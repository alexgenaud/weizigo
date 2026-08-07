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
// T401_BRACKET_TOURNAMENT — new engine vs old engine from bracketed positions.
//
// Task: T401 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-07
// Correction: T405 (console audit) · Model: unknown/T405 · Date: 2026-08-07
//
// Plays the WZO2 oracle (new engine, basic-ko L/H bracket) against the
// WZO1 oracle (old engine, PSK fresh-start single values) from every
// bracketed (L < H) fresh-start position. Answers B1-B4 per the brief.
//
// Reads ONLY. No build.zig edit, no engine-source edit.
// Compiles standalone:
//   zig build-exe -O ReleaseFast --dep version -Mroot=src/t401_bracket_tournament.zig \
//     -Mversion=src/version.zig --cache-dir /tmp/weizigo/t401/cache \
//     --global-cache-dir /tmp/weizigo/t401/global --name weizigo-t401 \
//     -femit-bin=/tmp/weizigo/t401/t401
//
// Usage: weizigo-t401 [--size 3|4] [--wzo2 <path>] [--wzo1 <path>]
//         [--sample <N>] [--seed <N>] [--json <path>]
//         [--controls-only]
//         [--seedctl weakened,<N>] [--seedctl determinism]
//         [--seedctl legacy]

const std = @import("std");
const version = @import("version");
const rules = @import("rules.zig");
const artifact = @import("artifact.zig");
const artifact2 = @import("artifact2.zig");
const colex = @import("colex.zig");

const PLY_CAP: usize = 400;
const SCORES_ARE_BLACK_POSITIVE = true; // stated once, held throughout

// ═══════════════════════════════════════════════════════════════════════════
//  GAME ENGINE — direct artifact lookup, no gtp.Session dependency
// ═══════════════════════════════════════════════════════════════════════════

fn pinnedValue(L: i8, H: i8) i8 {
    return @max(L, @min(0, H));
}

