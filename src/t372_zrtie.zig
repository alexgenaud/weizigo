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
////////////////////////////////////////////
//
// Task: T372 · Role: worker · Model: deepseek-v4-flash · identifier: flash/T372
// Date: 2026-08-05
//
// T372_ZRTIE — Z-R-TIE: test Markovian state-sufficiency with CONTRASTING
// histories (re-derivation #1 of T354's register triage, §5.1).
//
// The load-bearing claim under test is QA-023 C1 / GLOBAL.H1-MARKOV:
// the (position, side, passes, ko) tuple determines the value, so history
// beyond the ko field cannot matter. The 2B-3-AUDIT showed the previous
// probe's history generator misses the shortest arrival in 93% of states
// with ~62% shared prefixes — a tautological differential: two "different"
// histories that are nearly the same history cannot fail a sufficiency
// test. This instrument:
//
//   1. BUILDS a contrast-rich generator (shortest-arrival-first): BFS
//      shortest paths enumerated from the root PLUS randomized DFS detours
//      (probe-equivalent), and MEASURES the achieved contrast (shortest-
//      arrival hit rate, shared-prefix fraction, arrival-length
//      distribution) directly against the 93% / 62% baseline — with the
//      old-style DFS-only generator re-run on the same states as the
//      baseline control.
//   2. RUNS the C1 probe on the CORRECTED kernel at 3x2 first (the rung
//      where the hand-verified witness exists: (178,0,6,0), arrival A
//      -> -3, arrival B -> -6), then 3x3 if 3x2 is clean. "Corrected
//      kernel" = (a) the post-2B-FIX-KO rules (lone-stone ko conjunct,
//      single true game root), (b) the CORRECTED L/H fixpoint — the
//      monotone Gauss-Seidel pattern of pinrule-sufficiency, NOT the
//      as-shipped qa023_probe.zig fixpoint_kernel whose White-node
//      update guards are inverted (pinrule §1; still at HEAD, verified
//      by grep in this task).
//   3. RUNS the controls BEFORE the reading counts: a null control (same
//      state, same history, evaluated twice — a mismatch means the
//      harness, not the theory, is broken) and a seeded control (the
//      value deliberately consults something outside the four key
//      components — arrival length parity, and pass-membership of the
//      arrival — and the probe must CATCH the injected dependence).
//   4. Reports agreements and disagreements with denominators (N states x
//      M history pairs, both stated) and states plainly whether the Z-R-TIE
//      node's [F] — a state where Markovianity fails — was found.
//
// Semantics (reference-semantics-2026-07-29.md §1): V(sigma | A) =
//   TIE                    if sigma in A (revisit; A = arrival visit set,
//                          exclusive of sigma) or in the continuation path
//   area_score(board)      if passes == 2 (terminal)
//   max/min over children  Black max / White min, recursing with A u {sigma}
// Budget-capped; budget exhaustion is NEVER agreement (three-way split:
// value / TIE / exhausted).
//
// The rules, fixpoint and evaluators are re-implemented in-file (no imports
// beyond std): the rules from proof-v2 §1.1 formalization (i) as corrected
// by 2B-FIX-KO, validated against the hand-verified witness; the fixpoint
// from pinrule-sufficiency's corrected kernel, validated against the Bellman
// residual == 0, colour inversion == 0, and the (178,0,6,0) L==H==-6 anchor.
// This is deliberately an independent implementation — per the project's
// standing rule, independent re-implementation is what finds defects.
//
// Additive-only per the brief: one new standalone instrument, no build.zig
// edit, no edits to engine sources or src/vb_*.zig. T363/T369 hold the
// build graph; this file compiles standalone:
//
//   zig build-exe -O ReleaseSafe src/t372_zrtie.zig \
//       -femit-bin=/tmp/weizigo/t372/zrtie --cache-dir /tmp/weizigo/t372/cache \
//       --global-cache-dir /tmp/weizigo/t372/global
//
// Usage: weizigo-t372-zrtie <3x2|3x3> <mode> [flags]
//   modes:
//     census            reachable census + corrected fixpoint + anchors
//     witness           hardcoded (178,0,6,0) arrivals A/B (3x2 only)
//     contrast          generator contrast vs the 93%/62% baseline
//     probe             the C1/C2 probe with the contrast generator
//     control-null      same (state, history) twice must agree
//     control-seeded    injected history dependence must be caught
//     all               3x2: census + witness + contrast + controls + probe
//   flags:
//     --seed N          PRNG seed (default 0x2B3DA7A — the audit's seed)
//     --n-states N      sampled target states (default 128)
//     --k-short N       shortest histories per state (default 4)
//     --k-detour N      detour histories per state (default 4)
//     --max-depth N     detour DFS depth (3x2 default 24, 3x3 default 32)
//     --budget N        node budget per evaluation (default 5,000,000)
//     --eval ab|plain   evaluator: alpha-beta (exact, pruned) or plain
//                       minimax (default ab; plain cross-checks built in)
//     --include-witness add (178,0,6,0) to the 3x2 sample (default on)
//     --json <path>     write a results JSON for the mode
//
// Tests (tags): rules, witness, fixpoint-anchors, null-control,
// seeded-control, contrast. Verify each leg with
//   zig test src/t372_zrtie.zig --test-filter <tag>
// and ASSERT the reported test count (a filter matching zero tests compiles
// nothing and exits 0 — STATE rule 7).
//
// Reference anchors (3x2, corrected kernel, single true root):
//   reachable V = 2,583 (F1-CENSUS-GAP new+1 ground truth, independent
//     Python); non-terminal ~1,753 (3 phantom states of the 4-root set are
//     all trivial singletons); Bellman residual 0; inversion violations 0;
//     (178,0,6,0) -> (L,H) = (-6,-6); witness arrivals A/B -> -3 / -6
//     (QA023-C1-WITNESS handcheck, two independent implementations).
//
// Known state of knowledge this run sits on (pinrule-sufficiency
// 2026-07-29): under the history-conditioned first-revisit-truncation rule
// C1 is FALSIFIED at 3x2 (7 witnesses incl. (178,0,6,0)); under the
// fresh-start reading (shortest-arrival values vs median(L,TIE,H)) pinrule
// measured 396/396 agreement with 75.5% budget exhaustion. T372 re-runs
// both readings with a measured-contrast generator, the mandated controls,
// and (if 3x2 is clean) a 3x3 extension.

const std = @import("std");
const util = @import("util.zig");

const HEAD_SHA = "657f800"; // git rev-parse HEAD at build time (Orcha T372 registration)
pub const STAMP = "weizigo-t372-zrtie " ++ HEAD_SHA ++ " zig 0.16.0";

const DEFAULT_SEED: u64 = 0x2B3DA7A; // the 2B-3-AUDIT seed

/// Seeded-control perturbation: the value consults something outside the
/// four key components (the arrival history), and the probe must catch it.
/// NOTE: an earlier candidate seed — value += parity of arrival length — is
/// DEGENERATE: side toggles on every move from the root, so path-length
/// parity equals the state's side; it is a function of the tuple, not of the
/// history, and the probe correctly does not flag it (a negative control in
/// its own right). The two live seeds read the arrival itself.
const Perturb = enum { len_gt_dist, pass_member };

var g_io: std.Io = undefined; // set from init.io in main (single-threaded)

// ---------------------------------------------------------------------------
// Comptime-generic goban: rules, state encoding, reachability, corrected
// fixpoint, history machinery, evaluators. Instantiated for 3x2 and 3x3.
// ---------------------------------------------------------------------------

