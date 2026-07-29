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
// ORCHA-AUTOMATION (2026-07-30): stdout/stderr split, --json, sync, audit,
// standing-tier auto-registration, attribution enforcement, retrieval surface.
//

const std = @import("std");

const alloc = std.heap.page_allocator;

// ── Writers: stdout for data, stderr for diagnostics ────────────────────────

const Writers = struct {
    io: std.Io,

    /// Write data to stdout — anything a caller might parse, filter, or redirect.
    fn data(self: Writers, comptime fmt: []const u8, args: anytype) void {
        var buf: [4096]u8 = undefined;
        var w = std.Io.File.stdout().writer(self.io, &buf);
        w.interface.print(fmt, args) catch {};
        w.flush() catch {};
    }

    /// Write diagnostics to stderr — warnings, errors, progress chatter.
    fn diag(_: Writers, comptime fmt: []const u8, args: anytype) void {
        std.debug.print(fmt, args);
    }
};

// ── task types ──────────────────────────────────────────────────────────────

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
    set: u8 = 'A',
    holds: [][]const u8 = &.{},
    needs: [][]const u8 = &.{},
    caps: [][]const u8 = &.{},
    added: []const u8 = "",
    claimed: ?[]const u8 = null,
    done: ?[]const u8 = null,
    dispatched: ?[]const u8 = null,
    dispatched_to: ?[]const u8 = null,
    note: ?[]const u8 = null,
};

// ── message-bus types ───────────────────────────────────────────────────────

const RoleSync = struct {
    last_read_msg: u32 = 0,
    last_posted_msg: u32 = 0,
    last_event_gen: u64 = 0,
};

const StateMap = std.StringHashMapUnmanaged(TaskState);

// ─────────────────────────────────────────────────────────────────── entry

