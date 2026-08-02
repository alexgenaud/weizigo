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
// GTP ORACLE PLAYER — play against a persisted fresh-start oracle (ADR-0011).
//
//   zig build-exe -O ReleaseFast src/gtp.zig && ./gtp artifacts/oracle-3x3.wzo
//
// Speaks enough GTP (Go Text Protocol v2) for Sabaki / gogui / gogui-twogtp:
// goban size comes from the artifact header and is not negotiable. Move
// choice per (position, side): among PSK-legal moves (and pass), maximize
// (Black) / minimize (White) the stored fresh-start child value; break value
// ties by MORE captures, then smaller child DTT (resolve fast). The pass edge
// at passes=0 leads to a V1 node the artifact does not store; it is recomputed
// as one ply of V0 lookups (the ADR-0009 Bellman equation — which holds only on
// the chainable region, see HONESTY below).
//
// HONESTY (measured 2026-07-27; docs/research/ko-sensitive-chainability.md):
// stored values are FRESH-START values, and this player steers by comparing a
// node's stored CHILDREN — a well-defined one-ply minimax only where the table
// is CHAINABLE (the history-free Bellman identity holds; GLOSSARY.md). Measured
// with bin/weizigo-chainability: the single-score (L==H) region IS chainable —
// zero violations at 2x2/3x2/3x3/4x3/4x4 (4x4 at a 1:37 sample) — and there this
// player really is fresh-start-optimal. The KO_SENSITIVE (L<H) region is NOT:
// each such slot holds an INDEPENDENT fresh-start PSK solve, so V0(P) and one
// ply of V0(child) are under no obligation to agree (4x4: 4.08% mispriced inside
// the region, worst disagreement 32 = 2n = the full goban swing). There the
// player is neither history-perfect NOR fresh-start-perfect: it steers by a
// quantity that is not defined. On 4x4 the EMPTY goban is itself KO_SENSITIVE
// (bracket [-6,+16]), so play STARTS inside that region — 16 of 19 plies are
// flagged in both saved regression games. Positional-superko bans are NOT the
// problem: in those games a ban changed the best available value at 0 of 19
// plies, so the PSK filtering below is correct and cheap; it is the value
// comparison that is unsound. KO_SENSITIVE / HISTORY-DIVERGED are printed on
// every such ply — and steered by anyway.
//
// Values assume komi 0 and Chinese/area scoring; `final_score` subtracts the
// GUI's komi from the exact area score (score-optimal play is komi-agnostic).
//
// H5(a) PLAY-TIME CHAINABILITY CHECK (EXP-9, 2026-07-28): the old
// `Session.choose` always steers by the extremum over stored V0(child)
// values. On a CHAINABLE node (L==H, identity holds) that is a sound
// one-ply minimax and the move is fresh-start-optimal. On an UNCHAINABLE
// node (L<H; ko-sensitive region) the children are independent fresh-start
// solves and the comparison is not defined — that is the source of the 32-pt
// ply-16 collapse on the 4x4 regression games. This file's `genmove` path
// now runs `Session.choose_with_check`, which performs TWO cheap identity
// checks per genmove — A1 at the current node, A2 at the chosen child (per
// D-3: a node-only check warns after the trouble is created, not before) —
// and REFUSES the V0 comparison when either fails. Refusal is a certification
// marker: the engine logs `UNCHAINABLE` and picks a history-free move
// (Benson-alive territory + stones; sound by Benson's theorem). Pass is
// NEVER the refusal — the brief's "refuse must not mean pass" rule, since
// passing in the opening is itself a blunder. Net effect: optimal where the
// table is chainable; visibly refuses (with a sound fallback) where it is
// not. See `docs/infra/dispatch/EXP-9.md` and
// `docs/research/h5a-player-mitigation-2026-07-28.md`.

const std = @import("std");
const version = @import("version");
const rules = @import("rules.zig");
const colexmod = @import("colex.zig");
const artifact = @import("artifact.zig");
const artifact2 = @import("artifact2.zig");
const score = @import("score.zig");

const COLS = "ABCDEFGHJKLMNOPQRSTUVWXYZ"; // GTP letters, no 'I'
const MAX_HIST = 4096;

/// Sentinel stored in unfilled artifact slots (2-ko+ positions on the 4x4
/// parallel artifact). The GTP player must NEVER treat this as a real score:
/// -128 is catastrophic as a fresh-start value (B39: 144-pt leaks). When a
/// child's stored value is UNDEF, that move is dropped from consideration
/// and the engine falls back to pass or another filled child.
pub const UNDEF: i8 = -128;

/// T263: session stats counters (reported on quit / weizigo-stats).
/// Module-level statics because bounds2 takes *const S and the counters
/// must survive per-session.
var stats_lookups: u64 = 0;     // total bounds2() calls
var stats_misses: u64 = 0;      // bounds2() fallback to area score
var stats_fallbacks: u64 = 0;   // choose_with_check fallback (UNCHAINABLE refusal)
var stats_genmoves: u64 = 0;    // genmove calls

/// Enforcement mode per spec oracle-v2 §3.1.
/// basic_ko = enforce the artifact's own rule (ko point only).
/// psk      = also forbid position recurrence (stricter; values are still basic-ko).
pub const Enforcement = enum { basic_ko, psk };

fn pinnedValue(L: i8, H: i8) i8 {
    return @max(L, @min(0, H));
}

