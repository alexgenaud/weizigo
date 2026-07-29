// Task: PINRULE-SUFFICIENCY · Role: worker · Model: Kimi-k3 (kimi-k3) · Date: 2026-07-29
// Set: T · Holds: src/qa023_pinrule.zig (this file; NEW per the brief —
// src/qa023_probe.zig is contended by F1-SEEDROOTS and is NOT touched)
//
// ############################################################################
// QA-023 / PINRULE-SUFFICIENCY — can ANY pointwise function of (L, TIE, H) be
// correct at 3x2?
// ############################################################################
//
// The brief (docs/infra/dispatch/PINRULE-SUFFICIENCY.md):
//   1. Compute the fixpoint (L, TIE, H) for every reachable non-terminal
//      state at 3x2 under the corrected ko rule (post-2B-FIX-KO).
//   2. Group states by their exact (L, H) pair. Report the distribution.
//   3. Within each group of size >= 2, compare history-conditioned
//      truncation values (fixed probe, sigma excluded, separate exhaustion
//      counters) with a generous node budget; report per-group denominators.
//   4. Finding: does any (L, H) group contain two states with different
//      within-budget truncation values? Yes -> no pointwise pin rule can
//      work (witness in full). No -> characterise the correct rule on the
//      known counterexample states; claim only non-obstruction + coverage.
//   5. Report coverage honestly.
//
// PREMISE DEFECT FOUND WHILE BUILDING THIS INSTRUMENT (see evidence doc):
// the 3x2 fixpoint_kernel in src/qa023_probe.zig (post-2B-FIX-KO, HEAD
// 8b610ee) has inverted update guards at White-to-move nodes: the L sweep
// (ascending, seeded -6) updates a White node only when the child-min is
// *smaller* than current (impossible from -6), and the H sweep (descending,
// seeded +6) updates a White node only when the child-min is *larger* than
// current (impossible from +6). Black nodes are correct in both sweeps. So
// L == -6 and H == +6 at EVERY White-to-move non-terminal state, and the
// published "median pins TIE" on the six/seven C2 counterexample states is
// an artefact: all seven are forced-single-successor states whose only
// legal move is pass-to-terminal, so the Bellman operator forces
// L == H == area_score at each. This file therefore computes BOTH kernels:
//   - "as-shipped": an exact port (bug-compatible) — fidelity check:
//     must reproduce the published pin census 948/1532/142/0;
//   - "corrected": monotone Gauss-Seidel (the pattern of retro.zig,
//     EXP-11-verified, and of smoke_fixpoint_2x2): seed L=-6/H=+6,
//     iterate L = Phi(L) up, H = Phi(H) down, Black max / White min in both.
// The grouping experiment (the actual task) runs on the CORRECTED tables;
// the as-shipped grouping is reported for comparison only.
//
// Validations computed here (all printed, none asserted away):
//   V0  as-shipped port reproduces published pin census exactly.
//   V1  corrected tables satisfy the Bellman residual == 0 at every
//       reachable non-terminal (they are exact fixpoints of Phi).
//   V2  colour inversion: L(-S) == -H(S) at every reachable state
//       (the game graph is inversion-symmetric; the correct extremal
//       fixpoints must mirror). Symptom check on published tables:
//       pin_L=142 vs pin_H=0 is impossible for a correct pair.
//   V3  seven hand-adjudicated states (the C2 "counterexamples" + state
//       146 from the 2B-6 erratum): corrected L == H == area_score ==
//       hand-verified truncated value (+1,+1,+1,+1,+3,-6,-6).
//   V4  evaluator tier agreement (see below).
//
// Evaluators (history-conditioned first-revisit truncation, post-fix
// semantics: arrival exclusive of sigma; TIE leaf on revisit of any state
// in the arrival prefix or on the continuation path; area_score at
// passes==2; null on budget exhaustion; scratch overflow separate):
//   T1  probe-exact port (linear membership scans) — provenance chain to
//       2B-PROBE-FIX. Slow; used on a calibration battery only.
//   T2  bitset plain minimax — identical tree and node accounting as T1
//       (O(1) membership only). Cross-validated against T1 on the battery.
//   T3  bitset alpha-beta — same tree, exact root value, pruned. Primary
//       instrument for coverage. Cross-validated against T2 wherever T2
//       fits; every T1/T2/T3 overlap must agree or this file says so
//       loudly.
//
// Arrival histories per target state:
//   h0  BFS-shortest path from the empty-board root (guaranteed; the class
//       of arrival the probe's DFS generator systematically MISSES —
//       2B-3-AUDIT found the shortest path missed in 93% of states);
//   h1.. randomized DFS long histories (probe-equivalent generator,
//       depth 24) for comparability with 2B-PROBE-FIX.
//
// Modes:
//   pinrule-census   census + both fixpoints + V0..V3 + (L,H) group
//                    distribution (corrected primary, as-shipped comparison)
//   pinrule-eval     the experiment: per-state arrivals + evaluations,
//                    per-group testability, witness search, coverage
//   pinrule-battery  evaluator tier-agreement battery (V4)
//   pinrule-diag6    the seven adjudicated states fully decoded
//
const std = @import("std");

const BOARD_W: usize = 3;
const BOARD_H: usize = 2;
const n: usize = BOARD_W * BOARD_H; // 6
const Pos = [n]i8; // -1 white, 0 empty, +1 black
const TIE: i8 = 0;

// ---- state tuple (identical encoding to qa023_probe.zig) ------------------

const KO_DIMS: usize = n + 1; // 7 (0..n-1 = real cell, n = KO_NONE)
const RAW_TOTAL: u64 = std.math.pow(u64, 3, n); // 729
const TOTAL_STATES: u64 = RAW_TOTAL * 2 * KO_DIMS * 3; // 30,618
const ReachWords: u64 = (TOTAL_STATES + 63) / 64;

const StateIdx = struct {
    board: u32, // 0..728 dense
    side: u8, // 0 = Black (+1), 1 = White (-1)
    ko: u16, // 0..n-1 = cell, KO_NONE = n
    passes: u8, // 0, 1, 2

    pub fn linear(self: StateIdx) u64 {
        const ko_u: u64 = self.ko;
        const side_u: u64 = self.side;
        const passes_u: u64 = self.passes;
        return (((passes_u * 2) + side_u) * KO_DIMS + ko_u) * RAW_TOTAL + self.board;
    }
};

fn decode_linear(linear: u64) StateIdx {
    const passes: u8 = @intCast(linear / (2 * KO_DIMS * RAW_TOTAL));
    const rest: u64 = linear % (2 * KO_DIMS * RAW_TOTAL);
    const side: u8 = @intCast(rest / (KO_DIMS * RAW_TOTAL));
    const rest2: u64 = rest % (KO_DIMS * RAW_TOTAL);
    const ko: u16 = @intCast(rest2 / RAW_TOTAL);
    const board: u32 = @intCast(rest2 % RAW_TOTAL);
    return .{ .board = board, .side = side, .ko = ko, .passes = passes };
}

