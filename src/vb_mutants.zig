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
// VB_MUTANTS — mutation-testing fixtures for the verify-battery.
//
// Task: T291 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-03
//
// Each test constructs a synthetic WZO1 artifact corrupted to match one
// historical defect, feeds it to the named invariant check, and verifies
// the check kills it. Every output carries an EXPECTED marker.
//
// Per Amendment 1 (ratified 2026-08-03): mutants are synthetic — constructed
// in memory from a clean artifact, never written to data/ or artifacts/.
//
// Kill-verification for all ten catalogue mutants (M1–M10).
//   M1 (key-agreement, T530) · M2 (key-agreement, T530) · M3 (key-agreement,
//   T530 — inverted from SURVIVES) · M4 (key-agreement, T530) ·
//   M5 (I2) · M6 (I7) · M7 (I2) · M8 (C-A1/C-A2 closure, T363) ·
//   M9 (BATT-HEALTH meta-check, T347) · M10 (I11 null + seeded-defect, T363).
// Catalogue: docs/epic-01-markovian/sprints/verify-battery/pass1/mutants.md.

const std = @import("std");
const testing = std.testing;

const vb = @import("vb_common.zig");
const vb_table = @import("vb_table.zig");
const vb_fixpoint = @import("vb_fixpoint.zig");
const vb_health = @import("vb_health.zig");
const vb_closure = @import("vb_closure.zig");
const vb_i11 = @import("vb_i11.zig");

// Key-agreement machinery (producer kernel rules.stateKey / consumer R8
// vb_movegen.stateKey) — the T267/T345 invariant that kills M1/M2/M3/M4.
// rules/colex route through the shared engine shim (T341) so no engine file
// belongs to two modules; vb_movegen imports only std and is safe directly.
const engine = @import("engine");
const rules = engine.rules;
const colex_mod = engine.colex;
const vb_mg = @import("vb_movegen.zig");

// ─── helpers ───────────────────────────────────────────────────────────────

/// Read a WZO1 artifact file into owned bytes.
fn readArtifactBytes(gpa: std.mem.Allocator, path: []const u8) ![]u8 {
    var threaded = std.Io.Threaded.init(gpa, .{});
    defer threaded.deinit();
    const io = threaded.io();
    return try std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .unlimited);
}

/// Recompute and patch the CRC-32 in a WZO1 byte buffer.
fn patchCrc(bytes: []u8) void {
    var crc = std.hash.crc.Crc32IsoHdlc.init();
    crc.update(bytes[32..]);
    std.mem.writeInt(u32, bytes[28..32], crc.final(), .little);
}

/// WZO1 column offsets for a given total.
fn colOffsets(total: u64) struct {
    vb: u64,
    vw: u64,
    fb: u64,
    fw: u64,
    db: u64,
    dw: u64,
} {
    return .{
        .vb = 32,
        .vw = 32 + total,
        .fb = 32 + 2 * total,
        .fw = 32 + 3 * total,
        .db = 32 + 4 * total,
        .dw = 32 + 5 * total,
    };
}

// ─── key-agreement helpers (T530) ─────────────────────────────────────────

/// Base-3 lexicographic rank of a position: the odometer enumeration over
/// [0, 3^n). A DIFFERENT bijection than colex — the class of "wrong index
/// function" the T178 defect was (exp6 rank vs combinatorial colex). Used
/// as the M1 mutant's producer index function.
fn lexRank(comptime n_cells: usize, pos: [n_cells]i8) u64 {
    var r: u64 = 0;
    for (pos) |c| {
        r = r * 3 + @as(u64, @intCast(c + 1));
    }
    return r;
}

/// The pre-T265 ko rule (M3/M4 mutant): ANY single-stone capture sets ko at
/// the captured cell — no liberties==1 && friendly==0 test. Reproduces the
/// T265 `CODE.GTP-KOKEY` defect (and its ACCEPT-KOKEY twin) this fixture is
/// named for. Returns the captured cell, or ko_none (n_cells) otherwise.
fn oldKoRule(comptime n_cells: usize, comptime w: usize, comptime h: usize, board: [n_cells]i8, colour: i8, cell: u8) u8 {
    if (board[cell] != 0) return @intCast(n_cells);
    const R = rules.Rules(w, h);
    const next = R.pos_from_move(&board, colour, cell) catch return @intCast(n_cells);
    const opp: i8 = -colour;
    var opp_before: u8 = 0;
    var last_captured: u8 = @intCast(n_cells);
    for (0..n_cells) |p| {
        if (board[p] == opp) opp_before += 1;
        if (board[p] == opp and next[p] == 0) last_captured = @intCast(p);
    }
    var opp_after: u8 = 0;
    for (0..n_cells) |p| {
        if (next[p] == opp) opp_after += 1;
    }
    if (opp_before - opp_after == 1 and last_captured != n_cells) return last_captured;
    return @intCast(n_cells);
}

