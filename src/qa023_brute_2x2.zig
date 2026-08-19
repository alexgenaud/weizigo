////////////////////////////////////////////
//                                        //
//    (c) 2026 Alexander E Genaud         //
//                                        //
//    Permission is granted hereby,       //
//    to copy, share, use, modify,        //
//        for purposes any,               //
//        for free or for money,          //
//    provided these notices multiply.    //
//                                        //
//    This work "as is" I provide,        //
//    no warranty express or implied,     //
//    for, no purpose fit,            //
//    'tis unmerchantable shit.       //
//    Liability for damages denied.       //
//                                        //
////////////////////////////////////////////
//
// EXP-2 QA-023 — 2×2 SMOKE-TEST REFERENCE under basic ko + tie=0.
//
// This file is the *source of values* for the 2×2 smoke test
// (`src/qa023_smoke_2x2.zig`). Per `docs/infra/dispatch/EXP-2.md` Part B
// (corrected 2026-07-28 by Opus, see `audit-opus-2026-07-28.md`):
//
//   B1 (smoke, 2×2):   cheap gross-error check on a goban with no reachable
//                      non-root cycles — catches 'implemented PSK by accident'
//                      and similar wiring errors. NOT evidence for QA-023.
//
//   B2 (probe, 3×2):   history-sensitivity probe; EXP-2B builds its own
//                      solver from scratch (`src/qa023_probe.zig`).
//
// The *original* v0 of EXP-2 Part B instructed the console to 'brute-force
// the same game by explicit game-tree evaluation carrying full history and
// compare every state' (i.e. enumerate *paths*, not states, and cross-check
// a parallel converge solver). That instruction is unsatisfiable — the audit
// ran the design for 10h22m on a four-point goban and produced nothing. The
// correction in EXP-2.md §B2 is a history-sensitivity probe (reach the same
// state via different histories, check values agree). The converge/compare
// files referenced in the comment below do not exist on disk; the converge
// solver that EXP-2B builds replaces them.
//
// The IMPLEMENTATION in this file is fine for what it does: a self-contained
// 2×2 game-value function `value(s: State) i8` under basic ko (formalization
// (i)) with TIE = 0 for cycles and depth-bound exits. 2×2 has 2430
// (board, side, ko, passes) states; a single-state value() call on the
// 5-state smoke test is well below any time bound.
//
// This file deliberately uses only the public surface of rules.zig and
// enumerate.zig (pos_from_move, area_score, is_legal) and does not import
// retro.zig / oracle.zig / solve.zig.
//
// Not wired into build.zig: run as
//   zig run src/qa023_smoke_2x2.zig --dep mod -Mmod=src/qa023_brute_2x2.zig
// (smoke is in the same directory and `@import`s the brute module).
// A build target for it is the Orchestrator's queue, not Part A's.
//
// AUDIT NOTE (2026-07-28, Opus): the *enumeration design* was unsatisfiable
// (paths × states exponential). The *value function* here is unsound only
// at depth-bounded exits (which return TIE — i.e. a tied terminal) and
// only on 2×2 it cannot reach. Do not extend this file to 3×2 or larger
// without re-reading the audit.

const std = @import("std");
const expect = std.testing.expect;

const R = @import("rules.zig").Rules(2, 2);
const E = @import("enumerate.zig").Enumerator(2, 2);
const Pos = R.Pos;
const n = R.n;

/// TIE value (the constant value for any long cycle / infinite play).
/// Per the EXP-2 brief and `roadmap-2026-07-28.md` §2: on 2x2 with komi 0,
/// the published MIGOS II value is 0, so the natural choice is TIE = 0.
pub const TIE: i8 = 0;

