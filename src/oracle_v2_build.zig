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
// oracle-v2 M2b — Build WZO2 artifact from exposed fixpoint (T165).
//
// Task: T165 (M2b) · Role: worker · Model: DSPro · Date: 2026-07-31
//
// Builds the WZO2 artifact per design-M1.md: reads the fixpoint tables
// from exp6_solve.zig's exposed interface, computes DTT (§3.1), builds
// the grouped inline segregated layout, and writes to
// untracked/oracle-v2/oracle-{goban}-v2.wzo2.
//
// Gate chain (2×2=0, 3×2=0, 3×3=+9) runs before any 4×4 build.
//
// Build:
//   tools/runner --rss-cap-mb 4096 --max-wall 14400 -- \
//     zig run -O ReleaseFast src/oracle_v2_build.zig

const std = @import("std");
const exp6 = @import("exp6_solve.zig");
const artifact2 = @import("artifact2.zig");
const colex = @import("colex.zig");

const GroupBuilder4 = struct {
    rank: u32, // exp6 base-3 rank (for linearIndex4 lookups)
    colex_val: u32, // combinatorial colex (for artifact group header)
    count: u8,
};

const gpa = std.heap.page_allocator;

pub fn main() !void {
    std.debug.print("# ============================================================================\n", .{});
    std.debug.print("# oracle-v2 M2b — Build WZO2 artifact from exposed fixpoint\n", .{});
    std.debug.print("# Task: T165 · Model: DSPro · Date: 2026-07-31\n", .{});
    std.debug.print("# ============================================================================\n", .{});

    // =====================================================================
    // GATE CHAIN: must pass before 4×4
    // =====================================================================
    std.debug.print("\n## GATE CHAIN (from exp6_solve)\n", .{});

    // --- 2×2 ---
    const fp2 = exp6.run_fixpoint_2x2();
    const s_root_b2 = exp6.Brute2x2.State{ .board = .{0} ** exp6.N2_N, .side = 1, .ko_point = exp6.Brute2x2.State.KO_NONE, .passes = 0 };
    const s_root_w2 = exp6.Brute2x2.State{ .board = .{0} ** exp6.N2_N, .side = -1, .ko_point = exp6.Brute2x2.State.KO_NONE, .passes = 0 };
    const v2_b = fp2.v(exp6.Brute2x2.global_index(s_root_b2));
    const v2_w = fp2.v(exp6.Brute2x2.global_index(s_root_w2));
    const gate2 = v2_b == 0 and v2_w == 0;
    std.debug.print("# 2×2: B={d} W={d} → {s}\n", .{ v2_b, v2_w, if (gate2) "PASS (0)" else "FAIL" });

    // --- 3×2 ---
    const reach32 = try gpa.alloc(u64, exp6.ReachWords32);
    defer gpa.free(reach32);
    const L_tab32 = try gpa.alloc(i8, exp6.TOTAL32);
    defer gpa.free(L_tab32);
    const H_tab32 = try gpa.alloc(i8, exp6.TOTAL32);
    defer gpa.free(H_tab32);
    _ = try exp6.run_census_3x2(gpa, reach32);
    _ = exp6.run_fixpoint_3x2(reach32, L_tab32, H_tab32);
    const root32_b = exp6.StateIdx32{ .board = 0, .side = 0, .ko = exp6.KO_NONE32, .passes = 0 };
    const root32_w = exp6.StateIdx32{ .board = 0, .side = 1, .ko = exp6.KO_NONE32, .passes = 0 };
    const v32_b = exp6.median32(L_tab32[root32_b.linear()], H_tab32[root32_b.linear()]);
    const v32_w = exp6.median32(L_tab32[root32_w.linear()], H_tab32[root32_w.linear()]);
    const gate32 = v32_b == 0 and v32_w == 0;
    std.debug.print("# 3×2: B={d} W={d} → {s}\n", .{ v32_b, v32_w, if (gate32) "PASS (0)" else "FAIL" });

    // --- 3×3 ---
    const reach3 = try gpa.alloc(u64, exp6.ReachWords);
    defer gpa.free(reach3);
    const L_tab3 = try gpa.alloc(i8, exp6.TOTAL);
    defer gpa.free(L_tab3);
    const H_tab3 = try gpa.alloc(i8, exp6.TOTAL);
    defer gpa.free(H_tab3);
    _ = try exp6.run_census_3x3(gpa, reach3);
    _ = exp6.run_fixpoint_3x3(reach3, L_tab3, H_tab3);
    const root3_b = exp6.StateIdx{ .board = 0, .side = 0, .ko = exp6.KO_NONE, .passes = 0 };
    const root3_w = exp6.StateIdx{ .board = 0, .side = 1, .ko = exp6.KO_NONE, .passes = 0 };
    const v3_b = exp6.median(L_tab3[root3_b.linear()], H_tab3[root3_b.linear()]);
    const v3_w = exp6.median(L_tab3[root3_w.linear()], H_tab3[root3_w.linear()]);
    const gate3 = v3_b == 9 and v3_w == -9;
    std.debug.print("# 3×3: B={d} W={d} → {s}\n", .{ v3_b, v3_w, if (gate3) "PASS (+9)" else "FAIL" });

    if (!gate2 or !gate32 or !gate3) {
        std.debug.print("\n# GATE CHAIN FAILED — stopping.\n", .{});
        return;
    }
    std.debug.print("\n# Gate chain: PASS — 2×2=0, 3×2=0, 3×3=+9.\n", .{});

    // =====================================================================
    // 4×4 CENSUS + FIXPOINT
    // =====================================================================
    std.debug.print("\n## 4×4 census\n", .{});

    const reach4 = try gpa.alloc(u64, exp6.ReachWords4);
    // freed explicitly before WZO2 write to reduce peak RSS (T192)

    const census4 = try exp6.run_census_4x4(gpa, reach4);
    std.debug.print("# 4x4 total reachable (all passes): {d}\n", .{census4.total_marked});
    std.debug.print("# 4x4 census sweeps: {d}\n", .{census4.sweeps});

    std.debug.print("\n## 4×4 fixpoint\n", .{});

    var fp4_out = try exp6.run_fixpoint_4x4(gpa, reach4);
    // freed explicitly before WZO2 write to reduce peak RSS (T192)

    const fp4 = fp4_out.result;
    const data = fp4_out.data;

    std.debug.print("# root (empty, B to move):  L={d:>3} H={d:>3}\n", .{ fp4.root_b_L, fp4.root_b_H });
    std.debug.print("# root (empty, W to move):  L={d:>3} H={d:>3}\n", .{ fp4.root_w_L, fp4.root_w_H });
    std.debug.print("# fixpoint sweeps: {d}, converged: {}\n", .{ fp4.sweeps, fp4.converged });
    std.debug.print("# compact states (passes ∈ {{0,1}}): {d}\n", .{fp4.compact_count});

    // =====================================================================
    // DTT COMPUTATION (§3.1 of design-M1.md)
    // =====================================================================
    std.debug.print("\n## DTT computation\n", .{});

    const compact_count = fp4.compact_count;
    const dtt = try gpa.alloc(u8, compact_count);
    // Note: dtt is freed explicitly after entry_rows are built, before
    // allocating file_bytes, to keep peak RSS within the 4 GB budget.
    @memset(dtt, artifact2.DTT_FAR);

    // DTT recurrence: for each state s, DTT(s) = 1 + min_{c in VP(s)} DTT(c)
    // where VP(s) = value-preserving children:
    //   Black: L(c) >= L(s)
    //   White: H(c) <= H(s)
    // Passes=2 children have DTT=0 (terminal).
    // Clamp computed DTT at 254; 255 = FAR reserved for cycle sentinel.

    var child_indices: [exp6.N4 + 1]u64 = undefined;

    // Initialize: for passes=1 states, check if pass child (terminal) is VP
    for (data.compact_list, 0..) |dense_idx, ci| {
        const passes: u8 = @intCast(dense_idx / (2 * exp6.KO_DIMS4 * exp6.RAW_TOTAL4));
        if (passes != 1) continue;

        const rest: u64 = dense_idx % (2 * exp6.KO_DIMS4 * exp6.RAW_TOTAL4);
        const side: u8 = @intCast(rest / (exp6.KO_DIMS4 * exp6.RAW_TOTAL4));
        const rest2: u64 = rest % (exp6.KO_DIMS4 * exp6.RAW_TOTAL4);
        const ko: u5 = @intCast(rest2 / exp6.RAW_TOTAL4);
        const board: u32 = @intCast(rest2 % exp6.RAW_TOTAL4);
        const enc = exp6.encodeState4(board, @intCast(side), ko, @intCast(passes));

        var child_count: usize = 0;
        exp6.genChildren4(enc, &child_indices, &child_count);

        // Check if pass child is value-preserving
        for (child_indices[0..child_count]) |child_enc| {
            const child_passes = exp6.decodePasses4(child_enc);
            if (child_passes != 2) continue;

            const child_board = exp6.decodeBoard4(child_enc);
            const b = exp6.unrank_board4(child_board);
            if (!exp6.genericIsLegal(exp6.N4, &b, exp6.W4, exp6.H4)) continue;
            const sc = exp6.genericAreaScore(exp6.N4, &b, exp6.W4, exp6.H4);

            // Value-preserving check
            const maximizing = side == 0;
            const parent_L = data.L_tab[ci];
            const parent_H = data.H_tab[ci];
            const vp = if (maximizing)
                sc >= parent_L // Black: L(c) >= L(s)
            else
                sc <= parent_H; // White: H(c) <= H(s)

            if (vp) {
                dtt[ci] = 1; // DTT = 1 + 0 (terminal)
                break;
            }
        }
    }

    // Iterative relaxation: repeat until no changes, max 254 sweeps
    std.debug.print("# DTT: iterative relaxation (max 254 sweeps)...\n", .{});
    var dtt_changed: u64 = 1;
    var dtt_sweep: u32 = 0;
    const MAX_DTT_SWEEPS: u32 = 254;
    while (dtt_changed > 0 and dtt_sweep < MAX_DTT_SWEEPS) {
        dtt_sweep += 1;
        dtt_changed = 0;

        for (data.compact_list, 0..) |dense_idx, ci| {
            const passes: u8 = @intCast(dense_idx / (2 * exp6.KO_DIMS4 * exp6.RAW_TOTAL4));
            if (passes == 2) continue;

            const rest: u64 = dense_idx % (2 * exp6.KO_DIMS4 * exp6.RAW_TOTAL4);
            const side: u8 = @intCast(rest / (exp6.KO_DIMS4 * exp6.RAW_TOTAL4));
            const rest2: u64 = rest % (exp6.KO_DIMS4 * exp6.RAW_TOTAL4);
            const ko: u5 = @intCast(rest2 / exp6.RAW_TOTAL4);
            const board: u32 = @intCast(rest2 % exp6.RAW_TOTAL4);
            const enc = exp6.encodeState4(board, @intCast(side), ko, @intCast(passes));

            const maximizing = side == 0;
            const parent_L = data.L_tab[ci];
            const parent_H = data.H_tab[ci];

            var child_count: usize = 0;
            exp6.genChildren4(enc, &child_indices, &child_count);

            var best_dtt: u8 = artifact2.DTT_FAR;
            var any_vp = false;

            for (child_indices[0..child_count]) |child_enc| {
                const child_passes = exp6.decodePasses4(child_enc);
                const child_board = exp6.decodeBoard4(child_enc);
                const child_side = exp6.decodeSide4(child_enc);
                const child_ko = exp6.decodeKo4(child_enc);

                if (child_passes == 2) {
                    // Terminal child
                    const b = exp6.unrank_board4(child_board);
                    if (!exp6.genericIsLegal(exp6.N4, &b, exp6.W4, exp6.H4)) continue;
                    const sc = exp6.genericAreaScore(exp6.N4, &b, exp6.W4, exp6.H4);

                    const vp = if (maximizing) sc >= parent_L else sc <= parent_H;
                    if (vp) {
                        if (1 < best_dtt) { best_dtt = 1; any_vp = true; }
                    }
                } else {
                    const child_lin = exp6.linearIndex4(child_board, child_side, child_ko, child_passes);
                    if (data.map.get(child_lin)) |child_ci| {
                        const child_L = data.L_tab[child_ci];
                        const child_H = data.H_tab[child_ci];

                        const vp = if (maximizing) child_L >= parent_L else child_H <= parent_H;
                        if (vp) {
                            const child_dtt = dtt[child_ci];
                            if (child_dtt < artifact2.DTT_FAR) {
                                const candidate: u8 = if (child_dtt < 254) child_dtt + 1 else 254;
                                if (candidate < best_dtt) { best_dtt = candidate; any_vp = true; }
                            }
                        }
                    }
                }
            }

            // Handle terminal=1 (no legal placements): the pass child is the
            // only child and is VP by construction (§3.1 step 4). If we already
            // found VP children, the best_dtt is correct; if not, DTT stays FAR.

            if (any_vp and best_dtt < dtt[ci]) {
                dtt[ci] = best_dtt;
                dtt_changed += 1;
            }
        }

        if (dtt_sweep % 16 == 0 or dtt_changed == 0) {
            std.debug.print("# DTT sweep {d}: changed={d}\n", .{ dtt_sweep, dtt_changed });
        }
    }
    std.debug.print("# DTT: {d} sweeps, final changes={d}\n", .{ dtt_sweep, dtt_changed });

    // DTT stats
    {
        var dtt_counts: [256]u64 = [_]u64{0} ** 256;
        for (dtt) |v| dtt_counts[v] += 1;
        std.debug.print("# DTT distribution: FAR(255)={d}", .{dtt_counts[255]});
        var distinct: u32 = 0;
        for (dtt_counts, 0..) |cnt, i| {
            if (i != 255 and cnt > 0) distinct += 1;
        }
        std.debug.print(" non-FAR-distinct={d}\n", .{distinct});
        // Print first few values
        for (dtt_counts, 0..) |cnt, i| {
            if (i == 255) continue;
            if (cnt > 0 and i < 20) {
                std.debug.print("#   DTT={d}: {d}\n", .{ i, cnt });
            }
        }
    }

    // DTT computation complete.

    // =====================================================================
    // BUILD WZO2 ARTIFACT
    // =====================================================================
    std.debug.print("\n## Building WZO2 artifact\n", .{});

    const w: u8 = 4;
    const h: u8 = 4;
    const kb = artifact2.koBits(w * h);
    const max_per_group = artifact2.maxEntriesPerGroup(w, h);

    // Phase 1: count entries per board
    // Use a dense array: RAW_TOTAL4 is 43M, u8 per slot = 43 MB
    const raw_total: usize = @intCast(exp6.RAW_TOTAL4);
    const board_counts = try gpa.alloc(u8, raw_total);
    @memset(board_counts, 0);

    for (data.compact_list) |dense_idx| {
        const rest2: u64 = dense_idx % (exp6.KO_DIMS4 * exp6.RAW_TOTAL4);
        const board: u32 = @intCast(rest2 % exp6.RAW_TOTAL4);
        board_counts[board] += 1;
    }

    // Phase 2: collect boards with entries, convert exp6 rank → colex, sort by colex
    const CR4 = colex.Indexer(4, 4);
    var group_builders = try std.ArrayListUnmanaged(GroupBuilder4).initCapacity(gpa, 0);
    defer group_builders.deinit(gpa);

    var n_entries_total: u64 = 0;
    for (board_counts, 0..) |count, board| {
        if (count == 0) continue;
        if (count > max_per_group) {
            std.debug.print("# PANIC: board {d} has {d} entries, max is {d}\n", .{ board, count, max_per_group });
            return error.EntryCountExceedsMax;
        }
        const pos4 = exp6.unrank_board4(@intCast(board));
        const colex_idx: u32 = @intCast(CR4.colex_from_pos(&pos4));
        group_builders.append(gpa, .{
            .rank = @intCast(board),
            .colex_val = colex_idx,
            .count = count,
        }) catch unreachable;
        n_entries_total += count;
    }

    // Sort by combinatorial colex (artifact format contract §2.1)
    std.mem.sort(GroupBuilder4, group_builders.items, {}, struct {
        fn lt(_: void, a: GroupBuilder4, b: GroupBuilder4) bool {
            return a.colex_val < b.colex_val;
        }
    }.lt);

    const n_groups: u64 = group_builders.items.len;

    // board_counts no longer needed
    gpa.free(board_counts);

    std.debug.print("# groups: {d}\n", .{n_groups});
    std.debug.print("# entries: {d}\n", .{n_entries_total});
    std.debug.print("# file size: {d} bytes ({d:.1} MB)\n", .{
        artifact2.HEADER_LEN + n_groups * 5 + n_entries_total * 4,
        @as(f64, @floatFromInt(artifact2.HEADER_LEN + n_groups * 5 + n_entries_total * 4)) / 1_000_000.0,
    });

    // Phase 3: build entry rows in WZO2 order (sorted by colex)
    var entry_rows = try std.ArrayListUnmanaged(artifact2.EntryRow).initCapacity(gpa, @intCast(n_entries_total));
    // freed explicitly after buildFile to reduce peak RSS

    for (group_builders.items) |gb| {
        const board: u32 = gb.rank; // exp6 rank for linearIndex4 lookups

        // passes=0: all ko values, both sides
        for (0..exp6.KO_DIMS4) |ko_u| {
            const ko: u5 = @intCast(ko_u);
            for ([_]u1{ 0, 1 }) |side| {
                const lin = exp6.linearIndex4(board, side, ko, 0);
                if (data.map.get(lin)) |ci| {
                    const Lv = data.L_tab[ci];
                    const Hv = data.H_tab[ci];
                    const kb_val = artifact2.encodeKeyByte(side, @intCast(ko_u), 0, 0, kb);
                    entry_rows.append(gpa, .{
                        .key_byte = kb_val,
                        .L = Lv,
                        .H = Hv,
                        .DTT = dtt[ci],
                    }) catch unreachable;
                }
            }
        }

        // passes=1: only ko=KO_NONE (invariant §2.5), both sides
        for ([_]u1{ 0, 1 }) |side| {
            const lin = exp6.linearIndex4(board, side, exp6.KO_NONE4, 1);
            if (data.map.get(lin)) |ci| {
                const Lv = data.L_tab[ci];
                const Hv = data.H_tab[ci];
                const kb_val = artifact2.encodeKeyByte(side, exp6.KO_NONE4, 1, 0, kb);
                entry_rows.append(gpa, .{
                    .key_byte = kb_val,
                    .L = Lv,
                    .H = Hv,
                    .DTT = dtt[ci],
                }) catch unreachable;
            }
        }
    }

    // Phase 3b: set terminal flags in key_bytes
    // A state has terminal=1 if the side has no legal placements (child_count=1: only pass).
    // genChildren4 always generates pass first; child_count>1 means at least one
    // basic-ko-legal placement exists.
    {
        // DTT no longer needed; free it before file_bytes allocation to reduce peak RSS
        gpa.free(dtt);

        var entry_idx: usize = 0;
        var terminal_set: u64 = 0;
        for (group_builders.items) |gb| {
            const board: u32 = gb.rank; // exp6 rank for lookups

            // passes=0: all ko values, both sides
            for (0..exp6.KO_DIMS4) |ko_u| {
                const ko: u5 = @intCast(ko_u);
                for ([_]u1{ 0, 1 }) |side| {
                    const lin = exp6.linearIndex4(board, side, ko, 0);
                    if (data.map.get(lin)) |_| {
                        // Check if side has legal placements
                        const enc = exp6.encodeState4(board, side, ko, 0);
                        var child_count: usize = 0;
                        exp6.genChildren4(enc, &child_indices, &child_count);
                        // First child is always pass
                        const has_placement = child_count > 1;
                        if (!has_placement) {
                            entry_rows.items[entry_idx].key_byte |= 1; // set terminal bit
                            terminal_set += 1;
                        }
                        entry_idx += 1;
                    }
                }
            }

            // passes=1: only ko=KO_NONE, both sides
            for ([_]u1{ 0, 1 }) |side| {
                const lin = exp6.linearIndex4(board, side, exp6.KO_NONE4, 1);
                if (data.map.get(lin)) |_| {
                    const enc = exp6.encodeState4(board, side, exp6.KO_NONE4, 1);
                    var child_count: usize = 0;
                    exp6.genChildren4(enc, &child_indices, &child_count);
                    const has_placement = child_count > 1;
                    if (!has_placement) {
                        entry_rows.items[entry_idx].key_byte |= 1;
                        terminal_set += 1;
                    }
                    entry_idx += 1;
                }
            }
        }
        std.debug.print("# terminal flags set: {d}\n", .{terminal_set});
    }

    // Free large no-longer-needed structures before allocating file_bytes (T192 OOM fix)
    // reach4: ~550 MB census bitset; fp4_out.data: ~2 GB hash map + L/H tables
    gpa.free(reach4);
    fp4_out.data.deinit();
    // dtt already freed above in terminal-flag block

    // =====================================================================
    // WRITE WZO2 FILE
    // =====================================================================
    std.debug.print("\n## Writing WZO2 artifact\n", .{});

    // Build final GroupHeader list (with colex values, not exp6 ranks)
    var group_headers = try std.ArrayListUnmanaged(artifact2.GroupHeader).initCapacity(gpa, @intCast(n_groups));
    // freed explicitly after buildFile to reduce peak RSS
    for (group_builders.items) |gb| {
        group_headers.append(gpa, .{
            .colex = gb.colex_val,
            .entry_count = gb.count,
        }) catch unreachable;
    }

    const art = artifact2.Artifact{
        .header = artifact2.Header{
            .w = w,
            .h = h,
            .ko_bits = kb,
            .n_groups = n_groups,
            .n_entries = n_entries_total,
            .sha256 = [_]u8{0} ** artifact2.HASH_LEN,
        },
        .group_headers = group_headers.items,
        .entry_rows = entry_rows.items,
    };

    const file_bytes = try artifact2.buildFile(gpa, &art);
    defer gpa.free(file_bytes);

    // Free entry_rows and group_headers now that file_bytes is built (T192 OOM fix: ~464 MB savings at peak)
    entry_rows.deinit(gpa);
    group_headers.deinit(gpa);

    // Verify hash self-check
    std.debug.print("# SHA-256 self-check...\n", .{});
    artifact2.verifyHash(file_bytes) catch {
        std.debug.print("# SHA-256 MISMATCH — bug in buildFile!\n", .{});
        return error.ChecksumMismatch;
    };
    std.debug.print("# SHA-256 verified\n", .{});

    // Write to untracked/oracle-v2/
    const out_dir = "untracked/oracle-v2";
    const out_path = "untracked/oracle-v2/oracle-4x4-v2.wzo2";
    std.debug.print("# Writing {s}...\n", .{out_path});

    var threaded = std.Io.Threaded.init(gpa, .{});
    defer threaded.deinit();
    const io = threaded.io();
    const dir = std.Io.Dir.cwd();
    try dir.createDirPath(io, out_dir);
    var file = try dir.createFile(io, out_path, .{});
    defer file.close(io);

    // Write in 64 MiB chunks (T192 OOM fix)
    const CHUNK: usize = 1 << 26;
    var off: u64 = 0;
    while (off < file_bytes.len) {
        const end = @min(off + CHUNK, file_bytes.len);
        try file.writePositionalAll(io, file_bytes[@intCast(off)..@intCast(end)], off);
        off = end;
    }

    std.debug.print("# WZO2 artifact written: {s} ({d} bytes, {d:.1} MB)\n", .{
        out_path,
        file_bytes.len,
        @as(f64, @floatFromInt(file_bytes.len)) / 1_000_000.0,
    });

    // =====================================================================
    // SUMMARY
    // =====================================================================
    std.debug.print("\n# ============================================================================\n", .{});
    std.debug.print("# oracle-v2 M2b SUMMARY\n", .{});
    std.debug.print("# ============================================================================\n", .{});
    std.debug.print("# gate chain: 2×2={d} 3×2={d} 3×3={d} → {s}\n", .{ v2_b, v32_b, v3_b, if (gate2 and gate32 and gate3) "PASS" else "FAIL" });
    std.debug.print("# 4×4 root (empty, B): L={d} H={d}\n", .{ fp4.root_b_L, fp4.root_b_H });
    std.debug.print("# 4×4 root (empty, W): L={d} H={d}\n", .{ fp4.root_w_L, fp4.root_w_H });
    std.debug.print("# fixpoint sweeps: {d}, converged: {}\n", .{ fp4.sweeps, fp4.converged });
    std.debug.print("# compact states: {d}\n", .{fp4.compact_count});
    std.debug.print("# DTT sweeps: {d}\n", .{dtt_sweep});
    std.debug.print("# groups: {d}, entries: {d}\n", .{ n_groups, n_entries_total });
    std.debug.print("# file: {s} ({d} bytes)\n", .{ out_path, file_bytes.len });
    std.debug.print("#\n", .{});
    std.debug.print("# DONE — artifact ready for M3/M4b.\n", .{});
}
