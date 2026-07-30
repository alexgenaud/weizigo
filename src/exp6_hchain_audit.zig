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
// EXP-6 H-CHAIN AUDIT — is H=+16 at the empty-board root genuine or a
// propagation bug? Faithful copy of src/exp6_solve.zig (DSPro, EXP-6) with
// POST-CONVERGENCE instrumentation only: the gate chain, census, and fixpoint
// code paths are byte-identical to the production run; nothing below writes
// into L_tab/H_tab/map before convergence.
//
// Task: AUDIT-EXP6-HCHAIN · Role: auditor · Model: Kimi-k3 · Date: 2026-07-30
// Original: src/exp6_solve.zig (EXP-6, DSPro, 2026-07-29)
//
// Per `docs/infra/dispatch/EXP-6.md`:
//   Under area scoring, komi 0, basic ko, and a fixed-value verdict for
//   long cycles (TIE = 0), what is the value of the empty 4×4 board?
//
// Acceptance: +2 (Black, empty board, central first move), matching
// van der Werf & Winands (ICGA 2009). Root FILLED (vb[empty] ≠ -128).
// Full gate chain: 2×2 = 0, 3×2 = 0, 3×3 = +9.
//
// Build:
//   tools/runner --rss-cap-mb 8192 --max-wall 14400 -- zig run -O ReleaseFast src/exp6_solve.zig

const std = @import("std");

// =========================================================================
// Constants
// =========================================================================
const TIE: i8 = 0;
const UNDEF: i8 = -128;

// =========================================================================
// 2×2 solver — reusing Brute2x2 from EXP-4/EXP-5
// =========================================================================
const Brute2x2 = @import("qa023_brute_2x2.zig");
const N2_TOTAL: usize = Brute2x2.TOTAL_STATES;
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

fn invert_state_2x2(s: Brute2x2.State) Brute2x2.State {
    var inv_board: [N2_N]i8 = undefined;
    for (0..N2_N) |i| inv_board[i] = -s.board[i];
    return Brute2x2.State{
        .board = inv_board,
        .side = -s.side,
        .ko_point = if (s.ko_point == Brute2x2.State.KO_NONE) Brute2x2.State.KO_NONE else s.ko_point,
        .passes = s.passes,
    };
}

// =========================================================================
// Generic board-ops helper: returns neighbours for a grid cell
// =========================================================================
fn genericNeighbors(p: usize, w: usize, h: usize, buf: *[4]usize) usize {
    var cnt: usize = 0;
    const r = p / w;
    const c = p % w;
    if (r > 0) { buf[cnt] = p - w; cnt += 1; }
    if (r + 1 < h) { buf[cnt] = p + w; cnt += 1; }
    if (c > 0) { buf[cnt] = p - 1; cnt += 1; }
    if (c + 1 < w) { buf[cnt] = p + 1; cnt += 1; }
    return cnt;
}

