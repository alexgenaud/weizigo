// Task: EXP-8 · Role: worker · Model: Kimi K2.7 · Date: 2026-07-29
//
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
//
////////////////////////////////////////////
//
// EXP-8 — PSK divergence harness (strategy S2).
//
// For sampled positions, compare the value and the move selected by a loaded
// table against the exact positional-superko (PSK) solver from src/retro.zig.
//
// The harness is rule-agnostic in the value it loads: it can be pointed at a
// PSK table, a synthetic table, or (once they exist) a new-rule table.  The
// exact reference is always fresh-start PSK.
//
// Frames implemented:
//   (A) reachable-play  -- positions observed in playouts from the empty
//                            goban under the same policies as reachcensus.
//   (B) uniform-over-empties -- legal positions with a given empty-count,
//                            sampled uniformly over slots.  (placeholder)
//
// Output: per-goban, per-policy divergence counts, PSK-value-loss histogram,
// exclusion accounting, and an empties-vs-solvability curve.
//
// IMPORTANT LIMITATION of this run (2026-07-29): new-rule (basic-ko + tie)
// tables do not yet exist on disk (EXP-4/5/6 are blocked).  The harness is
// built and calibrated here; the actual new-rule-vs-PSK divergence rate must
// be re-run once those tables are available.  Numbers produced with the
// existing PSK tables are explicitly labelled as calibration / sanity.

const std = @import("std");
const rules = @import("rules.zig");
const colexmod = @import("colex.zig");
const artifact = @import("artifact.zig");
const retro = @import("retro.zig");

const UNDEF: i8 = -128;
const COLS = "ABCDEFGHJKLMNOPQRSTUVWXYZ";

const Policy = enum {
    oracle,
    random,
    mixed,
    oracle_rt,

    fn label(p: Policy) []const u8 {
        return switch (p) {
            .oracle => "oracle",
            .random => "random",
            .mixed => "mixed",
            .oracle_rt => "oracle-rt",
        };
    }
};

const Driver = enum { engine, rand };
const Legality = enum { psk, basic_ko };

fn emptiesIn(pos: []const i8) u32 {
    var n: u32 = 0;
    for (pos) |v| {
        if (v == 0) n += 1;
    }
    return n;
}

// Wilson score interval for a binomial proportion (95%).
fn wilson95(successes: u64, trials: u64) struct { lo: f64, hi: f64, hi_rule3: f64 } {
    if (trials == 0) return .{ .lo = 0, .hi = 0, .hi_rule3 = 0 };
    const n = @as(f64, @floatFromInt(trials));
    const z: f64 = 1.96;
    const p = @as(f64, @floatFromInt(successes)) / n;
    const z2 = z * z;
    const denom = 1.0 + z2 / n;
    const centre = (p + z2 / (2.0 * n)) / denom;
    const width = z * @sqrt((p * (1.0 - p) + z2 / (4.0 * n)) / n) / denom;
    const lo = @max(0.0, centre - width);
    const hi = @min(1.0, centre + width);
    const hi3 = @min(1.0, 3.0 / n);
    return .{ .lo = lo, .hi = hi, .hi_rule3 = hi3 };
}

