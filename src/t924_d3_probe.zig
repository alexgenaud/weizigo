////////////////////////////////////////////
//                                        //
//    (c) 2026 Alexander E Genaud         //
//                                        //
//    Permission is granted hereby,       //
//    to copy, share, use, modify,        //
//    for purposes any,                   //
//    for free or for money,              //
//    provided these notices multiply.    //
//                                        //
//    This work "as is" I provide,        //
//    no warranty express or implied,     //
//        for, no purpose fit,            //
//    'tis unmerchantable shit.           //
//    Liability for damages denied.       //
////////////////////////////////////////////
//
// T924 — 4×4.D3 writes-off tractability probe (ox-alpha/T924, 2026-08-25).
//
// Question (CLAIMS.md 4x4.D3): is the 4×4 KO_SENSITIVE-column regeneration
// with memo_writes=false (Track A, ADR-0013) *tractable*? Nobody has measured
// it. This instrument measures the per-root cost curve WITHOUT committing to
// a full 4×4 run: it builds the L/H tables once, then systematically samples
// ko-sensitive roots per stone-count layer and times `ab_value_from_root`
// under a per-root node budget — the same solver the real finisher drives.
//
// NOTHING HERE IS REIMPLEMENTED: the driver is RT.ab_value_from_root +
// RT.solveSingleKo exactly as Finisher.runRoot calls them; orbit dedupe uses
// the same transform-marking; the memo/journal discipline is the Finisher's own.
//
// Arms:
//   writes OFF (memo_writes=false, Track A sound mode) — what we measure.
//   writes ON  (memo_writes=true) — calibration arm on the SAME roots.
//
// Instrument acceptance (T924_SELFTEST=1, run at 3x2 BEFORE any 4×4 work):
//   full enumeration at the configured size, diff every solved value against
//   the committed artifact expecting 0 mismatches (T912: HEAD agrees with a
//   fresh writes-off rebuild on all 978), then seed ONE defect (+1 into one
//   solved value) and expect the comparator to catch EXACTLY that one —
//   the known-bad control. Non-zero exit on any failure.
//
// Output: CSV on stdout ("T924" in column 1), diagnostics on stderr.
//
// Env:
//   T924_W / T924_H   goban size (default 4 / 4)
//   T924_BUDGET       per-root node budget (default 20_000_000 = production)
//   T924_SAMPLE       systematic-sample cap per layer over FLAGGED SLOTS;
//                     0 = enumerate fully (default 48). Orbit dedupe via the
//                     transform-marking means a sampled slot may be absorbed
//                     by an earlier sampled slot's orbit (second-order).
//   T924_WRITES       "off" | "on" | "both" (default "off")
//   T924_LAYERS       comma list restricting layers (e.g. "0,1,2")
//   T924_MODE         "sample" (default) | "empty"
//                     empty = empty-goban root (idx 0, layer 0), both sides,
//                     at an escalating budget ladder T924_BUDGETS, writes-off,
//                     plus one writes-on measurement as calibration reference.
//   T924_BUDGETS      ladder for MODE=empty
//                     (default "20000000,100000000,500000000,2000000000")
//   T924_ART          artifact to diff in SELFTEST (default artifacts/oracle-3x2.wzo)
//   T924_SELFTEST     "1" → acceptance sequence above
//
// Build: tools/runner -- zig build-exe -O ReleaseFast src/t924_d3_probe.zig

const std = @import("std");
const util = @import("util.zig");
const retro = @import("retro.zig");
const artifact = @import("artifact.zig");

fn envUsize(comptime name: [:0]const u8, default: usize) usize {
    const s = std.c.getenv(name) orelse return default;
    return std.fmt.parseInt(usize, std.mem.span(s), 10) catch default;
}

fn envStr(comptime name: [:0]const u8, default: []const u8) []const u8 {
    const s = std.c.getenv(name) orelse return default;
    return std.mem.span(s);
}

fn nowMs() u64 {
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * 1000 + @as(u64, @intCast(ts.nsec)) / 1_000_000;
}

fn parseLayerList(spec: []const u8, buf: []usize) usize {
    var count: usize = 0;
    var it = std.mem.splitScalar(u8, spec, ',');
    while (it.next()) |tok| {
        const t = std.mem.trim(u8, tok, " ");
        if (t.len == 0) continue;
        if (count >= buf.len) break;
        buf[count] = std.fmt.parseInt(usize, t, 10) catch continue;
        count += 1;
    }
    return count;
}

