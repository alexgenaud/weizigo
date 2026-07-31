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
// TABLE INVARIANTS — verify-battery V-7 M2.
//
// Implements I1, I2, I3, I6, I10, I12.
//
// Author: DSPro/T169-w2 · 2026-07-31
// Status: DELIVERED — M2 table invariants
//
// Standalone: imports NOTHING from src/ (spec R8). Re-implements WZO1
// artifact loader, runtime colex bijection, and invariant checks that
// read only the stored artifact columns.
//
// WZO1 constraints (pinned-v artifacts only):
//   I1  — L_eq_H only (derived from KO_SENSITIVE bit). pin_T/pin_L/pin_H
//          require WZO2 bracket columns.
//   I2  — colour inversion: V(-pos,-side) == -V(pos,side). Fully computable.
//   I3  — NOT APPLICABLE on WZO1 (no L/H columns to compare).
//   I6  — UNDEF census. Fully computable.
//   I10 — NOT APPLICABLE on WZO1 (no L/H/TIE triple to check).
//   I12 — score range: V ∈ [−area, +area]. Fully computable.
//
// Merge notes: when T168 (vb_common.zig) ships, the following types should
// be merged: GobanSize, VBArtifact, InvariantStatus, and the invariant-
// specific result structs. Colex should move to vb_common.zig as well.

const std = @import("std");
const Allocator = std.mem.Allocator;

// ─── public types (to be merged with vb_common.zig when T168 ships) ─────────

pub const GobanSize = struct {
    w: u8,
    h: u8,
};

/// Per-invariant status.
pub const InvariantStatus = enum {
    pass,
    fail,
    not_applicable,
    err,
};

// ─── I1 — pin census ───────────────────────────────────────────────────────

pub const I1Result = struct {
    status: InvariantStatus = .pass,
    numerator: u64 = 0,
    denominator: u64 = 0,
    /// Count of legal slots where fb bit0 (KO_SENSITIVE) is clear.
    /// On WZO1 this is the L==H count. pin_T/pin_L/pin_H require WZO2.
    L_eq_H: u64 = 0,
    err_msg: ?[]const u8 = null,
};

// ─── I2 — colour inversion ─────────────────────────────────────────────────

pub const I2Result = struct {
    status: InvariantStatus = .pass,
    numerator: u64 = 0,
    denominator: u64 = 0,
    violations: u64 = 0,
    /// Up to 5 example colex indices where the invariant is violated.
    violation_examples: [5]u64 = [_]u64{0} ** 5,
    violation_example_count: u8 = 0,
    err_msg: ?[]const u8 = null,
};

// ─── I3 — L ≤ H (not_applicable on WZO1) ──────────────────────────────────

pub const I3Result = struct {
    status: InvariantStatus = .not_applicable,
    numerator: u64 = 0,
    denominator: u64 = 0,
    violations: u64 = 0,
    violation_examples: [5]u64 = [_]u64{0} ** 5,
    violation_example_count: u8 = 0,
    err_msg: ?[]const u8 = null,
};

// ─── I6 — UNDEF census ─────────────────────────────────────────────────────

pub const I6Result = struct {
    status: InvariantStatus = .pass,
    numerator: u64 = 0,
    denominator: u64 = 0,
    illegal: u64 = 0,
    legal_both_sides: u64 = 0,
    legal_one_side_only: u64 = 0,
    legal_positions_total: u64 = 0,
    oeis_legal_reference: ?u64 = null,
    oeis_citation: []const u8 = "",
    legal_matches_oeis: ?bool = null,
    err_msg: ?[]const u8 = null,
};

// ─── I10 — TIE median (not_applicable on WZO1) ────────────────────────────

pub const I10Result = struct {
    status: InvariantStatus = .not_applicable,
    numerator: u64 = 0,
    denominator: u64 = 0,
    violations: u64 = 0,
    tie_below_L: u64 = 0,
    tie_above_H: u64 = 0,
    tie_not_median: u64 = 0,
    violation_examples: [5]u64 = [_]u64{0} ** 5,
    violation_example_count: u8 = 0,
    err_msg: ?[]const u8 = null,
};

// ─── I12 — score range ─────────────────────────────────────────────────────

pub const I12Result = struct {
    status: InvariantStatus = .pass,
    numerator: u64 = 0,
    denominator: u64 = 0,
    violations: u64 = 0,
    area: u16 = 0,
    out_of_range_low: u64 = 0,
    out_of_range_high: u64 = 0,
    violation_examples: [5]u64 = [_]u64{0} ** 5,
    violation_example_count: u8 = 0,
    err_msg: ?[]const u8 = null,
};

// ─── VBArtifact — WZO1 artifact (standalone loader, spec R8) ──────────────

