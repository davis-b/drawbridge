// TODO
// Perhaps we should include POLLRDHUP, POLLERR
// and pass the errors along to the caller.

const std = @import("std");
const log = std.log.default;

const PollFds = std.ArrayList(std.os.pollfd);

const Poller = @This();
open_fds: usize = 0,
index: usize = 0,
pfds: PollFds,

pub fn init(allocator: *std.mem.Allocator) Poller {
    return Poller{ .pfds = PollFds.init(allocator) };
}

pub fn deinit(self: *Poller) void {
    self.pfds.deinit();
}

/// Blocks until a FD that we are polling has data to read.
/// Returns that file descriptor.
/// If there are multiple open descriptors,
///  return them in sequence before polling for new ones.
pub fn readable(self: *Poller) !std.os.fd_t {
    // No reason to poll if we already have data to read, right?
    // We could of course poll anyway and get more fd's, but that could result
    // In us reading early fd's repeatedly and not being able to get to later fd's.
    if (self.open_fds == 0) {
        self.index = 0;
        self.open_fds = try std.os.poll(self.pfds.items[0..], -1);

        // log.info("open fds: {}\n", .{self.open_fds});
        if (self.open_fds == 0) {
            @panic("poll timeout");
        }
    }

    for (self.pfds.items[self.index..]) |pfd| {
        self.index += 1;
        const can_read = (pfd.revents & std.os.POLLIN) != 0;
        if (can_read) {
            self.open_fds -= 1;
            return pfd.fd;
        }
    }
    // If this occurs, it could be caused by some revents happening regardless of our events flags?
    // In which case, we would reduce the number of 'open_fds' by 1 whenever 'revents' is not 0.
    return error.UnexpectedPollError;
}

pub fn add(self: *Poller, fd: std.os.fd_t) !void {
    // Reset this to 0 so that we don't have an error from resuming
    //  Poller.readFds after changing the list it is working on.
    self.open_fds = 0;
    try self.pfds.append(make_pfd(fd));
}

pub fn remove(self: *Poller, fd: std.os.fd_t) !void {
    // Reset this to 0 so that we don't have an error from resuming
    //  Poller.readFds after changing the list it is working on.
    self.open_fds = 0;
    for (self.pfds.items) |i, index| {
        if (i.fd == fd) {
            _ = self.pfds.swapRemove(index);
            return;
        }
    }
    return error.FdNotFound;
}

fn make_pfd(fd: std.os.fd_t) std.os.pollfd {
    return std.os.pollfd{
        .fd = fd,
        .events = std.os.POLLIN,
        .revents = undefined,
    };
}