/// The corrected ko rule: move applied via the kernel rules.Rules, ko
/// delegated to the kernel's rules.koAfterCapture (liberties==1 &&
/// friendly==0, T273) — the single production implementation, not a copy.
fn correctedKoRule(comptime n_cells: usize, comptime w: usize, comptime h: usize, board: [n_cells]i8, colour: i8, cell: u8) u8 {
    if (board[cell] != 0) return @intCast(n_cells);
    const R = rules.Rules(w, h);
    const next = R.pos_from_move(&board, colour, cell) catch return @intCast(n_cells);
    return rules.koAfterCapture(&board, &next, colour, w, h, @intCast(n_cells));
}

/// Apply Black's placement at `cell`; null if illegal.
fn applyMove(comptime n_cells: usize, comptime w: usize, comptime h: usize, board: [n_cells]i8, cell: usize) ?[n_cells]i8 {
    const R = rules.Rules(w, h);
    return R.pos_from_move(&board, 1, cell) catch null;
}

/// The T345 key-agreement comparison: field-by-field inequality of the
/// producer key (kernel rules.stateKey) and the consumer key (R8
/// vb_movegen.stateKey). Both StateKey types carry the same field set;
/// any field difference is a key-agreement mismatch.
fn keyDisagrees(a: anytype, b: anytype) bool {
    return a.colex_idx != b.colex_idx or
        a.side != b.side or
        a.ko != b.ko or
        a.passes != b.passes or
        a.terminal != b.terminal;
}

// ─── M1 — T178: colex vs combinatorial rank → KILLED by key-agreement ──────

// M1's mutation: the producer builds its key with the WRONG index function on
// one side — one column's values sit at combinatorial-rank indices instead of
// colex indices. The key-agreement invariant (T267/T345) compares the
// producer's colex against the consumer's independently re-encoded colex
// (vb_movegen.colexFromPos). The M1 mutant substitutes a different bijection
// — the base-3 lexicographic rank, the same "rank vs colex" confusion T178
// was — and the keys MUST disagree.

test "M1-T178 colex-vs-rank KILLED by key-agreement (red, then green)" {
    const w: usize = 2;
    const h: usize = 2;
    const n: usize = 4;
    const ko_none: u8 = 4;
    const board = [4]i8{ 1, -1, 0, 0 }; // B at 0, W at 1 — legal 2×2 position
    const C = colex_mod.Indexer(w, h);
    const correct_colex = C.colex_from_pos(&board);
    const wrong_rank = lexRank(n, board);

    // Non-vacuity: the mutant's index function must actually differ from
    // colex on this input, or the fixture exercises nothing.
    std.debug.print("[EXPECTED] M1-T178: colex={d} lexRank={d}\n", .{ correct_colex, wrong_rank });
    try testing.expect(wrong_rank != correct_colex);

    // RED: producer key built with the rank instead of colex → disagrees
    // with the consumer, which re-encodes the position through its own colex.
    const pk_mutant = rules.stateKey(wrong_rank, 1, ko_none, 0);
    const ck = vb_mg.stateKey(w, h, vb_mg.State(w, h){ .pos = board, .side = 1, .ko = ko_none, .passes = 0 });
    std.debug.print("[EXPECTED] M1-T178 RED: producer(colex={d}) vs consumer(colex={d}) disagree={}\n", .{ wrong_rank, correct_colex, keyDisagrees(pk_mutant, ck) });
    try testing.expect(keyDisagrees(pk_mutant, ck));

    // GREEN: producer uses colex → keys agree.
    const pk_green = rules.stateKey(correct_colex, 1, ko_none, 0);
    try testing.expect(!keyDisagrees(pk_green, ck));
    std.debug.print("[EXPECTED] M1-T178 GREEN: producer(colex={d}) vs consumer agree\n", .{correct_colex});
}