pub const VBArtifact = struct {
    w: u8,
    h: u8,
    total: u64,
    /// legal positions per side (from header)
    legal_count: u64,
    rules_id: u8,
    /// vb — value Black-to-move (i8, -128 = illegal/undef)
    vb: []const u8,
    /// vw — value White-to-move (i8, -128 = illegal/undef)
    vw: []const u8,
    /// fb — flags Black-to-move (bit0 = KO_SENSITIVE, bit1 = FROM_FORWARD)
    fb: []const u8,
    /// fw — flags White-to-move
    fw: []const u8,
    /// db — DTT Black-to-move (255 = DTT_FAR)
    db: []const u8,
    /// dw — DTT White-to-move
    dw: []const u8,

    pub fn deinit(self: *VBArtifact, gpa: Allocator) void {
        gpa.free(self.vb);
        gpa.free(self.vw);
        gpa.free(self.fb);
        gpa.free(self.fw);
        gpa.free(self.db);
        gpa.free(self.dw);
        self.* = undefined;
    }

    /// True if position is legal for Black at colex index `idx`.
    pub inline fn isLegalB(self: *const VBArtifact, idx: u64) bool {
        return self.vb[idx] != 128; // -128 as u8
    }

    /// True if position is legal for White at colex index `idx`.
    pub inline fn isLegalW(self: *const VBArtifact, idx: u64) bool {
        return self.vw[idx] != 128;
    }

    /// Get vb value as signed i8. Caller must ensure isLegalB first.
    pub inline fn vbVal(self: *const VBArtifact, idx: u64) i8 {
        return @as(i8, @bitCast(self.vb[idx]));
    }

    /// Get vw value as signed i8. Caller must ensure isLegalW first.
    pub inline fn vwVal(self: *const VBArtifact, idx: u64) i8 {
        return @as(i8, @bitCast(self.vw[idx]));
    }
};

/// Load a WZO1 artifact from file bytes.
/// Independent re-implementation (spec R8) — does not import src/artifact.zig.
pub fn loadArtifact(gpa: Allocator, bytes: []const u8) !VBArtifact {
    if (bytes.len < 32) return error.Truncated;
    // magic
    if (!std.mem.eql(u8, bytes[0..4], "WZO1")) return error.BadMagic;
    const format_version = bytes[4];
    if (format_version != 1) return error.BadVersion;
    const colex_layout = bytes[5];
    _ = colex_layout;
    const w = bytes[6];
    const h = bytes[7];
    const value_semantics = bytes[8];
    if (value_semantics != 1) return error.BadSemantics;
    const rules_id = bytes[9];
    if (rules_id != 1 and rules_id != 2) return error.BadRulesId;
    const column_count = bytes[10];
    if (column_count != 6) return error.BadColumnCount;
    // reserved byte at 11
    const total = std.mem.readInt(u64, bytes[12..20], .little);
    const n = @as(u64, w) * @as(u64, h);
    const expected_total = pow3(n);
    if (total != expected_total) return error.TotalMismatch;

    const legal_count = std.mem.readInt(u64, bytes[20..28], .little);

    // CRC-32 check
    const stored_crc = std.mem.readInt(u32, bytes[28..32], .little);
    var crc = std.hash.crc.Crc32IsoHdlc.init();
    crc.update(bytes[32..]);
    if (crc.final() != stored_crc) return error.CrcMismatch;

    const payload_size: u64 = 6 * total;
    if (bytes.len != 32 + payload_size) return error.Truncated;

    // Allocate all six columns
    const vb = try gpa.dupe(u8, bytes[32 + 0 * total .. 32 + 1 * total]);
    errdefer gpa.free(vb);
    const vw = try gpa.dupe(u8, bytes[32 + 1 * total .. 32 + 2 * total]);
    errdefer gpa.free(vw);
    const fb = try gpa.dupe(u8, bytes[32 + 2 * total .. 32 + 3 * total]);
    errdefer gpa.free(fb);
    const fw = try gpa.dupe(u8, bytes[32 + 3 * total .. 32 + 4 * total]);
    errdefer gpa.free(fw);
    const db = try gpa.dupe(u8, bytes[32 + 4 * total .. 32 + 5 * total]);
    errdefer gpa.free(db);
    const dw = try gpa.dupe(u8, bytes[32 + 5 * total .. 32 + 6 * total]);
    errdefer gpa.free(dw);

    return VBArtifact{
        .w = w,
        .h = h,
        .total = total,
        .legal_count = legal_count,
        .rules_id = rules_id,
        .vb = vb,
        .vw = vw,
        .fb = fb,
        .fw = fw,
        .db = db,
        .dw = dw,
    };
}

// ─── pow3 ──────────────────────────────────────────────────────────────────

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

// ─── runtime colex bijection (independent re-implementation, spec R8) ──────