fn genericChainCaptured(comptime n_cells: usize, pos: []const i8, seed: usize, w: usize, h: usize, chain: *[n_cells]usize, chain_len: *usize) bool {
    const colour: i8 = if (pos[seed] > 0) 1 else -1;
    var visited = [_]bool{false} ** n_cells;
    var stack: [n_cells]usize = undefined;
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
        const cnt = genericNeighbors(q, w, h, &nb);
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

fn genericPosFromMove(comptime n_cells: usize, pos: []i8, colour: i8, cell: usize, w: usize, h: usize) !void {
    // pos is modified in-place; caller copies if needed
    if (pos[cell] != 0) return error.Occupied;
    pos[cell] = colour;
    var nb: [4]usize = undefined;
    const cnt = genericNeighbors(cell, w, h, &nb);
    var chain: [n_cells]usize = undefined;
    var chain_len: usize = 0;
    for (nb[0..cnt]) |q| {
        if (pos[q] * colour < 0) {
            if (genericChainCaptured(n_cells, pos, q, w, h, &chain, &chain_len)) {
                for (chain[0..chain_len]) |c| pos[c] = 0;
            }
        }
    }
    if (genericChainCaptured(n_cells, pos, cell, w, h, &chain, &chain_len)) return error.Suicide;
}

fn genericIsLegal(comptime n_cells: usize, pos: []const i8, w: usize, h: usize) bool {
    var visited = [_]bool{false} ** n_cells;
    for (0..n_cells) |p| {
        if (pos[p] == 0 or visited[p]) continue;
        const colour = pos[p];
        var stack: [n_cells]usize = undefined;
        var sp: usize = 1;
        stack[0] = p;
        visited[p] = true;
        var has_liberty = false;
        while (sp > 0) {
            sp -= 1;
            const q = stack[sp];
            var nb: [4]usize = undefined;
            const cnt = genericNeighbors(q, w, h, &nb);
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

fn genericAreaScore(comptime n_cells: usize, board: []const i8, w: usize, h: usize) i8 {
    var black: i16 = 0;
    var white: i16 = 0;
    var visited = [_]bool{false} ** n_cells;
    for (0..n_cells) |p| {
        if (board[p] > 0) { black += 1; continue; }
        if (board[p] < 0) { white += 1; continue; }
        if (visited[p]) continue;
        var stack: [n_cells]usize = undefined;
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
            const cnt = genericNeighbors(q, w, h, &nb);
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

// =========================================================================
// 3×2 solver — self-contained dense gate check (from EXP-5)
// =========================================================================

const W32: usize = 3;
const H32: usize = 2;
const n32: usize = W32 * H32;
const KO_DIMS32: usize = n32 + 1;
const RAW_TOTAL32: u64 = 729;
const TOTAL32: u64 = RAW_TOTAL32 * 2 * KO_DIMS32 * 3;

const Pos32 = [n32]i8;
const KO_NONE32: u16 = @intCast(n32);
const ReachWords32: u64 = (TOTAL32 + 63) / 64;

const StateIdx32 = packed struct {
    board: u32,
    side: u8,
    ko: u16,
    passes: u8,

    fn linear(self: StateIdx32) u64 {
        return (((@as(u64, self.passes) * 2) + @as(u64, self.side)) * KO_DIMS32 + @as(u64, self.ko)) * RAW_TOTAL32 + self.board;
    }
};

fn unrank_board32(idx: u32) Pos32 {
    var board: Pos32 = [_]i8{0} ** n32;
    var v: u32 = idx;
    for (0..n32) |i| {
        const d = v % 3;
        v /= 3;
        board[i] = switch (d) { 0 => 0, 1 => 1, 2 => -1, else => unreachable };
    }
    return board;
}

fn rank_board32(board: Pos32) u32 {
    var idx: u32 = 0;
    var mult: u32 = 1;
    for (board) |c| {
        const d: u32 = if (c > 0) 1 else if (c < 0) 2 else 0;
        idx += d * mult;
        mult *= 3;
    }
    return idx;
}

fn apply_place32(state: StateIdx32, board: *const Pos32, colour: i8, cell: u8) ?StateIdx32 {
    if (board[cell] != 0) return null;
    if (state.ko != n32 and cell == state.ko) return null;
    var next = board.*;
    _ = genericPosFromMove(n32, &next, colour, cell, W32, H32) catch return null;
    var opp_before: u8 = 0;
    var opp_after: u8 = 0;
    var captured_cell: u8 = KO_NONE32;
    for (0..n32) |i| {
        if (board[i] == -colour) opp_before += 1;
        if (next[i] == -colour) opp_after += 1;
        if (board[i] == -colour and next[i] == 0) captured_cell = @intCast(i);
    }
    var new_ko: u16 = KO_NONE32;
    if ((opp_before - opp_after == 1) and (captured_cell != KO_NONE32)) {
        var liberties: u8 = 0;
        var friendly: u8 = 0;
        var nb: [4]usize = undefined;
        const cnt = genericNeighbors(cell, W32, H32, &nb);
        for (nb[0..cnt]) |q| {
            if (next[q] == 0) liberties += 1;
            if (next[q] == colour) friendly += 1;
        }
        if (liberties == 1 and friendly == 0) new_ko = captured_cell;
    }
    return StateIdx32{
        .board = rank_board32(next),
        .side = if (colour == 1) @as(u8, 1) else @as(u8, 0),
        .ko = new_ko,
        .passes = 0,
    };
}

fn apply_pass32(state: StateIdx32) ?StateIdx32 {
    if (state.passes >= 2) return null;
    return StateIdx32{
        .board = state.board,
        .side = 1 - state.side,
        .ko = KO_NONE32,
        .passes = state.passes + 1,
    };
}

fn moves32(state: StateIdx32, succ_boards: *[n32 + 1]Pos32, succs: *[n32 + 1]StateIdx32) usize {
    if (state.passes == 2) return 0;
    const board = unrank_board32(state.board);
    const colour: i8 = if (state.side == 0) 1 else -1;
    var count: usize = 0;
    if (apply_pass32(state)) |ns| {
        succ_boards[count] = unrank_board32(ns.board);
        succs[count] = ns;
        count += 1;
    }
    for (0..n32) |cell_u| {
        const cell: u8 = @intCast(cell_u);
        if (apply_place32(state, &board, colour, cell)) |ns| {
            succ_boards[count] = unrank_board32(ns.board);
            succs[count] = ns;
            count += 1;
        }
    }
    return count;
}

const CensusResult32 = struct { total_marked: u64, legal_boards: u64, terminal_marked: u64, side_marked: [2]u64, sweeps: u32 };

fn run_census_3x2(gpa: std.mem.Allocator, reach: []u64) !CensusResult32 {
    @memset(reach, 0);
    const snap = try gpa.alloc(u64, ReachWords32);
    defer gpa.free(snap);
    for ([_]u8{ 0, 1 }) |side| {
        for ([_]u8{ 0, 1 }) |passes| {
            const root = StateIdx32{ .board = 0, .side = side, .ko = KO_NONE32, .passes = passes };
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
        var lin: u64 = 0;
        while (lin < TOTAL32) : (lin += 1) {
            const word = lin >> 6;
            const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
            if (snap[word] & bit == 0) continue;
            const passes: u8 = @intCast(lin / (2 * KO_DIMS32 * RAW_TOTAL32));
            const rest: u64 = lin % (2 * KO_DIMS32 * RAW_TOTAL32);
            const side: u8 = @intCast(rest / (KO_DIMS32 * RAW_TOTAL32));
            const rest2: u64 = rest % (KO_DIMS32 * RAW_TOTAL32);
            const ko: u16 = @intCast(rest2 / RAW_TOTAL32);
            const board: u32 = @intCast(rest2 % RAW_TOTAL32);
            const state = StateIdx32{ .board = board, .side = side, .ko = ko, .passes = passes };
            var succ_boards: [n32 + 1]Pos32 = undefined;
            var succs: [n32 + 1]StateIdx32 = undefined;
            const m = moves32(state, &succ_boards, &succs);
            for (0..m) |k| {
                if (!genericIsLegal(n32, &succ_boards[k], W32, H32)) continue;
                const child_lin = succs[k].linear();
                const child_word = child_lin >> 6;
                const child_bit: u64 = @as(u64, 1) << @intCast(child_lin & 63);
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
    var seen_boards = [_]bool{false} ** @as(usize, RAW_TOTAL32);
    var lin: u64 = 0;
    while (lin < TOTAL32) : (lin += 1) {
        const word = lin >> 6;
        const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
        if (reach[word] & bit == 0) continue;
        total_marked += 1;
        const passes: u8 = @intCast(lin / (2 * KO_DIMS32 * RAW_TOTAL32));
        if (passes == 2) terminal_marked += 1;
        const rest: u64 = lin % (2 * KO_DIMS32 * RAW_TOTAL32);
        const side: u8 = @intCast(rest / (KO_DIMS32 * RAW_TOTAL32));
        side_marked[side] += 1;
        const rest2: u64 = rest % (KO_DIMS32 * RAW_TOTAL32);
        const board_idx: u32 = @intCast(rest2 % RAW_TOTAL32);
        const b = unrank_board32(board_idx);
        if (genericIsLegal(n32, &b, W32, H32) and !seen_boards[board_idx]) {
            seen_boards[board_idx] = true;
            legal_boards += 1;
        }
    }
    return CensusResult32{ .total_marked = total_marked, .legal_boards = legal_boards, .terminal_marked = terminal_marked, .side_marked = side_marked, .sweeps = sweep_idx };
}

fn median32(Lv: i8, Hv: i8) i8 { return @max(Lv, @min(TIE, Hv)); }

const FixpointResult32 = struct { sweeps: u32, converged: bool };

fn run_fixpoint_3x2(reach: []const u64, L_tab: []i8, H_tab: []i8) FixpointResult32 {
    const L_init: i8 = -@as(i8, @intCast(n32));
    const H_init: i8 = @as(i8, @intCast(n32));
    for (0..TOTAL32) |i| { L_tab[i] = L_init; H_tab[i] = H_init; }
    var lin: u64 = 0;
    while (lin < TOTAL32) : (lin += 1) {
        const word = lin >> 6;
        const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
        if (reach[word] & bit == 0) continue;
        const passes: u8 = @intCast(lin / (2 * KO_DIMS32 * RAW_TOTAL32));
        if (passes == 2) {
            const rest2: u64 = lin % (KO_DIMS32 * RAW_TOTAL32);
            const board_idx: u32 = @intCast(rest2 % RAW_TOTAL32);
            const b = unrank_board32(board_idx);
            L_tab[lin] = genericAreaScore(n32, &b, W32, H32);
            H_tab[lin] = genericAreaScore(n32, &b, W32, H32);
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
        while (li < TOTAL32) : (li += 1) {
            const word = li >> 6;
            const bit: u64 = @as(u64, 1) << @intCast(li & 63);
            if (reach[word] & bit == 0) continue;
            const passes: u8 = @intCast(li / (2 * KO_DIMS32 * RAW_TOTAL32));
            if (passes == 2) continue;
            const rest: u64 = li % (2 * KO_DIMS32 * RAW_TOTAL32);
            const side: u8 = @intCast(rest / (KO_DIMS32 * RAW_TOTAL32));
            const rest2: u64 = rest % (KO_DIMS32 * RAW_TOTAL32);
            const ko: u16 = @intCast(rest2 / RAW_TOTAL32);
            const board: u32 = @intCast(rest2 % RAW_TOTAL32);
            const state = StateIdx32{ .board = board, .side = side, .ko = ko, .passes = passes };
            var succ_boards: [n32 + 1]Pos32 = undefined;
            var succs: [n32 + 1]StateIdx32 = undefined;
            const m = moves32(state, &succ_boards, &succs);
            const maximizing = side == 0;
            var best_l: ?i8 = null;
            var best_h: ?i8 = null;
            for (0..m) |k| {
                if (!genericIsLegal(n32, &succ_boards[k], W32, H32)) continue;
                const child_li = succs[k].linear();
                const vl = L_tab[child_li];
                const vh = H_tab[child_li];
                if (best_l == null or (if (maximizing) vl > best_l.? else vl < best_l.?)) best_l = vl;
                if (best_h == null or (if (maximizing) vh > best_h.? else vh < best_h.?)) best_h = vh;
            }
            if (best_l != null and best_l.? != L_tab[li]) { L_tab[li] = best_l.?; l_changed += 1; }
            if (best_h != null and best_h.? != H_tab[li]) { H_tab[li] = best_h.?; l_changed += 1; }
        }
        var h_changed: u64 = 0;
        var hi: u64 = 0;
        while (hi < TOTAL32) : (hi += 1) {
            const word = hi >> 6;
            const bit: u64 = @as(u64, 1) << @intCast(hi & 63);
            if (reach[word] & bit == 0) continue;
            const passes: u8 = @intCast(hi / (2 * KO_DIMS32 * RAW_TOTAL32));
            if (passes == 2) continue;
            const rest: u64 = hi % (2 * KO_DIMS32 * RAW_TOTAL32);
            const side: u8 = @intCast(rest / (KO_DIMS32 * RAW_TOTAL32));
            const rest2: u64 = rest % (KO_DIMS32 * RAW_TOTAL32);
            const ko: u16 = @intCast(rest2 / RAW_TOTAL32);
            const board: u32 = @intCast(rest2 % RAW_TOTAL32);
            const state = StateIdx32{ .board = board, .side = side, .ko = ko, .passes = passes };
            var succ_boards: [n32 + 1]Pos32 = undefined;
            var succs: [n32 + 1]StateIdx32 = undefined;
            const m = moves32(state, &succ_boards, &succs);
            const maximizing = side == 0;
            var best_h2: ?i8 = null;
            for (0..m) |k| {
                if (!genericIsLegal(n32, &succ_boards[k], W32, H32)) continue;
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
    return FixpointResult32{ .sweeps = sweep_idx, .converged = total_changes == 0 };
}

fn invert_state32(s: StateIdx32) StateIdx32 {
    const board = unrank_board32(s.board);
    var inv_board: Pos32 = undefined;
    for (0..n32) |i| inv_board[i] = -board[i];
    return StateIdx32{ .board = rank_board32(inv_board), .side = 1 - s.side, .ko = s.ko, .passes = s.passes };
}

// =========================================================================
// 3×3 solver — dense (from EXP-5)
// =========================================================================

const W: usize = 3;
const H: usize = 3;
const N: usize = W * H;
const KO_DIMS: usize = N + 1;
const RAW_TOTAL: u64 = 19683;
const TOTAL: u64 = RAW_TOTAL * 2 * KO_DIMS * 3;

const Pos3 = [N]i8;
const KO_NONE: u16 = @intCast(N);
const ReachWords: u64 = (TOTAL + 63) / 64;

const StateIdx = packed struct {
    board: u32,
    side: u8,
    ko: u16,
    passes: u8,

    fn linear(self: StateIdx) u64 {
        return (((@as(u64, self.passes) * 2) + @as(u64, self.side)) * KO_DIMS + @as(u64, self.ko)) * RAW_TOTAL + self.board;
    }
};

fn unrank_board(idx: u32) Pos3 {
    var board: Pos3 = [_]i8{0} ** N;
    var v: u32 = idx;
    for (0..N) |i| {
        const d = v % 3;
        v /= 3;
        board[i] = switch (d) { 0 => 0, 1 => 1, 2 => -1, else => unreachable };
    }
    return board;
}

fn rank_board(board: Pos3) u32 {
    var idx: u32 = 0;
    var mult: u32 = 1;
    for (board) |c| {
        const d: u32 = if (c > 0) 1 else if (c < 0) 2 else 0;
        idx += d * mult;
        mult *= 3;
    }
    return idx;
}

fn apply_place(state: StateIdx, board: *const Pos3, colour: i8, cell: u8) ?StateIdx {
    if (board[cell] != 0) return null;
    if (state.ko != N and cell == state.ko) return null;
    var next = board.*;
    _ = genericPosFromMove(N, &next, colour, cell, W, H) catch return null;
    var opp_before: u8 = 0;
    var opp_after: u8 = 0;
    var captured_cell: u8 = KO_NONE;
    for (0..N) |i| {
        if (board[i] == -colour) opp_before += 1;
        if (next[i] == -colour) opp_after += 1;
        if (board[i] == -colour and next[i] == 0) captured_cell = @intCast(i);
    }
    var new_ko: u16 = KO_NONE;
    if ((opp_before - opp_after == 1) and (captured_cell != KO_NONE)) {
        var liberties: u8 = 0;
        var friendly: u8 = 0;
        var nb: [4]usize = undefined;
        const cnt = genericNeighbors(cell, W, H, &nb);
        for (nb[0..cnt]) |q| {
            if (next[q] == 0) liberties += 1;
            if (next[q] == colour) friendly += 1;
        }
        if (liberties == 1 and friendly == 0) new_ko = captured_cell;
    }
    return StateIdx{
        .board = rank_board(next),
        .side = if (colour == 1) @as(u8, 1) else @as(u8, 0),
        .ko = new_ko,
        .passes = 0,
    };
}

fn apply_pass(state: StateIdx) ?StateIdx {
    if (state.passes >= 2) return null;
    return StateIdx{ .board = state.board, .side = 1 - state.side, .ko = KO_NONE, .passes = state.passes + 1 };
}

fn moves(state: StateIdx, succ_boards: *[N + 1]Pos3, succs: *[N + 1]StateIdx) usize {
    if (state.passes == 2) return 0;
    const board = unrank_board(state.board);
    const colour: i8 = if (state.side == 0) 1 else -1;
    var count: usize = 0;
    if (apply_pass(state)) |ns| {
        succ_boards[count] = unrank_board(ns.board);
        succs[count] = ns;
        count += 1;
    }
    for (0..N) |cell_u| {
        const cell: u8 = @intCast(cell_u);
        if (apply_place(state, &board, colour, cell)) |ns| {
            succ_boards[count] = unrank_board(ns.board);
            succs[count] = ns;
            count += 1;
        }
    }
    return count;
}

const CensusResult = struct { total_marked: u64, legal_boards: u64, terminal_marked: u64, side_marked: [2]u64, sweeps: u32 };

fn run_census_3x3(gpa: std.mem.Allocator, reach: []u64) !CensusResult {
    @memset(reach, 0);
    const snap = try gpa.alloc(u64, ReachWords);
    defer gpa.free(snap);
    for ([_]u8{ 0, 1 }) |side| {
        const root = StateIdx{ .board = 0, .side = side, .ko = KO_NONE, .passes = 0 };
        const lin = root.linear();
        reach[lin >> 6] |= @as(u64, 1) << @intCast(lin & 63);
    }
    var new_marks: u64 = 1;
    var sweep_idx: u32 = 0;
    const MAX_SWEEPS: u32 = 128;
    while (new_marks > 0 and sweep_idx < MAX_SWEEPS) {
        @memcpy(snap, reach);
        new_marks = 0;
        var lin: u64 = 0;
        while (lin < TOTAL) : (lin += 1) {
            const word = lin >> 6;
            const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
            if (snap[word] & bit == 0) continue;
            const passes: u8 = @intCast(lin / (2 * KO_DIMS * RAW_TOTAL));
            const rest: u64 = lin % (2 * KO_DIMS * RAW_TOTAL);
            const side: u8 = @intCast(rest / (KO_DIMS * RAW_TOTAL));
            const rest2: u64 = rest % (KO_DIMS * RAW_TOTAL);
            const ko: u16 = @intCast(rest2 / RAW_TOTAL);
            const board: u32 = @intCast(rest2 % RAW_TOTAL);
            const state = StateIdx{ .board = board, .side = side, .ko = ko, .passes = passes };
            var succ_boards: [N + 1]Pos3 = undefined;
            var succs: [N + 1]StateIdx = undefined;
            const m = moves(state, &succ_boards, &succs);
            for (0..m) |k| {
                if (!genericIsLegal(N, &succ_boards[k], W, H)) continue;
                const child_lin = succs[k].linear();
                const child_word = child_lin >> 6;
                const child_bit: u64 = @as(u64, 1) << @intCast(child_lin & 63);
                if (reach[child_word] & child_bit == 0) {
                    reach[child_word] |= child_bit;
                    new_marks += 1;
                }
            }
        }
        sweep_idx += 1;
        if (sweep_idx % 4 == 0 or new_marks == 0) {
            std.debug.print("# 3x3 census sweep {d}: new_marks = {d}\n", .{ sweep_idx, new_marks });
        }
    }
    var total_marked: u64 = 0;
    var terminal_marked: u64 = 0;
    var side_marked: [2]u64 = [_]u64{ 0, 0 };
    var legal_boards: u64 = 0;
    var seen_boards = [_]bool{false} ** @as(usize, RAW_TOTAL);
    var lin: u64 = 0;
    while (lin < TOTAL) : (lin += 1) {
        const word = lin >> 6;
        const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
        if (reach[word] & bit == 0) continue;
        total_marked += 1;
        const passes: u8 = @intCast(lin / (2 * KO_DIMS * RAW_TOTAL));
        if (passes == 2) terminal_marked += 1;
        const rest: u64 = lin % (2 * KO_DIMS * RAW_TOTAL);
        const side: u8 = @intCast(rest / (KO_DIMS * RAW_TOTAL));
        side_marked[side] += 1;
        const rest2: u64 = rest % (KO_DIMS * RAW_TOTAL);
        const board_idx: u32 = @intCast(rest2 % RAW_TOTAL);
        const b = unrank_board(board_idx);
        if (genericIsLegal(N, &b, W, H) and !seen_boards[board_idx]) {
            seen_boards[board_idx] = true;
            legal_boards += 1;
        }
    }
    return CensusResult{ .total_marked = total_marked, .legal_boards = legal_boards, .terminal_marked = terminal_marked, .side_marked = side_marked, .sweeps = sweep_idx };
}

fn median(Lv: i8, Hv: i8) i8 { return @max(Lv, @min(TIE, Hv)); }

const FixpointResult = struct { sweeps: u32, converged: bool };

fn run_fixpoint_3x3(reach: []const u64, L_tab: []i8, H_tab: []i8) FixpointResult {
    const L_init: i8 = -@as(i8, @intCast(N));
    const H_init: i8 = @as(i8, @intCast(N));
    for (0..TOTAL) |i| { L_tab[i] = L_init; H_tab[i] = H_init; }
    var lin: u64 = 0;
    while (lin < TOTAL) : (lin += 1) {
        const word = lin >> 6;
        const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
        if (reach[word] & bit == 0) continue;
        const passes: u8 = @intCast(lin / (2 * KO_DIMS * RAW_TOTAL));
        if (passes == 2) {
            const rest2: u64 = lin % (KO_DIMS * RAW_TOTAL);
            const board_idx: u32 = @intCast(rest2 % RAW_TOTAL);
            const b = unrank_board(board_idx);
            L_tab[lin] = genericAreaScore(N, &b, W, H);
            H_tab[lin] = genericAreaScore(N, &b, W, H);
        }
    }
    var sweep_idx: u32 = 0;
    var total_changes: u64 = 1;
    const MAX_SWEEPS: u32 = 256;
    while (total_changes > 0 and sweep_idx < MAX_SWEEPS) {
        sweep_idx += 1;
        total_changes = 0;
        var l_changed: u64 = 0;
        var li: u64 = 0;
        while (li < TOTAL) : (li += 1) {
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
            var succ_boards: [N + 1]Pos3 = undefined;
            var succs: [N + 1]StateIdx = undefined;
            const m = moves(state, &succ_boards, &succs);
            const maximizing = side == 0;
            var best_l: ?i8 = null;
            var best_h: ?i8 = null;
            for (0..m) |k| {
                if (!genericIsLegal(N, &succ_boards[k], W, H)) continue;
                const child_li = succs[k].linear();
                const vl = L_tab[child_li];
                const vh = H_tab[child_li];
                if (best_l == null or (if (maximizing) vl > best_l.? else vl < best_l.?)) best_l = vl;
                if (best_h == null or (if (maximizing) vh > best_h.? else vh < best_h.?)) best_h = vh;
            }
            if (best_l != null and best_l.? != L_tab[li]) { L_tab[li] = best_l.?; l_changed += 1; }
            if (best_h != null and best_h.? != H_tab[li]) { H_tab[li] = best_h.?; l_changed += 1; }
        }
        var h_changed: u64 = 0;
        var hi: u64 = 0;
        while (hi < TOTAL) : (hi += 1) {
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
            var succ_boards: [N + 1]Pos3 = undefined;
            var succs: [N + 1]StateIdx = undefined;
            const m = moves(state, &succ_boards, &succs);
            const maximizing = side == 0;
            var best_h2: ?i8 = null;
            for (0..m) |k| {
                if (!genericIsLegal(N, &succ_boards[k], W, H)) continue;
                const child_li = succs[k].linear();
                const vh = H_tab[child_li];
                if (best_h2 == null or (if (maximizing) vh > best_h2.? else vh < best_h2.?)) best_h2 = vh;
            }
            if (best_h2 != null and best_h2.? != H_tab[hi]) { H_tab[hi] = best_h2.?; h_changed += 1; }
        }
        total_changes = l_changed + h_changed;
        if (sweep_idx % 4 == 0 or total_changes == 0) {
            std.debug.print("# 3x3 fixpoint sweep {d}: L_changed={d} H_changed={d}\n", .{ sweep_idx, l_changed, h_changed });
        }
    }
    return FixpointResult{ .sweeps = sweep_idx, .converged = total_changes == 0 };
}

fn invert_state(s: StateIdx) StateIdx {
    const board = unrank_board(s.board);
    var inv_board: Pos3 = undefined;
    for (0..N) |i| inv_board[i] = -board[i];
    return StateIdx{ .board = rank_board(inv_board), .side = 1 - s.side, .ko = s.ko, .passes = s.passes };
}

// 3×3 brute-force
fn brute_value(
    state: StateIdx,
    history_set: []u64,
    depth: u32,
    node_budget: *u64,
    succ_boards_buf: *[N + 1]Pos3,
    succs_buf: *[N + 1]StateIdx,
) ?i8 {
    if (node_budget.* == 0) return null;
    node_budget.* -= 1;
    const lin = state.linear();
    if (history_set[lin >> 6] & (@as(u64, 1) << @intCast(lin & 63)) != 0) return TIE;
    if (state.passes == 2) {
        const board = unrank_board(state.board);
        return genericAreaScore(N, &board, W, H);
    }
    if (depth > 256) return TIE;
    const prev_bit = history_set[lin >> 6] & (@as(u64, 1) << @intCast(lin & 63));
    history_set[lin >> 6] |= @as(u64, 1) << @intCast(lin & 63);
    const m = moves(state, succ_boards_buf, succs_buf);
    const maximizing = state.side == 0;
    var best: ?i8 = null;
    for (0..m) |k| {
        if (!genericIsLegal(N, &succ_boards_buf[k], W, H)) continue;
        const child = succs_buf[k];
        const v = brute_value(child, history_set, depth + 1, node_budget, succ_boards_buf, succs_buf);
        if (v == null) {
            if (prev_bit == 0) history_set[lin >> 6] &= ~(@as(u64, 1) << @intCast(lin & 63));
            return null;
        }
        if (best == null or (if (maximizing) v.? > best.? else v.? < best.?)) best = v;
    }
    if (prev_bit == 0) history_set[lin >> 6] &= ~(@as(u64, 1) << @intCast(lin & 63));
    if (best == null) {
        const board = unrank_board(state.board);
        return genericAreaScore(N, &board, W, H);
    }
    return best;
}

// =========================================================================
// 4×4 solver — SPARSE (frontier BFS + hash map child lookup)
// =========================================================================

const W4: usize = 4;
const H4: usize = 4;
const N4: usize = 16;
const KO_DIMS4: u64 = N4 + 1; // 17
const RAW_TOTAL4: u64 = 43046721; // 3^16

// Dense linear index space: (passes * 2 + side) * KO_DIMS * RAW_TOTAL + ko * RAW_TOTAL + board
// where passes ∈ {0,1,2}, side ∈ {0,1}, ko ∈ {0..16}
// Total: 2 * KO_DIMS4 * 3 * RAW_TOTAL4
const TOTAL4: u64 = RAW_TOTAL4 * 2 * KO_DIMS4 * 3;

const ReachWords4: u64 = (TOTAL4 + 63) / 64;

const KO_NONE4: u5 = @intCast(N4);

const Pos4 = [N4]i8;

// Packed state encoding for 4×4 (40 bits in u64)
fn encodeState4(board: u32, side: u1, ko: u5, passes: u2) u64 {
    // Layout: [passes:2][ko:5][side:1][board:32] = 40 bits
    return (@as(u64, passes) << 38) | (@as(u64, ko) << 33) | (@as(u64, side) << 32) | @as(u64, board);
}

fn decodeBoard4(s: u64) u32 { return @intCast(s & 0xFFFFFFFF); }
fn decodeSide4(s: u64) u1 { return @intCast((s >> 32) & 1); }
fn decodeKo4(s: u64) u5 { return @intCast((s >> 33) & 0x1F); }
fn decodePasses4(s: u64) u2 { return @intCast((s >> 38) & 3); }

fn linearIndex4(board: u32, side: u1, ko: u5, passes: u2) u64 {
    return ((@as(u64, passes) * 2 + @as(u64, side)) * KO_DIMS4 + @as(u64, ko)) * RAW_TOTAL4 + board;
}

fn unrank_board4(idx: u32) Pos4 {
    var board: Pos4 = [_]i8{0} ** N4;
    var v: u32 = idx;
    for (0..N4) |i| {
        const d = v % 3;
        v /= 3;
        board[i] = switch (d) { 0 => 0, 1 => 1, 2 => -1, else => unreachable };
    }
    return board;
}

fn rank_board4(board: Pos4) u32 {
    var idx: u32 = 0;
    var mult: u32 = 1;
    for (board) |c| {
        const d: u32 = if (c > 0) 1 else if (c < 0) 2 else 0;
        idx += d * mult;
        mult *= 3;
    }
    return idx;
}

fn apply_place4(board: *const Pos4, colour: i8, cell: u8, ko_forbid: u5) ?struct { board: Pos4, new_ko: u5 } {
    if (board[cell] != 0) return null;
    if (ko_forbid != KO_NONE4 and @as(u8, @intCast(ko_forbid)) == cell) return null;
    var next = board.*;
    _ = genericPosFromMove(N4, &next, colour, cell, W4, H4) catch return null;
    var opp_before: u8 = 0;
    var opp_after: u8 = 0;
    var captured_cell: u8 = @intCast(KO_NONE4);
    for (0..N4) |i| {
        if (board[i] == -colour) opp_before += 1;
        if (next[i] == -colour) opp_after += 1;
        if (board[i] == -colour and next[i] == 0) captured_cell = @intCast(i);
    }
    var new_ko: u5 = KO_NONE4;
    if ((opp_before - opp_after == 1) and (captured_cell != KO_NONE4)) {
        var liberties: u8 = 0;
        var friendly: u8 = 0;
        var nb: [4]usize = undefined;
        const cnt = genericNeighbors(cell, W4, H4, &nb);
        for (nb[0..cnt]) |q| {
            if (next[q] == 0) liberties += 1;
            if (next[q] == colour) friendly += 1;
        }
        if (liberties == 1 and friendly == 0) new_ko = @intCast(captured_cell);
    }
    return .{ .board = next, .new_ko = new_ko };
}

fn genChildren4(enc: u64, child_indices: *[N4 + 1]u64, child_count: *usize) void {
    const board_idx = decodeBoard4(enc);
    const side = decodeSide4(enc);
    const ko = decodeKo4(enc);
    const passes = decodePasses4(enc);
    child_count.* = 0;

    if (passes == 2) return;

    const board = unrank_board4(board_idx);
    const colour: i8 = if (side == 0) 1 else -1;

    // Pass
    const pass_enc = encodeState4(board_idx, 1 - side, KO_NONE4, passes + 1);
    child_indices[child_count.*] = pass_enc;
    child_count.* += 1;

    // Place moves
    for (0..N4) |cell_u| {
        const cell: u8 = @intCast(cell_u);
        if (apply_place4(&board, colour, cell, ko)) |result| {
            const new_board_idx = rank_board4(result.board);
            const new_side: u1 = if (colour == 1) @as(u1, 1) else @as(u1, 0);
            const child = encodeState4(new_board_idx, new_side, result.new_ko, 0);
            child_indices[child_count.*] = child;
            child_count.* += 1;
        }
    }
}

// Census BFS for 4×4: frontier-based, writes to the dense reachability bitset
fn run_census_4x4(gpa: std.mem.Allocator, reach: []u64) !struct { total_marked: u64, sweeps: u32 } {
    std.debug.print("# 4x4 census: TOTAL4={d} ReachWords4={d} bitset_bytes={d}\n", .{ TOTAL4, ReachWords4, ReachWords4 * 8 });

    // Verify the slice
    std.debug.print("# 4x4 census: reach.ptr={*} reach.len={d} expected={d}\n", .{ reach.ptr, reach.len, ReachWords4 });
    if (reach.len < ReachWords4) {
        std.debug.print("# 4x4 census: PANIC — reach.len too small!\n", .{});
        return error.BufferTooSmall;
    }

    @memset(reach, 0);
    std.debug.print("# 4x4 census: memset done, reach.len={d}\n", .{reach.len});

    var frontier = try std.ArrayListUnmanaged(u64).initCapacity(gpa, 0);
    std.debug.print("# 4x4 census: frontier allocated\n", .{});
    defer frontier.deinit(gpa);

    // Seed: empty board, both sides, passes=0.
    // Store ENCODED states in frontier, not linear indices.
    for ([_]u1{ 0, 1 }) |side| {
        const enc = encodeState4(0, side, KO_NONE4, 0);
        const lin = linearIndex4(0, side, KO_NONE4, 0);
        reach[lin >> 6] |= @as(u64, 1) << @intCast(lin & 63);
        frontier.append(gpa, enc) catch |e| { std.debug.print("# 4x4 census seed append error: {}\n", .{e}); return e; };
    }
    std.debug.print("# 4x4 census: roots seeded, frontier.len={d}\n", .{frontier.items.len});

    var sweep_idx: u32 = 0;
    const MAX_SWEEPS: u32 = 128;
    var child_indices: [N4 + 1]u64 = undefined;

    std.debug.print("# 4x4 census: entering BFS loop...\n", .{});
    while (sweep_idx < MAX_SWEEPS) {
        if (frontier.items.len == 0) break;
        sweep_idx += 1;
        std.debug.print("# 4x4 census sweep {d}: frontier={d}\n", .{ sweep_idx, frontier.items.len });

        var next_frontier = try std.ArrayListUnmanaged(u64).initCapacity(gpa, 0);
        var new_marks: u64 = 0;

        for (frontier.items) |enc| {
            // enc is an encoded state (packed representation)
            const passes = decodePasses4(enc);
            if (passes == 2) continue;

            var child_count: usize = 0;
            genChildren4(enc, &child_indices, &child_count);

            for (child_indices[0..child_count]) |child_enc| {
                // child_enc is an encoded state; compute linear index for bitset
                const child_lin = linearIndex4(
                    decodeBoard4(child_enc),
                    decodeSide4(child_enc),
                    decodeKo4(child_enc),
                    decodePasses4(child_enc),
                );
                if (child_lin >= TOTAL4) {
                    std.debug.print("# 4x4 census BAD child_lin={d} TOTAL4={d} child_enc={d}\n", .{ child_lin, TOTAL4, child_enc });
                    std.debug.print("#   board={d} side={d} ko={d} passes={d}\n", .{ decodeBoard4(child_enc), decodeSide4(child_enc), decodeKo4(child_enc), decodePasses4(child_enc) });
                    return error.IndexOutOfBounds;
                }
                const word = child_lin >> 6;
                const bit: u64 = @as(u64, 1) << @intCast(child_lin & 63);
                if (reach[word] & bit == 0) {
                    // Check board legality for place moves (passes==0 children)
                    const child_passes = decodePasses4(child_enc);
                    if (child_passes == 0) {
                        const child_board_idx = decodeBoard4(child_enc);
                        const cb = unrank_board4(child_board_idx);
                        if (!genericIsLegal(N4, &cb, W4, H4)) continue;
                    }
                    reach[word] |= bit;
                    next_frontier.append(gpa, child_enc) catch |e| { std.debug.print("# 4x4 census append error: {}\n", .{e}); return e; };
                    new_marks += 1;
                }
            }
        }

        frontier.deinit(gpa);
        frontier = next_frontier;

        if (sweep_idx % 4 == 0 or new_marks == 0) {
            std.debug.print("# 4x4 census sweep {d}: frontier_size={d} new_marks={d}\n", .{ sweep_idx, frontier.items.len, new_marks });
        }
        if (new_marks == 0) break;
    }

    std.debug.print("# 4x4 census BFS done, counting marked states...\n", .{});

    // Count total marked and pass=2 marked
    var total_marked: u64 = 0;
    var lin: u64 = 0;
    while (lin < TOTAL4) : (lin += 1) {
        const word = lin >> 6;
        const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
        if (reach[word] & bit != 0) total_marked += 1;
    }

    return .{ .total_marked = total_marked, .sweeps = sweep_idx };
}

const Fixpoint4Result = struct {
    sweeps: u32,
    converged: bool,
    compact_count: u32, // number of non-terminal reachable states
    root_b_compact: u32,
    root_w_compact: u32,
    root_b_L: i8,
    root_b_H: i8,
    root_w_L: i8,
    root_w_H: i8,
};

// 4×4 fixpoint: uses compact arrays for L/H, hash map for child lookups
fn run_fixpoint_4x4(gpa: std.mem.Allocator, reach: []const u64) !Fixpoint4Result {
    // Phase 1: build compact array of reachable non-terminal states (passes ∈ {0,1})
    var compact_list = try std.ArrayListUnmanaged(u64).initCapacity(gpa, 0);
    defer compact_list.deinit(gpa);

    var lin: u64 = 0;
    while (lin < TOTAL4) : (lin += 1) {
        const word = lin >> 6;
        const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
        if (reach[word] & bit == 0) continue;
        // Only include non-terminal states
        const passes: u8 = @intCast(lin / (2 * KO_DIMS4 * RAW_TOTAL4));
        if (passes == 2) continue;
        compact_list.append(gpa, lin) catch unreachable;
    }

    const compact_count: u32 = @intCast(compact_list.items.len);
    std.debug.print("# 4x4 compact states (passes ∈ {{0,1}}): {d}\n", .{compact_count});

    // Phase 2: build hash map from dense linear index → compact index
    std.debug.print("# 4x4 fixpoint: building hash map for {d} states...\n", .{compact_count});
    var map = std.AutoHashMap(u64, u32).init(gpa);
    defer map.deinit();
    try map.ensureTotalCapacity(compact_count);
    std.debug.print("# 4x4 fixpoint: hash map capacity reserved, inserting...\n", .{});

    for (compact_list.items, 0..) |dense_idx, i| {
        map.putAssumeCapacity(dense_idx, @intCast(i));
    }
    std.debug.print("# 4x4 fixpoint: hash map built, {d} entries\n", .{map.count()});

    // Phase 3: allocate L and H arrays
    const L_tab = try gpa.alloc(i8, compact_count);
    defer gpa.free(L_tab);
    const H_tab = try gpa.alloc(i8, compact_count);
    defer gpa.free(H_tab);

    const L_init: i8 = -16; // -N4
    const H_init: i8 = 16;
    @memset(L_tab, L_init);
    @memset(H_tab, H_init);

    // Phase 4: find root compact indices
    const root_b_lin = linearIndex4(0, 0, KO_NONE4, 0);
    const root_w_lin = linearIndex4(0, 1, KO_NONE4, 0);
    const root_b_compact = map.get(root_b_lin).?;
    const root_w_compact = map.get(root_w_lin).?;

    var child_indices: [N4 + 1]u64 = undefined;

    // Phase 5: fixpoint sweeps
    var sweep_idx: u32 = 0;
    var total_changes: u64 = 1;
    const MAX_SWEEPS: u32 = 256;

    while (total_changes > 0 and sweep_idx < MAX_SWEEPS) {
        sweep_idx += 1;
        total_changes = 0;

        // L sweep
        var l_changed: u64 = 0;
        for (compact_list.items, 0..) |dense_idx, ci| {
            const passes: u8 = @intCast(dense_idx / (2 * KO_DIMS4 * RAW_TOTAL4));
            if (passes == 2) continue;
            const rest: u64 = dense_idx % (2 * KO_DIMS4 * RAW_TOTAL4);
            const side: u8 = @intCast(rest / (KO_DIMS4 * RAW_TOTAL4));
            const rest2: u64 = rest % (KO_DIMS4 * RAW_TOTAL4);
            const ko: u5 = @intCast(rest2 / RAW_TOTAL4);
            const board: u32 = @intCast(rest2 % RAW_TOTAL4);
            const enc = encodeState4(board, @intCast(side), ko, @intCast(passes));

            var child_count: usize = 0;
            genChildren4(enc, &child_indices, &child_count);

            const maximizing = side == 0;
            var best_l: ?i8 = null;
            for (child_indices[0..child_count]) |child_enc| {
                const child_passes = decodePasses4(child_enc);
                const child_board = decodeBoard4(child_enc);
                const child_side = decodeSide4(child_enc);
                const child_ko = decodeKo4(child_enc);
                const child_lin = linearIndex4(child_board, child_side, child_ko, child_passes);

                if (child_passes == 2) {
                    // Terminal: compute area score on the fly
                    const b = unrank_board4(child_board);
                    // Check legality
                    if (!genericIsLegal(N4, &b, W4, H4)) continue;
                    const sc = genericAreaScore(N4, &b, W4, H4);
                    if (best_l == null or (if (maximizing) sc > best_l.? else sc < best_l.?)) best_l = sc;
                } else {
                    if (map.get(child_lin)) |child_ci| {
                        const vl = L_tab[child_ci];
                        if (best_l == null or (if (maximizing) vl > best_l.? else vl < best_l.?)) best_l = vl;
                    }
                }
            }
            if (best_l != null) {
                const new_val = best_l.?;
                if (new_val != L_tab[ci]) {
                    L_tab[ci] = new_val;
                    l_changed += 1;
                }
            }
        }

        // H sweep
        var h_changed: u64 = 0;
        for (compact_list.items, 0..) |dense_idx, ci| {
            const passes: u8 = @intCast(dense_idx / (2 * KO_DIMS4 * RAW_TOTAL4));
            if (passes == 2) continue;
            const rest: u64 = dense_idx % (2 * KO_DIMS4 * RAW_TOTAL4);
            const side: u8 = @intCast(rest / (KO_DIMS4 * RAW_TOTAL4));
            const rest2: u64 = rest % (KO_DIMS4 * RAW_TOTAL4);
            const ko: u5 = @intCast(rest2 / RAW_TOTAL4);
            const board: u32 = @intCast(rest2 % RAW_TOTAL4);
            const enc = encodeState4(board, @intCast(side), ko, @intCast(passes));

            var child_count: usize = 0;
            genChildren4(enc, &child_indices, &child_count);

            const maximizing = side == 0;
            var best_h: ?i8 = null;
            for (child_indices[0..child_count]) |child_enc| {
                const child_passes = decodePasses4(child_enc);
                const child_board = decodeBoard4(child_enc);
                const child_side = decodeSide4(child_enc);
                const child_ko = decodeKo4(child_enc);
                const child_lin = linearIndex4(child_board, child_side, child_ko, child_passes);

                if (child_passes == 2) {
                    const b = unrank_board4(child_board);
                    if (!genericIsLegal(N4, &b, W4, H4)) continue;
                    const sc = genericAreaScore(N4, &b, W4, H4);
                    if (best_h == null or (if (maximizing) sc > best_h.? else sc < best_h.?)) best_h = sc;
                } else {
                    if (map.get(child_lin)) |child_ci| {
                        const vh = H_tab[child_ci];
                        if (best_h == null or (if (maximizing) vh > best_h.? else vh < best_h.?)) best_h = vh;
                    }
                }
            }
            if (best_h != null) {
                const new_val = best_h.?;
                if (new_val != H_tab[ci]) {
                    H_tab[ci] = new_val;
                    h_changed += 1;
                }
            }
        }

        total_changes = l_changed + h_changed;
        std.debug.print("# 4x4 fixpoint sweep {d}: L_changed={d} H_changed={d} root_B(L={d},H={d}) root_W(L={d},H={d})\n", .{ sweep_idx, l_changed, h_changed, L_tab[root_b_compact], H_tab[root_b_compact], L_tab[root_w_compact], H_tab[root_w_compact] });
        if (sweep_idx % 4 == 0 or total_changes == 0) {
            std.debug.print("# 4x4 fixpoint sweep {d}: L_changed={d} H_changed={d}\n", .{ sweep_idx, l_changed, h_changed });
        }
    }

    // Debug: print pass child of root B
    {
        const pass_child_lin = linearIndex4(0, 1, KO_NONE4, 1);
        if (map.get(pass_child_lin)) |pass_ci| {
            std.debug.print("# 4x4 fixpoint DEBUG: pass_child(empty,W,1) L={d} H={d}\n", .{ L_tab[pass_ci], H_tab[pass_ci] });
        } else {
            std.debug.print("# 4x4 fixpoint DEBUG: pass_child NOT in hash map!\n", .{});
        }
        const pass_child_lin_w = linearIndex4(0, 0, KO_NONE4, 1);
        if (map.get(pass_child_lin_w)) |pw_ci| {
            std.debug.print("# 4x4 fixpoint DEBUG: pass_child(empty,B,1) L={d} H={d}\n", .{ L_tab[pw_ci], H_tab[pw_ci] });
        }
        // Check board with one Black stone (rank=1), White to move, passes=0
        const b1w0_lin = linearIndex4(1, 1, KO_NONE4, 0);
        if (map.get(b1w0_lin)) |ci| {
            std.debug.print("# 4x4 fixpoint DEBUG: (1B,W,0) L={d} H={d}\n", .{ L_tab[ci], H_tab[ci] });
        } else {
            std.debug.print("# 4x4 fixpoint DEBUG: (1B,W,0) NOT in hash map!\n", .{});
        }
        // Check board with B at 0 and W at 1 (rank=7), Black to move, passes=0
        const b1w1_b0_lin = linearIndex4(7, 0, KO_NONE4, 0);
        if (map.get(b1w1_b0_lin)) |ci| {
            std.debug.print("# 4x4 fixpoint DEBUG: (1B1W,B,0) L={d} H={d}\n", .{ L_tab[ci], H_tab[ci] });
        } else {
            std.debug.print("# 4x4 fixpoint DEBUG: (1B1W,B,0) NOT in hash map!\n", .{});
        }
        // Check board with B at 0 and W at 1, White to move, passes=1
        const b1w1_w1_lin = linearIndex4(7, 1, KO_NONE4, 1);
        if (map.get(b1w1_w1_lin)) |ci| {
            std.debug.print("# 4x4 fixpoint DEBUG: (1B1W,W,1) L={d} H={d}\n", .{ L_tab[ci], H_tab[ci] });
        } else {
            std.debug.print("# 4x4 fixpoint DEBUG: (1B1W,W,1) NOT in hash map!\n", .{});
        }
    }

    // =====================================================================
    // AUDIT-EXP6-HCHAIN — post-convergence instrumentation (read-only)
    // =====================================================================
    {
        const tabs = AuditTabs4{
            .map = &map,
            .L_tab = L_tab,
            .H_tab = H_tab,
            .compact_list = compact_list.items,
        };
        auditVerify4(&tabs);
        auditInversion4(&tabs);
        auditFirstMoves4(&tabs);
        auditTraceA4(&tabs);
        auditTraceB4(&tabs, 0); // corner-class witness start
        auditTraceB4(&tabs, 1); // edge-class witness start
        auditTraceB4(&tabs, 5); // center-class witness start
    }

    return Fixpoint4Result{
        .sweeps = sweep_idx,
        .converged = total_changes == 0,
        .compact_count = compact_count,
        .root_b_compact = root_b_compact,
        .root_w_compact = root_w_compact,
        .root_b_L = L_tab[root_b_compact],
        .root_b_H = H_tab[root_b_compact],
        .root_w_L = L_tab[root_w_compact],
        .root_w_H = H_tab[root_w_compact],
    };
}

// =========================================================================
// Main
// =========================================================================

pub fn main() !void {
    const gpa = std.heap.page_allocator;

    std.debug.print("# ============================================================================\n", .{});
    std.debug.print("# EXP-6 — 4×4 under the new rule: +2, and a root that can say so\n", .{});
    std.debug.print("# Task: EXP-6 · Role: worker · Model: DSPro · Date: 2026-07-29\n", .{});
    std.debug.print("# Rule: basic ko (formalization (i)) + TIE = {d} for long cycles\n", .{TIE});
    std.debug.print("# Value rule: V = median(L, TIE, H) = max(L, min(TIE, H))\n", .{});
    std.debug.print("# ============================================================================\n", .{});

    // =====================================================================
    // GATE CHAIN: 2×2, 3×2, 3×3 (must pass before 4×4, per brief)
    // =====================================================================
    std.debug.print("\n## GATE CHAIN (re-run from this binary — mandatory before 4×4)\n", .{});

    // --- 2×2 ---
    const fp2 = run_fixpoint_2x2();
    const s_root_b2 = Brute2x2.State{ .board = .{0} ** N2_N, .side = 1, .ko_point = Brute2x2.State.KO_NONE, .passes = 0 };
    const s_root_w2 = Brute2x2.State{ .board = .{0} ** N2_N, .side = -1, .ko_point = Brute2x2.State.KO_NONE, .passes = 0 };
    const v2_b = fp2.v(Brute2x2.global_index(s_root_b2));
    const v2_w = fp2.v(Brute2x2.global_index(s_root_w2));
    const gate2 = v2_b == 0 and v2_w == 0;
    std.debug.print("# 2×2: B={d} W={d} → {s}\n", .{ v2_b, v2_w, if (gate2) "PASS (0)" else "FAIL" });
    // AUDIT: dump full 2×2 tables for independent Python comparison.
    // (2×2 fixpoint updates ALL states, no reachability filter.)
    {
        var i: usize = 0;
        while (i < N2_TOTAL) : (i += 1) {
            const s = Brute2x2.state_from_index(i);
            std.debug.print("#DUMP2 {d} {d} {d} {d} {d} {d}\n", .{ Brute2x2.board_index(s.board), s.side, s.ko_point, s.passes, fp2.L[i], fp2.H[i] });
        }
    }

    // --- 3×2 ---
    const reach32 = try gpa.alloc(u64, ReachWords32);
    defer gpa.free(reach32);
    const L_tab32 = try gpa.alloc(i8, TOTAL32);
    defer gpa.free(L_tab32);
    const H_tab32 = try gpa.alloc(i8, TOTAL32);
    defer gpa.free(H_tab32);
    _ = try run_census_3x2(gpa, reach32);
    _ = run_fixpoint_3x2(reach32, L_tab32, H_tab32);
    const root32_b = StateIdx32{ .board = 0, .side = 0, .ko = KO_NONE32, .passes = 0 };
    const root32_w = StateIdx32{ .board = 0, .side = 1, .ko = KO_NONE32, .passes = 0 };
    const v32_b = median32(L_tab32[root32_b.linear()], H_tab32[root32_b.linear()]);
    const v32_w = median32(L_tab32[root32_w.linear()], H_tab32[root32_w.linear()]);
    const gate32 = v32_b == 0 and v32_w == 0;
    std.debug.print("# 3×2: B={d} W={d} → {s}\n", .{ v32_b, v32_w, if (gate32) "PASS (0)" else "FAIL" });
    // AUDIT: dump 3×2 tables for reachable states + explicit root values.
    std.debug.print("# AUDIT 3x2: root_B(L={d},H={d}) root_W(L={d},H={d})\n", .{ L_tab32[root32_b.linear()], H_tab32[root32_b.linear()], L_tab32[root32_w.linear()], H_tab32[root32_w.linear()] });
    {
        var lin: u64 = 0;
        while (lin < TOTAL32) : (lin += 1) {
            const word = lin >> 6;
            const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
            if (reach32[word] & bit == 0) continue;
            const passes: u8 = @intCast(lin / (2 * KO_DIMS32 * RAW_TOTAL32));
            const rest: u64 = lin % (2 * KO_DIMS32 * RAW_TOTAL32);
            const side: u8 = @intCast(rest / (KO_DIMS32 * RAW_TOTAL32));
            const rest2: u64 = rest % (KO_DIMS32 * RAW_TOTAL32);
            const ko: u16 = @intCast(rest2 / RAW_TOTAL32);
            const board: u32 = @intCast(rest2 % RAW_TOTAL32);
            std.debug.print("#DUMP32 {d} {d} {d} {d} {d} {d}\n", .{ board, side, ko, passes, L_tab32[lin], H_tab32[lin] });
        }
    }

    // --- 3×3 ---
    const reach3 = try gpa.alloc(u64, ReachWords);
    defer gpa.free(reach3);
    const L_tab3 = try gpa.alloc(i8, TOTAL);
    defer gpa.free(L_tab3);
    const H_tab3 = try gpa.alloc(i8, TOTAL);
    defer gpa.free(H_tab3);
    _ = try run_census_3x3(gpa, reach3); // census3 unused, needed only for reachability set
    _ = run_fixpoint_3x3(reach3, L_tab3, H_tab3);
    const root3_b = StateIdx{ .board = 0, .side = 0, .ko = KO_NONE, .passes = 0 };
    const root3_w = StateIdx{ .board = 0, .side = 1, .ko = KO_NONE, .passes = 0 };
    const v3_b = median(L_tab3[root3_b.linear()], H_tab3[root3_b.linear()]);
    const v3_w = median(L_tab3[root3_w.linear()], H_tab3[root3_w.linear()]);
    const gate3 = v3_b == 9 and v3_w == -9;
    std.debug.print("# 3×3: B={d} W={d} → {s}\n", .{ v3_b, v3_w, if (gate3) "PASS (+9)" else "FAIL" });

    if (!gate2 or !gate32 or !gate3) {
        std.debug.print("\n# GATE CHAIN FAILED — stopping. A +1 at 2×2/3×2 would mean PSK drift.\n", .{});
        return;
    }
    std.debug.print("\n# Gate chain: PASS — 2×2=0, 3×2=0, 3×3=+9. Binary is not PSK.\n", .{});

    // 3×3 tie census (for reference)
    {
        var tie_count: u64 = 0;
        var l_eq_h: u64 = 0;
        var pin_t: u64 = 0;
        var pin_l: u64 = 0;
        var pin_h: u64 = 0;
        var reachable_count: u64 = 0;
        var lin: u64 = 0;
        while (lin < TOTAL) : (lin += 1) {
            const word = lin >> 6;
            const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
            if (reach3[word] & bit == 0) continue;
            reachable_count += 1;
            const Ll = L_tab3[lin];
            const Hh = H_tab3[lin];
            const v = median(Ll, Hh);
            if (v == TIE) tie_count += 1;
            if (Ll == Hh) l_eq_h += 1
            else if (TIE < Ll) pin_l += 1
            else if (TIE > Hh) pin_h += 1
            else pin_t += 1;
        }
        std.debug.print("# 3×3 gate stats: reachable={d} ties={d} L==H={d} pin_T={d} pin_L={d} pin_H={d}\n", .{ reachable_count, tie_count, l_eq_h, pin_t, pin_l, pin_h });

        // AUDIT 3×3: explicit root bounds, table dump, and phenomenon census.
        std.debug.print("# AUDIT 3x3: root_B(L={d},H={d}) root_W(L={d},H={d})\n", .{ L_tab3[root3_b.linear()], H_tab3[root3_b.linear()], L_tab3[root3_w.linear()], H_tab3[root3_w.linear()] });
        var top_w: u64 = 0;
        var top_w_stone_p0: u64 = 0;
        var top_w_stone_p1: u64 = 0;
        var lin2: u64 = 0;
        while (lin2 < TOTAL) : (lin2 += 1) {
            const word = lin2 >> 6;
            const bit: u64 = @as(u64, 1) << @intCast(lin2 & 63);
            if (reach3[word] & bit == 0) continue;
            const passes: u8 = @intCast(lin2 / (2 * KO_DIMS * RAW_TOTAL));
            const rest: u64 = lin2 % (2 * KO_DIMS * RAW_TOTAL);
            const side: u8 = @intCast(rest / (KO_DIMS * RAW_TOTAL));
            const rest2: u64 = rest % (KO_DIMS * RAW_TOTAL);
            const ko: u16 = @intCast(rest2 / RAW_TOTAL);
            const board: u32 = @intCast(rest2 % RAW_TOTAL);
            std.debug.print("#DUMP3 {d} {d} {d} {d} {d} {d}\n", .{ board, side, ko, passes, L_tab3[lin2], H_tab3[lin2] });
            if (side == 1 and H_tab3[lin2] == 9 and passes < 2) {
                top_w += 1;
                const b = unrank_board(board);
                var has_white = false;
                for (b) |c| {
                    if (c < 0) has_white = true;
                }
                if (has_white) {
                    if (passes == 1) top_w_stone_p1 += 1 else top_w_stone_p0 += 1;
                }
            }
        }
        std.debug.print("# AUDIT 3x3 phenomenon: white-to-move H==9 non-terminals={d}  with-white-stone-p0={d}  with-white-stone-p1={d} (p1 MUST be 0 in any faithful fixpoint: its pass child is a sub-top terminal)\n", .{ top_w, top_w_stone_p0, top_w_stone_p1 });
    }

    // =====================================================================
    // 4×4 CENSUS
    // =====================================================================
    std.debug.print("\n## 4×4 census (frontier BFS, dense bitset)\n", .{});

    const reach4 = try gpa.alloc(u64, ReachWords4);
    defer gpa.free(reach4);

    const census4 = try run_census_4x4(gpa, reach4);
    std.debug.print("# 4x4 total reachable (all passes): {d}\n", .{census4.total_marked});
    std.debug.print("# 4x4 census sweeps: {d}\n", .{census4.sweeps});

    // =====================================================================
    // 4×4 FIXPOINT
    // =====================================================================
    std.debug.print("\n## 4×4 fixpoint (sparse, compact arrays + hash map)\n", .{});

    const fp4 = try run_fixpoint_4x4(gpa, reach4);

    const v4_b = median(fp4.root_b_L, fp4.root_b_H);
    const v4_w = median(fp4.root_w_L, fp4.root_w_H);

    std.debug.print("# root (empty, B to move):  L={d:>3} H={d:>3} V={d:>3}\n", .{ fp4.root_b_L, fp4.root_b_H, v4_b });
    std.debug.print("# root (empty, W to move):  L={d:>3} H={d:>3} V={d:>3}\n", .{ fp4.root_w_L, fp4.root_w_H, v4_w });

    const anchor_match = v4_b == 2;
    std.debug.print("# anchor (+2): {s}\n", .{if (anchor_match) "MATCH" else "FAIL"});
    std.debug.print("# fixpoint sweeps: {d}, converged: {}\n", .{ fp4.sweeps, fp4.converged });

    // Tie-vs-score: on 4×4, area scores are even (16 points). TIE=0 collides with score=0.
    const tie_or_scored_b: []const u8 = if (fp4.root_b_L == fp4.root_b_H)
        if (fp4.root_b_L == 2) "scored +2 (L==H==2)" else "scored (L==H)"
    else if (fp4.root_b_L < TIE and TIE < fp4.root_b_H)
        "TIE (L<0<H, pinned)"
    else
        "score pinned";
    const tie_or_scored_w: []const u8 = if (fp4.root_w_L == fp4.root_w_H)
        if (fp4.root_w_L == -2) "scored -2 (L==H==-2)" else "scored (L==H)"
    else if (fp4.root_w_L < TIE and TIE < fp4.root_w_H)
        "TIE (L<0<H, pinned)"
    else
        "score pinned";

    std.debug.print("# 4×4 empty B: {s}\n", .{tie_or_scored_b});
    std.debug.print("# 4×4 empty W: {s}\n", .{tie_or_scored_w});

    // =====================================================================
    // ROOT FILLED check
    // =====================================================================
    std.debug.print("\n## Root filled + UNDEF check\n", .{});
    {
        // Check the root specifically
        const root_b_lin = linearIndex4(0, 0, KO_NONE4, 0);
        const word = root_b_lin >> 6;
        const bit: u64 = @as(u64, 1) << @intCast(root_b_lin & 63);
        const root_reachable = (reach4[word] & bit) != 0;
        std.debug.print("# root (empty, B) reachable: {}\n", .{root_reachable});
        std.debug.print("# root V = {d} (UNDEF = -128: {})\n", .{ v4_b, v4_b == UNDEF });

        // Count UNDEF across all reachable states (all passes)
        // We need to re-run the hash map to check. We'll check root specifically above.
        // For full UNDEF sweep, we need the L/H values for pass=2 too.
        // The pass=2 values are area_score(board) by construction.
        // We check: is the root filled? vb[empty] ≠ -128?
        const root_filled = v4_b != UNDEF;
        std.debug.print("# root filled? {s}\n", .{if (root_filled) "YES" else "NO"});
    }

    // =====================================================================
    // FINAL VERDICT
    // =====================================================================
    std.debug.print("\n# ============================================================================\n", .{});
    std.debug.print("# FINAL VERDICT — EXP-6 4×4\n", .{});
    std.debug.print("# ============================================================================\n", .{});
    std.debug.print("# 2×2 gate: {d}  {s}\n", .{ v2_b, if (gate2) "PASS" else "FAIL" });
    std.debug.print("# 3×2 gate: {d}  {s}\n", .{ v32_b, if (gate32) "PASS" else "FAIL" });
    std.debug.print("# 3×3 gate: {d}  {s}\n", .{ v3_b, if (gate3) "PASS" else "FAIL" });
    std.debug.print("#\n", .{});
    std.debug.print("# 4×4 root (empty, B): V={d}  expected +2  {s}\n", .{ v4_b, if (v4_b == 2) "MATCH" else "FAIL" });
    std.debug.print("# 4×4 root (empty, W): V={d}  expected -2  {s}\n", .{ v4_w, if (v4_w == -2) "MATCH" else "FAIL" });
    std.debug.print("#\n", .{});
    std.debug.print("# root filled? {s} (V={d} ≠ -128? {})\n", .{ if (v4_b != UNDEF) "YES" else "NO", v4_b, v4_b != UNDEF });
    std.debug.print("# anchor matched? {s}\n", .{if (v4_b == 2) "YES" else "NO"});
    std.debug.print("# gate passed? {s}\n", .{if (gate2 and gate32 and gate3) "YES" else "NO"});
    std.debug.print("#\n", .{});
    std.debug.print("# fixpoint sweeps: {d}  converged: {}\n", .{ fp4.sweeps, fp4.converged });
    std.debug.print("# compact states (passes ∈ {{0,1}}): {d}\n", .{fp4.compact_count});
    std.debug.print("# 4×4 empty B: {s}\n", .{tie_or_scored_b});
    std.debug.print("# 4×4 empty W: {s}\n", .{tie_or_scored_w});
}

// =========================================================================
// AUDIT-EXP6-HCHAIN (Kimi-k3, 2026-07-30)
// Post-convergence, read-only instrumentation. Nothing here mutates
// L_tab/H_tab/map; it observes the converged tables and re-derives values
// through the same child generator to check the fixpoint equations.
// =========================================================================

const AuditTabs4 = struct {
    map: *const std.AutoHashMap(u64, u32),
    L_tab: []const i8,
    H_tab: []const i8,
    compact_list: []const u64,
};

const LH4 = struct { l: i8, h: i8, ci: u32 };

fn auditLookup4(t: *const AuditTabs4, board: u32, side: u1, ko: u5, passes: u2) ?LH4 {
    const lin = linearIndex4(board, side, ko, passes);
    if (t.map.get(lin)) |ci| return .{ .l = t.L_tab[ci], .h = t.H_tab[ci], .ci = ci };
    return null;
}

fn stoneCounts4(board: u32) struct { b: u8, w: u8 } {
    const b = unrank_board4(board);
    var nb: u8 = 0;
    var nw: u8 = 0;
    for (b) |c| {
        if (c > 0) nb += 1;
        if (c < 0) nw += 1;
    }
    return .{ .b = nb, .w = nw };
}

// ---------------------------------------------------------------------
// AUDIT 1: verification sweep — recompute best_l / best_h at every compact
// state from children (same generator, same terminal rule), count violations
// of the fixpoint equations, map lookup misses, terminal legality skips, and
// population statistics. All counters are GLOBAL (99,133,036 states), no
// sampling. (AGENTS.md: state every denominator.)
// ---------------------------------------------------------------------
fn auditVerify4(t: *const AuditTabs4) void {
    std.debug.print("\n## AUDIT verify: recompute L=Phi(L), H=Phi(H) over all compact states\n", .{});
    var nodes: u64 = 0;
    var l_viol: u64 = 0;
    var h_viol: u64 = 0;
    var l_null: u64 = 0;
    var h_null: u64 = 0;
    var map_miss: u64 = 0;
    var term_islegal_skip: u64 = 0;
    var l_eq_h: u64 = 0;
    var pin_t: u64 = 0;
    var pin_l: u64 = 0;
    var pin_h: u64 = 0;
    var tot_h16: u64 = 0;
    var tot_lm16: u64 = 0;
    var white_h16: u64 = 0;
    var white_h16_ws: u64 = 0;
    var white_p1_mixed_h16: u64 = 0;
    var black_lm16: u64 = 0;
    var black_lm16_bs: u64 = 0;
    var child_indices: [N4 + 1]u64 = undefined;
    var shown: u64 = 0;

    for (t.compact_list, 0..) |dense_idx, ci_usz| {
        const ci: u32 = @intCast(ci_usz);
        nodes += 1;
        const passes: u8 = @intCast(dense_idx / (2 * KO_DIMS4 * RAW_TOTAL4));
        const rest: u64 = dense_idx % (2 * KO_DIMS4 * RAW_TOTAL4);
        const side: u8 = @intCast(rest / (KO_DIMS4 * RAW_TOTAL4));
        const rest2: u64 = rest % (KO_DIMS4 * RAW_TOTAL4);
        const ko: u5 = @intCast(rest2 / RAW_TOTAL4);
        const board: u32 = @intCast(rest2 % RAW_TOTAL4);
        const enc = encodeState4(board, @intCast(side), ko, @intCast(passes));

        var child_count: usize = 0;
        genChildren4(enc, &child_indices, &child_count);
        const maximizing = side == 0;
        var best_l: ?i8 = null;
        var best_h: ?i8 = null;
        for (child_indices[0..child_count]) |child_enc| {
            const cp = decodePasses4(child_enc);
            const cb = decodeBoard4(child_enc);
            const cs = decodeSide4(child_enc);
            const ck = decodeKo4(child_enc);
            if (cp == 2) {
                const bb = unrank_board4(cb);
                if (!genericIsLegal(N4, &bb, W4, H4)) {
                    term_islegal_skip += 1;
                    continue;
                }
                const sc = genericAreaScore(N4, &bb, W4, H4);
                if (best_l == null or (if (maximizing) sc > best_l.? else sc < best_l.?)) best_l = sc;
                if (best_h == null or (if (maximizing) sc > best_h.? else sc < best_h.?)) best_h = sc;
            } else {
                const child_lin = linearIndex4(cb, cs, ck, cp);
                if (t.map.get(child_lin)) |cci| {
                    const vl = t.L_tab[cci];
                    const vh = t.H_tab[cci];
                    if (best_l == null or (if (maximizing) vl > best_l.? else vl < best_l.?)) best_l = vl;
                    if (best_h == null or (if (maximizing) vh > best_h.? else vh < best_h.?)) best_h = vh;
                } else {
                    map_miss += 1;
                    if (shown < 5) {
                        shown += 1;
                        std.debug.print("# AUDIT verify MAP-MISS: parent(b={d},s={d},ko={d},p={d}) child(b={d},s={d},ko={d},p={d}) not in map\n", .{ board, side, ko, passes, cb, cs, ck, cp });
                    }
                }
            }
        }
        const sl = t.L_tab[ci];
        const sh = t.H_tab[ci];
        if (best_l == null) l_null += 1 else if (best_l.? != sl) {
            l_viol += 1;
            if (l_viol <= 5) std.debug.print("# AUDIT verify L-VIOLATION: (b={d},s={d},ko={d},p={d}) stored={d} recomputed={d}\n", .{ board, side, ko, passes, sl, best_l.? });
        }
        if (best_h == null) h_null += 1 else if (best_h.? != sh) {
            h_viol += 1;
            if (h_viol <= 5) std.debug.print("# AUDIT verify H-VIOLATION: (b={d},s={d},ko={d},p={d}) stored={d} recomputed={d}\n", .{ board, side, ko, passes, sh, best_h.? });
        }

        // population statistics
        if (sl == sh) l_eq_h += 1 else if (sl < TIE and TIE < sh) pin_t += 1 else if (sl > TIE) pin_l += 1 else pin_h += 1;
        if (sh == 16) tot_h16 += 1;
        if (sl == -16) tot_lm16 += 1;
        if (side == 1 and sh == 16) {
            white_h16 += 1;
            const b = unrank_board4(board);
            var has_white = false;
            for (b) |c| {
                if (c < 0) has_white = true;
            }
            if (has_white) {
                white_h16_ws += 1;
                if (passes == 1) white_p1_mixed_h16 += 1;
            }
        }
        if (side == 0 and sl == -16) {
            black_lm16 += 1;
            var has_black = false;
            const b = unrank_board4(board);
            for (b) |c| {
                if (c > 0) has_black = true;
            }
            if (has_black) black_lm16_bs += 1;
        }
    }
    std.debug.print("# AUDIT verify nodes={d} L_violations={d} H_violations={d} L_null={d} H_null={d}\n", .{ nodes, l_viol, h_viol, l_null, h_null });
    std.debug.print("# AUDIT verify map_misses={d} terminal_islegal_skips={d}\n", .{ map_miss, term_islegal_skip });
    std.debug.print("# AUDIT population L==H={d} pin_T={d} pin_L={d} pin_H={d} tot_H16={d} tot_L-16={d}\n", .{ l_eq_h, pin_t, pin_l, pin_h, tot_h16, tot_lm16 });
    std.debug.print("# AUDIT population white-to-move H==16: {d} (with white stone: {d}; of those passes==1: {d} — MUST be 0)\n", .{ white_h16, white_h16_ws, white_p1_mixed_h16 });
    std.debug.print("# AUDIT population black-to-move L==-16: {d} (with black stone: {d})\n", .{ black_lm16, black_lm16_bs });
}

// ---------------------------------------------------------------------
// AUDIT 2: exhaustive colour inversion — L(-s) == -H(s), H(-s) == -L(s).
// ---------------------------------------------------------------------
fn auditInversion4(t: *const AuditTabs4) void {
    std.debug.print("\n## AUDIT inversion: exhaustive over compact states\n", .{});
    var checked: u64 = 0;
    var viol: u64 = 0;
    var miss: u64 = 0;
    var shown: u64 = 0;
    for (t.compact_list, 0..) |dense_idx, ci_usz| {
        const ci: u32 = @intCast(ci_usz);
        const passes: u2 = @intCast(dense_idx / (2 * KO_DIMS4 * RAW_TOTAL4));
        const rest: u64 = dense_idx % (2 * KO_DIMS4 * RAW_TOTAL4);
        const side: u1 = @intCast(rest / (KO_DIMS4 * RAW_TOTAL4));
        const rest2: u64 = rest % (KO_DIMS4 * RAW_TOTAL4);
        const ko: u5 = @intCast(rest2 / RAW_TOTAL4);
        const board: u32 = @intCast(rest2 % RAW_TOTAL4);
        const b = unrank_board4(board);
        var inv: Pos4 = undefined;
        for (0..N4) |i| inv[i] = -b[i];
        const inv_board = rank_board4(inv);
        checked += 1;
        if (auditLookup4(t, inv_board, 1 - side, ko, passes)) |e| {
            if (e.l != -t.H_tab[ci] or e.h != -t.L_tab[ci]) {
                viol += 1;
                if (shown < 5) {
                    shown += 1;
                    std.debug.print("# AUDIT inversion VIOLATION: (b={d},s={d},ko={d},p={d}) L={d} H={d} vs inverted L={d} H={d}\n", .{ board, side, ko, passes, t.L_tab[ci], t.H_tab[ci], e.l, e.h });
                }
            }
        } else {
            miss += 1;
            if (shown < 5) {
                shown += 1;
                std.debug.print("# AUDIT inversion MISS: inverted (b={d},s={d},ko={d},p={d}) not in map (orig b={d})\n", .{ inv_board, @as(u1, 1 - side), ko, passes, board });
            }
        }
    }
    std.debug.print("# AUDIT inversion checked={d} violations={d} inverse-misses={d}\n", .{ checked, viol, miss });
}

// ---------------------------------------------------------------------
// AUDIT 3: first-move symmetry classes — L/H of every (1B at k, W, p0).
// The 4-fold board symmetry should make these constant on {corners},
// {edges}, {centre 2x2}; the greatest-fixpoint machinery is colour- and
// rotation-symmetric, so asymmetric values would flag an addressing bug.
// ---------------------------------------------------------------------
fn auditFirstMoves4(t: *const AuditTabs4) void {
    std.debug.print("\n## AUDIT first moves: (1B at cell k, White to move, ko=NONE, passes=0)\n", .{});
    var pow3: u32 = 1;
    for (0..N4) |k| {
        const class: []const u8 = if (k == 0 or k == 3 or k == 12 or k == 15) "corner" else if (k == 5 or k == 6 or k == 9 or k == 10) "centre" else "edge";
        if (auditLookup4(t, pow3, 1, KO_NONE4, 0)) |e| {
            std.debug.print("# AUDIT firstmove k={d:>2} [{s}] L={d:>3} H={d:>3}\n", .{ k, class, e.l, e.h });
        } else {
            std.debug.print("# AUDIT firstmove k={d:>2} [{s}] *** MAP MISS ***\n", .{ k, class });
        }
        pow3 *= 3;
    }
}

// ---------------------------------------------------------------------
// AUDIT 4: trace A — the pass-out chain from the root to a terminal.
// root(B) --B@5--> (1B@5, W, 0) [enumerate ALL children; the minimizer's
// every child must have H=16 for the node's H=16 to hold] --W pass-->
// (1B@5, B, 1) --B pass--> terminal (area score of a lone black stone = 16).
// ---------------------------------------------------------------------
fn auditTraceA4(t: *const AuditTabs4) void {
    var buf: [N4 + 1]u64 = undefined;
    std.debug.print("\n## AUDIT trace A: root -> B@5 -> White node -> pass -> pass -> terminal\n", .{});
    const root = auditLookup4(t, 0, 0, KO_NONE4, 0).?;
    std.debug.print("#TRACE A node (empty, B, ko=NONE, p=0): L={d} H={d}\n", .{ root.l, root.h });

    var pow3: u32 = 1;
    for (0..5) |_| pow3 *= 3; // B at cell 5 -> board rank 3^5 = 243
    const s1 = auditLookup4(t, pow3, 1, KO_NONE4, 0).?;
    std.debug.print("#TRACE A node (1B@5, W, p=0): L={d} H={d}\n", .{ s1.l, s1.h });

    var cnt: usize = 0;
    genChildren4(encodeState4(pow3, 1, KO_NONE4, 0), &buf, &cnt);
    std.debug.print("#TRACE A node (1B@5, W, p=0) has {d} children; White minimises, so H=16 requires every child to have H=16:\n", .{cnt});
    var viol_a: u32 = 0;
    var pass_dest: u64 = 0;
    for (buf[0..cnt], 0..) |ce, i| {
        const cb = decodeBoard4(ce);
        const cs = decodeSide4(ce);
        const ck = decodeKo4(ce);
        const cp = decodePasses4(ce);
        const scnt = stoneCounts4(cb);
        if (cp == 2) {
            const bb = unrank_board4(cb);
            const sc = genericAreaScore(N4, &bb, W4, H4);
            std.debug.print("#TRACE A  child[{d:>2}] TERMINAL (bstones={d}, wstones={d}) area_score={d}\n", .{ i, scnt.b, scnt.w, sc });
            if (sc != 16) viol_a += 1;
        } else {
            const e = auditLookup4(t, cb, cs, ck, cp).?;
            const kind: []const u8 = if (cp == 1) "pass " else "place";
            std.debug.print("#TRACE A  child[{d:>2}] {s} (bstones={d}, wstones={d}, ko={d}, p={d}) L={d:>3} H={d:>3}\n", .{ i, kind, scnt.b, scnt.w, ck, cp, e.l, e.h });
            if (e.h != 16) viol_a += 1;
        }
        if (cp == 1 and cb == pow3 and ck == KO_NONE4 and cs == 0) pass_dest = ce;
    }
    std.debug.print("#TRACE A white-node children with H<16: {d}  {s}\n", .{ viol_a, if (viol_a == 0) "-> H=16 CONSISTENT at this minimizer node" else "-> *** CONTRADICTION: stored H=16 cannot equal min of children ***" });

    // descend the pass child
    const pb = decodeBoard4(pass_dest);
    const ps = decodeSide4(pass_dest);
    const pk = decodeKo4(pass_dest);
    const pp = decodePasses4(pass_dest);
    const s2 = auditLookup4(t, pb, ps, pk, pp).?;
    std.debug.print("#TRACE A node (1B@5, B, p=1): L={d} H={d}\n", .{ s2.l, s2.h });
    var cnt2: usize = 0;
    genChildren4(pass_dest, &buf, &cnt2);
    const t0 = buf[0]; // pass child is generated first; here it is the terminal
    const tb = decodeBoard4(t0);
    const tp = decodePasses4(t0);
    const bb = unrank_board4(tb);
    const sc = genericAreaScore(N4, &bb, W4, H4);
    std.debug.print("#TRACE A node (1B@5, B, p=1) pass child: passes={d} area_score={d}  (Black maximises: one child with H=16 suffices)\n", .{ tp, sc });
    std.debug.print("#TRACE A VERDICT: terminal reached, area score {d}; H=+16 flows terminal -> (1B@5,B,p1) -> (1B@5,W,p0) -> root\n", .{sc});
}

// ---------------------------------------------------------------------
// AUDIT 5: trace B — root -> B@start, then WHITE ALWAYS PASSES (White's
// purest attempt to drag the game to a sub-16 terminal). At every White
// node every child is re-checked (all must have H=16; a violation is a
// direct contradiction of the converged equation). At every Black node a
// 16-achieving child must exist. Ends at a terminal, at a cycle, or at a
// dead end (any of which would be decisive evidence).
// ---------------------------------------------------------------------
fn auditTraceB4(t: *const AuditTabs4, start_cell: u6) void {
    var buf: [N4 + 1]u64 = undefined;
    var visited: [320]u64 = undefined;
    var vn: usize = 0;
    std.debug.print("\n## AUDIT trace B from (1B@{d}, W, p=0), White always passes\n", .{start_cell});
    var pow3: u32 = 1;
    for (0..start_cell) |_| pow3 *= 3;
    var enc = encodeState4(pow3, 1, KO_NONE4, 0);
    var depth: u32 = 0;
    while (depth < 300) : (depth += 1) {
        const b = decodeBoard4(enc);
        const s = decodeSide4(enc);
        const k = decodeKo4(enc);
        const p = decodePasses4(enc);
        for (visited[0..vn]) |v| {
            if (v == enc) {
                std.debug.print("#TRACE B CYCLE at depth {d}: state revisited\n", .{depth});
                return;
            }
        }
        visited[vn] = enc;
        vn += 1;
        const scnt = stoneCounts4(b);
        if (p == 2) {
            const bb = unrank_board4(b);
            const sc = genericAreaScore(N4, &bb, W4, H4);
            std.debug.print("#TRACE B d={d} TERMINAL: bstones={d} wstones={d} area_score={d}\n", .{ depth, scnt.b, scnt.w, sc });
            std.debug.print("#TRACE B VERDICT start={d}: terminal reached, score {d}  {s}\n", .{ start_cell, sc, if (sc == 16) "-> H=16 witness COMPLETE" else "-> *** H=16 BROKEN on this line ***" });
            return;
        }
        const e = auditLookup4(t, b, s, k, p) orelse {
            std.debug.print("#TRACE B d={d} *** MAP MISS (b={d},s={d},ko={d},p={d}) ***\n", .{ depth, b, s, k, p });
            return;
        };
        const who: []const u8 = if (s == 0) "B" else "W";
        std.debug.print("#TRACE B d={d} {s} bstones={d} wstones={d} ko={d} p={d} L={d:>3} H={d:>3}\n", .{ depth, who, scnt.b, scnt.w, k, p, e.l, e.h });
        var cnt: usize = 0;
        genChildren4(enc, &buf, &cnt);
        if (s == 1) {
            // White node: verify ALL children have H == 16 (or score 16).
            var viol: u32 = 0;
            for (buf[0..cnt]) |ce| {
                const cp = decodePasses4(ce);
                const cb = decodeBoard4(ce);
                if (cp == 2) {
                    const bb = unrank_board4(cb);
                    const sc = genericAreaScore(N4, &bb, W4, H4);
                    if (sc != 16) viol += 1;
                } else {
                    const cs = decodeSide4(ce);
                    const ck = decodeKo4(ce);
                    const le = auditLookup4(t, cb, cs, ck, cp) orelse {
                        std.debug.print("#TRACE B   *** child MAP MISS ***\n", .{});
                        viol += 1;
                        continue;
                    };
                    if (le.h != 16) viol += 1;
                }
            }
            if (viol > 0) std.debug.print("#TRACE B   *** WHITE-NODE VIOLATION: {d} of {d} children have H<16 — stored H=16 contradicts min\n", .{ viol, cnt });
            // White passes: pass child is generated first.
            enc = buf[0];
        } else {
            // Black node: prefer a placement achieving 16; fall back to pass.
            var chosen: u64 = 0;
            var found = false;
            for (buf[0..cnt]) |ce| {
                const cp = decodePasses4(ce);
                if (cp != 0) continue; // placements only
                const cb = decodeBoard4(ce);
                const cs = decodeSide4(ce);
                const ck = decodeKo4(ce);
                const le = auditLookup4(t, cb, cs, ck, cp) orelse continue;
                if (le.h == 16) {
                    chosen = ce;
                    found = true;
                    break;
                }
            }
            if (!found) {
                // fall back to the pass child (buf[0])
                const pc = buf[0];
                const cp = decodePasses4(pc);
                const cb = decodeBoard4(pc);
                if (cp == 2) {
                    const bb = unrank_board4(cb);
                    const sc = genericAreaScore(N4, &bb, W4, H4);
                    std.debug.print("#TRACE B d={d} Black has no 16-placement; pass leads to terminal score {d}\n", .{ depth, sc });
                    if (sc == 16) {
                        chosen = pc;
                        found = true;
                    }
                } else {
                    const cs = decodeSide4(pc);
                    const ck = decodeKo4(pc);
                    if (auditLookup4(t, cb, cs, ck, cp)) |le| {
                        std.debug.print("#TRACE B d={d} Black has no 16-placement; pass child H={d}\n", .{ depth, le.h });
                        if (le.h == 16) {
                            chosen = pc;
                            found = true;
                        }
                    } else {
                        std.debug.print("#TRACE B d={d} pass child MAP MISS\n", .{depth});
                    }
                }
            }
            if (!found) {
                std.debug.print("#TRACE B d={d} *** BLACK DEAD END: no child with H=16 — stored H=16 contradicts max\n", .{depth});
                return;
            }
            enc = chosen;
        }
    }
    std.debug.print("#TRACE B start={d}: depth cap 300 reached without terminal/cycle — SUSPICIOUS\n", .{start_cell});
}
