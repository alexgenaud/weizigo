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
// T382 — goban-pathology census instrument (deepseek-v4-flash/T382).
//
// Census only: reads committed artifacts, computes the five named pathology
// components per solved size (2×2, 3×2, 3×3, 4×3, 4×4). No solving, no
// re-derivation, no fixes. Additive instrument; no build.zig / engine edits.
//
// Components (definitions and provenance in
// docs/research/goban-pathology-2026-08-05.md):
//
//   1. full-kill frequency  — positions where one colour has ZERO stones on
//      the goban; and, per non-settled slot, whether a full-kill move exists
//      and whether one is optimal (a full-kill child's stored value == the
//      stored fresh-start value).
//   2. ko density           — KO_SENSITIVE (L<H) slot fraction, and the
//      independent-ko-count distribution (B23-style static ko shapes).
//   3. pass-optimality      — per non-settled slot, whether the pass edge
//      (V1(P,-side): best reply over the opponent's children ∪ area) equals
//      the stored V0 value, i.e. passing is an optimal move.
//   4. cycle reachability   — Tarjan SCCs over the full (pos, side, ko,
//      passes∈{0,1}) move graph (R8 legalMoves/applyMove/applyPass), plus the
//      root-reachable subgraph; whether any non-trivial SCC exists and the
//      cycle-reachable fraction (I5's notion).
//   5. history dependence   — NOT re-solved here (committed measurements:
//      2×2 = 0, 3×2 = 30.3% are cited in the report). This instrument
//      supplies the two structural bounds: the cycle-reachability of L==H
//      slots (channel 1) and the pending-ko potential (channel 2: a cell
//      where the side to move holds a basic-ko recapture ban a fresh-start
//      solve would not know about).
//
// Modes:
//   --selftest                   calibration suite (run BEFORE any reading)
//   --slot      <artifact.wzo>   components 1 / 2(flag) / 3 / pending-ko
//   --kocount   <artifact.wzo>   component 2 (independent ko shapes, B23)
//   --cycles    <artifact.wzo>   component 4 (2×2 / 3×2 / 3×3 only)
//   --wzo2      <file.wzo2>      WZO2 census: entries, L<H, key split
//
// Calibration (per brief: null and seeded controls before a counter's first
// reading counts) — exercised by --selftest:
//   * Tarjan on a hand-built graph (one 2-cycle) — known-good for the SCC
//     machinery;
//   * the 1×1 null artifact (1 legal position, zero moves, zero flags);
//   * ko-shape detector on hand-built 2×2 and 4×4 positions — known-good,
//     and a seeded second pocket (independent clusters must be 2);
//   * flag-flip seeded defect — KO_SENS count moves by exactly 1;
//   * value-perturbation seeded defect — pass-optimality comparison cannot
//     match a perturbed (impossible) stored value;
//   * committed cross-checks on real artifacts: 2×2 legal = 57 (OEIS
//     A094777), 2×2 no non-trivial SCC (T12), 3×2 non-trivial SCC exists
//     (T363), 3×3 ko-count distribution = B23, 4×4 non-settled KO_SENS =
//     10,367,922 (chainability), 4×4 WZO2 KO_SENS = 3,455,412 (I5).
//
// Build: tools/runner -- zig build-exe -O ReleaseFast src/t382_census.zig \
//          --name weizigo-t382-census

const std = @import("std");
const util = @import("util.zig");
const artifact = @import("artifact.zig");
const colex = @import("colex.zig");
const rules = @import("rules.zig");

const UNDEF: i8 = -128;
const KO_SENS: u8 = 1;

// ═════════════════════════════════════════════════════════════════════════
//  shared helpers
// ═════════════════════════════════════════════════════════════════════════

fn asPct(part: u64, total: u64) f64 {
    if (total == 0) return 0.0;
    return @as(f64, @floatFromInt(part)) * 100.0 / @as(f64, @floatFromInt(total));
}

fn stoneCounts(comptime R: type, pos: *const R.Pos) struct { b: u8, w: u8 } {
    var b: u8 = 0;
    var w: u8 = 0;
    for (pos) |c| {
        if (c > 0) b += 1 else if (c < 0) w += 1;
    }
    return .{ .b = b, .w = w };
}

/// Is `side` holding a basic-ko recapture ban at this position? I.e. does a
/// cell exist where `-side` has a stone whose ONLY liberty is an empty cell,
/// with no friendly (-side) neighbour — the shape a previous ko capture
/// (koAfterCapture) would have left, banning `side` from that cell. Static
/// shape-level pending-ko potential for the side to move.
fn hasPendingKoBan(comptime R: type, pos: *const R.Pos, side: i8) bool {
    for (0..R.n) |p| {
        if (pos[p] != -side) continue;
        var nb: [4]usize = undefined;
        const cnt = R.neighbors(p, &nb);
        var libs: u8 = 0;
        var friendly: u8 = 0;
        for (nb[0..cnt]) |q| {
            if (pos[q] == 0) libs += 1;
            if (pos[q] == -side) friendly += 1;
        }
        if (libs == 1 and friendly == 0) return true;
    }
    return false;
}

const KoPoint = struct { cell: u8, cap: u8 };

/// Detect whether placing `colour` at `p` is a basic ko capture (B23
/// definition): captures exactly one opponent stone and the placed stone ends
/// with exactly one liberty. Returns the captured cell, or null.
fn isKoCapture(comptime R: type, pos: *const R.Pos, p: usize, colour: i8) ?usize {
    if (pos[p] != 0) return null;
    const next = R.pos_from_move(pos, colour, p) catch return null;
    var opp_before: u8 = 0;
    var opp_after: u8 = 0;
    var captured_cell: ?usize = null;
    for (0..R.n) |i| {
        if (pos[i] == -colour) opp_before += 1;
        if (next[i] == -colour) opp_after += 1;
        if (pos[i] == -colour and next[i] == 0) captured_cell = i;
    }
    if (opp_before - opp_after != 1) return null;
    var liberties: u8 = 0;
    var nb: [4]usize = undefined;
    const cnt = R.neighbors(p, &nb);
    for (nb[0..cnt]) |q| {
        if (next[q] == 0) liberties += 1;
    }
    if (liberties != 1) return null;
    return captured_cell;
}

