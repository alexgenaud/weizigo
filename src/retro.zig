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
//   value: i8 (UNDEF = illegal slot / unfinished residue)
//   dtt:   u8 (fastest optimal resolution, saturating; DTT_FAR = unknown/far)
//   flags: u8 (bit0 KO_SENSITIVE, bit1 FROM_FORWARD)
//
// Standalone: rules/colex/enumerate/oracle only; per-module `zig test` works.
// `zig run -O ReleaseFast src/retro.zig` = build + full battery at 2x2, 3x2
// (exhaustive ground truth vs pure no-memo forward) and 3x3 (anchors,
// exhaustive symmetry, spot checks, residue stats). Results:
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
            // build statistics
            sweeps: usize = 0,
            legal_count: u64 = 0,
            settled_count: u64 = 0,
            residue_b: u64 = 0,
            residue_w: u64 = 0,

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
                        if (apply_eye_prune) own_alive = R.pass_alive(&pos, side);
                        var have_move = false;
                        var m: i8 = undefined;
                        for (0..n) |p| {
                            if (pos[p] != 0) continue;
                            if (apply_eye_prune and R.is_own_eye(&pos, p, side, &own_alive)) continue;
                            const child = R.pos_from_move(&pos, side, p) catch continue;
                            const ci: usize = @intCast(X.colex_from_pos(&child));
                            const cv = if (maximizing) q.w0[ci] else q.b0[ci];
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
            t.residue_b = 0;
            t.residue_w = 0;
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
                    t.residue_b += 1;
                }
                if (t.lo.w0[i] == t.hi.w0[i]) {
                    t.vw[i] = t.lo.w0[i];
                } else {
                    t.fw[i] = FLAG_KO_SENSITIVE;
                    t.residue_w += 1;
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

        /// Bracket-guided fail-soft alpha-beta (ADR-0010): the finisher's
        /// forward solve with [L,H] cutoffs at EVERY node and bracket-ordered
        /// edges. Same graph, terminals, eye-prune, superko and ko_ref
        /// discipline as O.solve; the brackets add history-free cuts inside
        /// the residue, where certified-memo cuts cannot fire (Finding 6).
        pub fn ab_solve(
            t: *const Tables,
            ctx: *O.Ctx,
            pos: *const Pos,
            to_move: i8,
            passes: u8,
            alpha0: i8,
            beta0: i8,
            hist: *O.History,
        ) error{Budget}!O.Result {
            ctx.nodes += 1;
            if (ctx.budget != 0 and ctx.nodes > ctx.budget) return error.Budget;
            const idx: usize = @intCast(X.colex_from_pos(pos));
            if (passes >= 2 or t.settled[idx]) return .{ .value = t.score[idx], .ko_ref = O.KO_CLEAN };

            // bracket cut: [lo,hi] holds under ANY arrival history -> KO_CLEAN
            // (conditional assumption; ctx.brackets toggles it off)
            if (ctx.brackets) {
                const blo = lo_from_node(t, idx, to_move, passes);
                const bhi = hi_from_node(t, idx, to_move, passes);
                if (blo == bhi) return .{ .value = blo, .ko_ref = O.KO_CLEAN };
                if (bhi <= alpha0) return .{ .value = bhi, .ko_ref = O.KO_CLEAN };
                if (blo >= beta0) return .{ .value = blo, .ko_ref = O.KO_CLEAN };
            }

            const d = hist.len - 1;
            const hashable = ctx.memo and passes == 0;
            if (hashable) {
                if (to_move > 0) {
                    if (ctx.cb[idx]) return .{ .value = ctx.vb[idx], .ko_ref = O.KO_CLEAN };
                } else {
                    if (ctx.cw[idx]) return .{ .value = ctx.vw[idx], .ko_ref = O.KO_CLEAN };
                }
            }

            const maximizing = to_move > 0;
            var alpha = alpha0;
            var beta = beta0;
            // BOUNDS memo read (per-root, ko_ref-clean like the exact memo):
            // stored fail-soft bounds cut or narrow the window — this is what
            // lets one null-window probe reuse the previous probe's work.
            if (hashable) {
                const lbs = if (to_move > 0) ctx.lbb else ctx.lbw;
                const ubs = if (to_move > 0) ctx.ubb else ctx.ubw;
                if (lbs) |lb| {
                    if (lb[idx] >= beta) return .{ .value = lb[idx], .ko_ref = O.KO_CLEAN };
                    if (lb[idx] > alpha) alpha = lb[idx];
                }
                if (ubs) |ub| {
                    if (ub[idx] <= alpha) return .{ .value = ub[idx], .ko_ref = O.KO_CLEAN };
                    if (ub[idx] < beta) beta = ub[idx];
                }
            }
            // exactness / bound classification is judged against the window
            // as ENTERED after narrowing (a fail against the narrowed window
            // must not be stored as exact)
            const a_entry = alpha;
            const b_entry = beta;
            var best: i8 = if (maximizing) -127 else 127;
            var ko_ref: usize = O.KO_CLEAN;

            // gather legal edges (board moves + pass), bracket-scored
            const Edge = struct { child: Pos, order: i16, pass: bool };
            var edges: [n + 1]Edge = undefined;
            var ne: usize = 0;
            const own_alive = R.pass_alive(pos, to_move); // ADR-0006 eye-prune
            for (0..n) |p| {
                if (pos[p] != 0) continue;
                if (R.is_own_eye(pos, p, to_move, &own_alive)) continue;
                const child = R.pos_from_move(pos, to_move, p) catch continue;
                if (hist.repeatsIndex(&child)) |j| {
                    ctx.saw_ban = true;
                    if (j < ko_ref) ko_ref = j;
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
                    r = try ab_solve(t, ctx, pos, -to_move, passes + 1, alpha, beta, hist);
                } else {
                    hist.push(&e.child);
                    r = try ab_solve(t, ctx, &e.child, -to_move, 0, alpha, beta, hist);
                    hist.pop();
                }
                if (r.ko_ref < ko_ref) ko_ref = r.ko_ref;
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
            if (hashable and ko_ref >= d) {
                if (best > a_entry and best < b_entry) {
                    ctx.record(idx, to_move);
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
                            lb[idx] = best;
                        }
                    }
                } else {
                    const ubs = if (to_move > 0) ctx.ubb else ctx.ubw;
                    if (ubs) |ub| {
                        if (best < ub[idx]) {
                            ctx.record_bound(idx, to_move);
                            ub[idx] = best;
                        }
                    }
                }
            }
            return .{ .value = best, .ko_ref = ko_ref };
        }

        /// Exact fresh-start value of a root by NULL-WINDOW binary search
        /// over its own [L,H] bracket (MTD-style). A wide window makes
        /// bracket cutoffs impotent exactly where brackets are wide (the
        /// deep-residue ko tangles — measured at 4x4: aspiration search
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
                const r = try ab_solve(t, ctx, pos, to_move, 0, mid - 1, mid, hist);
                if (r.value >= mid) lo = r.value else hi = r.value;
            }
            return lo;
        }

        pub const FinishStats = struct {
            solved: u64 = 0, // orbit representatives actually solved
            filled: u64 = 0, // slots filled (incl. orbit propagation)
            budget_skipped: u64 = 0, // orbits skipped on budget
            nodes: u64 = 0,
            max_nodes: u64 = 0,
            bracket_fail: u64 = 0, // finisher value outside [L, H] (want 0)
            orbit_clash: u64 = 0, // propagation disagreed with a filled slot (want 0)
        };

        /// Resolve the KO_SENSITIVE residue: forward fresh-start solve with
        /// the memo PRE-SEEDED with every certified value (marked clean), so
        /// the search terminates at the certified frontier of the ko tangle.
        ///
        /// Each root gets a FRESH copy of the certified baseline: an interior
        /// fresh-start memo value is NOT valid under another root's history
        /// (the ADR-0008 GHI residue) — carrying ordinary memo writes across
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
            return finishProgress(t, gpa, budget, bracketed, 0);
        }

        /// finish() with a progress heartbeat (report every `progress_every`
        /// solved-or-skipped orbit reps; 0 = silent), layers deepest-first.
        pub fn finishProgress(t: *Tables, gpa: std.mem.Allocator, budget: u64, bracketed: bool, progress_every: u64) !FinishStats {
            var f = try Finisher.init(t, gpa, budget, bracketed, progress_every);
            defer f.deinit();
            var layer: usize = n + 1;
            while (layer > 0) {
                layer -= 1;
                f.runLayer(layer);
            }
            return f.st;
        }

        /// The residue finisher as a resumable, layer-at-a-time engine so a
        /// driver can CHECKPOINT between layers (hours of 4x4+ work must
        /// survive interruption). Layers are processed deepest-first by the
        /// callers: residue near the terminal wall is cheap (certified
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
            st: FinishStats = .{},
            start_ms: u64,
            next_report: u64,

            pub fn init(t: *Tables, gpa: std.mem.Allocator, budget: u64, bracketed: bool, progress_every: u64) !Finisher {
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
                f.ctx.nodes = 0;
                f.ctx.budget = f.budget;
                const solved: error{Budget}!i8 = if (f.bracketed)
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

        /// GROUND TRUTH (small boards): HISTORY-EXACT forward fresh-start
        /// solve of every legal (position, side), compared slot-for-slot
        /// against the final retrograde table. The gold standard: sound by
        /// construction, no ko_ref rule, no eye-prune, no GHI assumption
        /// (see Exact below). One memo map is shared across all roots —
        /// sound because the ban set is part of the key.
        ///
        /// Roots are checked DEEPEST LAYER FIRST with a PER-ROOT node budget:
        /// exact solving explodes toward the empty board (MEASURED at 2x2:
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

/// HISTORY-EXACT forward solver — the gold standard for SMALL boards. The
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
        pub const Key = struct { idx: u32, side: i8, passes: u8, bans: Bans };
        pub const Map = std.AutoHashMap(Key, i8);

        pub const Ctx = struct {
            map: Map,
            nodes: u64 = 0,
            budget: u64 = 0, // 0 = unlimited (shared across roots)
            entry_cap: u32 = 0, // stop INSERTING beyond this (stays sound, just slower)
        };

        pub fn solve(ctx: *Ctx, pos: *const R.Pos, side: i8, passes: u8, bans: Bans) error{ Budget, OutOfMemory }!i8 {
            ctx.nodes += 1;
            if (ctx.budget != 0 and ctx.nodes > ctx.budget) return error.Budget;
            if (passes >= 2) return R.area_score(pos);
            if (R.is_settled(pos)) return R.area_score(pos);
            const key = Key{
                .idx = @intCast(X.colex_from_pos(pos)),
                .side = side,
                .passes = passes,
                .bans = bans,
            };
            if (ctx.map.get(key)) |v| return v;
            const maximizing = side > 0;
            var best: i8 = if (maximizing) -127 else 127;
            for (0..R.n) |p| {
                if (pos[p] != 0) continue;
                const child = R.pos_from_move(pos, side, p) catch continue;
                const ci: usize = @intCast(X.colex_from_pos(&child));
                if (bans.isSet(ci)) continue; // positional superko
                var nb = bans;
                nb.set(ci);
                const v = try solve(ctx, &child, -side, 0, nb);
                if (maximizing) {
                    if (v > best) best = v;
                } else if (v < best) best = v;
            }
            const vp = try solve(ctx, pos, -side, passes + 1, bans);
            if (maximizing) {
                if (vp > best) best = vp;
            } else if (vp < best) best = vp;
            if (ctx.entry_cap == 0 or ctx.map.count() < ctx.entry_cap) {
                try ctx.map.put(key, best);
            }
            return best;
        }

        /// Fresh-start value (ADR-0008): ban set seeded with the root itself.
        pub fn root(ctx: *Ctx, pos: *const R.Pos, side: i8) error{ Budget, OutOfMemory }!i8 {
            var bans = Bans.initEmpty();
            bans.set(@intCast(X.colex_from_pos(pos)));
            return solve(ctx, pos, side, 0, bans);
        }
    };
}

