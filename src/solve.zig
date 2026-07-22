////////////////////////////////////////////
//                                        //
//    (c) 2024 Alexander E Genaud         //
//                                        //
//    Permission is granted hereby,       //
//    to copy, share, use, modify,        //
//        for purposes any,               //
//        for free or for money,          //
//    provided these notices multiply.    //
//                                        //
//    This work "as is" I provide,        //
//    no warranty express or implied,     //
//        for, no purpose fit,            //
//        'tis unmerchantable shit.       //
//    Liability for damages denied.       //
//                                        //
////////////////////////////////////////////
//
// Correct search-to-terminal (docs/decisions/0005).
//
//   - Chinese / area scoring, value from Black's perspective, minus komi.
//   - Positional superko via superko.History (repetition is illegal).
//   - A node is terminal when Benson-settled (terminal.is_settled) or after two
//     consecutive passes; its value is the area score.
//   - Moves: every legal stone placement (skip Suicide, skip superko repeats)
//     plus pass. Black maximizes, White minimizes.
//
// Phase 2 adds a transposition table so the search is tractable (a single
// capture can reopen the board into a near-empty position whose subtree is
// exponential without memoization). Three rules keep the TT sound:
//
//   1. Key = (blind, seq) + side, canonicalized by state.lowest_blind_from_pos
//      (8 dihedral symmetries x black/white inversion). Only positions with
//      <= 16 stones are hashable (seq holds 16 stones); >16-stone positions
//      are near-terminal and searched without the TT.
//   2. Cache only nodes reached with `passes == 0`. Passing changes a
//      position's value (you may pass to end the game), so (board, side, passes)
//      is the true state; the thin `passes == 1` layer is computed inline.
//   3. GHI (Graph History Interaction): superko makes legality path-dependent,
//      so a value is only cacheable when every superko ban in its subtree
//      referenced a position within that subtree (not an ancestor). solve()
//      returns `ko_ref` = the shallowest game-line ply any ban referenced; a
//      node at ply `d` is cacheable iff `ko_ref >= d`.
//
// Full-board (5x5) only: restricting to a sub-region of the 25-cell array is
// unsound (edge stones keep phantom liberties into the unplayable cells).
//
// Invariant: when solve() is entered, `pos` is already the top of `history`.

const std = @import("std");
const expect = std.testing.expect;
const state = @import("state.zig");
const superko = @import("superko.zig");
const terminal = @import("terminal.zig");
const util = @import("util.zig");

const UNDEF = util.UNDEF;

/// Sentinel `ko_ref` meaning "no superko ban in this subtree referenced any
/// prior ply" -> the subtree value is fully history-independent (cacheable).
pub const KO_CLEAN: usize = std.math.maxInt(usize);

/// Only positions with at most this many stones are hashable: `seq` records the
/// colours of the occupied cells and holds 16 stones. Positions with more
/// stones are near-terminal (<= 8 empty points) and searched without the TT.
pub const MAX_HASH_STONES: u8 = 16;

pub const Result = struct {
    value: i8, // area score from Black's perspective, minus komi
    ko_ref: usize, // shallowest game-line ply any superko ban here referenced
};

// Black maximizes and White minimizes the Black-perspective value; these seed
// the min/max fold below any / above any real score (|value| <= 25 + |komi|).
const WORST_FOR_BLACK: i8 = -127;
const WORST_FOR_WHITE: i8 = 127;

/// A seq-block entry: a colour sequence and its canonical-frame score.
pub const SeqScore = struct {
    seq: u16 = 0,
    score: i8 = UNDEF,
};

/// Worst-case number of distinct colour sequences for a blind of `num_stones`
/// stones, AFTER black/white inversion canonicalization: the lowest-indexed
/// stone's colour is fixed, leaving `num_stones - 1` free bits. (Depends only on
/// the stone count -- there is no search-depth argument.) `num_stones` must be
/// <= MAX_HASH_STONES.
pub fn block_size(num_stones: u8) u32 {
    if (num_stones == 0) return 1;
    return @as(u32, 1) << @intCast(num_stones - 1);
}

