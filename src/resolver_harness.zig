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
// resolver_harness.zig — artifact-backed bracket-resolver comparison (ADR-0022).
//
// Task: T402 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-07
//
// Loads a WZO2 artifact, enumerates positions where the table has an opinion
// (all reachable states at passes=0, ko=NONE), and runs every registered
// resolver against them. Reports per resolver with denominator.
//
// Controls:
//   null — the `none` resolver proposes nothing (zero counters)
//   seeded — `deliberately_wrong` (propose L-1) MUST be marked REFUTED
//
// Usage:
//   zig build-exe -O ReleaseSafe --dep artifact2 --dep colex --dep version \
//     -Mroot=src/resolver_harness.zig -Martifact2=src/artifact2.zig \
//     -Mcolex=src/colex.zig -Mversion=src/version.zig \
//     --cache-dir /tmp/weizigo/t402/cache \
//     --global-cache-dir /tmp/weizigo/t402/global \
//     --name weizigo-t402-resolver-harness \
//     -femit-bin=/tmp/weizigo/t402/resolver-harness
//
//   /tmp/weizigo/t402/resolver-harness [--wzo2 <path>] [--size 3|4] [--sample <N>] [--seed <N>]

const std = @import("std");
const artifact2 = @import("artifact2");
const colexmod = @import("colex");
const resolver = @import("resolver.zig");
const version = @import("version");

const SCORES_ARE_BLACK_POSITIVE = true;

// ═══════════════════════════════════════════════════════════════════════════
//  POSITION ENUMERATION
// ═══════════════════════════════════════════════════════════════════════════

const BracketedPos = struct {
    colex: u32,
    side: i8,
    L: i8,
    H: i8,
    L_eq_H: bool,
};

fn enumeratePositions(
    comptime w: comptime_int,
    comptime h: comptime_int,
    a2: *const artifact2.LoadedArtifact,
    gpa: std.mem.Allocator,
) ![]BracketedPos {
    const n = w * h;
    const KO_NONE: u8 = n;
    const G: usize = @intCast(a2.header.n_groups);
    const groups = a2.data[a2.group_base .. a2.group_base + G * artifact2.GROUP_HEADER_SIZE];

    var results: std.ArrayListUnmanaged(BracketedPos) = .empty;
    var cum: u64 = 0;

    for (0..G) |g| {
        const grp = groups[g * artifact2.GROUP_HEADER_SIZE ..];
        const colex_val = std.mem.readInt(u32, grp[0..4], .little);
        const count: usize = grp[4];

        const entry_off = a2.entry_base + cum * artifact2.ENTRY_SIZE;
        for (0..count) |ei| {
            const eb = a2.data[entry_off + ei * artifact2.ENTRY_SIZE ..][0..artifact2.ENTRY_SIZE];
            const kb = eb[0];
            const decoded = artifact2.decodeKeyByte(kb, a2.header.ko_bits);

            if (decoded.terminal != 0) continue;
            if (decoded.ko != KO_NONE) continue;
            if (decoded.passes != 0) continue;

            const L: i8 = @bitCast(eb[1]);
            const H: i8 = @bitCast(eb[2]);
            const side = artifact2.u1ToSide(decoded.side);

            try results.append(gpa, .{
                .colex = colex_val,
                .side = side,
                .L = L,
                .H = H,
                .L_eq_H = L == H,
            });
        }
        cum += count;
    }

    return results.toOwnedSlice(gpa);
}

// ═══════════════════════════════════════════════════════════════════════════
//  MAIN
// ═══════════════════════════════════════════════════════════════════════════

