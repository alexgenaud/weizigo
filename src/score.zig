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
// BOARD-SNAPSHOT SCORING — pure geometry, no oracle, no history.
//
// Provides Chinese area, Japanese-style territory, dame (no-man's-land)
// regions, and a conservative dead-stone estimate for a single board
// snapshot.  Every public claim is tagged PROVEN, CLAIMED, or CLAIMED heuristic
// in its doc comment; this module does NOT consult the oracle/fresh-start
// table.

const std = @import("std");
const rules = @import("rules.zig");

/// Pure board-snapshot scoring namespace for a fixed board size.
/// All returned values are Black-positive; side-to-move is irrelevant.
///
/// **Epistemic scope:** PROVEN functions depend only on Benson's life theorem
/// (already validated in `rules.zig`) and pure graph reachability on the
/// snapshot.  CLAIMED functions state their caveat explicitly.  None of this
/// is influenced by the oracle's fresh-start / GHI caveats.
pub fn Score(comptime w: usize, comptime h: usize) type {
    return struct {
        const R = rules.Rules(w, h);
        pub const n = R.n;
        pub const Pos = R.Pos;

        /// A maximal 4-connected empty region that touches both colours.
        pub const DameRegions = struct {
            /// Number of dame points (valid entries in `points`).
            count: usize,
            /// Point indices of every dame point, in discovery order.
            /// Only `points[0..count]` is meaningful.
            points: [n]usize,
        };

        /// Japanese-style territory: surrounded empty points only.
        /// Stones are not counted and dead stones are not removed.
        pub const Territory = struct {
            black: i8,
            white: i8,
        };

        /// Conservative dead-stone estimate.  `dead_black`/`dead_white` list the
        /// point indices of chains classified as dead; `contested` counts
        /// non-Benson-alive chains that are NOT provably dead.
        pub const DeadStoneEstimate = struct {
            dead_black: [n]usize,
            dead_black_count: usize,
            dead_white: [n]usize,
            dead_white_count: usize,
            contested: usize,
        };

        /// Full report used by the GTP surface.
        pub const ScoreReport = struct {
            area: i8,
            territory: Territory,
            dame: DameRegions,
            dead: DeadStoneEstimate,
            definitive: bool,
        };

        /// Chinese/area score: thin wrapper over `rules.Rules.area_score`.
        /// **PROVEN.**
        pub fn chinese_area(board: *const Pos) i8 {
            return R.area_score(board);
        }

        /// True iff the snapshot is decided-terminal (all stones
        /// Benson-alive and every empty region is owned territory).
        /// **PROVEN.**
        pub fn is_definitive(board: *const Pos) bool {
            return R.is_settled(board);
        }

        /// Enumerate all dame points: empty points in regions touching both
        /// Black and White stones.  **PROVEN.**
        pub fn dame_regions(board: *const Pos) DameRegions {
            var visited = [_]bool{false} ** n;
            var out = DameRegions{ .count = 0, .points = undefined };
            for (0..n) |p| {
                if (board[p] != 0 or visited[p]) continue;
                var stack: [n]usize = undefined;
                var sp: usize = 1;
                stack[0] = p;
                visited[p] = true;
                var size: usize = 0;
                var touches_black = false;
                var touches_white = false;
                var region_points: [n]usize = undefined;
                while (sp > 0) {
                    sp -= 1;
                    const q = stack[sp];
                    region_points[size] = q;
                    size += 1;
                    var nb: [4]usize = undefined;
                    const cnt = R.neighbors(q, &nb);
                    for (nb[0..cnt]) |r| {
                        if (board[r] > 0) touches_black = true;
                        if (board[r] < 0) touches_white = true;
                        if (board[r] == 0 and !visited[r]) {
                            visited[r] = true;
                            stack[sp] = r;
                            sp += 1;
                        }
                    }
                }
                if (touches_black and touches_white) {
                    @memcpy(out.points[out.count .. out.count + size], region_points[0..size]);
                    out.count += size;
                }
            }
            return out;
        }

        /// Japanese-style territory: surrounded empty regions only.
        ///
        /// - Regions touching exactly one colour are added to that colour's
        ///   territory.
        /// - Regions touching both colours or neither colour are neutral.
        /// - Stones are NOT counted and dead stones are NOT removed.
        ///
        /// This is intentionally a lower-ish/unsafe territory number; full
        /// Japanese scoring (dead-stone removal) requires a stronger life
        /// estimator.  **CLAIMED.**
        pub fn territory_japanese(board: *const Pos) Territory {
            var visited = [_]bool{false} ** n;
            var black: i16 = 0;
            var white: i16 = 0;
            for (0..n) |p| {
                if (board[p] != 0 or visited[p]) continue;
                var stack: [n]usize = undefined;
                var sp: usize = 1;
                stack[0] = p;
                visited[p] = true;
                var size: i16 = 0;
                var touches_black = false;
                var touches_white = false;
                while (sp > 0) {
                    sp -= 1;
                    const q = stack[sp];
                    size += 1;
                    var nb: [4]usize = undefined;
                    const cnt = R.neighbors(q, &nb);
                    for (nb[0..cnt]) |r| {
                        if (board[r] > 0) touches_black = true;
                        if (board[r] < 0) touches_white = true;
                        if (board[r] == 0 and !visited[r]) {
                            visited[r] = true;
                            stack[sp] = r;
                            sp += 1;
                        }
                    }
                }
                if (touches_black and !touches_white) black += size;
                if (touches_white and !touches_black) white += size;
            }
            return Territory{
                .black = @intCast(black),
                .white = @intCast(white),
            };
        }

        /// Conservative dead-stone estimate.
        ///
        /// A chain is reported `dead` only if:
        ///   1. it is NOT Benson-alive, and
        ///   2. every one of its liberty regions is dominated by an enemy
        ///      Benson-alive group — i.e. the only non-empty neighbours of the
        ///      region are enemy Benson-alive stones (apart from the chain
        ///      itself).  Ambiguous chains are reported as `contested`.
        ///
        /// This deliberately under-claims: groups in a capturing race, one-eye
        /// groups, and groups with shared liberties are all `contested`.
        /// **CLAIMED heuristic.**
        pub fn dead_stone_estimate(board: *const Pos) DeadStoneEstimate {
            var out = DeadStoneEstimate{
                .dead_black = undefined,
                .dead_black_count = 0,
                .dead_white = undefined,
                .dead_white_count = 0,
                .contested = 0,
            };

            // Pre-compute chain labels and Benson flags for both colours.
            const black_chains = label_chains(board, 1);
            const white_chains = label_chains(board, -1);
            const black_alive = R.benson_alive(board, 1);
            const white_alive = R.benson_alive(board, -1);

            // Analyse each colour independently.  Dead for Black means
            // dominated by White Benson-alive stones, and vice versa.
            inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
                const friendly_label = if (colour == 1) black_chains else white_chains;
                const enemy_label = if (colour == 1) white_chains else black_chains;
                const friendly_alive = if (colour == 1) black_alive else white_alive;
                const enemy_alive_arr = if (colour == 1) white_alive else black_alive;

                if (friendly_label.num_chains > 0) {
                    // Per-chain alive flag: if any stone of the chain is
                    // Benson-alive, the whole chain is alive.
                    var chain_alive = [_]bool{false} ** n;
                    for (0..n) |p| {
                        const cid = friendly_label.id[p];
                        if (cid >= 0 and friendly_alive[p]) chain_alive[@intCast(cid)] = true;
                    }

                    // 2. label empty regions and record which chains touch them
                    const region_label = label_empty_regions(board);
                    var region_enemy_mask = [_]u32{0} ** n; // bitset of enemy chain ids
                    var region_friendly_mask = [_]u32{0} ** n; // bitset of `colour` chain ids
                    var region_has_enemy = [_]bool{false} ** n;
                    var region_empty_count = [_]usize{0} ** n;
                    {
                        var rvisited = [_]bool{false} ** n;
                        for (0..n) |p| {
                            if (board[p] != 0 or rvisited[p]) continue;
                            var stack: [n]usize = undefined;
                            var sp: usize = 1;
                            stack[0] = p;
                            rvisited[p] = true;
                            const rid: usize = @intCast(region_label.id[p]);
                            while (sp > 0) {
                                sp -= 1;
                                const q = stack[sp];
                                region_empty_count[rid] += 1;
                                var nb: [4]usize = undefined;
                                const cnt = R.neighbors(q, &nb);
                                for (nb[0..cnt]) |r| {
                                    if (board[r] * colour > 0) {
                                        region_friendly_mask[rid] |= bit(@intCast(friendly_label.id[r]));
                                    } else if (board[r] * colour < 0) {
                                        region_enemy_mask[rid] |= bit(@intCast(enemy_label.id[r]));
                                        region_has_enemy[rid] = true;
                                    } else if (!rvisited[r]) {
                                        rvisited[r] = true;
                                        stack[sp] = r;
                                        sp += 1;
                                    }
                                }
                            }
                        }
                    }

                    // 3. For each non-alive chain, check every liberty region.
                    // A liberty region of chain `c` is an empty region whose
                    // friendly-mask contains bit `c`.
                    var c: usize = 0;
                    while (c < friendly_label.num_chains) : (c += 1) {
                        if (chain_alive[c]) continue;
                        const cmask = bit(@intCast(c));
                        var all_dominated = true;
                        for (0..n) |p| {
                            const rid_i = region_label.id[p];
                            if (rid_i < 0) continue;
                            const rid: usize = @intCast(rid_i);
                            if (region_empty_count[rid] == 0) continue;
                            if (region_friendly_mask[rid] & cmask == 0) continue; // not a liberty of this chain

                            // Dominated iff:
                            //   - region touches at least one enemy stone, AND
                            //   - the only friendly stones touching it are this chain, AND
                            //   - every enemy stone touching it is Benson-alive.
                            if (!region_has_enemy[rid]) {
                                all_dominated = false;
                                break;
                            }
                            if (region_friendly_mask[rid] != cmask) {
                                all_dominated = false;
                                break;
                            }
                            if (!all_enemy_alive(region_enemy_mask[rid], enemy_alive_arr, enemy_label)) {
                                all_dominated = false;
                                break;
                            }
                        }
                        if (all_dominated) {
                            // record every stone of this chain in the appropriate list
                            for (0..n) |p| {
                                if (friendly_label.id[p] == @as(i16, @intCast(c))) {
                                    if (colour == 1) {
                                        out.dead_black[out.dead_black_count] = p;
                                        out.dead_black_count += 1;
                                    } else {
                                        out.dead_white[out.dead_white_count] = p;
                                        out.dead_white_count += 1;
                                    }
                                }
                            }
                        } else {
                            out.contested += 1;
                        }
                    }
                }
            }
            return out;
        }

        /// Assemble a complete report for a snapshot.
        /// All constituent functions are tagged above; the report itself is a
        /// pure composition.  **PROVEN / CLAIMED composition.**
        pub fn make_report(board: *const Pos) ScoreReport {
            return ScoreReport{
                .area = chinese_area(board),
                .territory = territory_japanese(board),
                .dame = dame_regions(board),
                .dead = dead_stone_estimate(board),
                .definitive = is_definitive(board),
            };
        }

        // ----------------------------------------------------------------
        // internal helpers
        // ----------------------------------------------------------------

        fn bit(i: u5) u32 {
            return @as(u32, 1) << i;
        }

        /// Returns true iff every enemy chain whose bit is set in `mask` is
        /// Benson-alive.
        fn all_enemy_alive(mask: u32, enemy_alive: [n]bool, chain_label: anytype) bool {
            var m = mask;
            while (m != 0) {
                const b = @ctz(m);
                const cid: usize = b;
                // find any stone of that enemy chain and check its alive flag
                var found = false;
                for (0..n) |p| {
                    if (chain_label.id[p] == @as(i16, @intCast(cid))) {
                        if (!enemy_alive[p]) return false;
                        found = true;
                        break;
                    }
                }
                if (!found) return false;
                m &= m - 1; // clear lowest set bit
            }
            return true;
        }

        const ChainLabel = struct {
            id: [n]i16,
            num_chains: usize,
        };

        /// Label connected components of `colour` stones.
        fn label_chains(board: *const Pos, colour: i8) ChainLabel {
            var id = [_]i16{-1} ** n;
            var num: usize = 0;
            var visited = [_]bool{false} ** n;
            for (0..n) |p| {
                if (board[p] * colour <= 0 or visited[p]) continue;
                const this_id: i16 = @intCast(num);
                num += 1;
                var stack: [n]usize = undefined;
                var sp: usize = 1;
                stack[0] = p;
                visited[p] = true;
                while (sp > 0) {
                    sp -= 1;
                    const q = stack[sp];
                    id[q] = this_id;
                    var nb: [4]usize = undefined;
                    const cnt = R.neighbors(q, &nb);
                    for (nb[0..cnt]) |r| {
                        if (board[r] * colour > 0 and !visited[r]) {
                            visited[r] = true;
                            stack[sp] = r;
                            sp += 1;
                        }
                    }
                }
            }
            return ChainLabel{ .id = id, .num_chains = num };
        }

        const RegionLabel = struct {
            id: [n]i16,
            num_regions: usize,
        };

        /// Label connected components of empty points.
        fn label_empty_regions(board: *const Pos) RegionLabel {
            var id = [_]i16{-1} ** n;
            var num: usize = 0;
            var visited = [_]bool{false} ** n;
            for (0..n) |p| {
                if (board[p] != 0 or visited[p]) continue;
                const this_id: i16 = @intCast(num);
                num += 1;
                var stack: [n]usize = undefined;
                var sp: usize = 1;
                stack[0] = p;
                visited[p] = true;
                while (sp > 0) {
                    sp -= 1;
                    const q = stack[sp];
                    id[q] = this_id;
                    var nb: [4]usize = undefined;
                    const cnt = R.neighbors(q, &nb);
                    for (nb[0..cnt]) |r| {
                        if (board[r] == 0 and !visited[r]) {
                            visited[r] = true;
                            stack[sp] = r;
                            sp += 1;
                        }
                    }
                }
            }
            return RegionLabel{ .id = id, .num_regions = num };
        }
    };
}