/// Transposition table: two blind arrays (one per side to move) each mapping a
/// canonical 25-bit occupancy `blind` to the start index of a block of
/// `SeqScore` slots inside `seq`. Slot/index 0 of `seq` is reserved as the
/// "unset" sentinel (a blind array entry of 0 means "no block yet").
pub const Table = struct {
    black: []u32, // side-to-move Black:  blind -> seq block start (0 = unset)
    white: []u32, // side-to-move White:  blind -> seq block start (0 = unset)
    seq: []SeqScore,
    next: u32 = 1, // next free seq index; 0 reserved as the unset sentinel

    /// Retrieve the Black-perspective value stored for (pos, to_move), or null.
    pub fn get(self: *const Table, pos: *const [25]i8, to_move: i8) ?i8 {
        const low = state.lowest_blind_from_pos(pos);
        if (low.num_stones > MAX_HASH_STONES) return null;
        // Fold black/white inversion into the side key: value(pos, t) equals
        // -value(inverse(pos), -t), so an inverted board keys on the opposite
        // side and negates the stored (canonical-frame) score.
        const key_side = if (low.is_inverse) -to_move else to_move;
        const tbl = if (key_side > 0) self.black else self.white;
        const start = tbl[low.blind];
        if (start == 0) return null;
        const bs = block_size(low.num_stones);
        var i = start;
        while (i < start + bs) : (i += 1) {
            const c = self.seq[i];
            if (c.score == UNDEF) return null; // empty slot: seq not present
            if (c.seq == low.seq) return if (low.is_inverse) -c.score else c.score;
        }
        return null;
    }

    /// Store the Black-perspective `value` for (pos, to_move).
    pub fn set(self: *Table, pos: *const [25]i8, to_move: i8, value: i8) void {
        const low = state.lowest_blind_from_pos(pos);
        if (low.num_stones > MAX_HASH_STONES) return;
        const key_side = if (low.is_inverse) -to_move else to_move;
        const tbl = if (key_side > 0) self.black else self.white;
        const bs = block_size(low.num_stones);

        var start = tbl[low.blind];
        if (start == 0) {
            // ALWAYS-LIVE bounds (not `assert`, which is a no-op in ReleaseFast):
            // overrunning `seq` would silently corrupt the table and poison the
            // oracle. Fail loud in every build.
            if (self.next + bs > self.seq.len) @panic("TT: seq table full");
            start = self.next;
            tbl[low.blind] = start;
            self.next += bs;
        }

        const stored: i8 = if (low.is_inverse) -value else value;
        var i = start;
        while (i < start + bs) : (i += 1) {
            const c = &self.seq[i];
            if (c.score == UNDEF) { // fresh slot
                c.seq = low.seq;
                c.score = stored;
                return;
            }
            if (c.seq == low.seq) {
                // Same position must map to the same value; a mismatch is a real
                // engine bug, so trap it in every build rather than only in Debug.
                if (c.score != stored) @panic("TT: inconsistent value for a position");
                return;
            }
        }
        @panic("TT: block_size undersized for this num_stones"); // block overrun
    }
};

/// Is empty point `p` a true eye of `to_move`: every orthogonal neighbour is a
/// `to_move` stone that is Benson-unconditionally-alive? Such a point is already
/// the mover's territory and filling it is never beneficial, so the search skips
/// it. (Edge/corner points count if all their present neighbours qualify.)
fn is_own_eye(pos: *const [25]i8, p: u8, to_move: i8, alive: *const [25]bool) bool {
    const row = p / 5;
    const col = p % 5;
    if (row > 0) {
        const q = p - 5;
        if (pos[q] * to_move <= 0 or !alive[q]) return false;
    }
    if (row < 4) {
        const q = p + 5;
        if (pos[q] * to_move <= 0 or !alive[q]) return false;
    }
    if (col > 0) {
        const q = p - 1;
        if (pos[q] * to_move <= 0 or !alive[q]) return false;
    }
    if (col < 4) {
        const q = p + 1;
        if (pos[q] * to_move <= 0 or !alive[q]) return false;
    }
    return true;
}

