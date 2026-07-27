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
// ARENA — adversarial self-play audit of the oracle player.
//
//   zig build-exe -O ReleaseFast src/arena.zig && ./arena data/oracle-4x4.wzo 200
//
// One player (the AUDITED player) plays fresh-start-optimally, but chooses
// RANDOMLY among the value-optimal moves (not just the fastest) — exploring
// alternative winning lines. The opponent plays a seeded MIX: optimal /
// winning-but-suboptimal / anything-legal (human-realistic errors). Colours,
// seeds and handicaps (0/1/2 pre-placed Black stones) all vary.
//
// THE AUDIT (the whole point): for every position in a game where the
// audited player was to move, the stored fresh-start value made a promise.
// If the final score falls short of the STRONGEST promise anywhere in the
// game's history, that game is a LEAK — either a fresh-start/history
// divergence (a superko tangle where the table's plan was history-poisoned;
// cf. "the B+16 game", research/retrograde-4x4.md) or a player bug. Every
// leaked game is printed as a replayable move list for the history-exact
// probes (RETRO_REPLAY / RETRO_VERIFY).
//
// Also counted: DIVERGED events (the audited player's best achievable child
// value differs from the stored value of its own position — the moment the
// table's promise becomes unkeepable under this game's superko bans).

const std = @import("std");
const rules = @import("rules.zig");
const artifact = @import("artifact.zig");
const gtp = @import("gtp.zig");

const PLY_CAP = 400;
const RECORD_DIR = "untracked/regressions";

/// Opponent personas (user-specified, 2026-07-22). Percentages are move-
/// selection probabilities: optimal / winning-but-any / remainder = any
/// legal move. `slop` restricts the winning pool to NON-optimal winning
/// moves where possible (the pure margin-leaker who never throws a won
/// game). Empty pools fall back: winning -> optimal -> any.
const Persona = struct { name: []const u8, p_opt: u8, p_win: u8, slop: bool = false };
const PERSONAS = [_]Persona{
    .{ .name = "optimal", .p_opt = 100, .p_win = 0 },
    .{ .name = "winning-any", .p_opt = 0, .p_win = 100 },
    .{ .name = "winning-slop", .p_opt = 0, .p_win = 100, .slop = true },
    .{ .name = "dan", .p_opt = 90, .p_win = 8 },
    .{ .name = "kyu", .p_opt = 60, .p_win = 25 },
    .{ .name = "novice", .p_opt = 30, .p_win = 40 },
};

const GameStats = struct {
    games: u64 = 0,
    capped: u64 = 0,
    leaks: u64 = 0, // CLEAN (no UNDEF slot touched) leaks only — see undef_tainted_games
    max_leak: i16 = 0,
    diverged_games: u64 = 0,
    diverged_events: u64 = 0,
    diverged_single: u64 = 0, // E1 (2026-07-25): diverged at single-score positions
    diverged_ko: u64 = 0,     // E1 (2026-07-25): diverged at ko-sensitive positions
    // B43 (2026-07-27): a UNDEF slot (-128 sentinel from 2-ko+ unfilled artifact
    // positions) has NO fresh-start belief — it is OUT OF SCOPE for the belief
    // audit. Games/plies that touch a UNDEF slot are reported in these counters
    // separately from clean leaks/divergences, so the post-fix numbers measure
    // only what the table can actually claim.
    undef_tainted_games: u64 = 0, // games that touched >=1 UNDEF slot
    undef_tainted_events: u64 = 0, // total plies that hit a UNDEF slot
    undef_tainted_leaks: u64 = 0,  // games that BOTH touched UNDEF AND leaked
    undef_tainted_max_leak: i16 = 0, // max leak on a tainted game
    audited_won: u64 = 0,
    audited_held: u64 = 0, // final score == best promise (exactly kept)
};

