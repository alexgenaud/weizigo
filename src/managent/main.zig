////////////////////////////////////////////
//                                        //
//    (c) 2026 Alexander E Genaud         //
//                                        //
//    Permission is granted hereby,       //
//    to copy, share, use, modify,        //
//        for purposes any,               //
//        for free or for money,          //
//    provided these notices multiply.    //
//                                        //
//    This work "as is" I provide,        //
//    no warranty express or implied,     //
//        for, no purpose fit,            //
//        'tis unmerchantable shit.       //
//    Liability for damages denied.       //
//                                        //
////////////////////////////////////////////
//
// managent — agent-manager CLI
//
// A tool for registering, claiming, and tracking subagent tasks.
// Enforces dependencies, parallel-set exclusion, and engine-file locks.
//

const std = @import("std");

const alloc = std.heap.page_allocator;

const TaskStatus = enum {
    blocked,
    dispatchable,
    in_progress,
    done,
    failed,
};

const TaskState = struct {
    status: TaskStatus = .dispatchable,
    agent: ?[]const u8 = null,
    bundle: []const u8 = "",
    set: u8 = 'A', // 'A', 'B', or 'C'
    holds: [][]const u8 = &.{},
    needs: [][]const u8 = &.{},
    needs_context: u64 = 0,
    added: []const u8 = "", // ISO-8601 timestamp
    claimed: ?[]const u8 = null,
    done: ?[]const u8 = null,
};

const StateMap = std.StringHashMapUnmanaged(TaskState);

// ─────────────────────────────────────────────────────────────────── entry

pub fn main(init: std.process.Init.Minimal) !void {
    const args_raw = init.args.vector;
    // Convert [*:0] slices to []const u8 for convenience
    var args_slice = std.ArrayList([]const u8).empty;
    defer args_slice.deinit(alloc);
    for (args_raw) |arg| {
        try args_slice.append(alloc, std.mem.span(arg));
    }
    const args = args_slice.items;

    var threaded = std.Io.Threaded.init(alloc, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const repo_root = try findRepoRoot(io);
    defer alloc.free(repo_root);

    const state_path = try std.fs.path.join(alloc, &.{ repo_root, "untracked", "managent", "tasks.json" });
    defer alloc.free(state_path);

    // Ensure the managent directory exists
    const dir_path = "untracked/managent";
    std.Io.Dir.cwd().createDirPath(io, dir_path) catch {};

    // Determine command
    const cmd: []const u8 = if (args.len >= 2 and !std.mem.startsWith(u8, args[1], "-")) args[1] else "status";

    // Help flags
    if (args.len >= 2) {
        if (std.mem.eql(u8, args[1], "-h") or std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, cmd, "help")) {
            printHelp();
            return;
        }
    }

    if (std.mem.eql(u8, cmd, "add")) {
        try cmdAdd(io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "claim")) {
        try cmdClaim(io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "done")) {
        try cmdDone(io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "status")) {
        try cmdStatus(io, state_path, repo_root);
    } else if (std.mem.eql(u8, cmd, "next")) {
        try cmdNext(io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "show")) {
        try cmdShow(io, state_path, args);
    } else {
        std.debug.print("unknown command: {s}\n", .{cmd});
        std.process.exit(1);
    }
}

// ── repo root ───────────────────────────────────────────────────────────────

fn findRepoRoot(io: std.Io) ![]const u8 {
    // Get the CWD path as a string, then walk up
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const cwd_ptr = std.c.getcwd(&buf, buf.len) orelse {
        std.debug.print("error: cannot get current directory\n", .{});
        std.process.exit(1);
    };
    const cwd = std.mem.sliceTo(cwd_ptr, 0);

    var current: []const u8 = cwd;
    while (true) {
        // Check for .git in current
        var dir = try std.Io.Dir.openDirAbsolute(io, current, .{});
        defer dir.close(io);

        if (dir.access(io, ".git", .{})) |_| {
            return alloc.dupe(u8, current);
        } else |_| {}

        // Go to parent
        const parent = std.fs.path.dirname(current) orelse {
            std.debug.print("error: could not find repo root (no .git found)\n", .{});
            std.process.exit(1);
        };
        if (std.mem.eql(u8, parent, current)) {
            std.debug.print("error: could not find repo root (no .git found)\n", .{});
            std.process.exit(1);
        }
        current = parent;
    }
}

// ── bundle parsing ──────────────────────────────────────────────────────────

const BundleMeta = struct {
    set: u8, // 'A', 'B', or 'C'
    holds: [][]const u8,
    needs: [][]const u8,
    context: u64,
};

