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
// T930 — parallel finisher costing driver (deepseek-v4-pro/T930, 2026-08-25).
//
// Question: does the 4x4 writes-off finisher scale across the host's 18 cores,
// or is T924's "not tractable" a property of using one core?
//
// This is a COSTING harness, not a production finisher. It drives the SAME
// per-root solver the production finisher uses (RT.solveSingleKo else
// RT.ab_value_from_root, writes-off / memo_writes=false / deps=false), builds
// the SAME orbit-deduped work list as RT.finishParallel (src/retro.zig, B31),
// but lets the caller choose the PARTITION strategy so the wall can be
// attributed to hardware vs. scheduling:
//
//   T930_PARTITION=contig  — contiguous chunks, exactly what finishParallel does
//                            (deepest-first order means cheap roots go to the
//                            low thread ids, expensive shallow roots to the last).
//   T930_PARTITION=rr      — round-robin (root i -> thread i%nt), load-balanced.
//
// The solver is NOT reimplemented: the per-thread ctx setup and per-root
// sequence (journal clear, solve, journal revert, node tally) are copied
// line-for-line from retro.zig's worker() so the two are byte-equivalent in
// writes-off mode (where the journal is empty and the revert is a no-op).
//
// Env:
//   T930_THREADS     thread count (default 1)
//   T930_W/T930_H    goban size (default 4 / 3 — the 35s/20,878-root rung)
//   T930_BUDGET      per-root node budget (default 20_000_000 = production)
//   T930_PARTITION   "contig" (default) | "rr"
//
// Output: one machine-readable summary line on stdout ("T930" in column 1),
//         per-thread node counts + diagnostics on stderr.
//
// Build: tools/runner -- zig build-exe -O ReleaseFast src/t930_parallel_finisher_cost.zig

const std = @import("std");
const util = @import("util.zig");
const retro = @import("retro.zig");

fn envUsize(comptime name: [:0]const u8, default: usize) usize {
    const s = std.c.getenv(name) orelse return default;
    return std.fmt.parseInt(usize, std.mem.span(s), 10) catch default;
}

fn nowMs() u64 {
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * 1000 + @as(u64, @intCast(ts.nsec)) / 1_000_000;
}

const WorkItem = struct { idx: u32, side: i8 };

const ThreadStat = struct {
    solved: u64 = 0,
    skipped: u64 = 0,
    nodes: u64 = 0,
    max_nodes: u64 = 0,
};

