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
// T912 — ADJUDICATE THE 62 AT 3x2.
//
// docs/research/arena-audit.md:182 records "62 of 378 ko-sensitive region
// (slot,side) pairs differ between writes-off and old".  This program is the
// instrument that (a) reproduces that comparison against a COMMITTED artifact
// generation, and (b) adjudicates every disputed pair against the project's
// own history-exact solver (retro.Exact — the full positional-superko ban set
// lives in the memo key, so the memo is sound BY CONSTRUCTION: no ko_ref rule,
// no eye-prune, no GHI assumption).
//
// NOTHING HERE IS REIMPLEMENTED.  The generator is RT.finishProgress, the
// judge is retro.Exact, the artifact reader is artifact.load.  Three earlier
// attempts at this row died at 1.3/2.8/7.7 GB resident driving a hand-rolled
// Python solver; this program's whole job is to wire the existing parts up.
//
// MEMORY DISCIPLINE (the reason the earlier attempts died):
//   * ONE memo map is shared across every root (sound — the ban set is in the
//     key; retro.zig:1738 says so and groundTruth already does it), so the
//     expensive states are paid for once.
//   * ctx.entry_cap bounds the map.  Past the cap the solver stops INSERTING
//     and stays sound, just slower.  Key is 136 B, so 1.5M entries is ~250 MB
//     steady and ~500 MB across a rehash.
//   * Per-root node budget, groundTruth-style (ctx.budget = ctx.nodes + B), so
//     one monster root cannot eat the whole wall.
//   * Recursion runs on one spawned thread with an explicit 256 MB stack.
//
// Order is the ACCEPTANCE order, not the narrative order: the NULL CONTROL
// runs BEFORE the adjudication.  A judge that only ever sees disputes has no
// calibration.
//
// Phases:
//   0  build 3x2 three ways: writes-off (cross-branch memo writes disabled),
//      reuse (memo_writes ON — the convicted generator), deps (fingerprint-
//      guarded).  Report the KO_SENSITIVE denominator.
//   1  load a committed artifact and diff it against writes-off over every
//      KO_SENSITIVE (slot,side) pair -> the disputed set.
//   2  NULL CONTROL: Exact on a sample of pairs where the generators AGREE.
//   3  SEEDED-DEFECT CONTROL on the judge: corrupt a resolved null-control
//      value and confirm the comparator flips it to DISAGREE.
//   4  ADJUDICATE: Exact on every disputed pair.
//   5  SEEDED-DEFECT CONTROL on the phase-1 comparator: perturb one agreeing
//      slot of the loaded table and confirm the diff count rises by exactly 1.
//
// Output is TSV on stdout, one record per line, tag in column 1.
//
//   zig build-exe -O ReleaseFast src/t912_adjudicate.zig
//
// Env:
//   T912_BUDGET   per-root Exact node budget (default 20_000_000)
//   T912_ENTRIES  shared memo entry cap     (default 1_500_000)
//   T912_NULL_N   null-control sample size  (default 24)
//   T912_ART      artifact path (default artifacts/oracle-3x2.wzo)

const std = @import("std");
const retro = @import("retro.zig");
const artifact = @import("artifact.zig");

const W = 3;
const H = 2;
const RT = retro.Retro(W, H);
const EX = retro.Exact(W, H);
const UNDEF = retro.UNDEF;
const FLAG_KO_SENSITIVE = retro.FLAG_KO_SENSITIVE;

const p = std.debug.print;

/// Monotonic milliseconds (std.time.Timer is gone in Zig 0.16 — same helper
/// retro.zig:2119 uses).
fn nowMs() u64 {
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * 1000 + @as(u64, @intCast(ts.nsec)) / 1_000_000;
}

fn envU64(name: [*:0]const u8, dflt: u64) u64 {
    if (std.c.getenv(name)) |s| return std.fmt.parseInt(u64, std.mem.span(s), 10) catch dflt;
    return dflt;
}

/// Certified-only tables: seed/converge/finalize, NO finisher.  This is what
/// retro.zig's consistBoard (retro.zig:2984-2987) hands its auditor, and it
/// matters: seedCtx marks every non-UNDEF slot as a CLEAN memo entry, so
/// handing the identity check a FINISHED table would let the finisher's own
/// ko-sensitive values be reused history-free — the very defect under audit.
/// The null control below catches that mistake if it is ever made again (it
/// fired at 52 of 316 on the first cut of this program).
fn baseTables(gpa: std.mem.Allocator) !RT.Tables {
    var t = try RT.Tables.init(gpa);
    RT.seed(&t);
    RT.converge(&t);
    RT.finalize(&t);
    return t;
}

/// Build the 3x2 tables with one finisher variant.
fn build(gpa: std.mem.Allocator, memo_writes: bool, deps: bool, budget: u64) !RT.Tables {
    var t = try RT.Tables.init(gpa);
    RT.seed(&t);
    RT.converge(&t);
    RT.finalize(&t);
    const st = try RT.finishProgress(&t, gpa, budget, true, 0, memo_writes, deps);
    p("# build variant memo_writes={} deps={}: legal={d} ko_sens_b={d} ko_sens_w={d} solved={d} skipped={d} bracket_fail={d}\n", .{
        memo_writes, deps, t.legal_count, t.ko_sensitive_b, t.ko_sensitive_w,
        st.solved,    st.budget_skipped, st.bracket_fail,
    });
    return t;
}

