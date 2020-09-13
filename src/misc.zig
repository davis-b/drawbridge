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
