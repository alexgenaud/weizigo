const std = @import("std");
const artifact2 = @import("src/artifact2.zig");
const colex = @import("src/colex.zig");
const gpa = std.heap.page_allocator;

pub fn main() !void {
    var threaded = std.Io.Threaded.init(gpa, .{});
    defer threaded.deinit();
    const io = threaded.io();
    const dir = std.Io.Dir.cwd();
    var a = try artifact2.load(io, dir, "untracked/oracle-v2/oracle-3x3-v2.wzo2", gpa);
    defer a.deinit();
    const none: u8 = 9;

    // Direct lookups at engine colex keys 2,4,6 (children of empty-B)
    for ([_]u32{ 2, 4, 6, 8, 10, 12, 14, 16, 18 }) |k| {
        const row = artifact2.lookup(&a, k, -1, none, 0);
        if (row) |r| {
            std.debug.print("colex {d} W p0: L={d} H={d}\n", .{ k, r.L, r.H });
        } else {
            std.debug.print("colex {d} W p0: MISSING\n", .{k});
        }
    }
    // Also: what does the engine's colex_from_pos say for B@cell0?
    const X = colex.Indexer(3, 3);
    var pos: [9]i8 = [_]i8{0} ** 9;
    pos[0] = 1;
    std.debug.print("engine colex(B@cell0) = {d}\n", .{X.colex_from_pos(&pos)});
}
