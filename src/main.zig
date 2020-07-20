const std = @import("std");
const os = std.os;
const math = std.math;
const warn = std.debug.warn;
const assert = std.debug.assert;

const draw = @import("draw.zig");
const tools = @import("tools.zig");
const State = @import("state.zig").State;
const c = @import("c.zig");
const sdl = @import("sdl.zig");
const users = @import("user.zig");

const GeneralError = error{SDLINitializationFailed};

extern fn changeColors(width: c_int, height: c_int, colorA: u32, colorB: u32, surf: *c.SDL_Surface) void;
extern fn inverseColors(width: c_int, height: c_int, colorA: u32, colorB: u32, surf: *c.SDL_Surface) void;
extern fn voidToU32(v: *c_void) u32;
extern fn incVoid(v: *c_void, amount: u32) *c_void;

const maxDrawSize: c_int = math.maxInt(c_int);

fn updateSurface(window: *c.SDL_Window) void {
    _ = c.SDL_UpdateWindowSurface(window);
}

const windowWidth: c_int = 2300;
const windowHeight: c_int = 1440;
//c.SDL_GetWindowSize(window, &windowWidth, &windowHeight);
pub fn main() !void {
    try sdl.init();
    errdefer c.SDL_Quit();
    const window = try sdl.initWindow(windowWidth, windowHeight);
    defer c.SDL_DestroyWindow(window);
    const surface = try sdl.initSurface(window);
    defer c.SDL_FreeSurface(surface);
    var bgColor: u32 = c.SDL_MapRGB(surface.format, 10, 10, 10);
    var fgColor: u32 = c.SDL_MapRGB(surface.format, 200, 200, 200);
    //user.color = 0xafafaf;
    const fillresult = c.SDL_FillRect(surface, null, bgColor);
    std.debug.assert(fillresult == 0);
    _ = c.SDL_UpdateWindowSurface(window);

    draw.thing(fgColor, surface);
    draw.squares(surface);

    var running = true;
    //const t = @intToEnum(c.SDL_bool, c.SDL_TRUE);
    //if (c.SDL_SetRelativeMouseMode(t) != 0) return error.UnableToSetRelativeMouseMode;
    var user = users.User{ .size = 10, .color = 0x777777 };
    var state = State{ .window = window, .surface = surface };
    var event: c.SDL_Event = undefined;
    while (running) {
        updateSurface(state.window);
        _ = c.SDL_WaitEvent(&event);
        onEvent(event, &user, &state, &running);
    }
    c.SDL_Log(c"pong\n");
}

/// Draws contents of frame onto surface
/// intended not to be used every update, but instead
/// when we resize, zoom, or scroll through an image.
fn drawFrame(frame: *Frame, surface: *c.SDL_Surface) void {
    //
}

/// TODO
/// Should return mouse pos within the frame, rather than the raw mouse pos of the window.
fn getMousePos() usize {
    var x: c_int = 0;
    var y: c_int = 0;
    const state = c.SDL_GetMouseState(&x, &y);
    warn("state: {} x: {} y: {}\n", state, x, y);
    //const pos = x + (x * y);
    //const pos = y + (x * y);
    const pos = (y * windowWidth) + x;
    //const pos = x * y;
    return @intCast(usize, pos);
}

fn onEvent(event: c.SDL_Event, user: *users.User, state: *State, running: *bool) void {
    switch (event.type) {
        c.SDL_KEYDOWN => {
            const key = event.key.keysym.scancode;
            switch (key) {
                c.SDL_Scancode.SDL_SCANCODE_Q => running.* = false,
                c.SDL_Scancode.SDL_SCANCODE_I => inverseColors(windowWidth, windowHeight, user.color, state.bgColor, state.surface),
                c.SDL_Scancode.SDL_SCANCODE_A => _ = c.SDL_FillRect(state.surface, null, state.bgColor),
                c.SDL_Scancode.SDL_SCANCODE_M => state.mirrorDrawing = !state.mirrorDrawing,
                c.SDL_Scancode.SDL_SCANCODE_C => {
                    if (user.color == 0x00ff00) {
                        user.color = 0xff0000;
                    } else {
                        user.color = 0x00ff00;
                    }
                    const cPixels = @alignCast(4, state.surface.pixels.?);
                    const pixels = @ptrCast([*]u32, cPixels);
                    const pos = getMousePos();
                    warn("color: {}\n", pixels[pos]);
                    warn("pos: {}\n", pos);
                },
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
                tools.pencil(x, y, deltaX, deltaY, user.color, state.surface);
                if (state.mirrorDrawing) {
                    const halfwidth = windowWidth / 2;
                    const halfheight = windowHeight / 2;
                    const deltaW = x - halfwidth;
                    const deltaH = y - halfheight;
                    // mirror x
                    tools.pencil(halfwidth - deltaW, y, -deltaX, deltaY, user.color, state.surface);
                    // mirror y
                    tools.pencil(x, halfheight - deltaH, deltaX, -deltaY, user.color, state.surface);
                    // mirror xy (diagonal corner)
                    tools.pencil(halfwidth - deltaW, halfheight - deltaH, -deltaX, -deltaY, user.color, state.surface);
                }
            }
        },
        c.SDL_MOUSEBUTTONDOWN => {
            state.drawing = true;
            const x = event.button.x;
            const y = event.button.y;
            tools.pencil(x, y, 0, 0, user.color, state.surface);
            if (event.button.button != 1) {
                draw.line2(x, x - user.lastX, y, y - user.lastY, user.color, state.surface) catch unreachable;
            }
            user.lastX = x;
            user.lastY = y;
        },
        c.SDL_MOUSEBUTTONUP => {
            state.drawing = false;
        },
        c.SDL_MOUSEWHEEL => {
            changeColors(windowWidth, windowHeight, user.color, state.bgColor, state.surface);
            var skip = false;
            if (event.wheel.y == -1 and (draw.Rectangle.h == 1 or draw.Rectangle.w == 1)) skip = true;
            if (event.wheel.y == 1 and (draw.Rectangle.h == maxDrawSize or draw.Rectangle.w == maxDrawSize)) skip = true;
            //warn("mousewheel {}\n", event.wheel);
            if (!skip) {
                draw.Rectangle.h += event.wheel.y;
                draw.Rectangle.w += event.wheel.y;
            }
        },
        c.SDL_QUIT => {
            warn("Attempting to quit\n");
            running.* = false;
        },
        c.SDL_WINDOWEVENT => warn("window event {}\n", event.window.event),
        c.SDL_SYSWMEVENT => warn("syswm event {}\n", event),
        c.SDL_TEXTINPUT => {},
        else => warn("unexpected event # {} \n", event.type),
    }
}
