const std = @import("std");

pub const Kind = packed enum(u8) {
    /// A regular paint action. e.g. draw, change color.
    /// Forwarded by the server, the data of this packet has been modified
    ///  by the server to include the sender's ID as its 0th element.
    action,

    /// A peer has entered the room we are in.
    peer_entry,

    /// A peer has left the room we are in.
    peer_exit,

    /// A request for our world state.
    state_query,

    /// A world state for us to use as our own.
    state_set,

    /// The server's response to a request or query of ours.
    /// When used, the 'data' field of a packet contains the response info.
    response,
};

/// Responses from server to client.
pub const Response = packed enum(u8) {
    /// Client tried to join a full room.
    room_full,

    /// Client has joined an empty room.
    room_empty,

    /// Client has joined a room with peers.
    /// A world state update should be on its way soon.
    room_state_incoming,

    /// A time based issue has occured.
    /// Trying again after a brief delay may fix the issue.
    try_again,
};