/// Count independent ko clusters among ko points (B23 union-find, from
/// src/ko_census.zig: two ko points are dependent if their 1-neighbourhoods
/// intersect).
fn countIndependentClusters(comptime R: type, ko_points: []const KoPoint) u8 {
    if (ko_points.len == 0) return 0;
    var masks: [32]u32 = undefined;
    for (ko_points, 0..) |kp, i| {
        var mask: u32 = 0;
        mask |= @as(u32, 1) << @intCast(kp.cell);
        mask |= @as(u32, 1) << @intCast(kp.cap);
        var nb: [4]usize = undefined;
        const cnt = R.neighbors(kp.cell, &nb);
        for (nb[0..cnt]) |q| mask |= @as(u32, 1) << @intCast(q);
        const cnt2 = R.neighbors(kp.cap, &nb);
        for (nb[0..cnt2]) |q| mask |= @as(u32, 1) << @intCast(q);
        masks[i] = mask;
    }
    var parent: [32]u8 = undefined;
    for (0..ko_points.len) |i| parent[i] = @intCast(i);
    for (0..ko_points.len) |i| {
        for (i + 1..ko_points.len) |j| {
            if (masks[i] & masks[j] != 0) {
                var ri: u8 = @intCast(i);
                while (parent[ri] != ri) {
                    parent[ri] = parent[parent[ri]];
                    ri = parent[ri];
                }
                var rj: u8 = @intCast(j);
                while (parent[rj] != rj) {
                    parent[rj] = parent[parent[rj]];
                    rj = parent[rj];
                }
                if (ri != rj) parent[ri] = rj;
            }
        }
    }
    var roots: u32 = 0;
    for (0..ko_points.len) |i| {
        var r: u8 = @intCast(i);
        while (parent[r] != r) {
            parent[r] = parent[parent[r]];
            r = parent[r];
        }
        roots |= @as(u32, 1) << @intCast(r);
    }
    return @popCount(roots);
}

fn findAllKoPoints(comptime R: type, pos: *const R.Pos, list: *std.ArrayListUnmanaged(KoPoint), gpa: std.mem.Allocator) !void {
    for (0..R.n) |p| {
        inline for (.{ @as(i8, 1), @as(i8, -1) }) |colour| {
            if (isKoCapture(R, pos, p, colour)) |cap| {
                try list.append(gpa, .{ .cell = @intCast(p), .cap = @intCast(cap) });
            }
        }
    }
}

// ═════════════════════════════════════════════════════════════════════════
//  Mode: --slot   (components 1, 2-flag, 3, pending-ko potential)
// ═════════════════════════════════════════════════════════════════════════

fn SlotSweep(comptime w: usize, comptime h: usize) type {
    return struct {
        const R = rules.Rules(w, h);
        const X = colex.Indexer(w, h);
        const n = R.n;
        const Pos = R.Pos;

        fn childV(d: *const artifact.Decoded, ch: *const Pos, side: i8) i8 {
            const i: usize = @intCast(X.colex_from_pos(ch));
            return if (side > 0) d.vb[i] else d.vw[i];
        }
        fn childFlag(d: *const artifact.Decoded, ch: *const Pos, side: i8) u8 {
            const i: usize = @intCast(X.colex_from_pos(ch));
            return if (side > 0) d.fb[i] else d.fw[i];
        }

        /// V1(P, side) — value after one pass: best over `side`'s children
        /// (V0(child, -side)) ∪ area_score(P) — computed in the same scan as
        /// the full-kill information for the side's slot:
        ///   has_fk      — some legal move eliminates the opponent entirely
        ///   best_fk_v   — best full-kill child value (max for B, min for W)
        ///   n_fk        — number of full-kill children
        ///   fk_ks       — of those, how many are KO_SENSITIVE-flagged
        const Scan = struct {
            v1: i8,
            has_fk: bool,
            best_fk_v: i8,
            n_fk: u32,
            fk_ks: u32,
        };

        fn scanSide(d: *const artifact.Decoded, pos: *const Pos, side: i8) Scan {
            const maxing = side > 0;
            var best: i8 = R.area_score(pos);
            var has_fk = false;
            var best_fk_v: i8 = if (maxing) std.math.minInt(i8) else std.math.maxInt(i8);
            var n_fk: u32 = 0;
            var fk_ks: u32 = 0;
            for (0..n) |c| {
                if (pos[c] != 0) continue;
                const ch = R.pos_from_move(pos, side, c) catch continue;
                const v = childV(d, &ch, -side);
                if (v == UNDEF) continue;
                if (if (maxing) v > best else v < best) best = v;
                const sc = stoneCounts(R, &ch);
                const opp_zero = if (side > 0) sc.w == 0 else sc.b == 0;
                if (opp_zero) {
                    n_fk += 1;
                    if (childFlag(d, &ch, -side) & KO_SENS != 0) fk_ks += 1;
                    if (if (maxing) v > best_fk_v else v < best_fk_v) best_fk_v = v;
                    has_fk = true;
                }
            }
            return .{ .v1 = best, .has_fk = has_fk, .best_fk_v = best_fk_v, .n_fk = n_fk, .fk_ks = fk_ks };
        }

        /// Does a colour have any Benson-alive stone?
        fn anyAlive(pos: *const Pos, colour: i8) bool {
            const al = R.benson_alive(pos, colour);
            for (0..n) |q| {
                if (al[q] and pos[q] == colour) return true;
            }
            return false;
        }

        pub fn run(d: *const artifact.Decoded, gpa: std.mem.Allocator) !void {
            _ = gpa;
            var legal: u64 = 0;
            var settled_n: u64 = 0;
            var fk_positions: u64 = 0; // legal positions with a zero-stone colour
            var fk_positions_alive: u64 = 0; // positions with a zero-ALIVE colour
            var empty_board_pos: u64 = 0;

            var slots_non_settled: u64 = 0;
            var slots_lh: u64 = 0;
            var slots_ks: u64 = 0;
            var settled_ko: u64 = 0;

            var pass_opt: u64 = 0;
            var pass_opt_lh: u64 = 0;
            var pass_opt_ks: u64 = 0;

            var fk_slots: u64 = 0;
            var fk_opt: u64 = 0;
            var fk_slots_lh: u64 = 0;
            var fk_opt_lh: u64 = 0;
            var fk_slots_ks: u64 = 0;
            var fk_opt_ks: u64 = 0;
            var fk_child_total: u64 = 0;
            var fk_child_ks_total: u64 = 0;

            var pend_ko_slots: u64 = 0;
            var pend_ko_lh: u64 = 0;

            var i: u64 = 0;
            while (i < X.total) : (i += 1) {
                const idx: usize = @intCast(i);
                if (d.vb[idx] == UNDEF and d.vw[idx] == UNDEF) continue;
                legal += 1;
                const pos = X.pos_from_colex(i);

                const sc = stoneCounts(R, &pos);
                if (sc.b == 0 or sc.w == 0) {
                    fk_positions += 1;
                    if (sc.b == 0 and sc.w == 0) empty_board_pos += 1;
                }
                if (!anyAlive(&pos, 1) or !anyAlive(&pos, -1)) fk_positions_alive += 1;

                if (R.is_settled(&pos)) {
                    settled_n += 1;
                    settled_ko += @intFromBool(d.fb[idx] & KO_SENS != 0) + @intFromBool(d.fw[idx] & KO_SENS != 0);
                    continue;
                }

                const scan_b = scanSide(d, &pos, 1);
                const scan_w = scanSide(d, &pos, -1);

                for ([_]i8{ 1, -1 }) |side| {
                    const stored = if (side > 0) d.vb[idx] else d.vw[idx];
                    if (stored == UNDEF) continue;
                    const fl = if (side > 0) d.fb[idx] else d.fw[idx];
                    slots_non_settled += 1;
                    const ko_slot = fl & KO_SENS != 0;
                    if (ko_slot) slots_ks += 1 else slots_lh += 1;

                    // pass edge: V1(P, -side)
                    const pv = if (side > 0) scan_w.v1 else scan_b.v1;
                    if (pv == stored) {
                        pass_opt += 1;
                        if (ko_slot) pass_opt_ks += 1 else pass_opt_lh += 1;
                    }

                    // full-kill
                    const s = if (side > 0) scan_b else scan_w;
                    if (s.has_fk) {
                        fk_slots += 1;
                        fk_child_total += s.n_fk;
                        fk_child_ks_total += s.fk_ks;
                        const opt = s.best_fk_v == stored;
                        if (opt) fk_opt += 1;
                        if (ko_slot) {
                            fk_slots_ks += 1;
                            if (opt) fk_opt_ks += 1;
                        } else {
                            fk_slots_lh += 1;
                            if (opt) fk_opt_lh += 1;
                        }
                    }

                    // pending-ko potential (channel-2 structural bound for H_DEP)
                    if (hasPendingKoBan(R, &pos, side)) {
                        pend_ko_slots += 1;
                        if (!ko_slot) pend_ko_lh += 1;
                    }
                }
            }

            util.out("== slot census {d}x{d}  artifact legal_count={d}\n", .{ w, h, d.header.legal_count });
            util.out("legal positions        {d}\n", .{legal});
            util.out("settled positions      {d}  (of which slots KO_SENSITIVE-flagged: {d})\n", .{ settled_n, settled_ko });
            util.out("full-kill positions (a colour at zero stones): {d}  ({d:.4}% of legal)\n", .{ fk_positions, asPct(fk_positions, legal) });
            util.out("  ... both colours zero (empty goban): {d}\n", .{empty_board_pos});
            util.out("positions with a colour at zero BENSON-alive stones: {d}  ({d:.4}% of legal)\n", .{ fk_positions_alive, asPct(fk_positions_alive, legal) });
            util.out("non-settled slots      {d}  (L==H {d}, KO_SENS {d})\n", .{ slots_non_settled, slots_lh, slots_ks });
            util.out("KO_SENS fraction over non-settled slots: {d:.4}%  ({d}/{d})\n", .{ asPct(slots_ks, slots_non_settled), slots_ks, slots_non_settled });
            util.out("pass-optimal slots     {d}  ({d:.4}% of non-settled)\n", .{ pass_opt, asPct(pass_opt, slots_non_settled) });
            util.out("  pass-opt L==H:   {d}/{d} = {d:.4}%\n", .{ pass_opt_lh, slots_lh, asPct(pass_opt_lh, slots_lh) });
            util.out("  pass-opt KO_SENS:{d}/{d} = {d:.4}%  (values distrusted)\n", .{ pass_opt_ks, slots_ks, asPct(pass_opt_ks, slots_ks) });
            util.out("slots with a full-kill move: {d}  ({d:.4}% of non-settled)\n", .{ fk_slots, asPct(fk_slots, slots_non_settled) });
            util.out("  of which full-kill is OPTIMAL: {d}  ({d:.4}% of fk slots)\n", .{ fk_opt, asPct(fk_opt, fk_slots) });
            util.out("  L==H subset:    {d}/{d} = {d:.4}%\n", .{ fk_opt_lh, fk_slots_lh, asPct(fk_opt_lh, fk_slots_lh) });
            util.out("  KO_SENS subset: {d}/{d} = {d:.4}%  (values distrusted)\n", .{ fk_opt_ks, fk_slots_ks, asPct(fk_opt_ks, fk_slots_ks) });
            util.out("  fk children total {d}, of which KO_SENS-flagged {d} ({d:.3}%)\n", .{ fk_child_total, fk_child_ks_total, asPct(fk_child_ks_total, fk_child_total) });
            util.out("pending-ko potential slots: {d}  ({d:.4}% of non-settled)\n", .{ pend_ko_slots, asPct(pend_ko_slots, slots_non_settled) });
            util.out("  pending-ko L==H: {d}  ({d:.4}% of L==H slots)\n", .{ pend_ko_lh, asPct(pend_ko_lh, slots_lh) });
            util.out("== end {d}x{d}\n", .{ w, h });
        }
    };
}

