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
// T571_LEAK_PROBE — the 4×4 single-position leak: which entries, and do
// they survive an independent Bellman re-derivation?
//
// Task: T571 · Role: worker (leaf) · Model: claude-opus-5 · Date: 2026-08-22
//
// T412's loop-onset study (docs/research/loop-onset-2026-08-07.md:215-241)
// found 7 of 232 capped 4×4 games visiting a single-valued (L == H) table
// entry, and reported it under a caveat: "the committed 4×4 table is the
// writes-ON build", so the leak might be a table artifact of the
// KNOWN-WRONG `ko_ref >= d` cross-branch memo guard (GLOBAL.F1, ADR-0013).
//
// This instrument does two things the study did not:
//
//   1. PIN THE ENTRIES.  Replay the 7 games (deterministic table-argmax,
//      so a replay from (colex, side) alone reproduces the game bit-for-
//      bit) and dump every L == H parent state actually visited, at its
//      full Markov key (colex, side, ko, passes), with the stored L/H/DTT
//      and whether the arrival carried a pending ko.  T412 counted them;
//      this names them.
//
//   2. RE-DERIVE THEM.  For every distinct L == H state visited, recompute
//      the one-step Bellman image with exp6_solve.zig's OWN successor
//      generator (`genChildren4` / `apply_place4` / base-3 `rank_board4`)
//      instead of rules.zig + colex.zig — the duplication-as-oracle move.
//      A stored value that equals its own Bellman image over children read
//      from the same table is a fixpoint entry; if the leak entries are
//      corrupt, the residual fires.  This is I4 (the G3b Bellman-residual
//      check) aimed at
//      exactly the states under suspicion, rather than a full-table regen.
//
// CONTROLS (a reading without them does not count):
//
//   N1 null control (`--nullctl K`): run the identical residual check over
//      K L == H entries sampled from the table that the leak never
//      touches.  Expected 0 violations; a non-zero count convicts the
//      checker, not the leak.
//
//   S1 seeded-defect control (always on, per state): re-run the residual
//      against a deliberately corrupted stored value (L+1, H+1).  The
//      checker must report a violation for every mutated state.  The
//      headline "0 residual violations" only means something because the
//      checker is shown able to see a defect at the same site.
//
// Reads ONLY.  Additive file: no existing src/ or data/ file is modified,
// no build.zig edit.  The game engine and chooseWzo2 below are copied
// VERBATIM from src/t412_loop_onset.zig (which copied them from
// src/t401_bracket_tournament.zig) so the replay is the same play, not a
// second implementation of it.
//
// Build (ReleaseFast — the 2026-07-29 OOM panic was a Debug build):
//   zig build-exe -O ReleaseFast --dep version -Mroot=src/t571_leak_probe.zig \
//     -Mversion=src/version.zig --cache-dir /tmp/weizigo/t571/cache \
//     --global-cache-dir /tmp/weizigo/t571/global --name weizigo-t571-leak \
//     -femit-bin=/tmp/weizigo/t571/t571-leak
//
// Usage: weizigo-t571-leak [--wzo2 <p>] [--json <p>] [--nullctl K] [--seed N]

const std = @import("std");
const version = @import("version");
const rules = @import("rules.zig");
const artifact2 = @import("artifact2.zig");
const colex = @import("colex.zig");
const util = @import("util.zig");
const exp6 = @import("exp6_solve.zig");

const W: comptime_int = 4;
const H: comptime_int = 4;
const N: usize = W * H;
const KO_NONE: u8 = N;
const PLY_CAP: usize = 400;
const SCORES_ARE_BLACK_POSITIVE = true; // stated once, held throughout

const R = rules.Rules(W, H);
const X = colex.Indexer(W, H);

/// Which child does the engine take when several children tie at the best
/// pinned value?  T412's engine is `.first` (lowest cell index wins, the
/// implicit tie-break of a single-pass argmax loop).  `.dtt` prefers the
/// smallest distance-to-termination.  `.random` is the attribution control:
/// if a random tie-break also removes the leak, the finding is about the
/// DEGENERACY of a fixed tie-break, not about the DTT column specifically.
const TieMode = enum { first, dtt, random };
var tie_rng_state: std.Random.DefaultPrng = undefined;

/// The 7 capped games that visit an L == H position, as pinned by
/// docs/evidence/T412-LOOP-ONSET/loop-onset-4x4-opt.json (the `pos_sg > 0`
/// rows of `capped_games`).  Reproduced at HEAD 2026-08-22 by re-running
/// t412_loop_onset --size 4 --sample 500 --seed 42: same 7, same counts.
const Start = struct { colex: u32, side: i8, t412_pos_sg: usize, t412_first_single: usize };
const STARTS = [_]Start{
    .{ .colex = 301964, .side = 1, .t412_pos_sg = 396, .t412_first_single = 4 },
    .{ .colex = 126959, .side = -1, .t412_pos_sg = 1, .t412_first_single = 2 },
    .{ .colex = 7928091, .side = -1, .t412_pos_sg = 398, .t412_first_single = 2 },
    .{ .colex = 1057330, .side = 1, .t412_pos_sg = 3, .t412_first_single = 3 },
    .{ .colex = 7457548, .side = -1, .t412_pos_sg = 5, .t412_first_single = 2 },
    .{ .colex = 16160524, .side = 1, .t412_pos_sg = 1, .t412_first_single = 1 },
    .{ .colex = 4957429, .side = -1, .t412_pos_sg = 399, .t412_first_single = 1 },
};

// ═══════════════════════════════════════════════════════════════════════════
//  GAME ENGINE — verbatim from t412_loop_onset.zig
// ═══════════════════════════════════════════════════════════════════════════

