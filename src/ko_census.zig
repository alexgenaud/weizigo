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
// ko_census — B23: count independent ko points on ko-sensitive positions.
//
// Loads a WZO1 artifact; for every ko-sensitive position (L<H, fresh-start),
// analyzes the board to count how many independent ko clusters exist.
// Outputs a table:
//
//   board   total-legal   ko-sens    0-ko    1-ko    2-ko    3-ko    4-ko+
//   3x3     12,675        8,698      ...     ...     ...     ...     ...
//   4x4     24,318,165    5,183,961  ...     ...     ...     ...     ...
//
// A ko point is a cell where a stone of some colour captures exactly one
// opponent stone and the capturing stone has exactly one liberty (the vacated
// cell) — the basic ko shape. Two ko points are independent if they don't
// share cells or adjacent cells.
//
// Usage: zig run -O ReleaseFast src/ko_census.zig -- <artifact.wzo>

const std = @import("std");
const util = @import("util.zig");
const artifact = @import("artifact.zig");
const colex = @import("colex.zig");

const KO_SENSITIVE: u8 = 1;
const UNDEF: i8 = -128;

const KoPoint = struct { cell: u8, cap: u8 };

/// Detect whether placing `colour` at `p` is a basic ko capture.
/// Returns the captured stone's cell if so, null otherwise.
fn isKoCapture(comptime R: type, pos: *const R.Pos, p: usize, colour: i8) ?usize {
    if (pos[p] != 0) return null;
    const next = R.pos_from_move(pos, colour, p) catch return null;

    // Count opponent stones before vs after: exactly 1 captured
    var opp_before: u8 = 0;
    var opp_after: u8 = 0;
    var captured_cell: ?usize = null;
    for (0..R.n) |i| {
        if (pos[i] == -colour) opp_before += 1;
        if (next[i] == -colour) opp_after += 1;
        if (pos[i] == -colour and next[i] == 0) captured_cell = i;
    }
    if (opp_before - opp_after != 1) return null;

    // Placed stone must have exactly 1 liberty
    var liberties: u8 = 0;
    var nb: [4]usize = undefined;
    const cnt = R.neighbors(p, &nb);
    for (nb[0..cnt]) |q| {
        if (next[q] == 0) liberties += 1;
    }
    if (liberties != 1) return null;

    return captured_cell;
}

/// Build a list of all ko points on the board.
/// Each ko point is (cell, captured_cell).
fn findAllKoPoints(comptime R: type, pos: *const R.Pos, list: *std.ArrayListUnmanaged(KoPoint), gpa: std.mem.Allocator) !void {
    for (0..R.n) |p| {
        inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
            if (isKoCapture(R, pos, p, colour)) |cap| {
                try list.append(gpa, .{ .cell = @intCast(p), .cap = @intCast(cap) });
            }
        }
    }
}

/// Count independent ko clusters among ko_points using union-find.
/// Two ko points are dependent if their 1-neighborhoods intersect.
fn countIndependentClusters(comptime R: type, ko_points: []const KoPoint) u8 {
    if (ko_points.len == 0) return 0;

    // Precompute 1-neighborhood bitmask for each ko point
    var masks: [32]u32 = undefined; // max 2*16 = 32 for 4x4
    for (ko_points, 0..) |kp, i| {
        var mask: u32 = 0;
        // ko cell
        mask |= @as(u32, 1) << @as(u5, @intCast(kp.cell));
        // captured cell
        mask |= @as(u32, 1) << @as(u5, @intCast(kp.cap));
        // neighbors of ko cell
        var nb: [4]usize = undefined;
        const cnt = R.neighbors(kp.cell, &nb);
        for (nb[0..cnt]) |q| mask |= @as(u32, 1) << @as(u5, @intCast(q));
        // neighbors of captured cell
        const cnt2 = R.neighbors(kp.cap, &nb);
        for (nb[0..cnt2]) |q| mask |= @as(u32, 1) << @as(u5, @intCast(q));
        masks[i] = mask;
    }

    // Union-find (path compression)
    var parent: [32]u8 = undefined;
    for (0..ko_points.len) |i| parent[i] = @intCast(i);

    for (0..ko_points.len) |i| {
        for (i + 1..ko_points.len) |j| {
            if (masks[i] & masks[j] != 0) {
                // find root for i
                var ri: u8 = @intCast(i);
                while (parent[ri] != ri) {
                    parent[ri] = parent[parent[ri]];
                    ri = parent[ri];
                }
                // find root for j
                var rj: u8 = @intCast(j);
                while (parent[rj] != rj) {
                    parent[rj] = parent[parent[rj]];
                    rj = parent[rj];
                }
                if (ri != rj) parent[ri] = rj;
            }
        }
    }

    // Count distinct roots
    var roots: u32 = 0;
    for (0..ko_points.len) |i| {
        var r: u8 = @intCast(i);
        while (parent[r] != r) {
            parent[r] = parent[parent[r]];
            r = parent[r];
        }
        roots |= @as(u32, 1) << @as(u5, @intCast(r));
    }
    return @popCount(roots);
}

