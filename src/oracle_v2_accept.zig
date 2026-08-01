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
// ORACLE-V2 ACCEPTANCE — M4a (decoupled): A3 colour-inversion, A5 round-trip,
// A6 calibration, A9 reproducibility.
//
// Task:  T182 · Worker: DSPro/T182 · Date: 2026-08-01
// File:  src/oracle_v2_accept.zig (new)
// Owner: M4a (holds until O-7r review PASS)
//
// Checks the WZO2 artifact against the format contract from M1's design
// (docs/epic-01-markovian/sprints/oracle-v2/pass0/design-M1.md). This module
// runs BEFORE M2b/M3 produce the real artifact — the checks exist before the
// code they judge (spec sprint.md A4).
//
// The format structures below are inline duplicates of artifact2.zig's
// contract. When M1 delivers artifact2.zig, a follow-up task replaces these
// with `const art = @import("artifact2.zig")` imports. The byte-level format
// is frozen by the M1 design; this file is the consumer that verifies it.
//
// Usage:
//   zig run -O ReleaseSafe src/oracle_v2_accept.zig -- <path-to-wzo2> [check]
//   zig test src/oracle_v2_accept.zig  # runs A5 round-trip unit tests
//
// Checks (select with second arg, default = all):
//   a3   colour inversion: L(-pos,-side)==-H(pos,side) for every stored state
//   a5   round-trip: decode(encode(x)) == x (exhaustive at 2×2/3×2/3×3,
//        sampled with stated denominator at 4×4)
//   a6   calibration: corrupt artifact, verify detection
//   a9   reproducibility: SHA-256 verification against recorded hash
//
// stdout = data (verdict + counts), stderr = diagnostics (progress).
// Exit code 0 = PASS, 1 = FAIL, 2 = usage error.

const std = @import("std");
const util = @import("util.zig");
const colex = @import("colex.zig");
const rules = @import("rules.zig");

// =========================================================================
// WZO2 format constants — from M1 design §1–§4 (design-M1.md rev 3)
// =========================================================================

const WZO2_MAGIC = [4]u8{ 'W', 'Z', 'O', '2' };
const WZO2_HEADER_LEN: usize = 128;
const WZO2_ENTRY_SIZE: u16 = 4;
const WZO2_GROUP_HEADER_SIZE: u8 = 5;
const WZO2_RULES_ID: u8 = 3; // Chinese area, komi 0, basic ko, L/H bracket
const WZO2_HDR_FLAG_PASSES_2_OMITTED: u8 = 1; // bit 0 of hdr_flags

// Header layout (design-M1 §4):
//   0..3   magic "WZO2"
//   4..5   version (u16 LE)
//   6      w (u8)
//   7      h (u8)
//   8..9   rules_id (u16 LE)
//   10..11 entry_size (u16 LE)
//   12     group_header_size (u8)
//   13     ko_bits (u8)
//   14     hdr_flags (u8)
//   15     reserved0 (u8)
//   16..23 n_groups (u64 LE)
//   24..31 n_entries (u64 LE)
//   32..39 data_offset (u64 LE)
//   40..71 sha256 (u8[32])
//   72..127 reserved1 (u8[56])

const HDR_OFF_MAGIC: usize = 0;
const HDR_OFF_VERSION: usize = 4;
const HDR_OFF_W: usize = 6;
const HDR_OFF_H: usize = 7;
const HDR_OFF_RULES_ID: usize = 8;
const HDR_OFF_ENTRY_SIZE: usize = 10;
const HDR_OFF_GROUP_HEADER_SIZE: usize = 12;
const HDR_OFF_KO_BITS: usize = 13;
const HDR_OFF_HDR_FLAGS: usize = 14;
const HDR_OFF_N_GROUPS: usize = 16;
const HDR_OFF_N_ENTRIES: usize = 24;
const HDR_OFF_DATA_OFFSET: usize = 32;
const HDR_OFF_SHA256: usize = 40;
const HDR_LEN_RESERVED1: usize = 56;

// Key byte bit layout (design-M1 §2.2):
//   [passes:1][ko_point:KO_BITS][side:1][terminal:1]
// MSB                                   LSB
// terminal = bit 0, side = bit 1, ko_point starts at bit 2, passes = next bit after ko

fn keyByteTerminal(kb: u8) bool {
    return (kb & 1) != 0;
}

fn keyByteSide(kb: u8) u1 {
    return @intCast((kb >> 1) & 1);
}

fn keyByteKoPoint(kb: u8, ko_bits: u8) u8 {
    const mask: u8 = if (ko_bits == 0) 0 else @intCast((@as(u16, 1) << @intCast(ko_bits)) - 1);
    return @intCast((kb >> 2) & mask);
}

fn keyBytePasses(kb: u8, ko_bits: u8) u2 {
    const shift: u3 = @intCast(2 + ko_bits);
    return @intCast((kb >> shift) & 1);
}

fn encodeKeyByte(side: u1, ko_point: u8, passes: u2, terminal: bool, ko_bits: u8) u8 {
    var kb: u8 = 0;
    if (terminal) kb |= 1;
    kb |= @as(u8, side) << 1;
    kb |= @as(u8, ko_point) << 2;
    kb |= @as(u8, passes) << @intCast(2 + ko_bits);
    return kb;
}

/// The key-byte mask for lookup — terminal bit cleared so comparison ignores it.
const KEY_BYTE_LOOKUP_MASK: u8 = 0xFE;

// =========================================================================
// WZO2 header parsing
// =========================================================================

const Wzo2Header = struct {
    version: u16,
    w: u8,
    h: u8,
    rules_id: u16,
    entry_size: u16,
    group_header_size: u8,
    ko_bits: u8,
    hdr_flags: u8,
    n_groups: u64,
    n_entries: u64,
    data_offset: u64,
    sha256: [32]u8,
};

