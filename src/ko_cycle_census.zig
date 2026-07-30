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
// ko_cycle_census — T117: dynamic single-ko vs multi-ko classification.
//
// The static ko_census (B23) counts basic-ko SHAPES on ko-sensitive positions
// but doesn't trace actual CYCLES. A position can have 0 static ko shapes
// yet still have a single-ko cycle (ko created during play). This tool does
// bounded PSK forward search to find actual cycles and classify them by
// ko-point count.
//
// Classification:
//   single-ko    — all cycles found have ≤1 independent ko cluster
//   multi-ko     — at least one cycle found with ≥2 independent ko clusters
//   non-ko-cycle — all cycles have 0 static ko points (L<H from capture races)
//   budget-exh   — no cycles found within node/depth budget
//   no-cycle     — search space exhausted without finding a cycle
//
// Usage: zig run -O ReleaseFast src/ko_cycle_census.zig -- <artifact.wzo> [opts]
//   --sample N        sample N positions per static-ko category (default 2000)
//   --seed S          random seed (default 20260730)
//   --max-depth D     DFS depth cap (default 16)
//   --max-nodes N     node cap per position (default 10000)
//   --categories 0,1,2  which static-ko categories to sample (default all)

const std = @import("std");
const util = @import("util.zig");
const artifact = @import("artifact.zig");
const colex = @import("colex.zig");

const KO_SENSITIVE: u8 = 1;
const UNDEF: i8 = -128;

const KoPoint = struct { cell: u8, cap: u8 };

// ---- ko detection (same as ko_census.zig) ----------------------------------

fn isKoCapture(comptime R: type, pos: *const R.Pos, p: usize, colour: i8) ?usize {
    if (pos[p] != 0) return null;
    const next = R.pos_from_move(pos, colour, p) catch return null;
    // Must capture exactly one opponent stone
    var opp_before: u8 = 0;
    var opp_after: u8 = 0;
    var captured_cell: ?usize = null;
    for (0..R.n) |i| {
        if (pos[i] == -colour) opp_before += 1;
        if (next[i] == -colour) opp_after += 1;
        if (pos[i] == -colour and next[i] == 0) captured_cell = i;
    }
    if (opp_before - opp_after != 1) return null;
    if (captured_cell == null) return null;
    // Capturing stone must have exactly 1 liberty
    var liberties: u8 = 0;
    var nb: [4]usize = undefined;
    const cnt = R.neighbors(p, &nb);
    for (nb[0..cnt]) |q| {
        if (next[q] == 0) liberties += 1;
    }
    if (liberties != 1) return null;
    return captured_cell;
}

fn findAllKoPoints(comptime R: type, pos: *const R.Pos, list: *std.ArrayListUnmanaged(KoPoint), gpa: std.mem.Allocator) !void {
    for (0..R.n) |p| {
        for ([_]i8{ 1, -1 }) |colour| {
            if (isKoCapture(R, pos, p, colour)) |cap| {
                try list.append(gpa, .{ .cell = @intCast(p), .cap = @intCast(cap) });
            }
        }
    }
}

fn countIndependentClusters(comptime R: type, ko_points: []const KoPoint) u8 {
    if (ko_points.len == 0) return 0;
    std.debug.assert(ko_points.len <= 32);
    var masks: [32]u32 = undefined;
    for (ko_points, 0..) |kp, i| {
        var mask: u32 = 0;
        mask |= @as(u32, 1) << @as(u5, @intCast(kp.cell));
        mask |= @as(u32, 1) << @as(u5, @intCast(kp.cap));
        var nb: [4]usize = undefined;
        const cnt = R.neighbors(kp.cell, &nb);
        for (nb[0..cnt]) |q| mask |= @as(u32, 1) << @as(u5, @intCast(q));
        const cnt2 = R.neighbors(kp.cap, &nb);
        for (nb[0..cnt2]) |q| mask |= @as(u32, 1) << @as(u5, @intCast(q));
        masks[i] = mask;
    }
    var parent: [32]u8 = undefined;
    for (0..ko_points.len) |i| parent[i] = @intCast(i);
    for (0..ko_points.len) |i| {
        for (i + 1..ko_points.len) |j| {
            if (masks[i] & masks[j] != 0) {
                var ri: u8 = @intCast(i);
                while (parent[ri] != ri) { parent[ri] = parent[parent[ri]]; ri = parent[ri]; }
                var rj: u8 = @intCast(j);
                while (parent[rj] != rj) { parent[rj] = parent[parent[rj]]; rj = parent[rj]; }
                if (ri != rj) parent[ri] = rj;
            }
        }
    }
    var roots: u32 = 0;
    for (0..ko_points.len) |i| {
        var r: u8 = @intCast(i);
        while (parent[r] != r) { parent[r] = parent[parent[r]]; r = parent[r]; }
        roots |= @as(u32, 1) << @as(u5, @intCast(r));
    }
    return @popCount(roots);
}