pub fn Session(comptime w: usize, comptime h: usize) type {
    return struct {
        const S = @This();
        const R = rules.Rules(w, h);
        const X = colexmod.Indexer(w, h);
        const Score = score.Score(w, h);
        const n = R.n;
        const Pos = R.Pos;
        const SUSTAINED_K: u8 = 3; // polite-resign sustained-loss window (our turns)

        const KO_NONE: u8 = n; // ko sentinel: no forbidden point

        d: ?*const artifact.Decoded = null,      // v1 artifact (WZO1)
        a2: ?*const artifact2.LoadedArtifact = null, // v2 artifact (WZO2)
        enforcement: Enforcement = .basic_ko,

        pos: Pos = [_]i8{0} ** n,
        hist: [MAX_HIST]Pos = undefined,
        hist_len: usize = 0,
        passes: u8 = 0,
        ko_point: u8 = KO_NONE, // ko-forbidden point for current side-to-move
        komi: f32 = 0,
        vals_b: [SUSTAINED_K]i8 = [_]i8{0} ** SUSTAINED_K,
        vals_b_len: u8 = 0,
        vals_w: [SUSTAINED_K]i8 = [_]i8{0} ** SUSTAINED_K,
        vals_w_len: u8 = 0,

        pub fn reset(s: *S) void {
            s.pos = [_]i8{0} ** n;
            s.hist_len = 0;
            s.passes = 0;
            s.ko_point = KO_NONE;
            s.vals_b_len = 0;
            s.vals_w_len = 0;
            // the initial position has occurred: recreating it (capturing
            // everything back to an empty goban) is PSK-illegal
            s.push(&s.pos);
        }

        /// Look up L/H/DTT for a state under the WZO2 artifact.
        /// If the state is not in the artifact (unreachable under basic ko),
        /// returns the area score as a single-value terminal fallback.
        pub fn bounds2(s: *const S, pos: *const Pos, ko: u8, passes: u2, side: i8) artifact2.Row {
            const a = s.a2.?;
            const colex_val: u32 = @intCast(X.colex_from_pos(pos));

            // passes=2 terminal shortcut (§2.3)
            if (passes >= 2) {
                const area = R.area_score(pos);
                return .{ .L = area, .H = area, .DTT = 0, .terminal = true, .ko_sensitive = false };
            }

            stats_lookups += 1;
            if (artifact2.lookup(a, colex_val, side, ko, passes)) |row| {
                return row;
            }

            // Not found: unreachable state under basic ko. Fall back to area score.
            stats_misses += 1;
            const area = R.area_score(pos);
            std.debug.print("weizigo-oracle: WARNING bounds2 lookup-miss #{d} — state colex={d} side={d} ko={d} passes={d} not in artifact, fell back to area score {d}\n", .{ stats_misses, colex_val, side, ko, passes, area });
            return .{ .L = area, .H = area, .DTT = 0, .terminal = true, .ko_sensitive = false };
        }

        pub fn v0(s: *const S, pos: *const Pos, side: i8) i8 {
            if (s.a2) |_| {
                const row = s.bounds2(pos, s.ko_point, @intCast(s.passes), side);
                return pinnedValue(row.L, row.H);
            }
            const i: usize = @intCast(X.colex_from_pos(pos));
            return if (side > 0) s.d.?.vb[i] else s.d.?.vw[i];
        }
        pub fn dtt0(s: *const S, pos: *const Pos, side: i8) u8 {
            if (s.a2) |_| {
                const row = s.bounds2(pos, s.ko_point, @intCast(s.passes), side);
                return row.DTT;
            }
            const i: usize = @intCast(X.colex_from_pos(pos));
            return if (side > 0) s.d.?.db[i] else s.d.?.dw[i];
        }
        pub fn flags0(s: *const S, pos: *const Pos, side: i8) u8 {
            if (s.a2) |_| {
                const row = s.bounds2(pos, s.ko_point, @intCast(s.passes), side);
                var fl: u8 = 0;
                if (row.ko_sensitive) fl |= 1; // KO_SENSITIVE bit
                return fl;
            }
            const i: usize = @intCast(X.colex_from_pos(pos));
            return if (side > 0) s.d.?.fb[i] else s.d.?.fw[i];
        }

        pub fn seen(s: *const S, pos: *const Pos) bool {
            for (s.hist[0..s.hist_len]) |*b| {
                if (std.mem.eql(i8, b, pos)) return true;
            }
            return false;
        }

        pub fn push(s: *S, pos: *const Pos) void {
            if (s.hist_len >= MAX_HIST) @panic("gtp: game line exceeded MAX_HIST");
            s.hist[s.hist_len] = pos.*;
            s.hist_len += 1;
        }

        /// V1(pos, side) = value when `side` moves facing one standing pass:
        /// any move -> stored V0(child, -side); pass -> game ends, score now.
        /// One ply of table lookups (the artifact stores V0 only).
        /// Children whose slot is UNDEF (2-ko+ unfilled) are skipped — the
        /// pass value (area_score) stands as the fallback.
        /// SAME CAVEAT AS `choose`: chaining stored V0(child) values this way
        /// reconstructs V1 only on the CHAINABLE (L==H) region. If any child is
        /// KO_SENSITIVE, the result mixes independent fresh-start solves and is
        /// not V1 of anything (docs/research/ko-sensitive-chainability.md).
        pub fn v1_from_table(s: *const S, pos: *const Pos, side: i8) i8 {
            if (s.a2) |_| {
                // For artifact2: the pass edge at passes=0 leads to a passes=1 state
                // with ko=none and the OTHER side to move.
                const pass_row = s.bounds2(pos, KO_NONE, 1, side);
                var best: i8 = pinnedValue(pass_row.L, pass_row.H);
                for (0..n) |p| {
                    if (pos[p] != 0) continue;
                    const child = R.pos_from_move(pos, side, p) catch continue;
                    const child_ko = koAfterCapture(pos, side, &child);
                    const row = s.bounds2(&child, child_ko, 0, -side);
                    const v = pinnedValue(row.L, row.H);
                    if (if (side > 0) v > best else v < best) best = v;
                }
                return best;
            }
            const maximizing = side > 0;
            var best: i8 = R.area_score(pos); // the ending pass
            for (0..n) |p| {
                if (pos[p] != 0) continue;
                const child = R.pos_from_move(pos, side, p) catch continue;
                const v = s.v0(&child, -side);
                if (v == UNDEF) continue; // unfilled slot — fall back to pass/other moves
                if (if (maximizing) v > best else v < best) best = v;
            }
            return best;
        }

        // ---- H5(a) play-time chainability check (docs/infra/dispatch/EXP-9.md) ---
        //
        // The "chainability" identity at (P, side) is the history-free Bellman
        // identity that the existing choose() implicitly assumes:
        //
        //     V0(P, side) == best_side( { V0(child, -side) : child legal }
        //                               ∪ { V1(P, -side) } )              [the pass edge]
        //
        // It holds provably on the single-score (L==H) region (the chainability
        // sweep, docs/research/ko-sensitive-chainability.md: 0 violations
        // outside the KO_SENSITIVE flag at every goban size, exhaustive at 4x4
        // as of 2026-07-28). It does NOT hold in general on the ko-sensitive
        // region — each such slot holds an INDEPENDENT fresh-start PSK solve,
        // so V0(P) and a one-ply lookahead over V0(child) are under no
        // obligation to agree, and the disagreement can be the entire goban
        // swing (32 = 2n on 4x4).
        //
        // `Session.choose` ignores this and takes the extremum over V0(child)
        // values anyway. That's the source of the ply-16 collapse on the 4x4
        // regression games. This module is the play-time mitigation: refuse
        // the V0 comparison when the identity fails, and fall back to a
        // history-free quantity on the resulting child. The refusal IS the
        // "this move is not certified optimal" signal.

        /// Best-side extremum over LEGAL children of `pos` for `side`,
        /// including the V1 (pass edge) value. Mirrors the chainability
        /// tool's RHS exactly: filled-child V0(child, -side), area_score
        /// fallback for pass, UNDEF-children skipped. **No PSK filter**:
        /// the chainability tool's verdict (and the underlying claim about
        /// the table) is PSK-independent — PSK only restricts which child
        /// `choose` may actually play, it does not change what the table
        /// says about its own children. Mirrors bin/weizigo-chainability
        /// (`src/chainability.zig`:rhs).
        fn rhs_chain(s: *const S, pos: *const Pos, side: i8) i8 {
            const maximizing = side > 0;
            // pass edge: V1(pos, -side) — opp's value if current side passes.
            var best: i8 = s.v1_from_table(pos, -side);
            for (0..n) |p| {
                if (pos[p] != 0) continue;
                const child = R.pos_from_move(pos, side, p) catch continue;
                const v = s.v0(&child, -side);
                if (v == UNDEF) continue;
                if (if (maximizing) v > best else v < best) best = v;
            }
            return best;
        }

        /// WZO2 single-ply Bellman RHS for the full Markov key (P3-B fix).
        /// Computes best_side({ V0(child, child_ko, 0, -side) : child legal }
        /// ∪ { V0(pos, KO_NONE, passes+1, -side) }). Uses explicit ko/passes
        /// rather than s.ko_point/s.passes so that child positions can be
        /// checked with their own ko state. Basic-ko recapture is enforced
        /// (matches the stored V0's computation).
        fn rhs_chain_v2(s: *const S, pos: *const Pos, side: i8, ko: u8, passes: u2) i8 {
            const maximizing = side > 0;
            // Pass edge: side passes → ko cleared, passes+1, opponent to move.
            const pass_row = s.bounds2(pos, KO_NONE, passes + 1, -side);
            var best: i8 = pinnedValue(pass_row.L, pass_row.H);
            for (0..n) |p| {
                if (pos[p] != 0) continue;
                // Basic ko enforcement: cannot recapture at the ko point.
                // The stored V0 was computed with this constraint; RHS must match.
                if (ko != KO_NONE and p == ko) continue;
                const child = R.pos_from_move(pos, side, p) catch continue;
                const child_ko = koAfterCapture(pos, side, &child);
                const row = s.bounds2(&child, child_ko, 0, -side);
                const v = pinnedValue(row.L, row.H);
                if (if (maximizing) v > best else v < best) best = v;
            }
            return best;
        }

        /// Does the chainability identity hold at (pos, side)?
        /// For artifact2 (WZO2): checks the Markov-key Bellman identity
        /// with explicit ko/passes rather than the session's current state.
        /// For artifact1 (WZO1): checks the history-free Bellman identity.
        /// P3-B: no longer short-circuits to true for WZO2 — the check is
        /// now falsifiable and will refuse on corrupted artifacts.
        pub fn chainable_at_pos(s: *const S, pos: *const Pos, side: i8, ko: u8, passes: u2) bool {
            if (s.a2) |_| {
                // Artifact2 (WZO2): Markov-key Bellman identity.
                const stored_row = s.bounds2(pos, ko, passes, side);
                const stored = pinnedValue(stored_row.L, stored_row.H);
                const expected = s.rhs_chain_v2(pos, side, ko, passes);
                return expected == stored;
            }
            // Artifact1 (WZO1): check the history-free Bellman identity
            if (R.is_settled(pos)) return true;
            const stored = s.v0(pos, side);
            if (stored == UNDEF) return true; // unfilled; nothing to compare
            const expected = s.rhs_chain(pos, side);
            return expected == stored;
        }

        /// Convenience wrapper for the current game state.
        pub fn chainable_at(s: *const S, side: i8) bool {
            return s.chainable_at_pos(&s.pos, side, s.ko_point, @intCast(s.passes));
        }

        /// History-free score for the refusal fallback: a snapshot-only,
        /// sound-by-Benson quantity.
        ///
        ///   (+1 per own Benson-alive stone) − (+1 per opp Benson-alive stone)
        /// + (+1 per territory point surrounded only by own Benson-alive groups)
        /// − (+1 per territory point surrounded only by opp Benson-alive groups)
        ///
        /// SOUND by Benson's theorem (rules.zig: a Benson-alive chain cannot
        /// be captured regardless of opponent play, so the alive-count and
        /// alive-territory are preserved under any future move sequence).
        /// History-free: it depends only on the post-move snapshot, not on
        /// the game's accumulated ban set. This is the certification floor
        /// for the "refuse V0, fall back" branch — not a strategy, just a
        /// move-selection signal that does not chain table values.
        /// Takes no `self`: it reads ONLY the position, never the artifact or
        /// the game history. That is the whole point (and it lets the
        /// antisymmetry property be unit-tested without an artifact).
        pub fn fallback_score(pos: *const Pos, side: i8) i8 {
            const opp: i8 = -side;
            const balive = R.benson_alive(pos, side);
            const walive = R.benson_alive(pos, opp);
            var acc: i16 = 0;
            for (0..n) |p| {
                if (pos[p] == side and balive[p]) acc += 1;
                if (pos[p] == opp and walive[p]) acc -= 1;
            }
            // Territory: flood empty regions. A region contributes +size if it
            // touches only friendly Benson-alive stones, -size if only enemy
            // Benson-alive stones, and 0 if it touches any non-alive group
            // (dame / contested / shared liberty). Same flood as area_score /
            // territory_japanese; the difference is the *adjacency filter*:
            // we only credit territory when the bordering stones are
            // guaranteed-stable by Benson.
            var visited = [_]bool{false} ** n;
            for (0..n) |p| {
                if (pos[p] != 0 or visited[p]) continue;
                var stack: [n]usize = undefined;
                var sp: usize = 1;
                stack[0] = p;
                visited[p] = true;
                var size: i16 = 0;
                var tb = false; // touches only own Benson-alive
                var tw = false; // touches only opp Benson-alive
                var mixed = false; // touches both, or a non-alive group
                while (sp > 0) {
                    sp -= 1;
                    const q = stack[sp];
                    size += 1;
                    var nb: [4]usize = undefined;
                    const cnt = R.neighbors(q, &nb);
                    for (nb[0..cnt]) |r| {
                        if (pos[r] * side > 0) {
                            if (balive[r]) {
                                if (tw) mixed = true;
                                tb = true;
                            } else mixed = true; // own stone not alive -> uncertain
                        } else if (pos[r] * opp > 0) {
                            if (walive[r]) {
                                if (tb) mixed = true;
                                tw = true;
                            } else mixed = true;
                        } else if (!visited[r]) {
                            visited[r] = true;
                            stack[sp] = r;
                            sp += 1;
                        }
                    }
                }
                if (mixed) continue;
                if (tb and !tw) acc += size;
                if (tw and !tb) acc -= size;
            }
            return @intCast(acc);
        }

        const Choice = struct { cell: ?usize, value: i8, dtt: u8, caps: u16 = 0 };

        /// Best move (or pass) for `side` from the current game state: the max
        /// (Black) / min (White) STORED CHILD value among PSK-legal options.
        /// SCOPE OF THAT EXTREMUM (measured 2026-07-27,
        /// docs/research/ko-sensitive-chainability.md): it is a well-defined
        /// one-ply minimax — and the pick genuinely fresh-start-optimal — only
        /// on the CHAINABLE region, i.e. single-score (L==H, no KO_SENSITIVE
        /// flag) nodes, where zero Bellman-identity violations were found at
        /// 2x2/3x2/3x3/4x3/4x4. On a KO_SENSITIVE (L<H) node the children hold
        /// INDEPENDENT fresh-start solves that need not agree with this node or
        /// with each other, so the comparison below is not an evaluation: the
        /// move returned is neither history-optimal nor fresh-start-optimal
        /// (4x4: 4.08% mispriced inside the region, by up to 2n = the whole
        /// goban). Everything from here down is unchanged and still accurate as
        /// a description of the SELECTION RULE; only its warrant is narrower.
        ///
        /// TIE-BREAK among equal-value moves: MORE captures first (finish the
        /// game - capture dead stones rather than dither; uncaptured dead
        /// stones still count for the opponent at game-end under area
        /// scoring), then smaller DTT.
        ///
        /// PASS POLICY: pass only when it is OPTIMAL (never suboptimally). But
        /// in the EARLY game the engine plays a move even when pass is TIED-
        /// optimal ("always play the opening"): on 4x4, after a strong 2-stone
        /// Black opening White is already fresh-start-dead (value 16), so pass
        /// is tied-optimal and pure-optimal would pass out immediately (game
        /// over after 2 stones - not a fun opening). Playing a tied-optimal move
        /// instead never passes suboptimally (consistent with "pass only if
        /// optimal") and gives 4x4 a real opening. In the LATE game, when
        /// winning decisively the engine CAPTURES the dead stones (capture-
        /// priority) until none remain, after which pass is optimal -> it
        /// passes -> two passes -> game ends -> Sabaki scores a winner. (Resign
        /// is the only politeness, handled by the caller before choose runs.)
        pub fn choose(s: *const S, side: i8) Choice {
            if (s.a2) |_| return s.chooseV2(side);
            return s.chooseV1(side);
        }

        /// Artifact2 (WZO2) move selection: basic-ko enforcement, full Markov key.
        /// Uses pinned TIE=0 value for comparison; L/H bounds exposed for diagnostics.
        fn chooseV2(s: *const S, side: i8) Choice {
            const maximizing = side > 0;
            const opp: i8 = -side;
            const opp_before = S.countColor(&s.pos, opp);

            // Pass candidate: lookup pass child (ko=none, passes+1, other side)
            const pass_value: i8 = if (s.passes >= 1)
                R.area_score(&s.pos)
            else blk: {
                const pass_row = s.bounds2(&s.pos, KO_NONE, @intCast(s.passes + 1), -side);
                break :blk pinnedValue(pass_row.L, pass_row.H);
            };
            const pass = Choice{
                .cell = null,
                .value = pass_value,
                .dtt = if (s.passes >= 1) 0 else 1,
                .caps = 0,
            };
            var best: ?Choice = pass;
            var best_move: ?Choice = null;

            for (0..n) |p| {
                if (s.pos[p] != 0) continue;

                // Basic ko enforcement: cannot recapture at the ko point
                if (s.ko_point != KO_NONE and p == s.ko_point) continue;

                const child = R.pos_from_move(&s.pos, side, p) catch continue;

                // PSK enforcement if mode is psk
                if (s.enforcement == .psk and s.seen(&child)) continue;

                const child_ko = koAfterCapture(&s.pos, side, &child);
                const row = s.bounds2(&child, child_ko, 0, -side);
                const v = pinnedValue(row.L, row.H);
                const dt = row.DTT;
                const caps: u16 = opp_before - S.countColor(&child, opp);
                const mv = Choice{ .cell = p, .value = v, .dtt = dt, .caps = caps };
                best_move = S.pick(best_move, mv, maximizing);
                best = S.pick(best, mv, maximizing);
            }

            // Early game: if pass would be chosen, play the best move instead
            if (best.?.cell == null) {
                const area: usize = w * h;
                const min_own: usize = area / 4;
                const min_total: usize = area / 2;
                var own: usize = 0;
                var tot: usize = 0;
                for (s.pos) |x| {
                    if (x == 0) continue;
                    tot += 1;
                    if ((x > 0) == (side > 0)) own += 1;
                }
                if (own < min_own and tot < min_total) {
                    if (best_move) |bm| return bm;
                }
            }
            return best.?;
        }

        /// Artifact1 (WZO1) move selection: original PSK enforcement, V0 comparison.
        fn chooseV1(s: *const S, side: i8) Choice {
            const maximizing = side > 0;
            const opp: i8 = -side;
            const opp_before = S.countColor(&s.pos, opp);
            const pass = Choice{
                .cell = null,
                .value = if (s.passes >= 1) R.area_score(&s.pos) else s.v1_from_table(&s.pos, -side),
                .dtt = if (s.passes >= 1) 0 else 1,
                .caps = 0,
            };
            var best: ?Choice = pass; // pass is a candidate
            var best_move: ?Choice = null; // best non-pass candidate (early-game effort)
            for (0..n) |p| {
                if (s.pos[p] != 0) continue;
                const child = R.pos_from_move(&s.pos, side, p) catch continue;
                if (s.seen(&child)) continue; // positional superko
                const v = s.v0(&child, -side);
                if (v == UNDEF) continue; // unfilled slot (2-ko+): skip
                const dt = s.dtt0(&child, -side);
                const caps: u16 = opp_before - S.countColor(&child, opp);
                const mv = Choice{ .cell = p, .value = v, .dtt = dt, .caps = caps };
                best_move = S.pick(best_move, mv, maximizing);
                best = S.pick(best, mv, maximizing);
            }
            // early game (own < area/4 AND total < area/2; 4 own / 8 total on
            // 4x4): if pass would be chosen, play the best move instead.
            if (best.?.cell == null) {
                const area: usize = w * h;
                const min_own: usize = area / 4;
                const min_total: usize = area / 2;
                var own: usize = 0;
                var tot: usize = 0;
                for (s.pos) |x| {
                    if (x == 0) continue;
                    tot += 1;
                    if ((x > 0) == (side > 0)) own += 1;
                }
                if (own < min_own and tot < min_total) {
                    if (best_move) |bm| return bm;
                }
            }
            return best.?;
        }

        /// Tie-break: value (max/min) primary; then MORE captures (finish the
        /// game); then SMALLER DTT (resolve fast). `cur` may be null (seed).
        fn pick(cur: ?Choice, mv: Choice, maximizing: bool) ?Choice {
            if (cur == null) return mv;
            const c = cur.?;
            const vbetter = if (maximizing) mv.value > c.value else mv.value < c.value;
            if (vbetter) return mv;
            if (mv.value != c.value) return c;
            if (mv.caps != c.caps) return if (mv.caps > c.caps) mv else c;
            if (mv.dtt != c.dtt) return if (mv.dtt < c.dtt) mv else c;
            return c;
        }

        /// H5(a) wrapper around `choose`: do the play-time chainability check
        /// (A1 at the current node + A2 at the chosen child, EXP-9) and fall
        /// back to a history-free per-move score when the identity fails.
        ///
        /// Returns {choice, refused}:
        ///   refused == false -> play `choice` exactly as the old engine would
        ///   refused == true  -> play `choice` (the history-free pick) and
        ///                       log `UNCHAINABLE` so the operator sees the
        ///                       refusal; the move is NOT a V0-optimal move,
        ///                       it is a sound history-free fallback. This
        ///                       is the certification signal: a refused ply
        ///                       is a ply where the table does not justify
        ///                       itself and the engine declines to claim
        ///                       optimality.
        /// Which check refused, if any. Reported in the log so an operator can
        /// tell a node-level refusal (A1: this position's own stored value
        /// already disagrees with its children) from the D-3 case that matters
        /// (A2: this node is fine, but the move `choose` wanted to play ENTERS
        /// an unchainable child). EXP-9 acceptance criterion 4 is specifically
        /// about A2 firing one ply BEFORE the collapse.
        pub const Refusal = enum { none, a1_node, a2_child };

        pub const CheckedChoice = struct {
            choice: Choice,
            /// Set iff A1 or A2 failed and the engine fell back to the
            /// history-free per-move score. The "refusal" is the certification
            /// marker — see EXP-9 acceptance criteria.
            cause: Refusal,

            pub fn refused(cc: CheckedChoice) bool {
                return cc.cause != .none;
            }
        };

        pub fn choose_with_check(s: *const S, side: i8) CheckedChoice {
            // A1: chainability at the current node. If the history-free Bellman
            // identity holds here, choose()'s V0 comparison is meaningful at
            // THIS ply.
            const a1 = s.chainable_at(side);
            if (a1) {
                // Still need A2: the chosen child must itself be chainable,
                // otherwise we are walking into an unchainable region one
                // move at a time. This is the D-3 correction: a node-only
                // check warns after the trouble is already created.
                const c = s.choose(side);
                if (c.cell) |cell| {
                    // A2 only meaningful for non-pass moves: a pass has no
                    // child to enter. The pass edge is already covered by A1.
                    const child = R.pos_from_move(&s.pos, side, cell) catch {
                        // Should not happen: choose() validated this. Treat
                        // as refusal-safe: fall through to fallback.
                        return s.fallback_pick(side, .a2_child);
                    };
                    // Compute child's ko for correct WZO2 Markov-key lookup.
                    // applyMove hasn't been called yet, so s.ko_point is the
                    // parent's ko; the child's ko is koAfterCapture from parent.
                    const child_ko = koAfterCapture(&s.pos, side, &child);
                    if (s.chainable_at_pos(&child, -side, child_ko, 0)) {
                        return .{ .choice = c, .cause = .none };
                    }
                    // A2 failed: refuse. Fall back.
                    return s.fallback_pick(side, .a2_child);
                }
                // Pass candidate: A1 already certified; trust the choice.
                return .{ .choice = c, .cause = .none };
            }
            // A1 failed: refuse. Fall back.
            return s.fallback_pick(side, .a1_node);
        }

        /// History-free per-move move selection. Used only on refusal.
        /// For every PSK-legal, non-pass move, evaluate `fallback_score` on
        /// the resulting child position. Pick the move that MAXIMISES the
        /// score (Black maximises, White maximises — both sides want a
        /// higher history-free score, i.e. more own alive territory minus
        /// opp alive territory).
        ///
        /// Tie-break among equal-scoring moves: a) pass is NOT a candidate
        /// (per EXP-9: "refuse" must not mean pass); b) among equal-scoring
        /// non-pass moves, prefer the smaller colex cell (deterministic).
        ///
        /// If no legal non-pass move exists, fall back to pass (matches the
        /// existing all-UNDEF behaviour).
        ///
        /// SIGN CONVENTION (fixed 2026-07-29 while completing EXP-9):
        /// `fallback_score` is **side-relative** — it counts the mover's own
        /// Benson-alive stones/territory as POSITIVE and the opponent's as
        /// negative, so `fallback_score(pos, +1) == -fallback_score(pos, -1)`.
        /// Therefore BOTH colours MAXIMISE it (as this function's doc comment
        /// above always said). The original EXP-9 draft branched on
        /// `maximizing = side > 0` and minimised for White, which made White
        /// choose the move WORST for itself on every refusal — inverting the
        /// fallback exactly where it is supposed to be the sound floor. Do not
        /// reintroduce a colour branch here: the colour is already inside the
        /// score.
        fn fallback_pick(s: *const S, side: i8, cause: Refusal) CheckedChoice {
            stats_fallbacks += 1;
            var best: ?Choice = null;
            for (0..n) |p| {
                if (s.pos[p] != 0) continue;
                const child = R.pos_from_move(&s.pos, side, p) catch continue;
                if (s.seen(&child)) continue; // positional superko
                const dt = s.dtt0(&child, -side);
                const sc = S.fallback_score(&child, side);
                // The "value" of a refused move carries the history-free score
                // (so the log line can show it) and the existing dtt (so the
                // engine still records "fastest optimal resolution" where it
                // was known). caps is left at 0 — captures don't matter to
                // the refusal path; area-score and chain are the certification
                // here.
                const mv = Choice{ .cell = p, .value = sc, .dtt = dt, .caps = 0 };
                // Primary: maximise fallback_score (both colours — see the
                // sign-convention note above). Tie-break: smaller colex cell,
                // which `p` ascending already gives us for free, so a strict
                // `>` keeps the first (lowest) cell among equals.
                if (best == null or mv.value > best.?.value) best = mv;
            }
            if (best) |bm| return .{ .choice = bm, .cause = cause };
            // No legal non-pass move: pass. Same backstop as choose().
            const pass = Choice{ .cell = null, .value = S.fallback_score(&s.pos, side), .dtt = 0, .caps = 0 };
            return .{ .choice = pass, .cause = cause };
        }

        fn countColor(pos: *const Pos, color: i8) u16 {
            var c: u16 = 0;
            for (pos) |x| if (x == color) { c += 1; };
            return c;
        }


        /// Compute ko_point after a placement. Returns KO_NONE if no ko created.
        /// Delegates to rules.koAfterCapture — the single production ko rule
        /// (Phase 2 kernel, T273). [GLOBAL.AXIOM-BASICKO:CLAIMED]
        fn koAfterCapture(old_pos: *const Pos, side: i8, new_pos: *const Pos) u8 {
            return rules.koAfterCapture(old_pos, new_pos, side, w, h, KO_NONE);
        }

        pub fn applyMove(s: *S, side: i8, cell: ?usize) !void {
            if (cell) |p| {
                const old_pos = s.pos;
                const child = try R.pos_from_move(&s.pos, side, p);
                s.pos = child;
                s.push(&child);
                s.passes = 0;
                // Track ko: if we captured exactly one stone, the opponent cannot recapture there
                s.ko_point = koAfterCapture(&old_pos, side, &child);
            } else {
                s.passes += 1;
                s.ko_point = KO_NONE; // pass clears the ko
            }
        }
    };
}

