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
// T380 (flash) — Q3/Q4 instrument: multi-ko census over the 4×4 table and
// the bracket-width ⇔ ko-structure correlation.
//
// The table is `data/oracle-4x4-v2.wzo2` (WZO2, rules_id 3 = basic ko + L/H
// bracket; 24,318,165 position groups, 99,133,036 entries). For every group
// (position) it counts the independent basic-ko clusters (union-find over
// single-stone-capture ko shapes, both colours, 1-neighbourhood overlap —
// the same independence notion as B23/`countKoClusters`) and aggregates the
// group's L/H entries: any bracket-valued (L<H) entry, min/max bracket width,
// and the fresh-start (ko=none, passes=0) brackets per side.
//
// Q3 output — the census: cluster-class distribution over all legal 4×4
// positions, over bracket-valued positions, over clear positions; the
// maximum cluster count and its witness positions. Denominator: 24,318,165
// (all legal 4×4 positions — one group per position in the table).
//
// Q4 output — the correlation: bracket-valued positions by cluster class;
// bracket-valued positions with ZERO ko shapes (the second source of
// state-insufficiency, if any); ko-carrying positions with no bracket-valued
// entry (ko that does not widen brackets); bracket-width distribution by
// cluster class; the fresh-start-slice ko-sensitive position counts
// (comparable to the old table's 21.32% figure).
//
// Controls:
//   null    — reproduce the B23/T117 published cluster-class distribution
//             over the OLD checkpoint's ko-sensitive side-positions
//             (data/oracle-4x4.checkpoint.wzo, WZO1): 0:6,741,026 / 1:3,415,640
//             / 2:211,000 / 3+:256 out of 10,367,922, and report agreement.
//             Also cross-checks my union-find against the retro-engine's
//             countKoClusters on a sample (two implementations, one reading).
//   plant   — a seeded-defect control: union-find with the merge disabled
//             (every ko point its own cluster); the 3×3 distribution must
//             differ from the correct one (the instrument catches the defect).
//
// Compile (ad hoc):
//   zig build-exe -O ReleaseFast --dep version -Mroot=src/t380_census.zig \
//     -Mversion=src/version.zig --cache-dir /tmp/weizigo/t380/kc \
//     --global-cache-dir /tmp/weizigo/t380/gc --name weizigo-t380-census \
//     -femit-bin=/tmp/weizigo/t380/census
//
// stdout = data, stderr = diagnostics.

const std = @import("std");
const rules = @import("rules.zig");
const colexmod = @import("colex.zig");
const artifact2 = @import("artifact2.zig");
const artifact = @import("artifact.zig");
const retro = @import("retro.zig");

const W = 4;
const H = 4;
const N = W * H;
const R = rules.Rules(W, H);
const X = colexmod.Indexer(W, H);
const E = @import("enumerate.zig").Enumerator(W, H);
const Pos = [N]i8;

const KoPoint = struct { cell: u8, cap: u8 };

/// Basic-ko shape detector: placing `colour` at `p` captures exactly one
/// opponent stone and the placed stone ends with exactly one liberty and no
/// friendly neighbours (the T273 kernel shape rule, B1/B2). `loose` drops
/// the friendly check (the B23/retro census ko-point definition).
fn isKoShape(pos: *const Pos, p: usize, colour: i8, loose: bool) ?u8 {
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
    if (libs != 1) return null;
    if (!loose and friends != 0) return null;
    return @intCast(captured.?);
}

