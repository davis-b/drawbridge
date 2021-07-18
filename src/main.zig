const std = @import("std");
const os = std.os;
const math = std.math;
const warn = std.debug.warn;
const assert = std.debug.assert;

const draw = @import("draw.zig");
const tools = @import("tools.zig");
const state = @import("state.zig");
const gui = @import("gui.zig");
const Dot = @import("misc.zig").Dot;
const Whiteboard = @import("whiteboard.zig").Whiteboard;

const c = @import("c.zig");
const sdl = @import("sdl/index.zig");

const changeColors = c.changeColors;
const inverseColors = c.inverseColors;

const maxDrawSize: c_int = math.maxInt(c_int);

pub fn main() !void {
    try sdl.init();
    errdefer sdl.deinit();
    const cursor = try sdl.mouse.createSystemCursor(.crosshair);
    defer c.SDL_FreeCursor(cursor);
    c.SDL_SetCursor(cursor);
    const window = try sdl.display.initWindow(1500, 1000);
    defer c.SDL_DestroyWindow(window);
    const surface = try sdl.display.initSurface(window);

    var gui_surfaces = try gui.init();

    const image_width = 1300;
    const image_height = 800;
    var whiteboard = try Whiteboard.init(surface, &gui_surfaces, image_width, image_height);
    var bg_color: u32 = c.SDL_MapRGB(whiteboard.surface.format, 40, 40, 40);
    var fgColor: u32 = c.SDL_MapRGB(whiteboard.surface.format, 150, 150, 150);

    var running = true;
    var user = state.User{ .size = 10, .color = 0x777777 };
    var world = state.World{
        .window = window,
        .surface = surface,
        .image = &whiteboard,
        .gui = &gui_surfaces,
        .bg_color = bg_color,
    };
    defer c.SDL_FreeSurface(world.surface);
    defer world.image.deinit();
    world.image.updateOnParentResize(world.surface, world.gui);
    fullRender(&world);
    draw.thing(fgColor, whiteboard.surface);
    draw.squares(whiteboard.surface);

    var event: c.SDL_Event = undefined;
    while (running) {
        renderImage(world.surface, world.image);
        sdl.display.updateSurface(world.window);
        _ = c.SDL_WaitEvent(&event);
        try onEvent(event, &user, &world, &running);
    }
    c.SDL_Log("pong\n");
}

fn fullRender(world: *state.World) void {
    sdl.display.fillRect(world.surface, null, world.bg_color);
    renderImage(world.surface, world.image);
    gui.drawAll(world.gui);
    gui.blitAll(world.surface, world.gui);
}

fn renderImage(dst: *sdl.Surface, whiteboard: *Whiteboard) void {
    var image_rect = sdl.Rect{
        .x = whiteboard.crop_offset.x,
        .y = whiteboard.crop_offset.y,
        .w = whiteboard.render_area.w,
        .h = whiteboard.render_area.h,
    };

    // TODO investigate using this
    //  alternate method of clipping image into destination surface.
    // Interesting side effect is no longer needing 'adjustMousePos' fn.
    // Fullscreen fps seems to increase as well.
    if (false) {
        _ = c.SDL_SetClipRect(dst, &whiteboard.render_area);
        sdl.display.blit(whiteboard.surface, null, dst, null);
        _ = c.SDL_SetClipRect(dst, null);
    } else {
        sdl.display.blit(whiteboard.surface, &image_rect, dst, &whiteboard.render_area);
    }
}

/// Returns mouse position as a single integer
fn getMousePos(window_width: c_int) usize {
    var x: c_int = 0;
    var y: c_int = 0;
    const mstate = c.SDL_GetMouseState(&x, &y);
    const pos = (y * window_width) + x;
    return @intCast(usize, pos);
}

fn coordinatesAreInImage(render_area: sdl.Rect, x: c_int, y: c_int) bool {
    return (x > render_area.x and x < (render_area.x + render_area.w) and y > render_area.y and y < (render_area.y + render_area.h));
}

/// Mouse events will not, by default, give us the correct position for our use case.
/// This is because we blit our drawable surface at an offset.
/// This function adjusts coordinates to account for the offset, ensuring we 'draw' where expected.
fn adjustMousePos(image: *Whiteboard, x: *c_int, y: *c_int) void {
    x.* += image.crop_offset.x - image.render_area.x;
    y.* += image.crop_offset.y - image.render_area.y;
}

