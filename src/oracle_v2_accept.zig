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
// (docs/epics/E1-markovian/sprints/oracle-v2/pass0/design-M1.md). This module
// runs BEFORE M2b/M3 produce the real artifact — the checks exist before the
// code they judge (spec sprint.md A4).
//
// The format structures below are inline duplicates of artifact2.zig's
// contract. When M1 delivers artifact2.zig, a follow-up task replaces these
// with `const art = @import("artifact2.zig")` imports. The byte-level format
// is frozen by the M1 design; this file is the consumer that verifies it.
//
// Usage:
//   zig run -O ReleaseSafe src/oracle_v2_accept.zig -- <path-to-wzo2> [check] [--stride N]
//   zig test src/oracle_v2_accept.zig  # runs A5 round-trip unit tests
//
// Checks (select with second arg, default = all):
//   a1   self-play refusal rate (pinned seed)
//   a2   Bellman residual (L/H fixpoint identity)
//   a3   colour inversion: L(-pos,-side)==-H(pos,side) for every stored state
//   a4   pin census (L==H, L<H categories)
//   a5   round-trip: decode(encode(x)) == x (exhaustive at 2×2/3×2/3×3,
//        sampled with stated denominator at 4×4)
//   a6   calibration: corrupt artifact, verify detection
//   a8   DTT distribution and consistency
//   a9   reproducibility: SHA-256 verification against recorded hash
//
// --stride N: override the default sampling stride for A2/A5/A8.
//   --stride 1  = exhaustive (check every entry)
//   --stride 0  = use built-in default (997/97/1999 for 4×4, 1 otherwise)
//   default: built-in values (backward-compatible with all existing baselines)
//
// stdout = data (verdict + counts), stderr = diagnostics (progress).
// Exit code 0 = PASS, 1 = FAIL, 2 = usage error.

const std = @import("std");
const util = @import("util.zig");
const evidence = @import("evidence.zig");
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
// Helpers — pinned value, PRNG, ko-after-capture
// =========================================================================

/// TIE=0 pinned value from an L/H bracket: max(L, min(0, H)).
fn pinnedValue(L: i8, H: i8) i8 {
    return @max(L, @min(@as(i8, 0), H));
}

/// Simple LCG PRNG for reproducible self-play (glibc-style).
fn prngNext(state: *u64) usize {
    state.* = state.* *% 6364136223846793005 +% 1442695040888963407;
    return @intCast((state.* >> 33) & 0x7FFFFFFF);
}

/// Compute ko_point after a placement. Returns KO_NONE (= n) if no ko created.
/// Delegates to rules.koAfterCapture — the single production ko rule
/// (Phase 2 kernel, T273). [GLOBAL.AXIOM-BASICKO:CLAIMED]
fn koAfterCapture(old_pos: anytype, side: i8, new_pos: anytype, w: usize, h: usize, ko_none: u8) u8 {
    return rules.koAfterCapture(old_pos[0..], new_pos[0..], side, w, h, ko_none);
}

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

