const std = @import("std");
const log = std.log.scoped(.main);

const parser = @import("parser");

const c = @import("c.zig");
const sdl = @import("sdl/index.zig");

const Dot = @import("misc.zig").Dot;
const net = @import("net/index.zig");
const NetAction = @import("net/actions.zig").Action;
const misc = @import("misc.zig");
const draw = @import("draw.zig");
const gui = @import("gui/index.zig");
const state = @import("state.zig");
const tools = @import("tools.zig");
const users = @import("users.zig");
const Whiteboard = @import("whiteboard.zig").Whiteboard;
const text = @import("gui/font.zig");

const changeColors = c.changeColors;
const inverseColors = c.inverseColors;

const maxDrawSize: c_int = std.math.maxInt(c_int);

const Options = struct {
    ip: ?[]const u8,
    port: u16 = 9890,
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

    const surface = try sdl.display.getWindowSurface(window);
    var gui_surfaces = try gui.init();

    const image_width = 1300;
    const image_height = 800;
    var whiteboard = try Whiteboard.init(surface, &gui_surfaces, image_width, image_height);
    sdl.display.fillRect(whiteboard.surface, null, whiteboard.bgColor);
    var bgColor: u32 = sdl.display.mapRGBA(.{ 30, 30, 50, 255 }, surface.format);

    var running = true;
    var localUser = users.User{};
    var peers = users.Peers.init(allocator);
    var world = state.World{
        .window = window,
        .surface = surface,
        .image = &whiteboard,
        .gui = &gui_surfaces,
        .bgColor = bgColor,
        .peers = &peers,
        .user = &localUser,
    };
    defer c.SDL_FreeSurface(world.surface);
    defer world.image.deinit();
    defer peers.deinit();
    world.image.updateOnParentResize(world.surface, world.gui);
    fullRender(&world);
    draw.squares(whiteboard.surface);

    // Set to true if network initialization fails.
    var localOnly = true;
    // All communication will happen through these queues.
    var netPipe = net.Pipe{};
    var netThreads: [2]*std.Thread = undefined;
    var netConnection: net.Connection = undefined;
    // Will not be true until we join a room and either it has no state or we receive state from someone in that room.
    var fully_joined_room = false;
    if (options.ip) |ip| netSetupBlk: {
        netConnection = net.init(allocator, ip, options.port) catch {
            break :netSetupBlk;
        };
        errdefer netConnection.deinit();

        // This can technically block indefinitely with the right circumstances. Perhaps we should give up after x seconds?
        fully_joined_room = net.enter_room(allocator, &netConnection, options.room) catch |err| {
            switch (err) {
                error.FullRoom => {
                    break :netSetupBlk;
                },
                else => return err,
            }
        };
        // This will spawn a new thread which will take care of low level networking stuff.
        // If the networking thread finishes early, it will put a signal in the meta queue and wait for the queue to be emptied.
        netThreads = try net.startThreads(allocator, &netPipe, &netConnection);
        localOnly = false;
    }

    var event: c.SDL_Event = undefined;
    log.info("running in local mode? {}", .{localOnly});
    if (localOnly) {
        while (running) {
            const start = std.time.milliTimestamp();
            defer {
                const end = std.time.milliTimestamp();
                const delta = end - start;
                if (delta < 16) {
                    const sleepTime = @intCast(usize, 16 - delta);
                    std.time.sleep(sleepTime * std.time.ns_per_ms);
                }
            }

            if (world.shouldRender) {
                renderImage(world.surface, world.image);
                world.shouldRender = false;
            }
            sdl.display.updateSurface(world.window);

            while (c.SDL_PollEvent(&event) == 1) {
                const maybe_action = onEvent(event, &world, world.user, &running);
                if (maybe_action) |action| {
                    doAction(action, world.user, &world, false);
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
            net.deinit() catch |err| {
                log.err("Error cleaning up networking {}", .{err});
            };
        }
        var lastPeerUpdate: i64 = 0;
        while (running) {
            const start = std.time.milliTimestamp();
            defer {
                if (fully_joined_room and start > lastPeerUpdate + 500) {
                    gui.updatePeers(&world);
                    lastPeerUpdate = start;
                }
                const end = std.time.milliTimestamp();
                const delta = end - start;
                if (delta < 16) {
                    const sleepTime = @intCast(usize, 16 - delta);
                    std.time.sleep(sleepTime * std.time.ns_per_ms);
                }
            }

            if (!fully_joined_room) {
                // Draw a loading indicator that changes with time, to indicate to the user that they are loading into a room.
                if (start > lastPeerUpdate + 400) {
                    var random = std.rand.DefaultPrng.init(@bitCast(u64, std.time.milliTimestamp()));
                    draw.circleFilled(.{ .x = 340, .y = 300 }, 30, random.random.int(u32), world.image.surface);
                    draw.circleFilled(.{ .x = 380, .y = 300 }, 30, random.random.int(u32), world.image.surface);
                    draw.circleFilled(.{ .x = 420, .y = 300 }, 30, random.random.int(u32), world.image.surface);
                    const textColor = sdl.display.mapRGBA(.{ 180, 50, 120, 255 }, world.image.surface.format);
                    text.write(world.image.surface, "loading room", .{ .x = 270, .y = 350 }, 3, textColor, 500);

                    world.shouldRender = true;
                    lastPeerUpdate = start;
                }
            }
            if (world.shouldRender) {
                renderImage(world.surface, world.image);
                world.shouldRender = false;
            }
            sdl.display.updateSurface(world.window);

            while (c.SDL_PollEvent(&event) == 1) {
                const maybe_action = onEvent(event, &world, world.user, &running);
                if (maybe_action) |action| {
                    // Until we have a preview of each client's cursor set up, save bandwith by not sending out unnecessary packets.
                    // When we do send these packets, we could probably get away with sending only some of them each second.
                    switch (action) {
                        .cursor_move => {
                            if (!world.user.drawing) {
                                doAction(action, world.user, &world, false);
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
                    doAction(action, world.user, &world, false);
                }
            }

            while (netPipe.in.take() catch null) |netEvent| {
                const user = world.peers.getPtr(netEvent.userID) orelse continue;
                doAction(netEvent.action, user, &world, true);
                user.lastActive = std.time.milliTimestamp(); // limit the number of times this can update per peer per second
            }

            while (netPipe.meta.take() catch null) |metaEvent| {
                log.debug("meta event: {}", .{metaEvent});
                switch (metaEvent) {
                    .peer_entry => |userID| {
                        try world.peers.put(userID, users.User{});
                        gui.updatePeers(&world);
                    },
                    .peer_exit => |userID| {
                        _ = world.peers.remove(userID);
                        gui.updatePeers(&world);
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
                        try netPipe.out.put(.{ .state = try copyState(allocator, &world, our_id) });
                    },
                    // We have been supplied with a new world state to copy.
                    .state_set => |message| {
                        fully_joined_room = true;
                        world.shouldRender = true;
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
                        world.user.reset();
                        gui.updatePeers(&world);
                    },
                }
            }
        }
    }
    log.info("Drawbridge closing.", .{});
}

/// Copies and serializes this client's current transferable state into a buffer.
/// Caller owns returned memory.
fn copyState(allocator: *std.mem.Allocator, world: *state.World, our_id: u8) ![]u8 {
    const imageData = world.image.serialize();
    var userList = try allocator.alloc(net.WorldState.UniqueUser, world.peers.count() + 1);
    defer allocator.free(userList);
    userList[0] = .{ .user = world.user.*, .id = our_id };
    userList[0].user.lastActive = std.time.milliTimestamp();
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
    gui.draw.Draw.all(world.gui, world.peers, world.user);
    gui.blitAll(world.surface, world.gui);
}

fn renderImage(dst: *sdl.Surface, whiteboard: *Whiteboard) void {
    var image_rect = sdl.Rect{
        .x = whiteboard.crop_offset.x,
        .y = whiteboard.crop_offset.y,
        .w = whiteboard.render_area.w,
        .h = whiteboard.render_area.h,
    };

    sdl.display.blit(whiteboard.surface, &image_rect, dst, &whiteboard.render_area);
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

                .N_7 => {
                    world.shouldRender = true;
                    world.image.modifyCropOffset(-20, null);
                },
                .N_8 => {
                    world.shouldRender = true;
                    world.image.modifyCropOffset(20, null);
                },
                .N_9 => {
                    world.shouldRender = true;
                    world.image.modifyCropOffset(null, -20);
                },
                .N_0 => {
                    world.shouldRender = true;
                    world.image.modifyCropOffset(null, 20);
                },

                .C => {
                    const cPixels = @alignCast(4, world.surface.pixels.?);
                    const pixels = @ptrCast([*]u32, cPixels);
                    const pos = getMousePos(world.surface.w);
                    const rgba = sdl.display.getRGBA(pixels[pos], world.surface.format);
                    return NetAction{ .color_change = sdl.display.mapRGBA(rgba, world.image.surface.format) };
                },

                .B, .W, .N_1 => return NetAction{ .tool_change = .pencil },
                .E, .N_2 => return NetAction{ .tool_change = .eraser },
                .G, .N_3 => return NetAction{ .tool_change = .bucket },
                .N_4 => return NetAction{ .tool_change = .color_picker },
                else => {},
            }
        },
        c.SDL_KEYUP => {},

        c.SDL_MOUSEMOTION => {
            var x = event.motion.x;
            var y = event.motion.y;
            // Pan around a cropped image if we are holding the middle mouse button.
            if ((event.motion.state & c.SDL_BUTTON_MMASK) != 0) {
                world.image.modifyCropOffset(-event.motion.xrel, -event.motion.yrel);
                world.shouldRender = true;
                return null;
            }
            if (coordinatesAreInImage(world.image.render_area, x, y)) {
                adjustMousePos(world.image, &x, &y);
                return NetAction{ .cursor_move = .{ .pos = .{ .x = x, .y = y }, .delta = .{ .x = event.motion.xrel, .y = event.motion.yrel } } };
            } else {
                const pos = Dot{ .x = event.motion.x, .y = event.motion.y };
                const delta = Dot{ .x = event.motion.xrel, .y = event.motion.yrel };
                const clicking = (event.motion.state & c.SDL_BUTTON_LMASK) != 0;
                const guiEvent = gui.events.handleMotion(
                    world.surface,
                    world.gui,
                    world.user,
                    clicking and !world.user.drawing,
                    pos,
                    delta,
                    world.image.surface.format,
                );
                if (guiEvent) |ge| {
                    switch (ge) {
                        .tool_resize_slider => |percent| {
                            const TOOL_RESIZE_T: type = std.meta.TagPayload(NetAction, .tool_resize);
                            const new = gui.header_info.ToolSize.applySlideEvent(TOOL_RESIZE_T, percent, world.user.size, std.math.maxInt(TOOL_RESIZE_T));
                            return NetAction{ .tool_resize = std.math.max(1, new) };
                        },
                        .tool_recolor => |color| {
                            return NetAction{ .color_change = color };
                        },
                        .tool_change => |_| unreachable,
                    }
                }
            }
        },
        c.SDL_MOUSEBUTTONDOWN => {
            var x = event.button.x;
            var y = event.button.y;
            adjustMousePos(world.image, &x, &y);
            if (coordinatesAreInImage(world.image.render_area, event.button.x, event.button.y)) {
                // Ensure we aren't panning using middle mouse button.
                if (event.button.button != 2) {
                    return NetAction{ .mouse_press = .{ .button = event.button.button, .pos = .{ .x = x, .y = y } } };
                }
            } else {
                const guiEvent = gui.events.handleButtonPress(
                    world.surface,
                    world.gui,
                    world.user,
                    .{ .x = event.button.x, .y = event.button.y },
                    world.image.surface.format,
                );
                if (guiEvent) |ge| {
                    switch (ge) {
                        .tool_change => |tool| {
                            return NetAction{ .tool_change = tool };
                        },
                        .tool_resize_slider => |percent| {
                            const TOOL_RESIZE_T: type = std.meta.TagPayload(NetAction, .tool_resize);
                            const new = gui.header_info.ToolSize.applySlideEvent(TOOL_RESIZE_T, percent, world.user.size, std.math.maxInt(TOOL_RESIZE_T));
                            return NetAction{ .tool_resize = std.math.max(1, new) };
                        },
                        .tool_recolor => |color| {
                            return NetAction{ .color_change = color };
                        },
                    }
                }
            }
        },
        c.SDL_MOUSEBUTTONUP => {
            // Ensure we aren't panning using middle mouse button.
            if (event.button.button != 2) {
                var x = event.button.x;
                var y = event.button.y;
                adjustMousePos(world.image, &x, &y);
                return NetAction{ .mouse_release = .{ .button = event.button.button, .pos = .{ .x = x, .y = y } } };
            }
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
                    world.surface = sdl.display.getWindowSurface(world.window) catch unreachable;
                    world.image.updateOnParentResize(world.surface, world.gui);
                    fullRender(world);
                },
                c.SDL_WINDOWEVENT_EXPOSED => {},
                else => {},
            }
        },
        c.SDL_SYSWMEVENT => log.debug("syswm event {}", .{event}),
        c.SDL_TEXTINPUT => {},
        else => log.warn("unexpected event # {} ", .{event.type}),
    }
    return null;
}

