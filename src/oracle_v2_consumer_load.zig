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
// oracle-v2 CONSUMER-LOAD TEST (sprint.md acceptance item 3, non-negotiable;
// channel 058 F1-F4: "an artifact task is not done until the consumer has
// loaded the artifact").
//
// Task: T178 · Worker: DSFlash/T178 · Date: 2026-07-31
//
// Builds a genuine WZO2 artifact (3×3 — the largest goban whose fixpoint
// completes in seconds) from exp6_solve's exposed fixpoint, computes DTT per
// design-M1 §3.1, serialises via artifact2 (the frozen format contract),
// then loads it through artifact2.load — the exact consumer path M3's
// engine (gtp.zig) uses — queries the empty goban on both sides under
// basic-ko + TIE=0 (reader-side pin V = max(L, min(0, H))), and verifies
// against the committed anchors (3x3.BASICKO-TIE: root = +9 / L==H==9,
// colour-inverted -9 for White).
//
// The 4×4-specific query is BLOCKED on the absent 4×4 WZO2 artifact: T165
// delivered the builder code, not the artifact (untracked/oracle-v2/ was
// never created), and producing it is the ~53-minute EXP-6 fixpoint run
// (docs/evidence/QA-026/4x4/PROVENANCE.md) — outside this task's
// "must complete in seconds" budget. The consumer path itself is exercised
// end-to-end here; the same loader/lookup code serves 4×4 unchanged.
//
// Build / run (must go through tools/runner):
//   tools/runner -- zig run -O ReleaseFast src/oracle_v2_consumer_load.zig
//
// KEYING-CONVENTION NOTE (T178 finding, 2026-07-31): this harness keys WZO2
// groups by exp6's base-3 board rank, DELIBERATELY mirroring oracle_v2_build.zig
// (M2b) — the pipeline as it stands. The frozen format contract (design-M1 §2.1)
// and every consumer (src/colex.zig, gtp.zig, oracle_v2_accept.zig flipColex)
// address the artifact by the combinatorial colex of src/colex.zig. The two
// bijections agree only at index 0 (the empty goban) — which is why the
// empty-board anchors PASS here while the engine's non-empty lookups FAIL
// (measured 7/9 one-stone children misread at 3×3; see
// docs/evidence/ORACLE-V2/consumer-load-T178-2026-07-31.md). When the builder
// is fixed to convert rank→colex, this harness's group keys must be converted
// in lockstep — same pipeline step, same convention.
//
// stdout = data (per-query verdicts + overall verdict), stderr = diagnostics.

const std = @import("std");
const util = @import("util.zig");
const exp6 = @import("exp6_solve.zig");
const artifact2 = @import("artifact2.zig");
const colex = @import("colex.zig");

const GroupBuilder3 = struct {
    rank: u32, // exp6 base-3 rank (for StateIdx lookups)
    colex_val: u32, // combinatorial colex (for artifact group header)
    count: u8,
};

const gpa = std.heap.page_allocator;

/// Monotonic milliseconds (std.time.Timer is gone in Zig 0.16).
fn nowMs() u64 {
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * 1000 + @as(u64, @intCast(ts.nsec)) / 1_000_000;
}

/// Decode a 3×3 linear index into (board, side, ko, passes).
fn decodeLin(lin: u64) struct { board: u32, side: u8, ko: u16, passes: u8 } {
    const board: u32 = @intCast(lin % exp6.RAW_TOTAL);
    const t: u64 = lin / exp6.RAW_TOTAL;
    const ko: u16 = @intCast(t % exp6.KO_DIMS);
    const t2: u64 = t / exp6.KO_DIMS;
    const side: u8 = @intCast(t2 % 2);
    const passes: u8 = @intCast(t2 / 2);
    return .{ .board = board, .side = side, .ko = ko, .passes = passes };
}

