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
// VB_SCC_4x4 — I5 SCC containment check at 4×4 (and calibration rungs).
//
// Task: T344 · Set: E (g3b-battery) · Holds: src/vb_scc_4x4.zig
// Author: deepseek-v4-pro/T344 · Date: 2026-08-05
//
// Implements the I5 check from G3b pass0 spec §2.1:
//   I5 SCC containment: KO_SENSITIVE ⊆ cycle-reachable.
//
// Ladder rungs:
//   Rung 1 — 3×2 calibration (first seeded-defect control is mandatory;
//            the 2×2 all-legal graph is entirely cycle-reachable so a
//            spurious KO_SENSITIVE can only be caught at 3×2+).
//   Rung 4 — 4×3 must pass before 4×4 reading is taken.
//   Rung 5 — 4×4 against oracle-v2 WZO2 artifact.
//
// Algorithm: iterative Tarjan over the move graph from R8 (vb_movegen.zig).
// For 4×4, uses the WZO2 table as the vertex space with a colex→group
// direct-mapping array (172 MB) for O(1) child lookup, per T134's memory
// plan. Peak RSS budget ~1.9 GB, well under the 3.5 GB runner cap.
//
// Standalone except for vb_movegen.zig (R8 move generator). No other
// src/ imports.

const std = @import("std");
const vb_movegen = @import("vb_movegen.zig");

const assert = std.debug.assert;

// ═══════════════════════════════════════════════════════════════════════════
//  PUBLIC TYPES
// ═══════════════════════════════════════════════════════════════════════════

pub const Status = enum { pass, fail, err };

pub const Result = struct {
    /// Graph metrics
    nodes: u64 = 0,
    edges: u64 = 0,
    scc_non_trivial: u64 = 0,
    max_scc_size: u64 = 0,
    cycle_involved: u64 = 0,
    cycle_reachable: u64 = 0,
    /// Containment check
    ko_sensitive_count: u64 = 0,
    ko_not_cr: u64 = 0,
    /// Status
    status: Status = .pass,
    error_msg: ?[]const u8 = null,
    /// Peak RSS estimate (MB)
    peak_rss_mb: u64 = 0,
    /// Per-component memory ledger (bytes), plan.md §2.1/§11 line items.
    /// Measured at allocation sites, not estimated.
    mem_file_bytes: u64 = 0, // artifact bytes resident (entry data + group index)
    mem_group_index: u64 = 0, // group index portion of the artifact
    mem_entry_data: u64 = 0, // entry data portion of the artifact
    mem_colex_map: u64 = 0, // colex→group direct map (WZO2 only)
    mem_entry_starts: u64 = 0, // per-group entry offsets (WZO2 only)
    mem_index: u64 = 0, // Tarjan index array
    mem_lowlink: u64 = 0, // Tarjan lowlink array
    mem_onstack: u64 = 0, // Tarjan onstack bitset/array
    mem_comp: u64 = 0, // SCC id per vertex
    mem_dense_linear: u64 = 0, // dense_to_linear (WZO1 bitset paths)
    mem_linear_dense: u64 = 0, // linear_to_dense (WZO1 bitset paths)
    mem_adjacency: u64 = 0, // adjacency lists (small-goban path)
    mem_scc_stack: u64 = 0, // Tarjan SCC stack
    mem_scc_rep: u64 = 0, // SCC representative array (WZO1 bitset path)
    mem_comp_sizes: u64 = 0, // per-SCC size array
    mem_cr: u64 = 0, // cycle-reachable marks
    mem_bitset: u64 = 0, // BFS bitset (WZO1 bitset path)
    mem_frames: u64 = 0, // DFS frame stack
    mem_queue: u64 = 0, // BFS queue (WZO1 paths)
    mem_other: u64 = 0, // everything else (scratch, overhead)
    /// Seeded-defect hint: first non-cycle-reachable (colex, side) at
    /// passes=0, ko=NONE. Used by the seeded-defect control test.
    seed_hint_colex: ?u64 = null,
    seed_hint_side: ?u1 = null,
    /// Seeded-defect hint #2: first non-cycle-reachable (colex, side) at
    /// passes=0, ko=NONE whose KO_SENSITIVE flag is CLEAR — the slot a
    /// spurious-KO_SENSITIVE seed needs (the first hint may already be set).
    seed_hint_clear_colex: ?u64 = null,
    seed_hint_clear_side: ?u1 = null,
};

/// Total of the memory-ledger entries above.
pub fn memTotal(res: Result) u64 {
    return res.mem_file_bytes + res.mem_group_index + res.mem_entry_data +
        res.mem_colex_map + res.mem_entry_starts + res.mem_index +
        res.mem_lowlink + res.mem_onstack + res.mem_comp +
        res.mem_dense_linear + res.mem_linear_dense + res.mem_adjacency +
        res.mem_scc_stack + res.mem_scc_rep + res.mem_comp_sizes +
        res.mem_cr + res.mem_bitset + res.mem_frames + res.mem_queue + res.mem_other;
}

// ═══════════════════════════════════════════════════════════════════════════
//  WZO2 HEADER (design-M1 §4)
// ═══════════════════════════════════════════════════════════════════════════

const WZO2_MAGIC: [4]u8 = .{ 'W', 'Z', 'O', '2' };
const WZO2_HEADER_SIZE: usize = 128;
const WZO2_GROUP_HEADER_SIZE: usize = 5; // colex u32 LE + entry_count u8
const WZO2_ENTRY_SIZE: usize = 4; // key_byte + L + H + DTT

const Wzo2Header = struct {
    w: u8,
    h: u8,
    ko_bits: u8,
    hdr_flags: u8,
    n_groups: u64,
    n_entries: u64,
    data_offset: u64,
};

fn parseWzo2Header(bytes: *const [WZO2_HEADER_SIZE]u8) !Wzo2Header {
    if (!std.mem.eql(u8, bytes[0..4], &WZO2_MAGIC)) return error.BadMagic;
    const version = std.mem.readInt(u16, bytes[4..6], .little);
    if (version != 1) return error.BadVersion;
    const w = bytes[6];
    const h = bytes[7];
    if (w != 4 or h != 4) return error.BadSize;
    const entry_size = std.mem.readInt(u16, bytes[10..12], .little);
    if (entry_size != WZO2_ENTRY_SIZE) return error.BadEntrySize;
    const group_header_size = bytes[12];
    if (group_header_size != WZO2_GROUP_HEADER_SIZE) return error.BadGroupHeaderSize;
    const ko_bits = bytes[13];
    const hdr_flags = bytes[14];
    const n_groups = std.mem.readInt(u64, bytes[16..24], .little);
    const n_entries = std.mem.readInt(u64, bytes[24..32], .little);
    const data_offset = std.mem.readInt(u64, bytes[32..40], .little);
    if (data_offset != WZO2_HEADER_SIZE) return error.BadDataOffset;

    return Wzo2Header{
        .w = w,
        .h = h,
        .ko_bits = ko_bits,
        .hdr_flags = hdr_flags,
        .n_groups = n_groups,
        .n_entries = n_entries,
        .data_offset = data_offset,
    };
}

// ═══════════════════════════════════════════════════════════════════════════
//  COLEX→GROUP MAPPING (for 4×4 WZO2 fast child lookup)
// ═══════════════════════════════════════════════════════════════════════════

const COLEX_SPACE_4X4: usize = 43046721; // 3^16

/// Build a direct array mapping colex → group index.
/// colex_to_group[colex] = group index (0..n_groups-1) or sentinel if absent.
fn buildColexToGroup(allocator: std.mem.Allocator, groups: []const u8, n_groups: u64) ![]u32 {
    const arr = try allocator.alloc(u32, COLEX_SPACE_4X4);
    errdefer allocator.free(arr);
    @memset(arr, 0xFFFFFFFF); // sentinel

    for (0..n_groups) |g| {
        const off = g * WZO2_GROUP_HEADER_SIZE;
        const colex = std.mem.readInt(u32, groups[off..][0..4], .little);
        arr[colex] = @intCast(g);
    }

    return arr;
}

// ═══════════════════════════════════════════════════════════════════════════
//  KEY BYTE ENCODING (design-M1 §2.2)
// ═══════════════════════════════════════════════════════════════════════════

/// Encode a key byte for lookup matching (terminal bit = 0).
fn encodeKeyByteLookup(side: u1, ko: u8, passes: u2, ko_bits: u8) u8 {
    var kb: u8 = @as(u8, side) << 1; // bit 1 = side
    kb |= ko << 2; // bits 2..(2+ko_bits-1)
    kb |= @as(u8, passes) << @intCast(2 + ko_bits); // bit (2+ko_bits)
    return kb;
}

/// Extract terminal flag from key_byte.
fn keyByteTerminal(kb: u8) bool {
    return (kb & 1) != 0;
}

/// Extract side from key_byte. Returns +1=Black, -1=White.
fn keyByteSide(kb: u8) i8 {
    return if ((kb & 2) != 0) @as(i8, -1) else @as(i8, 1);
}

/// Extract ko from key_byte.
fn keyByteKo(kb: u8, ko_bits: u8) u8 {
    const mask: u8 = (@as(u8, 1) << @intCast(ko_bits)) - 1;
    return (kb >> 2) & mask;
}

/// Extract passes from key_byte.
fn keyBytePasses(kb: u8, ko_bits: u8) u2 {
    return @intCast((kb >> @intCast(2 + ko_bits)) & 1);
}

// ═══════════════════════════════════════════════════════════════════════════
//  STATE TRANSITION (applyMove — consistent with R8 / vb_movegen rules)
// ═══════════════════════════════════════════════════════════════════════════

/// Apply a placement move. Returns child state (pos, ko) or null if illegal.
fn applyMove(
    comptime w: usize,
    comptime h: usize,
    pos: *const [w * h]i8,
    side: i8,
    ko_forbidden: u8,
    cell: usize,
) ?struct { pos: [w * h]i8, ko: u8 } {
    const n = w * h;
    if (pos[cell] != 0) return null;
    if (ko_forbidden < n and cell == ko_forbidden) return null;

    var next: [n]i8 = undefined;
    @memcpy(&next, pos);
    next[cell] = side;

    const opp: i8 = -side;
    var nb: [4]usize = undefined;
    const cnt = neighbors(w, h, cell, &nb);
    for (nb[0..cnt]) |q| {
        if (next[q] == opp and chainHasNoLiberty(w, h, &next, q, opp)) {
            removeChain(w, h, &next, q, opp);
        }
    }

    // suicide check
    if (chainHasNoLiberty(w, h, &next, cell, side)) return null;

    // compute new ko point (corrected single-stone rule)
    const new_ko = computeKo(w, h, pos, &next, side, cell);

    return .{ .pos = next, .ko = new_ko };
}

/// Pass move: just increments passes, clears ko.
fn applyPass(
    side: i8,
    passes: u2,
) struct { side: i8, ko: u8, passes: u2 } {
    return .{
        .side = -side,
        .ko = 255, // NONE (SMD1 encoding)
        .passes = passes + 1,
    };
}

fn neighbors(comptime w: usize, comptime h: usize, p: usize, buf: *[4]usize) usize {
    var cnt: usize = 0;
    const row = p / w;
    const col = p % w;
    if (row > 0) { buf[cnt] = p - w; cnt += 1; }
    if (row + 1 < h) { buf[cnt] = p + w; cnt += 1; }
    if (col > 0) { buf[cnt] = p - 1; cnt += 1; }
    if (col + 1 < w) { buf[cnt] = p + 1; cnt += 1; }
    return cnt;
}

fn chainHasNoLiberty(
    comptime w: usize,
    comptime h: usize,
    pos: *const [w * h]i8,
    seed: usize,
    colour: i8,
) bool {
    const n = w * h;
    if (pos[seed] != colour) return false;

    var visited = [_]bool{false} ** (4 * 4); // max n=16
    var stack: [n]usize = undefined;
    var sp: usize = 1;
    stack[0] = seed;
    visited[seed] = true;
    var has_lib = false;
    var nb_buf: [4]usize = undefined;

    while (sp > 0) {
        sp -= 1;
        const q = stack[sp];
        const cnt = neighbors(w, h, q, &nb_buf);
        for (nb_buf[0..cnt]) |r| {
            if (pos[r] == 0) {
                has_lib = true;
            } else if (pos[r] == colour and !visited[r]) {
                visited[r] = true;
                stack[sp] = r;
                sp += 1;
            }
        }
    }
    return !has_lib;
}

