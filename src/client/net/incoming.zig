const std = @import("std");

const net = @import("net");
const cereal = @import("cereal");

const ThreadContext = @import("index.zig").ThreadContext;
const DrawAction = @import("actions.zig").Action;
const WorldState = @import("world_state.zig").WorldState;
const MetaEvent = @import("meta_events.zig").Event;

/// An incoming Action along with the associated user that spawned it.
/// Ready for consumption by the main thread.
pub const PackagedAction = struct {
    userID: u8,
    action: DrawAction,
};

/// This thread is responsible for processing incoming packets.
/// It should not interact with the state of the world, as would be given when queried by a new client, to prevent desync issues.
/// Primarily this thread will be decoding and placing data into the appropriate queue.
pub fn startReceiving(context: ThreadContext) void {
    var recv_buffer: [1024]u8 = undefined;

    while (true) {
        const dataPacket = context.client.recv(recv_buffer[0..]) catch {
            context.pipe.meta.put(.net_exit) catch {
                std.debug.print("Network read thread encountered a queue error while exiting.\n", .{});
            };
            std.debug.print("Network read socket closed.\n", .{});
            break;
        };
        // Our queue implementation copies the item we give it.
        // Thus, we do not have to worry about freeing the underlying memory before the queue consumer uses it.
        defer context.client.marshaller.allocator.free(dataPacket);

        const message = net.unwrap(.server, dataPacket) catch unreachable;
        handleMsg(context, message) catch |err| {
            std.debug.print("Network read thread encountered an error: {}.\n", .{err});
            break;
        };
    }
}

fn handleMsg(context: ThreadContext, message: net.Packet(.server)) !void {
    const pipe = context.pipe;
    const err = MetaEvent{ .err = .unknown };
    errdefer pipe.meta.put(err) catch {
        std.debug.print("Meta pipe failed to put network-thread error\n", .{});
    };
    switch (message.kind) {
        .action => {
            const action = cereal.deserialize(null, PackagedAction, message.data) catch unreachable; // no allocation, can't fail.
            try pipe.in.put(action);
        },
        // A new peer has been detected. They joined our room.
        // We must now share our current state with the server, which will be received as a peer_update packet.
        .peer_entry => {
            try pipe.meta.put(MetaEvent{ .peer_entry = message.data[0] });
        },
        .peer_exit => {
            try pipe.meta.put(MetaEvent{ .peer_exit = message.data[0] });
        },
        // Server is querying this client for its current world state.
        // A new peer has just connected, and will be caught up using this state.
        .state_query => {
            // The main thread will serialize and send world state.
            // Signal only in meta queue, and then main thread puts it in network out queue, that should work.
            // This way, we avoid a race condition where our state query response gets sent before an outgoing network action packet that was part of creating that state.
            try pipe.meta.put(MetaEvent{ .state_query = message.data[0] });
        },
        // Set the state of this client.
        .state_set => {
            // const world = std.mem.bytesToValue(packet.WorldState, @ptrCast(*const [@sizeOf(packet.WorldState)]u8, message.data));
            const world = try cereal.deserialize(context.allocator, WorldState, message.data);
            try pipe.meta.put(MetaEvent{ .state_set = world });
        },
        .response => {
            switch (try std.meta.intToEnum(net.FromServer.Response, message.data[0])) {
                .room_full, .room_empty, .room_state_incoming, .try_again => return error.UnexpectedServerResponse,
            }
        },
    }
}
