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
// GTP ORACLE PLAYER — play against a persisted perfect oracle (ADR-0011).
//
//   zig build-exe -O ReleaseFast src/gtp.zig && ./gtp artifacts/oracle-3x3.wzo
//
// Speaks enough GTP (Go Text Protocol v2) for Sabaki / gogui / gogui-twogtp:
// board size comes from the artifact header and is not negotiable. Move
// choice per (position, side): among PSK-legal moves (and pass), maximize
// (Black) / minimize (White) the stored fresh-start child value; break value
// ties by smallest child DTT (resolve fast). The pass edge at passes=0 leads
// to a V1 node the artifact does not store; it is recomputed as one ply of
// V0 lookups (the ADR-0009 Bellman equation).
//
// HONESTY (the GHI ko-sensitive region, ADR-0009/0010): stored values are FRESH-START
// values. In a real game with history, superko bans can make the true
// optimum differ on KO_SENSITIVE positions. This player filters PSK-illegal
// moves against the actual game history and otherwise plays the fresh-start
// optimum; when the achievable choice differs from the stored value, or the
// node is flagged KO_SENSITIVE, it says so on stderr. Perfect for smoke
// testing; ko-fight play is "fresh-start perfect", not "history perfect".
//
// Values assume komi 0 and Chinese/area scoring; `final_score` subtracts the
// GUI's komi from the exact area score (score-optimal play is komi-agnostic).

const std = @import("std");
const rules = @import("rules.zig");
const colexmod = @import("colex.zig");
const artifact = @import("artifact.zig");
const score = @import("score.zig");

const COLS = "ABCDEFGHJKLMNOPQRSTUVWXYZ"; // GTP letters, no 'I'
const MAX_HIST = 4096;

/// Sentinel stored in unfilled artifact slots (2-ko+ positions on the 4x4
/// parallel artifact). The GTP player must NEVER treat this as a real score:
/// -128 is catastrophic as a fresh-start value (B39: 144-pt leaks). When a
/// child's stored value is UNDEF, that move is dropped from consideration
/// and the engine falls back to pass or another filled child.
pub const UNDEF: i8 = -128;

