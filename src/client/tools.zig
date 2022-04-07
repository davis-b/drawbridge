const std = @import("std");
const draw = @import("draw.zig");
const User = @import("users.zig").User;
const Dot = @import("misc.zig").Dot;

const c = @import("c.zig");

pub const Tool = enum(u8) {
    pencil,
    eraser,
    bucket,
    color_picker,
};

pub fn pencil(pos: Dot, deltaX: c_int, deltaY: c_int, user: *User, surface: *c.SDL_Surface) void {
    draw.Rectangle.h = user.size;
    draw.Rectangle.w = user.size;
    draw.putRectangle(pos.x, pos.y, user.color, surface);
    draw.line(pos.x, deltaX, pos.y, deltaY, user.color, surface) catch unreachable;
}

pub fn eraser(pos: Dot, delta: Dot, color: u32, surface: *c.SDL_Surface) void {
    //
}

pub fn bucket(pos: Dot, color: u32, surface: *c.SDL_Surface) void {
    // Find color at pos
    const cPixels = @alignCast(4, surface.pixels.?);
    const pixels = @ptrCast([*]u32, cPixels);
    const baseIndex = @intCast(usize, (pos.y * surface.w) + pos.x);
    const baseColor = pixels[baseIndex];
    if (baseColor == color) return;
    const totalPixels = @intCast(usize, surface.w * surface.h);

    spanFill(pos, baseColor, color, pixels, totalPixels, surface) catch unreachable;
}

fn spanFill(index: Dot, originalColor: u32, newColor: u32, pixels: [*]u32, max: usize, surface: *c.SDL_Surface) !void {
    if (!inside(index.x, index.y, surface.w, max, pixels, originalColor)) return;
    var s = std.ArrayList([2]Dot).init(std.heap.c_allocator);
    defer s.deinit();
    try s.append(.{ index, .{ .x = index.x, .y = 1 } });
    try s.append(.{ .{ .x = index.x, .y = index.y - 1 }, .{ .x = index.x, .y = -1 } });
    while (s.popOrNull()) |i| {
        var x1 = i[0].x;
        var x2 = i[1].x;
        var y = i[0].y;
        var dy = i[1].y;
        var x = x1;

        if (inside(x, y, surface.w, max, pixels, originalColor)) {
            while (inside(x - 1, y, surface.w, max, pixels, originalColor)) {
                set(x - 1, y, newColor, pixels, surface);
                x -= 1;
            }
        }
        if (x < x1) {
            try s.append(.{ .{ .x = x, .y = y - dy }, .{ .x = x1 - 1, .y = -dy } });
        }
        while (x1 <= x2) {
            while (inside(x1, y, surface.w, max, pixels, originalColor)) {
                set(x1, y, newColor, pixels, surface);
                x1 += 1;
            }
            try s.append(.{ .{ .x = x, .y = y + dy }, .{ .x = x1 - 1, .y = dy } });
            if (x1 - 1 > x2) {
                try s.append(.{ .{ .x = x2 + 1, .y = y - dy }, .{ .x = x1 - 1, .y = -dy } });
            }
            x1 += 1;
            while (x1 < x2 and !inside(x1, y, surface.w, max, pixels, originalColor)) {
                x1 += 1;
            }
            x = x1;
        }
    }
}

fn inside(x: c_int, y: c_int, w: c_int, max: usize, pixels: [*]u32, target: u32) bool {
    if (x >= w or x < 0 or y < 0) return false;
    const total = x + (y * w);
    if (total < 1 or total > max) return false;
    return pixels[@intCast(usize, total)] == target;
}

fn set(x: c_int, y: c_int, color: u32, pixels: [*]u32, surface: *c.SDL_Surface) void {
    pixels[@intCast(usize, x + (y * surface.w))] = color;
}


/// Given a surface and a position within that surface, return
/// a 4 byte pixel at that location.
pub fn color_picker(pos: Dot, surface: *c.SDL_Surface) u32 {
    const cPixels = @alignCast(4, surface.pixels.?);
    const pixels = @ptrCast([*]u32, cPixels);
    const flatPos = @intCast(usize, (pos.y * surface.w) + pos.x);
    const color = pixels[flatPos];
    return color;
}

pub fn rectangle(start: Dot, end: Dot, user: *User, surface: *c.SDL_Surface) void {
    draw.rectangle(start, end, user.color, user.size, surface);
}

// fn mirror_pencil() void {
//     const halfwidth = @divFloor(world.image.surface.w, 2);
//     const halfheight = @divFloor(world.image.surface.h, 2);
//     const deltaW = x - halfwidth;
//     const deltaH = y - halfheight;
//     // mirror x
//     tools.pencil(halfwidth - deltaW, y, -deltaX, deltaY, user.color, world.image.surface);
//     // mirror y
//     tools.pencil(x, halfheight - deltaH, deltaX, -deltaY, user.color, world.image.surface);
//     // mirror xy (diagonal corner)
//     tools.pencil(halfwidth - deltaW, halfheight - deltaH, -deltaX, -deltaY, user.color, world.image.surface);
// }
