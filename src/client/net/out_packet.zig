const User = @import("../users.zig").User;

pub const ClientOutKind = packed enum(u8) {
    /// A regular paint action.
    action,

    /// Our world state, as requested.
    state,
};

pub const ClientOutPacket = struct {
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