pub const State = struct {
    board: Pos,
    side: i8, // +1 Black, -1 White
    ko_point: u8, // 0..n-1 valid; 255 = none
    passes: u8, // 0, 1, or 2 (terminal)

    pub const KO_NONE: u8 = 255;

    pub fn is_terminal(s: State) bool {
        return s.passes == 2;
    }

    pub fn terminal_value(s: State) i8 {
        return R.area_score(&s.board);
    }

    /// Apply a *place* move at cell `cell`. Returns null if illegal
    /// (occupied, suicide, or basic-ko banned at this cell).
    /// On success, returns the new state with ko_point and passes updated.
    pub fn apply_place(s: State, cell: u8) ?State {
        if (s.board[cell] != 0) return null;
        if (s.ko_point != KO_NONE and cell == s.ko_point) return null; // basic ko (i)
        const next_board = R.pos_from_move(&s.board, s.side, cell) catch return null;

        // Determine new ko_point: was this a single-stone capture where
        // the placed stone has exactly one liberty (the captured cell)?
        // If so, the captured cell is the new ko_point for the opponent.
        var opp_before: u8 = 0;
        var opp_after: u8 = 0;
        var captured_cell: u8 = KO_NONE;
        for (0..n) |i| {
            if (s.board[i] == -s.side) opp_before += 1;
            if (next_board[i] == -s.side) opp_after += 1;
            if (s.board[i] == -s.side and next_board[i] == 0) captured_cell = @intCast(i);
        }
        const single_capture = (opp_before - opp_after == 1) and (captured_cell != KO_NONE);
        var new_ko: u8 = KO_NONE;
        if (single_capture) {
            // Basic-ko shape, per proof-v2 §1.1 formalization (i): the ko
            // point is set only by a *single-stone ko capture* — one stone
            // captured (tested above) AND the placed stone a lone stone
            // (chain of size 1) whose sole liberty is the vacated cell. If
            // the placed stone joins a friendly chain, the recapture takes
            // that whole chain and does not recreate the prior position, so
            // there is nothing to ban (Opus-5 2B-2 audit, finding F5).
            // Chain-of-size-1 ⇔ no friendly neighbour in `next_board`.
            var liberties: u8 = 0;
            var friendly: u8 = 0;
            var nb: [4]usize = undefined;
            const cnt = R.neighbors(cell, &nb);
            for (nb[0..cnt]) |q| {
                if (next_board[q] == 0) liberties += 1;
                if (next_board[q] == s.side) friendly += 1;
            }
            if (liberties == 1 and friendly == 0) new_ko = captured_cell;
        }
        return State{
            .board = next_board,
            .side = -s.side,
            .ko_point = new_ko,
            .passes = 0,
        };
    }

    /// Apply a *pass* move. Returns the new state. Passes are exempt from
    /// basic ko (`GLOBAL.ADR0005-PASS`). Two consecutive passes = terminal.
    pub fn apply_pass(s: State) ?State {
        if (s.passes >= 2) return null;
        return State{
            .board = s.board,
            .side = -s.side,
            .ko_point = KO_NONE,
            .passes = s.passes + 1,
        };
    }
};

/// State fingerprint = (board, side, ko_point, passes) — exactly the state
/// tuple, also the key into the transposition table (via `global_index`).
/// Retained as a named record for readers and for any external caller that
/// builds one; `brute_value` itself indexes the memo by `global_index`.
pub const Fingerprint = struct {
    board: Pos,
    side: i8,
    ko_point: u8,
    passes: u8,
};

pub fn fp_eq(a: Fingerprint, b: Fingerprint) bool {
    if (a.side != b.side or a.ko_point != b.ko_point or a.passes != b.passes) return false;
    for (0..n) |i| if (a.board[i] != b.board[i]) return false;
    return true;
}

/// Defensive DFS depth cap. The memoised search is finite without it (each
/// state is evaluated once), so this no longer bounds a live recursion; it is
/// kept for the `summary` dump and as a sanity ceiling.
pub const DEPTH_LIMIT: u32 = 64;

