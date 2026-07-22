////////////////////////////////////////////
//                                        //
//    (c) 2024 Alexander E Genaud         //
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
// Self-contained ko / superko probe (all experimental code lives HERE, not in
// the solver). It walks legal 5x5 game lines with a positional-superko history
// and classifies every repetition ban by cycle length:
//
//   dist = history.len - matched_ply    (the banned board would sit at len)
//     dist == 2  -> simple ko    (the position before the opponent's last move;
//                                  a simple-ko rule already forbids it)
//     dist >= 3  -> SUPERKO      (only the whole-history rule catches it)
//
// It also captures a few replayable example games (reconstructed as move lists
// from the board history) and re-plays each independently through the engine to
// prove the banned move truly recreates an earlier position.
//
// Run:  zig build-exe -O ReleaseFast src/ko_probe.zig
//       ./ko_probe 2> docs/research/ko-examples.md
// (the markdown report is written to stderr via std.debug.print).
//
// The walk is bounded by a node cap and a line-depth cap; it explores messy
// capture play (no eye-prune) precisely because that is where kos live. It does
// NOT need the solver's minimax / TT / eye-prune, so it stays decoupled.

const std = @import("std");
const p = std.debug.print;
const state = @import("state.zig");
const superko = @import("superko.zig");

const NODE_CAP: u64 = 40_000_000;
const DEPTH_CAP: usize = 80; // keep recursion (== line length) shallow & safe
const MAX_EX_MOVES = DEPTH_CAP + 1;
const MAX_EACH = 6; // keep up to this many simple + this many superko examples

const Move = struct { p: u8, c: i8 };

const KoExample = struct {
    is_superko: bool = false,
    dist: usize = 0,
    start: [25]i8 = [_]i8{0} ** 25,
    moves: [MAX_EX_MOVES]Move = undefined,
    nmoves: usize = 0,
    banned: Move = .{ .p = 0, .c = 0 },
};

var history: superko.History = .{};
var nodes: u64 = 0;
var simple_ko_bans: u64 = 0;
var superko_bans: u64 = 0;
var max_cycle: usize = 0;
var simple_examples: [MAX_EACH]KoExample = undefined;
var superko_examples: [MAX_EACH]KoExample = undefined;
var n_simple: usize = 0;
var n_superko: usize = 0;

/// The single point added going from board `a` to `b` (captures only remove
/// stones, so the added stone is unique). 25 if none (never for a real move).
fn added_point(a: *const [25]i8, b: *const [25]i8) u8 {
    for (0..25) |i| {
        if (a[i] == 0 and b[i] != 0) return @intCast(i);
    }
    return 25;
}

fn record(banned_p: u8, to_move: i8, dist: usize) void {
    const is_super = dist >= 3;
    const slot = if (is_super) blk: {
        if (n_superko >= MAX_EACH) return;
        break :blk &superko_examples[n_superko];
    } else blk: {
        if (n_simple >= MAX_EACH) return;
        break :blk &simple_examples[n_simple];
    };
    slot.* = .{ .is_superko = is_super, .dist = dist };
    slot.start = history.board[0];
    slot.banned = .{ .p = banned_p, .c = to_move };
    var i: usize = 1;
    while (i < history.len and slot.nmoves < MAX_EX_MOVES) : (i += 1) {
        const pt = added_point(&history.board[i - 1], &history.board[i]);
        const c: i8 = if (history.board[i][pt] > 0) 1 else -1;
        slot.moves[slot.nmoves] = .{ .p = pt, .c = c };
        slot.nmoves += 1;
    }
    if (is_super) n_superko += 1 else n_simple += 1;
}

/// Depth-first walk of legal stone plays (passes never repeat a board, so they
/// are irrelevant to ko detection and omitted). `pos` is the top of `history`.
fn explore(pos: *const [25]i8, to_move: i8, depth: usize) void {
    nodes += 1;
    if (nodes > NODE_CAP or depth >= DEPTH_CAP) return;
    for (0..25) |cell| {
        if (pos[cell] != 0) continue;
        const child = state.armies_from_move(pos, to_move, @intCast(cell)) catch continue;
        if (history.repeatsIndex(&child)) |j| {
            const dist = history.len - j; // child would sit at index history.len
            if (dist <= 2) simple_ko_bans += 1 else superko_bans += 1;
            if (dist > max_cycle) max_cycle = dist;
            record(@intCast(cell), to_move, dist);
            continue;
        }
        history.push(&child);
        explore(&child, -to_move, depth + 1);
        history.pop();
    }
}