pub fn Session(comptime w: usize, comptime h: usize) type {
    return struct {
        const S = @This();
        const R = rules.Rules(w, h);
        const X = colexmod.Indexer(w, h);
        const Score = score.Score(w, h);
        const n = R.n;
        const Pos = R.Pos;

        d: *const artifact.Decoded,
        pos: Pos = [_]i8{0} ** n,
        hist: [MAX_HIST]Pos = undefined,
        hist_len: usize = 0,
        passes: u8 = 0,
        komi: f32 = 0,

        pub fn reset(s: *S) void {
            s.pos = [_]i8{0} ** n;
            s.hist_len = 0;
            s.passes = 0;
            // the initial position has occurred: recreating it (capturing
            // everything back to an empty board) is PSK-illegal
            s.push(&s.pos);
        }

        pub fn v0(s: *const S, pos: *const Pos, side: i8) i8 {
            const i: usize = @intCast(X.colex_from_pos(pos));
            return if (side > 0) s.d.vb[i] else s.d.vw[i];
        }
        pub fn dtt0(s: *const S, pos: *const Pos, side: i8) u8 {
            const i: usize = @intCast(X.colex_from_pos(pos));
            return if (side > 0) s.d.db[i] else s.d.dw[i];
        }
        pub fn flags0(s: *const S, pos: *const Pos, side: i8) u8 {
            const i: usize = @intCast(X.colex_from_pos(pos));
            return if (side > 0) s.d.fb[i] else s.d.fw[i];
        }

        pub fn seen(s: *const S, pos: *const Pos) bool {
            for (s.hist[0..s.hist_len]) |*b| {
                if (std.mem.eql(i8, b, pos)) return true;
            }
            return false;
        }

        pub fn push(s: *S, pos: *const Pos) void {
            if (s.hist_len >= MAX_HIST) @panic("gtp: game line exceeded MAX_HIST");
            s.hist[s.hist_len] = pos.*;
            s.hist_len += 1;
        }

        /// V1(pos, side) = value when `side` moves facing one standing pass:
        /// any move -> stored V0(child, -side); pass -> game ends, score now.
        /// One ply of table lookups (the artifact stores V0 only).
        /// Children whose slot is UNDEF (2-ko+ unfilled) are skipped — the
        /// pass value (area_score) stands as the fallback.
        pub fn v1_from_table(s: *const S, pos: *const Pos, side: i8) i8 {
            const maximizing = side > 0;
            var best: i8 = R.area_score(pos); // the ending pass
            for (0..n) |p| {
                if (pos[p] != 0) continue;
                const child = R.pos_from_move(pos, side, p) catch continue;
                const v = s.v0(&child, -side);
                if (v == UNDEF) continue; // unfilled slot — fall back to pass/other moves
                if (if (maximizing) v > best else v < best) best = v;
            }
            return best;
        }

        const Choice = struct { cell: ?usize, value: i8, dtt: u8 };

        /// Best move (or pass) for `side` from the current game state:
        /// fresh-start-optimal among PSK-legal options, value ties broken by
        /// smallest DTT.
        ///
        /// PASS POLICY (user spec): pass only if (a) pass is STRICTLY best —
        /// every legal move is worse, not merely tied — (b) at least one stone
        /// has been played, and (c) passing does not concede a loss. The engine
        /// TRIES TO WIN: it does not pass out a losing position (that would
        /// assume the opponent plays optimally), and it never passes before a
        /// stone is on the board. Ties and losing positions both go to a move;
        /// the engine plays on. Resign (impossible-to-win) is handled by the
        /// caller before choose runs.
        pub fn choose(s: *const S, side: i8) Choice {
            const maximizing = side > 0;
            const pass_value: i8 = if (s.passes >= 1) R.area_score(&s.pos) else s.v1_from_table(&s.pos, -side);
            const pass_dtt: u8 = if (s.passes >= 1) 0 else 1;
            var best_move: ?Choice = null;
            for (0..n) |p| {
                if (s.pos[p] != 0) continue;
                const child = R.pos_from_move(&s.pos, side, p) catch continue;
                if (s.seen(&child)) continue; // positional superko
                const v = s.v0(&child, -side);
                if (v == UNDEF) continue; // unfilled slot (2-ko+): skip, fall back to pass/other moves
                const dt = s.dtt0(&child, -side);
                const mv = Choice{ .cell = p, .value = v, .dtt = dt };
                if (best_move) |bm| {
                    const better = if (maximizing) v > bm.value else v < bm.value;
                    if (better or (v == bm.value and dt < bm.dtt)) best_move = mv;
                } else {
                    best_move = mv;
                }
            }
            if (best_move) |bm| {
                const pass_strictly_better = if (maximizing) pass_value > bm.value else pass_value < bm.value;
                const pass_loses = if (maximizing) pass_value < 0 else pass_value > 0;
                const any = S.anyStone(&s.pos);
                if (pass_strictly_better and any and !pass_loses) {
                    return .{ .cell = null, .value = pass_value, .dtt = pass_dtt };
                }
                return bm; // move strictly better, ties pass, no stone yet, or pass would lose -> play on
            }
            // no legal move (full board / all children UNDEF or PSK-banned):
            // passing is the only option; a lost settled board is resigned by
            // the caller before we get here.
            return .{ .cell = null, .value = pass_value, .dtt = pass_dtt };
        }

        fn anyStone(pos: *const Pos) bool {
            for (pos) |x| if (x != 0) return true;
            return false;
        }

        pub fn applyMove(s: *S, side: i8, cell: ?usize) !void {
            if (cell) |p| {
                const child = try R.pos_from_move(&s.pos, side, p);
                s.pos = child;
                s.push(&child);
                s.passes = 0;
            } else {
                s.passes += 1;
            }
        }
    };
}

// ---- vertex <-> cell (GTP: column letters skip I, row 1 = bottom) -----------

pub fn vertex_from_cell(buf: []u8, cell: usize, w: usize, h: usize) []u8 {
    const col = cell % w;
    const row_from_top = cell / w;
    const row_num = h - row_from_top;
    return std.fmt.bufPrint(buf, "{c}{d}", .{ COLS[col], row_num }) catch unreachable;
}

pub fn cell_from_vertex(token: []const u8, w: usize, h: usize) ?usize {
    if (token.len < 2) return null;
    const letter = std.ascii.toUpper(token[0]);
    const col = std.mem.indexOfScalar(u8, COLS, letter) orelse return null;
    const row_num = std.fmt.parseInt(usize, token[1..], 10) catch return null;
    if (col >= w or row_num < 1 or row_num > h) return null;
    return (h - row_num) * w + col;
}

/// Parse "NxN" or "NxM" board-size shorthand. Returns .{w, h} or null.
fn parseBoardSize(s: []const u8) ?[2]usize {
    const x = std.mem.indexOfScalar(u8, s, 'x') orelse return null;
    const w = std.fmt.parseInt(usize, s[0..x], 10) catch return null;
    const h = std.fmt.parseInt(usize, s[x + 1 ..], 10) catch return null;
    if (w == 0 or h == 0 or w > 25 or h > 25) return null;
    return .{ w, h };
}

