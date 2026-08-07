////////////////////////////////////////////
//                                        //
//    (c) 2026 Alexander E Genaud          //
//                                        //
//    Permission is granted hereby,       //
//    to copy, share, use, modify,        //
//        for purposes any,               //
//    for free or for money,               //
//    provided these notices multiply.    //
//                                        //
//    This work "as is" I provide,        //
//    no warranty express or implied,     //
//        for, no purpose fit,             //
//        'tis unmerchantable shit.        //
//    Liability for damages denied.       //
//                                        //
////////////////////////////////////////////
//
// T412_PREDICTORS — can a CHEAP position-structure feature separate the
// bracketed region (L < H) from the single-valued region (L == H) better
// than the already-tried features (canForceLife, SCC, ko-freeness)?
//
// Task: T412 · Role: worker · Model: glm-5.2 · Date: 2026-08-07
//
// For every fresh-start table entry (terminal=0, ko=NONE, passes=0) the
// label is (L < H).  We compute a battery of cheap features from the
// position's geometry only (no fixpoint, no attractor) and score each as
// a single-feature classifier by threshold sweep, reporting best-F1 with
// precision/recall and the base rate.  A negative result is a real
// result: the deliverable is the best predictor's precision/recall even
// when it is poor, so the next attempt does not retry the same feature.
//
// Sizes: 3x3 exhaustive (49,428 entries); 4x4 reservoir sample (default
// 200,000 of 48,505,262 fresh-start entries, seed stated).  2x2/3x2/4x3
// have no WZO2 artifact and are out of scope for this instrument (their
// L/H come from a generic fixpoint, not a committable table).
//
// Controls (mandatory before any reading counts):
//   N1 null  — shuffle the L<H labels across the sample and re-score the
//              best feature; its precision must collapse to the base rate
//              (a measurement that returns 1.0 on shuffled labels is the
//              failure mode this guards).
//   S1 seeded — a "planted" feature equals the true label for a random
//              10% subset and 0 otherwise; its precision at the selecting
//              threshold must be 1.0 and recall 0.1, exercising the
//              precision/recall path and proving a perfect predictor is
//              detectable.
//
// Reads ONLY.  Compiles standalone:
//   zig build-exe -O ReleaseFast --dep version -Mroot=src/t412_predictors.zig \
//     -Mversion=src/version.zig --cache-dir /tmp/weizigo/t412/cache \
//     --global-cache-dir /tmp/weizigo/t412/global --name weizigo-t412-pred \
//     -femit-bin=/tmp/weizigo/t412/t412-pred
//
// Usage: weizigo-t412-pred --size 3|4 [--wzo2 <p>] [--sample <N>]
//          [--seed <N>] [--json <p>] [--controls-only]

const std = @import("std");
const version = @import("version");
const rules = @import("rules.zig");
const artifact2 = @import("artifact2.zig");
const colex = @import("colex.zig");
const util = @import("util.zig");

// ═══════════════════════════════════════════════════════════════════════════
//  FRESH-START ENTRY ENUMERATION (all entries, not just bracketed)
// ═══════════════════════════════════════════════════════════════════════════

const Entry = struct {
    colex: u32,
    side: i8,
    L: i8,
    H: i8,
};

fn enumerateFreshStart(
    comptime w: comptime_int,
    comptime h: comptime_int,
    a2: *const artifact2.LoadedArtifact,
    gpa: std.mem.Allocator,
) ![]Entry {
    const KO_NONE: u8 = w * h;
    const G: usize = @intCast(a2.header.n_groups);
    const groups = a2.data[a2.group_base .. a2.group_base + G * artifact2.GROUP_HEADER_SIZE];

    var results: std.ArrayListUnmanaged(Entry) = .empty;
    var cum: u64 = 0;

    for (0..G) |g| {
        const colex_val = std.mem.readInt(u32, groups[g * artifact2.GROUP_HEADER_SIZE ..][0..4], .little);
        const count: usize = groups[g * artifact2.GROUP_HEADER_SIZE + 4];

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
            try results.append(gpa, .{
                .colex = colex_val,
                .side = artifact2.u1ToSide(decoded.side),
                .L = L,
                .H = H,
            });
        }
        cum += count;
    }

    return results.toOwnedSlice(gpa);
}

// ═══════════════════════════════════════════════════════════════════════════
//  FEATURES (position geometry only; side-aware: "side" = side to move)
// ═══════════════════════════════════════════════════════════════════════════