// ─── M2 — T193: passes bit dropped → KILLED by key-agreement ───────────────

// M2's mutation: the passes bit is dropped in the producer's key byte — a
// passes=1 state lands at the passes=0 index. The key-agreement comparison
// includes the passes field; the mutant producer encodes passes=1 as
// passes=0 and the keys MUST disagree.

test "M2-T193 passes-bit KILLED by key-agreement (red, then green)" {
    // State from real play: empty board, White to move, ko=NONE, passes=1
    // (reachable by Black passing first). The producer must encode passes=1.
    const w: usize = 2;
    const h: usize = 2;
    const ko_none: u8 = 4;
    const board = [4]i8{ 0, 0, 0, 0 };
    const C = colex_mod.Indexer(w, h);
    const colex_empty = C.colex_from_pos(&board);
    const side_white: i8 = -1;

    // Non-vacuity: passes=1 must be distinguishable from passes=0 — the key
    // fields differ iff the producer drops the bit.
    const pk_correct = rules.stateKey(colex_empty, side_white, ko_none, 1);
    const pk_mutant = rules.stateKey(colex_empty, side_white, ko_none, 0);
    try testing.expect(pk_correct.passes != pk_mutant.passes);

    const ck = vb_mg.stateKey(w, h, vb_mg.State(w, h){ .pos = board, .side = side_white, .ko = ko_none, .passes = 1 });
    std.debug.print("[EXPECTED] M2-T193: producer(passes=1) vs consumer(passes=1) agree={} ; mutant producer(passes=0) disagree={}\n", .{ !keyDisagrees(pk_correct, ck), keyDisagrees(pk_mutant, ck) });

    // RED: mutant producer dropped the passes bit → keys disagree.
    try testing.expect(keyDisagrees(pk_mutant, ck));
    // GREEN: correct producer → keys agree.
    try testing.expect(!keyDisagrees(pk_correct, ck));
}

// ─── M3 — T265: ko set too broadly → KILLED by key-agreement (T530) ────────

// M3's mutation: the ko key is computed with the pre-T265 rule (ANY
// single-stone capture sets ko) instead of the liberties==1 && friendly==0
// test — the artifact tags states as ko-sensitive when they are not in any
// ko cycle.
//
// I5 (SCC containment) cannot kill it on 2×2/3×2/4×3: every legal passes=0
// state is cycle-reachable there, so a spuriously-set KO_SENSITIVE flag is
// never non-cycle-reachable. The first non-vacuous I5 rung is 4×4, whose
// artifact-level red-then-green (spurious L!=H on a non-cycle-reachable
// entry) already lives in src/vb_scc_4x4.zig. The proper killer the
// catalogue names is the T267 key-agreement invariant (G1/G3): producer and
// consumer must build the same (colex, side, ko, passes, terminal) key for
// a state from real play.
//
// The input that exposes M3: a position where a single-stone capture occurs
// but the corrected rule says NO ko (the capturing stone keeps >1 liberty).
// The old rule tags the state ko-sensitive (ko = captured cell); the
// corrected rule says ko=NONE. The two keys disagree → the key-agreement
// check kills the mutant.

