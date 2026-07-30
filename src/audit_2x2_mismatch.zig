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
// AUDIT-2X2-MISMATCH — is the EXP-4 2×2 fixpoint/brute-force gap real?
//
// Task: AUDIT-2X2-MISMATCH · Role: auditor · Model: Opus 5 · Date: 2026-07-30
//
// EXP-4 reported 24 of 172 reachable non-terminal 2×2 states where the
// loopy-game fixpoint gives ±4 but its first-revisit-truncation brute force
// gives 0, and read the gap as genuine semantic divergence.
//
// `brute_value_2x2` in `src/exp4_solve.zig` threads ONE successor buffer
// through the whole recursion:
//
//     fn brute_value_2x2(..., succs_buf: *[5]Brute2x2.State) ?i8 {
//         ... fills succs_buf[0..m] with this node's children ...
//         for (succs_buf[0..m]) |child| {
//             const v = brute_value_2x2(child, ..., succs_buf);
//         }                                        ^^^^^^^^^ same buffer
//     }
//
// Zig loads slice element i at iteration i, so every child after the first
// is read back after the recursive call has overwritten the buffer with some
// deeper node's children. This file runs the two evaluators side by side —
// the original (shared buffer) and a fix that differs ONLY in giving each
// recursion frame its own buffer — over every reachable non-terminal state.
//
// Build:
//   tools/runner -- zig run -O ReleaseFast src/audit_2x2_mismatch.zig

const std = @import("std");

const TIE: i8 = 0;

const Brute2x2 = @import("qa023_brute_2x2.zig");
const N2_TOTAL: usize = Brute2x2.TOTAL_STATES; // 1620
const N2_N: usize = 4;