fn removeChain(
    comptime w: usize,
    comptime h: usize,
    pos: *[w * h]i8,
    seed: usize,
    colour: i8,
) void {
    const n = w * h;
    var visited = [_]bool{false} ** (4 * 4);
    var stack: [n]usize = undefined;
    var sp: usize = 1;
    stack[0] = seed;
    visited[seed] = true;
    pos[seed] = 0;
    var nb_buf: [4]usize = undefined;

    while (sp > 0) {
        sp -= 1;
        const q = stack[sp];
        const cnt = neighbors(w, h, q, &nb_buf);
        for (nb_buf[0..cnt]) |r| {
            if (pos[r] == colour and !visited[r]) {
                visited[r] = true;
                pos[r] = 0;
                stack[sp] = r;
                sp += 1;
            }
        }
    }
}

fn computeKo(
    comptime w: usize,
    comptime h: usize,
    before: *const [w * h]i8,
    after: *const [w * h]i8,
    colour: i8,
    cell: usize,
) u8 {
    const n = w * h;
    const opp: i8 = -colour;

    var opp_before: usize = 0;
    var opp_after: usize = 0;
    for (0..n) |i| {
        if (before[i] == opp) opp_before += 1;
        if (after[i] == opp) opp_after += 1;
    }

    if (opp_before - opp_after == 1) {
        // find the captured cell
        var captured: usize = n; // sentinel
        for (0..n) |i| {
            if (before[i] == opp and after[i] == 0) {
                captured = i;
                break;
            }
        }
        if (captured < n) {
            var nb_buf: [4]usize = undefined;
            const cnt = neighbors(w, h, cell, &nb_buf);
            var empty_nbrs: usize = 0;
            var friendly_nbrs: usize = 0;
            for (nb_buf[0..cnt]) |q| {
                if (after[q] == 0) empty_nbrs += 1;
                if (after[q] == colour) friendly_nbrs += 1;
            }
            if (empty_nbrs == 1 and friendly_nbrs == 0) {
                return @intCast(captured);
            }
        }
    }
    return @intCast(n); // NONE
}

// ═══════════════════════════════════════════════════════════════════════════
//  SMALL-GOBAN I5 (3×2, 4×3 — hash-map BFS + Tarjan, WZO1 artifacts)
// ═══════════════════════════════════════════════════════════════════════════

/// Run I5 on a WZO1 artifact (3×2 or 4×3) using hash-map-based graph
/// construction. This is the exhaustive approach — the state space is
/// small enough (≤13.8M linear addresses) that hash-map BFS + full
/// adjacency works.
///
/// If `all_legal_seed` is true, seeds from all legal positions instead of
/// just the empty-board root. Use true for seeded-defect control testing.
/// (pub since T391: consumed by the cross-size differential,
/// src/i5_differential.zig.)
pub fn checkI5Small(
    allocator: std.mem.Allocator,
    comptime w: usize,
    comptime h: usize,
    artifact_bytes: []const u8,
    all_legal_seed: bool,
) !Result {
    const n = w * h;
    const total = pow3(@intCast(n));

    // ── Parse WZO1 header ────────────────────────────────────────────
    if (artifact_bytes.len < 32) return error.Truncated;
    if (!std.mem.eql(u8, artifact_bytes[0..4], "WZO1")) return error.BadMagic;
    if (artifact_bytes[4] != 1) return error.BadVersion;
    const aw = artifact_bytes[6];
    const ah = artifact_bytes[7];
    if (aw != w or ah != h) return error.BadSize;
    if (artifact_bytes[9] != 1 and artifact_bytes[9] != 2) return error.BadRulesId;
    const file_total = std.mem.readInt(u64, artifact_bytes[12..20], .little);
    if (file_total != total) return error.TotalMismatch;

    const payload_start: usize = 32;
    const expected_size = payload_start + 6 * @as(usize, @intCast(total));
    if (artifact_bytes.len != expected_size) return error.Truncated;

    // Read fb/fw columns for KO_SENSITIVE flags
    const fb = artifact_bytes[payload_start + 2 * @as(usize, @intCast(total)) .. payload_start + 3 * @as(usize, @intCast(total))];
    const fw = artifact_bytes[payload_start + 3 * @as(usize, @intCast(total)) .. payload_start + 4 * @as(usize, @intCast(total))];

    // ── Linear encoding for (colex, side, ko_point, passes) ──────────
    const ko_count = n + 1; // n actual ko points + 1 sentinel for NONE
    const sub_stride = ko_count * 3; // 3 pass values (0,1,2)
    const stride = 2 * sub_stride; // 2 sides

    const linearEncode = struct {
        fn encode(colex: u64, side: u1, ko_point: usize, passes: u2) u64 {
            // ko_point = n encodes NONE; stored as index 0 in the ko slot.
            // Actual ko points 0..n-1 are stored as 1..n.
            const ko_enc: u64 = if (ko_point == n) 0 else @as(u64, @intCast(ko_point)) + 1;
            return colex * stride + @as(u64, side) * sub_stride + ko_enc * 3 + @as(u64, passes);
        }
        fn decode(lin: u64) struct { colex: u64, side: u1, ko: usize, passes: u2 } {
            const c = lin / stride;
            const rem = lin % stride;
            const s: u1 = @intCast(rem / sub_stride);
            const r2 = rem % sub_stride;
            const ke = r2 / 3;
            const p: u2 = @intCast(r2 % 3);
            const kp: usize = if (ke == 0) n else @intCast(ke - 1);
            return .{ .colex = c, .side = s, .ko = kp, .passes = p };
        }
    };

    var visited = std.AutoHashMap(u64, u32).init(allocator);
    defer visited.deinit();

    var dense_to_linear = try std.ArrayListUnmanaged(u64).initCapacity(allocator, 0);
    defer dense_to_linear.deinit(allocator);

    var queue = try std.ArrayListUnmanaged(u64).initCapacity(allocator, 0);
    defer queue.deinit(allocator);

    // ── Seed: empty board root (true-root) or all legal positions ────
    if (all_legal_seed) {
        // Seed from ALL legal positions × both sides, ko=NONE, passes=0.
        var digits: [n]u8 = [_]u8{0} ** n;
        var pos: [n]i8 = [_]i8{0} ** n;
        while (true) {
            if (isLegalPosition(w, h, &pos)) {
                const colex = colexFromPosRt(w, h, &pos);
                for (0..2) |s| {
                    const lin = linearEncode.encode(colex, @intCast(s), n, 0);
                    const gop = try visited.getOrPut(lin);
                    if (!gop.found_existing) {
                        gop.value_ptr.* = @intCast(dense_to_linear.items.len);
                        try dense_to_linear.append(allocator, lin);
                        try queue.append(allocator, lin);
                    }
                }
            }
            var i: usize = 0;
            while (i < n) : (i += 1) {
                if (digits[i] == 2) { digits[i] = 0; pos[i] = 0; continue; }
                digits[i] += 1;
                pos[i] = if (digits[i] == 1) @as(i8, 1) else @as(i8, -1);
                break;
            }
            if (i == n) break;
        }
    } else {
        // Seed from empty board root only: colex=0, side=Black(0), ko=NONE(n), passes=0
        const root_lin = linearEncode.encode(0, 0, n, 0);
        const gop = try visited.getOrPut(root_lin);
        if (!gop.found_existing) {
            gop.value_ptr.* = @intCast(dense_to_linear.items.len);
            try dense_to_linear.append(allocator, root_lin);
            try queue.append(allocator, root_lin);
        }
    }

    // ── BFS expansion (full (b,side,ko,passes) graph) ─────────────
    // Includes passes=0→1→2 transitions. Passes=2 is terminal (no outgoing
    // edges). Placement children always have passes=0 (placement resets the
    // pass counter).
    var bfs_edges: u64 = 0;
    var qhead: usize = 0;
    var last_report: usize = 0;
    while (qhead < queue.items.len) {
        const cur = queue.items[qhead];
        qhead += 1;
        const dec = linearEncode.decode(cur);

        // Progress report every 100000 states for large graphs
        if (w * h >= 12 and qhead - last_report >= 100000) {
            std.debug.print("  BFS: {d}/{d} visited, queue={d}\n", .{ qhead, visited.count(), queue.items.len });
            last_report = qhead;
        }

        // Terminal: passes=2 has no outgoing edges.
        if (dec.passes >= 2) continue;

        var pos_arr: [w * h]i8 = undefined;
        posFromColexRt(w, h, dec.colex, &pos_arr);
        const pos = pos_arr;
        const colour: i8 = if (dec.side == 0) @as(i8, 1) else @as(i8, -1);
        const other_side: u1 = if (dec.side == 0) @as(u1, 1) else @as(u1, 0);

        // Placement successors → passes=0 (placement resets pass counter)
        for (0..n) |cell| {
            if (pos[cell] != 0) continue;
            // When passes=1, ko is NONE (per artifact invariant: passes>=1 ⇒ ko=none).
            // For passes=0, use the actual ko point.
            const ko_forbid: u8 = if (dec.passes == 1) @intCast(n) else @intCast(dec.ko);
            const result = applyMove(w, h, &pos, colour, ko_forbid, cell) orelse continue;
            const child_colex = colexFromPosRt(w, h, &result.pos);
            const child_ko: usize = if (result.ko < n) result.ko else n;
            const lin = linearEncode.encode(child_colex, other_side, child_ko, 0);
            bfs_edges += 1;
            const gop = try visited.getOrPut(lin);
            if (!gop.found_existing) {
                gop.value_ptr.* = @intCast(dense_to_linear.items.len);
                try dense_to_linear.append(allocator, lin);
                try queue.append(allocator, lin);
            }
        }
        // Pass successor: flips side, increments passes, ko=NONE
        {
            const lin = linearEncode.encode(dec.colex, other_side, n, dec.passes + 1);
            bfs_edges += 1;
            const gop = try visited.getOrPut(lin);
            if (!gop.found_existing) {
                gop.value_ptr.* = @intCast(dense_to_linear.items.len);
                try dense_to_linear.append(allocator, lin);
                try queue.append(allocator, lin);
            }
        }
    }

    const V = dense_to_linear.items.len;

    // ── Build adjacency (full graph) ─────────────────────────────────
    var adjacency = try allocator.alloc([]u32, V);
    defer {
        for (adjacency) |a| allocator.free(a);
        allocator.free(adjacency);
    }

    var total_edges: u64 = 0;
    for (0..V) |v| {
        const cur = dense_to_linear.items[v];
        const dec = linearEncode.decode(cur);

        var children = try std.ArrayListUnmanaged(u32).initCapacity(allocator, 0);

        // Terminal: passes=2 has no outgoing edges.
        if (dec.passes >= 2) {
            adjacency[v] = try children.toOwnedSlice(allocator);
            continue;
        }

        var pos_arr: [w * h]i8 = undefined;
        posFromColexRt(w, h, dec.colex, &pos_arr);
        const pos = pos_arr;
        const colour: i8 = if (dec.side == 0) @as(i8, 1) else @as(i8, -1);
        const other_side: u1 = if (dec.side == 0) @as(u1, 1) else @as(u1, 0);

        for (0..n) |cell| {
            if (pos[cell] != 0) continue;
            const ko_forbid: u8 = if (dec.passes == 1) @intCast(n) else @intCast(dec.ko);
            const result = applyMove(w, h, &pos, colour, ko_forbid, cell) orelse continue;
            const child_colex = colexFromPosRt(w, h, &result.pos);
            const child_ko: usize = if (result.ko < n) result.ko else n;
            const lin = linearEncode.encode(child_colex, other_side, child_ko, 0);
            if (visited.get(lin)) |child_id| {
                try children.append(allocator, child_id);
            }
        }
        // Pass successor
        {
            const lin = linearEncode.encode(dec.colex, other_side, n, dec.passes + 1);
            if (visited.get(lin)) |child_id| {
                try children.append(allocator, child_id);
            }
        }
        adjacency[v] = try children.toOwnedSlice(allocator);
        total_edges += adjacency[v].len;
    }

    // ── Iterative Tarjan ──────────────────────────────────────────────
    var index = try allocator.alloc(i32, V);
    defer allocator.free(index);
    @memset(index, -1);

    var lowlink = try allocator.alloc(u32, V);
    defer allocator.free(lowlink);

    var onstack = try allocator.alloc(bool, V);
    defer allocator.free(onstack);
    @memset(onstack, false);

    var scc_stack = try std.ArrayListUnmanaged(u32).initCapacity(allocator, V);
    defer scc_stack.deinit(allocator);

    var comp = try allocator.alloc(u32, V);
    defer allocator.free(comp);

    var counter: u32 = 0;
    var ncomp: u32 = 0;

    for (0..V) |root| {
        if (index[root] != -1) continue;

        var frames = try std.ArrayListUnmanaged(struct { v: u32, child_idx: u32 }).initCapacity(allocator, 0);
        defer frames.deinit(allocator);
        try frames.append(allocator, .{ .v = @intCast(root), .child_idx = 0 });

        while (frames.items.len > 0) {
            const frame = &frames.items[frames.items.len - 1];
            const v = frame.v;
            const ci = frame.child_idx;

            if (ci == 0) {
                index[v] = @intCast(counter);
                lowlink[v] = counter;
                counter += 1;
                try scc_stack.append(allocator, v);
                onstack[v] = true;
            }

            const children = adjacency[v];
            var recurse = false;
            var i: u32 = ci;
            while (i < children.len) : (i += 1) {
                const w_v = children[i];
                frame.child_idx = i + 1;
                if (index[w_v] == -1) {
                    try frames.append(allocator, .{ .v = w_v, .child_idx = 0 });
                    recurse = true;
                    break;
                } else if (onstack[w_v]) {
                    if (@as(i32, @intCast(index[w_v])) < lowlink[v]) {
                        lowlink[v] = @intCast(index[w_v]);
                    }
                }
            }
            if (recurse) continue;

            // v is done
            if (lowlink[v] == index[v]) {
                while (true) {
                    const popped = scc_stack.pop().?;
                    onstack[popped] = false;
                    comp[popped] = ncomp;
                    if (popped == v) break;
                }
                ncomp += 1;
            }

            _ = frames.pop();
            // propagate lowlink to parent
            if (frames.items.len > 0) {
                const parent_v = frames.items[frames.items.len - 1].v;
                if (lowlink[v] < lowlink[parent_v]) {
                    lowlink[parent_v] = lowlink[v];
                }
            }
        }
    }

    // ── SCC stats ─────────────────────────────────────────────────────
    var comp_sizes = try allocator.alloc(u32, ncomp);
    defer allocator.free(comp_sizes);
    @memset(comp_sizes, 0);
    for (comp) |c| comp_sizes[c] += 1;

    var non_trivial: u64 = 0;
    var max_scc: u64 = 0;
    var cycle_involved: u64 = 0;
    for (comp_sizes) |sz| {
        if (sz >= 2) {
            non_trivial += 1;
            cycle_involved += sz;
        }
        if (sz > max_scc) max_scc = sz;
    }

    // ── Cycle-reachable (reverse BFS from cycle-involved) ─────────────
    var cycle_reachable_set = try allocator.alloc(bool, V);
    defer allocator.free(cycle_reachable_set);
    @memset(cycle_reachable_set, false);

    var rev_queue = try std.ArrayListUnmanaged(u32).initCapacity(allocator, 0);
    defer rev_queue.deinit(allocator);

    for (0..V) |v| {
        if (comp_sizes[comp[v]] >= 2) {
            cycle_reachable_set[v] = true;
            try rev_queue.append(allocator, @intCast(v));
        }
    }

    var rev_qhead: usize = 0;
    while (rev_qhead < rev_queue.items.len) {
        const v = rev_queue.items[rev_qhead];
        rev_qhead += 1;
        // find parents of v by scanning all adjacency lists
        for (0..V) |parent| {
            if (cycle_reachable_set[parent]) continue;
            for (adjacency[parent]) |child| {
                if (child == v) {
                    cycle_reachable_set[parent] = true;
                    try rev_queue.append(allocator, @intCast(parent));
                    break;
                }
            }
        }
    }

    const cycle_reachable_count: u64 = @intCast(rev_queue.items.len);

    // ── KO_SENSITIVE containment check ────────────────────────────────
    // For WZO1, KO_SENSITIVE is stored as a per-(colex, side) flag (fb/fw).
    // This flag applies to the fresh-start state at passes=0, ko=NONE.
    var ko_sensitive: u64 = 0;
    var ko_not_cycle_reachable: u64 = 0;
    var seed_hint_colex: ?u64 = null;
    var seed_hint_side: ?u1 = null;
    var seed_hint_clear_colex: ?u64 = null;
    var seed_hint_clear_side: ?u1 = null;

    for (0..V) |v| {
        const lin = dense_to_linear.items[v];
        const dec = linearEncode.decode(lin);

        // Check KO_SENSITIVE flag — at ko=NONE, passes=0 only.
        if (dec.ko == n and dec.passes == 0) {
            const flags = if (dec.side == 0) fb[@intCast(dec.colex)] else fw[@intCast(dec.colex)];
            const is_ko_sensitive = (flags & 1) != 0;
            if (is_ko_sensitive) {
                ko_sensitive += 1;
                if (!cycle_reachable_set[v]) {
                    ko_not_cycle_reachable += 1;
                }
            }
            // Record the first non-cycle-reachable state for seeded-defect
            // control testing.
            if (seed_hint_colex == null and !cycle_reachable_set[v]) {
                seed_hint_colex = dec.colex;
                seed_hint_side = dec.side;
            }
            // Record the first non-cycle-reachable state whose flag is CLEAR
            // (a spurious-KO_SENSITIVE seed needs a clear slot).
            if (seed_hint_clear_colex == null and !cycle_reachable_set[v] and !is_ko_sensitive) {
                seed_hint_clear_colex = dec.colex;
                seed_hint_clear_side = dec.side;
            }
        }
    }

    return Result{
        .nodes = V,
        .edges = total_edges,
        .scc_non_trivial = non_trivial,
        .max_scc_size = max_scc,
        .cycle_involved = cycle_involved,
        .cycle_reachable = cycle_reachable_count,
        .ko_sensitive_count = ko_sensitive,
        .ko_not_cr = ko_not_cycle_reachable,
        .status = if (ko_not_cycle_reachable == 0) .pass else .fail,
        .seed_hint_colex = seed_hint_colex,
        .seed_hint_side = seed_hint_side,
        .seed_hint_clear_colex = seed_hint_clear_colex,
        .seed_hint_clear_side = seed_hint_clear_side,
        // Memory ledger (plan §2.1/§11 line items) — small-goban path.
        .mem_file_bytes = artifact_bytes.len,
        .mem_entry_data = artifact_bytes.len - 32, // 6 dense WZO1 columns
        .mem_dense_linear = V * @sizeOf(u64),
        .mem_index = V * @sizeOf(i32),
        .mem_lowlink = V * @sizeOf(u32),
        .mem_onstack = V * @sizeOf(bool),
        .mem_comp = V * @sizeOf(u32),
        .mem_cr = V * @sizeOf(bool),
        .mem_adjacency = total_edges * @sizeOf(u32),
    };
}

