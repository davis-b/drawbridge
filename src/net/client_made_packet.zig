const std = @import("std");

pub const Kind = packed enum(u8) {
    /// A draw action, meant to be broadcast to the sender's room.
    draw_action,

    /// A request to join a room. The 'data' field is the room name.
    room_request,

    /// Returning the server's request for the sender's current world state.
    return_state,

    /// The client is disconnecting from the server.
    disconnect,
};

/// Packs the outermost (client -> server) layer of a packet.
/// Caller owns returned memory.
pub fn wrap(allocator: *std.mem.Allocator, kind: Kind, packet: []const u8) ![]u8 {
    var new = try allocator.alloc(u8, packet.len + 1);
    std.mem.copy(u8, new[1..], packet);
    new[0] = @enumToInt(kind);
    return new;
}
