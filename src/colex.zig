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
//        'tis unmerchantable shit.       //
//    Liability for damages denied.       //
//                                        //
////////////////////////////////////////////
//
// LAYERED COLEX INDEX (colex) — the oracle's address system (ADR-0007, plan C).
//
// "Colex" (co-lexicographic) is the subset ordering used for the occupied
// cells: subsets are grouped by their HIGHEST cell, so all subsets confined to
// cells 0..m-1 precede any subset touching cell m. Consequence: a subset's
// colex number depends only on the cells it uses, never on the board size —
// the index space simply extends as the board grows. The project uses "colex"
// as shorthand for the whole layered address below.
//
// A board's colex index is its SERIAL NUMBER in a fixed enumeration order —
// an ADDRESS, never a score. `colex_from_pos` and `pos_from_colex` form a
// collision-free bijection (a minimal perfect hash with an inverse) between
// boards and the dense integers 0 .. 3^n - 1:
//
//   value_table[colex_from_pos(p)] = score of p   (score: i8, -25..+25,
//                                                 Black-positive, stored later)
//
// (The combinatorics literature calls this "ranking/unranking"; that word is
// deliberately avoided here — in Go, "rank" means kyu/dan player strength.)
//
// Layout — LAYERED by stone count k (also the retrograde solver's layer order;
// each layer is a contiguous, independently storable block):
//
//   idx  = layer_offset[k]                        // all boards with < k stones
//        + subset_idx(occupied cells) * 2^k       // which cells hold stones
//        + colour_bits                            // who owns them (1 = black),
//                                                 // bit j = j-th cell ascending
//
//   subset_idx = combinatorial number system: for occupied cells
//   c1 < c2 < ... < ck, subset_idx = C(c1,1) + C(c2,2) + ... + C(ck,k).
//
//   layer_size(k) = C(n,k) * 2^k;   sum over k = 3^n exactly.
//
// (An equally valid bijection is the literal base-3 number — cell i
// contributes digit*3^i; that is exactly state.zig's u40 "view". The layered
// form is preferred because stone count = retrograde processing order, and the
// subset component is where the later density folds attach.)
//
// "RAW" = the address space includes illegal and non-canonical boards (wasted
// slots). That is deliberate: raw indexing is simple, O(stones) both ways, and
// fully sufficient to build + validate the retrograde oracle on 3x3 / 4x4
// (3^9 = 19_683 slots; 3^16 = 43 MB at 1 B/slot). Density upgrades (legal-only
// ~2x, canonical-only ~16x) are later, behind this same two-function interface,
// and only gate 5x5 (raw 3^25 slots = 847 GB at 1 B/slot -> ~26 GB folded).
//
// FORMAT CONTRACT: this layout (layer offsets, subset ordering, colour-bit
// convention) defines where every stored oracle value lives on disk. Any change
// silently re-addresses every persisted file — version the layout in the
// persist header (like the codec's "WZG1" magic) before writing real data.
//
// Standalone: no state.zig / zobrist.zig imports (dyld gotcha); std only.

const std = @import("std");
const expect = std.testing.expect;

/// FORMAT CONTRACT version of the address layout below (layered by stone
/// count, combinatorial-number-system subset index, colour bit j = j-th
/// occupied cell ascending, 1 = black). Any change to that ordering MUST
/// bump this — it silently re-addresses every persisted oracle artifact
/// (artifact.zig stores it in the file header and refuses a mismatch).
pub const layout_version: u8 = 1;