// ---- score-report formatting helpers ----------------------------------------

fn fmtAreaCounts(buf: []u8, area: i8, dame_count: usize, board_n: usize) []u8 {
    const neutral: i16 = @intCast(dame_count);
    const a: i16 = @intCast(area);
    const nn: i16 = @intCast(board_n);
    const black = @divTrunc(a + nn - neutral, 2);
    const white = @divTrunc(nn - neutral - a, 2);
    return std.fmt.bufPrint(buf, "B+{d} / W+{d} (area)", .{ black, white }) catch unreachable;
}

fn fmtTerritory(buf: []u8, terr: anytype) []u8 {
    return std.fmt.bufPrint(buf, "territory B+{d}/W+{d}", .{ terr.black, terr.white }) catch unreachable;
}

fn fmtDame(buf: []u8, count: usize) []u8 {
    return std.fmt.bufPrint(buf, "dame {d}", .{count}) catch unreachable;
}

fn fmtDead(buf: []u8, dead: anytype) []u8 {
    return std.fmt.bufPrint(buf, "dead B+{d}/W+{d}", .{ dead.dead_black_count, dead.dead_white_count }) catch unreachable;
}

fn fmtVertexList(buf: []u8, points: []const usize, w_arg: usize, h_arg: usize) []u8 {
    if (points.len == 0) return std.fmt.bufPrint(buf, "none", .{}) catch unreachable;
    var off: usize = 0;
    for (points, 0..) |p, k| {
        if (k != 0) {
            buf[off] = ',';
            off += 1;
            buf[off] = ' ';
            off += 1;
        }
        const v = vertex_from_cell(buf[off..], p, w_arg, h_arg);
        off += v.len;
    }
    return buf[0..off];
}

/// One artefact load + log setup + dispatch. Shared by main (explicit path
/// or shorthand) and deferred mode (boardsize-triggered).
fn loadAndDispatch(io: std.Io, gpa: std.mem.Allocator, path: []const u8, opt_log_dir: ?[]const u8) !void {
    var dec = artifact.load(io, std.Io.Dir.cwd(), path, gpa) catch |err| {
        std.debug.print("weizigo-oracle: cannot load artifact '{s}': {t}\n" ++
            "  hint: when launching from a GUI, pass an ABSOLUTE path to the .wzo file\n", .{ path, err });
        return err;
    };
    defer dec.deinit();
    std.debug.print("weizigo-oracle: {s} ({d}x{d}, {d} legal/side)\n", .{
        path, dec.header.board_w, dec.header.board_h, dec.header.legal_count,
    });

    const artifact_dir = std.fs.path.dirname(path) orelse ".";
    const log_dir = opt_log_dir orelse try std.fmt.allocPrint(gpa, "{s}/../log", .{artifact_dir});
    const dir = std.Io.Dir.cwd();
    const log_file: ?std.Io.File = blk: {
        dir.createDirPath(io, log_dir) catch break :blk null;
        const log_path = try std.fmt.allocPrint(gpa, "{s}/weizigo-{d}.log", .{ log_dir, unix_seconds() });
        const f = dir.createFile(io, log_path, .{}) catch break :blk null;
        std.debug.print("weizigo-oracle: transcript -> {s}\n", .{log_path});
        break :blk f;
    };
    const log = LogSink{ .io = io, .file = log_file };
    log.line("# weizigo-oracle session, artifact {s} ({d}x{d}), unix time {d}", .{
        path, dec.header.board_w, dec.header.board_h, unix_seconds(),
    });

    const key = @as(usize, dec.header.board_w) * 100 + dec.header.board_h;
    switch (key) {
        202 => try runSession(2, 2, gpa, &dec, &log, &[_]u8{}),
        302 => try runSession(3, 2, gpa, &dec, &log, &[_]u8{}),
        303 => try runSession(3, 3, gpa, &dec, &log, &[_]u8{}),
        403 => try runSession(4, 3, gpa, &dec, &log, &[_]u8{}),
        404 => try runSession(4, 4, gpa, &dec, &log, &[_]u8{}),
        603 => try runSession(6, 3, gpa, &dec, &log, &[_]u8{}),
        505 => try runSession(5, 5, gpa, &dec, &log, &[_]u8{}),
        else => {
            std.debug.print("unsupported artifact board {d}x{d}\n", .{ dec.header.board_w, dec.header.board_h });
            return error.UnsupportedBoard;
        },
    }
}

