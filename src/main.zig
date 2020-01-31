const std = @import("std");
const os = std.os;
const math = std.math;
const warn = std.debug.warn;
const assert = std.debug.assert;

const draw = @import("draw.zig");
const tools = @import("tools.zig");
const State = @import("state.zig").State;
const c = @import("c.zig");

const SDL_WINDOWPOS_UNDEFINED = @bitCast(c_int, c.SDL_WINDOWPOS_UNDEFINED_MASK);

//const window_width: c_int = 840;
//const window_height: c_int = 620;
const window_width: c_int = 2300;
const window_height: c_int = 1440;
const maxDrawSize: c_int = math.maxInt(c_int);

const GeneralError = error{SDLINitializationFailed};

// For some reason, this isn't parsed automatically. According to SDL docs, the
// surface pointer returned is optional!
extern fn SDL_GetWindowSurface(window: *c.SDL_Window) ?*c.SDL_Surface;
extern fn setPixel(x: c_int, y: c_int, color: u32, surf: *c.SDL_Surface) void;
extern fn changeColors(width: c_int, height: c_int, colorA: u32, colorB: u32, surf: *c.SDL_Surface) void;
extern fn inverseColors(width: c_int, height: c_int, colorA: u32, colorB: u32, surf: *c.SDL_Surface) void;

pub fn main() !void {
    if (c.SDL_Init(c.SDL_INIT_VIDEO) != 0) {
        c.SDL_Log(c"Unable to initialize SDL: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    }
    defer c.SDL_Quit();
    var state = State{};

    const window: *c.SDL_Window = c.SDL_CreateWindow(
        c"Draw-bridge",
        SDL_WINDOWPOS_UNDEFINED,
        SDL_WINDOWPOS_UNDEFINED,
        window_width,
        window_height,
        c.SDL_WINDOW_OPENGL,
    ) orelse {
        c.SDL_Log(c"Unable to create window: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };
    defer c.SDL_DestroyWindow(window);

    //    const renderer = c.SDL_CreateRenderer(window, -1, c.SDL_RENDERER_ACCELERATED) orelse {
    //        return error.SDLInitializationFailed;
    //    };
    //    defer c.SDL_DestroyRenderer(renderer);

    const surface: *c.SDL_Surface = SDL_GetWindowSurface(window) orelse {
        c.SDL_Log(c"Unable to get window surface: %s", c.SDL_GetError());
        return error.SDLInitializationFailed;
    };

    var bgColor = c.SDL_MapRGB(surface.format, 10, 10, 10);
    var fgColor = c.SDL_MapRGB(surface.format, 200, 200, 200);
    //fgColor = 0xafafaf;
    const fillresult = c.SDL_FillRect(surface, null, bgColor);
    std.debug.assert(fillresult == 0);
    _ = c.SDL_UpdateWindowSurface(window);
    var square: c.SDL_Rect = undefined;
    square.x = 10;
    square.y = 10;
    square.w = 100;
    square.h = 100;
    _ = c.SDL_FillRect(surface, &square, fgColor);
    _ = c.SDL_UpdateWindowSurface(window);

    var event: c.SDL_Event = undefined;
    var running: u16 = 5000;
    draw.thing(fgColor, surface);
    var oldx: c_int = 0;
    var oldy: c_int = 0;
    //const t = @intToEnum(c.SDL_bool, c.SDL_TRUE);
    //if (c.SDL_SetRelativeMouseMode(t) != 0) return error.UnableToSetRelativeMouseMode;

    while (running > 0) { // : (running -= 1) {
        updateSurface(window);
        _ = c.SDL_WaitEvent(&event);
        switch (event.type) {
            c.SDL_KEYDOWN => {
                const key = event.key.keysym.scancode;
                switch (key) {
                    c.SDL_Scancode.SDL_SCANCODE_Q => break,
                    c.SDL_Scancode.SDL_SCANCODE_I => inverseColors(window_width, window_height, fgColor, bgColor, surface),
                    c.SDL_Scancode.SDL_SCANCODE_A => _ = c.SDL_FillRect(surface, null, bgColor),
                    c.SDL_Scancode.SDL_SCANCODE_M => state.mirrorDrawing = !state.mirrorDrawing,
                    else => warn("key pressed: {}\n", key),
                }
            },
            c.SDL_KEYUP => {},

            c.SDL_MOUSEMOTION => {
                if (state.drawing) {
                    //warn("Motion: x:{} y:{}  xrel: {}  yrel: {}\n", event.motion.x, event.motion.y, event.motion.xrel, event.motion.yrel);
                    const x = event.motion.x;
                    const y = event.motion.y;
                    const deltaX = event.motion.xrel;
                    const deltaY = event.motion.yrel;
                    tools.pencil(x, y, deltaX, deltaY, fgColor, surface);
                    if (state.mirrorDrawing) {
                        const halfwidth = window_width / 2;
                        const halfheight = window_height / 2;
                        const deltaW = x - halfwidth;
                        const deltaH = y - halfheight;
                        // mirror x
                        tools.pencil(halfwidth - deltaW, y, -deltaX, deltaY, fgColor, surface);
                        // mirror y
                        tools.pencil(x, halfheight - deltaH, deltaX, -deltaY, fgColor, surface);
                        // mirror xy (diagonal corner)
                        tools.pencil(halfwidth - deltaW, halfheight - deltaH, -deltaX, -deltaY, fgColor, surface);
                    }
                }
            },
            c.SDL_MOUSEBUTTONDOWN => {
                state.drawing = true;
                const x = event.button.x;
                const y = event.button.y;
                tools.pencil(x, y, 0, 0, fgColor, surface);
                if (event.button.button != 1) {
                    draw.line2(x, x - oldx, y, y - oldy, fgColor, surface) catch unreachable;
                }
                oldx = x;
                oldy = y;
            },
            c.SDL_MOUSEBUTTONUP => {
                state.drawing = false;
            },
            c.SDL_MOUSEWHEEL => {
                changeColors(window_width, window_height, fgColor, bgColor, surface);
                if (event.wheel.y == -1 and (draw.Rectangle.h == 1 or draw.Rectangle.w == 1)) continue;
                if (event.wheel.y == 1 and (draw.Rectangle.h == maxDrawSize or draw.Rectangle.w == maxDrawSize)) continue;
                //warn("mousewheel {}\n", event.wheel);
                draw.Rectangle.h += event.wheel.y;
                draw.Rectangle.w += event.wheel.y;
            },
            c.SDL_QUIT => {
                warn("Attempting to quit\n");
                break;
            },
            c.SDL_WINDOWEVENT => warn("window event {}\n", event.window.event),
            c.SDL_SYSWMEVENT => warn("syswm event {}\n", event),
            c.SDL_TEXTINPUT => {},
            else => warn("unexpected event # {} \n", event.type),
        }
    }
    c.SDL_Log(c"pong\n");
}

fn updateSurface(window: *c.SDL_Window) void {
    _ = c.SDL_UpdateWindowSurface(window);
}
