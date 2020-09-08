const c = @import("c.zig");
const sdl = @import("sdl/index.zig");
const fillRect = sdl.display.fillRect;

const Surface = sdl.Surface;

pub const Surfaces = struct {
    header: *Surface,
    footer: *Surface,
    left: *Surface,
    right: *Surface,
};

const Dimensions = struct {
    const header = .{ .w = 150, .h = 20 };
    const footer = .{ .w = 150, .h = 20 };
    const left = .{ .w = 50, .h = 200 };
    const right = .{ .w = 50, .h = 200 };
};

pub fn init() !Surfaces {
    var g: Surfaces = undefined;
    g.header = try initHeader();
    g.footer = try initFooter();
    g.left = try initLeft();
    g.right = try initRight();
    return g;
}

fn initHeader() !*Surface {
    return try sdl.display.initRgbSurface(0, Dimensions.header.w, Dimensions.header.h, 24);
}

fn initFooter() !*Surface {
    return try sdl.display.initRgbSurface(0, Dimensions.footer.w, Dimensions.footer.h, 24);
}

fn initLeft() !*Surface {
    return try sdl.display.initRgbSurface(0, Dimensions.left.w, Dimensions.left.h, 24);
}

fn initRight() !*Surface {
    return try sdl.display.initRgbSurface(0, Dimensions.right.w, Dimensions.right.h, 24);
}

pub fn drawHeader(a: bool, b: bool, surface: *Surface) void {
    const bg_color = 0xff0000;
    fillRect(surface, &c.SDL_Rect{ .x = 0, .y = 0, .w = 100, .h = 20 }, bg_color);
    if (a) {
        fillRect(surface, &c.SDL_Rect{ .x = 25, .y = 0, .w = 25, .h = 20 }, 0x00ff00);
    }
    if (b) {
        fillRect(surface, &c.SDL_Rect{ .x = 50, .y = 0, .w = 25, .h = 20 }, 0x0000ff);
    }
}

pub fn drawFooter(surface: *Surface) void {
    fillRect(surface, null, 0xff0000);
}

pub fn drawLeft(surface: *Surface) void {
    fillRect(surface, null, 0x00ff00);
}

pub fn drawRight(surface: *Surface) void {
    fillRect(surface, null, 0x0000ff);
}
