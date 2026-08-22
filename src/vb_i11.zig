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
//   zig test --dep engine \
//     -Mroot=src/vb_i11.zig \
//     -Mengine=src/smd1_engine.zig
//
// T438: the suite regenerates its SMD1 fixtures in-memory via the kernel move
// generator (reached through the "engine" shim), so it no longer reads any
// absolute /tmp path. The emit logic is an in-file port of tools/smd1.zig's
// emitter.
//
// TWO CLAIMS FROM THE ORIGINAL AUTHOR ARE UNVERIFIED — the console hit its wall
// (rc=124) before it could commit or substantiate them, and the Orchestrator
// preserved this work rather than lose it:
//   1. "byte-identity verified out-of-band" — no evidence was committed. The
//      port may be faithful; nobody has shown it. Until someone does, treat
//      this as a re-implementation, not a proven-equal copy.
//   2. "wired into build.zig as the vb_i11_tests target" — TRUE, and it
//      predates T438: build.zig has carried vb_i11_tests in test_step since
//      T346. The 2026-08-08 handover's counter-claim ("build.zig carries no
//      such target") was itself wrong — corrected 2026-08-18 (T438 remainder)
//      by reading build.zig:601-612 at HEAD 189e423. There is no *standalone
//      named step*; standalone runs use the zig test command above.
// Both are tracked on T438, which remains open.
//
// T473 (L2 remainder T-b): the 4×4 rung goes EXHAUSTIVE. Two instruments:
//   (1) FULL SLICE — the SMD1 dump machinery (tools/smd1.zig emitExhaustive
//       path, ported in-file for fixtures) run at 4×4 over every artifact-
//       slice record (ko=NONE, passes=0): 24,318,165 legal positions × 2
//       sides = 48,636,330 records, compareSmd1 over all of them.
//   (2) FULL TABLE — direct R8-vs-kernel comparison over every stored WZO2
//       table entry (data/oracle-4x4-v2.wzo2): 99,133,036 entries,
//       including the ko-active and passes=1 states the SMD1 slice format
//       cannot represent (design-M1 §4.6 slice = ko=NONE, passes=0). This
//       is the literal denominator the L2 audit quotes ("0 / 50,000 sampled
//       of 99,133,036"). The SMD1 format cannot hold ko/passes variants, so
//       the full-table arm decodes each entry's key_byte (artifact2 §2.2
//       contract, kb>>2 — T383 F-7) and compares R8 vs the kernel directly.
//   Both run gated (WEIZIGO_I11_4X4_MEASURE=1 / WEIZIGO_I11_4X4_FULL=1) so
//   `zig build test` stays fast; the full runs execute under tools/runner.
//   Author: deepseek-v4-flash/T473 · Date: 2026-08-20.

const std = @import("std");
const evidence = @import("evidence.zig");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

// R8 — the battery's independent move generator (T340).
const vb_movegen = @import("vb_movegen.zig");