const Features = struct {
    stones: u8,
    stone_parity: u8,
    side_stones: u8,
    opp_stones: u8,
    n_chains_side: u8,
    n_chains_opp: u8,
    min_lib_side: u8, // 255 if no side chains
    min_lib_opp: u8, // 255 if no opp chains
    total_lib_side: u16,
    total_lib_opp: u16,
    in_atari_side: bool, // some side chain has exactly 1 liberty
    in_atari_opp: bool,
    mutual_atari: bool,
    shared_lib: u16, // empty cells adjacent to both a side & an opp stone
    empty_regions: u8,
    max_empty_region: u8,
    min_empty_region: u8, // 255 if no empty region
    eye_space_side: u8, // empty regions bordered ONLY by side stones
    eye_space_opp: u8,
    benson_alive_side: bool,
    benson_alive_opp: bool,
    empty_cells: u8,
    // a planted synthetic feature for the seeded control (0 by default;
    // main sets it for a random 10% subset when --seedctl planted is on)
    planted: u8,
};

fn computeFeatures(
    comptime w: comptime_int,
    comptime h: comptime_int,
    pos: *const [w * h]i8,
    side: i8,
    planted: u8,
) Features {
    const R = rules.Rules(w, h);
    const n = w * h;
    const opp: i8 = -side;

    var f = Features{
        .stones = 0,
        .stone_parity = 0,
        .side_stones = 0,
        .opp_stones = 0,
        .n_chains_side = 0,
        .n_chains_opp = 0,
        .min_lib_side = 255,
        .min_lib_opp = 255,
        .total_lib_side = 0,
        .total_lib_opp = 0,
        .in_atari_side = false,
        .in_atari_opp = false,
        .mutual_atari = false,
        .shared_lib = 0,
        .empty_regions = 0,
        .max_empty_region = 0,
        .min_empty_region = 255,
        .eye_space_side = 0,
        .eye_space_opp = 0,
        .benson_alive_side = false,
        .benson_alive_opp = false,
        .empty_cells = 0,
        .planted = planted,
    };

    // stone counts
    for (pos) |x| {
        if (x == 0) continue;
        f.stones += 1;
        if (x == side) f.side_stones += 1 else f.opp_stones += 1;
    }
    f.empty_cells = @intCast(n - @as(usize, f.stones));
    f.stone_parity = @intCast(@as(u8, @intCast(f.stones)) % 2);

    // chain + liberty analysis per colour via flood fill
    var visited = [_]bool{false} ** n;
    var chain_cells: [n]usize = undefined;
    var lib_seen = [_]bool{false} ** n;
    for (0..n) |seed| {
        if (pos[seed] == 0 or visited[seed]) continue;
        const colour = pos[seed];
        // flood the chain
        var sp: usize = 0;
        var head: usize = 0;
        chain_cells[head] = seed;
        head += 1;
        visited[seed] = true;
        while (head > sp) : (sp += 1) {
            const q = chain_cells[sp];
            var nb: [4]usize = undefined;
            const cnt = R.neighbors(q, &nb);
            for (nb[0..cnt]) |r| {
                if (pos[r] == colour and !visited[r]) {
                    visited[r] = true;
                    chain_cells[head] = r;
                    head += 1;
                }
            }
        }
        const chain_len = head; // chain occupies chain_cells[0..chain_len]
        // liberties: empty neighbours of any chain cell
        var libs: u16 = 0;
        for (chain_cells[0..chain_len]) |c| {
            var nb2: [4]usize = undefined;
            const cc = R.neighbors(c, &nb2);
            for (nb2[0..cc]) |r| {
                if (pos[r] == 0 and !lib_seen[r]) {
                    lib_seen[r] = true;
                    libs += 1;
                }
            }
        }
        // reset lib_seen for this chain (so the next chain recounts)
        for (chain_cells[0..chain_len]) |c| {
            var nb2: [4]usize = undefined;
            const cc = R.neighbors(c, &nb2);
            for (nb2[0..cc]) |r| {
                if (pos[r] == 0) lib_seen[r] = false;
            }
        }
        if (colour == side) {
            f.n_chains_side += 1;
            f.total_lib_side += libs;
            const lib_u8: u8 = @intCast(@min(libs, 255));
            if (lib_u8 < f.min_lib_side) f.min_lib_side = lib_u8;
            if (libs == 1) f.in_atari_side = true;
        } else {
            f.n_chains_opp += 1;
            f.total_lib_opp += libs;
            const lib_u8: u8 = @intCast(@min(libs, 255));
            if (lib_u8 < f.min_lib_opp) f.min_lib_opp = lib_u8;
            if (libs == 1) f.in_atari_opp = true;
        }
    }
    f.mutual_atari = f.in_atari_side and f.in_atari_opp;
    if (f.n_chains_side == 0) {} // min_lib_side stays 255
    if (f.n_chains_opp == 0) {}

    // shared liberties: empty cells adjacent to both a side stone and an
    // opp stone.
    for (0..n) |p| {
        if (pos[p] != 0) continue;
        var nb: [4]usize = undefined;
        const cnt = R.neighbors(p, &nb);
        var tb = false;
        var tw = false;
        for (nb[0..cnt]) |r| {
            if (pos[r] == side) tb = true else if (pos[r] == opp) tw = true;
        }
        if (tb and tw) f.shared_lib += 1;
    }

    // empty regions (flood over empty cells), track size and bordering
    // colours; an "eye_space_colour" region is bordered ONLY by that colour
    // (and the goban edge counts as that colour's for the eye test? — no:
    // use strict: every present neighbour is that colour; edge-neighbours
    // with no stone are fine, i.e. a region whose every STONE neighbour is
    // `colour`).
    var rvis = [_]bool{false} ** n;
    var region_stack: [n]usize = undefined;
    for (0..n) |p| {
        if (pos[p] != 0 or rvis[p]) continue;
        var sp: usize = 0;
        var head: usize = 0;
        region_stack[head] = p;
        head += 1;
        rvis[p] = true;
        var size: u32 = 1;
        var b_side = false;
        var b_opp = false;
        var b_none_at_border = false; // a non-empty neighbour check
        while (head > sp) : (sp += 1) {
            const q = region_stack[sp];
            var nb: [4]usize = undefined;
            const cnt = R.neighbors(q, &nb);
            for (nb[0..cnt]) |r| {
                if (pos[r] == 0) {
                    if (!rvis[r]) {
                        rvis[r] = true;
                        region_stack[head] = r;
                        head += 1;
                        size += 1;
                    }
                } else {
                    b_none_at_border = true;
                    if (pos[r] == side) b_side = true else b_opp = true;
                }
            }
        }
        f.empty_regions += 1;
        const su8: u8 = @intCast(@min(size, 255));
        if (su8 > f.max_empty_region) f.max_empty_region = su8;
        if (su8 < f.min_empty_region) f.min_empty_region = su8;
        if (b_none_at_border) {
            if (b_side and !b_opp) f.eye_space_side += 1;
            if (b_opp and !b_side) f.eye_space_opp += 1;
        }
    }
    if (f.empty_regions == 0) f.min_empty_region = 0;

    // Benson alive NOW (not canForceLife — this is "alive at this position")
    const balive = R.benson_alive(pos, side);
    const walive = R.benson_alive(pos, opp);
    var any_b = false;
    var any_w = false;
    for (0..n) |p| {
        if (balive[p]) any_b = true;
        if (walive[p]) any_w = true;
    }
    f.benson_alive_side = any_b;
    f.benson_alive_opp = any_w;

    return f;
}

