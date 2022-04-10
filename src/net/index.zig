// This file contains network code that is shared between client and server.

const std = @import("std");

pub const FromServer = @import("server_made_packet.zig");
pub const FromClient = @import("client_made_packet.zig");
// TODO reduce this to u16 when we implement packet fragmenting
pub const ConnectionHeaderT = u24;

/// A simple packet type, containing a kind and some data.
pub fn Packet(kind: PacketOriginator) type {
    return struct {
        kind: switch (kind) {
            .server => FromServer.Kind,
            .client => FromClient.Kind,
        },
        data: []const u8,
    };
}

/// Indicates to the unwrapping function where the packet originally came from.
const PacketOriginator = enum {
    server,
    client,
};

/// Unwraps the outermost (client <-> server) layer of a packet.
pub fn unwrap(comptime originator: PacketOriginator, data: []const u8) !Packet(originator) {
    if (data.len == 0) return error.EmptyPacket;
    const T = Packet(originator);
    return T{
        .kind = try std.meta.intToEnum(std.meta.fieldInfo(T, .kind).field_type, data[0]),
        .data = data[1..],
    };
}

test "unwrap" {
    const raw_packet_no_data = [_]u8{1};
    const packet_no_data = try unwrap(.server, raw_packet_no_data[0..]);
    try std.testing.expectEqual(packet_no_data.data.len, 0);

    const raw_packet = [_]u8{ 1, 2, 3 };
    const packet = try unwrap(.server, raw_packet[0..]);
    try std.testing.expectEqual(packet.data.len, 2);
    try std.testing.expectEqual(packet.data[0], 2);
    try std.testing.expectEqual(packet.data[1], 3);
}

test "unwrap errors" {
    const empty_packet = [0]u8{};
    try std.testing.expectError(error.EmptyPacket, unwrap(.client, empty_packet[0..]));

    var raw_packet_no_data = [_]u8{0};
    try std.testing.expectEqual((try unwrap(.client, raw_packet_no_data[0..])).data.len, 0);
    raw_packet_no_data[0] = 255;
    try std.testing.expectError(error.InvalidEnumTag, unwrap(.client, raw_packet_no_data[0..]));
}
