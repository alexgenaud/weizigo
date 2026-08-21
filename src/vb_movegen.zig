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
//        for, no purpose fit,            //
//        'tis merchantable shit.        //
//    Liability for damages denied.       //
//                                        //
////////////////////////////////////////////
//
// VB_MOVEGEN — verify-battery independent move generator + state-key
// encoder (T340, R8, g3b-battery sprint).
//
// Author: minimax-m3/T340 (R8 author B; distinct from MG-KERN author A).
//
// This is the **independent re-implementation** of the move relation and
// the state-key encoder. The output contract (legalMoves and stateKey) is
// identical to the kernel's at every state; the implementation is not.
// Author blindness is enforced by scheduling (R8 starts in Wave 1, before
// MG-KERN's kernel function exists — see plan §6 / spec §4.3), not by
// trust.
//
// RULESET INPUT — the only ruleset input is the prose of
// `docs/epics/E1-markovian/AXIOMS.md` §2 (A1–A6, B1–B3) and the StateKey
// struct interface from `src/rules.zig` (field names + types, not the
// implementation). No kernel/solver source was read. The implementation
// was written from the axioms; the colex bijection was re-derived from
// the formula in `src/colex.zig`'s header comment (the "colex" address
// system is project-public knowledge; the layer offsets and combinatorial
// number system are spec, not kernel implementation).
//
// OUTPUT CONTRACTS — for a goban of size w × h:
//   • `legalMoves(state) -> [moves_bytes]u8` — bit i = 1 iff moving to
//     cell i is legal; bit n = 1 iff pass is legal; bits > n+1 are 0.
//     moves_bytes = ceil((n+1) / 8), n = w*h. The SMD1 §4.6.3 format.
//   • `stateKey(state) -> StateKey` — exactly the kernel's StateKey
//     struct, with the same field names, types, and side-encoding.
//
// STATE — `{ pos: [n]i8, side: i8, ko: u8, passes: u2 }`:
//   • pos: -1 = White, 0 = empty, +1 = Black (project sign convention,
//     C4 / AXIOMS §2).
//   • side: +1 = Black to move, -1 = White to move.
//   • ko: cell index of the ko-forbidden recapture, or any value >= n
//     to mean "no ko" (the SMD1 artifact-slice uses 255; both n and 255
//     are NONE here, so 255 reads as NONE for any w × h with n ≤ 254).
//   • passes: 0, 1, or 2. passes=2 is the absorbing double-pass terminal
//     (no children). D3 invariant: passes >= 1 ⇒ ko == NONE.
//
// STANDALONE — imports only `std`. No imports from `src/`, including
// rules.zig, exp6_solve.zig, differential.zig, or colex.zig. The colex
// bijection is re-implemented below; the kernel's pos_from_move /
// koAfterCapture are not used (and were not read).

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

// ═══════════════════════════════════════════════════════════════════════════
//  PUBLIC STATE TYPE
// ═══════════════════════════════════════════════════════════════════════════

/// Game state: position + side-to-move + ko + pass count.
/// comptime w, h: goban dimensions. n = w*h.
pub fn State(comptime w: usize, comptime h: usize) type {
    return struct {
        pos: [w * h]i8, // -1=White, 0=empty, +1=Black
        side: i8, // +1=Black, -1=White
        ko: u8, // ko-forbidden cell, or >= w*h for NONE
        passes: u2, // 0, 1, or 2

        pub const W = w;
        pub const H = h;
        pub const N = w * h;

    };
}

// ═══════════════════════════════════════════════════════════════════════════
//  STATEKEY INTERFACE — mirror of src/rules.zig StateKey
// ═══════════════════════════════════════════════════════════════════════════

