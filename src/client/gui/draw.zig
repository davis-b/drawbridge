const std = @import("std");
const log = std.log.scoped(.gui);

const Tool = @import("../tools.zig").Tool;
const User = @import("../users.zig").User;
const Peers = @import("../users.zig").Peers;
const surface_draw = @import("../draw.zig");
const Dot = @import("../misc.zig").Dot;
const c = @import("../c.zig");
const sdl = @import("../sdl/index.zig");
const fillRect = sdl.display.fillRect;
const Surface = sdl.Surface;

const widgets = @import("widgets.zig");
const Surfaces = @import("index.zig").Surfaces;
const Dimensions = @import("index.zig").Dimensions;
const header_info = @import("header.zig");
const text = @import("font.zig");

pub const toolHeight = 30;
const toolWidth = 30;
pub const toolGap = 5;
pub const toolStartY = 30;

const peerToolHeight = 20;
const peerToolWidth = 20;
const peerToolColorGap = 3;
const peerToolColorHeight = 3;
const peerToolGap = peerToolColorGap + peerToolColorHeight + 7;

pub const Draw = struct {
    pub fn header(surface: *Surface, user: *const User) void {
        // This could be a good spot for tool specific options,
        // such as: pencil tip type (square/circle), size, etc
        fillBg(surface);

        const y = @divFloor(Dimensions.header.h, 2);
        var x: c_int = header_info.margin;
        for (header_info.activeElements(user.tool)) |elem| {
            const len = header_info.elementWidth(elem);
            const pos = Dot{ .x = x, .y = y };
            switch (elem) {
                // Size slider
                .tool_size => {
                    // Calculate user's size as a percentage of its potential.
                    const sizePercentage = @intToFloat(f16, user.size) / std.math.maxInt(@TypeOf(user.size));
                    // Map that percentage to the upcoming slider.
                    header_info.ToolSize.draw(surface, .{ .x = pos.x, .y = pos.y }, sizePercentage, 3, .horizontal);

                    // Write the user's current tool size next to the size slider.
                    var buffer: [3]u8 = undefined;
                    const userSize = text.intToString(user.size, buffer[0..]) catch unreachable;
                    header_info.ToolSize.drawString(surface, userSize, 2, pos);
                },
                // Active color indicator
                .color => {
                    const end = Dot{ .x = x + len, .y = y + 10 };
                    const start = Dot{ .x = x, .y = y - 10 };
                    surface_draw.rectangleFilled(start, end, 0x444477, surface);
                    surface_draw.rectangle(start, end, 0x333355, 1, surface);
                    surface_draw.circleFilled(.{ .x = pos.x + @divFloor(len, 2), .y = pos.y }, 7, user.color, surface);

                    var buffer: [10]u8 = undefined;
                    var fbs = std.io.fixedBufferStream(&buffer);
                    std.fmt.formatIntValue(user.color, "x", .{}, fbs.writer()) catch @panic("x");
                    var colorString = fbs.getWritten();
                    if (colorString.len == 8) colorString = colorString[2..]; // remove alpha info because we don't use alpha yet
                    text.write(surface, colorString, .{ .x = start.x - 7, .y = end.y + 2 }, 1, widgets.Colors.text, 300);
                },
            }
            x += header_info.elementGap + len;
        }
    }

    fn footer(surface: *Surface) void {
        fillBg(surface);
    }

    /// Draw the left GUI bar, which contains tool icons.
    pub fn left(surface: *Surface, images: Images, activeTool: Tool) void {
        fillBg(surface);

        var paintOffsets = c.SDL_Rect{ .x = 5, .y = toolStartY, .w = 0, .h = 0 };
        for (images.tools) |image, index| {
            if (@enumToInt(activeTool) == index) {
                // Draw box around selected tool.
                // surface_draw.rectangle(.{ .x = 3, .y = paintOffsets.y }, .{ .x = toolWidth + 3, .y = paintOffsets.y + toolHeight }, 0x777777, 2, surface);
                // Indent area around the selected tool.
                surface_draw.rectangleFilled(
                    .{ .x = 3, .y = paintOffsets.y },
                    .{ .x = toolWidth + 5, .y = paintOffsets.y + toolHeight },
                    widgets.Colors.bg_shadow,
                    surface,
                );
            }
            sdl.display.blit(image, null, surface, &paintOffsets);
            paintOffsets.y += toolHeight + toolGap;
        }
    }

    /// Draw the right GUI bar, which contains peer information.
    pub fn right(surface: *Surface, images: Images, peers: *Peers) void {
        fillBg(surface);
        const active = 0x349847;
        const idle = 0x777734;
        const inactive = 0x982734;

        var paintOffsets = c.SDL_Rect{ .x = 5, .y = toolStartY, .w = peerToolWidth, .h = peerToolHeight };
        var iter = peers.iterator();
        const time = std.time.milliTimestamp();
        // Display the peer's tool, as well as their activity status (active, idle, inactive)
        while (iter.next()) |peerPtr| {
            const peer = peerPtr.value_ptr;
            const toolIndex = @enumToInt(peer.tool);
            sdl.display.blitScaled(images.tools[toolIndex], null, surface, &paintOffsets);
            const color: u32 = blk: {
                if (peer.lastActive + 1500 > time) break :blk active;
                if (peer.lastActive + 10000 > time) break :blk idle;
                break :blk inactive;
            };
            // Square displaying activity status of peer.
            sdl.display.fillRect(surface, &c.SDL_Rect{ .x = 3, .y = paintOffsets.y, .w = 3, .h = 3 }, color);
            // Vertical line displaying current color of peer.
            // sdl.display.fillRect(surface, &c.SDL_Rect{ .x = 3, .y = paintOffsets.y, .w = 2, .h = peerToolHeight }, peer.color);
            // Horizontal line displaying current color of peer.
            sdl.display.fillRect(surface, &c.SDL_Rect{ .x = 3, .y = paintOffsets.y + peerToolHeight + peerToolColorGap, .w = peerToolWidth, .h = peerToolColorHeight }, peer.color);
            paintOffsets.y += peerToolHeight + peerToolGap;
        }
    }

    /// Draws all GUI elements
    pub fn all(gui_s: *Surfaces, peers: *Peers, localUser: *const User) void {
        header(gui_s.header, localUser);
        footer(gui_s.footer);
        left(gui_s.left, gui_s.images, localUser.tool);
        right(gui_s.right, gui_s.images, peers);
    }
};

fn fillBg(surface: *Surface) void {
    fillRect(surface, null, elements.Colors.background);
}

/// A collection of surfaces with our GUI images painted on them.
pub const Images = struct {
    const ToolTI = @typeInfo(Tool).Enum;
    const ToolSurfaces = [ToolTI.fields.len]*Surface;

    tools: ToolSurfaces,

    pub fn init() !Images {
        var tools: ToolSurfaces = undefined;

        // This is where we embed the image files for each tool, matching the tool's name to the image's name.
        inline for (ToolTI.fields) |f, img_index| {
            const raw_img = @embedFile("../../../data/images/tools/" ++ f.name ++ ".bmp");
            const image = try sdl.bmp.loadFromMem(raw_img);
            tools[img_index] = image;
        }
        return Images{
            .tools = tools,
        };
    }

    pub fn deinit(self: Images) void {
        for (self.tool) |i| {
            c.SDL_FreeSurface(i);
        }
    }
};