fn census(comptime w: comptime_int, comptime h: comptime_int, d: *const artifact.Decoded, gpa: std.mem.Allocator) !void {
    const R = @import("rules.zig").Rules(w, h);
    const X = colex.Indexer(w, h);

    // Ensure the position count fits in u8/u32 (our bitmask uses u32)
    if (R.n > 32) @compileError("ko_census: board too large for u32 bitmask");

    const t: usize = @intCast(d.header.total);

    var counts = [_]u64{0} ** 5; // 0-ko, 1-ko, 2-ko, 3-ko, 4-ko+
    var total_legal: u64 = 0;
    var total_ko_sens: u64 = 0;

    var ko_points = try std.ArrayListUnmanaged(KoPoint).initCapacity(gpa, 32);
    defer ko_points.deinit(gpa);

    var last_pct: u64 = 0;
    // Cache the ko-point analysis per unique board (lazily computed)
    var board_done = try std.DynamicBitSetUnmanaged.initEmpty(gpa, t);
    defer board_done.deinit(gpa);
    var board_n_ko = try gpa.alloc(u8, t);
    defer gpa.free(board_n_ko);
    // sentinel: 255 = not yet computed
    @memset(board_n_ko, 255);

    for (0..t) |idx| {
        if (d.vb[idx] == UNDEF) continue;
        total_legal += 2; // count both B and W side-position pairs

        const b_ko = (d.fb[idx] & KO_SENSITIVE) != 0;
        const w_ko = (d.fw[idx] & KO_SENSITIVE) != 0;
        if (!b_ko and !w_ko) continue;

        // Progress reporting (every 5%)
        if (total_legal > 0) {
            const pct = total_legal * 100 / (2 * d.header.legal_count);
            if (pct >= last_pct + 5) {
                last_pct = pct;
                util.out("  progress: {d}% legal scanned, {d} ko-sens found\n", .{ pct, total_ko_sens });
            }
        }

        // Compute ko-point count for this board (once)
        const nko: u8 = if (board_n_ko[idx] != 255) board_n_ko[idx] else blk: {
            const pos = X.pos_from_colex(idx);
            ko_points.clearRetainingCapacity();
            try findAllKoPoints(R, &pos, &ko_points, gpa);
            const n = countIndependentClusters(R, ko_points.items);
            board_n_ko[idx] = n;
            break :blk n;
        };

        // Count per side
        if (b_ko) {
            total_ko_sens += 1;
            if (nko < 4) counts[nko] += 1 else counts[4] += 1;
        }
        if (w_ko) {
            total_ko_sens += 1;
            if (nko < 4) counts[nko] += 1 else counts[4] += 1;
        }
    }

    util.out("\n{d}x{d}:\n", .{ w, h });
    util.out("  total-legal: {d:>12}\n", .{total_legal});
    util.out("  ko-sens:     {d:>12}\n", .{total_ko_sens});
    util.out("  0-ko:        {d:>12}  ({d:.1}%)\n", .{ counts[0], asPct(counts[0], total_ko_sens) });
    util.out("  1-ko:        {d:>12}  ({d:.1}%)\n", .{ counts[1], asPct(counts[1], total_ko_sens) });
    util.out("  2-ko:        {d:>12}  ({d:.1}%)\n", .{ counts[2], asPct(counts[2], total_ko_sens) });
    util.out("  3-ko:        {d:>12}  ({d:.1}%)\n", .{ counts[3], asPct(counts[3], total_ko_sens) });
    util.out("  4-ko+:       {d:>12}  ({d:.1}%)\n", .{ counts[4], asPct(counts[4], total_ko_sens) });

    // Verify sum
    const sum = counts[0] + counts[1] + counts[2] + counts[3] + counts[4];
    util.out("  sum check:   {d:>12}  (want {d})\n", .{ sum, total_ko_sens });
}

fn asPct(part: u64, total: u64) f64 {
    if (total == 0) return 0.0;
    return @as(f64, @floatFromInt(part)) * 100.0 / @as(f64, @floatFromInt(total));
}

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;

    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next(); // skip program name
    const path = args.next() orelse {
        util.out("usage: ko_census <artifact.wzo>\n", .{});
        util.out("  e.g.: zig run -O ReleaseFast src/ko_census.zig -- artifacts/oracle-3x3.wzo\n", .{});
        return;
    };

    var decoded = try artifact.load(init.io, std.Io.Dir.cwd(), path, gpa);
    defer decoded.deinit();

    const w = decoded.header.board_w;
    const h = decoded.header.board_h;

    util.out("ko_census: {d}x{d}  total slots={d}  legal_count={d}\n\n", .{
        w, h, decoded.header.total, decoded.header.legal_count,
    });

    if (w == 3 and h == 3) {
        try census(3, 3, &decoded, gpa);
    } else if (w == 4 and h == 4) {
        try census(4, 4, &decoded, gpa);
    } else {
        util.out("unsupported board size {d}x{d}\n", .{ w, h });
    }
}
