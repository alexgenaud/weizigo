// T358 — clean 2×2 Markov-key reachability census.
// Additive instrument (no engine edits; not wired into build.zig). Seeds ONLY
// the two real roots (empty, B, KO_NONE, passes=0) and (empty, W, KO_NONE,
// passes=0) — unlike qa023_brute_2x2's main, which over-seeds ko=cell-on-empty
// "for completeness". BFS the legal-move graph via Brute2x2.State.apply_place
// / apply_pass, count reachable (board, side, ko, passes) states, split by
// passes∈{0,1} (the WZO2-stored slice) vs passes=2 (terminal). Comparable to
// exp6's run_census_3x2 / run_census_3x3 seeding (roots: empty, ko=none,
// passes∈{0,1}).
//
// Build: tools/runner -- zig run -O ReleaseFast src/t358_census_2x2.zig

const std = @import("std");
const util = @import("util.zig");
const B = @import("qa023_brute_2x2.zig");

// 2×2 goban: 4 cells. (qa023_brute_2x2.zig keeps `n` private; this instrument
// is 2×2-specific so the constant is local.)
const N: usize = 4;

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    var visited = try std.DynamicBitSetUnmanaged.initEmpty(gpa, B.TOTAL_STATES);
    defer visited.deinit(gpa);

    const empty = [_]i8{0} ** N;
    const roots = [_]B.State{
        .{ .board = empty, .side = 1, .ko_point = B.State.KO_NONE, .passes = 0 },
        .{ .board = empty, .side = -1, .ko_point = B.State.KO_NONE, .passes = 0 },
    };

    // iterative BFS (explicit stack — the graph is tiny, 2430 states)
    var stack: [B.TOTAL_STATES]B.State = undefined;
    var stack_len: usize = 0;
    for (roots) |r| {
        const idx = B.global_index(r);
        if (!visited.isSet(idx)) {
            visited.set(idx);
            stack[stack_len] = r;
            stack_len += 1;
        }
    }
    while (stack_len > 0) {
        stack_len -= 1;
        const s = stack[stack_len];
        if (B.State.apply_pass(s)) |ns| {
            const idx = B.global_index(ns);
            if (!visited.isSet(idx)) { visited.set(idx); stack[stack_len] = ns; stack_len += 1; }
        }
        for (0..N) |cell_u| {
            if (B.State.apply_place(s, @intCast(cell_u))) |ns| {
                const idx = B.global_index(ns);
                if (!visited.isSet(idx)) { visited.set(idx); stack[stack_len] = ns; stack_len += 1; }
            }
        }
    }

    var total: u64 = 0;
    var p01: u64 = 0; // passes ∈ {0,1}  (WZO2-stored slice)
    var p2: u64 = 0;  // passes == 2     (terminal, omitted from WZO2)
    var by_side: [2]u64 = .{ 0, 0 };
    var it = visited.iterator(.{});
    while (it.next()) |idx| {
        total += 1;
        const s = B.state_from_index(idx);
        if (s.passes == 2) p2 += 1 else p01 += 1;
        // side: +1 Black -> 0, -1 White -> 1 (matches exp6 side convention)
        const si: usize = if (s.side > 0) 0 else 1;
        by_side[si] += 1;
    }

    util.out("# t358 2x2 clean reachability census (roots: empty B/W, ko=none, passes=0)\n", .{});
    util.out("# state space TOTAL_STATES = {d} (3^4 * 2 * 5 * 3)\n", .{B.TOTAL_STATES});
    util.out("# goban cells N = {d}\n", .{N});
    util.out("# total reachable (all passes) = {d}\n", .{total});
    util.out("#   passes in {{0,1}} (WZO2-stored) = {d}\n", .{p01});
    util.out("#   passes == 2 (terminal)        = {d}\n", .{p2});
    util.out("# by side: B={d} W={d}\n", .{ by_side[0], by_side[1] });
}