fn doAction(action: NetAction, user: *users.User, world: *state.World, fromNet: bool) void {
    switch (action) {
        .tool_change => |new_tool| {
            user.tool = new_tool;
            if (fromNet) {
                gui.updatePeers(world);
            } else {
                gui.updateTools(world);
                gui.updateHeader(world);
            }
            user.lastX = -1;
            user.lastY = -1;
        },
        .tool_resize => |size| {
            user.size = size;
            if (!fromNet) {
                gui.updateHeader(world);
            }
        },
        .cursor_move => |move| {
            switch (user.tool) {
                .pencil => {
                    if (user.drawing) {
                        world.shouldRender = true;
                        tools.pencil(move.pos, move.delta, user.size, user.color, world.image.surface);
                        user.lastX = move.pos.x;
                        user.lastY = move.pos.y;
                    }
                },
                .eraser => {
                    if (user.drawing) {
                        world.shouldRender = true;
                        tools.pencil(move.pos, move.delta, user.size, world.image.bgColor, world.image.surface);
                    }
                },
                .bucket, .color_picker => {},
            }
        },
        .mouse_press => |click| {
            world.shouldRender = true;
            user.drawing = true;
            const x = click.pos.x;
            const y = click.pos.y;
            switch (user.tool) {
                .pencil => {
                    tools.pencil(click.pos, .{ .x = 0, .y = 0 }, user.size, user.color, world.image.surface);
                    if (click.button != 1 and user.lastX >= 0 and user.lastY >= 0) { // != LMB
                        draw.line2(x, x - user.lastX, y, y - user.lastY, user.color, world.image.surface) catch unreachable;
                    }
                    user.lastX = x;
                    user.lastY = y;
                },
                .eraser => {
                    tools.pencil(click.pos, .{ .x = 0, .y = 0 }, user.size, world.image.bgColor, world.image.surface);
                },
                .bucket => {
                    tools.bucket(click.pos, user.color, world.image.surface);
                },
                .color_picker => return doAction(
                    NetAction{ .color_change = tools.color_picker(click.pos, world.image.surface) },
                    user,
                    world,
                    fromNet,
                ),
            }
        },
        .mouse_release => |click| {
            user.drawing = false;
        },
        .color_change => |color| {
            user.color = color;
            if (!fromNet) {
                gui.updateHeader(world);
                gui.updateFooter(world);
            }
        },
        .layer_switch => |x| {
            //
        },
    }
}
