const std = @import("std");
const log = std.log.default;

const parser = @import("parser");
const mot = @import("mot");

const net = @import("net");

const Poller = @import("Poller.zig");
const misc = @import("misc.zig");
const management = @import("management.zig");
const protocol = @import("protocol.zig");
const Client = @import("client.zig").Client;
const accept_client = @import("client.zig").accept_client;

const Options = struct {
    port: u16 = 9890,
    // ip: []const u8 = "0.0.0.0",
};

// TODO should we disable forwarding packets from clients that have a packet buffer active?

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked) log.crit("memory leak detected\n", .{});
    }
    var allocator = &gpa.allocator;

    const options = try parser.parseAdvanced(allocator, Options, .{ .argv = std.os.argv });
    // const options = try parser.parse(Options, "-", false);
    // open server
    var server = try init_server(options.port);
    defer server.deinit();
    defer server.close();

    var poller = Poller.init(allocator);
    defer poller.deinit();
    try poller.add(server.sockfd.?);

    var clients = management.FdMap.init(allocator);
    defer clients.deinit();
    var rooms = management.Rooms.init(allocator);
    defer rooms.deinit();
    defer management.deinit_all_clients(&clients);

    // A list of all clients that have left or will be removed from the server.
    var leavers = management.Leavers.init(allocator);
    defer leavers.deinit();

    var recv_buffer: [1024]u8 = undefined;

    while (true) {
        try handle_leavers(&leavers, &poller, &clients);

        // Blocks until we have a fd we can read from.
        // Does not guarantee the read will be complete by the time we start.
        const readable_fd = try poller.readable();
        if (readable_fd == server.sockfd.?) {
            const new = try accept_client(allocator, &server, &leavers);
            // Register new client
            try clients.put(new.fd, new);
            try poller.add(new.fd);
            log.info("New client: {}", .{new});
            // Does not send a notify_connect signal or ask for a world state update, because it is not yet in a room.
        } else {
            const sender: *Client = clients.getPtr(readable_fd).?;
            // Partial messages are buffered until they are complete.
            const packet = sender.connection.maybe_recv(recv_buffer[0..]) catch |err| {
                log.warn("Kicking {}. Reason: recv() call failed. {}\n", .{ sender, err });
                leavers.append(sender);
                continue;
            } orelse continue; // maybe_recv has an incomplete packet
            defer allocator.free(packet);

            const unwrapped_packet = net.unwrap(.client, packet) catch {
                log.warn("Kicking {}. Reason: invalid packet.\n", .{sender});
                leavers.append(sender);
                continue;
            };

            switch (unwrapped_packet.kind) {
                .room_request => try room_request(sender, &rooms, unwrapped_packet.data),
                else => {
                    // If a client is not in a room, or is in an empty room, they should not be sending packets in the first place.
                    // However, packets could be in transit before the client gets the message that they are alone in a room.
                    if (sender.room == null) continue;
                    if (sender.room.?.count() == 1) continue;
                    switch (unwrapped_packet.kind) {
                        .room_request => unreachable,

                        // Forward world state to appropriate client.
                        .return_state => try recv_world_state(allocator, sender, unwrapped_packet.data),

                        // Forward packet to all eligible clients in same room as sender.
                        .draw_action => {
                            var new_packet = try protocol.pack_action(allocator, sender.id, unwrapped_packet.data);
                            defer allocator.free(new_packet);
                            try send_to_peers(sender, new_packet);
                        },
                    }
                },
            }
        }
    }
}

/// A client has requested to join a room.
/// Try moving that client to the room, ask a client to share world state.
fn room_request(requester: *Client, rooms: *management.Rooms, requested_room: []const u8) !void {
    const room_name = management.validate_room_name(requested_room) catch {
        log.warn("Client requested a room using a packet that was too small. This should not happen.", .{});
        _ = requester.send(protocol.pack_response(.room_full)[0..], "response: full room; invalid room name");
        return;
    };
    // If room is null, treat it as having space, as we'll create it for this user.
    if (!(rooms.room_has_space(room_name) orelse true)) {
        _ = requester.send(protocol.pack_response(.room_full)[0..], "response: full room");
        return; // If requested room is full, we will not change any state.
    }
    if (requester.room) |r| management.remove_from_room(requester);
    try rooms.add_client(requester, room_name);

    if (requester.room.?.count() == 1) {
        _ = requester.send(protocol.pack_response(.room_empty)[0..], "response: empty room");
    } else {
        requester.init_packet_buffer();
        try notify_connect(requester);
        request_world_state(requester) catch |err| {
            switch (err) {
                error.PeersUnableToSupplyState => {
                    log.warn("Non-empty room was unable to find a client without a packet history. Asking new client to try again soon.", .{});
                    const successful_send = requester.send(protocol.pack_response(.try_again)[0..], "response: try again");
                    // We don't want this client spending any more time in the room than required.
                    management.remove_from_room(requester); // safe to call multiple times.

                    // We don't want to notify more than necessary.
                    // If the send is not successful, the client will be added to the leaver's queue.
                    if (successful_send) {
                        try notify_disconnect(requester);
                    }
                    return;
                },
                else => return err,
            }
        };
        _ = requester.send(protocol.pack_response(.room_state_incoming)[0..], "response: room state incoming");
    }
}