// ---- independent replay verification ----------------------------------------

fn same_pos(a: *const [25]i8, b: *const [25]i8) bool {
    for (0..25) |i| {
        const sa: i8 = if (a[i] > 0) 1 else if (a[i] < 0) -1 else 0;
        const sb: i8 = if (b[i] > 0) 1 else if (b[i] < 0) -1 else 0;
        if (sa != sb) return false;
    }
    return true;
}

/// Replay an example through the engine and confirm the banned move recreates
/// the board exactly `dist` plies back.
fn verify(ex: *const KoExample) bool {
    var line: [MAX_EX_MOVES + 1][25]i8 = undefined;
    line[0] = ex.start;
    var len: usize = 1;
    for (0..ex.nmoves) |i| {
        line[len] = state.armies_from_move(&line[len - 1], ex.moves[i].c, ex.moves[i].p) catch return false;
        len += 1;
    }
    const banned = state.armies_from_move(&line[len - 1], ex.banned.c, ex.banned.p) catch return false;
    return ex.dist <= len and same_pos(&banned, &line[len - ex.dist]);
}

// ---- reporting (markdown to stderr) -----------------------------------------

fn coord(idx: u8) void {
    p("{c}{d}", .{ 'A' + idx % 5, idx / 5 + 1 }); // columns A..E, rows 1..5
}

fn print_board(b: *const [25]i8) void {
    p("```\n", .{});
    for (0..5) |r| {
        for (0..5) |c| {
            const v = b[r * 5 + c];
            p("{s}", .{if (v > 0) " X" else if (v < 0) " O" else " ."});
        }
        p("\n", .{});
    }
    p("```\n", .{});
}

fn print_example(ex: *const KoExample, n: usize) void {
    p("### {s} example {d} — cycle length {d} — replay check: {s}\n\n", .{
        if (ex.is_superko) "SUPERKO" else "simple-ko", n, ex.dist,
        if (verify(ex)) "PASS ✓" else "FAIL ✗",
    });
    p("Start from (X=black, O=white), then play the moves:\n\n", .{});
    print_board(&ex.start);
    p("\n", .{});
    for (0..ex.nmoves) |i| {
        p("{d}. {s} ", .{ i + 1, if (ex.moves[i].c > 0) "X" else "O" });
        coord(ex.moves[i].p);
        p("   ", .{});
        if ((i + 1) % 5 == 0) p("\n", .{});
    }
    p("\n\nThe next move — {s} ", .{if (ex.banned.c > 0) "X" else "O"});
    coord(ex.banned.p);
    p(" — recreates the whole-board position from {d} plies back, so it is ", .{ex.dist});
    p("**illegal under positional superko** ({s}).\n\n", .{
        if (ex.is_superko) "a simple-ko rule would NOT catch this" else "an immediate recapture; simple ko catches it too",
    });
}

pub fn main() void {
    p("# Ko and superko examples on 5x5 (auto-generated by src/ko_probe.zig)\n\n", .{});
    p("X = black, O = white. Coordinates: columns A..E left→right, rows 1..5 top→bottom.\n", .{});
    p("Superko = a whole-board repetition whose cycle is longer than simple ko's\n", .{});
    p("2-ply recapture; only the full-history rule forbids it.\n\n", .{});

    const empty = [_]i8{0} ** 25;
    history.reset();
    history.push(&empty);
    explore(&empty, 1, 0);

    p("## Sample of legal play from the empty board\n\n", .{});
    p("- nodes walked: {d} (cap {d}), line-depth cap {d}\n", .{ nodes, NODE_CAP, DEPTH_CAP });
    p("- simple-ko bans (2-ply): {d}\n", .{simple_ko_bans});
    p("- **superko bans (cycle >= 3): {d}**\n", .{superko_bans});
    p("- longest cycle seen: {d} plies\n\n", .{max_cycle});

    p("---\n\n# Replayable examples\n\n", .{});
    p("Captured {d} superko and {d} simple-ko cycle(s), each verified by replay.\n\n", .{ n_superko, n_simple });
    for (0..n_superko) |n| print_example(&superko_examples[n], n + 1);
    for (0..n_simple) |n| print_example(&simple_examples[n], n + 1);
}