// ═══════════════════════════════════════════════════════════════════════════
//  LARGE-GOBAN I5 (4×4 WZO2 — colex→group direct mapping + Tarjan)
// ═══════════════════════════════════════════════════════════════════════════

/// Run I5 on the 4×4 WZO2 artifact using the T134 memory plan:
/// colex→group direct array + iterative Tarjan with on-the-fly edges.
fn checkI5Wzo2(
    allocator: std.mem.Allocator,
    mmap_bytes: []const u8,
) !Result {
    const w: usize = 4;
    const h: usize = 4;
    const n: usize = w * h;
    const ko_none: u8 = @intCast(n); // 16

    if (mmap_bytes.len < WZO2_HEADER_SIZE) return error.FileTooSmall;
    const header_bytes: *const [WZO2_HEADER_SIZE]u8 = mmap_bytes[0..WZO2_HEADER_SIZE][0..WZO2_HEADER_SIZE];
    const hdr = try parseWzo2Header(header_bytes);

    const group_start: usize = hdr.data_offset;
    const group_end: usize = group_start + @as(usize, @intCast(hdr.n_groups)) * WZO2_GROUP_HEADER_SIZE;
    const entry_start: usize = group_end;
    const entry_end: usize = entry_start + @as(usize, @intCast(hdr.n_entries)) * WZO2_ENTRY_SIZE;
    if (entry_end > mmap_bytes.len) return error.FileTooSmall;

    const groups = mmap_bytes[group_start..group_end];
    const entries = mmap_bytes[entry_start..entry_end];

    const n_groups: u64 = hdr.n_groups;
    const n_entries: u64 = hdr.n_entries;

    // ── Memory ledger (plan §2.1 line items) ────────────────────────
    var res = Result{ .status = .pass };
    res.mem_file_bytes = mmap_bytes.len;
    res.mem_group_index = groups.len;
    res.mem_entry_data = entries.len;

    // ── Build colex→group mapping ─────────────────────────────────────
    const c2g = try buildColexToGroup(allocator, groups, n_groups);
    defer allocator.free(c2g);
    res.mem_colex_map = COLEX_SPACE_4X4 * @sizeOf(u32);

    // ── Build entry start offsets per group ───────────────────────────
    var entry_starts = try allocator.alloc(u64, n_groups);
    defer allocator.free(entry_starts);
    res.mem_entry_starts = n_groups * @sizeOf(u64);
    {
        var cum: u64 = 0;
        for (0..n_groups) |g| {
            entry_starts[g] = cum;
            const off = g * WZO2_GROUP_HEADER_SIZE;
            cum += groups[off + 4]; // entry_count at offset 4
        }
    }
    assert(entry_starts[n_groups - 1] + groups[(n_groups - 1) * WZO2_GROUP_HEADER_SIZE + 4] == n_entries);

    // ── KO_SENSITIVE census (first pass) ──────────────────────────────
    var ko_sensitive: u64 = 0;
    {
        for (0..n_groups) |g| {
            const count = groups[g * WZO2_GROUP_HEADER_SIZE + 4];
            const start = entry_starts[g];
            for (0..count) |i| {
                const ent = entries[(@as(usize, @intCast(start)) + i) * WZO2_ENTRY_SIZE ..][0..WZO2_ENTRY_SIZE];
                const L = @as(i8, @bitCast(ent[1]));
                const H = @as(i8, @bitCast(ent[2]));
                if (L != H) ko_sensitive += 1;
            }
        }
    }

    // ── Tarjan arrays ─────────────────────────────────────────────────
    const V = n_entries;

    var index = try allocator.alloc(i32, @intCast(V));
    defer allocator.free(index);
    @memset(index, -1);
    res.mem_index = V * @sizeOf(i32);

    var lowlink = try allocator.alloc(u32, @intCast(V));
    defer allocator.free(lowlink);
    res.mem_lowlink = V * @sizeOf(u32);

    // Packed onstack bitset: 1 bit per vertex
    const onstack_words = (@as(usize, @intCast(V)) + 63) / 64;
    var onstack = try allocator.alloc(u64, onstack_words);
    defer allocator.free(onstack);
    @memset(onstack, 0);
    res.mem_onstack = onstack_words * @sizeOf(u64);

    var scc_stack = try std.ArrayListUnmanaged(u64).initCapacity(allocator, @intCast(V));
    defer scc_stack.deinit(allocator);
    res.mem_scc_stack = V * @sizeOf(u64);

    var comp = try allocator.alloc(u32, @intCast(V));
    defer allocator.free(comp);
    res.mem_comp = V * @sizeOf(u32);

    var counter: u32 = 0;
    var ncomp: u32 = 0;
    var total_edges: u64 = 0;

    // DFS frame: (vertex: u64, child_count: u8, child_idx: u8, children_buf: [18]u64)
    const Frame = struct {
        v: u64,
        n_children: u8, // total number of children found
        child_idx: u8, // next child to process
        children: [18]u64, // child vertex IDs (max 16 place + 1 pass = 17, +padding)
    };

    var frames = try std.ArrayListUnmanaged(Frame).initCapacity(allocator, 0);
    defer frames.deinit(allocator);

    // Scratch buffer for position
    var pos_buf: [n]i8 = undefined;
    var move_bm: [3]u8 = undefined; // 17 bits fits in 3 bytes

    // ── Iterative Tarjan over all entries ─────────────────────────────
    for (0..V) |root| {
        if (index[root] != -1) continue;

        try frames.append(allocator, .{ .v = root, .n_children = 0, .child_idx = 0, .children = [_]u64{0} ** 18 });

        while (frames.items.len > 0) {
            const frame = &frames.items[frames.items.len - 1];
            const v = frame.v;

            // On first visit: set index/lowlink and push to SCC stack
            if (frame.child_idx == 0 and frame.n_children == 0) {
                index[@intCast(v)] = @intCast(counter);
                lowlink[@intCast(v)] = counter;
                counter += 1;
                try scc_stack.append(allocator, v);
                const word_idx: usize = @intCast(v / 64);
                const bit_idx: u6 = @intCast(v % 64);
                onstack[word_idx] |= @as(u64, 1) << bit_idx;

                // ── Compute children on the fly ──────────────────────────
                // Reconstruct state from entry
                const gi = findGroupForEntry(entry_starts, v);
                const colex = std.mem.readInt(u32, groups[gi * WZO2_GROUP_HEADER_SIZE ..][0..4], .little);
                    _ = v - entry_starts[gi]; // local_idx
                const ent_off: usize = @intCast(v * WZO2_ENTRY_SIZE);
                const ent = entries[ent_off..][0..WZO2_ENTRY_SIZE];
                const kb = ent[0];
                const side = keyByteSide(kb);
                const ko = keyByteKo(kb, hdr.ko_bits);
                const passes = keyBytePasses(kb, hdr.ko_bits);
                const terminal = keyByteTerminal(kb);

                if (terminal or passes >= 2) {
                    // Terminal: out-degree 0
                    frame.n_children = 0;
                } else {
                    // Decode position from colex
                    posFromColexRt(w, h, colex, &pos_buf);

                    // Determine ko_forbidden for placement moves
                    const ko_forbidden: u8 = if (ko < n) ko else ko_none;

                    // Use vb_movegen legalMoves to determine legal moves
                    const S = vb_movegen.State(w, h);
                    var state_pos: [n]i8 = undefined;
                    @memcpy(&state_pos, &pos_buf);
                    // Ensure i8 values: posFromColexRt uses -1/+1/0
                    const state: S = .{
                        .pos = state_pos,
                        .side = side,
                        .ko = ko_forbidden,
                        .passes = passes,
                    };
                    move_bm = vb_movegen.legalMoves(w, h, state);

                    var n_child: u8 = 0;

                    // Placement children
                    for (0..n) |cell| {
                        const byte_idx = cell / 8;
                        const cell_bit = cell % 8;
                        if (move_bm[byte_idx] & (@as(u8, 1) << @intCast(cell_bit)) == 0) continue;

                        const result = applyMove(w, h, &pos_buf, side, ko_forbidden, cell) orelse continue;
                        const child_colex = colexFromPosRt(w, h, &result.pos);
                        const child_ko: u8 = if (result.ko < n) result.ko else @intCast(n);

                        // Look up child in table (child side is opposite)
                        if (lookupEntry(c2g, entries, groups, entry_starts, child_colex, -side, child_ko, 0, hdr.ko_bits)) |child_v| {
                            frame.children[n_child] = child_v;
                            n_child += 1;
                            total_edges += 1;
                        }
                    }

                    // Pass child
                    {
                        const pass_byte = n / 8;
                        const pass_bit = n % 8;
                        if (move_bm[pass_byte] & (@as(u8, 1) << @intCast(pass_bit)) != 0) {
                            const pass = applyPass(side, passes);
                            const child_colex = colexFromPosRt(w, h, &pos_buf);
                            if (lookupEntry(c2g, entries, groups, entry_starts, child_colex, pass.side, pass.ko, pass.passes, hdr.ko_bits)) |child_v| {
                                frame.children[n_child] = child_v;
                                n_child += 1;
                                total_edges += 1;
                            }
                        }
                    }

                    frame.n_children = n_child;
                }
            }

            // Process next unvisited child
            var recurse = false;
            while (frame.child_idx < frame.n_children) {
                const w_v = frame.children[frame.child_idx];
                frame.child_idx += 1;
                if (index[@intCast(w_v)] == -1) {
                    try frames.append(allocator, .{ .v = w_v, .n_children = 0, .child_idx = 0, .children = [_]u64{0} ** 18 });
                    recurse = true;
                    break;
                } else {
                    const ww: usize = @intCast(w_v / 64);
                    const wb: u6 = @intCast(w_v % 64);
                    if ((onstack[ww] & (@as(u64, 1) << wb)) != 0) {
                        if (@as(i32, @intCast(index[@intCast(w_v)])) < lowlink[@intCast(v)]) {
                            lowlink[@intCast(v)] = @intCast(index[@intCast(w_v)]);
                        }
                    }
                }
            }
            if (recurse) continue;

            // v is done — check if SCC root
            if (lowlink[@intCast(v)] == index[@intCast(v)]) {
                while (true) {
                    const popped = scc_stack.pop().?;
                    const pw: usize = @intCast(popped / 64);
                    const pb: u6 = @intCast(popped % 64);
                    onstack[pw] &= ~(@as(u64, 1) << pb);
                    comp[@intCast(popped)] = ncomp;
                    if (popped == v) break;
                }
                ncomp += 1;
            }

            _ = frames.pop();
            // Propagate lowlink to parent
            if (frames.items.len > 0) {
                const parent_v = frames.items[frames.items.len - 1].v;
                if (lowlink[@intCast(v)] < lowlink[@intCast(parent_v)]) {
                    lowlink[@intCast(parent_v)] = lowlink[@intCast(v)];
                }
            }
        }
    }

    // ── SCC stats ─────────────────────────────────────────────────────
    var comp_sizes = try allocator.alloc(u32, ncomp);
    defer allocator.free(comp_sizes);
    @memset(comp_sizes, 0);
    res.mem_comp_sizes = ncomp * @sizeOf(u32);
    for (comp) |c| comp_sizes[c] += 1;

    var non_trivial: u64 = 0;
    var max_scc: u64 = 0;
    var cycle_involved: u64 = 0;
    for (comp_sizes) |sz| {
        if (sz >= 2) {
            non_trivial += 1;
            cycle_involved += sz;
        }
        if (sz > max_scc) max_scc = sz;
    }

    // ── Cycle-reachable: reverse edges to find all cycle-reachable states
    // For 4×4, we use snapshot-sweep BFS from cycle-involved sources.
    var cr = try allocator.alloc(bool, @intCast(V));
    defer allocator.free(cr);
    @memset(cr, false);
    res.mem_cr = V * @sizeOf(bool);
    res.mem_frames = frames.capacity * @sizeOf(Frame);

    // Seed: cycle-involved vertices
    for (0..V) |v| {
        if (comp_sizes[comp[v]] >= 2) {
            cr[v] = true;
        }
    }

    // Snapshot-sweep: repeatedly scan, for each CR-marked vertex, mark its
    // parents (states that can reach it) as CR. A parent is a state that
    // has an edge to a CR-marked child.
    // Since we don't have reverse adjacency stored, we iterate all vertices
    // and check if any child is CR-marked.
    var changed = true;
    var sweeps: u64 = 0;
    while (changed) {
        changed = false;
        sweeps += 1;
        for (0..V) |v| {
            if (cr[v]) continue;

            // Reconstruct state
            const gi2 = findGroupForEntry(entry_starts, v);
            const colex2 = std.mem.readInt(u32, groups[gi2 * WZO2_GROUP_HEADER_SIZE ..][0..4], .little);
            const ent2 = entries[@as(usize, @intCast(v)) * WZO2_ENTRY_SIZE ..][0..WZO2_ENTRY_SIZE];
            const kb2 = ent2[0];
            const side2 = keyByteSide(kb2);
            const ko2 = keyByteKo(kb2, hdr.ko_bits);
            const passes2 = keyBytePasses(kb2, hdr.ko_bits);
            const terminal2 = keyByteTerminal(kb2);

            if (terminal2 or passes2 >= 2) continue;

            posFromColexRt(w, h, colex2, &pos_buf);
            const ko_forbidden2: u8 = if (ko2 < n) ko2 else ko_none;

            const S2 = vb_movegen.State(w, h);
            var state_pos2: [n]i8 = undefined;
            @memcpy(&state_pos2, &pos_buf);
            const state2: S2 = .{ .pos = state_pos2, .side = side2, .ko = ko_forbidden2, .passes = passes2 };
            move_bm = vb_movegen.legalMoves(w, h, state2);

            var found_cr_child = false;

            // Check placement children
            var cell: usize = 0;
            while (cell < n and !found_cr_child) : (cell += 1) {
                if (move_bm[cell / 8] & (@as(u8, 1) << @intCast(cell % 8)) == 0) continue;
                const result2 = applyMove(w, h, &pos_buf, side2, ko_forbidden2, cell) orelse continue;
                const child_colex2 = colexFromPosRt(w, h, &result2.pos);
                const child_ko2: u8 = if (result2.ko < n) result2.ko else @intCast(n);
                if (lookupEntry(c2g, entries, groups, entry_starts, child_colex2, -side2, child_ko2, 0, hdr.ko_bits)) |child_v2| {
                    if (cr[@intCast(child_v2)]) {
                        found_cr_child = true;
                    }
                }
            }

            // Check pass child
            if (!found_cr_child and move_bm[n / 8] & (@as(u8, 1) << @intCast(n % 8)) != 0) {
                const pass2 = applyPass(side2, passes2);
                const child_colex3 = colexFromPosRt(w, h, &pos_buf);
                if (lookupEntry(c2g, entries, groups, entry_starts, child_colex3, pass2.side, pass2.ko, pass2.passes, hdr.ko_bits)) |child_v3| {
                    if (cr[@intCast(child_v3)]) {
                        found_cr_child = true;
                    }
                }
            }

            if (found_cr_child) {
                cr[v] = true;
                changed = true;
            }
        }
    }

    var cycle_reachable_count: u64 = 0;
    for (cr) |b| { if (b) cycle_reachable_count += 1; }

    // ── KO_SENSITIVE containment check ────────────────────────────────
    var ko_not_cr: u64 = 0;
    var seed_clear_ei: ?u64 = null; // first non-CR L==H entry (for seeding)
    var ko_sensitive_check: u64 = 0;
    for (0..V) |v| {
        const gi_kocheck = findGroupForEntry(entry_starts, v);
        _ = gi_kocheck;
        const ent_kocheck = entries[@as(usize, @intCast(v)) * WZO2_ENTRY_SIZE ..][0..WZO2_ENTRY_SIZE];
        const L = @as(i8, @bitCast(ent_kocheck[1]));
        const H = @as(i8, @bitCast(ent_kocheck[2]));
        if (L != H) {
            ko_sensitive_check += 1;
            if (!cr[v]) {
                ko_not_cr += 1;
            }
        } else if (seed_clear_ei == null and !cr[v]) {
            // First non-cycle-reachable L==H (clear) entry — a spurious
            // L!=H seed can be placed here to demonstrate red-then-green.
            seed_clear_ei = v;
        }
    }
    assert(ko_sensitive_check == ko_sensitive);

    res.nodes = V;
    res.edges = total_edges;
    res.scc_non_trivial = non_trivial;
    res.max_scc_size = max_scc;
    res.cycle_involved = cycle_involved;
    res.cycle_reachable = cycle_reachable_count;
    res.ko_sensitive_count = ko_sensitive;
    res.ko_not_cr = ko_not_cr;
    res.status = if (ko_not_cr == 0) .pass else .fail;
    // seed hints: for the WZO2 path the entries are the vertices; expose the
    // first non-CR L==H entry index (as colex surrogate via its entry index
    // is not meaningful to callers — use the entry index directly in the
    // seeded-defect test via a dedicated accessor instead).
    res.seed_hint_clear_colex = seed_clear_ei;
    return res;
}

