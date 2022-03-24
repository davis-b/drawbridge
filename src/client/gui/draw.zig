const log = @import("std").log.scoped(.gui);

const c = @import("../c.zig");
const sdl = @import("../sdl/index.zig");
const fillRect = sdl.display.fillRect;

const Surface = @import("index.zig").Surface;
const Surfaces = @import("index.zig").Surfaces;
const Dimensions = @import("index.zig").Dimensions;

pub const Draw = struct {
    pub fn header(surface: *Surface, a: bool, b: bool) void {
        const bg_color = 0xff0000;
        fillRect(surface, &c.SDL_Rect{ .x = 0, .y = 0, .w = Dimensions.header.w, .h = Dimensions.header.h }, bg_color);
        if (a) {
            fillRect(surface, &c.SDL_Rect{ .x = 25, .y = 0, .w = 25, .h = 20 }, 0x00ff00);
        }
        if (b) {
            fillRect(surface, &c.SDL_Rect{ .x = 50, .y = 0, .w = 25, .h = 20 }, 0x0000ff);
        }
    }

    pub fn footer(surface: *Surface) void {
        fillRect(surface, null, 0xff0000);
    }

    pub fn left(surface: *Surface) void {
        fillRect(surface, null, 0x00ff00);
    }

    pub fn right(surface: *Surface) void {
        fillRect(surface, null, 0x0000ff);
    }

    /// Draws all GUI elements
    pub fn all(gui_s: *Surfaces) void {
        header(gui_s.header, true, true);
        footer(gui_s.footer);
        left(gui_s.left);
        right(gui_s.right);
    }
};
