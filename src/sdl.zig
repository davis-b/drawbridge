const std = @import("std");
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
}

pub fn initWindow(width: c_int, height: c_int) !*c.SDL_Window {
    const window: *c.SDL_Window = c.SDL_CreateWindow(
        "Draw-bridge",
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        width,
        height,
        // c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_SHOWN | c.SDL_WINDOW_RESIZABLE,
        c.SDL_WINDOW_SHOWN | c.SDL_WINDOW_RESIZABLE,
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

pub fn initRgbSurface(flags: u32, w: c_int, h: c_int, depth: c_int) !*c.SDL_Surface {
    return c.SDL_CreateRGBSurface(flags, w, h, depth, 0, 0, 0, 0) orelse {
        c.SDL_Log("Unable to get window surface: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
}

pub fn updateSurface(window: *c.SDL_Window) void {
    _ = c.SDL_UpdateWindowSurface(window);
}

extern fn SDL_CreateSystemCursor(c_int) *c.SDL_Cursor;
const Cursor = enum(c_int) {
    arrow = c.SDL_SYSTEM_CURSOR_ARROW,
    ibeam = c.SDL_SYSTEM_CURSOR_IBEAM,
    wait = c.SDL_SYSTEM_CURSOR_WAIT,
    crosshair = c.SDL_SYSTEM_CURSOR_CROSSHAIR,
    waitarrow = c.SDL_SYSTEM_CURSOR_WAITARROW,
    size_nwse = c.SDL_SYSTEM_CURSOR_SIZENWSE,
    size_nesw = c.SDL_SYSTEM_CURSOR_SIZENESW,
    size_we = c.SDL_SYSTEM_CURSOR_SIZEWE,
    size_ns = c.SDL_SYSTEM_CURSOR_SIZENS,
    sizeall = c.SDL_SYSTEM_CURSOR_SIZEALL,
    no = c.SDL_SYSTEM_CURSOR_NO,
    hand = c.SDL_SYSTEM_CURSOR_HAND,
};

pub fn createSystemCursor(cursor: Cursor) !*c.SDL_Cursor {
    const result = SDL_CreateSystemCursor(@enumToInt(cursor));
    if (@ptrToInt(result) == 0) {
        c.SDL_Log("Unable to set system cursor: %s", c.SDL_GetError());
        return error.SettingCursorFailed;
    }
    return result;
}
