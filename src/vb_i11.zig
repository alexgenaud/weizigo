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
// VB_I11 — move-set consistency check (T346, G3b pass0, set E).
//
// Author: deepseek-v4-pro/T346 (I11 author C; distinct from MG-KERN author A
// and R8 author B — plan §6).
//
// Compares the battery's independent legal-move set (R8, src/vb_movegen.zig)
// against the kernel's (src/rules.zig), both via direct comparison (2×2, 3×2,
// 3×3, 4×3 exhaustive) and via SMD1 dump files (4×4 sampled, 50k stratified).
//
// NULL CONTROL (spec §4.1): compare kernel vs SMD1 (both kernel) at 2×2 → 0
// mismatches vacuously. Proves the harness is sensitive to independence.
//
// SEEDED-DEFECT CONTROL (spec §4.2): synthetic defective move generator
// (allows one suicide at a known state) → mismatches > 0 caught at 2×2.
//
// LADDER (spec §7):
//   Rung 1 (2×2): exhaustive, null + seeded-defect controls
//   Rung 2 (3×2): exhaustive
//   Rung 3 (3×3): exhaustive
//   Rung 4 (4×3): exhaustive (direct comparison; SMD1 tool does not yet
//                  support 4×3 — T341 restriction, noted as D026 finding)
//   Rung 5 (4×4): sampled 50k via SMD1 dump (stratified, seed 31337)
//
// STANDALONE TESTS:
//   zig test --dep vb_movegen --dep engine \
//     -Mroot=src/vb_i11.zig \
//     -Mvb_movegen=src/vb_movegen.zig \
//     -Mengine=src/smd1_engine.zig
//
// TODO: wire into build.zig by sprint console.

const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

// R8 — the battery's independent move generator (T340).
const vb_movegen = @import("vb_movegen.zig");

// Kernel move generator (via smd1_engine re-export — rules.zig, T339/MG-KERN).
const engine = @import("engine");
const kernel_rules = engine.rules;

// ═══════════════════════════════════════════════════════════════════════════
//  SMD1 FORMAT CONSTANTS (design-M1 §4.6)
// ═══════════════════════════════════════════════════════════════════════════

const SMD1_MAGIC = [_]u8{ 'S', 'M', 'D', '1' };
const SMD1_VERSION: u8 = 1;
const SMD1_HEADER_LEN: usize = 28;
const SLICE_KO_NONE: u8 = 255;
const SLICE_PASSES: u8 = 0;

// ═══════════════════════════════════════════════════════════════════════════
//  SMD1 READER
// ═══════════════════════════════════════════════════════════════════════════

const Smd1Header = struct {
    w: u8,
    h: u8,
    colex_bytes: u8,
    moves_bytes: u8,
    record_count: u32,
    record_bytes: []const u8, // slice into the file bytes
};

const Smd1Error = error{
    BadMagic,
    BadVersion,
    BadGoban,
    BadSlice,
    BadCrc,
    Truncated,
};

/// Validate and parse an SMD1 file header. Returns the parsed header fields
/// and a slice of the record bytes (CRC-validated).
fn smd1Validate(bytes: []const u8, w: usize, h: usize) Smd1Error!Smd1Header {
    if (bytes.len < SMD1_HEADER_LEN) return error.Truncated;
    if (!std.mem.eql(u8, bytes[0..4], &SMD1_MAGIC)) return error.BadMagic;
    if (bytes[4] != SMD1_VERSION) return error.BadVersion;
    if (bytes[5] != @as(u8, @intCast(w)) or bytes[6] != @as(u8, @intCast(h))) return error.BadGoban;
    const cb: usize = bytes[7];
    const mb: usize = bytes[8];
    if (bytes[9] != 0 or bytes[10] != 0 or bytes[11] != 0) return error.Truncated;
    const record_count = std.mem.readInt(u32, bytes[12..16], .little);
    if (bytes[16] != SLICE_KO_NONE or bytes[17] != 0 or bytes[18] != 0 or bytes[19] != 0)
        return error.BadSlice;
    if (bytes[20] != SLICE_PASSES or bytes[21] != 0 or bytes[22] != 0 or bytes[23] != 0)
        return error.BadSlice;
    const stored_crc = std.mem.readInt(u32, bytes[24..28], .little);
    const rec_len: usize = @as(usize, record_count) * (cb + 1 + mb);
    if (bytes.len != SMD1_HEADER_LEN + rec_len + 4) return error.Truncated;
    const record_bytes = bytes[SMD1_HEADER_LEN..][0..rec_len];
    var crc = std.hash.crc.Crc32IsoHdlc.init();
    crc.update(record_bytes);
    if (crc.final() != stored_crc) return error.BadCrc;
    const trailing = std.mem.readInt(u32, bytes[SMD1_HEADER_LEN + rec_len ..][0..4], .little);
    if (trailing != stored_crc) return error.BadCrc;
    return .{
        .w = @intCast(w),
        .h = @intCast(h),
        .colex_bytes = @intCast(cb),
        .moves_bytes = @intCast(mb),
        .record_count = record_count,
        .record_bytes = record_bytes,
    };
}