// =========================================================================
// Fixpoint — verbatim from src/exp4_solve.zig
// =========================================================================
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
// (A) ORIGINAL brute force — verbatim from src/exp4_solve.zig.
//     One `succs_buf` is threaded through every recursion level.
// =========================================================================
fn brute_shared(
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
        const v = brute_shared(child, history_set, depth + 1, node_budget, succs_buf);
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

// =========================================================================
// (B) FIXED brute force — identical line for line to (A) except that the
//     successor buffer is a local, so each frame owns its own children.
// =========================================================================
fn brute_local(
    state: Brute2x2.State,
    history_set: []u64,
    depth: u32,
    node_budget: *u64,
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
    var succs_buf: [5]Brute2x2.State = undefined; // <-- the only difference
    var m: usize = 0;
    if (Brute2x2.State.apply_pass(state)) |ns| { succs_buf[m] = ns; m += 1; }
    for (0..N2_N) |cell| {
        if (Brute2x2.State.apply_place(state, @intCast(cell))) |ns| { succs_buf[m] = ns; m += 1; }
    }

    var best: ?i8 = null;
    for (succs_buf[0..m]) |child| {
        const v = brute_local(child, history_set, depth + 1, node_budget);
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

// =========================================================================
// (C) FIXED brute force + alpha-beta.
//
//     (B) shows the honest first-revisit-truncation tree does not fit in
//     500k nodes. Alpha-beta is sound here: first-revisit truncation is a
//     plain minimax over a (path, state) tree, and pruning only skips
//     subtrees — there is no transposition table, so nothing path-dependent
//     is ever reused across paths. With a full window the root value is
//     exact regardless of move order; ordering only changes the node count.
//     Children are tried most-material-favourable first, a heuristic
//     computed from the goban alone and independent of the fixpoint tables.
// =========================================================================
fn material(board: [4]i8) i8 {
    var m: i8 = 0;
    for (board) |c| m += c;
    return m;
}

fn brute_ab(
    state: Brute2x2.State,
    history_set: []u64,
    depth: u32,
    node_budget: *u64,
    alpha_in: i8,
    beta_in: i8,
) ?i8 {
    if (node_budget.* == 0) return null;
    node_budget.* -= 1;

    const idx = Brute2x2.global_index(state);
    if (history_set[idx >> 6] & (@as(u64, 1) << @intCast(idx & 63)) != 0) return TIE;

    if (state.passes == 2) return state.terminal_value();
    if (depth > 128) return TIE;

    history_set[idx >> 6] |= @as(u64, 1) << @intCast(idx & 63);

    const maximizing = state.side > 0;
    var succs_buf: [5]Brute2x2.State = undefined;
    var m: usize = 0;
    if (Brute2x2.State.apply_pass(state)) |ns| { succs_buf[m] = ns; m += 1; }
    for (0..N2_N) |cell| {
        if (Brute2x2.State.apply_place(state, @intCast(cell))) |ns| { succs_buf[m] = ns; m += 1; }
    }

    // Insertion sort: best material for the side to move first.
    var a: usize = 1;
    while (a < m) : (a += 1) {
        var b = a;
        while (b > 0) : (b -= 1) {
            const lhs = material(succs_buf[b].board);
            const rhs = material(succs_buf[b - 1].board);
            const swap = if (maximizing) lhs > rhs else lhs < rhs;
            if (!swap) break;
            const tmp = succs_buf[b];
            succs_buf[b] = succs_buf[b - 1];
            succs_buf[b - 1] = tmp;
        }
    }

    var alpha = alpha_in;
    var beta = beta_in;
    var best: ?i8 = null;
    for (succs_buf[0..m]) |child| {
        const v = brute_ab(child, history_set, depth + 1, node_budget, alpha, beta);
        if (v == null) {
            history_set[idx >> 6] &= ~(@as(u64, 1) << @intCast(idx & 63));
            return null;
        }
        if (best == null or (if (maximizing) v.? > best.? else v.? < best.?)) best = v;
        if (maximizing) {
            if (best.? > alpha) alpha = best.?;
        } else {
            if (best.? < beta) beta = best.?;
        }
        if (alpha >= beta) break;
    }

    history_set[idx >> 6] &= ~(@as(u64, 1) << @intCast(idx & 63));
    if (best == null) return state.terminal_value();
    return best;
}

fn show(board: [4]i8) [5]u8 {
    var out: [5]u8 = undefined;
    const sym = [_]u8{ '.', 'B', 'W' };
    const d = struct {
        fn f(c: i8) usize {
            return if (c > 0) 1 else if (c < 0) 2 else 0;
        }
    };
    out[0] = sym[d.f(board[0])];
    out[1] = sym[d.f(board[1])];
    out[2] = '/';
    out[3] = sym[d.f(board[2])];
    out[4] = sym[d.f(board[3])];
    return out;
}

pub fn main() !void {
    const gpa = std.heap.page_allocator;

    std.debug.print("# ============================================================\n", .{});
    std.debug.print("# AUDIT-2X2-MISMATCH — shared vs per-frame successor buffer\n", .{});
    std.debug.print("# Opus 5 · 2026-07-30 · cross-check of EXP-4 (DSPro)\n", .{});
    std.debug.print("# ============================================================\n", .{});

    const fp = run_fixpoint_2x2();
    std.debug.print("# fixpoint: sweeps={d} converged={}\n", .{ fp.sweeps, fp.converged });

    const s_root_b = Brute2x2.State{ .board = .{0} ** N2_N, .side = 1, .ko_point = Brute2x2.State.KO_NONE, .passes = 0 };
    const s_root_w = Brute2x2.State{ .board = .{0} ** N2_N, .side = -1, .ko_point = Brute2x2.State.KO_NONE, .passes = 0 };

    var visited = try std.DynamicBitSetUnmanaged.initEmpty(gpa, N2_TOTAL);
    defer visited.deinit(gpa);
    try Brute2x2.mark_reachable(s_root_b, &visited, gpa);
    try Brute2x2.mark_reachable(s_root_w, &visited, gpa);

    const hist_words = (N2_TOTAL + 63) / 64;
    const history_set = try gpa.alloc(u64, hist_words);
    defer gpa.free(history_set);
    var succs_buf: [5]Brute2x2.State = undefined;

    const BUDGET_PLAIN: u64 = 500_000; // exp4's own per-state budget
    const BUDGET_AB: u64 = 2_000_000_000;

    var n_states: u64 = 0;
    var shared_mism: u64 = 0;
    var local_mism: u64 = 0;
    var ab_mism: u64 = 0;
    var shared_exhausted: u64 = 0;
    var local_exhausted: u64 = 0;
    var ab_exhausted: u64 = 0;
    var ab_nodes_total: u64 = 0;
    var ab_nodes_max: u64 = 0;

    std.debug.print("# per-state table (only rows where some evaluator disagrees with the fixpoint)\n", .{});
    var it = visited.iterator(.{});
    while (it.next()) |idx| {
        const s = Brute2x2.state_from_index(idx);
        if (s.passes == 2) continue;
        n_states += 1;
        const fp_val = fp.v(idx);

        @memset(history_set, 0);
        var budget_a: u64 = BUDGET_PLAIN;
        const v_shared = brute_shared(s, history_set, 0, &budget_a, &succs_buf);

        @memset(history_set, 0);
        var budget_b: u64 = BUDGET_PLAIN;
        const v_local = brute_local(s, history_set, 0, &budget_b);

        @memset(history_set, 0);
        var budget_c: u64 = BUDGET_AB;
        const v_ab = brute_ab(s, history_set, 0, &budget_c, -5, 5);
        const ab_nodes = BUDGET_AB - budget_c;
        ab_nodes_total += ab_nodes;
        if (ab_nodes > ab_nodes_max) ab_nodes_max = ab_nodes;

        if (v_shared == null) shared_exhausted += 1;
        if (v_local == null) local_exhausted += 1;
        if (v_ab == null) ab_exhausted += 1;

        const bad_shared = v_shared == null or v_shared.? != fp_val;
        const bad_local = v_local == null or v_local.? != fp_val;
        const bad_ab = v_ab == null or v_ab.? != fp_val;
        if (bad_shared) shared_mism += 1;
        if (bad_local) local_mism += 1;
        if (bad_ab) ab_mism += 1;

        if (bad_shared or bad_ab) {
            std.debug.print("# idx={d:>4} {s} side={s} passes={d}  L={d:>2} H={d:>2} V={d:>2}  shared={?d} plain={?d} ab={?d} ab_nodes={d}  {s}\n", .{
                idx,
                &show(s.board),
                if (s.side > 0) "B" else "W",
                s.passes,
                fp.L[idx],
                fp.H[idx],
                fp_val,
                v_shared,
                v_local,
                v_ab,
                ab_nodes,
                if (bad_ab) "AB-DISAGREES" else "shared-buffer-artifact",
            });
        }
    }

    std.debug.print("#\n", .{});
    std.debug.print("# non-terminal reachable states: {d}\n", .{n_states});
    std.debug.print("# (A) shared buffer, budget {d} [exp4 as committed]: disagreements={d} exhausted={d}\n", .{ BUDGET_PLAIN, shared_mism, shared_exhausted });
    std.debug.print("# (B) per-frame buffer, budget {d}:                  disagreements={d} exhausted={d}\n", .{ BUDGET_PLAIN, local_mism, local_exhausted });
    std.debug.print("# (C) per-frame buffer + alpha-beta, budget {d}: disagreements={d} exhausted={d}\n", .{ BUDGET_AB, ab_mism, ab_exhausted });
    std.debug.print("#     alpha-beta nodes: total={d} max-per-state={d}\n", .{ ab_nodes_total, ab_nodes_max });
    std.debug.print("#\n", .{});
    std.debug.print("# VERDICT: {s}\n", .{if (shared_mism > 0 and ab_mism == 0 and ab_exhausted == 0)
        "EXP-4's 24 mismatches are a shared-buffer aliasing artifact — the exact first-revisit-truncation value agrees with the fixpoint on ALL states"
    else if (ab_mism > 0)
        "exact evaluator still disagrees on some states — inspect AB-DISAGREES rows"
    else
        "inconclusive — alpha-beta exhausted its budget somewhere"});
}