/// Monotonic milliseconds (std.time.Timer is gone in Zig 0.16; the Io-based
/// clock needs an Io instance — overkill for battery timing).
fn nowMs() u64 {
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * 1000 + @as(u64, @intCast(ts.nsec)) / 1_000_000;
}

const RunOpts = struct {
    ground_truth: bool = false, // exhaustive history-exact compare (small boards only)
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
    finisher_progress_every: u64 = 0, // heartbeat every N orbit reps (0 = silent)
    diag: bool = false, // report the residue-orbit census, then CONTINUE
    diag_only: bool = false, // build + certify + report residue-orbit scale, then stop
};

/// Count residue orbit REPRESENTATIVES per side (the number of forward solves
/// the finisher must actually run — the orbit fills the rest). Cheap: build
/// + certify only, no solving.
fn residueDiag(comptime w: usize, comptime h: usize, t: anytype) void {
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
    p("residue-orbit diag: reps to solve B/W = {d}/{d} (from residue {d}/{d}); per-layer reps(B):", .{
        reps_b, reps_w, t.residue_b, t.residue_w,
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
    p("3x3 anchor probe: build sweeps={d} residue B/W={d}/{d}\n", .{ t.sweeps, t.residue_b, t.residue_w });

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
                if (certified) "CERT" else "residue",
                if (ok) "OK" else "MISMATCH", ctx.nodes, ms,
            });
        } else |_| {
            all_ok = false;
            p("  {s:<12}  BUDGET-EXCEEDED [{d},{d}] {s}  nodes>{d} {d}ms\n", .{
                a.name, lo0, hi0, if (certified) "CERT" else "residue", budget, ms,
            });
        }
    }
    p("anchor probe: {s}\n", .{if (all_ok) "PASS" else "INCOMPLETE/FAIL"});
}

