////////////////////////////////////////////
//                                        //
//    (c) 2026 Alexander E Genaud         //
//                                        //
//    Permission is granted hereby,       //
//        for any purpose,                //
//    provided these notices multiply.    //
//                                        //
////////////////////////////////////////////
//
// T386 (flash) — does resolving a layer shrink the next? The layered-PSK
// pinning experiment, at 3×3 (regression-gated) and 4×3 (projection).
//
// The operator's Pass 3: "retrograde-BFS until a depth with brackets;
// resolve those to terminal under PSK; then repeat Pass 2 for the next
// layer. Expect fewer instances each round."
//
// This instrument runs that loop exactly, with the pieces the proposal
// names:
//   Pass 2  = the ko-state retrograde fixpoint (t386_engine.zig, ADR-0020
//             semantics: basic-ko legality, TIE=0 cycles, area scoring) —
//             at 3×3 regression-gated entry-for-entry against
//             data/oracle-3x3-v2.wzo2 (the committed table).
//   resolve = pin the FRESH-START key (position, side, ko=none, passes=0)
//             of every bracket-valued (L < H) position at the deepest
//             unresolved layer to its POSITIONAL-SUPERKO fresh-start value
//             (artifacts/oracle-3x3.wzo at 3×3, artifacts/oracle-4x3.wzo
//             at 4×3 — both validated PSK oracles).
//   repeat  = re-converge the fixpoint with the pinned keys held; the
//             free states re-iterate monotonically (pinned values lie
//             inside their brackets, so L can only rise, H only fall, and
//             a certified key stays certified — shrink is structurally
//             non-increasing; the MEASURED question is the rate).
//
// Output per round: layer, keys pinned directly, keys certified by
// propagation (bracketed before, L == H after, never pinned), remaining
// fresh-start brackets, re-convergence sweep count.
//
// Phase 2 (exactness): after the bracket count hits zero, the construction
// is compared against the PSK oracle. Positions whose converged value still
// differs (propagation drifters) are pinned too, and the loop repeats until
// the table equals the PSK oracle. This measures the construction's TRUE
// resolution cost — propagation certifies positions "for free" but can
// certify them to the wrong value; exactness needs those pinned too.
//
// Coherence checks inside the loop: every pinned PSK value must lie inside
// [L,H] (a violation refutes the graft's value-coherence).
//
// Compile (ad hoc):
//   zig build-exe -O ReleaseFast --dep version -Mroot=src/t386_shrink.zig \
//     -Mversion=src/version.zig --cache-dir /tmp/weizigo/t386/kc \
//     --global-cache-dir /tmp/weizigo/t386/gc --name weizigo-t386-shrink \
//     -femit-bin=/tmp/weizigo/t386/shrink
//
// Usage: weizigo-t386-shrink [3x3|4x3]
//
// stdout = data, stderr = diagnostics.

const std = @import("std");
const colexmod = @import("colex.zig");
const eng = @import("t386_engine.zig");

const UNDEF: i8 = -128;

fn freshStartBrackets(comptime W: usize, comptime H: usize, reach: []const u64, L: []i8, Hi: []i8, per_layer: []u64, pinned: ?[]const bool) u64 {
    const N = W * H;
    const E = eng.Engine(W, H);
    const Pos = [N]i8;
    @memset(per_layer, 0);
    var total: u64 = 0;
    var board: u32 = 0;
    while (board < E.RAW_TOTAL) : (board += 1) {
        const pos: Pos = E.unrank(board);
        if (!E.isLegalBoard(&pos)) continue;
        for ([_]u8{ 0, 1 }) |side| {
            const lin = E.freshStartLin(board, side);
            const word = lin >> 6;
            const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
            if (reach[word] & bit == 0) continue;
            if (pinned != null and pinned.?[lin]) continue;
            if (L[lin] < Hi[lin]) {
                const layer: usize = E.stonesOf(&pos);
                per_layer[layer] += 1;
                total += 1;
            }
        }
    }
    return total;
}

