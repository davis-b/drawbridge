const packet = @import("packet.zig");

// A compilation of events that are not directly drawing related.

pub const Event = union(enum) {
    net_exit: void,
    peer_entry: u8,
    peer_exit: u8,
    state_query: void,
    state_set: packet.WorldState,
    err: MetaError,
};

pub const MetaError = enum {
    unknown,
};
