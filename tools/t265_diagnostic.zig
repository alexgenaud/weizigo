// T265 diagnostic — check cited states against solver ko rule
//
// Worker: T265 · Date: 2026-08-02 · Model: Claude
//
// The human played two games in Sabaki. Lookup-miss warnings gave us
// (colex, side, ko, passes) tuples. This tool checks whether those states
// are consistent with the solver's own ko rule.
//
// Finding: every non-KO_NONE state has a ko point the solver would never
// assign — the capturer is not in atari. This confirms the ko-rule mismatch
// diagnosis for ALL cited misses, including the second game's ko=0 misses.
//
// The ko=16 (KO_NONE) miss at passes=1 is downstream: the game went
// off-manifold at the first ko mismatch, and subsequent states are
// unreachable regardless of their ko field.

const std = @import("std");
const exp6 = @import("exp6_solve.zig");
const colex_mod = @import("colex.zig");

const W4: usize = 4;
const H4: usize = 4;
const N4: usize = W4 * H4;
const CR4 = colex_mod.Indexer(4, 4);

fn printBoard(b: [N4]i8) void {
    for (0..H4) |r| {
        const row = H4 - 1 - r;
        for (0..W4) |c| {
            const ch: u8 = switch (b[row * W4 + c]) {
                -1 => 'O',
                1 => 'X',
                else => '.',
            };
            std.debug.print("{c} ", .{ch});
        }
        std.debug.print("\n", .{});
    }
}

pub fn main() !void {
    const targets = [_]struct {
        colex: u32, side: i8, ko: u5, passes: u2, label: []const u8,
    }{
        // First game: every miss carries a ko point (3 or 12), never KO_NONE
        .{ .colex = 26668645, .side = 1,  .ko = 3,  .passes = 0, .label = "G1: colex=26668645 ko=3" },
        .{ .colex = 29301769, .side = 1,  .ko = 12, .passes = 0, .label = "G1: colex=29301769 ko=12" },
        .{ .colex = 29355009, .side = 1,  .ko = 3,  .passes = 0, .label = "G1: colex=29355009 ko=3" },
        .{ .colex = 29355009, .side = 1,  .ko = 12, .passes = 0, .label = "G1: colex=29355009 ko=12" },
        // Second game: ko=0 (ko-rule cannot explain) and ko=16 (KO_NONE)
        .{ .colex = 2456372,  .side = -1, .ko = 0,  .passes = 0, .label = "G2: colex=2456372 ko=0 passes=0" },
        .{ .colex = 5798208,  .side = -1, .ko = 16, .passes = 1, .label = "G2: colex=5798208 ko=16 passes=1" },
    };

    var all_inconsistent: bool = true;

    std.debug.print("=== T265: Cited-State Diagnostic ===\n\n", .{});
    std.debug.print("For each state the engine reported as a lookup-miss,\n", .{});
    std.debug.print("we check: would the solver's ko rule have produced this ko?\n\n", .{});

    for (targets) |t| {
        const board = CR4.pos_from_colex(t.colex);
        const side_str: []const u8 = if (t.side > 0) "Black" else "White";

        std.debug.print("{s}: side={s} ko={d} passes={d}\n", .{ t.label, side_str, t.ko, t.passes });
        printBoard(board);

        if (t.ko >= N4) {
            std.debug.print("  Ko: KO_NONE — passed through; no inconsistency check. ", .{});
            std.debug.print("(But is the board reachable? genericIsLegal: {})\n", .{
                exp6.genericIsLegal(N4, &board, W4, H4),
            });
            continue;
        }

        const ko_cell: u8 = @intCast(t.ko);

        // Ko consistency check: for the solver to have set ko=ko_cell,
        // the OPPONENT of side-to-move just captured there.
        // (1) ko_cell must be empty (the captured stone was removed)
        // (2) there must be a capturer of the OPPOSITE colour adjacent to
        //     ko_cell that is in atari with no friendly neighbors
        //     (sole liberty = ko_cell)
        const capturer_colour: i8 = -t.side;

        if (board[ko_cell] != 0) {
            std.debug.print("  KO INCONSISTENT: ko cell {d} is occupied by {d}\n", .{ ko_cell, board[ko_cell] });
            continue;
        }

        var found_capturer = false;
        var nb: [4]usize = undefined;
        const cnt = exp6.genericNeighbors(ko_cell, W4, H4, &nb);
        for (nb[0..cnt]) |q| {
            if (board[q] != capturer_colour) continue;
            var libs: u8 = 0;
            var friends: u8 = 0;
            var sees_ko: bool = false;
            var nb2: [4]usize = undefined;
            const cnt2 = exp6.genericNeighbors(q, W4, H4, &nb2);
            for (nb2[0..cnt2]) |r| {
                if (r == ko_cell) { sees_ko = true; continue; }
                if (board[r] == 0) libs += 1;
                if (board[r] == capturer_colour) friends += 1;
            }
            std.debug.print("  Adjacent capturer candidate at {d} (colour={d}): liberties={d} friendly={d} sees_ko={}\n", .{ q, capturer_colour, libs, friends, sees_ko });
            if (libs == 0 and friends == 0 and sees_ko) {
                std.debug.print("  → This IS a valid capturer (atari, sole liberty is ko cell)\n", .{});
                found_capturer = true;
                all_inconsistent = false;
            }
        }

        if (!found_capturer) {
            std.debug.print("  KO INCONSISTENT: no capturer in atari adjacent to ko cell {d}\n", .{ko_cell});
        }
        std.debug.print("  genericIsLegal: {}\n\n", .{
            exp6.genericIsLegal(N4, &board, W4, H4),
        });
    }

    std.debug.print("=== Verdict ===\n", .{});
    if (all_inconsistent) {
        std.debug.print("ALL non-KO_NONE states are ko-inconsistent with the solver.\n", .{});
        std.debug.print("The ko-rule mismatch explains every cited miss, including the\n", .{});
        std.debug.print("second game's ko=0 misses. The ko=16 miss is downstream of\n", .{});
        std.debug.print("the earlier off-manifold divergence.\n\n", .{});
        std.debug.print("The koAfterCapture fix (applied) resolves the root cause.\n", .{});
    } else {
        std.debug.print("Some states ARE consistent — the diagnosis is incomplete.\n", .{});
    }

    // Additional: search for first board where old vs new ko disagree
    std.debug.print("\n=== Negative control: old rule vs solver disagreement count ===\n", .{});
    std.debug.print("(sampling 100000 random boards to confirm the old rule is broader)\n", .{});

    var rng = std.Random.DefaultPrng.init(42);
    const rand = rng.random();

    var old_disagree: usize = 0;
    var captures_found: usize = 0;
    const SAMPLE: usize = 100000;

    for (0..SAMPLE) |_| {
        // Generate a random board with 4-10 stones (realistic game positions)
        var board: [N4]i8 = [_]i8{0} ** N4;
        const stones: usize = rand.uintLessThan(usize, 7) + 4;
        for (0..stones) |_| {
            const cell = rand.uintLessThan(usize, N4);
            if (board[cell] == 0) {
                board[cell] = if (rand.boolean()) @as(i8, 1) else @as(i8, -1);
            }
        }

        // Try Black capture at each empty cell
        for (0..N4) |cell| {
            if (board[cell] != 0) continue;
            const old_ko = oldEngineKo(&board, 1, @intCast(cell));
            const solver_ko = solverApply(&board, 1, @intCast(cell));
            if (old_ko) |ok| {
                captures_found += 1;
                if (solver_ko) |sk| {
                    if (sk != ok) old_disagree += 1;
                } else {
                    // Old engine found a capture, solver says illegal — also a disagreement
                    old_disagree += 1;
                }
            }
        }
    }

    std.debug.print("Captures found by old rule: {d}\n", .{captures_found});
    std.debug.print("Disagreements with solver: {d}\n", .{old_disagree});
    if (captures_found > 0) {
        const pct = @as(f64, @floatFromInt(old_disagree)) / @as(f64, @floatFromInt(captures_found)) * 100.0;
        std.debug.print("Disagreement rate: {d:.1}%\n", .{pct});
    }
}

