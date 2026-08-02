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
// CHAINABILITY AUDIT — where may a table value be compared with its children's?
//
// A player that picks a move by comparing the stored values of its children is
// performing one ply of minimax over the table. That is only meaningful where
// the table satisfies the history-free Bellman identity: for every legal,
// non-settled (position P, side),
//
//     V0(P, side) == best_side( { V0(child, -side) : child legal }
//                               U { V1(P, -side) } )        [the pass edge]
//     V1(P, s)    == best_s   ( { V0(child, -s) } U { area_score(P) } )
//
// This sweep measures where it holds. It reads the artifact ALONE — no history,
// no search, no reference solver — so it is cheap and it cannot be wrong about
// the *table*; it only reports what the table says about itself.
//
// WHAT A VIOLATION MEANS (read this before quoting a number): a violation is
// NOT automatically a bug. Each ko-sensitive slot holds an INDEPENDENT
// fresh-start positional-superko solve: V0(child) was computed as if the game
// restarted at `child` with an empty history, so it is not obliged to agree
// with V0(P) via a history-free edge. Violations are therefore EXPECTED in the
// ko-sensitive (L<H) region and are the C2 falsification restated per slot.
//
// The load-bearing output is the last two lines:
//   * violations OUTSIDE ko-sensitive MUST be 0 — a nonzero count convicts the
//     single-score region and is a real bug (this is FP1 acceptance check 3,
//     docs/epistemic/boards/4x4/EPISTEMIC.md).
//   * violations WITHIN ko-sensitive is the region's MISPRICE RATE: the share
//     of ko-sensitive slots whose stored value a one-ply table player would
//     find contradicted, and `max |stored - bellman|` is how badly.
//
// Two move sets are reported, because the generator uses both:
//   full     -- every legal goban move (retrograde `converge`)
//   eyeprune -- ADR-0006 own-true-eye moves dropped (the forward finisher)
// A slot counted under BOTH is unambiguously mispriced under either reading.
//
// usage: weizigo-chainability <artifact.wzo> [--sample N] [--examples K]
//   --sample N   stride: check every N-th colex slot (1 = exhaustive).
//                4x4 exhaustive is ~43M slots; --sample 37 is a 1:37 sample
//                that reproduces M1's 21.32% ko-sensitive fraction to 0.05pp.
//   --examples K print the first K violating positions (default 8).
const std = @import("std");
const version = @import("version");
const rules = @import("rules.zig");
const colexmod = @import("colex.zig");
const artifact = @import("artifact.zig");

const UNDEF: i8 = -128;
const COLS = "ABCDEFGHJKLMNOPQRSTUVWXYZ";