// ═══════════════════════════════════════════════════════════════════════════
//  THRESHOLD SWEEP — single-feature classifier, best F1
// ═══════════════════════════════════════════════════════════════════════════

const PR = struct {
    tp: usize,
    fp: usize,
    fn_count: usize,
    tn: usize,
    precision: f64,
    recall: f64,
    f1: f64,
    threshold: i64, // the threshold value (in the feature's integer units)
    direction: u8, // 0 = predict L<H iff feature >= t ; 1 = iff feature <= t
};

fn prFrom(tp: usize, fp: usize, fn_: usize, tn: usize, threshold: i64, dir: u8) PR {
    const precision: f64 = if (tp + fp == 0) 0 else @as(f64, @floatFromInt(tp)) / @as(f64, @floatFromInt(tp + fp));
    const recall: f64 = if (tp + fn_ == 0) 0 else @as(f64, @floatFromInt(tp)) / @as(f64, @floatFromInt(tp + fn_));
    const f1: f64 = if (precision + recall == 0) 0 else 2 * precision * recall / (precision + recall);
    return .{ .tp = tp, .fp = fp, .fn_count = fn_, .tn = tn, .precision = precision, .recall = recall, .f1 = f1, .threshold = threshold, .direction = dir };
}

/// Best-F1 threshold sweep for a continuous (integer) feature given as a
/// precomputed slice of i64 values.
fn sweepInt(
    gpa: std.mem.Allocator,
    n: usize,
    labels: []const bool,
    vals: []const i64,
) !PR {
    const vs = try gpa.dupe(i64, vals);
    defer gpa.free(vs);
    std.mem.sort(i64, vs, {}, std.sort.asc(i64));
    var best = prFrom(0, 0, 0, 0, 0, 0);
    var prev: i64 = std.math.minInt(i64);
    for (vs) |v| {
        if (v == prev) continue;
        prev = v;
        var tp_ge: usize = 0;
        var fp_ge: usize = 0;
        var fn_ge: usize = 0;
        var tn_ge: usize = 0;
        var tp_le: usize = 0;
        var fp_le: usize = 0;
        var fn_le: usize = 0;
        var tn_le: usize = 0;
        for (0..n) |i| {
            const fv = vals[i];
            const lab = labels[i];
            if (fv >= v) {
                if (lab) tp_ge += 1 else fp_ge += 1;
            } else {
                if (lab) fn_ge += 1 else tn_ge += 1;
            }
            if (fv <= v) {
                if (lab) tp_le += 1 else fp_le += 1;
            } else {
                if (lab) fn_le += 1 else tn_le += 1;
            }
        }
        const r_ge = prFrom(tp_ge, fp_ge, fn_ge, tn_ge, v, 0);
        const r_le = prFrom(tp_le, fp_le, fn_le, tn_le, v, 1);
        if (r_ge.f1 > best.f1) best = r_ge;
        if (r_le.f1 > best.f1) best = r_le;
    }
    return best;
}

