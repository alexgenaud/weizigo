// GLOBAL.FP3 re-derivation probe (DCLAIM chunk, 2026-08-22, deepseek-v4-flash).
//
// Claim row (docs/epistemic/CLAIMS.md): `GLOBAL.FP3` — "Bellman iteration
// terminates in finitely many sweeps (monotone map on a finite lattice)",
// PROVEN at `CONCEPTS.md:43-46`; `4x3/EPISTEMIC.md:31`. CONCEPTS.md:43-46
// states the claim precisely: "FP3 iteration converges in finite sweeps (the
// theorem) — the lattice argument that the Bellman iteration terminates.
// Prove: monotone map on a finite lattice (structural; the sweep *count* is a
// measurement, M2, not the theorem)".
//
// So the claim to re-derive is the theorem itself: for ANY monotone map f on
// a FINITE lattice, Kleene iteration (the engine's sweep) seeded from the
// lattice bottom / top terminates in finitely many sweeps, at the least /
// greatest fixpoint respectively.
//
// This probe re-derives the theorem empirically on random monotone maps over
// finite lattices (product of chains, the same lattice shape as the engine's
// score tables: functions from states to a bounded score range, ordered
// pointwise). For every map it checks, exhaustively:
//
//   (1) GENERATOR SELF-CHECK — f is genuinely monotone. Without this the
//       probe could pass vacuously on non-monotone maps (the theorem has no
//       content for them). A non-monotone f fails here and the trial counts
//       as a violation, never as evidence.
//   (2) FINITE TERMINATION — Kleene iteration from the bottom element
//       (engine's seed for L is the lattice bottom, -N) and from the top
//       element (engine's seed for H is +N) each stabilizes within |L|
//       sweeps, at a fixpoint. |L| is the finite-lattice bound: the Kleene
//       chain is non-decreasing (monotonicity + bottom/top seed), so a
//       strictly-increasing run can visit at most |L| distinct values.
//   (3) LEASTNESS / GREATESTNESS WITNESS — the fixpoint reached from the
//       bottom equals Tarski's independent characterization of the LEAST
//       fixpoint, meet{ y : f(y) <= y } (meet of all post-fixpoints); the
//       fixpoint reached from the top equals join{ y : y <= f(y) } (join of
//       all pre-fixpoints), the GREATEST fixpoint. These are computed by a
//       separate O(n^2) pass over the whole lattice, NOT by iteration, so
//       agreement is an independent witness that iteration stopped at the
//       right fixpoint (this is the content GLOBAL.FP1 inherits from FP3).
//
// Run:  tools/runner -- zig run docs/evidence/GLOBAL-FP3/probe_fp3_finite_lattice_2026_08_22.zig
//       (tools/runner forces -O ReleaseFast; asserts are no-ops there, which
//       is why every check is an explicit counter, not an assert).
//
// Fixed seed: re-runs reproduce byte-identical output.
//
// Identifier: deepseek-v4-flash/DCLAIM (task DCLAIM, duty 1).

const std = @import("std");

fn pow(comptime base: usize, comptime exp: usize) usize {
    var r: usize = 1;
    inline for (0..exp) |_| r *= base;
    return r;
}