fn pinnedValue(L: i8, Hv: i8) i8 {
    return @max(L, @min(0, Hv));
}

const GameState = struct {
    const Self = @This();
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
            s.ko_point = rules.koAfterCapture(&old, &child, s.side, W, H, KO_NONE);
        } else {
            s.passes += 1;
            s.ko_point = KO_NONE;
        }
        s.side = -s.side;
    }

    fn isTerminal(s: *const Self) bool {
        return s.passes >= 2;
    }
};

/// Verbatim from t412's chooseWzo2 (the cell choice is all this probe
/// needs, but the whole selection is copied so the replayed game is
/// identical, not merely similar).
fn chooseWzo2(
    a2: *const artifact2.LoadedArtifact,
    pos: *const [N]i8,
    ko_point: u8,
    passes: u8,
    side: i8,
    tie: TieMode,
) ?usize {
    const maximizing = side > 0;

    var pass_L: i8 = undefined;
    var pass_H: i8 = undefined;
    var pass_DTT: u16 = 0; // a passes>=1 pass lands on the double-pass terminal
    if (passes >= 1) {
        pass_L = R.area_score(pos);
        pass_H = pass_L;
        pass_DTT = 0;
    } else {
        const pass_colex: u32 = @intCast(X.colex_from_pos(pos));
        if (artifact2.lookup(a2, pass_colex, -side, KO_NONE, @intCast(passes + 1))) |pr| {
            pass_L = pr.L;
            pass_H = pr.H;
            pass_DTT = pr.DTT;
        } else {
            pass_L = R.area_score(pos);
            pass_H = pass_L;
            pass_DTT = 0;
        }
    }

    var best_cell: ?usize = null;
    var best_L: i8 = pass_L;
    var best_H: i8 = pass_H;
    var best_DTT: u16 = pass_DTT;

    for (0..N) |p| {
        if (pos[p] != 0) continue;
        if (ko_point != KO_NONE and p == ko_point) continue;

        const child = R.pos_from_move(pos, side, p) catch continue;
        const child_ko = rules.koAfterCapture(pos, &child, side, W, H, KO_NONE);

        const child_colex: u32 = @intCast(X.colex_from_pos(&child));
        const Lc: i8, const Hc: i8, const Dc: u16 = if (artifact2.lookup(a2, child_colex, -side, child_ko, 0)) |row|
            .{ row.L, row.H, row.DTT }
        else
            .{ R.area_score(&child), R.area_score(&child), 0 };

        const v = pinnedValue(Lc, Hc);
        if (best_cell == null) {
            best_cell = p;
            best_L = Lc;
            best_H = Hc;
            best_DTT = Dc;
        } else {
            const best_v = pinnedValue(best_L, best_H);
            const better = if (maximizing) v > best_v else v < best_v;
            // T571 variant: among children TIED at the best pinned value,
            // prefer the smaller distance-to-termination.  The T412 engine
            // has no such tie-break, which is the whole question here.
            const tie_better = switch (tie) {
                .first => false,
                .dtt => v == best_v and Dc < best_DTT,
                .random => v == best_v and tie_rng_state.random().boolean(),
            };
            if (better or tie_better) {
                best_cell = p;
                best_L = Lc;
                best_H = Hc;
                best_DTT = Dc;
            }
        }
    }

    if (best_cell != null) {
        const best_v = pinnedValue(best_L, best_H);
        const pass_v = pinnedValue(pass_L, pass_H);
        const pass_better = if (maximizing) pass_v > best_v else pass_v < best_v;
        const pass_tie_better = switch (tie) {
            .first => false,
            .dtt => pass_v == best_v and pass_DTT < best_DTT,
            .random => pass_v == best_v and tie_rng_state.random().boolean(),
        };
        if (pass_better or pass_tie_better) best_cell = null;
    }

    return best_cell;
}

// ═══════════════════════════════════════════════════════════════════════════
//  INDEPENDENT ONE-STEP BELLMAN RE-DERIVATION (exp6 generator)
// ═══════════════════════════════════════════════════════════════════════════

const Residual = struct {
    /// children enumerated by exp6.genChildren4
    n_children: usize,
    /// children that are passes==2 terminals scored by area_score
    n_terminal_children: usize,
    /// children with a WZO2 entry
    n_entry_children: usize,
    /// children with neither (unreachable/illegal — the fixpoint's map.get miss)
    n_missing_children: usize,
    /// recomputed one-step image of L and H; null if no candidate child
    recomputed_L: ?i8,
    recomputed_H: ?i8,
};