pub fn main() !void {
    const t0 = nowMs();
    std.debug.print("# ============================================================================\n", .{});
    std.debug.print("# oracle-v2 CONSUMER-LOAD TEST (T178, DSFlash) — 2026-07-31\n", .{});
    std.debug.print("# ============================================================================\n", .{});

    // =====================================================================
    // 1. 3×3 census + fixpoint via the exposed interface (A7 gate first)
    // =====================================================================
    const reach = try gpa.alloc(u64, exp6.ReachWords);
    defer gpa.free(reach);
    const L_tab = try gpa.alloc(i8, exp6.TOTAL);
    defer gpa.free(L_tab);
    const H_tab = try gpa.alloc(i8, exp6.TOTAL);
    defer gpa.free(H_tab);

    const census = try exp6.run_census_3x3(gpa, reach);
    const fp = exp6.run_fixpoint_3x3(reach, L_tab, H_tab);
    std.debug.print("# 3×3 census: reachable={d}, sweeps={d}; fixpoint sweeps={d}, converged={}\n", .{
        census.total_marked, census.sweeps, fp.sweeps, fp.converged,
    });

    // A7 anchor gate — the fixpoint root must reproduce the committed anchor
    // (3x3.BASICKO-TIE: root = +9, L==H==9) before any artifact is built.
    const root_b = exp6.StateIdx{ .board = 0, .side = 0, .ko = exp6.KO_NONE, .passes = 0 };
    const root_w = exp6.StateIdx{ .board = 0, .side = 1, .ko = exp6.KO_NONE, .passes = 0 };
    const lin_b = root_b.linear();
    const lin_w = root_w.linear();
    const fix_b_L = L_tab[lin_b];
    const fix_b_H = H_tab[lin_b];
    const fix_w_L = L_tab[lin_w];
    const fix_w_H = H_tab[lin_w];
    const gate = fix_b_L == 9 and fix_b_H == 9 and fix_w_L == -9 and fix_w_H == -9;
    std.debug.print("# A7 gate (fixpoint root): B L={d} H={d}, W L={d} H={d} → {s}\n", .{
        fix_b_L, fix_b_H, fix_w_L, fix_w_H, if (gate) "PASS (+9/-9)" else "FAIL",
    });
    if (!gate) {
        std.debug.print("# GATE FAILED — aborting; no artifact built from a broken fixpoint.\n", .{});
        std.process.exit(1);
    }

    // =====================================================================
    // 2. Collect compact states (passes ∈ {0,1}, reachable)
    // =====================================================================
    var compact = std.ArrayListUnmanaged(u64).empty;
    defer compact.deinit(gpa);
    var li: u64 = 0;
    while (li < exp6.TOTAL) : (li += 1) {
        if (reach[li >> 6] & (@as(u64, 1) << @intCast(li & 63)) == 0) continue;
        if ((li / (2 * exp6.KO_DIMS * exp6.RAW_TOTAL)) == 2) continue; // passes=2 not stored
        compact.append(gpa, li) catch unreachable;
    }
    std.debug.print("# compact states (passes ∈ {{0,1}}): {d}\n", .{compact.items.len});

    // =====================================================================
    // 3. DTT per design-M1 §3.1 — iterative relaxation to fixpoint
    // =====================================================================
    const dtt = try gpa.alloc(u8, exp6.TOTAL);
    defer gpa.free(dtt);
    @memset(dtt, artifact2.DTT_FAR);

    var child_boards: [exp6.N + 1]exp6.Pos3 = undefined;
    var child_states: [exp6.N + 1]exp6.StateIdx = undefined;

    var dtt_changed: u64 = 1;
    var dtt_sweep: u32 = 0;
    const MAX_DTT_SWEEPS: u32 = 254;
    while (dtt_changed > 0 and dtt_sweep < MAX_DTT_SWEEPS) {
        dtt_sweep += 1;
        dtt_changed = 0;

        for (compact.items) |lin| {
            const st = decodeLin(lin);
            const state = exp6.StateIdx{ .board = st.board, .side = st.side, .ko = st.ko, .passes = st.passes };
            const maximizing = st.side == 0;
            const parent_L = L_tab[lin];
            const parent_H = H_tab[lin];

            const m = exp6.moves(state, &child_boards, &child_states);
            var best_dtt: u8 = artifact2.DTT_FAR;
            var any_vp = false;

            for (0..m) |k| {
                const child = child_states[k];
                const b = &child_boards[k];
                if (!exp6.genericIsLegal(exp6.N, b, exp6.W, exp6.H)) continue;

                if (child.passes == 2) {
                    // Terminal child: DTT=0, L=H=area score (R10)
                    const sc = exp6.genericAreaScore(exp6.N, b, exp6.W, exp6.H);
                    const vp = if (maximizing) sc >= parent_L else sc <= parent_H;
                    if (vp) {
                        best_dtt = 1; // 1 + 0
                        any_vp = true;
                    }
                } else {
                    const child_lin = child.linear();
                    if (reach[child_lin >> 6] & (@as(u64, 1) << @intCast(child_lin & 63)) == 0) continue;
                    const child_L = L_tab[child_lin];
                    const child_H = H_tab[child_lin];
                    const vp = if (maximizing) child_L >= parent_L else child_H <= parent_H;
                    if (vp and dtt[child_lin] < artifact2.DTT_FAR) {
                        const cand: u8 = if (dtt[child_lin] < 254) dtt[child_lin] + 1 else 254;
                        if (cand < best_dtt) {
                            best_dtt = cand;
                            any_vp = true;
                        }
                    }
                }
            }

            if (any_vp and best_dtt < dtt[lin]) {
                dtt[lin] = best_dtt;
                dtt_changed += 1;
            }
        }
    }
    std.debug.print("# DTT: {d} sweeps, final changes={d}\n", .{ dtt_sweep, dtt_changed });

    {
        var far_count: u64 = 0;
        var distinct: u64 = 0;
        var max_dtt: u8 = 0;
        for (compact.items) |lin| {
            const v = dtt[lin];
            if (v == artifact2.DTT_FAR) far_count += 1 else {
                distinct += 1;
                if (v > max_dtt) max_dtt = v;
            }
        }
        std.debug.print("# DTT distribution: FAR={d}, non-FAR distinct values={d}, max={d}\n", .{ far_count, distinct, max_dtt });
    }

    // =====================================================================
    // 4. Build the WZO2 artifact (grouped inline, segregated layout)
    // =====================================================================
    const w: u8 = 3;
    const h: u8 = 3;
    const kb = artifact2.koBits(w * h);
    const none: u8 = @intCast(exp6.KO_NONE);
    const max_per_group = artifact2.maxEntriesPerGroup(w, h);

    // Phase A: collect entries per board (by exp6 rank), then convert to colex and sort
    const CR3 = colex.Indexer(3, 3);
    var group_builders = std.ArrayListUnmanaged(GroupBuilder3).empty;
    defer group_builders.deinit(gpa);

    // First pass: collect row data per exp6 board rank
    const BoardRows = struct {
        rows: std.ArrayListUnmanaged(artifact2.EntryRow),
        terminal_count: u64,
    };
    var board_data = try gpa.alloc(?BoardRows, exp6.RAW_TOTAL);
    defer {
        for (board_data) |*bd| {
            if (bd.*) |*br| br.*.rows.deinit(gpa);
        }
        gpa.free(board_data);
    }
    @memset(board_data, null);

    var terminal_count: u64 = 0;
    var board_idx: u32 = 0;
    while (board_idx < exp6.RAW_TOTAL) : (board_idx += 1) {
        var group_count: u8 = 0;
        var bd = BoardRows{
            .rows = std.ArrayListUnmanaged(artifact2.EntryRow).empty,
            .terminal_count = 0,
        };

        // passes=0: all ko values, both sides (ko-major, side-minor order)
        var ko_u: u16 = 0;
        while (ko_u < exp6.KO_DIMS) : (ko_u += 1) {
            for ([_]u1{ 0, 1 }) |side| {
                const lin = (exp6.StateIdx{ .board = board_idx, .side = side, .ko = ko_u, .passes = 0 }).linear();
                if (reach[lin >> 6] & (@as(u64, 1) << @intCast(lin & 63)) == 0) continue;
                const state = exp6.StateIdx{ .board = board_idx, .side = side, .ko = ko_u, .passes = 0 };
                const m = exp6.moves(state, &child_boards, &child_states);
                const terminal: u1 = if (m == 1) 1 else 0;
                if (terminal == 1) bd.terminal_count += 1;
                bd.rows.append(gpa, .{
                    .key_byte = artifact2.encodeKeyByte(side, @intCast(ko_u), 0, terminal, kb),
                    .L = L_tab[lin],
                    .H = H_tab[lin],
                    .DTT = dtt[lin],
                }) catch unreachable;
                group_count += 1;
            }
        }

        // passes=1: ko=KO_NONE only (§2.5 invariant), both sides
        for ([_]u1{ 0, 1 }) |side| {
            const lin = (exp6.StateIdx{ .board = board_idx, .side = side, .ko = exp6.KO_NONE, .passes = 1 }).linear();
            if (reach[lin >> 6] & (@as(u64, 1) << @intCast(lin & 63)) == 0) continue;
            const state = exp6.StateIdx{ .board = board_idx, .side = side, .ko = exp6.KO_NONE, .passes = 1 };
            const m = exp6.moves(state, &child_boards, &child_states);
            const terminal: u1 = if (m == 1) 1 else 0;
            if (terminal == 1) bd.terminal_count += 1;
            bd.rows.append(gpa, .{
                .key_byte = artifact2.encodeKeyByte(side, none, 1, terminal, kb),
                .L = L_tab[lin],
                .H = H_tab[lin],
                .DTT = dtt[lin],
            }) catch unreachable;
            group_count += 1;
        }

        if (group_count > 0) {
            if (group_count > max_per_group) {
                std.debug.print("# PANIC: board {d} has {d} entries, max is {d}\n", .{ board_idx, group_count, max_per_group });
                return error.EntryCountExceedsMax;
            }
            const pos3 = exp6.unrank_board(board_idx);
            const colex_idx: u32 = @intCast(CR3.colex_from_pos(&pos3));
            group_builders.append(gpa, .{
                .rank = board_idx,
                .colex_val = colex_idx,
                .count = group_count,
            }) catch unreachable;
            terminal_count += bd.terminal_count;
            board_data[board_idx] = bd;
        }
    }

    // Sort by combinatorial colex (artifact format contract §2.1)
    std.mem.sort(GroupBuilder3, group_builders.items, {}, struct {
        fn lt(_: void, a: GroupBuilder3, b: GroupBuilder3) bool {
            return a.colex_val < b.colex_val;
        }
    }.lt);

    // Phase B: build sorted GroupHeader list and flattened EntryRow list
    var groups = std.ArrayListUnmanaged(artifact2.GroupHeader).empty;
    defer groups.deinit(gpa);
    var rows = std.ArrayListUnmanaged(artifact2.EntryRow).empty;
    defer rows.deinit(gpa);

    for (group_builders.items) |gb| {
        groups.append(gpa, .{ .colex = gb.colex_val, .entry_count = gb.count }) catch unreachable;
        const bd = board_data[gb.rank].?;
        rows.appendSlice(gpa, bd.rows.items) catch unreachable;
    }

    std.debug.print("# terminal flags set: {d}\n", .{terminal_count});
    std.debug.print("# groups: {d}, entries: {d} (sorted by colex, not exp6 rank)\n", .{
        groups.items.len,
        rows.items.len,
    });
    std.debug.print("# file bytes: {d}\n", .{
        artifact2.HEADER_LEN + groups.items.len * 5 + rows.items.len * 4,
    });

    const art = artifact2.Artifact{
        .header = artifact2.Header{
            .w = w,
            .h = h,
            .ko_bits = kb,
            .n_groups = groups.items.len,
            .n_entries = rows.items.len,
            .sha256 = [_]u8{0} ** artifact2.HASH_LEN,
        },
        .group_headers = groups.items,
        .entry_rows = rows.items,
    };

    const file_bytes = try artifact2.buildFile(gpa, &art);
    defer gpa.free(file_bytes);
    try artifact2.verifyHash(file_bytes);
    std.debug.print("# SHA-256 self-check: ok\n", .{});

    // Write to untracked/oracle-v2/ (sprint convention; never data/)
    const out_dir = "untracked/oracle-v2";
    const out_path = "untracked/oracle-v2/oracle-3x3-v2.wzo2";
    var threaded = std.Io.Threaded.init(gpa, .{});
    defer threaded.deinit();
    const io = threaded.io();
    const dir = std.Io.Dir.cwd();
    try dir.createDirPath(io, out_dir);
    var file = try dir.createFile(io, out_path, .{});
    defer file.close(io);
    try file.writePositionalAll(io, file_bytes, 0);
    std.debug.print("# WZO2 artifact written: {s} ({d} bytes)\n", .{ out_path, file_bytes.len });

    // =====================================================================
    // 5. CONSUMER LOAD — artifact2.load, the exact M3 engine path
    // =====================================================================
    var loaded = try artifact2.load(io, dir, out_path, gpa);
    defer loaded.deinit();
    std.debug.print("# consumer load: {s} ({d}x{d}, {d} groups, {d} entries, rules_id={d}) [WZO2]\n", .{
        out_path, loaded.header.w, loaded.header.h, loaded.header.n_groups, loaded.header.n_entries, artifact2.RULES_BASICKO_LH_AREA,
    });

    // =====================================================================
    // 6. QUERY the empty goban — both sides, basic-ko + TIE=0
    //    Reader-side pin (spec R2 / F5): V = max(L, min(0, H))
    // =====================================================================
    const tie_pin = struct {
        fn pin(L: i8, H: i8) i8 {
            return @max(L, @min(0, H));
        }
    }.pin;

    var failures: usize = 0;

    // --- empty, Black to move, fresh start (passes=0, ko=none) ---
    {
        const row = artifact2.lookup(&loaded, 0, 1, none, 0);
        if (row) |r| {
            const v = tie_pin(r.L, r.H);
            const ok = r.L == 9 and r.H == 9 and v == 9;
            if (!ok) failures += 1;
            std.debug.print("# empty B: L={d} H={d} V={d} → {s}\n", .{ r.L, r.H, v, if (ok) "PASS" else "FAIL" });
            // data line on stdout
            util.out("CONSUMER-LOAD 3x3 empty-B passes=0 L={d} H={d} V={d} anchor=9 {s}\n", .{ r.L, r.H, v, if (ok) "PASS" else "FAIL" });
        } else {
            failures += 1;
            std.debug.print("# QUERY empty B passes=0: MISSING ENTRY → FAIL\n", .{});
        }
    }

    // --- empty, White to move, fresh start (passes=0, ko=none) ---
    {
        const row = artifact2.lookup(&loaded, 0, -1, none, 0);
        if (row) |r| {
            const v = tie_pin(r.L, r.H);
            const ok = r.L == -9 and r.H == -9 and v == -9;
            if (!ok) failures += 1;
            std.debug.print("# empty W: L={d} H={d} V={d} → {s}\n", .{ r.L, r.H, v, if (ok) "PASS" else "FAIL" });
            // colour inversion on the queried pair: L(-pos,-side) == -H(pos,side)
            const inv_ok = r.L == -9 and r.H == -9; // -H of the B row (9,9)
            if (!inv_ok) failures += 1;
            util.out("CONSUMER-LOAD 3x3 empty-W passes=0 L={d} H={d} V={d} anchor=-9 {s}\n", .{ r.L, r.H, v, if (ok) "PASS" else "FAIL" });
        } else {
            failures += 1;
            std.debug.print("# QUERY empty W passes=0: MISSING ENTRY → FAIL\n", .{});
        }
    }

    // --- coverage: the pass children (passes=1, ko=none), informational ---
    {
        const rb = artifact2.lookup(&loaded, 0, 1, none, 1);
        const rw = artifact2.lookup(&loaded, 0, -1, none, 1);
        if (rb == null or rw == null) {
            failures += 1;
            std.debug.print("# QUERY empty passes=1: MISSING ENTRY → FAIL\n", .{});
        } else {
            const b = rb.?;
            const wrow = rw.?;
            const sane = b.L <= b.H and wrow.L <= wrow.H and
                @abs(b.L) <= 9 and @abs(b.H) <= 9 and @abs(wrow.L) <= 9 and @abs(wrow.H) <= 9;
            if (!sane) failures += 1;
            util.out("CONSUMER-LOAD 3x3 empty-B/W passes=1 (coverage) B L={d} H={d} W L={d} H={d} {s}\n", .{
                b.L, b.H, wrow.L, wrow.H, if (sane) "PASS" else "FAIL",
            });
        }
    }

    // --- one-stone children: the key colex-mismatch test (T178 CRITICAL) ---
    // Before fix: non-empty board lookups returned null (exp6 rank ≠ colex),
    // causing the GTP engine to fall back to area score. After fix: must
    // return correct fixpoint values.
    {
        // Black places at cell 4 (3×3 center). Board: exp6 rank = 1*3^4 = 81.
        // colex = layer_offset[1] + C(4,1)*2^1 + colour_bit = 1 + 4*2 + 1 = 10.
        // Result state: White to move, ko=none, passes=0.
        const pos3_center: exp6.Pos3 = [_]i8{0} ** exp6.N;
        var pos3_mut = pos3_center;
        pos3_mut[4] = 1; // Black stone at center
        const colex_center: u32 = @intCast(CR3.colex_from_pos(&pos3_mut));
        const exp6_rank: u32 = exp6.rank_board(pos3_mut);
        const fix_lin = (exp6.StateIdx{ .board = exp6_rank, .side = 1, .ko = exp6.KO_NONE, .passes = 0 }).linear();
        const fix_L = L_tab[fix_lin];
        const fix_H = H_tab[fix_lin];

        const row = artifact2.lookup(&loaded, colex_center, -1, none, 0);
        if (row) |r| {
            const v = tie_pin(r.L, r.H);
            const area_score: i8 = 1; // one Black stone, area score = 1
            const not_fallback = r.L != area_score or r.H != area_score;
            const matches_fixpoint = r.L == fix_L and r.H == fix_H;
            const ok = not_fallback and matches_fixpoint;
            if (!ok) failures += 1;
            std.debug.print("# one-stone center (colex={d}): L={d} H={d} V={d} fixpoint(L={d},H={d}) area={d} not-fallback={} matches={} → {s}\n", .{
                colex_center, r.L, r.H, v, fix_L, fix_H, area_score, not_fallback, matches_fixpoint, if (ok) "PASS" else "FAIL",
            });
            util.out("CONSUMER-LOAD 3x3 one-stone-center colex={d} L={d} H={d} fixpoint(L={d},H={d}) not-fallback={} {s}\n", .{
                colex_center, r.L, r.H, fix_L, fix_H, not_fallback, if (ok) "PASS" else "FAIL",
            });
        } else {
            failures += 1;
            std.debug.print("# QUERY one-stone center colex={d}: MISSING ENTRY → FAIL (colex mismatch not fixed?)\n", .{colex_center});
            util.out("CONSUMER-LOAD 3x3 one-stone-center colex={d} MISSING → FAIL\n", .{colex_center});
        }
    }

    // --- second one-stone child: corner cell 0 ---
    {
        var pos3_corner: exp6.Pos3 = [_]i8{0} ** exp6.N;
        pos3_corner[0] = 1;
        const colex_corner: u32 = @intCast(CR3.colex_from_pos(&pos3_corner));
        const exp6_rank: u32 = exp6.rank_board(pos3_corner);
        const fix_lin = (exp6.StateIdx{ .board = exp6_rank, .side = 1, .ko = exp6.KO_NONE, .passes = 0 }).linear();
        const fix_L = L_tab[fix_lin];
        const fix_H = H_tab[fix_lin];

        const row = artifact2.lookup(&loaded, colex_corner, -1, none, 0);
        if (row) |r| {
            const v = tie_pin(r.L, r.H);
            const area_score: i8 = 1;
            const not_fallback = r.L != area_score or r.H != area_score;
            const matches_fixpoint = r.L == fix_L and r.H == fix_H;
            const ok = not_fallback and matches_fixpoint;
            if (!ok) failures += 1;
            std.debug.print("# one-stone corner (colex={d}): L={d} H={d} V={d} fixpoint(L={d},H={d}) area={d} not-fallback={} matches={} → {s}\n", .{
                colex_corner, r.L, r.H, v, fix_L, fix_H, area_score, not_fallback, matches_fixpoint, if (ok) "PASS" else "FAIL",
            });
            util.out("CONSUMER-LOAD 3x3 one-stone-corner colex={d} L={d} H={d} fixpoint(L={d},H={d}) not-fallback={} {s}\n", .{
                colex_corner, r.L, r.H, fix_L, fix_H, not_fallback, if (ok) "PASS" else "FAIL",
            });
        } else {
            failures += 1;
            std.debug.print("# QUERY one-stone corner colex={d}: MISSING ENTRY → FAIL (colex mismatch not fixed?)\n", .{colex_corner});
            util.out("CONSUMER-LOAD 3x3 one-stone-corner colex={d} MISSING → FAIL\n", .{colex_corner});
        }
    }
    const elapsed = nowMs() - t0;
    const verdict = if (failures == 0) "PASS" else "FAIL";
    std.debug.print("# elapsed: {d} ms\n", .{elapsed});
    std.debug.print("# ============================================================================\n", .{});
    std.debug.print("# CONSUMER-LOAD VERDICT: {s} (failures={d})\n", .{ verdict, failures });
    std.debug.print("# ============================================================================\n", .{});
    util.out("VERDICT {s} failures={d} elapsed_ms={d}\n", .{ verdict, failures, elapsed });

    if (failures != 0) std.process.exit(1);
}
