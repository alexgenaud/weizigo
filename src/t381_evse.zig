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
// Task: T381 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-05
//
// T381_THIRD_PARTY — play independent third-party engines against the 4x4
// oracle over GTP.
//
// Drives a subprocess engine (GNU Go, then Pachi / Fuego) over GTP while
// OUR side plays in-process from the WZO2 oracle artifact (basic ko,
// Chinese area, komi 0 — the L/H bracket table). Openings: the T366
// corpus (3 canonical one-ply + 30 seeded random two-ply, seed 42,
// deduplicated = 33 distinct) + the empty goban = 34 openings, each x 2
// colour assignments = 68 games per engine.
//
// For every game it records: final area score, our table's [L,H] bracket
// at every position WE moved from, the root bracket claim, and whether the
// outcome landed inside the root bracket. A loss (or tie) from a
// claimed-won position is the informative finding; each is resolved to one
// of three causes — ruleset mismatch, our move selector, or the table.
//
// In-process play (as T366 did): the GTP `play` surface of bin/weizigo-gtp
// enforces positional superko unconditionally, which would forbid basic-ko
// lines containing position repetitions (T366's caveat). Our side therefore
// plays through gtp.Session directly under .basic_ko enforcement; only the
// OPPONENT is a GTP subprocess.
//
// Reads ONLY: no build.zig edit, no engine-source edit, no src/vb_*.zig
// edit. Compiles standalone:
//
//   zig build-exe -O ReleaseFast --dep version -Mroot=src/t381_evse.zig \
//     -Mversion=src/version.zig --cache-dir /tmp/weizigo/t381/cache \
//     --global-cache-dir /tmp/weizigo/t381/global --name weizigo-t381-evse \
//     -femit-bin=/tmp/weizigo/t381/t381-evse
//
// Usage:
//   weizigo-t381-evse [--engine gnugo|pachi|fuego] [--artifact <wzo2>]
//     [--openings <N>] [--seed <N>] [--no-empty] [--no-canonical]
//     [--json <path>]
//   weizigo-t381-evse --probe [--engine gnugo|pachi|fuego]   (ruleset probe)
//   weizigo-t381-evse --nullctl <game-id> [--engine gnugo]   (null control)
//   weizigo-t381-evse --seedctl <game-id> <ply> <vertex|pass> [--engine gnugo]
//   weizigo-t381-evse --selfscore <game-id>                  (score authority
//                                                             replay, no engine)

const std = @import("std");
const version = @import("version");
const rules = @import("rules.zig");
const artifact2 = @import("artifact2.zig");
const gtp = @import("gtp.zig");

const W: usize = 4;
const H: usize = 4;
const R = rules.Rules(W, H);
const S = gtp.Session(W, H);
const KO_NONE: u8 = W * H; // gtp.Session KO_NONE == n

const PLY_CAP: usize = 400;

const DEFAULT_ARTIFACT = "data/oracle-4x4-v2.wzo2";
const DEFAULT_JSON = "findings/T381-third-party.json";

fn pinnedValue(L: i8, Hv: i8) i8 {
    return @max(L, @min(0, Hv));
}

// ---------------------------------------------------------------------------
// Engine definitions. argv[0] may be a bare name (resolved via PATH by
// std.process.spawn) or an absolute path.
// ---------------------------------------------------------------------------
const Engine = struct {
    name: []const u8,
    argv: []const []const u8,
    setup: []const []const u8 = &.{}, // extra GTP setup commands after the base
};

fn engineFor(name: []const u8) Engine {
    if (std.mem.eql(u8, name, "gnugo")) {
        // --never-resign: GNU Go's resign heuristic is broken on 4x4 (it
        // resigns even drawn positions); resignation is a politeness
        // heuristic, not a ruleset property, so forbidding it keeps the
        // ruleset identical while making the engine play to two passes.
        return .{
            .name = "gnugo",
            .argv = &.{ "gnugo", "--mode", "gtp", "--boardsize", "4", "--chinese-rules", "--komi", "0", "--forbid-suicide", "--simple-ko", "--never-resign" },
        };
    }
    if (std.mem.eql(u8, name, "pachi")) {
        // Per-move budget `-t =1000` (1000 simulations); `resign_threshold=0`
        // disables resignation (a politeness heuristic, not a ruleset
        // property — without it Pachi resigns most 4x4 positions on its
        // broken small-board eval); `threads=2` keeps the host polite.
        return .{
            .name = "pachi",
            .argv = &.{ "pachi", "resign_threshold=0", "threads=2", "-t", "=1000" },
            .setup = &.{ "boardsize 4", "clear_board", "komi 0" },
        };
    }
    if (std.mem.eql(u8, name, "fuego")) {
        // `--quiet` silences Fuego's banner; `time_settings 0 1 1` caps
        // each move at 1 s; `uct_param_player resign_threshold 0` disables
        // resignation; `go_param_rules ko_rule simple` switches Fuego from
        // its default POSITIONAL SUPERKO to our basic-ko ruleset — without
        // it the games are played under a different repetition rule (a
        // different game; T381 found this the hard way, see the evidence
        // doc section on ruleset matching).
        return .{
            .name = "fuego",
            .argv = &.{ "fuego", "--quiet" },
            .setup = &.{ "boardsize 4", "clear_board", "komi 0", "time_settings 0 1 1", "uct_param_player resign_threshold 0", "go_param_rules ko_rule simple" },
        };
    }
    // Fallback: treat name as a raw executable, GNU-Go-style flags assumed.
    return .{
        .name = name,
        .argv = &.{ name, "--mode", "gtp", "--boardsize", "4", "--chinese-rules", "--komi", "0", "--forbid-suicide", "--simple-ko" },
    };
}

/// T420 (additive): FULL-STRENGTH engine configurations, selected by --strong.
///
/// The headroom story, established by probing before the run:
///  - GNU Go: `--level` runs 0-10 and **10 is the default** (confirmed via
///    `gnugo --help`), so T381 already ran GNU Go at maximum strength. Adding
///    `--level 10` explicitly is documentation, not a change; the honest
///    result is "no headroom", not a re-run.
///  - Pachi: real headroom. T381's `-t =1000` actually ran ~11.5k simulations
///    per move (Pachi enforces a ~0.1 s minimum search: =500/=1000/=10000 all
///    land on the floor). `-t =50000` verifiably runs ~50-60k per move
///    (threads=8; reportfreq=1000000 suppresses intermediate progress lines so
///    stderr stays small enough to capture).
///  - Fuego: NO real headroom. Default `max_games` is already 1.79769e+308
///    (uncapped) and the search terminates on its own on 4x4 (~0.07-2.2 s,
///    ~170-230k playouts/move) regardless of the time budget (1 s vs 5 s
///    measured identical). `max_games 1000000` is set explicitly so the
///    configured value is recorded; it does not bind.
fn engineForStrong(name: []const u8) Engine {
    if (std.mem.eql(u8, name, "gnugo")) {
        // level 10 explicit = GNU Go's documented default and maximum.
        return .{
            .name = "gnugo",
            .argv = &.{ "gnugo", "--mode", "gtp", "--boardsize", "4", "--chinese-rules", "--komi", "0", "--forbid-suicide", "--simple-ko", "--never-resign", "--level", "10" },
        };
    }
    if (std.mem.eql(u8, name, "pachi")) {
        return .{
            .name = "pachi",
            .argv = &.{ "pachi", "resign_threshold=0", "threads=8", "reportfreq=1000000", "-t", "=50000" },
            .setup = &.{ "boardsize 4", "clear_board", "komi 0" },
        };
    }
    if (std.mem.eql(u8, name, "fuego")) {
        // T381 config + explicit (non-binding) max_games cap.
        return .{
            .name = "fuego",
            .argv = &.{ "fuego", "--quiet" },
            .setup = &.{ "boardsize 4", "clear_board", "komi 0", "time_settings 0 1 1", "uct_param_player resign_threshold 0", "go_param_rules ko_rule simple", "uct_param_player max_games 1000000" },
        };
    }
    return engineFor(name);
}

// ---------------------------------------------------------------------------
// GTP client over a spawned subprocess.
// ---------------------------------------------------------------------------
const Reply = struct {
    ok: bool,
    /// Slice into the client's in_buf; valid until the next command().
    value: []const u8,
};

