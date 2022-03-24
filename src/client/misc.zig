const std = @import("std");

pub const Rectangle = struct {
    width: usize,
    height: usize,
};

pub const Dot = struct {
    x: c_int,
    y: c_int,
};

pub fn clamp(comptime T: type, item: *T, min: T, max: T) void {
    if (item.* > max) item.* = max;
    if (item.* < min) item.* = min;
}

pub fn memberType(comptime T: type, name: []const u8) type {
    inline for (std.meta.fields(T)) |f| {
        if (std.mem.eql(u8, f.name, name)) {
            return f.field_type;
        }
    }
    unreachable;
}