/// Read a single SMD1 record at `offset` within the record block.
fn smd1ReadRecord(hdr: Smd1Header, offset: usize) struct { colex_idx: u64, side: i8, bitmap: []const u8 } {
    const rec_size = @as(usize, hdr.colex_bytes) + 1 + hdr.moves_bytes;
    const rec = hdr.record_bytes[offset..][0..rec_size];

    // colex_idx: little-endian, colex_bytes wide
    var colex_idx: u64 = 0;
    for (0..hdr.colex_bytes) |i| {
        colex_idx |= @as(u64, rec[i]) << @intCast(i * 8);
    }

    // side: 1 = Black, 2 = White
    const side: i8 = if (rec[hdr.colex_bytes] == 1) @as(i8, 1) else @as(i8, -1);

    // bitmap: moves_bytes wide
    const bitmap = rec[hdr.colex_bytes + 1 ..][0..hdr.moves_bytes];

    return .{ .colex_idx = colex_idx, .side = side, .bitmap = bitmap };
}

/// True iff bit `i` is set in `bm`. LSB of byte 0 is bit 0.
fn bitSet(bm: []const u8, i: usize) bool {
    return bm[i / 8] & (@as(u8, 1) << @intCast(i % 8)) != 0;
}

// ═══════════════════════════════════════════════════════════════════════════
//  COMPARISON ENGINE
// ═══════════════════════════════════════════════════════════════════════════

/// Result of comparing two move generators over a set of states.
const CmpResult = struct {
    mismatches: u64,
    total: u64,
    /// First few mismatch examples: (colex_idx, side, which_bit_differed)
    examples: [5]Mismatch,
    example_count: usize,

    const Mismatch = struct {
        colex_idx: u64,
        side: i8,
        r8_has_solver_lacks: u8, // bits in R8 not in SMD1/kernel
        solver_has_r8_lacks: u8, // bits in SMD1/kernel not in R8
    };
};

/// Compare R8 against an SMD1 dump file.
/// `bytes` = the full SMD1 file contents.
fn compareSmd1(comptime w: usize, comptime h: usize, bytes: []const u8) !CmpResult {
    const hdr = try smd1Validate(bytes, w, h);
    const rec_size: usize = @as(usize, hdr.colex_bytes) + 1 + hdr.moves_bytes;
    var res = CmpResult{ .mismatches = 0, .total = 0, .examples = undefined, .example_count = 0 };

    var offset: usize = 0;
    while (offset < hdr.record_bytes.len) : (offset += rec_size) {
        const rec = smd1ReadRecord(hdr, offset);
        const pos = vb_movegen.posFromColex(w, h, rec.colex_idx);

        // R8 side
        const r8_state: vb_movegen.State(w, h) = .{
            .pos = pos,
            .side = rec.side,
            .ko = @as(u8, @intCast(w * h)), // ko=NONE at the artifact slice
            .passes = 0,
        };
        const r8_bm = vb_movegen.legalMoves(w, h, r8_state);

        // Compare bitmaps
        const n = w * h;
        var mismatch = false;
        for (0..n + 1) |i| {
            const r8_has = bitSet(&r8_bm, i);
            const smd1_has = bitSet(rec.bitmap, i);
            if (r8_has != smd1_has) {
                mismatch = true;
            }
        }

        if (mismatch) {
            res.mismatches += 1;
            if (res.example_count < 5) {
                var r8_extra: u8 = 0;
                var smd1_extra: u8 = 0;
                for (0..@min(n + 1, 8)) |i| {
                    const r8_has = bitSet(&r8_bm, i);
                    const smd1_has = bitSet(rec.bitmap, i);
                    if (r8_has and !smd1_has) r8_extra |= @as(u8, 1) << @intCast(i);
                    if (!r8_has and smd1_has) smd1_extra |= @as(u8, 1) << @intCast(i);
                }
                res.examples[res.example_count] = .{
                    .colex_idx = rec.colex_idx,
                    .side = rec.side,
                    .r8_has_solver_lacks = r8_extra,
                    .solver_has_r8_lacks = smd1_extra,
                };
                res.example_count += 1;
            }
        }
        res.total += 1;
    }
    return res;
}

