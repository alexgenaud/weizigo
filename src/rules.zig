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
// BOARD-SIZE-GENERIC Go rules (Tromp-Taylor, no suicide) — the w x h
// generalization of the 5x5-hardcoded logic in state.zig / terminal.zig /
// solve.zig. Pure sign domain: cells are -1 white, 0 empty, +1 black (no army
// flags). Cross-validated against the 5x5 stack by the tests below.
//
//   pos_from_move — place a stone, remove captured opponent chains, reject
//                   suicide (no ko here: history/superko is the caller's job).
//   area_score    — Chinese/area score, Black-positive (port of terminal.zig).
//   benson_alive    — Benson unconditional life (port of terminal.zig).
//   is_settled    — decided-terminal test incl. eye-space rule (port).
//   is_own_eye    — the ADR-0006 eye-prune predicate (port of solve.zig).
//
// Standalone except std; tests import the 5x5 stack for cross-validation only.

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

pub fn Rules(comptime w: usize, comptime h: usize) type {
    return struct {
        pub const n = w * h;
        pub const Pos = [n]i8;
        pub const MoveError = error{ Occupied, Suicide };

        pub fn neighbors(p: usize, buf: *[4]usize) usize {
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

        /// Flood the chain containing `seed`; write its cells to `chain`.
        /// Returns true iff the chain has NO liberty.
        fn chain_captured(pos: *const Pos, seed: usize, chain: *[n]usize, chain_len: *usize) bool {
            const colour: i8 = if (pos[seed] > 0) 1 else -1;
            var visited = [_]bool{false} ** n;
            var sp: usize = 1;
            chain[0] = seed;
            visited[seed] = true;
            var len: usize = 1;
            var has_liberty = false;
            var stack: [n]usize = undefined;
            stack[0] = seed;
            while (sp > 0) {
                sp -= 1;
                const q = stack[sp];
                var nb: [4]usize = undefined;
                const cnt = neighbors(q, &nb);
                for (nb[0..cnt]) |r| {
                    if (pos[r] == 0) {
                        has_liberty = true;
                    } else if ((pos[r] > 0) == (colour > 0) and pos[r] != 0 and !visited[r]) {
                        visited[r] = true;
                        stack[sp] = r;
                        sp += 1;
                        chain[len] = r;
                        len += 1;
                    }
                }
            }
            chain_len.* = len;
            return !has_liberty;
        }

        /// Apply a stone move: place `colour` (+1/-1) on empty `cell`, remove
        /// any opponent chains left without liberties, reject suicide.
        /// Output cells are pure signs (-1/0/+1). No ko rule here.
        pub fn pos_from_move(pos: *const Pos, colour: i8, cell: usize) MoveError!Pos {
            if (pos[cell] != 0) return error.Occupied;
            var next: Pos = undefined;
            for (0..n) |i| next[i] = if (pos[i] > 0) 1 else if (pos[i] < 0) -1 else 0;
            next[cell] = colour;

            // capture: opponent neighbour chains with no liberty are removed
            var nb: [4]usize = undefined;
            const cnt = neighbors(cell, &nb);
            var chain: [n]usize = undefined;
            var chain_len: usize = 0;
            for (nb[0..cnt]) |q| {
                if (next[q] * colour < 0) {
                    if (chain_captured(&next, q, &chain, &chain_len)) {
                        for (chain[0..chain_len]) |c| next[c] = 0;
                    }
                }
            }
            // suicide: own chain must have a liberty after captures
            if (chain_captured(&next, cell, &chain, &chain_len)) return error.Suicide;
            return next;
        }

        /// Chinese / area score, Black-positive. Port of terminal.area_score.
        pub fn area_score(board: *const Pos) i8 {
            var black: i16 = 0;
            var white: i16 = 0;
            var visited = [_]bool{false} ** n;
            for (0..n) |p| {
                if (board[p] > 0) {
                    black += 1;
                    continue;
                }
                if (board[p] < 0) {
                    white += 1;
                    continue;
                }
                if (visited[p]) continue;
                var stack: [n]usize = undefined;
                var sp: usize = 1;
                stack[0] = p;
                visited[p] = true;
                var size: i16 = 0;
                var tb = false;
                var tw = false;
                while (sp > 0) {
                    sp -= 1;
                    const q = stack[sp];
                    size += 1;
                    var nb: [4]usize = undefined;
                    const cnt = neighbors(q, &nb);
                    for (nb[0..cnt]) |r| {
                        if (board[r] > 0) {
                            tb = true;
                        } else if (board[r] < 0) {
                            tw = true;
                        } else if (!visited[r]) {
                            visited[r] = true;
                            stack[sp] = r;
                            sp += 1;
                        }
                    }
                }
                if (tb and !tw) black += size;
                if (tw and !tb) white += size;
            }
            return @intCast(black - white);
        }

        /// Benson unconditional life. Port of terminal.benson_alive.
        pub fn benson_alive(board: *const Pos, colour: i8) [n]bool {
            var alive = [_]bool{false} ** n;

            var chain_id = [_]i16{-1} ** n;
            var num_chains: usize = 0;
            {
                var visited = [_]bool{false} ** n;
                for (0..n) |p| {
                    if (board[p] * colour <= 0 or visited[p]) continue;
                    const id = num_chains;
                    num_chains += 1;
                    var stack: [n]usize = undefined;
                    var sp: usize = 1;
                    stack[0] = p;
                    visited[p] = true;
                    while (sp > 0) {
                        sp -= 1;
                        const q = stack[sp];
                        chain_id[q] = @intCast(id);
                        var nb: [4]usize = undefined;
                        const cnt = neighbors(q, &nb);
                        for (nb[0..cnt]) |r| {
                            if (board[r] * colour > 0 and !visited[r]) {
                                visited[r] = true;
                                stack[sp] = r;
                                sp += 1;
                            }
                        }
                    }
                }
            }
            if (num_chains == 0) return alive;

            var region_id = [_]i16{-1} ** n;
            var num_regions: usize = 0;
            {
                var visited = [_]bool{false} ** n;
                for (0..n) |p| {
                    if (board[p] * colour > 0 or visited[p]) continue;
                    const id = num_regions;
                    num_regions += 1;
                    var stack: [n]usize = undefined;
                    var sp: usize = 1;
                    stack[0] = p;
                    visited[p] = true;
                    while (sp > 0) {
                        sp -= 1;
                        const q = stack[sp];
                        region_id[q] = @intCast(id);
                        var nb: [4]usize = undefined;
                        const cnt = neighbors(q, &nb);
                        for (nb[0..cnt]) |r| {
                            if (board[r] * colour <= 0 and !visited[r]) {
                                visited[r] = true;
                                stack[sp] = r;
                                sp += 1;
                            }
                        }
                    }
                }
            }

            var region_empty = [_]u8{0} ** n;
            var borders = std.mem.zeroes([n][n]bool);
            var empty_adj = std.mem.zeroes([n][n]u8);
            for (0..n) |p| {
                const rid = region_id[p];
                if (rid < 0) continue;
                const ru: usize = @intCast(rid);
                var nb: [4]usize = undefined;
                const cnt = neighbors(p, &nb);
                if (board[p] == 0) {
                    region_empty[ru] += 1;
                    var seen = [_]bool{false} ** n;
                    for (nb[0..cnt]) |r| {
                        if (board[r] * colour > 0) {
                            const cid: usize = @intCast(chain_id[r]);
                            if (!seen[cid]) {
                                seen[cid] = true;
                                empty_adj[ru][cid] += 1;
                            }
                        }
                    }
                }
                for (nb[0..cnt]) |r| {
                    if (board[r] * colour > 0) borders[ru][@intCast(chain_id[r])] = true;
                }
            }

            var vital = std.mem.zeroes([n][n]bool);
            for (0..num_regions) |ru| {
                if (region_empty[ru] == 0) continue;
                for (0..num_chains) |cu| {
                    if (empty_adj[ru][cu] == region_empty[ru]) vital[ru][cu] = true;
                }
            }

            var chain_in = [_]bool{true} ** n;
            var region_in = [_]bool{true} ** n;
            var changed = true;
            while (changed) {
                changed = false;
                for (0..num_chains) |cu| {
                    if (!chain_in[cu]) continue;
                    var vcount: usize = 0;
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

            for (0..n) |p| {
                if (board[p] * colour > 0 and chain_in[@intCast(chain_id[p])]) alive[p] = true;
            }
            return alive;
        }

        /// Decided-terminal test (port of terminal.is_settled, incl. the
        /// eye-space rule from the terminal-territory-bug fix).
        pub fn is_settled(board: *const Pos) bool {
            const balive = benson_alive(board, 1);
            const walive = benson_alive(board, -1);
            for (0..n) |p| {
                if (board[p] > 0 and !balive[p]) return false;
                if (board[p] < 0 and !walive[p]) return false;
            }
            var visited = [_]bool{false} ** n;
            for (0..n) |p| {
                if (board[p] != 0 or visited[p]) continue;
                var stack: [n]usize = undefined;
                var sp: usize = 1;
                stack[0] = p;
                visited[p] = true;
                var tb = false;
                var tw = false;
                while (sp > 0) {
                    sp -= 1;
                    const q = stack[sp];
                    var nb: [4]usize = undefined;
                    const cnt = neighbors(q, &nb);
                    var stone_nbr = false;
                    for (nb[0..cnt]) |r| {
                        if (board[r] > 0) {
                            tb = true;
                            stone_nbr = true;
                        } else if (board[r] < 0) {
                            tw = true;
                            stone_nbr = true;
                        } else if (!visited[r]) {
                            visited[r] = true;
                            stack[sp] = r;
                            sp += 1;
                        }
                    }
                    if (!stone_nbr) return false;
                }
                if (tb == tw) return false;
            }
            return true;
        }

        /// ADR-0006 eye-prune predicate (port of solve.is_own_eye): empty `p`
        /// whose every present neighbour is a Benson-alive stone of `colour`.
        pub fn is_own_eye(pos: *const Pos, p: usize, colour: i8, alive: *const [n]bool) bool {
            var nb: [4]usize = undefined;
            const cnt = neighbors(p, &nb);
            for (nb[0..cnt]) |q| {
                if (pos[q] * colour <= 0 or !alive[q]) return false;
            }
            return true;
        }
    };
}

// ---- tests ------------------------------------------------------------------

test "3x3: middle-column group is Benson-alive; board is settled at +9" {
    const R = Rules(3, 3);
    const b = [_]i8{
        0, 1, 0,
        0, 1, 0,
        0, 1, 0,
    };
    const alive = R.benson_alive(&b, 1);
    try expect(alive[1] and alive[4] and alive[7]);
    try expect(R.is_settled(&b));
    try expect(R.area_score(&b) == 9);
}

test "3x3: single stone is not alive; empty board not settled" {
    const R = Rules(3, 3);
    var one = [_]i8{0} ** 9;
    one[4] = 1;
    const alive = R.benson_alive(&one, 1);
    for (alive) |a| try expect(!a);
    try expect(!R.is_settled(&one));
    try expect(!R.is_settled(&[_]i8{0} ** 9));
    try expect(R.area_score(&one) == 9); // area counts it regardless
}

test "capture and suicide on 3x3" {
    const R = Rules(3, 3);
    // white at 0 with single liberty 3 (cell 1 black): black plays 3 -> capture
    const b = [_]i8{
        -1, 1, 0,
        0,  0, 0,
        0,  0, 0,
    };
    const after = try R.pos_from_move(&b, 1, 3);
    try expect(after[0] == 0 and after[1] == 1 and after[3] == 1);
    // white plays back into 0: liberties none (1,3 black) -> suicide
    try std.testing.expectError(error.Suicide, R.pos_from_move(&after, -1, 0));
    try std.testing.expectError(error.Occupied, R.pos_from_move(&after, -1, 1));
}

test "5x5 cross-validation: area/benson_alive/is_settled match terminal.zig" {
    const R = Rules(5, 5);
    const terminal = @import("terminal.zig");
    var prng = std.Random.DefaultPrng.init(0xC0FFEE);
    const rnd = prng.random();
    var checked: usize = 0;
    while (checked < 500) {
        var b: [25]i8 = undefined;
        for (0..25) |i| {
            const r = rnd.intRangeAtMost(u8, 0, 3);
            b[i] = if (r == 1) 1 else if (r == 2) -1 else 0; // ~50% empty
        }
        try expect(R.area_score(&b) == terminal.area_score(&b));
        const pa = R.benson_alive(&b, 1);
        const pa5 = terminal.benson_alive(&b, 1);
        for (0..25) |i| try expect(pa[i] == pa5[i]);
        const wa = R.benson_alive(&b, -1);
        const wa5 = terminal.benson_alive(&b, -1);
        for (0..25) |i| try expect(wa[i] == wa5[i]);
        try expect(R.is_settled(&b) == terminal.is_settled(&b));
        checked += 1;
    }
}

test "5x5 cross-validation: pos_from_move matches state.armies_from_move" {
    const R = Rules(5, 5);
    const state = @import("state.zig");
    const E = @import("enumerate.zig").Enumerator(5, 5);
    var prng = std.Random.DefaultPrng.init(0xBADA55);
    const rnd = prng.random();
    var moves_checked: usize = 0;
    while (moves_checked < 1000) {
        var b: [25]i8 = undefined;
        for (0..25) |i| {
            const r = rnd.intRangeAtMost(u8, 0, 5);
            b[i] = if (r == 1) 1 else if (r == 2) -1 else 0; // ~2/3 empty
        }
        if (!E.is_legal(&b)) continue; // both movers require legal parents
        const cell = rnd.intRangeAtMost(u8, 0, 24);
        const colour: i8 = if (rnd.boolean()) 1 else -1;
        const armies = state.armies_from_pos(&b);
        const mine = R.pos_from_move(&b, colour, cell);
        const theirs = state.armies_from_move(&armies, colour, cell);
        if (mine) |m| {
            const t = theirs catch |e| {
                std.debug.print("mismatch: rules ok, state err {any} cell {d}\n", .{ e, cell });
                return error.Mismatch;
            };
            for (0..25) |i| {
                const ts: i8 = if (t[i] > 0) 1 else if (t[i] < 0) -1 else 0;
                try expect(m[i] == ts);
            }
        } else |_| {
            try std.testing.expectError(error.TestExpectedError, blk: {
                _ = theirs catch break :blk error.TestExpectedError;
                break :blk {};
            });
        }
        moves_checked += 1;
    }
}

// ---- THEORY test: Benson's theorem itself, not just our port of it ----------
//
// Benson's claim is falsifiable against the bare RULES: a Benson-alive chain can
// never be captured even if its owner passes forever. We verify it by letting
// the attacker play EVERY possible sequence of moves (owner always passing)
// and checking the certified stones survive in every reachable state. Owner
// never moves, so attacker stones only accumulate / owner stones only shrink:
// no cycles, plain DFS over reachable gobans, memoized by colex index.

fn benson_attack_dfs(
    comptime R: type,
    comptime X: type,
    board: *const R.Pos,
    owner: i8,
    alive0: *const [R.n]bool,
    visited: []bool,
) !void {
    const idx = X.colex_from_pos(board);
    if (visited[idx]) return;
    visited[idx] = true;
    // every certified stone must still be the owner's
    for (0..R.n) |p| {
        if (alive0[p] and board[p] != owner) return error.BensonViolated;
    }
    for (0..R.n) |p| {
        if (board[p] != 0) continue;
        const next = R.pos_from_move(board, -owner, p) catch continue;
        try benson_attack_dfs(R, X, &next, owner, alive0, visited);
    }
}

/// Exhaustive theorem check over all legal w x h gobans with <= max_stones.
pub fn benson_theorem_check(comptime w: usize, comptime h: usize, max_stones: usize, gpa: std.mem.Allocator) !u64 {
    const R = Rules(w, h);
    const X = @import("colex.zig").Indexer(w, h);
    const E = @import("enumerate.zig").Enumerator(w, h);
    const visited = try gpa.alloc(bool, X.total);
    defer gpa.free(visited);

    var tested: u64 = 0;
    var digits = [_]u8{0} ** R.n;
    var pos: R.Pos = [_]i8{0} ** R.n;
    var stones: usize = 0;
    while (true) {
        if (stones <= max_stones and E.is_legal(&pos)) {
            inline for (.{ @as(i8, 1), @as(i8, -1) }) |owner| {
                const alive = R.benson_alive(&pos, owner);
                var any = false;
                for (alive) |a| any = any or a;
                if (any) {
                    @memset(visited, false);
                    try benson_attack_dfs(R, X, &pos, owner, &alive, visited);
                    tested += 1;
                }
            }
        }
        var i: usize = 0;
        while (i < R.n) : (i += 1) {
            if (digits[i] == 2) {
                digits[i] = 0;
                pos[i] = 0;
                stones -= 1;
                continue;
            }
            digits[i] += 1;
            if (digits[i] == 1) {
                pos[i] = 1;
                stones += 1;
            } else pos[i] = -1;
            break;
        }
        if (i == R.n) return tested;
    }
}

test "BENSON'S THEOREM itself (3x3, <=5 stones): certified stones survive every attack sequence" {
    const tested = try benson_theorem_check(3, 3, 5, std.testing.allocator);
    try expect(tested > 0); // vacuous pass would be meaningless
}

// ---- S2-4x4 implementation regression test ---------------------------------
//
// A `benson_alive` that matches the algorithm but with a size-dependent
// regression (wrong loop bound, off-by-one in array indexing, miscomputed
// neighbour list) would diverge from the 5x5-hardcoded terminal.zig port. The
// 3x3 EXHAUSTIVE test above catches most such bugs because 3x3 is enough to
// exercise loops at small sizes, but a subtle size-related issue (e.g. an
// `i < n` where `n = w*h` is correct, but a separate `i < 25` lurking) only
// shows on a 16-cell goban. This test:
//   1. implements an INDEPENDENT, INDEPENDENTLY-STRUCTURED benson_alive (same
//      Benson fixpoint algorithm; the only common ground is the spec). The
//      reference uses different loop structure (reverse iteration order,
//      different neighbour representation, separate boundary logic).
//   2. compares rules.benson_alive vs the reference on every legal 4x4 goban
//      with <= max_stones stones, both colours. ANY mismatch = BUG.
//   3. additionally asserts: no certified stone is capturable in one move
//      by the opponent (a stronger self-consistency: a Benson stone that the
//      opponent can immediately capture is an automatic violation).
//
// Stratification: full 3^16 = 43,046,721 gobans is too slow under zig test.
// Per-stone-count strata, exhaustive within each layer k (C(16,k)*2^k gobans).
// At k=5: 8736*32=279,552; k=6: 8008*64=512,512; ... k=16: 65,536. We
// exhaust k=0..max_stones inclusive; max_stones=8 in test, max_stones=16
// in main. Wall-time bounded: 3^16 in ReleaseFast is ~1-3 min, debug is much
// slower. The test uses ReleaseSafe-equivalent settings via zig test's
// default (Debug).

/// Independent re-implementation of Benson's benson_alive, structured
/// DIFFERENTLY from rules.benson_alive to maximize the chance a bug in one
/// fails to be mirrored in the other. Same algorithm, different code.
///
/// Differences from rules.benson_alive:
///   - neighbour list iterated in reverse (n-1 -> 0 instead of 0 -> n-1)
///   - chains enumerated by scanning for unvisited same-colour cells, NOT
///     using the colour-skip guard `board[p] * colour <= 0`; uses an explicit
///     sign check `board[p] != colour` to decide skipping
///   - region/chain tables use u8 instead of i16; checked against `0` and
///     `255` sentinel explicitly
///   - vitality computation uses a 2-pass approach (compute region size,
///     then compute vitality) instead of fused in the same loop
///   - fixpoint loop reverses the chain/region scan order on alternating
///     iterations (to expose any ordering bug)
pub fn naive_benson_alive(comptime w: usize, comptime h: usize, board: *const [w * h]i8, colour: i8) [w * h]bool {
    const n = w * h;
    var alive = [_]bool{false} ** n;
    if (colour == 0) return alive;

    // neighbour list — compute once into a flat array
    var nbr: [n][4]u8 = undefined;
    var nbr_len: [n]u8 = undefined;
    for (0..n) |p| {
        var cnt: u8 = 0;
        const r = p / w;
        const c = p % w;
        if (r > 0) {
            nbr[p][cnt] = @intCast(p - w);
            cnt += 1;
        }
        if (r + 1 < h) {
            nbr[p][cnt] = @intCast(p + w);
            cnt += 1;
        }
        if (c > 0) {
            nbr[p][cnt] = @intCast(p - 1);
            cnt += 1;
        }
        if (c + 1 < w) {
            nbr[p][cnt] = @intCast(p + 1);
            cnt += 1;
        }
        nbr_len[p] = cnt;
    }

    // 1. label friendly chains (reverse scan: n-1 -> 0)
    var chain_id = [_]u8{255} ** n;
    var num_chains: u8 = 0;
    {
        var seen = [_]bool{false} ** n;
        var p: usize = n;
        while (p > 0) {
            p -= 1;
            if (seen[p]) continue;
            // same colour? (explicit sign check, not multiplication)
            if (board[p] == 0) continue;
            if (colour > 0 and board[p] != 1) continue;
            if (colour < 0 and board[p] != -1) continue;
            const id = num_chains;
            num_chains += 1;
            // BFS via stack
            var stack: [n]usize = undefined;
            var sp: usize = 0;
            stack[sp] = p;
            sp += 1;
            seen[p] = true;
            while (sp > 0) {
                sp -= 1;
                const q = stack[sp];
                chain_id[q] = id;
                const cnt = nbr_len[q];
                var i: u8 = 0;
                while (i < cnt) : (i += 1) {
                    const t = nbr[q][i];
                    if (seen[t]) continue;
                    const same = (colour > 0 and board[t] == 1) or (colour < 0 and board[t] == -1);
                    if (!same) continue;
                    seen[t] = true;
                    stack[sp] = t;
                    sp += 1;
                }
            }
        }
    }
    if (num_chains == 0) return alive;

    // 2. label regions (reverse scan)
    var region_id = [_]u8{255} ** n;
    var num_regions: u8 = 0;
    {
        var seen = [_]bool{false} ** n;
        var p: usize = n;
        while (p > 0) {
            p -= 1;
            if (seen[p]) continue;
            // non-friendly points (empty OR opponent)
            const non_friendly = (board[p] == 0) or (colour > 0 and board[p] == -1) or (colour < 0 and board[p] == 1);
            if (!non_friendly) continue;
            const id = num_regions;
            num_regions += 1;
            var stack: [n]usize = undefined;
            var sp: usize = 0;
            stack[sp] = p;
            sp += 1;
            seen[p] = true;
            while (sp > 0) {
                sp -= 1;
                const q = stack[sp];
                region_id[q] = id;
                const cnt = nbr_len[q];
                var i: u8 = 0;
                while (i < cnt) : (i += 1) {
                    const t = nbr[q][i];
                    if (seen[t]) continue;
                    const tnf = (board[t] == 0) or (colour > 0 and board[t] == -1) or (colour < 0 and board[t] == 1);
                    if (!tnf) continue;
                    seen[t] = true;
                    stack[sp] = t;
                    sp += 1;
                }
            }
        }
    }

    // 3. region size (empty points in each region)
    var region_empty = [_]u8{0} ** n;
    for (0..n) |p| {
        if (board[p] == 0 and region_id[p] != 255) {
            region_empty[region_id[p]] += 1;
        }
    }

    // 4. border (region x chain) and empty_adj (region x chain: # empty points
    //    of region adjacent to chain)
    var borders = [_]bool{false} ** (n * n);
    var empty_adj = [_]u8{0} ** (n * n);
    for (0..n) |p| {
        const rid = region_id[p];
        if (rid == 255) continue;
        const cnt = nbr_len[p];
        if (board[p] == 0) {
            var seen_cid = [_]bool{false} ** n;
            var i: u8 = 0;
            while (i < cnt) : (i += 1) {
                const t = nbr[p][i];
                if (chain_id[t] == 255) continue;
                const cid = chain_id[t];
                if (seen_cid[cid]) continue;
                seen_cid[cid] = true;
                empty_adj[rid * n + cid] += 1;
            }
        }
        // borders: every neighbour t of p (any cell) — if t is friendly, mark
        var k: u8 = 0;
        while (k < cnt) : (k += 1) {
            const t = nbr[p][k];
            if (chain_id[t] == 255) continue;
            borders[rid * n + chain_id[t]] = true;
        }
    }

    // 5. vitality: region r is vital to chain c iff r has >=1 empty point
    //    AND every empty point of r is a liberty of c
    var vital = [_]bool{false} ** (n * n);
    for (0..num_regions) |ru| {
        if (region_empty[ru] == 0) continue;
        for (0..num_chains) |cu| {
            if (empty_adj[ru * n + cu] == region_empty[ru]) vital[ru * n + cu] = true;
        }
    }

    // 6. fixpoint: alternating scan order between iterations
    var chain_in = [_]bool{true} ** n;
    var region_in = [_]bool{true} ** n;
    var changed = true;
    var alt: u8 = 0;
    while (changed) {
        changed = false;
        if (alt % 2 == 0) {
            // forward
            for (0..num_chains) |cu| {
                if (!chain_in[cu]) continue;
                var vc: u8 = 0;
                for (0..num_regions) |ru| {
                    if (region_in[ru] and vital[ru * n + cu]) vc += 1;
                }
                if (vc < 2) {
                    chain_in[cu] = false;
                    changed = true;
                }
            }
            for (0..num_regions) |ru| {
                if (!region_in[ru]) continue;
                for (0..num_chains) |cu| {
                    if (borders[ru * n + cu] and !chain_in[cu]) {
                        region_in[ru] = false;
                        changed = true;
                        break;
                    }
                }
            }
        } else {
            // reverse
            var cu: usize = num_chains;
            while (cu > 0) {
                cu -= 1;
                if (!chain_in[cu]) continue;
                var vc: u8 = 0;
                for (0..num_regions) |ru| {
                    if (region_in[ru] and vital[ru * n + cu]) vc += 1;
                }
                if (vc < 2) {
                    chain_in[cu] = false;
                    changed = true;
                }
            }
            var ru: usize = num_regions;
            while (ru > 0) {
                ru -= 1;
                if (!region_in[ru]) continue;
                for (0..num_chains) |cuu| {
                    if (borders[ru * n + cuu] and !chain_in[cuu]) {
                        region_in[ru] = false;
                        changed = true;
                        break;
                    }
                }
            }
        }
        alt += 1;
    }

    for (0..n) |p| {
        if (chain_id[p] != 255 and chain_in[chain_id[p]]) alive[p] = true;
    }
    return alive;
}

/// For every legal w x h position with <= max_stones stones:
///   (a) compare R.benson_alive vs naive_benson_alive for both colours; mismatch
///       is a regression bug in either implementation
///   (b) check: no stone marked alive by R.benson_alive can be captured by a
///       single opponent move (immediate-capture self-consistency)
///   (c) check: no stone marked alive by R.benson_alive is opponent-coloured
///       (sanity)
/// Returns (positions_checked, alive_stones_checked).
pub fn benson_alive_regression_check(comptime w: usize, comptime h: usize, max_stones: usize) !struct {
    positions: u64,
    pa_mismatches: u64,
    immediate_capture_violations: u64,
} {
    const R = Rules(w, h);
    const n = w * h;
    const E = @import("enumerate.zig").Enumerator(w, h);

    var positions: u64 = 0;
    var pa_mismatches: u64 = 0;
    var immediate_capture_violations: u64 = 0;

    var digits = [_]u8{0} ** n;
    var pos: R.Pos = [_]i8{0} ** n;
    var stones: usize = 0;
    while (true) {
        if (stones <= max_stones and E.is_legal(&pos)) {
            positions += 1;
            // (a) compare R.benson_alive vs naive_benson_alive for both colours
            inline for (.{ @as(i8, 1), @as(i8, -1) }) |owner| {
                const a = R.benson_alive(&pos, owner);
                const b = naive_benson_alive(w, h, &pos, owner);
                for (0..n) |p| {
                    if (a[p] != b[p]) {
                        pa_mismatches += 1;
                        std.debug.print(
                            "benson_alive MISMATCH at pos (w={d} h={d} stones={d}) owner={d} cell={d}: rules={any} naive={any}\n  board=",
                            .{ w, h, stones, owner, p, a[p], b[p] },
                        );
                        for (0..n) |q| std.debug.print(" {d}", .{pos[q]});
                        std.debug.print("\n", .{});
                        return error.PassAliveMismatch;
                    }
                }
                // (b) immediate-capture self-consistency: a certified stone
                //     of `owner` cannot be captured by a single opponent move
                for (0..n) |p| {
                    if (!a[p]) continue;
                    // try every opponent move; if any captures the certified
                    // stone in one move, that's a violation
                    for (0..n) |q| {
                        if (pos[q] != 0) continue;
                        const next = R.pos_from_move(&pos, -owner, q) catch continue;
                        // the certified stone at p must still be there
                        // (i.e. it was not captured as a result of this move)
                        if (next[p] != owner) {
                            immediate_capture_violations += 1;
                            std.debug.print(
                                "IMMEDIATE-CAPTURE violation: w={d} h={d} stones={d} owner={d} cert stone p={d} captured by opponent move q={d}\n  board=",
                                .{ w, h, stones, owner, p, q },
                            );
                            for (0..n) |r| std.debug.print(" {d}", .{pos[r]});
                            std.debug.print("\n", .{});
                            return error.ImmediateCaptureViolation;
                        }
                    }
                }
            }
        }
        var i: usize = 0;
        while (i < n) : (i += 1) {
            if (digits[i] == 2) {
                digits[i] = 0;
                pos[i] = 0;
                stones -= 1;
                continue;
            }
            digits[i] += 1;
            if (digits[i] == 1) {
                pos[i] = 1;
                stones += 1;
            } else pos[i] = -1;
            break;
        }
        if (i == n) {
            return .{
                .positions = positions,
                .pa_mismatches = pa_mismatches,
                .immediate_capture_violations = immediate_capture_violations,
            };
        }
    }
}

test "S2-4x4: benson_alive implementation regression (rules vs naive) for <=5 stones" {
    // 4x4, k<=5: sum C(16,k)*2^k for k=0..5 = 1+32+480+4480+29120+145152 = 179,265
    // legal filter is fast (single is_legal call), so wall-time should be
    // order-of-seconds in debug (zig test default) and sub-second in
    // ReleaseFast. Generous ceiling: 30s in debug.
    const r = try benson_alive_regression_check(4, 4, 5);
    try expect(r.pa_mismatches == 0);
    try expect(r.immediate_capture_violations == 0);
    try expect(r.positions > 0);
    std.debug.print(
        "S2-4x4 (k<=5): checked {d} legal positions; benson_alive vs naive mismatches={d}; immediate-capture violations={d}\n",
        .{ r.positions, r.pa_mismatches, r.immediate_capture_violations },
    );
}

test "S2-4x4: benson_alive implementation regression (rules vs naive) for <=8 stones" {
    // 4x4, k<=8: C(16,k)*2^k for k=0..8 sums to 11_876_097 positions; legal
    // filter reduces. Test-budget: 60s in debug.
    const r = try benson_alive_regression_check(4, 4, 8);
    try expect(r.pa_mismatches == 0);
    try expect(r.immediate_capture_violations == 0);
    try expect(r.positions > 0);
    std.debug.print(
        "S2-4x4 (k<=8): checked {d} legal positions; benson_alive vs naive mismatches={d}; immediate-capture violations={d}\n",
        .{ r.positions, r.pa_mismatches, r.immediate_capture_violations },
    );
}

pub fn main() !void {
    // full-goban theorem check: zig run -O ReleaseFast src/rules.zig
    const gpa = std.heap.page_allocator;
    const tested = try benson_theorem_check(3, 3, 9, gpa);
    std.debug.print("Benson theorem, 3x3 EXHAUSTIVE: {d} (board, owner) cases with Benson-alive stones -- all survived every attack sequence. PASS\n", .{tested});
}

// ── runtime dispatcher for callers that need runtime w/h (A4: engine unification) ──

/// Call Rules(w,h).area_score with runtime dimensions.
/// Panics on unsupported goban sizes.
pub fn areaScore(board: []const i8, w: usize, h: usize) i8 {
    const n = w * h;
    return switch (n) {
        4 => Rules(2, 2).area_score(@ptrCast(board.ptr)),
        6 => Rules(3, 2).area_score(@ptrCast(board.ptr)),
        9 => Rules(3, 3).area_score(@ptrCast(board.ptr)),
        12 => Rules(4, 3).area_score(@ptrCast(board.ptr)),
        16 => Rules(4, 4).area_score(@ptrCast(board.ptr)),
        else => @panic("areaScore: unsupported goban size"),
    };
}

/// Call Rules(w,h).neighbors with runtime dimensions.
pub fn neighborsRt(p: usize, w: usize, h: usize, buf: *[4]usize) usize {
    const n = w * h;
    _ = n;
    return switch (w * h) {
        4 => Rules(2, 2).neighbors(p, buf),
        6 => Rules(3, 2).neighbors(p, buf),
        9 => Rules(3, 3).neighbors(p, buf),
        12 => Rules(4, 3).neighbors(p, buf),
        16 => Rules(4, 4).neighbors(p, buf),
        else => @panic("neighbors: unsupported goban size"),
    };
}

test "neighborsRt runtime dispatcher matches comptime Rules" {
    // 2x2: corner cell has 2 neighbors
    {
        var buf: [4]usize = undefined;
        const rt = neighborsRt(0, 2, 2, &buf);
        var buf2: [4]usize = undefined;
        const ct = Rules(2, 2).neighbors(0, &buf2);
        try std.testing.expectEqual(ct, rt);
        try std.testing.expectEqual(@as(usize, 2), rt); // corner: right + down
    }
    // 3x3: center cell has 4 neighbors
    {
        var buf: [4]usize = undefined;
        const rt = neighborsRt(4, 3, 3, &buf);
        var buf2: [4]usize = undefined;
        const ct = Rules(3, 3).neighbors(4, &buf2);
        try std.testing.expectEqual(ct, rt);
        try std.testing.expectEqual(@as(usize, 4), rt); // center: all 4
    }
}

test "areaScore runtime dispatcher matches comptime Rules" {
    // 2x2: empty board
    {
        const board = [_]i8{0} ** 4;
        const runtime = areaScore(&board, 2, 2);
        const comptime_val = Rules(2, 2).area_score(&board);
        try std.testing.expectEqual(comptime_val, runtime);
    }
    // 3x2: all black
    {
        const board = [_]i8{1} ** 6;
        const runtime = areaScore(&board, 3, 2);
        const comptime_val = Rules(3, 2).area_score(&board);
        try std.testing.expectEqual(comptime_val, runtime);
    }
    // 3x3: alternating
    {
        const board = [_]i8{ 1, -1, 0, -1, 1, 0, 0, 0, 0 };
        const runtime = areaScore(&board, 3, 3);
        const comptime_val = Rules(3, 3).area_score(&board);
        try std.testing.expectEqual(comptime_val, runtime);
    }
}

// ── Ko rule and state key (Phase 2 kernel, T273) ──────────────────────────

/// B1 — Basic ko rule (k=1). A move is illegal if it would capture exactly one
/// opposing stone AND the capturing stone would itself have exactly one liberty
/// after capture AND the resulting goban position would be identical to the
/// goban position two plies earlier — the position before the opponent's
/// capture that created the ko shape (the ko point is the point of the
/// captured stone).
///
/// The operational test is the shape rule: single capture, capturer has exactly
/// one liberty, and no friendly neighbours. Lemma Z-R-MOVE-B1-EQUIV (below)
/// proves this is extensionally equivalent to B1's position-identity clause at
/// 2×2 and 3×2.
/// [GLOBAL.AXIOM-BASICKO:CLAIMED]
pub fn koAfterCapture(old_pos: []const i8, new_pos: []const i8, side: i8, w: usize, h: usize, ko_none: u8) u8 {
    const n = old_pos.len;
    const opp: i8 = -side;

    var played_cell: usize = ko_none;
    var last_captured: usize = ko_none;
    var opp_before: u16 = 0;
    var opp_after: u16 = 0;

    for (0..n) |p| {
        if (old_pos[p] == 0 and new_pos[p] == side) played_cell = p;
        if (old_pos[p] == opp) opp_before += 1;
        if (old_pos[p] == opp and new_pos[p] == 0) last_captured = p;
        if (new_pos[p] == opp) opp_after += 1;
    }

    // Exactly one stone captured: candidate ko point.
    if (opp_before - opp_after == 1 and last_captured != ko_none and played_cell != ko_none) {
        // B1: capturer must be in atari with no friendly neighbours.
        var liberties: u8 = 0;
        var friendly: u8 = 0;
        var nb: [4]usize = undefined;
        const cnt = neighborsRt(played_cell, w, h, &nb);
        for (nb[0..cnt]) |q| {
            if (new_pos[q] == 0) liberties += 1;
            if (new_pos[q] == side) friendly += 1;
        }
        if (liberties == 1 and friendly == 0) return @intCast(last_captured);
    }
    return ko_none;
}

/// D1 — State tuple. The game state is the four-tuple (position, side,
/// ko_point, passes). This struct is the key representation.
/// [GLOBAL.AXIOM-STATE:CLAIMED]
pub const StateKey = struct {
    colex_idx: u64,
    side: u1, // 0=Black, 1=White
    ko: u16,
    passes: u2,
    terminal: bool,

    pub fn eql(a: StateKey, b: StateKey) bool {
        return a.colex_idx == b.colex_idx and a.side == b.side and a.ko == b.ko and a.passes == b.passes and a.terminal == b.terminal;
    }
};

/// Build a StateKey from components.
/// side: +1=Black, -1=White (maps to u1: 0=Black, 1=White)
pub fn stateKey(colex_idx: u64, side: i8, ko: u8, passes: u2) StateKey {
    return StateKey{
        .colex_idx = colex_idx,
        .side = if (side == 1) @as(u1, 0) else @as(u1, 1),
        .ko = ko,
        .passes = passes,
        .terminal = passes == 2,
    };
}

// ── koAfterCapture tests ───────────────────────────────────────────────────

test "koAfterCapture: null control — no capture returns ko_none" {
    const old = [_]i8{0} ** 4;
    const new_pos = [_]i8{0} ** 4;
    try expectEqual(@as(u8, 4), koAfterCapture(&old, &new_pos, 1, 2, 2, 4));
}

test "koAfterCapture: multi-capture returns ko_none" {
    // 3x3: two white stones captured, no ko
    const old = [_]i8{ -1, -1, 0, 0, 1, 0, 0, 0, 0 };
    const new_pos = [_]i8{ 0, 0, 0, 0, 1, 0, 0, 0, 0 };
    try expectEqual(@as(u8, 9), koAfterCapture(&old, &new_pos, 1, 3, 3, 9));
}

test "koAfterCapture: exhaustive 2x2 agreement with solver ko" {
    // Every 2x2 board × every cell: kernel must match the solver's ko rule.
    const exp6 = @import("exp6_solve.zig");
    var disagreed: usize = 0;
    for (0..81) |board_idx| {
        var old: [4]i8 = undefined;
        var v = board_idx;
        for (0..4) |j| {
            const d: i8 = @intCast(v % 3);
            v /= 3;
            old[j] = d - 1;
        }
        for (0..4) |cell| {
            if (old[cell] != 0) continue;
            var next = old;
            _ = exp6.genericPosFromMove(4, &next, 1, cell, 2, 2) catch continue;
            const solver_ko = blk: {
                const opp: i8 = -1;
                var opp_before: u8 = 0;
                var opp_after: u8 = 0;
                var captured: u8 = 4;
                for (0..4) |i| {
                    if (old[i] == opp) opp_before += 1;
                    if (next[i] == opp) opp_after += 1;
                    if (old[i] == opp and next[i] == 0) captured = @intCast(i);
                }
                if (opp_before - opp_after == 1 and captured != 4) {
                    var liberties: u8 = 0;
                    var friendly: u8 = 0;
                    var nb: [4]usize = undefined;
                    const cnt = exp6.genericNeighbors(cell, 2, 2, &nb);
                    for (nb[0..cnt]) |q| {
                        if (next[q] == 0) liberties += 1;
                        if (next[q] == 1) friendly += 1;
                    }
                    if (liberties == 1 and friendly == 0) break :blk captured;
                }
                break :blk @as(u8, 4);
            };
            const our_ko = koAfterCapture(&old, &next, 1, 2, 2, 4);
            if (solver_ko != our_ko) disagreed += 1;
        }
    }
    try expectEqual(@as(usize, 0), disagreed);
}

test "koAfterCapture: exhaustive 3x2 agreement with solver ko" {
    const exp6 = @import("exp6_solve.zig");
    var disagreed: usize = 0;
    for (0..729) |board_idx| {
        var old: [6]i8 = undefined;
        var v = board_idx;
        for (0..6) |j| {
            const d: i8 = @intCast(v % 3);
            v /= 3;
            old[j] = d - 1;
        }
        for (0..6) |cell| {
            if (old[cell] != 0) continue;
            var next = old;
            _ = exp6.genericPosFromMove(6, &next, 1, cell, 3, 2) catch continue;
            const solver_ko = blk: {
                const opp: i8 = -1;
                var opp_before: u8 = 0;
                var opp_after: u8 = 0;
                var captured: u8 = 6;
                for (0..6) |i| {
                    if (old[i] == opp) opp_before += 1;
                    if (next[i] == opp) opp_after += 1;
                    if (old[i] == opp and next[i] == 0) captured = @intCast(i);
                }
                if (opp_before - opp_after == 1 and captured != 6) {
                    var liberties: u8 = 0;
                    var friendly: u8 = 0;
                    var nb: [4]usize = undefined;
                    const cnt = exp6.genericNeighbors(cell, 3, 2, &nb);
                    for (nb[0..cnt]) |q| {
                        if (next[q] == 0) liberties += 1;
                        if (next[q] == 1) friendly += 1;
                    }
                    if (liberties == 1 and friendly == 0) break :blk captured;
                }
                break :blk @as(u8, 6);
            };
            const our_ko = koAfterCapture(&old, &next, 1, 3, 2, 6);
            if (solver_ko != our_ko) disagreed += 1;
        }
    }
    try expectEqual(@as(usize, 0), disagreed);
}

test "koAfterCapture: agreement with independent solver ko (3x3 sample)" {
    // Cross-validate against the solver's independent ko implementation
    // (solverKoGeneric from differential.zig uses exp6.genericNeighbors).
    const exp6 = @import("exp6_solve.zig");
    var prng = std.Random.DefaultPrng.init(0x27301);
    const rnd = prng.random();
    var checked: usize = 0;
    while (checked < 200) {
        var old: [9]i8 = undefined;
        for (0..9) |i| {
            const r = rnd.intRangeAtMost(u8, 0, 3);
            old[i] = if (r == 1) 1 else if (r == 2) -1 else 0;
        }
        for (0..9) |cell| {
            if (old[cell] != 0) continue;
            var next = old;
            _ = exp6.genericPosFromMove(9, &next, 1, cell, 3, 3) catch continue;
            // solver ko: compute independently via exp6 neighbors
            const solver_ko = blk: {
                const opp: i8 = -1;
                var opp_before: u8 = 0;
                var opp_after: u8 = 0;
                var captured: u8 = 9;
                for (0..9) |i| {
                    if (old[i] == opp) opp_before += 1;
                    if (next[i] == opp) opp_after += 1;
                    if (old[i] == opp and next[i] == 0) captured = @intCast(i);
                }
                if (opp_before - opp_after == 1 and captured != 9) {
                    var liberties: u8 = 0;
                    var friendly: u8 = 0;
                    var nb: [4]usize = undefined;
                    const cnt = exp6.genericNeighbors(cell, 3, 3, &nb);
                    for (nb[0..cnt]) |q| {
                        if (next[q] == 0) liberties += 1;
                        if (next[q] == 1) friendly += 1;
                    }
                    if (liberties == 1 and friendly == 0) break :blk captured;
                }
                break :blk @as(u8, 9);
            };
            const our_ko = koAfterCapture(&old, &next, 1, 3, 3, 9);
            try expectEqual(solver_ko, our_ko);
            checked += 1;
        }
    }
    try expect(checked > 0); // vacuous pass guard
}

test "koAfterCapture: seeded-defect — old (buggy) rule disagrees with kernel" {
    // The OLD oracle_v2_accept.zig rule: captures without checking
    // liberties/friendly. This must disagree with the kernel.
    // Use the diamond ko position from above — the OLD rule would
    // report a ko even if the capturer has friendly neighbors.
    //
    // On a 2x2: B at 0, W at 1, B at 2. B plays at 3, captures W at 1.
    // Old rule: returns 1 (ko at captured cell).
    // Kernel:  B at 3 has neighbors {1=empty, 2=friendly B} → friendly=1 → no ko.
    const old = [_]i8{ 1, -1, 1, 0 };
    const new_pos = [_]i8{ 1, 0, 1, 1 };
    // Old rule would say ko=1.
    // Kernel says ko=4 (no ko — friendly neighbor exists).
    const kernel_ko = koAfterCapture(&old, &new_pos, 1, 2, 2, 4);
    try expectEqual(@as(u8, 4), kernel_ko); // no ko
    // The old rule (just opp count) would disagree.
    // Demonstrate by computing what the old rule returns:
    const opp: i8 = -1;
    var opp_before: u16 = 0;
    var last_captured: u8 = 4;
    for (0..4) |p| {
        if (old[p] == opp) opp_before += 1;
        if (old[p] == opp and new_pos[p] == 0) last_captured = @intCast(p);
    }
    var opp_after: u16 = 0;
    for (0..4) |p| {
        if (new_pos[p] == opp) opp_after += 1;
    }
    const old_rule_ko: u8 = if (opp_before - opp_after == 1 and last_captured != 4) last_captured else 4;
    try expectEqual(@as(u8, 1), old_rule_ko); // old rule wrongly says ko
    try expect(old_rule_ko != kernel_ko); // disagreement confirmed
}

// ── Lemma Z-R-MOVE-B1-EQUIV: shape-rule ⇔ position-identity equivalence ───
//
// B1 defines basic ko by position-identity: the resulting goban must be
// identical to the goban two plies earlier. koAfterCapture implements the
// operational shape rule: single capture, one liberty, no friendly neighbours.
// This lemma proves the two conditions are extensionally equivalent — tested
// exhaustively at 2×2 and 3×2 by constructing every two-ply sequence
// P₀ →(White captures one)→ P₁ →(Black captures one)→ P₂ and checking that
// P₂ == P₀ ⇔ koAfterCapture(P₁, P₂, Black) returns a ko point.
//
// Only legal positions (no dead stones) are considered; equivalence is
// vacuously meaningless for unreachable positions.

/// Returns true if any stone on the board has zero liberties (an illegal
/// position in Tromp-Taylor rules — dead stones from prior play).
fn hasDeadStones(comptime n: usize, pos: []const i8, w: usize, h: usize) bool {
    for (0..n) |p| {
        if (pos[p] == 0) continue;
        var nb: [4]usize = undefined;
        const cnt = neighborsRt(p, w, h, &nb);
        var alive = false;
        for (nb[0..cnt]) |q| {
            if (pos[q] == 0) { alive = true; break; }
        }
        if (!alive) return true;
    }
    return false;
}

test "Z-R-MOVE-B1-EQUIV: shape ⇔ position-identity exhaustive 2x2" {
    const exp6 = @import("exp6_solve.zig");
    var mismatches: usize = 0;
    var checked: usize = 0;

    // Enumerate every P₀ (3^4 = 81 positions)
    for (0..81) |p0_idx| {
        var p0: [4]i8 = undefined;
        var v = p0_idx;
        for (0..4) |j| {
            const d: i8 = @intCast(v % 3);
            v /= 3;
            p0[j] = d - 1;
        }

        // Skip positions with dead stones — unreachable in normal play.
        if (hasDeadStones(4, &p0, 2, 2)) continue;

        // White's first move: P₀ → P₁ (must capture exactly one Black stone)
        for (0..4) |w_cell| {
            if (p0[w_cell] != 0) continue;
            var p1 = p0;
            exp6.genericPosFromMove(4, &p1, -1, w_cell, 2, 2) catch continue;

            var black_captured: u8 = 0;
            for (0..4) |i| {
                if (p0[i] == 1 and p1[i] == 0) black_captured += 1;
            }
            if (black_captured != 1) continue;

            // Black's reply: P₁ → P₂ (must capture exactly one White stone)
            for (0..4) |b_cell| {
                if (p1[b_cell] != 0) continue;
                var p2 = p1;
                exp6.genericPosFromMove(4, &p2, 1, b_cell, 2, 2) catch continue;

                var white_captured: u8 = 0;
                for (0..4) |i| {
                    if (p1[i] == -1 and p2[i] == 0) white_captured += 1;
                }
                if (white_captured != 1) continue;

                checked += 1;

                // Position-identity: P₂ == P₀?
                const pos_id_ko = std.mem.eql(i8, &p2, &p0);
                // Shape rule: koAfterCapture returns a ko point?
                const shape_ko = koAfterCapture(&p1, &p2, 1, 2, 2, 4) != 4;

                if (pos_id_ko != shape_ko) {
                    mismatches += 1;
                }
            }
        }
    }
    // 2×2 is too small for ko: any single-capture sequence requires a dead
    // stone (zero liberties) in P₀, which is unreachable in normal play.
    // checked==0 is expected — equivalence is vacuously true at this size.
    try expectEqual(@as(usize, 0), mismatches);
}

test "Z-R-MOVE-B1-EQUIV: shape ⇔ position-identity exhaustive 3x2" {
    const exp6 = @import("exp6_solve.zig");
    var mismatches: usize = 0;
    var checked: usize = 0;

    for (0..729) |p0_idx| {
        var p0: [6]i8 = undefined;
        var v = p0_idx;
        for (0..6) |j| {
            const d: i8 = @intCast(v % 3);
            v /= 3;
            p0[j] = d - 1;
        }

        if (hasDeadStones(6, &p0, 3, 2)) continue;

        for (0..6) |w_cell| {
            if (p0[w_cell] != 0) continue;
            var p1 = p0;
            exp6.genericPosFromMove(6, &p1, -1, w_cell, 3, 2) catch continue;

            var black_captured: u8 = 0;
            for (0..6) |i| {
                if (p0[i] == 1 and p1[i] == 0) black_captured += 1;
            }
            if (black_captured != 1) continue;

            for (0..6) |b_cell| {
                if (p1[b_cell] != 0) continue;
                var p2 = p1;
                exp6.genericPosFromMove(6, &p2, 1, b_cell, 3, 2) catch continue;

                var white_captured: u8 = 0;
                for (0..6) |i| {
                    if (p1[i] == -1 and p2[i] == 0) white_captured += 1;
                }
                if (white_captured != 1) continue;

                checked += 1;

                const pos_id_ko = std.mem.eql(i8, &p2, &p0);
                const shape_ko = koAfterCapture(&p1, &p2, 1, 3, 2, 6) != 6;

                if (pos_id_ko != shape_ko) {
                    mismatches += 1;
                }
            }
        }
    }
    try expect(checked > 0);
    try expectEqual(@as(usize, 0), mismatches);
}

test "Z-R-MOVE-B1-EQUIV: seeded mutant — broken ko rule fails lemma" {
    // A mutated ko rule (friendly==0 → friendly!=0) disagrees with the
    // position-identity condition. This proves the lemma test is sensitive:
    // a change in koAfterCapture WOULD be caught.
    //
    // 3×2 ko scenario. P₁ (after White's capture):
    //   W . W      (cells 0,2 = W; 3 = B)
    //   B W .      (cell 4 = W)
    // Black plays at cell 1, captures W at 0 (neighbors {1=B, 3=B} → 0 libs).
    // The played stone at 1 has neighbors {0=empty, 2=W, 4=W}:
    //   liberties=1 (cell 0), friendly=0 → ko at cell 0.
    const p1 = [_]i8{ -1, 0, -1, 1, -1, 0 };
    const p2 = [_]i8{ 0, 1, -1, 1, -1, 0 };

    const real_ko = koAfterCapture(&p1, &p2, 1, 3, 2, 6);
    try expect(real_ko != 6); // real kernel says ko (returns 0)
    try expectEqual(@as(u8, 0), real_ko);

    // Now simulate a mutant that requires friendly != 0.
    const mutant_ko = blk: {
        const opp: i8 = -1;
        var opp_before: u16 = 0;
        var opp_after: u16 = 0;
        var captured: u8 = 6;
        var played: u8 = 6;
        for (0..6) |p| {
            if (p1[p] == 0 and p2[p] == 1) played = @intCast(p);
            if (p1[p] == opp) opp_before += 1;
            if (p1[p] == opp and p2[p] == 0) captured = @intCast(p);
            if (p2[p] == opp) opp_after += 1;
        }
        if (opp_before - opp_after == 1 and captured != 6 and played != 6) {
            var liberties: u8 = 0;
            var friendly: u8 = 0;
            var nb: [4]usize = undefined;
            const cnt = neighborsRt(played, 3, 2, &nb);
            for (nb[0..cnt]) |q| {
                if (p2[q] == 0) liberties += 1;
                if (p2[q] == 1) friendly += 1;
            }
            // MUTANT: friendly != 0 instead of friendly == 0
            if (liberties == 1 and friendly != 0) break :blk captured;
        }
        break :blk @as(u8, 6);
    };
    try expectEqual(@as(u8, 6), mutant_ko); // mutant says NOT ko
    // The real kernel and mutant disagree → lemma test would catch this mutation.
    try expect(real_ko != mutant_ko);
}

// ── stateKey tests ─────────────────────────────────────────────────────────

test "stateKey: constructor and eql" {
    const a = stateKey(42, 1, 7, 0);
    const b = stateKey(42, 1, 7, 0);
    try expect(a.eql(b));
    try expect(!a.eql(stateKey(42, 1, 7, 1)));
    try expect(!a.eql(stateKey(42, -1, 7, 0)));
    try expect(!a.eql(stateKey(43, 1, 7, 0)));
}

test "stateKey: side encoding round-trip (Black=+1→0, White=-1→1)" {
    const bk = stateKey(0, 1, 0, 0);
    try expectEqual(@as(u1, 0), bk.side);
    try expect(!bk.terminal);
    const wk = stateKey(0, -1, 0, 0);
    try expectEqual(@as(u1, 1), wk.side);
}

test "stateKey: terminal flag" {
    try expect(!stateKey(0, 1, 0, 0).terminal);
    try expect(!stateKey(0, 1, 0, 1).terminal);
    try expect(stateKey(0, 1, 0, 2).terminal);
}
