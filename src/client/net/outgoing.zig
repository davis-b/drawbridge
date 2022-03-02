const std = @import("std");

const ThreadContext = @import("index.zig").ThreadContext;
const DrawAction = @import("actions.zig").Action;
const packet = @import("packet.zig");

const Packet = packet.Packet(.client);

/// Something delivered from the main thread that is to be sent to the server.
pub const OutgoingData = union(enum) {
    action: DrawAction,
    state: packet.WorldState,
};

pub fn startSending(context: ThreadContext) void {
    while (true) {
        const msg = context.pipe.out.wait(null) catch unreachable;
        @compileError("TODO: Serialize this properly");
        const packedMsg = switch (msg) {
            .action => |*action| {
                Packet{ .kind = .draw_action, .data = std.mem.asBytes(action) };
            },
            .state => |*state| {
                Packet{ .kind = .return_state, .data = std.mem.asBytes(state) };
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
