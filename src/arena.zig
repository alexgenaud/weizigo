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
    leaks: u64 = 0,
    max_leak: i16 = 0,
    diverged_games: u64 = 0,
    diverged_events: u64 = 0,
    audited_won: u64 = 0,
    audited_held: u64 = 0, // final score == best promise (exactly kept)
};

fn runArena(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator, dec: *const artifact.Decoded, num_seeds: u64) !void {
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
                var moves_rec: [PLY_CAP]u8 = undefined; // cell+1, 0 = pass
                var ply: usize = 0;

                while (s.passes < 2 and ply < PLY_CAP) : (ply += 1) {
                    // candidate enumeration (pass always included)
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
                        cells[cnt] = cell;
                        vals[cnt] = s.v0(&child, -side);
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
                        if (audited_color > 0) {
                            if (stored > promise) promise = stored;
                        } else if (stored < promise) promise = stored;
                        if (best != stored) diverged += 1;
                        var opt_count: usize = 0;
                        for (vals[0..cnt], 0..) |v, i| {
                            if (v == best) {
                                opt_count += 1;
                                if (rnd.uintLessThan(usize, opt_count) == 0) pick = i;
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
                const leak: i16 = if (audited_color > 0) promise - score else score - promise;
                if (leak > 0) {
                    stats[pi].leaks += 1;
                    if (leak > stats[pi].max_leak) stats[pi].max_leak = leak;
                    p("LEAK {d} pts | persona {s} | seed {d} | audited {s} | handicap {d} | promise {d} final {d} | diverged-events {d}\n  moves:", .{
                        leak, persona.name, seed, if (audited_color > 0) "B" else "W", handicap, promise, score, diverged,
                    });
                    for (moves_rec[0..ply]) |m| {
                        if (m == 0) {
                            p(" pass", .{});
                        } else {
                            p(" {s}", .{gtp.vertex_from_cell(&vbuf, m - 1, w, h)});
                        }
                    }
                    p("\n", .{});
                }
            }
        }
        }
    }

    p("\narena summary (per opponent persona):\n", .{});
    for (PERSONAS, 0..) |persona, pi| {
        p("  {s:<13} games={d:>5} capped={d} audited-won={d:>5} held-exact={d:>5} LEAKS={d} (max {d}) diverged {d}/{d}\n", .{
            persona.name, stats[pi].games, stats[pi].capped, stats[pi].audited_won, stats[pi].audited_held,
            stats[pi].leaks, stats[pi].max_leak, stats[pi].diverged_games, stats[pi].diverged_events,
        });
    }
}

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    const path = args.next() orelse "data/oracle-4x4.wzo";
    const num_seeds = if (args.next()) |a| try std.fmt.parseInt(u64, a, 10) else 100;

    var dec = try artifact.load(init.io, std.Io.Dir.cwd(), path, gpa);
    defer dec.deinit();
    std.debug.print("arena: {s} ({d}x{d}), {d} seeds x 2 colours x 3 handicaps\n", .{
        path, dec.header.board_w, dec.header.board_h, num_seeds,
    });

    const key = @as(usize, dec.header.board_w) * 100 + dec.header.board_h;
    switch (key) {
        202 => try runArena(2, 2, gpa, &dec, num_seeds),
        302 => try runArena(3, 2, gpa, &dec, num_seeds),
        303 => try runArena(3, 3, gpa, &dec, num_seeds),
        404 => try runArena(4, 4, gpa, &dec, num_seeds),
        else => return error.UnsupportedBoard,
    }
}
