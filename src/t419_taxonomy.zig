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
// T419_TAXONOMY — the full loopy-child partition, and the depth-2 question.
//
// Task: T419 · Role: worker · Model: deepseek-v4-flash · Date: 2026-08-08
// Landmark: L2 (proven 4×4 values) — closes the five-count gap the operator
// asked for on 2026-08-08.  T412 answers two of the five counts exactly
// (forced-loop; one-of-one), conflates two into the "no-loop" bucket, and
// never measures the fifth (the depth-2 question).  This instrument
// re-derives T412's numbers on the SAME sample (reconciliation with the
// published table is the regression check) and adds:
//
//   GAP 1 — split "no-loop" (no OPTIMAL child is loopy) into:
//     (a) positions with loopy children, none of them optimal — a loop is
//         reachable but optimal play declines it; the operator's most-wanted
//         count — plus the margin distribution (how much worse the best
//         loopy child is than the optimal value); and
//     (b) positions with no loopy children at all.
//     (a)+(b) must reconcile to the published no-loop figure.
//
//   GAP 2 — the depth-2 question: how many positions have two (three)
//   sequential optimal loopy paths for both players.  For each parent p
//   (mover X): count positions where X has an optimal loopy move to q AND
//   the opponent Y at q also has an optimal loopy move to r (and X again
//   at r for depth 3).  Reported in the PERMISSIVE form (some optimal move
//   at each step is loopy — a loop is available) and the FORCED form
//   (every optimal move at each step is loopy — no escape at any step).
//   The depth-3 forced count is a lower bound on how deep a compelled loop
//   can run, and must be >= 80 at 3×3 (T416's forced-cycle states,
//   exhaustive) — that reconciliation is the row's strongest control.
//
// Loopy criterion: L < H at the child (T412's value-ambiguity marker, kept
// verbatim so the numbers compose with the published table).  No graph
// criterion is substituted; the two would be reported separately if they
// diverged.
//
// Reads ONLY (WZO2 artifacts).  Compiles standalone:
//   zig build-exe -O ReleaseFast -Mroot=src/t419_taxonomy.zig \
//     --cache-dir /tmp/weizigo/t419/cache --global-cache-dir /tmp/weizigo/t419/global \
//     --name weizigo-t419-tax -femit-bin=/tmp/weizigo/t419/t419-tax
//
// Usage: weizigo-t419-tax --size 3|4 [--wzo2 <p>] [--sample <N>] [--seed <N>]
//          [--json <p>] [--seedctl force_loopy|none_loopy|none]
//
// Defaults: 3×3 exhaustive; 4×4 reservoir sample 200000 seed 42 — T412's
// declared sample, reproduced verbatim so the numbers compose.

const std = @import("std");
const rules = @import("rules.zig");
const artifact2 = @import("artifact2.zig");
const colex = @import("colex.zig");
const util = @import("util.zig");

// ═══════════════════════════════════════════════════════════════════════════
//  PURE HELPERS (unit-tested — see tests at the bottom)
// ═══════════════════════════════════════════════════════════════════════════

fn pinnedValue(L: i8, H: i8) i8 {
    return @max(L, @min(0, H));
}

/// A child as seen from its parent: its pinned value (Black-positive) and
/// whether the child is loopy (L < H at the child).
pub const ChildInfo = struct {
    v: i8,
    loopy: bool,
};

pub const ParentClass = enum {
    forced, // every optimal child is loopy (n_optimal >= 1)
    partial, // some but not all optimal children are loopy
    no_loop_a, // loopy children exist, none of them optimal (declined loop)
    no_loop_b, // no loopy children at all
    no_optimal, // no classifiable optimal children (leaf / no children)
};

pub const ClassResult = struct {
    class: ParentClass,
    n_optimal: u16,
    n_loopy_optimal: u16,
    n_loopy_children: u16, // ANY child that is loopy (optimal or not)
    margin: ?u16, // no_loop_a only: |best_v - best loopy child v| (>= 1)
};

/// Classify a parent from its Bellman best over children and its children.
/// `maximizing`: Black to move (argmax) vs White (argmin); scores are
/// Black-positive throughout — the side to move picks the array, never the
/// sign.  Children whose pinned value equals best_v are optimal.
pub fn classifyParent(maximizing: bool, best_v: i8, children: []const ChildInfo) ClassResult {
    var n_optimal: u16 = 0;
    var n_loopy_optimal: u16 = 0;
    var n_loopy_children: u16 = 0;
    var best_loopy_v: i8 = if (maximizing) -127 else 127;
    for (children) |c| {
        if (c.loopy) {
            n_loopy_children += 1;
            if (maximizing) {
                if (c.v > best_loopy_v) best_loopy_v = c.v;
            } else {
                if (c.v < best_loopy_v) best_loopy_v = c.v;
            }
        }
        if (c.v == best_v) {
            n_optimal += 1;
            if (c.loopy) n_loopy_optimal += 1;
        }
    }

    if (n_optimal == 0) {
        return .{ .class = .no_optimal, .n_optimal = 0, .n_loopy_optimal = 0, .n_loopy_children = n_loopy_children, .margin = null };
    }
    if (n_loopy_optimal == n_optimal) {
        return .{ .class = .forced, .n_optimal = n_optimal, .n_loopy_optimal = n_loopy_optimal, .n_loopy_children = n_loopy_children, .margin = null };
    }
    if (n_loopy_optimal > 0) {
        return .{ .class = .partial, .n_optimal = n_optimal, .n_loopy_optimal = n_loopy_optimal, .n_loopy_children = n_loopy_children, .margin = null };
    }
    // no optimal child is loopy: split (a) has loopy children (declined
    // loop, with margin) vs (b) no loopy children at all.
    if (n_loopy_children > 0) {
        // The best loopy child cannot tie best_v (it would be optimal), so
        // the margin is >= 1.  Black maximises (margin = best_v - best
        // loopy v), White minimises (margin = best loopy v - best_v).
        const margin: u16 = if (maximizing)
            @intCast(best_v - best_loopy_v)
        else
            @intCast(best_loopy_v - best_v);
        return .{ .class = .no_loop_a, .n_optimal = n_optimal, .n_loopy_optimal = 0, .n_loopy_children = n_loopy_children, .margin = margin };
    }
    return .{ .class = .no_loop_b, .n_optimal = n_optimal, .n_loopy_optimal = 0, .n_loopy_children = 0, .margin = null };
}

