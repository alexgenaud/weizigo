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
// EXP-4 — 2×2 and 3×2 under the new rule: the falsification gate.
//
// Task: EXP-4 · Role: worker · Model: DSPro · Date: 2026-07-29
//
// Per `docs/infra/dispatch/EXP-4.md`:
//   Under area scoring, komi 0, basic ko, and a fixed-value verdict for
//   long cycles (TIE = 0) — the rule EXP-2 pinned down — what is the
//   game-theoretic value of the empty board at 2×2 and at 3×2?
//
// Both must return 0 (MIGOS II published anchors; PSK returns +1).
//
// Build:
//   tools/runner -- zig run -O ReleaseFast src/exp4_solve.zig

const std = @import("std");

// =========================================================================
// Constants
// =========================================================================
const TIE: i8 = 0;

// =========================================================================
// 2×2 solver — using Brute2x2 state encoding, fixpoint via median pin
// =========================================================================
const Brute2x2 = @import("qa023_brute_2x2.zig");
const N2_TOTAL: usize = Brute2x2.TOTAL_STATES; // 1620
const N2_N: usize = 4;

const Fixpoint2x2 = struct {
    L: [N2_TOTAL]i8,
    H: [N2_TOTAL]i8,
    sweeps: u32,
    converged: bool,

    fn v(t: *const @This(), idx: usize) i8 {
        return @max(t.L[idx], @min(TIE, t.H[idx]));
    }
};

fn run_fixpoint_2x2() Fixpoint2x2 {
    var t = Fixpoint2x2{
        .L = [_]i8{-4} ** N2_TOTAL,
        .H = [_]i8{4} ** N2_TOTAL,
        .sweeps = 0,
        .converged = false,
    };
    for (0..N2_TOTAL) |i| {
        const s = Brute2x2.state_from_index(i);
        if (s.passes == 2) {
            const a = s.terminal_value();
            t.L[i] = a;
            t.H[i] = a;
        }
    }
    const MAX_SWEEPS: u32 = 64;
    while (t.sweeps < MAX_SWEEPS) {
        t.sweeps += 1;
        var changed: u64 = 0;
        for (0..N2_TOTAL) |i| {
            const s = Brute2x2.state_from_index(i);
            if (s.passes == 2) continue;
            const maximizing = s.side > 0;
            var bl: ?i8 = null;
            var bh: ?i8 = null;
            var succs: [5]Brute2x2.State = undefined;
            var m: usize = 0;
            if (Brute2x2.State.apply_pass(s)) |ns| { succs[m] = ns; m += 1; }
            for (0..N2_N) |cell| {
                if (Brute2x2.State.apply_place(s, @intCast(cell))) |ns| { succs[m] = ns; m += 1; }
            }
            for (succs[0..m]) |ns| {
                const ci = Brute2x2.global_index(ns);
                const vl = t.L[ci];
                const vh = t.H[ci];
                if (bl == null or (if (maximizing) vl > bl.? else vl < bl.?)) bl = vl;
                if (bh == null or (if (maximizing) vh > bh.? else vh < bh.?)) bh = vh;
            }
            if (bl.? != t.L[i]) { t.L[i] = bl.?; changed += 1; }
            if (bh.? != t.H[i]) { t.H[i] = bh.?; changed += 1; }
        }
        if (changed == 0) {
            t.converged = true;
            break;
        }
    }
    return t;
}

// =========================================================================
// 3×2 solver — self-contained state encoding, fixpoint, brute-force ref
// =========================================================================

const W3: usize = 3;
const H3: usize = 2;
const n3: usize = W3 * H3; // 6
const KO_DIMS: usize = n3 + 1; // 7
const RAW_TOTAL: u64 = std.math.pow(u64, 3, n3); // 729
const TOTAL3: u64 = RAW_TOTAL * 2 * KO_DIMS * 3; // 30618

const Pos3 = [n3]i8;
const KO_NONE3: u16 = @intCast(n3);

const StateIdx = packed struct {
    board: u32,
    side: u8, // 0 = Black (+1), 1 = White (-1)
    ko: u16,
    passes: u8, // 0, 1, 2

    fn linear(self: StateIdx) u64 {
        return (((@as(u64, self.passes) * 2) + @as(u64, self.side)) * KO_DIMS + @as(u64, self.ko)) * RAW_TOTAL + self.board;
    }
};

fn unrank_board3(idx: u32) Pos3 {
    var board: Pos3 = [_]i8{0} ** n3;
    var v: u32 = idx;
    for (0..n3) |i| {
        const d = v % 3;
        v /= 3;
        board[i] = switch (d) { 0 => 0, 1 => 1, 2 => -1, else => unreachable };
    }
    return board;
}

fn rank_board3(board: Pos3) u32 {
    var idx: u32 = 0;
    var mult: u32 = 1;
    for (board) |c| {
        const d: u32 = if (c > 0) 1 else if (c < 0) 2 else 0;
        idx += d * mult;
        mult *= 3;
    }
    return idx;
}

fn neighbors3(p: usize, buf: *[4]usize) usize {
    var cnt: usize = 0;
    const r = p / W3;
    const c = p % W3;
    if (r > 0) { buf[cnt] = p - W3; cnt += 1; }
    if (r + 1 < H3) { buf[cnt] = p + W3; cnt += 1; }
    if (c > 0) { buf[cnt] = p - 1; cnt += 1; }
    if (c + 1 < W3) { buf[cnt] = p + 1; cnt += 1; }
    return cnt;
}

