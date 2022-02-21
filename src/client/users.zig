const std = @import("std");

const Tool = @import("tools.zig").Tool;

pub const User = packed struct {
    drawing: bool = false,
    size: u8 = 1,
    color: u32 = 0xaabbcc,
    tool: Tool = .pencil,
    lastX: c_int = 0,
    lastY: c_int = 0,
    layer: u8 = 0,
};

pub const Peers = std.AutoHashMap(u8, User);
// pub const Peers = struct {
//     allocator: *std.mem.Allocator,
//     map: std.AutoHashMap(u8, User),
//
//     pub fn init(allocator: *std.mem.Allocator) Peers {
//         return Peers{
//             .allocator = allocator,
//             .map = std.AutoHashMap(u8, User).init(allocator),
//         };
//     }
//
//     pub fn deinit(self: *Peers) void {
//         var it = self.map.iterator();
//         for (it) |kv| {
//             self.allocator.destroy(kv.value);
//         }
//         self.map.deinit();
//     }
//
//     pub fn get(self: *Peers, id: u8) *User {
//         return self.map.get(id) catch unreachable;
//     }
//
//     pub fn remove(self: *Peers, id: u8) *User {
//         //
//     }
//
//     pub fn add(self: *Peers, id: u8, user: User) !void {
//         var u = allocator.create(User);
//         u.* = user;
//         self.map.put(id, u);
//     }
// };

// pub fn addUser(allocator: *std.mem.Allocator, id: u8, user: User, map: *Peers) !void {