pub const D1 = struct { perm1: bool = false, forced1: bool = false };

pub const DepthResult = struct {
    perm1: bool = false, forced1: bool = false,
    perm2: bool = false, forced2: bool = false,
    perm3: bool = false, forced3: bool = false,
};

fn d1Of(opt_children: []const []const u32, loopy: []const bool, i: u32) D1 {
    const oc = opt_children[i];
    var any = false;
    var all = oc.len > 0;
    for (oc) |c| {
        if (loopy[c]) any = true else all = false;
    }
    return .{ .perm1 = any, .forced1 = all };
}

/// Pure depth-1..3 for one root of an abstract optimal-loopy graph.
///   opt_children[i] = ids of state i's OPTIMAL children (empty = leaf)
///   loopy[i]        = state i itself is loopy (L < H)
/// The graph must contain, for the root, its optimal children, their optimal
/// children, and their optimal children (3 levels); the deepest level only
/// needs its loopy flags.
///
/// perm_k:  there EXISTS an optimal loopy move at each of k consecutive
///          steps (a loop is available).
/// forced_k: EVERY optimal move at each of k consecutive steps is loopy
///          (no escape at any step).
pub fn computeDepth(opt_children: []const []const u32, loopy: []const bool, root: u32) DepthResult {
    var r = DepthResult{};

    // d1 of the root: over its OWN optimal children.
    const d_root = d1Of(opt_children, loopy, root);
    r.perm1 = d_root.perm1;
    r.forced1 = d_root.forced1;

    if (d_root.perm1 or d_root.forced1) {
        // depth 2: expand the root's optimal children.
        var f2: bool = d_root.forced1;
        for (opt_children[root]) |c| {
            const dc = d1Of(opt_children, loopy, c);
            // permissive: some optimal child of the root is loopy AND that
            // child has an optimal loopy child of its own.
            if (loopy[c] and dc.perm1) r.perm2 = true;
            // forced: every optimal child of the root is loopy (d_root.
            // forced1) AND every optimal child of each such child is loopy.
            if (d_root.forced1 and !dc.forced1) f2 = false;
        }
        r.forced2 = if (d_root.forced1) f2 else false;
    }

    if (r.perm2) {
        // depth 3 permissive: some optimal child c of the root is loopy with
        // perm2(c) — i.e. some optimal child d of c is loopy with perm1(d).
        for (opt_children[root]) |c| {
            if (!loopy[c]) continue;
            for (opt_children[c]) |d| {
                if (!loopy[d]) continue;
                const dd = d1Of(opt_children, loopy, d);
                if (dd.perm1) {
                    r.perm3 = true;
                    break;
                }
            }
        }
    }

    if (r.forced2) {
        // depth 3 forced: forced2 at the root AND forced2 at every optimal
        // child c (forced2(c) = forced1(c) and every optimal child of c is
        // forced1).
        var f3: bool = true;
        for (opt_children[root]) |c| {
            const dc = d1Of(opt_children, loopy, c);
            if (!dc.forced1) {
                f3 = false;
                break;
            }
            for (opt_children[c]) |d| {
                const dd = d1Of(opt_children, loopy, d);
                if (!dd.forced1) {
                    f3 = false;
                    break;
                }
            }
        }
        r.forced3 = f3;
    }

    return r;
}

// ═══════════════════════════════════════════════════════════════════════════
//  TABLE ENUMERATION (mirrors src/t412_sibling.zig verbatim)
// ═══════════════════════════════════════════════════════════════════════════

const NTParent = struct {
    colex: u32,
    side: i8,
    ko: u8,
    passes: u8,
    L: i8,
    H: i8,
};

fn enumerateNonTerminal(
    a2: *const artifact2.LoadedArtifact,
    gpa: std.mem.Allocator,
) ![]NTParent {
    const G: usize = @intCast(a2.header.n_groups);
    const groups = a2.data[a2.group_base .. a2.group_base + G * artifact2.GROUP_HEADER_SIZE];
    var results: std.ArrayListUnmanaged(NTParent) = .empty;
    var cum: u64 = 0;
    for (0..G) |g| {
        const colex_val = std.mem.readInt(u32, groups[g * artifact2.GROUP_HEADER_SIZE ..][0..4], .little);
        const count: usize = groups[g * artifact2.GROUP_HEADER_SIZE + 4];
        const entry_off = a2.entry_base + cum * artifact2.ENTRY_SIZE;
        for (0..count) |ei| {
            const eb = a2.data[entry_off + ei * artifact2.ENTRY_SIZE ..][0..artifact2.ENTRY_SIZE];
            const kb = eb[0];
            const decoded = artifact2.decodeKeyByte(kb, a2.header.ko_bits);
            if (decoded.terminal != 0) continue; // terminal states have no children
            const L: i8 = @bitCast(eb[1]);
            const H: i8 = @bitCast(eb[2]);
            try results.append(gpa, .{
                .colex = colex_val,
                .side = artifact2.u1ToSide(decoded.side),
                .ko = decoded.ko,
                .passes = decoded.passes,
                .L = L,
                .H = H,
            });
        }
        cum += count;
    }
    return results.toOwnedSlice(gpa);
}

// ═══════════════════════════════════════════════════════════════════════════
//  CHILD ENUMERATION (mirrors src/t412_sibling.zig / src/t416_cycle.zig)
// ═══════════════════════════════════════════════════════════════════════════

const Child = struct {
    v: i8, // pinned value of the child
    loopy: bool, // L < H at the child (force_loopy overrides)
    has_entry: bool, // non-terminal table entry exists (recursable)
    colex: u32, // child's own state identity (for recursion)
    side: i8,
    ko: u8,
    passes: u8,
};

