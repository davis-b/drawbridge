const std = @import("std");
const warn = std.debug.warn;

const draw = @import("draw.zig");
const state = @import("state.zig");
const gui = @import("gui.zig");

const c = @import("c.zig");
const sdl = @import("sdl/index.zig");

const m = @import("main.zig");

const Timer = struct {
    time: ?u64 = null,
    name: []const u8,
    times: [10_000]?u64 = [_]?u64{null} ** 10_000,
    index: usize = 0,

    fn start(self: *Timer) void {
        self.time = std.time.milliTimestamp();
    }

    fn end(self: *Timer) void {
        const time_taken = std.time.milliTimestamp() - self.time.?;
        self.times[self.index] = time_taken;
        self.index += 1;
        if (self.index == self.times.len) self.index = 0;
        self.time = null;
    }

    fn print(self: *Timer) void {
        var total: usize = 0;
        for (self.times) |i| {
            if (i) |j| {
                warn("[{}] {}\n", .{ self.name, j });
                total += j;
            } else break;
        }
        warn("[{}] avg: {d:.2}ms, total: {} ms from {} events\n", .{ self.name, @intToFloat(f64, total) / @intToFloat(f64, self.index), total, self.index });
    }
};
pub fn main() !void {
    try sdl.init();
    errdefer sdl.deinit();
    const cursor = try sdl.mouse.createSystemCursor(.crosshair);
    defer c.SDL_FreeCursor(cursor);
    c.SDL_SetCursor(cursor);
    const window = try sdl.display.initWindow(1500, 1000);
    defer c.SDL_DestroyWindow(window);
    const surface = try sdl.display.initSurface(window);

    const image_width = 1300;
    const image_height = 800;
    const surface_draw = try sdl.display.initRgbSurface(0, image_width, image_height, 24);
    var bgColor: u32 = c.SDL_MapRGB(surface_draw.format, 40, 40, 40);
    var fgColor: u32 = c.SDL_MapRGB(surface_draw.format, 150, 150, 150);

    var gui_surfaces = try gui.init();
    var image_area: sdl.Rect = m.getImageArea(surface, surface_draw, &gui_surfaces);

    var running = true;
    var user = state.User{ .size = 10, .color = 0x777777 };
    var world = state.World{
        .window = window,
        .surface = surface,
        .image = surface_draw,
        .image_area = &image_area,
        .gui = &gui_surfaces,
        .bgColor = bgColor,
    };
    defer c.SDL_FreeSurface(world.surface);
    defer c.SDL_FreeSurface(world.image);
    try m.fullRender(world.surface, world.image, world.image_area, world.gui, world.bgColor);
    draw.thing(fgColor, surface_draw);
    draw.squares(surface_draw);

    var rtimer = Timer{ .name = "render image" };
    defer rtimer.print();
    var utimer = Timer{ .name = "update surface" };
    defer utimer.print();

    var x: c_int = 10;
    var y: c_int = 10;
    for (events) |event| {
        rtimer.start();
        m.renderImage(world.surface, world.image, world.image_area);
        rtimer.end();

        utimer.start();
        sdl.display.updateSurface(world.window);
        utimer.end();

        var e = event;
        if (e.type == c.SDL_MOUSEMOTION) {
            e.motion.x = x;
            x += 10;
            e.motion.y = y;
            y += 10;
        }
        try m.onEvent(e, &user, &world, &running);
        std.time.sleep(100 * std.time.millisecond);
    }
    c.SDL_Log("pong\n");

    for ([_]u8{0} ** 10) |_| {
        rtimer.start();
        m.renderImage(world.surface, world.image, world.image_area);
        rtimer.end();

        utimer.start();
        sdl.display.updateSurface(world.window);
        utimer.end();
    }
}

const setup_events = [_]c.SDL_Event{
    c.SDL_Event{
        .button = .{
            .type = c.SDL_MOUSEBUTTONDOWN,
            .x = 100,
            .y = 100,
            .button = 2,
            .timestamp = undefined,
            .which = undefined,
            .state = undefined,
            .clicks = undefined,
            .padding1 = undefined,
            .windowID = undefined,
        },
    },
};

const motion_events = [_]c.SDL_Event{
    c.SDL_Event{
        .motion = .{
            .type = c.SDL_MOUSEMOTION,
            .x = 50,
            .y = 50,
            .xrel = 10,
            .yrel = 10,
            .timestamp = undefined,
            .windowID = undefined,
            .which = undefined,
            .state = undefined,
        },
    },
} ** 40;

const events = setup_events ++ motion_events;
