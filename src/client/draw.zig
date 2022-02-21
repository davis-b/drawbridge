const std = @import("std");
const math = std.math;
const c = @import("c.zig");

pub var Rectangle: c.SDL_Rect = c.SDL_Rect{
    .x = 0,
    .y = 0,
    .h = 1,
    .w = 1,
};

pub fn putRectangle(x: c_int, y: c_int, color: u32, surface: *c.SDL_Surface) void {
    //setPixel(x, y, color, surface);
    Rectangle.x = x;
    Rectangle.y = y;
    _ = c.SDL_FillRect(surface, &Rectangle, color);
}

pub fn circle(window: anytype, x: u64, y: u64, radius: u32) void {
    var index: u32 = 0;
    while (index != radius) : (index += 1) {
        const delta = radius - index;
        //putRectangle(x, y, color, surface);
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
        0xff0000,
        0x00ff00,
        0x0000ff,
    };
    var rectangle = c.SDL_Rect{ .x = 0, .y = 0, .h = 0, .w = 0 };
    for (colors) |color| {
        rectangle.x = x;
        rectangle.y = y;
        rectangle.w = size;
        rectangle.h = size;
        _ = c.SDL_FillRect(surface, &rectangle, color);
        x += step;
    }
}
