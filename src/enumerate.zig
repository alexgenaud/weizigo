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
// Board-size-agnostic LEGAL-POSITION enumerator — STRUCTURE only, no values
// (ADR-0007: enumerating positions is cheap and correct now; correct VALUES
// need the retrograde engine). This module is the foundation for the oracle's
// position set and the combinatorial-ranking data model.
//
//   legal position  = every chain (connected same-colour group) has >= 1
//                     liberty (Tromp-Taylor: no stone without liberty may
//                     remain on the board).
//   canonical       = the lexicographically-least board among the dihedral
//                     symmetries x colour inversion (16 variants on a square
//                     board). One canonical representative per equivalence
//                     class; the oracle stores one value per class per side.
//
// Validation targets (published, John Tromp / OEIS A094777, legal positions
// on n x n): 1x1 = 1, 2x2 = 57, 3x3 = 12_675, 4x4 = 24_318_165,
// 5x5 = 414_295_148_741.
//
// Enumeration is a base-3 odometer over all 3^n colourings — exact and simple.
// Practical up to 4x4 (3^16 = 43M). 5x5 (3^25 = 8.5e11) needs the layered /
// ranked enumeration (or a long ReleaseFast run) — deliberately deferred; this
// module establishes the machinery + the small-board ground truth first.
//
// Deliberately standalone: no imports from state.zig (5x5-specific) or
// zobrist.zig (huge tables; dyld gotcha). Only std.

const std = @import("std");
const expect = std.testing.expect;