const ChildEnum = struct {
    children: [17]Child = undefined,
    n: usize = 0,
};

/// The loopy flag of a child under the seed controls:
///   force_loopy  -> always true  (seeded: every child is loopy)
///   none_loopy   -> always false (null: no child is loopy)
///   none         -> the natural L < H marker
fn loopyFlag(force_loopy: bool, none_loopy: bool, natural: bool) bool {
    if (force_loopy) return true;
    if (none_loopy) return false;
    return natural;
}

fn enumChildren(
    comptime w: comptime_int,
    comptime h: comptime_int,
    a2: *const artifact2.LoadedArtifact,
    colex_val: u32,
    side: i8,
    ko: u8,
    passes: u8,
    force_loopy: bool,
    none_loopy: bool,
) ChildEnum {
    const R = rules.Rules(w, h);
    const X = colex.Indexer(w, h);
    const n = w * h;
    const KO_NONE: u8 = n;
    var ce = ChildEnum{};

    const pos = X.pos_from_colex(colex_val);

    for (0..n) |cell| {
        if (pos[cell] != 0) continue;
        if (ko < KO_NONE and cell == ko) continue;
        const child = R.pos_from_move(&pos, side, cell) catch continue;
        const child_ko = rules.koAfterCapture(&pos, &child, side, w, h, KO_NONE);
        const child_colex: u32 = @intCast(X.colex_from_pos(&child));
        if (artifact2.lookup(a2, child_colex, -side, child_ko, 0)) |row| {
            ce.children[ce.n] = .{
                .v = pinnedValue(row.L, row.H),
                .loopy = loopyFlag(force_loopy, none_loopy, row.L < row.H),
                .has_entry = !row.terminal,
                .colex = child_colex,
                .side = -side,
                .ko = child_ko,
                .passes = 0,
            };
        } else {
            ce.children[ce.n] = .{
                .v = R.area_score(&child),
                .loopy = loopyFlag(force_loopy, none_loopy, false),
                .has_entry = false,
                .colex = child_colex,
                .side = -side,
                .ko = child_ko,
                .passes = 0,
            };
        }
        ce.n += 1;
    }

    // pass child
    if (passes >= 1) {
        // double pass -> terminal, scored by area
        ce.children[ce.n] = .{
            .v = R.area_score(&pos),
            .loopy = loopyFlag(force_loopy, none_loopy, false),
            .has_entry = false,
            .colex = colex_val,
            .side = -side,
            .ko = KO_NONE,
            .passes = 2,
        };
        ce.n += 1;
    } else {
        const np: u2 = @intCast(passes + 1);
        if (artifact2.lookup(a2, colex_val, -side, KO_NONE, np)) |row| {
            ce.children[ce.n] = .{
                .v = pinnedValue(row.L, row.H),
                .loopy = loopyFlag(force_loopy, none_loopy, row.L < row.H),
                .has_entry = !row.terminal,
                .colex = colex_val,
                .side = -side,
                .ko = KO_NONE,
                .passes = np,
            };
        } else {
            ce.children[ce.n] = .{
                .v = R.area_score(&pos),
                .loopy = loopyFlag(force_loopy, none_loopy, false),
                .has_entry = false,
                .colex = colex_val,
                .side = -side,
                .ko = KO_NONE,
                .passes = np,
            };
        }
        ce.n += 1;
    }

    return ce;
}

const BellmanBest = struct { best: i8, any: bool };

fn bellmanBest(ce: *const ChildEnum, maximizing: bool) BellmanBest {
    var best: i8 = if (maximizing) -127 else 127;
    var any = false;
    for (ce.children[0..ce.n]) |c| {
        any = true;
        if (maximizing) {
            if (c.v > best) best = c.v;
        } else {
            if (c.v < best) best = c.v;
        }
    }
    return .{ .best = best, .any = any };
}

// ═══════════════════════════════════════════════════════════════════════════
//  DEPTH (Gap 2) — per-root local graph over real table data
// ═══════════════════════════════════════════════════════════════════════════

const StateRef = struct {
    colex: u32,
    side: i8,
    ko: u8,
    passes: u8,
    loopy: bool,
};

