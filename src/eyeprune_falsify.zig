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
// Task: ADR0006-FALSIFY · Role: worker · Model: not stated at dispatch · Date: 2026-07-29
//
// Direct falsification test for ADR-0006 (eye-prune). Enumerates all 3x3
// positions with at least one Benson-alive true eye, then computes the
// game-theoretic fresh-start score with and without the eye-prune via
// forward minimax under positional superko. Reports every disagreement.
// Includes a calibration case (synthetic wrong prune) so a clean pass is
// distinguishable from a test that cannot detect a genuine error.
//
// Build: zig build-exe -O ReleaseFast src/eyeprune_falsify.zig
// Run:   tools/runner -- ./zig-out/bin/weizigo-eyeprune-falsify

const std = @import("std");
const R = @import("rules.zig").Rules(3, 3);
const X = @import("colex.zig").Indexer(3, 3);
const E = @import("enumerate.zig").Enumerator(3, 3);

const Pos = R.Pos;
const n = 9;

const UNDEF: i8 = -128;
const MEMO_KEYS = X.total * 2 * 2; // 19683 x 2 sides x 2 passes = 78732
const MAX_LINE = 32768;

// ---- aliases for brevity ---------------------------------------------------
const print = std.debug.print;

// ---- history (positional superko) -------------------------------------------

const History = struct {
    boards: [MAX_LINE]Pos = undefined,
    len: usize = 0,

    fn reset(self: *History) void { self.len = 0; }
    fn push(self: *History, b: *const Pos) void {
        if (self.len >= MAX_LINE) @panic("eyeprune_falsify: line exceeded MAX_LINE");
        self.boards[self.len] = b.*;
        self.len += 1;
    }
    fn pop(self: *History) void { self.len -= 1; }
    fn repeats(self: *const History, b: *const Pos) bool {
        var i: usize = 0;
        while (i < self.len) : (i += 1) {
            if (std.mem.eql(i8, &self.boards[i], b)) return true;
        }
        return false;
    }
};

// ---- memo -------------------------------------------------------------------

fn memoKey(idx: u64, to_move: i8, passes: u8) usize {
    return @intCast((idx << 2) | (@as(u64, @intFromBool(to_move <= 0)) << 1) | @as(u64, passes));
}

// ---- forward minimax solver --------------------------------------------------
//
// Semantics match oracle.zig's solve: area scoring, double-pass / is_settled
// terminals, positional superko. The only tunable is whether the eye-prune is
// applied.

const Solver = struct {
    memo: [MEMO_KEYS]i8,
    use_eyeprune: bool,
    cal_skip: ?usize, // calibration: additionally skip this non-eye cell
    nodes: u64 = 0,

    fn init(use_eyeprune: bool) Solver {
        return Solver{ .memo = [_]i8{UNDEF} ** MEMO_KEYS, .use_eyeprune = use_eyeprune, .cal_skip = null };
    }

    fn initCal(skip_cell: usize) Solver {
        return Solver{ .memo = [_]i8{UNDEF} ** MEMO_KEYS, .use_eyeprune = true, .cal_skip = skip_cell };
    }

    fn solve(self: *Solver, pos: *const Pos, to_move: i8, passes: u8, hist: *History) i8 {
        self.nodes += 1;
        if (passes >= 2) return R.area_score(pos);
        if (R.is_settled(pos)) return R.area_score(pos);

        const idx = X.colex_from_pos(pos);
        const key = memoKey(idx, to_move, passes);
        if (self.memo[key] != UNDEF) return self.memo[key];

        const maximizing = to_move > 0;
        var best: i8 = if (maximizing) -127 else 127;

        const own_alive = if (self.use_eyeprune) R.benson_alive(pos, to_move) else [_]bool{false} ** n;

        for (0..n) |cell| {
            if (pos[cell] != 0) continue;
            // eye-prune: skip filling own Benson-alive true eye
            if (self.use_eyeprune and R.is_own_eye(pos, cell, to_move, &own_alive)) continue;
            // calibration wrong prune: skip a non-eye cell
            if (self.cal_skip) |cal| {
                if (cell == cal and !R.is_own_eye(pos, cell, to_move, &own_alive)) continue;
            }

            const child = R.pos_from_move(pos, to_move, cell) catch continue;
            if (hist.repeats(&child)) continue;
            hist.push(&child);
            const v = self.solve(&child, -to_move, 0, hist);
            hist.pop();

            if (maximizing) {
                if (v > best) best = v;
            } else {
                if (v < best) best = v;
            }
        }
        // pass (board unchanged, exempt from superko — standard Go rules)
        {
            const vp = self.solve(pos, -to_move, passes + 1, hist);
            if (maximizing) {
                if (vp > best) best = vp;
            } else {
                if (vp < best) best = vp;
            }
        }

        self.memo[key] = best;
        return best;
    }

    /// Fresh-start value: root board in history, no passes, side to move.
    fn value(self: *Solver, pos: *const Pos, to_move: i8) i8 {
        var hist = History{};
        hist.push(pos);
        return self.solve(pos, to_move, 0, &hist);
    }
};