fn Goban(comptime W: usize, comptime H: usize) type {
    return struct {
        const Self = @This();
        const n: usize = W * H;
        const Pos = [n]i8; // -1 white, 0 empty, +1 black
        const KO_NONE: u16 = n; // "no ko" sentinel
        const KO_DIMS: usize = n + 1;
        const RAW_TOTAL: u64 = std.math.pow(u64, 3, n);
        const TOTAL_STATES: u64 = RAW_TOTAL * 2 * KO_DIMS * 3;
        const ReachWords: usize = @intCast((TOTAL_STATES + 63) / 64);
        const TIE: i8 = 0;
        const N_SCORE: i8 = @intCast(n);
        const L_INIT: i8 = -N_SCORE;
        const H_INIT: i8 = N_SCORE;

        const State = struct {
            board: u32, // dense colex-ish index (base-3 rank of the goban)
            side: u8, // 0 = Black (maximizer), 1 = White (minimizer)
            ko: u16, // n = none
            passes: u8, // 0..2

            pub fn linear(self: State) u64 {
                return ((@as(u64, self.passes) * 2 + self.side) * KO_DIMS + self.ko) * RAW_TOTAL + self.board;
            }
        };

        fn state_eq(a: State, b: State) bool {
            return a.board == b.board and a.side == b.side and a.ko == b.ko and a.passes == b.passes;
        }

        fn decode_linear(linear: u64) State {
            const passes: u8 = @intCast(linear / (2 * KO_DIMS * RAW_TOTAL));
            const rest: u64 = linear % (2 * KO_DIMS * RAW_TOTAL);
            const side: u8 = @intCast(rest / (KO_DIMS * RAW_TOTAL));
            const rest2: u64 = rest % (KO_DIMS * RAW_TOTAL);
            const ko: u16 = @intCast(rest2 / RAW_TOTAL);
            const board: u32 = @intCast(rest2 % RAW_TOTAL);
            return .{ .board = board, .side = side, .ko = ko, .passes = passes };
        }

        fn unrank_board(idx: u32) Pos {
            var b: Pos = undefined;
            var v = idx;
            for (0..n) |i| {
                const d = v % 3;
                b[i] = if (d == 1) 1 else if (d == 2) -1 else 0;
                v /= 3;
            }
            return b;
        }

        fn rank_board(board: Pos) u32 {
            var idx: u32 = 0;
            var mul: u32 = 1;
            for (board) |v| {
                const d: u32 = if (v > 0) 1 else if (v < 0) 2 else 0;
                idx += d * mul;
                mul *= 3;
            }
            return idx;
        }

        const root = State{ .board = 0, .side = 0, .ko = n, .passes = 0 };
        const root_board: Pos = [_]i8{0} ** n;

        // ---- legality / scoring -------------------------------------------

        fn neighbors(p: usize, buf: *[4]usize) usize {
            var cnt: usize = 0;
            const r = p / W;
            const c = p % W;
            if (r > 0) {
                buf[cnt] = p - W;
                cnt += 1;
            }
            if (r + 1 < H) {
                buf[cnt] = p + W;
                cnt += 1;
            }
            if (c > 0) {
                buf[cnt] = p - 1;
                cnt += 1;
            }
            if (c + 1 < W) {
                buf[cnt] = p + 1;
                cnt += 1;
            }
            return cnt;
        }

        fn chain_captured(pos: *const Pos, seed: usize, chain: *[n]usize, chain_len: *usize) bool {
            const colour: i8 = if (pos[seed] > 0) 1 else -1;
            var visited = [_]bool{false} ** n;
            var stack: [n]usize = undefined;
            var sp: usize = 1;
            stack[0] = seed;
            visited[seed] = true;
            chain[0] = seed;
            var len: usize = 1;
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

        /// Tromp-Taylor area score (Black-positive), same convention as the
        /// probe family: an empty region is territory of a colour iff it
        /// touches only that colour; a region touching both scores for neither.
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

        // ---- move application (corrected basic-ko, proof-v2 §1.1 (i)) -----

        /// Place `colour` at `cell`; captures applied; ko point set iff exactly
        /// one opponent stone captured AND the placed stone is a lone stone
        /// with exactly one liberty (the vacated cell) — the 2B-FIX-KO / F5
        /// correction. Returns null for illegal (occupied, suicide, ko ban).
        fn apply_place(state: State, board: *const Pos, colour: i8, cell: u8) ?State {
            if (board[cell] != 0) return null;
            if (state.ko != n and cell == state.ko) return null;
            const next_board = pos_from_move(board, colour, cell) catch return null;
            var opp_before: u8 = 0;
            var opp_after: u8 = 0;
            var captured_cell: u8 = @intCast(n);
            for (0..n) |i| {
                if (board[i] == -colour) opp_before += 1;
                if (next_board[i] == -colour) opp_after += 1;
                if (board[i] == -colour and next_board[i] == 0) captured_cell = @intCast(i);
            }
            var new_ko: u16 = n;
            if (opp_before - opp_after == 1 and captured_cell != n) {
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
            return .{
                .board = rank_board(next_board),
                .side = if (colour == 1) 1 else 0,
                .ko = new_ko,
                .passes = 0,
            };
        }

        fn apply_pass(state: State) ?State {
            if (state.passes >= 2) return null;
            return .{ .board = state.board, .side = 1 - state.side, .ko = n, .passes = state.passes + 1 };
        }

        /// All legal successors; pass edge first (determinism), then cells in
        /// index order. `successor_boards` aligns 1:1 with `successors`.
        fn moves(state: State, successor_boards: *[n + 1]Pos, successors: *[n + 1]State) usize {
            if (state.passes == 2) return 0;
            const board = unrank_board(state.board);
            const colour: i8 = if (state.side == 0) 1 else -1;
            var count: usize = 0;
            if (apply_pass(state)) |ns| {
                successor_boards[count] = unrank_board(ns.board);
                successors[count] = ns;
                count += 1;
            }
            for (0..n) |cell_u| {
                const cell: u8 = @intCast(cell_u);
                if (apply_place(state, &board, colour, cell)) |ns| {
                    successor_boards[count] = unrank_board(ns.board);
                    successors[count] = ns;
                    count += 1;
                }
            }
            return count;
        }

        /// Colour-inversion mirror: negate the goban, flip the side; ko cell
        /// and passes unchanged. Z4: L(s) == -H(mirror(s)).
        fn mirror_linear(linear: u64) u64 {
            const st = decode_linear(linear);
            const b = unrank_board(st.board);
            var nb: Pos = undefined;
            for (0..n) |i| nb[i] = -b[i];
            return (State{ .board = rank_board(nb), .side = 1 - st.side, .ko = st.ko, .passes = st.passes }).linear();
        }

        // ---- reachability --------------------------------------------------

        /// Single true game root (F1-CENSUS-GAP's new+1: V = 2,583 at 3x2).
        fn seed_roots(reach: []u64) void {
            const lin = root.linear();
            reach[lin >> 6] |= @as(u64, 1) << @intCast(lin & 63);
        }

        fn census_sweep(reach: []u64, snap: []u64, new_marks: *u64) void {
            @memcpy(snap, reach);
            new_marks.* = 0;
            var linear: u64 = 0;
            while (linear < TOTAL_STATES) : (linear += 1) {
                if (snap[linear >> 6] & (@as(u64, 1) << @intCast(linear & 63)) == 0) continue;
                const state = decode_linear(linear);
                var succ_boards: [n + 1]Pos = undefined;
                var succs: [n + 1]State = undefined;
                const m = moves(state, &succ_boards, &succs);
                for (0..m) |k| {
                    if (!is_legal(&succ_boards[k])) continue;
                    const cl = succs[k].linear();
                    if (reach[cl >> 6] & (@as(u64, 1) << @intCast(cl & 63)) == 0) {
                        reach[cl >> 6] |= @as(u64, 1) << @intCast(cl & 63);
                        new_marks.* += 1;
                    }
                }
            }
        }

        fn build_reach(gpa: std.mem.Allocator) ![]u64 {
            const reach = try gpa.alloc(u64, ReachWords);
            @memset(reach, 0);
            seed_roots(reach);
            const snap = try gpa.alloc(u64, ReachWords);
            defer gpa.free(snap);
            var new_marks: u64 = 1;
            var guard: u32 = 0;
            while (new_marks > 0 and guard < 64) {
                census_sweep(reach, snap, &new_marks);
                guard += 1;
            }
            return reach;
        }

        fn count_reach(reach: []const u64) u64 {
            var cnt: u64 = 0;
            for (reach) |w| cnt += @popCount(w);
            return cnt;
        }

        const Census = struct {
            reachable: u64,
            non_terminal: u64,
            terminal: u64,
        };

        fn census_stats(reach: []const u64) Census {
            var c = Census{ .reachable = 0, .non_terminal = 0, .terminal = 0 };
            var li: u64 = 0;
            while (li < TOTAL_STATES) : (li += 1) {
                if (reach[li >> 6] & (@as(u64, 1) << @intCast(li & 63)) == 0) continue;
                c.reachable += 1;
                if (decode_linear(li).passes == 2) c.terminal += 1 else c.non_terminal += 1;
            }
            return c;
        }

        // ---- corrected L/H fixpoint ---------------------------------------
        //
        // Monotone Gauss-Seidel (the pattern of retro.zig, EXP-11-verified,
        // and pinrule-sufficiency's fixpoint_corrected): seed L = -n, H = +n;
        // iterate L = Phi(L) up, H = Phi(H) down; Black max / White min in
        // BOTH sweeps. The update directions (L: only ever ascends; H: only
        // ever descends) are what the as-shipped qa023_probe.zig kernel gets
        // wrong at White nodes (pinrule §1 — verified still at HEAD by this
        // task: lines 965 `best < L_tab[li]` and 1024 `best > H_tab[hi]`).

        fn fixpoint_corrected(reach: []const u64, L_tab: []i8, H_tab: []i8) u32 {
            for (0..TOTAL_STATES) |i| {
                L_tab[i] = L_INIT;
                H_tab[i] = H_INIT;
            }
            var li2: u64 = 0;
            while (li2 < TOTAL_STATES) : (li2 += 1) {
                if (reach[li2 >> 6] & (@as(u64, 1) << @intCast(li2 & 63)) == 0) continue;
                if (decode_linear(li2).passes == 2) {
                    const b = unrank_board(decode_linear(li2).board);
                    L_tab[li2] = area_score(&b);
                    H_tab[li2] = area_score(&b);
                }
            }
            var sweep_idx: u32 = 0;
            var total_changes: u64 = 1;
            while (total_changes > 0 and sweep_idx < 512) {
                sweep_idx += 1;
                total_changes = 0;
                var li: u64 = 0;
                while (li < TOTAL_STATES) : (li += 1) {
                    if (reach[li >> 6] & (@as(u64, 1) << @intCast(li & 63)) == 0) continue;
                    const st = decode_linear(li);
                    if (st.passes == 2) continue;
                    const maximizing = (st.side == 0);
                    var succ_boards: [n + 1]Pos = undefined;
                    var succs: [n + 1]State = undefined;
                    const m = moves(st, &succ_boards, &succs);
                    var bl: ?i8 = null;
                    var bh: ?i8 = null;
                    for (0..m) |k| {
                        if (!is_legal(&succ_boards[k])) continue;
                        const cl = succs[k].linear();
                        if (reach[cl >> 6] & (@as(u64, 1) << @intCast(cl & 63)) == 0) continue;
                        const vl = L_tab[cl];
                        const vh = H_tab[cl];
                        if (bl == null or (if (maximizing) vl > bl.? else vl < bl.?)) bl = vl;
                        if (bh == null or (if (maximizing) vh > bh.? else vh < bh.?)) bh = vh;
                    }
                    if (bl == null or bh == null) continue; // defensive: terminal handled above
                    if (bl.? > L_tab[li]) {
                        L_tab[li] = bl.?;
                        total_changes += 1;
                    }
                    if (bh.? < H_tab[li]) {
                        H_tab[li] = bh.?;
                        total_changes += 1;
                    }
                }
            }
            return sweep_idx;
        }

        fn median(l: i8, h: i8) i8 {
            return @max(l, @min(TIE, h));
        }

        /// Bellman residual: count of reachable non-terminals where
        /// tab != Phi(tab). Zero means tab is an exact fixpoint of Phi.
        fn bellman_residual(reach: []const u64, tab: []const i8) u64 {
            var bad: u64 = 0;
            var li: u64 = 0;
            while (li < TOTAL_STATES) : (li += 1) {
                if (reach[li >> 6] & (@as(u64, 1) << @intCast(li & 63)) == 0) continue;
                const st = decode_linear(li);
                if (st.passes == 2) continue;
                const maximizing = (st.side == 0);
                var succ_boards: [n + 1]Pos = undefined;
                var succs: [n + 1]State = undefined;
                const m = moves(st, &succ_boards, &succs);
                var best: ?i8 = null;
                for (0..m) |k| {
                    if (!is_legal(&succ_boards[k])) continue;
                    const cl = succs[k].linear();
                    if (reach[cl >> 6] & (@as(u64, 1) << @intCast(cl & 63)) == 0) continue;
                    const v = tab[cl];
                    if (best == null or (if (maximizing) v > best.? else v < best.?)) best = v;
                }
                if (best == null or best.? != tab[li]) bad += 1;
            }
            return bad;
        }

        const InversionResult = struct {
            violations: u64, // both sides reachable but L(mirror) != -H(this)
            mirror_unreachable: u64, // mirror not reachable (single-root reachability boundary)
        };

        fn inversion_violations(reach: []const u64, L_tab: []const i8, H_tab: []const i8) InversionResult {
            var r = InversionResult{ .violations = 0, .mirror_unreachable = 0 };
            var li: u64 = 0;
            while (li < TOTAL_STATES) : (li += 1) {
                if (reach[li >> 6] & (@as(u64, 1) << @intCast(li & 63)) == 0) continue;
                const mi = mirror_linear(li);
                if (reach[mi >> 6] & (@as(u64, 1) << @intCast(mi & 63)) == 0) {
                    r.mirror_unreachable += 1;
                    continue;
                }
                if (L_tab[mi] != -H_tab[li]) r.violations += 1;
            }
            return r;
        }

        const PinCensus = struct { l_eq_h: u64, pin_t: u64, pin_l: u64, pin_h: u64 };

        fn pin_census(reach: []const u64, L_tab: []const i8, H_tab: []const i8, skip_terminals: bool) PinCensus {
            var c = PinCensus{ .l_eq_h = 0, .pin_t = 0, .pin_l = 0, .pin_h = 0 };
            var li: u64 = 0;
            while (li < TOTAL_STATES) : (li += 1) {
                if (reach[li >> 6] & (@as(u64, 1) << @intCast(li & 63)) == 0) continue;
                if (skip_terminals and decode_linear(li).passes == 2) continue;
                const Ll = L_tab[li];
                const Hh = H_tab[li];
                if (Ll == Hh) {
                    c.l_eq_h += 1;
                } else if (TIE < Ll) {
                    c.pin_l += 1;
                } else if (TIE > Hh) {
                    c.pin_h += 1;
                } else {
                    c.pin_t += 1;
                }
            }
            return c;
        }

        // ---- history machinery --------------------------------------------

        const Kind = enum(u8) { place, pass };

        const Move = struct {
            kind: Kind,
            cell: u8, // for place; 0 for pass
            colour: i8, // for place; 0 for pass
        };

        const HistoryEntry = struct {
            state: State,
            board: Pos,
        };

        const MAX_PATH: u16 = 4096; // >= longest simple path seen at 3x2/3x3

        /// Replay a move sequence from the root; buf gets root..final
        /// inclusive. Returns length (>= 1), or 0 on any illegal move.
        fn replay_arrival(play: []const Move, buf: []HistoryEntry) u16 {
            var st = root;
            var board = root_board;
            if (buf.len == 0) return 0;
            buf[0] = .{ .state = st, .board = board };
            var len: u16 = 1;
            for (play) |mv| {
                const next = switch (mv.kind) {
                    .place => apply_place(st, &board, mv.colour, mv.cell),
                    .pass => apply_pass(st),
                };
                const ns = next orelse return 0;
                if (len >= buf.len) return 0;
                st = ns;
                board = unrank_board(ns.board);
                buf[len] = .{ .state = st, .board = board };
                len += 1;
            }
            return len;
        }

        /// 0 = valid (root-anchored, consecutive legality, simple path),
        /// else the 1-based index of the first bad step (0xFFFF = bad root).
        fn arrival_valid(buf: []const HistoryEntry) u16 {
            if (buf.len == 0) return 0xFFFF;
            if (buf[0].state.board != root.board or buf[0].state.side != root.side or
                buf[0].state.ko != root.ko or buf[0].state.passes != root.passes) return 0xFFFF;
            var seen = [_]u64{0} ** ReachWords;
            for (buf, 0..) |e, i| {
                const lin = e.state.linear();
                if (seen[lin >> 6] & (@as(u64, 1) << @intCast(lin & 63)) != 0) return @intCast(i);
                seen[lin >> 6] |= @as(u64, 1) << @intCast(lin & 63);
                if (i == 0) continue;
                const prev = buf[i - 1].state;
                var succ_boards: [n + 1]Pos = undefined;
                var succs: [n + 1]State = undefined;
                const m = moves(prev, &succ_boards, &succs);
                var ok = false;
                for (0..m) |k| {
                    if (succs[k].board == e.state.board and succs[k].side == e.state.side and
                        succs[k].ko == e.state.ko and succs[k].passes == e.state.passes and is_legal(&succ_boards[k]))
                    {
                        ok = true;
                        break;
                    }
                }
                if (!ok) return @intCast(i);
            }
            return 0;
        }

        inline fn visit_get(set: []const u64, linear: u64) bool {
            return set[linear >> 6] & (@as(u64, 1) << @intCast(linear & 63)) != 0;
        }
        inline fn visit_set(set: []u64, linear: u64) void {
            set[linear >> 6] |= @as(u64, 1) << @intCast(linear & 63);
        }
        inline fn visit_clear(set: []u64, linear: u64) void {
            set[linear >> 6] &= ~(@as(u64, 1) << @intCast(linear & 63));
        }

        /// Arrival visit-set bitset from a HistoryEntry slice. The caller
        /// passes the slice EXCLUSIVE of sigma (per reference-semantics §1).
        fn arrival_bitset(arrival: []const HistoryEntry, set: []u64) void {
            @memset(set, 0);
            for (arrival) |e| visit_set(set, e.state.linear());
        }

        /// BFS from the root: dist[lin] = shortest arrival length (moves),
        /// parent[lin] = one shortest-path parent (self = root), with the
        /// move kind/cell of the edge parent -> lin.
        fn bfs_dist_parents(
            gpa: std.mem.Allocator,
            reach: []const u64,
            dist: []u32,
            parent: []u32,
            pmove_kind: []u8,
            pmove_cell: []u8,
        ) !void {
            @memset(dist, 0xFFFFFFFF);
            @memset(parent, 0xFFFFFFFF);
            const queue_buf = try gpa.alloc(u32, TOTAL_STATES);
            defer gpa.free(queue_buf);
            var head: u64 = 0;
            var tail: u64 = 0;
            const rlin: u32 = @intCast(root.linear());
            dist[rlin] = 0;
            parent[rlin] = rlin;
            queue_buf[tail] = rlin;
            tail += 1;
            while (head < tail) {
                const cur = queue_buf[head];
                head += 1;
                const st = decode_linear(cur);
                if (st.passes == 2) continue;
                var succ_boards: [n + 1]Pos = undefined;
                var succs: [n + 1]State = undefined;
                const m = moves(st, &succ_boards, &succs);
                for (0..m) |k| {
                    if (!is_legal(&succ_boards[k])) continue;
                    const cl = succs[k].linear();
                    if (reach[cl >> 6] & (@as(u64, 1) << @intCast(cl & 63)) == 0) continue;
                    if (dist[@intCast(cl)] != 0xFFFFFFFF) continue; // already shortest
                    dist[@intCast(cl)] = dist[cur] + 1;
                    parent[@intCast(cl)] = cur;
                    if (succs[k].board == st.board) {
                        pmove_kind[@intCast(cl)] = @intFromEnum(Kind.pass);
                        pmove_cell[@intCast(cl)] = 0;
                    } else {
                        pmove_kind[@intCast(cl)] = @intFromEnum(Kind.place);
                        const pb = unrank_board(st.board);
                        const cb = succ_boards[k];
                        var cell: u8 = 0;
                        for (0..n) |ci| {
                            if (pb[ci] == 0 and cb[ci] != 0) {
                                cell = @intCast(ci);
                                break;
                            }
                        }
                        pmove_cell[@intCast(cl)] = cell;
                    }
                    queue_buf[tail] = @intCast(cl);
                    tail += 1;
                }
            }
        }

        /// Reconstruct ONE shortest arrival (root..target inclusive) from the
        /// BFS parent chain. Returns length, or 0 if unreachable.
        fn arrival_from_parents(parent: []const u32, target_linear: u64, buf: []HistoryEntry) u16 {
            if (parent[@intCast(target_linear)] == 0xFFFFFFFF) return 0;
            var len: u16 = 0;
            var cur: u32 = @intCast(target_linear);
            while (true) {
                if (len >= buf.len) return 0;
                const st = decode_linear(cur);
                buf[len] = .{ .state = st, .board = unrank_board(st.board) };
                len += 1;
                const p = parent[@intCast(cur)];
                if (p == cur) break;
                cur = p;
            }
            var i: u16 = 0;
            while (i < len / 2) : (i += 1) {
                const t = buf[i];
                buf[i] = buf[len - 1 - i];
                buf[len - 1 - i] = t;
            }
            return len;
        }

        /// Enumerate up to `max_collect` DISTINCT SHORTEST paths to target
        /// (all of length dist[target]) by DFS over the shortest-path DAG
        /// (only edges with dist[child] == dist[cur] + 1). Child order is
        /// shuffled so distinct shortest paths are found; dedup by move
        /// sequence. Budget caps exploration.
        fn collect_shortest(
            state: State,
            board: *const Pos,
            target_linear: u64,
            depth: u16,
            budget: *u64,
            dist: []const u32,
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
                if (!same_move_seq(collected_moves, collected_lens, collected_count.*, path_moves, path_len.*, history_depth)) {
                    const base = collected_count.* * history_depth;
                    for (0..path_len.*) |p_| collected_moves[base + p_] = path_moves[p_];
                    collected_lens[collected_count.*] = path_len.*;
                    collected_count.* += 1;
                }
                return;
            }
            if (depth >= dist[@intCast(target_linear)] or budget.* == 0) return;
            budget.* -= 1;
            visited[linear] = true;

            var succ_boards: [n + 1]Pos = undefined;
            var succs: [n + 1]State = undefined;
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
                if (dist[@intCast(child_linear)] != dist[@intCast(linear)] + 1) continue; // shortest-DAG edge only
                const mv = move_of(state, board, child, succ_boards[idx]);
                path_moves[path_len.*] = mv;
                path_len.* += 1;
                collect_shortest(child, &succ_boards[idx], target_linear, depth + 1, budget, dist, path_moves, path_len, visited, collected_moves, collected_lens, collected_count, max_collect, history_depth, prng);
                path_len.* -= 1;
            }
            visited[linear] = false;
        }

        /// Randomized DFS detours (probe-equivalent generator), accepting
        /// only arrivals STRICTLY LONGER than the shortest (len > dist[t]),
        /// depth-capped, deduped by move sequence.
        fn collect_detours(
            state: State,
            board: *const Pos,
            target_linear: u64,
            depth: u16,
            max_depth: u16,
            budget: *u64,
            dist: []const u32,
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
                if (path_len.* <= dist[@intCast(target_linear)]) return; // not a detour
                if (collected_count.* >= max_collect) return;
                if (!same_move_seq(collected_moves, collected_lens, collected_count.*, path_moves, path_len.*, history_depth)) {
                    const base = collected_count.* * history_depth;
                    for (0..path_len.*) |p_| collected_moves[base + p_] = path_moves[p_];
                    collected_lens[collected_count.*] = path_len.*;
                    collected_count.* += 1;
                }
                return;
            }
            if (depth == max_depth or budget.* == 0) return;
            budget.* -= 1;
            visited[linear] = true;

            var succ_boards: [n + 1]Pos = undefined;
            var succs: [n + 1]State = undefined;
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
                const mv = move_of(state, board, child, succ_boards[idx]);
                path_moves[path_len.*] = mv;
                path_len.* += 1;
                collect_detours(child, &succ_boards[idx], target_linear, depth + 1, max_depth, budget, dist, path_moves, path_len, visited, collected_moves, collected_lens, collected_count, max_collect, history_depth, prng);
                path_len.* -= 1;
            }
            visited[linear] = false;
        }

        /// The old-style DFS-only collector (2B-3 / probe-equivalent,
        /// depth-capped, ANY arrival length). Used as the baseline control
        /// in contrast mode: must reproduce the 93% miss / 62% shared-prefix
        /// bias on the same sampled states.
        fn collect_dfs_old(
            state: State,
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
                if (!same_move_seq(collected_moves, collected_lens, collected_count.*, path_moves, path_len.*, history_depth)) {
                    const base = collected_count.* * history_depth;
                    for (0..path_len.*) |p_| collected_moves[base + p_] = path_moves[p_];
                    collected_lens[collected_count.*] = path_len.*;
                    collected_count.* += 1;
                }
                return;
            }
            if (depth == max_depth or budget.* == 0) return;
            budget.* -= 1;
            visited[linear] = true;

            var succ_boards: [n + 1]Pos = undefined;
            var succs: [n + 1]State = undefined;
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
                const mv = move_of(state, board, child, succ_boards[idx]);
                path_moves[path_len.*] = mv;
                path_len.* += 1;
                collect_dfs_old(child, &succ_boards[idx], target_linear, depth + 1, max_depth, budget, path_moves, path_len, visited, collected_moves, collected_lens, collected_count, max_collect, history_depth, prng);
                path_len.* -= 1;
            }
            visited[linear] = false;
        }

        fn same_move_seq(collected_moves: []const Move, collected_lens: []const u16, count: u32, path_moves: []const Move, path_len: u16, history_depth: u16) bool {
            var i: u32 = 0;
            while (i < count) : (i += 1) {
                if (collected_lens[i] != path_len) continue;
                const base = i * history_depth;
                var same = true;
                var j: u16 = 0;
                while (j < path_len) : (j += 1) {
                    const a = collected_moves[base + j];
                    const b = path_moves[j];
                    if (@intFromEnum(a.kind) != @intFromEnum(b.kind) or a.cell != b.cell or a.colour != b.colour) {
                        same = false;
                        break;
                    }
                }
                if (same) return true;
            }
            return false;
        }

        /// The Move that takes `state` to `child`; board = current goban,
        /// next_b = child goban. A pass never changes the goban; a place
        /// move is the cell that went empty -> occupied.
        fn move_of(state: State, board: *const Pos, child: State, next_b: Pos) Move {
            if (child.board == state.board) {
                return .{ .kind = .pass, .cell = 0, .colour = 0 };
            }
            var cell: u8 = 0;
            var found = false;
            for (0..n) |ci| {
                if (board[ci] == 0 and next_b[ci] != 0) {
                    cell = @intCast(ci);
                    found = true;
                    break;
                }
            }
            if (!found) {
                for (0..n) |ci| {
                    if (board[ci] != next_b[ci]) {
                        cell = @intCast(ci);
                        break;
                    }
                }
            }
            return .{ .kind = .place, .cell = cell, .colour = if (state.side == 0) 1 else -1 };
        }

        /// Longest common prefix (in moves) of two histories.
        fn shared_prefix_len(a: []const Move, al: u16, b: []const Move, bl: u16) u16 {
            const minl = @min(al, bl);
            var i: u16 = 0;
            while (i < minl) : (i += 1) {
                if (@intFromEnum(a[i].kind) != @intFromEnum(b[i].kind) or a[i].cell != b[i].cell or a[i].colour != b[i].colour) break;
            }
            return i;
        }

        // ---- truncated evaluators (first-revisit truncation) ---------------
        //
        // T2: plain minimax, bitset membership. T3: alpha-beta, same tree,
        // exact root value, pruned. Both implement the reference-semantics §1
        // recursion with the arrival visit set EXCLUSIVE of sigma.

        const EvalOutcome = struct {
            value: ?i8 = null,
            nodes: u64 = 0,
        };

        fn eval_plain(state: State, board: *const Pos, arrival_set: []const u64, budget: *u64, path_set: []u64) ?i8 {
            if (budget.* == 0) return null;
            budget.* -= 1;
            const lin = state.linear();
            if (visit_get(arrival_set, lin)) return TIE;
            if (visit_get(path_set, lin)) return TIE;
            if (state.passes == 2) return area_score(board);
            var succ_boards: [n + 1]Pos = undefined;
            var succs: [n + 1]State = undefined;
            const m = moves(state, &succ_boards, &succs);
            if (m == 0) return area_score(board);
            const maximizing = (state.side == 0);
            var best: i8 = if (maximizing) -127 else 127;
            visit_set(path_set, lin);
            for (0..m) |k| {
                if (!is_legal(&succ_boards[k])) continue;
                const v = eval_plain(succs[k], &succ_boards[k], arrival_set, budget, path_set) orelse {
                    visit_clear(path_set, lin);
                    return null;
                };
                if (maximizing) {
                    if (v > best) best = v;
                } else {
                    if (v < best) best = v;
                }
            }
            visit_clear(path_set, lin);
            return best;
        }

        fn eval_ab(state: State, board: *const Pos, arrival_set: []const u64, budget: *u64, path_set: []u64, alpha_in: i16, beta_in: i16) ?i8 {
            if (budget.* == 0) return null;
            budget.* -= 1;
            const lin = state.linear();
            if (visit_get(arrival_set, lin)) return TIE;
            if (visit_get(path_set, lin)) return TIE;
            if (state.passes == 2) return area_score(board);
            var succ_boards: [n + 1]Pos = undefined;
            var succs: [n + 1]State = undefined;
            const m = moves(state, &succ_boards, &succs);
            if (m == 0) return area_score(board);
            var alpha = alpha_in;
            var beta = beta_in;
            visit_set(path_set, lin);
            if (state.side == 0) {
                var best: i16 = -127;
                for (0..m) |k| {
                    if (!is_legal(&succ_boards[k])) continue;
                    const v = eval_ab(succs[k], &succ_boards[k], arrival_set, budget, path_set, alpha, beta) orelse {
                        visit_clear(path_set, lin);
                        return null;
                    };
                    if (v > best) best = v;
                    if (best > alpha) alpha = best;
                    if (alpha >= beta) break;
                }
                visit_clear(path_set, lin);
                return @intCast(best);
            } else {
                var best: i16 = 127;
                for (0..m) |k| {
                    if (!is_legal(&succ_boards[k])) continue;
                    const v = eval_ab(succs[k], &succ_boards[k], arrival_set, budget, path_set, alpha, beta) orelse {
                        visit_clear(path_set, lin);
                        return null;
                    };
                    if (v < best) best = v;
                    if (best < beta) beta = best;
                    if (alpha >= beta) break;
                }
                visit_clear(path_set, lin);
                return @intCast(best);
            }
        }

        fn eval_state(state: State, board: *const Pos, arrival_set: []const u64, budget: u64, use_ab: bool) EvalOutcome {
            var b = budget;
            const path_set = std.heap.page_allocator.alloc(u64, ReachWords) catch return .{};
            defer std.heap.page_allocator.free(path_set);
            @memset(path_set, 0);
            var outcome = EvalOutcome{};
            if (use_ab) {
                outcome.value = eval_ab(state, board, arrival_set, &b, path_set, -127, 127);
            } else {
                outcome.value = eval_plain(state, board, arrival_set, &b, path_set);
            }
            outcome.nodes = budget - b;
            return outcome;
        }
    };
}

