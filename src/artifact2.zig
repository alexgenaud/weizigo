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
// WZO2 ARTIFACT FORMAT (oracle-v2 M1 design, frozen at G2).
//
// Task: T165 (M2b) · Role: worker · Model: DSPro · Date: 2026-07-31
//
// The WZO2 artifact stores the oracle's value table for the full Markov key
// (goban, side, ko_point, passes) with L and H stored separately per spec
// R2, DTT computed per R3 (§3.1 of design-M1.md), and a self-describing
// header per R4.
//
// Format: grouped inline, segregated layout. Entries sorted by
// (colex_index, passes, ko_point, side) and grouped by goban. Three regions:
//   Header      128 bytes     self-describing metadata
//   Group index n_groups × 5  colex (u32 LE) + entry_count (u8)
//   Entry data  n_entries × 4 key_byte | L | H | DTT
//
// file_size = 128 + n_groups × 5 + n_entries × 4

const std = @import("std");
const Allocator = std.mem.Allocator;
const Sha256 = std.crypto.hash.sha2.Sha256;

pub const MAGIC = [4]u8{ 'W', 'Z', 'O', '2' };
pub const FORMAT_VERSION: u16 = 1;
pub const RULES_BASICKO_LH_AREA: u8 = 3; // Chinese area, komi 0, basic ko, L/H bracket
pub const ENTRY_SIZE: u16 = 4;
pub const GROUP_HEADER_SIZE: u8 = 5;
pub const HEADER_LEN: usize = 128;
pub const HASH_OFFSET: usize = 40;
pub const HASH_LEN: usize = 32;
pub const DTT_FAR: u8 = 255;

/// Header flags bits
pub const HDR_FLAG_PASSES_2_OMITTED: u8 = 1; // bit 0

// =========================================================================
// Key byte encoding (§2.2)
// =========================================================================

/// Encode (side, ko_point, passes, terminal) into a single key byte.
/// Bit layout (MSB→LSB): [passes:1][ko_point:KO_BITS][side:1][terminal:1]
/// Unused MSBs are zero.
pub fn encodeKeyByte(side: u1, ko: u8, passes: u1, terminal: u1, ko_bits: u8) u8 {
    // side=0=Black, side=1=White
    var kb: u8 = terminal; // bit 0
    kb |= @as(u8, side) << 1; // bit 1
    kb |= ko << 2; // bits 2..(2+ko_bits-1)
    kb |= @as(u8, passes) << @intCast(2 + ko_bits); // bit (2+ko_bits)
    return kb;
}

/// Decode the fields from a key byte.
pub fn decodeKeyByte(kb: u8, ko_bits: u8) struct { side: u1, ko: u8, passes: u1, terminal: u1 } {
    const terminal: u1 = @intCast(kb & 1);
    const side: u1 = @intCast((kb >> 1) & 1);
    const ko_mask: u8 = (@as(u8, 1) << @intCast(ko_bits)) - 1;
    const ko: u8 = (kb >> 2) & ko_mask;
    const passes: u1 = @intCast((kb >> @intCast(2 + ko_bits)) & 1);
    return .{ .side = side, .ko = ko, .passes = passes, .terminal = terminal };
}

/// Key byte with terminal bit masked off, for lookup comparison.
pub fn keyByteLookup(kb: u8) u8 {
    return kb & 0xFE;
}

// =========================================================================
// Header (§4)
// =========================================================================

pub const Header = struct {
    w: u8,
    h: u8,
    ko_bits: u8,
    n_groups: u64,
    n_entries: u64,
    sha256: [HASH_LEN]u8,
};