fn parseBudgetList(gpa: std.mem.Allocator, spec: []const u8) ![]u64 {
    var list: std.ArrayList(u64) = .empty;
    errdefer list.deinit(gpa);
    var it = std.mem.splitScalar(u8, spec, ',');
    while (it.next()) |tok| {
        const t = std.mem.trim(u8, tok, " ");
        if (t.len == 0) continue;
        const v = std.fmt.parseInt(u64, t, 10) catch continue;
        try list.append(gpa, v);
    }
    return list.toOwnedSlice(gpa);
}

/// Outcome of one root measurement.
const Outcome = struct {
    solved: bool,
    single_ko: bool,
    bracket_fail: bool,
    value: i8 = -128,
    nodes: u64,
    ms: u64,
};

/// Per-layer accumulator (one per arm).
const LayerStat = struct {
    layer: usize,
    pop_b: u64 = 0, // flagged slots this layer, Black side
    pop_w: u64 = 0,
    samples: u64 = 0,
    solved: u64 = 0,
    skipped: u64 = 0,
    single_ko: u64 = 0,
    sum_nodes: u64 = 0,
    max_nodes: u64 = 0,
    sum_ms: u64 = 0,

    fn meanNodes(self: *const LayerStat) f64 {
        const n = self.samples - self.single_ko;
        if (n == 0) return 0;
        return @as(f64, @floatFromInt(self.sum_nodes)) / @as(f64, @floatFromInt(n));
    }
};