// ---------------------------------------------------------------------------
// Per-goban runners
// ---------------------------------------------------------------------------

const G32 = Goban(3, 2);
const G33 = Goban(3, 3);

const Flags = struct {
    mode: []const u8 = "all",
    goban: []const u8 = "3x2",
    seed: u64 = DEFAULT_SEED,
    n_states: u32 = 128,
    k_short: u32 = 4,
    k_detour: u32 = 4,
    max_depth: u32 = 0, // resolved per goban when 0
    budget: u64 = 5_000_000,
    eval_ab: bool = true,
    include_witness: bool = true,
    stratum: []const u8 = "all", // all | pass1 | sparse (passes==1 / <=2 empty cells)
    max_empty: u32 = 2, // used by stratum=sparse
    json_path: ?[]const u8 = null,
};

fn progress(comptime fmt: []const u8, args: anytype) void {
    // stderr channel — the runner's progress watchdog scans stderr for
    // "[progress]".
    std.debug.print("[progress] " ++ fmt, args);
}

fn resolve_max_depth(comptime G: type, f: Flags) u32 {
    if (f.max_depth > 0) return f.max_depth;
    return if (G.n == 6) 24 else 32;
}

fn board_string(comptime G: type, b: G.Pos, buf: []u8) []const u8 {
    var i: usize = 0;
    for (b) |v| {
        buf[i] = if (v > 0) 'B' else if (v < 0) 'W' else '.';
        i += 1;
    }
    return buf[0..i];
}

