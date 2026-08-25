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
// RETROGRADE ENGINE (ADR-0009) — successor-sweep value iteration with
// two-sided certification over the colex address space.
//
// Nodes are (position, side, passes in {0,1}) over LEGAL positions; terminals
// are settled positions and the second consecutive pass (value = area score).
// Bellman updates read FORWARD successors only (the ordinary, cross-validated
// move generator — no un-move / un-capture code exists), swept stone-count
// DESCENDING until a full sweep changes nothing (captures are back-edges, so
// this is a fixpoint, not one pass).
//
// KO/GHI (the ADR-0009 core): superko never appears in the update rule.
// Instead TWO fixpoints are computed —
//   L seeded -n (every unresolved cycle scored maximally anti-Black,
//     monotone ascent to the LEAST fixpoint), and
//   H seeded +n (pro-Black, descent to the GREATEST fixpoint).
// Where L == H the value cannot depend on any cycle rule — history-free,
// equal to the ADR-0008 fresh-start value. Where L < H the node is flagged
// KO_SENSITIVE and its fresh-start value comes from the FINISHER: a forward
// fresh-start solve (oracle.zig: full history + ko_ref rule + eye-prune)
// whose memo is pre-seeded with every certified value, so it terminates the
// moment it leaves the ko-tangled region. The L==H => exact claim is strong
// structural evidence, not a theorem (see the ADR's honesty clause); the gap
// is closed empirically by this file's battery (exhaustive ground truth at
// 2x2/3x2, anchors + spot checks at 3x3).
//
// NO EYE-PRUNE in the retrograde move loop (ADR-0009 decision 3): value
// iteration has no DFS-reopening problem, so the FULL legal move set is used.
// Coverage is total; agreement with the eye-pruned forward cross-checks
// doubles as a standing empirical test of ADR-0006's dominance claim.
// `apply_eye_prune` below is a diagnosis flag only.
//
// SIGN CONVENTIONS (ADR-0008/0009; the user has been bitten here):
//   - scores are ALWAYS Black-positive; side-to-move picks the ARRAY
//     (vb/vw), never the sign. Black maximizes, White minimizes.
//   - colour inversion: value(-pos,-side) == -value(pos,side); for the bound
//     tables the fixpoints SWAP: L(-pos,-side) == -H(pos,side).
//   - dihedral transforms never change value or sign.
//
// SCHEMA (ADR-0009 decision 4), columnar per (position, side):
//   value: i8 (UNDEF = illegal slot / unfinished ko-sensitive region)
//   dtt:   u8 (fastest optimal resolution, saturating; DTT_FAR = unknown/far)
//   flags: u8 (bit0 KO_SENSITIVE, bit1 FROM_FORWARD)
//
// Standalone: rules/colex/enumerate/oracle only; per-module `zig test` works.
// `zig run -O ReleaseFast src/retro.zig` = build + full battery at 2x2, 3x2
// (exhaustive ground truth vs pure no-memo forward) and 3x3 (anchors,
// exhaustive symmetry, spot checks, ko-sensitive region stats). Results:
// docs/research/retrograde-3x3.md.

const std = @import("std");
const expect = std.testing.expect;
const rules = @import("rules.zig");
const colexmod = @import("colex.zig");
const enumerate = @import("enumerate.zig");
const oraclemod = @import("oracle.zig");
const artifact = @import("artifact.zig");

pub const UNDEF: i8 = -128;
pub const DTT_FAR: u8 = 255;
pub const FLAG_KO_SENSITIVE: u8 = 1 << 0;
pub const FLAG_FROM_FORWARD: u8 = 1 << 1;
/// Finisher tried this root and hit the node budget (provenance; persisted
/// in checkpoints so a resumed run does not re-burn budget on it).
pub const FLAG_TRIED_SKIP: u8 = 1 << 2;