fn runArena(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator, dec: *const artifact.Decoded, num_seeds: u64, det: bool, record: bool) !void {
    const S = gtp.Session(w, h);
    const R = rules.Rules(w, h);
    const n = R.n;
    const p = std.debug.print;

    const s = try gpa.create(S);
    defer gpa.destroy(s);
    s.* = .{ .d = dec };

    // handicap placements: opposite corners (a convention, not a claim)
    const handi_cells = [_]usize{ (h - 1) * w, w - 1 }; // A1-corner, top-right

    var stats: [PERSONAS.len]GameStats = .{GameStats{}} ** PERSONAS.len;
    var vbuf: [8]u8 = undefined;

    var seed: u64 = 0;
    while (seed < num_seeds) : (seed += 1) {
        for (PERSONAS, 0..) |persona, pi| {
        inline for (.{ @as(i8, 1), @as(i8, -1) }) |audited_color| {
            for (0..3) |handicap| {
                var prng = std.Random.DefaultPrng.init(seed * 1013 + pi * 131 + handicap * 7 + @as(u64, if (audited_color > 0) 0 else 1));
                const rnd = prng.random();

                s.reset();
                var ok = true;
                for (0..handicap) |hc| {
                    const child = R.pos_from_move(&s.pos, 1, handi_cells[hc]) catch {
                        ok = false;
                        break;
                    };
                    s.pos = child;
                    s.push(&child);
                }
                if (!ok) continue;
                var side: i8 = if (handicap > 0) -1 else 1;

                var promise: i16 = if (audited_color > 0) -127 else 127; // strongest value promised
                var diverged: u64 = 0;
                var diverged_single: u64 = 0; // E1: diverged at single-score (KO_SENSITIVE==0) positions
                var diverged_ko: u64 = 0;    // E1: diverged at ko-sensitive positions
                var undef_tainted_events: u64 = 0; // B43: plies that hit a UNDEF slot
                var undef_tainted: bool = false;  // B43: any UNDEF ply in this game so far?
                var moves_rec: [PLY_CAP]u8 = undefined; // cell+1, 0 = pass
                var ply: usize = 0;

                while (s.passes < 2 and ply < PLY_CAP) : (ply += 1) {
                    // candidate enumeration (pass always included)
                    // B43 (2026-07-27): UNDEF children are skipped — the table
                    // holds no fresh-start belief at a 2-ko+ unfilled slot, so
                    // it would manufacture fake candidates and a fake "best".
                    // Pass (`vals[0]`) is already UNDEF-safe via B40's
                    // `v1_from_table` guard. If all real children are UNDEF,
                    // pass is the only candidate — that matches the GTP
                    // player.
                    var cells: [n + 1]?usize = undefined;
                    var vals: [n + 1]i8 = undefined;
                    var cnt: usize = 0;
                    cells[0] = null;
                    vals[0] = if (s.passes >= 1) R.area_score(&s.pos) else s.v1_from_table(&s.pos, -side);
                    cnt = 1;
                    for (0..n) |cell| {
                        if (s.pos[cell] != 0) continue;
                        const child = R.pos_from_move(&s.pos, side, cell) catch continue;
                        if (s.seen(&child)) continue;
                        const child_val = s.v0(&child, -side);
                        if (child_val == gtp.UNDEF) continue; // B43: skip unfilled slot
                        cells[cnt] = cell;
                        vals[cnt] = child_val;
                        cnt += 1;
                    }
                    const maximizing = side > 0;
                    var best: i8 = vals[0];
                    for (vals[1..cnt]) |v| {
                        if (if (maximizing) v > best else v < best) best = v;
                    }

                    var pick: usize = 0;
                    if (side == audited_color) {
                        // AUDIT SEMANTICS: this is a BELIEF audit, not a
                        // policy audit. If the fresh-start values were true
                        // in-game values, then EVERY believed-optimal move
                        // preserves the promise, so a random pick among them
                        // can never cause a leak — any leak proves a move the
                        // table called optimal was history-poisoned. The
                        // randomization only widens coverage of that claim.
                        const stored = s.v0(&s.pos, side);
                        // B43: tag this game (and this ply) as undef-tainted
                        // if the stored slot is UNDEF, and skip the promise
                        // update — the table has no fresh-start belief to
                        // promise here.
                        const stored_undef = (stored == gtp.UNDEF);
                        const best_undef = (best == gtp.UNDEF);
                        const ply_tainted = stored_undef or best_undef;
                        if (ply_tainted) {
                            undef_tainted = true;
                            undef_tainted_events += 1;
                        }
                        if (stored_undef) {
                            // do NOT update promise from a UNDEF slot
                        } else if (audited_color > 0) {
                            if (stored > promise) promise = stored;
                        } else if (stored < promise) {
                            promise = stored;
                        }
                        if (ply_tainted) {
                            // B43: do NOT count a divergence on a UNDEF ply.
                            // There is no fresh-start belief to compare, so
                            // a `best != stored` here is an artifact of the
                            // table's missing slot, not a divergence of the
                            // player's plan. The ply is already tagged above
                            // (undef_tainted_events++); just skip the count.
                        } else if (best != stored) {
                            diverged += 1;
                            // E1 diagnostic (2026-07-25): which region did the
                            // fresh-start player's plan break in? NOTE: the flag
                            // is from converge; `best` is the fresh-start player's
                            // BELIEF (max fresh-start child over PSK-legal), NOT
                            // the true real-history value — so a single-score
                            // divergence does NOT falsify C2. See status/leak-crisis.md.
                            const ko = (s.flags0(&s.pos, side) & 1) != 0;
                            if (ko) diverged_ko += 1 else diverged_single += 1;
                        }
                        if (det) {
                            // DETERMINISTIC mode: exactly the GTP player's
                            // policy (min-DTT tie-break via Session.choose),
                            // so every leaked game replays verbatim against
                            // the real engine — a win recipe, not a sample
                            const c = s.choose(side);
                            for (cells[0..cnt], 0..) |cell, i| {
                                const match = if (c.cell) |cc| (cell != null and cell.? == cc) else (cell == null);
                                if (match) pick = i;
                            }
                        } else {
                            var opt_count: usize = 0;
                            for (vals[0..cnt], 0..) |v, i| {
                                if (v == best) {
                                    opt_count += 1;
                                    if (rnd.uintLessThan(usize, opt_count) == 0) pick = i;
                                }
                            }
                        }
                    } else {
                        // persona opponent: roll optimal / winning / any
                        const roll = rnd.uintLessThan(u8, 100);
                        var pool: [n + 1]usize = undefined;
                        var pc: usize = 0;
                        if (roll >= persona.p_opt and roll < @as(u16, persona.p_opt) + persona.p_win) {
                            // winning pool (slop: exclude optimal if possible)
                            for (vals[0..cnt], 0..) |v, i| {
                                const wins = if (maximizing) v > 0 else v < 0;
                                if (wins and !(persona.slop and v == best)) {
                                    pool[pc] = i;
                                    pc += 1;
                                }
                            }
                            if (pc == 0 and persona.slop) {
                                for (vals[0..cnt], 0..) |v, i| {
                                    const wins = if (maximizing) v > 0 else v < 0;
                                    if (wins) {
                                        pool[pc] = i;
                                        pc += 1;
                                    }
                                }
                            }
                        } else if (roll >= @as(u16, persona.p_opt) + persona.p_win) {
                            // anything legal
                            for (0..cnt) |i| {
                                pool[pc] = i;
                                pc += 1;
                            }
                        }
                        if (pc == 0) {
                            // optimal (rolled, or fallback for empty pools)
                            for (vals[0..cnt], 0..) |v, i| {
                                if (v == best) {
                                    pool[pc] = i;
                                    pc += 1;
                                }
                            }
                        }
                        pick = pool[rnd.uintLessThan(usize, pc)];
                    }

                    moves_rec[ply] = if (cells[pick]) |c| @intCast(c + 1) else 0;
                    try s.applyMove(side, cells[pick]);
                    side = -side;
                }

                stats[pi].games += 1;
                if (ply >= PLY_CAP) {
                    stats[pi].capped += 1;
                    continue;
                }
                const score: i16 = R.area_score(&s.pos);
                const won = if (audited_color > 0) score > 0 else score < 0;
                if (won) stats[pi].audited_won += 1;
                if (score == promise) stats[pi].audited_held += 1;
                if (diverged > 0) {
                    stats[pi].diverged_games += 1;
                    stats[pi].diverged_events += diverged;
                }
                stats[pi].diverged_single += diverged_single;
                stats[pi].diverged_ko += diverged_ko;
                // B43: count UNDEF-tainted games separately. The promise
                // tracking was suspended at UNDEF plies, so the `promise`
                // above is the strongest value the table could still claim
                // — but a leak through (or past) a UNDEF slot is no longer
                // a clean audit signal. Report it in the tainted bucket.
                if (undef_tainted) {
                    stats[pi].undef_tainted_games += 1;
                    stats[pi].undef_tainted_events += undef_tainted_events;
                }
                const leak: i16 = if (audited_color > 0) promise - score else score - promise;
                if (leak > 0) {
                    if (undef_tainted) {
                        stats[pi].undef_tainted_leaks += 1;
                        if (leak > stats[pi].undef_tainted_max_leak) stats[pi].undef_tainted_max_leak = leak;
                        p("LEAK(UNDEF) {d} pts | persona {s} | seed {d} | audited {s} | handicap {d} | promise {d} final {d} | undef-tainted plies {d} | diverged-events {d}\n  moves:", .{
                            leak, persona.name, seed, if (audited_color > 0) "B" else "W", handicap, promise, score, undef_tainted_events, diverged,
                        });
                    } else {
                        stats[pi].leaks += 1;
                        if (leak > stats[pi].max_leak) stats[pi].max_leak = leak;
                        p("LEAK {d} pts | persona {s} | seed {d} | audited {s} | handicap {d} | promise {d} final {d} | diverged-events {d}\n  moves:", .{
                            leak, persona.name, seed, if (audited_color > 0) "B" else "W", handicap, promise, score, diverged,
                        });
                    }
                    for (moves_rec[0..ply]) |m| {
                        if (m == 0) {
                            p(" pass", .{});
                        } else {
                            p(" {s}", .{gtp.vertex_from_cell(&vbuf, m - 1, w, h)});
                        }
                    }
                    p("\n", .{});
                }

                // ── record divergences ──
                if (record and !(ply >= PLY_CAP)) {
                    try recordGame(w, h, gpa, s, R, moves_rec[0..ply], seed, pi, audited_color, handicap, score);
                }
            }
        }
        }
    }

    p("\narena summary (per opponent persona):\n", .{});
    for (PERSONAS, 0..) |persona, pi| {
        p("  {s:<13} games={d:>5} capped={d} audited-won={d:>5} held-exact={d:>5} CLEAN-LEAKS={d} (max {d}) diverged {d}/{d}\n", .{
            persona.name, stats[pi].games, stats[pi].capped, stats[pi].audited_won, stats[pi].audited_held,
            stats[pi].leaks, stats[pi].max_leak, stats[pi].diverged_games, stats[pi].diverged_events,
        });
        p("  {s:<13} E1 diverged: single-score={d}  ko-sensitive={d}\n", .{ persona.name, stats[pi].diverged_single, stats[pi].diverged_ko });
        p("  {s:<13} B43 UNDEF-tainted: games={d}  events={d}  tainted-leaks={d} (max {d})\n", .{
            persona.name, stats[pi].undef_tainted_games, stats[pi].undef_tainted_events,
            stats[pi].undef_tainted_leaks, stats[pi].undef_tainted_max_leak,
        });
    }
}