// ---- tests ------------------------------------------------------------------

const expect = std.testing.expect;

test "empty board: no dame, no territory, not definitive" {
    const S = Score(3, 3);
    const b = [_]i8{0} ** 9;
    const dame = S.dame_regions(&b);
    try expect(dame.count == 0);
    const terr = S.territory_japanese(&b);
    try expect(terr.black == 0 and terr.white == 0);
    try expect(!S.is_definitive(&b));
    try expect(S.chinese_area(&b) == 0);
}

test "settled 3x3 middle column: definitive, no dame, territory matches area" {
    const S = Score(3, 3);
    // Black column in the centre (colex indices: 1,4,7).  Benson alive.
    const b = [_]i8{
        0, 1, 0,
        0, 1, 0,
        0, 1, 0,
    };
    try expect(S.is_definitive(&b));
    try expect(S.chinese_area(&b) == 9);
    const dame = S.dame_regions(&b);
    try expect(dame.count == 0);
    const terr = S.territory_japanese(&b);
    try expect(terr.black == 6); // left+right empty columns
    try expect(terr.white == 0);
}

test "obvious dame: shared empty region" {
    const S = Score(3, 3);
    // Black at 0, White at 1; every empty point is 4-connected to the rest
    // of the board and the region touches both colours, so all 7 empty points
    // are dame.
    const b = [_]i8{
        1, -1, 0,
        0, 0,  0,
        0, 0,  0,
    };
    const dame = S.dame_regions(&b);
    try expect(dame.count == 7);
}