/// Write the header into a 128-byte buffer, with the SHA-256 slot zeroed.
/// The caller writes the SHA-256 later with writeHeaderHash.
pub fn writeHeader(buf: *[HEADER_LEN]u8, hdr: Header) void {
    @memset(buf, 0);
    @memcpy(buf[0..4], &MAGIC);
    std.mem.writeInt(u16, buf[4..6], FORMAT_VERSION, .little);
    buf[6] = hdr.w;
    buf[7] = hdr.h;
    std.mem.writeInt(u16, buf[8..10], RULES_BASICKO_LH_AREA, .little);
    std.mem.writeInt(u16, buf[10..12], ENTRY_SIZE, .little);
    buf[12] = GROUP_HEADER_SIZE;
    buf[13] = hdr.ko_bits;
    buf[14] = HDR_FLAG_PASSES_2_OMITTED; // passes=2 not stored by contract
    buf[15] = 0; // reserved0
    std.mem.writeInt(u64, buf[16..24], hdr.n_groups, .little);
    std.mem.writeInt(u64, buf[24..32], hdr.n_entries, .little);
    std.mem.writeInt(u64, buf[32..40], HEADER_LEN, .little); // data_offset
    // bytes 40..72: sha256 slot (left zero, caller fills with writeHeaderHash)
    // bytes 72..128: reserved1 (zero)
}

/// Write the SHA-256 digest into the header's hash slot.
pub fn writeHeaderHash(buf: *[HEADER_LEN]u8, digest: [HASH_LEN]u8) void {
    @memcpy(buf[HASH_OFFSET .. HASH_OFFSET + HASH_LEN], &digest);
}

// =========================================================================
// Group index + entry data (§2, §2.4)
// =========================================================================

/// A single group header: colex index (u32 LE) + entry count (u8).
pub const GroupHeader = struct {
    colex: u32,
    entry_count: u8,
};

/// Write a group header into buf (5 bytes: colex u32 LE + entry_count u8).
pub fn writeGroupHeader(buf: *[5]u8, gh: GroupHeader) void {
    std.mem.writeInt(u32, buf[0..4], gh.colex, .little);
    buf[4] = gh.entry_count;
}

/// A single entry row: key_byte | L (i8) | H (i8) | DTT (u8).
pub const EntryRow = struct {
    key_byte: u8,
    L: i8,
    H: i8,
    DTT: u8,
};

/// Write an entry row into buf (4 bytes).
pub fn writeEntryRow(buf: *[4]u8, row: EntryRow) void {
    buf[0] = row.key_byte;
    buf[1] = @bitCast(row.L);
    buf[2] = @bitCast(row.H);
    buf[3] = row.DTT;
}

/// Read an entry row from buf (4 bytes).
pub fn readEntryRow(buf: *const [4]u8) EntryRow {
    return EntryRow{
        .key_byte = buf[0],
        .L = @bitCast(buf[1]),
        .H = @bitCast(buf[2]),
        .DTT = buf[3],
    };
}

// =========================================================================
// Full-file encode (§4.2)
// =========================================================================

/// The complete artifact data to be written.
pub const Artifact = struct {
    header: Header,
    group_headers: []const GroupHeader, // sorted by colex
    entry_rows: []const EntryRow, // sorted per §2.4 within each group

    /// Compute total file size.
    pub fn fileSize(self: Artifact) usize {
        return HEADER_LEN + self.group_headers.len * GROUP_HEADER_SIZE + self.entry_rows.len * ENTRY_SIZE;
    }
};

/// Build the full file bytes (with SHA-256 slot zeroed initially, then
/// recomputed after writing). The caller writes the hash slot with
/// writeHeaderHash after computing the digest.
pub fn buildFile(gpa: Allocator, art: *const Artifact) ![]u8 {
    const size = art.fileSize();
    const buf = try gpa.alloc(u8, size);
    errdefer gpa.free(buf);
    @memset(buf, 0);

    // Header
    var hdr_buf: [HEADER_LEN]u8 = undefined;
    writeHeader(&hdr_buf, art.header);
    @memcpy(buf[0..HEADER_LEN], &hdr_buf);

    // Group index
    var group_off: usize = HEADER_LEN;
    for (art.group_headers) |gh| {
        var gb: [5]u8 = undefined;
        writeGroupHeader(&gb, gh);
        @memcpy(buf[group_off .. group_off + 5], &gb);
        group_off += 5;
    }

    // Entry data
    var entry_off: usize = group_off;
    for (art.entry_rows) |row| {
        var eb: [4]u8 = undefined;
        writeEntryRow(&eb, row);
        @memcpy(buf[entry_off .. entry_off + 4], &eb);
        entry_off += 4;
    }

    // Compute SHA-256 of entire file (with hash slot still zero)
    var hasher = Sha256.init(.{});
    hasher.update(buf);
    const digest = hasher.finalResult();

    // Write digest into the header slot
    writeHeaderHash(buf[0..HEADER_LEN], digest);

    return buf;
}