/// Independent-ko-cluster count: union-find over ko shapes whose
/// 1-neighbourhoods (cell, captured cell, their neighbours) overlap.
/// `planted` disables merging (seeded-defect control). `loose` selects the
/// B23/retro ko-point definition (no friendly check).
fn countClusters(pos: *const Pos, planted: bool, loose: bool) u8 {
    var points: [2 * N]KoPoint = undefined;
    var np: usize = 0;
    for (0..N) |p| {
        inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
            if (isKoShape(pos, p, colour, loose)) |cap| {
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
    if (!planted) {
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
    }
    var roots: u32 = 0;
    for (0..np) |i| {
        var r: u8 = @intCast(i);
        while (parent[r] != r) r = parent[r];
        roots |= @as(u32, 1) << @as(u5, @intCast(r));
    }
    return @intCast(@popCount(roots));
}

/// Raw (unclustered) ko-shape count for a position.
fn countShapes(pos: *const Pos) u8 {
    return countShapesLoose(pos, false);
}
fn countShapesLoose(pos: *const Pos, loose: bool) u8 {
    var c: u8 = 0;
    for (0..N) |p| {
        inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
            if (isKoShape(pos, p, colour, loose) != null) c += 1;
        }
    }
    return c;
}

const ClassCounts = [4]u64; // 0-ko, 1-ko, 2-ko, 3+-ko
const Dist = struct {
    by_class: ClassCounts = .{ 0, 0, 0, 0 },
    max_clusters: u8 = 0,
    max_witness: u64 = 0,
    total: u64 = 0,
};

fn classOf(c: u8) usize {
    return if (c >= 3) 3 else c;
}

const Wzo2Entry = struct { L: i8, H: i8, ko: u8, side: i8, passes: u2, terminal: bool };

fn keyByteSide(kb: u8) u1 {
    return @intCast((kb >> 1) & 1);
}
fn keyByteKo(kb: u8, ko_bits: u8) u8 {
    const mask: u8 = if (ko_bits == 0) 0 else @intCast((@as(u16, 1) << @intCast(ko_bits)) - 1);
    return @intCast((kb >> 2) & mask);
}
fn keyBytePasses(kb: u8, ko_bits: u8) u2 {
    const shift: u3 = @intCast(2 + ko_bits);
    return @intCast((kb >> shift) & 1);
}

const GroupHdr = struct { colex: u32, count: u8, entry_offset: u64 };

/// Raw WZO2 read: header + group index + entry bytes (no lookup API).
const Wzo2 = struct {
    bytes: []const u8,
    n_groups: u64,
    n_entries: u64,
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
        if (bytes.len < 128 or !std.mem.eql(u8, bytes[0..4], "WZO2")) return error.BadWzo2;
        const n_groups = std.mem.readInt(u64, bytes[16..24], .little);
        const n_entries = std.mem.readInt(u64, bytes[24..32], .little);
        const ko_bits = bytes[13];
        const group_base: usize = 128;
        const entry_base: usize = group_base + @as(usize, @intCast(n_groups)) * 5;
        const groups = try gpa.alloc(GroupHdr, @intCast(n_groups));
        var cum: u64 = 0;
        for (0..@as(usize, @intCast(n_groups))) |i| {
            const off = group_base + i * 5;
            groups[i] = .{
                .colex = std.mem.readInt(u32, bytes[off..][0..4], .little),
                .count = bytes[off + 4],
                .entry_offset = cum,
            };
            cum += groups[i].count;
        }
        return .{ .bytes = bytes, .n_groups = n_groups, .n_entries = n_entries, .ko_bits = ko_bits, .group_base = group_base, .entry_base = entry_base, .groups = groups };
    }
    fn entryAt(self: *const Wzo2, g: usize, i: usize) Wzo2Entry {
        const off = self.entry_base + (self.groups[g].entry_offset + i) * 4;
        const kb = self.bytes[off];
        return .{
            .L = @bitCast(self.bytes[off + 1]),
            .H = @bitCast(self.bytes[off + 2]),
            .ko = if (keyBytePasses(kb, self.ko_bits) >= 1) @as(u8, @intCast(N)) else keyByteKo(kb, self.ko_bits),
            .side = if (keyByteSide(kb) == 0) @as(i8, 1) else @as(i8, -1),
            .passes = keyBytePasses(kb, self.ko_bits),
            .terminal = (kb & 1) != 0,
        };
    }
};

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    const mode: []const u8 = args.next() orelse "census";

    if (std.mem.eql(u8, mode, "null")) {
        // Reproduce the B23/T117 published cluster-class distribution over the
        // old checkpoint's ko-sensitive side-positions.
        var threaded = std.Io.Threaded.init(gpa, .{});
        defer threaded.deinit();
        var dec = try artifact.load(threaded.io(), std.Io.Dir.cwd(), "data/oracle-4x4.checkpoint.wzo", gpa);
        defer dec.deinit();
        var dist_kernel = Dist{};
        var dist_loose = Dist{};
        var ko_sens_side_positions: u64 = 0;
        for (0..X.total) |i| {
            if (!E.is_legal(&X.pos_from_colex(i))) continue;
            const pos: Pos = X.pos_from_colex(i);
            const clk = countClusters(&pos, false, false);
            const cll = countClusters(&pos, false, true);
            inline for (.{ @as(u8, 0), @as(u8, 1) }) |sidebit| {
                const flag = if (sidebit == 0) dec.fb[i] else dec.fw[i];
                if (flag & 1 != 0) {
                    ko_sens_side_positions += 1;
                    dist_kernel.by_class[classOf(clk)] += 1;
                    dist_loose.by_class[classOf(cll)] += 1;
                    dist_kernel.total += 1;
                    dist_loose.total += 1;
                    if (clk > dist_kernel.max_clusters) {
                        dist_kernel.max_clusters = clk;
                        dist_kernel.max_witness = i;
                    }
                    if (cll > dist_loose.max_clusters) {
                        dist_loose.max_clusters = cll;
                        dist_loose.max_witness = i;
                    }
                }
            }
        }
        std.debug.print("NULL: ko-sens side-positions={d}\n", .{ko_sens_side_positions});
        std.debug.print("NULL: kernel-def class=[{d},{d},{d},{d}] max={d} witness={d}\n", .{
            dist_kernel.by_class[0], dist_kernel.by_class[1], dist_kernel.by_class[2], dist_kernel.by_class[3], dist_kernel.max_clusters, dist_kernel.max_witness,
        });
        std.debug.print("NULL: loose-def  class=[{d},{d},{d},{d}] max={d} witness={d}\n", .{
            dist_loose.by_class[0], dist_loose.by_class[1], dist_loose.by_class[2], dist_loose.by_class[3], dist_loose.max_clusters, dist_loose.max_witness,
        });
        const want = [_]u64{ 6_741_026, 3_415_640, 211_000, 256 };
        var agree = ko_sens_side_positions == 10_367_922;
        for (want, 0..) |w, j| {
            if (dist_loose.by_class[j] != w) agree = false;
        }
        std.debug.print("NULL: loose-def matches B23 published [6741026,3415640,211000,256]? {s}\n", .{ if (agree) "YES" else "NO" });
        return;
    }

    if (std.mem.eql(u8, mode, "plant")) {
        // Seeded-defect control: the union-find merge is disabled; the 3×3
        // cluster distribution must differ from the correct one.
        const X3 = colexmod.Indexer(3, 3);
        const E3 = @import("enumerate.zig").Enumerator(3, 3);
        const Pos3 = [9]i8;
        var good = Dist{};
        var bad = Dist{};
        var legal3: u64 = 0;
        for (0..X3.total) |i| {
            const pos: Pos3 = X3.pos_from_colex(i);
            if (!E3.is_legal(&pos)) continue;
            legal3 += 1;
            const cg = countClusters3(&pos, false);
            const cb = countClusters3(&pos, true);
            good.by_class[classOf(cg)] += 1;
            bad.by_class[classOf(cb)] += 1;
            good.total += 1;
            bad.total += 1;
        }
        var differs = false;
        for (0..4) |j| {
            if (good.by_class[j] != bad.by_class[j]) differs = true;
        }
        std.debug.print("PLANT: legal3={d} correct=[{d},{d},{d},{d}] planted=[{d},{d},{d},{d}] differs={s}\n", .{
            legal3, good.by_class[0], good.by_class[1], good.by_class[2], good.by_class[3],
            bad.by_class[0], bad.by_class[1], bad.by_class[2], bad.by_class[3],
            if (differs) "YES (defect caught)" else "NO (control failed)",
        });
        return;
    }

    if (std.mem.eql(u8, mode, "scc3")) {
        try scc3(gpa);
        return;
    }

    // ── main census over the 4×4 WZO2 table ──
    var wzo = try Wzo2.open(gpa, "data/oracle-4x4-v2.wzo2");
    defer gpa.free(wzo.groups);
    defer gpa.free(wzo.bytes);

    var all_dist = Dist{}; // over all legal positions
    var set_dist = Dist{}; // over positions with >=1 bracket-valued entry
    var clear_dist = Dist{}; // over positions with 0 bracket-valued entries
    var set_with_zero_ko: u64 = 0; // bracket-valued but no ko shapes
    var ko_with_no_set: u64 = 0; // ko shapes but no bracket-valued entry
    var set_positions: u64 = 0;
    var clear_positions: u64 = 0;
    var legal_positions: u64 = 0;
    var entries_scanned: u64 = 0;
    var bracket_entries: u64 = 0;
    var freshstart_set_b: u64 = 0; // fresh-start (ko=none,passes=0) Black L<H
    var freshstart_set_w: u64 = 0;
    var freshstart_set_either: u64 = 0;
    var freshstart_width_sum_b: u128 = 0;
    var freshstart_width_sum_w: u128 = 0;
    // bracket width histogram over bracket-valued entries (width 1..32)
    var width_hist = [_]u64{0} ** 33;
    // per-class bracket-width stats over positions (max width in the group)
    var class_width_sum = [_]u128{0} ** 4;
    var class_width_count = [_]u64{0} ** 4;
    var class_max_width = [_]u8{0} ** 4;
    var global_max_width: u8 = 0;
    var global_max_witness: u64 = 0;

    var g: usize = 0;
    while (g < wzo.n_groups) : (g += 1) {
        const colex: u64 = wzo.groups[g].colex;
        const cnt: usize = wzo.groups[g].count;
        const pos: Pos = X.pos_from_colex(colex);
        const cl = countClusters(&pos, false, false);
        const shapes = countShapes(&pos);
        legal_positions += 1;
        all_dist.total += 1;
        all_dist.by_class[classOf(cl)] += 1;
        if (cl > all_dist.max_clusters) {
            all_dist.max_clusters = cl;
            all_dist.max_witness = colex;
        }

        var any_set = false;
        var max_width: u8 = 0;
        var fs_b: ?Wzo2Entry = null;
        var fs_w: ?Wzo2Entry = null;
        for (0..cnt) |i| {
            const e = wzo.entryAt(g, i);
            entries_scanned += 1;
            if (e.L != e.H) {
                bracket_entries += 1;
                any_set = true;
                const width: u8 = @intCast(e.H - e.L);
                if (width >= 1 and width <= 32) width_hist[width] += 1;
                if (width > max_width) max_width = width;
            }
            if (e.passes == 0 and e.ko == N) {
                if (e.side > 0) fs_b = e else fs_w = e;
            }
        }
        if (fs_b) |e| {
            if (e.L != e.H) freshstart_set_b += 1;
            freshstart_width_sum_b += @intCast(e.H - e.L);
        }
        if (fs_w) |e| {
            if (e.L != e.H) freshstart_set_w += 1;
            freshstart_width_sum_w += @intCast(e.H - e.L);
        }
        if ((fs_b != null and fs_b.?.L != fs_b.?.H) or (fs_w != null and fs_w.?.L != fs_w.?.H)) freshstart_set_either += 1;

        if (any_set) {
            set_positions += 1;
            set_dist.total += 1;
            set_dist.by_class[classOf(cl)] += 1;
            if (cl > set_dist.max_clusters) {
                set_dist.max_clusters = cl;
                set_dist.max_witness = colex;
            }
            if (shapes == 0) set_with_zero_ko += 1;
            class_width_sum[classOf(cl)] += max_width;
            class_width_count[classOf(cl)] += 1;
            if (max_width > class_max_width[classOf(cl)]) class_max_width[classOf(cl)] = max_width;
            if (max_width > global_max_width) {
                global_max_width = max_width;
                global_max_witness = colex;
            }
        } else {
            clear_positions += 1;
            clear_dist.total += 1;
            clear_dist.by_class[classOf(cl)] += 1;
            if (shapes > 0) ko_with_no_set += 1;
        }
    }

    std.debug.print("CENSUS: legal_positions={d} entries_scanned={d} bracket_entries={d}\n", .{ legal_positions, entries_scanned, bracket_entries });
    std.debug.print("Q3 all positions: total={d} class=[{d},{d},{d},{d}] max_clusters={d} witness={d}\n", .{
        all_dist.total, all_dist.by_class[0], all_dist.by_class[1], all_dist.by_class[2], all_dist.by_class[3], all_dist.max_clusters, all_dist.max_witness,
    });
    std.debug.print("Q3 bracket-valued positions: total={d} class=[{d},{d},{d},{d}] max_clusters={d}\n", .{
        set_dist.total, set_dist.by_class[0], set_dist.by_class[1], set_dist.by_class[2], set_dist.by_class[3], set_dist.max_clusters,
    });
    std.debug.print("Q3 clear positions: total={d} class=[{d},{d},{d},{d}]\n", .{
        clear_dist.total, clear_dist.by_class[0], clear_dist.by_class[1], clear_dist.by_class[2], clear_dist.by_class[3],
    });
    std.debug.print("Q4 set_positions={d} clear_positions={d} set_with_zero_ko={d} ko_with_no_set={d} freshstart_set_b={d} freshstart_set_w={d} freshstart_set_either={d}\n", .{
        set_positions, clear_positions, set_with_zero_ko, ko_with_no_set, freshstart_set_b, freshstart_set_w, freshstart_set_either,
    });
    std.debug.print("Q4 global_max_width={d} witness={d} class_max_width=[{d},{d},{d},{d}] class_mean_width=[{d:.3},{d:.3},{d:.3},{d:.3}]\n", .{
        global_max_width, global_max_witness, class_max_width[0], class_max_width[1], class_max_width[2], class_max_width[3],
        @as(f64, @floatFromInt(class_width_sum[0])) / @as(f64, @floatFromInt(@max(class_width_count[0], 1))),
        @as(f64, @floatFromInt(class_width_sum[1])) / @as(f64, @floatFromInt(@max(class_width_count[1], 1))),
        @as(f64, @floatFromInt(class_width_sum[2])) / @as(f64, @floatFromInt(@max(class_width_count[2], 1))),
        @as(f64, @floatFromInt(class_width_sum[3])) / @as(f64, @floatFromInt(@max(class_width_count[3], 1))),
    });
    std.debug.print("Q4 width_hist (width:count): ", .{});
    for (width_hist, 1..) |c, i| {
        if (c != 0) std.debug.print("{d}:{d} ", .{ i, c });
    }
    std.debug.print("\n", .{});
    if (freshstart_set_b + freshstart_set_w > 0) {
        std.debug.print("Q4 freshstart mean width B={d:.3} W={d:.3}\n", .{
            @as(f64, @floatFromInt(freshstart_width_sum_b)) / @as(f64, @floatFromInt(freshstart_set_b)),
            @as(f64, @floatFromInt(freshstart_width_sum_w)) / @as(f64, @floatFromInt(freshstart_set_w)),
        });
    }
}

