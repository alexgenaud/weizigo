const std = @import("std");
const retro = @import("retro");
const rules = @import("rules");
const colex = @import("colex");

// Exact PSK solver for a single 3x2 history.
// Input (stdin): one line per query:
//   side passes idx0 idx1 idx2 ... idxN
// side: 1 = Black to move at the final position, -1 = White.
// passes: consecutive passes already made (0 for a fresh move arrival).
// The final board index is the LAST index in the list.
// Output (stdout): one line per query: value (Black-positive).

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    const R = rules.Rules(3, 2);
    const X = colex.Indexer(3, 2);
    _ = R;
    const E = retro.Exact(3, 2);

    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();
    var ctx = E.Ctx{ .map = E.Map.init(gpa), .entry_cap = 0, .budget = 0 };
    defer ctx.map.deinit();

    var line_buf: [4096]u8 = undefined;
    while (try stdin.readUntilDelimiterOrEof(&line_buf, '\n')) |line| {
        var it = std.mem.tokenizeAny(u8, line, " \t");
        const side = std.fmt.parseInt(i8, it.next() orelse continue, 10) catch continue;
        const passes = std.fmt.parseInt(u8, it.next() orelse continue, 10) catch continue;

        var bans = E.Bans.initEmpty();
        var last_idx: u32 = 0;
        while (it.next()) |tok| {
            const idx = std.fmt.parseInt(u32, tok, 10) catch continue;
            bans.set(idx);
            last_idx = idx;
        }

        const pos = X.pos_from_colex(last_idx);
        ctx.nodes = 0;
        const win = E.win_empty;
        const v = try E.solve(&ctx, &pos, side, passes, win, bans);
        try stdout.print("{d}\n", .{v});
    }
}
