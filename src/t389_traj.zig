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
// Task: T389 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-06
//
// T389_TRAJ — per-ply trajectory consistency in new-engine self-play.
//
// The property that makes an answer key an answer key (operator's framing,
// 2026-08-05): along a self-play trajectory, the table's stored bracket
// [L,H] at every node (for the side to move, at the node's own (ko, passes)
// key) must contain the final score of the game. A final score outside an
// earlier bracket is a contradiction: the table is wrong, the move selector
// is wrong, or the key is wrong.
//
// Measures:
//   - mode selfplay (default): the new engine (WZO2, oracle-4x4-v2.wzo2)
//     plays itself from T366's corpus openings (3 canonical one-ply + 30
//     seeded random two-ply, seed 42) x both T366 colour assignments (for
//     self-play the two assignments coincide — the pair is a determinism
//     replicate) plus the empty-goban game. The bracket is recorded at
//     EVERY ply and checked against the final score.
//   - mode replay: replays the committed T366/T375 corpus (132 games in
//     findings/T366-engine-kifu.json) and runs the same per-ply check on
//     the corpus trajectories, so the two measurements share a corpus.
//   - seeded control: --inject-* forces a deliberately suboptimal move for
//     one side at one decision point (the exact semantics of the committed
//     src/seedctl.zig injection) and shows the checker catches the resulting
//     bracket escape at the right ply, naming the right side.
//
// Reads ONLY. Compiles standalone; build.zig and engine sources untouched:
//   zig build-exe -O ReleaseFast --dep version -Mroot=src/t389_traj.zig \
//     -Mversion=src/version.zig --cache-dir /tmp/weizigo/t389/cache \
//     --global-cache-dir /tmp/weizigo/t389/global --name weizigo-t389-traj \
//     -femit-bin=/tmp/weizigo/t389/t389-traj
//
// Usage: weizigo-t389-traj [--mode selfplay|replay] [--artifact <wzo2>]
//         [--openings <N>] [--seed <N>] [--json <path>]
//         [--corpus <t366-kifu.json>]
//         [--inject-opening <oi>] [--inject-ply <moves-idx>]
//         [--inject-cell <vertex|pass>] [--inject-side B|W]
//         [--no-empty]

const std = @import("std");
const version = @import("version");
const rules = @import("rules.zig");
const artifact2 = @import("artifact2.zig");
const gtp = @import("gtp.zig");
const colex = @import("colex.zig");

const PLY_CAP = 400;
const W: usize = 4;
const H: usize = 4;
const R = rules.Rules(W, H);
const X = colex.Indexer(W, H);
const S = gtp.Session(W, H);
const KO_NONE: u8 = W * H; // gtp.Session KO_NONE == n

const DEFAULT_ARTIFACT = "data/oracle-4x4-v2.wzo2";
const DEFAULT_JSON = "findings/T389-trajectory-consistency.json";
const DEFAULT_CORPUS = "findings/T366-engine-kifu.json";

// ---------------------------------------------------------------------------
// Cause taxonomy (brief §"Why a played-out result can differ from a stored
// value at all — the four candidate causes"):
//   1 key_mismatch          — the move selector consulted the table with a
//                             different key than the table was built on
//   2 indeterminate_bracket — L < H, interval semantics; escape from the
//                             interval at an L<H node
//   3 ruleset_mismatch      — the game left the graph the table describes
//   4 genuine_defect        — the table or the move selector contradicts
// ---------------------------------------------------------------------------
const Cause = enum(u8) {
    key_mismatch = 1,
    indeterminate_bracket = 2,
    ruleset_mismatch = 3,
    genuine_defect = 4,
};

fn causeName(c: Cause) []const u8 {
    return switch (c) {
        .key_mismatch => "key_mismatch",
        .indeterminate_bracket => "indeterminate_bracket",
        .ruleset_mismatch => "ruleset_mismatch",
        .genuine_defect => "genuine_defect",
    };
}

// ---------------------------------------------------------------------------
// Small JSON writer (hand-rolled; deterministic key order) — verbatim from
// t366_evse.zig.
// ---------------------------------------------------------------------------
const Json = struct {
    buf: std.ArrayList(u8),
    gpa: std.mem.Allocator,

    fn init(gpa: std.mem.Allocator) Json {
        return .{ .buf = std.ArrayList(u8).empty, .gpa = gpa };
    }
    fn deinit(j: *Json) void {
        j.buf.deinit(j.gpa);
    }
    fn raw(j: *Json, s: []const u8) !void {
        try j.buf.appendSlice(j.gpa, s);
    }
    fn str(j: *Json, s: []const u8) !void {
        try j.buf.append(j.gpa, '"');
        for (s) |ch| {
            switch (ch) {
                '"' => try j.buf.appendSlice(j.gpa, "\\\""),
                '\\' => try j.buf.appendSlice(j.gpa, "\\\\"),
                '\n' => try j.buf.appendSlice(j.gpa, "\\n"),
                '\r' => try j.buf.appendSlice(j.gpa, "\\r"),
                '\t' => try j.buf.appendSlice(j.gpa, "\\t"),
                else => {
                    if (ch < 0x20) {
                        try j.buf.print(j.gpa, "\\u{x:0>4}", .{ch});
                    } else {
                        try j.buf.append(j.gpa, ch);
                    }
                },
            }
        }
        try j.buf.append(j.gpa, '"');
    }
    fn num(j: *Json, n: i64) !void {
        try j.buf.print(j.gpa, "{d}", .{n});
    }
    fn boole(j: *Json, b: bool) !void {
        try j.buf.appendSlice(j.gpa, if (b) "true" else "false");
    }
};

fn fmtResult(score: i8, buf: []u8) []const u8 {
    if (score > 0) return std.fmt.bufPrint(buf, "B+{d}", .{score}) catch unreachable;
    if (score < 0) return std.fmt.bufPrint(buf, "W+{d}", .{-score}) catch unreachable;
    return "0";
}

