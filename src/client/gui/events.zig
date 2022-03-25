const std = @import("std");
const log = std.log.scoped(.gui);

const Tool = @import("../tools.zig").Tool;
const sdl = @import("../sdl/index.zig");

const Surfaces = @import("index.zig").Surfaces;
const Dimensions = @import("index.zig").Dimensions;
const draw = @import("draw.zig");

/// Takes a parent surface and our GUI surfaces, as well as the position of the click.
/// This function handles button presses to any GUI element.
/// Therefore, to get the x/y positions of a click inside a specific element,
/// we must take into account that overlapping gui elements occur in some places.
/// We layer our button handling to match the visual layering, where the last blitted item will appear above lower ones.
/// For instance, the left side bar starts at y0, however it is not visible until y + (header height), therefore
/// clicks should adjust their y position by the header's height.
pub fn handleButtonPress(parent: *sdl.Surface, s: *Surfaces, x: c_int, y: c_int) void {
    // header
    if (y <= s.header.h) {
        handleHeaderPress(parent, s.header, x, y);
        log.debug("header {}x{}", .{ x, y });
    }
    // footer
    else if (y >= parent.h - s.footer.h) {
        const new_y = y - (parent.h - s.footer.h);
        log.debug("footer {}x{}", .{ x, new_y });
    }
    // left sidebar
    else if (x <= s.left.w) {
        const new_y = y - s.header.h;
        const tool = whichToolPressed(new_y);
        log.debug("{}", .{tool});
    }
    // right sidebar
    else if (x >= parent.w - s.right.w) {
        const new_x = x - (parent.w - s.right.w);
        log.debug("right {}x{}", .{ new_x, y });
    }
}

fn handleHeaderPress(parent: *sdl.Surface, header: *sdl.Surface, x: c_int, y: c_int) void {
    // TODO
    // Seems like we may need to pass around structs with more state than sdl.Surface provides.
    // handleButtonPress may also need *state.World so that we may enact meaningful change.
    //  Alternatively, we could return a requested outcome, such as changeColor, newImage.
    //   Although, both of those require extra data, such as a color or a new image size.
    //   Unless we handle the gathering of that data at the call site, rather than within the gui code.
}

fn whichToolPressed(y: c_int) ?Tool {
    const new_y = y - draw.toolStartY;
    const toolSize = draw.toolGap + draw.toolHeight;
    if (new_y < 0) return null;
    const toolIndex = @divTrunc(new_y, toolSize);
    if (toolIndex < 0 or toolIndex >= @typeInfo(Tool).Enum.fields.len) return null;
    const tool = @intToEnum(Tool, @intCast(std.meta.Tag(Tool), toolIndex));
    return tool;
}
