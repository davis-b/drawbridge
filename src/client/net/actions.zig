// These are the actions that will be shared with peers.
// The original SDL events are discarded and these are processed instead.
// Remote actions and local actions of this type should be processed in the same fashion.

const Dot = @import("client").Dot;
const Tool = @import("client").Tool;

pub const Action = union(enum) {
    tool_change: Tool,
    tool_resize: u8,
    /// All cursor action coordinates are confined to and conforming within the active shared Whiteboard image.
    // Hence, someone cropped so that the top of their screen is the bottom half of the image, they will send the proper coordinates to their peers.
    cursor_move: Move,
    mouse_press: Click,
    mouse_release: Click,
    color_change: u32,
    layer_switch: u8,
};

const Click = struct { button: u8, pos: Dot };
const Move = struct { pos: Dot, delta: Dot };