// ---- vertex <-> cell (GTP: column letters skip I, row 1 = bottom) -----------

pub fn vertex_from_cell(buf: []u8, cell: usize, w: usize, h: usize) []u8 {
    const col = cell % w;
    const row_from_top = cell / w;
    const row_num = h - row_from_top;
    return std.fmt.bufPrint(buf, "{c}{d}", .{ COLS[col], row_num }) catch unreachable;
}

pub fn cell_from_vertex(token: []const u8, w: usize, h: usize) ?usize {
    if (token.len < 2) return null;
    const letter = std.ascii.toUpper(token[0]);
    const col = std.mem.indexOfScalar(u8, COLS, letter) orelse return null;
    const row_num = std.fmt.parseInt(usize, token[1..], 10) catch return null;
    if (col >= w or row_num < 1 or row_num > h) return null;
    return (h - row_num) * w + col;
}

/// Parse "NxN" or "NxM" goban-size shorthand. Returns .{w, h} or null.
fn parseBoardSize(s: []const u8) ?[2]usize {
    const x = std.mem.indexOfScalar(u8, s, 'x') orelse return null;
    const w = std.fmt.parseInt(usize, s[0..x], 10) catch return null;
    const h = std.fmt.parseInt(usize, s[x + 1 ..], 10) catch return null;
    if (w == 0 or h == 0 or w > 25 or h > 25) return null;
    return .{ w, h };
}

