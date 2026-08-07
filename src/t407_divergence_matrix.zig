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
// T407_DIVERGENCE_MATRIX — the four-game matrix per start position.
//
// Task: T407 · Role: worker · Model: glm-5.2 · Date: 2026-08-07
//
// For every fresh-start bracketed (L < H) position, play FOUR games:
//   slot 1  new/new   (new=Black, new=White)
//   slot 2  new/old   (new=Black, old=White)
//   slot 3  old/new   (old=Black, new=White)
//   slot 4  old/old   (old=Black, old=White)
// all with first-to-move = the table's side for that position (self-play
// needs only one game; the four slots already cover both colour assignments
// for the cross comparison — operator ruling 2026-08-07).
//
// Class A = all four (non-capped) scores agree; Class B = any pair differs.
// For each Class B position record the four scores, the bracket, the stone
// count, the bracket class, and the first ply at which the move sequences
// diverge (new/new vs old/old self-play, and new/old vs old/new cross) with
// the two moves involved.
//
// Historical-table check: for every non-capped game outcome, classify the
// achieved score against the start position's stored bracket/value in EACH
// historical table generation as within [L,H] / above H / below L / no-entry.
// Below L is the alarm and is reported as witnesses.
//
// Reads ONLY. No build.zig edit, no engine-source edit. The game engine,
// move selectors, and weakened controls are copied verbatim from
// src/t401_bracket_tournament.zig (the proven T401 harness) and restructured
// for the four-game matrix.
//
// Compiles standalone:
//   zig build-exe -O ReleaseFast --dep version -Mroot=src/t407_divergence_matrix.zig \
//     -Mversion=src/version.zig --cache-dir /tmp/weizigo/t407/cache \
//     --global-cache-dir /tmp/weizigo/t407/global --name weizigo-t407 \
//     -femit-bin=/tmp/weizigo/t407/t407
//
// Usage: weizigo-t407 --size 3|4 [--wzo2 <p>] [--wzo1 <p>]
//          [--sample <N>] [--seed <N>] [--json <path>]
//          [--tables <t1>,<t2>,...]   (WZO1 historical tables for the matrix)
//          [--controls-only] [--seedctl weakened,N|h2h_seeded,N|null]

const std = @import("std");
const version = @import("version");
const rules = @import("rules.zig");
const artifact = @import("artifact.zig");
const artifact2 = @import("artifact2.zig");
const colex = @import("colex.zig");

const PLY_CAP: usize = 400;
const SCORES_ARE_BLACK_POSITIVE = true; // stated once, held throughout

// ═══════════════════════════════════════════════════════════════════════════
//  GAME ENGINE — copied verbatim from T401 (proven)
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

    const best_v = pinnedValue(best_L, best_H);
    const pass_v = pinnedValue(pass_L, pass_H);
    const pass_better = if (maximizing) pass_v > best_v else pass_v < best_v;

    if (pass_better or best_cell == null) {
        return .{ .cell = null, .L = pass_L, .H = pass_H };
    }
    return .{ .cell = best_cell, .L = best_L, .H = best_H };
}

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
//  FOUR-GAME MATRIX
// ═══════════════════════════════════════════════════════════════════════════

const Engine = enum { new, old };

const Slot = enum {
    new_new, // slot 1: new=Black, new=White
    new_old, // slot 2: new=Black, old=White
    old_new, // slot 3: old=Black, new=White
    old_old, // slot 4: old=Black, old=White
};

fn engineForSide(slot: Slot, side: i8) Engine {
    return switch (slot) {
        .new_new => .new,
        .old_old => .old,
        .new_old => if (side > 0) .new else .old,
        .old_new => if (side > 0) .old else .new,
    };
}

const GameRec = struct {
    score: i8 = 0,
    capped: bool = false,
    ply: usize = 0,
    double_pass: bool = false,
    moves: [PLY_CAP]?usize = [_]?usize{null} ** PLY_CAP,
    moves_len: usize = 0,
};

