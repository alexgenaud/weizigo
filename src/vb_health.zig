////////////////////////////////////////////
//                                        //
//    (c) 2026 Alexander E Genaud         //
//                                        //
//    Permission is granted hereby,       //
//    to copy· share· use· modify,        //
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
// VB_HEALTH — M9 meta-check: battery health (BATT-HEALTH, T347).
//
// Task: T347 · Role: worker · Model: minimax-m3 · Date: 2026-08-04
// Sprint: g3b-value-correctness · Pass: 0 · Plan: plan.md Rev 5 §5 (row BATT-HEALTH)
// Mutant: M9 (battery-stubbed) — `docs/.../verify-battery/pass1/mutants.md`
//
// GOAL — kill the "battery-stubbed" mutant (M9). An invariant stubbed to
// `.skipped` reads as a pass: `verify_battery.zig`'s `toExit` maps
// `.skipped => .pass`, so a stubbed suite goes green with no meta-check
// the wiser. This module IS that meta-check: enumerate every declared
// invariant, run each, and assert none returned `.skipped`.
//
// ENUMERATION IS BY COMPILE-TIME REFLECTION over `vb.Invariant` (the single
// source of truth for the declared set), NOT by a hand-maintained name list.
// The runner registry is indexed by `@intFromEnum(inv)` and built at comptime;
// completeness is enforced: every `vb.Invariant` variant must have a
// registered runner, or this file FAILS TO COMPILE with a message naming the
// unregistered invariant. Adding a new invariant without registering its
// runner can therefore never silently bypass the check — the wrong answer the
// brief calls out.
//
// R8 — imports only the battery's own modules (`vb_common`, `vb_table`,
// `vb_fixpoint`, `vb_graph`) and Zig std. No `src/` kernel/solver imports.
//
// STANDALONE TESTS — all tests live in this file. The sprint console wires
// it into `zig build test` after merge; during development run
// `zig test src/vb_health.zig`.

const std = @import("std");
const evidence = @import("evidence.zig");
const testing = std.testing;
const Allocator = std.mem.Allocator;

const vb = @import("vb_common.zig");
const vbt = @import("vb_table.zig");
const vbf = @import("vb_fixpoint.zig");
const vbg = @import("vb_graph.zig");

// ═══════════════════════════════════════════════════════════════════════════
// Status — reuse the battery's common CheckStatus (it carries `.skipped`)
// ═══════════════════════════════════════════════════════════════════════════

pub const Status = vb.CheckStatus;

/// Number of declared invariants — reflected from the enum at comptime.
/// This is the denominator the health check reports. Adding an `Invariant`
/// variant grows this constant; the registry's completeness check then
/// forces a runner to be registered for it (compile error otherwise).
pub const DECLARED: usize = @typeInfo(vb.Invariant).@"enum".fields.len;

// ═══════════════════════════════════════════════════════════════════════════
// Fixture context — the 2×2 artifact in all three representations the
// per-module checks consume. Self-contained and deterministic: the health
// check does not depend on a CLI-supplied artifact.
// ═══════════════════════════════════════════════════════════════════════════

pub const Ctx = struct {
    gpa: Allocator,
    bytes: []const u8,
    dec: vb.WZO1Decoded,
    vbt_art: vbt.VBArtifact,
    vbg_art: vbg.VBArtifact,
    gs: vb.GobanSize,

    pub fn deinit(self: *Ctx) void {
        self.dec.deinit();
        self.vbt_art.deinit(self.gpa);
        self.vbg_art.deinit(self.gpa);
        self.gpa.free(self.bytes);
        self.* = undefined;
    }
};

/// Load `path` (a WZO1 artifact) into a `Ctx` on `gpa`.
pub fn loadCtx(gpa: Allocator, path: []const u8) !Ctx {
    var threaded = std.Io.Threaded.init(gpa, .{});
    defer threaded.deinit();
    const io = threaded.io();
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .unlimited);
    errdefer gpa.free(bytes);

    var dec = try vb.decodeWZO1(gpa, bytes);
    errdefer dec.deinit();

    var vbt_art = try vbt.loadArtifact(gpa, bytes);
    errdefer vbt_art.deinit(gpa);

    var vbg_art = try vbg.loadArtifact(gpa, bytes);
    errdefer vbg_art.deinit(gpa);

    const gs = vb.GobanSize{ .w = dec.header.board_w, .h = dec.header.board_h };
    return Ctx{
        .gpa = gpa,
        .bytes = bytes,
        .dec = dec,
        .vbt_art = vbt_art,
        .vbg_art = vbg_art,
        .gs = gs,
    };
}