pub fn Retro(comptime w: usize, comptime h: usize) type {
    return struct {
        pub const R = rules.Rules(w, h);
        pub const X = colexmod.Indexer(w, h);
        pub const E = enumerate.Enumerator(w, h);
        pub const O = oraclemod.Oracle(w, h);
        pub const n = R.n;
        pub const Pos = R.Pos;
        pub const total: usize = @intCast(X.total);
        const N: i8 = @intCast(n);

        /// DIAGNOSIS ONLY (ADR-0009 decision 3): re-apply the ADR-0006
        /// eye-prune inside the retrograde move loop to isolate a
        /// forward/retro mismatch. The sound default is the full move set.
        pub const apply_eye_prune = false;

        /// Loud upper bound on fixpoint sweeps (same policy as MAX_LINE).
        pub const MAX_SWEEPS = 10_000;

        /// One Bellman table pair: V0 (passes=0 — the oracle value) and V1
        /// (one pass already made), per side to move. L and H are instances.
        pub const Quad = struct { b0: []i8, w0: []i8, b1: []i8, w1: []i8 };

        pub const Tables = struct {
            gpa: std.mem.Allocator,
            legal: []bool,
            settled: []bool,
            score: []i8, // area score of the position as it stands
            lo: Quad, // least fixpoint (cycles maximally anti-Black)
            hi: Quad, // greatest fixpoint (cycles maximally pro-Black)
            // final oracle columns (the ADR-0009 schema)
            vb: []i8,
            vw: []i8,
            fb: []u8,
            fw: []u8,
            db: []u8, // dtt of the V0 node, Black to move
            dw: []u8,
            db1: []u8, // dtt of the V1 node (working column for db/dw)
            dw1: []u8,
            // kill-X% rule (experimental, ABANDONED as a ko-sensitive region lever): an
            // edge whose move captures MORE than kill_pct% of the goban's
            // points is treated as terminal, scored by area at the child. 0 =
            // off (pure PSK). Set before converge().
            // CORRECTION (measured, RETRO_KILLCENSUS): an earlier comment here
            // claimed kill edges "contribute identically to L and H -> can only
            // SHRINK the ko-sensitive region". That is FALSE. A kill edge does not merely
            // ADD a history-free option; it REPLACES a move's continuation
            // (a sub-game with its own [L,H] bracket) with a frozen area score,
            // which shifts the L and H fixpoints by different amounts and can
            // WIDEN a parent's bracket. Net effect on 4x4: ko-sensitive region GREW as the
            // threshold dropped (kill 0/50/40/30% -> 21.32/21.24/21.63/25.01%),
            // because lower thresholds rewrite far more mid-game positions.
            kill_pct: u8 = 0,
            // build statistics
            sweeps: usize = 0,
            legal_count: u64 = 0,
            settled_count: u64 = 0,
            ko_sensitive_b: u64 = 0,
            ko_sensitive_w: u64 = 0,

            pub fn init(gpa: std.mem.Allocator) !Tables {
                return .{
                    .gpa = gpa,
                    .legal = try gpa.alloc(bool, total),
                    .settled = try gpa.alloc(bool, total),
                    .score = try gpa.alloc(i8, total),
                    .lo = .{
                        .b0 = try gpa.alloc(i8, total),
                        .w0 = try gpa.alloc(i8, total),
                        .b1 = try gpa.alloc(i8, total),
                        .w1 = try gpa.alloc(i8, total),
                    },
                    .hi = .{
                        .b0 = try gpa.alloc(i8, total),
                        .w0 = try gpa.alloc(i8, total),
                        .b1 = try gpa.alloc(i8, total),
                        .w1 = try gpa.alloc(i8, total),
                    },
                    .vb = try gpa.alloc(i8, total),
                    .vw = try gpa.alloc(i8, total),
                    .fb = try gpa.alloc(u8, total),
                    .fw = try gpa.alloc(u8, total),
                    .db = try gpa.alloc(u8, total),
                    .dw = try gpa.alloc(u8, total),
                    .db1 = try gpa.alloc(u8, total),
                    .dw1 = try gpa.alloc(u8, total),
                };
            }

            pub fn deinit(t: *Tables) void {
                t.gpa.free(t.legal);
                t.gpa.free(t.settled);
                t.gpa.free(t.score);
                inline for (.{ &t.lo, &t.hi }) |q| {
                    t.gpa.free(q.b0);
                    t.gpa.free(q.w0);
                    t.gpa.free(q.b1);
                    t.gpa.free(q.w1);
                }
                t.gpa.free(t.vb);
                t.gpa.free(t.vw);
                t.gpa.free(t.fb);
                t.gpa.free(t.fw);
                t.gpa.free(t.db);
                t.gpa.free(t.dw);
                t.gpa.free(t.db1);
                t.gpa.free(t.dw1);
            }
        };

        fn opt(comptime maximizing: bool, a: i8, b: i8) i8 {
            return if (maximizing) @max(a, b) else @min(a, b);
        }

        fn num_stones_of_pos(pos: *const Pos) usize {
            var c: usize = 0;
            for (pos) |v| {
                if (v != 0) c += 1;
            }
            return c;
        }

        pub fn seed(t: *Tables) void {
            t.legal_count = 0;
            t.settled_count = 0;
            for (0..total) |i| {
                var pos = X.pos_from_colex(i);
                const ok = E.is_legal(&pos);
                t.legal[i] = ok;
                t.settled[i] = false;
                t.score[i] = 0;
                t.vb[i] = UNDEF;
                t.vw[i] = UNDEF;
                t.fb[i] = 0;
                t.fw[i] = 0;
                t.db[i] = DTT_FAR;
                t.dw[i] = DTT_FAR;
                t.db1[i] = DTT_FAR;
                t.dw1[i] = DTT_FAR;
                if (!ok) continue;
                t.legal_count += 1;
                const sc = R.area_score(&pos);
                t.score[i] = sc;
                const st = R.is_settled(&pos);
                t.settled[i] = st;
                if (st) {
                    t.settled_count += 1;
                    inline for (.{ &t.lo, &t.hi }) |q| {
                        q.b0[i] = sc;
                        q.w0[i] = sc;
                        q.b1[i] = sc;
                        q.w1[i] = sc;
                    }
                } else {
                    inline for (.{ .{ &t.lo, -N }, .{ &t.hi, N } }) |pair| {
                        const q = pair[0];
                        const v = pair[1];
                        q.b0[i] = v;
                        q.w0[i] = v;
                        q.b1[i] = v;
                        q.w1[i] = v;
                    }
                }
            }
        }

        /// One Bellman sweep of a quad, stone-count DESCENDING (Gauss-Seidel:
        /// no-capture children live one layer up, so their fresh values are
        /// picked up within the same sweep). Returns the number of cell
        /// updates that changed a value.
        pub fn sweep(t: *Tables, q: *Quad) u64 {
            var changes: u64 = 0;
            var layer: usize = n + 1;
            while (layer > 0) {
                layer -= 1;
                var idx: u64 = X.layer_offset[layer];
                const stop = X.layer_offset[layer + 1];
                while (idx < stop) : (idx += 1) {
                    const i: usize = @intCast(idx);
                    if (!t.legal[i] or t.settled[i]) continue;
                    var pos = X.pos_from_colex(idx);
                    inline for (.{ @as(i8, 1), @as(i8, -1) }) |side| {
                        const maximizing = comptime (side > 0);
                        var own_alive: [n]bool = undefined;
                        if (apply_eye_prune) own_alive = R.benson_alive(&pos, side);
                        var have_move = false;
                        var m: i8 = undefined;
                        for (0..n) |p| {
                            if (pos[p] != 0) continue;
                            if (apply_eye_prune and R.is_own_eye(&pos, p, side, &own_alive)) continue;
                            const child = R.pos_from_move(&pos, side, p) catch continue;
                            const ci: usize = @intCast(X.colex_from_pos(&child));
                            // kill-X%: a move capturing > kill_pct% of the
                            // goban's points ends the game (scored by area);
                            // the child is NOT expanded, so no kill-refill cycle.
                            const cv = blk: {
                                if (t.kill_pct != 0) {
                                    var before: u32 = 0;
                                    var after: u32 = 0;
                                    for (pos) |v| {
                                        if (v == -side) before += 1;
                                    }
                                    for (child) |v| {
                                        if (v == -side) after += 1;
                                    }
                                    if ((before - after) * 100 > @as(u32, t.kill_pct) * n)
                                        break :blk R.area_score(&child);
                                }
                                break :blk if (maximizing) q.w0[ci] else q.b0[ci];
                            };
                            if (!have_move) {
                                m = cv;
                                have_move = true;
                            } else m = opt(maximizing, m, cv);
                        }
                        // V1: move or the game-ending second pass (= score now)
                        var v1: i8 = t.score[i];
                        // V0: move or pass to the opponent's V1 at this position
                        var v0: i8 = if (maximizing) q.w1[i] else q.b1[i];
                        if (have_move) {
                            v1 = opt(maximizing, m, v1);
                            v0 = opt(maximizing, m, v0);
                        }
                        const a1 = if (maximizing) q.b1 else q.w1;
                        const a0 = if (maximizing) q.b0 else q.w0;
                        if (a1[i] != v1) {
                            a1[i] = v1;
                            changes += 1;
                        }
                        if (a0[i] != v0) {
                            a0[i] = v0;
                            changes += 1;
                        }
                    }
                }
            }
            return changes;
        }

        /// Iterate both fixpoints until a full sweep changes nothing.
        /// (Chaotic iteration of a monotone map from below/above converges to
        /// the least/greatest fixpoint; the zero-change sweep is the check.)
        pub fn converge(t: *Tables) void {
            t.sweeps = 0;
            while (true) {
                const c = sweep(t, &t.lo) + sweep(t, &t.hi);
                t.sweeps += 1;
                if (c == 0) break;
                if (t.sweeps >= MAX_SWEEPS) @panic("retro: value iteration exceeded MAX_SWEEPS");
            }
        }

        /// Certify: where L == H the value is history-free; elsewhere flag
        /// KO_SENSITIVE (value UNDEF until the finisher fills it).
        pub fn finalize(t: *Tables) void {
            t.ko_sensitive_b = 0;
            t.ko_sensitive_w = 0;
            for (0..total) |i| {
                if (!t.legal[i]) continue;
                if (t.settled[i]) {
                    t.vb[i] = t.score[i];
                    t.vw[i] = t.score[i];
                    continue;
                }
                if (t.lo.b0[i] == t.hi.b0[i]) {
                    t.vb[i] = t.lo.b0[i];
                } else {
                    t.fb[i] = FLAG_KO_SENSITIVE;
                    t.ko_sensitive_b += 1;
                }
                if (t.lo.w0[i] == t.hi.w0[i]) {
                    t.vw[i] = t.lo.w0[i];
                } else {
                    t.fw[i] = FLAG_KO_SENSITIVE;
                    t.ko_sensitive_w += 1;
                }
            }
        }

        /// [L,H] bracket bounds of a game node (position, side, passes).
        /// passes >= 2 is the game-over terminal: the score, exactly.
        fn lo_from_node(t: *const Tables, idx: usize, side: i8, passes: u8) i8 {
            if (passes >= 2) return t.score[idx];
            if (passes == 0) return if (side > 0) t.lo.b0[idx] else t.lo.w0[idx];
            return if (side > 0) t.lo.b1[idx] else t.lo.w1[idx];
        }
        fn hi_from_node(t: *const Tables, idx: usize, side: i8, passes: u8) i8 {
            if (passes >= 2) return t.score[idx];
            if (passes == 0) return if (side > 0) t.hi.b0[idx] else t.hi.w0[idx];
            return if (side > 0) t.hi.b1[idx] else t.hi.w1[idx];
        }

        /// Bloom fingerprint of a single position: k hash-selected bits spread
        /// across the 64*FP_WORDS-bit fingerprint (Track B, ADR-0013). Equal
        /// positions hash identically, so if position A is in a set whose
        /// fingerprint is F, then fpDisjoint(F, fpBits(A)) is false.
        /// Contrapositive gives the sound reuse test: fpDisjoint(entry_fp,
        /// ancestor_bits) proves no ancestor is in the dependency set. Hashes
        /// the goban cells directly (no colex needed).
        fn fpBits(pos: *const Pos) O.Fp {
            var x: u64 = 1469598103934665603; // FNV-1a offset basis
            for (pos) |c| {
                x = (x ^ @as(u64, @as(u8, @bitCast(c)))) *% 1099511628211;
            }
            var out = O.fp_zero;
            const nbits: u64 = 64 * O.FP_WORDS;
            // k = 3 independent bit positions (mixed via splitmix64 steps)
            inline for (0..3) |_| {
                x ^= x >> 30;
                x *%= 0xbf58476d1ce4e5b9;
                x ^= x >> 27;
                const b = x % nbits;
                out[@intCast(b / 64)] |= @as(u64, 1) << @as(u6, @intCast(b % 64));
            }
            return out;
        }

        fn countStones(pos: *const Pos) u8 {
            var c: u8 = 0;
            for (pos) |v| {
                if (v != 0) c += 1;
            }
            return c;
        }

        fn fpOr(a: O.Fp, b: O.Fp) O.Fp {
            var out: O.Fp = undefined;
            inline for (0..O.FP_WORDS) |i| out[i] = a[i] | b[i];
            return out;
        }

        /// True iff the two fingerprints share NO set bit (sound: proves the
        /// underlying sets are disjoint; false negatives from bit-collisions
        /// only cost reuse, never correctness).
        fn fpDisjoint(a: O.Fp, b: O.Fp) bool {
            inline for (0..O.FP_WORDS) |i| {
                if (a[i] & b[i] != 0) return false;
            }
            return true;
        }

        /// OR `add` into the sparse dependency fingerprint for (idx, side).
        /// No-op unless deps is on. OOM panics (same policy as the journal).
        fn depAccumulate(ctx: *O.Ctx, idx: usize, to_move: i8, add: O.Fp) void {
            if (!ctx.deps) return;
            const m = ctx.dep_map.?;
            const k = O.depKey(idx, to_move);
            const g = m.get(k) orelse O.fp_zero;
            m.put(k, fpOr(g, add)) catch @panic("retro: dep_map allocation failed");
        }

        /// Bracket-guided fail-soft alpha-beta (ADR-0010): the finisher's
        /// forward solve with [L,H] cutoffs at EVERY node and bracket-ordered
        /// edges. Same graph, terminals, eye-prune, superko and ko_ref
        /// discipline as O.solve; the brackets add history-free cuts inside
        /// the ko-sensitive region, where certified-memo cuts cannot fire (Finding 6).
        pub fn ab_solve(
            t: *const Tables,
            ctx: *O.Ctx,
            pos: *const Pos,
            to_move: i8,
            passes: u8,
            alpha0: i8,
            beta0: i8,
            hist: *O.History,
            anc_or: O.Fp, // OR of fpBits over this node's strict path-ancestors
        ) error{Budget}!O.Result {
            ctx.nodes += 1;
            if (ctx.budget != 0 and ctx.nodes > ctx.budget) return error.Budget;
            const idx: usize = @intCast(X.colex_from_pos(pos));
            // fingerprints (Track B) cost O(FP_WORDS) per node, so compute them
            // ONLY when deps is on; sound/reuse modes pay nothing. The sound
            // shrink: a position with more stones than dep_layer_max can never
            // be a real ancestor, so it contributes nothing to any dependency
            // set (its fingerprint stays empty), which keeps the fingerprint
            // sparse and unsaturated.
            const in_dep = ctx.deps and countStones(pos) <= ctx.dep_layer_max;
            const self_fp = if (in_dep) fpBits(pos) else O.fp_zero;
            if (passes >= 2 or t.settled[idx]) return .{ .value = t.score[idx], .ko_ref = O.KO_CLEAN, .fp = self_fp };

            // bracket cut: [lo,hi] holds under ANY arrival history -> KO_CLEAN
            // (conditional assumption; ctx.brackets toggles it off)
            if (ctx.brackets) {
                const blo = lo_from_node(t, idx, to_move, passes);
                const bhi = hi_from_node(t, idx, to_move, passes);
                if (blo == bhi) return .{ .value = blo, .ko_ref = O.KO_CLEAN, .fp = self_fp };
                if (bhi <= alpha0) return .{ .value = bhi, .ko_ref = O.KO_CLEAN, .fp = self_fp };
                if (blo >= beta0) return .{ .value = blo, .ko_ref = O.KO_CLEAN, .fp = self_fp };
            }

            const d = hist.len - 1;
            const hashable = ctx.memo and passes == 0;
            // fingerprint of ancestors INCLUDING this node (passed to children)
            const anc_or_child = if (ctx.deps) fpOr(anc_or, self_fp) else O.fp_zero;
            if (hashable) {
                // exact memo hit. Legacy (deps off): unconditional reuse — the
                // unsound ko_ref>=d path. deps on (Track B): reuse ONLY when the
                // entry's dependency fingerprint shares no bits with the current
                // ancestors, proving no ancestor is in the dependency set.
                if (to_move > 0) {
                    if (ctx.cb[idx]) {
                        if (!ctx.deps) return .{ .value = ctx.vb[idx], .ko_ref = O.KO_CLEAN, .fp = self_fp };
                        const dep = ctx.dep_map.?.get(O.depKey(idx, to_move)) orelse O.fp_zero;
                        if (fpDisjoint(dep, anc_or)) return .{ .value = ctx.vb[idx], .ko_ref = O.KO_CLEAN, .fp = dep };
                    }
                } else {
                    if (ctx.cw[idx]) {
                        if (!ctx.deps) return .{ .value = ctx.vw[idx], .ko_ref = O.KO_CLEAN, .fp = self_fp };
                        const dep = ctx.dep_map.?.get(O.depKey(idx, to_move)) orelse O.fp_zero;
                        if (fpDisjoint(dep, anc_or)) return .{ .value = ctx.vw[idx], .ko_ref = O.KO_CLEAN, .fp = dep };
                    }
                }
            }

            const maximizing = to_move > 0;
            var alpha = alpha0;
            var beta = beta0;
            // BOUNDS memo read (per-root, ko_ref-clean like the exact memo):
            // stored fail-soft bounds cut or narrow the window — this is what
            // lets one null-window (MTD) probe reuse the previous probe's work,
            // and is where the finisher's reuse actually lives. Under `deps`
            // (Track B) a stored bound is honoured ONLY when its dependency
            // fingerprint is disjoint from the current ancestors (same
            // soundness argument as the exact memo); the dep fingerprint is
            // shared per (idx,side) and covers both bounds' dependencies.
            if (hashable) {
                const lbs = if (to_move > 0) ctx.lbb else ctx.lbw;
                const ubs = if (to_move > 0) ctx.ubb else ctx.ubw;
                const dep = if (!ctx.deps) O.fp_zero else (ctx.dep_map.?.get(O.depKey(idx, to_move)) orelse O.fp_zero);
                if (!ctx.deps or fpDisjoint(dep, anc_or)) {
                    if (lbs) |lb| {
                        if (lb[idx] >= beta) return .{ .value = lb[idx], .ko_ref = O.KO_CLEAN, .fp = dep };
                        if (lb[idx] > alpha) alpha = lb[idx];
                    }
                    if (ubs) |ub| {
                        if (ub[idx] <= alpha) return .{ .value = ub[idx], .ko_ref = O.KO_CLEAN, .fp = dep };
                        if (ub[idx] < beta) beta = ub[idx];
                    }
                }
            }
            // exactness / bound classification is judged against the window
            // as ENTERED after narrowing (a fail against the narrowed window
            // must not be stored as exact)
            const a_entry = alpha;
            const b_entry = beta;
            var best: i8 = if (maximizing) -127 else 127;
            var ko_ref: usize = O.KO_CLEAN;
            var sub_fp: O.Fp = self_fp; // this node + everything its value touches

            // gather legal edges (goban moves + pass), bracket-scored
            const Edge = struct { child: Pos, order: i16, pass: bool };
            var edges: [n + 1]Edge = undefined;
            var ne: usize = 0;
            const own_alive = R.benson_alive(pos, to_move); // ADR-0006 eye-prune
            for (0..n) |p| {
                if (pos[p] != 0) continue;
                if (R.is_own_eye(pos, p, to_move, &own_alive)) continue;
                const child = R.pos_from_move(pos, to_move, p) catch continue;
                if (hist.repeatsIndex(&child)) |j| {
                    ctx.saw_ban = true;
                    if (j < ko_ref) ko_ref = j;
                    if (ctx.deps and countStones(&child) <= ctx.dep_layer_max)
                        sub_fp = fpOr(sub_fp, fpBits(&child)); // ban target is a dependency
                    continue;
                }
                const ci: usize = @intCast(X.colex_from_pos(&child));
                const s = @as(i16, lo_from_node(t, ci, -to_move, 0)) + @as(i16, hi_from_node(t, ci, -to_move, 0));
                edges[ne] = .{ .child = child, .order = s, .pass = false };
                ne += 1;
            }
            {
                const s = @as(i16, lo_from_node(t, idx, -to_move, passes + 1)) + @as(i16, hi_from_node(t, idx, -to_move, passes + 1));
                edges[ne] = .{ .child = pos.*, .order = s, .pass = true };
                ne += 1;
            }
            // best-first: descending order for Black, ascending for White
            var si: usize = 1;
            while (si < ne) : (si += 1) {
                const e = edges[si];
                var j = si;
                while (j > 0 and (if (maximizing) edges[j - 1].order < e.order else edges[j - 1].order > e.order)) : (j -= 1) {
                    edges[j] = edges[j - 1];
                }
                edges[j] = e;
            }

            for (edges[0..ne]) |*e| {
                var r: O.Result = undefined;
                if (e.pass) {
                    r = try ab_solve(t, ctx, pos, -to_move, passes + 1, alpha, beta, hist, anc_or_child);
                } else {
                    hist.push(&e.child);
                    r = try ab_solve(t, ctx, &e.child, -to_move, 0, alpha, beta, hist, anc_or_child);
                    hist.pop();
                }
                if (r.ko_ref < ko_ref) ko_ref = r.ko_ref;
                if (ctx.deps) sub_fp = fpOr(sub_fp, r.fp); // fold child's dependency set into ours
                if (maximizing) {
                    if (r.value > best) best = r.value;
                    if (best > alpha) alpha = best;
                } else {
                    if (r.value < best) best = r.value;
                    if (best < beta) beta = best;
                }
                if (alpha >= beta) break; // cutoff: result is a bound
            }

            // memo write, ko_ref-clean only: exact if inside the entry
            // window, otherwise a fail-soft BOUND into the bounds memo
            if (hashable and ctx.memo_writes and ko_ref >= d) {
                // Track B: the entry's dependency fingerprint is shared per
                // (idx,side) across the exact value and both bounds, OR-ed into
                // the sparse map so it soundly covers every dependency
                // contributing to the slot. Accumulated only at recorded writes;
                // the per-root map clear (runRoot / seedCtx) undoes it exactly.
                if (best > a_entry and best < b_entry) {
                    ctx.record(idx, to_move);
                    depAccumulate(ctx, idx, to_move, sub_fp);
                    if (to_move > 0) {
                        ctx.vb[idx] = best;
                        ctx.cb[idx] = true;
                    } else {
                        ctx.vw[idx] = best;
                        ctx.cw[idx] = true;
                    }
                } else if (best >= b_entry) {
                    const lbs = if (to_move > 0) ctx.lbb else ctx.lbw;
                    if (lbs) |lb| {
                        if (best > lb[idx]) {
                            ctx.record_bound(idx, to_move);
                            depAccumulate(ctx, idx, to_move, sub_fp);
                            lb[idx] = best;
                        }
                    }
                } else {
                    const ubs = if (to_move > 0) ctx.ubb else ctx.ubw;
                    if (ubs) |ub| {
                        if (best < ub[idx]) {
                            ctx.record_bound(idx, to_move);
                            depAccumulate(ctx, idx, to_move, sub_fp);
                            ub[idx] = best;
                        }
                    }
                }
            }
            return .{ .value = best, .ko_ref = ko_ref, .fp = sub_fp };
        }

        /// Exact fresh-start value of a root by NULL-WINDOW binary search
        /// over its own [L,H] bracket (MTD-style). A wide window makes
        /// bracket cutoffs impotent exactly where brackets are wide (the
        /// deep-ko-sensitive region ko tangles — measured at 4x4: aspiration search
        /// blew 20M+ nodes where null-window probes cut everywhere). Each
        /// probe asks "value >= mid?" with a zero-width window, halving the
        /// bracket; ~log2(H-L) probes pin the value. The per-root memo is
        /// SHARED across probes (exact clean values from one probe cut the
        /// next; all probes share this root's fresh-start context) and is
        /// reverted once per root by the caller's journal.
        pub fn ab_value_from_root(t: *const Tables, ctx: *O.Ctx, pos: *const Pos, to_move: i8, hist: *O.History) error{Budget}!i8 {
            const idx: usize = @intCast(X.colex_from_pos(pos));
            var lo = lo_from_node(t, idx, to_move, 0);
            var hi = hi_from_node(t, idx, to_move, 0);
            while (lo < hi) {
                const mid = lo + @divTrunc(hi - lo + 1, 2);
                hist.reset();
                hist.push(pos);
                ctx.saw_ban = false;
                const r = try ab_solve(t, ctx, pos, to_move, 0, mid - 1, mid, hist, O.fp_zero);
                if (r.value >= mid) lo = r.value else hi = r.value;
            }
            return lo;
        }

        // ── single-ko O(1) solver (B32) ───────────────────────────────────

        /// Check if placing `colour` at `p` is a basic ko capture.
        /// Returns the captured stone's cell if so, null otherwise.
        fn isKoCapture(pos: *const Pos, p: usize, colour: i8) ?usize {
            if (pos[p] != 0) return null;
            const next = R.pos_from_move(pos, colour, p) catch return null;
            // exactly 1 opponent stone captured
            var opp_before: u8 = 0;
            var captured_cell: ?usize = null;
            for (0..n) |i| {
                if (pos[i] == -colour) opp_before += 1;
                if (pos[i] == -colour and next[i] == 0) captured_cell = i;
            }
            if (captured_cell == null) return null;
            // the capturing stone has exactly 1 liberty
            var nb: [4]usize = undefined;
            const nc = R.neighbors(p, &nb);
            var libs: u8 = 0;
            for (nb[0..nc]) |q| {
                if (next[q] == 0) libs += 1;
            }
            if (libs != 1) return null;
            return captured_cell;
        }

        /// Count independent ko captures on the goban using the
        /// same union-find logic as ko_census.zig.
        fn countKoClusters(pos: *const Pos) u8 {
            var points: [2 * n]struct { cell: u8, cap: u8 } = undefined;
            var np: u8 = 0;
            for (0..n) |p| {
                inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
                    if (isKoCapture(pos, p, colour)) |cap| {
                        if (np >= 2 * n) break;
                        points[np] = .{ .cell = @intCast(p), .cap = @intCast(cap) };
                        np += 1;
                    }
                }
            }
            if (np == 0) return 0;

            // union-find on 1-neighborhood overlap
            var masks: [2 * n]u32 = undefined;
            for (0..np) |i| {
                var mask: u32 = 0;
                mask |= @as(u32, 1) << @as(u5, @intCast(points[i].cell));
                mask |= @as(u32, 1) << @as(u5, @intCast(points[i].cap));
                var nb: [4]usize = undefined;
                const c1 = R.neighbors(points[i].cell, &nb);
                for (nb[0..c1]) |q| mask |= @as(u32, 1) << @as(u5, @intCast(q));
                const c2 = R.neighbors(points[i].cap, &nb);
                for (nb[0..c2]) |q| mask |= @as(u32, 1) << @as(u5, @intCast(q));
                masks[i] = mask;
            }
            var parent: [2 * n]u8 = undefined;
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
            return @popCount(roots);
        }

        /// Find the single ko-capture cell for `side` at `pos`.
        /// Returns (capture_cell, pos_after_capture), or null if not
        /// single-ko or no capture is available for `side`.
        fn singleKoCapture(pos: *const Pos, side: i8) ?struct { cell: usize, after: Pos } {
            var found: ?usize = null;
            for (0..n) |p| {
                if (isKoCapture(pos, p, side)) |_| {
                    if (found != null) return null; // > 1 ko capture
                    found = p;
                }
            }
            const p = found orelse return null;
            const after = R.pos_from_move(pos, side, p) catch return null;
            return .{ .cell = p, .after = after };
        }

        /// Exact value of a single-ko fresh-start position (B32).
        ///
        /// Under PSK fresh-start, the ko is a ONE-SHOT capture: the root
        /// position is always banned, so the recapture is permanently illegal.
        /// The value is:
        ///   V = opt( best_nonko_move_value,  value_after_ko_capture )
        /// where opt = max for Black, min for White, and both values come
        /// from the certified (L==H) table. The post-capture value is
        /// computed with the recapture move excluded.
        ///
        /// Returns null when the position is NOT single-ko or a non-ko
        /// move leads to an uncertified position (caller falls back to
        /// full forward search).
        pub fn solveSingleKo(t: *const Tables, pos: *const Pos, side: i8) ?i8 {
            // Env-var kill-switch for correctness comparison.
            if (std.c.getenv("RETRO_NOSINGLEKO") != null) return null;

            // Must be exactly one independent ko cluster
            if (countKoClusters(pos) != 1) return null;

            // Find the ko capture
            const kc = singleKoCapture(pos, side) orelse return null;

            const idx: usize = @intCast(X.colex_from_pos(pos));
            const cap_idx: usize = @intCast(X.colex_from_pos(&kc.after));
            const maximizing = side > 0;
            const opp_side = -side;

            // ── V_other: best value from non-ko moves (including pass) ──
            // For Black: max over child positions where opponent moves next
            // For White: min over child positions where opponent moves next
            var best_other: i8 = -127;
            var any: bool = false;

            // pass option
            const pass_val = if (maximizing) t.lo.w1[idx] else t.hi.b1[idx];
            const pass_cert = if (maximizing) (t.lo.w1[idx] == t.hi.w1[idx]) else (t.lo.b1[idx] == t.hi.b1[idx]);
            if (pass_cert) {
                best_other = pass_val;
                any = true;
            } else {
                return null;
            }

            const own_alive = R.benson_alive(pos, side);
            for (0..n) |p| {
                if (pos[p] != 0) continue;
                if (p == kc.cell) continue; // skip the ko capture
                if (R.is_own_eye(pos, p, side, &own_alive)) continue;
                const child = R.pos_from_move(pos, side, p) catch continue;
                const ci: usize = @intCast(X.colex_from_pos(&child));
                if (maximizing) {
                    if (t.lo.w0[ci] == t.hi.w0[ci]) {
                        if (!any or t.lo.w0[ci] > best_other) best_other = t.lo.w0[ci];
                        any = true;
                    } else {
                        return null;
                    }
                } else {
                    if (t.lo.b0[ci] == t.hi.b0[ci]) {
                        if (!any or t.lo.b0[ci] < best_other) best_other = t.lo.b0[ci];
                        any = true;
                    } else {
                        return null;
                    }
                }
            }
            if (!any) return null;
            const v_other = best_other;

            // ── V_after_capture: value from post-capture position,
            //    with the ko recapture EXCLUDED (PSK bans it). ──
            // The opponent moves next from pos_after_capture.
            var best_cap: i8 = -127;
            var any_cap: bool = false;
            const opp_max = opp_side > 0;

            // pass from post-capture position
            const pass_cap_val = if (opp_max) t.lo.w1[cap_idx] else t.hi.b1[cap_idx];
            const pass_cap_cert = if (opp_max) (t.lo.w1[cap_idx] == t.hi.w1[cap_idx]) else (t.lo.b1[cap_idx] == t.hi.b1[cap_idx]);
            if (pass_cap_cert) {
                best_cap = pass_cap_val;
                any_cap = true;
            } else {
                return null;
            }

            // Find the ko recapture cell from post-capture (would recreate pos)
            const recapture_cell: ?usize = blk: {
                for (0..n) |p| {
                    if (isKoCapture(&kc.after, p, opp_side)) |_| {
                        const recaptured = R.pos_from_move(&kc.after, opp_side, p) catch continue;
                        if (std.mem.eql(i8, &recaptured, pos)) break :blk p;
                    }
                }
                break :blk null;
            };

            const own_alive2 = R.benson_alive(&kc.after, opp_side);
            for (0..n) |p| {
                if (kc.after[p] != 0) continue;
                if (recapture_cell != null and p == recapture_cell.?) continue; // EXCLUDE recapture
                if (R.is_own_eye(&kc.after, p, opp_side, &own_alive2)) continue;
                const child = R.pos_from_move(&kc.after, opp_side, p) catch continue;
                const ci: usize = @intCast(X.colex_from_pos(&child));
                if (opp_max) {
                    if (t.lo.w0[ci] == t.hi.w0[ci]) {
                        if (!any_cap or t.lo.w0[ci] > best_cap) best_cap = t.lo.w0[ci];
                        any_cap = true;
                    } else {
                        return null;
                    }
                } else {
                    if (t.lo.b0[ci] == t.hi.b0[ci]) {
                        if (!any_cap or t.lo.b0[ci] < best_cap) best_cap = t.lo.b0[ci];
                        any_cap = true;
                    } else {
                        return null;
                    }
                }
            }
            if (!any_cap) return null;
            const v_after_cap = best_cap;

            // One-shot ko under PSK: V = opt(V_other, V_after_capture)
            return if (maximizing)
                @max(v_other, v_after_cap)
            else
                @min(v_other, v_after_cap);
        }

        pub const FinishStats = struct {
            solved: u64 = 0, // orbit representatives actually solved
            filled: u64 = 0, // slots filled (incl. orbit propagation)
            budget_skipped: u64 = 0, // orbits skipped on budget
            nodes: u64 = 0,
            max_nodes: u64 = 0,
            bracket_fail: u64 = 0, // finisher value outside [L, H] (want 0)
            orbit_clash: u64 = 0, // propagation disagreed with a filled slot (want 0)
            single_ko: u64 = 0, // solved via single-ko O(1) shortcut (B32)
        };

        /// Resolve the KO_SENSITIVE ko-sensitive region: forward fresh-start solve with
        /// the memo PRE-SEEDED with every certified value (marked clean), so
        /// the search terminates at the certified frontier of the ko tangle.
        ///
        /// Each root gets a FRESH copy of the certified baseline: an interior
        /// fresh-start memo value is NOT valid under another root's history
        /// (the ADR-0008 GHI ko-sensitive region) — carrying ordinary memo writes across
        /// roots was measured ORDER-DEPENDENT (asymmetric tables) at 2x2.
        /// Only ONE representative per symmetry orbit is solved; the orbit is
        /// filled by the proven transforms (dihedral: same value; colour
        /// inversion: negate and swap side) — order-independent and ~8-16x
        /// cheaper. Any disagreement with an already-filled slot is counted
        /// (orbit_clash, want 0).
        ///
        /// `bracketed` picks the root solver: the ADR-0010 bracket-guided
        /// alpha-beta (default) or the plain ADR-0009 minimax finisher (kept
        /// as the engine-vs-engine cross-check; both must produce identical
        /// tables where both complete).
        pub fn finish(t: *Tables, gpa: std.mem.Allocator, budget: u64, bracketed: bool) !FinishStats {
            return finishProgress(t, gpa, budget, bracketed, 0, true, false);
        }

        /// finish() with a progress heartbeat (report every `progress_every`
        /// solved-or-skipped orbit reps; 0 = silent), layers deepest-first.
        /// `memo_writes` false = SOUND mode (Track A, ADR-0013): no cross-branch
        /// memo/bounds reuse — the `ko_ref >= d` GHI shortcut is disabled, so
        /// ko-sensitive values are trustworthy but the search loses the reuse
        /// accelerant (slower). true = the fast (unsound) legacy path.
        pub fn finishProgress(t: *Tables, gpa: std.mem.Allocator, budget: u64, bracketed: bool, progress_every: u64, memo_writes: bool, deps: bool) !FinishStats {
            var f = try Finisher.init(t, gpa, budget, bracketed, progress_every, memo_writes, deps);
            defer f.deinit();
            var layer: usize = n + 1;
            while (layer > 0) {
                layer -= 1;
                f.runLayer(layer);
            }
            return f.st;
        }

        /// The ko-sensitive finisher as a resumable, layer-at-a-time engine so a
        /// driver can CHECKPOINT between layers (hours of 4x4+ work must
        /// survive interruption). Layers are processed deepest-first by the
        /// callers: ko-sensitive region near the terminal wall is cheap (certified
        /// frontier adjacent); opening roots are the expensive/hopeless tail.
        /// Order-independent by construction: every root starts from the same
        /// certified-only baseline (journal revert; the Finding-2 discipline)
        /// and orbits never cross layers. Roots already carrying
        /// FLAG_FROM_FORWARD or FLAG_TRIED_SKIP (e.g. from a loaded
        /// checkpoint) are not re-attempted.
        pub const Finisher = struct {
            t: *Tables,
            gpa: std.mem.Allocator,
            budget: u64,
            bracketed: bool,
            progress_every: u64,
            ctx: O.Ctx,
            base_vb: []i8,
            base_vw: []i8,
            base_cb: []bool,
            base_cw: []bool,
            tried_b: []bool,
            tried_w: []bool,
            hist: *O.History,
            journal: std.ArrayList(u32) = .empty,
            dep_map: O.DepMap = undefined, // Track B; init'd iff deps
            st: FinishStats = .{},
            start_ms: u64,
            next_report: u64,

            pub fn init(t: *Tables, gpa: std.mem.Allocator, budget: u64, bracketed: bool, progress_every: u64, memo_writes: bool, deps: bool) !Finisher {
                var f = Finisher{
                    .t = t,
                    .gpa = gpa,
                    .budget = budget,
                    .bracketed = bracketed,
                    .progress_every = progress_every,
                    .ctx = .{
                        .vb = try gpa.alloc(i8, total),
                        .vw = try gpa.alloc(i8, total),
                        .cb = try gpa.alloc(bool, total),
                        .cw = try gpa.alloc(bool, total),
                        .memo = true,
                        .memo_writes = memo_writes,
                        .deps = deps,
                    },
                    .base_vb = try gpa.alloc(i8, total),
                    .base_vw = try gpa.alloc(i8, total),
                    .base_cb = try gpa.alloc(bool, total),
                    .base_cw = try gpa.alloc(bool, total),
                    .tried_b = try gpa.alloc(bool, total),
                    .tried_w = try gpa.alloc(bool, total),
                    .hist = try gpa.create(O.History),
                    .start_ms = nowMs(),
                    .next_report = progress_every,
                };
                f.hist.* = .{};
                // per-root bounds memo (what makes null-window probes
                // incremental); vacuous sentinels, journal-reverted per root
                f.ctx.lbb = try gpa.alloc(i8, total);
                f.ctx.ubb = try gpa.alloc(i8, total);
                f.ctx.lbw = try gpa.alloc(i8, total);
                f.ctx.ubw = try gpa.alloc(i8, total);
                @memset(f.ctx.lbb.?, -127);
                @memset(f.ctx.ubb.?, 127);
                @memset(f.ctx.lbw.?, -127);
                @memset(f.ctx.ubw.?, 127);
                // Track B dependency fingerprints: sparse map (only the current
                // root's live entries), cleared per root. Certified seeds have
                // no entry => empty dependency set => always reuse.
                // NOTE: the self-pointer f.ctx.dep_map = &f.dep_map must be set
                // in runLayer, not here — init returns Finisher BY VALUE, so a
                // pointer into this local `f` would dangle (same reason journal
                // is wired in runLayer).
                if (deps) f.dep_map = O.DepMap.init(gpa);
                // The certified-only baseline. NOTE: values filled by an
                // earlier finisher pass or a loaded checkpoint carry
                // FLAG_FROM_FORWARD — they are fresh-start values of
                // ko-sensitive positions and MUST NOT seed the memo
                // (Finding 2); only certified (flag-free) values may.
                @memcpy(f.base_vb, t.vb);
                @memcpy(f.base_vw, t.vw);
                for (0..total) |i| {
                    f.base_cb[i] = t.legal[i] and t.vb[i] != UNDEF and t.fb[i] & (FLAG_KO_SENSITIVE | FLAG_FROM_FORWARD) == 0;
                    f.base_cw[i] = t.legal[i] and t.vw[i] != UNDEF and t.fw[i] & (FLAG_KO_SENSITIVE | FLAG_FROM_FORWARD) == 0;
                }
                @memset(f.tried_b, false);
                @memset(f.tried_w, false);
                // per-root baseline reset via undo JOURNAL: initialize the
                // memo ONCE; after each root revert only the touched slots
                // (a full memcpy per root is O(total) — prohibitive at 43M).
                @memcpy(f.ctx.vb, f.base_vb);
                @memcpy(f.ctx.vw, f.base_vw);
                @memcpy(f.ctx.cb, f.base_cb);
                @memcpy(f.ctx.cw, f.base_cw);
                return f;
            }

            pub fn deinit(f: *Finisher) void {
                f.gpa.free(f.ctx.vb);
                f.gpa.free(f.ctx.vw);
                f.gpa.free(f.ctx.cb);
                f.gpa.free(f.ctx.cw);
                f.gpa.free(f.ctx.lbb.?);
                f.gpa.free(f.ctx.ubb.?);
                f.gpa.free(f.ctx.lbw.?);
                f.gpa.free(f.ctx.ubw.?);
                if (f.ctx.dep_map != null) f.dep_map.deinit();
                f.gpa.free(f.base_vb);
                f.gpa.free(f.base_vw);
                f.gpa.free(f.base_cb);
                f.gpa.free(f.base_cw);
                f.gpa.free(f.tried_b);
                f.gpa.free(f.tried_w);
                f.gpa.destroy(f.hist);
                f.journal.deinit(f.gpa);
            }

            pub fn runLayer(f: *Finisher, layer: usize) void {
                const t = f.t;
                f.ctx.journal = &f.journal;
                f.ctx.journal_gpa = f.gpa;
                if (f.ctx.deps) f.ctx.dep_map = &f.dep_map; // final location (init returns by value)
                var li: u64 = X.layer_offset[layer];
                const li_stop = X.layer_offset[layer + 1];
                while (li < li_stop) : (li += 1) {
                    const i: usize = @intCast(li);
                    if (!t.legal[i]) continue;
                    if (t.fb[i] & FLAG_KO_SENSITIVE == 0 and t.fw[i] & FLAG_KO_SENSITIVE == 0) continue;
                    var pos = X.pos_from_colex(i);
                    inline for (.{ @as(i8, 1), @as(i8, -1) }) |side| {
                        const flags = if (side > 0) t.fb else t.fw;
                        const tried = if (side > 0) f.tried_b else f.tried_w;
                        if (flags[i] & FLAG_KO_SENSITIVE != 0 and
                            flags[i] & (FLAG_FROM_FORWARD | FLAG_TRIED_SKIP) == 0 and !tried[i])
                        {
                            f.runRoot(i, &pos, side, layer);
                        }
                    }
                }
            }

            fn runRoot(f: *Finisher, i: usize, pos: *Pos, side: i8, layer: usize) void {
                const t = f.t;
                f.journal.clearRetainingCapacity();
                // Track B: the dependency fingerprints are per-root; drop the
                // previous root's live entries (base state = empty set). The
                // root has `layer` stones, and (deepest-layer-first) every real
                // ancestor has <= layer stones, so that is the sound shrink
                // threshold for this root's dependency sets.
                if (f.ctx.dep_map) |m| m.clearRetainingCapacity();
                // NOTE: a stone-count shrink of the dependency set (dep_layer_max
                // = layer) was tried and PROVEN UNSOUND (RETRO_DEPSVAL diverged):
                // deeper ko-sensitive region positions are re-searched, not leaves, so real
                // ancestors are NOT bounded by the root's stone count. Left at
                // 255 (no shrink) -- the full-subtree dependency set is exact.
                f.ctx.dep_layer_max = 255;
                f.ctx.nodes = 0;
                f.ctx.budget = f.budget;
                const solved: error{Budget}!i8 = if (solveSingleKo(t, pos, side)) |v| blk: {
                    f.st.single_ko += 1;
                    break :blk v;
                } else if (f.bracketed)
                    ab_value_from_root(t, &f.ctx, pos, side, f.hist)
                else
                    O.value_from_root(&f.ctx, pos, side, f.hist);
                // revert this root's memo writes (success or budget-abort);
                // bound entries reset both bounds of the slot to vacuous
                for (f.journal.items) |entry| {
                    const ji: usize = @intCast(entry & 0x3FFF_FFFF);
                    const white = entry & (1 << 31) != 0;
                    if (entry & (1 << 30) != 0) {
                        if (white) {
                            f.ctx.lbw.?[ji] = -127;
                            f.ctx.ubw.?[ji] = 127;
                        } else {
                            f.ctx.lbb.?[ji] = -127;
                            f.ctx.ubb.?[ji] = 127;
                        }
                    } else if (white) {
                        f.ctx.vw[ji] = f.base_vw[ji];
                        f.ctx.cw[ji] = f.base_cw[ji];
                    } else {
                        f.ctx.vb[ji] = f.base_vb[ji];
                        f.ctx.cb[ji] = f.base_cb[ji];
                    }
                }
                if (solved) |v| {
                    f.st.solved += 1;
                    f.st.nodes += f.ctx.nodes;
                    if (f.ctx.nodes > f.st.max_nodes) f.st.max_nodes = f.ctx.nodes;
                    const lo0 = if (side > 0) t.lo.b0[i] else t.lo.w0[i];
                    const hi0 = if (side > 0) t.hi.b0[i] else t.hi.w0[i];
                    if (v < lo0 or v > hi0) f.st.bracket_fail += 1;
                    inline for (0..E.num_syms) |k| {
                        const tp = transformed(pos, &E.sym_perms[k], 1);
                        const ti: usize = @intCast(X.colex_from_pos(&tp));
                        const ip = transformed(pos, &E.sym_perms[k], -1);
                        const ii: usize = @intCast(X.colex_from_pos(&ip));
                        const same_v = if (side > 0) t.vb else t.vw;
                        const same_f = if (side > 0) t.fb else t.fw;
                        const same_t = if (side > 0) f.tried_b else f.tried_w;
                        const swap_v = if (side > 0) t.vw else t.vb;
                        const swap_f = if (side > 0) t.fw else t.fb;
                        const swap_t = if (side > 0) f.tried_w else f.tried_b;
                        if (same_v[ti] == UNDEF) {
                            same_v[ti] = v;
                            f.st.filled += 1;
                        } else if (same_v[ti] != v) f.st.orbit_clash += 1;
                        same_f[ti] |= FLAG_FROM_FORWARD;
                        same_t[ti] = true;
                        if (swap_v[ii] == UNDEF) {
                            swap_v[ii] = -v;
                            f.st.filled += 1;
                        } else if (swap_v[ii] != -v) f.st.orbit_clash += 1;
                        swap_f[ii] |= FLAG_FROM_FORWARD;
                        swap_t[ii] = true;
                    }
                    if (f.progress_every != 0 and f.st.solved + f.st.budget_skipped >= f.next_report) {
                        f.next_report += f.progress_every;
                        std.debug.print("  finisher progress: solved={d} skipped={d} nodes={d} max/root={d} ({d} s)\n", .{
                            f.st.solved, f.st.budget_skipped, f.st.nodes, f.st.max_nodes, (nowMs() - f.start_ms) / 1000,
                        });
                    }
                } else |_| {
                    f.st.budget_skipped += 1;
                    std.debug.print("  finisher BUDGET-SKIP #{d}: layer={d} root-idx={d} side={d} after {d} s\n", .{
                        f.st.budget_skipped, layer, i, side, (nowMs() - f.start_ms) / 1000,
                    });
                    // mark the whole orbit tried (both in-memory and, via
                    // FLAG_TRIED_SKIP, in any checkpoint written later)
                    inline for (0..E.num_syms) |k| {
                        const tp = transformed(pos, &E.sym_perms[k], 1);
                        const ti: usize = @intCast(X.colex_from_pos(&tp));
                        const ip = transformed(pos, &E.sym_perms[k], -1);
                        const ii: usize = @intCast(X.colex_from_pos(&ip));
                        if (side > 0) {
                            f.tried_b[ti] = true;
                            t.fb[ti] |= FLAG_TRIED_SKIP;
                            f.tried_w[ii] = true;
                            t.fw[ii] |= FLAG_TRIED_SKIP;
                        } else {
                            f.tried_w[ti] = true;
                            t.fw[ti] |= FLAG_TRIED_SKIP;
                            f.tried_b[ii] = true;
                            t.fb[ii] |= FLAG_TRIED_SKIP;
                        }
                    }
                }
            }
        };

        /// DTT (ADR-0009 schema): fastest optimal resolution — plies to a
        /// terminal when both sides play only value-optimal moves and, among
        /// those, cooperate on speed. Monotone-decreasing min-sweeps over the
        /// FINAL values; nodes whose optimal lines run through uncertified V1
        /// slots stay DTT_FAR (best-effort, documented).
        pub fn dttPass(t: *Tables) void {
            for (0..total) |i| {
                if (t.legal[i] and t.settled[i]) {
                    t.db[i] = 0;
                    t.dw[i] = 0;
                    t.db1[i] = 0;
                    t.dw1[i] = 0;
                }
            }
            var rounds: usize = 0;
            while (true) {
                var changed: u64 = 0;
                var layer: usize = n + 1;
                while (layer > 0) {
                    layer -= 1;
                    var idx: u64 = X.layer_offset[layer];
                    const stop = X.layer_offset[layer + 1];
                    while (idx < stop) : (idx += 1) {
                        const i: usize = @intCast(idx);
                        if (!t.legal[i] or t.settled[i]) continue;
                        var pos = X.pos_from_colex(idx);
                        inline for (.{ @as(i8, 1), @as(i8, -1) }) |side| {
                            const maxi = comptime (side > 0);
                            const v0 = if (maxi) t.vb[i] else t.vw[i];
                            const cert1 = if (maxi) t.lo.b1[i] == t.hi.b1[i] else t.lo.w1[i] == t.hi.w1[i];
                            const v1 = if (maxi) t.lo.b1[i] else t.lo.w1[i];
                            var best0: u16 = DTT_FAR;
                            var best1: u16 = DTT_FAR;
                            if (cert1 and t.score[i] == v1) best1 = 1; // ending pass
                            for (0..n) |p| {
                                if (pos[p] != 0) continue;
                                const child = R.pos_from_move(&pos, side, p) catch continue;
                                const ci: usize = @intCast(X.colex_from_pos(&child));
                                const cv = if (maxi) t.vw[ci] else t.vb[ci];
                                if (cv == UNDEF) continue;
                                const cd: u16 = if (maxi) t.dw[ci] else t.db[ci];
                                if (cd >= DTT_FAR) continue;
                                if (v0 != UNDEF and cv == v0 and cd + 1 < best0) best0 = cd + 1;
                                if (cert1 and cv == v1 and cd + 1 < best1) best1 = cd + 1;
                            }
                            // pass from V0 to the opponent's V1 at this position
                            const opp_cert1 = if (maxi) t.lo.w1[i] == t.hi.w1[i] else t.lo.b1[i] == t.hi.b1[i];
                            const opp_v1 = if (maxi) t.lo.w1[i] else t.lo.b1[i];
                            const opp_d1: u16 = if (maxi) t.dw1[i] else t.db1[i];
                            if (v0 != UNDEF and opp_cert1 and opp_v1 == v0 and opp_d1 < DTT_FAR and opp_d1 + 1 < best0)
                                best0 = opp_d1 + 1;
                            const a0 = if (maxi) t.db else t.dw;
                            const a1 = if (maxi) t.db1 else t.dw1;
                            if (best0 < a0[i]) {
                                a0[i] = @intCast(best0);
                                changed += 1;
                            }
                            if (best1 < a1[i]) {
                                a1[i] = @intCast(best1);
                                changed += 1;
                            }
                        }
                    }
                }
                rounds += 1;
                if (changed == 0) break;
                if (rounds >= MAX_SWEEPS) @panic("retro: dtt sweeps exceeded MAX_SWEEPS");
            }
        }

        pub fn transformed(pos: *const Pos, perm: *const [n]u8, flip: i8) Pos {
            var out: Pos = undefined;
            for (0..n) |i| out[i] = flip * pos[perm[i]];
            return out;
        }

        // ── parallel finisher (B31) ────────────────────────────────────────

        /// One unit of work for a parallel-finisher worker thread.
        pub const WorkItem = struct { idx: u32, side: i8 };

        /// Per-thread output: freshly allocated columns destined for merge.
        pub const ThreadOut = struct {
            vb: []i8,
            vw: []i8,
            fb: []u8,
            fw: []u8,
            st: ParallelStats = .{},

            pub fn deinit(o: *ThreadOut, alloc: std.mem.Allocator) void {
                alloc.free(o.vb);
                alloc.free(o.vw);
                alloc.free(o.fb);
                alloc.free(o.fw);
            }
        };

        pub const ParallelStats = struct {
            solved: u64 = 0,
            budget_skipped: u64 = 0,
            nodes: u64 = 0,
            max_nodes: u64 = 0,
            bracket_fail: u64 = 0,
            filled: u64 = 0,
            orbit_clash: u64 = 0,
            single_ko: u64 = 0,
        };

        /// Shared read-only state visible to every worker.
        pub const SharedRO = struct {
            t: *const Tables,
            budget: u64,
            bracketed: bool,
            memo_writes: bool,
            deps: bool,
            progress_every: u64,
            quit: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
        };

        /// One worker thread: solves a contiguous slice of work items.
        fn worker(
            shared: *SharedRO,
            work: []WorkItem,
            thread_id: u8,
            out: *ThreadOut,
            gpa: std.mem.Allocator,
        ) void {
            const t = shared.t;

            // ── allocate per-thread state ──
            var ctx = O.Ctx{
                .vb = gpa.alloc(i8, total) catch @panic("OOM: ctx.vb"),
                .vw = gpa.alloc(i8, total) catch @panic("OOM: ctx.vw"),
                .cb = gpa.alloc(bool, total) catch @panic("OOM: ctx.cb"),
                .cw = gpa.alloc(bool, total) catch @panic("OOM: ctx.cw"),
                .memo = true,
                .memo_writes = shared.memo_writes,
                .deps = shared.deps,
            };
            defer {
                gpa.free(ctx.vb);
                gpa.free(ctx.vw);
                gpa.free(ctx.cb);
                gpa.free(ctx.cw);
            }
            ctx.lbb = gpa.alloc(i8, total) catch @panic("OOM: ctx.lbb");
            ctx.ubb = gpa.alloc(i8, total) catch @panic("OOM: ctx.ubb");
            ctx.lbw = gpa.alloc(i8, total) catch @panic("OOM: ctx.lbw");
            ctx.ubw = gpa.alloc(i8, total) catch @panic("OOM: ctx.ubw");
            defer {
                gpa.free(ctx.lbb.?);
                gpa.free(ctx.ubb.?);
                gpa.free(ctx.lbw.?);
                gpa.free(ctx.ubw.?);
            }
            @memset(ctx.lbb.?, -127);
            @memset(ctx.ubb.?, 127);
            @memset(ctx.lbw.?, -127);
            @memset(ctx.ubw.?, 127);

            // certified-only baseline: copy values from t, exclude finished/ko-sensitive
            // (same logic as Finisher.init base_* construction)
            for (0..total) |i| {
                ctx.vb[i] = if (t.legal[i] and t.vb[i] != UNDEF and t.fb[i] & (FLAG_KO_SENSITIVE | FLAG_FROM_FORWARD) == 0) t.vb[i] else UNDEF;
                ctx.vw[i] = if (t.legal[i] and t.vw[i] != UNDEF and t.fw[i] & (FLAG_KO_SENSITIVE | FLAG_FROM_FORWARD) == 0) t.vw[i] else UNDEF;
                ctx.cb[i] = t.legal[i] and t.vb[i] != UNDEF and t.fb[i] & (FLAG_KO_SENSITIVE | FLAG_FROM_FORWARD) == 0;
                ctx.cw[i] = t.legal[i] and t.vw[i] != UNDEF and t.fw[i] & (FLAG_KO_SENSITIVE | FLAG_FROM_FORWARD) == 0;
            }

            var journal = std.ArrayList(u32).empty;
            defer journal.deinit(gpa);
            ctx.journal = &journal;
            ctx.journal_gpa = gpa;

            var dep_map: O.DepMap = undefined;
            if (shared.deps) {
                dep_map = O.DepMap.init(gpa);
                defer dep_map.deinit();
            }

            var hist: O.History = .{};

            const start_ms = nowMs();
            var next_report: u64 = if (shared.progress_every != 0) shared.progress_every else std.math.maxInt(u64);

            // Check both the global SIGINT flag and the programmatic quit.
            for (work) |item| {
                if (parallel_interrupt.load(.acquire) or shared.quit.load(.acquire)) {
                    shared.quit.store(true, .release); // propagate to other workers
                    break;
                }

                const i: usize = @intCast(item.idx);
                var pos = X.pos_from_colex(i);

                journal.clearRetainingCapacity();
                if (shared.deps) {
                    if (ctx.dep_map) |m| m.clearRetainingCapacity();
                    ctx.dep_map = &dep_map;
                }
                ctx.dep_layer_max = 255;
                ctx.nodes = 0;
                ctx.budget = shared.budget;

                const solved: error{Budget}!i8 = if (solveSingleKo(t, &pos, item.side)) |v| blk: {
                    out.st.single_ko += 1;
                    break :blk v;
                } else if (shared.bracketed)
                    ab_value_from_root(t, &ctx, &pos, item.side, &hist)
                else
                    O.value_from_root(&ctx, &pos, item.side, &hist);

                // revert journal (exact-memo + bounds)
                for (journal.items) |entry| {
                    const ji: usize = @intCast(entry & 0x3FFF_FFFF);
                    const white = entry & (1 << 31) != 0;
                    if (entry & (1 << 30) != 0) {
                        if (white) {
                            ctx.lbw.?[ji] = -127;
                            ctx.ubw.?[ji] = 127;
                        } else {
                            ctx.lbb.?[ji] = -127;
                            ctx.ubb.?[ji] = 127;
                        }
                    } else if (white) {
                        ctx.vw[ji] = if (t.legal[ji] and t.vw[ji] != UNDEF and t.fw[ji] & (FLAG_KO_SENSITIVE | FLAG_FROM_FORWARD) == 0) t.vw[ji] else UNDEF;
                        ctx.cw[ji] = t.legal[ji] and t.vw[ji] != UNDEF and t.fw[ji] & (FLAG_KO_SENSITIVE | FLAG_FROM_FORWARD) == 0;
                    } else {
                        ctx.vb[ji] = if (t.legal[ji] and t.vb[ji] != UNDEF and t.fb[ji] & (FLAG_KO_SENSITIVE | FLAG_FROM_FORWARD) == 0) t.vb[ji] else UNDEF;
                        ctx.cb[ji] = t.legal[ji] and t.vb[ji] != UNDEF and t.fb[ji] & (FLAG_KO_SENSITIVE | FLAG_FROM_FORWARD) == 0;
                    }
                }

                if (solved) |v| {
                    out.st.solved += 1;
                    out.st.nodes += ctx.nodes;
                    if (ctx.nodes > out.st.max_nodes) out.st.max_nodes = ctx.nodes;

                    // bracket validation
                    const lo0 = if (item.side > 0) t.lo.b0[i] else t.lo.w0[i];
                    const hi0 = if (item.side > 0) t.hi.b0[i] else t.hi.w0[i];
                    if (v < lo0 or v > hi0) out.st.bracket_fail += 1;

                    // orbit fill into per-thread output buffers
                    inline for (0..E.num_syms) |k| {
                        const tp = transformed(&pos, &E.sym_perms[k], 1);
                        const ti: usize = @intCast(X.colex_from_pos(&tp));
                        const ip = transformed(&pos, &E.sym_perms[k], -1);
                        const ii: usize = @intCast(X.colex_from_pos(&ip));

                        const same_v = if (item.side > 0) out.vb else out.vw;
                        const same_f = if (item.side > 0) out.fb else out.fw;
                        const swap_v = if (item.side > 0) out.vw else out.vb;
                        const swap_f = if (item.side > 0) out.fw else out.fb;

                        if (same_v[ti] == UNDEF) {
                            same_v[ti] = v;
                            out.st.filled += 1;
                        } else if (same_v[ti] != v) out.st.orbit_clash += 1;
                        same_f[ti] |= FLAG_FROM_FORWARD;

                        if (swap_v[ii] == UNDEF) {
                            swap_v[ii] = -v;
                            out.st.filled += 1;
                        } else if (swap_v[ii] != -v) out.st.orbit_clash += 1;
                        swap_f[ii] |= FLAG_FROM_FORWARD;
                    }
                } else |_| {
                    out.st.budget_skipped += 1;
                    // mark orbit with FLAG_TRIED_SKIP in output
                    inline for (0..E.num_syms) |k| {
                        const tp = transformed(&pos, &E.sym_perms[k], 1);
                        const ti: usize = @intCast(X.colex_from_pos(&tp));
                        const ip = transformed(&pos, &E.sym_perms[k], -1);
                        const ii: usize = @intCast(X.colex_from_pos(&ip));
                        if (item.side > 0) {
                            out.fb[ti] |= FLAG_TRIED_SKIP;
                            out.fw[ii] |= FLAG_TRIED_SKIP;
                        } else {
                            out.fw[ti] |= FLAG_TRIED_SKIP;
                            out.fb[ii] |= FLAG_TRIED_SKIP;
                        }
                    }
                }

                if (shared.progress_every != 0 and out.st.solved + out.st.budget_skipped >= next_report) {
                    next_report += shared.progress_every;
                    std.debug.print("  [worker {d}] solved={d} skipped={d} nodes={d} max/root={d} ({d}s)\n", .{
                        thread_id, out.st.solved, out.st.budget_skipped, out.st.nodes,
                        out.st.max_nodes, (nowMs() - start_ms) / 1000,
                    });
                }
            }
        }

        /// Parallel writes-off finisher.
        ///
        /// Collects all ko-sensitive UNDEF orbit representatives (respecting
        /// FLAG_FROM_FORWARD / FLAG_TRIED_SKIP from a loaded checkpoint),
        /// partitions them among N threads, and solves each root
        /// independently. Per-thread output buffers are merged after all
        /// workers complete.
        pub fn finishParallel(
            t: *Tables,
            gpa: std.mem.Allocator,
            budget: u64,
            bracketed: bool,
            progress_every: u64,
            memo_writes: bool,
            deps: bool,
            num_threads: u8,
            round_robin: bool,
        ) !FinishStats {
            const nt: u8 = if (num_threads == 0)
                @as(u8, @intCast((std.Thread.getCpuCount() catch 1)))
            else
                num_threads;
            if (nt == 0) return error.NoThreads;

            const p = std.debug.print;
            const t0 = nowMs();

            // ── Step 1: build work list of unique orbit reps ──
            var done_b = try gpa.alloc(bool, total);
            defer gpa.free(done_b);
            var done_w = try gpa.alloc(bool, total);
            defer gpa.free(done_w);
            @memset(done_b, false);
            @memset(done_w, false);

            var work_list = std.ArrayList(WorkItem).empty;
            defer work_list.deinit(gpa);

            // deepest-first (same order as sequential finisher)
            var layer: usize = n + 1;
            while (layer > 0) {
                layer -= 1;
                var li: u64 = X.layer_offset[layer];
                const li_stop = X.layer_offset[layer + 1];
                while (li < li_stop) : (li += 1) {
                    const i: usize = @intCast(li);
                    if (!t.legal[i]) continue;
                    if (t.fb[i] & FLAG_KO_SENSITIVE == 0 and t.fw[i] & FLAG_KO_SENSITIVE == 0) continue;
                    var pos = X.pos_from_colex(i);
                    inline for (.{ @as(i8, 1), @as(i8, -1) }) |side| {
                        const flags = if (side > 0) t.fb else t.fw;
                        const done = if (side > 0) done_b else done_w;
                        if (flags[i] & FLAG_KO_SENSITIVE != 0 and
                            flags[i] & (FLAG_FROM_FORWARD | FLAG_TRIED_SKIP) == 0 and !done[i])
                        {
                            // mark entire orbit (dedup)
                            inline for (0..E.num_syms) |k| {
                                const tp = transformed(&pos, &E.sym_perms[k], 1);
                                const ti: usize = @intCast(X.colex_from_pos(&tp));
                                const ip = transformed(&pos, &E.sym_perms[k], -1);
                                const ii: usize = @intCast(X.colex_from_pos(&ip));
                                if (side > 0) {
                                    done_b[ti] = true;
                                    done_w[ii] = true;
                                } else {
                                    done_w[ti] = true;
                                    done_b[ii] = true;
                                }
                            }
                            work_list.append(gpa, .{ .idx = @intCast(i), .side = side }) catch
                                @panic("OOM: work list");
                        }
                    }
                }
            }

            const total_work = work_list.items.len;
            if (total_work == 0) {
                p("finishParallel: no work (all ko-sensitive region already solved).\n", .{});
                return FinishStats{};
            }

            p("finishParallel: partition={s} ({d} orbit reps -> {d} threads)\n", .{
                if (round_robin) "round-robin" else "contiguous", total_work, nt,
            });

            // ── Step 2: partition work ──
            // Round-robin (root i -> thread i % nt) is the default: the work
            // list is deepest-first and per-root cost is correlated with list
            // position, so contiguous chunks concentrate same-cost roots on one
            // thread (T930 measured a 3.34x busiest-thread imbalance at 18
            // threads; the wall is set by the busiest thread). round_robin=false
            // restores the legacy contiguous chunking (RETRO_PARTITION=contig;
            // the seeded-defect control and A/B measurement use it).

            // ── Step 3: allocate per-thread output buffers ──
            var outs = try gpa.alloc(ThreadOut, nt);
            defer gpa.free(outs);
            for (0..nt) |tid| {
                outs[tid] = ThreadOut{
                    .vb = try gpa.alloc(i8, total),
                    .vw = try gpa.alloc(i8, total),
                    .fb = try gpa.alloc(u8, total),
                    .fw = try gpa.alloc(u8, total),
                };
                @memset(outs[tid].vb, UNDEF);
                @memset(outs[tid].vw, UNDEF);
                @memset(outs[tid].fb, 0);
                @memset(outs[tid].fw, 0);
            }
            defer for (outs) |*o| o.deinit(gpa);

            // ── Step 4: spawn workers ──
            var shared = SharedRO{
                .t = t,
                .budget = budget,
                .bracketed = bracketed,
                .memo_writes = memo_writes,
                .deps = deps,
                .progress_every = progress_every,
            };

            if (nt == 1) {
                // single-threaded path: no spawn overhead, no permutation
                worker(&shared, work_list.items, @as(u8, 0), &outs[0], gpa);
            } else {
                var threads = try gpa.alloc(std.Thread, nt - 1);
                defer gpa.free(threads);

                // Per-thread slices. Round-robin needs a permuted flat buffer
                // (Zig slices have no stride) so each thread still sees a
                // contiguous slice; contiguous chunks index work_list directly.
                // Both must live until after the join below, hence this scope.
                var rr_items: []WorkItem = &.{};
                defer if (rr_items.len != 0) gpa.free(rr_items);
                var rr_offsets: []usize = &.{};
                defer if (rr_offsets.len != 0) gpa.free(rr_offsets);
                const chunk_size = (total_work + nt - 1) / nt;

                if (round_robin) {
                    // thread t handles items t, t+nt, t+2nt, ...
                    const counts = try gpa.alloc(usize, nt);
                    defer gpa.free(counts);
                    @memset(counts, 0);
                    for (work_list.items, 0..) |_, k| counts[k % nt] += 1;

                    rr_offsets = try gpa.alloc(usize, nt + 1);
                    rr_offsets[0] = 0;
                    for (0..nt) |ti| rr_offsets[ti + 1] = rr_offsets[ti] + counts[ti];

                    rr_items = try gpa.alloc(WorkItem, total_work);
                    const cursors = try gpa.alloc(usize, nt);
                    defer gpa.free(cursors);
                    @memcpy(cursors, rr_offsets[0..nt]);
                    for (work_list.items, 0..) |item, k| {
                        const tid = k % nt;
                        rr_items[cursors[tid]] = item;
                        cursors[tid] += 1;
                    }
                }

                // spawn workers 1..nt-1 on their own slices
                for (1..nt) |tid| {
                    const items: []WorkItem = if (round_robin)
                        rr_items[rr_offsets[tid]..rr_offsets[tid + 1]]
                    else blk: {
                        const start = tid * chunk_size;
                        break :blk if (start >= total_work)
                            work_list.items[0..0] // fewer items than threads
                        else
                            work_list.items[start..@min(start + chunk_size, total_work)];
                    };
                    threads[tid - 1] = try std.Thread.spawn(.{}, worker, .{
                        &shared,
                        items,
                        @as(u8, @intCast(tid)),
                        &outs[tid],
                        gpa,
                    });
                }

                // worker 0 runs on the calling thread
                {
                    const items0: []WorkItem = if (round_robin)
                        rr_items[rr_offsets[0]..rr_offsets[1]]
                    else
                        work_list.items[0..@min(chunk_size, total_work)];
                    worker(&shared, items0, @as(u8, 0), &outs[0], gpa);
                }

                // join all spawned workers
                for (0..nt - 1) |j| {
                    threads[j].join();
                }
            }

            if (shared.quit.load(.acquire)) {
                p("finishParallel: INTERRUPTED — merging partial results.\n", .{});
            }

            // per-thread node totals (diagnostic; the regression's imbalance
            // detector reads these to tell round-robin from contiguous)
            for (0..nt) |tid| {
                p("finishParallel: thread {d}: solved={d} skipped={d} nodes={d}\n", .{
                    tid, outs[tid].st.solved, outs[tid].st.budget_skipped, outs[tid].st.nodes,
                });
            }

            // ── Step 5: merge per-thread outputs into the main table ──
            var st = FinishStats{};
            for (0..nt) |tid| {
                const o = &outs[tid];
                st.solved += o.st.solved;
                st.budget_skipped += o.st.budget_skipped;
                st.nodes += o.st.nodes;
                if (o.st.max_nodes > st.max_nodes) st.max_nodes = o.st.max_nodes;
                st.bracket_fail += o.st.bracket_fail;
                st.single_ko += o.st.single_ko;
                // merge columns: take non-UNDEF values; count clashes
                for (0..total) |i| {
                    if (o.vb[i] != UNDEF) {
                        if (t.vb[i] == UNDEF) {
                            t.vb[i] = o.vb[i];
                            st.filled += 1;
                        } else if (t.vb[i] != o.vb[i]) {
                            st.orbit_clash += 1;
                        }
                    }
                    if (o.vw[i] != UNDEF) {
                        if (t.vw[i] == UNDEF) {
                            t.vw[i] = o.vw[i];
                            st.filled += 1;
                        } else if (t.vw[i] != o.vw[i]) {
                            st.orbit_clash += 1;
                        }
                    }
                    t.fb[i] |= o.fb[i];
                    t.fw[i] |= o.fw[i];
                }
            }

            p("finishParallel: solved={d} filled={d} skipped={d} single-ko={d} nodes={d} max/root={d} ({d}ms)\n", .{
                st.solved, st.filled, st.budget_skipped, st.single_ko, st.nodes, st.max_nodes, nowMs() - t0,
            });
            return st;
        }

        pub const SymStats = struct {
            inv_fail: u64 = 0, // value(-pos,-side) == -value(pos,side)
            dih_fail: u64 = 0, // value(T(pos),side) == value(pos,side)
            lh_inv_fail: u64 = 0, // L(-pos,-side) == -H(pos,side)
            flag_fail: u64 = 0, // flags symmetric under inversion + dihedral
            pub fn pass(s: *const SymStats) bool {
                return s.inv_fail == 0 and s.dih_fail == 0 and s.lh_inv_fail == 0 and s.flag_fail == 0;
            }
        };

        /// Exhaustive symmetry battery over the WHOLE table (the ported
        /// colour-symmetry tests, total instead of hand-picked).
        pub fn checkSymmetry(t: *Tables) SymStats {
            var s = SymStats{};
            for (0..total) |i| {
                if (!t.legal[i]) continue;
                var pos = X.pos_from_colex(i);
                const inv = transformed(&pos, &E.sym_perms[0], -1);
                const ii: usize = @intCast(X.colex_from_pos(&inv));
                if (t.vb[i] == UNDEF) {
                    if (t.vw[ii] != UNDEF) s.inv_fail += 1;
                } else if (t.vw[ii] != -t.vb[i]) s.inv_fail += 1;
                if (t.vw[i] == UNDEF) {
                    if (t.vb[ii] != UNDEF) s.inv_fail += 1;
                } else if (t.vb[ii] != -t.vw[i]) s.inv_fail += 1;
                if (t.fb[i] != t.fw[ii] or t.fw[i] != t.fb[ii]) s.flag_fail += 1;
                // the fixpoints swap under colour inversion: L <-> H
                if (t.lo.b0[i] != -t.hi.w0[ii]) s.lh_inv_fail += 1;
                if (t.lo.w0[i] != -t.hi.b0[ii]) s.lh_inv_fail += 1;
                if (t.lo.b1[i] != -t.hi.w1[ii]) s.lh_inv_fail += 1;
                if (t.lo.w1[i] != -t.hi.b1[ii]) s.lh_inv_fail += 1;
                inline for (0..E.num_syms) |k| {
                    const tp = transformed(&pos, &E.sym_perms[k], 1);
                    const ti: usize = @intCast(X.colex_from_pos(&tp));
                    if (t.vb[ti] != t.vb[i] or t.vw[ti] != t.vw[i]) s.dih_fail += 1;
                    if (t.fb[ti] != t.fb[i] or t.fw[ti] != t.fw[i]) s.flag_fail += 1;
                }
            }
            return s;
        }

        pub const GtStats = struct {
            checked: u64 = 0, // history-exact solves completed
            mismatch: u64 = 0, // ... disagreeing with the stored table
            unfilled: u64 = 0, // stored slot UNDEF (finisher budget-skipped)
            root_skipped: u64 = 0, // node budget exceeded
            bracket_fail: u64 = 0, // exact value outside [L, H] (want 0)
            states: u64 = 0, // distinct (pos, side, passes, ban-set) memoized
            nodes: u64 = 0,
        };

        /// GROUND TRUTH (small gobans): HISTORY-EXACT forward fresh-start
        /// solve of every legal (position, side), compared slot-for-slot
        /// against the final retrograde table. The gold standard: sound by
        /// construction, no ko_ref rule, no eye-prune, no GHI assumption
        /// (see Exact below). One memo map is shared across all roots —
        /// sound because the ban set is part of the key.
        ///
        /// Roots are checked DEEPEST LAYER FIRST with a PER-ROOT node budget:
        /// exact solving explodes toward the empty goban (MEASURED at 2x2:
        /// the empty root alone exceeds 4e9 nodes / 3e7 exact states — nearly
        /// every path is a unique ban set, so the memo barely reuses), and
        /// coverage must not be destroyed by the monster roots. Skipped
        /// shallow roots remain validated by brackets/symmetry/anchors only.
        pub fn groundTruth(t: *Tables, gpa: std.mem.Allocator, root_budget: u64, entry_cap: u32) !GtStats {
            const EX = Exact(w, h);
            var st = GtStats{};
            var ctx = EX.Ctx{ .map = EX.Map.init(gpa), .entry_cap = entry_cap };
            defer ctx.map.deinit();

            var layer: usize = n + 1;
            while (layer > 0) {
                layer -= 1;
                var idx: u64 = X.layer_offset[layer];
                const stop = X.layer_offset[layer + 1];
                while (idx < stop) : (idx += 1) {
                    const i: usize = @intCast(idx);
                    if (!t.legal[i]) continue;
                    var pos = X.pos_from_colex(idx);
                    inline for (.{ @as(i8, 1), @as(i8, -1) }) |side| {
                        const stored = if (side > 0) t.vb[i] else t.vw[i];
                        ctx.budget = ctx.nodes + root_budget; // per-root allowance
                        if (stored == UNDEF) {
                            st.unfilled += 1;
                        } else if (EX.root(&ctx, &pos, side)) |v| {
                            st.checked += 1;
                            if (stored != v) st.mismatch += 1;
                            if (!t.settled[i]) {
                                const lo0 = if (side > 0) t.lo.b0[i] else t.lo.w0[i];
                                const hi0 = if (side > 0) t.hi.b0[i] else t.hi.w0[i];
                                if (v < lo0 or v > hi0) st.bracket_fail += 1;
                            }
                        } else |err| switch (err) {
                            error.Budget => st.root_skipped += 1,
                            else => return err,
                        }
                    }
                }
            }
            st.states = ctx.map.count();
            st.nodes = ctx.nodes;
            return st;
        }
    };
}

