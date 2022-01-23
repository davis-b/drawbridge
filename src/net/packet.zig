const User = @import("../users.zig").User;

pub const InKind = packed enum(u8) {
    /// A regular paint action. e.g. draw, change color.
    action,

    /// A peer has entered the room we are in.
    peer_entry,

    /// A peer has left the room we are in.
    peer_exit,

    /// A request for our world state.
    state_query,

    /// A world state for us to use as our own.
    state_set,
};

pub const InPacket = struct {
    kind: InKind,
    user: u8,
    data: []u8,
};

/// A user with its ID, for use in conjunction with sending WorldState.
pub const UniqueUser = struct {
    id: u8,
    user: User,
};

/// Used to send and receive the state of the program when a user enters a room.
pub const WorldState = struct {
    users: []UniqueUser,
    image: []u8,
    // TODO
    // image_size: Dot,
    // layers: u8,
};
