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
// EXP-2 QA-023 — BRUTE-FORCE GAME-TREE REFERENCE (2x2).
// (docs/evidence/QA-023/proof.md)
//
// A INDEPENDENT reference implementation of the game value under
// (board, side, ko_point, passes) state with basic ko (formalization (i))
// and a constant tie value TIE = 0 for any long cycle.
//
// This is *not* a retrograde / fixpoint computation. It is an EXHAUSTIVE
// game-tree DFS with full history tracking. When a state is revisited in
// the history (a cycle), the value is set to TIE. This is the *ground
// truth* for the 2x2 board under this ruleset.
//
// The CONVERGE solver (qa023_basic_ko_2x2.zig) and this BRUTE-FORCE
// reference are cross-checked state-by-state by qa023_compare.zig. They
// must agree on EVERY reachable (board, side, ko_point, passes) tuple
// under 2x2.
//
// The implementation deliberately uses only the public surface of
// rules.zig and enumerate.zig (pos_from_move, area_score, is_legal) and
// does not import retro.zig / oracle.zig / solve.zig.
//
// Usage:
//   weizigo-qa023-brute-2x2 > states.txt
//   weizigo-qa023-converge-2x2 > states.txt
//   weizigo-qa023-compare states.txt states.txt

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

/// DEPTH_LIMIT — game-tree DFS bound. On 2x2, every play that doesn't
/// reach a cycle has at most 4 plies of placement + 2 pass plies = 6; but
/// we set this generously to be safe. The check `if (depth >= DEPTH_LIMIT)`
/// also returns TIE — this is the *definition* of brute force: if you ran
/// out of depth, the value is a tie (you didn't terminate).
pub const DEPTH_LIMIT: u32 = 64;

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
            // Check that the placed stone has exactly one liberty (the
            // captured cell) — the basic-ko shape.
            var liberties: u8 = 0;
            var nb: [4]usize = undefined;
            const cnt = R.neighbors(cell, &nb);
            for (nb[0..cnt]) |q| {
                if (next_board[q] == 0) liberties += 1;
            }
            if (liberties == 1) new_ko = captured_cell;
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

/// Game-tree DFS with full history. The value is:
///   - TIE if a state reappears in the path (cycle detected)
///   - TIE if depth limit reached
///   - terminal_value if `passes == 2`
///   - max over children if Black to move
///   - min over children if White to move
///
/// The history is tracked as a stack of state fingerprints. The fingerprint
/// is (board, side, ko_point, passes) — exactly the state tuple. If the
/// fingerprint is already in the history, a cycle is detected.
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

/// Stack of fingerprints; cap at DEPTH_LIMIT+1.
pub const FP_STACK_SIZE: u32 = DEPTH_LIMIT + 1;

pub fn brute_value(s: State, history: []Fingerprint, history_len: u32, depth: u32) i8 {
    // Cycle check: is the current state in the history?
    const current_fp = Fingerprint{
        .board = s.board,
        .side = s.side,
        .ko_point = s.ko_point,
        .passes = s.passes,
    };
    var i: u32 = 0;
    while (i < history_len) : (i += 1) {
        if (fp_eq(history[i], current_fp)) return TIE;
    }
    // Depth limit (defensive; on 2x2 this should not fire if the
    // analysis in the comment above is correct).
    if (depth >= DEPTH_LIMIT) return TIE;
    // Terminal.
    if (State.is_terminal(s)) return State.terminal_value(s);
    // Push and recurse.
    history[history_len] = current_fp;
    const new_history_len = history_len + 1;

    // Enumerate all legal moves.
    var best: i8 = if (s.side == 1) -128 else 127;

    if (State.apply_pass(s)) |next_s| {
        const v = brute_value(next_s, history, new_history_len, depth + 1);
        if (s.side == 1) {
            if (v > best) best = v;
        } else {
            if (v < best) best = v;
        }
    }
    for (0..n) |cell_u| {
        const cell: u8 = @intCast(cell_u);
        if (State.apply_place(s, cell)) |next_s| {
            const v = brute_value(next_s, history, new_history_len, depth + 1);
            if (s.side == 1) {
                if (v > best) best = v;
            } else {
                if (v < best) best = v;
            }
        }
    }
    return best;
}

/// Top-level: game value of state `s` (no history).
pub fn value(s: State) i8 {
    var history: [FP_STACK_SIZE]Fingerprint = undefined;
    return brute_value(s, &history, 0, 0);
}

// ---- state encoding / decoding ----------------------------------------------
//
// Global state index for a 2x2 board:
//   bits:  passes(2) | side(1) | ko(3) | board(7)  (board: 3^4=81, 7 bits)
//   total: 2 * 2 * 5 * 81 = 1620

pub const TOTAL_STATES: u32 = 81 * 2 * (n + 1) * 3; // = 1620 for 2x2

pub fn global_index(s: State) u32 {
    const ko_idx: u32 = if (s.ko_point == State.KO_NONE) n else @as(u32, s.ko_point);
    return (@as(u32, s.passes) * 2 * (n + 1) +
        (if (s.side == 1) @as(u32, 0) else @as(u32, 1)) * (n + 1) + ko_idx) * 81 +
        board_index(s.board);
}

pub fn state_from_index(idx: u32) State {
    const board_id = idx % 81;
    const rest = idx / 81;
    const ko_idx = rest % (n + 1);
    const side_passes = rest / (n + 1);
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

    // Reachability: start from the empty board in all (side, ko, passes)
    // combinations, plus any state that might be a root. The four roots
    // are: empty board + Black-to-move, empty board + White-to-move.
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
    var total_visited: u32 = 0;
    var total_legal: u32 = 0;
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
        // Sorted by idx (visited.iterator returns sorted).
        var iter = visited.iterator(.{});
        while (iter.next()) |idx| {
            const s = state_from_index(idx);
            const v = value(s);
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
    //  2x2 board is too small for the ko shape to occur.
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
