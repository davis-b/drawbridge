const math = @import("std").math;

const c = @import("c.zig");
const gui = @import("gui/index.zig");
const sdl = @import("sdl/index.zig");
const misc = @import("misc.zig");

/// Collection of data used to represent the area user(s) draw on
pub const Whiteboard = struct {
    // The actual image.
    surface: *sdl.Surface,
    // The sub-area of the whole parent surface that we are allowed to render into, accounts for GUI
    render_area: sdl.Rect,
    // When we can only see a portion of the image, the start of the image gets pushed this much from 0, 0
    crop_offset: misc.Dot,

    pub fn init(parent: *sdl.Surface, gui_surfaces: *gui.Surfaces, width: c_int, height: c_int) !Whiteboard {
        const surface = try sdl.display.initRgbSurface(0, width, height, 32);
        return Whiteboard{
            .surface = surface,
            .render_area = getRenderArea(parent, surface, gui_surfaces),
            .crop_offset = .{ .x = 0, .y = 0 },
        };
    }

    pub fn deinit(self: *Whiteboard) void {
        c.SDL_FreeSurface(self.surface);
    }

    /// Updates attributes that require change on parent resize
    pub fn updateOnParentResize(self: *Whiteboard, parent: *sdl.Surface, gui_s: *gui.Surfaces) void {
        self.render_area = getRenderArea(parent, self.surface, gui_s);
        clampCropOffset(self.surface, self.render_area, &self.crop_offset);
    }

    pub fn modifyCropOffset(self: *Whiteboard, newx: ?c_int, newy: ?c_int) void {
        if (newx) |x| self.crop_offset.x += x;
        if (newy) |y| self.crop_offset.y += y;
        clampCropOffset(self.surface, self.render_area, &self.crop_offset);
    }

    fn isCropped(self: *Whiteboard) bool {
        return internalIsCropped(self.surface, self.render_area);
    }

    pub fn serialize(self: *Whiteboard) []const u8 {
        const pixels = @ptrCast([*]u8, self.surface.pixels);
        return pixels[0..self.imageByteSize(self.surface)];
    }

    pub fn deserialize(self: *Whiteboard, imageData: []const u8) void {
        _ = c.SDL_LockSurface(self.surface);
        defer c.SDL_UnlockSurface(self.surface);
        const pixels = @ptrCast([*]u8, self.surface.pixels);
        for (imageData) |p, n| {
            pixels[n] = p;
        }
    }

    fn imageByteSize(self: *Whiteboard, image: *sdl.Surface) usize {
        const height: usize = @intCast(usize, self.surface.h);
        const pitch: usize = @intCast(usize, self.surface.pitch);
        return height * pitch;
    }
};

/// Returns a rectangle representing the available area that our whiteboard's surface can be blitted to
///  while respecting the gui.
fn getRenderArea(parent_surface: *sdl.Surface, image: *sdl.Surface, gui_surfaces: *gui.Surfaces) sdl.Rect {
    var render_area = sdl.Rect{
        .x = gui_surfaces.left.w,
        .y = gui_surfaces.header.h,
        .w = parent_surface.w - (gui_surfaces.left.w + gui_surfaces.right.w),
        .h = parent_surface.h - (gui_surfaces.footer.h + gui_surfaces.header.h),
    };
    // Places image in middle of available image area. Only necessary if image is not being cropped.
    if (internalIsCropped(image, render_area)) {
        render_area.x = @divFloor((render_area.w - image.w) + gui_surfaces.right.w, 2);
    }
    return render_area;
}

fn internalIsCropped(image: *sdl.Surface, render_area: sdl.Rect) bool {
    return image.w < math.absInt(render_area.w - render_area.x) catch @panic("Whiteboard internal is cropped; Unexpected absInt error\n");
}

fn clampCropOffset(image: *sdl.Surface, render_area: sdl.Rect, offset: *misc.Dot) void {
    misc.clamp(c_int, &offset.x, 0, image.w - render_area.w);
    misc.clamp(c_int, &offset.y, 0, image.h - render_area.h);
}