/// Null-control compare: kernel vs SMD1 (both kernel-generated).
/// Uses the kernel's own legalMoves instead of R8. Must return 0 mismatches.
fn compareSmd1Null(comptime w: usize, comptime h: usize, bytes: []const u8) !CmpResult {
    const hdr = try smd1Validate(bytes, w, h);
    const R = kernel_rules.Rules(w, h);
    const ko_none = R.ko_none();
    const rec_size: usize = @as(usize, hdr.colex_bytes) + 1 + hdr.moves_bytes;
    var res = CmpResult{ .mismatches = 0, .total = 0, .examples = undefined, .example_count = 0 };

    var offset: usize = 0;
    while (offset < hdr.record_bytes.len) : (offset += rec_size) {
        const rec = smd1ReadRecord(hdr, offset);
        const X = engine.colex.Indexer(w, h);
        const pos = X.pos_from_colex(rec.colex_idx);

        // Kernel side — same implementation that generated the SMD1 dump
        const kernel_bm = R.legalMoves(&pos, rec.side, ko_none, 0);

        const n = w * h;
        var mismatch = false;
        for (0..n + 1) |i| {
            if (bitSet(kernel_bm[0..], i) != bitSet(rec.bitmap, i)) {
                mismatch = true;
            }
        }

        if (mismatch) {
            res.mismatches += 1;
            if (res.example_count < 5) {
                res.examples[res.example_count] = .{
                    .colex_idx = rec.colex_idx,
                    .side = rec.side,
                    .r8_has_solver_lacks = 0,
                    .solver_has_r8_lacks = 0,
                };
                res.example_count += 1;
            }
        }
        res.total += 1;
    }
    return res;
}

/// Direct comparison of R8 vs kernel for exhaustive gobans (2×2, 3×2, 3×3,
/// 4×3). Iterates every legal position at the artifact slice (ko=NONE,
/// passes=0) for both sides.
fn compareDirect(comptime w: usize, comptime h: usize) !CmpResult {
    const R = kernel_rules.Rules(w, h);
    const X = engine.colex.Indexer(w, h);
    const E = engine.enumerate.Enumerator(w, h);
    const ko_none = R.ko_none();
    const n = w * h;
    var res = CmpResult{ .mismatches = 0, .total = 0, .examples = undefined, .example_count = 0 };

    var colex_idx: u64 = 0;
    while (colex_idx < X.total) : (colex_idx += 1) {
        const pos = X.pos_from_colex(colex_idx);
        if (!E.is_legal(&pos)) continue;

        // Check both sides
        inline for (&[_]i8{ 1, -1 }) |side| {
            // Kernel side
            const kernel_bm = R.legalMoves(&pos, side, ko_none, 0);

            // R8 side
            const r8_state: vb_movegen.State(w, h) = .{
                .pos = pos,
                .side = side,
                .ko = @as(u8, @intCast(n)), // ko=NONE at the artifact slice
                .passes = 0,
            };
            const r8_bm = vb_movegen.legalMoves(w, h, r8_state);

            // Compare
            var mismatch = false;
            for (0..n + 1) |i| {
                if (bitSet(kernel_bm[0..], i) != bitSet(&r8_bm, i)) {
                    mismatch = true;
                }
            }

            if (mismatch) {
                res.mismatches += 1;
                if (res.example_count < 5) {
                    var r8_extra: u8 = 0;
                    var kernel_extra: u8 = 0;
                    for (0..@min(n + 1, 8)) |i| {
                        const r8_has = bitSet(&r8_bm, i);
                        const k_has = bitSet(kernel_bm[0..], i);
                        if (r8_has and !k_has) r8_extra |= @as(u8, 1) << @intCast(i);
                        if (!r8_has and k_has) kernel_extra |= @as(u8, 1) << @intCast(i);
                    }
                    res.examples[res.example_count] = .{
                        .colex_idx = colex_idx,
                        .side = side,
                        .r8_has_solver_lacks = r8_extra,
                        .solver_has_r8_lacks = kernel_extra,
                    };
                    res.example_count += 1;
                }
            }
            res.total += 1;
        }
    }
    return res;
}