// =========================================================================
// Validation on load (§4.3)
// =========================================================================

pub const LoadError = error{
    BadMagic,
    BadVersion,
    BadGobanSize,
    BadEntrySize,
    BadGroupHeaderSize,
    BadKoBits,
    BadPasses2Flag,
    BadFileSize,
    BadRulesId,
    BadChecksum,
    Truncated,
};

/// Parse the header from the first 128 bytes. Does NOT verify SHA-256
/// (caller opts in with --verify-hash). Does verify magic, version,
/// structural fields and file size.
pub fn validateHeader(raw_header: *const [HEADER_LEN]u8, file_size: usize, w: u8, h: u8) LoadError!Header {
    if (!std.mem.eql(u8, raw_header[0..4], &MAGIC)) return LoadError.BadMagic;
    const version = std.mem.readInt(u16, raw_header[4..6], .little);
    if (version != FORMAT_VERSION) return LoadError.BadVersion;
    const hdr_w = raw_header[6];
    const hdr_h = raw_header[7];
    if (hdr_w != w or hdr_h != h) return LoadError.BadGobanSize;
    const rules_id = std.mem.readInt(u16, raw_header[8..10], .little);
    if (@as(u8, @intCast(rules_id & 0xFF)) != RULES_BASICKO_LH_AREA) return LoadError.BadRulesId;
    const entry_size = std.mem.readInt(u16, raw_header[10..12], .little);
    if (entry_size != ENTRY_SIZE) return LoadError.BadEntrySize;
    const gh_size = raw_header[12];
    if (gh_size != GROUP_HEADER_SIZE) return LoadError.BadGroupHeaderSize;
    const n_cells = @as(u16, w) * @as(u16, h);
    const ko_bits = raw_header[13];
    {
        const expected = koBits(@intCast(n_cells));
        if (ko_bits != expected) return LoadError.BadKoBits;
    }
    const hdr_flags = raw_header[14];
    if (hdr_flags & HDR_FLAG_PASSES_2_OMITTED == 0) return LoadError.BadPasses2Flag;
    const data_offset = std.mem.readInt(u64, raw_header[32..40], .little);
    if (data_offset != HEADER_LEN) return LoadError.BadVersion;
    const n_groups = std.mem.readInt(u64, raw_header[16..24], .little);
    const n_entries = std.mem.readInt(u64, raw_header[24..32], .little);
    const expected_size = data_offset + n_groups * GROUP_HEADER_SIZE + n_entries * ENTRY_SIZE;
    if (file_size != expected_size) return LoadError.BadFileSize;

    return Header{
        .w = hdr_w,
        .h = hdr_h,
        .ko_bits = ko_bits,
        .n_groups = n_groups,
        .n_entries = n_entries,
        .sha256 = raw_header[HASH_OFFSET .. HASH_OFFSET + HASH_LEN][0..HASH_LEN].*,
    };
}

/// Verify SHA-256 of the full file. Expensive over ~500 MB; use
/// --verify-hash (not mandatory on every load per design-M1 §4.2).
pub fn verifyHash(file_bytes: []const u8) LoadError!void {
    if (file_bytes.len < HEADER_LEN) return LoadError.Truncated;
    // Hash with the slot zeroed
    var hasher = Sha256.init(.{});
    hasher.update(file_bytes[0..HASH_OFFSET]);
    // zero bytes for hash slot
    const zero: [HASH_LEN]u8 = [_]u8{0} ** HASH_LEN;
    hasher.update(&zero);
    hasher.update(file_bytes[HASH_OFFSET + HASH_LEN ..]);
    const digest = hasher.finalResult();
    const stored = file_bytes[HASH_OFFSET .. HASH_OFFSET + HASH_LEN];
    if (!std.mem.eql(u8, &digest, stored)) return LoadError.BadChecksum;
}