const GtpClient = struct {
    child: std.process.Child,
    io: std.Io,
    gpa: std.mem.Allocator,
    in_buf: std.ArrayList(u8),
    name: []const u8,
    /// T420 (additive): when true, stderr is piped into err_buf instead of
    /// ignored — used by Pachi to read its per-move "*** WINNER (A/B games)"
    /// search summaries, the only reliable per-move playout counter.
    capture_stderr: bool = false,
    err_buf: std.ArrayList(u8) = .empty,

    fn spawn(io: std.Io, gpa: std.mem.Allocator, argv: []const []const u8) !GtpClient {
        return spawnInner(io, gpa, argv, false);
    }

    fn spawnWithStderr(io: std.Io, gpa: std.mem.Allocator, argv: []const []const u8) !GtpClient {
        return spawnInner(io, gpa, argv, true);
    }

    fn spawnInner(io: std.Io, gpa: std.mem.Allocator, argv: []const []const u8, capture_stderr: bool) !GtpClient {
        const child = try std.process.spawn(io, .{
            .argv = argv,
            .stdin = .pipe,
            .stdout = .pipe,
            .stderr = if (capture_stderr) .pipe else .ignore,
        });
        return .{ .child = child, .io = io, .gpa = gpa, .in_buf = std.ArrayList(u8).empty, .name = argv[0], .capture_stderr = capture_stderr };
    }

    fn deinit(self: *GtpClient) void {
        self.child.kill(self.io);
        self.in_buf.deinit(self.gpa);
        if (self.capture_stderr) self.err_buf.deinit(self.gpa);
    }

    /// T420 (additive): non-blocking drain of the captured stderr pipe into
    /// err_buf. Called between GTP commands so the pipe never fills (Pachi
    /// writes its per-move search summary to stderr during genmove).
    fn drainStderr(self: *GtpClient) void {
        if (!self.capture_stderr) return;
        const fd = self.child.stderr.?.handle;
        var buf: [8192]u8 = undefined;
        while (true) {
            var fds = [_]std.posix.pollfd{.{ .fd = fd, .events = std.posix.POLL.IN, .revents = 0 }};
            const ready = std.posix.poll(&fds, 0) catch 0;
            if (ready == 0) break;
            const got = self.child.stderr.?.readStreaming(self.io, &[_][]u8{buf[0..]}) catch break;
            if (got == 0) break;
            self.err_buf.appendSlice(self.gpa, buf[0..got]) catch break;
        }
    }

    /// Read until a complete GTP response block ("\n\n") is in in_buf.
    fn readBlock(self: *GtpClient) !void {
        var buf: [8192]u8 = undefined;
        while (std.mem.indexOf(u8, self.in_buf.items, "\n\n") == null) {
            const n = self.child.stdout.?.readStreaming(self.io, &[_][]u8{buf[0..]}) catch |err| {
                std.debug.print("t381: {s} stdout read error: {}\n", .{ self.name, err });
                return error.GtpReadFailed;
            };
            if (n == 0) {
                std.debug.print("t381: {s} closed stdout (EOF) mid-command; buffered {d} bytes\n", .{ self.name, self.in_buf.items.len });
                return error.GtpEof;
            }
            try self.in_buf.appendSlice(self.gpa, buf[0..n]);
        }
    }

    /// Send one GTP command and return its parsed reply. `value` slices into
    /// self.in_buf; it is valid until the next command() call.
    fn command(self: *GtpClient, cmd: []const u8) !Reply {
        try self.child.stdin.?.writeStreamingAll(self.io, cmd);
        try self.child.stdin.?.writeStreamingAll(self.io, "\n");
        self.in_buf.clearRetainingCapacity();
        try self.readBlock();
        const end = std.mem.indexOf(u8, self.in_buf.items, "\n\n") orelse return error.GtpBadBlock;
        var t = std.mem.trim(u8, self.in_buf.items[0..end], " \t\r\n");
        if (t.len == 0) return error.GtpBadBlock;
        const ok = t[0] == '=';
        if (t[0] != '=' and t[0] != '?') {
            std.debug.print("t381: {s} bad GTP response to '{s}': '{s}'\n", .{ self.name, cmd, t });
            return error.GtpBadBlock;
        }
        var rest = t[1..];
        // Skip an optional response id ("= 42 value").
        rest = std.mem.trimStart(u8, rest, " ");
        var id_end: usize = 0;
        while (id_end < rest.len and rest[id_end] >= '0' and rest[id_end] <= '9') id_end += 1;
        if (id_end > 0 and id_end < rest.len and rest[id_end] == ' ') {
            rest = std.mem.trimStart(u8, rest[id_end..], " ");
        }
        return .{ .ok = ok, .value = rest };
    }

    /// Handshake: boardsize 4, clear_board, komi 0. Returns false on any
    /// failure (including a board size the engine refuses).
    fn setup4x4(self: *GtpClient) !bool {
        const pv = try self.command("protocol_version");
        if (!pv.ok) return false;
        const bs = try self.command("boardsize 4");
        if (!bs.ok) return false;
        const cb = try self.command("clear_board");
        if (!cb.ok) return false;
        const km = try self.command("komi 0");
        if (!km.ok) return false;
        return true;
    }

    fn play(self: *GtpClient, colour: i8, cell: ?usize) !Reply {
        var vbuf: [8]u8 = undefined;
        const mv = if (cell) |c| gtp.vertex_from_cell(&vbuf, c, W, H) else "pass";
        const ch: u8 = if (colour > 0) 'b' else 'w';
        var cmdbuf: [32]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmdbuf, "play {c} {s}", .{ ch, mv }) catch unreachable;
        return self.command(cmd);
    }

    /// genmove. Returns: 0 = pass, 1..n = cell+1, 0xFF = resign, null on error.
    fn genmove(self: *GtpClient, colour: i8) !?u8 {
        const ch: u8 = if (colour > 0) 'b' else 'w';
        var cmdbuf: [16]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmdbuf, "genmove {c}", .{ch}) catch unreachable;
        const r = try self.command(cmd);
        if (!r.ok) {
            std.debug.print("t381: {s} genmove error: '{s}'\n", .{ self.name, r.value });
            return null;
        }
        const v = std.mem.trim(u8, r.value, " \t\r\n");
        if (v.len == 0) return error.GtpEmptyMove;
        if (std.ascii.eqlIgnoreCase(v, "pass")) return 0;
        if (std.ascii.eqlIgnoreCase(v, "resign")) return 0xFF;
        if (gtp.cell_from_vertex(v, W, H)) |cell| return @intCast(cell + 1);
        std.debug.print("t381: {s} genmove returned unparseable '{s}'\n", .{ self.name, v });
        return error.GtpUnparseableMove;
    }

    fn finalScore(self: *GtpClient) []const u8 {
        const r = self.command("final_score") catch return "?";
        return r.value;
    }

    fn listStones(self: *GtpClient, colour: i8) []const u8 {
        const ch: u8 = if (colour > 0) 'b' else 'w';
        var cmdbuf: [16]u8 = undefined;
        const cmd = std.fmt.bufPrint(&cmdbuf, "list_stones {c}", .{ch}) catch unreachable;
        const r = self.command(cmd) catch return "?";
        if (!r.ok) return "?";
        return r.value;
    }

    /// list_stones with the reply copied into `buf` (safe across subsequent
    /// commands). Returns "?" on failure.
    fn listStonesCopy(self: *GtpClient, buf: []u8, colour: i8) []const u8 {
        const v = self.listStones(colour);
        if (std.mem.eql(u8, v, "?")) return "?";
        const n = @min(v.len, buf.len - 1);
        @memcpy(buf[0..n], v[0..n]);
        buf[n] = 0;
        return buf[0..n];
    }
};

// ---------------------------------------------------------------------------
// Opening generation — verbatim from src/t366_evse.zig (same RNG, same seed
// 42) so the corpus is identical: 3 canonical one-ply + N random two-ply.
// ---------------------------------------------------------------------------
const Opening = struct {
    name: []const u8,
    moves: [2]u8, // cell+1; 0 = unused
    len: u8,
};

const OpeningList = struct {
    items: std.ArrayListUnmanaged(Opening) = .empty,
    names: std.ArrayListUnmanaged(u8) = .empty,
    gpa: std.mem.Allocator,

    fn add(o: *OpeningList, name: []const u8, moves: []const u8) !void {
        var op = Opening{ .name = undefined, .moves = .{ 0, 0 }, .len = 0 };
        for (moves, 0..) |m, i| op.moves[i] = m;
        op.len = @intCast(moves.len);
        const name_start = o.names.items.len;
        try o.names.appendSlice(o.gpa, name);
        try o.names.append(o.gpa, 0);
        op.name = o.names.items[name_start .. o.names.items.len - 1];
        try o.items.append(o.gpa, op);
    }
};

fn buildOpenings(gpa: std.mem.Allocator, count: usize, seed: u64, canonical: bool, empty: bool) !OpeningList {
    var list = OpeningList{ .gpa = gpa };
    if (canonical) {
        try list.add("canonical-corner-A1", &.{1}); // cell 0
        try list.add("canonical-edge-B1", &.{2}); // cell 1
        try list.add("canonical-centre-B2", &.{6}); // cell 5
    }
    var prng = std.Random.DefaultPrng.init(seed);
    const rnd = prng.random();
    var seen = [_]bool{false} ** 256;
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
        if (seen[sig]) continue;
        seen[sig] = true;
        var nmbuf: [64]u8 = undefined;
        var vb: [4]u8 = undefined;
        var vw: [4]u8 = undefined;
        const name = std.fmt.bufPrint(&nmbuf, "random-{d:0>3}-{s}{s}", .{ added, vertex(b, &vb), vertex(w, &vw) }) catch unreachable;
        try list.add(name, &.{ @intCast(b + 1), @intCast(w + 1) });
        added += 1;
    }
    if (empty) try list.add("empty", &.{});
    return list;
}

/// Vertex name for a cell (row-major, 'a'-based, SGF style — matches T366's
/// opening names).
fn vertex(cell: usize, buf: *[4]u8) []const u8 {
    const col: u8 = @intCast('a' + cell % W);
    const row: u8 = @intCast('a' + cell / W);
    buf[0] = col;
    buf[1] = row;
    return buf[0..2];
}

