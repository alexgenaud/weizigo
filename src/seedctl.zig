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
// Task: T366 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-05
//
// T375_SEEDCTL — seeded-control harness: copy of src/t366_evse.zig (commit
// 19cd78b, instrument SHA 4e378353...) with one additive feature: an
// injection that forces the NEW engine's move at one decision point to a
// deliberately bad move (default: pass), to prove the mirrored classifier
// catches an injected bad move as a genuine_loss. All measurement code
// (runGame, substitution replays, arbiters, classifyGame/classifyMirror,
// JSON/SGF emission) is untouched.
//
// Usage: weizigo-t375-seedctl [--old <wzo>] [--new <wzo2>] [--frame a|b|both]
//         [--openings <N>] [--seed <N>] [--out <sgf-dir>] [--json <path>]
//         [--inject-frame fA|fB] [--inject-opening <oi>]
//         [--inject-colour B|W] [--inject-ply <moves-idx>]
//         [--inject-cell <vertex|pass>]
//
// Plays the WZO1-era 4x4 oracle (data/oracle-4x4.checkpoint.wzo, PSK-era
// fresh-start single values, no ko/passes dimension) against the current
// WZO2 oracle (data/oracle-4x4-v2.wzo2, basic-ko L/H bracket keyed on
// (goban, side, ko_point, passes)) and produces the divergence kifu:
//   - openings x both colour assignments, two legality frames:
//       frame a: shared PSK legality (both engines PSK-filtered moves)
//       frame b: the new engine's own ruleset (basic ko); the old engine
//                still filters by its own PSK rule
//   - first-divergence ply per game, both engines' chosen moves and stored
//     values at that node (old V0 vs new L/H bracket at the node's own
//     (ko, passes) key), ko-class of the node
//   - per game: substitution replay (the engine-vs-engine regression
//     semantics: the new engine's moves at the old engine's decision points,
//     original opponent moves replayed) and a new-engine self-play arbiter
//     from the same opening; classification genuine-loss / not-attributable
//     / equal-value / outcome-unknown
//   - SGF kifu per diverged game with the divergence ply marked
//
// Reads ONLY. Compiles standalone (like src/engine-vs-engine.zig); build.zig
// is not touched:
//   zig build-exe -O ReleaseFast -Mroot=src/t366_evse.zig \
//     --dep version -Mversion=src/version.zig \
//     --cache-dir /tmp/weizigo/t366/cache --global-cache-dir /tmp/weizigo/t366/global \
//     --name weizigo-t366-evse -femit-bin=/tmp/weizigo/t366/t366-evse
//
// Usage: weizigo-t366-evse [--old <wzo>] [--new <wzo2>] [--frame a|b|both]
//         [--openings <N>] [--seed <N>] [--out <sgf-dir>] [--json <path>]
//         [--no-canonical]

const std = @import("std");
const version = @import("version");
const rules = @import("rules.zig");
const artifact = @import("artifact.zig");
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

/// T375 seeded control: force the NEW engine's move at one decision point.
/// `ply` is the moves-array index (opening plies included), matching the
/// div_ply convention. `pass=true` forces a pass; otherwise `cell` (0-based).
const Inject = struct {
    frame: []const u8,
    opening_idx: usize,
    old_colour: i8,
    ply: usize,
    pass: bool,
    cell: usize = 0,
};

const DEFAULT_OLD = "data/oracle-4x4.checkpoint.wzo";
const DEFAULT_NEW = "data/oracle-4x4-v2.wzo2";
const DEFAULT_OUT = "docs/evidence/ENGINE-VS-ENGINE";
const DEFAULT_JSON = "findings/T366-engine-kifu.json";

fn pinnedValue(L: i8, Hv: i8) i8 {
    return @max(L, @min(0, Hv));
}

// ---------------------------------------------------------------------------
// Ko classification (inlined verbatim from engine-vs-engine.zig, itself
// inlined from B23/ko_census.zig): independent-ko-cluster count of a
// position, used to bucket divergence nodes like the existing tool does.
// ---------------------------------------------------------------------------
const KoPoint = struct { cell: u8, cap: u8 };

fn isKoCapture(pos: *const R.Pos, p: usize, colour: i8) ?usize {
    if (pos[p] != 0) return null;
    const next = R.pos_from_move(pos, colour, p) catch return null;

    var opp_before: u8 = 0;
    var opp_after: u8 = 0;
    var captured_cell: ?usize = null;
    for (0..R.n) |i| {
        if (pos[i] == -colour) opp_before += 1;
        if (next[i] == -colour) opp_after += 1;
        if (pos[i] == -colour and next[i] == 0) captured_cell = i;
    }
    if (opp_before - opp_after != 1) return null;

    var liberties: u8 = 0;
    var nb: [4]usize = undefined;
    const cnt = R.neighbors(p, &nb);
    for (nb[0..cnt]) |q| {
        if (next[q] == 0) liberties += 1;
    }
    if (liberties != 1) return null;

    return captured_cell;
}

fn findAllKoPoints(pos: *const R.Pos, list: *std.ArrayListUnmanaged(KoPoint), gpa: std.mem.Allocator) !void {
    for (0..R.n) |p| {
        inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
            if (isKoCapture(pos, p, colour)) |cap| {
                try list.append(gpa, .{ .cell = @intCast(p), .cap = @intCast(cap) });
            }
        }
    }
}

fn countIndependentClusters(ko_points: []const KoPoint) u8 {
    if (ko_points.len == 0) return 0;
    if (ko_points.len > 32) @panic("too many ko points for u32 mask");

    var masks: [32]u32 = undefined;
    for (ko_points, 0..) |kp, i| {
        var mask: u32 = 0;
        mask |= @as(u32, 1) << @as(u5, @intCast(kp.cell));
        mask |= @as(u32, 1) << @as(u5, @intCast(kp.cap));
        var nb: [4]usize = undefined;
        const cnt = R.neighbors(kp.cell, &nb);
        for (nb[0..cnt]) |q| mask |= @as(u32, 1) << @as(u5, @intCast(q));
        const cnt2 = R.neighbors(kp.cap, &nb);
        for (nb[0..cnt2]) |q| mask |= @as(u32, 1) << @as(u5, @intCast(q));
        masks[i] = mask;
    }

    var parent: [32]u8 = undefined;
    for (0..ko_points.len) |i| parent[i] = @intCast(i);
    for (0..ko_points.len) |i| {
        for (i + 1..ko_points.len) |j| {
            if (masks[i] & masks[j] != 0) {
                var ri: u8 = @intCast(i);
                while (parent[ri] != ri) {
                    parent[ri] = parent[parent[ri]];
                    ri = parent[ri];
                }
                var rj: u8 = @intCast(j);
                while (parent[rj] != rj) {
                    parent[rj] = parent[parent[rj]];
                    rj = parent[rj];
                }
                if (ri != rj) parent[ri] = rj;
            }
        }
    }

    var roots: u32 = 0;
    for (0..ko_points.len) |i| {
        var r: u8 = @intCast(i);
        while (parent[r] != r) {
            parent[r] = parent[parent[r]];
            r = parent[r];
        }
        roots |= @as(u32, 1) << @as(u5, @intCast(r));
    }
    return @popCount(roots);
}

