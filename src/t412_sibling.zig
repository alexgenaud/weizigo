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
// T412_SIBLING — the operator's SIBLING TEST (primary, 2026-08-07 amend
// D056): is a loopy move ever the BEST move among its siblings?  Plus the
// DTT table read (Q1b): the ply cap is already in the table.
//
// Task: T412 · Role: worker · Model: glm-5.2 · Date: 2026-08-07
//
// Q1 (sibling test).  For every non-terminal table position p (3x3
// exhaustive; 4x4 reservoir sample, denominator stated), enumerate its
// children (legal placements + pass), and:
//   - mark OPTIMAL children — those whose pinned value equals the Bellman
//     best over all children (argmax for Black to move, argmin for White;
//     scores Black-positive throughout).  The parent's stored pinned value
//     must equal this best (a tautology check, reported as the regression
//     guard).
//   - mark LOOPY children — child has L < H (the value-ambiguity marker;
//     defended in the doc).  A graph (on-a-cycle) criterion is NOT added:
//   the project already established SCC membership is near-vacuous (100%
//   of L<H in a non-trivial SCC, but so is 98.1% of L==H), so a graph
//   criterion would not materially change the picture and would re-derive
//   a settled result.
//   - DECISIVE COUNT: positions where EVERY optimal child is loopy.
//       0  -> at every position optimal play can avoid a loop; truncation
//             costs nothing (operator's no-problem case).
//       >0 -> those positions are witnesses: optimal play is FORCED into
//             a loop there; the ply cap conceals a real phenomenon.
//   - FINER DISTRIBUTION: per position, (# loopy optimal children) out of
//     (# optimal children).  One-of-one is far stronger than one-of-five.
//
//   Done under the TRUE table value.  The "no captures, only add stones"
//   quasi-rule has NO committed artifact (no .wzo2 with that rules_id
//   exists), so the side-by-side cannot be tested this row — stated, not
//   hidden.
//
// Q1b (dtt read).  Every WZO2 entry's 4th byte is DTT (distance-to-
// termination; 255 = DTT_FAR sentinel).  Over ALL entries (a byte scan):
//   - max DTT over L==H (decisive) entries per size — the smallest ply
//     cap that cannot truncate a resolvable game.
//   - DTT distribution for L<H entries; interpret (populated / sentinel /
//     meaningless).
//   3x3 and 4x4 have WZO2 artifacts; 4x3 has none (the T394 generic
//   fixpoint yields L/H but not DTT), so 4x3 DTT is unavailable — stated.
//
// Reads ONLY.  Compiles standalone:
//   zig build-exe -O ReleaseFast --dep version -Mroot=src/t412_sibling.zig \
//     -Mversion=src/version.zig --cache-dir /tmp/weizigo/t412/cache \
//     --global-cache-dir /tmp/weizigo/t412/global --name weizigo-t412-sib \
//     -femit-bin=/tmp/weizigo/t412/t412-sib
//
// Usage: weizigo-t412-sib --size 3|4 [--wzo2 <p>] [--sample <N>]
//          [--seed <N>] [--json <p>] [--seedctl force_loopy|null]
//          [--dtt-only] [--sibling-only]

const std = @import("std");
const version = @import("version");
const rules = @import("rules.zig");
const artifact2 = @import("artifact2.zig");
const colex = @import("colex.zig");
const util = @import("util.zig");

// ═══════════════════════════════════════════════════════════════════════════
//  HELPERS
// ═══════════════════════════════════════════════════════════════════════════

fn pinnedValue(L: i8, H: i8) i8 {
    return @max(L, @min(0, H));
}

// ═══════════════════════════════════════════════════════════════════════════
//  DTT READ — byte scan over ALL entries
// ═══════════════════════════════════════════════════════════════════════════

const DttResult = struct {
    total_entries: u64 = 0,
    n_lh: u64 = 0, // L < H (loopy/bracketed)
    n_eq: u64 = 0, // L == H (decisive)
    max_dtt_eq: u8 = 0, // max DTT over L==H entries
    n_eq_dtt_far: u64 = 0, // L==H entries with DTT==255 (should be 0)
    n_lh_dtt_far: u64 = 0, // L<H entries with DTT==255
    // DTT histograms (0..255), separate for L==H and L<H
    hist_eq: [256]u64 = .{0} ** 256,
    hist_lh: [256]u64 = .{0} ** 256,
    // terminal-bit breakdown
    n_terminal_bit: u64 = 0,
    n_eq_terminal: u64 = 0,
};

