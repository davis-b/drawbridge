const std = @import("std");

const Client = @import("client.zig").Client;
const Leavers = @This();

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
