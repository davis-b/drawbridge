const std = @import("std");
const log = std.log.scoped(.gui);

const sdl = @import("../sdl/index.zig");
const Surface = sdl.Surface;
const surface_draw = @import("../draw.zig");
const Dot = @import("../misc.zig").Dot;
const text = @import("font.zig");

const Colors_ = struct {
    primary: u32 = 0x9a77baff,
    secondary: u32 = 0x554453ff,
    highlight: u32 = 0xbb77bbff,
    bg_shadow: u32 = 0x030f2bff,
    background: u32 = 0x142238ff,
    text: u32 = 0xffffffff,
};
pub var Colors = Colors_{};

/// A slider widget with optional text output.
pub const Slider = struct {
    /// The total length of this widget. Includes the slider as well as the text.
    len: u16,

    /// The maximum allotted length (in pixels; traveling in the direction of the slider) of the text following the slider.
    textLen: u16,

    /// The gap between the size slider and the following text.
    textGap: u16,

    /// A space at the beginning of this widget to allow for a more generous sliding area. 
    startMargin: u8,

    /// The radius of this slider's active element.
    radius: u8,

    colors: ?Colors_ = null,

    /// The total length of the slider portion of this widget.
    pub fn sliderLen(self: *const Slider) u16 {
        return self.len - (self.textLen + self.textGap + self.startMargin);
    }

    /// Draws the slider widget.
    /// The activePercent argument dictates where the slider circle will appear.
    pub fn draw(self: *const Slider, surface: *Surface, pos_: Dot, activePercent: f16, thickness: u8, direction: enum { horizontal, vertical }) void {
        const pos = Dot{ .x = pos_.x + self.startMargin, .y = pos_.y };
        const len = self.sliderLen();
        const activePos = @floatToInt(u16, activePercent * @intToFloat(f16, len));
        const colors = self.colors orelse Colors;
        switch (direction) {
            .horizontal => {
                surface_draw.rectangle(pos, .{ .x = pos.x + len, .y = pos.y }, colors.secondary, thickness, surface);
                surface_draw.circleFilled(.{ .x = pos.x + activePos, .y = pos.y }, self.radius, colors.primary, surface);
            },
            .vertical => {
                surface_draw.rectangle(pos, .{ .x = pos.x, .y = pos.y + len }, colors.secondary, thickness, surface);
                surface_draw.circleFilled(.{ .x = pos.x, .y = pos.y + activePos }, self.radius, colors.primary, surface);
            },
        }
    }

    /// Draws a string following the slider itself.
    /// Currently only works with horizontal sliders.
    pub fn drawString(self: *const Slider, surface: *Surface, string: []const u8, size: u8, pos: Dot) void {
        const colors = self.colors orelse Colors;
        text.write(
            surface,
            string,
            .{
                .x = pos.x + self.sliderLen() + self.textGap + self.startMargin,
                .y = pos.y - @divFloor(text.letterHeight, 2),
            },
            size,
            colors.text,
            self.textLen,
        );
    }

    /// Takes a position on the directional axis indicating where a click occurred.
    /// Returns where the click occurred as a percentage of the total slider bar length.
    /// Can return null if the click took place outside the slider area.
    pub fn clickedWhere(self: *const Slider, position: u16) ?f16 {
        // User has clicked within the safety margin provided at the leftmost area of the slider.
        // While not technically on the slider, this workaround greatly improves the feel of the slider.
        if (position <= self.startMargin) return 0;

        // We remove the start margin to get the actual position along the visible slider.
        const realPos = position - self.startMargin;
        const slen = self.sliderLen();
        // This can be true when we click past the slider, into the text area of the widget.
        if (realPos >= slen) return null;

        const percent = @intToFloat(f16, realPos) / @intToFloat(f16, slen);
        return percent;
    }

    /// Takes a percentage, a maximum value, and a current value.
    /// Returns a number that maps closely to the percentage of that maximum value.
    /// The returned number may be smaller than expected when it is close to the current value.
    /// This is done to make for less jerky sliding motions.
    pub fn applySlideEvent(self: *const Slider, comptime T: type, percent: f16, current: T, maximum: T) T {
        var new = @floatToInt(T, @intToFloat(f16, maximum) * percent);
        const larger = std.math.max(new, current);
        const smaller = std.math.min(new, current);
        const delta = larger - smaller;

        var offset: T = delta;
        if (delta == 0) {
            return current;
        } else if (delta < 5) {
            offset = 1;
        } else if (delta < 10) {
            offset = 2;
        }
        const result = if (new >= current) current + offset else current - offset;
        return @intCast(T, result);
    }
};