// ---------------------------------------------------------------------------
// Per-game recording.
// ---------------------------------------------------------------------------
const OurPosition = struct {
    ply: usize, // moves-array index (opening plies included)
    ko_pending: bool,
    passes: u8,
    L: i8,
    H: i8,
    pinned: i8,
    claimed_for_us: bool,
    ko_sensitive: bool,
    in_scope: bool,
    chosen: u8, // cell+1, 0 = pass
    chosen_value: i8, // V0 child value of the played move (pass edge for pass)
    extremum: i8, // best child value per the table (side-appropriate)
    optimal: bool, // chosen_value == extremum
    refused: bool, // choose_with_check refusal (A1/A2 chainability)
    refusal_cause: u8, // 0 none, 1 a1_node, 2 a2_child
};

const Result = enum { win, loss, tie };
const Finding = enum { none, loss_from_claimed, tie_from_claimed };
const Resolution = enum { none, ruleset_mismatch, selector, table_wrong, unresolved };

const GameRecord = struct {
    game_id: []const u8 = "",
    engine: []const u8 = "",
    opening: []const u8 = "",
    our_colour: i8 = 1,
    moves: std.ArrayListUnmanaged(u8) = .empty, // cell+1, 0=pass (opening plies included)
    score: i8 = 0, // area, Black-positive
    our_result: Result = .tie,
    capped: bool = false,
    engine_resigned: bool = false,
    engine_rejected: ?usize = null, // ply where the engine rejected OUR play
    engine_illegal: ?usize = null, // ply where the engine's move was illegal under our rules
    engine_final_score: []const u8 = "",
    our_positions: std.ArrayListUnmanaged(OurPosition) = .empty,
    // root = the first position where WE moved (first entry of our_positions)
    root_L: i8 = 0,
    root_H: i8 = 0,
    root_pinned: i8 = 0,
    root_claimed_for_us: bool = false,
    // start = the empty goban, our colour to move (game-start claim)
    start_L: i8 = 0,
    start_H: i8 = 0,
    start_claimed_for_us: bool = false,
    outcome_inside_root: bool = false,
    finding: Finding = .none,
    resolution: Resolution = .none,
    witness_ply: usize = 0,
    witness_L: i8 = 0,
    witness_H: i8 = 0,
    witness_pinned: i8 = 0,
    witness_note: []const u8 = "",
    engine_stone_check: u8 = 0, // 0 untested, 1 agree, 2 disagree
    // T420 (additive): achieved-strength instrumentation.
    strength_label: []const u8 = "",
    engine_playouts: std.ArrayListUnmanaged(u64) = .empty, // per engine-move, in order
    playouts_total: u64 = 0,
    playouts_missing: u64 = 0, // engine moves where no playout count could be read
};

fn claimedForUs(L: i8, Hv: i8, our_colour: i8) bool {
    if (our_colour > 0) return L > 0;
    return Hv < 0;
}

fn ourWon(score: i8, our_colour: i8) bool {
    return (our_colour > 0 and score > 0) or (our_colour < 0 and score < 0);
}

fn ourLost(score: i8, our_colour: i8) bool {
    return (our_colour > 0 and score < 0) or (our_colour < 0 and score > 0);
}

/// Extremum over children + pass edge at (pos, side) — mirrors chooseV2's
/// value logic (basic ko enforcement, no PSK filter). Returns the best
/// achievable value for `side` (max if Black, min if White).
fn extremumAt(s: *const S, side: i8) i8 {
    const maximizing = side > 0;
    const pass_value: i8 = if (s.passes >= 1)
        R.area_score(&s.pos)
    else blk: {
        const pass_row = s.bounds2(&s.pos, KO_NONE, @intCast(s.passes + 1), -side);
        break :blk pinnedValue(pass_row.L, pass_row.H);
    };
    var best: i8 = pass_value;
    for (0..R.n) |p| {
        if (s.pos[p] != 0) continue;
        if (s.ko_point != KO_NONE and p == s.ko_point) continue;
        const child = R.pos_from_move(&s.pos, side, p) catch continue;
        const child_ko = rules.koAfterCapture(&s.pos, &child, side, W, H, KO_NONE);
        const row = s.bounds2(&child, child_ko, 0, -side);
        const v = pinnedValue(row.L, row.H);
        if (maximizing) {
            if (v > best) best = v;
        } else {
            if (v < best) best = v;
        }
    }
    return best;
}

/// V0 value of the move (cell+1, 0=pass) for `side` at `pos`.
fn moveValueAt(s: *const S, side: i8, cell_plus: u8) i8 {
    if (cell_plus == 0) {
        if (s.passes >= 1) return R.area_score(&s.pos);
        const pass_row = s.bounds2(&s.pos, KO_NONE, @intCast(s.passes + 1), -side);
        return pinnedValue(pass_row.L, pass_row.H);
    }
    const p: usize = cell_plus - 1;
    const child = R.pos_from_move(&s.pos, side, p) catch return 0;
    const child_ko = rules.koAfterCapture(&s.pos, &child, side, W, H, KO_NONE);
    const row = s.bounds2(&child, child_ko, 0, -side);
    return pinnedValue(row.L, row.H);
}

/// T420: extract the total-simulations count from the LAST
/// "*** WINNER is X with score Y% (A/B games)" line in Pachi's captured
/// stderr. Returns null if no WINNER line is present.
fn pachiLastPlayouts(err_buf: []const u8) ?u64 {
    var pos: usize = 0;
    var best: ?u64 = null;
    while (std.mem.indexOfPos(u8, err_buf, pos, "*** WINNER")) |wi| {
        pos = wi + 1;
        const paren = std.mem.indexOfPos(u8, err_buf, wi, "(") orelse break;
        const slash = std.mem.indexOfPos(u8, err_buf, paren, "/") orelse break;
        var end = slash + 1;
        while (end < err_buf.len and err_buf[end] >= '0' and err_buf[end] <= '9') end += 1;
        if (end == slash + 1) continue;
        best = std.fmt.parseInt(u64, err_buf[slash + 1 .. end], 10) catch continue;
    }
    return best;
}

/// T420: extract the "GamesPlayed N" line from Fuego's `uct_stat_search`
/// reply (the per-move achieved simulation count).
fn fuegoGamesPlayed(reply: []const u8) ?u64 {
    const pat = "GamesPlayed";
    const gi = std.mem.indexOf(u8, reply, pat) orelse return null;
    var start = gi + pat.len;
    while (start < reply.len and (reply[start] == ' ' or reply[start] == '\t')) start += 1;
    var end = start;
    while (end < reply.len and reply[end] >= '0' and reply[end] <= '9') end += 1;
    if (end == start) return null;
    return std.fmt.parseInt(u64, reply[start..end], 10) catch null;
}

/// T420: human-readable label of the strength configuration in effect.
fn strengthLabelFor(engine: Engine, strong: bool) []const u8 {
    if (!strong) return "baseline (T381 settings)";
    if (std.mem.eql(u8, engine.name, "gnugo")) return "gnugo --level 10 (default=max; no headroom)";
    if (std.mem.eql(u8, engine.name, "pachi")) return "pachi threads=8 reportfreq=1000000 -t =50000";
    if (std.mem.eql(u8, engine.name, "fuego")) return "fuego time_settings 0 1 1 uct_param_player max_games 1000000";
    return "strong";
}

// ---------------------------------------------------------------------------
// One game against a subprocess engine.
// ---------------------------------------------------------------------------
const Inject = struct {
    ply: usize, // moves-array index of OUR decision to override
    cell_plus: u8, // 0 = pass
};