/// Mirror of exp6_solve.zig:jacobiWorker's inner update, one state only,
/// reading child values from the WZO2 artifact instead of the fixpoint's
/// compact table.  `bias` is added to every child value read from the
/// table — 0 for the real reading, non-zero for the S1 seeded-defect
/// control (a uniform child shift must move the parent's image by the
/// same amount, so a checker that cannot see it is broken).
fn bellmanImage(
    a2: *const artifact2.LoadedArtifact,
    colex_v: u32,
    side: i8,
    ko: u8,
    passes: u8,
    bias: i8,
) Residual {
    const pos = X.pos_from_colex(colex_v);
    var board4: exp6.Pos4 = undefined;
    for (0..N) |i| board4[i] = pos[i];
    const board_idx = exp6.rank_board4(board4);

    const side_u1: u1 = if (side > 0) 0 else 1; // exp6: 0 = Black to move
    const enc = exp6.encodeState4(board_idx, side_u1, @intCast(ko), @intCast(passes));

    var kids: [exp6.N4 + 1]u64 = undefined;
    var kid_count: usize = 0;
    exp6.genChildren4(enc, &kids, &kid_count);

    const maximizing = side > 0;
    var res = Residual{
        .n_children = kid_count,
        .n_terminal_children = 0,
        .n_entry_children = 0,
        .n_missing_children = 0,
        .recomputed_L = null,
        .recomputed_H = null,
    };

    for (kids[0..kid_count]) |child_enc| {
        const cp = exp6.decodePasses4(child_enc);
        const cb = exp6.decodeBoard4(child_enc);
        const cs = exp6.decodeSide4(child_enc);
        const ck = exp6.decodeKo4(child_enc);

        if (cp == 2) {
            const b = exp6.unrank_board4(cb);
            if (!exp6.genericIsLegal(exp6.N4, &b, exp6.W4, exp6.H4)) continue;
            const sc = exp6.genericAreaScore(exp6.N4, &b, exp6.W4, exp6.H4);
            res.n_terminal_children += 1;
            // the S1 bias is a UNIFORM shift of every child value, so the
            // double-pass terminal children must be shifted too — otherwise
            // a state whose optimum comes from a terminal child is a blind
            // spot in the control (3 of the 45 were, before this).
            takeBest(&res.recomputed_L, sc +| bias, maximizing);
            takeBest(&res.recomputed_H, sc +| bias, maximizing);
            continue;
        }

        const cpos = exp6.unrank_board4(cb);
        var cpos_i8: [N]i8 = undefined;
        for (0..N) |i| cpos_i8[i] = cpos[i];
        const child_colex: u32 = @intCast(X.colex_from_pos(&cpos_i8));
        const child_side: i8 = if (cs == 0) 1 else -1;
        if (artifact2.lookup(a2, child_colex, child_side, @intCast(ck), @intCast(cp))) |row| {
            res.n_entry_children += 1;
            takeBest(&res.recomputed_L, row.L +| bias, maximizing);
            takeBest(&res.recomputed_H, row.H +| bias, maximizing);
        } else {
            res.n_missing_children += 1;
        }
    }

    return res;
}

fn takeBest(slot: *?i8, cand: i8, maximizing: bool) void {
    if (slot.* == null) {
        slot.* = cand;
        return;
    }
    const better = if (maximizing) cand > slot.*.? else cand < slot.*.?;
    if (better) slot.* = cand;
}

// ═══════════════════════════════════════════════════════════════════════════
//  LEAK STATES
// ═══════════════════════════════════════════════════════════════════════════

const LeakState = struct {
    colex: u32,
    side: i8,
    ko: u8,
    passes: u8,
    L: i8,
    H: i8,
    DTT: u8,
    terminal: bool,
    /// visits summed over the 7 replayed games
    visits: usize,
    /// games (index into STARTS) that visited it, as a bitmask
    games_mask: u8,
    /// earliest ply at which any game visited it
    first_ply: usize,
    // residual results, filled in phase 2
    res: Residual = undefined,
    residual_ok: bool = false,
    /// S1: does the checker notice a corrupted stored value at this site?
    mutation_detected: bool = false,
    /// S1: recomputed(bias=+1) - stored.  A uniform +1 shift of every child
    /// value must move the parent's image by exactly +1; anything else is a
    /// checker defect, not a table finding.
    s1_shift_L: i16 = 0,
    s1_shift_H: i16 = 0,
};

const GameRecord = struct {
    colex: u32,
    side: i8,
    L: i8,
    H: i8,
    plies: usize,
    pos_single: usize,
    pos_bracketed: usize,
    pos_no_entry: usize,
    first_single: ?usize,
    distinct_states: usize,
    distinct_single_states: usize,
    /// how many of the L==H arrivals carried a pending ko point
    single_with_ko: usize,
    /// how many of the L==H arrivals were at passes >= 1
    single_with_passes: usize,
    matches_t412: bool,
    terminated: bool = false,
    final_score: i8 = 0,
};

fn stateKey(colex_v: u32, side: i8, ko: u8, passes: u8) u64 {
    var k: u64 = colex_v;
    k |= @as(u64, @intCast(@as(u8, if (side > 0) 0 else 1))) << 32;
    k |= (@as(u64, ko) & 0x3F) << 33;
    k |= (@as(u64, passes) & 0x3) << 39;
    return k;
}

var leak_index: std.AutoHashMap(u64, usize) = undefined;
var leak_states: std.ArrayListUnmanaged(LeakState) = .empty;

fn recordLeak(
    gpa: std.mem.Allocator,
    game_i: usize,
    ply: usize,
    colex_v: u32,
    side: i8,
    ko: u8,
    passes: u8,
    row: artifact2.Row,
) !void {
    const key = stateKey(colex_v, side, ko, passes);
    if (leak_index.get(key)) |idx| {
        leak_states.items[idx].visits += 1;
        leak_states.items[idx].games_mask |= @as(u8, 1) << @intCast(game_i);
        if (ply < leak_states.items[idx].first_ply) leak_states.items[idx].first_ply = ply;
        return;
    }
    try leak_states.append(gpa, .{
        .colex = colex_v,
        .side = side,
        .ko = ko,
        .passes = passes,
        .L = row.L,
        .H = row.H,
        .DTT = row.DTT,
        .terminal = row.terminal,
        .visits = 1,
        .games_mask = @as(u8, 1) << @intCast(game_i),
        .first_ply = ply,
    });
    try leak_index.put(key, leak_states.items.len - 1);
}

