const c = @import("c");
pub const display = @import("display.zig");
pub const mouse = @import("mouse.zig");

pub const Rect = c.SDL_Rect;
pub const Surface = c.SDL_Surface;

pub fn init() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
}

pub fn deinit() void {
    c.SDL_Quit();
}
