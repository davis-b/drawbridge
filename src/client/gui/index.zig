const log = @import("std").log.scoped(.gui);

const c = @import("../c.zig");
const sdl = @import("../sdl/index.zig");

pub const draw = @import("draw.zig");
pub const events = @import("events.zig");

pub const Surface = sdl.Surface;
pub const Surfaces = struct {
    header: *Surface,
    footer: *Surface,
    left: *Surface,
    right: *Surface,
    images: draw.Images,
};

pub const Dimensions = struct {
    pub const header = .{ .w = 100, .h = 20 };
    pub const footer = .{ .w = 150, .h = 20 };
    pub const left = .{ .w = 40, .h = 400 };
    pub const right = .{ .w = 50, .h = 200 };
};

pub fn init() !Surfaces {
    errdefer |err| {
        log.err("gui init: {} -- {s}", .{ err, sdl.lastErr() });
    }
    var s: Surfaces = undefined;
    s.header = try Init.header();
    s.footer = try Init.footer();
    s.left = try Init.left();
    s.right = try Init.right();
    s.images = try draw.Images.init();
    return s;
}

const Init = struct {
    fn header() !*Surface {
        return try sdl.display.initRgbSurface(0, Dimensions.header.w, Dimensions.header.h, 24);
    }

    fn footer() !*Surface {
        return try sdl.display.initRgbSurface(0, Dimensions.footer.w, Dimensions.footer.h, 24);
    }

    fn left() !*Surface {
        return try sdl.display.initRgbSurface(0, Dimensions.left.w, Dimensions.left.h, 24);
    }

    fn right() !*Surface {
        return try sdl.display.initRgbSurface(0, Dimensions.right.w, Dimensions.right.h, 24);
    }
};

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
