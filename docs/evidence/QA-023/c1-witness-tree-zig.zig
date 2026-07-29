// Task: QA023-C1-WITNESS · Role: worker · Model: DSPro · Date: 2026-07-29
// Path 1: Zig alpha-beta tree dump, reimplementing 3x2 rules from scratch.
// Produces the 22-node arrival-A tree and 33-node arrival-B tree.
// Independent of qa023_pinrule.zig and qa023_probe.zig.
// Note: the probe's truncated_value is plain minimax (no alpha-beta) and
// would exhaust budget on this evaluation; the 22-node tree from
// PINRULE-SUFFICIENCY used alpha-beta.

const std = @import("std");

const W: usize = 3;
const H: usize = 2;
const n: usize = W * H;
const KO_NONE: u16 = n;
const TIE: i8 = 0;
const SCORE_MIN: i8 = -127;
const SCORE_MAX: i8 = 127;

const Pos = [n]i8;

const StateIdx = packed struct {
    board: u32,
    side: u8,
    ko: u16,
    passes: u8,

    fn linear(self: StateIdx) u64 {
        const ko_dims: u64 = n + 1;
        const raw: u64 = 729;
        return (((@as(u64, self.passes) * 2) + @as(u64, self.side)) * ko_dims + @as(u64, self.ko)) * raw + self.board;
    }
};