fn goban_label(comptime G: type) []const u8 {
    return if (G.n == 6) "3x2" else "3x3";
}

// ---- census + fixpoint mode ------------------------------------------------

fn run_census(comptime G: type, f: Flags) !void {
    _ = f;
    const gpa = std.heap.page_allocator;
    util.out("# t372 census — {s} corrected kernel (single true root)\n", .{goban_label(G)});
    util.out("# instrument: {s}\n", .{STAMP});
    const reach = try G.build_reach(gpa);
    defer gpa.free(reach);
    const cs = G.census_stats(reach);
    util.out("# reachable V = {d}  (non-terminal {d}, terminal {d})\n", .{ cs.reachable, cs.non_terminal, cs.terminal });
    if (G.n == 6) {
        util.out("# anchor: F1-CENSUS-GAP new+1 (independent Python) = 2,583\n", .{});
    }
    const L_tab = try gpa.alloc(i8, G.TOTAL_STATES);
    defer gpa.free(L_tab);
    const H_tab = try gpa.alloc(i8, G.TOTAL_STATES);
    defer gpa.free(H_tab);
    const sweeps = G.fixpoint_corrected(reach, L_tab, H_tab);
    util.out("# fixpoint: {d} sweeps (monotone Gauss-Seidel, L up from -n, H down from +n)\n", .{sweeps});
    const resid_l = G.bellman_residual(reach, L_tab);
    const resid_h = G.bellman_residual(reach, H_tab);
    util.out("# Bellman residual: L={d} H={d} (must be 0 = exact fixpoints)\n", .{ resid_l, resid_h });
    const inv = G.inversion_violations(reach, L_tab, H_tab);
    util.out("# colour-inversion: violations {d} (both-reachable, must be 0); mirror-unreachable {d} (single-root boundary)\n", .{ inv.violations, inv.mirror_unreachable });
    const pc = G.pin_census(reach, L_tab, H_tab, true);
    util.out("# pin census (non-terminal): L==H={d} L<H&pin_T={d} L<H&pin_L={d} L<H&pin_H={d} (sum {d})\n", .{ pc.l_eq_h, pc.pin_t, pc.pin_l, pc.pin_h, pc.l_eq_h + pc.pin_t + pc.pin_l + pc.pin_h });
    if (G.n == 6) {
        // anchors: the 7 pinrule C1-witness states' (L,H)
        const anchors = [_]struct { b: u32, s: u8, k: u16, p: u8, l: i8, h: i8 }{
            .{ .b = 178, .s = 0, .k = 6, .p = 0, .l = -6, .h = -6 },
            .{ .b = 511, .s = 1, .k = 6, .p = 1, .l = -6, .h = -6 },
            .{ .b = 146, .s = 0, .k = 6, .p = 0, .l = 6, .h = 6 },
            .{ .b = 93, .s = 1, .k = 6, .p = 0, .l = 6, .h = 6 },
            .{ .b = 146, .s = 1, .k = 6, .p = 0, .l = 6, .h = 6 },
            .{ .b = 146, .s = 0, .k = 6, .p = 1, .l = 6, .h = 6 },
            .{ .b = 380, .s = 0, .k = 6, .p = 1, .l = 6, .h = 6 },
        };
        for (anchors) |a| {
            const st = G.State{ .board = a.b, .side = a.s, .ko = a.k, .passes = a.p };
            const lin = st.linear();
            const reachable = G.visit_get(reach, lin);
            util.out("# anchor state ({d},{d},{d},{d}): reachable={} L={d} H={d} median={d} (pinrule: L={d} H={d})\n", .{
                a.b, a.s, a.k, a.p, reachable, L_tab[lin], H_tab[lin], G.median(L_tab[lin], H_tab[lin]), a.l, a.h,
            });
        }
    }
}

// ---- witness mode (3x2 only) -----------------------------------------------

const WitnessArrival = struct {
    name: []const u8,
    moves: []const u8, // space-separated "B2 W3 pass ..."
    expected: i8,
};

const WITNESS_A = "B2 W3 B1 W4 B5 pass B0 pass B3 W4 pass W5 B0 W3 pass W1 pass W2 B0 W1 B2 W4";
const WITNESS_B = "B3 W1 pass W5 pass W4 pass W0 pass W3 B2 W3 B5 pass B0 W4 B1 pass B3 W4 B0 pass B2 W1";

/// Parse "B2 W3 pass ..." into moves; colour from turn parity (B first).
fn parse_witness(comptime G: type, spec: []const u8, out_moves: []G.Move) !u16 {
    var it = std.mem.tokenizeScalar(u8, spec, ' ');
    var i: u16 = 0;
    while (it.next()) |tok| {
        if (i >= out_moves.len) return error.TooManyMoves;
        if (std.mem.eql(u8, tok, "pass")) {
            out_moves[i] = .{ .kind = .pass, .cell = 0, .colour = 0 };
        } else {
            const colour: i8 = if (i % 2 == 0) 1 else -1;
            if (tok.len < 2) return error.BadMove;
            const cell = try std.fmt.parseInt(u8, tok[1..], 10);
            out_moves[i] = .{ .kind = .place, .cell = cell, .colour = colour };
        }
        i += 1;
    }
    return i;
}

fn run_witness(comptime G: type, f: Flags) !void {
    if (G.n != 6) {
        util.out("# witness mode is 3x2-only (the hand-verified rung); skipping\n", .{});
        return;
    }
    const gpa = std.heap.page_allocator;
    util.out("# t372 witness — (178,0,6,0) [B W B . W .] Black to move, ko=none, passes=0\n", .{});
    util.out("# instrument: {s}\n", .{STAMP});
    const reach = try G.build_reach(gpa);
    defer gpa.free(reach);
    const L_tab = try gpa.alloc(i8, G.TOTAL_STATES);
    defer gpa.free(L_tab);
    const H_tab = try gpa.alloc(i8, G.TOTAL_STATES);
    defer gpa.free(H_tab);
    _ = G.fixpoint_corrected(reach, L_tab, H_tab);

    const sigma = G.State{ .board = 178, .side = 0, .ko = 6, .passes = 0 };
    const sigma_lin = sigma.linear();
    const sigma_board = G.unrank_board(178);
    util.out("# sigma reachable={}  corrected L={d} H={d} median={d} (handcheck: L==H==-6)\n", .{
        G.visit_get(reach, sigma_lin), L_tab[sigma_lin], H_tab[sigma_lin], G.median(L_tab[sigma_lin], H_tab[sigma_lin]),
    });

    const arrivals = [_]WitnessArrival{
        .{ .name = "A", .moves = WITNESS_A, .expected = -3 },
        .{ .name = "B", .moves = WITNESS_B, .expected = -6 },
    };
    var any_fail = false;
    for (arrivals) |wa| {
        var play: [64]G.Move = undefined;
        const plen = try parse_witness(G, wa.moves, &play);
        var abuf: [G.MAX_PATH]G.HistoryEntry = undefined;
        const alen = G.replay_arrival(play[0..plen], &abuf);
        const valid = G.arrival_valid(abuf[0..alen]);
        const ends_at = abuf[alen - 1].state.board == sigma.board and abuf[alen - 1].state.side == sigma.side and
            abuf[alen - 1].state.ko == sigma.ko and abuf[alen - 1].state.passes == sigma.passes;
        var aset: [G.ReachWords]u64 = [_]u64{0} ** G.ReachWords;
        G.arrival_bitset(abuf[0 .. alen - 1], &aset);
        const arrival_lin = G.visit_get(&aset, sigma_lin);
        const r_ab = G.eval_state(sigma, &sigma_board, &aset, f.budget, true);
        const r_plain = G.eval_state(sigma, &sigma_board, &aset, f.budget * 4, false);
        const pass = (r_ab.value != null and r_ab.value.? == wa.expected);
        if (!pass) any_fail = true;
        util.out("# arrival {s}: len={d} moves, valid={d} (0=valid), ends-at-sigma={}, sigma-in-arrival={}, ab={?d} ({d} nodes), plain={?d} ({d} nodes), expected={d}  {s}\n", .{
            wa.name, plen, valid, ends_at, arrival_lin, r_ab.value, r_ab.nodes, r_plain.value, r_plain.nodes, wa.expected, if (pass) "PASS" else "FAIL",
        });
    }
    util.out("# witness verdict: {s}\n", .{if (any_fail) "FAILED TO REPRODUCE" else "REPRODUCED — evaluator and rules validated against the hand-verified witness"});
}

// ---- contrast mode ---------------------------------------------------------

const ContrastResult = struct {
    states: u32,
    old_shortest_hit: u32, // states where old DFS collected >=1 shortest path
    old_avg_len: f64,
    old_shared_prefix: f64,
    new_shortest_hit: u32, // states where new generator collected >=1 shortest path
    new_avg_short_len: f64,
    new_avg_detour_len: f64,
    new_shared_prefix: f64,
    new_pairs: u64,
    old_pairs: u64,
    arrival_bad: u64,
};

