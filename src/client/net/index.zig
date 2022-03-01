const std = @import("std");
const log = std.log.default;

pub const mot = @import("mot"); // message oriented tcp
const net = @import("net");
const Queue = @import("queue").ThreadsafeQueue;

const packet = @import("packet.zig");
const users = @import("../users.zig");
const MetaEvent = @import("meta_events.zig").Event;
const c = @import("c.zig");
const send = @import("outgoing.zig");
const recv = @import("incoming.zig");

/// Communication channel between the main thread and the network threads.
pub const Pipe = struct {
    /// Outoing actions that we send to the server.
    out: Queue(send.OutgoingData, 1000) = Queue(send.OutgoingData, 1000).init(),
    /// Incoming actions that the server sends us, along with the associated user ID.
    in: Queue(recv.PackagedAction, 4000) = Queue(recv.PackagedAction, 4000).init(),
    /// Meta information, such as users entering or leaving a room.
    meta: Queue(MetaEvent, 150) = Queue(MetaEvent, 150).init(),
};

pub const ThreadContext = struct {
    pipe: *Pipe,
    client: *mot.Connection,
};

/// Initializes a connection with the server at a specific room.
pub fn init(allocator: *std.mem.Allocator, ip: []const u8, port: u16, room: []const u8) !mot.Connection {
    const addr = try std.net.Address.resolveIp(ip, port);
    var client = try connect(allocator, addr);
    errdefer client.deinit();
    while (try enter_room(allocator, &client, room)) {
        std.time.sleep(1 * std.time.ns_per_s);
    }
    return client;
}

/// Starts the network read/write threads.
pub fn startThreads(pipe: *Pipe, client: *mot.Connection) ![2]*std.Thread {
    const read_thread = try std.Thread.spawn(send.startSending, .{ .pipe = pipe, .client = client });
    const write_thread = try std.Thread.spawn(recv.startReceiving, .{ .pipe = pipe, .client = client });
    return [2]*std.Thread{ read_thread, write_thread };
}

pub fn connect(allocator: *std.mem.Allocator, addr: std.net.Address) !mot.Connection {
    // connect to server
    const stream = try std.net.tcpConnectToAddress(addr);

    // create mot client
    var client = mot.Connection.init_from_stream(allocator, stream) catch |err| {
        stream.close();
        return err;
    };
    return client;
}

/// Returns true if we should try again in a little while.
/// Otherwise returns false.
pub fn enter_room(allocator: *std.mem.Allocator, client: *mot.Connection, room: []const u8) !bool {
    log.debug("sending room {s}", .{room});
    var room_packet = try net.FromClient.pack(allocator, .room_request, room);
    defer allocator.free(room_packet);
    try client.send(room_packet);
    log.debug("sent room", .{});

    var result_buffer = [_]u8{0} ** 80;

    log.debug("waiting for response", .{});
    const result_packet = try client.recv(result_buffer[0..]);
    defer client.marshaller.allocator.free(room_result);
    log.debug("response received", .{});

    const result = try net.unwrap(.server, result_packet);
    std.debug.assert(result.kind == .response);
    const response = try std.meta.intToEnum(net.FromServer.Response, result.data[0]);

    // Could return response here and have main function handle it.
    switch (response) {
        .room_full => {
            log.debug("room not joined; room full", .{});
            return error.FullRoom;
        },
        .room_empty => {
            log.debug("room joined; empty room", .{});
        },
        .room_state_incoming => {
            log.debug("room joined; state incoming", .{});
        },
        .try_again => {
            return true;
        },
        else => {
            return error.UnknownResponse;
        },
    }
    return false;
}