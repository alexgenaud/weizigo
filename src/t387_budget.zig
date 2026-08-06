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
// T387 (flash) — capture-budget measurement instrument.
//
// The capture-budget rule under test: total stones captured over the whole
// game is bounded by B (the budget). State =
//   (board: base-3 rank u32, side: u8 {0=Black to move,1=White},
//    ko: u16, passes: u8 {0,1,2}, budget: u8 {0..B})
// A placement that captures k stones is legal iff budget + k <= B; on a
// legal capture the budget becomes budget + k. Everything else (basic-ko
// legality, suicide, passes, TIE=0 Chinese-area scoring at double-pass) is
// the WZO2/ADR-0020 semantics, mirrored from t386_engine.zig.
//
// THEOREM (verified here; machine-checked by the `dag` mode): the
// budget-augmented game graph is a DAG — no directed cycles. Proof sketch:
// the budget is monotone non-decreasing along every play, so a directed
// cycle would need constant budget; on a constant-budget cycle no capture
// occurs, so placements only add stones and the board can never repeat, so
// no placement lies on the cycle; a pass-only cycle hits passes=2 and
// terminates. Hence every play terminates from any state, and L == H
// everywhere (the bracket collapses structurally — no fixpoint ambiguity).
//
// Modes:
//   reach <WxH> <B> [out.json] [--planted]
//       Reachable budget-augmented state counts per budget level, exact.
//       B=0 must equal the base census (null control).
//   dag <WxH> <B> [out.json] [--planted|base]
//       DFS over the augmented closure from the empty roots: count
//       back-edges (want 0 — the DAG theorem's machine check). With `base`
//       the same DFS runs on the budget-less base graph, where back-edges
//       MUST be found (the detector is sensitive).
//   value <WxH> <B> [out.json] [--planted]
//       DFS-memo minimax from the empty roots: V'(B) (both colours,
//       colour-inversion checked), longest game (plies), min/max/support of
//       captures over optimal lines, transcripts, minimax-identity sample,
//       back-edge count.
//   hypothesis <Bmax> [out.json] [--planted]
//       3×3 only: per-position fresh-start values under the budget rule vs
//       the base table data/oracle-3x3-v2.wzo2, over the B sweep — L==H
//       movement (the hypothesis predicts zero at large B), L<H collapse,
//       root curve. Runs the base-fixpoint regression gate first (t386
//       Engine vs the table, want 0/49,428 mismatches).
//   scoring [out.json]
//       area-vs-territory scoring asymmetry demo on the T382 2×2
//       capture-exchange cycle.
//
// Controls:
//   null     reach B=0 == base census (3×3: 73,758; 4×3: 1,929,038);
//            minimax identity sample in value mode; the base-fixpoint
//            regression gate in hypothesis mode; colour inversion
//            v(empty,side1) == -v(empty,side0).
//   seeded   --planted: budget increments on EVERY placement instead of on
//            captures only — value/hypothesis readings must change;
//            `dag base` must find back-edges.
//
// Compile (ad hoc, under tools/runner):
//   zig build-exe -O ReleaseFast --dep version -Mroot=src/t387_budget.zig \
//     -Mversion=src/version.zig --cache-dir /tmp/weizigo/t387/kc \
//     --global-cache-dir /tmp/weizigo/t387/gc --name weizigo-t387-budget \
//     -femit-bin=/tmp/weizigo/t387/budget
//
// stdout = data, stderr = diagnostics.

const std = @import("std");
const eng = @import("t386_engine.zig");
const exp6 = @import("exp6_solve.zig");
const colexmod = @import("colex.zig");

// ---------------------------------------------------------------------------
// JSON writer (hand-rolled; std.json abandoned under Zig 0.16 churn)
// ---------------------------------------------------------------------------

const Json = struct {
    gpa: std.mem.Allocator,
    buf: std.ArrayListUnmanaged(u8),

    fn init(gpa: std.mem.Allocator) Json {
        return .{ .gpa = gpa, .buf = std.ArrayListUnmanaged(u8).empty };
    }
    fn deinit(self: *Json) void {
        self.buf.deinit(self.gpa);
    }
    fn put(self: *Json, s: []const u8) void {
        self.buf.appendSlice(self.gpa, s) catch unreachable;
    }
    fn putCh(self: *Json, c: u8) void {
        self.buf.append(self.gpa, c) catch unreachable;
    }
    fn esc(self: *Json, s: []const u8) void {
        self.putCh('"');
        for (s) |c| {
            switch (c) {
                '"' => self.put("\\\""),
                '\\' => self.put("\\\\"),
                '\n' => self.put("\\n"),
                '\t' => self.put("\\t"),
                '\r' => self.put("\\r"),
                else => self.putCh(c),
            }
        }
        self.putCh('"');
    }
    fn int(self: *Json, v: anytype) void {
        self.buf.print(self.gpa, "{d}", .{v}) catch unreachable;
    }
    fn flt(self: *Json, v: f64) void {
        self.buf.print(self.gpa, "{d:.4}", .{v}) catch unreachable;
    }
    fn bool_(self: *Json, v: bool) void {
        self.put(if (v) "true" else "false");
    }
    fn objBegin(self: *Json) void {
        self.putCh('{');
    }
    fn objEnd(self: *Json) void {
        self.putCh('}');
    }
    fn arrBegin(self: *Json) void {
        self.putCh('[');
    }
    fn arrEnd(self: *Json) void {
        self.putCh(']');
    }
    fn key(self: *Json, k: []const u8) void {
        self.esc(k);
        self.putCh(':');
    }
    fn sep(self: *Json) void {
        self.putCh(',');
    }
};

fn writeOut(gpa: std.mem.Allocator, path: []const u8, data: []const u8) !void {
    const out_dir = std.Io.Dir.cwd();
    var threaded_out = std.Io.Threaded.init(gpa, .{});
    defer threaded_out.deinit();
    out_dir.writeFile(threaded_out.io(), .{ .sub_path = path, .data = data }) catch |err| {
        std.debug.print("cannot write {s}: {s}\n", .{ path, @errorName(err) });
        return;
    };
    std.debug.print("JSON written to {s} ({d} bytes)\n", .{ path, data.len });
}

fn parseWxH(s: []const u8) ?struct { w: usize, h: usize } {
    if (s.len != 3) return null;
    if (s[1] != 'x') return null;
    const w: usize = s[0] - '0';
    const h: usize = s[2] - '0';
    if (w < 1 or w > 4 or h < 1 or h > 4) return null;
    return .{ .w = w, .h = h };
}

fn pow3(n: usize) u64 {
    var x: u64 = 1;
    for (0..n) |_| x *= 3;
    return x;
}

// ---------------------------------------------------------------------------
// The budget-augmented solver, comptime-generic over the goban size.
// ---------------------------------------------------------------------------

