////////////////////////////////////////////
//                                        //
//    (c) 2026 Alexander E Genaud         //
//                                        //
//    Permission is granted hereby,       //
//    to copy, share, use, modify,        //
//        for purposes any,               //
//        for free or for money,          //
//    provided these notices multiply.    //
//    This work "as is" I provide,        //
//    no warranty express or implied,     //
//        for, no purpose fit,            //
//        'tis unmerchantable shit.       //
//    Liability for damages denied.       //
//                                        //
////////////////////////////////////////////
//
// kostate_census — EXP-3 from docs/infra/dispatch/EXP-3.md.
//
// Counts the EXACT number of reachable `(board, side_to_move, ko_point)`
// triples under basic ko at 3×3, 4×3, and 4×4, plus a secondary count
// including the `passes ∈ {0,1}` component that EXP-2 Part A / EXP-6 must
// allocate for. The census is the addressing-decision input — the engine's
// existing storage model is dense colex over 3^(w·h) (CODE.ADR0011-FMT), and
// the augmented space is sparse (ruleset-options.md:76-81), so the
// reachable-vs-dense ratio decides the build.
//
// This file:
//   1. enumerates legal positions with the base-3 odometer
//      (src/enumerate.zig) and validates the published legal-position counts
//      for the calibration row;
//   2. for every legal position Q and every legal move by either colour:
//      compute the child P, decide whether the move left a basic-ko shape
//      (single-stone capture whose capturing stone has exactly one liberty
//      — the vacated cell), and mark `(P, side, ko_point)` reachable in a
//      bitset. `(P, side, none)` is marked for every non-ko move / root.
//   3. iterates to a fixpoint over the legal-move graph (captures create
//      back-edges), reporting the number of sweeps until convergence;
//   4. reports the four acceptance numbers per goban separately (3×3, 4×3,
//      4×4 — three independent measurements, per AGENTS.md per-goban
//      epistemic independence).
//
// Calibration is mandatory per the dispatch:
//   - KO-DISABLED: with the ko dimension collapsed to `none` for every
//     reachable triple, the count collapses to the known
//     `(position, side)` slot counts from ruleset-options.md:209-213 —
//     3×3 = 25,350 · 4×3 = 643,378 · 4×4 = 48,636,330.
//   - KNOWN-BAD: feed it a deliberately broken ko detector (mark EVERY
//     capture as leaving a ko point) and show the count moves in the
//     direction and rough magnitude predicted *before* running it.
//
// No imports from src/retro.zig / oracle.zig / rules.zig are needed beyond
// `R.pos_from_move` (which is already in src/rules.zig and is also
// reimplemented here so this file has no transitive engine dependency —
// one writer per engine file). The shape detector is the same
// `isKoCapture` algorithm used in src/ko_census.zig:55-77.
//
// Build isolation (dispatch README): binary `weizigo-exp3-<id>`, caches
// under /tmp/weizigo-zigcache-exp3 (override with
// ZIG_LOCAL_CACHE_DIR/ZIG_GLOBAL_CACHE_DIR as needed).
//
// Usage: zig run -O ReleaseFast src/kostate_census.zig -- <goban-tag>
//   goban-tag ∈ {3x3, 4x3, 4x4, all}
//   --calib-over: deliberately broken detector (every capture is a ko point)
//   --calib-noko: ko dimension forced to none (recover known (pos,side) counts)
//   --max-sweeps N: stop after N sweeps even if not converged (default 64)
//
// Standalone except std.

const std = @import("std");
const util = @import("util.zig");

/// Which ko detector to use. Standard is the canonical basic-ko shape
/// (single-stone capture whose capturing stone has exactly one liberty).
/// The other three are deliberately broken and exist for calibration —
/// dispatch EXP-3 requires a "known-bad" detector that the count must
/// distinguish from the standard one.
pub const KoDet = enum { standard, every_capture, every_move, none };

