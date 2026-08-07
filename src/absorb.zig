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
// ABSORB — read a findings JSON file, compare against CLAIMS.md, emit edit
// directives.
//
// This is the mechanical half of knowledge-capture absorption (R3). It reads
// a findings JSON file, parses the CLAIMS.md register, and outputs JSON-Lines
// edit directives to stdout. The Orchestrator reviews and ratifies — this tool
// never writes CLAIMS.md directly.
//
// usage: weizigo-absorb <findings.json> [--dry-run]
//
// Output: JSON-Lines to stdout, one directive per line.
// Appends one line to untracked/absorption.md (unless --dry-run).

const std = @import("std");
const version = @import("version");
const cr = @import("claims_register.zig");
const util = @import("util.zig");
const Allocator = std.mem.Allocator;
const Io = std.Io;

const ABSORPTION_LOG = "untracked/absorption.md";
const CLAIMS_PATH = "docs/epistemic/CLAIMS.md";

/// Walk up from cwd to find the repo root (contains .git).
fn findRepoRoot(io: Io) ![]const u8 {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const cwd = std.c.getcwd(&buf, buf.len) orelse return error.CwdTooLong;
    const cwd_slice = std.mem.sliceTo(cwd, 0);

    var current: []const u8 = cwd_slice;
    while (true) {
        var dir = try Io.Dir.openDirAbsolute(io, current, .{});
        defer dir.close(io);

        if (dir.access(io, ".git", .{})) |_| {
            return std.heap.page_allocator.dupe(u8, current);
        } else |_| {}

        const parent = std.fs.path.dirname(current) orelse {
            return error.NoGitRepo;
        };
        if (std.mem.eql(u8, parent, current)) {
            return error.NoGitRepo;
        }
        current = parent;
    }
}

// ── findings model ──────────────────────────────────────────────────────────

const FindingClaim = struct {
    id: []const u8,
    proposed_status: []const u8,
    rationale: []const u8,
    evidence_path: []const u8,
};

const NewRow = struct {
    id: []const u8,
    legacy: []const u8,
    goban: []const u8,
    claim: []const u8,
    status: []const u8,
    evidence: []const u8,
    depends_on: []const u8,
    narrowed: []const u8,
    wrong_answer_pass_rate: []const u8,
};

const Finding = struct {
    task_id: []const u8,
    date: []const u8,
    model: []const u8,
    claims: std.ArrayList(FindingClaim),
    new_rows: std.ArrayList(NewRow),
    notes: []const u8,
};

// ── JSON parsing ────────────────────────────────────────────────────────────

fn jsonStringValue(gpa: Allocator, json: []const u8, key: []const u8, out: *std.ArrayList(u8)) !bool {
    out.clearRetainingCapacity();
    var i: usize = 0;
    while (i < json.len) {
        if (json[i] != '"') { i += 1; continue; }
        const key_start = i + 1;
        const key_end = std.mem.indexOfScalarPos(u8, json, key_start, '"') orelse return false;
        const found_key = json[key_start..key_end];
        i = key_end + 1;
        while (i < json.len and (json[i] == ' ' or json[i] == '\t' or json[i] == '\n' or json[i] == '\r')) : (i += 1) {}
        if (i >= json.len or json[i] != ':') continue;
        i += 1;
        while (i < json.len and (json[i] == ' ' or json[i] == '\t' or json[i] == '\n' or json[i] == '\r')) : (i += 1) {}
        if (i >= json.len) return false;
        if (!std.mem.eql(u8, found_key, key)) continue;
        if (json[i] != '"') return false;
        i += 1;
        while (i < json.len) {
            if (json[i] == '\\' and i + 1 < json.len) {
                try out.append(gpa, json[i + 1]);
                i += 2;
                continue;
            }
            if (json[i] == '"') {
                i += 1;
                return true;
            }
            try out.append(gpa, json[i]);
            i += 1;
        }
        return false;
    }
    return false;
}