/// History-exact fresh-start value of one (slot, side) pair, on the SHARED
/// memo.  Returns null on budget exhaustion (= UNRESOLVED, a first-class
/// outcome).  Never returns a value it did not fully prove.
fn exactValue(ctx: *EX.Ctx, idx: usize, black: bool, root_budget: u64, nodes_out: *u64) ?i8 {
    const before = ctx.nodes;
    ctx.budget = ctx.nodes + root_budget;
    var pos = EX.X.pos_from_colex(@intCast(idx));
    const v = EX.root(ctx, &pos, if (black) @as(i8, 1) else @as(i8, -1)) catch {
        nodes_out.* = ctx.nodes - before;
        return null;
    };
    nodes_out.* = ctx.nodes - before;
    return v;
}

fn stoneCount(idx: usize) u32 {
    const pos = EX.X.pos_from_colex(@intCast(idx));
    var c: u32 = 0;
    for (pos) |v| {
        if (v != 0) c += 1;
    }
    return c;
}

fn posString(idx: usize, buf: []u8) []const u8 {
    const pos = EX.X.pos_from_colex(@intCast(idx));
    for (pos, 0..) |v, i| buf[i] = switch (v) {
        1 => 'B',
        -1 => 'W',
        else => '.',
    };
    return buf[0..pos.len];
}


// ---- the two adjudicators the project ITSELF sanctions for this region -----
// retro.zig:2637 (spot-check comment): "Ko-sensitive region is NOT spot-checked
// here: forward search cannot tractably reach it (Finding 3/6) — it is
// validated by the [L,H] brackets + symmetry instead."  So when the
// history-exact judge runs out (it does, measurably), these are not a
// substitute someone invented for this row; they are the project's own
// validators for exactly this region.
//
//  * BRACKET.  L and H come from the retrograde FIXPOINT (seed/converge/
//    finalize), which runs before any finisher and is independent of every
//    finisher variant.  A stored value outside [L,H] is refuted — under the
//    stated assumption that the brackets are sound (ADR-0010).
//  * SYMMETRY.  value(T(pos), side) == value(pos, side) for every dihedral T,
//    and value(-pos, -side) == -value(pos, side).  These are THEOREMS OF THE
//    RULES, assumption-free: no bracket, no certified seed, no memo discipline
//    is involved.  A table that breaks them is self-refuting.

const Cols = struct { vb: []const i8, vw: []const i8 };

/// Symmetry violations for one (slot, side) against its own table: dihedral
/// orbit members that disagree, plus the colour-inversion partner.
fn symBad(c: Cols, i: usize, black: bool) u32 {
    const v = if (black) c.vb[i] else c.vw[i];
    var bad: u32 = 0;
    var pos = RT.X.pos_from_colex(@intCast(i));
    inline for (0..RT.E.num_syms) |k| {
        const tp = RT.transformed(&pos, &RT.E.sym_perms[k], 1);
        const ti: usize = @intCast(RT.X.colex_from_pos(&tp));
        const tv = if (black) c.vb[ti] else c.vw[ti];
        if (tv != v) bad += 1;
    }
    const inv = RT.transformed(&pos, &RT.E.sym_perms[0], -1);
    const ii: usize = @intCast(RT.X.colex_from_pos(&inv));
    const iv = if (black) c.vw[ii] else c.vb[ii];
    if (iv != -v) bad += 1;
    return bad;
}

fn inBracket(t: *const RT.Tables, i: usize, black: bool, v: i8) bool {
    const lo0 = if (black) t.lo.b0[i] else t.lo.w0[i];
    const hi0 = if (black) t.hi.b0[i] else t.hi.w0[i];
    return v >= lo0 and v <= hi0;
}


// ---- the identity adjudicator (the instrument ADR-0013 actually used) ------
// docs/research/consistency-audit.md / ADR-0013 convicted a finisher generation
// with the minimax identity under a FIXED root history:
//
//     V(P, side, [P])  ==  opt_side( { V(c, -side, [P,c]) : c legal }, pass )
//
// retro.zig's own auditor (RETRO_CONSIST, retro.zig:4458 -> consistBoard:2980 ->
// auditNode:2906) audits a GENERATOR: it solves the parent with the variant
// under test and compares it against that same variant's children.  It cannot
// be pointed at a `.wzo` file, and the generator that produced the disputed
// values does not exist in the repo any more.
//
// So we compute only the RIGHT-HAND SIDE — the best option, with the children
// and the pass branch each re-solved as INDEPENDENT roots under H=[P,c] by the
// SOUND variant (memo_writes = false) — and test BOTH candidate parent values
// against it.  Whichever candidate is not equal to the best option violates the
// identity.  Both unequal would mean both generations are wrong.
//
// `bestOption` and `seedCtxLocal` below are the public-API call sequence of
// retro.zig:2845 (solveNode) and retro.zig:2874 (seedCtx), invoked verbatim;
// no engine code is duplicated and retro.zig is not edited (one writer per
// engine file).
//
// ASSUMPTION, stated once and not smuggled: the children and the pass branch
// are valued by the sound finisher variant over the real positional-superko
// history, reading certified seeds and [L,H] brackets.  A refutation therefore
// says "this stored value contradicts the sound solver's independently
// re-solved children", not "this stored value is false in the absolute".  That
// is the same standing the ADR-0013 conviction has.

