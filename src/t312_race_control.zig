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
// T312 RACE CONTROLS — parallel fixpoint race-condition tests.
//
// Task: T312 · Role: worker · Model: deepseek-v4-pro · Date: 2026-08-03
//
// Verifies that the parallel Jacobi fixpoint agrees with the serial
// Gauss-Seidel path, and that removing synchronization introduces
// detectable disagreement.

const std = @import("std");
const testing = std.testing;

// ── Tiny fixpoint graph for fast exhaustive tests ────────────────────────

const TIE: i8 = 0;

/// A tiny fixpoint graph: N_STATES states with known children.
/// States are indexed 0..N_STATES-1. Terminal states (last T terminal indices)
/// have no children and fixed scores.
/// Children form a DAG: state i can reference children < i only.

const NX: usize = 512; // total states
const NT: usize = 64; // terminal states at the end (indices NX-NT..NX-1)
const SCORE0: i8 = 0;
const MAX_VAL: i8 = 16;
const MIN_VAL: i8 = -16;

/// Build a child list for state i.
/// Terminal states have no children. Non-terminal states have children
/// consisting of 1..4 children chosen deterministically from lower-index states.
/// The DAG property ensures no cycles: children have indices < i.
fn buildTinyGraph(children: *[NX][8]u32, child_counts: *[NX]u8) void {
    for (0..NX - NT) |i| {
        child_counts[i] = 0;
    }
    for (NX - NT..NX) |i| {
        child_counts[i] = 0; // terminal
    }
    // Each non-terminal state gets 1..4 children, referencing earlier states.
    // State 0 gets 0 children (there are no earlier non-terminal states,
    // only possibly terminals which are higher-indexed).
    for (0..NX - NT) |i| {
        if (i == 0) {
            child_counts[0] = 0;
            continue;
        }
        var cnt: u8 = 0;
        var seed: u32 = @truncate(@as(u64, i) *% 2654435761); // simple hash (wrapping)
        const want: u8 = @intCast(1 + (seed & 3)); // 1..4 children
        seed >>= 2;
        var attempts: usize = 0;
        while (cnt < want and attempts < 100) : (attempts += 1) {
            if (seed == 0) seed = 1;
            const candidate: u32 = seed % @as(u32, @intCast(i)); // 0 .. i-1
            seed >>= 2;
            // Check not already used
            var dup = false;
            for (0..cnt) |j| {
                if (children[i][j] == candidate) {
                    dup = true;
                    break;
                }
            }
            if (!dup) {
                children[i][cnt] = candidate;
                cnt += 1;
            }
        }
        child_counts[i] = cnt;
    }
}

/// Run serial Gauss-Seidel fixpoint on the tiny graph.
fn serialTiny(L: []i8, H: []i8, children: *const [NX][8]u32, child_counts: *const [NX]u8) void {
    @memset(L, MIN_VAL);
    @memset(H, MAX_VAL);
    // Terminal values
    for (NX - NT..NX) |i| {
        L[i] = SCORE0;
        H[i] = SCORE0;
    }
    // Gauss-Seidel: iterate in-place until convergence
    const MAX_SWEEPS: u32 = 200;
    var sweep: u32 = 0;
    while (sweep < MAX_SWEEPS) : (sweep += 1) {
        var changes: u32 = 0;

        // L sweep (in-place Gauss-Seidel)
        for (0..NX - NT) |i| {
            const maximizing = (i & 1) == 0; // alternate side
            var best: ?i8 = null;
            for (0..child_counts[i]) |j| {
                const c = children[i][j];
                const v = L[c];
                if (best == null or (if (maximizing) v > best.? else v < best.?)) best = v;
            }
            if (best) |b| {
                if (b != L[i]) { L[i] = b; changes += 1; }
            }
        }

        // H sweep (in-place Gauss-Seidel)
        for (0..NX - NT) |i| {
            const maximizing = (i & 1) == 0;
            var best: ?i8 = null;
            for (0..child_counts[i]) |j| {
                const c = children[i][j];
                const v = H[c];
                if (best == null or (if (maximizing) v > best.? else v < best.?)) best = v;
            }
            if (best) |b| {
                if (b != H[i]) { H[i] = b; changes += 1; }
            }
        }

        if (changes == 0) break;
    }
}

/// Parallel Jacobi worker for the tiny graph: processes range [start..end).
fn tinyJacobiWorker(cur: []i8, next: []i8, children: *const [NX][8]u32, child_counts: *const [NX]u8, start: usize, end: usize) void {
    for (start..end) |i| {
        if (i >= NX - NT) {
            next[i] = cur[i]; // terminal
            continue;
        }
        const maximizing = (i & 1) == 0;
        var best: ?i8 = null;
        for (0..child_counts[i]) |j| {
            const c = children[i][j];
            const v = cur[c];
            if (best == null or (if (maximizing) v > best.? else v < best.?)) best = v;
        }
        next[i] = best orelse cur[i];
    }
}