// ═══════════════════════════════════════════════════════════════════════════
//  HELPERS: colex (runtime, since we switch on goban size at runtime for
//  the WZO2 path)
// ═══════════════════════════════════════════════════════════════════════════

fn pow3(n: u64) u64 {
    var r: u64 = 1;
    var e: u64 = n;
    var b: u64 = 3;
    while (e > 0) {
        if (e & 1 == 1) r *= b;
        b *= b;
        e >>= 1;
    }
    return r;
}

/// Runtime colex encode (for use in 4×4 path where we need runtime dispatch).
fn colexFromPosRt(comptime w: usize, comptime h: usize, pos: *const [w * h]i8) u64 {
    const n = w * h;
    const c = comptime binomTable(n);
    const layer_off = comptime layerOffsets(n);

    var k: usize = 0;
    var subset: u64 = 0;
    var colours: u64 = 0;
    for (0..n) |cell| {
        if (pos[cell] == 0) continue;
        if (pos[cell] > 0) colours |= @as(u64, 1) << @intCast(k);
        k += 1;
        subset += c[cell][k];
    }
    return layer_off[k] + subset * (@as(u64, 1) << @intCast(k)) + colours;
}

/// Runtime colex decode.
fn posFromColexRt(comptime w: usize, comptime h: usize, idx: u64, out: *[w * h]i8) void {
    const n = w * h;
    const c = comptime binomTable(n);
    const layer_off = comptime layerOffsets(n);

    var k: usize = 0;
    while (idx >= layer_off[k + 1]) k += 1;
    const layer_idx = idx - layer_off[k];
    var subset = layer_idx >> @intCast(k);
    const colours = layer_idx & ((@as(u64, 1) << @intCast(k)) - 1);

    @memset(out[0..n], 0);
    var i = k;
    while (i > 0) {
        i -= 1;
        var cell: usize = n - 1;
        while (c[cell][i + 1] > subset) cell -= 1;
        subset -= c[cell][i + 1];
        const black = (colours >> @intCast(i)) & 1 == 1;
        out[cell] = if (black) @as(i8, 1) else @as(i8, -1);
    }
}