// ═════════════════════════════════════════════════════════════════════════
//  Mode: --kocount   (component 2: independent-ko-count distribution)
// ═════════════════════════════════════════════════════════════════════════

fn KoCountSweep(comptime w: usize, comptime h: usize) type {
    return struct {
        const R = rules.Rules(w, h);
        const X = colex.Indexer(w, h);

        pub fn run(d: *const artifact.Decoded, gpa: std.mem.Allocator) !void {
            if (R.n > 32) @compileError("t382 kocount: board too large for u32 bitmask");
            var counts = [_]u64{0} ** 5;
            var total_legal: u64 = 0;
            var total_ko_sens: u64 = 0;
            var ko_points = try std.ArrayListUnmanaged(KoPoint).initCapacity(gpa, 32);
            defer ko_points.deinit(gpa);
            var board_n_ko = try gpa.alloc(u8, @intCast(X.total));
            defer gpa.free(board_n_ko);
            @memset(board_n_ko, 255);

            var i: u64 = 0;
            while (i < X.total) : (i += 1) {
                const idx: usize = @intCast(i);
                if (d.vb[idx] == UNDEF) continue;
                total_legal += 2;
                const b_ko = (d.fb[idx] & KO_SENS) != 0;
                const w_ko = (d.fw[idx] & KO_SENS) != 0;
                if (!b_ko and !w_ko) continue;
                const nko: u8 = if (board_n_ko[idx] != 255) board_n_ko[idx] else blk: {
                    const pos = X.pos_from_colex(i);
                    ko_points.clearRetainingCapacity();
                    try findAllKoPoints(R, &pos, &ko_points, gpa);
                    const cnt = countIndependentClusters(R, ko_points.items);
                    board_n_ko[idx] = cnt;
                    break :blk cnt;
                };
                if (b_ko) {
                    total_ko_sens += 1;
                    if (nko < 4) counts[nko] += 1 else counts[4] += 1;
                }
                if (w_ko) {
                    total_ko_sens += 1;
                    if (nko < 4) counts[nko] += 1 else counts[4] += 1;
                }
            }
            util.out("== ko-count census {d}x{d}\n", .{ w, h });
            util.out("legal (side-slots)     {d}\n", .{total_legal});
            util.out("ko-sensitive slots     {d}\n", .{total_ko_sens});
            util.out("0-ko: {d} ({d:.4}%)  1-ko: {d} ({d:.4}%)  2-ko: {d} ({d:.4}%)  3-ko: {d} ({d:.4}%)  4-ko+: {d} ({d:.4}%)\n", .{
                counts[0], asPct(counts[0], total_ko_sens),
                counts[1], asPct(counts[1], total_ko_sens),
                counts[2], asPct(counts[2], total_ko_sens),
                counts[3], asPct(counts[3], total_ko_sens),
                counts[4], asPct(counts[4], total_ko_sens),
            });
            const sum = counts[0] + counts[1] + counts[2] + counts[3] + counts[4];
            util.out("sum check: {d} (want {d})  {s}\n", .{ sum, total_ko_sens, if (sum == total_ko_sens) "OK" else "MISMATCH" });
            util.out("== end {d}x{d}\n", .{ w, h });
        }
    };
}