/// Vertex name for a cell (row-major), GTP/SGF 'a'-based.
fn vertex(cell: usize, buf: *[4]u8) []const u8 {
    const col: u8 = @intCast('a' + cell % W);
    const row: u8 = @intCast('a' + cell / W);
    buf[0] = col;
    buf[1] = row;
    return buf[0..2];
}

/// Inverse of vertex(): SGF-style "ab" -> cell. null when malformed.
fn cellFromVertex(token: []const u8) ?usize {
    if (token.len != 2) return null;
    if (token[0] < 'a' or token[0] >= 'a' + W) return null;
    if (token[1] < 'a' or token[1] >= 'a' + H) return null;
    const col: usize = token[0] - 'a';
    const row: usize = token[1] - 'a';
    return row * W + col;
}

/// Compact 4x4 board rendering for violation witnesses: '.' empty, 'B'/'W'.
fn boardString(pos: *const R.Pos, buf: *[16]u8) []const u8 {
    for (0..R.n) |i| {
        buf[i] = switch (pos[i]) {
            1 => 'B',
            -1 => 'W',
            else => '.',
        };
    }
    return buf[0..R.n];
}

// ---------------------------------------------------------------------------
// Opening generation — verbatim from t366_evse.zig (the corpus is reused so
// the measurements are comparable).
// ---------------------------------------------------------------------------
const Opening = struct {
    name: []const u8, // owned by the caller's name arena
    moves: [2]u8, // cell+1; 0 = unused (canonical openings are 1 ply)
    len: u8,
};

const OpeningList = struct {
    items: std.ArrayListUnmanaged(Opening) = .empty,
    names: std.ArrayListUnmanaged(u8) = .empty, // packed name arena
    gpa: std.mem.Allocator,

    fn add(o: *OpeningList, name: []const u8, moves: []const u8) !void {
        var op = Opening{ .name = undefined, .moves = .{ 0, 0 }, .len = 0 };
        for (moves, 0..) |m, i| {
            op.moves[i] = m;
        }
        op.len = @intCast(moves.len);
        const name_start = o.names.items.len;
        try o.names.appendSlice(o.gpa, name);
        try o.names.append(o.gpa, 0);
        op.name = o.names.items[name_start .. o.names.items.len - 1];
        try o.items.append(o.gpa, op);
    }
};

fn buildOpenings(gpa: std.mem.Allocator, count: usize, seed: u64, canonical: bool) !OpeningList {
    var list = OpeningList{ .gpa = gpa };
    if (canonical) {
        try list.add("canonical-corner-A1", &.{1}); // cell 0
        try list.add("canonical-edge-B1", &.{2}); // cell 1
        try list.add("canonical-centre-B2", &.{6}); // cell 5
    }
    var prng = std.Random.DefaultPrng.init(seed);
    const rnd = prng.random();
    var seen = [_]bool{false} ** 256; // b*16 + w signatures
    var added: usize = 0;
    var guard: usize = 0;
    while (added < count and guard < count * 20) : (guard += 1) {
        const b = rnd.uintLessThan(usize, R.n);
        var w: usize = undefined;
        while (true) {
            w = rnd.uintLessThan(usize, R.n);
            if (w != b) break;
        }
        const sig = b * R.n + w;
        if (seen[sig]) continue; // dedupe
        seen[sig] = true;
        var nmbuf: [64]u8 = undefined;
        var vb: [4]u8 = undefined;
        var vw: [4]u8 = undefined;
        const name = std.fmt.bufPrint(&nmbuf, "random-{d:0>3}-{s}{s}", .{ added, vertex(b, &vb), vertex(w, &vw) }) catch unreachable;
        try list.add(name, &.{ @intCast(b + 1), @intCast(w + 1) });
        added += 1;
    }
    return list;
}
// ---------------------------------------------------------------------------
// The checker core.
// ---------------------------------------------------------------------------

/// The table's bracket at one trajectory node (state BEFORE the ply's move).
const NodeRec = struct {
    ply: usize, // moves-array index (opening plies included)
    side: i8, // side to move
    ko_point: u8,
    passes: u8,
    L: i8,
    H: i8,
    DTT: u8,
    in_table: bool, // the (colex, side, ko, passes) key is present in the artifact
};

/// One invariant violation: final score escaped [L,H] at this node.
const Violation = struct {
    ply: usize,
    side: i8,
    ko_point: u8,
    passes: u8,
    L: i8,
    H: i8,
    final_score: i8,
    direction: u8, // 0 = below L, 1 = above H
    cause: Cause,
    in_table: bool,
    old_decision: bool, // corpus replay: ply was an old-engine decision point
    forced_ply: bool, // the move AT this ply was a forced (corpus) opening move
    alt_key_hit: u8, // 0 none, 1 (ko=NONE,passes=0), 2 (node ko, passes=0), 3 (ko=NONE, node passes)
    board: [16]u8,
};

const GameRec = struct {
    game_id: []const u8 = "",
    opening: []const u8 = "",
    opening_len: usize = 0, // forced opening plies in the moves array
    assignment: i8 = 1, // selfplay: +1/-1 replicate slot; replay: corpus old_colour
    moves: std.ArrayListUnmanaged(u8) = .empty, // cell+1, 0 = pass (incl. opening plies)
    plies: usize = 0, // nodes examined (= moves played before the terminal break)
    final_score: i8 = 0,
    capped: bool = false,
    injected: bool = false, // selfplay: an injection fired in this game
    illegal_move_ply: ?usize = null, // replay: first ply that was illegal under basic ko
    misses: usize = 0, // nodes whose key was not in the artifact
    root_L: i8 = 0,
    root_H: i8 = 0,
    root_in_table: bool = false,
    violations: std.ArrayListUnmanaged(Violation) = .empty,
    new_decision_violations: usize = 0,
    old_decision_violations: usize = 0,
    forced_ply_violations: usize = 0,
    engine_ply_violations: usize = 0,
    trace: std.ArrayListUnmanaged(NodeRec) = .empty, // full per-ply bracket trace (violated games only)
};

