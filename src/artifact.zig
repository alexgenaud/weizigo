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
// ORACLE ARTIFACT (ADR-0011) — the persisted perfect oracle itself.
//
// Distinct from persist.zig (the forward-search TT *checkpoint*): this file
// IS the product — the complete value/dtt/flags table of a solved board,
// colex-addressed (ADR-0007/0009). The payload is the six frozen schema
// columns (ADR-0009 decision 4), dense over the RAW colex address space,
// in this order:
//
//   vb  i8  value, Black to move   (Black-positive; UNDEF -128 = illegal slot)
//   vw  i8  value, White to move   (STILL Black-positive — side picks the
//                                   column, never the sign)
//   fb  u8  flags, Black to move   (bit0 KO_SENSITIVE, bit1 FROM_FORWARD)
//   fw  u8  flags, White to move
//   db  u8  dtt,   Black to move   (fastest optimal resolution; 255 = FAR)
//   dw  u8  dtt,   White to move
//
// FORMAT CONTRACT: a stored value's location is defined by colex.zig's
// address layout. The header therefore records colex.layout_version next to
// the artifact format version; a reader refuses either mismatch. Header
// (little-endian, 32 bytes):
//
//   0  4  magic "WZO1"
//   4  1  format_version    = 1
//   5  1  colex_layout      = colex.layout_version
//   6  1  board_w
//   7  1  board_h
//   8  1  value_semantics   = 1  (fresh-start value, ADR-0008)
//   9  1  rules_id          = 1  (Chinese area, komi 0, positional superko,
//                                 Benson/double-pass terminal)
//  10  1  column_count      = 6  (the schema above, in that order)
//  11  1  reserved          = 0
//  12  8  total             u64, == 3^(w*h) (raw layered colex space)
//  20  8  legal_count       u64, provenance/sanity (legal positions per side)
//  28  4  payload_crc32     u32, CRC-32 (ISO-HDLC) of the whole payload
//  32  payload: vb | vw | fb | fw | db | dw, each `total` bytes
//
// Dense-raw is deliberate (colex.zig: "RAW"): simple, O(1) addressable,
// sufficient through 4x4. Density folds (legal-only, canonical-only) are a
// LAYOUT change -> new colex_layout version, same reader shape. A general
// compressor (gzip) can wrap the file; the format stays byte-addressable.
//
// Standalone: imports colex.zig (std only) — safe for per-module `zig test`.

const std = @import("std");
const Allocator = std.mem.Allocator;
const colex = @import("colex.zig");

pub const MAGIC = [4]u8{ 'W', 'Z', 'O', '1' };
pub const FORMAT_VERSION: u8 = 1;
pub const VALUE_SEMANTICS_FRESH_START: u8 = 1; // ADR-0008
pub const RULES_CHINESE_PSK: u8 = 1;
pub const COLUMN_COUNT: u8 = 6;
pub const HEADER_LEN: usize = 32;

pub const Header = struct {
    board_w: u8,
    board_h: u8,
    total: u64, // == 3^(board_w*board_h)
    legal_count: u64,
};

/// The six schema columns, each exactly `total` bytes. `encode` borrows,
/// `decode` allocates (caller frees via `Decoded.deinit`).
pub const Columns = struct {
    vb: []const i8,
    vw: []const i8,
    fb: []const u8,
    fw: []const u8,
    db: []const u8,
    dw: []const u8,
};

pub const Decoded = struct {
    gpa: Allocator,
    header: Header,
    vb: []i8,
    vw: []i8,
    fb: []u8,
    fw: []u8,
    db: []u8,
    dw: []u8,

    pub fn deinit(d: *Decoded) void {
        d.gpa.free(d.vb);
        d.gpa.free(d.vw);
        d.gpa.free(d.fb);
        d.gpa.free(d.fw);
        d.gpa.free(d.db);
        d.gpa.free(d.dw);
    }
};

pub const Error = error{
    BadMagic,
    BadVersion,
    BadLayout,
    BadSemantics,
    BadTotal,
    BadChecksum,
    Truncated,
};

fn pow3(n: u8) u64 {
    var x: u64 = 1;
    for (0..n) |_| x *= 3;
    return x;
}

fn writeU64(buf: []u8, v: u64) void {
    std.mem.writeInt(u64, buf[0..8], v, .little);
}

fn writeU32(buf: []u8, v: u32) void {
    std.mem.writeInt(u32, buf[0..4], v, .little);
}

