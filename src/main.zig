const std = @import("std");
const os = std.os;
const math = std.math;
const warn = std.debug.warn;
const assert = std.debug.assert;

const draw = @import("draw.zig");
const tools = @import("tools.zig");
const state = @import("state.zig");
const gui = @import("gui.zig");

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

    const image_width = 1300;
    const image_height = 800;
    const surface_draw = try sdl.display.initRgbSurface(0, image_width, image_height, 24);
    var bg_color: u32 = c.SDL_MapRGB(surface_draw.format, 40, 40, 40);
    var fgColor: u32 = c.SDL_MapRGB(surface_draw.format, 150, 150, 150);

    var gui_surfaces = try gui.init();
    var image_area: sdl.Rect = getImageArea(surface, surface_draw, &gui_surfaces);

    var running = true;
    var user = state.User{ .size = 10, .color = 0x777777 };
    var world = state.World{
        .window = window,
        .surface = surface,
        .image = surface_draw,
        .image_area = &image_area,
        .image_offset = .{ .x = 0, .y = 0 },
        .gui = &gui_surfaces,
        .bg_color = bg_color,
    };
    defer c.SDL_FreeSurface(world.surface);
    defer c.SDL_FreeSurface(world.image);
    updateSize(&world);
    fullRender(&world);
    draw.thing(fgColor, surface_draw);
    draw.squares(surface_draw);

    var event: c.SDL_Event = undefined;
    while (running) {
        renderImage(world.surface, world.image, world.image_area, world.image_offset);
        sdl.display.updateSurface(world.window);
        _ = c.SDL_WaitEvent(&event);
        try onEvent(event, &user, &world, &running);
    }
    c.SDL_Log("pong\n");
}

/// Returns a rectangle representing the available area that our image can be blitted to
///  while respecting the gui.
fn getImageArea(main_surface: *sdl.Surface, image: *sdl.Surface, gui_surfaces: *gui.Surfaces) sdl.Rect {
    var image_area = sdl.Rect{
        .x = gui_surfaces.left.w,
        .y = gui_surfaces.header.h,
        .w = main_surface.w - (gui_surfaces.left.w + gui_surfaces.right.w),
        .h = main_surface.h - (gui_surfaces.footer.h + gui_surfaces.header.h),
    };
    // Places image in middle of available image area. Only necessary if image is not being cropped.
    if (image.w < image_area.w - gui_surfaces.left.w) {
        image_area.x = @divFloor((image_area.w - image.w) + gui_surfaces.right.w, 2);
    }
    return image_area;
}

fn clampImageOffset(image: *sdl.Surface, image_area: *sdl.Rect, offset: *state.Dot) void {
    clamp(c_int, &offset.x, 0, image.w - image_area.w);
    clamp(c_int, &offset.y, 0, image.h - image_area.h);
}

fn modifyImageOffset(world: *state.World, newx: ?c_int, newy: ?c_int) void {
    if (newx) |x| world.image_offset.x += x;
    if (newy) |y| world.image_offset.y += y;
    clampImageOffset(world.image, world.image_area, &world.image_offset);
}

/// Updates world attributes that should change on resize
fn updateSize(world: *state.World) void {
    world.image_area.* = getImageArea(world.surface, world.image, world.gui);
    clampImageOffset(world.image, world.image_area, &world.image_offset);
}

fn fullRender(world: *state.World) void {
    sdl.display.fillRect(world.surface, null, world.bg_color);
    renderImage(world.surface, world.image, world.image_area, world.image_offset);
    gui.drawAll(world.gui);
    gui.blitAll(world.surface, world.gui);
}