fn runForSize(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator, threads: u8, budget: u64, rr: bool) !void {
    const RT = retro.Retro(w, h);

    var t = try RT.Tables.init(gpa);
    defer t.deinit();

    const t0 = nowMs();
    RT.seed(&t);
    RT.converge(&t);
    RT.finalize(&t);
    const build_ms = nowMs() - t0;
    util.note("build {d}x{d}: legal={d} sweeps={d} ko_b={d} ko_w={d} ({d}ms)\n", .{
        w, h, t.legal_count, t.sweeps, t.ko_sensitive_b, t.ko_sensitive_w, build_ms,
    });

    // ── Step 1: work list — identical orbit dedup to finishParallel ──
    var done_b = try gpa.alloc(bool, RT.total);
    defer gpa.free(done_b);
    var done_w = try gpa.alloc(bool, RT.total);
    defer gpa.free(done_w);
    @memset(done_b, false);
    @memset(done_w, false);

    var work_list = std.ArrayList(WorkItem).empty;
    defer work_list.deinit(gpa);

    var layer: usize = RT.n + 1;
    while (layer > 0) {
        layer -= 1;
        var li: u64 = RT.X.layer_offset[layer];
        const li_stop = RT.X.layer_offset[layer + 1];
        while (li < li_stop) : (li += 1) {
            const i: usize = @intCast(li);
            if (!t.legal[i]) continue;
            if (t.fb[i] & retro.FLAG_KO_SENSITIVE == 0 and t.fw[i] & retro.FLAG_KO_SENSITIVE == 0) continue;
            var pos = RT.X.pos_from_colex(i);
            inline for (.{ @as(i8, 1), @as(i8, -1) }) |side| {
                const flags = if (side > 0) t.fb else t.fw;
                const done = if (side > 0) done_b else done_w;
                if (flags[i] & retro.FLAG_KO_SENSITIVE != 0 and
                    flags[i] & (retro.FLAG_FROM_FORWARD | retro.FLAG_TRIED_SKIP) == 0 and !done[i])
                {
                    inline for (0..RT.E.num_syms) |k| {
                        const tp = RT.transformed(&pos, &RT.E.sym_perms[k], 1);
                        const ti: usize = @intCast(RT.X.colex_from_pos(&tp));
                        const ip = RT.transformed(&pos, &RT.E.sym_perms[k], -1);
                        const ii: usize = @intCast(RT.X.colex_from_pos(&ip));
                        if (side > 0) {
                            done_b[ti] = true;
                            done_w[ii] = true;
                        } else {
                            done_w[ti] = true;
                            done_b[ii] = true;
                        }
                    }
                    work_list.append(gpa, .{ .idx = @intCast(i), .side = side }) catch
                        @panic("OOM: work list");
                }
            }
        }
    }

    const total_work = work_list.items.len;
    const nt: u8 = if (threads == 0) @as(u8, @intCast((std.Thread.getCpuCount() catch 1))) else threads;
    if (nt == 0 or total_work == 0) {
        util.warn("no work or no threads (work={d}, nt={d})\n", .{ total_work, nt });
        return;
    }
    const nti: usize = nt;

    // ── per-thread stats ──
    const stats = try gpa.alloc(ThreadStat, nti);
    defer gpa.free(stats);
    @memset(stats, ThreadStat{});

    const shared_t = &t;
    const shared_budget = budget;

    const t1 = nowMs();

    const Worker = struct {
        fn run(t2: *RT.Tables, budget2: u64, items: []const WorkItem, out: *ThreadStat, gpa2: std.mem.Allocator) void {
            const total2 = RT.total;
            var ctx = RT.O.Ctx{
                .vb = gpa2.alloc(i8, total2) catch @panic("OOM"),
                .vw = gpa2.alloc(i8, total2) catch @panic("OOM"),
                .cb = gpa2.alloc(bool, total2) catch @panic("OOM"),
                .cw = gpa2.alloc(bool, total2) catch @panic("OOM"),
                .memo = true,
                .memo_writes = false,
                .deps = false,
            };
            defer {
                gpa2.free(ctx.vb);
                gpa2.free(ctx.vw);
                gpa2.free(ctx.cb);
                gpa2.free(ctx.cw);
            }
            ctx.lbb = gpa2.alloc(i8, total2) catch @panic("OOM");
            ctx.ubb = gpa2.alloc(i8, total2) catch @panic("OOM");
            ctx.lbw = gpa2.alloc(i8, total2) catch @panic("OOM");
            ctx.ubw = gpa2.alloc(i8, total2) catch @panic("OOM");
            defer {
                gpa2.free(ctx.lbb.?);
                gpa2.free(ctx.ubb.?);
                gpa2.free(ctx.lbw.?);
                gpa2.free(ctx.ubw.?);
            }
            @memset(ctx.lbb.?, -127);
            @memset(ctx.ubb.?, 127);
            @memset(ctx.lbw.?, -127);
            @memset(ctx.ubw.?, 127);

            for (0..total2) |i| {
                ctx.vb[i] = if (t2.legal[i] and t2.vb[i] != retro.UNDEF and t2.fb[i] & (retro.FLAG_KO_SENSITIVE | retro.FLAG_FROM_FORWARD) == 0) t2.vb[i] else retro.UNDEF;
                ctx.vw[i] = if (t2.legal[i] and t2.vw[i] != retro.UNDEF and t2.fw[i] & (retro.FLAG_KO_SENSITIVE | retro.FLAG_FROM_FORWARD) == 0) t2.vw[i] else retro.UNDEF;
                ctx.cb[i] = t2.legal[i] and t2.vb[i] != retro.UNDEF and t2.fb[i] & (retro.FLAG_KO_SENSITIVE | retro.FLAG_FROM_FORWARD) == 0;
                ctx.cw[i] = t2.legal[i] and t2.vw[i] != retro.UNDEF and t2.fw[i] & (retro.FLAG_KO_SENSITIVE | retro.FLAG_FROM_FORWARD) == 0;
            }

            var journal = std.ArrayList(u32).empty;
            defer journal.deinit(gpa2);
            ctx.journal = &journal;
            ctx.journal_gpa = gpa2;

            var hist: RT.O.History = .{};

            for (items) |item| {
                const i: usize = @intCast(item.idx);
                var pos = RT.X.pos_from_colex(i);
                journal.clearRetainingCapacity();
                ctx.nodes = 0;
                ctx.budget = budget2;

                const solved: error{Budget}!i8 = if (RT.solveSingleKo(t2, &pos, item.side)) |v|
                    v
                else
                    RT.ab_value_from_root(t2, &ctx, &pos, item.side, &hist);

                // revert (no-op writes-off; faithful to retro.zig worker)
                for (journal.items) |entry| {
                    const ji: usize = @intCast(entry & 0x3FFF_FFFF);
                    const white = entry & (1 << 31) != 0;
                    if (entry & (1 << 30) != 0) {
                        if (white) {
                            ctx.lbw.?[ji] = -127;
                            ctx.ubw.?[ji] = 127;
                        } else {
                            ctx.lbb.?[ji] = -127;
                            ctx.ubb.?[ji] = 127;
                        }
                    } else if (white) {
                        ctx.vw[ji] = if (t2.legal[ji] and t2.vw[ji] != retro.UNDEF and t2.fw[ji] & (retro.FLAG_KO_SENSITIVE | retro.FLAG_FROM_FORWARD) == 0) t2.vw[ji] else retro.UNDEF;
                        ctx.cw[ji] = t2.legal[ji] and t2.vw[ji] != retro.UNDEF and t2.fw[ji] & (retro.FLAG_KO_SENSITIVE | retro.FLAG_FROM_FORWARD) == 0;
                    } else {
                        ctx.vb[ji] = if (t2.legal[ji] and t2.vb[ji] != retro.UNDEF and t2.fb[ji] & (retro.FLAG_KO_SENSITIVE | retro.FLAG_FROM_FORWARD) == 0) t2.vb[ji] else retro.UNDEF;
                        ctx.cb[ji] = t2.legal[ji] and t2.vb[ji] != retro.UNDEF and t2.fb[ji] & (retro.FLAG_KO_SENSITIVE | retro.FLAG_FROM_FORWARD) == 0;
                    }
                }

                if (solved) |_| {
                    out.solved += 1;
                    out.nodes += ctx.nodes;
                    if (ctx.nodes > out.max_nodes) out.max_nodes = ctx.nodes;
                } else |_| {
                    out.skipped += 1;
                }
            }
        }
    };

    // ── partition ──
    if (nti == 1) {
        Worker.run(shared_t, shared_budget, work_list.items, &stats[0], gpa);
    } else {
        var threads_arr = try gpa.alloc(std.Thread, nti - 1);
        defer gpa.free(threads_arr);

        // Round-robin needs a permuted flat buffer (Zig slices have no stride);
        // it MUST live until after the join below, so its lifetime is scoped to
        // the whole else-branch, not the inner `if (rr)` block.
        var rr_items: []WorkItem = &.{};
        defer if (rr_items.len != 0) gpa.free(rr_items);
        var rr_offsets: []usize = &.{};
        defer if (rr_offsets.len != 0) gpa.free(rr_offsets);

        if (rr) {
            // round-robin: thread t handles items t, t+nt, t+2nt, ...
            const counts = try gpa.alloc(usize, nti);
            defer gpa.free(counts);
            @memset(counts, 0);
            for (work_list.items, 0..) |_, k| counts[k % nti] += 1;

            rr_offsets = try gpa.alloc(usize, nti + 1);
            rr_offsets[0] = 0;
            for (0..nti) |ti| rr_offsets[ti + 1] = rr_offsets[ti] + counts[ti];

            rr_items = try gpa.alloc(WorkItem, total_work);
            const cursors = try gpa.alloc(usize, nti);
            defer gpa.free(cursors);
            @memcpy(cursors, rr_offsets[0..nti]);
            for (work_list.items, 0..) |item, k| {
                const tid = k % nti;
                rr_items[cursors[tid]] = item;
                cursors[tid] += 1;
            }

            for (1..nti) |tid| {
                const items = rr_items[rr_offsets[tid]..rr_offsets[tid + 1]];
                threads_arr[tid - 1] = try std.Thread.spawn(.{}, Worker.run, .{ shared_t, shared_budget, items, &stats[tid], gpa });
            }
            Worker.run(shared_t, shared_budget, rr_items[rr_offsets[0]..rr_offsets[1]], &stats[0], gpa);
        } else {
            const chunk = (total_work + nti - 1) / nti;
            for (1..nti) |tid| {
                const start = tid * chunk;
                const items = if (start >= total_work) work_list.items[0..0] else work_list.items[start..@min(start + chunk, total_work)];
                threads_arr[tid - 1] = try std.Thread.spawn(.{}, Worker.run, .{ shared_t, shared_budget, items, &stats[tid], gpa });
            }
            Worker.run(shared_t, shared_budget, work_list.items[0..@min(chunk, total_work)], &stats[0], gpa);
        }

        for (0..nti - 1) |j| threads_arr[j].join();
    }

    const finish_ms = nowMs() - t1;

    // per-thread diagnostic on stderr
    {
        var tot = ThreadStat{};
        for (stats, 0..) |*s, tid| {
            tot.solved += s.solved;
            tot.skipped += s.skipped;
            tot.nodes += s.nodes;
            if (s.max_nodes > tot.max_nodes) tot.max_nodes = s.max_nodes;
            util.note("  thread {d}: solved={d} skipped={d} nodes={d} max={d}\n", .{ tid, s.solved, s.skipped, s.nodes, s.max_nodes });
        }
        util.note("  TOTAL: solved={d} skipped={d} nodes={d} max={d}\n", .{ tot.solved, tot.skipped, tot.nodes, tot.max_nodes });
    }

    // one parseable line on stdout = data
    util.out("T930,run,{d}x{d},threads={d},part={s},build_ms={d},finish_ms={d},roots={d},nodes={d},bracket_fail={d}\n", .{
        w, h, nt, if (rr) "rr" else "contig", build_ms, finish_ms, total_work,
        (blk: {
            var tot: u64 = 0;
            for (stats) |s| tot += s.nodes;
            break :blk tot;
        }),
        @as(u64, 0),
    });
}

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    const threads: u8 = @intCast(envUsize("T930_THREADS", 1));
    const w = envUsize("T930_W", 4);
    const h = envUsize("T930_H", 3);
    const budget: u64 = envUsize("T930_BUDGET", 20_000_000);
    const part_spec: []const u8 = if (std.c.getenv("T930_PARTITION")) |p| std.mem.span(p) else "contig";
    const rr = std.mem.eql(u8, part_spec, "rr");

    if (w == 4 and h == 3) {
        try runForSize(4, 3, gpa, threads, budget, rr);
    } else if (w == 3 and h == 3) {
        try runForSize(3, 3, gpa, threads, budget, rr);
    } else if (w == 4 and h == 4) {
        try runForSize(4, 4, gpa, threads, budget, rr);
    } else if (w == 3 and h == 2) {
        try runForSize(3, 2, gpa, threads, budget, rr);
    } else if (w == 2 and h == 2) {
        try runForSize(2, 2, gpa, threads, budget, rr);
    } else {
        util.warn("unsupported size {d}x{d}\n", .{ w, h });
        return error.UnsupportedSize;
    }
}
