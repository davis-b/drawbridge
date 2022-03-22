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