/// Boolean feature: predict L<H iff feature==true.
fn sweepBool(n: usize, labels: []const bool, vals: []const bool) PR {
    var tp: usize = 0;
    var fp: usize = 0;
    var fn_c: usize = 0;
    var tn: usize = 0;
    for (0..n) |i| {
        const lab = labels[i];
        if (vals[i]) {
            if (lab) tp += 1 else fp += 1;
        } else {
            if (lab) fn_c += 1 else tn += 1;
        }
    }
    return prFrom(tp, fp, fn_c, tn, 0, 0);
}

// ═══════════════════════════════════════════════════════════════════════════
//  DRIVER
// ═══════════════════════════════════════════════════════════════════════════

const Feat = struct {
    name: []const u8,
    kind: enum { int, bool },
    get_int: ?*const fn (f: Features) i64,
    get_bool: ?*const fn (f: Features) bool,
};

fn f_stones(f: Features) i64 { return f.stones; }
fn f_parity(f: Features) i64 { return f.stone_parity; }
fn f_side_stones(f: Features) i64 { return f.side_stones; }
fn f_opp_stones(f: Features) i64 { return f.opp_stones; }
fn f_nchains_side(f: Features) i64 { return f.n_chains_side; }
fn f_nchains_opp(f: Features) i64 { return f.n_chains_opp; }
fn f_minlib_side(f: Features) i64 { return f.min_lib_side; }
fn f_minlib_opp(f: Features) i64 { return f.min_lib_opp; }
fn f_totlib_side(f: Features) i64 { return f.total_lib_side; }
fn f_totlib_opp(f: Features) i64 { return f.total_lib_opp; }
fn f_shared_lib(f: Features) i64 { return f.shared_lib; }
fn f_empty_regions(f: Features) i64 { return f.empty_regions; }
fn f_max_empty(f: Features) i64 { return f.max_empty_region; }
fn f_min_empty(f: Features) i64 { return f.min_empty_region; }
fn f_eye_side(f: Features) i64 { return f.eye_space_side; }
fn f_eye_opp(f: Features) i64 { return f.eye_space_opp; }
fn f_empty_cells(f: Features) i64 { return f.empty_cells; }
fn f_planted(f: Features) i64 { return f.planted; }
fn fb_atari_side(f: Features) bool { return f.in_atari_side; }
fn fb_atari_opp(f: Features) bool { return f.in_atari_opp; }
fn fb_mutual_atari(f: Features) bool { return f.mutual_atari; }
fn fb_benson_side(f: Features) bool { return f.benson_alive_side; }
fn fb_benson_opp(f: Features) bool { return f.benson_alive_opp; }

