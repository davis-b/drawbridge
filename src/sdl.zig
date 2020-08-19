const c = @import("c.zig");

// For some reason, this isn't parsed automatically. According to SDL docs, the
// surface pointer returned is optional!
extern fn SDL_GetWindowSurface(window: *c.SDL_Window) ?*c.SDL_Surface;

const SDL_WINDOWPOS_UNDEFINED = @bitCast(c_int, c.SDL_WINDOWPOS_UNDEFINED_MASK);
//const window_width: c_int = 840;
//const window_height: c_int = 620;

pub fn init() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        c.SDL_Log("Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }

    //    const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED) orelse {
    //        return error.SDLInitializationFailed;
    //    };
    //    defer c.SDL_DestroyRenderer(renderer);
}

pub fn initWindow(width: c_int, height: c_int) !*c.SDL_Window {
    const window: *c.SDL_Window = c.SDL_CreateWindow(
        "Draw-bridge",
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        width,
        height,
        c.SDL_WINDOW_OPENGL,
    ) orelse {
        c.SDL_Log("Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    return window;
}

pub fn initSurface(window: *c.SDL_Window) !*c.SDL_Surface {
    const surface: *c.SDL_Surface = SDL_GetWindowSurface(window) orelse {
        c.SDL_Log("Unable to get window surface: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    return surface;
}

pub fn deinit(window: *c.SDL_Window, surface: *c.SDL_Surface) void {
    c.SDL_FreeSurface(surface);
    c.SDL_DestroyWindow(window);
    //c.SDL_Quit();
}
