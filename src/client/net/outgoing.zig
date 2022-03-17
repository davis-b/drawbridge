const std = @import("std");

const net = @import("net");
const cereal = @import("cereal");

const ThreadContext = @import("index.zig").ThreadContext;
const DrawAction = @import("actions.zig").Action;
const WorldState = @import("world_state.zig").WorldState;

/// Delivered from the main thread, to be sent to the server.
pub const ToForward = union(enum) {
    action: DrawAction,

    /// The world state bytes must be created in the main thread.
    /// They cannot be freed until after they are sent out to the server.
    state: []u8,

    exit: void,
};

/// Data to be serialized.
pub const Serializable = union(enum) {
    /// This is an unchanging struct, and can be serialized from this thread.
    action: DrawAction,

    /// This however, is created from an ever-changing world state.
    /// Therefore it must be serialized from the main thread, to avoid desync issues.
    state: WorldState,
};

pub fn startSending(context: ThreadContext) void {
    while (true) {
        const event = context.pipe.out.wait(null) catch unreachable;
        var packetBytes: []u8 = undefined;
        switch (event) {
            .action => |action| {
                packetBytes = serialize(context.allocator, .{ .action = action }) catch |err| {
                    std.debug.print("error while serializing outgoing packet: {}\n", .{err});
                    context.pipe.meta.put(.net_exit) catch {
                        std.debug.print("Network write thread encountered a queue error while exiting due to memory allocation error.\n", .{});
                    };
                    break;
                };
            },
            .state => |world_bytes| {
                packetBytes = world_bytes;
            },
            .exit => {
                const exit_packet = [1]u8{@enumToInt(net.FromClient.Kind.disconnect)};
                context.client.send(exit_packet[0..]) catch |err| {
                    std.debug.print("Error while sending 'disconnect' packet to server ({})\n", .{err});
                };
                std.debug.print("Exiting network out thread\n", .{});
                break;
            },
        }

        defer context.allocator.free(packetBytes);
        context.client.send(packetBytes) catch |err| {
            std.debug.print("error while sending packet: {}\n", .{err});
            context.pipe.meta.put(.net_exit) catch {
                std.debug.print("Network write thread encountered a queue error while exiting.\n", .{});
            };
            break;
        };
    }
}

pub fn serialize(allocator: *std.mem.Allocator, event: Serializable) ![]u8 {
    var buffer: []u8 = undefined;
    switch (event) {
        .action => |data| {
            buffer = try allocator.alloc(u8, cereal.size_of(data) + 1);
            // Dedicate the 0th index in the packet to indicating this packet type to the server.
            buffer[0] = @enumToInt(net.FromClient.Kind.draw_action);
            cereal.serialize(DrawAction, buffer[1..], data);
        },
        .state => |data| {
            buffer = try allocator.alloc(u8, cereal.size_of(data) + 1);
            // Dedicate the 0th index in the packet to indicating this packet type to the server.
            buffer[0] = @enumToInt(net.FromClient.Kind.return_state);
            cereal.serialize(WorldState, buffer[1..], data);
        },
    }
    return buffer;
}

test "serialize and deserialize draw action" {
    const alloc = std.testing.allocator;

    const actions = [_]DrawAction{
        .{ .layer_switch = 3 },
        .{ .mouse_press = .{ .button = 8, .pos = .{ .x = 900, .y = -500 } } },
    };

    for (actions) |action| {
        const event = Serializable{ .action = action };
        const packetBytes = try serialize(alloc, event);
        defer alloc.free(packetBytes);

        try std.testing.expectEqual(packetBytes.len, cereal.size_of(action) + 1);
        try std.testing.expect(@intToEnum(net.FromClient.Kind, packetBytes[0]) == .draw_action);

        // Keep in mind, when a DrawAction packet is returned from the server, that packet will actually be struct{id: u8, action: DrawAction}.
        var unpacked = try cereal.deserialize(null, DrawAction, packetBytes[1..]);
        try std.testing.expect(std.meta.eql(action, unpacked));
        unpacked = .{ .layer_switch = 10 };
        try std.testing.expect(!std.meta.eql(action, unpacked));
    }
}

test "serialize and deserialize world state" {
    const alloc = std.testing.allocator;
    const image = [_]u8{ 1, 2, 3, 4, 5 } ** 1000;
    var users = [_]WorldState.UniqueUser{
        .{ .id = 1, .user = .{ .size = 2 } },
        .{ .id = 25, .user = .{ .size = 26 } },
        .{ .id = 100, .user = .{ .size = 70 } },
        .{ .id = 200, .user = .{ .size = 255 } },
        .{ .id = 201, .user = .{ .size = 0 } },
    };

    const state = WorldState{
        .users = users[0..],
        .image = image[0..],
    };
    const event = Serializable{ .state = state };

    const packetBytes = try serialize(alloc, event);
    defer alloc.free(packetBytes);

    try std.testing.expectEqual(packetBytes.len, cereal.size_of(state) + 1);
    try std.testing.expect(@intToEnum(net.FromClient.Kind, packetBytes[0]) == .return_state);

    var unpacked = try cereal.deserialize(alloc, WorldState, packetBytes[1..]);
    defer alloc.free(unpacked.users);
    defer alloc.free(unpacked.image);
    try std.testing.expect(std.mem.eql(u8, state.image, unpacked.image));
    for (state.users) |user, n| {
        try std.testing.expect(std.meta.eql(user.id, unpacked.users[n].id));
        try std.testing.expect(std.meta.eql(user.user, unpacked.users[n].user));
    }
}
