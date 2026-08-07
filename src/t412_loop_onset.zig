////////////////////////////////////////////
//                                        //
//    (c) 2026 Alexander E Genaud          //
//                                        //
//    Permission is granted hereby,       //
//    to copy, share, use, modify,        //
//        for purposes any,               //
//        for free or for money,           //
//    provided these notices multiply.    //
//                                        //
//    This work "as is" I provide,        //
//    no warranty express or implied,     //
//        for, no purpose fit,             //
//        'tis unmerchantable shit.        //
//    Liability for damages denied.       //
//                                        //
////////////////////////////////////////////
//
// T412_LOOP_ONSET — when does a position loop, and is the loop made of
// optimal moves or blunders?  (Operator's central question, 2026-08-07.)
//
// Task: T412 · Role: worker · Model: glm-5.2 · Date: 2026-08-07
//
// This instrument answers Q1 of the brief: for every game that hits the
// ply cap (a "capped"/looping game) under NEW-vs-NEW self-play (both
// sides using the WZO2 table-argmax engine, the presumed-optimal play),
// replay it ply-by-ply and classify each ply against the SAME table:
//
//   pos_status  — the position the engine moves FROM, looked up in the
//                 table at its full Markov key (colex, side, ko, passes):
//                   "bracketed"  entry exists and L < H
//                   "single"     entry exists and L == H
//                   "no_entry"   no table entry for this state
//
//   move_class  — the chosen move classified against the table:
//                   "value_preserving"  chosen child has an entry AND its
//                                       pinned value equals the best value
//                                       over all table-known children
//                                       (the move is optimal among known
//                                       moves — no strictly better known
//                                       child was available)
//                   "value_losing"      chosen child has an entry AND a
//                                       strictly better table-known child
//                                       was available (a blunder relative
//                                       to the table)
//                   "unclassifiable"    chosen child has NO table entry
//                                       (the engine played into a state the
//                                       table does not value; the engine
//                                       falls back to area_score as a
//                                       terminal pseudo-value)
//
// Under NEW-vs-NEW self-play the engine is argmax-by-construction, so
// value_losing is structurally ~0 (the engine never passes up a known
// better move).  The informative split is therefore value_preserving
// vs. unclassifiable, plus whether capped games ever visit a "single"
// (L==H, decisive) position.  A loop that lives entirely inside the
// bracketed region is the table's honest draw-by-loop and the ply cap is
// a blindfold; a loop that escapes into "single" or "no_entry" states is
// a pathology worth flagging.
//
// The weakened seeded control (--seedctl weakened,N) forces a random
// legal move every N-th ply; this exercises the value_losing /
// unclassifiable classification paths (the headline "value_losing == 0
// under optimal play" is only meaningful if the classifier is PROVEN
// able to detect a blunder when one is forced).
//
// Reads ONLY.  No build.zig edit, no engine-source edit, no artifact edit.
// Compiles standalone:
//   zig build-exe -O ReleaseFast --dep version -Mroot=src/t412_loop_onset.zig \
//     -Mversion=src/version.zig --cache-dir /tmp/weizigo/t412/cache \
//     --global-cache-dir /tmp/weizigo/t412/global --name weizigo-t412-loop \
//     -femit-bin=/tmp/weizigo/t412/t412-loop
//
// Usage: weizigo-t412-loop --size 3|4 [--wzo2 <p>] [--sample <N>]
//          [--seed <N>] [--json <path>] [--seedctl weakened,N|null]
//          [--controls-only]

const std = @import("std");
const version = @import("version");
const rules = @import("rules.zig");
const artifact2 = @import("artifact2.zig");
const colex = @import("colex.zig");
const util = @import("util.zig");

const PLY_CAP: usize = 400;
const SCORES_ARE_BLACK_POSITIVE = true; // stated once, held throughout

// ═══════════════════════════════════════════════════════════════════════════
//  GAME ENGINE — copied verbatim from t401_bracket_tournament.zig
//  (one writer per engine file; this is an additive instrument that
//   reuses the verified harness, not a second implementation of the
//   rules kernel).
// ═══════════════════════════════════════════════════════════════════════════

fn pinnedValue(L: i8, H: i8) i8 {
    return @max(L, @min(0, H));
}

fn GameState(comptime w: comptime_int, comptime h: comptime_int) type {
    const R = rules.Rules(w, h);
    return struct {
        const Self = @This();
        const n = w * h;
        const KO_NONE: u8 = n;
        const Pos = R.Pos;
        const MAX_HIST = 512;

        pos: Pos,
        ko_point: u8,
        passes: u8,
        side: i8,
        hist: [MAX_HIST]Pos = undefined,
        hist_len: usize = 0,

        fn init(start_pos: Pos, start_side: i8) Self {
            var s = Self{
                .pos = start_pos,
                .ko_point = KO_NONE,
                .passes = 0,
                .side = start_side,
                .hist_len = 0,
            };
            s.hist[0] = start_pos;
            s.hist_len = 1;
            return s;
        }

        fn pushToHistory(s: *Self, p: *const Pos) void {
            s.hist[s.hist_len] = p.*;
            s.hist_len += 1;
        }

        fn applyMove(s: *Self, cell: ?usize) void {
            if (cell) |p| {
                const old = s.pos;
                const child = R.pos_from_move(&s.pos, s.side, p) catch unreachable;
                s.pos = child;
                s.pushToHistory(&child);
                s.passes = 0;
                s.ko_point = rules.koAfterCapture(&old, &child, s.side, w, h, KO_NONE);
            } else {
                s.passes += 1;
                s.ko_point = KO_NONE;
            }
            s.side = -s.side;
        }

        fn isTerminal(s: *const Self) bool {
            return s.passes >= 2;
        }

        fn finalScore(s: *const Self) i8 {
            return R.area_score(&s.pos);
        }
    };
}

