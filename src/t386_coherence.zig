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
// T386 (flash) — coherence of the graft: where does PSK fresh-start differ
// from the basic-ko fixpoint, and is every difference inside the bracket?
//
// The graft under evaluation resolves the bracket-valued region under
// positional superko while leaving the certified region at its fixpoint
// values. Its coherence rests on two empirical facts:
//   (a) at every position the fixpoint already determines (L == H), the
//       PSK fresh-start value is the SAME value — the graft changes nothing
//       that was determined (T380 F-6 measured 0/24,330 violations at 3×3);
//   (b) at every position the fixpoint does not determine (L < H), the PSK
//       fresh-start value lies INSIDE the bracket — the graft never
//       contradicts a bound the table already makes.
//
// This instrument re-derives (a) and measures (b) at 3×3 (control — must
// reproduce T380 F-6's 680 divergent / 0 at L==H / 0 null-control) and at
// 4×3 (the projection check the brief asks for; the smallest board where a
// fresh construction is needed — no WZO2 artifact exists for 4×3, so the
// basic-ko fixpoint is computed in-process by t386_engine.zig, gated at 3×3
// against the committed table).
//
// Frame per size: every reachable legal position × side with a PSK value.
//   checked            — slots compared (denominator)
//   divergent          — PSK fresh-start != clamp(TIE=0, [L,H])
//   div_at_lh_set      — divergent where L < H
//   div_at_lh_clear    — divergent where L == H (want 0)
//   null_control       — divergent at (L == H, 0-ko-cluster) (want 0)
//   psk_out_of_bracket — PSK value outside [L,H] (want 0; a fresh-start
//                        PSK value outside its own fixpoint bracket would
//                        refute the graft's value-coherence)
//   div_by_class       — divergent by independent-ko-cluster class
//
// Compile (ad hoc):
//   zig build-exe -O ReleaseFast --dep version -Mroot=src/t386_coherence.zig \
//     -Mversion=src/version.zig --cache-dir /tmp/weizigo/t386/kc \
//     --global-cache-dir /tmp/weizigo/t386/gc --name weizigo-t386-coherence \
//     -femit-bin=/tmp/weizigo/t386/coherence
//
// stdout = data, stderr = diagnostics.

const std = @import("std");
const colexmod = @import("colex.zig");
const eng = @import("t386_engine.zig");

const UNDEF: i8 = -128;