fn run_contrast(comptime G: type, f: Flags) !void {
    const gpa = std.heap.page_allocator;
    const max_depth = resolve_max_depth(G, f);
    util.out("# t372 contrast — generator contrast vs the 93% / 62% baseline ({s})\n", .{goban_label(G)});
    util.out("# params: seed={d} n-states={d} k-short={d} k-detour={d} max-depth={d} (old generator: depth 16, k 8)\n", .{
        f.seed, f.n_states, f.k_short, f.k_detour, max_depth,
    });
    util.out("# instrument: {s}\n", .{STAMP});

    const reach = try G.build_reach(gpa);
    defer gpa.free(reach);
    const L_tab = try gpa.alloc(i8, G.TOTAL_STATES);
    defer gpa.free(L_tab);
    const H_tab = try gpa.alloc(i8, G.TOTAL_STATES);
    defer gpa.free(H_tab);
    _ = G.fixpoint_corrected(reach, L_tab, H_tab);
    const dist = try gpa.alloc(u32, G.TOTAL_STATES);
    defer gpa.free(dist);
    const parent = try gpa.alloc(u32, G.TOTAL_STATES);
    defer gpa.free(parent);
    const pmk = try gpa.alloc(u8, G.TOTAL_STATES);
    defer gpa.free(pmk);
    const pmc = try gpa.alloc(u8, G.TOTAL_STATES);
    defer gpa.free(pmc);
    try G.bfs_dist_parents(gpa, reach, dist, parent, pmk, pmc);

    // sample states: non-terminal reachable, flat sample (contrast is about
    // arrival geometry, not pin class)
    var sample = try gpa.alloc(u64, f.n_states);
    defer gpa.free(sample);
    var sampled: u32 = 0;
    {
        var prng = std.Random.DefaultPrng.init(f.seed);
        var attempts: u64 = 0;
        while (sampled < f.n_states and attempts < f.n_states * 100) : (attempts += 1) {
            const lin = prng.random().intRangeAtMost(u64, 0, G.TOTAL_STATES - 1);
            if (!G.visit_get(reach, lin)) continue;
            if (G.decode_linear(lin).passes == 2) continue;
            if (dist[@intCast(lin)] == 0xFFFFFFFF) continue;
            sample[sampled] = lin;
            sampled += 1;
        }
    }

    const visited_states = try gpa.alloc(bool, G.TOTAL_STATES);
    defer gpa.free(visited_states);
    const path_moves = try gpa.alloc(G.Move, 256);
    defer gpa.free(path_moves);
    const hd_old: u16 = 32; // per-history slot width (>= max len)
    const hd_new: u16 = 64;
    const old_moves = try gpa.alloc(G.Move, 8 * hd_old);
    defer gpa.free(old_moves);
    const old_lens = try gpa.alloc(u16, 8);
    defer gpa.free(old_lens);
    const new_moves = try gpa.alloc(G.Move, (f.k_short + f.k_detour) * hd_new);
    defer gpa.free(new_moves);
    const new_lens = try gpa.alloc(u16, f.k_short + f.k_detour);
    defer gpa.free(new_lens);

    var res = ContrastResult{ .states = sampled, .old_shortest_hit = 0, .old_avg_len = 0, .old_shared_prefix = 0, .new_shortest_hit = 0, .new_avg_short_len = 0, .new_avg_detour_len = 0, .new_shared_prefix = 0, .new_pairs = 0, .old_pairs = 0, .arrival_bad = 0 };

    var old_len_sum: f64 = 0;
    var old_len_cnt: f64 = 0;
    var new_short_len_sum: f64 = 0;
    var new_short_cnt: f64 = 0;
    var new_detour_len_sum: f64 = 0;
    var new_detour_cnt: f64 = 0;
    var old_prefix_sum: f64 = 0;
    var old_prefix_cnt: f64 = 0;
    var new_prefix_sum: f64 = 0;
    var new_prefix_cnt: f64 = 0;

    var prng = std.Random.DefaultPrng.init(f.seed ^ 0x51E7);
    for (sample[0..sampled], 0..) |lin, si| {
        const target_dist = dist[@intCast(lin)];

        // --- old-style DFS-only generator (baseline control, depth 16, k 8)
        var cc: u32 = 0;
        var cbudget: u64 = 200_000;
        var rand = prng.random();
        var plen: u16 = 0;
        G.collect_dfs_old(G.root, &G.root_board, lin, 0, 16, &cbudget, path_moves, &plen, visited_states, old_moves, old_lens, &cc, 8, hd_old, &rand);
        var old_hit = false;
        var old_lens_local: [8]u16 = undefined;
        for (0..cc) |i| {
            old_lens_local[i] = old_lens[i];
            if (old_lens[i] == target_dist) old_hit = true;
            old_len_sum += @floatFromInt(old_lens[i]);
            old_len_cnt += 1;
        }
        if (old_hit) res.old_shortest_hit += 1;
        // pairwise shared prefix among old histories
        var i: u32 = 0;
        while (i < cc) : (i += 1) {
            var j: u32 = i + 1;
            while (j < cc) : (j += 1) {
                const lcp = G.shared_prefix_len(old_moves[i * hd_old ..][0..old_lens[i]], old_lens[i], old_moves[j * hd_old ..][0..old_lens[j]], old_lens[j]);
                old_prefix_sum += @as(f64, @floatFromInt(lcp)) / @as(f64, @floatFromInt(@min(old_lens[i], old_lens[j])));
                old_prefix_cnt += 1;
                res.old_pairs += 1;
            }
        }

        // --- new generator: shortest + detours
        @memset(visited_states, false);
        var short_count: u32 = 0;
        var sbudget: u64 = 100_000;
        plen = 0;
        var rand2 = prng.random();
        G.collect_shortest(G.root, &G.root_board, lin, 0, &sbudget, dist, path_moves, &plen, visited_states, new_moves, new_lens, &short_count, f.k_short, hd_new, &rand2);

        @memset(visited_states, false);
        var detour_count: u32 = 0;
        var dbudget: u64 = 200_000;
        plen = 0;
        var rand3 = prng.random();
        G.collect_detours(G.root, &G.root_board, lin, 0, @intCast(max_depth), &dbudget, dist, path_moves, &plen, visited_states, new_moves[short_count * hd_new ..], new_lens[short_count..], &detour_count, f.k_detour, hd_new, &rand3);

        const total_new = short_count + detour_count;
        var new_hit = false;
        var new_lens_local: [32]u16 = undefined;
        for (0..short_count) |si2| {
            new_lens_local[si2] = new_lens[si2];
            if (new_lens[si2] == target_dist) new_hit = true;
            new_short_len_sum += @floatFromInt(new_lens[si2]);
            new_short_cnt += 1;
        }
        for (0..detour_count) |di2| {
            new_lens_local[short_count + di2] = new_lens[short_count + di2];
            new_detour_len_sum += @floatFromInt(new_lens[short_count + di2]);
            new_detour_cnt += 1;
        }
        if (new_hit) res.new_shortest_hit += 1;
        var ii: u32 = 0;
        while (ii < total_new) : (ii += 1) {
            var jj: u32 = ii + 1;
            while (jj < total_new) : (jj += 1) {
                const lcp = G.shared_prefix_len(new_moves[ii * hd_new ..][0..new_lens[ii]], new_lens[ii], new_moves[jj * hd_new ..][0..new_lens[jj]], new_lens[jj]);
                new_prefix_sum += @as(f64, @floatFromInt(lcp)) / @as(f64, @floatFromInt(@min(new_lens[ii], new_lens[jj])));
                new_prefix_cnt += 1;
                res.new_pairs += 1;
            }
        }

        // validate a sample of the new histories (ARRIVAL-BAD must be 0)
        if (si % 8 == 0) {
            var vbuf: [G.MAX_PATH]G.HistoryEntry = undefined;
            var hi: u32 = 0;
            while (hi < total_new) : (hi += 1) {
                const rlen = G.replay_arrival(new_moves[hi * hd_new ..][0..new_lens[hi]], &vbuf);
                if (rlen == 0 or G.arrival_valid(vbuf[0..rlen]) != 0) res.arrival_bad += 1;
            }
        }
        if (si % 25 == 0) progress("contrast {s}: state {d}/{d} (dist {d})\n", .{ goban_label(G), si, sampled, target_dist });
    }

    res.old_avg_len = if (old_len_cnt > 0) old_len_sum / old_len_cnt else 0;
    res.old_shared_prefix = if (old_prefix_cnt > 0) old_prefix_sum / old_prefix_cnt else 0;
    res.new_avg_short_len = if (new_short_cnt > 0) new_short_len_sum / new_short_cnt else 0;
    res.new_avg_detour_len = if (new_detour_cnt > 0) new_detour_len_sum / new_detour_cnt else 0;
    res.new_shared_prefix = if (new_prefix_cnt > 0) new_prefix_sum / new_prefix_cnt else 0;

    const old_miss_rate = 100.0 * (@as(f64, @floatFromInt(sampled - res.old_shortest_hit)) / @as(f64, @floatFromInt(sampled)));
    const new_hit_rate = 100.0 * (@as(f64, @floatFromInt(res.new_shortest_hit)) / @as(f64, @floatFromInt(sampled)));

    util.out("# === contrast measurement (N = {d} states) ===\n", .{sampled});
    util.out("# baseline (2B-3-AUDIT, old DFS generator): shortest miss 93%, shared prefix 62.35%, avg len 14.8 vs shortest 5.1\n", .{});
    util.out("# OLD generator (depth 16, k 8): shortest-hit {d}/{d} ({d:.1}% miss {d:.1}%), avg arrival len {d:.2}, shared prefix {d:.2}% ({d} pairs)\n", .{
        res.old_shortest_hit, sampled, old_miss_rate, 100.0 - old_miss_rate, res.old_avg_len, res.old_shared_prefix * 100.0, res.old_pairs,
    });
    util.out("# NEW generator: shortest-hit {d}/{d} ({d:.1}%), avg shortest len {d:.2}, avg detour len {d:.2}, shared prefix {d:.2}% ({d} pairs)\n", .{
        res.new_shortest_hit, sampled, new_hit_rate, res.new_avg_short_len, res.new_avg_detour_len, res.new_shared_prefix * 100.0, res.new_pairs,
    });
    util.out("# ARRIVAL-BAD (validated subset): {d} (must be 0)\n", .{res.arrival_bad});
    const beats = (new_hit_rate >= 50.0 and res.new_shared_prefix < 0.62);
    util.out("# verdict: new generator {s} the baseline (hit rate {d:.1}% vs 7%, shared prefix {d:.2}% vs 62.35%)\n", .{
        if (beats) "BEATS" else "DOES NOT BEAT",
        new_hit_rate,
        res.new_shared_prefix * 100.0,
    });
    if (f.json_path) |jp| try write_contrast_json(jp, G, f, res, old_miss_rate, new_hit_rate);
}

fn write_contrast_json(path: []const u8, comptime G: type, f: Flags, r: ContrastResult, old_miss_rate: f64, new_hit_rate: f64) !void {
    var buf: [8192]u8 = undefined;
    const s = try std.fmt.bufPrint(&buf,
        \\{{"task_id":"T372","goban":"{s}","mode":"contrast","seed":{d},"instrument":"{s}",
        \\"n_states":{d},"k_short":{d},"k_detour":{d},
        \\"old_generator":{{"shortest_miss_pct":{d:.1},"avg_len":{d:.2},"shared_prefix_pct":{d:.2},"pairs":{d}}},
        \\"new_generator":{{"shortest_hit_pct":{d:.1},"avg_shortest_len":{d:.2},"avg_detour_len":{d:.2},"shared_prefix_pct":{d:.2},"pairs":{d}}},
        \\"arrival_bad":{d},"baseline":{{"shortest_miss_pct":93.0,"shared_prefix_pct":62.35}}}}
    , .{ goban_label(G), f.seed, STAMP, r.states, f.k_short, f.k_detour, old_miss_rate, r.old_avg_len, r.old_shared_prefix * 100.0, r.old_pairs, new_hit_rate, r.new_avg_short_len, r.new_avg_detour_len, r.new_shared_prefix * 100.0, r.new_pairs, r.arrival_bad });
    try write_file(path, s);
}

// ---- the probe -------------------------------------------------------------

const Bucket = enum { leh, pin_t, pin_l, pin_h };

const ProbeResult = struct {
    states_sampled: u32,
    states_reached: u32, // >=1 arrival generated and valid
    states_with_value: u32, // >=1 within-budget evaluation
    states_c1_eligible: u32, // >=2 within-budget values
    states_c1_fail: u32, // >=2 within-budget values, not all equal
    states_c2_eligible: u32, // >=1 within-budget value
    states_c2_fail: u32, // all within-budget equal, != median
    pairs_within_budget: u64, // sum over states of choose(k,2), k = within-budget evals
    pairs_disagree: u64, // pairs whose values differ
    evals_total: u64,
    evals_within_budget: u64,
    evals_tie: u64,
    evals_exhausted: u64,
    hist_total: u64,
    hist_short: u64,
    hist_detour: u64,
    arrival_bad: u64,
    sigma_in_arrival: u64,
    nodes_spent: u64,
    fresh_start_agree: u64, // shortest-arrival values == median
    fresh_start_total: u64, // shortest-arrival within-budget evals
    c1_witness_states: u64, // states where a short vs long disagreement was seen
    buckets: [4]u32,
};