const Probe = struct {
    gpa: std.mem.Allocator,
    budget: u64,
    writes: bool,
    // seeded-defect control state: corrupt exactly one solved value so the
    // artifact comparator must report it (known-bad must be caught)
    defect_pending: bool = false,
    defect_fired: bool = false,
    art_vb: []const i8 = &.{},
    art_vw: []const i8 = &.{},
    diffs: u64 = 0,
    compared: u64 = 0,
    bracket_fails: u64 = 0,

    fn measureRoot(
        comptime w: usize,
        comptime h: usize,
        comptime RT: type,
        p: *Probe,
        f: *RT.Finisher,
        i: usize,
        pos: *RT.Pos,
        side: i8,
    ) Outcome {
        _ = w;
        _ = h;
        const t0 = nowMs();
        f.journal.clearRetainingCapacity();
        f.ctx.nodes = 0;
        f.ctx.budget = p.budget;

        const res: error{Budget}!i8 = if (RT.solveSingleKo(&f.t.*, pos, side)) |v|
            v
        else
            RT.ab_value_from_root(&f.t.*, &f.ctx, pos, side, f.hist);

        // revert this root's memo writes (same loop as Finisher.runRoot);
        // with writes OFF the journal stays empty and this is a no-op.
        for (f.journal.items) |entry| {
            const ji: usize = @intCast(entry & 0x3FFF_FFFF);
            const white = entry & (1 << 31) != 0;
            if (entry & (1 << 30) != 0) {
                if (white) {
                    f.ctx.lbw.?[ji] = -127;
                    f.ctx.ubw.?[ji] = 127;
                } else {
                    f.ctx.lbb.?[ji] = -127;
                    f.ctx.ubb.?[ji] = 127;
                }
            } else if (white) {
                f.ctx.vw[ji] = f.base_vw[ji];
                f.ctx.cw[ji] = f.base_cw[ji];
            } else {
                f.ctx.vb[ji] = f.base_vb[ji];
                f.ctx.cb[ji] = f.base_cb[ji];
            }
        }

        const ms = nowMs() - t0;
        const nodes = f.ctx.nodes;
        const solved_v: ?i8 = if (res) |v| v else |_| null;
        if (solved_v) |v0| {
            var v = v0;
            if (p.defect_pending) {
                v +%= 1; // the seeded defect: exactly one wrong value
                p.defect_pending = false;
                p.defect_fired = true;
            }
            // bracket containment check (runRoot does the same)
            var bracket_fail = false;
            const lo0 = if (side > 0) f.t.lo.b0[i] else f.t.lo.w0[i];
            const hi0 = if (side > 0) f.t.hi.b0[i] else f.t.hi.w0[i];
            if (v < lo0 or v > hi0) {
                bracket_fail = true;
                p.bracket_fails += 1;
                util.warn("BRACKET FAIL idx={d} side={d}: v={d} outside [{d},{d}]", .{ i, side, v, lo0, hi0 });
            }
            // artifact diff (selftest/calibration)
            if (p.art_vb.len != 0) {
                const av = if (side > 0) p.art_vb[i] else p.art_vw[i];
                p.compared += 1;
                if (av != v) {
                    p.diffs += 1;
                    util.out("T924,diff,{d},{d},{d},{d},{d}\n", .{ i, side, av, v, @intFromBool(p.defect_fired) });
                }
            }
            util.out("T924,root,{d},{d},1,0,{d},{d},{d},{d}\n", .{ i, side, nodes, ms, v, @intFromBool(p.writes) });
            return .{ .solved = true, .single_ko = false, .bracket_fail = bracket_fail, .value = v, .nodes = nodes, .ms = ms };
        }
        util.out("T924,root,{d},{d},0,0,{d},{d},-128,{d}\n", .{ i, side, nodes, ms, @intFromBool(p.writes) });
        return .{ .solved = false, .single_ko = false, .bracket_fail = false, .nodes = nodes, .ms = ms };
    }

    /// Walk every layer deepest-first like Finisher.runLayer, measuring a
    /// systematic sample of ko-sensitive roots per layer per side.
    fn walkLayers(
        comptime w: usize,
        comptime h: usize,
        comptime RT: type,
        p: *Probe,
        f: *RT.Finisher,
        tried_b: []bool,
        tried_w: []bool,
        stats: []LayerStat,
        layer_filter: ?[]const usize,
        sample_cap: usize,
    ) void {
        var layer: usize = RT.n + 1;
        while (layer > 0) {
            layer -= 1;
            if (layer_filter) |lf| {
                var keep = false;
                for (lf) |l| {
                    if (l == layer) keep = true;
                }
                if (!keep) continue;
            }
            const ls = &stats[layer];

            for ([_]i8{ 1, -1 }) |side| {
                const flags = if (side > 0) f.t.fb else f.t.fw;
                const tried = if (side > 0) tried_b else tried_w;

                // pass A: population + candidate count
                var ncand: u64 = 0;
                {
                    var li: u64 = RT.X.layer_offset[layer];
                    const stop = RT.X.layer_offset[layer + 1];
                    while (li < stop) : (li += 1) {
                        const i: usize = @intCast(li);
                        if (!f.t.legal[i]) continue;
                        if (flags[i] & retro.FLAG_KO_SENSITIVE == 0) continue;
                        if (side > 0) ls.pop_b += 1 else ls.pop_w += 1;
                        if (flags[i] & (retro.FLAG_FROM_FORWARD | retro.FLAG_TRIED_SKIP) != 0) continue;
                        if (tried[i]) continue;
                        ncand += 1;
                    }
                }
                if (ncand == 0) continue;

                const take: u64 = if (sample_cap == 0 or ncand <= sample_cap) ncand else sample_cap;
                const stride: u64 = ncand / take + 1;

                // pass B: measure selected candidates (systematic across colex)
                var j: u64 = 0;
                var li: u64 = RT.X.layer_offset[layer];
                const stop2 = RT.X.layer_offset[layer + 1];
                while (li < stop2) : (li += 1) {
                    const i: usize = @intCast(li);
                    if (!f.t.legal[i]) continue;
                    if (flags[i] & retro.FLAG_KO_SENSITIVE == 0) continue;
                    defer j += 1;
                    if (j % stride != 0) continue;
                    if (flags[i] & (retro.FLAG_FROM_FORWARD | retro.FLAG_TRIED_SKIP) != 0) continue;
                    if (tried[i]) continue;

                    var pos = RT.X.pos_from_colex(i);
                    if (RT.solveSingleKo(&f.t.*, &pos, side)) |v| {
                        markOrbit(w, h, RT, tried_b, tried_w, &pos, side);
                        ls.samples += 1;
                        ls.single_ko += 1;
                        ls.solved += 1;
                        if (p.art_vb.len != 0) {
                            const av = if (side > 0) p.art_vb[i] else p.art_vw[i];
                            p.compared += 1;
                            if (av != v) {
                                p.diffs += 1;
                                util.out("T924,diff,{d},{d},{d},{d},0\n", .{ i, side, av, v });
                            }
                        }
                        util.out("T924,root,{d},{d},1,1,0,0,{d},{d}\n", .{ i, side, v, @intFromBool(p.writes) });
                        continue;
                    }
                    const out = Probe.measureRoot(w, h, RT, p, f, i, &pos, side);
                    ls.samples += 1;
                    ls.sum_nodes += out.nodes;
                    ls.sum_ms += out.ms;
                    if (out.nodes > ls.max_nodes) ls.max_nodes = out.nodes;
                    if (out.solved) ls.solved += 1 else ls.skipped += 1;
                    markOrbit(w, h, RT, tried_b, tried_w, &pos, side);
                }
            }
        }
    }

    fn markOrbit(
        comptime w: usize,
        comptime h: usize,
        comptime RT: type,
        tried_b: []bool,
        tried_w: []bool,
        pos: *const RT.Pos,
        side: i8,
    ) void {
        _ = w;
        _ = h;
        inline for (0..RT.E.num_syms) |k| {
            const tp = RT.transformed(pos, &RT.E.sym_perms[k], 1);
            const ti: usize = @intCast(RT.X.colex_from_pos(&tp));
            const ip = RT.transformed(pos, &RT.E.sym_perms[k], -1);
            const ii: usize = @intCast(RT.X.colex_from_pos(&ip));
            if (side > 0) {
                tried_b[ti] = true;
                tried_w[ii] = true;
            } else {
                tried_w[ti] = true;
                tried_b[ii] = true;
            }
        }
    }
};