fn chain_captured3(pos: *const Pos3, seed: usize, chain: *[n3]usize, chain_len: *usize) bool {
    const colour: i8 = if (pos[seed] > 0) 1 else -1;
    var visited = [_]bool{false} ** n3;
    var stack: [n3]usize = undefined;
    var sp: usize = 1;
    chain[0] = seed;
    visited[seed] = true;
    stack[0] = seed;
    var len: usize = 1;
    var has_liberty = false;
    while (sp > 0) {
        sp -= 1;
        const q = stack[sp];
        var nb: [4]usize = undefined;
        const cnt = neighbors3(q, &nb);
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

fn pos_from_move3(pos: *const Pos3, colour: i8, cell: usize) !Pos3 {
    if (pos[cell] != 0) return error.Occupied;
    var next: Pos3 = undefined;
    for (0..n3) |i| next[i] = if (pos[i] > 0) 1 else if (pos[i] < 0) -1 else 0;
    next[cell] = colour;
    var nb: [4]usize = undefined;
    const cnt = neighbors3(cell, &nb);
    var chain: [n3]usize = undefined;
    var chain_len: usize = 0;
    for (nb[0..cnt]) |q| {
        if (next[q] * colour < 0) {
            if (chain_captured3(&next, q, &chain, &chain_len)) {
                for (chain[0..chain_len]) |c| next[c] = 0;
            }
        }
    }
    if (chain_captured3(&next, cell, &chain, &chain_len)) return error.Suicide;
    return next;
}

fn is_legal3(pos: *const Pos3) bool {
    var visited = [_]bool{false} ** n3;
    for (0..n3) |p| {
        if (pos[p] == 0 or visited[p]) continue;
        const colour = pos[p];
        var stack: [n3]usize = undefined;
        var sp: usize = 1;
        stack[0] = p;
        visited[p] = true;
        var has_liberty = false;
        while (sp > 0) {
            sp -= 1;
            const q = stack[sp];
            var nb: [4]usize = undefined;
            const cnt = neighbors3(q, &nb);
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

fn area_score3(board: *const Pos3) i8 {
    var black: i16 = 0;
    var white: i16 = 0;
    var visited = [_]bool{false} ** n3;
    for (0..n3) |p| {
        if (board[p] > 0) { black += 1; continue; }
        if (board[p] < 0) { white += 1; continue; }
        if (visited[p]) continue;
        var stack: [n3]usize = undefined;
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
            const cnt = neighbors3(q, &nb);
            for (nb[0..cnt]) |r| {
                if (board[r] > 0) tb = true
                else if (board[r] < 0) tw = true
                else if (!visited[r]) {
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

fn apply_place3(state: StateIdx, board: *const Pos3, colour: i8, cell: u8) ?StateIdx {
    if (board[cell] != 0) return null;
    if (state.ko != n3 and cell == state.ko) return null;
    const next_board = pos_from_move3(board, colour, cell) catch return null;
    var opp_before: u8 = 0;
    var opp_after: u8 = 0;
    var captured_cell: u8 = KO_NONE3;
    for (0..n3) |i| {
        if (board[i] == -colour) opp_before += 1;
        if (next_board[i] == -colour) opp_after += 1;
        if (board[i] == -colour and next_board[i] == 0) captured_cell = @intCast(i);
    }
    var new_ko: u16 = KO_NONE3;
    if ((opp_before - opp_after == 1) and (captured_cell != KO_NONE3)) {
        var liberties: u8 = 0;
        var friendly: u8 = 0;
        var nb: [4]usize = undefined;
        const cnt = neighbors3(cell, &nb);
        for (nb[0..cnt]) |q| {
            if (next_board[q] == 0) liberties += 1;
            if (next_board[q] == colour) friendly += 1;
        }
        if (liberties == 1 and friendly == 0) new_ko = captured_cell;
    }
    return StateIdx{
        .board = rank_board3(next_board),
        .side = if (colour == 1) @as(u8, 1) else @as(u8, 0),
        .ko = new_ko,
        .passes = 0,
    };
}

fn apply_pass3(state: StateIdx) ?StateIdx {
    if (state.passes >= 2) return null;
    return StateIdx{
        .board = state.board,
        .side = 1 - state.side,
        .ko = KO_NONE3,
        .passes = state.passes + 1,
    };
}

fn moves3(state: StateIdx, succ_boards: *[n3 + 1]Pos3, succs: *[n3 + 1]StateIdx) usize {
    if (state.passes == 2) return 0;
    const board = unrank_board3(state.board);
    const colour: i8 = if (state.side == 0) 1 else -1;
    var count: usize = 0;
    if (apply_pass3(state)) |ns| {
        succ_boards[count] = unrank_board3(ns.board);
        succs[count] = ns;
        count += 1;
    }
    for (0..n3) |cell_u| {
        const cell: u8 = @intCast(cell_u);
        if (apply_place3(state, &board, colour, cell)) |ns| {
            succ_boards[count] = unrank_board3(ns.board);
            succs[count] = ns;
            count += 1;
        }
    }
    return count;
}

// ---- 3×2 Census ----------------------------------------------------------

const ReachWords3: u64 = (TOTAL3 + 63) / 64;

const CensusResult3 = struct {
    total_marked: u64,
    legal_boards: u64,
    terminal_marked: u64,
    side_marked: [2]u64,
    sweeps: u32,
};

fn run_census_3x2(gpa: std.mem.Allocator, reach: []u64) !CensusResult3 {
    @memset(reach, 0);
    const snap = try gpa.alloc(u64, ReachWords3);
    defer gpa.free(snap);

    for ([_]u8{ 0, 1 }) |side| {
        for ([_]u8{ 0, 1 }) |passes| {
            const root = StateIdx{ .board = 0, .side = side, .ko = KO_NONE3, .passes = passes };
            const lin = root.linear();
            reach[lin >> 6] |= @as(u64, 1) << @intCast(lin & 63);
        }
    }

    var new_marks: u64 = 1;
    var sweep_idx: u32 = 0;
    const MAX_SWEEPS: u32 = 64;
    while (new_marks > 0 and sweep_idx < MAX_SWEEPS) {
        @memcpy(snap, reach);
        new_marks = 0;
        var linear: u64 = 0;
        while (linear < TOTAL3) : (linear += 1) {
            const word = linear >> 6;
            const bit: u64 = @as(u64, 1) << @intCast(linear & 63);
            if (snap[word] & bit == 0) continue;
            const passes: u8 = @intCast(linear / (2 * KO_DIMS * RAW_TOTAL));
            const rest: u64 = linear % (2 * KO_DIMS * RAW_TOTAL);
            const side: u8 = @intCast(rest / (KO_DIMS * RAW_TOTAL));
            const rest2: u64 = rest % (KO_DIMS * RAW_TOTAL);
            const ko: u16 = @intCast(rest2 / RAW_TOTAL);
            const board: u32 = @intCast(rest2 % RAW_TOTAL);
            const state = StateIdx{ .board = board, .side = side, .ko = ko, .passes = passes };
            var succ_boards: [n3 + 1]Pos3 = undefined;
            var succs: [n3 + 1]StateIdx = undefined;
            const m = moves3(state, &succ_boards, &succs);
            for (0..m) |k| {
                if (!is_legal3(&succ_boards[k])) continue;
                const child_linear = succs[k].linear();
                const child_word = child_linear >> 6;
                const child_bit: u64 = @as(u64, 1) << @intCast(child_linear & 63);
                if (reach[child_word] & child_bit == 0) {
                    reach[child_word] |= child_bit;
                    new_marks += 1;
                }
            }
        }
        sweep_idx += 1;
        if (sweep_idx % 8 == 0 or new_marks == 0) {
            std.debug.print("# 3x2 census sweep {d}: new_marks = {d}\n", .{ sweep_idx, new_marks });
        }
    }

    var total_marked: u64 = 0;
    var terminal_marked: u64 = 0;
    var side_marked: [2]u64 = [_]u64{ 0, 0 };
    var legal_boards: u64 = 0;
    var seen_boards = [_]bool{false} ** @as(usize, RAW_TOTAL);
    var linear: u64 = 0;
    while (linear < TOTAL3) : (linear += 1) {
        const word = linear >> 6;
        const bit: u64 = @as(u64, 1) << @intCast(linear & 63);
        if (reach[word] & bit == 0) continue;
        total_marked += 1;
        const passes: u8 = @intCast(linear / (2 * KO_DIMS * RAW_TOTAL));
        if (passes == 2) terminal_marked += 1;
        const rest: u64 = linear % (2 * KO_DIMS * RAW_TOTAL);
        const side: u8 = @intCast(rest / (KO_DIMS * RAW_TOTAL));
        side_marked[side] += 1;
        const rest2: u64 = rest % (KO_DIMS * RAW_TOTAL);
        const board_idx: u32 = @intCast(rest2 % RAW_TOTAL);
        if (is_legal3(&unrank_board3(board_idx)) and !seen_boards[board_idx]) {
            seen_boards[board_idx] = true;
            legal_boards += 1;
        }
    }
    return CensusResult3{
        .total_marked = total_marked,
        .legal_boards = legal_boards,
        .terminal_marked = terminal_marked,
        .side_marked = side_marked,
        .sweeps = sweep_idx,
    };
}

// ---- 3×2 Fixpoint --------------------------------------------------------

const FixpointResult3 = struct {
    sweeps: u32,
    converged: bool,
};

fn median3(L: i8, H: i8) i8 {
    return @max(L, @min(TIE, H));
}

fn run_fixpoint_3x2(reach: []const u64, L_tab: []i8, H_tab: []i8) FixpointResult3 {
    const L_init: i8 = -@as(i8, @intCast(n3));
    const H_init: i8 = @as(i8, @intCast(n3));
    for (0..TOTAL3) |i| {
        L_tab[i] = L_init;
        H_tab[i] = H_init;
    }
    var lin: u64 = 0;
    while (lin < TOTAL3) : (lin += 1) {
        const word = lin >> 6;
        const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
        if (reach[word] & bit == 0) continue;
        const passes: u8 = @intCast(lin / (2 * KO_DIMS * RAW_TOTAL));
        if (passes == 2) {
            const rest: u64 = lin % (2 * KO_DIMS * RAW_TOTAL);
            const rest2: u64 = rest % (KO_DIMS * RAW_TOTAL);
            const board_idx: u32 = @intCast(rest2 % RAW_TOTAL);
            const b = unrank_board3(board_idx);
            L_tab[lin] = area_score3(&b);
            H_tab[lin] = area_score3(&b);
        }
    }
    var sweep_idx: u32 = 0;
    var total_changes: u64 = 1;
    const MAX_SWEEPS: u32 = 64;
    while (total_changes > 0 and sweep_idx < MAX_SWEEPS) {
        sweep_idx += 1;
        total_changes = 0;

        var l_changed: u64 = 0;
        var li: u64 = 0;
        while (li < TOTAL3) : (li += 1) {
            const word = li >> 6;
            const bit: u64 = @as(u64, 1) << @intCast(li & 63);
            if (reach[word] & bit == 0) continue;
            const passes: u8 = @intCast(li / (2 * KO_DIMS * RAW_TOTAL));
            if (passes == 2) continue;
            const rest: u64 = li % (2 * KO_DIMS * RAW_TOTAL);
            const side: u8 = @intCast(rest / (KO_DIMS * RAW_TOTAL));
            const rest2: u64 = rest % (KO_DIMS * RAW_TOTAL);
            const ko: u16 = @intCast(rest2 / RAW_TOTAL);
            const board: u32 = @intCast(rest2 % RAW_TOTAL);
            const state = StateIdx{ .board = board, .side = side, .ko = ko, .passes = passes };
            var succ_boards: [n3 + 1]Pos3 = undefined;
            var succs: [n3 + 1]StateIdx = undefined;
            const m = moves3(state, &succ_boards, &succs);
            const maximizing = side == 0;
            var best_l: ?i8 = null;
            var best_h: ?i8 = null;
            for (0..m) |k| {
                if (!is_legal3(&succ_boards[k])) continue;
                const child_li = succs[k].linear();
                const vl = L_tab[child_li];
                const vh = H_tab[child_li];
                if (best_l == null or (if (maximizing) vl > best_l.? else vl < best_l.?)) best_l = vl;
                if (best_h == null or (if (maximizing) vh > best_h.? else vh < best_h.?)) best_h = vh;
            }
            if (best_l != null and best_l.? != L_tab[li]) { L_tab[li] = best_l.?; l_changed += 1; }
            if (best_h != null and best_h.? != H_tab[li]) { H_tab[li] = best_h.?; l_changed += 1; }
        }

        // H sweep is identical to L sweep per ADR-0009 (same operator).
        // The only difference is seed (+n vs -n) and monotonicity direction.
        // After L sweep, we do a second pass for H convergence.
        var h_changed: u64 = 0;
        var hi: u64 = 0;
        while (hi < TOTAL3) : (hi += 1) {
            const word = hi >> 6;
            const bit: u64 = @as(u64, 1) << @intCast(hi & 63);
            if (reach[word] & bit == 0) continue;
            const passes: u8 = @intCast(hi / (2 * KO_DIMS * RAW_TOTAL));
            if (passes == 2) continue;
            const rest: u64 = hi % (2 * KO_DIMS * RAW_TOTAL);
            const side: u8 = @intCast(rest / (KO_DIMS * RAW_TOTAL));
            const rest2: u64 = rest % (KO_DIMS * RAW_TOTAL);
            const ko: u16 = @intCast(rest2 / RAW_TOTAL);
            const board: u32 = @intCast(rest2 % RAW_TOTAL);
            const state = StateIdx{ .board = board, .side = side, .ko = ko, .passes = passes };
            var succ_boards: [n3 + 1]Pos3 = undefined;
            var succs: [n3 + 1]StateIdx = undefined;
            const m = moves3(state, &succ_boards, &succs);
            const maximizing = side == 0;
            var best_h2: ?i8 = null;
            for (0..m) |k| {
                if (!is_legal3(&succ_boards[k])) continue;
                const child_li = succs[k].linear();
                const vh = H_tab[child_li];
                if (best_h2 == null or (if (maximizing) vh > best_h2.? else vh < best_h2.?)) best_h2 = vh;
            }
            if (best_h2 != null and best_h2.? != H_tab[hi]) { H_tab[hi] = best_h2.?; h_changed += 1; }
        }
        total_changes = l_changed + h_changed;
        if (sweep_idx % 4 == 0 or total_changes == 0) {
            std.debug.print("# 3x2 fixpoint sweep {d}: L_changed={d} H_changed={d}\n", .{ sweep_idx, l_changed, h_changed });
        }
    }
    return FixpointResult3{ .sweeps = sweep_idx, .converged = total_changes == 0 };
}

// ---- 2×2 Brute-force (first-revisit truncation, budget-aware) ---------------

/// Budget-aware minimax with first-revisit truncation for 2×2.
/// Uses Brute2x2 state encoding. Returns null if budget exhausted.
fn brute_value_2x2(
    state: Brute2x2.State,
    history_set: []u64,
    depth: u32,
    node_budget: *u64,
    succs_buf: *[5]Brute2x2.State,
) ?i8 {
    if (node_budget.* == 0) return null;
    node_budget.* -= 1;

    const idx = Brute2x2.global_index(state);
    if (history_set[idx >> 6] & (@as(u64, 1) << @intCast(idx & 63)) != 0) return TIE;

    if (state.passes == 2) return state.terminal_value();
    if (depth > 128) return TIE;

    const prev_bit = history_set[idx >> 6] & (@as(u64, 1) << @intCast(idx & 63));
    history_set[idx >> 6] |= @as(u64, 1) << @intCast(idx & 63);

    const maximizing = state.side > 0;
    var m: usize = 0;
    if (Brute2x2.State.apply_pass(state)) |ns| { succs_buf[m] = ns; m += 1; }
    for (0..N2_N) |cell| {
        if (Brute2x2.State.apply_place(state, @intCast(cell))) |ns| { succs_buf[m] = ns; m += 1; }
    }

    var best: ?i8 = null;
    for (succs_buf[0..m]) |child| {
        const v = brute_value_2x2(child, history_set, depth + 1, node_budget, succs_buf);
        if (v == null) {
            if (prev_bit == 0) history_set[idx >> 6] &= ~(@as(u64, 1) << @intCast(idx & 63));
            return null;
        }
        if (best == null or (if (maximizing) v.? > best.? else v.? < best.?)) best = v;
    }

    if (prev_bit == 0) history_set[idx >> 6] &= ~(@as(u64, 1) << @intCast(idx & 63));
    if (best == null) return state.terminal_value();
    return best;
}

// ---- 3×2 Brute-force (first-revisit truncation) --------------------------

fn brute_value_3x2(
    state: StateIdx,
    history_set: []u64,
    depth: u32,
    node_budget: *u64,
    succ_boards_buf: *[n3 + 1]Pos3,
    succs_buf: *[n3 + 1]StateIdx,
) ?i8 {
    if (node_budget.* == 0) return null;
    node_budget.* -= 1;

    const lin = state.linear();
    if (history_set[lin >> 6] & (@as(u64, 1) << @intCast(lin & 63)) != 0) return TIE;

    if (state.passes == 2) {
        const board = unrank_board3(state.board);
        return area_score3(&board);
    }

    if (depth > 128) return TIE;

    const prev_bit = history_set[lin >> 6] & (@as(u64, 1) << @intCast(lin & 63));
    history_set[lin >> 6] |= @as(u64, 1) << @intCast(lin & 63);

    const m = moves3(state, succ_boards_buf, succs_buf);
    const maximizing = state.side == 0;

    var best: ?i8 = null;
    for (0..m) |k| {
        if (!is_legal3(&succ_boards_buf[k])) continue;
        const child = succs_buf[k];
        const v = brute_value_3x2(child, history_set, depth + 1, node_budget, succ_boards_buf, succs_buf);
        if (v == null) {
            if (prev_bit == 0) history_set[lin >> 6] &= ~(@as(u64, 1) << @intCast(lin & 63));
            return null;
        }
        if (best == null or (if (maximizing) v.? > best.? else v.? < best.?)) best = v;
    }

    if (prev_bit == 0) history_set[lin >> 6] &= ~(@as(u64, 1) << @intCast(lin & 63));

    if (best == null) {
        const board = unrank_board3(state.board);
        return area_score3(&board);
    }
    return best;
}

// =========================================================================
// Colour inversion helpers
// =========================================================================

fn invert_board_2x2(board: *const [N2_N]i8) [N2_N]i8 {
    var inv: [N2_N]i8 = undefined;
    for (0..N2_N) |i| inv[i] = -board[i];
    return inv;
}

fn invert_board_3x3(board: *const Pos3) Pos3 {
    var inv: Pos3 = undefined;
    for (0..n3) |i| inv[i] = -board[i];
    return inv;
}

fn invert_state_2x2(s: Brute2x2.State) Brute2x2.State {
    return Brute2x2.State{
        .board = invert_board_2x2(&s.board),
        .side = -s.side,
        .ko_point = if (s.ko_point == Brute2x2.State.KO_NONE) Brute2x2.State.KO_NONE else s.ko_point,
        .passes = s.passes,
    };
}

fn invert_state_3x2(s: StateIdx) StateIdx {
    const board = unrank_board3(s.board);
    const inv_board = invert_board_3x3(&board);
    return StateIdx{
        .board = rank_board3(inv_board),
        .side = 1 - s.side,
        .ko = s.ko,
        .passes = s.passes,
    };
}

// =========================================================================
// Main
// =========================================================================

pub fn main() !void {
    const gpa = std.heap.page_allocator;

    std.debug.print("# ============================================================================\n", .{});
    std.debug.print("# EXP-4 — 2×2 and 3×2 under the new rule: the falsification gate\n", .{});
    std.debug.print("# Task: EXP-4 · Role: worker · Model: DSPro · Date: 2026-07-29\n", .{});
    std.debug.print("# Rule: basic ko (formalization (i)) + TIE = {d} for long cycles\n", .{TIE});
    std.debug.print("# Value rule: V = median(L, TIE, H) = max(L, min(TIE, H))\n", .{});
    std.debug.print("# ============================================================================\n", .{});

    // =====================================================================
    // PART 1: 2×2 — Fixpoint
    // =====================================================================
    std.debug.print("\n## 1. 2×2 fixpoint\n", .{});

    const fp2 = run_fixpoint_2x2();
    std.debug.print("# sweeps: {d}, converged: {}\n", .{ fp2.sweeps, fp2.converged });

    const s_root_b = Brute2x2.State{ .board = .{0} ** N2_N, .side = 1, .ko_point = Brute2x2.State.KO_NONE, .passes = 0 };
    const s_root_w = Brute2x2.State{ .board = .{0} ** N2_N, .side = -1, .ko_point = Brute2x2.State.KO_NONE, .passes = 0 };
    const idx_root_b = Brute2x2.global_index(s_root_b);
    const idx_root_w = Brute2x2.global_index(s_root_w);

    const v2_root_b = fp2.v(idx_root_b);
    const v2_root_w = fp2.v(idx_root_w);
    const L2_root_b = fp2.L[idx_root_b];
    const H2_root_b = fp2.H[idx_root_b];
    const L2_root_w = fp2.L[idx_root_w];
    const H2_root_w = fp2.H[idx_root_w];

    std.debug.print("# root (empty, B to move):  L={d:>3} H={d:>3} V={d:>3}\n", .{ L2_root_b, H2_root_b, v2_root_b });
    std.debug.print("# root (empty, W to move):  L={d:>3} H={d:>3} V={d:>3}\n", .{ L2_root_w, H2_root_w, v2_root_w });

    const gate2 = v2_root_b == 0 and v2_root_w == 0;
    std.debug.print("# gate (0 on both): {s}\n", .{if (gate2) "PASS" else "FAIL — +1 would be PSK"});

    const tie_or_scored_2_b = if (L2_root_b == H2_root_b) "scored 0 (L==H==0)" else if (L2_root_b < TIE and TIE < H2_root_b) "TIE (L<0<H, pinned)" else "unexpected";
    const tie_or_scored_2_w = if (L2_root_w == H2_root_w) "scored 0 (L==H==0)" else if (L2_root_w < TIE and TIE < H2_root_w) "TIE (L<0<H, pinned)" else "unexpected";
    std.debug.print("# 2×2 empty B: {s}\n", .{tie_or_scored_2_b});
    std.debug.print("# 2×2 empty W: {s}\n", .{tie_or_scored_2_w});

    // Every state defined?
    {
        var visited = try std.DynamicBitSetUnmanaged.initEmpty(gpa, N2_TOTAL);
        defer visited.deinit(gpa);
        try Brute2x2.mark_reachable(s_root_b, &visited, gpa);
        try Brute2x2.mark_reachable(s_root_w, &visited, gpa);

        var reachable_count: u64 = 0;
        var undef_count: u64 = 0;
        var it = visited.iterator(.{});
        while (it.next()) |idx| {
            reachable_count += 1;
            if (fp2.v(idx) == -128) undef_count += 1;
        }
        std.debug.print("# 2×2 reachable states: {d}, UNDEF: {d}\n", .{ reachable_count, undef_count });
        std.debug.print("# root filled? {s}\n", .{if (undef_count == 0) "YES" else "NO"});
    }

    // =====================================================================
    // PART 2: 2×2 — Cross-check (brute-force anchors + Bellman consistency)
    // =====================================================================
    std.debug.print("\n## 2. 2×2 cross-check (brute-force anchors + Bellman self-consistency)\n", .{});

    // 2a. Brute-force anchors via budget-aware first-revisit truncation.
    // Path-enumeration DFS is exponential; we use a node budget to keep it
    // tractable for individual anchor states.
    {
        const hist_words_2 = (N2_TOTAL + 63) / 64;
        const history_set = try gpa.alloc(u64, hist_words_2);
        defer gpa.free(history_set);
        var succs_buf: [5]Brute2x2.State = undefined;

        const anchors = [_]struct { name: []const u8, state: Brute2x2.State, expected: i8 }{
            .{ .name = "empty B", .state = s_root_b, .expected = 0 },
            .{ .name = "empty W", .state = s_root_w, .expected = 0 },
            .{ .name = "full B", .state = Brute2x2.State{ .board = .{ 1, 1, 1, 1 }, .side = 1, .ko_point = Brute2x2.State.KO_NONE, .passes = 0 }, .expected = 4 },
            .{ .name = "full W", .state = Brute2x2.State{ .board = .{ -1, -1, -1, -1 }, .side = 1, .ko_point = Brute2x2.State.KO_NONE, .passes = 0 }, .expected = -4 },
            .{ .name = "passes=1", .state = Brute2x2.State{ .board = .{0} ** 4, .side = -1, .ko_point = Brute2x2.State.KO_NONE, .passes = 1 }, .expected = 0 },
            .{ .name = "passes=2", .state = Brute2x2.State{ .board = .{0} ** 4, .side = 1, .ko_point = Brute2x2.State.KO_NONE, .passes = 2 }, .expected = 0 },
            .{ .name = "1-ko shape", .state = Brute2x2.State{ .board = .{ -1, 1, 0, 0 }, .side = -1, .ko_point = Brute2x2.State.KO_NONE, .passes = 0 }, .expected = 0 },
        };
        var anchor_ok = true;
        for (anchors) |a| {
            @memset(history_set, 0);
            var node_budget: u64 = 1_000_000;
            const bf_val = brute_value_2x2(a.state, history_set, 0, &node_budget, &succs_buf);
            const idx = Brute2x2.global_index(a.state);
            const fp_val = fp2.v(idx);
            const ok = bf_val != null and bf_val.? == fp_val and bf_val.? == a.expected;
            if (!ok) anchor_ok = false;
            std.debug.print("#   anchor {s}: fixpoint={d} brute={?d} expected={d} {s}\n", .{ a.name, fp_val, bf_val, a.expected, if (ok) "OK" else if (bf_val == null) "BUDGET-EXHAUSTED" else "FAIL" });
        }
        std.debug.print("# brute-force anchors: {s}\n", .{if (anchor_ok) "PASS — all anchors match" else "FAIL or INCONCLUSIVE"});
    }

    // 2b. Fixpoint self-consistency: L = Φ(L) and H = Φ(H) on reachable states.
    // NOTE: V = median(L,T,H) is NOT guaranteed to be a fixpoint of Φ.
    // The correct check verifies L and H individually satisfy the Bellman eq.
    {
        var visited = try std.DynamicBitSetUnmanaged.initEmpty(gpa, N2_TOTAL);
        defer visited.deinit(gpa);
        try Brute2x2.mark_reachable(s_root_b, &visited, gpa);
        try Brute2x2.mark_reachable(s_root_w, &visited, gpa);

        var l_fail: u64 = 0;
        var h_fail: u64 = 0;
        var checked: u64 = 0;
        var terminal_count: u64 = 0;
        var it = visited.iterator(.{});
        while (it.next()) |idx| {
            const s = Brute2x2.state_from_index(idx);
            if (s.passes == 2) { terminal_count += 1; continue; }
            checked += 1;
            const maximizing = s.side > 0;
            var bl: ?i8 = null;
            var bh: ?i8 = null;
            var succs: [5]Brute2x2.State = undefined;
            var m: usize = 0;
            if (Brute2x2.State.apply_pass(s)) |ns| { succs[m] = ns; m += 1; }
            for (0..N2_N) |cell| {
                if (Brute2x2.State.apply_place(s, @intCast(cell))) |ns| { succs[m] = ns; m += 1; }
            }
            for (succs[0..m]) |ns| {
                const ci = Brute2x2.global_index(ns);
                const vl = fp2.L[ci];
                const vh = fp2.H[ci];
                if (bl == null or (if (maximizing) vl > bl.? else vl < bl.?)) bl = vl;
                if (bh == null or (if (maximizing) vh > bh.? else vh < bh.?)) bh = vh;
            }
            if (bl == null or bl.? != fp2.L[idx]) {
                l_fail += 1;
                if (l_fail <= 3) std.debug.print("# L-FIXPOINT-FAIL idx={d}: L={d} Φ(L)={?d}\n", .{ idx, fp2.L[idx], bl });
            }
            if (bh == null or bh.? != fp2.H[idx]) {
                h_fail += 1;
                if (h_fail <= 3) std.debug.print("# H-FIXPOINT-FAIL idx={d}: H={d} Φ(H)={?d}\n", .{ idx, fp2.H[idx], bh });
            }
        }
        std.debug.print("# Fixpoint consistency ({d} non-terminals): L-fail={d} H-fail={d} terminals={d}\n", .{ checked, l_fail, h_fail, terminal_count });
        std.debug.print("# Fixpoint check: {s}\n", .{if (l_fail == 0 and h_fail == 0) "PASS — L=Φ(L), H=Φ(H) everywhere" else "FAIL"});

    // 2c. Budget-limited brute-force sample for 2×2.
    {
        const hist_words_2 = (N2_TOTAL + 63) / 64;
        const history_set = try gpa.alloc(u64, hist_words_2);
        defer gpa.free(history_set);
        var succs_buf: [5]Brute2x2.State = undefined;
        var sample_agreements: u64 = 0;
        var sample_mismatches: u64 = 0;
        var sample_exhausted: u64 = 0;
        var sample_count: u64 = 0;

        var visited2 = try std.DynamicBitSetUnmanaged.initEmpty(gpa, N2_TOTAL);
        defer visited2.deinit(gpa);
        try Brute2x2.mark_reachable(s_root_b, &visited2, gpa);
        try Brute2x2.mark_reachable(s_root_w, &visited2, gpa);

        var it2 = visited2.iterator(.{});
        while (it2.next()) |idx| {
            if (sample_count >= 200) break;
            const s = Brute2x2.state_from_index(idx);
            if (s.passes == 2) continue; // terminals are trivial
            sample_count += 1;
            @memset(history_set, 0);
            var node_budget: u64 = 500_000;
            const bf_val = brute_value_2x2(s, history_set, 0, &node_budget, &succs_buf);
            const fp_val = fp2.v(idx);
            if (bf_val == null) {
                sample_exhausted += 1;
            } else if (bf_val.? == fp_val) {
                sample_agreements += 1;
            } else {
                sample_mismatches += 1;
                std.debug.print("# MISMATCH 2x2 idx={d}: fixpoint={d} brute={d}\n", .{ idx, fp_val, bf_val.? });
            }
        }
        std.debug.print("# 2x2 brute-force sample ({d} non-terminal states, budget=500k/state):\n", .{sample_count});
        std.debug.print("#   agreements:       {d}\n", .{sample_agreements});
        std.debug.print("#   mismatches:       {d}\n", .{sample_mismatches});
        std.debug.print("#   budget-exhausted: {d}\n", .{sample_exhausted});
        const within2 = sample_agreements + sample_mismatches;
        std.debug.print("# sample cross-check: {s} (denominator: {d} within-budget / {d} total)\n", .{
            if (sample_mismatches == 0) "PASS — no mismatches" else "FAIL — mismatches found",
            within2,
            sample_count,
        });
    }
    }

    // =====================================================================
    // PART 3: 2×2 — Colour-inversion symmetry
    // =====================================================================
    std.debug.print("\n## 3. 2×2 colour-inversion symmetry\n", .{});

    {
        var violations: u64 = 0;
        for (0..N2_TOTAL) |i| {
            const s = Brute2x2.state_from_index(i);
            const s_inv = invert_state_2x2(s);
            const i_inv = Brute2x2.global_index(s_inv);
            const v = fp2.v(i);
            const v_inv = fp2.v(i_inv);
            if (v != -v_inv) {
                violations += 1;
                if (violations <= 5) {
                    std.debug.print("# VIOLATION idx={d}: v={d} v_inv({d})={d} (expected {d})\n", .{ i, v, i_inv, v_inv, -v });
                }
            }
        }
        std.debug.print("# 2×2 inversion violations: {d} / {d}\n", .{ violations, N2_TOTAL });
        std.debug.print("# symmetry: {s}\n", .{if (violations == 0) "PASS — value(-pos,-side) == -value(pos,side)" else "FAIL"});
    }

    // =====================================================================
    // PART 4: 2×2 — Calibration (known-good, known-bad)
    // =====================================================================
    std.debug.print("\n## 4. 2×2 calibration\n", .{});

    // Known-good: 5 anchors.
    {
        const anchors = [_]struct { name: []const u8, state: Brute2x2.State, expected: i8 }{
            .{ .name = "empty B", .state = s_root_b, .expected = 0 },
            .{ .name = "empty W", .state = s_root_w, .expected = 0 },
            .{ .name = "full B", .state = Brute2x2.State{ .board = .{ 1, 1, 1, 1 }, .side = 1, .ko_point = Brute2x2.State.KO_NONE, .passes = 0 }, .expected = 4 },
            .{ .name = "passes=1", .state = Brute2x2.State{ .board = .{0} ** 4, .side = -1, .ko_point = Brute2x2.State.KO_NONE, .passes = 1 }, .expected = 0 },
            .{ .name = "passes=2", .state = Brute2x2.State{ .board = .{0} ** 4, .side = 1, .ko_point = Brute2x2.State.KO_NONE, .passes = 2 }, .expected = 0 },
        };
        var anchor_ok = true;
        for (anchors) |a| {
            const idx = Brute2x2.global_index(a.state);
            const v = fp2.v(idx);
            const ok = v == a.expected;
            if (!ok) anchor_ok = false;
            std.debug.print("#   anchor {s}: v={d} expected={d} {s}\n", .{ a.name, v, a.expected, if (ok) "OK" else "FAIL" });
        }
        std.debug.print("# known-good: {s}\n", .{if (anchor_ok) "PASS — all anchors match" else "FAIL"});
    }

    // Known-bad 1: perturb non-root state and confirm detection.
    {
        var fp_pert = fp2;
        const pert_idx: usize = Brute2x2.global_index(Brute2x2.State{
            .board = .{ 1, 0, 0, 0 },
            .side = -1,
            .ko_point = Brute2x2.State.KO_NONE,
            .passes = 0,
        });
        const orig_val = fp_pert.v(pert_idx);
        fp_pert.L[pert_idx] += 1;
        const pert_val = fp_pert.v(pert_idx);
        std.debug.print("# known-bad (perturb): idx={d} orig={d} perturbed={d} detected={s}\n", .{ pert_idx, orig_val, pert_val, if (orig_val != pert_val) "YES" else "NO — perturbation was silent" });
    }

    // Known-bad 2: fixpoint root = 0 vs PSK root = +1 (gate distinguishes rulesets)
    std.debug.print("# known-bad (PSK vs new rule): fixpoint root = {d}, PSK root = +1, delta = {d} (non-zero => gate distinguishes rulesets)\n", .{ v2_root_b, 1 - v2_root_b });

    // =====================================================================
    // PART 5: 3×2 — Census
    // =====================================================================
    std.debug.print("\n## 5. 3×2 census\n", .{});

    const reach3 = try gpa.alloc(u64, ReachWords3);
    defer gpa.free(reach3);
    const census3 = try run_census_3x2(gpa, reach3);
    std.debug.print("# total reachable: {d}\n", .{census3.total_marked});
    std.debug.print("# legal boards: {d}\n", .{census3.legal_boards});
    std.debug.print("# terminals: {d}\n", .{census3.terminal_marked});
    std.debug.print("# by side: B={d} W={d}\n", .{ census3.side_marked[0], census3.side_marked[1] });
    std.debug.print("# sweeps: {d}\n", .{census3.sweeps});

    // =====================================================================
    // PART 6: 3×2 — Fixpoint
    // =====================================================================
    std.debug.print("\n## 6. 3×2 fixpoint\n", .{});

    const L_tab3 = try gpa.alloc(i8, TOTAL3);
    defer gpa.free(L_tab3);
    const H_tab3 = try gpa.alloc(i8, TOTAL3);
    defer gpa.free(H_tab3);

    const fp_res3 = run_fixpoint_3x2(reach3, L_tab3, H_tab3);
    std.debug.print("# sweeps: {d}, converged: {}\n", .{ fp_res3.sweeps, fp_res3.converged });

    const root3_b = StateIdx{ .board = 0, .side = 0, .ko = KO_NONE3, .passes = 0 };
    const root3_w = StateIdx{ .board = 0, .side = 1, .ko = KO_NONE3, .passes = 0 };
    const root3_b_lin = root3_b.linear();
    const root3_w_lin = root3_w.linear();

    const v3_root_b = median3(L_tab3[root3_b_lin], H_tab3[root3_b_lin]);
    const v3_root_w = median3(L_tab3[root3_w_lin], H_tab3[root3_w_lin]);
    const L3_root_b = L_tab3[root3_b_lin];
    const H3_root_b = H_tab3[root3_b_lin];
    const L3_root_w = L_tab3[root3_w_lin];
    const H3_root_w = H_tab3[root3_w_lin];

    std.debug.print("# root (empty, B to move):  L={d:>3} H={d:>3} V={d:>3}\n", .{ L3_root_b, H3_root_b, v3_root_b });
    std.debug.print("# root (empty, W to move):  L={d:>3} H={d:>3} V={d:>3}\n", .{ L3_root_w, H3_root_w, v3_root_w });

    const gate3 = v3_root_b == 0 and v3_root_w == 0;
    std.debug.print("# gate (0 on both): {s}\n", .{if (gate3) "PASS" else "FAIL — +1 would be PSK"});

    const tie_or_scored_3_b = if (L3_root_b == H3_root_b) "scored 0 (L==H==0)" else if (L3_root_b < TIE and TIE < H3_root_b) "TIE (L<0<H, pinned)" else "unexpected";
    const tie_or_scored_3_w = if (L3_root_w == H3_root_w) "scored 0 (L==H==0)" else if (L3_root_w < TIE and TIE < H3_root_w) "TIE (L<0<H, pinned)" else "unexpected";
    std.debug.print("# 3×2 empty B: {s}\n", .{tie_or_scored_3_b});
    std.debug.print("# 3×2 empty W: {s}\n", .{tie_or_scored_3_w});

    // Every state defined?
    {
        var undef_count: u64 = 0;
        var reachable_count: u64 = 0;
        var lin: u64 = 0;
        while (lin < TOTAL3) : (lin += 1) {
            const word = lin >> 6;
            const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
            if (reach3[word] & bit == 0) continue;
            reachable_count += 1;
            const v = median3(L_tab3[lin], H_tab3[lin]);
            if (v == -128) undef_count += 1;
        }
        std.debug.print("# 3×2 reachable states: {d}, UNDEF: {d}\n", .{ reachable_count, undef_count });
        std.debug.print("# root filled? {s}\n", .{if (undef_count == 0) "YES" else "NO"});
    }

    // Pin census
    {
        var l_eq_h: u64 = 0;
        var pin_t: u64 = 0;
        var pin_l: u64 = 0;
        var pin_h: u64 = 0;
        var lin: u64 = 0;
        while (lin < TOTAL3) : (lin += 1) {
            const word = lin >> 6;
            const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
            if (reach3[word] & bit == 0) continue;
            const Ll = L_tab3[lin];
            const Hh = H_tab3[lin];
            if (Ll == Hh) {
                l_eq_h += 1;
            } else if (TIE < Ll) {
                pin_l += 1;
            } else if (TIE > Hh) {
                pin_h += 1;
            } else {
                pin_t += 1;
            }
        }
        std.debug.print("# 3×2 pin census: L==H={d}  pin_T={d}  pin_L={d}  pin_H={d}\n", .{ l_eq_h, pin_t, pin_l, pin_h });
    }

    // =====================================================================
    // PART 7: 3×2 — Cross-check (brute-force root + Bellman + sample)
    // =====================================================================
    std.debug.print("\n## 7. 3×2 cross-check (brute-force root + Bellman + budget sample)\n", .{});

    // 7a. Brute-force the root states with first-revisit truncation.
    {
        const hist_words = ReachWords3;
        const history_set = try gpa.alloc(u64, hist_words);
        defer gpa.free(history_set);
        var succ_boards: [n3 + 1]Pos3 = undefined;
        var succs: [n3 + 1]StateIdx = undefined;

        @memset(history_set, 0);
        var node_budget: u64 = 10_000_000;
        const bf_root_b = brute_value_3x2(root3_b, history_set, 0, &node_budget, &succ_boards, &succs);
        std.debug.print("# brute-force root (empty, B): {?d} (budget remaining: {d})\n", .{ bf_root_b, node_budget });
        std.debug.print("# root cross-check (B): fixpoint={d} brute={?d} {s}\n", .{ v3_root_b, bf_root_b, if (bf_root_b != null and bf_root_b.? == v3_root_b) "OK" else if (bf_root_b == null) "BUDGET-EXHAUSTED" else "FAIL" });

        @memset(history_set, 0);
        node_budget = 10_000_000;
        const bf_root_w = brute_value_3x2(root3_w, history_set, 0, &node_budget, &succ_boards, &succs);
        std.debug.print("# brute-force root (empty, W): {?d} (budget remaining: {d})\n", .{ bf_root_w, node_budget });
        std.debug.print("# root cross-check (W): fixpoint={d} brute={?d} {s}\n", .{ v3_root_w, bf_root_w, if (bf_root_w != null and bf_root_w.? == v3_root_w) "OK" else if (bf_root_w == null) "BUDGET-EXHAUSTED" else "FAIL" });
    }

    // 7b. Fixpoint self-consistency: L = Φ(L), H = Φ(H).
    // NOTE: V = median(L,T,H) is NOT guaranteed to be a fixpoint of Φ.
    // The proof-v2 guarantees L and H are fixpoints; V can differ from Φ(V).
    {
        var l_fail: u64 = 0;
        var h_fail: u64 = 0;
        var checked: u64 = 0;
        var terminals: u64 = 0;
        var lin: u64 = 0;
        while (lin < TOTAL3) : (lin += 1) {
            const word = lin >> 6;
            const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
            if (reach3[word] & bit == 0) continue;
            const passes: u8 = @intCast(lin / (2 * KO_DIMS * RAW_TOTAL));
            if (passes == 2) { terminals += 1; continue; }
            checked += 1;
            const rest: u64 = lin % (2 * KO_DIMS * RAW_TOTAL);
            const side: u8 = @intCast(rest / (KO_DIMS * RAW_TOTAL));
            const rest2: u64 = rest % (KO_DIMS * RAW_TOTAL);
            const ko: u16 = @intCast(rest2 / RAW_TOTAL);
            const board: u32 = @intCast(rest2 % RAW_TOTAL);
            const state = StateIdx{ .board = board, .side = side, .ko = ko, .passes = passes };
            const maximizing = side == 0;

            var succ_boards: [n3 + 1]Pos3 = undefined;
            var succs: [n3 + 1]StateIdx = undefined;
            const m = moves3(state, &succ_boards, &succs);
            var bl: ?i8 = null;
            var bh: ?i8 = null;
            for (0..m) |k| {
                if (!is_legal3(&succ_boards[k])) continue;
                const child_lin = succs[k].linear();
                const vl = L_tab3[child_lin];
                const vh = H_tab3[child_lin];
                if (bl == null or (if (maximizing) vl > bl.? else vl < bl.?)) bl = vl;
                if (bh == null or (if (maximizing) vh > bh.? else vh < bh.?)) bh = vh;
            }
            if (bl == null or bl.? != L_tab3[lin]) {
                l_fail += 1;
                if (l_fail <= 3) std.debug.print("# L-FIXPOINT-FAIL lin={d}: L={d} Φ(L)={?d}\n", .{ lin, L_tab3[lin], bl });
            }
            if (bh == null or bh.? != H_tab3[lin]) {
                h_fail += 1;
                if (h_fail <= 3) std.debug.print("# H-FIXPOINT-FAIL lin={d}: H={d} Φ(H)={?d}\n", .{ lin, H_tab3[lin], bh });
            }
        }
        std.debug.print("# Fixpoint consistency ({d} non-terminals): L-fail={d} H-fail={d} terminals={d}\n", .{ checked, l_fail, h_fail, terminals });
        std.debug.print("# Fixpoint check: {s}\n", .{if (l_fail == 0 and h_fail == 0) "PASS — L=Φ(L), H=Φ(H) everywhere" else "FAIL"});
    }

    // 7c. Budget-limited brute-force sample.
    {
        const NODE_BUDGET_PER_STATE: u64 = 1_000_000;
        var agreements: u64 = 0;
        var mismatches: u64 = 0;
        var budget_exhausted: u64 = 0;

        const hist_words = ReachWords3;
        const history_set = try gpa.alloc(u64, hist_words);
        defer gpa.free(history_set);

        var succ_boards: [n3 + 1]Pos3 = undefined;
        var succs: [n3 + 1]StateIdx = undefined;

        var sample_count: u64 = 0;
        const SAMPLE_MAX: u64 = 500;
        var lin: u64 = 0;
        while (lin < TOTAL3 and sample_count < SAMPLE_MAX) : (lin += 5) {
            const word = lin >> 6;
            const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
            if (reach3[word] & bit == 0) continue;

            const fp_val = median3(L_tab3[lin], H_tab3[lin]);
            const passes: u8 = @intCast(lin / (2 * KO_DIMS * RAW_TOTAL));
            const rest: u64 = lin % (2 * KO_DIMS * RAW_TOTAL);
            const side: u8 = @intCast(rest / (KO_DIMS * RAW_TOTAL));
            const rest2: u64 = rest % (KO_DIMS * RAW_TOTAL);
            const ko: u16 = @intCast(rest2 / RAW_TOTAL);
            const board: u32 = @intCast(rest2 % RAW_TOTAL);
            const state = StateIdx{ .board = board, .side = side, .ko = ko, .passes = passes };

            if (!is_legal3(&unrank_board3(board))) continue;
            sample_count += 1;

            @memset(history_set, 0);
            var node_budget: u64 = NODE_BUDGET_PER_STATE;
            const bf_val = brute_value_3x2(state, history_set, 0, &node_budget, &succ_boards, &succs);

            if (bf_val == null) {
                budget_exhausted += 1;
            } else if (fp_val == bf_val.?) {
                agreements += 1;
            } else {
                mismatches += 1;
                std.debug.print("# MISMATCH lin={d}: fixpoint={d} brute={d}\n", .{ lin, fp_val, bf_val.? });
            }
        }

        std.debug.print("# brute-force sample ({d} states, budget={d}/state):\n", .{ sample_count, NODE_BUDGET_PER_STATE });
        std.debug.print("#   agreements:       {d}\n", .{agreements});
        std.debug.print("#   mismatches:       {d}\n", .{mismatches});
        std.debug.print("#   budget-exhausted: {d}\n", .{budget_exhausted});
        const within_budget = agreements + mismatches;
        std.debug.print("# sample cross-check: {s} (denominator: {d} within-budget / {d} total)\n", .{
            if (mismatches == 0) "PASS — no mismatches" else "FAIL — mismatches found",
            within_budget,
            sample_count,
        });
    }

    // =====================================================================
    // PART 8: 3×2 — Colour-inversion symmetry
    // =====================================================================
    std.debug.print("\n## 8. 3×2 colour-inversion symmetry\n", .{});

    {
        var violations: u64 = 0;
        var checked: u64 = 0;
        var lin: u64 = 0;
        while (lin < TOTAL3) : (lin += 1) {
            const word = lin >> 6;
            const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
            if (reach3[word] & bit == 0) continue;
            const passes: u8 = @intCast(lin / (2 * KO_DIMS * RAW_TOTAL));
            const rest: u64 = lin % (2 * KO_DIMS * RAW_TOTAL);
            const side: u8 = @intCast(rest / (KO_DIMS * RAW_TOTAL));
            const rest2: u64 = rest % (KO_DIMS * RAW_TOTAL);
            const ko: u16 = @intCast(rest2 / RAW_TOTAL);
            const board: u32 = @intCast(rest2 % RAW_TOTAL);
            const state = StateIdx{ .board = board, .side = side, .ko = ko, .passes = passes };

            const state_inv = invert_state_3x2(state);
            const lin_inv = state_inv.linear();

            const v = median3(L_tab3[lin], H_tab3[lin]);
            const v_inv = median3(L_tab3[lin_inv], H_tab3[lin_inv]);
            checked += 1;

            if (v != -v_inv) {
                violations += 1;
                if (violations <= 5) {
                    std.debug.print("# VIOLATION lin={d}: v={d} v_inv({d})={d} (expected {d})\n", .{ lin, v, lin_inv, v_inv, -v });
                }
            }
        }
        std.debug.print("# 3×2 inversion violations: {d} / {d}\n", .{ violations, checked });
        std.debug.print("# symmetry: {s}\n", .{if (violations == 0) "PASS — value(-pos,-side) == -value(pos,side)" else "FAIL"});
    }

    // =====================================================================
    // PART 9: 3×2 — Calibration
    // =====================================================================
    std.debug.print("\n## 9. 3×2 calibration\n", .{});

    std.debug.print("# known-good: root (empty, B) = {d} expected 0 {s}\n", .{ v3_root_b, if (v3_root_b == 0) "OK" else "FAIL" });
    std.debug.print("# known-good: root (empty, W) = {d} expected 0 {s}\n", .{ v3_root_w, if (v3_root_w == 0) "OK" else "FAIL" });
    std.debug.print("# known-bad (PSK vs new rule): fixpoint root = {d}, PSK root = +1, delta = {d} (non-zero => gate distinguishes rulesets)\n", .{ v3_root_b, 1 - v3_root_b });

    // =====================================================================
    // Final verdict
    // =====================================================================
    std.debug.print("\n# ============================================================================\n", .{});
    std.debug.print("# FINAL VERDICT\n", .{});
    std.debug.print("# ============================================================================\n", .{});
    std.debug.print("# 2×2 root (empty, B): {d}  expected 0  {s}\n", .{ v2_root_b, if (v2_root_b == 0) "OK" else "FAIL" });
    std.debug.print("# 2×2 root (empty, W): {d}  expected 0  {s}\n", .{ v2_root_w, if (v2_root_w == 0) "OK" else "FAIL" });
    std.debug.print("# 3×2 root (empty, B): {d}  expected 0  {s}\n", .{ v3_root_b, if (v3_root_b == 0) "OK" else "FAIL" });
    std.debug.print("# 3×2 root (empty, W): {d}  expected 0  {s}\n", .{ v3_root_w, if (v3_root_w == 0) "OK" else "FAIL" });
    std.debug.print("#\n", .{});
    std.debug.print("# 2×2 root: {s}\n", .{tie_or_scored_2_b});
    std.debug.print("# 3×2 root: {s}\n", .{tie_or_scored_3_b});
    std.debug.print("#\n", .{});
    const all_good = gate2 and gate3 and v2_root_b == 0 and v2_root_w == 0 and v3_root_b == 0 and v3_root_w == 0;
    std.debug.print("# acceptance: {s}\n", .{if (all_good) "PASS — both boards return 0, MIGOS II anchors matched" else "FAIL"});
}
