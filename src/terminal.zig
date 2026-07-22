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
// Terminal detection and scoring (see docs/decisions/0004).
//
//   area_score  - Chinese / area score of a snapshot (Tromp-Taylor style):
//                 black_area - white_area. Assumes on-board stones are alive
//                 (dead stones are removed by prior play). Pure function.
//   pass_alive  - Benson's algorithm: which stones of `color` are
//                 UNCONDITIONALLY alive (cannot be captured even if the
//                 defender always passes). Pure function.
//   is_settled  - conservative terminal test: all stones pass-alive and every
//                 empty region is one colour's eye (no dame, no dead stones).
//
// Input boards use sign for colour (>0 black, <0 white, 0 empty); army-flag
// magnitudes are ignored, so raw +/-1 boards and armies() output both work.

const std = @import("std");
const expect = std.testing.expect;

fn neighbors(p: usize, buf: *[4]usize) usize {
    var n: usize = 0;
    const row = p / 5;
    const col = p % 5;
    if (row > 0) {
        buf[n] = p - 5;
        n += 1;
    }
    if (row < 4) {
        buf[n] = p + 5;
        n += 1;
    }
    if (col > 0) {
        buf[n] = p - 1;
        n += 1;
    }
    if (col < 4) {
        buf[n] = p + 1;
        n += 1;
    }
    return n;
}

/// Chinese / area score: black points minus white points. A point counts for
/// a colour if it holds that colour's stone, or is empty and its empty region
/// reaches only that colour. Komi is applied by the caller.
pub fn area_score(board: *const [25]i8) i8 {
    var black: i16 = 0;
    var white: i16 = 0;
    var visited = [_]bool{false} ** 25;
    for (0..25) |p| {
        if (board[p] > 0) {
            black += 1;
            continue;
        }
        if (board[p] < 0) {
            white += 1;
            continue;
        }
        if (visited[p]) continue;
        // flood the empty region, recording which colours it touches
        var stack: [25]usize = undefined;
        var sp: usize = 0;
        stack[0] = p;
        sp = 1;
        visited[p] = true;
        var size: i16 = 0;
        var touches_black = false;
        var touches_white = false;
        while (sp > 0) {
            sp -= 1;
            const q = stack[sp];
            size += 1;
            var nb: [4]usize = undefined;
            const cnt = neighbors(q, &nb);
            for (nb[0..cnt]) |r| {
                if (board[r] > 0) {
                    touches_black = true;
                } else if (board[r] < 0) {
                    touches_white = true;
                } else if (!visited[r]) {
                    visited[r] = true;
                    stack[sp] = r;
                    sp += 1;
                }
            }
        }
        if (touches_black and !touches_white) black += size;
        if (touches_white and !touches_black) white += size;
        // touching both (dame) or neither (bare board) is neutral
    }
    return @intCast(black - white);
}

