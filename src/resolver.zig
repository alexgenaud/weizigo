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
// resolver.zig — pluggable bracket resolvers (ADR-0022).
//
// Task: T402 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-07
//
// A bracket resolver takes a state's stored [L,H] and proposes a single value
// or "no opinion". Resolvers are never authoritative: output is never promoted
// without independent agreement. The honest deliverable remains the fresh-start
// single-score region plus the [L,H] bracket.
//
// Registered resolvers:
//   none               — always "no opinion" (null control)
//   bracket_low        — propose L (baseline)
//   bracket_high       — propose H (baseline)
//   bracket_mid        — propose ⌊(L+H)/2⌋ (baseline)
//   deliberately_wrong — propose L-1 (seeded control; MUST be caught)
//   capture_budget(B)  — no_opinion + metadata (non-convergence measured)
//
// Acceptance: zig test src/resolver.zig
//   (standalone test; no engine/artifact/axiom edits)
//
// Internal consistency is not external agreement.
//   — ADR-0022, from T387/T397

const std = @import("std");
const testing = std.testing;

// ═══════════════════════════════════════════════════════════════════════════
//  INTERFACE
// ═══════════════════════════════════════════════════════════════════════════

/// A resolver's output: either a proposed single value, or no opinion.
pub const Resolution = union(enum) {
    value: i8,
    no_opinion: void,

    pub fn format(self: @This(), comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .value => |v| try writer.print("value({d})", .{v}),
            .no_opinion => try writer.writeAll("no_opinion"),
        }
    }
};

/// Context passed to a resolver's resolve function.
/// colex: the goban's colex index (for resolvers that need position context)
/// side: +1 for Black, -1 for White
/// L, H: the stored bracket [L,H] from the canonical table
pub const ResolveContext = struct {
    colex: u32,
    side: i8,
    L: i8,
    H: i8,
};

/// A pluggable bracket resolver.
///
/// Fields:
///   name     — human-readable identifier
///   metadata — description, caveats, provenance (for registration)
///   resolve  — function pointer: (ctx, ResolveContext) → Resolution
///   ctx      — opaque pointer to resolver-specific state (e.g. budget B)
pub const Resolver = struct {
    name: []const u8,
    metadata: []const u8,
    resolve: *const fn (self_ctx: ?*const anyopaque, rc: ResolveContext) Resolution,
    self_ctx: ?*const anyopaque,

    /// Propose a single value for a bracketed entry, or "no opinion".
    pub fn propose(self: *const Resolver, rc: ResolveContext) Resolution {
        return self.resolve(self.self_ctx, rc);
    }
};

// ═══════════════════════════════════════════════════════════════════════════
//  IMPLEMENTATIONS
// ═══════════════════════════════════════════════════════════════════════════

/// null resolver — always "no opinion". Exists to make the comparison honest:
/// a resolver that cannot beat "propose nothing" provides no information.
pub fn resolverNone() Resolver {
    return .{
        .name = "none",
        .metadata = "Null resolver. Always returns no_opinion. Exists as a control: every counter this resolver moves is a harness defect.",
        .resolve = resolveNone,
        .self_ctx = null,
    };
}

fn resolveNone(_: ?*const anyopaque, _: ResolveContext) Resolution {
    return .no_opinion;
}

/// trivial resolver — always propose L. Baseline: any useful resolver must
/// beat "always say the conservative bound."
pub fn resolverBracketLow() Resolver {
    return .{
        .name = "bracket_low",
        .metadata = "Trivial baseline resolver. Always proposes L (the lower bracket bound). Any useful resolver must disagree with this where the true value is not L.",
        .resolve = resolveBracketLow,
        .self_ctx = null,
    };
}

fn resolveBracketLow(_: ?*const anyopaque, rc: ResolveContext) Resolution {
    return .{ .value = rc.L };
}

/// trivial resolver — always propose H. Baseline: symmetric.
pub fn resolverBracketHigh() Resolver {
    return .{
        .name = "bracket_high",
        .metadata = "Trivial baseline resolver. Always proposes H (the upper bracket bound).",
        .resolve = resolveBracketHigh,
        .self_ctx = null,
    };
}

fn resolveBracketHigh(_: ?*const anyopaque, rc: ResolveContext) Resolution {
    return .{ .value = rc.H };
}

