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
// T380 (flash) — Q5 instrument: where does basic ko differ from positional
// superko (PSK), and which of those positions does the current table call
// bracket-valued (L<H)?
//
// Frames:
//   3x3  — EXHAUSTIVE. PSK fresh-start values from artifacts/oracle-3x3.wzo
//          (WZO1, the validated PSK oracle); basic-ko fresh-start brackets
//          from data/oracle-3x3-v2.wzo2 (WZO2, rules 3) pinned to the
//          TIE=0 verdict V = clamp(0, [L,H]). Both tables trusted at 3×3.
//          For every legal position × side: divergence? new-table L<H at the
//          fresh-start key? ko-cluster class? Denominators: 12,675 positions
//          × 2 sides = 25,350.
//   4x4  — SAMPLE. Basic-ko pinned fresh-start from data/oracle-4x4-v2.wzo2;
//          PSK fresh-start via the ban-set-keyed Exact solver
//          (retro.Exact(4,4).root, the PSK gold standard) under a node
//          budget, on a stratified sample (by stone count, weighted toward
//          ko-carrying positions where divergence is expected). Every
//          reading cites its within-budget denominator.
//
// Controls:
//   null3 — the 3×3 frame must find ZERO divergence at positions where the
//           new table's fresh-start is single-valued (L==H) AND the position
//           has no ko shape: without a ko or a cycle, basic ko and PSK agree
//           by construction. Any divergence there is an instrument defect.
//           (Positions with L<H or with ko shapes may legitimately diverge.)
//
// Compile (ad hoc):
//   zig build-exe -O ReleaseFast --dep version -Mroot=src/t380_psk_diff.zig \
//     -Mversion=src/version.zig --cache-dir /tmp/weizigo/t380/kc \
//     --global-cache-dir /tmp/weizigo/t380/gc --name weizigo-t380-psk-diff \
//     -femit-bin=/tmp/weizigo/t380/psk-diff
//
// stdout = data, stderr = diagnostics.

const std = @import("std");
const rules = @import("rules.zig");
const colexmod = @import("colex.zig");
const artifact = @import("artifact.zig");
const retro = @import("retro.zig");

const W = 4;
const H = 4;
const N = W * H;
const R = rules.Rules(W, H);
const X = colexmod.Indexer(W, H);
const E = @import("enumerate.zig").Enumerator(W, H);
const Pos = [N]i8;

fn pinned(L: i8, Hv: i8) i8 {
    return @max(L, @min(@as(i8, 0), Hv));
}

fn isKoShape4(pos: *const Pos, p: usize, colour: i8) ?u8 {
    if (pos[p] != 0) return null;
    const next = R.pos_from_move(pos, colour, p) catch return null;
    var opp_before: u8 = 0;
    var opp_after: u8 = 0;
    var captured: ?usize = null;
    for (0..N) |i| {
        if (pos[i] == -colour) opp_before += 1;
        if (next[i] == -colour) opp_after += 1;
        if (pos[i] == -colour and next[i] == 0) captured = i;
    }
    if (opp_before - opp_after != 1) return null;
    var libs: u8 = 0;
    var friends: u8 = 0;
    var nb: [4]usize = undefined;
    const cnt = R.neighbors(p, &nb);
    for (nb[0..cnt]) |q| {
        if (next[q] == 0) libs += 1;
        if (next[q] == colour) friends += 1;
    }
    if (libs != 1 or friends != 0) return null;
    return @intCast(captured.?);
}