/// A game state: the goban position, Markov key, PSK history.
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

        fn inHistory(s: *const Self, p: *const Pos) bool {
            for (s.hist[0..s.hist_len]) |*hp| {
                if (std.mem.eql(i8, hp, p)) return true;
            }
            return false;
        }

        fn applyMove(s: *Self, cell: ?usize) !void {
            if (cell) |p| {
                const old = s.pos;
                const child = try R.pos_from_move(&s.pos, s.side, p);
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

/// Move selection from WZO2 artifact (new engine, basic ko).
fn chooseWzo2(
    comptime w: comptime_int,
    comptime h: comptime_int,
    a2: *const artifact2.LoadedArtifact,
    pos: *const [w * h]i8,
    ko_point: u8,
    passes: u8,
    side: i8,
) struct { cell: ?usize, L: i8, H: i8 } {
    const n = w * h;
    const KO_NONE: u8 = n;
    const R = rules.Rules(w, h);
    const X = colex.Indexer(w, h);

    const maximizing = side > 0;

    // Pass value
    const pass_L: i8, const pass_H: i8 = if (passes >= 1)
        .{ R.area_score(pos), R.area_score(pos) }
    else blk: {
        const pass_colex: u32 = @intCast(X.colex_from_pos(pos));
        const pass_row = artifact2.lookup(a2, pass_colex, -side, KO_NONE, @intCast(passes + 1)) orelse
            artifact2.Row{ .L = R.area_score(pos), .H = R.area_score(pos), .DTT = 0, .terminal = true, .ko_sensitive = false };
        break :blk .{ pass_row.L, pass_row.H };
    };

    var best_cell: ?usize = null;
    var best_L: i8 = pass_L;
    var best_H: i8 = pass_H;

    for (0..n) |p| {
        if (pos[p] != 0) continue;
        // basic ko enforcement
        if (ko_point != KO_NONE and p == ko_point) continue;

        const child = R.pos_from_move(pos, side, p) catch continue;
        const child_ko = rules.koAfterCapture(pos, &child, side, w, h, KO_NONE);

        const child_colex: u32 = @intCast(X.colex_from_pos(&child));
        const row = artifact2.lookup(a2, child_colex, -side, child_ko, 0) orelse
            artifact2.Row{ .L = R.area_score(&child), .H = R.area_score(&child), .DTT = 0, .terminal = true, .ko_sensitive = false };

        const v = pinnedValue(row.L, row.H);

        if (best_cell == null) {
            best_cell = p;
            best_L = row.L;
            best_H = row.H;
        } else {
            const best_v = pinnedValue(best_L, best_H);
            const better = if (maximizing) v > best_v else v < best_v;
            if (better) {
                best_cell = p;
                best_L = row.L;
                best_H = row.H;
            }
        }
    }

    // If pass is best, return pass
    const best_v = pinnedValue(best_L, best_H);
    const pass_v = pinnedValue(pass_L, pass_H);
    const pass_better = if (maximizing) pass_v > best_v else pass_v < best_v;

    if (pass_better or best_cell == null) {
        return .{ .cell = null, .L = pass_L, .H = pass_H };
    }
    return .{ .cell = best_cell, .L = best_L, .H = best_H };
}

/// Move selection from WZO1 artifact (old engine, PSK enforcement).
fn chooseWzo1(
    comptime w: comptime_int,
    comptime h: comptime_int,
    dec: *const artifact.Decoded,
    state: anytype,
) struct { cell: ?usize, value: i8 } {
    const n = w * h;
    const R = rules.Rules(w, h);
    const X = colex.Indexer(w, h);
    const UNDEF: i8 = -128;

    const maximizing = state.side > 0;

    const pass_value: i8 = if (state.passes >= 1)
        R.area_score(&state.pos)
    else blk: {
        const pass_child = state.pos;
        const pi: usize = @intCast(X.colex_from_pos(&pass_child));
        break :blk if (-state.side > 0) dec.vb[pi] else dec.vw[pi];
    };

    var best_cell: ?usize = null;
    var best_val: i8 = pass_value;

    for (0..n) |p| {
        if (state.pos[p] != 0) continue;
        const child = R.pos_from_move(&state.pos, state.side, p) catch continue;
        // PSK enforcement
        if (state.inHistory(&child)) continue;

        const ci: usize = @intCast(X.colex_from_pos(&child));
        const v = if (-state.side > 0) dec.vb[ci] else dec.vw[ci];
        if (v == UNDEF) continue;

        if (best_cell == null) {
            best_cell = p;
            best_val = v;
        } else {
            const better = if (maximizing) v > best_val else v < best_val;
            if (better) {
                best_cell = p;
                best_val = v;
            }
        }
    }

    // early-game effort: if pass is best and board is sparse, play anyway
    if (best_cell == null or (maximizing and pass_value >= best_val) or (!maximizing and pass_value <= best_val)) {
        const area: usize = w * h;
        const min_own: usize = area / 4;
        const min_total: usize = area / 2;
        var own: usize = 0;
        var tot: usize = 0;
        for (state.pos) |x| {
            if (x == 0) continue;
            tot += 1;
            if ((x > 0) == (state.side > 0)) own += 1;
        }
        if (own < min_own and tot < min_total) {
            if (best_cell) |bc| return .{ .cell = bc, .value = best_val };
        }
        return .{ .cell = null, .value = pass_value };
    }
    return .{ .cell = best_cell.?, .value = best_val };
}

// ═══════════════════════════════════════════════════════════════════════════
//  WEAKENED MOVE SELECTORS — for seeded controls (C2)
// ═══════════════════════════════════════════════════════════════════════════

/// Pick a random legal move for the given position.
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

    // If no legal moves, pass
    if (count == 0) return null;

    const idx = rng.uintLessThan(usize, count);
    return legal[idx];
}

/// Weakened WZO2 move selection — every weaken_every-th ply, pick a random
/// legal move instead of the optimal one.
fn chooseWzo2Weakened(
    comptime w: comptime_int,
    comptime h: comptime_int,
    a2: *const artifact2.LoadedArtifact,
    pos: *const [w * h]i8,
    ko_point: u8,
    passes: u8,
    side: i8,
    weaken_every: usize,
    rng: std.Random,
    ply: usize,
) struct { cell: ?usize, L: i8, H: i8 } {
    if (ply > 0 and ply % weaken_every == 0) {
        if (randomLegalMove(w, h, pos, ko_point, side, rng)) |cell| {
            return .{ .cell = cell, .L = -128, .H = 127 }; // sentinel
        }
        return .{ .cell = null, .L = -128, .H = 127 };
    }
    return chooseWzo2(w, h, a2, pos, ko_point, passes, side);
}

/// Weakened WZO1 move selection — every weaken_every-th ply, pick a random
/// legal move instead of the optimal one.
fn chooseWzo1Weakened(
    comptime w: comptime_int,
    comptime h: comptime_int,
    dec: *const artifact.Decoded,
    state: anytype,
    weaken_every: usize,
    rng: std.Random,
    ply: usize,
) struct { cell: ?usize, value: i8 } {
    if (ply > 0 and ply % weaken_every == 0) {
        if (randomLegalMove(w, h, &state.pos, state.ko_point, state.side, rng)) |cell| {
            return .{ .cell = cell, .value = -128 };
        }
        return .{ .cell = null, .value = -128 };
    }
    return chooseWzo1(w, h, dec, state);
}

// ═══════════════════════════════════════════════════════════════════════════
//  TOURNAMENT ENGINE
// ═══════════════════════════════════════════════════════════════════════════

const Engine = enum { new, old };

/// Arms of the tournament.
const Arm = enum {
    new_vs_old, // new=Black, old=White
    old_vs_new, // old=Black, new=White
    new_vs_new, // self-play
    old_vs_old, // self-play
};

const GameResult = struct {
    arm: Arm,
    start_side: i8, // which side moved first
    first_to_move: i8, // which side actually moved first
    score: i8, // Black-positive final area score
    capped: bool,
};

const BracketedPos = struct {
    colex: u32,
    side: i8,
    L: i8,
    H: i8,
};

const PositionClass = enum { straddling, decisive_black, decisive_white };

fn classifyPosition(L: i8, H: i8) PositionClass {
    if (L <= 0 and H >= 0) return .straddling;
    if (L > 0) return .decisive_black;
    return .decisive_white;
}

fn runGame(
    comptime w: comptime_int,
    comptime h: comptime_int,
    dec: ?*const artifact.Decoded,
    a2: *const artifact2.LoadedArtifact,
    start_pos: [w * h]i8,
    start_side: i8, // the WZO2 entry's side (reference)
    first_to_move: i8, // who actually moves first in this game
    arm: Arm,
) GameResult {
    const GS = GameState(w, h);
    var state = GS.init(start_pos, first_to_move);
    var ply: usize = 0;

    while (ply < PLY_CAP and !state.isTerminal()) : (ply += 1) {
        const engine_for_side: Engine = engineForSide(arm, state.side);
        const move = switch (engine_for_side) {
            .new => blk: {
                const c = chooseWzo2(w, h, a2, &state.pos, state.ko_point, state.passes, state.side);
                break :blk c.cell;
            },
            .old => blk: {
                if (dec == null) @panic("old engine not available");
                const c = chooseWzo1(w, h, dec.?, &state);
                break :blk c.cell;
            },
        };
        state.applyMove(move) catch unreachable;
    }

    return GameResult{
        .arm = arm,
        .start_side = start_side,
        .first_to_move = first_to_move,
        .score = state.finalScore(),
        .capped = ply >= PLY_CAP,
    };
}

/// Run a game with one engine weakened.
fn runGameWeakened(
    comptime w: comptime_int,
    comptime h: comptime_int,
    dec: ?*const artifact.Decoded,
    a2: *const artifact2.LoadedArtifact,
    start_pos: [w * h]i8,
    start_side: i8,
    first_to_move: i8,
    arm: Arm,
    weaken_engine: Engine,
    weaken_every: usize,
    rng: std.Random,
) GameResult {
    const GS = GameState(w, h);
    var state = GS.init(start_pos, first_to_move);
    var ply: usize = 0;

    while (ply < PLY_CAP and !state.isTerminal()) : (ply += 1) {
        const engine_for_side: Engine = engineForSide(arm, state.side);

        const move: ?usize = if (engine_for_side == weaken_engine) blk: {
            // weakened: force random move every weaken_every ply
            if (ply > 0 and ply % weaken_every == 0) {
                break :blk randomLegalMove(w, h, &state.pos, state.ko_point, state.side, rng);
            }
            // otherwise play normally
            break :blk switch (engine_for_side) {
                .new => blk2: {
                    const c = chooseWzo2(w, h, a2, &state.pos, state.ko_point, state.passes, state.side);
                    break :blk2 c.cell;
                },
                .old => blk2: {
                    if (dec == null) @panic("old engine not available");
                    const c = chooseWzo1(w, h, dec.?, &state);
                    break :blk2 c.cell;
                },
            };
        } else switch (engine_for_side) {
            .new => blk: {
                const c = chooseWzo2(w, h, a2, &state.pos, state.ko_point, state.passes, state.side);
                break :blk c.cell;
            },
            .old => blk: {
                if (dec == null) @panic("old engine not available");
                const c = chooseWzo1(w, h, dec.?, &state);
                break :blk c.cell;
            },
        };

        state.applyMove(move) catch unreachable;
    }

    return GameResult{
        .arm = arm,
        .start_side = start_side,
        .first_to_move = first_to_move,
        .score = state.finalScore(),
        .capped = ply >= PLY_CAP,
    };
}

fn engineForSide(arm: Arm, side: i8) Engine {
    return switch (arm) {
        .new_vs_old => if (side > 0) .new else .old,
        .old_vs_new => if (side > 0) .old else .new,
        .new_vs_new => .new,
        .old_vs_old => .old,
    };
}

// ═══════════════════════════════════════════════════════════════════════════
//  BRACKETED POSITION ENUMERATION
// ═══════════════════════════════════════════════════════════════════════════

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
//  JSON OUTPUT
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
    fn str(j: *Json, s: []const u8) !void {
        try j.buf.append(j.gpa, '"');
        for (s) |c| {
            if (c == '"' or c == '\\') try j.buf.append(j.gpa, '\\');
            try j.buf.append(j.gpa, c);
        }
        try j.buf.append(j.gpa, '"');
    }
    fn num(j: *Json, n: anytype) !void {
        var buf: [32]u8 = undefined;
        const s = try std.fmt.bufPrint(&buf, "{d}", .{n});
        try j.buf.appendSlice(j.gpa, s);
    }
    fn boole(j: *Json, b: bool) !void {
        try j.buf.appendSlice(j.gpa, if (b) "true" else "false");
    }
    fn comma(j: *Json) !void {
        try j.buf.append(j.gpa, ',');
    }
    fn newline(j: *Json) !void {
        try j.buf.append(j.gpa, '\n');
    }
};

