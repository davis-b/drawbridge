const std = @import("std");
const os = std.os;
const math = std.math;
const warn = std.debug.warn;
const assert = std.debug.assert;

const draw = @import("draw.zig");
const tools = @import("tools.zig");
const state = @import("state.zig");

const c = @import("c.zig");
const sdl = @import("sdl.zig");

const GeneralError = error{SDLINitializationFailed};

const changeColors = c.changeColors;
const inverseColors = c.inverseColors;
// const voidToU32 = c.voidToU32;
// const incVoid = c.incVoid;

const maxDrawSize: c_int = math.maxInt(c_int);

const windowWidth: c_int = 2300;
const windowHeight: c_int = 1440;
//c.SDL_GetWindowSize(window, &windowWidth, &windowHeight);
pub fn main() !void {
    try sdl.init();
    errdefer c.SDL_Quit();
    const window = try sdl.initWindow(windowWidth, windowHeight);
    defer c.SDL_DestroyWindow(window);
    const surface = try sdl.initSurface(window);

    const image_width = 800;
    const image_height = 400;
    const surface_draw = try sdl.initRgbSurface(0, image_width, image_height, 32);
    var bgColor: u32 = c.SDL_MapRGB(surface.format, 10, 10, 10);
    var fgColor: u32 = c.SDL_MapRGB(surface.format, 200, 200, 200);
    //user.color = 0xafafaf;
    const fillresult = c.SDL_FillRect(surface, null, bgColor);
    std.debug.assert(fillresult == 0);
    sdl.updateSurface(window);

    draw.thing(fgColor, surface);
    draw.squares(surface);

    var running = true;
    //const t = @intToEnum(c.SDL_bool, c.SDL_TRUE);
    //if (c.SDL_SetRelativeMouseMode(t) != 0) return error.UnableToSetRelativeMouseMode;
    var user = state.User{ .size = 10, .color = 0x777777 };
    var world = state.World{
        .window = window,
        .surface = surface,
        .image = surface_draw,
    };
    defer c.SDL_FreeSurface(world.surface);
    defer c.SDL_FreeSurface(world.image);
    var event: c.SDL_Event = undefined;
    while (running) {
        drawFrame(world.image, world.surface);
        sdl.updateSurface(world.window);
        _ = c.SDL_WaitEvent(&event);
        onEvent(event, &user, &world, &running);
    }
    c.SDL_Log("pong\n");
}

/// Draws contents of frame onto surface
/// intended not to be used every update, but instead
/// when we resize, zoom, or scroll through an image.
fn drawFrame(src: *c.SDL_Surface, dst: *c.SDL_Surface) void {
    var r1 = c.SDL_Rect{ .x = 1, .y = 1, .h = 250, .w = 250 };
    var r2 = c.SDL_Rect{ .x = 0, .y = 0, .h = 500, .w = 500 };
    _ = c.SDL_FillRect(dst, null, 0x333333);
    _ = c.SDL_FillRect(src, null, 0xffffff);
    //   _ = c.SDL_SetClipRect(src, &r1);
    //   _ = c.SDL_SetClipRect(dst, &r2);
    //const result = c.SDL_BlitScaled(src, null, dst, null);
    const result = c.SDL_BlitSurface(src, null, dst, null);
    std.debug.assert(result == 0);

    //  _ = c.SDL_LockSurface(dst);
    //  _ = c.SDL_LockSurface(src);
    //  defer c.SDL_UnlockSurface(src);
    //  defer c.SDL_UnlockSurface(dst);
    //  var remaining: usize = 1000;
    //  var spx: [*]u32 = @ptrCast([*]u32, @alignCast(@alignOf([*]u32), src.pixels.?));
    //  var dpx: [*]u32 = @ptrCast([*]u32, @alignCast(@alignOf([*]u32), dst.pixels.?));
    //  while (remaining > 0) : (remaining -= 1) {
    //      dpx[remaining] = spx[remaining];
    //  }

    //  var n = @intCast(usize, world.surface.w * world.surface.h);
    //  var pixels: [*]u32 = @ptrCast([*]u32, @alignCast(@alignOf([*]u32), world.surface.pixels.?));
    //  while (n > 0) : (n -= 1) {
    //      pixels[n] = @intCast(u32, n % 10000);
    //  }
}

