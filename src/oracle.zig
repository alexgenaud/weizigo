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
// ORACLE BUILDER (prototype scale) — fills the value of EVERY legal
// (position, side-to-move) of a small board into a flat colex-addressed array:
// the first actual oracle artifact (ADR-0007 goal b; semantics in ADR-0008).
//
// SEMANTICS — "fresh-start value": oracle[pos][side] is the optimal area score
// (Black-positive, komi 0) of the game STARTING at `pos` with `side` to move,
// empty history seeded with `pos` itself (positional superko forbids
// recreating any position seen since this start). This matches solve.zig's
// solve_root and is well-defined for every legal position. For positions
// arising mid-game with additional ko bans in force the true value can differ;
// that gap is the GHI residue, MEASURED here (saw_ban fraction), not assumed.
//
// ENGINE — forward search-to-terminal, the same validated semantics as
// solve.zig (double-pass/settled terminals, area scoring, positional superko,
// the ko_ref GHI cacheability rule, the ADR-0006 eye-prune), but board-size-
// generic (rules.zig) and memoized directly in the RAW COLEX ARRAY — the memo
// table IS the oracle output. Only `passes == 0`, `ko_ref >= d` (clean) values
// are memoized; every legal position gets a root solve, so the sweep fills the
// whole table.
//
// SIGN CONVENTIONS (see ADR-0008; the user has been bitten here before):
//   - scores are ALWAYS Black-positive; side-to-move picks the ARRAY (vb/vw),
//     never the sign. Black maximizes, White minimizes.
//   - colour inversion: value(-pos, -side) == -value(pos, side). Verified
//     EXHAUSTIVELY over the whole table by `main`.
//
// VALIDATION in main (3x3):
//   1. published anchors: empty board = B+9 (centre); after 1.B side = +3;
//      after 1.B corner = -9; empty with White to move = -9.
//   2. exhaustive colour-inversion + all-8-dihedral symmetry over every legal
//      position, both sides.
//   3. build-order independence: ascending vs descending root sweeps must
//      produce byte-identical tables (order-dependence would expose GHI memo
//      pollution).
//   4. no-memo spot checks on >= 6-stone roots (small subtrees), node-budgeted.

const std = @import("std");
const expect = std.testing.expect;
const rules = @import("rules.zig");
const colexmod = @import("colex.zig");
const enumerate = @import("enumerate.zig");

