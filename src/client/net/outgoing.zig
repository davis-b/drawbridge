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
        const event = context.pipe.out.wait(null) catch unreachable;
        const packet = try serialize(allocator, event);
        context.client.send(packet) catch |err| {
            pipe.meta.put(.net_exit) catch {
                std.debug.print("Network write thread encountered a queue error while exiting.\n", .{});
            };
            break;
        };
    }
}

fn serialize(allocator: *std.mem.Allocator, data: OutgoingData) ![]u8 {
    @compileError("TODO: Serialize this properly");

    var buffer = try allocator.alloc(u8, sizeOf(data) + 1);
    buffer[0] = switch (msg) {
        .action => @enumToInt(net.FromClient.Kind.draw_action),
        .state => @enumToInt(net.FromClient.Kind.return_state),
    };

    try pack_more(OutgoingData, buffer[1..], data);

    return buffer;
}
