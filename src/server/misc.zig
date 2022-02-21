const std = @import("std");

/// Removes first occurrence of value.
/// Returns index which was removed.
/// The item at the end of the array will be placed into the returned index.
pub fn remove(array: anytype, value: anytype, options: struct { start: usize = 0 }) !?usize {
    if (options.start >= array.items.len) return error.StartingPastArray;

    for (array.items[options.start..]) |i, n| {
        if (i == value) {
            const real_index = n + options.start;
            _ = array.swapRemove(real_index);
            if (real_index == array.items.len) return null;
            return n;
        }
    }
    return error.ItemNotFound;
}

test "remove" {
    const allocator = std.testing.allocator;
    var array = std.ArrayList(u8).init(allocator);
    defer array.deinit();

    const slice = [_]u8{ 1, 2, 3 };
    try array.appendSlice(slice[0..]);

    const exp_null = try remove(&array, 3, .{});
    try std.testing.expectEqual(exp_null, null);
    try array.append(3);

    const exp_1 = try remove(&array, 2, .{});
    try std.testing.expectEqual(exp_1.?, 1);
    try array.insert(1, 2);
}

test "remove with start value" {
    // For some reason, this test causes a code generation error in the zig compiler.
    // Issue does not persist if other 'remove' tests are skipped.
    // Passes otherwise.
    if (true) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var array = std.ArrayList(u8).init(allocator);
    defer array.deinit();

    const slice = [_]u8{ 3, 1, 2, 3 };
    try array.appendSlice(slice[0..]);

    const exp_null = try remove(&array, 3, .{ .start = 1 });
    try std.testing.expectEqual(exp_null, null);
}

test "remove when multiple values match" {
    // For some reason, this test causes a code generation error in the zig compiler.
    // Issue does not persist if other 'remove' tests are skipped.
    // Otherwise, passes.
    if (true) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var array = std.ArrayList(u8).init(allocator);
    defer array.deinit();

    const slice = [_]u8{ 3, 1, 2, 3 };
    try array.appendSlice(slice[0..]);

    try array.insert(0, 3);
    const exp_0 = try remove(&array, 3, .{});
    try std.testing.expectEqual(exp_0.?, 0);
}