/// Finite lattice: product of D chains, each of length C, ordered
/// componentwise. Elements are [D]u8 with coordinates in 0..C-1.
/// |L| = C^D. Bottom = all zeros, top = all (C-1) — exactly the shape of the
/// engine's score-table lattice (functions from states to scores in [-N,+N],
/// ordered pointwise, bounded hence finite).
fn Lattice(comptime C: usize, comptime D: usize) type {
    return struct {
        const Self = @This();
        pub const c: usize = C;
        pub const d: usize = D;
        pub const Elem = [D]u8;
        pub const n: usize = pow(C, D);
        pub const bottom: Elem = [_]u8{0} ** D;
        pub const top: Elem = [_]u8{@intCast(C - 1)} ** D;

        pub fn leq(a: Elem, b: Elem) bool {
            inline for (0..D) |i| {
                if (a[i] > b[i]) return false;
            }
            return true;
        }
        pub fn meet(a: Elem, b: Elem) Elem {
            var r: Elem = undefined;
            inline for (0..D) |i| r[i] = @min(a[i], b[i]);
            return r;
        }
        pub fn join(a: Elem, b: Elem) Elem {
            var r: Elem = undefined;
            inline for (0..D) |i| r[i] = @max(a[i], b[i]);
            return r;
        }
        pub fn eq(a: Elem, b: Elem) bool {
            inline for (0..D) |i| {
                if (a[i] != b[i]) return false;
            }
            return true;
        }
        /// mixed-radix encode: element -> index in 0..n-1 (a bijection).
        pub fn toIndex(v: Elem) usize {
            var r: usize = 0;
            var mul: usize = 1;
            inline for (0..D) |i| {
                r += v[i] * mul;
                mul *= C;
            }
            return r;
        }
        /// mixed-radix decode: index -> element.
        pub fn fromIndex(idx: usize) Elem {
            var x: Elem = undefined;
            var rem = idx;
            inline for (0..D) |i| {
                x[i] = @intCast(rem % C);
                rem /= C;
            }
            return x;
        }
    };
}

const Mode = enum { upper, lower };

/// Build a monotone map f: L -> L.
/// mode == .upper: f(x) = meet{ g(y) : y >= x }  — monotone (if x <= x',
///   the upper cone of x' is a subset of the upper cone of x, so the meet of
///   the subset is >= the meet of the superset).
/// mode == .lower: f(x) = join{ g(y) : y <= x }  — monotone (dual argument).
/// g is a uniformly random map L -> L; the two modes sample two different
/// regions of the monotone-map space. Monotonicity is still re-verified
/// exhaustively per map (check 1), so a bug in this construction cannot
/// produce a vacuous pass.
fn buildMonotone(comptime L: type, rng: std.Random, mode: Mode) [L.n]L.Elem {
    const Elem = L.Elem;
    var g: [L.n]Elem = undefined;
    for (0..L.n) |i| {
        var e: Elem = undefined;
        inline for (0..L.d) |j| e[j] = rng.intRangeAtMost(u8, 0, @intCast(L.c - 1));
        g[i] = e;
    }
    var f: [L.n]Elem = undefined;
    for (0..L.n) |i| {
        const x = L.fromIndex(i);
        var acc: Elem = undefined;
        var first = true;
        for (0..L.n) |k| {
            const y = L.fromIndex(k);
            const in_cone = if (mode == .upper) L.leq(x, y) else L.leq(y, x);
            if (in_cone) {
                acc = if (first)
                    g[k]
                else if (mode == .upper)
                    L.meet(acc, g[k])
                else
                    L.join(acc, g[k]);
                first = false;
            }
        }
        f[i] = acc;
    }
    return f;
}

fn isMonotone(comptime L: type, f: *const [L.n]L.Elem) bool {
    for (0..L.n) |i| {
        const x = L.fromIndex(i);
        const fx = f[i];
        for (0..L.n) |j| {
            const y = L.fromIndex(j);
            if (L.leq(x, y) and !L.leq(fx, f[j])) return false;
        }
    }
    return true;
}

/// Kleene iteration seeded at `seed`, bounded by |L| sweeps (the theorem's
/// finite bound). Returns a converged flag, sweeps taken (1-based), and the
/// value reached.
fn kleeneIterate(comptime L: type, f: *const [L.n]L.Elem, seed: L.Elem) struct { converged: bool, sweeps: usize, value: L.Elem } {
    var cur = seed;
    var sweeps: usize = 0;
    while (sweeps < L.n) : (sweeps += 1) {
        const next = f[L.toIndex(cur)];
        if (L.eq(next, cur)) {
            return .{ .converged = true, .sweeps = sweeps + 1, .value = cur };
        }
        cur = next;
    }
    return .{ .converged = false, .sweeps = L.n, .value = cur };
}