/// Build the 3-level local optimal-loopy graph for one root and compute its
/// depth result via the pure computeDepth.
/// Only called when the root has >= 1 optimal loopy child (else all-false).
fn rootDepth(
    comptime w: comptime_int,
    comptime h: comptime_int,
    a2: *const artifact2.LoadedArtifact,
    gpa: std.mem.Allocator,
    root_ce: *const ChildEnum,
    bb: BellmanBest,
    force_loopy: bool,
    none_loopy: bool,
    cls: ClassResult,
) !DepthResult {
    if (cls.n_loopy_optimal == 0) return .{};

    var states: std.ArrayListUnmanaged(StateRef) = .empty;
    var opt_local: std.ArrayListUnmanaged(std.ArrayListUnmanaged(u32)) = .empty;
    var loopy_local: std.ArrayListUnmanaged(bool) = .empty;
    defer {
        for (opt_local.items) |*o| o.deinit(gpa);
        opt_local.deinit(gpa);
        states.deinit(gpa);
        loopy_local.deinit(gpa);
    }

    // id 0 = root (its own loopy flag is unused by computeDepth)
    try states.append(gpa, .{ .colex = 0, .side = 0, .ko = 0, .passes = 0, .loopy = false });
    try opt_local.append(gpa, .empty);
    try loopy_local.append(gpa, false);

    // level 1: root's optimal children (ALL of them — forced quantifiers
    // range over every optimal child, not just the loopy ones)
    var lvl1: std.ArrayListUnmanaged(u32) = .empty;
    defer lvl1.deinit(gpa);
    for (root_ce.children[0..root_ce.n]) |ch| {
        if (ch.v != bb.best) continue;
        try states.append(gpa, .{ .colex = ch.colex, .side = ch.side, .ko = ch.ko, .passes = ch.passes, .loopy = ch.loopy });
        try opt_local.append(gpa, .empty);
        try loopy_local.append(gpa, ch.loopy);
        try lvl1.append(gpa, @intCast(states.items.len - 1));
    }
    try opt_local.items[0].appendSlice(gpa, lvl1.items);

    // level 2 + 3: expand each level-1 state's optimal children, then each
    // level-2 state's optimal children (their loopy flags only)
    var lvl2: std.ArrayListUnmanaged(u32) = .empty;
    defer lvl2.deinit(gpa);
    for (lvl1.items) |id| {
        const st = states.items[id];
        if (!st.loopy and !force_loopy) {
            // non-loopy optimal children cannot host a loopy path, but their
            // d1 still matters for the forced quantifiers — expand anyway.
        }
        if (entryOf(a2, st)) {
            const ce2 = enumChildren(w, h, a2, st.colex, st.side, st.ko, st.passes, force_loopy, none_loopy);
            const bb2 = bellmanBest(&ce2, st.side > 0);
            for (ce2.children[0..ce2.n]) |ch| {
                if (ch.v != bb2.best) continue;
                try states.append(gpa, .{ .colex = ch.colex, .side = ch.side, .ko = ch.ko, .passes = ch.passes, .loopy = ch.loopy });
                try opt_local.append(gpa, .empty);
                try loopy_local.append(gpa, ch.loopy);
                try opt_local.items[id].append(gpa, @intCast(states.items.len - 1));
                try lvl2.append(gpa, @intCast(states.items.len - 1));
            }
        }
    }
    for (lvl2.items) |id| {
        const st = states.items[id];
        if (!entryOf(a2, st)) continue;
        const ce3 = enumChildren(w, h, a2, st.colex, st.side, st.ko, st.passes, force_loopy, none_loopy);
        const bb3 = bellmanBest(&ce3, st.side > 0);
        for (ce3.children[0..ce3.n]) |ch| {
            if (ch.v != bb3.best) continue;
            try states.append(gpa, .{ .colex = ch.colex, .side = ch.side, .ko = ch.ko, .passes = ch.passes, .loopy = ch.loopy });
            try opt_local.append(gpa, .empty);
            try loopy_local.append(gpa, ch.loopy);
            try opt_local.items[id].append(gpa, @intCast(states.items.len - 1));
        }
    }

    // opt_children as slices
    const opt_slices = try gpa.alloc([]const u32, opt_local.items.len);
    defer gpa.free(opt_slices);
    for (opt_local.items, 0..) |*o, i| opt_slices[i] = o.items;

    return computeDepth(opt_slices, loopy_local.items, 0);
}

/// True if the state has a non-terminal table entry (recursable).
fn entryOf(a2: *const artifact2.LoadedArtifact, st: StateRef) bool {
    if (artifact2.lookup(a2, st.colex, st.side, st.ko, @intCast(st.passes))) |row| {
        return !row.terminal;
    }
    return false;
}

// ═══════════════════════════════════════════════════════════════════════════
//  AGGREGATION
// ═══════════════════════════════════════════════════════════════════════════

