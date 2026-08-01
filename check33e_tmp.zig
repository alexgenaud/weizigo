const std = @import("std");
const rules = @import("src/rules.zig");
const gpa = std.heap.page_allocator;

const R = rules.Rules(3, 3);
const Pos = R.Pos;

pub fn main() !void {
    var pos: Pos = [_]i8{0} ** 9;
    pos[0] = 1; // B@cell0
    std.debug.print("area(B@cell0) = {d}\n", .{R.area_score(&pos)});

    for ([_]usize{ 2, 6, 8, 18 }) |cell| {
        var p2: Pos = [_]i8{0} ** 9;
        p2[cell] = 1;
        std.debug.print("area(B@cell{d}) = {d}\n", .{ cell, R.area_score(&p2) });
    }
}
