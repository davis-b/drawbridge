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
const footer = @import("footer.zig");

pub const Event = union(enum) {
    tool_change: Tool,
    tool_resize_slider: f16,
    tool_recolor: u32,
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
            const mid = @divFloor((parent.w - s.footer.w), 2);
            return handleFooterPress(.{ .x = pos.x - mid, .y = newY }, user.color);
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
        .footer => {
            if (clicking) {
                const mid = @divFloor((parent.w - s.footer.w), 2);
                const newY = pos.y - (parent.h - s.footer.h);
                return handleFooterPress(.{ .x = pos.x - mid, .y = newY }, user.color);
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

fn handleFooterPress(pos: Dot, userColor: u32) ?Event {
    if (pos.x < 0 or pos.y < 0) return null;
    if (footer.geometry.selectedElement(.{ .x = @intCast(u16, pos.x), .y = @intCast(u16, pos.y) })) |ep| {
        switch (ep.element) {
            .color_sliders => {
                const clickY = pos.y - ep.pos.y;
                if (clickY < 0) {
                    log.err("Unexpected footer position calculation error. Pos: {} | Expected Selected Element: {}. {}-{}={}", .{ pos, ep, pos.y, ep.pos.y, clickY });
                    return null;
                }
                var whichSlider = @intCast(u32, @divFloor(clickY, footer.sliderHeight));
                // Don't register clicks that reside clearly between two sliders and on neither.
                if (@rem(clickY, footer.sliderHeight) > footer.sliderHeight - (footer.sliderHeight / 3)) {
                    return null;
                }
                const clicked = pos.x - ep.pos.x;
                if (footer.ColorSlider.clickedWhere(@intCast(u16, clicked))) |p| {
                    // Determine the new value of the color based off the position of the slider.
                    var newSingleColor = @floatToInt(u8, p * std.math.maxInt(u8));
                    var newColor = userColor;
                    // Replace either R, G, or B with the newly selected color.
                    @ptrCast(*[4]u8, &newColor)[2 - whichSlider] = newSingleColor;
                    return Event{ .tool_recolor = newColor };
                } else return null;
            },
            .color_display => return null,
        }
    }
    return null;
}