/// Optimal area value (Black-positive) of `pos` with `to_move` to play,
/// `passes` consecutive passes already made. `pos` must be the top of `history`.
/// `table` may be null (no memoization -- only for tiny/terminal trees).
pub fn solve(
    pos: *const [25]i8,
    to_move: i8, // +1 black, -1 white
    passes: u8,
    history: *superko.History,
    table: ?*Table,
    komi: i8,
) Result {
    if (passes >= 2) return .{ .value = terminal.area_score(pos) - komi, .ko_ref = KO_CLEAN };
    if (terminal.is_settled(pos)) return .{ .value = terminal.area_score(pos) - komi, .ko_ref = KO_CLEAN };

    // `d` = this node's own 0-based index on the game line (pos is the top).
    const d = history.len - 1;
    const hashable = table != null and passes == 0 and
        @popCount(state.blind_from_pos(pos)) <= MAX_HASH_STONES;

    // A cache hit is history-independent by construction (only ko_ref>=d values
    // were ever stored), so it contributes no taint to the parent.
    if (hashable) {
        if (table.?.get(pos, to_move)) |v| return .{ .value = v, .ko_ref = KO_CLEAN };
    }

    const maximizing = to_move > 0;
    var best: i8 = if (maximizing) WORST_FOR_BLACK else WORST_FOR_WHITE;
    var ko_ref: usize = KO_CLEAN;

    // A player never benefits from filling its own true eye (a point enclosed by
    // its own Benson-unconditionally-alive stones): under area scoring the point
    // is already its territory, and filling only risks the group's life. Pruning
    // these moves is sound AND essential for tractability -- without it the DFS
    // explores a live group filling its own eyes down to one liberty, letting
    // the opponent capture the whole group and reopen the board (see
    // docs/decisions/0006). The opponent cannot fill these eyes either (suicide),
    // so a Benson-alive group's eyes are immortal.
    const own_alive = terminal.pass_alive(pos, to_move);

    // stone moves
    for (0..25) |p| {
        if (pos[p] != 0) continue;
        if (is_own_eye(pos, @intCast(p), to_move, &own_alive)) continue;
        const child = state.armies_from_move(pos, to_move, @intCast(p)) catch {
            continue; // Suicide / Unexpected / Occupied -> not a legal move here
        };
        if (history.repeatsIndex(&child)) |j| {
            if (j < ko_ref) ko_ref = j; // superko ban referenced game-line ply j
            continue;
        }
        history.push(&child);
        const r = solve(&child, -to_move, 0, history, table, komi);
        history.pop();
        if (r.ko_ref < ko_ref) ko_ref = r.ko_ref;
        if (maximizing) {
            if (r.value > best) best = r.value;
        } else {
            if (r.value < best) best = r.value;
        }
    }

    // pass move (board unchanged: not pushed to history, exempt from superko)
    const rp = solve(pos, -to_move, passes + 1, history, table, komi);
    if (rp.ko_ref < ko_ref) ko_ref = rp.ko_ref;
    if (maximizing) {
        if (rp.value > best) best = rp.value;
    } else {
        if (rp.value < best) best = rp.value;
    }

    // Cacheable iff every superko ban in this subtree referenced a ply within
    // the subtree itself (>= d). A ban referencing an ancestor above d makes
    // the value history-conditional -> do not cache.
    if (hashable and ko_ref >= d) table.?.set(pos, to_move, best);

    return .{ .value = best, .ko_ref = ko_ref };
}

/// Convenience entry: resets history, seeds it with `pos`, and solves.
pub fn solve_root(
    pos: *const [25]i8,
    to_move: i8,
    history: *superko.History,
    table: ?*Table,
    komi: i8,
) i8 {
    history.reset();
    history.push(pos);
    return solve(pos, to_move, 0, history, table, komi).value;
}

// ---- tests ------------------------------------------------------------------

var test_history: superko.History = .{}; // ~57 KB; keep off the test stack

const two_eyes_black = [_]i8{
    1, 1, 1, 1, 1,
    1, 0, 1, 0, 1,
    1, 1, 1, 1, 1,
    1, 1, 1, 1, 1,
    1, 1, 1, 1, 1,
};

// --- terminal / scoring paths (no TT needed) --------------------------------

test "settled position solves to its area (both sides to move)" {
    try expect(solve_root(&two_eyes_black, 1, &test_history, null, 0) == 25);
    try expect(solve_root(&two_eyes_black, -1, &test_history, null, 0) == 25);
}

test "komi shifts the value" {
    try expect(solve_root(&two_eyes_black, 1, &test_history, null, 7) == 18); // 25 - 7
}

test "colour symmetry: inverse settled position negates the value" {
    const inv = state.armies_inverse(&two_eyes_black); // all-white two-eye group
    try expect(solve_root(&inv, -1, &test_history, null, 0) == -25);
    try expect(solve_root(&inv, 1, &test_history, null, 0) == -25);
}

test "full board resolves by double pass to its area score" {
    const W: i8 = -1;
    const full = [_]i8{
        1, 1, 1, W, W,
        1, 1, 1, W, W,
        1, 1, 1, W, W,
        1, 1, 1, W, W,
        1, 1, 1, W, W,
    };
    try expect(solve_root(&full, 1, &test_history, null, 0) == 5); // 15 black - 10 white
    try expect(solve_root(&full, -1, &test_history, null, 0) == 5);
}

// --- TT machinery unit tests -------------------------------------------------

fn makeTable(comptime seq_len: usize) type {
    return struct {
        var black = [_]u32{0} ** (1 << 25);
        var white = [_]u32{0} ** (1 << 25);
        var seq = [_]SeqScore{.{}} ** seq_len;
    };
}

