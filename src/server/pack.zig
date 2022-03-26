const std = @import("std");

const net = @import("net");
const Packet = net.FromServer.Packet;
const PacketKind = net.FromServer.Kind;
const Response = net.FromServer.Response;

const ClientIdT = @import("client.zig").ClientIdT;
const management = @import("management.zig");

/// Takes a draw_action packet to forward.
/// Prepends the packet type and the sender's ID.
/// Caller owns the memory.
pub fn pack_action(allocator: *std.mem.Allocator, sender: ClientIdT, packet: []const u8) ![]u8 {
    var new = try pack_with_id(allocator, sender, packet);
    new[0] = @enumToInt(PacketKind.action);
    return new;
}

/// Takes a world_update packet to forward.
/// Prepends the packet type and the recipient's ID.
/// Caller owns the memory.
pub fn pack_world_update(allocator: *std.mem.Allocator, recipient: ClientIdT, packet: []const u8) ![]u8 {
    var new = try pack_with_id(allocator, recipient, packet);
    new[0] = @enumToInt(PacketKind.state_set);
    return new;
}

/// Copies and grows a packet to allow for 2 additional bytes of data.
/// Leaves the PacketKind field blank, fills in the 'client' field.
fn pack_with_id(allocator: *std.mem.Allocator, client: ClientIdT, packet: []const u8) ![]u8 {
    // If this changes, we'll have to modify our prepending to account for a larger client ID size.
    comptime std.debug.assert(ClientIdT == u8);

    var new = try allocator.alloc(u8, packet.len + 2);
    std.mem.copy(u8, new[2..], packet);
    new[0] = undefined; // should be replaced by the calling function
    new[1] = client;
    return new;
}

/// Creates a generic packet with a type and a single byte value.
pub fn pack_generic(comptime kind: PacketKind, value: ?u8) [2]u8 {
    var packet = [2]u8{ @enumToInt(kind), value orelse 0 };
    switch (kind) {
        .action => @compileLog("Use pack_action() instead"),
        .state_set => @compileLog("Use pack_world_update() instead"),
        else => return packet,
    }
}

/// Syntactic sugar for creating a repsonse packet.
pub fn pack_response(kind: Response) [2]u8 {
    return pack_generic(.response, @enumToInt(kind));
}

//
//

/// Takes a packed (server-modified) draw_action packet and returns the ID of the sender.
pub fn discern_action_sender_id(packet: []const u8) ClientIdT {
    return packet[1];
}

test "pack and check sender" {
    const data = [_]u8{ 0, 1, 2 };
    const packet = try pack_action(std.testing.allocator, 33, data[0..]);
    defer std.testing.allocator.free(packet);
    try std.testing.expectEqual(discern_action_sender_id(packet), 33);
}
