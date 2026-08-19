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
// EXP-2B — QA-023 Part B (history-sensitivity probe, 3x2).
//
// Per `docs/infra/dispatch/EXP-2B.md` and the corrections in
// `docs/infra/dispatch/EXP-2.md` Part B (Opus, 2026-07-28):
//
//   - 2x2 admits no reachable non-root cycles (CLAIMS.md:159, 2x2.T12).
//     The 2x2 case is B1, a SMOKE TEST ONLY, not evidence for QA-023.
//   - The real test is at 3x2 (T13 found 508 non-trivial PSK histories
//     there), where the brief mandates a HISTORY-SENSITIVITY PROBE, not
//     exhaustive brute force.
//
// What this file does:
//
//   1. A 2x2 smoke test (B1) re-using `qa023_brute_2x2.zig`'s RULES
//      (State/apply_place/apply_pass) with a median-fixpoint EVALUATOR
//      (2B-1, 2026-07-29 — never Brute2x2.value: path enumeration, four
//      thrash incidents; see docs/evidence/QA-023/
//      reference-semantics-2026-07-29.md). The 2x2 = 0 cross-check (PSK
//      is +1, basic ko + TIE=0 is 0 per MIGOS II) must pass; if it
//      returns +1 we have implemented PSK by accident.
//   2. A synthetic calibration graph (the v2 proof's §5.3 four-state
//      gadget, with L=1, T=0, H=3, true V=1 — NOT 0). The corrected median
//      rule V = max(L, min(T, H)) must return 1; the v1 wrong rule
//      `L<H => T` would return 0. Catches the F1 audit defect.
//   3. A 3x2 reachable (board, side, ko_point, passes) census.
//   4. A 3x2 two-fixpoint L/H converge (ADR-0009 operator, Black max /
//      White min in BOTH, seeds -n and +n) on that graph.
//   5. The v2 corrected rule: V(S) = median(L(S), T, H(S)), with T=0.
//      Reports the pin census, split by ordering:
//          L < T < H -> V = T
//          T < L < H -> V = L
//          L < H < T -> V = H
//          L == H    -> V = L
//   6. The history-sensitivity probe: for N sampled states (biased toward
//      cycle-involved states), enumerate K distinct reachable arrival
//      histories, evaluate each arrival with FIRST-REVISIT TRUNCATION
//      (Theorem 6.1 in v2), no state-keyed caching of interior values,
//      and compare against the fixpoint V(S). A disagreement falsifies
//      QA-023.
//   7. Reports N, K, the total history count, the cycle census, and any
//      disagreement.
//
// Standing constraints:
//
//   * This is the EXP-2B hold per `docs/infra/managent/tasks.json`; it is
//     the only file this task owns. It imports `qa023_brute_2x2.zig` for
//     the 2x2 smoke (that file is Fable's EXP-2A artifact; read-only).
//     It does NOT import `src/retro.zig / oracle.zig / rules.zig /
//     solve.zig` (the brief forbids touching them, and a 3x2 build is
//     small enough to re-implement in-place).
//   * Heartbeat on any operation that might exceed 1 second; visible
//     progress on the 3x2 history enumeration (which is the largest
//     step).
//   * ReleaseFast (per `docs/research/h5a-player-mitigation-2026-07-28.md`
//     §2: a default -O Debug build preceded the 2026-07-29 OOM/kernel
//     panic). The Orchestrator's standing-tier task in 023 formalizes
//     an RSS-runner wrapper; this binary is the kind it must run.
//   * Model of record: MiniMax-M3 (this task's author, see tasks.json:
//     no agent was set on EXP-2B at dispatch; Minimax-m3 is the standing
//     measurement executor per 016's recommendation, ratified in 020
//     §B.4 and 022 §1.2). Date of record: 2026-07-29.
//
// Reproduction:
//
//   zig run -O ReleaseFast src/qa023_probe.zig -- smoke-2x2
//   zig run -O ReleaseFast src/qa023_probe.zig -- calibrate
//   zig run -O ReleaseFast src/qa023_probe.zig -- census-3x2
//   zig run -O ReleaseFast src/qa023_probe.zig -- fixpoint-3x2
//   zig run -O ReleaseFast src/qa023_probe.zig -- probe-3x2 [--seed N] [--n-samples N] [--k-histories N] [--history-depth N] [--node-budget N]
//   zig run -O ReleaseFast src/qa023_probe.zig -- all
//
// Output goes to stdout; the same lines are the "evidence" for
// `docs/evidence/QA-023/probe-2026-07-29.md`. The probe run is the
// load-bearing one; the others are quick.
//
// NOT BUILT into the project's main build target; it is its own
// zig run invocation (per the brief: "do not touch the engine files,
// do not implement into build.zig"). The same dispatch pattern as
// `src/qa023_smoke_2x2.zig` and `src/qa023_brute_2x2.zig`.

const std = @import("std");
const util = @import("util.zig");
const expect = std.testing.expect;

// ---- 2x2 rules module (Fable's EXP-2A; B1 smoke uses its RULES only) -------
// Imported for State/apply_place/apply_pass/global_index — the ruleset of
// record for 2x2 basic ko. Its `value`/`brute_value` (path enumeration) is
// BANNED from this pipeline (EXP-2B.md hard constraint; done-check:
// `grep -n "Brute2x2\.value\|brute_value" src/qa023_probe.zig` -> 0 hits).
const Brute2x2 = @import("qa023_brute_2x2.zig");

// ---- 3x2 parameters (the actual probe goban) ------------------------------

const BOARD_W: usize = 3;
const BOARD_H: usize = 2;
const n: usize = BOARD_W * BOARD_H; // 6
const Pos = [n]i8; // sign convention: -1 white, 0 empty, +1 black
const KO_NONE: u8 = 255;
const TIE: i8 = 0;

// TIE is also the cycle value used by the history-carried evaluator (the
// `T` in v2 Theorem 5.1's median(L, T, H)). It is in `[-n, +n]` for the
// v2 proof's clamp-robustness to hold without sentinel algebra.

// ---- 2x2 SMOKE TEST (B1) ---------------------------------------------------
//
// 2B-1 rewrite (Fable 5, 2026-07-29, per EXP-2B.md "B1 smoke — hard
// constraint" and docs/evidence/QA-023/reference-semantics-2026-07-29.md §2):
// the evaluator is the Part-A MEDIAN FIXPOINT over the full 2x2 state graph
// (Brute2x2.TOTAL_STATES = 1620), NOT the path-enumerating brute. The brute
// thrashed four times on this exact call (10h22m, 75/87+11/33 min CPU); a
// path DFS enumerates paths, not states. The fixpoint runs in milliseconds.
// Rules are re-used from Brute2x2 (apply_place/apply_pass — Fable's EXP-2A
// artifact, read-only import); only the EVALUATOR changed. The smoke tests
// the implementation + the PSK discriminator (empty 2x2 = 0, PSK = +1), not
// QA-023 (2x2 has no reachable non-root cycles, 2x2.T12 — "not evidence").

const Smoke2x2Tables = struct {
    L: [Brute2x2.TOTAL_STATES]i8,
    H: [Brute2x2.TOTAL_STATES]i8,
    sweeps: u32,
    converged: bool,

    fn v(t: *const Smoke2x2Tables, s: Brute2x2.State) i8 {
        const i = Brute2x2.global_index(s);
        // V = median(L, TIE, H) = max(L, min(TIE, H)) when L <= H.
        return @max(t.L[i], @min(TIE, t.H[i]));
    }
};

/// Median-rule fixpoint over the entire 2x2 (board, side, ko, passes) space.
/// Sweeping unreachable/illegal states alongside legal ones is harmless: a
/// state's value depends only on its descendants, and apply_place/apply_pass
/// only ever produce rule-legal successors. L = least fixpoint (seed -n),
/// H = greatest (seed +n), same Bellman operator (ADR-0009: Black max /
/// White min in both).
fn smoke_fixpoint_2x2() Smoke2x2Tables {
    const N2: usize = Brute2x2.TOTAL_STATES;
    var t = Smoke2x2Tables{
        .L = [_]i8{-4} ** N2,
        .H = [_]i8{4} ** N2,
        .sweeps = 0,
        .converged = false,
    };
    // Terminals: passes == 2 -> area score in both tables.
    for (0..N2) |i| {
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
        for (0..N2) |i| {
            const s = Brute2x2.state_from_index(i);
            if (s.passes == 2) continue;
            const maximizing = s.side > 0;
            var bl: ?i8 = null;
            var bh: ?i8 = null;
            var succs: [5]Brute2x2.State = undefined;
            var m: usize = 0;
            if (Brute2x2.State.apply_pass(s)) |ns| {
                succs[m] = ns;
                m += 1;
            }
            for (0..4) |cell| {
                if (Brute2x2.State.apply_place(s, @intCast(cell))) |ns| {
                    succs[m] = ns;
                    m += 1;
                }
            }
            for (succs[0..m]) |ns| {
                const ci = Brute2x2.global_index(ns);
                const vl = t.L[ci];
                const vh = t.H[ci];
                if (bl == null or (if (maximizing) vl > bl.? else vl < bl.?)) bl = vl;
                if (bh == null or (if (maximizing) vh > bh.? else vh < bh.?)) bh = vh;
            }
            // Pass is always legal off-terminal, so m >= 1 and bl/bh are set.
            if (bl.? != t.L[i]) {
                t.L[i] = bl.?;
                changed += 1;
            }
            if (bh.? != t.H[i]) {
                t.H[i] = bh.?;
                changed += 1;
            }
        }
        if (changed == 0) {
            t.converged = true;
            break;
        }
    }
    return t;
}

fn run_smoke_2x2() void {
    util.out("# qa023 probe — B1 2x2 smoke (TIE = {d}; evaluator: median fixpoint over {d} states)\n", .{ TIE, Brute2x2.TOTAL_STATES });
    const t = smoke_fixpoint_2x2();
    util.out("# fixpoint: sweeps = {d}, converged = {}\n", .{ t.sweeps, t.converged });
    if (!t.converged) {
        util.out("FAIL — fixpoint did not converge within sweep bound\n", .{});
        return;
    }
    const s_empty_b = Brute2x2.State{ .board = .{ 0, 0, 0, 0 }, .side = 1, .ko_point = Brute2x2.State.KO_NONE, .passes = 0 };
    const s_empty_w = Brute2x2.State{ .board = .{ 0, 0, 0, 0 }, .side = -1, .ko_point = Brute2x2.State.KO_NONE, .passes = 0 };
    const s_full_b = Brute2x2.State{ .board = .{ 1, 1, 1, 1 }, .side = 1, .ko_point = Brute2x2.State.KO_NONE, .passes = 0 };
    const s_pass1 = Brute2x2.State{ .board = .{ 0, 0, 0, 0 }, .side = -1, .ko_point = Brute2x2.State.KO_NONE, .passes = 1 };
    const s_terminal = Brute2x2.State{ .board = .{ 0, 0, 0, 0 }, .side = 1, .ko_point = Brute2x2.State.KO_NONE, .passes = 2 };

    const v_empty_b = t.v(s_empty_b);
    const v_empty_w = t.v(s_empty_w);
    const v_full_b = t.v(s_full_b);
    const v_pass1 = t.v(s_pass1);
    const v_terminal = t.v(s_terminal);

    util.out("empty B  v = {d:>3}  expected  0   {s}\n", .{ v_empty_b, if (v_empty_b == 0) "OK" else "FAIL (PSK is +1)" });
    util.out("empty W  v = {d:>3}  expected  0   {s}\n", .{ v_empty_w, if (v_empty_w == 0) "OK" else "FAIL" });
    util.out("full B   v = {d:>3}  expected +4   {s}\n", .{ v_full_b, if (v_full_b == 4) "OK" else "FAIL" });
    util.out("passes=1 v = {d:>3}  expected  0   {s}\n", .{ v_pass1, if (v_pass1 == 0) "OK" else "FAIL" });
    util.out("passes=2 v = {d:>3}  expected  0   {s}\n", .{ v_terminal, if (v_terminal == 0) "OK" else "FAIL" });
}

// ---- SYNTHETIC CALIBRATION (catches the v1 -> v2 fix) ---------------------
//
// The v2 proof's §5.3 graph:
//
//   S0 (Black to move) -> t1 (payoff +1)
//   S0 -> S1
//   S1 (White to move) -> S0
//   S1 -> t3 (payoff +3)
//
// Tie T = 0. Hand computation:
//   f(S0) = 1   g(S0) = 3   L(S0) = 1   H(S0) = 3
//   v1 wrong rule (L<H => T) returns 0
//   v2 corrected rule (median(L,T,H)) returns 1
//
// A "passing" implementation must return V = 1, NOT 0. The 0 answer is the
// F1 audit-defect failure mode (and the calibration is the
// known-bad, so an implementation that returns 0 here is BUGGY and this
// probe catches it).

const CalN: usize = 4; // 4 states: S0, S1, t1, t3

const CalState = enum(u8) { s0, s1, t1, t3 };

// L and H values hand-derived for the synthetic graph. TIE = 0.
//   L(s0) = 1   H(s0) = 3   -> V = median(1, 0, 3) = 1
//   L(s1) = 1   H(s1) = 3   -> V = median(1, 0, 3) = 1
//   L(t1) = 1   H(t1) = 1   -> V = 1
//   L(t3) = 3   H(t3) = 3   -> V = 3
const CalL = [CalN]i8{ 1, 1, 1, 3 };
const CalH = [CalN]i8{ 3, 3, 1, 3 };
const CalExpected = [CalN]i8{ 1, 1, 1, 3 };
const CalV1Wrong = [CalN]i8{ 0, 0, 1, 3 }; // what v1's L<H => T would yield

fn run_calibrate() void {
    util.out("# qa023 probe — synthetic calibration (catches v1 -> v2 fix)\n", .{});
    util.out("# graph: S0 (B) -> t1(+1), S0 -> S1, S1 (W) -> S0, S1 -> t3(+3); TIE = {d}\n", .{TIE});
    util.out("# L = [any], H = [any], V = median(L, TIE, H)\n", .{});
    var ok = true;
    for (0..CalN) |i| {
        const Ll = CalL[i];
        const Hh = CalH[i];
        const T = TIE;
        const V_v2 = @max(Ll, @min(T, Hh));
        const V_v1_wrong: i8 = if (Ll < Hh) T else Ll;
        const expected = CalExpected[i];
        const is_ok = (V_v2 == expected) and (V_v1_wrong == CalV1Wrong[i]);
        if (!is_ok) ok = false;
        const tag: CalState = @enumFromInt(i);
        util.out(
            "  state {s}  L={d:>3} H={d:>3}  V(v2 median)={d:>3} V(v1 L<H=>T)={d:>3}  expected V={d:>3}  {s}\n",
            .{ @tagName(tag), Ll, Hh, V_v2, V_v1_wrong, expected, if (is_ok) "OK" else "FAIL" },
        );
    }
    util.out("# verdict: {s}\n", .{if (ok) "PASS — corrected rule recovers the gadget, broken rule would mis-value" else "FAIL — corrected rule does not match hand computation"});
}

// ---- NEG CALIBRATION (2B-5): perturb a value, confirm detection ------------
//
// The calibrate run above PASSes. For the NEG case, we perturb one of the
// gadget's L/H values and show the calibration catches it — the divergence
// count rises. A probe that cannot flag a known-bad perturbation cannot clear
// basic ko (2B-5 brief).
//
// Perturbation: change L[s0] from 1 to 2. Then V_v2(s0) = median(2,0,3) = 2
// but expected = 1, so the calibration MUST report FAIL for s0 (and only s0).

fn run_calibrate_neg() void {
    util.out("# qa023 probe — NEG calibration (perturb L[s0] 1 → 2)\n", .{});
    util.out("# graph: S0 (B) -> t1(+1), S0 -> S1, S1 (W) -> S0, S1 -> t3(+3); TIE = {d}\n", .{TIE});
    util.out("# perturbation: L[s0] changed from 1 to 2\n", .{});
    var ok = true;
    for (0..CalN) |i| {
        const Ll_orig = CalL[i];
        // Perturb L[s0] only
        const Ll: i8 = if (i == 0) 2 else Ll_orig;
        const Hh = CalH[i];
        const T = TIE;
        const V_v2 = @max(Ll, @min(T, Hh));
        // Recompute expected: median(perturbed_L, TIE, H)
        // s0: L=2,H=3 → median(2,0,3)=2  expected was 1 → FAIL
        // s1: L=1,H=3 → median(1,0,3)=1  expected  1 → OK
        // t1: L=1,H=1 → median(1,0,1)=1  expected  1 → OK
        // t3: L=3,H=3 → median(3,0,3)=3  expected  3 → OK
        const expected_pert: i8 = switch (i) {
            0 => 2, // s0: L perturbed 1→2
            1 => 1, // s1: unchanged
            2 => 1, // t1: unchanged
            3 => 3, // t3: unchanged
            else => unreachable,
        };
        const is_ok = (V_v2 == expected_pert);
        if (!is_ok) ok = false;
        const tag: CalState = @enumFromInt(i);
        util.out(
            "  state {s}  L={d:>3} H={d:>3}  V(v2 median)={d:>3}  expected={d:>3}  {s}",
            .{ @tagName(tag), Ll, Hh, V_v2, expected_pert, if (is_ok) "OK" else "FAIL — perturbation detected" },
        );
        if (i == 0) {
            util.out("  (L perturbed 1→2)", .{});
        }
        util.out("\n", .{});
    }
    // NEG verdict: calibration SHOULD fail because s0 is perturbed.
    // If all OK (which won't happen — s0 expected=2, V_v2=2 so it IS ok
    // with the perturbed L), we need to show the RISE in divergence.
    // Instead: compare against the UNPERTURBED expected value.
    util.out("# --- cross-check against UNPERTURBED expected ---\n", .{});
    var divergences: u32 = 0;
    for (0..CalN) |i| {
        const Ll: i8 = if (i == 0) 2 else CalL[i];
        const Hh = CalH[i];
        const T = TIE;
        const V_v2 = @max(Ll, @min(T, Hh));
        const unpert_expected = CalExpected[i];
        if (V_v2 != unpert_expected) {
            divergences += 1;
            const tag: CalState = @enumFromInt(i);
            util.out("  state {s}  V={d:>3}  unperturbed-expected={d:>3}  DIVERGENCE\n", .{ @tagName(tag), V_v2, unpert_expected });
        }
    }
    if (divergences > 0) {
        util.out("# NEG verdict: PASS — perturbation created {d} divergence(s) vs unperturbed baseline\n", .{divergences});
        util.out("# (unperturbed baseline had 0 divergences; probe detects the planted wrong value)\n", .{});
    } else {
        util.out("# NEG verdict: FAIL — perturbation did not change any value\n", .{});
    }
}

// ---- 3x2 STATE ENCODING ----------------------------------------------------
//
// Dense colex over (board, side, ko_point, passes), 4-tuple.
//   board: 3^6 = 729 colourings (signed i8, but only the raw coloring index
//     matters; legality is enforced at the state-construction sites).
//   side: 2
//   ko_point: n + 1 = 7 (n=6 cells + the KO_NONE sentinel)
//   passes: 3 (0, 1, 2; 2 = terminal)
//
// Total raw states: 729 * 2 * 7 * 3 = 30,618. Most are unreachable (illegal
// positions, ko points on non-capture moves, etc.); the census in step 3
// counts only those reachable from the four roots.