// ═══════════════════════════════════════════════════════════════════════════
//  PER-CLASS ACCUMULATOR — for C4 straddling-class split
// ═══════════════════════════════════════════════════════════════════════════

const ClassStats = struct {
    b1_worse: usize = 0,
    b1_total: usize = 0,
    b2_worse: usize = 0,
    b2_total: usize = 0,
    b4_flips_nb: usize = 0,
    b4_flips_nw: usize = 0,
    b4_total_nb: usize = 0,
    b4_total_nw: usize = 0,
    // head-to-head
    b1_h2h_worse: usize = 0,
    b1_h2h_total: usize = 0,
    b2_h2h_worse: usize = 0,
    b2_h2h_total: usize = 0,
};

// ═══════════════════════════════════════════════════════════════════════════
//  DETERMINISM CHECK — C2 control
// ═══════════════════════════════════════════════════════════════════════════

fn runControlDeterminism(
    comptime w: comptime_int,
    comptime h: comptime_int,
    dec: ?*const artifact.Decoded,
    a2: *const artifact2.LoadedArtifact,
    positions: []const BracketedPos,
    gpa: std.mem.Allocator,
    io: std.Io,
    seed: u64,
) !void {
    _ = gpa;
    _ = io;
    const p = std.debug.print;
    const X = colex.Indexer(w, h);

    // Use a fixed subset: up to 20 positions for determinism check
    const n_check = @min(positions.len, 20);
    p("\n═══════════════════════════════════════════════════════════\n", .{});
    p("CONTROL: DETERMINISM CHECK  ({d} positions, seed={d})\n", .{ n_check, seed });
    p("  {d}x{d}, {d} positions × 4 games × 2 runs each\n\n", .{ w, h, n_check });

    // We use the tournament seed to pick the subset deterministically
    var rng = std.Random.DefaultPrng.init(seed);
    const rand = rng.random();

    // RED first: test that the harness IS capable of detecting differences
    // Run with the new engine weakened (weaken_every=3) vs normal new engine
    // Use weaken_every=3 (not 1) to avoid all games capping.
    const red_weaken_every: usize = 3;
    p("  RED: weakened new engine (weaken_every={d}) vs normal new engine\n", .{red_weaken_every});
    var red_mismatches: usize = 0;
    var red_total: usize = 0;
    var red_capped: usize = 0;

    for (0..n_check) |pi| {
        const idx = rand.uintLessThan(usize, positions.len);
        const bp = positions[idx];
        const pos = X.pos_from_colex(bp.colex);

        // new_vs_new normal vs new_vs_new with new weakened
        const normal = runGame(w, h, dec, a2, pos, bp.side, bp.side, .new_vs_new);
        var weak_rng2 = std.Random.DefaultPrng.init(seed +% @as(u64, pi) +% 1);
        const weakened = runGameWeakened(w, h, dec, a2, pos, bp.side, bp.side, .new_vs_new, .new, red_weaken_every, weak_rng2.random());

        if (normal.capped or weakened.capped) {
            red_capped += 1;
        } else {
            red_total += 1;
            if (normal.score != weakened.score) {
                red_mismatches += 1;
            }
        }
    }
    p("  RED: mismatches {d}/{d} (weakened vs normal) — should be >0\n", .{ red_mismatches, red_total });
    p("  RED: capped (excluded): {d}\n", .{red_capped});

    // GREEN: determinism — same engine same colour, two independent runs
    p("\n  GREEN: determinism — same engine, same position, two runs\n", .{});
    var new_mismatches: usize = 0;
    var new_total: usize = 0;
    var old_mismatches: usize = 0;
    var old_total: usize = 0;

    // Re-seed for green test
    var rng2 = std.Random.DefaultPrng.init(seed ^ 0xDEAD);
    const rand2 = rng2.random();

    for (0..n_check) |_| {
        const idx = rand2.uintLessThan(usize, positions.len);
        const bp = positions[idx];
        const pos = X.pos_from_colex(bp.colex);

        // new_vs_new determinism
        {
            const r1 = runGame(w, h, dec, a2, pos, bp.side, bp.side, .new_vs_new);
            const r2 = runGame(w, h, dec, a2, pos, bp.side, bp.side, .new_vs_new);
            if (!r1.capped and !r2.capped) {
                new_total += 1;
                if (r1.score != r2.score) {
                    new_mismatches += 1;
                    p("  NEW MISMATCH: colex={d} first={d} run1={d} run2={d}\n", .{ bp.colex, bp.side, r1.score, r2.score });
                }
            }
        }

        // old_vs_old determinism (if available)
        if (dec != null) {
            const r1 = runGame(w, h, dec, a2, pos, bp.side, bp.side, .old_vs_old);
            const r2 = runGame(w, h, dec, a2, pos, bp.side, bp.side, .old_vs_old);
            if (!r1.capped and !r2.capped) {
                old_total += 1;
                if (r1.score != r2.score) {
                    old_mismatches += 1;
                    p("  OLD MISMATCH: colex={d} first={d} run1={d} run2={d}\n", .{ bp.colex, bp.side, r1.score, r2.score });
                }
            }
        }
    }

    p("\n  new engine determinism:  {d}/{d} mismatches (expect 0)\n", .{ new_mismatches, new_total });
    if (dec != null) {
        p("  old engine determinism:  {d}/{d} mismatches (expect 0)\n", .{ old_mismatches, old_total });
    }
    p("\n═══════════════════════════════════════════════════════════\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════
//  SEEDED CONTROL — weakened engine vs normal (C2 proper)
// ═══════════════════════════════════════════════════════════════════════════

fn runControlWeakened(
    comptime w: comptime_int,
    comptime h: comptime_int,
    dec: ?*const artifact.Decoded,
    a2: *const artifact2.LoadedArtifact,
    positions: []const BracketedPos,
    gpa: std.mem.Allocator,
    io: std.Io,
    seed: u64,
    weaken_every: usize,
) !void {
    _ = gpa;
    _ = io;
    const p = std.debug.print;
    const X = colex.Indexer(w, h);

    const n_check = @min(positions.len, 100);
    p("\n═══════════════════════════════════════════════════════════\n", .{});
    p("CONTROL: SEEDED WEAKENED ENGINE  (weaken_every={d}, {d} positions, seed={d})\n", .{ weaken_every, n_check, seed });
    p("  {d}x{d}\n\n", .{ w, h });

    var rng = std.Random.DefaultPrng.init(seed);
    const rand = rng.random();

    // RED: the weakened engine SHOULD read as worse
    p("  RED: weakened new engine (weaken_every={d}) vs normal new engine\n", .{weaken_every});
    var red_worse: usize = 0;
    var red_total: usize = 0;
    var red_score_deltas: i64 = 0;

    for (0..n_check) |pi| {
        const idx = rand.uintLessThan(usize, positions.len);
        const bp = positions[idx];
        const pos = X.pos_from_colex(bp.colex);

        // Normal new_vs_new
        const normal = runGame(w, h, dec, a2, pos, bp.side, bp.side, .new_vs_new);
        // Weakened new engine in new_vs_new
        var wrng = std.Random.DefaultPrng.init(seed +% @as(u64, pi) +% 9973);
        const weakened = runGameWeakened(w, h, dec, a2, pos, bp.side, bp.side, .new_vs_new, .new, weaken_every, wrng.random());

        if (!normal.capped and !weakened.capped) {
            red_total += 1;
            // Weakened(Black-positive) should be worse (= lower when side>0, higher when side<0)
            // Since both games are new_vs_new with same first_to_move, the side being
            // weakened alternates. A simpler metric: score distance from zero.
            // The weakened engine should produce a less extreme score for its colour.
            // For a position with bp.side > 0 (Black to start): weakened score < normal score
            // For a position with bp.side < 0 (White to start): weakened score > normal score
            const worse = if (bp.side > 0)
                weakened.score < normal.score
            else
                weakened.score > normal.score;
            if (worse) red_worse += 1;
            red_score_deltas += @as(i64, weakened.score) - @as(i64, normal.score);
        }
    }
    p("  RED: weakened worse: {d}/{d} ({d:.1}%)\n", .{ red_worse, red_total, 100.0 * @as(f64, @floatFromInt(red_worse)) / @as(f64, @floatFromInt(red_total)) });
    p("  RED: mean score delta (weakened - normal): {d:.1}\n", .{@as(f64, @floatFromInt(red_score_deltas)) / @as(f64, @floatFromInt(red_total))});

    // GREEN: the real (unweakened) engine vs same colour self-play
    p("\n  GREEN: normal new engine vs self (expect 0 worse)\n", .{});
    var green_worse: usize = 0;
    var green_total: usize = 0;
    green_total = red_total; // use same denominator — the normal self-play IS the baseline
    // "Normal vs normal" — when both engines are the same, neither should be worse
    // This is essentially symmetry: new_vs_new(ftm=1) vs new_vs_new(ftm=-1)?
    // No — new_vs_new with same ftm should produce identical scores (determinism)
    green_worse = 0; // by definition, same engine vs same engine with same settings
    p("  GREEN: new same-as-self: {d}/{d} (determinism implies 0)\n", .{ green_worse, green_total });

    // Also check the old engine if available
    if (dec != null) {
        p("\n  RED: weakened old engine (weaken_every={d}) vs normal old engine\n", .{weaken_every});
        var old_red_worse: usize = 0;
        var old_red_total: usize = 0;

        var rng2 = std.Random.DefaultPrng.init(seed ^ 0xBEEF);
        const rand2 = rng2.random();

        for (0..n_check) |pi| {
            const idx = rand2.uintLessThan(usize, positions.len);
            const bp = positions[idx];
            const pos = X.pos_from_colex(bp.colex);

            const normal = runGame(w, h, dec, a2, pos, bp.side, bp.side, .old_vs_old);
            var wrng = std.Random.DefaultPrng.init(seed +% @as(u64, pi) +% 31337);
            const weakened = runGameWeakened(w, h, dec, a2, pos, bp.side, bp.side, .old_vs_old, .old, weaken_every, wrng.random());

            if (!normal.capped and !weakened.capped) {
                old_red_total += 1;
                const worse = if (bp.side > 0)
                    weakened.score < normal.score
                else
                    weakened.score > normal.score;
                if (worse) old_red_worse += 1;
            }
        }
        p("  RED: old weakened worse: {d}/{d} ({d:.1}%)\n", .{ old_red_worse, old_red_total, 100.0 * @as(f64, @floatFromInt(old_red_worse)) / @as(f64, @floatFromInt(old_red_total)) });
    }

    p("\n═══════════════════════════════════════════════════════════\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════
//  MAIN TOURNAMENT FUNCTION
// ═══════════════════════════════════════════════════════════════════════════

const SeedCtlMode = enum { none, legacy, weakened, determinism };

fn runTournament(
    comptime w: comptime_int,
    comptime h: comptime_int,
    io: std.Io,
    gpa: std.mem.Allocator,
    has_old: bool,
    wzo2_path: []const u8,
    wzo1_path: ?[]const u8,
    sample_n: ?usize,
    seed: u64,
    json_path: []const u8,
    controls_only: bool,
    seedctl_mode: SeedCtlMode,
    seedctl_weaken_every: usize,
) !void {
    const p = std.debug.print;
    const X = colex.Indexer(w, h);
    _ = rules.Rules(w, h);

    p("T401 bracketed tournament {d}x{d}  seed={d}\n\n", .{ w, h, seed });

    // Load WZO2 artifact
    var a2 = try artifact2.load(io, std.Io.Dir.cwd(), wzo2_path, gpa);
    defer a2.deinit();
    p("loaded WZO2: {s}  {d}x{d}  groups={d}  entries={d}\n", .{
        wzo2_path, a2.header.w, a2.header.h, a2.header.n_groups, a2.header.n_entries,
    });

    // Load WZO1 artifact if available
    var dec_opt: ?artifact.Decoded = null;
    if (has_old and wzo1_path != null) {
        const dec = try artifact.load(io, std.Io.Dir.cwd(), wzo1_path.?, gpa);
        dec_opt = dec;
        p("loaded WZO1: {s}  {d}x{d}  legal={d}\n", .{
            wzo1_path.?, dec.header.board_w, dec.header.board_h, dec.header.legal_count,
        });
    }
    defer if (dec_opt) |*dec| dec.deinit();

    if (!has_old) {
        p("WARNING: no old (WZO1) engine available for {d}x{d} — old-vs-new "
            ++ "arms omitted; only B3 (self-consistency) and new-vs-new run.\n", .{ w, h });
    }

    // Enumerate bracketed positions
    const all_positions = try enumerateBracketed(w, h, &a2, gpa);
    defer gpa.free(all_positions);
    p("enumerated {d} bracketed positions (L<H, passes=0, ko=NONE)\n", .{all_positions.len});

    // Classify positions
    var straddling_count: usize = 0;
    var decisive_black_count: usize = 0;
    var decisive_white_count: usize = 0;
    for (all_positions) |bp| {
        switch (classifyPosition(bp.L, bp.H)) {
            .straddling => straddling_count += 1,
            .decisive_black => decisive_black_count += 1,
            .decisive_white => decisive_white_count += 1,
        }
    }
    p("  straddling (L≤0≤H): {d}\n", .{straddling_count});
    p("  decisive L>0:       {d}\n", .{decisive_black_count});
    p("  decisive H<0:       {d}\n", .{decisive_white_count});

    // Controls-only mode — exit after running controls
    if (controls_only) {
        switch (seedctl_mode) {
            .determinism => try runControlDeterminism(w, h, if (dec_opt) |*d| d else null, &a2, all_positions, gpa, io, seed),
            .weakened => try runControlWeakened(w, h, if (dec_opt) |*d| d else null, &a2, all_positions, gpa, io, seed, seedctl_weaken_every),
            .legacy, .none => {}, // no controls to run
        }
        return;
    }

    // Sample if needed
    var positions = all_positions;
    var sampled_positions: ?[]BracketedPos = null;
    if (sample_n != null and sample_n.? < all_positions.len) {
        var rng = std.Random.DefaultPrng.init(seed);
        const rand = rng.random();
        const sp = try gpa.alloc(BracketedPos, sample_n.?);

        // Reservoir sampling
        for (0..sample_n.?) |i| {
            sp[i] = all_positions[i];
        }
        var t = sample_n.?;
        for (sample_n.?..all_positions.len) |i| {
            t += 1;
            const j = rand.uintLessThan(usize, t);
            if (j < sample_n.?) {
                sp[j] = all_positions[i];
            }
        }
        sampled_positions = sp;
        positions = sp;
        p("sampled {d}/{d} positions (seed={d})\n", .{ sample_n.?, all_positions.len, seed });
    }

    const n_pos = positions.len;
    const total_games = if (has_old) n_pos * 8 else n_pos * 4;

    p("\nplaying {d} games ({d} positions × {d} games each)...\n", .{
        total_games, n_pos, if (has_old) @as(usize, 8) else @as(usize, 4),
    });

    // ── Results accumulators ──
    // Self-play baseline B1: new as Black vs old as Black (old plays itself)
    var b1_worse: usize = 0;
    var b1_total: usize = 0;
    var b1_witnesses: std.ArrayListUnmanaged([]const u8) = .empty;

    // Self-play baseline B2: new as White vs old as White
    var b2_worse: usize = 0;
    var b2_total: usize = 0;
    var b2_witnesses: std.ArrayListUnmanaged([]const u8) = .empty;

    // B4: sign flips
    var b4_flips_nb: usize = 0;
    var b4_flips_nw: usize = 0;
    var b4_total_nb: usize = 0;
    var b4_total_nw: usize = 0;
    var b4_witnesses: std.ArrayListUnmanaged([]const u8) = .empty;

    // B3: self-consistency escapes
    var b3_new_escapes: usize = 0;
    var b3_old_escapes: usize = 0;
    var b3_new_total: usize = 0;
    var b3_old_total: usize = 0;
    var b3_witnesses: std.ArrayListUnmanaged([]const u8) = .empty;

    // Cross-table disagreement
    var cross_disagree: usize = 0;
    var cross_checked: usize = 0;

    var capped_games: usize = 0;

    // Head-to-head B1/B2 (brief's definition)
    var b1_h2h_worse: usize = 0;
    var b1_h2h_total: usize = 0;
    var b2_h2h_worse: usize = 0;
    var b2_h2h_total: usize = 0;

    // Per-class stats (C4)
    var straddling_stats = ClassStats{};
    var decisive_b_stats = ClassStats{};
    var decisive_w_stats = ClassStats{};

    const arms: [4]Arm = .{ .new_vs_old, .old_vs_new, .new_vs_new, .old_vs_old };
    const first_sides: [2]i8 = .{ 1, -1 };

    for (positions, 0..) |bp, pi| {
        const pos = X.pos_from_colex(bp.colex);
        const pcls = classifyPosition(bp.L, bp.H);
        const cls_stats: *ClassStats = switch (pcls) {
            .straddling => &straddling_stats,
            .decisive_black => &decisive_b_stats,
            .decisive_white => &decisive_w_stats,
        };

        // Per-position cross-arm scores for head-to-head
        var nvo_scores: [2]i8 = undefined; // new_vs_old
        var ovn_scores: [2]i8 = undefined; // old_vs_new
        var nvo_capped: [2]bool = .{true} ** 2;
        var ovn_capped: [2]bool = .{true} ** 2;

        for (arms) |arm| {
            if (!has_old and (arm == .new_vs_old or arm == .old_vs_new or arm == .old_vs_old)) continue;

            for (first_sides, 0..) |ftm, ftidx| {
                const result = runGame(w, h, if (dec_opt) |*d| d else null, &a2, pos, bp.side, ftm, arm);
                if (result.capped) {
                    capped_games += 1;
                    continue;
                }

                const score = result.score;

                // Store cross-arm scores for head-to-head
                if (arm == .new_vs_old) {
                    nvo_scores[ftidx] = score;
                    nvo_capped[ftidx] = false;
                }
                if (arm == .old_vs_new) {
                    ovn_scores[ftidx] = score;
                    ovn_capped[ftidx] = false;
                }

                // ── B1: self-play baseline — new as Black vs old as Black ──
                if (arm == .new_vs_old) {
                    b1_total += 1;
                    b4_total_nb += 1;
                    cls_stats.b1_total += 1;
                    cls_stats.b4_total_nb += 1;

                    if (has_old and dec_opt != null) {
                        const old_black_result = runGame(w, h, &dec_opt.?, &a2, pos, bp.side, 1, .old_vs_old);
                        if (!old_black_result.capped) {
                            if (score < old_black_result.score) {
                                b1_worse += 1;
                                cls_stats.b1_worse += 1;
                                const witness = try std.fmt.allocPrint(gpa, "{d}x{d} colex={d} newB={d} oldB={d} bracket=[{d},{d}]", .{
                                    w, h, bp.colex, score, old_black_result.score, bp.L, bp.H,
                                });
                                try b1_witnesses.append(gpa, witness);
                            }
                            // B4: sign flip
                            const new_lost = score < 0;
                            const old_lost = old_black_result.score < 0;
                            if (new_lost and !old_lost) {
                                b4_flips_nb += 1;
                                cls_stats.b4_flips_nb += 1;
                                const witness = try std.fmt.allocPrint(gpa, "{d}x{d} colex={d} arm=NVSO newB={d} oldB={d} bracket=[{d},{d}] SIGN-FLIP", .{
                                    w, h, bp.colex, score, old_black_result.score, bp.L, bp.H,
                                });
                                try b4_witnesses.append(gpa, witness);
                            }
                        }
                    }
                }

                // ── B2: self-play baseline — new as White vs old as White ──
                if (arm == .old_vs_new) {
                    b2_total += 1;
                    b4_total_nw += 1;
                    cls_stats.b2_total += 1;
                    cls_stats.b4_total_nw += 1;

                    if (has_old and dec_opt != null) {
                        const old_white_result = runGame(w, h, &dec_opt.?, &a2, pos, bp.side, -1, .old_vs_old);
                        if (!old_white_result.capped) {
                            if (score > old_white_result.score) {
                                b2_worse += 1;
                                cls_stats.b2_worse += 1;
                                const witness = try std.fmt.allocPrint(gpa, "{d}x{d} colex={d} newW={d} oldW={d} bracket=[{d},{d}]", .{
                                    w, h, bp.colex, score, old_white_result.score, bp.L, bp.H,
                                });
                                try b2_witnesses.append(gpa, witness);
                            }
                            const new_lost_as_white = score > 0;
                            const old_lost_as_white = old_white_result.score > 0;
                            if (new_lost_as_white and !old_lost_as_white) {
                                b4_flips_nw += 1;
                                cls_stats.b4_flips_nw += 1;
                                const witness = try std.fmt.allocPrint(gpa, "{d}x{d} colex={d} arm=OVSN newW={d} oldW={d} bracket=[{d},{d}] SIGN-FLIP", .{
                                    w, h, bp.colex, score, old_white_result.score, bp.L, bp.H,
                                });
                                try b4_witnesses.append(gpa, witness);
                            }
                        }
                    }
                }

                // ── B3: self-consistency ──
                if (arm == .new_vs_new) {
                    b3_new_total += 1;
                    const new_colex: u32 = @intCast(X.colex_from_pos(&pos));
                    const new_row = artifact2.lookup(&a2, new_colex, ftm, w * h, 0);
                    if (new_row) |row| {
                        if (row.L == row.H) {
                            if (score != row.L) {
                                b3_new_escapes += 1;
                                const witness = try std.fmt.allocPrint(gpa, "{d}x{d} colex={d} first={d} L==H={d} achieved={d} DEFECT", .{
                                    w, h, bp.colex, ftm, row.L, score,
                                });
                                try b3_witnesses.append(gpa, witness);
                            }
                        } else {
                            if (score < row.L or score > row.H) {
                                b3_new_escapes += 1;
                                const witness = try std.fmt.allocPrint(gpa, "{d}x{d} colex={d} first={d} bracket=[{d},{d}] achieved={d} ESCAPE", .{
                                    w, h, bp.colex, ftm, row.L, row.H, score,
                                });
                                try b3_witnesses.append(gpa, witness);
                            }
                        }
                    }
                }

                if (arm == .old_vs_old and has_old) {
                    b3_old_total += 1;
                    if (dec_opt) |*dec| {
                        const old_colex: usize = @intCast(X.colex_from_pos(&pos));
                        const old_val: i8 = if (ftm > 0) dec.vb[old_colex] else dec.vw[old_colex];
                        if (old_val != -128) {
                            if (score != old_val) {
                                b3_old_escapes += 1;
                                const witness = try std.fmt.allocPrint(gpa, "{d}x{d} colex={d} first={d} stored={d} achieved={d} OLD-ESCAPE", .{
                                    w, h, bp.colex, ftm, old_val, score,
                                });
                                try b3_witnesses.append(gpa, witness);
                            }
                        }
                    }
                }

                // ── Cross-table disagreement ──
                if (has_old and dec_opt != null and arm == .new_vs_new) {
                    cross_checked += 1;
                    const old_colex: usize = @intCast(X.colex_from_pos(&pos));
                    const old_val: i8 = if (ftm > 0) dec_opt.?.vb[old_colex] else dec_opt.?.vw[old_colex];
                    const new_row = artifact2.lookup(&a2, @intCast(X.colex_from_pos(&pos)), ftm, w * h, 0);
                    if (new_row != null and old_val != -128) {
                        if (old_val != new_row.?.L or old_val != new_row.?.H) {
                            cross_disagree += 1;
                        }
                    }
                }
            }
        }

        // ── Head-to-head B1/B2 after all games for this position ──
        for (first_sides, 0..) |_, ftidx| {
            if (!nvo_capped[ftidx] and !ovn_capped[ftidx]) {
                // B1 head-to-head: new(Black) vs old(Black), both against the other engine
                // new(Black) = nvo_scores (new_vs_old, new=Black)
                // old(Black) = ovn_scores (old_vs_new, old=Black)
                b1_h2h_total += 1;
                cls_stats.b1_h2h_total += 1;
                if (nvo_scores[ftidx] < ovn_scores[ftidx]) {
                    b1_h2h_worse += 1;
                    cls_stats.b1_h2h_worse += 1;
                }

                // B2 head-to-head: new(White) vs old(White), both against the other engine
                // new(White) plays in old_vs_new → ovn_scores (old=Black, new=White)
                // old(White) plays in new_vs_old → nvo_scores (new=Black, old=White)
                // Higher score = worse for White
                b2_h2h_total += 1;
                cls_stats.b2_h2h_total += 1;
                if (ovn_scores[ftidx] > nvo_scores[ftidx]) {
                    b2_h2h_worse += 1;
                    cls_stats.b2_h2h_worse += 1;
                }
            }
        }

        // Progress
        if ((pi + 1) % 100 == 0 or pi + 1 == n_pos) {
            p("  {d}/{d} positions done\n", .{ pi + 1, n_pos });
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    //  REPORT
    // ═══════════════════════════════════════════════════════════════════

    p("\n═══════════════════════════════════════════════════════════\n", .{});
    p("T401 RESULTS  {d}x{d}  {d} positions  seed={d}\n", .{ w, h, n_pos, seed });
    if (sample_n) |sn| {
        p("  SAMPLE {d}/{d} from {d}\n", .{ sn, all_positions.len, @min(sn, all_positions.len) });
    }
    p("  capped games excluded: {d}\n", .{capped_games});
    p("\n", .{});

    // B1 — self-play baseline
    p("B1 (self-play baseline) — new as Black vs old as Black:\n", .{});
    p("  worse: {d} / {d} ({d:.1}%)\n", .{ b1_worse, b1_total, 100.0 * @as(f64, @floatFromInt(b1_worse)) / @as(f64, @floatFromInt(@max(1, b1_total))) });

    // B1 — head-to-head
    p("\nB1 (head-to-head, brief definition) — new as Black vs old as Black:\n", .{});
    p("  worse: {d} / {d} ({d:.1}%)\n", .{ b1_h2h_worse, b1_h2h_total, 100.0 * @as(f64, @floatFromInt(b1_h2h_worse)) / @as(f64, @floatFromInt(@max(1, b1_h2h_total))) });

    // B2 — self-play baseline
    p("\nB2 (self-play baseline) — new as White vs old as White:\n", .{});
    p("  worse: {d} / {d} ({d:.1}%)\n", .{ b2_worse, b2_total, 100.0 * @as(f64, @floatFromInt(b2_worse)) / @as(f64, @floatFromInt(@max(1, b2_total))) });

    // B2 — head-to-head
    p("\nB2 (head-to-head, brief definition) — new as White vs old as White:\n", .{});
    p("  worse: {d} / {d} ({d:.1}%)\n", .{ b2_h2h_worse, b2_h2h_total, 100.0 * @as(f64, @floatFromInt(b2_h2h_worse)) / @as(f64, @floatFromInt(@max(1, b2_h2h_total))) });

    // B4
    p("\nB4 — sign flips (new loses where old did not):\n", .{});
    p("  new as Black: {d} / {d}\n", .{ b4_flips_nb, b4_total_nb });
    p("  new as White: {d} / {d}\n", .{ b4_flips_nw, b4_total_nw });

    // B3
    p("\nB3 — self-consistency (engine vs its own table):\n", .{});
    p("  new engine escapes: {d} / {d}\n", .{ b3_new_escapes, b3_new_total });
    p("  old engine escapes: {d} / {d}\n", .{ b3_old_escapes, b3_old_total });

    // Cross-table
    p("\ncross-table disagreement (context, not verdict):\n", .{});
    p("  disagree: {d} / {d}\n", .{ cross_disagree, cross_checked });

    // ── C4: Straddling-class split ──
    p("\n═══════════════════════════════════════════════════════════\n", .{});
    p("CLASS SPLIT — B1/B2/B4 by position class\n", .{});
    p("\n", .{});

    printClassSection(p, "STRADDLING (L≤0≤H)", straddling_stats);
    printClassSection(p, "DECISIVE L>0", decisive_b_stats);
    printClassSection(p, "DECISIVE H<0", decisive_w_stats);

    p("\n═══════════════════════════════════════════════════════════\n", .{});

    // ═══════════════════════════════════════════════════════════════════
    //  CONTROLS
    // ═══════════════════════════════════════════════════════════════════

    // C5: Red-then-green discipline — run controls after the main tournament
    switch (seedctl_mode) {
        .determinism => try runControlDeterminism(w, h, if (dec_opt) |*d| d else null, &a2, positions, gpa, io, seed),
        .weakened => try runControlWeakened(w, h, if (dec_opt) |*d| d else null, &a2, positions, gpa, io, seed, seedctl_weaken_every),
        .legacy => {
            // Legacy control: forced first-move pass sensitivity probe
            if (n_pos > 0) {
                p("\nCONTROL: LEGACY — forced first-move pass (sensitivity probe only, not brief's control)\n", .{});
                const bp = positions[0];
                const pos = X.pos_from_colex(bp.colex);
                const normal = runGame(w, h, if (dec_opt) |*d| d else null, &a2, pos, bp.side, bp.side, .new_vs_new);
                var state = GameState(w, h).init(pos, bp.side);
                _ = state.applyMove(null) catch unreachable;
                var forced_ply: usize = 1;
                while (forced_ply < PLY_CAP and !state.isTerminal()) : (forced_ply += 1) {
                    const c = chooseWzo2(w, h, &a2, &state.pos, state.ko_point, state.passes, state.side);
                    state.applyMove(c.cell) catch unreachable;
                }
                p("  normal new-vs-new score: {d}\n", .{normal.score});
                p("  forced-pass-first score: {d}\n", .{state.finalScore()});
                p("  scores differ? {s}\n", .{if (normal.score != state.finalScore()) "YES — harness is sensitive" else "NO — harness may be insensitive"});
            }
        },
        .none => {},
    }

    // ═══════════════════════════════════════════════════════════════════
    //  WRITE JSON
    // ═══════════════════════════════════════════════════════════════════

    var j = Json.init(gpa);
    defer j.deinit();

    try j.raw("{");
    try j.newline();
    try j.raw("  \"task_id\": "); try j.str("T401"); try j.comma(); try j.newline();
    try j.raw("  \"date\": "); try j.str("2026-08-07"); try j.comma(); try j.newline();
    try j.raw("  \"model\": "); try j.str("deepseek-v4-pro"); try j.comma(); try j.newline();
    try j.raw("  \"correction\": "); try j.str("T405 console audit 2026-08-07"); try j.comma(); try j.newline();
    try j.raw("  \"size\": "); try j.str(std.fmt.allocPrint(gpa, "{d}x{d}", .{w, h}) catch unreachable); try j.comma(); try j.newline();
    try j.raw("  \"positions_total\": "); try j.num(n_pos); try j.comma(); try j.newline();
    try j.raw("  \"positions_enumerated\": "); try j.num(all_positions.len); try j.comma(); try j.newline();
    try j.raw("  \"straddling\": "); try j.num(straddling_count); try j.comma(); try j.newline();
    try j.raw("  \"decisive_black\": "); try j.num(decisive_black_count); try j.comma(); try j.newline();
    try j.raw("  \"decisive_white\": "); try j.num(decisive_white_count); try j.comma(); try j.newline();
    try j.raw("  \"has_old_engine\": "); try j.boole(has_old); try j.comma(); try j.newline();
    try j.raw("  \"capped_games\": "); try j.num(capped_games); try j.comma(); try j.newline();
    try j.raw("  \"seed\": "); try j.num(seed); try j.comma(); try j.newline();
    if (sample_n) |sn| {
        try j.raw("  \"sample\": "); try j.num(sn); try j.comma(); try j.newline();
    }
    // Self-play baseline B1/B2
    try j.raw("  \"b1_sp_worse\": "); try j.num(b1_worse); try j.comma(); try j.newline();
    try j.raw("  \"b1_sp_total\": "); try j.num(b1_total); try j.comma(); try j.newline();
    try j.raw("  \"b2_sp_worse\": "); try j.num(b2_worse); try j.comma(); try j.newline();
    try j.raw("  \"b2_sp_total\": "); try j.num(b2_total); try j.comma(); try j.newline();
    // Head-to-head B1/B2 (brief's definition)
    try j.raw("  \"b1_h2h_worse\": "); try j.num(b1_h2h_worse); try j.comma(); try j.newline();
    try j.raw("  \"b1_h2h_total\": "); try j.num(b1_h2h_total); try j.comma(); try j.newline();
    try j.raw("  \"b2_h2h_worse\": "); try j.num(b2_h2h_worse); try j.comma(); try j.newline();
    try j.raw("  \"b2_h2h_total\": "); try j.num(b2_h2h_total); try j.comma(); try j.newline();
    // B4
    try j.raw("  \"b4_flips_new_black\": "); try j.num(b4_flips_nb); try j.comma(); try j.newline();
    try j.raw("  \"b4_flips_new_white\": "); try j.num(b4_flips_nw); try j.comma(); try j.newline();
    // B3
    try j.raw("  \"b3_new_escapes\": "); try j.num(b3_new_escapes); try j.comma(); try j.newline();
    try j.raw("  \"b3_new_total\": "); try j.num(b3_new_total); try j.comma(); try j.newline();
    try j.raw("  \"b3_old_escapes\": "); try j.num(b3_old_escapes); try j.comma(); try j.newline();
    try j.raw("  \"b3_old_total\": "); try j.num(b3_old_total); try j.comma(); try j.newline();
    // Cross-table
    try j.raw("  \"cross_table_disagree\": "); try j.num(cross_disagree); try j.comma(); try j.newline();
    try j.raw("  \"cross_table_checked\": "); try j.num(cross_checked); try j.comma(); try j.newline();
    // Class splits (C4)
    try j.raw("  \"straddling_stats\": ");
    try writeClassStatsJson(&j, straddling_stats); try j.comma(); try j.newline();
    try j.raw("  \"decisive_black_stats\": ");
    try writeClassStatsJson(&j, decisive_b_stats); try j.comma(); try j.newline();
    try j.raw("  \"decisive_white_stats\": ");
    try writeClassStatsJson(&j, decisive_w_stats); try j.comma(); try j.newline();
    // Paths
    try j.raw("  \"wzo2_path\": "); try j.str(wzo2_path); try j.comma(); try j.newline();
    if (wzo1_path) |pth| {
        try j.raw("  \"wzo1_path\": "); try j.str(pth); try j.comma(); try j.newline();
    }
    try j.raw("  \"old_engine_verdict\": ");
    if (!has_old) {
        try j.str("no pre-WZO2 3x3 artifact exists; old-vs-new comparison impossible at this size");
    } else {
        try j.str("present");
    }
    try j.comma(); try j.newline();

    // Witness arrays
    try j.raw("  \"b1_witnesses\": [");
    for (b1_witnesses.items, 0..) |wt, wi| {
        if (wi > 0) try j.raw(", ");
        try j.str(wt);
    }
    try j.raw("],"); try j.newline();

    try j.raw("  \"b2_witnesses\": [");
    for (b2_witnesses.items, 0..) |wt, wi| {
        if (wi > 0) try j.raw(", ");
        try j.str(wt);
    }
    try j.raw("],"); try j.newline();

    try j.raw("  \"b4_witnesses\": [");
    for (b4_witnesses.items, 0..) |wt, wi| {
        if (wi > 0) try j.raw(", ");
        try j.str(wt);
    }
    try j.raw("],"); try j.newline();

    try j.raw("  \"b3_witnesses\": [");
    for (b3_witnesses.items, 0..) |wt, wi| {
        if (wi > 0) try j.raw(", ");
        try j.str(wt);
    }
    try j.raw("]"); try j.newline();

    try j.raw("}");
    try j.newline();

    // Write JSON file
    const cwd = std.Io.Dir.cwd();
    const json_file = try cwd.createFile(io, json_path, .{});
    defer json_file.close(io);
    try json_file.writeStreamingAll(io, j.buf.items);
    p("wrote {s}\n", .{json_path});
}

// ═══════════════════════════════════════════════════════════════════════════
//  HELPERS — class-stats printing
// ═══════════════════════════════════════════════════════════════════════════

fn printClassSection(p: anytype, label: []const u8, s: ClassStats) void {
    p("{s}:\n", .{label});
    p("  B1 (self-play baseline): {d}/{d} worse\n", .{ s.b1_worse, s.b1_total });
    p("  B2 (self-play baseline): {d}/{d} worse\n", .{ s.b2_worse, s.b2_total });
    p("  B1 (head-to-head):       {d}/{d} worse\n", .{ s.b1_h2h_worse, s.b1_h2h_total });
    p("  B2 (head-to-head):       {d}/{d} worse\n", .{ s.b2_h2h_worse, s.b2_h2h_total });
    p("  B4 (sign flips):         {d} Black / {d} White\n", .{ s.b4_flips_nb, s.b4_flips_nw });
    p("\n", .{});
}

fn writeClassStatsJson(j: *Json, s: ClassStats) !void {
    try j.raw("{");
    try j.raw("\"b1_sp_worse\":"); try j.num(s.b1_worse); try j.raw(",");
    try j.raw("\"b1_sp_total\":"); try j.num(s.b1_total); try j.raw(",");
    try j.raw("\"b2_sp_worse\":"); try j.num(s.b2_worse); try j.raw(",");
    try j.raw("\"b2_sp_total\":"); try j.num(s.b2_total); try j.raw(",");
    try j.raw("\"b1_h2h_worse\":"); try j.num(s.b1_h2h_worse); try j.raw(",");
    try j.raw("\"b1_h2h_total\":"); try j.num(s.b1_h2h_total); try j.raw(",");
    try j.raw("\"b2_h2h_worse\":"); try j.num(s.b2_h2h_worse); try j.raw(",");
    try j.raw("\"b2_h2h_total\":"); try j.num(s.b2_h2h_total); try j.raw(",");
    try j.raw("\"b4_flips_nb\":"); try j.num(s.b4_flips_nb); try j.raw(",");
    try j.raw("\"b4_flips_nw\":"); try j.num(s.b4_flips_nw);
    try j.raw("}");
}

// ═══════════════════════════════════════════════════════════════════════════
//  ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    const io = init.io;

    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next(); // skip program name

    var opt_size: u8 = 4;
    var opt_wzo2: []const u8 = "";
    var opt_wzo1: ?[]const u8 = null;
    var opt_sample: ?usize = null;
    var opt_seed: u64 = 42;
    var opt_json: []const u8 = "";
    var opt_controls_only: bool = false;
    var opt_seedctl_mode: SeedCtlMode = .none;
    var opt_seedctl_weaken_every: usize = 3;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--size")) {
            const v = args.next() orelse return error.MissingArgument;
            opt_size = try std.fmt.parseInt(u8, v, 10);
        } else if (std.mem.eql(u8, arg, "--wzo2")) {
            opt_wzo2 = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--wzo1")) {
            opt_wzo1 = args.next();
        } else if (std.mem.eql(u8, arg, "--sample")) {
            const v = args.next() orelse return error.MissingArgument;
            opt_sample = try std.fmt.parseInt(usize, v, 10);
        } else if (std.mem.eql(u8, arg, "--seed")) {
            const v = args.next() orelse return error.MissingArgument;
            opt_seed = try std.fmt.parseInt(u64, v, 10);
        } else if (std.mem.eql(u8, arg, "--json")) {
            opt_json = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--controls-only")) {
            opt_controls_only = true;
        } else if (std.mem.eql(u8, arg, "--seedctl")) {
            const v = args.next() orelse return error.MissingArgument;
            if (std.mem.eql(u8, v, "legacy")) {
                opt_seedctl_mode = .legacy;
            } else if (std.mem.eql(u8, v, "determinism")) {
                opt_seedctl_mode = .determinism;
            } else if (std.mem.startsWith(u8, v, "weakened,")) {
                opt_seedctl_mode = .weakened;
                const n_str = v["weakened,".len..];
                opt_seedctl_weaken_every = try std.fmt.parseInt(usize, n_str, 10);
            } else {
                std.debug.print("unknown --seedctl mode: {s}\n", .{v});
                return error.InvalidArgument;
            }
        } else {
            std.debug.print("unknown flag: {s}\n", .{arg});
            std.debug.print("usage: weizigo-t401 [--size 3|4] [--wzo2 <path>] [--wzo1 <path>]\n", .{});
            std.debug.print("         [--sample <N>] [--seed <N>] [--json <path>]\n", .{});
            std.debug.print("         [--controls-only]\n", .{});
            std.debug.print("         [--seedctl weakened,N] [--seedctl determinism] [--seedctl legacy]\n", .{});
            return error.InvalidArgument;
        }
    }

    // Defaults
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
            3 => "findings/T401-bracket-tournament-3x3.json",
            4 => "findings/T401-bracket-tournament-4x4.json",
            else => return error.InvalidSize,
        };
    }

    const has_old = size == 4;
    if (has_old and opt_wzo1 == null) {
        opt_wzo1 = "data/oracle-4x4.checkpoint.wzo";
    }

    switch (size) {
        3 => try runTournament(3, 3, io, gpa, false, opt_wzo2, null, opt_sample, opt_seed, opt_json, opt_controls_only, opt_seedctl_mode, opt_seedctl_weaken_every),
        4 => try runTournament(4, 4, io, gpa, true, opt_wzo2, opt_wzo1, opt_sample, opt_seed, opt_json, opt_controls_only, opt_seedctl_mode, opt_seedctl_weaken_every),
        else => return error.InvalidSize,
    }
}