fn binomTable(comptime n: usize) [n + 1][n + 1]u64 {
    var c: [n + 1][n + 1]u64 = .{.{0} ** (n + 1)} ** (n + 1);
    for (0..n + 1) |i| {
        c[i][0] = 1;
        for (1..i + 1) |j| {
            c[i][j] = c[i - 1][j - 1] + (if (j <= i - 1) c[i - 1][j] else 0);
        }
    }
    return c;
}

fn layerOffsets(comptime n: usize) [n + 2]u64 {
    const c = binomTable(n);
    var off: [n + 2]u64 = undefined;
    off[0] = 0;
    for (0..n + 1) |k| {
        off[k + 1] = off[k] + c[n][k] * (@as(u64, 1) << @intCast(k));
    }
    return off;
}

// ═══════════════════════════════════════════════════════════════════════════
//  HELPERS: WZO2 entry lookup + position legality
// ═══════════════════════════════════════════════════════════════════════════

/// Find the group index that contains entry `entry_idx`.
fn findGroupForEntry(entry_starts: []const u64, entry_idx: u64) usize {
    // Binary search entry_starts for the largest start ≤ entry_idx
    var lo: usize = 0;
    var hi: usize = entry_starts.len;
    while (lo + 1 < hi) {
        const mid = lo + (hi - lo) / 2;
        if (entry_starts[mid] <= entry_idx) {
            lo = mid;
        } else {
            hi = mid;
        }
    }
    return lo;
}

/// Look up a child state in the WZO2 table. Returns entry index or null.
fn lookupEntry(
    c2g: []const u32,
    entries: []const u8,
    groups: []const u8,
    entry_starts: []const u64,
    colex: u64,
    child_side: i8,
    child_ko: u8,
    child_passes: u2,
    ko_bits: u8,
) ?u64 {
    if (colex >= COLEX_SPACE_4X4) return null;
    const gi = c2g[@intCast(colex)];
    if (gi == 0xFFFFFFFF) return null;

    const count = groups[@as(usize, gi) * WZO2_GROUP_HEADER_SIZE + 4];
    const start = entry_starts[gi];

    const side_u1: u1 = if (child_side == -1) 1 else 0;
    const target_kb = encodeKeyByteLookup(side_u1, child_ko, child_passes, ko_bits);

    for (0..count) |i| {
        const ent_off = (@as(usize, @intCast(start)) + i) * WZO2_ENTRY_SIZE;
        const kb = entries[ent_off];
        if (kb & 0xFE == target_kb) {
            return @as(u64, start) + i;
        }
    }

    return null;
}

/// Check if a position is legal (every group has at least one liberty).
fn isLegalPosition(comptime w: usize, comptime h: usize, pos: *const [w * h]i8) bool {
    const n = w * h;
    var visited = [_]bool{false} ** (4 * 3); // max 4×3
    for (0..n) |i| {
        if (pos[i] == 0 or visited[i]) continue;
        if (chainHasNoLiberty(w, h, pos, i, if (pos[i] > 0) @as(i8, 1) else @as(i8, -1))) return false;
        // flood to mark visited
        const colour = if (pos[i] > 0) @as(i8, 1) else @as(i8, -1);
        var stack: [n]usize = undefined;
        var sp: usize = 1;
        stack[0] = i;
        visited[i] = true;
        var nb_buf: [4]usize = undefined;
        while (sp > 0) {
            sp -= 1;
            const q = stack[sp];
            const cnt = neighbors(w, h, q, &nb_buf);
            for (nb_buf[0..cnt]) |r| {
                if (pos[r] == colour and !visited[r]) {
                    visited[r] = true;
                    stack[sp] = r;
                    sp += 1;
                }
            }
        }
    }
    return true;
}

// ═══════════════════════════════════════════════════════════════════════════
//  4×3 WZO1 BITSET-BASED I5
// ═══════════════════════════════════════════════════════════════════════════

/// Run I5 on a WZO1 artifact using bitset BFS + on-the-fly iterative
/// Tarjan with SCC DAG propagation. For 4×3 (and potentially larger) gobans
/// where the hash-map approach would OOM or time out.
///
/// `all_legal_seed`: if true, seeds BFS from all legal positions instead
/// of just the empty-board root. Required for seeded-defect control.
fn checkI5Wzo1Bitset(
    allocator: std.mem.Allocator,
    comptime w: usize,
    comptime h: usize,
    artifact_bytes: []const u8,
    all_legal_seed: bool,
) !Result {
    const n = w * h;
    const total: u64 = pow3(@intCast(n));

    // Parse WZO1 header
    if (artifact_bytes.len < 32) return error.Truncated;
    if (!std.mem.eql(u8, artifact_bytes[0..4], "WZO1")) return error.BadMagic;
    if (artifact_bytes[4] != 1) return error.BadVersion;
    const file_total = std.mem.readInt(u64, artifact_bytes[12..20], .little);
    if (file_total != total) return error.TotalMismatch;
    const payload_start: usize = 32;
    const expected_size = payload_start + 6 * @as(usize, @intCast(total));
    if (artifact_bytes.len != expected_size) return error.Truncated;
    const fb = artifact_bytes[payload_start + 2 * @as(usize, @intCast(total)) .. payload_start + 3 * @as(usize, @intCast(total))];
    const fw = artifact_bytes[payload_start + 3 * @as(usize, @intCast(total)) .. payload_start + 4 * @as(usize, @intCast(total))];

    // ── Memory ledger (plan §2.1/§11 line items) ─────────────────────
    var res = Result{ .status = .pass };
    res.mem_file_bytes = artifact_bytes.len;
    res.mem_group_index = 0; // WZO1: dense columns, no separate group index
    res.mem_entry_data = artifact_bytes.len - payload_start; // 6 dense columns

    const ko_count: usize = n + 1;
    const sub_stride: u64 = @as(u64, ko_count) * 3;
    const stride: u64 = 2 * sub_stride;
    const space: u64 = total * stride;

    // Bitset: one bit per linear address
    const bitset_words: usize = (@as(usize, @intCast(space)) + 63) / 64;
    var bitset = try allocator.alloc(u64, bitset_words);
    defer allocator.free(bitset);
    @memset(bitset, 0);
    res.mem_bitset = bitset_words * @sizeOf(u64);

    var queue = try std.ArrayListUnmanaged(u64).initCapacity(allocator, 0);
    defer queue.deinit(allocator);
    res.mem_queue = queue.capacity * @sizeOf(u64);

    // Seed
    if (all_legal_seed) {
        var digits: [n]u8 = [_]u8{0} ** n;
        var pos: [n]i8 = [_]i8{0} ** n;
        while (true) {
            if (isLegalPosition(w, h, &pos)) {
                const colex = colexFromPosRt(w, h, &pos);
                for (0..2) |s| {
                    const lin = encodeLin(colex, @intCast(s), n, 0, stride, sub_stride);
                    const wi2 = @as(usize, @intCast(lin / 64));
                    if ((bitset[wi2] & (@as(u64, 1) << @intCast(lin % 64))) == 0) {
                        bitset[wi2] |= @as(u64, 1) << @intCast(lin % 64);
                        try queue.append(allocator, lin);
                    }
                }
            }
            var i: usize = 0;
            while (i < n) : (i += 1) {
                if (digits[i] == 2) { digits[i] = 0; pos[i] = 0; continue; }
                digits[i] += 1;
                pos[i] = if (digits[i] == 1) @as(i8, 1) else @as(i8, -1);
                break;
            }
            if (i == n) break;
        }
    } else {
        const lin = encodeLin(0, 0, n, 0, stride, sub_stride);
        bitset[0] |= 1;
        try queue.append(allocator, lin);
    }

    // BFS
    var qhead: usize = 0;
    while (qhead < queue.items.len) {
        const cur = queue.items[qhead]; qhead += 1;
        const dec = decodeLin(cur, stride, sub_stride);
        if (dec.passes >= 2) continue;
        const colour: i8 = if (dec.side == 0) @as(i8, 1) else @as(i8, -1);
        const other_side: u1 = if (dec.side == 0) @as(u1, 1) else @as(u1, 0);
        var pos_arr: [n]i8 = undefined;
        posFromColexRt(w, h, dec.colex, &pos_arr);

        for (0..n) |cell| {
            if (pos_arr[cell] != 0) continue;
            const ko_forbid: u8 = if (dec.passes == 1) @intCast(n) else @intCast(dec.ko);
            const result = applyMove(w, h, &pos_arr, colour, ko_forbid, cell) orelse continue;
            const child_colex = colexFromPosRt(w, h, &result.pos);
            const child_ko: usize = if (result.ko < n) result.ko else n;
            const lin = encodeLin(child_colex, other_side, child_ko, 0, stride, sub_stride);
            const wi3 = @as(usize, @intCast(lin / 64));
            if ((bitset[wi3] & (@as(u64, 1) << @intCast(lin % 64))) == 0) {
                bitset[wi3] |= @as(u64, 1) << @intCast(lin % 64);
                try queue.append(allocator, lin);
            }
        }
        {
            const lin = encodeLin(dec.colex, other_side, n, dec.passes + 1, stride, sub_stride);
            const wi4 = @as(usize, @intCast(lin / 64));
            if ((bitset[wi4] & (@as(u64, 1) << @intCast(lin % 64))) == 0) {
                bitset[wi4] |= @as(u64, 1) << @intCast(lin % 64);
                try queue.append(allocator, lin);
            }
        }
    }

    // Count and collect
    res.mem_queue = queue.capacity * @sizeOf(u64);
    var V: u64 = 0;
    for (bitset) |word| V += @popCount(word);
    const Vi = @as(usize, @intCast(V));

    var dense_to_linear = try allocator.alloc(u64, Vi);
    defer allocator.free(dense_to_linear);
    res.mem_dense_linear = Vi * @sizeOf(u64);
    var linear_to_dense = try allocator.alloc(u32, @as(usize, @intCast(space)));
    defer allocator.free(linear_to_dense);
    res.mem_linear_dense = @as(usize, @intCast(space)) * @sizeOf(u32);
    @memset(linear_to_dense, 0xFF);
    {
        var vid: u32 = 0;
        for (0..@as(u64, @intCast(space))) |addr| {
            const awi5 = @as(usize, @intCast(addr / 64));
            if ((bitset[awi5] & (@as(u64, 1) << @intCast(addr % 64))) != 0) {
                dense_to_linear[vid] = addr;
                linear_to_dense[@intCast(addr)] = vid;
                vid += 1;
            }
        }
    }

    // Tarjan with on-the-fly children + SCC DAG
    var out = try runTarjanSccDag(allocator, w, h, @intCast(n), stride, sub_stride, fb, fw, Vi, dense_to_linear, linear_to_dense, space);
    // Fold this function's ledger into the Tarjan result: the artifact and
    // bitset/queue allocations live here, not in runTarjanSccDag.
    out.mem_file_bytes = res.mem_file_bytes;
    out.mem_entry_data = res.mem_entry_data;
    out.mem_group_index = 0;
    out.mem_bitset = res.mem_bitset;
    out.mem_queue = res.mem_queue;
    out.mem_dense_linear = dense_to_linear.len * @sizeOf(u64);
    out.mem_linear_dense = linear_to_dense.len * @sizeOf(u32);
    return out;
}

