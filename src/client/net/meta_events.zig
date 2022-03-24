const WorldState = @import("world_state.zig").WorldState;

// A compilation of events that are not directly drawing related.

pub const Event = union(enum) {
    net_exit: void,
    peer_entry: u8,
    peer_exit: u8,
    state_query: u8, // our id, so we can return a user list that the new peer can properly use.
    state_set: WorldState,
    err: MetaError,
};

pub const MetaError = enum {
    unknown,
};
