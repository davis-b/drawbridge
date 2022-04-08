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

    /// Flag to determine if the main loop should copy our drawing canvas onto our rendering surface.
    /// Allows us to save CPU cycles if there is nothing new to copy.
    shouldRender: bool = true,
};