/// Seeded-defect control: a synthetic defective move generator that allows
/// a suicide placement. Wraps R8 but forces one specific cell to be legal
/// when it should be illegal (suicide).
fn defectiveLegalMoves(
    comptime w: usize,
    comptime h: usize,
    s: vb_movegen.State(w, h),
    trigger_colex: u64,
    trigger_cell: usize,
) [vb_movegen.movesBytes(w, h)]u8 {
    var bm = vb_movegen.legalMoves(w, h, s);
    // Check if we're at the trigger state: use the position's colex index
    const idx = vb_movegen.colexFromPos(w, h, &s.pos);
    if (idx == trigger_colex and s.side == 1 and s.ko >= @as(u8, @intCast(w * h)) and s.passes == 0) {
        // Force trigger_cell to be legal (allowing suicide)
        bm[trigger_cell / 8] |= @as(u8, 1) << @intCast(trigger_cell % 8);
    }
    return bm;
}

/// Seeded-defect comparison: compare the defective move generator against
/// the kernel at a specific goban. Must find mismatches > 0.
fn compareDefective(
    comptime w: usize,
    comptime h: usize,
    trigger_colex: u64,
    trigger_cell: usize,
) !CmpResult {
    const R = kernel_rules.Rules(w, h);
    const X = engine.colex.Indexer(w, h);
    const E = engine.enumerate.Enumerator(w, h);
    const ko_none = R.ko_none();
    const n = w * h;
    var res = CmpResult{ .mismatches = 0, .total = 0, .examples = undefined, .example_count = 0 };

    var colex_idx: u64 = 0;
    while (colex_idx < X.total) : (colex_idx += 1) {
        const pos = X.pos_from_colex(colex_idx);
        if (!E.is_legal(&pos)) continue;

        inline for (&[_]i8{ 1, -1 }) |side| {
            const kernel_bm = R.legalMoves(&pos, side, ko_none, 0);

            const r8_state: vb_movegen.State(w, h) = .{
                .pos = pos,
                .side = side,
                .ko = @as(u8, @intCast(n)),
                .passes = 0,
            };
            const def_bm = defectiveLegalMoves(w, h, r8_state, trigger_colex, trigger_cell);

            var mismatch = false;
            for (0..n + 1) |i| {
                if (bitSet(kernel_bm[0..], i) != bitSet(&def_bm, i)) {
                    mismatch = true;
                }
            }

            if (mismatch) {
                res.mismatches += 1;
                if (res.example_count < 5) {
                    var def_extra: u8 = 0;
                    var kernel_extra: u8 = 0;
                    for (0..@min(n + 1, 8)) |i| {
                        const def_has = bitSet(&def_bm, i);
                        const k_has = bitSet(kernel_bm[0..], i);
                        if (def_has and !k_has) def_extra |= @as(u8, 1) << @intCast(i);
                        if (!def_has and k_has) kernel_extra |= @as(u8, 1) << @intCast(i);
                    }
                    res.examples[res.example_count] = .{
                        .colex_idx = colex_idx,
                        .side = side,
                        .r8_has_solver_lacks = def_extra,
                        .solver_has_r8_lacks = kernel_extra,
                    };
                    res.example_count += 1;
                }
            }
            res.total += 1;
        }
    }
    return res;
}

// ═══════════════════════════════════════════════════════════════════════════
//  TEST HELPERS
// ═══════════════════════════════════════════════════════════════════════════

/// Read a file at runtime using page_allocator + Threaded IO.
fn readFile(path: []const u8) ![]u8 {
    const gpa = std.heap.page_allocator;
    var threaded = std.Io.Threaded.init(gpa, .{});
    defer threaded.deinit();
    const io = threaded.io();
    const cwd = std.Io.Dir.cwd();
    return try cwd.readFileAlloc(io, path, gpa, .unlimited);
}