fn runProbe(gpa: std.mem.Allocator) !void {
    const w = envUsize("T924_W", 4);
    const h = envUsize("T924_H", 4);
    const budget: u64 = envUsize("T924_BUDGET", 20_000_000);
    const sample_cap: usize = envUsize("T924_SAMPLE", 48);
    const mode = envStr("T924_MODE", "sample");
    const writes_spec = envStr("T924_WRITES", "off");
    const selftest = std.mem.eql(u8, envStr("T924_SELFTEST", "0"), "1");

    var layer_buf: [32]usize = undefined;
    var layer_filter: ?[]const usize = null;
    {
        var buf: [32]usize = undefined;
        const nl = parseLayerList(envStr("T924_LAYERS", ""), &buf);
        if (nl > 0) {
            @memcpy(layer_buf[0..nl], buf[0..nl]);
            layer_filter = layer_buf[0..nl];
        }
    }

    if (w == 2 and h == 2) {
        try runForSize(2, 2, gpa, budget, sample_cap, mode, writes_spec, selftest, layer_filter);
    } else if (w == 3 and h == 2) {
        try runForSize(3, 2, gpa, budget, sample_cap, mode, writes_spec, selftest, layer_filter);
    } else if (w == 3 and h == 3) {
        try runForSize(3, 3, gpa, budget, sample_cap, mode, writes_spec, selftest, layer_filter);
    } else if (w == 4 and h == 3) {
        try runForSize(4, 3, gpa, budget, sample_cap, mode, writes_spec, selftest, layer_filter);
    } else if (w == 4 and h == 4) {
        try runForSize(4, 4, gpa, budget, sample_cap, mode, writes_spec, selftest, layer_filter);
    } else {
        util.warn("unsupported size {d}x{d}\n", .{ w, h });
        return error.UnsupportedSize;
    }
}

fn loadArtifactOpt(gpa: std.mem.Allocator, path: []const u8) !?artifact.Decoded {
    var threaded = std.Io.Threaded.init(gpa, .{});
    const io = threaded.io();
    const dir = std.Io.Dir.cwd();
    return artifact.load(io, dir, path, gpa) catch |err| {
        util.warn("cannot load artifact '{s}': {t} — continuing WITHOUT artifact diff\n", .{ path, err });
        return null;
    };
}