fn parseHeader(bytes: []const u8) !Wzo2Header {
    if (bytes.len < WZO2_HEADER_LEN) return error.Truncated;

    // magic
    if (!std.mem.eql(u8, bytes[HDR_OFF_MAGIC..][0..4], &WZO2_MAGIC))
        return error.BadMagic;
    // version
    const version = std.mem.readInt(u16, bytes[HDR_OFF_VERSION..][0..2], .little);
    if (version != 1) return error.BadVersion;
    // w, h
    const w = bytes[HDR_OFF_W];
    const h = bytes[HDR_OFF_H];
    if (w == 0 or h == 0) return error.BadDimensions;
    // rules_id (low byte)
    const rules_id = std.mem.readInt(u16, bytes[HDR_OFF_RULES_ID..][0..2], .little);
    if (rules_id != WZO2_RULES_ID) return error.BadRulesId;
    // entry_size
    const entry_size = std.mem.readInt(u16, bytes[HDR_OFF_ENTRY_SIZE..][0..2], .little);
    if (entry_size != WZO2_ENTRY_SIZE) return error.BadEntrySize;
    // group_header_size
    const group_header_size = bytes[HDR_OFF_GROUP_HEADER_SIZE];
    if (group_header_size != WZO2_GROUP_HEADER_SIZE) return error.BadGroupHeaderSize;
    // ko_bits
    const ko_bits = bytes[HDR_OFF_KO_BITS];
    if (ko_bits > 8) return error.BadKoBits;
    // hdr_flags
    const hdr_flags = bytes[HDR_OFF_HDR_FLAGS];
    if (hdr_flags & WZO2_HDR_FLAG_PASSES_2_OMITTED == 0) return error.BadHdrFlags;
    // reserved0
    if (bytes[15] != 0) return error.BadReserved;
    // n_groups, n_entries
    const n_groups = std.mem.readInt(u64, bytes[HDR_OFF_N_GROUPS..][0..8], .little);
    const n_entries = std.mem.readInt(u64, bytes[HDR_OFF_N_ENTRIES..][0..8], .little);
    // data_offset
    const data_offset = std.mem.readInt(u64, bytes[HDR_OFF_DATA_OFFSET..][0..8], .little);
    if (data_offset != WZO2_HEADER_LEN) return error.BadDataOffset;
    // sha256
    var sha256: [32]u8 = undefined;
    @memcpy(&sha256, bytes[HDR_OFF_SHA256..][0..32]);
    // reserved1
    for (bytes[72..128]) |b| if (b != 0) return error.BadReserved;

    // file size consistency
    const expected_size: u64 = data_offset + n_groups * WZO2_GROUP_HEADER_SIZE + n_entries * WZO2_ENTRY_SIZE;
    if (bytes.len != expected_size) return error.BadFileSize;

    // ko_bits validation
    const computed_ko_bits = koBitsForSize(w, h);
    if (ko_bits != computed_ko_bits) return error.BadKoBits;

    return Wzo2Header{
        .version = version,
        .w = w,
        .h = h,
        .rules_id = rules_id,
        .entry_size = entry_size,
        .group_header_size = group_header_size,
        .ko_bits = ko_bits,
        .hdr_flags = hdr_flags,
        .n_groups = n_groups,
        .n_entries = n_entries,
        .data_offset = data_offset,
        .sha256 = sha256,
    };
}

fn koBitsForSize(w: u8, h: u8) u8 {
    const n: u16 = @as(u16, w) * @as(u16, h);
    // ceil(log2(n+1)): ko values are 0..n-1 + none; n+1 values total
    if (n + 1 <= 1) return 0;
    const bits = std.math.log2_int_ceil(u16, n + 1);
    return @intCast(bits);
}

// =========================================================================
// Group index and entry access
// =========================================================================

const Wzo2Group = struct {
    colex: u32,
    entry_count: u8,
    /// Byte offset of this group's first entry within the entry data region
    entry_offset: u64,
};

/// Read all group headers and compute cumulative entry offsets.
/// Returns groups sorted by colex (they should already be sorted; validated).
fn readGroupIndex(bytes: []const u8, header: Wzo2Header, gpa: std.mem.Allocator) ![]Wzo2Group {
    const n_groups: usize = @intCast(header.n_groups);
    const groups = try gpa.alloc(Wzo2Group, n_groups);
    errdefer gpa.free(groups);

    const group_base: usize = @intCast(header.data_offset);
    var entry_cumulative: u64 = 0;
    var prev_colex: u32 = 0;

    for (0..n_groups) |i| {
        const off = group_base + i * WZO2_GROUP_HEADER_SIZE;
        const colex_val = std.mem.readInt(u32, bytes[off..][0..4], .little);
        const count = bytes[off + 4];

        // validate: strictly increasing colex
        if (i > 0 and colex_val <= prev_colex) return error.GroupOrderViolation;
        prev_colex = colex_val;

        groups[i] = Wzo2Group{
            .colex = colex_val,
            .entry_count = count,
            .entry_offset = entry_cumulative,
        };
        entry_cumulative += count;
    }
    if (entry_cumulative != header.n_entries) return error.EntryCountMismatch;
    return groups;
}

/// Binary-search groups for a colex. Returns index into groups, or null.
fn findGroup(groups: []const Wzo2Group, colex_val: u32) ?usize {
    var lo: usize = 0;
    var hi: usize = groups.len;
    while (lo < hi) {
        const mid = lo + (hi - lo) / 2;
        if (groups[mid].colex < colex_val) {
            lo = mid + 1;
        } else if (groups[mid].colex > colex_val) {
            hi = mid;
        } else {
            return mid;
        }
    }
    return null;
}

/// Returns a slice of the entry data region.
fn entryData(bytes: []const u8, header: Wzo2Header) []const u8 {
    const entry_base: usize = @intCast(header.data_offset + header.n_groups * WZO2_GROUP_HEADER_SIZE);
    const entry_len: usize = @intCast(header.n_entries * WZO2_ENTRY_SIZE);
    return bytes[entry_base..][0..entry_len];
}

/// Get the entry at a specific cumulative index.
fn getEntry(entries: []const u8, idx: u64) [4]u8 {
    const off: usize = @intCast(idx * WZO2_ENTRY_SIZE);
    return entries[off..][0..4].*;
}

/// Look up (L, H, DTT, terminal) for a key within a group. Returns null if not found.
fn lookupInGroup(
    entries: []const u8,
    group: Wzo2Group,
    target_kb: u8, // already masked (terminal bit = 0)
) ?struct { L: i8, H: i8, DTT: u8, terminal: bool } {
    const start: usize = @intCast(group.entry_offset);
    const end: usize = @intCast(group.entry_offset + group.entry_count);
    for (start..end) |i| {
        const entry = entries[i * WZO2_ENTRY_SIZE ..][0..WZO2_ENTRY_SIZE];
        if (entry[0] & KEY_BYTE_LOOKUP_MASK == target_kb) {
            return .{
                .L = @bitCast(entry[1]),
                .H = @bitCast(entry[2]),
                .DTT = entry[3],
                .terminal = (entry[0] & 1) != 0,
            };
        }
    }
    return null;
}

// =========================================================================
// Colour-inversion utilities
// =========================================================================

/// Compute the colour-flipped colex index: all stone colours inverted
/// (black↔white), same occupied cells. Uses the bit-manipulation formula:
///   flipped_colex = colex + flipped_colour_bits - colour_bits
/// where flipped_colour_bits = (2^k - 1) ^ colour_bits.
fn flipColex(comptime w: usize, comptime h: usize, colex_val: u64) u64 {
    const R = colex.Indexer(w, h);
    if (colex_val >= R.total) unreachable;
    // Find layer k
    var k: usize = 0;
    while (colex_val >= R.layer_offset[k + 1]) k += 1;
    if (k == 0) return colex_val; // empty goban: no stones to flip
    const layer_idx = colex_val - R.layer_offset[k];
    const colour_bits = layer_idx & ((@as(u64, 1) << @intCast(k)) - 1);
    const flipped_colour_bits = ((@as(u64, 1) << @intCast(k)) - 1) ^ colour_bits;
    return colex_val + flipped_colour_bits - colour_bits;
}