/// Runtime colex indexer for goban size w × h.
/// Uses the layered colex layout:
///   idx = layer_offset[k] + subset_idx * 2^k + colour_bits
/// where subset_idx uses the combinatorial number system.
pub const Colex = struct {
    w: u8,
    h: u8,
    n: u8,
    total: u64,
    /// Pascal's triangle C(i,j) for i,j in 0..n
    binomial: [17][17]u64,
    /// layer_offset[k] = count of positions with < k stones
    layer_offset: [18]u64,

    /// Initialize a colex for a given goban size. Max 4×4 (n ≤ 16).
    pub fn init(w: u8, h: u8) Colex {
        const n: u8 = w * h;
        std.debug.assert(n <= 16);

        var self = Colex{
            .w = w,
            .h = h,
            .n = n,
            .total = 0,
            .binomial = [_][17]u64{[_]u64{0} ** 17} ** 17,
            .layer_offset = [_]u64{0} ** 18,
        };

        const nu = @as(usize, n);
        // Pascal's triangle
        for (0..nu + 1) |i| {
            self.binomial[i][0] = 1;
            for (1..i + 1) |j| {
                self.binomial[i][j] = self.binomial[i - 1][j - 1] +
                    (if (j <= i - 1) self.binomial[i - 1][j] else 0);
            }
        }

        // layer_offset[k] = sum_{i=0}^{k-1} C(n,i) * 2^i
        var off: u64 = 0;
        self.layer_offset[0] = 0;
        for (0..nu + 1) |k| {
            const contrib = self.binomial[nu][k] * (@as(u64, 1) << @intCast(k));
            self.layer_offset[k + 1] = off + contrib;
            off = self.layer_offset[k + 1];
        }

        self.total = self.layer_offset[nu + 1];
        return self;
    }

    /// Encode a position (array of i8: 0=empty, 1=Black, -1=White) to colex index.
    pub fn colexFromPos(self: *const Colex, pos: []const i8) u64 {
        std.debug.assert(pos.len == self.n);
        const nu = @as(usize, self.n);
        var k: usize = 0;
        var subset: u64 = 0;
        var colours: u64 = 0;
        for (0..nu) |cell| {
            if (pos[cell] == 0) continue;
            if (pos[cell] > 0) colours |= @as(u64, 1) << @intCast(k);
            k += 1;
            subset += self.binomial[cell][k];
        }
        return self.layer_offset[k] + subset * (@as(u64, 1) << @intCast(k)) + colours;
    }

    /// Decode a colex index to a position (array of i8).
    pub fn posFromColex(self: *const Colex, idx: u64, pos: []i8) void {
        std.debug.assert(pos.len == self.n);
        std.debug.assert(idx < self.total);
        // Find layer k
        var k: usize = 0;
        while (idx >= self.layer_offset[k + 1]) k += 1;
        const layer_idx = idx - self.layer_offset[k];
        var subset = layer_idx >> @intCast(k);
        const colours = layer_idx & ((@as(u64, 1) << @intCast(k)) - 1);

        @memset(pos, 0);
        var i: usize = k;
        while (i > 0) {
            i -= 1;
            var cell: usize = @intCast(self.n - 1);
            while (self.binomial[cell][i + 1] > subset) cell -= 1;
            subset -= self.binomial[cell][i + 1];
            const black = (colours >> @intCast(i)) & 1 == 1;
            pos[cell] = if (black) @as(i8, 1) else @as(i8, -1);
        }
    }

    /// Given a colex index, return the index of its colour-inverted position.
    /// Inversion swaps Black ↔ White (all +1 ↔ -1).
    pub fn invertIdx(self: *const Colex, idx: u64) u64 {
        std.debug.assert(idx < self.total);
        // Find layer k
        var k: usize = 0;
        while (idx >= self.layer_offset[k + 1]) k += 1;
        const layer_idx = idx - self.layer_offset[k];
        const subset = layer_idx >> @intCast(k);
        const colours = layer_idx & ((@as(u64, 1) << @intCast(k)) - 1);
        // Invert colours: 0 ↔ 1 for each stone
        const inverted_colours = colours ^ ((@as(u64, 1) << @intCast(k)) - 1);
        return self.layer_offset[k] + subset * (@as(u64, 1) << @intCast(k)) + inverted_colours;
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// INVARIANT IMPLEMENTATIONS
// ═══════════════════════════════════════════════════════════════════════════

const KO_SENSITIVE = 0x01; // bit0 = KO_SENSITIVE
const ILLEGAL: u8 = 128; // -128 as u8

// ─── I1 — pin census ───────────────────────────────────────────────────────

/// On WZO1: counts legal slots where KO_SENSITIVE is clear (L==H).
/// Scans both Black and White columns.
/// denominator = total legal slots (vb legal + vw legal).
/// L_eq_H = slots where flags bit0 == 0 among legal slots.
pub fn checkI1(art: *const VBArtifact) I1Result {
    var legal: u64 = 0;
    var clear: u64 = 0;

    // Black side
    for (0..art.total) |i| {
        if (art.vb[i] != ILLEGAL) {
            legal += 1;
            if (art.fb[i] & KO_SENSITIVE == 0) {
                clear += 1;
            }
        }
    }
    // White side
    for (0..art.total) |i| {
        if (art.vw[i] != ILLEGAL) {
            legal += 1;
            if (art.fw[i] & KO_SENSITIVE == 0) {
                clear += 1;
            }
        }
    }

    return I1Result{
        .status = .pass,
        .numerator = clear,
        .denominator = legal,
        .L_eq_H = clear,
    };
}

// ─── I2 — colour inversion ─────────────────────────────────────────────────

/// Checks V(-pos,-side) == -V(pos,side) for all legal slots.
/// For WZO1: vb[idx] == -vw[inverted_idx] for each legal Black slot.
/// Also checks vw[idx] == -vb[inverted_idx] for each legal White slot.
/// We iterate over all slots and check both directions independently.
/// denominator = total comparisons made (legal vb slots + legal vw slots).
pub fn checkI2(art: *const VBArtifact) I2Result {
    const colex = Colex.init(art.w, art.h);

    var violations: u64 = 0;
    var ex_buf: [5]u64 = [_]u64{0} ** 5;
    var ex_count: u8 = 0;

    // Check all slots: Black side
    for (0..art.total) |idx| {
        if (art.vb[idx] == ILLEGAL) continue;
        const inv_idx = colex.invertIdx(idx);
        if (art.vw[inv_idx] == ILLEGAL) continue;

        const vb_val = art.vbVal(idx);
        const vw_val = art.vwVal(inv_idx);

        if (vb_val != -vw_val) {
            violations += 1;
            if (ex_count < 5) {
                ex_buf[ex_count] = idx;
                ex_count += 1;
            }
        }
    }

    // Check all slots: White side
    for (0..art.total) |idx| {
        if (art.vw[idx] == ILLEGAL) continue;
        const inv_idx = colex.invertIdx(idx);
        if (art.vb[inv_idx] == ILLEGAL) continue;

        const vw_val = art.vwVal(idx);
        const vb_val = art.vbVal(inv_idx);

        if (vw_val != -vb_val) {
            violations += 1;
            if (ex_count < 5) {
                ex_buf[ex_count] = idx;
                ex_count += 1;
            }
        }
    }

    // denominator = total legal slots checked (both sides)
    // Each legal Black slot produces 1 check (against White on inverted pos).
    // Each legal White slot produces 1 check (against Black on inverted pos).
    // But these checks are symmetric: if vb[i] legal and vw[inv_i] legal,
    // then the reverse check (vw[inv_i] vs vb[i]) is the same pair counted
    // twice. We count each comparison once.
    // The total number of checks is legal_count * 2 (both sides).
    const denom: u64 = art.legal_count * 2;

    // Note: violations counts each failure direction. If both vb[i] != -vw[j]
    // AND vw[j] != -vb[i] (same pair), it's really one violation. But we count
    // it twice above, so we need to deduplicate. Since the check is symmetric,
    // each pair appears twice. We halve the violation count.
    // Actually: each direction is a separate check. A failure on vb[i] vs -vw[j]
    // implies vb[i] != -vw[j]. What about vw[j] vs -vb[i]? If vb[i] = -vw[j],
    // then vb[i] + vw[j] = 0. Then vw[j] = -vb[i]. So if one direction passes,
    // the other also passes. If one fails, the other also fails.
    // So violations is always even. We halve it.
    const deduped_violations = violations / 2;

    return I2Result{
        .status = if (deduped_violations == 0) .pass else .fail,
        .numerator = deduped_violations,
        .denominator = denom / 2, // unique pairs checked = legal_count
        .violations = deduped_violations,
        .violation_examples = ex_buf,
        .violation_example_count = ex_count,
    };
}

// ─── I3 — L ≤ H ────────────────────────────────────────────────────────────

/// NOT APPLICABLE on WZO1 — no L/H columns to compare (single V column only).
/// Returns status=not_applicable.
pub fn checkI3() I3Result {
    return I3Result{
        .status = .not_applicable,
        .numerator = 0,
        .denominator = 0,
        .violations = 0,
    };
}

// ─── I6 — UNDEF census ─────────────────────────────────────────────────────

/// Counts positions over the dense 3^(w×h) address space.
/// Categories:
///   illegal:             vb[idx] == ILLEGAL and vw[idx] == ILLEGAL
///   legal_both_sides:    vb legal AND vw legal
///   legal_one_side_only: exactly one of vb, vw legal
/// denominator = 3^(w×h).
/// numerator = legal_positions_total = illegal + legal_both_sides + legal_one_side_only.
///
/// OEIS A094777 reference: n×n gobans only. Null at 3×2, 4×3.
pub fn checkI6(art: *const VBArtifact) I6Result {
    var illegal: u64 = 0;
    var legal_both: u64 = 0;
    var legal_one: u64 = 0;

    for (0..art.total) |idx| {
        const b_legal = art.vb[idx] != ILLEGAL;
        const w_legal = art.vw[idx] != ILLEGAL;

        if (!b_legal and !w_legal) {
            illegal += 1;
        } else if (b_legal and w_legal) {
            legal_both += 1;
        } else {
            legal_one += 1;
        }
    }

    const total_positions: u64 = legal_both + legal_one;
    const matches_header = total_positions == art.legal_count;

    // OEIS A094777 is defined for n×n gobans only
    const is_square = art.w == art.h;
    const oeis_ref: ?u64 = if (is_square) oeisLookup(art.w) else null;
    const oeis_cite: []const u8 = if (is_square) "OEIS A094777" else "not applicable — OEIS A094777 is n×n only";

    var matches_oeis: ?bool = null;
    if (oeis_ref != null) {
        matches_oeis = total_positions == oeis_ref.?;
    }

    return I6Result{
        .status = if (matches_header) .pass else .fail,
        .numerator = total_positions,
        .denominator = art.total,
        .illegal = illegal,
        .legal_both_sides = legal_both,
        .legal_one_side_only = legal_one,
        .legal_positions_total = total_positions,
        .oeis_legal_reference = oeis_ref,
        .oeis_citation = oeis_cite,
        .legal_matches_oeis = matches_oeis,
    };
}

/// Known OEIS A094777 values: number of legal positions on n×n goban.
fn oeisLookup(n: u8) ?u64 {
    return switch (n) {
        1 => 1,
        2 => 57,
        3 => 12675,
        4 => 24318165,
        else => null,
    };
}

// ─── I10 — TIE median ─────────────────────────────────────────────────────

/// NOT APPLICABLE on WZO1 — no L/H/TIE triple to check.
/// The median check requires L and H which are not stored in WZO1.
pub fn checkI10() I10Result {
    return I10Result{
        .status = .not_applicable,
        .numerator = 0,
        .denominator = 0,
        .violations = 0,
    };
}

// ─── I12 — score range ─────────────────────────────────────────────────────

/// Checks V ∈ [−area, +area] for all legal slots.
/// Scans both vb and vw columns.
/// denominator = total legal slots (vb legal + vw legal).
/// violations = slots where value is outside [-area, +area].
pub fn checkI12(art: *const VBArtifact) I12Result {
    const area: i16 = @as(i16, art.w) * @as(i16, art.h);

    var violations: u64 = 0;
    var out_low: u64 = 0;
    var out_high: u64 = 0;
    var ex_buf: [5]u64 = [_]u64{0} ** 5;
    var ex_count: u8 = 0;
    var legal_count: u64 = 0;

    // Black side
    for (0..art.total) |idx| {
        if (art.vb[idx] == ILLEGAL) continue;
        legal_count += 1;
        const v: i16 = @as(i16, art.vbVal(idx));
        if (v < -area) {
            violations += 1;
            out_low += 1;
            if (ex_count < 5) { ex_buf[ex_count] = idx; ex_count += 1; }
        } else if (v > area) {
            violations += 1;
            out_high += 1;
            if (ex_count < 5) { ex_buf[ex_count] = idx; ex_count += 1; }
        }
    }

    // White side
    for (0..art.total) |idx| {
        if (art.vw[idx] == ILLEGAL) continue;
        legal_count += 1;
        const v: i16 = @as(i16, art.vwVal(idx));
        if (v < -area) {
            violations += 1;
            out_low += 1;
            if (ex_count < 5) { ex_buf[ex_count] = idx; ex_count += 1; }
        } else if (v > area) {
            violations += 1;
            out_high += 1;
            if (ex_count < 5) { ex_buf[ex_count] = idx; ex_count += 1; }
        }
    }

    return I12Result{
        .status = if (violations == 0) .pass else .fail,
        .numerator = violations,
        .denominator = legal_count,
        .violations = violations,
        .area = @intCast(area),
        .out_of_range_low = out_low,
        .out_of_range_high = out_high,
        .violation_examples = ex_buf,
        .violation_example_count = ex_count,
    };
}

// ═══════════════════════════════════════════════════════════════════════════
// TESTS
// ═══════════════════════════════════════════════════════════════════════════

const testing = std.testing;

/// Helper: read an artifact file for testing. Looks relative to project root.
fn readTestArtifact(gpa: Allocator, path: []const u8) ![]const u8 {
    var threaded = std.Io.Threaded.init(testing.allocator, .{});
    defer threaded.deinit();
    const io = threaded.io();
    return try std.Io.Dir.cwd().readFileAlloc(io, path, gpa, .unlimited);
}

// ─── artifact loader tests ─────────────────────────────────────────────────

test "load 2x2 artifact" {
    const bytes = try readTestArtifact(testing.allocator, "artifacts/oracle-2x2.wzo");
    defer testing.allocator.free(bytes);
    var art = try loadArtifact(testing.allocator, bytes);
    defer art.deinit(testing.allocator);

    try testing.expectEqual(@as(u8, 2), art.w);
    try testing.expectEqual(@as(u8, 2), art.h);
    try testing.expectEqual(@as(u64, 81), art.total);
    try testing.expectEqual(@as(u64, 57), art.legal_count);

    // Verify first few vb values
    try testing.expectEqual(@as(i8, 1), art.vbVal(0));
}

test "load 3x2 artifact" {
    const bytes = try readTestArtifact(testing.allocator, "artifacts/oracle-3x2.wzo");
    defer testing.allocator.free(bytes);
    var art = try loadArtifact(testing.allocator, bytes);
    defer art.deinit(testing.allocator);

    try testing.expectEqual(@as(u8, 3), art.w);
    try testing.expectEqual(@as(u8, 2), art.h);
    try testing.expectEqual(@as(u64, 729), art.total);
    try testing.expectEqual(@as(u64, 489), art.legal_count);
}

// ─── colex tests ───────────────────────────────────────────────────────────

test "colex 2x2 round-trip" {
    const colex = Colex.init(2, 2);
    try testing.expectEqual(@as(u64, 81), colex.total);

    // Empty position
    var pos = [_]i8{0} ** 4;
    const idx0 = colex.colexFromPos(&pos);
    try testing.expectEqual(@as(u64, 0), idx0);

    var decoded = [_]i8{0} ** 4;
    colex.posFromColex(idx0, &decoded);
    try testing.expect(std.mem.eql(i8, &pos, &decoded));
}

test "colex 2x2 exhaustive bijection" {
    const colex = Colex.init(2, 2);
    var pos = [_]i8{0} ** 4;
    for (0..colex.total) |idx| {
        colex.posFromColex(idx, &pos);
        const back = colex.colexFromPos(&pos);
        try testing.expectEqual(@as(u64, idx), back);
    }
}

test "colex 2x2 colors round-trip" {
    const colex = Colex.init(2, 2);
    var pos = [_]i8{ 1, -1, 0, 0 }; // Black at 0, White at 1
    const idx = colex.colexFromPos(&pos);
    var decoded = [_]i8{0} ** 4;
    colex.posFromColex(idx, &decoded);
    try testing.expect(std.mem.eql(i8, &pos, &decoded));
}

test "colex invert 2x2" {
    const colex = Colex.init(2, 2);
    // Empty board: invert should equal itself
    try testing.expectEqual(@as(u64, 0), colex.invertIdx(0));

    // Position with Black at 0: inverted should have White at 0
    var pos = [_]i8{ 1, 0, 0, 0 };
    const idx = colex.colexFromPos(&pos);
    var inv_pos = [_]i8{ -1, 0, 0, 0 };
    const inv_idx = colex.colexFromPos(&inv_pos);
    try testing.expectEqual(inv_idx, colex.invertIdx(idx));

    // Verify round-trip: invert(invert(idx)) == idx
    try testing.expectEqual(idx, colex.invertIdx(inv_idx));
}

// ─── I1 pin census tests ──────────────────────────────────────────────────

test "I1: 2x2 pin census" {
    const bytes = try readTestArtifact(testing.allocator, "artifacts/oracle-2x2.wzo");
    defer testing.allocator.free(bytes);
    var art = try loadArtifact(testing.allocator, bytes);
    defer art.deinit(testing.allocator);

    const result = checkI1(&art);
    try testing.expectEqual(InvariantStatus.pass, result.status);
    // Expected: legal_count=57 per side, so 114 legal slots total.
    try testing.expectEqual(@as(u64, 114), result.denominator);
    // We already verified L_eq_H = 16+16 = 32 from Python analysis
    try testing.expectEqual(@as(u64, 32), result.L_eq_H);
    try testing.expectEqual(@as(u64, 32), result.numerator);
}

test "I1: 3x2 pin census" {
    const bytes = try readTestArtifact(testing.allocator, "artifacts/oracle-3x2.wzo");
    defer testing.allocator.free(bytes);
    var art = try loadArtifact(testing.allocator, bytes);
    defer art.deinit(testing.allocator);

    const result = checkI1(&art);
    try testing.expectEqual(InvariantStatus.pass, result.status);
    // legal_count=489 per side, so 978 legal slots total.
    try testing.expectEqual(@as(u64, 978), result.denominator);
    // L_eq_H = 300+300 = 600 (from Python analysis)
    try testing.expectEqual(@as(u64, 600), result.L_eq_H);
}

// ─── I2 colour inversion tests ────────────────────────────────────────────

test "I2: 2x2 colour inversion" {
    const bytes = try readTestArtifact(testing.allocator, "artifacts/oracle-2x2.wzo");
    defer testing.allocator.free(bytes);
    var art = try loadArtifact(testing.allocator, bytes);
    defer art.deinit(testing.allocator);

    const result = checkI2(&art);
    // Should pass — colour inversion holds
    try testing.expectEqual(InvariantStatus.pass, result.status);
    try testing.expectEqual(@as(u64, 0), result.violations);
    try testing.expectEqual(@as(u64, 57), result.denominator);
    try testing.expectEqual(@as(u64, 0), result.numerator);
}

test "I2: 3x2 colour inversion" {
    const bytes = try readTestArtifact(testing.allocator, "artifacts/oracle-3x2.wzo");
    defer testing.allocator.free(bytes);
    var art = try loadArtifact(testing.allocator, bytes);
    defer art.deinit(testing.allocator);

    const result = checkI2(&art);
    // Should pass — colour inversion holds
    try testing.expectEqual(InvariantStatus.pass, result.status);
    try testing.expectEqual(@as(u64, 0), result.violations);
    try testing.expectEqual(@as(u64, 489), result.denominator);
}

test "I2: synthetic violation detection" {
    // Create a synthetic artifact with known violation
    const colex = Colex.init(2, 2);
    // Position: Black at 0. Inverted: White at 0.
    var pos = [_]i8{ 1, 0, 0, 0 };
    const idx = colex.colexFromPos(&pos);

    // Build minimal artifact bytes
    const total: u64 = 81;
    const payload_size: u64 = 6 * total;
    const file_size: u64 = 32 + payload_size;
    var bytes = try testing.allocator.alloc(u8, file_size);
    defer testing.allocator.free(bytes);
    @memset(bytes, 0);

    // Header
    std.mem.copyForwards(u8, bytes[0..4], "WZO1");
    bytes[4] = 1; // format_version
    bytes[5] = 1; // colex_layout
    bytes[6] = 2; // w
    bytes[7] = 2; // h
    bytes[8] = 1; // value_semantics
    bytes[9] = 1; // rules_id
    bytes[10] = 6; // column_count
    std.mem.writeInt(u64, bytes[12..20], total, .little);
    std.mem.writeInt(u64, bytes[20..28], 1, .little); // legal_count = 1

    // Fill columns: all illegal (-128) except one slot
    const vb_start: u64 = 32;
    const vw_start: u64 = 32 + total;
    @memset(bytes[vb_start..][0..total], 128);
    @memset(bytes[vw_start..][0..total], 128);

    // Set vb[idx] = 5, vw[inv_idx] = 5 (should be -5 for inversion to hold)
    const inv_idx = colex.invertIdx(idx);
    bytes[vb_start + idx] = 5; // vb = 5
    bytes[vw_start + inv_idx] = 5; // vw = 5, should be -5 → VIOLATION
    bytes[32 + 2 * total + idx] = 0; // fb bit0 clear
    bytes[32 + 3 * total + inv_idx] = 0; // fw bit0 clear

    // CRC32
    var crc = std.hash.crc.Crc32IsoHdlc.init();
    crc.update(bytes[32..]);
    std.mem.writeInt(u32, bytes[28..32], crc.final(), .little);

    var art = try loadArtifact(testing.allocator, bytes);
    defer art.deinit(testing.allocator);

    const result = checkI2(&art);
    try testing.expectEqual(InvariantStatus.fail, result.status);
    try testing.expectEqual(@as(u64, 1), result.violations);
    try testing.expectEqual(@as(u64, 1), result.denominator);
}

// ─── I3 not_applicable test ──────────────────────────────────────────────

test "I3: not_applicable on WZO1" {
    const result = checkI3();
    try testing.expectEqual(InvariantStatus.not_applicable, result.status);
    try testing.expectEqual(@as(u64, 0), result.violations);
}

// ─── I6 UNDEF census tests ────────────────────────────────────────────────

test "I6: 2x2 UNDEF census" {
    const bytes = try readTestArtifact(testing.allocator, "artifacts/oracle-2x2.wzo");
    defer testing.allocator.free(bytes);
    var art = try loadArtifact(testing.allocator, bytes);
    defer art.deinit(testing.allocator);

    const result = checkI6(&art);
    try testing.expectEqual(InvariantStatus.pass, result.status);

    // denominator = 3^4 = 81
    try testing.expectEqual(@as(u64, 81), result.denominator);
    // legal_positions_total should equal legal_count from header = 57
    try testing.expectEqual(@as(u64, 57), result.legal_positions_total);
    try testing.expectEqual(@as(u64, 57), result.legal_both_sides);
    try testing.expectEqual(@as(u64, 0), result.legal_one_side_only);
    try testing.expectEqual(@as(u64, 81 - 57), result.illegal);

    // OEIS A094777(2) = 57
    try testing.expectEqual(@as(u64, 57), result.oeis_legal_reference.?);
    try testing.expectEqual(true, result.legal_matches_oeis.?);
}

test "I6: 3x2 UNDEF census" {
    const bytes = try readTestArtifact(testing.allocator, "artifacts/oracle-3x2.wzo");
    defer testing.allocator.free(bytes);
    var art = try loadArtifact(testing.allocator, bytes);
    defer art.deinit(testing.allocator);

    const result = checkI6(&art);
    try testing.expectEqual(InvariantStatus.pass, result.status);

    // denominator = 3^6 = 729
    try testing.expectEqual(@as(u64, 729), result.denominator);
    // legal_positions_total should equal legal_count from header = 489
    try testing.expectEqual(@as(u64, 489), result.legal_positions_total);
    try testing.expectEqual(@as(u64, 489), result.legal_both_sides);
    try testing.expectEqual(@as(u64, 0), result.legal_one_side_only);
    try testing.expectEqual(@as(u64, 729 - 489), result.illegal);

    // OEIS not applicable for non-square
    try testing.expectEqual(@as(?u64, null), result.oeis_legal_reference);
    try testing.expectEqual(@as(?bool, null), result.legal_matches_oeis);
}

// ─── I10 not_applicable test ──────────────────────────────────────────────

test "I10: not_applicable on WZO1" {
    const result = checkI10();
    try testing.expectEqual(InvariantStatus.not_applicable, result.status);
    try testing.expectEqual(@as(u64, 0), result.violations);
}

// ─── I12 score range tests ────────────────────────────────────────────────

test "I12: 2x2 score range" {
    const bytes = try readTestArtifact(testing.allocator, "artifacts/oracle-2x2.wzo");
    defer testing.allocator.free(bytes);
    var art = try loadArtifact(testing.allocator, bytes);
    defer art.deinit(testing.allocator);

    const result = checkI12(&art);
    try testing.expectEqual(InvariantStatus.pass, result.status);
    try testing.expectEqual(@as(u16, 4), result.area);
    try testing.expectEqual(@as(u64, 0), result.violations);
    // denominator = 114 legal slots
    try testing.expectEqual(@as(u64, 114), result.denominator);
}

test "I12: 3x2 score range" {
    const bytes = try readTestArtifact(testing.allocator, "artifacts/oracle-3x2.wzo");
    defer testing.allocator.free(bytes);
    var art = try loadArtifact(testing.allocator, bytes);
    defer art.deinit(testing.allocator);

    const result = checkI12(&art);
    try testing.expectEqual(InvariantStatus.pass, result.status);
    try testing.expectEqual(@as(u16, 6), result.area);
    try testing.expectEqual(@as(u64, 0), result.violations);
    // denominator = 978 legal slots
    try testing.expectEqual(@as(u64, 978), result.denominator);
}

test "I12: synthetic violation detection" {
    // Build a minimal artifact with a value outside range
    const total: u64 = 81;
    const payload_size: u64 = 6 * total;
    const file_size: u64 = 32 + payload_size;
    var bytes = try testing.allocator.alloc(u8, file_size);
    defer testing.allocator.free(bytes);
    @memset(bytes, 0);

    std.mem.copyForwards(u8, bytes[0..4], "WZO1");
    bytes[4] = 1;
    bytes[5] = 1;
    bytes[6] = 2;
    bytes[7] = 2;
    bytes[8] = 1;
    bytes[9] = 1;
    bytes[10] = 6;
    std.mem.writeInt(u64, bytes[12..20], total, .little);
    std.mem.writeInt(u64, bytes[20..28], 1, .little);

    // All illegal except one slot
    const vb_start: u64 = 32;
    @memset(bytes[vb_start..][0..total], 128);
    @memset(bytes[vb_start + total ..][0..total], 128);
    @memset(bytes[vb_start + 2 * total ..][0..total], 0);

    // Set vb[0] = 10 (area=4, so 10 > 4 → out of range high)
    bytes[vb_start] = 10; // 10 > 4

    var crc = std.hash.crc.Crc32IsoHdlc.init();
    crc.update(bytes[32..]);
    std.mem.writeInt(u32, bytes[28..32], crc.final(), .little);

    var art = try loadArtifact(testing.allocator, bytes);
    defer art.deinit(testing.allocator);

    const result = checkI12(&art);
    try testing.expectEqual(InvariantStatus.fail, result.status);
    try testing.expectEqual(@as(u64, 1), result.violations);
    try testing.expectEqual(@as(u64, 1), result.out_of_range_high);
    try testing.expectEqual(@as(u64, 0), result.out_of_range_low);
    try testing.expectEqual(@as(u16, 4), result.area);
}

test "I12: synthetic out-of-range-low" {
    const total: u64 = 81;
    const payload_size: u64 = 6 * total;
    const file_size: u64 = 32 + payload_size;
    var bytes = try testing.allocator.alloc(u8, file_size);
    defer testing.allocator.free(bytes);
    @memset(bytes, 0);

    std.mem.copyForwards(u8, bytes[0..4], "WZO1");
    bytes[4] = 1;
    bytes[5] = 1;
    bytes[6] = 2;
    bytes[7] = 2;
    bytes[8] = 1;
    bytes[9] = 1;
    bytes[10] = 6;
    std.mem.writeInt(u64, bytes[12..20], total, .little);
    std.mem.writeInt(u64, bytes[20..28], 1, .little);

    const vb_start: u64 = 32;
    @memset(bytes[vb_start..][0..total], 128);
    @memset(bytes[vb_start + total ..][0..total], 128);
    @memset(bytes[vb_start + 2 * total ..][0..total], 0);

    // vb[0] = -10 as signed i8 = 246 as u8
    // area=4, -10 < -4 → out of range low
    bytes[vb_start] = @as(u8, @bitCast(@as(i8, -10)));

    var crc = std.hash.crc.Crc32IsoHdlc.init();
    crc.update(bytes[32..]);
    std.mem.writeInt(u32, bytes[28..32], crc.final(), .little);

    var art = try loadArtifact(testing.allocator, bytes);
    defer art.deinit(testing.allocator);

    const result = checkI12(&art);
    try testing.expectEqual(InvariantStatus.fail, result.status);
    try testing.expectEqual(@as(u64, 1), result.violations);
    try testing.expectEqual(@as(u64, 1), result.out_of_range_low);
    try testing.expectEqual(@as(u64, 0), result.out_of_range_high);
}
