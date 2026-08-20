// T358 — 3×3 reachability census wrapper (glm-5.2/T358, 2026-08-20).
// Reuses exp6_solve.run_census_3x3 (the same instrument the 4×4 build uses)
// but runs ONLY the 3×3 census. Cross-checks the WZO2 n_entries for 3×3
// (data/oracle-3x3-v2.wzo2 header: n_entries = 49,428) against an
// independent BFS reachability count.
//
// Build: tools/runner -- zig run -O ReleaseFast src/t358_census_3x3.zig

const std = @import("std");
const util = @import("util.zig");
const E = @import("exp6_solve.zig");

pub fn main() !void {
    const gpa = std.heap.page_allocator;
    const reach = try gpa.alloc(u64, E.ReachWords);
    defer gpa.free(reach);
    const r = try E.run_census_3x3(gpa, reach);
    const non_terminal = r.total_marked - r.terminal_marked;
    util.out("# t358 3x3 reachability census; state space TOTAL = {d} (3^9 * 2 * 10 * 3)\n", .{E.TOTAL});
    util.out("# total reachable (all passes) = {d}\n", .{r.total_marked});
    util.out("#   passes in {{0,1}} (WZO2-stored) = {d}\n", .{non_terminal});
    util.out("#   passes == 2 (terminal)        = {d}\n", .{r.terminal_marked});
    util.out("# legal boards reachable = {d}\n", .{r.legal_boards});
    util.out("# by side: B={d} W={d}\n", .{ r.side_marked[0], r.side_marked[1] });
    util.out("# sweeps to converge = {d}\n", .{r.sweeps});
}