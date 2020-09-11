const c = @import("c.zig");
const gui = @import("gui.zig");

pub const World = struct {
    window: *c.SDL_Window,
    surface: *c.SDL_Surface,
    image: *c.SDL_Surface,
    image_area: *c.SDL_Rect,
    image_offset: Dot, // when we can only see a portion of the image, the start of the image gets pushed this much from 0, 0
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

pub const Dot = struct {
    x: c_int,
    y: c_int,
};