// ---- score-report formatting helpers ----------------------------------------

fn fmtAreaCounts(buf: []u8, area: i8, dame_count: usize, board_n: usize) []u8 {
    const neutral: i16 = @intCast(dame_count);
    const a: i16 = @intCast(area);
    const nn: i16 = @intCast(board_n);
    const black = @divTrunc(a + nn - neutral, 2);
    const white = @divTrunc(nn - neutral - a, 2);
    return std.fmt.bufPrint(buf, "B+{d} / W+{d} (area)", .{ black, white }) catch unreachable;
}

fn fmtTerritory(buf: []u8, terr: anytype) []u8 {
    return std.fmt.bufPrint(buf, "territory B+{d}/W+{d}", .{ terr.black, terr.white }) catch unreachable;
}

fn fmtDame(buf: []u8, count: usize) []u8 {
    return std.fmt.bufPrint(buf, "dame {d}", .{count}) catch unreachable;
}

fn fmtDead(buf: []u8, dead: anytype) []u8 {
    return std.fmt.bufPrint(buf, "dead B+{d}/W+{d}", .{ dead.dead_black_count, dead.dead_white_count }) catch unreachable;
}

fn fmtVertexList(buf: []u8, points: []const usize, w_arg: usize, h_arg: usize) []u8 {
    if (points.len == 0) return std.fmt.bufPrint(buf, "none", .{}) catch unreachable;
    var off: usize = 0;
    for (points, 0..) |p, k| {
        if (k != 0) {
            buf[off] = ',';
            off += 1;
            buf[off] = ' ';
            off += 1;
        }
        const v = vertex_from_cell(buf[off..], p, w_arg, h_arg);
        off += v.len;
    }
    return buf[0..off];
}

/// One artefact load + log setup + dispatch. Detects WZO1 vs WZO2 by trying WZO2 first.
fn loadAndDispatch(io: std.Io, gpa: std.mem.Allocator, path: []const u8, opt_log_dir: ?[]const u8, enforcement: Enforcement) !void {
    // Determine goban size from the path: try to load header to get w/h.
    // For WZO2, we need to know w/h before calling load().
    // Strategy: try loading with typical sizes; or parse from filename.
    // Simplest: try WZO2 first with a size guess, then fall back.
    if (try tryWzo2Load(io, gpa, path, opt_log_dir, enforcement)) return;
    return loadAndDispatchV1(io, gpa, path, opt_log_dir);
}

/// Try loading as WZO2 artifact. Returns true on success (dispatch handled internally).
fn tryWzo2Load(io: std.Io, gpa: std.mem.Allocator, path: []const u8, opt_log_dir: ?[]const u8, enforcement: Enforcement) !bool {
    // Peek at first 4 bytes to check magic
    const peek = std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .unlimited) catch return false;
    if (peek.len < 4 or !std.mem.eql(u8, peek[0..4], &artifact2.MAGIC)) {
        gpa.free(peek);
        return false;
    }
    gpa.free(peek);

    var a2 = artifact2.load(io, std.Io.Dir.cwd(), path, gpa) catch |err| {
        std.debug.print("weizigo-oracle: WZO2 load failed for '{s}': {t}\n", .{ path, err });
        return false;
    };

    std.debug.print("weizigo-oracle: {s} ({d}x{d}, {d} groups, {d} entries) [WZO2]\n", .{
        path, a2.header.w, a2.header.h, a2.header.n_groups, a2.header.n_entries,
    });
    std.debug.print("weizigo-oracle: table rules_id={d} — {s}\n", .{
        artifact2.RULES_BASICKO_LH_AREA, artifact2.rulesName(artifact2.RULES_BASICKO_LH_AREA),
    });
    std.debug.print("weizigo-oracle: ENFORCEMENT {s} (artifact rules_id {d})\n", .{
        @tagName(enforcement), artifact2.RULES_BASICKO_LH_AREA,
    });

    const artifact_dir = std.fs.path.dirname(path) orelse ".";
    const log_dir = opt_log_dir orelse try std.fmt.allocPrint(gpa, "{s}/../log", .{artifact_dir});
    const dir = std.Io.Dir.cwd();
    const log_file: ?std.Io.File = blk: {
        dir.createDirPath(io, log_dir) catch break :blk null;
        const log_path = try std.fmt.allocPrint(gpa, "{s}/weizigo-{d}.log", .{ log_dir, unix_seconds() });
        const f = dir.createFile(io, log_path, .{}) catch break :blk null;
        std.debug.print("weizigo-oracle: transcript -> {s}\n", .{log_path});
        break :blk f;
    };
    const log = LogSink{ .io = io, .file = log_file };
    log.line("# weizigo-oracle session, artifact {s} ({d}x{d} WZO2), unix time {d}", .{
        path, a2.header.w, a2.header.h, unix_seconds(),
    });

    const key = @as(usize, a2.header.w) * 100 + a2.header.h;
    switch (key) {
        202 => try runSession(2, 2, gpa, null, &a2, &log, &[_]u8{}, enforcement),
        302 => try runSession(3, 2, gpa, null, &a2, &log, &[_]u8{}, enforcement),
        303 => try runSession(3, 3, gpa, null, &a2, &log, &[_]u8{}, enforcement),
        403 => try runSession(4, 3, gpa, null, &a2, &log, &[_]u8{}, enforcement),
        404 => try runSession(4, 4, gpa, null, &a2, &log, &[_]u8{}, enforcement),
        else => {
            std.debug.print("unsupported WZO2 artifact board {d}x{d}\n", .{ a2.header.w, a2.header.h });
            return error.UnsupportedBoard;
        },
    }
    return true;
}

fn loadAndDispatchV1(io: std.Io, gpa: std.mem.Allocator, path: []const u8, opt_log_dir: ?[]const u8) !void {
    var dec = artifact.load(io, std.Io.Dir.cwd(), path, gpa) catch |err| {
        std.debug.print("weizigo-oracle: cannot load artifact '{s}': {t}\n" ++
            "  hint: when launching from a GUI, pass an ABSOLUTE path to the .wzo file\n", .{ path, err });
        return err;
    };
    defer dec.deinit();
    std.debug.print("weizigo-oracle: {s} ({d}x{d}, {d} legal/side) [WZO1]\n", .{
        path, dec.header.board_w, dec.header.board_h, dec.header.legal_count,
    });
    std.debug.print("weizigo-oracle: table rules_id={d} — {s}\n", .{
        dec.header.rules_id, artifact.rulesName(dec.header.rules_id),
    });
    // The table is keyed on (pattern, side) only: no ko point, no pass count.
    // Move selection below enforces positional superko regardless. Say so out
    // loud — a silent mismatch between the table's rule and the player's rule
    // is exactly the class of defect this project keeps paying for.
    if (dec.header.rules_id != artifact.RULES_CHINESE_PSK) {
        std.debug.print("weizigo-oracle: WARNING — move selection enforces positional superko, " ++
            "but this table was solved under a different rule.\n" ++
            "weizigo-oracle: WARNING — stored values assume NO ko pending and NO prior pass; " ++
            "expect misplay in live ko and in the endgame.\n", .{});
    }

    const artifact_dir = std.fs.path.dirname(path) orelse ".";
    const log_dir = opt_log_dir orelse try std.fmt.allocPrint(gpa, "{s}/../log", .{artifact_dir});
    const dir = std.Io.Dir.cwd();
    const log_file: ?std.Io.File = blk: {
        dir.createDirPath(io, log_dir) catch break :blk null;
        const log_path = try std.fmt.allocPrint(gpa, "{s}/weizigo-{d}.log", .{ log_dir, unix_seconds() });
        const f = dir.createFile(io, log_path, .{}) catch break :blk null;
        std.debug.print("weizigo-oracle: transcript -> {s}\n", .{log_path});
        break :blk f;
    };
    const log = LogSink{ .io = io, .file = log_file };
    log.line("# weizigo-oracle session, artifact {s} ({d}x{d}), unix time {d}", .{
        path, dec.header.board_w, dec.header.board_h, unix_seconds(),
    });

    const key = @as(usize, dec.header.board_w) * 100 + dec.header.board_h;
    switch (key) {
        202 => try runSession(2, 2, gpa, &dec, null, &log, &[_]u8{}, .psk),
        302 => try runSession(3, 2, gpa, &dec, null, &log, &[_]u8{}, .psk),
        303 => try runSession(3, 3, gpa, &dec, null, &log, &[_]u8{}, .psk),
        403 => try runSession(4, 3, gpa, &dec, null, &log, &[_]u8{}, .psk),
        404 => try runSession(4, 4, gpa, &dec, null, &log, &[_]u8{}, .psk),
        603 => try runSession(6, 3, gpa, &dec, null, &log, &[_]u8{}, .psk),
        505 => try runSession(5, 5, gpa, &dec, null, &log, &[_]u8{}, .psk),
        else => {
            std.debug.print("unsupported artifact board {d}x{d}\n", .{ dec.header.board_w, dec.header.board_h });
            return error.UnsupportedBoard;
        },
    }
}

