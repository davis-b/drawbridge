const std = @import("std");
const log = std.log.default;

pub const mot = @import("mot"); // message oriented tcp
const Queue = @import("queue").ThreadsafeQueue;

pub const packet = @import("packet.zig");
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
    try enterRoom(&client, room);
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

pub fn enterRoom(client: *mot.Connection, room: []const u8) !void {
    @compileError("TODO: revamp this using new packet semantics");
    log.debug("sending room {s}", .{room});
    try client.send(room);
    log.debug("sent room", .{});

    const success = [_]u8{1};
    var result_buffer = [_]u8{0} ** success.len;

    log.debug("waiting for response", .{});
    const room_result = try client.recv(result_buffer[0..]);
    defer client.marshaller.allocator.free(room_result);
    log.debug("response received", .{});

    if (!std.mem.eql(u8, room_result, success[0..])) {
        log.debug("room not joined", .{});
        return error.InvalidRoom;
    }
    log.debug("room joined", .{});
}
