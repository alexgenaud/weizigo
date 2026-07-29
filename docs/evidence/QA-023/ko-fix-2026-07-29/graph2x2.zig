// 2B-FIX-KO cross-check: BFS the 2x2 legal-move graph
// through the real `Brute2x2.State.apply_place` / `apply_pass`, and report
// V, E and the ko-setting edge count. Compared against the independent
// Python transcription in scc2x2.py. Does NOT call `value`/`brute_value`
// (trilemma horn 1 — the 10h22m hazard), only the rules functions.
//
// Zig refuses imports outside the module path, so run it from a scratch dir:
//
//   cp docs/evidence/QA-023/ko-fix-2026-07-29/graph2x2.zig /tmp/x/
//   cp -R src /tmp/x/srccopy
//   tools/runner -- zig build-exe /tmp/x/graph2x2.zig -femit-bin=/tmp/x/graph2x2
//   /tmp/x/graph2x2
//
// Expected with the corrected rule: true root V=255 E=434 ko-edges=0;
// all-seed V=282 E=508 ko-edges=0. With the pre-fix rule (git show
// 45ed0f3:src/qa023_brute_2x2.zig): 263/442/32 and 290/516/32.
const std = @import("std");
const B = @import("srccopy/qa023_brute_2x2.zig");
const State = B.State;

const N: usize = 4;

fn rank(board: [N]i8) usize {
    var r: usize = 0;
    var i: usize = N;
    while (i > 0) {
        i -= 1;
        const d: usize = switch (board[i]) {
            0 => 0,
            1 => 1,
            else => 2,
        };
        r = r * 3 + d;
    }
    return r;
}

fn unrank(r0: usize) [N]i8 {
    var b: [N]i8 = .{ 0, 0, 0, 0 };
    var r = r0;
    for (0..N) |i| {
        b[i] = switch (r % 3) {
            0 => 0,
            1 => 1,
            else => -1,
        };
        r /= 3;
    }
    return b;
}

// linear index: board(81) x side(2) x ko(5) x passes(3) = 2430
fn lin(s: State) usize {
    const side: usize = if (s.side == 1) 0 else 1;
    const ko: usize = if (s.ko_point == State.KO_NONE) N else s.ko_point;
    return ((rank(s.board) * 2 + side) * (N + 1) + ko) * 3 + s.passes;
}

fn delin(l: usize) State {
    const passes = l % 3;
    const ko = (l / 3) % (N + 1);
    const side = (l / 3 / (N + 1)) % 2;
    const board = (l / 3 / (N + 1)) / 2;
    return State{
        .board = unrank(board),
        .side = if (side == 0) 1 else -1,
        .ko_point = if (ko == N) State.KO_NONE else @intCast(ko),
        .passes = @intCast(passes),
    };
}

fn run(mode: bool) void {
    const TOTAL: usize = 2430;
    var seen = [_]bool{false} ** TOTAL;
    var queue: [TOTAL]usize = undefined;
    var head: usize = 0;
    var tail: usize = 0;

    if (mode) {
        // empty board x side x ko x passes — the 3x2 seed_roots convention
        for ([_]i8{ 1, -1 }) |side| {
            for (0..3) |p| {
                for (0..N + 1) |k| {
                    const s = State{
                        .board = .{ 0, 0, 0, 0 },
                        .side = side,
                        .ko_point = if (k == N) State.KO_NONE else @intCast(k),
                        .passes = @intCast(p),
                    };
                    const l = lin(s);
                    if (!seen[l]) {
                        seen[l] = true;
                        queue[tail] = l;
                        tail += 1;
                    }
                }
            }
        }
    } else {
        const s = State{ .board = .{ 0, 0, 0, 0 }, .side = 1, .ko_point = State.KO_NONE, .passes = 0 };
        seen[lin(s)] = true;
        queue[tail] = lin(s);
        tail += 1;
    }

    var edges: usize = 0;
    var ko_edges: usize = 0;
    while (head < tail) {
        const l = queue[head];
        head += 1;
        const s = delin(l);
        if (s.passes == 2) continue;
        if (State.apply_pass(s)) |ns| {
            edges += 1;
            const nl = lin(ns);
            if (!seen[nl]) {
                seen[nl] = true;
                queue[tail] = nl;
                tail += 1;
            }
        }
        for (0..N) |cell| {
            if (State.apply_place(s, @intCast(cell))) |ns| {
                edges += 1;
                if (ns.ko_point != State.KO_NONE) ko_edges += 1;
                const nl = lin(ns);
                if (!seen[nl]) {
                    seen[nl] = true;
                    queue[tail] = nl;
                    tail += 1;
                }
            }
        }
    }
    std.debug.print("2x2 via Brute2x2 rules ({s}): V = {d}, E = {d}, ko-setting edges = {d}\n", .{ if (mode) "all-seed" else "true root", tail, edges, ko_edges });
}

pub fn main(init: std.process.Init) !void {
    _ = init;
    run(false);
    run(true);
}