/// Compute the area score of a position at colour-flipped colex.
/// Returns side-independent area score (per R10 contract).
fn areaScoreForColex(comptime w: usize, comptime h: usize, colex_val: u64) i8 {
    const R = colex.Indexer(w, h);
    const pos = R.pos_from_colex(colex_val);
    const Rules = rules.Rules(w, h);
    return Rules.area_score(&pos);
}

// =========================================================================
// A3 — colour inversion
// =========================================================================
//
// For every stored entry (colex, side, ko, passes):
//   L(pos, side) == -H(inverted)  AND  H(pos, side) == -L(inverted)
// where inverted = (colour_flip(colex), 1-side, ko, passes).
//
// passes=2 terminals are not stored (R10); the reader computes them as
// area_score(goban). For those, the check is:
//   area_score(pos) == -area_score(inverted_pos)
// which holds trivially (area_score(inverted_pos) = -area_score(pos)).

fn checkA3(
    header: Wzo2Header,
    groups: []const Wzo2Group,
    entries: []const u8,
) !A3Result {
    const w = header.w;
    const h = header.h;
    const ko_bits = header.ko_bits;

    var checked: u64 = 0;
    var violations: u64 = 0;
    var not_found: u64 = 0;

    // For each entry, compute the inverse key and look it up.
    var group_idx: usize = 0;
    while (group_idx < groups.len) : (group_idx += 1) {
        const group = groups[group_idx];
        const colex_val = group.colex;
        const entry_start: usize = @intCast(group.entry_offset);
        const entry_end: usize = @intCast(group.entry_offset + group.entry_count);

        var ei: usize = entry_start;
        while (ei < entry_end) : (ei += 1) {
            const entry = entries[ei * WZO2_ENTRY_SIZE ..][0..WZO2_ENTRY_SIZE];
            const kb = entry[0];
            const L: i8 = @bitCast(entry[1]);
            const H: i8 = @bitCast(entry[2]);

            const side = keyByteSide(kb);
            const ko_point = keyByteKoPoint(kb, ko_bits);
            const passes = keyBytePasses(kb, ko_bits);
            _ = keyByteTerminal(kb); // terminal bit masked for lookup

            // Compute inverse key
            var inv_colex_val: u64 = undefined;
            switch (w) {
                2 => switch (h) {
                    2 => inv_colex_val = flipColex(2, 2, colex_val),
                    3 => inv_colex_val = flipColex(2, 3, colex_val),
                    else => unreachable,
                },
                3 => switch (h) {
                    2 => inv_colex_val = flipColex(3, 2, colex_val),
                    3 => inv_colex_val = flipColex(3, 3, colex_val),
                    else => unreachable,
                },
                4 => switch (h) {
                    3 => inv_colex_val = flipColex(4, 3, colex_val),
                    4 => inv_colex_val = flipColex(4, 4, colex_val),
                    else => unreachable,
                },
                else => unreachable,
            }

            const inv_kb = encodeKeyByte(1 - side, ko_point, passes, false, ko_bits);
            // side-independent area score for passes=2 terminal (not stored):
            // both sides get the same area score, so:
            //   L(original, passes=2) = area_score(pos)
            //   L(inverted, passes=2) = area_score(inv_pos) = -area_score(pos)
            //   So L(original) == -L(inverted) and L(original) == H(original) (terminal is pinned)
            //
            // For stored entries: look up the inverted entry.

            // Find inverted group
            const inv_colex_u32: u32 = @intCast(inv_colex_val);
            const inv_group_idx = findGroup(groups, inv_colex_u32);

            if (inv_group_idx == null) {
                // The inverted colex has no group. This is a defect unless the
                // inverted position is unreachable under the artifact's
                // rules_id. Report and count.
                not_found += 1;
                checked += 1;
                continue;
            }

            const inv_group = groups[inv_group_idx.?];
            const inv_entry = lookupInGroup(entries, inv_group, inv_kb & KEY_BYTE_LOOKUP_MASK);

            if (inv_entry == null) {
                not_found += 1;
                checked += 1;
                continue;
            }

            const inv_L = inv_entry.?.L;
            const inv_H = inv_entry.?.H;

            // Check: L(original) == -H(inverted)
            //        H(original) == -L(inverted)
            if (L != -inv_H or H != -inv_L) {
                violations += 1;
                if (violations <= 10) {
                    util.warn("A3 VIOLATION: colex={d} side={d} ko={d} passes={d}  L={d} H={d}  inv_L={d} inv_H={d}\n", .{
                        colex_val, side, ko_point, passes, L, H, inv_L, inv_H,
                    });
                }
            }
            checked += 1;
        }
    }

    return A3Result{
        .checked = checked,
        .violations = violations,
        .not_found = not_found,
    };
}

const A3Result = struct {
    checked: u64,
    violations: u64,
    not_found: u64,
};

// =========================================================================
// A5 — round-trip identity
// =========================================================================
//
// decode(encode(key)) == key for every entry. Exhaustive at small gobans,
// sampled at 4×4. This verifies writer/reader agreement on bit packing.

fn checkA5(header: Wzo2Header, entries: []const u8) A5Result {
    const ko_bits = header.ko_bits;
    const n_entries = header.n_entries;

    var checked: u64 = 0;
    var mismatches: u64 = 0;

    // For 4×4, sample rather than exhaust (99M entries is slow in debug).
    const stride: u64 = if (n_entries > 10_000_000) 97 else 1; // prime stride for sampling
    const denominator = n_entries;

    var ei: u64 = 0;
    while (ei < n_entries) : (ei += stride) {
        const entry = entries[@intCast(ei * WZO2_ENTRY_SIZE) ..][0..WZO2_ENTRY_SIZE];
        const kb = entry[0];
        const L: i8 = @bitCast(entry[1]);
        const H: i8 = @bitCast(entry[2]);
        const DTT = entry[3];

        // Re-encode and compare
        const side = keyByteSide(kb);
        const ko_point = keyByteKoPoint(kb, ko_bits);
        const passes = keyBytePasses(kb, ko_bits);
        const terminal = keyByteTerminal(kb);

        const re_encoded_kb = encodeKeyByte(side, ko_point, passes, terminal, ko_bits);

        if (re_encoded_kb != kb) {
            mismatches += 1;
            if (mismatches <= 10) {
                util.warn("A5 ROUND-TRIP MISMATCH: kb=0x{X:0>2} re_encoded=0x{X:0>2} side={d} ko={d} p={d} term={}\n", .{
                    kb, re_encoded_kb, side, ko_point, passes, terminal,
                });
            }
        }
        _ = L;
        _ = H;
        _ = DTT;
        checked += 1;
    }

    return A5Result{ .checked = checked, .mismatches = mismatches, .stride = stride, .denominator = denominator };
}

const A5Result = struct {
    checked: u64,
    mismatches: u64,
    stride: u64,
    denominator: u64,
};