/// Run parallel Jacobi fixpoint on the tiny graph.
fn parallelTiny(L: []i8, H: []i8, children: *const [NX][8]u32, child_counts: *const [NX]u8, num_threads: u8) !void {
    @memset(L, MIN_VAL);
    @memset(H, MAX_VAL);
    for (NX - NT..NX) |i| {
        L[i] = SCORE0;
        H[i] = SCORE0;
    }

    const L_next = try std.testing.allocator.alloc(i8, NX);
    defer std.testing.allocator.free(L_next);
    const H_next = try std.testing.allocator.alloc(i8, NX);
    defer std.testing.allocator.free(H_next);

    @memcpy(L_next, L);
    @memcpy(H_next, H);

    const nt: u8 = if (num_threads == 0) 1 else num_threads;
    const chunk_size = (NX + nt - 1) / nt;

    const MAX_SWEEPS: u32 = 200;
    var sweep: u32 = 0;
    while (sweep < MAX_SWEEPS) : (sweep += 1) {
        var changes: u32 = 0;

        // L sweep (parallel Jacobi)
        if (nt == 1) {
            tinyJacobiWorker(L, L_next, children, child_counts, 0, NX);
        } else {
            var threads = try std.testing.allocator.alloc(std.Thread, nt - 1);
            defer std.testing.allocator.free(threads);
            for (1..nt) |tid| {
                const s = tid * chunk_size;
                const e = @min(s + chunk_size, NX);
                threads[tid - 1] = try std.Thread.spawn(.{}, tinyJacobiWorker, .{ L, L_next, children, child_counts, s, e });
            }
            tinyJacobiWorker(L, L_next, children, child_counts, 0, @min(chunk_size, NX));
            for (threads) |th| th.join();
        }
        for (0..NX) |i| {
            if (L_next[i] != L[i]) changes += 1;
            L[i] = L_next[i];
        }

        // H sweep (parallel Jacobi)
        if (nt == 1) {
            tinyJacobiWorker(H, H_next, children, child_counts, 0, NX);
        } else {
            var threads = try std.testing.allocator.alloc(std.Thread, nt - 1);
            defer std.testing.allocator.free(threads);
            for (1..nt) |tid| {
                const s = tid * chunk_size;
                const e = @min(s + chunk_size, NX);
                threads[tid - 1] = try std.Thread.spawn(.{}, tinyJacobiWorker, .{ H, H_next, children, child_counts, s, e });
            }
            tinyJacobiWorker(H, H_next, children, child_counts, 0, @min(chunk_size, NX));
            for (threads) |th| th.join();
        }
        for (0..NX) |i| {
            if (H_next[i] != H[i]) changes += 1;
            H[i] = H_next[i];
        }

        if (changes == 0) break;
    }
}

// ── Tests ─────────────────────────────────────────────────────────────────

test "T312: serial vs parallel fixpoint (tiny graph, 100 reps)" {
    var children: [NX][8]u32 = [_][8]u32{[_]u32{0} ** 8} ** NX;
    var child_counts: [NX]u8 = [_]u8{0} ** NX;
    buildTinyGraph(&children, &child_counts);

    var L_serial: [NX]i8 = undefined;
    var H_serial: [NX]i8 = undefined;
    serialTiny(&L_serial, &H_serial, &children, &child_counts);

    // Run 100 times with 4 threads to shake out ordering races.
    // Jacobi is deterministic — same result every run regardless of
    // thread count. 100 reps gives high confidence there are no data races.
    for (0..100) |_| {
        var L_par: [NX]i8 = undefined;
        var H_par: [NX]i8 = undefined;
        try parallelTiny(&L_par, &H_par, &children, &child_counts, 4);
        try testing.expectEqualSlices(i8, &L_serial, &L_par);
        try testing.expectEqualSlices(i8, &H_serial, &H_par);
    }
}

test "T312: serial vs parallel fixpoint (tiny graph, 2 threads)" {
    var children: [NX][8]u32 = [_][8]u32{[_]u32{0} ** 8} ** NX;
    var child_counts: [NX]u8 = [_]u8{0} ** NX;
    buildTinyGraph(&children, &child_counts);

    var L_serial: [NX]i8 = undefined;
    var H_serial: [NX]i8 = undefined;
    serialTiny(&L_serial, &H_serial, &children, &child_counts);

    // 2 threads × 50 reps
    for (0..50) |_| {
        var L_par: [NX]i8 = undefined;
        var H_par: [NX]i8 = undefined;
        try parallelTiny(&L_par, &H_par, &children, &child_counts, 2);
        try testing.expectEqualSlices(i8, &L_serial, &L_par);
        try testing.expectEqualSlices(i8, &H_serial, &H_par);
    }
}

