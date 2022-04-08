// These are the actions that will be shared with peers.
// The original SDL events are discarded and these are processed instead.
// Remote actions and local actions of this type should be processed in the same fashion.

const Dot = @import("client").Dot;
const Tool = @import("client").Tool;

pub const Action = union(enum) {
    tool_change: Tool,
    tool_resize: u8,
    // All cursor action coordinates are relative to the room's shared Whiteboard image.
    cursor_move: Move,
    mouse_press: Click,
    mouse_release: Click,
    color_change: u32,
    layer_switch: u8,
};

const Click = struct { button: u8, pos: Dot };
const Move = struct { pos: Dot, delta: Dot };