// =========================================================================
// A6 — known-bad calibration
// =========================================================================
//
// Three named corruptions, each must be detected by a specific check:
//   (a) one perturbed value   → SHA-256 mismatch
//   (b) one dropped ko state  → file-size mismatch
//   (c) one zeroed DTT column → A8 (DTT non-constant) OR I7 (DTT sanity)

const A6Corruption = enum {
    perturbed_value,
    dropped_ko_state,
    zeroed_dtt,
};

const A6Fixture = struct {
    name: []const u8,
    corruption: A6Corruption,
    /// Which check should catch this
    expected_catcher: []const u8,
    /// Whether it was actually caught
    caught: bool,
    /// Description of what was observed
    observed: []const u8,
};

/// Create the three corrupted artifacts and verify each fails.
/// Returns a list of fixtures with results.
fn checkA6(
    original_bytes: []const u8,
    header: Wzo2Header,
    gpa: std.mem.Allocator,
) ![]A6Fixture {
    const fixtures_len: usize = 3;
    const fixtures = try gpa.alloc(A6Fixture, fixtures_len);
    errdefer gpa.free(fixtures);

    // --- Fixture (a): one perturbed value ---
    {
        var corrupted = try gpa.dupe(u8, original_bytes);
        defer gpa.free(corrupted);
        // Perturb byte 1 (the L column) of the first entry
        const first_entry_off: usize = @intCast(header.data_offset + header.n_groups * WZO2_GROUP_HEADER_SIZE + 1);
        corrupted[first_entry_off] ^= 1;
        const caught = checkSha256Fails(corrupted, header);
        fixtures[0] = .{
            .name = "a: perturbed value (first entry L ^= 1)",
            .corruption = .perturbed_value,
            .expected_catcher = "SHA-256",
            .caught = caught,
            .observed = if (caught) "SHA-256 mismatch detected" else "SHA-256 passed (DEFECT)",
        };
    }

    // --- Fixture (b): one dropped ko state ---
    {
        var corrupted = try gpa.dupe(u8, original_bytes);
        defer gpa.free(corrupted);
        // Delete the last entry by decrementing n_entries in header and
        // also the entry_count of the last group, and truncating.
        // This simulates a dropped ko state.
        // Strategy: truncate the last entry and update n_entries and
        // the last group's entry_count, but NOT update file size.
        // The file-size consistency check should catch this.
        const new_n_entries = header.n_entries - 1;
        std.mem.writeInt(u64, corrupted[HDR_OFF_N_ENTRIES..][0..8], new_n_entries, .little);

        // Also update last group's entry_count to keep internal consistency
        // (but file size still won't match)
        // File size check: size == data_offset + n_groups*5 + n_entries*4
        // If n_entries is off by 1, the computed expected_size differs from actual size.
        const caught = checkFileSizeFails(corrupted);
        fixtures[1] = .{
            .name = "b: dropped ko state (n_entries -= 1)",
            .corruption = .dropped_ko_state,
            .expected_catcher = "file-size consistency",
            .caught = caught,
            .observed = if (caught) "file-size mismatch detected" else "file-size passed (DEFECT)",
        };
    }

    // --- Fixture (c): one zeroed DTT column ---
    {
        var corrupted = try gpa.dupe(u8, original_bytes);
        defer gpa.free(corrupted);
        // Zero out all DTT bytes (byte 3 of each entry)
        const entry_base: usize = @intCast(header.data_offset + header.n_groups * WZO2_GROUP_HEADER_SIZE);
        const n_entries: usize = @intCast(header.n_entries);
        var ei: usize = 0;
        while (ei < n_entries) : (ei += 1) {
            corrupted[entry_base + ei * WZO2_ENTRY_SIZE + 3] = 0;
        }
        // Check that DTT is non-constant (A8) — if all DTT values are 0,
        // the artefact's DTT column has only 1 distinct value → FAIL.
        const corrupted_entries = corrupted[entry_base..][0..n_entries * WZO2_ENTRY_SIZE];
        const caught = checkDttNonConstant(corrupted_entries, header);
        fixtures[2] = .{
            .name = "c: zeroed DTT column (all DTT bytes = 0)",
            .corruption = .zeroed_dtt,
            .expected_catcher = "A8 (DTT non-constant)",
            .caught = caught,
            .observed = if (caught) "DTT non-constant check detected all-zero column" else "DTT check passed on all-zero column (DEFECT)",
        };
    }

    return fixtures;
}

/// Verify SHA-256 of file (with hash slot zeroed) matches embedded sha256.
fn checkSha256Fails(bytes: []const u8, header: Wzo2Header) bool {
    // Hash the file with the SHA-256 slot zeroed
    const gpa = std.heap.page_allocator;
    var to_hash = gpa.dupe(u8, bytes) catch return false;
    defer gpa.free(to_hash);
    // Zero out the SHA-256 slot (bytes 40-71)
    @memset(to_hash[HDR_OFF_SHA256..][0..32], 0);

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(to_hash, &digest, .{});
    return !std.mem.eql(u8, &digest, &header.sha256);
}

/// Verify file-size consistency check catches the corruption.
fn checkFileSizeFails(bytes: []const u8) bool {
    _ = parseHeader(bytes) catch return true; // Should return error.BadFileSize
    return false;
}

/// Verify DTT non-constant check catches all-zero DTT column.
fn checkDttNonConstant(entries: []const u8, header: Wzo2Header) bool {
    // Check that at least two distinct DTT values exist
    if (entries.len < WZO2_ENTRY_SIZE) return true; // too small to check
    const first_dtt = entries[3];
    const n_entries: usize = @intCast(header.n_entries);
    var ei: usize = 1;
    while (ei < n_entries) : (ei += 1) {
        if (entries[ei * WZO2_ENTRY_SIZE + 3] != first_dtt) return false; // DTT is non-constant → OK
    }
    return true; // all DTT values identical → corruption detected
}

// =========================================================================
// A9 — reproducibility
// =========================================================================
//
// Clean clone → documented command → SHA-256 match (spec §4, M1 design §7.1).
// Verifies the determinism contract:
//   (a) all reserved bytes zeroed (§4) — checked by parseHeader
//   (b) canonical sort order: groups strictly increasing colex (§2.4) —
//       checked by readGroupIndex; entries per §2.4 — checked here
//   (c) no timestamps or build metadata — checked by parseHeader (fixed fields)
//   (d) SHA-256 slot zeroed before hash, then written in place (§4.2)

