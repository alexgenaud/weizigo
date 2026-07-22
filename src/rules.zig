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
//   pass_alive    — Benson unconditional life (port of terminal.zig).
//   is_settled    — decided-terminal test incl. eye-space rule (port).
//   is_own_eye    — the ADR-0006 eye-prune predicate (port of solve.zig).
//
// Standalone except std; tests import the 5x5 stack for cross-validation only.

const std = @import("std");
const expect = std.testing.expect;

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

        /// Benson unconditional life. Port of terminal.pass_alive.
        pub fn pass_alive(board: *const Pos, colour: i8) [n]bool {
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
            const balive = pass_alive(board, 1);
            const walive = pass_alive(board, -1);
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

test "3x3: middle-column group is pass-alive; board is settled at +9" {
    const R = Rules(3, 3);
    const b = [_]i8{
        0, 1, 0,
        0, 1, 0,
        0, 1, 0,
    };
    const alive = R.pass_alive(&b, 1);
    try expect(alive[1] and alive[4] and alive[7]);
    try expect(R.is_settled(&b));
    try expect(R.area_score(&b) == 9);
}

test "3x3: single stone is not alive; empty board not settled" {
    const R = Rules(3, 3);
    var one = [_]i8{0} ** 9;
    one[4] = 1;
    const alive = R.pass_alive(&one, 1);
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

test "5x5 cross-validation: area/pass_alive/is_settled match terminal.zig" {
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
        const pa = R.pass_alive(&b, 1);
        const pa5 = terminal.pass_alive(&b, 1);
        for (0..25) |i| try expect(pa[i] == pa5[i]);
        const wa = R.pass_alive(&b, -1);
        const wa5 = terminal.pass_alive(&b, -1);
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
// Benson's claim is falsifiable against the bare RULES: a pass-alive chain can
// never be captured even if its owner passes forever. We verify it by letting
// the attacker play EVERY possible sequence of moves (owner always passing)
// and checking the certified stones survive in every reachable state. Owner
// never moves, so attacker stones only accumulate / owner stones only shrink:
// no cycles, plain DFS over reachable boards, memoized by colex index.

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

/// Exhaustive theorem check over all legal w x h boards with <= max_stones.
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
                const alive = R.pass_alive(&pos, owner);
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

pub fn main() !void {
    // full-board theorem check: zig run -O ReleaseFast src/rules.zig
    const gpa = std.heap.page_allocator;
    const tested = try benson_theorem_check(3, 3, 9, gpa);
    std.debug.print("Benson theorem, 3x3 EXHAUSTIVE: {d} (board, owner) cases with pass-alive stones -- all survived every attack sequence. PASS\n", .{tested});
}