// History-exact PSK wrapper around retro.Retro(w,h).O.solve.
// Uses the actual game history (pre-populated O.History) and turns memo and
// bracket cuts OFF, giving the exact PSK value of the node under that history.
// This is the same discipline as the C2 falsification probe.
fn HistoryPSK(comptime w: usize, comptime h: usize) type {
    const RT = retro.Retro(w, h);
    const O = RT.O;
    const R = O.R;
    const X = O.X;
    const total = X.total;
    const Pos = O.Pos;

    return struct {
        gpa: std.mem.Allocator,
        budget: u64,

        const Self = @This();

        fn allocCtx(self: *Self) !O.Ctx {
            const t: usize = @intCast(total);
            const vb = try self.gpa.alloc(i8, t);
            errdefer self.gpa.free(vb);
            const vw = try self.gpa.alloc(i8, t);
            errdefer self.gpa.free(vw);
            const cb = try self.gpa.alloc(bool, t);
            errdefer self.gpa.free(cb);
            const cw = try self.gpa.alloc(bool, t);
            @memset(vb, 0);
            @memset(vw, 0);
            @memset(cb, false);
            @memset(cw, false);
            return .{
                .vb = vb,
                .vw = vw,
                .cb = cb,
                .cw = cw,
                .memo = false,
                .memo_writes = false,
                .brackets = false,
                .saw_ban = false,
                .nodes = 0,
                .budget = self.budget,
                .lbb = null,
                .ubb = null,
                .lbw = null,
                .ubw = null,
                .deps = false,
                .dep_map = null,
                .dep_layer_max = 255,
                .journal = null,
                .journal_gpa = undefined,
            };
        }

        fn freeCtx(self: *Self, ctx: *O.Ctx) void {
            self.gpa.free(ctx.vb);
            self.gpa.free(ctx.vw);
            self.gpa.free(ctx.cb);
            self.gpa.free(ctx.cw);
        }

        fn historyFromSlice(history: []const Pos) O.History {
            var hist = O.History{};
            for (history) |b| hist.push(&b);
            return hist;
        }

        pub fn solveNode(self: *Self, pos: *const Pos, side: i8, history: []const Pos) error{ Budget, OutOfMemory }!i8 {
            var ctx = try self.allocCtx();
            defer self.freeCtx(&ctx);
            var hist = historyFromSlice(history);
            const r = try O.solve(&ctx, pos, side, 0, &hist);
            return r.value;
        }

        pub fn solvePass(self: *Self, pos: *const Pos, side: i8, history: []const Pos) error{ Budget, OutOfMemory }!i8 {
            var ctx = try self.allocCtx();
            defer self.freeCtx(&ctx);
            var hist = historyFromSlice(history);
            const r = try O.solve(&ctx, pos, -side, 1, &hist);
            return r.value;
        }

        pub fn solveChild(self: *Self, pos: *const Pos, side: i8, cell: usize, history: []const Pos) error{ Budget, OutOfMemory }!?i8 {
            const child = R.pos_from_move(pos, side, cell) catch return null;
            var hist = historyFromSlice(history);
            if (hist.repeatsIndex(&child) != null) return null;
            hist.push(&child);
            var ctx = try self.allocCtx();
            defer self.freeCtx(&ctx);
            const r = try O.solve(&ctx, &child, -side, 0, &hist);
            return r.value;
        }
    };
}