/// 3×3 cluster counting for the seeded-defect control (comptime-generic).
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

fn countClusters3(pos: *const [9]i8, planted: bool) u8 {
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
    var masks: [18]u32 = undefined;
    for (points[0..np], 0..) |kp, i| {
        var mask: u32 = 0;
        mask |= @as(u32, 1) << @as(u5, @intCast(kp.cell));
        mask |= @as(u32, 1) << @as(u5, @intCast(kp.cap));
        var nb: [4]usize = undefined;
        const R3 = rules.Rules(3, 3);
        const c1 = R3.neighbors(kp.cell, &nb);
        for (nb[0..c1]) |q| mask |= @as(u32, 1) << @as(u5, @intCast(q));
        const c2 = R3.neighbors(kp.cap, &nb);
        for (nb[0..c2]) |q| mask |= @as(u32, 1) << @as(u5, @intCast(q));
        masks[i] = mask;
    }
    var parent: [18]u8 = undefined;
    for (0..np) |i| parent[i] = @intCast(i);
    if (!planted) {
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
    }
    var roots: u32 = 0;
    for (0..np) |i| {
        var r: u8 = @intCast(i);
        while (parent[r] != r) r = parent[r];
        roots |= @as(u32, 1) << @as(u5, @intCast(r));
    }
    return @intCast(@popCount(roots));
}

