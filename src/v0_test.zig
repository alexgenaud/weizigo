const std = @import("std");
const rules = @import("rules.zig");
const colexmod = @import("colex.zig");
const artifact = @import("artifact.zig");

pub fn main(init: std.process.Init) !void { _ = init;
    var threaded = std.Io.Threaded.init(std.heap.page_allocator, .{});
    const io = threaded.io();
    var dec = try artifact.load(io, std.Io.Dir.cwd(), "data/oracle-4x4.checkpoint.wzo", std.heap.page_allocator);
    defer dec.deinit();
    const R = rules.Rules(4, 4);
    const X = colexmod.Indexer(4, 4);
    // B at cell 1 (B2)
    var posB: R.Pos = [_]i8{0} ** 16;
    posB[1] = 1;
    const idxB = X.colex_from_pos(&posB);
    std.debug.print("B@B2 colex = {d}\n", .{idxB});
    std.debug.print("  d.vb[{d}] = {d}\n", .{ idxB, dec.vb[idxB] });
    std.debug.print("  d.vw[{d}] = {d}\n", .{ idxB, dec.vw[idxB] });
    // W@B2
    var posW: R.Pos = [_]i8{0} ** 16;
    posW[1] = -1;
    const idxW = X.colex_from_pos(&posW);
    std.debug.print("W@B2 colex = {d}\n", .{idxW});
    std.debug.print("  d.vb[{d}] = {d}\n", .{ idxW, dec.vb[idxW] });
    std.debug.print("  d.vw[{d}] = {d}\n", .{ idxW, dec.vw[idxW] });
    // Empty
    var pos0: R.Pos = [_]i8{0} ** 16;
    const idx0 = X.colex_from_pos(&pos0);
    std.debug.print("Empty colex = {d}\n", .{idx0});
    std.debug.print("  d.vb[{d}] = {d}\n", .{ idx0, dec.vb[idx0] });
    std.debug.print("  d.vw[{d}] = {d}\n", .{ idx0, dec.vw[idx0] });
}