fn Divergence(comptime w: usize, comptime h: usize) type {
    return struct {
        const Self = @This();
        const R = rules.Rules(w, h);
        const X = colexmod.Indexer(w, h);
        const n = R.n;
        const Pos = R.Pos;
        const PSK = HistoryPSK(w, h);

        const BucketStats = struct {
            sampled: u64 = 0,
            solved: u64 = 0,
            budget_excl: u64 = 0,
            oom_excl: u64 = 0,
            undef_excl: u64 = 0,
            value_div: u64 = 0,
            move_div: u64 = 0,
            suboptimal: u64 = 0,
            sum_abs_loss: u64 = 0,
        };

        const PolicyStats = struct {
            games: u64 = 0,
            nodes_observed: u64 = 0,
            sampled: u64 = 0,
            solved: u64 = 0,
            budget_excl: u64 = 0,
            oom_excl: u64 = 0,
            undef_excl: u64 = 0,
            value_div: u64 = 0,
            move_div: u64 = 0,
            suboptimal: u64 = 0,
            sum_abs_loss: u64 = 0,
            loss_hist: [65]u64 = [_]u64{0} ** 65,
            ko_sens: u64 = 0,
            ko_sens_value_div: u64 = 0,
            distinct_lines: u64 = 0,
        };

        d: *const artifact.Decoded,
        gpa: std.mem.Allocator,
        budget: u64,
        entry_cap: u32,
        max_empties: u32,
        seen: std.AutoHashMap(u64, void),

        stats: [4]PolicyStats,
        empties: [n + 1]BucketStats,

        pub fn init(d: *const artifact.Decoded, gpa: std.mem.Allocator, budget: u64, entry_cap: u32, max_empties: u32) Self {
            return .{
                .d = d,
                .gpa = gpa,
                .budget = budget,
                .entry_cap = entry_cap,
                .max_empties = max_empties,
                .seen = std.AutoHashMap(u64, void).init(gpa),
                .stats = [_]PolicyStats{.{}} ** 4,
                .empties = [_]BucketStats{.{}} ** (n + 1),
            };
        }

        pub fn deinit(self: *Self) void {
            self.seen.deinit();
        }

        fn v0(s: *const Self, pos: *const Pos, side: i8) i8 {
            const i: usize = @intCast(X.colex_from_pos(pos));
            return if (side > 0) s.d.vb[i] else s.d.vw[i];
        }
        fn dtt0(s: *const Self, pos: *const Pos, side: i8) u8 {
            const i: usize = @intCast(X.colex_from_pos(pos));
            return if (side > 0) s.d.db[i] else s.d.dw[i];
        }
        fn kosens(s: *const Self, pos: *const Pos, side: i8) bool {
            const i: usize = @intCast(X.colex_from_pos(pos));
            const f = if (side > 0) s.d.fb[i] else s.d.fw[i];
            return f & 1 != 0;
        }

        fn v1_from_table(s: *const Self, pos: *const Pos, side: i8) i8 {
            const maxing = side > 0;
            var best: i8 = R.area_score(pos);
            for (0..n) |c| {
                if (pos[c] != 0) continue;
                const ch = R.pos_from_move(pos, side, c) catch continue;
                const v = s.v0(&ch, -side);
                if (v == UNDEF) continue;
                if (if (maxing) v > best else v < best) best = v;
            }
            return best;
        }

        const Choice = struct { cell: ?usize, value: i8, dtt: u8, caps: u16 = 0 };

        fn pick(cur: ?Choice, mv: Choice, maxing: bool) ?Choice {
            if (cur == null) return mv;
            const c = cur.?;
            const vbetter = if (maxing) mv.value > c.value else mv.value < c.value;
            if (vbetter) return mv;
            if (mv.value != c.value) return c;
            if (mv.caps != c.caps) return if (mv.caps > c.caps) mv else c;
            if (mv.dtt != c.dtt) return if (mv.dtt < c.dtt) mv else c;
            return c;
        }

        fn eqRank(a: Choice, b: Choice) bool {
            return a.value == b.value and a.caps == b.caps and a.dtt == b.dtt;
        }

        // The table's selection rule, mirroring reachcensus/gtp.Session.choose:
        // one-ply extremum over PSK-legal children's stored values, with the
        // pass edge, the (value, captures, DTT) ordering, and the early-game
        // "always play the opening" override.
        fn chooseTable(s: *const Self, state: *const PlayState, side: i8, _rt: bool, _rnd: std.Random, leg: Legality) Choice {
            _ = _rt; _ = _rnd;
            const maxing = side > 0;
            const opp: i8 = -side;
            const opp_before = countColor(&state.pos, opp);
            const pass = Choice{
                .cell = null,
                .value = if (state.passes >= 1) R.area_score(&state.pos) else s.v1_from_table(&state.pos, -side),
                .dtt = if (state.passes >= 1) 0 else 1,
                .caps = 0,
            };
            var best: ?Choice = pass;
            var best_move: ?Choice = null;
            for (0..n) |p| {
                if (state.pos[p] != 0) continue;
                const child = R.pos_from_move(&state.pos, side, p) catch continue;
                if (s.repForbidden(state, &child, leg)) continue;
                const v = s.v0(&child, -side);
                if (v == UNDEF) continue;
                const dt = s.dtt0(&child, -side);
                const caps: u16 = opp_before - countColor(&child, opp);
                const mv = Choice{ .cell = p, .value = v, .dtt = dt, .caps = caps };
                best_move = pick(best_move, mv, maxing);
                best = pick(best, mv, maxing);
            }
            if (best.?.cell == null) {
                const area: usize = w * h;
                var own: usize = 0;
                var tot: usize = 0;
                for (state.pos) |x| {
                    if (x == 0) continue;
                    tot += 1;
                    if ((x > 0) == (side > 0)) own += 1;
                }
                if (own < area / 4 and tot < area / 2) {
                    if (best_move) |bm| return bm;
                }
            }
            return best.?;
        }

        fn repForbidden(s: *const Self, state: *const PlayState, child: *const Pos, leg: Legality) bool {
            return switch (leg) {
                .psk => s.seenBoard(state, child),
                .basic_ko => state.ply >= 1 and std.mem.eql(i8, &state.bply[state.ply - 1], child),
            };
        }

        fn seenBoard(_s: *const Self, state: *const PlayState, p: *const Pos) bool {
            _ = _s;
            for (state.hist[0..state.hist_len]) |*b| {
                if (std.mem.eql(i8, b, p)) return true;
            }
            return false;
        }

        fn countColor(p: *const Pos, color: i8) u16 {
            var c: u16 = 0;
            for (p) |x| if (x == color) { c += 1; };
            return c;
        }

        const PlayState = struct {
            pos: Pos = [_]i8{0} ** n,
            hist: [1024]Pos = undefined,
            hist_len: usize = 0,
            bply: [1024]Pos = undefined,
            ply: usize = 0,
            passes: u8 = 0,

            fn reset(st: *PlayState) void {
                st.pos = [_]i8{0} ** n;
                st.hist_len = 0;
                st.ply = 0;
                st.passes = 0;
                st.push(&st.pos);
                st.bply[0] = st.pos;
            }
            fn push(st: *PlayState, p: *const Pos) void {
                st.hist[st.hist_len] = p.*;
                st.hist_len += 1;
            }
            fn recordPly(st: *PlayState) void {
                st.bply[st.ply] = st.pos;
            }
        };

        fn chooseRandom(state: *const PlayState, side: i8, rnd: std.Random, pass_permille: u32, leg: Legality) Choice {
            if (rnd.uintLessThan(u32, 1000) < pass_permille) {
                return .{ .cell = null, .value = 0, .dtt = 0 };
            }
            var pool: [n]usize = undefined;
            var k: usize = 0;
            for (0..n) |p| {
                if (state.pos[p] != 0) continue;
                const child = R.pos_from_move(&state.pos, side, p) catch continue;
                if (repForbiddenStatic(state, &child, leg)) continue;
                pool[k] = p;
                k += 1;
            }
            if (k == 0) return .{ .cell = null, .value = 0, .dtt = 0 };
            return .{ .cell = pool[rnd.uintLessThan(usize, k)], .value = 0, .dtt = 0 };
        }

        fn repForbiddenStatic(state: *const PlayState, child: *const Pos, leg: Legality) bool {
            return switch (leg) {
                .psk => blk: {
                    for (state.hist[0..state.hist_len]) |*b| {
                        if (std.mem.eql(i8, b, child)) break :blk true;
                    }
                    break :blk false;
                },
                .basic_ko => state.ply >= 1 and std.mem.eql(i8, &state.bply[state.ply - 1], child),
            };
        }

        pub fn runFrameA(
            self: *Self,
            policy: Policy,
            games: u64,
            seed: u64,
            ply_cap: u64,
            pass_permille: u32,
            settled_stop: bool,
        ) !void {
            var st = &self.stats[@intFromEnum(policy)];
            st.* = .{};
            var state = PlayState{};
            var prng = std.Random.DefaultPrng.init(seed);
            const rnd = prng.random();
            var lines = std.AutoHashMap(u64, void).init(self.gpa);
            defer lines.deinit();

            var g: u64 = 0;
            while (g < games) : (g += 1) {
                state.reset();
                var drv: [2]Driver = undefined;
                switch (policy) {
                    .oracle, .oracle_rt => drv = .{ .engine, .engine },
                    .random => drv = .{ .rand, .rand },
                    .mixed => drv = if (g % 2 == 0) .{ .engine, .rand } else .{ .rand, .engine },
                }

                var side: i8 = 1;
                var ply: u64 = 0;
                var linehash: u64 = 0xcbf29ce484222325;
                while (true) {
                    if (ply >= ply_cap) break;
                    st.nodes_observed += 1;

                    // Process this decision node.
                    self.observeNode(&state, side, policy, st);

                    // Choose a move under real PSK.
                    const engine_turn = drv[if (side > 0) 0 else 1] == .engine;
                    const ch = if (engine_turn)
                        self.chooseTable(&state, side, policy == .oracle_rt, rnd, .psk)
                    else
                        chooseRandom(&state, side, rnd, pass_permille, .psk);

                    if (ch.cell) |c| {
                        const child = R.pos_from_move(&state.pos, side, c) catch unreachable;
                        state.pos = child;
                        state.push(&child);
                        state.passes = 0;
                        linehash = (linehash ^ (c + 1)) *% 0x100000001b3;
                    } else {
                        state.passes += 1;
                        linehash = (linehash ^ 0xff) *% 0x100000001b3;
                    }
                    ply += 1;
                    state.ply = ply;
                    state.recordPly();
                    if (state.passes >= 2) break;
                    if (settled_stop and R.is_settled(&state.pos)) break;
                    side = -side;
                }
                st.games += 1;
                try lines.put(linehash, {});
            }
            st.distinct_lines = lines.count();
        }

        fn observeNode(self: *Self, state: *const PlayState, side: i8, _policy: Policy, st: *PolicyStats) void {
            _ = _policy;
            const idx = X.colex_from_pos(&state.pos);
            const key = (@as(u64, idx) << 1) | @intFromBool(side < 0);
            if (self.seen.contains(key)) return;
            self.seen.put(key, {}) catch return;

            const e = emptiesIn(&state.pos);
            const bucket = &self.empties[e];
            bucket.sampled += 1;
            st.sampled += 1;

            if (e > self.max_empties) return;

            const table_val = self.v0(&state.pos, side);
            if (table_val == UNDEF) {
                st.undef_excl += 1;
                bucket.undef_excl += 1;
                return;
            }

            var psk = PSK{ .gpa = self.gpa, .budget = self.budget };
            const history = state.hist[0..state.hist_len];
            const root_val = psk.solveNode(&state.pos, side, history) catch |err| {
                if (err == error.Budget) {
                    st.budget_excl += 1;
                    bucket.budget_excl += 1;
                } else {
                    st.oom_excl += 1;
                    bucket.oom_excl += 1;
                }
                return;
            };
            st.solved += 1;
            bucket.solved += 1;

            const ko = self.kosens(&state.pos, side);
            if (ko) st.ko_sens += 1;

            if (table_val != root_val) {
                st.value_div += 1;
                bucket.value_div += 1;
                if (ko) st.ko_sens_value_div += 1;
            }

            var prng = std.Random.DefaultPrng.init(@intCast(X.colex_from_pos(&state.pos)));
            const rnd = prng.random();
            const chosen = self.chooseTable(state, side, false, rnd, .psk);

            var optimal_pass = false;
            var optimal_count: usize = 0;
            var chosen_optimal = false;
            var chosen_value: ?i8 = null;

            const pass_val = psk.solvePass(&state.pos, side, history) catch null;
            if (pass_val) |pv| {
                if (pv == root_val) {
                    optimal_pass = true;
                    optimal_count += 1;
                }
            }

            for (0..n) |p| {
                if (state.pos[p] != 0) continue;
                const child = R.pos_from_move(&state.pos, side, p) catch continue;
                if (self.seenBoard(state, &child)) continue;
                const cv = psk.solveChild(&state.pos, side, p, history) catch null;
                if (cv) |v| {
                    if (v == root_val) {
                        optimal_count += 1;
                    }
                    if (chosen.cell) |cc| {
                        if (cc == p) {
                            chosen_value = v;
                            if (v == root_val) chosen_optimal = true;
                        }
                    }
                }
            }

            if (chosen.cell == null) {
                chosen_value = pass_val;
                if (optimal_pass) chosen_optimal = true;
            }

            if (!chosen_optimal) {
                st.move_div += 1;
                bucket.move_div += 1;
                if (chosen_value) |cv| {
                    const loss = if (root_val > cv) root_val - cv else cv - root_val;
                    if (loss > 0) {
                        st.suboptimal += 1;
                        bucket.suboptimal += 1;
                        st.sum_abs_loss += @intCast(loss);
                        bucket.sum_abs_loss += @intCast(loss);
                        const hi: usize = @intCast(@min(loss, 64));
                        st.loss_hist[hi] += 1;
                    }
                }
            }
        }

        pub fn report(self: *const Self, policy: Policy) void {
            const st = self.stats[@intFromEnum(policy)];
            std.debug.print("\n== EXP-8 divergence: frame A, policy {s}, board {d}x{d} ==\n", .{ policy.label(), w, h });
            std.debug.print("games:                 {d}\n", .{st.games});
            std.debug.print("distinct lines:        {d}\n", .{st.distinct_lines});
            std.debug.print("decision nodes observed: {d}\n", .{st.nodes_observed});
            std.debug.print("sampled for PSK solve:   {d}\n", .{st.sampled});
            std.debug.print("  solved:                {d}\n", .{st.solved});
            std.debug.print("  budget-excluded:       {d}\n", .{st.budget_excl});
            std.debug.print("  OOM-excluded:          {d}\n", .{st.oom_excl});
            std.debug.print("  UNDEF-excluded:        {d}\n", .{st.undef_excl});
            std.debug.print("value divergence:        {d}/{d} ", .{ st.value_div, st.solved });
            const vci = wilson95(st.value_div, st.solved);
            std.debug.print("   95% CI: [{d:.4}, {d:.4}]  (rule-of-3 upper {d:.4})\n", .{ vci.lo, vci.hi, vci.hi_rule3 });

            std.debug.print("\n  move divergence:        {d}/{d}\n", .{ st.move_div, st.solved });
            std.debug.print("  suboptimal moves:      {d}/{d}\n", .{ st.suboptimal, st.solved });
            std.debug.print("  mean PSK-value loss:   {d:.2}\n", .{
                if (st.suboptimal == 0) 0.0 else @as(f64, @floatFromInt(st.sum_abs_loss)) / @as(f64, @floatFromInt(st.suboptimal)),
            });

            std.debug.print("  KO_SENSITIVE among solved: {d}/{d}; value-div among them: {d}\n", .{
                st.ko_sens, st.solved, st.ko_sens_value_div,
            });

            std.debug.print("\n  PSK-value-loss histogram (points):\n", .{});
            var any = false;
            for (0..65) |i| {
                if (st.loss_hist[i] == 0) continue;
                any = true;
                if (i == 64) {
                    std.debug.print("    >=64 : {d}\n", .{st.loss_hist[i]});
                } else {
                    std.debug.print("    {d:>2}: {d}\n", .{ i, st.loss_hist[i] });
                }
            }
            if (!any) std.debug.print("    (no suboptimal moves)\n", .{});
        }

        pub fn reportCurve(self: *const Self) void {
            std.debug.print("\n== empties-vs-solvability curve ({d}x{d}) ==\n", .{ w, h });
            std.debug.print("{s}\n", .{"empties  sampled  solved  budget  oom   value_div  move_div  subopt"});
            for (0..n + 1) |e| {
                const b = self.empties[e];
                if (b.sampled == 0) continue;
                std.debug.print("{d:>7} {d:>8} {d:>6} {d:>6} {d:>4} {d:>9} {d:>8} {d:>7}\n", .{
                    e, b.sampled, b.solved, b.budget_excl, b.oom_excl,
                    b.value_div, b.move_div, b.suboptimal,
                });
            }
        }
    };
}

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    const io = init.io;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    const path = args.next() orelse return error.NoArtifact;

    var games: u64 = 200;
    var seed: u64 = 20260729;
    var max_empties: u32 = 3;
    var budget: u64 = 2_000_000;
    var entry_cap: u32 = 1_000_000;
    var which: ?Policy = null;
    var ply_cap: u64 = 256;
    var pass_permille: u32 = 50;
    var settled_stop: bool = true;
    var perturb_vb_idx: ?usize = null;
    var perturb_vb_val: i8 = 0;
    var perturb_vw_idx: ?usize = null;
    var perturb_vw_val: i8 = 0;

    while (args.next()) |a| {
        if (std.mem.eql(u8, a, "--games")) {
            games = std.fmt.parseInt(u64, args.next() orelse "200", 10) catch 200;
        } else if (std.mem.eql(u8, a, "--seed")) {
            seed = std.fmt.parseInt(u64, args.next() orelse "20260729", 10) catch 20260729;
        } else if (std.mem.eql(u8, a, "--max-empties")) {
            max_empties = std.fmt.parseInt(u32, args.next() orelse "3", 10) catch 3;
        } else if (std.mem.eql(u8, a, "--budget")) {
            budget = std.fmt.parseInt(u64, args.next() orelse "2000000", 10) catch 2_000_000;
        } else if (std.mem.eql(u8, a, "--entry-cap")) {
            entry_cap = std.fmt.parseInt(u32, args.next() orelse "1000000", 10) catch 1_000_000;
        } else if (std.mem.eql(u8, a, "--ply-cap")) {
            ply_cap = std.fmt.parseInt(u64, args.next() orelse "256", 10) catch 256;
        } else if (std.mem.eql(u8, a, "--pass-prob")) {
            pass_permille = std.fmt.parseInt(u32, args.next() orelse "50", 10) catch 50;
        } else if (std.mem.eql(u8, a, "--no-settled-stop")) {
            settled_stop = false;
        } else if (std.mem.eql(u8, a, "--policy")) {
            const v = args.next() orelse "all";
            if (std.mem.eql(u8, v, "oracle")) which = .oracle;
            if (std.mem.eql(u8, v, "random")) which = .random;
            if (std.mem.eql(u8, v, "mixed")) which = .mixed;
            if (std.mem.eql(u8, v, "oracle-rt")) which = .oracle_rt;
        } else if (std.mem.eql(u8, a, "--perturb-vb")) {
            perturb_vb_idx = std.fmt.parseInt(usize, args.next() orelse "0", 10) catch 0;
            perturb_vb_val = std.fmt.parseInt(i8, args.next() orelse "0", 10) catch 0;
        } else if (std.mem.eql(u8, a, "--perturb-vw")) {
            perturb_vw_idx = std.fmt.parseInt(usize, args.next() orelse "0", 10) catch 0;
            perturb_vw_val = std.fmt.parseInt(i8, args.next() orelse "0", 10) catch 0;
        }
    }

    var dec = try artifact.load(io, std.Io.Dir.cwd(), path, gpa);
    defer dec.deinit();
    if (perturb_vb_idx) |i| {
        dec.vb[i] = perturb_vb_val;
        std.debug.print("  CALIBRATION: perturb vb[{d}] = {d}\n", .{ i, perturb_vb_val });
    }
    if (perturb_vw_idx) |i| {
        dec.vw[i] = perturb_vw_val;
        std.debug.print("  CALIBRATION: perturb vw[{d}] = {d}\n", .{ i, perturb_vw_val });
    }

    std.debug.print("\nEXP-8 PSK divergence harness\n", .{});
    std.debug.print("  artifact: {s} ({d}x{d}, {d} legal/side)\n", .{ path, dec.header.board_w, dec.header.board_h, dec.header.legal_count });
    std.debug.print("  frame: A (reachable play)\n", .{});
    std.debug.print("  games/policy: {d}   seed: {d}   max empties: {d}\n", .{ games, seed, max_empties });
    std.debug.print("  PSK exact solver budget: {d} nodes   entry cap: {d}\n", .{ budget, entry_cap });
    std.debug.print("  ply cap: {d}   settled stop: {s}\n", .{ ply_cap, if (settled_stop) "on" else "off" });

    const key = @as(usize, dec.header.board_w) * 100 + dec.header.board_h;
    switch (key) {
        202 => try runAll(2, 2, &dec, games, seed, max_empties, budget, entry_cap, ply_cap, pass_permille, settled_stop, which),
        302 => try runAll(3, 2, &dec, games, seed, max_empties, budget, entry_cap, ply_cap, pass_permille, settled_stop, which),
        303 => try runAll(3, 3, &dec, games, seed, max_empties, budget, entry_cap, ply_cap, pass_permille, settled_stop, which),
        403 => try runAll(4, 3, &dec, games, seed, max_empties, budget, entry_cap, ply_cap, pass_permille, settled_stop, which),
        404 => try runAll(4, 4, &dec, games, seed, max_empties, budget, entry_cap, ply_cap, pass_permille, settled_stop, which),
        else => return error.UnsupportedBoard,
    }
}

fn runAll(
    comptime w: usize,
    comptime h: usize,
    dec: *const artifact.Decoded,
    games: u64,
    seed: u64,
    max_empties: u32,
    budget: u64,
    entry_cap: u32,
    ply_cap: u64,
    pass_permille: u32,
    settled_stop: bool,
    which: ?Policy,
) !void {
    const gpa = std.heap.page_allocator;
    var div = Divergence(w, h).init(dec, gpa, budget, entry_cap, max_empties);
    defer div.deinit();

    const policies = if (which) |p| &[_]Policy{p} else &[_]Policy{ .oracle, .oracle_rt, .random, .mixed };
    for (policies) |p| {
        try div.runFrameA(p, games, seed +% @as(u64, @intFromEnum(p)) *% 0x1001, ply_cap, pass_permille, settled_stop);
        div.report(p);
    }
    div.reportCurve();
}
