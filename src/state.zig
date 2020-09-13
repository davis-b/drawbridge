const c = @import("c.zig");
const gui = @import("gui.zig");
const Dot = @import("misc.zig").Dot;
const Whiteboard = @import("whiteboard.zig").Whiteboard;

pub const World = struct {
    window: *c.SDL_Window,
    surface: *c.SDL_Surface,
    image: *Whiteboard,
    gui: *gui.Surfaces,
    drawing: bool = false,
    mirrorDrawing: bool = false,
    bg_color: u32 = 0x090909,
};

pub const User = struct {
    size: u8,
    color: u32,
    //tool: tools.Tools,
    lastX: c_int = 0,
    lastY: c_int = 0,
};
