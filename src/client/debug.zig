const std = @import("std");
const warn = std.debug.warn;

pub const Levels = enum {
    info,
    debug,
    warn,
    err,
};

pub fn log(comptime level: Levels, comptime fmt: []const u8, args: anytype) void {
    const name = switch (level) {
        .info => "Info",
        .debug => "Debug",
        .warn => "Warn ",
        .err => "Error",
    };
    print(name, fmt, args);
}

pub fn print(comptime header: []const u8, comptime fmt: []const u8, args: anytype) void {
    warn("[" ++ header ++ " {}] ", .{timestamp()});
    warn(fmt, args);
}

// returns final 4 digits of standard unix epoch timestamp
fn timestamp() i64 {
    return @mod(std.time.timestamp(), 10000);
}
