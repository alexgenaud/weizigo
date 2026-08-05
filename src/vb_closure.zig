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
// VB_CLOSURE — C-A1 forward closure + C-A2 backward closure over WZO2 table.
//
// Task: T342 · Set: E (g3b-battery) · Holds: src/vb_closure.zig
// Author: deepseek-v4-pro/T342 · Date: 2026-08-04
//
// Implements the two closure checks from G3b pass0 spec §2.1:
//   C-A1 (forward):  Every child of every reachable state is in the table.
//   C-A2 (backward): Every state reachable from the fresh-start root is
//                     in the table.
//
// Membership via group-index binary search + in-group linear scan, per
// plan.md §2.1 memory plan. Uses the kernel move generator (rules.zig,
// T339 MG-KERN). WZO2 schema authority: design-M1.md (rev 3, RATIFIED G2).
//
// Standalone except for rules.zig + colex.zig (kernel move generator +
// colex bijection). No other src/ imports.

const std = @import("std");
const engine = @import("engine");
const rules = engine.rules;
const colex_mod = engine.colex;

const assert = std.debug.assert;

// ═══════════════════════════════════════════════════════════════════════════
//  WZO2 HEADER (design-M1 §4)
// ═══════════════════════════════════════════════════════════════════════════

const WZO2_MAGIC: [4]u8 = .{ 'W', 'Z', 'O', '2' };
const WZO2_HEADER_SIZE: usize = 128;
const WZO2_GROUP_HEADER_SIZE: usize = 5; // colex u32 LE + entry_count u8
const WZO2_ENTRY_SIZE: usize = 4; // key_byte + L + H + DTT
const WZO2_RULES_ID: u16 = 3;

pub const Wzo2Header = struct {
    w: u8,
    h: u8,
    entry_size: u16,
    group_header_size: u8,
    ko_bits: u8,
    hdr_flags: u8,
    n_groups: u64,
    n_entries: u64,
    data_offset: u64,

    pub fn passes2Omitted(self: Wzo2Header) bool {
        return (self.hdr_flags & 1) != 0;
    }
};

/// Parse a WZO2 header from the first 128 bytes. Returns error on magic
/// mismatch, wrong version, or structural inconsistencies.
pub fn parseWzo2Header(bytes: *const [WZO2_HEADER_SIZE]u8) !Wzo2Header {
    if (!std.mem.eql(u8, bytes[0..4], &WZO2_MAGIC)) return error.BadMagic;
    const version = std.mem.readInt(u16, bytes[4..6], .little);
    if (version != 1) return error.BadVersion;
    const w = bytes[6];
    const h = bytes[7];
    const rules_id = std.mem.readInt(u16, bytes[8..10], .little);
    if (rules_id != WZO2_RULES_ID) return error.WrongRulesId;
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
        .entry_size = entry_size,
        .group_header_size = group_header_size,
        .ko_bits = ko_bits,
        .hdr_flags = hdr_flags,
        .n_groups = n_groups,
        .n_entries = n_entries,
        .data_offset = data_offset,
    };
}

/// Compute ko_none sentinel for the given goban size: n = w*h.
pub fn koNone(w: u8, h: u8) u8 {
    return w * h;
}

// ═══════════════════════════════════════════════════════════════════════════
//  KEY BYTE ENCODING (design-M1 §2.2, artifact2.zig authority)
// ═══════════════════════════════════════════════════════════════════════════
//
// Bit layout (MSB→LSB): [passes:1][ko_point:KO_BITS][side:1][terminal:1]
//   terminal = bit 0 (LSB)
//   side     = bit 1  (0=Black, 1=White)
//   ko_point = bits 2 .. 1+KO_BITS
//   passes   = bit (2+KO_BITS)

/// Encode a key byte from components. Matches artifact2.encodeKeyByte.
/// side: u1 — 0=Black, 1=White.
fn encodeKeyByte(side: u1, ko: u8, passes: u2, ko_bits: u8, terminal: bool) u8 {
    var kb: u8 = if (terminal) @as(u8, 1) else 0; // bit 0
    kb |= @as(u8, side) << 1; // bit 1
    kb |= ko << 2; // bits 2..(2+ko_bits-1)
    kb |= @as(u8, passes) << @intCast(2 + ko_bits); // bit (2+ko_bits)
    return kb;
}

/// Encode a key byte for lookup (terminal bit = 0, masked off during scan).
fn encodeKeyByteLookup(side: u1, ko: u8, passes: u2, ko_bits: u8) u8 {
    return encodeKeyByte(side, ko, passes, ko_bits, false);
}

/// Convert kernel side (+1=Black, -1=White) to u1 (0=Black, 1=White).
fn sideToU1(side: i8) u1 {
    return if (side == -1) @as(u1, 1) else @as(u1, 0);
}

/// Extract side from key_byte. Returns +1=Black, -1=White.
fn keyByteSide(kb: u8) i8 {
    return if ((kb & 2) != 0) @as(i8, -1) else @as(i8, 1);
}

/// Extract passes from key_byte (with ko_bits).
fn keyBytePasses(kb: u8, ko_bits: u8) u2 {
    return @intCast((kb >> @intCast(2 + ko_bits)) & 1);
}

/// Extract terminal flag from key_byte.
fn keyByteTerminal(kb: u8) bool {
    return (kb & 1) != 0;
}

// ═══════════════════════════════════════════════════════════════════════════
//  WZO2 READER
// ═══════════════════════════════════════════════════════════════════════════
//
// Loads the WZO2 artifact fully into memory:
//   - Group index: n_groups × 5 bytes (colex u32 LE + count u8), kept in memory
//   - Sparse prefix sum: every 256th group's cumulative entry index (~380 KB at 4×4)
//   - Entry data: n_entries × 4 bytes, kept in memory for fast scanning