test "dead stone: lone white stone surrounded by black Benson-alive wall" {
    const S = Score(3, 3);
    // Black ring around the centre: cells 1,3,4,5,7 are black with two eyes
    // at 0 and 8 (and at 2,6? actually 4 is centre black too).  White plays
    // into the centre (cell 4)? No — centre is part of the black group.
    // Instead, place White at the very centre of a 3x3 black-filled board
    // with eyes.  Board:
    //   . X .
    //   X O X
    //   . X .
    // White at 4 has a single liberty region (0,2,6,8 connected via edges).
    // That region is dominated by the surrounding Black Benson-alive group.
    const b = [_]i8{
        0, 1, 0,
        1, -1, 1,
        0, 1, 0,
    };
    const dead = S.dead_stone_estimate(&b);
    // White chain is not Benson-alive; its only liberty region touches only
    // the White chain and the Black Benson-alive ring.
    try expect(dead.dead_white_count == 1);
    try expect(dead.dead_black_count == 0);
    try expect(dead.contested == 0);
}

test "one-eye group is contested, not dead" {
    const S = Score(3, 3);
    // Black ring with a single empty eye in the centre.  Not Benson-alive
    // (needs two vital regions) and the one liberty region is not dominated
    // by any enemy Benson-alive group.
    const b = [_]i8{
        1, 1, 1,
        1, 0, 1,
        1, 1, 1,
    };
    const dead = S.dead_stone_estimate(&b);
    try expect(dead.dead_black_count == 0);
    try expect(dead.dead_white_count == 0);
    try expect(dead.contested == 1); // the one-eye Black chain is contested
}

test "Benson-alive chain is not dead nor contested" {
    const S = Score(3, 3);
    // Black vertical column in the centre is Benson-alive; surrounding empty
    // regions are Black territory.
    const b = [_]i8{
        0, 1, 0,
        0, 1, 0,
        0, 1, 0,
    };
    const dead = S.dead_stone_estimate(&b);
    try expect(dead.dead_black_count == 0);
    try expect(dead.dead_white_count == 0);
    try expect(dead.contested == 0);
}