/// Look up the table's bracket for the current session state, or fall back to
/// the area score (mirroring gtp.bounds2's miss behaviour) with in_table=false.
fn recordNode(a2: *const artifact2.LoadedArtifact, s: *const S, ply: usize, side: i8) NodeRec {
    const colex_val: u32 = @intCast(X.colex_from_pos(&s.pos));
    if (s.passes >= 2) {
        const area = R.area_score(&s.pos);
        return .{ .ply = ply, .side = side, .ko_point = s.ko_point, .passes = s.passes, .L = area, .H = area, .DTT = 0, .in_table = false };
    }
    if (artifact2.lookup(a2, colex_val, side, s.ko_point, @intCast(s.passes))) |row| {
        return .{ .ply = ply, .side = side, .ko_point = s.ko_point, .passes = s.passes, .L = row.L, .H = row.H, .DTT = row.DTT, .in_table = true };
    }
    const area = R.area_score(&s.pos);
    return .{ .ply = ply, .side = side, .ko_point = s.ko_point, .passes = s.passes, .L = area, .H = area, .DTT = 0, .in_table = false };
}

/// Probe the same position under alternate (ko, passes) keys. Returns
/// 1 = (KO_NONE, 0), 2 = (node ko, 0), 3 = (KO_NONE, node passes) — the first
/// alternate key whose bracket contains `final` — or 0 when none does.
fn probeAlternateKeys(a2: *const artifact2.LoadedArtifact, nr: *const NodeRec, s: *const S, final: i8) u8 {
    const colex_val: u32 = @intCast(X.colex_from_pos(&s.pos));
    var probes: [3]struct { ko: u8, passes: u8 } = undefined;
    var n_probes: usize = 0;
    // (KO_NONE, 0)
    if (nr.ko_point != KO_NONE or nr.passes != 0) {
        probes[n_probes] = .{ .ko = KO_NONE, .passes = 0 };
        n_probes += 1;
    }
    // (node ko, 0)
    if (nr.passes != 0) {
        probes[n_probes] = .{ .ko = nr.ko_point, .passes = 0 };
        n_probes += 1;
    }
    // (KO_NONE, node passes)
    if (nr.ko_point != KO_NONE) {
        probes[n_probes] = .{ .ko = KO_NONE, .passes = nr.passes };
        n_probes += 1;
    }
    for (probes[0..n_probes], 0..) |p, i| {
        if (artifact2.lookup(a2, colex_val, nr.side, p.ko, @intCast(p.passes))) |row| {
            if (final >= row.L and final <= row.H) return @intCast(i + 1);
        }
    }
    return 0;
}

/// Classify a violation into exactly one of the four causes.
///   illegal_before: the game had already left the graph (replay illegal move)
///   final: the game's final score
///   culprit_new: the escape is attributable to the NEW engine's own play
///     (below_L & Black is the new engine, or above_H & White is the new
///     engine; in self-play both sides are the new engine).
///   direction: 0 = final < L (Black's guarantee failed — Black played
///     suboptimally at/after this node), 1 = final > H (White's enforcement
///     failed — White played suboptimally at/after this node).
/// Key mismatch is asserted only when the NEW engine's own play escaped an
/// L==H bracket AND an alternate (ko, passes) key's bracket contains the
/// final — the value is a function of the key and the used key's value
/// contradicts the line. An escape caused by the OLD engine's suboptimality
/// (corpus replay) is not a key-mismatch witness even when an alternate key
/// fits: the alt-key hit is recorded on every violation as data (it tests
/// the operator's ko/pass-key hypothesis), but by itself it does not name a
/// defect.
fn classifyViolation(
    a2: *const artifact2.LoadedArtifact,
    nr: *const NodeRec,
    s: *const S,
    final: i8,
    illegal_before: bool,
    culprit_new: bool,
) struct { cause: Cause, alt: u8 } {
    if (illegal_before) return .{ .cause = .ruleset_mismatch, .alt = 0 };
    if (!nr.in_table) return .{ .cause = .key_mismatch, .alt = 0 };
    if (nr.L != nr.H) return .{ .cause = .indeterminate_bracket, .alt = 0 };
    const alt = probeAlternateKeys(a2, nr, s, final);
    if (alt != 0 and culprit_new)
        return .{ .cause = .key_mismatch, .alt = alt };
    return .{ .cause = .genuine_defect, .alt = alt };
}

/// After a game ends, check the invariant at every recorded node.
fn checkInvariant(
    gpa: std.mem.Allocator,
    a2: *const artifact2.LoadedArtifact,
    nodes: []const NodeRec,
    s_at_node: []const S, // session state at each node (for alternate-key probes)
    final: i8,
    illegal_before: bool,
    old_decision_mask: ?[]const bool, // per-ply old-decision mask (corpus replay); null for selfplay
    forced_mask: ?[]const bool, // per-ply forced-opening-move mask; null when none forced
    black_is_new: bool, // is Black the new engine? (selfplay: true; corpus: old_colour == W)
    rec: *GameRec,
) !void {
    for (nodes, 0..) |nr, i| {
        if (final < nr.L or final > nr.H) {
            const is_old = if (old_decision_mask) |m| m[i] else false;
            const is_forced = if (forced_mask) |m| m[i] else false;
            const dir: u8 = if (final < nr.L) 0 else 1;
            const culprit_new = if (dir == 0) black_is_new else !black_is_new;
            const cls = classifyViolation(a2, &nr, &s_at_node[i], final, illegal_before, culprit_new);
            var v = Violation{
                .ply = nr.ply,
                .side = nr.side,
                .ko_point = nr.ko_point,
                .passes = nr.passes,
                .L = nr.L,
                .H = nr.H,
                .final_score = final,
                .direction = dir,
                .cause = cls.cause,
                .in_table = nr.in_table,
                .old_decision = is_old,
                .forced_ply = is_forced,
                .alt_key_hit = cls.alt,
                .board = undefined,
            };
            const b = boardString(&s_at_node[i].pos, &v.board);
            _ = b;
            std.debug.print("  [t389] VIOLATION game={s} ply={d} side={s} ko={s} passes={d} bracket=[{d},{d}] final={d} direction={s} cause={s}\n", .{
                rec.game_id,
                nr.ply,
                if (nr.side > 0) "B" else "W",
                if (nr.ko_point != KO_NONE) "yes" else "no",
                nr.passes,
                nr.L,
                nr.H,
                final,
                if (final < nr.L) "below_L" else "above_H",
                causeName(cls.cause),
            });
            try rec.violations.append(gpa, v);
            if (is_old) rec.old_decision_violations += 1 else rec.new_decision_violations += 1;
            if (is_forced) rec.forced_ply_violations += 1 else rec.engine_ply_violations += 1;
        }
    }
}