// ---- build + validation battery ------------------------------------------------

/// HISTORY-EXACT forward solver — the gold standard for SMALL gobans. The
/// memo key includes the FULL positional-superko ban set (a bitset over the
/// whole colex space), so memoization is sound BY CONSTRUCTION: no ko_ref
/// cleanliness rule, no GHI assumption, no eye-prune, and one map may be
/// shared across roots. The price is the key size (3^n bits), which is why
/// this exists only for 2x2 (81-bit ban set) and 3x2 (729-bit) scale — the
/// scales where independent per-root forward solving was MEASURED intractable
/// (2x2 roots exceed 100M nodes even with a fresh single-root memo).
pub fn Exact(comptime w: usize, comptime h: usize) type {
    return struct {
        pub const R = rules.Rules(w, h);
        pub const X = colexmod.Indexer(w, h);
        pub const total: usize = @intCast(X.total);
        pub const Bans = std.StaticBitSet(total);
        /// N-ply ko window: the up-to-MAX_KO_PLY most recent goban indices,
        /// most-recent first, sentinel-padded. See Ctx.ko_ply.
        pub const MAX_KO_PLY = 8;
        pub const KO_NONE: u32 = std.math.maxInt(u32);
        pub const Win = [MAX_KO_PLY]u32;
        pub const win_empty: Win = [_]u32{KO_NONE} ** MAX_KO_PLY;
        pub const Key = struct { idx: u32, side: i8, passes: u8, win: Win, bans: Bans };
        pub const Map = std.AutoHashMap(Key, i8);

        pub const Ctx = struct {
            map: Map,
            nodes: u64 = 0,
            budget: u64 = 0, // 0 = unlimited (shared across roots)
            entry_cap: u32 = 0, // stop INSERTING beyond this (stays sound, just slower)
            // kill-X% rule (experimental, ABANDONED as a ko-sensitive region lever): a move
            // capturing MORE than kill_pct% of the goban's points ends the
            // game, scored by area. 0 = disabled. See Tables.kill_pct.
            kill_pct: u8 = 0,
            // N-ply superko + score-on-cycle (the bounded-history family that
            // interpolates basic ko -> PSK). When cycle_score is set, positional
            // superko is REPLACED by: (a) a move may not recreate any of the
            // last `ko_ply` goban positions (the bounded ko WINDOW; ko_ply=1 =
            // basic ko); (b) a repeat OLDER than the window (a longer cycle the
            // window can't forbid) ENDS the game, scored by area AS-IS. This
            // makes every N-ply rule terminate and interpolate basic ko (N=1)
            // -> PSK (N large enough that no repeat is ever "older"). The value
            // depends on the window + full history, so `win` and `bans` are
            // both in the memo key -> a small-goban VALUES/tractability probe,
            // not a generation method. false = pure PSK.
            cycle_score: bool = false,
            ko_ply: usize = 1, // window depth N (1..MAX_KO_PLY); used iff cycle_score
        };

        fn stones(pos: *const R.Pos, colour: i8) u32 {
            var c: u32 = 0;
            for (pos) |v| {
                if (v == colour) c += 1;
            }
            return c;
        }

        /// True iff `ci` is in the first `n` slots of the ko window.
        fn inWindow(win: *const Win, n: usize, ci: usize) bool {
            const c: u32 = @intCast(ci);
            for (win[0..n]) |wb| {
                if (wb == c) return true;
            }
            return false;
        }

        /// New window after moving to `next`: prepend it, keep the N most
        /// recent, drop the oldest. (A pass instead clears the window.)
        fn pushWindow(win: *const Win, next: usize) Win {
            var out = win_empty;
            out[0] = @intCast(next);
            for (0..MAX_KO_PLY - 1) |k| out[k + 1] = win[k];
            return out;
        }

        pub fn solve(ctx: *Ctx, pos: *const R.Pos, side: i8, passes: u8, win: Win, bans: Bans) error{ Budget, OutOfMemory }!i8 {
            ctx.nodes += 1;
            if (ctx.budget != 0 and ctx.nodes > ctx.budget) return error.Budget;
            if (passes >= 2) return R.area_score(pos);
            if (R.is_settled(pos)) return R.area_score(pos);
            const key = Key{
                .idx = @intCast(X.colex_from_pos(pos)),
                .side = side,
                .passes = passes,
                .win = win,
                .bans = bans,
            };
            if (ctx.map.get(key)) |v| return v;
            const self_idx: usize = @intCast(key.idx);
            const maximizing = side > 0;
            var best: i8 = if (maximizing) -127 else 127;
            for (0..R.n) |p| {
                if (pos[p] != 0) continue;
                const child = R.pos_from_move(pos, side, p) catch continue;
                const ci: usize = @intCast(X.colex_from_pos(&child));
                if (ctx.cycle_score) {
                    // N-ply ko: may not recreate any of the last ko_ply gobans.
                    if (inWindow(&win, ctx.ko_ply, ci)) continue;
                    // repeat OLDER than the window (a longer cycle the window
                    // can't forbid): the game ends now, scored by area AS-IS.
                    if (bans.isSet(ci)) {
                        const v = R.area_score(&child);
                        if (maximizing) {
                            if (v > best) best = v;
                        } else if (v < best) best = v;
                        continue;
                    }
                } else if (bans.isSet(ci)) continue; // positional superko
                // kill-X%: if this move captured > kill_pct% of the goban's
                // points worth of opponent stones, the game ends now (scored
                // by area). Terminal -> no recursion, so no kill-refill cycle.
                if (ctx.kill_pct != 0) {
                    const captured = stones(pos, -side) -| stones(&child, -side);
                    if (captured * 100 > @as(u32, ctx.kill_pct) * R.n) {
                        const v = R.area_score(&child);
                        if (maximizing) {
                            if (v > best) best = v;
                        } else if (v < best) best = v;
                        continue;
                    }
                }
                var nb = bans;
                nb.set(ci);
                const nw = pushWindow(&win, self_idx);
                const v = try solve(ctx, &child, -side, 0, nw, nb);
                if (maximizing) {
                    if (v > best) best = v;
                } else if (v < best) best = v;
            }
            // a pass places no stone and clears any pending ko window.
            const vp = try solve(ctx, pos, -side, passes + 1, win_empty, bans);
            if (maximizing) {
                if (vp > best) best = vp;
            } else if (vp < best) best = vp;
            if (ctx.entry_cap == 0 or ctx.map.count() < ctx.entry_cap) {
                try ctx.map.put(key, best);
            }
            return best;
        }

        /// Fresh-start value (ADR-0008): ban set seeded with the root itself,
        /// empty ko window.
        pub fn root(ctx: *Ctx, pos: *const R.Pos, side: i8) error{ Budget, OutOfMemory }!i8 {
            var bans = Bans.initEmpty();
            bans.set(@intCast(X.colex_from_pos(pos)));
            return solve(ctx, pos, side, 0, win_empty, bans);
        }
    };
}