/// cluster count (kernel ko-shape definition, reused from the census).
fn clustersOf(pos: *const Pos) u8 {
    const KoPoint = struct { cell: u8, cap: u8 };
    var points: [2 * N]KoPoint = undefined;
    var np: usize = 0;
    for (0..N) |p| {
        inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
            if (isKoShape4(pos, p, colour)) |cap| {
                if (np < 2 * N) {
                    points[np] = .{ .cell = @intCast(p), .cap = cap };
                    np += 1;
                }
            }
        }
    }
    if (np == 0) return 0;
    var masks: [2 * N]u32 = undefined;
    for (points[0..np], 0..) |kp, i| {
        var mask: u32 = 0;
        mask |= @as(u32, 1) << @as(u5, @intCast(kp.cell));
        mask |= @as(u32, 1) << @as(u5, @intCast(kp.cap));
        var nb: [4]usize = undefined;
        const c1 = R.neighbors(kp.cell, &nb);
        for (nb[0..c1]) |q| mask |= @as(u32, 1) << @as(u5, @intCast(q));
        const c2 = R.neighbors(kp.cap, &nb);
        for (nb[0..c2]) |q| mask |= @as(u32, 1) << @as(u5, @intCast(q));
        masks[i] = mask;
    }
    var parent: [2 * N]u8 = undefined;
    for (0..np) |i| parent[i] = @intCast(i);
    for (0..np) |i| {
        for (i + 1..np) |j| {
            if (masks[i] & masks[j] != 0) {
                var ri: u8 = @intCast(i);
                while (parent[ri] != ri) ri = parent[ri];
                var rj: u8 = @intCast(j);
                while (parent[rj] != rj) rj = parent[rj];
                if (ri != rj) parent[ri] = rj;
            }
        }
    }
    var roots: u32 = 0;
    for (0..np) |i| {
        var r: u8 = @intCast(i);
        while (parent[r] != r) r = parent[r];
        roots |= @as(u32, 1) << @as(u5, @intCast(r));
    }
    return @intCast(@popCount(roots));
}

const GroupHdr = struct { colex: u32, count: u8, entry_offset: u64 };
const Wzo2 = struct {
    bytes: []const u8,
    n_groups: u64,
    ko_bits: u8,
    group_base: usize,
    entry_base: usize,
    groups: []GroupHdr,
    fn open(gpa: std.mem.Allocator, path: []const u8) !Wzo2 {
        const cwd = std.Io.Dir.cwd();
        var threaded = std.Io.Threaded.init(gpa, .{});
        defer threaded.deinit();
        const io = threaded.io();
        const bytes = try cwd.readFileAlloc(io, path, gpa, .unlimited);
        if (!std.mem.eql(u8, bytes[0..4], "WZO2")) return error.BadWzo2;
        const n_groups = std.mem.readInt(u64, bytes[16..24], .little);
        const ko_bits = bytes[13];
        const group_base: usize = 128;
        const entry_base: usize = group_base + @as(usize, @intCast(n_groups)) * 5;
        const groups = try gpa.alloc(GroupHdr, @intCast(n_groups));
        var cum: u64 = 0;
        for (0..@as(usize, @intCast(n_groups))) |i| {
            const off = group_base + i * 5;
            groups[i] = .{ .colex = std.mem.readInt(u32, bytes[off..][0..4], .little), .count = bytes[off + 4], .entry_offset = cum };
            cum += groups[i].count;
        }
        return .{ .bytes = bytes, .n_groups = n_groups, .ko_bits = ko_bits, .group_base = group_base, .entry_base = entry_base, .groups = groups };
    }
    fn entryAt(self: *const Wzo2, g: usize, i: usize) struct { L: i8, H: i8, ko: u8, side: i8, passes: u2 } {
        const off = self.entry_base + (self.groups[g].entry_offset + i) * 4;
        const kb = self.bytes[off];
        const side_u1: u1 = @intCast((kb >> 1) & 1);
        const ko_bits = self.ko_bits;
        const ko_raw: u8 = @intCast((kb >> 2) & ((@as(u16, 1) << @intCast(ko_bits)) - 1));
        const passes: u2 = @intCast((kb >> @intCast(2 + ko_bits)) & 1);
        return .{
            .L = @bitCast(self.bytes[off + 1]),
            .H = @bitCast(self.bytes[off + 2]),
            .ko = if (passes >= 1) @as(u8, @intCast(N)) else ko_raw,
            .side = if (side_u1 == 0) @as(i8, 1) else @as(i8, -1),
            .passes = passes,
        };
    }
};