/// Serialize header + columns to a freshly allocated byte slice. Caller owns.
pub fn encode(gpa: Allocator, header: Header, cols: Columns) Allocator.Error![]u8 {
    const t: usize = @intCast(header.total);
    std.debug.assert(cols.vb.len == t and cols.vw.len == t and cols.fb.len == t and
        cols.fw.len == t and cols.db.len == t and cols.dw.len == t);
    const out = try gpa.alloc(u8, HEADER_LEN + 6 * t);
    @memcpy(out[0..4], &MAGIC);
    out[4] = FORMAT_VERSION;
    out[5] = colex.layout_version;
    out[6] = header.board_w;
    out[7] = header.board_h;
    out[8] = VALUE_SEMANTICS_FRESH_START;
    out[9] = RULES_CHINESE_PSK;
    out[10] = COLUMN_COUNT;
    out[11] = 0;
    writeU64(out[12..20], header.total);
    writeU64(out[20..28], header.legal_count);
    const payload = out[HEADER_LEN..];
    @memcpy(payload[0 * t .. 1 * t], std.mem.sliceAsBytes(cols.vb));
    @memcpy(payload[1 * t .. 2 * t], std.mem.sliceAsBytes(cols.vw));
    @memcpy(payload[2 * t .. 3 * t], cols.fb);
    @memcpy(payload[3 * t .. 4 * t], cols.fw);
    @memcpy(payload[4 * t .. 5 * t], cols.db);
    @memcpy(payload[5 * t .. 6 * t], cols.dw);
    writeU32(out[28..32], std.hash.crc.Crc32IsoHdlc.hash(payload));
    return out;
}

/// Parse + verify a byte slice (magic, versions, layout, total, checksum)
/// and return allocated column copies. Caller: `defer decoded.deinit()`.
pub fn decode(gpa: Allocator, bytes: []const u8) (Error || Allocator.Error)!Decoded {
    if (bytes.len < HEADER_LEN) return Error.Truncated;
    if (!std.mem.eql(u8, bytes[0..4], &MAGIC)) return Error.BadMagic;
    if (bytes[4] != FORMAT_VERSION) return Error.BadVersion;
    if (bytes[5] != colex.layout_version) return Error.BadLayout;
    if (bytes[8] != VALUE_SEMANTICS_FRESH_START or bytes[9] != RULES_CHINESE_PSK) return Error.BadSemantics;
    if (bytes[10] != COLUMN_COUNT) return Error.BadVersion;
    const header = Header{
        .board_w = bytes[6],
        .board_h = bytes[7],
        .total = std.mem.readInt(u64, bytes[12..20], .little),
        .legal_count = std.mem.readInt(u64, bytes[20..28], .little),
    };
    const n_cells = @as(u16, header.board_w) * @as(u16, header.board_h);
    if (n_cells == 0 or n_cells > 40 or header.total != pow3(@intCast(n_cells))) return Error.BadTotal;
    const t: usize = @intCast(header.total);
    if (bytes.len != HEADER_LEN + 6 * t) return Error.Truncated;
    const payload = bytes[HEADER_LEN..];
    const crc = std.mem.readInt(u32, bytes[28..32], .little);
    if (std.hash.crc.Crc32IsoHdlc.hash(payload) != crc) return Error.BadChecksum;

    var d = Decoded{
        .gpa = gpa,
        .header = header,
        .vb = undefined,
        .vw = undefined,
        .fb = undefined,
        .fw = undefined,
        .db = undefined,
        .dw = undefined,
    };
    d.vb = try gpa.alloc(i8, t);
    errdefer gpa.free(d.vb);
    d.vw = try gpa.alloc(i8, t);
    errdefer gpa.free(d.vw);
    d.fb = try gpa.alloc(u8, t);
    errdefer gpa.free(d.fb);
    d.fw = try gpa.alloc(u8, t);
    errdefer gpa.free(d.fw);
    d.db = try gpa.alloc(u8, t);
    errdefer gpa.free(d.db);
    d.dw = try gpa.alloc(u8, t);
    errdefer gpa.free(d.dw);
    @memcpy(std.mem.sliceAsBytes(d.vb), payload[0 * t .. 1 * t]);
    @memcpy(std.mem.sliceAsBytes(d.vw), payload[1 * t .. 2 * t]);
    @memcpy(d.fb, payload[2 * t .. 3 * t]);
    @memcpy(d.fw, payload[3 * t .. 4 * t]);
    @memcpy(d.db, payload[4 * t .. 5 * t]);
    @memcpy(d.dw, payload[5 * t .. 6 * t]);
    return d;
}

/// Encode and write the artifact to `sub_path` under `dir` (same io-passing
/// shape as persist.save). Parent directories are created as needed.
pub fn save(io: std.Io, dir: std.Io.Dir, sub_path: []const u8, gpa: Allocator, header: Header, cols: Columns) !void {
    const bytes = try encode(gpa, header, cols);
    defer gpa.free(bytes);
    if (std.fs.path.dirname(sub_path)) |parent| try dir.createDirPath(io, parent);
    try dir.writeFile(io, .{ .sub_path = sub_path, .data = bytes });
}