// =========================================================================
// Helpers for M2b/M3
// =========================================================================

/// ceil(log2(n+1)) for the ko point field. `n_cells` = w·h.
pub fn koBits(n_cells: u8) u8 {
    var ko_vals: u16 = @as(u16, n_cells) + 1;
    var bits: u8 = 0;
    while (ko_vals > 1) : (ko_vals = (ko_vals + 1) >> 1) {
        bits += 1;
    }
    if (bits == 0) bits = 1;
    return bits;
}

/// Maximum entries per group (§2.4): 2 sides × (n+1 ko values) at passes=0
/// plus 2 sides × 1 ko value at passes=1 = 2 × (n+2), where n = w·h.
pub fn maxEntriesPerGroup(w: u8, h: u8) u8 {
    const n: u8 = w * h;
    return 2 * (n + 2);
}

/// Human-readable rules name for a rules_id.
pub fn rulesName(rules_id: u16) []const u8 {
    return switch (rules_id) {
        RULES_BASICKO_LH_AREA => "Chinese area, komi 0, basic ko, L/H bracket",
        else => "unknown",
    };
}

// =========================================================================
// Reader / lookup (M3) — engine-side artifact consumption
// =========================================================================

/// Decoded lookup result for a state.
pub const Row = struct {
    L: i8,
    H: i8,
    DTT: u8,
    terminal: bool,
    ko_sensitive: bool, // derived: L != H
};

/// Convert engine-side convention (1=Black, -1=White) to key-byte u1 (0=Black, 1=White).
pub fn sideToU1(side: i8) u1 {
    return if (side > 0) @as(u1, 0) else @as(u1, 1);
}

/// Convert key-byte u1 (0=Black, 1=White) to engine-side i8 (1=Black, -1=White).
pub fn u1ToSide(s: u1) i8 {
    return if (s == 0) @as(i8, 1) else @as(i8, -1);
}

/// KO_NONE value for a given goban: the cell count (n), meaning "no ko point."
pub fn koNone(w: u8, h: u8) u8 {
    return w * h;
}

/// Sparse prefix-sum stride: store cumulative entry index every N groups.
pub const CHECKPOINT_STRIDE: usize = 256;

/// A loaded, validated WZO2 artifact ready for interactive lookup.
/// The entire file is kept in memory (mmap-friendly via page allocator).
pub const LoadedArtifact = struct {
    gpa: Allocator,
    data: []const u8, // full file bytes
    header: Header,
    group_base: usize, // byte offset to group index (= HEADER_LEN)
    entry_base: usize, // byte offset to first entry
    entry_checkpoints: []u64, // sparse prefix sum, allocated

    pub fn deinit(a: *LoadedArtifact) void {
        a.gpa.free(a.entry_checkpoints);
        a.gpa.free(a.data);
    }
};