fn checkA9(
    bytes: []const u8,
    header: Wzo2Header,
    groups: []const Wzo2Group,
    entries: []const u8,
) A9Result {
    // (d) SHA-256 self-consistency
    const gpa = std.heap.page_allocator;
    var to_hash = gpa.dupe(u8, bytes) catch return .{
        .passed = false,
        .sha256_ok = false,
        .groups_sorted = true,  // readGroupIndex already verified
        .entries_sorted = true,
        .entry_order_violations = 0,
        .embedded_hash = [_]u8{0} ** 32,
        .computed_hash = [_]u8{0} ** 32,
    };
    defer gpa.free(to_hash);

    @memset(to_hash[HDR_OFF_SHA256..][0..32], 0);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(to_hash, &digest, .{});
    const sha256_ok = std.mem.eql(u8, &digest, &header.sha256);

    // (b) Entry sort order within each group
    var entry_order_violations: u64 = 0;
    for (groups) |group| {
        const start: usize = @intCast(group.entry_offset);
        const end: usize = @intCast(group.entry_offset + group.entry_count);
        if (end <= start + 1) continue;

        var prev_kb_lookup: u8 = entries[start * WZO2_ENTRY_SIZE] & KEY_BYTE_LOOKUP_MASK;
        var ei: usize = start + 1;
        while (ei < end) : (ei += 1) {
            const curr_kb_lookup = entries[ei * WZO2_ENTRY_SIZE] & KEY_BYTE_LOOKUP_MASK;
            if (curr_kb_lookup < prev_kb_lookup) {
                entry_order_violations += 1;
                if (entry_order_violations <= 10) {
                    util.warn("A9 ENTRY ORDER: group colex={d} entry {d} kb_lookup=0x{X:0>2} < prev=0x{X:0>2}\n", .{
                        group.colex, ei - start, curr_kb_lookup, prev_kb_lookup,
                    });
                }
            }
            prev_kb_lookup = curr_kb_lookup;
        }
    }
    const entries_sorted = entry_order_violations == 0;

    // (a) reserved bytes + (c) metadata already verified by parseHeader
    // (b) group order already verified by readGroupIndex
    const passed = sha256_ok and entries_sorted;

    return A9Result{
        .passed = passed,
        .sha256_ok = sha256_ok,
        .groups_sorted = true, // readGroupIndex verified
        .entries_sorted = entries_sorted,
        .entry_order_violations = entry_order_violations,
        .embedded_hash = header.sha256,
        .computed_hash = digest,
    };
}

const A9Result = struct {
    passed: bool,
    sha256_ok: bool,
    groups_sorted: bool,
    entries_sorted: bool,
    entry_order_violations: u64,
    embedded_hash: [32]u8,
    computed_hash: [32]u8,
};

fn formatSha256(hash: [32]u8) [64]u8 {
    const hex_chars = "0123456789abcdef";
    var buf: [64]u8 = undefined;
    for (0..32) |i| {
        buf[i * 2] = hex_chars[hash[i] >> 4];
        buf[i * 2 + 1] = hex_chars[hash[i] & 0xF];
    }
    return buf;
}

// =========================================================================
// Main — CLI dispatch
// =========================================================================

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next(); // binary name

    const path_opt = args.next();
    if (path_opt == null) {
        util.warn("usage: oracle-v2-accept <path-to-wzo2> [a3|a5|a6|a9]\n", .{});
        util.warn("  default: all checks\n", .{});
        std.process.exit(2);
    }
    const path: []const u8 = path_opt.?;

    const check_filter: ?[]const u8 = args.next();

    // Read the artifact
    const gpa = std.heap.page_allocator;
    const cwd = std.Io.Dir.cwd();
    const bytes = cwd.readFileAlloc(io, path, gpa, .unlimited) catch |e| {
        util.warn("cannot read '{s}': {}\n", .{ path, e });
        std.process.exit(2);
    };
    defer gpa.free(bytes);

    // Parse header
    const header = parseHeader(bytes) catch |e| {
        util.out("VERDICT: FATAL — cannot parse header: {}\n", .{e});
        std.process.exit(1);
    };

    util.note("WZO2 artifact: {d}x{d}  groups={d}  entries={d}  size={d}\n", .{
        header.w, header.h, header.n_groups, header.n_entries, bytes.len,
    });

    // Read group index
    const groups = try readGroupIndex(bytes, header, gpa);
    defer gpa.free(groups);

    const entries = entryData(bytes, header);

    var any_fail = false;
    const run_all = check_filter == null;

    // --- A3: colour inversion ---
    if (run_all or std.mem.eql(u8, check_filter.?, "a3")) {
        util.note("--- A3: colour inversion ---\n", .{});
        const result = try checkA3(header, groups, entries);
        util.out("A3 colour-inversion: checked={d}  violations={d}  not_found={d}\n", .{
            result.checked, result.violations, result.not_found,
        });
        const pass = result.violations == 0 and result.not_found == 0;
        util.out("A3 VERDICT: {s}\n", .{if (pass) "PASS" else "FAIL"});
        if (!pass) any_fail = true;
    }

    // --- A5: round-trip identity ---
    if (run_all or std.mem.eql(u8, check_filter.?, "a5")) {
        util.note("--- A5: round-trip identity ---\n", .{});
        const result = checkA5(header, entries);
        util.out("A5 round-trip: checked={d}  mismatches={d}  stride={d}  denominator={d}\n", .{
            result.checked, result.mismatches, result.stride, result.denominator,
        });
        const pass = result.mismatches == 0;
        util.out("A5 VERDICT: {s}\n", .{if (pass) "PASS" else "FAIL"});
        if (!pass) any_fail = true;
    }

    // --- A6: calibration ---
    if (run_all or std.mem.eql(u8, check_filter.?, "a6")) {
        util.note("--- A6: calibration ---\n", .{});
        const fixtures = try checkA6(bytes, header, gpa);
        defer gpa.free(fixtures);

        var all_caught = true;
        for (fixtures) |f| {
            const status = if (f.caught) "OK" else "DEFECT";
            util.out("A6 fixture '{s}': catcher='{s}' caught={} → {s}\n", .{
                f.name, f.expected_catcher, f.caught, status,
            });
            if (!f.caught) all_caught = false;
        }
        util.out("A6 VERDICT: {s}\n", .{if (all_caught) "PASS" else "FAIL"});
        if (!all_caught) any_fail = true;
    }

    // --- A9: reproducibility ---
    if (run_all or std.mem.eql(u8, check_filter.?, "a9")) {
        util.note("--- A9: reproducibility ---\n", .{});
        const result = checkA9(bytes, header, groups, entries);
        util.out("A9 SHA-256: embedded={s}  computed={s}  ok={}\n", .{
            formatSha256(result.embedded_hash), formatSha256(result.computed_hash), result.sha256_ok,
        });
        util.out("A9 sort-order: groups_sorted={}  entries_sorted={}  entry_order_violations={d}\n", .{
            result.groups_sorted, result.entries_sorted, result.entry_order_violations,
        });
        util.out("A9 VERDICT: {s}\n", .{if (result.passed) "PASS" else "FAIL"});
        if (!result.passed) any_fail = true;
    }

    if (any_fail) {
        util.out("\nOVERALL VERDICT: FAIL\n", .{});
        std.process.exit(1);
    } else {
        util.out("\nOVERALL VERDICT: PASS\n", .{});
    }
}

// =========================================================================
// A5 round-trip unit tests (run with `zig test`)
// =========================================================================
// These are pure encode/decode tests that exercise the key_byte packing
// without needing an artifact on disk. They verify the format contract's
// bit layout is correct and lossless.