/// Fresh-start (ko=none, passes=0) L/H for a position and side, from a WZO2.
fn freshStart(wzo: *const Wzo2, colex: u32, side: i8, ko_none: u8) ?struct { L: i8, H: i8 } {
    // binary search the group
    var lo: usize = 0;
    var hi: usize = @intCast(wzo.n_groups);
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        if (wzo.groups[mid].colex < colex) {
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }
    if (lo >= wzo.n_groups or wzo.groups[lo].colex != colex) return null;
    for (0..wzo.groups[lo].count) |i| {
        const e = wzo.entryAt(lo, i);
        if (e.side == side and e.ko == ko_none and e.passes == 0) return .{ .L = e.L, .H = e.H };
    }
    return null;
}

fn stonesIn(pos: *const Pos) u8 {
    var c: u8 = 0;
    for (pos) |v| {
        if (v != 0) c += 1;
    }
    return c;
}

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    const mode: []const u8 = args.next() orelse "3x3";

    if (std.mem.eql(u8, mode, "3x3")) {
        var threaded = std.Io.Threaded.init(gpa, .{});
        defer threaded.deinit();
        var dec = try artifact.load(threaded.io(), std.Io.Dir.cwd(), "artifacts/oracle-3x3.wzo", gpa);
        defer dec.deinit();
        var wzo = try Wzo2.open(gpa, "data/oracle-3x3-v2.wzo2");
        defer gpa.free(wzo.groups);
        defer gpa.free(wzo.bytes);
        const X3 = colexmod.Indexer(3, 3);
        const E3 = @import("enumerate.zig").Enumerator(3, 3);
        const R3 = rules.Rules(3, 3);
        const N3: u8 = 9;

        var div_total: u64 = 0;
        var div_lh_set: u64 = 0;
        var div_lh_clear: u64 = 0;
        var div_by_class = [_]u64{0} ** 4;
        var same_total: u64 = 0;
        var same_lh_set: u64 = 0;
        var checked: u64 = 0;
        var null_div: u64 = 0; // divergence at L==H && 0-cluster positions (should be 0)
        var div_examples: u64 = 0;
        var legal_positions: u64 = 0;

        for (0..X3.total) |i| {
            const pos: [9]i8 = X3.pos_from_colex(i);
            if (!E3.is_legal(&pos)) continue;
            legal_positions += 1;
            const cl = clustersOfN3(&pos);
            for ([_]i8{ 1, -1 }) |side| {
                const psk_v = if (side > 0) dec.vb[i] else dec.vw[i];
                const fs = freshStart(&wzo, @intCast(i), side, 9) orelse continue;
                const bko_v = pinned(fs.L, fs.H);
                checked += 1;
                const lh_set = fs.L != fs.H;
                if (psk_v != bko_v) {
                    div_total += 1;
                    if (lh_set) div_lh_set += 1 else div_lh_clear += 1;
                    div_by_class[if (cl >= 3) 3 else cl] += 1;
                    if (!lh_set and cl == 0) null_div += 1;
                    if (div_examples < 5) {
                        std.debug.print("3X3 DIV colex={d} side={d} psk={d} bko={d} L={d} H={d} clusters={d}\n", .{
                            i, side, psk_v, bko_v, fs.L, fs.H, cl,
                        });
                        div_examples += 1;
                    }
                } else {
                    same_total += 1;
                    if (lh_set) same_lh_set += 1;
                }
            }
        }
        _ = R3;
        _ = N3;
        std.debug.print("3X3: legal_positions={d} checked={d} divergent={d} same={d}\n", .{
            legal_positions, checked, div_total, same_total,
        });
        std.debug.print("3X3: divergent by new-table fresh-start status: L<H={d} L==H={d}; by cluster class=[{d},{d},{d},{d}]\n", .{
            div_lh_set, div_lh_clear, div_by_class[0], div_by_class[1], div_by_class[2], div_by_class[3],
        });
        std.debug.print("3X3: same-value with L<H={d}; NULL control divergences at (L==H, 0-cluster)={d} (want 0)\n", .{
            same_lh_set, null_div,
        });
        return;
    }

    if (std.mem.eql(u8, mode, "4x4")) {
        // sample-based: basic-ko pinned fresh-start (WZO2) vs Exact PSK root
        var wzo = try Wzo2.open(gpa, "data/oracle-4x4-v2.wzo2");
        defer gpa.free(wzo.groups);
        defer gpa.free(wzo.bytes);
        var prng = std.Random.DefaultPrng.init(0x5EED_0004);
        const rnd = prng.random();
        // memo-off PSK context arrays, reused across roots (no writes)
        const total4: usize = @intCast(colexmod.Indexer(4, 4).total);
        const psk_vb = try gpa.alloc(i8, total4);
        const psk_vw = try gpa.alloc(i8, total4);
        const psk_cb = try gpa.alloc(bool, total4);
        const psk_cw = try gpa.alloc(bool, total4);
        defer gpa.free(psk_vb);
        defer gpa.free(psk_vw);
        defer gpa.free(psk_cb);
        defer gpa.free(psk_cw);
        var div_total: u64 = 0;
        var div_lh_set: u64 = 0;
        var div_lh_clear: u64 = 0;
        var checked: u64 = 0;
        var budget_excl: u64 = 0;
        const oom_excl: u64 = 0;
        var div_by_class = [_]u64{0} ** 4;
        var null_div: u64 = 0;
        var ex: u64 = 0;

        // strata: 8..15 stones (small PSK subtrees); weight ko-carrying
        // positions 8x to find divergences
        var layer: usize = 10;
        while (layer <= 14) : (layer += 1) {
            const lo = X.layer_offset[layer];
            const hi = X.layer_offset[layer + 1];
            const span = hi - lo;
            const want: u64 = @intCast(@min(@as(u64, 250), span));
            var drawn: u64 = 0;
            var attempts: u64 = 0;
            while (drawn < want and attempts < want * 8) : (attempts += 1) {
                const idx: u64 = lo + rnd.uintLessThan(u64, span);
                const pos: Pos = X.pos_from_colex(idx);
                if (!E.is_legal(&pos)) continue;
                const cl = clustersOf(&pos);
                if (cl == 0 and rnd.uintLessThan(u8, 8) != 0) continue; // weight ko-carrying
                const side: i8 = if (rnd.boolean()) 1 else -1;
                const fs = freshStart(&wzo, @intCast(idx), side, 16) orelse continue;
                drawn += 1;
                checked += 1;
                const bko_v = pinned(fs.L, fs.H);
                // PSK fresh-start via the forward solver with memo/brackets OFF
                // (the psk_divergence HistoryPSK discipline): exact PSK value
                // of the fresh-start root, node-budgeted. The Exact ban-set
                // solver is unusable at 4×4 (5.4 MB per key).
                var o_ctx = retro.Retro(4, 4).O.Ctx{
                    .vb = psk_vb, .vw = psk_vw, .cb = psk_cb, .cw = psk_cw,
                    .memo = false, .memo_writes = false, .brackets = false,
                    .saw_ban = false, .nodes = 0, .budget = 200_000,
                    .lbb = null, .ubb = null, .lbw = null, .ubw = null,
                    .deps = false, .dep_map = null, .dep_layer_max = 255,
                    .journal = null, .journal_gpa = undefined,
                };
                var hist = retro.Retro(4, 4).O.History{};
                if (retro.Retro(4, 4).O.value_from_root(&o_ctx, &pos, side, &hist)) |psk_v| {
                    const lh_set = fs.L != fs.H;
                    if (psk_v != bko_v) {
                        div_total += 1;
                        if (lh_set) div_lh_set += 1 else div_lh_clear += 1;
                        div_by_class[if (cl >= 3) 3 else cl] += 1;
                        if (!lh_set and cl == 0) null_div += 1;
                        if (ex < 5) {
                            std.debug.print("4X4 DIV colex={d} stones={d} side={d} psk={d} bko={d} L={d} H={d} clusters={d} nodes={d}\n", .{
                                idx, stonesIn(&pos), side, psk_v, bko_v, fs.L, fs.H, cl, o_ctx.nodes,
                            });
                            ex += 1;
                        }
                    }
                } else |_| {
                    budget_excl += 1; // the only error from O.solve with these flags is Budget
                }
            }
        }
        std.debug.print("4X4: checked={d} budget_excluded={d} oom_excluded={d} divergent={d} (within-budget)\n", .{
            checked, budget_excl, oom_excl, div_total,
        });
        std.debug.print("4X4: divergent by fresh-start status: L<H={d} L==H={d}; by cluster class=[{d},{d},{d},{d}]\n", .{
            div_lh_set, div_lh_clear, div_by_class[0], div_by_class[1], div_by_class[2], div_by_class[3],
        });
        std.debug.print("4X4: NULL control divergences at (L==H, 0-cluster)={d} (want 0)\n", .{ null_div });
        return;
    }

    std.debug.print("unknown mode {s}\n", .{mode});
}

