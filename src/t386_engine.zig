////////////////////////////////////////////
//                                        //
//    (c) 2026 Alexander E Genaud         //
//                                        //
//    Permission is granted hereby,       //
//        for any purpose,                //
//    provided these notices multiply.    //
//                                        //
////////////////////////////////////////////
//
// T386 (flash) — shared engine for the cycle-resolution ADR instruments.
//
// A generic ko-state retrograde fixpoint engine over
//   state = (board: base-3 rank u32, side: u8 {0=Black to move, 1=White},
//            ko: u16 {0..N-1 = ko point, N = none}, passes: u8 {0,1,2})
// with basic-ko legality (a move may not recapture at the ko point) and the
// ADR-0020 long-cycle verdict (TIE = 0): terminal = second consecutive pass,
// scored by Chinese area. This is exactly the semantics of the WZO2 tables
// (exp6_solve.zig run_fixpoint_3x3/4x4); the linear index convention is
// identical: (((passes*2)+side)*KO_DIMS + ko)*RAW_TOTAL + board.
//
// Used at 3×3 — regression-gated entry-for-entry against
// data/oracle-3x3-v2.wzo2 and against exp6_solve.zig's published counts —
// and at 4×3, where no WZO2 artifact exists and the engine is the fresh
// construction (validated only by the 3×3 gate + the exp6 move kernel).
//
// Also carries: the WZO2 artifact reader (fresh-start L/H lookup), the WZO1
// PSK fresh-start loader, and the independent-ko-cluster helper.
//
// Measurement instrument only — additive; no engine file is imported from
// src/ (only exp6_solve.zig's generic move-kernel helpers, itself a
// measurement-support module, plus rules/colex/enumerate).
//
// Compile (ad hoc, per instrument):
//   zig build-exe -O ReleaseFast --dep version -Mroot=src/t386_<tool>.zig \
//     -Mversion=src/version.zig --cache-dir /tmp/weizigo/t386/kc \
//     --global-cache-dir /tmp/weizigo/t386/gc --name weizigo-t386-<tool> \
//     -femit-bin=/tmp/weizigo/t386/<tool>

const std = @import("std");
const exp6 = @import("exp6_solve.zig");
const colexmod = @import("colex.zig");
const artifact = @import("artifact.zig");

pub fn pow3(n: usize) u64 {
    var x: u64 = 1;
    for (0..n) |_| x *= 3;
    return x;
}