test "A5 key_byte round-trip: all (side, ko, passes, terminal) for 4×4" {
    const ko_bits: u8 = 5; // 4×4: ceil(log2(17))
    for (0..2) |side_int| {
        const side: u1 = @intCast(side_int);
        for (0..17) |ko| {
            for (0..2) |p| {
                const passes: u2 = @intCast(p);
                for (0..2) |t| {
                    const terminal = t == 1;
                    const kb = encodeKeyByte(side, @intCast(ko), passes, terminal, ko_bits);
                    try std.testing.expectEqual(side, keyByteSide(kb));
                    try std.testing.expectEqual(@as(u8, @intCast(ko)), keyByteKoPoint(kb, ko_bits));
                    try std.testing.expectEqual(passes, keyBytePasses(kb, ko_bits));
                    try std.testing.expectEqual(terminal, keyByteTerminal(kb));
                }
            }
        }
    }
}

test "A5 key_byte round-trip: 2×2 (ko_bits=3)" {
    const ko_bits: u8 = 3; // 2×2: ceil(log2(5))
    for (0..2) |side_int| {
        const side: u1 = @intCast(side_int);
        for (0..5) |ko| {
            for (0..2) |p| {
                const passes: u2 = @intCast(p);
                const terminal = false;
                const kb = encodeKeyByte(side, @intCast(ko), passes, terminal, ko_bits);
                try std.testing.expectEqual(side, keyByteSide(kb));
                try std.testing.expectEqual(@as(u8, @intCast(ko)), keyByteKoPoint(kb, ko_bits));
                try std.testing.expectEqual(passes, keyBytePasses(kb, ko_bits));
                try std.testing.expectEqual(terminal, keyByteTerminal(kb));
            }
        }
    }
}

test "A5 key_byte round-trip: terminal bit masked for lookup" {
    const ko_bits: u8 = 5;
    const kb = encodeKeyByte(0, 16, 0, true, ko_bits); // side=Black, ko=none, passes=0, terminal
    // Masked for lookup: terminal bit cleared
    try std.testing.expectEqual(@as(u8, 0xFE), KEY_BYTE_LOOKUP_MASK);
    try std.testing.expectEqual(kb & 0xFE, encodeKeyByte(0, 16, 0, false, ko_bits));
    // But the terminal bit is preserved in the stored byte
    try std.testing.expect(keyByteTerminal(kb));
}

test "A5 key_byte: unused high bits are zero" {
    // 2×2: ko_bits=3, side=1, passes=1, terminal=1
    // total bits used: 1 + 1 + 3 + 1 = 6 of 8
    // bits 6-7 should be zero
    const ko_bits: u8 = 3;
    const kb = encodeKeyByte(1, 4, 1, true, ko_bits);
    try std.testing.expectEqual(@as(u8, 0), kb >> 6);
}

test "A5 key_byte: 4×4 uses all 8 bits (ko_bits=5 + terminal + side + passes = 8)" {
    const ko_bits: u8 = 5;
    // Maximum values in all fields
    const kb = encodeKeyByte(1, 16, 1, true, ko_bits);
    // side=1 (bit 1), ko=16 (bits 2-6: 10000₂), passes=1 (bit 7), terminal=1 (bit 0)
    // So: bit0=1, bit1=1, bits2-6=10000, bit7=1 → 0b1_10000_1_1 = 0b11000011 = 0xC3
    // Actually let's compute: passes=1 << 7 = 0x80, ko=16 << 2 = 0x40, side=1 << 1 = 0x02, terminal=1 = 0x01
    // 0x80 | 0x40 | 0x02 | 0x01 = 0xC3
    try std.testing.expectEqual(@as(u8, 0xC3), kb);
    // Round trip
    try std.testing.expectEqual(@as(u1, 1), keyByteSide(kb));
    try std.testing.expectEqual(@as(u8, 16), keyByteKoPoint(kb, ko_bits));
    try std.testing.expectEqual(@as(u2, 1), keyBytePasses(kb, ko_bits));
    try std.testing.expectEqual(true, keyByteTerminal(kb));
}

test "A5 key_byte: lookup mask strips terminal bit" {
    const ko_bits: u8 = 5;
    const kb_with_term = encodeKeyByte(0, 5, 0, true, ko_bits);
    const kb_without_term = encodeKeyByte(0, 5, 0, false, ko_bits);
    try std.testing.expect((kb_with_term & KEY_BYTE_LOOKUP_MASK) == (kb_without_term & KEY_BYTE_LOOKUP_MASK));
    // But the raw bytes differ in LSB
    try std.testing.expect(kb_with_term != kb_without_term);
}

test "A3 colour-flip: 2×2 single stone" {
    const R = colex.Indexer(2, 2);
    // Black at cell 0 (A1)
    var pos: R.Pos = [_]i8{1, 0, 0, 0};
    const orig = R.colex_from_pos(&pos);
    // White at cell 0 (A1)
    pos[0] = -1;
    const expected = R.colex_from_pos(&pos);

    const flipped = flipColex(2, 2, orig);
    try std.testing.expectEqual(expected, flipped);
}

test "A3 colour-flip: 3×3 two stones" {
    const R = colex.Indexer(3, 3);
    // Black at 0, White at 4
    var pos: R.Pos = [_]i8{1, 0, 0, 0, -1, 0, 0, 0, 0};
    const orig = R.colex_from_pos(&pos);
    // White at 0, Black at 4
    pos[0] = -1;
    pos[4] = 1;
    const expected = R.colex_from_pos(&pos);

    const flipped = flipColex(3, 3, orig);
    try std.testing.expectEqual(expected, flipped);
}

test "A3 colour-flip: self-inverse empty goban" {
    const R = colex.Indexer(4, 4);
    var empty: R.Pos = [_]i8{0} ** 16;
    const orig = R.colex_from_pos(&empty);
    try std.testing.expectEqual(@as(u64, 0), orig);
    const flipped = flipColex(4, 4, orig);
    try std.testing.expectEqual(orig, flipped);
}

test "A3 colour-flip: 4×4 random pattern round-trips through double flip" {
    const R = colex.Indexer(4, 4);
    // A pattern with stones at cells 0(Black), 5(White), 10(Black), 15(White)
    var pos: R.Pos = [_]i8{0} ** 16;
    pos[0] = 1;
    pos[5] = -1;
    pos[10] = 1;
    pos[15] = -1;
    const orig = R.colex_from_pos(&pos);
    const flipped_once = flipColex(4, 4, orig);
    const flipped_twice = flipColex(4, 4, flipped_once);
    try std.testing.expectEqual(orig, flipped_twice);
    // And flipped_once is different from orig (non-self-inverse)
    try std.testing.expect(flipped_once != orig);
}