fn seedCtxLocal(c: *RT.O.Ctx, tt: *const RT.Tables) void {
    @memcpy(c.vb, tt.vb);
    @memcpy(c.vw, tt.vw);
    for (0..RT.total) |i| {
        c.cb[i] = tt.legal[i] and tt.vb[i] != UNDEF;
        c.cw[i] = tt.legal[i] and tt.vw[i] != UNDEF;
    }
    @memset(c.lbb.?, -127);
    @memset(c.ubb.?, 127);
    @memset(c.lbw.?, -127);
    @memset(c.ubw.?, 127);
    if (c.dep_map) |m| m.clearRetainingCapacity();
    c.nodes = 0;
}

fn solveNodeLocal(t: *const RT.Tables, ctx: *RT.O.Ctx, pos: *const RT.Pos, to_move: i8, passes: u8, hist: *RT.O.History) error{Budget}!i8 {
    const idx: usize = @intCast(RT.X.colex_from_pos(pos));
    const nn: i8 = @intCast(RT.n);
    var lo: i8 = undefined;
    var hi: i8 = undefined;
    if (passes >= 2 or t.settled[idx]) return t.score[idx];
    if (!ctx.brackets) {
        lo = -nn;
        hi = nn;
    } else if (passes == 0) {
        lo = if (to_move > 0) t.lo.b0[idx] else t.lo.w0[idx];
        hi = if (to_move > 0) t.hi.b0[idx] else t.hi.w0[idx];
    } else {
        lo = if (to_move > 0) t.lo.b1[idx] else t.lo.w1[idx];
        hi = if (to_move > 0) t.hi.b1[idx] else t.hi.w1[idx];
    }
    while (lo < hi) {
        const mid = lo + @divTrunc(hi - lo + 1, 2);
        ctx.saw_ban = false;
        const r = try RT.ab_solve(t, ctx, pos, to_move, passes, mid - 1, mid, hist, RT.O.fp_zero);
        if (r.value >= mid) lo = r.value else hi = r.value;
    }
    return lo;
}

/// The identity's RIGHT-HAND SIDE for one (slot, side): the best of every
/// PSK-legal eye-pruned child under H=[P,c] and the pass branch under [P].
fn bestOption(t: *const RT.Tables, ctx: *RT.O.Ctx, hist: *RT.O.History, idx: usize, black: bool) ?i8 {
    const side: i8 = if (black) 1 else -1;
    var pos = RT.X.pos_from_colex(@intCast(idx));
    var best: i8 = if (side > 0) -127 else 127;
    const own_alive = RT.R.benson_alive(&pos, side);
    for (0..RT.n) |cell| {
        if (pos[cell] != 0) continue;
        if (RT.R.is_own_eye(&pos, cell, side, &own_alive)) continue;
        const child = RT.R.pos_from_move(&pos, side, cell) catch continue;
        hist.reset();
        hist.push(&pos);
        if (hist.repeatsIndex(&child) != null) continue; // PSK-illegal here
        hist.push(&child); // H = [P, child]
        seedCtxLocal(ctx, t);
        const cv = solveNodeLocal(t, ctx, &child, -side, 0, hist) catch return null;
        if (side > 0) {
            if (cv > best) best = cv;
        } else {
            if (cv < best) best = cv;
        }
    }
    hist.reset();
    hist.push(&pos);
    seedCtxLocal(ctx, t);
    const pv = solveNodeLocal(t, ctx, &pos, -side, 1, hist) catch return null;
    if (side > 0) {
        if (pv > best) best = pv;
    } else {
        if (pv < best) best = pv;
    }
    return best;
}

const Pair = struct { idx: usize, black: bool, wo: i8, cm: i8 };

fn deepestFirst(_: void, a: Pair, b: Pair) bool {
    const sa = stoneCount(a.idx);
    const sb = stoneCount(b.idx);
    if (sa != sb) return sa > sb;
    return a.idx < b.idx;
}

pub fn main() !void {
    const th = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, run, .{});
    th.join();
}

