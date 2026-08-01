// differential.zig — oracle harness: compare N implementations of one operation
//
// Task: T226 · Phase: P1 (A1+A2 remediated) · Date: 2026-08-01
//
// Each operation has multiple independent implementations across the codebase.
// This harness compares them at every enumerable goban size and reports:
//   - agreements: boards where ALL implementations return the same value
//   - disagreements: boards where implementations differ, with witness boards
//     and each implementation's value
//
// Controls (A2):
//   - Null control: same implementation registered twice → perfect agreement
//   - Seeded-defect control: a deliberately mutated copy → caught, witnesses named
//   - Known-bad fixture: synthetic disagreement detected (must fail before pass)
//
// Design: adding an implementation is a one-line registration.

const std = @import("std");
const testing = std.testing;

// ── common board type ───────────────────────────────────────────────────────

fn Board(comptime n_cells: usize) type {
    return [n_cells]i8; // -1=white, 0=empty, 1=black
}

// ── operation descriptor ────────────────────────────────────────────────────

fn Impl(comptime n_cells: usize, comptime T: type) type {
    return struct {
        name: []const u8,
        file: []const u8,
        func: *const fn (board: Board(n_cells)) T,
    };
}

fn Disagreement(comptime n_cells: usize, comptime T: type) type {
    return struct {
        board: Board(n_cells),
        values: []T, // one per implementation
    };
}

fn Comparison(comptime n_cells: usize, comptime T: type) type {
    return struct {
        operation: []const u8,
        size_label: []const u8,
        impls: []const Impl(n_cells, T),
        total_boards: usize,
        agreements: usize,
        disagreements: []Disagreement(n_cells, T),

        pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
            for (self.disagreements) |*d| {
                alloc.free(d.values);
            }
            alloc.free(self.disagreements);
        }
    };
}

// ── core comparison: per-board, per-implementation evaluation ───────────────

/// Compare N implementations on every board.  A board *agrees* when all
/// implementations return the same value.  A board *disagrees* when any two
/// differ.  Disagreement witnesses carry each implementation's value.
pub fn compare(
    comptime n_cells: usize,
    comptime T: type,
    alloc: std.mem.Allocator,
    operation: []const u8,
    size_label: []const u8,
    impls: []const Impl(n_cells, T),
    boards: []const Board(n_cells),
) !Comparison(n_cells, T) {
    if (impls.len == 0) {
        return .{
            .operation = operation,
            .size_label = size_label,
            .impls = impls,
            .total_boards = boards.len,
            .agreements = boards.len, // vacuously true
            .disagreements = &.{},
        };
    }

    var disagreement_list: std.ArrayList(Disagreement(n_cells, T)) = .empty;
    var agreement_count: usize = 0;

    for (boards) |board| {
        // Evaluate every implementation on this board
        var values = try alloc.alloc(T, impls.len);
        for (impls, 0..) |_, i| {
            values[i] = impls[i].func(board);
        }

        // Check if all values are equal
        const all_equal = blk: {
            const first = values[0];
            for (values[1..]) |v| {
                if (!std.meta.eql(v, first)) break :blk false;
            }
            break :blk true;
        };

        if (all_equal) {
            agreement_count += 1;
            alloc.free(values);
        } else {
            try disagreement_list.append(alloc, .{ .board = board, .values = values });
        }
    }

    return .{
        .operation = operation,
        .size_label = size_label,
        .impls = impls,
        .total_boards = boards.len,
        .agreements = agreement_count,
        .disagreements = try disagreement_list.toOwnedSlice(alloc),
    };
}

// ── board enumeration ──────────────────────────────────────────────────────

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
            const rem = @as(i8, @intCast(v % 3)) - 1;
            b[j] = rem;
            v /= 3;
        }
        boards[i] = b;
    }
    return boards;
}

// ── tests ───────────────────────────────────────────────────────────────────

fn alwaysZero(_: Board(4)) i8 { return 0; }
fn alwaysOne(_: Board(4)) i8 { return 1; }
fn alwaysZeroCopy(_: Board(4)) i8 { return 0; }
fn plusOne(board: Board(4)) i8 { return board[0] + board[1] + board[2] + board[3] + 1; }

test "null control: same impl twice → perfect agreement" {
    const alloc = std.testing.allocator;
    const impls = [_]Impl(4, i8){
        .{ .name = "zero", .file = "test", .func = alwaysZero },
        .{ .name = "zero_copy", .file = "test", .func = alwaysZero },
    };
    const boards = [_]Board(4){
        .{ 0, 0, 0, 0 },
        .{ 1, -1, 0, 1 },
        .{ -1, -1, 1, 1 },
    };

    var result = try compare(4, i8, alloc, "null_control", "2x2", &impls, &boards);
    defer result.deinit(alloc);

    try testing.expectEqual(3, result.total_boards);
    try testing.expectEqual(3, result.agreements);
    try testing.expectEqual(0, result.disagreements.len);
}