const Agg = struct {
    n_parents: usize = 0,
    tautology_checks: usize = 0,
    tautology_mismatches: usize = 0,
    // gap 1 buckets
    forced: usize = 0,
    one_of_one: usize = 0,
    all_loopy_k: usize = 0,
    partial: usize = 0,
    no_loop: usize = 0,
    no_loop_a: usize = 0,
    no_loop_b: usize = 0,
    no_optimal: usize = 0,
    total_optimal_children: u64 = 0,
    total_loopy_optimal_children: u64 = 0,
    total_loopy_children: u64 = 0,
    margin_hist: [64]u64 = .{0} ** 64,
    n_margin: usize = 0,
    // gap 2 depth counts
    depth_perm1: usize = 0,
    depth_forced1: usize = 0,
    depth_perm2: usize = 0,
    depth_forced2: usize = 0,
    depth_perm3: usize = 0,
    depth_forced3: usize = 0,
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
    force_loopy: bool,
    none_loopy: bool,
) !void {
    var a2 = try artifact2.load(io, std.Io.Dir.cwd(), wzo2_path, gpa);
    defer a2.deinit();

    var agg = Agg{};
    var j = Json.init(gpa);
    defer j.deinit();

    const all_parents = try enumerateNonTerminal(&a2, gpa);
    defer gpa.free(all_parents);

    var parents: []NTParent = all_parents;
    var sampled_buf: ?[]NTParent = null;
    if (sample_n != null and sample_n.? < all_parents.len) {
        const sn = sample_n.?;
        const sp = try gpa.alloc(NTParent, sn);
        for (0..sn) |i| sp[i] = all_parents[i];
        var t: usize = sn;
        var prng = std.Random.DefaultPrng.init(seed);
        const rng = prng.random();
        for (sn..all_parents.len) |i| {
            t += 1;
            const k = rng.uintLessThan(usize, t);
            if (k < sn) sp[k] = all_parents[i];
        }
        sampled_buf = sp;
        parents = sp;
        util.note("[T419] {d}x{d} sampled {d}/{d} non-terminal positions (seed={d}) — T412's declared sample\n", .{ w, h, sn, all_parents.len, seed });
    } else {
        util.note("[T419] {d}x{d} exhaustive {d} non-terminal positions\n", .{ w, h, all_parents.len });
    }
    defer if (sampled_buf) |sb| gpa.free(sb);

    agg.n_parents = parents.len;

    for (parents, 0..) |p, pi| {
        if (pi % 25000 == 0 and pi > 0) {
            util.note("[progress] T419 {d}x{d}: {d}/{d} parents classified\n", .{ w, h, pi, parents.len });
        }
        const ce = enumChildren(w, h, &a2, p.colex, p.side, p.ko, p.passes, force_loopy, none_loopy);
        const maximizing = p.side > 0;
        const bb = bellmanBest(&ce, maximizing);
        const V_p = pinnedValue(p.L, p.H);
        agg.tautology_checks += 1;
        if (bb.any and V_p != bb.best) agg.tautology_mismatches += 1;

        var infos: [17]ChildInfo = undefined;
        var n_loopy_children: u16 = 0;
        for (0..ce.n) |i| {
            infos[i] = .{ .v = ce.children[i].v, .loopy = ce.children[i].loopy };
            if (ce.children[i].loopy) n_loopy_children += 1;
        }
        var cls = classifyParent(maximizing, bb.best, infos[0..ce.n]);
        cls.n_loopy_children = n_loopy_children;

        switch (cls.class) {
            .forced => {
                agg.forced += 1;
                if (cls.n_optimal == 1) agg.one_of_one += 1 else agg.all_loopy_k += 1;
            },
            .partial => agg.partial += 1,
            .no_loop_a => {
                agg.no_loop += 1;
                agg.no_loop_a += 1;
                const m = cls.margin.?;
                agg.margin_hist[@min(m, 63)] += 1;
                agg.n_margin += 1;
            },
            .no_loop_b => {
                agg.no_loop += 1;
                agg.no_loop_b += 1;
            },
            .no_optimal => agg.no_optimal += 1,
        }
        agg.total_optimal_children += cls.n_optimal;
        agg.total_loopy_optimal_children += cls.n_loopy_optimal;
        agg.total_loopy_children += cls.n_loopy_children;

        // gap 2 — depth, only meaningful when there is an optimal loopy child
        const depth = try rootDepth(w, h, &a2, gpa, &ce, bb, force_loopy, none_loopy, cls);
        if (depth.perm1) agg.depth_perm1 += 1;
        if (depth.forced1) agg.depth_forced1 += 1;
        if (depth.perm2) agg.depth_perm2 += 1;
        if (depth.forced2) agg.depth_forced2 += 1;
        if (depth.perm3) agg.depth_perm3 += 1;
        if (depth.forced3) agg.depth_forced3 += 1;
    }

    // ── report ─────────────────────────────────────────────────────────
    const seedctl_name = if (force_loopy) "force_loopy" else if (none_loopy) "none_loopy" else "none";
    util.out("[T419] size={d}x{d} seedctl={s}\n", .{ w, h, seedctl_name });
    if (sample_n != null) util.out("  sample: {d}/{d} non-terminal positions (seed={d})\n", .{ sample_n.?, all_parents.len, seed });
    util.out("  parents: {d}\n", .{agg.n_parents});
    util.out("  tautology V_p==Bellman-best: {d} checks, {d} mismatches  (regression guard)\n", .{ agg.tautology_checks, agg.tautology_mismatches });
    util.out("  --- GAP 1: full loopy-child partition (denominator: {d} parents) ---\n", .{agg.n_parents});
    util.out("  FORCED (every optimal child loopy): {d}\n", .{agg.forced});
    util.out("    one-of-one: {d}   all-loopy k>=2: {d}\n", .{ agg.one_of_one, agg.all_loopy_k });
    util.out("  partial (some optimal loopy): {d}\n", .{agg.partial});
    util.out("  no-loop (no optimal loopy): {d}\n", .{agg.no_loop});
    util.out("    (a) loopy children exist, none optimal: {d}\n", .{agg.no_loop_a});
    util.out("    (b) no loopy children at all: {d}\n", .{agg.no_loop_b});
    util.out("  no-optimal: {d}\n", .{agg.no_optimal});
    util.out("  children: total_optimal={d} loopy_optimal={d} any_loopy={d}\n", .{ agg.total_optimal_children, agg.total_loopy_optimal_children, agg.total_loopy_children });
    util.out("  margin (best loopy child vs optimal), n={d}:\n", .{agg.n_margin});
    var mi: usize = 0;
    while (mi < 64) : (mi += 1) {
        if (agg.margin_hist[mi] > 0) util.out("    margin {d}: {d}\n", .{ mi, agg.margin_hist[mi] });
    }
    util.out("  --- GAP 2: depth-1..3 (permissive / forced) ---\n", .{});
    util.out("  depth 1: permissive {d}  forced {d}\n", .{ agg.depth_perm1, agg.depth_forced1 });
    util.out("  depth 2: permissive {d}  forced {d}\n", .{ agg.depth_perm2, agg.depth_forced2 });
    util.out("  depth 3: permissive {d}  forced {d}\n", .{ agg.depth_perm3, agg.depth_forced3 });

    // ── json ───────────────────────────────────────────────────────────
    const margin_stats = marginStats(&agg);
    try j.raw("{\n");
    try j.raw("  \"task_id\": \"T419\",");
    try j.raw(" \"instrument\": \"t419_taxonomy\",");
    try j.raw(" \"size\": \""); try j.num(w); try j.raw("x"); try j.num(h); try j.raw("\",\n");
    try j.raw("  \"wzo2_path\": "); try j.str(wzo2_path); try j.comma();
    try j.raw(" \"seedctl\": "); try j.str(seedctl_name); try j.comma();
    try j.raw(" \"seed\": "); try j.num(seed); try j.comma();
    if (sample_n) |sn| { try j.raw(" \"sample\": "); try j.num(sn); try j.comma(); }
    try j.raw("\n");
    try j.raw("  \"parents\": {\n");
    try j.raw("    \"n_parents_total\": "); try j.num(all_parents.len); try j.comma();
    try j.raw(" \"n_parents\": "); try j.num(agg.n_parents); try j.comma();
    try j.raw(" \"tautology_checks\": "); try j.num(agg.tautology_checks); try j.comma();
    try j.raw(" \"tautology_mismatches\": "); try j.num(agg.tautology_mismatches); try j.raw("\n");
    try j.raw("  },\n");
    try j.raw("  \"gap1\": {\n");
    try j.raw("    \"forced\": "); try j.num(agg.forced); try j.comma();
    try j.raw(" \"one_of_one\": "); try j.num(agg.one_of_one); try j.comma();
    try j.raw(" \"all_loopy_k\": "); try j.num(agg.all_loopy_k); try j.comma();
    try j.raw(" \"partial\": "); try j.num(agg.partial); try j.comma();
    try j.raw(" \"no_loop\": "); try j.num(agg.no_loop); try j.comma();
    try j.raw(" \"no_loop_a\": "); try j.num(agg.no_loop_a); try j.comma();
    try j.raw(" \"no_loop_b\": "); try j.num(agg.no_loop_b); try j.comma();
    try j.raw(" \"no_optimal\": "); try j.num(agg.no_optimal); try j.comma();
    try j.raw(" \"total_optimal_children\": "); try j.num(agg.total_optimal_children); try j.comma();
    try j.raw(" \"total_loopy_optimal_children\": "); try j.num(agg.total_loopy_optimal_children); try j.comma();
    try j.raw(" \"total_loopy_children\": "); try j.num(agg.total_loopy_children); try j.comma();
    try j.raw(" \"margin\": {\n");
    try j.raw("   \"n\": "); try j.num(margin_stats.n); try j.comma();
    try j.raw(" \"min\": "); try j.num(margin_stats.min); try j.comma();
    try j.raw(" \"max\": "); try j.num(margin_stats.max); try j.comma();
    try j.raw(" \"median\": "); try j.num(margin_stats.median); try j.comma();
    try j.raw(" \"mean\": "); try j.numF(margin_stats.mean); try j.comma();
    try j.raw(" \"hist\": [");
    for (0..64) |m| { if (m > 0) try j.comma(); try j.num(agg.margin_hist[m]); }
    try j.raw("]\n");
    try j.raw("   }\n");
    try j.raw("  },\n");
    try j.raw("  \"gap2\": {\n");
    try j.raw("    \"perm1\": "); try j.num(agg.depth_perm1); try j.comma();
    try j.raw(" \"forced1\": "); try j.num(agg.depth_forced1); try j.comma();
    try j.raw(" \"perm2\": "); try j.num(agg.depth_perm2); try j.comma();
    try j.raw(" \"forced2\": "); try j.num(agg.depth_forced2); try j.comma();
    try j.raw(" \"perm3\": "); try j.num(agg.depth_perm3); try j.comma();
    try j.raw(" \"forced3\": "); try j.num(agg.depth_forced3); try j.raw("\n");
    try j.raw("  },\n");
    try j.raw("  \"reconciliations\": {\n");
    try j.raw("    \"no_loop_a_plus_b_equals_no_loop\": "); try j.jbool(agg.no_loop_a + agg.no_loop_b == agg.no_loop); try j.comma();
    try j.raw(" \"perm1_equals_forced_plus_partial\": "); try j.jbool(agg.depth_perm1 == agg.forced + agg.partial); try j.comma();
    try j.raw(" \"forced1_equals_forced\": "); try j.jbool(agg.depth_forced1 == agg.forced); try j.comma();
    try j.raw(" \"forced_monotone\": "); try j.jbool(agg.depth_forced3 <= agg.depth_forced2 and agg.depth_forced2 <= agg.depth_forced1); try j.comma();
    try j.raw(" \"perm_monotone\": "); try j.jbool(agg.depth_perm1 >= agg.depth_perm2 and agg.depth_perm2 >= agg.depth_perm3); try j.raw("\n");
    try j.raw("  }\n");
    try j.raw("}\n");

    if (json_path.len > 0) {
        std.Io.Dir.cwd().writeFile(io, .{ .sub_path = json_path, .data = j.buf.items }) catch |err| {
            util.warn("[T419] failed to write json {s}: {s}\n", .{ json_path, @errorName(err) });
        };
    }
}