fn classifyKo(pos: *const R.Pos, gpa: std.mem.Allocator) u8 {
    var ko_points = std.ArrayListUnmanaged(KoPoint).initCapacity(gpa, 32) catch return 0;
    defer ko_points.deinit(gpa);
    findAllKoPoints(pos, &ko_points, gpa) catch return 0;
    const n = countIndependentClusters(ko_points.items);
    return if (n < 3) n else 3;
}

// ---------------------------------------------------------------------------
// Small JSON writer (hand-rolled; deterministic key order).
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

// ---------------------------------------------------------------------------
// Opening generation. Canonical: the three inequivalent first moves
// (corner A1, edge B1, centre B2). Random: `count` two-ply openings from a
// seeded RNG (both plies trivially legal on an empty 4x4).
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
        // One-ply openings: Black's first move only, White to move after.
        // NB: the slice length IS the opening length — never pad with a
        // sentinel element (a 2-element {cell,0} literal would silently
        // become a two-ply 'stone + White pass' opening, len=2).
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
        if (seen[sig]) continue; // dedupe: the same two-ply opening twice is
        // one opening, not two — the denominator must count distinct positions.
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
// One game: opening + old colour + frame.
// ---------------------------------------------------------------------------
const GameRecord = struct {
    game_id: []const u8 = "",
    opening: []const u8 = "",
    old_colour: i8 = 1, // +1 Black, -1 White
    moves: std.ArrayListUnmanaged(u8) = .empty, // cell+1, 0 = pass (incl. opening plies)
    ply_count: usize = 0,
    capped: bool = false,
    disagree_plys: u64 = 0, // total plies where the two engines chose differently
    cross_ruleset_plys: std.ArrayListUnmanaged(usize) = .empty, // frame b: new engine played a PSK-forbidden repetition
    old_result: enum { win, loss, draw } = .draw,

    has_divergence: bool = false,
    div_ply: usize = 0,
    div_side: i8 = 1,
    div_old_move: u8 = 0, // cell+1 / 0 pass
    div_old_value: i8 = 0,
    div_new_move: u8 = 0,
    div_new_value: i8 = 0,
    div_old_v0: i8 = 0, // node's stored V0 in the old table
    div_new_L: i8 = 0,
    div_new_H: i8 = 0,
    div_new_DTT: u8 = 0,
    div_new_terminal: bool = false,
    div_new_ko_sensitive: bool = false,
    div_ko_pending: bool = false,
    div_passes: u8 = 0,
    div_ko_class: u8 = 0,
    div_in_scope: bool = false, // ko==NONE and passes==0: the fresh-start slice
    div_node_equal: bool = false, // old V0 == new pinned value

    score: i8 = 0,

    // substitution replay (engine-vs-engine regression semantics)
    sub_completed: bool = false,
    sub_score: i8 = 0,
    sub_old_colour_wins: bool = false,
    sub_diverged: bool = false,
    sub_capped: bool = false,

    // arbiter: new engine self-play from the opening
    arb_completed: bool = false,
    arb_score: i8 = 0,
    arb_old_colour_wins: bool = false,
    arb_capped: bool = false,

    classification: enum { genuine_loss, not_attributable, equal_value, outcome_unknown } = .equal_value,

    // mirror: same measurement with roles swapped (new engine is the tested one)
    mirror_new_result: enum { win, loss, draw } = .draw,
    mirror_sub_completed: bool = false,
    mirror_sub_score: i8 = 0,
    mirror_sub_old_colour_wins: bool = false,
    mirror_sub_diverged: bool = false,
    mirror_sub_capped: bool = false,
    mirror_arb_completed: bool = false,
    mirror_arb_score: i8 = 0,
    mirror_arb_old_colour_wins: bool = false,
    mirror_arb_capped: bool = false,
    mirror_classification: enum { genuine_loss, not_attributable, equal_value, outcome_unknown } = .equal_value,

    sgf_path: []const u8 = "",
};

fn playOpening(sess: *S, opening: *const Opening) void {
    var side: i8 = 1;
    for (opening.moves[0..opening.len]) |m| {
        sess.applyMove(side, if (m == 0) null else m - 1) catch unreachable;
        side = -side;
    }
}

/// True if `side` placing at `cell` reproduces a position that already
/// occurred earlier in `sess`'s history (positional superko violation, the
/// old engine's rule). Used to flag frame-b plys where the NEW engine plays a
/// move the old engine's ruleset would forbid.
fn cellRepeatsHistory(sess: *const S, side: i8, cell: usize) bool {
    var scratch = sess.*;
    scratch.applyMove(side, cell) catch return false;
    const child_pos = scratch.hist[scratch.hist_len - 1];
    for (scratch.hist[0 .. scratch.hist_len - 1]) |*p| {
        if (std.mem.eql(i8, p, &child_pos)) return true;
    }
    return false;
}