const features = [_]Feat{
    .{ .name = "stones", .kind = .int, .get_int = f_stones, .get_bool = null },
    .{ .name = "stone_parity", .kind = .int, .get_int = f_parity, .get_bool = null },
    .{ .name = "side_stones", .kind = .int, .get_int = f_side_stones, .get_bool = null },
    .{ .name = "opp_stones", .kind = .int, .get_int = f_opp_stones, .get_bool = null },
    .{ .name = "n_chains_side", .kind = .int, .get_int = f_nchains_side, .get_bool = null },
    .{ .name = "n_chains_opp", .kind = .int, .get_int = f_nchains_opp, .get_bool = null },
    .{ .name = "min_lib_side", .kind = .int, .get_int = f_minlib_side, .get_bool = null },
    .{ .name = "min_lib_opp", .kind = .int, .get_int = f_minlib_opp, .get_bool = null },
    .{ .name = "total_lib_side", .kind = .int, .get_int = f_totlib_side, .get_bool = null },
    .{ .name = "total_lib_opp", .kind = .int, .get_int = f_totlib_opp, .get_bool = null },
    .{ .name = "shared_lib", .kind = .int, .get_int = f_shared_lib, .get_bool = null },
    .{ .name = "empty_regions", .kind = .int, .get_int = f_empty_regions, .get_bool = null },
    .{ .name = "max_empty_region", .kind = .int, .get_int = f_max_empty, .get_bool = null },
    .{ .name = "min_empty_region", .kind = .int, .get_int = f_min_empty, .get_bool = null },
    .{ .name = "eye_space_side", .kind = .int, .get_int = f_eye_side, .get_bool = null },
    .{ .name = "eye_space_opp", .kind = .int, .get_int = f_eye_opp, .get_bool = null },
    .{ .name = "empty_cells", .kind = .int, .get_int = f_empty_cells, .get_bool = null },
    .{ .name = "in_atari_side", .kind = .bool, .get_int = null, .get_bool = fb_atari_side },
    .{ .name = "in_atari_opp", .kind = .bool, .get_int = null, .get_bool = fb_atari_opp },
    .{ .name = "mutual_atari", .kind = .bool, .get_int = null, .get_bool = fb_mutual_atari },
    .{ .name = "benson_alive_side_now", .kind = .bool, .get_int = null, .get_bool = fb_benson_side },
    .{ .name = "benson_alive_opp_now", .kind = .bool, .get_int = null, .get_bool = fb_benson_opp },
    .{ .name = "planted", .kind = .int, .get_int = f_planted, .get_bool = null },
};

const Json = struct {
    buf: std.ArrayListUnmanaged(u8) = .empty,
    gpa: std.mem.Allocator,
    fn init(gpa: std.mem.Allocator) Json {
        return .{ .buf = .empty, .gpa = gpa };
    }
    fn deinit(j: *Json) void {
        j.buf.deinit(j.gpa);
    }
    fn raw(j: *Json, s: []const u8) !void {
        try j.buf.appendSlice(j.gpa, s);
    }
    fn num(j: *Json, v: anytype) !void {
        var b: [32]u8 = undefined;
        const s = try std.fmt.bufPrint(&b, "{d}", .{v});
        try j.buf.appendSlice(j.gpa, s);
    }
    fn fnum(j: *Json, v: f64) !void {
        var b: [32]u8 = undefined;
        const s = try std.fmt.bufPrint(&b, "{d:.4}", .{v});
        try j.buf.appendSlice(j.gpa, s);
    }
    fn str(j: *Json, s: []const u8) !void {
        try j.buf.append(j.gpa, '"');
        for (s) |c| {
            if (c == '"' or c == '\\') try j.buf.append(j.gpa, '\\');
            try j.buf.append(j.gpa, c);
        }
        try j.buf.append(j.gpa, '"');
    }
    fn comma(j: *Json) !void {
        try j.buf.append(j.gpa, ',');
    }
};