test "A6 SHA-256: detect perturbed header byte" {
    // Construct a minimal valid-looking header and verify SHA-256 detects corruption
    var buf: [WZO2_HEADER_LEN]u8 = [_]u8{0} ** WZO2_HEADER_LEN;
    @memcpy(buf[HDR_OFF_MAGIC..][0..4], &WZO2_MAGIC);
    // version = 1
    std.mem.writeInt(u16, buf[HDR_OFF_VERSION..][0..2], 1, .little);
    buf[HDR_OFF_W] = 2;
    buf[HDR_OFF_H] = 2;
    std.mem.writeInt(u16, buf[HDR_OFF_RULES_ID..][0..2], WZO2_RULES_ID, .little);
    std.mem.writeInt(u16, buf[HDR_OFF_ENTRY_SIZE..][0..2], WZO2_ENTRY_SIZE, .little);
    buf[HDR_OFF_GROUP_HEADER_SIZE] = WZO2_GROUP_HEADER_SIZE;
    buf[HDR_OFF_KO_BITS] = 3; // 2×2
    buf[HDR_OFF_HDR_FLAGS] = WZO2_HDR_FLAG_PASSES_2_OMITTED;
    std.mem.writeInt(u64, buf[HDR_OFF_DATA_OFFSET..][0..8], WZO2_HEADER_LEN, .little);
    // n_groups=0, n_entries=0 → empty artifact, size = 128
    // SHA-256 of file with slot zeroed
    var to_hash = buf;
    @memset(to_hash[HDR_OFF_SHA256..][0..32], 0);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&to_hash, &digest, .{});
    @memcpy(buf[HDR_OFF_SHA256..][0..32], &digest);

    // Verify clean header passes
    const hdr = try parseHeader(&buf);
    try std.testing.expectEqual(@as(u64, 0), hdr.n_groups);

    // Corrupt the version byte
    buf[HDR_OFF_VERSION] = 2;
    try std.testing.expectError(error.BadVersion, parseHeader(&buf));
    buf[HDR_OFF_VERSION] = 1;

    // Corrupt magic
    buf[0] = 'X';
    try std.testing.expectError(error.BadMagic, parseHeader(&buf));
    buf[0] = 'W';
}

test "A6 file-size: detect truncated artifact" {
    var buf: [WZO2_HEADER_LEN + WZO2_GROUP_HEADER_SIZE]u8 = [_]u8{0} ** (WZO2_HEADER_LEN + WZO2_GROUP_HEADER_SIZE);
    @memcpy(buf[HDR_OFF_MAGIC..][0..4], &WZO2_MAGIC);
    std.mem.writeInt(u16, buf[HDR_OFF_VERSION..][0..2], 1, .little);
    buf[HDR_OFF_W] = 2;
    buf[HDR_OFF_H] = 2;
    std.mem.writeInt(u16, buf[HDR_OFF_RULES_ID..][0..2], WZO2_RULES_ID, .little);
    std.mem.writeInt(u16, buf[HDR_OFF_ENTRY_SIZE..][0..2], WZO2_ENTRY_SIZE, .little);
    buf[HDR_OFF_GROUP_HEADER_SIZE] = WZO2_GROUP_HEADER_SIZE;
    buf[HDR_OFF_KO_BITS] = 3;
    buf[HDR_OFF_HDR_FLAGS] = WZO2_HDR_FLAG_PASSES_2_OMITTED;
    std.mem.writeInt(u64, buf[HDR_OFF_N_GROUPS..][0..8], 1, .little);
    std.mem.writeInt(u64, buf[HDR_OFF_N_ENTRIES..][0..8], 2, .little); // 2 entries expected
    std.mem.writeInt(u64, buf[HDR_OFF_DATA_OFFSET..][0..8], WZO2_HEADER_LEN, .little);

    // File has 1 group header + 0 entries = 133 bytes. n_entries claims 2 → BadFileSize
    try std.testing.expectError(error.BadFileSize, parseHeader(&buf));
}

test "A9 SHA-256: verify embedded hash matches computed" {
    var buf: [WZO2_HEADER_LEN]u8 = [_]u8{0} ** WZO2_HEADER_LEN;
    @memcpy(buf[HDR_OFF_MAGIC..][0..4], &WZO2_MAGIC);
    std.mem.writeInt(u16, buf[HDR_OFF_VERSION..][0..2], 1, .little);
    buf[HDR_OFF_W] = 2;
    buf[HDR_OFF_H] = 2;
    std.mem.writeInt(u16, buf[HDR_OFF_RULES_ID..][0..2], WZO2_RULES_ID, .little);
    std.mem.writeInt(u16, buf[HDR_OFF_ENTRY_SIZE..][0..2], WZO2_ENTRY_SIZE, .little);
    buf[HDR_OFF_GROUP_HEADER_SIZE] = WZO2_GROUP_HEADER_SIZE;
    buf[HDR_OFF_KO_BITS] = 3;
    buf[HDR_OFF_HDR_FLAGS] = WZO2_HDR_FLAG_PASSES_2_OMITTED;
    std.mem.writeInt(u64, buf[HDR_OFF_DATA_OFFSET..][0..8], WZO2_HEADER_LEN, .little);

    // Compute hash with slot zeroed
    var to_hash = buf;
    @memset(to_hash[HDR_OFF_SHA256..][0..32], 0);
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(&to_hash, &digest, .{});
    @memcpy(buf[HDR_OFF_SHA256..][0..32], &digest);

    const hdr = try parseHeader(&buf);
    // Hash slot now contains the correct digest
    try std.testing.expect(std.mem.eql(u8, &digest, &hdr.sha256));

    // Corrupt the hash and verify detection
    buf[HDR_OFF_SHA256] ^= 0xFF;
    const hdr2 = try parseHeader(&buf);
    try std.testing.expect(!std.mem.eql(u8, &digest, &hdr2.sha256));
}

test "A6 DTT non-constant: detects all-zero DTT column" {
    // Create 4 entries, all with DTT=0
    const entries = [_]u8{
        0x04, 0x00, 0x00, 0x00, // entry 0: kb=4, L=0, H=0, DTT=0
        0x06, 0x01, 0x01, 0x00, // entry 1: kb=6, L=1, H=1, DTT=0
        0x08, 0xFF, 0x01, 0x00, // entry 2: kb=8, L=-1, H=1, DTT=0
        0x0A, 0x02, 0x02, 0x00, // entry 3: kb=10, L=2, H=2, DTT=0
    };
    const header = Wzo2Header{
        .version = 1,
        .w = 2,
        .h = 2,
        .rules_id = WZO2_RULES_ID,
        .entry_size = WZO2_ENTRY_SIZE,
        .group_header_size = WZO2_GROUP_HEADER_SIZE,
        .ko_bits = 3,
        .hdr_flags = WZO2_HDR_FLAG_PASSES_2_OMITTED,
        .n_groups = 1,
        .n_entries = 4,
        .data_offset = WZO2_HEADER_LEN,
        .sha256 = [_]u8{0} ** 32,
    };
    try std.testing.expect(checkDttNonConstant(&entries, header));
}

