const std = @import("std");
const log = std.log.scoped(.gui_header);
const Tool = @import("../tools.zig").Tool;
const widgets = @import("widgets.zig");

/// The number of pixels between each header element.
pub const elementGap = 20;

/// The empty space on each side of the header, before elements are drawn.
pub const margin = 50;

/// Context sensitive elements.
pub const ContextElement = enum {
    tool_size,
    color,
};

pub const ToolSize = widgets.Slider{
    .len = elementWidth(.tool_size),
    .textLen = 25,
    .textGap = 15,
    .startMargin = 7,
};

pub fn elementWidth(element: ContextElement) u16 {
    return switch (element) {
        .tool_size => 140,
        .color => 20,
    };
}

/// Returns the relevant header elements for a given tool.
pub fn activeElements(activeTool: Tool) []const ContextElement {
    return switch (activeTool) {
        .pencil => &[_]ContextElement{ .color, .tool_size },
        .eraser => &[_]ContextElement{.tool_size},
        .bucket => &[_]ContextElement{.color},
        .color_picker => &[_]ContextElement{.color},
    };
}