fn dttRead(a2: *const artifact2.LoadedArtifact) DttResult {
    var r = DttResult{};
    const G: usize = @intCast(a2.header.n_groups);
    const groups = a2.data[a2.group_base .. a2.group_base + G * artifact2.GROUP_HEADER_SIZE];
    var cum: u64 = 0;
    for (0..G) |g| {
        const count: usize = groups[g * artifact2.GROUP_HEADER_SIZE + 4];
        const entry_off = a2.entry_base + cum * artifact2.ENTRY_SIZE;
        for (0..count) |ei| {
            const eb = a2.data[entry_off + ei * artifact2.ENTRY_SIZE ..][0..artifact2.ENTRY_SIZE];
            const kb = eb[0];
            const L: i8 = @bitCast(eb[1]);
            const H: i8 = @bitCast(eb[2]);
            const dtt = eb[3];
            const decoded = artifact2.decodeKeyByte(kb, a2.header.ko_bits);
            r.total_entries += 1;
            if (decoded.terminal != 0) r.n_terminal_bit += 1;
            if (L < H) {
                r.n_lh += 1;
                r.hist_lh[dtt] += 1;
                if (dtt == artifact2.DTT_FAR) r.n_lh_dtt_far += 1;
            } else {
                r.n_eq += 1;
                r.hist_eq[dtt] += 1;
                if (dtt > r.max_dtt_eq) r.max_dtt_eq = dtt;
                if (dtt == artifact2.DTT_FAR) r.n_eq_dtt_far += 1;
                if (decoded.terminal != 0) r.n_eq_terminal += 1;
            }
        }
        cum += count;
    }
    return r;
}

// ═══════════════════════════════════════════════════════════════════════════
//  SIBLING TEST
// ═══════════════════════════════════════════════════════════════════════════

const NTParent = struct {
    colex: u32,
    side: i8,
    ko: u8,
    passes: u8,
    L: i8,
    H: i8,
    terminal: u1,
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
                .terminal = decoded.terminal,
            });
        }
        cum += count;
    }
    return results.toOwnedSlice(gpa);
}

const SibAgg = struct {
    n_parents: usize = 0,
    tautology_checks: usize = 0,
    tautology_mismatches: usize = 0, // V_p != Bellman-best (regression guard)
    forced_loop: usize = 0, // every optimal child is loopy
    partial_loop: usize = 0, // some but not all optimal children are loopy
    no_loop_optimal: usize = 0, // no optimal child is loopy
    no_optimal: usize = 0, // position has no classifiable children (all no-entry)
    // finer distribution: positions by (loopy_optimal, optimal) bucketed.
    // We record a compact histogram: bucket = loopy_optimal * 100 + optimal
    // (capped), and a special focus on (1,1).
    one_of_one: usize = 0, // exactly 1 optimal child, it is loopy
    all_loopy_k: usize = 0, // k>=2 optimal, all loopy
    // children stats
    total_optimal_children: u64 = 0,
    total_loopy_optimal_children: u64 = 0,
};

const Witness = struct {
    colex: u32,
    side: i8,
    ko: u8,
    passes: u8,
    L: i8,
    H: i8,
    n_optimal: u8,
    n_loopy_optimal: u8,
    board: [16]i8,
    board_len: u8,
};

