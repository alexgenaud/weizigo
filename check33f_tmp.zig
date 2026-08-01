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
    const X = colex.Indexer(3, 3);

    // TRUE position (B@cell1, W to move): exp6 base-3 rank 3.
    const true_row = artifact2.lookup(&a, 3, -1, none, 0).?;
    std.debug.print("TRUE (B@cell1, W, p0) [artifact key 3]: L={d} H={d}\n", .{ true_row.L, true_row.H });

    // What the ENGINE reads for the same position: engine colex 4.
    const eng_row = artifact2.lookup(&a, 4, -1, none, 0).?;
    std.debug.print("ENGINE reads (colex 4, W, p0): L={d} H={d}\n", .{ eng_row.L, eng_row.H });

    // What position is the engine's key 4 in the artifact's (exp6) address space?
    // exp6 base-3 of 4 = digits 1,1 -> B at cells 0 and 1.
    var v: u32 = 4;
    var cells: [9]u8 = [_]u8{0} ** 9;
    var i: usize = 0;
    while (v > 0) : (i += 1) { cells[i] = @intCast(v % 3); v /= 3; }
    std.debug.print("artifact group 4 = exp6 board [", .{});
    for (cells) |c| std.debug.print("{d}", .{c});
    std.debug.print("]  (engine decodes colex 4 as B@cell1)\n", .{});

    // The engine's colex for B@cell1:
    var pos: [9]i8 = [_]i8{0} ** 9;
    pos[1] = 1;
    std.debug.print("engine colex(B@cell1) = {d}\n", .{X.colex_from_pos(&pos)});
}
