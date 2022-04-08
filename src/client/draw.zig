const std = @import("std");
const log = std.log.scoped(.draw);
const math = std.math;
const c = @import("c.zig");
const Dot = @import("misc.zig").Dot;

pub var Rectangle: c.SDL_Rect = c.SDL_Rect{
    .x = 0,
    .y = 0,
    .h = 1,
    .w = 1,
};

pub inline fn setPixel(pos: Dot, color: u32, surface: *c.SDL_Surface) void {
    const pixels = @ptrCast([*]u32, @alignCast(4, surface.pixels.?));
    pixels[@intCast(usize, pos.x + (pos.y * surface.w))] = color;
}

pub fn putRectangle(x: c_int, y: c_int, color: u32, surface: *c.SDL_Surface) void {
    //setPixel(x, y, color, surface);
    Rectangle.x = x;
    Rectangle.y = y;
    _ = c.SDL_FillRect(surface, &Rectangle, color);
}

fn putARectangle(x: c_int, y: c_int, color: u32, rect: *c.SDL_Rect, surface: *c.SDL_Surface) void {
    rect.x = x;
    rect.y = y;
    _ = c.SDL_FillRect(surface, rect, color);
}

/// Draw a rectangle with edges at 'start' and 'end'
pub fn rectangle(start: Dot, end: Dot, color: u32, thickness: u16, surface: *c.SDL_Surface) void {
    var rect: c.SDL_Rect = c.SDL_Rect{ .x = 0, .y = 0, .h = thickness, .w = thickness };
    const deltaX = math.absInt(start.x - end.x) catch |err| blk: {
        log.err("draw.rectangle() absInt error: {}", .{err});
        break :blk 1;
    };
    const deltaY = math.absInt(start.y - end.y) catch |err| blk: {
        log.err("draw.rectangle() absInt error: {}", .{err});
        break :blk 1;
    };

    const x1 = std.math.min(start.x, end.x);
    const y1 = std.math.min(start.y, end.y);
    const x2 = std.math.max(start.x, end.x);
    const y2 = std.math.max(start.y, end.y);

    // horizontal lines
    rect.w = deltaX;
    putARectangle(x1, y1, color, &rect, surface);
    putARectangle(x1, y2, color, &rect, surface);

    // vertical lines
    rect.w = thickness;
    rect.h = deltaY;
    putARectangle(x2, y1, color, &rect, surface);
    putARectangle(x1, y1, color, &rect, surface);

    rect.h = thickness;
    putARectangle(x2, y2, color, &rect, surface);
}

pub fn rectangleFilled(start: Dot, end: Dot, color: u32, surface: *c.SDL_Surface) void {
    const deltaX = math.absInt(start.x - end.x) catch |err| blk: {
        log.err("draw.rectangle() absInt error: {}", .{err});
        break :blk 1;
    };
    const deltaY = math.absInt(start.y - end.y) catch |err| blk: {
        log.err("draw.rectangle() absInt error: {}", .{err});
        break :blk 1;
    };
    var rect: c.SDL_Rect = c.SDL_Rect{ .x = std.math.min(start.x, end.x), .y = std.math.min(start.y, end.y), .h = deltaY, .w = deltaX };
    _ = c.SDL_FillRect(surface, &rect, color);
}

/// Draws a filled in circle on the given surface.
pub fn circleFilled(pos: Dot, radius: u16, color: u32, surface: *c.SDL_Surface) void {
    var rect = c.SDL_Rect{ .x = 0, .y = 0, .h = 1, .w = 1 };
    var err: c_int = -@intCast(i16, radius);
    var x: c_int = radius;
    var y: c_int = 0;
    while (x >= y) {
        const lastY = y;
        err += (y * 2) + 1;
        y += 1;

        rect.w = x * 2;
        putARectangle(pos.x - x, pos.y + lastY, color, &rect, surface);
        if (y != 0) {
            putARectangle(pos.x - x, pos.y - lastY, color, &rect, surface);
        }

        if (err >= 0) {
            if (x != lastY) {
                rect.w = lastY * 2;
                putARectangle(pos.x - lastY, pos.y + x, color, &rect, surface);
                if (y != 0) {
                    putARectangle(pos.x - lastY, pos.y - x, color, &rect, surface);
                }
            }
            err -= (x * 2);
            x -= 1;
            err += 1;
        }
    }
}

/// Utilizes the "midpoint circle algorithm" to draw the outline of a circle on the given surface.
pub fn circleOutline(pos: Dot, radius: u16, color: u32, surface: *c.SDL_Surface) void {
    var rect = c.SDL_Rect{ .x = 0, .y = 0, .h = 1, .w = 1 };
    var x: c_int = radius - 1;
    var y: c_int = 0;
    var dx: c_int = 1;
    var dy: c_int = 1;
    var err: c_int = dx - (radius << 1);
    while (x >= y) {
        putARectangle(pos.x + x, pos.y + y, color, &rect, surface);
        putARectangle(pos.x - x, pos.y + y, color, &rect, surface);
        putARectangle(pos.x - x, pos.y - y, color, &rect, surface);
        putARectangle(pos.x + x, pos.y - y, color, &rect, surface);
        putARectangle(pos.x + y, pos.y + x, color, &rect, surface);
        putARectangle(pos.x - y, pos.y + x, color, &rect, surface);
        putARectangle(pos.x - y, pos.y - x, color, &rect, surface);
        putARectangle(pos.x + y, pos.y - x, color, &rect, surface);

        if (err <= 0) {
            y += 1;
            err += dy;
            dy += 2;
        }
        if (err > 0) {
            x -= 1;
            dx += 2;
            err += dx - (radius << 1);
        }
    }
}

