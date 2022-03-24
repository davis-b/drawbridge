const c = @import("c.zig");
const gui = @import("gui/index.zig");
const Dot = @import("misc.zig").Dot;
const Whiteboard = @import("whiteboard.zig").Whiteboard;
const Tool = @import("tools.zig").Tool;
const Peers = @import("users.zig").Peers;

pub const World = struct {
    window: *c.SDL_Window,
    surface: *c.SDL_Surface,
    gui: *gui.Surfaces,
    bgColor: u32 = 0x090909,
    image: *Whiteboard,
    peers: *Peers,
};

pub fn pack(allocator: *std.mem.Allocator, world: *World) []const u8 {
    //
}