/// One lean L/H Bellman sweep over a single quad given as raw slices
/// (b0/w0/b1/w1). Stone-count DESCENDING Gauss-Seidel, identical update to
/// Retro.sweep but with NO kill-X% branch and NO finisher columns. Returns the
/// number of value changes. This is the perf-critical loop of the core-only
/// (Option (c)) build; keep it byte-for-byte equivalent to Retro.sweep's
/// no-kill path (regression-gated against the full-Tables numbers).
fn coreSweep(
    comptime w: usize,
    comptime h: usize,
    b0: []i8,
    w0: []i8,
    b1: []i8,
    w1: []i8,
    legal: []const bool,
    settled: []const bool,
    score: []const i8,
) u64 {
    const R = rules.Rules(w, h);
    const X = colexmod.Indexer(w, h);
    const n = R.n;
    var changes: u64 = 0;
    var layer: usize = n + 1;
    while (layer > 0) {
        layer -= 1;
        var idx: u64 = X.layer_offset[layer];
        const stop = X.layer_offset[layer + 1];
        while (idx < stop) : (idx += 1) {
            const i: usize = @intCast(idx);
            if (!legal[i] or settled[i]) continue;
            var pos = X.pos_from_colex(idx);
            inline for (.{ @as(i8, 1), @as(i8, -1) }) |side| {
                const maximizing = comptime (side > 0);
                var have_move = false;
                var m: i8 = undefined;
                for (0..n) |pp| {
                    if (pos[pp] != 0) continue;
                    const child = R.pos_from_move(&pos, side, pp) catch continue;
                    const ci: usize = @intCast(X.colex_from_pos(&child));
                    const cv = if (maximizing) w0[ci] else b0[ci];
                    if (!have_move) {
                        m = cv;
                        have_move = true;
                    } else m = if (maximizing) @max(m, cv) else @min(m, cv);
                }
                var v1: i8 = score[i];
                var v0: i8 = if (maximizing) w1[i] else b1[i];
                if (have_move) {
                    v1 = if (maximizing) @max(m, v1) else @min(m, v1);
                    v0 = if (maximizing) @max(m, v0) else @min(m, v0);
                }
                const a1 = if (maximizing) b1 else w1;
                const a0 = if (maximizing) b0 else w0;
                if (a1[i] != v1) {
                    a1[i] = v1;
                    changes += 1;
                }
                if (a0[i] != v0) {
                    a0[i] = v0;
                    changes += 1;
                }
            }
        }
    }
    return changes;
}

/// LEAN CORE-ONLY census (Option (c), the 5x5 scaling path). Allocates only the
/// 11 columns seed/converge/core-count need — legal, settled, score, and the
/// L/H quads [b0,w0,b1,w1]x2 — dropping the 8 finisher/artifact columns
/// (vb/vw/fb/fw/db/dw/db1/dw1) the single-score census never reads. ~halves
/// RAM per index (19 -> 11 bytes): 4x4 = 0.5 GB, 5x4 = 38 GB dense (before
/// symmetry folding / out-of-core, which 5x5 will require). Reports the
/// rule-independent single-score fraction + empty(B) bracket — no finisher,
/// no ko rule. MUST reproduce the full-Tables (RETRO_BRACKET) numbers exactly.
fn coreCensus(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator) !void {
    const R = rules.Rules(w, h);
    const X = colexmod.Indexer(w, h);
    const E = enumerate.Enumerator(w, h);
    const n = R.n;
    const N: i8 = @intCast(n);
    const total: usize = @intCast(X.total);
    const p = std.debug.print;

    p("core-census {d}x{d}: total=3^{d}={d}  lean RAM = {d:.2} GB (11 B/idx)\n", .{
        w, h, n, total, @as(f64, @floatFromInt(total)) * 11.0 / 1e9,
    });

    const legal = try gpa.alloc(bool, total);
    defer gpa.free(legal);
    const settled = try gpa.alloc(bool, total);
    defer gpa.free(settled);
    const score = try gpa.alloc(i8, total);
    defer gpa.free(score);
    var q: [8][]i8 = undefined;
    for (0..8) |k| q[k] = try gpa.alloc(i8, total);
    defer for (0..8) |k| gpa.free(q[k]);
    const lb0 = q[0];
    const lw0 = q[1];
    const lb1 = q[2];
    const lw1 = q[3];
    const hb0 = q[4];
    const hw0 = q[5];
    const hb1 = q[6];
    const hw1 = q[7];

    const t0 = nowMs();
    var legal_count: u64 = 0;
    var settled_count: u64 = 0;
    for (0..total) |i| {
        var pos = X.pos_from_colex(i);
        const ok = E.is_legal(&pos);
        legal[i] = ok;
        if (!ok) {
            settled[i] = false;
            score[i] = 0;
            inline for (0..8) |k| q[k][i] = 0;
            continue;
        }
        legal_count += 1;
        const sc = R.area_score(&pos);
        score[i] = sc;
        const st = R.is_settled(&pos);
        settled[i] = st;
        if (st) {
            settled_count += 1;
            inline for (0..8) |k| q[k][i] = sc;
        } else {
            lb0[i] = -N;
            lw0[i] = -N;
            lb1[i] = -N;
            lw1[i] = -N;
            hb0[i] = N;
            hw0[i] = N;
            hb1[i] = N;
            hw1[i] = N;
        }
    }
    const seed_ms = nowMs() - t0;

    var sweeps: usize = 0;
    while (true) {
        const c = coreSweep(w, h, lb0, lw0, lb1, lw1, legal, settled, score) +
            coreSweep(w, h, hb0, hw0, hb1, hw1, legal, settled, score);
        sweeps += 1;
        if (c == 0) break;
    }
    const build_ms = nowMs() - t0;

    var certified: u64 = settled_count * 2;
    var ko_sensitive: u64 = 0;
    for (0..total) |i| {
        if (!legal[i] or settled[i]) continue;
        if (lb0[i] == hb0[i]) certified += 1 else ko_sensitive += 1;
        if (lw0[i] == hw0[i]) certified += 1 else ko_sensitive += 1;
    }
    const slots = legal_count * 2;
    const core_pct = @as(f64, @floatFromInt(certified)) * 100.0 / @as(f64, @floatFromInt(slots));
    const res_pct = @as(f64, @floatFromInt(ko_sensitive)) * 100.0 / @as(f64, @floatFromInt(slots));

    const e: usize = @intCast(X.colex_from_pos(&([_]i8{0} ** R.n)));
    p("  slots={d}  single-score={d} ({d:.2}%)  ko_sensitive={d} ({d:.4}%)  sweeps={d}  seed={d}ms build={d}ms\n", .{
        slots, certified, core_pct, ko_sensitive, res_pct, sweeps, seed_ms, build_ms,
    });
    if (lb0[e] == hb0[e]) {
        p("  empty(B) single-score = {d} (fresh-start)\n", .{lb0[e]});
    } else {
        p("  empty(B) bracket = [{d}, {d}] (width {d})\n", .{ lb0[e], hb0[e], @as(i16, hb0[e]) - @as(i16, lb0[e]) });
    }
}

fn runCore(gpa: std.mem.Allocator) void {
    const p = std.debug.print;
    p("CORE: lean core-only single-score census (Option (c), 5x5 path)\n", .{});
    p("  [validation — must match RETRO_BRACKET: 3x3 65.69%, 4x3 73.53%, 4x4 78.68%]\n", .{});
    coreCensus(3, 3, gpa) catch |e| p("  3x3 FAILED: {t}\n", .{e});
    coreCensus(4, 3, gpa) catch |e| p("  4x3 FAILED: {t}\n", .{e});
    coreCensus(4, 4, gpa) catch |e| p("  4x4 FAILED: {t}\n", .{e});
    if (std.c.getenv("RETRO_CORE_5X4") != null) {
        p("  [5x4 dress rehearsal — ~38 GB dense, the ko-sensitive region-growth measurement]\n", .{});
        coreCensus(5, 4, gpa) catch |e| p("  5x4 FAILED: {t}\n", .{e});
    }
}

/// Monotonic milliseconds (std.time.Timer is gone in Zig 0.16; the Io-based
/// clock needs an Io instance — overkill for battery timing).
fn nowMs() u64 {
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * 1000 + @as(u64, @intCast(ts.nsec)) / 1_000_000;
}

/// Global interrupt flag for the parallel finisher (B31). Set by the SIGINT
/// handler and polled by each worker between root solves.
var parallel_interrupt: std.atomic.Value(bool) = std.atomic.Value(bool).init(false);

/// SIGINT handler: sets the global interrupt flag so workers can clean up.
fn parallelSigintHandler(sig: std.posix.SIG) callconv(.c) void {
    parallel_interrupt.store(true, .release);
    _ = sig;
}

/// Install the SIGINT handler. Returns the previous action so the caller can
/// restore it (or just leave it — process exits shortly after).
fn installParallelSigint() void {
    const act = std.posix.Sigaction{
        .handler = .{ .handler = parallelSigintHandler },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    };
    std.posix.sigaction(std.posix.SIG.INT, &act, null);
}

const RunOpts = struct {
    ground_truth: bool = false, // exhaustive history-exact compare (small gobans only)
    gt_root_budget: u64 = 3_000_000, // per-root node allowance (deepest layers first;
    // exact roots are bimodal — near-terminal ones finish far under this,
    // reopening ones would not finish at 1000x it, MEASURED at 2x2 — so a
    // small budget keeps the reachable coverage and fails the rest fast)
    gt_entries: u32 = 30_000_000, // memo entry cap (memory bound; sound either way)
    spot_min_layer: ?usize = null, // no-memo spot checks for layers >= this
    spot_budget: u64 = 2_000_000, // even deep CERTIFIED roots can reopen & be
    // expensive; a modest budget confirms the tractable ones and fails the
    // rest fast (they are still covered by brackets + symmetry)
    spot_stride: usize = 7, // sample every Nth certified deep (pos,side)
    spot_cap: u64 = 400, // hard cap on spot solves (bounds wall time)
    finisher_budget: u64 = 500_000_000,
    finisher_bracketed: bool = true, // ADR-0010 alpha-beta; false = plain ADR-0009 cross-check
    finisher_memo_writes: bool = true, // false = SOUND (Track A): no cross-branch reuse (ADR-0013)
    finisher_deps: bool = false, // true = Track B: fingerprint-guarded reuse (ADR-0013)
    finisher_progress_every: u64 = 0, // heartbeat every N orbit reps (0 = silent)
    diag: bool = false, // report the ko-sensitive region-orbit census, then CONTINUE
    diag_only: bool = false, // build + certify + report ko-sensitive region-orbit scale, then stop
};

/// Count ko-sensitive orbit REPRESENTATIVES per side (the number of forward solves
/// the finisher must actually run — the orbit fills the rest). Cheap: build
/// + certify only, no solving.
fn koSensitiveDiag(comptime w: usize, comptime h: usize, t: anytype) void {
    const RT = Retro(w, h);
    const p = std.debug.print;
    const gpa = std.heap.page_allocator;
    const done_b = gpa.alloc(bool, RT.total) catch return;
    const done_w = gpa.alloc(bool, RT.total) catch return;
    defer gpa.free(done_b);
    defer gpa.free(done_w);
    @memset(done_b, false);
    @memset(done_w, false);
    var reps_b: u64 = 0;
    var reps_w: u64 = 0;
    for (0..RT.total) |i| {
        if (!t.legal[i]) continue;
        var pos = RT.X.pos_from_colex(i);
        inline for (.{ @as(i8, 1), @as(i8, -1) }) |side| {
            const flags = if (side > 0) t.fb else t.fw;
            const done = if (side > 0) done_b else done_w;
            if (flags[i] & FLAG_KO_SENSITIVE != 0 and !done[i]) {
                if (side > 0) reps_b += 1 else reps_w += 1;
                inline for (0..RT.E.num_syms) |k| {
                    const tp = RT.transformed(&pos, &RT.E.sym_perms[k], 1);
                    const ti: usize = @intCast(RT.X.colex_from_pos(&tp));
                    const ip = RT.transformed(&pos, &RT.E.sym_perms[k], -1);
                    const ii: usize = @intCast(RT.X.colex_from_pos(&ip));
                    if (side > 0) {
                        done_b[ti] = true;
                        done_w[ii] = true;
                    } else {
                        done_w[ti] = true;
                        done_b[ii] = true;
                    }
                }
            }
        }
    }
    p("ko-sensitive region-orbit diag: reps to solve B/W = {d}/{d} (from ko-sensitive region {d}/{d}); per-layer reps(B):", .{
        reps_b, reps_w, t.ko_sensitive_b, t.ko_sensitive_w,
    });
    // per-layer rep counts (B)
    @memset(done_b, false);
    for (0..RT.n + 1) |layer| {
        var c: u64 = 0;
        for (RT.X.layer_offset[layer]..RT.X.layer_offset[layer + 1]) |ii| {
            const i: usize = @intCast(ii);
            if (!t.legal[i] or t.fb[i] & FLAG_KO_SENSITIVE == 0 or done_b[i]) continue;
            c += 1;
            var pos = RT.X.pos_from_colex(ii);
            inline for (0..RT.E.num_syms) |k| {
                const tp = RT.transformed(&pos, &RT.E.sym_perms[k], 1);
                done_b[@intCast(RT.X.colex_from_pos(&tp))] = true;
            }
        }
        if (c != 0) p(" k{d}:{d}", .{ layer, c });
    }
    p("\n\n", .{});
}

/// Probe: build + certify, then solve ONLY the 3x3 published-anchor roots
/// with the bracket-guided alpha-beta finisher (ADR-0010), each timed and
/// node-counted. This is the ADR-0010 acceptance test: the anchors must PIN
/// (empty +9 / side +3 / corner -9), not merely bracket — the plain finisher
/// was measured unable to (Finding 6: empty(B) >2e9 nodes).
fn anchorProbe(gpa: std.mem.Allocator, budget: u64) !void {
    const RT = Retro(3, 3);
    const p = std.debug.print;
    var t = try RT.Tables.init(gpa);
    defer t.deinit();
    RT.seed(&t);
    RT.converge(&t);
    RT.finalize(&t);
    p("3x3 anchor probe: build sweeps={d} ko-sensitive region B/W={d}/{d}\n", .{ t.sweeps, t.ko_sensitive_b, t.ko_sensitive_w });

    // certified-seeded forward context (same construction as finish())
    var ctx = RT.O.Ctx{
        .vb = try gpa.alloc(i8, RT.total),
        .vw = try gpa.alloc(i8, RT.total),
        .cb = try gpa.alloc(bool, RT.total),
        .cw = try gpa.alloc(bool, RT.total),
        .memo = true,
    };
    defer {
        gpa.free(ctx.vb);
        gpa.free(ctx.vw);
        gpa.free(ctx.cb);
        gpa.free(ctx.cw);
    }
    const base_vb = try gpa.alloc(i8, RT.total);
    const base_vw = try gpa.alloc(i8, RT.total);
    const base_cb = try gpa.alloc(bool, RT.total);
    const base_cw = try gpa.alloc(bool, RT.total);
    defer {
        gpa.free(base_vb);
        gpa.free(base_vw);
        gpa.free(base_cb);
        gpa.free(base_cw);
    }
    @memcpy(base_vb, t.vb);
    @memcpy(base_vw, t.vw);
    for (0..RT.total) |i| {
        base_cb[i] = t.legal[i] and t.vb[i] != UNDEF;
        base_cw[i] = t.legal[i] and t.vw[i] != UNDEF;
    }
    const hist = try gpa.create(RT.O.History);
    defer gpa.destroy(hist);
    hist.* = .{};

    var empty: RT.Pos = [_]i8{0} ** 9;
    var centre: RT.Pos = [_]i8{0} ** 9;
    centre[4] = 1;
    var side_b1: RT.Pos = [_]i8{0} ** 9;
    side_b1[7] = 1;
    var corner: RT.Pos = [_]i8{0} ** 9;
    corner[6] = 1;
    const Anchor = struct { name: []const u8, pos: *RT.Pos, side: i8, want: i8 };
    const anchors = [_]Anchor{
        .{ .name = "empty(B)", .pos = &empty, .side = 1, .want = 9 },
        .{ .name = "empty(W)", .pos = &empty, .side = -1, .want = -9 },
        .{ .name = "1.B centre", .pos = &centre, .side = -1, .want = 9 },
        .{ .name = "1.B side", .pos = &side_b1, .side = -1, .want = 3 },
        .{ .name = "1.B corner", .pos = &corner, .side = -1, .want = -9 },
    };
    var all_ok = true;
    for (anchors) |a| {
        const i: usize = @intCast(RT.X.colex_from_pos(a.pos));
        const lo0 = if (a.side > 0) t.lo.b0[i] else t.lo.w0[i];
        const hi0 = if (a.side > 0) t.hi.b0[i] else t.hi.w0[i];
        const certified = lo0 == hi0;
        @memcpy(ctx.vb, base_vb);
        @memcpy(ctx.vw, base_vw);
        @memcpy(ctx.cb, base_cb);
        @memcpy(ctx.cw, base_cw);
        ctx.nodes = 0;
        ctx.budget = budget;
        const t0 = nowMs();
        const res = RT.ab_value_from_root(&t, &ctx, a.pos, a.side, hist);
        const ms = nowMs() - t0;
        if (res) |v| {
            const ok = v == a.want and v >= lo0 and v <= hi0;
            if (!ok) all_ok = false;
            p("  {s:<12} = {d:>3} (want {d:>3}) [{d},{d}] {s} {s}  nodes={d} {d}ms\n", .{
                a.name, v, a.want, lo0, hi0,
                if (certified) "CERT" else "ko-sensitive region",
                if (ok) "OK" else "MISMATCH", ctx.nodes, ms,
            });
        } else |_| {
            all_ok = false;
            p("  {s:<12}  BUDGET-EXCEEDED [{d},{d}] {s}  nodes>{d} {d}ms\n", .{
                a.name, lo0, hi0, if (certified) "CERT" else "ko-sensitive region", budget, ms,
            });
        }
    }
    p("anchor probe: {s}\n", .{if (all_ok) "PASS" else "INCOMPLETE/FAIL"});
}

/// Build the COMPLETE oracle for a goban (iterate -> certify -> finish ->
/// dtt), persist it as an ADR-0011 artifact, then RELOAD the file and verify
/// the loaded bytes: every column identical to the in-memory table, and the
/// battery's key facts re-checked from the LOADED data (the file, not the
/// RAM it came from, is what future sessions trust).
fn saveArtifact(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator, path: []const u8, finisher_budget: u64, progress_every: u64, diag: bool, checkpoint_path: ?[]const u8, memo_writes: bool, deps: bool, bracket_only: bool) !void {
    const RT = Retro(w, h);
    const p = std.debug.print;
    p("==== artifact {d}x{d} -> {s} ====\n", .{ w, h, path });

    var threaded = std.Io.Threaded.init(gpa, .{});
    const io = threaded.io();
    const dir = std.Io.Dir.cwd();
    const header = artifact.Header{
        .board_w = w,
        .board_h = h,
        .total = RT.X.total,
        .legal_count = 0, // patched below once the build has counted
    };

    var t = try RT.Tables.init(gpa);
    defer t.deinit();
    const t0 = nowMs();
    RT.seed(&t);
    RT.converge(&t);
    RT.finalize(&t);
    p("build: legal={d} settled={d} sweeps={d} ko-sensitive region B/W={d}/{d} ({d} ms)\n", .{
        t.legal_count, t.settled_count, t.sweeps, t.ko_sensitive_b, t.ko_sensitive_w, nowMs() - t0,
    });
    if (diag) koSensitiveDiag(w, h, &t);
    var hdr = header;
    hdr.legal_count = t.legal_count;

    // RESUME: a checkpoint carries finished values (FLAG_FROM_FORWARD) and
    // budget-skip marks (FLAG_TRIED_SKIP); the finisher skips both. The
    // build is deterministic, so overlaying the checkpoint columns onto the
    // fresh certify is sound; the finisher re-derives its certified-only
    // memo baseline flag-aware (a checkpointed finished value never seeds
    // the memo — Finding 2).
    if (checkpoint_path) |cp| {
        if (artifact.load(io, dir, cp, gpa)) |loaded| {
            var d = loaded;
            defer d.deinit();
            if (d.header.board_w != w or d.header.board_h != h) return error.ArtifactMismatch;
            @memcpy(t.vb, d.vb);
            @memcpy(t.vw, d.vw);
            @memcpy(t.fb, d.fb);
            @memcpy(t.fw, d.fw);
            var done: u64 = 0;
            var skipped: u64 = 0;
            for (0..RT.total) |i| {
                if (t.fb[i] & FLAG_FROM_FORWARD != 0) done += 1;
                if (t.fw[i] & FLAG_FROM_FORWARD != 0) done += 1;
                if (t.fb[i] & FLAG_TRIED_SKIP != 0) skipped += 1;
                if (t.fw[i] & FLAG_TRIED_SKIP != 0) skipped += 1;
            }
            p("resume: {s} loaded — {d} finished slots, {d} skip-marked slots carried over\n", .{ cp, done, skipped });
        } else |_| {
            p("resume: no checkpoint at {s} — starting fresh\n", .{cp});
        }
    }

    const t1 = nowMs();
    var fin: RT.FinishStats = undefined;
    if (bracket_only) {
        // T14.1 (Minimax-m3, 2026-07-26): the bracket-only deliverable per
        // ADR-0011/0013. The fresh-start single-score region is history-free; the ko-sensitive
        // region stays FLAG_KO_SENSITIVE / value UNDEF, honestly bracketed [L,H].
        // No finisher is run; no checkpoint is written. The artifact is sound
        // and partial by design.
        p("finisher: SKIPPED (bracket_only=true; build result is the deliverable)\n", .{});
        fin = .{
            .solved = 0,
            .filled = 0,
            .budget_skipped = 0,
            .nodes = 0,
            .max_nodes = 0,
            .bracket_fail = 0,
            .orbit_clash = 0,
        };
    } else {
        var f = try RT.Finisher.init(&t, gpa, finisher_budget, true, progress_every, memo_writes, deps);
        defer f.deinit();
        var layer: usize = RT.n + 1;
        var last_work: u64 = 0;
        while (layer > 0) {
            layer -= 1;
            f.runLayer(layer);
            const work = f.st.solved + f.st.budget_skipped;
            if (checkpoint_path != null and work != last_work) {
                last_work = work;
                try artifact.save(io, dir, checkpoint_path.?, gpa, hdr, .{
                    .vb = t.vb, .vw = t.vw, .fb = t.fb, .fw = t.fw, .db = t.db, .dw = t.dw,
                });
                p("  checkpoint: layer {d} done -> {s} (solved={d} skipped={d})\n", .{
                    layer, checkpoint_path.?, f.st.solved, f.st.budget_skipped,
                });
            }
        }
        fin = f.st;
    }
    p("finisher[bracketed,{s}]: orbits solved={d} skipped={d} single-ko={d} nodes={d} max/root={d} ({d} ms)\n", .{
        if (deps) "deps" else if (memo_writes) "reuse" else "sound", fin.solved, fin.budget_skipped, fin.single_ko, fin.nodes, fin.max_nodes, nowMs() - t1,
    });
    const t2 = nowMs();
    RT.dttPass(&t);
    const sym = RT.checkSymmetry(&t);
    var undef_legal: u64 = 0;
    for (0..RT.total) |i| {
        if (t.legal[i] and (t.vb[i] == UNDEF or t.vw[i] == UNDEF)) undef_legal += 1;
    }
    p("validate: bracket-fails={d} orbit-clashes={d} symmetry={s} unfilled={d} (dtt+symmetry {d} ms)\n", .{
        fin.bracket_fail, fin.orbit_clash, if (sym.pass()) "PASS" else "FAIL", undef_legal, nowMs() - t2,
    });
    if (!sym.pass() or fin.bracket_fail != 0 or fin.orbit_clash != 0) {
        p("artifact: REFUSED — validation failed\n", .{});
        return error.IncompleteOracle;
    }
    if (undef_legal != 0 and !bracket_only) {
        // incomplete but sound: the tractable ko-sensitive region is solved and
        // persisted in the checkpoint; the remainder stays bracketed [L,H].
        p("artifact: PARTIAL — {d} legal slots unfilled (budget-skipped opening ko-sensitive region). Checkpoint {s} holds all finished values; no final artifact written (ADR-0011: complete oracles only).\n", .{
            undef_legal, checkpoint_path orelse "(none)",
        });
        return;
    }
    if (undef_legal != 0) {
        p("artifact: BRACKET-ONLY — {d} legal slots remain ko-sensitive (FLAG_KO_SENSITIVE, value UNDEF, bounded by [L,H]). ADR-0011 partial-oracle deliverable, the sound bracket-only result.\n", .{undef_legal});
    }

    try artifact.save(io, dir, path, gpa, hdr, .{ .vb = t.vb, .vw = t.vw, .fb = t.fb, .fw = t.fw, .db = t.db, .dw = t.dw });

    var d = try artifact.load(io, dir, path, gpa);
    defer d.deinit();
    const identical = std.mem.eql(i8, d.vb, t.vb) and std.mem.eql(i8, d.vw, t.vw) and
        std.mem.eql(u8, d.fb, t.fb) and std.mem.eql(u8, d.fw, t.fw) and
        std.mem.eql(u8, d.db, t.db) and std.mem.eql(u8, d.dw, t.dw);
    // key facts re-read from the LOADED columns
    const empty: RT.Pos = [_]i8{0} ** RT.n;
    const ei: usize = @intCast(RT.X.colex_from_pos(&empty));
    p("reload: header {d}x{d} total={d} legal={d}; columns {s}; empty(B) value={d} dtt={d} flags={b}\n", .{
        d.header.board_w, d.header.board_h, d.header.total, d.header.legal_count,
        if (identical) "IDENTICAL" else "MISMATCH", d.vb[ei], d.db[ei], d.fb[ei],
    });
    if (!identical) return error.ArtifactMismatch;
    const bytes = artifact.HEADER_LEN + 6 * RT.total;
    p("artifact: OK ({d} bytes)\n\n", .{bytes});
}