/// Sends a 'world state query' message to a Client within the requester's room.
/// Sets up the link between the requester and requested.
/// This link will be used when the requested sends us a world state update packet.
fn request_world_state(requester: *Client) !void {
    if (requester.room) |room| {
        const person_with_state = (try room.request_world_state_source(requester)) orelse return error.PeersUnableToSupplyState;
        _ = person_with_state.send(protocol.pack_generic(.state_query, person_with_state.id)[0..], "state query");
    } else {
        return error.NullRoom;
    }
}

/// Send a packet to a Client's peers.
fn send_to_peers(sender: *Client, packet: []const u8) !void {
    if (sender.room) |room| {
        for (room.clients.items) |peer| {
            if (peer.id == sender.id) continue;
            if (peer.packet_buffer) |*packets| {
                try packets.store(packet);
            } else {
                _ = peer.send(packet, "broadcast");
            }
        }
    } else {
        log.warn("Tried to send_to_peers() with a sender that is not in a room", .{});
    }
}

/// Receives and forwards a world state.
/// After a client joins a room which is not empty,
///  we send a request to a different client in that room for 
///  the current world state.
/// When that request is responded to, this function gets called.
fn recv_world_state(allocator: *std.mem.Allocator, sender: *Client, packet: []const u8) !void {
    const recipient = blk: {
        if (sender.room) |room| {
            if (room.find_world_state_recipient(sender)) |receiver| {
                break :blk receiver;
            } else {
                // Likely the recipient has left the room already. Do nothing.
                log.info("Client {} tried sending a world_state update packet. Unable to find recipient in same room.", .{sender});
                return;
            }
        } else {
            log.info("Client {} tried sending a world_state update packet. Client is not in a room.", .{sender});
            return;
        }
    };

    const new_packet = try protocol.pack_world_update(allocator, packet);
    defer allocator.free(new_packet);

    if (recipient.packet_buffer) |*packets| {
        _ = recipient.send(new_packet, "world state update");
        for (packets.items()) |old_packet| {
            // Skip old packets from the world state sender. They are already included in the world state.
            if (protocol.action_sender_id(old_packet) != sender.id) {
                _ = recipient.send(old_packet, "replaying old packets");
            }
        }
        packets.deinit();
        recipient.packet_buffer = null;
    } else {
        // Is the recipient in an invalid state, or is there a network delay causing this?
        log.err("A world state update was sent from '{}', to '{}'. However, the recipient does not have a packet history.", .{ sender, recipient });
    }
}

/// Completely purges a client from the server.
fn purge_client(client: *Client, poller: *Poller, clients: *management.FdMap) !void {
    try notify_disconnect(client);
    management.remove_from_room(client);
    try poller.remove(client.fd);
    client.deinit();
    _ = clients.remove(client.fd);
}

/// Notify a client's peers when it disconnects from a room.
fn notify_disconnect(client: *Client) !void {
    try send_to_peers(client, protocol.pack_generic(.peer_exit, client.id)[0..]);
}

/// Notify a client's peers when it connects to a room.
fn notify_connect(client: *Client) !void {
    try send_to_peers(client, protocol.pack_generic(.peer_entry, client.id)[0..]);
}

/// Handle clients that have left or have been flagged for removal.
fn handle_leavers(leavers: *management.Leavers, poller: *Poller, clients: *management.FdMap) !void {
    var processed_leavers: usize = 0;
    // If new leavers are added while purging a client, handle them here until there are no more leavers.
    while (leavers.clients.items.len > processed_leavers) {
        const new_start_index = processed_leavers;
        // Set this now, as it could increase during the 'purge_client()' call.
        processed_leavers = leavers.clients.items.len;
        for (leavers.clients.items[new_start_index..]) |client| {
            try purge_client(client, poller, clients);
        }
    }
    // Remove all elements from the array.
    leavers.clients.clearAndFree();
}

fn init_server(port: u16) !std.net.StreamServer {
    var server = std.net.StreamServer.init(.{ .reuse_address = true });
    errdefer server.deinit();
    errdefer server.close();

    const addr = try std.net.Address.resolveIp("0.0.0.0", port);
    log.debug("starting server at: {}", .{addr});
    try server.listen(addr);
    return server;
}
