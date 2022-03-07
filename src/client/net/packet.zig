const User = @import("client").users.User;

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