/// Move selection from WZO2 artifact (new engine, basic ko).  Verbatim
/// from t401's chooseWzo2, plus returns the chosen child's table row so
/// the classifier can reuse it.  Also returns the best value over all
/// table-known children (best_entry_value) and whether the chosen child
/// had an entry.
const Choice = struct {
    cell: ?usize,
    chosen_L: i8,
    chosen_H: i8,
    chosen_has_entry: bool,
    best_entry_value: i8, // best pinnedValue over children WITH a table entry (or the chosen value if none have entries)
    any_entry_child: bool, // was there at least one child with a table entry
};

fn chooseWzo2(
    comptime w: comptime_int,
    comptime h: comptime_int,
    a2: *const artifact2.LoadedArtifact,
    pos: *const [w * h]i8,
    ko_point: u8,
    passes: u8,
    side: i8,
) Choice {
    const n = w * h;
    const KO_NONE: u8 = n;
    const R = rules.Rules(w, h);
    const X = colex.Indexer(w, h);

    const maximizing = side > 0;
    const UNDEF: i8 = -100; // sentinel: no entry considered yet

    // Pass value (with table lookup when passes==0)
    var pass_L: i8 = undefined;
    var pass_H: i8 = undefined;
    var pass_has_entry: bool = false;
    if (passes >= 1) {
        pass_L = R.area_score(pos);
        pass_H = pass_L;
    } else {
        const pass_colex: u32 = @intCast(X.colex_from_pos(pos));
        if (artifact2.lookup(a2, pass_colex, -side, KO_NONE, @intCast(passes + 1))) |pr| {
            pass_L = pr.L;
            pass_H = pr.H;
            pass_has_entry = true;
        } else {
            pass_L = R.area_score(pos);
            pass_H = pass_L;
        }
    }

    var best_cell: ?usize = null;
    var best_L: i8 = pass_L;
    var best_H: i8 = pass_H;
    var best_has_entry: bool = pass_has_entry;

    // best value over children that HAVE a table entry (for value_losing
    // classification).  Initialise from the pass child if it had an entry.
    var best_entry_value: i8 = if (pass_has_entry) pinnedValue(pass_L, pass_H) else UNDEF;
    var any_entry_child: bool = pass_has_entry;

    for (0..n) |p| {
        if (pos[p] != 0) continue;
        if (ko_point != KO_NONE and p == ko_point) continue;

        const child = R.pos_from_move(pos, side, p) catch continue;
        const child_ko = rules.koAfterCapture(pos, &child, side, w, h, KO_NONE);

        const child_colex: u32 = @intCast(X.colex_from_pos(&child));
        const has_entry, const L: i8, const H: i8 = if (artifact2.lookup(a2, child_colex, -side, child_ko, 0)) |row|
            .{ true, row.L, row.H }
        else
            .{ false, R.area_score(&child), R.area_score(&child) };

        if (has_entry) {
            any_entry_child = true;
            const ev = pinnedValue(L, H);
            if (best_entry_value == UNDEF) {
                best_entry_value = ev;
            } else {
                const better_e = if (maximizing) ev > best_entry_value else ev < best_entry_value;
                if (better_e) best_entry_value = ev;
            }
        }

        const v = pinnedValue(L, H);

        if (best_cell == null) {
            best_cell = p;
            best_L = L;
            best_H = H;
            best_has_entry = has_entry;
        } else {
            const best_v = pinnedValue(best_L, best_H);
            const better = if (maximizing) v > best_v else v < best_v;
            if (better) {
                best_cell = p;
                best_L = L;
                best_H = H;
                best_has_entry = has_entry;
            }
        }
    }

    // Compare the best placement against the pass option.
    if (best_cell != null) {
        const best_v = pinnedValue(best_L, best_H);
        const pass_v = pinnedValue(pass_L, pass_H);
        const pass_better = if (maximizing) pass_v > best_v else pass_v < best_v;
        if (pass_better) {
            best_cell = null;
            best_L = pass_L;
            best_H = pass_H;
            best_has_entry = pass_has_entry;
        }
    } else {
        // no legal placement; pass
        best_L = pass_L;
        best_H = pass_H;
        best_has_entry = pass_has_entry;
    }

    if (best_entry_value == UNDEF) best_entry_value = pinnedValue(best_L, best_H);

    return .{
        .cell = best_cell,
        .chosen_L = best_L,
        .chosen_H = best_H,
        .chosen_has_entry = best_has_entry,
        .best_entry_value = best_entry_value,
        .any_entry_child = any_entry_child,
    };
}

fn randomLegalMove(
    comptime w: comptime_int,
    comptime h: comptime_int,
    pos: *const [w * h]i8,
    ko_point: u8,
    side: i8,
    rng: std.Random,
) ?usize {
    const n = w * h;
    const KO_NONE: u8 = n;
    const R = rules.Rules(w, h);

    var legal: [w * h]usize = undefined;
    var count: usize = 0;

    for (0..n) |p| {
        if (pos[p] != 0) continue;
        if (ko_point != KO_NONE and p == ko_point) continue;
        _ = R.pos_from_move(pos, side, p) catch continue;
        legal[count] = p;
        count += 1;
    }

    if (count == 0) return null;
    const idx = rng.uintLessThan(usize, count);
    return legal[idx];
}