fn runSlot(
    comptime w: comptime_int,
    comptime h: comptime_int,
    dec: ?*const artifact.Decoded,
    a2: *const artifact2.LoadedArtifact,
    start_pos: [w * h]i8,
    start_side: i8,
    slot: Slot,
) GameRec {
    const GS = GameState(w, h);
    var state = GS.init(start_pos, start_side);
    var rec: GameRec = .{};
    var ply: usize = 0;

    while (ply < PLY_CAP and !state.isTerminal()) : (ply += 1) {
        const eng = engineForSide(slot, state.side);
        const move: ?usize = switch (eng) {
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
        rec.moves[ply] = move;
        rec.moves_len = ply + 1;
        state.applyMove(move) catch unreachable;
    }

    rec.score = state.finalScore();
    rec.capped = ply >= PLY_CAP and !state.isTerminal();
    rec.ply = ply;
    rec.double_pass = state.isTerminal();
    return rec;
}

fn runSlotWeakened(
    comptime w: comptime_int,
    comptime h: comptime_int,
    dec: ?*const artifact.Decoded,
    a2: *const artifact2.LoadedArtifact,
    start_pos: [w * h]i8,
    start_side: i8,
    slot: Slot,
    weaken_engine: Engine,
    weaken_every: usize,
    rng: std.Random,
) GameRec {
    const GS = GameState(w, h);
    var state = GS.init(start_pos, start_side);
    var rec: GameRec = .{};
    var ply: usize = 0;

    while (ply < PLY_CAP and !state.isTerminal()) : (ply += 1) {
        const eng = engineForSide(slot, state.side);
        const move: ?usize = if (eng == weaken_engine and ply > 0 and ply % weaken_every == 0)
            randomLegalMove(w, h, &state.pos, state.ko_point, state.side, rng)
        else switch (eng) {
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
        rec.moves[ply] = move;
        rec.moves_len = ply + 1;
        state.applyMove(move) catch unreachable;
    }

    rec.score = state.finalScore();
    rec.capped = ply >= PLY_CAP and !state.isTerminal();
    rec.ply = ply;
    rec.double_pass = state.isTerminal();
    return rec;
}

const BracketedPos = struct {
    colex: u32,
    side: i8,
    L: i8,
    H: i8,
};

const BracketClass = enum { straddling, decisive_black, decisive_white };

fn classifyPosition(L: i8, H: i8) BracketClass {
    if (L <= 0 and H >= 0) return .straddling;
    if (L > 0) return .decisive_black;
    return .decisive_white;
}

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
            if (L >= H) continue; // bracketed only

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
//  HISTORICAL TABLE CHECK
// ═══════════════════════════════════════════════════════════════════════════

const TableKind = enum { wzo2_current, wzo1 };

const HistTable = struct {
    name: []const u8,
    kind: TableKind,
    // for wzo2_current the bracket is already known from enumeration (bp.L/bpH)
    dec: ?*const artifact.Decoded = null, // for wzo1
};

const HistClass = enum { within, above, below, no_entry };

fn classifyWzo1(dec: *const artifact.Decoded, clex: u32, side: i8, score: i8) HistClass {
    const UNDEF: i8 = -128;
    const ci: usize = @intCast(clex);
    if (ci >= dec.vb.len) return .no_entry;
    const v: i8 = if (side > 0) dec.vb[ci] else dec.vw[ci];
    if (v == UNDEF) return .no_entry;
    if (score == v) return .within;
    if (score > v) return .above;
    return .below;
}

fn classifyWzo2Bracket(L: i8, H: i8, score: i8) HistClass {
    if (score < L) return .below;
    if (score > H) return .above;
    return .within;
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

// format a move as a small string into a buffer; returns slice
fn fmtMove(buf: *[4]u8, m: ?usize, w: usize) []const u8 {
    if (m) |cell| {
        const col = cell % w;
        const row = cell / w;
        buf[0] = 'A' + @as(u8, @intCast(col));
        buf[1] = '1' + @as(u8, @intCast(row));
        return buf[0..2];
    } else {
        buf[0] = 'p';
        buf[1] = 'a';
        buf[2] = 's';
        buf[3] = 's';
        return buf[0..4];
    }
}

// ═══════════════════════════════════════════════════════════════════════════
//  NULL CONTROL — seat-symmetry / determinism for self-play arms
// ═══════════════════════════════════════════════════════════════════════════

fn runNullSeatSymmetry(
    comptime w: comptime_int,
    comptime h: comptime_int,
    dec: ?*const artifact.Decoded,
    a2: *const artifact2.LoadedArtifact,
    positions: []const BracketedPos,
    seed: u64,
) !void {
    const p = std.debug.print;
    const X = colex.Indexer(w, h);
    const n_check = @min(positions.len, 20);

    p("\n═══════════════════════════════════════════════════════════\n", .{});
    p("NULL CONTROL: seat-symmetry / determinism  ({d} positions, seed={d})\n", .{ n_check, seed });
    p("  {d}x{d} — self-play arms byte-identical under repeated run\n\n", .{ w, h });

    // Code-level tautology: self-play engineForSide is seat-independent.
    var taut_fail = false;
    if (engineForSide(.new_new, 1) != .new) taut_fail = true;
    if (engineForSide(.new_new, -1) != .new) taut_fail = true;
    if (engineForSide(.old_old, 1) != .old) taut_fail = true;
    if (engineForSide(.old_old, -1) != .old) taut_fail = true;
    p("  tautology (engineForSide self-play seat-independent): {s}\n", .{if (taut_fail) "FAIL" else "PASS"});

    var rng = std.Random.DefaultPrng.init(seed);
    const rand = rng.random();

    var new_mismatch: usize = 0;
    var new_total: usize = 0;
    var old_mismatch: usize = 0;
    var old_total: usize = 0;

    for (0..n_check) |_| {
        const idx = rand.uintLessThan(usize, positions.len);
        const bp = positions[idx];
        const pos = X.pos_from_colex(bp.colex);

        // new/new determinism: two identical runs
        const r1 = runSlot(w, h, dec, a2, pos, bp.side, .new_new);
        const r2 = runSlot(w, h, dec, a2, pos, bp.side, .new_new);
        if (!r1.capped and !r2.capped) {
            new_total += 1;
            if (r1.score != r2.score or !std.mem.eql(?usize, r1.moves[0..r1.moves_len], r2.moves[0..r2.moves_len])) {
                new_mismatch += 1;
                p("  NEW MISMATCH: colex={d} score1={d} score2={d}\n", .{ bp.colex, r1.score, r2.score });
            }
        }

        // old/old determinism
        if (dec != null) {
            const o1 = runSlot(w, h, dec, a2, pos, bp.side, .old_old);
            const o2 = runSlot(w, h, dec, a2, pos, bp.side, .old_old);
            if (!o1.capped and !o2.capped) {
                old_total += 1;
                if (o1.score != o2.score or !std.mem.eql(?usize, o1.moves[0..o1.moves_len], o2.moves[0..o2.moves_len])) {
                    old_mismatch += 1;
                    p("  OLD MISMATCH: colex={d} score1={d} score2={d}\n", .{ bp.colex, o1.score, o2.score });
                }
            }
        }
    }

    p("\n  new/new byte-identical pairs: {d}/{d} mismatches (expect 0)\n", .{ new_mismatch, new_total });
    if (dec != null) {
        p("  old/old byte-identical pairs: {d}/{d} mismatches (expect 0)\n", .{ old_mismatch, old_total });
    }
    if (new_mismatch != 0 or old_mismatch != 0 or taut_fail) {
        p("\n  *** NULL CONTROL FAILED — engine is non-deterministic or seat-dependent; every number rests on sand ***\n", .{});
    } else {
        p("\n  NULL CONTROL PASS — self-play arms are deterministic and seat-symmetric\n", .{});
    }
    p("═══════════════════════════════════════════════════════════\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════
//  SEEDED H2H CONTROL — weaken new in one cross arm, measure worse
// ═══════════════════════════════════════════════════════════════════════════

fn runSeededH2h(
    comptime w: comptime_int,
    comptime h: comptime_int,
    dec: ?*const artifact.Decoded,
    a2: *const artifact2.LoadedArtifact,
    positions: []const BracketedPos,
    seed: u64,
    weaken_every: usize,
) !void {
    const p = std.debug.print;
    const X = colex.Indexer(w, h);
    const n_check = @min(positions.len, 200);

    p("\n═══════════════════════════════════════════════════════════\n", .{});
    p("SEEDED H2H CONTROL: weaken new in one cross arm  (weaken_every={d}, {d} positions, seed={d})\n", .{ weaken_every, n_check, seed });
    p("  {d}x{d}\n\n", .{ w, h });

    var rng = std.Random.DefaultPrng.init(seed);
    const rand = rng.random();

    // RED: weaken new in new_old (new=Black if bp.side=Black else new=White), compare vs normal old_new.
    // For each position, the "new as first-mover" slot is new_old if bp.side=Black, old_new if bp.side=White.
    // We measure: does weakening new make new's outcome worse vs the normal cross game?
    var red_better: usize = 0;
    var red_equal: usize = 0;
    var red_worse: usize = 0;
    var red_total: usize = 0;

    for (0..n_check) |pi| {
        const idx = rand.uintLessThan(usize, positions.len);
        const bp = positions[idx];
        const pos = X.pos_from_colex(bp.colex);

        // normal cross arms
        const no = runSlot(w, h, dec, a2, pos, bp.side, .new_old);
        const on = runSlot(w, h, dec, a2, pos, bp.side, .old_new);

        // weaken new in the slot where new is the first mover
        const new_first_slot: Slot = if (bp.side > 0) .new_old else .old_new;
        var wrng = std.Random.DefaultPrng.init(seed +% @as(u64, pi) +% 4243);
        const weak = runSlotWeakened(w, h, dec, a2, pos, bp.side, new_first_slot, .new, weaken_every, wrng.random());

        if (no.capped or on.capped or weak.capped) continue;
        red_total += 1;

        // "new better" metric: new as the side-to-move engine scores better than old as side-to-move.
        // Normal: compare no vs on. new better = if bp.side>0: no.score > on.score else on.score < no.score
        // Weakened: replace the new-first slot's score with weak.score.
        const normal_new_score: i8 = if (bp.side > 0) no.score else on.score;
        const normal_old_score: i8 = if (bp.side > 0) on.score else no.score;
        const weak_new_score: i8 = weak.score;
        const weak_old_score: i8 = if (bp.side > 0) on.score else no.score; // old slot unchanged

        const normal_better = if (bp.side > 0) normal_new_score > normal_old_score else normal_new_score < normal_old_score;
        const weak_better = if (bp.side > 0) weak_new_score > weak_old_score else weak_new_score < weak_old_score;

        // Classify weakening effect on new's outcome:
        // worse = new's score got worse (less favourable) under weakening
        const new_got_worse = if (bp.side > 0) weak_new_score < normal_new_score else weak_new_score > normal_new_score;
        const new_got_better = if (bp.side > 0) weak_new_score > normal_new_score else weak_new_score < normal_new_score;

        if (new_got_worse) {
            red_worse += 1;
        } else if (new_got_better) {
            red_better += 1;
        } else {
            red_equal += 1;
        }
        _ = normal_better;
        _ = weak_better;
    }

    p("  RED (weakened new vs normal new, same position): new got worse {d} / equal {d} / better {d}  (total {d})\n", .{ red_worse, red_equal, red_better, red_total });
    if (red_total > 0) {
        p("    worse rate: {d:.1}%\n", .{100.0 * @as(f64, @floatFromInt(red_worse)) / @as(f64, @floatFromInt(red_total))});
    }

    // GREEN: normal cross arms reproduce — new should not be worse than itself (determinism)
    var green_worse: usize = 0;
    var green_total: usize = 0;
    for (0..@min(n_check, 50)) |_| {
        const idx = rand.uintLessThan(usize, positions.len);
        const bp = positions[idx];
        const pos = X.pos_from_colex(bp.colex);
        const no1 = runSlot(w, h, dec, a2, pos, bp.side, .new_old);
        const no2 = runSlot(w, h, dec, a2, pos, bp.side, .new_old);
        if (no1.capped or no2.capped) continue;
        green_total += 1;
        if (no1.score != no2.score) green_worse += 1;
    }
    p("\n  GREEN (new_old determinism): {d}/{d} mismatches (expect 0)\n", .{ green_worse, green_total });
    p("═══════════════════════════════════════════════════════════\n", .{});
}

// ═══════════════════════════════════════════════════════════════════════════
//  DIVERGENCE PLY — first ply where two move sequences differ
// ═══════════════════════════════════════════════════════════════════════════

const DivResult = struct {
    ply: ?usize, // null if sequences identical
    move_a: ?usize,
    move_b: ?usize,
};

fn firstDivergence(a: *const GameRec, b: *const GameRec) DivResult {
    const len = @min(a.moves_len, b.moves_len);
    for (0..len) |i| {
        if (a.moves[i] != b.moves[i]) {
            return .{ .ply = i, .move_a = a.moves[i], .move_b = b.moves[i] };
        }
    }
    // identical up to the common length
    return .{ .ply = null, .move_a = null, .move_b = null };
}

// ═══════════════════════════════════════════════════════════════════════════
//  MAIN
// ═══════════════════════════════════════════════════════════════════════════

const SeedCtlMode = enum { none, weakened, h2h_seeded, null_sym };

fn runMatrix(
    comptime w: comptime_int,
    comptime h: comptime_int,
    io: std.Io,
    gpa: std.mem.Allocator,
    wzo2_path: []const u8,
    wzo1_path: []const u8,
    hist_wzo1_paths: []const []const u8,
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

    p("T407 divergence matrix {d}x{d}  seed={d}\n\n", .{ w, h, seed });

    // Load WZO2 (new engine)
    var a2 = try artifact2.load(io, std.Io.Dir.cwd(), wzo2_path, gpa);
    defer a2.deinit();
    p("loaded WZO2 (new): {s}  {d}x{d}  groups={d}  entries={d}\n", .{
        wzo2_path, a2.header.w, a2.header.h, a2.header.n_groups, a2.header.n_entries,
    });

    // Load WZO1 (old engine)
    var dec = try artifact.load(io, std.Io.Dir.cwd(), wzo1_path, gpa);
    defer dec.deinit();
    p("loaded WZO1 (old): {s}  {d}x{d}  legal={d}  rules={s}\n", .{
        wzo1_path, dec.header.board_w, dec.header.board_h, dec.header.legal_count, artifact.rulesName(dec.header.rules_id),
    });

    // Enumerate bracketed positions
    const all_positions = try enumerateBracketed(w, h, &a2, gpa);
    defer gpa.free(all_positions);
    p("enumerated {d} bracketed positions (L<H, passes=0, ko=NONE)\n", .{all_positions.len});

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
    p("  straddling (L<=0<=H): {d}\n", .{straddling_count});
    p("  decisive L>0:         {d}\n", .{decisive_black_count});
    p("  decisive H<0:         {d}\n", .{decisive_white_count});

    // Null control first (one-time, ~20 positions)
    try runNullSeatSymmetry(w, h, &dec, &a2, all_positions, seed);

    if (controls_only) {
        switch (seedctl_mode) {
            .h2h_seeded => try runSeededH2h(w, h, &dec, &a2, all_positions, seed, seedctl_weaken_every),
            .none => {},
            else => {},
        }
        return;
    }

    // Sample
    var positions = all_positions;
    var sampled: ?[]BracketedPos = null;
    if (sample_n != null and sample_n.? < all_positions.len) {
        var rng = std.Random.DefaultPrng.init(seed);
        const rand = rng.random();
        const sp = try gpa.alloc(BracketedPos, sample_n.?);
        for (0..sample_n.?) |i| sp[i] = all_positions[i];
        var t = sample_n.?;
        for (sample_n.?..all_positions.len) |i| {
            t += 1;
            const j = rand.uintLessThan(usize, t);
            if (j < sample_n.?) sp[j] = all_positions[i];
        }
        sampled = sp;
        positions = sp;
        p("sampled {d}/{d} positions (seed={d})\n", .{ sample_n.?, all_positions.len, seed });
    }

    const n_pos = positions.len;
    p("\n[progress] running four-game matrix: {d} positions x 4 games = {d} games\n", .{ n_pos, n_pos * 4 });

    // ── Accumulators ──
    var class_a: usize = 0;
    var class_b: usize = 0;
    var cap_class: usize = 0; // any of the 4 capped
    var class_b_total: usize = 0; // positions contributing to class A/B (non-capped)

    // Self-play baseline (new/new vs old/old) three-way split — T401 B1/B2 analogue
    var sp_new_better: usize = 0;
    var sp_equal: usize = 0;
    var sp_new_worse: usize = 0;
    var sp_total: usize = 0;

    // Cross h2h (new_old vs old_new) three-way split — T401 h2h analogue
    var x_new_better: usize = 0;
    var x_equal: usize = 0;
    var x_new_worse: usize = 0;
    var x_total: usize = 0;

    // Identical move sequences (cross h2h pair)
    var x_identical_seq: usize = 0;
    var x_seq_total: usize = 0;

    // Per-ply move agreement between new and old as first mover (new_new vs old_old)
    var sp_ply_agree: usize = 0;
    var sp_ply_total: usize = 0;

    // Per bracket class
    const ClassAgg = struct {
        a: usize = 0,
        b: usize = 0,
        cap: usize = 0,
        sp_better: usize = 0,
        sp_equal: usize = 0,
        sp_worse: usize = 0,
        sp_total: usize = 0,
        x_better: usize = 0,
        x_equal: usize = 0,
        x_worse: usize = 0,
        x_total: usize = 0,
    };
    var agg_strad = ClassAgg{};
    var agg_db = ClassAgg{};
    var agg_dw = ClassAgg{};

    // Per-position scored records (for historical-table check without re-running)
    const PerPos = struct {
        colex: u32,
        side: i8,
        L: i8,
        H: i8,
        capped: bool,
        scores: [4]i8, // nn, no, on, oo
    };
    var per_pos: std.ArrayListUnmanaged(PerPos) = .empty;
    defer per_pos.deinit(gpa);

    // Class-B catalogue (bounded; full data in JSON)
    const ClassBEntry = struct {
        colex: u32,
        side: i8,
        L: i8,
        H: i8,
        stones: u8,
        cls: BracketClass,
        nn: i8,
        no: i8,
        on: i8,
        oo: i8,
        sp_div_ply: ?usize,
        sp_div_new_move: ?usize,
        sp_div_old_move: ?usize,
        x_div_ply: ?usize,
        x_div_a_move: ?usize,
        x_div_b_move: ?usize,
    };
    var class_b_entries: std.ArrayListUnmanaged(ClassBEntry) = .empty;
    defer class_b_entries.deinit(gpa);

    // Historical-table matrix accumulators
    // For the current WZO2 table + each named WZO1 table.
    const HistAgg = struct {
        name: []const u8,
        kind: TableKind,
        within: usize = 0,
        above: usize = 0,
        below: usize = 0,
        no_entry: usize = 0,
        total: usize = 0,
        below_by_slot: [4]usize = .{ 0, 0, 0, 0 }, // nn, no, on, oo
        below_witnesses: std.ArrayListUnmanaged([]const u8) = .empty,
    };
    var hist_cur = HistAgg{ .name = wzo2_path, .kind = .wzo2_current };
    defer hist_cur.below_witnesses.deinit(gpa);
    var hist_wzo1_arr: std.ArrayListUnmanaged(HistAgg) = .empty;
    defer {
        for (hist_wzo1_arr.items) |*ha| ha.below_witnesses.deinit(gpa);
        hist_wzo1_arr.deinit(gpa);
    }
    for (hist_wzo1_paths) |hp| {
        try hist_wzo1_arr.append(gpa, .{ .name = hp, .kind = .wzo1 });
    }

    const slots = [_]Slot{ .new_new, .new_old, .old_new, .old_old };

    for (positions, 0..) |bp, pi| {
        const pos = X.pos_from_colex(bp.colex);
        const cls = classifyPosition(bp.L, bp.H);
        const agg: *ClassAgg = switch (cls) {
            .straddling => &agg_strad,
            .decisive_black => &agg_db,
            .decisive_white => &agg_dw,
        };

        // stone count
        var stones: u8 = 0;
        for (pos) |x| {
            if (x != 0) stones += 1;
        }

        var recs: [4]GameRec = undefined;
        var any_capped = false;
        for (slots, 0..) |s, si| {
            recs[si] = runSlot(w, h, &dec, &a2, pos, bp.side, s);
            if (recs[si].capped) any_capped = true;
        }

        if (any_capped) {
            cap_class += 1;
            agg.cap += 1;
            // cap-hits are their own class, never scored; excluded from the
            // historical-table matrix (which is over scored games only).
        } else {
            class_b_total += 1;
            try per_pos.append(gpa, .{
                .colex = bp.colex,
                .side = bp.side,
                .L = bp.L,
                .H = bp.H,
                .capped = false,
                .scores = .{ recs[0].score, recs[1].score, recs[2].score, recs[3].score },
            });
            // Class A/B
            const s_nn = recs[0].score;
            const s_no = recs[1].score;
            const s_on = recs[2].score;
            const s_oo = recs[3].score;
            const all_equal = (s_nn == s_no and s_no == s_on and s_on == s_oo);
            if (all_equal) {
                class_a += 1;
                agg.a += 1;
            } else {
                class_b += 1;
                agg.b += 1;
                const sp_div = firstDivergence(&recs[0], &recs[3]); // new_new vs old_old
                const x_div = firstDivergence(&recs[1], &recs[2]); // new_old vs old_new
                try class_b_entries.append(gpa, .{
                    .colex = bp.colex,
                    .side = bp.side,
                    .L = bp.L,
                    .H = bp.H,
                    .stones = stones,
                    .cls = cls,
                    .nn = s_nn,
                    .no = s_no,
                    .on = s_on,
                    .oo = s_oo,
                    .sp_div_ply = sp_div.ply,
                    .sp_div_new_move = sp_div.move_a,
                    .sp_div_old_move = sp_div.move_b,
                    .x_div_ply = x_div.ply,
                    .x_div_a_move = x_div.move_a,
                    .x_div_b_move = x_div.move_b,
                });
            }

            // Self-play baseline split (new_new vs old_old)
            sp_total += 1;
            agg.sp_total += 1;
            const new_better_sp = if (bp.side > 0) s_nn > s_oo else s_nn < s_oo;
            if (s_nn == s_oo) {
                sp_equal += 1;
                agg.sp_equal += 1;
            } else if (new_better_sp) {
                sp_new_better += 1;
                agg.sp_better += 1;
            } else {
                sp_new_worse += 1;
                agg.sp_worse += 1;
            }

            // Cross h2h split (new_old vs old_new) — new better if new as first-mover beats old as first-mover
            x_total += 1;
            agg.x_total += 1;
            const new_first_score: i8 = if (bp.side > 0) s_no else s_on;
            const old_first_score: i8 = if (bp.side > 0) s_on else s_no;
            const new_better_x = if (bp.side > 0) new_first_score > old_first_score else new_first_score < old_first_score;
            if (new_first_score == old_first_score) {
                x_equal += 1;
                agg.x_equal += 1;
            } else if (new_better_x) {
                x_new_better += 1;
                agg.x_better += 1;
            } else {
                x_new_worse += 1;
                agg.x_worse += 1;
            }

            // Identical move sequences (cross pair)
            x_seq_total += 1;
            if (std.mem.eql(?usize, recs[1].moves[0..recs[1].moves_len], recs[2].moves[0..recs[2].moves_len])) {
                x_identical_seq += 1;
            }

            // Per-ply agreement new_new vs old_old
            const common = @min(recs[0].moves_len, recs[3].moves_len);
            for (0..common) |i| {
                sp_ply_total += 1;
                if (recs[0].moves[i] == recs[3].moves[i]) sp_ply_agree += 1;
            }

            // Historical-table check: each of the 4 non-capped games vs each table
            const scores = [_]i8{ s_nn, s_no, s_on, s_oo };
            const slot_names = [_][]const u8{ "new_new", "new_old", "old_new", "old_old" };

            // current WZO2 (bracket = bp.L, bp.H)
            for (scores, 0..) |sc, si| {
                hist_cur.total += 1;
                const c = classifyWzo2Bracket(bp.L, bp.H, sc);
                switch (c) {
                    .within => hist_cur.within += 1,
                    .above => hist_cur.above += 1,
                    .below => {
                        hist_cur.below += 1;
                        hist_cur.below_by_slot[si] += 1;
                        const witness = try std.fmt.allocPrint(gpa, "{d}x{d} colex={d} side={d} slot={s} score={d} bracket=[{d},{d}] BELOW-L table={s}", .{ w, h, bp.colex, bp.side, slot_names[si], sc, bp.L, bp.H, wzo2_path });
                        try hist_cur.below_witnesses.append(gpa, witness);
                    },
                    .no_entry => hist_cur.no_entry += 1,
                }
            }
        }

        // Per-ply agreement for capped positions still useful? skip — keep scored-only.

        if ((pi + 1) % 50 == 0 or pi + 1 == n_pos) {
            p("[progress] {d}/{d} positions  (classA={d} classB={d} cap={d})\n", .{ pi + 1, n_pos, class_a, class_b, cap_class });
        }
    }

    // ── Historical WZO1 tables (load one at a time; games already played) ──
    p("\n[progress] historical-table check: {d} WZO1 tables x {d} scored positions x 4 games\n", .{ hist_wzo1_arr.items.len, class_b_total });
    const slot_names = [_][]const u8{ "new_new", "new_old", "old_new", "old_old" };
    for (hist_wzo1_arr.items) |*ha| {
        var hdec = artifact.load(io, std.Io.Dir.cwd(), ha.name, gpa) catch |err| {
            p("  WARN: could not load {s}: {s} — marking all no_entry\n", .{ ha.name, @errorName(err) });
            ha.total = class_b_total * 4;
            ha.no_entry = class_b_total * 4;
            continue;
        };
        defer hdec.deinit();
        p("  loaded {s}  {d}x{d}  rules={s}\n", .{ ha.name, hdec.header.board_w, hdec.header.board_h, artifact.rulesName(hdec.header.rules_id) });

        for (per_pos.items) |pp| {
            for (pp.scores, 0..) |sc, si| {
                ha.total += 1;
                const c = classifyWzo1(&hdec, pp.colex, pp.side, sc);
                switch (c) {
                    .within => ha.within += 1,
                    .above => ha.above += 1,
                    .below => {
                        ha.below += 1;
                        ha.below_by_slot[si] += 1;
                        const ci: usize = @intCast(pp.colex);
                        const stored: i8 = if (pp.side > 0) hdec.vb[ci] else hdec.vw[ci];
                        const witness = try std.fmt.allocPrint(gpa, "{d}x{d} colex={d} side={d} slot={s} score={d} stored={d} BELOW-L table={s}", .{ w, h, pp.colex, pp.side, slot_names[si], sc, stored, ha.name });
                        try ha.below_witnesses.append(gpa, witness);
                    },
                    .no_entry => ha.no_entry += 1,
                }
            }
        }
        p("  {s}: within={d} above={d} below={d} no_entry={d}  (total {d})\n", .{ ha.name, ha.within, ha.above, ha.below, ha.no_entry, ha.total });
    }

    // ── Report ──
    p("\n═══════════════════════════════════════════════════════════\n", .{});
    p("T407 RESULTS  {d}x{d}  {d} positions  seed={d}\n", .{ w, h, n_pos, seed });
    if (sample_n) |sn| p("  SAMPLE {d}/{d}\n", .{ sn, all_positions.len });
    p("  ply cap: {d}  (cap-hits their own class, never scored)\n", .{PLY_CAP});
    p("\n", .{});
    p("FOUR-GAME MATRIX — class split (denominators first):\n", .{});
    p("  positions played:        {d}\n", .{n_pos});
    p("  cap-class (any capped):  {d} / {d}\n", .{ cap_class, n_pos });
    p("  scored (all 4 non-cap):  {d} / {d}\n", .{ class_b_total, n_pos });
    p("  Class A (all 4 agree):   {d} / {d}  ({d:.1}% of scored)\n", .{ class_a, class_b_total, pct(class_a, class_b_total) });
    p("  Class B (any disagree):  {d} / {d}  ({d:.1}% of scored)\n", .{ class_b, class_b_total, pct(class_b, class_b_total) });
    if (class_b_total == 0) {
        p("\n  *** Class B is EMPTY at this size — contradicts T401's divergence; check the other size ***\n", .{});
    }

    p("\nSELF-PLAY BASELINE (new/new vs old/old, same first-to-move) — three-way:\n", .{});
    p("  new better: {d} / {d}  ({d:.1}%)\n", .{ sp_new_better, sp_total, pct(sp_new_better, sp_total) });
    p("  equal:      {d} / {d}  ({d:.1}%)\n", .{ sp_equal, sp_total, pct(sp_equal, sp_total) });
    p("  new worse:  {d} / {d}  ({d:.1}%)\n", .{ sp_new_worse, sp_total, pct(sp_new_worse, sp_total) });

    p("\nCROSS HEAD-TO-HEAD (new_old vs old_new) — three-way:\n", .{});
    p("  new better: {d} / {d}  ({d:.1}%)\n", .{ x_new_better, x_total, pct(x_new_better, x_total) });
    p("  equal:      {d} / {d}  ({d:.1}%)\n", .{ x_equal, x_total, pct(x_equal, x_total) });
    p("  new worse:  {d} / {d}  ({d:.1}%)\n", .{ x_new_worse, x_total, pct(x_new_worse, x_total) });
    p("  identical-sequence cross pairs: {d} / {d}  ({d:.1}%)\n", .{ x_identical_seq, x_seq_total, pct(x_identical_seq, x_seq_total) });
    p("  per-ply move agreement (new_new vs old_old): {d} / {d}  ({d:.1}%)\n", .{ sp_ply_agree, sp_ply_total, pct(sp_ply_agree, sp_ply_total) });

    p("\nCLASS-B RATE PER BRACKET CLASS (denominator = scored in that class):\n", .{});
    p("  straddling (L<=0<=H):  class B {d} / {d} scored  (cap {d})\n", .{ agg_strad.b, agg_strad.a + agg_strad.b, agg_strad.cap });
    p("  decisive L>0:          class B {d} / {d} scored  (cap {d})\n", .{ agg_db.b, agg_db.a + agg_db.b, agg_db.cap });
    p("  decisive H<0:          class B {d} / {d} scored  (cap {d})\n", .{ agg_dw.b, agg_dw.a + agg_dw.b, agg_dw.cap });

    p("\nSELF-PLAY SPLIT PER BRACKET CLASS (new better / equal / new worse / total):\n", .{});
    p("  straddling:   {d} / {d} / {d} / {d}\n", .{ agg_strad.sp_better, agg_strad.sp_equal, agg_strad.sp_worse, agg_strad.sp_total });
    p("  decisive L>0: {d} / {d} / {d} / {d}\n", .{ agg_db.sp_better, agg_db.sp_equal, agg_db.sp_worse, agg_db.sp_total });
    p("  decisive H<0: {d} / {d} / {d} / {d}\n", .{ agg_dw.sp_better, agg_dw.sp_equal, agg_dw.sp_worse, agg_dw.sp_total });

    p("\nCROSS H2H SPLIT PER BRACKET CLASS (new better / equal / new worse / total):\n", .{});
    p("  straddling:   {d} / {d} / {d} / {d}\n", .{ agg_strad.x_better, agg_strad.x_equal, agg_strad.x_worse, agg_strad.x_total });
    p("  decisive L>0: {d} / {d} / {d} / {d}\n", .{ agg_db.x_better, agg_db.x_equal, agg_db.x_worse, agg_db.x_total });
    p("  decisive H<0: {d} / {d} / {d} / {d}\n", .{ agg_dw.x_better, agg_dw.x_equal, agg_dw.x_worse, agg_dw.x_total });

    // Class-B catalogue (first N to stdout, full in JSON)
    p("\nCLASS-B CATALOGUE (first 30 shown; full set in JSON):\n", .{});
    const show_n = @min(class_b_entries.items.len, 30);
    for (class_b_entries.items[0..show_n]) |e| {
        var sp_buf: [64]u8 = undefined;
        var x_buf: [64]u8 = undefined;
        const sp_str = blk: {
            if (e.sp_div_ply) |ply| {
                var ma: [4]u8 = undefined;
                var mb: [4]u8 = undefined;
                const a = fmtMove(&ma, e.sp_div_new_move, w);
                const b = fmtMove(&mb, e.sp_div_old_move, w);
                break :blk std.fmt.bufPrint(&sp_buf, "ply{d} new={s} old={s}", .{ ply, a, b }) catch "?";
            }
            break :blk "identical";
        };
        const x_str = blk: {
            if (e.x_div_ply) |ply| {
                var ma: [4]u8 = undefined;
                var mb: [4]u8 = undefined;
                const a = fmtMove(&ma, e.x_div_a_move, w);
                const b = fmtMove(&mb, e.x_div_b_move, w);
                break :blk std.fmt.bufPrint(&x_buf, "ply{d} a={s} b={s}", .{ ply, a, b }) catch "?";
            }
            break :blk "identical";
        };
        p("  colex={d} side={d} bracket=[{d},{d}] stones={d} nn={d} no={d} on={d} oo={d} | sp_div={s} x_div={s}\n", .{
            e.colex, e.side, e.L, e.H, e.stones, e.nn, e.no, e.on, e.oo, sp_str, x_str,
        });
    }

    // Historical-table matrix
    p("\nHISTORICAL-TABLE MATRIX (within / above / below / no-entry, per game scored):\n", .{});
    p("  {s:<45} within  above  below  no_entry  total\n", .{"table"});
    p("  {s:<45} {d:6}  {d:5}  {d:5}  {d:8}  {d:5}\n", .{ hist_cur.name, hist_cur.within, hist_cur.above, hist_cur.below, hist_cur.no_entry, hist_cur.total });
    for (hist_wzo1_arr.items) |ha| {
        p("  {s:<45} {d:6}  {d:5}  {d:5}  {d:8}  {d:5}\n", .{ ha.name, ha.within, ha.above, ha.below, ha.no_entry, ha.total });
    }

    // Below-L witnesses (the alarm)
    p("\nBELOW-L WITNESSES (the alarm; first 200 per table):\n", .{});
    p("  [{s}] below={d}\n", .{ hist_cur.name, hist_cur.below });
    for (hist_cur.below_witnesses.items[0..@min(hist_cur.below_witnesses.items.len, 200)]) |wit| p("    {s}\n", .{wit});
    for (hist_wzo1_arr.items) |ha| {
        p("  [{s}] below={d}\n", .{ ha.name, ha.below });
        for (ha.below_witnesses.items[0..@min(ha.below_witnesses.items.len, 200)]) |wit| p("    {s}\n", .{wit});
    }

    p("\n═══════════════════════════════════════════════════════════\n", .{});

    // ── JSON ──
    var j = Json.init(gpa);
    defer j.deinit();

    try j.raw("{\n");
    try j.raw("  \"task_id\": "); try j.str("T407"); try j.comma(); try j.newline();
    try j.raw("  \"date\": "); try j.str("2026-08-07"); try j.comma(); try j.newline();
    try j.raw("  \"model\": "); try j.str("glm-5.2"); try j.comma(); try j.newline();
    try j.raw("  \"size\": "); try j.str(std.fmt.allocPrint(gpa, "{d}x{d}", .{ w, h }) catch unreachable); try j.comma(); try j.newline();
    try j.raw("  \"ply_cap\": "); try j.num(PLY_CAP); try j.comma(); try j.newline();
    try j.raw("  \"seed\": "); try j.num(seed); try j.comma(); try j.newline();
    if (sample_n) |sn| {
        try j.raw("  \"sample\": "); try j.num(sn); try j.comma(); try j.newline();
        try j.raw("  \"positions_enumerated\": "); try j.num(all_positions.len); try j.comma(); try j.newline();
    }
    try j.raw("  \"positions_played\": "); try j.num(n_pos); try j.comma(); try j.newline();
    try j.raw("  \"straddling\": "); try j.num(straddling_count); try j.comma(); try j.newline();
    try j.raw("  \"decisive_black\": "); try j.num(decisive_black_count); try j.comma(); try j.newline();
    try j.raw("  \"decisive_white\": "); try j.num(decisive_white_count); try j.comma(); try j.newline();
    try j.raw("  \"cap_class\": "); try j.num(cap_class); try j.comma(); try j.newline();
    try j.raw("  \"scored\": "); try j.num(class_b_total); try j.comma(); try j.newline();
    try j.raw("  \"class_a\": "); try j.num(class_a); try j.comma(); try j.newline();
    try j.raw("  \"class_b\": "); try j.num(class_b); try j.comma(); try j.newline();
    try j.raw("  \"sp_new_better\": "); try j.num(sp_new_better); try j.comma(); try j.newline();
    try j.raw("  \"sp_equal\": "); try j.num(sp_equal); try j.comma(); try j.newline();
    try j.raw("  \"sp_new_worse\": "); try j.num(sp_new_worse); try j.comma(); try j.newline();
    try j.raw("  \"sp_total\": "); try j.num(sp_total); try j.comma(); try j.newline();
    try j.raw("  \"x_new_better\": "); try j.num(x_new_better); try j.comma(); try j.newline();
    try j.raw("  \"x_equal\": "); try j.num(x_equal); try j.comma(); try j.newline();
    try j.raw("  \"x_new_worse\": "); try j.num(x_new_worse); try j.comma(); try j.newline();
    try j.raw("  \"x_total\": "); try j.num(x_total); try j.comma(); try j.newline();
    try j.raw("  \"x_identical_seq\": "); try j.num(x_identical_seq); try j.comma(); try j.newline();
    try j.raw("  \"x_seq_total\": "); try j.num(x_seq_total); try j.comma(); try j.newline();
    try j.raw("  \"sp_ply_agree\": "); try j.num(sp_ply_agree); try j.comma(); try j.newline();
    try j.raw("  \"sp_ply_total\": "); try j.num(sp_ply_total); try j.comma(); try j.newline();
    try j.raw("  \"wzo2_path\": "); try j.str(wzo2_path); try j.comma(); try j.newline();
    try j.raw("  \"wzo1_path\": "); try j.str(wzo1_path); try j.comma(); try j.newline();

    // per-class aggs
    try j.raw("  \"agg_straddling\": "); try writeClassAgg(&j, agg_strad); try j.comma(); try j.newline();
    try j.raw("  \"agg_decisive_black\": "); try writeClassAgg(&j, agg_db); try j.comma(); try j.newline();
    try j.raw("  \"agg_decisive_white\": "); try writeClassAgg(&j, agg_dw); try j.comma(); try j.newline();

    // historical matrix
    try j.raw("  \"hist_tables\": [");
    try j.newline();
    try j.raw("    "); try writeHistAgg(&j, hist_cur); try j.comma(); try j.newline();
    for (hist_wzo1_arr.items, 0..) |ha, hi| {
        try j.raw("    "); try writeHistAgg(&j, ha);
        if (hi + 1 < hist_wzo1_arr.items.len) try j.comma();
        try j.newline();
    }
    try j.raw("  ],"); try j.newline();

    // class-B catalogue
    try j.raw("  \"class_b_catalogue\": [");
    try j.newline();
    for (class_b_entries.items, 0..) |e, ei| {
        try j.raw("    "); try writeClassBEntry(&j, e, w);
        if (ei + 1 < class_b_entries.items.len) try j.comma();
        try j.newline();
    }
    try j.raw("  ]"); try j.newline();

    try j.raw("}\n");

    const cwd = std.Io.Dir.cwd();
    const jf = try cwd.createFile(io, json_path, .{});
    defer jf.close(io);
    try jf.writeStreamingAll(io, j.buf.items);
    p("wrote {s}\n", .{json_path});

    // Seeded h2h control after main run
    if (seedctl_mode == .h2h_seeded) {
        try runSeededH2h(w, h, &dec, &a2, positions, seed, seedctl_weaken_every);
    }
}

fn pct(num_v: usize, den: usize) f64 {
    if (den == 0) return 0.0;
    return 100.0 * @as(f64, @floatFromInt(num_v)) / @as(f64, @floatFromInt(den));
}

fn writeClassAgg(j: *Json, a: anytype) !void {
    try j.raw("{");
    try j.raw("\"a\":"); try j.num(a.a); try j.raw(",");
    try j.raw("\"b\":"); try j.num(a.b); try j.raw(",");
    try j.raw("\"cap\":"); try j.num(a.cap); try j.raw(",");
    try j.raw("\"sp_better\":"); try j.num(a.sp_better); try j.raw(",");
    try j.raw("\"sp_equal\":"); try j.num(a.sp_equal); try j.raw(",");
    try j.raw("\"sp_worse\":"); try j.num(a.sp_worse); try j.raw(",");
    try j.raw("\"sp_total\":"); try j.num(a.sp_total); try j.raw(",");
    try j.raw("\"x_better\":"); try j.num(a.x_better); try j.raw(",");
    try j.raw("\"x_equal\":"); try j.num(a.x_equal); try j.raw(",");
    try j.raw("\"x_worse\":"); try j.num(a.x_worse); try j.raw(",");
    try j.raw("\"x_total\":"); try j.num(a.x_total);
    try j.raw("}");
}

fn writeHistAgg(j: *Json, ha: anytype) !void {
    try j.raw("{");
    try j.raw("\"name\":"); try j.str(ha.name); try j.raw(",");
    try j.raw("\"kind\":"); try j.str(if (ha.kind == .wzo2_current) "wzo2_current" else "wzo1"); try j.raw(",");
    try j.raw("\"within\":"); try j.num(ha.within); try j.raw(",");
    try j.raw("\"above\":"); try j.num(ha.above); try j.raw(",");
    try j.raw("\"below\":"); try j.num(ha.below); try j.raw(",");
    try j.raw("\"below_by_slot\":["); try j.num(ha.below_by_slot[0]); try j.raw(","); try j.num(ha.below_by_slot[1]); try j.raw(","); try j.num(ha.below_by_slot[2]); try j.raw(","); try j.num(ha.below_by_slot[3]); try j.raw("],");
    try j.raw("\"no_entry\":"); try j.num(ha.no_entry); try j.raw(",");
    try j.raw("\"total\":"); try j.num(ha.total);
    try j.raw("}");
}

fn writeClassBEntry(j: *Json, e: anytype, w: usize) !void {
    var mbuf_a: [4]u8 = undefined;
    var mbuf_b: [4]u8 = undefined;
    var mbuf_c: [4]u8 = undefined;
    var mbuf_d: [4]u8 = undefined;
    try j.raw("{");
    try j.raw("\"colex\":"); try j.num(e.colex); try j.raw(",");
    try j.raw("\"side\":"); try j.num(e.side); try j.raw(",");
    try j.raw("\"L\":"); try j.num(e.L); try j.raw(",");
    try j.raw("\"H\":"); try j.num(e.H); try j.raw(",");
    try j.raw("\"stones\":"); try j.num(e.stones); try j.raw(",");
    try j.raw("\"cls\":\""); try j.raw(switch (e.cls) {
        .straddling => "straddling",
        .decisive_black => "decisive_black",
        .decisive_white => "decisive_white",
    }); try j.raw("\",");
    try j.raw("\"nn\":"); try j.num(e.nn); try j.raw(",");
    try j.raw("\"no\":"); try j.num(e.no); try j.raw(",");
    try j.raw("\"on\":"); try j.num(e.on); try j.raw(",");
    try j.raw("\"oo\":"); try j.num(e.oo); try j.raw(",");
    if (e.sp_div_ply) |ply| {
        try j.raw("\"sp_div_ply\":"); try j.num(ply); try j.raw(",");
        try j.raw("\"sp_div_new\":\""); try j.raw(fmtMove(&mbuf_a, e.sp_div_new_move, w)); try j.raw("\",");
        try j.raw("\"sp_div_old\":\""); try j.raw(fmtMove(&mbuf_b, e.sp_div_old_move, w)); try j.raw("\",");
    } else {
        try j.raw("\"sp_div_ply\":null,\"sp_div_new\":null,\"sp_div_old\":null,");
    }
    if (e.x_div_ply) |ply| {
        try j.raw("\"x_div_ply\":"); try j.num(ply); try j.raw(",");
        try j.raw("\"x_div_a\":\""); try j.raw(fmtMove(&mbuf_c, e.x_div_a_move, w)); try j.raw("\",");
        try j.raw("\"x_div_b\":\""); try j.raw(fmtMove(&mbuf_d, e.x_div_b_move, w)); try j.raw("\"");
    } else {
        try j.raw("\"x_div_ply\":null,\"x_div_a\":null,\"x_div_b\":null");
    }
    try j.raw("}");
}

// ═══════════════════════════════════════════════════════════════════════════
//  ENTRY POINT
// ═══════════════════════════════════════════════════════════════════════════

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    const io = init.io;
    _ = version;

    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();

    var opt_size: u8 = 4;
    var opt_wzo2: []const u8 = "";
    var opt_wzo1: ?[]const u8 = null;
    var opt_tables: std.ArrayListUnmanaged([]const u8) = .empty;
    defer opt_tables.deinit(gpa);
    var opt_sample: ?usize = null;
    var opt_seed: u64 = 42;
    var opt_json: []const u8 = "";
    var opt_controls_only: bool = false;
    var opt_seedctl_mode: SeedCtlMode = .none;
    var opt_seedctl_weaken_every: usize = 3;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--size")) {
            opt_size = try std.fmt.parseInt(u8, args.next() orelse return error.MissingArgument, 10);
        } else if (std.mem.eql(u8, arg, "--wzo2")) {
            opt_wzo2 = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--wzo1")) {
            opt_wzo1 = args.next();
        } else if (std.mem.eql(u8, arg, "--tables")) {
            const v = args.next() orelse return error.MissingArgument;
            var it = std.mem.splitScalar(u8, v, ',');
            while (it.next()) |t| {
                const trimmed = std.mem.trim(u8, t, " ");
                if (trimmed.len > 0) try opt_tables.append(gpa, trimmed);
            }
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
            if (std.mem.startsWith(u8, v, "weakened,")) {
                opt_seedctl_mode = .weakened;
                opt_seedctl_weaken_every = try std.fmt.parseInt(usize, v["weakened,".len..], 10);
            } else if (std.mem.startsWith(u8, v, "h2h_seeded,")) {
                opt_seedctl_mode = .h2h_seeded;
                opt_seedctl_weaken_every = try std.fmt.parseInt(usize, v["h2h_seeded,".len..], 10);
            } else if (std.mem.eql(u8, v, "null_sym")) {
                opt_seedctl_mode = .null_sym;
            } else {
                std.debug.print("unknown --seedctl mode: {s}\n", .{v});
                return error.InvalidArgument;
            }
        } else {
            std.debug.print("unknown flag: {s}\n", .{arg});
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
    if (opt_wzo1 == null) {
        opt_wzo1 = switch (size) {
            3 => "artifacts/oracle-3x3.wzo",
            4 => "data/oracle-4x4.checkpoint.wzo",
            else => return error.InvalidSize,
        };
    }
    if (opt_json.len == 0) {
        opt_json = switch (size) {
            3 => "/tmp/weizigo/t407-3x3-data.json",
            4 => "/tmp/weizigo/t407-4x4-data.json",
            else => return error.InvalidSize,
        };
    }
    // default historical tables
    if (opt_tables.items.len == 0) {
        switch (size) {
            3 => {
                try opt_tables.append(gpa, "artifacts/oracle-3x3.wzo");
            },
            4 => {
                try opt_tables.append(gpa, "data/oracle-4x4.checkpoint.wzo");
                try opt_tables.append(gpa, "data/oracle-4x4-basicko-tie-area.wzo");
                try opt_tables.append(gpa, "data/oracle-4x4-parallel.checkpoint.wzo");
            },
            else => {},
        }
    }

    switch (size) {
        3 => try runMatrix(3, 3, io, gpa, opt_wzo2, opt_wzo1.?, opt_tables.items, opt_sample, opt_seed, opt_json, opt_controls_only, opt_seedctl_mode, opt_seedctl_weaken_every),
        4 => try runMatrix(4, 4, io, gpa, opt_wzo2, opt_wzo1.?, opt_tables.items, opt_sample, opt_seed, opt_json, opt_controls_only, opt_seedctl_mode, opt_seedctl_weaken_every),
        else => return error.InvalidSize,
    }
}