/// StateKey — D1 (AXIOMS §2). The full state tuple's compact
/// representation. Field names + types + side encoding MUST match
/// `src/rules.zig`'s `StateKey` (this is the public interface copied
/// from there; only the field list is read, not the implementation).
///
/// side: u1 — 0 = Black, 1 = White (per the kernel's convention).
/// ko: u16 — the cell index, or n (or any value >= n) for NONE.
/// terminal: bool — true iff passes == 2.
pub const StateKey = struct {
    colex_idx: u64,
    side: u1, // 0 = Black, 1 = White
    ko: u16,
    passes: u2,
    terminal: bool,

    pub fn eql(a: StateKey, b: StateKey) bool {
        return a.colex_idx == b.colex_idx and
            a.side == b.side and
            a.ko == b.ko and
            a.passes == b.passes and
            a.terminal == b.terminal;
    }
};

// ═══════════════════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════════════════

/// Orthogonal neighbors of cell p on a w×h goban. Writes up to 4 cells
/// to `buf`; returns the count.
fn neighbors(comptime w: usize, comptime h: usize, p: usize, buf: *[4]usize) usize {
    var cnt: usize = 0;
    const row = p / w;
    const col = p % w;
    if (row > 0) {
        buf[cnt] = p - w;
        cnt += 1;
    }
    if (row + 1 < h) {
        buf[cnt] = p + w;
        cnt += 1;
    }
    if (col > 0) {
        buf[cnt] = p - 1;
        cnt += 1;
    }
    if (col + 1 < w) {
        buf[cnt] = p + 1;
        cnt += 1;
    }
    return cnt;
}

/// Pascal's triangle C(i, j) for 0 <= i, j <= n. C(i, j) = 0 where j > i.
fn binomTable(comptime n: usize) [n + 1][n + 1]u64 {
    var c: [n + 1][n + 1]u64 = .{.{0} ** (n + 1)} ** (n + 1);
    for (0..n + 1) |i| {
        c[i][0] = 1;
        for (1..i + 1) |j| {
            c[i][j] = c[i - 1][j - 1] + (if (j <= i - 1) c[i - 1][j] else 0);
        }
    }
    return c;
}

/// layer_offset[k] = number of positions with fewer than k stones.
/// layer_offset[n+1] = 3^n (the total address-space size).
fn layerOffsets(comptime n: usize) [n + 2]u64 {
    const c = binomTable(n);
    var off: [n + 2]u64 = undefined;
    off[0] = 0;
    for (0..n + 1) |k| {
        off[k + 1] = off[k] + c[n][k] * (@as(u64, 1) << @intCast(k));
    }
    return off;
}

// ═══════════════════════════════════════════════════════════════════════════
//  PUBLIC: colex bijection (D1 — "position is the goban colouring encoded
//  by colex index"; the layered colex layout per colex.zig's header
//  comment, re-derived here).
// ═══════════════════════════════════════════════════════════════════════════

/// Encode a position to its layered-colex index.
/// `pos[c] = 0` (empty), `+1` (Black), or `-1` (White).
pub fn colexFromPos(comptime w: usize, comptime h: usize, pos: *const [w * h]i8) u64 {
    const n = w * h;
    const layer_off = comptime layerOffsets(n);
    const c = comptime binomTable(n);
    var k: usize = 0;
    var subset: u64 = 0;
    var colours: u64 = 0;
    for (0..n) |cell| {
        const v = pos[cell];
        if (v == 0) continue;
        if (v > 0) colours |= @as(u64, 1) << @intCast(k);
        k += 1;
        subset += c[cell][k];
    }
    return layer_off[k] + subset * (@as(u64, 1) << @intCast(k)) + colours;
}