fn parseFindingsJson(gpa: Allocator, json: []const u8) !Finding {
    var f: Finding = .{
        .task_id = "",
        .date = "",
        .model = "",
        .claims = .empty,
        .new_rows = .empty,
        .notes = "",
    };

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(gpa);

    if (try jsonStringValue(gpa, json, "task_id", &buf)) {
        f.task_id = try gpa.dupe(u8, buf.items);
    }
    if (try jsonStringValue(gpa, json, "date", &buf)) {
        f.date = try gpa.dupe(u8, buf.items);
    }
    if (try jsonStringValue(gpa, json, "model", &buf)) {
        f.model = try gpa.dupe(u8, buf.items);
    }
    if (try jsonStringValue(gpa, json, "notes", &buf)) {
        f.notes = try gpa.dupe(u8, buf.items);
    }

    // Parse claims[] array
    var i: usize = 0;
    while (i < json.len) : (i += 1) {
        if (json[i] != '"') continue;
        const ks = i + 1;
        const ke = std.mem.indexOfScalarPos(u8, json, ks, '"') orelse break;
        const k = json[ks..ke];
        i = ke + 1;
        if (!std.mem.eql(u8, k, "claims")) continue;
        // skip to opening [
        while (i < json.len and json[i] != '[') : (i += 1) {}
        if (i >= json.len) break;
        i += 1; // past [
        // iterate objects in claims[]
        while (i < json.len) : (i += 1) {
            if (json[i] == ']') break;
            if (json[i] != '{') continue;
            var cid_buf: std.ArrayList(u8) = .empty;
            defer cid_buf.deinit(gpa);
            var status_buf: std.ArrayList(u8) = .empty;
            defer status_buf.deinit(gpa);
            var rationale_buf: std.ArrayList(u8) = .empty;
            defer rationale_buf.deinit(gpa);
            var ev_buf: std.ArrayList(u8) = .empty;
            defer ev_buf.deinit(gpa);
            var depth: usize = 1;
            i += 1; // past {
            while (i < json.len and depth > 0) : (i += 1) {
                if (json[i] == '{') depth += 1;
                if (json[i] == '}') {
                    depth -= 1;
                    if (depth == 0) break;
                }
                if (json[i] != '"') continue;
                const fks = i + 1;
                const fke = std.mem.indexOfScalarPos(u8, json, fks, '"') orelse break;
                const fk = json[fks..fke];
                i = fke + 1;
                while (i < json.len and (json[i] == ' ' or json[i] == '\t' or json[i] == '\n' or json[i] == '\r' or json[i] == ':')) : (i += 1) {}
                if (i >= json.len or json[i] != '"') continue;
                i += 1;
                var fb: *std.ArrayList(u8) = undefined;
                if (std.mem.eql(u8, fk, "id")) fb = &cid_buf
                else if (std.mem.eql(u8, fk, "proposed_status")) fb = &status_buf
                else if (std.mem.eql(u8, fk, "rationale")) fb = &rationale_buf
                else if (std.mem.eql(u8, fk, "evidence_path")) fb = &ev_buf;
                // fb was assigned only for known fields; skip unknown ones
                const is_known = std.mem.eql(u8, fk, "id") or std.mem.eql(u8, fk, "proposed_status") or std.mem.eql(u8, fk, "rationale") or std.mem.eql(u8, fk, "evidence_path");
                if (!is_known) {
                    // skip this string value
                    while (i < json.len) {
                        if (json[i] == '\\' and i + 1 < json.len) {
                            i += 2;
                            continue;
                        }
                        if (json[i] == '"') break;
                        i += 1;
                    }
                    continue;
                }
                while (i < json.len) {
                    if (json[i] == '\\' and i + 1 < json.len) {
                        try fb.append(gpa, json[i + 1]);
                        i += 2;
                        continue;
                    }
                    if (json[i] == '"') break;
                    try fb.append(gpa, json[i]);
                    i += 1;
                }
            }
            if (cid_buf.items.len > 0) {
                try f.claims.append(gpa, .{
                    .id = try gpa.dupe(u8, cid_buf.items),
                    .proposed_status = try gpa.dupe(u8, status_buf.items),
                    .rationale = try gpa.dupe(u8, rationale_buf.items),
                    .evidence_path = try gpa.dupe(u8, ev_buf.items),
                });
            }
        }
        break;
    }

    // Parse new_rows[] array
    i = 0;
    while (i < json.len) : (i += 1) {
        if (json[i] != '"') continue;
        const ks = i + 1;
        const ke = std.mem.indexOfScalarPos(u8, json, ks, '"') orelse break;
        const k = json[ks..ke];
        i = ke + 1;
        if (!std.mem.eql(u8, k, "new_rows")) continue;
        while (i < json.len and json[i] != '[') : (i += 1) {}
        if (i >= json.len) break;
        i += 1;
        while (i < json.len) : (i += 1) {
            if (json[i] == ']') break;
            if (json[i] != '{') continue;
            var nr: [9]std.ArrayList(u8) = undefined;
            const nr_keys = [_][]const u8{ "id", "legacy", "goban", "claim", "status", "evidence", "depends_on", "narrowed", "wrong_answer_pass_rate" };
            for (&nr) |*b| b.* = .empty;
            defer for (&nr) |*b| b.deinit(gpa);
            var depth: usize = 1;
            i += 1;
            while (i < json.len and depth > 0) : (i += 1) {
                if (json[i] == '{') depth += 1;
                if (json[i] == '}') {
                    depth -= 1;
                    if (depth == 0) break;
                }
                if (json[i] != '"') continue;
                const fks = i + 1;
                const fke = std.mem.indexOfScalarPos(u8, json, fks, '"') orelse break;
                const fk = json[fks..fke];
                i = fke + 1;
                while (i < json.len and (json[i] == ' ' or json[i] == '\t' or json[i] == '\n' or json[i] == '\r' or json[i] == ':')) : (i += 1) {}
                if (i >= json.len) continue;
                var field_idx: ?usize = null;
                for (nr_keys, 0..) |nk, ni| {
                    if (std.mem.eql(u8, fk, nk)) { field_idx = ni; break; }
                }
                const fi = field_idx orelse {
                    // skip unknown field value
                    if (json[i] == '"') {
                        i += 1;
                        while (i < json.len) {
                            if (json[i] == '\\' and i + 1 < json.len) { i += 2; continue; }
                            if (json[i] == '"') break;
                            i += 1;
                        }
                    } else if (json[i] == '-' or std.ascii.isDigit(json[i])) {
                        // numeric value, skip to next comma or }
                        while (i < json.len and json[i] != ',' and json[i] != '}') : (i += 1) {}
                    }
                    continue;
                };
                if (json[i] == '"') {
                    i += 1;
                    const fb = &nr[fi];
                    while (i < json.len) {
                        if (json[i] == '\\' and i + 1 < json.len) {
                            try fb.append(gpa, json[i + 1]);
                            i += 2;
                            continue;
                        }
                        if (json[i] == '"') break;
                        try fb.append(gpa, json[i]);
                        i += 1;
                    }
                } else if (json[i] == '-' or std.ascii.isDigit(json[i])) {
                    // numeric field (narrowed)
                    const start = i;
                    while (i < json.len and (std.ascii.isDigit(json[i]) or json[i] == '-')) : (i += 1) {}
                    const fb = &nr[fi];
                    try fb.appendSlice(gpa, json[start..i]);
                }
            }
            if (nr[0].items.len > 0) {
                try f.new_rows.append(gpa, .{
                    .id = try gpa.dupe(u8, nr[0].items),
                    .legacy = try gpa.dupe(u8, nr[1].items),
                    .goban = try gpa.dupe(u8, nr[2].items),
                    .claim = try gpa.dupe(u8, nr[3].items),
                    .status = try gpa.dupe(u8, nr[4].items),
                    .evidence = try gpa.dupe(u8, nr[5].items),
                    .depends_on = try gpa.dupe(u8, nr[6].items),
                    .narrowed = try gpa.dupe(u8, nr[7].items),
                    .wrong_answer_pass_rate = try gpa.dupe(u8, nr[8].items),
                });
            }
        }
        break;
    }

    return f;
}