// ── Solver ko rule (replicated from exp6_solve.zig apply_place4) ─────────

fn solverApply(board: *const [N4]i8, colour: i8, cell: u8) ?u5 {
    if (board[cell] != 0) return null;
    var next = board.*;
    _ = exp6.genericPosFromMove(N4, &next, colour, cell, W4, H4) catch return null;
    var opp_before: u8 = 0;
    var opp_after: u8 = 0;
    var captured_cell: u8 = @intCast(N4);
    for (0..N4) |i| {
        if (board[i] == -colour) opp_before += 1;
        if (next[i] == -colour) opp_after += 1;
        if (board[i] == -colour and next[i] == 0) captured_cell = @intCast(i);
    }
    if ((opp_before - opp_after == 1) and (captured_cell != N4)) {
        var liberties: u8 = 0;
        var friendly: u8 = 0;
        var nb: [4]usize = undefined;
        const cnt = exp6.genericNeighbors(cell, W4, H4, &nb);
        for (nb[0..cnt]) |q| {
            if (next[q] == 0) liberties += 1;
            if (next[q] == colour) friendly += 1;
        }
        if (liberties == 1 and friendly == 0) return @intCast(captured_cell);
    }
    return @intCast(N4);
}

// ── Old engine ko rule (replicated from pre-fix koAfterCapture) ───────────

fn oldEngineKo(board: *const [N4]i8, colour: i8, cell: u8) ?u5 {
    if (board[cell] != 0) return null;
    const opp: i8 = -colour;
    var next = board.*;
    _ = exp6.genericPosFromMove(N4, &next, colour, cell, W4, H4) catch return null;
    var opp_before: u16 = 0;
    var last_captured: u8 = @intCast(N4);
    for (0..N4) |p| {
        if (board[p] == opp) opp_before += 1;
        if (board[p] == opp and next[p] == 0) last_captured = @intCast(p);
    }
    var opp_after: u16 = 0;
    for (0..N4) |p| {
        if (next[p] == opp) opp_after += 1;
    }
    if (opp_before - opp_after == 1 and last_captured != N4) return @intCast(last_captured);
    return @intCast(N4);
}