pub fn Indexer(comptime w: usize, comptime h: usize) type {
    return struct {
        pub const n = w * h;
        pub const Pos = [n]i8; // 0 empty, +1 black, -1 white (project convention)

        /// Pascal's triangle, C(i, j) for i, j in 0..n. C(i,j)=0 where j>i.
        pub const binomial: [n + 1][n + 1]u64 = blk: {
            var c: [n + 1][n + 1]u64 = .{.{0} ** (n + 1)} ** (n + 1);
            for (0..n + 1) |i| {
                c[i][0] = 1;
                for (1..i + 1) |j| {
                    c[i][j] = c[i - 1][j - 1] + (if (j <= i - 1) c[i - 1][j] else 0);
                }
            }
            break :blk c;
        };

        /// layer_offset[k] = number of boards with fewer than k stones;
        /// layer_offset[n+1] = 3^n (the total address-space size).
        pub const layer_offset: [n + 2]u64 = blk: {
            var off: [n + 2]u64 = undefined;
            off[0] = 0;
            for (0..n + 1) |k| {
                off[k + 1] = off[k] + binomial[n][k] * (@as(u64, 1) << k);
            }
            break :blk off;
        };

        pub const total: u64 = layer_offset[n + 1]; // == 3^n

        /// The board's serial number (address) in 0 .. 3^n - 1. Pure encoding
        /// of WHICH board this is — never a score.
        pub fn colex_from_pos(pos: *const Pos) u64 {
            var k: usize = 0; // stones seen so far
            var subset: u64 = 0; // combinatorial number system index
            var colours: u64 = 0; // bit j = 1 iff j-th occupied cell is black
            for (0..n) |cell| {
                if (pos[cell] == 0) continue;
                if (pos[cell] > 0) colours |= @as(u64, 1) << @intCast(k);
                k += 1;
                subset += binomial[cell][k]; // C(cell, k) with k 1-based here
            }
            return layer_offset[k] + subset * (@as(u64, 1) << @intCast(k)) + colours;
        }

        /// Inverse of `colex_from_pos`.
        pub fn pos_from_colex(idx: u64) Pos {
            std.debug.assert(idx < total);
            // find the layer: k such that layer_offset[k] <= idx < layer_offset[k+1]
            var k: usize = 0;
            while (idx >= layer_offset[k + 1]) k += 1;
            const layer_idx = idx - layer_offset[k];
            var subset = layer_idx >> @intCast(k);
            const colours = layer_idx & ((@as(u64, 1) << @intCast(k)) - 1);

            var pos: Pos = [_]i8{0} ** n;
            // decode the k-subset, largest element first (greedy)
            var i = k;
            while (i > 0) : (i -= 1) {
                // largest cell with C(cell, i) <= subset
                var cell = n - 1;
                while (binomial[cell][i] > subset) cell -= 1;
                subset -= binomial[cell][i];
                // this is the (i-1)-th occupied cell in ascending order
                const black = (colours >> @intCast(i - 1)) & 1 == 1;
                pos[cell] = if (black) 1 else -1;
            }
            return pos;
        }
    };
}

// ---- runner: exhaustive bijection verification --------------------------------

