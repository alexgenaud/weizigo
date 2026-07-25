////////////////////////////////////////////
//                                        //
//    (c) 2024 Alexander E Genaud         //
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

const std = @import("std");
const superko = @import("superko.zig");
const solve = @import("solve.zig");

// Recursion depth in `solve` equals the game-line length (one frame per ply),
// which is bounded above by superko.MAX_LINE, not by the ~20-stone board ceiling
// (captures let a line keep changing without adding net stones). Give the solve
// its own thread with a generous stack so a deep line cannot overflow the
// default 8 MB main-thread stack. For a one-time PERFECT computation, correctness
// beats speed: build with `-Doptimize=ReleaseSafe` so bounds checks stay live.
const SOLVE_STACK_BYTES = 256 * 1024 * 1024;

// White stone at idx 8 is dead (one liberty); Black is unconditionally alive
// (two eyes at 6 and 18) but the position is NOT settled, so the search must
// actually play it out: capture the dead stone -> Black+25. Completes quickly
// without a transposition table, so it exercises the full search + the new
// depth instrumentation end to end.
const demo = [_]i8{
    1, 1, 1, 0, 1,
    1, 0, 1, -1, 1,
    1, 1, 1, 1,  1,
    1, 1, 1, 0,  1,
    1, 1, 1, 1,  1,
};

const empty = [_]i8{0} ** 25;

// Flip to `true` to attempt the empty-board full solve (the scaling frontier).
// MEASURED 2026-07-16 (docs/research/forward-solve-scaling.md): it does NOT
// converge -- the DFS descends 200+ plies while the TT caches nothing, so keep
// the default `false` (the quick dead-stone demo). A runtime flag is avoided:
// the args/env std APIs churned in 0.16 and this is a one-time computation, not
// a general CLI (a build option belongs with the build-structure work, TODO #5).
const FULL = false;

// Transposition-table sizing for the FULL solve. black/white are dense
// blind->block-start arrays (one u32 per 25-bit occupancy = 128 MB each). `seq`
// is the SeqScore block pool; its exact need (sum of block_size over distinct
// canonical (blind,side) with <=16 stones) is an OPEN measurement, so we
// over-allocate and rely on solve.Table.set's always-live "seq table full"
// panic as the backstop. 1<<29 SeqScore * 4 B = 2 GB.
const SEQ_LEN_FULL = 1 << 29;

const Job = struct {
    pos: [25]i8,
    to_move: i8,
    komi: i8,
    history: *superko.History,
    table: ?*solve.Table,
    value: i8 = undefined, // out
    max_len: usize = undefined, // out
    done: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
};

fn runSolve(job: *Job) void {
    job.value = solve.solve_root(&job.pos, job.to_move, job.history, job.table, job.komi);
    job.max_len = job.history.max_len;
    job.done.store(true, .release);
}

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    const full = FULL;

    const history = try gpa.create(superko.History); // ~115 KB, keep off the stack
    defer gpa.destroy(history);
    history.* = .{};

    // Optional transposition table (FULL only; the demo completes without it).
    var table: ?solve.Table = null;
    if (full) {
        const black = try gpa.alloc(u32, 1 << 25);
        const white = try gpa.alloc(u32, 1 << 25);
        const seq = try gpa.alloc(solve.SeqScore, SEQ_LEN_FULL);
        @memset(black, 0);
        @memset(white, 0);
        @memset(seq, .{}); // score = UNDEF (empty slot), start = 0 (unset)
        table = .{ .black = black, .white = white, .seq = seq };
    }
    defer if (table) |t| {
        gpa.free(t.black);
        gpa.free(t.white);
        gpa.free(t.seq);
    };
    const tt: ?*solve.Table = if (table) |*t| t else null;

    var job = Job{
        .pos = if (full) empty else demo,
        .to_move = 1, // Black to move
        .komi = 0,
        .history = history,
        .table = tt,
    };

    std.debug.print("weizigo: perfect 5x5 go\n", .{});
    std.debug.print("  position: {s}   MAX_LINE={d}   stack={d} MB\n", .{
        if (full) "empty board (scaling frontier -- may not finish)" else "dead-stone demo",
        superko.MAX_LINE,
        SOLVE_STACK_BYTES >> 20,
    });
    if (tt) |_| std.debug.print("  TT: 256 MB blind arrays + {d} MB seq pool\n", .{SEQ_LEN_FULL * @sizeOf(solve.SeqScore) >> 20});

    const thread = try std.Thread.spawn(.{ .stack_size = SOLVE_STACK_BYTES }, runSolve, .{&job});

    // Live progress for the (possibly non-terminating) FULL run: poll the
    // already-existing counters -- no instrumentation in the hot `solve` path.
    // Racy atomic reads of aligned integers are fine for a gauge.
    if (tt) |t| {
        var peak_ply: usize = 0;
        var last_blocks: u32 = 0;
        while (!job.done.load(.acquire)) {
            const ply = @atomicLoad(usize, &history.max_len, .monotonic);
            const blocks = @atomicLoad(u32, &t.next, .monotonic);
            if (ply >= peak_ply + 10 or blocks >= last_blocks + 2_000_000) {
                peak_ply = ply;
                last_blocks = blocks;
                std.debug.print("  progress: max_ply={d}  tt_blocks={d}  seq_used={d}/{d}\n", .{ ply, blocks, blocks, SEQ_LEN_FULL });
            }
        }
    }
    thread.join();

    std.debug.print("  value  : Black {c}{d}\n", .{ @as(u8, if (job.value < 0) '-' else '+'), @abs(job.value) });
    std.debug.print("  max ply: {d} (deepest game line seen; measured vs MAX_LINE={d})\n", .{ job.max_len, superko.MAX_LINE });
    if (tt) |t| std.debug.print("  tt used: {d} seq blocks of {d}\n", .{ t.next, SEQ_LEN_FULL });
}

// Pull every live module's tests into `zig build test`. (The old depth-limited
// path -- minimax.zig, measure.zig -- was retired in ADR-0007; zobrist.zig is
// standalone and kept for future hashing / data-model work.)
test {
    _ = @import("util.zig");
    _ = @import("state.zig");
    _ = @import("zobrist.zig");
    _ = @import("persist.zig");
    _ = @import("terminal.zig");
    _ = @import("superko.zig");
    _ = @import("solve.zig");
    _ = @import("enumerate.zig");
    _ = @import("colex.zig");
    _ = @import("rules.zig");
    _ = @import("oracle.zig");
    _ = @import("sgf.zig");
    _ = @import("retro.zig");
    _ = @import("artifact.zig");
    _ = @import("gtp.zig");
    _ = @import("arena.zig");
}