fn unrank_board(idx: u32) Pos {
    var board: Pos = [_]i8{0} ** n;
    var v: u32 = idx;
    for (0..n) |i| {
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

fn rank_board(board: Pos) u32 {
    var idx: u32 = 0;
    var mult: u32 = 1;
    for (0..n) |i| {
        const d: u32 = if (board[i] > 0) 1 else if (board[i] < 0) 2 else 0;
        idx += d * mult;
        mult *= 3;
    }
    return idx;
}

// ---- rules: verbatim semantics from qa023_probe.zig post-2B-FIX-KO --------

fn neighbors(p: usize, buf: *[4]usize) usize {
    var cnt: usize = 0;
    const r = p / BOARD_W;
    const c = p % BOARD_W;
    if (r > 0) {
        buf[cnt] = p -% BOARD_W;
        cnt += 1;
    }
    if (r + 1 < BOARD_H) {
        buf[cnt] = p +% BOARD_W;
        cnt += 1;
    }
    if (c > 0) {
        buf[cnt] = p -% 1;
        cnt += 1;
    }
    if (c + 1 < BOARD_W) {
        buf[cnt] = p +% 1;
        cnt += 1;
    }
    return cnt;
}

fn chain_captured(pos: *const Pos, seed: usize, chain: *[n]usize, chain_len: *usize) bool {
    const colour: i8 = if (pos[seed] > 0) 1 else -1;
    var visited = [_]bool{false} ** n;
    var sp: usize = 1;
    chain[0] = seed;
    visited[seed] = true;
    var len: usize = 1;
    var stack: [n]usize = undefined;
    stack[0] = seed;
    var has_liberty = false;
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

fn pos_from_move(pos: *const Pos, colour: i8, cell: usize) !Pos {
    if (pos[cell] != 0) return error.Occupied;
    var next: Pos = undefined;
    for (0..n) |i| next[i] = if (pos[i] > 0) 1 else if (pos[i] < 0) -1 else 0;
    next[cell] = colour;
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
    if (chain_captured(&next, cell, &chain, &chain_len)) return error.Suicide;
    return next;
}

fn is_legal(pos: *const Pos) bool {
    var visited = [_]bool{false} ** n;
    for (0..n) |p| {
        if (pos[p] == 0 or visited[p]) continue;
        const colour = pos[p];
        var stack: [n]usize = undefined;
        var sp: usize = 1;
        stack[0] = p;
        visited[p] = true;
        var has_liberty = false;
        while (sp > 0) {
            sp -= 1;
            const q = stack[sp];
            var nb: [4]usize = undefined;
            const cnt = neighbors(q, &nb);
            for (nb[0..cnt]) |r| {
                if (pos[r] == 0) {
                    has_liberty = true;
                } else if (pos[r] == colour and !visited[r]) {
                    visited[r] = true;
                    stack[sp] = r;
                    sp += 1;
                }
            }
        }
        if (!has_liberty) return false;
    }
    return true;
}

fn area_score(board: *const Pos) i8 {
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

/// apply_place WITH the 2B-FIX-KO lone-stone conjunct (formalization (i)).
fn apply_place(state: StateIdx, board: *const Pos, colour: i8, cell: u8) ?StateIdx {
    if (board[cell] != 0) return null;
    if (state.ko != n and cell == state.ko) return null; // basic-ko (i) ban
    const next_board = pos_from_move(board, colour, cell) catch return null;
    var opp_before: u8 = 0;
    var opp_after: u8 = 0;
    var captured_cell: u8 = 255;
    for (0..n) |i| {
        if (board[i] == -colour) opp_before += 1;
        if (next_board[i] == -colour) opp_after += 1;
        if (board[i] == -colour and next_board[i] == 0) captured_cell = @intCast(i);
    }
    var new_ko: u8 = @as(u8, n);
    if ((opp_before - opp_after == 1) and (captured_cell != 255)) {
        var liberties: u8 = 0;
        var friendly: u8 = 0;
        var nb: [4]usize = undefined;
        const cnt = neighbors(cell, &nb);
        for (nb[0..cnt]) |q| {
            if (next_board[q] == 0) liberties += 1;
            if (next_board[q] == colour) friendly += 1;
        }
        if (liberties == 1 and friendly == 0) new_ko = captured_cell;
    }
    return StateIdx{
        .board = rank_board(next_board),
        .side = if (colour == 1) @as(u8, 1) else @as(u8, 0),
        .ko = new_ko,
        .passes = 0,
    };
}

fn apply_pass(state: StateIdx) ?StateIdx {
    if (state.passes >= 2) return null;
    return StateIdx{
        .board = state.board,
        .side = 1 - state.side,
        .ko = @as(u16, n),
        .passes = state.passes + 1,
    };
}

fn moves(state: StateIdx, successor_boards: *[n + 1]Pos, successors: *[(n + 1)]StateIdx) usize {
    if (state.passes == 2) return 0;
    const board = unrank_board(state.board);
    const colour: i8 = if (state.side == 0) 1 else -1;
    var count: usize = 0;
    if (apply_pass(state)) |next_state| {
        successor_boards[count] = unrank_board(next_state.board);
        successors[count] = next_state;
        count += 1;
    }
    for (0..n) |cell_u| {
        const cell: u8 = @intCast(cell_u);
        if (apply_place(state, &board, colour, cell)) |next_state| {
            successor_boards[count] = unrank_board(next_state.board);
            successors[count] = next_state;
            count += 1;
        }
    }
    return count;
}

// ---- census (verbatim semantics) -------------------------------------------

fn seed_roots(reach: []u64) void {
    for ([_]u8{ 0, 1 }) |side| {
        for ([_]u8{ 0, 1, 2 }) |passes| {
            for (0..KO_DIMS) |ko_u| {
                const ko: u16 = @intCast(ko_u);
                const root = StateIdx{ .board = 0, .side = side, .ko = ko, .passes = passes };
                const lin = root.linear();
                reach[lin >> 6] |= @as(u64, 1) << @intCast(lin & 63);
            }
        }
    }
}

fn census_sweep(reach: []u64, snap: []u64, new_marks: *u64) !void {
    @memcpy(snap, reach);
    new_marks.* = 0;
    var linear: u64 = 0;
    while (linear < TOTAL_STATES) : (linear += 1) {
        const parent_word = linear >> 6;
        const parent_bit: u64 = @as(u64, 1) << @intCast(linear & 63);
        if (snap[parent_word] & parent_bit == 0) continue;
        const state = decode_linear(linear);
        var succ_boards: [n + 1]Pos = undefined;
        var succs: [n + 1]StateIdx = undefined;
        const m = moves(state, &succ_boards, &succs);
        for (0..m) |k| {
            const child = succs[k];
            if (!is_legal(&succ_boards[k])) continue;
            const child_linear = child.linear();
            const child_word = child_linear >> 6;
            const child_bit: u64 = @as(u64, 1) << @intCast(child_linear & 63);
            if (reach[child_word] & child_bit == 0) {
                reach[child_word] |= child_bit;
                new_marks.* += 1;
            }
        }
    }
}

fn build_reach(gpa: std.mem.Allocator) ![]u64 {
    const reach = try gpa.alloc(u64, ReachWords);
    @memset(reach, 0);
    seed_roots(reach);
    const snap = try gpa.alloc(u64, ReachWords);
    defer gpa.free(snap);
    var new_marks: u64 = 1;
    var guard: u32 = 0;
    while (new_marks > 0 and guard < 64) {
        try census_sweep(reach, snap, &new_marks);
        guard += 1;
    }
    return reach;
}

// ---- fixpoint kernels ------------------------------------------------------
//
// As-shipped: exact port of qa023_probe.zig:fixpoint_kernel at HEAD 8b610ee,
// INCLUDING the White-node update-guard directions. Fidelity demand: it must
// reproduce the published pin census (L==H=948, pin_T=1532, pin_L=142,
// pin_H=0) exactly.
fn fixpoint_as_shipped(reach: []const u64, L_tab: []i8, H_tab: []i8) u32 {
    const L_init: i8 = -@as(i8, @intCast(n));
    const H_init: i8 = @as(i8, @intCast(n));
    for (0..TOTAL_STATES) |i| {
        L_tab[i] = L_init;
        H_tab[i] = H_init;
    }
    var lin2: u64 = 0;
    while (lin2 < TOTAL_STATES) : (lin2 += 1) {
        if (reach[lin2 >> 6] & (@as(u64, 1) << @intCast(lin2 & 63)) == 0) continue;
        const st = decode_linear(lin2);
        if (st.passes == 2) {
            const b = unrank_board(st.board);
            L_tab[lin2] = area_score(&b);
            H_tab[lin2] = area_score(&b);
        }
    }
    var sweep_idx: u32 = 0;
    var total_changes: u64 = 1;
    while (total_changes > 0 and sweep_idx < 64) {
        sweep_idx += 1;
        total_changes = 0;
        // L sweep
        var l_changed: u64 = 0;
        var li: u64 = 0;
        while (li < TOTAL_STATES) : (li += 1) {
            if (reach[li >> 6] & (@as(u64, 1) << @intCast(li & 63)) == 0) continue;
            const st = decode_linear(li);
            if (st.passes == 2) continue;
            var succ_boards: [n + 1]Pos = undefined;
            var succs: [n + 1]StateIdx = undefined;
            const m = moves(st, &succ_boards, &succs);
            if (st.side == 0) {
                var best: i8 = L_init;
                var any: bool = false;
                for (0..m) |k| {
                    if (!is_legal(&succ_boards[k])) continue;
                    const cl = succs[k].linear();
                    if (reach[cl >> 6] & (@as(u64, 1) << @intCast(cl & 63)) == 0) continue;
                    const v = L_tab[cl];
                    if (!any or v > best) {
                        best = v;
                        any = true;
                    }
                }
                // AS-SHIPPED Black ascent: correct direction.
                if (any and best > L_tab[li]) {
                    L_tab[li] = best;
                    l_changed += 1;
                }
            } else {
                var best: i8 = H_init;
                var any: bool = false;
                for (0..m) |k| {
                    if (!is_legal(&succ_boards[k])) continue;
                    const cl = succs[k].linear();
                    if (reach[cl >> 6] & (@as(u64, 1) << @intCast(cl & 63)) == 0) continue;
                    const v = L_tab[cl];
                    if (!any or v < best) {
                        best = v;
                        any = true;
                    }
                }
                // AS-SHIPPED White "ascent": INVERTED GUARD (updates only if
                // best < current; current is -6 and best >= -6, so never).
                if (any and best < L_tab[li]) {
                    L_tab[li] = best;
                    l_changed += 1;
                }
            }
        }
        // H sweep
        var h_changed: u64 = 0;
        var hi: u64 = 0;
        while (hi < TOTAL_STATES) : (hi += 1) {
            if (reach[hi >> 6] & (@as(u64, 1) << @intCast(hi & 63)) == 0) continue;
            const st = decode_linear(hi);
            if (st.passes == 2) continue;
            var succ_boards: [n + 1]Pos = undefined;
            var succs: [n + 1]StateIdx = undefined;
            const m = moves(st, &succ_boards, &succs);
            if (st.side == 0) {
                var best: i8 = H_init;
                var any: bool = false;
                for (0..m) |k| {
                    if (!is_legal(&succ_boards[k])) continue;
                    const cl = succs[k].linear();
                    if (reach[cl >> 6] & (@as(u64, 1) << @intCast(cl & 63)) == 0) continue;
                    const v = H_tab[cl];
                    if (!any or v > best) {
                        best = v;
                        any = true;
                    }
                }
                // AS-SHIPPED Black descent: correct direction.
                if (any and best < H_tab[hi]) {
                    H_tab[hi] = best;
                    h_changed += 1;
                }
            } else {
                var best: i8 = L_init;
                var any: bool = false;
                for (0..m) |k| {
                    if (!is_legal(&succ_boards[k])) continue;
                    const cl = succs[k].linear();
                    if (reach[cl >> 6] & (@as(u64, 1) << @intCast(cl & 63)) == 0) continue;
                    const v = H_tab[cl];
                    if (!any or v < best) {
                        best = v;
                        any = true;
                    }
                }
                // AS-SHIPPED White "descent": INVERTED GUARD (updates only if
                // best > current; current is +6 and best <= +6, so never).
                if (any and best > H_tab[hi]) {
                    H_tab[hi] = best;
                    h_changed += 1;
                }
            }
        }
        total_changes = l_changed + h_changed;
    }
    return sweep_idx;
}

/// Corrected kernel: monotone Gauss-Seidel from the extremal seeds — the
/// pattern of src/retro.zig (EXP-11-verified) and smoke_fixpoint_2x2:
/// L seeded -6, assigned Phi(L) unconditionally (monotone ascent);
/// H seeded +6, assigned Phi(H) unconditionally (monotone descent);
/// Black max / White min in both (ADR-0009, same operator).
fn fixpoint_corrected(reach: []const u64, L_tab: []i8, H_tab: []i8) u32 {
    const L_init: i8 = -@as(i8, @intCast(n));
    const H_init: i8 = @as(i8, @intCast(n));
    for (0..TOTAL_STATES) |i| {
        L_tab[i] = L_init;
        H_tab[i] = H_init;
    }
    var lin2: u64 = 0;
    while (lin2 < TOTAL_STATES) : (lin2 += 1) {
        if (reach[lin2 >> 6] & (@as(u64, 1) << @intCast(lin2 & 63)) == 0) continue;
        const st = decode_linear(lin2);
        if (st.passes == 2) {
            const b = unrank_board(st.board);
            L_tab[lin2] = area_score(&b);
            H_tab[lin2] = area_score(&b);
        }
    }
    var sweep_idx: u32 = 0;
    var total_changes: u64 = 1;
    while (total_changes > 0 and sweep_idx < 256) {
        sweep_idx += 1;
        total_changes = 0;
        var li: u64 = 0;
        while (li < TOTAL_STATES) : (li += 1) {
            if (reach[li >> 6] & (@as(u64, 1) << @intCast(li & 63)) == 0) continue;
            const st = decode_linear(li);
            if (st.passes == 2) continue;
            const maximizing = (st.side == 0);
            var succ_boards: [n + 1]Pos = undefined;
            var succs: [n + 1]StateIdx = undefined;
            const m = moves(st, &succ_boards, &succs);
            var bl: ?i8 = null;
            var bh: ?i8 = null;
            for (0..m) |k| {
                if (!is_legal(&succ_boards[k])) continue;
                const cl = succs[k].linear();
                if (reach[cl >> 6] & (@as(u64, 1) << @intCast(cl & 63)) == 0) continue;
                const vl = L_tab[cl];
                const vh = H_tab[cl];
                if (bl == null or (if (maximizing) vl > bl.? else vl < bl.?)) bl = vl;
                if (bh == null or (if (maximizing) vh > bh.? else vh < bh.?)) bh = vh;
            }
            // Pass is always legal off-terminal => bl/bh set.
            if (bl.? > L_tab[li]) {
                L_tab[li] = bl.?;
                total_changes += 1;
            }
            if (bh.? < H_tab[li]) {
                H_tab[li] = bh.?;
                total_changes += 1;
            }
        }
    }
    return sweep_idx;
}

// ---- validation V1/V2 -------------------------------------------------------

/// Bellman residual: count of reachable non-terminals where table != Phi(table).
fn bellman_residual(reach: []const u64, tab: []const i8) u64 {
    var bad: u64 = 0;
    var li: u64 = 0;
    while (li < TOTAL_STATES) : (li += 1) {
        if (reach[li >> 6] & (@as(u64, 1) << @intCast(li & 63)) == 0) continue;
        const st = decode_linear(li);
        if (st.passes == 2) continue;
        const maximizing = (st.side == 0);
        var succ_boards: [n + 1]Pos = undefined;
        var succs: [n + 1]StateIdx = undefined;
        const m = moves(st, &succ_boards, &succs);
        var best: ?i8 = null;
        for (0..m) |k| {
            if (!is_legal(&succ_boards[k])) continue;
            const cl = succs[k].linear();
            if (reach[cl >> 6] & (@as(u64, 1) << @intCast(cl & 63)) == 0) continue;
            const v = tab[cl];
            if (best == null or (if (maximizing) v > best.? else v < best.?)) best = v;
        }
        if (best == null or best.? != tab[li]) bad += 1;
    }
    return bad;
}

/// Colour-inversion mirror of a state: negate the board, flip the side;
/// ko cell and passes unchanged. The game graph is invariant under this map.
fn mirror_linear(linear: u64) u64 {
    const st = decode_linear(linear);
    const b = unrank_board(st.board);
    var nb: Pos = undefined;
    for (0..n) |i| nb[i] = -b[i];
    const mst = StateIdx{ .board = rank_board(nb), .side = 1 - st.side, .ko = st.ko, .passes = st.passes };
    return mst.linear();
}

fn inversion_violations(reach: []const u64, L_tab: []const i8, H_tab: []const i8) u64 {
    var bad: u64 = 0;
    var li: u64 = 0;
    while (li < TOTAL_STATES) : (li += 1) {
        if (reach[li >> 6] & (@as(u64, 1) << @intCast(li & 63)) == 0) continue;
        const mi = mirror_linear(li);
        if (reach[mi >> 6] & (@as(u64, 1) << @intCast(mi & 63)) == 0) {
            bad += 1; // mirror unreachable: symmetry of the reach set broken
            continue;
        }
        if (L_tab[mi] != -H_tab[li]) bad += 1;
    }
    return bad;
}

const PinCensus = struct { l_eq_h: u64, pin_t: u64, pin_l: u64, pin_h: u64 };

fn pin_census(reach: []const u64, L_tab: []const i8, H_tab: []const i8, skip_terminals: bool) PinCensus {
    var c = PinCensus{ .l_eq_h = 0, .pin_t = 0, .pin_l = 0, .pin_h = 0 };
    var li: u64 = 0;
    while (li < TOTAL_STATES) : (li += 1) {
        if (reach[li >> 6] & (@as(u64, 1) << @intCast(li & 63)) == 0) continue;
        const st = decode_linear(li);
        if (skip_terminals and st.passes == 2) continue;
        const Ll = L_tab[li];
        const Hh = H_tab[li];
        if (Ll == Hh) {
            c.l_eq_h += 1;
        } else if (TIE < Ll) {
            c.pin_l += 1;
        } else if (TIE > Hh) {
            c.pin_h += 1;
        } else {
            c.pin_t += 1;
        }
    }
    return c;
}

// ---- history machinery ------------------------------------------------------

const Move = struct {
    move_kind: enum { place, pass },
    cell: u8,
    colour: i8,
};

const HistoryEntry = struct {
    state: StateIdx,
    board: Pos,
};

/// BFS shortest arrival paths from the empty-board root to every reachable
/// state. parent[lin] = parent linear (0xFFFFFFFF = none); pmove_cell /
/// pmove_kind describe the edge parent -> lin.
fn bfs_parents(
    gpa: std.mem.Allocator,
    reach: []const u64,
    parent: []u32,
    pmove_kind: []u8, // 0 place, 1 pass
    pmove_cell: []u8,
) !void {
    _ = gpa;
    @memset(parent, 0xFFFFFFFF);
    const root = StateIdx{ .board = 0, .side = 0, .ko = @as(u16, n), .passes = 0 };
    const queue_buf = try std.heap.page_allocator.alloc(u32, TOTAL_STATES);
    defer std.heap.page_allocator.free(queue_buf);
    var head: u64 = 0;
    var tail: u64 = 0;
    const rlin: u32 = @intCast(root.linear());
    parent[rlin] = rlin; // self-parent marks root
    queue_buf[tail] = rlin;
    tail += 1;
    while (head < tail) {
        const cur = queue_buf[head];
        head += 1;
        const st = decode_linear(cur);
        if (st.passes == 2) continue;
        var succ_boards: [n + 1]Pos = undefined;
        var succs: [n + 1]StateIdx = undefined;
        const m = moves(st, &succ_boards, &succs);
        for (0..m) |k| {
            const child = succs[k];
            if (!is_legal(&succ_boards[k])) continue;
            const cl = child.linear();
            if (reach[cl >> 6] & (@as(u64, 1) << @intCast(cl & 63)) == 0) continue;
            if (parent[@intCast(cl)] != 0xFFFFFFFF) continue; // already have a shortest path
            parent[@intCast(cl)] = cur;
            if (child.board == st.board) {
                pmove_kind[@intCast(cl)] = 1;
                pmove_cell[@intCast(cl)] = 0;
            } else {
                pmove_kind[@intCast(cl)] = 0;
                // find the placed cell: empty -> occupied
                const cb = succ_boards[k];
                const pb = unrank_board(st.board);
                var cell: u8 = 0;
                for (0..n) |ci| {
                    if (pb[ci] == 0 and cb[ci] != 0) {
                        cell = @intCast(ci);
                        break;
                    }
                }
                pmove_cell[@intCast(cl)] = cell;
            }
            queue_buf[tail] = @intCast(cl);
            tail += 1;
        }
    }
}

/// Reconstruct the arrival (root..target inclusive) as a StateIdx path.
/// Caller provides buf sized MAX_PATH. Returns length, or 0 if unreachable.
const MAX_PATH: u16 = 2700; // >= reachable-state count (simple paths only)
fn arrival_from_parents(
    parent: []const u32,
    target_linear: u64,
    buf: []HistoryEntry,
) u16 {
    if (parent[@intCast(target_linear)] == 0xFFFFFFFF) return 0;
    var len: u16 = 0;
    var cur: u32 = @intCast(target_linear);
    while (true) {
        if (len >= buf.len) return 0;
        const st = decode_linear(cur);
        buf[len] = .{ .state = st, .board = unrank_board(st.board) };
        len += 1;
        const p = parent[@intCast(cur)];
        if (p == cur) break;
        cur = p;
    }
    // reverse to root-first order
    var i: u16 = 0;
    while (i < len / 2) : (i += 1) {
        const t = buf[i];
        buf[i] = buf[len - 1 - i];
        buf[len - 1 - i] = t;
    }
    return len;
}

/// Port of qa023_probe.zig's randomized DFS simple-path collector:
/// up to max_collect distinct arrival histories (move sequences) from the
/// root to target_linear, depth-limited, deduplicated verbatim.
fn collect_histories_dfs(
    state: StateIdx,
    board: *const Pos,
    target_linear: u64,
    depth: u16,
    max_depth: u16,
    budget: *u64,
    path_moves: []Move,
    path_len: *u16,
    visited: []bool,
    collected_moves: []Move,
    collected_lens: []u16,
    collected_count: *u32,
    max_collect: u32,
    history_depth: u16,
    prng: *std.Random,
) void {
    const linear = state.linear();
    if (linear == target_linear) {
        if (collected_count.* >= max_collect) return;
        var i: u32 = 0;
        while (i < collected_count.*) : (i += 1) {
            const li = collected_lens[i];
            if (li != path_len.*) continue;
            const base = i * history_depth;
            var same = true;
            var j: u16 = 0;
            while (j < li) : (j += 1) {
                const a = collected_moves[base + j];
                const b = path_moves[j];
                if (@intFromEnum(a.move_kind) != @intFromEnum(b.move_kind) or a.cell != b.cell or a.colour != b.colour) {
                    same = false;
                    break;
                }
            }
            if (same) return;
        }
        const base = collected_count.* * history_depth;
        for (0..path_len.*) |p_| {
            collected_moves[base + p_] = path_moves[p_];
        }
        collected_lens[collected_count.*] = path_len.*;
        collected_count.* += 1;
        return;
    }
    if (depth == max_depth or budget.* == 0) return;
    budget.* -= 1;

    visited[linear] = true;

    var succ_boards: [n + 1]Pos = undefined;
    var succs: [n + 1]StateIdx = undefined;
    const m = moves(state, &succ_boards, &succs);
    var order: [n + 1]usize = undefined;
    for (0..m) |j| order[j] = j;
    var mm = m;
    while (mm > 1) {
        mm -= 1;
        const j = prng.intRangeAtMost(usize, 0, mm);
        const tmp = order[mm];
        order[mm] = order[j];
        order[j] = tmp;
    }

    for (0..m) |k| {
        const idx = order[k];
        const child = succs[idx];
        const child_linear = child.linear();
        if (visited[child_linear]) continue;

        const mv = if (child.board == state.board)
            Move{ .move_kind = .pass, .cell = 0, .colour = 0 }
        else blk: {
            const next_b = succ_boards[idx];
            var cell: u8 = 0;
            var found: bool = false;
            var c: usize = 0;
            while (c < n) : (c += 1) {
                if (board[c] == 0 and next_b[c] != 0) {
                    cell = @intCast(c);
                    found = true;
                    break;
                }
            }
            if (!found) {
                c = 0;
                while (c < n) : (c += 1) {
                    if (board[c] != next_b[c]) {
                        cell = @intCast(c);
                        break;
                    }
                }
            }
            const colour: i8 = if (state.side == 0) 1 else -1;
            break :blk Move{ .move_kind = .place, .cell = cell, .colour = colour };
        };

        path_moves[path_len.*] = mv;
        path_len.* += 1;
        collect_histories_dfs(child, &succ_boards[idx], target_linear, depth + 1, max_depth, budget, path_moves, path_len, visited, collected_moves, collected_lens, collected_count, max_collect, history_depth, prng);
        path_len.* -= 1;
    }

    visited[linear] = false;
}

/// Replay a move sequence from the root, building the arrival entries
/// (root..final inclusive). Returns 0 on any illegal move.
fn replay_arrival(play: []const Move, buf: []HistoryEntry) u16 {
    var st = StateIdx{ .board = 0, .side = 0, .ko = @as(u16, n), .passes = 0 };
    var board: Pos = [_]i8{0} ** n;
    if (buf.len == 0) return 0;
    buf[0] = .{ .state = st, .board = board };
    var len: u16 = 1;
    for (play) |mv| {
        const next = switch (mv.move_kind) {
            .place => apply_place(st, &board, mv.colour, mv.cell),
            .pass => apply_pass(st),
        };
        const ns = next orelse return 0;
        if (len >= buf.len) return 0;
        st = ns;
        board = unrank_board(ns.board);
        buf[len] = .{ .state = st, .board = board };
        len += 1;
    }
    return len;
}

// ---- evaluators -------------------------------------------------------------
//
// All three implement the SAME truncated game (post-fix semantics):
//   - budget decremented per entered node BEFORE any other check;
//   - membership of the current state in the arrival prefix (exclusive of
//     sigma) or in the continuation path => leaf value TIE;
//   - passes == 2 => area_score; no legal moves => area_score (defensive);
//   - Black max / White min over legal, reachable... note: the probe's
//     truncated_value filters successors by is_legal only (NOT by reach).
//     We keep exactly that: is_legal filter only.
//   - null = budget exhausted (or scratch overflow, tracked separately).

fn state_eq(a: StateIdx, b: StateIdx) bool {
    return a.board == b.board and a.side == b.side and a.ko == b.ko and a.passes == b.passes;
}

/// T1: probe-exact port (linear membership scans). Calibration only.
fn truncated_value_t1(
    state: StateIdx,
    board: *const Pos,
    arrival: []const HistoryEntry,
    budget: *u64,
    scratch: []StateIdx,
    scratch_top: *u16,
    scratch_full: *bool,
) ?i8 {
    if (budget.* == 0) return null;
    budget.* -= 1;
    for (arrival) |e| {
        if (state_eq(e.state, state)) return TIE;
    }
    var i: u16 = 0;
    while (i < scratch_top.*) : (i += 1) {
        if (state_eq(scratch[i], state)) return TIE;
    }
    if (state.passes == 2) return area_score(board);
    var succ_boards: [n + 1]Pos = undefined;
    var succs: [n + 1]StateIdx = undefined;
    const m = moves(state, &succ_boards, &succs);
    if (m == 0) return area_score(board);
    const maximizing: bool = (state.side == 0);
    var best: i8 = if (maximizing) -127 else 127;
    for (0..m) |k| {
        if (!is_legal(&succ_boards[k])) continue;
        if (scratch_top.* >= scratch.len) {
            scratch_full.* = true;
            return null;
        }
        scratch[scratch_top.*] = state;
        scratch_top.* += 1;
        const v = truncated_value_t1(succs[k], &succ_boards[k], arrival, budget, scratch, scratch_top, scratch_full) orelse return null;
        scratch_top.* -= 1;
        if (maximizing) {
            if (v > best) best = v;
        } else {
            if (v < best) best = v;
        }
    }
    return best;
}

const VISIT_WORDS: usize = ReachWords;

inline fn visit_get(set: []const u64, linear: u64) bool {
    return set[linear >> 6] & (@as(u64, 1) << @intCast(linear & 63)) != 0;
}
inline fn visit_set(set: []u64, linear: u64) void {
    set[linear >> 6] |= @as(u64, 1) << @intCast(linear & 63);
}
inline fn visit_clear(set: []u64, linear: u64) void {
    set[linear >> 6] &= ~(@as(u64, 1) << @intCast(linear & 63));
}

/// Build a visit bitset from an arrival slice; returns false if scratch
/// guard tripped (cannot happen at 3x2 sizes we use).
fn arrival_bitset(arrival: []const HistoryEntry, set: []u64) void {
    @memset(set, 0);
    for (arrival) |e| visit_set(set, e.state.linear());
}

/// T2: bitset plain minimax. Identical tree and identical node accounting
/// as T1 (same budget semantics, same successor filter). Differs only in
/// membership-test cost.
fn truncated_value_t2(
    state: StateIdx,
    board: *const Pos,
    arrival_set: []const u64,
    budget: *u64,
    path_set: []u64,
    nodes_over: *bool,
) ?i8 {
    if (budget.* == 0) return null;
    budget.* -= 1;
    const lin = state.linear();
    if (visit_get(arrival_set, lin)) return TIE;
    if (visit_get(path_set, lin)) return TIE;
    if (state.passes == 2) return area_score(board);
    var succ_boards: [n + 1]Pos = undefined;
    var succs: [n + 1]StateIdx = undefined;
    const m = moves(state, &succ_boards, &succs);
    if (m == 0) return area_score(board);
    const maximizing: bool = (state.side == 0);
    var best: i8 = if (maximizing) -127 else 127;
    visit_set(path_set, lin);
    for (0..m) |k| {
        if (!is_legal(&succ_boards[k])) continue;
        const v = truncated_value_t2(succs[k], &succ_boards[k], arrival_set, budget, path_set, nodes_over) orelse {
            visit_clear(path_set, lin);
            return null;
        };
        if (maximizing) {
            if (v > best) best = v;
        } else {
            if (v < best) best = v;
        }
    }
    visit_clear(path_set, lin);
    return best;
}

/// T3: bitset alpha-beta. Same tree as T1/T2; prunes; returns the exact
/// root value of the identical truncated tree whenever it returns non-null.
/// nodes counts entered nodes (same budget unit as T1/T2; alpha-beta simply
/// enters fewer of them).
fn truncated_value_t3(
    state: StateIdx,
    board: *const Pos,
    arrival_set: []const u64,
    budget: *u64,
    path_set: []u64,
    alpha_in: i16,
    beta_in: i16,
) ?i8 {
    if (budget.* == 0) return null;
    budget.* -= 1;
    const lin = state.linear();
    if (visit_get(arrival_set, lin)) return TIE;
    if (visit_get(path_set, lin)) return TIE;
    if (state.passes == 2) return area_score(board);
    var succ_boards: [n + 1]Pos = undefined;
    var succs: [n + 1]StateIdx = undefined;
    const m = moves(state, &succ_boards, &succs);
    if (m == 0) return area_score(board);
    var alpha = alpha_in;
    var beta = beta_in;
    visit_set(path_set, lin);
    if (state.side == 0) {
        var best: i16 = -127;
        for (0..m) |k| {
            if (!is_legal(&succ_boards[k])) continue;
            const v = truncated_value_t3(succs[k], &succ_boards[k], arrival_set, budget, path_set, alpha, beta) orelse {
                visit_clear(path_set, lin);
                return null;
            };
            if (v > best) best = v;
            if (best > alpha) alpha = best;
            if (alpha >= beta) break;
        }
        visit_clear(path_set, lin);
        return @intCast(best);
    } else {
        var best: i16 = 127;
        for (0..m) |k| {
            if (!is_legal(&succ_boards[k])) continue;
            const v = truncated_value_t3(succs[k], &succ_boards[k], arrival_set, budget, path_set, alpha, beta) orelse {
                visit_clear(path_set, lin);
                return null;
            };
            if (v < best) best = v;
            if (best < beta) beta = best;
            if (alpha >= beta) break;
        }
        visit_clear(path_set, lin);
        return @intCast(best);
    }
}

/// Verify an arrival entry chain: buf[0] must be the empty-board root;
/// each consecutive pair must be one legal move apart (and the chain must
/// be a simple path — no repeated state tuple). Returns 0 on valid, else
/// the 1-based index of the first bad step (or 0xFFFF for bad root).
fn arrival_valid(buf: []const HistoryEntry) u16 {
    if (buf.len == 0) return 0xFFFF;
    const root = StateIdx{ .board = 0, .side = 0, .ko = @as(u16, n), .passes = 0 };
    if (!state_eq(buf[0].state, root)) return 0xFFFF;
    var seen = [_]u64{0} ** ReachWords;
    for (buf, 0..) |e, i| {
        const lin = e.state.linear();
        if (visit_get(&seen, lin)) return @intCast(i); // repeat on the path
        visit_set(&seen, lin);
        if (i == 0) continue;
        const prev = buf[i - 1].state;
        var succ_boards: [n + 1]Pos = undefined;
        var succs: [n + 1]StateIdx = undefined;
        const m = moves(prev, &succ_boards, &succs);
        var ok = false;
        for (0..m) |k| {
            if (!is_legal(&succ_boards[k])) continue;
            if (state_eq(succs[k], e.state)) {
                ok = true;
                break;
            }
        }
        if (!ok) return @intCast(i);
    }
    return 0;
}

/// Print an arrival as a move sequence (B0/W2/pass ...) for hand checking.
fn print_arrival_moves(buf: []const HistoryEntry) void {
    std.debug.print("#   arrival moves: ", .{});
    var i: usize = 1;
    while (i < buf.len) : (i += 1) {
        const prev = buf[i - 1].state;
        const cur = buf[i].state;
        if (cur.board == prev.board) {
            std.debug.print("pass ", .{});
        } else {
            const pb = unrank_board(prev.board);
            const cb = unrank_board(cur.board);
            var cell: usize = 0;
            for (0..n) |c| {
                if (pb[c] == 0 and cb[c] != 0) {
                    cell = c;
                    break;
                }
            }
            const mover: u8 = if (prev.side == 0) 'B' else 'W';
            std.debug.print("{c}{d} ", .{ mover, cell });
        }
    }
    std.debug.print("\n", .{});
}

// ---- the seven hand-adjudicated control states ------------------------------
// From docs/epistemic/qa023-c2-adjudication-2026-07-29.md §1b (state 146's
// value corrected to +1 there) and probe-fix-2026-07-29.md §4.
const Control = struct { board: u32, side: u8, ko: u16, passes: u8, value: i8 };
const CONTROLS = [_]Control{
    .{ .board = 586, .side = 1, .ko = 6, .passes = 1, .value = 1 },
    .{ .board = 534, .side = 1, .ko = 6, .passes = 1, .value = 1 },
    .{ .board = 302, .side = 1, .ko = 6, .passes = 1, .value = 1 },
    .{ .board = 146, .side = 1, .ko = 6, .passes = 1, .value = 1 },
    .{ .board = 103, .side = 1, .ko = 6, .passes = 1, .value = 3 },
    .{ .board = 674, .side = 1, .ko = 6, .passes = 1, .value = -6 },
    .{ .board = 566, .side = 1, .ko = 6, .passes = 1, .value = -6 },
};

fn board_string(b: Pos, buf: *[2 * n]u8) []const u8 {
    for (0..n) |i| {
        buf[2 * i] = switch (b[i]) {
            1 => 'B',
            -1 => 'W',
            else => '.',
        };
        if (i + 1 < n) buf[2 * i + 1] = ' ';
    }
    return buf[0 .. 2 * n - 1];
}

// ---- group registry ----------------------------------------------------------

const GROUPS = 14 * 14; // L,H in [-6..6]
fn group_key(l: i8, h: i8) usize {
    return @as(usize, @intCast(l + 7)) * 14 + @as(usize, @intCast(h + 7));
}

// ---- modes -------------------------------------------------------------------

fn run_diag6(reach: []const u64, L_s: []const i8, H_s: []const i8, L_c: []const i8, H_c: []const i8) void {
    _ = reach;
    std.debug.print("# pinrule-diag6 — the seven hand-adjudicated states\n", .{});
    for (CONTROLS) |c| {
        const st = StateIdx{ .board = c.board, .side = c.side, .ko = c.ko, .passes = c.passes };
        const lin = st.linear();
        const b = unrank_board(c.board);
        var sbuf: [2 * n]u8 = undefined;
        var succ_boards: [n + 1]Pos = undefined;
        var succs: [n + 1]StateIdx = undefined;
        const m = moves(st, &succ_boards, &succs);
        var legal_cnt: usize = 0;
        for (0..m) |k| {
            if (is_legal(&succ_boards[k])) legal_cnt += 1;
        }
        std.debug.print("CTRL board[{s}] state=({d},{d},{d},{d}) area={d} hand_value={d}\n", .{
            board_string(b, &sbuf), c.board, c.side, c.ko, c.passes, area_score(&b), c.value,
        });
        std.debug.print("  as-shipped: L={d} H={d} median={d} | corrected: L={d} H={d} median={d} | legal_succs={d}\n", .{
            L_s[lin],       H_s[lin],       @max(L_s[lin], @min(TIE, H_s[lin])),
            L_c[lin],       H_c[lin],       @max(L_c[lin], @min(TIE, H_c[lin])),
            legal_cnt,
        });
        for (0..m) |k| {
            if (!is_legal(&succ_boards[k])) continue;
            std.debug.print("    -> ({d},{d},{d},{d}) pass={}\n", .{
                succs[k].board, succs[k].side, succs[k].ko, succs[k].passes, succs[k].board == st.board,
            });
        }
    }
}

fn run_census_mode(gpa: std.mem.Allocator) !void {
    std.debug.print("# pinrule-census — census, both fixpoints, validations V0..V3, group distribution\n", .{});
    const reach = try build_reach(gpa);
    var total_reach: u64 = 0;
    var non_terminal: u64 = 0;
    var side_count = [_]u64{ 0, 0 };
    var li: u64 = 0;
    while (li < TOTAL_STATES) : (li += 1) {
        if (reach[li >> 6] & (@as(u64, 1) << @intCast(li & 63)) == 0) continue;
        total_reach += 1;
        const st = decode_linear(li);
        side_count[st.side] += 1;
        if (st.passes != 2) non_terminal += 1;
    }
    std.debug.print("# census: total reachable = {d} (published: 2622)\n", .{total_reach});
    std.debug.print("# census: non-terminal = {d} (published: 1756)  terminals = {d} (published: 866)\n", .{ non_terminal, total_reach - non_terminal });
    std.debug.print("# census: by side B={d} W={d}\n", .{ side_count[0], side_count[1] });

    const L_s = try gpa.alloc(i8, TOTAL_STATES);
    const H_s = try gpa.alloc(i8, TOTAL_STATES);
    const L_c = try gpa.alloc(i8, TOTAL_STATES);
    const H_c = try gpa.alloc(i8, TOTAL_STATES);
    const sw_s = fixpoint_as_shipped(reach, L_s, H_s);
    const sw_c = fixpoint_corrected(reach, L_c, H_c);
    std.debug.print("# fixpoint sweeps: as-shipped={d} corrected={d}\n", .{ sw_s, sw_c });

    const pc_s_all = pin_census(reach, L_s, H_s, false);
    const pc_c_all = pin_census(reach, L_c, H_c, false);
    const pc_s_nt = pin_census(reach, L_s, H_s, true);
    const pc_c_nt = pin_census(reach, L_c, H_c, true);
    std.debug.print("# V0 as-shipped pin census (all):  L==H={d} pin_T={d} pin_L={d} pin_H={d}  (published: 948/1532/142/0)\n", .{ pc_s_all.l_eq_h, pc_s_all.pin_t, pc_s_all.pin_l, pc_s_all.pin_h });
    std.debug.print("# V0 as-shipped pin census (non-term): L==H={d} pin_T={d} pin_L={d} pin_H={d}  (published: 82/1532/142/0)\n", .{ pc_s_nt.l_eq_h, pc_s_nt.pin_t, pc_s_nt.pin_l, pc_s_nt.pin_h });
    std.debug.print("#    corrected pin census (all):  L==H={d} pin_T={d} pin_L={d} pin_H={d}\n", .{ pc_c_all.l_eq_h, pc_c_all.pin_t, pc_c_all.pin_l, pc_c_all.pin_h });
    std.debug.print("#    corrected pin census (non-term): L==H={d} pin_T={d} pin_L={d} pin_H={d}\n", .{ pc_c_nt.l_eq_h, pc_c_nt.pin_t, pc_c_nt.pin_l, pc_c_nt.pin_h });

    // White-node freeze check on as-shipped: count White non-terminals with L==-6 and H==+6
    var white_frozen: u64 = 0;
    var white_nt: u64 = 0;
    li = 0;
    while (li < TOTAL_STATES) : (li += 1) {
        if (reach[li >> 6] & (@as(u64, 1) << @intCast(li & 63)) == 0) continue;
        const st = decode_linear(li);
        if (st.passes == 2 or st.side != 1) continue;
        white_nt += 1;
        if (L_s[li] == -6 and H_s[li] == 6) white_frozen += 1;
    }
    std.debug.print("# as-shipped White-to-move non-terminals: {d}, of which pinned at seed (-6,+6): {d}\n", .{ white_nt, white_frozen });

    // V1 Bellman residuals
    const res_s_L = bellman_residual(reach, L_s);
    const res_s_H = bellman_residual(reach, H_s);
    const res_c_L = bellman_residual(reach, L_c);
    const res_c_H = bellman_residual(reach, H_c);
    std.debug.print("# V1 Bellman residual (states where table != Phi(table)):\n", .{});
    std.debug.print("#    as-shipped: L residual={d}  H residual={d}\n", .{ res_s_L, res_s_H });
    std.debug.print("#    corrected:  L residual={d}  H residual={d}\n", .{ res_c_L, res_c_H });

    // V2 inversion symmetry
    const inv_s = inversion_violations(reach, L_s, H_s);
    const inv_c = inversion_violations(reach, L_c, H_c);
    std.debug.print("# V2 inversion violations (L(-S) != -H(S) or mirror unreachable): as-shipped={d} corrected={d}\n", .{ inv_s, inv_c });

    // V3 controls
    std.debug.print("# V3 controls (corrected L==H==hand value required):\n", .{});
    var v3_pass: u32 = 0;
    for (CONTROLS) |c| {
        const st = StateIdx{ .board = c.board, .side = c.side, .ko = c.ko, .passes = c.passes };
        const lin = st.linear();
        const ok = (L_c[lin] == c.value and H_c[lin] == c.value);
        if (ok) v3_pass += 1;
        std.debug.print("#    ({d},{d},{d},{d}): corrected L={d} H={d} expected={d} {s}\n", .{
            c.board, c.side, c.ko, c.passes, L_c[lin], H_c[lin], c.value, if (ok) "OK" else "** MISMATCH **",
        });
    }
    std.debug.print("# V3: {d}/{d} controls pass\n", .{ v3_pass, CONTROLS.len });

    // Group distribution on corrected tables (reachable non-terminal states)
    var size_by_group = [_]u64{0} ** GROUPS;
    var hist = [_]u64{0} ** 64; // group-size histogram bucket (size capped at 63+, last bucket = overflow)
    li = 0;
    while (li < TOTAL_STATES) : (li += 1) {
        if (reach[li >> 6] & (@as(u64, 1) << @intCast(li & 63)) == 0) continue;
        const st = decode_linear(li);
        if (st.passes == 2) continue;
        size_by_group[group_key(L_c[li], H_c[li])] += 1;
    }
    var n_groups: u64 = 0;
    var n_groups_ge2: u64 = 0;
    var states_in_ge2: u64 = 0;
    var biggest: u64 = 0;
    var biggest_key: usize = 0;
    for (0..GROUPS) |g| {
        const s = size_by_group[g];
        if (s == 0) continue;
        n_groups += 1;
        if (s >= 2) {
            n_groups_ge2 += 1;
            states_in_ge2 += s;
        }
        if (s > biggest) {
            biggest = s;
            biggest_key = g;
        }
        hist[@as(usize, @intCast(@min(s, 63)))] += 1;
    }
    std.debug.print("# corrected (L,H) groups: {d} non-empty over {d} non-terminal states\n", .{ n_groups, non_terminal });
    std.debug.print("#   groups of size >= 2: {d}, containing {d} states ({d} size-1 groups untestable)\n", .{ n_groups_ge2, states_in_ge2, n_groups - n_groups_ge2 });
    std.debug.print("#   biggest group: (L={d},H={d}) size={d}\n", .{ @as(i8, @intCast(biggest_key / 14)) - 7, @as(i8, @intCast(biggest_key % 14)) - 7, biggest });
    std.debug.print("# group-size histogram (size -> #groups; 63 = size>=63):\n", .{});
    for (1..64) |s| {
        if (hist[s] > 0) std.debug.print("#   size {d}{s}: {d} groups\n", .{ s, if (s == 63) "+" else "", hist[s] });
    }
    // full group list
    std.debug.print("# group list (corrected tables), format L H size:\n", .{});
    for (0..GROUPS) |g| {
        const s = size_by_group[g];
        if (s == 0) continue;
        std.debug.print("GROUP L={d} H={d} size={d}\n", .{ @as(i8, @intCast(g / 14)) - 7, @as(i8, @intCast(g % 14)) - 7, s });
    }
    // as-shipped comparison: the giant degenerate group
    var s_group_sizes = [_]u64{0} ** GROUPS;
    li = 0;
    while (li < TOTAL_STATES) : (li += 1) {
        if (reach[li >> 6] & (@as(u64, 1) << @intCast(li & 63)) == 0) continue;
        const st = decode_linear(li);
        if (st.passes == 2) continue;
        s_group_sizes[group_key(L_s[li], H_s[li])] += 1;
    }
    var s_groups: u64 = 0;
    var s_ge2: u64 = 0;
    var s_big: u64 = 0;
    var s_bigkey: usize = 0;
    for (0..GROUPS) |g| {
        if (s_group_sizes[g] == 0) continue;
        s_groups += 1;
        if (s_group_sizes[g] >= 2) s_ge2 += 1;
        if (s_group_sizes[g] > s_big) {
            s_big = s_group_sizes[g];
            s_bigkey = g;
        }
    }
    std.debug.print("# as-shipped (L,H) groups: {d} non-empty, {d} of size>=2; biggest (L={d},H={d}) size={d} (the degenerate White-frozen pool)\n", .{ s_groups, s_ge2, @as(i8, @intCast(s_bigkey / 14)) - 7, @as(i8, @intCast(s_bigkey % 14)) - 7, s_big });
}

// -----------------------------------------------------------------------------

const EvalOutcome = struct {
    value: ?i8,
    nodes_used: u64,
};

fn eval_t2(state: StateIdx, board: *const Pos, arrival: []const HistoryEntry, node_budget: u64) EvalOutcome {
    var aset_buf = [1]u64{0} ** VISIT_WORDS;
    var pset_buf = [1]u64{0} ** VISIT_WORDS;
    arrival_bitset(arrival, &aset_buf);
    var budget = node_budget;
    var over = false;
    const v = truncated_value_t2(state, board, &aset_buf, &budget, &pset_buf, &over);
    return .{ .value = v, .nodes_used = node_budget - budget };
}

fn eval_t3(state: StateIdx, board: *const Pos, arrival: []const HistoryEntry, node_budget: u64) EvalOutcome {
    var aset_buf = [1]u64{0} ** VISIT_WORDS;
    var pset_buf = [1]u64{0} ** VISIT_WORDS;
    arrival_bitset(arrival, &aset_buf);
    var budget = node_budget;
    const v = truncated_value_t3(state, board, &aset_buf, &budget, &pset_buf, -127, 127);
    return .{ .value = v, .nodes_used = node_budget - budget };
}

fn eval_t1(state: StateIdx, board: *const Pos, arrival: []const HistoryEntry, node_budget: u64, scratch: []StateIdx) EvalOutcome {
    var budget = node_budget;
    var top: u16 = 0;
    var full = false;
    const v = truncated_value_t1(state, board, arrival, &budget, scratch, &top, &full);
    return .{ .value = v, .nodes_used = node_budget - budget };
}

fn run_battery(gpa: std.mem.Allocator, seed: u64, sample: u32, budget: u64) !void {
    std.debug.print("# pinrule-battery — evaluator tier agreement (V4)\n", .{});
    std.debug.print("# tiers: T1 probe-exact port (linear scans), T2 bitset minimax, T3 bitset alpha-beta\n", .{});
    std.debug.print("# budget per (state,history): {d}\n", .{budget});
    const reach = try build_reach(gpa);
    const parent = try gpa.alloc(u32, TOTAL_STATES);
    const pmk = try gpa.alloc(u8, TOTAL_STATES);
    const pmc = try gpa.alloc(u8, TOTAL_STATES);
    try bfs_parents(gpa, reach, parent, pmk, pmc);
    const scratch = try gpa.alloc(StateIdx, 4096);
    var prng = std.Random.DefaultPrng.init(seed);

    var checked: u64 = 0;
    var agree: u64 = 0;
    var disagree: u64 = 0;
    var partial: u64 = 0; // some tiers exhausted

    // Part 1: the seven controls, BFS-short arrival, all three tiers.
    std.debug.print("# battery part 1: seven controls x BFS-short arrival\n", .{});
    for (CONTROLS) |c| {
        const st = StateIdx{ .board = c.board, .side = c.side, .ko = c.ko, .passes = c.passes };
        const lin = st.linear();
        var abuf: [MAX_PATH]HistoryEntry = undefined;
        const alen = arrival_from_parents(parent, lin, &abuf);
        if (alen < 2) {
            std.debug.print("#   CTRL ({d},{d},{d},{d}): no BFS arrival?! len={d}\n", .{ c.board, c.side, c.ko, c.passes, alen });
            continue;
        }
        // arrival exclusive of sigma: drop the last entry
        const arrival = abuf[0 .. alen - 1];
        const b = unrank_board(c.board);
        const r1 = eval_t1(st, &b, arrival, budget, scratch);
        const r2 = eval_t2(st, &b, arrival, budget);
        const r3 = eval_t3(st, &b, arrival, budget);
        checked += 1;
        const ok12 = (r1.value == null and r2.value == null) or (r1.value != null and r2.value != null and r1.value.? == r2.value.?);
        const ok23 = (r2.value == null and r3.value == null) or (r2.value != null and r3.value != null and r2.value.? == r3.value.?);
        const okval = (r3.value != null and r3.value.? == c.value);
        if (ok12 and ok23) agree += 1 else disagree += 1;
        if (!ok12 or !ok23) std.debug.print("#   ** TIER DISAGREEMENT **\n", .{});
        std.debug.print("CTRL-BATT ({d},{d},{d},{d}) alen={d} T1={?d}({d}n) T2={?d}({d}n) T3={?d}({d}n) expected={d} {s}\n", .{
            c.board, c.side, c.ko, c.passes, alen - 1,
            r1.value, r1.nodes_used, r2.value, r2.nodes_used, r3.value, r3.nodes_used,
            c.value, if (okval) "VALUE-OK" else "** VALUE MISMATCH **",
        });
    }

    // Part 2: random reachable non-terminal states, BFS-short arrival.
    std.debug.print("# battery part 2: {d} random non-terminal states\n", .{sample});
    const nt_list = try gpa.alloc(u64, TOTAL_STATES);
    var nt_count: u64 = 0;
    var li: u64 = 0;
    while (li < TOTAL_STATES) : (li += 1) {
        if (reach[li >> 6] & (@as(u64, 1) << @intCast(li & 63)) == 0) continue;
        const st = decode_linear(li);
        if (st.passes == 2) continue;
        nt_list[nt_count] = li;
        nt_count += 1;
    }
    var picks: u32 = 0;
    while (picks < sample) : (picks += 1) {
        const idx = prng.random().intRangeAtMost(u64, 0, nt_count - 1);
        const lin = nt_list[idx];
        const st = decode_linear(lin);
        var abuf: [MAX_PATH]HistoryEntry = undefined;
        const alen = arrival_from_parents(parent, lin, &abuf);
        if (alen < 2) continue;
        const arrival = abuf[0 .. alen - 1];
        const b = unrank_board(st.board);
        const r1 = eval_t1(st, &b, arrival, budget, scratch);
        const r2 = eval_t2(st, &b, arrival, budget);
        const r3 = eval_t3(st, &b, arrival, budget);
        checked += 1;
        const both12 = r1.value != null and r2.value != null;
        const both23 = r2.value != null and r3.value != null;
        if ((both12 and r1.value.? != r2.value.?) or (both23 and r2.value.? != r3.value.?)) {
            disagree += 1;
            std.debug.print("BATT-DISAGREE ({d},{d},{d},{d}) T1={?d} T2={?d} T3={?d}\n", .{ st.board, st.side, st.ko, st.passes, r1.value, r2.value, r3.value });
        } else if (!both12 or !both23) {
            partial += 1;
        } else {
            agree += 1;
        }
    }
    std.debug.print("# battery: checked={d} full-agree={d} disagree={d} partial(some tier exhausted)={d}\n", .{ checked, agree, disagree, partial });
}

fn run_eval_mode(gpa: std.mem.Allocator, seed: u64, node_budget: u64, k_long: u32, max_states: u32, cross_every: u32) !void {
    std.debug.print("# pinrule-eval — the experiment (corrected tables)\n", .{});
    std.debug.print("# params: seed={d} node_budget={d} k_long={d} max_states={d} cross_every={d}\n", .{ seed, node_budget, k_long, max_states, cross_every });
    const reach = try build_reach(gpa);
    const L_c = try gpa.alloc(i8, TOTAL_STATES);
    const H_c = try gpa.alloc(i8, TOTAL_STATES);
    _ = fixpoint_corrected(reach, L_c, H_c);

    // group registry
    const group_of = try gpa.alloc(i32, TOTAL_STATES);
    @memset(group_of, -1);
    const members = try gpa.alloc(std.ArrayListUnmanaged(u64), GROUPS);
    for (0..GROUPS) |g| members[g] = .empty;
    var li: u64 = 0;
    while (li < TOTAL_STATES) : (li += 1) {
        if (reach[li >> 6] & (@as(u64, 1) << @intCast(li & 63)) == 0) continue;
        const st = decode_linear(li);
        if (st.passes == 2) continue;
        const g = group_key(L_c[li], H_c[li]);
        try members[g].append(gpa, li);
        group_of[li] = @intCast(g);
    }

    // BFS shortest paths for all
    const parent = try gpa.alloc(u32, TOTAL_STATES);
    const pmk = try gpa.alloc(u8, TOTAL_STATES);
    const pmc = try gpa.alloc(u8, TOTAL_STATES);
    try bfs_parents(gpa, reach, parent, pmk, pmc);

    // per-state result store: for witness search
    const EvalRec = struct {
        bfs_val: ?i8 = null,
        bfs_nodes: u64 = 0,
        long_vals: [4]?i8 = .{ null, null, null, null },
        long_lens: [4]u16 = .{ 0, 0, 0, 0 },
        any_val: ?i8 = null, // first within-budget value seen
        multi_val: bool = false, // two within-budget values disagree for THIS state
        evals_done: u32 = 0,
    };
    const recs = try gpa.alloc(EvalRec, TOTAL_STATES);
    for (0..TOTAL_STATES) |i| recs[i] = .{};

    var prng = std.Random.DefaultPrng.init(seed);
    const visited_states = try gpa.alloc(bool, TOTAL_STATES);
    const path_moves = try gpa.alloc(Move, 64);
    const collected_moves = try gpa.alloc(Move, 4 * 64);
    const collected_lens = try gpa.alloc(u16, 4);

    var states_attempted: u64 = 0;
    var states_with_value: u64 = 0;
    var evals_total: u64 = 0;
    var evals_within: u64 = 0;
    var evals_exhausted: u64 = 0;
    var nodes_spent: u64 = 0;
    var cross_checked: u64 = 0;
    var cross_disagree: u64 = 0;
    var c1_witnesses: u64 = 0;
    var arrival_bad: u64 = 0;

    // (no wall-clock dependency — std.time reshuffled in 0.16; progress
    // lines are emitted every 100 states so a stall is visible regardless)
    var ticks: u64 = 0;

    // iterate groups of size >= 2
    for (0..GROUPS) |g| {
        if (members[g].items.len < 2) continue;
        const gl: i8 = @as(i8, @intCast(g / 14)) - 7;
        const gh: i8 = @as(i8, @intCast(g % 14)) - 7;
        for (members[g].items) |lin| {
            if (max_states > 0 and states_attempted >= max_states) break;
            states_attempted += 1;
            const st = decode_linear(lin);
            const b = unrank_board(st.board);
            // h0: BFS-shortest arrival
            var abuf: [MAX_PATH]HistoryEntry = undefined;
            const alen = arrival_from_parents(parent, lin, &abuf);
            if (alen >= 2) {
                const bad = arrival_valid(abuf[0..alen]);
                if (bad != 0) {
                    arrival_bad += 1;
                    std.debug.print("# ** ARRIVAL-BAD (bfs) at ({d},{d},{d},{d}) step={d} **\n", .{ st.board, st.side, st.ko, st.passes, bad });
                    continue;
                }
                const arrival = abuf[0 .. alen - 1];
                const r3 = eval_t3(st, &b, arrival, node_budget);
                evals_total += 1;
                nodes_spent += r3.nodes_used;
                recs[lin].bfs_nodes = r3.nodes_used;
                if (r3.value) |v| {
                    evals_within += 1;
                    recs[lin].bfs_val = v;
                    if (recs[lin].any_val == null) recs[lin].any_val = v;
                    recs[lin].evals_done += 1;
                } else {
                    evals_exhausted += 1;
                }
                // cross-check with T2 on every cross_every-th state whose
                // T3 used <= node_budget/4 nodes (plain needs the full tree)
                if (cross_every > 0 and r3.value != null and states_attempted % cross_every == 0 and r3.nodes_used <= node_budget / 4) {
                    const r2 = eval_t2(st, &b, arrival, 4 * r3.nodes_used + 1024);
                    nodes_spent += r2.nodes_used;
                    cross_checked += 1;
                    if (r2.value != null and r2.value.? != r3.value.?) {
                        cross_disagree += 1;
                        std.debug.print("# ** CROSS DISAGREE T3={d} T2={d} at ({d},{d},{d},{d}) **\n", .{ r3.value.?, r2.value.?, st.board, st.side, st.ko, st.passes });
                    }
                }
                std.debug.print("EVAL state=({d},{d},{d},{d}) L={d} H={d} hist=bfs len={d} val={?d} nodes={d}\n", .{ st.board, st.side, st.ko, st.passes, gl, gh, alen - 1, r3.value, r3.nodes_used });
            } else {
                std.debug.print("EVAL state=({d},{d},{d},{d}) L={d} H={d} hist=bfs ARRIVAL-MISSING\n", .{ st.board, st.side, st.ko, st.passes, gl, gh });
            }
            // h1..: randomized DFS long histories
            var lj: u32 = 0;
            while (lj < k_long) : (lj += 1) {
                @memset(visited_states, false);
                var cc: u32 = 0;
                var cbudget: u64 = 4096;
                var rand = prng.random();
                const root = StateIdx{ .board = 0, .side = 0, .ko = @as(u16, n), .passes = 0 };
                const root_board: Pos = [_]i8{0} ** n;
                var plen: u16 = 0;
                collect_histories_dfs(root, &root_board, lin, 0, 24, &cbudget, path_moves, &plen, visited_states, collected_moves, collected_lens, &cc, 1, 64, &rand);
                if (cc == 0) {
                    std.debug.print("EVAL state=({d},{d},{d},{d}) L={d} H={d} hist=dfs{d} UNAVAILABLE\n", .{ st.board, st.side, st.ko, st.passes, gl, gh, lj + 1 });
                    continue;
                }
                const hlen = collected_lens[0];
                var rbuf: [80]HistoryEntry = undefined;
                const rlen = replay_arrival(collected_moves[0..hlen], &rbuf);
                if (rlen < 2) continue;
                const bad = arrival_valid(rbuf[0..rlen]);
                if (bad != 0 or !state_eq(rbuf[rlen - 1].state, st)) {
                    arrival_bad += 1;
                    std.debug.print("# ** ARRIVAL-BAD (dfs) at ({d},{d},{d},{d}) step={d} ends-at-sigma={} **\n", .{ st.board, st.side, st.ko, st.passes, bad, state_eq(rbuf[rlen - 1].state, st) });
                    continue;
                }
                const arrival = rbuf[0 .. rlen - 1];
                const r3 = eval_t3(st, &b, arrival, node_budget);
                evals_total += 1;
                nodes_spent += r3.nodes_used;
                recs[lin].long_lens[@min(lj, 3)] = hlen;
                if (r3.value) |v| {
                    evals_within += 1;
                    recs[lin].long_vals[@min(lj, 3)] = v;
                    if (recs[lin].any_val == null) {
                        recs[lin].any_val = v;
                    } else if (recs[lin].any_val.? != v) {
                        recs[lin].multi_val = true;
                    }
                    recs[lin].evals_done += 1;
                } else {
                    evals_exhausted += 1;
                }
                std.debug.print("EVAL state=({d},{d},{d},{d}) L={d} H={d} hist=dfs{d} len={d} val={?d} nodes={d}\n", .{ st.board, st.side, st.ko, st.passes, gl, gh, lj + 1, hlen, r3.value, r3.nodes_used });
            }
            if (recs[lin].evals_done > 0) states_with_value += 1;
            if (recs[lin].multi_val) {
                c1_witnesses += 1;
                std.debug.print("# ** C1-WITNESS: state ({d},{d},{d},{d}) evaluates to different values under different genuine arrivals: bfs={?d} long=[{?d},{?d},{?d},{?d}] **\n", .{
                    st.board, st.side, st.ko, st.passes, recs[lin].bfs_val, recs[lin].long_vals[0], recs[lin].long_vals[1], recs[lin].long_vals[2], recs[lin].long_vals[3],
                });
            }
            if (states_attempted % 100 == 0) {
                ticks += 1;
                std.debug.print("# progress: {d} states, {d}/{d} evals within budget, {d} states w/ value, {d}M nodes (x100 block {d})\n", .{ states_attempted, evals_within, evals_total, states_with_value, nodes_spent / 1_000_000, ticks });
            }
        }
    }

    // per-group witness analysis
    std.debug.print("# === per-group analysis (corrected (L,H) groups of size >= 2) ===\n", .{});
    var groups_testable: u64 = 0;
    var groups_with_any_value: u64 = 0;
    var groups_total_ge2: u64 = 0;
    var witness_groups: u64 = 0;
    for (0..GROUPS) |g| {
        if (members[g].items.len < 2) continue;
        groups_total_ge2 += 1;
        const gl: i8 = @as(i8, @intCast(g / 14)) - 7;
        const gh: i8 = @as(i8, @intCast(g % 14)) - 7;
        var vals_seen = [_]bool{false} ** 16; // value -6..6 -> idx 0..12 (+sentinel)
        var distinct: u32 = 0;
        var states_with_val: u32 = 0;
        for (members[g].items) |lin| {
            if (recs[lin].any_val) |v| {
                states_with_val += 1;
                const vi: usize = @intCast(v + 7);
                if (!vals_seen[vi]) {
                    vals_seen[vi] = true;
                    distinct += 1;
                }
            }
        }
        if (states_with_val > 0) groups_with_any_value += 1;
        if (states_with_val >= 2) groups_testable += 1;
        var vbuf: [80]u8 = undefined;
        var vlen: usize = 0;
        for (0..16) |vi| {
            if (vals_seen[vi]) {
                const sv = std.fmt.bufPrint(vbuf[vlen..], "{d} ", .{@as(i16, @intCast(vi)) - 7}) catch break;
                vlen += sv.len;
            }
        }
        std.debug.print("GROUP-SUM L={d} H={d} size={d} states_with_value={d} distinct_values={d} values=[{s}]\n", .{ gl, gh, members[g].items.len, states_with_val, distinct, vbuf[0..vlen] });
        if (distinct >= 2) {
            witness_groups += 1;
            std.debug.print("# ** WITNESS GROUP (L={d},H={d}): {d} distinct within-budget truncation values **\n", .{ gl, gh, distinct });
            for (members[g].items) |lin| {
                if (recs[lin].any_val == null) continue;
                const st = decode_linear(lin);
                const bb = unrank_board(st.board);
                var sbuf: [2 * n]u8 = undefined;
                std.debug.print("#    member ({d},{d},{d},{d}) board[{s}] value={d} bfs_nodes={d}\n", .{ st.board, st.side, st.ko, st.passes, board_string(bb, &sbuf), recs[lin].any_val.?, recs[lin].bfs_nodes });
            }
        }
    }
    std.debug.print("# === coverage ===\n", .{});
    std.debug.print("# states attempted (in corrected groups >=2): {d}\n", .{states_attempted});
    std.debug.print("# evaluations: total={d} within-budget={d} exhausted={d}  (exhaustion rate {d:.2}%)\n", .{ evals_total, evals_within, evals_exhausted, if (evals_total > 0) @as(f64, @floatFromInt(evals_exhausted)) * 100.0 / @as(f64, @floatFromInt(evals_total)) else 0.0 });
    std.debug.print("# states with >=1 within-budget value: {d} / {d} attempted\n", .{ states_with_value, states_attempted });
    std.debug.print("# groups size>=2: {d}; with >=1 valued state: {d}; TESTABLE (>=2 valued states): {d}\n", .{ groups_total_ge2, groups_with_any_value, groups_testable });
    std.debug.print("# C1 witnesses (same state, two arrivals, two values): {d}\n", .{c1_witnesses});
    std.debug.print("# ARRIVAL-BAD (instrument self-check, must be 0): {d}\n", .{arrival_bad});
    std.debug.print("# WITNESS GROUPS (distinct values inside one (L,H) group): {d} / {d} testable\n", .{ witness_groups, groups_testable });
    std.debug.print("# cross-checks T3-vs-T2: {d} checked, {d} disagreements\n", .{ cross_checked, cross_disagree });
    std.debug.print("# nodes spent: {d}\n", .{nodes_spent});
    if (witness_groups > 0 or c1_witnesses > 0) {
        std.debug.print("# VERDICT: YES — obstruction found; no pointwise function of (L,TIE,H) can be correct on these groups (see member dumps above).\n", .{});
    } else if (groups_testable > 0) {
        std.debug.print("# VERDICT: NO obstruction found within budget — on {d} testable groups, all within-budget truncation values agreed inside each group. NOT a proof: coverage and exhaustion above.\n", .{groups_testable});
    } else {
        std.debug.print("# VERDICT: INCONCLUSIVE — no group had >=2 within-budget evaluations.\n", .{});
    }
}

// ---- per-state deep-dive mode ------------------------------------------------

fn run_state_mode(gpa: std.mem.Allocator, b_in: u32, s_in: u8, k_in: u16, p_in: u8, seed: u64, budget: u64, k_long: u32) !void {
    std.debug.print("# pinrule-state — deep dive on ({d},{d},{d},{d})\n", .{ b_in, s_in, k_in, p_in });
    const reach = try build_reach(gpa);
    const L_c = try gpa.alloc(i8, TOTAL_STATES);
    const H_c = try gpa.alloc(i8, TOTAL_STATES);
    _ = fixpoint_corrected(reach, L_c, H_c);
    const st = StateIdx{ .board = b_in, .side = s_in, .ko = k_in, .passes = p_in };
    const lin = st.linear();
    const b = unrank_board(b_in);
    var sbuf: [2 * n]u8 = undefined;
    std.debug.print("# board[{s}] reachable={} area={d} corrected L={d} H={d} median={d}\n", .{
        board_string(b, &sbuf),
        reach[lin >> 6] & (@as(u64, 1) << @intCast(lin & 63)) != 0,
        area_score(&b),
        L_c[lin],
        H_c[lin],
        @max(L_c[lin], @min(TIE, H_c[lin])),
    });
    const parent = try gpa.alloc(u32, TOTAL_STATES);
    const pmk = try gpa.alloc(u8, TOTAL_STATES);
    const pmc = try gpa.alloc(u8, TOTAL_STATES);
    try bfs_parents(gpa, reach, parent, pmk, pmc);
    const scratch = try gpa.alloc(StateIdx, 4096);

    // BFS arrival
    {
        var abuf: [MAX_PATH]HistoryEntry = undefined;
        const alen = arrival_from_parents(parent, lin, &abuf);
        if (alen >= 2) {
            const bad = arrival_valid(abuf[0..alen]);
            std.debug.print("# BFS arrival len={d} valid={d} (0=valid)\n", .{ alen, bad });
            print_arrival_moves(abuf[0..alen]);
            const arrival = abuf[0 .. alen - 1];
            const r1 = eval_t1(st, &b, arrival, budget, scratch);
            const r2 = eval_t2(st, &b, arrival, budget);
            const r3 = eval_t3(st, &b, arrival, budget);
            std.debug.print("#   values: T1={?d}({d}n) T2={?d}({d}n) T3={?d}({d}n)\n", .{ r1.value, r1.nodes_used, r2.value, r2.nodes_used, r3.value, r3.nodes_used });
        } else {
            std.debug.print("# BFS arrival: unreachable (len={d})\n", .{alen});
        }
    }
    // DFS long arrivals
    const visited_states = try gpa.alloc(bool, TOTAL_STATES);
    const path_moves = try gpa.alloc(Move, 64);
    const collected_moves = try gpa.alloc(Move, 8 * 64);
    const collected_lens = try gpa.alloc(u16, 8);
    var prng = std.Random.DefaultPrng.init(seed);
    var lj: u32 = 0;
    while (lj < k_long) : (lj += 1) {
        @memset(visited_states, false);
        var cc: u32 = 0;
        var cbudget: u64 = 65536;
        var rand = prng.random();
        const root = StateIdx{ .board = 0, .side = 0, .ko = @as(u16, n), .passes = 0 };
        const root_board: Pos = [_]i8{0} ** n;
        var plen: u16 = 0;
        collect_histories_dfs(root, &root_board, lin, 0, 24, &cbudget, path_moves, &plen, visited_states, collected_moves, collected_lens, &cc, 1, 64, &rand);
        if (cc == 0) {
            std.debug.print("# dfs{d}: no history found\n", .{lj + 1});
            continue;
        }
        const hlen = collected_lens[0];
        var rbuf: [80]HistoryEntry = undefined;
        const rlen = replay_arrival(collected_moves[0..hlen], &rbuf);
        if (rlen < 2) {
            std.debug.print("# dfs{d}: replay failed (hlen={d} rlen={d})\n", .{ lj + 1, hlen, rlen });
            continue;
        }
        const final_ok = state_eq(rbuf[rlen - 1].state, st);
        const bad = arrival_valid(rbuf[0..rlen]);
        std.debug.print("# dfs{d} arrival len={d} ends-at-sigma={} valid={d} (0=valid)\n", .{ lj + 1, rlen, final_ok, bad });
        print_arrival_moves(rbuf[0..rlen]);
        const arrival = rbuf[0 .. rlen - 1];
        const r1 = eval_t1(st, &b, arrival, budget, scratch);
        const r2 = eval_t2(st, &b, arrival, budget);
        const r3 = eval_t3(st, &b, arrival, budget);
        std.debug.print("#   values: T1={?d}({d}n) T2={?d}({d}n) T3={?d}({d}n)\n", .{ r1.value, r1.nodes_used, r2.value, r2.nodes_used, r3.value, r3.nodes_used });
    }
}

pub fn main(init: std.process.Init) !void {
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    const mode = args.next() orelse "census";
    const gpa = std.heap.page_allocator;

    if (std.mem.eql(u8, mode, "pinrule-census")) {
        try run_census_mode(gpa);
    } else if (std.mem.eql(u8, mode, "pinrule-diag6")) {
        const reach = try build_reach(gpa);
        const L_s = try gpa.alloc(i8, TOTAL_STATES);
        const H_s = try gpa.alloc(i8, TOTAL_STATES);
        const L_c = try gpa.alloc(i8, TOTAL_STATES);
        const H_c = try gpa.alloc(i8, TOTAL_STATES);
        _ = fixpoint_as_shipped(reach, L_s, H_s);
        _ = fixpoint_corrected(reach, L_c, H_c);
        run_diag6(reach, L_s, H_s, L_c, H_c);
    } else if (std.mem.eql(u8, mode, "pinrule-battery")) {
        var seed: u64 = 0x9EF1;
        var sample: u32 = 64;
        var budget: u64 = 200_000;
        while (args.next()) |a| {
            if (std.mem.eql(u8, a, "--seed")) {
                seed = std.fmt.parseInt(u64, args.next() orelse "0", 0) catch 0;
            } else if (std.mem.eql(u8, a, "--sample")) {
                sample = std.fmt.parseInt(u32, args.next() orelse "64", 0) catch 64;
            } else if (std.mem.eql(u8, a, "--node-budget")) {
                budget = std.fmt.parseInt(u64, args.next() orelse "200000", 0) catch 200_000;
            }
        }
        try run_battery(gpa, seed, sample, budget);
    } else if (std.mem.eql(u8, mode, "pinrule-eval")) {
        var seed: u64 = 0x9EF1;
        var node_budget: u64 = 5_000_000;
        var k_long: u32 = 2;
        var max_states: u32 = 0;
        var cross_every: u32 = 5;
        while (args.next()) |a| {
            if (std.mem.eql(u8, a, "--seed")) {
                seed = std.fmt.parseInt(u64, args.next() orelse "0", 0) catch 0;
            } else if (std.mem.eql(u8, a, "--node-budget")) {
                node_budget = std.fmt.parseInt(u64, args.next() orelse "5000000", 0) catch 5_000_000;
            } else if (std.mem.eql(u8, a, "--k-long")) {
                k_long = std.fmt.parseInt(u32, args.next() orelse "2", 0) catch 2;
            } else if (std.mem.eql(u8, a, "--max-states")) {
                max_states = std.fmt.parseInt(u32, args.next() orelse "0", 0) catch 0;
            } else if (std.mem.eql(u8, a, "--cross-every")) {
                cross_every = std.fmt.parseInt(u32, args.next() orelse "5", 0) catch 5;
            }
        }
        try run_eval_mode(gpa, seed, node_budget, k_long, max_states, cross_every);
    } else if (std.mem.eql(u8, mode, "pinrule-state")) {
        // pinrule-state <board> <side> <ko> <passes> [--seed N] [--node-budget N] [--k-long N]
        const b_in = std.fmt.parseInt(u32, args.next() orelse "0", 0) catch 0;
        const s_in = std.fmt.parseInt(u8, args.next() orelse "0", 0) catch 0;
        const k_in = std.fmt.parseInt(u16, args.next() orelse "6", 0) catch 6;
        const p_in = std.fmt.parseInt(u8, args.next() orelse "0", 0) catch 0;
        var seed: u64 = 0x9EF1;
        var budget: u64 = 5_000_000;
        var k_long: u32 = 4;
        while (args.next()) |a| {
            if (std.mem.eql(u8, a, "--seed")) {
                seed = std.fmt.parseInt(u64, args.next() orelse "0", 0) catch 0;
            } else if (std.mem.eql(u8, a, "--node-budget")) {
                budget = std.fmt.parseInt(u64, args.next() orelse "5000000", 0) catch 5_000_000;
            } else if (std.mem.eql(u8, a, "--k-long")) {
                k_long = std.fmt.parseInt(u32, args.next() orelse "4", 0) catch 4;
            }
        }
        try run_state_mode(gpa, b_in, s_in, k_in, p_in, seed, budget, k_long);
    } else {
        std.debug.print("usage: qa023_pinrule [pinrule-census|pinrule-diag6|pinrule-battery|pinrule-eval|pinrule-state] [flags]\n", .{});
        return error.UnknownMode;
    }
}