fn findBundle(io: std.Io, repo_root: []const u8, id: []const u8) ![]const u8 {
    const untracked_path = try std.fs.path.join(alloc, &.{ repo_root, "untracked" });
    defer alloc.free(untracked_path);

    var dir = std.Io.Dir.cwd().openDir(io, untracked_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            std.debug.print("error: no bundle found for {s} (untracked/ not found)\n", .{id});
            std.process.exit(1);
        }
        return err;
    };
    defer dir.close(io);

    const prefix = try std.fmt.allocPrint(alloc, "{s}-", .{id});
    defer alloc.free(prefix);

    var candidates = std.ArrayList([]const u8).empty;
    defer {
        for (candidates.items) |c| alloc.free(c);
        candidates.deinit(alloc);
    }

    var iter = dir.iterate();
    while (try iter.next(io)) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.startsWith(u8, entry.name, prefix) and std.mem.endsWith(u8, entry.name, ".md")) {
            try candidates.append(alloc, try alloc.dupe(u8, entry.name));
        }
    }

    if (candidates.items.len == 0) {
        std.debug.print("error: no bundle found for {s} (glob: untracked/{s}-*.md)\n", .{ id, id });
        std.process.exit(1);
    }

    std.mem.sort([]const u8, candidates.items, {}, struct {
        fn lt(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lt);

    const result = try std.fs.path.join(alloc, &.{ repo_root, "untracked", candidates.items[0] });
    return result;
}

fn parseBundleMeta(io: std.Io, bundle_path: []const u8, set_override: ?[]const u8, needs_extra: ?[]const u8) !BundleMeta {
    const content = std.Io.Dir.cwd().readFileAlloc(io, bundle_path, alloc, .unlimited) catch |err| {
        std.debug.print("error: cannot read bundle {s}: {}\n", .{ bundle_path, err });
        std.process.exit(1);
    };
    defer alloc.free(content);

    // Look for <!--managent ...--> in the first 50 lines
    var lines = std.mem.splitScalar(u8, content, '\n');
    var line_count: usize = 0;
    const marker = "<!--managent ";
    var meta_line: ?[]const u8 = null;

    while (lines.next()) |line| : (line_count += 1) {
        if (line_count >= 50) break;
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (std.mem.startsWith(u8, trimmed, marker)) {
            meta_line = trimmed;
            break;
        }
    }

    if (meta_line == null) {
        std.debug.print("error: no <!--managent ...--> metadata found in {s}\n", .{bundle_path});
        std.process.exit(1);
    }

    // Parse key=value pairs from the comment
    // Format: <!--managent set=C holds=src/retro.zig needs=B07 context=500k-->
    const inner = meta_line.?[marker.len..];
    var inner_trimmed = inner;
    if (std.mem.endsWith(u8, inner_trimmed, "-->")) {
        inner_trimmed = inner_trimmed[0 .. inner_trimmed.len - 3];
    }
    inner_trimmed = std.mem.trim(u8, inner_trimmed, " \t");

    var result = BundleMeta{
        .set = 'A',
        .holds = &.{},
        .needs = &.{},
        .context = 0,
    };

    var set_found = false;

    // Split by spaces but handle multi-value needs (needs=B07 B10)
    var tokens = std.mem.splitScalar(u8, inner_trimmed, ' ');
    while (tokens.next()) |token| {
        if (token.len == 0) continue;
        var parts = std.mem.splitScalar(u8, token, '=');
        const key = parts.next() orelse continue;
        const value = parts.next() orelse "";

        if (std.mem.eql(u8, key, "set")) {
            if (value.len != 1 or (value[0] != 'A' and value[0] != 'B' and value[0] != 'C')) {
                std.debug.print("error: invalid set '{s}' in metadata (must be A, B, or C)\n", .{value});
                std.process.exit(1);
            }
            result.set = value[0];
            set_found = true;
        } else if (std.mem.eql(u8, key, "holds")) {
            if (value.len > 0) {
                result.holds = try alloc.alloc([]const u8, 1);
                result.holds[0] = try alloc.dupe(u8, value);
            }
        } else if (std.mem.eql(u8, key, "needs")) {
            if (value.len > 0) {
                var needs_list = std.ArrayList([]const u8).empty;
                var needs_split = std.mem.splitScalar(u8, value, ' ');
                while (needs_split.next()) |nid| {
                    if (nid.len > 0) {
                        try needs_list.append(alloc, try alloc.dupe(u8, nid));
                    }
                }
                result.needs = try needs_list.toOwnedSlice(alloc);
            }
        } else if (std.mem.eql(u8, key, "context")) {
            result.context = parseContextValue(value);
        }
    }

    if (!set_found) {
        std.debug.print("error: metadata missing required 'set' key in {s}\n", .{bundle_path});
        std.process.exit(1);
    }

    // Apply overrides
    if (set_override) |s| {
        if (s.len != 1 or (s[0] != 'A' and s[0] != 'B' and s[0] != 'C')) {
            std.debug.print("error: invalid --set '{s}' (must be A, B, or C)\n", .{s});
            std.process.exit(1);
        }
        result.set = s[0];
    }

    if (needs_extra) |n| {
        var needs_list = std.ArrayList([]const u8).empty;
        for (result.needs) |existing| {
            try needs_list.append(alloc, existing);
        }
        try needs_list.append(alloc, try alloc.dupe(u8, n));
        result.needs = try needs_list.toOwnedSlice(alloc);
    }

    return result;
}

fn parseContextValue(s: []const u8) u64 {
    if (s.len == 0) return 0;
    var num_str = s;
    var multiplier: u64 = 1;

    const last = s[s.len - 1];
    if (last == 'k' or last == 'K') {
        num_str = s[0 .. s.len - 1];
        multiplier = 1_000;
    } else if (last == 'M') {
        num_str = s[0 .. s.len - 1];
        multiplier = 1_000_000;
    }

    return (std.fmt.parseUnsigned(u64, num_str, 10) catch 0) * multiplier;
}

// ── state file ──────────────────────────────────────────────────────────────

fn lockStateDir(io: std.Io, state_path: []const u8) !void {
    // Lock directory: mkdir is atomic. Wait with backoff if contention.
    const lock_path = try std.fmt.allocPrint(alloc, "{s}.lock", .{state_path});
    defer alloc.free(lock_path);

    if (std.fs.path.dirname(lock_path)) |dp| {
        std.Io.Dir.cwd().createDirPath(io, dp) catch {};
    }

    var delay: u64 = 1 * std.time.ns_per_ms;
    while (true) {
        std.Io.Dir.cwd().createDir(io, lock_path, .default_dir) catch {
            // Lock held — backoff and retry
            const req: std.c.timespec = .{
                .sec = @intCast(delay / std.time.ns_per_s),
                .nsec = @intCast(delay % std.time.ns_per_s),
            };
            _ = std.c.nanosleep(&req, null);
            delay = @min(delay * 2, 100 * std.time.ns_per_ms);
            continue;
        };
        break;
    }
}

fn unlockStateDir(io: std.Io, state_path: []const u8) void {
    const lock_path = std.fmt.allocPrint(alloc, "{s}.lock", .{state_path}) catch return;
    defer alloc.free(lock_path);
    std.Io.Dir.cwd().deleteDir(io, lock_path) catch {};
}

fn ensureStateDir(io: std.Io, state_path: []const u8) !void {
    if (std.fs.path.dirname(state_path)) |dp| {
        std.Io.Dir.cwd().createDirPath(io, dp) catch {};
    }
}

fn readState(io: std.Io, state_path: []const u8) !StateMap {
    try ensureStateDir(io, state_path);

    const content = std.Io.Dir.cwd().readFileAlloc(io, state_path, alloc, .unlimited) catch |err| {
        if (err == error.FileNotFound) {
            return StateMap{};
        }
        return err;
    };
    defer alloc.free(content);

    return parseStateJson(content);
}

fn writeState(io: std.Io, state_path: []const u8, state: *StateMap) !void {
    try ensureStateDir(io, state_path);
    try lockStateDir(io, state_path);
    defer unlockStateDir(io, state_path);

    // Serialize to temp buffer, then write atomically via rename
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(alloc);
    try serializeState(state, &buf);

    // Write to temp file, then rename atomically
    const dirname = std.fs.path.dirname(state_path) orelse ".";
    const basename = std.fs.path.basename(state_path);

    var tmp_name_buf: [256]u8 = undefined;
    const tmp_name = try std.fmt.bufPrint(&tmp_name_buf, "{s}.tmp.{d}", .{ basename, nowMs() });

    const tmp_path = try std.fs.path.join(alloc, &.{ dirname, tmp_name });
    defer alloc.free(tmp_path);

    {
        const tmp_file = try std.Io.Dir.cwd().createFile(io, tmp_path, .{});
        defer tmp_file.close(io);
        try tmp_file.writeStreamingAll(io, buf.items);
    }

    // Rename atomically
    const state_dir = try std.Io.Dir.cwd().openDir(io, dirname, .{});
    defer state_dir.close(io);
    try state_dir.rename(tmp_name, state_dir, basename, io);
}

fn parseStateJson(content: []const u8) !StateMap {
    const trimmed = std.mem.trim(u8, content, " \t\n\r");
    if (trimmed.len == 0 or std.mem.eql(u8, trimmed, "{}")) {
        return StateMap{};
    }

    var state = StateMap{};

    var parsed = try std.json.parseFromSlice(
        std.json.Value,
        alloc,
        content,
        .{ .allocate = .alloc_always },
    );
    defer parsed.deinit();

    if (parsed.value != .object) return state;

    var it = parsed.value.object.iterator();
    while (it.next()) |entry| {
        const task_id = try alloc.dupe(u8, entry.key_ptr.*);
        const obj = entry.value_ptr.*;

        if (obj != .object) continue;

        var ts = TaskState{};

        if (obj.object.get("status")) |sv| {
            if (sv == .string) ts.status = parseStatus(sv.string);
        }
        if (obj.object.get("agent")) |av| {
            if (av == .string) ts.agent = try alloc.dupe(u8, av.string);
        }
        if (obj.object.get("bundle")) |bv| {
            if (bv == .string) ts.bundle = try alloc.dupe(u8, bv.string);
        }
        if (obj.object.get("set")) |sv2| {
            if (sv2 == .string and sv2.string.len == 1) ts.set = sv2.string[0];
        }
        if (obj.object.get("holds")) |hv| {
            if (hv == .array) {
                var list = std.ArrayList([]const u8).empty;
                for (hv.array.items) |item| {
                    if (item == .string) {
                        try list.append(alloc, try alloc.dupe(u8, item.string));
                    }
                }
                ts.holds = try list.toOwnedSlice(alloc);
            }
        }
        if (obj.object.get("needs")) |nv| {
            if (nv == .array) {
                var list = std.ArrayList([]const u8).empty;
                for (nv.array.items) |item| {
                    if (item == .string) {
                        try list.append(alloc, try alloc.dupe(u8, item.string));
                    }
                }
                ts.needs = try list.toOwnedSlice(alloc);
            }
        }
        if (obj.object.get("needs_context")) |cv| {
            if (cv == .integer) ts.needs_context = @intCast(cv.integer);
        }
        if (obj.object.get("added")) |ad| {
            if (ad == .string) ts.added = try alloc.dupe(u8, ad.string);
        }
        if (obj.object.get("claimed")) |cl| {
            if (cl == .string) ts.claimed = try alloc.dupe(u8, cl.string);
        }
        if (obj.object.get("done")) |dn| {
            if (dn == .string) ts.done = try alloc.dupe(u8, dn.string);
        }

        try state.put(alloc, task_id, ts);
    }

    return state;
}

fn serializeState(state: *StateMap, buf: *std.ArrayList(u8)) !void {
    try buf.appendSlice(alloc, "{");

    var it = state.iterator();
    var first = true;
    while (it.next()) |entry| {
        if (!first) try buf.appendSlice(alloc, ",");
        first = false;

        try buf.appendSlice(alloc, "\n  \"");
        try buf.appendSlice(alloc, entry.key_ptr.*);
        try buf.appendSlice(alloc, "\": {");

        const ts = entry.value_ptr.*;
        try buf.appendSlice(alloc, "\n    \"status\": \"");
        try buf.appendSlice(alloc, statusToString(ts.status));
        try buf.appendSlice(alloc, "\"");

        if (ts.agent) |a| {
            try buf.appendSlice(alloc, ",\n    \"agent\": \"");
            try buf.appendSlice(alloc, a);
            try buf.appendSlice(alloc, "\"");
        }
        try buf.appendSlice(alloc, ",\n    \"bundle\": \"");
        try buf.appendSlice(alloc, ts.bundle);
        try buf.appendSlice(alloc, "\"");

        try buf.appendSlice(alloc, ",\n    \"set\": \"");
        try buf.append(alloc, ts.set);
        try buf.appendSlice(alloc, "\"");

        try buf.appendSlice(alloc, ",\n    \"holds\": [");
        for (ts.holds, 0..) |h, hi| {
            if (hi > 0) try buf.appendSlice(alloc, ", ");
            try buf.appendSlice(alloc, "\"");
            try buf.appendSlice(alloc, h);
            try buf.appendSlice(alloc, "\"");
        }
        try buf.appendSlice(alloc, "]");

        try buf.appendSlice(alloc, ",\n    \"needs\": [");
        for (ts.needs, 0..) |n, ni| {
            if (ni > 0) try buf.appendSlice(alloc, ", ");
            try buf.appendSlice(alloc, "\"");
            try buf.appendSlice(alloc, n);
            try buf.appendSlice(alloc, "\"");
        }
        try buf.appendSlice(alloc, "]");

        // needs_context as number
        var ctx_buf: [32]u8 = undefined;
        const ctx_str = try std.fmt.bufPrint(&ctx_buf, "{}", .{ts.needs_context});
        try buf.appendSlice(alloc, ",\n    \"needs_context\": ");
        try buf.appendSlice(alloc, ctx_str);

        try buf.appendSlice(alloc, ",\n    \"added\": \"");
        try buf.appendSlice(alloc, ts.added);
        try buf.appendSlice(alloc, "\"");

        if (ts.claimed) |c| {
            try buf.appendSlice(alloc, ",\n    \"claimed\": \"");
            try buf.appendSlice(alloc, c);
            try buf.appendSlice(alloc, "\"");
        } else {
            try buf.appendSlice(alloc, ",\n    \"claimed\": null");
        }

        if (ts.done) |d| {
            try buf.appendSlice(alloc, ",\n    \"done\": \"");
            try buf.appendSlice(alloc, d);
            try buf.appendSlice(alloc, "\"");
        } else {
            try buf.appendSlice(alloc, ",\n    \"done\": null");
        }

        try buf.appendSlice(alloc, "\n  }");
    }

    if (!first) try buf.appendSlice(alloc, "\n");
    try buf.appendSlice(alloc, "}\n");
}

fn parseStatus(s: []const u8) TaskStatus {
    if (std.mem.eql(u8, s, "blocked")) return .blocked;
    if (std.mem.eql(u8, s, "dispatchable")) return .dispatchable;
    if (std.mem.eql(u8, s, "in_progress")) return .in_progress;
    if (std.mem.eql(u8, s, "done")) return .done;
    if (std.mem.eql(u8, s, "failed")) return .failed;
    return .dispatchable;
}

fn statusToString(s: TaskStatus) []const u8 {
    return switch (s) {
        .blocked => "blocked",
        .dispatchable => "dispatchable",
        .in_progress => "in_progress",
        .done => "done",
        .failed => "failed",
    };
}

// ── helpers ─────────────────────────────────────────────────────────────────

fn nowMs() u64 {
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(std.c.CLOCK.MONOTONIC, &ts);
    return @as(u64, @intCast(ts.sec)) * 1000 + @as(u64, @intCast(ts.nsec)) / 1_000_000;
}

fn nowTimestamp() ![]const u8 {
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(std.c.CLOCK.REALTIME, &ts);
    const epoch_secs: u64 = @intCast(@max(ts.sec, 0));
    const secs_per_day: u64 = 86400;
    var days = epoch_secs / secs_per_day;
    var remaining = epoch_secs % secs_per_day;

    var year: u64 = 1970;
    while (true) {
        const days_in_year: u64 = if (isLeapYear(year)) 366 else 365;
        if (days < days_in_year) break;
        days -= days_in_year;
        year += 1;
    }

    const month_days = if (isLeapYear(year))
        [_]u64{ 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }
    else
        [_]u64{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };

    var month: u64 = 1;
    for (month_days) |md| {
        if (days < md) break;
        days -= md;
        month += 1;
    }

    const day = days + 1;
    const hours = remaining / 3600;
    remaining %= 3600;
    const mins = remaining / 60;
    const secs = remaining % 60;

    return try std.fmt.allocPrint(alloc, "{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z", .{
        year, month, day, hours, mins, secs,
    });
}

fn isLeapYear(y: u64) bool {
    if (y % 400 == 0) return true;
    if (y % 100 == 0) return false;
    return y % 4 == 0;
}

// Returns true if any task in a prior set (A < B < C) is not yet done.
fn phaseGate(state: StateMap, set: u8) bool {
    const set_order = "ABC";
    const my_idx = std.mem.indexOfScalar(u8, set_order, set) orelse return false;
    if (my_idx == 0) return false; // Set A has no prior set

    var it = state.iterator();
    while (it.next()) |entry| {
        const ts = entry.value_ptr.*;
        if (ts.status == .done or ts.status == .failed) continue;
        const ts_idx = std.mem.indexOfScalar(u8, set_order, ts.set) orelse continue;
        if (ts_idx < my_idx) return true; // prior-set task not done
    }
    return false;
}

// Returns the ID of an in-progress task (in any set) that holds any of the same files.
fn holdsConflict(state: StateMap, holds: []const []const u8, exclude_id: []const u8) ?[]const u8 {
    if (holds.len == 0) return null;
    var it = state.iterator();
    while (it.next()) |entry| {
        const ts = entry.value_ptr.*;
        if (ts.status != .in_progress) continue;
        if (std.mem.eql(u8, entry.key_ptr.*, exclude_id)) continue;
        if (ts.holds.len == 0) continue;
        for (holds) |h| {
            for (ts.holds) |oh| {
                if (std.mem.eql(u8, h, oh)) return entry.key_ptr.*;
            }
        }
    }
    return null;
}

// ── commands ────────────────────────────────────────────────────────────────

fn cmdAdd(io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    if (args.len < 3) {
        std.debug.print("usage: managent add <id>\n", .{});
        std.process.exit(1);
    }
    const id = args[2];

    var bundle_override: ?[]const u8 = null;
    var set_override: ?[]const u8 = null;
    var needs_extra: ?[]const u8 = null;

    var i: usize = 3;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--bundle") and i + 1 < args.len) {
            i += 1;
            bundle_override = args[i];
        } else if (std.mem.eql(u8, args[i], "--set") and i + 1 < args.len) {
            i += 1;
            set_override = args[i];
        } else if (std.mem.eql(u8, args[i], "--needs") and i + 1 < args.len) {
            i += 1;
            needs_extra = args[i];
        }
    }

    var state = try readState(io, state_path);
    // We'll write back at end since readState already released the lock

    if (state.contains(id)) {
        std.debug.print("error: task '{s}' already exists\n", .{id});
        std.process.exit(1);
    }

    // Find bundle
    const bundle_path = if (bundle_override) |bp|
        try alloc.dupe(u8, bp)
    else
        try findBundle(io, repo_root, id);
    const owned_bundle = bundle_override == null;
    defer if (owned_bundle) alloc.free(bundle_path);

    const meta = try parseBundleMeta(io, bundle_path, set_override, needs_extra);

    // Compute initial status: blocked if needs unmet or phase gate not open
    const phase_open = !phaseGate(state, meta.set);
    const needs_met = meta.needs.len == 0 or for (meta.needs) |n| {
        const nts = state.get(n);
        if (nts == null or nts.?.status != .done) break false;
    } else true;
    const initial_status: TaskStatus = if (needs_met and phase_open) .dispatchable else .blocked;

    const now = try nowTimestamp();

    const ts = TaskState{
        .status = initial_status,
        .agent = null,
        .bundle = bundle_path,
        .set = meta.set,
        .holds = meta.holds,
        .needs = meta.needs,
        .needs_context = meta.context,
        .added = now,
        .claimed = null,
        .done = null,
    };

    try state.put(alloc, try alloc.dupe(u8, id), ts);

    try writeState(io, state_path, &state);

    // Print confirmation
    const set_label = if (meta.holds.len > 0)
        try std.fmt.allocPrint(alloc, "set: {c}, holds {s}", .{ meta.set, meta.holds[0] })
    else
        try std.fmt.allocPrint(alloc, "set: {c}", .{meta.set});
    defer alloc.free(set_label);

    if (initial_status == .blocked) {
        std.debug.print("\n  registered {s}  [{s}]  [blocked", .{id, set_label});
        if (meta.needs.len > 0) {
            std.debug.print(": needs", .{});
            for (meta.needs) |n| std.debug.print(" {s}", .{n});
        }
        if (!phase_open) std.debug.print(": phase {c}", .{meta.set});
        std.debug.print("]\n", .{});
    } else {
        std.debug.print("\n  registered {s}  [{s}]  [dispatchable]\n", .{ id, set_label });
    }
}