fn summarize(stats: []LayerStat, num_syms: usize, label: []const u8) void {
    util.out("T924,summary,{s},layer,pop_b,pop_w,samples,solved,skipped,single_ko,mean_nodes,max_nodes,sum_ms\n", .{label});
    var tot = LayerStat{ .layer = 999 };
    for (stats) |ls| {
        if (ls.pop_b + ls.pop_w == 0 and ls.samples == 0) continue;
        util.out("T924,summary,{s},{d},{d},{d},{d},{d},{d},{d},{d:.1},{d},{d}\n", .{
            label, ls.layer, ls.pop_b, ls.pop_w, ls.samples, ls.solved, ls.skipped,
            ls.single_ko, ls.meanNodes(), ls.max_nodes, ls.sum_ms,
        });
        tot.pop_b += ls.pop_b;
        tot.pop_w += ls.pop_w;
        tot.samples += ls.samples;
        tot.solved += ls.solved;
        tot.skipped += ls.skipped;
        tot.single_ko += ls.single_ko;
        tot.sum_nodes += ls.sum_nodes;
        tot.max_nodes = @max(tot.max_nodes, ls.max_nodes);
        tot.sum_ms += ls.sum_ms;
    }
    // Projection bracket. The finisher solves ONE root per orbit; orbit sizes
    // vary, so the sampled slot-mean brackets the rep-mean between /num_syms
    // (every orbit maximal) and ×1 (every orbit trivial).
    const pop_slots: f64 = @floatFromInt(tot.pop_b + tot.pop_w);
    const mean: f64 = tot.meanNodes();
    const ns_per_node: f64 = if (tot.sum_nodes != 0)
        @as(f64, @floatFromInt(tot.sum_ms)) * 1_000_000.0 / @as(f64, @floatFromInt(tot.sum_nodes))
    else
        0;
    const proj_lo_nodes: f64 = pop_slots / @as(f64, @floatFromInt(num_syms)) * mean;
    const proj_hi_nodes: f64 = pop_slots * mean;
    const proj_lo_h = proj_lo_nodes * ns_per_node / 3.6e12; // ms→h with ns/node
    const proj_hi_h = proj_hi_nodes * ns_per_node / 3.6e12;
    util.out("T924,total,{s},pop={d},samples={d},solved={d},skipped={d},single_ko={d},sum_nodes={d},max_root={d},sum_ms={d}\n", .{
        label, tot.pop_b + tot.pop_w, tot.samples, tot.solved, tot.skipped, tot.single_ko, tot.sum_nodes, tot.max_nodes, tot.sum_ms,
    });
    util.out("T924,projection,{s},mean_nodes_per_nontrivial_root={d:.1},ns_per_node={d:.2},projected_finisher_nodes=[{d:.0},{d:.0}],projected_wall_h=[{d:.3},{d:.3}]\n", .{
        label, mean, ns_per_node, proj_lo_nodes, proj_hi_nodes, proj_lo_h, proj_hi_h,
    });
}

