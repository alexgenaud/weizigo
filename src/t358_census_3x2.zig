// T358 — 3×2 reachability census wrapper (glm-5.2/T358, 2026-08-20).
// Reuses exp6_solve.run_census_3x2 (the same instrument the 4×4 build uses)
// but runs ONLY the 3×2 census — not the full 4×4 fixpoint + WZO2 serialize.
// Prints total reachable (all passes), non-terminal (passes∈{0,1}, the
// WZO2-stored slice), terminal (passes==2), legal boards, by side, sweeps.
//
// Build: tools/runner -- zig run -O ReleaseFast src/t358_census_3x2.zig

const std = @import("std");
const util = @import("util.zig");
const E = @import("exp6_solve.zig");

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    const reach = try gpa.alloc(u64, E.ReachWords32);
    defer gpa.free(reach);
    const r = try E.run_census_3x2(gpa, reach);
    const non_terminal = r.total_marked - r.terminal_marked;
    util.out("# t358 3x2 reachability census (roots: empty B/W, ko=none, passes in 0,1); state space TOTAL32 = {d} (3^6 * 2 * 7 * 3)\n", .{E.TOTAL32});
    util.out("# total reachable (all passes) = {d}\n", .{r.total_marked});
    util.out("#   passes in {{0,1}} (WZO2-stored) = {d}\n", .{non_terminal});
    util.out("#   passes == 2 (terminal)        = {d}\n", .{r.terminal_marked});
    util.out("# legal boards reachable = {d}\n", .{r.legal_boards});
    util.out("# by side: B={d} W={d}\n", .{ r.side_marked[0], r.side_marked[1] });
    util.out("# sweeps to converge = {d}\n", .{r.sweeps});
}