fn cmdClaim(io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    if (args.len < 3) {
        std.debug.print("usage: managent claim <id> [--agent <name>] [--exec <prefix>]\n", .{});
        std.process.exit(1);
    }
    const id = args[2];

    var agent_name: ?[]const u8 = null;
    var exec_prefix: ?[]const u8 = null;
    var i: usize = 3;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--agent") and i + 1 < args.len) {
            i += 1;
            agent_name = args[i];
        } else if (std.mem.eql(u8, args[i], "--exec") and i + 1 < args.len) {
            i += 1;
            exec_prefix = args[i];
        }
    }

    var state = try readState(io, state_path);

    const ts_ptr = state.getPtr(id) orelse {
        std.debug.print("error: task '{s}' not found\n", .{id});
        std.process.exit(1);
    };

    switch (ts_ptr.status) {
        .blocked => {
            std.debug.print("\n  BLOCKED: {s}", .{id});
            if (ts_ptr.needs.len > 0) {
                std.debug.print(" needs", .{});
                for (ts_ptr.needs) |n| {
                    const need_ts = state.get(n);
                    const need_status: []const u8 = if (need_ts) |nts| statusToString(nts.status) else "unknown";
                    std.debug.print(" {s}={s}", .{ n, need_status });
                }
            }
            if (phaseGate(state, ts_ptr.set)) std.debug.print(" phase {c}", .{ts_ptr.set});
            std.debug.print("\n", .{});
            std.process.exit(1);
        },
        .in_progress => {
            std.debug.print("\n  ALREADY CLAIMED: {s} is already in progress", .{id});
            if (ts_ptr.agent) |a| std.debug.print(" by {s}", .{a});
            std.debug.print("\n", .{});
            std.process.exit(1);
        },
        .done => {
            std.debug.print("\n  ALREADY DONE: {s}\n", .{id});
            std.process.exit(1);
        },
        .failed => {
            std.debug.print("\n  FAILED: {s} has failed\n", .{id});
            std.process.exit(1);
        },
        .dispatchable => {
            // Phase gate: all prior sets must be done
            if (phaseGate(state, ts_ptr.set)) {
                std.debug.print("\n  REJECTED: phase gate — prior set not yet complete\n", .{});
                std.process.exit(1);
            }

            // Cross-set file-lock: no in-progress task may hold the same file
            if (holdsConflict(state, ts_ptr.holds, id)) |holder| {
                std.debug.print("\n  REJECTED: holds conflict on file — {s} is in progress\n", .{holder});
                std.process.exit(1);
            }

            // Claim it
            const now = try nowTimestamp();
            ts_ptr.status = .in_progress;
            ts_ptr.agent = if (agent_name) |a| try alloc.dupe(u8, a) else null;
            ts_ptr.claimed = now;

            try writeState(io, state_path, &state);

            std.debug.print("\n  claimed {s}  [set: {c}]\n", .{ id, ts_ptr.set });
            std.debug.print("  follow {s}\n", .{ts_ptr.bundle});

            if (exec_prefix) |prefix| {
                const rel = bundleRel(ts_ptr.bundle, repo_root);
                try execHarness(prefix, rel);
            }
        },
    }
}