/// Legal-position machinery for a w x h board. Cells are i8: 0 empty,
/// +1 black, -1 white (matching the project's sign convention).
pub fn Enumerator(comptime w: usize, comptime h: usize) type {
    return struct {
        pub const n = w * h;
        pub const Pos = [n]i8;

        // ---- symmetry permutations (comptime) -------------------------------
        // Square boards get the full dihedral group (8); rectangles get the
        // Klein group (4: identity, horizontal flip, vertical flip, 180).
        pub const num_syms = if (w == h) 8 else 4;

        pub const sym_perms: [num_syms][n]u8 = blk: {
            var perms: [num_syms][n]u8 = undefined;
            for (0..h) |r| {
                for (0..w) |c| {
                    const i = r * w + c;
                    // identity, flip-horizontal, flip-vertical, rotate-180
                    perms[0][i] = i;
                    perms[1][r * w + (w - 1 - c)] = i;
                    perms[2][(h - 1 - r) * w + c] = i;
                    perms[3][(h - 1 - r) * w + (w - 1 - c)] = i;
                    if (w == h) {
                        // transpose, rot90, rot270, anti-transpose
                        perms[4][c * w + r] = i;
                        perms[5][c * w + (w - 1 - r)] = i;
                        perms[6][(w - 1 - c) * w + r] = i;
                        perms[7][(w - 1 - c) * w + (w - 1 - r)] = i;
                    }
                }
            }
            break :blk perms;
        };

        // ---- legality --------------------------------------------------------

        /// Tromp-Taylor legal: every chain has at least one liberty.
        pub fn is_legal(pos: *const Pos) bool {
            var visited = [_]bool{false} ** n;
            for (0..n) |p| {
                if (pos[p] == 0 or visited[p]) continue;
                // flood this chain; look for any liberty
                const colour = pos[p];
                var stack: [n]usize = undefined;
                var sp: usize = 1;
                stack[0] = p;
                visited[p] = true;
                var has_liberty = false;
                while (sp > 0) {
                    sp -= 1;
                    const q = stack[sp];
                    const r = q / w;
                    const c = q % w;
                    // orthogonal neighbours
                    inline for (.{
                        .{ r > 0, q -% w },
                        .{ r + 1 < h, q + w },
                        .{ c > 0, q -% 1 },
                        .{ c + 1 < w, q + 1 },
                    }) |nb| {
                        if (nb[0]) {
                            const t = nb[1];
                            if (pos[t] == 0) {
                                has_liberty = true;
                            } else if (pos[t] == colour and !visited[t]) {
                                visited[t] = true;
                                stack[sp] = t;
                                sp += 1;
                            }
                        }
                    }
                }
                if (!has_liberty) return false;
            }
            return true;
        }

        // ---- canonicalization ------------------------------------------------

        /// Is `pos` the canonical representative of its class: lexicographically
        /// <= every dihedral transform x colour inversion of itself?
        pub fn is_canonical(pos: *const Pos) bool {
            inline for (0..num_syms) |s| {
                const perm = &sym_perms[s];
                // colour_flip = 1 (as-is) then -1 (inverted)
                inline for (.{ @as(i8, 1), @as(i8, -1) }) |flip| {
                    if (s == 0 and flip == 1) continue; // identity == self
                    // lexicographic compare of transform vs pos, early exit
                    var cmp: i8 = 0; // -1 transform smaller, +1 bigger
                    for (0..n) |i| {
                        const t = flip * pos[perm[i]];
                        if (t < pos[i]) {
                            cmp = -1;
                            break;
                        }
                        if (t > pos[i]) {
                            cmp = 1;
                            break;
                        }
                    }
                    if (cmp < 0) return false; // a smaller variant exists
                }
            }
            return true;
        }

        // ---- exhaustive census -----------------------------------------------

        pub const Census = struct {
            raw: u64 = 0, // 3^n, sanity
            legal: u64 = 0,
            canonical: u64 = 0, // canonical representatives among legal
            legal_by_stones: [n + 1]u64 = [_]u64{0} ** (n + 1),
            canon_by_stones: [n + 1]u64 = [_]u64{0} ** (n + 1),
        };

        /// Walk all 3^n colourings with a base-3 odometer; count legal and
        /// canonical-legal, per stone count. Exact, no allocation.
        pub fn census() Census {
            var result = Census{};
            var digits = [_]u8{0} ** n; // 0 empty, 1 black, 2 white
            var pos: Pos = [_]i8{0} ** n;
            var stones: usize = 0;
            while (true) {
                result.raw += 1;
                if (is_legal(&pos)) {
                    result.legal += 1;
                    result.legal_by_stones[stones] += 1;
                    if (is_canonical(&pos)) {
                        result.canonical += 1;
                        result.canon_by_stones[stones] += 1;
                    }
                }
                // odometer increment (cell 0 is the fastest digit)
                var i: usize = 0;
                while (i < n) : (i += 1) {
                    if (digits[i] == 2) {
                        digits[i] = 0;
                        pos[i] = 0;
                        stones -= 1; // was white, now empty
                        continue;
                    }
                    digits[i] += 1;
                    if (digits[i] == 1) {
                        pos[i] = 1; // empty -> black: +1 stone
                        stones += 1;
                    } else {
                        pos[i] = -1; // black -> white: same count
                    }
                    break;
                }
                if (i == n) return result; // odometer wrapped: done
            }
        }
    };
}

// ---- runner -------------------------------------------------------------------

/// Published legal-position counts on square boards (Tromp; OEIS A094777).
pub const known_legal = [_]u64{ 1, 57, 12_675, 24_318_165, 414_295_148_741 };

fn report(comptime size: usize, expected: ?u64) void {
    const E = Enumerator(size, size);
    const c = E.census();
    const ok = if (expected) |e| c.legal == e else true;
    std.debug.print("{d}x{d}: raw={d} legal={d} canonical={d}  {s}\n", .{
        size,                     size, c.raw, c.legal, c.canonical,
        if (ok) "PASS" else "FAIL vs published",
    });
    std.debug.print("     legal/canon by stones:", .{});
    for (0..E.n + 1) |k| {
        if (c.legal_by_stones[k] != 0)
            std.debug.print(" {d}:{d}/{d}", .{ k, c.legal_by_stones[k], c.canon_by_stones[k] });
    }
    std.debug.print("\n", .{});
}

