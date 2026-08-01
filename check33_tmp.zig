const std = @import("std");
const exp6 = @import("src/exp6_solve.zig");
const artifact2 = @import("src/artifact2.zig");

const gpa = std.heap.page_allocator;

pub fn main() !void {
    const reach = try gpa.alloc(u64, exp6.ReachWords);
    defer gpa.free(reach);
    const L = try gpa.alloc(i8, exp6.TOTAL);
    defer gpa.free(L);
    const H = try gpa.alloc(i8, exp6.TOTAL);
    defer gpa.free(H);
    _ = try exp6.run_census_3x3(gpa, reach);
    const fp = exp6.run_fixpoint_3x3(reach, L, H);
    std.debug.print("fixpoint sweeps={d} converged={}\n", .{ fp.sweeps, fp.converged });

    const state = struct {
        fn s(board: u32, side: u8, ko: u16, passes: u8) exp6.StateIdx {
            return .{ .board = board, .side = side, .ko = ko, .passes = passes };
        }
    }.s;

    // (B@A3, W to move) — engine printed stored-v0=9 => pinned 9
    const bA3_w = state(729, 1, exp6.KO_NONE, 0).linear();
    std.debug.print("(B@A3, W, ko=none, p0): L={d} H={d}\n", .{ L[bA3_w], H[bA3_w] });

    // (B@A3+W@A1, B to move) — engine printed child-value=-4
    const bA3wA1_b = state(731, 0, exp6.KO_NONE, 0).linear();
    std.debug.print("(B@A3+W@A1, B, ko=none, p0): L={d} H={d}\n", .{ L[bA3wA1_b], H[bA3wA1_b] });

    // (B@A3+W@A1, W to move) — engine printed [L=0,H=0]
    const bA3wA1_w = state(731, 1, exp6.KO_NONE, 0).linear();
    std.debug.print("(B@A3+W@A1, W, ko=none, p0): L={d} H={d}\n", .{ L[bA3wA1_w], H[bA3wA1_w] });

    // All White children of (B@A3, W, ko=none, p0)
    const st = state(729, 1, exp6.KO_NONE, 0);
    var boards: [exp6.N + 1]exp6.Pos3 = undefined;
    var succs: [exp6.N + 1]exp6.StateIdx = undefined;
    const m = exp6.moves(st, &boards, &succs);
    std.debug.print("children of (B@A3, W, p0): {d}\n", .{m});
    for (0..m) |k| {
        const c = succs[k];
        const cl = c.linear();
        std.debug.print("  child board={d} side={d} ko={d} passes={d} lin={d} L={d} H={d}\n", .{
            c.board, c.side, c.ko, c.passes, cl, L[cl], H[cl],
        });
    }

    // Now the artifact side: what does the built artifact store for these keys?
    var threaded = std.Io.Threaded.init(gpa, .{});
    defer threaded.deinit();
    const io = threaded.io();
    const dir = std.Io.Dir.cwd();
    var a = try artifact2.load(io, dir, "untracked/oracle-v2/oracle-3x3-v2.wzo2", gpa);
    defer a.deinit();
    const none: u8 = @intCast(exp6.KO_NONE);
    std.debug.print("\n-- artifact lookups --\n", .{});
    if (artifact2.lookup(&a, 729, -1, none, 0)) |r| {
        std.debug.print("art (B@A3, W, ko=none, p0): L={d} H={d}\n", .{ r.L, r.H });
    } else std.debug.print("art (B@A3, W, ko=none, p0): MISSING\n", .{});
    if (artifact2.lookup(&a, 731, 1, none, 0)) |r| {
        std.debug.print("art (B@A3+W@A1, B, ko=none, p0): L={d} H={d}\n", .{ r.L, r.H });
    } else std.debug.print("art (B@A3+W@A1, B, ko=none, p0): MISSING\n", .{});
    if (artifact2.lookup(&a, 731, -1, none, 0)) |r| {
        std.debug.print("art (B@A3+W@A1, W, ko=none, p0): L={d} H={d}\n", .{ r.L, r.H });
    } else std.debug.print("art (B@A3+W@A1, W, ko=none, p0): MISSING\n", .{});
}

// Engine-side keys (combinatorial colex) for the SAME positions:
const colex = @import("src/colex.zig");
pub fn engColex(w: usize, h: usize, pos: []const i8) u64 {
    const X = colex.Indexer(w, h);
    const p: [9]i8 = pos[0..9].*;
    return X.colex_from_pos(&p);
}