/// Free file bytes allocated by page_allocator.
fn freeFile(bytes: []u8) void {
    std.heap.page_allocator.free(bytes);
}

// ═══════════════════════════════════════════════════════════════════════════
//  TESTS
// ═══════════════════════════════════════════════════════════════════════════

// ---- SMD1 parser ---------------------------------------------------------

test "vb_i11: SMD1 2x2 validate" {
    const path = "/tmp/weizigo/oracle-2x2-exhaustive.smd1";
    const bytes = try readFile(path);
    defer freeFile(bytes);
    const hdr = try smd1Validate(bytes, 2, 2);
    try expectEqual(@as(u8, 2), hdr.w);
    try expectEqual(@as(u8, 2), hdr.h);
    try expectEqual(@as(u8, 1), hdr.colex_bytes);
    try expectEqual(@as(u8, 1), hdr.moves_bytes);
    // 2×2: 114 positions × 2 sides = 228 records (per T341 smoke)
    // 57 legal positions × 2 sides = 114 records
    try expectEqual(@as(u32, 114), hdr.record_count);
    const rec_size: usize = @as(usize, hdr.colex_bytes) + 1 + hdr.moves_bytes;
    try expectEqual(@as(usize, hdr.record_count) * rec_size, hdr.record_bytes.len);
}

test "vb_i11: SMD1 3x2 validate" {
    const path = "/tmp/weizigo/oracle-3x2-exhaustive.smd1";
    const bytes = try readFile(path);
    defer freeFile(bytes);
    const hdr = try smd1Validate(bytes, 3, 2);
    try expectEqual(@as(u8, 3), hdr.w);
    try expectEqual(@as(u8, 2), hdr.h);
    try expectEqual(@as(u8, 4), hdr.colex_bytes);
    try expectEqual(@as(u8, 1), hdr.moves_bytes);
}

test "vb_i11: SMD1 3x3 validate" {
    const path = "/tmp/weizigo/oracle-3x3-exhaustive.smd1";
    const bytes = try readFile(path);
    defer freeFile(bytes);
    const hdr = try smd1Validate(bytes, 3, 3);
    try expectEqual(@as(u8, 3), hdr.w);
    try expectEqual(@as(u8, 3), hdr.h);
    try expectEqual(@as(u8, 4), hdr.colex_bytes);
}

test "vb_i11: SMD1 4x4 validate" {
    const path = "/tmp/weizigo/oracle-4x4-sample-s31337-n50000.smd1";
    const bytes = try readFile(path);
    defer freeFile(bytes);
    const hdr = try smd1Validate(bytes, 4, 4);
    try expectEqual(@as(u8, 4), hdr.w);
    try expectEqual(@as(u8, 4), hdr.h);
    try expectEqual(@as(u8, 8), hdr.colex_bytes);
    try expectEqual(@as(u8, 3), hdr.moves_bytes);
    try expectEqual(@as(u32, 50000), hdr.record_count);
}

// ---- NULL CONTROL: kernel vs SMD1 (both kernel) — must be 0 ------------

test "vb_i11: NULL CONTROL — kernel vs SMD1 at 2x2 → 0 mismatches" {
    const path = "/tmp/weizigo/oracle-2x2-exhaustive.smd1";
    const bytes = try readFile(path);
    defer freeFile(bytes);
    const res = try compareSmd1Null(2, 2, bytes);
    try expectEqual(@as(u64, 0), res.mismatches);
    // 57 legal positions × 2 sides = 114 records
    try expectEqual(@as(u64, 114), res.total);
}

test "vb_i11: NULL CONTROL — kernel vs SMD1 at 3x2 → 0 mismatches" {
    const path = "/tmp/weizigo/oracle-3x2-exhaustive.smd1";
    const bytes = try readFile(path);
    defer freeFile(bytes);
    const res = try compareSmd1Null(3, 2, bytes);
    try expectEqual(@as(u64, 0), res.mismatches);
}

test "vb_i11: NULL CONTROL — kernel vs SMD1 at 3x3 → 0 mismatches" {
    const path = "/tmp/weizigo/oracle-3x3-exhaustive.smd1";
    const bytes = try readFile(path);
    defer freeFile(bytes);
    const res = try compareSmd1Null(3, 3, bytes);
    try expectEqual(@as(u64, 0), res.mismatches);
}

