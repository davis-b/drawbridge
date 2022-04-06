const c = @import("client").c;
pub const display = @import("display.zig");
pub const mouse = @import("mouse.zig");
pub const keyboard = @import("keyboard.zig");
pub const bmp = @import("bmp.zig");

pub const Rect = c.SDL_Rect;
pub const Surface = c.SDL_Surface;
pub const pixelFormat = c.SDL_PixelFormat;

pub fn init() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
}

pub fn deinit() void {
    c.SDL_Quit();
}

pub fn lastErr() [*c]const u8 {
    return c.SDL_GetError();
}