/// Load and validate a WZO2 artifact from disk for interactive lookup.
/// Reads the entire file into memory. Caller owns the returned LoadedArtifact;
/// call `deinit` to free. Goban dimensions are read from the header.
pub fn load(io: std.Io, dir: std.Io.Dir, sub_path: []const u8, gpa: Allocator) !LoadedArtifact {
    const data = try dir.readFileAlloc(io, sub_path, gpa, .unlimited);
    errdefer gpa.free(data);

    if (data.len < HEADER_LEN) return LoadError.Truncated;

    const raw_header = data[0..HEADER_LEN];
    var raw_hdr: [HEADER_LEN]u8 = undefined;
    @memcpy(&raw_hdr, raw_header);

    // Read goban dimensions from header before validation
    const w = raw_hdr[6];
    const h = raw_hdr[7];
    const header = try validateHeader(&raw_hdr, data.len, w, h);

    const G: usize = @intCast(header.n_groups);
    const group_base: usize = HEADER_LEN;
    const entry_base: usize = HEADER_LEN + G * GROUP_HEADER_SIZE;

    // Validate group index and build sparse prefix sum
    const n_checkpoints = (G + CHECKPOINT_STRIDE - 1) / CHECKPOINT_STRIDE;
    const checkpoints = try gpa.alloc(u64, n_checkpoints);
    errdefer gpa.free(checkpoints);

    var cum: u64 = 0;
    var prev_colex: u32 = 0;
    var group_idx: usize = 0;
    while (group_idx < G) : (group_idx += 1) {
        const off = group_base + group_idx * GROUP_HEADER_SIZE;
        const colex_val = std.mem.readInt(u32, data[off..][0..4], .little);
        const count = data[off + 4];

        // Group order: strictly increasing colex
        if (group_idx > 0 and colex_val <= prev_colex) return LoadError.BadFileSize;
        prev_colex = colex_val;

        // Entry count bound (§2.4)
        if (count > maxEntriesPerGroup(w, h)) return LoadError.BadFileSize;

        if (group_idx % CHECKPOINT_STRIDE == 0) {
            checkpoints[group_idx / CHECKPOINT_STRIDE] = cum;
        }
        cum += count;
    }

    // Verify cumulative entry count matches header
    if (cum != header.n_entries) return LoadError.BadFileSize;

    return LoadedArtifact{
        .gpa = gpa,
        .data = data,
        .header = header,
        .group_base = group_base,
        .entry_base = entry_base,
        .entry_checkpoints = checkpoints,
    };
}

/// Look up a state in the artifact by full Markov key.
/// Returns null if the state is not in the artifact (should not happen for
/// reachable states under the artifact's rules_id).
pub fn lookup(a: *const LoadedArtifact, colex: u32, side: i8, ko: u8, passes: u2) ?Row {
    const G: usize = @intCast(a.header.n_groups);
    const groups = a.data[a.group_base .. a.group_base + G * GROUP_HEADER_SIZE];

    // Binary search on colex
    var lo: usize = 0;
    var hi: usize = G;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        const mid_colex = std.mem.readInt(u32, groups[mid * GROUP_HEADER_SIZE ..][0..4], .little);
        if (mid_colex < colex) {
            lo = mid + 1;
        } else if (mid_colex > colex) {
            hi = mid;
        } else {
            lo = mid;
            break;
        }
    }

    if (lo >= G) return null;
    const grp_colex = std.mem.readInt(u32, groups[lo * GROUP_HEADER_SIZE ..][0..4], .little);
    if (grp_colex != colex) return null;

    const count: usize = groups[lo * GROUP_HEADER_SIZE + 4];
    if (count == 0) return null;

    // Build target key_byte (terminal bit = 0 for lookup; masked off during scan)
    const target_kb = encodeKeyByte(sideToU1(side), ko, @intCast(passes), 0, a.header.ko_bits);

    // Sparse prefix sum: compute entry offset
    const checkpoint_idx = lo / CHECKPOINT_STRIDE;
    var entry_offset: usize = @intCast(a.entry_checkpoints[checkpoint_idx]);
    const start_group = checkpoint_idx * CHECKPOINT_STRIDE;
    for (start_group..lo) |g| {
        entry_offset += groups[g * GROUP_HEADER_SIZE + 4];
    }

    // Linear scan within group
    const entries = a.data[a.entry_base..];
    for (0..count) |i| {
        const entry = entries[(entry_offset + i) * ENTRY_SIZE ..][0..ENTRY_SIZE];
        // Mask off terminal LSB before comparing keys
        if (keyByteLookup(entry[0]) == target_kb) {
            return Row{
                .L = @bitCast(entry[1]),
                .H = @bitCast(entry[2]),
                .DTT = entry[3],
                .terminal = (entry[0] & 1) != 0,
                .ko_sensitive = (entry[1] != entry[2]),
            };
        }
    }
    return null;
}

// =========================================================================
// Tests
// =========================================================================

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