pub fn Oracle(comptime w: usize, comptime h: usize) type {
    return struct {
        pub const R = rules.Rules(w, h);
        pub const X = colexmod.Indexer(w, h);
        pub const E = enumerate.Enumerator(w, h);
        pub const n = R.n;
        pub const Pos = R.Pos;

        /// Positional-superko line bound. A line cannot repeat a position, so
        /// it is bounded by the number of legal positions; this is a pragmatic
        /// cap with a loud panic (same policy as superko.MAX_LINE).
        pub const MAX_LINE = 16384;
        pub const KO_CLEAN: usize = std.math.maxInt(usize);

        pub const History = struct {
            boards: [MAX_LINE]Pos = undefined,
            len: usize = 0,
            max_len: usize = 0,

            pub fn reset(self: *History) void {
                self.len = 0;
            }
            pub fn push(self: *History, b: *const Pos) void {
                if (self.len >= MAX_LINE) @panic("oracle: game line exceeded MAX_LINE");
                self.boards[self.len] = b.*;
                self.len += 1;
                if (self.len > self.max_len) self.max_len = self.len;
            }
            pub fn pop(self: *History) void {
                self.len -= 1;
            }
            pub fn repeatsIndex(self: *const History, b: *const Pos) ?usize {
                var i: usize = 0;
                while (i < self.len) : (i += 1) {
                    if (std.mem.eql(i8, &self.boards[i], b)) return i;
                }
                return null;
            }
        };

        pub const Ctx = struct {
            vb: []i8, // value, Black to move (Black-positive score)
            vw: []i8, // value, White to move (still Black-positive score!)
            cb: []bool, // vb[idx] is a memoized CLEAN value
            cw: []bool,
            memo: bool, // enable memo read/write
            // CONDITIONAL ASSUMPTION toggle (arena-audit doctrine): [L,H]
            // bracket cuts in retro.ab_solve. Off = values come only from
            // the memo discipline + search. Used to localize prefix-
            // soundness failures.
            brackets: bool = true,
            saw_ban: bool = false, // any superko ban fired during current root
            nodes: u64 = 0,
            budget: u64 = 0, // 0 = unlimited; else error.Budget when exceeded
            // Optional per-root BOUNDS memo for the alpha-beta finisher
            // (retro.zig): fail-soft lower/upper bounds per (idx, side) that
            // the exactness discipline forbids storing in the exact memo —
            // what makes null-window (MTD) probes incremental instead of
            // re-searching. Sentinels: lb = -127 / ub = +127 (no info).
            // Same ko_ref-clean, per-root journaled discipline.
            lbb: ?[]i8 = null, // lower bound, Black to move
            ubb: ?[]i8 = null, // upper bound, Black to move
            lbw: ?[]i8 = null,
            ubw: ?[]i8 = null,

            // Optional undo journal: every memo WRITE is recorded as
            // idx | side_bit<<31 | bound_bit<<30 so a multi-root driver can
            // revert just the touched slots to its baseline instead of a
            // full-table memcpy per root (O(total) — prohibitive at 43M
            // slots). Requires idx < 2^30 (raw colex through 4x4; revisit
            // with the 5x5 density folds).
            journal: ?*std.ArrayList(u32) = null,
            journal_gpa: std.mem.Allocator = undefined, // set iff journal != null

            pub fn record(ctx: *Ctx, idx: u64, to_move: i8) void {
                if (ctx.journal) |j| {
                    const bit: u32 = if (to_move > 0) 0 else 1 << 31;
                    j.append(ctx.journal_gpa, @as(u32, @intCast(idx)) | bit) catch
                        @panic("oracle: memo journal allocation failed");
                }
            }

            pub fn record_bound(ctx: *Ctx, idx: u64, to_move: i8) void {
                if (ctx.journal) |j| {
                    const bit: u32 = if (to_move > 0) 0 else 1 << 31;
                    j.append(ctx.journal_gpa, @as(u32, @intCast(idx)) | bit | (1 << 30)) catch
                        @panic("oracle: memo journal allocation failed");
                }
            }
        };

        pub const Result = struct { value: i8, ko_ref: usize };

        pub fn solve(ctx: *Ctx, pos: *const Pos, to_move: i8, passes: u8, hist: *History) error{Budget}!Result {
            ctx.nodes += 1;
            if (ctx.budget != 0 and ctx.nodes > ctx.budget) return error.Budget;
            if (passes >= 2) return .{ .value = R.area_score(pos), .ko_ref = KO_CLEAN };
            if (R.is_settled(pos)) return .{ .value = R.area_score(pos), .ko_ref = KO_CLEAN };

            const d = hist.len - 1;
            const idx = X.colex_from_pos(pos);
            const hashable = ctx.memo and passes == 0;
            if (hashable) {
                if (to_move > 0) {
                    if (ctx.cb[idx]) return .{ .value = ctx.vb[idx], .ko_ref = KO_CLEAN };
                } else {
                    if (ctx.cw[idx]) return .{ .value = ctx.vw[idx], .ko_ref = KO_CLEAN };
                }
            }

            const maximizing = to_move > 0;
            var best: i8 = if (maximizing) -127 else 127;
            var ko_ref: usize = KO_CLEAN;

            const own_alive = R.pass_alive(pos, to_move); // ADR-0006 eye-prune
            for (0..n) |p| {
                if (pos[p] != 0) continue;
                if (R.is_own_eye(pos, p, to_move, &own_alive)) continue;
                const child = R.pos_from_move(pos, to_move, p) catch continue;
                if (hist.repeatsIndex(&child)) |j| {
                    ctx.saw_ban = true;
                    if (j < ko_ref) ko_ref = j;
                    continue;
                }
                hist.push(&child);
                const r = try solve(ctx, &child, -to_move, 0, hist);
                hist.pop();
                if (r.ko_ref < ko_ref) ko_ref = r.ko_ref;
                if (maximizing) {
                    if (r.value > best) best = r.value;
                } else {
                    if (r.value < best) best = r.value;
                }
            }
            // pass (board unchanged, exempt from superko)
            const rp = try solve(ctx, pos, -to_move, passes + 1, hist);
            if (rp.ko_ref < ko_ref) ko_ref = rp.ko_ref;
            if (maximizing) {
                if (rp.value > best) best = rp.value;
            } else {
                if (rp.value < best) best = rp.value;
            }

            if (hashable and ko_ref >= d) {
                ctx.record(idx, to_move);
                if (to_move > 0) {
                    ctx.vb[idx] = best;
                    ctx.cb[idx] = true;
                } else {
                    ctx.vw[idx] = best;
                    ctx.cw[idx] = true;
                }
            }
            return .{ .value = best, .ko_ref = ko_ref };
        }

        /// Fresh-start value of (pos, to_move) — the oracle's defining query.
        pub fn value_from_root(ctx: *Ctx, pos: *const Pos, to_move: i8, hist: *History) error{Budget}!i8 {
            hist.reset();
            hist.push(pos);
            ctx.saw_ban = false;
            return (try solve(ctx, pos, to_move, 0, hist)).value;
        }
    };
}