/// Read, verify and decode an artifact from `sub_path` under `dir`.
pub fn load(io: std.Io, dir: std.Io.Dir, sub_path: []const u8, gpa: Allocator) !Decoded {
    const bytes = try dir.readFileAlloc(io, sub_path, gpa, .unlimited);
    defer gpa.free(bytes);
    return decode(gpa, bytes);
}

// ---- tests ------------------------------------------------------------------

const expect = std.testing.expect;

fn testColumns(gpa: Allocator, t: usize) !struct { vb: []i8, vw: []i8, fb: []u8, fw: []u8, db: []u8, dw: []u8 } {
    const vb = try gpa.alloc(i8, t);
    const vw = try gpa.alloc(i8, t);
    const fb = try gpa.alloc(u8, t);
    const fw = try gpa.alloc(u8, t);
    const db = try gpa.alloc(u8, t);
    const dw = try gpa.alloc(u8, t);
    for (0..t) |i| {
        vb[i] = @intCast(@as(i64, @intCast(i % 19)) - 9);
        vw[i] = -vb[i];
        fb[i] = @intCast(i % 4);
        fw[i] = @intCast((i + 1) % 4);
        db[i] = @intCast(i % 256);
        dw[i] = @intCast((i * 7) % 256);
    }
    return .{ .vb = vb, .vw = vw, .fb = fb, .fw = fw, .db = db, .dw = dw };
}

test "round-trip: encode -> decode reproduces header and every column" {
    const gpa = std.testing.allocator;
    const t: usize = 27; // 1x3 board: 3^3 slots
    const c = try testColumns(gpa, t);
    defer inline for (.{ c.vb, c.vw, c.fb, c.fw, c.db, c.dw }) |s| gpa.free(s);
    const header = Header{ .board_w = 1, .board_h = 3, .total = t, .legal_count = 21 };
    const cols = Columns{ .vb = c.vb, .vw = c.vw, .fb = c.fb, .fw = c.fw, .db = c.db, .dw = c.dw };
    const bytes = try encode(gpa, header, cols);
    defer gpa.free(bytes);
    try expect(bytes.len == HEADER_LEN + 6 * t);

    var d = try decode(gpa, bytes);
    defer d.deinit();
    try expect(d.header.board_w == 1 and d.header.board_h == 3);
    try expect(d.header.total == t and d.header.legal_count == 21);
    try expect(std.mem.eql(i8, d.vb, c.vb));
    try expect(std.mem.eql(i8, d.vw, c.vw));
    try expect(std.mem.eql(u8, d.fb, c.fb));
    try expect(std.mem.eql(u8, d.fw, c.fw));
    try expect(std.mem.eql(u8, d.db, c.db));
    try expect(std.mem.eql(u8, d.dw, c.dw));
}

test "reader refuses: bad magic, version, layout, total, checksum, truncation" {
    const gpa = std.testing.allocator;
    const t: usize = 27;
    const c = try testColumns(gpa, t);
    defer inline for (.{ c.vb, c.vw, c.fb, c.fw, c.db, c.dw }) |s| gpa.free(s);
    const header = Header{ .board_w = 1, .board_h = 3, .total = t, .legal_count = 21 };
    const cols = Columns{ .vb = c.vb, .vw = c.vw, .fb = c.fb, .fw = c.fw, .db = c.db, .dw = c.dw };
    const good = try encode(gpa, header, cols);
    defer gpa.free(good);
    const corrupt = try gpa.dupe(u8, good);
    defer gpa.free(corrupt);

    corrupt[0] = 'X';
    try std.testing.expectError(Error.BadMagic, decode(gpa, corrupt));
    corrupt[0] = 'W';
    corrupt[4] = FORMAT_VERSION + 1;
    try std.testing.expectError(Error.BadVersion, decode(gpa, corrupt));
    corrupt[4] = FORMAT_VERSION;
    corrupt[5] = colex.layout_version + 1; // the format-contract check
    try std.testing.expectError(Error.BadLayout, decode(gpa, corrupt));
    corrupt[5] = colex.layout_version;
    corrupt[12] += 1; // total no longer 3^n
    try std.testing.expectError(Error.BadTotal, decode(gpa, corrupt));
    corrupt[12] -= 1;
    corrupt[HEADER_LEN + 5] ^= 0x40; // payload bit flip
    try std.testing.expectError(Error.BadChecksum, decode(gpa, corrupt));
    corrupt[HEADER_LEN + 5] ^= 0x40;
    try std.testing.expectError(Error.Truncated, decode(gpa, corrupt[0 .. corrupt.len - 1]));
    try std.testing.expectError(Error.Truncated, decode(gpa, corrupt[0..10]));
    var d = try decode(gpa, corrupt); // restored bytes decode clean again
    d.deinit();
}