fn runForSize(
    comptime w: usize,
    comptime h: usize,
    gpa: std.mem.Allocator,
    budget: u64,
    sample_cap: usize,
    mode: []const u8,
    writes_spec: []const u8,
    selftest: bool,
    layer_filter: ?[]const usize,
) !void {
    const RT = retro.Retro(w, h);
    const p_note = std.debug.print;
    p_note("==== T924 probe {d}x{d} mode={s} ===\n", .{ w, h, mode });

    var art_decoded: ?artifact.Decoded = null;
    defer if (art_decoded) |*d| d.deinit();
    if (selftest) {
        const path = envStr("T924_ART", "artifacts/oracle-3x2.wzo");
        art_decoded = try loadArtifactOpt(gpa, path);
    }

    // ── build the L/H tables once ──
    var t = try RT.Tables.init(gpa);
    defer t.deinit();
    const t0 = nowMs();
    RT.seed(&t);
    RT.converge(&t);
    RT.finalize(&t);
    const build_ms = nowMs() - t0;
    p_note("build: legal={d} settled={d} sweeps={d} ko-sensitive region B/W={d}/{d} ({d} ms)\n", .{
        t.legal_count, t.settled_count, t.sweeps, t.ko_sensitive_b, t.ko_sensitive_w, build_ms,
    });
    util.out("T924,build,{d}x{d},legal={d},sweeps={d},ko_b={d},ko_w={d},ms={d}\n", .{ w, h, t.legal_count, t.sweeps, t.ko_sensitive_b, t.ko_sensitive_w, build_ms });

    if (std.mem.eql(u8, mode, "empty")) {
        try runEmptyMode(w, h, RT, gpa, &t, budget);
        return;
    }

    // ── arms ──
    const n_layers = RT.n + 2;
    const stats_off = try gpa.alloc(LayerStat, n_layers);
    defer gpa.free(stats_off);
    const stats_on = try gpa.alloc(LayerStat, n_layers);
    defer gpa.free(stats_on);

    const run_on = std.mem.eql(u8, writes_spec, "on") or std.mem.eql(u8, writes_spec, "both");
    const run_off = std.mem.eql(u8, writes_spec, "off") or std.mem.eql(u8, writes_spec, "both");

    if (selftest) {
        // ACCEPTANCE ORDER: clean pass first (expect 0 diffs), then the
        // seeded-defect control on the SAME workload (expect exactly 1 diff).
        if (art_decoded == null) {
            util.warn("SELFTEST requires T924_ART to load\n", .{});
            return error.SelftestNeedsArtifact;
        }
        // pass 1: writes-off clean vs artifact
        {
            var probe = Probe{
                .gpa = gpa,
                .budget = budget,
                .writes = false,
                .art_vb = art_decoded.?.vb,
                .art_vw = art_decoded.?.vw,
            };
            var f = try RT.Finisher.init(&t, gpa, budget, true, 0, false, false);
            defer f.deinit();
            f.ctx.journal = &f.journal;
            f.ctx.journal_gpa = gpa;
            const tried_b = try gpa.alloc(bool, RT.total);
            defer gpa.free(tried_b);
            const tried_w = try gpa.alloc(bool, RT.total);
            defer gpa.free(tried_w);
            @memset(tried_b, false);
            @memset(tried_w, false);
            @memset(stats_off, LayerStat{ .layer = 0 });
            for (stats_off, 0..) |*s, i| s.layer = i;
            Probe.walkLayers(w, h, RT, &probe, &f, tried_b, tried_w, stats_off, null, 0);
            summarize(stats_off, RT.E.num_syms, "selftest-off-clean");
            p_note("SELFTEST clean: compared={d} diffs={d}\n", .{ probe.compared, probe.diffs });
            if (probe.diffs != 0) {
                util.warn("SELFTEST FAILED: expected 0 diffs, got {d}\n", .{probe.diffs});
                return error.SelftestCleanFailed;
            }
            if (probe.compared == 0) {
                util.warn("SELFTEST FAILED: comparator never fired (compared=0)\n", .{});
                return error.SelftestComparatorSilent;
            }
        }
        // pass 2: seeded defect (+1 into the FIRST solved value encountered)
        {
            var probe = Probe{
                .gpa = gpa,
                .budget = budget,
                .writes = false,
                .defect_pending = true,
                .art_vb = art_decoded.?.vb,
                .art_vw = art_decoded.?.vw,
            };
            var f = try RT.Finisher.init(&t, gpa, budget, true, 0, false, false);
            defer f.deinit();
            f.ctx.journal = &f.journal;
            f.ctx.journal_gpa = gpa;
            const tried_b = try gpa.alloc(bool, RT.total);
            defer gpa.free(tried_b);
            const tried_w = try gpa.alloc(bool, RT.total);
            defer gpa.free(tried_w);
            @memset(tried_b, false);
            @memset(tried_w, false);
            @memset(stats_on, LayerStat{ .layer = 0 });
            for (stats_on, 0..) |*s, i| s.layer = i;
            Probe.walkLayers(w, h, RT, &probe, &f, tried_b, tried_w, stats_on, null, 0);
            summarize(stats_on, RT.E.num_syms, "selftest-defect");
            p_note("SELFTEST defect: fired={} diffs={d}\n", .{ probe.defect_fired, probe.diffs });
            if (!probe.defect_fired or probe.diffs != 1) {
                util.warn("SELFTEST FAILED: seeded defect not caught exactly once (fired={}, diffs={d})\n", .{ probe.defect_fired, probe.diffs });
                return error.SelftestDefectMissed;
            }
            util.out("T924,selftest,PASS,compared={d},clean_diffs=0,seeded_defect_caught=1\n", .{stats_off[0].samples});
            p_note("==== SELFTEST PASS ====\n", .{});
        }
        return;
    }

    if (run_off) {
        var probe = Probe{ .gpa = gpa, .budget = budget, .writes = false };
        var f = try RT.Finisher.init(&t, gpa, budget, true, 0, false, false);
        defer f.deinit();
        f.ctx.journal = &f.journal;
        f.ctx.journal_gpa = gpa;
        const tried_b = try gpa.alloc(bool, RT.total);
        defer gpa.free(tried_b);
        const tried_w = try gpa.alloc(bool, RT.total);
        defer gpa.free(tried_w);
        @memset(tried_b, false);
        @memset(tried_w, false);
        @memset(stats_off, LayerStat{ .layer = 0 });
        for (stats_off, 0..) |*s, i| s.layer = i;
        Probe.walkLayers(w, h, RT, &probe, &f, tried_b, tried_w, stats_off, layer_filter, sample_cap);
        if (probe.bracket_fails != 0) {
            util.warn("{d} BRACKET FAILURES — instrument verdict invalid\n", .{probe.bracket_fails});
        }
        summarize(stats_off, RT.E.num_syms, "writes-off");
    }

    if (run_on) {
        var probe = Probe{ .gpa = gpa, .budget = budget, .writes = true };
        var f = try RT.Finisher.init(&t, gpa, budget, true, 0, true, false);
        defer f.deinit();
        f.ctx.journal = &f.journal;
        f.ctx.journal_gpa = gpa;
        const tried_b = try gpa.alloc(bool, RT.total);
        defer gpa.free(tried_b);
        const tried_w = try gpa.alloc(bool, RT.total);
        defer gpa.free(tried_w);
        @memset(tried_b, false);
        @memset(tried_w, false);
        @memset(stats_on, LayerStat{ .layer = 0 });
        for (stats_on, 0..) |*s, i| s.layer = i;
        Probe.walkLayers(w, h, RT, &probe, &f, tried_b, tried_w, stats_on, layer_filter, sample_cap);
        summarize(stats_on, RT.E.num_syms, "writes-on");
    }
}