fn runGame(
    gpa: std.mem.Allocator,
    dec: *const artifact.Decoded,
    a2: *const artifact2.LoadedArtifact,
    opening: *const Opening,
    old_colour: i8,
    frame_basic_ko: bool, // false = frame a (new engine psk-enforced), true = frame b
    ko_disagree: *[4]u64,
    out: *GameRecord,
    inject: ?*const Inject,
) !void {
    out.old_colour = old_colour;
    const enforcement: gtp.Enforcement = if (frame_basic_ko) .basic_ko else .psk;

    var s_old = S{ .d = dec, .a2 = null, .enforcement = .psk };
    var s_new = S{ .d = null, .a2 = a2, .enforcement = enforcement };
    s_old.reset();
    s_new.reset();
    playOpening(&s_old, opening);
    playOpening(&s_new, opening);

    // Record the opening plies in the game sequence (they are forced, not
    // engine choices).
    for (opening.moves[0..opening.len]) |m| {
        try out.moves.append(gpa, m);
    }

    var side: i8 = if (opening.len % 2 == 0) 1 else -1; // continue from the side after the forced opening plies
    var ply: usize = 0;

    while (ply < PLY_CAP) : (ply += 1) {
        if (s_old.passes >= 2) break;

        const co = s_old.choose(side);
        const cn = s_new.choose(side);

        if (co.cell != cn.cell) {
            out.disagree_plys += 1;
            const nko = classifyKo(&s_old.pos, gpa);
            ko_disagree[nko] += 1;

            // First divergence: record the node, both choices, both stored
            // values.
            if (!out.has_divergence) {
                out.has_divergence = true;
                out.div_ply = opening.len + ply; // index into out.moves (opening plies included)
                out.div_side = side;
                out.div_old_move = if (co.cell) |c| @intCast(c + 1) else 0;
                out.div_old_value = co.value;
                out.div_new_move = if (cn.cell) |c| @intCast(c + 1) else 0;
                out.div_new_value = cn.value;
                out.div_old_v0 = s_old.v0(&s_old.pos, side);
                const row = s_new.bounds2(&s_new.pos, s_new.ko_point, @intCast(s_new.passes), side);
                out.div_new_L = row.L;
                out.div_new_H = row.H;
                out.div_new_DTT = row.DTT;
                out.div_new_terminal = row.terminal;
                out.div_new_ko_sensitive = row.ko_sensitive;
                out.div_ko_pending = s_new.ko_point != KO_NONE;
                out.div_passes = s_new.passes;
                out.div_ko_class = classifyKo(&s_old.pos, gpa);
                out.div_in_scope = !out.div_ko_pending and out.div_passes == 0;
                out.div_node_equal = out.div_old_v0 == pinnedValue(row.L, row.H);
            }
        }

        // Played move: the side-to-move engine's choice. T375 injection:
        // force the NEW engine's move at one decision point (side != old
        // colour, matching moves-array index) to a deliberately bad move.
        var c = if (side == old_colour) co else cn;
        if (inject) |inj| {
            if (side != old_colour and opening.len + ply == inj.ply) {
                c.cell = if (inj.pass) null else inj.cell;
                std.debug.print("  [seedctl] INJECTED at moves-index {d} (ply {d}, {s} to move): new engine forced to {s}{s}\n", .{
                    opening.len + ply, ply, if (side > 0) "B" else "W",
                    if (inj.pass) "pass" else "cell ",
                    if (inj.pass) "" else "",
                });
            }
        }
        const cell: ?usize = c.cell;

        // Frame b: if the NEW engine made this move, check whether it repeats
        // a position the old engine's PSK rules forbid (cross-ruleset ply:
        // the old engine could not have chosen it in a PSK game).
        if (frame_basic_ko and side != old_colour and cell != null) {
            if (cellRepeatsHistory(&s_old, side, cell.?)) {
                try out.cross_ruleset_plys.append(gpa, opening.len + ply); // moves-array index
            }
        }

        try out.moves.append(gpa, if (cell) |cl| @intCast(cl + 1) else 0);
        s_old.applyMove(side, cell) catch unreachable;
        s_new.applyMove(side, cell) catch unreachable;
        side = -side;
    }

    out.ply_count = ply;
    out.capped = ply >= PLY_CAP;
    out.score = R.area_score(&s_old.pos);
    out.old_result = if (out.score > 0)
        (if (old_colour > 0) .win else .loss)
    else if (out.score < 0)
        (if (old_colour > 0) .loss else .win)
    else
        .draw;
}

const ReplayOutcome = struct {
    completed: bool,
    diverged: bool,
    capped: bool,
    score: i8 = 0,
    old_colour_wins: bool = false,
};

/// Substitution replay (engine-vs-engine regression semantics): from the
/// empty goban with the same forced opening, at the old engine's DECISION
/// points (old-colour plies beyond the opening) play the NEW engine's live
/// choice; at every other ply replay the original game's move. Verifies
/// legality of replayed moves (and PSK legality in frame a); aborts
/// (diverged) when the original line no longer fits. `orig_moves` includes
/// the opening plies.
fn substitutionReplay(
    a2: *const artifact2.LoadedArtifact,
    opening: *const Opening,
    old_colour: i8,
    frame_basic_ko: bool,
    orig_moves: []const u8,
) ReplayOutcome {
    const enforcement: gtp.Enforcement = if (frame_basic_ko) .basic_ko else .psk;
    var s = S{ .d = null, .a2 = a2, .enforcement = enforcement };
    s.reset();

    var side: i8 = 1;
    var mi: usize = 0;
    var plies: usize = 0;
    var outcome = ReplayOutcome{ .completed = false, .diverged = false, .capped = false };

    while (plies < PLY_CAP and s.passes < 2 and mi < orig_moves.len) : (plies += 1) {
        const old_decision = (side == old_colour and mi >= opening.len);
        if (old_decision) {
            const c = s.choose(side);
            s.applyMove(side, c.cell) catch {
                outcome.diverged = true;
                return outcome;
            };
        } else {
            const m = orig_moves[mi];
            if (m == 0) {
                s.applyMove(side, null) catch {
                    outcome.diverged = true;
                    return outcome;
                };
            } else {
                const cell: usize = m - 1;
                const child = R.pos_from_move(&s.pos, side, cell) catch {
                    outcome.diverged = true;
                    return outcome;
                };
                if (enforcement == .psk and s.seen(&child)) {
                    outcome.diverged = true;
                    return outcome;
                }
                s.applyMove(side, cell) catch unreachable;
            }
        }
        side = -side;
        mi += 1;
    }

    if (plies >= PLY_CAP) {
        outcome.capped = true;
        return outcome;
    }
    if (s.passes < 2) {
        // Move sequence exhausted before the game finished.
        outcome.diverged = true;
        return outcome;
    }
    outcome.completed = true;
    outcome.score = R.area_score(&s.pos);
    outcome.old_colour_wins = if (old_colour > 0) outcome.score > 0 else outcome.score < 0;
    return outcome;
}

/// Arbiter: the new engine plays BOTH colours from the opening position
/// (opening plies forced). Reports whether the new engine wins with the old
/// engine's colour from this exact opening.
fn arbiterPlay(
    a2: *const artifact2.LoadedArtifact,
    opening: *const Opening,
    old_colour: i8,
    frame_basic_ko: bool,
) ReplayOutcome {
    const enforcement: gtp.Enforcement = if (frame_basic_ko) .basic_ko else .psk;
    var s = S{ .d = null, .a2 = a2, .enforcement = enforcement };
    s.reset();
    playOpening(&s, opening);

    var side: i8 = if (opening.len % 2 == 0) 1 else -1; // side to move after the forced opening
    var plies: usize = 0;
    while (plies < PLY_CAP and s.passes < 2) : (plies += 1) {
        const c = s.choose(side);
        s.applyMove(side, c.cell) catch unreachable;
        side = -side;
    }
    var outcome = ReplayOutcome{ .completed = false, .diverged = false, .capped = false };
    if (plies >= PLY_CAP) {
        outcome.capped = true;
        return outcome;
    }
    outcome.completed = s.passes >= 2;
    outcome.score = R.area_score(&s.pos);
    outcome.old_colour_wins = if (old_colour > 0) outcome.score > 0 else outcome.score < 0;
    return outcome;
}