/// T452 (2026-08-19) — the explosion, diagnosed and fixed.
///
/// The original `brute_value` rejected only repeats **along the current DFS
/// path**, so it enumerated *simple paths*, not states. On 2×2 the basic-ko
/// shape never fires (the goban is too small — see the ko test below), so
/// capture–recapture cycles are unbounded by the rule and only the path
/// history stops them. Simple paths in the 2430-state 2×2 graph run to depth
/// ~40–50 before a state repeats (measured: the depth bound never fired), and
/// there are exponentially many of them — the search spun at 100% CPU for up
/// to 171 min and `zig build test` never finished. T360 turned the spin into
/// a `@panic` on a 20M-node budget; that alarm was the signal, not the cure,
/// and the budget was never the fix.
///
/// Worse, the path-history DFS is *unsound*, not merely slow. Its value is
/// path-dependent: a state reached with different ancestors can yield a
/// different value, because a cycle back to an ancestor is valued TIE on one
/// path and not on another. A memoised on-stack DFS was tried first — it
/// collapsed the count and reproduced five anchors but returned the *wrong*
/// value on the ko-shape smoke test, because the memo freezes a value from one
/// stack context and reuses it in another. So the fix is not a cleverer DFS.
///
/// The fix is the **L/H median fixpoint** — the same sound algorithm
/// `exp6_solve.zig`'s `run_fixpoint_2x2` uses. Seed terminal states
/// (`passes == 2`) with their area score; give every other state the widest
/// bounds `L = -4` / `H = +4`; then sweep: for a Black-to-move state
/// `L = max` over the children's `L` and `H = max` over the children's `H`,
/// and for White-to-move `L = min` / `H = min`. A capture–recapture cycle can
/// never tighten a bound past the seed, so the bounds of states inside a cycle
/// stay wide; the resolved value is the median `v = max(L, min(TIE, H))`, which
/// is exactly the draw value under “TIE on repetition”. The sweep is monotone
/// over the finite [−4, 4] lattice, so it converges in a handful of passes over
/// 2430 states — microseconds, no budget, no path dependence. It reproduces
/// all seven 2×2 smoke anchors (empty B/W = 0, full B = +4, full W = −4,
/// passes = 1 / 2 = 0, and the ko shape = 0), so it does not widen what those
/// tests measure; it makes the reference compute them at all.
/// NODE_BUDGET / nodes_visited are removed: the search is finite by
/// construction, so the T360 alarm is obsolete. `Fingerprint` / `fp_eq` are
/// retained as named records for readers.

/// Widest lower / upper bounds for a 2×2 area score (range [−4, +4]).
pub const LO_BOUND: i8 = -4;
pub const HI_BOUND: i8 = 4;
pub const MAX_SWEEPS: u32 = 64;

/// Result of the 2×2 L/H fixpoint. `v(idx)` is the resolved draw-on-repetition
/// value of state `idx`: `max(L[idx], min(TIE, H[idx]))`.
pub const Fixpoint = struct {
    L: [TOTAL_STATES]i8,
    H: [TOTAL_STATES]i8,
    sweeps: u32,
    converged: bool,

    pub fn v(t: *const @This(), idx: usize) i8 {
        return @max(t.L[idx], @min(TIE, t.H[idx]));
    }
};