// ---- PSK forward search ----------------------------------------------------

const CycleClass = enum {
    single_ko,
    multi_ko,
    non_ko_cycle,
    budget_exh,
    no_cycle,
};

const SearchResult = struct {
    class: CycleClass,
    nodes_visited: u64,
    cycles_found: u64,
    max_clusters_seen: u8,
};

fn hashBoard(pos: anytype) u64 {
    var h: u64 = 14695981039346656037;
    for (pos) |cell| {
        h ^= @as(u8, @bitCast(cell));
        h *%= 1099511628211;
    }
    return h;
}

fn classifyPosition(
    comptime R: type,
    alloc: std.mem.Allocator,
    pos: *const R.Pos,
    side: i8,
    max_depth: usize,
    max_nodes: u64,
    ko_pts_buf: *std.ArrayListUnmanaged(KoPoint),
) !SearchResult {
    var result = SearchResult{
        .class = .no_cycle,
        .nodes_visited = 0,
        .cycles_found = 0,
        .max_clusters_seen = 0,
    };

    var hist_hashes: [128]u64 = undefined;
    hist_hashes[0] = hashBoard(pos);
    var hist_len: usize = 1;

    const StackFrame = struct { cell_idx: u8, pos: R.Pos, hash: u64 };
    var stack = try std.ArrayListUnmanaged(StackFrame).initCapacity(alloc, max_depth + 1);
    defer stack.deinit(alloc);

    try stack.append(alloc, .{ .cell_idx = 0, .pos = pos.*, .hash = hist_hashes[0] });
    result.nodes_visited = 1;

    var found_any_cycle: bool = false;
    var found_multi_ko: bool = false;
    var found_non_ko: bool = false;

    while (stack.items.len > 0 and result.nodes_visited < max_nodes) {
        var frame = &stack.items[stack.items.len - 1];
        const depth = stack.items.len;
        const cur_side: i8 = if (depth % 2 == 1) side else -side;

        // No eye-prune: need to explore captures to find ko cycles
        var found_move = false;
        while (frame.cell_idx < R.n and !found_move) : (frame.cell_idx += 1) {
            const c: usize = @intCast(frame.cell_idx);
            if (frame.pos[c] != 0) continue;
            const child_pos = R.pos_from_move(&frame.pos, cur_side, c) catch continue;
            const ch = hashBoard(&child_pos);

            var repeats: bool = false;
            for (hist_hashes[0..hist_len]) |past_h| {
                if (past_h == ch) { repeats = true; break; }
            }
            if (repeats) {
                result.cycles_found += 1;
                found_any_cycle = true;
                ko_pts_buf.clearRetainingCapacity();
                for (stack.items) |sf| {
                    try findAllKoPoints(R, &sf.pos, ko_pts_buf, alloc);
                }
                try findAllKoPoints(R, &child_pos, ko_pts_buf, alloc);
                const n_clusters = countIndependentClusters(R, ko_pts_buf.items);
                if (n_clusters > result.max_clusters_seen) result.max_clusters_seen = n_clusters;
                if (n_clusters >= 2) found_multi_ko = true;
                if (n_clusters == 0) found_non_ko = true;
                continue;
            }

            if (depth < max_depth) {
                try stack.append(alloc, .{ .cell_idx = 0, .pos = child_pos, .hash = ch });
                hist_hashes[hist_len] = ch;
                hist_len += 1;
                found_move = true;
                result.nodes_visited += 1;
            }
        }
        if (!found_move) {
            _ = stack.pop();
            if (hist_len > 0) hist_len -= 1;
        }
    }

    if (result.nodes_visited >= max_nodes and !found_any_cycle) {
        result.class = .budget_exh;
    } else if (!found_any_cycle) {
        result.class = .no_cycle;
    } else if (found_multi_ko) {
        result.class = .multi_ko;
    } else if (found_non_ko and result.max_clusters_seen == 0) {
        result.class = .non_ko_cycle;
    } else {
        result.class = .single_ko;
    }
    return result;
}

// ---- main census -----------------------------------------------------------

const CensusCounts = struct {
    total: u64 = 0,
    single_ko: u64 = 0,
    multi_ko: u64 = 0,
    non_ko_cycle: u64 = 0,
    budget_exh: u64 = 0,
    no_cycle: u64 = 0,
    nodes_visited: u64 = 0,
    cycles_found: u64 = 0,
};