const MarginStats = struct { n: usize, min: u16, max: u16, median: u16, mean: f64 };

fn marginStats(agg: *const Agg) MarginStats {
    var s = MarginStats{ .n = agg.n_margin, .min = 0, .max = 0, .median = 0, .mean = 0 };
    if (agg.n_margin == 0) return s;
    var total: u64 = 0;
    var first: bool = true;
    for (0..64) |m| {
        const c = agg.margin_hist[m];
        if (c == 0) continue;
        if (first) { s.min = @intCast(m); first = false; }
        s.max = @intCast(m);
        total += c * m;
    }
    s.mean = @as(f64, @floatFromInt(total)) / @as(f64, @floatFromInt(agg.n_margin));
    // median: middle element of the histogram
    var half: usize = agg.n_margin / 2;
    for (0..64) |m| {
        const c = agg.margin_hist[m];
        if (half < c) { s.median = @intCast(m); break; }
        half -= c;
    }
    return s;
}

// ═══════════════════════════════════════════════════════════════════════════
//  JSON writer (mirrors src/t412_sibling.zig)
// ═══════════════════════════════════════════════════════════════════════════

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
    fn numF(j: *Json, v: f64) !void {
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
    fn jbool(j: *Json, b: bool) !void {
        try j.raw(if (b) "true" else "false");
    }
    fn comma(j: *Json) !void {
        try j.buf.append(j.gpa, ',');
    }
};

// ═══════════════════════════════════════════════════════════════════════════
//  DRIVER
// ═══════════════════════════════════════════════════════════════════════════

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    const io = init.io;

    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();

    var opt_size: u8 = 3;
    var opt_wzo2: []const u8 = "";
    var opt_sample: ?usize = null;
    var opt_seed: u64 = 42;
    var opt_json: []const u8 = "";
    var opt_force_loopy: bool = false;
    var opt_none_loopy: bool = false;

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
        } else if (std.mem.eql(u8, arg, "--seedctl")) {
            const v = args.next() orelse return error.MissingArgument;
            if (std.mem.eql(u8, v, "force_loopy")) opt_force_loopy = true else if (std.mem.eql(u8, v, "none_loopy")) opt_none_loopy = true else if (std.mem.eql(u8, v, "none")) {} else return error.InvalidArgument;
        } else {
            util.warn("unknown flag: {s}\n", .{arg});
            return error.InvalidArgument;
        }
    }

    if (opt_wzo2.len == 0) {
        opt_wzo2 = switch (opt_size) {
            3 => "data/oracle-3x3-v2.wzo2",
            4 => "data/oracle-4x4-v2.wzo2",
            else => return error.InvalidSize,
        };
    }
    if (opt_json.len == 0) {
        opt_json = switch (opt_size) {
            3 => "findings/T419-taxonomy-3x3.json",
            4 => "findings/T419-taxonomy-4x4.json",
            else => return error.InvalidSize,
        };
    }
    if (opt_size == 4 and opt_sample == null) opt_sample = 200000; // T412's declared sample

    switch (opt_size) {
        3 => try runSize(3, 3, io, gpa, opt_wzo2, opt_sample, opt_seed, opt_json, opt_force_loopy, opt_none_loopy),
        4 => try runSize(4, 4, io, gpa, opt_wzo2, opt_sample, opt_seed, opt_json, opt_force_loopy, opt_none_loopy),
        else => return error.InvalidSize,
    }
}