// ---- session transcript log ---------------------------------------------------

/// Line-flushed transcript of the whole session (commands, responses, oracle
/// diagnostics) so every game against a human is preserved for the review /
/// arena pipeline. Null file = logging disabled (open failure is not fatal).
fn unix_seconds() i64 {
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(.REALTIME, &ts);
    return ts.sec;
}

const LogSink = struct {
    io: std.Io,
    file: ?std.Io.File,

    fn line(l: *const LogSink, comptime fmt: []const u8, args: anytype) void {
        if (l.file) |f| {
            var buf: [4096]u8 = undefined;
            const s = std.fmt.bufPrint(&buf, fmt ++ "\n", args) catch return;
            f.writeStreamingAll(l.io, s) catch {};
        }
    }
};

// ---- GTP main loop -----------------------------------------------------------

const KNOWN_COMMANDS = [_][]const u8{
    "protocol_version", "name",        "version",  "known_command", "list_commands",
    "boardsize",        "rectangular_boardsize",    "clear_board",   "komi",
    "play",             "genmove",     "undo",     "showboard",     "final_score",
    "weizigo_settled",  "weizigo_estimate", "weizigo_score",
    "weizigo_chaincheck", "weizigo-stats",
    "quit",
};

fn runSession(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator, dec: ?*const artifact.Decoded, a2: ?*const artifact2.LoadedArtifact, log: *const LogSink, pre: []const u8, enforcement: Enforcement) !void {
    const S = Session(w, h);
    var s = S{ .d = dec, .a2 = a2, .enforcement = enforcement };

    var threaded = std.Io.Threaded.init(gpa, .{});
    const io = threaded.io();
    const stdin = std.Io.File.stdin();
    const stdout = std.Io.File.stdout();

    var in_buf: [4096]u8 = undefined;
    var line: std.ArrayList(u8) = .empty;
    defer line.deinit(gpa);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);
    var vbuf: [8]u8 = undefined;
    var sbuf: [4096]u8 = undefined;

    var pre_pos: usize = 0;

    while (true) {
        const buf: []const u8 = if (pre_pos < pre.len) blk: {
            const slice = pre[pre_pos..];
            pre_pos = pre.len;
            break :blk slice;
        } else blk: {
            const got = stdin.readStreaming(io, &.{&in_buf}) catch 0;
            if (got == 0) break; // EOF
            break :blk in_buf[0..got];
        };
        for (buf) |ch| {
            if (ch != '\n') {
                try line.append(gpa, ch);
                continue;
            }
            // ---- one GTP command line ----
            log.line("< {s}", .{std.mem.trim(u8, line.items, " \t\r")});
            var tokens = std.mem.tokenizeAny(u8, line.items, " \t\r");
            var first = tokens.next() orelse continue;
            var id: []const u8 = "";
            if (first.len > 0 and std.ascii.isDigit(first[0])) {
                id = first;
                first = tokens.next() orelse continue;
            }
            out.clearRetainingCapacity();
            var quit = false;
            var ok = true;
            var reply: []const u8 = "";
            var rbuf: [512]u8 = undefined;

            if (std.mem.eql(u8, first, "protocol_version")) {
                reply = "2";
            } else if (std.mem.eql(u8, first, "name")) {
                reply = "weizigo-oracle";
            } else if (std.mem.eql(u8, first, "version")) {
                reply = std.fmt.bufPrint(&rbuf, "{d}x{d}-wzo1", .{ w, h }) catch unreachable;
            } else if (std.mem.eql(u8, first, "known_command")) {
                const q = tokens.next() orelse "";
                reply = "false";
                for (KNOWN_COMMANDS) |c| {
                    if (std.mem.eql(u8, c, q)) reply = "true";
                }
            } else if (std.mem.eql(u8, first, "list_commands")) {
                var lb: [256]u8 = undefined;
                var ll: usize = 0;
                for (KNOWN_COMMANDS, 0..) |c, k| {
                    if (k != 0) {
                        lb[ll] = '\n';
                        ll += 1;
                    }
                    @memcpy(lb[ll .. ll + c.len], c);
                    ll += c.len;
                }
                @memcpy(rbuf[0..ll], lb[0..ll]);
                reply = rbuf[0..ll];
            } else if (std.mem.eql(u8, first, "boardsize") or std.mem.eql(u8, first, "rectangular_boardsize")) {
                // Square GTP is "boardsize N"; for non-square gobans Sabaki
                // sends "rectangular_boardsize W H" (and detects support via
                // known_command, so it MUST be listed). Either way: first token
                // = width, optional second = height (defaults to width). The
                // goban is fixed by the artifact; accept only an exact match.
                const q = tokens.next() orelse "";
                const want_w = std.fmt.parseInt(usize, q, 10) catch 0;
                const q2 = tokens.next();
                const want_h = if (q2) |s2| (std.fmt.parseInt(usize, s2, 10) catch 0) else want_w;
                if (want_w == w and want_h == h) {
                    s.reset();
                } else {
                    ok = false;
                    reply = "unacceptable size";
                }
            } else if (std.mem.eql(u8, first, "clear_board")) {
                s.reset();
            } else if (std.mem.eql(u8, first, "komi")) {
                const q = tokens.next() orelse "0";
                s.komi = std.fmt.parseFloat(f32, q) catch 0;
            } else if (std.mem.eql(u8, first, "play")) {
                const colort = tokens.next() orelse "";
                const vert = tokens.next() orelse "";
                const side: i8 = if (colort.len > 0 and (colort[0] == 'b' or colort[0] == 'B')) 1 else -1;
                if (std.ascii.eqlIgnoreCase(vert, "pass")) {
                    s.applyMove(side, null) catch {};
                } else if (cell_from_vertex(vert, w, h)) |cell| {
                    // Basic ko enforcement (default for WZO2; also valid for WZO1)
                    if (s.ko_point != S.KO_NONE and cell == s.ko_point) {
                        ok = false;
                        reply = "illegal move (ko)";
                    } else {
                        const child = S.R.pos_from_move(&s.pos, side, cell) catch null;
                        // PSK enforcement or if enforcement is psk
                        const psk_illegal = child != null and s.seen(&child.?);
                        if (psk_illegal) {
                            ok = false;
                            reply = "illegal move (positional superko)";
                        } else {
                            s.applyMove(side, cell) catch {
                                ok = false;
                                reply = "illegal move";
                            };
                        }
                    }
                } else {
                    ok = false;
                    reply = "invalid vertex";
                }
            } else if (std.mem.eql(u8, first, "genmove")) {
                const colort = tokens.next() orelse "";
                const side: i8 = if (colort.len > 0 and (colort[0] == 'b' or colort[0] == 'B')) 1 else -1;
                stats_genmoves += 1;
                if (s.passes >= 2) {
                    reply = "pass";
                    std.debug.print("oracle: {s} -> pass  (two consecutive passes)\n", .{colort});
                    log.line("# oracle {s} -> pass  (two consecutive passes)", .{colort});
                } else {
                    const stored = s.v0(&s.pos, side);
                    const undef = stored == UNDEF; // unfilled slot (2-ko+ parallel artifact)
                    // POLITE RESIGN (CLAIMED convention, tunable; the objective
                    // eval stays pure in score.zig + the table). Resign only in
                    // the LATE game, when DECISIVELY losing - never on a bare bad
                    // fresh-start value (that assumed optimal opponent play).
                    //   (1) EARLY-GAME GATE ("always play"): don't resign before
                    //       min-stones (own >= area/4 OR total >= area/2; on 4x4:
                    //       4 own / 8 total). This is a meaningful early/late line on
                    //       4x4 (8 total is mid-game): the engine always plays the
                    //       opening and only considers resigning once the goban has
                    //       filled out.
                    //   (2) DECISIVE + SUSTAINED: our fresh-start value has been
                    //       losing by >= half the goban for the last SUSTAINED_K of
                    //       OUR turns (not a single blip), AND the opponent has a
                    //       Benson-alive (2-eye) group - they secured territory.
                    //       ("don't drag out a decisive loss".)
                    //   (3) BACKSTOP (PROVEN): OR the goban is settled (is_settled)
                    //       and the area score is against us - winning is then
                    //       impossible regardless of opponent play. area_score is
                    //       a pure goban fn, sound even on UNDEF slots.
                    const area: usize = w * h;
                    const SUSTAINED_K: u8 = S.SUSTAINED_K; // local alias (decl lives in Session)
                    const half_i8: i8 = @intCast(area / 2);
                    const min_own: usize = area / 4;
                    const min_total: usize = area / 2;
                    var own_stones: usize = 0;
                    var total_stones: usize = 0;
                    for (s.pos) |x| {
                        if (x == 0) continue;
                        total_stones += 1;
                        if ((x > 0) == (side > 0)) own_stones += 1;
                    }
                    const early = own_stones < min_own and total_stones < min_total;
                    // record this turn's value into the sustained-loss FIFO ring
                    const vals: *[SUSTAINED_K]i8 = if (side > 0) &s.vals_b else &s.vals_w;
                    const vlen: *u8 = if (side > 0) &s.vals_b_len else &s.vals_w_len;
                    if (vlen.* < SUSTAINED_K) {
                        vals[vlen.*] = stored;
                        vlen.* += 1;
                    } else {
                        var i: u8 = 0;
                        while (i + 1 < SUSTAINED_K) : (i += 1) vals[i] = vals[i + 1];
                        vals[SUSTAINED_K - 1] = stored;
                    }
                    const decisive_now = !undef and (if (side > 0) stored <= -half_i8 else stored >= half_i8);
                    var sustained = vlen.* >= SUSTAINED_K and decisive_now;
                    if (sustained) {
                        var i: u8 = 0;
                        while (i < SUSTAINED_K) : (i += 1) {
                            const vv = vals[i];
                            const d = (vv != UNDEF) and (if (side > 0) vv <= -half_i8 else vv >= half_i8);
                            if (!d) sustained = false;
                        }
                    }
                    const opp: i8 = -side;
                    const opp_alive = S.R.benson_alive(&s.pos, opp);
                    var opp_2eye = false;
                    for (opp_alive) |a| if (a) { opp_2eye = true; break; };
                    const settled = S.Score.is_definitive(&s.pos);
                    const area_now: i8 = S.R.area_score(&s.pos);
                    const behind = if (side > 0) area_now < 0 else area_now > 0;
                    // backstop only on a DECISIVE settled loss (|>= half the goban):
                    // a close settled loss (e.g. 4x4 B+2) pass-outs instead -
                    // "don't resign close games".
                    const decisive_area = if (side > 0) area_now <= -half_i8 else area_now >= half_i8;
                    const settled_backstop = settled and behind and decisive_area;
                    const resign = (!early) and ((sustained and opp_2eye) or settled_backstop);
                    if (resign) {
                        reply = "resign";
                        if (settled_backstop) {
                            std.debug.print("oracle: {s} -> resign  settled, area={d} (impossible to win)\n", .{ colort, area_now });
                            log.line("# oracle {s} -> resign  settled, area={d} (impossible to win)", .{ colort, area_now });
                        } else {
                            std.debug.print("oracle: {s} -> resign  decisively lost late (sustained {d} turns, opp 2-eye), area={d}\n", .{ colort, SUSTAINED_K, area_now });
                            log.line("# oracle {s} -> resign  decisively lost late (sustained {d} turns, opp 2-eye), area={d}", .{ colort, SUSTAINED_K, area_now });
                        }
                    } else {
                        const fl = s.flags0(&s.pos, side);
                        // H5(a): do the chainability check (A1 + A2) before
                        // trusting the V0 comparison (EXP-9). The check
                        // costs ~2n lookups when both hold; on refusal, the
                        // engine falls back to a history-free per-move score
                        // and logs UNCHAINABLE.
                        const cc = s.choose_with_check(side);
                        const c = cc.choice;
                        s.applyMove(side, c.cell) catch {};
                        reply = if (c.cell) |cell| vertex_from_cell(&vbuf, cell, w, h) else "pass";
                        const diverged = !undef and c.value != stored and !cc.refused();
                        // Log the refused-ply marker. On refusal the "value"
                        // field carries the history-free score, not V0; the
                        // suffix names that explicitly so an operator can
                        // see at a glance which plies the engine declined
                        // to certify. A1 vs A2 is named because they mean
                        // different things: A1 = this node's own stored value
                        // is already incoherent; A2 = this node is fine but
                        // the V0-optimal move would ENTER an unchainable
                        // child (the D-3 case, caught one ply early).
                        const refused_suffix: []const u8 = switch (cc.cause) {
                            .none => "",
                            .a1_node => " (UNCHAINABLE A1@node — refused V0 comparison; played history-free fallback)",
                            .a2_child => " (UNCHAINABLE A2@chosen-child — refused V0 comparison; played history-free fallback)",
                        };
                        // For artifact2: show L/H bracket alongside pinned value
                        const lh_suffix: []const u8 = if (s.a2) |_| blk: {
                            const row = s.bounds2(&s.pos, s.ko_point, @intCast(s.passes), side);
                            break :blk std.fmt.bufPrint(&sbuf, " [L={d},H={d}]", .{ row.L, row.H }) catch "";
                        } else "";
                        std.debug.print("oracle: {s} -> {s}  child-value={d} stored-v0={d}{s}{s}{s}{s}{s} dtt={d}\n", .{
                            colort,                reply,                       c.value, stored,
                            if (undef) " (UNDEF slot)" else "",
                            if (diverged) " (HISTORY-DIVERGED)" else "",
                            if (fl & 1 != 0) " KO_SENSITIVE" else "",         refused_suffix,
                            lh_suffix,
                            c.dtt,
                        });
                        log.line("# oracle {s} -> {s}  child-value={d} stored-v0={d}{s}{s}{s}{s}{s} dtt={d}", .{
                            colort,                reply,                       c.value, stored,
                            if (undef) " (UNDEF slot)" else "",
                            if (diverged) " (HISTORY-DIVERGED)" else "",
                            if (fl & 1 != 0) " KO_SENSITIVE" else "",         refused_suffix,
                            lh_suffix,
                            c.dtt,
                        });
                    }
                }
            } else if (std.mem.eql(u8, first, "undo")) {
                ok = false;
                reply = "cannot undo"; // no snapshot stack; keep the oracle simple
            } else if (std.mem.eql(u8, first, "showboard")) {
                var bb: [512]u8 = undefined;
                var bl: usize = 0;
                // start the block on its own line: the "= " response prefix
                // must not indent the first goban row
                bb[bl] = '\n';
                bl += 1;
                for (0..h) |r| {
                    for (0..w) |cx| {
                        const cell = s.pos[r * w + cx];
                        bb[bl] = if (cell > 0) 'X' else if (cell < 0) 'O' else '.';
                        bl += 1;
                        bb[bl] = ' ';
                        bl += 1;
                    }
                    bb[bl] = '\n';
                    bl += 1;
                }
                @memcpy(rbuf[0..bl], bb[0..bl]);
                reply = rbuf[0..bl];
            } else if (std.mem.eql(u8, first, "weizigo_chaincheck")) {
                // EXP-9 introspection: report the two H5(a) checks separately
                // for `<colour>` to move at the CURRENT position, without
                // playing anything. Needed to evidence acceptance criterion 4
                // (A1 holds at ply k while A2 fails, so the engine refuses at
                // ply k rather than after the collapse at ply k+1) along a
                // FIXED transcript, where `genmove` would change the line.
                //   a1=<0|1>  the node's own identity
                //   a2=<0|1|-> the chosen child's identity ('-' if choose()
                //              returns pass, which has no child to enter)
                //   move=<vertex|pass>  what choose() would play
                const ct = tokens.next() orelse "b";
                const cs: i8 = if (ct.len > 0 and (ct[0] == 'b' or ct[0] == 'B')) 1 else -1;
                const a1 = s.chainable_at(cs);
                const cch = s.choose(cs);
                var a2buf: [2]u8 = undefined;
                const a2s: []const u8 = if (cch.cell) |cell| blk: {
                    const kid = S.R.pos_from_move(&s.pos, cs, cell) catch break :blk "-";
                    const kid_ko = S.koAfterCapture(&s.pos, cs, &kid);
                    a2buf[0] = if (s.chainable_at_pos(&kid, -cs, kid_ko, 0)) '1' else '0';
                    break :blk a2buf[0..1];
                } else "-";
                const mv: []const u8 = if (cch.cell) |cell| vertex_from_cell(&vbuf, cell, w, h) else "pass";
                reply = std.fmt.bufPrint(&rbuf, "a1={d} a2={s} move={s} v0={d}", .{
                    @intFromBool(a1), a2s, mv, s.v0(&s.pos, cs),
                }) catch "chaincheck error";
            } else if (std.mem.eql(u8, first, "final_score")) {
                const raw: f32 = @floatFromInt(S.R.area_score(&s.pos));
                const sc = raw - s.komi;
                reply = if (sc > 0)
                    std.fmt.bufPrint(&rbuf, "B+{d}", .{sc}) catch unreachable
                else if (sc < 0)
                    std.fmt.bufPrint(&rbuf, "W+{d}", .{-sc}) catch unreachable
                else
                    "0";
                const report = S.Score.make_report(&s.pos);
                if (!report.definitive) {
                    std.debug.print("oracle final_score: provisional (dame {d}, contested chains {d}, dead stones counted as alive)\n", .{
                        report.dame.count, report.dead.contested,
                    });
                    log.line("# oracle final_score: provisional (dame {d}, contested chains {d}, dead stones counted as alive)", .{
                        report.dame.count, report.dead.contested,
                    });
                }
            } else if (std.mem.eql(u8, first, "weizigo_settled")) {
                reply = if (S.Score.is_definitive(&s.pos)) "yes" else "no";
            } else if (std.mem.eql(u8, first, "weizigo_estimate")) {
                const report = S.Score.make_report(&s.pos);
                const area_s = fmtAreaCounts(&sbuf, report.area, report.dame.count, S.n);
                const terr_s = fmtTerritory(sbuf[area_s.len..], report.territory);
                const dame_s = fmtDame(sbuf[area_s.len + terr_s.len ..], report.dame.count);
                const dead_s = fmtDead(sbuf[area_s.len + terr_s.len + dame_s.len ..], report.dead);
                const status = if (report.definitive) "definitive" else "provisional";
                reply = std.fmt.bufPrint(&rbuf, "{s}, {s}, {s}, {s}, {s}", .{
                    area_s, terr_s, dame_s, dead_s, status,
                }) catch unreachable;
            } else if (std.mem.eql(u8, first, "weizigo_score")) {
                const report = S.Score.make_report(&s.pos);
                const status = if (report.definitive) "definitive" else "provisional";
                var off: usize = 0;
                const area_s = fmtAreaCounts(sbuf[off..], report.area, report.dame.count, S.n);
                off += area_s.len;
                sbuf[off] = '\n';
                off += 1;
                const terr_s = fmtTerritory(sbuf[off..], report.territory);
                off += terr_s.len;
                sbuf[off] = '\n';
                off += 1;
                const dame_s = fmtDame(sbuf[off..], report.dame.count);
                off += dame_s.len;
                sbuf[off] = '\n';
                off += 1;
                const dead_s = fmtDead(sbuf[off..], report.dead);
                off += dead_s.len;
                sbuf[off] = '\n';
                off += 1;
                const dame_points = fmtVertexList(sbuf[off..], report.dame.points[0..report.dame.count], w, h);
                off += dame_points.len;
                off += (std.fmt.bufPrint(sbuf[off..], "\nDead stones: B: ", .{}) catch unreachable).len;
                const db_list = fmtVertexList(sbuf[off..], report.dead.dead_black[0..report.dead.dead_black_count], w, h);
                off += db_list.len;
                off += (std.fmt.bufPrint(sbuf[off..], "; W: ", .{}) catch unreachable).len;
                const dw_list = fmtVertexList(sbuf[off..], report.dead.dead_white[0..report.dead.dead_white_count], w, h);
                off += dw_list.len;
                off += (std.fmt.bufPrint(sbuf[off..], "\nContested chains: {d}\nStatus: {s}", .{
                    report.dead.contested, status,
                }) catch unreachable).len;
                reply = sbuf[0..off];
            } else if (std.mem.eql(u8, first, "weizigo-stats")) {
                reply = std.fmt.bufPrint(&rbuf, "lookups={d} misses={d} fallbacks={d} genmoves={d}", .{
                    stats_lookups, stats_misses, stats_fallbacks, stats_genmoves,
                }) catch "stats error";
                std.debug.print("weizigo-oracle: stats lookups={d} misses={d} fallbacks={d} genmoves={d}\n", .{
                    stats_lookups, stats_misses, stats_fallbacks, stats_genmoves,
                });
                log.line("# stats lookups={d} misses={d} fallbacks={d} genmoves={d}", .{
                    stats_lookups, stats_misses, stats_fallbacks, stats_genmoves,
                });
            } else if (std.mem.eql(u8, first, "quit")) {
                std.debug.print("weizigo-oracle: session stats lookups={d} misses={d} fallbacks={d} genmoves={d}\n", .{
                    stats_lookups, stats_misses, stats_fallbacks, stats_genmoves,
                });
                log.line("# session stats lookups={d} misses={d} fallbacks={d} genmoves={d}", .{
                    stats_lookups, stats_misses, stats_fallbacks, stats_genmoves,
                });
                quit = true;
            } else {
                ok = false;
                reply = "unknown command";
            }

            try out.appendSlice(gpa, if (ok) "=" else "?");
            try out.appendSlice(gpa, id);
            if (reply.len > 0) {
                try out.appendSlice(gpa, " ");
                // exactly one blank line terminates a GTP response — a
                // multi-line reply with its own trailing newline would
                // desynchronize clients
                try out.appendSlice(gpa, std.mem.trimEnd(u8, reply, "\n"));
            }
            try out.appendSlice(gpa, "\n\n");
            log.line("> {s}", .{std.mem.trim(u8, out.items, "\n")});
            try stdout.writeStreamingAll(io, out.items);
            out.clearRetainingCapacity();
            line.clearRetainingCapacity();
            if (quit) return;
        }
    }
}

