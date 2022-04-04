const std = @import("std");
const log = std.log.scoped(.netmain);

pub const mot = @import("mot"); // message oriented tcp
pub const cereal = @import("cereal");
const net = @import("net"); // network code/data shared with server
const Queue = @import("queue").ThreadsafeQueue;

const users = @import("client").users;
pub const WorldState = @import("world_state.zig").WorldState;
const MetaEvent = @import("meta_events.zig").Event;
pub const send = @import("outgoing.zig");
const recv = @import("incoming.zig");

/// Communication channel between the main thread and the network threads.
pub const Pipe = struct {
    /// Outoing actions that we send to the server.
    out: Queue(send.ToForward, 1000) = Queue(send.ToForward, 1000).init(),
    /// Incoming actions that the server sends us, along with the associated user ID.
    in: Queue(recv.PackagedAction, 4000) = Queue(recv.PackagedAction, 4000).init(),
    /// Meta information, such as users entering or leaving a room.
    meta: Queue(MetaEvent, 150) = Queue(MetaEvent, 150).init(),
};

pub const ThreadContext = struct {
    pipe: *Pipe,
    client: *mot.Connection,
    allocator: *std.mem.Allocator,
};

/// Initializes a connection with the server.
pub fn init(allocator: *std.mem.Allocator, ip: []const u8, port: u16) !mot.Connection {
    const addr = try std.net.Address.parseIp(ip, port);
    var client = try connect(allocator, addr);
    return client;
}

/// Starts the network read/write threads.
pub fn startThreads(allocator: *std.mem.Allocator, pipe: *Pipe, client: *mot.Connection) ![2]*std.Thread {
    const out_thread = try std.Thread.spawn(send.startSending, .{ .pipe = pipe, .client = client, .allocator = allocator });
    const in_thread = try std.Thread.spawn(recv.startReceiving, .{ .pipe = pipe, .client = client, .allocator = allocator });
    return [2]*std.Thread{ out_thread, in_thread };
}

pub fn connect(allocator: *std.mem.Allocator, addr: std.net.Address) !mot.Connection {
    // connect to server
    const stream = blk: {
        if (std.builtin.os.tag == .windows) {
            // Windows requires this workaround instead of a simple tcpConnectToAddress()
            // because there is currently no way to pass WSA_FLAG_OVERLAPPED to that function.
            // This block does the same work as that function, just with that flag included.
            // The OVERLAPPED flag allows us to simultaneously read and write from a socket,
            // which is neccessary for our use case.
            // Note that the OVERLAPPED flag resides within the async world of Windows.
            // It is for that reason that we need to work around the zig std library here,
            // as our program is not async.
            const ws = std.os.windows.ws2_32;
            _ = try std.os.windows.WSAStartup(2, 2);
            const socket = ws.WSASocketW(
                ws.AF_INET,
                ws.SOCK_STREAM,
                ws.IPPROTO_TCP,
                null,
                0,
                ws.WSA_FLAG_OVERLAPPED | ws.WSA_FLAG_NO_HANDLE_INHERIT,
            );
            errdefer std.os.close(socket);
            try std.os.connect(socket, &addr.any, addr.getOsSockLen());
            break :blk std.net.Stream{ .handle = socket };
        } else {
            break :blk try std.net.tcpConnectToAddress(addr);
        }
    };

    // create mot client
    var client = mot.Connection.init_from_stream(allocator, stream) catch |err| {
        stream.close();
        return err;
    };
    if (std.builtin.os.tag == .windows) client.windows_overlapped_flag = true;
    return client;
}

/// If the server sends a try_again packet, we will block while doing so.
/// Returns true if we are the only member of a room, otherwise false.
pub fn enter_room(allocator: *std.mem.Allocator, client: *mot.Connection, room: []const u8) !bool {
    log.info("requesting to join room: \"{s}\"", .{room});
    var room_packet = try net.FromClient.wrap(allocator, .room_request, room);
    defer allocator.free(room_packet);
    try client.send(room_packet);
    log.debug("request sent", .{});

    var result_buffer = [_]u8{0} ** 80;

    log.debug("waiting for response", .{});
    const result_packet = try client.recv(result_buffer[0..]);
    defer client.marshaller.allocator.free(result_packet);
    log.debug("response received", .{});

    const result = try net.unwrap(.server, result_packet);
    std.debug.assert(result.kind == .response);
    const response = try std.meta.intToEnum(net.FromServer.Response, result.data[0]);

    // Could return response here and have main function handle it.
    switch (response) {
        .room_full => {
            log.info("room not joined; room full", .{});
            return error.FullRoom;
        },
        .room_empty => {
            log.info("room joined; empty room", .{});
            return true;
        },
        .room_state_incoming => {
            log.info("room joined; state incoming", .{});
            return false;
        },
        .try_again => {
            std.time.sleep(1 * std.time.ns_per_s);
            return enter_room(allocator, client, room);
        },
    }
}