// ═══════════════════════════════════════════════════════════════════════════
//  UNIT TESTS (test-first; wired into `zig build test`)
// ═══════════════════════════════════════════════════════════════════════════

const testing = std.testing;

test "classifyParent: forced one-of-one (Black)" {
    const c = classifyParent(true, 5, &.{.{ .v = 5, .loopy = true }});
    try testing.expectEqual(ParentClass.forced, c.class);
    try testing.expectEqual(@as(u16, 1), c.n_optimal);
    try testing.expectEqual(@as(u16, 1), c.n_loopy_optimal);
    try testing.expectEqual(@as(u16, 1), c.n_loopy_children);
    try testing.expect(c.margin == null);
}

test "classifyParent: forced k>=2 (Black), suboptimal sibling" {
    const children = [_]ChildInfo{ .{ .v = 5, .loopy = true }, .{ .v = 5, .loopy = true }, .{ .v = 3, .loopy = false } };
    const c = classifyParent(true, 5, &children);
    try testing.expectEqual(ParentClass.forced, c.class);
    try testing.expectEqual(@as(u16, 2), c.n_optimal);
    try testing.expectEqual(@as(u16, 2), c.n_loopy_optimal);
    try testing.expectEqual(@as(u16, 2), c.n_loopy_children);
    try testing.expect(c.margin == null);
}

test "classifyParent: partial (Black)" {
    const children = [_]ChildInfo{ .{ .v = 5, .loopy = true }, .{ .v = 5, .loopy = false }, .{ .v = 3, .loopy = false } };
    const c = classifyParent(true, 5, &children);
    try testing.expectEqual(ParentClass.partial, c.class);
    try testing.expectEqual(@as(u16, 2), c.n_optimal);
    try testing.expectEqual(@as(u16, 1), c.n_loopy_optimal);
    try testing.expectEqual(@as(u16, 1), c.n_loopy_children);
    try testing.expect(c.margin == null);
}

test "classifyParent: no_loop_a (Black) with margin" {
    const children = [_]ChildInfo{ .{ .v = 5, .loopy = false }, .{ .v = 3, .loopy = true } };
    const c = classifyParent(true, 5, &children);
    try testing.expectEqual(ParentClass.no_loop_a, c.class);
    try testing.expectEqual(@as(u16, 1), c.n_optimal);
    try testing.expectEqual(@as(u16, 0), c.n_loopy_optimal);
    try testing.expectEqual(@as(u16, 1), c.n_loopy_children);
    try testing.expectEqual(@as(u16, 2), c.margin.?);
}

test "classifyParent: no_loop_b (Black) — no loopy children at all" {
    const children = [_]ChildInfo{ .{ .v = 5, .loopy = false }, .{ .v = 4, .loopy = false }, .{ .v = 3, .loopy = false } };
    const c = classifyParent(true, 5, &children);
    try testing.expectEqual(ParentClass.no_loop_b, c.class);
    try testing.expectEqual(@as(u16, 1), c.n_optimal);
    try testing.expectEqual(@as(u16, 0), c.n_loopy_optimal);
    try testing.expectEqual(@as(u16, 0), c.n_loopy_children);
    try testing.expect(c.margin == null);
}

test "classifyParent: no_loop_a margin for White (minimizer)" {
    // White minimises: best_v = 1; the loopy child at v=3 is 2 worse.
    const children = [_]ChildInfo{ .{ .v = 1, .loopy = false }, .{ .v = 3, .loopy = true }, .{ .v = 5, .loopy = false } };
    const c = classifyParent(false, 1, &children);
    try testing.expectEqual(ParentClass.no_loop_a, c.class);
    try testing.expectEqual(@as(u16, 2), c.margin.?);
}

test "classifyParent: forced for White (minimizer)" {
    const children = [_]ChildInfo{ .{ .v = 3, .loopy = true }, .{ .v = 5, .loopy = false } };
    const c = classifyParent(false, 3, &children);
    try testing.expectEqual(ParentClass.forced, c.class);
    try testing.expectEqual(@as(u16, 1), c.n_optimal);
    try testing.expectEqual(@as(u16, 1), c.n_loopy_optimal);
}

test "classifyParent: no_optimal (no children)" {
    const c = classifyParent(true, 0, &.{});
    try testing.expectEqual(ParentClass.no_optimal, c.class);
    try testing.expectEqual(@as(u16, 0), c.n_optimal);
    try testing.expect(c.margin == null);
}

test "classifyParent: no_loop_a margin is always >= 1" {
    // A loopy child that ties best_v would be optimal — so in no_loop_a the
    // best loopy child must be strictly off the optimal value (margin >= 1).
    // best_v is derived as the argmax/argmin over children (the classifier's
    // precondition); an independent random best_v violates it.
    var prng = std.Random.DefaultPrng.init(99);
    const rng = prng.random();
    var buf: [8]ChildInfo = undefined;
    for (0..2000) |_| {
        const n = 1 + rng.uintLessThan(usize, 8);
        const maximizing = rng.boolean();
        const lo = rng.intRangeAtMost(i8, -9, 9);
        const hi = lo + @as(i8, @intCast(rng.uintLessThan(u8, 12)));
        var best_v: i8 = if (maximizing) -127 else 127;
        for (0..n) |i| {
            const v = rng.intRangeAtMost(i8, lo, hi);
            buf[i] = .{ .v = v, .loopy = rng.boolean() };
            if (maximizing) {
                if (buf[i].v > best_v) best_v = buf[i].v;
            } else {
                if (buf[i].v < best_v) best_v = buf[i].v;
            }
        }
        const c = classifyParent(maximizing, best_v, buf[0..n]);
        if (c.class == .no_loop_a) {
            try testing.expect(c.margin != null);
            try testing.expect(c.margin.? >= 1);
        }
    }
}