/// trivial resolver — propose the midpoint. Baseline: the simplest
/// non-trivial guess.
pub fn resolverBracketMid() Resolver {
    return .{
        .name = "bracket_mid",
        .metadata = "Trivial baseline resolver. Proposes ⌊(L+H)/2⌋ (midpoint, truncated toward zero).",
        .resolve = resolveBracketMid,
        .self_ctx = null,
    };
}

fn resolveBracketMid(_: ?*const anyopaque, rc: ResolveContext) Resolution {
    const mid = @divTrunc(rc.L + rc.H, 2);
    return .{ .value = mid };
}

/// deliberately wrong resolver — propose L - 1. Seeded control: MUST be
/// caught by the L==H agreement column. If the harness does not call this
/// "refuted", the harness is insensitive.
pub fn resolverDeliberatelyWrong() Resolver {
    return .{
        .name = "deliberately_wrong",
        .metadata = "SEEDED CONTROL — proposes L-1, which is always outside [L,H] when L==H. MUST be caught by the L==H agreement column. If this resolver is not marked REFUTED, the harness is broken.",
        .resolve = resolveDeliberatelyWrong,
        .self_ctx = null,
    };
}

fn resolveDeliberatelyWrong(_: ?*const anyopaque, rc: ResolveContext) Resolution {
    return .{ .value = rc.L - 1 };
}

/// capture budget resolver — registered with its non-convergence on the label.
///
/// PARTIAL IMPLEMENTATION. The budget rule (T387/T397, src/t387_budget.zig,
/// sha 5dbfd551) computes values by solving the full budget-augmented game
/// graph — it cannot be run per-position from [L,H] alone; it requires the
/// full board state, move generation, and a forward minimax search with the
/// game engine. This lightweight resolver does not import the engine.
///
/// What this resolver does:
///   - L==H: propose L (the budget rule preserves the determined region at
///     sufficient B — T387 found 0/21,126 L==H entries move at 3x3 B≥24).
///     At small B the budget value may differ; this resolver cannot detect
///     that case from [L,H] alone.
///   - L<H: no_opinion (the budget value is B-dependent and non-convergent;
///     computing it requires a full forward search).
///
/// This is NOT a silent always-abstain resolver — it proposes for all L==H
/// entries (the column the harness cares about). The limitation is documented
/// so a future reader does not mistake "agrees with L==H at 100%" for "the
/// budget resolver reproduces the table" — it only reproduces the L==H subset,
/// which is definitional at sufficient B, not evidential.
///
/// Measurements (T387/T397, src/t387_budget.zig, sha 5dbfd551):
///   - VERIFIED: the budget-augmented graph is a DAG (0 back-edges at 3x3 B=8
///     and 4x3 B=8; control finds 135,512 / 4,929,916).
///   - VERIFIED: Bellman-consistent (0 minimax-identity mismatches).
///   - FALSIFIED for correctness: 4x3 root oscillates forever in {0,1,2,7,9,12}
///     and never equals PSK truth +4.
///   - 3x3: L==H region preserved only at B >= 24 (20,780/21,126 entries move
///     at B=0); L<H values B-dependent and non-convergent (1,252-1,648 slots
///     drift between B=24/32/48).
///   - The budget relocates the bracket's ambiguity into a budget-exhaustion
///     race instead of resolving it.
///   - INTERNAL CONSISTENCY IS NOT EXTERNAL AGREEMENT.
pub fn resolverCaptureBudget(B: u8) Resolver {
    const BudgetCtx = struct {
        B: u8,
    };
    // Leaked intentionally — resolver lives for the program lifetime.
    const alloc = std.heap.page_allocator;
    const ctx = alloc.create(BudgetCtx) catch @panic("OOM");
    ctx.B = B;

    return .{
        .name = "capture_budget",
        .metadata = 
        \\Capture-budget resolver — partial implementation; REGISTERED AS A CAUTIONARY TALE.
        \\Proposes L for L==H entries (budget preserves the determined region at sufficient B,
        \\per T387); no_opinion for L<H (requires full forward search, not available from
        \\[L,H] alone). The budget construction is measured and known-wrong as a valuing rule
        \\(T387/T397). See ADR-0022. Key facts:
        \\  4x3 root oscillates {0,1,2,7,9,12}, never equals PSK truth +4.
        \\  Termination and Bellman consistency were true; neither implies correctness.
        \\  Internal consistency is not external agreement.
        ,
        .resolve = resolveCaptureBudget,
        .self_ctx = ctx,
    };
}