// ---------------------------------------------------------------------------
// Mode 1: self-play, new engine vs itself.
// ---------------------------------------------------------------------------
const Inject = struct {
    opening_idx: usize,
    ply: usize, // moves-array index (opening plies included)
    side: i8,
    pass: bool,
    cell: usize = 0,
};

fn playSelfGame(
    gpa: std.mem.Allocator,
    a2: *const artifact2.LoadedArtifact,
    opening: *const Opening,
    inject: ?*const Inject,
    rec: *GameRec,
) !void {
    var s = S{ .d = null, .a2 = a2, .enforcement = .basic_ko };
    s.reset();

    var side: i8 = 1;
    var nodes = std.ArrayListUnmanaged(NodeRec).empty;
    defer nodes.deinit(gpa);
    var s_at = std.ArrayListUnmanaged(S).empty;
    defer s_at.deinit(gpa);

    // Record and play the forced opening plies as part of the trajectory:
    // the node BEFORE every move (including the empty-board root at ply 0)
    // carries a bracket that must contain the final score.
    var ply: usize = 0;
    while (ply < opening.len) : (ply += 1) {
        if (s.passes >= 2) break;
        const nr = recordNode(a2, &s, ply, side);
        if (!nr.in_table) rec.misses += 1;
        try nodes.append(gpa, nr);
        try s_at.append(gpa, s);

        const m = opening.moves[ply];
        try rec.moves.append(gpa, m);
        s.applyMove(side, if (m == 0) null else m - 1) catch unreachable;
        side = -side;
    }

    // Decision plies: the new engine plays itself.
    var dply: usize = 0;
    while (dply < PLY_CAP) : (dply += 1) {
        if (s.passes >= 2) break;
        const nr = recordNode(a2, &s, opening.len + dply, side);
        if (!nr.in_table) rec.misses += 1;
        try nodes.append(gpa, nr);
        try s_at.append(gpa, s);

        var c = s.choose(side);
        if (inject) |inj| {
            if (opening.len + dply == inj.ply and side == inj.side) {
                c.cell = if (inj.pass) null else inj.cell;
                rec.injected = true;
                std.debug.print("  [t389] INJECTED at moves-index {d} ({s} to move): {s} forced to {s}\n", .{
                    opening.len + dply,
                    if (side > 0) "B" else "W",
                    if (side > 0) "B" else "W",
                    if (inj.pass) "pass" else blk: {
                        var vb: [4]u8 = undefined;
                        break :blk vertex(inj.cell, &vb);
                    },
                });
            }
        }
        try rec.moves.append(gpa, if (c.cell) |cl| @intCast(cl + 1) else 0);
        s.applyMove(side, c.cell) catch unreachable;
        side = -side;
    }

    rec.plies = nodes.items.len;
    rec.capped = dply >= PLY_CAP;
    rec.final_score = R.area_score(&s.pos);
    if (nodes.items.len > 0) {
        rec.root_L = nodes.items[0].L;
        rec.root_H = nodes.items[0].H;
        rec.root_in_table = nodes.items[0].in_table;
    }
    // forced mask: the move AT nodes[i].ply is an opening (forced) ply iff
    // nodes[i].ply < opening.len
    var forced = try gpa.alloc(bool, nodes.items.len);
    defer gpa.free(forced);
    for (nodes.items, 0..) |nr, i| {
        forced[i] = nr.ply < opening.len;
    }
    try checkInvariant(gpa, a2, nodes.items, s_at.items, rec.final_score, false, null, forced, true, rec);
    if (rec.violations.items.len > 0) {
        try rec.trace.appendSlice(gpa, nodes.items);
    }
}

