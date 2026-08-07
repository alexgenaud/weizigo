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
//         [--controls-only] [--seedctl]

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
//  MAIN
// ═══════════════════════════════════════════════════════════════════════════

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
    do_seedctl: bool,
) !void {
    _ = controls_only;
    const p = std.debug.print;
    const X = colex.Indexer(w, h);
    _ = rules.Rules(w, h); // used only for type info in comptime

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
    var straddling: usize = 0;
    var decisive_black: usize = 0;
    var decisive_white: usize = 0;
    for (all_positions) |bp| {
        if (bp.L <= 0 and bp.H >= 0) {
            straddling += 1;
        } else if (bp.L > 0) {
            decisive_black += 1;
        } else {
            decisive_white += 1;
        }
    }
    p("  straddling (L≤0≤H): {d}\n", .{straddling});
    p("  decisive L>0:       {d}\n", .{decisive_black});
    p("  decisive H<0:       {d}\n", .{decisive_white});

    // Sample if needed
    var positions = all_positions;
    var sampled_indices: ?[]usize = null;
    var sampled_positions: ?[]BracketedPos = null;
    if (sample_n != null and sample_n.? < all_positions.len) {
        var rng = std.Random.DefaultPrng.init(seed);
        const rand = rng.random();
        const indices = try gpa.alloc(usize, sample_n.?);
        const sp = try gpa.alloc(BracketedPos, sample_n.?);

        // Reservoir sampling
        for (0..sample_n.?) |i| {
            indices[i] = i;
            sp[i] = all_positions[i];
        }
        var t = sample_n.?;
        for (sample_n.?..all_positions.len) |i| {
            t += 1;
            const j = rand.uintLessThan(usize, t);
            if (j < sample_n.?) {
                indices[j] = i;
                sp[j] = all_positions[i];
            }
        }
        sampled_indices = indices;
        sampled_positions = sp;
        positions = sp;
        p("sampled {d}/{d} positions (seed={d})\n", .{ sample_n.?, all_positions.len, seed });
    }

    const n_pos = positions.len;
    const total_games = if (has_old) n_pos * 8 else n_pos * 4; // 2 arms (new-vs-new) × 2 starting sides

    p("\nplaying {d} games ({d} positions × {d} games each)...\n", .{
        total_games, n_pos, if (has_old) @as(usize, 8) else @as(usize, 4),
    });

    // Results accumulators
    // B1: new as Black vs old as White — compare new(Black) final score vs old(Black) from same pos
    var b1_worse: usize = 0;
    var b1_total: usize = 0;
    var b1_witnesses: std.ArrayListUnmanaged([]const u8) = .empty;

    // B2: new as White vs old as Black
    var b2_worse: usize = 0;
    var b2_total: usize = 0;
    var b2_witnesses: std.ArrayListUnmanaged([]const u8) = .empty;

    // B4: sign flips
    var b4_flips_nb: usize = 0; // new as Black
    var b4_flips_nw: usize = 0; // new as White
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

    const arms: [4]Arm = .{ .new_vs_old, .old_vs_new, .new_vs_new, .old_vs_old };
    const first_sides: [2]i8 = .{ 1, -1 };

    for (positions, 0..) |bp, pi| {
        const pos = X.pos_from_colex(bp.colex);

        for (arms) |arm| {
            // Skip old-engine arms when old engine not available
            if (!has_old and (arm == .new_vs_old or arm == .old_vs_new or arm == .old_vs_old)) continue;

            for (first_sides) |ftm| {
                const result = runGame(w, h, if (dec_opt) |*d| d else null, &a2, pos, bp.side, ftm, arm);
                if (result.capped) {
                    capped_games += 1;
                    continue;
                }

                const score = result.score;

                // B1: new as Black vs old as White
                if (arm == .new_vs_old) {
                    // For B1, we compare: new(Black) result vs old(Black) from same pos
                    b1_total += 1;
                    b4_total_nb += 1;

                    // Get the old engine's result from same position playing Black
                    if (has_old and dec_opt != null) {
                        const old_black_result = runGame(w, h, &dec_opt.?, &a2, pos, bp.side, 1, .old_vs_old);
                        if (!old_black_result.capped) {
                            // new(Black) should score >= old(Black) → new score >= old score
                            if (score < old_black_result.score) {
                                b1_worse += 1;
                                const witness = try std.fmt.allocPrint(gpa, "{d}x{d} colex={d} newB={d} oldB={d} bracket=[{d},{d}]", .{
                                    w, h, bp.colex, score, old_black_result.score, bp.L, bp.H,
                                });
                                try b1_witnesses.append(gpa, witness);
                            }
                            // B4: sign flip — new loses where old did not
                            const new_lost = score < 0;
                            const old_lost = old_black_result.score < 0;
                            if (new_lost and !old_lost) {
                                b4_flips_nb += 1;
                                const witness = try std.fmt.allocPrint(gpa, "{d}x{d} colex={d} arm=NVSO newB={d} oldB={d} bracket=[{d},{d}] SIGN-FLIP", .{
                                    w, h, bp.colex, score, old_black_result.score, bp.L, bp.H,
                                });
                                try b4_witnesses.append(gpa, witness);
                            }
                        }
                    }
                }

                // B2: new as White vs old as Black
                if (arm == .old_vs_new) {
                    b2_total += 1;
                    b4_total_nw += 1;

                    if (has_old and dec_opt != null) {
                        const old_white_result = runGame(w, h, &dec_opt.?, &a2, pos, bp.side, -1, .old_vs_old);
                        if (!old_white_result.capped) {
                            // new(White) should score <= old(White) (scores are Black-positive)
                            // new(White) is the opponent → lower score is better for White
                            // We want new ≤ old → score ≤ old_white_result.score
                            if (score > old_white_result.score) {
                                b2_worse += 1;
                                const witness = try std.fmt.allocPrint(gpa, "{d}x{d} colex={d} newW={d} oldW={d} bracket=[{d},{d}]", .{
                                    w, h, bp.colex, score, old_white_result.score, bp.L, bp.H,
                                });
                                try b2_witnesses.append(gpa, witness);
                            }
                            const new_lost_as_white = score > 0;
                            const old_lost_as_white = old_white_result.score > 0;
                            if (new_lost_as_white and !old_lost_as_white) {
                                b4_flips_nw += 1;
                                const witness = try std.fmt.allocPrint(gpa, "{d}x{d} colex={d} arm=OVSN newW={d} oldW={d} bracket=[{d},{d}] SIGN-FLIP", .{
                                    w, h, bp.colex, score, old_white_result.score, bp.L, bp.H,
                                });
                                try b4_witnesses.append(gpa, witness);
                            }
                        }
                    }
                }

                // B3: self-consistency
                // The relevant table entry is for the side that moves FIRST in this game
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

                // Cross-table disagreement
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

    // B1
    p("B1 — new as Black vs old as White:\n", .{});
    p("  worse: {d} / {d}\n", .{ b1_worse, b1_total });
    if (b1_witnesses.items.len > 0) {
        p("  witnesses:\n", .{});
        for (b1_witnesses.items) |wt| {
            p("    {s}\n", .{wt});
        }
    }

    // B2
    p("\nB2 — new as White vs old as Black:\n", .{});
    p("  worse: {d} / {d}\n", .{ b2_worse, b2_total });
    if (b2_witnesses.items.len > 0) {
        p("  witnesses:\n", .{});
        for (b2_witnesses.items) |wt| {
            p("    {s}\n", .{wt});
        }
    }

    // B4
    p("\nB4 — sign flips (new loses where old did not):\n", .{});
    p("  new as Black: {d} / {d}\n", .{ b4_flips_nb, b4_total_nb });
    p("  new as White: {d} / {d}\n", .{ b4_flips_nw, b4_total_nw });
    if (b4_witnesses.items.len > 0) {
        p("  witnesses:\n", .{});
        for (b4_witnesses.items) |wt| {
            p("    {s}\n", .{wt});
        }
    }

    // B3
    p("\nB3 — self-consistency (engine vs its own table):\n", .{});
    p("  new engine escapes: {d} / {d}\n", .{ b3_new_escapes, b3_new_total });
    p("  old engine escapes: {d} / {d}\n", .{ b3_old_escapes, b3_old_total });
    if (b3_witnesses.items.len > 0) {
        p("  witnesses:\n", .{});
        for (b3_witnesses.items) |wt| {
            p("    {s}\n", .{wt});
        }
    }

    // Cross-table
    p("\ncross-table disagreement (context, not verdict):\n", .{});
    p("  disagree: {d} / {d}\n", .{ cross_disagree, cross_checked });

    p("\n═══════════════════════════════════════════════════════════\n", .{});

    // ═══════════════════════════════════════════════════════════════════
    //  CONTROLS
    // ═══════════════════════════════════════════════════════════════════

    if (do_seedctl and n_pos > 0) {
        p("\nSEEDED CONTROL — forcing suboptimal moves\n", .{});
        // Pick the first position as a test bed
        const bp = positions[0];
        const pos = X.pos_from_colex(bp.colex);

        // Play a normal new-vs-new game
        const normal = runGame(w, h, if (dec_opt) |*d| d else null, &a2, pos, bp.side, bp.side, .new_vs_new);

        // Play a game where new engine deliberately makes a pass on the first move
        var state = GameState(w, h).init(pos, bp.side);
        _ = state.applyMove(null) catch unreachable; // forced pass
        var forced_ply: usize = 1;
        while (forced_ply < PLY_CAP and !state.isTerminal()) : (forced_ply += 1) {
            const c = chooseWzo2(w, h, &a2, &state.pos, state.ko_point, state.passes, state.side);
            state.applyMove(c.cell) catch unreachable;
        }
        const forced_score = state.finalScore();
        p("  normal new-vs-new score: {d}\n", .{normal.score});
        p("  forced-pass-first score: {d}\n", .{forced_score});
        p("  control detection: scores differ? {s}\n", .{if (normal.score != forced_score) "YES — harness is sensitive" else "NO — harness may be insensitive"});
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
    try j.raw("  \"size\": "); try j.str(std.fmt.allocPrint(gpa, "{d}x{d}", .{w, h}) catch unreachable); try j.comma(); try j.newline();
    try j.raw("  \"positions_total\": "); try j.num(n_pos); try j.comma(); try j.newline();
    try j.raw("  \"positions_enumerated\": "); try j.num(all_positions.len); try j.comma(); try j.newline();
    try j.raw("  \"straddling\": "); try j.num(straddling); try j.comma(); try j.newline();
    try j.raw("  \"decisive_black\": "); try j.num(decisive_black); try j.comma(); try j.newline();
    try j.raw("  \"decisive_white\": "); try j.num(decisive_white); try j.comma(); try j.newline();
    try j.raw("  \"has_old_engine\": "); try j.boole(has_old); try j.comma(); try j.newline();
    try j.raw("  \"capped_games\": "); try j.num(capped_games); try j.comma(); try j.newline();
    try j.raw("  \"seed\": "); try j.num(seed); try j.comma(); try j.newline();
    if (sample_n) |sn| {
        try j.raw("  \"sample\": "); try j.num(sn); try j.comma(); try j.newline();
    }
    try j.raw("  \"b1_new_black_worse\": "); try j.num(b1_worse); try j.comma(); try j.newline();
    try j.raw("  \"b1_total\": "); try j.num(b1_total); try j.comma(); try j.newline();
    try j.raw("  \"b2_new_white_worse\": "); try j.num(b2_worse); try j.comma(); try j.newline();
    try j.raw("  \"b2_total\": "); try j.num(b2_total); try j.comma(); try j.newline();
    try j.raw("  \"b4_flips_new_black\": "); try j.num(b4_flips_nb); try j.comma(); try j.newline();
    try j.raw("  \"b4_flips_new_white\": "); try j.num(b4_flips_nw); try j.comma(); try j.newline();
    try j.raw("  \"b3_new_escapes\": "); try j.num(b3_new_escapes); try j.comma(); try j.newline();
    try j.raw("  \"b3_new_total\": "); try j.num(b3_new_total); try j.comma(); try j.newline();
    try j.raw("  \"b3_old_escapes\": "); try j.num(b3_old_escapes); try j.comma(); try j.newline();
    try j.raw("  \"b3_old_total\": "); try j.num(b3_old_total); try j.comma(); try j.newline();
    try j.raw("  \"cross_table_disagree\": "); try j.num(cross_disagree); try j.comma(); try j.newline();
    try j.raw("  \"cross_table_checked\": "); try j.num(cross_checked); try j.comma(); try j.newline();
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

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    const io = init.io;

    // Parse arguments
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next(); // skip program name

    var opt_size: u8 = 4;
    var opt_wzo2: []const u8 = "";
    var opt_wzo1: ?[]const u8 = null;
    var opt_sample: ?usize = null;
    var opt_seed: u64 = 42;
    var opt_json: []const u8 = "";
    var opt_controls_only: bool = false;
    var opt_seedctl: bool = false;

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
            opt_seedctl = true;
        } else {
            std.debug.print("unknown flag: {s}\n", .{arg});
            std.debug.print("usage: weizigo-t401 [--size 3|4] [--wzo2 <path>] [--wzo1 <path>]\n", .{});
            std.debug.print("         [--sample <N>] [--seed <N>] [--json <path>]\n", .{});
            std.debug.print("         [--controls-only] [--seedctl]\n", .{});
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

    const has_old = size == 4; // only 4x4 has a WZO1 artifact
    if (has_old and opt_wzo1 == null) {
        opt_wzo1 = "data/oracle-4x4.checkpoint.wzo";
    }

    switch (size) {
        3 => try runTournament(3, 3, io, gpa, false, opt_wzo2, null, opt_sample, opt_seed, opt_json, opt_controls_only, opt_seedctl),
        4 => try runTournament(4, 4, io, gpa, true, opt_wzo2, opt_wzo1, opt_sample, opt_seed, opt_json, opt_controls_only, opt_seedctl),
        else => return error.InvalidSize,
    }
}
