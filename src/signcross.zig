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
// signcross — B29: how often does [L,H] cross zero in ko-sensitive region?
//
// Loads a bracket WZO1 artifact (6 columns: L,H in vb,vw positions).
// For every ko-sensitive (position, side) where L≠H, measures:
//   - same-sign:  sign(L) == sign(H)  (bracket doesn't cross zero)
//   - cross-zero: sign(L) != sign(H)  (bracket crosses zero)
// Also reports bracket-width distribution.
//
// Usage: zig run -O ReleaseFast src/signcross.zig -- <bracket.wzo>

const std = @import("std");
const artifact = @import("artifact.zig");

const KO_SENSITIVE: u8 = 1;
const UNDEF: i8 = -128;

const WidthBucket = enum { w0, w1_2, w3_5, w6_10, w11_20, w21_50, w51_plus, count };

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;

    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    const path = args.next() orelse {
        std.debug.print("usage: signcross <bracket.wzo>\n", .{});
        return;
    };

    var decoded = try artifact.load(init.io, std.Io.Dir.cwd(), path, gpa);
    defer decoded.deinit();

    const w = decoded.header.board_w;
    const h = decoded.header.board_h;
    const t: usize = @intCast(decoded.header.total);

    std.debug.print("signcross: {d}x{d}  total slots={d}  legal_count={d}\n\n", .{
        w, h, t, decoded.header.legal_count,
    });

    // ── counts ──
    var total_legal: u64 = 0;
    var total_ko_sens: u64 = 0; // L ≠ H
    var same_sign: u64 = 0; // L,H same sign (all-winning or all-losing)
    var cross_zero: u64 = 0; // L,H opposite signs
    var zero_bracket: u64 = 0; // L == 0 or H == 0 (edge case)

    // bracket-width distribution (for same-sign and cross-zero separately)
    var width_same: [@typeInfo(WidthBucket).@"enum".fields.len]u64 = .{0} ** @typeInfo(WidthBucket).@"enum".fields.len;
    var width_cross: [@typeInfo(WidthBucket).@"enum".fields.len]u64 = .{0} ** @typeInfo(WidthBucket).@"enum".fields.len;

    var last_pct: u64 = 0;

    for (0..t) |idx| {
        if (decoded.vb[idx] == UNDEF) continue;
        total_legal += 2; // count both B and W

        const b_ko = (decoded.fb[idx] & KO_SENSITIVE) != 0;
        const w_ko = (decoded.fw[idx] & KO_SENSITIVE) != 0;

        // Progress (every 5%)
        if (total_legal > 0) {
            const prog = total_legal * 100 / (2 * decoded.header.legal_count);
            if (prog >= last_pct + 5) {
                last_pct = prog;
                std.debug.print("  progress: {d}%  ko-sens={d}  same-sign={d}  cross-zero={d}\n", .{ prog, total_ko_sens, same_sign, cross_zero });
            }
        }

        // Analyze Black to move
        if (b_ko) {
            total_ko_sens += 1;
            const lo = decoded.vb[idx];
            const hi = decoded.vw[idx];
            try analyzeBracket(w, h, lo, hi, &same_sign, &cross_zero, &zero_bracket, &width_same, &width_cross);
        }

        // Analyze White to move: color inversion
        if (w_ko) {
            total_ko_sens += 1;
            const lo: i16 = -decoded.vw[idx];
            const hi: i16 = -decoded.vb[idx];
            try analyzeBracket(w, h, lo, hi, &same_sign, &cross_zero, &zero_bracket, &width_same, &width_cross);
        }
    }

    // ── output ──
    std.debug.print("\n{d}x{d} ko-sensitive bracket analysis:\n\n", .{ w, h });
    std.debug.print("  total legal (position,side) pairs: {d:>12}\n", .{total_legal});
    std.debug.print("  total ko-sensitive (L≠H):        {d:>12}\n\n", .{total_ko_sens});

    std.debug.print("  same-sign (all-winning or all-losing):\n", .{});
    std.debug.print("    count:   {d:>10}  ({d:.1}% of ko-sens)\n", .{ same_sign, pct(same_sign, total_ko_sens) });
    std.debug.print("  cross-zero (outcome depends on exact value):\n", .{});
    std.debug.print("    count:   {d:>10}  ({d:.1}% of ko-sens)\n", .{ cross_zero, pct(cross_zero, total_ko_sens) });
    if (zero_bracket > 0) {
        std.debug.print("  zero-edge (L=0 or H=0):                 {d:>10}\n", .{zero_bracket});
    }
    std.debug.print("\n", .{});

    // Width distribution
    std.debug.print("  bracket-width distribution:\n", .{});
    std.debug.print("       width       same-sign    cross-zero\n", .{});
    std.debug.print("  ----------  ------------  ------------\n", .{});
    inline for (@typeInfo(WidthBucket).@"enum".fields, 0..) |_, i| {
        if (i == @intFromEnum(WidthBucket.count)) break;
        const label: []const u8 = switch (@as(WidthBucket, @enumFromInt(i))) {
            .w0 => "0",
            .w1_2 => "1-2",
            .w3_5 => "3-5",
            .w6_10 => "6-10",
            .w11_20 => "11-20",
            .w21_50 => "21-50",
            .w51_plus => "51+",
            .count => unreachable,
        };
        std.debug.print("  {s:>10}  {d:>12}  {d:>12}\n", .{ label, width_same[i], width_cross[i] });
    }

    const sum_check = same_sign + cross_zero + zero_bracket;
    std.debug.print("\n  sum check: {d}  (want {d})\n", .{ sum_check, total_ko_sens });
}

fn analyzeBracket(
    w: usize,
    h: usize,
    lo: i16,
    hi: i16,
    same_sign: *u64,
    cross_zero: *u64,
    zero_bracket: *u64,
    width_same: *[8]u64,
    width_cross: *[8]u64,
) !void {
    _ = w;
    _ = h;

    const width: u16 = @intCast(@max(hi - lo, 0));

    if (lo == 0 or hi == 0) {
        zero_bracket.* += 1;
        return;
    }

    const lo_pos = lo > 0;
    const hi_pos = hi > 0;

    if (lo_pos == hi_pos) {
        // same sign
        same_sign.* += 1;
        width_same[bucket(width)] += 1;
    } else {
        // crosses zero
        cross_zero.* += 1;
        width_cross[bucket(width)] += 1;
    }
}

fn bucket(width: u16) usize {
    return if (width == 0) @intFromEnum(WidthBucket.w0)
        else if (width <= 2) @intFromEnum(WidthBucket.w1_2)
        else if (width <= 5) @intFromEnum(WidthBucket.w3_5)
        else if (width <= 10) @intFromEnum(WidthBucket.w6_10)
        else if (width <= 20) @intFromEnum(WidthBucket.w11_20)
        else if (width <= 50) @intFromEnum(WidthBucket.w21_50)
        else @intFromEnum(WidthBucket.w51_plus);
}

fn pct(part: u64, total: u64) f64 {
    if (total == 0) return 0.0;
    return @as(f64, @floatFromInt(part)) * 100.0 / @as(f64, @floatFromInt(total));
}
