////////////////////////////////////////////
// T274 — small-goban tie-constant sweep harness.
// Task: T274 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-02
//
// Imports src/exp6_solve.zig and re-runs the 2×2, 3×2 (and, supplementary, 3×3)
// fixpoints for whatever comptime `pub const TIE` (line 41) is compiled into that
// file. Per run the ONLY change to exp6_solve.zig is that constant.
//
// What this demonstrates (D014 descope):
//   (1) L/H tables are produced by TIE-free fixpoint sweeps, so they must be
//       bit-identical across runs — printed as additive fingerprints.
//   (2) V = median(L,TIE,H) must equal clamp(TIE,[L,H]) at every reachable state
//       — checked exhaustively (violations must be 0).
//   (3) the bracket census: states with L==H (resolved), L<TIE<H (tie-pinned:
//       V == TIE, moves with the constant), L>TIE (pin_L), H<TIE (pin_H).
//   (4) the 5 widest-bracket states are the same states every run (L/H identical);
//       their V follows the clamp, including V == TIE when TIE lands inside.
//   (5) TIE=0 run is the null control: roots must match the committed gates
//       (2×2 = 0, 3×2 = 0, 3×3 = +9).
//
// main() of exp6_solve.zig (incl. the 4×4 census/fixpoint/WZO write) is never
// referenced here, so it is not analyzed and not executed.
//
// Build: tools/runner -- zig run -O ReleaseFast src/t274_tie_harness.zig
////////////////////////////////////////////

const std = @import("std");
const e = @import("exp6_solve.zig");

const Widest = struct { lin: u64, L: i8, H: i8, V: i8 };

fn clamp(L: i8, H: i8, tie: i8) i8 {
    return @max(L, @min(tie, H));
}

fn fingerprint(tab: []const i8) u64 {
    var acc: u64 = 0;
    for (tab) |v| acc = acc *% 31 +% @as(u8, @bitCast(v));
    return acc;
}

const CensusOut = struct {
    reachable: u64,
    l_eq_h: u64,
    tie_inside: u64,
    pin_l: u64,
    pin_h: u64,
    violations: u64,
};

fn censusRow(L: i8, H: i8, V: i8, c: *CensusOut) void {
    if (V != clamp(L, H, e.TIE)) c.violations += 1;
    if (L == H) c.l_eq_h += 1
    else if (L < e.TIE and e.TIE < H) c.tie_inside += 1
    else if (L > e.TIE) c.pin_l += 1
    else c.pin_h += 1;
}

fn widestPush(widest: *[5]Widest, wc: *usize, lin: u64, L: i8, H: i8, V: i8) void {
    if (wc.* < 5) {
        widest[wc.*] = .{ .lin = lin, .L = L, .H = H, .V = V };
        wc.* += 1;
        return;
    }
    var w_min: usize = 0;
    for (widest, 0..) |w, k| {
        if (w.H - w.L < widest[w_min].H - widest[w_min].L) w_min = k;
    }
    if (H - L > widest[w_min].H - widest[w_min].L) {
        widest[w_min] = .{ .lin = lin, .L = L, .H = H, .V = V };
    }
}

fn printWidest(tag: []const u8, widest: *const [5]Widest, wc: usize) void {
    std.debug.print("{s} widest (lin,L,H,V):\n", .{tag});
    for (widest[0..wc]) |w| std.debug.print("  {d} {d} {d} {d}\n", .{ w.lin, w.L, w.H, w.V });
}

fn scan2x2(fp: *const e.Fixpoint2x2) void {
    var c = CensusOut{ .reachable = 0, .l_eq_h = 0, .tie_inside = 0, .pin_l = 0, .pin_h = 0, .violations = 0 };
    var widest: [5]Widest = undefined;
    var wc: usize = 0;
    var i: usize = 0;
    while (i < e.N2_TOTAL) : (i += 1) {
        const s = e.Brute2x2.state_from_index(i);
        if (s.passes == 2) continue;
        c.reachable += 1;
        const L = fp.L[i];
        const H = fp.H[i];
        const V = fp.v(i);
        censusRow(L, H, V, &c);
        widestPush(&widest, &wc, i, L, H, V);
    }
    std.debug.print("2x2 census: reachable={d} l_eq_h={d} tie_inside={d} pin_L={d} pin_H={d} violations={d}\n", .{ c.reachable, c.l_eq_h, c.tie_inside, c.pin_l, c.pin_h, c.violations });
    printWidest("2x2", &widest, wc);
}