pub fn main(init: std.process.Init.Minimal) !void {
    const args_raw = init.args.vector;
    var args_slice = std.ArrayList([]const u8).empty;
    defer args_slice.deinit(alloc);
    for (args_raw) |arg| {
        try args_slice.append(alloc, std.mem.span(arg));
    }
    const args = args_slice.items;

    var threaded = std.Io.Threaded.init(alloc, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const w = Writers{ .io = io };

    const repo_root = try findRepoRoot(w, io);
    defer alloc.free(repo_root);

    const state_path = try std.fs.path.join(alloc, &.{ repo_root, "docs", "infra", "managent", "tasks.json" });
    defer alloc.free(state_path);

    // Ensure the managent directory exists
    const dir_path = "docs/infra/managent";
    std.Io.Dir.cwd().createDirPath(io, dir_path) catch {};

    // Migration: on every invocation, re-derive dispatchable/blocked statuses
    {
        var st = try readState(io, state_path);
        if (migrateState(w, &st)) {
            try writeState(io, state_path, &st);
        }
        freeState(&st);
    }

    // Determine command
    const cmd: []const u8 = if (args.len >= 2 and !std.mem.startsWith(u8, args[1], "-")) args[1] else "status";

    // Help flags
    if (args.len >= 2) {
        if (std.mem.eql(u8, args[1], "-h") or std.mem.eql(u8, args[1], "--help") or std.mem.eql(u8, cmd, "help")) {
            printHelp(w);
            return;
        }
    }

    if (std.mem.eql(u8, cmd, "add")) {
        try cmdAdd(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "claim")) {
        try cmdClaim(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "done")) {
        try cmdDone(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "status")) {
        try cmdStatus(w, io, state_path, repo_root, args);
    } else if (std.mem.eql(u8, cmd, "next")) {
        try cmdNext(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "show")) {
        try cmdShow(w, io, state_path, args);
    } else if (std.mem.eql(u8, cmd, "dispatch")) {
        try cmdDispatch(w, io, state_path, args);
    } else if (std.mem.eql(u8, cmd, "reopen")) {
        try cmdReopen(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "purge")) {
        try cmdPurge(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "set")) {
        try cmdSet(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "needs")) {
        try cmdNeeds(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "agent")) {
        try cmdAgent(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "sync")) {
        try cmdSync(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "audit")) {
        try cmdAudit(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "standing")) {
        try cmdStanding(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "why")) {
        try cmdWhy(w, io, state_path, args);
    } else {
        w.diag("unknown command: {s}\n", .{cmd});
        std.process.exit(1);
    }
}

// ── repo root ───────────────────────────────────────────────────────────────

fn findRepoRoot(w: Writers, io: std.Io) ![]const u8 {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const cwd_ptr = std.c.getcwd(&buf, buf.len) orelse {
        w.diag("error: cannot get current directory\n", .{});
        std.process.exit(1);
    };
    const cwd = std.mem.sliceTo(cwd_ptr, 0);

    var current: []const u8 = cwd;
    while (true) {
        var dir = try std.Io.Dir.openDirAbsolute(io, current, .{});
        defer dir.close(io);

        if (dir.access(io, ".git", .{})) |_| {
            return alloc.dupe(u8, current);
        } else |_| {}

        const parent = std.fs.path.dirname(current) orelse {
            w.diag("error: could not find repo root (no .git found)\n", .{});
            std.process.exit(1);
        };
        if (std.mem.eql(u8, parent, current)) {
            w.diag("error: could not find repo root (no .git found)\n", .{});
            std.process.exit(1);
        }
        current = parent;
    }
}

// ── bundle parsing ──────────────────────────────────────────────────────────

const BundleMeta = struct {
    set: u8,
    holds: [][]const u8,
    needs: [][]const u8,
    caps: [][]const u8,
};

fn findBundle(w: Writers, io: std.Io, repo_root: []const u8, id: []const u8) ![]const u8 {
    const untracked_path = try std.fs.path.join(alloc, &.{ repo_root, "untracked" });
    defer alloc.free(untracked_path);

    var dir = std.Io.Dir.cwd().openDir(io, untracked_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            w.diag("error: no bundle found for {s} (untracked/ not found)\n", .{id});
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
        w.diag("error: no bundle found for {s} (glob: untracked/{s}-*.md)\n", .{ id, id });
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

fn parseBundleMeta(w: Writers, io: std.Io, bundle_path: []const u8, set_override: ?[]const u8, needs_extra: ?[]const u8) !BundleMeta {
    const content = std.Io.Dir.cwd().readFileAlloc(io, bundle_path, alloc, .unlimited) catch |err| {
        w.diag("error: cannot read bundle {s}: {}\n", .{ bundle_path, err });
        std.process.exit(1);
    };
    defer alloc.free(content);

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
        w.diag("error: no <!--managent ...--> metadata found in {s}\n", .{bundle_path});
        std.process.exit(1);
    }

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
        .caps = &.{},
    };

    var set_found = false;

    var tokens = std.mem.splitScalar(u8, inner_trimmed, ' ');
    while (tokens.next()) |token| {
        if (token.len == 0) continue;
        var parts = std.mem.splitScalar(u8, token, '=');
        const key = parts.next() orelse continue;
        const value = parts.next() orelse "";

        if (std.mem.eql(u8, key, "set")) {
            if (value.len != 1 or value[0] < 'A' or value[0] > 'Z') {
                w.diag("error: invalid set '{s}' in metadata (must be A–Z)\n", .{value});
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
                var needs_split = std.mem.splitScalar(u8, value, ',');
                while (needs_split.next()) |nid| {
                    const trimmed = std.mem.trim(u8, nid, " \t");
                    if (trimmed.len > 0) {
                        try needs_list.append(alloc, try alloc.dupe(u8, trimmed));
                    }
                }
                result.needs = try needs_list.toOwnedSlice(alloc);
            }
        } else if (std.mem.eql(u8, key, "caps")) {
            if (value.len > 0) {
                var caps_list = std.ArrayList([]const u8).empty;
                var caps_split = std.mem.splitScalar(u8, value, ' ');
                while (caps_split.next()) |c| {
                    const trimmed = std.mem.trim(u8, c, " \t");
                    if (trimmed.len > 0) {
                        try caps_list.append(alloc, try alloc.dupe(u8, trimmed));
                    }
                }
                result.caps = try caps_list.toOwnedSlice(alloc);
            }
        } else if (std.mem.eql(u8, key, "context")) {
            w.diag("error: 'context=…' key is rejected (retired 2026-07-28); remove it from {s}\n", .{bundle_path});
            std.process.exit(1);
        }
    }

    if (!set_found) {
        w.diag("error: metadata missing required 'set' key in {s}\n", .{bundle_path});
        std.process.exit(1);
    }

    if (set_override) |s| {
        if (s.len != 1 or s[0] < 'A' or s[0] > 'Z') {
            w.diag("error: invalid --set '{s}' (must be A–Z)\n", .{s});
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

// ── state file ──────────────────────────────────────────────────────────────

fn lockStateDir(io: std.Io, state_path: []const u8) !void {
    const lock_path = try std.fmt.allocPrint(alloc, "{s}.lock", .{state_path});
    defer alloc.free(lock_path);

    if (std.fs.path.dirname(lock_path)) |dp| {
        std.Io.Dir.cwd().createDirPath(io, dp) catch {};
    }

    var delay: u64 = 1 * std.time.ns_per_ms;
    while (true) {
        std.Io.Dir.cwd().createDir(io, lock_path, .default_dir) catch {
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

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(alloc);
    try serializeState(state, &buf);

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
        const key = entry.key_ptr.*;
        // Skip metadata keys (prefixed with _)
        if (std.mem.startsWith(u8, key, "_")) continue;

        const task_id = try alloc.dupe(u8, key);
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
        if (obj.object.get("caps")) |cv| {
            if (cv == .array) {
                var list = std.ArrayList([]const u8).empty;
                for (cv.array.items) |item| {
                    if (item == .string) {
                        try list.append(alloc, try alloc.dupe(u8, item.string));
                    }
                }
                ts.caps = try list.toOwnedSlice(alloc);
            }
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
        if (obj.object.get("dispatched")) |dp| {
            if (dp == .string) ts.dispatched = try alloc.dupe(u8, dp.string);
        }
        if (obj.object.get("dispatched_to")) |dt| {
            if (dt == .string) ts.dispatched_to = try alloc.dupe(u8, dt.string);
        }
        if (obj.object.get("note")) |nt| {
            if (nt == .string) ts.note = try alloc.dupe(u8, nt.string);
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

        try buf.appendSlice(alloc, ",\n    \"caps\": [");
        for (ts.caps, 0..) |c, ci| {
            if (ci > 0) try buf.appendSlice(alloc, ", ");
            try buf.appendSlice(alloc, "\"");
            try buf.appendSlice(alloc, c);
            try buf.appendSlice(alloc, "\"");
        }
        try buf.appendSlice(alloc, "]");

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

        if (ts.dispatched) |dp| {
            try buf.appendSlice(alloc, ",\n    \"dispatched\": \"");
            try buf.appendSlice(alloc, dp);
            try buf.appendSlice(alloc, "\"");
        } else {
            try buf.appendSlice(alloc, ",\n    \"dispatched\": null");
        }

        if (ts.dispatched_to) |dt| {
            try buf.appendSlice(alloc, ",\n    \"dispatched_to\": \"");
            try buf.appendSlice(alloc, dt);
            try buf.appendSlice(alloc, "\"");
        } else {
            try buf.appendSlice(alloc, ",\n    \"dispatched_to\": null");
        }

        if (ts.note) |nt| {
            try buf.appendSlice(alloc, ",\n    \"note\": \"");
            try buf.appendSlice(alloc, nt);
            try buf.appendSlice(alloc, "\"");
        } else {
            try buf.appendSlice(alloc, ",\n    \"note\": null");
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

fn phaseGate(state: StateMap, set: u8) bool {
    _ = state;
    _ = set;
    return false;
}

fn needsMet(state: *const StateMap, ts: TaskState) bool {
    if (ts.needs.len == 0) return true;
    for (ts.needs) |n| {
        const nts = state.get(n);
        if (nts == null or nts.?.status != .done) return false;
    }
    return true;
}

fn deriveStatus(state: *const StateMap, ts: TaskState) TaskStatus {
    return switch (ts.status) {
        .in_progress, .done, .failed => ts.status,
        .dispatchable, .blocked => if (needsMet(state, ts)) .dispatchable else .blocked,
    };
}

fn migrateState(w: Writers, state: *StateMap) bool {
    var changed = false;
    var it = state.iterator();
    while (it.next()) |entry| {
        const id = entry.key_ptr.*;
        const ts = entry.value_ptr;
        if (ts.status != .dispatchable and ts.status != .blocked) continue;
        const derived = deriveStatus(state, ts.*);
        if (ts.status != derived) {
            const before = statusToString(ts.status);
            const after = statusToString(derived);
            w.diag("[migrate] {s}: stored {s} → {s} (needs-derived)\n", .{ id, before, after });
            ts.status = derived;
            changed = true;
        }
    }
    return changed;
}

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

fn bundleRel(bundle: []const u8, repo_root: []const u8) []const u8 {
    if (std.fs.path.isAbsolute(bundle)) {
        if (repo_root.len + 1 <= bundle.len and bundle[repo_root.len] == '/') {
            if (std.mem.startsWith(u8, bundle, repo_root)) {
                return bundle[repo_root.len + 1 ..];
            }
        }
    }
    return bundle;
}

// ── flag parsing helpers ────────────────────────────────────────────────────

fn hasFlag(args: [][]const u8, flag: []const u8) bool {
    for (args) |a| {
        if (std.mem.eql(u8, a, flag)) return true;
    }
    return false;
}

fn getFlagValue(args: [][]const u8, flag: []const u8) ?[]const u8 {
    var i: usize = 0;
    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], flag) and i + 1 < args.len) {
            return args[i + 1];
        }
    }
    return null;
}

// ── commands ────────────────────────────────────────────────────────────────

fn cmdAdd(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    if (args.len < 3) {
        w.diag("usage: managent add <id>\n", .{});
        std.process.exit(1);
    }
    const id = args[2];

    const bundle_override = getFlagValue(args, "--bundle");
    const set_override = getFlagValue(args, "--set");
    const needs_extra = getFlagValue(args, "--needs");

    var state = try readState(io, state_path);

    if (state.contains(id)) {
        w.diag("error: task '{s}' already exists\n", .{id});
        std.process.exit(1);
    }

    const bundle_path = if (bundle_override) |bp|
        try alloc.dupe(u8, bp)
    else
        try findBundle(w, io, repo_root, id);
    const owned_bundle = bundle_override == null;
    defer if (owned_bundle) alloc.free(bundle_path);

    const meta = try parseBundleMeta(w, io, bundle_path, set_override, needs_extra);

    const tmp_for_needs = TaskState{ .needs = meta.needs };
    const initial_status: TaskStatus = if (needsMet(&state, tmp_for_needs)) .dispatchable else .blocked;

    const now = try nowTimestamp();

    const ts = TaskState{
        .status = initial_status,
        .agent = null,
        .bundle = bundle_path,
        .set = meta.set,
        .holds = meta.holds,
        .needs = meta.needs,
        .caps = meta.caps,
        .added = now,
        .claimed = null,
        .done = null,
    };

    try state.put(alloc, try alloc.dupe(u8, id), ts);
    try writeState(io, state_path, &state);

    const set_label = if (meta.holds.len > 0)
        try std.fmt.allocPrint(alloc, "set: {c}, holds {s}", .{ meta.set, meta.holds[0] })
    else
        try std.fmt.allocPrint(alloc, "set: {c}", .{meta.set});
    defer alloc.free(set_label);

    if (initial_status == .blocked) {
        w.diag("\n  registered {s}  [{s}]  [blocked", .{ id, set_label });
        if (meta.needs.len > 0) {
            w.diag(": needs", .{});
            for (meta.needs) |n| w.diag(" {s}", .{n});
        }
        w.diag("]\n", .{});
    } else {
        w.diag("\n  registered {s}  [{s}]  [dispatchable]\n", .{ id, set_label });
    }
}

fn cmdClaim(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    if (args.len < 3) {
        w.diag("usage: managent claim <id> [--agent <name>] [--exec <prefix>]\n", .{});
        std.process.exit(1);
    }
    const id = args[2];

    const agent_name = getFlagValue(args, "--agent");
    const exec_prefix = getFlagValue(args, "--exec");

    var state = try readState(io, state_path);

    const ts_ptr = state.getPtr(id) orelse {
        w.diag("error: task '{s}' not found\n", .{id});
        std.process.exit(1);
    };

    if (!needsMet(&state, ts_ptr.*)) {
        w.diag("\n  UNMET NEEDS: {s}", .{id});
        for (ts_ptr.needs) |n| {
            const nts = state.get(n);
            const need_status: []const u8 = if (nts) |ntsv| statusToString(ntsv.status) else "unknown";
            w.diag(" {s}={s}", .{ n, need_status });
        }
        w.diag("\n", .{});
        std.process.exit(1);
    }

    switch (ts_ptr.status) {
        .blocked => {
            w.diag("\n  (stored blocked, needs met — claiming anyway)", .{});

            if (phaseGate(state, ts_ptr.set)) {
                w.diag("\n  REJECTED: phase gate — prior set not yet complete\n", .{});
                std.process.exit(1);
            }

            if (holdsConflict(state, ts_ptr.holds, id)) |holder| {
                w.diag("\n  REJECTED: holds conflict on file — {s} is in progress\n", .{holder});
                std.process.exit(1);
            }

            const now = try nowTimestamp();
            ts_ptr.status = .in_progress;
            ts_ptr.agent = if (agent_name) |a| try alloc.dupe(u8, a) else null;
            ts_ptr.claimed = now;

            try writeState(io, state_path, &state);
            w.diag("\n  claimed {s}  [set: {c}]\n", .{ id, ts_ptr.set });
            w.diag("  follow {s}\n", .{ts_ptr.bundle});

            if (exec_prefix) |prefix| {
                const rel = bundleRel(ts_ptr.bundle, repo_root);
                try execHarness(prefix, rel);
            }
        },
        .in_progress => {
            w.diag("\n  ALREADY CLAIMED: {s} is already in progress", .{id});
            if (ts_ptr.agent) |a| w.diag(" by {s}", .{a});
            w.diag("\n", .{});
            std.process.exit(1);
        },
        .done => {
            w.diag("\n  ALREADY DONE: {s}\n", .{id});
            std.process.exit(1);
        },
        .failed => {
            w.diag("\n  FAILED: {s} has failed\n", .{id});
            std.process.exit(1);
        },
        .dispatchable => {
            if (phaseGate(state, ts_ptr.set)) {
                w.diag("\n  REJECTED: phase gate — prior set not yet complete\n", .{});
                std.process.exit(1);
            }

            if (holdsConflict(state, ts_ptr.holds, id)) |holder| {
                w.diag("\n  REJECTED: holds conflict on file — {s} is in progress\n", .{holder});
                std.process.exit(1);
            }

            const now = try nowTimestamp();
            ts_ptr.status = .in_progress;
            ts_ptr.agent = if (agent_name) |a| try alloc.dupe(u8, a) else null;
            ts_ptr.claimed = now;

            try writeState(io, state_path, &state);

            w.diag("\n  claimed {s}  [set: {c}]\n", .{ id, ts_ptr.set });
            w.diag("  follow {s}\n", .{ts_ptr.bundle});

            if (exec_prefix) |prefix| {
                const rel = bundleRel(ts_ptr.bundle, repo_root);
                try execHarness(prefix, rel);
            }
        },
    }
}

fn cmdDispatch(w: Writers, io: std.Io, state_path: []const u8, args: [][]const u8) !void {
    if (args.len < 3) {
        w.diag("usage: managent dispatch <id> --to <agent> [--note <text>]\n", .{});
        std.process.exit(1);
    }
    const id = args[2];

    const to_agent = getFlagValue(args, "--to");
    const note_text = getFlagValue(args, "--note");

    if (to_agent == null) {
        w.diag("error: --to <agent> is required\n", .{});
        std.process.exit(1);
    }
    if (note_text) |nt| {
        if (nt.len > 4096) {
            w.diag("error: --note is 4 KiB max (got {d} bytes)\n", .{nt.len});
            std.process.exit(1);
        }
    }

    var state = try readState(io, state_path);

    const ts_ptr = state.getPtr(id) orelse {
        w.diag("error: task '{s}' not found\n", .{id});
        std.process.exit(1);
    };

    if (ts_ptr.status == .done) {
        w.diag("warning: {s} is already done; recording the dispatch anyway\n", .{id});
    }
    if (ts_ptr.status == .in_progress) {
        w.diag("warning: {s} is already in progress (by {s}); recording the dispatch anyway\n", .{ id, ts_ptr.agent orelse "unknown" });
    }

    const now = try nowTimestamp();

    if (ts_ptr.dispatched) |d| alloc.free(d);
    if (ts_ptr.dispatched_to) |d| alloc.free(d);
    if (ts_ptr.note) |n| alloc.free(n);
    ts_ptr.dispatched = try alloc.dupe(u8, now);
    ts_ptr.dispatched_to = try alloc.dupe(u8, to_agent.?);
    if (note_text) |nt| {
        ts_ptr.note = try alloc.dupe(u8, nt);
    } else {
        ts_ptr.note = null;
    }

    try writeState(io, state_path, &state);

    w.diag("\n  dispatched {s}  to {s}  [set: {c}]\n", .{ id, to_agent.?, ts_ptr.set });
    if (ts_ptr.status == .dispatchable) {
        w.diag("  awaiting claim by {s} (or another agent): managent claim {s}\n", .{ to_agent.?, id });
    }
    if (note_text != null) {
        w.diag("  note recorded ({d} bytes)\n", .{note_text.?.len});
    }
}

fn cmdDone(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    _ = repo_root;
    if (args.len < 3) {
        w.diag("usage: managent done <id> [--fail] [--agent <name>]\n", .{});
        std.process.exit(1);
    }
    const id = args[2];
    const is_fail = hasFlag(args, "--fail");
    const agent_override = getFlagValue(args, "--agent");

    var state = try readState(io, state_path);

    const ts_ptr = state.getPtr(id) orelse {
        w.diag("error: task '{s}' not found\n", .{id});
        std.process.exit(1);
    };

    if (ts_ptr.status != .in_progress) {
        w.diag("error: task '{s}' is not in progress (status: {s})\n", .{ id, statusToString(ts_ptr.status) });
        std.process.exit(1);
    }

    // ── attribution enforcement (ORCHA-AUTOMATION item 3) ──
    if (agent_override) |a| {
        if (ts_ptr.agent) |old| alloc.free(old);
        ts_ptr.agent = try alloc.dupe(u8, a);
    }
    if (ts_ptr.agent == null and !is_fail) {
        w.diag("\n  REJECTED: {s} has no agent set.\n", .{id});
        w.diag("  Every completed task must be attributed to a worker for the model-performance ledger.\n", .{});
        w.diag("  Use: managent done {s} --agent <worker>\n", .{id});
        w.diag("  Or set it first: managent agent {s} <worker>\n", .{id});
        std.process.exit(1);
    }

    const now = try nowTimestamp();

    if (is_fail) {
        ts_ptr.status = .failed;
        ts_ptr.done = now;
        try writeState(io, state_path, &state);
        w.diag("\n  {s} failed  [set: {c}]\n", .{ id, ts_ptr.set });
    } else {
        ts_ptr.status = .done;
        ts_ptr.done = now;

        var unblocked = std.ArrayList([]const u8).empty;
        defer unblocked.deinit(alloc);

        var it = state.iterator();
        while (it.next()) |entry| {
            const dep_ts = entry.value_ptr.*;
            if (dep_ts.status != .blocked) continue;

            if (deriveStatus(&state, dep_ts) == .dispatchable) {
                const dep_ptr = state.getPtr(entry.key_ptr.*).?;
                dep_ptr.status = .dispatchable;
                try unblocked.append(alloc, entry.key_ptr.*);
            }
        }

        try writeState(io, state_path, &state);

        w.diag("\n  {s} done  [set: {c}]", .{ id, ts_ptr.set });
        if (unblocked.items.len > 0) {
            w.diag("  [unblocks:", .{});
            for (unblocked.items) |ub| {
                w.diag(" {s}", .{ub});
            }
            w.diag("]\n", .{});
        } else {
            w.diag("\n", .{});
        }
    }
}

fn cmdReopen(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    _ = repo_root;
    if (args.len < 3) {
        w.diag("usage: managent reopen <id>\n", .{});
        std.process.exit(1);
    }
    const id = args[2];

    var state = try readState(io, state_path);

    const ts_ptr = state.getPtr(id) orelse {
        w.diag("error: task '{s}' not found\n", .{id});
        std.process.exit(1);
    };

    const prev = ts_ptr.status;
    if (prev != .in_progress and prev != .failed) {
        w.diag("error: task '{s}' is {s} (reopen is for in_progress/failed tasks killed mid-attempt)\n", .{ id, statusToString(prev) });
        std.process.exit(1);
    }

    ts_ptr.status = if (needsMet(&state, ts_ptr.*)) .dispatchable else .blocked;
    ts_ptr.agent = null;
    ts_ptr.claimed = null;
    ts_ptr.done = null;

    try writeState(io, state_path, &state);

    const prev_str: []const u8 = if (prev == .in_progress) "in_progress" else "failed";
    const status_str: []const u8 = statusToString(ts_ptr.status);
    w.diag("\n  reopened {s}  [set: {c}]  (was {s}, now {s})\n", .{ id, ts_ptr.set, prev_str, status_str });
    w.diag("  follow {s}\n", .{ts_ptr.bundle});
}

fn cmdPurge(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    _ = args;
    var state = try readState(io, state_path);

    // commit-before-purge guard (ORCHA-AUTOMATION item 6)
    // Check: any done/failed task holds paths not in git ls-files
    {
        const git_files = try runCommand(alloc, io, &.{ "git", "-C", repo_root, "ls-files" });
        defer alloc.free(git_files);
        var has_untracked = false;
        var it = state.iterator();
        while (it.next()) |entry| {
            const ts = entry.value_ptr.*;
            if (ts.status != .done and ts.status != .failed) continue;
            for (ts.holds) |h| {
                if (std.mem.indexOf(u8, git_files, h) == null) {
                    if (!has_untracked) {
                        w.diag("  REFUSED: some deliverables are not in git ls-files. Commit before purge:\n", .{});
                        has_untracked = true;
                    }
                    w.diag("    {s}: {s}\n", .{ entry.key_ptr.*, h });
                }
            }
        }
        if (has_untracked) {
            w.diag("\n", .{});
            std.process.exit(1);
        }
    }

    var purged = std.ArrayList([]const u8).empty;
    defer purged.deinit(alloc);
    {
        var it = state.iterator();
        while (it.next()) |entry| {
            const st = entry.value_ptr.*.status;
            if (st == .done or st == .failed) try purged.append(alloc, entry.key_ptr.*);
        }
    }

    if (purged.items.len == 0) {
        w.diag("\n  nothing to purge (no done/failed tasks)\n", .{});
        return;
    }

    var cleaned = std.ArrayList([]const u8).empty;
    defer cleaned.deinit(alloc);
    {
        var it = state.iterator();
        while (it.next()) |entry| {
            const ts_ptr = entry.value_ptr;
            if (ts_ptr.needs.len == 0) continue;
            var kept = std.ArrayList([]const u8).empty;
            var removed_any = false;
            for (ts_ptr.needs) |n| {
                var is_purged = false;
                for (purged.items) |p| {
                    if (std.mem.eql(u8, n, p)) {
                        is_purged = true;
                        break;
                    }
                }
                if (!is_purged) {
                    try kept.append(alloc, n);
                } else {
                    removed_any = true;
                }
            }
            if (removed_any) {
                ts_ptr.needs = try kept.toOwnedSlice(alloc);
                try cleaned.append(alloc, entry.key_ptr.*);
            } else {
                kept.deinit(alloc);
            }
        }
    }

    for (purged.items) |p| {
        _ = state.remove(p);
    }

    try writeState(io, state_path, &state);

    w.diag("\n  purged {d} task(s):", .{purged.items.len});
    for (purged.items) |p| w.diag(" {s}", .{p});
    w.diag("\n", .{});
    if (cleaned.items.len > 0) {
        w.diag("  cleaned needs of:", .{});
        for (cleaned.items) |c| w.diag(" {s}", .{c});
        w.diag("\n", .{});
    }
}

fn cmdSet(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    _ = repo_root;
    if (args.len < 4 or args[3].len == 0) {
        w.diag("usage: managent set <id> <A|B|C|…>\n", .{});
        std.process.exit(1);
    }
    const id = args[2];
    const new_set = args[3][0];
    if (new_set < 'A' or new_set > 'Z') {
        w.diag("error: set must be an uppercase letter A–Z, got '{c}'\n", .{new_set});
        std.process.exit(1);
    }
    var state = try readState(io, state_path);
    const ts_ptr = state.getPtr(id) orelse {
        w.diag("error: task '{s}' not found\n", .{id});
        std.process.exit(1);
    };
    const old_set = ts_ptr.set;
    ts_ptr.set = new_set;
    try writeState(io, state_path, &state);
    w.diag("\n  {s}  set {c} -> {c}\n", .{ id, old_set, new_set });
}

fn cmdNeeds(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    _ = repo_root;
    if (args.len < 3) {
        w.diag("usage: managent needs <id> [--add <dep>...] [--rm <dep>...]\n", .{});
        std.process.exit(1);
    }
    const id = args[2];
    var added = std.ArrayList([]const u8).empty;
    defer added.deinit(alloc);
    var removed = std.ArrayList([]const u8).empty;
    defer removed.deinit(alloc);

    // Collect all --add and --rm values
    {
        var i: usize = 3;
        while (i < args.len) : (i += 1) {
            if (std.mem.eql(u8, args[i], "--add")) {
                i += 1;
                while (i < args.len and !std.mem.startsWith(u8, args[i], "-")) : (i += 1) {
                    try added.append(alloc, args[i]);
                }
                if (i < args.len) i -= 1;
            } else if (std.mem.eql(u8, args[i], "--rm")) {
                i += 1;
                while (i < args.len and !std.mem.startsWith(u8, args[i], "-")) : (i += 1) {
                    try removed.append(alloc, args[i]);
                }
                if (i < args.len) i -= 1;
            }
        }
    }

    if (added.items.len == 0 and removed.items.len == 0) {
        w.diag("error: give at least one --add or --rm\n", .{});
        std.process.exit(1);
    }
    var state = try readState(io, state_path);
    const ts_ptr = state.getPtr(id) orelse {
        w.diag("error: task '{s}' not found\n", .{id});
        std.process.exit(1);
    };
    var newneeds = std.ArrayList([]const u8).empty;
    defer newneeds.deinit(alloc);
    for (ts_ptr.needs) |n| {
        var is_removed = false;
        for (removed.items) |r| {
            if (std.mem.eql(u8, n, r)) {
                is_removed = true;
                break;
            }
        }
        if (is_removed) continue;
        var dup = false;
        for (newneeds.items) |k| {
            if (std.mem.eql(u8, n, k)) {
                dup = true;
                break;
            }
        }
        if (!dup) try newneeds.append(alloc, n);
    }
    for (added.items) |a| {
        var dup = false;
        for (newneeds.items) |k| {
            if (std.mem.eql(u8, a, k)) {
                dup = true;
                break;
            }
        }
        if (!dup) try newneeds.append(alloc, a);
    }
    ts_ptr.needs = try newneeds.toOwnedSlice(alloc);

    const old_status = ts_ptr.status;
    const derived = deriveStatus(&state, ts_ptr.*);
    if (derived != old_status) {
        ts_ptr.status = derived;
    }

    try writeState(io, state_path, &state);

    const from_str = statusToString(old_status);
    const to_str = statusToString(derived);
    w.diag("\n  {s}  needs:", .{id});
    for (ts_ptr.needs) |n| w.diag(" {s}", .{n});
    if (ts_ptr.needs.len == 0) w.diag(" (none)", .{});
    if (derived != old_status) {
        w.diag("  [{s} -> {s}]\n", .{ from_str, to_str });
    } else {
        w.diag("  [{s}]\n", .{from_str});
    }
}

fn cmdAgent(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    _ = repo_root;
    if (args.len < 4) {
        w.diag("usage: managent agent <id> <name>\n", .{});
        std.process.exit(1);
    }
    const id = args[2];
    const name = args[3];
    var state = try readState(io, state_path);
    const ts_ptr = state.getPtr(id) orelse {
        w.diag("error: task '{s}' not found\n", .{id});
        std.process.exit(1);
    };
    const old = ts_ptr.agent;
    ts_ptr.agent = try alloc.dupe(u8, name);
    try writeState(io, state_path, &state);
    w.diag("\n  {s}  agent {s} -> {s}\n", .{ id, old orelse "(none)", name });
}

fn cmdStatus(w: Writers, io: std.Io, state_path: []const u8, repo_root: []const u8, args: [][]const u8) !void {
    const use_json = hasFlag(args, "--json");

    var state = try readState(io, state_path);
    defer freeState(&state);

    if (use_json) {
        try printStatusJson(w, &state, repo_root);
        return;
    }

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

    // ── stdout: the data ──
    printSection(w, "dispatchable", dispatchable.items, &state, repo_root);
    printSection(w, "in progress", in_progress.items, &state, repo_root);

    // ── stderr: warnings ──
    var warned = false;
    for (in_progress.items) |tid| {
        const ts = state.get(tid).?;
        if (!needsMet(&state, ts)) {
            if (!warned) {
                w.diag("  !! Unmet-dependency warnings (in_progress tasks):\n", .{});
                warned = true;
            }
            w.diag("     {s} in progress but needs", .{tid});
            for (ts.needs) |n| {
                const nts = state.get(n);
                const ns = if (nts) |ntsv| statusToString(ntsv.status) else "unknown";
                w.diag(" {s}={s}", .{ n, ns });
            }
            w.diag("\n", .{});
        }
    }
    if (warned) w.diag("\n", .{});

    printSection(w, "blocked", blocked.items, &state, repo_root);
    printSection(w, "done", done.items, &state, repo_root);
    printSection(w, "failed", failed.items, &state, repo_root);
    w.data("\n", .{});
}

fn printSection(w: Writers, label: []const u8, ids: []const []const u8, state: *StateMap, repo_root: []const u8) void {
    w.data("\n  {s} ({d})\n", .{ label, ids.len });
    if (ids.len == 0) {
        w.data("    -- none --\n", .{});
        return;
    }
    for (ids) |tid| {
        const ts = state.get(tid).?;
        const rel = bundleRel(ts.bundle, repo_root);
        w.data("    {s} set {c}", .{ tid, ts.set });
        if (ts.needs.len > 0) {
            w.data(", needs", .{});
            for (ts.needs) |n| w.data(" {s}", .{n});
        }
        if (ts.holds.len > 0) {
            w.data(", holds", .{});
            for (ts.holds) |h| w.data(" {s}", .{h});
        }
        if (ts.agent) |a| {
            w.data(", agent {s}", .{a});
        }
        if (ts.dispatched_to) |dt| {
            w.data(", dispatched {s}", .{dt});
        }
        w.data(": follow {s}\n", .{rel});
    }
}

fn printStatusJson(w: Writers, state: *StateMap, repo_root: []const u8) !void {
    w.data("[", .{});
    var it = state.iterator();
    var first = true;
    while (it.next()) |entry| {
        if (!first) w.data(",", .{});
        first = false;
        const ts = entry.value_ptr.*;
        const rel = bundleRel(ts.bundle, repo_root);
        w.data("\n  {{\"id\":\"{s}\",\"status\":\"{s}\",\"set\":\"{c}\",\"bundle\":\"{s}\"", .{
            entry.key_ptr.*, statusToString(ts.status), ts.set, rel,
        });
        if (ts.agent) |a| w.data(",\"agent\":\"{s}\"", .{a});
        if (ts.needs.len > 0) {
            w.data(",\"needs\":[", .{});
            for (ts.needs, 0..) |n, ni| {
                if (ni > 0) w.data(",", .{});
                w.data("\"{s}\"", .{n});
            }
            w.data("]", .{});
        }
        if (ts.holds.len > 0) {
            w.data(",\"holds\":[", .{});
            for (ts.holds, 0..) |h, hi| {
                if (hi > 0) w.data(",", .{});
                w.data("\"{s}\"", .{h});
            }
            w.data("]", .{});
        }
        if (ts.dispatched_to) |dt| w.data(",\"dispatched_to\":\"{s}\"", .{dt});
        w.data("}}", .{});
    }
    if (!first) w.data("\n", .{});
    w.data("]\n", .{});
}

fn cmdNext(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    const exec_prefix = getFlagValue(args, "--exec");

    var state = try readState(io, state_path);

    var candidate_id: ?[]const u8 = null;

    var it = state.iterator();
    while (it.next()) |entry| {
        const ts = entry.value_ptr.*;
        if (deriveStatus(&state, ts) != .dispatchable) continue;
        if (phaseGate(state, ts.set)) continue;
        if (holdsConflict(state, ts.holds, entry.key_ptr.*) != null) continue;
        candidate_id = entry.key_ptr.*;
        break;
    }

    if (candidate_id == null) return;

    const id = candidate_id.?;
    const ts_ptr = state.getPtr(id).?;

    const now = try nowTimestamp();
    ts_ptr.status = .in_progress;
    ts_ptr.claimed = now;

    try writeState(io, state_path, &state);

    w.diag("\n  claimed {s}  [set: {c}]\n", .{ id, ts_ptr.set });
    w.diag("  follow {s}\n", .{ts_ptr.bundle});

    if (exec_prefix) |prefix| {
        const rel = bundleRel(ts_ptr.bundle, repo_root);
        try execHarness(prefix, rel);
    }
}

fn cmdShow(w: Writers, io: std.Io, state_path: []const u8, args: [][]const u8) !void {
    if (args.len < 3) {
        w.diag("usage: managent show <id>\n", .{});
        std.process.exit(1);
    }
    const id = args[2];

    var state = try readState(io, state_path);
    defer freeState(&state);

    const ts = state.get(id) orelse {
        w.diag("error: task '{s}' not found\n", .{id});
        std.process.exit(1);
    };

    // ── stdout: the data ──
    w.data("\n", .{});
    w.data("  {s}  {s}\n", .{ id, statusToString(ts.status) });
    w.data("    bundle:   {s}\n", .{ts.bundle});
    w.data("    set:      {c}\n", .{ts.set});
    if (ts.holds.len > 0) {
        w.data("    holds:    ", .{});
        for (ts.holds, 0..) |h, j| {
            if (j > 0) w.data(" ", .{});
            w.data("{s}", .{h});
        }
        w.data("\n", .{});
    } else {
        w.data("    holds:    -- none --\n", .{});
    }
    w.data("    needs:    ", .{});
    if (ts.needs.len > 0) {
        for (ts.needs, 0..) |n, j| {
            if (j > 0) w.data(" ", .{});
            w.data("{s}", .{n});
        }
    } else {
        w.data("-- none --", .{});
    }
    w.data("\n", .{});

    if (ts.caps.len > 0) {
        w.data("    caps:     ", .{});
        for (ts.caps, 0..) |c, j| {
            if (j > 0) w.data(" ", .{});
            w.data("{s}", .{c});
        }
        w.data("\n", .{});
    }

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
    w.data("    needed by:", .{});
    if (needed_by.items.len > 0) {
        for (needed_by.items) |nb| {
            w.data(" {s}", .{nb});
        }
    } else {
        w.data(" -- none --", .{});
    }
    w.data("\n", .{});

    w.data("    added:    {s}\n", .{ts.added});
    if (ts.claimed) |c| {
        w.data("    claimed:  {s}\n", .{c});
    }
    if (ts.done) |d| {
        w.data("    done:     {s}\n", .{d});
    }
    if (ts.dispatched) |dp| {
        w.data("    dispatched: {s}", .{dp});
        if (ts.dispatched_to) |dt| w.data(" to {s}", .{dt});
        w.data("\n", .{});
    }
    if (ts.agent) |a| {
        w.data("    agent:    {s}\n", .{a});
    } else {
        w.data("    agent:    -- unset --\n", .{});
    }
    if (ts.note) |nt| {
        w.data("    note:     {s}\n", .{nt});
    }
    w.data("\n", .{});
}

fn cmdWhy(w: Writers, io: std.Io, state_path: []const u8, args: [][]const u8) !void {
    if (args.len < 3) {
        w.diag("usage: managent why <claim-id>\n", .{});
        std.process.exit(1);
    }
    const claim_id = args[2];

    var state = try readState(io, state_path);
    defer freeState(&state);

    // ── stdout: the data ──
    w.data("\n  Tasks touching claim '{s}':\n", .{claim_id});

    var found = false;
    var it = state.iterator();
    while (it.next()) |entry| {
        const ts = entry.value_ptr.*;
        const tid = entry.key_ptr.*;

        const bundle_rel = bundleRel(ts.bundle, "");
        var mentions = false;
        if (std.mem.indexOf(u8, bundle_rel, claim_id) != null) mentions = true;
        if (!mentions and ts.note != null) {
            if (std.mem.indexOf(u8, ts.note.?, claim_id) != null) mentions = true;
        }
        if (!mentions and std.mem.indexOf(u8, tid, claim_id) != null) mentions = true;

        if (mentions) {
            found = true;
            const rel = bundleRel(ts.bundle, "");
            w.data("    {s}  [{s}]", .{ tid, statusToString(ts.status) });
            if (ts.agent) |a| w.data("  agent: {s}", .{a});
            w.data("\n      bundle: {s}\n", .{rel});
            if (ts.done) |d| w.data("      done: {s}\n", .{d});
        }
    }

    if (!found) {
        w.data("    -- no tasks reference this claim --\n", .{});
    }
    w.data("\n", .{});
}

fn printHelp(w: Writers) void {
    w.diag(
        \\managent — agent-manager CLI
        \\
        \\Usage:
        \\  managent                  show current state (default)
        \\  managent status [--json]  show current state (--json for machine output)
        \\  managent add <id>         register a task from untracked/<id>-*.md
        \\  managent dispatch <id>    record a human→agent dispatch (task stays dispatchable)
        \\  managent claim <id>       claim a task for execution
        \\  managent done <id>        mark a task complete
        \\  managent done <id> --fail mark a task failed
        \\  managent next             claim the next available task
        \\  managent show <id>        show details for one task
        \\  managent why <claim-id>   show tasks that produced evidence for a claim
        \\  managent sync <role>      print unread messages; exit non-zero when write owed
        \\  managent audit [--json]   cross-check kanban against reality
        \\  managent standing         register triggered standing-tier tasks
        \\  managent help             show this help
        \\
        \\Options:
        \\  --agent <name>           label who claimed (with claim / done)
        \\  --to <agent>             agent the task is dispatched to (with dispatch)
        \\  --note <text>            free-form context, ≤4 KiB (with dispatch / add)
        \\  --bundle <path>          override bundle path (with add)
        \\  --set <A|B|C>            override parallel set (with add)
        \\  --needs <id>             add extra dependency (with add)
        \\  --exec <prefix>          claim and exec into harness (with claim / next)
        \\  --json                   machine-readable output (with status / audit)
        \\  -h, --help               show this help
        \\
        \\Examples:
        \\  managent status --json | jq '.[] | select(.status=="blocked")'
        \\  managent audit 2>/dev/null  # see only discrepancies
        \\  managent next --exec "pi --provider deepseek --model deepseek-v4-pro"
        \\  managent claim B17 --exec "pi --provider ollama --model glm-5.2:cloud"
        \\
    , .{});
}

fn execHarness(prefix: []const u8, follow: []const u8) !void {
    const cmd = try std.fmt.allocPrint(alloc, "{s} -p \"follow {s}\"", .{ prefix, follow });
    defer alloc.free(cmd);

    const cmd_z = try alloc.allocSentinel(u8, cmd.len, 0);
    defer alloc.free(cmd_z);
    @memcpy(cmd_z, cmd);

    const sh = "/bin/sh";
    const argv: [3:null]?[*:0]const u8 = .{ sh, "-c", cmd_z };
    _ = std.c.execve(sh, &argv, std.c.environ);
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
        for (ts.caps) |c| alloc.free(c);
        alloc.free(ts.caps);
        alloc.free(ts.added);
        if (ts.claimed) |c| alloc.free(c);
        if (ts.done) |d| alloc.free(d);
        if (ts.dispatched) |dp| alloc.free(dp);
        if (ts.dispatched_to) |dt| alloc.free(dt);
        if (ts.note) |nt| alloc.free(nt);
    }
    state.deinit(alloc);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ORCHA-AUTOMATION new commands
// ═══════════════════════════════════════════════════════════════════════════════

// ── 1. sync <role> — message-bus sync ───────────────────────────────────────

fn cmdSync(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    if (args.len < 3) {
        w.diag("usage: managent sync <role>\n", .{});
        std.process.exit(1);
    }
    const role = args[2];

    // Scan message directories
    const msg_dir = try std.fs.path.join(alloc, &.{ repo_root, "untracked", "msg" });
    defer alloc.free(msg_dir);

    var msg_root = std.Io.Dir.cwd().openDir(io, msg_dir, .{}) catch |err| {
        if (err == error.FileNotFound) {
            w.data("no messages yet\n", .{});
            _ = std.c._exit(0);
        }
        return err;
    };
    defer msg_root.close(io);

    const MessageFile = struct {
        num: u32,
        from: []const u8,
        to: []const u8,
        path: []const u8,
        subj: []const u8,
    };

    var messages = std.ArrayList(MessageFile).empty;
    defer {
        for (messages.items) |m| {
            alloc.free(m.from);
            alloc.free(m.to);
            alloc.free(m.path);
            alloc.free(m.subj);
        }
        messages.deinit(alloc);
    }

    var milestone_iter = msg_root.iterate();
    while (try milestone_iter.next(io)) |milestone_entry| {
        if (milestone_entry.kind != .directory) continue;

        var ms_dir = try msg_root.openDir(io, milestone_entry.name, .{});
        defer ms_dir.close(io);

        var file_iter = ms_dir.iterate();
        while (try file_iter.next(io)) |file_entry| {
            if (file_entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, file_entry.name, ".md")) continue;

            // Parse NNN-from-to-rest.md
            const name = file_entry.name;
            const first_dash = std.mem.indexOfScalar(u8, name, '-') orelse continue;
            const num_str = name[0..first_dash];
            const num = std.fmt.parseInt(u32, num_str, 10) catch continue;

            const after_num = name[first_dash + 1 ..];
            const second_dash = std.mem.indexOfScalar(u8, after_num, '-') orelse continue;
            const from = after_num[0..second_dash];

            const after_from = after_num[second_dash + 1 ..];
            const third_dash = std.mem.indexOfScalar(u8, after_from, '-') orelse continue;
            const to = after_from[0..third_dash];

            const full_path = try std.fs.path.join(alloc, &.{ msg_dir, milestone_entry.name, name });

            // Extract subject from first heading line
            var subj: []const u8 = "";
            const content = std.Io.Dir.cwd().readFileAlloc(io, full_path, alloc, .unlimited) catch "";
            if (content.len > 0) {
                defer alloc.free(content);
                var lines = std.mem.splitScalar(u8, content, '\n');
                if (lines.next()) |first_line| {
                    const trimmed = std.mem.trim(u8, first_line, "# \t\r");
                    if (std.mem.indexOfScalar(u8, trimmed, ' ')) |space_idx| {
                        const after_space = std.mem.trim(u8, trimmed[space_idx..], " —- \t\r");
                        if (after_space.len > 0) {
                            subj = try alloc.dupe(u8, after_space);
                        }
                    }
                    if (subj.len == 0) {
                        subj = try alloc.dupe(u8, trimmed);
                    }
                }
            } else {
                subj = try alloc.dupe(u8, name);
            }

            try messages.append(alloc, MessageFile{
                .num = num,
                .from = try alloc.dupe(u8, from),
                .to = try alloc.dupe(u8, to),
                .path = full_path,
                .subj = subj,
            });
        }
    }

    // Sort by message number
    std.mem.sort(MessageFile, messages.items, {}, struct {
        fn lt(_: void, a: MessageFile, b: MessageFile) bool {
            return a.num < b.num;
        }
    }.lt);

    // Find unread messages addressed to role or "all"
    const sync_data = try readSyncData(io, state_path);
    const role_lower = try normalizeRole(role);
    const last_read: u32 = if (sync_data.get(role_lower)) |rs| rs.last_read_msg else 0;

    // ── stdout: inbox ──
    var unread_count: u32 = 0;
    var max_num: u32 = 0;
    var last_role_post: u32 = 0;
    w.data("\n  INBOX for '{s}' (unread messages):\n", .{role});
    for (messages.items) |m| {
        if (m.num > max_num) max_num = m.num;

        const from_lower = try normalizeRole(m.from);
        const to_lower = try normalizeRole(m.to);
        const is_addressed = std.mem.eql(u8, to_lower, role_lower) or
            std.mem.eql(u8, to_lower, "all");

        if (is_addressed and m.num > last_read) {
            unread_count += 1;
            w.data("    M{d:0>3}  from {s}  to {s}\n", .{ m.num, m.from, m.to });
            w.data("           {s}\n", .{m.subj});
        }

        // Track last message this role posted
        if (std.mem.eql(u8, from_lower, role_lower)) {
            last_role_post = m.num;
        }
    }
    if (unread_count == 0) {
        w.data("    -- none --\n", .{});
    }

    // ── stdout: last posted + gap ──
    w.data("\n  LAST POSTED by '{s}': M{d}\n", .{ role, last_role_post });

    const gap_threshold: u32 = 5;
    const events_since = if (last_role_post > 0) max_num - last_role_post else max_num;

    // ── exit non-zero when gap exceeds threshold or there are unread ──
    if (unread_count > 0 or events_since > gap_threshold) {
        w.diag("  SYNC: {d} unread, {d} events since last post — you owe a write.\n", .{ unread_count, events_since });
        std.process.exit(1);
    }

    // Update read state
    {
        var st = try readState(io, state_path);
        const new_rs = RoleSync{
            .last_read_msg = max_num,
            .last_posted_msg = last_role_post,
            .last_event_gen = getEventGen(&st),
        };
        try writeSyncData(io, state_path, &st, role_lower, new_rs);
        freeState(&st);
    }

    w.data("\n", .{});
}

fn normalizeRole(role: []const u8) ![]const u8 {
    var buf: [128]u8 = undefined;
    const lower = std.ascii.lowerString(&buf, role);
    return alloc.dupe(u8, lower);
}

fn readSyncData(io: std.Io, state_path: []const u8) !std.StringHashMapUnmanaged(RoleSync) {
    var result = std.StringHashMapUnmanaged(RoleSync){};

    const content = std.Io.Dir.cwd().readFileAlloc(io, state_path, alloc, .unlimited) catch |err| {
        if (err == error.FileNotFound) return result;
        return err;
    };
    defer alloc.free(content);

    const trimmed = std.mem.trim(u8, content, " \t\n\r");
    if (trimmed.len == 0 or std.mem.eql(u8, trimmed, "{}")) return result;

    var parsed = try std.json.parseFromSlice(std.json.Value, alloc, content, .{ .allocate = .alloc_always });
    defer parsed.deinit();

    if (parsed.value != .object) return result;

    if (parsed.value.object.get("_sync")) |sync_val| {
        if (sync_val == .object) {
            var sync_it = sync_val.object.iterator();
            while (sync_it.next()) |entry| {
                const r = try alloc.dupe(u8, entry.key_ptr.*);
                const obj = entry.value_ptr.*;
                if (obj != .object) continue;

                var rs = RoleSync{};
                if (obj.object.get("last_read_msg")) |v| {
                    if (v == .integer) rs.last_read_msg = @intCast(v.integer);
                }
                if (obj.object.get("last_posted_msg")) |v| {
                    if (v == .integer) rs.last_posted_msg = @intCast(v.integer);
                }
                if (obj.object.get("last_event_gen")) |v| {
                    if (v == .integer) rs.last_event_gen = @intCast(v.integer);
                }
                try result.put(alloc, r, rs);
            }
        }
    }

    return result;
}

fn writeSyncData(io: std.Io, state_path: []const u8, state: *StateMap, role: []const u8, rs: RoleSync) !void {
    // Persist sync data by amending the raw JSON.
    // Read current file, inject the _sync key, write back.
    const content = std.Io.Dir.cwd().readFileAlloc(io, state_path, alloc, .unlimited) catch {
        // No file yet — just write the state as-is; sync data lives in memory.
        return;
    };
    defer alloc.free(content);

    const trimmed = std.mem.trim(u8, content, " \t\n\r");
    if (trimmed.len < 2) return;

    // Build the new JSON with _sync key inserted
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(alloc);

    // Content is "{...}". Insert _sync before the closing "}".
    // Also merge with existing _sync if present.
    const sync_json = try std.fmt.allocPrint(alloc,
        \\"_sync": {{"{s}": {{"last_read_msg":{d},"last_posted_msg":{d},"last_event_gen":{d}}}}}
    , .{ role, rs.last_read_msg, rs.last_posted_msg, rs.last_event_gen });
    defer alloc.free(sync_json);

    // Simple approach: insert _sync before the closing brace
    if (trimmed.len > 2 and trimmed[trimmed.len - 1] == '}') {
        // Strip trailing whitespace before the closing }
        var end = trimmed.len - 1;
        while (end > 0 and (trimmed[end - 1] == ' ' or trimmed[end - 1] == '\n' or trimmed[end - 1] == '\r' or trimmed[end - 1] == '\t')) {
            end -= 1;
        }
        try buf.appendSlice(alloc, trimmed[0..end]);
        try buf.appendSlice(alloc, ",\n  ");
        try buf.appendSlice(alloc, sync_json);
        try buf.appendSlice(alloc, "\n}\n");
    } else {
        try buf.appendSlice(alloc, trimmed);
    }

    // Write atomically
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

    const state_dir = try std.Io.Dir.cwd().openDir(io, dirname, .{});
    defer state_dir.close(io);
    state_dir.rename(tmp_name, state_dir, basename, io) catch {};

    _ = state; // state is already persisted; we're just adding sync metadata
}

fn getEventGen(state: *StateMap) u64 {
    var count: u64 = 0;
    var it = state.iterator();
    while (it.next()) |_| {
        count += 1;
    }
    return count;
}

// ── 2. audit — cross-check kanban against reality ───────────────────────────

fn cmdAudit(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    const use_json = hasFlag(args, "--json");

    var state = try readState(io, state_path);
    defer freeState(&state);

    // Collect git ls-files for checking deliverables
    var git_files = std.ArrayList([]const u8).empty;
    defer {
        for (git_files.items) |f| alloc.free(f);
        git_files.deinit(alloc);
    }
    {
        const git_result = try runCommand(alloc, io, &.{ "git", "-C", repo_root, "ls-files" });
        defer alloc.free(git_result);
        var lines = std.mem.splitScalar(u8, git_result, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len > 0) {
                try git_files.append(alloc, try alloc.dupe(u8, trimmed));
            }
        }
    }

    // Collect git ls-files --others --exclude-standard for untracked files
    var untracked_files = std.ArrayList([]const u8).empty;
    defer {
        for (untracked_files.items) |f| alloc.free(f);
        untracked_files.deinit(alloc);
    }
    {
        const untracked_result = try runCommand(alloc, io, &.{ "git", "-C", repo_root, "ls-files", "--others", "--exclude-standard" });
        defer alloc.free(untracked_result);
        var lines = std.mem.splitScalar(u8, untracked_result, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (trimmed.len > 0) {
                try untracked_files.append(alloc, try alloc.dupe(u8, trimmed));
            }
        }
    }

    const Finding = struct {
        level: []const u8,
        id: []const u8,
        msg: []const u8,
    };

    var findings = std.ArrayList(Finding).empty;
    defer {
        for (findings.items) |f| {
            alloc.free(f.level);
            alloc.free(f.msg);
        }
        findings.deinit(alloc);
    }

    var it = state.iterator();
    while (it.next()) |entry| {
        const tid = entry.key_ptr.*;
        const ts = entry.value_ptr.*;

        // ── cross-status checks (apply regardless of status) ──

        // A. in_progress or done but needs not met → claimed over an unmet gate
        if (ts.status == .in_progress or ts.status == .done) {
            if (!needsMet(&state, ts)) {
                var unmet_list = std.ArrayList(u8).empty;
                defer unmet_list.deinit(alloc);
                for (ts.needs) |n| {
                    const nts = state.get(n);
                    const ns = if (nts) |ntsv| statusToString(ntsv.status) else "unknown";
                    if (!std.mem.eql(u8, ns, "done")) {
                        if (unmet_list.items.len > 0) try unmet_list.appendSlice(alloc, ", ");
                        try unmet_list.appendSlice(alloc, n);
                        try unmet_list.appendSlice(alloc, "=");
                        try unmet_list.appendSlice(alloc, ns);
                    }
                }
                const msg = try std.fmt.allocPrint(alloc, "{s} but needs not met: {s} — gate it (claimed over unmet dependency)", .{ statusToString(ts.status), unmet_list.items });
                try findings.append(alloc, .{ .level = "FIX", .id = tid, .msg = msg });
            }
            // Also check retroactively: claimed before dependency completed
            if (ts.claimed != null and needsMet(&state, ts)) {
                for (ts.needs) |n| {
                    const nts = state.get(n);
                    if (nts) |need_ts| {
                        if (need_ts.done != null and ts.claimed != null) {
                            if (std.mem.lessThan(u8, ts.claimed.?, need_ts.done.?)) {
                                const msg = try std.fmt.allocPrint(alloc, "{s}: claimed ({s}) before dependency {s} was done ({s}) — gated claim", .{ statusToString(ts.status), ts.claimed.?, n, need_ts.done.? });
                                try findings.append(alloc, .{ .level = "WARN", .id = tid, .msg = msg });
                                break;
                            }
                        }
                    }
                }
            }
        }

        // B. done task with claimed == null → completed without ever being claimed
        if (ts.status == .done and ts.claimed == null) {
            const msg = try std.fmt.allocPrint(alloc, "done but never claimed — audit trail broken", .{});
            try findings.append(alloc, .{ .level = "FIX", .id = tid, .msg = msg });
        }

        // C. in_progress task with note containing GATED → was blocked by hand
        if (ts.status == .in_progress and ts.note != null) {
            if (std.mem.indexOf(u8, ts.note.?, "GATED") != null) {
                const msg = try std.fmt.allocPrint(alloc, "in_progress but note says GATED — verify premise is still valid", .{});
                try findings.append(alloc, .{ .level = "WARN", .id = tid, .msg = msg });
            }
        }

        switch (ts.status) {
            .done => {
                // 1. done task with agent == null → attribute it
                if (ts.agent == null) {
                    const msg = try std.fmt.allocPrint(alloc, "done but agent is unset — attribute it: managent agent {s} <worker>", .{tid});
                    try findings.append(alloc, .{ .level = "FIX", .id = tid, .msg = msg });
                }

                // 2. done task whose holds paths are not in git ls-files → commit these
                for (ts.holds) |h| {
                    var found_in_git = false;
                    for (git_files.items) |gf| {
                        if (std.mem.eql(u8, gf, h)) {
                            found_in_git = true;
                            break;
                        }
                    }
                    if (!found_in_git) {
                        // Check if it's untracked (in working tree at least)
                        var found_untracked = false;
                        for (untracked_files.items) |uf| {
                            if (std.mem.eql(u8, uf, h)) {
                                found_untracked = true;
                                break;
                            }
                        }
                        if (found_untracked) {
                            const msg = try std.fmt.allocPrint(alloc, "holds '{s}' is untracked — git add and commit", .{h});
                            try findings.append(alloc, .{ .level = "FIX", .id = tid, .msg = msg });
                        } else {
                            const msg = try std.fmt.allocPrint(alloc, "holds '{s}' not in git ls-files — commit these", .{h});
                            try findings.append(alloc, .{ .level = "FIX", .id = tid, .msg = msg });
                        }
                    }
                }
            },
            .in_progress => {
                // 3. in_progress: protect untracked src/*.zig held by this task
                for (ts.holds) |h| {
                    if (std.mem.startsWith(u8, h, "src/") and std.mem.endsWith(u8, h, ".zig")) {
                        var is_untracked = false;
                        for (untracked_files.items) |uf| {
                            if (std.mem.eql(u8, uf, h)) {
                                is_untracked = true;
                                break;
                            }
                        }
                        if (is_untracked) {
                            const msg = try std.fmt.allocPrint(alloc, "holds untracked source '{s}' — snapshot before git clean -x destroys it", .{h});
                            try findings.append(alloc, .{ .level = "WARN", .id = tid, .msg = msg });
                        }
                    }
                }
            },
            .dispatchable => {
                // 4. dispatchable but needs not met → gate it
                if (!needsMet(&state, ts)) {
                    const msg = try std.fmt.allocPrint(alloc, "dispatchable but needs not met (should be blocked) — gate it", .{});
                    try findings.append(alloc, .{ .level = "FIX", .id = tid, .msg = msg });
                }
            },
            .blocked => {
                // 5. blocked but all needs met → should be dispatchable
                if (needsMet(&state, ts)) {
                    const msg = try std.fmt.allocPrint(alloc, "blocked but all needs met — should be dispatchable", .{});
                    try findings.append(alloc, .{ .level = "WARN", .id = tid, .msg = msg });
                }
            },
            .failed => {},
        }

        // 6. task note references claim-status change with no second seat cited
        if (ts.note) |note| {
            if (std.mem.indexOf(u8, note, "CLAIM") != null or
                std.mem.indexOf(u8, note, "claim") != null)
            {
                if (std.mem.indexOf(u8, note, "second seat") == null and
                    std.mem.indexOf(u8, note, "audit") == null)
                {
                    const msg = try std.fmt.allocPrint(alloc, "claim-status change noted but no independent seat cited", .{});
                    try findings.append(alloc, .{ .level = "WARN", .id = tid, .msg = msg });
                }
            }
        }
    }

    // ── §6 guards: cross-file checks ──

    // 7. Rebuilt managent? cp it — warn if zig-out/bin/managent newer than bin/managent
    {
        const zig_out = try std.fs.path.join(alloc, &.{ repo_root, "zig-out", "bin", "managent" });
        defer alloc.free(zig_out);
        const bin_mg = try std.fs.path.join(alloc, &.{ repo_root, "bin", "managent" });
        defer alloc.free(bin_mg);

        const stat_zig = std.Io.Dir.cwd().statFile(io, zig_out, .{}) catch null;
        const stat_bin = std.Io.Dir.cwd().statFile(io, bin_mg, .{}) catch null;
        if (stat_zig != null and stat_bin != null) {
            if (stat_zig.?.mtime.nanoseconds > stat_bin.?.mtime.nanoseconds) {
                const msg = try std.fmt.allocPrint(alloc, "zig-out/bin/managent is newer than bin/managent — cp it", .{});
                try findings.append(alloc, .{ .level = "WARN", .id = "(managent)", .msg = msg });
            }
        }
    }

    // 8. git diff --name-only on CLAIMS.md: flag edits citing no second seat
    {
        const diff_result = try runCommand(alloc, io, &.{ "git", "-C", repo_root, "diff", "--name-only", "docs/epistemic/CLAIMS.md" });
        defer alloc.free(diff_result);
        const diff_trimmed = std.mem.trim(u8, diff_result, " \t\n\r");
        if (diff_trimmed.len > 0) {
            // CLAIMS.md has uncommitted changes — check if commit message (via git log) cites a second seat
            const log_result = try runCommand(alloc, io, &.{ "git", "-C", repo_root, "log", "-1", "--format=%s" });
            defer alloc.free(log_result);
            if (std.mem.indexOf(u8, log_result, "2B-") == null and
                std.mem.indexOf(u8, log_result, "AUDIT") == null and
                std.mem.indexOf(u8, log_result, "audit") == null and
                std.mem.indexOf(u8, log_result, "second seat") == null and
                std.mem.indexOf(u8, log_result, "independent") == null)
            {
                const msg = try std.fmt.allocPrint(alloc, "CLAIMS.md has uncommitted changes but last commit cites no second seat — verify before commit", .{});
                try findings.append(alloc, .{ .level = "WARN", .id = "CLAIMS.md", .msg = msg });
            }
        }
    }

    if (use_json) {
        w.data("[\n", .{});
        for (findings.items, 0..) |f, fi| {
            if (fi > 0) w.data(",\n", .{});
            w.data("  {{\"level\":\"{s}\",\"id\":\"{s}\",\"msg\":\"{s}\"}}", .{ f.level, f.id, f.msg });
        }
        if (findings.items.len > 0) w.data("\n", .{});
        w.data("]\n", .{});
    } else {
        if (findings.items.len == 0) {
            w.data("\n  audit: clean — no discrepancies found\n\n", .{});
        } else {
            w.data("\n  audit: {d} finding(s):\n", .{findings.items.len});
            for (findings.items) |f| {
                w.data("    [{s}] {s}: {s}\n", .{ f.level, f.id, f.msg });
            }
            w.data("\n", .{});
        }
    }

    // Exit non-zero when FIX-level findings exist
    for (findings.items) |f| {
        if (std.mem.eql(u8, f.level, "FIX")) {
            std.process.exit(1);
        }
    }
}

// ── 3. standing — register triggered standing-tier tasks ────────────────────

const Standing = struct {
    id: []const u8,
    set: u8,
    needs: []const []const u8,
    brief_path: []const u8,
};

const standing_templates = [_]Standing{
    .{ .id = "STANDING-HOLISTIC-AUDIT", .set = 'H', .needs = &.{}, .brief_path = "docs/infra/dispatch/STANDING-HOLISTIC-AUDIT.md" },
    .{ .id = "STANDING-CLEANUP",        .set = 'H', .needs = &.{}, .brief_path = "docs/infra/dispatch/STANDING-CLEANUP.md" },
    .{ .id = "STANDING-REEVIDENCE",     .set = 'H', .needs = &.{}, .brief_path = "docs/infra/dispatch/STANDING-REEVIDENCE.md" },
    .{ .id = "STANDING-CONSOLIDATE",    .set = 'H', .needs = &.{}, .brief_path = "docs/infra/dispatch/STANDING-CONSOLIDATE.md" },
};

fn cmdStanding(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    _ = args;

    var state = try readState(io, state_path);

    // ── detect triggers ──

    // Trigger 1: claimlint C3 debt (for STANDING-REEVIDENCE)
    var c3_debt: u64 = 0;
    var c3_prior: u64 = 0;
    const claimlint_result = try runCommand(alloc, io, &.{ "bin/weizigo-claimlint" });
    defer alloc.free(claimlint_result);
    {
        const c3_marker = "C3: ";
        var lines = std.mem.splitScalar(u8, claimlint_result, '\n');
        while (lines.next()) |line| {
            if (std.mem.indexOf(u8, line, c3_marker)) |idx| {
                const after = line[idx + c3_marker.len ..];
                c3_debt = std.fmt.parseInt(u64, std.mem.trim(u8, after, " \t\r"), 10) catch 0;
                break;
            }
        }
    }

    // Read prior C3 debt from _standing metadata
    {
        const content = std.Io.Dir.cwd().readFileAlloc(io, state_path, alloc, .unlimited) catch "";
        defer alloc.free(content);
        if (content.len > 0) {
            const trimmed = std.mem.trim(u8, content, " \t\n\r");
            if (trimmed.len > 2) {
                var parsed = try std.json.parseFromSlice(std.json.Value, alloc, content, .{ .allocate = .alloc_always });
                defer parsed.deinit();
                if (parsed.value == .object) {
                    if (parsed.value.object.get("_standing")) |st_val| {
                        if (st_val == .object) {
                            if (st_val.object.get("c3_debt")) |c3v| {
                                if (c3v == .integer) c3_prior = @intCast(c3v.integer);
                            }
                        }
                    }
                }
            }
        }
    }

    // Trigger 2: milestone shape — count message directories
    var msg_count: u64 = 0;
    var msg_prior: u64 = 0;
    {
        const msg_dir = try std.fs.path.join(alloc, &.{ repo_root, "untracked", "msg" });
        defer alloc.free(msg_dir);
        var msg_root = std.Io.Dir.cwd().openDir(io, msg_dir, .{}) catch null;
        if (msg_root) |*dir| {
            defer dir.close(io);
            var iter = dir.iterate();
            while (try iter.next(io)) |entry| {
                if (entry.kind == .directory) msg_count += 1;
            }
        }
    }
    // Read prior from _standing
    {
        const content = std.Io.Dir.cwd().readFileAlloc(io, state_path, alloc, .unlimited) catch "";
        defer alloc.free(content);
        if (content.len > 2) {
            var parsed = try std.json.parseFromSlice(std.json.Value, alloc, content, .{ .allocate = .alloc_always });
            defer parsed.deinit();
            if (parsed.value == .object) {
                if (parsed.value.object.get("_standing")) |st_val| {
                    if (st_val == .object) {
                        if (st_val.object.get("msg_count")) |mc| {
                            if (mc == .integer) msg_prior = @intCast(mc.integer);
                        }
                    }
                }
            }
        }
    }

    // Trigger 3: falsifications — count FALSE-AS-SCOPED in CLAIMS.md
    var false_count: u64 = 0;
    var false_prior: u64 = 0;
    {
        const claims_path = try std.fs.path.join(alloc, &.{ repo_root, "docs", "epistemic", "CLAIMS.md" });
        defer alloc.free(claims_path);
        const claims_content = std.Io.Dir.cwd().readFileAlloc(io, claims_path, alloc, .unlimited) catch "";
        defer alloc.free(claims_content);
        var clines = std.mem.splitScalar(u8, claims_content, '\n');
        while (clines.next()) |line| {
            if (std.mem.indexOf(u8, line, "FALSE-AS-SCOPED") != null) false_count += 1;
        }
    }
    {
        const content = std.Io.Dir.cwd().readFileAlloc(io, state_path, alloc, .unlimited) catch "";
        defer alloc.free(content);
        if (content.len > 2) {
            var parsed = try std.json.parseFromSlice(std.json.Value, alloc, content, .{ .allocate = .alloc_always });
            defer parsed.deinit();
            if (parsed.value == .object) {
                if (parsed.value.object.get("_standing")) |st_val| {
                    if (st_val == .object) {
                        if (st_val.object.get("false_count")) |fc| {
                            if (fc == .integer) false_prior = @intCast(fc.integer);
                        }
                    }
                }
            }
        }
    }

    // Trigger 4: tree dirty — git diff --stat line count
    var dirty_files: u64 = 0;
    var dirty_prior: u64 = 0;
    {
        const diff_result = try runCommand(alloc, io, &.{ "git", "-C", repo_root, "diff", "--stat" });
        defer alloc.free(diff_result);
        var dlines = std.mem.splitScalar(u8, diff_result, '\n');
        while (dlines.next()) |_| {
            dirty_files += 1;
        }
        if (dirty_files > 0) dirty_files -= 1; // last line is summary
    }
    {
        const content = std.Io.Dir.cwd().readFileAlloc(io, state_path, alloc, .unlimited) catch "";
        defer alloc.free(content);
        if (content.len > 2) {
            var parsed = try std.json.parseFromSlice(std.json.Value, alloc, content, .{ .allocate = .alloc_always });
            defer parsed.deinit();
            if (parsed.value == .object) {
                if (parsed.value.object.get("_standing")) |st_val| {
                    if (st_val == .object) {
                        if (st_val.object.get("dirty_files")) |df| {
                            if (df == .integer) dirty_prior = @intCast(df.integer);
                        }
                    }
                }
            }
        }
    }

    // ── evaluate triggers and register ──

    w.data("\n  Standing-tier triggers:\n", .{});

    // STANDING-HOLISTIC-AUDIT: trigger when milestone shape changes (msg dir count differs)
    {
        const triggered = msg_count != msg_prior and msg_prior > 0;
        w.data("    STANDING-HOLISTIC-AUDIT  msg dirs: {d} (was {d})", .{ msg_count, msg_prior });
        if (triggered) {
            w.data(" [TRIGGERED — milestone shape changed]", .{});
            try registerStanding(w, io, repo_root, state_path, &state, "STANDING-HOLISTIC-AUDIT", "milestone shape changed: msg dirs {d}→{d}", .{ msg_prior, msg_count });
        }
        w.data("\n", .{});
    }

    // STANDING-CLEANUP: trigger when tree dirty across two turns (dirty > 0, prior was also > 0)
    {
        const triggered = dirty_files > 0 and dirty_prior > 0;
        w.data("    STANDING-CLEANUP         dirty files: {d} (was {d})", .{ dirty_files, dirty_prior });
        if (triggered) {
            w.data(" [TRIGGERED — tree dirty across two turns]", .{});
            try registerStanding(w, io, repo_root, state_path, &state, "STANDING-CLEANUP", "tree dirty across two turns: {d}→{d} dirty files", .{ dirty_prior, dirty_files });
        }
        w.data("\n", .{});
    }

    // STANDING-REEVIDENCE: trigger when C3 debt grows
    {
        const triggered = c3_debt > c3_prior and c3_prior > 0;
        w.data("    STANDING-REEVIDENCE      C3 debt: {d} (was {d})", .{ c3_debt, c3_prior });
        if (triggered) {
            w.data(" [TRIGGERED — C3 debt grew]", .{});
            try registerStanding(w, io, repo_root, state_path, &state, "STANDING-REEVIDENCE", "C3 debt grew: {d}→{d}", .{ c3_prior, c3_debt });
        }
        w.data("\n", .{});
    }

    // STANDING-CONSOLIDATE: trigger when falsification count grows
    {
        const triggered = false_count > false_prior and false_prior > 0;
        w.data("    STANDING-CONSOLIDATE     FALSE-AS-SCOPED: {d} (was {d})", .{ false_count, false_prior });
        if (triggered) {
            w.data(" [TRIGGERED — new falsification]", .{});
            try registerStanding(w, io, repo_root, state_path, &state, "STANDING-CONSOLIDATE", "falsification count grew: {d}→{d}", .{ false_prior, false_count });
        }
        w.data("\n", .{});
    }

    // ── persist current trigger state ──
    try persistStandingState(io, state_path, c3_debt, msg_count, false_count, dirty_files);

    // ── show registered standing tasks ──
    w.data("\n  Registered standing tasks:\n", .{});
    for (standing_templates) |st| {
        if (state.contains(st.id)) {
            const st_ts = state.get(st.id).?;
            w.data("    {s}: {s}", .{ st.id, statusToString(st_ts.status) });
            if (st_ts.note) |n| w.data("  ({s})", .{n});
            w.data("\n", .{});
        } else {
            w.data("    {s}: not yet registered\n", .{st.id});
        }
    }
    w.data("\n", .{});
}

fn registerStanding(
    w: Writers,
    io: std.Io,
    repo_root: []const u8,
    state_path: []const u8,
    state: *StateMap,
    id: []const u8,
    comptime note_fmt: []const u8,
    note_args: anytype,
) !void {
    if (state.contains(id)) {
        w.diag("      (already registered, skipping)\n", .{});
        return;
    }

    // Find or create the brief path
    const brief_path = try std.fs.path.join(alloc, &.{ repo_root, "docs", "infra", "dispatch", id });
    const brief_md = try std.fmt.allocPrint(alloc, "{s}.md", .{brief_path});
    defer alloc.free(brief_path);
    defer alloc.free(brief_md);

    // Create brief file if it doesn't exist
    const brief_exists = std.Io.Dir.cwd().statFile(io, brief_md, .{}) catch null;
    if (brief_exists == null) {
        var file = try std.Io.Dir.cwd().createFile(io, brief_md, .{});
        defer file.close(io);
        const meta_line = try std.fmt.allocPrint(alloc, "<!--managent set=H-->\n", .{});
        defer alloc.free(meta_line);
        try file.writeStreamingAll(io, meta_line);
        const body = try std.fmt.allocPrint(alloc, "# {s}\n\nAuto-registered standing task.\n", .{id});
        defer alloc.free(body);
        try file.writeStreamingAll(io, body);
    }

    // Register the task
    const now = try nowTimestamp();
    const note = try std.fmt.allocPrint(alloc, note_fmt, note_args);
    const ts = TaskState{
        .status = .dispatchable,
        .agent = null,
        .bundle = brief_md,
        .set = 'H',
        .holds = &.{},
        .needs = &.{},
        .caps = &.{},
        .added = now,
        .claimed = null,
        .done = null,
        .dispatched = null,
        .dispatched_to = null,
        .note = note,
    };
    try state.put(alloc, try alloc.dupe(u8, id), ts);
    try writeState(io, state_path, state);
    w.data("\n      registered {s} [set: H] [dispatchable]", .{id});
}

fn persistStandingState(io: std.Io, state_path: []const u8, c3: u64, msg: u64, false_cnt: u64, dirty: u64) !void {
    const content = std.Io.Dir.cwd().readFileAlloc(io, state_path, alloc, .unlimited) catch return;
    defer alloc.free(content);

    const trimmed = std.mem.trim(u8, content, " \t\n\r");
    if (trimmed.len < 2) return;

    // Remove existing _standing key if present (naive: find and skip it)
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(alloc);

    // Insert _standing before closing }
    const standing_json = try std.fmt.allocPrint(alloc,
        \\"_standing": {{"c3_debt":{d},"msg_count":{d},"false_count":{d},"dirty_files":{d}}}
    , .{ c3, msg, false_cnt, dirty });
    defer alloc.free(standing_json);

    if (trimmed.len > 2 and trimmed[trimmed.len - 1] == '}') {
        var end = trimmed.len - 1;
        while (end > 0 and (trimmed[end - 1] == ' ' or trimmed[end - 1] == '\n' or trimmed[end - 1] == '\r' or trimmed[end - 1] == '\t')) {
            end -= 1;
        }
        try buf.appendSlice(alloc, trimmed[0..end]);
        // Check if _standing already exists
        if (std.mem.indexOf(u8, trimmed[0..end], "\"_standing\"")) |_| {
            // Already have _standing — skip rewrite to avoid corruption
            return;
        }
        try buf.appendSlice(alloc, ",\n  ");
        try buf.appendSlice(alloc, standing_json);
        try buf.appendSlice(alloc, "\n}\n");
    } else {
        try buf.appendSlice(alloc, trimmed);
        return;
    }

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

    const state_dir = try std.Io.Dir.cwd().openDir(io, dirname, .{});
    defer state_dir.close(io);
    state_dir.rename(tmp_name, state_dir, basename, io) catch {};
}

// ── run a command and capture stdout ────────────────────────────────────────

fn runCommand(allocator: std.mem.Allocator, io: std.Io, argv: []const []const u8) ![]const u8 {
    const result = try std.process.run(allocator, io, .{
        .argv = argv,
    });
    return result.stdout;
}