// ---- eye detection -----------------------------------------------------------

fn countEyes(pos: *const Pos, colour: i8, alive: *const [n]bool) u32 {
    var cnt: u32 = 0;
    for (0..n) |cell| {
        if (pos[cell] == 0 and R.is_own_eye(pos, cell, colour, alive)) cnt += 1;
    }
    return cnt;
}

fn hasBensonEye(pos: *const Pos) bool {
    const balive = R.benson_alive(pos, 1);
    const walive = R.benson_alive(pos, -1);
    return countEyes(pos, 1, &balive) > 0 or countEyes(pos, -1, &walive) > 0;
}

// ---- formatting --------------------------------------------------------------

fn printBoard(pos: *const Pos) void {
    for (0..3) |r| {
        for (0..3) |c| {
            const cell = pos[r * 3 + c];
            const ch: u8 = if (cell > 0) 'X' else if (cell < 0) 'O' else '.';
            print("{c} ", .{ch});
        }
        print("\n", .{});
    }
}

fn printAlive(label: []const u8, alive: *const [n]bool) void {
    print("{s}", .{label});
    for (0..n) |i| {
        if (alive[i]) print("{d} ", .{i});
    }
    print("\n", .{});
}

// ---- main: exhaustive falsification ------------------------------------------

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    print("=== ADR0006-FALSIFY: eye-prune falsification test (3x3 exhaustive) ===\n", .{});
    print("Model: not stated at dispatch  Date: 2026-07-29\n\n", .{});

    // ---- Phase 1: enumerate positions with Benson-alive true eyes -----------

    print("Phase 1: enumerating 3x3 positions with Benson-alive true eyes...\n", .{});

    var eye_positions: std.ArrayList(Pos) = .empty;
    defer eye_positions.deinit(alloc);

    {
        var digits = [_]u8{0} ** n;
        var pos: Pos = [_]i8{0} ** n;
        var stones: usize = 0;
        while (true) {
            if (E.is_legal(&pos) and hasBensonEye(&pos)) {
                try eye_positions.append(alloc, pos);
            }
            var i: usize = 0;
            while (i < n) : (i += 1) {
                if (digits[i] == 2) {
                    digits[i] = 0;
                    pos[i] = 0;
                    stones -= 1;
                    continue;
                }
                digits[i] += 1;
                if (digits[i] == 1) {
                    pos[i] = 1;
                    stones += 1;
                } else pos[i] = -1;
                break;
            }
            if (i == n) break;
        }
    }

    const N = eye_positions.items.len;
    print("  {d} positions have >= 1 Benson-alive true eye (out of 12_675 legal)\n\n", .{N});

    // ---- Phase 2: compare scores with vs without eye-prune ------------------

    print("Phase 2: computing scores with and without eye-prune for each position...\n", .{});

    var disagreements: u32 = 0;
    var total_checked: u32 = 0;
    var total_nodes_with: u64 = 0;
    var total_nodes_without: u64 = 0;
    const prog_every: u32 = if (N > 100) @intCast(N / 20) else 1;

    for (eye_positions.items, 0..) |pos, idx| {
        const balive = R.benson_alive(&pos, 1);
        const walive = R.benson_alive(&pos, -1);
        const b_has_eye = countEyes(&pos, 1, &balive) > 0;
        const w_has_eye = countEyes(&pos, -1, &walive) > 0;

        // Side(s) where the prune matters: the mover owns at least one eye.
        var sides: [2]i8 = undefined;
        var nsides: usize = 0;
        if (b_has_eye) { sides[nsides] = 1; nsides += 1; }
        if (w_has_eye) { sides[nsides] = -1; nsides += 1; }

        for (sides[0..nsides]) |side| {
            var solver_with = Solver.init(true);
            var solver_without = Solver.init(false);

            const val_with = solver_with.value(&pos, side);
            const val_without = solver_without.value(&pos, side);

            total_nodes_with += solver_with.nodes;
            total_nodes_without += solver_without.nodes;
            total_checked += 1;

            if (val_with != val_without) {
                disagreements += 1;
                print("--- DISAGREEMENT #{d} ---\n", .{disagreements});
                print("Board:\n", .{});
                printBoard(&pos);
                print("Side to move: {s}\n", .{if (side > 0) "Black" else "White"});
                print("Score WITH eye-prune:    {d}\n", .{val_with});
                print("Score WITHOUT eye-prune: {d}\n", .{val_without});
                print("Delta: {d}\n", .{val_with - val_without});
                printAlive("Benson Black alive: ", &balive);
                printAlive("Benson White alive: ", &walive);
                print("\n", .{});
            }
        }

        if ((idx + 1) % prog_every == 0) {
            print("  progress: {d}/{d} positions, {d} disagreements so far\n", .{ idx + 1, N, disagreements });
        }
    }

    print("\nPhase 2 complete. {d} (position, side) pairs checked.\n", .{total_checked});
    print("  Disagreements: {d}\n", .{disagreements});
    print("  Total search nodes (with prune):    {d}\n", .{total_nodes_with});
    print("  Total search nodes (without prune): {d}\n", .{total_nodes_without});

    // ---- Phase 3: calibration — synthetic wrong prune -----------------------
    //
    // We plant a wrong prune: for positions with eyes, additionally forbid
    // playing in a specific cell that is NOT an eye. This should produce a
    // disagreement on at least one position. If it passes clean, the checker
    // cannot distinguish "the eye-prune is sound" from "the checker is blind."

    print("\nPhase 3: calibration -- synthetic wrong prune...\n", .{});

    if (eye_positions.items.len == 0) {
        print("  SKIP: no eye-positions to calibrate on -- test is vacuous\n", .{});
    } else {
        // Try multiple wrong-prune candidates until we find one that changes
        // the score, proving the harness can detect a real error.
        const MAX_CAL_TRIES = 200;
        var cal_success: bool = false;
        var cal_tried: u32 = 0;

        for (eye_positions.items) |cand| {
            if (cal_success or cal_tried >= MAX_CAL_TRIES) break;
            inline for (.{ @as(i8, 1), @as(i8, -1) }) |cs| {
                if (cal_success or cal_tried >= MAX_CAL_TRIES) break;
                const alive = R.benson_alive(&cand, cs);
                for (0..n) |p1| {
                    if (cal_success or cal_tried >= MAX_CAL_TRIES) break;
                    if (cand[p1] != 0) continue;
                    if (R.is_own_eye(&cand, p1, cs, &alive)) continue;
                    _ = R.pos_from_move(&cand, cs, p1) catch continue;

                    cal_tried += 1;
                    var sc = Solver.init(true);
                    var sw = Solver.initCal(p1);
                    const vc = sc.value(&cand, cs);
                    const vw = sw.value(&cand, cs);

                    if (vc != vw) {
                        cal_success = true;
                        print("  Calibration position (skip cell {d}, side {s}):\n", .{ p1, if (cs > 0) "Black" else "White" });
                        printBoard(&cand);
                        print("  Score correct (eye-prune only): {d}\n", .{vc});
                        print("  Score wrong   (prune cell {d}): {d}\n", .{ p1, vw });
                        print("  CALIBRATION PASSED: wrong prune detected after {d} tries\n", .{cal_tried});
                    }
                }
            }
        }

        if (!cal_success) {
            print("  CALIBRATION FAILED: tried {d} wrong-prune candidates, none changed the score\n", .{cal_tried});
            print("  The checker cannot distinguish 'eye-prune is sound' from 'checker is blind'\n", .{});
        }
    }

    // ---- Phase 4: wrong-answer pass rate ------------------------------------

    print("\nPhase 4: wrong-answer pass rate estimate...\n", .{});

    const WRONG_SAMPLES: u32 = if (N > 100) 100 else @intCast(N);
    var wrong_pass: u32 = 0;
    var wrong_total: u32 = 0;
    var rng = std.Random.DefaultPrng.init(0xAD0006);
    const rnd = rng.random();

    for (0..WRONG_SAMPLES) |_| {
        const ri = rnd.intRangeLessThan(usize, 0, eye_positions.items.len);
        const rpos = eye_positions.items[ri];
        const rside: i8 = if (rnd.boolean()) 1 else -1;
        const ralive = R.benson_alive(&rpos, rside);

        var non_eye_cells: [n]usize = undefined;
        var non_eye_cnt: usize = 0;
        for (0..n) |p2| {
            if (rpos[p2] != 0) continue;
            if (R.is_own_eye(&rpos, p2, rside, &ralive)) continue;
            _ = R.pos_from_move(&rpos, rside, p2) catch continue;
            non_eye_cells[non_eye_cnt] = p2;
            non_eye_cnt += 1;
        }
        if (non_eye_cnt == 0) continue;

        const skip_cell = non_eye_cells[rnd.intRangeLessThan(usize, 0, non_eye_cnt)];

        var sc = Solver.init(true);
        var sw = Solver.initCal(skip_cell);
        const vc = sc.value(&rpos, rside);
        const vw = sw.value(&rpos, rside);
        wrong_total += 1;
        if (vc == vw) wrong_pass += 1;
    }

    if (wrong_total > 0) {
        print("  Wrong-prune samples: {d}\n", .{wrong_total});
        const rate: f64 = @as(f64, @floatFromInt(wrong_pass)) / @as(f64, @floatFromInt(wrong_total)) * 100.0;
        print("  Wrong-prune pass rate (same score despite wrong prune): {d}/{d} = {d:.1}%\n", .{ wrong_pass, wrong_total, rate });
    } else {
        print("  SKIP: no positions with non-eye legal moves for wrong-prune sampling\n", .{});
    }

    // ---- Final report -------------------------------------------------------

    print("\n========================================\n", .{});
    print("ADR0006-FALSIFY RESULT (3x3 exhaustive)\n", .{});
    print("========================================\n", .{});
    print("Eye-positions (denominator): {d}\n", .{N});
    print("(position, side) pairs checked: {d}\n", .{total_checked});
    print("Disagreements: {d}\n", .{disagreements});
    if (disagreements == 0) {
        print("VERDICT: ADR-0006 eye-prune passes exhaustive 3x3 -- no score changes detected\n", .{});
        print("CAVEAT: result is scoped to 3x3 only; see per-board epistemic independence (AGENTS.md)\n", .{});
    } else {
        print("VERDICT: ADR-0006 eye-prune FALSIFIED at 3x3 -- {d} disagreements found\n", .{disagreements});
    }
    print("\n", .{});

    // ---- Provenance (stdout, copy-paste into docs/evidence/ADR-0006/) ------

    print("\n--- PROVENANCE (copy below this line) ---\n", .{});
    print("# PROVENANCE -- ADR0006 eye-prune falsification (3x3 exhaustive)\n", .{});
    print("\n", .{});
    print("- **Claim:** ADR-0006\n", .{});
    print("- **Board:** 3x3 (exhaustive)\n", .{});
    print("- **Total eye-positions:** {d}\n", .{N});
    print("- **(position, side) pairs checked:** {d}\n", .{total_checked});
    print("- **Disagreements:** {d}\n", .{disagreements});
    print("- **Total search nodes (with prune):** {d}\n", .{total_nodes_with});
    print("- **Total search nodes (without prune):** {d}\n", .{total_nodes_without});
    print("- **Calibration wrong-prune pass rate:** {d}/{d}\n", .{ wrong_pass, wrong_total });
    print("- **Date:** 2026-07-29\n", .{});
    print("- **Model:** not stated at dispatch\n", .{});
    print("- **Task:** ADR0006-FALSIFY set M\n", .{});
    print("- **Source:** src/eyeprune_falsify.zig\n", .{});
    print("- **Ko rule:** positional superko (matches oracle.zig)\n", .{});
    print("- **Scoring:** area (Chinese), Black-positive\n", .{});
    print("- **Terminal:** double pass or is_settled\n", .{});
    print("\n", .{});
    print("--- PROVENANCE (copy above this line) ---\n", .{});
}
