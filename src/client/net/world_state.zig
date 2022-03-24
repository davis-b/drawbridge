const std = @import("std");
const User = @import("client").users.User;

/// Used to send and receive the state of the program when a user enters a room.
pub const WorldState = struct {

    /// A user with its ID, for use in conjunction with sending WorldState.
    pub const UniqueUser = struct {
        id: u8,
        user: User,
    };

    users: []UniqueUser,
    image: []const u8,
    // TODO
    // image_size: Dot,
    // layers: u8,

    pub fn format(self: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, out_stream: anytype) !void {
        try std.fmt.format(out_stream, "World state = Users: {}", .{self.users.len});
    }
};