/// Mirror measurement (the 'is the new engine strictly better?' question):
/// the substitution-replay logic with roles swapped. At the TESTED (new)
/// engine's decision points the reference (old) engine plays; at the old
/// engine's turns the original moves are replayed (they were the old engine's
/// own choices). If the OLD engine wins with the NEW engine's colour, the new
/// engine threw away a winnable position.
fn mirrorSubstitution(
    dec: *const artifact.Decoded,
    opening: *const Opening,
    tested_colour: i8, // the NEW engine's colour in the original game
    orig_moves: []const u8,
) ReplayOutcome {
    var s = S{ .d = dec, .a2 = null, .enforcement = .psk };
    s.reset();

    var side: i8 = 1;
    var mi: usize = 0;
    var plies: usize = 0;
    var outcome = ReplayOutcome{ .completed = false, .diverged = false, .capped = false };

    while (plies < PLY_CAP and s.passes < 2 and mi < orig_moves.len) : (plies += 1) {
        const ref_decision = (side == tested_colour and mi >= opening.len);
        if (ref_decision) {
            const c = s.choose(side);
            s.applyMove(side, c.cell) catch {
                outcome.diverged = true;
                return outcome;
            };
        } else {
            const m = orig_moves[mi];
            if (m == 0) {
                s.applyMove(side, null) catch {
                    outcome.diverged = true;
                    return outcome;
                };
            } else {
                const cell: usize = m - 1;
                const child = R.pos_from_move(&s.pos, side, cell) catch {
                    outcome.diverged = true;
                    return outcome;
                };
                if (s.seen(&child)) { // the old engine's rule: PSK
                    outcome.diverged = true;
                    return outcome;
                }
                s.applyMove(side, cell) catch unreachable;
            }
        }
        side = -side;
        mi += 1;
    }

    if (plies >= PLY_CAP) {
        outcome.capped = true;
        return outcome;
    }
    if (s.passes < 2) {
        outcome.diverged = true;
        return outcome;
    }
    outcome.completed = true;
    outcome.score = R.area_score(&s.pos);
    outcome.old_colour_wins = if (tested_colour > 0) outcome.score > 0 else outcome.score < 0;
    return outcome;
}

/// Mirror arbiter: the OLD engine self-plays both colours from the opening;
/// reports whether it wins with the NEW engine's colour.
fn mirrorArbiter(
    dec: *const artifact.Decoded,
    opening: *const Opening,
    tested_colour: i8,
) ReplayOutcome {
    var s = S{ .d = dec, .a2 = null, .enforcement = .psk };
    s.reset();
    playOpening(&s, opening);

    var side: i8 = if (opening.len % 2 == 0) 1 else -1;
    var plies: usize = 0;
    while (plies < PLY_CAP and s.passes < 2) : (plies += 1) {
        const c = s.choose(side);
        s.applyMove(side, c.cell) catch unreachable;
        side = -side;
    }
    var outcome = ReplayOutcome{ .completed = false, .diverged = false, .capped = false };
    if (plies >= PLY_CAP) {
        outcome.capped = true;
        return outcome;
    }
    outcome.completed = s.passes >= 2;
    outcome.score = R.area_score(&s.pos);
    outcome.old_colour_wins = if (tested_colour > 0) outcome.score > 0 else outcome.score < 0;
    return outcome;
}

/// Outcome-based classification: does the old engine lose (or fail to win) a
/// game its colour could have drawn/won under better moves? Decided by what
/// the new engine achieves with the old engine's colour from the same opening
/// (substitution replay preferred, arbiter as fallback).
fn classifyGame(rec: *GameRecord) void {
    if (rec.old_result == .win) {
        rec.classification = .equal_value;
        return;
    }
    var better: ?bool = null; // can old's colour strictly do better than old's result?
    if (rec.sub_completed) {
        if (rec.old_result == .loss) {
            better = rec.sub_old_colour_wins or rec.sub_score == 0; // threw away a win or a draw
        } else { // draw
            better = rec.sub_old_colour_wins; // threw away a win
        }
    } else if (rec.arb_completed) {
        if (rec.old_result == .loss) {
            better = rec.arb_old_colour_wins or rec.arb_score == 0;
        } else { // draw
            better = rec.arb_old_colour_wins;
        }
    }
    rec.classification = if (better == null)
        .outcome_unknown
    else if (better.?)
        .genuine_loss
    else if (rec.old_result == .loss)
        .not_attributable
    else
        .equal_value;
}

/// Mirror classification: does the NEW engine lose (or fail to win) a game
/// its colour could have won under the OLD engine's moves? Decided by the old
/// engine's substitution replay (preferred) or old-engine self-play arbiter.
fn classifyMirror(rec: *GameRecord) void {
    const new_colour: i8 = -rec.old_colour;
    rec.mirror_new_result = if (rec.score > 0)
        (if (new_colour > 0) .win else .loss)
    else if (rec.score < 0)
        (if (new_colour > 0) .loss else .win)
    else
        .draw;

    if (rec.mirror_new_result == .win) {
        rec.mirror_classification = .equal_value;
        return;
    }
    var better: ?bool = null;
    if (rec.mirror_sub_completed) {
        if (rec.mirror_new_result == .loss) {
            better = rec.mirror_sub_old_colour_wins or rec.mirror_sub_score == 0;
        } else { // draw
            better = rec.mirror_sub_old_colour_wins;
        }
    } else if (rec.mirror_arb_completed) {
        if (rec.mirror_new_result == .loss) {
            better = rec.mirror_arb_old_colour_wins or rec.mirror_arb_score == 0;
        } else { // draw
            better = rec.mirror_arb_old_colour_wins;
        }
    }
    rec.mirror_classification = if (better == null)
        .outcome_unknown
    else if (better.?)
        .genuine_loss
    else if (rec.mirror_new_result == .loss)
        .not_attributable
    else
        .equal_value;
}