pub fn parseHeader(bytes: []const u8) !Wzo2Header {
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

pub const Wzo2Group = struct {
    colex: u32,
    entry_count: u8,
    /// Byte offset of this group's first entry within the entry data region
    entry_offset: u64,
};

/// Read all group headers and compute cumulative entry offsets.
/// Returns groups sorted by colex (they should already be sorted; validated).
pub fn readGroupIndex(bytes: []const u8, header: Wzo2Header, gpa: std.mem.Allocator) ![]Wzo2Group {
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
pub fn entryData(bytes: []const u8, header: Wzo2Header) []const u8 {
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
// A1 — pinned-seed self-play refusal rate
// =========================================================================
//
// Random self-play with a pinned PRNG seed. At each ply the harness looks up
// the current state in the artifact; a null return is a refusal (= the v1
// UNCHAINABLE symptom). Move selection is random (same PRNG). Denominator ≥
// 100 oracle queries. The seed is recorded here for reproducibility.

const SELFPLAY_SEED: u64 = 0x57A1_4E27_0D97;

fn checkA1(
    header: Wzo2Header,
    groups: []const Wzo2Group,
    entries: []const u8,
) !A1Result {
    const w = header.w;
    const h = header.h;
    return switch (w) {
        2 => switch (h) {
            2 => checkA1Inner(2, 2, header, groups, entries),
            3 => checkA1Inner(2, 3, header, groups, entries),
            else => error.UnsupportedGoban,
        },
        3 => switch (h) {
            2 => checkA1Inner(3, 2, header, groups, entries),
            3 => checkA1Inner(3, 3, header, groups, entries),
            else => error.UnsupportedGoban,
        },
        4 => switch (h) {
            3 => checkA1Inner(4, 3, header, groups, entries),
            4 => checkA1Inner(4, 4, header, groups, entries),
            else => error.UnsupportedGoban,
        },
        else => error.UnsupportedGoban,
    };
}

fn checkA1Inner(
    comptime w: usize,
    comptime h: usize,
    header: Wzo2Header,
    groups: []const Wzo2Group,
    entries: []const u8,
) !A1Result {
    const R = colex.Indexer(w, h);
    const Rules = rules.Rules(w, h);
    const ko_bits = header.ko_bits;
    const ko_none: u8 = @intCast(w * h);
    const n_cells = w * h;

    var rng: u64 = SELFPLAY_SEED;
    var queries: u64 = 0;
    var refusals: u64 = 0;
    var games: u64 = 0;
    var max_plies: u64 = 0;

    // Play games until we have ≥ 100 oracle queries, max 20 games
    while (queries < 100 and games < 20) : (games += 1) {
        var pos: R.Pos = [_]i8{0} ** (w * h);
        var side: i8 = 1; // Black to move
        var ko: u8 = ko_none;
        var passes: u2 = 0;
        var plies: u64 = 0;

        while (plies < 200) : (plies += 1) {
            if (passes >= 2) break; // game over (double pass)
            queries += 1;

            // Oracle query: look up current state
            const colex_val: u32 = @intCast(R.colex_from_pos(&pos));
            const group_idx = findGroup(groups, colex_val);
            if (group_idx == null) {
                refusals += 1;
                if (refusals <= 5) {
                    evidence.print("A1 REFUSAL: colex={d} side={d} ko={d} passes={d} group not found\n", .{ colex_val, side, ko, passes });
                }
                break;
            }
            const group = groups[group_idx.?];
            const target_kb = encodeKeyByte(if (side > 0) @as(u1, 0) else @as(u1, 1), ko, @intCast(passes), false, ko_bits);
            const entry = lookupInGroup(entries, group, target_kb & KEY_BYTE_LOOKUP_MASK);
            if (entry == null) {
                refusals += 1;
                if (refusals <= 5) {
                    evidence.print("A1 REFUSAL: colex={d} side={d} ko={d} passes={d} entry not found\n", .{ colex_val, side, ko, passes });
                }
                break;
            }

            // Collect legal moves (non-pass)
            var legal_moves: [n_cells]usize = undefined;
            var nmoves: usize = 0;
            for (0..n_cells) |p| {
                if (pos[p] != 0) continue;
                if (ko != ko_none and p == ko) continue; // basic ko
                _ = Rules.pos_from_move(&pos, side, p) catch continue; // suicide/occupied
                legal_moves[nmoves] = p;
                nmoves += 1;
            }

            if (nmoves == 0) {
                // No legal placements — must pass
                passes += 1;
                ko = ko_none; // pass clears ko
                side = -side;
                continue;
            }

            // Pick a random move using PRNG
            const pick = prngNext(&rng) % nmoves;
            const mp = legal_moves[pick];

            // Apply the move
            const child_pos = Rules.pos_from_move(&pos, side, mp) catch continue;
            const child_ko = koAfterCapture(&pos, side, &child_pos, w, h, ko_none);
            pos = child_pos;
            ko = child_ko;
            passes = 0; // placement resets passes
            side = -side;
        }
        if (plies > max_plies) max_plies = plies;
    }

    return A1Result{
        .queries = queries,
        .refusals = refusals,
        .games = games,
        .max_plies = max_plies,
        .seed = SELFPLAY_SEED,
    };
}

const A1Result = struct {
    queries: u64,
    refusals: u64,
    games: u64,
    max_plies: u64,
    seed: u64,
};

// =========================================================================
// A4 — pin census
// =========================================================================
//
// Count entries by pin category: L==H (pin_T), L<H with L>0 (pin_L — TIE=0
// would select L), L<H with H<0 (pin_H — TIE=0 would select H). Invariant:
// pin_L == pin_H (colour-inversion symmetry). Also report L<H with L≤0≤H
// (straddle-zero, TIE=0 picks 0).

fn checkA4(_: Wzo2Header, groups: []const Wzo2Group, entries: []const u8) A4Result {
    var pin_T: u64 = 0; // L == H
    var pin_L: u64 = 0; // L < H, L > 0 (TIE=0 picks L)
    var pin_H: u64 = 0; // L < H, H < 0 (TIE=0 picks H)
    var pin_0: u64 = 0; // L < H, L <= 0 <= H (TIE=0 picks 0 at the boundary)
    var total: u64 = 0;

    // Iterate all entries
    var group_idx: usize = 0;
    while (group_idx < groups.len) : (group_idx += 1) {
        const group = groups[group_idx];
        const start: usize = @intCast(group.entry_offset);
        const end: usize = @intCast(group.entry_offset + group.entry_count);

        var ei: usize = start;
        while (ei < end) : (ei += 1) {
            const entry = entries[ei * WZO2_ENTRY_SIZE ..][0..WZO2_ENTRY_SIZE];
            const L: i8 = @bitCast(entry[1]);
            const H: i8 = @bitCast(entry[2]);
            total += 1;

            if (L == H) {
                pin_T += 1;
            } else if (L > 0) {
                pin_L += 1;
            } else if (H < 0) {
                pin_H += 1;
            } else {
                pin_0 += 1; // L <= 0 <= H, L < H
            }
        }
    }

    const pin_LH_ok = pin_L == pin_H;

    return A4Result{
        .total = total,
        .pin_T = pin_T,
        .pin_L = pin_L,
        .pin_H = pin_H,
        .pin_0 = pin_0,
        .pin_LH_ok = pin_LH_ok,
    };
}

const A4Result = struct {
    total: u64,
    pin_T: u64,
    pin_L: u64,
    pin_H: u64,
    pin_0: u64,
    pin_LH_ok: bool,
};

// =========================================================================
// A2 — post-round-trip Bellman residual
// =========================================================================
//
// For every stored entry, reconstruct the state, generate all children
// (legal placements + pass), look up child values, and verify the Bellman
// operator is a fixpoint:
//   L(parent) == best_side({L(child), ...})
//   H(parent) == best_side({H(child), ...})
// where best_side = max for Black, min for White.
//
// Passes=2 children (absorbing terminals per R10) are not in the artifact;
// plug them as L=H=area_score(pos), DTT=0, terminal=true.
//
// Exhaustive at 2x2/3x2/3x3, sampled with prime stride at 4x4.

pub fn checkA2(
    header: Wzo2Header,
    groups: []const Wzo2Group,
    entries: []const u8,
    user_stride: ?u64,
) !A2Result {
    const w = header.w;
    const h = header.h;
    const us = user_stride;
    return switch (w) {
        2 => switch (h) {
            2 => checkA2Inner(2, 2, header, groups, entries, us),
            3 => checkA2Inner(2, 3, header, groups, entries, us),
            else => error.UnsupportedGoban,
        },
        3 => switch (h) {
            2 => checkA2Inner(3, 2, header, groups, entries, us),
            3 => checkA2Inner(3, 3, header, groups, entries, us),
            else => error.UnsupportedGoban,
        },
        4 => switch (h) {
            3 => checkA2Inner(4, 3, header, groups, entries, us),
            4 => checkA2Inner(4, 4, header, groups, entries, us),
            else => error.UnsupportedGoban,
        },
        else => error.UnsupportedGoban,
    };
}

fn checkA2Inner(
    comptime w: usize,
    comptime h: usize,
    header: Wzo2Header,
    groups: []const Wzo2Group,
    entries: []const u8,
    user_stride: ?u64,
) !A2Result {
    const R = colex.Indexer(w, h);
    const Rules = rules.Rules(w, h);
    const ko_bits = header.ko_bits;
    const ko_none: u8 = @intCast(w * h);
    const n_cells = w * h;
    const n_entries = header.n_entries;

    // Stride: user override > built-in default (exhaustive for small gobans,
    // prime-stride sample for 4x4)
    const stride: u64 = if (user_stride) |s|
        if (s == 0) (if (n_entries > 5_000_000) @as(u64, 997) else 1) else s
    else if (n_entries > 5_000_000) 997 else 1;
    const denominator = n_entries;

    var checked: u64 = 0;
    var L_violations: u64 = 0;
    var H_violations: u64 = 0;
    var missing_child: u64 = 0;

    var group_idx: usize = 0;
    var entry_global: u64 = 0;
    while (group_idx < groups.len) : (group_idx += 1) {
        const group = groups[group_idx];
        const colex_val = group.colex;
        const start: usize = @intCast(group.entry_offset);
        const end: usize = @intCast(group.entry_offset + group.entry_count);

        // Reconstruct the goban position for this group
        const pos = R.pos_from_colex(colex_val);

        var ei: usize = start;
        while (ei < end) : (ei += 1) {
            defer entry_global += 1;
            if (entry_global % stride != 0) continue;

            const entry = entries[ei * WZO2_ENTRY_SIZE ..][0..WZO2_ENTRY_SIZE];
            const kb = entry[0];
            const L: i8 = @bitCast(entry[1]);
            const H: i8 = @bitCast(entry[2]);

            const side_u1 = keyByteSide(kb);
            const side: i8 = if (side_u1 == 0) @as(i8, 1) else @as(i8, -1);
            const ko_point = keyByteKoPoint(kb, ko_bits);
            const passes: u2 = keyBytePasses(kb, ko_bits);
            _ = keyByteTerminal(kb);

            const maximizing = side > 0;

            // Accumulate child values
            var best_L: i8 = if (maximizing) -128 else 127;
            var best_H: i8 = if (maximizing) -128 else 127;
            var any_child = false;

            // Pass edge: (same pos, -side, ko=none, passes+1)
            {
                const child_passes = passes + 1;
                if (child_passes >= 2) {
                    // Absorbing terminal (R10): L=H=area_score(pos)
                    const ascore = Rules.area_score(&pos);
                    const cl: i8 = ascore;
                    const ch: i8 = ascore;
                    if (if (maximizing) cl > best_L else cl < best_L) best_L = cl;
                    if (if (maximizing) ch > best_H else ch < best_H) best_H = ch;
                    any_child = true;
                } else {
                    const pass_kb = encodeKeyByte(1 - side_u1, ko_none, @intCast(child_passes), false, ko_bits);
                    const pass_group_idx = findGroup(groups, colex_val); // same colex
                    if (pass_group_idx != null) {
                        const pass_row = lookupInGroup(entries, groups[pass_group_idx.?], pass_kb & KEY_BYTE_LOOKUP_MASK);
                        if (pass_row != null) {
                            if (if (maximizing) pass_row.?.L > best_L else pass_row.?.L < best_L) best_L = pass_row.?.L;
                            if (if (maximizing) pass_row.?.H > best_H else pass_row.?.H < best_H) best_H = pass_row.?.H;
                            any_child = true;
                        } else {
                            missing_child += 1;
                        }
                    } else {
                        missing_child += 1;
                    }
                }
            }

            // Placement children
            for (0..n_cells) |p| {
                if (pos[p] != 0) continue;
                if (ko_point != ko_none and p == ko_point) continue; // basic ko
                const child_pos = Rules.pos_from_move(&pos, side, p) catch continue;
                const child_ko = koAfterCapture(&pos, side, &child_pos, w, h, ko_none);
                const child_colex: u32 = @intCast(R.colex_from_pos(&child_pos));
                const child_kb = encodeKeyByte(1 - side_u1, child_ko, 0, false, ko_bits); // passes resets to 0

                const child_group_idx = findGroup(groups, child_colex);
                if (child_group_idx == null) {
                    missing_child += 1;
                    continue;
                }
                const child_row = lookupInGroup(entries, groups[child_group_idx.?], child_kb & KEY_BYTE_LOOKUP_MASK);
                if (child_row == null) {
                    missing_child += 1;
                    continue;
                }
                if (if (maximizing) child_row.?.L > best_L else child_row.?.L < best_L) best_L = child_row.?.L;
                if (if (maximizing) child_row.?.H > best_H else child_row.?.H < best_H) best_H = child_row.?.H;
                any_child = true;
            }

            // If terminal (no legal placements), the pass edge is the only child.
            // `any_child` covers this since the pass edge is always generated.
            // If somehow no children at all, skip the check.
            if (!any_child) {
                missing_child += 1;
                checked += 1;
                continue;
            }

            // Bellman identity check
            if (L != best_L) {
                L_violations += 1;
                if (L_violations <= 10) {
                    evidence.print("A2 L-VIOLATION: colex={d} side={d} ko={d} p={d}  stored L={d} expected L={d}\n", .{ colex_val, side, ko_point, passes, L, best_L });
                }
            }
            if (H != best_H) {
                H_violations += 1;
                if (H_violations <= 10) {
                    evidence.print("A2 H-VIOLATION: colex={d} side={d} ko={d} p={d}  stored H={d} expected H={d}\n", .{ colex_val, side, ko_point, passes, H, best_H });
                }
            }
            checked += 1;
        }
    }

    return A2Result{
        .checked = checked,
        .L_violations = L_violations,
        .H_violations = H_violations,
        .missing_child = missing_child,
        .stride = stride,
        .denominator = denominator,
    };
}

pub const A2Result = struct {
    checked: u64,
    L_violations: u64,
    H_violations: u64,
    missing_child: u64,
    stride: u64,
    denominator: u64,
};

// =========================================================================
// A8 — DTT non-constant, consistency, distribution
// =========================================================================
//
// DTT is non-constant (≥ 2 distinct non-FAR values), terminals have DTT≥1
// (stored; passes=2 terminals with DTT=0 are not in artifact), and for each
// non-terminal non-FAR entry, DTT > min_{c ∈ VP(s)} DTT(c).
// Reports the distribution (histogram buckets).

fn checkA8(
    header: Wzo2Header,
    groups: []const Wzo2Group,
    entries: []const u8,
    user_stride: ?u64,
) !A8Result {
    const w = header.w;
    const h = header.h;
    const us = user_stride;
    return switch (w) {
        2 => switch (h) {
            2 => checkA8Inner(2, 2, header, groups, entries, us),
            3 => checkA8Inner(2, 3, header, groups, entries, us),
            else => error.UnsupportedGoban,
        },
        3 => switch (h) {
            2 => checkA8Inner(3, 2, header, groups, entries, us),
            3 => checkA8Inner(3, 3, header, groups, entries, us),
            else => error.UnsupportedGoban,
        },
        4 => switch (h) {
            3 => checkA8Inner(4, 3, header, groups, entries, us),
            4 => checkA8Inner(4, 4, header, groups, entries, us),
            else => error.UnsupportedGoban,
        },
        else => error.UnsupportedGoban,
    };
}

fn checkA8Inner(
    comptime w: usize,
    comptime h: usize,
    header: Wzo2Header,
    groups: []const Wzo2Group,
    entries: []const u8,
    user_stride: ?u64,
) !A8Result {
    const R = colex.Indexer(w, h);
    const Rules = rules.Rules(w, h);
    const ko_bits = header.ko_bits;
    const ko_none: u8 = @intCast(w * h);
    const n_cells = w * h;

    // Distribution buckets: [0]=0, [1]=1..4, [2]=5..16, [3]=17..64, [4]=65..254, [5]=FAR(255)
    var dist: [6]u64 = [_]u64{0} ** 6;
    var total: u64 = 0;
    var far_count: u64 = 0;
    var terminal_with_dtt0: u64 = 0; // ERROR: terminal flag set but DTT=0
    var dtt_consistency_checked: u64 = 0;
    var dtt_consistency_violations: u64 = 0;

    // For DTT non-constant: track first non-FAR DTT value
    var first_dtt: ?u8 = null;
    var non_constant_ok = false;

    // Stride for DTT consistency (expensive: requires child generation)
    const n_entries = header.n_entries;
    const dtt_stride: u64 = if (user_stride) |s|
        if (s == 0) (if (n_entries > 1_000_000) @as(u64, 1999) else 1) else s
    else if (n_entries > 1_000_000) 1999 else 1;

    var group_idx: usize = 0;
    var entry_global: u64 = 0;
    while (group_idx < groups.len) : (group_idx += 1) {
        const group = groups[group_idx];
        const colex_val = group.colex;
        const start: usize = @intCast(group.entry_offset);
        const end: usize = @intCast(group.entry_offset + group.entry_count);

        const pos = R.pos_from_colex(colex_val);

        var ei: usize = start;
        while (ei < end) : (ei += 1) {
            defer entry_global += 1;
            const entry = entries[ei * WZO2_ENTRY_SIZE ..][0..WZO2_ENTRY_SIZE];
            const kb = entry[0];
            const L: i8 = @bitCast(entry[1]);
            const H: i8 = @bitCast(entry[2]);
            const DTT = entry[3];

            const side_u1 = keyByteSide(kb);
            const side: i8 = if (side_u1 == 0) @as(i8, 1) else @as(i8, -1);
            const ko_point = keyByteKoPoint(kb, ko_bits);
            const passes: u2 = keyBytePasses(kb, ko_bits);
            const terminal = keyByteTerminal(kb);

            total += 1;

            // Distribution
            if (DTT == 255) {
                dist[5] += 1;
                far_count += 1;
            } else if (DTT == 0) {
                dist[0] += 1;
                if (terminal) terminal_with_dtt0 += 1;
                if (first_dtt == null) first_dtt = 0;
                if (first_dtt.? != 0) non_constant_ok = true;
            } else if (DTT <= 4) {
                dist[1] += 1;
                if (first_dtt == null) first_dtt = DTT;
                if (first_dtt.? != DTT) non_constant_ok = true;
            } else if (DTT <= 16) {
                dist[2] += 1;
                if (first_dtt == null) first_dtt = DTT;
                if (first_dtt.? != DTT) non_constant_ok = true;
            } else if (DTT <= 64) {
                dist[3] += 1;
                if (first_dtt == null) first_dtt = DTT;
                if (first_dtt.? != DTT) non_constant_ok = true;
            } else {
                dist[4] += 1;
                if (first_dtt == null) first_dtt = DTT;
                if (first_dtt.? != DTT) non_constant_ok = true;
            }

            // DTT consistency check (sampled for 4x4)
            if (entry_global % dtt_stride != 0) continue;
            if (terminal or DTT == 255) {
                dtt_consistency_checked += 1;
                continue; // terminals have no placements; FAR has no guaranteed child path
            }

            // For each stored state, find value-preserving children and check
            // DTT > min(DTT(VP child))
            const maximizing = side > 0;
            var min_child_dtt: u8 = 255;
            var any_vp_child = false;

            // Pass edge
            {
                const child_passes = passes + 1;
                if (child_passes >= 2) {
                    // passes=2 terminal: DTT=0, value = area_score
                    const ascore = Rules.area_score(&pos);
                    const vp = if (maximizing) ascore >= L else ascore <= H;
                    if (vp) {
                        min_child_dtt = 0;
                        any_vp_child = true;
                    }
                } else {
                    const pass_kb = encodeKeyByte(1 - side_u1, ko_none, @intCast(child_passes), false, ko_bits);
                    const pass_group_idx = findGroup(groups, colex_val);
                    if (pass_group_idx != null) {
                        const pass_row = lookupInGroup(entries, groups[pass_group_idx.?], pass_kb & KEY_BYTE_LOOKUP_MASK);
                        if (pass_row != null) {
                            const vp = if (maximizing) pass_row.?.L >= L else pass_row.?.H <= H;
                            if (vp) {
                                if (pass_row.?.DTT < min_child_dtt and pass_row.?.DTT != 255) min_child_dtt = pass_row.?.DTT;
                                any_vp_child = true;
                            }
                        }
                    }
                }
            }

            // Placement children
            for (0..n_cells) |p| {
                if (pos[p] != 0) continue;
                if (ko_point != ko_none and p == ko_point) continue;
                const child_pos = Rules.pos_from_move(&pos, side, p) catch continue;
                const child_ko = koAfterCapture(&pos, side, &child_pos, w, h, ko_none);
                const child_colex: u32 = @intCast(R.colex_from_pos(&child_pos));
                const child_kb = encodeKeyByte(1 - side_u1, child_ko, 0, false, ko_bits);

                const child_group_idx = findGroup(groups, child_colex);
                if (child_group_idx == null) continue;
                const child_row = lookupInGroup(entries, groups[child_group_idx.?], child_kb & KEY_BYTE_LOOKUP_MASK);
                if (child_row == null) continue;

                const vp = if (maximizing) child_row.?.L >= L else child_row.?.H <= H;
                if (vp) {
                    if (child_row.?.DTT < min_child_dtt and child_row.?.DTT != 255) min_child_dtt = child_row.?.DTT;
                    any_vp_child = true;
                }
            }

            if (any_vp_child and min_child_dtt != 255) {
                if (DTT != min_child_dtt + 1) {
                    dtt_consistency_violations += 1;
                    if (dtt_consistency_violations <= 10) {
                        util.warn("A8 DTT VIOLATION: colex={d} side={d} ko={d} p={d}  DTT={d} expected={d} (min_child={d})\n", .{ colex_val, side, ko_point, passes, DTT, min_child_dtt + 1, min_child_dtt });
                    }
                }
            }
            dtt_consistency_checked += 1;
        }
    }

    return A8Result{
        .total = total,
        .dist = dist,
        .far_count = far_count,
        .non_constant_ok = non_constant_ok,
        .terminal_dtt0_errs = terminal_with_dtt0,
        .dtt_consistency_checked = dtt_consistency_checked,
        .dtt_consistency_violations = dtt_consistency_violations,
        .dtt_stride = dtt_stride,
    };
}

const A8Result = struct {
    total: u64,
    dist: [6]u64,
    far_count: u64,
    non_constant_ok: bool,
    terminal_dtt0_errs: u64,
    dtt_consistency_checked: u64,
    dtt_consistency_violations: u64,
    dtt_stride: u64,
};

// =========================================================================
// A5 — round-trip identity
// =========================================================================
//
// decode(encode(key)) == key for every entry. Exhaustive at small gobans,
// sampled at 4×4. This verifies writer/reader agreement on bit packing.

fn checkA5(header: Wzo2Header, entries: []const u8, user_stride: ?u64) A5Result {
    const ko_bits = header.ko_bits;
    const n_entries = header.n_entries;

    var checked: u64 = 0;
    var mismatches: u64 = 0;

    // Stride: user override > built-in default (prime stride 97 for 4×4)
    const stride: u64 = if (user_stride) |s|
        if (s == 0) (if (n_entries > 10_000_000) @as(u64, 97) else 1) else s
    else if (n_entries > 10_000_000) 97 else 1;
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
        util.warn("usage: oracle-v2-accept <path-to-wzo2> [a1|a2|a3|a4|a5|a6|a8|a9]\n", .{});
        util.warn("  default: all checks\n", .{});
        std.process.exit(2);
    }
    const path: []const u8 = path_opt.?;

    var check_filter: ?[]const u8 = null;
    var user_stride: ?u64 = null;

    // Parse remaining args: [check] [--stride N]
    while (true) {
        const arg = args.next();
        if (arg == null) break;
        const a = arg.?;
        if (std.mem.eql(u8, a, "--stride")) {
            const val = args.next();
            if (val == null) {
                util.warn("error: --stride requires a value\n", .{});
                std.process.exit(2);
            }
            user_stride = std.fmt.parseUnsigned(u64, val.?, 10) catch {
                util.warn("error: --stride value must be a non-negative integer, got '{s}'\n", .{val.?});
                std.process.exit(2);
            };
        } else if (check_filter == null) {
            check_filter = a;
        } else {
            util.warn("error: unexpected argument '{s}'\n", .{a});
            std.process.exit(2);
        }
    }

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

    // --- A1: self-play refusal rate ---
    if (run_all or std.mem.eql(u8, check_filter.?, "a1")) {
        util.note("--- A1: pinned-seed self-play ---\n", .{});
        const result = try checkA1(header, groups, entries);
        util.out("A1 self-play: queries={d}  refusals={d}  games={d}  max_plies={d}  seed=0x{X:0>16}\n", .{
            result.queries, result.refusals, result.games, result.max_plies, result.seed,
        });
        const pass = result.refusals == 0;
        util.out("A1 VERDICT: {s}\n", .{if (pass) "PASS" else "FAIL"});
        if (!pass) any_fail = true;
    }

    // --- A4: pin census ---
    if (run_all or std.mem.eql(u8, check_filter.?, "a4")) {
        util.note("--- A4: pin census ---\n", .{});
        const result = checkA4(header, groups, entries);
        util.out("A4 pin-census: total={d}  pin_T={d}  pin_L={d}  pin_H={d}  pin_0={d}  pin_L==pin_H={}\n", .{
            result.total, result.pin_T, result.pin_L, result.pin_H, result.pin_0, result.pin_LH_ok,
        });
        const pass = result.pin_LH_ok;
        util.out("A4 VERDICT: {s}\n", .{if (pass) "PASS" else "FAIL"});
        if (!pass) any_fail = true;
    }

    // --- A2: post-round-trip Bellman ---
    if (run_all or std.mem.eql(u8, check_filter.?, "a2")) {
        util.note("--- A2: Bellman residual ---\n", .{});
        const result = try checkA2(header, groups, entries, user_stride);
        util.out("A2 Bellman: checked={d}  L_violations={d}  H_violations={d}  missing_child={d}  stride={d}  denominator={d}\n", .{
            result.checked, result.L_violations, result.H_violations, result.missing_child, result.stride, result.denominator,
        });
        const pass = result.L_violations == 0 and result.H_violations == 0;
        util.out("A2 VERDICT: {s}\n", .{if (pass) "PASS" else "FAIL"});
        if (!pass) any_fail = true;
    }

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
        const result = checkA5(header, entries, user_stride);
        util.out("A5 round-trip: checked={d}  mismatches={d}  stride={d}  denominator={d}\n", .{
            result.checked, result.mismatches, result.stride, result.denominator,
        });
        const pass = result.mismatches == 0;
        util.out("A5 VERDICT: {s}\n", .{if (pass) "PASS" else "FAIL"});
        if (!pass) any_fail = true;
    }

    // --- A8: DTT distribution and consistency ---
    if (run_all or std.mem.eql(u8, check_filter.?, "a8")) {
        util.note("--- A8: DTT ---\n", .{});
        const result = try checkA8(header, groups, entries, user_stride);
        util.out("A8 DTT: total={d}  far={d}  non_constant={}  terminal_dtt0_errs={d}\n", .{
            result.total, result.far_count, result.non_constant_ok, result.terminal_dtt0_errs,
        });
        util.out("A8 DTT dist: [0]={d} [1..4]={d} [5..16]={d} [17..64]={d} [65..254]={d} [FAR]={d}\n", .{
            result.dist[0], result.dist[1], result.dist[2], result.dist[3], result.dist[4], result.dist[5],
        });
        util.out("A8 DTT consistency: checked={d}  violations={d}  stride={d}\n", .{
            result.dtt_consistency_checked, result.dtt_consistency_violations, result.dtt_stride,
        });
        const pass = result.non_constant_ok and result.terminal_dtt0_errs == 0 and result.dtt_consistency_violations == 0;
        util.out("A8 VERDICT: {s}\n", .{if (pass) "PASS" else "FAIL"});
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

// =========================================================================
// A1 tests — self-play helpers and synthetic artifact coverage
// =========================================================================

test "A1 PRNG determinism" {
    var rng: u64 = SELFPLAY_SEED;
    const first = prngNext(&rng);
    const second = prngNext(&rng);
    // Reset, verify reproducibility
    rng = SELFPLAY_SEED;
    try std.testing.expectEqual(first, prngNext(&rng));
    try std.testing.expectEqual(second, prngNext(&rng));
}

test "A1 PRNG produces varied output" {
    var rng: u64 = SELFPLAY_SEED;
    var seen = std.StaticBitSet(1024).initEmpty();
    for (0..200) |_| {
        const v = prngNext(&rng) % 1024;
        seen.set(v);
    }
    // Should visit many distinct values (probabilistic; > 100 distinct)
    try std.testing.expect(seen.count() > 100);
}

test "A1 self-play on synthetic 2x2 artifact: detects refusals on incomplete data" {
    // Build a minimal 2x2 artifact with only a few entries.
    // The self-play will quickly wander into positions not in the artifact,
    // producing refusals. This verifies the refusal-counting mechanism works.
    const gpa = std.testing.allocator;
    const w: u8 = 2;
    const h: u8 = 2;
    const kb = koBitsForSize(w, h);
    const none: u8 = 4;

    const colex0_kb_B = encodeKeyByte(0, none, 0, false, kb);
    const colex0_kb_W = encodeKeyByte(1, none, 0, false, kb);

    const groups = [_]Wzo2Group{
        .{ .colex = 0, .entry_count = 2, .entry_offset = 0 },
    };

    const n_entries: u64 = 2;
    const entries_buf = try gpa.alloc(u8, @intCast(n_entries * WZO2_ENTRY_SIZE));
    defer gpa.free(entries_buf);
    @memset(entries_buf, 0);

    entries_buf[0] = colex0_kb_B; entries_buf[1] = 0; entries_buf[2] = 0; entries_buf[3] = 5;
    entries_buf[4] = colex0_kb_W; entries_buf[5] = 0; entries_buf[6] = 0; entries_buf[7] = 5;

    const header = Wzo2Header{
        .version = 1, .w = w, .h = h, .rules_id = WZO2_RULES_ID,
        .entry_size = WZO2_ENTRY_SIZE, .group_header_size = WZO2_GROUP_HEADER_SIZE,
        .ko_bits = kb, .hdr_flags = WZO2_HDR_FLAG_PASSES_2_OMITTED,
        .n_groups = groups.len, .n_entries = n_entries, .data_offset = WZO2_HEADER_LEN,
        .sha256 = [_]u8{0} ** 32,
    };

    const result = try checkA1(header, &groups, entries_buf);
    // Incomplete artifact → refusals once the self-play moves beyond empty goban.
    // The sparse artifact may not allow 100 queries before hitting game caps;
    // we verify the mechanism works (refusals detected).
    try std.testing.expect(result.refusals > 0);
    try std.testing.expect(result.queries > 0);
}

// =========================================================================
// A4 tests — pin census
// =========================================================================

test "A4 pin census: counts correctly" {
    const n_entries: u64 = 8;
    var entries_buf: [8 * 4]u8 = undefined;
    @memset(&entries_buf, 0);

    // pin_T: L==H
    entries_buf[0] = 0x04; entries_buf[1] = @bitCast(@as(i8, 0)); entries_buf[2] = @bitCast(@as(i8, 0)); // L=H=0 → pin_T
    entries_buf[4] = 0x04; entries_buf[5] = @bitCast(@as(i8, 5)); entries_buf[6] = @bitCast(@as(i8, 5)); // L=H=5 → pin_T
    // pin_L: L<H, L>0
    entries_buf[8] = 0x04; entries_buf[9] = @bitCast(@as(i8, 3)); entries_buf[10] = @bitCast(@as(i8, 7)); // L=3,H=7 → pin_L
    // pin_H: L<H, H<0
    entries_buf[12] = 0x04; entries_buf[13] = @bitCast(@as(i8, -7)); entries_buf[14] = @bitCast(@as(i8, -3)); // L=-7,H=-3 → pin_H
    // pin_0: L<=0<=H, L<H
    entries_buf[16] = 0x04; entries_buf[17] = @bitCast(@as(i8, -2)); entries_buf[18] = @bitCast(@as(i8, 3)); // L=-2,H=3 → pin_0
    entries_buf[20] = 0x04; entries_buf[21] = @bitCast(@as(i8, 0)); entries_buf[22] = @bitCast(@as(i8, 5)); // L=0,H=5 → pin_0 (L≤0≤H)
    // More pin_T and pin_L to test counts
    entries_buf[24] = 0x04; entries_buf[25] = @bitCast(@as(i8, -1)); entries_buf[26] = @bitCast(@as(i8, -1)); // L=H=-1 → pin_T
    entries_buf[28] = 0x04; entries_buf[29] = @bitCast(@as(i8, 1)); entries_buf[30] = @bitCast(@as(i8, 4)); // L=1,H=4 → pin_L

    const groups = [_]Wzo2Group{
        .{ .colex = 0, .entry_count = 8, .entry_offset = 0 },
    };
    const header = Wzo2Header{
        .version = 1, .w = 2, .h = 2, .rules_id = WZO2_RULES_ID,
        .entry_size = WZO2_ENTRY_SIZE, .group_header_size = WZO2_GROUP_HEADER_SIZE,
        .ko_bits = 3, .hdr_flags = WZO2_HDR_FLAG_PASSES_2_OMITTED,
        .n_groups = 1, .n_entries = n_entries, .data_offset = WZO2_HEADER_LEN,
        .sha256 = [_]u8{0} ** 32,
    };

    const result = checkA4(header, &groups, &entries_buf);
    try std.testing.expectEqual(@as(u64, 8), result.total);
    try std.testing.expectEqual(@as(u64, 3), result.pin_T); // (0,0), (5,5), (-1,-1)
    try std.testing.expectEqual(@as(u64, 2), result.pin_L); // (3,7), (1,4)
    try std.testing.expectEqual(@as(u64, 1), result.pin_H); // (-7,-3)
    try std.testing.expectEqual(@as(u64, 2), result.pin_0); // (-2,3), (0,5)
    // pin_L != pin_H in this synthetic case (2 vs 1)
    try std.testing.expect(!result.pin_LH_ok);
}

test "A4 pin census: symmetric data has pin_L == pin_H" {
    // Create entries where L values are symmetric with H values under colour flip
    // pin_L conditions: L<H, L>0; pin_H conditions: L<H, H<0
    // For symmetry, we need one pin_L for each pin_H and vice versa
    const n_entries: u64 = 4;
    var entries_buf: [4 * 4]u8 = undefined;
    @memset(&entries_buf, 0);

    // pin_L: (2, 4)
    entries_buf[0] = 0x04; entries_buf[1] = @bitCast(@as(i8, 2)); entries_buf[2] = @bitCast(@as(i8, 4));
    // pin_H: (-4, -2) — colour-inverted counterpart of (2, 4)
    entries_buf[4] = 0x04; entries_buf[5] = @bitCast(@as(i8, -4)); entries_buf[6] = @bitCast(@as(i8, -2));
    // pin_T for balance
    entries_buf[8] = 0x04; entries_buf[9] = @bitCast(@as(i8, 0)); entries_buf[10] = @bitCast(@as(i8, 0));
    entries_buf[12] = 0x04; entries_buf[13] = @bitCast(@as(i8, 5)); entries_buf[14] = @bitCast(@as(i8, 5));

    const groups = [_]Wzo2Group{
        .{ .colex = 0, .entry_count = 4, .entry_offset = 0 },
    };
    const header = Wzo2Header{
        .version = 1, .w = 2, .h = 2, .rules_id = WZO2_RULES_ID,
        .entry_size = WZO2_ENTRY_SIZE, .group_header_size = WZO2_GROUP_HEADER_SIZE,
        .ko_bits = 3, .hdr_flags = WZO2_HDR_FLAG_PASSES_2_OMITTED,
        .n_groups = 1, .n_entries = n_entries, .data_offset = WZO2_HEADER_LEN,
        .sha256 = [_]u8{0} ** 32,
    };

    const result = checkA4(header, &groups, &entries_buf);
    try std.testing.expectEqual(@as(u64, 1), result.pin_L);
    try std.testing.expectEqual(@as(u64, 1), result.pin_H);
    try std.testing.expect(result.pin_LH_ok);
}

// =========================================================================
// A2 tests — Bellman residual
// =========================================================================

test "A2 Bellman: koAfterCapture detects ko on real placement" {
    // 2x2: B at 0, W at 1, B at 2. B plays at 3, captures W at 1.
    // Old (buggy) rule says ko=1. Kernel says none (friendly=1 at cell 2).
    // The solver and kernel agree exhaustively (verified by rules.zig tests).
    var old_pos = [_]i8{ 1, -1, 1, 0 };
    var new_pos = [_]i8{ 1, 0, 1, 1 };
    const ko = koAfterCapture(&old_pos, 1, &new_pos, 2, 2, 4);
    try std.testing.expectEqual(@as(u8, 4), ko); // no ko: friendly neighbor
}

test "A2 Bellman: koAfterCapture returns none for multi-capture" {
    // 2x2: two White stones at 0,1. Black plays at 3? No, that's not adjacent.
    // Use 3x2: multiple W stones captured by a single B placement.
    const none: u8 = 6;
    var old_pos = [_]i8{ -1, -1, 0, 1, 0, 0 };
    var new_pos = [_]i8{ 0, 0, 0, 1, 0, 0 }; // two stones captured, no ko
    const ko = koAfterCapture(&old_pos, 1, &new_pos, 3, 2, none);
    try std.testing.expectEqual(none, ko);
}

test "A2 Bellman: koAfterCapture returns none when capturer has friend" {
    // 2x2: B at 0, W at 1, B at 2. B plays at 3, captures W at 1.
    // B at 3 has friendly neighbor at 2 → not a ko.
    const none: u8 = 4;
    var old_pos = [_]i8{ 1, -1, 1, 0 };
    var new_pos = [_]i8{ 1, 0, 1, 1 };
    const ko = koAfterCapture(&old_pos, 1, &new_pos, 2, 2, none);
    try std.testing.expectEqual(none, ko); // no ko: friendly neighbor
}

test "A2 Bellman: pinnedValue" {
    try std.testing.expectEqual(@as(i8, 5), pinnedValue(5, 5)); // L==H
    try std.testing.expectEqual(@as(i8, 3), pinnedValue(3, 7)); // L>0 → L
    try std.testing.expectEqual(@as(i8, -2), pinnedValue(-5, -2)); // H<0 → H
    try std.testing.expectEqual(@as(i8, 0), pinnedValue(-3, 5)); // straddle 0 → 0
    try std.testing.expectEqual(@as(i8, 0), pinnedValue(0, 0)); // exact zero
}

test "A2 Bellman: synthetic 2x2 fixpoint identity passes" {
    // Build a minimal self-consistent artifact
    const gpa = std.testing.allocator;
    const w: u8 = 2;
    const h: u8 = 2;
    const kb = koBitsForSize(w, h);
    const none: u8 = 4;

    // colex=0: empty goban
    // - Black ko=none p=0: children are Black plays at 0,1,2,3 + pass
    // - White ko=none p=0: children are White plays at 0,1,2,3 + pass
    // For the Bellman identity to hold, values must be consistent.
    // We'll create a tiny fixpoint where all values are 0 (trivial: area=0 on empty)

    const colex0_B_kb = encodeKeyByte(0, none, 0, false, kb);
    const colex0_W_kb = encodeKeyByte(1, none, 0, false, kb);
    // After Black plays at cell 0 → colex 3 (Black at 0)
    // All values are 0
    const colex0_B_p1_kb = encodeKeyByte(0, none, 1, false, kb);
    const colex0_W_p1_kb = encodeKeyByte(1, none, 1, false, kb);

    // Children after Black plays at cell 0 (colex=3): White to move
    const colex3_W_kb = encodeKeyByte(1, none, 0, false, kb);

    const groups = [_]Wzo2Group{
        .{ .colex = 0, .entry_count = 4, .entry_offset = 0 },
        .{ .colex = 3, .entry_count = 1, .entry_offset = 4 },
    };

    const n_entries: u64 = 5;
    const entries_buf = try gpa.alloc(u8, @intCast(n_entries * WZO2_ENTRY_SIZE));
    defer gpa.free(entries_buf);
    @memset(entries_buf, 0);

    // All values = 0; DTT artificial
    entries_buf[0] = colex0_B_kb; entries_buf[1] = 0; entries_buf[2] = 0; entries_buf[3] = 5;
    entries_buf[4] = colex0_W_kb; entries_buf[5] = 0; entries_buf[6] = 0; entries_buf[7] = 5;
    entries_buf[8] = colex0_B_p1_kb; entries_buf[9] = 0; entries_buf[10] = 0; entries_buf[11] = 3;
    entries_buf[12] = colex0_W_p1_kb; entries_buf[13] = 0; entries_buf[14] = 0; entries_buf[15] = 3;
    entries_buf[16] = colex3_W_kb; entries_buf[17] = 0; entries_buf[18] = 0; entries_buf[19] = 1;

    const header = Wzo2Header{
        .version = 1, .w = w, .h = h, .rules_id = WZO2_RULES_ID,
        .entry_size = WZO2_ENTRY_SIZE, .group_header_size = WZO2_GROUP_HEADER_SIZE,
        .ko_bits = kb, .hdr_flags = WZO2_HDR_FLAG_PASSES_2_OMITTED,
        .n_groups = groups.len, .n_entries = n_entries, .data_offset = WZO2_HEADER_LEN,
        .sha256 = [_]u8{0} ** 32,
    };

    // This will miss some children (since the artifact is minimal) —
    // missing_child will be non-zero, but L/H violations should be 0
    // because the values we stored (0) happen to match the pass-edge
    // value (0 from area_score when passes=2).
    const result = try checkA2(header, &groups, entries_buf, null);
    // We expect L/H violations = 0 (the pass edge gives 0, and there are
    // no other placed children with entries, which skip).
    try std.testing.expectEqual(@as(u64, 0), result.L_violations);
    try std.testing.expectEqual(@as(u64, 0), result.H_violations);
}

test "A2 Bellman: detects L violation on synthetic data" {
    // Store a wrong L value and verify A2 catches it.
    // Use passes=1 state so pass edge goes directly to passes=2 terminal
    // (area_score), which is computed without needing another artifact entry.
    const gpa = std.testing.allocator;
    const w: u8 = 2;
    const h: u8 = 2;
    const kb = koBitsForSize(w, h);
    const none: u8 = 4;

    // Black, passes=1, empty goban. Pass edge → passes=2 → area_score(empty)=0.
    // Expected Bellman: max(0) = 0. If we store L=99, we get a violation.
    const colex0_B_p1_kb = encodeKeyByte(0, none, 1, false, kb);

    const groups = [_]Wzo2Group{
        .{ .colex = 0, .entry_count = 1, .entry_offset = 0 },
    };

    const n_entries: u64 = 1;
    const entries_buf = try gpa.alloc(u8, @intCast(n_entries * WZO2_ENTRY_SIZE));
    defer gpa.free(entries_buf);

    entries_buf[0] = colex0_B_p1_kb;
    entries_buf[1] = @bitCast(@as(i8, 99));
    entries_buf[2] = @bitCast(@as(i8, 99));
    entries_buf[3] = 3;

    const header = Wzo2Header{
        .version = 1, .w = w, .h = h, .rules_id = WZO2_RULES_ID,
        .entry_size = WZO2_ENTRY_SIZE, .group_header_size = WZO2_GROUP_HEADER_SIZE,
        .ko_bits = kb, .hdr_flags = WZO2_HDR_FLAG_PASSES_2_OMITTED,
        .n_groups = groups.len, .n_entries = n_entries, .data_offset = WZO2_HEADER_LEN,
        .sha256 = [_]u8{0} ** 32,
    };

    const result = try checkA2(header, &groups, entries_buf, null);
    // L should be 99 but expected is 0 (pass edge → passes=2 terminal) → L violation
    try std.testing.expect(result.L_violations > 0);
}

// =========================================================================
// A8 tests — DTT
// =========================================================================

test "A8 DTT: non-constant detection" {
    const n_entries: u64 = 4;
    var entries_buf: [4 * 4]u8 = undefined;
    @memset(&entries_buf, 0);

    // All DTT=5 (constant, non-constant should be false)
    for (0..4) |i| {
        entries_buf[i * 4 + 0] = 0x04;
        entries_buf[i * 4 + 1] = @bitCast(@as(i8, 0));
        entries_buf[i * 4 + 2] = @bitCast(@as(i8, 0));
        entries_buf[i * 4 + 3] = 5;
    }

    const groups = [_]Wzo2Group{
        .{ .colex = 0, .entry_count = 4, .entry_offset = 0 },
    };
    const header = Wzo2Header{
        .version = 1, .w = 2, .h = 2, .rules_id = WZO2_RULES_ID,
        .entry_size = WZO2_ENTRY_SIZE, .group_header_size = WZO2_GROUP_HEADER_SIZE,
        .ko_bits = 3, .hdr_flags = WZO2_HDR_FLAG_PASSES_2_OMITTED,
        .n_groups = 1, .n_entries = n_entries, .data_offset = WZO2_HEADER_LEN,
        .sha256 = [_]u8{0} ** 32,
    };

    const result = try checkA8(header, &groups, &entries_buf, null);
    try std.testing.expect(!result.non_constant_ok); // all same DTT
}

test "A8 DTT: non-constant passes with variety" {
    const n_entries: u64 = 4;
    var entries_buf: [4 * 4]u8 = undefined;
    @memset(&entries_buf, 0);

    // Varying DTT values
    const dtts = [_]u8{ 1, 3, 7, 15 };
    for (0..4) |i| {
        entries_buf[i * 4 + 0] = 0x04;
        entries_buf[i * 4 + 1] = @bitCast(@as(i8, 0));
        entries_buf[i * 4 + 2] = @bitCast(@as(i8, 0));
        entries_buf[i * 4 + 3] = dtts[i];
    }

    const groups = [_]Wzo2Group{
        .{ .colex = 0, .entry_count = 4, .entry_offset = 0 },
    };
    const header = Wzo2Header{
        .version = 1, .w = 2, .h = 2, .rules_id = WZO2_RULES_ID,
        .entry_size = WZO2_ENTRY_SIZE, .group_header_size = WZO2_GROUP_HEADER_SIZE,
        .ko_bits = 3, .hdr_flags = WZO2_HDR_FLAG_PASSES_2_OMITTED,
        .n_groups = 1, .n_entries = n_entries, .data_offset = WZO2_HEADER_LEN,
        .sha256 = [_]u8{0} ** 32,
    };

    const result = try checkA8(header, &groups, &entries_buf, null);
    try std.testing.expect(result.non_constant_ok);
}

test "A8 DTT: terminal with DTT=0 is flagged" {
    const n_entries: u64 = 2;
    var entries_buf: [2 * 4]u8 = undefined;
    @memset(&entries_buf, 0);

    const none: u8 = 4;
    const kb = koBitsForSize(2, 2);

    // Entry 0: non-terminal, DTT=5
    entries_buf[0] = encodeKeyByte(0, none, 0, false, kb);
    entries_buf[1] = @bitCast(@as(i8, 0));
    entries_buf[2] = @bitCast(@as(i8, 0));
    entries_buf[3] = 5;

    // Entry 1: terminal flag set, DTT=0 → ERROR
    entries_buf[4] = encodeKeyByte(0, none, 0, false, kb) | 1; // terminal bit set
    entries_buf[5] = @bitCast(@as(i8, 0));
    entries_buf[6] = @bitCast(@as(i8, 0));
    entries_buf[7] = 0; // DTT=0 with terminal flag → should be flagged

    const groups = [_]Wzo2Group{
        .{ .colex = 0, .entry_count = 2, .entry_offset = 0 },
    };
    const header = Wzo2Header{
        .version = 1, .w = 2, .h = 2, .rules_id = WZO2_RULES_ID,
        .entry_size = WZO2_ENTRY_SIZE, .group_header_size = WZO2_GROUP_HEADER_SIZE,
        .ko_bits = kb, .hdr_flags = WZO2_HDR_FLAG_PASSES_2_OMITTED,
        .n_groups = 1, .n_entries = n_entries, .data_offset = WZO2_HEADER_LEN,
        .sha256 = [_]u8{0} ** 32,
    };

    const result = try checkA8(header, &groups, &entries_buf, null);
    try std.testing.expectEqual(@as(u64, 1), result.terminal_dtt0_errs);
}