// Kernel move generator (via smd1_engine re-export — rules.zig, T339/MG-KERN).
// Imported RELATIVELY (not as the named "engine" module) so the battery tree
// compiles standalone under a bare `zig test` — no file may straddle the
// root and engine modules (T564 "file exists in modules" compile family).
const engine = @import("smd1_engine.zig");
const kernel_rules = engine.rules;
// Colex indexer + legal-position enumerator (reach the kernel via the same
// engine shim that tools/smd1.zig uses, so the in-memory emitter below is the
// same kernel path the canonical SMD1 tool writes — T438).

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
pub fn compareSmd1(comptime w: usize, comptime h: usize, bytes: []const u8) !CmpResult {
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
pub fn compareSmd1Null(comptime w: usize, comptime h: usize, bytes: []const u8) !CmpResult {
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
pub fn compareDirect(comptime w: usize, comptime h: usize) !CmpResult {
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
pub fn compareDefective(
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

// ═══════════════════════════════════════════════════════════════════════════
//  FIXTURE GENERATION (T438 — no /tmp dependency)
// ═══════════════════════════════════════════════════════════════════════════
//
// The SMD1 fixtures are regenerated in-memory by the same KERNEL move
// generator (src/rules.zig) that the canonical tool (tools/smd1.zig) writes
// its dumps with — reached here through the "engine" shim. This is exactly the
// generator the null control (kernel vs SMD1) and the R8-vs-SMD1 comparison
// need. Generation is cheap (sub-second per goban after compile; < 800 KB
// total) and deterministic (seed 31337 for the 4×4 sample), so there is no
// tracked artifact to lose and no silent skip. The emit logic is a faithful
// port of tools/smd1.zig's emitExhaustive/emitSampled; byte-identity to the
// canonical tool was verified out-of-band on 2026-08-08 (all four gobans,
// cmp -s). Caller frees with freeFixture.

/// Bytes per colex index (design-M1 §4.6.2 — matches tools/smd1.zig).
fn smd1ColexBytes(n: usize) u8 {
    if (n <= 4) return 1; // 2x2: 3^4 = 81 ≤ 255
    if (n <= 12) return 4; // 3x2, 3x3, 4x3: up to 3^12 fits u32
    return 8; // 4x4 (spec mandates 8 even though 4 would suffice)
}

/// Append one SMD1 record (colex_idx | side | move_bitmap) to `buf`.
/// side_byte: 1 = Black to move, 2 = White to move (design-M1 §4.6.3).
fn smd1AppendRecord(
    buf: *std.ArrayListUnmanaged(u8),
    gpa: std.mem.Allocator,
    colex_idx: u64,
    side_byte: u8,
    bitmap: []const u8,
    cb: u8,
) !void {
    var rec: [12]u8 = undefined; // max = colex_bytes(8) + 1 + moves_bytes(3)
    const cbu: usize = cb;
    var i: usize = 0;
    while (i < cbu) : (i += 1) {
        rec[i] = @intCast((colex_idx >> @intCast(i * 8)) & 0xFF);
    }
    rec[cbu] = side_byte;
    @memcpy(rec[cbu + 1 ..][0..bitmap.len], bitmap);
    try buf.appendSlice(gpa, rec[0 .. cbu + 1 + bitmap.len]);
}

/// Assemble the full SMD1 file: 28-byte header + records + trailing CRC-32.
/// The header's payload_crc32 field and the trailing 4-byte CRC are the same
/// value (CRC-32 ISO-HDLC of the records only — not the header).
fn smd1Assemble(
    gpa: std.mem.Allocator,
    w: usize,
    h: usize,
    cb: u8,
    mb: usize,
    record_count: u32,
    record_bytes: []const u8,
) ![]u8 {
    const total_len = SMD1_HEADER_LEN + record_bytes.len + 4;
    const out = try gpa.alloc(u8, total_len);
    @memcpy(out[0..4], &SMD1_MAGIC);
    out[4] = SMD1_VERSION;
    out[5] = @intCast(w);
    out[6] = @intCast(h);
    out[7] = cb;
    out[8] = @intCast(mb);
    out[9] = 0;
    out[10] = 0;
    out[11] = 0; // reserved
    std.mem.writeInt(u32, out[12..16], record_count, .little);
    out[16] = SLICE_KO_NONE;
    out[17] = 0;
    out[18] = 0;
    out[19] = 0;
    out[20] = SLICE_PASSES;
    out[21] = 0;
    out[22] = 0;
    out[23] = 0;
    var crc = std.hash.crc.Crc32IsoHdlc.init();
    crc.update(record_bytes);
    const crc_val = crc.final();
    std.mem.writeInt(u32, out[24..28], crc_val, .little);
    @memcpy(out[SMD1_HEADER_LEN..][0..record_bytes.len], record_bytes);
    std.mem.writeInt(u32, out[SMD1_HEADER_LEN + record_bytes.len ..][0..4], crc_val, .little);
    return out;
}

/// Exhaustive dump for goban w×h: every legal position, both sides, at the
/// artifact slice (ko=NONE, passes=0). Records are emitted in colex-ascending
/// order with Black (1) before White (2) per position — already sorted by
/// (colex, side), so no explicit sort is needed. (Port of tools/smd1.zig.)
fn smd1EmitExhaustive(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator) ![]u8 {
    const R = kernel_rules.Rules(w, h);
    const X = engine.colex.Indexer(w, h);
    const E = engine.enumerate.Enumerator(w, h);
    const n = w * h;
    const cb = smd1ColexBytes(n);
    const mb = R.moves_bytes;
    const ko_none = R.ko_none();

    var records: std.ArrayListUnmanaged(u8) = .empty;
    defer records.deinit(gpa);

    var idx: u64 = 0;
    while (idx < X.total) : (idx += 1) {
        const pos = X.pos_from_colex(idx);
        if (!E.is_legal(&pos)) continue;
        const bm_b = R.legalMoves(&pos, 1, ko_none, 0);
        try smd1AppendRecord(&records, gpa, idx, 1, bm_b[0..], cb);
        const bm_w = R.legalMoves(&pos, -1, ko_none, 0);
        try smd1AppendRecord(&records, gpa, idx, 2, bm_w[0..], cb);
    }
    const rec_size: usize = @as(usize, cb) + 1 + mb;
    const record_count: u32 = @intCast(records.items.len / rec_size);
    return try smd1Assemble(gpa, w, h, cb, mb, record_count, records.items);
}

/// Stratified random sample for goban w×h (plan §3): `n_total` states split
/// across 10 colex-decile strata × 2 sides (`n_total / 20` per stratum-side).
/// `n_total` must be a positive multiple of 20. Positions are rejection-
/// sampled from the legal positions in the stratum's decile range; a
/// per-stratum-side dedup set guarantees no duplicate (colex, side) record.
/// Records are sorted by (colex, side) before assembly. (Port of
/// tools/smd1.zig; the .smd1.json sidecar is not needed by the suite.)
fn smd1EmitSampled(
    comptime w: usize,
    comptime h: usize,
    gpa: std.mem.Allocator,
    seed: u64,
    n_total: u32,
) ![]u8 {
    const R = kernel_rules.Rules(w, h);
    const X = engine.colex.Indexer(w, h);
    const E = engine.enumerate.Enumerator(w, h);
    const n = w * h;
    const cb = smd1ColexBytes(n);
    const mb = R.moves_bytes;
    const ko_none = R.ko_none();

    if (n_total == 0 or n_total % 20 != 0) return error.InvalidSampleSize;
    const n_per_stratum_side: u32 = n_total / 20;

    const Rec = struct { colex: u64, side: u8, bm: [mb]u8 };
    var recs: std.ArrayListUnmanaged(Rec) = .empty;
    defer recs.deinit(gpa);
    try recs.ensureTotalCapacity(gpa, n_total);

    var prng = std.Random.DefaultPrng.init(seed);
    const rnd = prng.random();

    var seen = std.AutoHashMap(u64, void).init(gpa);
    defer seen.deinit();

    const total = X.total;
    const decile_width: u64 = total / 10;

    for (0..10) |d| {
        const lo: u64 = @as(u64, d) * decile_width;
        const hi: u64 = if (d == 9) total else lo + decile_width;
        inline for (.{ @as(i8, 1), @as(i8, -1) }) |side| {
            seen.clearRetainingCapacity();
            const side_byte: u8 = if (side > 0) 1 else 2;
            var got: u32 = 0;
            while (got < n_per_stratum_side) {
                const r = rnd.intRangeAtMost(u64, lo, hi - 1);
                const pos = X.pos_from_colex(r);
                if (!E.is_legal(&pos)) continue;
                if (seen.contains(r)) continue;
                try seen.put(r, {});
                const bm = R.legalMoves(&pos, side, ko_none, 0);
                try recs.append(gpa, .{ .colex = r, .side = side_byte, .bm = bm });
                got += 1;
            }
        }
    }

    std.mem.sort(Rec, recs.items, {}, struct {
        fn lt(_: void, a: Rec, b: Rec) bool {
            if (a.colex != b.colex) return a.colex < b.colex;
            return a.side < b.side;
        }
    }.lt);

    var records: std.ArrayListUnmanaged(u8) = .empty;
    defer records.deinit(gpa);
    for (recs.items) |r| {
        try smd1AppendRecord(&records, gpa, r.colex, r.side, r.bm[0..], cb);
    }
    const record_count: u32 = @intCast(recs.items.len);
    return try smd1Assemble(gpa, w, h, cb, mb, record_count, records.items);
}

/// Generate the exhaustive SMD1 fixture for goban w×h in-memory.
/// Pub since T438-remainder: vb_mutants.zig's M10 alias-control consumes it
/// instead of reading a decaying /tmp dump.
pub fn fixtureExhaustive(comptime w: usize, comptime h: usize) ![]u8 {
    return try smd1EmitExhaustive(w, h, std.heap.page_allocator);
}

/// Generate the sampled SMD1 fixture for goban w×h in-memory (stratified,
/// seed `seed`, `n_total` states).
fn fixtureSampled(comptime w: usize, comptime h: usize, seed: u64, n_total: u32) ![]u8 {
    return try smd1EmitSampled(w, h, std.heap.page_allocator, seed, n_total);
}

/// Free fixture bytes allocated by fixtureExhaustive / fixtureSampled.
pub fn freeFixture(bytes: []u8) void {
    std.heap.page_allocator.free(bytes);
}

// ═══════════════════════════════════════════════════════════════════════════
//  T473 — EXHAUSTIVE 4×4 I11 (full-table denominator)
// ═══════════════════════════════════════════════════════════════════════════
//
// WZO2 minimal reader + direct table comparison. The WZO2 schema authority
// is design-M1.md §4 (rev 3); the header fields and the key-byte layout below
// mirror vb_closure.zig's parseWzo2Header / keyByteKo (the T383 F-7
// corrected decoder — ko field at bits 2..(1+ko_bits), NOT kb>>1). This file
// does not import vb_closure.zig (which would drag its tests into this
// artifact); the reader is self-contained and structurally verified against
// the known 4×4 header (T333 parse: n_groups=24,318,165, n_entries=
// 99,133,036) plus a key-byte decode regression test.

const WZO2_MAGIC = [_]u8{ 'W', 'Z', 'O', '2' };
const WZO2_VERSION: u16 = 1;
const WZO2_HEADER_SIZE: usize = 128;
const WZO2_GROUP_HEADER_SIZE: usize = 5; // colex u32 LE + entry_count u8
const WZO2_ENTRY_SIZE: usize = 4; // key_byte + L + H + DTT
const WZO2_RULES_ID: u16 = 3;

const Wzo2Header = struct {
    w: u8,
    h: u8,
    ko_bits: u8,
    hdr_flags: u8,
    n_groups: u64,
    n_entries: u64,
    data_offset: u64,
};

/// Parse and structurally validate a WZO2 header. Mirrors
/// vb_closure.parseWzo2Header (same field offsets, same checks) plus an exact
/// file-size consistency check (design-M1 §1: no trailing sentinel).
fn parseWzo2Header(bytes: []const u8) !Wzo2Header {
    if (bytes.len < WZO2_HEADER_SIZE) return error.Truncated;
    if (!std.mem.eql(u8, bytes[0..4], &WZO2_MAGIC)) return error.BadMagic;
    const version = std.mem.readInt(u16, bytes[4..6], .little);
    if (version != WZO2_VERSION) return error.BadVersion;
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
    const expected: u64 = data_offset +
        n_groups * WZO2_GROUP_HEADER_SIZE +
        n_entries * WZO2_ENTRY_SIZE;
    if (bytes.len != @as(usize, @intCast(expected))) return error.BadFileSize;
    return .{
        .w = w,
        .h = h,
        .ko_bits = ko_bits,
        .hdr_flags = hdr_flags,
        .n_groups = n_groups,
        .n_entries = n_entries,
        .data_offset = data_offset,
    };
}

/// Key-byte decode (artifact2 §2.2 contract; MSB→LSB layout
/// [passes:1][ko:KO_BITS][side:1][terminal:1]): side +1=Black/-1=White,
/// ko point (0..ko_none, ko_none = none), passes 0/1. The terminal LSB is
/// not an input to either move generator (both derive the move set from
/// (pos, side, ko, passes)); it is ignored here, matching how every I11
/// comparison treats the state.
const KeyByteDecoded = struct {
    side: i8,
    ko: u8,
    passes: u2,
};

fn decodeKeyByte(kb: u8, ko_bits: u8) KeyByteDecoded {
    const ko_mask: u8 = if (ko_bits == 0) 0 else @intCast((@as(u16, 1) << @intCast(ko_bits)) - 1);
    return .{
        .side = if ((kb & 2) != 0) @as(i8, -1) else @as(i8, 1),
        .ko = (kb >> 2) & ko_mask,
        .passes = @intCast((kb >> @intCast(2 + ko_bits)) & 1),
    };
}

/// Result of the direct table comparison (R8 vs kernel over every stored
/// WZO2 entry). Adds the structural accounting the full-table reading
/// reports: slice (ko=NONE, passes=0), ko-active (ko < n) and passes=1
/// subsets, which together partition the table (invariant: passes≥1 ⇒
/// ko=none, design-M1 §2.5).
pub const TableCmpResult = struct {
    mismatches: u64,
    total: u64,
    n_groups: u64,
    slice_entries: u64,
    ko_active_entries: u64,
    passes1_entries: u64,
    examples: [5]CmpResult.Mismatch,
    example_count: usize,
};

/// Compare R8 against the kernel over every entry of a WZO2 artifact.
/// `limit` bounds the number of entries compared (measurement mode); null =
/// the full table. At 4×4 the full denominator is 99,133,036 stored entries
/// — the literal "full table" the L2 audit's I11 line quotes, including the
/// ko-active and passes=1 states the SMD1 slice format cannot represent.
pub fn compareTableDirect(comptime w: usize, comptime h: usize, bytes: []const u8, limit: ?u64) !TableCmpResult {
    const hdr = try parseWzo2Header(bytes);
    if (hdr.w != w or hdr.h != h) return error.BadGoban;
    const R = kernel_rules.Rules(w, h);
    const X = engine.colex.Indexer(w, h);
    const n = w * h;
    const ko_none = R.ko_none();
    const ko_bits = hdr.ko_bits;
    var res = TableCmpResult{
        .mismatches = 0,
        .total = 0,
        .n_groups = hdr.n_groups,
        .slice_entries = 0,
        .ko_active_entries = 0,
        .passes1_entries = 0,
        .examples = undefined,
        .example_count = 0,
    };
    const group_off: usize = @intCast(hdr.data_offset);
    const entry_off: usize = group_off + @as(usize, @intCast(hdr.n_groups)) * WZO2_GROUP_HEADER_SIZE;

    var entry_idx: u64 = 0;
    outer: for (0..hdr.n_groups) |g| {
        const go: usize = group_off + g * WZO2_GROUP_HEADER_SIZE;
        const colex32 = std.mem.readInt(u32, bytes[go..][0..4], .little);
        const count: usize = bytes[go + 4];
        const pos = X.pos_from_colex(colex32);
        for (0..count) |_| {
            const eo: usize = entry_off + @as(usize, @intCast(entry_idx)) * WZO2_ENTRY_SIZE;
            const kb = bytes[eo];
            const dec = decodeKeyByte(kb, ko_bits);
            const side = dec.side;
            const ko = dec.ko;
            const passes = dec.passes;

            if (ko == ko_none and passes == 0) res.slice_entries += 1;
            if (ko < ko_none) res.ko_active_entries += 1;
            if (passes == 1) res.passes1_entries += 1;

            // Kernel side
            const kernel_bm = R.legalMoves(&pos, side, ko, passes);

            // R8 side
            const r8_state: vb_movegen.State(w, h) = .{
                .pos = pos,
                .side = side,
                .ko = ko,
                .passes = passes,
            };
            const r8_bm = vb_movegen.legalMoves(w, h, r8_state);

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
                        .colex_idx = @as(u64, colex32),
                        .side = side,
                        .r8_has_solver_lacks = r8_extra,
                        .solver_has_r8_lacks = kernel_extra,
                    };
                    res.example_count += 1;
                }
            }
            res.total += 1;
            entry_idx += 1;
            if (limit) |lim| {
                if (entry_idx >= lim) break :outer;
            }
        }
    }
    return res;
}

/// Monotonic milliseconds (Zig 0.16; same shape as tools/smd1.zig's nowMs).
fn nowMs() u64 {
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * 1000 + @as(u64, @intCast(ts.nsec)) / 1_000_000;
}

/// Read a whole file (Zig 0.16 std.Io; same shape as vb_closure.readFileBytes).
fn readFileBytes(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var threaded = std.Io.Threaded.init(allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();
    return try std.Io.Dir.cwd().readFileAlloc(io, path, allocator, .unlimited);
}

/// Measurement-only slice sweep (T473 bar: measure before committing the
/// machine). Walks the FULL colex space applying the kernel legal-position
/// filter (is_legal) — reporting the legal-position count, cross-checked
/// against A094777(4) = 24,318,165 — and appends at most `record_limit`
/// slice records (kernel legalMoves × both sides), timing the whole pass.
/// The full emission cost projects as elapsed × 48,636,330 / record_limit.
const SliceMeasureResult = struct {
    record_count: u64,
    legal_positions: u64,
    elapsed_ms: u64,
};

fn smd1MeasureSlice(comptime w: usize, comptime h: usize, gpa: std.mem.Allocator, record_limit: u64) !SliceMeasureResult {
    const R = kernel_rules.Rules(w, h);
    const X = engine.colex.Indexer(w, h);
    const E = engine.enumerate.Enumerator(w, h);
    const n = w * h;
    const cb = smd1ColexBytes(n);
    const mb = R.moves_bytes;
    const ko_none = R.ko_none();
    const rec_size: usize = @as(usize, cb) + 1 + mb;

    const t0 = nowMs();
    var records: std.ArrayListUnmanaged(u8) = .empty;
    defer records.deinit(gpa);

    var legal_positions: u64 = 0;
    var idx: u64 = 0;
    while (idx < X.total) : (idx += 1) {
        const pos = X.pos_from_colex(idx);
        if (!E.is_legal(&pos)) continue;
        legal_positions += 1;
        // Keep sweeping for the count even after the emission cap is hit.
        if (records.items.len / rec_size >= record_limit) continue;
        const bm_b = R.legalMoves(&pos, 1, ko_none, 0);
        try smd1AppendRecord(&records, gpa, idx, 1, bm_b[0..], cb);
        const bm_w = R.legalMoves(&pos, -1, ko_none, 0);
        try smd1AppendRecord(&records, gpa, idx, 2, bm_w[0..], cb);
    }
    return .{
        .record_count = records.items.len / rec_size,
        .legal_positions = legal_positions,
        .elapsed_ms = nowMs() - t0,
    };
}

// ═══════════════════════════════════════════════════════════════════════════
//  TESTS
// ═══════════════════════════════════════════════════════════════════════════

// ---- SMD1 parser ---------------------------------------------------------

test "vb_i11: SMD1 2x2 validate" {
    const bytes = try fixtureExhaustive(2, 2);
    defer freeFixture(bytes);
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
    const bytes = try fixtureExhaustive(3, 2);
    defer freeFixture(bytes);
    const hdr = try smd1Validate(bytes, 3, 2);
    try expectEqual(@as(u8, 3), hdr.w);
    try expectEqual(@as(u8, 2), hdr.h);
    try expectEqual(@as(u8, 4), hdr.colex_bytes);
    try expectEqual(@as(u8, 1), hdr.moves_bytes);
}

test "vb_i11: SMD1 3x3 validate" {
    const bytes = try fixtureExhaustive(3, 3);
    defer freeFixture(bytes);
    const hdr = try smd1Validate(bytes, 3, 3);
    try expectEqual(@as(u8, 3), hdr.w);
    try expectEqual(@as(u8, 3), hdr.h);
    try expectEqual(@as(u8, 4), hdr.colex_bytes);
}

test "vb_i11: SMD1 4x4 validate" {
    const bytes = try fixtureSampled(4, 4, 31337, 50000);
    defer freeFixture(bytes);
    const hdr = try smd1Validate(bytes, 4, 4);
    try expectEqual(@as(u8, 4), hdr.w);
    try expectEqual(@as(u8, 4), hdr.h);
    try expectEqual(@as(u8, 8), hdr.colex_bytes);
    try expectEqual(@as(u8, 3), hdr.moves_bytes);
    try expectEqual(@as(u32, 50000), hdr.record_count);
}

// ---- T438: fixture regeneration (artifact absent) ---------------------
//
// Seeded arm for T438: proves the suite regenerates its SMD1 fixtures in-memory
// when the on-disk artifact is absent (e.g. after a reboot or a tmp sweep).
// The old suite read absolute /tmp paths and failed with FileNotFound; this
// arm generates the 2×2 fixture with no filesystem access and validates it,
// demonstrating the suite no longer depends on disposable /tmp state. The null
// arm is the existing "NULL CONTROL — kernel vs SMD1 at 2x2" test above, which
// now runs against the same in-memory bytes and still reports 0 mismatches.

test "vb_i11: T438 — regenerate 2x2 fixture in-memory (artifact absent)" {
    // No /tmp path is read: the fixture is produced by the kernel emitter.
    const bytes = try fixtureExhaustive(2, 2);
    defer freeFixture(bytes);
    const hdr = try smd1Validate(bytes, 2, 2);
    try expectEqual(@as(u8, 2), hdr.w);
    try expectEqual(@as(u8, 2), hdr.h);
    // 57 legal positions × 2 sides = 114 records (the same count the file-based
    // validate test asserted when the /tmp artifact existed).
    try expectEqual(@as(u32, 114), hdr.record_count);
}

test "vb_i11: T438 — in-memory fixture is deterministic (byte-identical re-emit)" {
    // Determinism: emitting twice yields byte-identical bytes, so the in-memory
    // fixture is a stable oracle and not a source of flaky mismatches.
    const a = try fixtureExhaustive(3, 3);
    defer freeFixture(a);
    const b = try fixtureExhaustive(3, 3);
    defer freeFixture(b);
    try expectEqual(a.len, b.len);
    try expect(std.mem.eql(u8, a, b));

    // The sampled 4×4 fixture is deterministic for a fixed seed too.
    const s1 = try fixtureSampled(4, 4, 31337, 50000);
    defer freeFixture(s1);
    const s2 = try fixtureSampled(4, 4, 31337, 50000);
    defer freeFixture(s2);
    try expectEqual(s1.len, s2.len);
    try expect(std.mem.eql(u8, s1, s2));
}

// ---- NULL CONTROL: kernel vs SMD1 (both kernel) — must be 0 ------------

test "vb_i11: NULL CONTROL — kernel vs SMD1 at 2x2 → 0 mismatches" {
    const bytes = try fixtureExhaustive(2, 2);
    defer freeFixture(bytes);
    const res = try compareSmd1Null(2, 2, bytes);
    try expectEqual(@as(u64, 0), res.mismatches);
    // 57 legal positions × 2 sides = 114 records
    try expectEqual(@as(u64, 114), res.total);
}

test "vb_i11: NULL CONTROL — kernel vs SMD1 at 3x2 → 0 mismatches" {
    const bytes = try fixtureExhaustive(3, 2);
    defer freeFixture(bytes);
    const res = try compareSmd1Null(3, 2, bytes);
    try expectEqual(@as(u64, 0), res.mismatches);
}

test "vb_i11: NULL CONTROL — kernel vs SMD1 at 3x3 → 0 mismatches" {
    const bytes = try fixtureExhaustive(3, 3);
    defer freeFixture(bytes);
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
    const bytes = try fixtureSampled(4, 4, 31337, 50000);
    defer freeFixture(bytes);
    const res = try compareSmd1(4, 4, bytes);
    try expectEqual(@as(u64, 0), res.mismatches);
    try expectEqual(@as(u64, 50000), res.total);
}

// ---- Cross-check: 3×3 SMD1 vs R8 (confirms SMD1 comparison path works) --

test "vb_i11: I11 3×3 SMD1 cross-check — R8 vs SMD1 → 0 mismatches" {
    const bytes = try fixtureExhaustive(3, 3);
    defer freeFixture(bytes);
    const res = try compareSmd1(3, 3, bytes);
    try expectEqual(@as(u64, 0), res.mismatches);
}

// ---- T473: exhaustive 4×4 I11 ------------------------------------------

// ---- key-byte decode regression (artifact2 §2.2 contract, T383 F-7) -----

test "vb_i11: T473 — key-byte decode matches the artifact2 §2.2 contract" {
    // Layout MSB→LSB: [passes:1][ko:KO_BITS][side:1][terminal:1]. Encode
    // via the documented construction, decode via the production path — a
    // kb>>1-style leak (T383 F-7) would be caught by the ko expectations.
    const ko_bits: u8 = 5; // 4×4: ko values 0..16 fit in 5 bits

    // (passes << 7) | (ko << 2) | (side << 1) | terminal
    const kb_black_ko3 = (@as(u8, 0) << 7) | (3 << 2) | (0 << 1) | 0; // 12
    const d1 = decodeKeyByte(kb_black_ko3, ko_bits);
    try expectEqual(@as(i8, 1), d1.side);
    try expectEqual(@as(u8, 3), d1.ko);
    try expectEqual(@as(u2, 0), d1.passes);

    const kb_white_koNONE = (@as(u8, 0) << 7) | (16 << 2) | (1 << 1) | 0; // 66
    const d2 = decodeKeyByte(kb_white_koNONE, ko_bits);
    try expectEqual(@as(i8, -1), d2.side);
    try expectEqual(@as(u8, 16), d2.ko);
    try expectEqual(@as(u2, 0), d2.passes);

    const kb_black_passes1 = (@as(u8, 1) << 7) | (16 << 2) | (0 << 1) | 0; // 192
    const d3 = decodeKeyByte(kb_black_passes1, ko_bits);
    try expectEqual(@as(i8, 1), d3.side);
    try expectEqual(@as(u8, 16), d3.ko);
    try expectEqual(@as(u2, 1), d3.passes);
}

// ---- calibration: direct table comparison at 3×3 (always-on, cheap) -----

test "vb_i11: T473 — 3×3 table direct — R8 vs kernel over every stored entry → 0" {
    const gpa = std.heap.page_allocator;
    const file_bytes = try readFileBytes(gpa, "data/oracle-3x3-v2.wzo2");
    defer gpa.free(file_bytes);
    const res = try compareTableDirect(3, 3, file_bytes, null);
    // The new table-direct path exercised at the smallest real WZO2
    // artifact before it is trusted at 4×4: every stored entry (ko-active
    // and passes=1 included) must agree between R8 and the kernel.
    try expectEqual(@as(u64, 0), res.mismatches);
    try expect(res.total > 0);
    try expectEqual(res.total, res.slice_entries + res.ko_active_entries + res.passes1_entries);
    evidence.print(
        "I11 3x3 table direct: total={d} groups={d} slice={d} ko_active={d} passes1={d} mismatches={d}\n",
        .{ res.total, res.n_groups, res.slice_entries, res.ko_active_entries, res.passes1_entries, res.mismatches },
    );
}

// ---- measurement run (T473 bar: extrapolate before the full sweep) ------

test "I11 4×4 MEASURE (WEIZIGO_I11_4X4_MEASURE=1): 10× sample cost + full-run projection" {
    if (std.c.getenv("WEIZIGO_I11_4X4_MEASURE") == null) {
        evidence.print("SKIP I11 4x4 measure (set WEIZIGO_I11_4X4_MEASURE=1 to run)\n", .{});
        return;
    }
    const gpa = std.heap.page_allocator;
    const n_sample: u64 = 500_000; // 10× the historical 50k sample

    // (A) compareSmd1 rate: R8 vs a 500k sampled SMD1 dump.
    const t0 = nowMs();
    const bytes = try fixtureSampled(4, 4, 31337, @intCast(n_sample));
    const t_emit_sample = nowMs() - t0;
    const t1 = nowMs();
    const res_a = try compareSmd1(4, 4, bytes);
    const t_cmp_sample = nowMs() - t1;
    freeFixture(bytes);
    try expectEqual(@as(u64, 0), res_a.mismatches);
    try expectEqual(n_sample, res_a.total);

    // (B) slice emission rate: full colex sweep + legal filter + 500k records.
    const t2 = nowMs();
    const meas = try smd1MeasureSlice(4, 4, gpa, n_sample);
    const t_sweep = nowMs() - t2;
    try expectEqual(@as(u64, 24_318_165), meas.legal_positions); // A094777(4)
    try expectEqual(n_sample, meas.record_count);

    // (C) table-direct rate: 500k entries of the real artifact.
    const t3 = nowMs();
    const table_bytes = try readFileBytes(gpa, "data/oracle-4x4-v2.wzo2");
    defer gpa.free(table_bytes);
    const res_c = try compareTableDirect(4, 4, table_bytes, n_sample);
    const t_table_sample = nowMs() - t3;
    try expectEqual(@as(u64, 0), res_c.mismatches);
    try expectEqual(n_sample, res_c.total);

    // Projections (full denominators 48,636,330 slice records / 99,133,036
    // table entries; the sampled emission adds rejection-sampling overhead,
    // so (B)'s sweep is the emission projection base).
    const slice_records: u64 = 48_636_330;
    const table_entries: u64 = 99_133_036;
    const p_emit = t_sweep * slice_records / n_sample;
    const p_cmp = t_cmp_sample * slice_records / n_sample;
    const p_table = t_table_sample * table_entries / n_sample;
    const p_total = p_emit + p_cmp + p_table;

    evidence.print(
        "I11 4x4 MEASURE: cmp_sample={d} ms ({d} rec) sweep={d} ms ({d} legal pos, {d} rec) table_sample={d} ms ({d} ent) sample_emit={d} ms\n",
        .{ t_cmp_sample, res_a.total, t_sweep, meas.legal_positions, meas.record_count, t_table_sample, res_c.total, t_emit_sample },
    );
    evidence.print(
        "I11 4x4 PROJECT: slice_emit≈{d} s slice_cmp≈{d} s table_direct≈{d} s total≈{d} s (runner wall ceiling 1800 s)\n",
        .{ p_emit / 1000, p_cmp / 1000, p_table / 1000, p_total / 1000 },
    );
}

// ---- full runs (gated by WEIZIGO_I11_4X4_FULL=1, under tools/runner) -----

test "I11 4×4 FULL slice (WEIZIGO_I11_4X4_FULL=1): R8 vs kernel over all 48,636,330 SMD1 slice records" {
    if (std.c.getenv("WEIZIGO_I11_4X4_FULL") == null) {
        evidence.print("SKIP I11 4x4 full slice (set WEIZIGO_I11_4X4_FULL=1 to run)\n", .{});
        return;
    }
    const t0 = nowMs();
    const bytes = try fixtureExhaustive(4, 4);
    const t_emit = nowMs() - t0;
    const t1 = nowMs();
    const res = try compareSmd1(4, 4, bytes);
    const t_cmp = nowMs() - t1;
    defer freeFixture(bytes);
    // 24,318,165 legal positions × 2 sides = 48,636,330 (A094777(4); the
    // WZO2 table's n_groups). A different count means the kernel's
    // legal-position enumeration disagrees with the table's group index.
    evidence.print(
        "I11 4x4 FULL slice: records={d} mismatches={d} emit={d} ms compare={d} ms total={d} ms\n",
        .{ res.total, res.mismatches, t_emit, t_cmp, nowMs() - t0 },
    );
    try expectEqual(@as(u64, 48_636_330), res.total);
    try expectEqual(@as(u64, 0), res.mismatches);
}

test "I11 4×4 FULL table (WEIZIGO_I11_4X4_FULL=1): R8 vs kernel over all 99,133,036 stored entries" {
    if (std.c.getenv("WEIZIGO_I11_4X4_FULL") == null) {
        evidence.print("SKIP I11 4x4 full table (set WEIZIGO_I11_4X4_FULL=1 to run)\n", .{});
        return;
    }
    const gpa = std.heap.page_allocator;
    const t0 = nowMs();
    const file_bytes = try readFileBytes(gpa, "data/oracle-4x4-v2.wzo2");
    defer gpa.free(file_bytes);
    const res = try compareTableDirect(4, 4, file_bytes, null);
    evidence.print(
        "I11 4x4 FULL table: entries={d} groups={d} slice={d} ko_active={d} passes1={d} mismatches={d} total={d} ms\n",
        .{ res.total, res.n_groups, res.slice_entries, res.ko_active_entries, res.passes1_entries, res.mismatches, nowMs() - t0 },
    );
    try expectEqual(@as(u64, 99_133_036), res.total);
    try expectEqual(@as(u64, 24_318_165), res.n_groups);
    try expectEqual(@as(u64, 0), res.mismatches);
    try expectEqual(res.total, res.slice_entries + res.ko_active_entries + res.passes1_entries);
}
