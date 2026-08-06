////////////////////////////////////////////
//                                        //
//    (c) 2026 Alexander E Genaud         //
//                                        //
//    Permission is granted hereby,       //
//        for any purpose,                //
//    provided these notices multiply.    //
//                                        //
////////////////////////////////////////////
//
// T386 (flash) — layer distribution of the bracket-valued region.
//
// Reads a WZO2 table (data/oracle-3x3-v2.wzo2 or data/oracle-4x4-v2.wzo2)
// and aggregates the FRESH-START slice (ko = none, passes = 0) per
// retrograde layer (layer = number of stones on the goban; the retrograde
// sweeps stone-count DESCENDING, so "depth" here means distance from the
// settled/terminal wall measured in stones).
//
// Per layer:
//   groups       — positions with at least one table entry
//   fresh        — fresh-start entries (positions x sides with an entry)
//   fresh_bracket— fresh-start entries with L < H
//   bracket_pos  — positions whose fresh-start bracket is L < H on EITHER side
//   width_mean   — mean bracket width (H - L) over fresh_bracket entries
//   width_max    — max bracket width over fresh_bracket entries
//   w_ge_16, w_ge_24, w_eq_32 — deep-tangle counts (width >= 16 / 24 / full 32)
//   all_bracket  — bracket-valued entries over ALL keys (any ko, passes 0/1),
//                  for context (the ko-set keys the proposal does not address)
//
// Denominator for every per-layer fraction: the layer's `groups` (positions),
// or `fresh` (fresh-start entries) as stated per line.
//
// Controls: the 3×3 frame is a cheap full-table re-derivation (the 4×4 frame
// is the same code path on the 518 MB artifact); the 4×4 totals must
// reproduce T380's published fresh-start census (1,924,973 bracket-valued
// positions / 981,071 per side / 7.87% of 24,318,165).
//
// Compile (ad hoc):
//   zig build-exe -O ReleaseFast --dep version -Mroot=src/t386_layers.zig \
//     -Mversion=src/version.zig --cache-dir /tmp/weizigo/t386/kc \
//     --global-cache-dir /tmp/weizigo/t386/gc --name weizigo-t386-layers \
//     -femit-bin=/tmp/weizigo/t386/layers
//
// stdout = data, stderr = diagnostics.

const std = @import("std");
const colexmod = @import("colex.zig");
const eng = @import("t386_engine.zig");

fn stonesIn(comptime N: usize, pos: *const [N]i8) u8 {
    var c: u8 = 0;
    for (pos) |v| {
        if (v != 0) c += 1;
    }
    return c;
}

const LayerStat = struct {
    groups: u64 = 0,
    fresh: u64 = 0,
    fresh_bracket: u64 = 0,
    bracket_pos: u64 = 0,
    width_sum: u64 = 0,
    width_max: i8 = 0,
    w_ge_16: u64 = 0,
    w_ge_24: u64 = 0,
    w_eq_32: u64 = 0,
    all_bracket: u64 = 0,
};

fn run(comptime W: usize, comptime H: usize, gpa: std.mem.Allocator, path: []const u8) !void {
    const N: usize = W * H;
    const X = colexmod.Indexer(W, H);
    var wzo = try eng.Wzo2.open(gpa, path);
    defer gpa.free(wzo.groups);
    defer gpa.free(wzo.bytes);

    var layers: [N + 1]LayerStat = undefined;
    for (&layers) |*st| st.* = .{};
    var total_groups: u64 = 0;
    var total_fresh: u64 = 0;
    var total_fresh_bracket: u64 = 0;
    var total_bracket_pos: u64 = 0;
    var total_width_sum: u64 = 0;
    var total_all_bracket: u64 = 0;

    for (0..@as(usize, @intCast(wzo.n_groups))) |g| {
        const colex = wzo.groups[g].colex;
        const pos = X.pos_from_colex(colex);
        const layer: usize = stonesIn(N, &pos);
        const st = &layers[layer];
        st.groups += 1;
        total_groups += 1;
        var bracket_b = false;
        var bracket_w = false;
        for (0..wzo.groups[g].count) |i| {
            const e = wzo.entryAt(g, i);
            if (e.L < e.H) {
                st.all_bracket += 1;
                total_all_bracket += 1;
            }
            if (e.passes != 0 or e.ko != N) continue;
            st.fresh += 1;
            total_fresh += 1;
            if (e.L < e.H) {
                st.fresh_bracket += 1;
                total_fresh_bracket += 1;
                const width: i8 = e.H - e.L;
                st.width_sum += @intCast(width);
                total_width_sum += @intCast(width);
                if (width > st.width_max) st.width_max = width;
                if (width >= 16) st.w_ge_16 += 1;
                if (width >= 24) st.w_ge_24 += 1;
                if (width >= 32) st.w_eq_32 += 1;
                if (e.side > 0) bracket_b = true else bracket_w = true;
            }
        }
        if (bracket_b or bracket_w) {
            st.bracket_pos += 1;
            total_bracket_pos += 1;
        }
    }

    std.debug.print("T386-LAYERS {d}x{d} wzo2 groups={d} fresh-entries={d}\n", .{ W, H, total_groups, total_fresh });
    std.debug.print("layer groups fresh fresh_bracket bracket_pos all_bracket width_mean width_max w_ge_16 w_ge_24 w_eq_32\n", .{});
    var layer: usize = N + 1;
    while (layer > 0) {
        layer -= 1;
        const st = layers[layer];
        if (st.groups == 0) continue;
        const mean: f64 = if (st.fresh_bracket > 0) @as(f64, @floatFromInt(st.width_sum)) / @as(f64, @floatFromInt(st.fresh_bracket)) else 0;
        std.debug.print("{d} {d} {d} {d} {d} {d} {d:.2} {d} {d} {d} {d}\n", .{
            layer, st.groups, st.fresh, st.fresh_bracket, st.bracket_pos, st.all_bracket, mean, st.width_max, st.w_ge_16, st.w_ge_24, st.w_eq_32,
        });
    }
    const total_mean: f64 = if (total_fresh_bracket > 0) @as(f64, @floatFromInt(total_width_sum)) / @as(f64, @floatFromInt(total_fresh_bracket)) else 0;
    std.debug.print("TOTALS {d}x{d}: groups={d} fresh={d} fresh_bracket={d} bracket_pos={d} all_bracket={d} width_mean={d:.2} fresh-bracket-positions-pct={d:.4}\n", .{
        W, H, total_groups, total_fresh, total_fresh_bracket, total_bracket_pos, total_all_bracket, total_mean,
        @as(f64, @floatFromInt(total_bracket_pos)) * 100.0 / @as(f64, @floatFromInt(total_groups)),
    });
}

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    const mode: []const u8 = args.next() orelse "4x4";
    if (std.mem.eql(u8, mode, "3x3")) {
        try run(3, 3, gpa, "data/oracle-3x3-v2.wzo2");
    } else {
        try run(4, 4, gpa, "data/oracle-4x4-v2.wzo2");
    }
}
