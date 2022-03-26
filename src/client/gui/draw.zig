const std = @import("std");
const log = std.log.scoped(.gui);

const Tool = @import("../tools.zig").Tool;
const Peers = @import("../users.zig").Peers;
const c = @import("../c.zig");
const sdl = @import("../sdl/index.zig");
const fillRect = sdl.display.fillRect;

const Surface = @import("index.zig").Surface;
const Surfaces = @import("index.zig").Surfaces;
const Dimensions = @import("index.zig").Dimensions;

const bgColor = 0x142238;

pub const toolHeight = 30;
const toolWidth = 30;
pub const toolGap = 5;
pub const toolStartY = 30;

const peerToolHeight = 20;
const peerToolWidth = 20;
const peerToolGap = 3;

pub const Draw = struct {
    fn header(surface: *Surface, a: bool, b: bool) void {
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
    fn left(surface: *Surface, images: Images) void {
        fillBg(surface);

        var paintOffsets = c.SDL_Rect{ .x = 5, .y = toolStartY, .w = 0, .h = 0 };
        for (images.tools) |image| {
            sdl.display.blit(image, null, surface, &paintOffsets);
            paintOffsets.y += toolHeight + toolGap;
        }
    }

    /// Draw the right GUI bar, which contains peer information.
    pub fn right(surface: *Surface, images: Images, peers: *Peers) void {
        fillBg(surface);

        var paintOffsets = c.SDL_Rect{ .x = 5, .y = toolStartY, .w = peerToolWidth, .h = peerToolHeight };
        var iter = peers.iterator();
        while (iter.next()) |peer| {
            const toolIndex = @enumToInt(peer.value_ptr.tool);
            sdl.display.blitScaled(images.tools[toolIndex], null, surface, &paintOffsets);
            paintOffsets.y += peerToolHeight + peerToolGap;
        }
    }

    /// Draws all GUI elements
    pub fn all(gui_s: *Surfaces, peers: *Peers) void {
        header(gui_s.header, true, true);
        footer(gui_s.footer);
        left(gui_s.left, gui_s.images);
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