/// TODO
/// Should return mouse pos within the frame, rather than the raw mouse pos of the window.
fn getMousePos() usize {
    var x: c_int = 0;
    var y: c_int = 0;
    const mstate = c.SDL_GetMouseState(&x, &y);
    warn("mouse state: {} x: {} y: {}\n", .{ mstate, x, y });
    //const pos = x + (x * y);
    //const pos = y + (x * y);
    const pos = (y * windowWidth) + x;
    //const pos = x * y;
    return @intCast(usize, pos);
}

fn onEvent(event: c.SDL_Event, user: *state.User, world: *state.World, running: *bool) void {
    switch (event.type) {
        c.SDL_KEYDOWN => {
            const key = event.key.keysym.scancode;
            switch (key) {
                c.SDL_Scancode.SDL_SCANCODE_Q => running.* = false,
                c.SDL_Scancode.SDL_SCANCODE_I => inverseColors(windowWidth, windowHeight, user.color, world.bgColor, world.image),
                c.SDL_Scancode.SDL_SCANCODE_A => _ = c.SDL_FillRect(world.image, null, world.bgColor),
                c.SDL_Scancode.SDL_SCANCODE_M => world.mirrorDrawing = !world.mirrorDrawing,
                c.SDL_Scancode.SDL_SCANCODE_C => {
                    const cPixels = @alignCast(4, world.surface.pixels.?);
                    const pixels = @ptrCast([*]u32, cPixels);
                    const pos = getMousePos();
                    const color = pixels[pos];
                    user.color = color;
                },
                else => warn("key pressed: {}\n", .{key}),
            }
        },
        c.SDL_KEYUP => {},

        c.SDL_MOUSEMOTION => {
            if (world.drawing) {
                //warn("Motion: x:{} y:{}  xrel: {}  yrel: {}\n", event.motion.x, event.motion.y, event.motion.xrel, event.motion.yrel);
                const x = event.motion.x;
                const y = event.motion.y;
                const deltaX = event.motion.xrel;
                const deltaY = event.motion.yrel;
                tools.pencil(x, y, deltaX, deltaY, user.color, world.image);
                if (world.mirrorDrawing) {
                    const halfwidth = windowWidth / 2;
                    const halfheight = windowHeight / 2;
                    const deltaW = x - halfwidth;
                    const deltaH = y - halfheight;
                    // mirror x
                    tools.pencil(halfwidth - deltaW, y, -deltaX, deltaY, user.color, world.image);
                    // mirror y
                    tools.pencil(x, halfheight - deltaH, deltaX, -deltaY, user.color, world.image);
                    // mirror xy (diagonal corner)
                    tools.pencil(halfwidth - deltaW, halfheight - deltaH, -deltaX, -deltaY, user.color, world.image);
                }
            }
        },
        c.SDL_MOUSEBUTTONDOWN => {
            world.drawing = true;
            const x = event.button.x;
            const y = event.button.y;
            tools.pencil(x, y, 0, 0, user.color, world.image);
            if (event.button.button != 1) {
                draw.line2(x, x - user.lastX, y, y - user.lastY, user.color, world.image) catch unreachable;
            }
            user.lastX = x;
            user.lastY = y;
        },
        c.SDL_MOUSEBUTTONUP => {
            world.drawing = false;
        },
        c.SDL_MOUSEWHEEL => {
            // changeColors(windowWidth, windowHeight, user.color, world.bgColor, world.image);
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
            warn("Attempting to quit\n", .{});
            running.* = false;
        },
        c.SDL_WINDOWEVENT => {
            const e = event.window;
            const width = event.window.data1;
            const height = event.window.data2;
            switch (event.window.event) {
                c.SDL_WINDOWEVENT_MOVED => {},
                c.SDL_WINDOWEVENT_RESIZED => {
                    warn("window resized {}x{}\n", .{ width, height });
                    c.SDL_FreeSurface(world.surface);
                    world.surface = sdl.initSurface(world.window) catch unreachable;
                },
                c.SDL_WINDOWEVENT_SIZE_CHANGED => {}, // warn("window size changed {}x{}\n", .{ width, height }),
                c.SDL_WINDOWEVENT_EXPOSED => {
                    //world.surface = sdl.initSurface(world.window) catch unreachable;
                },
                else => warn("window event {}\n", .{event.window.event}),
            }
        },
        c.SDL_SYSWMEVENT => warn("syswm event {}\n", .{event}),
        c.SDL_TEXTINPUT => {},
        else => warn("unexpected event # {} \n", .{event.type}),
    }
}