// ── directive emission ─────────────────────────────────────────────────────

fn emitEditStatus(gpa: Allocator, claim_id: []const u8, current_status: []const u8, proposed_status: []const u8, line: usize, old_cell: []const u8, new_cell: []const u8) ![]const u8 {
    var buf: std.ArrayList(u8) = .empty;
    try buf.appendSlice(gpa, "{\"directive\":\"edit_status\",\"claim_id\":\"");
    try appendJsonString(gpa, &buf, claim_id);
    try buf.appendSlice(gpa, "\",\"current_status\":\"");
    try appendJsonString(gpa, &buf, current_status);
    try buf.appendSlice(gpa, "\",\"proposed_status\":\"");
    try appendJsonString(gpa, &buf, proposed_status);
    try buf.appendSlice(gpa, "\",\"line\":");
    const line_str = try std.fmt.allocPrint(gpa, "{d}", .{line});
    try buf.appendSlice(gpa, line_str);
    try buf.appendSlice(gpa, ",\"old_cell_text\":\"");
    try appendJsonString(gpa, &buf, old_cell);
    try buf.appendSlice(gpa, "\",\"new_cell_text\":\"");
    try appendJsonString(gpa, &buf, new_cell);
    try buf.appendSlice(gpa, "\"}");
    return buf.toOwnedSlice(gpa);
}