pub fn main(init: std.process.Init) !void {
    std.debug.print("{s}\n", .{version.banner("weizigo-gtp")});
    const gpa = std.heap.page_allocator;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next(); // argv0
    const arg1 = args.next();
    const io = init.io;

    // Parse optional --enforcement <mode> flag (psk | basic-ko, default: basic-ko for WZO2, psk for WZO1)
    var enforcement: Enforcement = .psk; // default for WZO1; WZO2 path overrides
    var artifact_path: ?[]const u8 = null;
    var log_dir_opt: ?[]const u8 = null;

    // First pass: scan for flags, collect positional args
    var pos_args: [3][]const u8 = undefined;
    var n_pos: usize = 0;
    if (arg1) |a| {
        // Check if it's a flag
        if (std.mem.eql(u8, a, "--enforcement")) {
            const mode = args.next() orelse "";
            if (std.mem.eql(u8, mode, "psk")) enforcement = .psk
            else if (std.mem.eql(u8, mode, "basic-ko")) enforcement = .basic_ko
            else { std.debug.print("unknown enforcement mode '{s}'; use psk or basic-ko\n", .{mode}); return error.InvalidArgument; }
            pos_args[n_pos] = args.next() orelse ""; n_pos += 1;
            if (pos_args[0].len > 0) {
                pos_args[n_pos] = args.next() orelse ""; n_pos += 1;
            }
        } else {
            pos_args[0] = a;
            n_pos = 1;
            pos_args[1] = args.next() orelse ""; n_pos = 2;
        }
    }

    artifact_path = if (n_pos > 0 and pos_args[0].len > 0) pos_args[0] else null;
    log_dir_opt = if (n_pos > 1 and pos_args[1].len > 0) pos_args[1] else null;

    if (artifact_path) |ap| {
        // Goban-size shorthand "NxN" or "NxM" → construct artifact path
        if (parseBoardSize(ap)) |bs| {
            const path = try std.fmt.allocPrint(gpa, "artifacts/oracle-{d}x{d}.wzo", .{ bs[0], bs[1] });
            return loadAndDispatch(io, gpa, path, log_dir_opt, enforcement);
        }
        // Explicit artifact path
        return loadAndDispatch(io, gpa, ap, log_dir_opt, enforcement);
    }

    // No argument: deferred mode — wait for boardsize GTP command
    try runDeferred(io, gpa, log_dir_opt, enforcement);
}