pub fn diamond(pos: Dot, radius: u16, color: u32, surface: *c.SDL_Surface) void {
    var rect = c.SDL_Rect{ .x = 0, .y = 0, .h = 1, .w = 0 };
    var index: c_int = 0;
    while (index != radius) : (index += 1) {
        rect.w = index * 2;
        putARectangle(pos.x - index, pos.y + index, color, &rect, surface);
        putARectangle(pos.x - index, ((pos.y - 1) + (radius * 2)) - index, color, &rect, surface);
    }
}

pub fn line(xstart: c_int, xlength: c_int, ystart: c_int, ylength: c_int, color: u32, surface: *c.SDL_Surface) !void {
    const xsteps: c_int = try math.absInt(xlength);
    const ysteps: c_int = try math.absInt(ylength);
    const maxsteps: c_int = math.max(xsteps, ysteps);
    const minsteps: c_int = math.min(xsteps, ysteps);
    const delta_err: f32 = @intToFloat(f32, minsteps) / @intToFloat(f32, maxsteps);

    const z: i3 = 0;
    const one: i3 = 1;
    var x_step_direction: c_int = if (xlength < z) -one else one;
    var y_step_direction: c_int = if (ylength < z) -one else one;

    const errthreshold = 1.0;
    const errminus = 1.0;

    var ystep: c_int = 0;
    var xstep: c_int = 0;
    var err: f32 = 0.0;
    if (xsteps == maxsteps) {
        while (xstep != xlength) : (xstep += x_step_direction) {
            if (err >= errthreshold) {
                ystep += y_step_direction;
                err -= errminus;
            }
            err += delta_err;
            putRectangle(xstart - xstep, ystart - ystep, color, surface);
        }
    } else {
        while (ystep != ylength) : (ystep += y_step_direction) {
            if (err >= errthreshold) {
                xstep += x_step_direction;
                err -= errminus;
            }
            err += delta_err;
            putRectangle(xstart - xstep, ystart - ystep, color, surface);
        }
    }
}

pub fn line2(xstart: c_int, xlength: c_int, ystart: c_int, ylength: c_int, color: u32, surface: *c.SDL_Surface) !void {
    // has deadzone near the middle where drawing only occurs in one direction
    const xsteps: c_int = try math.absInt(xlength);
    const ysteps: c_int = try math.absInt(ylength);
    const step_difference: c_int = try math.absInt(xsteps - ysteps);
    const maxsteps: c_int = math.max(xsteps, ysteps);
    const minsteps: c_int = math.min(xsteps, ysteps);

    const z: i3 = 0;
    const one: i3 = 1;
    var x_step_direction: c_int = if (xlength < z) -one else one;
    var y_step_direction: c_int = if (ylength < z) -one else one;

    const deadzone_start: c_int = @divFloor(maxsteps, 2);
    const deadzone_end = deadzone_start + step_difference;
    var fewsteps: c_int = 0;
    var moresteps: c_int = 0;
    if (xsteps == maxsteps) {
        while (moresteps != xlength) : (moresteps += x_step_direction) {
            if (fewsteps != ylength and (moresteps < deadzone_start or moresteps > deadzone_end)) fewsteps += y_step_direction;
            putRectangle(xstart - moresteps, ystart - fewsteps, color, surface);
        }
    } else {
        while (moresteps != ylength) : (moresteps += y_step_direction) {
            if (fewsteps != xlength and (moresteps < deadzone_start or moresteps > deadzone_end)) fewsteps += x_step_direction;
            putRectangle(xstart - fewsteps, ystart - moresteps, color, surface);
        }
    }
}

pub fn thing(fgColor: u32, surface: *c.SDL_Surface) void {
    line2(280, -50, 280, -90, fgColor, surface) catch unreachable;
    line2(320, 50, 320, 90, fgColor, surface) catch unreachable;
    line2(280, -50, 320, 90, fgColor, surface) catch unreachable;
    line2(320, 50, 280, -90, fgColor, surface) catch unreachable;
}

pub fn squares(surface: *c.SDL_Surface) void {
    var x: c_int = 300;
    var y: c_int = 20;
    const size = 50;
    const step = size + 20;
    const colors = [_]u32{
        0xff0000ff,
        0x00ff00ff,
        0x0000ffff,
    };
    var rect = c.SDL_Rect{ .x = 0, .y = 0, .h = 0, .w = 0 };
    for (colors) |color| {
        rect.x = x;
        rect.y = y;
        rect.w = size;
        rect.h = size;
        _ = c.SDL_FillRect(surface, &rect, color);
        x += step;
    }
}