fn Sweep(comptime w: usize, comptime h: usize) type {
    return struct {
        const R = rules.Rules(w, h);
        const X = colexmod.Indexer(w, h);
        const n = R.n;
        const Pos = R.Pos;

        fn v0(d: *const artifact.Decoded, p: *const Pos, side: i8) i8 {
            const i: usize = @intCast(X.colex_from_pos(p));
            return if (side > 0) d.vb[i] else d.vw[i];
        }
        fn v1(d: *const artifact.Decoded, p: *const Pos, side: i8, eyeprune: bool) i8 {
            const maxing = side > 0;
            var best: i8 = R.area_score(p);
            const alive = if (eyeprune) R.benson_alive(p, side) else [_]bool{false} ** n;
            for (0..n) |c| {
                if (p[c] != 0) continue;
                if (eyeprune and R.is_own_eye(p, c, side, &alive)) continue;
                const ch = R.pos_from_move(p, side, c) catch continue;
                const v = v0(d, &ch, -side);
                if (v == UNDEF) continue;
                if (if (maxing) v > best else v < best) best = v;
            }
            return best;
        }
        /// Bellman right-hand side of V0(p, side).
        fn rhs(d: *const artifact.Decoded, p: *const Pos, side: i8, eyeprune: bool) i8 {
            const maxing = side > 0;
            var best: i8 = v1(d, p, -side, eyeprune); // pass edge -> V1 for the opponent
            const alive = if (eyeprune) R.benson_alive(p, side) else [_]bool{false} ** n;
            for (0..n) |c| {
                if (p[c] != 0) continue;
                if (eyeprune and R.is_own_eye(p, c, side, &alive)) continue;
                const ch = R.pos_from_move(p, side, c) catch continue;
                const v = v0(d, &ch, -side);
                if (v == UNDEF) continue;
                if (if (maxing) v > best else v < best) best = v;
            }
            return best;
        }
        fn show(p: *const Pos, buf: []u8) []u8 {
            var o: usize = 0;
            for (0..h) |r| {
                for (0..w) |c| {
                    buf[o] = if (p[r * w + c] > 0) 'X' else if (p[r * w + c] < 0) 'O' else '.';
                    o += 1;
                }
                if (r + 1 < h) {
                    buf[o] = '/';
                    o += 1;
                }
            }
            return buf[0..o];
        }

        fn run(d: *const artifact.Decoded, sample: u64, examples: usize) !void {
            var legal: u64 = 0;
            var settled_n: u64 = 0;
            var checked: u64 = 0;
            var bad_full: u64 = 0;
            var bad_eye: u64 = 0;
            var bad_both: u64 = 0;
            var bad_both_ko: u64 = 0; // violations on KO_SENSITIVE-flagged slots
            var ko_slots: u64 = 0;   // KO_SENSITIVE-flagged slots in the sample
            var settled_ko: u64 = 0; // KO_SENSITIVE-flagged slots on SETTLED positions
            var max_gap: i16 = 0;
            var shown: usize = 0;
            var i: u64 = 0;
            const total: u64 = X.total;
            while (i < total) : (i += sample) {
                const pos = X.pos_from_colex(i);
                if (d.vb[@intCast(i)] == UNDEF and d.vw[@intCast(i)] == UNDEF) continue;
                legal += 1;
                const st = R.is_settled(&pos);
                if (st) {
                    settled_n += 1;
                    // Settled slots are exempt from the identity check (V0 ==
                    // area_score there by definition). Count their flags anyway:
                    // the census and this sweep use different denominators, and
                    // whether any settled slot is KO_SENSITIVE is exactly what
                    // reconciles them. Measured, not inferred.
                    inline for (.{ @as(i8, 1), @as(i8, -1) }) |sd| {
                        const idxs: usize = @intCast(i);
                        const fs = if (sd > 0) d.fb[idxs] else d.fw[idxs];
                        const vs = if (sd > 0) d.vb[idxs] else d.vw[idxs];
                        if (vs != UNDEF and fs & 1 != 0) settled_ko += 1;
                    }
                    continue;
                }
                inline for (.{ @as(i8, 1), @as(i8, -1) }) |side| {
                    const stored = v0(d, &pos, side);
                    if (stored != UNDEF) {
                        checked += 1;
                        {
                            const idx0: usize = @intCast(i);
                            const f0 = if (side > 0) d.fb[idx0] else d.fw[idx0];
                            if (f0 & 1 != 0) ko_slots += 1;
                        }
                        const rf = rhs(d, &pos, side, false);
                        const re = rhs(d, &pos, side, true);
                        const bf = rf != stored;
                        const be = re != stored;
                        if (bf) bad_full += 1;
                        if (be) bad_eye += 1;
                        if (bf and be) {
                            bad_both += 1;
                            const idx: usize = @intCast(i);
                            const flags = if (side > 0) d.fb[idx] else d.fw[idx];
                            if (flags & 1 != 0) bad_both_ko += 1;
                            const gap = @abs(@as(i16, rf) - @as(i16, stored));
                            if (gap > max_gap) max_gap = @intCast(gap);
                            if (shown < examples) {
                                shown += 1;
                                var bb: [64]u8 = undefined;
                                std.debug.print("  {s}  {s} to move: stored={d:>4}  bellman(full)={d:>4}  bellman(eyeprune)={d:>4}  ko_sens={}\n", .{
                                    show(&pos, &bb),
                                    if (side > 0) "B" else "W",
                                    stored,
                                    rf,
                                    re,
                                    flags & 1 != 0,
                                });
                            }
                        }
                    }
                }
            }
            std.debug.print("\nsampled positions:      {d} (stride {d} over {d} colex slots)\n", .{ legal + settled_n, sample, total });
            // `legal` is incremented BEFORE the settled `continue`, so it is the
            // plain legal-position count. Label it as such: calling it
            // "legal, non-settled" was wrong and fed a denominator mix-up
            // across the docs (the 21.32 / 21.33 / 21.27 confusion, 2026-07-28).
            std.debug.print("  legal positions:      {d}\n", .{legal});
            std.debug.print("  non-settled:          {d}  <- positions actually identity-checked\n", .{legal - settled_n});
            std.debug.print("  settled (exempt):     {d}  ({d} of their slots are KO_SENSITIVE-flagged)\n", .{ settled_n, settled_ko });
            std.debug.print("(position, side) slots checked: {d}\n", .{checked});
            std.debug.print("  violations, full move set:     {d}\n", .{bad_full});
            std.debug.print("  violations, eyeprune move set: {d}\n", .{bad_eye});
            std.debug.print("  violations under BOTH:         {d}   <-- unambiguous\n", .{bad_both});
            std.debug.print("    of which KO_SENSITIVE-flagged: {d}\n", .{bad_both_ko});
            std.debug.print("  max |stored - bellman|:        {d} points\n", .{max_gap});
            const pct: f64 = if (checked == 0) 0 else 100.0 * @as(f64, @floatFromInt(bad_both)) / @as(f64, @floatFromInt(checked));
            std.debug.print("  BOTH-violation rate:           {d:.4}% of all checked slots\n", .{pct});
            std.debug.print("KO_SENSITIVE-flagged slots:     {d} ({d:.2}% of checked)\n", .{
                ko_slots, if (checked == 0) 0.0 else 100.0 * @as(f64, @floatFromInt(ko_slots)) / @as(f64, @floatFromInt(checked)),
            });
            std.debug.print("  violations WITHIN ko-sensitive: {d:.2}%   <-- the region's misprice rate\n", .{
                if (ko_slots == 0) 0.0 else 100.0 * @as(f64, @floatFromInt(bad_both)) / @as(f64, @floatFromInt(ko_slots)),
            });
            std.debug.print("  violations OUTSIDE ko-sensitive: {d}   <-- must be 0\n", .{bad_both - bad_both_ko});
            // The verdict judges only the falsifiable claim. Ko-sensitive
            // violations are expected (independent fresh-start solves, C2
            // falsified); a violation in the single-score region is a bug.
            std.debug.print("\nverdict: {s}\n", .{if (bad_both - bad_both_ko == 0)
                "PASS — single-score (L==H) region is chainable; ko-sensitive violations are expected (see header)"
            else
                "FAIL — the single-score region contradicts itself (FP1 check 3 violated)"});
        }
    };
}