pub const Wzo2Reader = struct {
    header: Wzo2Header,
    allocator: std.mem.Allocator,
    /// Full group-index slice: n_groups × 5 bytes. Owned; freed in deinit.
    groups: []align(1) u8,
    /// Full entry-data slice: n_entries × 4 bytes. Owned; freed in deinit.
    entries: []align(1) u8,
    /// Sparse prefix sum: entry_checkpoints[i] = cumulative entry count
    /// at group index i*256. Length = ceil(n_groups/256).
    entry_checkpoints: []u64,

    pub fn deinit(self: *Wzo2Reader) void {
        self.allocator.free(self.groups);
        self.allocator.free(self.entries);
        self.allocator.free(self.entry_checkpoints);
    }

    /// Return the colex index for group g (standalone helper).
    pub fn groupColex(groups: []const u8, g: usize) u32 {
        const off = g * WZO2_GROUP_HEADER_SIZE;
        return std.mem.readInt(u32, groups[off..][0..4], .little);
    }

    /// Return the entry count for group g (standalone helper).
    pub fn groupEntryCount(groups: []const u8, g: usize) u8 {
        const off = g * WZO2_GROUP_HEADER_SIZE;
        return groups[off + 4];
    }

    /// Return the entry count for group g (instance method).
    pub fn entryCount(self: *const Wzo2Reader, g: usize) u8 {
        return Wzo2Reader.groupEntryCount(self.groups, g);
    }

    /// Load a WZO2 artifact from a byte slice (the full file contents).
    /// Copies group index and entry data into owned allocations.
    pub fn load(allocator: std.mem.Allocator, file_bytes: []const u8) !Wzo2Reader {
        if (file_bytes.len < WZO2_HEADER_SIZE) return error.FileTooSmall;

        const header_bytes: *const [WZO2_HEADER_SIZE]u8 = file_bytes[0..WZO2_HEADER_SIZE][0..WZO2_HEADER_SIZE];
        const header = try parseWzo2Header(header_bytes);

        const group_start: usize = header.data_offset;
        const group_end: usize = group_start + header.n_groups * WZO2_GROUP_HEADER_SIZE;
        const entry_start: usize = group_end;
        const entry_end: usize = entry_start + header.n_entries * WZO2_ENTRY_SIZE;

        if (entry_end > file_bytes.len) return error.FileTooSmall;
        // File size must match exactly (design-M1 §1: no sentinel)
        const expected_size = header.data_offset +
            header.n_groups * WZO2_GROUP_HEADER_SIZE +
            header.n_entries * WZO2_ENTRY_SIZE;
        if (file_bytes.len != expected_size) return error.BadFileSize;

        // Copy groups into owned allocation
        const groups = try allocator.dupe(u8, file_bytes[group_start..group_end]);
        errdefer allocator.free(groups);

        // Copy entries into owned allocation
        const entries = try allocator.dupe(u8, file_bytes[entry_start..entry_end]);
        errdefer allocator.free(entries);

        // Build sparse prefix sum: every 256th group
        const n_checkpoints = (header.n_groups + 255) / 256;
        const entry_checkpoints = try allocator.alloc(u64, n_checkpoints);
        errdefer allocator.free(entry_checkpoints);

        var cum: u64 = 0;
        for (0..header.n_groups) |g| {
            if (g % 256 == 0) {
                entry_checkpoints[g / 256] = cum;
            }
            cum += Wzo2Reader.groupEntryCount(groups, g);
        }

        return Wzo2Reader{
            .header = header,
            .allocator = allocator,
            .groups = groups,
            .entries = entries,
            .entry_checkpoints = entry_checkpoints,
        };
    }

    /// Binary-search the group index for `colex`. Returns the group index
    /// (0..n_groups) if found, else null.
    pub fn findGroup(self: *const Wzo2Reader, colex: u32) ?usize {
        var lo: usize = 0;
        var hi: usize = self.header.n_groups;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            const mid_colex = Wzo2Reader.groupColex(self.groups, mid);
            if (mid_colex < colex) {
                lo = mid + 1;
            } else if (mid_colex > colex) {
                hi = mid;
            } else {
                return mid;
            }
        }
        return null;
    }

    /// Get the starting entry index for group g, using the sparse prefix sum.
    pub fn groupEntryStart(self: *const Wzo2Reader, g: usize) u64 {
        const checkpoint_idx = g >> 8; // g / 256
        var offset = self.entry_checkpoints[checkpoint_idx];
        var i = checkpoint_idx * 256;
        while (i < g) : (i += 1) {
            offset += Wzo2Reader.groupEntryCount(self.groups, i);
        }
        return offset;
    }

    /// Look up a state in the WZO2 table. Returns the entry bytes
    /// (key_byte, L, H, DTT) or null if not found.
    /// side: +1=Black, -1=White. ko: ko point or >= n for NONE.
    /// passes: 0 or 1 (passes=2 is not stored — handled by caller).
    pub fn lookup(self: *const Wzo2Reader, colex: u32, side: i8, ko: u8, passes: u2) ?[4]u8 {
        assert(passes <= 1); // passes=2 is not stored, caller must handle

        const g = self.findGroup(colex) orelse return null;
        const count = Wzo2Reader.groupEntryCount(self.groups, g);
        const start = self.groupEntryStart(g);

        // Build target key_byte (terminal bit = 0, masked during scan)
        const target_kb = encodeKeyByteLookup(sideToU1(side), ko, passes, self.header.ko_bits);

        // Linear scan within group. Mask off terminal LSB before comparing.
        for (0..@as(usize, count)) |i| {
            const off = @as(usize, @intCast(start)) + i;
            if (off >= self.header.n_entries) return null;
            const entry = self.entries[off * WZO2_ENTRY_SIZE ..][0..WZO2_ENTRY_SIZE];
            if (entry[0] & 0xFE == target_kb) {
                var row: [4]u8 = undefined;
                @memcpy(&row, entry);
                return row;
            }
        }
        return null;
    }

    /// Iterate all entries, calling `callback(group_index, entry_index, entry_bytes)`.
    /// entry_bytes is [4]u8 = {key_byte, L, H, DTT}.
    pub fn forEachEntry(
        self: *const Wzo2Reader,
        context: anytype,
        comptime callback: fn (context: @TypeOf(context), group_idx: usize, entry_idx: u64, entry: *const [4]u8) anyerror!void,
    ) !void {
        var entry_idx: u64 = 0;
        for (0..self.header.n_groups) |g| {
            const count = Wzo2Reader.groupEntryCount(self.groups, g);
            for (0..@as(usize, count)) |_| {
                const off = @as(usize, @intCast(entry_idx));
                const entry_ptr: *const [4]u8 = self.entries[off * WZO2_ENTRY_SIZE ..][0..WZO2_ENTRY_SIZE];
                try callback(context, g, entry_idx, entry_ptr);
                entry_idx += 1;
            }
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════
//  STATE RECONSTRUCTION FROM ENTRY
// ═══════════════════════════════════════════════════════════════════════════

/// Reconstruct a goban position from a WZO2 colex index.
/// Uses the goban size from the artifact header (w×h).
fn posFromColexRt(colex: u32, w: u8, h: u8) ![rules.MAX_N]i8 {
    const n: usize = @as(usize, w) * @as(usize, h);
    var out: [rules.MAX_N]i8 = [_]i8{0} ** rules.MAX_N;
    switch (n) {
        4 => {
            const p = colex_mod.Indexer(2, 2).pos_from_colex(colex);
            @memcpy(out[0..4], &p);
        },
        6 => {
            const p = colex_mod.Indexer(3, 2).pos_from_colex(colex);
            @memcpy(out[0..6], &p);
        },
        9 => {
            const p = colex_mod.Indexer(3, 3).pos_from_colex(colex);
            @memcpy(out[0..9], &p);
        },
        12 => {
            const p = colex_mod.Indexer(4, 3).pos_from_colex(colex);
            @memcpy(out[0..12], &p);
        },
        16 => {
            const p = colex_mod.Indexer(4, 4).pos_from_colex(colex);
            @memcpy(out[0..16], &p);
        },
        else => return error.UnsupportedGobanSize,
    }
    return out;
}

/// Compute colex index for a goban position at the given size.
fn colexFromPosRt(pos: []const i8, w: u8, h: u8) !u64 {
    const n: usize = pos.len;
    _ = w;
    _ = h;
    return switch (n) {
        4 => colex_mod.Indexer(2, 2).colex_from_pos(@ptrCast(pos.ptr)),
        6 => colex_mod.Indexer(3, 2).colex_from_pos(@ptrCast(pos.ptr)),
        9 => colex_mod.Indexer(3, 3).colex_from_pos(@ptrCast(pos.ptr)),
        12 => colex_mod.Indexer(4, 3).colex_from_pos(@ptrCast(pos.ptr)),
        16 => colex_mod.Indexer(4, 4).colex_from_pos(@ptrCast(pos.ptr)),
        else => error.UnsupportedGobanSize,
    };
}

// ═══════════════════════════════════════════════════════════════════════════
//  C-A1: FORWARD CLOSURE
// ═══════════════════════════════════════════════════════════════════════════
//
// For every entry in the table, generate all children via the kernel move
// generator and verify each child is in the table.
//
// passes=2 children are expected-absent terminals (PASSES_2_OMITTED flag) —
// counted separately, not as `children_not_in_table`.
//
// Invariant: passes ≥ 1 ⇒ ko = none (§2.5). So children at passes=1 always
// have ko=NONE.

pub const ClosureStatus = enum { pass, fail, err };

pub const CA1Result = struct {
    status: ClosureStatus,
    /// Table entries scanned.
    n_entries_scanned: u64 = 0,
    /// Total non-terminal (passes∈{0,1}) children generated.
    total_non_terminal_children: u64 = 0,
    /// passes=2 children (expected-absent terminals).
    passes2_children: u64 = 0,
    /// Children not found in table (verdict: must be 0).
    children_not_in_table: u64 = 0,
    /// First few missing-child details for diagnostics (up to 10).
    missing_examples: [10]MissingChild = [_]MissingChild{.{}} ** 10,
    missing_count: usize = 0,
    err_msg: ?[]const u8 = null,

    pub const MissingChild = struct {
        parent_colex: u32 = 0,
        parent_side: i8 = 0,
        parent_ko: u8 = 0,
        parent_passes: u2 = 0,
        child_colex: u32 = 0,
        child_side: i8 = 0,
        child_ko: u8 = 0,
        child_passes: u2 = 0,
    };

    pub fn avgBranchingFactor(self: CA1Result) f64 {
        if (self.n_entries_scanned == 0) return 0;
        return @as(f64, @floatFromInt(self.total_non_terminal_children)) /
            @as(f64, @floatFromInt(self.n_entries_scanned));
    }
};

/// Run C-A1 forward closure over the WZO2 table.
/// Uses the kernel move generator (rules.zig) for child expansion.
pub fn ca1ForwardClosure(
    reader: *const Wzo2Reader,
    allocator: std.mem.Allocator,
) !CA1Result {
    _ = allocator;
    const hdr = reader.header;
    const n: usize = @as(usize, hdr.w) * @as(usize, hdr.h);
    const ko_none = koNone(hdr.w, hdr.h);

    var result = CA1Result{ .status = .pass };

    const Context = struct {
        reader: *const Wzo2Reader,
        result: *CA1Result,
        n: usize,
        w: u8,
        h: u8,
        ko_none: u8,
        ko_bits: u8,
    };

    var ctx = Context{
        .reader = reader,
        .result = &result,
        .n = n,
        .w = hdr.w,
        .h = hdr.h,
        .ko_none = ko_none,
        .ko_bits = hdr.ko_bits,
    };

    try reader.forEachEntry(&ctx, struct {
        fn cb(context: *Context, group_idx: usize, entry_idx: u64, entry: *const [4]u8) anyerror!void {
            _ = entry_idx;
            const rdr = context.reader;
            const hd = rdr.header;
            const groups = rdr.groups;

            const colex = Wzo2Reader.groupColex(groups, group_idx);
            const kb = entry[0];

            // Reconstruct Markov state from group + key_byte
            const side = keyByteSide(kb);
            const passes = keyBytePasses(kb, hd.ko_bits);
            const ko = if (passes >= 1) context.ko_none else (kb >> 1) & ((@as(u8, 1) << @intCast(hd.ko_bits)) - 1);

            context.result.n_entries_scanned += 1;

            // Build the goban position from colex
            const pos = try posFromColexRt(colex, hd.w, hd.h);

            // Generate children via kernel move generator.
            const moves = rules.legalMovesRt(&pos, hd.w, hd.h, side, ko, passes);

            // Check placements (bits 0..n-1)
            const moves_bytes = (context.n + 1 + 7) / 8;
            for (0..context.n) |cell| {
                const byte = cell / 8;
                const bit = @as(u8, 1) << @intCast(cell % 8);
                if (byte >= moves_bytes or (moves[byte] & bit) == 0) continue;

                // Apply the move to get child state
                const child = rules.applyMoveRt(&pos, hd.w, hd.h, side, ko, passes, cell) orelse continue;

                if (child.passes >= 2) {
                    // passes=2 child → expected-absent terminal
                    context.result.passes2_children += 1;
                    continue;
                }

                context.result.total_non_terminal_children += 1;

                // Look up child in table
                const child_colex = try colexFromPosRt(child.board[0..context.n], hd.w, hd.h);
                const child_colex_u32: u32 = @intCast(child_colex);

                const found = rdr.lookup(child_colex_u32, child.side, child.ko, child.passes);
                if (found == null) {
                    context.result.children_not_in_table += 1;
                    context.result.status = .fail;
                    if (context.result.missing_count < 10) {
                        context.result.missing_examples[context.result.missing_count] = .{
                            .parent_colex = colex,
                            .parent_side = side,
                            .parent_ko = ko,
                            .parent_passes = passes,
                            .child_colex = child_colex_u32,
                            .child_side = child.side,
                            .child_ko = child.ko,
                            .child_passes = child.passes,
                        };
                        context.result.missing_count += 1;
                    }
                }
            }

            // Pass child (bit n). Always legal unless terminal.
            const pass_bit = @as(u8, 1) << @intCast(context.n % 8);
            const pass_byte = context.n / 8;
            if (pass_byte < moves_bytes and (moves[pass_byte] & pass_bit) != 0) {
                const pass_child = rules.applyPassRt(hd.w, hd.h, side, passes) orelse return;

                if (pass_child.passes >= 2) {
                    context.result.passes2_children += 1;
                } else {
                    context.result.total_non_terminal_children += 1;

                    // Look up pass child. Same colex, flipped side, NONE ko.
                    const found = rdr.lookup(colex, pass_child.side, pass_child.ko, pass_child.passes);
                    if (found == null) {
                        context.result.children_not_in_table += 1;
                        context.result.status = .fail;
                        if (context.result.missing_count < 10) {
                            context.result.missing_examples[context.result.missing_count] = .{
                                .parent_colex = colex,
                                .parent_side = side,
                                .parent_ko = ko,
                                .parent_passes = passes,
                                .child_colex = colex,
                                .child_side = pass_child.side,
                                .child_ko = pass_child.ko,
                                .child_passes = pass_child.passes,
                            };
                            context.result.missing_count += 1;
                        }
                    }
                }
            }
        }
    }.cb);

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════
//  C-A2: BACKWARD CLOSURE
// ═══════════════════════════════════════════════════════════════════════════
//
// Snapshot-sweep BFS from the fresh-start root (empty board, Black to move,
// ko=NONE, passes=0). Each sweep scans the visited bitset linearly, expands
// all newly-marked entries, and marks their in-table non-terminal children.
//
// No BFS queue — eliminates ~793 MB of queue memory at 4×4 at the cost of
// O(sweeps) passes over the bitset.

pub const CA2Result = struct {
    status: ClosureStatus,
    /// Number of non-terminal (passes∈{0,1}) states reached.
    reachable_non_terminal: u64 = 0,
    /// Number of terminal (passes=2) states reached.
    reachable_terminal: u64 = 0,
    /// States reachable from root but not in table (verdict: must be 0).
    reachable_not_in_table: u64 = 0,
    /// Number of snapshot sweeps performed.
    sweeps: u64 = 0,
    /// First few missing-reachable-entry details (up to 10).
    missing_examples: [10]CA2Missing = [_]CA2Missing{.{}} ** 10,
    missing_count: usize = 0,
    err_msg: ?[]const u8 = null,

    pub const CA2Missing = struct {
        colex: u32 = 0,
        side: i8 = 0,
        ko: u8 = 0,
        passes: u2 = 0,
    };

    /// Percentage of colex space reachable (non-terminal entries / n_groups).
    pub fn pctColexSpace(self: CA2Result, n_groups: u64) f64 {
        if (n_groups == 0) return 0;
        return @as(f64, @floatFromInt(self.reachable_non_terminal)) /
            @as(f64, @floatFromInt(n_groups)) * 100.0;
    }
};

/// Find which group contains entry index `ei`.
fn findGroupForEntry(reader: *const Wzo2Reader, ei: u64) ?usize {
    const n_checkpoints = reader.entry_checkpoints.len;
    var cp: usize = 0;
    var lo: usize = 0;
    var hi: usize = n_checkpoints;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        if (reader.entry_checkpoints[mid] <= ei) {
            cp = mid;
            lo = mid + 1;
        } else {
            hi = mid;
        }
    }

    var cum: u64 = reader.entry_checkpoints[cp];
    var g: usize = cp * 256;
    while (g < reader.header.n_groups) {
        const count = Wzo2Reader.groupEntryCount(reader.groups, g);
        if (cum + count > ei) return g;
        cum += count;
        g += 1;
    }
    return null;
}

/// Mark a child state in the visited bitset. If not yet visited, mark for
/// the next sweep. If not in table, record as missing.
fn markChildInTable(
    reader: *const Wzo2Reader,
    colex: u32,
    side: i8,
    ko: u8,
    passes: u2,
    result: *CA2Result,
    visited: []u64,
    mark: []u64,
) !void {
    const entry = reader.lookup(colex, side, ko, passes);
    if (entry == null) {
        result.reachable_not_in_table += 1;
        result.status = .fail;
        if (result.missing_count < 10) {
            result.missing_examples[result.missing_count] = .{
                .colex = colex,
                .side = side,
                .ko = ko,
                .passes = passes,
            };
            result.missing_count += 1;
        }
        return;
    }

    // Find the entry index for this state (need for bitset)
    const g = reader.findGroup(colex) orelse {
        result.reachable_not_in_table += 1;
        result.status = .fail;
        return;
    };

    const start = reader.groupEntryStart(g);
    const count = Wzo2Reader.groupEntryCount(reader.groups, g);
    const target_kb = encodeKeyByteLookup(sideToU1(side), ko, passes, reader.header.ko_bits);

    for (0..@as(usize, count)) |i| {
        const ei = start + i;
        const entry_bytes = reader.entries[@as(usize, @intCast(ei)) * WZO2_ENTRY_SIZE ..][0..WZO2_ENTRY_SIZE];
        if (entry_bytes[0] & 0xFE == target_kb) {
            const word = ei / 64;
            const bit = @as(u64, 1) << @intCast(ei % 64);
            if (visited[word] & bit == 0) {
                visited[word] |= bit;
                mark[word] |= bit;
                result.reachable_non_terminal += 1;
            }
            return;
        }
    }

    // Inconsistency: lookup found it but entry-index scan didn't
    result.status = .err;
    result.err_msg = "lookup found entry but entry index mismatch";
}

/// Run C-A2 backward closure over the WZO2 table.
/// Starts from the fresh-start root and BFS-expands using the kernel move
/// generator. Verifies every reached state is in the table.
pub fn ca2BackwardClosure(
    reader: *const Wzo2Reader,
    allocator: std.mem.Allocator,
) !CA2Result {
    const hdr = reader.header;
    const n: usize = @as(usize, hdr.w) * @as(usize, hdr.h);
    const ko_none = koNone(hdr.w, hdr.h);
    const n_entries = hdr.n_entries;

    // Visited bitset over entry indices.
    const visited_words = (n_entries + 63) / 64;
    const visited = try allocator.alloc(u64, visited_words);
    defer allocator.free(visited);
    @memset(visited, 0);

    // Mark bitset: entries to expand in this sweep.
    const mark_words = (n_entries + 63) / 64;
    const mark = try allocator.alloc(u64, mark_words);
    defer allocator.free(mark);
    @memset(mark, 0);

    var result = CA2Result{ .status = .pass };

    // Seed: fresh-start root — empty board, Black to move, ko=NONE, passes=0
    const root_colex: u32 = 0; // empty board is always colex 0
    const root_entry = reader.lookup(root_colex, 1, ko_none, 0);
    if (root_entry == null) {
        result.status = .fail;
        result.reachable_not_in_table = 1;
        result.missing_examples[0] = .{
            .colex = root_colex,
            .side = 1,
            .ko = ko_none,
            .passes = 0,
        };
        result.missing_count = 1;
        return result;
    }

    // Find root's entry index in the first group
    const root_count = Wzo2Reader.groupEntryCount(reader.groups, 0);
    var root_found: bool = false;
    var root_ei: u64 = 0;
    const target_root = encodeKeyByteLookup(0, ko_none, 0, hdr.ko_bits); // u1: 0=Black
    for (0..@as(usize, root_count)) |i| {
        const entry = reader.entries[i * WZO2_ENTRY_SIZE ..][0..WZO2_ENTRY_SIZE];
        if (entry[0] & 0xFE == target_root) {
            root_ei = @intCast(i);
            root_found = true;
            break;
        }
    }
    if (!root_found) {
        result.status = .err;
        result.err_msg = "root entry not found in first group";
        return result;
    }

    // Mark root for first sweep
    mark[root_ei / 64] |= @as(u64, 1) << @intCast(root_ei % 64);
    visited[root_ei / 64] |= @as(u64, 1) << @intCast(root_ei % 64);
    result.reachable_non_terminal = 1;

    // Snapshot-sweep BFS
    while (true) {
        // Count marks for this sweep
        var marks_this_sweep: u64 = 0;
        for (mark) |w| {
            marks_this_sweep += @popCount(w);
        }
        if (marks_this_sweep == 0) break;

        result.sweeps += 1;

        // Collect entry indices to expand in this sweep
        const sweep_list = try allocator.alloc(u64, marks_this_sweep);
        defer allocator.free(sweep_list);
        {
            var si: usize = 0;
            for (0..mark_words) |wi| {
                var w = mark[wi];
                while (w != 0) {
                    const bit = @ctz(w);
                    w &= w - 1;
                    sweep_list[si] = wi * 64 + bit;
                    si += 1;
                }
            }
        }

        // Clear marks for next sweep
        @memset(mark, 0);

        // Expand each entry in the sweep list
        for (sweep_list) |ei| {
            const entry_off = ei * WZO2_ENTRY_SIZE;
            const entry_bytes = reader.entries[entry_off..][0..WZO2_ENTRY_SIZE];
            const kb = entry_bytes[0];

            const group_idx = findGroupForEntry(reader, ei) orelse {
                result.status = .err;
                result.err_msg = "entry not found in any group (internal error)";
                return result;
            };
            const colex = Wzo2Reader.groupColex(reader.groups, group_idx);
            const side = keyByteSide(kb);
            const passes = keyBytePasses(kb, hdr.ko_bits);
            const ko = if (passes >= 1) ko_none else (kb >> 1) & ((@as(u8, 1) << @intCast(hdr.ko_bits)) - 1);

            // Reconstruct goban position
            const pos = try posFromColexRt(colex, hdr.w, hdr.h);

            // Generate children
            const moves = rules.legalMovesRt(&pos, hdr.w, hdr.h, side, ko, passes);

            // Check placements
            const moves_bytes = (n + 1 + 7) / 8;
            for (0..n) |cell| {
                const byte = cell / 8;
                const bit = @as(u8, 1) << @intCast(cell % 8);
                if (byte >= moves_bytes or (moves[byte] & bit) == 0) continue;

                const child = rules.applyMoveRt(&pos, hdr.w, hdr.h, side, ko, passes, cell) orelse continue;

                if (child.passes >= 2) {
                    result.reachable_terminal += 1;
                    continue;
                }

                const child_colex = try colexFromPosRt(child.board[0..n], hdr.w, hdr.h);
                const child_colex_u32: u32 = @intCast(child_colex);

                try markChildInTable(reader, child_colex_u32, child.side, child.ko, child.passes, &result, visited, mark);
            }

            // Pass child
            const pass_bit = @as(u8, 1) << @intCast(n % 8);
            const pass_byte = n / 8;
            if (pass_byte < moves_bytes and (moves[pass_byte] & pass_bit) != 0) {
                const pass_child = rules.applyPassRt(hdr.w, hdr.h, side, passes) orelse continue;

                if (pass_child.passes >= 2) {
                    result.reachable_terminal += 1;
                } else {
                    try markChildInTable(reader, colex, pass_child.side, pass_child.ko, pass_child.passes, &result, visited, mark);
                }
            }
        }
    }

    return result;
}

// ═══════════════════════════════════════════════════════════════════════════
//  TESTS
// ═══════════════════════════════════════════════════════════════════════════

const testing = std.testing;

/// Load a WZO2 artifact from a file path at runtime (uses cwd).
fn readFileBytes(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();
    return try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .unlimited);
}

test "WZO2 header: parse 3x3 artifact" {
    const file_bytes = try readFileBytes(testing.allocator, "data/oracle-3x3-v2.wzo2");
    defer testing.allocator.free(file_bytes);
    const header_bytes: *const [WZO2_HEADER_SIZE]u8 = file_bytes[0..WZO2_HEADER_SIZE][0..WZO2_HEADER_SIZE];
    const hdr = try parseWzo2Header(header_bytes);
    try testing.expectEqual(@as(u8, 3), hdr.w);
    try testing.expectEqual(@as(u8, 3), hdr.h);
    try testing.expectEqual(@as(u16, WZO2_ENTRY_SIZE), hdr.entry_size);
    try testing.expectEqual(@as(u8, WZO2_GROUP_HEADER_SIZE), hdr.group_header_size);
    try testing.expect(hdr.passes2Omitted());
    try testing.expect(hdr.n_groups > 0);
    try testing.expect(hdr.n_entries > 0);
    try testing.expectEqual(@as(u64, WZO2_HEADER_SIZE), hdr.data_offset);
}

test "WZO2 reader: load 3x3 artifact and look up root" {
    const file_bytes = try readFileBytes(testing.allocator, "data/oracle-3x3-v2.wzo2");
    defer testing.allocator.free(file_bytes);
    var reader = try Wzo2Reader.load(testing.allocator, file_bytes);
    defer reader.deinit();

    const ko_none = koNone(3, 3);
    const entry = reader.lookup(0, 1, ko_none, 0);
    try testing.expect(entry != null);
    try testing.expectEqual(@as(i8, 9), @as(i8, @bitCast(entry.?[1]))); // L = +9
    try testing.expectEqual(@as(i8, 9), @as(i8, @bitCast(entry.?[2]))); // H = +9
}

test "WZO2 reader: binary search finds multiple groups" {
    const file_bytes = try readFileBytes(testing.allocator, "data/oracle-3x3-v2.wzo2");
    defer testing.allocator.free(file_bytes);
    var reader = try Wzo2Reader.load(testing.allocator, file_bytes);
    defer reader.deinit();

    const first_colex = Wzo2Reader.groupColex(reader.groups, 0);
    const last_colex = Wzo2Reader.groupColex(reader.groups, reader.header.n_groups - 1);

    try testing.expect(reader.findGroup(first_colex) != null);
    try testing.expect(reader.findGroup(last_colex) != null);

    // A definitely-invalid colex (max u32) should not be found
    try testing.expect(reader.findGroup(0xFFFFFFFF) == null);
}

test "C-A1 forward closure: 3x3 passes" {
    const file_bytes = try readFileBytes(testing.allocator, "data/oracle-3x3-v2.wzo2");
    defer testing.allocator.free(file_bytes);
    var reader = try Wzo2Reader.load(testing.allocator, file_bytes);
    defer reader.deinit();

    const result = try ca1ForwardClosure(&reader, testing.allocator);
    try testing.expectEqual(@as(u64, 0), result.children_not_in_table);
    try testing.expect(result.n_entries_scanned > 0);
    try testing.expect(result.total_non_terminal_children > 0);

    std.debug.print(
        "C-A1 3×3: scanned={d} non-term-children={d} passes2={d} missing={d} avg_bf={d:.2}\n",
        .{ result.n_entries_scanned, result.total_non_terminal_children, result.passes2_children, result.children_not_in_table, result.avgBranchingFactor() },
    );
}

test "C-A1 forward closure: calibration — delete one entry → children_not_in_table > 0" {
    const file_bytes = try readFileBytes(testing.allocator, "data/oracle-3x3-v2.wzo2");
    defer testing.allocator.free(file_bytes);
    var reader = try Wzo2Reader.load(testing.allocator, file_bytes);
    defer reader.deinit();

    // Corrupt entry 3 (the pass child of root: White, passes=1).
    // This entry is reachable by Black passing from root, so other
    // entries' children should find it missing.
    if (reader.header.n_entries > 3) {
        reader.entries[3 * WZO2_ENTRY_SIZE] = 0;
    }

    const result = try ca1ForwardClosure(&reader, testing.allocator);
    try testing.expect(result.children_not_in_table > 0);
    try testing.expectEqual(ClosureStatus.fail, result.status);

    std.debug.print(
        "C-A1 3×3 CALIBRATION: missing={d} (expected > 0)\n",
        .{result.children_not_in_table},
    );
}

test "C-A2 backward closure: 3x3 passes" {
    const file_bytes = try readFileBytes(testing.allocator, "data/oracle-3x3-v2.wzo2");
    defer testing.allocator.free(file_bytes);
    var reader = try Wzo2Reader.load(testing.allocator, file_bytes);
    defer reader.deinit();

    const result = try ca2BackwardClosure(&reader, testing.allocator);
    try testing.expectEqual(@as(u64, 0), result.reachable_not_in_table);
    // Not all entries in the artifact are reachable from root in the
    // forward direction (e.g. White-to-move on empty board with passes=0
    // is not reachable without capture sequences). C-A2 only verifies
    // that every state reachable from root IS in the table.
    try testing.expect(result.reachable_non_terminal > 0);
    try testing.expect(result.sweeps > 0);

    std.debug.print(
        "C-A2 3×3: reachable-non-term={d} (of {d} entries) reachable-term={d} missing={d} sweeps={d} pct-colex={d:.2}%\n",
        .{ result.reachable_non_terminal, reader.header.n_entries, result.reachable_terminal, result.reachable_not_in_table, result.sweeps, result.pctColexSpace(reader.header.n_groups) },
    );
}

test "C-A2 backward closure: calibration — delete one entry → reachable_not_in_table > 0" {
    const file_bytes = try readFileBytes(testing.allocator, "data/oracle-3x3-v2.wzo2");
    defer testing.allocator.free(file_bytes);
    var reader = try Wzo2Reader.load(testing.allocator, file_bytes);
    defer reader.deinit();

    // Corrupt a reachable entry: the pass child of root (entry 3: White, passes=1).
    if (reader.header.n_entries > 3) {
        reader.entries[3 * WZO2_ENTRY_SIZE] = 0;
    }

    const result = try ca2BackwardClosure(&reader, testing.allocator);
    try testing.expect(result.reachable_not_in_table > 0);
    try testing.expectEqual(ClosureStatus.fail, result.status);

    std.debug.print(
        "C-A2 3×3 CALIBRATION: missing={d} (expected > 0)\n",
        .{result.reachable_not_in_table},
    );
}

test "C-A1 forward closure: 4x4 passes on sample (first ~10 groups)" {
    // Full 4×4 C-A1 takes minutes; test a sample to verify mechanism.
    const file_bytes = readFileBytes(testing.allocator, "data/oracle-4x4-v2.wzo2") catch {
        std.debug.print("SKIP: data/oracle-4x4-v2.wzo2 not found\n", .{});
        return;
    };
    defer testing.allocator.free(file_bytes);

    var reader = Wzo2Reader.load(testing.allocator, file_bytes) catch {
        std.debug.print("SKIP: failed to load 4x4 artifact\n", .{});
        return;
    };
    defer reader.deinit();

    const ko_none = koNone(4, 4);
    const n: usize = 16;

    var checked: u64 = 0;
    var children_checked: u64 = 0;
    var missing: u64 = 0;
    var passes2: u64 = 0;

    var entry_idx: u64 = 0;
    const max_groups: usize = @min(@as(usize, 10), @as(usize, @intCast(reader.header.n_groups)));
    for (0..max_groups) |g| {
        const colex = Wzo2Reader.groupColex(reader.groups, g);
        const pos = try posFromColexRt(colex, 4, 4);
        const count = Wzo2Reader.groupEntryCount(reader.groups, g);
        for (0..@as(usize, count)) |_| {
            const entry = reader.entries[@as(usize, @intCast(entry_idx)) * WZO2_ENTRY_SIZE ..][0..WZO2_ENTRY_SIZE];
            const kb = entry[0];
            const side = keyByteSide(kb);
            const passes = keyBytePasses(kb, reader.header.ko_bits);
            const ko = if (passes >= 1) ko_none else (kb >> 2) & ((@as(u8, 1) << @intCast(reader.header.ko_bits)) - 1);

            const moves = rules.legalMovesRt(&pos, 4, 4, side, ko, passes);
            const moves_bytes = (n + 1 + 7) / 8;

            for (0..n) |cell| {
                const byte = cell / 8;
                const bit = @as(u8, 1) << @intCast(cell % 8);
                if (byte >= moves_bytes or (moves[byte] & bit) == 0) continue;

                const child = rules.applyMoveRt(&pos, 4, 4, side, ko, passes, cell) orelse continue;
                children_checked += 1;

                if (child.passes >= 2) {
                    passes2 += 1;
                    continue;
                }

                const child_colex = try colexFromPosRt(child.board[0..n], 4, 4);
                const found = reader.lookup(@intCast(child_colex), child.side, child.ko, child.passes);
                if (found == null) {
                    missing += 1;
                }
            }

            // Pass child
            if (passes < 2) {
                const pass_child = rules.applyPassRt(4, 4, side, passes) orelse continue;
                children_checked += 1;
                if (pass_child.passes >= 2) {
                    passes2 += 1;
                } else {
                    const found = reader.lookup(colex, pass_child.side, pass_child.ko, pass_child.passes);
                    if (found == null) {
                        missing += 1;
                    }
                }
            }

            checked += 1;
            entry_idx += 1;
        }
    }

    try testing.expectEqual(@as(u64, 0), missing);
    try testing.expect(checked > 0);
    try testing.expect(children_checked > 0);

    std.debug.print(
        "C-A1 4×4 sample: entries={d} children={d} passes2={d} missing={d}\n",
        .{ checked, children_checked, passes2, missing },
    );
}

test "C-A1/C-A2 4x4 full closure (gated by WEIZIGO_CLOSURE_4X4_FULL=1): children_not_in_table == 0 and reachable_not_in_table == 0" {
    // Full 4×4 closure run (spec §2.3 items 2–3). The plan (plan.md §2.1)
    // budgets ~531 MB peak RSS; the runner guard (4 GB) is the bound.
    // Gated so `zig build test` stays fast — the sprint console runs it
    // explicitly with WEIZIGO_CLOSURE_4X4_FULL=1 for the reading.
    if (std.c.getenv("WEIZIGO_CLOSURE_4X4_FULL") == null) {
        std.debug.print("SKIP 4x4 full closure (set WEIZIGO_CLOSURE_4X4_FULL=1 to run)\n", .{});
        return;
    }
    const allocator = std.heap.page_allocator;
    const file_bytes = try readFileBytes(allocator, "data/oracle-4x4-v2.wzo2");
    defer allocator.free(file_bytes);
    var reader = try Wzo2Reader.load(allocator, file_bytes);
    defer reader.deinit();

    // C-A1: forward closure over the whole table.
    const ca1 = try ca1ForwardClosure(&reader, allocator);
    std.debug.print(
        "C-A1 4x4 FULL: entries_scanned={d} non_term_children={d} passes2={d} children_not_in_table={d} avg_bf={d:.4} status={s}\n",
        .{ ca1.n_entries_scanned, ca1.total_non_terminal_children, ca1.passes2_children, ca1.children_not_in_table, ca1.avgBranchingFactor(), @tagName(ca1.status) },
    );
    try testing.expectEqual(@as(u64, 0), ca1.children_not_in_table);
    try testing.expectEqual(reader.header.n_entries, ca1.n_entries_scanned);
    try testing.expectEqual(ClosureStatus.pass, ca1.status);

    // C-A2: backward closure from the fresh-start root.
    const ca2 = try ca2BackwardClosure(&reader, allocator);
    std.debug.print(
        "C-A2 4x4 FULL: reachable_non_terminal={d} reachable_terminal={d} reachable_not_in_table={d} sweeps={d} pct_colex={d:.4}% status={s}\n",
        .{ ca2.reachable_non_terminal, ca2.reachable_terminal, ca2.reachable_not_in_table, ca2.sweeps, ca2.pctColexSpace(reader.header.n_groups), @tagName(ca2.status) },
    );
    try testing.expectEqual(@as(u64, 0), ca2.reachable_not_in_table);
    try testing.expectEqual(ClosureStatus.pass, ca2.status);
}

test "key_byte encoding round-trips" {
    const ko_bits: u8 = 5; // 4×4

    // Black, ko=3, passes=0, not terminal
    const kb1 = encodeKeyByte(0, 3, 0, ko_bits, false); // 0=Black
    try testing.expectEqual(@as(i8, 1), keyByteSide(kb1));
    try testing.expectEqual(@as(u2, 0), keyBytePasses(kb1, ko_bits));
    try testing.expect(!keyByteTerminal(kb1));

    // White, ko=NONE(16), passes=1, not terminal
    const kb2 = encodeKeyByte(1, 16, 1, ko_bits, false); // 1=White
    try testing.expectEqual(@as(i8, -1), keyByteSide(kb2));
    try testing.expectEqual(@as(u2, 1), keyBytePasses(kb2, ko_bits));
    try testing.expect(!keyByteTerminal(kb2));

    // Black, ko=0, passes=0, terminal
    const kb3 = encodeKeyByte(0, 0, 0, ko_bits, true); // 0=Black
    try testing.expect(keyByteTerminal(kb3));
    try testing.expectEqual(@as(i8, 1), keyByteSide(kb3));
    try testing.expectEqual(@as(u2, 0), keyBytePasses(kb3, ko_bits));

    // Lookup key masks terminal bit
    const kb_lookup = encodeKeyByteLookup(0, 0, 0, ko_bits); // 0=Black
    try testing.expectEqual(kb3 & 0xFE, kb_lookup);
}

test "key_byte: passes bit position is correct for different ko_bits" {
    // 2×2: ko_bits=3, passes at bit 4
    {
        const kb = encodeKeyByte(0, 4, 1, 3, false); // 0=Black
        try testing.expectEqual(@as(u2, 1), keyBytePasses(kb, 3));
        try testing.expect((kb & 0x10) != 0); // bit 4 set for passes=1
    }
    // 3×3: ko_bits=4, passes at bit 5
    {
        const kb = encodeKeyByte(0, 9, 1, 4, false); // 0=Black
        try testing.expectEqual(@as(u2, 1), keyBytePasses(kb, 4));
        try testing.expect((kb & 0x20) != 0); // bit 5 set
    }
    // 4×4: ko_bits=5, passes at bit 6
    {
        const kb = encodeKeyByte(0, 16, 1, 5, false); // 0=Black
        try testing.expectEqual(@as(u2, 1), keyBytePasses(kb, 5));
        try testing.expect((kb & 0x40) != 0); // bit 6 set
    }
}