test "M3-T265 ko-too-broad KILLED by key-agreement (red, then green)" {
    // Witness (2×2): board [empty, B, empty, W], Black plays cell 2 —
    // captures the W stone at cell 3 (single capture), but the capturing
    // stone keeps two liberties (cells 0 and 3 after the capture), so the
    // corrected rule returns ko=NONE while the old rule spuriously returns
    // ko=3. This is the M3 mutant applied to a state from real play.
    const w: usize = 2;
    const h: usize = 2;
    const n: usize = 4;
    const ko_none: u8 = 4;
    const board = [4]i8{ 0, 1, 0, -1 };
    const cell: u8 = 2;

    const next = applyMove(n, w, h, board, cell) orelse {
        std.debug.print("[M3] witness move illegal — fixture broken\n", .{});
        return error.FixtureWitnessIllegal;
    };

    const corrected_ko = correctedKoRule(n, w, h, board, 1, cell);
    const old_ko = oldKoRule(n, w, h, board, 1, cell);
    std.debug.print("[EXPECTED] M3-T265: corrected_ko={d} old_ko={d} (old rule MUST spuriously set ko here)\n", .{ corrected_ko, old_ko });
    // Non-vacuity: the mutant must actually differ from the corrected rule
    // on this input, or the fixture exercises nothing.
    try testing.expectEqual(ko_none, corrected_ko);
    try testing.expect(old_ko != corrected_ko);

    const C = colex_mod.Indexer(w, h);
    const result_colex = C.colex_from_pos(&next);

    // RED: producer uses the M3 mutant ko rule → key disagrees with the
    // consumer (corrected rule). The key-agreement check must fire.
    const pk_mutant = rules.stateKey(result_colex, -1, old_ko, 0);
    const ck = vb_mg.stateKey(w, h, vb_mg.State(w, h){ .pos = next, .side = -1, .ko = corrected_ko, .passes = 0 });
    std.debug.print("[EXPECTED] M3-T265 RED: producer(mutant ko={d}) vs consumer(ko={d}) disagree={}\n", .{ old_ko, corrected_ko, keyDisagrees(pk_mutant, ck) });
    try testing.expect(keyDisagrees(pk_mutant, ck));

    // GREEN: producer uses the corrected rule → keys agree.
    const pk_green = rules.stateKey(result_colex, -1, corrected_ko, 0);
    try testing.expect(!keyDisagrees(pk_green, ck));
    std.debug.print("[EXPECTED] M3-T265 GREEN: producer(corrected ko={d}) vs consumer agree\n", .{corrected_ko});
}

// ─── M4 — CODE.ACCEPT-KOKEY: old ko rule restored in one consumer → KILLED ─

// M4's mutation: the pre-T265 ko rule (any single-stone capture → ko) is
// restored in ONE consumer while the other uses the corrected rule. Both
// consumers must build the same key for the same state; with the old rule
// in one of them, the keys MUST disagree.

test "M4-ACCEPT-KOKEY old-ko-consumer KILLED by key-agreement (red, then green)" {
    // Witness (2×2): board [empty, empty, B, W], Black plays cell 1 —
    // captures the W stone at cell 3; the capturing stone keeps two
    // liberties, so the corrected rule says ko=NONE while the restored old
    // rule says ko=3. Same defect class as M3, but on the CONSUMER side:
    // two consumers of the acceptance harness disagree on the same state.
    const w: usize = 2;
    const h: usize = 2;
    const n: usize = 4;
    const ko_none: u8 = 4;
    const board = [4]i8{ 0, 0, 1, -1 };
    const cell: u8 = 1;

    const next = applyMove(n, w, h, board, cell) orelse {
        std.debug.print("[M4] witness move illegal — fixture broken\n", .{});
        return error.FixtureWitnessIllegal;
    };

    const corrected_ko = correctedKoRule(n, w, h, board, 1, cell);
    const old_ko = oldKoRule(n, w, h, board, 1, cell);
    try testing.expectEqual(ko_none, corrected_ko);
    try testing.expect(old_ko != corrected_ko);

    // RED: consumer A (mutant, old rule) vs consumer B (corrected rule) —
    // the two consumers produce different keys for the same state.
    const key_a = vb_mg.stateKey(w, h, vb_mg.State(w, h){ .pos = next, .side = -1, .ko = old_ko, .passes = 0 });
    const key_b = vb_mg.stateKey(w, h, vb_mg.State(w, h){ .pos = next, .side = -1, .ko = corrected_ko, .passes = 0 });
    std.debug.print("[EXPECTED] M4-ACCEPT-KOKEY RED: consumerA(old ko={d}) vs consumerB(corrected ko={d}) disagree={}\n", .{ old_ko, corrected_ko, keyDisagrees(key_a, key_b) });
    try testing.expect(keyDisagrees(key_a, key_b));

    // GREEN: both consumers use the corrected rule → keys agree.
    const key_a_green = vb_mg.stateKey(w, h, vb_mg.State(w, h){ .pos = next, .side = -1, .ko = corrected_ko, .passes = 0 });
    try testing.expect(!keyDisagrees(key_a_green, key_b));
    std.debug.print("[EXPECTED] M4-ACCEPT-KOKEY GREEN: both consumers corrected → agree\n", .{});
}

// ─── M5 — T283: wrong side after move → GAP G1/G3, no killer ───────────────

