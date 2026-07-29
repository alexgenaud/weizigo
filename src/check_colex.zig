const std = @import("std");
const colexmod = @import("colex.zig");
pub fn main(init: std.process.Init) !void {
    const X = colexmod.Indexer(4, 4);
    // B at B2 = cell 1
    var pos1: X.Pos = [_]i8{0} ** 16;
    pos1[1] = 1; // Black at cell 1 (B2)
    const idx1 = X.colex_from_pos(&pos1);
    std.debug.print("B at B2 (cell 1) colex = {d}\n", .{idx1});
    // W at B2
    var pos2: X.Pos = [_]i8{0} ** 16;
    pos2[1] = -1; // White at cell 1
    const idx2 = X.colex_from_pos(&pos2);
    std.debug.print("W at B2 (cell 1) colex = {d}\n", .{idx2});
    // Empty
    var pos0: X.Pos = [_]i8{0} ** 16;
    const idx0 = X.colex_from_pos(&pos0);
    std.debug.print("Empty colex = {d}\n", .{idx0});
    // Print values directly from artifact
    const io = init.io;
    var f = try std.Io.Dir.cwd().openFile(io, "data/oracle-4x4.checkpoint.wzo", .{});
    defer f.close(io);
    const N: u64 = 3 * 3 * 3 * 3 * 3 * 3 * 3 * 3 * 3 * 3 * 3 * 3 * 3 * 3 * 3 * 3;
    // 32-byte header, then vb (3^16 bytes), vw (3^16 bytes), fb, fw, db, dw
    var buf: [16]u8 = undefined;
    {
        try f.seekTo(io, 32 + idx0);
        _ = try f.read(io, &buf);
        std.debug.print("Empty vb[0] = {d}\n", .{@as(i8, buf[0])});
    }
    {
        try f.seekTo(io, 32 + N + idx0);
        _ = try f.read(io, &buf);
        std.debug.print("Empty vw[0] = {d}\n", .{@as(i8, buf[0])});
    }
    {
        try f.seekTo(io, 32 + idx1);
        _ = try f.read(io, &buf);
        std.debug.print("B@B2 vb[{d}] = {d}\n", .{ idx1, @as(i8, buf[0]) });
    }
    {
        try f.seekTo(io, 32 + N + idx1);
        _ = try f.read(io, &buf);
        std.debug.print("B@B2 vw[{d}] = {d}\n", .{ idx1, @as(i8, buf[0]) });
    }
    {
        try f.seekTo(io, 32 + idx2);
        _ = try f.read(io, &buf);
        std.debug.print("W@B2 vb[{d}] = {d}\n", .{ idx2, @as(i8, buf[0]) });
    }
    {
        try f.seekTo(io, 32 + N + idx2);
        _ = try f.read(io, &buf);
        std.debug.print("W@B2 vw[{d}] = {d}\n", .{ idx2, @as(i8, buf[0]) });
    }
}
