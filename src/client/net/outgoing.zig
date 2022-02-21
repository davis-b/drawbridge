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
        const kind = pipe.out.wait(null) catch unreachable;
        // TODO we probably have to serialize packet.WorldState and maybe DrawAction to a sequence of bytes that will be the same on every computer.
        // either packed extern struct or more manual serialization.
        var packedMsg: packet.OutPacket = undefined;
        switch (kind) {
            .action => |action| {
                packedMsg = packet.OutPacket{ .kind = .action, .data = std.mem.asBytes(&action) };
            },
            .state => |state| {
                packedMsg = packet.OutPacket{ .kind = .state, .data = std.mem.asBytes(&state) };
            },
        }
        client.send(std.mem.asBytes(&packedMsg)) catch |err| {
            pipe.meta.put(.net_exit) catch {
                std.debug.print("Network write thread encountered a queue error while exiting.\n", .{});
            };
            break;
        };
    }
}
