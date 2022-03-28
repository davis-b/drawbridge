const std = @import("std");
const log = std.log.scoped(.gui);

const Tool = @import("../tools.zig").Tool;
const User = @import("../users.zig").User;
const Peers = @import("../users.zig").Peers;
const surface_draw = @import("../draw.zig");
const c = @import("../c.zig");
const sdl = @import("../sdl/index.zig");
const fillRect = sdl.display.fillRect;
const Surface = sdl.Surface;

const Surfaces = @import("index.zig").Surfaces;
const Dimensions = @import("index.zig").Dimensions;

const bgColor = 0x142238;

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
    fn header(surface: *Surface, a: bool, b: bool) void {
        // This could be a good spot for tool specific options,
        // such as: pencil tip type (square/circle), size, etc
        const bg_color = 0xff0000;
        fillBg(surface);
        if (a) {
            fillRect(surface, &c.SDL_Rect{ .x = 25, .y = 0, .w = 25, .h = 20 }, 0x00ff00);
        }
        if (b) {
            fillRect(surface, &c.SDL_Rect{ .x = 50, .y = 0, .w = 25, .h = 20 }, 0x0000ff);
        }
    }

    fn footer(surface: *Surface) void {
        fillBg(surface);
    }

    /// Draw the left GUI bar, which contains tool icons.
    fn left(surface: *Surface, images: Images, activeTool: Tool) void {
        fillBg(surface);

        var paintOffsets = c.SDL_Rect{ .x = 5, .y = toolStartY, .w = 0, .h = 0 };
        for (images.tools) |image, index| {
            sdl.display.blit(image, null, surface, &paintOffsets);
            if (@enumToInt(activeTool) == index) {
                // draw box around selected tool
                surface_draw.rectangle(.{ .x = 3, .y = paintOffsets.y }, .{ .x = toolWidth + 3, .y = paintOffsets.y + toolHeight }, 0x777777, 2, surface);
            }
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
        header(gui_s.header, true, true);
        footer(gui_s.footer);
        left(gui_s.left, gui_s.images, localUser.tool);
        right(gui_s.right, gui_s.images, peers);
    }
};

fn fillBg(surface: *Surface) void {
    fillRect(surface, null, bgColor);
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
