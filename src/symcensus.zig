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
// T359 — symmetry-fold census (analysis only; no encoding/format change).
//
// Measures, for each goban (w x h), over the RAW address space (all 3^n
// colourings, legal AND illegal):
//
//   * orbit of every position under spatial symmetry group x colour inversion
//     (D4 x 2 = 16 on a square, D2 x 2 = 8 on a rectangle);
//   * orbit-size distribution;
//   * number of distinct orbits (= canonical set size) and measured fold
//     factor raw / canonical, against the predicted 16x / 8x;
//   * how many positions are fixed by >= 1 non-identity group element;
//   * anomalies: orbits of size 1 or 2 (named);
//   * Q2: distribution of orbit-minimum colex ranks across the colex range,
//     and whether truncating the table at 6.25/12.5/25/50% is lossless.
//
// Reuses symmetry permutations + legality test from src/enumerate.zig and the
// layered colex address from src/colex.zig.  Standalone: std only plus those
// two std-only modules.
//
// Run:  tools/runner -- zig run -O ReleaseFast src/symcensus.zig

const std = @import("std");
const enumerate = @import("enumerate.zig");
const colexmod = @import("colex.zig");

const GroupEl = struct { s: usize, flip: i8 };

fn posToString(comptime n: usize, pos: *const [n]i8, buf: []u8, w: usize, h: usize) []u8 {
    var k: usize = 0;
    for (0..h) |r| {
        for (0..w) |c| {
            const v = pos[r * w + c];
            buf[k] = if (v > 0) 'B' else if (v < 0) 'W' else '.';
            k += 1;
        }
        if (r + 1 < h) {
            buf[k] = '/';
            k += 1;
        }
    }
    return buf[0..k];
}

const OrbitInfo = struct {
    colex: u64,
    min_colex: u64,
    size: u32,
    is_rep: bool,
    fixed_nonid: bool,
};

/// Compute the orbit of `pos` under the group; return its info.
/// `R` is the colex Indexer(w,h) type.
fn orbitInfo(comptime n: usize, comptime num_syms: usize, comptime R: type, pos: *const [n]i8, perms: *const [num_syms][n]u8, els: *const [2 * num_syms]GroupEl) OrbitInfo {
    const self_colex = R.colex_from_pos(pos);
    var vals: [2 * num_syms]u64 = undefined;
    var tpos: [n]i8 = undefined;
    var min_colex: u64 = std.math.maxInt(u64);
    var fixed_nonid = false;
    for (els, 0..) |el, ei| {
        const perm = &perms[el.s];
        for (0..n) |i| tpos[i] = el.flip * pos[perm[i]];
        const c = R.colex_from_pos(&tpos);
        vals[ei] = c;
        if (c < min_colex) min_colex = c;
        const is_id = (el.s == 0 and el.flip == 1);
        if (!is_id and c == self_colex) fixed_nonid = true;
    }
    std.sort.block(u64, &vals, {}, std.sort.asc(u64));
    var cnt: u32 = 1;
    for (1..vals.len) |i| {
        if (vals[i] != vals[i - 1]) cnt += 1;
    }
    return .{
        .colex = self_colex,
        .min_colex = min_colex,
        .size = cnt,
        .is_rep = (self_colex == min_colex),
        .fixed_nonid = fixed_nonid,
    };
}

/// Lex-min canonical test: is `pos` the lexicographically-least member of its
/// orbit?  Independent of colex (raw array compare, -1 < 0 < 1).
fn isLexMin(comptime n: usize, comptime num_syms: usize, pos: *const [n]i8, perms: *const [num_syms][n]u8, els: *const [2 * num_syms]GroupEl) bool {
    for (els) |el| {
        const perm = &perms[el.s];
        var cmp: i8 = 0;
        for (0..n) |i| {
            const t = el.flip * pos[perm[i]];
            if (t < pos[i]) {
                cmp = -1;
                break;
            }
            if (t > pos[i]) {
                cmp = 1;
                break;
            }
        }
        if (cmp < 0) return false;
    }
    return true;
}