fn runSize(
    comptime w: comptime_int,
    comptime h: comptime_int,
    io: std.Io,
    gpa: std.mem.Allocator,
    wzo2_path: []const u8,
    sample_n: ?usize,
    seed: u64,
    json_path: []const u8,
    controls_only: bool,
) !void {
    var a2 = try artifact2.load(io, std.Io.Dir.cwd(), wzo2_path, gpa);
    defer a2.deinit();

    const all_entries = try enumerateFreshStart(w, h, &a2, gpa);
    defer gpa.free(all_entries);

    var entries: []Entry = all_entries;
    var sampled_buf: ?[]Entry = null;
    if (sample_n != null and sample_n.? < all_entries.len) {
        const sn = sample_n.?;
        const sp = try gpa.alloc(Entry, sn);
        for (0..sn) |i| sp[i] = all_entries[i];
        var t: usize = sn;
        var prng = std.Random.DefaultPrng.init(seed);
        const rng = prng.random();
        for (sn..all_entries.len) |i| {
            t += 1;
            const j = rng.uintLessThan(usize, t);
            if (j < sn) sp[j] = all_entries[i];
        }
        sampled_buf = sp;
        entries = sp;
        util.note("[T412PRED] {d}x{d} sampled {d}/{d} fresh-start entries (seed={d})\n", .{ w, h, sn, all_entries.len, seed });
    } else {
        util.note("[T412PRED] {d}x{d} exhaustive {d} fresh-start entries\n", .{ w, h, all_entries.len });
    }
    defer if (sampled_buf) |sb| gpa.free(sb);

    if (controls_only) {
        entries = all_entries[0..0];
        util.note("[T412PRED] CONTROLS-ONLY: entry list truncated to 0 (null control)\n", .{});
    }

    const n = entries.len;
    // labels
    const labels = try gpa.alloc(bool, n);
    defer gpa.free(labels);
    var n_lh: usize = 0;
    for (entries, 0..) |e, i| {
        const lh = e.L < e.H;
        labels[i] = lh;
        if (lh) n_lh += 1;
    }
    const base_rate: f64 = if (n == 0) 0 else @as(f64, @floatFromInt(n_lh)) / @as(f64, @floatFromInt(n));

    // planted feature: for a random 10% subset, planted = 1 iff label==true
    // (so the "planted" feature is a perfect predictor on that subset, 0
    // elsewhere).  This exercises the precision/recall path: at threshold
    // "planted >= 1", precision must be 1.0 and recall 0.1.
    var planted_vals = try gpa.alloc(u8, n);
    defer gpa.free(planted_vals);
    {
        var prng = std.Random.DefaultPrng.init(seed +% 777);
        const rng = prng.random();
        for (0..n) |i| {
            const in_subset = rng.uintLessThan(usize, 10) == 0;
            planted_vals[i] = if (in_subset and labels[i]) 1 else 0;
        }
    }

    // compute features into a packed array of Features and index it.
    const X = colex.Indexer(w, h);
    const FArr = Features;
    const farr = try gpa.alloc(FArr, n);
    defer gpa.free(farr);
    for (entries, 0..) |e, i| {
        const pos = X.pos_from_colex(e.colex);
        farr[i] = computeFeatures(w, h, &pos, e.side, planted_vals[i]);
    }

    // sweep each feature.  For each feature we materialise a []i64 or []bool
    // view (no closures — Zig has none) and pass it to the sweep.
    const Result = struct {
        name: []const u8,
        pr: PR,
    };
    var results: std.ArrayListUnmanaged(Result) = .empty;
    defer results.deinit(gpa);

    var ivals = try gpa.alloc(i64, n);
    defer gpa.free(ivals);
    var bvals = try gpa.alloc(bool, n);
    defer gpa.free(bvals);

    for (features) |ft| {
        const pr: PR = switch (ft.kind) {
            .int => blk: {
                const gi = ft.get_int.?;
                for (0..n) |i| ivals[i] = gi(farr[i]);
                break :blk try sweepInt(gpa, n, labels, ivals);
            },
            .bool => blk: {
                const gb = ft.get_bool.?;
                for (0..n) |i| bvals[i] = gb(farr[i]);
                break :blk sweepBool(n, labels, bvals);
            },
        };
        try results.append(gpa, .{ .name = ft.name, .pr = pr });
    }

    // best non-planted feature
    var best: ?Result = null;
    var best_name: []const u8 = "stones";
    for (results.items) |r| {
        if (std.mem.eql(u8, r.name, "planted")) continue;
        if (best == null or r.pr.f1 > best.?.pr.f1) {
            best = r;
            best_name = r.name;
        }
    }

    // ── null control: shuffle labels, re-score the best feature ─────────
    const null_pr: PR = blk: {
        if (n == 0) break :blk prFrom(0, 0, 0, 0, 0, 0);
        const shuf = try gpa.dupe(bool, labels);
        defer gpa.free(shuf);
        var prng = std.Random.DefaultPrng.init(seed +% 13);
        const rng = prng.random();
        var i: usize = n;
        while (i > 1) {
            i -= 1;
            const j = rng.uintLessThan(usize, i + 1);
            const tmp = shuf[i];
            shuf[i] = shuf[j];
            shuf[j] = tmp;
        }
        var bft: ?Feat = null;
        for (features) |ft| {
            if (std.mem.eql(u8, ft.name, best_name)) {
                bft = ft;
                break;
            }
        }
        if (bft) |ft| {
            switch (ft.kind) {
                .int => {
                    const gi = ft.get_int.?;
                    for (0..n) |k| ivals[k] = gi(farr[k]);
                    break :blk try sweepInt(gpa, n, shuf, ivals);
                },
                .bool => {
                    const gb = ft.get_bool.?;
                    for (0..n) |k| bvals[k] = gb(farr[k]);
                    break :blk sweepBool(n, shuf, bvals);
                },
            }
        }
        break :blk prFrom(0, 0, 0, 0, 0, 0);
    };

    // ── stdout summary ──────────────────────────────────────────────────
    util.out("[T412-PRED] size={d}x{d} wzo2={s} seed={d}\n", .{ w, h, wzo2_path, seed });
    if (sample_n != null) util.out("  sample: {d}/{d} fresh-start entries\n", .{ sample_n.?, all_entries.len });
    util.out("  entries: {d}   L<H: {d}  (base rate {d:.4})\n", .{ n, n_lh, base_rate });
    util.out("  --- single-feature best-F1 (predict L<H) ---\n", .{});
    for (results.items) |r| {
        util.out("  {s}  F1={d:.4}  P={d:.4}  R={d:.4}  thr={d} dir={d}\n", .{ r.name, r.pr.f1, r.pr.precision, r.pr.recall, r.pr.threshold, r.pr.direction });
    }
    if (best) |bf| {
        util.out("  BEST non-planted feature: {s}  F1={d:.4}  P={d:.4}  R={d:.4}\n", .{ bf.name, bf.pr.f1, bf.pr.precision, bf.pr.recall });
    }
    util.out("  --- controls ---\n", .{});
    util.out("  N1 null (shuffle labels, re-score best): F1={d:.4}  P={d:.4}  R={d:.4}  (should collapse toward base rate {d:.4})\n", .{ null_pr.f1, null_pr.precision, null_pr.recall, base_rate });
    // planted feature S1 — evaluate at its SELECTING threshold (planted>=1),
    // not best-F1: for a rare class the precision-perfect planted point
    // (P=1.0, R~0.1) has lower F1 than the trivial "predict all positive"
    // point, so best-F1 would mask it.  The control's purpose is to prove
    // the precision/recall arithmetic is correct: a perfect predictor must
    // read P=1.0 at the threshold that selects it.
    var planted_sel_tp: usize = 0;
    var planted_sel_fp: usize = 0;
    var planted_sel_fn: usize = 0;
    var planted_sel_tn: usize = 0;
    for (0..n) |i| {
        const pred = planted_vals[i] >= 1; // the selecting threshold
        const lab = labels[i];
        if (pred) {
            if (lab) planted_sel_tp += 1 else planted_sel_fp += 1;
        } else {
            if (lab) planted_sel_fn += 1 else planted_sel_tn += 1;
        }
    }
    const planted_sel = prFrom(planted_sel_tp, planted_sel_fp, planted_sel_fn, planted_sel_tn, 1, 0);
    var planted_bestf1: PR = prFrom(0, 0, 0, 0, 0, 0);
    for (results.items) |r| {
        if (std.mem.eql(u8, r.name, "planted")) planted_bestf1 = r.pr;
    }
    util.out("  S1 seeded (planted perfect-on-10%): at selecting threshold planted>=1: P={d:.4}  R={d:.4}  F1={d:.4}  (P must be 1.0)\n", .{ planted_sel.precision, planted_sel.recall, planted_sel.f1 });
    util.out("     planted best-F1 over all thresholds (for reference): F1={d:.4}  P={d:.4}  R={d:.4}\n", .{ planted_bestf1.f1, planted_bestf1.precision, planted_bestf1.recall });

    // ── JSON ────────────────────────────────────────────────────────────
    var j = Json.init(gpa);
    defer j.deinit();
    try j.raw("{\n");
    try j.raw("  \"task_id\": \"T412\",");
    try j.raw(" \"instrument\": \"t412_predictors\",");
    try j.raw(" \"size\": \""); try j.num(w); try j.raw("x"); try j.num(h); try j.raw("\",\n");
    try j.raw("  \"wzo2_path\": "); try j.str(wzo2_path); try j.comma();
    try j.raw(" \"seed\": "); try j.num(seed); try j.comma();
    if (sample_n) |sn| {
        try j.raw(" \"sample\": "); try j.num(sn); try j.comma();
        try j.raw(" \"freshstart_total\": "); try j.num(all_entries.len); try j.comma();
    }
    try j.raw(" \"n_entries\": "); try j.num(n); try j.comma();
    try j.raw(" \"n_LH\": "); try j.num(n_lh); try j.comma();
    try j.raw(" \"base_rate\": "); try j.fnum(base_rate); try j.comma();
    try j.raw(" \"features\": [");
    for (results.items, 0..) |r, i| {
        if (i > 0) try j.comma();
        try j.raw("\n    {");
        try j.raw("\"name\":"); try j.str(r.name); try j.comma();
        try j.raw("\"f1\":"); try j.fnum(r.pr.f1); try j.comma();
        try j.raw("\"precision\":"); try j.fnum(r.pr.precision); try j.comma();
        try j.raw("\"recall\":"); try j.fnum(r.pr.recall); try j.comma();
        try j.raw("\"tp\":"); try j.num(r.pr.tp); try j.comma();
        try j.raw("\"fp\":"); try j.num(r.pr.fp); try j.comma();
        try j.raw("\"fn\":"); try j.num(r.pr.fn_count); try j.comma();
        try j.raw("\"tn\":"); try j.num(r.pr.tn); try j.comma();
        try j.raw("\"threshold\":"); try j.num(r.pr.threshold); try j.comma();
        try j.raw("\"direction\":"); try j.num(r.pr.direction);
        try j.raw("}");
    }
    try j.raw("\n  ],\n");
    try j.raw("  \"best_nonplanted\": ");
    if (best) |bf| {
        try j.raw("{\"name\":"); try j.str(bf.name); try j.comma();
        try j.raw("\"f1\":"); try j.fnum(bf.pr.f1); try j.comma();
        try j.raw("\"precision\":"); try j.fnum(bf.pr.precision); try j.comma();
        try j.raw("\"recall\":"); try j.fnum(bf.pr.recall); try j.raw("}");
    } else {
        try j.raw("null");
    }
    try j.comma();
    try j.raw(" \"null_control\": {");
    try j.raw("\"f1\":"); try j.fnum(null_pr.f1); try j.comma();
    try j.raw("\"precision\":"); try j.fnum(null_pr.precision); try j.comma();
    try j.raw("\"recall\":"); try j.fnum(null_pr.recall); try j.raw("},");
    try j.raw(" \"planted_control\": {");
    try j.raw("\"sel_precision\":"); try j.fnum(planted_sel.precision); try j.comma();
    try j.raw("\"sel_recall\":"); try j.fnum(planted_sel.recall); try j.comma();
    try j.raw("\"sel_f1\":"); try j.fnum(planted_sel.f1); try j.comma();
    try j.raw("\"bestf1_f1\":"); try j.fnum(planted_bestf1.f1); try j.comma();
    try j.raw("\"bestf1_precision\":"); try j.fnum(planted_bestf1.precision); try j.comma();
    try j.raw("\"bestf1_recall\":"); try j.fnum(planted_bestf1.recall); try j.raw("}\n");
    try j.raw("}\n");

    if (json_path.len > 0) {
        std.Io.Dir.cwd().writeFile(io, .{ .sub_path = json_path, .data = j.buf.items }) catch |err| {
            util.warn("[T412PRED] failed to write json {s}: {s}\n", .{ json_path, @errorName(err) });
        };
    }
}

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    const io = init.io;
    _ = version;

    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();

    var opt_size: u8 = 3;
    var opt_wzo2: []const u8 = "";
    var opt_sample: ?usize = null;
    var opt_seed: u64 = 42;
    var opt_json: []const u8 = "";
    var opt_controls_only: bool = false;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--size")) {
            opt_size = try std.fmt.parseInt(u8, args.next() orelse return error.MissingArgument, 10);
        } else if (std.mem.eql(u8, arg, "--wzo2")) {
            opt_wzo2 = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--sample")) {
            opt_sample = try std.fmt.parseInt(usize, args.next() orelse return error.MissingArgument, 10);
        } else if (std.mem.eql(u8, arg, "--seed")) {
            opt_seed = try std.fmt.parseInt(u64, args.next() orelse return error.MissingArgument, 10);
        } else if (std.mem.eql(u8, arg, "--json")) {
            opt_json = args.next() orelse return error.MissingArgument;
        } else if (std.mem.eql(u8, arg, "--controls-only")) {
            opt_controls_only = true;
        } else {
            util.warn("unknown flag: {s}\n", .{arg});
            return error.InvalidArgument;
        }
    }

    const size = opt_size;
    if (opt_wzo2.len == 0) {
        opt_wzo2 = switch (size) {
            3 => "data/oracle-3x3-v2.wzo2",
            4 => "data/oracle-4x4-v2.wzo2",
            else => return error.InvalidSize,
        };
    }
    if (opt_json.len == 0) {
        opt_json = switch (size) {
            3 => "findings/T412-predictors-3x3.json",
            4 => "findings/T412-predictors-4x4.json",
            else => return error.InvalidSize,
        };
    }
    if (size == 4 and opt_sample == null) opt_sample = 200000;

    switch (size) {
        3 => try runSize(3, 3, io, gpa, opt_wzo2, opt_sample, opt_seed, opt_json, opt_controls_only),
        4 => try runSize(4, 4, io, gpa, opt_wzo2, opt_sample, opt_seed, opt_json, opt_controls_only),
        else => return error.InvalidSize,
    }
}