// EXP-2 QA-023 — 2×2 smoke test (B1).
//
// Per `docs/infra/dispatch/EXP-2.md` Part B (corrected 2026-07-28):
// B1 (smoke, 2×2) is a cheap gross-error check. 2×2 has no reachable
// non-root cycles, so this is NOT evidence for QA-023 — it catches
// 'implemented PSK by accident' and similar wiring errors. The 3×2
// history-sensitivity probe is EXP-2B (`src/qa023_probe.zig`).
//
// What this prints: the value of five representative states under basic
// ko (formalization (i)) + TIE = 0, computed by the reference function
// in `qa023_brute_2x2.zig`. The expected outputs (per the brief and the
// published MIGOS II anchor) are:
//
//   empty B (B to move, empty goban)        v =  0   (anchor)
//   empty W (W to move, empty goban)        v =  0   (symmetric)
//   full B  (B to move, all 4 cells Black)  v = +4   (area_score)
//   passes=1 (W to move, empty, 1 pass in)  v =  0   (anchor; tie or
//                                                    area, equal at 2×2)
//   passes=2 (B to move, terminal)          v =  0   (area_score)
//
// A build that returns +1 on 'empty B' has implemented PSK by accident
// (`retrograde-3x3.md:224-245`). The smoke test surfaces that case before
// any 3×2 work begins.
//
// Not wired into build.zig; run as:
//   zig run src/qa023_smoke_2x2.zig --dep mod -Mmod=src/qa023_brute_2x2.zig
// (mod is a name for the brute module; both files live in src/).

const B = @import("qa023_brute_2x2.zig");
const std = @import("std");

pub fn main() !void {
    const s_empty_b = B.State{
        .board = .{0, 0, 0, 0},
        .side = 1,
        .ko_point = B.State.KO_NONE,
        .passes = 0,
    };
    const s_empty_w = B.State{
        .board = .{0, 0, 0, 0},
        .side = -1,
        .ko_point = B.State.KO_NONE,
        .passes = 0,
    };
    const s_full_b = B.State{
        .board = .{ 1, 1, 1, 1 },
        .side = 1,
        .ko_point = B.State.KO_NONE,
        .passes = 0,
    };
    const s_pass1 = B.State{
        .board = .{0, 0, 0, 0},
        .side = -1,
        .ko_point = B.State.KO_NONE,
        .passes = 1,
    };
    const s_terminal = B.State{
        .board = .{0, 0, 0, 0},
        .side = 1,
        .ko_point = B.State.KO_NONE,
        .passes = 2,
    };
    std.debug.print("empty B:  v = {d}\n", .{B.value(s_empty_b)});
    std.debug.print("empty W:  v = {d}\n", .{B.value(s_empty_w)});
    std.debug.print("full B:   v = {d}\n", .{B.value(s_full_b)});
    std.debug.print("passes=1: v = {d}\n", .{B.value(s_pass1)});
    std.debug.print("passes=2: v = {d}\n", .{B.value(s_terminal)});
}
