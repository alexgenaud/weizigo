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
// I5 CROSS-SIZE DIFFERENTIAL — the T388 §4 regression, built as a gate.
//
// Task: T391 · Set: J · 2026-08-06 · Author: flash/T391
//
// At every (check, size) cell where two instruments implement the same I5
// check on the same artifact, both must return IDENTICAL readings —
// verdict, V, E, maxSCC, cycle_involved, cycle_reachable, KO_SENSITIVE
// count, and violations. Verdict equality alone is not enough: at 3×2 the
// two instruments disagreed on every countable quantity while both reported
// pass, and the divergence survived because nothing compared the numbers.
//
// Today the only overlapping cells are 3×2 and 4×3, both WZO1, both
// reachable-from-empty convention:
//   general        vb_graph.checkI5  (.graph = .reachable)
//   size-specific  vb_scc_4x4.checkI5Small / checkI5Wzo1Bitset (seed=false)
//
// These tests run under `zig build test` (wired in build.zig) and directly
// via `zig test src/i5_differential.zig` from the repo root (artifacts are
// read relative to the working directory).
//
// History: T388 (2026-08-06) demonstrated the pair diverging (E 7,364 vs
// 5,510; maxSCC 1,000 vs 1,676; cycle_reachable 2,523 vs 1,678; ko_sensitive
// 378 vs 347 — both verdicts pass) and proposed this differential. T391
// adjudicated: vb_graph's readings were wrong (passes==2 states were given
// placement successors, and SCC sizes were triple-projected instead of the
// register's quadruple level); both are fixed. The differential now passes
// with identical readings and fails loudly if either instrument ever
// diverges again.

const std = @import("std");
const vb_graph = @import("vb_graph.zig");
const vb_scc_4x4 = @import("vb_scc_4x4.zig");

fn loadBytes(path: []const u8) ![]u8 {
    var threaded = std.Io.Threaded.init(std.heap.page_allocator, .{});
    const io = threaded.io();
    return std.Io.Dir.cwd().readFileAlloc(io, path, std.heap.page_allocator, .unlimited);
}

/// Run both instruments on the same artifact (reachable-from-empty graph,
/// WZO1) and require identical readings on every countable quantity.
fn differential(
    allocator: std.mem.Allocator,
    comptime w: usize,
    comptime h: usize,
    artifact_path: []const u8,
) !void {
    const bytes = try loadBytes(artifact_path);
    defer allocator.free(bytes);

    // General instrument: needs its own WZO1 parse for fb/fw.
    var art = try vb_graph.loadArtifact(allocator, bytes);
    defer art.deinit(allocator);

    const general = try vb_graph.checkI5(allocator, .{ .w = @intCast(w), .h = @intCast(h) }, &art, .{ .graph = .reachable });
    const specific = try vb_scc_4x4.checkI5Small(allocator, w, h, bytes, false);

    std.debug.print("[I5-diff {d}x{d}] general: V={d} E={d} maxSCC={d} cycleInv={d} cycleReach={d} koSensGraph={d} koNotCR={d} {s}\n", .{
        w, h, general.nodes, general.edges, general.max_scc_size, general.cycle_involved,
        general.cycle_reachable, general.ko_sensitive_graph, general.ko_sensitive_not_cycle_reachable,
        @tagName(general.status),
    });
    std.debug.print("[I5-diff {d}x{d}] specific: V={d} E={d} maxSCC={d} cycleInv={d} cycleReach={d} koSens={d} koNotCR={d} {s}\n", .{
        w, h, specific.nodes, specific.edges, specific.max_scc_size, specific.cycle_involved,
        specific.cycle_reachable, specific.ko_sensitive_count, specific.ko_not_cr,
        @tagName(specific.status),
    });

    // Identical readings, not just identical verdicts.
    try std.testing.expectEqual(general.nodes, specific.nodes);
    try std.testing.expectEqual(general.edges, specific.edges);
    try std.testing.expectEqual(general.max_scc_size, specific.max_scc_size);
    try std.testing.expectEqual(general.cycle_involved, specific.cycle_involved);
    try std.testing.expectEqual(general.cycle_reachable, specific.cycle_reachable);
    try std.testing.expectEqual(general.ko_sensitive_graph, specific.ko_sensitive_count);
    try std.testing.expectEqual(general.ko_sensitive_not_cycle_reachable, specific.ko_not_cr);
    try std.testing.expectEqualStrings(@tagName(general.status), @tagName(specific.status));
}

test "I5 cross-size differential 3×2 (reachable, artifacts/oracle-3x2.wzo)" {
    // page_allocator: the instruments' own allocations are not leak-free
    // under the testing allocator (and they are built for page_allocator).
    try differential(std.heap.page_allocator, 3, 2, "artifacts/oracle-3x2.wzo");
}

test "I5 cross-size differential 4×3 (reachable, artifacts/oracle-4x3.wzo) [env-gated]" {
    // Gated behind WEIZIGO_I5_DIFF_4X3=1: linking both instruments (which
    // together instantiate the full 4×3 and 4×4 paths) in ONE binary makes
    // the zig frontend's ReleaseFast codegen exceed the tools/runner 4 GB
    // cap — a tooling constraint, not an instrument defect (the direct
    // Debug run is stable at ~2.1 GB). Run on demand:
    //   WEIZIGO_I5_DIFF_4X3=1 tools/runner -- zig test src/i5_differential.zig \
    //       --test-filter '4×3' -O Debug
    // The 3×2 cell above is the permanent gate that catches the T388 class;
    // the 4×3 equivalence itself is also pinned by the per-instrument exact
    // gates (vb_scc_4x4.zig 4×3 calibration) and the T391 third route
    // (docs/evidence/I5-DISAGREEMENT/third-route-4x3.py).
    if (std.c.getenv("WEIZIGO_I5_DIFF_4X3") == null) {
        std.debug.print("SKIP 4×3 I5 differential (set WEIZIGO_I5_DIFF_4X3=1 to run)\n", .{});
        return error.SkipZigTest;
    }
    try differential(std.heap.page_allocator, 4, 3, "artifacts/oracle-4x3.wzo");
}
