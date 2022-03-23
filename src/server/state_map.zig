const std = @import("std");

const Room = @import("rooms.zig").Room;
const ClientIdT = @import("client.zig").ClientIdT;
const Client = @import("client.zig").Client;

/// Connects a client with an up to date state of the room to a list of clients requesting the room's state.
pub const ClientStateLinker = struct {
    const Self = @This();
    /// A mapping of a client with state to a list of clients waiting to receive that state.
    links: std.AutoHashMap(ClientIdT, std.ArrayList(?ClientIdT)),
    allocator: *std.mem.Allocator,

    pub fn init(allocator: *std.mem.Allocator) Self {
        return Self{
            .links = std.AutoHashMap(ClientIdT, std.ArrayList(?ClientIdT)).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        var it = self.links.valueIterator();
        while (it.next()) |clients| {
            clients.deinit();
        }
        self.links.deinit();
    }

    /// Returns a client which can share its world state with the requester.
    /// Can return null if there are no viable clients to request state from.
    /// Sets up a link between the requester and the returned client.
    pub fn link(self: *Self, requester: ClientIdT, room: *Room) !?*Client {
        // First loop through the list of clients, ignores clients that are already linked.
        for (room.clients.items) |client| {
            if (client.id == requester) continue;
            // We shouldn't request a world state from someone who doesn't have a complete one.
            if (client.packet_buffer) |_| continue;

            if (self.links.contains(client.id)) continue;

            try self.appendMaybeCreate(client.id, requester);
            return client;
        }

        // Second loop through the list of clients looks for any available client,
        // choosing not to ignore clients that are already linked.
        for (room.clients.items) |client| {
            if (client.id == requester) continue;
            // We shouldn't request a world state from someone who doesn't have a complete one.
            if (client.packet_buffer) |_| continue;

            try self.appendMaybeCreate(client.id, requester);
            return client;
        }
        return null;
    }

    fn appendMaybeCreate(self: *Self, key: ClientIdT, value: ClientIdT) !void {
        if (self.links.getPtr(key)) |array| {
            try array.append(value);
        } else {
            var array = std.ArrayList(?ClientIdT).init(self.allocator);
            try self.links.put(key, array);
            try self.links.getPtr(key).?.append(value);
        }
    }

    /// Returns the ID of the client which is supposed to receive a world state packet from the given client.
    /// Can return null if recipient has left room.
    /// Removes the 0th item from the list of the sender's recipients.
    pub fn take_linked(self: *Self, sender: ClientIdT) ?ClientIdT {
        if (self.links.getPtr(sender)) |recipients| {
            if (recipients.items.len == 0) return null;
            const recipient = recipients.orderedRemove(0);
            return recipient;
        }
        return null;
    }

    /// Removes a client from both halves of our hashmap.
    pub fn unlink(self: *Self, client: ClientIdT) void {
        if (self.links.contains(client)) {
            _ = self.links.remove(client);
        } else {
            var it = self.links.valueIterator();
            while (it.next()) |client_array| {
                for (client_array.items) |maybe_client, index| {
                    if (maybe_client) |c| {
                        if (client == c) {
                            // Set the client to 'null' instead of simply remove it.
                            // This is because we do not want other clients receiving packets meant for this one.
                            client_array.items[index] = null;
                            // If a client is in more than recipient array, something has already gone horribly wrong.
                            return;
                        }
                    }
                }
            }
        }
    }
};