/// SHA-256 sums of the just-written artifact files, `shasum` format —
/// integrity check independent of the artifact reader's internal CRC.
fn writeChecksums(gpa: std.mem.Allocator, sums_path: []const u8, paths: []const []const u8) !void {
    var threaded = std.Io.Threaded.init(gpa, .{});
    const io = threaded.io();
    const dir = std.Io.Dir.cwd();
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);
    for (paths) |path| {
        const bytes = try dir.readFileAlloc(io, path, gpa, .unlimited);
        defer gpa.free(bytes);
        var digest: [32]u8 = undefined;
        std.crypto.hash.sha2.Sha256.hash(bytes, &digest, .{});
        const hex = std.fmt.bytesToHex(digest, .lower);
        try out.appendSlice(gpa, &hex);
        try out.appendSlice(gpa, "  ");
        try out.appendSlice(gpa, path);
        try out.appendSlice(gpa, "\n");
    }
    try dir.writeFile(io, .{ .sub_path = sums_path, .data = out.items });
    std.debug.print("checksums: {s} written ({d} files)\n", .{ sums_path, paths.len });
}

fn runBoard(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator, opts: RunOpts) !void {
    const RT = Retro(w, h);
    const p = std.debug.print;
    p("==== {d}x{d} ({d} slots) ====\n", .{ w, h, RT.total });

    var t = try RT.Tables.init(gpa);
    defer t.deinit();

    const t0 = nowMs();
    RT.seed(&t);
    RT.converge(&t);
    RT.finalize(&t);
    const build_ms = nowMs() - t0;
    p("build: legal={d} settled={d} sweeps={d} ko-sensitive region B/W={d}/{d} ({d} ms)\n", .{
        t.legal_count, t.settled_count, t.sweeps, t.ko_sensitive_b, t.ko_sensitive_w, build_ms,
    });

    if (opts.diag or opts.diag_only) {
        koSensitiveDiag(w, h, &t);
        if (opts.diag_only) return;
    }

    if (opts.finisher_budget != 0) {
        const t1 = nowMs();
        const fin = try RT.finishProgress(&t, gpa, opts.finisher_budget, opts.finisher_bracketed, opts.finisher_progress_every, opts.finisher_memo_writes, opts.finisher_deps);
        const fin_ms = nowMs() - t1;
        p("finisher[{s},{s}]: orbits solved={d} slots filled={d} budget-skipped={d} single-ko={d} nodes={d} max/root={d} bracket-fails={d} orbit-clashes={d} ({d} ms)\n", .{
            if (opts.finisher_bracketed) "bracketed" else "plain",
            if (opts.finisher_memo_writes) "reuse" else "sound",
            fin.solved, fin.filled, fin.budget_skipped, fin.single_ko, fin.nodes, fin.max_nodes, fin.bracket_fail, fin.orbit_clash, fin_ms,
        });
    } else {
        p("finisher: SKIPPED (ko-sensitive region left bracketed [L,H]; see research/retrograde-3x3.md Finding 6)\n", .{});
    }

    const t2 = nowMs();
    RT.dttPass(&t);
    const dtt_ms = nowMs() - t2;
    var dtt_far_certified: u64 = 0;
    var dtt_max: u8 = 0;
    for (0..RT.total) |i| {
        if (!t.legal[i]) continue;
        if (t.fb[i] == 0 and t.db[i] == DTT_FAR) dtt_far_certified += 1;
        if (t.fw[i] == 0 and t.dw[i] == DTT_FAR) dtt_far_certified += 1;
        if (t.db[i] != DTT_FAR and t.db[i] > dtt_max) dtt_max = t.db[i];
        if (t.dw[i] != DTT_FAR and t.dw[i] > dtt_max) dtt_max = t.dw[i];
    }
    const empty: RT.Pos = [_]i8{0} ** RT.n;
    const e_idx: usize = @intCast(RT.X.colex_from_pos(&empty));
    p("dtt: empty(B)={d} plies; max finite={d}; certified-with-FAR={d} (want 0) ({d} ms)\n", .{
        t.db[e_idx], dtt_max, dtt_far_certified, dtt_ms,
    });

    const sym = RT.checkSymmetry(&t);
    p("symmetry (exhaustive): {s} inv={d} dihedral={d} L/H-swap={d} flags={d}\n", .{
        if (sym.pass()) "PASS" else "FAIL", sym.inv_fail, sym.dih_fail, sym.lh_inv_fail, sym.flag_fail,
    });

    if (w == 3 and h == 3) {
        // published anchors (Hayward, Solving Go on Small Gobans)
        var centre: RT.Pos = [_]i8{0} ** 9;
        centre[4] = 1;
        var side_b1: RT.Pos = [_]i8{0} ** 9; // bottom-centre
        side_b1[7] = 1;
        var corner: RT.Pos = [_]i8{0} ** 9; // bottom-left
        corner[6] = 1;
        // Anchors are OPENING positions = ko-sensitive region (Finding 6). When the
        // finisher is skipped their value slot is UNDEF; report the [L,H]
        // bracket and whether it CONTAINS the published value (consistent) —
        // an exact match only when a filled value exists.
        const Anchor = struct { name: []const u8, ci: usize, black: bool, want: i8 };
        const anchors = [_]Anchor{
            .{ .name = "empty(B)", .ci = e_idx, .black = true, .want = 9 },
            .{ .name = "empty(W)", .ci = e_idx, .black = false, .want = -9 },
            .{ .name = "1.B centre", .ci = @intCast(RT.X.colex_from_pos(&centre)), .black = false, .want = 9 },
            .{ .name = "1.B side", .ci = @intCast(RT.X.colex_from_pos(&side_b1)), .black = false, .want = 3 },
            .{ .name = "1.B corner", .ci = @intCast(RT.X.colex_from_pos(&corner)), .black = false, .want = -9 },
        };
        var anchors_ok = true;
        p("anchors (published: Hayward):\n", .{});
        for (anchors) |a| {
            const v = if (a.black) t.vb[a.ci] else t.vw[a.ci];
            const lo0 = if (a.black) t.lo.b0[a.ci] else t.lo.w0[a.ci];
            const hi0 = if (a.black) t.hi.b0[a.ci] else t.hi.w0[a.ci];
            const contains = a.want >= lo0 and a.want <= hi0;
            if (!contains) anchors_ok = false;
            if (v == UNDEF) {
                p("  {s:<12} want {d:>3}: bracket [{d},{d}] {s} (ko-sensitive region, unfilled)\n", .{
                    a.name, a.want, lo0, hi0, if (contains) "CONTAINS-ok" else "OUT-OF-BRACKET-FAIL",
                });
            } else {
                if (v != a.want) anchors_ok = false;
                p("  {s:<12} want {d:>3}: value {d} {s}\n", .{
                    a.name, a.want, v, if (v == a.want) "MATCH" else "MISMATCH-FAIL",
                });
            }
        }
        p("anchors: {s}\n", .{if (anchors_ok) "PASS (all consistent)" else "FAIL"});
        var histo = [_]u64{0} ** 19;
        for (0..RT.total) |i| {
            if (t.legal[i] and t.vb[i] != UNDEF) histo[@intCast(@as(i16, t.vb[i]) + 9)] += 1;
        }
        p("value histogram (Black to move), v:-9..9:\n  ", .{});
        for (histo, 0..) |c, j| {
            if (c != 0) p("{d}:{d} ", .{ @as(i16, @intCast(j)) - 9, c });
        }
        p("\n", .{});
        // ko-sensitive region per layer
        p("ko-sensitive region per layer (B-to-move):", .{});
        for (0..RT.n + 1) |k| {
            var c: u64 = 0;
            for (RT.X.layer_offset[k]..RT.X.layer_offset[k + 1]) |ii| {
                if (t.fb[@intCast(ii)] & FLAG_KO_SENSITIVE != 0) c += 1;
            }
            if (c != 0) p(" k{d}:{d}", .{ k, c });
        }
        p("\n", .{});
    }

    if (opts.ground_truth) {
        const t3 = nowMs();
        const gt = try RT.groundTruth(&t, gpa, opts.gt_root_budget, opts.gt_entries);
        const gt_ms = nowMs() - t3;
        // SOUNDNESS = every value the exact solver could reach agrees, and
        // sits in [L,H]. COMPLETENESS = nothing left unchecked (shallow roots
        // the exact solver can't reach + ko-sensitive region the finisher didn't fill).
        // The exact solver CANNOT reach shallow roots on ANY goban (Finding
        // 3), so anything below full coverage is expected, not a failure.
        const gt_sound = gt.mismatch == 0 and gt.bracket_fail == 0;
        const gt_full = gt_sound and gt.root_skipped == 0 and gt.unfilled == 0;
        p("GROUND TRUTH (history-exact): {s} checked={d} mismatch={d} bracket-fails={d} exact-unreachable={d} ko-sensitive region-unfilled={d} states={d} ({d} ms)\n", .{
            if (!gt_sound) "FAIL (SOUNDNESS)" else if (gt_full) "PASS (complete)" else "SOUND-PARTIAL (coverage bounded by GHI; see ADR-0009)",
            gt.checked, gt.mismatch, gt.bracket_fail, gt.root_skipped, gt.unfilled, gt.states, gt_ms,
        });
    }

    if (opts.spot_min_layer) |min_layer| {
        // Independent no-memo forward check of CERTIFIED values in deep layers
        // (near-terminal, so no-memo is tractable). Ko-sensitive region is NOT spot-checked
        // here: forward search cannot tractably reach it (Finding 3/6) — it is
        // validated by the [L,H] brackets + symmetry instead.
        var ctx = RT.O.Ctx{
            .vb = try gpa.alloc(i8, RT.total),
            .vw = try gpa.alloc(i8, RT.total),
            .cb = try gpa.alloc(bool, RT.total),
            .cw = try gpa.alloc(bool, RT.total),
            .memo = false,
        };
        defer {
            gpa.free(ctx.vb);
            gpa.free(ctx.vw);
            gpa.free(ctx.cb);
            gpa.free(ctx.cw);
        }
        const hist = try gpa.create(RT.O.History);
        defer gpa.destroy(hist);
        hist.* = .{};
        var ok: u64 = 0;
        var fail: u64 = 0;
        var skip: u64 = 0;
        var seen: u64 = 0;
        const t4 = nowMs();
        // Bounded sample: even deep CERTIFIED 3x3 roots can reopen and cost
        // >>budget forward, so an exhaustive sweep is impractical (measured
        // >20 min). Sample every `stride`-th deep certified root up to `cap`.
        const stride: usize = opts.spot_stride;
        for (RT.X.layer_offset[min_layer]..RT.total) |i| {
            if (!t.legal[i]) continue;
            var pos = RT.X.pos_from_colex(i);
            inline for (.{ @as(i8, 1), @as(i8, -1) }) |side| {
                const stored = if (side > 0) t.vb[i] else t.vw[i];
                const cert = (if (side > 0) t.fb[i] else t.fw[i]) & FLAG_KO_SENSITIVE == 0;
                if (stored != UNDEF and cert) {
                    if (seen % stride == 0 and ok + fail + skip < opts.spot_cap) {
                        ctx.nodes = 0;
                        ctx.budget = opts.spot_budget;
                        if (RT.O.value_from_root(&ctx, &pos, side, hist)) |v| {
                            if (v == stored) ok += 1 else fail += 1;
                        } else |_| skip += 1;
                    }
                    seen += 1;
                }
            }
        }
        const spot_ms = nowMs() - t4;
        p("spot checks (no-memo, certified, layers>={d}, sampled {d}/{d}): {s} ok={d} fail={d} budget-skipped={d} ({d} ms)\n", .{
            min_layer, ok + fail + skip, seen, if (fail == 0) "PASS" else "FAIL", ok, fail, skip, spot_ms,
        });
    }
    p("\n", .{});
}

/// History-exact value of a position at the END of a game line (the line is
/// already in `hist`, current position on top): MTD null-window binary
/// search like ab_value_from_root, but WITHOUT resetting the history — the
/// game's superko bans constrain the search. Sound by the standing
/// discipline: bracket cuts hold under any history; certified memo seeds are
/// history-free; ko_ref blocks caching of values that depend on bans above
/// the root. Caller must reset the memo (exact + bounds) to the certified
/// baseline before EVERY call — different prefixes are different ban sets
/// (Finding 2).
fn value_from_line(comptime w: usize, comptime h: usize, t: *const Retro(w, h).Tables, ctx: *Retro(w, h).O.Ctx, pos: *const Retro(w, h).Pos, to_move: i8, hist: *Retro(w, h).O.History) error{Budget}!i8 {
    const RT = Retro(w, h);
    const idx: usize = @intCast(RT.X.colex_from_pos(pos));
    // with brackets disabled the binary search runs over the full score range
    var lo = if (!ctx.brackets) -@as(i8, @intCast(RT.n)) else if (to_move > 0) t.lo.b0[idx] else t.lo.w0[idx];
    var hi = if (!ctx.brackets) @as(i8, @intCast(RT.n)) else if (to_move > 0) t.hi.b0[idx] else t.hi.w0[idx];
    while (lo < hi) {
        const mid = lo + @divTrunc(hi - lo + 1, 2);
        ctx.saw_ban = false;
        const r = try RT.ab_solve(t, ctx, pos, to_move, 0, mid - 1, mid, hist, RT.O.fp_zero);
        if (r.value >= mid) lo = r.value else hi = r.value;
    }
    return lo;
}

/// Replay the recorded B+16 game (research/retrograde-4x4.md) and print, at
/// every juncture, the FRESH-START value vs the HISTORY-EXACT value under
/// the game's actual superko bans — answers "could White still have won,
/// given Black's actual play?".
fn runReplay(gpa: std.mem.Allocator) void {
    replay4x4(gpa) catch |err| std.debug.print("replay FAILED: {t}\n", .{err});
}

fn replay4x4(gpa: std.mem.Allocator) !void {
    const RT = Retro(4, 4);
    const p = std.debug.print;
    // the B+16 game, goban moves only (final two passes omitted)
    const game = "C3 B2 B3 C2 A2 D3 C4 A3 A4 B1 D4 A1 D2 C1 D1 B2 B1 C2 C1 B2 C2";

    var t = try RT.Tables.init(gpa);
    defer t.deinit();
    const t0 = nowMs();
    RT.seed(&t);
    RT.converge(&t);
    RT.finalize(&t);
    p("replay: build done ({d} ms). ply | move | to-move | fresh | history-exact\n", .{nowMs() - t0});

    var ctx = RT.O.Ctx{
        .vb = try gpa.alloc(i8, RT.total),
        .vw = try gpa.alloc(i8, RT.total),
        .cb = try gpa.alloc(bool, RT.total),
        .cw = try gpa.alloc(bool, RT.total),
        .lbb = try gpa.alloc(i8, RT.total),
        .ubb = try gpa.alloc(i8, RT.total),
        .lbw = try gpa.alloc(i8, RT.total),
        .ubw = try gpa.alloc(i8, RT.total),
        .memo = true,
        .budget = 2_000_000_000,
    };
    defer {
        gpa.free(ctx.vb);
        gpa.free(ctx.vw);
        gpa.free(ctx.cb);
        gpa.free(ctx.cw);
        gpa.free(ctx.lbb.?);
        gpa.free(ctx.ubb.?);
        gpa.free(ctx.lbw.?);
        gpa.free(ctx.ubw.?);
    }
    const base_cb = try gpa.alloc(bool, RT.total);
    const base_cw = try gpa.alloc(bool, RT.total);
    defer {
        gpa.free(base_cb);
        gpa.free(base_cw);
    }
    for (0..RT.total) |i| {
        base_cb[i] = t.legal[i] and t.vb[i] != UNDEF;
        base_cw[i] = t.legal[i] and t.vw[i] != UNDEF;
    }
    const hist = try gpa.create(RT.O.History);
    defer gpa.destroy(hist);
    hist.* = .{};

    const resetMemo = struct {
        fn go(c: *RT.O.Ctx, tt: *const RT.Tables, cb: []const bool, cw: []const bool) void {
            @memcpy(c.vb, tt.vb);
            @memcpy(c.vw, tt.vw);
            @memcpy(c.cb, cb);
            @memcpy(c.cw, cw);
            @memset(c.lbb.?, -127);
            @memset(c.ubb.?, 127);
            @memset(c.lbw.?, -127);
            @memset(c.ubw.?, 127);
            c.nodes = 0;
        }
    }.go;

    var pos: RT.Pos = [_]i8{0} ** 16;
    hist.push(&pos); // the initial position has occurred (PSK)
    var side: i8 = 1;
    var ply: usize = 0;
    var it = std.mem.tokenizeScalar(u8, game, ' ');
    while (it.next()) |mv| {
        // BEFORE the actual move: history-exact value of every PSK-legal
        // child for the side to move — the true best move under the real
        // game, vs what was actually played
        var best_v: i8 = if (side > 0) -127 else 127;
        var best_cell: usize = 99;
        var actual_v: i8 = -128;
        const col: usize = @intCast(std.ascii.toUpper(mv[0]) - 'A');
        const row: usize = @intCast(mv[1] - '0');
        const actual_cell = (4 - row) * 4 + col;
        for (0..16) |cell| {
            if (pos[cell] != 0) continue;
            const child = RT.R.pos_from_move(&pos, side, cell) catch continue;
            var banned = false;
            for (hist.boards[0..hist.len]) |*b| {
                if (std.mem.eql(i8, b, &child)) {
                    banned = true;
                    break;
                }
            }
            if (banned) continue;
            resetMemo(&ctx, &t, base_cb, base_cw);
            hist.push(&child);
            const cv = value_from_line(4, 4, &t, &ctx, &child, -side, hist) catch -128;
            hist.pop();
            if ((side > 0 and cv > best_v) or (side < 0 and cv < best_v)) {
                best_v = cv;
                best_cell = cell;
            }
            if (cell == actual_cell) actual_v = cv;
        }
        var bbuf: [4]u8 = undefined;
        const best_name = if (best_cell == 99) "??" else std.fmt.bufPrint(&bbuf, "{c}{d}", .{
            "ABCD"[best_cell % 4], 4 - best_cell / 4,
        }) catch "??";
        p("  ply {d:>2} | {s} to move | true best {s} = {d:>3} | played {c}{s} = {d:>3}{s}\n", .{
            ply + 1, if (side > 0) "B" else "W", best_name, best_v,
            @as(u8, if (side > 0) 'B' else 'W'), mv, actual_v,
            if (actual_v != best_v) "  <-- ERROR" else "",
        });

        pos = try RT.R.pos_from_move(&pos, side, actual_cell);
        hist.push(&pos);
        ply += 1;
        side = -side;
    }
}

/// Solve a single node (position, side, passes) to its EXACT value under the
/// history already staged in `hist` (hist top must be the node's position for
/// passes>0, or the node itself for a fresh root). Same binary-search-over-
/// brackets driver as value_from_root, but with an explicit `passes` so the
/// consistency auditor can price the pass branch (passes=1) too. With
/// ctx.brackets off the search runs over the full [-n, n] score range.
fn solveNode(comptime w: usize, comptime h: usize, t: *const Retro(w, h).Tables, ctx: *Retro(w, h).O.Ctx, pos: *const Retro(w, h).Pos, to_move: i8, passes: u8, hist: *Retro(w, h).O.History) error{Budget}!i8 {
    const RT = Retro(w, h);
    const idx: usize = @intCast(RT.X.colex_from_pos(pos));
    const nn: i8 = @intCast(RT.n);
    var lo: i8 = undefined;
    var hi: i8 = undefined;
    if (passes >= 2 or t.settled[idx]) return t.score[idx];
    if (!ctx.brackets) {
        lo = -nn;
        hi = nn;
    } else if (passes == 0) {
        lo = if (to_move > 0) t.lo.b0[idx] else t.lo.w0[idx];
        hi = if (to_move > 0) t.hi.b0[idx] else t.hi.w0[idx];
    } else {
        lo = if (to_move > 0) t.lo.b1[idx] else t.lo.w1[idx];
        hi = if (to_move > 0) t.hi.b1[idx] else t.hi.w1[idx];
    }
    while (lo < hi) {
        const mid = lo + @divTrunc(hi - lo + 1, 2);
        ctx.saw_ban = false;
        const r = try RT.ab_solve(t, ctx, pos, to_move, passes, mid - 1, mid, hist, RT.O.fp_zero);
        if (r.value >= mid) lo = r.value else hi = r.value;
    }
    return lo;
}

/// Re-seed a per-root memo/bounds context from the finalized table (the exact
/// state the finisher's runRoot starts each ko-sensitive roots from): certified
/// slots become clean cutoffs, bounds memo vacuous.
fn seedCtx(comptime w: usize, comptime h: usize, c: *Retro(w, h).O.Ctx, tt: *const Retro(w, h).Tables) void {
    const RT = Retro(w, h);
    @memcpy(c.vb, tt.vb);
    @memcpy(c.vw, tt.vw);
    for (0..RT.total) |i| {
        c.cb[i] = tt.legal[i] and tt.vb[i] != UNDEF;
        c.cw[i] = tt.legal[i] and tt.vw[i] != UNDEF;
    }
    @memset(c.lbb.?, -127);
    @memset(c.ubb.?, 127);
    @memset(c.lbw.?, -127);
    @memset(c.ubw.?, 127);
    // certified seeds are history-free: no map entry => empty dependency set,
    // always reused. Ko-sensitive region slots get a real fp on write; drop the prior
    // solve's live entries.
    if (c.dep_map) |m| m.clearRetainingCapacity();
    c.nodes = 0;
}

const ConsistOutcome = struct {
    status: enum { consistent, violation, skipped },
    parent: i8 = 0,
    best: i8 = 0,
};

/// Audit ONE node against the minimax identity under a FIXED history H=[P]:
///   V(P, side, [P]) == opt_side( { V(c, -side, [P,c]) : c legal }, pass )
/// where the pass branch is V(P, -side, [P]) at passes=1. Parent, every
/// goban child, and the pass branch are each solved as INDEPENDENT roots with
/// a freshly re-seeded ctx (so the check compares final exact values, not the
/// search's fail-soft internals). A maximizer's parent below its best option
/// (or a minimizer's above) is an outright PROOF of a bug in this variant.
fn auditNode(comptime w: usize, comptime h: usize, t: *const Retro(w, h).Tables, ctx: *Retro(w, h).O.Ctx, hist: *Retro(w, h).O.History, pos_in: *const Retro(w, h).Pos, side: i8) ConsistOutcome {
    const RT = Retro(w, h);
    var pos = pos_in.*;

    // parent as its own root under H = [P]
    seedCtx(w, h, ctx, t);
    hist.reset();
    hist.push(&pos);
    const parent = solveNode(w, h, t, ctx, &pos, side, 0, hist) catch return .{ .status = .skipped };

    // opt over PSK-legal, eye-pruned goban children under H = [P, c]
    var best: i8 = if (side > 0) -127 else 127;
    const own_alive = RT.R.benson_alive(&pos, side);
    for (0..RT.n) |cell| {
        if (pos[cell] != 0) continue;
        if (RT.R.is_own_eye(&pos, cell, side, &own_alive)) continue;
        const child = RT.R.pos_from_move(&pos, side, cell) catch continue;
        if (hist.repeatsIndex(&child) != null) continue; // PSK-illegal here
        hist.reset();
        hist.push(&pos);
        hist.push(&child); // H = [P, child]
        seedCtx(w, h, ctx, t);
        const cv = solveNode(w, h, t, ctx, &child, -side, 0, hist) catch return .{ .status = .skipped };
        if (side > 0) {
            if (cv > best) best = cv;
        } else {
            if (cv < best) best = cv;
        }
    }

    // the pass branch: opponent to move with one pass pending, still under [P]
    hist.reset();
    hist.push(&pos);
    seedCtx(w, h, ctx, t);
    const pv = solveNode(w, h, t, ctx, &pos, -side, 1, hist) catch return .{ .status = .skipped };
    if (side > 0) {
        if (pv > best) best = pv;
    } else {
        if (pv < best) best = pv;
    }

    return .{
        .status = if (parent == best) .consistent else .violation,
        .parent = parent,
        .best = best,
    };
}

fn runConsist(gpa: std.mem.Allocator) void {
    consistBoard(3, 2, gpa, 0) catch |err| std.debug.print("consist FAILED: {t}\n", .{err});
}

fn runConsist4(gpa: std.mem.Allocator) void {
    // 4x4 is far too large to audit exhaustively; sample the deepest (most
    // near-terminal, cheapest-to-solve) KO_SENSITIVE nodes first.
    consistBoard(4, 4, gpa, 400) catch |err| std.debug.print("consist4 FAILED: {t}\n", .{err});
}

fn runConsist2x2(gpa: std.mem.Allocator, max_checks: u64) void {
    consistBoard(2, 2, gpa, max_checks) catch |err| std.debug.print("consist2x2 FAILED: {t}\n", .{err});
}

fn runConsist3x3(gpa: std.mem.Allocator, max_checks: u64) void {
    // 3x3 has 12675 legal slots; deepest-first sample by default.
    consistBoard(3, 3, gpa, max_checks) catch |err| std.debug.print("consist3x3 FAILED: {t}\n", .{err});
}

