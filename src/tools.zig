const draw = @import("draw.zig");
const c = @import("c.zig");

pub fn pencil(x: c_int, y: c_int, deltaX: c_int, deltaY: c_int, color: u32, surface: *c.SDL_Surface) void {
    draw.putRectangle(x, y, color, surface);
    //Todo: Line that decreases width/height to reduce jaggedness.
    // So the size becomes the max size and the lower change between height/width becomes a reduction in that category.
    draw.line(x, deltaX, y, deltaY, color, surface) catch unreachable;
}