// ---- 3x3 oracle build + validation --------------------------------------------

const O = Oracle(3, 3);
const UNDEF: i8 = -128;

fn newCtx(gpa: std.mem.Allocator, memo: bool) !O.Ctx {
    const vb = try gpa.alloc(i8, O.X.total);
    const vw = try gpa.alloc(i8, O.X.total);
    const cb = try gpa.alloc(bool, O.X.total);
    const cw = try gpa.alloc(bool, O.X.total);
    @memset(vb, UNDEF);
    @memset(vw, UNDEF);
    @memset(cb, false);
    @memset(cw, false);
    return .{ .vb = vb, .vw = vw, .cb = cb, .cw = cw, .memo = memo };
}

/// Sweep every legal position (both sides) as a fresh-start root, layers
/// BOTTOM-UP (most stones first): endgame roots are cheap and their clean
/// values warm the memo before the ko-heavy opening roots. (An ascending
/// cold-start sweep — empty board first — was measured impractically slow:
/// the empty root alone re-searches the GHI-tainted opening unmemoized, the
/// forward-solve wall of docs/research/forward-solve-scaling.md in miniature.)
/// `within_desc` flips the within-layer order (order-independence probe).
fn build(ctx: *O.Ctx, hist: *O.History, within_desc: bool, ko_affected: *u64) !u64 {
    var legal_count: u64 = 0;
    var layer: usize = O.n + 1;
    while (layer > 0) {
        layer -= 1;
        const lo = O.X.layer_offset[layer];
        const hi = O.X.layer_offset[layer + 1];
        var step: u64 = 0;
        while (step < hi - lo) : (step += 1) {
            const idx = if (within_desc) hi - 1 - step else lo + step;
            var pos = O.X.pos_from_colex(idx);
            if (!O.E.is_legal(&pos)) continue;
            legal_count += 1;
            inline for (.{ @as(i8, 1), @as(i8, -1) }) |side| {
                const v = try O.value_from_root(ctx, &pos, side, hist);
                if (ctx.saw_ban) ko_affected.* += 1;
                // root is always memoized (ko_ref >= 0 == d); assert and record
                if (side > 0) {
                    ctx.vb[idx] = v;
                    ctx.cb[idx] = true;
                } else {
                    ctx.vw[idx] = v;
                    ctx.cw[idx] = true;
                }
            }
        }
        std.debug.print("  layer {d} done: legal so far {d}, nodes {d}\n", .{ layer, legal_count, ctx.nodes });
    }
    return legal_count;
}