/// MODE=empty: the empty-goban root at an escalating per-root budget ladder,
/// writes-off, plus one writes-on measurement as calibration reference.
fn runEmptyMode(
    comptime w: usize,
    comptime h: usize,
    comptime RT: type,
    gpa: std.mem.Allocator,
    t: *RT.Tables,
    default_budget: u64,
) !void {
    _ = default_budget;
    const budgets = try parseBudgetList(gpa, envStr("T924_BUDGETS", "20000000,100000000,500000000,2000000000"));
    defer gpa.free(budgets);

    const pos0 = RT.X.pos_from_colex(0);

    inline for (.{ @as(i8, 1), @as(i8, -1) }) |side| {
        for (budgets) |b| {
            var probe = Probe{ .gpa = gpa, .budget = b, .writes = false };
            var f = try RT.Finisher.init(t, gpa, b, true, 0, false, false);
            defer f.deinit();
            f.ctx.journal = &f.journal;
            f.ctx.journal_gpa = gpa;
            var pos = pos0;
            const out = Probe.measureRoot(w, h, RT, &probe, &f, 0, &pos, side);
            util.out("T924,empty,{d},off,{d},{d},{d},{d},{d}\n", .{
                side, b, @intFromBool(out.solved), out.nodes, out.ms, out.value,
            });
            std.debug.print("empty root side={d} budget={d}: solved={} nodes={d} ({d} ms) v={d}\n", .{
                side, b, out.solved, out.nodes, out.ms, out.value,
            });
        }
    }
    // calibration reference: writes-on, largest budget only
    {
        var probe = Probe{ .gpa = gpa, .budget = budgets[budgets.len - 1], .writes = true };
        var f = try RT.Finisher.init(t, gpa, budgets[budgets.len - 1], true, 0, true, false);
        defer f.deinit();
        f.ctx.journal = &f.journal;
        f.ctx.journal_gpa = gpa;
        inline for (.{ @as(i8, 1), @as(i8, -1) }) |side| {
            var pos = pos0;
            const out = Probe.measureRoot(w, h, RT, &probe, &f, 0, &pos, side);
            util.out("T924,empty,{d},on,{d},{d},{d},{d},{d}\n", .{
                side, budgets[budgets.len - 1], @intFromBool(out.solved), out.nodes, out.ms, out.value,
            });
            std.debug.print("[calibration] empty root side={d} WRITES-ON: solved={} nodes={d} ({d} ms) v={d}\n", .{
                side, out.solved, out.nodes, out.ms, out.value,
            });
        }
    }
}

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    const thread = try std.Thread.spawn(.{ .stack_size = 1 << 28 }, runProbeWrapper, .{gpa});
    thread.join();
}

fn runProbeWrapper(gpa: std.mem.Allocator) void {
    runProbe(gpa) catch |err| {
        util.warn("T924 probe FAILED: {t}\n", .{err});
        std.process.exit(1);
    };
}