fn recordGame(
    comptime w: usize,
    comptime h: usize,
    gpa: std.mem.Allocator,
    s: anytype,
    R: anytype,
    moves: []const u8,
    seed: u64,
    persona_idx: usize,
    audited_color: i8,
    handicap: u64,
    final_score: i16,
) !void {
    if (moves.len == 0) return;

    var threaded = std.Io.Threaded.init(gpa, .{});
    defer threaded.deinit();
    const io = threaded.io();

    // Ensure record dir exists
    std.Io.Dir.cwd().createDirPath(io, RECORD_DIR) catch {};

    // Filename: <seed>_<persona>_<color>_<handicap>.reg
    const fname = try std.fmt.allocPrint(gpa, "{d}_{d}_{s}_{d}.reg", .{
        seed, persona_idx, if (audited_color > 0) "B" else "W", handicap,
    });
    defer gpa.free(fname);
    const path = try std.fs.path.join(gpa, &.{ RECORD_DIR, fname });
    defer gpa.free(path);

    // Format: header line + one line per diverged position
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(gpa);

    const header = try std.fmt.allocPrint(gpa, "{d} {d} {d} {d} {d} {d}\n", .{
        seed, persona_idx, audited_color, handicap, final_score, moves.len,
    });
    defer gpa.free(header);
    try buf.appendSlice(gpa, header);

    // Replay moves on a fresh session to find diverged positions
    const S = gtp.Session(w, h);
    var rs: S = .{ .d = s.d };
    rs.reset();

    // Apply handicap stones to the fresh session
    const handi_cells = [_]usize{ (h - 1) * w, w - 1 };
    for (0..handicap) |hc| {
        const child = R.pos_from_move(&rs.pos, 1, handi_cells[hc]) catch break;
        rs.pos = child;
        rs.push(&child);
    }
    var side: i8 = if (handicap > 0) -1 else 1;

    for (moves, 0..) |m, ply_i| {
        const stored = rs.v0(&rs.pos, side);
        if (stored != final_score) {
            const line = try std.fmt.allocPrint(gpa, "{d} {d}", .{ ply_i, stored });
            defer gpa.free(line);
            try buf.appendSlice(gpa, line);
            for (moves[0..ply_i]) |mp| {
                try buf.appendSlice(gpa, " ");
                var num_buf: [16]u8 = undefined;
                const num_str = try std.fmt.bufPrint(&num_buf, "{d}", .{mp});
                try buf.appendSlice(gpa, num_str);
            }
            try buf.appendSlice(gpa, "\n");
        }

        // Advance the fresh session
        const cell: ?usize = if (m == 0) null else m - 1;
        _ = try rs.applyMove(side, cell);
        side = -side;
    }

    // Write if we have divergence lines (beyond header)
    if (std.mem.count(u8, buf.items, "\n") > 1) {
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = path, .data = buf.items });
    }
}

