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
// HONESTY (the GHI residue, ADR-0009/0010): stored values are FRESH-START
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

const COLS = "ABCDEFGHJKLMNOPQRSTUVWXYZ"; // GTP letters, no 'I'
const MAX_HIST = 4096;

pub fn Session(comptime w: usize, comptime h: usize) type {
    return struct {
        const S = @This();
        const R = rules.Rules(w, h);
        const X = colexmod.Indexer(w, h);
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
        pub fn v1_from_table(s: *const S, pos: *const Pos, side: i8) i8 {
            const maximizing = side > 0;
            var best: i8 = R.area_score(pos); // the ending pass
            for (0..n) |p| {
                if (pos[p] != 0) continue;
                const child = R.pos_from_move(pos, side, p) catch continue;
                const v = s.v0(&child, -side);
                if (if (maximizing) v > best else v < best) best = v;
            }
            return best;
        }

        const Choice = struct { cell: ?usize, value: i8, dtt: u8 };

        /// Best move (or pass) for `side` from the current game state:
        /// fresh-start-optimal among PSK-legal options, value ties broken by
        /// smallest DTT. Never resigns — the oracle has nothing to fear.
        pub fn choose(s: *const S, side: i8) Choice {
            const maximizing = side > 0;
            // pass option
            var best = Choice{
                .cell = null,
                .value = if (s.passes >= 1) R.area_score(&s.pos) else s.v1_from_table(&s.pos, -side),
                // prefer board moves on ties while the game is open; prefer
                // the game-ending pass once the score is already optimal
                .dtt = if (s.passes >= 1) 0 else 254,
            };
            for (0..n) |p| {
                if (s.pos[p] != 0) continue;
                const child = R.pos_from_move(&s.pos, side, p) catch continue;
                if (s.seen(&child)) continue; // positional superko
                const v = s.v0(&child, -side);
                const dt = s.dtt0(&child, -side);
                const better = if (maximizing) v > best.value else v < best.value;
                if (better or (v == best.value and dt < best.dtt)) {
                    best = .{ .cell = p, .value = v, .dtt = dt };
                }
            }
            return best;
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

// ---- GTP main loop -----------------------------------------------------------

const KNOWN_COMMANDS = [_][]const u8{
    "protocol_version", "name",        "version",  "known_command", "list_commands",
    "boardsize",        "clear_board", "komi",     "play",          "genmove",
    "undo",             "showboard",   "final_score", "quit",
};

fn runSession(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator, dec: *const artifact.Decoded) !void {
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

    while (true) {
        const got = stdin.readStreaming(io, &.{&in_buf}) catch 0;
        if (got == 0) break; // EOF
        for (in_buf[0..got]) |ch| {
            if (ch != '\n') {
                try line.append(gpa, ch);
                continue;
            }
            // ---- one GTP command line ----
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
            } else if (std.mem.eql(u8, first, "boardsize")) {
                const q = tokens.next() orelse "";
                const want = std.fmt.parseInt(usize, q, 10) catch 0;
                if (want == w and w == h) {
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
                    s.applyMove(side, cell) catch {
                        ok = false;
                        reply = "illegal move";
                    };
                } else {
                    ok = false;
                    reply = "invalid vertex";
                }
            } else if (std.mem.eql(u8, first, "genmove")) {
                const colort = tokens.next() orelse "";
                const side: i8 = if (colort.len > 0 and (colort[0] == 'b' or colort[0] == 'B')) 1 else -1;
                if (s.passes >= 2) {
                    reply = "pass";
                } else {
                    const stored = s.v0(&s.pos, side);
                    const fl = s.flags0(&s.pos, side);
                    const c = s.choose(side);
                    s.applyMove(side, c.cell) catch {};
                    reply = if (c.cell) |cell| vertex_from_cell(&vbuf, cell, w, h) else "pass";
                    std.debug.print("oracle: {s} -> {s}  child-value={d} stored-v0={d}{s}{s} dtt={d}\n", .{
                        colort,                reply,                       c.value, stored,
                        if (c.value != stored) " (HISTORY-DIVERGED)" else "",
                        if (fl & 1 != 0) " KO_SENSITIVE" else "",         c.dtt,
                    });
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
    const path = args.next() orelse {
        std.debug.print("usage: gtp <oracle-artifact.wzo>\n", .{});
        return error.MissingArtifactPath;
    };

    const io = init.io;
    var dec = artifact.load(io, std.Io.Dir.cwd(), path, gpa) catch |err| {
        // GUIs (Sabaki/gogui) launch engines with THEIR working directory, so
        // a relative artifact path usually fails there — say so loudly on
        // stderr (the GUI console) instead of dying with a bare error code.
        std.debug.print("weizigo-oracle: cannot load artifact '{s}': {t}\n" ++
            "  hint: when launching from a GUI, pass an ABSOLUTE path to the .wzo file\n", .{ path, err });
        return err;
    };
    defer dec.deinit();
    std.debug.print("weizigo-oracle: {s} ({d}x{d}, {d} legal/side)\n", .{
        path, dec.header.board_w, dec.header.board_h, dec.header.legal_count,
    });

    const key = @as(usize, dec.header.board_w) * 100 + dec.header.board_h;
    switch (key) {
        202 => try runSession(2, 2, gpa, &dec),
        302 => try runSession(3, 2, gpa, &dec),
        303 => try runSession(3, 3, gpa, &dec),
        404 => try runSession(4, 4, gpa, &dec),
        505 => try runSession(5, 5, gpa, &dec),
        else => {
            std.debug.print("unsupported artifact board {d}x{d}\n", .{ dec.header.board_w, dec.header.board_h });
            return error.UnsupportedBoard;
        },
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