/// Tarski's independent characterization of the LEAST fixpoint:
/// lfp = meet{ y : f(y) <= y } over all post-fixpoints.
/// (top is always a post-fixpoint: f(top) <= top — so the set is nonempty.)
fn leastFixpointWitness(comptime L: type, f: *const [L.n]L.Elem) L.Elem {
    var acc: L.Elem = L.top;
    var first = true;
    for (0..L.n) |i| {
        const y = L.fromIndex(i);
        if (L.leq(f[i], y)) {
            acc = if (first) y else L.meet(acc, y);
            first = false;
        }
    }
    return acc;
}

/// Tarski's independent characterization of the GREATEST fixpoint:
/// gfp = join{ y : y <= f(y) } over all pre-fixpoints.
/// (bottom is always a pre-fixpoint: bottom <= f(bottom).)
fn greatestFixpointWitness(comptime L: type, f: *const [L.n]L.Elem) L.Elem {
    var acc: L.Elem = L.bottom;
    var first = true;
    for (0..L.n) |i| {
        const y = L.fromIndex(i);
        if (L.leq(y, f[i])) {
            acc = if (first) y else L.join(acc, y);
            first = false;
        }
    }
    return acc;
}

const CheckCounts = struct {
    maps: usize = 0,
    not_monotone: usize = 0,
    bottom_not_converged: usize = 0,
    top_not_converged: usize = 0,
    bottom_sweeps_over_n: usize = 0,
    top_sweeps_over_n: usize = 0,
    bottom_not_fixpoint: usize = 0,
    top_not_fixpoint: usize = 0,
    lfp_mismatch: usize = 0,
    gfp_mismatch: usize = 0,
    lfp_witness_not_fixpoint: usize = 0,
    gfp_witness_not_fixpoint: usize = 0,
    max_sweeps_bottom: usize = 0,
    max_sweeps_top: usize = 0,
};

fn runBattery(comptime C: usize, comptime D: usize, trials: usize, rng: std.Random, counts: *CheckCounts) void {
    const L = Lattice(C, D);
    var local_max_b: usize = 0;
    var local_max_t: usize = 0;
    for (0..trials) |t| {
        const mode: Mode = if (t % 2 == 0) .upper else .lower;
        const f = buildMonotone(L, rng, mode);
        counts.maps += 1;

        if (!isMonotone(L, &f)) {
            counts.not_monotone += 1;
            continue; // map is not monotone — the theorem does not apply; count as violation, no further checks
        }

        const r_b = kleeneIterate(L, &f, L.bottom);
        const r_t = kleeneIterate(L, &f, L.top);

        if (!r_b.converged) counts.bottom_not_converged += 1;
        if (r_b.sweeps > L.n) counts.bottom_sweeps_over_n += 1;
        if (r_t.sweeps > L.n) counts.top_sweeps_over_n += 1;
        if (!r_t.converged) counts.top_not_converged += 1;

        if (r_b.converged) {
            if (r_b.sweeps > local_max_b) local_max_b = r_b.sweeps;
            if (!L.eq(f[L.toIndex(r_b.value)], r_b.value)) counts.bottom_not_fixpoint += 1;
        }
        if (r_t.converged) {
            if (r_t.sweeps > local_max_t) local_max_t = r_t.sweeps;
            if (!L.eq(f[L.toIndex(r_t.value)], r_t.value)) counts.top_not_fixpoint += 1;
        }

        // Independent Tarski witnesses must agree with the iteration results
        // and must themselves be fixpoints.
        const lfp = leastFixpointWitness(L, &f);
        const gfp = greatestFixpointWitness(L, &f);
        if (!L.eq(f[L.toIndex(lfp)], lfp)) counts.lfp_witness_not_fixpoint += 1;
        if (!L.eq(f[L.toIndex(gfp)], gfp)) counts.gfp_witness_not_fixpoint += 1;
        if (r_b.converged and !L.eq(r_b.value, lfp)) counts.lfp_mismatch += 1;
        if (r_t.converged and !L.eq(r_t.value, gfp)) counts.gfp_mismatch += 1;
    }
    if (local_max_b > counts.max_sweeps_bottom) counts.max_sweeps_bottom = local_max_b;
    if (local_max_t > counts.max_sweeps_top) counts.max_sweeps_top = local_max_t;
    out("  C={d} D={d} |L|={d}: {d} maps, max sweeps bottom->{d} / top->{d}\n", .{ C, D, L.n, trials, local_max_b, local_max_t });
}