pub fn run(comptime W: usize, comptime H: usize, gpa: std.mem.Allocator, psk_path: []const u8, wzo2_path: ?[]const u8) !void {
    const N = W * H;
    const E = eng.Engine(W, H);
    const X = colexmod.Indexer(W, H);
    const Pos = [N]i8;
    std.debug.print("# T386-SHRINK {d}x{d} — layered PSK pinning experiment\n", .{ W, H });

    // ── Pass 2: census + fixpoint (round 0) ────────────────────────────────
    const reach = try gpa.alloc(u64, E.ReachWords);
    defer gpa.free(reach);
    const census = try E.census(gpa, reach);
    std.debug.print("# census: reachable states={d} legal boards={d} sweeps={d}\n", .{
        census.total_marked, census.legal_boards, census.sweeps,
    });

    const L = try gpa.alloc(i8, E.TOTAL);
    const Hi = try gpa.alloc(i8, E.TOTAL);
    defer gpa.free(L);
    defer gpa.free(Hi);
    E.seed(reach, L, Hi);
    const conv0 = E.converge(reach, L, Hi, null);
    std.debug.print("# round-0 fixpoint: sweeps={d} converged={}\n", .{ conv0.sweeps, conv0.converged });
    const h0 = E.health(reach, L, Hi);
    std.debug.print("# round-0 health: L>H={d} bracketed-states={d} (want L>H = 0)\n", .{ h0.l_gt_h, h0.brackets });

    // ── Regression gate: engine == committed WZO2 table, entry-for-entry ───
    if (wzo2_path) |path| {
        var wzo = try eng.Wzo2.open(gpa, path);
        defer gpa.free(wzo.groups);
        defer gpa.free(wzo.bytes);
        var mismatches: u64 = 0;
        var wzo_entries: u64 = 0;
        var fresh_mismatch: u64 = 0;
        var fresh_checked: u64 = 0;
        for (0..@as(usize, @intCast(wzo.n_groups))) |g| {
            const pos: Pos = X.pos_from_colex(wzo.groups[g].colex);
            const board = E.rank(&pos);
            for (0..wzo.groups[g].count) |i| {
                const e = wzo.entryAt(g, i);
                const side: u8 = if (e.side > 0) 0 else 1;
                const ko: u16 = if (e.passes == 1) E.KO_NONE else e.ko;
                const st = E.State{ .board = board, .side = side, .ko = ko, .passes = e.passes };
                const lin = st.linear();
                wzo_entries += 1;
                if (L[lin] != e.L or Hi[lin] != e.H) {
                    mismatches += 1;
                    if (e.passes == 0 and e.ko == E.KO_NONE) fresh_mismatch += 1;
                }
                if (e.passes == 0 and e.ko == E.KO_NONE) fresh_checked += 1;
            }
        }
        std.debug.print("# regression gate vs {s}: entries={d} mismatches={d} fresh-entries-checked={d} fresh-mismatches={d} (want 0)\n", .{
            path, wzo_entries, mismatches, fresh_checked, fresh_mismatch,
        });
        if (mismatches != 0) {
            std.debug.print("# GATE FAILED — engine does not reproduce the committed table; aborting.\n", .{});
            return;
        }
    }

    // ── PSK oracle (the resolution source) ─────────────────────────────────
    var psk = try eng.PskTable.load(gpa, psk_path);
    defer psk.deinit();

    // ── Round loop ─────────────────────────────────────────────────────────
    const pinned = try gpa.alloc(bool, E.TOTAL);
    defer gpa.free(pinned);
    @memset(pinned, false);
    // round-0 L/H snapshot (for phase-2 provenance: were the drifters
    // bracketed / divergent at round 0?)
    const L0 = try gpa.alloc(i8, E.TOTAL);
    const H0 = try gpa.alloc(i8, E.TOTAL);
    defer gpa.free(L0);
    defer gpa.free(H0);
    @memcpy(L0, L);
    @memcpy(H0, Hi);
    const per_layer = try gpa.alloc(u64, N + 1);
    defer gpa.free(per_layer);

    var total_brackets = freshStartBrackets(W, H, reach, L, Hi, per_layer, pinned);
    std.debug.print("# round 0: fresh-start brackets total={d} per-layer=", .{total_brackets});
    for (0..N + 1) |ly| {
        if (per_layer[ly] > 0) std.debug.print("L{d}:{d} ", .{ ly, per_layer[ly] });
    }
    std.debug.print("\n", .{});

    var round: u32 = 0;
    var cum_pinned: u64 = 0;
    var cum_prop: u64 = 0;
    var psk_out: u64 = 0;
    var psk_undef: u64 = 0;

    while (total_brackets > 0 and round < 64) {
        // deepest unresolved layer with a fresh-start bracket
        var layer: usize = N + 1;
        var found: usize = 0;
        while (layer > 0) {
            layer -= 1;
            if (per_layer[layer] > 0) {
                found = layer;
                break;
            }
        }
        if (found == 0 and per_layer[0] == 0) break; // no brackets left
        round += 1;

        // pin every bracket-valued fresh-start key at this layer
        var pinned_this: u64 = 0;
        var board: u32 = 0;
        while (board < E.RAW_TOTAL) : (board += 1) {
            const pos: Pos = E.unrank(board);
            if (E.stonesOf(&pos) != found) continue;
            if (!E.isLegalBoard(&pos)) continue;
            for ([_]u8{ 0, 1 }) |side| {
                const lin = E.freshStartLin(board, side);
                const word = lin >> 6;
                const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
                if (reach[word] & bit == 0) continue;
                if (pinned[lin]) continue;
                if (!(L[lin] < Hi[lin])) continue;
                const colex: u64 = X.colex_from_pos(&pos);
                const v = psk.value(colex, if (side == 0) @as(i8, 1) else @as(i8, -1));
                if (v == UNDEF) {
                    psk_undef += 1;
                    continue;
                }
                if (v < L[lin] or v > Hi[lin]) {
                    psk_out += 1;
                    std.debug.print("# COHERENCE VIOLATION: colex={d} side={d} layer={d} L={d} H={d} psk={d}\n", .{ colex, side, found, L[lin], Hi[lin], v });
                }
                L[lin] = v;
                Hi[lin] = v;
                pinned[lin] = true;
                pinned_this += 1;
            }
        }

        // certified-before-reconverge count (excludes the just-pinned)
        const certified_before = total_brackets - pinned_this;

        // re-converge with pins held
        const conv = E.converge(reach, L, Hi, pinned);
        const h = E.health(reach, L, Hi);
        const remaining = freshStartBrackets(W, H, reach, L, Hi, per_layer, pinned);
        const prop = if (remaining <= certified_before) certified_before - remaining else 0;
        cum_pinned += pinned_this;
        cum_prop += prop;

        std.debug.print("# round {d}: layer={d} pinned={d} propagated-certified={d} remaining={d} sweeps={d} converged={} health(L>H)={d}\n", .{
            round, found, pinned_this, prop, remaining, conv.sweeps, conv.converged, h.l_gt_h,
        });
        std.debug.print("#   per-layer remaining:", .{});
        for (0..N + 1) |ly| {
            if (per_layer[ly] > 0) std.debug.print(" L{d}:{d}", .{ ly, per_layer[ly] });
        }
        std.debug.print("\n", .{});
        total_brackets = remaining;
    }

    const hf = E.health(reach, L, Hi);
    std.debug.print("# SUMMARY: rounds={d} cumulative pinned={d} cumulative propagated-certified={d} final-remaining={d} final-L>H={d} psk-outside-bracket={d} psk-undef-skipped={d}\n", .{
        round, cum_pinned, cum_prop, total_brackets, hf.l_gt_h, psk_out, psk_undef,
    });

    // ── Final verification: the construction's fresh-start table vs the ────
    // PSK oracle, entry-for-entry. If the graft is coherent, every reachable
    // legal position x side must agree (pinned keys are PSK by construction;
    // propagated keys must MATCH the PSK value to validate propagation).
    var final_mismatch: u64 = 0;
    var final_checked: u64 = 0;
    var final_bracket_left: u64 = 0;
    var board2: u32 = 0;
    while (board2 < E.RAW_TOTAL) : (board2 += 1) {
        const pos: Pos = E.unrank(board2);
        if (!E.isLegalBoard(&pos)) continue;
        for ([_]u8{ 0, 1 }) |side| {
            const lin = E.freshStartLin(board2, side);
            const word = lin >> 6;
            const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
            if (reach[word] & bit == 0) continue;
            const colex: u64 = X.colex_from_pos(&pos);
            const v = psk.value(colex, if (side == 0) @as(i8, 1) else @as(i8, -1));
            if (v == UNDEF) continue;
            final_checked += 1;
            if (L[lin] != Hi[lin]) final_bracket_left += 1;
            if (L[lin] != v) {
                final_mismatch += 1;
                if (final_mismatch < 5) {
                    std.debug.print("# FINAL-MISMATCH colex={d} side={d} constructed={d} psk={d} pinned={}\n", .{ colex, side, L[lin], v, pinned[lin] });
                }
            }
        }
    }
    std.debug.print("# FINAL-VERIFY: checked={d} still-bracketed-fresh-start={d} mismatch-vs-PSK={d} (want 0)\n", .{
        final_checked, final_bracket_left, final_mismatch,
    });

    // ── Phase 2: verify-then-pin to PSK exactness. Pin every fresh-start
    // key whose converged value still differs from its PSK value; re-converge;
    // repeat until the table equals the PSK oracle (or a round pins nothing).
    var phase2_rounds: u32 = 0;
    var phase2_pins: u64 = 0;
    const phase2_mismatch_first: u64 = final_mismatch;
    var phase2_mismatch_last: u64 = 0;
    var phase2_divergent: u64 = 0; // of phase-2 pins: divergent at round 0
    var phase2_bracketed_r0: u64 = 0; // of phase-2 pins: L<H at round 0
    var phase2_err_up: u64 = 0; // constructed > psk (too good for Black)
    var phase2_err_dn: u64 = 0; // constructed < psk (too bad for Black)
    var phase2_by_layer = [_]u64{0} ** (N + 1);
    while (true) {
        var mismatch_now: u64 = 0;
        var pin_now: u64 = 0;
        var b2: u32 = 0;
        while (b2 < E.RAW_TOTAL) : (b2 += 1) {
            const pos: Pos = E.unrank(b2);
            if (!E.isLegalBoard(&pos)) continue;
            for ([_]u8{ 0, 1 }) |side| {
                const lin = E.freshStartLin(b2, side);
                const word = lin >> 6;
                const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
                if (reach[word] & bit == 0) continue;
                const colex: u64 = X.colex_from_pos(&pos);
                const v = psk.value(colex, if (side == 0) @as(i8, 1) else @as(i8, -1));
                if (v == UNDEF) continue;
                if (L[lin] != v) {
                    mismatch_now += 1;
                    if (!pinned[lin]) {
                        const l0 = L0[lin];
                        const hh0 = H0[lin];
                        phase2_bracketed_r0 += if (l0 < hh0) 1 else 0;
                        if (v != eng.clampTie(W, H, l0, hh0)) phase2_divergent += 1;
                        if (L[lin] > v) phase2_err_up += 1 else phase2_err_dn += 1;
                        phase2_by_layer[E.stonesOf(&pos)] += 1;
                        L[lin] = v;
                        Hi[lin] = v;
                        pinned[lin] = true;
                        pin_now += 1;
                    }
                }
            }
        }
        if (pin_now == 0) {
            phase2_mismatch_last = mismatch_now;
            break;
        }
        phase2_rounds += 1;
        phase2_pins += pin_now;
        const conv2 = E.converge(reach, L, Hi, pinned);
        const h2 = E.health(reach, L, Hi);
        std.debug.print("# phase2 round {d}: pinned={d} sweeps={d} converged={} health(L>H)={d}\n", .{
            phase2_rounds, pin_now, conv2.sweeps, conv2.converged, h2.l_gt_h,
        });
        if (phase2_rounds > 64) {
            std.debug.print("# phase2 cap reached — aborting\n", .{});
            break;
        }
    }
    std.debug.print("# PHASE2-SUMMARY: rounds={d} extra-pins={d} first-mismatch={d} final-mismatch={d} total-pins={d} of-phase2-pins: bracketed-at-r0={d} divergent-at-r0={d} err-up={d} err-down={d} by-layer=", .{
        phase2_rounds, phase2_pins, phase2_mismatch_first, phase2_mismatch_last, cum_pinned + phase2_pins,
        phase2_bracketed_r0, phase2_divergent, phase2_err_up, phase2_err_dn,
    });
    for (0..N + 1) |ly| {
        if (phase2_by_layer[ly] > 0) std.debug.print("L{d}:{d} ", .{ ly, phase2_by_layer[ly] });
    }
    std.debug.print("\n", .{});
}

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    const mode: []const u8 = args.next() orelse "3x3";

    if (std.mem.eql(u8, mode, "3x3")) {
        try run(3, 3, gpa, "artifacts/oracle-3x3.wzo", "data/oracle-3x3-v2.wzo2");
    } else if (std.mem.eql(u8, mode, "4x3")) {
        try run(4, 3, gpa, "artifacts/oracle-4x3.wzo", null);
    } else {
        std.debug.print("unknown mode {s}\n", .{mode});
    }
}