fn emitAddRow(gpa: Allocator, nr: NewRow, insert_after: []const u8, section: []const u8) ![]const u8 {
    // T406: the register is 11 columns (the `tree` column, T305, C9-gated).
    // The findings schema carries no tree field, so the emitted row carries
    // the TREE-ASSIGN placeholder: the Orchestrator must map the row onto
    // the requirement tree (register-tree-map.md §1) before ratifying — a
    // bare 10-column row would be unparseable by claimlint ("expected 11
    // columns, found 10"). The directive names the obligation in its own
    // `tree` field so the placeholder cannot be mistaken for a value.
    const row_text = try std.fmt.allocPrint(gpa,
        "| `{s}` | {s} | {s} | {s} | {s} | {s} | {s} | — | {s} | {s} | TREE-ASSIGN |",
        .{ nr.id, nr.legacy, nr.goban, nr.claim, nr.status, nr.evidence, nr.depends_on, nr.narrowed, nr.wrong_answer_pass_rate },
    );
    var buf: std.ArrayList(u8) = .empty;
    try buf.appendSlice(gpa, "{\"directive\":\"add_row\",\"claim_id\":\"");
    try appendJsonString(gpa, &buf, nr.id);
    try buf.appendSlice(gpa, "\",\"insert_after\":\"");
    try appendJsonString(gpa, &buf, insert_after);
    try buf.appendSlice(gpa, "\",\"section\":\"");
    try appendJsonString(gpa, &buf, section);
    try buf.appendSlice(gpa, "\",\"row_text\":\"");
    try appendJsonString(gpa, &buf, row_text);
    try buf.appendSlice(gpa, "\",\"tree\":\"TREE-ASSIGN — assign a node from register-tree-map.md §1 (C9-gated); the findings schema carries no tree field\"}");
    return buf.toOwnedSlice(gpa);
}

fn emitNoop(gpa: Allocator, claim_id: []const u8, note: []const u8) ![]const u8 {
    var buf: std.ArrayList(u8) = .empty;
    try buf.appendSlice(gpa, "{\"directive\":\"noop\",\"claim_id\":\"");
    try appendJsonString(gpa, &buf, claim_id);
    try buf.appendSlice(gpa, "\",\"note\":\"");
    try appendJsonString(gpa, &buf, note);
    try buf.appendSlice(gpa, "\"}");
    return buf.toOwnedSlice(gpa);
}