fn playGame(
    io: std.Io,
    gpa: std.mem.Allocator,
    a2: *const artifact2.LoadedArtifact,
    engine: Engine,
    opening: *const Opening,
    opening_idx: usize,
    our_colour: i8,
    inject: ?*const Inject,
    strong: bool, // T420: full-strength config + per-move playout recording
) !GameRecord {
    var rec = GameRecord{};
    rec.engine = engine.name;
    rec.opening = opening.name;
    rec.our_colour = our_colour;
    rec.strength_label = strengthLabelFor(engine, strong);
    var idbuf: [96]u8 = undefined;
    const gid = std.fmt.bufPrint(&idbuf, "{s}-o{d:0>2}-{s}", .{
        engine.name, opening_idx, if (our_colour > 0) "B" else "W",
    }) catch unreachable;
    rec.game_id = gpa.dupe(u8, gid) catch unreachable;

    var client = if (strong and std.mem.eql(u8, engine.name, "pachi"))
        try GtpClient.spawnWithStderr(io, gpa, engine.argv)
    else
        try GtpClient.spawn(io, gpa, engine.argv);
    defer client.deinit();

    if (!(try client.setup4x4())) {
        std.debug.print("t381: {s} setup failed — cannot play (ruleset exclusion candidate)\n", .{ engine.name });
        return error.EngineSetupFailed;
    }
    for (engine.setup) |cmd| {
        const r = try client.command(cmd);
        if (!r.ok) {
            std.debug.print("t381: {s} setup command '{s}' failed: '{s}'\n", .{ engine.name, cmd, r.value });
            return error.EngineSetupFailed;
        }
    }

    var sess = S{ .d = null, .a2 = a2, .enforcement = .basic_ko };
    sess.reset();

    // Forced opening plies.
    var side: i8 = 1;
    for (opening.moves[0..opening.len]) |m| {
        const cell: ?usize = if (m == 0) null else m - 1;
        sess.applyMove(side, cell) catch unreachable;
        try rec.moves.append(gpa, m);
        const r = try client.play(side, cell);
        if (!r.ok) {
            rec.engine_rejected = rec.moves.items.len - 1;
            break;
        }
        side = -side;
    }

    // Play the game: side to move alternates. OUR decisions come from the
    // table; the ENGINE's from genmove.
    var ply: usize = opening.len;
    while (ply < PLY_CAP) : (ply += 1) {
        if (sess.passes >= 2) break;
        if (rec.engine_rejected != null or rec.engine_illegal != null) break;

        if (side == our_colour) {
            // Record the bracket at the position we are moving from.
            const row = sess.bounds2(&sess.pos, sess.ko_point, @intCast(sess.passes), side);
            var op = OurPosition{
                .ply = ply,
                .ko_pending = sess.ko_point != KO_NONE,
                .passes = sess.passes,
                .L = row.L,
                .H = row.H,
                .pinned = pinnedValue(row.L, row.H),
                .claimed_for_us = claimedForUs(row.L, row.H, our_colour),
                .ko_sensitive = row.ko_sensitive,
                .in_scope = sess.ko_point == KO_NONE and sess.passes == 0,
                .chosen = 0,
                .chosen_value = 0,
                .extremum = 0,
                .optimal = false,
                .refused = false,
                .refusal_cause = 0,
            };

            // Choose with the production selector (H5(a) chainability check).
            const cc = sess.choose_with_check(side);
            var chosen: u8 = if (cc.choice.cell) |c| @intCast(c + 1) else 0;

            // Seeded-control injection: force a deliberately bad move.
            if (inject) |inj| {
                if (ply == inj.ply) {
                    chosen = inj.cell_plus;
                    std.debug.print("t381: [seedctl] injected {s} at ply {d} ({s} to move) — deliberately wrong\n", .{
                        if (inj.cell_plus == 0) "pass" else "move",
                        ply, if (side > 0) "B" else "W",
                    });
                }
            }

            const ex = extremumAt(&sess, side);
            const cv = moveValueAt(&sess, side, chosen);
            op.chosen = chosen;
            op.chosen_value = cv;
            op.extremum = ex;
            op.optimal = cv == ex;
            op.refused = cc.refused();
            op.refusal_cause = switch (cc.cause) {
                .none => 0,
                .a1_node => 1,
                .a2_child => 2,
            };

            try rec.our_positions.append(gpa, op);

            const cell: ?usize = if (chosen == 0) null else chosen - 1;
            sess.applyMove(side, cell) catch unreachable;
            try rec.moves.append(gpa, chosen);
            const r = try client.play(side, cell);
            if (!r.ok) {
                rec.engine_rejected = ply;
                std.debug.print("t381: {s} REJECTED our {s} move at ply {d}: '{s}'\n", .{
                    engine.name, if (side > 0) "B" else "W", ply, r.value,
                });
                break;
            }
        } else {
            // Engine's move.
            const mv = try client.genmove(side);
            if (mv == null) {
                // Engine errored on genmove — treat as a ruleset/interop break.
                rec.engine_illegal = ply;
                break;
            }
            if (mv.? == 0xFF) {
                rec.engine_resigned = true;
                try rec.moves.append(gpa, 0);
                sess.applyMove(side, null) catch unreachable;
                break;
            }
            const cell: ?usize = if (mv.? == 0) null else mv.? - 1;
            sess.applyMove(side, cell) catch {
                rec.engine_illegal = ply;
                std.debug.print("t381: {s} played a move ILLEGAL under our rules at ply {d} (cell {?d})\n", .{
                    engine.name, ply, cell,
                });
                break;
            };
            try rec.moves.append(gpa, mv.?);

            // T420: record the engine's ACTUAL per-move playouts, not the
            // flag we passed. Pachi: parse the "*** WINNER (A/B games)"
            // summary from its captured stderr (written synchronously during
            // genmove). Fuego: query uct_stat_search for the search that just
            // finished (read-only command, no game-state change).
            if (strong) {
                if (std.mem.eql(u8, engine.name, "pachi")) {
                    client.drainStderr();
                    if (pachiLastPlayouts(client.err_buf.items)) |n| {
                        try rec.engine_playouts.append(gpa, n);
                    } else {
                        rec.playouts_missing += 1;
                    }
                } else if (std.mem.eql(u8, engine.name, "fuego")) {
                    const sr = try client.command("uct_stat_search");
                    if (fuegoGamesPlayed(sr.value)) |n| {
                        try rec.engine_playouts.append(gpa, n);
                    } else {
                        rec.playouts_missing += 1;
                    }
                }
            }
        }
        side = -side;
    }

    rec.capped = ply >= PLY_CAP;
    for (rec.engine_playouts.items) |n| rec.playouts_total += n;
    rec.score = R.area_score(&sess.pos);
    rec.our_result = if (rec.engine_resigned)
        .win
    else if (ourWon(rec.score, our_colour))
        .win
    else if (ourLost(rec.score, our_colour))
        .loss
    else
        .tie;
    rec.engine_final_score = gpa.dupe(u8, client.finalScore()) catch "";

    // Root = first position where we moved.
    if (rec.our_positions.items.len > 0) {
        const root = rec.our_positions.items[0];
        rec.root_L = root.L;
        rec.root_H = root.H;
        rec.root_pinned = root.pinned;
        rec.root_claimed_for_us = root.claimed_for_us;
        rec.outcome_inside_root = rec.score >= root.L and rec.score <= root.H;
    }

    // Start-of-game claim (empty goban, our colour to move).
    {
        var empty_sess = S{ .d = null, .a2 = a2, .enforcement = .basic_ko };
        empty_sess.reset();
        const row = empty_sess.bounds2(&empty_sess.pos, KO_NONE, 0, our_colour);
        rec.start_L = row.L;
        rec.start_H = row.H;
        rec.start_claimed_for_us = claimedForUs(row.L, row.H, our_colour);
    }

    // Positional agreement belt-and-braces: engine's list_stones vs our
    // session, both colours (best effort). Copy both replies into fixed
    // buffers first: the GTP client reuses one buffer per command.
    {
        var ebbuf: [256]u8 = undefined;
        var ewbuf: [256]u8 = undefined;
        const eb = client.listStonesCopy(&ebbuf, 1);
        const ew = client.listStonesCopy(&ewbuf, -1);
        if (!std.mem.eql(u8, eb, "?") and !std.mem.eql(u8, ew, "?")) {
            var agree = true;
            for (0..R.n) |p| {
                const in_engine_b = containsVertex(eb, p);
                const in_engine_w = containsVertex(ew, p);
                const mine = sess.pos[p];
                if (mine > 0 and !in_engine_b) agree = false;
                if (mine < 0 and !in_engine_w) agree = false;
                if (mine == 0 and (in_engine_b or in_engine_w)) agree = false;
            }
            rec.engine_stone_check = if (agree) 1 else 2;
        }
    }

    return rec;
}