/// Build the COMPLETE oracle for a board (iterate -> certify -> finish ->
/// dtt), persist it as an ADR-0011 artifact, then RELOAD the file and verify
/// the loaded bytes: every column identical to the in-memory table, and the
/// battery's key facts re-checked from the LOADED data (the file, not the
/// RAM it came from, is what future sessions trust).
fn saveArtifact(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator, path: []const u8, finisher_budget: u64, progress_every: u64, diag: bool, checkpoint_path: ?[]const u8) !void {
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
    p("build: legal={d} settled={d} sweeps={d} residue B/W={d}/{d} ({d} ms)\n", .{
        t.legal_count, t.settled_count, t.sweeps, t.residue_b, t.residue_w, nowMs() - t0,
    });
    if (diag) residueDiag(w, h, &t);
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
    {
        var f = try RT.Finisher.init(&t, gpa, finisher_budget, true, progress_every);
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
    p("finisher[bracketed]: orbits solved={d} skipped={d} nodes={d} max/root={d} ({d} ms)\n", .{
        fin.solved, fin.budget_skipped, fin.nodes, fin.max_nodes, nowMs() - t1,
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
    if (undef_legal != 0) {
        // incomplete but sound: the tractable residue is solved and
        // persisted in the checkpoint; the remainder stays bracketed [L,H].
        p("artifact: PARTIAL — {d} legal slots unfilled (budget-skipped opening residue). Checkpoint {s} holds all finished values; no final artifact written (ADR-0011: complete oracles only).\n", .{
            undef_legal, checkpoint_path orelse "(none)",
        });
        return;
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
    p("build: legal={d} settled={d} sweeps={d} residue B/W={d}/{d} ({d} ms)\n", .{
        t.legal_count, t.settled_count, t.sweeps, t.residue_b, t.residue_w, build_ms,
    });

    if (opts.diag or opts.diag_only) {
        residueDiag(w, h, &t);
        if (opts.diag_only) return;
    }

    if (opts.finisher_budget != 0) {
        const t1 = nowMs();
        const fin = try RT.finishProgress(&t, gpa, opts.finisher_budget, opts.finisher_bracketed, opts.finisher_progress_every);
        const fin_ms = nowMs() - t1;
        p("finisher[{s}]: orbits solved={d} slots filled={d} budget-skipped={d} nodes={d} max/root={d} bracket-fails={d} orbit-clashes={d} ({d} ms)\n", .{
            if (opts.finisher_bracketed) "bracketed" else "plain",
            fin.solved, fin.filled, fin.budget_skipped, fin.nodes, fin.max_nodes, fin.bracket_fail, fin.orbit_clash, fin_ms,
        });
    } else {
        p("finisher: SKIPPED (residue left bracketed [L,H]; see research/retrograde-3x3.md Finding 6)\n", .{});
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
        // published anchors (Hayward, Solving Go on Small Boards)
        var centre: RT.Pos = [_]i8{0} ** 9;
        centre[4] = 1;
        var side_b1: RT.Pos = [_]i8{0} ** 9; // bottom-centre
        side_b1[7] = 1;
        var corner: RT.Pos = [_]i8{0} ** 9; // bottom-left
        corner[6] = 1;
        // Anchors are OPENING positions = residue (Finding 6). When the
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
                p("  {s:<12} want {d:>3}: bracket [{d},{d}] {s} (residue, unfilled)\n", .{
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
        // residue per layer
        p("residue per layer (B-to-move):", .{});
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
        // the exact solver can't reach + residue the finisher didn't fill).
        // The exact solver CANNOT reach shallow roots on ANY board (Finding
        // 3), so anything below full coverage is expected, not a failure.
        const gt_sound = gt.mismatch == 0 and gt.bracket_fail == 0;
        const gt_full = gt_sound and gt.root_skipped == 0 and gt.unfilled == 0;
        p("GROUND TRUTH (history-exact): {s} checked={d} mismatch={d} bracket-fails={d} exact-unreachable={d} residue-unfilled={d} states={d} ({d} ms)\n", .{
            if (!gt_sound) "FAIL (SOUNDNESS)" else if (gt_full) "PASS (complete)" else "SOUND-PARTIAL (coverage bounded by GHI; see ADR-0009)",
            gt.checked, gt.mismatch, gt.bracket_fail, gt.root_skipped, gt.unfilled, gt.states, gt_ms,
        });
    }

    if (opts.spot_min_layer) |min_layer| {
        // Independent no-memo forward check of CERTIFIED values in deep layers
        // (near-terminal, so no-memo is tractable). Residue is NOT spot-checked
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
        const r = try RT.ab_solve(t, ctx, pos, to_move, 0, mid - 1, mid, hist);
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
    // the B+16 game, board moves only (final two passes omitted)
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

/// CONTRADICTION LOCALIZER: the replay probe reported value(P10) = -1 yet
/// max over P10's children = +1 (same position, same history) — impossible
/// if the machinery were sound under prefixes. Recompute both quantities
/// under every combination of {bracket cuts, certified seeds} to localize
/// which conditional assumption breaks. (Exact+bounds memo with the ko_ref
/// discipline stays on throughout — it is the machinery under test when
/// both toggles are off.)
fn runContra(gpa: std.mem.Allocator) void {
    contra4x4(gpa) catch |err| std.debug.print("contra FAILED: {t}\n", .{err});
}

fn contra4x4(gpa: std.mem.Allocator) !void {
    const RT = Retro(4, 4);
    const p = std.debug.print;
    const game10 = "C3 B2 B3 C2 A2 D3 C4 A3 A4 B1"; // through ply 10: B to move

    var t = try RT.Tables.init(gpa);
    defer t.deinit();
    RT.seed(&t);
    RT.converge(&t);
    RT.finalize(&t);
    p("contra: build done. quantity A = value(P10, B, prefix); B = max over children\n", .{});

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
        .budget = 3_000_000_000,
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
    const hist = try gpa.create(RT.O.History);
    defer gpa.destroy(hist);
    hist.* = .{};

    var pos: RT.Pos = [_]i8{0} ** 16;
    hist.push(&pos);
    var side: i8 = 1;
    var it = std.mem.tokenizeScalar(u8, game10, ' ');
    while (it.next()) |mv| {
        const col: usize = @intCast(std.ascii.toUpper(mv[0]) - 'A');
        const row: usize = @intCast(mv[1] - '0');
        pos = try RT.R.pos_from_move(&pos, side, (4 - row) * 4 + col);
        hist.push(&pos);
        side = -side;
    }
    // side is now Black (ply 11 to move)
    std.debug.assert(side == 1);

    inline for (.{ true, false }) |use_brackets| {
        inline for (.{ true, false }) |use_seeds| {
            ctx.brackets = use_brackets;
            const resetM = struct {
                fn go(c: *RT.O.Ctx, tt: *const RT.Tables, seeds: bool) void {
                    if (seeds) {
                        @memcpy(c.vb, tt.vb);
                        @memcpy(c.vw, tt.vw);
                        for (0..RT.total) |i| {
                            c.cb[i] = tt.legal[i] and tt.vb[i] != UNDEF;
                            c.cw[i] = tt.legal[i] and tt.vw[i] != UNDEF;
                        }
                    } else {
                        @memset(c.cb, false);
                        @memset(c.cw, false);
                    }
                    @memset(c.lbb.?, -127);
                    @memset(c.ubb.?, 127);
                    @memset(c.lbw.?, -127);
                    @memset(c.ubw.?, 127);
                    c.nodes = 0;
                }
            }.go;

            resetM(&ctx, &t, use_seeds);
            const a: i16 = if (value_from_line(4, 4, &t, &ctx, &pos, 1, hist)) |v| v else |_| -999;
            const a_nodes = ctx.nodes;
            var best: i16 = -999;
            var best_cell: usize = 99;
            var total_nodes: u64 = 0;
            for (0..16) |cell| {
                if (pos[cell] != 0) continue;
                const child = RT.R.pos_from_move(&pos, 1, cell) catch continue;
                var banned = false;
                for (hist.boards[0..hist.len]) |*b| {
                    if (std.mem.eql(i8, b, &child)) {
                        banned = true;
                        break;
                    }
                }
                if (banned) continue;
                resetM(&ctx, &t, use_seeds);
                hist.push(&child);
                const cv: i16 = if (value_from_line(4, 4, &t, &ctx, &child, -1, hist)) |v| v else |_| -999;
                hist.pop();
                total_nodes += ctx.nodes;
                if (cv != -999 and cv > best) {
                    best = cv;
                    best_cell = cell;
                }
            }
            p("  brackets={s} seeds={s}: A={d} (nodes {d})  child-max={d} (cell {d}, nodes {d})  {s}\n", .{
                if (use_brackets) "ON " else "OFF", if (use_seeds) "ON " else "OFF",
                a, a_nodes, best, best_cell, total_nodes,
                if (a != -999 and best != -999 and a < best) "INCONSISTENT" else "consistent-or-unknown",
            });
        }
    }
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

fn run4x4(gpa: std.mem.Allocator) void {
    // Full pipeline WITH persistence: a checkpoint after every finished
    // layer (resumable — rerun and it picks up where it stopped), final
    // artifact only if complete. data/ is gitignored (~258 MB files).
    // Budget 20M: MEASURED (2026-07-21) — the empty 4x4 root exceeds 500M
    // nodes (146 s); deep-opening residue is not crackable by budget at
    // this size, so hopeless roots must fail FAST (~6 s each). Layers run
    // deepest-first, so the tractable bulk is solved and checkpointed
    // before the opening tail is even attempted.
    saveArtifact(4, 4, gpa, "data/oracle-4x4.wzo", 20_000_000, 25_000, true, "data/oracle-4x4.checkpoint.wzo") catch |err| {
        std.debug.print("4x4 run FAILED: {t}\n", .{err});
    };
}

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    std.debug.print("weizigo retrograde engine (ADR-0009) -- L/H value iteration + finisher + battery\n\n", .{});
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
        try saveArtifact(2, 2, gpa, "artifacts/oracle-2x2.wzo", 500_000_000, 0, false, null);
        try saveArtifact(3, 2, gpa, "artifacts/oracle-3x2.wzo", 500_000_000, 0, false, null);
        try saveArtifact(3, 3, gpa, "artifacts/oracle-3x3.wzo", 500_000_000, 0, false, null);
        // external checksums of the files as written (verify independently of
        // the reader: `shasum -a 256 -c artifacts/SHA256SUMS` from repo root)
        try writeChecksums(gpa, "artifacts/SHA256SUMS", &.{
            "artifacts/oracle-2x2.wzo",
            "artifacts/oracle-3x2.wzo",
            "artifacts/oracle-3x3.wzo",
        });
        return;
    }
    if (std.c.getenv("RETRO_CONTRA") != null) {
        const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, runContra, .{gpa});
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
    if (std.c.getenv("RETRO_4X4") != null) {
        // THE SCALE RUN (ADR-0009/0010 consequences): 3^16 = 43,046,721 slots
        // (~1.3 GB working set). Measures the 5x5 projection numbers: sweep
        // count, residue fraction, orbit-rep census, bracketed-finisher
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
        // 2x2 only (the one board plain completes — Finding 5/6). The two
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
    // against exhaustive ground truth; 3x3 measures the full residue sweep
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

test "2x2 bracket-guided finisher completes the whole residue (ADR-0010)" {
    const RT = Retro(2, 2);
    var t = try RT.Tables.init(std.testing.allocator);
    defer t.deinit();
    RT.seed(&t);
    RT.converge(&t);
    RT.finalize(&t);
    // modest per-root budget: bracket cuts must make every root small (the
    // PLAIN finisher needed up to 285M nodes on this board — Finding 5)
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