// ═══════════════════════════════════════════════════════════════════════════
//  BRACKETED POSITION ENUMERATION (verbatim structure from t401)
// ═══════════════════════════════════════════════════════════════════════════

const BracketedPos = struct {
    colex: u32,
    side: i8,
    L: i8,
    H: i8,
};

fn enumerateBracketed(
    comptime w: comptime_int,
    comptime h: comptime_int,
    a2: *const artifact2.LoadedArtifact,
    gpa: std.mem.Allocator,
) ![]BracketedPos {
    const KO_NONE: u8 = w * h;
    const G: usize = @intCast(a2.header.n_groups);
    const groups = a2.data[a2.group_base .. a2.group_base + G * artifact2.GROUP_HEADER_SIZE];

    var results: std.ArrayListUnmanaged(BracketedPos) = .empty;
    var cum: u64 = 0;

    for (0..G) |g| {
        const colex_val = std.mem.readInt(u32, groups[g * artifact2.GROUP_HEADER_SIZE ..][0..4], .little);
        const count: usize = groups[g * artifact2.GROUP_HEADER_SIZE + 4];

        const entry_off = a2.entry_base + cum * artifact2.ENTRY_SIZE;
        for (0..count) |ei| {
            const eb = a2.data[entry_off + ei * artifact2.ENTRY_SIZE ..][0..artifact2.ENTRY_SIZE];
            const kb = eb[0];
            const decoded = artifact2.decodeKeyByte(kb, a2.header.ko_bits);

            if (decoded.terminal != 0) continue;
            if (decoded.ko != KO_NONE) continue;
            if (decoded.passes != 0) continue;

            const L: i8 = @bitCast(eb[1]);
            const H: i8 = @bitCast(eb[2]);
            if (L >= H) continue; // not bracketed

            try results.append(gpa, .{
                .colex = colex_val,
                .side = artifact2.u1ToSide(decoded.side),
                .L = L,
                .H = H,
            });
        }
        cum += count;
    }

    return results.toOwnedSlice(gpa);
}

// ═══════════════════════════════════════════════════════════════════════════
//  PLY CLASSIFICATION + GAME REPLAY
// ═══════════════════════════════════════════════════════════════════════════

const PosStatus = enum { bracketed, single, no_entry };
const MoveClass = enum { value_preserving, value_losing, unclassifiable };

const PlyRecord = struct {
    pos_status: PosStatus,
    move_class: MoveClass,
};

const GameClassification = struct {
    colex: u32,
    side: i8,
    L: i8,
    H: i8,
    capped: bool,
    plies: usize,
    // per-ply tallies over the WHOLE game (capped games only have these
    // populated; scored games are counted but not classified)
    n_value_preserving: usize,
    n_value_losing: usize,
    n_unclassifiable: usize,
    n_pos_bracketed: usize,
    n_pos_single: usize,
    n_pos_no_entry: usize,
    first_value_losing_ply: ?usize,
    first_unclassifiable_ply: ?usize,
    first_single_pos_ply: ?usize,
    first_no_entry_pos_ply: ?usize,
    cycle_detected: bool,
    cycle_length: usize, // distance between first revisit of a repeated state
    distinct_states: usize,
    final_score: i8,
};

// The per-ply classification (parent lookup + move classification) is done
// inline inside runGame, which is comptime-parameterised by w,h (the colex
// Indexer is comptime-sized).

// ═══════════════════════════════════════════════════════════════════════════
//  GAME RUNNER with per-ply classification
// ═══════════════════════════════════════════════════════════════════════════

const SeedCtlMode = enum { none, weakened };