/// Append a JSON-escaped string to a buffer.
fn appendJsonString(gpa: Allocator, buf: *std.ArrayList(u8), s: []const u8) !void {
    for (s) |c| {
        switch (c) {
            '"' => try buf.appendSlice(gpa, "\\\""),
            '\\' => try buf.appendSlice(gpa, "\\\\"),
            '\n' => try buf.appendSlice(gpa, "\\n"),
            '\r' => try buf.appendSlice(gpa, "\\r"),
            '\t' => try buf.appendSlice(gpa, "\\t"),
            else => try buf.append(gpa, c),
        }
    }
}

// ── status cell building ───────────────────────────────────────────────────

/// Given a proposed status and an existing status cell text (which may carry a
/// parenthetical qualifier), produce the new status cell text. The tool
/// replaces the status prefix and preserves any existing parenthetical
/// qualifier. If the existing cell has no qualifier, just the proposed status.
fn buildNewStatusCell(gpa: Allocator, proposed: []const u8, existing_raw: []const u8) ![]const u8 {
    const exist = cr.trim(existing_raw);
    // Does the existing cell have a parenthetical qualifier?
    const paren = std.mem.indexOfScalar(u8, exist, '(') orelse return proposed;
    // Only add the qualifier if it looks like a genuine status qualifier
    // (starts with "at", "as", a goban size, or a year)
    const qual = cr.trim(exist[paren..]);
    if (qual.len < 2) return proposed;
    return try std.fmt.allocPrint(gpa, "{s} {s}", .{ proposed, qual });
}

/// Extract the board/goban scope from a new-row and determine the CLAIMS.md
/// section to insert into. Returns a section name for the directive.
fn sectionForNewRow(nr: NewRow) []const u8 {
    _ = nr;
    return "2"; // All register rows are in §2
}

/// Determine the insertion point for a new row: after the last register row
/// with a matching board/goban value. Returns the claim ID to insert after.
fn insertAfterForNewRow(reg: *cr.Register, nr: NewRow) []const u8 {
    const target_board = cr.trim(nr.goban);
    var last_id: []const u8 = "";
    for (reg.rows.items) |r| {
        if (std.mem.eql(u8, cr.trim(r.board), target_board)) {
            last_id = r.id;
        }
    }
    if (last_id.len > 0) return last_id;
    // Fallback: last row in the whole register
    if (reg.rows.items.len > 0) return reg.rows.items[reg.rows.items.len - 1].id;
    return "GLOBAL.ADR0001-PROJECT";
}

// ── main ────────────────────────────────────────────────────────────────────