/// #2 SELF-CONSISTENCY AUDITOR (docs/research/next-step-consistency-auditor.md).
/// Necessary-not-sufficient bug detector: needs no external oracle and never
/// has to brute-force the ko-tangled ko-sensitive region (that was #1, structurally dead).
/// For each variant (memo_writes ON = the committed "new" generation, OFF =
/// "soundish"), check the minimax identity at every KO_SENSITIVE 3x2 node.
/// ANY violation is a PROOF that variant is buggy; zero violations is the weak
/// (necessary) pass — it cannot crown a winner, only eliminate a loser.
fn consistBoard(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator, max_checks: u64) !void {
    const RT = Retro(w, h);
    const p = std.debug.print;
    const t0 = nowMs();
    var t = try RT.Tables.init(gpa);
    defer t.deinit();
    RT.seed(&t);
    RT.converge(&t);
    RT.finalize(&t);
    p("consist: {d}x{d} self-consistency audit (build {d} ms)\n", .{ w, h, nowMs() - t0 });
    p("  identity: V(P,side,[P]) == opt over children V(c,-side,[P,c]) and pass\n", .{});
    p("  a violation is a PROOF of a bug; zero = necessary (not sufficient) pass\n", .{});
    if (max_checks != 0)
        p("  SAMPLED: deepest {d} KO_SENSITIVE nodes per variant (not exhaustive)\n", .{max_checks});
    p("\n", .{});

    var ctx = RT.O.Ctx{
        .vb = try gpa.alloc(i8, RT.total),
        .vw = try gpa.alloc(i8, RT.total),
        .cb = try gpa.alloc(bool, RT.total),
        .cw = try gpa.alloc(bool, RT.total),
        .lbb = try gpa.alloc(i8, RT.total),
        .ubb = try gpa.alloc(i8, RT.total),
        .lbw = try gpa.alloc(i8, RT.total),
        .ubw = try gpa.alloc(i8, RT.total),
        .memo = true,
        .brackets = true,
        .budget = 2_000_000_000,
    };
    defer inline for (.{ ctx.vb, ctx.vw }) |a| gpa.free(a);
    defer inline for (.{ ctx.cb, ctx.cw }) |a| gpa.free(a);
    defer inline for (.{ ctx.lbb.?, ctx.lbw.? }) |a| gpa.free(a);
    defer inline for (.{ ctx.ubb.?, ctx.ubw.? }) |a| gpa.free(a);
    var dep_map = RT.O.DepMap.init(gpa);
    defer dep_map.deinit();
    ctx.dep_map = &dep_map;

    const hist = try gpa.create(RT.O.History);
    defer gpa.destroy(hist);
    hist.* = .{};

    const Variant = struct { name: []const u8, writes: bool, deps: bool };
    const variants = [_]Variant{
        .{ .name = "new (memo_writes ON)", .writes = true, .deps = false },
        .{ .name = "soundish (writes OFF)", .writes = false, .deps = false },
        .{ .name = "deps (guarded reuse, Track B)", .writes = true, .deps = true },
    };

    for (variants) |V| {
        ctx.memo_writes = V.writes;
        ctx.deps = V.deps;
        var checked: u64 = 0;
        var violations: u64 = 0;
        var skipped: u64 = 0;
        p("=== variant: {s} ===\n", .{V.name});
        // deepest layer first: near-terminal ko-sensitive region is cheapest to solve, so
        // a bounded sample gets the most coverage per node.
        var layer: usize = RT.n + 1;
        outer: while (layer > 0) {
            layer -= 1;
            var li: u64 = RT.X.layer_offset[layer];
            const stop = RT.X.layer_offset[layer + 1];
            while (li < stop) : (li += 1) {
                const i: usize = @intCast(li);
                if (!t.legal[i]) continue;
                var pos = RT.X.pos_from_colex(li);
                for ([_]i8{ 1, -1 }) |side| {
                    const flags = if (side > 0) t.fb[i] else t.fw[i];
                    if (flags & FLAG_KO_SENSITIVE == 0) continue;
                    const o = auditNode(w, h, &t, &ctx, hist, &pos, side);
                    switch (o.status) {
                        .skipped => skipped += 1,
                        .consistent => checked += 1,
                        .violation => {
                            checked += 1;
                            violations += 1;
                            p("  VIOLATION idx {d:>7} {c} stones {d}: parent={d} best-option={d}  ({s})\n", .{
                                i, @as(u8, if (side > 0) 'b' else 'w'), layer, o.parent, o.best,
                                if (side > 0) "max: parent < best is the bug" else "min: parent > best is the bug",
                            });
                        },
                    }
                    if (max_checks != 0 and checked + skipped >= max_checks) break :outer;
                }
            }
        }
        p("  RESULT {s}: checked={d} violations={d} skipped={d}  -> {s}\n\n", .{
            V.name, checked, violations, skipped,
            if (violations > 0) "PROVABLY BUGGY" else "self-consistent (necessary pass only)",
        });
    }
    p("reading:\n", .{});
    p("  new inconsistent, soundish consistent -> cross-branch writes are the bug; go to #3\n", .{});
    p("  both inconsistent -> hole deeper than writes (brackets/seeds); widen #3 guard\n", .{});
    p("  both consistent -> inconclusive; #3 still required for the true values\n", .{});
}

/// ADJUDICATOR for the replay probe: plain assumption-free forward solve
/// (oracle.zig O.solve with memo=false — no memo, no brackets, no certified
/// seeds; just rules + eye-prune + the REAL game history) at contested
/// junctures of the B+16 game. Slow but authoritative where it completes.
fn runVerify(gpa: std.mem.Allocator) void {
    verify4x4(gpa) catch |err| std.debug.print("verify FAILED: {t}\n", .{err});
}

fn verify4x4(gpa: std.mem.Allocator) !void {
    const RT = Retro(4, 4);
    const p = std.debug.print;
    const game = "C3 B2 B3 C2 A2 D3 C4 A3 A4 B1 D4 A1 D2 C1 D1 B2 B1 C2 C1 B2 C2";
    // junctures = position BEFORE the k-th move (1-indexed), i.e. after k-1
    // moves. 11: the ply-10/11 contradiction; 13/14: the verdict junctures.
    const junctures = [_]usize{ 11, 13, 14 };

    var ctx = RT.O.Ctx{
        .vb = try gpa.alloc(i8, 1),
        .vw = try gpa.alloc(i8, 1),
        .cb = try gpa.alloc(bool, 1),
        .cw = try gpa.alloc(bool, 1),
        .memo = false, // assumption-free: pure history-correct search
    };
    defer {
        gpa.free(ctx.vb);
        gpa.free(ctx.vw);
        gpa.free(ctx.cb);
        gpa.free(ctx.cw);
    }
    const hist = try gpa.create(RT.O.History);
    defer gpa.destroy(hist);
    hist.* = .{};

    var pos: RT.Pos = [_]i8{0} ** 16;
    hist.push(&pos);
    var side: i8 = 1;
    var moves_done: usize = 0;
    var it = std.mem.tokenizeScalar(u8, game, ' ');
    while (it.next()) |mv| {
        for (junctures) |j| {
            if (j == moves_done + 1) {
                ctx.nodes = 0;
                ctx.budget = 4_000_000_000;
                const t0 = nowMs();
                const r = RT.O.solve(&ctx, &pos, side, 0, hist);
                if (r) |res| {
                    p("juncture {d} ({s} to move, after {d} moves): PLAIN history value = {d}  (nodes {d}, {d} ms)\n", .{
                        j, if (side > 0) "B" else "W", moves_done, res.value, ctx.nodes, nowMs() - t0,
                    });
                } else |_| {
                    p("juncture {d} ({s} to move): BUDGET-EXCEEDED (> {d} nodes, {d} ms)\n", .{
                        j, if (side > 0) "B" else "W", ctx.budget, nowMs() - t0,
                    });
                }
            }
        }
        const col: usize = @intCast(std.ascii.toUpper(mv[0]) - 'A');
        const row: usize = @intCast(mv[1] - '0');
        pos = try RT.R.pos_from_move(&pos, side, (4 - row) * 4 + col);
        hist.push(&pos);
        moves_done += 1;
        side = -side;
    }
}

fn run6x3(gpa: std.mem.Allocator) void {
    saveArtifact(6, 3, gpa, "data/oracle-6x3.wzo", 20_000_000, 100_000, true, "data/oracle-6x3.checkpoint.wzo", true, false, false) catch |err| {
        std.debug.print("6x3 run FAILED: {t}\n", .{err});
    };
}

fn run4x4(gpa: std.mem.Allocator) void {
    // Finisher mode (ADR-0013): RETRO_DEPS=1 -> Track B fingerprint-guarded
    // reuse (sound AND fast); RETRO_SOUND=1 -> Track A writes-off (sound, slow);
    // neither -> fast legacy reuse (unsound ko-sensitive region). deps implies writes on.
    const deps_4x4 = std.c.getenv("RETRO_DEPS") != null;
    const memo_writes_4x4 = deps_4x4 or (std.c.getenv("RETRO_SOUND") == null);
    // per-root node budget (RETRO_BUDGET, default 20M). Higher lets the hard
    // opening roots complete instead of budget-skipping.
    const budget_4x4: u64 = if (std.c.getenv("RETRO_BUDGET")) |b|
        (std.fmt.parseInt(u64, std.mem.span(b), 10) catch 20_000_000)
    else
        20_000_000;
    // T14.1 / T14.2 env overrides (Minimax-m3, 2026-07-26): allow dispatching
    // a writes-off regen run that does NOT clobber the committed paths.
    //   RETRO_4X4_OUT        — override the final artifact path (default unchanged)
    //   RETRO_4X4_CKPT       — override the checkpoint path (default unchanged)
    //   RETRO_4X4_SKIP_FINISHER=1 — skip the ko-sensitive finisher and persist
    //                              the build-only bracket artifact (T14.1).
    const out_path: []const u8 = if (std.c.getenv("RETRO_4X4_OUT")) |p| std.mem.span(p) else "data/oracle-4x4.wzo";
    const ckpt_path: []const u8 = if (std.c.getenv("RETRO_4X4_CKPT")) |p| std.mem.span(p) else "data/oracle-4x4.checkpoint.wzo";
    const skip_finisher = std.c.getenv("RETRO_4X4_SKIP_FINISHER") != null;
    // T14.1 (converge only): the build is the single-score census (no
    // finisher, no checkpoint loop). fin_budget is set to 1 just so saveArtifact
    // does not trip the zero-budget guard; SKIP_FINISHER keeps the finisher
    // entirely out of the pipeline.
    // T14.2 (finisher chunks): leave RETRO_4X4_SKIP_FINISHER unset, the
    // original 20M/root budget and per-layer checkpoint apply.
    const diag = !skip_finisher;
    const fin_budget: u64 = if (skip_finisher) 1 else budget_4x4;
    const progress_every: u64 = if (skip_finisher) 0 else 25_000;
    const ckpt_arg: ?[]const u8 = if (skip_finisher) null else ckpt_path;
    // Full pipeline WITH persistence: a checkpoint after every finished
    // layer (resumable — rerun and it picks up where it stopped), final
    // artifact only if complete. data/ is gitignored (~258 MB files).
    // Budget 20M: MEASURED (2026-07-21) — the empty 4x4 root exceeds 500M
    // nodes (146 s); deep-opening ko-sensitive region is not crackable by budget at
    // this size, so hopeless roots must fail FAST (~6 s each). Layers run
    // deepest-first, so the tractable bulk is solved and checkpointed
    // before the opening tail is even attempted.
    saveArtifact(4, 4, gpa, out_path, fin_budget, progress_every, diag, ckpt_arg, memo_writes_4x4, deps_4x4, skip_finisher) catch |err| {
        std.debug.print("4x4 run FAILED: {t}\n", .{err});
    };
}

/// Parallel writes-off finisher pipeline (B31).
///
/// Env vars:
///   RETRO_PARALLEL=1           — enable parallel mode
///   RETRO_PARALLEL_THREADS=N   — thread count (default: CPU count)
///   RETRO_PARALLEL_CKPT=path   — checkpoint path
///   RETRO_PARALLEL_OUT=path    — output artifact path
///   RETRO_4X4=1                — run on 4x4 (alongside RETRO_PARALLEL)
///   RETRO_3X3=1                — run on 3x3 (test: 1 vs N threads)
///   RETRO_4X3=1                — run on 4x3 (the T930 measured rung)
///   RETRO_SOUND=1              — Track A writes-off (memo_writes=false)
///   RETRO_DEPS=1               — Track B dependency-guarded reuse
///   RETRO_PARTITION=contig     — legacy contiguous chunks (default round-robin)
///   RETRO_PARALLEL_BUDGET=N    — per-root node budget (default: 20M)
fn runParallel(gpa: std.mem.Allocator) void {
    const num_threads: u8 = if (std.c.getenv("RETRO_PARALLEL_THREADS")) |s|
        @intCast((std.fmt.parseInt(u8, std.mem.span(s), 10) catch 0))
    else
        0;

    const deps = std.c.getenv("RETRO_DEPS") != null;
    const memo_writes = deps or (std.c.getenv("RETRO_SOUND") == null);
    // RETRO_PARTITION=contig restores the legacy contiguous chunking (the
    // seeded-defect control and A/B measurement); the default is round-robin.
    const round_robin = if (std.c.getenv("RETRO_PARTITION")) |s|
        !std.mem.eql(u8, std.mem.span(s), "contig")
    else
        true;
    const budget: u64 = if (std.c.getenv("RETRO_PARALLEL_BUDGET")) |b|
        (std.fmt.parseInt(u64, std.mem.span(b), 10) catch 20_000_000)
    else
        20_000_000;
    const progress_every: u64 = if (std.c.getenv("RETRO_PARALLEL_PROGRESS")) |s|
        (std.fmt.parseInt(u64, std.mem.span(s), 10) catch 1000)
    else
        1000;

    // Install SIGINT handler for graceful interrupt
    installParallelSigint();

    var threaded = std.Io.Threaded.init(gpa, .{});
    const io = threaded.io();
    const dir = std.Io.Dir.cwd();

    // Dispatch by goban size
    if (std.c.getenv("RETRO_3X3") != null) {
        parallelBoard(3, 3, gpa, io, dir, budget, memo_writes, deps, num_threads, progress_every, round_robin);
    } else if (std.c.getenv("RETRO_4X3") != null) {
        parallelBoard(4, 3, gpa, io, dir, budget, memo_writes, deps, num_threads, progress_every, round_robin);
    } else {
        parallelBoard(4, 4, gpa, io, dir, budget, memo_writes, deps, num_threads, progress_every, round_robin);
    }
}

/// Build + converge + finalize, then run the parallel finisher, checkpoint,
/// dtt, symmetry, and persist the artifact.
fn parallelBoard(
    comptime w: usize,
    comptime h: usize,
    gpa: std.mem.Allocator,
    io: std.Io,
    dir: std.Io.Dir,
    budget: u64,
    memo_writes: bool,
    deps: bool,
    num_threads: u8,
    progress_every: u64,
    round_robin: bool,
) void {
    const RT = Retro(w, h);
    const p = std.debug.print;

    const ckpt_path: []const u8 = if (std.c.getenv("RETRO_PARALLEL_CKPT")) |p2|
        std.mem.span(p2)
    else blk: {
        var buf: [64]u8 = undefined;
        break :blk std.fmt.bufPrint(&buf, "data/oracle-{d}x{d}-parallel.checkpoint.wzo", .{ w, h }) catch unreachable;
    };
    const out_path: []const u8 = if (std.c.getenv("RETRO_PARALLEL_OUT")) |p2|
        std.mem.span(p2)
    else blk: {
        var buf: [64]u8 = undefined;
        break :blk std.fmt.bufPrint(&buf, "data/oracle-{d}x{d}-parallel.wzo", .{ w, h }) catch unreachable;
    };

    const nt = if (num_threads == 0) @as(u8, @intCast((std.Thread.getCpuCount() catch 1))) else num_threads;

    p("==== parallel artifact {d}x{d} -> {s} ====\n", .{ w, h, out_path });
    p("  threads={d} budget={d} memo_writes={s} deps={s} ckpt={s}\n", .{
        nt, budget,
        if (memo_writes) "reuse" else "sound",
        if (deps) "yes" else "no",
        ckpt_path,
    });

    const header = artifact.Header{
        .board_w = w,
        .board_h = h,
        .total = RT.X.total,
        .legal_count = 0,
    };

    var t = RT.Tables.init(gpa) catch {
        p("parallelBoard: OOM during Tables.init\n", .{});
        return;
    };
    defer t.deinit();

    // -- Build (single-threaded) --
    const t0 = nowMs();
    RT.seed(&t);
    RT.converge(&t);
    RT.finalize(&t);
    p("build: legal={d} settled={d} sweeps={d} ko-sensitive B/W={d}/{d} ({d}ms)\n", .{
        t.legal_count, t.settled_count, t.sweeps, t.ko_sensitive_b, t.ko_sensitive_w, nowMs() - t0,
    });

    var hdr = header;
    hdr.legal_count = t.legal_count;

    // -- Checkpoint resume --
    if (artifact.load(io, dir, ckpt_path, gpa)) |loaded| {
        var d = loaded;
        defer d.deinit();
        if (d.header.board_w == w and d.header.board_h == h) {
            @memcpy(t.vb, d.vb);
            @memcpy(t.vw, d.vw);
            @memcpy(t.fb, d.fb);
            @memcpy(t.fw, d.fw);
            // RETRO_PARALLEL_RETRY=1 clears TRIED_SKIP so budget-skipped
            // positions are re-attempted (e.g. with a larger budget).
            if (std.c.getenv("RETRO_PARALLEL_RETRY") != null) {
                for (0..RT.total) |i| {
                    t.fb[i] &= ~FLAG_TRIED_SKIP;
                    t.fw[i] &= ~FLAG_TRIED_SKIP;
                }
            }
            var done: u64 = 0;
            var skipped: u64 = 0;
            for (0..RT.total) |i| {
                if (t.fb[i] & FLAG_FROM_FORWARD != 0) done += 1;
                if (t.fw[i] & FLAG_FROM_FORWARD != 0) done += 1;
                if (t.fb[i] & FLAG_TRIED_SKIP != 0) skipped += 1;
                if (t.fw[i] & FLAG_TRIED_SKIP != 0) skipped += 1;
            }
            p("resume: {s} loaded — {d} finished, {d} skip-marked\n", .{ ckpt_path, done, skipped });
        } else {
            p("resume: {s} board-size mismatch, starting fresh\n", .{ckpt_path});
        }
    } else |_| {
        p("resume: no checkpoint at {s}, starting fresh\n", .{ckpt_path});
    }

    // -- Parallel finisher --
    const t1 = nowMs();
    parallel_interrupt.store(false, .release);

    const fin = RT.finishParallel(&t, gpa, budget, true, progress_every, memo_writes, deps, num_threads, round_robin) catch |err| {
        p("finishParallel FAILED: {t}\n", .{err});
        return;
    };

    p("finisher[parallel,{s}]: solved={d} filled={d} skipped={d} single-ko={d} nodes={d} max/root={d} ({d}ms)\n", .{
        if (deps) "deps" else if (memo_writes) "reuse" else "sound",
        fin.solved, fin.filled, fin.budget_skipped, fin.single_ko, fin.nodes, fin.max_nodes, nowMs() - t1,
    });

    // -- Checkpoint after finisher --
    artifact.save(io, dir, ckpt_path, gpa, hdr, .{
        .vb = t.vb, .vw = t.vw, .fb = t.fb, .fw = t.fw, .db = t.db, .dw = t.dw,
    }) catch |err| {
        p("checkpoint save FAILED: {t}\n", .{err});
    };
    p("checkpoint: {s} written (solved={d} skipped={d})\n", .{ ckpt_path, fin.solved, fin.budget_skipped });

    if (parallel_interrupt.load(.acquire)) {
        p("INTERRUPTED — checkpoint saved. Re-run to resume.\n", .{});
        return;
    }

    // -- dtt + symmetry + artifact --
    const t2 = nowMs();
    RT.dttPass(&t);
    const sym = RT.checkSymmetry(&t);
    var undef_legal: u64 = 0;
    for (0..RT.total) |i| {
        if (t.legal[i] and (t.vb[i] == UNDEF or t.vw[i] == UNDEF)) undef_legal += 1;
    }
    p("validate: bracket-fails={d} orbit-clashes={d} symmetry={s} unfilled={d} (dtt+sym {d}ms)\n", .{
        fin.bracket_fail, fin.orbit_clash, if (sym.pass()) "PASS" else "FAIL", undef_legal, nowMs() - t2,
    });

    if (!sym.pass() or fin.bracket_fail != 0 or fin.orbit_clash != 0) {
        p("artifact: REFUSED — validation failed\n", .{});
        return;
    }

    if (undef_legal != 0) {
        p("artifact: PARTIAL — {d} unfilled. Checkpoint={s}\n", .{ undef_legal, ckpt_path });
        return;
    }

    artifact.save(io, dir, out_path, gpa, hdr, .{ .vb = t.vb, .vw = t.vw, .fb = t.fb, .fw = t.fw, .db = t.db, .dw = t.dw }) catch |err| {
        p("artifact save FAILED: {t}\n", .{err});
        return;
    };

    var d = artifact.load(io, dir, out_path, gpa) catch |err| {
        p("artifact reload FAILED: {t}\n", .{err});
        return;
    };
    defer d.deinit();
    const identical = std.mem.eql(i8, d.vb, t.vb) and std.mem.eql(i8, d.vw, t.vw) and
        std.mem.eql(u8, d.fb, t.fb) and std.mem.eql(u8, d.fw, t.fw) and
        std.mem.eql(u8, d.db, t.db) and std.mem.eql(u8, d.dw, t.dw);
    p("reload: {s}; artifact OK ({d} bytes)\n\n", .{
        if (identical) "IDENTICAL" else "MISMATCH",
        artifact.HEADER_LEN + 6 * RT.total,
    });
    if (!identical) {
        p("artifact: RELOAD MISMATCH!\n", .{});
    }
}

/// CENSUS (5x5 projection): build each goban through seed+converge+finalize
/// only (NO finisher — this is the cheap history-free part) and report the
/// numbers that drive the 5x5 feasibility question: legal-position count
/// (final table size), certified vs KO_SENSITIVE ko-sensitive region split and its
/// fraction (does the hard part grow?), and convergence sweeps + wall time
/// (out-of-core sweep cost). See docs/research/methods-and-findings.md sec 8.
fn censusBoard(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator) !void {
    const RT = Retro(w, h);
    const p = std.debug.print;
    const raw: u64 = RT.total;
    const t0 = nowMs();
    var t = try RT.Tables.init(gpa);
    defer t.deinit();
    RT.seed(&t);
    RT.converge(&t);
    RT.finalize(&t);
    const ms = nowMs() - t0;
    // ko-sensitive region = KO_SENSITIVE slots (per side); certified = legal-but-not-ko-sensitive region
    var res_b: u64 = 0;
    var res_w: u64 = 0;
    for (0..RT.total) |i| {
        if (!t.legal[i]) continue;
        if (t.fb[i] & FLAG_KO_SENSITIVE != 0) res_b += 1;
        if (t.fw[i] & FLAG_KO_SENSITIVE != 0) res_w += 1;
    }
    const res = res_b + res_w;
    const slots = t.legal_count * 2; // both sides
    const pct = if (slots != 0) @as(f64, @floatFromInt(res)) * 100.0 / @as(f64, @floatFromInt(slots)) else 0;
    p("{d}x{d}: raw 3^n={d:>12}  legal={d:>11} ({d:>2}% of raw)  settled={d:>11}\n", .{
        w, h, raw, t.legal_count, t.legal_count * 100 / raw, t.settled_count,
    });
    p("       side-slots={d:>11}  ko-sensitive region(KO) B/W={d}/{d} = {d} ({d:.4}% of slots)  sweeps={d}  build={d} ms\n", .{
        slots, res_b, res_w, res, pct, t.sweeps, ms,
    });
}

/// BRACKET report (Option B, the honest scalable deliverable). After
/// converge/finalize the L and H fixpoints bracket every node's value under
/// ANY cycle convention whose cycle-value lies in [-N,N] (PSK, basic-ko,
/// score-on-cycle-as-is, kill-X%, ...). Where L==H the value is a fresh-start single score and
/// rule-independent (no finisher, no ko rule needed). Where L<H the value is
/// convention-dependent and provably lies in [L,H]. This reports the certified
/// core, the empty-goban bracket (the headline), and the ko-sensitive region bracket-width
/// distribution — all sound, no finisher.
fn bracketBoard(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator) !void {
    const RT = Retro(w, h);
    const p = std.debug.print;
    const t0 = nowMs();
    var t = try RT.Tables.init(gpa);
    defer t.deinit();
    RT.seed(&t);
    RT.converge(&t);
    RT.finalize(&t);
    const ms = nowMs() - t0;

    var certified: u64 = 0;
    var ko_sensitive: u64 = 0;
    // width histogram: index = hi-lo (0..2N), only ko-sensitive region (width>0) counted
    var width_hist = [_]u64{0} ** (2 * RT.n + 1);
    var max_width: i16 = 0;
    for (0..RT.total) |i| {
        if (!t.legal[i] or t.settled[i]) continue;
        inline for (.{ .{ t.lo.b0, t.hi.b0 }, .{ t.lo.w0, t.hi.w0 } }) |c| {
            const lo = c[0][i];
            const hi = c[1][i];
            if (lo == hi) {
                certified += 1;
            } else {
                ko_sensitive += 1;
                const wdt: usize = @intCast(@as(i16, hi) - @as(i16, lo));
                width_hist[wdt] += 1;
                if (@as(i16, hi) - @as(i16, lo) > max_width) max_width = @as(i16, hi) - @as(i16, lo);
            }
        }
    }
    // settled slots are trivially certified (lo==hi==score); fold them in for
    // the headline core fraction, since they are exact rule-independent too.
    certified += t.settled_count * 2;
    const slots = t.legal_count * 2;
    const core_pct = @as(f64, @floatFromInt(certified)) * 100.0 / @as(f64, @floatFromInt(slots));

    const e: usize = @intCast(RT.X.colex_from_pos(&([_]i8{0} ** RT.n)));
    const elo = t.lo.b0[e];
    const ehi = t.hi.b0[e];

    p("{d}x{d}: slots={d}  single-score={d} ({d:.2}%)  ko_sensitive={d}  sweeps={d}  build={d}ms\n", .{
        w, h, slots, certified, core_pct, ko_sensitive, t.sweeps, ms,
    });
    if (elo == ehi) {
        p("       empty(B) single-score = {d} (fresh-start)\n", .{elo});
    } else {
        p("       empty(B) bracket = [{d}, {d}]  (width {d}; value is convention-dependent)\n", .{ elo, ehi, @as(i16, ehi) - @as(i16, elo) });
    }
    p("       ko-sensitive region bracket-width histogram (width: count):", .{});
    for (width_hist, 0..) |cnt, wdt| {
        if (cnt != 0) p(" {d}:{d}", .{ wdt, cnt });
    }
    p("\n", .{});
}

fn runBracket(gpa: std.mem.Allocator) void {
    const p = std.debug.print;
    p("BRACKET: fresh-start single-score region + [L,H] ko-sensitive region bracket (no finisher)\n", .{});
    bracketBoard(3, 3, gpa) catch |e| p("  3x3 FAILED: {t}\n", .{e});
    bracketBoard(4, 3, gpa) catch |e| p("  4x3 FAILED: {t}\n", .{e});
    bracketBoard(4, 4, gpa) catch |e| p("  4x4 FAILED: {t}\n", .{e});
}