test "key byte encode/decode round-trip" {
    const ko_bits: u8 = 5; // 4×4
    // Test all combinations of side, ko, passes (terminal=0 for now)
    const test_cases = [_]struct { side: u1, ko: u8, passes: u1 }{
        .{ .side = 0, .ko = 0, .passes = 0 },
        .{ .side = 1, .ko = 0, .passes = 0 },
        .{ .side = 0, .ko = 16, .passes = 0 }, // KO_NONE4
        .{ .side = 1, .ko = 16, .passes = 0 },
        .{ .side = 0, .ko = 0, .passes = 1 },
        .{ .side = 1, .ko = 0, .passes = 1 },
        .{ .side = 0, .ko = 5, .passes = 0 },
        .{ .side = 1, .ko = 5, .passes = 0 },
    };
    for (test_cases) |tc| {
        const kb = encodeKeyByte(tc.side, tc.ko, tc.passes, 0, ko_bits);
        const dec = decodeKeyByte(kb, ko_bits);
        try expectEqual(tc.side, dec.side);
        try expectEqual(tc.ko, dec.ko);
        try expectEqual(tc.passes, dec.passes);
        try expectEqual(@as(u1, 0), dec.terminal);
    }
}

test "key byte terminal flag" {
    const ko_bits: u8 = 5;
    const kb = encodeKeyByte(0, 0, 0, 1, ko_bits);
    const dec = decodeKeyByte(kb, ko_bits);
    try expectEqual(@as(u1, 1), dec.terminal);
    // keyByteLookup masks off terminal
    try expectEqual(encodeKeyByte(0, 0, 0, 0, ko_bits), keyByteLookup(kb));
}

test "key byte unused MSBs are zero" {
    const ko_bits: u8 = 3; // 3×2: 7 ko values, 3 bits
    const kb = encodeKeyByte(1, 6, 1, 0, ko_bits);
    // With 3 ko bits: layout [passes:1][ko:3][side:1][terminal:1] = 6 bits
    // Bits 6-7 should be zero
    try expect(kb & 0xC0 == 0);
}

test "koBits" {
    try expectEqual(@as(u8, 3), koBits(4)); // 2×2: 5 values need 3 bits
    try expectEqual(@as(u8, 3), koBits(6)); // 3×2: 7 values need 3 bits
    try expectEqual(@as(u8, 4), koBits(9)); // 3×3: 10 values need 4 bits
    try expectEqual(@as(u8, 4), koBits(12)); // 4×3: 13 values need 4 bits
    try expectEqual(@as(u8, 5), koBits(16)); // 4×4: 17 values need 5 bits
}

test "maxEntriesPerGroup" {
    try expectEqual(@as(u8, 2 * (4 + 2)), maxEntriesPerGroup(2, 2)); // 12
    try expectEqual(@as(u8, 2 * (6 + 2)), maxEntriesPerGroup(3, 2)); // 16
    try expectEqual(@as(u8, 2 * (9 + 2)), maxEntriesPerGroup(3, 3)); // 22
    try expectEqual(@as(u8, 2 * (16 + 2)), maxEntriesPerGroup(4, 4)); // 36
}

test "header round-trip" {
    const hdr = Header{
        .w = 4,
        .h = 4,
        .ko_bits = 5,
        .n_groups = 100,
        .n_entries = 1000,
        .sha256 = [_]u8{0} ** HASH_LEN,
    };
    var buf: [HEADER_LEN]u8 = undefined;
    writeHeader(&buf, hdr);
    const parsed = try validateHeader(&buf, HEADER_LEN + 100 * 5 + 1000 * 4, 4, 4);
    try expectEqual(hdr.w, parsed.w);
    try expectEqual(hdr.h, parsed.h);
    try expectEqual(hdr.ko_bits, parsed.ko_bits);
    try expectEqual(hdr.n_groups, parsed.n_groups);
    try expectEqual(hdr.n_entries, parsed.n_entries);
}

test "validateHeader rejects bad magic" {
    var buf: [HEADER_LEN]u8 = [_]u8{0} ** HEADER_LEN;
    buf[0] = 'X';
    try std.testing.expectError(LoadError.BadMagic, validateHeader(&buf, 0, 4, 4));
}

test "validateHeader rejects version != 1" {
    var buf: [HEADER_LEN]u8 = [_]u8{0} ** HEADER_LEN;
    @memcpy(buf[0..4], &MAGIC);
    std.mem.writeInt(u16, buf[4..6], @as(u16, 2), .little);
    try std.testing.expectError(LoadError.BadVersion, validateHeader(&buf, 0, 4, 4));
}