/// 3×3 verification of the interpretation "a table entry is bracket-valued
/// (L<H) iff the state can reach a value-ambiguous cycle": compute the SCC
/// decomposition of the 3×3 reachable state graph and report the correlation
/// of the L<H flag with (in a non-trivial SCC) or (can reach a non-trivial
/// SCC). Calibration only — the 4×4 subject is too big for full SCC.
fn scc3(gpa: std.mem.Allocator) !void {
    const R3 = rules.Rules(3, 3);
    const X3 = colexmod.Indexer(3, 3);
    // read the 3×3 WZO2 table entries into a map key = (colex, side, ko, passes)
    var wzo = try Wzo2.open(gpa, "data/oracle-3x3-v2.wzo2");
    defer gpa.free(wzo.groups);
    defer gpa.free(wzo.bytes);
    var by_key = std.AutoHashMap(u64, Wzo2Entry).init(gpa);
    defer by_key.deinit();
    var key_of = std.AutoHashMap(u64, u64).init(gpa); // entry -> compact id
    defer key_of.deinit();
    var id_of = std.AutoHashMap(u64, u64).init(gpa); // compact id -> entry
    defer id_of.deinit();
    var entries_list = try std.ArrayListUnmanaged(u64).initCapacity(gpa, 0);
    defer entries_list.deinit(gpa);
    var n_ids: u64 = 0;
    for (0..@as(usize, @intCast(wzo.n_groups))) |g| {
        const colex: u64 = wzo.groups[g].colex;
        for (0..wzo.groups[g].count) |i| {
            const e = wzo.entryAt(g, i);
            const key: u64 = (colex << 16) | (@as(u64, if (e.side > 0) 0 else 1) << 8) | (@as(u64, e.ko) << 2) | e.passes;
            try by_key.put(key, e);
            try entries_list.append(gpa, key);
            try key_of.put(key, n_ids);
            try id_of.put(n_ids, key);
            n_ids += 1;
        }
    }
    std.debug.print("SCC3: entries={d}\n", .{n_ids});
    // successors
    var succ = try std.ArrayListUnmanaged(u64).initCapacity(gpa, 0);
    defer succ.deinit(gpa);
    var succ_start = try std.ArrayListUnmanaged(u64).initCapacity(gpa, 0);
    defer succ_start.deinit(gpa);
    try succ_start.append(gpa, 0);
    var adj_count: u64 = 0;
    for (0..n_ids) |id| {
        const key = id_of.get(id).?;
        const colex: u64 = key >> 16;
        const side: i8 = if ((key >> 8) & 1 == 0) 1 else -1;
        const ko: u16 = @intCast((key >> 2) & 0x1F);
        const passes: u2 = @intCast(key & 3);
        const pos: [9]i8 = X3.pos_from_colex(colex);
        if (passes >= 2 or R3.is_settled(&pos)) {
            try succ_start.append(gpa, adj_count);
            continue;
        }
        var k: u64 = 0;
        for (0..9) |cell| {
            if (R3.applyMove(&pos, side, @intCast(ko), passes, cell)) |child| {
                const cco: u64 = X3.colex_from_pos(&child.pos);
                const ck: u64 = (cco << 16) | (@as(u64, if (child.side > 0) 0 else 1) << 8) | (@as(u64, child.ko) << 2) | child.passes;
                if (by_key.get(ck)) |_| {
                    try succ.append(gpa, key_of.get(ck).?);
                    k += 1;
                }
            }
        }
        if (R3.applyPass(side, passes)) |pc| {
            const ck: u64 = (colex << 16) | (@as(u64, if (pc.side > 0) 0 else 1) << 8) | (@as(u64, pc.ko) << 2) | pc.passes;
            if (by_key.get(ck)) |_| {
                try succ.append(gpa, key_of.get(ck).?);
                k += 1;
            }
        }
        adj_count += k;
        try succ_start.append(gpa, adj_count);
    }
    std.debug.print("SCC3: adj_count={d}\n", .{adj_count});
    // Tarjan SCC
    var index = try gpa.alloc(u64, @intCast(n_ids));
    defer gpa.free(index);
    var low = try gpa.alloc(u64, @intCast(n_ids));
    defer gpa.free(low);
    var onstack = try gpa.alloc(bool, @intCast(n_ids));
    defer gpa.free(onstack);
    var comp = try gpa.alloc(u64, @intCast(n_ids));
    defer gpa.free(comp);
    @memset(index, std.math.maxInt(u64));
    @memset(comp, std.math.maxInt(u64));
    var stack = try std.ArrayListUnmanaged(u64).initCapacity(gpa, 0);
    defer stack.deinit(gpa);
    var comp_size = try std.ArrayListUnmanaged(u64).initCapacity(gpa, 0);
    defer comp_size.deinit(gpa);
    var n_comp: u64 = 0;
    var counter: u64 = 0;

    const State = struct { v: u64, it: u64 };
    var work = try std.ArrayListUnmanaged(State).initCapacity(gpa, 0);
    defer work.deinit(gpa);

    for (0..n_ids) |root| {
        if (index[root] != std.math.maxInt(u64)) continue;
        // iterative Tarjan
        try work.append(gpa, .{ .v = root, .it = 0 });
        while (work.items.len > 0) {
            const st = work.items[work.items.len - 1];
            const v = st.v;
            if (st.it == 0) {
                index[v] = counter;
                low[v] = counter;
                counter += 1;
                try stack.append(gpa, v);
                onstack[v] = true;
            }
            const vi: usize = @intCast(v);
            const s0 = succ_start.items[vi];
            const s1 = succ_start.items[vi + 1];
            var advanced = false;
            var it = st.it;
            while (s0 + it < s1) : (it += 1) {
                const w = succ.items[@intCast(s0 + it)];
                if (index[w] == std.math.maxInt(u64)) {
                    work.items[work.items.len - 1].it = it + 1;
                    try work.append(gpa, .{ .v = w, .it = 0 });
                    advanced = true;
                    break;
                } else if (onstack[w]) {
                    if (index[w] < low[v]) low[v] = index[w];
                }
            }
            if (advanced) continue;
            // all successors processed
            if (low[v] == index[v]) {
                var sz: u64 = 0;
                while (true) {
                    const w = stack.items[stack.items.len - 1];
                    _ = stack.pop();
                    onstack[w] = false;
                    comp[w] = n_comp;
                    sz += 1;
                    if (w == v) break;
                }
                try comp_size.append(gpa, sz);
                n_comp += 1;
            }
            _ = work.pop();
            if (work.items.len > 0) {
                const p = work.items[work.items.len - 1].v;
                if (low[v] < low[p]) low[p] = low[v];
            }
        }
    }
    std.debug.print("SCC3: n_comp={d}\n", .{n_comp});
    // nontrivial comps (size > 1) and L<H correlation
    var nontriv = try gpa.alloc(bool, @intCast(n_comp));
    defer gpa.free(nontriv);
    for (0..n_comp) |c| nontriv[c] = comp_size.items[@intCast(c)] > 1;
    var in_nontriv_set: u64 = 0;
    var lh_set_in_nontriv: u64 = 0;
    var lh_set_not_in_nontriv: u64 = 0;
    for (0..n_ids) |id| {
        const e = by_key.get(id_of.get(id).?).?;
        if (e.L != e.H) {
            if (nontriv[@intCast(comp[id])]) lh_set_in_nontriv += 1 else lh_set_not_in_nontriv += 1;
        }
        if (nontriv[@intCast(comp[id])]) in_nontriv_set += 1;
    }
    std.debug.print("SCC3: L<H entries in non-trivial SCCs={d}; L<H entries NOT in non-trivial SCCs={d}; entries in non-trivial SCCs={d}\n", .{
        lh_set_in_nontriv, lh_set_not_in_nontriv, in_nontriv_set,
    });
}