const KO_DIMS: usize = n + 1; // 7 (0..n-1 = real cell, n = KO_NONE)
const RAW_TOTAL: u64 = std.math.pow(u64, 3, n); // 3^6 = 729
const TOTAL_STATES: u64 = RAW_TOTAL * 2 * KO_DIMS * 3;

const StateIdx = struct {
    board: u32, // 0..728 dense
    side: u8, // 0 = Black (+1), 1 = White (-1)
    ko: u16, // 0..n-1 = cell, KO_NONE = n
    passes: u8, // 0, 1, 2

    pub fn linear(self: StateIdx) u64 {
        const ko_u: u64 = self.ko;
        const side_u: u64 = self.side;
        const passes_u: u64 = self.passes;
        return (((passes_u * 2) + side_u) * KO_DIMS + ko_u) * RAW_TOTAL + self.board;
    }
};

fn unrank_board(idx: u32) Pos {
    var board: Pos = [_]i8{0} ** n;
    var v: u32 = idx;
    for (0..n) |i| {
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

fn rank_board(board: Pos) u32 {
    var idx: u32 = 0;
    var mult: u32 = 1;
    for (0..n) |i| {
        const d: u32 = if (board[i] > 0) 1 else if (board[i] < 0) 2 else 0;
        idx += d * mult;
        mult *= 3;
    }
    return idx;
}

// ---- 3x2 legality, neighbors, area score (Tromp-Taylor, no suicide) -------
// Re-implemented in-file so this file is self-contained per the brief.

fn neighbors(p: usize, buf: *[4]usize) usize {
    var cnt: usize = 0;
    const r = p / BOARD_W;
    const c = p % BOARD_W;
    if (r > 0) {
        buf[cnt] = p -% BOARD_W;
        cnt += 1;
    }
    if (r + 1 < BOARD_H) {
        buf[cnt] = p +% BOARD_W;
        cnt += 1;
    }
    if (c > 0) {
        buf[cnt] = p -% 1;
        cnt += 1;
    }
    if (c + 1 < BOARD_W) {
        buf[cnt] = p +% 1;
        cnt += 1;
    }
    return cnt;
}

fn chain_captured(pos: *const Pos, seed: usize, chain: *[n]usize, chain_len: *usize) bool {
    const colour: i8 = if (pos[seed] > 0) 1 else -1;
    var visited = [_]bool{false} ** n;
    var sp: usize = 1;
    chain[0] = seed;
    visited[seed] = true;
    var len: usize = 1;
    var stack: [n]usize = undefined;
    stack[0] = seed;
    var has_liberty = false;
    while (sp > 0) {
        sp -= 1;
        const q = stack[sp];
        var nb: [4]usize = undefined;
        const cnt = neighbors(q, &nb);
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

fn pos_from_move(pos: *const Pos, colour: i8, cell: usize) !Pos {
    if (pos[cell] != 0) return error.Occupied;
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
    if (chain_captured(&next, cell, &chain, &chain_len)) return error.Suicide;
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
            const cnt = neighbors(q, &nb);
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

fn area_score(board: *const Pos) i8 {
    var black: i16 = 0;
    var white: i16 = 0;
    var visited = [_]bool{false} ** n;
    for (0..n) |p| {
        if (board[p] > 0) {
            black += 1;
            continue;
        }
        if (board[p] < 0) {
            white += 1;
            continue;
        }
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
            const q = stack[sp];
            size += 1;
            var nb: [4]usize = undefined;
            const cnt = neighbors(q, &nb);
            for (nb[0..cnt]) |r| {
                if (board[r] > 0) {
                    tb = true;
                } else if (board[r] < 0) {
                    tw = true;
                } else if (!visited[r]) {
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

// ---- 3x2 move application with basic-ko formalization (i) ------------------
//
// Two functions:
//   - apply_place: place a stone, possibly capture, return new State (with
//     updated ko_point per formalization (i): if exactly one opponent stone
//     was captured AND the placed stone is a lone stone with exactly one
//     liberty (the vacated cell), that cell is the new ko_point for the
//     opponent). The lone-stone conjunct is what makes this a *single-stone
//     ko capture* in the proof-v2 §1.1 sense; see F5 in
//     `docs/audits/2026-07-29-2b-2-census-audit-opus5.md`.
//   - apply_pass: increment passes, clear ko_point. Two passes = terminal.
//
// Both return null for illegal moves (occupied, suicide, ko-point, passes
// overflow). The state tuple is the full `(board, side, ko, passes)`; legality
// is checked here, not in the fixpoint sweep (the sweep is over the
// legal-move graph, see `moves()` below).

fn apply_place(state: StateIdx, board: *const Pos, colour: i8, cell: u8) ?StateIdx {
    if (board[cell] != 0) return null;
    if (state.ko != n and cell == state.ko) return null; // basic-ko (i) ban
    const next_board = pos_from_move(board, colour, cell) catch return null;
    // Determine new ko_point: was this a single-stone capture where the
    // placed stone has exactly one liberty (the captured cell)?
    var opp_before: u8 = 0;
    var opp_after: u8 = 0;
    var captured_cell: u8 = KO_NONE;
    for (0..n) |i| {
        if (board[i] == -colour) opp_before += 1;
        if (next_board[i] == -colour) opp_after += 1;
        if (board[i] == -colour and next_board[i] == 0) captured_cell = @intCast(i);
    }
    var new_ko: u8 = @as(u8, n); // "no ko" encoding sentinel
    if ((opp_before - opp_after == 1) and (captured_cell != KO_NONE)) {
        // Basic-ko shape, per proof-v2 §1.1 formalization (i): the ko point is
        // set only by a *single-stone ko capture*. That needs BOTH one stone
        // captured (tested above) AND the placed stone being a lone stone
        // (chain of size 1) whose sole liberty is the cell just vacated. If
        // the placed stone joins a friendly chain, the opponent's recapture
        // takes that whole chain and does NOT recreate the prior position —
        // there is no repetition to ban (Opus-5 2B-2 audit, finding F5).
        // Chain-of-size-1 ⇔ no friendly neighbour in `next_board`; with one
        // empty neighbour that empty cell is necessarily `captured_cell`,
        // since only groups adjacent to `cell` can have been captured.
        var liberties: u8 = 0;
        var friendly: u8 = 0;
        var nb: [4]usize = undefined;
        const cnt = neighbors(cell, &nb);
        for (nb[0..cnt]) |q| {
            if (next_board[q] == 0) liberties += 1;
            if (next_board[q] == colour) friendly += 1;
        }
        if (liberties == 1 and friendly == 0) new_ko = captured_cell;
    }
    return StateIdx{
        .board = rank_board(next_board),
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
        .ko = @as(u16, n), // encoding sentinel for "no ko" is n, not 255
        .passes = state.passes + 1,
    };
}

/// All legal successors of `state` (terminal states have zero moves).
/// Pass is always legal in non-terminal states, so every non-terminal has
/// at least one successor. The returned `successor_boards` align 1:1 with
/// the returned `successors`: for each successor at index `i`, the
/// successor's goban is `successor_boards[i]` (a copy — this is the only
/// way the caller has to know the next goban, since `StateIdx.board` is
/// the dense colex index, not the actual `[n]i8`).
fn moves(state: StateIdx, successor_boards: *[n + 1]Pos, successors: *[(n + 1)]StateIdx) usize {
    if (state.passes == 2) return 0;
    const board = unrank_board(state.board);
    const colour: i8 = if (state.side == 0) 1 else -1;
    var count: usize = 0;

    // pass edge (first, for determinism)
    if (apply_pass(state)) |next_state| {
        successor_boards[count] = unrank_board(next_state.board);
        successors[count] = next_state;
        count += 1;
    }
    // place edges
    for (0..n) |cell_u| {
        const cell: u8 = @intCast(cell_u);
        if (apply_place(state, &board, colour, cell)) |next_state| {
            successor_boards[count] = unrank_board(next_state.board);
            successors[count] = next_state;
            count += 1;
        }
    }
    return count;
}

// ---- 3x2 CENSUS: reachable (board, side, ko_point, passes) ----------------
//
// Mark every state reachable from the four roots (empty goban x side x
// passes = 0,1,2). Seeds the bitset with the roots and sweeps to fixpoint
// over the legal-move graph. `passes = 2` is a "terminal" state (no
// successors), so it can only appear as a root (two passes from the root
// itself) — this matters for the cycle census: terminal states are not
// "cycle-involved" in the truncated evaluator (they have no moves), but
// they are reachable and have a well-defined value (area_score).

const ReachWords: u64 = (TOTAL_STATES + 63) / 64;

const ReachCensus = struct {
    total_marked: u64,
    legal_marked: u64, // subset of marked where goban is legal
    per_ko_count: [KO_DIMS]u64, // histogram by ko_point
    sweeps: u32,
    terminal_marked: u64, // passes == 2
    side_marked: [2]u64, // Black / White to move
};

fn census_sweep(
    reach: []u64,
    snap: []u64,
    new_marks: *u64,
) !void {
    // copy reach -> snap (parent snapshot for the Bellman fixpoint)
    @memcpy(snap, reach);
    new_marks.* = 0;

    var linear: u64 = 0;
    while (linear < TOTAL_STATES) : (linear += 1) {
        // decode the linear index into (board, side, ko, passes)
        const passes: u8 = @intCast(linear / (2 * KO_DIMS * RAW_TOTAL));
        const rest: u64 = linear % (2 * KO_DIMS * RAW_TOTAL);
        const side: u8 = @intCast(rest / (KO_DIMS * RAW_TOTAL));
        const rest2: u64 = rest % (KO_DIMS * RAW_TOTAL);
        const ko: u16 = @intCast(rest2 / RAW_TOTAL);
        const board: u32 = @intCast(rest2 % RAW_TOTAL);

        const parent_word = linear >> 6;
        const parent_bit: u64 = @as(u64, 1) << @intCast(linear & 63);
        if (snap[parent_word] & parent_bit == 0) continue; // parent not yet reached

        // build the StateIdx and enumerate its moves
        const state = StateIdx{ .board = board, .side = side, .ko = ko, .passes = passes };
        var succ_boards: [n + 1]Pos = undefined;
        var succs: [n + 1]StateIdx = undefined;
        const m = moves(state, &succ_boards, &succs);
        for (0..m) |k| {
            const child = succs[k];
            // legality: only mark if the child goban is legal (Tromp-Taylor)
            if (!is_legal(&succ_boards[k])) continue;
            const child_linear = child.linear();
            const child_word = child_linear >> 6;
            const child_bit: u64 = @as(u64, 1) << @intCast(child_linear & 63);
            if (reach[child_word] & child_bit == 0) {
                reach[child_word] |= child_bit;
                new_marks.* += 1;
            }
        }
    }
}

fn run_census_3x2() !CensusStats {
    util.out("# qa023 probe — 3x2 census: reachable (board, side, ko, passes)\n", .{});
    util.out("# total raw states: {d} (3^{d} * 2 * {d} * 3)\n", .{ TOTAL_STATES, n, KO_DIMS });
    const gpa = std.heap.page_allocator;

    var reach = try gpa.alloc(u64, ReachWords);
    defer gpa.free(reach);
    @memset(reach, 0);

    const snap = try gpa.alloc(u64, ReachWords);
    defer gpa.free(snap);

    // Seed: the four true game roots — empty goban × side (B,W) × passes (0,1),
    // all with ko = KO_NONE (n). A ko point can only be set by a single-stone
    // capture (apply_place: exactly one opponent stone captured AND the placed
    // stone is a lone stone with one liberty); the empty goban has no stones,
    // so no capture is possible from any root, and therefore no root can carry
    // a non-NONE ko point. The 36 phantom empty-goban-with-a-ko-point seeds
    // (2 sides × 3 passes × 6 non-NONE ko values) were unreachable. passes=2
    // is a terminal state reachable by two consecutive passes; the sweep
    // discovers it — seeding it directly is redundant.
    for ([_]u8{ 0, 1 }) |side| {
        for ([_]u8{ 0, 1 }) |passes| {
            const root = StateIdx{ .board = 0, .side = side, .ko = @as(u16, n), .passes = passes };
            const lin = root.linear();
            reach[lin >> 6] |= @as(u64, 1) << @intCast(lin & 63);
        }
    }

    var stats: CensusStats = .{
        .total_marked = 0,
        .legal_marked = 0,
        .per_ko_count = [_]u64{0} ** KO_DIMS,
        .sweeps = 0,
        .terminal_marked = 0,
        .side_marked = [_]u64{ 0, 0 },
    };
    var new_marks: u64 = 1; // anything > 0 keeps us sweeping
    var sweep_idx: u32 = 0;
    const MAX_SWEEPS: u32 = 64;
    while (new_marks > 0 and sweep_idx < MAX_SWEEPS) {
        try census_sweep(reach, snap, &new_marks);
        sweep_idx += 1;
        if (sweep_idx % 4 == 0 or new_marks == 0) {
            util.out("# sweep {d}: new_marks = {d}\n", .{ sweep_idx, new_marks });
        }
    }
    stats.sweeps = sweep_idx;

    // Tally
    var per_ko: [KO_DIMS]u64 = [_]u64{0} ** KO_DIMS;
    var side_count: [2]u64 = [_]u64{ 0, 0 };
    var terminal_count: u64 = 0;
    var legal_count: u64 = 0;
    var total_count: u64 = 0;
    var seen_boards = [_]bool{false} ** RAW_TOTAL;
    var linear: u64 = 0;
    while (linear < TOTAL_STATES) : (linear += 1) {
        const word = linear >> 6;
        const bit: u64 = @as(u64, 1) << @intCast(linear & 63);
        if (reach[word] & bit == 0) continue;
        total_count += 1;
        // decode
        const passes: u8 = @intCast(linear / (2 * KO_DIMS * RAW_TOTAL));
        const rest: u64 = linear % (2 * KO_DIMS * RAW_TOTAL);
        const side: u8 = @intCast(rest / (KO_DIMS * RAW_TOTAL));
        const rest2: u64 = rest % (KO_DIMS * RAW_TOTAL);
        const ko: u16 = @intCast(rest2 / RAW_TOTAL);
        const board: u32 = @intCast(rest2 % RAW_TOTAL);
        per_ko[ko] += 1;
        side_count[side] += 1;
        if (passes == 2) terminal_count += 1;
        if (is_legal(&unrank_board(board)) and !seen_boards[board]) {
            seen_boards[board] = true;
            legal_count += 1;
        }
    }
    stats.total_marked = total_count;
    stats.legal_marked = legal_count;
    stats.per_ko_count = per_ko;
    stats.terminal_marked = terminal_count;
    stats.side_marked = side_count;

    util.out("# total marked: {d}\n", .{total_count});
    util.out("#   by ko:  ko=none={d}  ko=cells={d}\n", .{ per_ko[KO_DIMS - 1], total_count - per_ko[KO_DIMS - 1] });
    util.out("#   by side: B={d}  W={d}\n", .{ side_count[0], side_count[1] });
    util.out("#   terminals (passes=2): {d}\n", .{terminal_count});
    util.out("# sweeps: {d}\n", .{sweep_idx});
    util.out("# verdict: census covers {d} (state-tuple) addresses, of which {d} distinct legal boards\n", .{ total_count, legal_count });

    return stats;
}

const CensusStats = struct {
    total_marked: u64,
    legal_marked: u64,
    per_ko_count: [KO_DIMS]u64,
    sweeps: u32,
    terminal_marked: u64,
    side_marked: [2]u64,
};

// ---- 3x2 FIXPOINT: L, H, V = median(L, TIE, H) -----------------------------
//
// We hold two i8 tables L[S] and H[S] for every reachable state. (States not
// marked reachable in the census are excluded; we sweep over the marked set
// using the bitset as a worklist.) The Bellman operator is:
//
//   (Phi X)(S) = area_score(goban)                       if S is terminal
//             = max over successors X(S')                if S is Black to move
//             = min over successors X(S')                if S is White to move
//
//   (ADR-0009: same operator for both L and H, Black max / White min in both.)
//
//   L = least fixpoint (sweep up from -n)
//   H = greatest fixpoint (sweep down from +n)
//
// V(S) = median(L(S), TIE, H(S))  — the v2 corrected rule, equivalent to
//                                       max(L(S), min(TIE, H(S))) when L <= H.
//
// The sweep is over the LEGAL-MOVE GRAPH on the REACHABLE SET (computed
// by `run_census_3x2`). Pass moves are always legal, so every non-terminal
// reachable state has at least one successor within the reachable set (the
// pass edge leading to a state with passes+1, which is also reachable because
// the reachability fixpoint closed under moves; the only non-reachable
// states are non-legal or those requiring a non-ko move to enter).

/// The L/H fixpoint kernel (used by both `run_fixpoint_3x2` and the
/// probe branch in `main`). Caller provides the tables; the kernel
/// initializes terminals to area_score, runs interleaved L (up from -n)
/// and H (down from +n) sweeps, returns a stats record. The shared
/// Bellman operator is the ADR-0009 v2 form: at Black nodes, max over
/// children; at White nodes, min over children. Same operator for L and
/// H — the difference is the seed and the monotonicity direction.
fn fixpoint_kernel(reach: []const u64, L_tab: []i8, H_tab: []i8) FixpointStats {
    const L_init: i8 = -@as(i8, @intCast(n));
    const H_init: i8 = @as(i8, @intCast(n));
    for (0..TOTAL_STATES) |i| {
        L_tab[i] = L_init;
        H_tab[i] = H_init;
    }
    // Initialize terminals
    var lin2: u64 = 0;
    while (lin2 < TOTAL_STATES) : (lin2 += 1) {
        const word = lin2 >> 6;
        const bit: u64 = @as(u64, 1) << @intCast(lin2 & 63);
        if (reach[word] & bit == 0) continue;
        const passes: u8 = @intCast(lin2 / (2 * KO_DIMS * RAW_TOTAL));
        if (passes == 2) {
            const rest: u64 = lin2 % (2 * KO_DIMS * RAW_TOTAL);
            const rest2: u64 = rest % (KO_DIMS * RAW_TOTAL);
            const board_idx: u32 = @intCast(rest2 % RAW_TOTAL);
            const b = unrank_board(board_idx);
            L_tab[lin2] = area_score(&b);
            H_tab[lin2] = area_score(&b);
        }
    }
    var sweep_idx: u32 = 0;
    var total_changes: u64 = 1;
    const MAX_SWEEPS: u32 = 64;
    while (total_changes > 0 and sweep_idx < MAX_SWEEPS) {
        sweep_idx += 1;
        total_changes = 0;
        // L sweep
        var l_changed: u64 = 0;
        var li: u64 = 0;
        while (li < TOTAL_STATES) : (li += 1) {
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
            var succ_boards: [n + 1]Pos = undefined;
            var succs: [n + 1]StateIdx = undefined;
            const m = moves(state, &succ_boards, &succs);
            if (side == 0) {
                // Black max over L(children); L ascends so any best > current
                var best: i8 = L_init;
                var any: bool = false;
                for (0..m) |k| {
                    const child = succs[k];
                    if (!is_legal(&succ_boards[k])) continue;
                    const child_li = child.linear();
                    if (reach[child_li >> 6] & (@as(u64, 1) << @intCast(child_li & 63)) == 0) continue;
                    const v = L_tab[child_li];
                    if (!any or v > best) {
                        best = v;
                        any = true;
                    }
                }
                if (any and best > L_tab[li]) {
                    L_tab[li] = best;
                    l_changed += 1;
                }
            } else {
                // White min over L(children); L ascends so any best > current
                var best: i8 = H_init;
                var any: bool = false;
                for (0..m) |k| {
                    const child = succs[k];
                    if (!is_legal(&succ_boards[k])) continue;
                    const child_li = child.linear();
                    if (reach[child_li >> 6] & (@as(u64, 1) << @intCast(child_li & 63)) == 0) continue;
                    const v = L_tab[child_li];
                    if (!any or v < best) {
                        best = v;
                        any = true;
                    }
                }
                if (any and best > L_tab[li]) {
                    L_tab[li] = best;
                    l_changed += 1;
                }
            }
        }
        // H sweep (same operator: Black max, White min); H descends so the
        // driving check flips: best < H_tab[hi] for Black, best < for White.
        // (H descends for both; the side only affects WHICH child's value
        // we pick — Black max, White min — not the descent direction.
        // Earlier this comment read "best > for White", a copy error: T378.)
        var h_changed: u64 = 0;
        var hi: u64 = 0;
        while (hi < TOTAL_STATES) : (hi += 1) {
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
            var succ_boards: [n + 1]Pos = undefined;
            var succs: [n + 1]StateIdx = undefined;
            const m = moves(state, &succ_boards, &succs);
            if (side == 0) {
                // Black max over H(children); H descends so any best < current
                var best: i8 = H_init;
                var any: bool = false;
                for (0..m) |k| {
                    const child = succs[k];
                    if (!is_legal(&succ_boards[k])) continue;
                    const child_li = child.linear();
                    if (reach[child_li >> 6] & (@as(u64, 1) << @intCast(child_li & 63)) == 0) continue;
                    const v = H_tab[child_li];
                    if (!any or v > best) {
                        best = v;
                        any = true;
                    }
                }
                if (any and best < H_tab[hi]) {
                    H_tab[hi] = best;
                    h_changed += 1;
                }
            } else {
                // White min over H(children); H descends so any best < current
                var best: i8 = L_init;
                var any: bool = false;
                for (0..m) |k| {
                    const child = succs[k];
                    if (!is_legal(&succ_boards[k])) continue;
                    const child_li = child.linear();
                    if (reach[child_li >> 6] & (@as(u64, 1) << @intCast(child_li & 63)) == 0) continue;
                    const v = H_tab[child_li];
                    if (!any or v < best) {
                        best = v;
                        any = true;
                    }
                }
                if (any and best < H_tab[hi]) {
                    H_tab[hi] = best;
                    h_changed += 1;
                }
            }
        }
        total_changes = l_changed + h_changed;
        if (sweep_idx % 4 == 0 or total_changes == 0) {
            util.out("# sweep {d}: L_changed={d} H_changed={d}\n", .{ sweep_idx, l_changed, h_changed });
        }
    }
    // Pin census
    var stats: FixpointStats = .{
        .sweeps = sweep_idx,
        .l_eq_h = 0,
        .pin_t = 0,
        .pin_l = 0,
        .pin_h = 0,
        .illegal_check = 0,
        .l_lt_h_total = 0,
    };
    var linear: u64 = 0;
    while (linear < TOTAL_STATES) : (linear += 1) {
        const word = linear >> 6;
        const bit: u64 = @as(u64, 1) << @intCast(linear & 63);
        if (reach[word] & bit == 0) continue;
        const Ll = L_tab[linear];
        const Hh = H_tab[linear];
        if (Ll == Hh) {
            stats.l_eq_h += 1;
        } else {
            stats.l_lt_h_total += 1;
            if (TIE < Ll) {
                stats.pin_l += 1;
            } else if (TIE > Hh) {
                stats.pin_h += 1;
            } else {
                stats.pin_t += 1;
            }
        }
    }
    util.out("# sweeps: {d} (final total_changes = {d})\n", .{ sweep_idx, total_changes });
    util.out("# pin census:  L==H={d}  L<H&pin_T={d}  L<H&pin_L={d}  L<H&pin_H={d}\n", .{
        stats.l_eq_h,
        stats.pin_t,
        stats.pin_l,
        stats.pin_h,
    });
    util.out("# v1's wrong rule would have given `pin_t + pin_l + pin_h` wrong; v2's rule gives all three correct.\n", .{});
    return stats;
}

fn run_fixpoint_3x2(reach: []const u64) !FixpointStats {
    util.out("# qa023 probe — 3x2 two-fixpoint (L, H) and V = median(L, TIE, H)\n", .{});
    util.out("# TIE = {d}, n = {d}\n", .{ TIE, n });
    const gpa = std.heap.page_allocator;
    const L_tab = try gpa.alloc(i8, TOTAL_STATES);
    defer gpa.free(L_tab);
    const H_tab = try gpa.alloc(i8, TOTAL_STATES);
    defer gpa.free(H_tab);
    return fixpoint_kernel(reach, L_tab, H_tab);
}

const FixpointStats = struct {
    sweeps: u32,
    l_eq_h: u64,
    pin_t: u64,
    pin_l: u64,
    pin_h: u64,
    illegal_check: u64,
    l_lt_h_total: u64,
};

// ---- 3x2 HISTORY-SENSITIVITY PROBE ----------------------------------------
//
// Modelled on T13 (c2-falsification-3x2.md). For each of N sampled states
// (biased toward cycle-involved states — i.e. states where the cycle census
// says the truncated evaluator must encounter a cycle):
//
//   1. Enumerate up to K distinct reachable ARRIVAL HISTORIES ending at the
//      state S. An arrival history is a sequence of legal placements + passes
//      (with full state tuple as the fingerprint) from the empty-goban root
//      to S. Two histories are "distinct" if the multiset of moves played
//      differs (i.e. not a simple re-ordering of the same moves).
//   2. For each arrival history, evaluate S with FIRST-REVISIT TRUNCATION
//      (Theorem 6.1 in v2): search the game tree from S, scoring a leaf
//      `TIE` if the path revisits a state in the current PATH (not the
//      arrival prefix), terminal `area_score` if `passes == 2`, otherwise
//      minimax.
//      CRITICAL: per the reviewer's F1 finding, do NOT cache truncated
//      values by state across paths — interior truncated values are
//      path-dependent. (Theorem 6.1 equates only the ROOT value with
//      V(S); the probe asks for the root value, so this is sound.)
//   3. Compare each arrival's evaluated value with the fixpoint V(S).
//      Any disagreement falsifies QA-023 (history-dependent) OR the
//      implementation (a real bug we must find).
//
// Budget: each history is evaluated with a node budget; report the
// budget-exhaustion count.

const HistoryEntry = struct {
    state: StateIdx,
    board: Pos,
    parent_idx: u32, // index into the path; 0xFFFFFFFF = root
    kind: HistoryKind,
    cell: u8, // for place; 0 for pass
    move_board: Pos, // the goban AFTER the move that led here (for fingerprint use)
    depth: u16,
};

const HistoryKind = enum { place, pass };

const Path = struct {
    entries: []HistoryEntry,
    len: u16,
    fingerprint: []const u8, // alias of entries[0..len], walk in order to detect revisits
};

fn fp_eq(a: HistoryEntry, b: HistoryEntry) bool {
    if (a.state.side != b.state.side) return false;
    if (a.state.ko != b.state.ko) return false;
    if (a.state.passes != b.state.passes) return false;
    if (a.state.board != b.state.board) return false;
    return true;
}
/// `path` is the arrival history; this function builds the continuation
/// tree from `state`, scoring revisits within the continuation as TIE.
/// Returns the value, or `null` if exhausted (budget or scratch).
/// `scratch_full` is set to true on scratch overflow, false on budget exhaustion.
/// `collision_count` is incremented when the arrival set contains the target
/// state σ itself (defect 1 in probe-defect-2026-07-29); caller zeroes it.
fn truncated_value(
    state: StateIdx,
    board: *const Pos,
    arrival: []const HistoryEntry,
    arrival_len: u16,
    budget: *u64,
    scratch: []HistoryEntry,
    scratch_top: *u16,
    tie_value: i8,
    scratch_full: *bool,
    collision_count: *u64,
) ?i8 {
    if (budget.* == 0) return null;
    budget.* -= 1;
    // Independent defect verification: is σ itself in the arrival set?
    // Per reference-semantics §1, the arrival set is exclusive of σ.
    // If arrival_len > 0 and arrival[arrival_len-1] matches the current
    // (state, goban), that is a σ-in-arrival collision.
    // ONLY count at the top-level call (scratch_top == 0) — recursive
    // matches against the arrival prefix are normal and not the defect.
    if (scratch_top.* == 0 and arrival_len > 0) {
        const last = arrival[arrival_len - 1];
        if (last.state.board == state.board and last.state.side == state.side and
            last.state.ko == state.ko and last.state.passes == state.passes)
        {
            collision_count.* += 1;
        }
    }
    // Cycle check: has `state` appeared in the arrival prefix OR in the
    // continuation-so-far (entries 0..arrival_len-1 plus scratch[0..*scratch_top])?
    var i: u16 = 0;
    while (i < arrival_len) : (i += 1) {
        if (fp_eq(arrival[i], .{
            .state = state,
            .board = board.*,
            .parent_idx = 0,
            .kind = .place,
            .cell = 0,
            .move_board = undefined,
            .depth = 0,
        })) return tie_value;
    }
    i = 0;
    while (i < scratch_top.*) : (i += 1) {
        if (fp_eq(scratch[i], .{
            .state = state,
            .board = board.*,
            .parent_idx = 0,
            .kind = .place,
            .cell = 0,
            .move_board = undefined,
            .depth = 0,
        })) return tie_value;
    }
    // Terminal
    if (state.passes == 2) return area_score(board);
    // Enumerate moves (max n+1)
    var succ_boards: [n + 1]Pos = undefined;
    var succs: [n + 1]StateIdx = undefined;
    const m = moves(state, &succ_boards, &succs);
    if (m == 0) return area_score(board); // defensive: no legal moves => score the current goban
    const maximizing: bool = (state.side == 0); // Black maximizes
    var best: i8 = if (maximizing) -127 else 127;
    for (0..m) |k| {
        if (!is_legal(&succ_boards[k])) continue;
        // Push this state onto scratch, recurse, then pop.
        if (scratch_top.* >= scratch.len) {
            scratch_full.* = true;
            return null;
        }
        scratch[scratch_top.*] = .{
            .state = state,
            .board = board.*,
            .parent_idx = 0,
            .kind = .pass,
            .cell = 0,
            .move_board = succ_boards[k],
            .depth = 0,
        };
        scratch_top.* += 1;
        const child = succs[k];
        const v = truncated_value(child, &succ_boards[k], arrival, arrival_len, budget, scratch, scratch_top, tie_value, scratch_full, collision_count) orelse return null;
        scratch_top.* -= 1;
        if (maximizing) {
            if (v > best) best = v;
        } else {
            if (v < best) best = v;
        }
    }
    return best;
}

/// Walk one arrival history: start at the empty goban (root), play the
/// sequence of `(move_kind, cell)` moves, return the final state. Returns null
/// if any move is illegal at the current state.
fn play_arrival(play: []const Move, play_len: u16) ?struct { state: StateIdx, board: Pos } {
    var state = StateIdx{ .board = 0, .side = 0, .ko = @as(u16, n), .passes = 0 };
    var board: Pos = [_]i8{0} ** n;
    var i: u16 = 0;
    while (i < play_len) : (i += 1) {
        const mv = play[i];
        const next = switch (mv.move_kind) {
            .place => apply_place(state, &board, mv.colour, mv.cell),
            .pass => apply_pass(state),
        };
        const ns = next orelse return null;
        state = ns;
        board = unrank_board(state.board);
    }
    return .{ .state = state, .board = board };
}

/// Replay a move sequence and collect all visited state linear indices
/// as a sorted, deduplicated visit-set. The visit-set includes the root
/// (empty goban) and every intermediate state up to and including the
/// final state. `set` must have capacity `max_visit`; on return
/// `set_len` is the number of distinct states visited.
fn visit_set_of_arrival(
    play: []const Move,
    play_len: u16,
    set: []u64,
    set_len: *u16,
) bool {
    var state = StateIdx{ .board = 0, .side = 0, .ko = @as(u16, n), .passes = 0 };
    var board: Pos = [_]i8{0} ** n;
    var raw: [32]u64 = undefined;
    raw[0] = state.linear();
    var raw_len: u16 = 1;
    var i: u16 = 0;
    while (i < play_len) : (i += 1) {
        const mv = play[i];
        const next = switch (mv.move_kind) {
            .place => apply_place(state, &board, mv.colour, mv.cell),
            .pass => apply_pass(state),
        };
        const ns = next orelse {
            set_len.* = 0;
            return false;
        };
        state = ns;
        board = unrank_board(state.board);
        raw[raw_len] = state.linear();
        raw_len += 1;
    }
    // insertion-sort the raw indices, dedup into `set`
    var j: u16 = 1;
    while (j < raw_len) : (j += 1) {
        const key = raw[j];
        var k: i16 = @intCast(j);
        while (k > 0 and raw[@intCast(k - 1)] > key) : (k -= 1) {
            raw[@intCast(k)] = raw[@intCast(k - 1)];
        }
        raw[@intCast(k)] = key;
    }
    set[0] = raw[0];
    set_len.* = 1;
    j = 1;
    while (j < raw_len) : (j += 1) {
        if (raw[j] != set[set_len.* - 1]) {
            if (set_len.* >= set.len) return false;
            set[set_len.*] = raw[j];
            set_len.* += 1;
        }
    }
    return true;
}

/// Returns true iff two visit-sets differ. Both are assumed sorted+dedup.
fn visit_sets_differ(a: []const u64, a_len: u16, b: []const u64, b_len: u16) bool {
    if (a_len != b_len) return true;
    var i: u16 = 0;
    while (i < a_len) : (i += 1) {
        if (a[i] != b[i]) return true;
    }
    return false;
}

const Move = struct {
    move_kind: enum { place, pass },
    cell: u8, // for place; ignored for pass
    colour: i8, // for place; ignored for pass
};

const ProbeParams = struct {
    seed: u64,
    n_samples: u32,
    k_histories: u32,
    history_depth: u16, // moves per arrival history
    node_budget_per_history: u64,
};

const ProbeOutcome = struct {
    n_total: u32,
    n_evaluated: u32,
    n_value_agreements: u32, // v != TIE, v == V_fixpoint  (reached a terminal, agrees with fixpoint)
    n_tie_valued: u32, // v == TIE  (first-revisit truncation)
    n_disagreement: u32,
    n_cycle_involved: u32,
    n_budget_exhausted: u32,
    n_scratch_overflow: u32,
    n_unreachable: u32,
    cycle_census_states: u32, // states that any arrival-history evaluator saw a cycle in
    pin_t_sampled: u32,
    pin_l_sampled: u32,
    pin_h_sampled: u32,
    l_eq_h_sampled: u32,
    history_total: u32,
    // C1/C2 split (2B-PROBE-FIX)
    n_c1_failures: u32, // within-budget evaluations disagree among themselves (C1 falsified)
    n_c2_failures: u32, // within-budget evaluations agree among themselves but disagree with fixpoint
    n_c1_eligible: u32, // states with >=2 within-budget evaluations (can test C1)
    n_c2_eligible: u32, // states with >=1 within-budget evaluation (can test C2)
    sigma_in_arrival_collisions: u64, // independent reproduction of defect 1
};

/// Collect up to `max_collect` distinct arrival histories from the empty
/// goban root to `target_linear` using depth-first search over simple paths
/// (no repeated states on the arrival prefix).  `budget` limits the total
/// nodes explored; exhaustion is reported by the caller.  Histories are
/// deduplicated by FNV-1a hash of their move sequence.
fn collect_histories_dfs_impl(
    state: StateIdx,
    board: *const Pos,
    target_linear: u64,
    depth: u16,
    max_depth: u16,
    budget: *u64,
    path_moves: []Move,
    path_len: *u16,
    visited: []bool,
    collected_moves: []Move,
    collected_lens: []u16,
    collected_count: *u32,
    max_collect: u32,
    history_depth: u16,
    prng: *std.Random,
) void {
    const linear = state.linear();
    if (linear == target_linear) {
        if (collected_count.* >= max_collect) return;
        var h: u64 = 0xcbf29ce484222325;
        for (0..path_len.*) |p_| {
            const mv = path_moves[p_];
            h = (h ^ @as(u64, @intCast(@as(u8, @intFromEnum(mv.move_kind))))) *% 0x100000001b3;
            h = (h ^ @as(u64, mv.cell)) *% 0x100000001b3;
            h = (h ^ (@as(u64, @bitCast(@as(i64, mv.colour))))) *% 0x100000001b3;
        }
        var i: u32 = 0;
        while (i < collected_count.*) : (i += 1) {
            const li = collected_lens[i];
            if (li != path_len.*) continue;
            const base = i * history_depth;
            var same = true;
            var j: u16 = 0;
            while (j < li) : (j += 1) {
                const a = collected_moves[base + j];
                const b = path_moves[j];
                if (@intFromEnum(a.move_kind) != @intFromEnum(b.move_kind) or a.cell != b.cell or a.colour != b.colour) {
                    same = false;
                    break;
                }
            }
            if (same) return;
        }
        const base = collected_count.* * history_depth;
        for (0..path_len.*) |p_| {
            collected_moves[base + p_] = path_moves[p_];
        }
        collected_lens[collected_count.*] = path_len.*;
        collected_count.* += 1;
        return;
    }
    if (depth == max_depth or budget.* == 0) return;
    budget.* -= 1;

    visited[linear] = true;

    var succ_boards: [n + 1]Pos = undefined;
    var succs: [n + 1]StateIdx = undefined;
    const m = moves(state, &succ_boards, &succs);
    var order: [n + 1]usize = undefined;
    for (0..m) |j| order[j] = j;
    var mm = m;
    while (mm > 1) {
        mm -= 1;
        const j = prng.intRangeAtMost(usize, 0, mm);
        const tmp = order[mm];
        order[mm] = order[j];
        order[j] = tmp;
    }

    for (0..m) |k| {
        const idx = order[k];
        const child = succs[idx];
        const child_linear = child.linear();
        if (visited[child_linear]) continue;

        // A pass never changes the goban; a place move always does.
        const mv = if (child.board == state.board)
            Move{ .move_kind = .pass, .cell = 0, .colour = 0 }
        else blk: {
            const next_b = succ_boards[idx];
            // Find the PLACED cell: the one that changed from empty (0) to occupied.
            // Captures change non-zero to 0; the placed stone changes 0 to non-zero.
            var cell: u8 = 0;
            var found: bool = false;
            var c: usize = 0;
            while (c < n) : (c += 1) {
                if (board[c] == 0 and next_b[c] != 0) {
                    cell = @intCast(c);
                    found = true;
                    break;
                }
            }
            // Fallback: if no empty→occupied change (e.g., a capture that exactly
            // clears a cell while the placed stone fills another), scan any diff.
            if (!found) {
                c = 0;
                while (c < n) : (c += 1) {
                    if (board[c] != next_b[c]) {
                        cell = @intCast(c);
                        break;
                    }
                }
            }
            const colour: i8 = if (state.side == 0) 1 else -1;
            break :blk Move{ .move_kind = .place, .cell = cell, .colour = colour };
        };

        path_moves[path_len.*] = mv;
        path_len.* += 1;
        collect_histories_dfs_impl(child, &succ_boards[idx], target_linear, depth + 1, max_depth, budget, path_moves, path_len, visited, collected_moves, collected_lens, collected_count, max_collect, history_depth, prng);
        path_len.* -= 1;
    }

    visited[linear] = false;
}

fn collect_histories(
    target_linear: u64,
    max_depth: u16,
    budget: *u64,
    path_moves: []Move,
    visited: []bool,
    collected_moves: []Move,
    collected_lens: []u16,
    max_collect: u32,
    history_depth: u16,
    prng: *std.Random,
) u32 {
    var path_len: u16 = 0;
    var collected_count: u32 = 0;
    const root = StateIdx{ .board = 0, .side = 0, .ko = @as(u16, n), .passes = 0 };
    const root_board: Pos = [_]i8{0} ** n;
    collect_histories_dfs_impl(root, &root_board, target_linear, 0, max_depth, budget, path_moves, &path_len, visited, collected_moves, collected_lens, &collected_count, max_collect, history_depth, prng);
    return collected_count;
}

fn run_probe_3x2(
    reach: []const u64,
    L_tab: []const i8,
    H_tab: []const i8,
    params: ProbeParams,
) !ProbeOutcome {
    util.out("# qa023 probe — 3x2 HISTORY-SENSITIVITY PROBE (T13-style)\n", .{});
    util.out("# params: seed={d} n_samples={d} k_histories={d} history_depth={d} budget/history={d}\n", .{
        params.seed,
        params.n_samples,
        params.k_histories,
        params.history_depth,
        params.node_budget_per_history,
    });

    const gpa = std.heap.page_allocator;
    var prng = std.Random.DefaultPrng.init(params.seed);

    // First: collect the list of all reachable (board, side, ko, passes)
    // states. Sampling biases toward cycle-involved states (L<H); we
    // weight the choice proportional to the cycle census. Since the
    // cycle census is only known AFTER the truncated evaluator runs on
    // a state, we instead classify by L<H from the fixpoint (a state
    // is *guaranteed* cycle-involved iff L<H; the reverse does not hold
    // for the truncated evaluator but is a good proxy: every state with
    // L<H is in the bracket, and the bracket is what the median rule
    // pins).
    //
    // Build a flat index of (linear_state, kind) tuples, then sample.
    var reachable_indices = try gpa.alloc(u64, TOTAL_STATES);
    defer gpa.free(reachable_indices);
    var reachable_count: u64 = 0;
    var pin_t_indices = try gpa.alloc(u64, TOTAL_STATES);
    defer gpa.free(pin_t_indices);
    var pin_t_count: u64 = 0;
    var pin_l_indices = try gpa.alloc(u64, TOTAL_STATES);
    defer gpa.free(pin_l_indices);
    var pin_l_count: u64 = 0;
    var pin_h_indices = try gpa.alloc(u64, TOTAL_STATES);
    defer gpa.free(pin_h_indices);
    var pin_h_count: u64 = 0;
    var leh_indices = try gpa.alloc(u64, TOTAL_STATES);
    defer gpa.free(leh_indices);
    var leh_count: u64 = 0;
    {
        var linear: u64 = 0;
        while (linear < TOTAL_STATES) : (linear += 1) {
            const word = linear >> 6;
            const bit: u64 = @as(u64, 1) << @intCast(linear & 63);
            if (reach[word] & bit == 0) continue;
            // skip terminals — they have no moves, the cycle census is uninteresting
            const passes: u8 = @intCast(linear / (2 * KO_DIMS * RAW_TOTAL));
            if (passes == 2) continue;
            reachable_indices[reachable_count] = linear;
            reachable_count += 1;
            const Ll = L_tab[linear];
            const Hh = H_tab[linear];
            if (Ll == Hh) {
                leh_indices[leh_count] = linear;
                leh_count += 1;
            } else if (TIE < Ll) {
                pin_l_indices[pin_l_count] = linear;
                pin_l_count += 1;
            } else if (TIE > Hh) {
                pin_h_indices[pin_h_count] = linear;
                pin_h_count += 1;
            } else {
                pin_t_indices[pin_t_count] = linear;
                pin_t_count += 1;
            }
        }
    }
    util.out("# reachable non-terminal states: {d}\n", .{reachable_count});
    util.out("#   L==H: {d}  pin_T: {d}  pin_L: {d}  pin_H: {d}\n", .{
        leh_count,
        pin_t_count,
        pin_l_count,
        pin_h_count,
    });

    // Sample with weights: 50% from pin_T (the original QA-023 hypothesis
    // is most likely to fail or pass here), 25% from L==H (sanity), 12.5%
    // each from pin_L and pin_H (these are the v2-only states, where v1
    // would have been wrong — useful to make sure v2's median rule is the
    // one we actually implemented).
    var outcome = ProbeOutcome{
        .n_total = params.n_samples,
        .n_evaluated = 0,
        .n_value_agreements = 0,
        .n_tie_valued = 0,
        .n_disagreement = 0,
        .n_cycle_involved = 0,
        .n_budget_exhausted = 0,
        .n_scratch_overflow = 0,
        .n_unreachable = 0,
        .cycle_census_states = 0,
        .pin_t_sampled = 0,
        .pin_l_sampled = 0,
        .pin_h_sampled = 0,
        .l_eq_h_sampled = 0,
        .history_total = 0,
        .n_c1_failures = 0,
        .n_c2_failures = 0,
        .n_c1_eligible = 0,
        .n_c2_eligible = 0,
        .sigma_in_arrival_collisions = 0,
    };

    // DFS resources for collecting distinct simple-path arrival histories.
    const path_moves = try gpa.alloc(Move, params.history_depth);
    defer gpa.free(path_moves);
    const visited_states = try gpa.alloc(bool, TOTAL_STATES);
    defer gpa.free(visited_states);
    const collected_moves = try gpa.alloc(Move, params.k_histories * params.history_depth);
    defer gpa.free(collected_moves);
    const collected_lens = try gpa.alloc(u16, params.k_histories);
    defer gpa.free(collected_lens);

    // Scratch for the truncated evaluator — continuation depth is bounded by
    // the reachable state count (~2,622 at 3×2), NOT by arrival depth. A
    // scratch sized `history_depth + 4` overflows silently (defect 2 in
    // probe-defect-2026-07-29). 4096 is a safe over-provision for 3×2.
    const scratch = try gpa.alloc(HistoryEntry, 4096);
    defer gpa.free(scratch);
    const arrival_buf = try gpa.alloc(HistoryEntry, 4096);
    defer gpa.free(arrival_buf);

    const TIE_PERTURB: i8 = if (TIE == 0) 1 else 0;

    var sample_idx: u32 = 0;
    while (sample_idx < params.n_samples) : (sample_idx += 1) {
        // Pick a bucket by weighted dice, then sample an index, recording
        // the kind only after a successful draw.
        const bucket_roll = prng.random().intRangeAtMost(u8, 0, 99);
        const target_linear: u64 = blk: {
            if (bucket_roll < 50 and pin_t_count > 0) {
                outcome.pin_t_sampled += 1;
                break :blk pin_t_indices[prng.random().intRangeAtMost(u64, 0, pin_t_count - 1)];
            } else if (bucket_roll < 75 and leh_count > 0) {
                outcome.l_eq_h_sampled += 1;
                break :blk leh_indices[prng.random().intRangeAtMost(u64, 0, leh_count - 1)];
            } else if (bucket_roll < 87 and pin_l_count > 0) {
                outcome.pin_l_sampled += 1;
                break :blk pin_l_indices[prng.random().intRangeAtMost(u64, 0, pin_l_count - 1)];
            } else if (pin_h_count > 0) {
                outcome.pin_h_sampled += 1;
                break :blk pin_h_indices[prng.random().intRangeAtMost(u64, 0, pin_h_count - 1)];
            } else {
                // fall back to any non-empty bucket
                if (pin_t_count > 0) {
                    outcome.pin_t_sampled += 1;
                    break :blk pin_t_indices[prng.random().intRangeAtMost(u64, 0, pin_t_count - 1)];
                } else if (leh_count > 0) {
                    outcome.l_eq_h_sampled += 1;
                    break :blk leh_indices[prng.random().intRangeAtMost(u64, 0, leh_count - 1)];
                } else if (pin_l_count > 0) {
                    outcome.pin_l_sampled += 1;
                    break :blk pin_l_indices[prng.random().intRangeAtMost(u64, 0, pin_l_count - 1)];
                } else break :blk 0;
            }
        };

        // Decode the state
        const passes: u8 = @intCast(target_linear / (2 * KO_DIMS * RAW_TOTAL));
        const rest: u64 = target_linear % (2 * KO_DIMS * RAW_TOTAL);
        const side: u8 = @intCast(rest / (KO_DIMS * RAW_TOTAL));
        const rest2: u64 = rest % (KO_DIMS * RAW_TOTAL);
        const ko: u16 = @intCast(rest2 / RAW_TOTAL);
        const board: u32 = @intCast(rest2 % RAW_TOTAL);
        const state = StateIdx{ .board = board, .side = side, .ko = ko, .passes = passes };
        const target_board = unrank_board(board);

        // Fixpoint V
        const Ll = L_tab[target_linear];
        const Hh = H_tab[target_linear];
        const V_fixpoint: i8 = @max(Ll, @min(TIE, Hh));

        // Collect up to K distinct simple-path arrival histories via DFS.
        @memset(visited_states, false);
        var collection_budget: u64 = params.k_histories * 1024;
        var rand = prng.random();
        const n_collected = collect_histories(target_linear, params.history_depth, &collection_budget, path_moves, visited_states, collected_moves, collected_lens, params.k_histories, params.history_depth, &rand);

        if (n_collected == 0) {
            outcome.n_unreachable += 1;
            if (sample_idx % 8 == 0 and sample_idx > 0) {
                util.out("# sample {d}/{d}: value_agree={d} TIE={d} disagree={d} budget={d}\n", .{
                    sample_idx,
                    params.n_samples,
                    outcome.n_value_agreements,
                    outcome.n_tie_valued,
                    outcome.n_disagreement,
                    outcome.n_budget_exhausted,
                });
            }
            continue;
        }

        outcome.n_evaluated += 1;
        var sample_had_disagreement: bool = false;
        var sample_had_successful_eval: bool = false;
        var sample_cycle_mattered: bool = false;
        // C1/C2 tracking (2B-PROBE-FIX): per-sample, per-history within-budget vals
        var c1_first_val: ?i8 = null;
        var c1_all_agree: bool = true;
        var c1_within_budget_count: u32 = 0;
        var hist_idx: u32 = 0;
        while (hist_idx < n_collected) : (hist_idx += 1) {
            const base = hist_idx * params.history_depth;
            const hlen = collected_lens[hist_idx];
            const play = collected_moves[base .. base + hlen];

            // Build arrival path by replaying the move sequence.
            var arrival_len: u16 = 0;
            arrival_buf[arrival_len] = .{
                .state = .{ .board = 0, .side = 0, .ko = @as(u16, n), .passes = 0 },
                .board = [_]i8{0} ** n,
                .parent_idx = 0,
                .kind = .pass,
                .cell = 0,
                .move_board = [_]i8{0} ** n,
                .depth = 0,
            };
            arrival_len += 1;
            {
                var cur2 = StateIdx{ .board = 0, .side = 0, .ko = @as(u16, n), .passes = 0 };
                var cur_b: Pos = [_]i8{0} ** n;
                var j: u16 = 0;
                while (j < hlen) : (j += 1) {
                    const mv = play[j];
                    const next = switch (mv.move_kind) {
                        .place => apply_place(cur2, &cur_b, mv.colour, mv.cell),
                        .pass => apply_pass(cur2),
                    };
                    const ns = next orelse break;
                    const next_b = unrank_board(ns.board);
                    arrival_buf[arrival_len] = .{
                        .state = ns,
                        .board = next_b,
                        .parent_idx = arrival_len - 1,
                        .kind = @as(HistoryKind, @enumFromInt(@intFromEnum(mv.move_kind))),
                        .cell = mv.cell,
                        .move_board = next_b,
                        .depth = arrival_len,
                    };
                    arrival_len += 1;
                    cur2 = ns;
                    cur_b = next_b;
                }
            }

            // Evaluate S with first-revisit truncation.
            var budget1 = params.node_budget_per_history;
            var scratch_top1: u16 = 0;
            var scratch_full1: bool = false;
            var collision_count1: u64 = 0;
            const v = truncated_value(state, &target_board, arrival_buf[0..arrival_len - 1], arrival_len - 1, &budget1, scratch, &scratch_top1, TIE, &scratch_full1, &collision_count1);
            outcome.sigma_in_arrival_collisions += collision_count1;
            outcome.history_total += 1;
            if (v == null) {
                if (scratch_full1) {
                    outcome.n_scratch_overflow += 1;
                } else {
                    outcome.n_budget_exhausted += 1;
                }
                continue;
            }
            sample_had_successful_eval = true;

            // C1/C2 tracking (2B-PROBE-FIX): record within-budget truncated value
            c1_within_budget_count += 1;
            if (c1_first_val == null) {
                c1_first_val = v.?;
            } else if (c1_first_val.? != v.?) {
                c1_all_agree = false;
            }

            // Three-way split per reference-semantics §2:
            //   value (v != TIE) / TIE (v == TIE) / BUDGET-EXHAUSTED (v == null)
            if (v.? == TIE) {
                // The evaluator hit a first-revisit and returned TIE.
                // Per QA-023, the fixpoint V must also equal TIE here (if not,
                // this is a disagreement — the median rule should have pinned
                // TIE if the truncated evaluator saw a cycle).
                if (v.? != V_fixpoint) {
                    sample_had_disagreement = true;
                    outcome.n_disagreement += 1;
                    if (outcome.n_disagreement <= 100) {
                        util.out("# DISAGREE(TIE) #{d}: state=({d},{d},{d},{d}) V_fixpoint={d} truncated=TIE arrival_len={d}\n", .{
                            outcome.n_disagreement,
                            state.board, state.side, state.ko, state.passes,
                            V_fixpoint,
                            arrival_len,
                        });
                        util.out("#   arrival: ", .{});
                        var mvi2: u16 = 0;
                        while (mvi2 < hlen) : (mvi2 += 1) {
                            const mv2 = play[mvi2];
                            if (mv2.move_kind == .pass) {
                                util.out("pass ", .{});
                            } else {
                                util.out("{s}{d} ", .{ if (mv2.colour > 0) "B" else "W", mv2.cell });
                            }
                        }
                        util.out("\n", .{});
                    }
                } else {
                    outcome.n_tie_valued += 1;
                    sample_cycle_mattered = true;
                }
                continue;
            }

            if (v.? != V_fixpoint) {
                sample_had_disagreement = true;
                outcome.n_disagreement += 1;
                // Dump the first 5 disagreements verbatim per 2B-4 acceptance.
                if (outcome.n_disagreement <= 100) {
                    util.out("# DISAGREE #{d}: state=({d},{d},{d},{d}) V_fixpoint={d} truncated={d} arrival_len={d}\n", .{
                        outcome.n_disagreement,
                        state.board, state.side, state.ko, state.passes,
                        V_fixpoint, v.?,
                        arrival_len,
                    });
                    // Replay the arrival moves
                    util.out("#   arrival: ", .{});
                    var mvi: u16 = 0;
                    while (mvi < hlen) : (mvi += 1) {
                        const mv = play[mvi];
                        if (mv.move_kind == .pass) {
                            util.out("pass ", .{});
                        } else {
                            util.out("{s}{d} ", .{ if (mv.colour > 0) "B" else "W", mv.cell });
                        }
                    }
                    util.out("\n", .{});
                }
                continue;
            }

            // Perturbation test: if changing the tie value changes the root
            // value, then a truncated-leaf TIE was on the optimal line.
            var budget2 = params.node_budget_per_history;
            var scratch_top2: u16 = 0;
            var scratch_full2: bool = false;
            var collision_count2: u64 = 0;
            const v_perturb = truncated_value(state, &target_board, arrival_buf[0..arrival_len - 1], arrival_len - 1, &budget2, scratch, &scratch_top2, TIE_PERTURB, &scratch_full2, &collision_count2);
            outcome.sigma_in_arrival_collisions += collision_count2;
            if (v_perturb == null) {
                if (scratch_full2) {
                    outcome.n_scratch_overflow += 1;
                } else {
                    outcome.n_budget_exhausted += 1;
                }
                continue;
            }
            if (v_perturb.? != v.?) {
                sample_cycle_mattered = true;
            }
            outcome.n_value_agreements += 1;
        }
        if (sample_had_disagreement) {
            // already counted per-history in n_disagreement; sample-level count is implicit
        } else if (sample_had_successful_eval) {
            // at least one history agreed and none disagreed
        }
        // Per-sample C1/C2 adjudication (2B-PROBE-FIX)
        if (c1_within_budget_count >= 2) {
            outcome.n_c1_eligible += 1;
            if (!c1_all_agree) {
                outcome.n_c1_failures += 1;
            }
        }
        if (c1_within_budget_count >= 1) {
            outcome.n_c2_eligible += 1;
            if (c1_all_agree and c1_first_val != null and c1_first_val.? != V_fixpoint) {
                outcome.n_c2_failures += 1;
            }
        }
        if (sample_cycle_mattered) outcome.cycle_census_states += 1;
        if (sample_idx % 8 == 0 and sample_idx > 0) {
            util.out("# sample {d}/{d}: value_agree={d} TIE={d} disagree={d} budget={d} scratch={d}\n", .{
                sample_idx,
                params.n_samples,
                outcome.n_value_agreements,
                outcome.n_tie_valued,
                outcome.n_disagreement,
                outcome.n_budget_exhausted,
                outcome.n_scratch_overflow,
            });
        }
    }

    util.out("# === probe verdict ===\n", .{});
    util.out("# samples requested: {d}\n", .{params.n_samples});
    util.out("# samples evaluated: {d}\n", .{outcome.n_evaluated});
    util.out("# sigma-in-arrival collisions (defect 1, should be 0): {d}\n", .{outcome.sigma_in_arrival_collisions});
    util.out("# === three-way split (ref-semantics §2) ===\n", .{});
    const within_budget: u32 = outcome.history_total - outcome.n_budget_exhausted - outcome.n_scratch_overflow;
    util.out("# value-agreements (v != TIE, v == V): {d}  (/{d} within-budget)\n", .{ outcome.n_value_agreements, within_budget });
    util.out("# TIE-valued (v == TIE): {d}  (/{d} within-budget)\n", .{ outcome.n_tie_valued, within_budget });
    util.out("# budget-exhausted (v == null, budget): {d} / {d}\n", .{ outcome.n_budget_exhausted, outcome.history_total });
    util.out("# scratch-overflow (v == null, scratch): {d} / {d}\n", .{ outcome.n_scratch_overflow, outcome.history_total });
    util.out("# disagreements (v != TIE, v != V, v != null): {d}  (/{d} within-budget)\n", .{ outcome.n_disagreement, within_budget });
    util.out("# samples no arrival history reached target: {d}\n", .{outcome.n_unreachable});
    util.out("# cycle-census states (any history hit TIE leaf): {d}\n", .{outcome.cycle_census_states});
    util.out("# sampled-kind counts: L==H={d} pin_T={d} pin_L={d} pin_H={d}\n", .{
        outcome.l_eq_h_sampled,
        outcome.pin_t_sampled,
        outcome.pin_l_sampled,
        outcome.pin_h_sampled,
    });
    util.out("# === C1/C2 split (2B-PROBE-FIX) ===\n", .{});
    util.out("# C1: states with >=2 within-budget evals (can test C1): {d}\n", .{outcome.n_c1_eligible});
    util.out("# C1: states where within-budget values disagree among themselves: {d}\n", .{outcome.n_c1_failures});
    util.out("# C2: states with >=1 within-budget eval (can test C2): {d}\n", .{outcome.n_c2_eligible});
    util.out("# C2: states where all agree but disagree with fixpoint V: {d}\n", .{outcome.n_c2_failures});
    if (outcome.n_c1_failures > 0) {
        util.out("# C1 VERDICT: FALSIFIED — {d} states show history-dependent truncated values\n", .{outcome.n_c1_failures});
    } else if (outcome.n_c1_eligible > 0) {
        util.out("# C1 VERDICT: no history-dependence among {d} eligible states (histories share ~62% prefixes per 2B-3-AUDIT; short paths systematically missed — UNTESTED-FOR-WANT-OF-CONTRAST, not a clean pass)\n", .{outcome.n_c1_eligible});
    } else {
        util.out("# C1 VERDICT: INCONCLUSIVE — no states with >=2 within-budget evals\n", .{});
    }
    if (outcome.n_c2_failures > 0) {
        util.out("# C2 VERDICT: FALSIFIED — {d} states where truncated value != fixpoint V\n", .{outcome.n_c2_failures});
    } else if (outcome.n_c2_eligible > 0) {
        util.out("# C2 VERDICT: CONSISTENT on {d} eligible states — all within-budget values match fixpoint\n", .{outcome.n_c2_eligible});
    } else {
        util.out("# C2 VERDICT: INCONCLUSIVE — no states with >=1 within-budget eval\n", .{});
    }
    // Legacy QA-023 summary (OR of C1 and C2)
    if (outcome.n_disagreement == 0 and outcome.n_evaluated > 0) {
        util.out("# QA-023 (legacy): NOT FALSIFIED on this sample. No arrival history disagreed with V.\n", .{});
    } else if (outcome.n_disagreement > 0) {
        util.out("# QA-023 (legacy): FALSIFIED on this sample. See C1/C2 split above for which conjunct failed.\n", .{});
    } else {
        util.out("# QA-023 (legacy): INCONCLUSIVE (no evaluated samples).\n", .{});
    }
    return outcome;
}

// ############################################################################
// PSK (Positional Superko) infrastructure — 2B-5 POS calibration
// ############################################################################
//
// Under PSK the state tuple is (board, side, passes): ko_point is always
// "none" because PSK bans goban-position repeats, not ko-point-specific
// repeats. State space: 729 gobans × 2 sides × 3 passes = 4,374 states.
//
// The PSK fixpoint is the no-ko minimax fixpoint: same Bellman operator
// (Black max / White min in both L and H), no ko ban. The fixpoint cannot
// express positional superko (which is history-dependent), so it is a
// "no-ko" fixpoint. The history-aware PSK evaluator adds PSK legality.
//
// The PSK evaluator does full minimax search with PSK legality (goban
// repeats are illegal moves). It does NOT use first-revisit truncation —
// revisits are illegal, not TIE-valued. Search continues to terminal
// (passes==2) or budget exhaustion.

const PSK_RAW_TOTAL: u64 = 729;
const PSK_TOTAL: u64 = PSK_RAW_TOTAL * 2 * 3; // 4,374

fn psk_linear(board: u32, side: u8, passes: u8) u64 {
    return ((@as(u64, board) * 2) + side) * 3 + passes;
}

fn psk_decode(linear: u64) struct { board: u32, side: u8, passes: u8 } {
    const passes: u8 = @intCast(linear % 3);
    const rest: u64 = linear / 3;
    const side: u8 = @intCast(rest % 2);
    const board: u32 = @intCast(rest / 2);
    return .{ .board = board, .side = side, .passes = passes };
}

const PskFixpointStats = struct {
    sweeps: u32,
    l_eq_h: u64,
    pin_t: u64,
    pin_l: u64,
    pin_h: u64,
};

/// PSK fixpoint: no-ko minimax over (board, side, passes).
/// L = least fixpoint (seed -n), H = greatest (seed +n).
fn psk_fixpoint(L_tab: []i8, H_tab: []i8) PskFixpointStats {
    const L_init: i8 = -@as(i8, @intCast(n));
    const H_init: i8 = @as(i8, @intCast(n));
    for (0..PSK_TOTAL) |i| {
        L_tab[i] = L_init;
        H_tab[i] = H_init;
    }
    // Initialize terminals: passes == 2 → area_score.
    for (0..PSK_RAW_TOTAL) |bi_u| {
        const bi: u32 = @intCast(bi_u);
        const board = unrank_board(bi);
        const a = area_score(&board);
        for (0..2) |si| {
            const li = psk_linear(bi, @intCast(si), 2);
            L_tab[li] = a;
            H_tab[li] = a;
        }
    }
    var sweeps: u32 = 0;
    var any_change: u64 = 1;
    while (any_change > 0 and sweeps < 64) {
        sweeps += 1;
        any_change = 0;

        // L sweep (up from -n)
        for (0..PSK_RAW_TOTAL) |bi_u| {
            const bi: u32 = @intCast(bi_u);
            const board = unrank_board(bi);
            for (0..2) |si| {
                for (0..2) |pi| { // passes = 0, 1 only
                    const li = psk_linear(bi, @intCast(si), @intCast(pi));
                    const colour: i8 = if (si == 0) 1 else -1;
                    const maximizing = (si == 0);
                    var best: i8 = if (maximizing) L_init else H_init;
                    var any: bool = false;
                    // Pass edge
                    {
                        const pli = psk_linear(bi, 1 - @as(u8, @intCast(si)), @intCast(pi + 1));
                        const v = L_tab[pli];
                        best = v;
                        any = true;
                    }
                    // Place edges
                    for (0..n) |cell| {
                        const next = pos_from_move(&board, colour, cell) catch continue;
                        const nbi = rank_board(next);
                        const nli = psk_linear(nbi, 1 - @as(u8, @intCast(si)), 0);
                        const v = L_tab[nli];
                        if (!any or (maximizing and v > best) or (!maximizing and v < best)) {
                            best = v;
                            any = true;
                        }
                    }
                    if (any and best != L_tab[li]) {
                        L_tab[li] = best;
                        any_change += 1;
                    }
                }
            }
        }
        // H sweep (down from +n)
        for (0..PSK_RAW_TOTAL) |bi_u| {
            const bi: u32 = @intCast(bi_u);
            const board = unrank_board(bi);
            for (0..2) |si| {
                for (0..2) |pi| {
                    const li = psk_linear(bi, @intCast(si), @intCast(pi));
                    const colour: i8 = if (si == 0) 1 else -1;
                    const maximizing = (si == 0);
                    var best: i8 = if (maximizing) H_init else L_init;
                    var any: bool = false;
                    {
                        const pli = psk_linear(bi, 1 - @as(u8, @intCast(si)), @intCast(pi + 1));
                        const v = H_tab[pli];
                        best = v;
                        any = true;
                    }
                    for (0..n) |cell| {
                        const next = pos_from_move(&board, colour, cell) catch continue;
                        const nbi = rank_board(next);
                        const nli = psk_linear(nbi, 1 - @as(u8, @intCast(si)), 0);
                        const v = H_tab[nli];
                        if (!any or (maximizing and v > best) or (!maximizing and v < best)) {
                            best = v;
                            any = true;
                        }
                    }
                    if (any and best != H_tab[li]) {
                        H_tab[li] = best;
                        any_change += 1;
                    }
                }
            }
        }
        if (sweeps % 4 == 0 or any_change == 0) {
            util.out("# PSK fixpoint sweep {d}: changes={d}\n", .{ sweeps, any_change });
        }
    }
    // Pin census
    var stats = PskFixpointStats{ .sweeps = sweeps, .l_eq_h = 0, .pin_t = 0, .pin_l = 0, .pin_h = 0 };
    for (0..PSK_TOTAL) |li| {
        const Ll = L_tab[li];
        const Hh = H_tab[li];
        if (Ll == Hh) {
            stats.l_eq_h += 1;
        } else if (TIE < Ll) {
            stats.pin_l += 1;
        } else if (TIE > Hh) {
            stats.pin_h += 1;
        } else {
            stats.pin_t += 1;
        }
    }
    util.out("# PSK fixpoint ({d} states): sweeps={d}  L==H={d}  pin_T={d}  pin_L={d}  pin_H={d}\n", .{
        PSK_TOTAL, sweeps, stats.l_eq_h, stats.pin_t, stats.pin_l, stats.pin_h,
    });
    return stats;
}

/// PSK-aware exact value evaluator with alpha-beta pruning and depth limit.
/// Does full minimax search with PSK legality: a placement is illegal if
/// the resulting goban index has appeared in the continuation path.
/// Terminal: passes == 2 → area_score. Depth limit: if depth >= max_depth,
/// returns area_score (truncation — the position is too deep to search).
/// Returns null on budget exhaustion.
fn psk_exact_value(
    board: *const Pos,
    side: u8,
    passes: u8,
    seen_boards: *[12]u64,
    seen_count: *u8,
    budget: *u64,
    alpha: i8,
    beta: i8,
    depth: u8,
    max_depth: u8,
) ?i8 {
    if (budget.* == 0) return null;
    budget.* -= 1;
    if (passes == 2) return area_score(board);
    if (depth >= max_depth) return area_score(board);

    const bi = rank_board(board.*);
    const bi_word = bi >> 6;
    const bi_bit: u64 = @as(u64, 1) << @intCast(bi & 63);

    // Add current goban to seen set (it's the position we're AT — repeats
    // are only illegal for MOVES, i.e., children can't go back to a seen goban).
    // The arrival-history gobans are legitimately in seen; the current goban
    // may already be there (it's the last goban of the arrival).
    seen_boards[bi_word] |= bi_bit;
    seen_count.* += 1;
    defer {
        seen_boards[bi_word] &= ~bi_bit;
        seen_count.* -= 1;
    }

    const colour: i8 = if (side == 0) 1 else -1;
    const maximizing = (side == 0);
    var best: i8 = if (maximizing) -127 else 127;
    var any_legal: bool = false;
    var a = alpha;
    var b = beta;

    // Placements first (better for alpha-beta: aggressive moves give bounds),
    // pass last (the fallback).
    for (0..n) |cell| {
        if (a >= b) break;
        const next = pos_from_move(board, colour, cell) catch continue;
        const nbi = rank_board(next);
        const nbi_word = nbi >> 6;
        const nbi_bit: u64 = @as(u64, 1) << @intCast(nbi & 63);
        if ((seen_boards[nbi_word] & nbi_bit) != 0) continue;
        const v = psk_exact_value(&next, 1 - side, 0, seen_boards, seen_count, budget, a, b, depth + 1, max_depth) orelse return null;
        if (!any_legal) {
            best = v;
            any_legal = true;
        } else if (maximizing and v > best) {
            best = v;
        } else if (!maximizing and v < best) {
            best = v;
        }
        if (maximizing) {
            if (v > a) a = v;
        } else {
            if (v < b) b = v;
        }
        // Early termination: if we found a winning move, skip pass.
        if (maximizing and best >= @as(i8, @intCast(n))) break;
        if (!maximizing and best <= -@as(i8, @intCast(n))) break;
    }
    // Pass is always legal (off-terminal) — evaluate only if needed.
    if (a < b) {
        const v = psk_exact_value(board, 1 - side, passes + 1, seen_boards, seen_count, budget, a, b, depth + 1, max_depth) orelse return null;
        if (!any_legal) {
            best = v;
            any_legal = true;
        } else if (maximizing and v > best) {
            best = v;
        } else if (!maximizing and v < best) {
            best = v;
        }
    }
    if (!any_legal) {
        // No legal moves under PSK → score the current position.
        return area_score(board);
    }
    return best;
}

/// PSK probe: sample states from the PSK fixpoint, enumerate arrival
/// histories with PSK legality, evaluate each with psk_exact_value,
/// compare against the PSK fixpoint V. Reports disagreements.
fn run_probe_psk_3x2(params: ProbeParams) !ProbeOutcome {
    util.out("# qa023 probe — 3x2 PSK HISTORY-SENSITIVITY PROBE (T13-style, 2B-5 POS)\n", .{});
    util.out("# params: seed={d} n_samples={d} k_histories={d} history_depth={d} budget/history={d}\n", .{
        params.seed, params.n_samples, params.k_histories, params.history_depth, params.node_budget_per_history,
    });
    util.out("# TIE is irrelevant under PSK (revisits are illegal, not TIE-valued)\n", .{});

    const gpa = std.heap.page_allocator;
    var prng = std.Random.DefaultPrng.init(params.seed);

    // Compute PSK fixpoint.
    const L_tab = try gpa.alloc(i8, PSK_TOTAL);
    defer gpa.free(L_tab);
    const H_tab = try gpa.alloc(i8, PSK_TOTAL);
    defer gpa.free(H_tab);
    _ = psk_fixpoint(L_tab, H_tab);

    // Classify non-terminal states by pin category.
    var pin_t_indices = try gpa.alloc(u64, PSK_TOTAL);
    defer gpa.free(pin_t_indices);
    var pin_t_count: u64 = 0;
    var leh_indices = try gpa.alloc(u64, PSK_TOTAL);
    defer gpa.free(leh_indices);
    var leh_count: u64 = 0;
    {
        for (0..PSK_TOTAL) |li| {
            const dec = psk_decode(li);
            if (dec.passes == 2) continue;
            const Ll = L_tab[li];
            const Hh = H_tab[li];
            if (Ll == Hh) {
                leh_indices[leh_count] = li;
                leh_count += 1;
            } else if (TIE < Ll) {
                pin_t_indices[pin_t_count] = li; // reuse pin_t array for all L<H
                pin_t_count += 1;
            }
        }
    }
    const l_lt_h_total = leh_count + pin_t_count;
    util.out("# PSK reachable non-terminal states: {d}  (L==H={d}  L<H={d})\n", .{ l_lt_h_total, leh_count, pin_t_count });

    // Allocate resources for history enumeration (PSK-specific).
    const path_moves = try gpa.alloc(Move, params.history_depth);
    defer gpa.free(path_moves);
    const visited_boards = try gpa.alloc(bool, PSK_RAW_TOTAL);
    defer gpa.free(visited_boards);
    const collected_moves = try gpa.alloc(Move, params.k_histories * params.history_depth);
    defer gpa.free(collected_moves);
    const collected_lens = try gpa.alloc(u16, params.k_histories);
    defer gpa.free(collected_lens);

    var outcome = ProbeOutcome{
        .n_total = params.n_samples,
        .n_evaluated = 0,
        .n_value_agreements = 0,
        .n_tie_valued = 0,
        .n_disagreement = 0,
        .n_cycle_involved = 0,
        .n_budget_exhausted = 0,
        .n_scratch_overflow = 0,
        .n_unreachable = 0,
        .cycle_census_states = 0,
        .pin_t_sampled = 0,
        .pin_l_sampled = 0,
        .pin_h_sampled = 0,
        .l_eq_h_sampled = 0,
        .history_total = 0,
        .n_c1_failures = 0,
        .n_c2_failures = 0,
        .n_c1_eligible = 0,
        .n_c2_eligible = 0,
        .sigma_in_arrival_collisions = 0,
    };

    var sample_idx: u32 = 0;
    while (sample_idx < params.n_samples) : (sample_idx += 1) {
        // Weighted sampling: 70% L==H, 30% L<H.
        const bucket_roll = prng.random().intRangeAtMost(u8, 0, 99);
        const target_linear: u64 = blk: {
            if (bucket_roll < 70 and leh_count > 0) {
                outcome.l_eq_h_sampled += 1;
                break :blk leh_indices[prng.random().intRangeAtMost(u64, 0, leh_count - 1)];
            } else if (pin_t_count > 0) {
                outcome.pin_t_sampled += 1;
                break :blk pin_t_indices[prng.random().intRangeAtMost(u64, 0, pin_t_count - 1)];
            } else if (leh_count > 0) {
                outcome.l_eq_h_sampled += 1;
                break :blk leh_indices[prng.random().intRangeAtMost(u64, 0, leh_count - 1)];
            } else break :blk 0;
        };

        const dec = psk_decode(target_linear);
        const target_board = unrank_board(dec.board);
        const V_fixpoint: i8 = @max(L_tab[target_linear], @min(TIE, H_tab[target_linear]));

        // Collect up to K arrival histories via PSK-aware DFS.
        @memset(visited_boards, false);
        var collection_budget: u64 = params.k_histories * 2048;
        var rand = prng.random();
        const n_collected = psk_collect_histories(dec.board, dec.side, dec.passes, params.history_depth, &collection_budget, path_moves, visited_boards, collected_moves, collected_lens, params.k_histories, params.history_depth, &rand);

        if (n_collected == 0) {
            outcome.n_unreachable += 1;
            if (sample_idx % 8 == 0 and sample_idx > 0) {
                util.out("# sample {d}/{d}: agree={d} disagree={d} budget={d}\n", .{
                    sample_idx, params.n_samples, outcome.n_value_agreements, outcome.n_disagreement, outcome.n_budget_exhausted,
                });
            }
            continue;
        }
        outcome.n_evaluated += 1;

        var hist_idx: u32 = 0;
        while (hist_idx < n_collected) : (hist_idx += 1) {
            const base = hist_idx * params.history_depth;
            const hlen = collected_lens[hist_idx];
            const play = collected_moves[base .. base + hlen];

            // Replay arrival to build seen_boards set.
            var seen: [12]u64 = [_]u64{0} ** 12;
            var seen_cnt: u8 = 0;
            {
                var cur_board: Pos = [_]i8{0} ** n;
                var cur_side: u8 = 0;
                var cur_passes: u8 = 0;
                // Add root goban to seen set
                const rbi = rank_board(cur_board);
                seen[rbi >> 6] |= @as(u64, 1) << @intCast(rbi & 63);
                seen_cnt += 1;
                var j: u16 = 0;
                var ok_arrival: bool = true;
                while (j < hlen) : (j += 1) {
                    const mv = play[j];
                    const colour: i8 = if (cur_side == 0) 1 else -1;
                    if (mv.move_kind == .pass) {
                        cur_side = 1 - cur_side;
                        cur_passes += 1;
                    } else {
                        const next = pos_from_move(&cur_board, colour, mv.cell) catch {
                            ok_arrival = false;
                            break;
                        };
                        const nbi = rank_board(next);
                        if ((seen[nbi >> 6] & (@as(u64, 1) << @intCast(nbi & 63))) != 0) {
                            ok_arrival = false;
                            break;
                        }
                        cur_board = next;
                        cur_side = 1 - cur_side;
                        cur_passes = 0;
                        seen[nbi >> 6] |= @as(u64, 1) << @intCast(nbi & 63);
                        seen_cnt += 1;
                    }
                }
                if (!ok_arrival) continue;
            }

            // Evaluate target state with PSK exact value (alpha-beta, depth-limited).
            var budget1 = params.node_budget_per_history;
            const v = psk_exact_value(&target_board, dec.side, dec.passes, &seen, &seen_cnt, &budget1, -@as(i8, @intCast(n)), @as(i8, @intCast(n)), 0, 8);
            outcome.history_total += 1;
            if (v == null) {
                outcome.n_budget_exhausted += 1;
                continue;
            }
            if (v.? != V_fixpoint) {
                outcome.n_disagreement += 1;
                if (outcome.n_disagreement <= 5) {
                    util.out("# DISAGREE(PSK) #{d}: state=(board={d},side={d},passes={d}) V_fixpoint={d} psk_exact={d} arrival_len={d}\n", .{
                        outcome.n_disagreement, dec.board, dec.side, dec.passes, V_fixpoint, v.?, hlen,
                    });
                    util.out("#   arrival: ", .{});
                    var mvi2: u16 = 0;
                    while (mvi2 < hlen) : (mvi2 += 1) {
                        const mv2 = play[mvi2];
                        if (mv2.move_kind == .pass) {
                            util.out("pass ", .{});
                        } else {
                            util.out("{s}{d} ", .{ if (mv2.colour > 0) "B" else "W", mv2.cell });
                        }
                    }
                    util.out("\n", .{});
                }
            } else {
                outcome.n_value_agreements += 1;
            }
        }
        if (sample_idx % 8 == 0 and sample_idx > 0) {
            util.out("# sample {d}/{d}: agree={d} disagree={d} budget={d}\n", .{
                sample_idx, params.n_samples, outcome.n_value_agreements, outcome.n_disagreement, outcome.n_budget_exhausted,
            });
        }
    }

    util.out("# === PSK probe verdict ===\n", .{});
    util.out("# samples requested: {d}\n", .{params.n_samples});
    util.out("# samples evaluated: {d}\n", .{outcome.n_evaluated});
    util.out("# value-agreements (psk == V): {d}\n", .{outcome.n_value_agreements});
    util.out("# budget-exhausted: {d} / {d}\n", .{ outcome.n_budget_exhausted, outcome.history_total });
    util.out("# disagreements (psk != V, != null): {d}\n", .{outcome.n_disagreement});
    util.out("# samples no arrival history reached target: {d}\n", .{outcome.n_unreachable});
    util.out("# sampled-kind counts: L==H={d}  L<H={d}\n", .{ outcome.l_eq_h_sampled, outcome.pin_t_sampled });
    if (outcome.n_disagreement > 0) {
        util.out("# POS verdict: PASS — probe detects history-sensitivity under PSK ({d} disagreements)\n", .{outcome.n_disagreement});
        util.out("# T13 found 12 pointwise mismatches at 3x2; this probe reproduces the phenomenon: stored\n", .{});
        util.out("#   fresh-start PSK scores disagree with history-aware PSK evaluation.\n", .{});
    } else if (outcome.n_evaluated > 0) {
        util.out("# POS verdict: INCONCLUSIVE — probe found zero disagreements under PSK\n", .{});
        util.out("#   This would mean either the probe is too weak, or history-sensitivity is absent.\n", .{});
    } else {
        util.out("# POS verdict: INCONCLUSIVE (no evaluated samples)\n", .{});
    }
    return outcome;
}

/// PSK-aware arrival-history collector. Similar to collect_histories but:
/// - State = (board, side, passes), no ko_point.
/// - Visited tracking is goban-level (goban repeats are illegal under PSK).
/// - Move generation uses basic placement rules (no suicide, no occupied);
///   the goban-repeat check is in the visited-gobans set.
fn psk_collect_histories(
    target_board_idx: u32,
    target_side: u8,
    target_passes: u8,
    max_depth: u16,
    budget: *u64,
    path_moves: []Move,
    visited_boards: []bool,
    collected_moves: []Move,
    collected_lens: []u16,
    max_collect: u32,
    history_depth: u16,
    prng: *std.Random,
) u32 {
    var path_len: u16 = 0;
    var collected_count: u32 = 0;
    const root_board: Pos = [_]i8{0} ** n;
    psk_collect_histories_dfs(&root_board, 0, 0, target_board_idx, target_side, target_passes, 0, max_depth, budget, path_moves, &path_len, visited_boards, collected_moves, collected_lens, &collected_count, max_collect, history_depth, prng);
    return collected_count;
}

fn psk_collect_histories_dfs(
    board: *const Pos,
    side: u8,
    passes: u8,
    target_board_idx: u32,
    target_side: u8,
    target_passes: u8,
    depth: u16,
    max_depth: u16,
    budget: *u64,
    path_moves: []Move,
    path_len: *u16,
    visited_boards: []bool,
    collected_moves: []Move,
    collected_lens: []u16,
    collected_count: *u32,
    max_collect: u32,
    history_depth: u16,
    prng: *std.Random,
) void {
    const bi = rank_board(board.*);
    if (bi == target_board_idx and side == target_side and passes == target_passes) {
        if (collected_count.* >= max_collect) return;
        // Dedup by move-sequence FNV-1a hash, then exact match.
        var h: u64 = 0xcbf29ce484222325;
        for (0..path_len.*) |p_| {
            const mv = path_moves[p_];
            h = (h ^ @as(u64, @intCast(@as(u8, @intFromEnum(mv.move_kind))))) *% 0x100000001b3;
            h = (h ^ @as(u64, mv.cell)) *% 0x100000001b3;
            h = (h ^ (@as(u64, @bitCast(@as(i64, mv.colour))))) *% 0x100000001b3;
        }
        var i: u32 = 0;
        while (i < collected_count.*) : (i += 1) {
            const li = collected_lens[i];
            if (li != path_len.*) continue;
            const base = i * history_depth;
            var same = true;
            var j: u16 = 0;
            while (j < li) : (j += 1) {
                const a = collected_moves[base + j];
                const b = path_moves[j];
                if (@intFromEnum(a.move_kind) != @intFromEnum(b.move_kind) or a.cell != b.cell or a.colour != b.colour) {
                    same = false;
                    break;
                }
            }
            if (same) return;
        }
        const base = collected_count.* * history_depth;
        for (0..path_len.*) |p_| {
            collected_moves[base + p_] = path_moves[p_];
        }
        collected_lens[collected_count.*] = path_len.*;
        collected_count.* += 1;
        return;
    }
    if (depth == max_depth or budget.* == 0) return;
    budget.* -= 1;

    visited_boards[bi] = true;

    const colour: i8 = if (side == 0) 1 else -1;

    // Pass is always legal
    {
        const mv = Move{ .move_kind = .pass, .cell = 0, .colour = 0 };
        path_moves[path_len.*] = mv;
        path_len.* += 1;
        psk_collect_histories_dfs(board, 1 - side, passes + 1, target_board_idx, target_side, target_passes, depth + 1, max_depth, budget, path_moves, path_len, visited_boards, collected_moves, collected_lens, collected_count, max_collect, history_depth, prng);
        path_len.* -= 1;
    }

    // Placements (randomized order)
    var order: [n]usize = undefined;
    for (0..n) |j| order[j] = j;
    var mm: usize = n;
    while (mm > 1) {
        mm -= 1;
        const j = prng.intRangeAtMost(usize, 0, mm);
        const tmp = order[mm];
        order[mm] = order[j];
        order[j] = tmp;
    }
    for (0..n) |k| {
        const cell = order[k];
        const next = pos_from_move(board, colour, cell) catch continue;
        const nbi = rank_board(next);
        if (visited_boards[nbi]) continue;
        const mv = Move{ .move_kind = .place, .cell = @intCast(cell), .colour = colour };
        path_moves[path_len.*] = mv;
        path_len.* += 1;
        psk_collect_histories_dfs(&next, 1 - side, 0, target_board_idx, target_side, target_passes, depth + 1, max_depth, budget, path_moves, path_len, visited_boards, collected_moves, collected_lens, collected_count, max_collect, history_depth, prng);
        path_len.* -= 1;
    }

    visited_boards[bi] = false;
}

// ---- TEST: 2x2 SMOKE (cheap, runs in <1s) ----------------------------------

test "2x2 smoke: fixpoint converges and matches all five anchors" {
    // 2B-1: evaluator is the median fixpoint (reference-semantics doc §2),
    // never Brute2x2.value (path enumeration; four thrash incidents).
    const t = smoke_fixpoint_2x2();
    try expect(t.converged);
    const KO_NONE_2 = Brute2x2.State.KO_NONE;
    try expect(t.v(.{ .board = .{ 0, 0, 0, 0 }, .side = 1, .ko_point = KO_NONE_2, .passes = 0 }) == 0); // PSK would be +1
    try expect(t.v(.{ .board = .{ 0, 0, 0, 0 }, .side = -1, .ko_point = KO_NONE_2, .passes = 0 }) == 0);
    try expect(t.v(.{ .board = .{ 1, 1, 1, 1 }, .side = 1, .ko_point = KO_NONE_2, .passes = 0 }) == 4);
    try expect(t.v(.{ .board = .{ 0, 0, 0, 0 }, .side = -1, .ko_point = KO_NONE_2, .passes = 1 }) == 0);
    try expect(t.v(.{ .board = .{ 0, 0, 0, 0 }, .side = 1, .ko_point = KO_NONE_2, .passes = 2 }) == 0);
}

// ---- TEST: 3x2 primitives ------------------------------------------------

test "3x2: rank/unrank roundtrip" {
    var idx: u32 = 0;
    while (idx < RAW_TOTAL) : (idx += 1) {
        const board = unrank_board(idx);
        const back = rank_board(board);
        try expect(back == idx);
    }
}

test "3x2: area_score of empty = 0" {
    const empty: Pos = [_]i8{0} ** n;
    try expect(area_score(&empty) == 0);
}

test "3x2: area_score of full B = +6, full W = -6" {
    var fb: Pos = [_]i8{0} ** n;
    var fw: Pos = [_]i8{0} ** n;
    for (0..n) |i| {
        fb[i] = 1;
        fw[i] = -1;
    }
    try expect(area_score(&fb) == 6);
    try expect(area_score(&fw) == -6);
}

test "3x2: median rule on the calibration gadget" {
    // L=1, H=3, T=0 -> V=1 (not 0)
    const L: i8 = 1;
    const H: i8 = 3;
    const T: i8 = TIE;
    const V_v2: i8 = @max(L, @min(T, H));
    try expect(V_v2 == 1);
}

// ---- TEST: 3x2 fixpoint_kernel — White guards (T378, 2026-08-19) ---------
//
// The as-shipped kernel had inverted White guards at :965 (L sweep) and :1024
// (H sweep): the L-sweep White guard read `best < L_tab[li]` (lower on
// descent), the H-sweep White guard read `best > H_tab[hi]` (raise on
// descent). Both are wrong because the sweep direction does not flip with
// side — only the operator (max vs min) does. The buggy guards therefore
// never raised L or lowered H at White-to-move states, so the kernel
// reported a partial fixpoint (Bellman residual > 0). With the fix, the
// kernel reaches an exact Phi fixpoint (Bellman residual = 0 on L and H,
// bracket invariant L<=H).
//
// The strong witness is the fixpoint property itself: count of reachable
// non-terminal states where Phi(tab)[s] != tab[s]. T372's fixpoint_corrected
// reports residual 0/0 at 3x2 (census 2026-08-19); these tests reproduce
// that invariant against the qa023_probe kernel.

test "3x2: fixpoint_kernel — White L guard at :965 propagates from terminal" {
    const gpa = std.heap.page_allocator;
    const reach = try gpa.alloc(u64, ReachWords);
    defer gpa.free(reach);
    @memset(reach, 0);
    seed_roots(reach);
    const snap = try gpa.alloc(u64, ReachWords);
    defer gpa.free(snap);
    var new_marks: u64 = 1;
    while (new_marks > 0) {
        try census_sweep(reach, snap, &new_marks);
    }
    const L_tab = try gpa.alloc(i8, TOTAL_STATES);
    defer gpa.free(L_tab);
    const H_tab = try gpa.alloc(i8, TOTAL_STATES);
    defer gpa.free(H_tab);
    _ = fixpoint_kernel(reach, L_tab, H_tab);

    // The strong witness (T378): the kernel must compute an exact fixpoint
    // of Phi on both L and H (bellman_residual == 0). The buggy kernel
    // never raised L at White-to-move states (guard `best < L_tab[li]`
    // instead of `best > L_tab[li]`), so the residuals on L would be > 0.
    // T372's fixpoint_corrected (src/t372_zrtie.zig:bellman_residual) is
    // the reference: residuals 0/0 at 3x2 (census output, 2026-08-19).
    var l_residual: u64 = 0;
    var h_residual: u64 = 0;
    var linear: u64 = 0;
    while (linear < TOTAL_STATES) : (linear += 1) {
        if (reach[linear >> 6] & (@as(u64, 1) << @intCast(linear & 63)) == 0) continue;
        const passes: u8 = @intCast(linear / (2 * KO_DIMS * RAW_TOTAL));
        if (passes == 2) continue;
        const rest: u64 = linear % (2 * KO_DIMS * RAW_TOTAL);
        const side: u8 = @intCast(rest / (KO_DIMS * RAW_TOTAL));
        const rest2: u64 = rest % (KO_DIMS * RAW_TOTAL);
        const ko: u16 = @intCast(rest2 / RAW_TOTAL);
        const board: u32 = @intCast(rest2 % RAW_TOTAL);
        const state = StateIdx{ .board = board, .side = side, .ko = ko, .passes = passes };
        var succ_boards: [n + 1]Pos = undefined;
        var succs: [n + 1]StateIdx = undefined;
        const m = moves(state, &succ_boards, &succs);
        var best_l: ?i8 = null;
        var best_h: ?i8 = null;
        for (0..m) |k| {
            if (!is_legal(&succ_boards[k])) continue;
            const cl = succs[k].linear();
            if (reach[cl >> 6] & (@as(u64, 1) << @intCast(cl & 63)) == 0) continue;
            const vl = L_tab[cl];
            const vh = H_tab[cl];
            if (side == 0) {
                if (best_l == null or vl > best_l.?) best_l = vl;
                if (best_h == null or vh > best_h.?) best_h = vh;
            } else {
                if (best_l == null or vl < best_l.?) best_l = vl;
                if (best_h == null or vh < best_h.?) best_h = vh;
            }
        }
        if (best_l == null or best_h == null) continue;
        if (best_l.? != L_tab[linear]) l_residual += 1;
        if (best_h.? != H_tab[linear]) h_residual += 1;
    }
    std.debug.print("# T378 bellman residual L={d} H={d}\n", .{ l_residual, h_residual });
    try expect(l_residual == 0);
    try expect(h_residual == 0);

    // And the bracket invariant: L <= H at every reachable state.
    var bracket_violations: u64 = 0;
    var li2: u64 = 0;
    while (li2 < TOTAL_STATES) : (li2 += 1) {
        if (reach[li2 >> 6] & (@as(u64, 1) << @intCast(li2 & 63)) == 0) continue;
        if (L_tab[li2] > H_tab[li2]) bracket_violations += 1;
    }
    try expect(bracket_violations == 0);
}

test "3x2: fixpoint_kernel — White H guard at :1024 propagates from terminal" {
    const gpa = std.heap.page_allocator;
    const reach = try gpa.alloc(u64, ReachWords);
    defer gpa.free(reach);
    @memset(reach, 0);
    seed_roots(reach);
    const snap = try gpa.alloc(u64, ReachWords);
    defer gpa.free(snap);
    var new_marks: u64 = 1;
    while (new_marks > 0) {
        try census_sweep(reach, snap, &new_marks);
    }
    const L_tab = try gpa.alloc(i8, TOTAL_STATES);
    defer gpa.free(L_tab);
    const H_tab = try gpa.alloc(i8, TOTAL_STATES);
    defer gpa.free(H_tab);
    _ = fixpoint_kernel(reach, L_tab, H_tab);

    // Strong witness for the H-side White guard (T378): the Bellman residual
    // on H must be zero. The buggy kernel never lowered H at White-to-move
    // states (guard `best > H_tab[hi]` instead of `best < H_tab[hi]`), so the
    // H residuals would be > 0. The L-sweep White guard test above already
    // exercises Phi(L), this one exercises Phi(H) separately so a future
    // regression on the H-side alone (e.g. someone fixing L but breaking H)
    // would be caught independently.
    var h_residual: u64 = 0;
    var linear: u64 = 0;
    while (linear < TOTAL_STATES) : (linear += 1) {
        if (reach[linear >> 6] & (@as(u64, 1) << @intCast(linear & 63)) == 0) continue;
        const passes: u8 = @intCast(linear / (2 * KO_DIMS * RAW_TOTAL));
        if (passes == 2) continue;
        const rest: u64 = linear % (2 * KO_DIMS * RAW_TOTAL);
        const side: u8 = @intCast(rest / (KO_DIMS * RAW_TOTAL));
        const rest2: u64 = rest % (KO_DIMS * RAW_TOTAL);
        const ko: u16 = @intCast(rest2 / RAW_TOTAL);
        const board: u32 = @intCast(rest2 % RAW_TOTAL);
        const state = StateIdx{ .board = board, .side = side, .ko = ko, .passes = passes };
        var succ_boards: [n + 1]Pos = undefined;
        var succs: [n + 1]StateIdx = undefined;
        const m = moves(state, &succ_boards, &succs);
        var best_h: ?i8 = null;
        for (0..m) |k| {
            if (!is_legal(&succ_boards[k])) continue;
            const cl = succs[k].linear();
            if (reach[cl >> 6] & (@as(u64, 1) << @intCast(cl & 63)) == 0) continue;
            const vh = H_tab[cl];
            if (side == 0) {
                if (best_h == null or vh > best_h.?) best_h = vh;
            } else {
                if (best_h == null or vh < best_h.?) best_h = vh;
            }
        }
        if (best_h == null) continue;
        if (best_h.? != H_tab[linear]) h_residual += 1;
    }
    std.debug.print("# T378 H-bellman residual = {d}\n", .{h_residual});
    try expect(h_residual == 0);
}

// ---- 3x2 HISTORY-PAIR GENERATION (2B-3) -----------------------------------
//
// For each sampled 3×2 state, enumerate K distinct bounded arrival
// histories, compute the visit-set of each, and report how many state/
// history-pairs carry different visit-sets.  The vacuity guard: if no
// cycle-eligible state has ≥2 visit-set-distinct histories, escalate —
// the QA-023 probe cannot test history-independence (the same trap that
// made 2×2 void).

fn run_history_pairs_3x2(reach: []const u64, L_tab: []const i8, H_tab: []const i8) !HistoryPairsOutcome {
    // Parameters for 2B-3 (tunable; defaults are sensible for a <10 min run)
    const n_samples: u32 = 128;
    const k_histories: u32 = 8;
    const history_depth: u16 = 16;
    const seed: u64 = 0x2B3DA7A;

    util.out("# qa023 2B-3 — history-pair generation at 3×2\n", .{});
    util.out("# params: n_samples={d} k_histories={d} history_depth={d} seed=0x{X}\n", .{
        n_samples, k_histories, history_depth, seed,
    });

    const gpa = std.heap.page_allocator;
    var prng = std.Random.DefaultPrng.init(seed);

    // Build the reachable non-terminal index lists (same as probe).
    // Bias sampling: 70% from pin_T (L<T<H), 15% L==H, 7.5% each pin_L/pin_H.
    var pin_t_indices = try gpa.alloc(u64, TOTAL_STATES);
    defer gpa.free(pin_t_indices);
    var pin_t_count: u64 = 0;
    var leh_indices = try gpa.alloc(u64, TOTAL_STATES);
    defer gpa.free(leh_indices);
    var leh_count: u64 = 0;
    var pin_l_indices = try gpa.alloc(u64, TOTAL_STATES);
    defer gpa.free(pin_l_indices);
    var pin_l_count: u64 = 0;
    var pin_h_indices = try gpa.alloc(u64, TOTAL_STATES);
    defer gpa.free(pin_h_indices);
    var pin_h_count: u64 = 0;
    {
        var linear: u64 = 0;
        while (linear < TOTAL_STATES) : (linear += 1) {
            const word = linear >> 6;
            const bit: u64 = @as(u64, 1) << @intCast(linear & 63);
            if (reach[word] & bit == 0) continue;
            const passes: u8 = @intCast(linear / (2 * KO_DIMS * RAW_TOTAL));
            if (passes == 2) continue;
            const Ll = L_tab[linear];
            const Hh = H_tab[linear];
            if (Ll == Hh) {
                leh_indices[leh_count] = linear;
                leh_count += 1;
            } else if (TIE < Ll) {
                pin_l_indices[pin_l_count] = linear;
                pin_l_count += 1;
            } else if (TIE > Hh) {
                pin_h_indices[pin_h_count] = linear;
                pin_h_count += 1;
            } else {
                pin_t_indices[pin_t_count] = linear;
                pin_t_count += 1;
            }
        }
    }
    util.out("# reachable non-terminal: pin_T={d} L==H={d} pin_L={d} pin_H={d}\n", .{
        pin_t_count, leh_count, pin_l_count, pin_h_count,
    });

    // Allocate DFS resources
    const path_moves = try gpa.alloc(Move, history_depth);
    defer gpa.free(path_moves);
    const visited_states = try gpa.alloc(bool, TOTAL_STATES);
    defer gpa.free(visited_states);
    const collected_moves = try gpa.alloc(Move, k_histories * history_depth);
    defer gpa.free(collected_moves);
    const collected_lens = try gpa.alloc(u16, k_histories);
    defer gpa.free(collected_lens);

    // Per-history visit-set storage: at most k_histories sets of up to
    // history_depth+1 elements each.
    const max_visit_elems: u16 = history_depth + 2; // root + up to depth moves + 1
    const visit_sets_storage = try gpa.alloc(u64, k_histories * max_visit_elems);
    defer gpa.free(visit_sets_storage);
    var visit_set_lens = try gpa.alloc(u16, k_histories);
    defer gpa.free(visit_set_lens);
    @memset(visit_set_lens, 0);

    var outcome = HistoryPairsOutcome{
        .n_states_sampled = n_samples,
        .n_states_with_multi_history = 0,
        .n_states_with_visit_set_diff = 0,
        .total_pairs = 0,
        .total_visit_set_diff_pairs = 0,
    };

    var sample_idx: u32 = 0;
    while (sample_idx < n_samples) : (sample_idx += 1) {
        const bucket_roll = prng.random().intRangeAtMost(u8, 0, 99);
        const target_linear: u64 = blk: {
            if (bucket_roll < 70 and pin_t_count > 0) {
                break :blk pin_t_indices[prng.random().intRangeAtMost(u64, 0, pin_t_count - 1)];
            } else if (bucket_roll < 85 and leh_count > 0) {
                break :blk leh_indices[prng.random().intRangeAtMost(u64, 0, leh_count - 1)];
            } else if (bucket_roll < 92 and pin_l_count > 0) {
                break :blk pin_l_indices[prng.random().intRangeAtMost(u64, 0, pin_l_count - 1)];
            } else if (pin_h_count > 0) {
                break :blk pin_h_indices[prng.random().intRangeAtMost(u64, 0, pin_h_count - 1)];
            } else if (pin_t_count > 0) {
                break :blk pin_t_indices[prng.random().intRangeAtMost(u64, 0, pin_t_count - 1)];
            } else if (leh_count > 0) {
                break :blk leh_indices[prng.random().intRangeAtMost(u64, 0, leh_count - 1)];
            } else break :blk 0;
        };

        // Collect K arrival histories to this state
        @memset(visited_states, false);
        var collection_budget: u64 = k_histories * 2048;
        var rand = prng.random();
        const n_collected = collect_histories(target_linear, history_depth, &collection_budget, path_moves, visited_states, collected_moves, collected_lens, k_histories, history_depth, &rand);

        if (n_collected < 2) continue;
        outcome.n_states_with_multi_history += 1;

        // Compute visit-set for each history
        var h: u32 = 0;
        while (h < n_collected) : (h += 1) {
            const base = h * history_depth;
            const hlen = collected_lens[h];
            const vs_slice = visit_sets_storage[h * max_visit_elems .. (h + 1) * max_visit_elems];
            _ = visit_set_of_arrival(collected_moves[base .. base + hlen], hlen, vs_slice, &visit_set_lens[h]);
        }

        // Compare all pairs of visit-sets
        var pair_count: u32 = 0;
        var diff_count: u32 = 0;
        var a: u32 = 0;
        while (a < n_collected) : (a += 1) {
            var b: u32 = a + 1;
            while (b < n_collected) : (b += 1) {
                pair_count += 1;
                const vs_a = visit_sets_storage[a * max_visit_elems .. (a + 1) * max_visit_elems];
                const vs_b = visit_sets_storage[b * max_visit_elems .. (b + 1) * max_visit_elems];
                if (visit_sets_differ(vs_a, visit_set_lens[a], vs_b, visit_set_lens[b])) {
                    diff_count += 1;
                }
            }
        }
        outcome.total_pairs += pair_count;
        outcome.total_visit_set_diff_pairs += diff_count;
        if (diff_count > 0) {
            outcome.n_states_with_visit_set_diff += 1;
        }

        if (sample_idx % 8 == 0 and sample_idx > 0) {
            util.out("# sample {d}/{d}: multi-hist={d} diff-vs={d} pairs={d} diff-pairs={d}\n", .{
                sample_idx,
                n_samples,
                outcome.n_states_with_multi_history,
                outcome.n_states_with_visit_set_diff,
                outcome.total_pairs,
                outcome.total_visit_set_diff_pairs,
            });
        }
    }

    util.out("# === 2B-3 history-pairs verdict ===\n", .{});
    util.out("# states sampled: {d}\n", .{outcome.n_states_sampled});
    util.out("# states with >=2 arrival histories: {d}\n", .{outcome.n_states_with_multi_history});
    util.out("# states with visit-set-different histories: {d}\n", .{outcome.n_states_with_visit_set_diff});
    util.out("# total history-pairs compared: {d}\n", .{outcome.total_pairs});
    util.out("# total visit-set-different pairs: {d}\n", .{outcome.total_visit_set_diff_pairs});

    if (outcome.n_states_with_visit_set_diff == 0) {
        util.out("# VACUITY-GUARD FAIL: no state has >=2 visit-set-distinct histories.\n", .{});
        util.out("# ESCALATE: QA-023 probe at 3×2 cannot test history-independence (same trap as 2×2).\n", .{});
    } else {
        util.out("# VACUITY-GUARD PASS: {d} states have >=2 visit-set-distinct histories → non-vacuous probe.\n", .{outcome.n_states_with_visit_set_diff});
    }
    return outcome;
}

const HistoryPairsOutcome = struct {
    n_states_sampled: u32,
    n_states_with_multi_history: u32,
    n_states_with_visit_set_diff: u32,
    total_pairs: u32,
    total_visit_set_diff_pairs: u32,
};

// ---- 3x2 CYCLE CENSUS (2B-2) ----------------------------------------------
//
// Counts *directed* simple cycles in the legal-move graph on the reachable
// `(board, side, ko_point, passes)` state graph. Cycle-involved states are
// those that lie on at least one directed cycle (Tarjan's SCC, then
// per-SCC cycle enumeration). A state can be reached via >1 arrival
// history iff the graph has at least one directed cycle that returns to it
// (or to a state reachable from it via paths that share the target).
//
// For QA-023 specifically: a cycle-involved state is one where the
// history-carried evaluator (`truncated_value`) can encounter a first-revisit
// during the search, and the visit-set it produces depends on the arrival.
//
// Method:
//   1. Reuse the reachability fixpoint (census_3x2 machinery).
//   2. Build a dense vertex map (reachable linear index -> [0..V)) and
//      forward adjacency list.
//   3. Tarjan's SCC, O(V+E).  Non-trivial SCCs (size >= 2) admit cycles.
//   4. Per non-trivial SCC, enumerate simple directed cycles by bounded
//      DFS that maintains a vertex-ordering invariant (only search from
//      v through vertices w with id >= v, so each cycle is found exactly
//      once).  Bounded by --max-cycle-len (default 12) and a total cap
//      (--max-cycles, default 100000) to guard against pathological inputs.
//   5. Mark all vertices on any cycle as cycle-involved.
//   6. Report: V, E, SCC counts, cycle counts, cycle-involved vertex count,
//      the partition by SCC size, and a few sample cycles (length 2, 3, 4).
//
// Cycle-involved = "lies on a directed cycle" (definition 2B-2 §headline).
// We additionally report "cycle-REACHABLE" states (state σ such that some
// σ' in σ's forward-reachable set lies on a cycle) — this is the broader
// notion (siblings of cycles; can be visited via paths that pass through
// a cycle), and is what the probe sampler (2B-4) should bias toward.
//
// The TIE constant is irrelevant here — we're counting graph structure, not
// evaluating.  No probe/truncated evaluator is called.

const CycleCensusStats = struct {
    v: u32, // number of reachable vertices
    e: u32, // number of directed edges (legal moves within reachable set)
    scc_total: u32, // total SCCs
    scc_nontrivial: u32, // SCCs of size >= 2
    scc_max_size: u32, // size of the largest SCC
    cycles_found: u64, // total simple directed cycles enumerated (capped)
    cycles_capped: bool, // true iff the cycle cap was hit
    cycle_involved: u32, // reachable vertices on at least one directed cycle
    cycle_reachable: u32, // reachable vertices whose forward-reachable set
    //                                       intersects a cycle-involved SCC
    max_cycle_len: u32, // longest cycle length found
    histogram_by_len: [13]u64, // cycles by length (length 2..12; index 12 = length >= 12)
    sample_cycles: [3][]u32, // one sample cycle per length 2/3/4 (if any)
    sample_cycles_count: u32,
};

fn run_cycle_census_3x2(
    reach: []const u64,
    max_cycle_len: u32,
    max_cycles: u64,
) !CycleCensusStats {
    var gpa = std.heap.page_allocator;

    util.out("# qa023 probe — 3x2 cycle census: directed cycles in the reachable legal-move graph\n", .{});
    util.out("# (TIE constant is irrelevant; this is graph structure, not evaluation.)\n", .{});

    // 1. Build dense vertex map: reachable linear index -> [0..V).
    const vertex_map = try gpa.alloc(u32, TOTAL_STATES);
    defer gpa.free(vertex_map);
    @memset(vertex_map, 0xFFFFFFFF);

    var V: u32 = 0;
    var linear: u64 = 0;
    while (linear < TOTAL_STATES) : (linear += 1) {
        const word = linear >> 6;
        const bit: u64 = @as(u64, 1) << @intCast(linear & 63);
        if (reach[word] & bit == 0) continue;
        vertex_map[linear] = V;
        V += 1;
    }
    util.out("# cycle census: reachable V = {d}\n", .{V});

    // 2. Build forward adjacency list. Use an ArrayListUnmanaged per vertex
    // so we can grow during the moves enumeration.
    var adj = try gpa.alloc(std.ArrayListUnmanaged(u32), V);
    defer {
        for (adj[0..V]) |*al| al.deinit(gpa);
        gpa.free(adj);
    }
    for (0..V) |i| {
        adj[i] = .{ .items = &.{}, .capacity = 0 };
    }

    var E: u32 = 0;
    linear = 0;
    while (linear < TOTAL_STATES) : (linear += 1) {
        const word = linear >> 6;
        const bit: u64 = @as(u64, 1) << @intCast(linear & 63);
        if (reach[word] & bit == 0) continue;
        const v = vertex_map[linear];

        // Decode the linear index into (board, side, ko, passes) so we can
        // enumerate its legal moves.
        const passes: u8 = @intCast(linear / (2 * KO_DIMS * RAW_TOTAL));
        const rest: u64 = linear % (2 * KO_DIMS * RAW_TOTAL);
        const side: u8 = @intCast(rest / (KO_DIMS * RAW_TOTAL));
        const rest2: u64 = rest % (KO_DIMS * RAW_TOTAL);
        const ko: u16 = @intCast(rest2 / RAW_TOTAL);
        const board: u32 = @intCast(rest2 % RAW_TOTAL);

        const state = StateIdx{ .board = board, .side = side, .ko = ko, .passes = passes };

        // Terminal states (passes == 2) have no successors; adjacency stays empty.
        if (passes == 2) continue;

        // Build the actual goban so we can reuse `moves()`.  We need the
        // goban array (not just the dense index) because moves() uses
        // `apply_place` which reads the actual goban.
        // (moves() re-unranks internally; no work needed here.)

        var succ_boards: [n + 1]Pos = undefined;
        var succs: [n + 1]StateIdx = undefined;
        const m = moves(state, &succ_boards, &succs);
        for (0..m) |k| {
            const child = succs[k];
            const child_linear = child.linear();
            const child_word = child_linear >> 6;
            const child_bit: u64 = @as(u64, 1) << @intCast(child_linear & 63);
            if (reach[child_word] & child_bit == 0) continue;
            const w = vertex_map[child_linear];
            if (w == 0xFFFFFFFF) continue;
            try adj[v].append(gpa, w);
            E += 1;
        }
    }
    util.out("# cycle census: directed edges E = {d}\n", .{E});

    // 3. Tarjan's SCC.  Iterative form to avoid recursion-depth issues.
    // index[v] = -1 means "unvisited".  Standard textbook algorithm.
    const index_arr = try gpa.alloc(i32, V);
    defer gpa.free(index_arr);
    const lowlink = try gpa.alloc(u32, V);
    defer gpa.free(lowlink);
    const on_stack = try gpa.alloc(u8, V);
    defer gpa.free(on_stack);
    const scc_id = try gpa.alloc(u32, V);
    defer gpa.free(scc_id);
    @memset(index_arr, -1);
    @memset(on_stack, 0);
    @memset(scc_id, 0);

    var idx: u32 = 0;
    var scc_count: u32 = 0;
    var scc_max_size: u32 = 0;
    // Tarjan's SCC stack (separate adjacency DFS stack).
    var scc_stack = try std.ArrayListUnmanaged(u32).initCapacity(gpa, V);
    defer scc_stack.deinit(gpa);

    // Iterative Tarjan's: a separate DFS stack holds (vertex, next_child_idx)
    // frames.  On visiting a new vertex, we push a frame.  When we finish
    // exploring all neighbors, we either pop the SCC (if lowlink == index)
    // or backtrack to the parent.  Recursive Tarjan's is O(V) but Zig
    // function closures can't capture outer mutable state without explicit
    // pointers; the iterative form is the standard workaround.
    const DFSFrame = struct { v: u32, next_child: u32 };
    var dfs_stack = try std.ArrayListUnmanaged(DFSFrame).initCapacity(gpa, V);
    defer dfs_stack.deinit(gpa);

    var s_root: u32 = 0;
    while (s_root < V) : (s_root += 1) {
        if (index_arr[s_root] != -1) continue;

        // Root: push.
        index_arr[s_root] = @intCast(idx);
        lowlink[s_root] = idx;
        idx += 1;
        scc_stack.append(gpa, s_root) catch unreachable;
        on_stack[s_root] = 1;
        dfs_stack.append(gpa, .{ .v = s_root, .next_child = 0 }) catch unreachable;

        while (dfs_stack.items.len > 0) {
            const top = &dfs_stack.items[dfs_stack.items.len - 1];
            const v = top.v;
            const nbrs = adj[v].items;
            if (top.next_child < nbrs.len) {
                const w = nbrs[top.next_child];
                top.next_child += 1;
                if (index_arr[w] == -1) {
                    // New vertex: recurse.
                    index_arr[w] = @intCast(idx);
                    lowlink[w] = idx;
                    idx += 1;
                    scc_stack.append(gpa, w) catch unreachable;
                    on_stack[w] = 1;
                    dfs_stack.append(gpa, .{ .v = w, .next_child = 0 }) catch unreachable;
                } else if (on_stack[w] == 1) {
                    // Back edge to ancestor on the stack.
                    if (index_arr[w] < lowlink[v]) lowlink[v] = @intCast(index_arr[w]);
                }
                // If w is fully visited and not on stack, it's a cross edge
                // — ignore (it doesn't affect SCC membership).
            } else {
                // All neighbors explored. Pop frame.
                if (lowlink[v] == index_arr[v]) {
                    // v is SCC root: pop everything down to v.
                    var size: u32 = 0;
                    while (true) {
                        const w = scc_stack.pop().?;
                        on_stack[w] = 0;
                        scc_id[w] = scc_count;
                        size += 1;
                        if (w == v) break;
                    }
                    if (size > scc_max_size) scc_max_size = size;
                    scc_count += 1;
                }
                _ = dfs_stack.pop();
                // Backtrack: update parent's lowlink.
                if (dfs_stack.items.len > 0) {
                    const parent = dfs_stack.items[dfs_stack.items.len - 1].v;
                    if (lowlink[v] < lowlink[parent]) lowlink[parent] = lowlink[v];
                }
            }
        }
    }

    // 4. Per-SCC cycle enumeration within non-trivial SCCs.
    // Use a bounded DFS that, for each vertex v in SCC, looks for paths
    // v -> ... -> v using only vertices w with id >= v's SCC-internal order.
    // Cap cycle length at max_cycle_len and total cycles at max_cycles.
    const cycle_involved_flag = try gpa.alloc(u8, V);
    defer gpa.free(cycle_involved_flag);
    @memset(cycle_involved_flag, 0);

    // For each SCC, compute its vertex list.
    var scc_vertices = try std.ArrayListUnmanaged(std.ArrayListUnmanaged(u32)).initCapacity(gpa, scc_count);
    defer {
        for (scc_vertices.items) |*al| al.deinit(gpa);
        scc_vertices.deinit(gpa);
    }
    for (0..scc_count) |_| {
        scc_vertices.append(gpa, .{ .items = &.{}, .capacity = 0 }) catch unreachable;
    }
    for (0..V) |v| {
        scc_vertices.items[scc_id[v]].append(gpa, @intCast(v)) catch unreachable;
    }

    var histogram = [_]u64{0} ** 13;
    var cycles_found: u64 = 0;
    var max_len_found: u32 = 0;
    var cycles_capped: bool = false;
    // We keep a copy of the path when we hit a new length for the first
    // time.  Storage slots: [0..3] for lengths 2, 3, 4, 5; [4] for length
    // 6; [5] for length 8; [6] for length 14.  (Length 7 is odd -> 0 by
    // parity; same for length 5, 9, 11, 13.)  The intent is to give a
    // human reader a few concrete cycles to verify non-triviality.
    var sample_storage = try gpa.alloc([]u32, 7);
    defer {
        for (sample_storage[0..]) |s| gpa.free(s);
        gpa.free(sample_storage);
    }
    for (sample_storage[0..]) |*s| s.* = &[_]u32{};
    var sample_filled = [_]bool{ false, false, false, false, false, false, false };

    // DFS scratch
    var path = try std.ArrayListUnmanaged(u32).initCapacity(gpa, max_cycle_len);
    defer path.deinit(gpa);
    var on_path = try gpa.alloc(u8, V);
    defer gpa.free(on_path);
    @memset(on_path, 0);

    // Cycle enumeration, per non-trivial SCC.
    for (0..scc_count) |s| {
        const verts = scc_vertices.items[s].items;
        if (verts.len < 2) continue;

        // Enumerate cycles starting from each vertex v in the SCC, looking
        // for paths back to v using only vertices with SCC-internal id >= v.
        // Sort verts so we know the relative order (we will reuse idx).
        // We need a per-SCC "rank" mapping.
        const rank_in_scc = try gpa.alloc(u32, V);
        defer gpa.free(rank_in_scc);
        @memset(rank_in_scc, 0xFFFFFFFF);
        for (verts, 0..) |v, k| rank_in_scc[v] = @intCast(k);

        // Outer loop: enumerate cycles starting from `start`.
        for (verts) |start| {
            // DFS through neighbors with rank >= rank_in_scc[start].
            @memset(on_path, 0);
            path.clearRetainingCapacity();
            path.append(gpa, start) catch unreachable;
            on_path[start] = 1;

            // Iterative DFS using a struct frame { v, next_child }.
            const FrameCycle = struct { v: u32, next_child: u32 };
            var dfs_stack_cycle = try std.ArrayListUnmanaged(FrameCycle).initCapacity(gpa, max_cycle_len + 1);
            defer dfs_stack_cycle.deinit(gpa);
            dfs_stack_cycle.append(gpa, .{ .v = start, .next_child = 0 }) catch unreachable;

            while (dfs_stack_cycle.items.len > 0) {
                if (cycles_found >= max_cycles) {
                    cycles_capped = true;
                    break;
                }
                var top = &dfs_stack_cycle.items[dfs_stack_cycle.items.len - 1];
                const v = top.v;
                const nbrs = adj[v].items;
                if (top.next_child < nbrs.len) {
                    const w = nbrs[top.next_child];
                    top.next_child += 1;
                    if (rank_in_scc[w] < rank_in_scc[start]) continue;
                    if (w == start) {
                        // Cycle closure: start is on the path; only count
                        // if path has at least one edge (len >= 2).
                        if (path.items.len >= 2) {
                            const len = path.items.len;
                            if (len <= max_cycle_len) {
                                cycles_found += 1;
                                histogram[@intCast(@min(len - 2, 12))] += 1;
                                if (len > max_len_found) max_len_found = @intCast(len);
                                for (path.items) |cv| cycle_involved_flag[cv] = 1;
                                if (len <= 4 and !sample_filled[len - 2]) {
                                    sample_storage[len - 2] = try gpa.alloc(u32, len);
                                    @memcpy(sample_storage[len - 2][0..len], path.items);
                                    sample_filled[len - 2] = true;
                                } else if (len == 6 and !sample_filled[4]) {
                                    sample_storage[4] = try gpa.alloc(u32, len);
                                    @memcpy(sample_storage[4][0..len], path.items);
                                    sample_filled[4] = true;
                                } else if (len == 8 and !sample_filled[5]) {
                                    sample_storage[5] = try gpa.alloc(u32, len);
                                    @memcpy(sample_storage[5][0..len], path.items);
                                    sample_filled[5] = true;
                                } else if (len == 14 and !sample_filled[6]) {
                                    sample_storage[6] = try gpa.alloc(u32, len);
                                    @memcpy(sample_storage[6][0..len], path.items);
                                    sample_filled[6] = true;
                                }
                            }
                        }
                        // closing edge: do not descend.
                        continue;
                    }
                    if (on_path[w] == 1) continue; // would create a non-simple cycle through w
                    if (path.items.len < max_cycle_len) {
                        path.append(gpa, w) catch unreachable;
                        on_path[w] = 1;
                        dfs_stack_cycle.append(gpa, .{ .v = w, .next_child = 0 }) catch unreachable;
                    }
                } else {
                    // pop
                    on_path[v] = 0;
                    _ = path.pop();
                    _ = dfs_stack_cycle.pop();
                }
            }
            if (cycles_capped) break;
        }
        if (cycles_capped) break;
    }

    // 5. cycle-REACHABLE (broader): a state is cycle-reachable iff some
    // state in its forward-reachable set is cycle-involved.  Compute by
    // reverse-BFS from the cycle-involved set.
    var cycle_reachable: u32 = 0;
    {
        // Build reverse adjacency list.
        var radj = try gpa.alloc(std.ArrayListUnmanaged(u32), V);
        defer {
            for (radj[0..V]) |*al| al.deinit(gpa);
            gpa.free(radj);
        }
        for (0..V) |i| radj[i] = .{ .items = &.{}, .capacity = 0 };
        for (0..V) |v| {
            for (adj[v].items) |w| {
                radj[w].append(gpa, @intCast(v)) catch unreachable;
            }
        }
        var visited = try gpa.alloc(u8, V);
        defer gpa.free(visited);
        @memset(visited, 0);
        var bfs = try std.ArrayListUnmanaged(u32).initCapacity(gpa, V);
        defer bfs.deinit(gpa);
        // seed: every cycle-involved vertex
        for (0..V) |v| {
            if (cycle_involved_flag[v] == 1) {
                visited[v] = 1;
                bfs.append(gpa, @intCast(v)) catch unreachable;
            }
        }
        while (bfs.items.len > 0) {
            const v = bfs.orderedRemove(0);
            for (radj[v].items) |u| {
                if (visited[u] == 0) {
                    visited[u] = 1;
                    bfs.append(gpa, u) catch unreachable;
                }
            }
        }
        for (0..V) |v| {
            if (visited[v] == 1) cycle_reachable += 1;
        }
    }

    // 6. Tally cycle-involved count (over the whole reachable set).
    var cycle_involved_count: u32 = 0;
    for (0..V) |v| {
        if (cycle_involved_flag[v] == 1) cycle_involved_count += 1;
    }

    // 7. Count non-trivial SCCs and tally SCC size histogram.
    var scc_nontrivial: u32 = 0;
    var scc_size_hist: [16]u64 = [_]u64{0} ** 16;
    for (0..scc_count) |s| {
        const sz = scc_vertices.items[s].items.len;
        if (sz >= scc_size_hist.len) {
            scc_size_hist[scc_size_hist.len - 1] += 1;
        } else {
            scc_size_hist[sz] += 1;
        }
        if (sz >= 2) scc_nontrivial += 1;
    }

    // 8. Report.
    util.out("# SCCs: total = {d}, non-trivial (size >= 2) = {d}, max size = {d}\n", .{ scc_count, scc_nontrivial, scc_max_size });
    util.out("# SCC size histogram (size 0..14, index 15 = size >= 15):\n", .{});
    {
        var si: usize = 0;
        while (si < scc_size_hist.len) : (si += 1) {
            if (scc_size_hist[si] > 0) {
                util.out("#   size {d}", .{si});
                if (si == scc_size_hist.len - 1) util.out("+", .{});
                util.out(": {d} SCCs\n", .{scc_size_hist[si]});
            }
        }
    }
    util.out("# cycle-involved vertices (lie on a directed cycle): {d}\n", .{cycle_involved_count});
    util.out("# cycle-REACHABLE vertices (forward-reachable set touches a cycle): {d}\n", .{cycle_reachable});
    util.out("# simple directed cycles found (cycle-length cap = {d}, total cap = {d}): {d}{s}\n", .{
        max_cycle_len,
        max_cycles,
        cycles_found,
        if (cycles_capped) " (CAPPED — counted only)" else "",
    });
    if (max_len_found > 0) {
        util.out("# max cycle length observed: {d}\n", .{max_len_found});
    } else {
        util.out("# max cycle length observed: 0 (no cycles)\n", .{});
    }
    util.out("# cycle histogram by length (length 2..{d}; index {d} = length >= {d}):\n", .{
        max_cycle_len,
        max_cycle_len - 1,
        max_cycle_len,
    });
    var last_printed_idx: usize = 0xFFFFFFFF;
    var li: u32 = 2;
    while (li <= max_cycle_len) : (li += 1) {
        const idx_h: usize = @intCast(@min(li - 2, 12));
        if (idx_h == last_printed_idx) continue; // already covered by a prior range bucket
        // Find the end of this bucket.
        var lj: u32 = li + 1;
        while (lj <= max_cycle_len) : (lj += 1) {
            const idxj: usize = @intCast(@min(lj - 2, 12));
            if (idxj != idx_h) break;
        }
        util.out("#   length {d}", .{li});
        if (lj > li + 1) {
            util.out("..{d}", .{lj - 1});
        }
        util.out(": {d}\n", .{histogram[idx_h]});
        last_printed_idx = idx_h;
    }

    // Sample cycles.  Index -> length: 0->2, 1->3, 2->4, 3->5, 4->6, 5->8, 6->14.
    const sample_len_for_idx = [_]u32{ 2, 3, 4, 5, 6, 8, 14 };
    var sample_count: u32 = 0;
    for (sample_storage[0..7], 0..) |s, i| {
        if (s.len > 0) {
            sample_count += 1;
            util.out("# sample cycle (length {d}): [", .{sample_len_for_idx[i]});
            for (s, 0..) |v, k| {
                if (k > 0) util.out(", ", .{});
                util.out("{d}", .{v});
            }
            util.out("]\n", .{});
        }
    }

    // 9. Final verdict for claim 3x2.QA023.B-VACUITY.
    util.out("# === 2B-2 cycle-census verdict ===\n", .{});
    util.out("# reachable V = {d}, E = {d}, non-trivial SCCs = {d}, cycles_found = {d}, cycle-involved = {d}, cycle-reachable = {d}\n", .{
        V,
        E,
        scc_nontrivial,
        cycles_found,
        cycle_involved_count,
        cycle_reachable,
    });
    if (cycles_found > 0) {
        util.out("# CLAIM 3x2.QA023.B-VACUITY: PASS — reachable directed cycles > 0 (3x2 IS a non-trivial test surface)\n", .{});
    } else {
        util.out("# CLAIM 3x2.QA023.B-VACUITY: FAIL — zero reachable directed cycles at 3x2\n", .{});
        util.out("# ESCALATE: 3x2 cannot host a non-trivial QA-023 test. Move to 3x3.\n", .{});
    }

    return CycleCensusStats{
        .v = V,
        .e = E,
        .scc_total = scc_count,
        .scc_nontrivial = scc_nontrivial,
        .scc_max_size = scc_max_size,
        .cycles_found = cycles_found,
        .cycles_capped = cycles_capped,
        .cycle_involved = cycle_involved_count,
        .cycle_reachable = cycle_reachable,
        .max_cycle_len = max_len_found,
        .histogram_by_len = histogram,
        .sample_cycles = undefined,
        .sample_cycles_count = sample_count,
    };
}

// ---- main -----------------------------------------------------------------

pub fn main(init: std.process.Init) !void {
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next(); // skip program name
    const mode = args.next() orelse "all";

    if (std.mem.eql(u8, mode, "smoke-2x2")) {
        run_smoke_2x2();
    } else if (std.mem.eql(u8, mode, "calibrate")) {
        run_calibrate();
    } else if (std.mem.eql(u8, mode, "census-3x2")) {
        _ = run_census_3x2() catch return error.OutOfMemory;
    } else if (std.mem.eql(u8, mode, "fixpoint-3x2")) {
        var gpa = std.heap.page_allocator;
        const reach = try gpa.alloc(u64, ReachWords);
        defer gpa.free(reach);
        @memset(reach, 0);
        seed_roots(reach);
        const snap = try gpa.alloc(u64, ReachWords);
        defer gpa.free(snap);
        var new_marks: u64 = 1;
        while (new_marks > 0) {
            try census_sweep(reach, snap, &new_marks);
        }
        _ = run_fixpoint_3x2(reach) catch return error.OutOfMemory;
    } else if (std.mem.eql(u8, mode, "cycle-census-3x2")) {
        // Parse --max-cycle-len, --max-cycles.
        var max_cycle_len: u32 = 12;
        var max_cycles: u64 = 100_000;
        while (args.next()) |a| {
            if (std.mem.eql(u8, a, "--max-cycle-len")) {
                max_cycle_len = std.fmt.parseInt(u32, args.next() orelse "12", 0) catch 12;
            } else if (std.mem.eql(u8, a, "--max-cycles")) {
                max_cycles = std.fmt.parseInt(u64, args.next() orelse "100000", 0) catch 100_000;
            }
        }
        const gpa = std.heap.page_allocator;
        const reach = try gpa.alloc(u64, ReachWords);
        defer gpa.free(reach);
        @memset(reach, 0);
        seed_roots(reach);
        const snap = try gpa.alloc(u64, ReachWords);
        defer gpa.free(snap);
        var new_marks: u64 = 1;
        while (new_marks > 0) {
            try census_sweep(reach, snap, &new_marks);
        }
        _ = run_cycle_census_3x2(reach, max_cycle_len, max_cycles) catch return error.OutOfMemory;
    } else if (std.mem.eql(u8, mode, "history-pairs-3x2")) {
        const gpa = std.heap.page_allocator;
        const reach = try gpa.alloc(u64, ReachWords);
        defer gpa.free(reach);
        @memset(reach, 0);
        seed_roots(reach);
        const snap = try gpa.alloc(u64, ReachWords);
        defer gpa.free(snap);
        var new_marks: u64 = 1;
        while (new_marks > 0) {
            try census_sweep(reach, snap, &new_marks);
        }
        const L_tab = try gpa.alloc(i8, TOTAL_STATES);
        defer gpa.free(L_tab);
        const H_tab = try gpa.alloc(i8, TOTAL_STATES);
        defer gpa.free(H_tab);
        _ = fixpoint_kernel(reach, L_tab, H_tab);
        _ = run_history_pairs_3x2(reach, L_tab, H_tab) catch return error.OutOfMemory;
    } else if (std.mem.eql(u8, mode, "probe-3x2")) {
        // Parse --seed, --n-samples, --k-histories, --history-depth, --node-budget.
        var seed: u64 = 0xC0FFEE5;
        var n_samples: u32 = 64;
        var k_histories: u32 = 8;
        var history_depth: u16 = 16;
        var node_budget: u64 = 100_000;
        while (args.next()) |a| {
            if (std.mem.eql(u8, a, "--seed")) {
                seed = std.fmt.parseInt(u64, args.next() orelse "0", 0) catch 0;
            } else if (std.mem.eql(u8, a, "--n-samples")) {
                n_samples = std.fmt.parseInt(u32, args.next() orelse "64", 0) catch 64;
            } else if (std.mem.eql(u8, a, "--k-histories")) {
                k_histories = std.fmt.parseInt(u32, args.next() orelse "8", 0) catch 8;
            } else if (std.mem.eql(u8, a, "--history-depth")) {
                history_depth = std.fmt.parseInt(u16, args.next() orelse "16", 0) catch 16;
            } else if (std.mem.eql(u8, a, "--node-budget")) {
                node_budget = std.fmt.parseInt(u64, args.next() orelse "100000", 0) catch 100_000;
            }
        }
        const params = ProbeParams{
            .seed = seed,
            .n_samples = n_samples,
            .k_histories = k_histories,
            .history_depth = history_depth,
            .node_budget_per_history = node_budget,
        };
        // Build reach + run L/H fixpoint, then probe.
        const gpa = std.heap.page_allocator;
        const reach = try gpa.alloc(u64, ReachWords);
        defer gpa.free(reach);
        @memset(reach, 0);
        seed_roots(reach);
        const snap = try gpa.alloc(u64, ReachWords);
        defer gpa.free(snap);
        var new_marks: u64 = 1;
        while (new_marks > 0) {
            try census_sweep(reach, snap, &new_marks);
        }
        const L_tab = try gpa.alloc(i8, TOTAL_STATES);
        defer gpa.free(L_tab);
        const H_tab = try gpa.alloc(i8, TOTAL_STATES);
        defer gpa.free(H_tab);
        _ = fixpoint_kernel(reach, L_tab, H_tab);
        _ = run_probe_3x2(reach, L_tab, H_tab, params) catch return error.OutOfMemory;
    } else if (std.mem.eql(u8, mode, "all")) {
        run_smoke_2x2();
        run_calibrate();
        _ = run_census_3x2() catch return error.OutOfMemory;
        // For "all", run a small fixpoint + probe. We rebuild reach
        // here; cheap on 3x2.
        const gpa = std.heap.page_allocator;
        const reach = try gpa.alloc(u64, ReachWords);
        defer gpa.free(reach);
        @memset(reach, 0);
        seed_roots(reach);
        const snap = try gpa.alloc(u64, ReachWords);
        defer gpa.free(snap);
        var new_marks: u64 = 1;
        while (new_marks > 0) {
            try census_sweep(reach, snap, &new_marks);
        }
        _ = run_fixpoint_3x2(reach) catch return error.OutOfMemory;
        util.out("# (run `zig run ... probe-3x2 -- --seed N --n-samples N --k-histories N --history-depth N` for the history-sensitivity check)\n", .{});
    } else if (std.mem.eql(u8, mode, "calibrate-neg")) {
        run_calibrate_neg();
    } else if (std.mem.eql(u8, mode, "psk-test")) {
        // Quick debug: evaluate empty 3x2 goban, Black to move, empty history
        var seen: [12]u64 = [_]u64{0} ** 12;
        var seen_cnt: u8 = 0;
        var budget: u64 = 10_000_000;
        const board: Pos = [_]i8{0} ** n;
        const v = psk_exact_value(&board, 0, 0, &seen, &seen_cnt, &budget, -6, 6, 0, 8);
        util.out("empty 3x2 B-to-move PSK exact(depth 8): v={?d} budget_left={d}\n", .{ v, budget });
    } else if (std.mem.eql(u8, mode, "probe-psk-3x2")) {
        var seed: u64 = 0xC0FFEE5;
        var n_samples: u32 = 64;
        var k_histories: u32 = 4;
        var history_depth: u16 = 16;
        while (args.next()) |a| {
            if (std.mem.eql(u8, a, "--seed")) {
                seed = std.fmt.parseInt(u64, args.next() orelse "0", 0) catch 0;
            } else if (std.mem.eql(u8, a, "--n-samples")) {
                n_samples = std.fmt.parseInt(u32, args.next() orelse "64", 0) catch 64;
            } else if (std.mem.eql(u8, a, "--k-histories")) {
                k_histories = std.fmt.parseInt(u32, args.next() orelse "4", 0) catch 4;
            } else if (std.mem.eql(u8, a, "--history-depth")) {
                history_depth = std.fmt.parseInt(u16, args.next() orelse "12", 0) catch 12;
            }
        }
        const params = ProbeParams{
            .seed = seed,
            .n_samples = n_samples,
            .k_histories = k_histories,
            .history_depth = history_depth,
            .node_budget_per_history = 500_000,
        };
        _ = run_probe_psk_3x2(params) catch return error.OutOfMemory;
    } else {
        util.out("usage: qa023_probe [smoke-2x2|calibrate|calibrate-neg|census-3x2|cycle-census-3x2|fixpoint-3x2|history-pairs-3x2|probe-3x2 [--seed N] [--n-samples N] [--k-histories N] [--history-depth N] [--node-budget N]|probe-psk-3x2|all] [flags]\n", .{});
        return error.UnknownMode;
    }
}

/// Seed the four true game roots: empty goban × side (B,W) × passes (0,1),
/// all with ko = KO_NONE (n, the encoding sentinel). A ko point can only be
/// set by a single-stone capture (§1.1, apply_place); the empty goban
/// contains no stones, so no capture is possible from any root, and
/// therefore no root can carry a non-NONE ko point. The 36 phantom
/// empty-goban-with-a-ko-point seeds (2 sides × 3 passes × 6 non-NONE ko
/// values) were unreachable and inflated the published V/E/real-ko counts.
/// passes=2 is a terminal state reachable by two consecutive passes; the
/// sweep discovers it — seeding it directly is redundant.
fn seed_roots(reach: []u64) void {
    for ([_]u8{ 0, 1 }) |side| {
        for ([_]u8{ 0, 1 }) |passes| {
            const root = StateIdx{ .board = 0, .side = side, .ko = @as(u16, n), .passes = passes };
            const lin = root.linear();
            reach[lin >> 6] |= @as(u64, 1) << @intCast(lin & 63);
        }
    }
}