fn run_probe(comptime G: type, f: Flags, perturb: ?Perturb) !ProbeResult {
    const gpa = std.heap.page_allocator;
    const max_depth = resolve_max_depth(G, f);
    util.out("# t372 probe — C1/C2 with contrast-rich histories ({s}, kernel {s})\n", .{ goban_label(G), if (perturb == null) "corrected" else "SEEDED-PERTURBED" });
    util.out("# params: seed={d} n-states={d} k-short={d} k-detour={d} max-depth={d} budget={d} eval={s} stratum={s}\n", .{
        f.seed, f.n_states, f.k_short, f.k_detour, max_depth, f.budget, if (f.eval_ab) "ab" else "plain", f.stratum,
    });
    util.out("# instrument: {s}\n", .{STAMP});

    const reach = try G.build_reach(gpa);
    defer gpa.free(reach);
    const L_tab = try gpa.alloc(i8, G.TOTAL_STATES);
    defer gpa.free(L_tab);
    const H_tab = try gpa.alloc(i8, G.TOTAL_STATES);
    defer gpa.free(H_tab);
    _ = G.fixpoint_corrected(reach, L_tab, H_tab);
    const dist = try gpa.alloc(u32, G.TOTAL_STATES);
    defer gpa.free(dist);
    const parent = try gpa.alloc(u32, G.TOTAL_STATES);
    defer gpa.free(parent);
    const pmk = try gpa.alloc(u8, G.TOTAL_STATES);
    defer gpa.free(pmk);
    const pmc = try gpa.alloc(u8, G.TOTAL_STATES);
    defer gpa.free(pmc);
    try G.bfs_dist_parents(gpa, reach, dist, parent, pmk, pmc);

    // bucket sampling (weighted toward bracket states, mirroring the probe)
    var bucket_idx = [_]std.ArrayListUnmanaged(u64){ .empty, .empty, .empty, .empty };
    for (0..bucket_idx.len) |i| bucket_idx[i] = .empty;
    defer {
        for (0..bucket_idx.len) |i| bucket_idx[i].deinit(gpa);
    }
    {
        var li: u64 = 0;
        while (li < G.TOTAL_STATES) : (li += 1) {
            if (!G.visit_get(reach, li)) continue;
            if (G.decode_linear(li).passes == 2) continue;
            if (dist[@intCast(li)] == 0xFFFFFFFF) continue;
            if (std.mem.eql(u8, f.stratum, "pass1") and G.decode_linear(li).passes != 1) continue;
            if (std.mem.eql(u8, f.stratum, "sparse")) {
                const b2 = G.unrank_board(G.decode_linear(li).board);
                var empties: u8 = 0;
                for (b2) |v| {
                    if (v == 0) empties += 1;
                }
                if (empties > f.max_empty) continue;
            }
            const Ll = L_tab[li];
            const Hh = H_tab[li];
            const b: Bucket = if (Ll == Hh) .leh else if (G.TIE < Ll) .pin_l else if (G.TIE > Hh) .pin_h else .pin_t;
            try bucket_idx[@intFromEnum(b)].append(gpa, li);
        }
    }
    util.out("# buckets (non-terminal reachable, BFS-reachable): L==H={d} pin_T={d} pin_L={d} pin_H={d}\n", .{
        bucket_idx[0].items.len, bucket_idx[1].items.len, bucket_idx[2].items.len, bucket_idx[3].items.len,
    });

    const k_total = f.k_short + f.k_detour;
    const hd: u16 = 64;
    const visited_states = try gpa.alloc(bool, G.TOTAL_STATES);
    defer gpa.free(visited_states);
    const path_moves = try gpa.alloc(G.Move, 256);
    defer gpa.free(path_moves);
    const collected_moves = try gpa.alloc(G.Move, k_total * hd);
    defer gpa.free(collected_moves);
    const collected_lens = try gpa.alloc(u16, k_total);
    defer gpa.free(collected_lens);
    const arrival_set = try gpa.alloc(u64, G.ReachWords);
    defer gpa.free(arrival_set);
    const abuf = try gpa.alloc(G.HistoryEntry, G.MAX_PATH);
    defer gpa.free(abuf);

    var res = ProbeResult{
        .states_sampled = 0, .states_reached = 0, .states_with_value = 0,
        .states_c1_eligible = 0, .states_c1_fail = 0, .states_c2_eligible = 0, .states_c2_fail = 0,
        .pairs_within_budget = 0, .pairs_disagree = 0,
        .evals_total = 0, .evals_within_budget = 0, .evals_tie = 0, .evals_exhausted = 0,
        .hist_total = 0, .hist_short = 0, .hist_detour = 0,
        .arrival_bad = 0, .sigma_in_arrival = 0, .nodes_spent = 0,
        .fresh_start_agree = 0, .fresh_start_total = 0, .c1_witness_states = 0,
        .buckets = [_]u32{ 0, 0, 0, 0 },
    };

    var prng = std.Random.DefaultPrng.init(f.seed);
    var sample_list: std.ArrayListUnmanaged(u64) = .empty;
    defer sample_list.deinit(gpa);

    // sample states
    while (sample_list.items.len < f.n_states) {
        const roll = prng.random().intRangeAtMost(u8, 0, 99);
        const b: Bucket = if (roll < 40) .leh else if (roll < 80) .pin_t else if (roll < 90) .pin_l else .pin_h;
        const bi = @intFromEnum(b);
        if (bucket_idx[bi].items.len == 0) continue; // empty bucket: reroll
        const lin = bucket_idx[bi].items[prng.random().intRangeAtMost(u64, 0, bucket_idx[bi].items.len - 1)];
        try sample_list.append(gpa, lin);
        res.buckets[bi] += 1;
    }
    // always include the hand-verified witness state at 3x2
    if (G.n == 6 and f.include_witness) {
        const wl = (G.State{ .board = 178, .side = 0, .ko = 6, .passes = 0 }).linear();
        if (std.mem.indexOfScalar(u64, sample_list.items, wl) == null) {
            try sample_list.append(gpa, wl);
        }
    }

    var sample_idx: u32 = 0;
    while (sample_idx < sample_list.items.len) : (sample_idx += 1) {
        const lin = sample_list.items[sample_idx];
        res.states_sampled += 1;
        const st = G.decode_linear(lin);
        const b = G.unrank_board(st.board);
        const target_dist = dist[@intCast(lin)];
        const median_v = G.median(L_tab[lin], H_tab[lin]);

        // shortest histories (guaranteed hit)
        @memset(visited_states, false);
        var short_count: u32 = 0;
        var sbudget: u64 = 100_000;
        var plen: u16 = 0;
        var rand_s = prng.random();
        G.collect_shortest(G.root, &G.root_board, lin, 0, &sbudget, dist, path_moves, &plen, visited_states, collected_moves, collected_lens, &short_count, f.k_short, hd, &rand_s);
        // detours
        @memset(visited_states, false);
        var detour_count: u32 = 0;
        var dbudget: u64 = 200_000;
        plen = 0;
        var rand_d = prng.random();
        G.collect_detours(G.root, &G.root_board, lin, 0, @intCast(max_depth), &dbudget, dist, path_moves, &plen, visited_states, collected_moves[short_count * hd ..], collected_lens[short_count..], &detour_count, f.k_detour, hd, &rand_d);

        const total = short_count + detour_count;
        if (total == 0) continue;
        res.states_reached += 1;

        // per-state within-budget values, with origin tags (short vs detour)
        var vals: [32]?i8 = [_]?i8{null} ** 32;
        var is_short: [32]bool = [_]bool{false} ** 32;
        var n_vals: u32 = 0;
        var any_within = false;
        var c1_fail_state = false;
        var c2_fail_state = false;

        var hi: u32 = 0;
        while (hi < total) : (hi += 1) {
            const hlen = collected_lens[hi];
            const hshort = hi < short_count;
            const rlen = G.replay_arrival(collected_moves[hi * hd ..][0..hlen], abuf);
            if (rlen == 0 or G.arrival_valid(abuf[0..rlen]) != 0) {
                res.arrival_bad += 1;
                continue;
            }
            if (!G.state_eq(abuf[rlen - 1].state, st)) {
                res.arrival_bad += 1;
                continue;
            }
            res.hist_total += 1;
            if (hshort) res.hist_short += 1 else res.hist_detour += 1;

            G.arrival_bitset(abuf[0 .. rlen - 1], arrival_set);
            if (G.visit_get(arrival_set, lin)) res.sigma_in_arrival += 1; // must be 0

            var budget = f.budget;
            const path_set = gpa.alloc(u64, G.ReachWords) catch unreachable;
            defer gpa.free(path_set);
            @memset(path_set, 0);
            var v: ?i8 = null;
            if (f.eval_ab) {
                v = G.eval_ab(st, &b, arrival_set, &budget, path_set, -127, 127);
            } else {
                v = G.eval_plain(st, &b, arrival_set, &budget, path_set);
            }
            const nodes = f.budget - budget;
            res.nodes_spent += nodes;
            res.evals_total += 1;
            if (v == null) {
                res.evals_exhausted += 1;
                continue;
            }
            res.evals_within_budget += 1;
            if (v.? == G.TIE) res.evals_tie += 1;

            // SEEDED control: value consults something outside the tuple
            var vv = v.?;
            if (perturb) |p| {
                switch (p) {
                    .len_gt_dist => vv = v.? + @as(i8, if (hlen > target_dist) 1 else 0),
                    .pass_member => {
                        var has_pass = false;
                        for (collected_moves[hi * hd ..][0..hlen]) |mv| {
                            if (mv.kind == .pass) {
                                has_pass = true;
                                break;
                            }
                        }
                        vv = v.? + @as(i8, if (has_pass) 1 else 0);
                    },
                }
            }

            if (n_vals < 32) {
                vals[n_vals] = vv;
                is_short[n_vals] = hshort;
                n_vals += 1;
            }
            any_within = true;
            if (hshort) {
                res.fresh_start_total += 1;
                if (vv == median_v) res.fresh_start_agree += 1;
            }
        }

        if (any_within) res.states_with_value += 1;
        if (n_vals >= 2) {
            res.states_c1_eligible += 1;
            const first = vals[0].?;
            var all_same = true;
            for (1..n_vals) |k| {
                if (vals[k].? != first) {
                    all_same = false;
                    break;
                }
            }
            // pair-level: count disagreeing pairs
            var k1: u32 = 0;
            while (k1 < n_vals) : (k1 += 1) {
                var k2: u32 = k1 + 1;
                while (k2 < n_vals) : (k2 += 1) {
                    if (vals[k1].? != vals[k2].?) res.pairs_disagree += 1;
                }
            }
            res.pairs_within_budget += @intCast(n_vals * (n_vals - 1) / 2);
            if (!all_same) {
                res.states_c1_fail += 1;
                c1_fail_state = true;
            }
        }
        if (n_vals >= 1) {
            res.states_c2_eligible += 1;
            const first = vals[0].?;
            var all_same = true;
            for (1..n_vals) |k| {
                if (vals[k].? != first) {
                    all_same = false;
                    break;
                }
            }
            if (all_same and first != median_v) {
                res.states_c2_fail += 1;
                c2_fail_state = true;
            }
        }
        // short-vs-long C1 witness (the fresh-start vs history-conditioned cut)
        if (n_vals >= 2) {
            var short_v: ?i8 = null;
            var long_v: ?i8 = null;
            for (0..n_vals) |k| {
                if (is_short[k]) {
                    if (short_v == null) short_v = vals[k];
                } else {
                    if (long_v == null) long_v = vals[k];
                }
            }
            if (short_v != null and long_v != null and short_v.? != long_v.?) res.c1_witness_states += 1;
        }

        if (perturb == null) {
            if (c1_fail_state or c2_fail_state) {
                if (res.states_c1_fail + res.states_c2_fail <= 12) {
                    var sb: [2 * G.n]u8 = undefined;
                    util.out("# STATE-DISAGREE: ({d},{d},{d},{d}) board[{s}] dist={d} median={d} vals=[", .{
                        st.board, st.side, st.ko, st.passes, board_string(G, b, &sb), target_dist, median_v,
                    });
                    for (0..n_vals) |k| {
                        if (k > 0) util.out(",", .{});
                        util.out("{d}{s}", .{ vals[k].?, if (is_short[k]) "S" else "L" });
                    }
                    util.out("]\n", .{});
                }
            }
        } else if (n_vals >= 2 and res.states_c1_eligible <= 8) {
            // seeded-control debug: show the trigger feature per within-budget
            // eval so a non-detection is attributable to the sample, not to a
            // silently uniform feature.
            var sb: [2 * G.n]u8 = undefined;
            util.out("# SEEDED-DBG: ({d},{d},{d},{d}) board[{s}] dist={d} evals=[", .{
                st.board, st.side, st.ko, st.passes, board_string(G, b, &sb), target_dist,
            });
            for (0..n_vals) |k| {
                if (k > 0) util.out(",", .{});
                const hl = collected_lens[if (k < short_count) k else short_count + (k - short_count)];
                util.out("{d}@{d}{s}", .{ vals[k].?, hl & 1, if (is_short[k]) "S" else "L" });
            }
            util.out("]\n", .{});
        }
        if (sample_idx % 16 == 0) progress("probe {s}: state {d}/{d} within={d}/{d}\n", .{ goban_label(G), sample_idx, sample_list.items.len, res.evals_within_budget, res.evals_total });
    }

    util.out("# === probe reading ===\n", .{});
    util.out("# states sampled: {d}\n", .{res.states_sampled});
    util.out("# states with >=1 valid arrival: {d}\n", .{res.states_reached});
    util.out("# states with >=1 within-budget value: {d}\n", .{res.states_with_value});
    util.out("# histories: total {d} (short {d}, detour {d}); ARRIVAL-BAD {d}; sigma-in-arrival {d} (must be 0)\n", .{ res.hist_total, res.hist_short, res.hist_detour, res.arrival_bad, res.sigma_in_arrival });
    util.out("# evaluations: total {d}; within-budget {d} (TIE-valued {d}); exhausted {d} ({d:.1}%)\n", .{ res.evals_total, res.evals_within_budget, res.evals_tie, res.evals_exhausted, if (res.evals_total > 0) @as(f64, @floatFromInt(res.evals_exhausted)) * 100.0 / @as(f64, @floatFromInt(res.evals_total)) else 0 });
    util.out("# nodes spent: {d}\n", .{res.nodes_spent});
    util.out("# C1: states eligible (>=2 within-budget values): {d}; states FAILING (values disagree): {d}\n", .{ res.states_c1_eligible, res.states_c1_fail });
    util.out("# C1 pair-level: {d} within-budget history pairs, {d} disagreeing\n", .{ res.pairs_within_budget, res.pairs_disagree });
    util.out("# C2: states eligible (>=1 within-budget value): {d}; states FAILING (all agree but != median): {d}\n", .{ res.states_c2_eligible, res.states_c2_fail });
    util.out("# fresh-start cut (shortest arrivals only): {d}/{d} values == median(L,TIE,H)\n", .{ res.fresh_start_agree, res.fresh_start_total });
    util.out("# short-vs-long C1 witness states: {d}\n", .{res.c1_witness_states});

    if (perturb != null) {
        const detected = res.pairs_disagree > 0 or res.states_c1_fail > 0;
        util.out("# SEEDED CONTROL verdict: injected history dependence {s} by the probe ({d} disagreeing pairs, {d} C1-fail states)\n", .{
            if (detected) "DETECTED" else "NOT DETECTED", res.pairs_disagree, res.states_c1_fail,
        });
    } else {
        util.out("# [F] verdict (Z-R-TIE): ", .{});
        if (res.states_c1_fail > 0 or res.pairs_disagree > 0) {
            util.out("FOUND — {d} state(s)/{d} pair(s) where two genuine arrivals give different truncated values at the same state (history-conditioned rule)\n", .{ res.states_c1_fail, res.pairs_disagree });
        } else if (res.states_c1_eligible > 0) {
            util.out("NOT FOUND at this contrast level — {d} eligible states, {d} pairs, zero disagreements\n", .{ res.states_c1_eligible, res.pairs_within_budget });
        } else {
            util.out("INCONCLUSIVE — no state with >=2 within-budget values\n", .{});
        }
        util.out("# fresh-start reading: {s}\n", .{if (res.fresh_start_total > 0 and res.fresh_start_agree == res.fresh_start_total) "CONSISTENT — every within-budget shortest-arrival value equals the corrected fixpoint median" else "NOT FULLY CONSISTENT — see cut above (with denominators)"});
    }
    if (f.json_path) |jp| try write_probe_json(jp, G, f, res, perturb);
    return res;
}