// ---------------------------------------------------------------------------
// SGF emission with per-node comments.
// ---------------------------------------------------------------------------
fn emitSgf(
    io: std.Io,
    gpa: std.mem.Allocator,
    dir: []const u8,
    fname: []const u8,
    frame_name: []const u8,
    opening: *const Opening,
    rec: *const GameRecord,
) !void {
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(gpa);

    var root_comment_buf: [512]u8 = undefined;
    var root_rbuf: [16]u8 = undefined;
    const root_comment = std.fmt.bufPrint(&root_comment_buf,
        \\T366 divergence kifu. frame={s} old-colour={s} opening={s} result={s} old-result={s} classification={s}
    , .{
        frame_name,
        if (rec.old_colour > 0) "Black" else "White",
        opening.name,
        fmtResult(rec.score, &root_rbuf),
        @tagName(rec.old_result),
        @tagName(rec.classification),
    }) catch "T366 divergence kifu";

    try buf.appendSlice(gpa, "(;GM[1]FF[4]CA[UTF-8]AP[weizigo-t366-evse]RU[Chinese]KM[0]SZ[4]C[");
    try buf.appendSlice(gpa, root_comment);
    try buf.appendSlice(gpa, "]");

    var side: i8 = 1;
    for (rec.moves.items, 0..) |m, ply| {
        var vbuf: [4]u8 = undefined;
        var cmt_buf: [512]u8 = undefined;
        var cmt: ?[]const u8 = null;

        if (rec.has_divergence and ply == rec.div_ply) {
            var ov: [4]u8 = undefined;
            var nv: [4]u8 = undefined;
            const old_mv = if (rec.div_old_move == 0) "pass" else vertex(rec.div_old_move - 1, &ov);
            const new_mv = if (rec.div_new_move == 0) "pass" else vertex(rec.div_new_move - 1, &nv);
            cmt = std.fmt.bufPrint(&cmt_buf,
                \\DIVERGENCE ply{d}: OLD would play {s} child-value {d}; NEW plays {s} child-value {d}. node old-V0={d} new-L={d} new-H={d} ko={d} passes={d} in-scope={s}
            , .{
                ply, old_mv, rec.div_old_value, new_mv, rec.div_new_value,
                rec.div_old_v0, rec.div_new_L, rec.div_new_H,
                @as(u8, if (rec.div_ko_pending) 1 else 0), rec.div_passes,
                if (rec.div_in_scope) "yes" else "no",
            }) catch null;
        }
        for (rec.cross_ruleset_plys.items) |cp| {
            if (cp == ply) {
                var c2: [256]u8 = undefined;
                const note = std.fmt.bufPrint(&c2,
                    \\NOTE: this move repeats a position the old engine's PSK rules forbid (cross-ruleset ply)
                , .{}) catch null;
                if (note) |n| {
                    if (cmt) |existing| {
                        var merged: [768]u8 = undefined;
                        cmt = std.fmt.bufPrint(&merged, "{s} | {s}", .{ existing, n }) catch null;
                    } else {
                        cmt = note;
                    }
                }
            }
        }

        try buf.appendSlice(gpa, if (side > 0) ";B[" else ";W[");
        if (m == 0) {
            try buf.appendSlice(gpa, "]");
        } else {
            try buf.appendSlice(gpa, vertex(m - 1, &vbuf));
            try buf.appendSlice(gpa, "]");
        }
        if (cmt) |c| {
            try buf.appendSlice(gpa, "C[");
            try buf.appendSlice(gpa, c);
            try buf.appendSlice(gpa, "]");
        }
        side = -side;
    }
    try buf.appendSlice(gpa, ")\n");

    const path = try std.fs.path.join(gpa, &.{ dir, fname });
    defer gpa.free(path);
    var file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, buf.items);
}

