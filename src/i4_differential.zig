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
// I4 BELLMAN-RESIDUAL DIFFERENTIAL — T395 (T388 D1, wired as a gate).
//
// Task: T395 (does every property have exactly one production
// implementation?) · Set: Q · 2026-08-06 · Author: flash/T395
//
// D1 (T388): I4 is implemented by THREE independent Φ operators with no
// overlap cell — vb_fixpoint.checkI4 (WZO1, ≤4×3), vb_bellman_4x4.i4Bellman
// (WZO2, R8 move engine), oracle_v2_accept.checkA2 (WZO2, kernel
// rules.Rules move engine). A rule defect in one engine is invisible to the
// other two: WZO1 I4 stops at 4×3, WZO2 I4 starts at 3×3, and the 3×3
// WZO1/WZO2 artifacts are different builds, so no cell ever ran two of them
// on the same artifact. All three passed today — but nothing verified they
// measure the same property.
//
// This differential closes the cheapest overlap: the 3×3 WZO2 artifact
// (data/oracle-3x3-v2.wzo2, 49,428 entries) is read by BOTH WZO2 engines —
// vb_bellman_4x4 (R8 movegen, independent place/capture/ko + areaScore
// terminals) and oracle_v2_accept.checkA2 (kernel rules.Rules). Both are
// exhaustive at 3×3 (n_entries < 5M, so A2's stride=1). Identical
// denominator, zero violations on both sides, identical missing-child
// counts, and zero R8-internal move divergences are required. If R8 and the
// kernel ever disagree on a child's legality or value, one side reports a
// violation (or a missing child) the other does not, and this gate fires.
//
// Runs under `zig build test` (wired in build.zig) and directly via
// `zig test src/i4_differential.zig` from the repo root.
//
// The third Φ (vb_fixpoint.checkI4, WZO1) shares no artifact with either
// WZO2 engine — the 3×3 WZO1 and WZO2 artifacts are different builds with
// different ko conventions. That overlap is genuinely infeasible on a shared
// artifact; T388's unification proposals (a WZO2 reader for the general
// check, or a Φ core with pluggable move engines) remain the path, and this
// differential is the WZO2-side gate meanwhile.

const std = @import("std");
const evidence = @import("evidence.zig");
const vb_bellman_4x4 = @import("vb_bellman_4x4.zig");
const oracle_v2_accept = @import("oracle_v2_accept.zig");

fn loadBytes(path: []const u8) ![]u8 {
    var threaded = std.Io.Threaded.init(std.heap.page_allocator, .{});
    const io = threaded.io();
    return std.Io.Dir.cwd().readFileAlloc(io, path, std.heap.page_allocator, .unlimited);
}

test "I4 Bellman differential: vb_bellman_4x4 (R8) vs oracle_v2_accept A2 (kernel) on 3×3 WZO2" {
    const allocator = std.heap.page_allocator;
    const bytes = try loadBytes("data/oracle-3x3-v2.wzo2");
    defer allocator.free(bytes);

    // ── Side 1: vb_bellman_4x4 (R8 move engine) ────────────────────────
    var reader = try vb_bellman_4x4.Wzo2Reader.load(allocator, bytes);
    defer reader.deinit();
    try reader.buildColexMap(vb_bellman_4x4.colexSpace(9));
    const bellman = try vb_bellman_4x4.i4Bellman(&reader, "3x3 (T395 differential)");

    // ── Side 2: oracle_v2_accept A2 (kernel rules.Rules) ───────────────
    const header = try oracle_v2_accept.parseHeader(bytes);
    const groups = try oracle_v2_accept.readGroupIndex(bytes, header, allocator);
    defer allocator.free(groups);
    const entries = oracle_v2_accept.entryData(bytes, header);
    const a2 = try oracle_v2_accept.checkA2(header, groups, entries, null);

    evidence.print("[I4-diff 3x3] bellman(R8): entries={d} clear={d} set={d} viol_clear={d} viol_set={d} missing={d} move_div={d} no_child={d} {s}\n", .{
        bellman.n_entries,        bellman.n_clear,          bellman.n_set,       bellman.violations_clear, bellman.violations_set,
        bellman.children_missing, bellman.move_divergences, bellman.no_children, @tagName(bellman.status),
    });
    evidence.print("[I4-diff 3x3] A2(kernel): checked={d} L_violations={d} H_violations={d} missing_child={d} stride={d} denominator={d}\n", .{
        a2.checked, a2.L_violations, a2.H_violations, a2.missing_child, a2.stride, a2.denominator,
    });

    // Identical denominator — both engines must have swept the same table.
    try std.testing.expectEqual(bellman.n_entries, a2.checked);
    try std.testing.expectEqual(@as(u64, 49_428), a2.checked);

    // Verdict: neither engine finds a Bellman residual violation.
    try std.testing.expectEqual(@as(u64, 0), bellman.violations_clear);
    try std.testing.expectEqual(@as(u64, 0), bellman.violations_set);
    try std.testing.expectEqual(@as(u64, 0), a2.L_violations);
    try std.testing.expectEqual(@as(u64, 0), a2.H_violations);
    try std.testing.expectEqualStrings("pass", @tagName(bellman.status));

    // Missing children: both engines must see the same children in the table.
    try std.testing.expectEqual(bellman.children_missing, a2.missing_child);
    try std.testing.expectEqual(@as(u64, 0), a2.missing_child);

    // R8-internal consistency (a legality disagreement inside the R8 engine
    // is a defect even if the kernel never sees it).
    try std.testing.expectEqual(@as(u64, 0), bellman.move_divergences);
    try std.testing.expectEqual(@as(u64, 0), bellman.no_children);

    // Sanity: 3×3 has ko, so some KO_SENSITIVE-set slots must exist — a
    // table where every entry is clear would make the differential vacuous.
    try std.testing.expect(bellman.n_set > 0);

    evidence.print("[I4-diff 3x3] GREEN: R8 and kernel engines agree on every countable — the two Φ operators measure the same property\n", .{});
}