// ---------------------------------------------------------------------------
// Mode 2: replay the committed T366/T375 corpus trajectories.
// ---------------------------------------------------------------------------
fn replayCorpusGame(
    gpa: std.mem.Allocator,
    a2: *const artifact2.LoadedArtifact,
    old_colour: i8,
    moves: []const []const u8,
    rec: *GameRec,
) !void {
    var s = S{ .d = null, .a2 = a2, .enforcement = .basic_ko };
    s.reset();

    var side: i8 = 1;
    var ply: usize = 0;
    var nodes = std.ArrayListUnmanaged(NodeRec).empty;
    defer nodes.deinit(gpa);
    var s_at = std.ArrayListUnmanaged(S).empty;
    defer s_at.deinit(gpa);
    var illegal_before = false;

    while (ply < moves.len and s.passes < 2 and ply < PLY_CAP) : (ply += 1) {
        const nr = recordNode(a2, &s, ply, side);
        if (!nr.in_table) rec.misses += 1;
        try nodes.append(gpa, nr);
        try s_at.append(gpa, s);

        const mv = moves[ply];
        const cell: ?usize = if (std.mem.eql(u8, mv, "pass")) null else cellFromVertex(mv) orelse {
            rec.illegal_move_ply = ply;
            illegal_before = true;
            break;
        };
        s.applyMove(side, cell) catch {
            rec.illegal_move_ply = ply;
            illegal_before = true;
            break;
        };
        try rec.moves.append(gpa, if (cell) |cl| @intCast(cl + 1) else 0);
        side = -side;
    }

    rec.plies = nodes.items.len;
    rec.capped = ply >= PLY_CAP;
    rec.final_score = R.area_score(&s.pos);
    if (nodes.items.len > 0) {
        rec.root_L = nodes.items[0].L;
        rec.root_H = nodes.items[0].H;
        rec.root_in_table = nodes.items[0].in_table;
    }
    // old_decision mask: at ply i the side to move is Black for even i; the
    // old engine decided when that side == old_colour.
    var mask = try gpa.alloc(bool, nodes.items.len);
    defer gpa.free(mask);
    for (nodes.items, 0..) |nr, i| {
        _ = nr;
        const stm: i8 = if (@mod(i, 2) == 0) 1 else -1;
        mask[i] = stm == old_colour;
    }
    // forced mask: opening plies (first `opening_len` moves) were forced in
    // the corpus.
    var forced = try gpa.alloc(bool, nodes.items.len);
    defer gpa.free(forced);
    for (nodes.items, 0..) |nr, i| {
        forced[i] = nr.ply < rec.opening_len;
    }
    // black_is_new: Black is the new engine iff the old engine was White.
    const black_is_new = old_colour < 0;
    try checkInvariant(gpa, a2, nodes.items, s_at.items, rec.final_score, illegal_before, mask, forced, black_is_new, rec);
    if (rec.violations.items.len > 0) {
        try rec.trace.appendSlice(gpa, nodes.items);
    }
}

// ---------------------------------------------------------------------------
// Section summary + JSON emission.
// ---------------------------------------------------------------------------
fn emitViolationJson(j: *Json, v: *const Violation) !void {
    try j.raw("{\"ply\":");
    try j.num(@intCast(v.ply));
    try j.raw(",\"side\":");
    try j.str(if (v.side > 0) "B" else "W");
    try j.raw(",\"ko_pending\":");
    try j.boole(v.ko_point != KO_NONE);
    if (v.ko_point != KO_NONE) {
        try j.raw(",\"ko_cell\":");
        var vb: [4]u8 = undefined;
        try j.str(vertex(v.ko_point, &vb));
    }
    try j.raw(",\"passes\":");
    try j.num(v.passes);
    try j.raw(",\"L\":");
    try j.num(v.L);
    try j.raw(",\"H\":");
    try j.num(v.H);
    try j.raw(",\"width\":");
    try j.num(v.H - v.L);
    try j.raw(",\"final_score\":");
    try j.num(v.final_score);
    try j.raw(",\"direction\":");
    try j.str(if (v.direction == 0) "below_L" else "above_H");
    try j.raw(",\"cause\":");
    try j.str(causeName(v.cause));
    try j.raw(",\"in_table\":");
    try j.boole(v.in_table);
    try j.raw(",\"old_decision\":");
    try j.boole(v.old_decision);
    try j.raw(",\"forced_ply\":");
    try j.boole(v.forced_ply);
    try j.raw(",\"alt_key_hit\":");
    try j.num(v.alt_key_hit);
    try j.raw(",\"board\":");
    try j.str(&v.board);
    try j.raw("}");
}

