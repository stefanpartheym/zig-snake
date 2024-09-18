const std = @import("std");
const rl = @import("raylib");

const Vec2 = struct {
    x: f32,
    y: f32,
};

const MapTileType = enum {
    EMPTY,
    ROCK,
};

const MapTile = struct {
    type: MapTileType,
};

const SnakePart = struct {
    pos: struct {
        x: i32,
        y: i32,
    },
};

const SnakeDirection = enum {
    UP,
    DOWN,
    LEFT,
    RIGHT,
};

const Snake = struct {
    const Self = @This();

    parts: std.ArrayList(SnakePart),
    head: *SnakePart,
    direction: SnakeDirection,

    pub fn init(allocator: std.mem.Allocator) !Self {
        var self = Self{
            .parts = std.ArrayList(SnakePart).init(allocator),
            .head = undefined,
            .direction = .RIGHT,
        };

        try self.parts.append(SnakePart{ .pos = .{ .x = 0, .y = 0 } });
        self.head = &self.parts.items[self.parts.items.len - 1];
        self.direction = .RIGHT;

        return self;
    }

    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// Update snake direction.
    pub fn setDirection(self: *Self, direction: SnakeDirection) void {
        const opposite: SnakeDirection = switch (self.direction) {
            .UP => .DOWN,
            .DOWN => .UP,
            .LEFT => .RIGHT,
            .RIGHT => .LEFT,
        };

        // Make sure, snake cannot move into opposite direction.
        if (direction != opposite) {
            self.direction = direction;
        }
    }

    /// Move snake in a certain direction.
    pub fn move(self: *Self) void {
        for (self.parts.items) |*part| {
            switch (self.direction) {
                .UP => part.pos.y -= 1,
                .DOWN => part.pos.y += 1,
                .LEFT => part.pos.x -= 1,
                .RIGHT => part.pos.x += 1,
            }
        }
    }
};

const Map = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    config: *const Config,
    data: []MapTile,

    pub fn init(allocator: std.mem.Allocator, config: *const Config) !Self {
        var self = Self{
            .allocator = allocator,
            .config = config,
            .data = try allocator.alloc(MapTile, config.map.rows * config.map.cols),
        };

        // Initialize map.
        for (0..config.map.rows) |row| {
            for (0..config.map.cols) |col| {
                if (std.crypto.random.float(f32) > 0.96) {
                    self.setTileAt(row, col, .{ .type = .ROCK });
                } else {
                    self.setTileAt(row, col, .{ .type = .EMPTY });
                }
            }
        }

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.data);
    }

    pub fn setTileAt(self: *Self, row: usize, col: usize, value: MapTile) void {
        self.data[self.getTileIndex(row, col)] = value;
    }

    pub fn getTileAt(self: *Self, row: usize, col: usize) MapTile {
        return self.data[self.getTileIndex(row, col)];
    }

    pub fn getTileIndex(self: *Self, row: usize, col: usize) usize {
        return row * self.config.map.cols + col;
    }
};

const Game = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    config: *const Config,
    running: bool,
    map: Map,
    snake: Snake,

    pub fn init(allocator: std.mem.Allocator, config: *const Config) !Self {
        return Self{
            .allocator = allocator,
            .config = config,
            .running = true,
            .map = try Map.init(allocator, config),
            .snake = try Snake.init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.snake.deinit();
        self.map.deinit();
    }
};

const Config = struct {
    const Self = @This();

    width: i32,
    height: i32,
    target_fps: i32,
    highdpi: bool,
    /// Time in seconds for one game tick to pass.
    tick_time: f32,
    map: struct {
        cols: u32,
        rows: u32,
    },

    pub fn init(
        width: i32,
        height: i32,
        highdpi: bool,
        tick_time: f32,
    ) Self {
        return Self{
            .width = width,
            .height = height,
            .target_fps = 60,
            .highdpi = highdpi,
            .tick_time = tick_time,
            .map = .{ .cols = 16, .rows = 12 },
        };
    }

    pub fn getTileWidth(self: *const Self) f32 {
        return @as(f32, @floatFromInt(self.width)) / @as(f32, @floatFromInt(self.map.cols));
    }

    pub fn getTileHeight(self: *const Self) f32 {
        return @as(f32, @floatFromInt(self.height)) / @as(f32, @floatFromInt(self.map.rows));
    }
};

pub fn main() !void {
    const config = Config.init(800, 600, true, 0.2);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var game = try Game.init(gpa.allocator(), &config);
    defer game.deinit();

    const tile_width = game.config.getTileWidth();
    const tile_height = game.config.getTileHeight();

    rl.setConfigFlags(.{ .window_highdpi = config.highdpi });
    rl.setTargetFPS(game.config.target_fps);
    rl.initWindow(config.width, config.height, "zig-snake");
    defer rl.closeWindow();

    var tick: f32 = 0;
    while (game.running) {
        tick += rl.getFrameTime();

        // Handle input
        if (rl.windowShouldClose() or
            rl.isKeyPressed(rl.KeyboardKey.key_q))
        {
            game.running = false;
        }

        if (rl.isKeyPressed(rl.KeyboardKey.key_k)) {
            game.snake.setDirection(.UP);
        }
        if (rl.isKeyPressed(rl.KeyboardKey.key_j)) {
            game.snake.setDirection(.DOWN);
        }
        if (rl.isKeyPressed(rl.KeyboardKey.key_h)) {
            game.snake.setDirection(.LEFT);
        }
        if (rl.isKeyPressed(rl.KeyboardKey.key_l)) {
            game.snake.setDirection(.RIGHT);
        }

        if (tick >= config.tick_time) {
            game.snake.move();
            tick = 0;
        }

        // Render
        rl.beginDrawing();
        rl.clearBackground(rl.Color.black);

        // Map
        for (0..config.map.rows) |row| {
            for (0..config.map.cols) |col| {
                const tile = game.map.getTileAt(row, col);
                renderMapTile(
                    tile,
                    @intCast(col),
                    @intCast(row),
                    .{ .x = tile_width, .y = tile_height },
                );
            }
        }

        // Snake
        for (game.snake.parts.items) |snake_part| {
            renderTile(
                snake_part.pos.x,
                snake_part.pos.y,
                .{ .x = tile_width, .y = tile_height },
                rl.Color.dark_green,
            );
        }

        rl.endDrawing();
    }
}

pub fn renderTile(col: i32, row: i32, size: Vec2, color: rl.Color) void {
    rl.drawRectangle(
        col * @as(i32, @intFromFloat(size.x)),
        row * @as(i32, @intFromFloat(size.y)),
        @as(i32, @intFromFloat(size.x)),
        @as(i32, @intFromFloat(size.y)),
        color,
    );
}

pub fn renderMapTile(tile: MapTile, col: i32, row: i32, size: Vec2) void {
    const color = switch (tile.type) {
        .EMPTY => rl.Color.brown,
        .ROCK => rl.Color.gray,
    };
    renderTile(col, row, size, color);
}
