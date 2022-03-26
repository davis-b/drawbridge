const std = @import("std");
const log = std.log.scoped(.main);

const parser = @import("parser");

const c = @import("c.zig");
const sdl = @import("sdl/index.zig");

const net = @import("net/index.zig");
const NetAction = @import("net/actions.zig").Action;
const misc = @import("misc.zig");
const draw = @import("draw.zig");
const gui = @import("gui.zig");
const state = @import("state.zig");
const tools = @import("tools.zig");
const users = @import("users.zig");
const Whiteboard = @import("whiteboard.zig").Whiteboard;

const changeColors = c.changeColors;
const inverseColors = c.inverseColors;

const maxDrawSize: c_int = std.math.maxInt(c_int);

const Options = struct {
    ip: ?[]const u8,
    port: u16 = 8797,
    room: []const u8 = "default",
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked) std.log.default.crit("memory leak detected while quitting", .{});
    }
    var allocator = &gpa.allocator;

    const options = try parser.parseAdvanced(allocator, Options, .{ .argv = std.os.argv });

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
    var bgColor: u32 = c.SDL_MapRGB(whiteboard.surface.format, 40, 40, 40);

    var running = true;
    var local_user = users.User{};
    var peers = users.Peers.init(allocator);
    var world = state.World{
        .window = window,
        .surface = surface,
        .image = &whiteboard,
        .gui = &gui_surfaces,
        .bgColor = bgColor,
        .peers = &peers,
    };
    defer c.SDL_FreeSurface(world.surface);
    defer world.image.deinit();
    defer peers.deinit();
    world.image.updateOnParentResize(world.surface, world.gui);
    fullRender(&world);
    draw.thing(local_user.color, whiteboard.surface);
    draw.squares(whiteboard.surface);

    // Set to true if network initialization fails.
    var localOnly = false;
    // All communication will happen through these queues.
    var netPipe = net.Pipe{};
    var netThreads: [2]*std.Thread = undefined;
    var netConnection: net.mot.Connection = undefined;
    // Will not be true until we join a room and either it has no state or we receive state from someone in that room.
    var fully_joined_room = false;
    if (options.ip) |ip| netSetupBlk: {
        netConnection = net.init(allocator, ip, options.port) catch {
            localOnly = true;
            break :netSetupBlk;
        };
        errdefer netConnection.deinit();

        // This can technically block indefinitely with the right circumstances. Perhaps we should give up after x seconds?
        fully_joined_room = net.enter_room(allocator, &netConnection, options.room) catch |err| {
            switch (err) {
                error.FullRoom => {
                    localOnly = true;
                    break :netSetupBlk;
                },
                else => return err,
            }
        };
        // This will spawn a new thread which will take care of low level networking stuff.
        // If the networking thread finishes early, it will put a signal in the meta queue and wait for the queue to be emptied.
        netThreads = try net.startThreads(allocator, &netPipe, &netConnection);
    } else {
        localOnly = true;
    }

    var event: c.SDL_Event = undefined;
    log.info("running in local mode? {}", .{localOnly});
    if (localOnly) {
        while (running) {
            renderImage(world.surface, world.image);
            sdl.display.updateSurface(world.window);

            while (c.SDL_PollEvent(&event) == 1) {
                const maybe_action = onEvent(event, &world, &local_user, &running);
                if (maybe_action) |action| {
                    doAction(action, &local_user, &whiteboard);
                }
            }
        }
    } else {
        defer {
            var should_wait = true;
            netPipe.out.put(.{ .disconnect = {} }) catch {
                log.warn("unable to push exit flag to net-out-thread", .{});
                netConnection.deinit();
                should_wait = false;
            };
            if (should_wait) {
                netThreads[0].wait(); // outgoing packets thread
                // TODO reliably send an exit signal to this thread on multiple platforms.
                // netThreads[1].wait(); // incoming packets thread
                netConnection.deinit();
            }
        }
        while (running) {
            renderImage(world.surface, world.image);
            sdl.display.updateSurface(world.window);

            while (c.SDL_PollEvent(&event) == 1) {
                const maybe_action = onEvent(event, &world, &local_user, &running);
                if (maybe_action) |action| {
                    // Until we have a preview of each client's cursor set up, save bandwith by not sending out unnecessary packets.
                    // When we do send these packets, we could probably get away with sending only some of them each second.
                    switch (action) {
                        .cursor_move => {
                            if (!local_user.drawing) {
                                doAction(action, &local_user, &whiteboard);
                                continue;
                            }
                        },
                        else => {},
                    }
                    if (world.peers.count() > 0 and fully_joined_room) {
                        netPipe.out.put(.{ .action = action }) catch {
                            log.warn("Outgoing network pipe is full. Action ignored!", .{});
                            continue;
                        };
                    }
                    doAction(action, &local_user, &whiteboard);
                }
            }

            while (netPipe.in.take() catch null) |netEvent| {
                const user = world.peers.getPtr(netEvent.userID) orelse continue;
                doAction(netEvent.action, user, &whiteboard);
            }

            while (netPipe.meta.take() catch null) |metaEvent| {
                log.debug("meta event: {}", .{metaEvent});
                switch (metaEvent) {
                    .peer_entry => |userID| {
                        try world.peers.put(userID, users.User{});
                    },
                    .peer_exit => |userID| {
                        _ = world.peers.remove(userID);
                    },
                    // Disconnected from server.
                    .net_exit => {
                        // Can quit program, ask for new room, or enter local mode. Maybe local mode can also try reconnecting at will?
                        // For now, we will simply exit the program.
                        running = false;
                    },
                    // Handle whatever error occurred.
                    .err => |err| {
                        log.warn("network error: {}", .{err});
                        running = false;
                    },
                    // Our state has been queried. Add it to outgoing queue here.
                    .state_query => |our_id| {
                        // We must copy the state here in this thread before any state changes.
                        try netPipe.out.put(.{ .state = try copyState(allocator, &world, local_user, our_id) });
                    },
                    // We have been supplied with a new world state to copy.
                    .state_set => |message| {
                        fully_joined_room = true;
                        var new_state = message.state;
                        defer allocator.free(new_state.users);
                        defer allocator.free(new_state.image);
                        for (new_state.users) |u| {
                            // The state sender receives an update that we have entered the room before it sends us their state.
                            // Thus, we are included in their user list.
                            // We don't want to be in our own user list though.
                            if (u.id == message.our_id) continue;
                            try world.peers.put(u.id, u.user);
                        }
                        // NOTE this is where we might set image size, or maybe image size is set when entering a room
                        world.image.deserialize(new_state.image);
                        local_user.reset();
                    },
                }
            }
        }
    }
    log.info("Drawbridge closing.", .{});
}