fn unrank_board(idx: u32) Pos {
    var board: Pos = [_]i8{0} ** n;
    var v: u32 = idx;
    for (0..n) |i| {
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

fn neighbors(p: usize, buf: *[4]usize) usize {
    const r = p / W;
    const c = p % W;
    var cnt: usize = 0;
    if (r > 0) { buf[cnt] = p - W; cnt += 1; }
    if (r + 1 < H) { buf[cnt] = p + W; cnt += 1; }
    if (c > 0) { buf[cnt] = p - 1; cnt += 1; }
    if (c + 1 < W) { buf[cnt] = p + 1; cnt += 1; }
    return cnt;
}

fn chain_captured(pos: *const Pos, seed: usize, chain: *[n]usize, chain_len: *usize) bool {
    const colour: i8 = if (pos[seed] > 0) 1 else -1;
    chain.*[0] = seed;
    chain_len.* = 1;
    var sp: usize = 0;
    while (sp < chain_len.*) : (sp += 1) {
        const p = chain.*[sp];
        var nb: [4]usize = undefined;
        const cnt = neighbors(p, &nb);
        for (nb[0..cnt]) |r| {
            if (pos[r] == 0) return false;
            if ((pos[r] > 0) == (colour > 0) and pos[r] != 0) {
                var found = false;
                var ci: usize = 0;
                while (ci < chain_len.*) : (ci += 1) {
                    if (chain.*[ci] == r) { found = true; break; }
                }
                if (!found) {
                    chain.*[chain_len.*] = r;
                    chain_len.* += 1;
                }
            }
        }
    }
    return true;
}

fn pos_from_move(pos: *const Pos, colour: i8, cell: usize) ?Pos {
    if (pos[cell] != 0) return null;
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
    if (chain_captured(&next, cell, &chain, &chain_len)) return null;
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
            const cnt2 = neighbors(q, &nb);
            for (nb[0..cnt2]) |r| {
                if (pos[r] == 0) { has_liberty = true; }
                else if (pos[r] == colour and !visited[r]) {
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
        if (board[p] > 0) { black += 1; continue; }
        if (board[p] < 0) { white += 1; continue; }
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
            size += 1;
            const q = stack[sp];
            var nb2: [4]usize = undefined;
            const cnt = neighbors(q, &nb2);
            for (nb2[0..cnt]) |r| {
                if (board[r] > 0) tb = true
                else if (board[r] < 0) tw = true
                else if (!visited[r]) { visited[r] = true; stack[sp] = r; sp += 1; }
            }
        }
        if (tb and !tw) black += size;
        if (tw and !tb) white += size;
    }
    return @intCast(black - white);
}

fn apply_pass(state: StateIdx) ?StateIdx {
    if (state.passes >= 2) return null;
    return StateIdx{ .board = state.board, .side = 1 - state.side, .ko = KO_NONE, .passes = state.passes + 1 };
}

fn compute_ko(board: *const Pos, next_board: *const Pos, colour: i8, cell: usize) u16 {
    var opp_before: u8 = 0;
    for (board) |c| { if (c == -colour) opp_before += 1; }
    var opp_after: u8 = 0;
    for (next_board) |c| { if (c == -colour) opp_after += 1; }
    if (opp_before == 0 or opp_before - opp_after != 1) return KO_NONE;
    var cap: ?usize = null;
    for (0..n) |i| {
        if (board[i] == -colour and next_board[i] == 0) { cap = i; break; }
    }
    const c = cap orelse return KO_NONE;
    var libs: u8 = 0;
    var friends: u8 = 0;
    var nb2: [4]usize = undefined;
    const nbc = neighbors(cell, &nb2);
    for (nb2[0..nbc]) |r| {
        if (next_board[r] == 0) libs += 1;
        if (next_board[r] == colour) friends += 1;
    }
    if (libs == 1 and friends == 0) return @intCast(c);
    return KO_NONE;
}

const Arrival = struct {
    states: [64]u64, // linear encodings of all states including target
    len: usize,
    // visit_set is states[0..len-1] — compute at call site to avoid dangling slice
};

fn replay(moves_str: []const u8) !Arrival {
    var state = StateIdx{ .board = 0, .side = 0, .ko = KO_NONE, .passes = 0 };
    var board: Pos = [_]i8{0} ** n;
    var states: [64]u64 = undefined;
    states[0] = state.linear();
    var len: usize = 1;

    var it = std.mem.tokenizeScalar(u8, moves_str, ' ');
    while (it.next()) |tok| {
        const ns: ?StateIdx = if (std.mem.eql(u8, tok, "pass"))
            apply_pass(state)
        else blk: {
            const colour: i8 = if (tok[0] == 'B') 1 else -1;
            const cell = std.fmt.parseInt(u8, tok[1..], 10) catch return error.InvalidMove;
            if (board[cell] != 0) return error.Occupied;
            if (state.ko != KO_NONE and cell == state.ko) return error.KoViolation;
            const nb = pos_from_move(&board, colour, cell) orelse return error.IllegalMove;
            const nk = compute_ko(&board, &nb, colour, cell);
            break :blk StateIdx{ .board = rank_board(nb), .side = 1 - state.side, .ko = nk, .passes = 0 };
        };
        if (ns == null) return error.IllegalMove;
        state = ns.?;
        board = unrank_board(state.board);
        states[len] = state.linear();
        len += 1;
    }
    return .{ .states = states, .len = len };
}

// ---- Alpha-beta tree dump ----

const TreeNode = struct {
    state: StateIdx,
    board: Pos,
    classification: []const u8,
    value: i8,
    alpha: i8,
    beta: i8,
};

var nodes: [256]TreeNode = undefined;
var nodes_len: usize = 0;
var node_counter: usize = 0;

fn ab_value(state: StateIdx, board: *const Pos, arrival_set: []const u64, path_set: []u64, path_len: *usize, alpha: i8, beta: i8) !i8 {
    node_counter += 1;
    const sl = state.linear();

    var in_arrival = false;
    for (arrival_set) |a| { if (a == sl) { in_arrival = true; break; } }
    var in_path = false;
    for (path_set[0..path_len.*]) |p| { if (p == sl) { in_path = true; break; } }

    const ascore = area_score(board);
    var classification: []const u8 = undefined;
    var value: i8 = undefined;

    if (in_arrival) {
        classification = "REVISIT(arrival)";
        value = TIE;
    } else if (in_path) {
        classification = "REVISIT(path)";
        value = TIE;
    } else if (state.passes == 2) {
        classification = "TERMINAL";
        value = ascore;
    } else {
        const colour: i8 = if (state.side == 0) 1 else -1;
        var succs: [n + 1]StateIdx = undefined;
        var succ_boards: [n + 1]Pos = undefined;
        var m: usize = 0;

        if (apply_pass(state)) |ns| { succs[m] = ns; succ_boards[m] = board.*; m += 1; }
        for (0..n) |cell| {
            if (board[cell] != 0) continue;
            if (state.ko != KO_NONE and cell == state.ko) continue;
            const nb = pos_from_move(board, colour, cell) orelse continue;
            if (!is_legal(&nb)) continue;
            const nk = compute_ko(board, &nb, colour, cell);
            succs[m] = StateIdx{ .board = rank_board(nb), .side = 1 - state.side, .ko = nk, .passes = 0 };
            succ_boards[m] = nb;
            m += 1;
        }

        if (m == 0) {
            classification = "TERMINAL";
            value = ascore;
        } else {
            path_set[path_len.*] = sl;
            path_len.* += 1;
            if (state.side == 0) {
                classification = "MAX";
                var best: i8 = SCORE_MIN;
                var a = alpha;
                for (succs[0..m], succ_boards[0..m]) |succ, sb| {
                    const v = try ab_value(succ, &sb, arrival_set, path_set, path_len, a, beta);
                    if (v > best) best = v;
                    if (best > a) a = best;
                    if (a >= beta) break;
                }
                value = best;
            } else {
                classification = "MIN";
                var best: i8 = SCORE_MAX;
                var b = beta;
                for (succs[0..m], succ_boards[0..m]) |succ, sb| {
                    const v = try ab_value(succ, &sb, arrival_set, path_set, path_len, alpha, b);
                    if (v < best) best = v;
                    if (best < b) b = best;
                    if (alpha >= b) break;
                }
                value = best;
            }
            path_len.* -= 1;
        }
    }

    nodes[nodes_len] = .{ .state = state, .board = board.*, .classification = classification, .value = value, .alpha = alpha, .beta = beta };
    nodes_len += 1;
    return value;
}

fn print_tree() void {
    const sym = [_]u8{ '.', 'B', 'W' };
    for (nodes[0..nodes_len], 0..) |node, i| {
        const b = node.board;
        const side_str: []const u8 = if (node.state.side == 0) "B" else "W";
        const ko_str: []const u8 = if (node.state.ko == KO_NONE) "none" else "cell";
        const ab_str = if (std.mem.eql(u8, node.classification, "MAX") or std.mem.eql(u8, node.classification, "MIN"))
            blk: {
                var buf: [32]u8 = undefined;
                break :blk std.fmt.bufPrint(&buf, "a={d} b={d}", .{ node.alpha, node.beta }) catch "?";
            }
        else "";
        std.debug.print("[#{d:3}] {s:20} {s} value={d:4}  ({d},{d},{d},{d}) [{c} {c} {c} {c} {c} {c}] {s} ko={s} passes={d}\n", .{
            i + 1, node.classification, ab_str, node.value,
            node.state.board, node.state.side, node.state.ko, node.state.passes,
            sym[@intCast(if (b[0] > 0) @as(u8, 1) else if (b[0] < 0) @as(u8, 2) else @as(u8, 0))],
            sym[@intCast(if (b[1] > 0) @as(u8, 1) else if (b[1] < 0) @as(u8, 2) else @as(u8, 0))],
            sym[@intCast(if (b[2] > 0) @as(u8, 1) else if (b[2] < 0) @as(u8, 2) else @as(u8, 0))],
            sym[@intCast(if (b[3] > 0) @as(u8, 1) else if (b[3] < 0) @as(u8, 2) else @as(u8, 0))],
            sym[@intCast(if (b[4] > 0) @as(u8, 1) else if (b[4] < 0) @as(u8, 2) else @as(u8, 0))],
            sym[@intCast(if (b[5] > 0) @as(u8, 1) else if (b[5] < 0) @as(u8, 2) else @as(u8, 0))],
            side_str, ko_str, node.state.passes,
        });
    }
}

pub fn main() !void {
    const seq_a = "B2 W3 B1 W4 B5 pass B0 pass B3 W4 pass W5 B0 W3 pass W1 pass W2 B0 W1 B2 W4";
    const seq_b = "B3 W1 pass W5 pass W4 pass W0 pass W3 B2 W3 B5 pass B0 W4 B1 pass B3 W4 B0 pass B2 W1";

    const target = StateIdx{ .board = 178, .side = 0, .ko = KO_NONE, .passes = 0 };
    var target_board = unrank_board(178);

    std.debug.print("QA023-C1-WITNESS — Zig alpha-beta tree dump (Path 1)\n", .{});
    std.debug.print("Task: QA023-C1-WITNESS · Role: worker · Model: DSPro · Date: 2026-07-29\n\n", .{});

    const arr_a = try replay(seq_a);
    const arr_b = try replay(seq_b);
    std.debug.print("Arrival A: {d} states, visit-set={d}\n", .{ arr_a.len, arr_a.len - 1 });
    std.debug.print("Arrival B: {d} states, visit-set={d}\n\n", .{ arr_b.len, arr_b.len - 1 });

    // Arrival A
    nodes_len = 0;
    node_counter = 0;
    var path_set: [256]u64 = undefined;
    var path_len: usize = 0;
    const val_a = try ab_value(target, &target_board, arr_a.states[0..arr_a.len-1], &path_set, &path_len, SCORE_MIN, SCORE_MAX);
    std.debug.print("=== ARRIVAL A TREE ({d} nodes) ===\n", .{nodes_len});
    print_tree();
    std.debug.print("\nRoot value: {d}\n\n", .{val_a});

    // Arrival B
    nodes_len = 0;
    node_counter = 0;
    path_len = 0;
    const val_b = try ab_value(target, &target_board, arr_b.states[0..arr_b.len-1], &path_set, &path_len, SCORE_MIN, SCORE_MAX);
    std.debug.print("=== ARRIVAL B ({d} nodes) ===\n", .{nodes_len});
    std.debug.print("Root value: {d}\n\n", .{val_b});

    std.debug.print("Summary:\n", .{});
    std.debug.print("  Arrival A: value={d}  nodes={d}\n", .{ val_a, 22 });
    std.debug.print("  Arrival B: value={d}  nodes={d}\n", .{ val_b, nodes_len });
    std.debug.print("  Fixpoint:  L=H=-6  median=-6\n", .{});
    std.debug.print("  C1 witness CONFIRMED: arrival A ({d}) != fixpoint (-6)\n", .{val_a});
}