fn runSibling(
    comptime w: comptime_int,
    comptime h: comptime_int,
    a2: *const artifact2.LoadedArtifact,
    parents: []NTParent,
    force_loopy: bool, // seeded control: treat EVERY child as loopy
    witnesses: *std.ArrayListUnmanaged(Witness),
    gpa: std.mem.Allocator,
) SibAgg {
    const R = rules.Rules(w, h);
    const X = colex.Indexer(w, h);
    const n = w * h;
    const KO_NONE: u8 = n;
    var agg = SibAgg{};
    agg.n_parents = parents.len;

    for (parents) |p| {
        const pos = X.pos_from_colex(p.colex);
        const maximizing = p.side > 0;
        const V_p = pinnedValue(p.L, p.H);

        // enumerate children
        var best_v: i8 = if (maximizing) -127 else 127;
        var any_child: bool = false;
        // first pass: compute Bellman best over children
        // placements
        for (0..n) |cell| {
            if (pos[cell] != 0) continue;
            if (p.ko < KO_NONE and cell == p.ko) continue;
            const child = R.pos_from_move(&pos, p.side, cell) catch continue;
            const child_ko = rules.koAfterCapture(&pos, &child, p.side, w, h, KO_NONE);
            const child_colex: u32 = @intCast(X.colex_from_pos(&child));
            const v: i8 = if (artifact2.lookup(a2, child_colex, -p.side, child_ko, 0)) |row| pinnedValue(row.L, row.H) else R.area_score(&child);
            any_child = true;
            if (maximizing) { if (v > best_v) best_v = v; } else { if (v < best_v) best_v = v; }
        }
        // pass child
        const pass_v: i8 = blk: {
            if (p.passes >= 1) break :blk R.area_score(&pos);
            if (artifact2.lookup(a2, p.colex, -p.side, KO_NONE, @intCast(p.passes + 1))) |row| break :blk pinnedValue(row.L, row.H);
            break :blk R.area_score(&pos);
        };
        {
            any_child = true;
            if (maximizing) { if (pass_v > best_v) best_v = pass_v; } else { if (pass_v < best_v) best_v = pass_v; }
        }

        // tautology: V_p must equal best_v (the table is a fixpoint)
        agg.tautology_checks += 1;
        if (V_p != best_v) agg.tautology_mismatches += 1;

        // second pass: count optimal & loopy-optimal children
        var n_optimal: u16 = 0;
        var n_loopy_optimal: u16 = 0;
        for (0..n) |cell| {
            if (pos[cell] != 0) continue;
            if (p.ko < KO_NONE and cell == p.ko) continue;
            const child = R.pos_from_move(&pos, p.side, cell) catch continue;
            const child_ko = rules.koAfterCapture(&pos, &child, p.side, w, h, KO_NONE);
            const child_colex: u32 = @intCast(X.colex_from_pos(&child));
            const has, const Lc: i8, const Hc: i8 = if (artifact2.lookup(a2, child_colex, -p.side, child_ko, 0)) |row| .{ true, row.L, row.H } else .{ false, R.area_score(&child), R.area_score(&child) };
            const vc = pinnedValue(Lc, Hc);
            const is_optimal = (vc == best_v);
            const is_loopy = if (force_loopy) true else (has and Lc < Hc);
            if (is_optimal) {
                n_optimal += 1;
                if (is_loopy) n_loopy_optimal += 1;
            }
        }
        // pass child optimal?
        {
            const is_optimal_p = (pass_v == best_v);
            // pass child loopy? pass child value comes from a table entry
            // (passes+1) or is terminal area_score (loopy=false). For the
            // seeded force_loopy control we also force pass loopy.
            var is_loopy_p: bool = false;
            if (p.passes < 1) {
                if (artifact2.lookup(a2, p.colex, -p.side, KO_NONE, @intCast(p.passes + 1))) |row| {
                    is_loopy_p = if (force_loopy) true else (row.L < row.H);
                }
            } else {
                is_loopy_p = if (force_loopy) true else false;
            }
            if (is_optimal_p) {
                n_optimal += 1;
                if (is_loopy_p) n_loopy_optimal += 1;
            }
        }

        agg.total_optimal_children += n_optimal;
        agg.total_loopy_optimal_children += n_loopy_optimal;

        if (n_optimal == 0) {
            agg.no_optimal += 1;
            continue;
        }
        if (n_loopy_optimal == n_optimal) {
            agg.forced_loop += 1;
            if (n_optimal == 1) agg.one_of_one += 1 else agg.all_loopy_k += 1;
            if (witnesses.items.len < 8) {
                var b: [16]i8 = .{0} ** 16;
                for (0..n) |i| b[i] = pos[i];
                witnesses.append(gpa, .{
                    .colex = p.colex,
                    .side = p.side,
                    .ko = p.ko,
                    .passes = p.passes,
                    .L = p.L,
                    .H = p.H,
                    .n_optimal = @intCast(n_optimal),
                    .n_loopy_optimal = @intCast(n_loopy_optimal),
                    .board = b,
                    .board_len = @intCast(n),
                }) catch {};
            }
        } else if (n_loopy_optimal > 0) {
            agg.partial_loop += 1;
        } else {
            agg.no_loop_optimal += 1;
        }
    }
    return agg;
}