/// GTP loop that starts without an artifact; loads it when boardsize arrives.
fn runDeferred(io: std.Io, gpa: std.mem.Allocator, opt_log_dir: ?[]const u8, enforcement: Enforcement) !void {
    const log_dir = opt_log_dir orelse "log";
    const dir = std.Io.Dir.cwd();
    const log_file: ?std.Io.File = blk: {
        dir.createDirPath(io, log_dir) catch break :blk null;
        const log_path = try std.fmt.allocPrint(gpa, "{s}/weizigo-{d}.log", .{ log_dir, unix_seconds() });
        const f = dir.createFile(io, log_path, .{}) catch break :blk null;
        std.debug.print("weizigo-oracle: transcript -> {s}\n", .{log_path});
        break :blk f;
    };
    const log = LogSink{ .io = io, .file = log_file };

    var threaded = std.Io.Threaded.init(gpa, .{});
    const tio = threaded.io();
    const stdin = std.Io.File.stdin();
    const stdout = std.Io.File.stdout();

    var in_buf: [4096]u8 = undefined;
    var line: std.ArrayList(u8) = .empty;
    defer line.deinit(gpa);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);

    std.debug.print("weizigo-oracle: deferred mode — waiting for boardsize…\n", .{});

    while (true) {
        const got = stdin.readStreaming(tio, &.{&in_buf}) catch 0;
        if (got == 0) break;
        var i: usize = 0;
        while (i < got) : (i += 1) {
            const ch = in_buf[i];
            if (ch != '\n') {
                try line.append(gpa, ch);
                continue;
            }
            log.line("< {s}", .{std.mem.trim(u8, line.items, " \t\r")});
            var tokens = std.mem.tokenizeAny(u8, line.items, " \t\r");
            var first = tokens.next() orelse continue;
            var id: []const u8 = "";
            if (first.len > 0 and std.ascii.isDigit(first[0])) {
                id = first;
                first = tokens.next() orelse continue;
            }
            out.clearRetainingCapacity();
            var quit = false;
            var ok = true;
            var reply: []const u8 = "";
            var rbuf: [512]u8 = undefined;

            if (std.mem.eql(u8, first, "protocol_version")) {
                reply = "2";
            } else if (std.mem.eql(u8, first, "name")) {
                reply = "weizigo-oracle";
            } else if (std.mem.eql(u8, first, "version")) {
                reply = "deferred";
            } else if (std.mem.eql(u8, first, "known_command")) {
                const q = tokens.next() orelse "";
                reply = "false";
                for (KNOWN_COMMANDS) |c| {
                    if (std.mem.eql(u8, c, q)) reply = "true";
                }
            } else if (std.mem.eql(u8, first, "list_commands")) {
                var lb: [256]u8 = undefined;
                var ll: usize = 0;
                for (KNOWN_COMMANDS, 0..) |c, k| {
                    if (k != 0) {
                        lb[ll] = '\n';
                        ll += 1;
                    }
                    @memcpy(lb[ll .. ll + c.len], c);
                    ll += c.len;
                }
                @memcpy(rbuf[0..ll], lb[0..ll]);
                reply = rbuf[0..ll];
            } else if (std.mem.eql(u8, first, "boardsize") or std.mem.eql(u8, first, "rectangular_boardsize")) {
                const q = tokens.next() orelse "";
                const want_w = std.fmt.parseInt(usize, q, 10) catch 0;
                const q2 = tokens.next();
                const want_h = if (q2) |s2| (std.fmt.parseInt(usize, s2, 10) catch 0) else want_w;
                if (want_w == 0 or want_h == 0) {
                    ok = false;
                    reply = "unacceptable size";
                } else {
                    // Try WZO2 first, then WZO1
                    const wzo2_path = try std.fmt.allocPrint(gpa, "artifacts/oracle-{d}x{d}-v2.wzo2", .{ want_w, want_h });
                    var loaded_v2: ?artifact2.LoadedArtifact = null;

                    // Attempt WZO2 load
                    loaded_v2 = artifact2.load(io, std.Io.Dir.cwd(), wzo2_path, gpa) catch null;

                    if (loaded_v2) |*a2| {
                        std.debug.print("weizigo-oracle: {s} ({d}x{d}, {d} groups, {d} entries) [WZO2]\n", .{
                            wzo2_path, a2.header.w, a2.header.h, a2.header.n_groups, a2.header.n_entries,
                        });
                        log.line("# weizigo-oracle session, artifact {s} ({d}x{d} WZO2), unix time {d}", .{
                            wzo2_path, a2.header.w, a2.header.h, unix_seconds(),
                        });

                        try out.appendSlice(gpa, "=");
                        try out.appendSlice(gpa, id);
                        try out.appendSlice(gpa, "\n\n");
                        log.line("> =", .{});
                        try stdout.writeStreamingAll(tio, out.items);

                        const remaining = in_buf[i + 1 .. got];
                        const key = @as(usize, a2.header.w) * 100 + a2.header.h;
                        switch (key) {
                            202 => try runSession(2, 2, gpa, null, a2, &log, remaining, enforcement),
                            302 => try runSession(3, 2, gpa, null, a2, &log, remaining, enforcement),
                            303 => try runSession(3, 3, gpa, null, a2, &log, remaining, enforcement),
                            403 => try runSession(4, 3, gpa, null, a2, &log, remaining, enforcement),
                            404 => try runSession(4, 4, gpa, null, a2, &log, remaining, enforcement),
                            else => {
                                std.debug.print("unsupported WZO2 artifact board {d}x{d}\n", .{ a2.header.w, a2.header.h });
                                return error.UnsupportedBoard;
                            },
                        }
                        return;
                    }

                    // Fall back to WZO1
                    const artifact_path = try std.fmt.allocPrint(gpa, "artifacts/oracle-{d}x{d}.wzo", .{ want_w, want_h });
                    var load_result = artifact.load(io, std.Io.Dir.cwd(), artifact_path, gpa);
                    if (load_result) |*dec| {
                        defer dec.deinit();
                        std.debug.print("weizigo-oracle: {s} ({d}x{d}, {d} legal/side) [WZO1]\n", .{
                            artifact_path, dec.header.board_w, dec.header.board_h, dec.header.legal_count,
                        });
                        log.line("# weizigo-oracle session, artifact {s} ({d}x{d}), unix time {d}", .{
                            artifact_path, dec.header.board_w, dec.header.board_h, unix_seconds(),
                        });

                        // Send success for boardsize before handing off
                        try out.appendSlice(gpa, "=");
                        try out.appendSlice(gpa, id);
                        try out.appendSlice(gpa, "\n\n");
                        log.line("> =", .{});
                        try stdout.writeStreamingAll(tio, out.items);

                        // Feed any leftover bytes from this read into runSession
                        const remaining = in_buf[i + 1 .. got];

                        const key = @as(usize, dec.header.board_w) * 100 + dec.header.board_h;
                        switch (key) {
                            202 => try runSession(2, 2, gpa, dec, null, &log, remaining, .psk),
                            302 => try runSession(3, 2, gpa, dec, null, &log, remaining, .psk),
                            303 => try runSession(3, 3, gpa, dec, null, &log, remaining, .psk),
                            403 => try runSession(4, 3, gpa, dec, null, &log, remaining, .psk),
                            404 => try runSession(4, 4, gpa, dec, null, &log, remaining, .psk),
                            603 => try runSession(6, 3, gpa, dec, null, &log, remaining, .psk),
                            505 => try runSession(5, 5, gpa, dec, null, &log, remaining, .psk),
                            else => {
                                std.debug.print("unsupported artifact board {d}x{d}\n", .{ dec.header.board_w, dec.header.board_h });
                                return error.UnsupportedBoard;
                            },
                        }
                        return; // runSession returned (quit)
                    } else |_| {
                        ok = false;
                        reply = "unacceptable size";
                    }
                }
            } else if (std.mem.eql(u8, first, "weizigo-stats")) {
                reply = std.fmt.bufPrint(&rbuf, "lookups={d} misses={d} fallbacks={d} genmoves={d}", .{
                    stats_lookups, stats_misses, stats_fallbacks, stats_genmoves,
                }) catch "stats error";
            } else if (std.mem.eql(u8, first, "quit")) {
                std.debug.print("weizigo-oracle: session stats lookups={d} misses={d} fallbacks={d} genmoves={d}\n", .{
                    stats_lookups, stats_misses, stats_fallbacks, stats_genmoves,
                });
                log.line("# session stats lookups={d} misses={d} fallbacks={d} genmoves={d}", .{
                    stats_lookups, stats_misses, stats_fallbacks, stats_genmoves,
                });
                quit = true;
            } else {
                ok = false;
                reply = "unknown command";
            }

            try out.appendSlice(gpa, if (ok) "=" else "?");
            try out.appendSlice(gpa, id);
            if (reply.len > 0) {
                try out.appendSlice(gpa, " ");
                try out.appendSlice(gpa, std.mem.trimEnd(u8, reply, "\n"));
            }
            try out.appendSlice(gpa, "\n\n");
            log.line("> {s}", .{std.mem.trim(u8, out.items, "\n")});
            try stdout.writeStreamingAll(tio, out.items);
            line.clearRetainingCapacity();
            if (quit) return;
        }
    }
}

