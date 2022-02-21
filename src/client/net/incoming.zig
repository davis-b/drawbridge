const std = @import("std");

const ThreadContext = @import("index.zig").ThreadContext;
const DrawAction = @import("../net_actions.zig").Action;
const packet = @import("packet.zig");
const MetaEvent = @import("meta_events.zig").Event;

/// An incoming Action along with the associated user that spawned it.
/// Ready for consumption by the main thread.
pub const PackagedAction = struct {
    action: DrawAction,
    userID: u8,
};

/// This thread is responsible for processing incoming packets.
/// It should not interact with the state of the world, as would be given when queried by a new client, to prevent desync issues.
/// Primarily this thread will be decoding and placing data into the appropriate queue.
pub fn startReceiving(context: ThreadContext) void {
    const pipe = context.pipe;
    const alloc = context.client.marshaller.allocator;
    var recv_buffer: [1024]u8 = undefined;

    while (true) {
        const dataPacket = context.client.recv(recv_buffer[0..]) catch {
            pipe.meta.put(.net_exit) catch {
                std.debug.print("Network read thread encountered a queue error while exiting.\n", .{});
                break;
            };
            break;
        };
        // Our queue implementation copies the item we give it.
        // Thus, we do not have to worry about freeing the underlying memory before the queue consumer uses it.
        defer alloc.free(dataPacket);
        const message = std.mem.bytesToValue(packet.InPacket, dataPacket[0..@sizeOf(packet.InPacket)]);
        switch (message.kind) {
            .action => {
                const action = std.mem.bytesToValue(DrawAction, message.data[0..@sizeOf(DrawAction)]);
                pipe.in.put(PackagedAction{ .action = action, .userID = message.user }) catch {
                    std.debug.print("Network read thread encountered a queue error adding to incoming action queue.\n", .{});
                    break;
                };
            },
            // A new peer has been detected. Either we joined a room, or they did.
            // We must now share our current state with the server, which will be received as a peer_update packet.
            .peer_entry => {
                pipe.meta.put(MetaEvent{ .peer_entry = message.user }) catch {
                    std.debug.print("Network read thread encountered a queue error while adding to meta queue [peer enter].\n", .{});
                    break;
                };
            },
            .peer_exit => {
                pipe.meta.put(MetaEvent{ .peer_exit = message.user }) catch {
                    std.debug.print("Network read thread encountered a queue error while adding to meta queue [peer exit].\n", .{});
                    break;
                };
            },
            // Server is querying this client for its current world state.
            // A new peer has just connected, and will be caught up using this state.
            .state_query => {
                // The main thread will serialize and send world state.
                // Signal only in meta queue, and then main thread puts it in network out queue, that should work.
                // This way, we avoid a race condition where our state query response gets sent before an outgoing network action packet that was part of creating that state.
                pipe.meta.put(MetaEvent{ .state_query = {} }) catch {
                    std.debug.print("Network read thread encountered a queue error while adding to meta queue [state query].\n", .{});
                    break;
                };
            },
            // Set the state of this client.
            .state_set => {
                // New user enters, server sends that info to connected clients.
                //
                // Server copies packets that arrive after this point into a packet history. Server still sends packets to previously connected clients in the meantime.
                //
                // When the Authoritative Client sends a (valid) world state, server can mark that packet.
                //
                // Send the packet history to the new client.
                // Any packets that the AC sent before the world state packet can be skipped or removed when sending packet history to new client.
                //
                // When history has been sent, free it and treat the new client as any other would be treated.
                //

                const world = std.mem.bytesToValue(packet.WorldState, @ptrCast(*const [@sizeOf(packet.WorldState)]u8, message.data));
                pipe.meta.put(MetaEvent{ .state_set = world }) catch {
                    std.debug.print("Network read thread encountered a queue error while adding to meta queue [state set].\n", .{});
                    break;
                };
            },
        }
    }
}