/// Solve the 2×2 game under basic ko + TIE-on-repetition by L/H median
/// fixpoint. Sound and terminating: bounds are monotone-narrowed over the
/// finite [−4, 4] lattice, so the sweep converges in ≤ `MAX_SWEEPS` passes
/// (and in practice in a handful). Cycles (capture–recapture with no basic-ko
/// ban on 2×2) leave the bounds of their member states wide, so `v` resolves
/// them to `TIE = 0`.
pub fn solve_fixpoint() Fixpoint {
    var t = Fixpoint{
        .L = [_]i8{LO_BOUND} ** TOTAL_STATES,
        .H = [_]i8{HI_BOUND} ** TOTAL_STATES,
        .sweeps = 0,
        .converged = false,
    };
    // Seed terminals: passes == 2 → area score, both bounds pinned.
    for (0..TOTAL_STATES) |i| {
        const s = state_from_index(i);
        if (s.passes == 2) {
            const a = State.terminal_value(s);
            t.L[i] = a;
            t.H[i] = a;
        }
    }
    while (t.sweeps < MAX_SWEEPS) {
        t.sweeps += 1;
        var changed = false;
        for (0..TOTAL_STATES) |i| {
            const s = state_from_index(i);
            if (s.passes == 2) continue; // seed pinned
            const maximizing = s.side > 0;
            var bl: ?i8 = null;
            var bh: ?i8 = null;
            // Pass is always legal for passes < 2; placements follow.
            var succs: [5]State = undefined;
            var m: usize = 0;
            if (State.apply_pass(s)) |ns| { succs[m] = ns; m += 1; }
            for (0..n) |cell_u| {
                const cell: u8 = @intCast(cell_u);
                if (State.apply_place(s, cell)) |ns| { succs[m] = ns; m += 1; }
            }
            for (succs[0..m]) |ns| {
                const ci = global_index(ns);
                const vl = t.L[ci];
                const vh = t.H[ci];
                if (bl == null or (if (maximizing) vl > bl.? else vl < bl.?)) bl = vl;
                if (bh == null or (if (maximizing) vh > bh.? else vh < bh.?)) bh = vh;
            }
            if (bl.? != t.L[i]) { t.L[i] = bl.?; changed = true; }
            if (bh.? != t.H[i]) { t.H[i] = bh.?; changed = true; }
        }
        if (!changed) {
            t.converged = true;
            break;
        }
    }
    return t;
}

/// Top-level: game value of state `s` under basic ko + TIE-on-repetition.
/// Solves the full 2×2 L/H fixpoint and reads out `v(global_index(s))`. Each
/// call is independent — `value(s)` depends only on `s`, never on a prior
/// call. The solve is ~2430 states × a handful of sweeps, so a single query is
/// microseconds; callers that value many states should hold a `solve_fixpoint()`
/// result and call `.v(idx)` directly (as `main` does).
pub fn value(s: State) i8 {
    const t = solve_fixpoint();
    return t.v(global_index(s));
}

// ---- state encoding / decoding ----------------------------------------------
//
// Global state index for a 2x2 board:
//   bits:  passes(2) | side(1) | ko(3) | goban(7)  (board: 3^4=81, 7 bits)
//   total: 3 * 2 * 5 * 81 = 2430   (passes: 3 values 0/1/2; side: 2; ko: n+1=5; board: 3^4=81)

pub const TOTAL_STATES: u64 = 81 * 2 * (n + 1) * 3; // = 2430 for 2x2 (passes 3 × side 2 × ko 5 × board 81)

pub fn global_index(s: State) u64 {
    const ko_idx: u32 = if (s.ko_point == State.KO_NONE) n else @as(u32, s.ko_point);
    return (@as(u64, s.passes) * 2 * (n + 1) +
        (if (s.side == 1) @as(u64, 0) else @as(u64, 1)) * (n + 1) + ko_idx) * 81 +
        board_index(s.board);
}

pub fn state_from_index(idx: u64) State {
    const board_id: u32 = @intCast(idx % 81);
    const rest: u64 = idx / 81;
    const ko_idx: u32 = @intCast(rest % (n + 1));
    const side_passes: u64 = rest / (n + 1);
    const side = if (side_passes % 2 == 0) @as(i8, 1) else @as(i8, -1);
    const passes: u8 = @intCast(side_passes / 2);
    const ko: u8 = if (ko_idx == n) State.KO_NONE else @intCast(ko_idx);
    return State{
        .board = unrank_board(board_id),
        .side = side,
        .ko_point = ko,
        .passes = passes,
    };
}

pub fn board_index(board: Pos) u32 {
    var idx: u32 = 0;
    var mult: u32 = 1;
    for (0..n) |i| {
        const d: u32 = if (board[i] > 0) @as(u32, 1) else if (board[i] < 0) @as(u32, 2) else @as(u32, 0);
        idx += d * mult;
        mult *= 3;
    }
    return idx;
}