fn runHarness(
    comptime w: comptime_int,
    comptime h: comptime_int,
    io: std.Io,
    gpa: std.mem.Allocator,
    wzo2_path: []const u8,
    sample_n: ?usize,
    seed: u64,
) !void {
    const p = std.debug.print;
    _ = colexmod.Indexer(w, h); // type-check only; harness uses artifact2 interface

    p("T402 bracket-resolver comparison  {d}x{d}  seed={d}\n", .{ w, h, seed });
    p("ADR-0022 — pluggable bracket resolvers; none is authoritative\n", .{});
    p("internal consistency is not external agreement\n\n", .{});

    // Load WZO2 artifact
    var a2 = try artifact2.load(io, std.Io.Dir.cwd(), wzo2_path, gpa);
    defer a2.deinit();
    p("loaded WZO2: {s}  {d}x{d}  groups={d}  entries={d}\n\n", .{
        wzo2_path, a2.header.w, a2.header.h, a2.header.n_groups, a2.header.n_entries,
    });

    // Enumerate positions
    const all_positions = try enumeratePositions(w, h, &a2, gpa);
    defer gpa.free(all_positions);

    var l_eq_h: usize = 0;
    var l_lt_h: usize = 0;
    for (all_positions) |bp| {
        if (bp.L_eq_H) {
            l_eq_h += 1;
        } else {
            l_lt_h += 1;
        }
    }
    p("enumerated {d} positions  (L==H: {d}, L<H: {d})\n\n", .{ all_positions.len, l_eq_h, l_lt_h });

    // Sample if needed
    var positions = all_positions;
    var sampled: ?[]BracketedPos = null;
    if (sample_n != null and sample_n.? < all_positions.len) {
        var rng = std.Random.DefaultPrng.init(seed);
        const rand = rng.random();
        const sp = try gpa.alloc(BracketedPos, sample_n.?);
        // Reservoir sampling
        for (0..sample_n.?) |i| {
            sp[i] = all_positions[i];
        }
        var t = sample_n.?;
        for (sample_n.?..all_positions.len) |i| {
            t += 1;
            const j = rand.uintLessThan(usize, t);
            if (j < sample_n.?) {
                sp[j] = all_positions[i];
            }
        }
        sampled = sp;
        positions = sp;
        p("sampled {d}/{d} positions (seed={d})\n\n", .{ sample_n.?, all_positions.len, seed });
    }

    // Build resolve contexts
    const rcs = try gpa.alloc(resolver.ResolveContext, positions.len);
    defer gpa.free(rcs);
    var sl_eq_h: usize = 0;
    var sl_lt_h: usize = 0;
    for (positions, 0..) |bp, i| {
        rcs[i] = .{ .colex = bp.colex, .side = bp.side, .L = bp.L, .H = bp.H };
        if (bp.L_eq_H) {
            sl_eq_h += 1;
        } else {
            sl_lt_h += 1;
        }
    }

    // Registered resolvers
    const resolvers = [_]resolver.Resolver{
        resolver.resolverNone(),
        resolver.resolverBracketLow(),
        resolver.resolverBracketHigh(),
        resolver.resolverBracketMid(),
        resolver.resolverDeliberatelyWrong(),
        resolver.resolverCaptureBudget(8),
    };

    var stats: [resolvers.len]resolver.ResolverStats = undefined;
    resolver.compare(rcs, &resolvers, &stats);

    // Print report
    resolver.printReport(&stats, positions.len, sl_eq_h, sl_lt_h);

    // Controls verification
    p("\nCONTROLS:\n", .{});

    // Null: none resolver must propose nothing
    const none_st = stats[0];
    if (none_st.proposed == 0 and none_st.abstained == positions.len) {
        p("  null control PASS: none resolver proposed 0/{d}\n", .{positions.len});
    } else {
        p("  null control FAIL: none resolver proposed {d}, abstained {d}\n", .{ none_st.proposed, none_st.abstained });
    }

    // Seeded: deliberately_wrong must be refuted
    const wrong_st = stats[4];
    if (wrong_st.isRefuted() and l_eq_h > 0) {
        p("  seeded control PASS: deliberately_wrong REFUTED ({d} L==H disagreements / {d} checked)\n", .{ wrong_st.disagrees_l_eq_h, wrong_st.agrees_l_eq_h + wrong_st.disagrees_l_eq_h });
    } else if (l_eq_h == 0) {
        p("  seeded control INCONCLUSIVE: no L==H entries to check (all positions bracketed)\n", .{});
    } else {
        p("  seeded control FAIL: deliberately_wrong NOT refuted — harness may be insensitive\n", .{});
    }

    // Capture budget: partial implementation — proposes L for L==H, no_opinion for L<H.
    // The agreement column is the measurable comparison the row exists to record.
    const cb_st = stats[5];
    p("  capture_budget(8): proposed {d}/{d}, abstained {d}/{d}, L==H agree {d}/{d}", .{
        cb_st.proposed, positions.len,
        cb_st.abstained, positions.len,
        cb_st.agrees_l_eq_h, cb_st.agrees_l_eq_h + cb_st.disagrees_l_eq_h,
    });
    if (cb_st.disagrees_l_eq_h > 0) {
        p(" — REFUTED ({d} disagreements)\n", .{cb_st.disagrees_l_eq_h});
    } else if (cb_st.agrees_l_eq_h + cb_st.disagrees_l_eq_h == 0) {
        p(" (no L==H entries in sample)\n", .{});
    } else {
        p("\n", .{});
    }

    p("\nLandmark: protects L2 (proven 4x4 values) from contamination.\n", .{});
    p("This row demotes a construction rather than advancing one.\n", .{});
    p("The capture budget is now quarantined behind a named interface with its\n", .{});
    p("falsification measurements on the label.\n", .{});
}

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    const io = init.io;

    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next(); // skip program name

    var opt_size: u8 = 3;
    var opt_wzo2: []const u8 = "";
    var opt_sample: ?usize = null;
    var opt_seed: u64 = 42;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--size")) {
            const v = args.next() orelse return error.MissingArgument;
            opt_size = try std.fmt.parseInt(u8, v, 10);
        } else if (std.mem.eql(u8, arg, "--wzo2")) {
            opt_wzo2 = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--sample")) {
            const v = args.next() orelse return error.MissingArgument;
            opt_sample = try std.fmt.parseInt(usize, v, 10);
        } else if (std.mem.eql(u8, arg, "--seed")) {
            const v = args.next() orelse return error.MissingArgument;
            opt_seed = try std.fmt.parseInt(u64, v, 10);
        } else {
            std.debug.print("unknown flag: {s}\n", .{arg});
            std.debug.print("usage: weizigo-t402 [--size 3|4] [--wzo2 <path>] [--sample <N>] [--seed <N>]\n", .{});
            return error.InvalidArgument;
        }
    }

    const size = opt_size;
    if (opt_wzo2.len == 0) {
        opt_wzo2 = switch (size) {
            3 => "data/oracle-3x3-v2.wzo2",
            4 => "data/oracle-4x3-v2.wzo2",
            else => return error.InvalidSize,
        };
    }

    switch (size) {
        3 => try runHarness(3, 3, io, gpa, opt_wzo2, opt_sample, opt_seed),
        4 => try runHarness(4, 3, io, gpa, opt_wzo2, opt_sample, opt_seed),
        else => return error.InvalidSize,
    }
}