// M5 — T283: wrong side after move → KILLED by I2 (column-wide negation)
//
// Column-wide negation models the side-not-advanced defect: values
// computed for the wrong player break the sign-antisymmetry I2 checks.
// Note: the proper, comprehensive killer is key-agreement (G1/G3, T267);
// I2 catches this specific corruption pattern but would not catch all
// wrong-side manifestations.

test "M5-T283 wrong-side killed by I2" {
    const clean = try readArtifactBytes(testing.allocator, "artifacts/oracle-2x2.wzo");
    defer testing.allocator.free(clean);

    var corrupted = try testing.allocator.dupe(u8, clean);
    defer testing.allocator.free(corrupted);

    const cols = colOffsets(81);
    // Negate every vw byte. Column-wide negation breaks the sign-antisymmetry
    // I2 checks: vb[i] should equal -vw[invert(i)]. After negation,
    // the check becomes vb[i] == -(-original_vw) = original_vw, which fails
    // for any position where vb[i] != vw[invert(i)] (i.e. every non-zero slot).
    for (0..81) |i| {
        corrupted[cols.vw + i] = 0 -% corrupted[cols.vw + i];
    }

    patchCrc(corrupted);

    var art = try vb_table.loadArtifact(testing.allocator, corrupted);
    defer art.deinit(testing.allocator);

    const result = vb_table.checkI2(&art);

    std.debug.print("[EXPECTED] M5-T283: I2 status={s} violations={d}/{d}\n", .{ @tagName(result.status), result.violations, result.denominator });
    try testing.expectEqual(vb_table.InvariantStatus.fail, result.status);
    try testing.expect(result.violations > 0);
}

// ─── M6 — DTT-UNSET: DTT column never computed → I7 must kill ──────────────

test "M6-DTT-unset killed by I7" {
    // Set db and dw columns to 255 (DTT_FAR) on every slot.
    // I7 checks: every terminal must have DTT=0. Terminals with DTT=255 fail.
    const clean = try readArtifactBytes(testing.allocator, "artifacts/oracle-2x2.wzo");
    defer testing.allocator.free(clean);

    var corrupted = try testing.allocator.dupe(u8, clean);
    defer testing.allocator.free(corrupted);

    const cols = colOffsets(81);
    @memset(corrupted[cols.db..][0..81], 255);
    @memset(corrupted[cols.dw..][0..81], 255);

    patchCrc(corrupted);

    var dec = try vb.decodeWZO1(testing.allocator, corrupted);
    defer dec.deinit();

    const gs = vb.GobanSize{ .w = 2, .h = 2 };
    const result = vb_fixpoint.checkI7(&dec, gs);

    std.debug.print("[EXPECTED] M6-DTT-unset: I7 status={s} terminals_bad={d} terminals_total={d} uniform_val={?}\n", .{ @tagName(result.status), result.terminals_with_dtt_neq_0, result.terminals_total, result.uniform_value });
    try testing.expectEqual(vb_fixpoint.FixpointStatus.fail, result.status);
    try testing.expect(result.terminals_with_dtt_neq_0 > 0);
}

// ─── M7 — T260: colour inversion broken → I2 must kill ─────────────────────

test "M7-T260 inversion-broken killed by I2" {
    // Copy vb into vw (no negation). With vw == vb, the inversion identity
    // vb[i] == -vw[invert(i)] becomes vb[i] == -vb[invert(i)], which is
    // false for all non-zero-valued legal slots.
    const clean = try readArtifactBytes(testing.allocator, "artifacts/oracle-2x2.wzo");
    defer testing.allocator.free(clean);

    var corrupted = try testing.allocator.dupe(u8, clean);
    defer testing.allocator.free(corrupted);

    const cols = colOffsets(81);
    @memcpy(corrupted[cols.vw..][0..81], corrupted[cols.vb..][0..81]);

    patchCrc(corrupted);

    var art = try vb_table.loadArtifact(testing.allocator, corrupted);
    defer art.deinit(testing.allocator);

    const result = vb_table.checkI2(&art);

    std.debug.print("[EXPECTED] M7-T260: I2 status={s} violations={d}/{d}\n", .{ @tagName(result.status), result.violations, result.denominator });
    try testing.expectEqual(vb_table.InvariantStatus.fail, result.status);
    try testing.expect(result.violations > 0);
}

