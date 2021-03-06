const std = @import("std");
const misc = @import("misc.zig");
const c = @import("client").c;

// For some reason, this isn't parsed automatically. According to SDL docs, the
// surface pointer returned is optional!
extern fn SDL_GetWindowSurface(window: *c.SDL_Window) ?*c.SDL_Surface;

const SDL_WINDOWPOS_UNDEFINED = @bitCast(c_int, c.SDL_WINDOWPOS_UNDEFINED_MASK);

pub fn initWindow(width: c_int, height: c_int) !*c.SDL_Window {
    const window: *c.SDL_Window = c.SDL_CreateWindow(
        "Drawbridge",
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

pub fn getWindowSurface(window: *c.SDL_Window) !*c.SDL_Surface {
    const surface: *c.SDL_Surface = SDL_GetWindowSurface(window) orelse {
        c.SDL_Log("Unable to get window surface: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    return surface;
}

pub fn initRgbSurface(flags: u32, w: c_int, h: c_int, depth: c_int) !*c.SDL_Surface {
    const endian = std.Target.current.cpu.arch.endian();
    const masks = switch (endian) {
        .Little => [4]u32{ 0xff000000, 0x00ff0000, 0x0000ff00, 0x000000ff },
        .Big => [4]u32{ 0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000 },
    };
    return c.SDL_CreateRGBSurface(flags, w, h, depth, masks[0], masks[1], masks[2], masks[3]) orelse {
        c.SDL_Log("Unable to get window surface: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
}

pub fn updateSurface(window: *c.SDL_Window) void {
    _ = c.SDL_UpdateWindowSurface(window);
}

pub fn queryWindowSize(window: *c.SDL_Window) misc.Rectangle {
    var w: c_int = undefined;
    var h: c_int = undefined;
    c.SDL_GetWindowSize(window, &w, &h);
    return misc.Rectangle{ .w = w, .h = h };
}

pub fn blit(src: *c.SDL_Surface, src_rect: ?*c.SDL_Rect, dst: *c.SDL_Surface, dst_rect: ?*c.SDL_Rect) void {
    const result = c.SDL_BlitSurface(src, src_rect, dst, dst_rect);
    if (result != 0) @panic("Error blitting surface!\n");
}

pub fn blitScaled(src: *c.SDL_Surface, src_rect: ?*c.SDL_Rect, dst: *c.SDL_Surface, dst_rect: ?*c.SDL_Rect) void {
    const result = c.SDL_BlitScaled(src, src_rect, dst, dst_rect);
    if (result != 0) @panic("Error blitting surface!\n");
}

pub fn fillRect(surface: *c.SDL_Surface, rect: ?*const c.SDL_Rect, color: u32) void {
    const result = c.SDL_FillRect(surface, rect, color);
    if (result != 0) @panic("Error filling rectangle!\n");
}

pub fn getRGBA(pixel: u32, format: *c.SDL_PixelFormat) [4]u8 {
    var r: u8 = undefined;
    var g: u8 = undefined;
    var b: u8 = undefined;
    var a: u8 = undefined;
    c.SDL_GetRGBA(pixel, format, &r, &g, &b, &a);
    return [4]u8{ r, g, b, a };
}

pub fn mapRGBA(rgba: [4]u8, format: *c.SDL_PixelFormat) u32 {
    return c.SDL_MapRGBA(format, rgba[0], rgba[1], rgba[2], rgba[3]);
}
