const std = @import("std");
const log = std.log.scoped(.gui);

const Tool = @import("../tools.zig").Tool;
const User = @import("../users.zig").User;
const sdl = @import("../sdl/index.zig");

const Surfaces = @import("index.zig").Surfaces;
const Dimensions = @import("index.zig").Dimensions;
const draw = @import("draw.zig");
const header = @import("header.zig");

pub const Event = union(enum) {
    tool_change: Tool,
    tool_resize_slider: f16,
};

/// Takes a parent surface and our GUI surfaces, as well as the position of the click.
/// This function handles button presses to any GUI element.
/// Therefore, to get the x/y positions of a click inside a specific element,
/// we must take into account that overlapping gui elements occur in some places.
/// We layer our button handling to match the visual layering, where the last blitted item will appear above lower ones.
/// For instance, the left side bar starts at y0, however it is not visible until y + (header height), therefore
/// clicks should adjust their y position by the header's height.
pub fn handleButtonPress(parent: *sdl.Surface, s: *Surfaces, user: *const User, x: c_int, y: c_int) ?Event {
    // header
    if (y <= s.header.h) {
        log.debug("header {}x{}", .{ x, y });
        const mid = @divFloor((parent.w - s.header.w), 2);
        return handleHeaderPress(user.tool, x - mid, user.size);
    }
    // footer
    else if (y >= parent.h - s.footer.h) {
        const newY = y - (parent.h - s.footer.h);
        log.debug("footer {}x{}", .{ x, newY });
    }
    // left sidebar
    else if (x <= s.left.w) {
        const newY = y - s.header.h;
        if (whichToolPressed(newY)) |tool| {
            return Event{ .tool_change = tool };
        }
    }
    // right sidebar
    else if (x >= parent.w - s.right.w) {
        const newX = x - (parent.w - s.right.w);
        log.debug("right {}x{}", .{ newX, y });
    }
    return null;
}

fn whichToolPressed(y: c_int) ?Tool {
    const newY = y - draw.toolStartY;
    const toolSize = draw.toolGap + draw.toolHeight;
    if (newY < 0) return null;
    const toolIndex = @divTrunc(newY, toolSize);
    if (toolIndex < 0 or toolIndex >= @typeInfo(Tool).Enum.fields.len) return null;
    const tool = @intToEnum(Tool, @intCast(std.meta.Tag(Tool), toolIndex));
    return tool;
}

fn handleHeaderPress(tool: Tool, x: c_int, toolSize: u8) ?Event {
    var startPos: u16 = header.margin;
    for (header.activeElements(tool)) |elem| {
        const w = header.elementWidth(elem);
        if (x > startPos and x < startPos + w) {
            log.debug("header pressed {}", .{elem});
            switch (elem) {
                .tool_size => {
                    var clicked = x - startPos;
                    if (header.ToolSize.clickedWhere(@intCast(u16, clicked))) |p| {
                        return Event{ .tool_resize_slider = p };
                    } else return null;
                },
                .color => {},
            }
            break;
        }
        startPos += w + header.elementGap;
    }
    return null;
}