/// FAIL-FAST throughput comparison: build a goban once, then run the ko-sensitive region
/// finisher twice on fresh certified tables — fast REUSE path vs SOUND
/// (writes-off) path — and report wall time, slots filled, and budget-skips.
/// Quantifies the cost of dropping the (unsound) cross-branch reuse, the
/// number that decides whether Track A alone can scale (ADR-0013).
fn finishCompare(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator, budget: u64) !void {
    const RT = Retro(w, h);
    const p = std.debug.print;
    p("finish-compare {d}x{d} (budget {d}/root): reuse=fast/unsound, sound=writes-off, deps=Track B guarded reuse\n", .{ w, h, budget });
    const Mode = struct { name: []const u8, writes: bool, deps: bool };
    inline for (.{
        Mode{ .name = "reuse", .writes = true, .deps = false },
        Mode{ .name = "sound", .writes = false, .deps = false },
        Mode{ .name = "deps ", .writes = true, .deps = true },
    }) |m| {
        var t = try RT.Tables.init(gpa);
        defer t.deinit();
        RT.seed(&t);
        RT.converge(&t);
        RT.finalize(&t);
        const t0 = nowMs();
        const fin = try RT.finishProgress(&t, gpa, budget, true, 0, m.writes, m.deps);
        const ms = nowMs() - t0;
        var unfilled: u64 = 0;
        for (0..RT.total) |i| {
            if (t.legal[i] and (t.vb[i] == UNDEF or t.vw[i] == UNDEF)) unfilled += 1;
        }
        p("  [{s}] solved={d} filled={d} skipped={d} unfilled={d} nodes={d} max/root={d}  {d} ms\n", .{
            m.name, fin.solved, fin.filled, fin.budget_skipped, unfilled, fin.nodes, fin.max_nodes, ms,
        });
    }
}

fn runCompare(gpa: std.mem.Allocator) void {
    finishCompare(3, 3, gpa, 500_000_000) catch |e| std.debug.print("cmp 3x3 FAILED: {t}\n", .{e});
    finishCompare(4, 3, gpa, 200_000_000) catch |e| std.debug.print("cmp 4x3 FAILED: {t}\n", .{e});
}

/// CORRECTNESS gate for Track B: finish the same goban two ways — sound
/// (writes-off) and deps (fingerprint-guarded reuse) — and compare every
/// filled value slot. They MUST be identical: deps is only sound if it
/// reproduces the writes-off values exactly. (The auditor proves
/// self-consistency; this proves value-equality with the trusted baseline.)
fn depsValidate(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator, budget: u64) !void {
    const RT = Retro(w, h);
    const p = std.debug.print;
    var ts = try RT.Tables.init(gpa);
    defer ts.deinit();
    RT.seed(&ts);
    RT.converge(&ts);
    RT.finalize(&ts);
    _ = try RT.finishProgress(&ts, gpa, budget, true, 0, false, false); // sound

    var td = try RT.Tables.init(gpa);
    defer td.deinit();
    RT.seed(&td);
    RT.converge(&td);
    RT.finalize(&td);
    _ = try RT.finishProgress(&td, gpa, budget, true, 0, true, true); // deps

    var mism: u64 = 0;
    var checked: u64 = 0;
    for (0..RT.total) |i| {
        if (!ts.legal[i]) continue;
        inline for (.{ true, false }) |black| {
            const a = if (black) ts.vb[i] else ts.vw[i];
            const b = if (black) td.vb[i] else td.vw[i];
            if (a != UNDEF or b != UNDEF) {
                checked += 1;
                if (a != b) {
                    mism += 1;
                    if (mism <= 10) p("  MISMATCH idx {d} {c}: sound={d} deps={d}\n", .{ i, @as(u8, if (black) 'b' else 'w'), a, b });
                }
            }
        }
    }
    p("deps-validate {d}x{d}: checked={d} mismatches={d}  -> {s}\n", .{
        w, h, checked, mism, if (mism == 0) "IDENTICAL (deps correct)" else "DIVERGED (deps BUGGY)",
    });
}

fn runDepsVal(gpa: std.mem.Allocator) void {
    depsValidate(3, 2, gpa, 500_000_000) catch |e| std.debug.print("depsval 3x2 FAILED: {t}\n", .{e});
    depsValidate(3, 3, gpa, 500_000_000) catch |e| std.debug.print("depsval 3x3 FAILED: {t}\n", .{e});
    depsValidate(4, 3, gpa, 200_000_000) catch |e| std.debug.print("depsval 4x3 FAILED: {t}\n", .{e});
}

/// RULES experiment (sanity tier): solve the EMPTY goban with the exact
/// PSK solver, kill_pct = 0 (pure PSK) vs 50 (kill->immediate scored end), and
/// report the value + search size. Answers: (a) does kill-50 change the true
/// value? (b) does the kill rule make the otherwise-explosive exact solve
/// terminate? Tiny gobans only (exact PSK is intractable beyond ~3x3).
fn rulesBoard(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator, budget: u64) void {
    const EX = Exact(w, h);
    const p = std.debug.print;
    for ([_]u8{ 0, 50 }) |kill| {
        var ctx = EX.Ctx{ .map = EX.Map.init(gpa), .budget = budget, .kill_pct = kill };
        defer ctx.map.deinit();
        var empty: EX.R.Pos = [_]i8{0} ** (w * h);
        ctx.nodes = 0;
        const rb = EX.root(&ctx, &empty, 1);
        const bnodes = ctx.nodes;
        const states = ctx.map.count();
        if (rb) |v| {
            p("  {d}x{d} kill={d:>2}%: empty(B) = {d:>3}  (nodes {d}, states {d})\n", .{ w, h, kill, v, bnodes, states });
        } else |_| {
            p("  {d}x{d} kill={d:>2}%: empty(B) = BUDGET-EXCEEDED (> {d} nodes, states {d})\n", .{ w, h, kill, budget, states });
        }
    }
}

fn runRules(gpa: std.mem.Allocator) void {
    const p = std.debug.print;
    p("RULES: exact PSK, kill_pct 0 vs 50, empty-board value (sanity tier)\n", .{});
    rulesBoard(2, 2, gpa, 200_000_000);
    rulesBoard(3, 2, gpa, 200_000_000);
    rulesBoard(3, 3, gpa, 200_000_000);
    rulesBoard(4, 3, gpa, 200_000_000);
}

/// Option B probe: exact empty-goban value under basic-ko + score-on-cycle
/// (the game ends and is scored AS-IS the first time a longer cycle would
/// repeat an earlier goban). Reported side by side with pure PSK so we can
/// see (a) whether the rule changes the value and (b) whether it is any more
/// tractable than PSK. History-dependent, so a values probe, not generation.
fn cycleBoard(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator, budget: u64) void {
    const EX = Exact(w, h);
    const p = std.debug.print;
    const Row = struct { label: []const u8, cyc: bool };
    for ([_]Row{ .{ .label = "PSK        ", .cyc = false }, .{ .label = "basic+cycle", .cyc = true } }) |row| {
        var ctx = EX.Ctx{ .map = EX.Map.init(gpa), .budget = budget, .cycle_score = row.cyc };
        defer ctx.map.deinit();
        var empty: EX.R.Pos = [_]i8{0} ** (w * h);
        ctx.nodes = 0;
        const rb = EX.root(&ctx, &empty, 1);
        if (rb) |v| {
            p("  {d}x{d} {s}: empty(B) = {d:>3}  (nodes {d}, states {d})\n", .{ w, h, row.label, v, ctx.nodes, ctx.map.count() });
        } else |_| {
            p("  {d}x{d} {s}: empty(B) = BUDGET-EXCEEDED (> {d} nodes, states {d})\n", .{ w, h, row.label, budget, ctx.map.count() });
        }
    }
}

fn runCycle(gpa: std.mem.Allocator) void {
    const p = std.debug.print;
    p("CYCLE: exact empty-board value, PSK vs basic-ko + score-on-cycle-as-is\n", .{});
    cycleBoard(2, 2, gpa, 200_000_000);
    cycleBoard(3, 2, gpa, 200_000_000);
    cycleBoard(3, 3, gpa, 200_000_000);
    cycleBoard(4, 3, gpa, 200_000_000);
}

/// N-PLY SWEEP (the agreed experiment): exact empty-goban value + tractability
/// under the bounded-history superko family. For each N in {1,2,4,6,8} a move
/// may not recreate any of the last N gobans, and a repeat OLDER than the
/// window ends the game scored by area. N=1 is basic ko; large N approaches
/// PSK. We watch two things: (1) does the VALUE converge toward the PSK anchor
/// as N grows? (2) does small N stay TRACTABLE (score-on-cycle ends games
/// early, potentially pruning the tree PSK can't prune)?
fn plyBoard(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator, budget: u64) void {
    const EX = Exact(w, h);
    const p = std.debug.print;
    var empty: EX.R.Pos = [_]i8{0} ** (w * h);

    // PSK anchor (unbounded superko, no score-on-cycle)
    {
        var ctx = EX.Ctx{ .map = EX.Map.init(gpa), .budget = budget, .entry_cap = 5_000_000, .cycle_score = false };
        defer ctx.map.deinit();
        const rb = EX.root(&ctx, &empty, 1);
        if (rb) |v| {
            p("  {d}x{d} PSK   : empty(B) = {d:>3}  (nodes {d}, states {d})\n", .{ w, h, v, ctx.nodes, ctx.map.count() });
        } else |_| {
            p("  {d}x{d} PSK   : empty(B) = BUDGET (> {d} nodes, states {d})\n", .{ w, h, budget, ctx.map.count() });
        }
    }
    // N-ply window + score-on-cycle
    for ([_]usize{ 1, 2, 4, 6, 8 }) |ply| {
        if (ply > EX.MAX_KO_PLY) continue;
        var ctx = EX.Ctx{ .map = EX.Map.init(gpa), .budget = budget, .entry_cap = 5_000_000, .cycle_score = true, .ko_ply = ply };
        defer ctx.map.deinit();
        const rb = EX.root(&ctx, &empty, 1);
        if (rb) |v| {
            p("  {d}x{d} {d}-ply : empty(B) = {d:>3}  (nodes {d}, states {d})\n", .{ w, h, ply, v, ctx.nodes, ctx.map.count() });
        } else |_| {
            p("  {d}x{d} {d}-ply : empty(B) = BUDGET (> {d} nodes, states {d})\n", .{ w, h, ply, budget, ctx.map.count() });
        }
    }
}

fn runPly(gpa: std.mem.Allocator) void {
    const p = std.debug.print;
    p("N-PLY SWEEP: exact empty-board value + tractability, N in {{1,2,4,6,8}} vs PSK\n", .{});
    p("  (N-ply = ban last N boards; older repeat scores as-is; N=1 basic ko, N->inf PSK)\n", .{});
    plyBoard(2, 2, gpa, 200_000_000);
    plyBoard(3, 2, gpa, 200_000_000);
    plyBoard(3, 3, gpa, 200_000_000);
}

/// KILL-CENSUS: retrograde build-only census with a given kill_pct, reporting
/// how the ko-sensitive region (KO_SENSITIVE) fraction responds to the kill-X% rule. The
/// retrograde engine is tractable at 4x4 (unlike the exact solver), so this is
/// how we measure the kill rule where it matters.
fn killCensusBoard(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator, kill_pct: u8) !void {
    const RT = Retro(w, h);
    const p = std.debug.print;
    const t0 = nowMs();
    var t = try RT.Tables.init(gpa);
    defer t.deinit();
    t.kill_pct = kill_pct;
    RT.seed(&t);
    RT.converge(&t);
    RT.finalize(&t);
    var res: u64 = 0;
    for (0..RT.total) |i| {
        if (!t.legal[i]) continue;
        if (t.fb[i] & FLAG_KO_SENSITIVE != 0) res += 1;
        if (t.fw[i] & FLAG_KO_SENSITIVE != 0) res += 1;
    }
    const slots = t.legal_count * 2;
    const pct = @as(f64, @floatFromInt(res)) * 100.0 / @as(f64, @floatFromInt(slots));
    const e: usize = @intCast(RT.X.colex_from_pos(&([_]i8{0} ** RT.n)));
    const cert = t.fb[e] & FLAG_KO_SENSITIVE == 0;
    p("{d}x{d} kill={d:>3}%: ko_sensitive={d}/{d} ({d:.4}%) sweeps={d} empty(B)={s} build={d}ms\n", .{
        w, h, kill_pct, res, slots, pct, t.sweeps,
        if (cert) "certified" else "still-ko-sensitive region", nowMs() - t0,
    });
}

fn runKillCensus(gpa: std.mem.Allocator) void {
    const p = std.debug.print;
    p("KILL-CENSUS 4x4: ko-sensitive fraction vs kill_pct (kill=0 baseline = 21.32%)\n", .{});
    inline for (.{ @as(u8, 0), 50, 40, 30 }) |k| {
        killCensusBoard(4, 4, gpa, k) catch |e| p("  4x4 kill={d} FAILED: {t}\n", .{ k, e });
    }
}

fn runCensus(gpa: std.mem.Allocator) void {
    const p = std.debug.print;
    p("CENSUS: history-free build only (no finisher). Ko-sensitive region = the hard part.\n\n", .{});
    inline for (.{ .{ 2, 2 }, .{ 3, 2 }, .{ 3, 3 }, .{ 4, 3 }, .{ 4, 4 } }) |b| {
        censusBoard(b[0], b[1], gpa) catch |err| p("  {d}x{d} FAILED: {t}\n", .{ b[0], b[1], err });
    }
}


/// E2 (leak-crisis, 2026-07-25): range-aware self-play. Both players play the
/// lo-game (Black maximizes lo[child], White minimizes lo[child]) with REAL
/// PSK legality (a move recreating any prior goban is illegal). The audited
/// colour records a promise = the lo-floor of the move it chose; a game leaks
/// if the final score is worse than the strongest promise. Zero leaks => lo is
/// a true lower bound (C3 supported). In-memory converge (no artifact: the
/// artifact does not store lo/hi). See docs/status/leak-crisis.md.
/// E3 (leak-crisis): exact history-aware cross-check of a leaking self-play
/// line. Replays the game to the ply where the strongest promise was made,
/// then walks the self-play line to the end; at each position compares the
/// table's `lo` (claimed lower bound, ban-set-independent) to the TRUE value
/// from the exact PSK solver with the actual ban set. `true < lo` => the
/// bracket is not a sound real-game bound (C3 false) OR `lo` is mis-computed.
/// See docs/status/leak-crisis.md.
fn e3Analyze(comptime w: usize, comptime h: usize, t: *const Retro(w, h).Tables, gpa: std.mem.Allocator, moves: []const u8, ply: usize, promise_ply: usize, audited_color: i8, promise: i16) void {
    const RT = Retro(w, h);
    const R = RT.R;
    const X = RT.X;
    const n = RT.n;
    const Pos = RT.Pos;
    const EX = Exact(w, h);
    const p = std.debug.print;
    _ = audited_color;

    p("E3 audit: promise {d} at ply {d}/{d}\n", .{ promise, promise_ply, ply });
    // PSK-legality scan: replay the WHOLE game, verify no move recreated a
    // prior goban (the self-play `seen` filter must match this). Any illegal
    // move => the leak is a self-play/PSK wiring bug, not a bound failure.
    {
        var lp: Pos = [_]i8{0} ** n;
        var lb = EX.Bans.initEmpty();
        lb.set(@intCast(X.colex_from_pos(&lp)));
        var ls: i8 = 1;
        var lpass: u8 = 0;
        var illegal: u64 = 0;
        var j: usize = 0;
        while (j < ply) : (j += 1) {
            const m = moves[j];
            if (m == 0) {
                lpass += 1;
            } else {
                const cell: usize = @intCast(m - 1);
                const child = R.pos_from_move(&lp, ls, cell) catch {
                    illegal += 1;
                    p("  *** ILLEGAL move at ply {d}: pos_from_move failed ***\n", .{j});
                    break;
                };
                const ci: usize = @intCast(X.colex_from_pos(&child));
                if (lb.isSet(ci)) {
                    illegal += 1;
                    p("  *** ILLEGAL move at ply {d}: child recreates a banned position (self-play/PSK bug) ***\n", .{j});
                }
                lb.set(ci);
                lp = child;
                lpass = 0;
            }
            ls = -ls;
        }
        p("  PSK-legality: {d} illegal moves in {d} plies -> {s}\n", .{ illegal, ply, if (illegal == 0) "VALID PSK game" else "INVALID (self-play bug)" });
    }


    // replay to the promise ply, building the ban set (positions seen so far)
    var pos: Pos = [_]i8{0} ** n;
    var bans = EX.Bans.initEmpty();
    bans.set(@intCast(X.colex_from_pos(&pos)));
    var side: i8 = 1;
    var passes: u8 = 0;
    var i: usize = 0;
    while (i < promise_ply) : (i += 1) {
        const m = moves[i];
        if (m == 0) {
            passes += 1;
        } else {
            const cell: usize = @intCast(m - 1);
            const child = R.pos_from_move(&pos, side, cell) catch break;
            bans.set(@intCast(X.colex_from_pos(&child)));
            pos = child;
            passes = 0;
        }
        side = -side;
    }

    // walk the self-play line; compare lo (table) vs true (exact solver)
    var ctx = EX.Ctx{ .map = EX.Map.init(gpa), .budget = 2_000_000, .entry_cap = 1_000_000 };
    defer ctx.map.deinit();
    var violations: u64 = 0;
    while (i < ply) : (i += 1) {
        const idx: usize = @intCast(X.colex_from_pos(&pos));
        const lo_tbl: i8 = if (passes >= 2) t.score[idx] else if (passes == 0) (if (side > 0) t.lo.b0[idx] else t.lo.w0[idx]) else (if (side > 0) t.lo.b1[idx] else t.lo.w1[idx]);
        const hi_tbl: i8 = if (passes >= 2) t.score[idx] else if (passes == 0) (if (side > 0) t.hi.b0[idx] else t.hi.w0[idx]) else (if (side > 0) t.hi.b1[idx] else t.hi.w1[idx]);
        ctx.nodes = 0;
        var tractable = true;
        var true_v: i8 = 0;
        const r = EX.solve(&ctx, &pos, side, passes, EX.win_empty, bans);
        if (r) |v| {
            true_v = v;
        } else |_| {
            tractable = false;
            p("  ply {d} side {s} passes {d} lo={d} hi={d} : EXACT budget-exceeded ({d} nodes) -- intractable here\n", .{ i, if (side > 0) "B" else "W", passes, lo_tbl, hi_tbl, ctx.nodes });
        }
        if (tractable) {
            const bad = true_v < lo_tbl;
            p("  ply {d} side {s} passes {d} lo={d} hi={d} true={d} nodes={d}  {s}\n", .{ i, if (side > 0) "B" else "W", passes, lo_tbl, hi_tbl, true_v, ctx.nodes, if (bad) "<<< true < lo  (C3 FALSE / lo-bug)" else "ok" });
            if (bad) {
                violations += 1;
                if (violations >= 3) {
                    p("  (stopping after 3 violations)\n", .{});
                    break;
                }
            }
        }
        // advance along the self-play line
        const m = moves[i];
        if (m == 0) {
            passes += 1;
        } else {
            const cell: usize = @intCast(m - 1);
            const child = R.pos_from_move(&pos, side, cell) catch break;
            bans.set(@intCast(X.colex_from_pos(&child)));
            pos = child;
            passes = 0;
        }
        side = -side;
    }
    p("E3 audit: {s}\n", .{ if (violations > 0) "VIOLATION (true < lo on the self-play line)" else "no violation on the traversed line (early plies may be intractable)" });
}

fn e2Board(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator, num_seeds: u64, comptime trivial: bool) !void {
    const RT = Retro(w, h);
    const R = RT.R;
    const X = RT.X;
    const n = RT.n;
    const Pos = RT.Pos;
    const p = std.debug.print;

    var t = try RT.Tables.init(gpa);
    defer t.deinit();
    RT.seed(&t);
    if (trivial) {
        // POLICY SANITY CHECK: feed trivially-valid bounds (lo=-N, hi=+N for
        // every legal position). True by the rules alone (every area score is
        // in [-N,N]); uses NO game-theoretic value. A correct range-aware
        // policy MUST be leak-free here. Any leak => a policy/wiring bug, not
        // a bound problem. See docs/status/leak-crisis.md.
        for (0..RT.total) |i| {
            if (!t.legal[i]) continue;
            t.lo.b0[i] = -RT.N; t.lo.w0[i] = -RT.N; t.lo.b1[i] = -RT.N; t.lo.w1[i] = -RT.N;
            t.hi.b0[i] = RT.N;  t.hi.w0[i] = RT.N;  t.hi.b1[i] = RT.N;  t.hi.w1[i] = RT.N;
        }
    } else {
        RT.converge(&t);
        RT.finalize(&t);
    }

    const PLY_CAP = 400;
    const MAX_HIST = 4096;
    var hist: [MAX_HIST]Pos = undefined;
    var pos: Pos = [_]i8{0} ** n;
    var passes: u8 = 0;
    var hlen: usize = 0;

    var leaks: u64 = 0;
    var max_leak: i16 = 0;
    var games: u64 = 0;
    var capped: u64 = 0;
    var audited_won: u64 = 0;
    var e3_analyzed: u64 = 0;

    var seed: u64 = 0;
    while (seed < num_seeds) : (seed += 1) {
        for ([_]i8{ 1, -1 }) |audited_color| {
            var prng = std.Random.DefaultPrng.init(seed * 1013 + @as(u64, if (audited_color > 0) 0 else 1));
            const rnd = prng.random();

            pos = [_]i8{0} ** n;
            hlen = 0;
            hist[0] = pos;
            hlen = 1;
            passes = 0;
            var side: i8 = 1;
            var promise: i16 = if (audited_color > 0) -127 else 127;
            var ply: usize = 0;
            var promise_ply: usize = 0;
            var moves_rec: [PLY_CAP]u8 = undefined;

            while (passes < 2 and ply < PLY_CAP) : (ply += 1) {
                const idx: usize = @intCast(X.colex_from_pos(&pos));
                var cells: [n + 1]?usize = undefined;
                var vals: [n + 1]i8 = undefined;
                var cnt: usize = 0;
                // pass option: game ends if a pass is already standing, else the V1 lo-floor
                cells[0] = null;
                vals[0] = if (passes >= 1) R.area_score(&pos) else (if (side > 0) t.lo.w1[idx] else t.hi.b1[idx]);
                cnt = 1;
                for (0..n) |cell| {
                    if (pos[cell] != 0) continue;
                    const child = R.pos_from_move(&pos, side, cell) catch continue;
                    var seen = false;
                    for (hist[0..hlen]) |*b| {
                        if (std.mem.eql(i8, b, &child)) {
                            seen = true;
                            break;
                        }
                    }
                    if (seen) continue;
                    const ci: usize = @intCast(X.colex_from_pos(&child));
                    cells[cnt] = cell;
                    vals[cnt] = if (side > 0) t.lo.w0[ci] else t.hi.b0[ci];
                    cnt += 1;
                }
                const maximizing = side > 0;
                var best: i8 = vals[0];
                for (vals[1..cnt]) |v| {
                    if (if (maximizing) v > best else v < best) best = v;
                }
                // random tie-break among lo-optimal moves (line variety)
                var pick: usize = 0;
                var opt_count: usize = 0;
                for (vals[0..cnt], 0..) |v, i| {
                    if (v == best) {
                        opt_count += 1;
                        if (rnd.uintLessThan(usize, opt_count) == 0) pick = i;
                    }
                }
                if (side == audited_color) {
                    if (audited_color > 0) {
                        if (@as(i16, best) > promise) {
                            promise = best;
                            promise_ply = ply;
                        }
                    } else {
                        if (@as(i16, best) < promise) {
                            promise = best;
                            promise_ply = ply;
                        }
                    }
                }
                const ch = cells[pick];
                moves_rec[ply] = if (ch) |c| @intCast(c + 1) else 0;
                if (ch) |c| {
                    const child = R.pos_from_move(&pos, side, c) catch unreachable;
                    pos = child;
                    hist[hlen] = pos;
                    hlen += 1;
                    passes = 0;
                } else {
                    passes += 1;
                    if (passes >= 2) break;
                }
                side = -side;
            }

            games += 1;
            if (ply >= PLY_CAP) {
                capped += 1;
                continue;
            }
            const score: i16 = R.area_score(&pos);
            if (if (audited_color > 0) score > 0 else score < 0) audited_won += 1;
            const leak: i16 = if (audited_color > 0) promise - score else score - promise;
            if (leak > 0) {
                leaks += 1;
                if (leak > max_leak) max_leak = leak;
                p("E2 LEAK {d} pts | {d}x{d} seed {d} audited {s} promise {d} final {d}\n", .{
                    leak, w, h, seed, if (audited_color > 0) "B" else "W", promise, score,
                });
                if (e3_analyzed < 1) {
                    e3_analyzed += 1;
                    e3Analyze(w, h, &t, gpa, moves_rec[0..ply], ply, promise_ply, audited_color, promise);
                }
            }
        }
    }
    p("E2 {d}x{d}: games={d} capped={d} leaks={d} (max {d}) audited-won={d}  -> {s}\n", .{
        w, h, games, capped, leaks, max_leak, audited_won,
        if (leaks == 0) "ZERO LEAKS (C3 supported)" else "LEAKS (C3 falsified)",
    });
}

fn runE2(gpa: std.mem.Allocator) void {
    const p = std.debug.print;
    const e2_seeds: u64 = if (std.c.getenv("RETRO_E2_SEEDS")) |s|
        (std.fmt.parseInt(u64, std.mem.span(s), 10) catch 2000)
    else
        2000;
    p("E2: range-aware (maximin over lo/hi) self-play; seeds={d}; promise = bound of chosen move; acceptance = zero leaks\n", .{e2_seeds});
    e2Board(2, 2, gpa, e2_seeds, false) catch |e| p("E2 2x2 FAILED: {t}\n", .{e});
    e2Board(3, 2, gpa, e2_seeds, false) catch |e| p("E2 3x2 FAILED: {t}\n", .{e});
    e2Board(3, 3, gpa, e2_seeds, false) catch |e| p("E2 3x3 FAILED: {t}\n", .{e});
}

/// E2 POLICY SANITY CHECK: trivially-valid bounds (lo=-N, hi=+N), no converge,
/// no Go knowledge. A correct policy MUST leak zero. Isolates policy/wiring
/// from the bound-correctness question.
fn runE2sanity(gpa: std.mem.Allocator) void {
    const p = std.debug.print;
    p("E2-SANITY: trivially-valid bounds (lo=-N, hi=+N, no converge). Expected: ZERO leaks (policy wiring check).\n", .{});
    e2Board(2, 2, gpa, 2000, true) catch |e| p("E2-sanity 2x2 FAILED: {t}\n", .{e});
    e2Board(3, 2, gpa, 2000, true) catch |e| p("E2-sanity 3x2 FAILED: {t}\n", .{e});
    e2Board(3, 3, gpa, 2000, true) catch |e| p("E2-sanity 3x3 FAILED: {t}\n", .{e});
}