test "seeded-defect control: mutant caught with witnesses" {
    const alloc = std.testing.allocator;
    // alwaysZero and alwaysOne are a one-character mutation apart
    const impls = [_]Impl(4, i8){
        .{ .name = "zero", .file = "test", .func = alwaysZero },
        .{ .name = "one", .file = "test", .func = alwaysOne }, // mutant: returns 1 instead of 0
    };
    const boards = [_]Board(4){
        .{ 0, 0, 0, 0 },
    };

    var result = try compare(4, i8, alloc, "mutant", "2x2", &impls, &boards);
    defer result.deinit(alloc);

    try testing.expectEqual(1, result.total_boards);
    try testing.expectEqual(0, result.agreements);
    try testing.expectEqual(1, result.disagreements.len);
    // Witness must name the differing values
    try testing.expectEqual(@as(i8, 0), result.disagreements[0].values[0]);
    try testing.expectEqual(@as(i8, 1), result.disagreements[0].values[1]);
}

test "known-bad fixture: three impls, one disagrees, witnesses correct" {
    const alloc = std.testing.allocator;
    const impls = [_]Impl(4, i8){
        .{ .name = "zero", .file = "test", .func = alwaysZero },
        .{ .name = "mutant_one", .file = "test", .func = alwaysOne },
        .{ .name = "zero_copy", .file = "test", .func = alwaysZeroCopy },
    };
    const boards = [_]Board(4){
        .{ 0, 0, 0, 0 }, // zero=0, mutant=1, copy=0 → disagreement
        .{ -1, 0, 1, 0 }, // zero=0, mutant=1, copy=0 → disagreement
    };

    var result = try compare(4, i8, alloc, "known_bad", "2x2", &impls, &boards);
    defer result.deinit(alloc);

    try testing.expectEqual(2, result.total_boards);
    try testing.expectEqual(0, result.agreements);
    try testing.expectEqual(2, result.disagreements.len);
    // Each disagreement must show values[0]=0, values[1]=1, values[2]=0
    for (result.disagreements) |d| {
        try testing.expectEqual(@as(i8, 0), d.values[0]);
        try testing.expectEqual(@as(i8, 1), d.values[1]);
        try testing.expectEqual(@as(i8, 0), d.values[2]);
    }
}

// ── main: run area score comparison using real implementations ──────────────

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

    // 2×2: compare exp6 vs Rules — expected identical (they're clones)
    {
        const impls = [_]Impl(4, i8){
            .{ .name = "exp6.genericAreaScore", .file = "src/exp6_solve.zig", .func = areaScoreExp6_2x2 },
            .{ .name = "rules.Rules(2,2).area_score", .file = "src/rules.zig", .func = areaScoreRules_2x2 },
        };
        const boards = try enumerateBoards(4, alloc);
        defer alloc.free(boards);

        var result = try compare(4, i8, alloc, "area_score", "2x2", &impls, boards);
        defer result.deinit(alloc);

        std.debug.print("area_score @ 2x2: {d}/{d} agree", .{ result.agreements, result.total_boards });
        if (result.disagreements.len == 0) {
            std.debug.print(" — ALL AGREE\n", .{});
        } else {
            std.debug.print(" — {d} DISAGREEMENTS\n", .{result.disagreements.len});
            for (result.disagreements[0..@min(result.disagreements.len, 3)]) |d| {
                std.debug.print("  board=[", .{});
                for (d.board, 0..) |c, ci| {
                    if (ci > 0) std.debug.print(",", .{});
                    std.debug.print("{d}", .{c});
                }
                std.debug.print("] values=[", .{});
                for (d.values, 0..) |v, vi| {
                    if (vi > 0) std.debug.print(",", .{});
                    std.debug.print("{d}", .{v});
                }
                std.debug.print("]\n", .{});
            }
        }
    }

    // 3×2: same comparison
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

        std.debug.print("area_score @ 3x2: {d}/{d} agree", .{ result.agreements, result.total_boards });
        if (result.disagreements.len == 0) {
            std.debug.print(" — ALL AGREE\n", .{});
        } else {
            std.debug.print(" — {d} DISAGREEMENTS\n", .{result.disagreements.len});
            for (result.disagreements[0..@min(result.disagreements.len, 3)]) |d| {
                std.debug.print("  board=[", .{});
                for (d.board, 0..) |c, ci| {
                    if (ci > 0) std.debug.print(",", .{});
                    std.debug.print("{d}", .{c});
                }
                std.debug.print("] values=[", .{});
                for (d.values, 0..) |v, vi| {
                    if (vi > 0) std.debug.print(",", .{});
                    std.debug.print("{d}", .{v});
                }
                std.debug.print("]\n", .{});
            }
        }
    }
}