/// Decode a layered-colex index to a position.
pub fn posFromColex(comptime w: usize, comptime h: usize, idx: u64) [w * h]i8 {
    const n = w * h;
    const layer_off = comptime layerOffsets(n);
    const c = comptime binomTable(n);

    // find the layer: k such that layer_off[k] <= idx < layer_off[k+1]
    var k: usize = 0;
    while (idx >= layer_off[k + 1]) k += 1;
    const layer_idx = idx - layer_off[k];
    var subset = layer_idx >> @intCast(k);
    const colours = layer_idx & ((@as(u64, 1) << @intCast(k)) - 1);

    var pos: [n]i8 = [_]i8{0} ** n;
    var i: usize = k;
    while (i > 0) {
        i -= 1;
        // largest cell with C(cell, i+1) <= subset
        var cell: usize = n - 1;
        while (c[cell][i + 1] > subset) cell -= 1;
        subset -= c[cell][i + 1];
        const black = (colours >> @intCast(i)) & 1 == 1;
        pos[cell] = if (black) @as(i8, 1) else @as(i8, -1);
    }
    return pos;
}

// ═══════════════════════════════════════════════════════════════════════════
//  PUBLIC: legalMoves — A2/A3/A4/A5/B1/B2/B3
// ═══════════════════════════════════════════════════════════════════════════

/// Returns a bitmap of legal moves in the state `s`:
///   bit i (0 <= i < w*h) = 1 iff a stone placement at cell i is legal.
///   bit (w*h) = 1 iff pass is legal (A5: pass is always legal).
///   bits > w*h are 0.
///
/// Move legality under R (basic ko, k=1, no suicide):
///   1. A2 — cell must be empty.
///   2. A3/A4 — placement must not be suicide. "Capture first" (A3), then
///      check the placed stone's own group has at least one liberty.
///   3. B1 — a placement at the current ko point is illegal (recapture).
///   4. A5/B3 — pass is always legal regardless of the ko state (the ko
///      point is cleared on a pass; see stateKey's child). Pass is a
///      distinct child and has its own bit; the pass bit is set whenever
///      the state is not the absorbing terminal (passes=2).
///   5. C1 (D1) — at passes=2, no children at all: empty bitmap.
/// moves_bytes for a w x h goban: ceil((n+1) / 8), where n = w*h and
/// the +1 is the pass bit (SMD1 section 4.6.3).
pub fn movesBytes(comptime w: usize, comptime h: usize) usize {
    return (w * h + 1 + 7) / 8;
}

pub fn legalMoves(comptime w: usize, comptime h: usize, s: State(w, h)) [movesBytes(w, h)]u8 {
    const mb = comptime movesBytes(w, h);
    const n = w * h;
    var bm: [mb]u8 = [_]u8{0} ** mb;

    // C1 — at passes=2 the state is the absorbing terminal; no children.
    if (s.passes == 2) return bm;

    // The current player's colour.
    const colour: i8 = s.side;
    const opp: i8 = -s.side;

    // Ko is set iff s.ko < n; otherwise (ko >= n) it is NONE.
    const ko_set = s.ko < @as(u8, @intCast(n));

    for (0..n) |cell| {
        // A2 — occupied cells are not legal placements.
        if (s.pos[cell] != 0) continue;
        // B1 — the ko point is the recapture that would create a 2-ply
        // repeat (AXIOMS §2 B1 derivation). Forbid it.
        if (ko_set and cell == s.ko) continue;
        // A4 — suicide check. After A3 capture is applied, the placed
        // stone's own group must have at least one liberty. Compute
        // A3 first (captures any opponent chain left without liberties
        // after the placement), then check the placed stone's group.
        if (isSuicidal(w, h, &s.pos, colour, opp, cell)) continue;
        // Legal: set bit `cell`.
        bm[cell / 8] |= @as(u8, 1) << @intCast(cell % 8);
    }

    // A5 — pass is always legal. Bit n is the pass bit. (B3: a pass
    // clears the ko point, so it always breaks a ko cycle.)
    bm[n / 8] |= @as(u8, 1) << @intCast(n % 8);

    return bm;
}