/// Does a GTP list_stones reply contain the vertex for cell p?
fn containsVertex(reply: []const u8, p: usize) bool {
    var vbuf: [8]u8 = undefined;
    const v = gtp.vertex_from_cell(&vbuf, p, W, H);
    var it = std.mem.tokenizeAny(u8, reply, " \t\r\n");
    while (it.next()) |tok| {
        if (std.ascii.eqlIgnoreCase(tok, v)) return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// Classification & resolution.
// ---------------------------------------------------------------------------
fn classifyAndResolve(rec: *GameRecord) void {
    // A capped game (ply cap hit — basic-ko position cycling) is not a
    // completed game; it is reported separately, never classified (T366's
    // convention for outcome_unknown).
    if (rec.capped) return;

    if (rec.our_result == .loss and rec.root_claimed_for_us) {
        rec.finding = .loss_from_claimed;
    } else if (rec.our_result == .loss) {
        // A loss where the root was not claimed-won is still a finding if any
        // later our-position was claimed-won.
        for (rec.our_positions.items) |op| {
            if (op.claimed_for_us) {
                rec.finding = .loss_from_claimed;
                break;
            }
        }
    } else if (rec.our_result == .tie and rec.root_claimed_for_us) {
        rec.finding = .tie_from_claimed;
    }

    if (rec.finding == .none) return;

    // Resolution, in the brief's order.
    // 1. Ruleset mismatch.
    if (rec.engine_rejected != null or rec.engine_illegal != null) {
        rec.resolution = .ruleset_mismatch;
        rec.witness_ply = rec.engine_rejected orelse rec.engine_illegal.?;
        rec.witness_note = if (rec.engine_rejected != null)
            "the engine rejected one of our plays (its ruleset differs from ours)"
        else
            "the engine played a move illegal under our rules (its ruleset differs from ours)";
        return;
    }
    // 2. Our move selector: some our-position played a non-optimal move.
    for (rec.our_positions.items) |op| {
        if (!op.optimal) {
            rec.resolution = .selector;
            rec.witness_ply = op.ply;
            rec.witness_L = op.L;
            rec.witness_H = op.H;
            rec.witness_pinned = op.pinned;
            rec.witness_note = "we played a move whose child value is below the table's own extremum at this position (chosen_value vs extremum in our_positions)";
            return;
        }
    }
    // 3. Table wrong: clean rules, optimal play throughout, still lost a
    //    claimed-won position → the bracket over-claims.
    for (rec.our_positions.items) |op| {
        if (op.claimed_for_us) {
            rec.resolution = .table_wrong;
            rec.witness_ply = op.ply;
            rec.witness_L = op.L;
            rec.witness_H = op.H;
            rec.witness_pinned = op.pinned;
            rec.witness_note = "the table's bracket claims the position won for us; we played optimal moves (per the table) with clean rules and still lost — the fresh-start claim failed in real play";
            return;
        }
    }
    rec.resolution = .unresolved;
    rec.witness_note = "no cause determinable from the recorded data";
}

// ---------------------------------------------------------------------------
// JSON emission.
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

fn fmtScore(score: i8, buf: []u8) []const u8 {
    if (score > 0) return std.fmt.bufPrint(buf, "B+{d}", .{score}) catch unreachable;
    if (score < 0) return std.fmt.bufPrint(buf, "W+{d}", .{-score}) catch unreachable;
    return "0";
}

fn emitGameJson(j: *Json, rec: *const GameRecord) !void {
    try j.raw("{\"game_id\":");
    try j.str(rec.game_id);
    try j.raw(",\"engine\":");
    try j.str(rec.engine);
    try j.raw(",\"opening\":");
    try j.str(rec.opening);
    try j.raw(",\"our_colour\":");
    try j.str(if (rec.our_colour > 0) "B" else "W");
    try j.raw(",\"result\":");
    var sb: [16]u8 = undefined;
    try j.str(fmtScore(rec.score, &sb));
    try j.raw(",\"our_result\":");
    try j.str(@tagName(rec.our_result));
    try j.raw(",\"score\":");
    try j.num(rec.score);
    try j.raw(",\"capped\":");
    try j.boole(rec.capped);
    try j.raw(",\"engine_resigned\":");
    try j.boole(rec.engine_resigned);
    try j.raw(",\"engine_rejected_ply\":");
    if (rec.engine_rejected) |p| try j.num(@intCast(p)) else try j.raw("null");
    try j.raw(",\"engine_illegal_ply\":");
    if (rec.engine_illegal) |p| try j.num(@intCast(p)) else try j.raw("null");
    try j.raw(",\"engine_final_score\":");
    try j.str(rec.engine_final_score);
    try j.raw(",\"engine_stone_check\":");
    try j.num(rec.engine_stone_check);
    try j.raw(",\"root\":{\"L\":");
    try j.num(rec.root_L);
    try j.raw(",\"H\":");
    try j.num(rec.root_H);
    try j.raw(",\"pinned\":");
    try j.num(rec.root_pinned);
    try j.raw(",\"claimed_for_us\":");
    try j.boole(rec.root_claimed_for_us);
    try j.raw("},\"start\":{\"L\":");
    try j.num(rec.start_L);
    try j.raw(",\"H\":");
    try j.num(rec.start_H);
    try j.raw(",\"claimed_for_us\":");
    try j.boole(rec.start_claimed_for_us);
    try j.raw("},\"outcome_inside_root\":");
    try j.boole(rec.outcome_inside_root);
    try j.raw(",\"finding\":");
    try j.str(@tagName(rec.finding));
    try j.raw(",\"resolution\":");
    try j.str(@tagName(rec.resolution));
    try j.raw(",\"witness_ply\":");
    try j.num(@intCast(rec.witness_ply));
    try j.raw(",\"witness_L\":");
    try j.num(rec.witness_L);
    try j.raw(",\"witness_H\":");
    try j.num(rec.witness_H);
    try j.raw(",\"witness_pinned\":");
    try j.num(rec.witness_pinned);
    try j.raw(",\"witness_note\":");
    try j.str(rec.witness_note);
    try j.raw(",\"moves\":[");
    for (rec.moves.items, 0..) |m, i| {
        if (i > 0) try j.raw(",");
        var vbuf: [4]u8 = undefined;
        if (m == 0) {
            try j.str("pass");
        } else {
            try j.str(vertex(m - 1, &vbuf));
        }
    }
    try j.raw("],\n\"our_positions\":[");
    for (rec.our_positions.items, 0..) |op, i| {
        if (i > 0) try j.raw(",");
        try j.raw("{\"ply\":");
        try j.num(@intCast(op.ply));
        try j.raw(",\"L\":");
        try j.num(op.L);
        try j.raw(",\"H\":");
        try j.num(op.H);
        try j.raw(",\"pinned\":");
        try j.num(op.pinned);
        try j.raw(",\"claimed\":");
        try j.boole(op.claimed_for_us);
        try j.raw(",\"ko\":");
        try j.boole(op.ko_pending);
        try j.raw(",\"passes\":");
        try j.num(op.passes);
        try j.raw(",\"ko_sensitive\":");
        try j.boole(op.ko_sensitive);
        try j.raw(",\"in_scope\":");
        try j.boole(op.in_scope);
        try j.raw(",\"move\":");
        if (op.chosen == 0) {
            try j.str("pass");
        } else {
            var vbuf: [4]u8 = undefined;
            try j.str(vertex(op.chosen - 1, &vbuf));
        }
        try j.raw(",\"chosen_value\":");
        try j.num(op.chosen_value);
        try j.raw(",\"extremum\":");
        try j.num(op.extremum);
        try j.raw(",\"optimal\":");
        try j.boole(op.optimal);
        try j.raw(",\"refused\":");
        try j.boole(op.refused);
        try j.raw(",\"refusal_cause\":");
        try j.num(op.refusal_cause);
        try j.raw("}");
    }
    try j.raw("],\n\"strength\":");
    try j.str(rec.strength_label);
    try j.raw(",\"playouts\":[");
    for (rec.engine_playouts.items, 0..) |n, i| {
        if (i > 0) try j.raw(",");
        try j.num(@intCast(n));
    }
    try j.raw("],\n\"playouts_total\":");
    try j.num(@intCast(rec.playouts_total));
    try j.raw(",\"playouts_missing\":");
    try j.num(@intCast(rec.playouts_missing));
    try j.raw("}");
}

fn runEngine(
    io: std.Io,
    gpa: std.mem.Allocator,
    a2: *const artifact2.LoadedArtifact,
    engine: Engine,
    openings: *const OpeningList,
    json_path: []const u8,
    strong: bool, // T420
) !void {
    const p = std.debug.print;
    const strength_label = strengthLabelFor(engine, strong);
    var games = std.ArrayListUnmanaged(GameRecord).empty;
    defer {
        for (games.items) |*g| {
            g.moves.deinit(gpa);
            g.our_positions.deinit(gpa);
            g.engine_playouts.deinit(gpa); // T420
            gpa.free(g.game_id);
            gpa.free(g.engine_final_score);
        }
        games.deinit(gpa);
    }

    var wins: u64 = 0;
    var losses: u64 = 0;
    var ties: u64 = 0;
    var aborted: u64 = 0;
    var loss_from_claimed: u64 = 0;
    var tie_from_claimed: u64 = 0;
    var inside_root: u64 = 0;
    var capped: u64 = 0;
    var res_selector: u64 = 0;
    var res_ruleset: u64 = 0;
    var res_table: u64 = 0;
    var res_unresolved: u64 = 0;
    // T420: per-colour splits (the game is NOT colour-symmetric here) and
    // achieved-strength counters.
    var wins_b: u64 = 0;
    var wins_w: u64 = 0;
    var losses_b: u64 = 0;
    var losses_w: u64 = 0;
    var ties_b: u64 = 0;
    var ties_w: u64 = 0;
    var lfc_b: u64 = 0; // losses from claimed-won, Black
    var lfc_w: u64 = 0; // losses from claimed-won, White
    var wnr_b: u64 = 0; // wins from non-claimed roots, Black
    var wnr_w: u64 = 0; // wins from non-claimed roots, White
    var inside_b: u64 = 0;
    var inside_w: u64 = 0;
    var capped_b: u64 = 0;
    var capped_w: u64 = 0;
    var playouts_total_all: u64 = 0;
    var playouts_missing_all: u64 = 0;

    for (openings.items.items, 0..) |*opening, oi| {
        for ([_]i8{ 1, -1 }) |colour| {
            var rec = playGame(io, gpa, a2, engine, opening, oi, colour, null, strong) catch |err| {
                p("t381: game {s}-o{d:0>2}-{s} aborted: {}\n", .{ engine.name, oi, if (colour > 0) "B" else "W", err });
                aborted += 1;
                continue;
            };
            const our_b = rec.our_colour > 0;
            if (rec.capped) {
                capped += 1;
                if (our_b) capped_b += 1 else capped_w += 1;
            }
            classifyAndResolve(&rec);

            // Capped games are reported separately, not counted as W/L/T.
            if (!rec.capped) {
                switch (rec.our_result) {
                    .win => {
                        wins += 1;
                        if (our_b) wins_b += 1 else wins_w += 1;
                        // Q2: wins from roots NOT claimed for us = opponent
                        // error (their blunder, not our claim); should fall as
                        // strength rises.
                        if (!rec.root_claimed_for_us) {
                            if (our_b) wnr_b += 1 else wnr_w += 1;
                        }
                    },
                    .loss => {
                        losses += 1;
                        if (our_b) losses_b += 1 else losses_w += 1;
                    },
                    .tie => {
                        ties += 1;
                        if (our_b) ties_b += 1 else ties_w += 1;
                    },
                }
            }
            switch (rec.finding) {
                .none => {},
                .loss_from_claimed => {
                    loss_from_claimed += 1;
                    if (our_b) lfc_b += 1 else lfc_w += 1;
                },
                .tie_from_claimed => tie_from_claimed += 1,
            }
            if (rec.outcome_inside_root) {
                inside_root += 1;
                if (our_b) inside_b += 1 else inside_w += 1;
            }
            switch (rec.resolution) {
                .none => {},
                .selector => res_selector += 1,
                .ruleset_mismatch => res_ruleset += 1,
                .table_wrong => res_table += 1,
                .unresolved => res_unresolved += 1,
            }
            playouts_total_all += rec.playouts_total;
            playouts_missing_all += rec.playouts_missing;

            var sb: [16]u8 = undefined;
            p("  {s}  {s:>26}  {s:>5}  result={s:>4}  finding={s:>16}  resolution={s:>14}\n", .{
                rec.game_id, opening.name, fmtScore(rec.score, &sb), @tagName(rec.our_result),
                @tagName(rec.finding), @tagName(rec.resolution),
            });

            try games.append(gpa, rec);
        }
    }

    p("t381: {s}: {d} games (wins {d} losses {d} ties {d} aborted {d}) | losses-from-claimed {d} ties-from-claimed {d} | inside-root {d} | capped {d} | playouts-missing {d}\n", .{
        engine.name, games.items.len, wins, losses, ties, aborted, loss_from_claimed, tie_from_claimed, inside_root, capped, playouts_missing_all,
    });
    p("t381: {s} colour split — B: {d}W/{d}L/{d}T lfc={d} wnr={d} inside={d} capped={d} | W: {d}W/{d}L/{d}T lfc={d} wnr={d} inside={d} capped={d}\n", .{
        engine.name, wins_b, losses_b, ties_b, lfc_b, wnr_b, inside_b, capped_b,
        wins_w, losses_w, ties_w, lfc_w, wnr_w, inside_w, capped_w,
    });

    // JSON document.
    var j = Json.init(gpa);
    defer j.deinit();
    try j.raw("{\n\"task_id\":\"T381\",\n\"date\":\"2026-08-05\",\n\"model\":\"deepseek-v4-flash\",\n\"identifier\":\"flash/T381\",\n");
    try j.raw("\"engine\":");
    try j.str(engine.name);
    try j.raw(",\n\"strength\":");
    try j.str(strength_label);
    try j.raw(",\n\"artifact\":");
    try j.str(DEFAULT_ARTIFACT);
    try j.raw(",\n\"openings_total\":");
    try j.num(@intCast(openings.items.items.len));
    try j.raw(",\n\"summary\":{\"games\":");
    try j.num(@intCast(games.items.len));
    try j.raw(",\"aborted\":");
    try j.num(@intCast(aborted));
    try j.raw(",\"wins\":");
    try j.num(@intCast(wins));
    try j.raw(",\"losses\":");
    try j.num(@intCast(losses));
    try j.raw(",\"ties\":");
    try j.num(@intCast(ties));
    try j.raw(",\"losses_from_claimed_won\":");
    try j.num(@intCast(loss_from_claimed));
    try j.raw(",\"ties_from_claimed_won\":");
    try j.num(@intCast(tie_from_claimed));
    try j.raw(",\"outcome_inside_root_bracket\":");
    try j.num(@intCast(inside_root));
    try j.raw(",\"capped\":");
    try j.num(@intCast(capped));
    try j.raw(",\"resolution_selector\":");
    try j.num(@intCast(res_selector));
    try j.raw(",\"resolution_ruleset_mismatch\":");
    try j.num(@intCast(res_ruleset));
    try j.raw(",\"resolution_table_wrong\":");
    try j.num(@intCast(res_table));
    try j.raw(",\"resolution_unresolved\":");
    try j.num(@intCast(res_unresolved));
    // T420 additions: per-colour splits + achieved playouts.
    try j.raw(",\"wins_black\":");
    try j.num(@intCast(wins_b));
    try j.raw(",\"wins_white\":");
    try j.num(@intCast(wins_w));
    try j.raw(",\"losses_black\":");
    try j.num(@intCast(losses_b));
    try j.raw(",\"losses_white\":");
    try j.num(@intCast(losses_w));
    try j.raw(",\"ties_black\":");
    try j.num(@intCast(ties_b));
    try j.raw(",\"ties_white\":");
    try j.num(@intCast(ties_w));
    try j.raw(",\"losses_from_claimed_black\":");
    try j.num(@intCast(lfc_b));
    try j.raw(",\"losses_from_claimed_white\":");
    try j.num(@intCast(lfc_w));
    try j.raw(",\"wins_from_non_claimed_roots_black\":");
    try j.num(@intCast(wnr_b));
    try j.raw(",\"wins_from_non_claimed_roots_white\":");
    try j.num(@intCast(wnr_w));
    try j.raw(",\"inside_root_black\":");
    try j.num(@intCast(inside_b));
    try j.raw(",\"inside_root_white\":");
    try j.num(@intCast(inside_w));
    try j.raw(",\"capped_black\":");
    try j.num(@intCast(capped_b));
    try j.raw(",\"capped_white\":");
    try j.num(@intCast(capped_w));
    try j.raw(",\"playouts_total\":");
    try j.num(@intCast(playouts_total_all));
    try j.raw(",\"playouts_missing\":");
    try j.num(@intCast(playouts_missing_all));
    try j.raw("},\n\"games\":[\n");
    for (games.items, 0..) |*g, i| {
        if (i > 0) try j.raw(",\n");
        try emitGameJson(&j, g);
    }
    try j.raw("\n]}\n");

    var file = try std.Io.Dir.cwd().createFile(io, json_path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, j.buf.items);
    p("t381: wrote {s} ({d} bytes)\n", .{ json_path, j.buf.items.len });
}

// ---------------------------------------------------------------------------
// Ruleset probe: verify the engine's actual rules against ours (Chinese
// area, komi 0, no suicide, basic ko), record the working invocation.
// ---------------------------------------------------------------------------
fn probeEngine(io: std.Io, gpa: std.mem.Allocator, engine: Engine) !void {
    const p = std.debug.print;
    p("t381: ruleset probe for {s} (argv: ", .{engine.name});
    for (engine.argv, 0..) |a, i| {
        if (i > 0) p(" ", .{});
        p("{s}", .{a});
    }
    p(")\n", .{});

    // T420: capture stderr so the strength section can read Pachi's
    // per-move "*** WINNER (A/B games)" summaries. Transparent for the
    // ruleset probes below (they read stdout responses only).
    var client = try GtpClient.spawnWithStderr(io, gpa, engine.argv);
    defer client.deinit();

    const pv = try client.command("protocol_version");
    p("  protocol_version: ok={} value='{s}'\n", .{ pv.ok, pv.value });
    const nm = try client.command("name");
    p("  name: '{s}'\n", .{nm.value});
    const vr = try client.command("version");
    p("  version: '{s}'\n", .{vr.value});
    if (!(try client.setup4x4())) {
        p("  setup4x4 FAILED — engine cannot be configured to 4x4 komi 0; excluded\n", .{});
        return;
    }
    for (engine.setup) |cmd| {
        const r = try client.command(cmd);
        p("  setup '{s}' ok={} value='{s}'\n", .{ cmd, r.ok, r.value });
    }

    // --- ko probe: build a simple-ko shape; the recapture must be illegal.
    // The ko stone B3 is a single Black stone whose only liberty is B2; its
    // other three neighbours (A3, C3, B4) are White, and B2's other
    // neighbours (A2, C2, B1) are Black, so after White plays B2 the
    // capturing White stone has exactly one liberty (B3) — a genuine ko.
    const ko_plays = [_][]const u8{
        "play b A2", "play b C2", "play b B1",
        "play w A3", "play w C3", "play w B4",
        "play b B3",
    };
    var ko_ok = true;
    for (ko_plays) |cp| {
        const r = try client.command(cp);
        if (!r.ok) {
            p("  ko probe: engine rejected setup move '{s}': '{s}'\n", .{ cp, r.value });
            ko_ok = false;
            break;
        }
    }
    if (ko_ok) {
        const al = try client.command("all_legal w");
        p("  ko probe: all_legal w before capture = '{s}'\n", .{al.value});
        const cap = try client.command("play w B2");
        p("  ko probe: play w B2 (capture, creates ko) ok={} value='{s}'\n", .{ cap.ok, cap.value });
        const al2 = try client.command("all_legal b");
        p("  ko probe: all_legal b after capture = '{s}'\n", .{al2.value});
        const has_recapture = std.mem.indexOf(u8, al2.value, "B3") != null or std.mem.indexOf(u8, al2.value, "b3") != null;
        p("  ko probe: B3 (immediate ko recapture) legal? {}  (basic ko requires: no)\n", .{has_recapture});
        // Play-based recapture test — works even when all_legal is unknown.
        const recap = try client.command("play b B3");
        p("  ko probe: play b B3 (immediate recapture) ok={} value='{s}'  (basic ko requires: error)\n", .{ recap.ok, recap.value });
    }

    // --- suicide probe: D4 must be illegal for Black in the given shape.
    _ = try client.command("clear_board");
    const sui_plays = [_][]const u8{
        "play b A1", "play b B1", "play b C1", "play b D1",
        "play b A2", "play b B2", "play b C2", "play b D2",
        "play w A3", "play w B3", "play w C3", "play w D3",
        "play w A4", "play w B4", "play w C4",
    };
    var sui_ok = true;
    for (sui_plays) |cp| {
        const r = try client.command(cp);
        if (!r.ok) {
            p("  suicide probe: engine rejected setup move '{s}': '{s}'\n", .{ cp, r.value });
            sui_ok = false;
            break;
        }
    }
    if (sui_ok) {
        const al = try client.command("all_legal b");
        p("  suicide probe: all_legal b = '{s}'\n", .{al.value});
        const has_d4 = std.mem.indexOf(u8, al.value, "D4") != null or std.mem.indexOf(u8, al.value, "d4") != null;
        p("  suicide probe: D4 (suicide for Black) legal? {}  (our rules require: no)\n", .{has_d4});
        const tryplay = try client.command("play b D4");
        p("  suicide probe: play b D4 ok={} value='{s}'  (our rules require: error)\n", .{ tryplay.ok, tryplay.value });
    }

    // --- final_score sanity on a full board + empty board (document quirks).
    _ = try client.command("clear_board");
    const fs_empty = try client.command("final_score");
    p("  final_score on EMPTY board: '{s}'  (area komi 0 expects 0)\n", .{fs_empty.value});
    const full = [_][]const u8{
        "play b A1", "play b B1", "play b C1", "play b D1",
        "play b A2", "play b B2", "play b C2", "play b D2",
        "play w A3", "play w B3", "play w C3", "play w D3",
        "play w A4", "play w B4", "play w C4", "play w D4",
    };
    for (full) |cp| _ = try client.command(cp);
    const fs_full = try client.command("final_score");
    p("  final_score on fully-occupied board (W has all 16): '{s}'  (area komi 0 expects W+16)\n", .{fs_full.value});

    // --- T420: strength settings actually in effect, per engine.
    p("  --- strength section ---\n", .{});
    if (std.mem.eql(u8, engine.name, "gnugo")) {
        // GNU Go has no GTP-level strength query; level is a startup flag.
        // Documented in --help: "--level <amount>  strength (default 10)";
        // 10 is the maximum (runs 0-10). T381 ran without --level, i.e. at
        // the default 10 — already maximum. No headroom exists.
        p("  gnugo level: 10 (documented default and maximum; --help: '--level <amount> strength (default 10)')\n", .{});
        p("  gnugo headroom: NONE — T381 already ran at max; not re-run per the brief.\n", .{});
    } else if (std.mem.eql(u8, engine.name, "pachi")) {
        // One genmove; read the actual simulation count from stderr.
        var req: []const u8 = "?";
        for (engine.argv, 0..) |a, i| {
            if (std.mem.eql(u8, a, "-t") and i + 1 < engine.argv.len) req = engine.argv[i + 1];
        }
        _ = try client.command("clear_board");
        const gm = try client.command("genmove b");
        client.drainStderr();
        const achieved = pachiLastPlayouts(client.err_buf.items);
        p("  pachi requested -t {s}; move '{s}'\n", .{ req, gm.value });
        if (achieved) |n| {
            p("  pachi ACHIEVED playouts this move: {d}\n", .{n});
        } else {
            p("  pachi ACHIEVED playouts: UNREADABLE (no WINNER line in stderr)\n", .{});
        }
    } else if (std.mem.eql(u8, engine.name, "fuego")) {
        // Configured vs achieved: uct_param_player reports max_games;
        // uct_stat_search reports GamesPlayed for the search just finished.
        const pp = try client.command("uct_param_player");
        const ppc = gpa.dupe(u8, pp.value) catch return error.OutOfMemory;
        defer gpa.free(ppc);
        p("  fuego uct_param_player (configured):\n", .{});
        var it = std.mem.tokenizeAny(u8, ppc, "\n");
        while (it.next()) |line| {
            if (std.mem.indexOf(u8, line, "max_games") != null or std.mem.indexOf(u8, line, "resign_threshold") != null)
                p("    {s}\n", .{line});
        }
        _ = try client.command("clear_board");
        const gm = try client.command("genmove b");
        // gm.value slices into in_buf, which the next command overwrites —
        // copy it before querying uct_stat_search.
        const gm_copy = gpa.dupe(u8, gm.value) catch return error.OutOfMemory;
        defer gpa.free(gm_copy);
        const sr = try client.command("uct_stat_search");
        const played = fuegoGamesPlayed(sr.value);
        p("  fuego move '{s}'; ACHIEVED GamesPlayed: {d}\n", .{ gm_copy, played orelse 0 });
        if (played == null) p("  fuego ACHIEVED GamesPlayed: UNREADABLE\n", .{});
    } else {
        p("  (no strength probe defined for unknown engine '{s}')\n", .{engine.name});
    }

    p("t381: probe done for {s}\n", .{engine.name});
}

// ---------------------------------------------------------------------------
// Null control: replay a completed game's recorded moves through a FRESH
// engine instance (play only, no genmove) and verify the same score, the
// engine accepts every move. Proves the harness is deterministic.
// ---------------------------------------------------------------------------
fn nullControl(io: std.Io, gpa: std.mem.Allocator, engine: Engine, moves: []const u8, expect_score: i8, game_id: []const u8) !void {
    const p = std.debug.print;
    p("t381: null control — replaying {s} through a fresh {s}\n", .{ game_id, engine.name });

    var client = try GtpClient.spawn(io, gpa, engine.argv);
    defer client.deinit();
    if (!(try client.setup4x4())) {
        p("t381: null control FAILED — engine setup\n", .{});
        return error.NullControlFailed;
    }

    var sess = S{ .d = null, .a2 = null, .enforcement = .basic_ko };
    sess.reset();

    var side: i8 = 1;
    var rejected: ?usize = null;
    for (moves, 0..) |m, ply| {
        const cell: ?usize = if (m == 0) null else m - 1;
        sess.applyMove(side, cell) catch {
            p("t381: null control — recorded move at ply {d} illegal under our rules — HARNESS BUG\n", .{ply});
            return error.NullControlFailed;
        };
        const r = try client.play(side, cell);
        if (!r.ok) {
            rejected = ply;
            p("t381: null control — engine rejected replayed move at ply {d}: '{s}'\n", .{ ply, r.value });
            break;
        }
        side = -side;
    }

    const replay_score = R.area_score(&sess.pos);
    const match = replay_score == expect_score;
    p("t381: null control — recorded score {d} vs replay score {d}: {s}\n", .{
        expect_score, replay_score, if (match) "MATCH" else "MISMATCH — HARNESS BUG",
    });
    if (rejected != null) {
        p("t381: null control FAILED — engine rejected ply {d}\n", .{rejected.?});
        return error.NullControlFailed;
    }
    if (!match) {
        p("t381: null control FAILED — score mismatch\n", .{});
        return error.NullControlFailed;
    }
    const fs = client.finalScore();
    p("t381: null control — engine final_score on replayed position: '{s}'\n", .{fs});
    p("t381: null control PASSED — deterministic replay, identical score\n", .{});
}

// ---------------------------------------------------------------------------
// Self-score authority replay: recompute the score of a recorded game's
// moves with NO engine (used to demonstrate the score is a pure function of
// the position).
// ---------------------------------------------------------------------------
fn selfScore(moves: []const u8) i8 {
    var sess = S{ .d = null, .a2 = null, .enforcement = .basic_ko };
    sess.reset();
    var side: i8 = 1;
    for (moves) |m| {
        const cell: ?usize = if (m == 0) null else m - 1;
        sess.applyMove(side, cell) catch unreachable;
        side = -side;
    }
    return R.area_score(&sess.pos);
}

// ---------------------------------------------------------------------------
// Minimal JSON reader for the recorded games (used by --nullctl /
// --selfscore). The instrument's JSON emits moves as 'a'-based SGF-style
// vertices (top-left origin, matching T366); this parser matches that.
// ---------------------------------------------------------------------------
const LoadedGame = struct {
    moves: std.ArrayListUnmanaged(u8) = .empty,
    score: i8 = 0,
};

fn loadGameFromJson(io: std.Io, gpa: std.mem.Allocator, path: []const u8, want_id: []const u8) !LoadedGame {
    const data = try std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .unlimited);
    defer gpa.free(data);

    var pos: usize = 0;
    while (std.mem.indexOfPos(u8, data, pos, "\"game_id\":\"")) |gi| {
        const id_start = gi + "\"game_id\":\"".len;
        const id_end = std.mem.indexOfPos(u8, data, id_start, "\"") orelse return error.BadJson;
        const gid = data[id_start..id_end];
        if (std.mem.eql(u8, gid, want_id)) {
            // Object extends to the next "\"game_id\":" or the games-array end.
            const obj_end = if (std.mem.indexOfPos(u8, data, id_end + 1, "\"game_id\":")) |ng|
                ng
            else if (std.mem.indexOfPos(u8, data, id_end, "\n]")) |oe|
                oe
            else
                data.len;
            const obj = data[gi..obj_end];
            var out = LoadedGame{};
            out.score = extractInt(obj, "score") orelse 0;
            try extractMoves(gpa, obj, &out.moves);
            return out;
        }
        pos = gi + 1;
    }
    return error.GameNotFound;
}

fn extractInt(obj: []const u8, key: []const u8) ?i8 {
    var keybuf: [64]u8 = undefined;
    const pat = std.fmt.bufPrint(&keybuf, "\"{s}\":", .{key}) catch unreachable;
    const si = std.mem.indexOf(u8, obj, pat) orelse return null;
    var start = si + pat.len;
    const is_neg = start < obj.len and obj[start] == '-';
    if (is_neg) start += 1;
    const num_start = start;
    while (start < obj.len and obj[start] >= '0' and obj[start] <= '9') start += 1;
    if (start == num_start) return null;
    const num = obj[si + pat.len .. start];
    const v = std.fmt.parseInt(i16, num, 10) catch return null;
    return @intCast(v);
}

/// Parse the "moves":[...] array (SGF-style vertices, 'aa' = top-left).
fn extractMoves(gpa: std.mem.Allocator, obj: []const u8, out: *std.ArrayListUnmanaged(u8)) !void {
    const pat = "\"moves\":[";
    const si = std.mem.indexOf(u8, obj, pat) orelse return error.BadJson;
    const arr_end = std.mem.indexOfPos(u8, obj, si + pat.len, "]") orelse return error.BadJson;
    const arr = obj[si + pat.len .. arr_end];
    var it = std.mem.tokenizeAny(u8, arr, " \t\r\n,");
    while (it.next()) |tok| {
        const t = std.mem.trim(u8, tok, " \t\r\n\"");
        if (std.mem.eql(u8, t, "pass")) {
            try out.append(gpa, 0);
        } else if (t.len == 2 and t[0] >= 'a' and t[0] <= 'd' and t[1] >= 'a' and t[1] <= 'd') {
            const col: usize = t[0] - 'a';
            const row: usize = t[1] - 'a';
            try out.append(gpa, @intCast(row * W + col + 1));
        } else {
            return error.BadJson;
        }
    }
}

// ---------------------------------------------------------------------------
// main
// ---------------------------------------------------------------------------
pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa = std.heap.page_allocator;

    var engine_name: []const u8 = "gnugo";
    var artifact_path: []const u8 = DEFAULT_ARTIFACT;
    var json_path: []const u8 = DEFAULT_JSON;
    var openings_count: usize = 30;
    var seed: u64 = 42;
    var canonical = true;
    var include_empty = true;
    var strong = false; // T420: full-strength engine configs + per-move playout recording
    var mode: enum { run, probe, nullctl, seedctl, selfscore } = .run;
    var nullctl_game: ?[]const u8 = null;
    var seedctl_game: ?[]const u8 = null;
    var seedctl_ply: ?usize = null;
    var seedctl_move: ?[]const u8 = null; // vertex or "pass"

    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    while (args.next()) |a| {
        if (std.mem.eql(u8, a, "--engine")) engine_name = args.next() orelse "gnugo"
        else if (std.mem.eql(u8, a, "--artifact")) artifact_path = args.next() orelse DEFAULT_ARTIFACT
        else if (std.mem.eql(u8, a, "--json")) json_path = args.next() orelse DEFAULT_JSON
        else if (std.mem.eql(u8, a, "--openings")) openings_count = std.fmt.parseInt(usize, args.next() orelse "30", 10) catch 30
        else if (std.mem.eql(u8, a, "--seed")) seed = std.fmt.parseInt(u64, args.next() orelse "42", 10) catch 42
        else if (std.mem.eql(u8, a, "--no-canonical")) canonical = false
        else if (std.mem.eql(u8, a, "--no-empty")) include_empty = false
        else if (std.mem.eql(u8, a, "--strong")) strong = true
        else if (std.mem.eql(u8, a, "--probe")) mode = .probe
        else if (std.mem.eql(u8, a, "--nullctl")) {
            mode = .nullctl;
            nullctl_game = args.next();
        } else if (std.mem.eql(u8, a, "--seedctl")) {
            mode = .seedctl;
            seedctl_game = args.next();
            seedctl_ply = std.fmt.parseInt(usize, args.next() orelse "0", 10) catch 0;
            seedctl_move = args.next();
        } else if (std.mem.eql(u8, a, "--selfscore")) {
            mode = .selfscore;
            nullctl_game = args.next();
        } else {
            std.debug.print("unknown argument '{s}'\n", .{a});
            return;
        }
    }

    std.debug.print("{s}\n", .{version.banner("weizigo-t381-evse")});

    const engine = if (strong) engineForStrong(engine_name) else engineFor(engine_name);

    if (mode == .probe) {
        if (strong) std.debug.print("t381: --strong probe: full-strength config\n", .{});
        try probeEngine(io, gpa, engine);
        return;
    }

    // Load the oracle artifact.
    var a2 = artifact2.load(io, std.Io.Dir.cwd(), artifact_path, gpa) catch |err| {
        std.debug.print("error: cannot load artifact '{s}': {t}\n", .{ artifact_path, err });
        return;
    };
    defer a2.deinit();

    if (a2.header.w != W or a2.header.h != H) {
        std.debug.print("error: artifact must be {d}x{d} (got {d}x{d})\n", .{ W, H, a2.header.w, a2.header.h });
        return;
    }
    std.debug.print("artifact: {s} ({d}x{d}, rules_id={d} {s})\n", .{
        artifact_path, a2.header.w, a2.header.h,
        artifact2.RULES_BASICKO_LH_AREA, artifact2.rulesName(artifact2.RULES_BASICKO_LH_AREA),
    });

    if (mode == .nullctl or mode == .selfscore) {
        const gid = nullctl_game orelse {
            std.debug.print("error: this mode requires a game id\n", .{});
            return;
        };
        var loaded = loadGameFromJson(io, gpa, json_path, gid) catch |err| {
            std.debug.print("error: cannot load game {s} from {s}: {}\n", .{ gid, json_path, err });
            return;
        };
        defer loaded.moves.deinit(gpa);
        if (mode == .nullctl) {
            try nullControl(io, gpa, engine, loaded.moves.items, loaded.score, gid);
        } else {
            const sc = selfScore(loaded.moves.items);
            std.debug.print("t381: selfscore {s} = {d} (recorded {d})\n", .{ gid, sc, loaded.score });
        }
        return;
    }

    var openings = try buildOpenings(gpa, openings_count, seed, canonical, include_empty);
    defer openings.names.deinit(gpa);
    defer openings.items.deinit(gpa);
    std.debug.print("openings: {d} ({d} canonical + {d} random + {s})\n", .{
        openings.items.items.len,
        if (canonical) @as(usize, 3) else 0,
        openings_count,
        if (include_empty) "empty" else "no-empty",
    });

    // Seedctl mode: build the injection and run only the target game.
    if (mode == .seedctl) {
        const gid = seedctl_game orelse {
            std.debug.print("error: --seedctl requires a game id\n", .{});
            return;
        };
        const ply = seedctl_ply orelse {
            std.debug.print("error: --seedctl requires a ply\n", .{});
            return;
        };
        const mv = seedctl_move orelse {
            std.debug.print("error: --seedctl requires a move (vertex or pass)\n", .{});
            return;
        };
        var cell_plus: u8 = 0;
        if (!std.mem.eql(u8, mv, "pass")) {
            cell_plus = @intCast((gtp.cell_from_vertex(mv, W, H) orelse {
                std.debug.print("error: --seedctl bad vertex '{s}'\n", .{mv});
                return;
            }) + 1);
        }
        const inject = Inject{ .ply = ply, .cell_plus = cell_plus };

        var found = false;
        for (openings.items.items, 0..) |*opening, oi| {
            for ([_]i8{ 1, -1 }) |colour| {
                var idbuf: [96]u8 = undefined;
                const gid2 = std.fmt.bufPrint(&idbuf, "{s}-o{d:0>2}-{s}", .{
                    engine.name, oi, if (colour > 0) "B" else "W",
                }) catch unreachable;
                if (!std.mem.eql(u8, gid2, gid)) continue;
                found = true;
                var rec = try playGame(io, gpa, &a2, engine, opening, oi, colour, &inject, strong);
                defer {
                    rec.moves.deinit(gpa);
                    rec.our_positions.deinit(gpa);
                    rec.engine_playouts.deinit(gpa); // T420
                    gpa.free(rec.game_id);
                    gpa.free(rec.engine_final_score);
                }
                classifyAndResolve(&rec);
                var sb: [16]u8 = undefined;
                std.debug.print("t381: seedctl game {s}: result {s} our_result {s} finding {s} resolution {s} outcome_inside_root {}\n", .{
                    gid, fmtScore(rec.score, &sb), @tagName(rec.our_result), @tagName(rec.finding), @tagName(rec.resolution), rec.outcome_inside_root,
                });
                for (rec.our_positions.items) |op| {
                    var vbuf: [4]u8 = undefined;
                    std.debug.print("  ply {d}: L={d} H={d} claimed={} move={s} chosen_value={d} extremum={d} optimal={}\n", .{
                        op.ply, op.L, op.H, op.claimed_for_us,
                        if (op.chosen == 0) "pass" else vertex(op.chosen - 1, &vbuf),
                        op.chosen_value, op.extremum, op.optimal,
                    });
                }
            }
        }
        if (!found) std.debug.print("error: game {s} not found\n", .{gid});
        return;
    }

    // Normal run.
    try runEngine(io, gpa, &a2, engine, &openings, json_path, strong);
}