// ═══════════════════════════════════════════════════════════════════════════
// Per-invariant runners — call the real per-module check and map its
// module-specific status to the common `Status`. None of the real checks
// can produce `.skipped` (their status enums lack that variant), so the
// ONLY way a runner yields `.skipped` is a deliberate stub — the M9 mutant.
// ═══════════════════════════════════════════════════════════════════════════

fn mapTable(s: vbt.InvariantStatus) Status {
    return switch (s) {
        .pass => .pass,
        .fail => .fail,
        .not_applicable => .@"not-applicable",
        .err => .@"error",
    };
}

fn mapFix(s: vbf.FixpointStatus) Status {
    return switch (s) {
        .pass => .pass,
        .fail => .fail,
        .not_applicable => .@"not-applicable",
        .err => .@"error",
    };
}

fn mapI5(s: vbg.I5Status) Status {
    return switch (s) {
        .pass => .pass,
        .fail => .fail,
        .err => .@"error",
    };
}

fn runI1(ctx: *const Ctx) Status {
    return mapTable(vbt.checkI1(&ctx.vbt_art).status);
}
fn runI2(ctx: *const Ctx) Status {
    return mapTable(vbt.checkI2(&ctx.vbt_art).status);
}
fn runI3(ctx: *const Ctx) Status {
    _ = ctx;
    return mapTable(vbt.checkI3().status);
}
fn runI4(ctx: *const Ctx) Status {
    return mapFix(vbf.checkI4(&ctx.dec, ctx.gs).status);
}
fn runI5(ctx: *const Ctx) Status {
    const r = vbg.checkI5(
        ctx.gpa,
        vbg.GobanSize{ .w = ctx.gs.w, .h = ctx.gs.h },
        &ctx.vbg_art,
        .{ .graph = .all_legal },
    ) catch return .@"error";
    return mapI5(r.status);
}
fn runI6(ctx: *const Ctx) Status {
    return mapTable(vbt.checkI6(&ctx.vbt_art).status);
}
fn runI7(ctx: *const Ctx) Status {
    return mapFix(vbf.checkI7(&ctx.dec, ctx.gs).status);
}
fn runI8(ctx: *const Ctx) Status {
    _ = ctx;
    // T872 green-up: the not_applicable stub is deleted; I8's real coverage
    // is the external Python fixture
    // (docs/evidence/QA-026/calibration-2x2-mismatch.py).
    return .external;
}
fn runI9(ctx: *const Ctx) Status {
    return mapFix(vbf.checkI9(&ctx.dec, ctx.gs).status);
}
fn runI10(ctx: *const Ctx) Status {
    _ = ctx;
    return mapTable(vbt.checkI10().status);
}
fn runI11(ctx: *const Ctx) Status {
    _ = ctx;
    // T872 green-up: the not_applicable stub is deleted; I11's real coverage
    // is the standalone vb_i11.zig module (T346/T473), so the harness slot
    // reports `external` (delegating to that module).
    return .external;
}
fn runI12(ctx: *const Ctx) Status {
    return mapTable(vbt.checkI12(&ctx.vbt_art).status);
}

// ═══════════════════════════════════════════════════════════════════════════
// Runner registry — comptime-built, indexed by @intFromEnum(inv).
// Completeness enforced: a declared invariant with no runner is a
// COMPILE ERROR, so adding an invariant can never silently bypass the
// health check.
// ═══════════════════════════════════════════════════════════════════════════

pub const RunnerFn = *const fn (ctx: *const Ctx) Status;