/// B1 (leak-crisis, 2026-07-25, T02.2): independently verify the canonical
/// `RT.converge` lands at the true least fixpoint of the L map it applies.
/// Three checks at every legal, non-settled (i, side):
///   (A) V0 fixpoint: stored `lo.b0[i]` (B) / `lo.w0[i]` (W) equals
///       opt(side)( max_{p ∈ moves} oppV0[colex(child)] , oppV1[i] ).
///   (B) V1 fixpoint: stored `lo.b1[i]` (B) / `lo.w1[i]` (W) equals
///       opt(side)( max_{p ∈ moves} oppV0[colex(child)] , t.score[i] ).
///   (C) Symmetric for `hi` (greatest-fixpoint dual via colour inversion).
/// Plus §3 least-fixpoint checks:
///   (D) Re-converge from `lo=-N+1` (lower seed); must land at canonical
///       lo elementwise AFTER `sweep(t, &t.lo) == 0` (zero-change).
///   (E) Re-converge from `lo=+N` (upper seed); must drain to canonical lo
///       elementwise AFTER zero-change.
/// Acceptance (the contract): all V0/V1 violations zero on 2x2/3x2/3x3 AND
/// re-converges elementwise match canonical after zero-change => (b)
/// converge-bug RULED OUT. Any violation or element-above => (b) plausible.
/// MAX_SWEEPS hit => report and treat as inconclusive. See untracked/b1-spec.md
/// and untracked/T02-minimax.md.
fn e3LofixCheck(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator) !void {
    const RT = Retro(w, h);
    const R = RT.R;
    const X = RT.X;
    const n = RT.n;
    const N: i8 = @intCast(n);
    const total: usize = RT.total;
    const p = std.debug.print;

    // ---------- canonical converge ----------
    var t0 = try RT.Tables.init(gpa);
    defer t0.deinit();
    RT.seed(&t0);
    RT.converge(&t0);

    var empty_pos: RT.Pos = [_]i8{0} ** n;
    const empty_idx: usize = @intCast(X.colex_from_pos(&empty_pos));

    p("B1 {d}x{d}: canonical sweeps={d}  empty(B) lo=[{d},{d}]  hi=[{d},{d}]  ko_sensitive_b={d} ko_sensitive_w={d}\n", .{
        w, h, t0.sweeps,
        t0.lo.b0[empty_idx], t0.lo.b1[empty_idx],
        t0.hi.b0[empty_idx], t0.hi.b1[empty_idx],
        t0.ko_sensitive_b, t0.ko_sensitive_w,
    });

    // ---------- (A) V0 fixpoint-equation check ----------
    // For every legal, non-settled (i, side):
    //   B to move: stored lo.b0[i] = opt_max( max_p lo.w0[colex(child_p)] ,
    //                                         lo.w1[i] )
    //   W to move: stored lo.w0[i] = opt_min( min_p lo.b0[colex(child_p)] ,
    //                                         lo.b1[i] )
    var a_v0_viol: u64 = 0;
    var a_v0_exemplars: u8 = 0;
    {
        var i: usize = 0;
        while (i < total) : (i += 1) {
            if (!t0.legal[i] or t0.settled[i]) continue;
            var pos = X.pos_from_colex(i);
            // B
            var best_b: i8 = t0.lo.w1[i]; // start with the "pass" branch value
            for (0..n) |p_idx| {
                if (pos[p_idx] != 0) continue;
                const child = R.pos_from_move(&pos, @as(i8, 1), p_idx) catch continue;
                const ci: usize = @intCast(X.colex_from_pos(&child));
                if (t0.lo.w0[ci] > best_b) best_b = t0.lo.w0[ci];
            }
            if (t0.lo.b0[i] != best_b) {
                a_v0_viol += 1;
                if (a_v0_exemplars < 10) {
                    a_v0_exemplars += 1;
                    p("  [A-V0-B] idx={d} stored={d} expected={d}  (max over p of lo.w0[child_p]; pass: lo.w1[i]={d})\n", .{
                        i, t0.lo.b0[i], best_b, t0.lo.w1[i],
                    });
                }
            }
            // W
            var best_w: i8 = t0.lo.b1[i]; // start with the "pass" branch value
            for (0..n) |p_idx| {
                if (pos[p_idx] != 0) continue;
                const child = R.pos_from_move(&pos, @as(i8, -1), p_idx) catch continue;
                const ci: usize = @intCast(X.colex_from_pos(&child));
                if (t0.lo.b0[ci] < best_w) best_w = t0.lo.b0[ci];
            }
            if (t0.lo.w0[i] != best_w) {
                a_v0_viol += 1;
                if (a_v0_exemplars < 10) {
                    a_v0_exemplars += 1;
                    p("  [A-V0-W] idx={d} stored={d} expected={d}  (min over p of lo.b0[child_p]; pass: lo.b1[i]={d})\n", .{
                        i, t0.lo.w0[i], best_w, t0.lo.b1[i],
                    });
                }
            }
        }
    }
    p("B1 {d}x{d} [A-V0] fixpoint-equation violations (V0 over all legal non-settled (i,side)): {d}\n", .{ w, h, a_v0_viol });

    // ---------- (B) V1 fixpoint-equation check ----------
    // B: stored lo.b1[i] = opt_max( max_p lo.w0[colex(child_p)] , t.score[i] )
    // W: stored lo.w1[i] = opt_min( min_p lo.b0[colex(child_p)] , t.score[i] )
    // (Boss correction 2026-07-25: V1 also reads oppV0[child], not oppV1[child];
    //  the sweep's `m` is shared between v0 and v1.)
    var a_v1_viol: u64 = 0;
    var a_v1_exemplars: u8 = 0;
    {
        var i: usize = 0;
        while (i < total) : (i += 1) {
            if (!t0.legal[i] or t0.settled[i]) continue;
            var pos = X.pos_from_colex(i);
            // B
            var best_b: i8 = t0.score[i]; // start with the "second pass" branch value
            for (0..n) |p_idx| {
                if (pos[p_idx] != 0) continue;
                const child = R.pos_from_move(&pos, @as(i8, 1), p_idx) catch continue;
                const ci: usize = @intCast(X.colex_from_pos(&child));
                if (t0.lo.w0[ci] > best_b) best_b = t0.lo.w0[ci];
            }
            if (t0.lo.b1[i] != best_b) {
                a_v1_viol += 1;
                if (a_v1_exemplars < 10) {
                    a_v1_exemplars += 1;
                    p("  [B-V1-B] idx={d} stored={d} expected={d}  (max over p of lo.w0[child_p]; pass: score[i]={d})\n", .{
                        i, t0.lo.b1[i], best_b, t0.score[i],
                    });
                }
            }
            // W
            var best_w: i8 = t0.score[i]; // start with the "second pass" branch value
            for (0..n) |p_idx| {
                if (pos[p_idx] != 0) continue;
                const child = R.pos_from_move(&pos, @as(i8, -1), p_idx) catch continue;
                const ci: usize = @intCast(X.colex_from_pos(&child));
                if (t0.lo.b0[ci] < best_w) best_w = t0.lo.b0[ci];
            }
            if (t0.lo.w1[i] != best_w) {
                a_v1_viol += 1;
                if (a_v1_exemplars < 10) {
                    a_v1_exemplars += 1;
                    p("  [B-V1-W] idx={d} stored={d} expected={d}  (min over p of lo.b0[child_p]; pass: score[i]={d})\n", .{
                        i, t0.lo.w1[i], best_w, t0.score[i],
                    });
                }
            }
        }
    }
    p("B1 {d}x{d} [B-V1] fixpoint-equation violations (V1 over all legal non-settled (i,side)): {d}\n", .{ w, h, a_v1_viol });

    // ---------- (C) Same checks against `hi` (greatest fixpoint) ----------
    // Same equations, but with hi instead of lo. By colour inversion
    // hi(-pos,-side) == -lo(pos,side); a violation here is the same kind
    // of evidence as a lo violation.
    var c_v0_viol: u64 = 0;
    var c_v1_viol: u64 = 0;
    {
        var i: usize = 0;
        while (i < total) : (i += 1) {
            if (!t0.legal[i] or t0.settled[i]) continue;
            var pos = X.pos_from_colex(i);
            // B-V0 on hi
            var best_b_v0: i8 = t0.hi.w1[i];
            for (0..n) |p_idx| {
                if (pos[p_idx] != 0) continue;
                const child = R.pos_from_move(&pos, @as(i8, 1), p_idx) catch continue;
                const ci: usize = @intCast(X.colex_from_pos(&child));
                if (t0.hi.w0[ci] > best_b_v0) best_b_v0 = t0.hi.w0[ci];
            }
            if (t0.hi.b0[i] != best_b_v0) c_v0_viol += 1;
            // W-V0 on hi
            var best_w_v0: i8 = t0.hi.b1[i];
            for (0..n) |p_idx| {
                if (pos[p_idx] != 0) continue;
                const child = R.pos_from_move(&pos, @as(i8, -1), p_idx) catch continue;
                const ci: usize = @intCast(X.colex_from_pos(&child));
                if (t0.hi.b0[ci] < best_w_v0) best_w_v0 = t0.hi.b0[ci];
            }
            if (t0.hi.w0[i] != best_w_v0) c_v0_viol += 1;
            // B-V1 on hi
            var best_b_v1: i8 = t0.score[i];
            for (0..n) |p_idx| {
                if (pos[p_idx] != 0) continue;
                const child = R.pos_from_move(&pos, @as(i8, 1), p_idx) catch continue;
                const ci: usize = @intCast(X.colex_from_pos(&child));
                if (t0.hi.w0[ci] > best_b_v1) best_b_v1 = t0.hi.w0[ci];
            }
            if (t0.hi.b1[i] != best_b_v1) c_v1_viol += 1;
            // W-V1 on hi
            var best_w_v1: i8 = t0.score[i];
            for (0..n) |p_idx| {
                if (pos[p_idx] != 0) continue;
                const child = R.pos_from_move(&pos, @as(i8, -1), p_idx) catch continue;
                const ci: usize = @intCast(X.colex_from_pos(&child));
                if (t0.hi.b0[ci] < best_w_v1) best_w_v1 = t0.hi.b0[ci];
            }
            if (t0.hi.w1[i] != best_w_v1) c_v1_viol += 1;
        }
    }
    p("B1 {d}x{d} [C-hi]  V0 violations={d}  V1 violations={d}\n", .{ w, h, c_v0_viol, c_v1_viol });

    // ---------- (D) Re-converge from `lo = -N+1` (lower bound) ----------
    var t_d = try RT.Tables.init(gpa);
    defer t_d.deinit();
    RT.seed(&t_d);
    // re-seed lo to (-N+1) — strictly above the canonical seed (-N). hi
    // left at its canonical value (do NOT double-perturb; b1-spec §6).
    for (0..total) |i| {
        if (!t_d.legal[i] or t_d.settled[i]) continue;
        t_d.lo.b0[i] = -N + 1;
        t_d.lo.w0[i] = -N + 1;
        t_d.lo.b1[i] = -N + 1;
        t_d.lo.w1[i] = -N + 1;
    }
    RT.converge(&t_d);
    const d_zero: u64 = RT.sweep(&t_d, &t_d.lo);
    var d_above: u64 = 0;
    var d_below: u64 = 0;
    for (0..total) |i| {
        if (!t_d.legal[i] or t_d.settled[i]) continue;
        // For L map: re-converge from a higher lower seed must drain
        // DOWN to the canonical least fixpoint. Compare elementwise:
        // any re-converge element strictly ABOVE canonical => (b).
        if (t_d.lo.b0[i] > t0.lo.b0[i]) d_above += 1;
        if (t_d.lo.b0[i] < t0.lo.b0[i]) d_below += 1;
        if (t_d.lo.w0[i] > t0.lo.w0[i]) d_above += 1;
        if (t_d.lo.w0[i] < t0.lo.w0[i]) d_below += 1;
        if (t_d.lo.b1[i] > t0.lo.b1[i]) d_above += 1;
        if (t_d.lo.b1[i] < t0.lo.b1[i]) d_below += 1;
        if (t_d.lo.w1[i] > t0.lo.w1[i]) d_above += 1;
        if (t_d.lo.w1[i] < t0.lo.w1[i]) d_below += 1;
    }
    const d_reached_canon: bool = (d_above == 0);
    p("B1 {d}x{d} [D]   re-converge lo=-N+1: empty(B) lo={d} (canon={d})  sweep_changes_after={d}  above_canon={d} below_canon={d}  reached_canon={s}\n", .{
        w, h, t_d.lo.b0[empty_idx], t0.lo.b0[empty_idx], d_zero, d_above, d_below,
        if (d_reached_canon) "YES" else "NO",
    });

    // ---------- (E) Re-converge from `lo = +N` (upper seed) ----------
    // Map is monotone in q; iterating from above must drain down to the
    // LEAST fixpoint (the map's reads of q are all opt; raising q can
    // only raise the result; iterating from a higher q must decrease
    // monotonically toward the least fixpoint).
    var t_e = try RT.Tables.init(gpa);
    defer t_e.deinit();
    RT.seed(&t_e);
    for (0..total) |i| {
        if (!t_e.legal[i] or t_e.settled[i]) continue;
        t_e.lo.b0[i] = N;
        t_e.lo.w0[i] = N;
        t_e.lo.b1[i] = N;
        t_e.lo.w1[i] = N;
    }
    RT.converge(&t_e);
    const e_zero: u64 = RT.sweep(&t_e, &t_e.lo);
    var e_above: u64 = 0;
    var e_below: u64 = 0;
    for (0..total) |i| {
        if (!t_e.legal[i] or t_e.settled[i]) continue;
        if (t_e.lo.b0[i] > t0.lo.b0[i]) e_above += 1;
        if (t_e.lo.b0[i] < t0.lo.b0[i]) e_below += 1;
        if (t_e.lo.w0[i] > t0.lo.w0[i]) e_above += 1;
        if (t_e.lo.w0[i] < t0.lo.w0[i]) e_below += 1;
        if (t_e.lo.b1[i] > t0.lo.b1[i]) e_above += 1;
        if (t_e.lo.b1[i] < t0.lo.b1[i]) e_below += 1;
        if (t_e.lo.w1[i] > t0.lo.w1[i]) e_above += 1;
        if (t_e.lo.w1[i] < t0.lo.w1[i]) e_below += 1;
    }
    const e_reached_canon: bool = (e_above == 0);
    p("B1 {d}x{d} [E]   re-converge lo=+N:   empty(B) lo={d} (canon={d})  sweep_changes_after={d}  above_canon={d} below_canon={d}  reached_canon={s}\n", .{
        w, h, t_e.lo.b0[empty_idx], t0.lo.b0[empty_idx], e_zero, e_above, e_below,
        if (e_reached_canon) "YES" else "NO",
    });

    // ---------- Verdict ----------
    const all_zero_change: bool = (d_zero == 0 and e_zero == 0);
    const all_pass: bool = (a_v0_viol == 0 and a_v1_viol == 0 and c_v0_viol == 0 and c_v1_viol == 0
        and d_reached_canon and e_reached_canon and all_zero_change);
    p("B1 {d}x{d}: V0_viol={d} V1_viol={d} hi_V0={d} hi_V1={d} D_reached_canon={s} E_reached_canon={s} D_zero_change={s} E_zero_change={s}  -> {s}\n", .{
        w, h, a_v0_viol, a_v1_viol, c_v0_viol, c_v1_viol,
        if (d_reached_canon) "YES" else "NO",
        if (e_reached_canon) "YES" else "NO",
        if (d_zero == 0) "YES" else "NO",
        if (e_zero == 0) "YES" else "NO",
        if (all_pass) "(b) RULED OUT on this board" else "(b) PLAUSIBLE or INCONCLUSIVE on this board",
    });
}

fn runE3B1(gpa: std.mem.Allocator) void {
    const p = std.debug.print;
    p("B1: independently verify lo is the true least fixpoint of the L map (rules out (b) converge-bug).\n", .{});
    p("      Three checks per board: V0 + V1 fixpoint equation on lo and hi, plus two least-fixpoint\n", .{});
    p("      re-converge checks from lo=-N+1 and lo=+N with zero-change precondition.\n", .{});
    p("      Spec: untracked/b1-spec.md  T02: untracked/T02-minimax.md\n\n", .{});
    e3LofixCheck(2, 2, gpa) catch |e| p("B1 2x2 FAILED: {t}\n", .{e});
    e3LofixCheck(3, 2, gpa) catch |e| p("B1 3x2 FAILED: {t}\n", .{e});
    e3LofixCheck(3, 3, gpa) catch |e| p("B1 3x3 FAILED: {t}\n", .{e});
}

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    std.debug.print("weizigo retrograde engine (ADR-0009) -- L/H value iteration + finisher + battery\n\n", .{});
    if (std.c.getenv("RETRO_CENSUS") != null) {
        const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, runCensus, .{gpa});
        thread.join();
        return;
    }
    if (std.c.getenv("RETRO_PARALLEL") != null) {
        // B31: parallel writes-off finisher
        const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, runParallel, .{gpa});
        thread.join();
        return;
    }
    if (std.c.getenv("RETRO_RULES") != null) {
        const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, runRules, .{gpa});
        thread.join();
        return;
    }
    if (std.c.getenv("RETRO_KILLCENSUS") != null) {
        const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, runKillCensus, .{gpa});
        thread.join();
        return;
    }
    if (std.c.getenv("RETRO_CYCLE") != null) {
        const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, runCycle, .{gpa});
        thread.join();
        return;
    }
    if (std.c.getenv("RETRO_BRACKET") != null) {
        const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, runBracket, .{gpa});
        thread.join();
        return;
    }
    if (std.c.getenv("RETRO_E2") != null) {
        const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, runE2, .{gpa});
        thread.join();
        return;
    }
    if (std.c.getenv("RETRO_E2SANITY") != null) {
        const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, runE2sanity, .{gpa});
        thread.join();
        return;
    }

    if (std.c.getenv("RETRO_B1_LOFIX") != null) {
        const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, runE3B1, .{gpa});
        thread.join();
        return;
    }

    if (std.c.getenv("RETRO_CORE") != null) {
        const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, runCore, .{gpa});
        thread.join();
        return;
    }
    if (std.c.getenv("RETRO_PLY") != null) {
        const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, runPly, .{gpa});
        thread.join();
        return;
    }
    if (std.c.getenv("RETRO_CMP") != null) {
        const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, runCompare, .{gpa});
        thread.join();
        return;
    }
    if (std.c.getenv("RETRO_DEPSVAL") != null) {
        const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, runDepsVal, .{gpa});
        thread.join();
        return;
    }
    if (std.c.getenv("RETRO_DIAG") != null) {
        try runBoard(2, 2, gpa, .{ .diag_only = true });
        try runBoard(3, 2, gpa, .{ .diag_only = true });
        try runBoard(3, 3, gpa, .{ .diag_only = true });
        return;
    }
    if (std.c.getenv("RETRO_ANCHOR") != null) {
        try anchorProbe(gpa, 2_000_000_000);
        return;
    }
    if (std.c.getenv("RETRO_3X3") != null) {
        try runBoard(3, 3, gpa, .{ .spot_min_layer = 6, .finisher_budget = 500_000_000 });
        return;
    }
    if (std.c.getenv("RETRO_SAVE") != null) {
        // persist the complete oracles (2x2, 3x2, 3x3) as ADR-0011 artifacts
        try saveArtifact(2, 2, gpa, (if (std.c.getenv("RETRO_SAVE_2X2_OUT")) |p| std.mem.span(p) else "artifacts/oracle-2x2.wzo"), 500_000_000, 0, false, null, false, false, false);
        try saveArtifact(3, 2, gpa, (if (std.c.getenv("RETRO_SAVE_3X2_OUT")) |p| std.mem.span(p) else "artifacts/oracle-3x2.wzo"), 500_000_000, 0, false, null, false, false, false);
        try saveArtifact(3, 3, gpa, (if (std.c.getenv("RETRO_SAVE_3X3_OUT")) |p| std.mem.span(p) else "artifacts/oracle-3x3.wzo"), 500_000_000, 0, false, null, false, false, false);
        // 4x3 completes fully with the sound (writes-off) finisher (ko-sensitive region is
        // tractable at this size — measured 0 budget-skips); provably correct.
        try saveArtifact(4, 3, gpa, (if (std.c.getenv("RETRO_SAVE_4X3_OUT")) |p| std.mem.span(p) else "artifacts/oracle-4x3.wzo"), 2_000_000_000, 0, false, null, false, false, false);
        // external checksums of the files as written (verify independently of
        // the reader: `shasum -a 256 -c artifacts/SHA256SUMS` from repo root)
        try writeChecksums(gpa, "artifacts/SHA256SUMS", &.{
            "artifacts/oracle-2x2.wzo",
            "artifacts/oracle-3x2.wzo",
            "artifacts/oracle-3x3.wzo",
            "artifacts/oracle-4x3.wzo",
        });
        return;
    }
    if (std.c.getenv("RETRO_CONSIST") != null) {
        // #2 self-consistency auditor: minimax-identity check on every 3x2
        // KO_SENSITIVE node, memo_writes ON vs OFF. Any violation PROVES that
        // variant buggy (necessary, not sufficient).
        const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, runConsist, .{gpa});
        thread.join();
        return;
    }
    if (std.c.getenv("RETRO_CONSIST4") != null) {
        // same auditor, sampled over the deepest 4x4 KO_SENSITIVE nodes.
        const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, runConsist4, .{gpa});
        thread.join();
        return;
    }
    if (std.c.getenv("RETRO_CONSIST2") != null) {
        // B07: #2 auditor on 2x2 (all 41 KO_SENSITIVE slots by default)
        const max_str: []const u8 = if (std.c.getenv("RETRO_CONSIST_SAMPLE")) |s| std.mem.span(s) else "0";
        const max_checks: u64 = std.fmt.parseInt(u64, max_str, 10) catch 0;
        const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, runConsist2x2, .{ gpa, max_checks });
        thread.join();
        return;
    }
    if (std.c.getenv("RETRO_CONSIST3") != null) {
        // B07: #2 auditor on 3x3 (4349 KO_SENSITIVE slots, sampled by default 400)
        const max_str: []const u8 = if (std.c.getenv("RETRO_CONSIST_SAMPLE")) |s| std.mem.span(s) else "400";
        const max_checks: u64 = std.fmt.parseInt(u64, max_str, 10) catch 400;
        const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, runConsist3x3, .{ gpa, max_checks });
        thread.join();
        return;
    }
    if (std.c.getenv("RETRO_VERIFY") != null) {
        const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, runVerify, .{gpa});
        thread.join();
        return;
    }
    if (std.c.getenv("RETRO_REPLAY") != null) {
        // history-exact replay of the B+16 game (big stack: deep recursion)
        const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, runReplay, .{gpa});
        thread.join();
        return;
    }
    if (std.c.getenv("RETRO_6X3") != null) {
        // 3^18 = 387,420,489 slots (~16 GB peak) — the largest in-RAM goban
        // on this machine; published anchor: 3x6 = B+18 (van der Werf).
        const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, run6x3, .{gpa});
        thread.join();
        return;
    }
    if (std.c.getenv("RETRO_4X4") != null) {
        // THE SCALE RUN (ADR-0009/0010 consequences): 3^16 = 43,046,721 slots
        // (~1.3 GB working set). Measures the 5x5 projection numbers: sweep
        // count, ko-sensitive fraction, orbit-rep census, bracketed-finisher
        // nodes/root. No ground truth (Finding 3: intractable), no spot
        // checks (each deep no-memo root is expensive; symmetry + brackets +
        // anchors-by-inclusion cover the table). Big-stack thread: finisher
        // recursion depth == line length, and 4x4 lines can exceed the 8 MB
        // default stack.
        const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, run4x4, .{gpa});
        thread.join();
        return;
    }
    if (std.c.getenv("RETRO_PLAIN") != null) {
        // engine-vs-engine: plain ADR-0009 finisher vs bracketed ADR-0010,
        // 2x2 only (the one goban plain completes — Finding 5/6). The two
        // final tables must be IDENTICAL slot-for-slot.
        const RT = Retro(2, 2);
        var ta = try RT.Tables.init(gpa);
        defer ta.deinit();
        RT.seed(&ta);
        RT.converge(&ta);
        RT.finalize(&ta);
        var tb = try RT.Tables.init(gpa);
        defer tb.deinit();
        RT.seed(&tb);
        RT.converge(&tb);
        RT.finalize(&tb);
        const fa = try RT.finish(&ta, gpa, 500_000_000, false);
        const fb = try RT.finish(&tb, gpa, 500_000_000, true);
        var diff: u64 = 0;
        for (0..RT.total) |i| {
            if (!ta.legal[i]) continue;
            if (ta.vb[i] != tb.vb[i]) diff += 1;
            if (ta.vw[i] != tb.vw[i]) diff += 1;
        }
        std.debug.print("2x2 plain-vs-bracketed: {s} diffs={d} (plain nodes={d}, bracketed nodes={d})\n", .{
            if (diff == 0 and fa.budget_skipped == 0 and fb.budget_skipped == 0) "IDENTICAL" else "MISMATCH",
            diff, fa.nodes, fb.nodes,
        });
        return;
    }
    // Bracket-guided (ADR-0010) finisher everywhere: 2x2 and 3x2 complete
    // against exhaustive ground truth; 3x3 measures the full ko-sensitive region sweep
    // that the plain finisher could not reach (Finding 6).
    try runBoard(2, 2, gpa, .{ .ground_truth = true, .finisher_budget = 500_000_000 });
    try runBoard(3, 2, gpa, .{ .ground_truth = true, .finisher_budget = 500_000_000 });
    try runBoard(3, 3, gpa, .{ .spot_min_layer = 6, .finisher_budget = 500_000_000 });
}

// ---- tests ------------------------------------------------------------------

test "3x3 settled wall is terminal at seed (no sweeps needed)" {
    const RT = Retro(3, 3);
    var t = try RT.Tables.init(std.testing.allocator);
    defer t.deinit();
    RT.seed(&t);
    RT.finalize(&t);
    const wall = [_]i8{
        0, 1, 0,
        0, 1, 0,
        0, 1, 0,
    };
    const i: usize = @intCast(RT.X.colex_from_pos(&wall));
    try expect(t.settled[i]);
    try expect(t.vb[i] == 9 and t.vw[i] == 9);
    try expect(t.fb[i] == 0 and t.fw[i] == 0);
}

test "2x2 retrograde: converges, L <= H, fixpoints swap under colour inversion" {
    const RT = Retro(2, 2);
    var t = try RT.Tables.init(std.testing.allocator);
    defer t.deinit();
    RT.seed(&t);
    RT.converge(&t);
    RT.finalize(&t);
    try expect(t.sweeps < RT.MAX_SWEEPS);
    for (0..RT.total) |i| {
        if (!t.legal[i]) continue;
        try expect(t.lo.b0[i] <= t.hi.b0[i]);
        try expect(t.lo.w0[i] <= t.hi.w0[i]);
    }
    const sym = RT.checkSymmetry(&t);
    try expect(sym.lh_inv_fail == 0);
    try expect(sym.dih_fail == 0);
    try expect(sym.flag_fail == 0);
}

test "2x2 bracket-guided finisher completes the whole ko-sensitive region (ADR-0010)" {
    const RT = Retro(2, 2);
    var t = try RT.Tables.init(std.testing.allocator);
    defer t.deinit();
    RT.seed(&t);
    RT.converge(&t);
    RT.finalize(&t);
    // modest per-root budget: bracket cuts must make every root small (the
    // PLAIN finisher needed up to 285M nodes on this goban — Finding 5)
    const fin = try RT.finish(&t, std.testing.allocator, 2_000_000, true);
    try expect(fin.budget_skipped == 0);
    try expect(fin.bracket_fail == 0);
    try expect(fin.orbit_clash == 0);
    for (0..RT.total) |i| {
        if (!t.legal[i]) continue;
        try expect(t.vb[i] != UNDEF and t.vw[i] != UNDEF);
    }
    const sym = RT.checkSymmetry(&t);
    try expect(sym.pass());
}

test "3x3 anchors bracketed by L/H (full certification checked in main)" {
    const RT = Retro(3, 3);
    var t = try RT.Tables.init(std.testing.allocator);
    defer t.deinit();
    RT.seed(&t);
    RT.converge(&t);
    RT.finalize(&t);
    const empty: RT.Pos = [_]i8{0} ** 9;
    const i: usize = @intCast(RT.X.colex_from_pos(&empty));
    // published: empty 3x3, Black to move = B+9
    try expect(t.lo.b0[i] <= 9 and 9 <= t.hi.b0[i]);
    if (t.fb[i] == 0) try expect(t.vb[i] == 9);
    // colour symmetry of the whole final table
    const sym = RT.checkSymmetry(&t);
    try expect(sym.pass());
}