/// True iff a placement at `cell` by `colour` would be suicide (A4).
/// Computes A3 capture first, then checks the placed stone's group for
/// liberties. `pos` is the *pre-placement* board.
fn isSuicidal(
    comptime w: usize,
    comptime h: usize,
    pos: *const [w * h]i8,
    colour: i8,
    opp: i8,
    cell: usize,
) bool {
    // A3 — apply captures: any opponent chain adjacent to `cell` that
    // would have zero liberties after the placement is removed.
    var next: [w * h]i8 = undefined;
    for (0..w * h) |i| next[i] = if (pos[i] > 0) @as(i8, 1) else if (pos[i] < 0) @as(i8, -1) else @as(i8, 0);
    next[cell] = colour;

    var nb: [4]usize = undefined;
    const cnt = neighbors(w, h, cell, &nb);
    for (nb[0..cnt]) |q| {
        if (next[q] == opp and chainHasNoLiberty(w, h, &next, q, opp)) {
            // remove the captured chain
            removeChain(w, h, &next, q, opp);
        }
    }

    // A4 — after captures, the placed stone's group must have a liberty.
    // A suicide is the case where the group has zero liberties, which
    // `chainHasNoLiberty` reports as `true`.
    return chainHasNoLiberty(w, h, &next, cell, colour);
}

// Helpers below do the A3 capture and A4 group-liberty check by direct
// flood-fill (re-derived, not copied from any kernel source).

/// True iff the chain containing `seed` (of colour `c`) has zero liberties
/// on the board `pos`. The chain is found by flood-fill; visited cells are
/// tracked by the `visited` array (caller-provided, must be all-false on
/// entry; reused across calls within a single function).
fn chainHasNoLiberty(
    comptime w: usize,
    comptime h: usize,
    pos: *const [w * h]i8,
    seed: usize,
    c: i8,
) bool {
    const n = w * h;
    if (pos[seed] != c) return false; // not in a chain of colour c
    var visited = [_]bool{false} ** n;
    var stack: [n]usize = undefined;
    var sp: usize = 1;
    stack[0] = seed;
    visited[seed] = true;
    var has_lib = false;
    var nb: [4]usize = undefined;
    while (sp > 0) {
        sp -= 1;
        const q = stack[sp];
        const cnt = neighbors(w, h, q, &nb);
        for (nb[0..cnt]) |r| {
            if (pos[r] == 0) {
                has_lib = true;
            } else if (pos[r] == c and !visited[r]) {
                visited[r] = true;
                stack[sp] = r;
                sp += 1;
            }
        }
    }
    return !has_lib;
}

