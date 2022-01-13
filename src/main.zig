const std = @import("std");
const warn = std.debug.warn;
const assert = std.debug.assert;

const misc = @import("misc.zig");
const draw = @import("draw.zig");
const NetAction = @import("net_actions.zig").Action;
const gui = @import("gui.zig");
const state = @import("state.zig");
const tools = @import("tools.zig");
const Whiteboard = @import("whiteboard.zig").Whiteboard;

const c = @import("c.zig");
const sdl = @import("sdl/index.zig");

const changeColors = c.changeColors;
const inverseColors = c.inverseColors;

const maxDrawSize: c_int = std.math.maxInt(c_int);

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

    var running = true;
    var local_user = state.User{ .color = 0x777777 };
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
    draw.thing(local_user.color, whiteboard.surface);
    draw.squares(whiteboard.surface);

    var event: c.SDL_Event = undefined;
    while (running) {
        renderImage(world.surface, world.image);
        sdl.display.updateSurface(world.window);
        while (c.SDL_PollEvent(&event) == 1) {
            const maybe_action = onEvent(event, &world, &local_user, &running);
            if (maybe_action) |action| {
                doAction(action, &local_user, &whiteboard);
                // send action over network, or put into an outgoing queue that is sent by other thread
            }
        }
    }
    c.SDL_Log("Drawbridge raised.\n");
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

fn onEvent(event: c.SDL_Event, world: *state.World, user: *state.User, running: *bool) ?NetAction {
    switch (event.type) {
        c.SDL_KEYDOWN => {
            // Both enums have same values, we're simply changing for a more convenient naming scheme
            const key = @intToEnum(sdl.keyboard.Scancode, @enumToInt(event.key.keysym.scancode));
            switch (key) {
                .Q => running.* = false,
                .A => _ = c.SDL_FillRect(world.surface, null, @truncate(u32, @intCast(u64, std.time.milliTimestamp()))),
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
                    return NetAction{ .color_change = color };
                },
                else => warn("key pressed: {}\n", .{key}),
            }
        },
        c.SDL_KEYUP => {},

        c.SDL_MOUSEMOTION => {
            var x = event.motion.x;
            var y = event.motion.y;
            const in_image = coordinatesAreInImage(world.image.render_area, x, y);
            // TODO
            // Does this adjust within the frame of the SDL window?
            // What we really want are the coordinates relative to the Whiteboard image itself.
            // So that in the SDL window maybe we have 500, 500. Yet it's at the top of the draw area. Also our image is cropped 100 off the top.
            // In that scenario we would want to derive 100 for y, as we're at the top of the image and it's cropped by 100.
            adjustMousePos(world.image, &x, &y);
            return NetAction{ .cursor_move = .{ .pos = .{ .x = x, .y = y }, .delta = .{ .x = event.motion.xrel, .y = event.motion.yrel } } };
        },
        c.SDL_MOUSEBUTTONDOWN => {
            var x = event.button.x;
            var y = event.button.y;
            adjustMousePos(world.image, &x, &y);
            if (coordinatesAreInImage(world.image.render_area, event.button.x, event.button.y)) {
                return NetAction{ .mouse_press = .{ .button = event.button.button, .pos = .{ .x = x, .y = y } } };
            } else {
                gui.handleButtonPress(world.surface, world.gui, event.button.x, event.button.y);
            }
        },
        c.SDL_MOUSEBUTTONUP => {
            var x = event.button.x;
            var y = event.button.y;
            adjustMousePos(world.image, &x, &y);
            return NetAction{ .mouse_release = .{ .button = event.button.button, .pos = .{ .x = x, .y = y } } };
        },
        c.SDL_MOUSEWHEEL => {
            const TOOL_RESIZE_T: type = std.meta.TagPayload(NetAction, .tool_resize);

            var new: i64 = event.wheel.y + user.size;
            misc.clamp(i64, &new, 1, std.math.maxInt(TOOL_RESIZE_T));

            const final_new = @intCast(TOOL_RESIZE_T, new);
            if (final_new != user.size) {
                return NetAction{ .tool_resize = final_new };
            }
        },
        c.SDL_QUIT => {
            warn("Attempting to quit\n", .{});
            running.* = false;
        },
        c.SDL_WINDOWEVENT => {
            const e = event.window;
            switch (event.window.event) {
                c.SDL_WINDOWEVENT_MOVED => {},
                c.SDL_WINDOWEVENT_RESIZED => {}, // Subset of size_changed event. Does not get triggered if resize originated from SDL code.
                c.SDL_WINDOWEVENT_SIZE_CHANGED => {
                    warn("window resized {}x{}\n", .{ e.data1, e.data2 });
                    world.surface = sdl.display.initSurface(world.window) catch unreachable;
                    world.image.updateOnParentResize(world.surface, world.gui);
                    fullRender(world);
                },
                c.SDL_WINDOWEVENT_EXPOSED => {},
                else => warn("window event {}\n", .{event.window.event}),
            }
        },
        c.SDL_SYSWMEVENT => warn("syswm event {}\n", .{event}),
        c.SDL_TEXTINPUT => {},
        else => warn("unexpected event # {} \n", .{event.type}),
    }
    return null;
}

fn doAction(action: NetAction, user: *state.User, whiteboard: *Whiteboard) void {
    switch (action) {
        .tool_change => |new_tool| user.tool = new_tool,
        .tool_resize => |size| user.size = size,
        .cursor_move => |move| {
            if (user.drawing) {
                tools.pencil(move.pos.x, move.pos.y, move.delta.x, move.delta.y, user, whiteboard.surface);
            } else {
                // Preview what would happen if the user started drawing.
                // TODO add a layer that allows temporary stuff like this to appear at all.
                // Perhaps we use a 'ghost' surface that gets reset and replaced repeatedly.
                // Currently the image blits on top of this and removes it.
            }
        },
        .mouse_press => |click| {
            user.drawing = true;
            const x = click.pos.x;
            const y = click.pos.y;
            tools.pencil(x, y, 0, 0, user, whiteboard.surface);
            // if (click.button != 1) { // != LMB
            //     draw.line2(x, x - user.lastX, y, y - user.lastY, user, whiteboard.surface) catch unreachable;
            // }
            user.lastX = x;
            user.lastY = y;
        },
        .mouse_release => |click| {
            user.drawing = false;
        },
        .color_change => |color| user.color = color,
        .layer_switch => |x| {
            //
        },
    }
}
