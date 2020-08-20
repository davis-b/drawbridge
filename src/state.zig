const c = @import("c.zig");

pub const World = struct {
    window: *c.SDL_Window,
    surface: *c.SDL_Surface,
    drawing: bool = false,
    mirrorDrawing: bool = false,
    bgColor: u32 = 0x090909,

    draw_area: Rectangle,
};

const Rectangle = struct {
    width: usize,
    height: usize,
};

pub const User = struct {
    size: u8,
    color: u32,
    //tool: tools.Tools,
    lastX: c_int = 0,
    lastY: c_int = 0,
};
