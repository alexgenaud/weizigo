const std = @import("std");
const artifact2 = @import("src/artifact2.zig");
const gpa = std.heap.page_allocator;

pub fn main() !void {
    var threaded = std.Io.Threaded.init(gpa, .{});
    defer threaded.deinit();
    const io = threaded.io();
    const dir = std.Io.Dir.cwd();
    var a = try artifact2.load(io, dir, "untracked/oracle-v2/oracle-3x3-v2.wzo2", gpa);
    defer a.deinit();
    const none: u8 = 9;

    // TRUE W-to-move values of the one-stone positions, keyed by exp6 rank
    const cells = [_]struct { cell: u32, exp6: u32 }{
        .{ .cell = 0, .exp6 = 1 },
        .{ .cell = 1, .exp6 = 3 },
        .{ .cell = 2, .exp6 = 9 },
        .{ .cell = 3, .exp6 = 27 },
        .{ .cell = 4, .exp6 = 81 },
        .{ .cell = 5, .exp6 = 243 },
        .{ .cell = 6, .exp6 = 729 },
        .{ .cell = 7, .exp6 = 2187 },
        .{ .cell = 8, .exp6 = 6561 },
    };
    std.debug.print("TRUE (B@cell, W, p0) values:\n", .{});
    for (cells) |c| {
        const row = artifact2.lookup(&a, c.exp6, -1, none, 0);
        if (row) |r| {
            std.debug.print("  B@cell{d}: L={d} H={d}\n", .{ c.cell, r.L, r.H });
        } else std.debug.print("  B@cell{d}: MISSING\n", .{c.cell});
    }
    std.debug.print("\nWhat the engine read (combinatorial colex keys):\n", .{});
    std.debug.print("  cell0->key2: fallback(9,9) | cell1->key4: (3,9) | cell2->key6: fallback(9,9)\n", .{});
    std.debug.print("  cell3->key8: fallback(9,9) | cell4->key10: (-9,-9) | cell5->key12: (3,9)\n", .{});
    std.debug.print("  cell6->key14: (-1,9) | cell7->key16: (-9,-9) | cell8->key18: fallback(9,9)\n", .{});
}