fn replay(
    gpa: std.mem.Allocator,
    a2: *const artifact2.LoadedArtifact,
    game_i: usize,
    st: Start,
    tie: TieMode,
    record_leaks: bool,
) !GameRecord {
    const start_pos = X.pos_from_colex(st.colex);
    var pos_i8: [N]i8 = undefined;
    for (0..N) |i| pos_i8[i] = start_pos[i];

    var state = GameState.init(pos_i8, st.side);

    var rec = GameRecord{
        .colex = st.colex,
        .side = st.side,
        .L = 0,
        .H = 0,
        .plies = 0,
        .pos_single = 0,
        .pos_bracketed = 0,
        .pos_no_entry = 0,
        .first_single = null,
        .distinct_states = 0,
        .distinct_single_states = 0,
        .single_with_ko = 0,
        .single_with_passes = 0,
        .matches_t412 = false,
    };
    if (artifact2.lookup(a2, st.colex, st.side, KO_NONE, 0)) |r| {
        rec.L = r.L;
        rec.H = r.H;
    }

    var seen: std.AutoHashMap(u64, void) = std.AutoHashMap(u64, void).init(gpa);
    defer seen.deinit();
    var seen_single: std.AutoHashMap(u64, void) = std.AutoHashMap(u64, void).init(gpa);
    defer seen_single.deinit();

    var ply: usize = 0;
    while (ply < PLY_CAP and !state.isTerminal()) : (ply += 1) {
        const pc: u32 = @intCast(X.colex_from_pos(&state.pos));
        const key = stateKey(pc, state.side, state.ko_point, state.passes);
        try seen.put(key, {});

        if (artifact2.lookup(a2, pc, state.side, state.ko_point, @intCast(state.passes))) |r| {
            if (r.L < r.H) {
                rec.pos_bracketed += 1;
            } else {
                rec.pos_single += 1;
                if (rec.first_single == null) rec.first_single = ply;
                if (state.ko_point != KO_NONE) rec.single_with_ko += 1;
                if (state.passes >= 1) rec.single_with_passes += 1;
                if (!seen_single.contains(key)) {
                    try seen_single.put(key, {});
                    rec.distinct_single_states += 1;
                }
                if (record_leaks) try recordLeak(gpa, game_i, ply, pc, state.side, state.ko_point, state.passes, r);
            }
        } else {
            rec.pos_no_entry += 1;
        }

        const cell = chooseWzo2(a2, &state.pos, state.ko_point, state.passes, state.side, tie);
        state.applyMove(cell);
    }

    rec.plies = ply;
    rec.terminated = state.isTerminal();
    rec.final_score = R.area_score(&state.pos);
    rec.distinct_states = seen.count();
    rec.matches_t412 = (rec.pos_single == st.t412_pos_sg) and
        (rec.first_single != null and rec.first_single.? == st.t412_first_single);
    return rec;
}

// ═══════════════════════════════════════════════════════════════════════════
//  N1 NULL CONTROL — L == H entries the leak never touches
// ═══════════════════════════════════════════════════════════════════════════

const NullCtl = struct {
    checked: usize = 0,
    violations: usize = 0,
    no_candidate: usize = 0,
    first_violation_colex: ?u32 = null,
};

fn nullControl(
    a2: *const artifact2.LoadedArtifact,
    want: usize,
    seed: u64,
) NullCtl {
    var out = NullCtl{};
    if (want == 0) return out;

    const G: usize = @intCast(a2.header.n_groups);
    const groups = a2.data[a2.group_base .. a2.group_base + G * artifact2.GROUP_HEADER_SIZE];

    // Deterministic strided walk over groups (a stride coprime-ish to G),
    // so the control is reproducible from --seed and is not the same slice
    // the leak lives in.
    var prng = std.Random.DefaultPrng.init(seed);
    const rng = prng.random();
    const stride: usize = 1 + rng.uintLessThan(usize, 9973);

    var g: usize = rng.uintLessThan(usize, G);
    var steps: usize = 0;
    while (out.checked < want and steps < G) : (steps += 1) {
        g = (g + stride) % G;
        const colex_val = std.mem.readInt(u32, groups[g * artifact2.GROUP_HEADER_SIZE ..][0..4], .little);
        const count: usize = groups[g * artifact2.GROUP_HEADER_SIZE + 4];
        if (count == 0) continue;

        // re-look-up through the public reader so the control uses the
        // same path as the measurement
        var found = false;
        for ([_]i8{ 1, -1 }) |sd| {
            var ko: u8 = 0;
            while (ko <= KO_NONE) : (ko += 1) {
                var pss: u8 = 0;
                while (pss <= 1) : (pss += 1) {
                    if (found) break;
                    const row = artifact2.lookup(a2, colex_val, sd, ko, @intCast(pss)) orelse continue;
                    if (row.L != row.H) continue;
                    if (leak_index.contains(stateKey(colex_val, sd, ko, pss))) continue;
                    const res = bellmanImage(a2, colex_val, sd, ko, pss, 0);
                    out.checked += 1;
                    if (res.recomputed_L == null or res.recomputed_H == null) {
                        out.no_candidate += 1;
                    } else if (res.recomputed_L.? != row.L or res.recomputed_H.? != row.H) {
                        out.violations += 1;
                        if (out.first_violation_colex == null) out.first_violation_colex = colex_val;
                    }
                    found = true;
                }
                if (found) break;
            }
            if (found) break;
        }
    }
    return out;
}

// ═══════════════════════════════════════════════════════════════════════════
//  T3 POPULATION MODE — the same 500-position sample, both engines
//
//  T2 above answers the question on the 7 pinned games.  This runs the
//  identical bracketed-fresh-start enumeration and reservoir sample as
//  t412_loop_onset (same algorithm, same seed => same 500 positions) and
//  replays every one under BOTH move rules, so the verdict carries a
//  population denominator instead of an anecdote.
// ═══════════════════════════════════════════════════════════════════════════

const BracketedPos = struct { colex: u32, side: i8 };