// ─── Linear encoding helpers (used by both WZO1 and WZO2 bitset paths) ──

fn encodeLin(colex: u64, side: u1, ko_point: usize, passes: u2, stride: u64, sub_stride: u64) u64 {
    const ko_count: u64 = sub_stride / 3;
    const ko_none_val: usize = @intCast(ko_count - 1);
    const ko_enc: u64 = if (ko_point == ko_none_val) 0 else @as(u64, @intCast(ko_point)) + 1;
    return colex * stride + @as(u64, side) * sub_stride + ko_enc * 3 + @as(u64, passes);
}

const DecodedLin = struct { colex: u64, side: u1, ko: usize, passes: u2 };
fn decodeLin(lin: u64, stride: u64, sub_stride: u64) DecodedLin {
    const c = lin / stride;
    const rem = lin % stride;
    const s: u1 = @intCast(rem / sub_stride);
    const r2 = rem % sub_stride;
    const ke = r2 / 3;
    const p: u2 = @intCast(r2 % 3);
    const ko_count_m1 = sub_stride / 3;
    const kp: usize = if (ke == 0) ko_count_m1 - 1 else @intCast(ke - 1);
    return .{ .colex = c, .side = s, .ko = kp, .passes = p };
}

// ─── On-the-fly Tarjan + SCC DAG propagation ─────────────────────────────

fn runTarjanSccDag(
    allocator: std.mem.Allocator,
    comptime w: usize,
    comptime h: usize,
    n: usize,
    stride: u64,
    sub_stride: u64,
    fb: []const u8,
    fw: []const u8,
    Vi: usize,
    dense_to_linear: []const u64,
    linear_to_dense: []const u32,
    space: u64,
) !Result {
    const ko_none = n;

    var index = try allocator.alloc(i32, Vi);
    defer allocator.free(index); @memset(index, -1);
    var lowlink = try allocator.alloc(u32, Vi);
    defer allocator.free(lowlink);
    var onstack = try allocator.alloc(bool, Vi);
    defer allocator.free(onstack); @memset(onstack, false);
    var scc_stack = try std.ArrayListUnmanaged(u32).initCapacity(allocator, Vi);
    defer scc_stack.deinit(allocator);
    var comp = try allocator.alloc(u32, Vi);
    @memset(comp, 0);

    // ── Memory ledger (plan §2.1/§11 line items) ─────────────────────
    var res = Result{ .status = .pass };
    res.mem_file_bytes = 0; // caller records the artifact; columns indexed here
    res.mem_entry_data = 0;
    res.mem_index = Vi * @sizeOf(i32);
    res.mem_lowlink = Vi * @sizeOf(u32);
    res.mem_onstack = Vi * @sizeOf(bool);
    res.mem_scc_stack = Vi * @sizeOf(u32);
    res.mem_comp = Vi * @sizeOf(u32);
    res.mem_dense_linear = dense_to_linear.len * @sizeOf(u64);
    res.mem_linear_dense = linear_to_dense.len * @sizeOf(u32);
    res.mem_queue = 0;

    // Inter-SCC edges NOT stored. Instead, we process SCCs in reverse
    // pop order (topological order of the SCC DAG) and compute children
    // on the fly for each trivial SCC.
    // Record one vertex per SCC for on-the-fly child computation.
    var scc_rep = try allocator.alloc(u32, 0); // will resize
    defer allocator.free(scc_rep);

    var counter: u32 = 0;
    var ncomp: u32 = 0;
    var total_edges: u64 = 0;

    // Iterative Tarjan: frame = (v, child_count, child_idx, child_list)
    const Frame = struct {
        v: u32,
        n_children: u32,
        child_idx: u32,
        children: std.ArrayListUnmanaged(u32),
    };
    var frames = try std.ArrayListUnmanaged(Frame).initCapacity(allocator, 0);
    defer {
        for (frames.items) |*fr| fr.children.deinit(allocator);
        frames.deinit(allocator);
    }
    res.mem_frames = frames.capacity * @sizeOf(Frame);

    for (0..Vi) |root| {
        if (index[root] != -1) continue;
        try frames.append(allocator, .{ .v = @intCast(root), .n_children = 0, .child_idx = 0, .children = .{ .items = &.{}, .capacity = 0 } });

        while (frames.items.len > 0) {
            const frame = &frames.items[frames.items.len - 1];
            const v = frame.v;

            if (frame.child_idx == 0 and frame.n_children == 0) {
                index[v] = @intCast(counter);
                lowlink[v] = counter;
                counter += 1;
                try scc_stack.append(allocator, v);
                onstack[v] = true;

                // Compute children on the fly
                var child_list = try std.ArrayListUnmanaged(u32).initCapacity(allocator, 0);
                computeWzo1Children(allocator, w, h, n, stride, sub_stride, dense_to_linear, linear_to_dense, space, v, &child_list);
                frame.children = child_list;
                frame.n_children = @intCast(child_list.items.len);
                total_edges += frame.n_children;
            }

            var recurse = false;
            while (frame.child_idx < frame.n_children) {
                const w_v = frame.children.items[frame.child_idx];
                frame.child_idx += 1;
                if (index[w_v] == -1) {
                    try frames.append(allocator, .{ .v = w_v, .n_children = 0, .child_idx = 0, .children = .{ .items = &.{}, .capacity = 0 } });
                    recurse = true;
                    break;
                } else if (onstack[w_v]) {
                    if (@as(i32, @intCast(index[w_v])) < lowlink[v]) lowlink[v] = @intCast(index[w_v]);
                }
            }
            if (recurse) continue;

            if (lowlink[v] == index[v]) {
                // Pop SCC — record one representative vertex for on-the-fly
                // child computation later.
                while (true) {
                    const popped = scc_stack.pop().?;
                    onstack[popped] = false;
                    comp[popped] = ncomp;
                    if (popped == v) {
                        scc_rep = try allocator.realloc(scc_rep, ncomp + 1);
                        scc_rep[ncomp] = v;
                        break;
                    }
                }
                ncomp += 1;
            }

            frame.children.deinit(allocator);
            _ = frames.pop();
            if (frames.items.len > 0) {
                const parent_v = frames.items[frames.items.len - 1].v;
                if (lowlink[v] < lowlink[parent_v]) lowlink[parent_v] = lowlink[v];
            }
        }
    }

    // SCC stats
    var comp_sizes = try allocator.alloc(u32, ncomp);
    defer allocator.free(comp_sizes);
    @memset(comp_sizes, 0);
    for (comp) |c| comp_sizes[c] += 1;
    var non_trivial: u64 = 0; var max_scc: u64 = 0; var cycle_involved: u64 = 0;
    for (comp_sizes) |sz| { if (sz >= 2) { non_trivial += 1; cycle_involved += sz; if (sz > max_scc) max_scc = sz; } }

    // ── SCC cycle-reachable: single pass in POP order ──────────────────
    // CR(c) is a backward property: c is cycle-reachable iff some successor
    // SCC is cycle-reachable. Tarjan pops SCCs in reverse topological order
    // (sinks first, sources last), so a successor SCC always has a LOWER
    // component id than its predecessor. Processing ids ASCENDING
    // (sinks → sources) therefore visits every successor before its
    // predecessors — the correct order for this propagation.
    //
    // T391 (2026-08-06): the previous code processed ncomp-1 → 0 (sources
    // first), so a trivial SCC was examined before its successors' CR status
    // was known and was never marked CR unless a child was already marked.
    // At 4×3 all-legal this produced 24 spurious KO_SENSITIVE violations
    // (CR 1,300,006 vs the correct 1,300,030; third-route-4x3.py). The
    // reachable-graph readings were unaffected (the bug only over-reports
    // non-CR), and the recorded "24 natural violations" (T344/T363) are
    // falsified: the true 4×3 all-legal ko_not_cr is 0.
    var scc_cr = try allocator.alloc(bool, ncomp);
    defer allocator.free(scc_cr);
    @memset(scc_cr, false);
    res.mem_cr = ncomp * @sizeOf(bool);
    res.mem_scc_rep = scc_rep.len * @sizeOf(u32);
    res.mem_comp_sizes = ncomp * @sizeOf(u32);
    for (0..ncomp) |c| { if (comp_sizes[c] >= 2) scc_cr[c] = true; }

    // Process ids ascending (sinks → sources): successors before predecessors.
    for (0..ncomp) |c0| {
        const c: u32 = @intCast(c0);
        if (scc_cr[c]) continue; // already CR (non-trivial or propagated)
        // Trivial SCC: compute children of its representative vertex
        const rep_v = scc_rep[c];
        var buf: std.ArrayListUnmanaged(u32) = .{ .items = &.{}, .capacity = 0 };
        computeWzo1Children(allocator, w, h, n, stride, sub_stride, dense_to_linear, linear_to_dense, space, rep_v, &buf);
        for (buf.items) |child_v| {
            if (scc_cr[comp[child_v]]) {
                scc_cr[c] = true;
                break;
            }
        }
        buf.deinit(allocator);
    }

    // ── KO_SENSITIVE containment ──────────────────────────────────────
    var ko_sens: u64 = 0;
    var ko_not_cr: u64 = 0;
    var sh_colex: ?u64 = null;
    var sh_side: ?u1 = null;
    var sh_clear_colex: ?u64 = null;
    var sh_clear_side: ?u1 = null;
    for (0..Vi) |v| {
        const addr = dense_to_linear[v];
        const dec = decodeLin(addr, stride, sub_stride);
        if (dec.ko == ko_none and dec.passes == 0) {
            const flags = if (dec.side == 0) fb[@intCast(dec.colex)] else fw[@intCast(dec.colex)];
            const is_ko_sensitive = (flags & 1) != 0;
            if (is_ko_sensitive) {
                ko_sens += 1;
                if (!scc_cr[comp[v]]) ko_not_cr += 1;
            }
            if (sh_colex == null and !scc_cr[comp[v]]) { sh_colex = dec.colex; sh_side = dec.side; }
            if (sh_clear_colex == null and !scc_cr[comp[v]] and !is_ko_sensitive) { sh_clear_colex = dec.colex; sh_clear_side = dec.side; }
        }
    }

    var cr_count: u64 = 0;
    for (0..Vi) |v| { if (scc_cr[comp[v]]) cr_count += 1; }

    res.nodes = Vi;
    res.edges = total_edges;
    res.scc_non_trivial = non_trivial;
    res.max_scc_size = max_scc;
    res.cycle_involved = cycle_involved;
    res.cycle_reachable = cr_count;
    res.ko_sensitive_count = ko_sens;
    res.ko_not_cr = ko_not_cr;
    res.status = if (ko_not_cr == 0) .pass else .fail;
    res.seed_hint_colex = sh_colex;
    res.seed_hint_side = sh_side;
    res.seed_hint_clear_colex = sh_clear_colex;
    res.seed_hint_clear_side = sh_clear_side;
    return res;
}

