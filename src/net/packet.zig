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
    data: []const u8,
};

pub const OutKind = packed enum(u8) {
    /// A regular paint action.
    action,

    /// Our world state, as requested.
    state,
};

pub const OutPacket = struct {
    kind: OutKind,
    data: []const u8,
};

/// A user with its ID, for use in conjunction with sending WorldState.
pub const UniqueUser = struct {
    id: u8,
    user: User,
};

/// Used to send and receive the state of the program when a user enters a room.
pub const WorldState = struct {
    users: []UniqueUser,
    image: []const u8,
    // TODO
    // image_size: Dot,
    // layers: u8,
};