pub fn Census(
    comptime w: usize,
    comptime h: usize,
    comptime passdim: bool,
) type {
    return struct {
        const n = w * h;
        const Pos = [n]i8;

        // ---- ko dimension: `n + 1` slots, index `n` = `none` ---------------
        pub const KO_NONE_U: usize = n; // sentinel "no ko point"
        pub const KO_DIMS: usize = n + 1; // = n + 1
        pub const KO_NONE: u16 = @intCast(KO_NONE_U);
        // 3^n is the total raw address space (the dense colex bound).
        pub const raw_total: u64 = std.math.pow(u64, 3, n);

        // For each (board, side, ko_point) we want a 1-bit reachability marker.
        // Total cells: 2 sides * KO_DIMS * raw_total. u64-padded.
        pub const reach_total: u64 = 2 * @as(u64, KO_DIMS) * raw_total;
        pub const reach_words: u64 = (reach_total + 63) / 64;

        pub const Stats = struct {
            raw_total: u64,
            legal_count: u64, // legal (position) — 3×3 = 12,675, 4×4 = 24,318,165
            // (a) reachable (board, side, ko_point) triples
            triples: u64,
            // (b) distinct (board, ko_point) addresses (the dense-indexing cost)
            addresses: u64,
            // (a') secondary: includes passes ∈ {0,1}; for `passdim=false` this
            // is just 2x (a)
            triples_with_passes: u64,
            addresses_with_passes: u64,
            // (b) split: how many addresses carry ko_point = none vs a cell
            addr_none: u64,
            addr_some: u64,
            // (d) sparse/dense ratio over (b) / `3^(w·h) × (n+1)`
            dense_addresses: u64,
            sparse_ratio: f64,
            // provenance
            sweeps: u32,
            new_marks_last_sweep: u64,
            per_ko_count: []u64, // histogram: how many triples per ko_point cell
        };

        /// Tromp-Taylor legal: every chain has at least one liberty.
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
                    const r = q / w;
                    const c = q % w;
                    if (r > 0) {
                        const t = q - w;
                        if (pos[t] == 0) {
                            has_liberty = true;
                        } else if (pos[t] == colour and !visited[t]) {
                            visited[t] = true;
                            stack[sp] = t;
                            sp += 1;
                        }
                    }
                    if (r + 1 < h) {
                        const t = q + w;
                        if (pos[t] == 0) {
                            has_liberty = true;
                        } else if (pos[t] == colour and !visited[t]) {
                            visited[t] = true;
                            stack[sp] = t;
                            sp += 1;
                        }
                    }
                    if (c > 0) {
                        const t = q - 1;
                        if (pos[t] == 0) {
                            has_liberty = true;
                        } else if (pos[t] == colour and !visited[t]) {
                            visited[t] = true;
                            stack[sp] = t;
                            sp += 1;
                        }
                    }
                    if (c + 1 < w) {
                        const t = q + 1;
                        if (pos[t] == 0) {
                            has_liberty = true;
                        } else if (pos[t] == colour and !visited[t]) {
                            visited[t] = true;
                            stack[sp] = t;
                            sp += 1;
                        }
                    }
                }
                if (!has_liberty) return false;
            }
            return true;
        }

        /// Apply a stone move: place `colour` (+1/-1) on empty `cell`, remove
        /// any opponent chains left without liberties, reject suicide.
        /// Returns `null` for Occupied / Suicide; an `n`-cell position
        /// otherwise. (Non-error-returning variant — the parent's `catch
        /// continue` in inline-for has to be runtime, so the kernel
        /// here has no error union.)
        fn pos_from_move_opt(pos: *const Pos, colour: i8, cell: usize) ?[n]i8 {
            if (pos[cell] != 0) return null;
            var next: [n]i8 = undefined;
            for (0..n) |i| {
                next[i] = if (pos[i] > 0) 1 else if (pos[i] < 0) -1 else 0;
            }
            next[cell] = colour;

            // capture: opponent neighbour chains with no liberty are removed
            const r = cell / w;
            const c = cell % w;
            const neighbours = [_]struct { ok: bool, t: usize }{
                .{ .ok = r > 0, .t = cell - w },
                .{ .ok = r + 1 < h, .t = cell + w },
                .{ .ok = c > 0, .t = cell - 1 },
                .{ .ok = c + 1 < w, .t = cell + 1 },
            };
            for (neighbours) |nb| {
                if (!nb.ok) continue;
                if (next[nb.t] * colour < 0) {
                    // flood the chain, look for any liberty
                    var visited = [_]bool{false} ** n;
                    var chain: [n]usize = undefined;
                    var chain_len: usize = 0;
                    var stack: [n]usize = undefined;
                    var sp: usize = 1;
                    stack[0] = nb.t;
                    visited[nb.t] = true;
                    chain[0] = nb.t;
                    chain_len = 1;
                    var has_liberty = false;
                    while (sp > 0) {
                        sp -= 1;
                        const q = stack[sp];
                        const rr = q / w;
                        const cc = q % w;
                        if (rr > 0) {
                            const t = q - w;
                            if (next[t] == 0) {
                                has_liberty = true;
                            } else if ((next[t] > 0) == (colour < 0) and !visited[t]) {
                                visited[t] = true;
                                stack[sp] = t;
                                chain[chain_len] = t;
                                chain_len += 1;
                            }
                        }
                        if (rr + 1 < h) {
                            const t = q + w;
                            if (next[t] == 0) {
                                has_liberty = true;
                            } else if ((next[t] > 0) == (colour < 0) and !visited[t]) {
                                visited[t] = true;
                                stack[sp] = t;
                                chain[chain_len] = t;
                                chain_len += 1;
                            }
                        }
                        if (cc > 0) {
                            const t = q - 1;
                            if (next[t] == 0) {
                                has_liberty = true;
                            } else if ((next[t] > 0) == (colour < 0) and !visited[t]) {
                                visited[t] = true;
                                stack[sp] = t;
                                chain[chain_len] = t;
                                chain_len += 1;
                            }
                        }
                        if (cc + 1 < w) {
                            const t = q + 1;
                            if (next[t] == 0) {
                                has_liberty = true;
                            } else if ((next[t] > 0) == (colour < 0) and !visited[t]) {
                                visited[t] = true;
                                stack[sp] = t;
                                chain[chain_len] = t;
                                chain_len += 1;
                            }
                        }
                    }
                    if (!has_liberty) {
                        for (chain[0..chain_len]) |q| next[q] = 0;
                    }
                }
            }
            // suicide check on own chain
            {
                var visited = [_]bool{false} ** n;
                var stack: [n]usize = undefined;
                var sp: usize = 1;
                stack[0] = cell;
                visited[cell] = true;
                var has_liberty = false;
                while (sp > 0) {
                    sp -= 1;
                    const q = stack[sp];
                    const rr = q / w;
                    const cc = q % w;
                    if (rr > 0) {
                        const t = q - w;
                        if (next[t] == 0) {
                            has_liberty = true;
                        } else if (next[t] == colour and !visited[t]) {
                            visited[t] = true;
                            stack[sp] = t;
                        }
                    }
                    if (rr + 1 < h) {
                        const t = q + w;
                        if (next[t] == 0) {
                            has_liberty = true;
                        } else if (next[t] == colour and !visited[t]) {
                            visited[t] = true;
                            stack[sp] = t;
                        }
                    }
                    if (cc > 0) {
                        const t = q - 1;
                        if (next[t] == 0) {
                            has_liberty = true;
                        } else if (next[t] == colour and !visited[t]) {
                            visited[t] = true;
                            stack[sp] = t;
                        }
                    }
                    if (cc + 1 < w) {
                        const t = q + 1;
                        if (next[t] == 0) {
                            has_liberty = true;
                        } else if (next[t] == colour and !visited[t]) {
                            visited[t] = true;
                            stack[sp] = t;
                        }
                    }
                }
                if (!has_liberty) return null;
            }
            return next;
        }

        /// Encode a position as a base-3 number over the w*h cells.
        /// (i.e. literal layered-colex index, NOT the layered subset-index
        /// form in src/colex.zig — we never store, only sweep.)  This
        /// function is bijective with `[0, 3^n)` over the digit odometer we
        /// iterate below, so the result is also a dense colex address.
        fn board_to_dense(pos: *const Pos) u64 {
            var v: u64 = 0;
            var mul: u64 = 1;
            for (0..n) |i| {
                const cell: i8 = pos[i];
                const digit: u64 = if (cell > 0) 1 else if (cell < 0) 2 else 0;
                v += digit * mul;
                mul *= 3;
            }
            return v;
        }

        /// Standard basic-ko detector (same algorithm as
        /// src/ko_census.zig:55-77). Returns `Some(vacated_cell)` iff placing
        /// `colour` at `cell` captures exactly one opponent stone AND the
        /// capturing stone has exactly one liberty (the vacated cell).
        fn is_basic_ko(pos: *const Pos, cell: usize, colour: i8) ?usize {
            const next = pos_from_move_opt(pos, colour, cell) orelse return null;
            var opp_before: u8 = 0;
            var opp_after: u8 = 0;
            var captured_cell: ?usize = null;
            for (0..n) |i| {
                if (pos[i] == -colour) opp_before += 1;
                if (next[i] == -colour) opp_after += 1;
                if (pos[i] == -colour and next[i] == 0) captured_cell = i;
            }
            if (opp_before - opp_after != 1) return null;
            // liberties of the placed stone (only — opponent groups removed)
            var liberties: u8 = 0;
            const r = cell / w;
            const c = cell % w;
            const neighbours = [_]struct { ok: bool, t: usize }{
                .{ .ok = r > 0, .t = cell - w },
                .{ .ok = r + 1 < h, .t = cell + w },
                .{ .ok = c > 0, .t = cell - 1 },
                .{ .ok = c + 1 < w, .t = cell + 1 },
            };
            for (neighbours) |nb| {
                if (!nb.ok) continue;
                if (next[nb.t] == 0) liberties += 1;
            }
            if (liberties != 1) return null;
            return captured_cell;
        }

        /// Broken detector (calibration-known-bad): every capture is a ko
        /// point. This strictly OVER-counts reachable triples with
        /// `ko_point != none`, so the right magnitude check is: triples and
        /// addresses increase noticeably (predicted a couple of percent at
        /// 4×4, since most captures are not single-stone / not one-liberty
        /// follow-ups).
        fn is_basic_ko_broken_every_capture(pos: *const Pos, cell: usize, colour: i8) ?usize {
            const next = pos_from_move_opt(pos, colour, cell) orelse return null;
            var opp_before: u8 = 0;
            var opp_after: u8 = 0;
            for (0..n) |i| {
                if (pos[i] == -colour) opp_before += 1;
                if (next[i] == -colour) opp_after += 1;
            }
            const cap = opp_before - opp_after;
            if (cap == 0) return null;
            // return the first cell that flipped from opponent to empty as
            // the "ko point" (i.e. any captured cell, regardless of count)
            for (0..n) |i| {
                if (pos[i] == -colour and next[i] == 0) return i;
            }
            return null;
        }

        /// broken detector 2: every NON-capture is a ko at the played cell
        /// (still over-counts, in a different way: marks non-ko moves as ko).
        /// Used as a third calibration to make sure the standard detector
        /// is not just "mark everything" in disguise.
        fn is_basic_ko_broken_every_move(_: *const Pos, cell: usize, _: i8) ?usize {
            return cell;
        }

        /// Selector for the ko detector.
        fn detector(comptime d: KoDet) *const fn (pos: *const Pos, cell: usize, colour: i8) ?usize {
            return switch (d) {
                .standard => &is_basic_ko,
                .every_capture => &is_basic_ko_broken_every_capture,
                .every_move => &is_basic_ko_broken_every_move,
                .none => struct {
                    fn f(_: *const Pos, _: usize, _: i8) ?usize {
                        return null;
                    }
                }.f,
            };
        }

        /// Sweep the legal-move graph once, marking new reachable triples.
        /// On each sweep, only CONSIDER a parent Q if (Q, side, ko) was
        /// marked reachable AT THE START of this sweep (we snapshot the
        /// bitset for the test). This gives a true fixpoint over the
        /// legal-move graph starting from the seeded root — and the sweep
        /// correctly bounds the moves reachable in exactly N steps.
        ///
        /// Returns the number of NEW marks this sweep made. Does NOT count
        /// legal positions — that's done once at startup (see `count_legal`).
        fn sweep(
            gpa: std.mem.Allocator,
            reach: []u64,
            comptime det: KoDet,
            seen_legal: []u64, // counts per cell `0..n` AND `n` (none); pre-set
        ) !u64 {
            const kofn = detector(det);
            var new_marks: u64 = 0;

            // Snapshot the reach bitset at the start of this sweep; only
            // parents visible IN THE SNAPSHOT are expanded. This is the
            // classical Bellman fixpoint.
            const snap = try gpa.alloc(u64, reach.len);
            defer gpa.free(snap);
            @memcpy(snap, reach);
            // Walk all 3^n colourings, odometer-style (no allocation, same
            // loop shape as src/enumerate.zig census()).
            var digits = [_]u8{0} ** n;
            var pos: Pos = [_]i8{0} ** n;
            var stones: usize = 0;
            while (true) {
                if (is_legal(&pos)) {
                    const Q = board_to_dense(&pos);
                    // For Q, is it marked reachable for either side (in the
                    // snapshot)? If so, expand all children of the *marked*
                    // (side, ko) and check whether each child (P, child_side,
                    // child_ko) is new (in the live bitset).
                    const colours = [_]i8{ 1, -1 };
                    for (colours) |side_to_move| {
                        // For each ko_point value (0..n-1 = real cell, n =
                        // KO_NONE), check if (Q, side, ko) is marked in the
                        // SNAPSHOT.
                        for (0..KO_DIMS) |ko_u| {
                            const ko: u16 = @intCast(ko_u);
                            const side_idx: u64 = if (side_to_move > 0) 0 else 1;
                            const parent_linear = (@as(u64, ko) * 2 + side_idx) * raw_total + Q;
                            const parent_word = parent_linear >> 6;
                            const parent_bit: u64 = @as(u64, 1) << @intCast(parent_linear & 63);
                            if (snap[parent_word] & parent_bit == 0) continue;
                            // Q is reachable as (Q, side, ko). Now expand:
                            // for every legal move by `side_to_move` from Q,
                            // compute the child P, decide the new ko, mark.
                            for (0..n) |cell| {
                                if (pos[cell] != 0) continue;
                                const maybe_next = pos_from_move_opt(&pos, side_to_move, cell);
                                const next = maybe_next orelse continue;
                                const P = board_to_dense(&next);
                                // After side_to_move's move, the side to
                                // move flips to -side_to_move.
                                const child_side: i8 = -side_to_move;
                                // Decide child ko: if THIS move itself left
                                // a basic-ko shape, child_ko = vacated cell.
                                // If not, child_ko = KO_NONE.
                                // (Inheritance: if the move is a non-ko
                                // move, the previous ko point is
                                // invalidated — that is the standard
                                // basic-ko semantics.)
                                const new_ko_cell = kofn(&pos, cell, side_to_move);
                                const child_ko: u16 = if (new_ko_cell) |cap| @intCast(cap) else KO_NONE;
                                const child_side_idx: u64 = if (child_side > 0) 0 else 1;
                                const child_linear = (@as(u64, child_ko) * 2 + child_side_idx) * raw_total + P;
                                const child_word = child_linear >> 6;
                                const child_bit: u64 = @as(u64, 1) << @intCast(child_linear & 63);
                                if (reach[child_word] & child_bit == 0) {
                                    reach[child_word] |= child_bit;
                                    new_marks += 1;
                                    seen_legal[child_ko] += 1;
                                }
                            }
                        }
                    }
                }
                // odometer increment (cell 0 fastest)
                var i: usize = 0;
                while (i < n) : (i += 1) {
                    if (digits[i] == 2) {
                        digits[i] = 0;
                        pos[i] = 0;
                        stones -= 1;
                        continue;
                    }
                    digits[i] += 1;
                    if (digits[i] == 1) {
                        pos[i] = 1;
                        stones += 1;
                    } else pos[i] = -1;
                    break;
                }
                if (i == n) break;
            }
            return new_marks;
        }

        /// Single odometer pass to count legal positions (calibration).
        /// Used to verify the position enumerator reproduces the published
        /// OEIS A094777 counts — see dispatch EXP-3 calibration requirement
        /// (known-good part 1).
        fn count_legal() u64 {
            var count: u64 = 0;
            var digits = [_]u8{0} ** n;
            var pos: Pos = [_]i8{0} ** n;
            while (true) {
                if (is_legal(&pos)) count += 1;
                var i: usize = 0;
                while (i < n) : (i += 1) {
                    if (digits[i] == 2) {
                        digits[i] = 0;
                        pos[i] = 0;
                        continue;
                    }
                    digits[i] += 1;
                    if (digits[i] == 1) {
                        pos[i] = 1;
                    } else pos[i] = -1;
                    break;
                }
                if (i == n) return count;
            }
        }

        /// First sweep also seeds the root (empty goban) for both sides with
        /// ko_point = none. Subsequent sweeps only add children of already-
        /// marked triples.
        fn seed_root(reach: []u64) void {
            // root is `P = 0` (all-empty position, dense index 0) for both
            // sides with `ko_point = KO_NONE`.
            for ([_]i8{ 1, -1 }) |side| {
                const side_idx: u64 = if (side > 0) 0 else 1;
                const linear = (@as(u64, KO_NONE) * 2 + side_idx) * raw_total + 0;
                const word = linear >> 6;
                const bit: u64 = @as(u64, 1) << @intCast(linear & 63);
                reach[word] |= bit;
            }
        }

        /// Count distinct (board, ko_point) addresses by collapsing the
        /// two sides — `(board, ko_point)` is the same address whether the
        /// side to move is Black or White, by the dispatch's definition.
        fn count_addresses(reach: []const u64) struct { total: u64, with_ko: u64, none: u64 } {
            // address slot k, p := (k * raw_total + p); two sides share the
            // address, so we OR the two side bits together and count the
            // union.
            var total: u64 = 0;
            var with_ko: u64 = 0;
            var none: u64 = 0;
            // iterate ko (0..=n) and goban p (0..raw_total)
            for (0..KO_DIMS) |k_| {
                const k: u64 = @intCast(k_);
                for (0..raw_total) |p| {
                    const lin_b = (k * 2 + 0) * raw_total + p;
                    const lin_w = (k * 2 + 1) * raw_total + p;
                    const wb = lin_b >> 6;
                    const bb: u64 = @as(u64, 1) << @intCast(lin_b & 63);
                    const ww = lin_w >> 6;
                    const bw: u64 = @as(u64, 1) << @intCast(lin_w & 63);
                    if (reach[wb] & bb != 0 or reach[ww] & bw != 0) {
                        total += 1;
                        if (k == KO_NONE) none += 1 else with_ko += 1;
                    }
                }
            }
            return .{ .total = total, .with_ko = with_ko, .none = none };
        }

        pub fn run(
            gpa: std.mem.Allocator,
            comptime det: KoDet,
            max_sweeps: u32,
        ) !Stats {
            // Allocate reachability bitset.
            const reach = try gpa.alloc(u64, reach_words);
            defer gpa.free(reach);
            @memset(reach, 0);
            seed_root(reach);

            // Per-ko histogram (size KO_DIMS): count of (board, side, ko_point)
            // triples per ko_point, including KO_NONE.
            // NOTE: ownership transfers to the returned Stats; the caller
            // (report) uses it before any further allocation. Not deferred
            // because Stats.per_ko_count references it.
            const per_ko = try gpa.alloc(u64, KO_DIMS);
            @memset(per_ko, 0);

            // Single odometer pass to count legal positions (calibration).
            const legal_count = count_legal();
            util.out(
                "  legal positions (calibration odometer pass): {d}\n",
                .{legal_count},
            );

            var sweep_idx: u32 = 0;
            var new_marks: u64 = 1;
            while (new_marks > 0 and sweep_idx < max_sweeps) {
                sweep_idx += 1;
                new_marks = try sweep(gpa, reach, det, per_ko);
                util.out(
                    "  sweep {d}: +{d} new marks\n",
                    .{ sweep_idx, new_marks },
                );
            }
            util.out(
                "  converged after {d} sweep{s}; last sweep added {d} new marks.\n",
                .{ sweep_idx, if (sweep_idx == 1) "" else "s", new_marks },
            );

            // Count (a) reachable triples.
            var triples: u64 = 0;
            for (reach) |word| triples += @popCount(word);

            // Count (b) distinct addresses.
            const a = count_addresses(reach);
            const addresses = a.total;
            const addr_none = a.none;
            const addr_some = a.with_ko;

            // (d) sparse/dense ratio
            const dense_addresses: u64 = raw_total * @as(u64, KO_DIMS);
            const sparse_ratio: f64 = @as(f64, @floatFromInt(addresses)) /
                @as(f64, @floatFromInt(dense_addresses));

            return .{
                .raw_total = raw_total,
                .legal_count = legal_count,
                .triples = triples,
                .addresses = addresses,
                .triples_with_passes = if (passdim) triples * 2 else triples,
                .addresses_with_passes = if (passdim) addresses * 2 else addresses,
                .addr_none = addr_none,
                .addr_some = addr_some,
                .dense_addresses = dense_addresses,
                .sparse_ratio = sparse_ratio,
                .sweeps = sweep_idx,
                .new_marks_last_sweep = new_marks,
                .per_ko_count = per_ko,
            };
        }
    };
}