// ---- session transcript log ---------------------------------------------------

/// Line-flushed transcript of the whole session (commands, responses, oracle
/// diagnostics) so every game against a human is preserved for the review /
/// arena pipeline. Null file = logging disabled (open failure is not fatal).
fn unix_seconds() i64 {
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(.REALTIME, &ts);
    return ts.sec;
}

const LogSink = struct {
    io: std.Io,
    file: ?std.Io.File,

    fn line(l: *const LogSink, comptime fmt: []const u8, args: anytype) void {
        if (l.file) |f| {
            var buf: [4096]u8 = undefined;
            const s = std.fmt.bufPrint(&buf, fmt ++ "\n", args) catch return;
            f.writeStreamingAll(l.io, s) catch {};
        }
    }
};

// ---- GTP main loop -----------------------------------------------------------

const KNOWN_COMMANDS = [_][]const u8{
    "protocol_version", "name",        "version",  "known_command", "list_commands",
    "boardsize",        "rectangular_boardsize",    "clear_board",   "komi",
    "play",             "genmove",     "undo",     "showboard",     "final_score",
    "weizigo_settled",  "weizigo_estimate", "weizigo_score",
    "quit",
};

fn runSession(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator, dec: *const artifact.Decoded, log: *const LogSink, pre: []const u8) !void {
    const S = Session(w, h);
    var s = S{ .d = dec };

    var threaded = std.Io.Threaded.init(gpa, .{});
    const io = threaded.io();
    const stdin = std.Io.File.stdin();
    const stdout = std.Io.File.stdout();

    var in_buf: [4096]u8 = undefined;
    var line: std.ArrayList(u8) = .empty;
    defer line.deinit(gpa);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);
    var vbuf: [8]u8 = undefined;
    var sbuf: [4096]u8 = undefined;

    var pre_pos: usize = 0;

    while (true) {
        const buf: []const u8 = if (pre_pos < pre.len) blk: {
            const slice = pre[pre_pos..];
            pre_pos = pre.len;
            break :blk slice;
        } else blk: {
            const got = stdin.readStreaming(io, &.{&in_buf}) catch 0;
            if (got == 0) break; // EOF
            break :blk in_buf[0..got];
        };
        for (buf) |ch| {
            if (ch != '\n') {
                try line.append(gpa, ch);
                continue;
            }
            // ---- one GTP command line ----
            log.line("< {s}", .{std.mem.trim(u8, line.items, " \t\r")});
            var tokens = std.mem.tokenizeAny(u8, line.items, " \t\r");
            line.clearRetainingCapacity();
            var first = tokens.next() orelse continue;
            var id: []const u8 = "";
            if (first.len > 0 and std.ascii.isDigit(first[0])) {
                id = first;
                first = tokens.next() orelse continue;
            }
            out.clearRetainingCapacity();
            var quit = false;
            var ok = true;
            var reply: []const u8 = "";
            var rbuf: [512]u8 = undefined;

            if (std.mem.eql(u8, first, "protocol_version")) {
                reply = "2";
            } else if (std.mem.eql(u8, first, "name")) {
                reply = "weizigo-oracle";
            } else if (std.mem.eql(u8, first, "version")) {
                reply = std.fmt.bufPrint(&rbuf, "{d}x{d}-wzo1", .{ w, h }) catch unreachable;
            } else if (std.mem.eql(u8, first, "known_command")) {
                const q = tokens.next() orelse "";
                reply = "false";
                for (KNOWN_COMMANDS) |c| {
                    if (std.mem.eql(u8, c, q)) reply = "true";
                }
            } else if (std.mem.eql(u8, first, "list_commands")) {
                var lb: [256]u8 = undefined;
                var ll: usize = 0;
                for (KNOWN_COMMANDS, 0..) |c, k| {
                    if (k != 0) {
                        lb[ll] = '\n';
                        ll += 1;
                    }
                    @memcpy(lb[ll .. ll + c.len], c);
                    ll += c.len;
                }
                @memcpy(rbuf[0..ll], lb[0..ll]);
                reply = rbuf[0..ll];
            } else if (std.mem.eql(u8, first, "boardsize") or std.mem.eql(u8, first, "rectangular_boardsize")) {
                // Square GTP is "boardsize N"; for non-square boards Sabaki
                // sends "rectangular_boardsize W H" (and detects support via
                // known_command, so it MUST be listed). Either way: first token
                // = width, optional second = height (defaults to width). The
                // board is fixed by the artifact; accept only an exact match.
                const q = tokens.next() orelse "";
                const want_w = std.fmt.parseInt(usize, q, 10) catch 0;
                const q2 = tokens.next();
                const want_h = if (q2) |s2| (std.fmt.parseInt(usize, s2, 10) catch 0) else want_w;
                if (want_w == w and want_h == h) {
                    s.reset();
                } else {
                    ok = false;
                    reply = "unacceptable size";
                }
            } else if (std.mem.eql(u8, first, "clear_board")) {
                s.reset();
            } else if (std.mem.eql(u8, first, "komi")) {
                const q = tokens.next() orelse "0";
                s.komi = std.fmt.parseFloat(f32, q) catch 0;
            } else if (std.mem.eql(u8, first, "play")) {
                const colort = tokens.next() orelse "";
                const vert = tokens.next() orelse "";
                const side: i8 = if (colort.len > 0 and (colort[0] == 'b' or colort[0] == 'B')) 1 else -1;
                if (std.ascii.eqlIgnoreCase(vert, "pass")) {
                    s.applyMove(side, null) catch {};
                } else if (cell_from_vertex(vert, w, h)) |cell| {
                    // enforce OUR rules regardless of the GUI: positional
                    // superko — no whole-board position may ever recur
                    const child = S.R.pos_from_move(&s.pos, side, cell) catch null;
                    if (child != null and s.seen(&child.?)) {
                        ok = false;
                        reply = "illegal move (positional superko)";
                    } else {
                        s.applyMove(side, cell) catch {
                            ok = false;
                            reply = "illegal move";
                        };
                    }
                } else {
                    ok = false;
                    reply = "invalid vertex";
                }
            } else if (std.mem.eql(u8, first, "genmove")) {
                const colort = tokens.next() orelse "";
                const side: i8 = if (colort.len > 0 and (colort[0] == 'b' or colort[0] == 'B')) 1 else -1;
                if (s.passes >= 2) {
                    reply = "pass";
                    std.debug.print("oracle: {s} -> pass  (two consecutive passes)\n", .{colort});
                    log.line("# oracle {s} -> pass  (two consecutive passes)", .{colort});
                } else {
                    const stored = s.v0(&s.pos, side);
                    const undef = stored == UNDEF; // unfilled slot (2-ko+ parallel artifact)
                    // POLICY: resign only when it is IMPOSSIBLE to win — the board
                    // is settled (is_settled: all stones Benson-alive, no dame, no
                    // dead stones) and the area score is against us. A settled-
                    // against position cannot be improved by any move (only
                    // self-eye-fills, which hurt), so winning is impossible no
                    // matter how the opponent plays. PROVEN sound. We never resign
                    // on a bare bad fresh-start value — that assumed OPTIMAL
                    // opponent play and conceded games the opponent might still
                    // throw away (the B40-era White-resigns-after-two-stones
                    // bug). The engine plays on and tries to win until the
                    // position is truly decided. area_score is a pure board
                    // function (table-independent), so this is sound even on
                    // UNDEF slots.
                    const settled = S.Score.is_definitive(&s.pos);
                    const area_now: i8 = S.R.area_score(&s.pos);
                    const behind = if (side > 0) area_now < 0 else area_now > 0;
                    if (settled and behind) {
                        reply = "resign";
                        std.debug.print("oracle: {s} -> resign  settled, area={d} (impossible to win)\n", .{ colort, area_now });
                        log.line("# oracle {s} -> resign  settled, area={d} (impossible to win)", .{ colort, area_now });
                    } else {
                        const fl = s.flags0(&s.pos, side);
                        const c = s.choose(side);
                        s.applyMove(side, c.cell) catch {};
                        reply = if (c.cell) |cell| vertex_from_cell(&vbuf, cell, w, h) else "pass";
                        const diverged = !undef and c.value != stored;
                        std.debug.print("oracle: {s} -> {s}  child-value={d} stored-v0={d}{s}{s}{s} dtt={d}\n", .{
                            colort,                reply,                       c.value, stored,
                            if (undef) " (UNDEF slot)" else "",
                            if (diverged) " (HISTORY-DIVERGED)" else "",
                            if (fl & 1 != 0) " KO_SENSITIVE" else "",         c.dtt,
                        });
                        log.line("# oracle {s} -> {s}  child-value={d} stored-v0={d}{s}{s}{s} dtt={d}", .{
                            colort,                reply,                       c.value, stored,
                            if (undef) " (UNDEF slot)" else "",
                            if (diverged) " (HISTORY-DIVERGED)" else "",
                            if (fl & 1 != 0) " KO_SENSITIVE" else "",         c.dtt,
                        });
                    }
                }
            } else if (std.mem.eql(u8, first, "undo")) {
                ok = false;
                reply = "cannot undo"; // no snapshot stack; keep the oracle simple
            } else if (std.mem.eql(u8, first, "showboard")) {
                var bb: [512]u8 = undefined;
                var bl: usize = 0;
                // start the block on its own line: the "= " response prefix
                // must not indent the first board row
                bb[bl] = '\n';
                bl += 1;
                for (0..h) |r| {
                    for (0..w) |cx| {
                        const cell = s.pos[r * w + cx];
                        bb[bl] = if (cell > 0) 'X' else if (cell < 0) 'O' else '.';
                        bl += 1;
                        bb[bl] = ' ';
                        bl += 1;
                    }
                    bb[bl] = '\n';
                    bl += 1;
                }
                @memcpy(rbuf[0..bl], bb[0..bl]);
                reply = rbuf[0..bl];
            } else if (std.mem.eql(u8, first, "final_score")) {
                const raw: f32 = @floatFromInt(S.R.area_score(&s.pos));
                const sc = raw - s.komi;
                reply = if (sc > 0)
                    std.fmt.bufPrint(&rbuf, "B+{d}", .{sc}) catch unreachable
                else if (sc < 0)
                    std.fmt.bufPrint(&rbuf, "W+{d}", .{-sc}) catch unreachable
                else
                    "0";
                const report = S.Score.make_report(&s.pos);
                if (!report.definitive) {
                    std.debug.print("oracle final_score: provisional (dame {d}, contested chains {d}, dead stones counted as alive)\n", .{
                        report.dame.count, report.dead.contested,
                    });
                    log.line("# oracle final_score: provisional (dame {d}, contested chains {d}, dead stones counted as alive)", .{
                        report.dame.count, report.dead.contested,
                    });
                }
            } else if (std.mem.eql(u8, first, "weizigo_settled")) {
                reply = if (S.Score.is_definitive(&s.pos)) "yes" else "no";
            } else if (std.mem.eql(u8, first, "weizigo_estimate")) {
                const report = S.Score.make_report(&s.pos);
                const area_s = fmtAreaCounts(&sbuf, report.area, report.dame.count, S.n);
                const terr_s = fmtTerritory(sbuf[area_s.len..], report.territory);
                const dame_s = fmtDame(sbuf[area_s.len + terr_s.len ..], report.dame.count);
                const dead_s = fmtDead(sbuf[area_s.len + terr_s.len + dame_s.len ..], report.dead);
                const status = if (report.definitive) "definitive" else "provisional";
                reply = std.fmt.bufPrint(&rbuf, "{s}, {s}, {s}, {s}, {s}", .{
                    area_s, terr_s, dame_s, dead_s, status,
                }) catch unreachable;
            } else if (std.mem.eql(u8, first, "weizigo_score")) {
                const report = S.Score.make_report(&s.pos);
                const status = if (report.definitive) "definitive" else "provisional";
                var off: usize = 0;
                const area_s = fmtAreaCounts(sbuf[off..], report.area, report.dame.count, S.n);
                off += area_s.len;
                sbuf[off] = '\n';
                off += 1;
                const terr_s = fmtTerritory(sbuf[off..], report.territory);
                off += terr_s.len;
                sbuf[off] = '\n';
                off += 1;
                const dame_s = fmtDame(sbuf[off..], report.dame.count);
                off += dame_s.len;
                sbuf[off] = '\n';
                off += 1;
                const dead_s = fmtDead(sbuf[off..], report.dead);
                off += dead_s.len;
                sbuf[off] = '\n';
                off += 1;
                const dame_points = fmtVertexList(sbuf[off..], report.dame.points[0..report.dame.count], w, h);
                off += dame_points.len;
                off += (std.fmt.bufPrint(sbuf[off..], "\nDead stones: B: ", .{}) catch unreachable).len;
                const db_list = fmtVertexList(sbuf[off..], report.dead.dead_black[0..report.dead.dead_black_count], w, h);
                off += db_list.len;
                off += (std.fmt.bufPrint(sbuf[off..], "; W: ", .{}) catch unreachable).len;
                const dw_list = fmtVertexList(sbuf[off..], report.dead.dead_white[0..report.dead.dead_white_count], w, h);
                off += dw_list.len;
                off += (std.fmt.bufPrint(sbuf[off..], "\nContested chains: {d}\nStatus: {s}", .{
                    report.dead.contested, status,
                }) catch unreachable).len;
                reply = sbuf[0..off];
            } else if (std.mem.eql(u8, first, "quit")) {
                quit = true;
            } else {
                ok = false;
                reply = "unknown command";
            }

            try out.appendSlice(gpa, if (ok) "=" else "?");
            try out.appendSlice(gpa, id);
            if (reply.len > 0) {
                try out.appendSlice(gpa, " ");
                // exactly one blank line terminates a GTP response — a
                // multi-line reply with its own trailing newline would
                // desynchronize clients
                try out.appendSlice(gpa, std.mem.trimEnd(u8, reply, "\n"));
            }
            try out.appendSlice(gpa, "\n\n");
            log.line("> {s}", .{std.mem.trim(u8, out.items, "\n")});
            try stdout.writeStreamingAll(io, out.items);
            out.clearRetainingCapacity();
            if (quit) return;
        }
    }
}

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next(); // argv0
    const arg1 = args.next();
    const io = init.io;

    if (arg1) |a| {
        // Board-size shorthand "NxN" or "NxM" → construct artifact path
        if (parseBoardSize(a)) |bs| {
            const path = try std.fmt.allocPrint(gpa, "artifacts/oracle-{d}x{d}.wzo", .{ bs[0], bs[1] });
            return loadAndDispatch(io, gpa, path, args.next());
        }
        // Explicit artifact path (backward compatible)
        return loadAndDispatch(io, gpa, a, args.next());
    }

    // No argument: deferred mode — wait for boardsize GTP command
    try runDeferred(io, gpa, args.next());
}