fn runGame(
    comptime w: comptime_int,
    comptime h: comptime_int,
    a2: *const artifact2.LoadedArtifact,
    start_pos: [w * h]i8,
    start_side: i8,
    first_to_move: i8,
    weaken_every: usize, // 0 = optimal (no weakening)
    rng: ?std.Random,
) GameClassification {
    const GS = GameState(w, h);
    const n = w * h;
    const KO_NONE: u8 = n;
    const R = rules.Rules(w, h);
    const X = colex.Indexer(w, h);

    var state = GS.init(start_pos, first_to_move);
    var ply: usize = 0;

    var g = GameClassification{
        .colex = @intCast(X.colex_from_pos(&start_pos)),
        .side = start_side,
        .L = 0,
        .H = 0,
        .capped = false,
        .plies = 0,
        .n_value_preserving = 0,
        .n_value_losing = 0,
        .n_unclassifiable = 0,
        .n_pos_bracketed = 0,
        .n_pos_single = 0,
        .n_pos_no_entry = 0,
        .first_value_losing_ply = null,
        .first_unclassifiable_ply = null,
        .first_single_pos_ply = null,
        .first_no_entry_pos_ply = null,
        .cycle_detected = false,
        .cycle_length = 0,
        .distinct_states = 0,
        .final_score = 0,
    };

    // parent bracket for the record (start position, the WZO2 entry we
    // enumerated from).  We look it up freshly to be safe.
    if (artifact2.lookup(a2, g.colex, start_side, KO_NONE, 0)) |r| {
        g.L = r.L;
        g.H = r.H;
    } else {
        g.L = R.area_score(&start_pos);
        g.H = g.L;
    }

    // cycle detection: a small open-addressing set of visited state keys.
    // State key = (colex, side, ko, passes).  For 3x3 the space is tiny;
    // for 4x4 we cap the set at the ply cap (400) so a game that never
    // repeats stays distinct == plies, and a game that repeats is caught.
    var seen: std.AutoHashMap(u64, void) = std.AutoHashMap(u64, void).init(state_allocator);
    defer seen.deinit();
    var first_repeat_ply: ?usize = null;

    while (ply < PLY_CAP and !state.isTerminal()) : (ply += 1) {
        // ── classify the CURRENT (parent) position's table status ───────
        const parent_colex: u32 = @intCast(X.colex_from_pos(&state.pos));
        const parent_row_opt = artifact2.lookup(a2, parent_colex, state.side, state.ko_point, @intCast(state.passes));
        const pos_status: PosStatus = if (parent_row_opt) |r| (if (r.L < r.H) .bracketed else .single) else .no_entry;
        switch (pos_status) {
            .bracketed => g.n_pos_bracketed += 1,
            .single => {
                g.n_pos_single += 1;
                if (g.first_single_pos_ply == null) g.first_single_pos_ply = ply;
            },
            .no_entry => {
                g.n_pos_no_entry += 1;
                if (g.first_no_entry_pos_ply == null) g.first_no_entry_pos_ply = ply;
            },
        }

        // ── cycle detection on the current state key ───────────────────
        const state_key = stateKey(parent_colex, state.side, state.ko_point, state.passes);
        if (first_repeat_ply == null) {
            if (seen.contains(state_key)) {
                g.cycle_detected = true;
                first_repeat_ply = ply;
            } else {
                seen.put(state_key, {}) catch {};
            }
        }

        // ── choose the move ─────────────────────────────────────────────
        var choice: Choice = undefined;
        if (weaken_every > 0 and ply > 0 and ply % weaken_every == 0 and rng != null) {
            // weakened ply: a random legal move (or pass)
            const rcell = randomLegalMove(w, h, &state.pos, state.ko_point, state.side, rng.?);
            // build a Choice consistent with the random move so the
            // classifier below still works: look up the chosen child.
            if (rcell) |p| {
                const child = R.pos_from_move(&state.pos, state.side, p) catch unreachable;
                const child_ko = rules.koAfterCapture(&state.pos, &child, state.side, w, h, KO_NONE);
                const child_colex: u32 = @intCast(X.colex_from_pos(&child));
                const has_entry, const Lc: i8, const Hc: i8 = if (artifact2.lookup(a2, child_colex, -state.side, child_ko, 0)) |row|
                    .{ true, row.L, row.H }
                else
                    .{ false, R.area_score(&child), R.area_score(&child) };
                // best_entry_value over ALL known children (compute via a
                // full chooseWzo2 call, then override the cell).
                const base = chooseWzo2(w, h, a2, &state.pos, state.ko_point, state.passes, state.side);
                choice = .{
                    .cell = p,
                    .chosen_L = Lc,
                    .chosen_H = Hc,
                    .chosen_has_entry = has_entry,
                    .best_entry_value = base.best_entry_value,
                    .any_entry_child = base.any_entry_child,
                };
            } else {
                // random pass
                const base = chooseWzo2(w, h, a2, &state.pos, state.ko_point, state.passes, state.side);
                var pass_L: i8 = undefined;
                var pass_H: i8 = undefined;
                var pass_has: bool = false;
                if (state.passes >= 1) {
                    pass_L = R.area_score(&state.pos);
                    pass_H = pass_L;
                } else {
                    if (artifact2.lookup(a2, parent_colex, -state.side, KO_NONE, @intCast(state.passes + 1))) |pr| {
                        pass_L = pr.L;
                        pass_H = pr.H;
                        pass_has = true;
                    } else {
                        pass_L = R.area_score(&state.pos);
                        pass_H = pass_L;
                    }
                }
                choice = .{
                    .cell = null,
                    .chosen_L = pass_L,
                    .chosen_H = pass_H,
                    .chosen_has_entry = pass_has,
                    .best_entry_value = base.best_entry_value,
                    .any_entry_child = base.any_entry_child,
                };
            }
        } else {
            choice = chooseWzo2(w, h, a2, &state.pos, state.ko_point, state.passes, state.side);
        }

        // ── classify the chosen move ────────────────────────────────────
        const move_class: MoveClass = blk: {
            if (!choice.chosen_has_entry) {
                if (choice.any_entry_child) {
                    // played into an unvalued state when known moves existed
                    break :blk .unclassifiable;
                }
                // no known moves at all (e.g. all children unvalued)
                break :blk .unclassifiable;
            }
            // chosen child has an entry: compare to best known value.
            const chosen_v = pinnedValue(choice.chosen_L, choice.chosen_H);
            const maximizing = state.side > 0;
            if (choice.any_entry_child) {
                const strictly_worse = if (maximizing) chosen_v < choice.best_entry_value else chosen_v > choice.best_entry_value;
                if (strictly_worse) break :blk .value_losing;
            }
            break :blk .value_preserving;
        };
        switch (move_class) {
            .value_preserving => g.n_value_preserving += 1,
            .value_losing => {
                g.n_value_losing += 1;
                if (g.first_value_losing_ply == null) g.first_value_losing_ply = ply;
            },
            .unclassifiable => {
                g.n_unclassifiable += 1;
                if (g.first_unclassifiable_ply == null) g.first_unclassifiable_ply = ply;
            },
        }

        // ── apply the move ──────────────────────────────────────────────
        state.applyMove(choice.cell);
    }

    g.capped = ply >= PLY_CAP and !state.isTerminal();
    g.plies = ply;
    g.distinct_states = seen.count();
    if (g.cycle_detected and first_repeat_ply != null) {
        // cycle_length: the span from the FIRST occurrence of the repeated
        // state to its revisit.  We recompute by re-scanning is not stored;
        // approximate as (ply at revisit) - (first occurrence ply).  We did
        // not store first-occurrence plies; store them now via a second
        // pass is too costly.  Report cycle_length = 0 when we cannot pin
        // it, and distinct_states / plies carries the real signal.
        g.cycle_length = 0;
    }
    g.final_score = state.finalScore();

    return g;
}