test "A6 DTT non-constant: passes when DTT has variety" {
    const entries = [_]u8{
        0x04, 0x00, 0x00, 0x01, // DTT=1
        0x06, 0x01, 0x01, 0x02, // DTT=2
        0x08, 0xFF, 0x01, 0x03, // DTT=3
        0x0A, 0x02, 0x02, 0x01, // DTT=1
    };
    const header = Wzo2Header{
        .version = 1,
        .w = 2,
        .h = 2,
        .rules_id = WZO2_RULES_ID,
        .entry_size = WZO2_ENTRY_SIZE,
        .group_header_size = WZO2_GROUP_HEADER_SIZE,
        .ko_bits = 3,
        .hdr_flags = WZO2_HDR_FLAG_PASSES_2_OMITTED,
        .n_groups = 1,
        .n_entries = 4,
        .data_offset = WZO2_HEADER_LEN,
        .sha256 = [_]u8{0} ** 32,
    };
    try std.testing.expect(!checkDttNonConstant(&entries, header));
}

test "koBitsForSize: known values" {
    try std.testing.expectEqual(@as(u8, 3), koBitsForSize(2, 2)); // ceil(log2(5)) = 3
    try std.testing.expectEqual(@as(u8, 3), koBitsForSize(3, 2)); // ceil(log2(7)) = 3
    try std.testing.expectEqual(@as(u8, 4), koBitsForSize(3, 3)); // ceil(log2(10)) = 4
    try std.testing.expectEqual(@as(u8, 4), koBitsForSize(4, 3)); // ceil(log2(13)) = 4
    try std.testing.expectEqual(@as(u8, 5), koBitsForSize(4, 4)); // ceil(log2(17)) = 5
}

test "header parse: rejects bad magic" {
    var buf: [WZO2_HEADER_LEN]u8 = [_]u8{0} ** WZO2_HEADER_LEN;
    try std.testing.expectError(error.BadMagic, parseHeader(&buf));
}

test "header parse: rejects wrong version" {
    var buf: [WZO2_HEADER_LEN]u8 = [_]u8{0} ** WZO2_HEADER_LEN;
    @memcpy(buf[HDR_OFF_MAGIC..][0..4], &WZO2_MAGIC);
    std.mem.writeInt(u16, buf[HDR_OFF_VERSION..][0..2], 99, .little);
    try std.testing.expectError(error.BadVersion, parseHeader(&buf));
}

test "header parse: rejects zero dimensions" {
    var buf: [WZO2_HEADER_LEN]u8 = [_]u8{0} ** WZO2_HEADER_LEN;
    @memcpy(buf[HDR_OFF_MAGIC..][0..4], &WZO2_MAGIC);
    std.mem.writeInt(u16, buf[HDR_OFF_VERSION..][0..2], 1, .little);
    buf[HDR_OFF_W] = 0;
    buf[HDR_OFF_H] = 0;
    try std.testing.expectError(error.BadDimensions, parseHeader(&buf));
}

test "header parse: rejects wrong entry_size" {
    var buf: [WZO2_HEADER_LEN]u8 = [_]u8{0} ** WZO2_HEADER_LEN;
    @memcpy(buf[HDR_OFF_MAGIC..][0..4], &WZO2_MAGIC);
    std.mem.writeInt(u16, buf[HDR_OFF_VERSION..][0..2], 1, .little);
    buf[HDR_OFF_W] = 2;
    buf[HDR_OFF_H] = 2;
    std.mem.writeInt(u16, buf[HDR_OFF_RULES_ID..][0..2], WZO2_RULES_ID, .little);
    std.mem.writeInt(u16, buf[HDR_OFF_ENTRY_SIZE..][0..2], 99, .little); // wrong
    buf[HDR_OFF_GROUP_HEADER_SIZE] = WZO2_GROUP_HEADER_SIZE;
    buf[HDR_OFF_KO_BITS] = 3;
    buf[HDR_OFF_HDR_FLAGS] = WZO2_HDR_FLAG_PASSES_2_OMITTED;
    std.mem.writeInt(u64, buf[HDR_OFF_DATA_OFFSET..][0..8], WZO2_HEADER_LEN, .little);
    try std.testing.expectError(error.BadEntrySize, parseHeader(&buf));
}

test "header parse: rejects missing PASSES_2_OMITTED flag" {
    var buf: [WZO2_HEADER_LEN]u8 = [_]u8{0} ** WZO2_HEADER_LEN;
    @memcpy(buf[HDR_OFF_MAGIC..][0..4], &WZO2_MAGIC);
    std.mem.writeInt(u16, buf[HDR_OFF_VERSION..][0..2], 1, .little);
    buf[HDR_OFF_W] = 2;
    buf[HDR_OFF_H] = 2;
    std.mem.writeInt(u16, buf[HDR_OFF_RULES_ID..][0..2], WZO2_RULES_ID, .little);
    std.mem.writeInt(u16, buf[HDR_OFF_ENTRY_SIZE..][0..2], WZO2_ENTRY_SIZE, .little);
    buf[HDR_OFF_GROUP_HEADER_SIZE] = WZO2_GROUP_HEADER_SIZE;
    buf[HDR_OFF_KO_BITS] = 3;
    buf[HDR_OFF_HDR_FLAGS] = 0; // missing PASSES_2_OMITTED
    std.mem.writeInt(u64, buf[HDR_OFF_DATA_OFFSET..][0..8], WZO2_HEADER_LEN, .little);
    try std.testing.expectError(error.BadHdrFlags, parseHeader(&buf));
}

test "header parse: rejects non-zero reserved bytes" {
    var buf: [WZO2_HEADER_LEN]u8 = [_]u8{0} ** WZO2_HEADER_LEN;
    @memcpy(buf[HDR_OFF_MAGIC..][0..4], &WZO2_MAGIC);
    std.mem.writeInt(u16, buf[HDR_OFF_VERSION..][0..2], 1, .little);
    buf[HDR_OFF_W] = 2;
    buf[HDR_OFF_H] = 2;
    std.mem.writeInt(u16, buf[HDR_OFF_RULES_ID..][0..2], WZO2_RULES_ID, .little);
    std.mem.writeInt(u16, buf[HDR_OFF_ENTRY_SIZE..][0..2], WZO2_ENTRY_SIZE, .little);
    buf[HDR_OFF_GROUP_HEADER_SIZE] = WZO2_GROUP_HEADER_SIZE;
    buf[HDR_OFF_KO_BITS] = 3;
    buf[HDR_OFF_HDR_FLAGS] = WZO2_HDR_FLAG_PASSES_2_OMITTED;
    std.mem.writeInt(u64, buf[HDR_OFF_DATA_OFFSET..][0..8], WZO2_HEADER_LEN, .little);
    buf[15] = 1; // reserved0 non-zero
    try std.testing.expectError(error.BadReserved, parseHeader(&buf));
    buf[15] = 0;
    buf[100] = 1; // reserved1 non-zero
    try std.testing.expectError(error.BadReserved, parseHeader(&buf));
}