// ═════════════════════════════════════════════════════════════════════════
//  Mode: --cycles   (component 4: SCC / cycle-reachability)
//  State space: (legal position, side, ko ∈ {0..n}, passes ∈ {0,1}); edges =
//  R8 legalMoves (placement children via applyMove, pass via applyPass).
//  passes=2 is terminal and has no vertex. This is the full-graph model of
//  I5/vb_scc (the WZO2 compact vertex space).
// ═════════════════════════════════════════════════════════════════════════

const Sid = struct {
    n: u8,
    /// dense id: ((pos_rank * 2 + side01) * (n+1) + ko) * 2 + passes
    fn from(self: Sid, pos_rank: u64, side01: u1, ko: u8, passes: u1) u64 {
        return ((pos_rank * 2 + @as(u64, side01)) * (@as(u64, self.n) + 1) + @as(u64, ko)) * 2 + @as(u64, passes);
    }
};

fn CycleSweep(comptime w: usize, comptime h: usize) type {
    return struct {
        const R = rules.Rules(w, h);
        const X = colex.Indexer(w, h);
        const n: u8 = @intCast(R.n);
        const SidT = Sid{ .n = n };
        const V: usize = 0; // set in run()

        pub fn run(d: *const artifact.Decoded, gpa: std.mem.Allocator) !void {
            // 1. legal position ranks (ascending colex)
            var legal_list = std.ArrayListUnmanaged(u64).empty;
            defer legal_list.deinit(gpa);
            var i: u64 = 0;
            while (i < X.total) : (i += 1) {
                const idx: usize = @intCast(i);
                if (d.vb[idx] != UNDEF) try legal_list.append(gpa, i);
            }
            const n_legal = legal_list.items.len;
            const n_ko: usize = @as(usize, n) + 1;
            const Vtotal: usize = n_legal * 2 * n_ko * 2;

            // 2. CSR adjacency over the full graph
            const offsets = try gpa.alloc(u64, Vtotal + 1);
            defer gpa.free(offsets);
            @memset(offsets, 0);
            {
                var rank: usize = 0;
                for (legal_list.items) |pos_idx| {
                    const pos = X.pos_from_colex(pos_idx);
                    inline for (.{ @as(u1, 0), @as(u1, 1) }) |side01| {
                        const side: i8 = if (side01 == 0) 1 else -1;
                        for (0..n_ko) |ko| {
                            for (0..2) |p01| {
                                const vid: usize = @intCast(SidT.from(@intCast(rank), side01, @intCast(ko), @intCast(p01)));
                                const bm = R.legalMoves(&pos, side, @intCast(ko), @intCast(p01));
                                var deg: u64 = 0;
                                for (0..R.n) |cell| {
                                    if ((bm[cell / 8] >> @intCast(cell % 8)) & 1 != 0) deg += 1;
                                }
                                if (p01 == 0 and (bm[n / 8] >> @intCast(n % 8)) & 1 != 0) deg += 1; // pass edge
                                offsets[vid] = deg;
                            }
                        }
                    }
                    rank += 1;
                }
                var acc: u64 = 0;
                for (0..Vtotal) |v| {
                    const dg = offsets[v];
                    offsets[v] = acc;
                    acc += dg;
                }
                offsets[Vtotal] = acc;
            }
            const E = offsets[Vtotal];
            const targets = try gpa.alloc(u64, E);
            defer gpa.free(targets);
            {
                var cursor = try gpa.dupe(u64, offsets[0 .. Vtotal + 1]);
                defer gpa.free(cursor);
                var rank: usize = 0;
                for (legal_list.items) |pos_idx| {
                    const pos = X.pos_from_colex(pos_idx);
                    inline for (.{ @as(u1, 0), @as(u1, 1) }) |side01| {
                        const side: i8 = if (side01 == 0) 1 else -1;
                        for (0..n_ko) |ko| {
                            for (0..2) |p01| {
                                const vid: usize = @intCast(SidT.from(@intCast(rank), side01, @intCast(ko), @intCast(p01)));
                                const bm = R.legalMoves(&pos, side, @intCast(ko), @intCast(p01));
                                for (0..R.n) |cell| {
                                    if ((bm[cell / 8] >> @intCast(cell % 8)) & 1 != 0) {
                                        const child = R.applyMove(&pos, side, @intCast(ko), @intCast(p01), cell) orelse unreachable;
                                        const child_rank = rankOf(legal_list.items, X.colex_from_pos(&child.pos)) orelse unreachable;
                                        const child_ko: u8 = if (child.ko >= n) n else child.ko;
                                        const tgt: usize = @intCast(SidT.from(child_rank, if (child.side > 0) 0 else 1, child_ko, 0));
                                        targets[cursor[vid]] = tgt;
                                        cursor[vid] += 1;
                                    }
                                }
                                if (p01 == 0 and (bm[n / 8] >> @intCast(n % 8)) & 1 != 0) {
                                    const child = R.applyPass(side, @intCast(p01)) orelse unreachable;
                                    const tgt: usize = @intCast(SidT.from(@intCast(rank), if (child.side > 0) 0 else 1, n, 1));
                                    targets[cursor[vid]] = tgt;
                                    cursor[vid] += 1;
                                }
                            }
                        }
                    }
                    rank += 1;
                }
            }

            // 3. Tarjan SCCs (iterative)
            const index = try gpa.alloc(i64, Vtotal);
            defer gpa.free(index);
            const low = try gpa.alloc(i64, Vtotal);
            defer gpa.free(low);
            var onstack = try std.DynamicBitSetUnmanaged.initEmpty(gpa, Vtotal);
            defer onstack.deinit(gpa);
            const comp = try gpa.alloc(u32, Vtotal);
            defer gpa.free(comp);
            var comp_sizes = std.ArrayListUnmanaged(u32).empty;
            defer comp_sizes.deinit(gpa);
            @memset(index, -1);

            var counter: i64 = 0;
            var scc_count: u32 = 0;
            const Node = struct { v: u64, next: u64 };
            var scc_stack = std.ArrayListUnmanaged(u64).empty;
            defer scc_stack.deinit(gpa);
            var dfs = std.ArrayListUnmanaged(Node).empty;
            defer dfs.deinit(gpa);

            for (0..Vtotal) |start| {
                if (index[start] != -1) continue;
                index[start] = counter;
                low[start] = counter;
                counter += 1;
                try scc_stack.append(gpa, start);
                onstack.set(start);
                try dfs.append(gpa, .{ .v = start, .next = offsets[start] });
                while (dfs.items.len > 0) {
                    const top = &dfs.items[dfs.items.len - 1];
                    if (top.next < offsets[top.v + 1]) {
                        const u = targets[top.next];
                        top.next += 1;
                        if (index[u] == -1) {
                            index[u] = counter;
                            low[u] = counter;
                            counter += 1;
                            try scc_stack.append(gpa, u);
                            onstack.set(u);
                            try dfs.append(gpa, .{ .v = u, .next = offsets[u] });
                        } else if (onstack.isSet(u)) {
                            if (index[u] < low[top.v]) low[top.v] = index[u];
                        }
                    } else {
                        const v = top.v;
                        _ = dfs.pop();
                        if (dfs.items.len > 0) {
                            const parent = &dfs.items[dfs.items.len - 1];
                            if (low[v] < low[parent.v]) low[parent.v] = low[v];
                        }
                        if (low[v] == index[v]) {
                            var sz: u32 = 0;
                            while (true) {
                                const u = scc_stack.pop().?;
                                onstack.unset(u);
                                comp[u] = scc_count;
                                sz += 1;
                                if (u == v) break;
                            }
                            try comp_sizes.append(gpa, sz);
                            scc_count += 1;
                        }
                    }
                }
            }

            // 4. cycle-reachable = can reach a non-trivial SCC (size >= 2).
            //    Compute by reverse-BFS from all vertices in non-trivial SCCs.
            //    Build the reverse graph.
            var offsets_rev = try gpa.alloc(u64, Vtotal + 1);
            defer gpa.free(offsets_rev);
            @memset(offsets_rev, 0);
            for (0..Vtotal) |v| {
                var e = offsets[v];
                while (e < offsets[v + 1]) : (e += 1) {
                    offsets_rev[targets[e] + 1] += 1;
                }
            }
            for (0..Vtotal) |v| {
                offsets_rev[v + 1] += offsets_rev[v];
            }
            const targets_rev = try gpa.alloc(u64, E);
            defer gpa.free(targets_rev);
            {
                var cursor = try gpa.dupe(u64, offsets_rev[0 .. Vtotal + 1]);
                defer gpa.free(cursor);
                for (0..Vtotal) |v| {
                    var e = offsets[v];
                    while (e < offsets[v + 1]) : (e += 1) {
                        const u = targets[e];
                        targets_rev[cursor[u]] = v;
                        cursor[u] += 1;
                    }
                }
            }

            var nontrivial_sccs: u64 = 0;
            var max_scc: u32 = 0;
            for (0..scc_count) |s| {
                if (comp_sizes.items[s] > max_scc) max_scc = comp_sizes.items[s];
                if (comp_sizes.items[s] >= 2) nontrivial_sccs += 1;
            }
            var cr = try std.DynamicBitSetUnmanaged.initEmpty(gpa, Vtotal);
            defer cr.deinit(gpa);
            var queue = std.ArrayListUnmanaged(u64).empty;
            defer queue.deinit(gpa);
            for (0..Vtotal) |v| {
                if (comp_sizes.items[comp[v]] >= 2) {
                    if (!cr.isSet(v)) {
                        cr.set(v);
                        try queue.append(gpa, v);
                    }
                }
            }
            var qhead: usize = 0;
            while (qhead < queue.items.len) : (qhead += 1) {
                const v = queue.items[qhead];
                var e = offsets_rev[v];
                while (e < offsets_rev[v + 1]) : (e += 1) {
                    const u = targets_rev[e];
                    if (!cr.isSet(u)) {
                        cr.set(u);
                        try queue.append(gpa, u);
                    }
                }
            }
            var cycle_vertices: u64 = 0;
            for (0..Vtotal) |v| {
                if (cr.isSet(v)) cycle_vertices += 1;
            }

            // 5. root-reachable subgraph from (empty, B, ko=none, passes=0)
            const root_rank = rankOf(legal_list.items, 0) orelse unreachable; // empty goban is colex 0
            const root: usize = @intCast(SidT.from(root_rank, 0, n, 0));
            var reachable = try std.DynamicBitSetUnmanaged.initEmpty(gpa, Vtotal);
            defer reachable.deinit(gpa);
            queue.clearRetainingCapacity();
            try queue.append(gpa, root);
            reachable.set(root);
            qhead = 0;
            while (qhead < queue.items.len) : (qhead += 1) {
                const v = queue.items[qhead];
                var e = offsets[v];
                while (e < offsets[v + 1]) : (e += 1) {
                    const u = targets[e];
                    if (!reachable.isSet(u)) {
                        reachable.set(u);
                        try queue.append(gpa, u);
                    }
                }
            }
            var reach_count: u64 = 0;
            var reach_nontrivial_scc: u64 = 0;
            var reach_in_cycle: u64 = 0;
            for (0..Vtotal) |v| {
                if (reachable.isSet(v)) {
                    reach_count += 1;
                    if (comp_sizes.items[comp[v]] >= 2) reach_nontrivial_scc += 1;
                    if (cr.isSet(v)) reach_in_cycle += 1;
                }
            }

            // 6. L==H / KO_SENS split over ko=none passes=0 slots
            var lh_p0: u64 = 0;
            var lh_p0_cr: u64 = 0;
            var ks_p0: u64 = 0;
            var ks_p0_cr: u64 = 0;
            {
                var rank: usize = 0;
                for (legal_list.items) |pos_idx| {
                    const idx: usize = @intCast(pos_idx);
                    inline for (.{ @as(u1, 0), @as(u1, 1) }) |side01| {
                        const vid: usize = @intCast(SidT.from(@intCast(rank), side01, n, 0));
                        const side: i8 = if (side01 == 0) 1 else -1;
                        const fl = if (side > 0) d.fb[idx] else d.fw[idx];
                        const is_ks = fl & KO_SENS != 0;
                        if (is_ks) {
                            ks_p0 += 1;
                            if (cr.isSet(vid)) ks_p0_cr += 1;
                        } else {
                            lh_p0 += 1;
                            if (cr.isSet(vid)) lh_p0_cr += 1;
                        }
                    }
                    rank += 1;
                }
            }

            util.out("== cycle census {d}x{d}\n", .{ w, h });
            util.out("full graph: V={d}  E={d}\n", .{ Vtotal, E });
            util.out("SCCs: {d}  non-trivial: {d}  max SCC size: {d}\n", .{ scc_count, nontrivial_sccs, max_scc });
            util.out("cycle-reachable vertices: {d}  ({d:.4}% of V)\n", .{ cycle_vertices, asPct(cycle_vertices, Vtotal) });
            util.out("root-reachable vertices:  {d}  ({d:.4}% of V)\n", .{ reach_count, asPct(reach_count, Vtotal) });
            util.out("root-reachable in a non-trivial SCC: {d}  ({d:.4}% of reachable)\n", .{ reach_nontrivial_scc, asPct(reach_nontrivial_scc, reach_count) });
            util.out("root-reachable cycle-reachable: {d}  ({d:.4}% of reachable)\n", .{ reach_in_cycle, asPct(reach_in_cycle, reach_count) });
            util.out("non-root cycle exists (root-reachable): {s}\n", .{if (reach_nontrivial_scc > 0) "YES" else "NO"});
            util.out("ko=none passes=0 slots: L==H {d} (cycle-reachable {d} = {d:.4}%)   KO_SENS {d} (cycle-reachable {d} = {d:.4}%)\n", .{
                lh_p0, lh_p0_cr, asPct(lh_p0_cr, lh_p0),
                ks_p0, ks_p0_cr, asPct(ks_p0_cr, ks_p0),
            });
            util.out("== end {d}x{d}\n", .{ w, h });
        }

        fn rankOf(list: []const u64, idx: u64) ?u64 {
            var lo: u64 = 0;
            var hi: u64 = list.len;
            while (lo < hi) {
                const mid = lo + (hi - lo) / 2;
                if (list[mid] == idx) return mid;
                if (list[mid] < idx) lo = mid + 1 else hi = mid;
            }
            return null;
        }
    };
}