fn cmdDone(io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    _ = repo_root;
    if (args.len < 3) {
        std.debug.print("usage: managent done <id> [--fail]\n", .{});
        std.process.exit(1);
    }
    const id = args[2];
    const is_fail = for (args[3..]) |a| {
        if (std.mem.eql(u8, a, "--fail")) break true;
    } else false;

    var state = try readState(io, state_path);

    const ts_ptr = state.getPtr(id) orelse {
        std.debug.print("error: task '{s}' not found\n", .{id});
        std.process.exit(1);
    };

    if (ts_ptr.status != .in_progress) {
        std.debug.print("error: task '{s}' is not in progress (status: {s})\n", .{ id, statusToString(ts_ptr.status) });
        std.process.exit(1);
    }

    const now = try nowTimestamp();

    if (is_fail) {
        ts_ptr.status = .failed;
        ts_ptr.done = now;
        try writeState(io, state_path, &state);
        std.debug.print("\n  {s} failed  [set: {c}]\n", .{ id, ts_ptr.set });
    } else {
        ts_ptr.status = .done;
        ts_ptr.done = now;

        // Find unblocked dependents (needs satisfied AND phase gate open)
        var unblocked = std.ArrayList([]const u8).empty;
        defer unblocked.deinit(alloc);

        var it = state.iterator();
        while (it.next()) |entry| {
            const dep_ts = entry.value_ptr.*;
            if (dep_ts.status != .blocked) continue;

            const needs_met = dep_ts.needs.len == 0 or for (dep_ts.needs) |n| {
                const nts = state.get(n);
                if (nts == null or nts.?.status != .done) break false;
            } else true;

            const gate_open = !phaseGate(state, dep_ts.set);

            if (needs_met and gate_open) {
                const dep_ptr = state.getPtr(entry.key_ptr.*).?;
                dep_ptr.status = .dispatchable;
                try unblocked.append(alloc, entry.key_ptr.*);
            }
        }

        try writeState(io, state_path, &state);

        std.debug.print("\n  {s} done  [set: {c}]", .{ id, ts_ptr.set });
        if (unblocked.items.len > 0) {
            std.debug.print("  [unblocks:", .{});
            for (unblocked.items) |ub| {
                std.debug.print(" {s}", .{ub});
            }
            std.debug.print("]\n", .{});
        } else {
            std.debug.print("\n", .{});
        }
    }
}