pub fn Engine(comptime W: usize, comptime H: usize) type {
    return struct {
        pub const N: usize = W * H;
        pub const RAW_TOTAL: u64 = pow3(N);
        pub const KO_DIMS: u64 = N + 1;
        pub const TOTAL: u64 = RAW_TOTAL * 2 * KO_DIMS * 3; // passes {0,1,2}
        pub const ReachWords: u64 = (TOTAL + 63) / 64;
        pub const KO_NONE: u16 = @intCast(N);
        pub const Pos = [N]i8;

        pub const State = packed struct {
            board: u32,
            side: u8,
            ko: u16,
            passes: u8,

            pub fn linear(self: State) u64 {
                return (((@as(u64, self.passes) * 2) + @as(u64, self.side)) * KO_DIMS + @as(u64, self.ko)) * RAW_TOTAL + self.board;
            }
        };

        pub fn unrank(idx: u32) Pos {
            var board: Pos = [_]i8{0} ** N;
            var v: u32 = idx;
            for (0..N) |i| {
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

        pub fn rank(board: *const Pos) u32 {
            var idx: u32 = 0;
            var mult: u32 = 1;
            for (board) |c| {
                const d: u32 = if (c > 0) 1 else if (c < 0) 2 else 0;
                idx += d * mult;
                mult *= 3;
            }
            return idx;
        }

        pub fn stonesOf(pos: *const Pos) u8 {
            var c: u8 = 0;
            for (pos) |v| {
                if (v != 0) c += 1;
            }
            return c;
        }

        /// The T273 kernel legality predicate (same one the production
        /// fixpoint uses to gate children).
        pub fn isLegalBoard(pos: *const Pos) bool {
            return exp6.genericIsLegal(N, pos, W, H);
        }

        /// Basic-ko legal placement (mirror of exp6 apply_place): occupied or
        /// ko-point recapture returns null; suicide/illegal returns null via
        /// genericPosFromMove.
        pub fn applyPlace(state: State, board: *const Pos, colour: i8, cell: u8) ?State {
            if (board[cell] != 0) return null;
            if (state.ko != N and cell == state.ko) return null;
            var next = board.*;
            _ = exp6.genericPosFromMove(N, &next, colour, cell, W, H) catch return null;
            var opp_before: u8 = 0;
            var opp_after: u8 = 0;
            var captured_cell: u8 = @intCast(KO_NONE);
            for (0..N) |i| {
                if (board[i] == -colour) opp_before += 1;
                if (next[i] == -colour) opp_after += 1;
                if (board[i] == -colour and next[i] == 0) captured_cell = @intCast(i);
            }
            var new_ko: u16 = KO_NONE;
            if ((opp_before - opp_after == 1) and (captured_cell != N)) {
                var liberties: u8 = 0;
                var friendly: u8 = 0;
                var nb: [4]usize = undefined;
                const cnt = exp6.genericNeighbors(cell, W, H, &nb);
                for (nb[0..cnt]) |q| {
                    if (next[q] == 0) liberties += 1;
                    if (next[q] == colour) friendly += 1;
                }
                if (liberties == 1 and friendly == 0) new_ko = captured_cell;
            }
            return State{
                .board = rank(&next),
                .side = if (colour == 1) @as(u8, 1) else @as(u8, 0),
                .ko = new_ko,
                .passes = 0,
            };
        }

        pub fn applyPass(state: State) ?State {
            if (state.passes >= 2) return null;
            return State{ .board = state.board, .side = 1 - state.side, .ko = KO_NONE, .passes = state.passes + 1 };
        }

        /// All legal moves (pass first, then placements), mirror of exp6.moves.
        pub fn moves(state: State, succ_boards: *[N + 1]Pos, succs: *[N + 1]State) usize {
            if (state.passes == 2) return 0;
            const board = unrank(state.board);
            const colour: i8 = if (state.side == 0) 1 else -1;
            var count: usize = 0;
            if (applyPass(state)) |ns| {
                succ_boards[count] = unrank(ns.board);
                succs[count] = ns;
                count += 1;
            }
            for (0..N) |cell_u| {
                const cell: u8 = @intCast(cell_u);
                if (applyPlace(state, &board, colour, cell)) |ns| {
                    succ_boards[count] = unrank(ns.board);
                    succs[count] = ns;
                    count += 1;
                }
            }
            return count;
        }

        pub const CensusResult = struct {
            total_marked: u64,
            legal_boards: u64,
            sweeps: u32,
        };

        /// Reachability BFS from the two fresh-start roots (mirror of
        /// exp6.run_census_3x3, generic over W/H).
        pub fn census(gpa: std.mem.Allocator, reach: []u64) !CensusResult {
            @memset(reach, 0);
            const snap = try gpa.alloc(u64, ReachWords);
            defer gpa.free(snap);
            for ([_]u8{ 0, 1 }) |side| {
                const root = State{ .board = 0, .side = side, .ko = KO_NONE, .passes = 0 };
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
                    const state = State{ .board = board, .side = side, .ko = ko, .passes = passes };
                    var succ_boards: [N + 1]Pos = undefined;
                    var succs: [N + 1]State = undefined;
                    const m = moves(state, &succ_boards, &succs);
                    for (0..m) |k| {
                        if (!exp6.genericIsLegal(N, &succ_boards[k], W, H)) continue;
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
                    std.debug.print("# {d}x{d} census sweep {d}: new_marks = {d}\n", .{ W, H, sweep_idx, new_marks });
                }
            }
            var total_marked: u64 = 0;
            var legal_boards: u64 = 0;
            var seen_boards = [_]bool{false} ** @as(usize, RAW_TOTAL);
            var lin: u64 = 0;
            while (lin < TOTAL) : (lin += 1) {
                const word = lin >> 6;
                const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
                if (reach[word] & bit == 0) continue;
                total_marked += 1;
                const rest2: u64 = lin % (KO_DIMS * RAW_TOTAL);
                const board_idx: u32 = @intCast(rest2 % RAW_TOTAL);
                const b = unrank(board_idx);
                if (exp6.genericIsLegal(N, &b, W, H) and !seen_boards[board_idx]) {
                    seen_boards[board_idx] = true;
                    legal_boards += 1;
                }
            }
            return CensusResult{ .total_marked = total_marked, .legal_boards = legal_boards, .sweeps = sweep_idx };
        }

        /// Seed L/H: -N/+N for reachable non-terminal, area score for
        /// passes==2 (mirror of exp6.run_fixpoint_3x3 seeding).
        pub fn seed(reach: []const u64, L: []i8, Hi: []i8) void {
            const L_init: i8 = -@as(i8, @intCast(N));
            const H_init: i8 = @as(i8, @intCast(N));
            for (0..TOTAL) |i| {
                L[i] = L_init;
                Hi[i] = H_init;
            }
            var lin: u64 = 0;
            while (lin < TOTAL) : (lin += 1) {
                const word = lin >> 6;
                const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
                if (reach[word] & bit == 0) continue;
                const passes: u8 = @intCast(lin / (2 * KO_DIMS * RAW_TOTAL));
                if (passes == 2) {
                    const rest2: u64 = lin % (KO_DIMS * RAW_TOTAL);
                    const board_idx: u32 = @intCast(rest2 % RAW_TOTAL);
                    const b = unrank(board_idx);
                    const sc = exp6.genericAreaScore(N, &b, W, H);
                    L[lin] = sc;
                    Hi[lin] = sc;
                }
            }
        }

        /// One Bellman sweep over both bounds. `pinned` (optional): held
        /// states are skipped (their values are data). Mirrors the exp6
        /// update rule: for each reachable non-terminal state, best L/H over
        /// legal children (max for Black to move, min for White).
        pub fn sweep(reach: []const u64, L: []i8, Hi: []i8, pinned: ?[]const bool) u64 {
            var changes: u64 = 0;
            var lin: u64 = 0;
            while (lin < TOTAL) : (lin += 1) {
                const word = lin >> 6;
                const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
                if (reach[word] & bit == 0) continue;
                const passes: u8 = @intCast(lin / (2 * KO_DIMS * RAW_TOTAL));
                if (passes == 2) continue;
                if (pinned != null and pinned.?[lin]) continue;
                const rest: u64 = lin % (2 * KO_DIMS * RAW_TOTAL);
                const side: u8 = @intCast(rest / (KO_DIMS * RAW_TOTAL));
                const rest2: u64 = rest % (KO_DIMS * RAW_TOTAL);
                const ko: u16 = @intCast(rest2 / RAW_TOTAL);
                const board: u32 = @intCast(rest2 % RAW_TOTAL);
                const state = State{ .board = board, .side = side, .ko = ko, .passes = passes };
                var succ_boards: [N + 1]Pos = undefined;
                var succs: [N + 1]State = undefined;
                const m = moves(state, &succ_boards, &succs);
                const maximizing = side == 0;
                var best_l: ?i8 = null;
                var best_h: ?i8 = null;
                for (0..m) |k| {
                    if (!exp6.genericIsLegal(N, &succ_boards[k], W, H)) continue;
                    const child_li = succs[k].linear();
                    const vl = L[child_li];
                    const vh = Hi[child_li];
                    if (best_l == null or (if (maximizing) vl > best_l.? else vl < best_l.?)) best_l = vl;
                    if (best_h == null or (if (maximizing) vh > best_h.? else vh < best_h.?)) best_h = vh;
                }
                if (best_l != null and best_l.? != L[lin]) {
                    L[lin] = best_l.?;
                    changes += 1;
                }
                if (best_h != null and best_h.? != Hi[lin]) {
                    Hi[lin] = best_h.?;
                    changes += 1;
                }
            }
            return changes;
        }

        pub const ConvResult = struct { sweeps: u32, converged: bool };

        /// Iterate both fixpoints to a zero-change sweep (chaotic iteration
        /// of a monotone map from the current values; with pinned states held
        /// the free states converge monotonically — pinned values inside the
        /// original brackets move L up and H down only).
        pub fn converge(reach: []const u64, L: []i8, Hi: []i8, pinned: ?[]const bool) ConvResult {
            var sweep_idx: u32 = 0;
            var total_changes: u64 = 1;
            const MAX_SWEEPS: u32 = 256;
            while (total_changes > 0 and sweep_idx < MAX_SWEEPS) {
                sweep_idx += 1;
                const c = sweep(reach, L, Hi, pinned);
                total_changes = c;
                if (sweep_idx % 8 == 0 or total_changes == 0) {
                    std.debug.print("# {d}x{d} fixpoint sweep {d}: changes={d}\n", .{ W, H, sweep_idx, total_changes });
                }
            }
            return ConvResult{ .sweeps = sweep_idx, .converged = total_changes == 0 };
        }

        /// Fresh-start linear index of a board for a side (ko = none,
        /// passes = 0) — the state whose value is the oracle's V0.
        pub fn freshStartLin(board: u32, side: u8) u64 {
            return (State{ .board = board, .side = side, .ko = KO_NONE, .passes = 0 }).linear();
        }

        /// Bracket violation counts over all reachable legal positions:
        /// L > H anywhere (want 0), and certification sanity.
        pub const Health = struct { l_gt_h: u64, brackets: u64 };

        pub fn health(reach: []const u64, L: []i8, Hi: []i8) Health {
            var l_gt_h: u64 = 0;
            var brackets: u64 = 0;
            var lin: u64 = 0;
            while (lin < TOTAL) : (lin += 1) {
                const word = lin >> 6;
                const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
                if (reach[word] & bit == 0) continue;
                if (L[lin] > Hi[lin]) l_gt_h += 1;
                if (L[lin] < Hi[lin]) brackets += 1;
            }
            return .{ .l_gt_h = l_gt_h, .brackets = brackets };
        }
    };
}

// ─── WZO2 artifact reader (the current table format) ───────────────────────

pub const GroupHdr = struct { colex: u32, count: u8, entry_offset: u64 };
pub const Wzo2 = struct {
    bytes: []const u8,
    n_groups: u64,
    ko_bits: u8,
    group_base: usize,
    entry_base: usize,
    groups: []GroupHdr,

    pub fn open(gpa: std.mem.Allocator, path: []const u8) !Wzo2 {
        var threaded = std.Io.Threaded.init(gpa, .{});
        defer threaded.deinit();
        const io = threaded.io();
        const cwd = std.Io.Dir.cwd();
        const bytes = try cwd.readFileAlloc(io, path, gpa, .unlimited);
        if (!std.mem.eql(u8, bytes[0..4], "WZO2")) return error.BadWzo2;
        const n_groups = std.mem.readInt(u64, bytes[16..24], .little);
        const ko_bits = bytes[13];
        const group_base: usize = 128;
        const entry_base: usize = group_base + @as(usize, @intCast(n_groups)) * 5;
        const groups = try gpa.alloc(GroupHdr, @intCast(n_groups));
        var cum: u64 = 0;
        for (0..@as(usize, @intCast(n_groups))) |i| {
            const off = group_base + i * 5;
            groups[i] = .{ .colex = std.mem.readInt(u32, bytes[off..][0..4], .little), .count = bytes[off + 4], .entry_offset = cum };
            cum += groups[i].count;
        }
        return .{ .bytes = bytes, .n_groups = n_groups, .ko_bits = ko_bits, .group_base = group_base, .entry_base = entry_base, .groups = groups };
    }

    pub const Entry = struct { L: i8, H: i8, ko: u16, side: i8, passes: u2, terminal: bool };

    pub fn entryAt(self: *const Wzo2, g: usize, i: usize) Entry {
        const off = self.entry_base + (self.groups[g].entry_offset + i) * 4;
        const kb = self.bytes[off];
        const side_u1: u1 = @intCast((kb >> 1) & 1);
        const ko_bits = self.ko_bits;
        const ko_raw: u16 = @intCast((kb >> 2) & ((@as(u16, 1) << @intCast(ko_bits)) - 1));
        const passes: u2 = @intCast((kb >> @intCast(2 + ko_bits)) & 1);
        return .{
            .L = @bitCast(self.bytes[off + 1]),
            .H = @bitCast(self.bytes[off + 2]),
            .ko = if (passes >= 1) @as(u16, 0xFFFF) else ko_raw,
            .side = if (side_u1 == 0) @as(i8, 1) else @as(i8, -1),
            .passes = passes,
            .terminal = (kb & 1) != 0,
        };
    }

    pub fn groupOf(self: *const Wzo2, colex: u32) ?usize {
        var lo: usize = 0;
        var hi: usize = @intCast(self.n_groups);
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            if (self.groups[mid].colex < colex) {
                lo = mid + 1;
            } else {
                hi = mid;
            }
        }
        if (lo >= self.n_groups or self.groups[lo].colex != colex) return null;
        return lo;
    }

    /// Fresh-start (ko = none, passes = 0) L/H for a position and side.
    pub fn freshStart(self: *const Wzo2, colex: u32, side: i8, ko_none: u16) ?Entry {
        const g = self.groupOf(colex) orelse return null;
        for (0..self.groups[g].count) |i| {
            const e = self.entryAt(g, i);
            if (e.side == side and e.passes == 0 and e.ko == ko_none) return e;
        }
        return null;
    }
};

// ─── WZO1 PSK fresh-start loader ──────────────────────────────────────────

pub const PskTable = struct {
    dec: artifact.Decoded,

    pub fn load(gpa: std.mem.Allocator, path: []const u8) !PskTable {
        var threaded = std.Io.Threaded.init(gpa, .{});
        defer threaded.deinit();
        const dec = try artifact.load(threaded.io(), std.Io.Dir.cwd(), path, gpa);
        return .{ .dec = dec };
    }

    pub fn deinit(self: *PskTable) void {
        self.dec.deinit();
    }

    /// PSK fresh-start value at a colex index for a side; UNDEF if absent.
    pub fn value(self: *const PskTable, colex: u64, side: i8) i8 {
        return if (side > 0) self.dec.vb[colex] else self.dec.vw[colex];
    }
};

// ─── independent ko-cluster helper (kernel shape rule) ─────────────────────

pub const KoPoint = struct { cell: u8, cap: u8 };

pub fn isKoShape(comptime W: usize, comptime H: usize, pos: *const [W * H]i8, p: usize, colour: i8) ?u8 {
    const N = W * H;
    const R = rules_mod.Rules(W, H);
    if (pos[p] != 0) return null;
    const next = R.pos_from_move(pos, colour, p) catch return null;
    var opp_before: u8 = 0;
    var opp_after: u8 = 0;
    var captured: ?usize = null;
    for (0..N) |i| {
        if (pos[i] == -colour) opp_before += 1;
        if (next[i] == -colour) opp_after += 1;
        if (pos[i] == -colour and next[i] == 0) captured = i;
    }
    if (opp_before - opp_after != 1) return null;
    var libs: u8 = 0;
    var friends: u8 = 0;
    var nb: [4]usize = undefined;
    const cnt = R.neighbors(p, &nb);
    for (nb[0..cnt]) |q| {
        if (next[q] == 0) libs += 1;
        if (next[q] == colour) friends += 1;
    }
    if (libs != 1 or friends != 0) return null;
    return @intCast(captured.?);
}

const rules_mod = @import("rules.zig");

/// Number of independent ko-cluster shapes on a position (union-find over
/// single-capture ko shapes, 1-neighbourhood overlap).
pub fn clustersOf(comptime W: usize, comptime H: usize, pos: *const [W * H]i8) u8 {
    const N = W * H;
    var points: [2 * N]KoPoint = undefined;
    var np: usize = 0;
    for (0..N) |p| {
        inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
            if (isKoShape(W, H, pos, p, colour)) |cap| {
                if (np < 2 * N) {
                    points[np] = .{ .cell = @intCast(p), .cap = cap };
                    np += 1;
                }
            }
        }
    }
    if (np == 0) return 0;
    var masks: [2 * N]u32 = undefined;
    for (points[0..np], 0..) |kp, i| {
        var mask: u32 = 0;
        mask |= @as(u32, 1) << @as(u5, @intCast(kp.cell));
        mask |= @as(u32, 1) << @as(u5, @intCast(kp.cap));
        var nb: [4]usize = undefined;
        const R = rules_mod.Rules(W, H);
        const c1 = R.neighbors(kp.cell, &nb);
        for (nb[0..c1]) |q| mask |= @as(u32, 1) << @as(u5, @intCast(q));
        const c2 = R.neighbors(kp.cap, &nb);
        for (nb[0..c2]) |q| mask |= @as(u32, 1) << @as(u5, @intCast(q));
        masks[i] = mask;
    }
    var parent: [2 * N]u8 = undefined;
    for (0..np) |i| parent[i] = @intCast(i);
    for (0..np) |i| {
        for (i + 1..np) |j| {
            if (masks[i] & masks[j] != 0) {
                var ri: u8 = @intCast(i);
                while (parent[ri] != ri) ri = parent[ri];
                var rj: u8 = @intCast(j);
                while (parent[rj] != rj) rj = parent[rj];
                if (ri != rj) parent[ri] = rj;
            }
        }
    }
    var roots: u32 = 0;
    for (0..np) |i| {
        var r: u8 = @intCast(i);
        while (parent[r] != r) r = parent[r];
        roots |= @as(u32, 1) << @as(u5, @intCast(r));
    }
    return @intCast(@popCount(roots));
}

/// clamp(TIE=0, [L,H]) — the ADR-0020 pinned fresh-start verdict.
pub fn clampTie(comptime W: usize, comptime H: usize, L: i8, Hv: i8) i8 {
    _ = W;
    _ = H;
    return @max(L, @min(@as(i8, 0), Hv));
}
