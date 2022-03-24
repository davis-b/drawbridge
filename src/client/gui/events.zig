const log = @import("std").log.scoped(.gui);

const sdl = @import("../sdl/index.zig");

const Surfaces = @import("index.zig").Surfaces;
const Dimensions = @import("index.zig").Dimensions;

pub fn handleButtonPress(parent: *sdl.Surface, s: *Surfaces, x: c_int, y: c_int) void {
    // header
    if (y <= s.header.h) {
        handleHeaderPress(parent, s.header, x, y);
        log.debug("header {}x{}", .{ x, y });
    }
    // footer
    else if (y >= parent.h - s.footer.h) {
        const new_y = y - (parent.h - s.footer.h);
        log.debug("footer {}x{}", .{ x, new_y });
    }
    // left sidebar
    else if (x <= s.left.w) {
        log.debug("left", .{});
    }
    // right sidebar
    else if (x >= parent.w - s.right.w) {
        const new_x = x - (parent.w - s.right.w);
        log.debug("right {}x{}", .{ new_x, y });
    }
}

fn handleHeaderPress(parent: *sdl.Surface, header: *sdl.Surface, x: c_int, y: c_int) void {
    // TODO
    // Seems like we may need to pass around structs with more state than sdl.Surface provides.
    // handleButtonPress may also need *state.World so that we may enact meaningful change.
    //  Alternatively, we could return a requested outcome, such as changeColor, newImage.
    //   Although, both of those require extra data, such as a color or a new image size.
    //   Unless we handle the gathering of that data at the call site, rather than within the gui code.
}