// ---- tests ------------------------------------------------------------------

const expect = std.testing.expect;

test "vertex mapping: A1 is bottom-left, letters skip I, round-trips" {
    var buf: [8]u8 = undefined;
    // 3x3: cell 6 = bottom-left = A1; cell 0 = top-left = A3; centre = B2
    try expect(cell_from_vertex("A1", 3, 3).? == 6);
    try expect(cell_from_vertex("a3", 3, 3).? == 0);
    try expect(cell_from_vertex("B2", 3, 3).? == 4);
    try expect(std.mem.eql(u8, vertex_from_cell(&buf, 4, 3, 3), "B2"));
    for (0..9) |cell| {
        const v = vertex_from_cell(&buf, cell, 3, 3);
        try expect(cell_from_vertex(v, 3, 3).? == cell);
    }
    try expect(cell_from_vertex("J9", 9, 9) != null); // I skipped -> col 8
    try expect(cell_from_vertex("I5", 9, 9) == null);
    try expect(cell_from_vertex("D1", 3, 3) == null); // off-goban
}

test "4x4 regression: user-win B+15.5 (captures, ko replays, end-game)" {
    // Fixed transcript of a real game (User/Black beat weizigo-oracle/White,
    // komi 0.5). See regressions/4x4-history-blunder.{gtp,sgf} + README.
    // Artifact-independent: exercises rules (captures, positional superko,
    // area scoring) only - the final area score is 16 -> B+15.5 with komi 0.5.
    // Guards the capture/ko-replay and two-pass end-game scoring path.
    const R = rules.Rules(4, 4);
    const Pos = R.Pos;
    var pos: Pos = [_]i8{0} ** 16;
    var seen: [64]Pos = undefined;
    var seen_n: usize = 0;
    seen[seen_n] = pos;
    seen_n += 1; // the initial position recurs -> PSK-illegal to recreate
    const moves = [_]struct { side: i8, v: []const u8 }{
        .{ .side = 1, .v = "C3" },  .{ .side = -1, .v = "B2" },
        .{ .side = 1, .v = "C2" },  .{ .side = -1, .v = "B3" },
        .{ .side = 1, .v = "B1" },  .{ .side = -1, .v = "C4" },
        .{ .side = 1, .v = "C1" },  .{ .side = -1, .v = "B4" },
        .{ .side = 1, .v = "D4" },  .{ .side = -1, .v = "D3" },
        .{ .side = 1, .v = "D2" },  .{ .side = -1, .v = "A2" },
        .{ .side = 1, .v = "D4" },  .{ .side = -1, .v = "A1" },
        .{ .side = 1, .v = "A3" },  .{ .side = -1, .v = "A4" },
        .{ .side = 1, .v = "A3" },  .{ .side = -1, .v = "A4" },
        .{ .side = 1, .v = "B4" },  .{ .side = -1, .v = "pass" },
        .{ .side = 1, .v = "pass" },
    };
    for (moves) |m| {
        if (std.mem.eql(u8, m.v, "pass")) continue; // pass: no goban change
        const cell = cell_from_vertex(m.v, 4, 4) orelse return error.BadVertex;
        const child = try R.pos_from_move(&pos, m.side, cell);
        for (seen[0..seen_n]) |b| {
            try expect(!std.mem.eql(i8, &b, &child)); // positional superko
        }
        pos = child;
        seen[seen_n] = pos;
        seen_n += 1;
    }
    try expect(R.area_score(&pos) == 16); // B+16 -> B+15.5 at komi 0.5
}

test "H5(a) fallback_score is side-relative (antisymmetric), so both colours maximise it" {
    // EXP-9. The refusal fallback (`fallback_pick`) must MAXIMISE
    // `fallback_score` for BOTH colours, because the colour is already baked
    // into the score: it counts the mover's own Benson-alive stones/territory
    // as positive and the opponent's as negative. The first EXP-9 draft
    // branched on `maximizing = side > 0` and minimised for White, which made
    // White pick the move worst for itself on every refused ply. This test
    // pins the premise of that fix: score(pos, +1) == -score(pos, -1) for
    // every position, so there is no colour branch to make.
    const S = Session(4, 4);
    const Pos = S.R.Pos;

    // A genuinely Benson-alive Black group: the chain {1,3,4,5,6,7} enclosing
    // two single-point eyes at cells 0 and 2 (cell = r*4 + c).
    //
    //   . X . X      <- cells 0..3  : eyes at 0 and 2
    //   X X X X      <- cells 4..7  : the chain
    //   . . . .
    //   . . . .
    //
    // Both eyes are surrounded solely by that one chain, so it is alive by
    // Benson's theorem, and White has nothing anywhere.
    var pos: Pos = [_]i8{0} ** 16;
    for ([_]usize{ 1, 3, 4, 5, 6, 7 }) |p| pos[p] = 1;
    try expect(S.fallback_score(&pos, 1) == -S.fallback_score(&pos, -1));
    try expect(S.fallback_score(&pos, 1) > 0); // good for Black
    try expect(S.fallback_score(&pos, -1) < 0); // ... hence bad for White

    // Antisymmetry must hold for arbitrary positions too, not just the tidy
    // one above: sweep a deterministic pseudo-random spread of gobans.
    var seed: u32 = 12345;
    for (0..2000) |_| {
        var b: Pos = [_]i8{0} ** 16;
        for (0..16) |p| {
            seed = seed *% 1664525 +% 1013904223;
            b[p] = switch ((seed >> 16) % 3) {
                0 => 0,
                1 => 1,
                else => -1,
            };
        }
        try expect(S.fallback_score(&b, 1) == -S.fallback_score(&b, -1));
    }

    // The empty goban has no alive stones and no owned territory: 0 either way.
    const empty: Pos = [_]i8{0} ** 16;
    try expect(S.fallback_score(&empty, 1) == 0);
    try expect(S.fallback_score(&empty, -1) == 0);
}

// T263 smoke test: pipe a fixed GTP session over stdin to the weizigo-gtp
// binary and assert well-formed `=` responses for every command except quit.
test "smoke: GTP session pipe (T263)" {
    const artifact_path = "untracked/oracle-v2/oracle-4x4-v2.wzo2";

    const gpa = std.testing.allocator;

    // GTP session: protocol_version, boardsize 4, clear_board, showboard,
    // genmove b, final_score, quit
    const commands = "protocol_version\nboardsize 4\nclear_board\nshowboard\ngenmove b\nfinal_score\nquit\n";

    var child = std.process.spawn(std.testing.io, .{
        .argv = &.{ "bin/weizigo-gtp", artifact_path },
        .stdin = .pipe,
        .stdout = .pipe,
        .stderr = .ignore,
    }) catch |err| {
        std.debug.print("SKIP: cannot spawn bin/weizigo-gtp — run 'zig build deploy-gtp' first: {}\n", .{err});
        return error.SkipZigTest;
    };
    defer child.kill(std.testing.io);

    const io = std.testing.io;

    // Write commands and close stdin so the child gets EOF.
    try child.stdin.?.writeStreamingAll(io, commands);
    child.stdin = null;

    // Read all stdout into a buffer.
    var stdout_buf: std.ArrayList(u8) = .empty;
    defer stdout_buf.deinit(gpa);
    var read_buf: [1024]u8 = undefined;
    while (true) {
        const n = child.stdout.?.readStreaming(io, &[_][]u8{read_buf[0..]}) catch break;
        if (n == 0) break;
        try stdout_buf.appendSlice(gpa, read_buf[0..n]);
    }

    const output = stdout_buf.items;

    // Parse response blocks: split on "\n\n"
    var responses = std.mem.splitSequence(u8, output, "\n\n");
    var cmd_idx: usize = 0;
    const expected_cmds = [_][]const u8{
        "protocol_version", "boardsize 4", "clear_board", "showboard",
        "genmove b", "final_score", "quit",
    };
    while (responses.next()) |block| {
        const trimmed = std.mem.trim(u8, block, " \t\r\n");
        if (trimmed.len == 0) continue;
        if (cmd_idx >= expected_cmds.len) break;
        // Every response to a GTP command must start with '=' (success)
        // or '?' (error). We expect all = here.
        if (trimmed.len > 0 and trimmed[0] != '=') {
            std.debug.print("FAIL cmd '{s}': response starts with '{c}' not '=', block: '{s}'\n", .{ expected_cmds[cmd_idx], trimmed[0], trimmed });
            return error.BadGtpResponse;
        }
        cmd_idx += 1;
    }

    // We should have matched all commands
    try expect(cmd_idx >= expected_cmds.len - 1); // quit may not produce a response
}
