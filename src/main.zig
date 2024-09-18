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

const Entity = struct {
    const Self = @This();

    x: i32,
    y: i32,

    pub fn isPosition(self: *const Self, entity: *const Self) bool {
        return self.x == entity.x and self.y == entity.y;
    }
};

const SnakeDirection = enum {
    UP,
    DOWN,
    LEFT,
    RIGHT,
};

const Snake = struct {
    const Self = @This();

    parts: std.ArrayList(Entity),
    direction: SnakeDirection,

    pub fn init(allocator: std.mem.Allocator) !Self {
        var self = Self{
            .parts = std.ArrayList(Entity).init(allocator),
            .direction = .RIGHT,
        };

        try self.parts.append(Entity{ .x = 1, .y = 0 });
        try self.parts.append(Entity{ .x = 0, .y = 0 });
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

    pub fn getHead(self: *Self) Entity {
        return self.parts.items[0];
    }

    /// Move snake in a certain direction.
    pub fn move(self: *Self) Entity {
        var target = self.getHead();

        // TODO: Handle cases when snake would move out of the map's
        // boundaries and make it enter on the opposite side.
        switch (self.direction) {
            .UP => target.y -= 1,
            .DOWN => target.y += 1,
            .LEFT => target.x -= 1,
            .RIGHT => target.x += 1,
        }

        for (self.parts.items) |*part| {
            const next = Entity{
                .x = part.x,
                .y = part.y,
            };
            part.x = target.x;
            part.y = target.y;
            target = next;
        }

        // NOTE:
        // Return original position of the tail in order to be able to
        // potentially grow the snake.
        return target;
    }

    pub fn grow(self: *Self, part: Entity) !void {
        try self.parts.append(part);
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
    playing: bool,
    map: Map,
    snake: Snake,
    food: Entity,

    pub fn init(allocator: std.mem.Allocator, config: *const Config) !Self {
        var self = Self{
            .allocator = allocator,
            .config = config,
            .running = true,
            .playing = false,
            .map = try Map.init(allocator, config),
            .snake = try Snake.init(allocator),
            .food = undefined,
        };

        self.spawnFood();

        return self;
    }

    pub fn deinit(self: *Self) void {
        self.snake.deinit();
        self.map.deinit();
    }

    pub fn spawnFood(self: *Self) void {
        const random_x: i32 = @intCast(std.crypto.random.uintAtMost(u32, self.config.map.cols - 1));
        const random_y: i32 = @intCast(std.crypto.random.uintAtMost(u32, self.config.map.rows - 1));
        self.food = .{ .x = random_x, .y = random_y };
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

        // Start/pause game.
        if (rl.isKeyPressed(rl.KeyboardKey.key_enter)) {
            game.playing = !game.playing;
        }

        if (game.playing) {
            if (rl.isKeyPressed(rl.KeyboardKey.key_k) or rl.isKeyPressed(rl.KeyboardKey.key_up)) {
                game.snake.setDirection(.UP);
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_j) or rl.isKeyPressed(rl.KeyboardKey.key_down)) {
                game.snake.setDirection(.DOWN);
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_h) or rl.isKeyPressed(rl.KeyboardKey.key_left)) {
                game.snake.setDirection(.LEFT);
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_l) or rl.isKeyPressed(rl.KeyboardKey.key_right)) {
                game.snake.setDirection(.RIGHT);
            }

            if (tick >= config.tick_time) {
                const previous_tail = game.snake.move();
                if (game.snake.getHead().isPosition(&game.food)) {
                    try game.snake.grow(previous_tail);
                    game.spawnFood();
                }
                tick = 0;
            }
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
                snake_part.x,
                snake_part.y,
                .{ .x = tile_width, .y = tile_height },
                rl.Color.dark_green,
            );
        }

        // Food
        renderTile(
            game.food.x,
            game.food.y,
            .{ .x = tile_width, .y = tile_height },
            rl.Color.gold,
        );

        if (!game.playing) {
            const text = "Press [ENTER] to start the game.";
            const font_size = 24;
            const text_size = rl.measureText(text, font_size);
            rl.drawText(
                text,
                @divTrunc(config.width, 2) - @divTrunc(text_size, 2),
                @divTrunc(config.height, 2),
                font_size,
                rl.Color.ray_white,
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