pub fn main(init: std.process.Init) !void {
    std.debug.print("{s}\n", .{version.banner("weizigo-chainability")});
    const gpa = std.heap.page_allocator;
    const io = init.io;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    const path = args.next() orelse return error.NoArtifact;
    var sample: u64 = 1;
    var examples: usize = 8;
    while (args.next()) |a| {
        if (std.mem.eql(u8, a, "--sample")) {
            sample = std.fmt.parseInt(u64, args.next() orelse "1", 10) catch 1;
        } else if (std.mem.eql(u8, a, "--examples")) {
            examples = std.fmt.parseInt(usize, args.next() orelse "8", 10) catch 8;
        }
    }
    if (sample == 0) sample = 1;

    var dec = try artifact.load(io, std.Io.Dir.cwd(), path, gpa);
    defer dec.deinit();
    std.debug.print("chainability audit: {s} ({d}x{d}, {d} legal/side)\n\n", .{
        path, dec.header.board_w, dec.header.board_h, dec.header.legal_count,
    });
    const key = @as(usize, dec.header.board_w) * 100 + dec.header.board_h;
    switch (key) {
        202 => try Sweep(2, 2).run(&dec, sample, examples),
        302 => try Sweep(3, 2).run(&dec, sample, examples),
        303 => try Sweep(3, 3).run(&dec, sample, examples),
        403 => try Sweep(4, 3).run(&dec, sample, examples),
        404 => try Sweep(4, 4).run(&dec, sample, examples),
        else => return error.Unsupported,
    }
}