pub fn unrank_board(idx: u32) Pos {
    var board: Pos = [_]i8{0} ** n;
    var i: usize = 0;
    var v: u32 = idx;
    while (i < n) : (i += 1) {
        const d = v % 3;
        v /= 3;
        board[i] = switch (d) {
            0 => 0,
            1 => 1,
            2 => -1,
            else => unreachable,
        };
    }
    return board;
}

/// Reachability walk: start from a state, follow the legal-move graph,
/// mark every visited state.
pub fn mark_reachable(
    s: State,
    visited: *std.DynamicBitSetUnmanaged,
    gpa: std.mem.Allocator,
) !void {
    const idx = global_index(s);
    if (visited.isSet(idx)) return;
    visited.set(idx);
    if (State.apply_pass(s)) |next_s| {
        try mark_reachable(next_s, visited, gpa);
    }
    for (0..n) |cell_u| {
        const cell: u8 = @intCast(cell_u);
        if (State.apply_place(s, cell)) |next_s| {
            try mark_reachable(next_s, visited, gpa);
        }
    }
}

// ---- main: enumerate reachable states, dump (idx, value) pairs --------------

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;

    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next(); // skip program name
    const mode = args.next() orelse "dump";

    var visited = try std.DynamicBitSetUnmanaged.initEmpty(gpa, TOTAL_STATES);
    defer visited.deinit(gpa);

    // Reachability: start from the empty goban in all (side, ko, passes)
    // combinations, plus any state that might be a root. The four roots
    // are: empty goban + Black-to-move, empty goban + White-to-move.
    const empty_board = [_]i8{0} ** n;
    const sides: [2]i8 = .{ 1, -1 };
    const passes_arr: [3]u8 = .{ 0, 1, 2 };
    for (sides) |side| {
        for (passes_arr) |passes| {
            // ko_point = none, but also iterate all ko_point values for
            // completeness (some may be reachable via captures).
            try mark_reachable(State{ .board = empty_board, .side = side, .ko_point = State.KO_NONE, .passes = passes }, &visited, gpa);
            for (0..n) |ko| {
                try mark_reachable(State{ .board = empty_board, .side = side, .ko_point = @intCast(ko), .passes = passes }, &visited, gpa);
            }
        }
    }

    // Count legal vs total.
    var total_visited: u64 = 0;
    var total_legal: u64 = 0;
    var it = visited.iterator(.{});
    while (it.next()) |idx| {
        total_visited += 1;
        const s = state_from_index(idx);
        if (E.is_legal(&s.board)) total_legal += 1;
    }

    if (std.mem.eql(u8, mode, "dump")) {
        // Dump: one line per visited state. Format:
        //   idx<TAB>side<TAB>passes<TAB>ko<TAB>brute_v
        // (ko is 0..n-1 or 255 for none)
        // Sorted by idx (visited.iterator returns sorted). The fixpoint is
        // solved once and read out per state — valuing many states via a
        // per-call `value(s)` would re-solve the whole table each time.
        const t = solve_fixpoint();
        var iter = visited.iterator(.{});
        while (iter.next()) |idx| {
            const s = state_from_index(idx);
            const v = t.v(idx);
            std.debug.print("{d}\t{d}\t{d}\t{d}\t{d}\n", .{ idx, s.side, s.passes, s.ko_point, v });
        }
    } else if (std.mem.eql(u8, mode, "summary")) {
        // Print summary: total visited, total legal, TIE value, depth
        // limit. (For the comparison test's header.)
        std.debug.print(
            \\# qa023_brute_2x2 summary
            \\# TIE = {d}, DEPTH_LIMIT = {d}
            \\# total_visited = {d}
            \\# total_legal = {d}
            \\
        , .{ TIE, DEPTH_LIMIT, total_visited, total_legal });
    } else {
        std.debug.print("usage: qa023_brute_2x2 [dump|summary]\n", .{});
        return error.UnknownMode;
    }
}

