const c = @import("c.zig");

pub const State = struct {
    window: *c.SDL_Window,
    surface: *c.SDL_Surface,
    drawing: bool = false,
    mirrorDrawing: bool = false,
    bgColor: u32 = 0x090909,
};
