const std = @import("std");
const log = std.log.default;

const Client = @import("client.zig").Client;
const ClientIdT = @import("client.zig").ClientIdT;

const MaxRoomSize = std.math.maxInt(ClientIdT);
const RoomMap = std.StringHashMap(Room);

/// This is what actually owns the Client memory.
/// A file descriptor is the longest lasting component of a client.
/// Thus, storing clients in a fd map seems most fitting.
pub const FdMap = std.AutoHashMap(std.os.fd_t, Client);

/// A room in which clients broadcast messages to each other.
pub const Room = struct {
    /// The clients within this room.
    clients: std.ArrayList(*Client),

    /// Available IDs. Unique for each client.
    ids: [MaxRoomSize]bool = [_]bool{false} ** MaxRoomSize,

    /// A map of requested:[]requester for world_state updates.
    state_share_map: ClientStateLinker,

    // This room's name must be stored somewhere, as StringHashMap does not store it.
    name: []u8,

    allocator: *std.mem.Allocator,

    fn init(allocator: *std.mem.Allocator, name: []const u8) !Room {
        var owned_name = try allocator.dupe(u8, name);
        return Room{
            .clients = std.ArrayList(*Client).init(allocator),
            .state_share_map = ClientStateLinker.init(allocator),
            .name = owned_name,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Room) void {
        self.clients.deinit();
        self.state_share_map.deinit();
        self.allocator.free(self.name);
    }

    /// Returns the first available ID, and sets it to taken.
    fn new_id(self: *Room) ?ClientIdT {
        for (self.ids) |taken, index| {
            if (!taken) {
                self.ids[index] = true;
                // This int cast should never fail, as the size of ids is tied to the max size of ClientIdT.
                return @intCast(ClientIdT, index);
            }
        }
        return null;
    }

    /// Sets an id to be available.
    fn free_id(self: *Room, id: ClientIdT) void {
        self.ids[id] = false;
    }

    /// Removes a client from this room.
    fn remove(self: *Room, client: *Client) void {
        const index = client.index;
        _ = self.clients.swapRemove(index);
        if (index < self.clients.items.len) {
            // A Client was swapped from the last index of room.
            // We now need to update its index variable.
            self.clients.items[index].index = index;
        }
        self.free_id(client.id);
        self.state_share_map.unlink(client.id);
    }

    /// Returns the number of clients in this room.
    pub fn count(self: *Room) usize {
        return self.clients.items.len;
    }

    /// Returns a client which the caller should request state from.
    /// When said client returns a world_state packet, this room will be
    ///  responsible for pointing to which client requested that world_state.
    /// Returns null if there are no viable clients to copy state from. 
    pub fn request_world_state_source(self: *Room, requester: *Client) !?*Client {
        return self.state_share_map.link(requester.id, self);
    }

    /// Returns the recipient to this sender's world_state packet.
    /// Can return null if the recipient has left the room. Caller should do nothing in that case.
    pub fn find_world_state_recipient(self: *Room, sender: *Client) ?*Client {
        const id = self.state_share_map.take_linked(sender.id) orelse return null;
        // Ensure the given recipient id is still in this room.
        for (self.clients.items) |c| {
            if (c.id == id) return c;
        }
        // It is possible for the recipient to have left the room before the sender's world_state packet arrives.
        // In such a situation, all we have to do is ignore the packet.
        return null;
    }

    pub fn format(self: @This(), comptime fmt: []const u8, options: std.fmt.FormatOptions, out_stream: anytype) !void {
        try std.fmt.format(out_stream, "'Room ({s}, {})'", .{ self.name, self.clients.items.len });
    }
};

/// Connects a client with an up to date state of the room to a list of clients requesting the room's state.
const ClientStateLinker = struct {
    const Self = @This();
    links: std.AutoHashMap(ClientIdT, std.ArrayList(?ClientIdT)),
    allocator: *std.mem.Allocator,

    fn init(allocator: *std.mem.Allocator) Self {
        return Self{
            .links = std.AutoHashMap(ClientIdT, std.ArrayList(?ClientIdT)).init(allocator),
            .allocator = allocator,
        };
    }

    fn deinit(self: *Self) void {
        var it = self.links.valueIterator();
        while (it.next()) |clients| {
            clients.deinit();
        }
        self.links.deinit();
    }

    /// Returns a client which can share its world state with the requester.
    /// Can return null if there are no viable clients to request state from.
    /// Sets up a link between the requester and the returned client.
    fn link(self: *Self, requester: ClientIdT, room: *Room) !?*Client {
        // TODO optimize this by prioritizing clients that aren't already linked.
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
    fn take_linked(self: *Self, sender: ClientIdT) ?ClientIdT {
        if (self.links.getPtr(sender)) |recipients| {
            if (recipients.items.len == 0) return null;
            const recipient = recipients.orderedRemove(0);
            return recipient;
        }
        return null;
    }

    /// Removes a client from both halves of our hashmap.
    fn unlink(self: *Self, client: ClientIdT) void {
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

/// Removes a client from a room.
/// Shifts around index of last room member.
/// Safe to call with clients that have no room; it will do nothing.
pub fn remove_from_room(client: *Client) void {
    if (client.room) |room| {
        room.remove(client);
        client.room = null;
        client.index = undefined;
        client.id = undefined;
        if (client.packet_buffer) |*pb| {
            pb.deinit();
            client.packet_buffer = null;
        }
    }
}

/// A collection of all the rooms on this server.
pub const Rooms = struct {
    items: RoomMap,

    pub fn init(allocator: *std.mem.Allocator) Rooms {
        return Rooms{
            .items = RoomMap.init(allocator),
        };
    }

    /// Deinit all room state.
    /// Does not affect active connections.
    pub fn deinit(self: *Rooms) void {
        var it = self.items.iterator();
        while (it.next()) |kv| {
            kv.value_ptr.deinit();
        }
        self.items.deinit();
    }

    /// Adds a client to a room.
    /// If the requested room does not exist, it will be created.
    pub fn add_client(self: *Rooms, client: *Client, name: []const u8) !void {
        const room: *Room = self.items.getPtr(name) orelse try self.create_room(name);
        const room_member_count = room.clients.items.len;
        if (room_member_count >= MaxRoomSize) return error.RoomFull;
        try room.clients.append(client);
        client.index = @intCast(ClientIdT, room_member_count);
        client.room = room;
        client.id = room.new_id().?;
    }

    /// Creates a new room within the given set of rooms.
    /// Returns a pointer to that room.
    fn create_room(self: *Rooms, name: []const u8) !*Room {
        if (self.items.contains(name)) return error.RoomAlreadyExists;
        var room = try Room.init(self.items.allocator, name);
        errdefer room.deinit();
        try self.items.put(room.name, room);
        return self.items.getPtr(name).?;
    }

    /// Returns null if the room does not exist.
    pub fn room_has_space(self: *Rooms, name: []const u8) ?bool {
        if (self.items.getPtr(name)) |room| {
            if (room.clients.items.len >= MaxRoomSize) {
                return false;
            }
            return true;
        }
        // Room does not exist.
        return null;
    }
};

pub const Leavers = struct {
    clients: std.ArrayList(*Client),

    pub fn init(allocator: *std.mem.Allocator) Leavers {
        return Leavers{ .clients = std.ArrayList(*Client).init(allocator) };
    }

    pub fn deinit(self: *Leavers) void {
        self.clients.deinit();
    }

    pub fn append(self: *Leavers, client: *Client) !void {
        for (self.clients.items) |c| {
            if (c == client) return;
        }
        try self.clients.append(client);
    }
};

/// Ensures the requested room from a packet has a name that will not cause issues.
pub fn validate_room_name(name: []const u8) ![]const u8 {
    if (name.len == 0) return error.NameTooShort;
    // Cut off name early if the requested room name is longer than we allow.
    const MAX_ROOM_NAME_LEN = 50;
    const end = if (name.len > MAX_ROOM_NAME_LEN) MAX_ROOM_NAME_LEN else name.len;
    return name[0..end];
}

pub fn deinit_all_clients(fdmap: *FdMap) void {
    var it = fdmap.valueIterator();
    while (it.next()) |client| {
        client.deinit();
    }
}

test "add to room" {
    var client = Client{ .room = null, .index = undefined, .fd = undefined, .connection = undefined, .id = undefined, .leavers = undefined };
    var client2 = Client{ .room = null, .index = undefined, .fd = undefined, .connection = undefined, .id = undefined, .leavers = undefined };

    var state = Rooms.init(std.testing.allocator);
    var rooms = &state.items;
    defer state.deinit();

    // No room exists with this name, an empty room should be created with this client as its sole member.
    try state.add_client(&client, "test");
    try std.testing.expectEqual(rooms.getPtr("test").?.clients.items.len, 1);
    try std.testing.expectEqual(rooms.getPtr("test").?.clients.items[0].index, 0);

    // Add a second client to this room.
    try state.add_client(&client2, "test");
    try std.testing.expectEqual(rooms.getPtr("test").?.clients.items.len, 2);
    try std.testing.expectEqual(rooms.getPtr("test").?.clients.items[0].room.?.clients.items.len, 2);
    try std.testing.expectEqual(rooms.getPtr("test").?.clients.items[0].index, 0);
    try std.testing.expectEqual(rooms.getPtr("test").?.clients.items[1].index, 1);
}

test "remove from room" {
    const allocator = std.testing.allocator;
    const room_name = "test room";
    var room = try Room.init(allocator, room_name[0..]);
    defer room.deinit();

    var client = Client{ .room = &room, .index = 0, .fd = undefined, .connection = undefined, .id = undefined, .leavers = undefined };
    var client2 = Client{ .room = &room, .index = 1, .fd = undefined, .connection = undefined, .id = undefined, .leavers = undefined };
    var client3 = Client{ .room = &room, .index = 2, .fd = undefined, .connection = undefined, .id = undefined, .leavers = undefined };
    try room.clients.append(&client);
    remove_from_room(&client);
    try std.testing.expectEqual(@as(?*Room, null), client.room);

    // This function should do nothing for clients without a room.
    remove_from_room(&client);

    // Test if we properly move the last index when removing a client.
    client.room = &room;
    client.index = 0;
    try room.clients.append(&client);
    try room.clients.append(&client2);
    try room.clients.append(&client3);
    remove_from_room(room.clients.items[0]);
    try std.testing.expectEqual(room.clients.items.len, 2);
    try std.testing.expectEqual(room.clients.items[0].index, 0);
    try std.testing.expectEqual(room.clients.items[1].index, 1);

    remove_from_room(room.clients.items[0]);
    try std.testing.expectEqual(room.clients.items[0].index, 0);
}

test "add and remove from a room" {
    var client = Client{ .room = null, .index = undefined, .fd = undefined, .connection = undefined, .id = undefined, .leavers = undefined };
    var client2 = Client{ .room = null, .index = undefined, .fd = undefined, .connection = undefined, .id = undefined, .leavers = undefined };

    var rooms = Rooms.init(std.testing.allocator);
    defer rooms.deinit();
    try rooms.add_client(&client, "test");
    try rooms.add_client(&client2, "test");
    const room = rooms.items.getPtr("test").?;

    try std.testing.expectEqual(room.clients.items[1].index, 1);
    try std.testing.expectEqual(room.clients.items[0].index, 0);
    remove_from_room(room.clients.items[0]);
    try std.testing.expectEqual(room.clients.items[0].index, 0);
}