// ═════════════════════════════════════════════════════════════════════════
//  Mode: --wzo2   (WZO2 census: entries, L<H KO_SENS, key split)
// ═════════════════════════════════════════════════════════════════════════

fn wzo2Census(io: std.Io, path: []const u8, gpa: std.mem.Allocator) !void {
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .unlimited);
    defer gpa.free(bytes);
    if (bytes.len < 128) return error.Truncated;
    if (!std.mem.eql(u8, bytes[0..4], "WZO2")) return error.BadMagic;
    const w = bytes[6];
    const h = bytes[7];
    const ko_bits = bytes[13];
    const n_groups = std.mem.readInt(u64, bytes[16..24], .little);
    const n_entries = std.mem.readInt(u64, bytes[24..32], .little);
    const ko_mask: u8 = (@as(u8, 1) << @intCast(ko_bits)) - 1;
    const ko_none_val: u8 = w * h; // none is encoded as ko == cell count

    var off: usize = 128; // group block start (contiguous 5-byte group headers)
    const entry_base: usize = 128 + @as(usize, @intCast(n_groups)) * 5;
    var entry_cursor: usize = entry_base;
    var entries: u64 = 0;
    var groups: u64 = 0;
    var terminal: u64 = 0;
    var ko_sens: u64 = 0;
    var lh: u64 = 0;
    var pass0: u64 = 0;
    var pass1: u64 = 0;
    var ko_none: u64 = 0;
    var lh_pass0_konone: u64 = 0;
    var ks_pass0_konone: u64 = 0;

    while (off + 5 <= bytes.len and groups < n_groups) {
        const count = bytes[off + 4];
        off += 5;
        groups += 1;
        for (0..count) |_| {
            if (entry_cursor + 4 > bytes.len) return error.Truncated;
            const kb = bytes[entry_cursor];
            const L: i8 = @bitCast(bytes[entry_cursor + 1]);
            const H: i8 = @bitCast(bytes[entry_cursor + 2]);
            entry_cursor += 4;
            entries += 1;
            const term: u1 = @intCast(kb & 1);
            const ko: u8 = (kb >> 2) & ko_mask;
            const passes: u1 = @intCast((kb >> @intCast(2 + ko_bits)) & 1);
            if (term != 0) terminal += 1;
            if (L < H) ko_sens += 1 else lh += 1;
            if (passes == 0) pass0 += 1 else pass1 += 1;
            if (ko == ko_none_val) ko_none += 1;
            if (passes == 0 and ko == ko_none_val) {
                if (L < H) ks_pass0_konone += 1 else lh_pass0_konone += 1;
            }
        }
    }

    util.out("== wzo2 census {s}\n", .{path});
    util.out("header: {d}x{d}  ko_bits={d}  n_groups={d}  n_entries={d}\n", .{ w, h, ko_bits, n_groups, n_entries });
    util.out("walked: groups={d}  entries={d}  {s}\n", .{ groups, entries, if (groups == n_groups and entries == n_entries) "OK" else "MISMATCH" });
    util.out("terminal {d}  non-terminal {d}\n", .{ terminal, entries - terminal });
    util.out("L<H (KO_SENS): {d}  ({d:.4}% of entries)   L==H: {d}\n", .{ ko_sens, asPct(ko_sens, entries), lh });
    util.out("passes: p0 {d}  p1 {d}   ko: none {d}  cell {d}\n", .{ pass0, pass1, ko_none, entries - ko_none });
    util.out("ko=none passes=0 slice: L==H {d}  KO_SENS {d}\n", .{ lh_pass0_konone, ks_pass0_konone });
    util.out("== end {s}\n", .{path});
}