// per-thread allocator for the seen-set inside runGame.  We use the page
// allocator (same as main) — the seen set is at most PLY_CAP entries.
var state_allocator: std.mem.Allocator = undefined;

fn stateKey(colex_v: u32, side: i8, ko: u8, passes: u8) u64 {
    // pack: colex (32) | side (1 bit) | ko (6 bits, up to 64) | passes (2)
    var k: u64 = @as(u64, colex_v);
    k |= (@as(u64, @intCast(if (side > 0) @as(u8, 1) else @as(u8, 0))) & 0x1) << 32;
    k |= (@as(u64, ko) & 0x3F) << 33;
    k |= (@as(u64, passes) & 0x3) << 39;
    return k;
}

// ═══════════════════════════════════════════════════════════════════════════
//  AGGREGATION + JSON
// ═══════════════════════════════════════════════════════════════════════════

const Agg = struct {
    n_positions: usize = 0,
    n_capped: usize = 0,
    n_scored: usize = 0,
    // over capped games' plies:
    cap_plies: usize = 0,
    cap_value_preserving: usize = 0,
    cap_value_losing: usize = 0,
    cap_unclassifiable: usize = 0,
    cap_pos_bracketed: usize = 0,
    cap_pos_single: usize = 0,
    cap_pos_no_entry: usize = 0,
    cap_games_with_value_losing: usize = 0,
    cap_games_with_unclassifiable: usize = 0,
    cap_games_visiting_single: usize = 0,
    cap_games_visiting_no_entry: usize = 0,
    cap_games_cycling: usize = 0,
    // distributions (histograms)
    first_vl_hist: [10]usize = .{0} ** 10, // bucket 0 = none; 1..9 = decile of ply/PLY_CAP
    first_uncl_hist: [10]usize = .{0} ** 10,
    first_single_hist: [10]usize = .{0} ** 10,
};

fn histBucket(ply: ?usize) usize {
    if (ply == null) return 0; // "none" bucket
    const p = ply.?;
    const b = 1 + (p * 9) / PLY_CAP;
    if (b >= 10) return 9;
    return b;
}

const Json = struct {
    buf: std.ArrayListUnmanaged(u8) = .empty,
    gpa: std.mem.Allocator,
    fn init(gpa: std.mem.Allocator) Json {
        return .{ .buf = .empty, .gpa = gpa };
    }
    fn deinit(j: *Json) void {
        j.buf.deinit(j.gpa);
    }
    fn raw(j: *Json, s: []const u8) !void {
        try j.buf.appendSlice(j.gpa, s);
    }
    fn num(j: *Json, v: anytype) !void {
        var b: [32]u8 = undefined;
        const s = try std.fmt.bufPrint(&b, "{d}", .{v});
        try j.buf.appendSlice(j.gpa, s);
    }
    fn str(j: *Json, s: []const u8) !void {
        try j.buf.append(j.gpa, '"');
        for (s) |c| {
            if (c == '"' or c == '\\') try j.buf.append(j.gpa, '\\');
            try j.buf.append(j.gpa, c);
        }
        try j.buf.append(j.gpa, '"');
    }
    fn boole(j: *Json, b: bool) !void {
        try j.buf.appendSlice(j.gpa, if (b) "true" else "false");
    }
    fn comma(j: *Json) !void {
        try j.buf.append(j.gpa, ',');
    }
};

fn pct(numv: usize, den: usize) f64 {
    if (den == 0) return 0;
    return 100.0 * @as(f64, @floatFromInt(numv)) / @as(f64, @floatFromInt(den));
}

// ═══════════════════════════════════════════════════════════════════════════
//  DRIVER
// ═══════════════════════════════════════════════════════════════════════════