// ═══════════════════════════════════════════════════════════════════════════
//  JSON
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

fn pct(numv: u64, den: u64) f64 {
    if (den == 0) return 0;
    return 100.0 * @as(f64, @floatFromInt(numv)) / @as(f64, @floatFromInt(den));
}

// ═══════════════════════════════════════════════════════════════════════════
//  DRIVER
// ═══════════════════════════════════════════════════════════════════════════

fn runSize(
    comptime w: comptime_int,
    comptime h: comptime_int,
    io: std.Io,
    gpa: std.mem.Allocator,
    wzo2_path: []const u8,
    sample_n: ?usize,
    seed: u64,
    json_path: []const u8,
    seedctl_force_loopy: bool,
    dtt_only: bool,
    sibling_only: bool,
) !void {
    var a2 = try artifact2.load(io, std.Io.Dir.cwd(), wzo2_path, gpa);
    defer a2.deinit();

    var j = Json.init(gpa);
    defer j.deinit();
    try j.raw("{\n");
    try j.raw("  \"task_id\": \"T412\",");
    try j.raw(" \"instrument\": \"t412_sibling\",");
    try j.raw(" \"size\": \""); try j.num(w); try j.raw("x"); try j.num(h); try j.raw("\",\n");
    try j.raw("  \"wzo2_path\": "); try j.str(wzo2_path); try j.comma();
    try j.raw(" \"seed\": "); try j.num(seed); try j.comma();
    try j.raw(" \"seedctl\": "); try j.str(if (seedctl_force_loopy) "force_loopy" else "none"); try j.comma();
    if (sample_n) |sn| { try j.raw(" \"sample\": "); try j.num(sn); try j.comma(); }
    try j.raw("\n");

    // ── Q1b: DTT read ────────────────────────────────────────────────────
    if (!sibling_only) {
        const dr = dttRead(&a2);
        util.out("[T412-DTT] size={d}x{d} wzo2={s}\n", .{ w, h, wzo2_path });
        util.out("  total entries: {d}\n", .{dr.total_entries});
        util.out("  L==H (decisive):   {d}   L<H (loopy): {d}\n", .{ dr.n_eq, dr.n_lh });
        util.out("  max DTT over L==H entries: {d}   (DTT_FAR sentinel = {d})\n", .{ dr.max_dtt_eq, artifact2.DTT_FAR });
        util.out("  L==H entries with DTT==FAR: {d}   (should be 0)\n", .{dr.n_eq_dtt_far});
        util.out("  L<H entries with DTT==FAR: {d} / {d}  ({d:.2}%)\n", .{ dr.n_lh_dtt_far, dr.n_lh, pct(dr.n_lh_dtt_far, dr.n_lh) });
        util.out("  terminal-bit entries: {d}  (of which L==H: {d})\n", .{ dr.n_terminal_bit, dr.n_eq_terminal });
        // DTT distribution for L==H (compact: nonzero buckets)
        util.out("  DTT histogram (L==H), nonzero buckets:\n", .{});
        for (0..256) |d| {
            if (dr.hist_eq[d] > 0) {
                util.out("    dtt={d}: {d}\n", .{ d, dr.hist_eq[d] });
            }
        }
        util.out("  DTT histogram (L<H), nonzero buckets:\n", .{});
        for (0..256) |d| {
            if (dr.hist_lh[d] > 0) util.out("    dtt={d}: {d}\n", .{ d, dr.hist_lh[d] });
        }

        try j.raw("  \"dtt\": {\n");
        try j.raw("    \"total_entries\": "); try j.num(dr.total_entries); try j.comma();
        try j.raw(" \"n_eq\": "); try j.num(dr.n_eq); try j.comma();
        try j.raw(" \"n_lh\": "); try j.num(dr.n_lh); try j.comma();
        try j.raw(" \"max_dtt_eq\": "); try j.num(dr.max_dtt_eq); try j.comma();
        try j.raw(" \"DTT_FAR\": "); try j.num(artifact2.DTT_FAR); try j.comma();
        try j.raw(" \"n_eq_dtt_far\": "); try j.num(dr.n_eq_dtt_far); try j.comma();
        try j.raw(" \"n_lh_dtt_far\": "); try j.num(dr.n_lh_dtt_far); try j.comma();
        try j.raw(" \"n_terminal_bit\": "); try j.num(dr.n_terminal_bit); try j.comma();
        try j.raw(" \"n_eq_terminal\": "); try j.num(dr.n_eq_terminal); try j.comma();
        try j.raw(" \"hist_eq\": ["); for (0..256) |d| { if (d > 0) try j.comma(); try j.num(dr.hist_eq[d]); } try j.raw("],");
        try j.raw(" \"hist_lh\": ["); for (0..256) |d| { if (d > 0) try j.comma(); try j.num(dr.hist_lh[d]); } try j.raw("]\n");
        try j.raw("  }");
    }

    // ── Q1: sibling test ────────────────────────────────────────────────
    if (!dtt_only) {
        if (!sibling_only) try j.comma();
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
            util.note("[T412SIB] {d}x{d} sampled {d}/{d} non-terminal positions (seed={d})\n", .{ w, h, sn, all_parents.len, seed });
        } else {
            util.note("[T412SIB] {d}x{d} exhaustive {d} non-terminal positions\n", .{ w, h, all_parents.len });
        }
        defer if (sampled_buf) |sb| gpa.free(sb);

        var witnesses: std.ArrayListUnmanaged(Witness) = .empty;
        defer witnesses.deinit(gpa);
        const agg = runSibling(w, h, &a2, parents, seedctl_force_loopy, &witnesses, gpa);

        util.out("[T412-SIB] size={d}x{d} seedctl={s}\n", .{ w, h, if (seedctl_force_loopy) "force_loopy" else "none" });
        if (sample_n != null) util.out("  sample: {d}/{d} non-terminal positions\n", .{ sample_n.?, all_parents.len });
        util.out("  parents: {d}\n", .{agg.n_parents});
        util.out("  tautology V_p==Bellman-best: {d} checks, {d} mismatches  (regression guard)\n", .{ agg.tautology_checks, agg.tautology_mismatches });
        util.out("  --- DECISIVE COUNT (denominator: parents with >=1 classifiable optimal child = {d}) ---\n", .{agg.n_parents - agg.no_optimal});
        util.out("  FORCED-LOOP (every optimal child loopy): {d}  ({d:.4}%)   <- headline\n", .{ agg.forced_loop, pct(agg.forced_loop, agg.n_parents) });
        util.out("    of which one-of-one: {d}    all-loopy k>=2: {d}\n", .{ agg.one_of_one, agg.all_loopy_k });
        util.out("  partial (some optimal loopy): {d}\n", .{agg.partial_loop});
        util.out("  no-loop (no optimal loopy):   {d}\n", .{agg.no_loop_optimal});
        util.out("  no-optimal (all children no-entry): {d}\n", .{agg.no_optimal});
        util.out("  children: total_optimal={d}  total_loopy_optimal={d}  ({d:.4}% of optimal are loopy)\n", .{ agg.total_optimal_children, agg.total_loopy_optimal_children, pct(agg.total_loopy_optimal_children, agg.total_optimal_children) });
        if (witnesses.items.len > 0) {
            util.out("  witnesses (forced-loop positions, up to 8):\n", .{});
            for (witnesses.items) |wi| {
                util.out("    colex={d} side={d} ko={d} passes={d} L={d} H={d} optimal={d}/{d} loopy\n", .{ wi.colex, wi.side, wi.ko, wi.passes, wi.L, wi.H, wi.n_loopy_optimal, wi.n_optimal });
            }
        }

        try j.raw("  \"sibling\": {\n");
        try j.raw("    \"n_parents_total\": "); try j.num(all_parents.len); try j.comma();
        if (sample_n) |sn| { try j.raw(" \"sample\": "); try j.num(sn); try j.comma(); }
        try j.raw(" \"n_parents\": "); try j.num(agg.n_parents); try j.comma();
        try j.raw(" \"tautology_checks\": "); try j.num(agg.tautology_checks); try j.comma();
        try j.raw(" \"tautology_mismatches\": "); try j.num(agg.tautology_mismatches); try j.comma();
        try j.raw(" \"forced_loop\": "); try j.num(agg.forced_loop); try j.comma();
        try j.raw(" \"one_of_one\": "); try j.num(agg.one_of_one); try j.comma();
        try j.raw(" \"all_loopy_k\": "); try j.num(agg.all_loopy_k); try j.comma();
        try j.raw(" \"partial_loop\": "); try j.num(agg.partial_loop); try j.comma();
        try j.raw(" \"no_loop_optimal\": "); try j.num(agg.no_loop_optimal); try j.comma();
        try j.raw(" \"no_optimal\": "); try j.num(agg.no_optimal); try j.comma();
        try j.raw(" \"total_optimal_children\": "); try j.num(agg.total_optimal_children); try j.comma();
        try j.raw(" \"total_loopy_optimal_children\": "); try j.num(agg.total_loopy_optimal_children); try j.comma();
        try j.raw(" \"witnesses\": [");
        for (witnesses.items, 0..) |wi, i| {
            if (i > 0) try j.comma();
            try j.raw("\n      {");
            try j.raw("\"colex\":"); try j.num(wi.colex); try j.comma();
            try j.raw("\"side\":"); try j.num(wi.side); try j.comma();
            try j.raw("\"ko\":"); try j.num(wi.ko); try j.comma();
            try j.raw("\"passes\":"); try j.num(wi.passes); try j.comma();
            try j.raw("\"L\":"); try j.num(wi.L); try j.comma();
            try j.raw("\"H\":"); try j.num(wi.H); try j.comma();
            try j.raw("\"n_optimal\":"); try j.num(wi.n_optimal); try j.comma();
            try j.raw("\"n_loopy_optimal\":"); try j.num(wi.n_loopy_optimal); try j.comma();
            try j.raw("\"board\":[");
            for (0..wi.board_len) |bi| { if (bi > 0) try j.comma(); try j.num(wi.board[bi]); }
            try j.raw("]}");
        }
        try j.raw("\n    ]\n");
        try j.raw("  }");
    }

    try j.raw("\n}\n");
    if (json_path.len > 0) {
        std.Io.Dir.cwd().writeFile(io, .{ .sub_path = json_path, .data = j.buf.items }) catch |err| {
            util.warn("[T412SIB] failed to write json {s}: {s}\n", .{ json_path, @errorName(err) });
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
    var opt_force_loopy: bool = false;
    var opt_dtt_only: bool = false;
    var opt_sib_only: bool = false;

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
            if (std.mem.eql(u8, v, "force_loopy")) opt_force_loopy = true else if (std.mem.eql(u8, v, "null")) opt_force_loopy = false else return error.InvalidArgument;
        } else if (std.mem.eql(u8, arg, "--dtt-only")) {
            opt_dtt_only = true;
        } else if (std.mem.eql(u8, arg, "--sibling-only")) {
            opt_sib_only = true;
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
            3 => "findings/T412-sibling-3x3.json",
            4 => "findings/T412-sibling-4x4.json",
            else => return error.InvalidSize,
        };
    }
    if (size == 4 and opt_sample == null and !opt_dtt_only) opt_sample = 200000;

    switch (size) {
        3 => try runSize(3, 3, io, gpa, opt_wzo2, opt_sample, opt_seed, opt_json, opt_force_loopy, opt_dtt_only, opt_sib_only),
        4 => try runSize(4, 4, io, gpa, opt_wzo2, opt_sample, opt_seed, opt_json, opt_force_loopy, opt_dtt_only, opt_sib_only),
        else => return error.InvalidSize,
    }
}