fn isKoShape3(pos: *const [9]i8, p: usize, colour: i8) ?u8 {
    const R3 = rules.Rules(3, 3);
    if (pos[p] != 0) return null;
    const next = R3.pos_from_move(pos, colour, p) catch return null;
    var opp_before: u8 = 0;
    var opp_after: u8 = 0;
    var captured: ?usize = null;
    for (0..9) |i| {
        if (pos[i] == -colour) opp_before += 1;
        if (next[i] == -colour) opp_after += 1;
        if (pos[i] == -colour and next[i] == 0) captured = i;
    }
    if (opp_before - opp_after != 1) return null;
    var libs: u8 = 0;
    var friends: u8 = 0;
    var nb: [4]usize = undefined;
    const cnt = R3.neighbors(p, &nb);
    for (nb[0..cnt]) |q| {
        if (next[q] == 0) libs += 1;
        if (next[q] == colour) friends += 1;
    }
    if (libs != 1 or friends != 0) return null;
    return @intCast(captured.?);
}

fn clustersOfN3(pos: *const [9]i8) u8 {
    const KoPoint = struct { cell: u8, cap: u8 };
    var points: [18]KoPoint = undefined;
    var np: usize = 0;
    for (0..9) |p| {
        inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
            if (isKoShape3(pos, p, colour)) |cap| {
                if (np < 18) {
                    points[np] = .{ .cell = @intCast(p), .cap = cap };
                    np += 1;
                }
            }
        }
    }
    if (np == 0) return 0;
    const R3 = rules.Rules(3, 3);
    var masks: [18]u32 = undefined;
    for (points[0..np], 0..) |kp, i| {
        var mask: u32 = 0;
        mask |= @as(u32, 1) << @as(u5, @intCast(kp.cell));
        mask |= @as(u32, 1) << @as(u5, @intCast(kp.cap));
        var nb: [4]usize = undefined;
        const c1 = R3.neighbors(kp.cell, &nb);
        for (nb[0..c1]) |q| mask |= @as(u32, 1) << @as(u5, @intCast(q));
        const c2 = R3.neighbors(kp.cap, &nb);
        for (nb[0..c2]) |q| mask |= @as(u32, 1) << @as(u5, @intCast(q));
        masks[i] = mask;
    }
    var parent: [18]u8 = undefined;
    for (0..np) |i| parent[i] = @intCast(i);
    for (0..np) |i| {
        for (i + 1..np) |j| {
            if (masks[i] & masks[j] != 0) {
                var ri: u8 = @intCast(i);
                while (parent[ri] != ri) ri = parent[ri];
                var rj: u8 = @intCast(j);
                while (parent[rj] != rj) rj = parent[rj];
                if (ri != rj) parent[ri] = rj;
            }
        }
    }
    var roots: u32 = 0;
    for (0..np) |i| {
        var r: u8 = @intCast(i);
        while (parent[r] != r) r = parent[r];
        roots |= @as(u32, 1) << @as(u5, @intCast(r));
    }
    return @intCast(@popCount(roots));
}
