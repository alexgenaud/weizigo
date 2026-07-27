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
// ENGINE-VS-ENGINE — B28: self-play regression test.
//
//   zig build-exe -O ReleaseFast src/engine-vs-engine.zig
//   ./engine-vs-engine artifacts/oracle-3x3.wzo artifacts/oracle-3x3-v2.wzo 200
//
// Tournament mode: loads two WZO1 artifacts (v1 = reference, v2 = challenger)
// and plays N games alternating colours. Reports v2's win/loss/draw record.
//
// REGRESSION DETECTION: for every game v2 lost, replays the same opponent-move
// sequence but substitutes v1's best move at v2's turns. If v1 wins, the loss
// is a REGRESSION — v2 made at least one suboptimal choice that changed the
// outcome. The regression game is saved as a compact record file.
//
// KO-AWARE COMPARISON: at each position where the two engines disagree on the
// best move, the position is classified by its independent-ko count (0-ko,
// 1-ko, 2-ko, 3+) using the logic from B23/ko_census.zig.

const std = @import("std");
const rules = @import("rules.zig");
const artifact = @import("artifact.zig");
const gtp = @import("gtp.zig");

const PLY_CAP = 400;
const REGRESSION_DIR = "untracked/regressions";

/// A ko-capture point: (cell of the capturing stone, cell of the captured stone).
const KoPoint = struct { cell: u8, cap: u8 };

/// Detect whether placing `colour` at `p` is a basic ko capture.
/// Returns the captured stone's cell if so, null otherwise.
/// (Inlined from ko_census.zig — B23.)
fn isKoCapture(comptime R: type, pos: *const R.Pos, p: usize, colour: i8) ?usize {
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

/// Build a list of all ko points on the board.
/// (Inlined from ko_census.zig — B23.)
fn findAllKoPoints(comptime R: type, pos: *const R.Pos, list: *std.ArrayListUnmanaged(KoPoint), gpa: std.mem.Allocator) !void {
    for (0..R.n) |p| {
        inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
            if (isKoCapture(R, pos, p, colour)) |cap| {
                try list.append(gpa, .{ .cell = @intCast(p), .cap = @intCast(cap) });
            }
        }
    }
}

