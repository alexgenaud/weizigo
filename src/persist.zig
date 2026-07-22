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
// On-disk checkpoint of solved positions (the transposition table).
//
// The disk format is intentionally decoupled from the in-memory layout:
//   in-memory  = two dense blind->index tables + a SeqScore block pool
//                (solve.Table), chosen for O(1) lookup / cheap copy / evaluate.
//   on-disk    = a flat, sorted, delta+varint packed record stream,
//                chosen for size. Each record is one solved position:
//                    blind  (<=25 bits) which cells are occupied,
//                    black  which side's table it lives in,
//                    seq    (<=16 bits) black/white pattern of the stones,
//                    score  (i8) minimax value.
//
// Records are grouped into a black section and a white section, each sorted
// by (blind, seq); blinds are delta-coded and everything is LEB128 varint
// packed. On this structured, sorted integer data that alone is a large
// reduction; a general codec (std.compress.flate/gzip) can be layered on
// top later for a bit more if wanted.
//
// Block sizing follows solve.block_size(num_stones) = 2^(num_stones-1); it no
// longer depends on a search depth. `Header.max_depth` is kept for provenance
// only (it does NOT affect the block layout). See ADR-0007.

const std = @import("std");
const Allocator = std.mem.Allocator;

const util = @import("util.zig");
const solve = @import("solve.zig");
const SeqScore = solve.SeqScore;
const block_size = solve.block_size;
const UNDEF = util.UNDEF;

const MAGIC = [4]u8{ 'W', 'Z', 'G', '1' };
const VERSION: u8 = 1;

pub const Record = struct {
    blind: u32,
    black: bool,
    seq: u16,
    score: i8,
};

pub const Header = struct {
    board_w: u8,
    board_h: u8,
    max_depth: u8, // provenance only; block layout is depth-independent (ADR-0007)
};

pub const Decoded = struct {
    records: []Record,
    header: Header,
};

pub const LoadResult = struct {
    header: Header,
    count: usize,
    // Next free index in the seq pool after the checkpoint was applied. Assign
    // to solve.Table.next so a resumed search allocates past the loaded data.
    next_index: u32,
};

pub const Error = error{
    BadMagic,
    BadVersion,
    Truncated,
    SeqTableFull,
};

// ---- LEB128 unsigned varint -------------------------------------------------

fn writeVarint(out: *std.ArrayList(u8), gpa: Allocator, value: u64) Allocator.Error!void {
    var x = value;
    while (true) {
        const byte: u8 = @intCast(x & 0x7f);
        x >>= 7;
        if (x == 0) {
            try out.append(gpa, byte);
            return;
        }
        try out.append(gpa, byte | 0x80);
    }
}

fn readVarint(bytes: []const u8, idx: *usize) Error!u64 {
    var result: u64 = 0;
    var shift: u6 = 0;
    while (true) {
        if (idx.* >= bytes.len) return Error.Truncated;
        const byte = bytes[idx.*];
        idx.* += 1;
        result |= @as(u64, byte & 0x7f) << shift;
        if (byte & 0x80 == 0) return result;
        shift += 7; // valid data never needs shift > 63
    }
}

fn readByte(bytes: []const u8, idx: *usize) Error!u8 {
    if (idx.* >= bytes.len) return Error.Truncated;
    const b = bytes[idx.*];
    idx.* += 1;
    return b;
}

// ---- record helpers ---------------------------------------------------------

fn lessThan(_: void, a: Record, b: Record) bool {
    if (a.blind != b.blind) return a.blind < b.blind;
    return a.seq < b.seq;
}

fn num_stones_of(blind: u32) u8 {
    return @popCount(blind);
}

// ---- encode / decode --------------------------------------------------------

/// Serialize `records` to a freshly allocated byte slice. Caller owns it.
pub fn encode(gpa: Allocator, records: []const Record, header: Header) Allocator.Error![]u8 {
    // split by colour so each section's blinds are monotonic for delta coding
    var black: std.ArrayList(Record) = .empty;
    defer black.deinit(gpa);
    var white: std.ArrayList(Record) = .empty;
    defer white.deinit(gpa);
    for (records) |r| {
        if (r.black) try black.append(gpa, r) else try white.append(gpa, r);
    }
    std.mem.sort(Record, black.items, {}, lessThan);
    std.mem.sort(Record, white.items, {}, lessThan);

    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(gpa);
    try out.appendSlice(gpa, &MAGIC);
    try out.append(gpa, VERSION);
    try out.append(gpa, header.board_w);
    try out.append(gpa, header.board_h);
    try out.append(gpa, header.max_depth);
    try encodeSection(&out, gpa, black.items);
    try encodeSection(&out, gpa, white.items);
    return out.toOwnedSlice(gpa);
}

fn encodeSection(out: *std.ArrayList(u8), gpa: Allocator, recs: []const Record) Allocator.Error!void {
    try writeVarint(out, gpa, recs.len);
    var prev_blind: u32 = 0;
    for (recs) |r| {
        try writeVarint(out, gpa, r.blind - prev_blind); // sorted => delta >= 0
        prev_blind = r.blind;
        try writeVarint(out, gpa, r.seq);
        try out.append(gpa, @bitCast(r.score));
    }
}