test "full file build + hash verify" {
    const gpa = std.testing.allocator;

    const w: u8 = 2;
    const h: u8 = 2;
    const kb = koBits(w * h);

    const groups = [_]GroupHeader{
        .{ .colex = 0, .entry_count = 2 },
        .{ .colex = 10, .entry_count = 3 },
    };

    const entries = [_]EntryRow{
        .{ .key_byte = encodeKeyByte(0, 4, 0, 0, kb), .L = 0, .H = 0, .DTT = 5 },
        .{ .key_byte = encodeKeyByte(1, 4, 0, 0, kb), .L = 0, .H = 0, .DTT = 5 },
        .{ .key_byte = encodeKeyByte(0, 4, 0, 0, kb), .L = 1, .H = 1, .DTT = 3 },
        .{ .key_byte = encodeKeyByte(1, 4, 0, 0, kb), .L = -1, .H = -1, .DTT = 3 },
        .{ .key_byte = encodeKeyByte(0, 4, 0, 1, kb), .L = 2, .H = 3, .DTT = 1 },
    };

    const art = Artifact{
        .header = Header{
            .w = w,
            .h = h,
            .ko_bits = kb,
            .n_groups = groups.len,
            .n_entries = entries.len,
            .sha256 = [_]u8{0} ** HASH_LEN,
        },
        .group_headers = &groups,
        .entry_rows = &entries,
    };

    const file_bytes = try buildFile(gpa, &art);
    defer gpa.free(file_bytes);

    const expected_size = HEADER_LEN + groups.len * 5 + entries.len * 4;
    try expectEqual(expected_size, file_bytes.len);

    // Verify hash
    try verifyHash(file_bytes);

    // Corrupt one byte and check hash fails
    var corrupted = try gpa.dupe(u8, file_bytes);
    defer gpa.free(corrupted);
    corrupted[HEADER_LEN + groups.len * 5 + 2] ^= 0x01; // flip a bit in entries
    try std.testing.expectError(LoadError.BadChecksum, verifyHash(corrupted));
}

