const std = @import("std");

pub const Image = struct {
    allocator: *std.mem.Allocator,
    data: []u32,
    width: usize,
    height: usize,

    pub fn init(allocator: *std.mem.Allocator, width: usize, height: usize) !Image {
        var data = try allocator.alloc(u32, width * height);
        return Image{
            .allocator = allocator,
            .data = data,
            .width = width,
            .height = height,
        };
    }

    fn deinit(self: *Image) void {
        self.allocator.free(self.data);
    }
};