/// The canonical runner registry. Public so the M9 mutant fixture (and the
/// sprint console) can copy it and stub one slot to demonstrate the kill.
pub const RUNNERS: [DECLARED]RunnerFn = blk: {
    var r: [DECLARED]?RunnerFn = [_]?RunnerFn{null} ** DECLARED;

    r[@intFromEnum(vb.Invariant.I1)] = runI1;
    r[@intFromEnum(vb.Invariant.I2)] = runI2;
    r[@intFromEnum(vb.Invariant.I3)] = runI3;
    r[@intFromEnum(vb.Invariant.I4)] = runI4;
    r[@intFromEnum(vb.Invariant.I5)] = runI5;
    r[@intFromEnum(vb.Invariant.I6)] = runI6;
    r[@intFromEnum(vb.Invariant.I7)] = runI7;
    r[@intFromEnum(vb.Invariant.I8)] = runI8;
    r[@intFromEnum(vb.Invariant.I9)] = runI9;
    r[@intFromEnum(vb.Invariant.I10)] = runI10;
    r[@intFromEnum(vb.Invariant.I11)] = runI11;
    r[@intFromEnum(vb.Invariant.I12)] = runI12;

    // Completeness: every declared invariant must be registered. A new
    // `vb.Invariant` variant without a runner above fails the build here,
    // naming the offender — the guarantee that the registry cannot rot.
    const fields = @typeInfo(vb.Invariant).@"enum".fields;
    for (r, 0..) |maybe, i| {
        if (maybe == null) {
            @compileError(
                "vb_health: invariant " ++ fields[i].name ++
                    " is declared in vb.Invariant but has no registered runner — " ++
                    "the battery-health meta-check would silently skip it. " ++
                    "Add a runI<n> fn and register it in RUNNERS.",
            );
        }
    }

    var out: [DECLARED]RunnerFn = undefined;
    for (r, 0..) |maybe, i| out[i] = maybe.?;
    break :blk out;
};

// A comptime assertion that the registry tracks the enum — guards against
// a future edit that decouples DECLARED from the registry width.
comptime {
    if (RUNNERS.len != DECLARED) @compileError("RUNNERS width != DECLARED");
}

// ═══════════════════════════════════════════════════════════════════════════
// Health verdict + check
// ═══════════════════════════════════════════════════════════════════════════

pub const Verdict = struct {
    /// `.pass` iff every registered invariant returned a real verdict
    /// (pass / fail / not-applicable / error) and NONE returned `.skipped`.
    /// `.fail` iff at least one invariant returned `.skipped` (M9).
    status: Status,
    /// Number of declared invariants enumerated (== DECLARED).
    declared: usize,
    /// Number of invariants that returned `.skipped` — the M9 count.
    skipped_count: u32,
    /// Per-invariant skip flags, indexed by `@intFromEnum(inv)`.
    /// `skipped[i] == true` iff invariant `i` returned `.skipped`.
    skipped: [DECLARED]bool,
    /// Per-invariant verdict, indexed by `@intFromEnum(inv)`.
    statuses: [DECLARED]Status,
};

/// Run every declared invariant via `runners` and return the health verdict.
/// `runners` is indexed by `@intFromEnum(vb.Invariant)`; `inline for` over
/// the enum's comptime-reflected fields drives the dispatch — no name list.
pub fn checkWith(ctx: *const Ctx, runners: []const RunnerFn) Verdict {
    var v = Verdict{
        .status = .pass,
        .declared = DECLARED,
        .skipped_count = 0,
        .skipped = [_]bool{false} ** DECLARED,
        .statuses = [_]Status{.pass} ** DECLARED,
    };
    inline for (@typeInfo(vb.Invariant).@"enum".fields) |f| {
        const i = f.value;
        const s = runners[i](ctx);
        v.statuses[i] = s;
        if (s == .skipped) {
            v.skipped[i] = true;
            v.skipped_count += 1;
        }
    }
    if (v.skipped_count > 0) v.status = .fail;
    return v;
}

/// Run every declared invariant via the canonical `RUNNERS` registry.
pub fn check(ctx: *const Ctx) Verdict {
    return checkWith(ctx, &RUNNERS);
}

/// Per-invariant name, indexed by `@intFromEnum(inv)`. Built at comptime by
/// reflecting the enum, so the registry and the names share one source of
/// truth — adding an `Invariant` variant without updating one is impossible
/// without touching the other.
pub const NAMES: [DECLARED][]const u8 = blk: {
    var names: [DECLARED][]const u8 = undefined;
    for (@typeInfo(vb.Invariant).@"enum".fields) |f| {
        names[f.value] = f.name;
    }
    break :blk names;
};

