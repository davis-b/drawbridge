const c = @import("c.zig");
const gui = @import("gui/index.zig");
const Dot = @import("misc.zig").Dot;
const Whiteboard = @import("whiteboard.zig").Whiteboard;
const Tool = @import("tools.zig").Tool;
const users = @import("users.zig");

pub const World = struct {
    window: *c.SDL_Window,
    surface: *c.SDL_Surface,
    gui: *gui.Surfaces,
    bgColor: u32,
    image: *Whiteboard,
    peers: *users.Peers,
    user: *users.User,
};