fn onEvent(event: c.SDL_Event, user: *state.User, world: *state.World, running: *bool) !void {
    switch (event.type) {
        c.SDL_KEYDOWN => {
            // Both enums have same values, we're simply changing for a more convenient naming scheme
            const key = @intToEnum(sdl.keyboard.Scancode, @enumToInt(event.key.keysym.scancode));
            switch (key) {
                .Q => running.* = false,
                .A => _ = c.SDL_FillRect(world.surface, null, @truncate(u32, std.time.milliTimestamp())),
                .M => world.mirrorDrawing = !world.mirrorDrawing,

                .N_1 => world.image.modifyCropOffset(-20, null),
                .N_2 => world.image.modifyCropOffset(20, null),
                .N_3 => world.image.modifyCropOffset(null, -20),
                .N_4 => world.image.modifyCropOffset(null, 20),

                .C => {
                    const cPixels = @alignCast(4, world.surface.pixels.?);
                    const pixels = @ptrCast([*]u32, cPixels);
                    const pos = getMousePos(world.surface.w);
                    const color = pixels[pos];
                    user.color = color;
                },
                else => warn("key pressed: {}\n", .{key}),
            }
        },
        c.SDL_KEYUP => {},

        c.SDL_MOUSEMOTION => {
            if (user.drawing and coordinatesAreInImage(world.image.render_area, event.motion.x, event.motion.y)) {
                //warn("Motion: x:{} y:{}  xrel: {}  yrel: {}\n", event.motion.x, event.motion.y, event.motion.xrel, event.motion.yrel);
                var x = event.motion.x;
                var y = event.motion.y;
                adjustMousePos(world.image, &x, &y);
                const deltaX = event.motion.xrel;
                const deltaY = event.motion.yrel;
                tools.pencil(x, y, deltaX, deltaY, user.color, world.image.surface);
                if (world.mirrorDrawing) {
                    const halfwidth = @divFloor(world.image.surface.w, 2);
                    const halfheight = @divFloor(world.image.surface.h, 2);
                    const deltaW = x - halfwidth;
                    const deltaH = y - halfheight;
                    // mirror x
                    tools.pencil(halfwidth - deltaW, y, -deltaX, deltaY, user.color, world.image.surface);
                    // mirror y
                    tools.pencil(x, halfheight - deltaH, deltaX, -deltaY, user.color, world.image.surface);
                    // mirror xy (diagonal corner)
                    tools.pencil(halfwidth - deltaW, halfheight - deltaH, -deltaX, -deltaY, user.color, world.image.surface);
                }
            }
        },
        c.SDL_MOUSEBUTTONDOWN => {
            user.drawing = true;
            var x = event.button.x;
            var y = event.button.y;
            adjustMousePos(world.image, &x, &y);
            if (coordinatesAreInImage(world.image.render_area, event.button.x, event.button.y)) {
                tools.pencil(x, y, 0, 0, user.color, world.image.surface);
                if (event.button.button != 1) {
                    draw.line2(x, x - user.lastX, y, y - user.lastY, user.color, world.image.surface) catch unreachable;
                }
            } else {
                gui.handleButtonPress(world.surface, world.gui, event.button.x, event.button.y);
            }
            user.lastX = x;
            user.lastY = y;
        },
        c.SDL_MOUSEBUTTONUP => {
            user.drawing = false;
        },
        c.SDL_MOUSEWHEEL => {
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
                    world.surface = sdl.display.initSurface(world.window) catch unreachable;
                    world.image.updateOnParentResize(world.surface, world.gui);
                    fullRender(world);
                },
                c.SDL_WINDOWEVENT_SIZE_CHANGED => {}, // warn("window size changed {}x{}\n", .{ width, height }),
                c.SDL_WINDOWEVENT_EXPOSED => {},
                else => warn("window event {}\n", .{event.window.event}),
            }
        },
        c.SDL_SYSWMEVENT => warn("syswm event {}\n", .{event}),
        c.SDL_TEXTINPUT => {},
        else => warn("unexpected event # {} \n", .{event.type}),
    }
}