/// Parse a byte slice produced by `encode`. Caller owns `.records`.
pub fn decode(gpa: Allocator, bytes: []const u8) (Error || Allocator.Error)!Decoded {
    var idx: usize = 0;
    if (bytes.len < 8) return Error.Truncated;
    if (!std.mem.eql(u8, bytes[0..4], &MAGIC)) return Error.BadMagic;
    idx = 4;
    if (try readByte(bytes, &idx) != VERSION) return Error.BadVersion;
    const header = Header{
        .board_w = try readByte(bytes, &idx),
        .board_h = try readByte(bytes, &idx),
        .max_depth = try readByte(bytes, &idx),
    };

    var records: std.ArrayList(Record) = .empty;
    errdefer records.deinit(gpa);
    try decodeSection(bytes, &idx, gpa, &records, true);
    try decodeSection(bytes, &idx, gpa, &records, false);
    return .{ .records = try records.toOwnedSlice(gpa), .header = header };
}

fn decodeSection(
    bytes: []const u8,
    idx: *usize,
    gpa: Allocator,
    out: *std.ArrayList(Record),
    black: bool,
) (Error || Allocator.Error)!void {
    const n = try readVarint(bytes, idx);
    var prev_blind: u32 = 0;
    var i: u64 = 0;
    while (i < n) : (i += 1) {
        const blind: u32 = prev_blind + @as(u32, @intCast(try readVarint(bytes, idx)));
        prev_blind = blind;
        const seq: u16 = @intCast(try readVarint(bytes, idx));
        const score: i8 = @bitCast(try readByte(bytes, idx));
        try out.append(gpa, .{ .blind = blind, .black = black, .seq = seq, .score = score });
    }
}

// ---- table <-> records ------------------------------------------------------

/// Walk the in-memory tables and collect every stored (blind, colour, seq)
/// -> score as a flat record list. Caller owns the result.
pub fn extract(
    gpa: Allocator,
    black_table: []const u32,
    white_table: []const u32,
    seq_table: []const SeqScore,
) Allocator.Error![]Record {
    var out: std.ArrayList(Record) = .empty;
    errdefer out.deinit(gpa);
    try extractTable(&out, gpa, black_table, seq_table, true);
    try extractTable(&out, gpa, white_table, seq_table, false);
    return out.toOwnedSlice(gpa);
}

fn extractTable(
    out: *std.ArrayList(Record),
    gpa: Allocator,
    table: []const u32,
    seq_table: []const SeqScore,
    black: bool,
) Allocator.Error!void {
    for (table, 0..) |start, blind| {
        if (start == 0) continue; // index 0 is the "unset" sentinel
        const size = block_size(num_stones_of(@intCast(blind)));
        var i: u32 = start;
        const end = start + size;
        while (i < end) : (i += 1) {
            const e = seq_table[i];
            if (e.score == UNDEF) break; // block is filled from the front
            try out.append(gpa, .{
                .blind = @intCast(blind),
                .black = black,
                .seq = e.seq,
                .score = e.score,
            });
        }
    }
}

/// Rebuild the in-memory tables from a record list. `black_table`,
/// `white_table` and `seq_table` must be zero-initialized. Returns the next
/// free seq index (assign to solve.Table.next to resume a search).
/// Index 0 is reserved as the "unset" sentinel.
pub fn apply(
    records: []const Record,
    black_table: []u32,
    white_table: []u32,
    seq_table: []SeqScore,
) Error!u32 {
    var next: u32 = 1; // reserve 0 as the "unset" sentinel
    for (records) |r| {
        const table = if (r.black) black_table else white_table;
        const size = block_size(num_stones_of(r.blind));
        var start = table[r.blind];
        if (start == 0) {
            if (next + size > seq_table.len) return Error.SeqTableFull;
            start = next;
            table[r.blind] = start;
            next += size;
        }
        // place into the block: first slot matching seq or still unset
        var i: u32 = start;
        const end = start + size;
        while (i < end) : (i += 1) {
            const cur = &seq_table[i];
            if (cur.score == UNDEF or cur.seq == r.seq) {
                cur.seq = r.seq;
                cur.score = r.score;
                break;
            }
        }
    }
    return next;
}

// ---- file save / load -------------------------------------------------------

/// Extract, encode and write the checkpoint to `sub_path` under `dir`.
pub fn save(
    io: std.Io,
    dir: std.Io.Dir,
    sub_path: []const u8,
    gpa: Allocator,
    black_table: []const u32,
    white_table: []const u32,
    seq_table: []const SeqScore,
    header: Header,
) !void {
    const recs = try extract(gpa, black_table, white_table, seq_table);
    defer gpa.free(recs);
    const bytes = try encode(gpa, recs, header);
    defer gpa.free(bytes);
    try dir.writeFile(io, .{ .sub_path = sub_path, .data = bytes });
}