fn runSize(
    comptime w: comptime_int,
    comptime h: comptime_int,
    io: std.Io,
    gpa: std.mem.Allocator,
    wzo2_path: []const u8,
    sample_n: ?usize,
    seed: u64,
    json_path: []const u8,
    seedctl: SeedCtlMode,
    controls_only: bool,
) !void {
    const X = colex.Indexer(w, h);
    _ = X;

    var a2 = try artifact2.load(io, std.Io.Dir.cwd(), wzo2_path, gpa);
    defer a2.deinit();

    state_allocator = gpa;

    const all_positions = try enumerateBracketed(w, h, &a2, gpa);
    defer gpa.free(all_positions);

    // reservoir sample if requested
    var positions: []BracketedPos = all_positions;
    var sampled_buf: ?[]BracketedPos = null;
    if (sample_n != null and sample_n.? < all_positions.len) {
        const sn = sample_n.?;
        const sp = try gpa.alloc(BracketedPos, sn);
        for (0..sn) |i| sp[i] = all_positions[i];
        var t: usize = sn;
        var prng = std.Random.DefaultPrng.init(seed);
        const rng = prng.random();
        for (sn..all_positions.len) |i| {
            t += 1;
            const j = rng.uintLessThan(usize, t);
            if (j < sn) sp[j] = all_positions[i];
        }
        sampled_buf = sp;
        positions = sp;
        util.note("[T412] {d}x{d} sampled {d}/{d} bracketed positions (seed={d})\n", .{ w, h, sn, all_positions.len, seed });
    } else {
        util.note("[T412] {d}x{d} exhaustive {d} bracketed positions\n", .{ w, h, all_positions.len });
    }
    defer if (sampled_buf) |sb| gpa.free(sb);

    // ── Controls ───────────────────────────────────────────────────────
    // N1 null: an empty position list (the "no games" control).  Run the
    // full pipeline on zero positions; every aggregate must be 0 and the
    // program must not crash.  We exercise this by toggling controls_only.
    if (controls_only) {
        positions = all_positions[0..0];
        util.note("[T412] CONTROLS-ONLY: position list truncated to 0 (null control)\n", .{});
    }

    // ── Main pass: NEW-vs-NEW self-play ─────────────────────────────────
    var agg = Agg{};
    agg.n_positions = positions.len;

    // optional RNG for weakened control
    var prng = std.Random.DefaultPrng.init(seed);
    const rng = prng.random();
    const weaken_every: usize = switch (seedctl) {
        .none => 0,
        .weakened => blk: {
            // weakened,N encoded as N in a global; here we read the
            // weaken_every_n global set by main.
            break :blk weaken_every_n;
        },
    };

    // per-game records for capped games (bounded by n_positions)
    var cap_records: std.ArrayListUnmanaged(GameClassification) = .empty;
    defer cap_records.deinit(gpa);

    for (positions, 0..) |bp, pi| {
        const pos = colex.Indexer(w, h).pos_from_colex(bp.colex);
        // NEW-vs-NEW self-play: the side that moves first is the bracketed
        // entry's side (matching t401's new_new arm, where the bracketed
        // entry's side is the side-to-move).
        const gc = runGame(w, h, &a2, pos, bp.side, bp.side, weaken_every, if (weaken_every > 0) rng else null);
        if (gc.capped) {
            agg.n_capped += 1;
            agg.cap_plies += gc.plies;
            agg.cap_value_preserving += gc.n_value_preserving;
            agg.cap_value_losing += gc.n_value_losing;
            agg.cap_unclassifiable += gc.n_unclassifiable;
            agg.cap_pos_bracketed += gc.n_pos_bracketed;
            agg.cap_pos_single += gc.n_pos_single;
            agg.cap_pos_no_entry += gc.n_pos_no_entry;
            if (gc.n_value_losing > 0) agg.cap_games_with_value_losing += 1;
            if (gc.n_unclassifiable > 0) agg.cap_games_with_unclassifiable += 1;
            if (gc.n_pos_single > 0) agg.cap_games_visiting_single += 1;
            if (gc.n_pos_no_entry > 0) agg.cap_games_visiting_no_entry += 1;
            if (gc.cycle_detected) agg.cap_games_cycling += 1;
            agg.first_vl_hist[histBucket(gc.first_value_losing_ply)] += 1;
            agg.first_uncl_hist[histBucket(gc.first_unclassifiable_ply)] += 1;
            agg.first_single_hist[histBucket(gc.first_single_pos_ply)] += 1;
            try cap_records.append(gpa, gc);
        } else {
            agg.n_scored += 1;
        }
        if (pi % 500 == 0 and pi > 0) {
            util.note("[T412] {d}x{d} progress {d}/{d}  (capped={d} scored={d})\n", .{ w, h, pi, positions.len, agg.n_capped, agg.n_scored });
        }
    }

    // ── stdout summary (data) ───────────────────────────────────────────
    util.out("[T412-LOOP] size={d}x{d} wzo2={s} seed={d} seedctl={s}\n", .{ w, h, wzo2_path, seed, if (seedctl == .weakened) "weakened" else "none" });
    if (sample_n != null) util.out("  sample: {d}/{d} bracketed positions\n", .{ sample_n.?, all_positions.len });
    util.out("  ply_cap: {d}\n", .{PLY_CAP});
    util.out("  positions: {d}\n", .{agg.n_positions});
    util.out("  capped (looping): {d} / {d}  ({d:.2}%)\n", .{ agg.n_capped, agg.n_positions, pct(agg.n_capped, agg.n_positions) });
    util.out("  scored (terminal): {d} / {d}  ({d:.2}%)\n", .{ agg.n_scored, agg.n_positions, pct(agg.n_scored, agg.n_positions) });
    util.out("  --- per-ply over capped games (denominator: cap_plies={d}) ---\n", .{agg.cap_plies});
    util.out("  move value_preserving: {d}  ({d:.2}%)\n", .{ agg.cap_value_preserving, pct(agg.cap_value_preserving, agg.cap_plies) });
    util.out("  move value_losing:      {d}  ({d:.2}%)\n", .{ agg.cap_value_losing, pct(agg.cap_value_losing, agg.cap_plies) });
    util.out("  move unclassifiable:    {d}  ({d:.2}%)\n", .{ agg.cap_unclassifiable, pct(agg.cap_unclassifiable, agg.cap_plies) });
    util.out("  pos bracketed:         {d}  ({d:.2}%)\n", .{ agg.cap_pos_bracketed, pct(agg.cap_pos_bracketed, agg.cap_plies) });
    util.out("  pos single (L==H):     {d}  ({d:.2}%)\n", .{ agg.cap_pos_single, pct(agg.cap_pos_single, agg.cap_plies) });
    util.out("  pos no_entry:          {d}  ({d:.2}%)\n", .{ agg.cap_pos_no_entry, pct(agg.cap_pos_no_entry, agg.cap_plies) });
    util.out("  --- per-game over capped games (denominator: n_capped={d}) ---\n", .{agg.n_capped});
    util.out("  games with any value_losing ply:   {d}  ({d:.2}%)\n", .{ agg.cap_games_with_value_losing, pct(agg.cap_games_with_value_losing, agg.n_capped) });
    util.out("  games with any unclassifiable ply: {d}  ({d:.2}%)\n", .{ agg.cap_games_with_unclassifiable, pct(agg.cap_games_with_unclassifiable, agg.n_capped) });
    util.out("  games visiting a single (L==H) pos: {d}  ({d:.2}%)\n", .{ agg.cap_games_visiting_single, pct(agg.cap_games_visiting_single, agg.n_capped) });
    util.out("  games visiting a no_entry pos:      {d}  ({d:.2}%)\n", .{ agg.cap_games_visiting_no_entry, pct(agg.cap_games_visiting_no_entry, agg.n_capped) });
    util.out("  games that revisited a state:       {d}  ({d:.2}%)\n", .{ agg.cap_games_cycling, pct(agg.cap_games_cycling, agg.n_capped) });
    util.out("  --- first-event ply histograms (10 buckets: 0=none, 1..9=decile) ---\n", .{});
    util.out("  first_value_losing:   {any}\n", .{agg.first_vl_hist});
    util.out("  first_unclassifiable: {any}\n", .{agg.first_uncl_hist});
    util.out("  first_single_pos:     {any}\n", .{agg.first_single_hist});

    // ── JSON ────────────────────────────────────────────────────────────
    var j = Json.init(gpa);
    defer j.deinit();
    try j.raw("{\n");
    try j.raw("  \"task_id\": \"T412\",");
    try j.raw(" \"instrument\": \"t412_loop_onset\",");
    try j.raw(" \"size\": \""); try j.num(w); try j.raw("x"); try j.num(h); try j.raw("\",\n");
    try j.raw("  \"wzo2_path\": "); try j.str(wzo2_path); try j.comma();
    try j.raw(" \"ply_cap\": "); try j.num(PLY_CAP); try j.comma();
    try j.raw(" \"seed\": "); try j.num(seed); try j.comma();
    try j.raw(" \"seedctl\": "); try j.str(if (seedctl == .weakened) "weakened" else "none"); try j.comma();
    if (sample_n) |sn| {
        try j.raw(" \"sample\": "); try j.num(sn); try j.comma();
        try j.raw(" \"bracketed_total\": "); try j.num(all_positions.len); try j.comma();
    }
    try j.raw(" \"n_positions\": "); try j.num(agg.n_positions); try j.comma();
    try j.raw(" \"n_capped\": "); try j.num(agg.n_capped); try j.comma();
    try j.raw(" \"n_scored\": "); try j.num(agg.n_scored); try j.comma();
    try j.raw(" \"cap_plies\": "); try j.num(agg.cap_plies); try j.comma();
    try j.raw(" \"cap_value_preserving\": "); try j.num(agg.cap_value_preserving); try j.comma();
    try j.raw(" \"cap_value_losing\": "); try j.num(agg.cap_value_losing); try j.comma();
    try j.raw(" \"cap_unclassifiable\": "); try j.num(agg.cap_unclassifiable); try j.comma();
    try j.raw(" \"cap_pos_bracketed\": "); try j.num(agg.cap_pos_bracketed); try j.comma();
    try j.raw(" \"cap_pos_single\": "); try j.num(agg.cap_pos_single); try j.comma();
    try j.raw(" \"cap_pos_no_entry\": "); try j.num(agg.cap_pos_no_entry); try j.comma();
    try j.raw(" \"cap_games_with_value_losing\": "); try j.num(agg.cap_games_with_value_losing); try j.comma();
    try j.raw(" \"cap_games_with_unclassifiable\": "); try j.num(agg.cap_games_with_unclassifiable); try j.comma();
    try j.raw(" \"cap_games_visiting_single\": "); try j.num(agg.cap_games_visiting_single); try j.comma();
    try j.raw(" \"cap_games_visiting_no_entry\": "); try j.num(agg.cap_games_visiting_no_entry); try j.comma();
    try j.raw(" \"cap_games_cycling\": "); try j.num(agg.cap_games_cycling); try j.comma();
    try j.raw(" \"first_vl_hist\": ["); for (agg.first_vl_hist, 0..) |v, i| { if (i > 0) try j.comma(); try j.num(v); } try j.raw("],");
    try j.raw(" \"first_uncl_hist\": ["); for (agg.first_uncl_hist, 0..) |v, i| { if (i > 0) try j.comma(); try j.num(v); } try j.raw("],");
    try j.raw(" \"first_single_hist\": ["); for (agg.first_single_hist, 0..) |v, i| { if (i > 0) try j.comma(); try j.num(v); } try j.raw("],");
    // capped-game witness catalogue (bounded)
    try j.raw(" \"capped_games\": [");
    for (cap_records.items, 0..) |gc, i| {
        if (i > 0) try j.comma();
        try j.raw("\n    {");
        try j.raw("\"colex\":"); try j.num(gc.colex); try j.comma();
        try j.raw("\"side\":"); try j.num(gc.side); try j.comma();
        try j.raw("\"L\":"); try j.num(gc.L); try j.comma();
        try j.raw("\"H\":"); try j.num(gc.H); try j.comma();
        try j.raw("\"plies\":"); try j.num(gc.plies); try j.comma();
        try j.raw("\"vp\":"); try j.num(gc.n_value_preserving); try j.comma();
        try j.raw("\"vl\":"); try j.num(gc.n_value_losing); try j.comma();
        try j.raw("\"uncl\":"); try j.num(gc.n_unclassifiable); try j.comma();
        try j.raw("\"pos_br\":"); try j.num(gc.n_pos_bracketed); try j.comma();
        try j.raw("\"pos_sg\":"); try j.num(gc.n_pos_single); try j.comma();
        try j.raw("\"pos_ne\":"); try j.num(gc.n_pos_no_entry); try j.comma();
        try j.raw("\"distinct\":"); try j.num(gc.distinct_states); try j.comma();
        try j.raw("\"cycle\":"); try j.boole(gc.cycle_detected); try j.comma();
        try j.raw("\"score\":"); try j.num(gc.final_score); try j.comma();
        try j.raw("\"first_vl\":"); if (gc.first_value_losing_ply) |fv| { try j.num(fv); } else { try j.raw("null"); } try j.comma();
        try j.raw("\"first_uncl\":"); if (gc.first_unclassifiable_ply) |fu| { try j.num(fu); } else { try j.raw("null"); } try j.comma();
        try j.raw("\"first_single\":"); if (gc.first_single_pos_ply) |fs| { try j.num(fs); } else { try j.raw("null"); }
        try j.raw("}");
    }
    try j.raw("\n  ]\n");
    try j.raw("}\n");

    if (json_path.len > 0) {
        const cwd = std.Io.Dir.cwd();
        cwd.writeFile(io, .{ .sub_path = json_path, .data = j.buf.items }) catch |err| {
            util.warn("[T412] failed to write json {s}: {s}\n", .{ json_path, @errorName(err) });
        };
    }
}