const Anomaly = struct { colex: u64, size: u32, k: usize, pos_str: []u8 };

const GobanReport = struct {
    w: usize,
    h: usize,
    n: usize,
    num_syms: usize,
    group_order: usize,
    raw: u64,
    legal: u64,
    orbits: u64,
    canonical_legal: u64,
    fold_raw: f64,
    fold_legal: f64,
    fold_combined: f64,
    orbit_size_dist: [33]u64,
    fixed_nonid_count: u64,
    thresh_fracs: [6]f64,
    thresh_counts: [6]u64,
    lost_orbits_top: u64,
    anomalies: std.ArrayListUnmanaged(Anomaly),
    brute_orbits: u64,
    perturb_orbits: u64,
    perturb_agree: bool,
    self_consistent: bool,
};

fn runGoban(comptime w: usize, comptime h: usize, alloc: std.mem.Allocator) !GobanReport {
    const E = enumerate.Enumerator(w, h);
    const R = colexmod.Indexer(w, h);
    const perms_base = E.sym_perms;
    var perms_mut: [E.num_syms][E.n]u8 = perms_base;

    var els: [2 * E.num_syms]GroupEl = undefined;
    {
        var idx: usize = 0;
        for (0..E.num_syms) |s| {
            els[idx] = .{ .s = s, .flip = 1 };
            idx += 1;
            els[idx] = .{ .s = s, .flip = -1 };
            idx += 1;
        }
    }

    var rep: GobanReport = .{
        .w = w,
        .h = h,
        .n = E.n,
        .num_syms = E.num_syms,
        .group_order = 2 * E.num_syms,
        .raw = R.total,
        .legal = 0,
        .orbits = 0,
        .canonical_legal = 0,
        .fold_raw = 0,
        .fold_legal = 0,
        .fold_combined = 0,
        .orbit_size_dist = [_]u64{0} ** 33,
        .fixed_nonid_count = 0,
        .thresh_fracs = .{ 0.0625, 0.125, 0.25, 0.50, 0.75, 1.00 },
        .thresh_counts = [_]u64{0} ** 6,
        .lost_orbits_top = 0,
        .anomalies = .empty,
        .brute_orbits = 0,
        .perturb_orbits = 0,
        .perturb_agree = false,
        .self_consistent = false,
    };

    const total = R.total;
    var thresholds: [6]u64 = undefined;
    for (rep.thresh_fracs, 0..) |f, i| {
        thresholds[i] = @as(u64, @intFromFloat(@as(f64, @floatFromInt(total)) * f));
    }

    var digits = [_]u8{0} ** E.n;
    var pos: E.Pos = [_]i8{0} ** E.n;
    var stones: usize = 0;
    var progress: u64 = 0;
    const show_progress = (E.n >= 16);

    while (true) {
        const oi = orbitInfo(E.n, E.num_syms, R, &pos, &perms_mut, &els);
        const is_legal = E.is_legal(&pos);
        if (is_legal) rep.legal += 1;
        if (oi.fixed_nonid) rep.fixed_nonid_count += 1;

        if (oi.is_rep) {
            rep.orbits += 1;
            if (oi.size < rep.orbit_size_dist.len) {
                rep.orbit_size_dist[oi.size] += 1;
            }
            if (is_legal) rep.canonical_legal += 1;
            for (thresholds, 0..) |th, i| {
                if (oi.min_colex < th) rep.thresh_counts[i] += 1;
            }
            if (oi.min_colex >= thresholds[3]) rep.lost_orbits_top += 1;
            if (oi.size <= 2 and rep.anomalies.items.len < 256) {
                var buf: [128]u8 = undefined;
                const s = posToString(E.n, &pos, &buf, w, h);
                try rep.anomalies.append(alloc, .{
                    .colex = oi.min_colex,
                    .size = oi.size,
                    .k = stones,
                    .pos_str = try alloc.dupe(u8, s),
                });
            }
        }

        if (isLexMin(E.n, E.num_syms, &pos, &perms_mut, &els)) rep.brute_orbits += 1;

        progress += 1;
        if (show_progress and progress % 5_000_000 == 0) {
            std.debug.print("  {d}x{d}: {d}/{d} ({d:.1}%)\n", .{ w, h, progress, total, 100.0 * @as(f64, @floatFromInt(progress)) / @as(f64, @floatFromInt(total)) });
        }

        var i: usize = 0;
        while (i < E.n) : (i += 1) {
            if (digits[i] == 2) {
                digits[i] = 0;
                pos[i] = 0;
                stones -= 1;
                continue;
            }
            digits[i] += 1;
            if (digits[i] == 1) {
                pos[i] = 1;
                stones += 1;
            } else {
                pos[i] = -1;
            }
            break;
        }
        if (i == E.n) break;
    }

    rep.fold_raw = @as(f64, @floatFromInt(rep.raw)) / @as(f64, @floatFromInt(rep.orbits));
    rep.fold_legal = if (rep.canonical_legal > 0)
        @as(f64, @floatFromInt(rep.legal)) / @as(f64, @floatFromInt(rep.canonical_legal))
    else
        0;
    rep.fold_combined = if (rep.canonical_legal > 0)
        @as(f64, @floatFromInt(rep.raw)) / @as(f64, @floatFromInt(rep.canonical_legal))
    else
        0;

    var chk: u64 = 0;
    for (rep.orbit_size_dist, 0..) |c, sz| chk += @as(u64, sz) * c;
    rep.self_consistent = (chk == rep.raw);

    // seeded control: perturb the rot90 permutation (square only) and recount.
    if (E.num_syms >= 6) {
        var pperms: [E.num_syms][E.n]u8 = perms_base;
        const t = pperms[5][0];
        pperms[5][0] = pperms[5][1];
        pperms[5][1] = t;
        @memset(&digits, 0);
        @memset(&pos, 0);
        stones = 0;
        while (true) {
            const oi = orbitInfo(E.n, E.num_syms, R, &pos, &pperms, &els);
            if (oi.is_rep) rep.perturb_orbits += 1;
            var i: usize = 0;
            while (i < E.n) : (i += 1) {
                if (digits[i] == 2) {
                    digits[i] = 0;
                    pos[i] = 0;
                    stones -= 1;
                    continue;
                }
                digits[i] += 1;
                if (digits[i] == 1) {
                    pos[i] = 1;
                    stones += 1;
                } else {
                    pos[i] = -1;
                }
                break;
            }
            if (i == E.n) break;
        }
        rep.perturb_agree = (rep.perturb_orbits == rep.orbits);
    }

    return rep;
}

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    std.debug.print("weizigo symmetry-fold census (T359; analysis only)\n", .{});
    std.debug.print("run with -O ReleaseFast\n\n", .{});

    const sizes = [_]struct { w: usize, h: usize }{
        .{ .w = 2, .h = 2 },
        .{ .w = 3, .h = 2 },
        .{ .w = 3, .h = 3 },
        .{ .w = 4, .h = 3 },
        .{ .w = 4, .h = 4 },
    };

    var reports: std.ArrayListUnmanaged(GobanReport) = .empty;
    defer {
        for (reports.items) |*r| {
            for (r.anomalies.items) |a| alloc.free(a.pos_str);
            r.anomalies.deinit(alloc);
        }
        reports.deinit(alloc);
    }

    inline for (sizes) |sz| {
        std.debug.print("==== {d}x{d} ====\n", .{ sz.w, sz.h });
        const r = try runGoban(sz.w, sz.h, alloc);
        try reports.append(alloc, r);
        printReport(&r);
    }

    std.debug.print("\n==== SUMMARY ====\n", .{});
    std.debug.print("goban  grp  raw           legal          orbits(raw)   fold_raw  canon_legal  fold_legal  fold_comb\n", .{});
    for (reports.items) |r| {
        std.debug.print("{d}x{d:<2} {d:>4} {d:>13} {d:>13} {d:>13}  {d:>6.2}  {d:>11}  {d:>8.2}  {d:>7.2}\n", .{
            r.w, r.h, r.group_order, r.raw, r.legal, r.orbits, r.fold_raw, r.canonical_legal, r.fold_legal, r.fold_combined,
        });
    }

    std.debug.print("\n==== NULL CONTROL (colex-min vs lex-min orbit count) ====\n", .{});
    for (reports.items) |r| {
        const agree = if (r.brute_orbits == r.orbits) "AGREE" else "DISAGREE";
        std.debug.print("{d}x{d}: colex-min orbits={d}  lex-min orbits={d}  {s}\n", .{ r.w, r.h, r.orbits, r.brute_orbits, agree });
    }

    std.debug.print("\n==== SEEDED CONTROL (perturbed rot90 permutation) ====\n", .{});
    for (reports.items) |r| {
        if (r.perturb_orbits > 0 or r.num_syms >= 6) {
            const detected = if (!r.perturb_agree) "DETECTED" else "NOT-DETECTED";
            std.debug.print("{d}x{d}: correct orbits={d}  perturbed orbits={d}  {s}\n", .{ r.w, r.h, r.orbits, r.perturb_orbits, detected });
        } else {
            std.debug.print("{d}x{d}: rectangle (no rot90 to perturb) — n/a\n", .{ r.w, r.h });
        }
    }

    std.debug.print("\n==== Q2: orbit-min colex distribution (cumulative % of orbits below threshold) ====\n", .{});
    std.debug.print("goban   6.25%    12.5%    25%      50%      75%      100%\n", .{});
    for (reports.items) |r| {
        std.debug.print("{d}x{d:<2} ", .{ r.w, r.h });
        for (r.thresh_counts, 0..) |c, i| {
            const pct = 100.0 * @as(f64, @floatFromInt(c)) / @as(f64, @floatFromInt(r.orbits));
            std.debug.print("{d:>6.1}% ", .{pct});
            _ = i;
        }
        std.debug.print("\n", .{});
    }

    std.debug.print("\n==== Q2: truncation loss at 50% (orbits with min_colex >= 50%) ====\n", .{});
    for (reports.items) |r| {
        const pct = 100.0 * @as(f64, @floatFromInt(r.lost_orbits_top)) / @as(f64, @floatFromInt(r.orbits));
        std.debug.print("{d}x{d}: lost {d} orbits ({d:.1}% of canonical set) by truncating at 50%\n", .{ r.w, r.h, r.lost_orbits_top, pct });
    }

    std.debug.print("\n==== ANOMALIES (orbits of size 1 or 2; up to 256 listed) ====\n", .{});
    for (reports.items) |r| {
        std.debug.print("{d}x{d}: {d} anomaly orbits\n", .{ r.w, r.h, r.anomalies.items.len });
        for (r.anomalies.items) |a| {
            std.debug.print("  size={d} k={d} colex={d} pos={s}\n", .{ a.size, a.k, a.colex, a.pos_str });
        }
    }
}

fn printReport(r: *const GobanReport) void {
    std.debug.print("raw (3^n)         = {d}\n", .{r.raw});
    std.debug.print("legal             = {d}\n", .{r.legal});
    std.debug.print("orbits (raw)      = {d}\n", .{r.orbits});
    std.debug.print("canonical-legal   = {d}\n", .{r.canonical_legal});
    std.debug.print("fold raw/canon    = {d:.3}\n", .{r.fold_raw});
    std.debug.print("fold legal/canon  = {d:.3}\n", .{r.fold_legal});
    std.debug.print("fold raw/canon-leg= {d:.3}\n", .{r.fold_combined});
    std.debug.print("group order       = {d}\n", .{r.group_order});
    std.debug.print("fixed by >=1 non-id (raw positions): {d}\n", .{r.fixed_nonid_count});
    std.debug.print("orbit-size dist (size: count):\n", .{});
    for (r.orbit_size_dist, 0..) |c, sz| {
        if (c != 0) std.debug.print("  size={d}: {d}\n", .{ sz, c });
    }
    std.debug.print("self-consistency sum(size*count) = {s} ({s} raw)\n", .{
        if (r.self_consistent) "matches" else "MISMATCH",
        if (r.self_consistent) "==" else "!=",
    });
}