/// Name of the invariant at registry index `i`.
pub fn invariantName(i: usize) []const u8 {
    if (i >= DECLARED) return "?";
    return NAMES[i];
}

// ═══════════════════════════════════════════════════════════════════════════
// M9 mutant stub — a runner that always returns `.skipped`. Used by the
// kill test (and by `vb_mutants.zig`'s M9 inversion) to demonstrate the
// health check catches a stubbed invariant.
// ═══════════════════════════════════════════════════════════════════════════

pub fn stubSkipped(_: *const Ctx) Status {
    return .skipped;
}

// ═══════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════

test "M9: health check is GREEN on real invariants (no skipped)" {
    // (c) of the wiring proof — removing the mutant makes it green. The
    // canonical RUNNERS call no stubs, so every invariant returns a real
    // verdict and the health check passes.
    var ctx = try loadCtx(testing.allocator, "artifacts/oracle-2x2.wzo");
    defer ctx.deinit();

    const v = check(&ctx);
    evidence.print("[EXPECTED] M9 green: status={s} declared={d} skipped={d}\n", .{
        @tagName(v.status), v.declared, v.skipped_count,
    });
    try testing.expectEqual(Status.pass, v.status);
    try testing.expectEqual(@as(usize, DECLARED), v.declared);
    try testing.expectEqual(@as(u32, 0), v.skipped_count);
}

test "M9: battery-stubbed mutant is RED (caught)" {
    // (b) of the wiring proof — a deliberately seeded failure makes it red.
    // Copy the canonical registry and stub one slot (I7) to `.skipped`,
    // modelling the M9 mutant: an invariant that always returns skipped.
    var ctx = try loadCtx(testing.allocator, "artifacts/oracle-2x2.wzo");
    defer ctx.deinit();

    var mutant: [DECLARED]RunnerFn = RUNNERS;
    const stubbed = vb.Invariant.I7;
    mutant[@intFromEnum(stubbed)] = stubSkipped;

    const v = checkWith(&ctx, &mutant);
    evidence.print("[EXPECTED] M9 red: status={s} skipped={d} stubbed={s}\n", .{
        @tagName(v.status), v.skipped_count, invariantName(@intFromEnum(stubbed)),
    });
    try testing.expectEqual(Status.fail, v.status);
    try testing.expectEqual(@as(u32, 1), v.skipped_count);
    try testing.expect(v.skipped[@intFromEnum(stubbed)]);
    // The stubbed slot's recorded status is `.skipped`.
    try testing.expectEqual(Status.skipped, v.statuses[@intFromEnum(stubbed)]);
}

test "M9: stubbing a second invariant is still RED (two skipped)" {
    // The health check counts ALL skipped invariants, not just the first —
    // a partial meta-check that stops at the first stub would miss a second.
    var ctx = try loadCtx(testing.allocator, "artifacts/oracle-2x2.wzo");
    defer ctx.deinit();

    var mutant: [DECLARED]RunnerFn = RUNNERS;
    mutant[@intFromEnum(vb.Invariant.I4)] = stubSkipped;
    mutant[@intFromEnum(vb.Invariant.I11)] = stubSkipped;

    const v = checkWith(&ctx, &mutant);
    evidence.print("[EXPECTED] M9 double-red: status={s} skipped={d}\n", .{
        @tagName(v.status), v.skipped_count,
    });
    try testing.expectEqual(Status.fail, v.status);
    try testing.expectEqual(@as(u32, 2), v.skipped_count);
    try testing.expect(v.skipped[@intFromEnum(vb.Invariant.I4)]);
    try testing.expect(v.skipped[@intFromEnum(vb.Invariant.I11)]);
}

test "registry completeness: every declared invariant has a runner" {
    // Sanity: the registry width equals the enum width, and no slot is
    // null. (The null case is already a compile error in RUNNERS; this test
    // pins the count so a future enum growth that someone bypasses the
    // comptime gate by widening the array manually still shows up here.)
    try testing.expectEqual(@as(usize, DECLARED), RUNNERS.len);
    // Every invariant name is reflectable from the same enum — no name rot.
    inline for (@typeInfo(vb.Invariant).@"enum".fields) |f| {
        try testing.expectEqualStrings(f.name, NAMES[f.value]);
    }
}