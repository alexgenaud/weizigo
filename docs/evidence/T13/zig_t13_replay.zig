// T110: re-execute the 12 recorded T13 contradiction lines through the
// COMMITTED Zig retro.ab_solve (memo=false, brackets=false, window
// [-127,127]) so the Python re-implementation's solver can be diffed
// against it, not only its tables.
const std = @import("std");
const retro = @import("retro");

const RT = retro.Retro(3, 2);

const Line = struct { idx: usize, side: i8, hist: []const u16 };

const LINES = [_]Line{
    .{ .idx = 314, .side = 1, .hist = &.{ 0, 2, 26, 40, 110, 278, 57, 154, 314 } },
    .{ .idx = 413, .side = 1, .hist = &.{ 0, 2, 26, 40, 110, 278, 57, 211, 413 } },
    .{ .idx = 410, .side = 1, .hist = &.{ 0, 4, 15, 32, 102, 244, 45, 122, 410 } },
    .{ .idx = 459, .side = 1, .hist = &.{ 0, 4, 15, 32, 102, 244, 45, 147, 459 } },
    .{ .idx = 267, .side = 1, .hist = &.{ 0, 4, 22, 60, 159, 327, 37, 107, 267 } },
    .{ .idx = 433, .side = 1, .hist = &.{ 0, 4, 22, 60, 159, 327, 37, 205, 433 } },
    .{ .idx = 237, .side = 1, .hist = &.{ 0, 6, 62, 48, 127, 423, 29, 99, 237 } },
    .{ .idx = 273, .side = 1, .hist = &.{ 0, 6, 62, 48, 127, 423, 29, 141, 273 } },
    .{ .idx = 359, .side = -1, .hist = &.{ 1, 19, 77, 325, 105, 253, 477, 64, 167, 359 } },
    .{ .idx = 346, .side = 1, .hist = &.{ 2, 16, 84, 112, 260, 500, 61, 162, 346 } },
    .{ .idx = 398, .side = -1, .hist = &.{ 2, 16, 84, 112, 260, 500, 61, 162, 346, 398 } },
    .{ .idx = 347, .side = 1, .hist = &.{ 4, 24, 172, 128, 263, 567, 25, 91, 347 } },
};

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    const p = std.debug.print;
    var t = try RT.Tables.init(gpa);
    defer t.deinit();
    RT.seed(&t);
    RT.converge(&t);
    RT.finalize(&t);

    var ctx = RT.O.Ctx{
        .vb = try gpa.alloc(i8, RT.total),
        .vw = try gpa.alloc(i8, RT.total),
        .cb = try gpa.alloc(bool, RT.total),
        .cw = try gpa.alloc(bool, RT.total),
        .memo = false, // T13 step 4: no memo reads/writes -> no GHI risk
        .memo_writes = false,
        .brackets = false, // T13 step 4: no history-free L/H cuts
        .deps = false,
        .budget = 2_000_000_000,
    };
    @memset(ctx.cb, false);
    @memset(ctx.cw, false);

    const hist = try gpa.create(RT.O.History);
    defer gpa.destroy(hist);
    hist.* = .{};

    p("# idx side stored history_value fresh_value\n", .{});
    for (LINES) |L| {
        const pos = RT.X.pos_from_colex(L.idx);
        const stored = if (L.side > 0) t.vb[L.idx] else t.vw[L.idx];

        hist.reset();
        for (L.hist) |ix| {
            const b = RT.X.pos_from_colex(ix);
            hist.push(&b);
        }
        const hv = try RT.ab_solve(&t, &ctx, &pos, L.side, 0, -127, 127, hist, RT.O.fp_zero);

        hist.reset();
        hist.push(&pos);
        const fv = try RT.ab_solve(&t, &ctx, &pos, L.side, 0, -127, 127, hist, RT.O.fp_zero);

        p("{d} {d} {d} {d} {d}\n", .{ L.idx, L.side, stored, hv.value, fv.value });
    }
}
