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
// Kill-verification for mutants M3, M5, M6, M7, and M9 (BATT-HEALTH, T347).
// Mutants M1, M2, M4, M8, M10 have no killer — see the catalogue at
// docs/epic-01-markovian/sprints/verify-battery/pass1/mutants.md.

const std = @import("std");
const testing = std.testing;

const vb = @import("vb_common.zig");
const vb_table = @import("vb_table.zig");
const vb_fixpoint = @import("vb_fixpoint.zig");
const vb_graph = @import("vb_graph.zig");
const vb_health = @import("vb_health.zig");

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

// ─── M3 — T265: ko set too broadly → GAP G1/G3, no killer ──────────────────

// M3 survives: the battery has no key-agreement check (G1/G3 — Z-R-STATE /
// Z-STATE-KEY). I5 (SCC containment) can detect spuriously-set KO_SENSITIVE
// flags in principle, but on 2×2 every legal state at passes=0 is
// cycle-reachable, so the synthetic fixture does not trigger a kill.
// The proper killer is the T267 key-agreement invariant, which requires
// the Phase 2 kernel's producer encoder.
//
// This assertion expects SURVIVAL (I5 passes despite the corruption).
// When Phase 2 lands and key-agreement is runnable, invert this assertion
// to expect `.fail`.

test "M3-T265 ko-too-broad SURVIVES (gap G1/G3)" {
    const clean = try readArtifactBytes(testing.allocator, "artifacts/oracle-2x2.wzo");
    defer testing.allocator.free(clean);

    var corrupted = try testing.allocator.dupe(u8, clean);
    defer testing.allocator.free(corrupted);

    const cols = colOffsets(81);
    // Set KO_SENSITIVE on a non-cycle-reachable position. On 2×2 all-legal
    // graph, every legal state at passes=0 is cycle-reachable, so I5 won't
    // flag it. The mutation is still valid — the artifact has a spuriously
    // set KO_SENSITIVE flag — but no battery check kills it.
    corrupted[cols.fb + 40] |= 0x01; // colex=40 ([B,B,B,empty]), Black side

    patchCrc(corrupted);

    var art = try vb_graph.loadArtifact(testing.allocator, corrupted);
    defer art.deinit(testing.allocator);

    const goban = vb_graph.GobanSize{ .w = 2, .h = 2 };
    const opts = vb_graph.I5Opts{ .graph = .all_legal };
    const result = try vb_graph.checkI5(testing.allocator, goban, &art, opts);

    std.debug.print("[EXPECTED-GAP G1/G3] M3-T265: I5 status={s} ko_flags={d} ko_not_cr={d} — SURVIVES, no key-agreement check\n", .{ @tagName(result.status), result.ko_sensitive_flags, result.ko_sensitive_not_cycle_reachable });
    // CURRENT: mutant survives — no check kills it. INVERT to .fail when Phase 2 key-agreement lands.
    try testing.expectEqual(vb_graph.I5Status.pass, result.status);
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