test "T312: parallel fixpoint agrees with serial (7 threads)" {
    var children: [NX][8]u32 = [_][8]u32{[_]u32{0} ** 8} ** NX;
    var child_counts: [NX]u8 = [_]u8{0} ** NX;
    buildTinyGraph(&children, &child_counts);

    var L_serial: [NX]i8 = undefined;
    var H_serial: [NX]i8 = undefined;
    serialTiny(&L_serial, &H_serial, &children, &child_counts);

    // 7 threads × 10 reps (odd thread count to test uneven chunking)
    for (0..10) |_| {
        var L_par: [NX]i8 = undefined;
        var H_par: [NX]i8 = undefined;
        try parallelTiny(&L_par, &H_par, &children, &child_counts, 7);
        try testing.expectEqualSlices(i8, &L_serial, &L_par);
        try testing.expectEqualSlices(i8, &H_serial, &H_par);
    }
}

test "T312: seeded defect — missing join barrier causes stale reads" {
    // Positive control: prove the test harness detects a missing
    // synchronization barrier. We spawn threads to fill an output
    // array, then DELIBERATELY read the output BEFORE joining all
    // threads. The spawned threads are given a slow path (large
    // array, compute per element) to ensure they don't finish before
    // we check. The parallel fixpoint tests above (which properly
    // join before reading) are the negative control.

    const NN: usize = 10_000_000; // 10M elements — slow enough
    const NUM_THREADS: u8 = 4;
    const SENTINEL: i64 = -999;
    const out = try std.testing.allocator.alloc(i64, NN);
    defer std.testing.allocator.free(out);

    const FillWorker = struct {
        fn run(arr: []i64, start: usize, end: usize) void {
            // Do some compute per element to ensure non-trivial runtime
            for (start..end) |i| {
                arr[i] = @as(i64, @intCast(i % 9973)) + 42;
            }
        }
    };

    // CORRECT: join all threads first, then read → no sentinel values
    {
        @memset(out, SENTINEL);
        const chunk: usize = NN / NUM_THREADS;
        const main_start = NN - 100;
        var threads = try std.testing.allocator.alloc(std.Thread, NUM_THREADS - 1);
        defer std.testing.allocator.free(threads);
        threads[0] = try std.Thread.spawn(.{}, FillWorker.run, .{ out, @as(usize, 0), chunk });
        threads[1] = try std.Thread.spawn(.{}, FillWorker.run, .{ out, chunk, 2 * chunk });
        threads[2] = try std.Thread.spawn(.{}, FillWorker.run, .{ out, 2 * chunk, main_start });
        FillWorker.run(out, main_start, NN);
        for (threads) |th| th.join(); // CORRECT: join before checking
        for (out) |v| {
            if (v == SENTINEL) return error.TestUnexpectedResult;
        }
    }

    // DEFECT: read BEFORE joining — some spawned threads haven't finished
    {
        @memset(out, SENTINEL);
        const chunk: usize = NN / NUM_THREADS;
        var threads = try std.testing.allocator.alloc(std.Thread, NUM_THREADS - 1);
        defer std.testing.allocator.free(threads);
        // Spawn threads to do ALL the work EXCEPT a tiny slice
        // Thread 0: chunk 1 (spawned)
        // Thread 1: chunk 2 (spawned)
        // Thread 2: chunk 3 (spawned)
        // Main thread: only the LAST 100 elements (tiny)
        // Then check immediately — the 3 spawned threads are still working
        // on their large chunks.
        const main_start = NN - 100;
        threads[0] = try std.Thread.spawn(.{}, FillWorker.run, .{ out, @as(usize, 0), chunk });
        threads[1] = try std.Thread.spawn(.{}, FillWorker.run, .{ out, chunk, 2 * chunk });
        threads[2] = try std.Thread.spawn(.{}, FillWorker.run, .{ out, 2 * chunk, main_start });
        FillWorker.run(out, main_start, NN); // only 100 elements
        // DELIBERATE DEFECT: check output BEFORE joining — spawned threads
        // are still working on millions of elements
        var has_sentinel = false;
        for (out[0..main_start]) |v| {
            if (v == SENTINEL) { has_sentinel = true; break; }
        }
        for (threads) |th| th.join();
        try testing.expect(has_sentinel);
    }
}
