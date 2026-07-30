// T110 (2026-07-30): dump the 3x2 L/H retrograde tables so the Python re-implementation
// of T13 can be diffed against the committed Zig, slot by slot.
const std = @import("std");
const retro = @import("retro");

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    const RT = retro.Retro(3, 2);
    var t = try RT.Tables.init(gpa);
    defer t.deinit();
    RT.seed(&t);
    RT.converge(&t);
    RT.finalize(&t);
    const p = struct {
        fn print(comptime fmt: []const u8, args: anytype) !void {
            std.debug.print(fmt, args);
        }
    };
    try p.print("# legal={d} settled={d} kob={d} kow={d} sweeps={d}\n", .{
        t.legal_count, t.settled_count, t.ko_sensitive_b, t.ko_sensitive_w, t.sweeps,
    });
    for (0..RT.total) |i| {
        if (!t.legal[i]) continue;
        try p.print("{d} {d} {d} {d} {d} {d} {d} {d} {d} {d} {d} {d}\n", .{
            i,
            @intFromBool(t.settled[i]),
            t.score[i],
            t.lo.b0[i], t.hi.b0[i], t.lo.w0[i], t.hi.w0[i],
            t.lo.b1[i], t.hi.b1[i], t.lo.w1[i], t.hi.w1[i],
            @as(i16, t.vb[i]),
        });
    }
}