fn cmdStatus(io: std.Io, state_path: []const u8, repo_root: []const u8) !void {
    var state = try readState(io, state_path);
    defer freeState(&state);

    var dispatchable = std.ArrayList([]const u8).empty;
    defer dispatchable.deinit(alloc);
    var in_progress = std.ArrayList([]const u8).empty;
    defer in_progress.deinit(alloc);
    var blocked = std.ArrayList([]const u8).empty;
    defer blocked.deinit(alloc);
    var done = std.ArrayList([]const u8).empty;
    defer done.deinit(alloc);
    var failed = std.ArrayList([]const u8).empty;
    defer failed.deinit(alloc);

    var it_sort = state.iterator();
    while (it_sort.next()) |entry| {
        const tid = entry.key_ptr.*;
        switch (entry.value_ptr.*.status) {
            .dispatchable => try dispatchable.append(alloc, tid),
            .in_progress => try in_progress.append(alloc, tid),
            .blocked => try blocked.append(alloc, tid),
            .done => try done.append(alloc, tid),
            .failed => try failed.append(alloc, tid),
        }
    }

    const sortFn = struct {
        fn lt(_: void, a: []const u8, b: []const u8) bool { return std.mem.lessThan(u8, a, b); }
    }.lt;
    std.mem.sort([]const u8, dispatchable.items, {}, sortFn);
    std.mem.sort([]const u8, in_progress.items, {}, sortFn);
    std.mem.sort([]const u8, blocked.items, {}, sortFn);
    std.mem.sort([]const u8, done.items, {}, sortFn);
    std.mem.sort([]const u8, failed.items, {}, sortFn);

    std.debug.print("\n", .{});
    printSection("dispatchable", dispatchable.items, &state, repo_root);
    printSection("in progress", in_progress.items, &state, repo_root);
    printSection("blocked", blocked.items, &state, repo_root);
    printSection("done", done.items, &state, repo_root);
    printSection("failed", failed.items, &state, repo_root);
    std.debug.print("\n", .{});
}