/// Copies and serializes this client's current transferable state into a buffer.
/// Caller owns returned memory.
fn copyState(allocator: *std.mem.Allocator, world: *state.World, local_user: users.User, our_id: u8) ![]u8 {
    const imageData = world.image.serialize();
    var userList = try allocator.alloc(net.WorldState.UniqueUser, world.peers.count() + 1);
    defer allocator.free(userList);
    userList[0] = .{ .user = local_user, .id = our_id };
    var iter = world.peers.iterator();
    var index: usize = 1;
    while (iter.next()) |entry| {
        userList[index] = .{
            .user = entry.value_ptr.*,
            .id = entry.key_ptr.*,
        };
        index += 1;
    }
    const worldState = net.WorldState{ .image = imageData, .users = userList };

    return try net.send.serialize(allocator, .{ .state = worldState });
}

fn fullRender(world: *state.World) void {
    sdl.display.fillRect(world.surface, null, world.bgColor);
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

fn onEvent(event: c.SDL_Event, world: *state.World, user: *const users.User, running: *bool) ?NetAction {
    switch (event.type) {
        c.SDL_KEYDOWN => {
            // Both enums have same values, we're simply changing for a more convenient naming scheme
            const key = @intToEnum(sdl.keyboard.Scancode, @enumToInt(event.key.keysym.scancode));
            switch (key) {
                .Q => running.* = false,
                .A => _ = c.SDL_FillRect(world.surface, null, @truncate(u32, @intCast(u64, std.time.milliTimestamp()))),

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
                else => log.info("key pressed: {}", .{key}),
            }
        },
        c.SDL_KEYUP => {},

        c.SDL_MOUSEMOTION => {
            var x = event.motion.x;
            var y = event.motion.y;
            const in_image = coordinatesAreInImage(world.image.render_area, x, y);
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
            log.info("Attempting to quit", .{});
            running.* = false;
        },
        c.SDL_WINDOWEVENT => {
            const e = event.window;
            switch (event.window.event) {
                c.SDL_WINDOWEVENT_MOVED => {},
                c.SDL_WINDOWEVENT_RESIZED => {}, // Subset of size_changed event. Does not get triggered if resize originated from SDL code.
                c.SDL_WINDOWEVENT_SIZE_CHANGED => {
                    log.debug("window resized {}x{}", .{ e.data1, e.data2 });
                    world.surface = sdl.display.initSurface(world.window) catch unreachable;
                    world.image.updateOnParentResize(world.surface, world.gui);
                    fullRender(world);
                },
                c.SDL_WINDOWEVENT_EXPOSED => {},
                else => log.debug("window event {}", .{event.window.event}),
            }
        },
        c.SDL_SYSWMEVENT => log.debug("syswm event {}", .{event}),
        c.SDL_TEXTINPUT => {},
        else => log.warn("unexpected event # {} ", .{event.type}),
    }
    return null;
}

fn doAction(action: NetAction, user: *users.User, whiteboard: *Whiteboard) void {
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
                // or do something like this:
                // tools.pencil(move.pos.x, move.pos.y, 0, 0, user, world.surface);
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
