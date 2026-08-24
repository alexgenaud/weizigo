////////////////////////////////////////////
//                                        //
//    (c) 2024 Alexander E Genaud         //
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
// VB_COMMON — shared types and utilities for the verify-battery.
//
// R8-compliant: imports nothing from src/ (only Zig std).
// Defines the common interface that invariant modules (T169-T171) import.
//
// Author: DSPro/T168-w2 · 2026-07-31

const std = @import("std");
const Allocator = std.mem.Allocator;

// ═══════════════════════════════════════════════════════════════════════════
// GobanSize
// ═══════════════════════════════════════════════════════════════════════════

pub const GobanSize = struct {
    w: u8,
    h: u8,

    pub fn format(self: GobanSize, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.print("{d}x{d}", .{ self.w, self.h });
    }

    pub fn area(self: GobanSize) u16 {
        return @as(u16, self.w) * @as(u16, self.h);
    }

    pub fn parse(s: []const u8) ?GobanSize {
        const x = std.mem.indexOfScalar(u8, s, 'x') orelse return null;
        const w = std.fmt.parseUnsigned(u8, s[0..x], 10) catch return null;
        const h = std.fmt.parseUnsigned(u8, s[x + 1 ..], 10) catch return null;
        if (w == 0 or h == 0) return null;
        if (w > 4 or h > 4) return null;
        return GobanSize{ .w = w, .h = h };
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// Enums
// ═══════════════════════════════════════════════════════════════════════════

pub const Invariant = enum(u8) {
    I1, I2, I3, I4, I5, I6, I7, I8, I9, I10, I11, I12,

    pub fn label(self: Invariant) []const u8 {
        return @tagName(self);
    }

    pub fn parse(s: []const u8) ?Invariant {
        inline for (@typeInfo(Invariant).@"enum".fields) |f| {
            if (std.mem.eql(u8, f.name, s)) return @enumFromInt(f.value);
        }
        return null;
    }
};

pub const CheckStatus = enum {
    pass,
    fail,
    @"reference-disagreement",
    skipped,
    @"not-applicable",
    // Coverage lives outside the battery's own check (a committed external
    // fixture, or a gap deferred to the change-log / claims register).
    external,
    @"error",
};

pub const ExitClass = enum {
    pass,
    @"artifact-bad",
    @"reference-bad",
    @"battery-bad",
};

pub const ArtifactKind = enum {
    @"pinned-v",
    bracket,
};

pub const ArtifactFormat = enum {
    WZO1,
    WZO2,
};

pub const I5GraphKind = enum {
    @"all-legal",
    reachable,
};

pub const SeedSource = enum {
    fixed,
    auto,
};

pub const ModeDeclared = enum {
    exhaustive,
    sampled,
    @"not-applicable",
};

pub const ErrorKind = enum {
    memory_budget,
    stack_overflow,
    oom,
    artifact_load,
    internal,
};

// ═══════════════════════════════════════════════════════════════════════════
// §6a matrix
// ═══════════════════════════════════════════════════════════════════════════

pub fn modeForCell(inv: Invariant, gs: GobanSize) ModeDeclared {
    return switch (inv) {
        .I1, .I2, .I4, .I6, .I7, .I9, .I12 => .exhaustive,
        .I3, .I10 => .exhaustive,
        .I5 => .exhaustive,
        .I8 => if (gs.w == 2 and gs.h == 2) .exhaustive else .@"not-applicable",
        .I11 => if (gs.w <= 3 and gs.h <= 2) .exhaustive else .sampled,
    };
}

pub fn notApplicableOnWZO1(inv: Invariant) bool {
    return inv == .I3 or inv == .I10;
}

// ═══════════════════════════════════════════════════════════════════════════
// WZO1 artifact loader (re-implemented per R8)
// ═══════════════════════════════════════════════════════════════════════════

pub const WZO1_MAGIC = [4]u8{ 'W', 'Z', 'O', '1' };
pub const WZO2_MAGIC = [4]u8{ 'W', 'Z', 'O', '2' };
pub const WZO1_HEADER_LEN: usize = 32;
pub const WZO1_RULES_PSK: u8 = 1;
pub const WZO1_RULES_BASICKO_TIE: u8 = 2;

pub fn rulesName(rules_id: u8) []const u8 {
    return switch (rules_id) {
        WZO1_RULES_PSK => "Chinese area, komi 0, positional superko",
        WZO1_RULES_BASICKO_TIE => "Chinese area, komi 0, basic ko, TIE=0 on cycles",
        else => "unknown",
    };
}

pub const WZO1Header = struct {
    board_w: u8,
    board_h: u8,
    total: u64,
    legal_count: u64,
    rules_id: u8,
};

pub const WZO1Columns = struct {
    vb: []const i8,
    vw: []const i8,
    fb: []const u8,
    fw: []const u8,
    db: []const u8,
    dw: []const u8,
};

pub const WZO1Decoded = struct {
    gpa: Allocator,
    header: WZO1Header,
    vb: []i8,
    vw: []i8,
    fb: []u8,
    fw: []u8,
    db: []u8,
    dw: []u8,

    pub fn deinit(d: *WZO1Decoded) void {
        d.gpa.free(d.vb);
        d.gpa.free(d.vw);
        d.gpa.free(d.fb);
        d.gpa.free(d.fw);
        d.gpa.free(d.db);
        d.gpa.free(d.dw);
    }
};

pub const WZO1LoadError = error{
    BadMagic,
    BadVersion,
    BadLayout,
    BadSemantics,
    BadTotal,
    BadChecksum,
    Truncated,
    WZO2NotSupported,
    OutOfMemory,
};

fn pow3(n: u8) u64 {
    var x: u64 = 1;
    for (0..n) |_| x *= 3;
    return x;
}

pub fn decodeWZO1(gpa: Allocator, bytes: []const u8) WZO1LoadError!WZO1Decoded {
    if (bytes.len < WZO1_HEADER_LEN) return error.Truncated;
    if (std.mem.eql(u8, bytes[0..4], &WZO2_MAGIC)) return error.WZO2NotSupported;
    if (!std.mem.eql(u8, bytes[0..4], &WZO1_MAGIC)) return error.BadMagic;
    if (bytes[4] != 1) return error.BadVersion;
    if (bytes[5] != 1) return error.BadLayout;
    if (bytes[8] != 1) return error.BadSemantics;
    const r_id = bytes[9];
    if (r_id != WZO1_RULES_PSK and r_id != WZO1_RULES_BASICKO_TIE) return error.BadSemantics;
    if (bytes[10] != 6) return error.BadVersion;

    const header = WZO1Header{
        .board_w = bytes[6],
        .board_h = bytes[7],
        .total = std.mem.readInt(u64, bytes[12..20], .little),
        .legal_count = std.mem.readInt(u64, bytes[20..28], .little),
        .rules_id = r_id,
    };
    const n_cells: u16 = @as(u16, header.board_w) * @as(u16, header.board_h);
    if (n_cells == 0 or n_cells > 40 or header.total != pow3(@intCast(n_cells))) return error.BadTotal;

    const t: usize = @intCast(header.total);
    if (bytes.len != WZO1_HEADER_LEN + 6 * t) return error.Truncated;

    const payload = bytes[WZO1_HEADER_LEN..];
    const stored_crc = std.mem.readInt(u32, bytes[28..32], .little);
    if (std.hash.crc.Crc32IsoHdlc.hash(payload) != stored_crc) return error.BadChecksum;

    var d = WZO1Decoded{
        .gpa = gpa,
        .header = header,
        .vb = undefined, .vw = undefined, .fb = undefined,
        .fw = undefined, .db = undefined, .dw = undefined,
    };
    d.vb = gpa.alloc(i8, t) catch return error.OutOfMemory;
    errdefer gpa.free(d.vb);
    d.vw = gpa.alloc(i8, t) catch return error.OutOfMemory;
    errdefer gpa.free(d.vw);
    d.fb = gpa.alloc(u8, t) catch return error.OutOfMemory;
    errdefer gpa.free(d.fb);
    d.fw = gpa.alloc(u8, t) catch return error.OutOfMemory;
    errdefer gpa.free(d.fw);
    d.db = gpa.alloc(u8, t) catch return error.OutOfMemory;
    errdefer gpa.free(d.db);
    d.dw = gpa.alloc(u8, t) catch return error.OutOfMemory;
    errdefer gpa.free(d.dw);
    @memcpy(std.mem.sliceAsBytes(d.vb), payload[0 * t .. 1 * t]);
    @memcpy(std.mem.sliceAsBytes(d.vw), payload[1 * t .. 2 * t]);
    @memcpy(d.fb, payload[2 * t .. 3 * t]);
    @memcpy(d.fw, payload[3 * t .. 4 * t]);
    @memcpy(d.db, payload[4 * t .. 5 * t]);
    @memcpy(d.dw, payload[5 * t .. 6 * t]);
    return d;
}

// ═══════════════════════════════════════════════════════════════════════════
// Colex addressing (runtime-parameterized)
// ═══════════════════════════════════════════════════════════════════════════

pub const Colex = struct {
    n: u8,
    total: u64,
    binomial: [][]u64,
    layer_offset: []u64,
    allocator: Allocator,

    pub fn init(allocator: Allocator, w: u8, h: u8) !Colex {
        const n: u8 = @intCast(@as(u16, w) * @as(u16, h));
        const N: usize = n + 1;

        const bin_flat = try allocator.alloc(u64, N * N);
        errdefer allocator.free(bin_flat);
        @memset(bin_flat, 0);
        const binomial = try allocator.alloc([]u64, N);
        errdefer allocator.free(binomial);
        for (0..N) |i| binomial[i] = bin_flat[i * N .. (i + 1) * N];
        for (0..N) |i| {
            binomial[i][0] = 1;
            for (1..i + 1) |j| {
                binomial[i][j] = binomial[i - 1][j - 1] + (if (j <= i - 1) binomial[i - 1][j] else 0);
            }
        }

        const layer_offset = try allocator.alloc(u64, n + 2);
        errdefer allocator.free(layer_offset);
        layer_offset[0] = 0;
        for (0..n + 1) |k| {
            layer_offset[k + 1] = layer_offset[k] + binomial[n][k] * (@as(u64, 1) << @intCast(k));
        }

        return Colex{
            .n = n,
            .total = layer_offset[n + 1],
            .binomial = binomial,
            .layer_offset = layer_offset,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Colex) void {
        if (self.binomial.len > 0) {
            self.allocator.free(self.binomial[0]);
            self.allocator.free(self.binomial);
        }
        if (self.layer_offset.len > 0) self.allocator.free(self.layer_offset);
    }

    pub fn colexFromPos(self: *const Colex, pos: []const i8) u64 {
        var k: usize = 0;
        var subset: u64 = 0;
        var colours: u64 = 0;
        for (0..self.n) |cell| {
            if (pos[cell] == 0) continue;
            if (pos[cell] > 0) colours |= @as(u64, 1) << @intCast(k);
            k += 1;
            subset += self.binomial[cell][k];
        }
        return self.layer_offset[k] + subset * (@as(u64, 1) << @intCast(k)) + colours;
    }

    pub fn posFromColex(self: *const Colex, idx: u64, pos: []i8) void {
        std.debug.assert(idx < self.total);
        var k: usize = 0;
        while (idx >= self.layer_offset[k + 1]) k += 1;
        const layer_idx = idx - self.layer_offset[k];
        var subset = layer_idx >> @intCast(k);
        const colours = layer_idx & ((@as(u64, 1) << @intCast(k)) - 1);

        @memset(pos[0..self.n], 0);
        var i = k;
        while (i > 0) : (i -= 1) {
            var cell = self.n - 1;
            while (self.binomial[cell][i] > subset) cell -= 1;
            subset -= self.binomial[cell][i];
            const black = (colours >> @intCast(i - 1)) & 1 == 1;
            pos[cell] = if (black) @as(i8, 1) else @as(i8, -1);
        }
    }
};

// ═══════════════════════════════════════════════════════════════════════════
// Invariant-specific value types (stubs for schema reference)
// ═══════════════════════════════════════════════════════════════════════════

pub const ErrorInfo = struct {
    kind: ErrorKind,
    message: []const u8,
    predicted_rss_mb: ?f64 = null,
    fallback_tier: ?[]const u8 = null,
    artifact_magic: ?[]const u8 = null,
};

pub const CheckResultValue = struct {
    numerator: u64,
    denominator: u64,
};

pub const CheckResult = struct {
    invariant: Invariant,
    goban: GobanSize,
    artifact_kind: ?ArtifactKind,
    format: ?ArtifactFormat,
    format_version: ?u8,
    artifact: ?[]const u8,
    artifact_sha256: ?[]const u8,
    mode_declared: ModeDeclared,
    mode_actual: ModeDeclared,
    scope_once_per_goban: bool,
    status: CheckStatus,
    exit_class: ExitClass,
    duration_ms: u64,
    rss_hwm_after_mb: ?f64,
    seed: ?u64,
    sample_size: ?u64,
    sample_denominator: ?u64,
    value: ?CheckResultValue,
    deviation: ?[]const u8,
    @"error": ?ErrorInfo,
};

pub const CheckOptions = struct {
    seed: u64 = 31337,
    sample_size: ?u64 = null,
    i5_graph: ?I5GraphKind = null,
    allow_mode_deviation: bool = false,
};

// ═══════════════════════════════════════════════════════════════════════════
// JSON writing
// ═══════════════════════════════════════════════════════════════════════════

pub fn writeJsonRecord(writer: anytype, value: anytype) !void {
    try std.json.value(value, .{}, writer);
    try writer.writeByte('\n');
}