fn printSection(label: []const u8, ids: []const []const u8, state: *StateMap, repo_root: []const u8) void {
    std.debug.print("  {s} ({d})\n", .{ label, ids.len });
    if (ids.len == 0) {
        std.debug.print("    -- none --\n", .{});
        return;
    }
    for (ids) |tid| {
        const ts = state.get(tid).?;
        const rel = bundleRel(ts.bundle, repo_root);

        // Build the stable prompt line:
        // <ID> set <set>, context <ctx>: follow <relpath>
        // Extra metadata appended before ':' if present.
        std.debug.print("    {s} set {c}", .{ tid, ts.set });
        if (ts.needs_context > 0) {
            std.debug.print(", context ", .{});
            printContext(ts.needs_context);
        }
        if (ts.needs.len > 0) {
            std.debug.print(", needs", .{});
            for (ts.needs) |n| std.debug.print(" {s}", .{n});
        }
        if (ts.holds.len > 0) {
            std.debug.print(", holds", .{});
            for (ts.holds) |h| std.debug.print(" {s}", .{h});
        }
        if (ts.agent) |a| {
            std.debug.print(", agent {s}", .{a});
        }
        std.debug.print(": follow {s}\n", .{rel});
    }
}

fn relativizePath(bundle: []const u8, repo_prefix: []const u8) []const u8 {
    if (std.mem.startsWith(u8, bundle, repo_prefix)) {
        return bundle[repo_prefix.len..];
    }
    return bundle;
}