// ---------------------------------------------------------------------------
// JSON emission: one frame's object as owned text; main assembles the
// combined findings file.
// ---------------------------------------------------------------------------
fn frameJson(
    gpa: std.mem.Allocator,
    frame_name: []const u8,
    frame_basic_ko: bool,
    openings: *const OpeningList,
    games: []const GameRecord,
    ko_disagree: [4]u64,
    old_path: []const u8,
    new_path: []const u8,
    seed: u64,
    instrument_stamp: []const u8,
) ![]u8 {
    var j = Json.init(gpa);
    defer j.deinit();

    try j.raw("{\n");
    try j.raw("\"frame\":");
    try j.str(frame_name);
    try j.raw(",\n\"new_engine_enforcement\":");
    try j.str(if (frame_basic_ko) "basic-ko" else "psk");
    try j.raw(",\n\"old_engine_enforcement\":\"psk\",\n\"old_artifact\":");
    try j.str(old_path);
    try j.raw(",\n\"new_artifact\":");
    try j.str(new_path);
    try j.raw(",\n\"seed\":");
    try j.num(@intCast(seed));
    try j.raw(",\n\"instrument_stamp\":");
    try j.str(instrument_stamp);
    try j.raw(",\n");

    var div: u64 = 0;
    var genuine: u64 = 0;
    var not_attr: u64 = 0;
    var eqv: u64 = 0;
    var unk: u64 = 0;
    var capped: u64 = 0;
    var old_wins: u64 = 0;
    var old_losses: u64 = 0;
    var old_draws: u64 = 0;
    var cross_plys: u64 = 0;
    var in_scope_div: u64 = 0;
    var disagree_total: u64 = 0;
    var m_genuine: u64 = 0;
    var m_not_attr: u64 = 0;
    var m_eqv: u64 = 0;
    var m_unk: u64 = 0;
    var m_new_wins: u64 = 0;
    var m_new_losses: u64 = 0;
    var m_new_draws: u64 = 0;
    for (games) |g| {
        if (g.has_divergence) div += 1;
        if (g.has_divergence and g.div_in_scope) in_scope_div += 1;
        disagree_total += g.disagree_plys;
        switch (g.classification) {
            .genuine_loss => genuine += 1,
            .not_attributable => not_attr += 1,
            .equal_value => eqv += 1,
            .outcome_unknown => unk += 1,
        }
        switch (g.mirror_classification) {
            .genuine_loss => m_genuine += 1,
            .not_attributable => m_not_attr += 1,
            .equal_value => m_eqv += 1,
            .outcome_unknown => m_unk += 1,
        }
        if (g.capped) capped += 1;
        switch (g.old_result) {
            .win => old_wins += 1,
            .loss => old_losses += 1,
            .draw => old_draws += 1,
        }
        switch (g.mirror_new_result) {
            .win => m_new_wins += 1,
            .loss => m_new_losses += 1,
            .draw => m_new_draws += 1,
        }
        cross_plys += g.cross_ruleset_plys.items.len;
    }

    try j.raw("\"summary\":{\n");
    try j.raw("\"games\":");
    try j.num(@intCast(games.len));
    try j.raw(",\n\"openings\":");
    try j.num(@intCast(openings.items.items.len));
    try j.raw(",\n\"diverged_games\":");
    try j.num(@intCast(div));
    try j.raw(",\n\"in_scope_first_divergences\":");
    try j.num(@intCast(in_scope_div));
    try j.raw(",\n\"total_disagreeing_plys\":");
    try j.num(@intCast(disagree_total));
    try j.raw(",\n\"genuine_value_losses\":");
    try j.num(@intCast(genuine));
    try j.raw(",\n\"loss_not_attributable\":");
    try j.num(@intCast(not_attr));
    try j.raw(",\n\"equal_value\":");
    try j.num(@intCast(eqv));
    try j.raw(",\n\"outcome_unknown\":");
    try j.num(@intCast(unk));
    try j.raw(",\n\"capped_games\":");
    try j.num(@intCast(capped));
    try j.raw(",\n\"old_wins\":");
    try j.num(@intCast(old_wins));
    try j.raw(",\n\"old_losses\":");
    try j.num(@intCast(old_losses));
    try j.raw(",\n\"old_draws\":");
    try j.num(@intCast(old_draws));
    try j.raw(",\n\"cross_ruleset_plys\":");
    try j.num(@intCast(cross_plys));
    try j.raw(",\n\"ko_disagree_by_class\":[");
    for (ko_disagree, 0..) |k, i| {
        if (i > 0) try j.raw(",");
        try j.num(@intCast(k));
    }
    try j.raw("]},\n");

    try j.raw("\"mirror_summary\":{\n\"new_wins\":");
    try j.num(@intCast(m_new_wins));
    try j.raw(",\n\"new_losses\":");
    try j.num(@intCast(m_new_losses));
    try j.raw(",\n\"new_draws\":");
    try j.num(@intCast(m_new_draws));
    try j.raw(",\n\"new_engine_genuine_losses\":");
    try j.num(@intCast(m_genuine));
    try j.raw(",\n\"new_engine_loss_not_attributable\":");
    try j.num(@intCast(m_not_attr));
    try j.raw(",\n\"new_engine_equal_value\":");
    try j.num(@intCast(m_eqv));
    try j.raw(",\n\"new_engine_outcome_unknown\":");
    try j.num(@intCast(m_unk));
    try j.raw("},\n");

    try j.raw("\"games\":[\n");
    for (games, 0..) |g, i| {
        if (i > 0) try j.raw(",\n");
        try j.raw("{\"game_id\":");
        try j.str(g.game_id);
        try j.raw(",\"opening\":");
        try j.str(g.opening);
        try j.raw(",\"old_colour\":");
        try j.str(if (g.old_colour > 0) "B" else "W");
        try j.raw(",\"moves\":[");
        for (g.moves.items, 0..) |m, ply| {
            if (ply > 0) try j.raw(",");
            var vb: [4]u8 = undefined;
            if (m == 0) {
                try j.str("pass");
            } else {
                try j.str(vertex(m - 1, &vb));
            }
        }
        try j.raw("],\n\"result\":");
        var rbuf: [16]u8 = undefined;
        try j.str(fmtResult(g.score, &rbuf));
        try j.raw(",\"old_result\":");
        try j.str(@tagName(g.old_result));
        try j.raw(",\"capped\":");
        try j.boole(g.capped);
        try j.raw(",\"disagreeing_plys\":");
        try j.num(@intCast(g.disagree_plys));
        try j.raw(",\"cross_ruleset_plys\":[");
        for (g.cross_ruleset_plys.items, 0..) |cp, ci| {
            if (ci > 0) try j.raw(",");
            try j.num(@intCast(cp));
        }
        try j.raw("],\n\"classification\":");
        try j.str(@tagName(g.classification));
        try j.raw(",\"sgf\":");
        try j.str(g.sgf_path);
        try j.raw(",\n\"divergence\":");
        try j.boole(g.has_divergence);
        if (g.has_divergence) {
            try j.raw(",\"div_ply\":");
            try j.num(@intCast(g.div_ply));
            try j.raw(",\"div_side\":");
            try j.str(if (g.div_side > 0) "B" else "W");
            try j.raw(",\"old_move\":");
            if (g.div_old_move == 0) {
                try j.str("pass");
            } else {
                var vb: [4]u8 = undefined;
                try j.str(vertex(g.div_old_move - 1, &vb));
            }
            try j.raw(",\"old_child_value\":");
            try j.num(g.div_old_value);
            try j.raw(",\"new_move\":");
            if (g.div_new_move == 0) {
                try j.str("pass");
            } else {
                var vb: [4]u8 = undefined;
                try j.str(vertex(g.div_new_move - 1, &vb));
            }
            try j.raw(",\"new_child_value\":");
            try j.num(g.div_new_value);
            try j.raw(",\"node_old_v0\":");
            try j.num(g.div_old_v0);
            try j.raw(",\"node_new_L\":");
            try j.num(g.div_new_L);
            try j.raw(",\"node_new_H\":");
            try j.num(g.div_new_H);
            try j.raw(",\"node_new_DTT\":");
            try j.num(g.div_new_DTT);
            try j.raw(",\"node_new_terminal\":");
            try j.boole(g.div_new_terminal);
            try j.raw(",\"node_new_ko_sensitive\":");
            try j.boole(g.div_new_ko_sensitive);
            try j.raw(",\"node_ko_pending\":");
            try j.boole(g.div_ko_pending);
            try j.raw(",\"node_passes\":");
            try j.num(g.div_passes);
            try j.raw(",\"node_ko_class\":");
            try j.num(g.div_ko_class);
            try j.raw(",\"node_in_scope\":");
            try j.boole(g.div_in_scope);
            try j.raw(",\"node_value_equal\":");
            try j.boole(g.div_node_equal);
        }
        try j.raw(",\n\"substitution_replay\":{\"completed\":");
        try j.boole(g.sub_completed);
        try j.raw(",\"diverged\":");
        try j.boole(g.sub_diverged);
        try j.raw(",\"capped\":");
        try j.boole(g.sub_capped);
        try j.raw(",\"score\":");
        try j.num(g.sub_score);
        try j.raw(",\"old_colour_wins\":");
        try j.boole(g.sub_old_colour_wins);
        try j.raw("},\n\"arbiter_self_play\":{\"completed\":");
        try j.boole(g.arb_completed);
        try j.raw(",\"capped\":");
        try j.boole(g.arb_capped);
        try j.raw(",\"score\":");
        try j.num(g.arb_score);
        try j.raw(",\"old_colour_wins\":");
        try j.boole(g.arb_old_colour_wins);
        try j.raw("},\n\"mirror\":{\"new_result\":");
        try j.str(@tagName(g.mirror_new_result));
        try j.raw(",\"mirror_classification\":");
        try j.str(@tagName(g.mirror_classification));
        try j.raw(",\"substitution_replay\":{\"completed\":");
        try j.boole(g.mirror_sub_completed);
        try j.raw(",\"diverged\":");
        try j.boole(g.mirror_sub_diverged);
        try j.raw(",\"capped\":");
        try j.boole(g.mirror_sub_capped);
        try j.raw(",\"score\":");
        try j.num(g.mirror_sub_score);
        try j.raw(",\"old_engine_wins_with_new_colour\":");
        try j.boole(g.mirror_sub_old_colour_wins);
        try j.raw("},\"arbiter_old_self_play\":{\"completed\":");
        try j.boole(g.mirror_arb_completed);
        try j.raw(",\"capped\":");
        try j.boole(g.mirror_arb_capped);
        try j.raw(",\"score\":");
        try j.num(g.mirror_arb_score);
        try j.raw(",\"old_engine_wins_with_new_colour\":");
        try j.boole(g.mirror_arb_old_colour_wins);
        try j.raw("}}}"); // closes arbiter_old_self_play, mirror, and the game object
    }
    try j.raw("\n]}\n");

    return j.buf.toOwnedSlice(gpa);
}