test "lookup: binary search + linear scan on synthetic 2x2 artifact" {
    // Build a synthetic artifact with known data, then look up entries.
    const gpa = std.testing.allocator;

    const w: u8 = 2;
    const h: u8 = 2;
    const kb = koBits(w * h);
    const none = koNone(w, h); // 4

    // Two groups, three colex values, non-trivial entry ordering
    const groups = [_]GroupHeader{
        .{ .colex = 0, .entry_count = 3 },
        .{ .colex = 27, .entry_count = 2 }, // gap in colex to test binary search
        .{ .colex = 80, .entry_count = 1 },
    };

    const entries = [_]EntryRow{
        // Group 0 (colex=0): Black ko=none passes=0; White ko=none passes=0; Black ko=1 passes=0
        .{ .key_byte = encodeKeyByte(0, none, 0, 0, kb), .L = -1, .H = 3, .DTT = 10 },
        .{ .key_byte = encodeKeyByte(1, none, 0, 0, kb), .L = -3, .H = 1, .DTT = 10 },
        .{ .key_byte = encodeKeyByte(0, 1, 0, 0, kb), .L = 2, .H = 2, .DTT = 8 },
        // Group 27 (colex=27): Black ko=none passes=0; Black ko=none passes=1
        .{ .key_byte = encodeKeyByte(0, none, 0, 0, kb), .L = 4, .H = 4, .DTT = 3 },
        .{ .key_byte = encodeKeyByte(0, none, 1, 0, kb), .L = 2, .H = 2, .DTT = 1 },
        // Group 80 (colex=80): White ko=none passes=0
        .{ .key_byte = encodeKeyByte(1, none, 0, 0, kb), .L = -2, .H = -2, .DTT = 1 },
    };

    const art = Artifact{
        .header = Header{
            .w = w, .h = h, .ko_bits = kb,
            .n_groups = groups.len, .n_entries = entries.len,
            .sha256 = [_]u8{0} ** HASH_LEN,
        },
        .group_headers = &groups,
        .entry_rows = &entries,
    };

    const file_bytes = try buildFile(gpa, &art);
    defer gpa.free(file_bytes);

    // Validate and build lookup structures directly from bytes (exercises
    // the same logic as load() without temp files).
    var raw_hdr: [HEADER_LEN]u8 = undefined;
    @memcpy(&raw_hdr, file_bytes[0..HEADER_LEN]);
    const header = try validateHeader(&raw_hdr, file_bytes.len, w, h);
    try expectEqual(@as(u64, groups.len), header.n_groups);
    try expectEqual(@as(u64, entries.len), header.n_entries);

    const G: usize = @intCast(header.n_groups);
    const n_checkpoints = (G + CHECKPOINT_STRIDE - 1) / CHECKPOINT_STRIDE;
    const checkpoints = try gpa.alloc(u64, n_checkpoints);
    defer gpa.free(checkpoints);

    // Build prefix sum checkpoints
    var cum: u64 = 0;
    for (0..G) |gi| {
        const off = HEADER_LEN + gi * GROUP_HEADER_SIZE;
        const count = file_bytes[off + 4];
        if (gi % CHECKPOINT_STRIDE == 0) checkpoints[gi / CHECKPOINT_STRIDE] = cum;
        cum += count;
    }
    try expectEqual(header.n_entries, cum);

    const loaded = LoadedArtifact{
        .gpa = gpa,
        .data = file_bytes,
        .header = header,
        .group_base = HEADER_LEN,
        .entry_base = HEADER_LEN + G * GROUP_HEADER_SIZE,
        .entry_checkpoints = checkpoints,
    };

    // Look up: colex=0, Black, ko=none, passes=0
    {
        const row = lookup(&loaded, 0, 1, none, 0).?;
        try expectEqual(@as(i8, -1), row.L);
        try expectEqual(@as(i8, 3), row.H);
        try expectEqual(@as(u8, 10), row.DTT);
        try expect(!row.terminal);
        try expect(row.ko_sensitive);
    }

    // Look up: colex=0, White, ko=none, passes=0
    {
        const row = lookup(&loaded, 0, -1, none, 0).?;
        try expectEqual(@as(i8, -3), row.L);
        try expectEqual(@as(i8, 1), row.H);
    }

    // Look up: colex=0, Black, ko=1, passes=0
    {
        const row = lookup(&loaded, 0, 1, 1, 0).?;
        try expectEqual(@as(i8, 2), row.L);
        try expectEqual(@as(i8, 2), row.H);
        try expect(!row.ko_sensitive);
    }

    // Look up: colex=27, Black, ko=none, passes=0
    {
        const row = lookup(&loaded, 27, 1, none, 0).?;
        try expectEqual(@as(i8, 4), row.L);
        try expectEqual(@as(i8, 4), row.H);
        try expectEqual(@as(u8, 3), row.DTT);
    }

    // Look up: colex=27, Black, ko=none, passes=1
    {
        const row = lookup(&loaded, 27, 1, none, 1).?;
        try expectEqual(@as(i8, 2), row.L);
        try expectEqual(@as(i8, 2), row.H);
    }

    // Look up: colex=80, White, ko=none, passes=0
    {
        const row = lookup(&loaded, 80, -1, none, 0).?;
        try expectEqual(@as(i8, -2), row.L);
        try expectEqual(@as(i8, -2), row.H);
        try expect(!row.ko_sensitive);
    }

    // Missing: colex=5 (not in any group) → null
    try expect(lookup(&loaded, 5, 1, none, 0) == null);

    // Missing: colex=0, Black, ko=2, passes=0 (not in group) → null
    try expect(lookup(&loaded, 0, 1, 2, 0) == null);
}

test "sideToU1 / u1ToSide round-trip" {
    try expectEqual(@as(u1, 0), sideToU1(1)); // Black → 0
    try expectEqual(@as(u1, 1), sideToU1(-1)); // White → 1
    try expectEqual(@as(i8, 1), u1ToSide(0));
    try expectEqual(@as(i8, -1), u1ToSide(1));
}
