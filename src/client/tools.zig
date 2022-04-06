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

pub fn eraser(x: c_int, y: c_int, deltaX: c_int, deltaY: c_int, color: u32, surface: *c.SDL_Surface) void {
    //
}

pub fn bucket(x: c_int, y: c_int, color: u32, surface: *c.SDL_Surface) void {}

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