/// Remove every stone of the chain containing `seed` (of colour `c`) from
/// `pos`, in-place. Assumes the chain is closed under flood-fill of `c`.
fn removeChain(
    comptime w: usize,
    comptime h: usize,
    pos: *[w * h]i8,
    seed: usize,
    c: i8,
) void {
    const n = w * h;
    var visited = [_]bool{false} ** n;
    var stack: [n]usize = undefined;
    var sp: usize = 1;
    stack[0] = seed;
    visited[seed] = true;
    pos[seed] = 0;
    var nb: [4]usize = undefined;
    while (sp > 0) {
        sp -= 1;
        const q = stack[sp];
        const cnt = neighbors(w, h, q, &nb);
        for (nb[0..cnt]) |r| {
            if (pos[r] == c and !visited[r]) {
                visited[r] = true;
                pos[r] = 0;
                stack[sp] = r;
                sp += 1;
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
//  PUBLIC: stateKey — D1, D3
// ═══════════════════════════════════════════════════════════════════════════

/// Build the StateKey for `s`.
///
/// Side encoding (matches the kernel's `StateKey.side: u1`):
///   +1 (Black) -> 0
///   -1 (White) -> 1
/// (Per AXIOMS §2 C4: side-to-move picks the array, never the sign.)
///
/// Ko: stored as the raw u8 input widened to u16. The "ko is NONE" case
/// is the caller's convention; this function does not re-encode it. The
/// StateKey.terminal bit is set iff passes == 2.
pub fn stateKey(comptime w: usize, comptime h: usize, s: State(w, h)) StateKey {
    return StateKey{
        .colex_idx = colexFromPos(w, h, &s.pos),
        .side = if (s.side == 1) @as(u1, 0) else @as(u1, 1),
        .ko = @as(u16, s.ko),
        .passes = s.passes,
        .terminal = s.passes == 2,
    };
}

// ═══════════════════════════════════════════════════════════════════════════
//  BITMAP HELPERS (test convenience)
// ═══════════════════════════════════════════════════════════════════════════

/// True iff bit `i` is set in `bm`. Bit ordering: bit 0 = LSB of byte 0.
fn bitSet(bm: []const u8, i: usize) bool {
    return bm[i / 8] & (@as(u8, 1) << @intCast(i % 8)) != 0;
}

// ═══════════════════════════════════════════════════════════════════════════
//  TESTS
// ═══════════════════════════════════════════════════════════════════════════

// ---- colex bijection ------------------------------------------------------

test "vb_movegen: colex 2x2 round-trip bijection over all positions" {
    const C = struct {
        const w = 2;
        const h = 2;
    };
    const n = C.w * C.h;
    const total: u64 = 81; // 3^4
    // verify total matches the layered sum
    const lo = comptime layerOffsets(n);
    try expectEqual(total, lo[n + 1]);

    // round-trip every base-3 encoding
    var digits = [_]u8{0} ** n;
    var pos: [n]i8 = [_]i8{0} ** n;
    var seen_bits: u64 = 0;
    var count: u64 = 0;
    while (true) {
        const r = colexFromPos(C.w, C.h, &pos);
        try expect(r < total);
        seen_bits |= @as(u64, 1) << @intCast(r % 64);
        const back = posFromColex(C.w, C.h, r);
        try expect(std.mem.eql(i8, &back, &pos));
        count += 1;

        // odometer +1 in base 3
        var i: usize = 0;
        while (i < n) : (i += 1) {
            if (digits[i] == 2) {
                digits[i] = 0;
                pos[i] = 0;
                continue;
            }
            digits[i] += 1;
            pos[i] = if (digits[i] == 1) @as(i8, 1) else @as(i8, -1);
            break;
        }
        if (i == n) break;
    }
    try expectEqual(total, count);
    // All 81 indices should be distinct. Check seen_bits is a complete
    // bitset by sampling: the lowest 64 bits should be the lower-half
    // 64 indices (since we enumerate colex=0,1,2,3... in odometer order,
    // which is the layered colex in a different but still per-position-
    // unique enumeration).
    // Concrete stronger check: round-trip covers exactly 81 distinct
    // colex values, and seen_bits's first 64 bits include exactly 64
    // distinct values out of those 81 — which is true iff the bijection
    // spans 81 distinct indices (it does, by construction).
    // So: count the set bits in seen_bits; should equal 64 (the lower 64
    // colex indices from the 2x2 odometer enumeration).
    var bit_count: u32 = 0;
    var bits: u64 = seen_bits;
    while (bits != 0) : (bits &= bits - 1) bit_count += 1;
    try expectEqual(@as(u32, 64), bit_count);
}

test "vb_movegen: colex 2x2 — empty board is index 0" {
    const w = 2;
    const h = 2;
    const pos = [_]i8{0} ** (w * h);
    try expectEqual(@as(u64, 0), colexFromPos(w, h, &pos));
}

test "vb_movegen: colex 3x3 — empty board is index 0, total = 3^9" {
    const w = 3;
    const h = 3;
    const n = w * h;
    const pos = [_]i8{0} ** n;
    try expectEqual(@as(u64, 0), colexFromPos(w, h, &pos));
    const lo = comptime layerOffsets(n);
    try expectEqual(@as(u64, 19_683), lo[n + 1]);
}

// ---- legalMoves: 2x2 ------------------------------------------------------

test "vb_movegen: legalMoves 2x2 — empty board, Black to move" {
    const w = 2;
    const h = 2;
    const S = State(w, h);
    const s: S = .{
        .pos = [_]i8{0} ** (w * h),
        .side = 1, // Black
        .ko = @as(u8, w * h), // NONE
        .passes = 0,
    };
    const bm = legalMoves(w, h, s);
    // 4 cells + pass = 5 bits; all should be set on the empty board
    try expect(bitSet(&bm, 0)); // cell 0
    try expect(bitSet(&bm, 1)); // cell 1
    try expect(bitSet(&bm, 2)); // cell 2
    try expect(bitSet(&bm, 3)); // cell 3
    try expect(bitSet(&bm, 4)); // pass
}

test "vb_movegen: legalMoves 2x2 — full board, Black to move" {
    const w = 2;
    const h = 2;
    const S = State(w, h);
    const s: S = .{
        .pos = [_]i8{ 1, -1, -1, 1 }, // two black, two white
        .side = 1,
        .ko = @as(u8, w * h),
        .passes = 0,
    };
    const bm = legalMoves(w, h, s);
    // No cells empty; only pass is legal.
    try expect(!bitSet(&bm, 0));
    try expect(!bitSet(&bm, 1));
    try expect(!bitSet(&bm, 2));
    try expect(!bitSet(&bm, 3));
    try expect(bitSet(&bm, 4));
}

test "vb_movegen: legalMoves 2x2 — suicide forbidden (corner surrounded)" {
    // 2x2, cells 0,1 / 2,3 in row-major. Cell 0 has neighbours 1 and 2.
    // Setup: pos = { 0, -1, -1, 0 }, side = Black.
    // Black plays at cell 0. A3 first:
    //   cell 1 (White): neighbours 0 (Black), 3 (empty) — has liberty 3.
    //   cell 2 (White): neighbours 0 (Black), 3 (empty) — has liberty 3.
    // Neither White is captured. Now the placed B at cell 0 is in group
    // {0} (no other Black adjacent). Neighbours: 1 (White), 2 (White).
    // No empty neighbours → suicide → illegal.
    const w = 2;
    const h = 2;
    const S = State(w, h);
    const s: S = .{
        .pos = [_]i8{ 0, -1, -1, 0 },
        .side = 1, // Black to move
        .ko = @as(u8, w * h),
        .passes = 0,
    };
    const bm = legalMoves(w, h, s);
    // Cell 0 is the suicide — illegal.
    try expect(!bitSet(&bm, 0));
    // Cells 1, 2 are occupied by White; not legal placements.
    try expect(!bitSet(&bm, 1));
    try expect(!bitSet(&bm, 2));
    // Cell 3 is also suicide: if Black plays at 3, A3 first — cell 1
    // (White) has liberty at 0 (empty) so not captured. After placement,
    // the B group at {3} has neighbours 1 (W), 2 (W), no empties.
    // Suicide → illegal.
    try expect(!bitSet(&bm, 3));
    // Pass is always legal.
    try expect(bitSet(&bm, 4));
}

test "vb_movegen: legalMoves 2x2 — ko point forbids recapture" {
    // Set ko = 0; no other restrictions. Cell 0 is empty but
    // ko-forbidden; everything else is legal.
    const w = 2;
    const h = 2;
    const S = State(w, h);
    const s: S = .{
        .pos = [_]i8{0} ** (w * h),
        .side = 1,
        .ko = 0, // ko point at cell 0
        .passes = 0,
    };
    const bm = legalMoves(w, h, s);
    try expect(!bitSet(&bm, 0)); // forbidden by ko
    try expect(bitSet(&bm, 1));
    try expect(bitSet(&bm, 2));
    try expect(bitSet(&bm, 3));
    try expect(bitSet(&bm, 4)); // pass legal
}

test "vb_movegen: legalMoves 2x2 — terminal (passes=2) has no moves" {
    const w = 2;
    const h = 2;
    const S = State(w, h);
    const s: S = .{
        .pos = [_]i8{0} ** (w * h),
        .side = 1,
        .ko = @as(u8, w * h),
        .passes = 2,
    };
    const bm = legalMoves(w, h, s);
    // No bits set (no children, including no pass).
    for (bm) |b| try expectEqual(@as(u8, 0), b);
}

test "vb_movegen: legalMoves 2x2 — White to move on empty" {
    // Side inversion: -1 (White) is the player; everything else is the
    // same as Black to move (the rules don't depend on the colour of
    // the mover, only its identity relative to the board).
    const w = 2;
    const h = 2;
    const S = State(w, h);
    const s: S = .{
        .pos = [_]i8{0} ** (w * h),
        .side = -1,
        .ko = @as(u8, w * h),
        .passes = 0,
    };
    const bm = legalMoves(w, h, s);
    for (0..5) |i| try expect(bitSet(&bm, i));
}

// ---- legalMoves: 3x2 (rectangular, sanity) --------------------------------

test "vb_movegen: legalMoves 3x2 — empty board, 6 cells + pass = 7 bits" {
    const w = 3;
    const h = 2;
    const S = State(w, h);
    const s: S = .{
        .pos = [_]i8{0} ** (w * h),
        .side = 1,
        .ko = @as(u8, w * h),
        .passes = 0,
    };
    const bm = legalMoves(w, h, s);
    for (0..7) |i| try expect(bitSet(&bm, i));
    // bit 7 must be 0
    try expect(!bitSet(&bm, 7));
}

test "vb_movegen: legalMoves 3x2 — SMD1 moves_bytes = 1" {
    try expectEqual(@as(usize, 1), movesBytes(3, 2));
}

test "vb_movegen: legalMoves 4x4 — SMD1 moves_bytes = 3" {
    try expectEqual(@as(usize, 3), movesBytes(4, 4));
}

// ---- stateKey -------------------------------------------------------------

test "vb_movegen: stateKey — empty 2x2 Black, ko=NONE, passes=0" {
    const w = 2;
    const h = 2;
    const S = State(w, h);
    const s: S = .{
        .pos = [_]i8{0} ** (w * h),
        .side = 1, // Black
        .ko = @as(u8, w * h),
        .passes = 0,
    };
    const k = stateKey(w, h, s);
    try expectEqual(@as(u64, 0), k.colex_idx); // empty = 0
    try expectEqual(@as(u1, 0), k.side); // Black = 0
    try expectEqual(@as(u16, w * h), k.ko); // raw u8 widened
    try expectEqual(@as(u2, 0), k.passes);
    try expect(!k.terminal);
}

test "vb_movegen: stateKey — side encoding: Black→0, White→1" {
    const w = 2;
    const h = 2;
    const S = State(w, h);
    const b: S = .{
        .pos = [_]i8{0} ** (w * h),
        .side = 1,
        .ko = @as(u8, w * h),
        .passes = 0,
    };
    const wt: S = .{
        .pos = [_]i8{0} ** (w * h),
        .side = -1,
        .ko = @as(u8, w * h),
        .passes = 0,
    };
    const bk = stateKey(w, h, b);
    const wk = stateKey(w, h, wt);
    try expectEqual(@as(u1, 0), bk.side);
    try expectEqual(@as(u1, 1), wk.side);
    try expect(!bk.eql(wk)); // different sides
}

test "vb_movegen: stateKey — terminal iff passes == 2" {
    const w = 2;
    const h = 2;
    const S = State(w, h);
    const s0: S = .{ .pos = [_]i8{0} ** (w * h), .side = 1, .ko = @as(u8, w * h), .passes = 0 };
    const s1: S = .{ .pos = [_]i8{0} ** (w * h), .side = 1, .ko = @as(u8, w * h), .passes = 1 };
    const s2: S = .{ .pos = [_]i8{0} ** (w * h), .side = 1, .ko = @as(u8, w * h), .passes = 2 };
    try expect(!stateKey(w, h, s0).terminal);
    try expect(!stateKey(w, h, s1).terminal);
    try expect(stateKey(w, h, s2).terminal);
}

test "vb_movegen: stateKey — ko is stored as raw u8 widened to u16" {
    // The SMD1 artifact-slice uses 255 for NONE; the kernel uses n.
    // Both are stored as the raw input — the StateKey.ko is the literal
    // ko value, not a re-encoded NONE.
    const w = 2;
    const h = 2;
    const S = State(w, h);
    const s_none_n: S = .{
        .pos = [_]i8{0} ** (w * h),
        .side = 1,
        .ko = @as(u8, w * h), // 4 for 2x2
        .passes = 0,
    };
    const s_none_255: S = .{
        .pos = [_]i8{0} ** (w * h),
        .side = 1,
        .ko = 255, // SMD1's NONE encoding
        .passes = 0,
    };
    const s_active: S = .{
        .pos = [_]i8{0} ** (w * h),
        .side = 1,
        .ko = 1, // an actual ko point
        .passes = 0,
    };
    try expectEqual(@as(u16, 4), stateKey(w, h, s_none_n).ko);
    try expectEqual(@as(u16, 255), stateKey(w, h, s_none_255).ko);
    try expectEqual(@as(u16, 1), stateKey(w, h, s_active).ko);
}

test "vb_movegen: stateKey — colex_idx for 1-stone positions" {
    // 2x2, one black stone at cell 0: layer_offset[1]=1 (just empty
    // board before this), subset=0, colours=1 (Black). So
    // colex = 1 + 0*2 + 1 = 2. (White at cell 0 would be 1.)
    const w = 2;
    const h = 2;
    const S = State(w, h);
    var pos: [w * h]i8 = [_]i8{0} ** (w * h);
    pos[0] = 1;
    const s: S = .{ .pos = pos, .side = 1, .ko = @as(u8, w * h), .passes = 0 };
    try expectEqual(@as(u64, 2), stateKey(w, h, s).colex_idx);

    // White at cell 0: colex = 1 + 0*2 + 0 = 1.
    var pos_w: [w * h]i8 = [_]i8{0} ** (w * h);
    pos_w[0] = -1;
    const sw: S = .{ .pos = pos_w, .side = 1, .ko = @as(u8, w * h), .passes = 0 };
    try expectEqual(@as(u64, 1), stateKey(w, h, sw).colex_idx);
}

test "vb_movegen: stateKey — distinct positions yield distinct keys" {
    // Two distinct positions, same side, same ko, same passes.
    const w = 2;
    const h = 2;
    const S = State(w, h);
    var pos_a: [w * h]i8 = [_]i8{0} ** (w * h);
    pos_a[0] = 1;
    var pos_b: [w * h]i8 = [_]i8{0} ** (w * h);
    pos_b[1] = 1;
    const a: S = .{ .pos = pos_a, .side = 1, .ko = @as(u8, w * h), .passes = 0 };
    const b: S = .{ .pos = pos_b, .side = 1, .ko = @as(u8, w * h), .passes = 0 };
    try expect(!stateKey(w, h, a).eql(stateKey(w, h, b)));
}

test "vb_movegen: stateKey — same state tuple yields same key" {
    const w = 2;
    const h = 2;
    const S = State(w, h);
    const s: S = .{
        .pos = [_]i8{ 1, -1, 0, 0 },
        .side = 1,
        .ko = 2,
        .passes = 1,
    };
    const k1 = stateKey(w, h, s);
    const k2 = stateKey(w, h, s);
    try expect(k1.eql(k2));
}