/// Benson's algorithm: returns, per intersection, whether the stone of `color`
/// there is unconditionally alive (pass-alive). Non-`color` points are false.
pub fn pass_alive(board: *const [25]i8, color: i8) [25]bool {
    var alive = [_]bool{false} ** 25;

    // 1. label friendly chains
    var chain_id = [_]i8{-1} ** 25;
    var num_chains: u8 = 0;
    {
        var visited = [_]bool{false} ** 25;
        for (0..25) |p| {
            if (board[p] * color <= 0 or visited[p]) continue;
            const id = num_chains;
            num_chains += 1;
            var stack: [25]usize = undefined;
            var sp: usize = 0;
            stack[0] = p;
            sp = 1;
            visited[p] = true;
            while (sp > 0) {
                sp -= 1;
                const q = stack[sp];
                chain_id[q] = @intCast(id);
                var nb: [4]usize = undefined;
                const cnt = neighbors(q, &nb);
                for (nb[0..cnt]) |r| {
                    if (board[r] * color > 0 and !visited[r]) {
                        visited[r] = true;
                        stack[sp] = r;
                        sp += 1;
                    }
                }
            }
        }
    }
    if (num_chains == 0) return alive;

    // 2. label regions = connected components of non-friendly points
    var region_id = [_]i8{-1} ** 25;
    var num_regions: u8 = 0;
    {
        var visited = [_]bool{false} ** 25;
        for (0..25) |p| {
            if (board[p] * color > 0 or visited[p]) continue;
            const id = num_regions;
            num_regions += 1;
            var stack: [25]usize = undefined;
            var sp: usize = 0;
            stack[0] = p;
            sp = 1;
            visited[p] = true;
            while (sp > 0) {
                sp -= 1;
                const q = stack[sp];
                region_id[q] = @intCast(id);
                var nb: [4]usize = undefined;
                const cnt = neighbors(q, &nb);
                for (nb[0..cnt]) |r| {
                    if (board[r] * color <= 0 and !visited[r]) {
                        visited[r] = true;
                        stack[sp] = r;
                        sp += 1;
                    }
                }
            }
        }
    }

    // 3. per region: which chains border it, and how many of its empty points
    //    are adjacent to each chain (for vitality)
    var region_empty = [_]u8{0} ** 25; // empty points per region
    var borders = std.mem.zeroes([25][25]bool); // region x chain
    var empty_adj = std.mem.zeroes([25][25]u8); // region x chain: empty pts adjacent to chain
    for (0..25) |p| {
        const rid = region_id[p];
        if (rid < 0) continue;
        const ru: usize = @intCast(rid);
        var nb: [4]usize = undefined;
        const cnt = neighbors(p, &nb);
        if (board[p] == 0) {
            region_empty[ru] += 1;
            var seen = [_]bool{false} ** 25;
            for (nb[0..cnt]) |r| {
                if (board[r] * color > 0) {
                    const cid: usize = @intCast(chain_id[r]);
                    if (!seen[cid]) {
                        seen[cid] = true;
                        empty_adj[ru][cid] += 1;
                    }
                }
            }
        }
        for (nb[0..cnt]) |r| {
            if (board[r] * color > 0) borders[ru][@intCast(chain_id[r])] = true;
        }
    }

    // region r is vital to chain c iff it has >=1 empty point and ALL of them
    // are liberties of c
    var vital = std.mem.zeroes([25][25]bool);
    for (0..num_regions) |ru| {
        if (region_empty[ru] == 0) continue;
        for (0..num_chains) |cu| {
            if (empty_adj[ru][cu] == region_empty[ru]) vital[ru][cu] = true;
        }
    }

    // 4. Benson fixpoint
    var chain_in = [_]bool{true} ** 25;
    var region_in = [_]bool{true} ** 25;
    var changed = true;
    while (changed) {
        changed = false;
        for (0..num_chains) |cu| {
            if (!chain_in[cu]) continue;
            var vcount: u8 = 0;
            for (0..num_regions) |ru| {
                if (region_in[ru] and vital[ru][cu]) vcount += 1;
            }
            if (vcount < 2) {
                chain_in[cu] = false;
                changed = true;
            }
        }
        for (0..num_regions) |ru| {
            if (!region_in[ru]) continue;
            for (0..num_chains) |cu| {
                if (borders[ru][cu] and !chain_in[cu]) {
                    region_in[ru] = false;
                    changed = true;
                    break;
                }
            }
        }
    }

    for (0..25) |p| {
        if (board[p] * color > 0 and chain_in[@intCast(chain_id[p])]) alive[p] = true;
    }
    return alive;
}

/// Unconditional (Benson) terminal test: the position is *decided* — its area
/// score cannot change no matter how the opponent plays, even against a passing
/// defender. Requires:
///   1. every stone is pass-alive for its colour, AND
///   2. every empty region touches exactly one colour (no dame), AND
///   3. every empty point has a stone neighbour (it is eye-space of the
///      surrounding immortal group, not open territory).
///
/// (3) is the crucial one, and the difference from mere Tromp-Taylor scoring: a
/// large empty region touching only Black still is NOT Black's unless Black
/// actually walls every point of it. Any empty point with no stone neighbour is
/// interior space the opponent could invade and make eyes in (Benson proves the
/// *stones* immortal, not the *territory*). If (3) held only under alternating
/// play, the search resolves it via its double-pass terminal instead.
/// See docs/research/terminal-territory-bug.md.
pub fn is_settled(board: *const [25]i8) bool {
    const balive = pass_alive(board, 1);
    const walive = pass_alive(board, -1);
    for (0..25) |p| {
        if (board[p] > 0 and !balive[p]) return false;
        if (board[p] < 0 and !walive[p]) return false;
    }
    var visited = [_]bool{false} ** 25;
    for (0..25) |p| {
        if (board[p] != 0 or visited[p]) continue;
        var stack: [25]usize = undefined;
        var sp: usize = 0;
        stack[0] = p;
        sp = 1;
        visited[p] = true;
        var touches_black = false;
        var touches_white = false;
        while (sp > 0) {
            sp -= 1;
            const q = stack[sp];
            var nb: [4]usize = undefined;
            const cnt = neighbors(q, &nb);
            var stone_nbr = false;
            for (nb[0..cnt]) |r| {
                if (board[r] > 0) {
                    touches_black = true;
                    stone_nbr = true;
                } else if (board[r] < 0) {
                    touches_white = true;
                    stone_nbr = true;
                } else if (!visited[r]) {
                    visited[r] = true;
                    stack[sp] = r;
                    sp += 1;
                }
            }
            // (3): an empty point with no stone neighbour is uncontrolled space
            // -> the opponent could invade and live -> not a decided terminal.
            if (!stone_nbr) return false;
        }
        if (touches_black == touches_white) return false; // dame, or bare board
    }
    return true;
}