pub fn main(init: std.process.Init) !void {
    std.debug.print("{s}\n", .{version.banner("weizigo-absorb")});
    const gpa = std.heap.page_allocator;
    const io = init.io;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();

    var findings_path: ?[]const u8 = null;
    var dry_run = false;

    while (args.next()) |a| {
        if (std.mem.eql(u8, a, "--dry-run")) {
            dry_run = true;
        } else if (!std.mem.startsWith(u8, a, "--")) {
            findings_path = a;
        }
    }

    const fpath = findings_path orelse {
        util.note("usage: weizigo-absorb <findings.json> [--dry-run]\n", .{});
        std.process.exit(1);
    };

    // Find repo root and resolve paths relative to it
    const repo_root = findRepoRoot(io) catch {
        util.note("absorb: cannot find repo root (no .git found)\n", .{});
        std.process.exit(1);
    };
    defer gpa.free(repo_root);

    const claims_path = try std.fs.path.join(gpa, &.{ repo_root, CLAIMS_PATH });
    defer gpa.free(claims_path);
    const absorption_log = try std.fs.path.join(gpa, &.{ repo_root, ABSORPTION_LOG });
    defer gpa.free(absorption_log);

    // Read findings JSON — resolve relative paths against cwd (not repo root)
    const fpath_abs = if (std.fs.path.isAbsolute(fpath))
        try gpa.dupe(u8, fpath)
    else blk: {
        var cwd_buf: [std.fs.max_path_bytes]u8 = undefined;
        const cwd_ptr = std.c.getcwd(&cwd_buf, cwd_buf.len);
        if (cwd_ptr == null) break :blk try gpa.dupe(u8, fpath);
        break :blk try std.fs.path.join(gpa, &.{ std.mem.sliceTo(cwd_ptr.?, 0), fpath });
    };
    defer gpa.free(fpath_abs);

    const fjson = Io.Dir.cwd().readFileAlloc(io, fpath_abs, gpa, .unlimited) catch |e| {
        util.note("absorb: cannot read {s}: {s}\n", .{ fpath_abs, @errorName(e) });
        std.process.exit(1);
    };
    const finding = try parseFindingsJson(gpa, fjson);

    // Read CLAIMS.md
    const claims_text = Io.Dir.cwd().readFileAlloc(io, claims_path, gpa, .unlimited) catch |e| {
        util.note("absorb: cannot read {s}: {s}\n", .{ claims_path, @errorName(e) });
        std.process.exit(1);
    };
    var reg = try cr.parseRegister(gpa, claims_text);

    // T406: an empty parse is a HARD error, never "nothing to do". The old
    // parser returned 0 rows from the 11-column register and silently
    // reported the backlog as clear — the tool reported success while doing
    // nothing. A register that exists, is non-empty, and yields 0 rows (or
    // whose header does not match the canonical 11-column format) is a file
    // the tool does not understand; refuse loudly with the counts.
    util.note("absorb: parsed {d} rows from CLAIMS.md\n", .{reg.rows.items.len});
    if (reg.rows.items.len == 0 or !reg.format_ok) {
        util.note("absorb: FATAL — parsed 0 rows from CLAIMS.md; register file is {d} bytes\n", .{claims_text.len});
        if (reg.header_cols == 0) {
            util.note("  no §2 header row found inside the register\n", .{});
        } else if (reg.format_ok) {
            util.note("  the §2 header is valid but carries no data rows — the register is empty\n", .{});
        } else {
            util.note("  register header carries {d} columns, expected {d} (the tree column format, T305)\n", .{ reg.header_cols, cr.REGISTER_COLS });
        }
        if (reg.unparsed.items.len > 0) {
            util.note("  first parse complaint(s):\n", .{});
            for (reg.unparsed.items[0..@min(reg.unparsed.items.len, 3)]) |u| {
                util.note("    {s}\n", .{u});
            }
        }
        util.note("  refusing to report 'nothing to do' from a register it could not understand\n", .{});
        std.process.exit(1);
    }
    if (reg.unparsed.items.len > 0) {
        // Partial drift: some rows were skipped; claims on those rows will
        // read as "not found". Loud but not fatal — the register may be
        // mid-edit. This is the non-silent half of the same discipline.
        util.note("absorb: {d} register row(s) unparseable — claims on those rows will read as 'not found'\n", .{reg.unparsed.items.len});
        for (reg.unparsed.items[0..@min(reg.unparsed.items.len, 3)]) |u| {
            util.note("    {s}\n", .{u});
        }
    }

    // Build output lines, emit via util.out for stdout discipline.
    var out_lines: std.ArrayList([]const u8) = .empty;
    defer out_lines.deinit(gpa);

    var edit_count: usize = 0;

    // Process claim status changes
    for (finding.claims.items) |fc| {
        const slot = reg.by_id.get(fc.id) orelse {
            try out_lines.append(gpa, try emitNoop(gpa, fc.id, try std.fmt.allocPrint(gpa,
                "claim ID `{s}` not found in register — use new_rows for new claims", .{fc.id})));
            continue;
        };
        const row = reg.rows.items[slot];
        const ps = cr.parseStatusFromJson(fc.proposed_status);
        if (ps == .unparsed) {
            try out_lines.append(gpa, try emitNoop(gpa, fc.id, try std.fmt.allocPrint(gpa,
                "unrecognised proposed status `{s}`", .{fc.proposed_status})));
            continue;
        }
        if (ps == row.status) {
            try out_lines.append(gpa, try emitNoop(gpa, fc.id, try std.fmt.allocPrint(gpa,
                "register already reflects proposed status {s}", .{fc.proposed_status})));
            continue;
        }
        // Status mismatch — emit edit directive
        const old_cell = try cr.statusCellAt(gpa, claims_text, row.line) orelse row.status_raw;
        const new_cell = try buildNewStatusCell(gpa, fc.proposed_status, old_cell);
        try out_lines.append(gpa, try emitEditStatus(gpa, fc.id, row.status.name(), fc.proposed_status, row.line, old_cell, new_cell));
        edit_count += 1;
    }

    // Process new rows
    for (finding.new_rows.items) |nr| {
        if (reg.by_id.get(nr.id)) |slot| {
            const row = reg.rows.items[slot];
            const nps = cr.parseStatusFromJson(nr.status);
            if (nps != .unparsed and nps != row.status) {
                const old_cell = try cr.statusCellAt(gpa, claims_text, row.line) orelse row.status_raw;
                const new_cell = try buildNewStatusCell(gpa, nr.status, old_cell);
                try out_lines.append(gpa, try emitEditStatus(gpa, nr.id, row.status.name(), nr.status, row.line, old_cell, new_cell));
                edit_count += 1;
            } else {
                try out_lines.append(gpa, try emitNoop(gpa, nr.id, try std.fmt.allocPrint(gpa,
                    "new-row already in register with matching status {s}", .{nr.status})));
            }
        } else {
            const insert_after = insertAfterForNewRow(&reg, nr);
            const section = sectionForNewRow(nr);
            try out_lines.append(gpa, try emitAddRow(gpa, nr, insert_after, section));
            edit_count += 1;
        }
    }

    for (out_lines.items) |line| {
        util.out("{s}\n", .{line});
    }

    // Append to absorption log (unless dry-run or no edits)
    if (!dry_run and edit_count > 0) {
        // Build the list of claim IDs
        var id_list: std.ArrayList(u8) = .empty;
        defer id_list.deinit(gpa);
        for (finding.claims.items, 0..) |fc, j| {
            if (j > 0) try id_list.append(gpa, ' ');
            try id_list.appendSlice(gpa, fc.id);
        }
        for (finding.new_rows.items) |nr| {
            if (id_list.items.len > 0) try id_list.append(gpa, ' ');
            try id_list.appendSlice(gpa, nr.id);
        }

        const today = try todayIso(gpa);
        const log_line = try std.fmt.allocPrint(gpa, "{s} {s} {s} {s} CLAIMS:yes model-perf:no\n", .{
            finding.task_id,
            today,
            finding.model,
            id_list.items,
        });

        // Append to untracked/absorption.md — read existing, rewrite with new line
        const existing = Io.Dir.cwd().readFileAlloc(io, absorption_log, gpa, .unlimited) catch "";
        const combined = try std.fmt.allocPrint(gpa, "{s}{s}", .{ existing, log_line });
        try Io.Dir.cwd().writeFile(io, .{ .sub_path = absorption_log, .data = combined });
    }
}

extern "c" fn time(t: ?*i64) i64;
extern "c" fn gmtime_r(t: *const i64, tm: *Tm) ?*Tm;

const Tm = extern struct {
    tm_sec: i32,
    tm_min: i32,
    tm_hour: i32,
    tm_mday: i32,
    tm_mon: i32,
    tm_year: i32,
    tm_wday: i32,
    tm_yday: i32,
    tm_isdst: i32,
};

/// Return today's date in ISO format YYYY-MM-DD.
/// Only called when there are edits to log; a convenience, not load-bearing.
fn todayIso(gpa: Allocator) ![]const u8 {
    var now: i64 = undefined;
    _ = time(&now);
    var tm: Tm = undefined;
    if (gmtime_r(&now, &tm) == null) return "????-??-??";
    return try std.fmt.allocPrint(gpa, "{d:0>4}-{d:0>2}-{d:0>2}", .{
        @as(u32, @intCast(tm.tm_year + 1900)),
        @as(u32, @intCast(tm.tm_mon + 1)),
        @as(u32, @intCast(tm.tm_mday)),
    });
}