// ─── M9 — BATTERY-STUBBED: an invariant that always returns `.skipped` ─────
//
// M9 (CODE.BATTERY-STUBBED): one invariant stubbed to `.skipped` status; the
// suite reports green because `verify_battery.zig`'s `toExit` maps
// `.skipped => .pass` — no meta-check verified every invariant returned a
// real verdict. The BATT-HEALTH meta-check (T347, `src/vb_health.zig`) is the
// killer: it enumerates every declared invariant by compile-time reflection
// over `vb.Invariant`, runs each, and fails iff any returns `.skipped`.
//
// Inverted from SURVIVED → KILLED on 2026-08-04 (T347). The fixture stubs one
// runner (I7) to `vb_health.stubSkipped`; the health check must go red, then
// green when the stub is removed (the real `RUNNERS` carry no stubs).

test "M9-BATTERY-STUBBED killed by BATT-HEALTH (red, then green)" {
    // (b) red — stub I7 to `.skipped`, the M9 mutant. The health check
    // enumerates all 12 declared invariants and fails on the one stub.
    var ctx = try vb_health.loadCtx(testing.allocator, "artifacts/oracle-2x2.wzo");
    defer ctx.deinit();

    var mutant: [vb_health.DECLARED]vb_health.RunnerFn = vb_health.RUNNERS;
    const stubbed = vb.Invariant.I7;
    mutant[@intFromEnum(stubbed)] = vb_health.stubSkipped;

    const red = vb_health.checkWith(&ctx, &mutant);
    std.debug.print("[EXPECTED] M9-BATTERY-STUBBED: red status={s} skipped={d} stubbed={s}\n", .{
        @tagName(red.status), red.skipped_count, vb_health.invariantName(@intFromEnum(stubbed)),
    });
    try testing.expectEqual(vb_health.Status.fail, red.status);
    try testing.expectEqual(@as(u32, 1), red.skipped_count);
    try testing.expect(red.skipped[@intFromEnum(stubbed)]);

    // (c) green — remove the stub (the canonical RUNNERS). Every invariant
    // returns a real verdict; the health check passes.
    const green = vb_health.check(&ctx);
    std.debug.print("[EXPECTED] M9-BATTERY-STUBBED: green status={s} skipped={d}\n", .{
        @tagName(green.status), green.skipped_count,
    });
    try testing.expectEqual(vb_health.Status.pass, green.status);
    try testing.expectEqual(@as(u32, 0), green.skipped_count);
}

// ─── M8 — T261 deleted-entry: one side's entry removed → closure catches ───
//
// M8 (T261-as-described): a legitimate passes=1 side-entry deleted — a
// reachable state has one side present and the other absent. The proper
// killer is the C-A1/C-A2 closure checks (T342, `src/vb_closure.zig`): with
// an entry deleted, forward closure finds children-not-in-table > 0 and
// backward closure finds reachable-not-in-table > 0.
//
// Inverted from SURVIVED → KILLED on 2026-08-05 (T363). The fixture deletes
// one entry from a small WZO2 artifact (3×3, `data/oracle-3x3-v2.wzo2`),
// runs both closure directions, and expects each to go red (missing > 0),
// then green (missing == 0) when the entry is restored.