fn write_probe_json(path: []const u8, comptime G: type, f: Flags, r: ProbeResult, perturb: ?Perturb) !void {
    const mode_str = if (perturb) |p| (switch (p) { .len_gt_dist => "control-seeded-lengt", .pass_member => "control-seeded-passmember" }) else "probe";
    const c1_v = if (r.states_c1_fail > 0) "FOUND" else "NOT_FOUND";
    const fresh_v = if (r.fresh_start_total > 0 and r.fresh_start_agree == r.fresh_start_total) "CONSISTENT" else "INCONSISTENT";
    var buf: [16384]u8 = undefined;
    var idx: usize = 0;
    const p1 = try std.fmt.bufPrint(buf[idx..],
        \\{{"task_id":"T372","goban":"{s}","mode":"{s}","seed":{d},"instrument":"{s}",
        \\"n_states":{d},"k_short":{d},"k_detour":{d},"budget":{d},"eval":"{s}",
        \\"states":{{"sampled":{d},"reached":{d},"with_value":{d},"c1_eligible":{d},"c1_fail":{d},"c2_eligible":{d},"c2_fail":{d}}},
    , .{ goban_label(G), mode_str, f.seed, STAMP, f.n_states, f.k_short, f.k_detour, f.budget, if (f.eval_ab) "ab" else "plain",
        r.states_sampled, r.states_reached, r.states_with_value, r.states_c1_eligible, r.states_c1_fail, r.states_c2_eligible, r.states_c2_fail });
    idx += p1.len;
    const p2 = try std.fmt.bufPrint(buf[idx..],
        \\"pairs":{{"within_budget":{d},"disagreeing":{d}}},
        \\"evals":{{"total":{d},"within_budget":{d},"tie":{d},"exhausted":{d},"nodes":{d}}},
        \\"histories":{{"total":{d},"short":{d},"detour":{d},"arrival_bad":{d},"sigma_in_arrival":{d}}},
        \\"fresh_start":{{"agree":{d},"total":{d}}},"short_vs_long_witness_states":{d},
        \\"buckets":{{"leh":{d},"pin_t":{d},"pin_l":{d},"pin_h":{d}}},
    , .{ r.pairs_within_budget, r.pairs_disagree,
        r.evals_total, r.evals_within_budget, r.evals_tie, r.evals_exhausted, r.nodes_spent,
        r.hist_total, r.hist_short, r.hist_detour, r.arrival_bad, r.sigma_in_arrival,
        r.fresh_start_agree, r.fresh_start_total, r.c1_witness_states,
        r.buckets[0], r.buckets[1], r.buckets[2], r.buckets[3] });
    idx += p2.len;
    const p3 = try std.fmt.bufPrint(buf[idx..],
        \\"verdict_c1":"{s}","verdict_fresh":"{s}","claims":[],"new_rows":[]}}
    , .{ c1_v, fresh_v });
    idx += p3.len;
    try write_file(path, buf[0..idx]);
}

fn write_file(path: []const u8, content: []const u8) !void {
    try std.Io.Dir.cwd().writeFile(g_io, .{ .sub_path = path, .data = content });
}

// ---- control modes ---------------------------------------------------------

fn run_control_null(comptime G: type, f: Flags) !void {
    const gpa = std.heap.page_allocator;
    util.out("# t372 control-null — same (state, history) evaluated twice must agree ({s})\n", .{goban_label(G)});
    util.out("# params: seed={d} n-states={d} k={d} budget={d} eval={s}\n", .{ f.seed, f.n_states, f.k_short, f.budget, if (f.eval_ab) "ab" else "plain" });
    const reach = try G.build_reach(gpa);
    defer gpa.free(reach);
    const L_tab = try gpa.alloc(i8, G.TOTAL_STATES);
    defer gpa.free(L_tab);
    const H_tab = try gpa.alloc(i8, G.TOTAL_STATES);
    defer gpa.free(H_tab);
    _ = G.fixpoint_corrected(reach, L_tab, H_tab);
    const dist = try gpa.alloc(u32, G.TOTAL_STATES);
    defer gpa.free(dist);
    const parent = try gpa.alloc(u32, G.TOTAL_STATES);
    defer gpa.free(parent);
    const pmk = try gpa.alloc(u8, G.TOTAL_STATES);
    defer gpa.free(pmk);
    const pmc = try gpa.alloc(u8, G.TOTAL_STATES);
    defer gpa.free(pmc);
    try G.bfs_dist_parents(gpa, reach, dist, parent, pmk, pmc);

    // deterministic: same seed convention as the probe
    var prng = std.Random.DefaultPrng.init(f.seed);

    const hd: u16 = 64;
    const visited_states = try gpa.alloc(bool, G.TOTAL_STATES);
    defer gpa.free(visited_states);
    const path_moves = try gpa.alloc(G.Move, 256);
    defer gpa.free(path_moves);
    const collected_moves = try gpa.alloc(G.Move, f.k_short * hd);
    defer gpa.free(collected_moves);
    const collected_lens = try gpa.alloc(u16, f.k_short);
    defer gpa.free(collected_lens);
    const arrival_set = try gpa.alloc(u64, G.ReachWords);
    defer gpa.free(arrival_set);
    const abuf = try gpa.alloc(G.HistoryEntry, G.MAX_PATH);
    defer gpa.free(abuf);

    var mismatches: u64 = 0;
    var pairs: u64 = 0;
    var replay_mismatches: u64 = 0;

    // sample target states flat
    var attempted: u32 = 0;
    var done: u32 = 0;
    while (done < f.n_states and attempted < f.n_states * 100) : (attempted += 1) {
        const lin = prng.random().intRangeAtMost(u64, 0, G.TOTAL_STATES - 1);
        if (!G.visit_get(reach, lin)) continue;
        if (G.decode_linear(lin).passes == 2) continue;
        done += 1;
        const st = G.decode_linear(lin);
        const b = G.unrank_board(st.board);
        @memset(visited_states, false);
        var cc: u32 = 0;
        var cbudget: u64 = 100_000;
        var plen: u16 = 0;
        var rand = prng.random();
        G.collect_shortest(G.root, &G.root_board, lin, 0, &cbudget, dist, path_moves, &plen, visited_states, collected_moves, collected_lens, &cc, 1, hd, &rand);
        if (cc == 0) continue;
        const hlen = collected_lens[0];
        // replay twice: identical arrival?
        var abuf2: [G.MAX_PATH]G.HistoryEntry = undefined;
        const rlen1 = G.replay_arrival(collected_moves[0..hlen], abuf);
        const rlen2 = G.replay_arrival(collected_moves[0..hlen], &abuf2);
        if (rlen1 != rlen2) {
            replay_mismatches += 1;
            continue;
        }
        var replay_same = true;
        for (0..rlen1) |i| {
            if (abuf[i].state.board != abuf2[i].state.board or abuf[i].state.side != abuf2[i].state.side or
                abuf[i].state.ko != abuf2[i].state.ko or abuf[i].state.passes != abuf2[i].state.passes) {
                replay_same = false;
                break;
            }
        }
        if (!replay_same) replay_mismatches += 1;

        G.arrival_bitset(abuf[0 .. rlen1 - 1], arrival_set);
        // evaluate twice, fresh budget + fresh path_set each time
        const r1 = G.eval_state(st, &b, arrival_set, f.budget, f.eval_ab);
        const r2 = G.eval_state(st, &b, arrival_set, f.budget, f.eval_ab);
        pairs += 1;
        const same = (r1.value == r2.value);
        if (!same) mismatches += 1;
        if (done % 25 == 0) progress("control-null {s}: {d}/{d} pairs\n", .{ goban_label(G), done, f.n_states });
    }
    util.out("# null control: {d} (state, history) pairs evaluated twice; mismatches {d}; replay mismatches {d}\n", .{ pairs, mismatches, replay_mismatches });
    util.out("# null verdict: {s}\n", .{if (mismatches == 0 and replay_mismatches == 0) "PASS — harness is deterministic (a mismatch here would break the theory test, not the theory)" else "FAIL — the harness itself is nondeterministic"});
}

fn run_control_seeded(comptime G: type, f: Flags) !void {
    util.out("# t372 control-seeded — injected history dependence must be caught ({s})\n", .{goban_label(G)});
    util.out("# instrument: {s}\n", .{STAMP});
    // two genuine history-consulting perturbations (see Perturb doc: the
    // naive length-parity seed is degenerate — parity equals the state's
    // side — and is deliberately NOT used)
    var f1 = f;
    f1.json_path = null;
    util.out("# --- seeded mode: len_gt_dist (value consults whether the arrival is longer than the shortest) ---\n", .{});
    const r1 = try run_probe(G, f1, .len_gt_dist);
    util.out("# --- seeded mode: pass-member (value consults pass-membership of the arrival) ---\n", .{});
    const r2 = try run_probe(G, f1, .pass_member);
    // OR across seeds: one detected injection proves the probe discriminates
    // (at 3x3 the pass-member feature is uniform within the within-budget
    // sample — near-terminal arrivals all contain a pass — which is a sample
    // property, not an instrument failure; len_gt_dist detects at both sizes).
    const ok = (r1.pairs_disagree > 0 or r1.states_c1_fail > 0) or (r2.pairs_disagree > 0 or r2.states_c1_fail > 0);
    util.out("# seeded verdict: {s} — len_gt_dist detected {d} disagreeing pairs, pass-member detected {d}\n", .{
        if (ok) "PASS — the probe discriminates injected history dependence" else "FAIL — the probe did not catch the injected dependence",
        r1.pairs_disagree, r2.pairs_disagree,
    });
}

// ---- main ------------------------------------------------------------------

fn dispatch(comptime G: type, f: Flags) !void {
    if (std.mem.eql(u8, f.mode, "census")) {
        try run_census(G, f);
    } else if (std.mem.eql(u8, f.mode, "witness")) {
        try run_witness(G, f);
    } else if (std.mem.eql(u8, f.mode, "contrast")) {
        try run_contrast(G, f);
    } else if (std.mem.eql(u8, f.mode, "probe")) {
        _ = try run_probe(G, f, null);
    } else if (std.mem.eql(u8, f.mode, "control-null")) {
        try run_control_null(G, f);
    } else if (std.mem.eql(u8, f.mode, "control-seeded")) {
        try run_control_seeded(G, f);
    } else {
        util.out("usage: weizigo-t372-zrtie <3x2|3x3> <census|witness|contrast|probe|control-null|control-seeded|all> [flags]\n", .{});
        return error.UnknownMode;
    }
}

pub fn main(init: std.process.Init) !void {
    g_io = init.io;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next(); // program name
    var f = Flags{};
    if (args.next()) |a| f.goban = a;
    if (args.next()) |a| f.mode = a;
    while (args.next()) |a| {
        if (std.mem.eql(u8, a, "--seed")) {
            f.seed = std.fmt.parseInt(u64, args.next() orelse "0", 0) catch DEFAULT_SEED;
        } else if (std.mem.eql(u8, a, "--n-states")) {
            f.n_states = std.fmt.parseInt(u32, args.next() orelse "128", 0) catch 128;
        } else if (std.mem.eql(u8, a, "--k-short")) {
            f.k_short = std.fmt.parseInt(u32, args.next() orelse "4", 0) catch 4;
        } else if (std.mem.eql(u8, a, "--k-detour")) {
            f.k_detour = std.fmt.parseInt(u32, args.next() orelse "4", 0) catch 4;
        } else if (std.mem.eql(u8, a, "--max-depth")) {
            f.max_depth = std.fmt.parseInt(u32, args.next() orelse "0", 0) catch 0;
        } else if (std.mem.eql(u8, a, "--budget")) {
            f.budget = std.fmt.parseInt(u64, args.next() orelse "5000000", 0) catch 5_000_000;
        } else if (std.mem.eql(u8, a, "--eval")) {
            const e = args.next() orelse "ab";
            f.eval_ab = std.mem.eql(u8, e, "ab");
        } else if (std.mem.eql(u8, a, "--no-witness")) {
            f.include_witness = false;
        } else if (std.mem.eql(u8, a, "--stratum")) {
            f.stratum = args.next() orelse "all";
        } else if (std.mem.eql(u8, a, "--max-empty")) {
            f.max_empty = std.fmt.parseInt(u32, args.next() orelse "2", 0) catch 2;
        } else if (std.mem.eql(u8, a, "--json")) {
            f.json_path = args.next();
        }
    }
    // run on a big-stack thread: the truncated evaluator recurses along
    // simple paths whose length is bounded only by the reachable state
    // count; a deep continuation at 3x3 can exceed the default 8 MB stack.
    const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, bigStackMain, .{ f });
    thread.join();
}

fn bigStackMain(f: Flags) void {
    if (std.mem.eql(u8, f.goban, "3x2")) {
        dispatch(G32, f) catch |e| {
            std.debug.print("t372 error: {s}\n", .{@errorName(e)});
            std.process.exit(1);
        };
    } else if (std.mem.eql(u8, f.goban, "3x3")) {
        dispatch(G33, f) catch |e| {
            std.debug.print("t372 error: {s}\n", .{@errorName(e)});
            std.process.exit(1);
        };
    } else {
        std.debug.print("unknown goban: {s}\n", .{f.goban});
        std.process.exit(1);
    }
}

// ---------------------------------------------------------------------------
// Tests (tags: rules, witness, fixpoint-anchors, null-control, seeded-control,
// contrast). Verify each leg with `zig test src/t372_zrtie.zig
// --test-filter <tag>` and ASSERT the reported test count.
// ---------------------------------------------------------------------------

test "t372-rules-basic" {
    const G = G32;
    // suicide illegal
    var nb: [G.n + 1]G.Pos = undefined;
    var ns: [G.n + 1]G.State = undefined;
    // a full-white goban, Black to move: any Black placement at an empty
    // cell would be suicide unless it captures. Use (empty, W to move) and
    // verify pass is legal and a placement is legal on the empty goban.
    const m = G.moves(G.root, &nb, &ns);
    try std.testing.expect(m >= 2); // pass + at least one place
    // every move from the root is legal
    for (0..m) |k| try std.testing.expect(G.is_legal(&nb[k]));
}

