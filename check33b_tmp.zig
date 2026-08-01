const std = @import("std");
const exp6 = @import("src/exp6_solve.zig");
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
    const none: u8 = @intCast(exp6.KO_NONE);

    const X = colex.Indexer(3, 3);
    // Position: B at A3 (cell 6). White to move.
    var pos: [9]i8 = [_]i8{0} ** 9;
    pos[6] = 1;
    const eng_key = X.colex_from_pos(&pos);
    const exp6_key: u32 = @intCast(exp6.rank_board(pos));
    std.debug.print("position B@A3: engine colex={d}  exp6 base3 rank={d}\n", .{ eng_key, exp6_key });
    std.debug.print("  what the ENGINE reads  (colex {d}): ", .{eng_key});
    if (artifact2.lookup(&a, @intCast(eng_key), -1, none, 0)) |r| {
        std.debug.print("L={d} H={d}\n", .{ r.L, r.H });
    } else std.debug.print("MISSING\n", .{});
    std.debug.print("  true position's entry (colex {d}): ", .{exp6_key});
    if (artifact2.lookup(&a, exp6_key, -1, none, 0)) |r| {
        std.debug.print("L={d} H={d}\n", .{ r.L, r.H });
    } else std.debug.print("MISSING\n", .{});

    // What IS the board stored under the engine's key?
    const dec = X.pos_from_colex(eng_key);
    std.debug.print("  board stored under engine key {d}: [", .{eng_key});
    for (dec) |c| std.debug.print("{d}", .{c});
    std.debug.print("]\n", .{});
}
