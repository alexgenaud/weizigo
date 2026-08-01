const std = @import("std");
const artifact2 = @import("src/artifact2.zig");
const colex = @import("src/colex.zig");
const rules = @import("src/rules.zig");
const gpa = std.heap.page_allocator;

const R = rules.Rules(3, 3);
const X = colex.Indexer(3, 3);
const Pos = R.Pos;

fn pinned(L: i8, H: i8) i8 { return @max(L, @min(0, H)); }

pub fn main() !void {
    var threaded = std.Io.Threaded.init(gpa, .{});
    defer threaded.deinit();
    const io = threaded.io();
    const dir = std.Io.Dir.cwd();
    var a = try artifact2.load(io, dir, "untracked/oracle-v2/oracle-3x3-v2.wzo2", gpa);
    defer a.deinit();
    const none: u8 = R.n; // 9

    // Empty board, Black to move: evaluate every placement like chooseV2.
    var pos: Pos = [_]i8{0} ** 9;
    std.debug.print("empty board colex = {d}\n", .{X.colex_from_pos(&pos)});
    for (0..9) |p| {
        const child = R.pos_from_move(&pos, 1, p) catch continue;
        // koAfterCapture for a no-capture move = none
        const row = artifact2.lookup(&a, @intCast(X.colex_from_pos(&child)), -1, none, 0) orelse {
            std.debug.print("  cell {d}: MISSING (colex {d})\n", .{ p, X.colex_from_pos(&child) });
            continue;
        };
        std.debug.print("  B cell {d}: engine-colex={d} row L={d} H={d} pinned={d}\n", .{
            p, X.colex_from_pos(&child), row.L, row.H, pinned(row.L, row.H),
        });
    }
}