fn bundleRel(bundle: []const u8, repo_root: []const u8) []const u8 {
    // Strip repo_root/ from the bundle path → untracked/foo.md
    if (std.fs.path.isAbsolute(bundle)) {
        // bundle = /Users/.../weizigo/untracked/foo.md
        // repo_root = /Users/.../weizigo
        // result = untracked/foo.md
        if (repo_root.len + 1 <= bundle.len and bundle[repo_root.len] == '/') {
            if (std.mem.startsWith(u8, bundle, repo_root)) {
                return bundle[repo_root.len + 1 ..];
            }
        }
    }
    return bundle;
}

fn cmdNext(io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    var context_limit: u64 = std.math.maxInt(u64);
    var exec_prefix: ?[]const u8 = null;
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "--context") and i + 1 < args.len) {
            i += 1;
            context_limit = parseContextValue(args[i]);
        } else if (std.mem.eql(u8, args[i], "--exec") and i + 1 < args.len) {
            i += 1;
            exec_prefix = args[i];
        }
    }

    var state = try readState(io, state_path);

    // Find first dispatchable task that meets context requirement
    var candidate_id: ?[]const u8 = null;

    var it = state.iterator();
    while (it.next()) |entry| {
        const ts = entry.value_ptr.*;
        if (ts.status != .dispatchable) continue;
        if (ts.needs_context > context_limit) continue;
        if (phaseGate(state, ts.set)) continue;
        if (holdsConflict(state, ts.holds, entry.key_ptr.*) != null) continue;

        candidate_id = entry.key_ptr.*;
        break;
    }

    if (candidate_id == null) return; // No eligible task; exit silently

    const id = candidate_id.?;
    const ts_ptr = state.getPtr(id).?;

    const now = try nowTimestamp();
    ts_ptr.status = .in_progress;
    ts_ptr.claimed = now;

    try writeState(io, state_path, &state);

    std.debug.print("\n  claimed {s}  [set: {c}]\n", .{ id, ts_ptr.set });
    std.debug.print("  follow {s}\n", .{ts_ptr.bundle});

    if (exec_prefix) |prefix| {
        const rel = bundleRel(ts_ptr.bundle, repo_root);
        try execHarness(prefix, rel);
    }
}