// ═════════════════════════════════════════════════════════════════════════
//  Mode: --selftest
// ═════════════════════════════════════════════════════════════════════════

fn selftest(io: std.Io, gpa: std.mem.Allocator) !void {
    var passed: u32 = 0;
    var failed: u32 = 0;
    const check = struct {
        fn c(ok: bool, name: []const u8, p: *u32, f: *u32) void {
            if (ok) {
                p.* += 1;
                util.out("  [PASS] {s}\n", .{name});
            } else {
                f.* += 1;
                util.out("  [FAIL] {s}\n", .{name});
            }
        }
    }.c;

    util.out("== selftest\n", .{});

    // ── 1. Tarjan on a hand-built graph: 5 vertices, one 2-cycle {1,2},
    //    vertex 3 -> 1, vertex 4 leaf. Expect 4 SCCs (3 trivial + 1 of
    //    size 2); max SCC 2; vertices 1,2 in the same SCC.
    {
        const V: usize = 5;
        const offsets = [_]u64{ 0, 0, 1, 2, 3, 3 };
        const targets = [_]u64{ 2, 1, 1 };
        var index = [_]i64{ -1 } ** 5;
        var low = [_]i64{ 0 } ** 5;
        var onstack = [_]bool{false} ** 5;
        var comp = [_]u32{ 0 } ** 5;
        var comp_sizes: [5]u32 = undefined;
        var scc_count: u32 = 0;
        var counter: i64 = 0;
        var scc_stack: [5]u64 = undefined;
        var ss_top: usize = 0;
        const Node = struct { v: u64, next: u64 };
        var dfs: [5]Node = undefined;
        var df_top: usize = 0;

        for (0..V) |start| {
            if (index[start] != -1) continue;
            index[start] = counter;
            low[start] = counter;
            counter += 1;
            scc_stack[ss_top] = start;
            ss_top += 1;
            onstack[start] = true;
            dfs[df_top] = .{ .v = start, .next = offsets[start] };
            df_top += 1;
            while (df_top > 0) {
                const t_idx = df_top - 1;
                if (dfs[t_idx].next < offsets[dfs[t_idx].v + 1]) {
                    const u = targets[dfs[t_idx].next];
                    dfs[t_idx].next += 1;
                    if (index[u] == -1) {
                        index[u] = counter;
                        low[u] = counter;
                        counter += 1;
                        scc_stack[ss_top] = u;
                        ss_top += 1;
                        onstack[u] = true;
                        dfs[df_top] = .{ .v = u, .next = offsets[u] };
                        df_top += 1;
                    } else if (onstack[u]) {
                        if (index[u] < low[dfs[t_idx].v]) low[dfs[t_idx].v] = index[u];
                    }
                } else {
                    const v = dfs[t_idx].v;
                    df_top -= 1;
                    if (df_top > 0) {
                        if (low[v] < low[dfs[df_top - 1].v]) low[dfs[df_top - 1].v] = low[v];
                    }
                    if (low[v] == index[v]) {
                        var sz: u32 = 0;
                        while (true) {
                            ss_top -= 1;
                            const u = scc_stack[ss_top];
                            onstack[u] = false;
                            comp[u] = scc_count;
                            sz += 1;
                            if (u == v) break;
                        }
                        comp_sizes[scc_count] = sz;
                        scc_count += 1;
                    }
                }
            }
        }
        var nontriv: u64 = 0;
        var maxsz: u32 = 0;
        for (0..scc_count) |s| {
            if (comp_sizes[s] > maxsz) maxsz = comp_sizes[s];
            if (comp_sizes[s] >= 2) nontriv += 1;
        }
        check(scc_count == 4 and nontriv == 1 and maxsz == 2, "Tarjan hand-built graph: 4 SCCs, 1 non-trivial of size 2", &passed, &failed);
        check(comp[1] == comp[2], "Tarjan hand-built graph: vertices 1,2 in the same SCC", &passed, &failed);
        check(comp[0] != comp[1] and comp[3] != comp[1] and comp[4] != comp[1], "Tarjan hand-built graph: leaves in distinct trivial SCCs", &passed, &failed);
    }

    // ── 2. ko-shape detector on hand-built positions.
    {
        // 3×3 single-stone ko: B{0,2,4}, W{3}. B@0 is a lone stone whose
        // only liberty is cell 1 (neighbors 1,3; 3 is W). W plays 1: captures
        // B@0 (single); the new W stone @1 has liberties {0(vacated),2(B),4(B)}
        // = exactly 1 → ko point (cell 1, cap 0). No other ko capture exists
        // (B@6 would capture W@3 but the new stone then has 2 liberties).
        const R3 = rules.Rules(3, 3);
        var pos3 = [_]i8{0} ** 9;
        pos3[0] = 1; pos3[2] = 1; pos3[4] = 1; pos3[3] = -1;
        var kp = std.ArrayListUnmanaged(KoPoint).empty;
        defer kp.deinit(gpa);
        try findAllKoPoints(R3, &pos3, &kp, gpa);
        const n_clusters = countIndependentClusters(R3, kp.items);
        check(kp.items.len == 1 and n_clusters == 1, "ko-shape: 3×3 single-stone ko position yields exactly 1 ko point in 1 cluster", &passed, &failed);
        check(kp.items.len == 1 and kp.items[0].cell == 1 and kp.items[0].cap == 0, "ko-shape: the single ko point is (cell 1, captured 0)", &passed, &failed);

        // 4×4: two DISJOINT corner pockets → 2 independent clusters.
        // Pocket A (top-left): lone B@1 with only liberty 0 (neighbors 0,2,5;
        //   2,5 are W); W plays 0 → captures B@1, new stone @0 has liberties
        //   {1(vacated),4(W)} = 1 → ko (cell 0, cap 1).
        // Pocket B (bottom-right): lone B@14 with only liberty 15 (neighbors
        //   10,13,15; 10,13 are W); W plays 15 → captures B@14, new stone @15
        //   has liberties {11(W),14(vacated)} = 1 → ko (cell 15, cap 14).
        const R4 = rules.Rules(4, 4);
        var pos4 = [_]i8{0} ** 16;
        pos4[1] = 1; pos4[2] = -1; pos4[4] = -1; pos4[5] = -1; // pocket A
        pos4[10] = -1; pos4[11] = -1; pos4[13] = -1; pos4[14] = 1; // pocket B
        var kp4 = std.ArrayListUnmanaged(KoPoint).empty;
        defer kp4.deinit(gpa);
        try findAllKoPoints(R4, &pos4, &kp4, gpa);
        const n4 = countIndependentClusters(R4, kp4.items);
        check(kp4.items.len == 2 and n4 == 2, "ko-shape: two disjoint 4×4 ko pockets → 2 ko points in 2 clusters", &passed, &failed);
    }

    // ── 3. null control: 1×1 artifact (1 legal position, zero flags, zero
    //    moves) exercised through encode/decode.
    {
        const R1 = rules.Rules(1, 1);
        const X1 = colex.Indexer(1, 1);
        const t1: usize = @intCast(X1.total);
        const vb = try gpa.alloc(i8, t1);
        defer gpa.free(vb);
        const vw = try gpa.alloc(i8, t1);
        defer gpa.free(vw);
        const fb = try gpa.alloc(u8, t1);
        defer gpa.free(fb);
        const fw = try gpa.alloc(u8, t1);
        defer gpa.free(fw);
        const db = try gpa.alloc(u8, t1);
        defer gpa.free(db);
        const dw = try gpa.alloc(u8, t1);
        defer gpa.free(dw);
        @memset(vb, UNDEF);
        @memset(vw, UNDEF);
        @memset(fb, 0);
        @memset(fw, 0);
        @memset(db, 0);
        @memset(dw, 0);
        vb[0] = 0;
        vw[0] = 0;
        const cols = artifact.Columns{ .vb = vb, .vw = vw, .fb = fb, .fw = fw, .db = db, .dw = dw };
        const hdr = artifact.Header{ .board_w = 1, .board_h = 1, .total = t1, .legal_count = 1 };
        const enc = try artifact.encode(gpa, hdr, cols);
        defer gpa.free(enc);
        var dec = try artifact.decode(gpa, enc);
        defer dec.deinit();
        check(dec.fb[0] & KO_SENS == 0 and dec.fw[0] & KO_SENS == 0, "null control: 1×1 has zero KO_SENS flags", &passed, &failed);
        var pos1 = [_]i8{0};
        const sc = stoneCounts(R1, &pos1);
        check(sc.b == 0 and sc.w == 0, "null control: 1×1 empty goban is a full-kill position (zero stones both colours)", &passed, &failed);
        var bm = R1.legalMoves(&pos1, 1, 1, 0);
        var n_moves: u8 = 0;
        for (0..R1.n + 1) |c| {
            if ((bm[c / 8] >> @intCast(c % 8)) & 1 != 0) n_moves += 1;
        }
        check(n_moves == 1, "null control: 1×1 empty goban has exactly one legal move (the pass)", &passed, &failed);
        bm = [_]u8{0};
        _ = &bm;
    }

    // ── 4. seeded defects on the real 2×2 artifact.
    {
        const bytes = try std.Io.Dir.cwd().readFileAlloc(io, "artifacts/oracle-2x2.wzo", gpa, .unlimited);
        defer gpa.free(bytes);
        var dec = try artifact.decode(gpa, bytes);
        defer dec.deinit();
        const X2 = colex.Indexer(2, 2);
        // (a) flag flip: KO_SENS count moves by exactly 1
        var flip_idx: usize = 0;
        var flip_side: i8 = 1;
        var flip_found = false;
        outer: for (0..@as(usize, @intCast(X2.total))) |idx| {
            if (dec.vb[idx] == UNDEF) continue;
            const pos = X2.pos_from_colex(idx);
            if (rules.Rules(2, 2).is_settled(&pos)) continue;
            if (dec.fb[idx] & KO_SENS == 0) {
                flip_idx = idx;
                flip_side = 1;
                flip_found = true;
                break :outer;
            }
            if (dec.fw[idx] & KO_SENS == 0) {
                flip_idx = idx;
                flip_side = -1;
                flip_found = true;
                break :outer;
            }
        }
        if (flip_found) {
            const before = countFlags2x2(&dec);
            const saved = if (flip_side > 0) dec.fb[flip_idx] else dec.fw[flip_idx];
            if (flip_side > 0) dec.fb[flip_idx] |= KO_SENS else dec.fw[flip_idx] |= KO_SENS;
            const after = countFlags2x2(&dec);
            if (flip_side > 0) dec.fb[flip_idx] = saved else dec.fw[flip_idx] = saved;
            check(after == before + 1, "seeded defect: flag flip on a clear 2×2 slot moves the KO_SENS count by exactly 1", &passed, &failed);
        } else {
            check(false, "seeded defect: no clear 2×2 slot found to flip", &passed, &failed);
        }
        // (b) value perturbation: a stored value of +127 (impossible as a
        //     score on any goban) can never equal a pass-edge / child value,
        //     so a slot perturbed to 127 must not count as pass-optimal.
        var p_idx: usize = 0;
        var p_found = false;
        for (0..@as(usize, @intCast(X2.total))) |idx| {
            if (dec.vb[idx] == UNDEF) continue;
            const pos = X2.pos_from_colex(idx);
            if (rules.Rules(2, 2).is_settled(&pos)) continue;
            p_idx = idx;
            p_found = true;
            break;
        }
        if (p_found) {
            const saved_v = dec.vb[p_idx];
            dec.vb[p_idx] = 127;
            const p_ok = checkPassOptBound(&dec, p_idx);
            dec.vb[p_idx] = saved_v;
            check(!p_ok, "seeded defect: stored value perturbed to 127 cannot be pass-optimal (127 > any score)", &passed, &failed);
        } else {
            check(false, "seeded defect: no perturbable 2×2 slot found", &passed, &failed);
        }
    }

    util.out("selftest: {d} passed, {d} failed\n", .{ passed, failed });
    if (failed > 0) std.process.exit(2);
}

