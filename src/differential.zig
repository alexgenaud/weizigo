// differential.zig — oracle harness: compare N implementations of one operation
//
// Task: T252 · Phase: P1 of engine-unification sprint · Date: 2026-08-01
//
// Each operation (area score, legality, capture, pass) has multiple independent
// implementations across the codebase. This harness compares them at every
// enumerable goban size and reports agreement. Disagreements are reported with
// witness inputs, not fixed.
//
// Design: adding an implementation is a one-line registration. The harness
// is only useful if it stays used.

const std = @import("std");
const testing = std.testing;

// ── common board type ───────────────────────────────────────────────────────

fn Board(comptime n_cells: usize) type {
    return [n_cells]i8; // -1=white, 0=empty, 1=black
}

// ── operation descriptor ────────────────────────────────────────────────────

/// An implementation of an operation at a specific goban size.
/// T is the result type (e.g. i8 for area score, bool for legality).
fn Impl(comptime n_cells: usize, comptime T: type) type {
    return struct {
        name: []const u8, // human-readable, e.g. "exp4.area_score3"
        file: []const u8, // source file, e.g. "src/exp4_solve.zig"
        func: *const fn (board: Board(n_cells)) T,
    };
}

/// A set of implementations for one operation at one size.
fn Comparison(comptime n_cells: usize, comptime T: type) type {
    return struct {
        operation: []const u8,
        size_label: []const u8, // e.g. "2x2"
        impls: []const Impl(n_cells, T),
        total_states: usize,
        agreements: usize,
        disagreements: []Disagreement(n_cells, T),

        pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
            for (self.disagreements) |*d| {
                alloc.free(d.witnesses);
                alloc.free(d.impls_with);
            }
            alloc.free(self.disagreements);
        }
    };
}

fn Disagreement(comptime n_cells: usize, comptime T: type) type {
    return struct {
        result: T,
        count: usize,
        witnesses: []Board(n_cells), // first few witness boards
        impls_with: []u8, // bitmap: which impls return this result
    };
}

// ── result grouping ─────────────────────────────────────────────────────────

/// Group boards by the result vector (which impl returned what).
/// Returns a map from result-key to list of boards.
fn groupByResult(
    comptime n_cells: usize,
    comptime T: type,
    alloc: std.mem.Allocator,
    impls: []const Impl(n_cells, T),
    boards: []const Board(n_cells),
) !std.AutoHashMap(u64, std.ArrayList(Board(n_cells))) {
    var map = std.AutoHashMap(u64, std.ArrayList(Board(n_cells))).init(alloc);
    for (boards) |board| {
        var key: u64 = 0;
        for (impls, 0..) |_, i| {
            const result = impls[i].func(board);
            const r: u64 = @bitCast(@as(i64, result));
            key ^= r << @intCast((i * 8) % 64);
        }
        const entry = try map.getOrPut(key);
        if (!entry.found_existing) {
            entry.value_ptr.* = .empty;
        }
        try entry.value_ptr.*.append(alloc, board);
    }
    return map;
}

// ── comparison runner ───────────────────────────────────────────────────────

/// Run all comparisons for a given operation across multiple goban sizes.
/// Returns a list of Comparison results, one per size.
pub fn compare(
    comptime n_cells: usize,
    comptime T: type,
    alloc: std.mem.Allocator,
    operation: []const u8,
    size_label: []const u8,
    impls: []const Impl(n_cells, T),
    boards: []const Board(n_cells),
) !Comparison(n_cells, T) {
    var groups = try groupByResult(n_cells, T, alloc, impls, boards);
    defer {
        var it = groups.valueIterator();
        while (it.next()) |list| list.deinit(alloc);
        groups.deinit();
    }

    const total = boards.len;

    // Find the majority result key (the one with the most boards)
    var majority_key: u64 = 0;
    var majority_count: usize = 0;
    var it = groups.iterator();
    while (it.next()) |entry| {
        if (entry.value_ptr.*.items.len > majority_count) {
            majority_count = entry.value_ptr.*.items.len;
            majority_key = entry.key_ptr.*;
        }
    }

    // Collect disagreements: groups that are not the majority
    var disagreements: std.ArrayList(Disagreement(n_cells, T)) = .empty;
    it = groups.iterator();
    while (it.next()) |entry| {
        if (entry.key_ptr.* == majority_key) continue;
        const boards_list = entry.value_ptr.*;
        const witness_count = @min(boards_list.items.len, 5);
        const witnesses = try alloc.alloc(Board(n_cells), witness_count);
        @memcpy(witnesses, boards_list.items[0..witness_count]);

        // Build bitmap: which impls produced this result
        var impls_with = try alloc.alloc(u8, (impls.len + 7) / 8);
        @memset(impls_with, 0);
        // For each impl, check if it returns the same value as the first witness
        const first_board = witnesses[0];
        for (impls, 0..) |_, i| {
            // Compare this impl's result on the first witness to the result stored
            const this_result = impls[i].func(first_board);
            // The result stored for this group is from a board where all impls returned
            // values matching the key. We just check if impl i returns the same as impl 0.
            if (this_result == impls[0].func(first_board)) {
                impls_with[i / 8] |= @as(u8, 1) << @intCast(i % 8);
            }
        }

        try disagreements.append(alloc, .{
            .result = impls[0].func(witnesses[0]),
            .count = boards_list.items.len,
            .witnesses = witnesses,
            .impls_with = impls_with,
        });
    }

    return .{
        .operation = operation,
        .size_label = size_label,
        .impls = impls,
        .total_states = total,
        .agreements = majority_count,
        .disagreements = try disagreements.toOwnedSlice(alloc),
    };
}