test "computeDepth: 3-cycle all-loopy — all perm/forced true" {
    const opt = [_][]const u32{ &.{ 1 }, &.{ 2 }, &.{ 0 } };
    const loopy = [_]bool{ true, true, true };
    const d = computeDepth(&opt, &loopy, 0);
    try testing.expect(d.perm1 and d.forced1);
    try testing.expect(d.perm2 and d.forced2);
    try testing.expect(d.perm3 and d.forced3);
}

test "computeDepth: forced1 at root but child has an optimal non-loopy child -> forced2 false, perm2 true" {
    // 0 -> [1] (1 loopy); 1 -> [2,3] (2 loopy, 3 not loopy)
    const opt = [_][]const u32{ &.{ 1 }, &.{ 2, 3 }, &.{}, &.{} };
    const loopy = [_]bool{ true, true, true, false };
    const d = computeDepth(&opt, &loopy, 0);
    try testing.expect(d.perm1 and d.forced1);
    try testing.expect(d.perm2);
    try testing.expect(!d.forced2);
    try testing.expect(!d.forced3);
}

test "computeDepth: leaf root — all false" {
    const opt = [_][]const u32{&.{}};
    const loopy = [_]bool{true};
    const d = computeDepth(&opt, &loopy, 0);
    try testing.expect(!d.perm1 and !d.forced1 and !d.perm2 and !d.forced2 and !d.perm3 and !d.forced3);
}

test "computeDepth: perm3 requires a 3-deep loopy chain" {
    // 0->[1] (1 loopy), 1->[2] (2 loopy), 2->[3] (3 loopy): three
    // consecutive optimal-loopy moves, each landing on a loopy state.
    const opt = [_][]const u32{ &.{ 1 }, &.{ 2 }, &.{ 3 }, &.{} };
    const loopy = [_]bool{ true, true, true, true };
    const d = computeDepth(&opt, &loopy, 0);
    try testing.expect(d.perm1 and d.perm2 and d.perm3);
    try testing.expect(d.forced1 and d.forced2 and d.forced3);
}

test "computeDepth: chain of 3 loopy moves with a non-loopy endpoint (perm3 false)" {
    // 0->[1] (loopy), 1->[2] (loopy), 2->[3] (NOT loopy): the third move
    // lands on a non-loopy state, so depth-3 permissive is false.
    const opt = [_][]const u32{ &.{ 1 }, &.{ 2 }, &.{ 3 }, &.{} };
    const loopy = [_]bool{ true, true, true, false };
    const d = computeDepth(&opt, &loopy, 0);
    try testing.expect(d.perm1 and d.perm2);
    try testing.expect(!d.perm3);
    try testing.expect(d.forced1 and d.forced2);
    try testing.expect(!d.forced3);
}

test "computeDepth: perm2 false when the move into the second state is not loopy" {
    // 0->[1] (1 loopy), 1->[2] (2 NOT loopy): the second move lands on a
    // non-loopy state, so depth-2 permissive is false.
    const opt = [_][]const u32{ &.{ 1 }, &.{ 2 }, &.{ 3 }, &.{} };
    const loopy = [_]bool{ true, true, false, true };
    const d = computeDepth(&opt, &loopy, 0);
    try testing.expect(d.perm1);
    try testing.expect(!d.perm2 and !d.perm3);
    try testing.expect(!d.forced2 and !d.forced3);
}

test "computeDepth: property — monotonicity and forced => perm on random graphs" {
    var prng = std.Random.DefaultPrng.init(1234);
    const rng = prng.random();
    var opt_storage: [4][4]u32 = undefined;
    for (0..500) |_| {
        const n: usize = 4;
        var opt: [4][]const u32 = undefined;
        for (0..n) |i| {
            var cnt: usize = 0;
            for (0..n) |j| {
                if (i != j and rng.boolean()) {
                    opt_storage[i][cnt] = @intCast(j);
                    cnt += 1;
                }
            }
            opt[i] = opt_storage[i][0..cnt];
        }
        var loopy: [4]bool = undefined;
        for (0..n) |i| loopy[i] = rng.boolean();
        const d = computeDepth(&opt, &loopy, 0);
        // monotone (as sets of roots): perm2 => perm1, perm3 => perm2;
        // forced2 => forced1, forced3 => forced2 (each deeper condition is
        // strictly stronger).
        try testing.expect(!d.perm2 or d.perm1);
        try testing.expect(!d.perm3 or d.perm2);
        try testing.expect(!d.forced2 or d.forced1);
        try testing.expect(!d.forced3 or d.forced2);
        // forced_k implies perm_k
        try testing.expect(!d.forced1 or d.perm1);
        try testing.expect(!d.forced2 or d.perm2);
        try testing.expect(!d.forced3 or d.perm3);
    }
}

test "computeDepth: a node on a forced cycle satisfies depth-3 forced (the T416 reconciliation shape)" {
    // Cycle 0->1->2->0 with a dangling non-optimal branch: every optimal
    // child stays on the cycle, every cycle node loopy.
    const opt = [_][]const u32{ &.{ 1 }, &.{ 2 }, &.{ 0 } };
    const loopy = [_]bool{ true, true, true };
    for (0..3) |r| {
        const d = computeDepth(&opt, &loopy, @intCast(r));
        try testing.expect(d.forced1 and d.forced2 and d.forced3);
        try testing.expect(d.perm1 and d.perm2 and d.perm3);
    }
}
