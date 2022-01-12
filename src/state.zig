const c = @import("c.zig");
const gui = @import("gui.zig");
const Dot = @import("misc.zig").Dot;
const Whiteboard = @import("whiteboard.zig").Whiteboard;
const Tool = @import("tools.zig").Tool;

pub const World = struct {
    window: *c.SDL_Window,
    surface: *c.SDL_Surface,
    image: *Whiteboard,
    gui: *gui.Surfaces,
    mirrorDrawing: bool = false,
    bg_color: u32 = 0x090909,
};

pub const User = struct {
    drawing: bool = false,
    size: u8 = 1,
    color: u32,
    tool: Tool = .pencil,
    lastX: c_int = 0,
    lastY: c_int = 0,
};
