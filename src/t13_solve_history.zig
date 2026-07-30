const std = @import("std");
const retro = @import("retro.zig");
const colex = @import("colex.zig");

// Exact PSK solver for a single 3x2 history.
// Command-line arguments:
//   side passes idx0 idx1 idx2 ... idxN
// side: 1 = Black to move at the final position, -1 = White.
// passes: consecutive passes already made (0 for a fresh move arrival).
// The final goban index is the LAST index in the list.
// Output (stdout): value (Black-positive), followed by a newline.

pub fn main(init: std.process.Init) !void {
    const gpa = std.heap.page_allocator;
    const X = colex.Indexer(3, 2);
    const E = retro.Exact(3, 2);

    var ctx = E.Ctx{ .map = E.Map.init(gpa), .entry_cap = 0, .budget = 0 };
    defer ctx.map.deinit();

    var args = std.process.Args.Iterator.init(init.minimal.args);
    defer args.deinit();
    _ = args.next(); // skip program name

    const side_str = args.next() orelse return;
    const passes_str = args.next() orelse return;
    const side = try std.fmt.parseInt(i8, side_str, 10);
    const passes = try std.fmt.parseInt(u8, passes_str, 10);

    var bans = E.Bans.initEmpty();
    var last_idx: u32 = 0;
    while (args.next()) |tok| {
        const idx = try std.fmt.parseInt(u32, tok, 10);
        bans.set(idx);
        last_idx = idx;
    }

    const pos = X.pos_from_colex(last_idx);
    ctx.nodes = 0;
    const win = E.win_empty;
    const v = try E.solve(&ctx, &pos, side, passes, win, bans);
    std.debug.print("{d}\n", .{v});
}