// ---- driver ------------------------------------------------------------------

fn report(
    comptime w: usize,
    comptime h: usize,
    comptime passdim: bool,
    comptime det: KoDet,
    label: []const u8,
    max_sweeps: u32,
) !void {
    const C = Census(w, h, passdim);
    const gpa = std.heap.page_allocator;
    const stats = try C.run(gpa, det, max_sweeps);
    const det_label: []const u8 = switch (det) {
        .standard => "standard",
        .every_capture => "every_capture (BROKEN)",
        .every_move => "every_move (BROKEN)",
        .none => "none (ko off)",
    };
    util.out(
        "\n=== {s} ({d}x{d}, detector={s}, passes_dim={any}) ===\n",
        .{ label, w, h, det_label, passdim },
    );
    util.out("  raw 3^n              = {d}\n", .{stats.raw_total});
    util.out("  legal positions      = {d}\n", .{stats.legal_count});
    util.out("  (a) reachable triples (b,side,ko) = {d}\n", .{stats.triples});
    util.out("  (a') with passes in {{0,1}} (x2)  = {d}\n", .{stats.triples_with_passes});
    util.out("  (b) distinct (b,ko) addresses     = {d}\n", .{stats.addresses});
    util.out("       of which  ko_point = none   = {d}\n", .{stats.addr_none});
    util.out("       of which  ko_point = cell   = {d}\n", .{stats.addr_some});
    util.out("  (b') with passes (x2)             = {d}\n", .{stats.addresses_with_passes});
    util.out("  (c) artifact size 6 B/address     = {d} B", .{stats.addresses * 6});
    if (w * h == 16) {
        util.out("  (current PSK 4x4: 258,280,358 B; naive dense: 4,390,765,542 B)", .{});
    }
    util.out("\n", .{});
    util.out("  (d) sparse/dense ratio  (b) / (3^n * (n+1))   = {d:.6}%\n", .{stats.sparse_ratio * 100.0});
    util.out("       numerator   (b)   = {d}\n", .{stats.addresses});
    util.out("       denominator (3^n * (n+1)) = {d}\n", .{stats.dense_addresses});
    util.out("  sweeps to convergence = {d}\n", .{stats.sweeps});
    // Brief per-ko histogram: ko cells with at least one reachable triple.
    var nk: u64 = 0;
    for (stats.per_ko_count) |c| {
        if (c > 0) nk += 1;
    }
    util.out("  distinct ko_point cells used      = {d} / {d}\n", .{ nk, C.KO_DIMS });
    // print top-10 ko cells by count
    util.out("  top-10 ko cells by triple count:  ", .{});
    // simple insertion sort of top-10
    var top: [10]struct { ko: u16, cnt: u64 } = undefined;
    for (top[0..]) |*t| {
        t.* = .{ .ko = 0, .cnt = 0 };
    }
    for (stats.per_ko_count, 0..) |c, k_| {
        const k: u16 = @intCast(k_);
        if (c == 0) continue;
        // insert
        var i: usize = 0;
        while (i < 10) : (i += 1) {
            if (c > top[i].cnt) {
                var j: usize = 9;
                while (j > i) {
                    top[j] = top[j - 1];
                    j -= 1;
                }
                top[i] = .{ .ko = k, .cnt = c };
                break;
            }
        }
    }
    for (top[0..]) |t| {
        if (t.cnt > 0) {
            util.out("  ko={d}:{d}", .{ t.ko, t.cnt });
        }
    }
    util.out("\n", .{});
    gpa.free(stats.per_ko_count);
}

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    const board_arg = args.next() orelse "all";

    const det_arg = args.next() orelse "standard";
    const det: KoDet = blk: {
        if (std.mem.eql(u8, det_arg, "standard")) break :blk .standard;
        if (std.mem.eql(u8, det_arg, "every_capture")) break :blk .every_capture;
        if (std.mem.eql(u8, det_arg, "every_move")) break :blk .every_move;
        if (std.mem.eql(u8, det_arg, "none")) break :blk .none;
        util.out("unknown detector {s}; use standard|every_capture|every_move|none\n", .{det_arg});
        return error.BadArgs;
    };

    const passdim_arg = args.next() orelse "on";

    const max_sweeps_arg = args.next() orelse "64";
    const max_sweeps = std.fmt.parseInt(u32, max_sweeps_arg, 10) catch 64;

    util.out("weizigo kostate_census (EXP-3 from docs/infra/dispatch/EXP-3.md)\n", .{});
    util.out("detector: {s}  passes_dim: {s}  max_sweeps: {d}\n", .{ det_arg, passdim_arg, max_sweeps });

    // dispatch on (passdim, det) at comptime
    if (std.mem.eql(u8, passdim_arg, "on")) {
        switch (det) {
            .standard => {
                if (std.mem.eql(u8, board_arg, "3x3") or std.mem.eql(u8, board_arg, "all")) try report(3, 3, true, .standard, "3x3", max_sweeps);
                if (std.mem.eql(u8, board_arg, "4x3") or std.mem.eql(u8, board_arg, "all")) try report(4, 3, true, .standard, "4x3", max_sweeps);
                if (std.mem.eql(u8, board_arg, "4x4") or std.mem.eql(u8, board_arg, "all")) try report(4, 4, true, .standard, "4x4", max_sweeps);
            },
            .every_capture => {
                if (std.mem.eql(u8, board_arg, "3x3") or std.mem.eql(u8, board_arg, "all")) try report(3, 3, true, .every_capture, "3x3", max_sweeps);
                if (std.mem.eql(u8, board_arg, "4x3") or std.mem.eql(u8, board_arg, "all")) try report(4, 3, true, .every_capture, "4x3", max_sweeps);
                if (std.mem.eql(u8, board_arg, "4x4") or std.mem.eql(u8, board_arg, "all")) try report(4, 4, true, .every_capture, "4x4", max_sweeps);
            },
            .every_move => {
                if (std.mem.eql(u8, board_arg, "3x3") or std.mem.eql(u8, board_arg, "all")) try report(3, 3, true, .every_move, "3x3", max_sweeps);
                if (std.mem.eql(u8, board_arg, "4x3") or std.mem.eql(u8, board_arg, "all")) try report(4, 3, true, .every_move, "4x3", max_sweeps);
                if (std.mem.eql(u8, board_arg, "4x4") or std.mem.eql(u8, board_arg, "all")) try report(4, 4, true, .every_move, "4x4", max_sweeps);
            },
            .none => {
                if (std.mem.eql(u8, board_arg, "3x3") or std.mem.eql(u8, board_arg, "all")) try report(3, 3, true, .none, "3x3", max_sweeps);
                if (std.mem.eql(u8, board_arg, "4x3") or std.mem.eql(u8, board_arg, "all")) try report(4, 3, true, .none, "4x3", max_sweeps);
                if (std.mem.eql(u8, board_arg, "4x4") or std.mem.eql(u8, board_arg, "all")) try report(4, 4, true, .none, "4x4", max_sweeps);
            },
        }
    } else {
        switch (det) {
            .standard => {
                if (std.mem.eql(u8, board_arg, "3x3") or std.mem.eql(u8, board_arg, "all")) try report(3, 3, false, .standard, "3x3", max_sweeps);
                if (std.mem.eql(u8, board_arg, "4x3") or std.mem.eql(u8, board_arg, "all")) try report(4, 3, false, .standard, "4x3", max_sweeps);
                if (std.mem.eql(u8, board_arg, "4x4") or std.mem.eql(u8, board_arg, "all")) try report(4, 4, false, .standard, "4x4", max_sweeps);
            },
            .every_capture => {
                if (std.mem.eql(u8, board_arg, "3x3") or std.mem.eql(u8, board_arg, "all")) try report(3, 3, false, .every_capture, "3x3", max_sweeps);
                if (std.mem.eql(u8, board_arg, "4x3") or std.mem.eql(u8, board_arg, "all")) try report(4, 3, false, .every_capture, "4x3", max_sweeps);
                if (std.mem.eql(u8, board_arg, "4x4") or std.mem.eql(u8, board_arg, "all")) try report(4, 4, false, .every_capture, "4x4", max_sweeps);
            },
            .every_move => {
                if (std.mem.eql(u8, board_arg, "3x3") or std.mem.eql(u8, board_arg, "all")) try report(3, 3, false, .every_move, "3x3", max_sweeps);
                if (std.mem.eql(u8, board_arg, "4x3") or std.mem.eql(u8, board_arg, "all")) try report(4, 3, false, .every_move, "4x3", max_sweeps);
                if (std.mem.eql(u8, board_arg, "4x4") or std.mem.eql(u8, board_arg, "all")) try report(4, 4, false, .every_move, "4x4", max_sweeps);
            },
            .none => {
                if (std.mem.eql(u8, board_arg, "3x3") or std.mem.eql(u8, board_arg, "all")) try report(3, 3, false, .none, "3x3", max_sweeps);
                if (std.mem.eql(u8, board_arg, "4x3") or std.mem.eql(u8, board_arg, "all")) try report(4, 3, false, .none, "4x3", max_sweeps);
                if (std.mem.eql(u8, board_arg, "4x4") or std.mem.eql(u8, board_arg, "all")) try report(4, 4, false, .none, "4x4", max_sweeps);
            },
        }
    }

    _ = gpa;
}