// ── reporting ───────────────────────────────────────────────────────────────

pub fn report(
    comptime n_cells: usize,
    comptime T: type,
    writer: anytype,
    result: Comparison(n_cells, T),
) !void {
    try writer.print("=== {s} @ {s} ===\n", .{ result.operation, result.size_label });
    try writer.print("  implementations: {d}\n", .{result.impls.len});
    for (result.impls, 0..) |impl, i| {
        try writer.print("    [{d}] {s} ({s})\n", .{ i, impl.name, impl.file });
    }
    try writer.print("  total states: {d}\n", .{result.total_states});
    try writer.print("  agreements: {d}/{d} ({d:.1}%)\n", .{ result.agreements, result.total_states, 100.0 * @as(f64, @floatFromInt(result.agreements)) / @as(f64, @floatFromInt(result.total_states)) });

    if (result.disagreements.len == 0) {
        try writer.print("  ALL AGREE\n", .{});
    } else {
        try writer.print("  DISAGREEMENTS: {d} groups\n", .{result.disagreements.len});
        for (result.disagreements, 0..) |d, di| {
            try writer.print("    group {d}: count={d}\n", .{ di, d.count });
            try writer.print("      witness[0]: [", .{});
            for (d.witnesses[0], 0..) |cell, ci| {
                if (ci > 0) try writer.print(",", .{});
                try writer.print("{d}", .{cell});
            }
            try writer.print("]\n", .{});
        }
    }
    try writer.print("\n", .{});
}

// ── tests ───────────────────────────────────────────────────────────────────

fn alwaysZero(_: Board(4)) i8 { return 0; }
fn alwaysOne(_: Board(4)) i8 { return 1; }
fn alwaysZeroB(_: Board(4)) i8 { return 0; }
fn boardSum(board: Board(4)) i8 {
    return board[0] + board[1] + board[2] + board[3];
}

test "known-bad fixture: disagreement detected" {
    const alloc = std.testing.allocator;
    // alwaysZero and alwaysZeroB always agree.
    // boardSum sometimes agrees with them (when sum=0), sometimes doesn't.
    const impls = [_]Impl(4, i8){
        .{ .name = "zero_a", .file = "test", .func = alwaysZero },
        .{ .name = "sum", .file = "test", .func = boardSum },
        .{ .name = "zero_b", .file = "test", .func = alwaysZeroB },
    };
    const boards = [_]Board(4){
        .{ 0, 0, 0, 0 },  // sum=0, all agree
        .{ 1, -1, 0, 1 }, // sum=1, sum disagrees with zeros
        .{ 2, -2, 0, 0 }, // sum=0, all agree
    };

    var result = try compare(4, i8, alloc, "test_op", "2x2", &impls, &boards);
    defer result.deinit(alloc);

    try testing.expect(result.total_states == 3);
    // Two boards have sum=0 (3-way agreement). One board has sum=1 (disagreement).
    try testing.expect(result.agreements == 2);
    try testing.expect(result.disagreements.len == 1);
    try testing.expect(result.disagreements[0].count == 1);
}

