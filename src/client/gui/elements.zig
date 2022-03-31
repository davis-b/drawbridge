const std = @import("std");
const log = std.log.scoped(.gui);

const sdl = @import("../sdl/index.zig");
const Surface = sdl.Surface;
const surface_draw = @import("../draw.zig");
const Dot = @import("../misc.zig").Dot;
const text = @import("font.zig");

const Colors_ = struct {
    primary: u32 = 0x9a77ba,
    secondary: u32 = 0xaaffbb,
    highlight: u32 = 0xbb77bb,
    bg_shadow: u32 = 0x030f2b,
    background: u32 = 0x554453,
    text: u32 = 0xffffff,
};
pub var Colors = Colors_{};

/// A slider element with optional text output.
pub const Slider = struct {
    /// The total length of this element. Includes the slider as well as the text.
    len: u16,

    /// The maximum allotted length (in pixels; traveling in the direction of the slider) of the text following the slider.
    textLen: u16,

    /// The gap between the size slider and the following text.
    textGap: u16,

    /// A space at the beginning of this element to allow for a more generous sliding area. 
    startMargin: u8,

    /// The total length of the slider portion of this element.
    pub fn sliderLen(self: *const Slider) u16 {
        return self.len - (self.textLen + self.textGap + self.startMargin);
    }

    /// Draws the slider element.
    /// The activePercent argument dictates where the slider circle will appear.
    pub fn draw(self: *const Slider, surface: *Surface, pos: Dot, activePercent: f16, thickness: u8, radius: u8, direction: enum { horizontal, vertical }) void {
        const len = self.sliderLen();
        const activePos = @floatToInt(u16, activePercent * @intToFloat(f16, len));
        switch (direction) {
            .horizontal => {
                surface_draw.rectangle(pos, .{ .x = pos.x + len, .y = pos.y }, Colors.background, thickness, surface);
                surface_draw.circleFilled(.{ .x = pos.x + activePos, .y = pos.y }, radius, Colors.primary, surface);
            },
            .vertical => {
                surface_draw.rectangle(pos, .{ .x = pos.x, .y = pos.y + len }, Colors.background, thickness, surface);
                surface_draw.circleFilled(.{ .x = pos.x, .y = pos.y + activePos }, radius, Colors.primary, surface);
            },
        }
    }

    /// Draws a string following the slider itself.
    /// Currently only works with horizontal sliders.
    pub fn drawString(self: *const Slider, surface: *Surface, string: []const u8, size: u8, pos: Dot) void {
        text.write(
            surface,
            string,
            .{
                .x = pos.x + self.sliderLen() + self.textGap + self.startMargin,
                .y = pos.y - @divFloor(text.letterHeight, 2),
            },
            size,
            Colors.text,
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
        // This can be true when we click past the slider, into the text area of the element.
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
