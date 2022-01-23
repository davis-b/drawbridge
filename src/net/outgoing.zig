const std = @import("std");

const ThreadContext = @import("index.zig").ThreadContext;
const DrawAction = @import("../net_actions.zig").Action;
const packet = @import("packet.zig");

/// Something delivered from the main thread that is to be sent to the server.
pub const OutgoingData = union(enum) {
    action: DrawAction,
    state: packet.WorldState,
};

pub fn startSending(context: ThreadContext) void {
    const client = context.client;
    const pipe = context.pipe;
    while (true) {
        const action = pipe.out.wait(null);
        // TODO we probably have to serialize packet.WorldState and maybe DrawAction to a sequence of bytes that will be the same on every computer.
        // either packed extern struct or more manual serialization.
        client.send(std.mem.asBytes(&action)) catch |err| {
            pipe.meta.put(.net_exit) catch {
                std.debug.print("Network write thread encountered a queue error while exiting.\n", .{});
            };
            break;
        };
    }
}
