const std = @import("std");
const log = std.log.scoped(.gui_footer);

const Tool = @import("../tools.zig").Tool;
const Dot = @import("../misc.zig").Dot;
const layout = @import("layout.zig");

const widgets = @import("widgets.zig");

pub const ColorSlider = widgets.Slider{
    .len = 150,
    .textLen = 35,
    .textGap = 15,
    .startMargin = 7,
    .radius = 7,
};

/// The height of each ColorSlider, including the gap between sliders.
pub const sliderHeight = 25;

/// The number of sliders within the "color_sliders" Element.
pub const sliderCount = 3;

pub const geometry = layout.Geometry(Element, elementLayout[0..]){
    .elementSize = elementSize,
    .margin = .{ .x = 50, .y = 20 },
    .gap = .{ .x = 10, .y = 10 },
};

const Element = enum { color_sliders, color_display };

const elementLayout = [_][]const Element{
    &.{ .color_sliders, .color_display },
};

fn elementSize(element: Element) layout.XY {
    return switch (element) {
        .color_sliders => .{ .x = ColorSlider.len, .y = sliderHeight * sliderCount }, // * 4 if we start using alpha.
        .color_display => .{ .x = sliderHeight * sliderCount, .y = sliderHeight * sliderCount },
    };
}