test "all agree: no disagreements" {
    const alloc = std.testing.allocator;
    const impls = [_]Impl(4, i8){
        .{ .name = "zero_a", .file = "test", .func = alwaysZero },
        .{ .name = "zero_b", .file = "test", .func = alwaysZeroB },
    };
    const boards = [_]Board(4){
        .{ 0, 0, 0, 0 },
        .{ 1, -1, 0, 1 },
    };

    var result = try compare(4, i8, alloc, "all_zero", "2x2", &impls, &boards);
    defer result.deinit(alloc);

    try testing.expect(result.total_states == 2);
    try testing.expect(result.agreements == 2);
    try testing.expect(result.disagreements.len == 0);
}

// ── board enumeration ──────────────────────────────────────────────────────

/// Enumerate all boards of a given size (3^N states).
pub fn enumerateBoards(comptime n_cells: usize, alloc: std.mem.Allocator) ![]Board(n_cells) {
    const pow3 = comptime blk: {
        var p: usize = 1;
        var i: usize = 0;
        while (i < n_cells) : (i += 1) { p *= 3; }
        break :blk p;
    };
    var boards = try alloc.alloc(Board(n_cells), pow3);
    var i: usize = 0;
    while (i < pow3) : (i += 1) {
        var b: Board(n_cells) = undefined;
        var v = i;
        var j: usize = 0;
        while (j < n_cells) : (j += 1) {
            const rem = @as(i8, @intCast(v % 3)) - 1; // -1, 0, 1
            b[j] = rem;
            v /= 3;
        }
        boards[i] = b;
    }
    return boards;
}

// ── main: run area score comparison at 2×2 ──────────────────────────────────

const exp6 = @import("exp6_solve.zig");
const rules_mod = @import("rules.zig");

fn areaScoreExp6_2x2(board: Board(4)) i8 {
    return exp6.genericAreaScore(4, &board, 2, 2);
}

fn areaScoreRules_2x2(board: Board(4)) i8 {
    const R = rules_mod.Rules(2, 2);
    return R.area_score(&board);
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    // Area score at 2×2
    {
        const impls = [_]Impl(4, i8){
            .{ .name = "exp6.genericAreaScore", .file = "src/exp6_solve.zig", .func = areaScoreExp6_2x2 },
            .{ .name = "rules.Rules(2,2).area_score", .file = "src/rules.zig", .func = areaScoreRules_2x2 },
        };
        const boards = try enumerateBoards(4, alloc);
        defer alloc.free(boards);

        var result = try compare(4, i8, alloc, "area_score", "2x2", &impls, boards);
        defer result.deinit(alloc);

        std.debug.print("=== {s} @ {s} ===\n", .{ result.operation, result.size_label });
        std.debug.print("  implementations: {d}\n", .{result.impls.len});
        std.debug.print("  total states: {d}\n", .{result.total_states});
        std.debug.print("  agreements: {d}/{d}\n", .{ result.agreements, result.total_states });
        if (result.disagreements.len == 0) {
            std.debug.print("  ALL AGREE\n\n", .{});
        } else {
            std.debug.print("  DISAGREEMENTS: {d}\n\n", .{result.disagreements.len});
        }
    }

    // Area score at 3×2 (6 cells, 3^6 = 729 states)
    {
        const impls = [_]Impl(6, i8){
            .{ .name = "exp6.genericAreaScore", .file = "src/exp6_solve.zig", .func = struct {
                fn f(board: Board(6)) i8 { return exp6.genericAreaScore(6, &board, 3, 2); }
            }.f },
            .{ .name = "rules.Rules(3,2).area_score", .file = "src/rules.zig", .func = struct {
                fn f(board: Board(6)) i8 {
                    const R = rules_mod.Rules(3, 2);
                    return R.area_score(&board);
                }
            }.f },
        };
        const boards = try enumerateBoards(6, alloc);
        defer alloc.free(boards);

        var result = try compare(6, i8, alloc, "area_score", "3x2", &impls, boards);
        defer result.deinit(alloc);

        std.debug.print("=== {s} @ {s} ===\n", .{ result.operation, result.size_label });
        std.debug.print("  implementations: {d}\n", .{result.impls.len});
        std.debug.print("  total states: {d}\n", .{result.total_states});
        std.debug.print("  agreements: {d}/{d}\n", .{ result.agreements, result.total_states });
        if (result.disagreements.len == 0) {
            std.debug.print("  ALL AGREE\n\n", .{});
        } else {
            std.debug.print("  DISAGREEMENTS: {d}\n\n", .{result.disagreements.len});
        }
    }
}