fn resolveCaptureBudget(self_ctx: ?*const anyopaque, rc: ResolveContext) Resolution {
    const BudgetCtx = struct { B: u8 };
    const ctx: *const BudgetCtx = @ptrCast(@alignCast(self_ctx.?));
    _ = ctx;
    // L==H: the budget rule preserves the determined region at sufficient B
    // (T387: 0/21,126 L==H entries move at 3×3 B≥24). Propose L.
    // L<H: the budget value requires a full forward search with the engine —
    // not computable from [L,H] alone. Return no_opinion.
    if (rc.L == rc.H) {
        return .{ .value = rc.L };
    }
    return .no_opinion;
}

// ═══════════════════════════════════════════════════════════════════════════
//  COMPARISON HARNESS
// ═══════════════════════════════════════════════════════════════════════════

/// Per-resolver statistics from the comparison harness.
pub const ResolverStats = struct {
    name: []const u8,
    proposed: usize = 0,
    abstained: usize = 0,
    /// Agreement with L==H entries (the column that matters — ground truth)
    agrees_l_eq_h: usize = 0,
    disagrees_l_eq_h: usize = 0,
    /// For L<H entries: proposed value lies inside [L,H]
    inside_bracket: usize = 0,
    outside_bracket: usize = 0,
    /// First witness of L==H disagreement (for reporting)
    first_disagreement: ?Disagreement = null,

    pub fn total(self: *const ResolverStats) usize {
        return self.proposed + self.abstained;
    }

    pub fn agreementRate(self: *const ResolverStats) ?f64 {
        const d = self.agrees_l_eq_h + self.disagrees_l_eq_h;
        if (d == 0) return null;
        return @as(f64, @floatFromInt(self.agrees_l_eq_h)) / @as(f64, @floatFromInt(d));
    }

    pub fn isRefuted(self: *const ResolverStats) bool {
        return self.disagrees_l_eq_h > 0;
    }
};

const Disagreement = struct {
    colex: u32,
    side: i8,
    L: i8,
    H: i8,
    proposed: i8,
};