/// Verify colex_from_pos / pos_from_colex is a bijection over the ENTIRE 3^n space of a board:
/// every board round-trips, every index is in range and hit exactly once.
fn verify(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator) !void {
    const R = Indexer(w, h);
    const words = (R.total + 63) / 64;
    const seen = try gpa.alloc(u64, words);
    defer gpa.free(seen);
    @memset(seen, 0);

    var digits = [_]u8{0} ** R.n; // base-3 odometer
    var pos: R.Pos = [_]i8{0} ** R.n;
    var count: u64 = 0;
    while (true) {
        const r = R.colex_from_pos(&pos);
        if (r >= R.total) return error.IndexOutOfRange;
        const word = r / 64;
        const bit = @as(u64, 1) << @intCast(r % 64);
        if (seen[word] & bit != 0) return error.IndexCollision;
        seen[word] |= bit;
        const back = R.pos_from_colex(r);
        if (!std.mem.eql(i8, &back, &pos)) return error.RoundTripMismatch;
        count += 1;

        var i: usize = 0;
        while (i < R.n) : (i += 1) {
            if (digits[i] == 2) {
                digits[i] = 0;
                pos[i] = 0;
                continue;
            }
            digits[i] += 1;
            pos[i] = if (digits[i] == 1) 1 else -1;
            break;
        }
        if (i == R.n) break;
    }
    if (count != R.total) return error.CountMismatch;
    std.debug.print("{d}x{d}: bijection over all {d} boards VERIFIED (dense, no collision)\n", .{ w, h, count });
}

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    std.debug.print("weizigo layered colex index -- address system (run with -O ReleaseFast)\n\n", .{});
    try verify(2, 2, gpa);
    try verify(3, 3, gpa);
    try verify(3, 2, gpa);
    try verify(4, 4, gpa); // 43M boards, ~seconds in ReleaseFast

    // 5x5 addresses work arithmetically NOW (no enumeration needed) --
    // only the 847 GB value ARRAY needs the legality/symmetry folds first.
    const R5 = Indexer(5, 5);
    std.debug.print("\n5x5 address space: total = {d} (= 3^25), layers:\n", .{R5.total});
    for (0..R5.n + 1) |k| {
        const size = R5.layer_offset[k + 1] - R5.layer_offset[k];
        std.debug.print("  k={d:>2}: offset={d:>15}  size={d:>14}\n", .{ k, R5.layer_offset[k], size });
    }
    // demonstrate a 5x5 round trip: single black stone at the center (tengen)
    var tengen: R5.Pos = [_]i8{0} ** 25;
    tengen[12] = 1;
    const r = R5.colex_from_pos(&tengen);
    const back = R5.pos_from_colex(r);
    std.debug.print("\n5x5 tengen: colex_from_pos={d}, pos_from_colex round-trips: {}\n", .{ r, std.mem.eql(i8, &back, &tengen) });
}

// ---- tests ------------------------------------------------------------------

test "layer sizes sum to 3^n" {
    const R = Indexer(3, 3);
    try expect(R.total == 19_683); // 3^9
    const R4 = Indexer(4, 4);
    try expect(R4.total == 43_046_721); // 3^16
    const R5 = Indexer(5, 5);
    try expect(R5.total == 847_288_609_443); // 3^25
}

test "empty board has index 0; an index is an address, not a score" {
    const R = Indexer(5, 5);
    const empty: R.Pos = [_]i8{0} ** 25;
    try expect(R.colex_from_pos(&empty) == 0);
}

test "single-stone layer: 25 cells x 2 colours occupy indices 1..50" {
    const R = Indexer(5, 5);
    try expect(R.layer_offset[1] == 1);
    try expect(R.layer_offset[2] == 51); // 1 + C(25,1)*2
    var seen = [_]bool{false} ** 51;
    for (0..25) |cell| {
        inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
            var p: R.Pos = [_]i8{0} ** 25;
            p[cell] = colour;
            const r = R.colex_from_pos(&p);
            try expect(r >= 1 and r < 51);
            try expect(!seen[r]);
            seen[r] = true;
            const back = R.pos_from_colex(r);
            try expect(std.mem.eql(i8, &back, &p));
        }
    }
}

test "exhaustive bijection on 2x2 and 3x3 (and a rectangle)" {
    try verify(2, 2, std.testing.allocator);
    try verify(3, 3, std.testing.allocator);
    try verify(3, 2, std.testing.allocator);
}

test "colour bit convention: j-th occupied cell ascending, 1 = black" {
    const R = Indexer(2, 2);
    // two stones on cells 0,1: colours (b,b), (b,w), (w,b), (w,w) must be
    // consecutive indices within the same subset block, ordered by colour bits:
    // ww=00, bw=01 (cell0 black), wb=10 (cell1 black), bb=11
    const ww = R.colex_from_pos(&[_]i8{ -1, -1, 0, 0 });
    const bw = R.colex_from_pos(&[_]i8{ 1, -1, 0, 0 });
    const wb = R.colex_from_pos(&[_]i8{ -1, 1, 0, 0 });
    const bb = R.colex_from_pos(&[_]i8{ 1, 1, 0, 0 });
    try expect(bw == ww + 1 and wb == ww + 2 and bb == ww + 3);
}