/// GTP loop that starts without an artifact; loads it when boardsize arrives.
fn runDeferred(io: std.Io, gpa: std.mem.Allocator, opt_log_dir: ?[]const u8) !void {
    const log_dir = opt_log_dir orelse "log";
    const dir = std.Io.Dir.cwd();
    const log_file: ?std.Io.File = blk: {
        dir.createDirPath(io, log_dir) catch break :blk null;
        const log_path = try std.fmt.allocPrint(gpa, "{s}/weizigo-{d}.log", .{ log_dir, unix_seconds() });
        const f = dir.createFile(io, log_path, .{}) catch break :blk null;
        std.debug.print("weizigo-oracle: transcript -> {s}\n", .{log_path});
        break :blk f;
    };
    const log = LogSink{ .io = io, .file = log_file };

    var threaded = std.Io.Threaded.init(gpa, .{});
    const tio = threaded.io();
    const stdin = std.Io.File.stdin();
    const stdout = std.Io.File.stdout();

    var in_buf: [4096]u8 = undefined;
    var line: std.ArrayList(u8) = .empty;
    defer line.deinit(gpa);
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);

    std.debug.print("weizigo-oracle: deferred mode — waiting for boardsize…\n", .{});

    while (true) {
        const got = stdin.readStreaming(tio, &.{&in_buf}) catch 0;
        if (got == 0) break;
        var i: usize = 0;
        while (i < got) : (i += 1) {
            const ch = in_buf[i];
            if (ch != '\n') {
                try line.append(gpa, ch);
                continue;
            }
            log.line("< {s}", .{std.mem.trim(u8, line.items, " \t\r")});
            var tokens = std.mem.tokenizeAny(u8, line.items, " \t\r");
            line.clearRetainingCapacity();
            var first = tokens.next() orelse continue;
            var id: []const u8 = "";
            if (first.len > 0 and std.ascii.isDigit(first[0])) {
                id = first;
                first = tokens.next() orelse continue;
            }
            out.clearRetainingCapacity();
            var quit = false;
            var ok = true;
            var reply: []const u8 = "";
            var rbuf: [512]u8 = undefined;

            if (std.mem.eql(u8, first, "protocol_version")) {
                reply = "2";
            } else if (std.mem.eql(u8, first, "name")) {
                reply = "weizigo-oracle";
            } else if (std.mem.eql(u8, first, "version")) {
                reply = "deferred";
            } else if (std.mem.eql(u8, first, "known_command")) {
                const q = tokens.next() orelse "";
                reply = "false";
                for (KNOWN_COMMANDS) |c| {
                    if (std.mem.eql(u8, c, q)) reply = "true";
                }
            } else if (std.mem.eql(u8, first, "list_commands")) {
                var lb: [256]u8 = undefined;
                var ll: usize = 0;
                for (KNOWN_COMMANDS, 0..) |c, k| {
                    if (k != 0) {
                        lb[ll] = '\n';
                        ll += 1;
                    }
                    @memcpy(lb[ll .. ll + c.len], c);
                    ll += c.len;
                }
                @memcpy(rbuf[0..ll], lb[0..ll]);
                reply = rbuf[0..ll];
            } else if (std.mem.eql(u8, first, "boardsize") or std.mem.eql(u8, first, "rectangular_boardsize")) {
                const q = tokens.next() orelse "";
                const want_w = std.fmt.parseInt(usize, q, 10) catch 0;
                const q2 = tokens.next();
                const want_h = if (q2) |s2| (std.fmt.parseInt(usize, s2, 10) catch 0) else want_w;
                if (want_w == 0 or want_h == 0) {
                    ok = false;
                    reply = "unacceptable size";
                } else {
                    const artifact_path = try std.fmt.allocPrint(gpa, "artifacts/oracle-{d}x{d}.wzo", .{ want_w, want_h });
                    var load_result = artifact.load(io, std.Io.Dir.cwd(), artifact_path, gpa);
                    if (load_result) |*dec| {
                        defer dec.deinit();
                        std.debug.print("weizigo-oracle: {s} ({d}x{d}, {d} legal/side)\n", .{
                            artifact_path, dec.header.board_w, dec.header.board_h, dec.header.legal_count,
                        });
                        log.line("# weizigo-oracle session, artifact {s} ({d}x{d}), unix time {d}", .{
                            artifact_path, dec.header.board_w, dec.header.board_h, unix_seconds(),
                        });

                        // Send success for boardsize before handing off
                        try out.appendSlice(gpa, "=");
                        try out.appendSlice(gpa, id);
                        try out.appendSlice(gpa, "\n\n");
                        log.line("> =", .{});
                        try stdout.writeStreamingAll(tio, out.items);

                        // Feed any leftover bytes from this read into runSession
                        const remaining = in_buf[i + 1 .. got];

                        const key = @as(usize, dec.header.board_w) * 100 + dec.header.board_h;
                        switch (key) {
                            202 => try runSession(2, 2, gpa, dec, &log, remaining),
                            302 => try runSession(3, 2, gpa, dec, &log, remaining),
                            303 => try runSession(3, 3, gpa, dec, &log, remaining),
                            403 => try runSession(4, 3, gpa, dec, &log, remaining),
                            404 => try runSession(4, 4, gpa, dec, &log, remaining),
                            603 => try runSession(6, 3, gpa, dec, &log, remaining),
                            505 => try runSession(5, 5, gpa, dec, &log, remaining),
                            else => {
                                std.debug.print("unsupported artifact board {d}x{d}\n", .{ dec.header.board_w, dec.header.board_h });
                                return error.UnsupportedBoard;
                            },
                        }
                        return; // runSession returned (quit)
                    } else |_| {
                        ok = false;
                        reply = "unacceptable size";
                    }
                }
            } else if (std.mem.eql(u8, first, "quit")) {
                quit = true;
            } else {
                ok = false;
                reply = "unknown command";
            }

            try out.appendSlice(gpa, if (ok) "=" else "?");
            try out.appendSlice(gpa, id);
            if (reply.len > 0) {
                try out.appendSlice(gpa, " ");
                try out.appendSlice(gpa, std.mem.trimEnd(u8, reply, "\n"));
            }
            try out.appendSlice(gpa, "\n\n");
            log.line("> {s}", .{std.mem.trim(u8, out.items, "\n")});
            try stdout.writeStreamingAll(tio, out.items);
            if (quit) return;
        }
    }
}

// ---- tests ------------------------------------------------------------------

const expect = std.testing.expect;

test "vertex mapping: A1 is bottom-left, letters skip I, round-trips" {
    var buf: [8]u8 = undefined;
    // 3x3: cell 6 = bottom-left = A1; cell 0 = top-left = A3; centre = B2
    try expect(cell_from_vertex("A1", 3, 3).? == 6);
    try expect(cell_from_vertex("a3", 3, 3).? == 0);
    try expect(cell_from_vertex("B2", 3, 3).? == 4);
    try expect(std.mem.eql(u8, vertex_from_cell(&buf, 4, 3, 3), "B2"));
    for (0..9) |cell| {
        const v = vertex_from_cell(&buf, cell, 3, 3);
        try expect(cell_from_vertex(v, 3, 3).? == cell);
    }
    try expect(cell_from_vertex("J9", 9, 9) != null); // I skipped -> col 8
    try expect(cell_from_vertex("I5", 9, 9) == null);
    try expect(cell_from_vertex("D1", 3, 3) == null); // off-board
}