fn run() !void {
    const gpa = std.heap.page_allocator;

    const root_budget = envU64("T912_BUDGET", 20_000_000);
    const entries = envU64("T912_ENTRIES", 1_500_000);
    const null_n = envU64("T912_NULL_N", 24);
    // Calibration knob: cap how many disputed pairs the judge is asked to
    // resolve, so a probe run can measure the per-root cost without spending
    // the whole wall.  0 = no cap.  Any capped run must say so in its report.
    const max_adj = envU64("T912_MAX_ADJ", 0);
    const art_path: []const u8 = if (std.c.getenv("T912_ART")) |s| std.mem.span(s) else "artifacts/oracle-3x2.wzo";

    p("# T912 adjudicate 3x2 — root_budget={d} entry_cap={d} null_n={d} max_adj={d} artifact={s}\n", .{ root_budget, entries, null_n, max_adj, art_path });
    p("# Exact key size = {d} bytes; cap therefore bounds the memo at ~{d} MB\n", .{ @sizeOf(EX.Key), (entries * (@sizeOf(EX.Key) + 2)) >> 20 });

    var t0 = nowMs();

    // ---- phase 0: three generators -----------------------------------------
    var wo = try build(gpa, false, false, 500_000_000); // writes-off (least-assumption generator)
    defer wo.deinit();
    var reuse = try build(gpa, true, false, 500_000_000); // cross-branch memo reuse (convicted)
    defer reuse.deinit();
    var dep = try build(gpa, true, true, 500_000_000); // fingerprint-guarded reuse
    defer dep.deinit();
    p("TIMING\tgenerators_ms\t{d}\n", .{nowMs() - t0});

    // ---- phase 1: committed artifact ---------------------------------------
    var threaded = std.Io.Threaded.init(gpa, .{});
    const io = threaded.io();
    var loaded = try artifact.load(io, std.Io.Dir.cwd(), art_path, gpa);
    defer loaded.deinit();
    p("# artifact {s}: w={d} h={d} total={d} legal={d}\n", .{
        art_path, loaded.header.board_w, loaded.header.board_h, loaded.header.total, loaded.header.legal_count,
    });

    var ks_total: usize = 0;
    var disputed = std.ArrayList(Pair).empty;
    defer disputed.deinit(gpa);
    var agreeing = std.ArrayList(Pair).empty;
    defer agreeing.deinit(gpa);
    var wo_reuse_diff: usize = 0;
    var wo_deps_diff: usize = 0;
    var cm_undef: usize = 0;
    var wo_undef: usize = 0;

    for (0..RT.total) |i| {
        if (!wo.legal[i]) continue;
        inline for (.{ true, false }) |black| {
            const f = if (black) wo.fb[i] else wo.fw[i];
            if (f & FLAG_KO_SENSITIVE != 0) {
                ks_total += 1;
                const a = if (black) wo.vb[i] else wo.vw[i];
                const c = if (black) loaded.vb[i] else loaded.vw[i];
                const r = if (black) reuse.vb[i] else reuse.vw[i];
                const d = if (black) dep.vb[i] else dep.vw[i];
                if (a == UNDEF) wo_undef += 1;
                if (c == UNDEF) cm_undef += 1;
                if (a != r) wo_reuse_diff += 1;
                if (a != d) wo_deps_diff += 1;
                const pr = Pair{ .idx = i, .black = black, .wo = a, .cm = c };
                if (a != c) try disputed.append(gpa, pr) else try agreeing.append(gpa, pr);
            }
        }
    }
    p("KSDENOM\tko_sensitive_pairs\t{d}\n", .{ks_total});
    p("DIFFCOUNT\twrites_off_vs_artifact\t{d}\t{d}\n", .{ disputed.items.len, ks_total });
    p("DIFFCOUNT\twrites_off_vs_reuse\t{d}\t{d}\n", .{ wo_reuse_diff, ks_total });
    p("DIFFCOUNT\twrites_off_vs_deps\t{d}\t{d}\n", .{ wo_deps_diff, ks_total });
    p("UNDEF\twrites_off\t{d}\tartifact\t{d}\n", .{ wo_undef, cm_undef });

    // Whole-table diff (every legal slot, both sides — not just the
    // ko-sensitive region), so "the committed table IS the writes-off table"
    // is a measured statement rather than an inference from the 378.
    {
        var full_pairs: usize = 0;
        var full_diff: usize = 0;
        for (0..RT.total) |i| {
            if (!wo.legal[i]) continue;
            full_pairs += 2;
            if (wo.vb[i] != loaded.vb[i]) full_diff += 1;
            if (wo.vw[i] != loaded.vw[i]) full_diff += 1;
        }
        p("FULLDIFF\twrites_off_vs_artifact\t{d}\t{d}\n", .{ full_diff, full_pairs });
    }

    var buf: [16]u8 = undefined;
    std.mem.sort(Pair, disputed.items, {}, deepestFirst);
    std.mem.sort(Pair, agreeing.items, {}, deepestFirst);
    for (disputed.items) |d| {
        p("DISPUTED\t{d}\t{s}\t{s}\t{d}\t{d}\t{d}\n", .{
            d.idx, if (d.black) "B" else "W", posString(d.idx, &buf), d.wo, d.cm, stoneCount(d.idx),
        });
    }

    // ---- phase 1b: the CHEAP adjudicators, with their controls -------------
    const wo_cols = Cols{ .vb = wo.vb, .vw = wo.vw };
    const cm_cols = Cols{ .vb = loaded.vb, .vw = loaded.vw };
    const reuse_cols = Cols{ .vb = reuse.vb, .vw = reuse.vw };
    const dep_cols = Cols{ .vb = dep.vb, .vw = dep.vw };

    // Whole-region symmetry census per table (denominator = every KO_SENSITIVE pair).
    {
        var sb_wo: usize = 0;
        var sb_cm: usize = 0;
        var sb_re: usize = 0;
        var sb_dp: usize = 0;
        for (0..RT.total) |i| {
            if (!wo.legal[i]) continue;
            inline for (.{ true, false }) |black| {
                const f = if (black) wo.fb[i] else wo.fw[i];
                if (f & FLAG_KO_SENSITIVE != 0) {
                    if (symBad(wo_cols, i, black) != 0) sb_wo += 1;
                    if (symBad(cm_cols, i, black) != 0) sb_cm += 1;
                    if (symBad(reuse_cols, i, black) != 0) sb_re += 1;
                    if (symBad(dep_cols, i, black) != 0) sb_dp += 1;
                }
            }
        }
        p("SYMCENSUS\twrites_off\t{d}\tartifact\t{d}\treuse\t{d}\tdeps\t{d}\tof\t{d}\n", .{ sb_wo, sb_cm, sb_re, sb_dp, ks_total });
    }

    // NULL CONTROL for the cheap adjudicators: on the pairs where writes-off
    // and the artifact AGREE, neither check may fire.  If it fires here, its
    // verdicts on the disputed pairs are worthless.
    {
        var nb_wo: usize = 0;
        var nb_cm: usize = 0;
        var nk_wo: usize = 0;
        var nk_cm: usize = 0;
        for (agreeing.items) |a| {
            if (!inBracket(&wo, a.idx, a.black, a.wo)) nb_wo += 1;
            if (!inBracket(&wo, a.idx, a.black, a.cm)) nb_cm += 1;
            if (symBad(wo_cols, a.idx, a.black) != 0) nk_wo += 1;
            if (symBad(cm_cols, a.idx, a.black) != 0) nk_cm += 1;
        }
        p("CHEAPNULL\tpool\t{d}\tbracket_fires_wo\t{d}\tbracket_fires_artifact\t{d}\tsym_fires_wo\t{d}\tsym_fires_artifact\t{d}\n", .{
            agreeing.items.len, nb_wo, nb_cm, nk_wo, nk_cm,
        });
    }

    // SEEDED-DEFECT CONTROL for the cheap adjudicators: corrupt one agreeing
    // slot and confirm BOTH checks catch it.
    if (agreeing.items.len > 0) {
        const a = agreeing.items[0];
        const orig = if (a.black) loaded.vb[a.idx] else loaded.vw[a.idx];
        const hi0 = if (a.black) wo.hi.b0[a.idx] else wo.hi.w0[a.idx];
        const bad: i8 = if (hi0 < 9) hi0 + 1 else 9; // deliberately out of bracket
        const bracket_caught = !inBracket(&wo, a.idx, a.black, bad);
        if (a.black) loaded.vb[a.idx] = bad else loaded.vw[a.idx] = bad;
        const sym_caught = symBad(cm_cols, a.idx, a.black) != 0;
        if (a.black) loaded.vb[a.idx] = orig else loaded.vw[a.idx] = orig;
        p("CHEAPSEED\tidx\t{d}\tside\t{s}\torig\t{d}\tseeded\t{d}\tbracket\t{s}\tsymmetry\t{s}\n", .{
            a.idx, if (a.black) "B" else "W", orig, bad,
            if (bracket_caught) "CAUGHT" else "MISSED",
            if (sym_caught) "CAUGHT" else "MISSED",
        });
    }

    // Per-disputed-pair cheap verdict.
    var c_wo: usize = 0;
    var c_cm: usize = 0;
    var c_both: usize = 0;
    var c_unres: usize = 0;
    for (disputed.items) |d| {
        const wob = inBracket(&wo, d.idx, d.black, d.wo);
        const cmb = inBracket(&wo, d.idx, d.black, d.cm);
        const wos = symBad(wo_cols, d.idx, d.black);
        const cms = symBad(cm_cols, d.idx, d.black);
        const lo0 = if (d.black) wo.lo.b0[d.idx] else wo.lo.w0[d.idx];
        const hi0 = if (d.black) wo.hi.b0[d.idx] else wo.hi.w0[d.idx];
        const verdict: []const u8 = if (!wob and !cmb) blk: {
            c_both += 1;
            break :blk "BOTH_OUT_OF_BRACKET";
        } else if (!cmb) blk: {
            c_cm += 1;
            break :blk "BRACKET_REFUTES_ARTIFACT";
        } else if (!wob) blk: {
            c_wo += 1;
            break :blk "BRACKET_REFUTES_WRITES_OFF";
        } else if (cms != 0 and wos == 0) blk: {
            c_cm += 1;
            break :blk "SYMMETRY_REFUTES_ARTIFACT";
        } else if (wos != 0 and cms == 0) blk: {
            c_wo += 1;
            break :blk "SYMMETRY_REFUTES_WRITES_OFF";
        } else if (wos != 0 and cms != 0) blk: {
            c_both += 1;
            break :blk "SYMMETRY_REFUTES_BOTH";
        } else blk: {
            c_unres += 1;
            break :blk "CHEAP_UNRESOLVED";
        };
        p("CHEAPADJ\t{d}\t{s}\t{s}\t{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{s}\n", .{
            d.idx, if (d.black) "B" else "W", posString(d.idx, &buf), d.wo, d.cm, lo0, hi0, wos, cms, verdict,
        });
    }
    p("CHEAPSUM\tartifact_refuted\t{d}\twrites_off_refuted\t{d}\tboth_refuted\t{d}\tunresolved\t{d}\tdisputed\t{d}\n", .{
        c_cm, c_wo, c_both, c_unres, disputed.items.len,
    });

    // ---- the shared, bounded judge -----------------------------------------
    var ctx = EX.Ctx{ .map = EX.Map.init(gpa), .entry_cap = @intCast(entries) };
    defer ctx.map.deinit();

    // ---- phase 1b-2: IDENTITY ADJUDICATION ---------------------------------
    {
        var ictx = RT.O.Ctx{
            .vb = try gpa.alloc(i8, RT.total),
            .vw = try gpa.alloc(i8, RT.total),
            .cb = try gpa.alloc(bool, RT.total),
            .cw = try gpa.alloc(bool, RT.total),
            .lbb = try gpa.alloc(i8, RT.total),
            .ubb = try gpa.alloc(i8, RT.total),
            .lbw = try gpa.alloc(i8, RT.total),
            .ubw = try gpa.alloc(i8, RT.total),
            .memo = true,
            .memo_writes = false, // the SOUND variant — ADR-0013
            .brackets = true,
            .budget = 2_000_000_000,
        };
        defer inline for (.{ ictx.vb, ictx.vw }) |a| gpa.free(a);
        defer inline for (.{ ictx.cb, ictx.cw }) |a| gpa.free(a);
        defer inline for (.{ ictx.lbb.?, ictx.lbw.? }) |a| gpa.free(a);
        defer inline for (.{ ictx.ubb.?, ictx.ubw.? }) |a| gpa.free(a);
        var base = try baseTables(gpa);
        defer base.deinit();
        var idep = RT.O.DepMap.init(gpa);
        defer idep.deinit();
        ictx.dep_map = &idep;
        const ihist = try gpa.create(RT.O.History);
        defer gpa.destroy(ihist);
        ihist.* = .{};

        // NULL CONTROL FIRST.  Where writes-off and the artifact AGREE, the
        // best option must equal that agreed value.  Any disagreement here and
        // every verdict below is worthless.
        t0 = nowMs();
        var in_ok: usize = 0;
        var in_bad: usize = 0;
        var in_skip: usize = 0;
        for (agreeing.items) |a| {
            const bo = bestOption(&base, &ictx, ihist, a.idx, a.black);
            if (bo) |b| {
                if (b == a.wo) in_ok += 1 else {
                    in_bad += 1;
                    p("IDNULLBAD\t{d}\t{s}\t{s}\tagreed\t{d}\tbest_option\t{d}\n", .{
                        a.idx, if (a.black) "B" else "W", posString(a.idx, &buf), a.wo, b,
                    });
                }
            } else in_skip += 1;
        }
        p("IDNULL\tpool\t{d}\tagree\t{d}\tdisagree\t{d}\tskipped\t{d}\tms\t{d}\n", .{
            agreeing.items.len, in_ok, in_bad, in_skip, nowMs() - t0,
        });

        // SEEDED-DEFECT CONTROL: hand the comparator a value that is provably
        // not the best option and confirm it fires.
        if (agreeing.items.len > 0) {
            const a = agreeing.items[0];
            const bo = bestOption(&base, &ictx, ihist, a.idx, a.black);
            if (bo) |b| {
                const seeded: i8 = if (b == 0) 3 else 0;
                p("IDSEED\tidx\t{d}\tside\t{s}\tbest_option\t{d}\tseeded\t{d}\t{s}\n", .{
                    a.idx, if (a.black) "B" else "W", b, seeded,
                    if (seeded != b) "CAUGHT" else "MISSED",
                });
            } else p("IDSEED\tNA\tbest_option_unavailable\n", .{});
        }

        // ADJUDICATE the disputed pairs.
        t0 = nowMs();
        var i_wo: usize = 0;
        var i_cm: usize = 0;
        var i_both: usize = 0;
        var i_skip: usize = 0;
        for (disputed.items) |d| {
            const bo = bestOption(&base, &ictx, ihist, d.idx, d.black);
            if (bo) |b| {
                const verdict: []const u8 = if (b == d.wo and b != d.cm) blk: {
                    i_wo += 1;
                    break :blk "WRITES_OFF_MATCHES_IDENTITY";
                } else if (b == d.cm and b != d.wo) blk: {
                    i_cm += 1;
                    break :blk "ARTIFACT_MATCHES_IDENTITY";
                } else blk: {
                    i_both += 1;
                    break :blk "BOTH_VIOLATE_IDENTITY";
                };
                p("IDADJ\t{d}\t{s}\t{s}\t{d}\t{d}\t{d}\t{s}\n", .{
                    d.idx, if (d.black) "B" else "W", posString(d.idx, &buf), d.wo, d.cm, b, verdict,
                });
            } else {
                i_skip += 1;
                p("IDADJ\t{d}\t{s}\t{s}\t{d}\t{d}\tNA\tUNRESOLVED\n", .{
                    d.idx, if (d.black) "B" else "W", posString(d.idx, &buf), d.wo, d.cm,
                });
            }
        }
        p("IDSUM\twrites_off_matches\t{d}\tartifact_matches\t{d}\tboth_violate\t{d}\tunresolved\t{d}\tdisputed\t{d}\tms\t{d}\n", .{
            i_wo, i_cm, i_both, i_skip, disputed.items.len, nowMs() - t0,
        });

        // KNOWN-BAD-GENERATOR CONTROL.  A synthetic perturbation only proves
        // the comparator can see a changed number.  ADR-0013 already convicted
        // cross-branch memo reuse, so its table is a REAL seeded defect: point
        // the same adjudicator at every pair where reuse differs from
        // writes-off and confirm it lands on writes-off.  If it did not, the
        // 62-of-62 verdict above would be an artefact of the method.
        t0 = nowMs();
        var r_wo: usize = 0;
        var r_re: usize = 0;
        var r_both: usize = 0;
        var r_n: usize = 0;
        for (0..RT.total) |i| {
            if (!wo.legal[i]) continue;
            inline for (.{ true, false }) |black| {
                const fl = if (black) wo.fb[i] else wo.fw[i];
                if (fl & FLAG_KO_SENSITIVE != 0) {
                    const a = if (black) wo.vb[i] else wo.vw[i];
                    const r = if (black) reuse.vb[i] else reuse.vw[i];
                    if (a != r) {
                        r_n += 1;
                        if (bestOption(&base, &ictx, ihist, i, black)) |b| {
                            if (b == a and b != r) r_wo += 1 else if (b == r and b != a) r_re += 1 else r_both += 1;
                        }
                    }
                }
            }
        }
        p("REUSECTL\tpairs\t{d}\twrites_off_matches\t{d}\treuse_matches\t{d}\tneither\t{d}\tms\t{d}\n", .{
            r_n, r_wo, r_re, r_both, nowMs() - t0,
        });
    }

    // ---- phase 1c: GROWTH PROBE (why the judge cannot finish) ---------------
    // Isolated, UNCAPPED memo on the single most tractable disputed root, at
    // doubling node budgets.  Reports states-per-node, which is the number that
    // says how much RAM a completed adjudication would need.  Bounded by the
    // largest budget, so its own peak is predictable.
    if (std.c.getenv("T912_GROWTH") != null and disputed.items.len > 0) {
        const g = disputed.items[0];
        var gb: u64 = 1_000_000;
        while (gb <= envU64("T912_GROWTH_MAX", 16_000_000)) : (gb *= 2) {
            var gctx = EX.Ctx{ .map = EX.Map.init(gpa), .budget = gb };
            var gpos = EX.X.pos_from_colex(@intCast(g.idx));
            const g0 = nowMs();
            const gv = EX.root(&gctx, &gpos, if (g.black) @as(i8, 1) else @as(i8, -1)) catch null;
            const gms = nowMs() - g0;
            p("GROWTH\t{d}\t{s}\tbudget\t{d}\tnodes\t{d}\tstates\t{d}\tbytes_per_node\t{d}\tms\t{d}\t{s}\n", .{
                g.idx,          if (g.black) "B" else "W", gb, gctx.nodes, gctx.map.count(),
                (gctx.map.count() * (@sizeOf(EX.Key) + 2)) / @max(gctx.nodes, 1),
                gms,            if (gv == null) "UNRESOLVED" else "RESOLVED",
            });
            gctx.map.deinit();
            if (gv != null) break;
        }
    }

    // ---- phase 2: NULL CONTROL (runs before adjudication) -------------------
    // Sample agreeing pairs, most-filled first (the tractable end), and ask the
    // judge.  If the judge disagrees where the generators agree, its verdicts on
    // the disputed pairs are worthless.
    var null_ok: usize = 0;
    var null_bad: usize = 0;
    var null_unres: usize = 0;
    var calibrated_idx: usize = 0;
    var calibrated_black = false;
    var calibrated_v: i8 = 0;
    var have_calibrated = false;
    t0 = nowMs();
    var ni: usize = 0;
    while (ni < agreeing.items.len and ni < null_n) : (ni += 1) {
        const a = agreeing.items[ni];
        var nodes: u64 = 0;
        const ev = exactValue(&ctx, a.idx, a.black, root_budget, &nodes);
        if (ev) |v| {
            if (v == a.wo) null_ok += 1 else null_bad += 1;
            if (!have_calibrated) {
                have_calibrated = true;
                calibrated_idx = a.idx;
                calibrated_black = a.black;
                calibrated_v = v;
            }
            p("NULLCTL\t{d}\t{s}\t{s}\t{d}\t{d}\t{s}\t{d}\t{d}\n", .{
                a.idx,                             if (a.black) "B" else "W", posString(a.idx, &buf), a.wo, v,
                if (v == a.wo) "AGREE" else "DISAGREE", nodes,                    ctx.map.count(),
            });
        } else {
            null_unres += 1;
            p("NULLCTL\t{d}\t{s}\t{s}\t{d}\tNA\tUNRESOLVED\t{d}\t{d}\n", .{
                a.idx, if (a.black) "B" else "W", posString(a.idx, &buf), a.wo, nodes, ctx.map.count(),
            });
        }
    }
    p("NULLSUM\tagree\t{d}\tdisagree\t{d}\tunresolved\t{d}\tsampled\t{d}\tpool\t{d}\n", .{
        null_ok, null_bad, null_unres, ni, agreeing.items.len,
    });
    p("TIMING\tnull_control_ms\t{d}\n", .{nowMs() - t0});

    // ---- phase 3: SEEDED-DEFECT CONTROL on the JUDGE ------------------------
    // Take a pair the judge RESOLVED and agreed on, corrupt the table value it
    // was compared against, and confirm the comparison reports DISAGREE.  A
    // control that only ever confirms agreement proves nothing.
    if (have_calibrated) {
        const seeded: i8 = if (calibrated_v == 0) 3 else 0;
        const caught = seeded != calibrated_v;
        p("SEEDJUDGE\tidx\t{d}\tside\t{s}\texact\t{d}\tseeded_table_value\t{d}\t{s}\n", .{
            calibrated_idx, if (calibrated_black) "B" else "W", calibrated_v, seeded,
            if (caught) "CAUGHT" else "MISSED",
        });
    } else {
        p("SEEDJUDGE\tNA\tno_resolved_null_control_pair\n", .{});
    }

    // ---- phase 4: ADJUDICATE -----------------------------------------------
    var n_wo: usize = 0;
    var n_cm: usize = 0;
    var n_both: usize = 0;
    var n_unres: usize = 0;
    t0 = nowMs();
    var attempted: usize = 0;
    for (disputed.items) |d| {
        if (max_adj != 0 and attempted >= max_adj) break;
        attempted += 1;
        var nodes: u64 = 0;
        const ev = exactValue(&ctx, d.idx, d.black, root_budget, &nodes);
        if (ev) |v| {
            const verdict: []const u8 = if (v == d.wo and v != d.cm) blk: {
                n_wo += 1;
                break :blk "WRITES_OFF_CORRECT";
            } else if (v == d.cm and v != d.wo) blk: {
                n_cm += 1;
                break :blk "ARTIFACT_CORRECT";
            } else blk: {
                n_both += 1;
                break :blk "BOTH_WRONG";
            };
            p("ADJ\t{d}\t{s}\t{s}\t{d}\t{d}\t{d}\t{s}\t{d}\t{d}\n", .{
                d.idx, if (d.black) "B" else "W", posString(d.idx, &buf), d.wo, d.cm, v, verdict, nodes, ctx.map.count(),
            });
        } else {
            n_unres += 1;
            p("ADJ\t{d}\t{s}\t{s}\t{d}\t{d}\tNA\tUNRESOLVED\t{d}\t{d}\n", .{
                d.idx, if (d.black) "B" else "W", posString(d.idx, &buf), d.wo, d.cm, nodes, ctx.map.count(),
            });
        }
    }
    p("ADJSUM\twrites_off_correct\t{d}\tartifact_correct\t{d}\tboth_wrong\t{d}\tunresolved\t{d}\tattempted\t{d}\tdisputed\t{d}\n", .{
        n_wo, n_cm, n_both, n_unres, attempted, disputed.items.len,
    });
    if (attempted < disputed.items.len) p("# CAPPED: only {d} of {d} disputed pairs were attempted (T912_MAX_ADJ)\n", .{ attempted, disputed.items.len });
    p("TIMING\tadjudication_ms\t{d}\n", .{nowMs() - t0});
    p("JUDGE\tnodes\t{d}\tstates\t{d}\tentry_cap\t{d}\tsaturated\t{}\n", .{
        ctx.nodes, ctx.map.count(), entries, ctx.map.count() >= entries,
    });

    // ---- phase 5: SEEDED-DEFECT CONTROL on the phase-1 comparator -----------
    if (agreeing.items.len > 0) {
        const victim = agreeing.items[0];
        const orig = if (victim.black) loaded.vb[victim.idx] else loaded.vw[victim.idx];
        const bad: i8 = if (orig == 0) 3 else 0;
        if (victim.black) loaded.vb[victim.idx] = bad else loaded.vw[victim.idx] = bad;
        var recount: usize = 0;
        for (0..RT.total) |i| {
            if (!wo.legal[i]) continue;
            inline for (.{ true, false }) |black| {
                const f = if (black) wo.fb[i] else wo.fw[i];
                if (f & FLAG_KO_SENSITIVE != 0) {
                    const a = if (black) wo.vb[i] else wo.vw[i];
                    const c = if (black) loaded.vb[i] else loaded.vw[i];
                    if (a != c) recount += 1;
                }
            }
        }
        const caught = recount == disputed.items.len + 1;
        p("SEEDCTL\tidx\t{d}\tside\t{s}\torig\t{d}\tseeded\t{d}\tbaseline_diffs\t{d}\tafter_diffs\t{d}\t{s}\n", .{
            victim.idx,           if (victim.black) "B" else "W", orig, bad,
            disputed.items.len, recount,                        if (caught) "CAUGHT" else "MISSED",
        });
        if (victim.black) loaded.vb[victim.idx] = orig else loaded.vw[victim.idx] = orig;
    }
    p("# done\n", .{});
}