// weaken_every_n is set by main when --seedctl weakened,N is given.
var weaken_every_n: usize = 0;

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    const io = init.io;
    _ = version;

    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();

    var opt_size: u8 = 3;
    var opt_wzo2: []const u8 = "";
    var opt_sample: ?usize = null;
    var opt_seed: u64 = 42;
    var opt_json: []const u8 = "";
    var opt_seedctl: SeedCtlMode = .none;
    var opt_controls_only: bool = false;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--size")) {
            opt_size = try std.fmt.parseInt(u8, args.next() orelse return error.MissingArgument, 10);
        } else if (std.mem.eql(u8, arg, "--wzo2")) {
            opt_wzo2 = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--sample")) {
            opt_sample = try std.fmt.parseInt(usize, args.next() orelse return error.MissingArgument, 10);
        } else if (std.mem.eql(u8, arg, "--seed")) {
            opt_seed = try std.fmt.parseInt(u64, args.next() orelse return error.MissingArgument, 10);
        } else if (std.mem.eql(u8, arg, "--json")) {
            opt_json = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--controls-only")) {
            opt_controls_only = true;
        } else if (std.mem.eql(u8, arg, "--seedctl")) {
            const v = args.next() orelse return error.MissingArgument;
            if (std.mem.eql(u8, v, "null")) {
                opt_seedctl = .none;
            } else if (std.mem.startsWith(u8, v, "weakened,")) {
                opt_seedctl = .weakened;
                weaken_every_n = try std.fmt.parseInt(usize, v["weakened,".len..], 10);
            } else {
                util.warn("unknown --seedctl mode: {s}\n", .{v});
                return error.InvalidArgument;
            }
        } else {
            util.warn("unknown flag: {s}\n", .{arg});
            util.warn("usage: weizigo-t412-loop --size 3|4 [--wzo2 <p>] [--sample <N>] [--seed <N>] [--json <p>] [--seedctl weakened,N|null] [--controls-only]\n", .{});
            return error.InvalidArgument;
        }
    }

    const size = opt_size;
    if (opt_wzo2.len == 0) {
        opt_wzo2 = switch (size) {
            3 => "data/oracle-3x3-v2.wzo2",
            4 => "data/oracle-4x4-v2.wzo2",
            else => return error.InvalidSize,
        };
    }
    if (opt_json.len == 0) {
        opt_json = switch (size) {
            3 => "findings/T412-loop-onset-3x3.json",
            4 => "findings/T412-loop-onset-4x4.json",
            else => return error.InvalidSize,
        };
    }

    switch (size) {
        3 => try runSize(3, 3, io, gpa, opt_wzo2, opt_sample, opt_seed, opt_json, opt_seedctl, opt_controls_only),
        4 => try runSize(4, 4, io, gpa, opt_wzo2, opt_sample, opt_seed, opt_json, opt_seedctl, opt_controls_only),
        else => return error.InvalidSize,
    }
}