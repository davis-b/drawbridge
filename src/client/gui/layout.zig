const std = @import("std");

const client = @import("client");

pub const XY = struct { x: u16, y: u16 };

pub fn Geometry(comptime Element: type, comptime layout: []const []const Element) type {
    return struct {
        const ElementPlace = struct { element: Element, pos: XY };
        const LayoutT = [count(layout)]ElementPlace;
        const This = @This();

        elementSize: fn (Element) XY,

        /// The empty space before elements are initially drawn, and after they stop being drawn.
        margin: XY,

        /// The empty space between different elements.
        gap: XY,

        /// Given a position, return the element residing at that location, if one exists.
        pub fn selectedElement(self: *const This, pos: XY) ?ElementPlace {
            for (self.layout()) |e| {
                const size = self.elementSize(e.element);
                const matchX = (pos.x >= e.pos.x) and (pos.x <= e.pos.x + size.x);
                const matchY = (pos.y >= e.pos.y) and (pos.y <= e.pos.y + size.y);
                if (matchX and matchY) {
                    return e;
                }
            }
            return null;
        }

        pub fn layout(self: *const This) LayoutT {
            var result: LayoutT = undefined;
            var index: usize = 0;
            var pos = XY{ .x = self.margin.x, .y = self.margin.y };
            for (layout) |row, rowIndex| {
                for (row) |el, columnIndex| {
                    const size = self.elementSize(el);
                    // Adjust element y position so that it doesn't overlap with previous row.
                    if (rowIndex > 0) {
                        // The index of the 0th element from the previous row.
                        var prevRowIndex: usize = index - (columnIndex + layout[rowIndex - 1].len);
                        const ceiling = index - columnIndex;
                        while (prevRowIndex < ceiling) : (prevRowIndex += 1) {
                            const prev = result[prevRowIndex];
                            const prevSize = self.elementSize(prev.element);
                            const overlapX: bool = blk: {
                                const start = pos.x;
                                const end = pos.x + size.x + self.gap.x;
                                const prevStart = prev.pos.x;
                                const prevEnd = prev.pos.x + prevSize.x + self.gap.x;
                                break :blk start <= prevEnd and end >= prevStart;
                            };
                            if (overlapX) {
                                const start = pos.y;
                                const end = pos.y + size.y + self.gap.y;
                                const prevStart = prev.pos.y;
                                const prevEnd = prev.pos.y + prevSize.y + self.gap.y;
                                const overlapY: bool = start <= prevEnd and end >= prevStart;
                                if (overlapY) {
                                    pos.y = prevEnd;
                                }
                            }
                        }
                    }
                    result[index] = .{ .element = el, .pos = pos };
                    pos.x += size.x + self.gap.x;
                    index += 1;
                }
                pos.x = self.margin.x;
                pos.y += self.gap.y;
            }
            return result;
        }
    };
}

inline fn count(arrayOfArrays: anytype) u16 {
    var total: u16 = 0;
    for (arrayOfArrays) |array| {
        for (array) |_| total += 1;
    }
    return total;
}

const TestElement = enum { a, b, c };
fn testElementSize(element: TestElement) XY {
    return switch (element) {
        .a => .{ .x = 10, .y = 10 },
        .b => .{ .x = 30, .y = 20 },
        .c => .{ .x = 20, .y = 30 },
    };
}

const TestLayout = [_][]const TestElement{
    &.{ .a, .b, .c },
    &.{.b},
    &.{ .c, .b },
    &.{ .b, .a },
};

const testGeometry = Geometry(TestElement, TestLayout[0..]){
    .elementSize = testElementSize,
    .margin = .{ .x = 10, .y = 10 },
    .gap = .{ .x = 20, .y = 20 },
};

test "selected element" {
    const g = testGeometry;
    const a = testElementSize(.a);
    const b = testElementSize(.b);
    const c = testElementSize(.c);

    var start = XY{ .x = g.margin.x, .y = g.margin.y };
    var end = XY{ .x = start.x + a.x, .y = start.y + a.y };
    try std.testing.expectEqual(g.selectedElement(.{ .x = start.x, .y = start.y }).?.element, .a);
    try std.testing.expectEqual(g.selectedElement(.{ .x = end.x, .y = end.y }).?.element, .a);
    try std.testing.expectEqual(g.selectedElement(.{ .x = start.x, .y = start.y - 1 }), null);
    try std.testing.expectEqual(g.selectedElement(.{ .x = end.x + 1, .y = end.y }), null);
    try std.testing.expectEqual(g.selectedElement(.{ .x = end.x, .y = end.y + 1 }), null);

    start.x = end.x + g.gap.x;
    end.x += g.gap.x + b.x;
    end.y = g.margin.y + b.y;
    try std.testing.expectEqual(g.selectedElement(.{ .x = start.x, .y = end.y }).?.element, .b);
    try std.testing.expectEqual(g.selectedElement(.{ .x = end.x, .y = start.y }).?.element, .b);
    try std.testing.expectEqual(g.selectedElement(.{ .x = start.x - 1, .y = start.y }), null);
    try std.testing.expectEqual(g.selectedElement(.{ .x = end.x + 1, .y = start.y }), null);
    try std.testing.expectEqual(g.selectedElement(.{ .x = end.x, .y = end.y + 1 }), null);

    start = XY{ .x = g.margin.x, .y = 50 }; // we get 50 by looking at the nearest available y position for this element
    end = XY{ .x = start.x + b.x, .y = start.y + b.y };
    try std.testing.expectEqual(g.selectedElement(.{ .x = start.x, .y = end.y }).?.element, .b);
    try std.testing.expectEqual(g.selectedElement(.{ .x = end.x, .y = start.y }).?.element, .b);
    try std.testing.expectEqual(g.selectedElement(.{ .x = start.x - 1, .y = start.y }), null);
    try std.testing.expectEqual(g.selectedElement(.{ .x = end.x + 1, .y = start.y }), null);
    try std.testing.expectEqual(g.selectedElement(.{ .x = end.x + 1, .y = end.y }), null);
    try std.testing.expectEqual(g.selectedElement(.{ .x = end.x + 0, .y = end.y }).?.element, .b);
    try std.testing.expectEqual(g.selectedElement(.{ .x = end.x, .y = end.y + 1 }), null);

    start = XY{ .x = g.margin.x, .y = 50 + b.y + g.gap.y };
    end = XY{ .x = start.x + c.x, .y = start.y + c.y };
    try std.testing.expectEqual(g.selectedElement(.{ .x = start.x, .y = end.y }).?.element, .c);
    try std.testing.expectEqual(g.selectedElement(.{ .x = end.x, .y = start.y }).?.element, .c);
    try std.testing.expectEqual(g.selectedElement(.{ .x = start.x - 1, .y = start.y }), null);
    try std.testing.expectEqual(g.selectedElement(.{ .x = end.x + 1, .y = start.y }), null);
    try std.testing.expectEqual(g.selectedElement(.{ .x = end.x, .y = end.y + 1 }), null);
}