fn renderImage(dst: *sdl.Surface, image: *sdl.Surface, image_area: *sdl.Rect, image_offset: state.Dot) void {
    var image_rect = sdl.Rect{ .x = image_offset.x, .y = image_offset.y, .w = image_area.w, .h = image_area.h };
    // var rect = sdl.Rect{ .x = image_offset.x, .y = image_offset.y, .w = image_area.w, .h = image_area.h };
    sdl.display.blit(image, &image_rect, dst, image_area);
    // TODO investigate using this
    //  alternate method of clipping image into destination surface.
    // Interesting side effect is no longer needing 'adjustMousePos' fn.
    // Fullscreen fps seems to increase as well.
    if (false) {
        _ = c.SDL_SetClipRect(dst, image_area);
        sdl.display.blit(image, null, dst, null);
        _ = c.SDL_SetClipRect(dst, null);
    }
}

fn clamp(comptime T: type, item: *T, min: T, max: T) void {
    if (item.* > max) item.* = max;
    if (item.* < min) item.* = min;
}

/// Returns mouse position as a single integer
fn getMousePos(window_width: c_int) usize {
    var x: c_int = 0;
    var y: c_int = 0;
    const mstate = c.SDL_GetMouseState(&x, &y);
    const pos = (y * window_width) + x;
    return @intCast(usize, pos);
}

fn coordinatesAreInImage(image_area: *sdl.Rect, x: c_int, y: c_int) bool {
    return (x > image_area.x and x < (image_area.x + image_area.w) and y > image_area.y and y < (image_area.y + image_area.h));
}

/// Mouse events will not, by default, give us the correct position for our use case.
/// This is because we blit our drawable surface at an offset.
/// This function adjusts coordinates to account for the offset, ensuring we 'draw' where expected.
fn adjustMousePos(image_area: *sdl.Rect, x: *c_int, y: *c_int) void {
    x.* = x.* - image_area.x;
    y.* = y.* - image_area.y;
}

fn onEvent(event: c.SDL_Event, user: *state.User, world: *state.World, running: *bool) !void {
    switch (event.type) {
        c.SDL_KEYDOWN => {
            const key = event.key.keysym.scancode;
            switch (key) {
                c.SDL_Scancode.SDL_SCANCODE_Q => running.* = false,
                c.SDL_Scancode.SDL_SCANCODE_A => _ = c.SDL_FillRect(world.surface, null, @truncate(u32, std.time.milliTimestamp())),
                c.SDL_Scancode.SDL_SCANCODE_M => world.mirrorDrawing = !world.mirrorDrawing,

                c.SDL_Scancode.SDL_SCANCODE_1 => modifyImageOffset(world, -20, null),
                c.SDL_Scancode.SDL_SCANCODE_2 => modifyImageOffset(world, 20, null),
                c.SDL_Scancode.SDL_SCANCODE_3 => modifyImageOffset(world, null, -20),
                c.SDL_Scancode.SDL_SCANCODE_4 => modifyImageOffset(world, null, 20),

                c.SDL_Scancode.SDL_SCANCODE_C => {
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
            if (world.drawing and coordinatesAreInImage(world.image_area, event.motion.x, event.motion.y)) {
                //warn("Motion: x:{} y:{}  xrel: {}  yrel: {}\n", event.motion.x, event.motion.y, event.motion.xrel, event.motion.yrel);
                var x = event.motion.x;
                var y = event.motion.y;
                adjustMousePos(world.image_area, &x, &y);
                const deltaX = event.motion.xrel;
                const deltaY = event.motion.yrel;
                tools.pencil(x, y, deltaX, deltaY, user.color, world.image);
                if (world.mirrorDrawing) {
                    const halfwidth = @divFloor(world.image.w, 2);
                    const halfheight = @divFloor(world.image.h, 2);
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
            if (coordinatesAreInImage(world.image_area, event.button.x, event.button.y)) {
                world.drawing = true;
                var x = event.button.x;
                var y = event.button.y;
                adjustMousePos(world.image_area, &x, &y);
                tools.pencil(x, y, 0, 0, user.color, world.image);
                if (event.button.button != 1) {
                    draw.line2(x, x - user.lastX, y, y - user.lastY, user.color, world.image) catch unreachable;
                }
                user.lastX = x;
                user.lastY = y;
            }
        },
        c.SDL_MOUSEBUTTONUP => {
            world.drawing = false;
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
                    updateSize(world);
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