/// Count independent ko clusters among ko_points using union-find.
/// Two ko points are dependent if their 1-neighborhoods intersect.
/// (Inlined from ko_census.zig — B23.)
fn countIndependentClusters(comptime R: type, ko_points: []const KoPoint) u8 {
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

/// Classify a position by independent-ko count (0, 1, 2, 3+).
fn classifyKo(comptime R: type, pos: *const R.Pos, gpa: std.mem.Allocator) u8 {
    var ko_points = std.ArrayListUnmanaged(KoPoint).initCapacity(gpa, 32) catch return 0;
    defer ko_points.deinit(gpa);
    findAllKoPoints(R, pos, &ko_points, gpa) catch return 0;
    const n = countIndependentClusters(R, ko_points.items);
    return if (n < 3) n else 3;
}

fn pct(part: u64, total: u64) f64 {
    if (total == 0) return 0;
    return @as(f64, @floatFromInt(part)) * 100.0 / @as(f64, @floatFromInt(total));
}

/// The error returned when a regression replay diverges (opponent's subsequent
/// move is illegal in the diverged position after v1's different choice).
const RegressionError = error{ GameDiverged };

fn checkRegression(
    io: std.Io,
    comptime w: usize,
    comptime h: usize,
    gpa: std.mem.Allocator,
    dec1: *const artifact.Decoded,
    orig_moves: []const u8,
    v2_color: i8,
    game_id: u64,
    rng_seed: u64,
    v1_path: []const u8,
    v2_path: []const u8,
) !bool {
    const S = gtp.Session(w, h);
    const R = rules.Rules(w, h);

    var s = S{ .d = dec1 };
    s.reset();

    var side: i8 = 1;
    var regr_moves: [PLY_CAP]u8 = undefined;
    var rply: usize = 0;

    for (orig_moves) |m| {
        if (s.passes >= 2) break;

        if (side == v2_color) {
            // v1 plays instead of v2
            const c = s.choose(side);
            const cell_byte: u8 = if (c.cell) |cell| @intCast(cell + 1) else 0;
            regr_moves[rply] = cell_byte;
            s.applyMove(side, c.cell) catch unreachable;
        } else {
            // Replay opponent's exact move from the original game
            const cell_byte = m;
            const cell: ?usize = if (cell_byte == 0) null else @as(usize, cell_byte - 1);

            // Verify the move is still legal in this position
            if (cell) |c| {
                const child = R.pos_from_move(&s.pos, side, c) catch return error.GameDiverged;
                if (s.seen(&child)) return error.GameDiverged;
            }

            regr_moves[rply] = cell_byte;
            s.applyMove(side, cell) catch unreachable;
        }

        side = -side;
        rply += 1;
    }

    const score = R.area_score(&s.pos);
    const v1_wins = if (v2_color > 0) score > 0 else score < 0;

    if (v1_wins) {
        try saveRegression(io, w, h, gpa, orig_moves, regr_moves[0..rply], v2_color, game_id, rng_seed, v1_path, v2_path, score);
        return true;
    }
    return false;
}

/// Format a move list as GTP vertex strings.
fn formatMoves(gpa: std.mem.Allocator, moves: []const u8, w: usize, h: usize) ![]u8 {
    var buf: std.ArrayList(u8) = .empty;
    var vbuf: [8]u8 = undefined;
    for (moves, 0..) |m, i| {
        if (i > 0) try buf.append(gpa, ' ');
        if (m == 0) {
            try buf.appendSlice(gpa, "pass");
        } else {
            const v = gtp.vertex_from_cell(&vbuf, m - 1, w, h);
            try buf.appendSlice(gpa, v);
        }
    }
    return buf.toOwnedSlice(gpa);
}

/// Save a regression game record.
fn saveRegression(
    io: std.Io,
    comptime w: usize,
    comptime h: usize,
    gpa: std.mem.Allocator,
    orig_moves: []const u8,
    regr_moves: []const u8,
    v2_color: i8,
    game_id: u64,
    rng_seed: u64,
    v1_path: []const u8,
    v2_path: []const u8,
    regr_score: i16,
) !void {
    // Create directory
    const dir_path = try std.fmt.allocPrint(gpa, "{s}/run-{d}", .{ REGRESSION_DIR, rng_seed });
    defer gpa.free(dir_path);
    std.Io.Dir.cwd().createDirPath(io, dir_path) catch {};

    const fname = try std.fmt.allocPrint(gpa, "regr-{d}-v2-{s}.txt", .{
        game_id, if (v2_color > 0) "B" else "W",
    });
    defer gpa.free(fname);
    const path = try std.fs.path.join(gpa, &.{ dir_path, fname });
    defer gpa.free(path);

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(gpa);

    try buf.appendSlice(gpa, "# REGRESSION game ");
    try buf.appendSlice(gpa, try std.fmt.allocPrint(gpa, "{d}", .{game_id}));
    try buf.appendSlice(gpa, "  seed ");
    try buf.appendSlice(gpa, try std.fmt.allocPrint(gpa, "{d}\n", .{rng_seed}));
    try buf.appendSlice(gpa, "# v1=");
    try buf.appendSlice(gpa, v1_path);
    try buf.appendSlice(gpa, "\n# v2=");
    try buf.appendSlice(gpa, v2_path);
    try buf.appendSlice(gpa, "\n# v2 played ");
    try buf.appendSlice(gpa, if (v2_color > 0) "Black" else "White");
    try buf.appendSlice(gpa, "\n# v1 replay score: ");
    if (regr_score > 0) {
        try buf.appendSlice(gpa, "B+");
        try buf.appendSlice(gpa, try std.fmt.allocPrint(gpa, "{d}", .{regr_score}));
    } else if (regr_score < 0) {
        try buf.appendSlice(gpa, "W+");
        try buf.appendSlice(gpa, try std.fmt.allocPrint(gpa, "{d}", .{-regr_score}));
    } else {
        try buf.appendSlice(gpa, "0");
    }
    try buf.appendSlice(gpa, "\n# original game:\n#  ");
    const orig_fmt = try formatMoves(gpa, orig_moves, w, h);
    defer gpa.free(orig_fmt);
    try buf.appendSlice(gpa, orig_fmt);
    try buf.appendSlice(gpa, "\n# v1 replay:\n#  ");
    const regr_fmt = try formatMoves(gpa, regr_moves, w, h);
    defer gpa.free(regr_fmt);
    try buf.appendSlice(gpa, regr_fmt);
    try buf.appendSlice(gpa, "\n");

    var file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, buf.items);
}