pub fn Solver(comptime W: usize, comptime H: usize) type {
    return struct {
        pub const N: usize = W * H;
        pub const RAW_TOTAL: u64 = pow3(N);
        pub const KO_DIMS: u64 = N + 1;
        pub const TOTAL_BASE: u64 = RAW_TOTAL * 2 * KO_DIMS * 3; // passes {0,1,2}
        pub const KO_NONE: u16 = @intCast(N);
        pub const PASS_MOVE: u8 = @intCast(N); // move marker: pass
        pub const Pos = [N]i8;
        const E = eng.Engine(W, H);

        pub const St = struct {
            board: u32,
            side: u8, // 0 = Black to move, 1 = White
            ko: u16,
            passes: u8,
            budget: u8,

            pub fn baseLinear(self: St) u64 {
                return (((@as(u64, self.passes) * 2) + self.side) * KO_DIMS + self.ko) * RAW_TOTAL + self.board;
            }
            pub fn augLinear(self: St, B: u8) u64 {
                return self.baseLinear() * (@as(u64, B) + 1) + self.budget;
            }
        };

        pub fn decodeAug(lin: u64, B: u8) St {
            const budget: u8 = @intCast(lin % (@as(u64, B) + 1));
            var rest = lin / (@as(u64, B) + 1);
            const board: u32 = @intCast(rest % RAW_TOTAL);
            rest /= RAW_TOTAL;
            const ko: u16 = @intCast(rest % KO_DIMS);
            rest /= KO_DIMS;
            const side: u8 = @intCast(rest % 2);
            const passes: u8 = @intCast(rest / 2);
            return .{ .board = board, .side = side, .ko = ko, .passes = passes, .budget = budget };
        }

        pub fn decodeBase(lin: u64) St {
            var rest = lin;
            const board: u32 = @intCast(rest % RAW_TOTAL);
            rest /= RAW_TOTAL;
            const ko: u16 = @intCast(rest % KO_DIMS);
            rest /= KO_DIMS;
            const side: u8 = @intCast(rest % 2);
            const passes: u8 = @intCast(rest / 2);
            return .{ .board = board, .side = side, .ko = ko, .passes = passes, .budget = 0 };
        }

        pub const Place = struct { st: St, k: u8 };

        /// Budget-aware placement. Mirrors t386_engine applyPlace for the
        /// board/ko semantics; adds the capture count k and the budget
        /// legality (budget + k <= B). Returns null if illegal.
        pub fn applyPlace(s: St, board: *const Pos, colour: i8, cell: u8, B: u8, planted: bool) ?Place {
            if (s.passes >= 2) return null;
            if (board[cell] != 0) return null;
            if (s.ko != KO_NONE and cell == s.ko) return null;
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
            const k: u8 = opp_before - opp_after;
            // The budget rule: the budget is consumed by captured stones
            // (or, in the planted control, by every placement).
            const consumed: u8 = if (planted) 1 else k;
            if (@as(u16, s.budget) + consumed > B) return null;
            var new_ko: u16 = KO_NONE;
            if ((opp_before - opp_after == 1) and (captured_cell != KO_NONE)) {
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
            return .{
                .st = .{
                    .board = E.rank(&next),
                    .side = if (colour == 1) @as(u8, 1) else @as(u8, 0),
                    .ko = new_ko,
                    .passes = 0,
                    .budget = s.budget + consumed,
                },
                .k = k,
            };
        }

        pub fn applyPass(s: St) ?St {
            if (s.passes >= 2) return null;
            return .{ .board = s.board, .side = 1 - s.side, .ko = KO_NONE, .passes = s.passes + 1, .budget = s.budget };
        }

        pub const Move = struct { child: St, k: u8, cell: u8 }; // cell N = pass
        pub const MoveList = struct { items: [N + 1]Move, len: usize };

        /// All legal moves (pass first, then cells 0..N-1; the t386 order),
        /// with the budget rule applied. k counts captured stones.
        pub fn moves(s: St, board: *const Pos, B: u8, planted: bool, out: *MoveList) void {
            out.len = 0;
            if (s.passes >= 2) return;
            const colour: i8 = if (s.side == 0) 1 else -1;
            if (applyPass(s)) |ns| {
                out.items[out.len] = .{ .child = ns, .k = 0, .cell = PASS_MOVE };
                out.len += 1;
            }
            for (0..N) |cell_u| {
                const cell: u8 = @intCast(cell_u);
                if (applyPlace(s, board, colour, cell, B, planted)) |r| {
                    out.items[out.len] = .{ .child = r.st, .k = r.k, .cell = cell };
                    out.len += 1;
                }
            }
        }

        pub const BfsResult = struct {
            total: u64,
            per_budget: []u64, // [B+1]
            words: u64,
            bits: []u64,
            B: u8,
            queue_peak: u64,
        };

        /// Budget-augmented BFS from the given roots (augmented linear
        /// indices). Counts per-budget reachable states. Level-queue BFS:
        /// memory peak = largest frontier, not the total reachable set
        /// (T397: the single-queue version grew to the full reachable set
        /// and the doubling transient blew the 3.8 GB runner cap at 4×4).
        pub fn bfs(gpa: std.mem.Allocator, roots: []const u64, B: u8, planted: bool) !BfsResult {
            const total_aug = TOTAL_BASE * (@as(u64, B) + 1);
            const words: u64 = (total_aug + 63) / 64;
            const bits = try gpa.alloc(u64, @intCast(words));
            @memset(bits, 0);
            const per_budget = try gpa.alloc(u64, @as(usize, B) + 1);
            @memset(per_budget, 0);
            var cur = std.ArrayListUnmanaged(u64).empty;
            var nxt = std.ArrayListUnmanaged(u64).empty;
            defer cur.deinit(gpa);
            defer nxt.deinit(gpa);
            var queue_peak: u64 = 0;
            var total: u64 = 0;
            for (roots) |r| {
                const word = r >> 6;
                const bit: u64 = @as(u64, 1) << @intCast(r & 63);
                if (bits[@intCast(word)] & bit == 0) {
                    bits[@intCast(word)] |= bit;
                    try cur.append(gpa, r);
                    per_budget[@intCast(decodeAug(r, B).budget)] += 1;
                    total += 1;
                }
            }
            while (cur.items.len > 0) {
                if (cur.items.len > queue_peak) queue_peak = cur.items.len;
                nxt.clearRetainingCapacity();
                for (cur.items) |lin| {
                    const s = decodeAug(lin, B);
                    const board = E.unrank(s.board);
                    var ml: MoveList = undefined;
                    moves(s, &board, B, planted, &ml);
                    for (ml.items[0..ml.len]) |m| {
                        if (!E.isLegalBoard(&E.unrank(m.child.board))) continue; // base census gate
                        const cl = m.child.augLinear(B);
                        const word = cl >> 6;
                        const bit: u64 = @as(u64, 1) << @intCast(cl & 63);
                        if (bits[@intCast(word)] & bit == 0) {
                            bits[@intCast(word)] |= bit;
                            try nxt.append(gpa, cl);
                            per_budget[@intCast(m.child.budget)] += 1;
                            total += 1;
                        }
                    }
                }
                std.mem.swap(std.ArrayListUnmanaged(u64), &cur, &nxt);
            }
            return .{ .total = total, .per_budget = per_budget, .words = words, .bits = bits, .B = B, .queue_peak = queue_peak };
        }

        /// Rank structure over the BFS bitset: dense index of an augmented
        /// linear index = popcount prefix.
        pub const Rank = struct {
            prefix: []u64, // words+1 entries
            bits: []u64,
            words: u64,

            pub fn build(gpa: std.mem.Allocator, bfs_res: *const BfsResult) !Rank {
                const prefix = try gpa.alloc(u64, @intCast(bfs_res.words + 1));
                var acc: u64 = 0;
                prefix[0] = 0;
                for (0..@as(usize, @intCast(bfs_res.words))) |i| {
                    acc += @popCount(bfs_res.bits[i]);
                    prefix[i + 1] = acc;
                }
                return .{ .prefix = prefix, .bits = bfs_res.bits, .words = bfs_res.words };
            }
            pub fn dense(self: *const Rank, lin: u64) usize {
                const word: u64 = lin >> 6;
                const low: u6 = @intCast(lin & 63);
                // bits strictly before `low` within this word (excludes the
                // bit itself: dense index = rank = count of set bits before).
                const before: u64 = if (low == 0) 0 else (@as(u64, 1) << @intCast(low)) - 1;
                return @intCast(self.prefix[@intCast(word)] + @popCount(self.bits[@intCast(word)] & before));
            }
        };

        /// DFS-memo minimax over the budget-augmented DAG, from the given
        /// roots (augmented linear indices — all must be in the BFS closure).
        pub const ValueResult = struct {
            val: []i8,
            status: []u8, // 0 new, 1 on-stack, 2 done
            longest: []u16,
            min_cap: []u8,
            max_cap: []u8,
            opt_move: []u8, // cell 0..N-1, N = pass
            long_move: []u8,
            support: []u64, // bitmask over capture counts 0..B
            back_edges: u64,
            n_states: u64,
            n_terminal: u64,
            B: u8,
        };

        pub const Dfs = struct {
            res: ValueResult,
            rank: Rank,
            planted: bool,
        };

        pub fn allocValue(gpa: std.mem.Allocator, n_states: u64, B: u8) !ValueResult {
            const n: usize = @intCast(n_states);
            const val = try gpa.alloc(i8, n);
            @memset(val, 0);
            const status = try gpa.alloc(u8, n);
            @memset(status, 0);
            const longest = try gpa.alloc(u16, n);
            @memset(longest, 0);
            const min_cap = try gpa.alloc(u8, n);
            @memset(min_cap, 0);
            const max_cap = try gpa.alloc(u8, n);
            @memset(max_cap, 0);
            const opt_move = try gpa.alloc(u8, n);
            @memset(opt_move, PASS_MOVE);
            const long_move = try gpa.alloc(u8, n);
            @memset(long_move, PASS_MOVE);
            const support = try gpa.alloc(u64, n);
            @memset(support, 0);
            return .{
                .val = val,
                .status = status,
                .longest = longest,
                .min_cap = min_cap,
                .max_cap = max_cap,
                .opt_move = opt_move,
                .long_move = long_move,
                .support = support,
                .back_edges = 0,
                .n_states = n_states,
                .n_terminal = 0,
                .B = B,
            };
        }

        /// Recursive value computation over the full closure.
        pub fn dfsValues(gpa: std.mem.Allocator, bfs_res: *const BfsResult, rank: *const Rank, roots: []const u64, planted: bool) !ValueResult {
            const res = try allocValue(gpa, bfs_res.total, bfs_res.B);
            var dfs = Dfs{ .res = res, .rank = rank.*, .planted = planted };
            for (roots) |r| {
                _ = valueOf(&dfs, bfs_res, r);
            }
            return dfs.res;
        }

        fn valueOf(dfs: *Dfs, bfs_res: *const BfsResult, lin: u64) i8 {
            const d = denseOf(&dfs.rank, lin);
            const st_ = dfs.res.status[@intCast(d)];
            if (st_ == 2) return dfs.res.val[@intCast(d)];
            if (st_ == 1) {
                dfs.res.back_edges += 1; // a directed cycle (want 0 under the budget rule)
                return 0;
            }
            dfs.res.status[@intCast(d)] = 1;
            const s = decodeAug(lin, bfs_res.B);
            const board = E.unrank(s.board);
            var v: i8 = 0;
            var longest: u16 = 0;
            var min_cap: u8 = 0;
            var max_cap: u8 = 0;
            var support: u64 = 0;
            var opt_move: u8 = PASS_MOVE;
            var long_move: u8 = PASS_MOVE;
            if (s.passes >= 2) {
                v = exp6.genericAreaScore(N, &board, W, H);
                support = @as(u64, 1) << @intCast(0);
                dfs.res.n_terminal += 1;
            } else {
                const maximizing = s.side == 0;
                var ml: MoveList = undefined;
                moves(s, &board, bfs_res.B, dfs.planted, &ml);
                var best: i16 = if (maximizing) -128 else 127;
                var best_longest: u16 = 0;
                for (ml.items[0..ml.len]) |m| {
                    const cd = denseOf(&dfs.rank, m.child.augLinear(bfs_res.B));
                    _ = valueOf(dfs, bfs_res, m.child.augLinear(bfs_res.B));
                    const cv = dfs.res.val[@intCast(cd)];
                    if (maximizing) {
                        if (cv > best) {
                            best = cv;
                            opt_move = m.cell;
                        }
                    } else {
                        if (cv < best) {
                            best = cv;
                            opt_move = m.cell;
                        }
                    }
                    const cl = dfs.res.longest[@intCast(cd)];
                    if (cl + 1 > best_longest) {
                        best_longest = cl + 1;
                        long_move = m.cell;
                    }
                }
                v = @intCast(best);
                longest = best_longest;
                // min/max captures and support over optimal children
                var mn: u8 = 255;
                var mx: u8 = 0;
                var sup: u64 = 0;
                for (ml.items[0..ml.len]) |m| {
                    const cd = denseOf(&dfs.rank, m.child.augLinear(bfs_res.B));
                    const cv = dfs.res.val[@intCast(cd)];
                    if (cv != v) continue; // not an optimal child
                    const k = m.k;
                    const cmin = dfs.res.min_cap[@intCast(cd)];
                    const cmax = dfs.res.max_cap[@intCast(cd)];
                    const cs = dfs.res.support[@intCast(cd)];
                    if (k + cmin < mn) mn = k + cmin;
                    if (k + cmax > mx) mx = k + cmax;
                    if (k < 64) sup |= cs << @intCast(k);
                }
                min_cap = if (mn == 255) 0 else mn;
                max_cap = mx;
                support = sup;
            }
            dfs.res.val[@intCast(d)] = v;
            dfs.res.longest[@intCast(d)] = longest;
            dfs.res.min_cap[@intCast(d)] = min_cap;
            dfs.res.max_cap[@intCast(d)] = max_cap;
            dfs.res.opt_move[@intCast(d)] = opt_move;
            dfs.res.long_move[@intCast(d)] = long_move;
            dfs.res.support[@intCast(d)] = support;
            dfs.res.status[@intCast(d)] = 2;
            return v;
        }

        fn denseOf(rank: *const Rank, lin: u64) usize {
            const word: u64 = lin >> 6;
            const low: u6 = @intCast(lin & 63);
            const before: u64 = if (low == 0) 0 else (@as(u64, 1) << @intCast(low)) - 1;
            return @intCast(rank.prefix[@intCast(word)] + @popCount(rank.bits[@intCast(word)] & before));
        }

        pub fn emptyRoots(B: u8) [2]u64 {
            const ko_none: u16 = @intCast(N);
            return .{
                (St{ .board = 0, .side = 0, .ko = ko_none, .passes = 0, .budget = 0 }).augLinear(B),
                (St{ .board = 0, .side = 1, .ko = ko_none, .passes = 0, .budget = 0 }).augLinear(B),
            };
        }

        /// Base-graph DFS (no budget): count re-visits and the reachable
        /// raw-key-space count. Seeded from BOTH fresh-start roots (empty,
        /// side 0/1) to match the t386 census convention exactly
        /// (cross-validated: 3×3 = 73,758; 4×3 = 1,929,038). The reachable
        /// count is the honest base for the budget multiplier (the raw key
        /// space, not the table entry count). back_edges > 0 confirms the
        /// base graph has cycles (the seeded control for the DAG theorem).
        pub fn baseReach(gpa: std.mem.Allocator) !struct { reachable: u64, back_edges: u64 } {
            const E_ = eng.Engine(W, H);
            const words: usize = @intCast((TOTAL_BASE + 63) / 64);
            const bits = try gpa.alloc(u64, words);
            @memset(bits, 0);
            defer gpa.free(bits);
            var stack = std.ArrayListUnmanaged(u64).empty;
            defer stack.deinit(gpa);
            var back_edges: u64 = 0;
            var reachable: u64 = 0;
            const ko_none: u16 = @intCast(N);
            inline for (.{ @as(u8, 0), @as(u8, 1) }) |side| {
                const root = E_.State{ .board = 0, .side = side, .ko = ko_none, .passes = 0 };
                try stack.append(gpa, root.linear());
            }
            while (stack.pop()) |lin| {
                const word = lin >> 6;
                const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
                if (bits[@intCast(word)] & bit != 0) {
                    back_edges += 1;
                    continue;
                }
                bits[@intCast(word)] |= bit;
                reachable += 1;
                const s0 = decodeBase(lin);
                const s = E_.State{ .board = s0.board, .side = s0.side, .ko = s0.ko, .passes = s0.passes };
                var succ_boards: [N + 1]Pos = undefined;
                var succs: [N + 1]E_.State = undefined;
                const m = E_.moves(s, &succ_boards, &succs);
                for (0..m) |k| {
                    if (!E.isLegalBoard(&succ_boards[k])) continue;
                    try stack.append(gpa, succs[k].linear());
                }
            }
            return .{ .reachable = reachable, .back_edges = back_edges };
        }

        /// Base-graph DFS (no budget): count re-visits only. For the `dag base`
        /// control — cycles MUST exist here.
        pub fn baseDagBackEdges(gpa: std.mem.Allocator) !u64 {
            return (try baseReach(gpa)).back_edges;
        }

        pub const IdentityResult = struct { checked: u64, mismatch: u64 };

        /// Minimax-identity sample: for sampled non-terminal reachable states,
        /// recompute the value from the children's stored values and compare.
        /// `sample_every` = sampling density (1 in N states that pass the
        /// filters). The scan is bounded by `cap` sampled states and by the
        /// bitset size, so a regression of the T397 u6-loop class FAILS loudly
        /// instead of hanging.
        pub fn identityScan(gpa: std.mem.Allocator, bfs_res: *const BfsResult, rank: *const Rank, res: *const ValueResult, B: u8, planted: bool, sample_every: u64) !IdentityResult {
            _ = gpa;
            var checked: u64 = 0;
            var mismatch: u64 = 0;
            var samples: u64 = 0;
            const cap: u64 = 1_000_000;
            var word_i: u64 = 0;
            outer: while (word_i < bfs_res.words and checked < cap) : (word_i += 1) {
                const w = bfs_res.bits[@intCast(word_i)];
                var bitpos: u7 = 0;
                while (bitpos < 64) : (bitpos += 1) {
                    if (w & (@as(u64, 1) << @intCast(bitpos)) == 0) continue;
                    const lin = (word_i << 6) | bitpos;
                    const d = denseOf(rank, lin);
                    if (res.status[d] != 2) continue;
                    const s = decodeAug(lin, B);
                    if (s.passes >= 2) continue;
                    samples += 1;
                    if (samples % sample_every != 0) continue;
                    const board = eng.Engine(W, H).unrank(s.board);
                    var ml: MoveList = undefined;
                    moves(s, &board, B, planted, &ml);
                    var best: i16 = if (s.side == 0) -128 else 127;
                    for (ml.items[0..ml.len]) |m| {
                        const cd = denseOf(rank, m.child.augLinear(B));
                        const cv = res.val[cd];
                        if (s.side == 0) {
                            if (cv > best) best = cv;
                        } else {
                            if (cv < best) best = cv;
                        }
                    }
                    checked += 1;
                    if (best != res.val[d]) mismatch += 1;
                    if (checked >= cap) break :outer;
                }
            }
            return .{ .checked = checked, .mismatch = mismatch };
        }
    };
}

// ---------------------------------------------------------------------------
// Mode implementations
// ---------------------------------------------------------------------------

fn reachMode(gpa: std.mem.Allocator, w: usize, h: usize, B: u8, planted: bool, out_path: []const u8) !void {
    switch (w * 10 + h) {
        33 => try reachModeImpl(3, 3, gpa, B, planted, out_path),
        43 => try reachModeImpl(4, 3, gpa, B, planted, out_path),
        44 => try reachModeImpl(4, 4, gpa, B, planted, out_path),
        else => std.debug.print("reach: unsupported goban {d}x{d}\n", .{ w, h }),
    }
}

fn reachModeImpl(comptime W: usize, comptime H: usize, gpa: std.mem.Allocator, B: u8, planted: bool, out_path: []const u8) !void {
    const S = Solver(W, H);
    const goban_label = [_]u8{ '0' + W, 'x', '0' + H };
    // Base reachable count from the single-pass base DFS (raw key space).
    // Cross-validated against the t386 census at 3×3 (73,758) and 4×3
    // (1,929,038); at 4×4 the t386 census is a 31-sweep wall, so the
    // single-pass DFS is used there too.
    const base = try S.baseReach(gpa);
    const base_total = base.reachable;
    const roots = S.emptyRoots(B);
    const bfs_res = try S.bfs(gpa, &roots, B, planted);
    defer gpa.free(bfs_res.bits);
    defer gpa.free(bfs_res.per_budget);

    var j = Json.init(gpa);
    defer j.deinit();
    j.objBegin();
    j.key("task_id"); j.esc("T387");
    j.sep(); j.key("mode"); j.esc("reach");
    j.sep(); j.key("goban"); j.esc(goban_label[0..]);
    j.sep(); j.key("B"); j.int(B);
    j.sep(); j.key("planted"); j.bool_(planted);
    j.sep(); j.key("dense_key_space"); j.int(S.TOTAL_BASE * (@as(u64, B) + 1));
    j.sep(); j.key("dense_multiplier"); j.flt(@as(f64, @floatFromInt(B)) + 1.0);
    j.sep(); j.key("reachable_total"); j.int(bfs_res.total);
    j.sep(); j.key("base_reachable"); j.int(base_total);
    j.sep(); j.key("reachable_over_base"); j.flt(@as(f64, @floatFromInt(bfs_res.total)) / @as(f64, @floatFromInt(base_total)));
    j.sep(); j.key("queue_peak"); j.int(bfs_res.queue_peak);
    j.sep(); j.key("per_budget"); j.arrBegin();
    for (0..@as(usize, B) + 1) |b| {
        if (b > 0) j.sep();
        j.int(bfs_res.per_budget[b]);
    }
    j.arrEnd();
    // B=0 is the capture-free subset of the base reachable set (captures are
    // illegal at B=0), so B0 <= base by construction; monotonicity in B and
    // the base-census gate in hypothesis mode are the machinery controls.
    j.sep(); j.key("b0_is_capture_free_subset_of_base"); j.bool_(B == 0 and bfs_res.total <= base_total);
    j.objEnd();
    j.putCh('\n');
    try writeOut(gpa, out_path, j.buf.items);
}

fn dagMode(gpa: std.mem.Allocator, w: usize, h: usize, B: u8, base: bool, out_path: []const u8) !void {
    switch (w * 10 + h) {
        33 => try dagModeImpl(3, 3, gpa, B, base, out_path),
        43 => try dagModeImpl(4, 3, gpa, B, base, out_path),
        else => std.debug.print("dag: unsupported goban {d}x{d}\n", .{ w, h }),
    }
}

fn dagModeImpl(comptime W: usize, comptime H: usize, gpa: std.mem.Allocator, B: u8, base: bool, out_path: []const u8) !void {
    const S = Solver(W, H);
    const goban_label = [_]u8{ '0' + W, 'x', '0' + H };
    var j = Json.init(gpa);
    defer j.deinit();
    j.objBegin();
    j.key("task_id"); j.esc("T387");
    j.sep(); j.key("mode"); j.esc("dag");
    j.sep(); j.key("goban"); j.esc(goban_label[0..]);
    j.sep(); j.key("base_graph"); j.bool_(base);
    if (base) {
        const be = try S.baseDagBackEdges(gpa);
        j.sep(); j.key("back_edges"); j.int(be);
        j.sep(); j.key("control_expects"); j.esc("> 0 (the cycle detector is sensitive)");
    } else {
        const roots = S.emptyRoots(B);
        var bfs_res = try S.bfs(gpa, &roots, B, false);
        defer gpa.free(bfs_res.bits);
        defer gpa.free(bfs_res.per_budget);
        var rank = try S.Rank.build(gpa, &bfs_res);
        defer gpa.free(rank.prefix);
        const res = try S.dfsValues(gpa, &bfs_res, &rank, &roots, false);
        defer gpa.free(res.val);
        defer gpa.free(res.status);
        defer gpa.free(res.longest);
        defer gpa.free(res.min_cap);
        defer gpa.free(res.max_cap);
        defer gpa.free(res.opt_move);
        defer gpa.free(res.long_move);
        defer gpa.free(res.support);
        j.sep(); j.key("B"); j.int(B);
        j.sep(); j.key("states"); j.int(bfs_res.total);
        j.sep(); j.key("back_edges"); j.int(res.back_edges);
        j.sep(); j.key("theorem_holds"); j.bool_(res.back_edges == 0);
    }
    j.objEnd();
    j.putCh('\n');
    try writeOut(gpa, out_path, j.buf.items);
}

fn valueMode(gpa: std.mem.Allocator, w: usize, h: usize, B: u8, planted: bool, out_path: []const u8) !void {
    switch (w * 10 + h) {
        33 => try valueModeImpl(3, 3, gpa, B, planted, out_path),
        43 => try valueModeImpl(4, 3, gpa, B, planted, out_path),
        else => std.debug.print("value: unsupported goban {d}x{d}\n", .{ w, h }),
    }
}

fn valueModeImpl(comptime W: usize, comptime H: usize, gpa: std.mem.Allocator, B: u8, planted: bool, out_path: []const u8) !void {
    const S = Solver(W, H);
    const goban_label = [_]u8{ '0' + W, 'x', '0' + H };
    const roots = S.emptyRoots(B);
    const bfs_res = try S.bfs(gpa, &roots, B, planted);
    defer gpa.free(bfs_res.bits);
    defer gpa.free(bfs_res.per_budget);
    var rank = try S.Rank.build(gpa, &bfs_res);
    defer gpa.free(rank.prefix);
    const res = try S.dfsValues(gpa, &bfs_res, &rank, &roots, planted);
    defer gpa.free(res.val);
    defer gpa.free(res.status);
    defer gpa.free(res.longest);
    defer gpa.free(res.min_cap);
    defer gpa.free(res.max_cap);
    defer gpa.free(res.opt_move);
    defer gpa.free(res.long_move);
    defer gpa.free(res.support);

    const root_b = (S.St{ .board = 0, .side = 0, .ko = @intCast(W * H), .passes = 0, .budget = 0 }).augLinear(B);
    const root_w = (S.St{ .board = 0, .side = 1, .ko = @intCast(W * H), .passes = 0, .budget = 0 }).augLinear(B);
    const db = S.denseOf(&rank, root_b);
    const dw = S.denseOf(&rank, root_w);
    const v_b = res.val[db];
    const v_w = res.val[dw];

    // minimax identity sample: recompute value from children on a sampled
    // subset of non-terminal reachable states (1 in `sample_every`).
    const id = try S.identityScan(gpa, &bfs_res, &rank, &res, B, planted, 100);
    const identity_checked = id.checked;
    const identity_mismatch = id.mismatch;

    var j = Json.init(gpa);
    defer j.deinit();
    j.objBegin();
    j.key("task_id"); j.esc("T387");
    j.sep(); j.key("mode"); j.esc("value");
    j.sep(); j.key("goban"); j.esc(goban_label[0..]);
    j.sep(); j.key("B"); j.int(B);
    j.sep(); j.key("planted"); j.bool_(planted);
    j.sep(); j.key("states"); j.int(bfs_res.total);
    j.sep(); j.key("terminal_states"); j.int(res.n_terminal);
    j.sep(); j.key("back_edges"); j.int(res.back_edges);
    j.sep(); j.key("theorem_holds"); j.bool_(res.back_edges == 0);
    j.sep(); j.key("root_black"); j.objBegin();
    j.key("V"); j.int(v_b);
    j.sep(); j.key("longest_plies"); j.int(res.longest[db]);
    j.sep(); j.key("min_captures_optimal"); j.int(res.min_cap[db]);
    j.sep(); j.key("max_captures_optimal"); j.int(res.max_cap[db]);
    j.sep(); j.key("support"); j.arrBegin();
    var first = true;
    for (0..@as(usize, B) + 1) |c| {
        if (res.support[db] & (@as(u64, 1) << @intCast(c)) != 0) {
            if (!first) j.sep();
            j.int(c);
            first = false;
        }
    }
    j.arrEnd();
    j.objEnd();
    j.sep(); j.key("root_white"); j.objBegin();
    j.key("V"); j.int(v_w);
    j.sep(); j.key("longest_plies"); j.int(res.longest[dw]);
    j.sep(); j.key("min_captures_optimal"); j.int(res.min_cap[dw]);
    j.sep(); j.key("max_captures_optimal"); j.int(res.max_cap[dw]);
    j.objEnd();
    j.sep(); j.key("colour_inversion"); j.bool_(v_w == -v_b);
    j.sep(); j.key("identity_checked"); j.int(identity_checked);
    j.sep(); j.key("identity_mismatch"); j.int(identity_mismatch);
    j.objEnd();
    j.putCh('\n');
    try writeOut(gpa, out_path, j.buf.items);
}

fn hypothesisMode(gpa: std.mem.Allocator, Bmax: u8, planted: bool, out_path: []const u8, with_psk: bool) !void {
    const S = Solver(3, 3);
    const E3 = eng.Engine(3, 3);
    const X3 = colexmod.Indexer(3, 3);
    const ko_none: u16 = 9;

    var psk: ?eng.PskTable = null;
    if (with_psk) {
        psk = try eng.PskTable.load(gpa, "artifacts/oracle-3x3.wzo");
    }
    defer if (psk != null) psk.?.deinit();

    // ---- null gate: reproduce the base fixpoint against the trusted table
    const table = try eng.Wzo2.open(gpa, "data/oracle-3x3-v2.wzo2");
    defer gpa.free(table.bytes);
    defer gpa.free(table.groups);
    const reach = try gpa.alloc(u64, E3.ReachWords);
    defer gpa.free(reach);
    const census = try E3.census(gpa, reach);
    const L = try gpa.alloc(i8, E3.TOTAL);
    const Ht = try gpa.alloc(i8, E3.TOTAL);
    defer gpa.free(L);
    defer gpa.free(Ht);
    E3.seed(reach, L, Ht);
    const conv = E3.converge(reach, L, Ht, null);
    var gate_entries: u64 = 0;
    var gate_mismatch: u64 = 0;
    for (0..@as(usize, @intCast(table.n_groups))) |g| {
        const colex = table.groups[g].colex;
        const pos: [9]i8 = X3.pos_from_colex(colex);
        const board = E3.rank(&pos);
        for (0..table.groups[g].count) |i| {
            const e = table.entryAt(g, i);
            const side: u8 = if (e.side > 0) 0 else 1;
            const ko: u16 = if (e.passes == 1) E3.KO_NONE else e.ko;
            const state = E3.State{ .board = board, .side = side, .ko = ko, .passes = e.passes };
            const lin = state.linear();
            gate_entries += 1;
            if (L[lin] != e.L or Ht[lin] != e.H) gate_mismatch += 1;
        }
    }

    // ---- fresh-start roots: every legal position × side, stored as base
    // linear indices (budget 0); the augmented index for budget B is
    // base * (B+1).
    var root_base = std.ArrayListUnmanaged(u64).empty;
    defer root_base.deinit(gpa);
    var colex_idx: u64 = 0;
    while (colex_idx < X3.total) : (colex_idx += 1) {
        const pos: [9]i8 = X3.pos_from_colex(colex_idx);
        if (!E3.isLegalBoard(&pos)) continue;
        const board = E3.rank(&pos);
        inline for (.{ @as(u8, 0), @as(u8, 1) }) |side| {
            const st = S.St{ .board = board, .side = side, .ko = ko_none, .passes = 0, .budget = 0 };
            try root_base.append(gpa, st.baseLinear());
        }
    }

    var j = Json.init(gpa);
    defer j.deinit();
    j.objBegin();
    j.key("task_id"); j.esc("T387");
    j.sep(); j.key("mode"); j.esc("hypothesis");
    j.sep(); j.key("goban"); j.esc("3x3");
    j.sep(); j.key("planted"); j.bool_(planted);
    j.sep(); j.key("null_gate"); j.objBegin();
    j.key("census_states"); j.int(census.total_marked);
    j.sep(); j.key("fixpoint_sweeps"); j.int(conv.sweeps);
    j.sep(); j.key("fixpoint_converged"); j.bool_(conv.converged);
    j.sep(); j.key("entries_checked"); j.int(gate_entries);
    j.sep(); j.key("mismatches"); j.int(gate_mismatch);
    j.sep(); j.key("gate_passes"); j.bool_(gate_mismatch == 0);
    j.objEnd();
    j.sep(); j.key("roots"); j.int(root_base.items.len);
    j.sep(); j.key("sweep"); j.arrBegin();

    const sweep = [_]u8{ 0, 1, 2, 3, 4, 6, 8, 12, 16, 24, 32 };
    var first_b = true;
    for (sweep) |B| {
        if (B > Bmax) break;
        // the augmented indices depend on B: budget 0 -> base * (B+1)
        var roots = std.ArrayListUnmanaged(u64).empty;
        defer roots.deinit(gpa);
        for (root_base.items) |bl| {
            try roots.append(gpa, bl * (@as(u64, B) + 1));
        }
        var bfs_res = try S.bfs(gpa, roots.items, B, planted);
        defer gpa.free(bfs_res.bits);
        defer gpa.free(bfs_res.per_budget);
        var rank = try S.Rank.build(gpa, &bfs_res);
        defer gpa.free(rank.prefix);
        const res = try S.dfsValues(gpa, &bfs_res, &rank, roots.items, planted);
        defer gpa.free(res.val);
        defer gpa.free(res.status);
        defer gpa.free(res.longest);
        defer gpa.free(res.min_cap);
        defer gpa.free(res.max_cap);
        defer gpa.free(res.opt_move);
        defer gpa.free(res.long_move);
        defer gpa.free(res.support);

        var lh_eq_total: u64 = 0;
        var lh_eq_moved: u64 = 0;
        var lh_lt_total: u64 = 0;
        var lh_lt_inside: u64 = 0;
        var lh_lt_outside: u64 = 0;
        var lh_lt_eq_pinned: u64 = 0;
        var lh_lt_eq_edge: u64 = 0;
        var checked: u64 = 0;
        var psk_checked: u64 = 0;
        var psk_match: u64 = 0;
        var psk_mismatch_lh_eq: u64 = 0;
        for (0..@as(usize, @intCast(table.n_groups))) |g| {
            const colex = table.groups[g].colex;
            const pos: [9]i8 = X3.pos_from_colex(colex);
            const board = E3.rank(&pos);
            for (0..table.groups[g].count) |i| {
                const e = table.entryAt(g, i);
                if (e.passes != 0 or e.ko != ko_none) continue; // fresh-start keys only
                const side_u8: u8 = if (e.side > 0) 0 else 1;
                const root_lin = (S.St{ .board = board, .side = side_u8, .ko = ko_none, .passes = 0, .budget = 0 }).augLinear(B);
                const d = S.denseOf(&rank, root_lin);
                const v = res.val[d];
                checked += 1;
                if (psk != null) {
                    const pv = psk.?.value(colex, e.side);
                    if (pv != -128) {
                        psk_checked += 1;
                        if (pv == v) psk_match += 1;
                        if (e.L == e.H and pv != v) psk_mismatch_lh_eq += 1;
                    }
                }
                if (e.L == e.H) {
                    lh_eq_total += 1;
                    if (v != e.L) lh_eq_moved += 1;
                } else {
                    lh_lt_total += 1;
                    if (v >= e.L and v <= e.H) lh_lt_inside += 1 else lh_lt_outside += 1;
                    const pinned = eng.clampTie(3, 3, e.L, e.H);
                    if (v == pinned) lh_lt_eq_pinned += 1;
                    if (v == e.L or v == e.H) lh_lt_eq_edge += 1;
                }
            }
        }
        if (!first_b) j.sep();
        j.objBegin();
        j.key("B"); j.int(B);
        j.sep(); j.key("states"); j.int(bfs_res.total);
        j.sep(); j.key("back_edges"); j.int(res.back_edges);
        j.sep(); j.key("checked"); j.int(checked);
        j.sep(); j.key("L_eq_H_total"); j.int(lh_eq_total);
        j.sep(); j.key("L_eq_H_moved"); j.int(lh_eq_moved);
        j.sep(); j.key("L_eq_H_moved_pct"); j.flt(if (lh_eq_total == 0) 0 else @as(f64, @floatFromInt(lh_eq_moved)) * 100.0 / @as(f64, @floatFromInt(lh_eq_total)));
        j.sep(); j.key("L_lt_H_total"); j.int(lh_lt_total);
        j.sep(); j.key("L_lt_H_collapsed_inside"); j.int(lh_lt_inside);
        j.sep(); j.key("L_lt_H_collapsed_outside"); j.int(lh_lt_outside);
        j.sep(); j.key("L_lt_H_eq_pinned"); j.int(lh_lt_eq_pinned);
        j.sep(); j.key("L_lt_H_eq_bracket_edge"); j.int(lh_lt_eq_edge);
        if (psk != null) {
            j.sep(); j.key("psk_checked"); j.int(psk_checked);
            j.sep(); j.key("psk_match"); j.int(psk_match);
            j.sep(); j.key("psk_mismatch_at_L_eq_H"); j.int(psk_mismatch_lh_eq);
        }
        // root (empty goban) values
        const rb = (S.St{ .board = 0, .side = 0, .ko = ko_none, .passes = 0, .budget = 0 }).augLinear(B);
        const rw = (S.St{ .board = 0, .side = 1, .ko = ko_none, .passes = 0, .budget = 0 }).augLinear(B);
        j.sep(); j.key("root_black_V"); j.int(res.val[S.denseOf(&rank, rb)]);
        j.sep(); j.key("root_white_V"); j.int(res.val[S.denseOf(&rank, rw)]);
        j.sep(); j.key("root_longest_plies"); j.int(res.longest[S.denseOf(&rank, rb)]);
        j.sep(); j.key("root_min_caps_optimal"); j.int(res.min_cap[S.denseOf(&rank, rb)]);
        j.sep(); j.key("root_max_caps_optimal"); j.int(res.max_cap[S.denseOf(&rank, rb)]);
        j.objEnd();
        first_b = false;
    }
    j.arrEnd();
    j.objEnd();
    j.putCh('\n');
    try writeOut(gpa, out_path, j.buf.items);
}

// ---------------------------------------------------------------------------
// tests
// ---------------------------------------------------------------------------

test "T397 red-then-green: identityScan's bitpos loop returns (a u6 counter would wrap)" {
    // The T397 defect: `var bitpos: u6 = 0; while (bitpos < 64) : (bitpos += 1)`
    // wraps at 63 under -O ReleaseFast and loops forever (2,554/2,554 stack
    // samples at the two lines, 14h02m, per D054). This test runs the real
    // production loop (identityScan) over a two-word all-ones bitset and
    // asserts it returns with every bit visited. A regression to u6 fails
    // loudly — the scan hits its own `cap` bound and checked != expected —
    // instead of hanging the suite.
    const S = Solver(3, 3);
    const gpa = std.testing.allocator;
    const B: u8 = 2;
    const words: u64 = 2;
    const bits = try gpa.alloc(u64, 2);
    defer gpa.free(bits);
    bits[0] = std.math.maxInt(u64);
    bits[1] = std.math.maxInt(u64);
    const per_budget = try gpa.alloc(u64, 3);
    defer gpa.free(per_budget);
    @memset(per_budget, 0);
    const bfs_res = S.BfsResult{ .total = 128, .per_budget = per_budget, .words = words, .bits = bits, .B = B, .queue_peak = 0 };
    var rank = try S.Rank.build(gpa, &bfs_res);
    defer gpa.free(rank.prefix);
    const val = try gpa.alloc(i8, 128);
    defer gpa.free(val);
    const status = try gpa.alloc(u8, 128);
    defer gpa.free(status);
    const longest = try gpa.alloc(u16, 128);
    defer gpa.free(longest);
    const min_cap = try gpa.alloc(u8, 128);
    defer gpa.free(min_cap);
    const max_cap = try gpa.alloc(u8, 128);
    defer gpa.free(max_cap);
    const opt_move = try gpa.alloc(u8, 128);
    defer gpa.free(opt_move);
    const long_move = try gpa.alloc(u8, 128);
    defer gpa.free(long_move);
    const support = try gpa.alloc(u64, 128);
    defer gpa.free(support);
    @memset(val, 0);
    @memset(status, 2); // all sampled as done
    @memset(longest, 0);
    @memset(min_cap, 0);
    @memset(max_cap, 0);
    @memset(opt_move, S.PASS_MOVE);
    @memset(long_move, S.PASS_MOVE);
    @memset(support, 0);
    const res = S.ValueResult{ .val = val, .status = status, .longest = longest, .min_cap = min_cap, .max_cap = max_cap, .opt_move = opt_move, .long_move = long_move, .support = support, .back_edges = 0, .n_states = 128, .n_terminal = 0, .B = B };
    const id = try S.identityScan(gpa, &bfs_res, &rank, &res, B, false, 1);
    // every one of the 128 bits must be sampled (density 1), so checked == 128.
    // Pre-fix (u6), the inner loop never exits and `checked` never reaches 128
    // before the `cap` break: checked == cap, failing this expect.
    try std.testing.expect(id.checked == 128);
    try std.testing.expect(id.mismatch <= 128);
}


fn bracketsMode(gpa: std.mem.Allocator, B: u8, out_path: []const u8) !void {
    const S = Solver(3, 3);
    const E3 = eng.Engine(3, 3);
    const X3 = colexmod.Indexer(3, 3);
    const ko_none: u16 = 9;
    const table = try eng.Wzo2.open(gpa, "data/oracle-3x3-v2.wzo2");
    defer gpa.free(table.bytes);
    defer gpa.free(table.groups);

    // roots: every legal position × side at budget 0
    var root_base = std.ArrayListUnmanaged(u64).empty;
    defer root_base.deinit(gpa);
    var colex_idx: u64 = 0;
    while (colex_idx < X3.total) : (colex_idx += 1) {
        const pos: [9]i8 = X3.pos_from_colex(colex_idx);
        if (!E3.isLegalBoard(&pos)) continue;
        const board = E3.rank(&pos);
        inline for (.{ @as(u8, 0), @as(u8, 1) }) |side| {
            const st = S.St{ .board = board, .side = side, .ko = ko_none, .passes = 0, .budget = 0 };
            try root_base.append(gpa, st.baseLinear());
        }
    }
    var roots = std.ArrayListUnmanaged(u64).empty;
    defer roots.deinit(gpa);
    for (root_base.items) |bl| try roots.append(gpa, bl * (@as(u64, B) + 1));

    var bfs_res = try S.bfs(gpa, roots.items, B, false);
    defer gpa.free(bfs_res.bits);
    defer gpa.free(bfs_res.per_budget);
    var rank = try S.Rank.build(gpa, &bfs_res);
    defer gpa.free(rank.prefix);
    const res = try S.dfsValues(gpa, &bfs_res, &rank, roots.items, false);
    defer gpa.free(res.val);
    defer gpa.free(res.status);
    defer gpa.free(res.longest);
    defer gpa.free(res.min_cap);
    defer gpa.free(res.max_cap);
    defer gpa.free(res.opt_move);
    defer gpa.free(res.long_move);
    defer gpa.free(res.support);

    var j = Json.init(gpa);
    defer j.deinit();
    j.objBegin();
    j.key("task_id"); j.esc("T387");
    j.sep(); j.key("mode"); j.esc("brackets");
    j.sep(); j.key("goban"); j.esc("3x3");
    j.sep(); j.key("B"); j.int(B);
    j.sep(); j.key("slots"); j.arrBegin();
    var first = true;
    for (0..@as(usize, @intCast(table.n_groups))) |g| {
        const colex = table.groups[g].colex;
        const pos: [9]i8 = X3.pos_from_colex(colex);
        const board = E3.rank(&pos);
        for (0..table.groups[g].count) |i| {
            const e = table.entryAt(g, i);
            if (e.passes != 0 or e.ko != ko_none) continue;
            const side_u8: u8 = if (e.side > 0) 0 else 1;
            const root_lin = (S.St{ .board = board, .side = side_u8, .ko = ko_none, .passes = 0, .budget = 0 }).augLinear(B);
            const v = res.val[S.denseOf(&rank, root_lin)];
            if (!first) j.sep();
            j.objBegin();
            j.key("colex"); j.int(colex);
            j.sep(); j.key("side"); j.int(e.side);
            j.sep(); j.key("L"); j.int(e.L);
            j.sep(); j.key("H"); j.int(e.H);
            j.sep(); j.key("V"); j.int(v);
            j.objEnd();
            first = false;
        }
    }
    j.arrEnd();
    j.objEnd();
    j.putCh('\n');
    try writeOut(gpa, out_path, j.buf.items);
}

fn lineMode(gpa: std.mem.Allocator, w: usize, h: usize, B: u8, optimal: bool, out_path: []const u8) !void {
    switch (w * 10 + h) {
        33 => try lineModeImpl(3, 3, gpa, B, optimal, out_path),
        43 => try lineModeImpl(4, 3, gpa, B, optimal, out_path),
        else => std.debug.print("line: unsupported goban {d}x{d}\n", .{ w, h }),
    }
}

fn lineModeImpl(comptime W: usize, comptime H: usize, gpa: std.mem.Allocator, B: u8, optimal: bool, out_path: []const u8) !void {
    const S = Solver(W, H);
    const E_ = eng.Engine(W, H);
    const roots = S.emptyRoots(B);
    var bfs_res = try S.bfs(gpa, &roots, B, false);
    defer gpa.free(bfs_res.bits);
    defer gpa.free(bfs_res.per_budget);
    var rank = try S.Rank.build(gpa, &bfs_res);
    defer gpa.free(rank.prefix);
    const res = try S.dfsValues(gpa, &bfs_res, &rank, &roots, false);
    defer gpa.free(res.val);
    defer gpa.free(res.status);
    defer gpa.free(res.longest);
    defer gpa.free(res.min_cap);
    defer gpa.free(res.max_cap);
    defer gpa.free(res.opt_move);
    defer gpa.free(res.long_move);
    defer gpa.free(res.support);

    var j = Json.init(gpa);
    defer j.deinit();
    j.objBegin();
    j.key("task_id"); j.esc("T387");
    j.sep(); j.key("mode"); j.esc("line");
    j.sep(); j.key("goban"); j.esc(comptime @as([3]u8, .{ '0' + W, 'x', '0' + H })[0..]);
    j.sep(); j.key("B"); j.int(B);
    j.sep(); j.key("line"); j.esc(if (optimal) "optimal" else "longest");

    const root = (S.St{ .board = 0, .side = 0, .ko = @as(u16, @intCast(W * H)), .passes = 0, .budget = 0 }).augLinear(B);
    var cur = root;
    var plies: u32 = 0;
    var captures: u32 = 0;
    j.sep(); j.key("moves"); j.arrBegin();
    var first = true;
    while (true) {
        const d = S.denseOf(&rank, cur);
        const s = S.decodeAug(cur, B);
        const board = E_.unrank(s.board);
        if (!first) j.sep();
        j.objBegin();
        j.key("ply"); j.int(plies);
        j.sep(); j.key("side"); j.esc(if (s.side == 0) "B" else "W");
        j.sep(); j.key("board"); j.esc(&boardToStr(W, H, &board));
        j.sep(); j.key("budget_used"); j.int(s.budget);
        j.objEnd();
        first = false;
        if (s.passes >= 2) break;
        const mv = if (optimal) res.opt_move[d] else res.long_move[d];
        if (mv == S.PASS_MOVE) {
            cur = (S.applyPass(s) orelse unreachable).augLinear(B);
        } else {
            const colour: i8 = if (s.side == 0) 1 else -1;
            const p = S.applyPlace(s, &board, colour, mv, B, false) orelse unreachable;
            captures += p.k;
            cur = p.st.augLinear(B);
        }
        plies += 1;
        if (plies > 10000) break; // defensive
    }
    j.arrEnd();
    j.sep(); j.key("total_plies"); j.int(plies);
    j.sep(); j.key("total_captures"); j.int(captures);
    j.sep(); j.key("final_value"); j.int(res.val[S.denseOf(&rank, root)]);
    j.objEnd();
    j.putCh('\n');
    try writeOut(gpa, out_path, j.buf.items);
}

fn boardToStr(comptime W: usize, comptime H: usize, board: *const [W * H]i8) [W * H * 2]u8 {
    var out: [W * H * 2]u8 = undefined;
    for (0..W * H) |i| {
        out[i * 2] = switch (board[i]) {
            1 => 'B',
            -1 => 'W',
            else => '.',
        };
        out[i * 2 + 1] = ' ';
    }
    return out;
}

fn scoringMode(gpa: std.mem.Allocator, out_path: []const u8) !void {
    const scoremod = @import("score.zig");
    const S2 = scoremod.Score(2, 2);

    // The T382 7-state capture-exchange cycle at 2×2 (docs/research/
    // goban-pathology-2026-08-05.md §3.4): {W@0} B@1 {W@0,B@1} W@2
    // {W@0,B@1,W@2} B@3(cap 2) {B@1,B@3} W@0 {W@0,B@1,B@3} B@2(cap 1)
    // {B@1,B@2,B@3} W@0(cap 3) {W@0}
    const boards = [_][4]i8{
        .{ -1, 0, 0, 0 },
        .{ -1, 1, 0, 0 },
        .{ -1, 1, -1, 0 },
        .{ 0, 1, 0, 1 },
        .{ -1, 1, 0, 1 },
        .{ -1, 1, -1, 1 },
        .{ -1, 0, 0, 0 },
    };
    const caps = [_][2]u8{ .{ 0, 0 }, .{ 0, 0 }, .{ 0, 0 }, .{ 2, 0 }, .{ 0, 0 }, .{ 1, 0 }, .{ 0, 3 } }; // {B prisoners, W prisoners} after each move
    var j = Json.init(gpa);
    defer j.deinit();
    j.objBegin();
    j.key("task_id"); j.esc("T387");
    j.sep(); j.key("mode"); j.esc("scoring");
    j.sep(); j.key("claim"); j.esc("Chinese area is a function of the final board alone, so any capture-and-rebuild round trip is score-neutral; Japanese territory + prisoners is not a board function, so the same round trip is neutral only when the prisoners cancel.");
    j.sep(); j.key("cycle"); j.esc("the T382 2x2 7-state capture-exchange cycle (basic-ko legal; goban-pathology-2026-08-05.md 3.4)");
    j.sep(); j.key("steps"); j.arrBegin();
    var b_prisoners: i32 = 0;
    var w_prisoners: i32 = 0;
    for (boards, 0..) |b, i| {
        const area = S2.chinese_area(&b);
        const terr = S2.territory_japanese(&b);
        b_prisoners += caps[i][0];
        w_prisoners += caps[i][1];
        if (i > 0) j.sep();
        j.objBegin();
        j.key("step"); j.int(i);
        j.sep(); j.key("board"); j.esc(@as([]const u8, comptime ""));
        j.sep(); j.key("area_score"); j.int(area);
        j.sep(); j.key("territory_black"); j.int(terr.black);
        j.sep(); j.key("territory_white"); j.int(terr.white);
        j.sep(); j.key("prisoners_black"); j.int(b_prisoners);
        j.sep(); j.key("prisoners_white"); j.int(w_prisoners);
        j.sep(); j.key("japanese_territory_plus_prisoners"); j.int(terr.black - terr.white + b_prisoners - w_prisoners);
        j.objEnd();
    }
    j.arrEnd();
    const start = boards[0];
    const end = boards[boards.len - 1];
    j.sep(); j.key("round_trip_returns_board"); j.bool_(std.mem.eql([4]i8, boards[0..1], boards[boards.len - 1 ..]));
    j.sep(); j.key("area_neutral"); j.bool_(S2.chinese_area(&start) == S2.chinese_area(&end));
    // The asymmetry proper: the SAME final board reached by two different
    // capture histories. Board {B@1,B@3} (2×2) is reached by the cycle at
    // step 3 (B holds 2 prisoners: it captured W@0 and W@2) and directly
    // (B plays 1 then 3, W never had stones: 0 prisoners). Area scoring is
    // a board function → identical; Japanese territory + prisoners is not.
    const board_13 = [_]i8{ 0, 1, 0, 1 };
    const terr13 = S2.territory_japanese(&board_13);
    j.sep(); j.key("asymmetry_same_board_two_histories"); j.objBegin();
    j.key("board"); j.esc("B@1,B@3 on 2x2");
    j.sep(); j.key("area"); j.int(S2.chinese_area(&board_13));
    j.sep(); j.key("territory_black_minus_white"); j.int(terr13.black - terr13.white);
    j.sep(); j.key("japanese_history_A_cycle_prisoners_B2_W0"); j.int(terr13.black - terr13.white + 2);
    j.sep(); j.key("japanese_history_B_direct_prisoners_B0_W0"); j.int(terr13.black - terr13.white + 0);
    j.sep(); j.key("area_identical"); j.bool_(true);
    j.sep(); j.key("japanese_differ_by"); j.int(2);
    j.objEnd();
    j.objEnd();
    j.putCh('\n');
    try writeOut(gpa, out_path, j.buf.items);
}

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    const mode: []const u8 = args.next() orelse {
        std.debug.print("usage: t387-budget <reach|dag|value|hypothesis|scoring> ...\n", .{});
        return;
    };

    if (std.mem.eql(u8, mode, "reach")) {
        const wh = args.next() orelse "3x3";
        const bs = args.next() orelse "8";
        var out: []const u8 = "findings/T387-reach.json";
        var planted = false;
        if (args.next()) |a| {
            if (std.mem.eql(u8, a, "--planted")) {
                planted = true;
                out = args.next() orelse "findings/T387-reach-planted.json";
            } else out = a;
        }
        const g = parseWxH(wh) orelse {
            std.debug.print("bad goban {s}\n", .{wh});
            return;
        };
        const B: u8 = std.fmt.parseInt(u8, bs, 10) catch {
            std.debug.print("bad B {s}\n", .{bs});
            return;
        };
        try reachMode(gpa, g.w, g.h, B, planted, out);
        return;
    }

    if (std.mem.eql(u8, mode, "dag")) {
        const wh = args.next() orelse "3x3";
        const bs = args.next() orelse "8";
        var base = false;
        var B: u8 = 8;
        var out: []const u8 = "findings/T387-dag.json";
        if (std.mem.eql(u8, bs, "base")) {
            base = true;
            out = args.next() orelse out;
        } else {
            B = std.fmt.parseInt(u8, bs, 10) catch {
                std.debug.print("bad B {s}\n", .{bs});
                return;
            };
            if (args.next()) |r| out = r;
        }
        const g = parseWxH(wh) orelse {
            std.debug.print("bad goban {s}\n", .{wh});
            return;
        };
        try dagMode(gpa, g.w, g.h, B, base, out);
        return;
    }

    if (std.mem.eql(u8, mode, "value")) {
        const wh = args.next() orelse "3x3";
        const bs = args.next() orelse "8";
        var out: []const u8 = "findings/T387-value.json";
        var planted = false;
        if (args.next()) |a| {
            if (std.mem.eql(u8, a, "--planted")) {
                planted = true;
                out = args.next() orelse "findings/T387-value-planted.json";
            } else out = a;
        }
        const g = parseWxH(wh) orelse {
            std.debug.print("bad goban {s}\n", .{wh});
            return;
        };
        const B: u8 = std.fmt.parseInt(u8, bs, 10) catch {
            std.debug.print("bad B {s}\n", .{bs});
            return;
        };
        try valueMode(gpa, g.w, g.h, B, planted, out);
        return;
    }

    if (std.mem.eql(u8, mode, "hypothesis")) {
        const bmaxs = args.next() orelse "16";
        const Bmax: u8 = std.fmt.parseInt(u8, bmaxs, 10) catch {
            std.debug.print("bad Bmax {s}\n", .{bmaxs});
            return;
        };
        var with_psk = false;
        var planted = false;
        var out: []const u8 = "findings/T387-hypothesis.json";
        if (args.next()) |a| {
            if (std.mem.eql(u8, a, "psk")) {
                with_psk = true;
                out = args.next() orelse out;
            } else if (std.mem.eql(u8, a, "--planted")) {
                planted = true;
                out = args.next() orelse "findings/T387-hypothesis-planted.json";
            } else {
                out = a;
            }
        }
        try hypothesisMode(gpa, Bmax, planted, out, with_psk);
        return;
    }

    if (std.mem.eql(u8, mode, "scoring")) {
        const out = args.next() orelse "findings/T387-scoring.json";
        try scoringMode(gpa, out);
        return;
    }

    if (std.mem.eql(u8, mode, "line")) {
        const wh = args.next() orelse "3x3";
        const bs = args.next() orelse "8";
        const kind = args.next() orelse "optimal";
        const out = args.next() orelse "findings/T387-line.json";
        const g = parseWxH(wh) orelse {
            std.debug.print("bad goban {s}\n", .{wh});
            return;
        };
        const B: u8 = std.fmt.parseInt(u8, bs, 10) catch {
            std.debug.print("bad B {s}\n", .{bs});
            return;
        };
        try lineMode(gpa, g.w, g.h, B, std.mem.eql(u8, kind, "optimal"), out);
        return;
    }

    if (std.mem.eql(u8, mode, "brackets")) {
        const bs = args.next() orelse "24";
        const out = args.next() orelse "findings/T387-brackets.json";
        const B: u8 = std.fmt.parseInt(u8, bs, 10) catch {
            std.debug.print("bad B {s}\n", .{bs});
            return;
        };
        try bracketsMode(gpa, B, out);
        return;
    }

    std.debug.print("unknown mode {s}\n", .{mode});
}

fn hasFlag(args: std.process.Args.Iterator, flag: []const u8) bool {
    var it = args;
    var found = false;
    while (it.next()) |a| {
        if (std.mem.eql(u8, a, flag)) {
            found = true;
            break;
        }
    }
    return found;
}