fn runFrame(
    io: std.Io,
    gpa: std.mem.Allocator,
    dec: *const artifact.Decoded,
    a2: *const artifact2.LoadedArtifact,
    frame_name: []const u8,
    frame_basic_ko: bool,
    openings: *const OpeningList,
    out_dir: []const u8,
    seed: u64,
    instrument_stamp: []const u8,
    old_path: []const u8,
    new_path: []const u8,
    inject: ?*const Inject,
) ![]u8 {
    const p = std.debug.print;
    var games = std.ArrayListUnmanaged(GameRecord).empty;
    defer {
        for (games.items) |*g| {
            g.moves.deinit(gpa);
            g.cross_ruleset_plys.deinit(gpa);
        }
        games.deinit(gpa);
    }
    var ko_disagree = [_]u64{ 0, 0, 0, 0 };

    for (openings.items.items, 0..) |*opening, oi| {
        var progress_rbuf: [16]u8 = undefined;
        for ([_]i8{ 1, -1 }) |old_colour| {
            var rec = GameRecord{};
            var idbuf: [64]u8 = undefined;
            const id = std.fmt.bufPrint(&idbuf, "{s}-o{d:0>2}-{s}", .{
                frame_name, oi, if (old_colour > 0) "B" else "W",
            }) catch unreachable;
            rec.game_id = gpa.dupe(u8, id) catch unreachable;
            rec.opening = opening.name;

            try runGame(gpa, dec, a2, opening, old_colour, frame_basic_ko, &ko_disagree, &rec, if (inject) |inj| blk: {
                if (std.mem.eql(u8, frame_name, inj.frame) and oi == inj.opening_idx and old_colour == inj.old_colour)
                    break :blk inj
                else
                    break :blk null;
            } else null);

            // substitution replay + arbiter for non-wins
            if (rec.old_result != .win) {
                const sub = substitutionReplay(a2, opening, old_colour, frame_basic_ko, rec.moves.items);
                rec.sub_completed = sub.completed;
                rec.sub_diverged = sub.diverged;
                rec.sub_capped = sub.capped;
                rec.sub_score = sub.score;
                rec.sub_old_colour_wins = sub.old_colour_wins;

                const arb = arbiterPlay(a2, opening, old_colour, frame_basic_ko);
                rec.arb_completed = arb.completed;
                rec.arb_capped = arb.capped;
                rec.arb_score = arb.score;
                rec.arb_old_colour_wins = arb.old_colour_wins;
            }

            classifyGame(&rec);

            // mirror: the new engine as the tested one (roles swapped)
            {
                const msub = mirrorSubstitution(dec, opening, -old_colour, rec.moves.items);
                rec.mirror_sub_completed = msub.completed;
                rec.mirror_sub_diverged = msub.diverged;
                rec.mirror_sub_capped = msub.capped;
                rec.mirror_sub_score = msub.score;
                rec.mirror_sub_old_colour_wins = msub.old_colour_wins;

                const msub_arb = mirrorArbiter(dec, opening, -old_colour);
                rec.mirror_arb_completed = msub_arb.completed;
                rec.mirror_arb_capped = msub_arb.capped;
                rec.mirror_arb_score = msub_arb.score;
                rec.mirror_arb_old_colour_wins = msub_arb.old_colour_wins;

                classifyMirror(&rec);
            }

            if (rec.has_divergence) {
                var fnamebuf: [96]u8 = undefined;
                const fname = std.fmt.bufPrint(&fnamebuf, "t366-{s}-o{d:0>2}-{s}.sgf", .{
                    frame_name, oi, if (old_colour > 0) "B" else "W",
                }) catch unreachable;
                const fname_owned = gpa.dupe(u8, fname) catch unreachable;
                rec.sgf_path = std.fs.path.join(gpa, &.{ out_dir, fname_owned }) catch unreachable;
                try emitSgf(io, gpa, out_dir, fname_owned, frame_name, opening, &rec);
            }

            try games.append(gpa, rec);

            p("  {s} {s:>26}: {s}  old={s}  class={s}\n", .{
                id, opening.name, fmtResult(rec.score, &progress_rbuf),
                @tagName(rec.old_result), @tagName(rec.classification),
            });
        }
    }

    var div: u64 = 0;
    var genuine: u64 = 0;
    var not_attr: u64 = 0;
    var eqv: u64 = 0;
    var unk: u64 = 0;
    for (games.items) |g| {
        if (g.has_divergence) div += 1;
        switch (g.classification) {
            .genuine_loss => genuine += 1,
            .not_attributable => not_attr += 1,
            .equal_value => eqv += 1,
            .outcome_unknown => unk += 1,
        }
    }
    p("frame {s}: {d} games ({d} openings x 2 colours), diverged {d}, genuine {d}, not-attr {d}, equal {d}, unknown {d}\n", .{
        frame_name, games.items.len, openings.items.items.len, div, genuine, not_attr, eqv, unk,
    });

    return frameJson(gpa, frame_name, frame_basic_ko, openings, games.items, ko_disagree, old_path, new_path, seed, instrument_stamp);
}