fn runTournament(
    io: std.Io,
    comptime w: usize,
    comptime h: usize,
    gpa: std.mem.Allocator,
    v1_path: []const u8,
    v2_path: []const u8,
    dec1: *const artifact.Decoded,
    dec2: *const artifact.Decoded,
    num_games: u64,
    rng_seed: u64,
) !void {
    const S = gtp.Session(w, h);
    const R = rules.Rules(w, h);
    const p = std.debug.print;

    var v2_wins: u64 = 0;
    var v2_losses: u64 = 0;
    var draws: u64 = 0;
    var capped: u64 = 0;
    var regressions: u64 = 0;
    var diverged_regressions: u64 = 0;
    var ko_disagree: [4]u64 = .{0} ** 4; // 0-ko, 1-ko, 2-ko, 3+-ko

    var s1 = try gpa.create(S);
    defer gpa.destroy(s1);
    var s2 = try gpa.create(S);
    defer gpa.destroy(s2);

    var vbuf: [8]u8 = undefined;
    _ = &vbuf;

    for (0..num_games) |gi| {
        const v2_is_black = (gi % 2 == 0);
        const v2_color: i8 = if (v2_is_black) 1 else -1;

        s1.* = .{ .d = dec1 };
        s2.* = .{ .d = dec2 };
        s1.reset();
        s2.reset();

        var moves: [PLY_CAP]u8 = undefined; // cell+1, 0=pass
        var ply: usize = 0;
        var side: i8 = 1;

        while (ply < PLY_CAP) : (ply += 1) {
            const engine_is_v2 = (side == v2_color);
            const active = if (engine_is_v2) s2 else s1;
            const other = if (engine_is_v2) s1 else s2;

            if (active.passes >= 2) break;

            const c = active.choose(side);

            // Ko-aware comparison: does the other engine disagree?
            const oc = other.choose(side);
            if (c.cell != oc.cell) {
                const nko = classifyKo(R, &active.pos, gpa);
                ko_disagree[nko] += 1;
            }

            moves[ply] = if (c.cell) |cell| @intCast(cell + 1) else 0;

            // Apply move to both sessions (keep them synced)
            active.applyMove(side, c.cell) catch unreachable;
            other.applyMove(side, c.cell) catch unreachable;

            side = -side;
        }

        if (ply >= PLY_CAP) {
            capped += 1;
            continue;
        }

        const score = R.area_score(&s1.pos);
        const v2_won = if (v2_color > 0) score > 0 else score < 0;
        const is_draw = score == 0;

        if (is_draw) {
            draws += 1;
        } else if (v2_won) {
            v2_wins += 1;
        } else {
            v2_losses += 1;

            // Regression check
            const reg = checkRegression(io, w, h, gpa, dec1, moves[0..ply], v2_color, gi, rng_seed, v1_path, v2_path) catch |err| {
                if (err == error.GameDiverged) {
                    diverged_regressions += 1;
                    continue;
                }
                return err;
            };
            if (reg) regressions += 1;
        }

        // Progress every 10 games or on last game
        if ((gi + 1) % 10 == 0 or gi == num_games - 1) {
            p("  game {d}/{d}: v2-wins={d} v2-losses={d} draws={d} regr={d}\r", .{
                gi + 1, num_games, v2_wins, v2_losses, draws, regressions,
            });
        }
    }

    p("\n\n", .{});
    p("═══════════════════════════════════════\n", .{});
    p("engine-vs-engine: {d}x{d}\n", .{ w, h });
    p("  v1 (reference):  {s}\n", .{v1_path});
    p("  v2 (challenger): {s}\n", .{v2_path});
    p("───────────────────────────────────────\n", .{});
    p("  games:       {d:>6}\n", .{num_games});
    p("  v2-wins:     {d:>6}  ({d:.1}%)\n", .{ v2_wins, pct(v2_wins, num_games) });
    p("  v2-losses:   {d:>6}  ({d:.1}%)\n", .{ v2_losses, pct(v2_losses, num_games) });
    p("  draws:       {d:>6}  ({d:.1}%)\n", .{ draws, pct(draws, num_games) });
    p("  capped:      {d:>6}\n", .{capped});
    p("───────────────────────────────────────\n", .{});
    p("  REGRESSIONS: {d}\n", .{regressions});
    if (diverged_regressions > 0) p("  diverged (skipped): {d}\n", .{diverged_regressions});
    p("───────────────────────────────────────\n", .{});
    p("  ko-disagreements:\n", .{});
    p("    0-ko:  {d:>6}\n", .{ko_disagree[0]});
    p("    1-ko:  {d:>6}\n", .{ko_disagree[1]});
    p("    2-ko:  {d:>6}\n", .{ko_disagree[2]});
    p("    3+-ko: {d:>6}\n", .{ko_disagree[3]});
    p("═══════════════════════════════════════\n", .{});
}

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next(); // program name

    const v1_path = args.next() orelse {
        std.debug.print(
            \\usage: engine-vs-engine <v1.wzo> <v2.wzo> [num_games] [--seed <N>]
            \\
            \\  v1.wzo      reference artifact (baseline)
            \\  v2.wzo      challenger artifact
            \\  num_games   number of games to play (default: 100)
            \\  --seed N    random seed (default: 42)
            \\
        , .{});
        return;
    };
    const v2_path = args.next() orelse {
        std.debug.print("error: missing v2 artifact path\n", .{});
        return;
    };

    var num_games: u64 = 100;
    var rng_seed: u64 = 42;

    var next_arg = args.next();
    while (next_arg) |a| {
        if (std.mem.eql(u8, a, "--seed")) {
            rng_seed = std.fmt.parseInt(u64, args.next() orelse "42", 10) catch 42;
        } else {
            num_games = std.fmt.parseInt(u64, a, 10) catch 100;
        }
        next_arg = args.next();
    }

    // Load both artifacts
    var dec1 = artifact.load(init.io, std.Io.Dir.cwd(), v1_path, gpa) catch |err| {
        std.debug.print("error: cannot load v1 artifact '{s}': {}\n", .{ v1_path, err });
        return;
    };
    defer dec1.deinit();

    var dec2 = artifact.load(init.io, std.Io.Dir.cwd(), v2_path, gpa) catch |err| {
        std.debug.print("error: cannot load v2 artifact '{s}': {}\n", .{ v2_path, err });
        return;
    };
    defer dec2.deinit();

    // Validate same board size
    if (dec1.header.board_w != dec2.header.board_w or dec1.header.board_h != dec2.header.board_h) {
        std.debug.print("error: artifacts have different board sizes ({d}x{d} vs {d}x{d})\n", .{
            dec1.header.board_w, dec1.header.board_h,
            dec2.header.board_w, dec2.header.board_h,
        });
        return;
    }

    std.debug.print("engine-vs-engine: v1={s} v2={s} {d}x{d}  {d} games  seed={d}\n\n", .{
        v1_path, v2_path, dec1.header.board_w, dec1.header.board_h, num_games, rng_seed,
    });

    const key = @as(usize, dec1.header.board_w) * 100 + dec1.header.board_h;
    switch (key) {
        202 => try runTournament(init.io, 2, 2, gpa, v1_path, v2_path, &dec1, &dec2, num_games, rng_seed),
        302 => try runTournament(init.io, 3, 2, gpa, v1_path, v2_path, &dec1, &dec2, num_games, rng_seed),
        303 => try runTournament(init.io, 3, 3, gpa, v1_path, v2_path, &dec1, &dec2, num_games, rng_seed),
        403 => try runTournament(init.io, 4, 3, gpa, v1_path, v2_path, &dec1, &dec2, num_games, rng_seed),
        404 => try runTournament(init.io, 4, 4, gpa, v1_path, v2_path, &dec1, &dec2, num_games, rng_seed),
        603 => try runTournament(init.io, 6, 3, gpa, v1_path, v2_path, &dec1, &dec2, num_games, rng_seed),
        else => {
            std.debug.print("error: unsupported board size {d}x{d}\n", .{ dec1.header.board_w, dec1.header.board_h });
            return;
        },
    }
}