test "block_size: 2^(n-1), n=0 -> 1" {
    try expect(block_size(0) == 1);
    try expect(block_size(1) == 1);
    try expect(block_size(2) == 2);
    try expect(block_size(3) == 4);
    try expect(block_size(16) == 32768);
}

test "TT round-trips a value keyed by side to move" {
    const G = makeTable(64);
    @memset(G.black[0..], 0);
    @memset(G.white[0..], 0);
    for (G.seq[0..]) |*s| s.* = .{};
    var t = Table{ .black = G.black[0..], .white = G.white[0..], .seq = G.seq[0..] };

    const b = [_]i8{
        1, 0, -1, 0, 0,
        0, 0, 0,  0, 0,
        0, 0, 0,  0, 0,
        0, 0, 0,  0, 0,
        0, 0, 0,  0, 0,
    };
    try expect(t.get(&b, 1) == null);
    t.set(&b, 1, 12);
    try expect(t.get(&b, 1).? == 12);
    // the other side to move is a distinct key (still unset)
    try expect(t.get(&b, -1) == null);
    t.set(&b, -1, -3);
    try expect(t.get(&b, -1).? == -3);
    try expect(t.get(&b, 1).? == 12); // unchanged
}

test "TT: colour-inverse board keys on opposite side and negates the score" {
    const G = makeTable(64);
    @memset(G.black[0..], 0);
    @memset(G.white[0..], 0);
    for (G.seq[0..]) |*s| s.* = .{};
    var t = Table{ .black = G.black[0..], .white = G.white[0..], .seq = G.seq[0..] };

    const b = [_]i8{
        1, 0, -1, 0, 0,
        0, 0, 0,  0, 0,
        0, 0, 0,  0, 0,
        0, 0, 0,  0, 0,
        0, 0, 0,  0, 0,
    };
    const inv = state.armies_inverse(&b);
    // value(b, Black) = V  ==>  value(inv, White) = -V, and both reference the
    // same canonical slot, so storing one lets us read the other.
    t.set(&b, 1, 9);
    try expect(t.get(&inv, -1).? == -9);
}

// --- integrated search (eye-prune + superko + TT + GHI) ---------------------

var tt_history: superko.History = .{};

// Black is unconditionally alive (two real eyes at idx 6 and 18). A single dead
// white stone sits at idx 8 with one liberty (idx 3). This is NOT settled (the
// white stone is not pass-alive), so the search must actually play: it captures
// the dead stone and reaches Black+25. The eye-prune is what keeps this bounded
// -- without it the DFS would fill black's eyes, let white capture the whole
// group, and reopen the board into an intractable near-empty search.
const dead_white = [_]i8{
    1, 1, 1, 0, 1,
    1, 0, 1, -1, 1,
    1, 1, 1, 1,  1,
    1, 1, 1, 0,  1,
    1, 1, 1, 1,  1,
};

test "integrated search resolves a dead stone to Black+25 (both sides)" {
    // Black to move and White to move both yield Black+25: white cannot live
    // (every invasion is suicide) and its dead stone is captured.
    try expect(solve_root(&dead_white, 1, &tt_history, null, 0) == 25);
    try expect(solve_root(&dead_white, -1, &tt_history, null, 0) == 25);
}

test "TT changes nothing vs the no-TT search, and colour symmetry holds" {
    const no_tt = solve_root(&dead_white, 1, &tt_history, null, 0);

    const G = makeTable(1 << 16);
    @memset(G.black[0..], 0);
    @memset(G.white[0..], 0);
    for (G.seq[0..]) |*s| s.* = .{};
    var t = Table{ .black = G.black[0..], .white = G.white[0..], .seq = G.seq[0..] };

    const with_tt = solve_root(&dead_white, 1, &tt_history, &t, 0);
    try expect(no_tt == with_tt);

    // colour symmetry through the search: value(pos, b) == -value(inv, w)
    const inv = state.armies_inverse(&dead_white);
    const inv_val = solve_root(&inv, -1, &tt_history, &t, 0);
    try expect(inv_val == -with_tt);
}

test "eye-prune: a Benson-alive group's own eyes are not playable moves" {
    // idx 6 and 18 are true eyes of the alive black group; the mover must not
    // fill them (that is the move that would eventually reopen the board).
    const alive = terminal.pass_alive(&dead_white, 1);
    try expect(is_own_eye(&dead_white, 6, 1, &alive));
    try expect(is_own_eye(&dead_white, 18, 1, &alive));
    // idx 3 borders the dead white stone, so it is NOT a black eye -> playable
    // (it is the capturing move).
    try expect(!is_own_eye(&dead_white, 3, 1, &alive));
}