fn transformed(pos: *const O.Pos, perm: *const [9]u8, flip: i8) O.Pos {
    var t: O.Pos = undefined;
    for (0..9) |i| t[i] = flip * pos[perm[i]];
    return t;
}

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    std.debug.print("weizigo 3x3 oracle build (fresh-start semantics, ADR-0008)\n", .{});

    const hist = try gpa.create(O.History);
    defer gpa.destroy(hist);
    hist.* = .{};

    // ---- build A (ascending) and B (descending) ----
    var ctxA = try newCtx(gpa, true);
    var koA: u64 = 0;
    const legal = try build(&ctxA, hist, false, &koA);
    const nodesA = ctxA.nodes;
    std.debug.print("A: {d} legal positions x 2 sides; nodes={d}; ko-affected roots={d} ({d}%); max line={d}\n", .{
        legal, nodesA, koA, koA * 100 / (legal * 2), hist.max_len,
    });

    var ctxB = try newCtx(gpa, true);
    var koB: u64 = 0;
    _ = try build(&ctxB, hist, true, &koB);

    // ---- 3. build-order independence (GHI memo-pollution probe) ----
    var order_mismatch: u64 = 0;
    for (0..O.X.total) |i| {
        if (ctxA.cb[i] != ctxB.cb[i] or ctxA.cw[i] != ctxB.cw[i]) order_mismatch += 1;
        if (ctxA.cb[i] and ctxA.vb[i] != ctxB.vb[i]) order_mismatch += 1;
        if (ctxA.cw[i] and ctxA.vw[i] != ctxB.vw[i]) order_mismatch += 1;
    }
    std.debug.print("order independence: {s} ({d} mismatches)\n", .{
        if (order_mismatch == 0) "PASS" else "FAIL", order_mismatch,
    });

    // ---- 1. published anchors ----
    const empty: O.Pos = [_]i8{0} ** 9;
    const e_idx = O.X.colex_from_pos(&empty);
    const vB = ctxA.vb[e_idx];
    const vW = ctxA.vw[e_idx];
    var centre: O.Pos = [_]i8{0} ** 9;
    centre[4] = 1;
    var side_b1: O.Pos = [_]i8{0} ** 9; // b1 = bottom-centre = cell 7
    side_b1[7] = 1;
    var corner: O.Pos = [_]i8{0} ** 9; // a1 = bottom-left = cell 6
    corner[6] = 1;
    const v_centre = ctxA.vw[O.X.colex_from_pos(&centre)]; // White to move after 1.B[centre]
    const v_side = ctxA.vw[O.X.colex_from_pos(&side_b1)];
    const v_corner = ctxA.vw[O.X.colex_from_pos(&corner)];
    std.debug.print("anchors: empty(B)={d} (want 9), empty(W)={d} (want -9), 1.B centre={d} (want 9), 1.B side={d} (want 3), 1.B corner={d} (want -9)\n", .{ vB, vW, v_centre, v_side, v_corner });
    const anchors_ok = vB == 9 and vW == -9 and v_centre == 9 and v_side == 3 and v_corner == -9;
    std.debug.print("anchors: {s}\n", .{if (anchors_ok) "PASS" else "FAIL"});

    // ---- 2. exhaustive colour-inversion + dihedral symmetry ----
    var inv_fail: u64 = 0;
    var dih_fail: u64 = 0;
    for (0..O.X.total) |i| {
        if (!ctxA.cb[i]) continue; // non-legal slots never filled
        var pos = O.X.pos_from_colex(i);
        // colour inversion: value(-pos, -side) == -value(pos, side)
        const inv = transformed(&pos, &O.E.sym_perms[0], -1);
        const inv_idx = O.X.colex_from_pos(&inv);
        if (ctxA.vw[inv_idx] != -ctxA.vb[i]) inv_fail += 1;
        if (ctxA.vb[inv_idx] != -ctxA.vw[i]) inv_fail += 1;
        // dihedral: value(T(pos), side) == value(pos, side) for all 8 T
        inline for (0..8) |s| {
            const t = transformed(&pos, &O.E.sym_perms[s], 1);
            const t_idx = O.X.colex_from_pos(&t);
            if (ctxA.vb[t_idx] != ctxA.vb[i]) dih_fail += 1;
            if (ctxA.vw[t_idx] != ctxA.vw[i]) dih_fail += 1;
        }
    }
    std.debug.print("EXHAUSTIVE colour-inversion: {s} ({d} fails)   dihedral x8: {s} ({d} fails)\n", .{
        if (inv_fail == 0) "PASS" else "FAIL", inv_fail,
        if (dih_fail == 0) "PASS" else "FAIL", dih_fail,
    });

    // ---- 4. no-memo spot checks on >=6-stone roots (small subtrees) ----
    var spot_ok: u64 = 0;
    var spot_fail: u64 = 0;
    var spot_skip: u64 = 0;
    var ctxN = try newCtx(gpa, false);
    for (O.X.layer_offset[6]..O.X.total) |i| {
        if (!ctxA.cb[i]) continue; // skip illegal slots
        var pos = O.X.pos_from_colex(i);
        inline for (.{ @as(i8, 1), @as(i8, -1) }) |side| {
            ctxN.nodes = 0;
            ctxN.budget = 5_000_000;
            if (O.value_from_root(&ctxN, &pos, side, hist)) |v| {
                const want = if (side > 0) ctxA.vb[i] else ctxA.vw[i];
                if (v == want) spot_ok += 1 else spot_fail += 1;
            } else |_| spot_skip += 1; // budget exceeded: skip, count
        }
    }
    std.debug.print("no-memo spot checks (>=6 stones): {s} ok={d} fail={d} budget-skipped={d}\n", .{
        if (spot_fail == 0) "PASS" else "FAIL", spot_ok, spot_fail, spot_skip,
    });

    // ---- value histogram (Black to move) ----
    var histo = [_]u64{0} ** 19;
    for (0..O.X.total) |i| {
        if (ctxA.cb[i]) histo[@intCast(@as(i16, ctxA.vb[i]) + 9)] += 1;
    }
    std.debug.print("value histogram (Black to move), v:-9..9:\n  ", .{});
    for (histo, 0..) |c, j| {
        if (c != 0) std.debug.print("{d}:{d} ", .{ @as(i16, @intCast(j)) - 9, c });
    }
    std.debug.print("\n", .{});
}

// ---- tests ------------------------------------------------------------------

var t_hist: O.History = .{};

test "settled 3x3 boards solve to their area at the root" {
    const gpa = std.testing.allocator;
    var ctx = try newCtx(gpa, false);
    defer {
        gpa.free(ctx.vb);
        gpa.free(ctx.vw);
        gpa.free(ctx.cb);
        gpa.free(ctx.cw);
    }
    const wall = [_]i8{
        0, 1, 0,
        0, 1, 0,
        0, 1, 0,
    };
    try expect(try O.value_from_root(&ctx, &wall, 1, &t_hist) == 9);
    try expect(try O.value_from_root(&ctx, &wall, -1, &t_hist) == 9);
}

test "near-terminal 3x3: dead white stone is captured to +9" {
    const gpa = std.testing.allocator;
    var ctx = try newCtx(gpa, true);
    defer {
        gpa.free(ctx.vb);
        gpa.free(ctx.vw);
        gpa.free(ctx.cb);
        gpa.free(ctx.cw);
    }
    // black middle column alive-ish + dead white corner stone
    const b = [_]i8{
        -1, 1, 0,
        0,  1, 0,
        0,  1, 0,
    };
    try expect(try O.value_from_root(&ctx, &b, 1, &t_hist) == 9);
}