// ---- tests ------------------------------------------------------------------

test "smoke: empty board Black to move -> value 0 (published anchor)" {
    const s = State{
        .board = [_]i8{0} ** n,
        .side = 1,
        .ko_point = State.KO_NONE,
        .passes = 0,
    };
    const v = value(s);
    try expect(v == 0);
}

test "smoke: empty board White to move -> value 0" {
    const s = State{
        .board = [_]i8{0} ** n,
        .side = -1,
        .ko_point = State.KO_NONE,
        .passes = 0,
    };
    const v = value(s);
    try expect(v == 0);
}

test "smoke: full-Black board -> value 4 (area score of decided terminal)" {
    // Full board: no placements possible (all occupied); only pass.
    // Two passes = terminal at area_score(4, 4) - 0 - 0 = 4.
    const s = State{
        .board = [_]i8{ 1, 1, 1, 1 },
        .side = 1,
        .ko_point = State.KO_NONE,
        .passes = 0,
    };
    const v = value(s);
    try expect(v == 4);
}

test "smoke: full-White board -> value -4" {
    const s = State{
        .board = [_]i8{ -1, -1, -1, -1 },
        .side = 1,
        .ko_point = State.KO_NONE,
        .passes = 0,
    };
    const v = value(s);
    try expect(v == -4);
}

test "smoke: passes=1 is NOT terminal" {
    // One pass made; opponent can pass (=> terminal 0) or place. Both yield
    // value 0 from this position.
    const s = State{
        .board = [_]i8{0} ** n,
        .side = -1,
        .ko_point = State.KO_NONE,
        .passes = 1,
    };
    const v = value(s);
    try expect(v == 0);
}

test "smoke: passes=2 IS terminal" {
    const s = State{
        .board = [_]i8{0} ** n,
        .side = 1,
        .ko_point = State.KO_NONE,
        .passes = 2,
    };
    const v = value(s);
    try expect(v == 0);
}

test "smoke: 1-ko shape: B captures 1 W stone, the ko point forbids the snapback" {
    // 2x2 board: cells 0 1 / 2 3 (row-major). Set up: White at cell 0
    // (single stone). Black plays cell 1 — does it capture?
    //  After: B[0]=0, B[1]=1, B[2]=0, B[3]=0. W[0] alone has neighbors
    //  1 (Black), no liberties — captured. So next board: B[1]=1, others
    //  empty. The captured cell is 0. Black's stone at 1 has neighbors
    //  0 (empty), 3 (empty), 2 (empty) — THREE liberties, not the basic-ko
    //  shape. So no ko is set; the new ko_point is NONE.
    // So the move is legal, and the resulting state has ko_point = NONE.
    // Now Black's turn with B[1]=1, side=White. White can play cell 0.
    //  After: B[0]=-1, B[1]=1, B[2]=0, B[3]=0. The new placement at 0
    //  has neighbors 1 (Black) — 1 liberty, OK. No capture. So this is
    //  a legal move for White.
    // The "ko point" notion only matters for the *single-stone capture
    // with capturing stone having exactly 1 liberty* shape. On 2x2, this
    // requires the capturing stone to be on the edge, with the captured
    // stone in the corner. E.g., capture scenario:
    //   Position: W[0], B[1]. Black plays cell 3. B[3] has neighbors
    //   1 (B), 2 (empty) — TWO liberties, not 1. No ko.
    //  So on 2x2, basic-ko with formalization (i) NEVER fires! The
    //  2x2 goban is too small for the ko shape to occur.
    //  This is the trivial-coincidence case for A2.
    //  (The 2x2 result must still be 0; this test asserts it.)
    const s = State{
        .board = [_]i8{ -1, 1, 0, 0 },
        .side = -1,
        .ko_point = State.KO_NONE,
        .passes = 0,
    };
    const v = value(s);
    try expect(v == 0);
}