var stdout_ready = false;
var stdout_buf: [4096]u8 = undefined;
var stdout_writer: std.Io.File.Writer = undefined;

/// stdout = data (the probe's readings). One persistent writer (T307: a new
/// File.Writer per call pwritev's at offset 0 on regular files).
fn out(comptime fmt: []const u8, args: anytype) void {
    if (!stdout_ready) {
        stdout_writer = std.Io.File.stdout().writer(
            std.Io.Threaded.global_single_threaded.io(),
            &stdout_buf,
        );
        stdout_ready = true;
    }
    var w = stdoutWriter();
    w.interface.print(fmt, args) catch {};
    w.flush() catch {};
}

fn stdoutWriter() *std.Io.File.Writer {
    return &stdout_writer;
}

pub fn main() !void {
    const seed: u64 = 0x667033; // "fp3"
    var prng = std.Random.DefaultPrng.init(seed);
    const rng = prng.random();

    out("GLOBAL.FP3 re-derivation probe — monotone map on a finite lattice => finite-sweep termination\n", .{});
    out("date 2026-08-22, seed {x}, toolchain zig {s}\n", .{ seed, @import("builtin").zig_version_string });

    var counts: CheckCounts = .{};

    // (C, D, trials): n = C^D. Small lattices get thousands of maps; the
    // largest lattice (n=8000) still gets the full exhaustive treatment.
    runBattery(5, 4, 2000, rng, &counts); // n = 625
    runBattery(7, 4, 100, rng, &counts); // n = 2401
    runBattery(9, 4, 10, rng, &counts); // n = 6561
    runBattery(20, 3, 8, rng, &counts); // n = 8000

    out("\nTOTALS — {d} random monotone maps over finite lattices (C^D = {d}..{d} elements)\n", .{ counts.maps, 625, 8000 });
    out("  (1) generator monotone:            {d} violations / {d} maps\n", .{ counts.not_monotone, counts.maps });
    out("  (2) bottom seed converged <= |L|:  {d} violations / {d} maps  (max {d} sweeps)\n", .{ counts.bottom_not_converged + counts.bottom_sweeps_over_n, counts.maps, counts.max_sweeps_bottom });
    out("  (2) top seed converged <= |L|:     {d} violations / {d} maps  (max {d} sweeps)\n", .{ counts.top_not_converged + counts.top_sweeps_over_n, counts.maps, counts.max_sweeps_top });
    out("  (2) reached value is a fixpoint:   {d} violations / {d} maps\n", .{ counts.bottom_not_fixpoint + counts.top_not_fixpoint, counts.maps });
    out("  (3) bottom == least fixpoint:      {d} violations / {d} maps\n", .{ counts.lfp_mismatch + counts.lfp_witness_not_fixpoint, counts.maps });
    out("  (3) top == greatest fixpoint:      {d} violations / {d} maps\n", .{ counts.gfp_mismatch + counts.gfp_witness_not_fixpoint, counts.maps });

    const total_violations = counts.not_monotone +
        counts.bottom_not_converged + counts.top_not_converged +
        counts.bottom_sweeps_over_n + counts.top_sweeps_over_n +
        counts.bottom_not_fixpoint + counts.top_not_fixpoint +
        counts.lfp_mismatch + counts.gfp_mismatch +
        counts.lfp_witness_not_fixpoint + counts.gfp_witness_not_fixpoint;

    if (total_violations == 0) {
        out("\nVERDICT: 0 violations / {d} maps — theorem REPRODUCED on every monotone map tested\n", .{ counts.maps });
    } else {
        out("\nVERDICT: {d} violations / {d} maps — theorem NOT reproduced; see counters above\n", .{ total_violations, counts.maps });
        std.process.exit(1);
    }
}