fn emitSectionJson(
    j: *Json,
    section_name: []const u8,
    games: []const GameRec,
    extra: []const u8, // raw JSON object (e.g. inject spec) injected after "name"
) !void {
    var plies: u64 = 0;
    var violations: u64 = 0;
    var misses: u64 = 0;
    var capped: u64 = 0;
    var illegal: u64 = 0;
    var below_l: u64 = 0;
    var above_h: u64 = 0;
    var c1: u64 = 0;
    var c2: u64 = 0;
    var c3: u64 = 0;
    var c4: u64 = 0;
    var old_dec_v: u64 = 0;
    var new_dec_v: u64 = 0;
    var l_eq_h_v: u64 = 0;
    var l_lt_h_v: u64 = 0;
    var forced_v: u64 = 0;
    var engine_v: u64 = 0;
    for (games) |g| {
        plies += g.plies;
        misses += g.misses;
        if (g.capped) capped += 1;
        if (g.illegal_move_ply != null) illegal += 1;
        forced_v += g.forced_ply_violations;
        engine_v += g.engine_ply_violations;
        for (g.violations.items) |v| {
            violations += 1;
            if (v.direction == 0) below_l += 1 else above_h += 1;
            switch (v.cause) {
                .key_mismatch => c1 += 1,
                .indeterminate_bracket => c2 += 1,
                .ruleset_mismatch => c3 += 1,
                .genuine_defect => c4 += 1,
            }
            if (v.L == v.H) l_eq_h_v += 1 else l_lt_h_v += 1;
            if (v.old_decision) old_dec_v += 1 else new_dec_v += 1;
        }
    }

    try j.raw("{\"name\":");
    try j.str(section_name);
    if (extra.len > 0) {
        try j.raw(",\n");
        try j.raw(extra);
    }
    try j.raw(",\n\"games\":");
    try j.num(@intCast(games.len));
    try j.raw(",\n\"plies\":");
    try j.num(@intCast(plies));
    try j.raw(",\n\"violations\":");
    try j.num(@intCast(violations));
    try j.raw(",\n\"lookup_misses\":");
    try j.num(@intCast(misses));
    try j.raw(",\n\"capped_games\":");
    try j.num(@intCast(capped - illegal));
    try j.raw(",\n\"illegal_moves\":");
    try j.num(@intCast(illegal));
    try j.raw(",\n\"by_direction\":{\"below_L\":");
    try j.num(@intCast(below_l));
    try j.raw(",\"above_H\":");
    try j.num(@intCast(above_h));
    try j.raw("},\n\"by_cause\":{\"key_mismatch\":");
    try j.num(@intCast(c1));
    try j.raw(",\"indeterminate_bracket\":");
    try j.num(@intCast(c2));
    try j.raw(",\"ruleset_mismatch\":");
    try j.num(@intCast(c3));
    try j.raw(",\"genuine_defect\":");
    try j.num(@intCast(c4));
    try j.raw("},\n\"by_bracket\":{\"L_eq_H\":");
    try j.num(@intCast(l_eq_h_v));
    try j.raw(",\"L_lt_H\":");
    try j.num(@intCast(l_lt_h_v));
    try j.raw("},\n\"by_decision\":{\"old_engine_plies\":");
    try j.num(@intCast(old_dec_v));
    try j.raw(",\"new_engine_plies\":");
    try j.num(@intCast(new_dec_v));
    try j.raw("},\n\"by_origin\":{\"forced_opening_plies\":");
    try j.num(@intCast(forced_v));
    try j.raw(",\"engine_decision_plies\":");
    try j.num(@intCast(engine_v));
    try j.raw("},\n\"games\":[");
    for (games, 0..) |g, i| {
        if (i > 0) try j.raw(",");
        try j.raw("{\"game_id\":");
        try j.str(g.game_id);
        try j.raw(",\"opening\":");
        try j.str(g.opening);
        try j.raw(",\"assignment\":");
        try j.str(if (g.assignment > 0) "A" else "B");
        try j.raw(",\"plies\":");
        try j.num(@intCast(g.plies));
        try j.raw(",\"final_score\":");
        try j.num(g.final_score);
        try j.raw(",\"capped\":");
        try j.boole(g.capped);
        try j.raw(",\"injected\":");
        try j.boole(g.injected);
        try j.raw(",\"root_L\":");
        try j.num(g.root_L);
        try j.raw(",\"root_H\":");
        try j.num(g.root_H);
        try j.raw(",\"root_in_table\":");
        try j.boole(g.root_in_table);
        try j.raw(",\"moves\":[");
        for (g.moves.items, 0..) |m, pi| {
            if (pi > 0) try j.raw(",");
            var vb: [4]u8 = undefined;
            if (m == 0) {
                try j.str("pass");
            } else {
                try j.str(vertex(m - 1, &vb));
            }
        }
        try j.raw("],\n\"violations\":[");
        for (g.violations.items, 0..) |*v, vi| {
            if (vi > 0) try j.raw(",");
            try emitViolationJson(j, v);
        }
        try j.raw("]");
        if (g.violations.items.len > 0) {
            try j.raw(",\n\"bracket_trace\":[");
            for (g.trace.items, 0..) |*nr, ti| {
                if (ti > 0) try j.raw(",");
                try j.raw("[");
                try j.num(@intCast(nr.ply));
                try j.raw(",");
                try j.str(if (nr.side > 0) "B" else "W");
                try j.raw(",");
                try j.boole(nr.ko_point != KO_NONE);
                try j.raw(",");
                try j.num(nr.passes);
                try j.raw(",");
                try j.num(nr.L);
                try j.raw(",");
                try j.num(nr.H);
                try j.raw(",");
                try j.boole(nr.in_table);
                try j.raw("]");
            }
            try j.raw("]");
        }
        try j.raw("}");
    }
    try j.raw("]}");
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------
pub fn main(init: std.process.Init) !void {
    std.debug.print("{s}\n", .{version.banner("weizigo-t389-traj")});
    const gpa = std.heap.page_allocator;
    const io = init.io;

    var mode: []const u8 = "selfplay";
    var artifact_path: []const u8 = DEFAULT_ARTIFACT;
    var json_path: []const u8 = DEFAULT_JSON;
    var corpus_path: []const u8 = DEFAULT_CORPUS;
    var openings_count: usize = 30;
    var seed: u64 = 42;
    var do_empty = true;

    var inj_opening: ?usize = null;
    var inj_ply: ?usize = null;
    var inj_side: ?i8 = null;
    var inj_cell: ?[]const u8 = null; // vertex name or "pass"

    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    while (args.next()) |a| {
        if (std.mem.eql(u8, a, "--mode")) mode = args.next() orelse "selfplay"
        else if (std.mem.eql(u8, a, "--artifact")) artifact_path = args.next() orelse DEFAULT_ARTIFACT
        else if (std.mem.eql(u8, a, "--json")) json_path = args.next() orelse DEFAULT_JSON
        else if (std.mem.eql(u8, a, "--corpus")) corpus_path = args.next() orelse DEFAULT_CORPUS
        else if (std.mem.eql(u8, a, "--openings")) openings_count = std.fmt.parseInt(usize, args.next() orelse "30", 10) catch 30
        else if (std.mem.eql(u8, a, "--seed")) seed = std.fmt.parseInt(u64, args.next() orelse "42", 10) catch 42
        else if (std.mem.eql(u8, a, "--no-empty")) do_empty = false
        else if (std.mem.eql(u8, a, "--inject-opening")) inj_opening = std.fmt.parseInt(usize, args.next() orelse "0", 10) catch 0
        else if (std.mem.eql(u8, a, "--inject-ply")) inj_ply = std.fmt.parseInt(usize, args.next() orelse "0", 10) catch 0
        else if (std.mem.eql(u8, a, "--inject-side")) inj_side = if (std.mem.eql(u8, args.next() orelse "B", "W")) -1 else 1
        else if (std.mem.eql(u8, a, "--inject-cell")) inj_cell = args.next()
        else {
            std.debug.print("unknown argument '{s}'\n", .{a});
            return;
        }
    }

    // Build the injection spec (seedctl semantics: force the move of one
    // side at one moves-array index to a pass or a cell).
    var inject: ?Inject = null;
    if (inj_ply != null or inj_opening != null or inj_cell != null or inj_side != null) {
        const cellname = inj_cell orelse "pass";
        var pass = false;
        var cell: usize = 0;
        if (std.mem.eql(u8, cellname, "pass")) {
            pass = true;
        } else {
            cell = cellFromVertex(cellname) orelse {
                std.debug.print("bad --inject-cell '{s}' (expect a vertex like 'aa' or 'pass')\n", .{cellname});
                return;
            };
        }
        inject = .{
            .opening_idx = inj_opening orelse 0,
            .ply = inj_ply orelse 0,
            .side = inj_side orelse -1,
            .pass = pass,
            .cell = cell,
        };
        std.debug.print("t389 injection: opening_idx={d} moves-index={d} side={s} cell={s}\n", .{
            inject.?.opening_idx, inject.?.ply, if (inject.?.side > 0) "B" else "W",
            if (inject.?.pass) "pass" else cellname,
        });
    }

    var a2 = artifact2.load(io, std.Io.Dir.cwd(), artifact_path, gpa) catch |err| {
        std.debug.print("error: cannot load artifact '{s}': {t}\n", .{ artifact_path, err });
        return;
    };
    defer a2.deinit();

    if (a2.header.w != W or a2.header.h != H) {
        std.debug.print("error: artifact must be {d}x{d} (is {d}x{d})\n", .{ W, H, a2.header.w, a2.header.h });
        return;
    }
    std.debug.print("artifact: {s} ({d}x{d}, {d} groups, {d} entries, ko_bits={d}, rules_id={d} {s})\n", .{
        artifact_path, a2.header.w, a2.header.h, a2.header.n_groups, a2.header.n_entries,
        a2.header.ko_bits, artifact2.RULES_BASICKO_LH_AREA, artifact2.rulesName(artifact2.RULES_BASICKO_LH_AREA),
    });

    const stamp = try std.fmt.allocPrint(gpa, "{s}", .{version.banner("weizigo-t389-traj")});
    defer gpa.free(stamp);

    var combined = Json.init(gpa);
    defer combined.deinit();
    try combined.raw("{\n\"task_id\":\"T389\",\n\"date\":\"2026-08-06\",\n\"model\":\"deepseek-v4-flash\",\n\"identifier\":\"deepseek-v4-flash/T389\",\n\"claims\":[],\n\"artifact\":");
    try combined.str(artifact_path);
    try combined.raw(",\n\"instrument_stamp\":");
    try combined.str(stamp);
    try combined.raw(",\n\"corpus\":");
    try combined.str(corpus_path);
    try combined.raw(",\n\"sections\":[");
    var section_count: usize = 0;

    const do_selfplay = std.mem.eql(u8, mode, "selfplay") or std.mem.eql(u8, mode, "both");
    const do_replay = std.mem.eql(u8, mode, "replay") or std.mem.eql(u8, mode, "both");

    if (do_selfplay) {
        var openings = try buildOpenings(gpa, openings_count, seed, true);
        defer openings.names.deinit(gpa);
        defer openings.items.deinit(gpa);
        std.debug.print("openings: {d} ({d} canonical + {d} random, seed {d})\n", .{
            openings.items.items.len, 3, openings_count, seed,
        });

        var games = std.ArrayListUnmanaged(GameRec).empty;
        defer {
            for (games.items) |*g| {
                g.moves.deinit(gpa);
                g.violations.deinit(gpa);
                g.trace.deinit(gpa);
            }
            games.deinit(gpa);
        }

        // 33 openings x 2 T366 colour assignments = 66 games; for self-play
        // the two assignments coincide (determinism replicate).
        for (openings.items.items, 0..) |*opening, oi| {
            for ([_]i8{ 1, -1 }) |assignment| {
                var rec = GameRec{};
                var idbuf: [64]u8 = undefined;
                const id = std.fmt.bufPrint(&idbuf, "sp-o{d:0>2}-{s}", .{
                    oi, if (assignment > 0) "A" else "B",
                }) catch unreachable;
                rec.game_id = gpa.dupe(u8, id) catch unreachable;
                rec.opening = opening.name;
                rec.opening_len = opening.len;
                rec.assignment = assignment;

                const inj_for_game: ?*const Inject = if (inject) |*inj| blk: {
                    if (oi == inj.opening_idx)
                        break :blk inj
                    else
                        break :blk null;
                } else null;

                try playSelfGame(gpa, &a2, opening, inj_for_game, &rec);
                try games.append(gpa, rec);

                var rbuf: [16]u8 = undefined;
                std.debug.print("  {s} {s:>26}: {s} plies={d} violations={d}\n", .{
                    rec.game_id, opening.name, fmtResult(rec.final_score, &rbuf),
                    rec.plies, rec.violations.items.len,
                });
            }
        }

        if (do_empty) {
            var rec = GameRec{};
            const empty = Opening{ .name = "empty", .moves = .{ 0, 0 }, .len = 0 };
            rec.game_id = gpa.dupe(u8, "sp-empty") catch unreachable;
            rec.opening = "empty";
            rec.opening_len = 0;
            rec.assignment = 1;
            try playSelfGame(gpa, &a2, &empty, null, &rec);
            try games.append(gpa, rec);
            var rbuf: [16]u8 = undefined;
            std.debug.print("  {s} {s:>26}: {s} plies={d} violations={d}\n", .{
                rec.game_id, "empty", fmtResult(rec.final_score, &rbuf), rec.plies, rec.violations.items.len,
            });
        }

        // determinism replicate check: for every opening, assignment A must
        // equal assignment B (same trajectory, same final score).
        var replicate_mismatches: usize = 0;
        for (games.items, 0..) |g, i| {
            if (g.opening.len == 0 or std.mem.eql(u8, g.opening, "empty")) continue;
            if (@mod(i, 2) == 1) {
                const a = games.items[i - 1];
                const b = g;
                if (a.final_score != b.final_score or a.plies != b.plies) replicate_mismatches += 1;
            }
        }
        std.debug.print("selfplay: {d} games, replicate mismatches (A vs B): {d}\n", .{ games.items.len, replicate_mismatches });

        var extra: std.ArrayList(u8) = .empty;
        defer extra.deinit(gpa);
        if (inject) |*inj| {
            try extra.appendSlice(gpa, "\"inject\":{\"opening_idx\":");
            try extra.print(gpa, "{d}", .{inj.opening_idx});
            try extra.appendSlice(gpa, ",\"ply\":");
            try extra.print(gpa, "{d}", .{inj.ply});
            try extra.appendSlice(gpa, ",\"side\":");
            try extra.appendSlice(gpa, if (inj.side > 0) "\"B\"" else "\"W\"");
            try extra.appendSlice(gpa, ",\"cell\":");
            if (inj.pass) {
                try extra.appendSlice(gpa, "\"pass\"");
            } else {
                var vb: [4]u8 = undefined;
                try extra.appendSlice(gpa, "\"");
                try extra.appendSlice(gpa, vertex(inj.cell, &vb));
                try extra.appendSlice(gpa, "\"");
            }
            try extra.appendSlice(gpa, "}");
        }
        if (section_count > 0) try combined.raw(",");
        try combined.raw("\n");
        try emitSectionJson(&combined, "selfplay", games.items, extra.items);
        section_count += 1;
    }
    if (do_replay) {
        const json = std.Io.Dir.cwd().readFileAlloc(io, corpus_path, gpa, .unlimited) catch |err| {
            std.debug.print("error: cannot read corpus '{s}': {t}\n", .{ corpus_path, err });
            return;
        };
        defer gpa.free(json);
        var parsed = std.json.parseFromSlice(std.json.Value, gpa, json, .{ .allocate = .alloc_always }) catch |err| {
            std.debug.print("error: corpus '{s}' is not valid JSON: {s}\n", .{ corpus_path, @errorName(err) });
            return;
        };
        defer parsed.deinit();

        var games = std.ArrayListUnmanaged(GameRec).empty;
        defer {
            for (games.items) |*g| {
                g.moves.deinit(gpa);
                g.violations.deinit(gpa);
                g.trace.deinit(gpa);
            }
            games.deinit(gpa);
        }

        const frames = parsed.value.object.get("frames") orelse {
            std.debug.print("error: corpus has no 'frames'\n", .{});
            return;
        };
        if (frames != .array) {
            std.debug.print("error: corpus 'frames' is not an array\n", .{});
            return;
        }
        for (frames.array.items) |frame_val| {
            if (frame_val != .object) continue;
            const frame_name = if (frame_val.object.get("frame")) |fv|
                (if (fv == .string) fv.string else "?")
            else
                "?";
            const games_val = frame_val.object.get("games") orelse continue;
            if (games_val != .array) continue;
            for (games_val.array.items) |gv| {
                if (gv != .object) continue;
                const gid = gv.object.get("game_id") orelse continue;
                const opening = gv.object.get("opening") orelse continue;
                const oc = gv.object.get("old_colour") orelse continue;
                const mv = gv.object.get("moves") orelse continue;
                if (gid != .string or opening != .string or oc != .string or mv != .array) continue;

                var rec = GameRec{};
                var idbuf: [128]u8 = undefined;
                const id = std.fmt.bufPrint(&idbuf, "{s}/{s}", .{ frame_name, gid.string }) catch unreachable;
                rec.game_id = gpa.dupe(u8, id) catch unreachable;
                rec.opening = gpa.dupe(u8, opening.string) catch unreachable;
                rec.opening_len = if (std.mem.startsWith(u8, opening.string, "random"))
                    2
                else if (std.mem.startsWith(u8, opening.string, "canonical"))
                    1
                else
                    0;
                rec.assignment = if (std.mem.eql(u8, oc.string, "W")) -1 else 1;

                // collect the move tokens
                const n_moves = mv.array.items.len;
                const move_tokens = try gpa.alloc([]const u8, n_moves);
                defer gpa.free(move_tokens);
                for (mv.array.items, 0..) |mvv, i| {
                    if (mvv != .string) {
                        move_tokens[i] = "?";
                    } else {
                        move_tokens[i] = gpa.dupe(u8, mvv.string) catch unreachable;
                    }
                }
                // free the dupes after the game
                defer {
                    for (move_tokens) |t| {
                        if (!std.mem.eql(u8, t, "?")) gpa.free(t);
                    }
                }
                try replayCorpusGame(gpa, &a2, rec.assignment, move_tokens, &rec);
                try games.append(gpa, rec);
                var rbuf: [16]u8 = undefined;
                std.debug.print("  {s}: {s} plies={d} violations={d}\n", .{
                    rec.game_id, fmtResult(rec.final_score, &rbuf), rec.plies, rec.violations.items.len,
                });
            }
        }
        std.debug.print("replay: {d} games from {s}\n", .{ games.items.len, corpus_path });

        if (section_count > 0) try combined.raw(",");
        try combined.raw("\n");
        var extra = Json.init(gpa);
        defer extra.deinit();
        try extra.raw("\"source\":");
        try extra.str(corpus_path);
        try emitSectionJson(&combined, "corpus-replay", games.items, extra.buf.items);
        section_count += 1;
    }
    if (!do_selfplay and !do_replay) {
        std.debug.print("unknown --mode '{s}' (expect selfplay|replay|both)\n", .{ mode });
        return;
    }

    try combined.raw("\n]}\n");

    var file = try std.Io.Dir.cwd().createFile(io, json_path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, combined.buf.items);
    std.debug.print("wrote {s} ({d} bytes)\n", .{ json_path, combined.buf.items.len });
}
