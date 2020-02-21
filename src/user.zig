// Contains all necessary state.
pub const User = struct {
    size: u8,
    color: u32,
    //tool: tools.Tools,
    lastX: c_int = 0,
    lastY: c_int = 0,
};
