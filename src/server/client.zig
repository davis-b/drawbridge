const std = @import("std");
const log = std.log.default;

const mot = @import("mot");

pub const ClientIdT = u8;

const Room = @import("management.zig").Room;
const Leavers = @import("management.zig").Leavers;

/// This is what the server should see each new client as.
pub const Client = struct {
    /// The underlying fd that we poll.
    fd: std.os.fd_t,

    /// Point of interaction when sending and receiving packets.
    connection: mot.Connection,

    /// A list of clients which will be removed from the server.
    /// Placed in the client struct so that we don't have to pass this around 
    /// to any function which might kick a client.
    leavers: *Leavers,

    /// The identifier added to each forwarded packet.
    /// The id is unique for each client within a room and not associated with its index.
    /// If a client is not in a room, that client's id should not be accessed.
    id: ClientIdT = undefined,

    /// The room this Client resides in.
    room: ?*Room = null,

    /// The Client's index within its room.
    index: ClientIdT = undefined,

    /// After entering an active room, messages for this client will be buffered here.
    /// When we receive a world state update from a peer, the buffer will be sent out and deleted.
    packet_buffer: ?PacketStorage = null,

    pub fn init(fd: std.os.fd_t, connection: mot.Connection, leavers: *Leavers) Client {
        return Client{ .fd = fd, .connection = connection, .leavers = leavers };
    }

    pub fn deinit(self: *Client) void {
        if (self.packet_buffer) |*pb| pb.deinit();
        self.connection.deinit();
    }

    /// Sends a packet and handles errors.
    /// Returns true if the packet was sent, false if there was an error.
    pub fn send(self: *Client, packet: []const u8, log_note: ?[]const u8) bool {
        self.connection.send(packet) catch |err| {
            // TODO We should probably return non network errors.
            log.warn("Kicking {}. Reason: send() failed ({s}) ({}).\n", .{ self, log_note, err });
            self.leavers.append(self);
            return false;
        };
        return true;
    }

    /// Inits a packet buffer for this client if it is in a room.
    /// If this client already has a packet buffer, it will be destroyed.
    pub fn init_packet_buffer(self: *Client) void {
        if (self.packet_buffer) |*pb| pb.deinit();
        if (self.room) |room| {
            self.packet_buffer = PacketStorage.init(room.allocator);
        }
    }
};

/// Stores copies of packets.
const PacketStorage = struct {
    allocator: *std.mem.Allocator,
    packets: std.ArrayList([]const u8),

    fn init(allocator: *std.mem.Allocator) PacketStorage {
        return .{
            .allocator = allocator,
            .packets = std.ArrayList([]const u8).init(allocator),
        };
    }

    /// Frees the memory we have allocated.
    pub fn deinit(self: *PacketStorage) void {
        for (self.packets.items) |p| {
            self.allocator.free(p);
        }
        self.packets.deinit();
    }

    /// Duplicates and stores a packet for later retrieval. 
    /// PacketStorage owns new memory, which is expected to be released with PacketStorage.deinit().
    pub fn store(self: *PacketStorage, packet: []const u8) !void {
        const new_packet = try self.allocator.dupe(u8, packet);
        try self.packets.append(new_packet);
    }

    pub fn items(self: *PacketStorage) [][]const u8 {
        return self.packets.items;
    }
};

/// Accept a new connection, returning a Client without a room.
pub fn accept_client(allocator: *std.mem.Allocator, server: *std.net.StreamServer, leavers: *Leavers) !Client {
    const raw_connection = try server.accept();
    errdefer raw_connection.stream.close();
    var motcon = try mot.Connection.init_from_stream(allocator, raw_connection.stream);
    // stream.handle may not be interchangeable with a FD on all platforms.
    // Will poll still work on those platforms?
    return Client.init(motcon.stream.handle, motcon, leavers);
}
