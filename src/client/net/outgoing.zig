const std = @import("std");

const ThreadContext = @import("index.zig").ThreadContext;
const DrawAction = @import("actions.zig").Action;
const Packet = @import("net").Packet(.client);
const User = @import("../users.zig").User;

/// Something delivered from the main thread that is to be sent to the server.
pub const OutgoingData = union(enum) {
    action: DrawAction,
    state: WorldState,
};

pub fn startSending(context: ThreadContext) void {
    while (true) {
        const msg = context.pipe.out.wait(null) catch unreachable;
        @compileError("TODO: Serialize this properly");
        // TODO we probably have to serialize packet.WorldState and maybe DrawAction to a sequence of bytes that will be the same on every computer.
        // either packed extern struct or more manual serialization.
        const packedMsg = switch (msg) {
            .action => |*action| {
                Packet{ .kind = .action, .data = std.mem.asBytes(action) };
            },
            .state => |*state| {
                Packet{ .kind = .state, .data = std.mem.asBytes(state) };
            },
        };
        context.client.send(std.mem.asBytes(&packedMsg)) catch |err| {
            pipe.meta.put(.net_exit) catch {
                std.debug.print("Network write thread encountered a queue error while exiting.\n", .{});
            };
            break;
        };
    }
}

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
