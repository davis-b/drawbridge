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

pub fn drawHeader(surface: *Surface, a: bool, b: bool) void {
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

/// Draws all GUI elements
pub fn drawAll(gui_s: *Surfaces) void {
    drawHeader(gui_s.header, true, true);
    drawFooter(gui_s.footer);
    drawLeft(gui_s.left);
    drawRight(gui_s.right);
}

/// Blits all GUI elements to dst surface
pub fn blitAll(dst: *c.SDL_Surface, gui_s: *Surfaces) void {
    {
        const mid = @divFloor((dst.w - gui_s.header.w), 2);
        var r = sdl.Rect{ .x = mid, .y = 0, .h = 0, .w = 0 };
        sdl.display.blit(gui_s.header, null, dst, &r);
    }
    {
        var r = sdl.Rect{ .x = 0, .y = gui_s.header.h, .h = 0, .w = 0 };
        sdl.display.blit(gui_s.left, null, dst, &r);
    }
    {
        var r = sdl.Rect{ .x = dst.w - gui_s.right.w, .y = gui_s.header.h, .h = 0, .w = 0 };
        sdl.display.blit(gui_s.right, null, dst, &r);
    }
    {
        const mid = @divFloor((dst.w - gui_s.footer.w), 2);
        var r = sdl.Rect{ .x = mid, .y = dst.h - gui_s.footer.h, .h = 0, .w = 0 };
        sdl.display.blit(gui_s.footer, null, dst, &r);
    }
}

pub fn handleButtonPress(parent: *sdl.Surface, s: *Surfaces, x: c_int, y: c_int) void {
    const warn = @import("std").debug.warn;
    // header
    if (y <= s.header.h) {
        handleHeaderPress(parent, s.header, x, y);
    }
    // footer
    else if (y >= parent.h - s.footer.h) {
        const new_y = y - (parent.h - s.footer.h);
        warn("footer {}x{}\n", .{ x, new_y });
    }
    // left sidebar
    else if (x <= s.left.w) {
        warn("left\n", .{});
    }
    // right sidebar
    else if (x >= parent.w - s.right.w) {
        const new_x = x - (parent.w - s.right.w);
        warn("right {}x{} \n", .{ new_x, y });
    }
}

fn handleHeaderPress(parent: *sdl.Surface, header: *sdl.Surface, x: c_int, y: c_int) void {
    // TODO
    // Seems like we may need to pass around structs with more state than sdl.Surface provides.
    // handleButtonPress may also need *state.World so that we may enact meaningful change.
    //  Alternatively, we could return a requested outcome, such as changeColor, newImage.
    //   Although, both of those require extra data, such as a color or a new image size.
    //   Unless we handle the gathering of that data at the call site, rather than within the gui code.
}