/// Verbatim structure of t412_loop_onset.zig:enumerateBracketed.
fn enumerateBracketed(a2: *const artifact2.LoadedArtifact, gpa: std.mem.Allocator) ![]BracketedPos {
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
            const Hv: i8 = @bitCast(eb[2]);
            if (L >= Hv) continue;

            try results.append(gpa, .{ .colex = colex_val, .side = artifact2.u1ToSide(decoded.side) });
        }
        cum += count;
    }
    return results.toOwnedSlice(gpa);
}

const PopResult = struct {
    n_positions: usize,
    n_capped: usize,
    n_terminated: usize,
    capped_visiting_single: usize,
    capped_single_plies: usize,
    capped_plies: usize,
    max_terminated_plies: usize,
};

fn population(
    gpa: std.mem.Allocator,
    a2: *const artifact2.LoadedArtifact,
    positions: []const BracketedPos,
    tie: TieMode,
) !PopResult {
    var out = PopResult{
        .n_positions = positions.len,
        .n_capped = 0,
        .n_terminated = 0,
        .capped_visiting_single = 0,
        .capped_single_plies = 0,
        .capped_plies = 0,
        .max_terminated_plies = 0,
    };
    for (positions) |bp| {
        const st = Start{ .colex = bp.colex, .side = bp.side, .t412_pos_sg = 0, .t412_first_single = 0 };
        const rec = try replay(gpa, a2, 0, st, tie, false);
        if (rec.terminated) {
            out.n_terminated += 1;
            if (rec.plies > out.max_terminated_plies) out.max_terminated_plies = rec.plies;
        } else {
            out.n_capped += 1;
            out.capped_plies += rec.plies;
            out.capped_single_plies += rec.pos_single;
            if (rec.pos_single > 0) out.capped_visiting_single += 1;
        }
    }
    return out;
}

// ═══════════════════════════════════════════════════════════════════════════
//  JSON
// ═══════════════════════════════════════════════════════════════════════════

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
    fn optnum(j: *Json, v: anytype) !void {
        if (v) |x| try j.num(x) else try j.raw("null");
    }
};

fn boardString(buf: *[N]u8, colex_v: u32) []const u8 {
    const pos = X.pos_from_colex(colex_v);
    for (0..N) |i| {
        buf[i] = switch (pos[i]) {
            1 => 'X',
            -1 => 'O',
            else => '.',
        };
    }
    return buf[0..N];
}