/// KO_SENS count over 2×2 non-settled legal slots (for the flag-flip check).
fn countFlags2x2(d: *const artifact.Decoded) u64 {
    const X2 = colex.Indexer(2, 2);
    var cnt: u64 = 0;
    for (0..@as(usize, @intCast(X2.total))) |i| {
        if (d.vb[i] == UNDEF) continue;
        const pos = X2.pos_from_colex(i);
        if (rules.Rules(2, 2).is_settled(&pos)) continue;
        if (d.fb[i] & KO_SENS != 0) cnt += 1;
        if (d.fw[i] & KO_SENS != 0) cnt += 1;
    }
    return cnt;
}

/// Is the (pos, side=B) slot at colex idx pass-optimal under the *current*
/// in-memory values? Used by the perturbation check (must be false for 127).
fn checkPassOptBound(d: *const artifact.Decoded, idx: usize) bool {
    const R = rules.Rules(2, 2);
    const X2 = colex.Indexer(2, 2);
    const pos = X2.pos_from_colex(idx);
    if (R.is_settled(&pos)) return false;
    // pass edge value for (pos, B): V1(pos, W)
    const maxing = false; // White maximizes? no — V1(P, W): White to move after a pass, White minimizes (Black-positive)
    var best: i8 = R.area_score(&pos);
    for (0..R.n) |c| {
        if (pos[c] != 0) continue;
        const ch = R.pos_from_move(&pos, -1, c) catch continue;
        const ci: usize = @intCast(X2.colex_from_pos(&ch));
        const v = d.vb[ci]; // Black to move at child
        if (v == UNDEF) continue;
        if (v < best) best = v; // White minimizes
    }
    _ = maxing;
    return d.vb[idx] == best;
}