fn replayRegressions(
    comptime w: usize,
    comptime h: usize,
    gpa: std.mem.Allocator,
    dec: *const artifact.Decoded,
    dir_path: []const u8,
) !void {
    const S = gtp.Session(w, h);
    const R = rules.Rules(w, h);

    var threaded = std.Io.Threaded.init(gpa, .{});
    defer threaded.deinit();
    const io = threaded.io();

    var dir = std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true }) catch |err| {
        std.debug.print("replay: cannot open {s}: {}\n", .{ dir_path, err });
        return;
    };
    defer dir.close(io);

    var total_positions: u64 = 0;
    var improved: u64 = 0;
    var worsened: u64 = 0;
    var unchanged: u64 = 0;
    var new_diverged: u64 = 0;

    var iter = dir.iterate();
    while (try iter.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".reg")) continue;

        const content = try dir.readFileAlloc(io, entry.name, gpa, .unlimited);
        defer gpa.free(content);

        var lines = std.mem.splitScalar(u8, content, '\n');
        const header_line = lines.next() orelse continue;

        // Parse header: <seed> <persona> <color> <handicap> <final_score> <num_moves>
        var header_tok = std.mem.splitScalar(u8, header_line, ' ');
        const seed_str = header_tok.next() orelse continue;
        const pers_str = header_tok.next() orelse continue;
        const col_str = header_tok.next() orelse continue;
        const hand_str = header_tok.next() orelse continue;
        const score_str = header_tok.next() orelse continue;

        _ = std.fmt.parseInt(u64, seed_str, 10) catch continue;
        _ = std.fmt.parseInt(u64, pers_str, 10) catch continue;
        _ = std.fmt.parseInt(i8, col_str, 10) catch continue;
        const handicap = std.fmt.parseInt(u64, hand_str, 10) catch continue;
        const final_score = std.fmt.parseInt(i16, score_str, 10) catch continue;

        // Create session and replay handicap + moves for each divergence line
        while (lines.next()) |line| {
            if (line.len == 0) continue;
            var tok = std.mem.splitScalar(u8, line, ' ');
            const ply_str = tok.next() orelse continue;
            const stored_str = tok.next() orelse continue;
            const ply = std.fmt.parseInt(u64, ply_str, 10) catch continue;
            const stored_val = std.fmt.parseInt(i16, stored_str, 10) catch continue;
            _ = ply;

            // Replay moves up to this point using s2 only
            var s2: S = .{ .d = dec };
            s2.reset();
            const handi_cells = [_]usize{ (h - 1) * w, w - 1 };
            for (0..handicap) |hc| {
                const child = R.pos_from_move(&s2.pos, 1, handi_cells[hc]) catch break;
                s2.pos = child;
                s2.push(&child);
            }

            var side2: i8 = if (handicap > 0) -1 else 1;

            // Replay all saved moves to reach the divergence position
            while (tok.next()) |mv_str| {
                const mv = std.fmt.parseInt(u8, mv_str, 10) catch break;
                const cell: ?usize = if (mv == 0) null else mv - 1;
                _ = try s2.applyMove(side2, cell);
                side2 = -side2;
            }

            // We're now at the exact position where the divergence was found
            const current_eval = s2.v0(&s2.pos, side2);
            total_positions += 1;

            const old_dist = if (stored_val > final_score) stored_val - final_score else final_score - stored_val;
            const new_dist = if (current_eval > final_score) current_eval - final_score else final_score - current_eval;

            if (new_dist < old_dist) {
                improved += 1;
            } else if (new_dist > old_dist) {
                worsened += 1;
            } else {
                unchanged += 1;
            }

            if (current_eval != final_score and current_eval != stored_val) {
                new_diverged += 1;
            }
        }

    }

    std.debug.print("\nreplay summary ({s}):\n", .{dir_path});
    std.debug.print("  total positions: {d}\n", .{total_positions});
    std.debug.print("  improved (closer to outcome):  {d}\n", .{improved});
    std.debug.print("  worsened (further from outcome): {d}\n", .{worsened});
    std.debug.print("  unchanged:                      {d}\n", .{unchanged});
    std.debug.print("  new divergences:                {d}\n", .{new_diverged});
}

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next(); // binary name

    var oracle_path: ?[]const u8 = null;
    var num_seeds: u64 = 100;
    var det: bool = false;
    var record: bool = false;
    var replay_dir: ?[]const u8 = null;

    while (args.next()) |a| {
        if (std.mem.eql(u8, a, "--record")) {
            record = true;
        } else if (std.mem.eql(u8, a, "--replay")) {
            replay_dir = args.next();
        } else if (std.mem.eql(u8, a, "det")) {
            det = true;
        } else if (oracle_path == null) {
            oracle_path = a;
        } else {
            num_seeds = std.fmt.parseInt(u64, a, 10) catch 100;
        }
    }

    const path = oracle_path orelse "data/oracle-4x4.wzo";
    var dec = try artifact.load(init.io, std.Io.Dir.cwd(), path, gpa);
    defer dec.deinit();

    const key = @as(usize, dec.header.board_w) * 100 + dec.header.board_h;

    if (replay_dir) |rd| {
        switch (key) {
            202 => try replayRegressions(2, 2, gpa, &dec, rd),
            302 => try replayRegressions(3, 2, gpa, &dec, rd),
            303 => try replayRegressions(3, 3, gpa, &dec, rd),
            403 => try replayRegressions(4, 3, gpa, &dec, rd),
            404 => try replayRegressions(4, 4, gpa, &dec, rd),
            603 => try replayRegressions(6, 3, gpa, &dec, rd),
            else => return error.UnsupportedBoard,
        }
        return;
    }

    std.debug.print("arena: {s} ({d}x{d}), {d} seeds x 2 colours x 3 handicaps\n", .{
        path, dec.header.board_w, dec.header.board_h, num_seeds,
    });

    switch (key) {
        202 => try runArena(2, 2, gpa, &dec, num_seeds, det, record),
        302 => try runArena(3, 2, gpa, &dec, num_seeds, det, record),
        303 => try runArena(3, 3, gpa, &dec, num_seeds, det, record),
        403 => try runArena(4, 3, gpa, &dec, num_seeds, det, record),
        404 => try runArena(4, 4, gpa, &dec, num_seeds, det, record),
        603 => try runArena(6, 3, gpa, &dec, num_seeds, det, record),
        else => return error.UnsupportedBoard,
    }
}