test "M8-T261 deleted-entry killed by C-A1/C-A2 closure (red, then green)" {
    // Read the 3×3 WZO2 artifact (small — the only committed small WZO2).
    var threaded = std.Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();
    const file_bytes = try std.Io.Dir.cwd().readFileAlloc(io, "data/oracle-3x3-v2.wzo2", testing.allocator, .unlimited);
    defer testing.allocator.free(file_bytes);

    // GREEN baseline: clean artifact, both closure directions pass.
    var reader_clean = try vb_closure.Wzo2Reader.load(testing.allocator, file_bytes);
    defer reader_clean.deinit();
    const ca1_clean = try vb_closure.ca1ForwardClosure(&reader_clean, testing.allocator);
    const ca2_clean = try vb_closure.ca2BackwardClosure(&reader_clean, testing.allocator);
    std.debug.print("[EXPECTED] M8-T261: clean C-A1 children_not_in_table={d} C-A2 reachable_not_in_table={d}\n", .{ ca1_clean.children_not_in_table, ca2_clean.reachable_not_in_table });
    try testing.expectEqual(@as(u64, 0), ca1_clean.children_not_in_table);
    try testing.expectEqual(@as(u64, 0), ca2_clean.reachable_not_in_table);

    // RED: delete one entry (the pass child of root, entry 3 — reachable by
    // Black passing from root, so both directions must find it missing).
    var reader_mut = try vb_closure.Wzo2Reader.load(testing.allocator, file_bytes);
    defer reader_mut.deinit();
    if (reader_mut.header.n_entries > 3) {
        reader_mut.entries[3 * 4] = 0; // key_byte := 0 — no longer matches any state
    }
    const ca1_mut = try vb_closure.ca1ForwardClosure(&reader_mut, testing.allocator);
    const ca2_mut = try vb_closure.ca2BackwardClosure(&reader_mut, testing.allocator);
    std.debug.print("[EXPECTED] M8-T261: RED C-A1 children_not_in_table={d} C-A2 reachable_not_in_table={d}\n", .{ ca1_mut.children_not_in_table, ca2_mut.reachable_not_in_table });
    try testing.expect(ca1_mut.children_not_in_table > 0);
    try testing.expectEqual(vb_closure.ClosureStatus.fail, ca1_mut.status);
    try testing.expect(ca2_mut.reachable_not_in_table > 0);
    try testing.expectEqual(vb_closure.ClosureStatus.fail, ca2_mut.status);
}

// ─── M10 — alias-control: R8 replaced by an alias of the kernel → I11 null ─
//
// M10 (GRAND-AUDIT §1a): the "independent" side is an alias of the solver —
// two "implementations" are the same function registered twice, producing
// perfect agreement vacuously. The I11 null control (spec §4.1) is the
// killer: run I11 with the battery's move generator replaced by an alias of
// the solver's (kernel vs SMD1 — both kernel-generated). It must report 0
// mismatches vacuously, confirming the comparison machinery sees nothing
// when the two sides are the same function; and the seeded-defect control
// (spec §4.2, allows-suicide mutant) must report > 0, confirming the
// machinery is NOT blind. Together they prove the real R8-vs-kernel reading
// is meaningful.
//
// Inverted from SURVIVED → KILLED on 2026-08-05 (T363). The fixture runs the
// I11 null control on the committed 2×2 SMD1 dump and asserts the vacuous 0,
// then runs the seeded-defect control and asserts the > 0.

test "M10-ALIAS-CONTROL killed by I11 null control (vacuous 0) + seeded-defect (> 0)" {
    // Null control: kernel vs SMD1 (both kernel) at 2×2 → 0 mismatches.
    // T438: the fixture is regenerated in-memory (vb_i11.fixtureExhaustive)
    // instead of read from a decaying /tmp dump. Both the old on-disk dump
    // and this regeneration come from the same kernel move generator, so the
    // null-control semantics (solver vs alias-of-solver) are unchanged; the
    // expected total of 114 records below now also cross-checks the in-memory
    // emitter against what the committed dump used to contain.
    const bytes = try vb_i11.fixtureExhaustive(2, 2);
    defer vb_i11.freeFixture(bytes);
    const res = try vb_i11.compareSmd1Null(2, 2, bytes);
    std.debug.print("[EXPECTED] M10-ALIAS-CONTROL: null mismatches={d}/{d} (vacuous 0 required)\n", .{ res.mismatches, res.total });
    try testing.expectEqual(@as(u64, 0), res.mismatches);
    try testing.expectEqual(@as(u64, 114), res.total);

    // Seeded-defect: the same comparison machinery with an allows-suicide
    // mutant must report > 0 — proving the harness is not blind.
    const w = 2;
    const h = 2;
    const engine_mod = @import("engine");
    const X = engine_mod.colex.Indexer(w, h);
    var pos: [4]i8 = [_]i8{ 0, -1, -1, 0 }; // W at 1, W at 2
    const trigger_colex = X.colex_from_pos(&pos);
    const E = engine_mod.enumerate.Enumerator(w, h);
    try testing.expect(E.is_legal(&pos));
    const res_def = try vb_i11.compareDefective(w, h, trigger_colex, 3);
    std.debug.print("[EXPECTED] M10-ALIAS-CONTROL: seeded-defect mismatches={d}/{d} (> 0 required)\n", .{ res_def.mismatches, res_def.total });
    try testing.expect(res_def.mismatches > 0);
}