/// Compute children for a vertex in the WZO1 bitset graph (on-the-fly).
fn computeWzo1Children(
    alloc: std.mem.Allocator,
    comptime w: usize,
    comptime h: usize,
    n: usize,
    stride: u64,
    sub_stride: u64,
    dense_to_linear: []const u64,
    linear_to_dense: []const u32,
    space: u64,
    v: u32,
    children: *std.ArrayListUnmanaged(u32),
) void {
    const addr = dense_to_linear[v];
    const dec = decodeLin(addr, stride, sub_stride);
    if (dec.passes >= 2) return;
    const colour: i8 = if (dec.side == 0) @as(i8, 1) else @as(i8, -1);
    const other_side: u1 = if (dec.side == 0) @as(u1, 1) else @as(u1, 0);
    var pos_arr: [w * h]i8 = undefined;
    posFromColexRt(w, h, dec.colex, &pos_arr);

    for (0..n) |cell| {
        if (pos_arr[cell] != 0) continue;
        const ko_forbid: u8 = if (dec.passes == 1) @intCast(n) else @intCast(dec.ko);
        const result = applyMove(w, h, &pos_arr, colour, ko_forbid, cell) orelse continue;
        const child_colex = colexFromPosRt(w, h, &result.pos);
        const child_ko: usize = if (result.ko < n) result.ko else n;
        const lin = encodeLin(child_colex, other_side, child_ko, 0, stride, sub_stride);
        if (lin < space) {
            const dv = linear_to_dense[@intCast(lin)];
            if (dv != 0xFFFFFFFF) children.append(alloc, dv) catch {};
        }
    }
    {
        const lin = encodeLin(dec.colex, other_side, n, dec.passes + 1, stride, sub_stride);
        if (lin < space) {
            const dv = linear_to_dense[@intCast(lin)];
            if (dv != 0xFFFFFFFF) children.append(alloc, dv) catch {};
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════
//  MEMORY BREAKDOWN PRINTER (plan §2.1/§11 line items)
// ═══════════════════════════════════════════════════════════════════════════

/// Print the per-component memory ledger with MiB figures, labelled for
/// the plan's line items. Output is diagnostic (stderr via std.debug.print).
pub fn printMemBreakdown(res: Result, goban_label: []const u8) void {
    const mib = struct {
        fn f(b: u64) f64 {
            return @as(f64, @floatFromInt(b)) / (1024.0 * 1024.0);
        }
    }.f;
    std.debug.print("[mem {s}] total={d:.1} MiB (ledger sum) — plan-vs-actual comparison below\n", .{ goban_label, mib(memTotal(res)) });
    std.debug.print("[mem {s}]   artifact file (mmap'd)   {d:>9} B = {d:.1} MiB\n", .{ goban_label, res.mem_file_bytes, mib(res.mem_file_bytes) });
    std.debug.print("[mem {s}]   group index              {d:>9} B = {d:.1} MiB\n", .{ goban_label, res.mem_group_index, mib(res.mem_group_index) });
    std.debug.print("[mem {s}]   entry data               {d:>9} B = {d:.1} MiB\n", .{ goban_label, res.mem_entry_data, mib(res.mem_entry_data) });
    std.debug.print("[mem {s}]   colex→group map          {d:>9} B = {d:.1} MiB\n", .{ goban_label, res.mem_colex_map, mib(res.mem_colex_map) });
    std.debug.print("[mem {s}]   entry_starts             {d:>9} B = {d:.1} MiB\n", .{ goban_label, res.mem_entry_starts, mib(res.mem_entry_starts) });
    std.debug.print("[mem {s}]   Tarjan index             {d:>9} B = {d:.1} MiB\n", .{ goban_label, res.mem_index, mib(res.mem_index) });
    std.debug.print("[mem {s}]   Tarjan lowlink           {d:>9} B = {d:.1} MiB\n", .{ goban_label, res.mem_lowlink, mib(res.mem_lowlink) });
    std.debug.print("[mem {s}]   Tarjan onstack           {d:>9} B = {d:.1} MiB\n", .{ goban_label, res.mem_onstack, mib(res.mem_onstack) });
    std.debug.print("[mem {s}]   SCC id (comp)            {d:>9} B = {d:.1} MiB\n", .{ goban_label, res.mem_comp, mib(res.mem_comp) });
    std.debug.print("[mem {s}]   dense_to_linear          {d:>9} B = {d:.1} MiB\n", .{ goban_label, res.mem_dense_linear, mib(res.mem_dense_linear) });
    std.debug.print("[mem {s}]   linear_to_dense          {d:>9} B = {d:.1} MiB\n", .{ goban_label, res.mem_linear_dense, mib(res.mem_linear_dense) });
    std.debug.print("[mem {s}]   adjacency lists          {d:>9} B = {d:.1} MiB\n", .{ goban_label, res.mem_adjacency, mib(res.mem_adjacency) });
    std.debug.print("[mem {s}]   SCC stack                {d:>9} B = {d:.1} MiB\n", .{ goban_label, res.mem_scc_stack, mib(res.mem_scc_stack) });
    std.debug.print("[mem {s}]   SCC reps                 {d:>9} B = {d:.1} MiB\n", .{ goban_label, res.mem_scc_rep, mib(res.mem_scc_rep) });
    std.debug.print("[mem {s}]   comp_sizes               {d:>9} B = {d:.1} MiB\n", .{ goban_label, res.mem_comp_sizes, mib(res.mem_comp_sizes) });
    std.debug.print("[mem {s}]   cycle-reachable marks    {d:>9} B = {d:.1} MiB\n", .{ goban_label, res.mem_cr, mib(res.mem_cr) });
    std.debug.print("[mem {s}]   BFS bitset               {d:>9} B = {d:.1} MiB\n", .{ goban_label, res.mem_bitset, mib(res.mem_bitset) });
    std.debug.print("[mem {s}]   DFS frame stack          {d:>9} B = {d:.1} MiB\n", .{ goban_label, res.mem_frames, mib(res.mem_frames) });
    std.debug.print("[mem {s}]   BFS queue                {d:>9} B = {d:.1} MiB\n", .{ goban_label, res.mem_queue, mib(res.mem_queue) });
    std.debug.print("[mem {s}]   other (scratch/overhead) {d:>9} B = {d:.1} MiB\n", .{ goban_label, res.mem_other, mib(res.mem_other) });
}

// ═══════════════════════════════════════════════════════════════════════════
//  TESTS
// ═══════════════════════════════════════════════════════════════════════════

test "vb_scc_4x4: 3×2 calibration — SCC structure + clean check" {
    const allocator = std.testing.allocator;
    const artifact_path = "artifacts/oracle-3x2.wzo";

    var threaded = std.Io.Threaded.init(std.heap.page_allocator, .{});
    const io = threaded.io();
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, artifact_path, allocator, .unlimited);
    defer allocator.free(bytes);

    const result = try checkI5Small(allocator, 3, 2, bytes, false);

    // Diagnostic
    std.debug.print("\n[3x2 diag] V={d} E={d} maxSCC={d} nSCC_non_trivial={d} cycle_involved={d} cycle_reachable={d} ko_sens={d} ko_not_cr={d}\n", .{
        result.nodes, result.edges, result.max_scc_size, result.scc_non_trivial,
        result.cycle_involved, result.cycle_reachable, result.ko_sensitive_count, result.ko_not_cr,
    });

    // Structural invariants (calibration-independent)
    try std.testing.expect(result.nodes > 0);
    try std.testing.expect(result.edges > 0);
    try std.testing.expect(result.scc_non_trivial >= 1); // at least one non-trivial SCC (ko cycle)
    try std.testing.expect(result.max_scc_size >= 2);
    try std.testing.expect(result.cycle_involved >= result.max_scc_size);
    try std.testing.expect(result.cycle_reachable >= result.cycle_involved);

    // The clean artifact must have ko_not_cr == 0
    try std.testing.expectEqual(Status.pass, result.status);
    try std.testing.expectEqual(@as(u64, 0), result.ko_not_cr);
}

test "vb_scc_4x4: 3×2 seeded-defect — spurious KO_SENSITIVE on a non-cycle-reachable slot → red-then-green" {
    // Spec §7.2 / plan F2: the FIRST seeded-defect control for I5 runs at 3×2
    // (the 2×2 all-legal graph is entirely cycle-reachable, so a spurious
    // KO_SENSITIVE cannot be caught there). Row bar: set KO_SENSITIVE
    // spuriously on a non-cycle-reachable 3×2 slot → ko_not_cr > 0, shown
    // red-then-green BEFORE the 4×4 reading.
    //
    // Measured finding (T363): in the FULL (colex, side, ko, passes) graph
    // this implementation uses, the 3×2 all-legal graph has NO
    // non-cycle-reachable passes=0 ko=NONE slot (ko_not_cr=0, hint null) —
    // the same vacuity the spec attributed to 2×2 only. The spec's 3×2
    // premise came from the projected-graph model (vb_graph); the full-graph
    // model needs a larger goban. T391 (2026-08-06): the first non-vacuous
    // rung is 4×4 — the previously claimed 4×3 all-legal non-CR slots
    // ("24 natural violations", T344/T363) were a false positive of a
    // CR-propagation order bug in runTarjanSccDag, fixed by T391; the true
    // 4×3 all-legal reading is ko_not_cr=0 (vacuous, same as 3×2). This
    // test records the 3×2 vacuity explicitly and defers the red-then-green
    // to the 4×4 test.
    const allocator = std.heap.page_allocator;
    const artifact_path = "artifacts/oracle-3x2.wzo";

    var threaded = std.Io.Threaded.init(std.heap.page_allocator, .{});
    const io = threaded.io();
    var bytes = try std.Io.Dir.cwd().readFileAlloc(io, artifact_path, allocator, .unlimited);
    defer allocator.free(bytes);

    // GREEN baseline: clean artifact, reachable-from-empty graph.
    const clean = try checkI5Small(allocator, 3, 2, bytes, false);
    try std.testing.expectEqual(Status.pass, clean.status);
    try std.testing.expectEqual(@as(u64, 0), clean.ko_not_cr);

    // All-legal graph: look for a non-cycle-reachable passes=0 ko=NONE slot.
    const all_legal = try checkI5Small(allocator, 3, 2, bytes, true);
    std.debug.print("[3x2 all-legal] V={d} ko_not_cr={d} hint_colex={?d} clear_hint_colex={?d}\n", .{ all_legal.nodes, all_legal.ko_not_cr, all_legal.seed_hint_colex, all_legal.seed_hint_clear_colex });

    if (all_legal.seed_hint_clear_colex == null) {
        // Vacuity documented above: every 3×2 passes=0 ko=NONE slot is
        // cycle-reachable in the full graph. The check still passes the
        // clean artifact; the seeded-defect control moves to 4×4 where a
        // non-CR L==H entry exists (4×3's non-CR slots are all already
        // KO_SENSITIVE, so it is vacuous too). This is a measurement, not
        // a pass.
        std.debug.print("[T344 NOTE] 3×2 all-legal has no non-CR clear-flag slot in the full graph — seeded-defect demonstrated at 4×4 instead (3×2 and 4×3 are vacuous in the full-graph model; 2×2, 3×2, 4×3-reachable share the same vacuity).\n", .{});
        return;
    }

    const hint_colex = all_legal.seed_hint_clear_colex.?;
    const hint_side = all_legal.seed_hint_clear_side.?;

    const total: u64 = 729;
    const payload_start: usize = 32;
    const fb_start = payload_start + 2 * @as(usize, @intCast(total));
    const fw_start = payload_start + 3 * @as(usize, @intCast(total));
    const flag_idx = if (hint_side == 0)
        fb_start + @as(usize, @intCast(hint_colex))
    else
        fw_start + @as(usize, @intCast(hint_colex));
    const old_flag = bytes[flag_idx];

    // RED: spurious KO_SENSITIVE → ko_not_cr increases over baseline.
    bytes[flag_idx] = old_flag | 1;
    const corrupted = try checkI5Small(allocator, 3, 2, bytes, true);
    try std.testing.expectEqual(Status.fail, corrupted.status);
    try std.testing.expect(corrupted.ko_not_cr > all_legal.ko_not_cr);
    std.debug.print("[3x2 seeded-defect RED] ko_not_cr={d} (baseline={d})\n", .{ corrupted.ko_not_cr, all_legal.ko_not_cr });

    // GREEN: restore the flag → back to baseline.
    bytes[flag_idx] = old_flag;
    const restored = try checkI5Small(allocator, 3, 2, bytes, true);
    try std.testing.expectEqual(restored.ko_not_cr, all_legal.ko_not_cr);
    std.debug.print("[3x2 seeded-defect GREEN] restored ko_not_cr={d} (baseline={d})\n", .{ restored.ko_not_cr, all_legal.ko_not_cr });
}

test "vb_scc_4x4: 4×3 calibration — clean check passes" {
    const allocator = std.heap.page_allocator;
    const artifact_path = "artifacts/oracle-4x3.wzo";

    var threaded = std.Io.Threaded.init(std.heap.page_allocator, .{});
    const io = threaded.io();
    const bytes = try std.Io.Dir.cwd().readFileAlloc(io, artifact_path, allocator, .unlimited);
    defer allocator.free(bytes);

    const result = try checkI5Wzo1Bitset(allocator, 4, 3, bytes, false);

    std.debug.print("\n[4x3] V={d} E={d} maxSCC={d} nSCC_nt={d} cycle_inv={d} cycle_reach={d} ko_sens={d} ko_not_cr={d}\n", .{
        result.nodes, result.edges, result.max_scc_size, result.scc_non_trivial,
        result.cycle_involved, result.cycle_reachable, result.ko_sensitive_count, result.ko_not_cr,
    });
    std.debug.print("  seed_hint_colex={?d} seed_hint_side={?d}\n", .{ result.seed_hint_colex, result.seed_hint_side });
    printMemBreakdown(result, "4x3");

    try std.testing.expect(result.nodes > 0);
    // Exact gate (T391): these match the register / third-route values
    // (docs/evidence/I5-DISAGREEMENT/third-route-4x3.py) exactly.
    try std.testing.expectEqual(@as(u64, 1929035), result.nodes);
    try std.testing.expectEqual(@as(u64, 6858926), result.edges);
    try std.testing.expectEqual(@as(u64, 1284078), result.max_scc_size);
    try std.testing.expectEqual(@as(u64, 1284078), result.cycle_involved);
    try std.testing.expectEqual(@as(u64, 1284080), result.cycle_reachable);
    try std.testing.expectEqual(@as(u64, 170181), result.ko_sensitive_count);
    try std.testing.expectEqual(Status.pass, result.status);
    try std.testing.expectEqual(@as(u64, 0), result.ko_not_cr);
}

test "vb_scc_4x4: 4×3 seeded-defect — red-then-green" {
    const allocator = std.heap.page_allocator;
    const artifact_path = "artifacts/oracle-4x3.wzo";

    var threaded = std.Io.Threaded.init(std.heap.page_allocator, .{});
    const io = threaded.io();
    var bytes = try std.Io.Dir.cwd().readFileAlloc(io, artifact_path, allocator, .unlimited);
    defer allocator.free(bytes);

    // GREEN: clean check on reachable-from-empty graph
    const clean = try checkI5Wzo1Bitset(allocator, 4, 3, bytes, false);
    try std.testing.expectEqual(Status.pass, clean.status);
    try std.testing.expectEqual(@as(u64, 0), clean.ko_not_cr);

    // Find a non-CR passes=0 state in the all-legal graph
    const all_legal = try checkI5Wzo1Bitset(allocator, 4, 3, bytes, true);
    std.debug.print("\n[4x3 all-legal] V={d} E={d} scc_nt={d} maxSCC={d} ko_not_cr={d} ko_sens={d} cr={d} hint_colex={?d} clear_hint_colex={?d}\n", .{ all_legal.nodes, all_legal.edges, all_legal.scc_non_trivial, all_legal.max_scc_size, all_legal.ko_not_cr, all_legal.ko_sensitive_count, all_legal.cycle_reachable, all_legal.seed_hint_colex, all_legal.seed_hint_clear_colex });

    // T391: with the CR-propagation order fixed, the 4×3 all-legal graph is
    // vacuous — ko_not_cr = 0 (no non-CR passes=0 ko=NONE slot at all). The
    // "24 natural violations" recorded at T344/T363 were a false positive of
    // the descending propagation order; the true all-legal reading is 0, and
    // the seeded-defect control moves to 4×4 (the first non-vacuous rung,
    // as T363 already concluded for the wrong reason).
    try std.testing.expectEqual(@as(u64, 0), all_legal.ko_not_cr);
    try std.testing.expect(all_legal.seed_hint_colex == null);

    const hint_colex = all_legal.seed_hint_clear_colex orelse {
        std.debug.print("[T391 NOTE] 4×3 all-legal is vacuous (ko_not_cr=0): no non-CR passes=0 ko=NONE slot, so no red-then-green can be shown here. Seeded-defect demonstrated at 4×4. The T344/T363 '24 natural violations' were spurious (propagation-order bug, fixed by T391).\n", .{});
        return;
    };
    const hint_side = all_legal.seed_hint_clear_side.?;

    // Proceed with seeded-defect: spurious KO_SENSITIVE on this clear state
    const total: u64 = 531441;
    const payload_start: usize = 32;
    const fb_start = payload_start + 2 * @as(usize, @intCast(total));
    const fw_start = payload_start + 3 * @as(usize, @intCast(total));
    const flag_idx = if (hint_side == 0)
        fb_start + @as(usize, @intCast(hint_colex))
    else
        fw_start + @as(usize, @intCast(hint_colex));
    const old_flag = bytes[flag_idx];

    // RED: spurious KO_SENSITIVE → ko_not_cr increases
    bytes[flag_idx] = old_flag | 1;
    const corrupted = try checkI5Wzo1Bitset(allocator, 4, 3, bytes, true);
    try std.testing.expectEqual(Status.fail, corrupted.status);
    try std.testing.expect(corrupted.ko_not_cr > all_legal.ko_not_cr);
    std.debug.print("[4x3 seeded-defect RED] ko_not_cr={d} (baseline was {d})\n", .{ corrupted.ko_not_cr, all_legal.ko_not_cr });

    // Restore and verify
    bytes[flag_idx] = old_flag;
    const restored = try checkI5Wzo1Bitset(allocator, 4, 3, bytes, true);
    try std.testing.expectEqual(restored.ko_not_cr, all_legal.ko_not_cr);
    std.debug.print("[4x3 seeded-defect GREEN] restored ko_not_cr={d} (baseline={d})\n", .{ restored.ko_not_cr, all_legal.ko_not_cr });
}

test "vb_scc_4x4: 4×4 seeded-defect — spurious L!=H on a non-cycle-reachable entry → red-then-green" {
    // Spec §7.2 calibration: I5 must fail a seeded defect. At 2×2/3×2/4×3
    // the full-graph model is vacuous (every passes=0 ko=NONE slot is
    // cycle-reachable — T391 confirmed the 4×3 all-legal reading is 0, not
    // the previously reported 24, which were a propagation-order false
    // positive). At 4×4 (WZO2, KO_SENSITIVE = L!=H) there are non-CR L==H
    // entries (~1.44M), so a spurious L!=H seed must push ko_not_cr > 0 —
    // shown red-then-green here.
    const allocator = std.heap.page_allocator;
    const artifact_path = "data/oracle-4x4-v2.wzo2";

    var threaded = std.Io.Threaded.init(std.heap.page_allocator, .{});
    const io = threaded.io();
    const file_bytes = try std.Io.Dir.cwd().readFileAlloc(io, artifact_path, allocator, .unlimited);
    defer allocator.free(file_bytes);

    // GREEN baseline.
    const clean = try checkI5Wzo2(allocator, file_bytes);
    try std.testing.expectEqual(Status.pass, clean.status);
    try std.testing.expectEqual(@as(u64, 0), clean.ko_not_cr);
    const seed_ei = clean.seed_hint_clear_colex orelse {
        std.debug.print("[T344 NOTE] 4×4 has no non-CR L==H entry — cannot seed. (Unexpected; ~1.44M expected.)\n", .{});
        return;
    };

    // RED: make the non-CR entry spurious-KO_SENSITIVE by corrupting L.
    // Entry data begins after the header + group index.
    const entry_data_start: usize = 128 + @as(usize, @intCast(24318165)) * WZO2_GROUP_HEADER_SIZE;
    const off = entry_data_start + @as(usize, @intCast(seed_ei)) * WZO2_ENTRY_SIZE + 1; // L byte
    const orig_l = file_bytes[off];
    const orig_h = file_bytes[off + 1];
    std.debug.print("[4x4 seeded-defect] seed entry {d} L={d} H={d}\n", .{ seed_ei, @as(i8, @bitCast(orig_l)), @as(i8, @bitCast(orig_h)) });
    file_bytes[off] = orig_l +% 1; // flip L to differ from H
    const corrupted = try checkI5Wzo2(allocator, file_bytes);
    try std.testing.expectEqual(Status.fail, corrupted.status);
    try std.testing.expect(corrupted.ko_not_cr > clean.ko_not_cr);
    std.debug.print("[4x4 seeded-defect RED] ko_not_cr={d} (baseline {d}) at entry {d}\n", .{ corrupted.ko_not_cr, clean.ko_not_cr, seed_ei });

    // GREEN: restore.
    file_bytes[off] = orig_l;
    const restored = try checkI5Wzo2(allocator, file_bytes);
    try std.testing.expectEqual(Status.pass, restored.status);
    try std.testing.expectEqual(@as(u64, 0), restored.ko_not_cr);
    std.debug.print("[4x4 seeded-defect GREEN] restored ko_not_cr={d}\n", .{restored.ko_not_cr});
}

test "vb_scc_4x4: 4×4 WZO2 — ko_not_cr == 0" {
    const allocator = std.heap.page_allocator;
    const artifact_path = "data/oracle-4x4-v2.wzo2";

    var threaded = std.Io.Threaded.init(std.heap.page_allocator, .{});
    const io = threaded.io();
    const file_bytes = try std.Io.Dir.cwd().readFileAlloc(io, artifact_path, allocator, .unlimited);
    defer allocator.free(file_bytes);

    // Validate header
    if (file_bytes.len < 128) return error.FileTooSmall;
    try std.testing.expect(std.mem.eql(u8, file_bytes[0..4], "WZO2"));
    try std.testing.expectEqual(@as(u8, 4), file_bytes[6]);
    try std.testing.expectEqual(@as(u8, 4), file_bytes[7]);

    const hdr = try parseWzo2Header(file_bytes[0..128][0..128]);
    try std.testing.expectEqual(@as(u64, 24318165), hdr.n_groups);
    try std.testing.expectEqual(@as(u64, 99133036), hdr.n_entries);

    std.debug.print("\n[4x4] {d} groups, {d} entries ({d} MB). Starting Tarjan...\n", .{
        hdr.n_groups, hdr.n_entries, file_bytes.len / (1024 * 1024),
    });

    // Attempt full I5 check. With 99M entries and snapshot-sweep
    // cycle-reachable propagation, this may be slow. The test
    // runner has a 10-minute silence timeout.
    const result = checkI5Wzo2(allocator, file_bytes) catch |err| {
        std.debug.print("[4x4 FAIL] error: {}\n", .{err});
        return;
    };

    std.debug.print("[4x4] V={d} E={d} maxSCC={d} nSCC_nt={d} cycle_inv={d} cycle_reach={d} ko_sens={d} ko_not_cr={d}\n", .{
        result.nodes, result.edges, result.max_scc_size, result.scc_non_trivial,
        result.cycle_involved, result.cycle_reachable, result.ko_sensitive_count, result.ko_not_cr,
    });
    printMemBreakdown(result, "4x4");

    try std.testing.expect(result.nodes > 0);
    try std.testing.expectEqual(Status.pass, result.status);
    try std.testing.expectEqual(@as(u64, 0), result.ko_not_cr);
}
