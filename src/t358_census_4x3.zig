// T358 — 4×3 reachability census (glm-5.2/T358, 2026-08-20).
//
// Independent BFS reachability census over (board, side, ko, passes) for the
// 4×3 goban, reusing exp6_solve's generic move/capture/ko/legality primitives
// (genericPosFromMove, genericChainCaptured, genericNeighbors, genericIsLegal)
// — the same kernel the 4×4 build uses, parameterised to W=4, H=3. This is an
// independent re-implementation of the 4×3 reachable count the I5/closure
// battery reported (accept.md §3.1: V=1,929,035); it cross-checks that number
// from a fresh instrument rather than quoting it.
//
// State encoding mirrors exp6's StateIdx32:
//   linear = ((passes*2 + side) * KO_DIMS + ko) * RAW_TOTAL + board
//   KO_DIMS = n + 1  (ko ∈ 0..n-1, none = n); passes ∈ {0,1,2}.
// Roots: (empty, B, ko=none, passes=0) and (empty, W, ko=none, passes=0).
// Snapshot-sweep BFS (no queue); a pass move resets ko=none and passes+1.
//
// Build: tools/runner -- zig run -O ReleaseFast src/t358_census_4x3.zig

const std = @import("std");
const util = @import("util.zig");
const E = @import("exp6_solve.zig");

const W: usize = 4;
const H: usize = 3;
const N: usize = W * H; // 12
const RAW_TOTAL: u64 = blk: { var x: u64 = 1; for (0..N) |_| x *= 3; break :blk x; }; // 531,441
const KO_DIMS: u64 = N + 1; // 13
const TOTAL: u64 = RAW_TOTAL * 2 * KO_DIMS * 3; // 41,452,398
const ReachWords: u64 = (TOTAL + 63) / 64;
const KO_NONE: u16 = @intCast(N);

const Pos = [N]i8;

const StateIdx = packed struct {
    board: u32,
    side: u8,
    ko: u16,
    passes: u8,

    pub fn linear(self: StateIdx) u64 {
        return (((@as(u64, self.passes) * 2) + @as(u64, self.side)) * KO_DIMS + @as(u64, self.ko)) * RAW_TOTAL + self.board;
    }
};

fn unrank_board(idx: u32) Pos {
    var board: Pos = [_]i8{0} ** N;
    var v: u32 = idx;
    for (0..N) |i| {
        const d = v % 3;
        v /= 3;
        board[i] = switch (d) { 0 => 0, 1 => 1, 2 => -1, else => unreachable };
    }
    return board;
}

fn rank_board(board: Pos) u32 {
    var idx: u32 = 0;
    var mult: u32 = 1;
    for (board) |c| {
        const d: u32 = if (c > 0) 1 else if (c < 0) 2 else 0;
        idx += d * mult;
        mult *= 3;
    }
    return idx;
}

fn apply_place_real(state: StateIdx, board: *const Pos, colour: i8, cell: u8) ?StateIdx {
    if (board[cell] != 0) return null;
    if (state.ko != KO_NONE and @as(u16, cell) == state.ko) return null;
    var next = board.*;
    E.genericPosFromMove(N, &next, colour, cell, W, H) catch return null;
    var opp_before: u8 = 0;
    var opp_after: u8 = 0;
    var captured_cell: u16 = KO_NONE;
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
        const cnt = E.genericNeighbors(cell, W, H, &nb);
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
    return StateIdx{
        .board = state.board,
        .side = 1 - state.side,
        .ko = KO_NONE,
        .passes = state.passes + 1,
    };
}

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    const reach = try gpa.alloc(u64, ReachWords);
    defer gpa.free(reach);
    @memset(reach, 0);
    const snap = try gpa.alloc(u64, ReachWords);
    defer gpa.free(snap);

    // seed roots: empty board, both sides, ko=none, passes=0
    for ([_]u8{ 0, 1 }) |side| {
        const root = StateIdx{ .board = 0, .side = side, .ko = KO_NONE, .passes = 0 };
        const lin = root.linear();
        reach[lin >> 6] |= @as(u64, 1) << @intCast(lin & 63);
    }

    var new_marks: u64 = 1;
    var sweep_idx: u32 = 0;
    const MAX_SWEEPS: u32 = 128;
    var succ_boards: [N + 1]Pos = undefined;
    var succs: [N + 1]StateIdx = undefined;
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
            const board_idx: u32 = @intCast(rest2 % RAW_TOTAL);
            const state = StateIdx{ .board = board_idx, .side = side, .ko = ko, .passes = passes };
            if (state.passes == 2) continue;
            const board = unrank_board(board_idx);
            const colour: i8 = if (side == 1) 1 else -1;
            var m: usize = 0;
            // pass
            if (apply_pass(state)) |ns| {
                succs[m] = ns;
                succ_boards[m] = board;
                m += 1;
            }
            // placements
            for (0..N) |cell_u| {
                if (apply_place_real(state, &board, colour, @intCast(cell_u))) |ns| {
                    const nb = unrank_board(ns.board);
                    if (E.genericIsLegal(N, &nb, W, H)) {
                        succs[m] = ns;
                        succ_boards[m] = nb;
                        m += 1;
                    }
                }
            }
            for (0..m) |k| {
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
        if (sweep_idx % 16 == 0 or new_marks == 0) {
            util.note("# 4x3 census sweep {d}: new_marks = {d}\n", .{ sweep_idx, new_marks });
        }
    }

    var total_marked: u64 = 0;
    var terminal_marked: u64 = 0;
    var legal_boards: u64 = 0;
    var seen_boards = try gpa.alloc(bool, @intCast(RAW_TOTAL));
    defer gpa.free(seen_boards);
    @memset(seen_boards, false);
    var lin: u64 = 0;
    while (lin < TOTAL) : (lin += 1) {
        const word = lin >> 6;
        const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
        if (reach[word] & bit == 0) continue;
        total_marked += 1;
        const passes: u8 = @intCast(lin / (2 * KO_DIMS * RAW_TOTAL));
        if (passes == 2) terminal_marked += 1;
        const rest2: u64 = (lin % (2 * KO_DIMS * RAW_TOTAL)) % (KO_DIMS * RAW_TOTAL);
        const board_idx: u32 = @intCast(rest2 % RAW_TOTAL);
        const b = unrank_board(board_idx);
        if (E.genericIsLegal(N, &b, W, H) and !seen_boards[board_idx]) {
            seen_boards[board_idx] = true;
            legal_boards += 1;
        }
    }
    const non_terminal = total_marked - terminal_marked;
    util.out("# t358 4x3 reachability census; state space TOTAL = {d} (3^12 * 2 * 13 * 3)\n", .{TOTAL});
    util.out("# total reachable (all passes) = {d}\n", .{total_marked});
    util.out("#   passes in {{0,1}} (WZO2-stored) = {d}\n", .{non_terminal});
    util.out("#   passes == 2 (terminal)        = {d}\n", .{terminal_marked});
    util.out("# legal boards reachable = {d}\n", .{legal_boards});
    util.out("# sweeps to converge = {d}\n", .{sweep_idx});
}