pub fn main(init: std.process.Init) !void {
    std.debug.print("{s}\n", .{version.banner("weizigo-t366-evse")});
    const gpa = std.heap.page_allocator;
    const io = init.io;

    var old_path: []const u8 = DEFAULT_OLD;
    var new_path: []const u8 = DEFAULT_NEW;
    var out_dir: []const u8 = DEFAULT_OUT;
    var json_path: []const u8 = DEFAULT_JSON;
    var frame_mode: []const u8 = "both"; // a | b | both
    var openings_count: usize = 20;
    var seed: u64 = 42;
    var canonical = true;

    // T375 seeded control args
    var inj_frame: ?[]const u8 = null;
    var inj_opening: ?usize = null;
    var inj_colour: ?i8 = null;
    var inj_ply: ?usize = null;
    var inj_cell: ?[]const u8 = null; // vertex name or "pass"

    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    while (args.next()) |a| {
        if (std.mem.eql(u8, a, "--old")) old_path = args.next() orelse DEFAULT_OLD
        else if (std.mem.eql(u8, a, "--new")) new_path = args.next() orelse DEFAULT_NEW
        else if (std.mem.eql(u8, a, "--out")) out_dir = args.next() orelse DEFAULT_OUT
        else if (std.mem.eql(u8, a, "--json")) json_path = args.next() orelse DEFAULT_JSON
        else if (std.mem.eql(u8, a, "--frame")) frame_mode = args.next() orelse "both"
        else if (std.mem.eql(u8, a, "--openings")) openings_count = std.fmt.parseInt(usize, args.next() orelse "20", 10) catch 20
        else if (std.mem.eql(u8, a, "--seed")) seed = std.fmt.parseInt(u64, args.next() orelse "42", 10) catch 42
        else if (std.mem.eql(u8, a, "--no-canonical")) canonical = false
        else if (std.mem.eql(u8, a, "--inject-frame")) inj_frame = args.next()
        else if (std.mem.eql(u8, a, "--inject-opening")) inj_opening = std.fmt.parseInt(usize, args.next() orelse "0", 10) catch 0
        else if (std.mem.eql(u8, a, "--inject-colour")) inj_colour = if (std.mem.eql(u8, args.next() orelse "B", "W")) -1 else 1
        else if (std.mem.eql(u8, a, "--inject-ply")) inj_ply = std.fmt.parseInt(usize, args.next() orelse "0", 10) catch 0
        else if (std.mem.eql(u8, a, "--inject-cell")) inj_cell = args.next()
        else {
            std.debug.print("unknown argument '{s}'\n", .{a});
            return;
        }
    }

    // Build the injection spec (default: first new-engine decision point is
    // not assumed — callers must pass --inject-ply explicitly).
    var inject: ?Inject = null;
    if (inj_cell != null or inj_frame != null or inj_opening != null or inj_ply != null or inj_colour != null) {
        const cellname = inj_cell orelse "pass";
        var pass = false;
        var cell: usize = 0;
        if (std.mem.eql(u8, cellname, "pass")) {
            pass = true;
        } else {
            if (cellname.len != 2 or cellname[0] < 'a' or cellname[0] >= 'a' + W or cellname[1] < 'a' or cellname[1] >= 'a' + H) {
                std.debug.print("bad --inject-cell '{s}' (expect a vertex like 'aa' or 'pass')\n", .{cellname});
                return;
            }
            const col: usize = cellname[0] - 'a';
            const row: usize = cellname[1] - 'a';
            cell = row * W + col;
        }
        inject = .{
            .frame = inj_frame orelse "fA",
            .opening_idx = inj_opening orelse 0,
            .old_colour = inj_colour orelse 1,
            .ply = inj_ply orelse 0,
            .pass = pass,
            .cell = cell,
        };
        std.debug.print("seedctl injection: frame={s} opening_idx={d} old_colour={s} moves-index={d} cell={s}\n", .{
            inject.?.frame, inject.?.opening_idx, if (inject.?.old_colour > 0) "B" else "W",
            inject.?.ply, if (inject.?.pass) "pass" else cellname,
        });
    }

    var dec = artifact.load(io, std.Io.Dir.cwd(), old_path, gpa) catch |err| {
        std.debug.print("error: cannot load old artifact '{s}': {t}\n", .{ old_path, err });
        return;
    };
    defer dec.deinit();

    var a2 = artifact2.load(io, std.Io.Dir.cwd(), new_path, gpa) catch |err| {
        std.debug.print("error: cannot load new artifact '{s}': {t}\n", .{ new_path, err });
        return;
    };
    defer a2.deinit();

    if (dec.header.board_w != W or dec.header.board_h != H or a2.header.w != W or a2.header.h != H) {
        std.debug.print("error: artifacts must be {d}x{d} (old {d}x{d}, new {d}x{d})\n", .{
            W, H, dec.header.board_w, dec.header.board_h, a2.header.w, a2.header.h,
        });
        return;
    }

    std.debug.print("old: {s} ({d}x{d}, {d} legal/side, rules_id={d} {s})\n", .{
        old_path, dec.header.board_w, dec.header.board_h, dec.header.legal_count,
        dec.header.rules_id, artifact.rulesName(dec.header.rules_id),
    });
    std.debug.print("new: {s} ({d}x{d}, {d} groups, {d} entries, ko_bits={d}, rules_id={d} {s})\n", .{
        new_path, a2.header.w, a2.header.h, a2.header.n_groups, a2.header.n_entries,
        a2.header.ko_bits, artifact2.RULES_BASICKO_LH_AREA, artifact2.rulesName(artifact2.RULES_BASICKO_LH_AREA),
    });

    var openings = try buildOpenings(gpa, openings_count, seed, canonical);
    defer openings.names.deinit(gpa);
    defer openings.items.deinit(gpa);
    const stamp = try std.fmt.allocPrint(gpa, "{s}", .{version.banner("weizigo-t366-evse")});
    defer gpa.free(stamp);

    const do_a = std.mem.eql(u8, frame_mode, "a") or std.mem.eql(u8, frame_mode, "both");
    const do_b = std.mem.eql(u8, frame_mode, "b") or std.mem.eql(u8, frame_mode, "both");

    // Combined findings JSON: task header + one object per frame.
    var combined = std.ArrayList(u8).empty;
    defer combined.deinit(gpa);
    try combined.appendSlice(gpa, "{\n\"task_id\":\"T366\",\n\"date\":\"2026-08-05\",\n\"model\":\"deepseek-v4-flash\",\n\"identifier\":\"deepseek-v4-flash/T366\",\n\"frames\":[\n");

    var frame_count: usize = 0;
    if (do_a) {
        if (frame_count > 0) try combined.appendSlice(gpa, ",\n");
        const fa = try runFrame(io, gpa, &dec, &a2, "fA", false, &openings, out_dir, seed, stamp, old_path, new_path, if (inject) |*inj| inj else null);
        defer gpa.free(fa);
        try combined.appendSlice(gpa, fa);
        frame_count += 1;
    }
    if (do_b) {
        if (frame_count > 0) try combined.appendSlice(gpa, ",\n");
        const fb = try runFrame(io, gpa, &dec, &a2, "fB", true, &openings, out_dir, seed, stamp, old_path, new_path, if (inject) |*inj| inj else null);
        defer gpa.free(fb);
        try combined.appendSlice(gpa, fb);
        frame_count += 1;
    }
    try combined.appendSlice(gpa, "\n]}\n");

    var file = try std.Io.Dir.cwd().createFile(io, json_path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, combined.items);
    std.debug.print("wrote {s} ({d} bytes)\n", .{ json_path, combined.items.len });
}
