// CENSUS TOOL.  CAVEAT (2026-07-15): this counts terminal.is_settled, which is
// currently UNSOUND — it reports scoring-settled positions, not game-theoretically
// decided ones (see docs/research/terminal-territory-bug.md). Re-run after
// is_settled is fixed to get the true minimal-DECIDED terminal + honest %.
//
// Census: over every single-colour (all-black) occupancy of the 5x5 board
// (all 2^25 blinds), how many are Benson-settled, broken down by stone count?
// This is the natural home of *minimal* terminals (one player owning the whole
// board); mixed-colour terminals need two living groups and thus more stones.
const std = @import("std");
const p = std.debug.print;
const terminal = @import("terminal.zig");

pub fn main() void {
    var total = [_]u64{0} ** 26; // C(25,k)
    var settled = [_]u64{0} ** 26;
    var minK: u32 = 99;
    var min_example: u32 = 0;

    var blind: u64 = 0;
    while (blind < (1 << 25)) : (blind += 1) {
        const k = @popCount(blind);
        total[k] += 1;
        var board = [_]i8{0} ** 25;
        var b = blind;
        var cell: usize = 0;
        while (cell < 25) : (cell += 1) {
            if (b & 1 == 1) board[cell] = 1;
            b >>= 1;
        }
        if (terminal.is_settled(&board)) {
            settled[k] += 1;
            if (k < minK) {
                minK = k;
                min_example = @intCast(blind);
            }
        }
    }

    p("minimal single-colour settled stone count: {d}\n\n", .{minK});
    p("smallest example (X = black):\n", .{});
    var b = min_example;
    for (0..5) |r| {
        for (0..5) |c| {
            _ = c;
            p(" {s}", .{if (b & 1 == 1) "X" else "."});
            b >>= 1;
        }
        p("\n", .{});
        _ = r;
    }

    p("\n k        C(25,k)        settled     %settled\n", .{});
    for (0..26) |k| {
        const pct = if (total[k] == 0) 0.0 else 100.0 *
            @as(f64, @floatFromInt(settled[k])) / @as(f64, @floatFromInt(total[k]));
        p("{d:>2} {d:>14} {d:>14} {d:>10.5}\n", .{ k, total[k], settled[k], pct });
    }
}