// ═════════════════════════════════════════════════════════════════════════
//  main
// ═════════════════════════════════════════════════════════════════════════

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next(); // program name
    const mode = args.next() orelse {
        util.out("usage: t382_census <mode> [args]\n", .{});
        util.out("  --selftest\n", .{});
        util.out("  --slot <artifact.wzo>\n", .{});
        util.out("  --kocount <artifact.wzo>\n", .{});
        util.out("  --cycles <artifact.wzo>\n", .{});
        util.out("  --wzo2 <file.wzo2>\n", .{});
        return;
    };

    if (std.mem.eql(u8, mode, "--selftest")) {
        try selftest(init.io, gpa);
        return;
    }

    if (std.mem.eql(u8, mode, "--wzo2")) {
        const path = args.next() orelse return error.NoArtifact;
        try wzo2Census(init.io, path, gpa);
        return;
    }

    const path = args.next() orelse return error.NoArtifact;
    var dec = try artifact.load(init.io, std.Io.Dir.cwd(), path, gpa);
    defer dec.deinit();
    const key = @as(usize, dec.header.board_w) * 100 + dec.header.board_h;

    if (std.mem.eql(u8, mode, "--slot")) {
        switch (key) {
            202 => try SlotSweep(2, 2).run(&dec, gpa),
            302 => try SlotSweep(3, 2).run(&dec, gpa),
            303 => try SlotSweep(3, 3).run(&dec, gpa),
            403 => try SlotSweep(4, 3).run(&dec, gpa),
            404 => try SlotSweep(4, 4).run(&dec, gpa),
            else => return error.Unsupported,
        }
    } else if (std.mem.eql(u8, mode, "--kocount")) {
        switch (key) {
            202 => try KoCountSweep(2, 2).run(&dec, gpa),
            302 => try KoCountSweep(3, 2).run(&dec, gpa),
            303 => try KoCountSweep(3, 3).run(&dec, gpa),
            403 => try KoCountSweep(4, 3).run(&dec, gpa),
            404 => try KoCountSweep(4, 4).run(&dec, gpa),
            else => return error.Unsupported,
        }
    } else if (std.mem.eql(u8, mode, "--cycles")) {
        switch (key) {
            202 => try CycleSweep(2, 2).run(&dec, gpa),
            302 => try CycleSweep(3, 2).run(&dec, gpa),
            303 => try CycleSweep(3, 3).run(&dec, gpa),
            else => return error.Unsupported,
        }
    } else {
        util.out("unknown mode: {s}\n", .{mode});
        return error.UnknownMode;
    }
}