fn asPct(part: u64, total: u64) f64 {
    if (total == 0) return 0.0;
    return @as(f64, @floatFromInt(part)) * 100.0 / @as(f64, @floatFromInt(total));
}

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;

    var sample_size: u64 = 2000;
    var seed: u64 = 20260730;
    var max_depth: usize = 16;
    var max_nodes: u64 = 10000;
    var categories: [4]bool = .{ true, true, true, true };
    var artifact_path: ?[]const u8 = null;

    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--sample")) {
            sample_size = try std.fmt.parseInt(u64, args.next() orelse "2000", 10);
        } else if (std.mem.eql(u8, arg, "--seed")) {
            seed = try std.fmt.parseInt(u64, args.next() orelse "20260730", 10);
        } else if (std.mem.eql(u8, arg, "--max-depth")) {
            max_depth = try std.fmt.parseInt(usize, args.next() orelse "16", 10);
        } else if (std.mem.eql(u8, arg, "--max-nodes")) {
            max_nodes = try std.fmt.parseInt(u64, args.next() orelse "10000", 10);
        } else if (std.mem.eql(u8, arg, "--categories")) {
            const cat_str = args.next() orelse "0,1,2";
            categories = .{ false, false, false, false };
            var it = std.mem.splitScalar(u8, cat_str, ',');
            while (it.next()) |c| {
                const cat = try std.fmt.parseInt(u8, std.mem.trim(u8, c, " "), 10);
                if (cat <= 3) categories[cat] = true;
            }
        } else if (artifact_path == null) {
            artifact_path = arg;
        }
    }

    const path = artifact_path orelse {
        util.out("usage: ko_cycle_census <artifact.wzo> [--sample N] [--seed S] [--max-depth D] [--max-nodes N] [--categories 0,1,2]\n", .{});
        return;
    };

    var decoded = try artifact.load(init.io, std.Io.Dir.cwd(), path, gpa);
    defer decoded.deinit();

    const w = decoded.header.board_w;
    const h = decoded.header.board_h;
    if (w != 4 or h != 4) {
        util.out("ko_cycle_census: only 4x4 supported, got {d}x{d}\n", .{ w, h });
        return;
    }

    const R = @import("rules.zig").Rules(4, 4);
    const X = colex.Indexer(4, 4);
    const t: usize = @intCast(decoded.header.total);

    util.out("ko_cycle_census: {d}x{d}  total_slots={d}  legal_count={d}\n", .{ w, h, decoded.header.total, decoded.header.legal_count });
    util.out("sample={d}  seed={d}  max_depth={d}  max_nodes={d}\n", .{ sample_size, seed, max_depth, max_nodes });
    util.out("categories: 0-ko={} 1-ko={} 2-ko={} 3-ko={}\n\n", .{ categories[0], categories[1], categories[2], categories[3] });

    // ---- Phase 1: reservoir sampling during scan ----
    var rng = std.Random.DefaultPrng.init(seed);
    const random = rng.random();

    const Reservoir = struct { seen: u64 = 0, slots: []u64 = &.{} };
    var reservoirs: [4]Reservoir = undefined;
    for (0..4) |c| {
        if (categories[c]) {
            reservoirs[c].slots = try gpa.alloc(u64, @intCast(sample_size));
            @memset(reservoirs[c].slots, 0);
        }
    }
    defer for (&reservoirs) |*r| if (r.slots.len > 0) gpa.free(r.slots);

    var total_legal: u64 = 0;
    var total_ko_sens_counts: [5]u64 = [_]u64{0} ** 5; // [0..3] = per cat, [4] = total
    var ko_pts = try std.ArrayListUnmanaged(KoPoint).initCapacity(gpa, 32);

    util.out("Phase 1: static census + reservoir sampling...\n", .{});
    var last_pct: u64 = 0;
    for (0..t) |idx| {
        if (decoded.vb[idx] == UNDEF) continue;
        total_legal += 2;
        const b_ko = (decoded.fb[idx] & KO_SENSITIVE) != 0;
        const w_ko = (decoded.fw[idx] & KO_SENSITIVE) != 0;
        if (!b_ko and !w_ko) continue;

        const pct = total_legal * 100 / (2 * decoded.header.legal_count);
        if (pct >= last_pct + 5) {
            last_pct = pct;
            util.out("  progress: {d}%\n", .{pct});
        }

        const pos = X.pos_from_colex(idx);
        ko_pts.clearRetainingCapacity();
        try findAllKoPoints(R, &pos, &ko_pts, gpa);
        const nko = countIndependentClusters(R, ko_pts.items);

        if (b_ko) {
            const cat = if (nko < 3) nko else 3;
            total_ko_sens_counts[cat] += 1;
            total_ko_sens_counts[4] += 1;
            if (categories[cat]) {
                const r = &reservoirs[cat];
                r.seen += 1;
                if (r.seen <= sample_size) {
                    r.slots[r.seen - 1] = @intCast(idx);
                } else {
                    const j = random.uintLessThan(u64, r.seen);
                    if (j < sample_size) r.slots[j] = @intCast(idx);
                }
            }
        }
        if (w_ko) {
            const cat = if (nko < 3) nko else 3;
            total_ko_sens_counts[cat] += 1;
            total_ko_sens_counts[4] += 1;
            if (categories[cat]) {
                const r = &reservoirs[cat];
                r.seen += 1;
                if (r.seen <= sample_size) {
                    r.slots[r.seen - 1] = @intCast(idx);
                } else {
                    const j = random.uintLessThan(u64, r.seen);
                    if (j < sample_size) r.slots[j] = @intCast(idx);
                }
            }
        }
    }

    util.out("\n  total-legal:   {d}\n", .{total_legal});
    util.out("  ko-sensitive:  {d}\n", .{total_ko_sens_counts[4]});
    for (0..4) |c| {
        util.out("  static {d}-ko:    {d}  ({d:.1}%)\n", .{ c, total_ko_sens_counts[c], asPct(total_ko_sens_counts[c], total_ko_sens_counts[4]) });
    }

    // ---- Phase 2: classify sampled positions ----
    util.out("\nPhase 2: dynamic cycle classification (PSK forward search)...\n", .{});

    for (0..4) |cat| {
        if (!categories[cat]) continue;
        const r = &reservoirs[cat];
        if (r.slots.len == 0) continue;

        const n_sample = @min(sample_size, r.seen);
        var counts = CensusCounts{};

        util.out("\n  --- static {d}-ko: pool={d}, sampled {d} ---\n", .{ cat, total_ko_sens_counts[cat], n_sample });

        // Shuffle reservoir
        var si: usize = n_sample;
        while (si > 1) {
            si -= 1;
            const jj = random.uintLessThan(usize, @intCast(si + 1));
            const tmp = r.slots[si];
            r.slots[si] = r.slots[jj];
            r.slots[jj] = tmp;
        }

        for (r.slots[0..n_sample], 0..) |idx, samp_i| {
            const pos2 = X.pos_from_colex(idx);
            for ([_]i8{ 1, -1 }) |side| {
                const flag = if (side > 0) decoded.fb[idx] else decoded.fw[idx];
                if ((flag & KO_SENSITIVE) == 0) continue;

                ko_pts.clearRetainingCapacity();
                const result = classifyPosition(R, gpa, &pos2, side, max_depth, max_nodes, &ko_pts) catch |err| {
                    util.warn("  error at idx={d} side={d}: {}\n", .{ idx, side, err });
                    continue;
                };

                counts.total += 1;
                counts.nodes_visited += result.nodes_visited;
                counts.cycles_found += result.cycles_found;
                switch (result.class) {
                    .single_ko => counts.single_ko += 1,
                    .multi_ko => counts.multi_ko += 1,
                    .non_ko_cycle => counts.non_ko_cycle += 1,
                    .budget_exh => counts.budget_exh += 1,
                    .no_cycle => counts.no_cycle += 1,
                }

                if (counts.total % 200 == 0) {
                    util.out("    [{d}/{d}] nodes_avg={d:.0} single={d} multi={d} nonko={d} budget={d} nocyc={d}\n", .{
                        samp_i + 1, n_sample,
                        @as(f64, @floatFromInt(counts.nodes_visited)) / @as(f64, @floatFromInt(@max(1, counts.total))),
                        counts.single_ko, counts.multi_ko, counts.non_ko_cycle, counts.budget_exh, counts.no_cycle,
                    });
                }
            }
        }

        // Report
        util.out("\n  Results for static {d}-ko (sampled {d} side-positions):\n", .{ cat, counts.total });
        util.out("    single-ko:     {d:>6}  ({d:.1}%)\n", .{ counts.single_ko, asPct(counts.single_ko, counts.total) });
        util.out("    multi-ko:      {d:>6}  ({d:.1}%)\n", .{ counts.multi_ko, asPct(counts.multi_ko, counts.total) });
        util.out("    non-ko-cycle:  {d:>6}  ({d:.1}%)\n", .{ counts.non_ko_cycle, asPct(counts.non_ko_cycle, counts.total) });
        util.out("    budget-exh:    {d:>6}  ({d:.1}%)\n", .{ counts.budget_exh, asPct(counts.budget_exh, counts.total) });
        util.out("    no-cycle:      {d:>6}  ({d:.1}%)\n", .{ counts.no_cycle, asPct(counts.no_cycle, counts.total) });
        util.out("    total:         {d}\n", .{counts.total});
        util.out("    avg nodes/pos: {d:.0}\n", .{@as(f64, @floatFromInt(counts.nodes_visited)) / @as(f64, @floatFromInt(@max(1, counts.total)))});
        util.out("    avg cycles/pos:{d:.1}\n", .{@as(f64, @floatFromInt(counts.cycles_found)) / @as(f64, @floatFromInt(@max(1, counts.total)))});
    }

    ko_pts.deinit(gpa);
}