pub fn run(comptime W: usize, comptime H: usize, gpa: std.mem.Allocator, psk_path: []const u8, wzo2_path: ?[]const u8) !void {
    const N = W * H;
    const E = eng.Engine(W, H);
    const X = colexmod.Indexer(W, H);
    const Pos = [N]i8;

    std.debug.print("# T386-COHERENCE {d}x{d}\n", .{ W, H });

    const reach = try gpa.alloc(u64, E.ReachWords);
    defer gpa.free(reach);
    const census = try E.census(gpa, reach);
    std.debug.print("# census: reachable={d} legal_boards={d} sweeps={d}\n", .{
        census.total_marked, census.legal_boards, census.sweeps,
    });
    const L = try gpa.alloc(i8, E.TOTAL);
    const Ht = try gpa.alloc(i8, E.TOTAL);
    defer gpa.free(L);
    defer gpa.free(Ht);
    E.seed(reach, L, Ht);
    const conv = E.converge(reach, L, Ht, null);
    std.debug.print("# fixpoint: sweeps={d} converged={}\n", .{ conv.sweeps, conv.converged });
    const h = E.health(reach, L, Ht);
    std.debug.print("# health: L>H={d} bracketed-states={d}\n", .{ h.l_gt_h, h.brackets });

    // regression gate when a committed table exists (3×3 only)
    if (wzo2_path) |path| {
        var wzo = try eng.Wzo2.open(gpa, path);
        defer gpa.free(wzo.groups);
        defer gpa.free(wzo.bytes);
        var mismatches: u64 = 0;
        var entries: u64 = 0;
        for (0..@as(usize, @intCast(wzo.n_groups))) |g| {
            const pos: Pos = X.pos_from_colex(wzo.groups[g].colex);
            const board = E.rank(&pos);
            for (0..wzo.groups[g].count) |i| {
                const e = wzo.entryAt(g, i);
                const side: u8 = if (e.side > 0) 0 else 1;
                const ko: u16 = if (e.passes == 1) E.KO_NONE else e.ko;
                const st = E.State{ .board = board, .side = side, .ko = ko, .passes = e.passes };
                const lin = st.linear();
                entries += 1;
                if (L[lin] != e.L or Ht[lin] != e.H) mismatches += 1;
            }
        }
        std.debug.print("# regression gate vs {s}: entries={d} mismatches={d} (want 0)\n", .{ path, entries, mismatches });
    }

    var psk = try eng.PskTable.load(gpa, psk_path);
    defer psk.deinit();

    var checked: u64 = 0;
    var divergent: u64 = 0;
    var div_lh_set: u64 = 0;
    var div_lh_clear: u64 = 0;
    var div_by_class = [_]u64{0} ** 4;
    var null_control: u64 = 0;
    var psk_out: u64 = 0;
    var psk_out_lh: u64 = 0;
    var ex: u64 = 0;
    var legal_boards: u64 = 0;
    var fs_bracket: u64 = 0;
    var fs_bracket_per_layer = [_]u64{0} ** (N + 1);
    var fs_per_layer = [_]u64{0} ** (N + 1);

    var board: u32 = 0;
    while (board < E.RAW_TOTAL) : (board += 1) {
        const pos: Pos = E.unrank(board);
        if (!E.isLegalBoard(&pos)) continue;
        legal_boards += 1;
        const cl = eng.clustersOf(W, H, &pos);
        const colex: u64 = X.colex_from_pos(&pos);
        for ([_]u8{ 0, 1 }) |side_u| {
            const lin = E.freshStartLin(board, side_u);
            const word = lin >> 6;
            const bit: u64 = @as(u64, 1) << @intCast(lin & 63);
            if (reach[word] & bit == 0) continue;
            const side: i8 = if (side_u == 0) 1 else -1;
            const v = psk.value(colex, side);
            if (v == UNDEF) continue;
            const l = L[lin];
            const hh = Ht[lin];
            checked += 1;
            const ly: usize = E.stonesOf(&pos);
            fs_per_layer[ly] += 1;
            if (l < hh) {
                fs_bracket += 1;
                fs_bracket_per_layer[ly] += 1;
            }
            if (v < l or v > hh) {
                psk_out += 1;
                if (l < hh) psk_out_lh += 1;
            }
            const lh_set = l < hh;
            const bko_v = eng.clampTie(W, H, l, hh);
            if (v != bko_v) {
                divergent += 1;
                if (lh_set) {
                    div_lh_set += 1;
                } else {
                    div_lh_clear += 1;
                    if (cl == 0) null_control += 1;
                }
                div_by_class[if (cl >= 3) 3 else cl] += 1;
                if (ex < 5) {
                    std.debug.print("# DIV colex={d} side={d} psk={d} pinned={d} L={d} H={d} clusters={d}\n", .{
                        colex, side, v, bko_v, l, hh, cl,
                    });
                    ex += 1;
                }
            }
        }
    }
    std.debug.print("# {d}x{d} RESULT: legal_boards={d} checked={d} divergent={d} div_at_L<H={d} div_at_L==H={d} null_control={d} psk_outside_bracket={d} (of which L<H: {d}) div_by_class=[{d},{d},{d},{d}]\n", .{
        W, H, legal_boards, checked, divergent, div_lh_set, div_lh_clear, null_control, psk_out, psk_out_lh,
        div_by_class[0], div_by_class[1], div_by_class[2], div_by_class[3],
    });
    std.debug.print("# {d}x{d} FRESH-START brackets: total={d} per-layer=", .{ W, H, fs_bracket });
    for (0..N + 1) |ly| {
        if (fs_bracket_per_layer[ly] > 0) std.debug.print("L{d}:{d}", .{ ly, fs_bracket_per_layer[ly] });
    }
    std.debug.print(" per-layer-checked=", .{});
    for (0..N + 1) |ly| {
        if (fs_per_layer[ly] > 0) std.debug.print("L{d}:{d}", .{ ly, fs_per_layer[ly] });
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