pub fn main() !void {
    std.debug.print("weizigo position enumerator (structure only; ADR-0007)\n", .{});
    std.debug.print("run with -O ReleaseFast; 4x4 = 43M boards (~seconds fast, ~minutes debug)\n\n", .{});
    report(1, known_legal[0]);
    report(2, known_legal[1]);
    report(3, known_legal[2]);
    report(4, known_legal[3]);
    std.debug.print("\n5x5 (3^25 = 8.5e11) deferred: needs layered/ranked enumeration\n", .{});
    std.debug.print("or a long ReleaseFast run; published legal = {d}\n", .{known_legal[4]});
}

// ---- tests ------------------------------------------------------------------

test "1x1: only the empty board is legal (a lone stone has no liberty)" {
    const E = Enumerator(1, 1);
    const c = E.census();
    try expect(c.raw == 3);
    try expect(c.legal == 1);
    try expect(c.canonical == 1);
}

test "2x2: 57 legal positions (published)" {
    const E = Enumerator(2, 2);
    const c = E.census();
    try expect(c.raw == 81);
    try expect(c.legal == 57);
    // class sizes are 1..16 => canonical count is bounded by legal/16 .. legal
    try expect(c.canonical * 16 >= c.legal);
    try expect(c.canonical <= c.legal);
    // layer counts must sum to the total
    var sum: u64 = 0;
    for (c.legal_by_stones) |k| sum += k;
    try expect(sum == c.legal);
}

test "3x3: 12675 legal positions (published)" {
    const E = Enumerator(3, 3);
    const c = E.census();
    try expect(c.legal == 12_675);
    try expect(c.canonical * 16 >= c.legal);
}

test "legality: full board is illegal, single stone is legal" {
    const E = Enumerator(3, 3);
    const full = [_]i8{1} ** 9; // no liberties anywhere
    try expect(!E.is_legal(&full));
    var one = [_]i8{0} ** 9;
    one[4] = 1;
    try expect(E.is_legal(&one));
    // black chain with its sole liberty filled by white, white alive: illegal
    // b b w      b group at 0,1 has liberties at 3,4 -> fill them
    const dead = [_]i8{
        1, 1, -1,
        -1, -1, 0,
        0, 0, 0,
    };
    try expect(!E.is_legal(&dead)); // 0,1 black chain: neighbours 2(w),3(w),4(w) -> no liberty
}

test "canonical: exactly one representative per symmetry class" {
    const E = Enumerator(2, 2);
    // all eight single-stone boards (4 cells x 2 colours) form ONE class under
    // dihedral x colour-inversion -> exactly one canonical representative.
    // (With lex order -1 < 0 < 1 the representative is a WHITE-stone board.)
    var count: u64 = 0;
    for (0..4) |p| {
        inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
            var b = [_]i8{0} ** 4;
            b[p] = colour;
            if (E.is_canonical(&b)) count += 1;
        }
    }
    try expect(count == 1);
    // colour inversion folds single-white into the same class as single-black
    var wboard = [_]i8{0} ** 4;
    wboard[0] = -1;
    var bboard = [_]i8{0} ** 4;
    bboard[0] = 1;
    // at most one of {black-at-0 class, white-at-0 class} may be canonical
    // (they are the same class under inversion)
    const both = E.is_canonical(&wboard) and E.is_canonical(&bboard);
    try expect(!both);
}

test "rectangular boards use the 4-element symmetry group" {
    const E = Enumerator(3, 2);
    try expect(E.num_syms == 4);
    const c = E.census();
    try expect(c.raw == 729); // 3^6
    try expect(c.legal > 0 and c.legal < c.raw);
    // class sizes bounded by 4 syms x 2 colours = 8
    try expect(c.canonical * 8 >= c.legal);
}
