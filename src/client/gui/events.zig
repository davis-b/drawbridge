const std = @import("std");
const log = std.log.scoped(.gui);

const Tool = @import("../tools.zig").Tool;
const User = @import("../users.zig").User;
const Dot = @import("../misc.zig").Dot;
const sdl = @import("../sdl/index.zig");

const Surfaces = @import("index.zig").Surfaces;
const Dimensions = @import("index.zig").Dimensions;
const draw = @import("draw.zig");
const header = @import("header.zig");

pub const Event = union(enum) {
    tool_change: Tool,
    tool_resize_slider: f16,
};

const GuiElement = enum { header, footer, left, right };
fn mouseIsWhere(parent: *sdl.Surface, s: *Surfaces, pos: Dot) ?GuiElement {
    if (pos.y <= s.header.h) {
        return .header;
    } else if (pos.y >= parent.h - s.footer.h) {
        return .footer;
    } else if (pos.x <= s.left.w) {
        return .left;
    } else if (pos.x >= parent.w - s.right.w) {
        return .right;
    }
    return null;
}

/// Takes a parent surface and our GUI surfaces, as well as the position of the click.
/// This function handles button presses to any GUI element.
/// Therefore, to get the x/y positions of a click inside a specific element,
/// we must take into account that overlapping gui elements occur in some places.
/// We layer our button handling to match the visual layering, where the last blitted item will appear above lower ones.
/// For instance, the left side bar starts at y0, however it is not visible until y + (header height), therefore
/// clicks should adjust their y position by the header's height.
pub fn handleButtonPress(parent: *sdl.Surface, s: *Surfaces, user: *const User, pos: Dot) ?Event {
    switch (mouseIsWhere(parent, s, pos) orelse return null) {
        .header => {
            const mid = @divFloor((parent.w - s.header.w), 2);
            return handleHeaderPress(pos.x - mid, user.tool, user.size);
        },
        .footer => {
            const newY = pos.y - (parent.h - s.footer.h);
            log.debug("footer {}x{}", .{ pos.x, newY });
        },
        .left => {
            const newY = pos.y - s.header.h;
            if (whichToolPressed(newY)) |tool| {
                return Event{ .tool_change = tool };
            }
        },
        .right => {
            const newX = pos.x - (parent.w - s.right.w);
            log.debug("right {}x{}", .{ newX, pos.y });
        },
    }
    return null;
}

pub fn handleMotion(parent: *sdl.Surface, s: *Surfaces, user: *const User, clicking: bool, pos: Dot, delta: Dot) ?Event {
    const where = mouseIsWhere(parent, s, pos) orelse return null;
    switch (where) {
        .header => {
            if (clicking) {
                const mid = @divFloor((parent.w - s.header.w), 2);
                return handleHeaderPress(pos.x - mid, user.tool, user.size);
            }
        },
        else => {},
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

fn handleHeaderPress(x: c_int, tool: Tool, toolSize: u8) ?Event {
    var startPos: u16 = header.margin;
    for (header.activeElements(tool)) |elem| {
        const w = header.elementWidth(elem);
        if (x > startPos and x < startPos + w) {
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