test "t372-witness" {
    const G = G32;
    const sigma = G.State{ .board = 178, .side = 0, .ko = 6, .passes = 0 };
    const sigma_board = G.unrank_board(178);
    const arrivals = [_]struct { spec: []const u8, expected: i8 }{
        .{ .spec = WITNESS_A, .expected = -3 },
        .{ .spec = WITNESS_B, .expected = -6 },
    };
    for (arrivals) |wa| {
        var play: [64]G.Move = undefined;
        const plen = try parse_witness(G, wa.spec, &play);
        var abuf: [G.MAX_PATH]G.HistoryEntry = undefined;
        const alen = G.replay_arrival(play[0..plen], &abuf);
        try std.testing.expect(alen > 1);
        try std.testing.expectEqual(@as(u16, 0), G.arrival_valid(abuf[0..alen]));
        var aset: [G.ReachWords]u64 = [_]u64{0} ** G.ReachWords;
        G.arrival_bitset(abuf[0 .. alen - 1], &aset);
        const r = G.eval_state(sigma, &sigma_board, &aset, 5_000_000, true);
        try std.testing.expectEqual(wa.expected, r.value orelse {
            std.debug.print("arrival {s} exhausted at 5M nodes\n", .{wa.spec[0..1]});
            return error.TestUnexpectedResult;
        });
    }
}

test "t372-fixpoint-anchors" {
    const G = G32;
    const gpa = std.heap.page_allocator;
    const reach = try G.build_reach(gpa);
    defer gpa.free(reach);
    try std.testing.expectEqual(@as(u64, 2_583), G.count_reach(reach)); // F1 new+1 ground truth
    const L_tab = try gpa.alloc(i8, G.TOTAL_STATES);
    defer gpa.free(L_tab);
    const H_tab = try gpa.alloc(i8, G.TOTAL_STATES);
    defer gpa.free(H_tab);
    _ = G.fixpoint_corrected(reach, L_tab, H_tab);
    try std.testing.expectEqual(@as(u64, 0), G.bellman_residual(reach, L_tab));
    try std.testing.expectEqual(@as(u64, 0), G.bellman_residual(reach, H_tab));
    const inv = G.inversion_violations(reach, L_tab, H_tab);
    try std.testing.expectEqual(@as(u64, 0), inv.violations);
    const wl = (G.State{ .board = 178, .side = 0, .ko = 6, .passes = 0 }).linear();
    try std.testing.expectEqual(@as(i8, -6), L_tab[wl]);
    try std.testing.expectEqual(@as(i8, -6), H_tab[wl]);
}

test "t372-null-control" {
    const G = G32;
    const gpa = std.heap.page_allocator;
    const reach = try G.build_reach(gpa);
    defer gpa.free(reach);
    const L_tab = try gpa.alloc(i8, G.TOTAL_STATES);
    defer gpa.free(L_tab);
    const H_tab = try gpa.alloc(i8, G.TOTAL_STATES);
    defer gpa.free(H_tab);
    _ = G.fixpoint_corrected(reach, L_tab, H_tab);
    const dist = try gpa.alloc(u32, G.TOTAL_STATES);
    defer gpa.free(dist);
    const parent = try gpa.alloc(u32, G.TOTAL_STATES);
    defer gpa.free(parent);
    const pmk = try gpa.alloc(u8, G.TOTAL_STATES);
    defer gpa.free(pmk);
    const pmc = try gpa.alloc(u8, G.TOTAL_STATES);
    defer gpa.free(pmc);
    try G.bfs_dist_parents(gpa, reach, dist, parent, pmk, pmc);
    var prng = std.Random.DefaultPrng.init(42);
    const hd: u16 = 64;
    const visited_states = try gpa.alloc(bool, G.TOTAL_STATES);
    defer gpa.free(visited_states);
    const path_moves = try gpa.alloc(G.Move, 256);
    defer gpa.free(path_moves);
    const collected_moves = try gpa.alloc(G.Move, 8 * hd);
    defer gpa.free(collected_moves);
    const collected_lens = try gpa.alloc(u16, 8);
    defer gpa.free(collected_lens);
    const arrival_set = try gpa.alloc(u64, G.ReachWords);
    defer gpa.free(arrival_set);
    const abuf = try gpa.alloc(G.HistoryEntry, G.MAX_PATH);
    defer gpa.free(abuf);
    var checked: u32 = 0;
    var attempts: u32 = 0;
    while (checked < 16 and attempts < 4000) : (attempts += 1) {
        const lin = prng.random().intRangeAtMost(u64, 0, G.TOTAL_STATES - 1);
        if (!G.visit_get(reach, lin)) continue;
        if (G.decode_linear(lin).passes == 2) continue;
        const st = G.decode_linear(lin);
        const b = G.unrank_board(st.board);
        @memset(visited_states, false);
        var cc: u32 = 0;
        var cbudget: u64 = 50_000;
        var plen: u16 = 0;
        var rand = prng.random();
        G.collect_shortest(G.root, &G.root_board, lin, 0, &cbudget, dist, path_moves, &plen, visited_states, collected_moves, collected_lens, &cc, 1, hd, &rand);
        if (cc == 0) continue;
        const hlen = collected_lens[0];
        const rlen = G.replay_arrival(collected_moves[0..hlen], abuf);
        if (rlen < 2) continue;
        G.arrival_bitset(abuf[0 .. rlen - 1], arrival_set);
        const r1 = G.eval_state(st, &b, arrival_set, 200_000, true);
        const r2 = G.eval_state(st, &b, arrival_set, 200_000, true);
        try std.testing.expectEqual(r1.value, r2.value);
        checked += 1;
    }
    try std.testing.expectEqual(@as(u32, 16), checked);
}

test "t372-seeded-control" {
    const G = G32;
    const gpa = std.heap.page_allocator;
    const reach = try G.build_reach(gpa);
    defer gpa.free(reach);
    const L_tab = try gpa.alloc(i8, G.TOTAL_STATES);
    defer gpa.free(L_tab);
    const H_tab = try gpa.alloc(i8, G.TOTAL_STATES);
    defer gpa.free(H_tab);
    _ = G.fixpoint_corrected(reach, L_tab, H_tab);
    const dist = try gpa.alloc(u32, G.TOTAL_STATES);
    defer gpa.free(dist);
    const parent = try gpa.alloc(u32, G.TOTAL_STATES);
    defer gpa.free(parent);
    const pmk = try gpa.alloc(u8, G.TOTAL_STATES);
    defer gpa.free(pmk);
    const pmc = try gpa.alloc(u8, G.TOTAL_STATES);
    defer gpa.free(pmc);
    try G.bfs_dist_parents(gpa, reach, dist, parent, pmk, pmc);
    var prng = std.Random.DefaultPrng.init(43);
    const hd: u16 = 64;
    const visited_states = try gpa.alloc(bool, G.TOTAL_STATES);
    defer gpa.free(visited_states);
    const path_moves = try gpa.alloc(G.Move, 256);
    defer gpa.free(path_moves);
    const collected_moves = try gpa.alloc(G.Move, 8 * hd);
    defer gpa.free(collected_moves);
    const collected_lens = try gpa.alloc(u16, 8);
    defer gpa.free(collected_lens);
    const arrival_set = try gpa.alloc(u64, G.ReachWords);
    defer gpa.free(arrival_set);
    const abuf = try gpa.alloc(G.HistoryEntry, G.MAX_PATH);
    defer gpa.free(abuf);
    // Find one state with at least one short and one long history, perturb
    // by parity, and require the two values to differ at least once across
    // the sample (probe catches the injected dependence).
    var detected: u32 = 0;
    var attempts: u32 = 0;
    while (detected < 1 and attempts < 8000) : (attempts += 1) {
        const lin = prng.random().intRangeAtMost(u64, 0, G.TOTAL_STATES - 1);
        if (!G.visit_get(reach, lin)) continue;
        if (G.decode_linear(lin).passes == 2) continue;
        const st = G.decode_linear(lin);
        const b = G.unrank_board(st.board);
        const target_dist = dist[@intCast(lin)];
        @memset(visited_states, false);
        var sc: u32 = 0;
        var sbudget: u64 = 50_000;
        var plen: u16 = 0;
        var rand = prng.random();
        G.collect_shortest(G.root, &G.root_board, lin, 0, &sbudget, dist, path_moves, &plen, visited_states, collected_moves, collected_lens, &sc, 2, hd, &rand);
        @memset(visited_states, false);
        var dc: u32 = 0;
        var dbudget: u64 = 50_000;
        plen = 0;
        var rand2 = prng.random();
        G.collect_detours(G.root, &G.root_board, lin, 0, 24, &dbudget, dist, path_moves, &plen, visited_states, collected_moves[sc * hd ..], collected_lens[sc..], &dc, 2, hd, &rand2);
        if (sc == 0 or dc == 0) continue;
        // perturb: value += 1 iff the arrival is longer than the shortest
        // (consults the arrival itself, not the four tuple components)
        var vals: [4]?i8 = [_]?i8{null} ** 4;
        var idx: u32 = 0;
        while (idx < sc + dc) : (idx += 1) {
            const hlen = collected_lens[idx];
            const rlen = G.replay_arrival(collected_moves[idx * hd ..][0..hlen], abuf);
            if (rlen < 2) continue;
            G.arrival_bitset(abuf[0 .. rlen - 1], arrival_set);
            const r = G.eval_state(st, &b, arrival_set, 200_000, true);
            if (r.value) |v| vals[idx] = v + @as(i8, if (hlen > target_dist) 1 else 0);
        }
        var seen: ?i8 = null;
        var differ = false;
        for (vals) |v| {
            if (v == null) continue;
            if (seen == null) {
                seen = v;
            } else if (seen.? != v.?) {
                differ = true;
            }
        }
        if (differ) detected += 1;
    }
    try std.testing.expect(detected >= 1);
}

test "t372-contrast" {
    const G = G32;
    const gpa = std.heap.page_allocator;
    const reach = try G.build_reach(gpa);
    defer gpa.free(reach);
    const dist = try gpa.alloc(u32, G.TOTAL_STATES);
    defer gpa.free(dist);
    const parent = try gpa.alloc(u32, G.TOTAL_STATES);
    defer gpa.free(parent);
    const pmk = try gpa.alloc(u8, G.TOTAL_STATES);
    defer gpa.free(pmk);
    const pmc = try gpa.alloc(u8, G.TOTAL_STATES);
    defer gpa.free(pmc);
    try G.bfs_dist_parents(gpa, reach, dist, parent, pmk, pmc);
    // Take 20 states; for each, old DFS (depth 16, k 8) should miss the
    // shortest in most cases while the new generator always includes it.
    var prng = std.Random.DefaultPrng.init(44);
    const hd: u16 = 64;
    const visited_states = try gpa.alloc(bool, G.TOTAL_STATES);
    defer gpa.free(visited_states);
    const path_moves = try gpa.alloc(G.Move, 256);
    defer gpa.free(path_moves);
    const old_moves = try gpa.alloc(G.Move, 8 * 32);
    defer gpa.free(old_moves);
    const old_lens = try gpa.alloc(u16, 8);
    defer gpa.free(old_lens);
    const new_moves = try gpa.alloc(G.Move, 8 * hd);
    defer gpa.free(new_moves);
    const new_lens = try gpa.alloc(u16, 8);
    defer gpa.free(new_lens);
    var old_hits: u32 = 0;
    var new_hits: u32 = 0;
    var states: u32 = 0;
    var attempts: u32 = 0;
    while (states < 20 and attempts < 6000) : (attempts += 1) {
        const lin = prng.random().intRangeAtMost(u64, 0, G.TOTAL_STATES - 1);
        if (!G.visit_get(reach, lin)) continue;
        if (G.decode_linear(lin).passes == 2) continue;
        if (dist[@intCast(lin)] == 0xFFFFFFFF) continue;
        states += 1;
        const target_dist = dist[@intCast(lin)];
        @memset(visited_states, false);
        var oc: u32 = 0;
        var obudget: u64 = 50_000;
        var plen: u16 = 0;
        var rand = prng.random();
        G.collect_dfs_old(G.root, &G.root_board, lin, 0, 16, &obudget, path_moves, &plen, visited_states, old_moves, old_lens, &oc, 8, 32, &rand);
        var old_hit = false;
        for (0..oc) |i| {
            if (old_lens[i] == target_dist) old_hit = true;
        }
        if (old_hit) old_hits += 1;
        @memset(visited_states, false);
        var nc: u32 = 0;
        var nbudget: u64 = 50_000;
        plen = 0;
        var rand2 = prng.random();
        G.collect_shortest(G.root, &G.root_board, lin, 0, &nbudget, dist, path_moves, &plen, visited_states, new_moves, new_lens, &nc, 4, hd, &rand2);
        var new_hit = false;
        for (0..nc) |i| {
            if (new_lens[i] == target_dist) new_hit = true;
        }
        if (new_hit) new_hits += 1;
    }
    // The new generator must include a shortest path for every state it
    // could collect one for; the old DFS must miss it at least once.
    try std.testing.expectEqual(@as(u32, 20), states);
    try std.testing.expect(new_hits == 20);
    try std.testing.expect(old_hits < 20);
}
