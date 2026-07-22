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
// SGF (Smart Game Format) EXPORT — the bridge to existing visualization
// tools. Presentation is deliberately DELEGATED: weizigo produces .sgf files;
// Sabaki / GoGui / CGoban / any online SGF editor renders boards, variation
// trees, per-node comments, and territory marks. No GUI code here, ever.
//
// Coordinates: SGF uses two lowercase letters, column then row, both from the
// TOP-LEFT ('a' = first). Our row-major cell i maps to
// ('a' + i % w, 'a' + i / w). A pass is an empty property: B[] / W[].
//
// Usage: `zig run src/sgf.zig 2> docs/research/oracle-5x5-pv.sgf` (the demo
// main prints the engine-verified published 5x5 principal variation; output
// goes to stderr so shell redirection needs `2>`).

const std = @import("std");
const expect = std.testing.expect;

pub const Move = struct {
    colour: i8, // +1 black, -1 white
    cell: ?usize, // null = pass
};

/// Append one complete SGF game tree to `out`.
pub fn append_game(
    out: *std.ArrayList(u8),
    gpa: std.mem.Allocator,
    w: usize,
    h: usize,
    comment: []const u8, // root comment; must not contain ']'
    moves: []const Move,
) !void {
    try out.appendSlice(gpa, "(;GM[1]FF[4]CA[UTF-8]AP[weizigo]RU[Chinese]KM[0]SZ[");
    var buf: [16]u8 = undefined;
    if (w == h) {
        try out.appendSlice(gpa, std.fmt.bufPrint(&buf, "{d}", .{w}) catch unreachable);
    } else {
        try out.appendSlice(gpa, std.fmt.bufPrint(&buf, "{d}:{d}", .{ w, h }) catch unreachable);
    }
    try out.appendSlice(gpa, "]");
    if (comment.len > 0) {
        try out.appendSlice(gpa, "C[");
        try out.appendSlice(gpa, comment);
        try out.appendSlice(gpa, "]");
    }
    for (moves) |m| {
        try out.appendSlice(gpa, if (m.colour > 0) ";B[" else ";W[");
        if (m.cell) |cell| {
            const col: u8 = @intCast('a' + cell % w);
            const row: u8 = @intCast('a' + cell / w);
            try out.append(gpa, col);
            try out.append(gpa, row);
        }
        try out.appendSlice(gpa, "]");
    }
    try out.appendSlice(gpa, ")\n");
}

// ---- demo: the engine-verified published 5x5 principal variation --------------

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);

    // docs/research/oracle-5x5-pv.md — van der Werf via Hayward, 13 plies,
    // every move engine-verified legal (state.armies_from_move replay).
    const pv = [_]Move{
        .{ .colour = 1, .cell = 12 }, .{ .colour = -1, .cell = 17 },
        .{ .colour = 1, .cell = 16 }, .{ .colour = -1, .cell = 11 },
        .{ .colour = 1, .cell = 18 }, .{ .colour = -1, .cell = 7 },
        .{ .colour = 1, .cell = 13 }, .{ .colour = -1, .cell = 15 },
        .{ .colour = 1, .cell = 21 }, .{ .colour = -1, .cell = 1 },
        .{ .colour = 1, .cell = 5 },  .{ .colour = -1, .cell = 8 },
        .{ .colour = 1, .cell = 6 },
    };
    try append_game(&out, gpa, 5, 5,
        \\5x5 Go is solved: Black wins by 25 (whole board) with the centre opening. This is *a* published principal variation (van der Werf 2002, via Hayward's course notes p.18), 13 plies, ending where Benson certifies the whole-board win. Every move engine-verified legal by weizigo. Not a unique perfect game.
    , &pv);
    std.debug.print("{s}", .{out.items});
}

// ---- tests ------------------------------------------------------------------

test "sgf: coordinates, colours, pass, exact output" {
    const gpa = std.testing.allocator;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);
    // 3x3: B centre (cell 4 -> col b row b), W pass, B top-left (aa)
    const moves = [_]Move{
        .{ .colour = 1, .cell = 4 },
        .{ .colour = -1, .cell = null },
        .{ .colour = 1, .cell = 0 },
    };
    try append_game(&out, gpa, 3, 3, "", &moves);
    try expect(std.mem.eql(u8,
        out.items,
        "(;GM[1]FF[4]CA[UTF-8]AP[weizigo]RU[Chinese]KM[0]SZ[3];B[bb];W[];B[aa])\n",
    ));
}

test "sgf: 5x5 tengen is cc" {
    const gpa = std.testing.allocator;
    var out: std.ArrayList(u8) = .empty;
    defer out.deinit(gpa);
    try append_game(&out, gpa, 5, 5, "", &[_]Move{.{ .colour = 1, .cell = 12 }});
    try expect(std.mem.indexOf(u8, out.items, ";B[cc]") != null);
}