// ---- SEEDED-DEFECT CONTROL: synthetic defective → mismatches > 0 --------

test "vb_i11: SEEDED-DEFECT — allows suicide at 2x2 → mismatches > 0" {
    // 2×2, cells: 0 1 / 2 3.
    // Trigger position: empty at 0, W at 1, W at 2, empty at 3.
    // Black plays at 3: neighbours are 1 (W) and 2 (W), no captures
    // possible (W at 1 has liberty at 0; W at 2 has liberty at 0).
    // The placed B stone at 3 has no liberties → suicide.
    // Defective generator forces cell 3 to be legal.
    const w = 2;
    const h = 2;
    const X = engine.colex.Indexer(w, h);
    var pos: [4]i8 = [_]i8{ 0, -1, -1, 0 }; // W at 1, W at 2
    const trigger_colex = X.colex_from_pos(&pos);

    // Verify this position is legal (no stone has 0 liberties)
    const E = engine.enumerate.Enumerator(w, h);
    try expect(E.is_legal(&pos));

    // Run the defective comparison
    const res = try compareDefective(w, h, trigger_colex, 3);
    // Must find at least 1 mismatch (the forced suicide at cell 3
    // should show up for Black-to-move at this position)
    try expect(res.mismatches > 0);

    // The mismatch should include cell 3 as the extra bit
    const first = res.examples[0];
    try expect(first.r8_has_solver_lacks & (@as(u8, 1) << 3) != 0);
}

// ---- I11: 2×2 exhaustive — R8 vs kernel direct ------------------------

test "vb_i11: I11 2×2 EXHAUSTIVE — R8 vs kernel → 0 mismatches" {
    const res = try compareDirect(2, 2);
    try expectEqual(@as(u64, 0), res.mismatches);
    // 57 legal positions × 2 sides = 114
    try expectEqual(@as(u64, 114), res.total);
}

// ---- I11: 3×2 exhaustive — R8 vs kernel direct ------------------------

test "vb_i11: I11 3×2 EXHAUSTIVE — R8 vs kernel → 0 mismatches" {
    const res = try compareDirect(3, 2);
    try expectEqual(@as(u64, 0), res.mismatches);
    // 489 legal positions × 2 sides = 978
    try expectEqual(@as(u64, 978), res.total);
}

// ---- I11: 3×3 exhaustive — R8 vs kernel direct ------------------------

test "vb_i11: I11 3×3 EXHAUSTIVE — R8 vs kernel → 0 mismatches" {
    const res = try compareDirect(3, 3);
    try expectEqual(@as(u64, 0), res.mismatches);
    // 12675 legal positions × 2 sides = 25350
    try expectEqual(@as(u64, 25350), res.total);
}

// ---- I11: 4×3 exhaustive — R8 vs kernel direct (D026 rung 4) ----------

test "vb_i11: I11 4×3 EXHAUSTIVE — R8 vs kernel → 0 mismatches" {
    const res = try compareDirect(4, 3);
    try expectEqual(@as(u64, 0), res.mismatches);
    // 321,689 legal positions × 2 sides = 643,378 total (measured)
    try expectEqual(@as(u64, 643378), res.total);
}

// ---- I11: 4×4 sampled — R8 vs SMD1 file ---------------------------------

test "vb_i11: I11 4×4 SAMPLED — R8 vs SMD1 (50k stratified) → 0 mismatches" {
    const path = "/tmp/weizigo/oracle-4x4-sample-s31337-n50000.smd1";
    const bytes = try readFile(path);
    defer freeFile(bytes);
    const res = try compareSmd1(4, 4, bytes);
    try expectEqual(@as(u64, 0), res.mismatches);
    try expectEqual(@as(u64, 50000), res.total);
}

// ---- Cross-check: 3×3 SMD1 vs R8 (confirms SMD1 comparison path works) --

test "vb_i11: I11 3×3 SMD1 cross-check — R8 vs SMD1 → 0 mismatches" {
    const path = "/tmp/weizigo/oracle-3x3-exhaustive.smd1";
    const bytes = try readFile(path);
    defer freeFile(bytes);
    const res = try compareSmd1(3, 3, bytes);
    try expectEqual(@as(u64, 0), res.mismatches);
}