/// Compare resolvers against position entries.
///
/// positions: a slice of ResolveContext entries (L==H for ground truth,
///   but may also include L<H for bracket containment check).
/// resolvers: slice of resolvers to compare.
/// stats_out: pre-allocated slice, one per resolver, to fill with results.
pub fn compare(
    positions: []const ResolveContext,
    resolvers: []const Resolver,
    stats_out: []ResolverStats,
) void {
    std.debug.assert(stats_out.len >= resolvers.len);

    for (resolvers, 0..) |resolver, ri| {
        stats_out[ri] = .{ .name = resolver.name };
    }

    for (positions) |rc| {
        for (resolvers, 0..) |resolver, ri| {
            const st = &stats_out[ri];
            const resolution = resolver.propose(rc);
            switch (resolution) {
                .value => |v| {
                    st.proposed += 1;
                    if (rc.L == rc.H) {
                        // Ground truth: L == H is the correct single value.
                        if (v == rc.L) {
                            st.agrees_l_eq_h += 1;
                        } else {
                            st.disagrees_l_eq_h += 1;
                            if (st.first_disagreement == null) {
                                st.first_disagreement = .{
                                    .colex = rc.colex,
                                    .side = rc.side,
                                    .L = rc.L,
                                    .H = rc.H,
                                    .proposed = v,
                                };
                            }
                        }
                    } else {
                        // L < H: check bracket containment only (no ground truth)
                        if (v >= rc.L and v <= rc.H) {
                            st.inside_bracket += 1;
                        } else {
                            st.outside_bracket += 1;
                        }
                    }
                },
                .no_opinion => {
                    st.abstained += 1;
                },
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TESTS
// ═══════════════════════════════════════════════════════════════════════════

/// Helper: construct a ResolveContext for testing.
fn mkRc(colex: u32, side: i8, L: i8, H: i8) ResolveContext {
    return .{ .colex = colex, .side = side, .L = L, .H = H };
}

test "none resolver — always no_opinion" {
    const r = resolverNone();
    const cases = [_]ResolveContext{
        mkRc(0, 1, -5, 5),
        mkRc(100, -1, 0, 0),
        mkRc(42, 1, 3, 7),
    };
    for (cases) |c| {
        try testing.expectEqual(Resolution.no_opinion, r.propose(c));
    }
}

test "bracket_low resolver — always propose L" {
    const r = resolverBracketLow();
    try testing.expectEqual(Resolution{ .value = -5 }, r.propose(mkRc(0, 1, -5, 5)));
    try testing.expectEqual(Resolution{ .value = 0 }, r.propose(mkRc(100, -1, 0, 0)));
    try testing.expectEqual(Resolution{ .value = 3 }, r.propose(mkRc(42, 1, 3, 7)));
}

test "bracket_high resolver — always propose H" {
    const r = resolverBracketHigh();
    try testing.expectEqual(Resolution{ .value = 5 }, r.propose(mkRc(0, 1, -5, 5)));
    try testing.expectEqual(Resolution{ .value = 0 }, r.propose(mkRc(100, -1, 0, 0)));
    try testing.expectEqual(Resolution{ .value = 7 }, r.propose(mkRc(42, 1, 3, 7)));
}

test "bracket_mid resolver — propose midpoint" {
    const r = resolverBracketMid();
    // (-5+5)/2 = 0
    try testing.expectEqual(Resolution{ .value = 0 }, r.propose(mkRc(0, 1, -5, 5)));
    // (0+0)/2 = 0
    try testing.expectEqual(Resolution{ .value = 0 }, r.propose(mkRc(100, -1, 0, 0)));
    // (3+7)/2 = 5
    try testing.expectEqual(Resolution{ .value = 5 }, r.propose(mkRc(42, 1, 3, 7)));
    // truncation toward zero: (-3+2)/2 = 0 (⌊-0.5⌋ = 0 in Zig @divTrunc)
    try testing.expectEqual(Resolution{ .value = 0 }, r.propose(mkRc(1, 1, -3, 2)));
}

test "deliberately_wrong resolver — propose L-1" {
    const r = resolverDeliberatelyWrong();
    try testing.expectEqual(Resolution{ .value = -6 }, r.propose(mkRc(0, 1, -5, 5)));
    try testing.expectEqual(Resolution{ .value = -1 }, r.propose(mkRc(100, -1, 0, 0)));
    try testing.expectEqual(Resolution{ .value = 2 }, r.propose(mkRc(42, 1, 3, 7)));
}

test "capture_budget resolver — propose L on L==H, no_opinion on L<H" {
    const r = resolverCaptureBudget(8);
    // L<H: no_opinion (requires full forward search)
    try testing.expectEqual(Resolution.no_opinion, r.propose(mkRc(0, 1, -5, 5)));
    // L==H: propose L (budget preserves determined region at sufficient B)
    try testing.expectEqual(Resolution{ .value = 0 }, r.propose(mkRc(100, -1, 0, 0)));
    try testing.expectEqual(Resolution{ .value = 7 }, r.propose(mkRc(42, 1, 7, 7)));
    // at different B — same behaviour
    const r2 = resolverCaptureBudget(64);
    try testing.expectEqual(Resolution.no_opinion, r2.propose(mkRc(0, 1, -5, 5)));
    try testing.expectEqual(Resolution{ .value = 0 }, r2.propose(mkRc(100, -1, 0, 0)));
}

// ═══════════════════════════════════════════════════════════════════════════
//  COMPARISON HARNESS TESTS (unit-level)
// ═══════════════════════════════════════════════════════════════════════════

test "comparison harness — null control: none resolver proposes nothing" {
    const positions = [_]ResolveContext{
        mkRc(0, 1, 5, 5), // L==H
        mkRc(1, -1, -3, -3), // L==H
        mkRc(2, 1, 0, 4), // L<H
    };
    const resolvers = [_]Resolver{ resolverNone() };
    var stats: [1]ResolverStats = undefined;
    compare(&positions, &resolvers, &stats);

    try testing.expectEqual(@as(usize, 0), stats[0].proposed);
    try testing.expectEqual(@as(usize, 3), stats[0].abstained);
    try testing.expectEqual(@as(usize, 0), stats[0].agrees_l_eq_h);
    try testing.expectEqual(@as(usize, 0), stats[0].disagrees_l_eq_h);
    try testing.expect(!stats[0].isRefuted());
}

test "comparison harness — bracket_low on L==H entries: agrees 100%" {
    const positions = [_]ResolveContext{
        mkRc(0, 1, 5, 5),
        mkRc(1, -1, -3, -3),
        mkRc(2, 1, 0, 0),
        mkRc(3, -1, 7, 7),
    };
    const resolvers = [_]Resolver{ resolverBracketLow() };
    var stats: [1]ResolverStats = undefined;
    compare(&positions, &resolvers, &stats);

    try testing.expectEqual(@as(usize, 4), stats[0].proposed);
    try testing.expectEqual(@as(usize, 0), stats[0].abstained);
    try testing.expectEqual(@as(usize, 4), stats[0].agrees_l_eq_h);
    try testing.expectEqual(@as(usize, 0), stats[0].disagrees_l_eq_h);
    try testing.expect(!stats[0].isRefuted());
}

test "comparison harness — bracket_mid on L<H entries: bracket containment" {
    const positions = [_]ResolveContext{
        mkRc(0, 1, 2, 6), // mid=4, inside [2,6]
        mkRc(1, -1, -5, -1), // mid=-3, inside [-5,-1]
    };
    const resolvers = [_]Resolver{ resolverBracketMid() };
    var stats: [1]ResolverStats = undefined;
    compare(&positions, &resolvers, &stats);

    try testing.expectEqual(@as(usize, 2), stats[0].proposed);
    try testing.expectEqual(@as(usize, 0), stats[0].abstained);
    try testing.expectEqual(@as(usize, 2), stats[0].inside_bracket);
    try testing.expectEqual(@as(usize, 0), stats[0].outside_bracket);
    // L < H, so no L==H entries to check
    try testing.expectEqual(@as(usize, 0), stats[0].agrees_l_eq_h);
    try testing.expectEqual(@as(usize, 0), stats[0].disagrees_l_eq_h);
}

test "comparison harness — deliberately_wrong IS REFUTED on L==H entries" {
    // This is the seeded control. If this test fails, the harness is broken.
    const positions = [_]ResolveContext{
        mkRc(0, 1, 5, 5), // L==H=5, resolver proposes L-1=4 → MISMATCH → REFUTED
        mkRc(1, -1, 0, 0), // L==H=0, resolver proposes -1 → MISMATCH
    };
    const resolvers = [_]Resolver{ resolverDeliberatelyWrong() };
    var stats: [1]ResolverStats = undefined;
    compare(&positions, &resolvers, &stats);

    try testing.expectEqual(@as(usize, 2), stats[0].proposed);
    try testing.expectEqual(@as(usize, 0), stats[0].agrees_l_eq_h);
    try testing.expectEqual(@as(usize, 2), stats[0].disagrees_l_eq_h);
    try testing.expect(stats[0].isRefuted());
    try testing.expect(stats[0].first_disagreement != null);
    try testing.expectEqual(@as(i8, 4), stats[0].first_disagreement.?.proposed);
}

test "comparison harness — all resolvers together" {
    const positions = [_]ResolveContext{
        mkRc(0, 1, 5, 5), // L==H
        mkRc(1, -1, -3, -3), // L==H
        mkRc(2, 1, 0, 4), // L<H, bracket straddles
        mkRc(3, -1, 2, 8), // L<H, bracket positive
    };
    const resolvers = [_]Resolver{
        resolverNone(),
        resolverBracketLow(),
        resolverBracketHigh(),
        resolverBracketMid(),
        resolverDeliberatelyWrong(),
        resolverCaptureBudget(8),
    };
    var stats: [6]ResolverStats = undefined;
    compare(&positions, &resolvers, &stats);

    // none
    try testing.expectEqual(@as(usize, 0), stats[0].proposed);
    try testing.expectEqual(@as(usize, 4), stats[0].abstained);
    try testing.expect(!stats[0].isRefuted());

    // bracket_low
    try testing.expectEqual(@as(usize, 4), stats[1].proposed);
    try testing.expectEqual(@as(usize, 0), stats[1].abstained);
    // L==H: 5→5 ✓, -3→-3 ✓ — 2/2 agrees
    try testing.expectEqual(@as(usize, 2), stats[1].agrees_l_eq_h);
    try testing.expectEqual(@as(usize, 0), stats[1].disagrees_l_eq_h);
    try testing.expect(!stats[1].isRefuted());
    // L<H: 0 inside [0,4], 2 inside [2,8]
    try testing.expectEqual(@as(usize, 2), stats[1].inside_bracket);
    try testing.expectEqual(@as(usize, 0), stats[1].outside_bracket);

    // bracket_high
    try testing.expectEqual(@as(usize, 4), stats[2].proposed);
    try testing.expectEqual(@as(usize, 2), stats[2].agrees_l_eq_h);
    try testing.expectEqual(@as(usize, 0), stats[2].disagrees_l_eq_h);

    // bracket_mid
    try testing.expectEqual(@as(usize, 4), stats[3].proposed);
    try testing.expectEqual(@as(usize, 2), stats[3].agrees_l_eq_h);
    try testing.expectEqual(@as(usize, 0), stats[3].disagrees_l_eq_h);

    // deliberately_wrong — MUST be refuted
    try testing.expect(stats[4].isRefuted());
    try testing.expectEqual(@as(usize, 2), stats[4].disagrees_l_eq_h);
    try testing.expectEqual(@as(usize, 0), stats[4].agrees_l_eq_h);

    // capture_budget — proposes L for L==H, no_opinion for L<H
    try testing.expectEqual(@as(usize, 2), stats[5].proposed);
    try testing.expectEqual(@as(usize, 2), stats[5].abstained);
    try testing.expectEqual(@as(usize, 2), stats[5].agrees_l_eq_h);
    try testing.expectEqual(@as(usize, 0), stats[5].disagrees_l_eq_h);
    try testing.expect(!stats[5].isRefuted());
}

// ═══════════════════════════════════════════════════════════════════════════
//  ARTIFACT-BACKED COMPARISON HARNESS
// ═══════════════════════════════════════════════════════════════════════════

// The artifact-backed comparison harness requires artifact2 + colex imports.
// For the standalone test suite (zig test src/resolver.zig), this test is a no-op.
// Run the full harness via:
//   zig build-exe -O ReleaseSafe --dep artifact2 --dep colex --dep version \
//     -Mroot=src/resolver_harness.zig -Martifact2=src/artifact2.zig \
//     -Mcolex=src/colex.zig -Mversion=src/version.zig
test "artifact-backed comparison — 3x3 WZO2" {
    return error.SkipZigTest;
}

// ═══════════════════════════════════════════════════════════════════════════
//  STYLISED COMPARISON OUTPUT (stdout = data)
// ═══════════════════════════════════════════════════════════════════════════

/// Print a human-readable comparison report to stdout.
/// Every figure with its denominator.
pub fn printReport(stats: []const ResolverStats, total_positions: usize, total_l_eq_h: usize, total_l_lt_h: usize) void {
    const p = std.debug.print;
    p("\n═══════════════════════════════════════════════════════════\n", .{});
    p("BRACKET RESOLVER COMPARISON  (ADR-0022)\n", .{});
    p("  positions: {d}  (L==H: {d}, L<H: {d})\n", .{ total_positions, total_l_eq_h, total_l_lt_h });
    p("\n", .{});
    p("{s: <24} {s: >8} {s: >8} {s: >8} {s: >8} {s: >10} {s}\n", .{
        "resolver", "proposed", "abstain", "L==H ✓", "L==H ✗", "verdict", "bracket",
    });
    p("{s:-<24} {s:-<8} {s:-<8} {s:-<8} {s:-<8} {s:-<10} {s}\n", .{
        "", "", "", "", "", "", "",
    });

    for (stats) |st| {
        const verdict: []const u8 = if (st.isRefuted())
            "REFUTED"
        else if (st.proposed == 0)
            "(null)"
        else
            "—";

        const bracket_info = if (total_l_lt_h > 0)
            blk: {
                const denom = st.inside_bracket + st.outside_bracket;
                if (denom == 0) break :blk "—";
                const info_str = std.fmt.allocPrint(
                    std.heap.page_allocator,
                    "{d}/{d} inside",
                    .{ st.inside_bracket, denom },
                ) catch "?";
                break :blk info_str;
            }
        else
            "—";

        p("{s: <24} {d: >8} {d: >8} {d: >8} {d: >8} {s: <10} {s}\n", .{
            st.name,
            st.proposed,
            st.abstained,
            st.agrees_l_eq_h,
            st.disagrees_l_eq_h,
            verdict,
            bracket_info,
        });

        if (st.first_disagreement) |d| {
            p("    first: colex={d} side={d} L={d} H={d} proposed={d}\n", .{
                d.colex, d.side, d.L, d.H, d.proposed,
            });
        }
    }
    p("\n═══════════════════════════════════════════════════════════\n", .{});
}