fn scan3x2(gpa: std.mem.Allocator, reach: []const u64, L_tab: []const i8, H_tab: []const i8) void {
    var c = CensusOut{ .reachable = 0, .l_eq_h = 0, .tie_inside = 0, .pin_l = 0, .pin_h = 0, .violations = 0 };
    var widest: [5]Widest = undefined;
    var wc: usize = 0;
    var lin: u64 = 0;
    while (lin < e.TOTAL32) : (lin += 1) {
        const word = lin >> 6;
        const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
        if (reach[word] & bit == 0) continue;
        const passes: u8 = @intCast(lin / (2 * e.KO_DIMS32 * e.RAW_TOTAL32));
        if (passes == 2) continue;
        c.reachable += 1;
        const L = L_tab[lin];
        const H = H_tab[lin];
        const V = e.median32(L, H);
        censusRow(L, H, V, &c);
        widestPush(&widest, &wc, lin, L, H, V);
    }
    std.debug.print("3x2 census: reachable={d} l_eq_h={d} tie_inside={d} pin_L={d} pin_H={d} violations={d}\n", .{ c.reachable, c.l_eq_h, c.tie_inside, c.pin_l, c.pin_h, c.violations });
    printWidest("3x2", &widest, wc);
    _ = gpa;
}

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    std.debug.print("TIE={d}\n", .{e.TIE});
    std.debug.print("note: L/H from TIE-free fixpoint sweeps; V = median(L,TIE,H)\n", .{});

    // ── 2×2 ──
    const fp2 = e.run_fixpoint_2x2();
    const s_root_b2 = e.Brute2x2.State{ .board = .{0} ** e.N2_N, .side = 1, .ko_point = e.Brute2x2.State.KO_NONE, .passes = 0 };
    const s_root_w2 = e.Brute2x2.State{ .board = .{0} ** e.N2_N, .side = -1, .ko_point = e.Brute2x2.State.KO_NONE, .passes = 0 };
    const rb2 = e.Brute2x2.global_index(s_root_b2);
    const rw2 = e.Brute2x2.global_index(s_root_w2);
    std.debug.print("2x2 root B: L={d} H={d} V={d} clamp_ok={}\n", .{ fp2.L[rb2], fp2.H[rb2], fp2.v(rb2), fp2.v(rb2) == clamp(fp2.L[rb2], fp2.H[rb2], e.TIE) });
    std.debug.print("2x2 root W: L={d} H={d} V={d} clamp_ok={}\n", .{ fp2.L[rw2], fp2.H[rw2], fp2.v(rw2), fp2.v(rw2) == clamp(fp2.L[rw2], fp2.H[rw2], e.TIE) });
    std.debug.print("2x2 sweeps={d} converged={}\n", .{ fp2.sweeps, fp2.converged });
    std.debug.print("2x2 fingerprint: L={d} H={d}\n", .{ fingerprint(&fp2.L), fingerprint(&fp2.H) });
    scan2x2(&fp2);

    // ── 3×2 ──
    const reach32 = try gpa.alloc(u64, e.ReachWords32);
    defer gpa.free(reach32);
    const L32 = try gpa.alloc(i8, e.TOTAL32);
    defer gpa.free(L32);
    const H32 = try gpa.alloc(i8, e.TOTAL32);
    defer gpa.free(H32);
    _ = try e.run_census_3x2(gpa, reach32);
    _ = e.run_fixpoint_3x2(reach32, L32, H32);
    const root32_b = e.StateIdx32{ .board = 0, .side = 0, .ko = e.KO_NONE32, .passes = 0 };
    const root32_w = e.StateIdx32{ .board = 0, .side = 1, .ko = e.KO_NONE32, .passes = 0 };
    const lb32 = L32[root32_b.linear()];
    const hb32 = H32[root32_b.linear()];
    const lw32 = L32[root32_w.linear()];
    const hw32 = H32[root32_w.linear()];
    std.debug.print("3x2 root B: L={d} H={d} V={d} clamp_ok={}\n", .{ lb32, hb32, e.median32(lb32, hb32), e.median32(lb32, hb32) == clamp(lb32, hb32, e.TIE) });
    std.debug.print("3x2 root W: L={d} H={d} V={d} clamp_ok={}\n", .{ lw32, hw32, e.median32(lw32, hw32), e.median32(lw32, hw32) == clamp(lw32, hw32, e.TIE) });
    std.debug.print("3x2 fingerprint: L={d} H={d}\n", .{ fingerprint(L32), fingerprint(H32) });
    scan3x2(gpa, reach32, L32, H32);

    // ── 3×3 (supplementary: the L==H root case) ──
    const reach3 = try gpa.alloc(u64, e.ReachWords);
    defer gpa.free(reach3);
    const L3 = try gpa.alloc(i8, e.TOTAL);
    defer gpa.free(L3);
    const H3 = try gpa.alloc(i8, e.TOTAL);
    defer gpa.free(H3);
    _ = try e.run_census_3x3(gpa, reach3);
    _ = e.run_fixpoint_3x3(reach3, L3, H3);
    const root3_b = e.StateIdx{ .board = 0, .side = 0, .ko = e.KO_NONE, .passes = 0 };
    const root3_w = e.StateIdx{ .board = 0, .side = 1, .ko = e.KO_NONE, .passes = 0 };
    const lb3 = L3[root3_b.linear()];
    const hb3 = H3[root3_b.linear()];
    const lw3 = L3[root3_w.linear()];
    const hw3 = H3[root3_w.linear()];
    std.debug.print("3x3 root B: L={d} H={d} V={d} clamp_ok={}\n", .{ lb3, hb3, e.median(lb3, hb3), e.median(lb3, hb3) == clamp(lb3, hb3, e.TIE) });
    std.debug.print("3x3 root W: L={d} H={d} V={d} clamp_ok={}\n", .{ lw3, hw3, e.median(lw3, hw3), e.median(lw3, hw3) == clamp(lw3, hw3, e.TIE) });
    std.debug.print("3x3 fingerprint: L={d} H={d}\n", .{ fingerprint(L3), fingerprint(H3) });
}