// ---- tests ------------------------------------------------------------------

test "area score: empty, full, single stone" {
    try expect(area_score(&[_]i8{0} ** 25) == 0);
    try expect(area_score(&[_]i8{1} ** 25) == 25);
    try expect(area_score(&[_]i8{-1} ** 25) == -25);
    // one black stone owns the whole board under area scoring
    var one = [_]i8{0} ** 25;
    one[0] = 1;
    try expect(area_score(&one) == 25);
}

test "area score: split board and dame" {
    const W: i8 = -1;
    // black corner vs white corner, rest empty -> region touches both = neutral
    var split = [_]i8{0} ** 25;
    split[0] = 1;
    split[24] = W;
    try expect(area_score(&split) == 0);

    // a black wall down the middle column splits the board
    const wall = [_]i8{
        0, 0, 1, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 1, 0, 0,
        0, 0, 1, 0, 0,
    };
    // no white anywhere -> every empty region touches only black -> all 25 black
    try expect(area_score(&wall) == 25);
}

test "benson: two-eye group is pass-alive" {
    const g = [_]i8{
        1, 1, 1, 1, 1,
        1, 0, 1, 0, 1,
        1, 1, 1, 1, 1,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
    };
    const alive = pass_alive(&g, 1);
    for (0..15) |p| {
        if (g[p] == 1) try expect(alive[p]);
    }
}

test "benson: one-eye group and lone stone are not alive" {
    const one_eye = [_]i8{
        1, 1, 1, 0, 0,
        1, 0, 1, 0, 0,
        1, 1, 1, 0, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
    };
    const a = pass_alive(&one_eye, 1);
    for (0..25) |p| try expect(!a[p]); // single eye -> capturable -> not alive

    var lone = [_]i8{0} ** 25;
    lone[12] = 1;
    const b = pass_alive(&lone, 1);
    for (0..25) |p| try expect(!b[p]);
}

test "settled requires eye-space, not just Benson-alive stones" {
    // Two real eyes make the STONES immortal, but the bottom two rows are open
    // territory: if Black passes, White invades and lives there. NOT decided.
    const open = [_]i8{
        1, 1, 1, 1, 1,
        1, 0, 1, 0, 1,
        1, 1, 1, 1, 1,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
    };
    try expect(!is_settled(&open));

    // Black actually owning the whole board (every empty point is eye-space
    // adjacent to the immortal group) IS decided.
    const owned = [_]i8{
        1, 1, 1, 1, 1,
        1, 0, 1, 0, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
        1, 1, 1, 1, 1,
    };
    try expect(is_settled(&owned));
    try expect(area_score(&owned) == 25);
}

test "not settled: a live group on a wide-open board" {
    // 6 stones, two eyes (A1,C1), rest of the board empty. Benson says the
    // stones live, but is_settled must NOT call this decided -- White can invade
    // the open space and live. (This is the census's spurious "6-stone terminal";
    // see docs/research/terminal-territory-bug.md.)
    const wide = [_]i8{
        0, 1, 0, 1, 0,
        1, 1, 1, 1, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
    };
    try expect(!is_settled(&wide));
}

test "benson: works for white too (colour symmetry)" {
    const W: i8 = -1;
    const g = [_]i8{
        W, W, W, W, W,
        W, 0, W, 0, W,
        W, W, W, W, W,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
    };
    const alive = pass_alive(&g, -1);
    for (0..15) |p| {
        if (g[p] == W) try expect(alive[p]);
    }
    try expect(area_score(&g) == -25);
}

test "scoring/benson ignore army-flag magnitudes" {
    // same shape as the two-eye test but with arbitrary positive flags
    const g = [_]i8{
        1, 2, 3, 2, 1,
        4, 0, 5, 0, 6,
        1, 1, 7, 1, 1,
        0, 0, 0, 0, 0,
        0, 0, 0, 0, 0,
    };
    try expect(area_score(&g) == 25);
    const alive = pass_alive(&g, 1);
    for (0..15) |p| {
        if (g[p] > 0) try expect(alive[p]);
    }
}

test "not settled: dead stone / contested" {
    const W: i8 = -1;
    // black two-eye group plus a lone white stone that is not alive -> not settled
    const g = [_]i8{
        1, 1, 1, 1, 1,
        1, 0, 1, 0, 1,
        1, 1, 1, 1, 1,
        0, 0, 0, 0, W,
        0, 0, 0, 0, 0,
    };
    try expect(!is_settled(&g)); // the white stone is not pass-alive
}