fn cmdShow(io: std.Io, state_path: []const u8, args: [][]const u8) !void {
    if (args.len < 3) {
        std.debug.print("usage: managent show <id>\n", .{});
        std.process.exit(1);
    }
    const id = args[2];

    var state = try readState(io, state_path);
    defer freeState(&state);

    const ts = state.get(id) orelse {
        std.debug.print("error: task '{s}' not found\n", .{id});
        std.process.exit(1);
    };

    std.debug.print("\n", .{});
    std.debug.print("  {s}  {s}\n", .{ id, statusToString(ts.status) });
    std.debug.print("    bundle:   {s}\n", .{ts.bundle});
    std.debug.print("    set:      {c}\n", .{ts.set});
    if (ts.holds.len > 0) {
        std.debug.print("    holds:    ", .{});
        for (ts.holds, 0..) |h, j| {
            if (j > 0) std.debug.print(" ", .{});
            std.debug.print("{s}", .{h});
        }
        std.debug.print("\n", .{});
    } else {
        std.debug.print("    holds:    -- none --\n", .{});
    }
    std.debug.print("    needs:    ", .{});
    if (ts.needs.len > 0) {
        for (ts.needs, 0..) |n, j| {
            if (j > 0) std.debug.print(" ", .{});
            std.debug.print("{s}", .{n});
        }
    } else {
        std.debug.print("-- none --", .{});
    }
    std.debug.print("\n", .{});

    // Find tasks that need this one
    var needed_by = std.ArrayList([]const u8).empty;
    defer needed_by.deinit(alloc);
    var it = state.iterator();
    while (it.next()) |entry| {
        for (entry.value_ptr.*.needs) |n| {
            if (std.mem.eql(u8, n, id)) {
                try needed_by.append(alloc, entry.key_ptr.*);
                break;
            }
        }
    }
    std.debug.print("    needed by:", .{});
    if (needed_by.items.len > 0) {
        for (needed_by.items) |nb| {
            std.debug.print(" {s}", .{nb});
        }
    } else {
        std.debug.print(" -- none --", .{});
    }
    std.debug.print("\n", .{});

    std.debug.print("    context:  ", .{});
    printContext(ts.needs_context);
    std.debug.print("\n", .{});

    std.debug.print("    added:    {s}\n", .{ts.added});
    if (ts.claimed) |c| {
        std.debug.print("    claimed:  {s}\n", .{c});
    }
    if (ts.done) |d| {
        std.debug.print("    done:     {s}\n", .{d});
    }
    std.debug.print("\n", .{});
}

fn printContext(c: u64) void {
    if (c > 0) {
        if (c >= 1_000_000) {
            std.debug.print("{d}M", .{c / 1_000_000});
        } else if (c >= 1_000) {
            std.debug.print("{d}k", .{c / 1_000});
        } else {
            std.debug.print("{d}", .{c});
        }
    } else {
        std.debug.print("-", .{});
    }
}

fn printHelp() void {
    std.debug.print(
        \\managent — agent-manager CLI
        \\
        \\Usage:
        \\  managent                  show current state (default)
        \\  managent status           show current state
        \\  managent add <id>         register a task from untracked/<id>-*.md
        \\  managent claim <id>       claim a task for execution
        \\  managent done <id>        mark a task complete
        \\  managent done <id> --fail mark a task failed
        \\  managent next             claim the next available task
        \\  managent show <id>        show details for one task
        \\  managent help             show this help
        \\
        \\Options:
        \\  --agent <name>           label who claimed (with claim)
        \\  --bundle <path>          override bundle path (with add)
        \\  --set <A|B|C>            override parallel set (with add)
        \\  --needs <id>             add extra dependency (with add)
        \\  --context <N>            agent token limit filter (with next)
        \\  --exec <prefix>          claim and exec into harness (with claim / next)
        \\  -h, --help               show this help
        \\
        \\Examples:
        \\  managent next --exec "pi --provider deepseek --model deepseek-v4-pro"
        \\  managent claim B17 --exec "pi --provider ollama --model glm-5.2:cloud"
        \\
    , .{});
}

fn execHarness(prefix: []const u8, follow: []const u8) !void {
    // Build: /bin/sh -c '<prefix> -p "follow <path>"'
    const cmd = try std.fmt.allocPrint(alloc, "{s} -p \"follow {s}\"", .{ prefix, follow });
    defer alloc.free(cmd);

    // Null-terminate the command string for execve
    const cmd_z = try alloc.allocSentinel(u8, cmd.len, 0);
    defer alloc.free(cmd_z);
    @memcpy(cmd_z, cmd);

    const sh = "/bin/sh";
    const argv: [3:null]?[*:0]const u8 = .{ sh, "-c", cmd_z };
    _ = std.c.execve(sh, &argv, std.c.environ);
    // execve only returns on error
    std.process.exit(1);
}

fn freeState(state: *StateMap) void {
    var it = state.iterator();
    while (it.next()) |entry| {
        alloc.free(entry.key_ptr.*);
        const ts = entry.value_ptr.*;
        alloc.free(ts.bundle);
        if (ts.agent) |a| alloc.free(a);
        for (ts.holds) |h| alloc.free(h);
        alloc.free(ts.holds);
        for (ts.needs) |n| alloc.free(n);
        alloc.free(ts.needs);
        alloc.free(ts.added);
        if (ts.claimed) |c| alloc.free(c);
        if (ts.done) |d| alloc.free(d);
    }
    state.deinit(alloc);
}
