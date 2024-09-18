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

    config: *const Config,
    parts: std.ArrayList(Entity),
    direction: SnakeDirection,
    next_direction: SnakeDirection,

    pub fn init(allocator: std.mem.Allocator, config: *const Config) !Self {
        var self = Self{
            .config = config,
            .parts = std.ArrayList(Entity).init(allocator),
            .direction = .DOWN,
            .next_direction = .DOWN,
        };

        const random_x = std.crypto.random.intRangeAtMost(i32, 2, @as(i32, @intCast(self.config.map.cols)) - 2);
        const random_y = std.crypto.random.intRangeAtMost(i32, 2, @as(i32, @intCast(self.config.map.rows)) - 2);
        try self.parts.append(Entity{ .x = random_x, .y = random_y });
        try self.parts.append(Entity{ .x = random_x, .y = random_y - 1 });

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
            self.next_direction = direction;
        }
    }

    pub fn getHead(self: *Self) Entity {
        return self.parts.items[0];
    }

    /// Move snake in a certain direction.
    pub fn move(self: *Self) Entity {
        var target = self.getHead();

        switch (self.next_direction) {
            .UP => target.y -= 1,
            .DOWN => target.y += 1,
            .LEFT => target.x -= 1,
            .RIGHT => target.x += 1,
        }

        // If the snake leaves the map, make sure snake enters again on the
        // opposite side of the map.
        if (target.y < 0) {
            target.y = @as(i32, @intCast(self.config.map.rows)) - 1;
        }
        if (target.y >= @as(i32, @intCast(self.config.map.rows))) {
            target.y = 0;
        }
        if (target.x < 0) {
            target.x = @as(i32, @intCast(self.config.map.cols)) - 1;
        }
        if (target.x >= @as(i32, @intCast(self.config.map.cols))) {
            target.x = 0;
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

        self.direction = self.next_direction;

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
            .snake = try Snake.init(allocator, config),
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
    const config = Config.init(800, 600, true, 0.3);
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
            tick += rl.getFrameTime();

            if (rl.isKeyPressed(rl.KeyboardKey.key_k) or rl.isKeyPressed(rl.KeyboardKey.key_up)) {
                game.snake.setDirection(.UP);
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_j) or rl.isKeyPressed(rl.KeyboardKey.key_down)) {
                game.snake.setDirection(.DOWN);
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_h) or rl.isKeyPressed(rl.KeyboardKey.key_left)) {
                game.snake.setDirection(.LEFT);
            } else if (rl.isKeyPressed(rl.KeyboardKey.key_l) or rl.isKeyPressed(rl.KeyboardKey.key_right)) {
                game.snake.setDirection(.RIGHT);
            }

            const tick_time = config.tick_time - (0.01 * @as(f32, @floatFromInt(game.snake.parts.items.len)));
            if (tick >= @max(0.1, tick_time)) {
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
        for (game.snake.parts.items, 0..) |snake_part, i| {
            const color = if (i == 0) rl.Color.green else rl.Color.dark_green;
            renderTile(
                snake_part.x,
                snake_part.y,
                .{ .x = tile_width, .y = tile_height },
                color,
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