/// Read, decode and apply a checkpoint from `sub_path` under `dir`.
pub fn load(
    io: std.Io,
    dir: std.Io.Dir,
    sub_path: []const u8,
    gpa: Allocator,
    black_table: []u32,
    white_table: []u32,
    seq_table: []SeqScore,
) !LoadResult {
    const bytes = try dir.readFileAlloc(io, sub_path, gpa, .unlimited);
    defer gpa.free(bytes);
    const dec = try decode(gpa, bytes);
    defer gpa.free(dec.records);
    const next = try apply(dec.records, black_table, white_table, seq_table);
    return .{ .header = dec.header, .count = dec.records.len, .next_index = next };
}

// ---- tests (deliberately tiny: no 2^25 tables) ------------------------------

const expect = std.testing.expect;

test "varint round trip" {
    const gpa = std.testing.allocator;
    const values = [_]u64{ 0, 1, 127, 128, 255, 16384, 32767, 33554431, 1 << 40 };
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);
    for (values) |v| try writeVarint(&out, gpa, v);
    var idx: usize = 0;
    for (values) |v| try expect(try readVarint(out.items, &idx) == v);
    try expect(idx == out.items.len);
}

test "codec round trip preserves records and header" {
    const gpa = std.testing.allocator;
    const in = [_]Record{
        .{ .blind = 7, .black = true, .seq = 0, .score = 10 },
        .{ .blind = 7, .black = true, .seq = 2, .score = 7 },
        .{ .blind = 7, .black = true, .seq = 1, .score = -4 },
        .{ .blind = 10, .black = true, .seq = 0, .score = 5 },
        .{ .blind = 7, .black = false, .seq = 0, .score = -9 },
        .{ .blind = 25_000_000, .black = false, .seq = 32767, .score = -128 + 1 },
    };
    const bytes = try encode(gpa, &in, .{ .board_w = 5, .board_h = 5, .max_depth = 8 });
    defer gpa.free(bytes);
    const dec = try decode(gpa, bytes);
    defer gpa.free(dec.records);

    try expect(dec.header.board_w == 5 and dec.header.board_h == 5 and dec.header.max_depth == 8);
    try expect(dec.records.len == in.len);
    // every input record must appear in the decoded set
    for (in) |want| {
        var found = false;
        for (dec.records) |got| {
            if (got.blind == want.blind and got.black == want.black and
                got.seq == want.seq and got.score == want.score) found = true;
        }
        try expect(found);
    }
}

test "decode rejects corrupt input" {
    const gpa = std.testing.allocator;
    try std.testing.expectError(Error.BadMagic, decode(gpa, "XXXX....."));
    try std.testing.expectError(Error.Truncated, decode(gpa, "WZG"));
}

test "extract/apply round trip through small tables" {
    const gpa = std.testing.allocator;
    // blinds < 16 keep the tables tiny; block_size = 2^(popcount-1)
    const seed = [_]Record{
        .{ .blind = 7, .black = true, .seq = 0, .score = 12 }, // 3 stones -> block 4
        .{ .blind = 7, .black = true, .seq = 2, .score = -3 },
        .{ .blind = 7, .black = true, .seq = 1, .score = 40 },
        .{ .blind = 10, .black = true, .seq = 0, .score = 6 }, // 2 stones -> block 2
        .{ .blind = 7, .black = false, .seq = 1, .score = -50 },
        .{ .blind = 15, .black = false, .seq = 3, .score = 1 }, // 4 stones -> block 8
    };

    var black1 = [_]u32{0} ** 16;
    var white1 = [_]u32{0} ** 16;
    var seq1 = [_]SeqScore{.{}} ** 64;
    const next = try apply(&seed, &black1, &white1, &seq1);
    try expect(next > 1);

    const recs = try extract(gpa, &black1, &white1, &seq1);
    defer gpa.free(recs);
    try expect(recs.len == seed.len);

    // full pipeline: extract -> encode -> decode -> apply into fresh tables
    const bytes = try encode(gpa, recs, .{ .board_w = 5, .board_h = 5, .max_depth = 8 });
    defer gpa.free(bytes);
    const dec = try decode(gpa, bytes);
    defer gpa.free(dec.records);

    var black2 = [_]u32{0} ** 16;
    var white2 = [_]u32{0} ** 16;
    var seq2 = [_]SeqScore{.{}} ** 64;
    _ = try apply(dec.records, &black2, &white2, &seq2);

    // every seeded fact must resolve identically in the rebuilt tables
    for (seed) |want| {
        const table = if (want.black) &black2 else &white2;
        const start = table[want.blind];
        try expect(start != 0);
        const size = block_size(num_stones_of(want.blind));
        var got: ?i8 = null;
        var i: u32 = start;
        while (i < start + size) : (i += 1) {
            if (seq2[i].score != UNDEF and seq2[i].seq == want.seq) got = seq2[i].score;
        }
        try expect(got != null and got.? == want.score);
    }
}