// ═══════════════════════════════════════════════════════════════════════════
//  DRIVER
// ═══════════════════════════════════════════════════════════════════════════

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    const io = init.io;
    _ = version;

    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();

    var opt_wzo2: []const u8 = "data/oracle-4x4-v2.wzo2";
    var opt_json: []const u8 = "";
    var opt_nullctl: usize = 0;
    var opt_seed: u64 = 42;
    var opt_sample: usize = 0;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--wzo2")) {
            opt_wzo2 = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--json")) {
            opt_json = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--nullctl")) {
            opt_nullctl = try std.fmt.parseInt(usize, args.next() orelse return error.MissingArgument, 10);
        } else if (std.mem.eql(u8, arg, "--sample")) {
            opt_sample = try std.fmt.parseInt(usize, args.next() orelse return error.MissingArgument, 10);
        } else if (std.mem.eql(u8, arg, "--seed")) {
            opt_seed = try std.fmt.parseInt(u64, args.next() orelse return error.MissingArgument, 10);
        } else {
            util.warn("unknown flag: {s}\n", .{arg});
            util.warn("usage: weizigo-t571-leak [--wzo2 <p>] [--json <p>] [--nullctl K] [--sample N] [--seed N]\n", .{});
            return error.InvalidArgument;
        }
    }

    tie_rng_state = std.Random.DefaultPrng.init(opt_seed ^ 0x5bd1e995);

    var a2 = try artifact2.load(io, std.Io.Dir.cwd(), opt_wzo2, gpa);
    defer a2.deinit();

    leak_index = std.AutoHashMap(u64, usize).init(gpa);
    defer leak_index.deinit();
    defer leak_states.deinit(gpa);

    util.out("[T571] table={s}\n", .{opt_wzo2});
    util.out("[T571] replaying {d} pinned capped games (deterministic table-argmax)\n", .{STARTS.len});

    // ── phase 1: replay ────────────────────────────────────────────────
    var games: std.ArrayListUnmanaged(GameRecord) = .empty;
    defer games.deinit(gpa);
    var total_single: usize = 0;
    var n_match: usize = 0;
    for (STARTS, 0..) |st, i| {
        const rec = try replay(gpa, &a2, i, st, .first, true);
        total_single += rec.pos_single;
        if (rec.matches_t412) n_match += 1;
        try games.append(gpa, rec);
        util.out(
            "  game {d}: colex={d} side={d} [L={d},H={d}] plies={d} single={d} (t412 {d}) first_single={?d} distinct={d} single_states={d} with_ko={d} with_passes={d} {s}\n",
            .{
                i,                      st.colex,             rec.side,               rec.L,
                rec.H,                  rec.plies,            rec.pos_single,         st.t412_pos_sg,
                rec.first_single,       rec.distinct_states,  rec.distinct_single_states,
                rec.single_with_ko,     rec.single_with_passes,
                if (rec.matches_t412) "MATCH" else "DIFFERS",
            },
        );
    }

    util.out("\n[T571] pinned L==H arrivals: {d} plies (T412 reported 1203) over {d} distinct states\n", .{ total_single, leak_states.items.len });

    // ── phase 2: independent Bellman re-derivation + S1 seeded defect ──
    var n_ok: usize = 0;
    var n_violation: usize = 0;
    var n_no_candidate: usize = 0;
    var n_mut_detected: usize = 0;
    var n_mut_shift_exact: usize = 0;
    var n_ko_states: usize = 0;
    var n_passes_states: usize = 0;

    for (leak_states.items) |*ls| {
        ls.res = bellmanImage(&a2, ls.colex, ls.side, ls.ko, ls.passes, 0);
        if (ls.res.recomputed_L == null or ls.res.recomputed_H == null) {
            n_no_candidate += 1;
            ls.residual_ok = false;
        } else if (ls.res.recomputed_L.? == ls.L and ls.res.recomputed_H.? == ls.H) {
            ls.residual_ok = true;
            n_ok += 1;
        } else {
            ls.residual_ok = false;
            n_violation += 1;
        }

        // S1 seeded defect at the same site: shift every child value by +1.
        // A sound checker must then see the parent's image move off the
        // stored value.
        const mres = bellmanImage(&a2, ls.colex, ls.side, ls.ko, ls.passes, 1);
        ls.mutation_detected = (mres.recomputed_L == null or mres.recomputed_H == null) or
            (mres.recomputed_L.? != ls.L or mres.recomputed_H.? != ls.H);
        if (ls.mutation_detected) n_mut_detected += 1;
        if (mres.recomputed_L) |v| ls.s1_shift_L = @as(i16, v) - @as(i16, ls.L);
        if (mres.recomputed_H) |v| ls.s1_shift_H = @as(i16, v) - @as(i16, ls.H);
        if (ls.s1_shift_L == 1 and ls.s1_shift_H == 1) n_mut_shift_exact += 1;

        if (ls.ko != KO_NONE) n_ko_states += 1;
        if (ls.passes >= 1) n_passes_states += 1;
    }

    util.out("\n[T571] one-step Bellman residual (exp6 generator, WZO2 child values)\n", .{});
    util.out("  states checked:        {d}\n", .{leak_states.items.len});
    util.out("  fixpoint (L,H) match:  {d}\n", .{n_ok});
    util.out("  residual violations:   {d}\n", .{n_violation});
    util.out("  no candidate child:    {d}\n", .{n_no_candidate});
    util.out("  S1 mutation detected:  {d} / {d}\n", .{ n_mut_detected, leak_states.items.len });
    util.out("  S1 shift exactly +1:   {d} / {d}\n", .{ n_mut_shift_exact, leak_states.items.len });
    util.out("  states with pending ko: {d}\n", .{n_ko_states});
    util.out("  states with passes>=1:  {d}\n", .{n_passes_states});

    // ── T2 DTT-tie-break variant: is the loop the table's or the player's?
    // Same table, same argmax, one change: among children tied at the best
    // pinned value, prefer the smaller distance-to-termination.  If the 7
    // games then terminate, the cap was the engine's missing tie-break, not
    // a property of the position.
    var tb_terminated: usize = 0;
    var tb_max_plies: usize = 0;
    var tb_records: std.ArrayListUnmanaged(GameRecord) = .empty;
    defer tb_records.deinit(gpa);
    util.out("\n[T571] T2 variant — DTT tie-break among value-tied children\n", .{});
    for (STARTS, 0..) |st, i| {
        const rec = try replay(gpa, &a2, i, st, .dtt, false);
        if (rec.terminated) tb_terminated += 1;
        if (rec.plies > tb_max_plies) tb_max_plies = rec.plies;
        try tb_records.append(gpa, rec);
        util.out("  game {d}: colex={d} plies={d} {s} score={d} single={d} bracketed={d}\n", .{
            i, st.colex, rec.plies,
            if (rec.terminated) "TERMINATED" else "CAPPED",
            rec.final_score, rec.pos_single, rec.pos_bracketed,
        });
    }
    util.out("  terminated: {d}/{d}   max plies: {d}\n", .{ tb_terminated, STARTS.len, tb_max_plies });

    // ── T3 population mode ─────────────────────────────────────────────
    var pop_base: ?PopResult = null;
    var pop_tb: ?PopResult = null;
    var pop_rnd: ?PopResult = null;
    var pop_total_bracketed: usize = 0;
    if (opt_sample > 0) {
        const all = try enumerateBracketed(&a2, gpa);
        defer gpa.free(all);
        pop_total_bracketed = all.len;

        // reservoir sample — same algorithm and same seed as
        // t412_loop_onset.zig:runSize, so the 500 positions are the same 500
        var sample_slice: []const BracketedPos = all;
        var sp_buf: ?[]BracketedPos = null;
        if (opt_sample < all.len) {
            const sn = opt_sample;
            const sp = try gpa.alloc(BracketedPos, sn);
            for (0..sn) |i| sp[i] = all[i];
            var t: usize = sn;
            var prng = std.Random.DefaultPrng.init(opt_seed);
            const rng = prng.random();
            for (sn..all.len) |i| {
                t += 1;
                const jj = rng.uintLessThan(usize, t);
                if (jj < sn) sp[jj] = all[i];
            }
            sp_buf = sp;
            sample_slice = sp;
        }
        defer if (sp_buf) |sb| gpa.free(sb);

        util.out("\n[T571] T3 population — {d}/{d} bracketed fresh-start positions (seed={d})\n", .{ sample_slice.len, all.len, opt_seed });
        pop_base = try population(gpa, &a2, sample_slice, .first);
        pop_tb = try population(gpa, &a2, sample_slice, .dtt);
        tie_rng_state = std.Random.DefaultPrng.init(opt_seed ^ 0x5bd1e995);
        pop_rnd = try population(gpa, &a2, sample_slice, .random);
        const b = pop_base.?;
        const t2 = pop_tb.?;
        util.out("  value-only argmax (T412's rule): capped {d}/{d}, capped games visiting L==H {d}, L==H plies {d}/{d}\n", .{ b.n_capped, b.n_positions, b.capped_visiting_single, b.capped_single_plies, b.capped_plies });
        util.out("  + DTT tie-break:                 capped {d}/{d}, capped games visiting L==H {d}, L==H plies {d}/{d}\n", .{ t2.n_capped, t2.n_positions, t2.capped_visiting_single, t2.capped_single_plies, t2.capped_plies });
        const t3 = pop_rnd.?;
        util.out("  + random tie-break (ctl):        capped {d}/{d}, capped games visiting L==H {d}, L==H plies {d}/{d}\n", .{ t3.n_capped, t3.n_positions, t3.capped_visiting_single, t3.capped_single_plies, t3.capped_plies });
        util.out("  terminated: {d} -> {d} (dtt) / {d} (random)   max terminated plies: {d} -> {d} / {d}\n", .{ b.n_terminated, t2.n_terminated, t3.n_terminated, b.max_terminated_plies, t2.max_terminated_plies, t3.max_terminated_plies });
    }

    // ── N1 null control ────────────────────────────────────────────────
    const nc = nullControl(&a2, opt_nullctl, opt_seed);
    if (opt_nullctl > 0) {
        util.out("\n[T571] N1 null control (L==H entries outside the leak set)\n", .{});
        util.out("  checked: {d}  violations: {d}  no_candidate: {d}\n", .{ nc.checked, nc.violations, nc.no_candidate });
    }

    // ── JSON ───────────────────────────────────────────────────────────
    if (opt_json.len == 0) return;

    var j = Json.init(gpa);
    defer j.deinit();
    try j.raw("{\n");
    try j.raw("  \"task_id\": \"T571\",");
    try j.raw(" \"instrument\": \"t571_leak_probe\",");
    try j.raw(" \"size\": \"4x4\",\n");
    try j.raw("  \"wzo2_path\": ");
    try j.str(opt_wzo2);
    try j.comma();
    try j.raw(" \"ply_cap\": ");
    try j.num(PLY_CAP);
    try j.comma();
    try j.raw(" \"n_games\": ");
    try j.num(games.items.len);
    try j.comma();
    try j.raw(" \"games_matching_t412\": ");
    try j.num(n_match);
    try j.comma();
    try j.raw(" \"total_single_plies\": ");
    try j.num(total_single);
    try j.comma();
    try j.raw(" \"distinct_single_states\": ");
    try j.num(leak_states.items.len);
    try j.comma();
    try j.raw(" \"residual_ok\": ");
    try j.num(n_ok);
    try j.comma();
    try j.raw(" \"residual_violations\": ");
    try j.num(n_violation);
    try j.comma();
    try j.raw(" \"residual_no_candidate\": ");
    try j.num(n_no_candidate);
    try j.comma();
    try j.raw(" \"s1_mutation_detected\": ");
    try j.num(n_mut_detected);
    try j.comma();
    try j.raw(" \"s1_shift_exactly_plus_one\": ");
    try j.num(n_mut_shift_exact);
    try j.comma();
    try j.raw(" \"states_with_pending_ko\": ");
    try j.num(n_ko_states);
    try j.comma();
    try j.raw(" \"states_with_passes_ge1\": ");
    try j.num(n_passes_states);
    try j.comma();
    try j.raw(" \"t2_dtt_tiebreak_terminated\": ");
    try j.num(tb_terminated);
    try j.comma();
    try j.raw(" \"t2_dtt_tiebreak_max_plies\": ");
    try j.num(tb_max_plies);
    try j.comma();
    try j.raw("\n  \"t2_dtt_tiebreak_games\": [");
    for (tb_records.items, 0..) |g, i| {
        if (i > 0) try j.comma();
        try j.raw("{\"colex\":");
        try j.num(g.colex);
        try j.raw(",\"plies\":");
        try j.num(g.plies);
        try j.raw(",\"terminated\":");
        try j.boole(g.terminated);
        try j.raw(",\"final_score\":");
        try j.num(g.final_score);
        try j.raw(",\"pos_single\":");
        try j.num(g.pos_single);
        try j.raw(",\"pos_bracketed\":");
        try j.num(g.pos_bracketed);
        try j.raw("}");
    }
    try j.raw("],\n");
    try j.raw("  \"t3_population\": ");
    if (pop_base) |b| {
        const t2 = pop_tb.?;
        try j.raw("{\"bracketed_total\": ");
        try j.num(pop_total_bracketed);
        try j.raw(", \"sample\": ");
        try j.num(b.n_positions);
        try j.raw(", \"seed\": ");
        try j.num(opt_seed);
        try j.raw(",\n    \"value_only_argmax\": {\"capped\": ");
        try j.num(b.n_capped);
        try j.raw(", \"terminated\": ");
        try j.num(b.n_terminated);
        try j.raw(", \"capped_visiting_single\": ");
        try j.num(b.capped_visiting_single);
        try j.raw(", \"capped_single_plies\": ");
        try j.num(b.capped_single_plies);
        try j.raw(", \"capped_plies\": ");
        try j.num(b.capped_plies);
        try j.raw(", \"max_terminated_plies\": ");
        try j.num(b.max_terminated_plies);
        try j.raw("},\n    \"dtt_tiebreak\": {\"capped\": ");
        try j.num(t2.n_capped);
        try j.raw(", \"terminated\": ");
        try j.num(t2.n_terminated);
        try j.raw(", \"capped_visiting_single\": ");
        try j.num(t2.capped_visiting_single);
        try j.raw(", \"capped_single_plies\": ");
        try j.num(t2.capped_single_plies);
        try j.raw(", \"capped_plies\": ");
        try j.num(t2.capped_plies);
        try j.raw(", \"max_terminated_plies\": ");
        try j.num(t2.max_terminated_plies);
        const t3 = pop_rnd.?;
        try j.raw("},\n    \"random_tiebreak_control\": {\"capped\": ");
        try j.num(t3.n_capped);
        try j.raw(", \"terminated\": ");
        try j.num(t3.n_terminated);
        try j.raw(", \"capped_visiting_single\": ");
        try j.num(t3.capped_visiting_single);
        try j.raw(", \"capped_single_plies\": ");
        try j.num(t3.capped_single_plies);
        try j.raw(", \"capped_plies\": ");
        try j.num(t3.capped_plies);
        try j.raw(", \"max_terminated_plies\": ");
        try j.num(t3.max_terminated_plies);
        try j.raw("}}");
    } else {
        try j.raw("null");
    }
    try j.raw(",\n");
    try j.raw("  \"n1_null_control\": {\"checked\": ");
    try j.num(nc.checked);
    try j.raw(", \"violations\": ");
    try j.num(nc.violations);
    try j.raw(", \"no_candidate\": ");
    try j.num(nc.no_candidate);
    try j.raw("},\n");

    try j.raw("  \"games\": [");
    for (games.items, 0..) |g, i| {
        if (i > 0) try j.comma();
        try j.raw("\n    {");
        try j.raw("\"colex\":");
        try j.num(g.colex);
        try j.comma();
        try j.raw("\"side\":");
        try j.num(g.side);
        try j.comma();
        try j.raw("\"L\":");
        try j.num(g.L);
        try j.comma();
        try j.raw("\"H\":");
        try j.num(g.H);
        try j.comma();
        try j.raw("\"plies\":");
        try j.num(g.plies);
        try j.comma();
        try j.raw("\"pos_single\":");
        try j.num(g.pos_single);
        try j.comma();
        try j.raw("\"t412_pos_sg\":");
        try j.num(STARTS[i].t412_pos_sg);
        try j.comma();
        try j.raw("\"pos_bracketed\":");
        try j.num(g.pos_bracketed);
        try j.comma();
        try j.raw("\"pos_no_entry\":");
        try j.num(g.pos_no_entry);
        try j.comma();
        try j.raw("\"first_single\":");
        try j.optnum(g.first_single);
        try j.comma();
        try j.raw("\"distinct_states\":");
        try j.num(g.distinct_states);
        try j.comma();
        try j.raw("\"distinct_single_states\":");
        try j.num(g.distinct_single_states);
        try j.comma();
        try j.raw("\"single_with_ko\":");
        try j.num(g.single_with_ko);
        try j.comma();
        try j.raw("\"single_with_passes\":");
        try j.num(g.single_with_passes);
        try j.comma();
        try j.raw("\"matches_t412\":");
        try j.boole(g.matches_t412);
        try j.raw("}");
    }
    try j.raw("\n  ],\n");

    try j.raw("  \"leak_states\": [");
    var bbuf: [N]u8 = undefined;
    for (leak_states.items, 0..) |ls, i| {
        if (i > 0) try j.comma();
        try j.raw("\n    {");
        try j.raw("\"colex\":");
        try j.num(ls.colex);
        try j.comma();
        try j.raw("\"board\":");
        try j.str(boardString(&bbuf, ls.colex));
        try j.comma();
        try j.raw("\"side\":");
        try j.num(ls.side);
        try j.comma();
        try j.raw("\"ko\":");
        try j.num(ls.ko);
        try j.comma();
        try j.raw("\"ko_none\":");
        try j.num(KO_NONE);
        try j.comma();
        try j.raw("\"passes\":");
        try j.num(ls.passes);
        try j.comma();
        try j.raw("\"L\":");
        try j.num(ls.L);
        try j.comma();
        try j.raw("\"H\":");
        try j.num(ls.H);
        try j.comma();
        try j.raw("\"DTT\":");
        try j.num(ls.DTT);
        try j.comma();
        try j.raw("\"terminal\":");
        try j.boole(ls.terminal);
        try j.comma();
        try j.raw("\"visits\":");
        try j.num(ls.visits);
        try j.comma();
        try j.raw("\"games_mask\":");
        try j.num(ls.games_mask);
        try j.comma();
        try j.raw("\"first_ply\":");
        try j.num(ls.first_ply);
        try j.comma();
        try j.raw("\"n_children\":");
        try j.num(ls.res.n_children);
        try j.comma();
        try j.raw("\"n_terminal_children\":");
        try j.num(ls.res.n_terminal_children);
        try j.comma();
        try j.raw("\"n_entry_children\":");
        try j.num(ls.res.n_entry_children);
        try j.comma();
        try j.raw("\"n_missing_children\":");
        try j.num(ls.res.n_missing_children);
        try j.comma();
        try j.raw("\"recomputed_L\":");
        try j.optnum(ls.res.recomputed_L);
        try j.comma();
        try j.raw("\"recomputed_H\":");
        try j.optnum(ls.res.recomputed_H);
        try j.comma();
        try j.raw("\"residual_ok\":");
        try j.boole(ls.residual_ok);
        try j.comma();
        try j.raw("\"s1_mutation_detected\":");
        try j.boole(ls.mutation_detected);
        try j.comma();
        try j.raw("\"s1_shift_L\":");
        try j.num(ls.s1_shift_L);
        try j.comma();
        try j.raw("\"s1_shift_H\":");
        try j.num(ls.s1_shift_H);
        try j.raw("}");
    }
    try j.raw("\n  ]\n}\n");

    const cwd = std.Io.Dir.cwd();
    cwd.writeFile(io, .{ .sub_path = opt_json, .data = j.buf.items }) catch |err| {
        util.warn("[T571] failed to write json {s}: {s}\n", .{ opt_json, @errorName(err) });
    };
    util.out("\n[T571] wrote {s}\n", .{opt_json});
}
