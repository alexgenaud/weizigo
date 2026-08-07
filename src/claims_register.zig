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
// CLAIMS REGISTER — shared parser for docs/epistemic/CLAIMS.md §2.
//
// Used by claimlint (checker) and absorb (knowledge-capture tool). Extracted
// from claimlint.zig 2026-08-01 (T194/D5) so the absorption tool can read the
// register without duplicating the parser.
//
// Public API:
//   parseRegister(gpa, text) → Register
//   parseStatus(raw) → Status
//   isClaimIdToken(tok) → bool
//   claimIdOf(span) → ?[]const u8
//   isQaId(tok) → bool
//   trim(s) → []const u8

const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Status = enum {
    proven,
    claimed,
    false_as_scoped,
    false_flat,
    untested,
    intractable,
    measurement,
    definition,
    unparsed,

    pub fn isLive(s: Status) bool {
        return s == .proven or s == .claimed;
    }
    pub fn isFalse(s: Status) bool {
        return s == .false_as_scoped or s == .false_flat;
    }
    pub fn name(s: Status) []const u8 {
        return switch (s) {
            .proven => "PROVEN",
            .claimed => "CLAIMED",
            .false_as_scoped => "FALSE-AS-SCOPED",
            .false_flat => "FALSE",
            .untested => "UNTESTED",
            .intractable => "INTRACTABLE",
            .measurement => "MEASUREMENT",
            .definition => "(definition)",
            .unparsed => "??",
        };
    }
    /// Return the canonical JSON value for a status, exactly as it appears in
    /// findings JSON files and the findings schema.
    pub fn jsonName(s: Status) []const u8 {
        return s.name(); // same strings
    }
};

pub const EdgeKind = enum {
    derives,
    evidenced,
    negation,
};

pub const Edge = struct { kind: EdgeKind, target: []const u8 };

pub const Row = struct {
    id: []const u8,
    line: usize,
    board: []const u8,
    status: Status,
    status_raw: []const u8,
    evidence: []const u8,
    dependents: []const u8,
    deps: std.ArrayList(Edge),
    narrowed: ?u32,
    rate: ?f64,
    rate_raw: []const u8,
    tree: []const u8,
    in_degree: u32 = 0,
    refs_outside: u32 = 0,
};

pub const Register = struct {
    rows: std.ArrayList(Row),
    by_id: std.StringHashMap(usize),
    unparsed: std.ArrayList([]const u8),
    /// [start,end) line numbers (1-based) of the §2 region.
    sec2_start: usize = 0,
    sec2_end: usize = 0,
    /// Column count read from the §2 header row (the `| ID | ... |` line).
    /// 0 when no header row was found inside §2.
    header_cols: usize = 0,
    /// True when the register matches the canonical 11-column format (a
    /// header was found and header_cols == REGISTER_COLS). A register whose
    /// header is absent or carries a different column count is NOT
    /// understood — callers must refuse to report "nothing to do" from it
    /// (T406; the old hard-coded 10 parsed the 11-column register as empty).
    format_ok: bool = false,
};

// ── scope prefixes §1 of the register ──────────────────────────────────────

pub const SCOPES = [_][]const u8{
    "GLOBAL", "CODE", "2x2", "3x2", "3x3", "4x3", "4x4", "5x3", "5x4", "5x5", "6x3",
};

// ── path extension list ────────────────────────────────────────────────────

pub const PATH_EXT = [_][]const u8{
    ".md", ".zig", ".txt", ".py", ".cfg", ".sh", ".json", ".sgf", ".log",
    ".csv", ".toml", ".yml", ".yaml", ".wzo", ".reg", ".bak",
};

// ── string helpers ─────────────────────────────────────────────────────────

pub fn trim(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t\r\n");
}

pub fn endsWith(s: []const u8, suffix: []const u8) bool {
    return std.mem.endsWith(u8, s, suffix);
}

pub fn hasPathExt(s: []const u8) bool {
    for (PATH_EXT) |e| if (endsWith(s, e)) return true;
    return false;
}

/// Split a markdown table row on `|` that is not backslash-escaped.
pub fn splitCells(gpa: Allocator, line: []const u8) !std.ArrayList([]const u8) {
    var out: std.ArrayList([]const u8) = .empty;
    var start: usize = 0;
    var i: usize = 0;
    while (i < line.len) : (i += 1) {
        if (line[i] != '|') continue;
        if (i > 0 and line[i - 1] == '\\') continue;
        try out.append(gpa, line[start..i]);
        start = i + 1;
    }
    try out.append(gpa, line[start..]);
    return out;
}

// ── status parsing ─────────────────────────────────────────────────────────

pub fn parseStatus(raw: []const u8) Status {
    const s = trim(raw);
    if (s.len == 0) return .unparsed;
    if (std.mem.startsWith(u8, s, "FALSE-AS-SCOPED")) return .false_as_scoped;
    if (std.mem.startsWith(u8, s, "FALSE")) return .false_flat;
    if (std.mem.startsWith(u8, s, "PROVEN")) return .proven;
    if (std.mem.startsWith(u8, s, "CLAIMED")) return .claimed;
    if (std.mem.startsWith(u8, s, "UNTESTED")) return .untested;
    if (std.mem.startsWith(u8, s, "INTRACTABLE")) return .intractable;
    if (std.mem.startsWith(u8, s, "MEASUREMENT")) return .measurement;
    if (std.mem.startsWith(u8, s, "—")) return .definition;
    return .unparsed;
}

/// Parse a status string from JSON findings. Accepts the canonical names
/// exactly as they appear in the findings schema.
pub fn parseStatusFromJson(raw: []const u8) Status {
    const s = trim(raw);
    if (std.mem.eql(u8, s, "FALSE-AS-SCOPED")) return .false_as_scoped;
    if (std.mem.eql(u8, s, "FALSE")) return .false_flat;
    if (std.mem.eql(u8, s, "PROVEN")) return .proven;
    if (std.mem.eql(u8, s, "CLAIMED")) return .claimed;
    if (std.mem.eql(u8, s, "UNTESTED")) return .untested;
    if (std.mem.eql(u8, s, "INTRACTABLE")) return .intractable;
    if (std.mem.eql(u8, s, "MEASUREMENT")) return .measurement;
    return .unparsed;
}

// ── number parsing ─────────────────────────────────────────────────────────

pub fn parseNarrowed(raw: []const u8) ?u32 {
    const s = trim(raw);
    if (s.len == 0 or s[0] == '?') return null;
    return std.fmt.parseInt(u32, s, 10) catch null;
}

pub fn parseRate(raw: []const u8) ?f64 {
    var s = trim(raw);
    if (s.len == 0 or s[0] == '?') return null;
    while (s.len > 0 and (s[0] == '~' or s[0] == '<' or s[0] == '>')) s = s[1..];
    if (endsWith(s, "%")) s = s[0 .. s.len - 1];
    return std.fmt.parseFloat(f64, s) catch null;
}

// ── backtick span extraction ───────────────────────────────────────────────

/// Every backtick-delimited span in `cell`, appended to `out`.
pub fn backtickSpans(gpa: Allocator, cell: []const u8, out: *std.ArrayList([]const u8)) !void {
    var i: usize = 0;
    while (i < cell.len) {
        if (cell[i] != '`') {
            i += 1;
            continue;
        }
        const start = i + 1;
        var j = start;
        while (j < cell.len and cell[j] != '`') : (j += 1) {}
        if (j >= cell.len) return;
        if (j > start) try out.append(gpa, cell[start..j]);
        i = j + 1;
    }
}

// ── line-spec stripping ────────────────────────────────────────────────────

/// Strip a trailing `:12`, `:12-34`, `:12,34-56` line citation.
pub fn stripLineSpec(tok: []const u8) []const u8 {
    const colon = std.mem.lastIndexOfScalar(u8, tok, ':') orelse return tok;
    if (colon + 1 >= tok.len) return tok[0..colon];
    for (tok[colon + 1 ..]) |c| {
        if (!std.ascii.isDigit(c) and c != ',' and c != '-') return tok;
    }
    return tok[0..colon];
}

pub fn stripPunct(tok: []const u8) []const u8 {
    var s = tok;
    while (s.len > 0 and (s[s.len - 1] == '.' or s[s.len - 1] == ',' or s[s.len - 1] == ';' or
        s[s.len - 1] == ')' or s[s.len - 1] == ']')) s = s[0 .. s.len - 1];
    while (s.len > 0 and (s[0] == '(' or s[0] == '[' or s[0] == '=')) s = s[1..];
    return s;
}

// ── claim-ID recognition ───────────────────────────────────────────────────

pub fn isQaId(tok: []const u8) bool {
    if (tok.len < 6 or !std.mem.startsWith(u8, tok, "QA-")) return false;
    for (tok[3..]) |ch| if (!std.ascii.isDigit(ch)) return false;
    return true;
}

pub fn isClaimIdToken(tok: []const u8) bool {
    if (isQaId(tok)) return true;
    const dot = std.mem.indexOfScalar(u8, tok, '.') orelse return false;
    const scope = tok[0..dot];
    const rest = tok[dot + 1 ..];
    if (rest.len == 0) return false;
    var scope_ok = false;
    for (SCOPES) |s| {
        if (std.mem.eql(u8, s, scope)) {
            scope_ok = true;
            break;
        }
    }
    if (!scope_ok) return false;
    for (rest) |ch| {
        if (!std.ascii.isAlphanumeric(ch) and ch != '.' and ch != '-' and ch != '_') return false;
    }
    if (hasPathExt(tok)) return false;
    return true;
}

pub fn claimIdOf(span: []const u8) ?[]const u8 {
    var s = trim(span);
    if (std.mem.startsWith(u8, s, "d:") or std.mem.startsWith(u8, s, "e:") or
        std.mem.startsWith(u8, s, "n:")) s = s[2..];
    if (!isClaimIdToken(s)) return null;
    return s;
}

// ── register parsing ───────────────────────────────────────────────────────

/// Canonical register width: the 11 columns of the T305 format (the `tree`
/// column appended after wrong-answer-pass-rate, C9-gated). Per-row checks
/// derive the expected count from the §2 header row (so a future column
/// addition fails with a truthful message instead of a silent misparse);
/// this constant is the canonical-format gate — a register whose header
/// disagrees with it is not understood and must be refused loudly (T406).
pub const REGISTER_COLS: usize = 11;

pub fn parseRegister(gpa: Allocator, text: []const u8) !Register {
    var reg: Register = .{
        .rows = .empty,
        .by_id = std.StringHashMap(usize).init(gpa),
        .unparsed = .empty,
    };
    var lineno: usize = 0;
    var in_sec2 = false;
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |line| {
        lineno += 1;
        if (std.mem.startsWith(u8, line, "## 2. The register")) {
            in_sec2 = true;
            reg.sec2_start = lineno;
            continue;
        }
        if (in_sec2 and std.mem.startsWith(u8, line, "## 3.")) {
            in_sec2 = false;
            reg.sec2_end = lineno;
            continue;
        }
        if (!in_sec2) continue;
        if (line.len == 0 or line[0] != '|') continue;

        var cells = try splitCells(gpa, line);
        defer cells.deinit(gpa);
        const c = cells.items;
        if (c.len < 3) {
            try reg.unparsed.append(gpa, try std.fmt.allocPrint(gpa, "{d}: too few cells ({d})", .{ lineno, c.len }));
            continue;
        }
        const first = trim(c[1]);
        if (std.mem.eql(u8, first, "ID")) {
            // §2 header — derive the expected column count from it, and gate
            // the canonical format (T406: the old hard-coded 10 silently
            // parsed the 11-column register as empty).
            reg.header_cols = c.len - 2;
            if (reg.header_cols != REGISTER_COLS) {
                try reg.unparsed.append(gpa, try std.fmt.allocPrint(
                    gpa,
                    "{d}: register header carries {d} columns, expected {d} (the tree column format, T305) — this register is not understood",
                    .{ lineno, reg.header_cols, REGISTER_COLS },
                ));
            } else {
                reg.format_ok = true;
            }
            continue; // header
        }
        var only_dashes = first.len > 0;
        for (first) |ch| {
            if (ch != '-' and ch != ':') only_dashes = false;
        }
        if (only_dashes) continue; // separator

        if (reg.header_cols == 0) {
            try reg.unparsed.append(gpa, try std.fmt.allocPrint(
                gpa,
                "{d}: data row before any §2 header row — `{s}`",
                .{ lineno, first },
            ));
            continue;
        }
        if (!reg.format_ok) {
            try reg.unparsed.append(gpa, try std.fmt.allocPrint(
                gpa,
                "{d}: data row under a non-{d}-column §2 header — {s}",
                .{ lineno, REGISTER_COLS, first },
            ));
            continue;
        }
        if (c.len != reg.header_cols + 2) {
            try reg.unparsed.append(gpa, try std.fmt.allocPrint(
                gpa,
                "{d}: expected {d} columns, found {d} — `{s}`",
                .{ lineno, reg.header_cols, c.len - 2, first },
            ));
            continue;
        }
        if (first.len < 3 or first[0] != '`' or first[first.len - 1] != '`') {
            try reg.unparsed.append(gpa, try std.fmt.allocPrint(
                gpa,
                "{d}: ID cell is not a backticked claim ID — `{s}`",
                .{ lineno, first },
            ));
            continue;
        }
        const id = first[1 .. first.len - 1];
        const status = parseStatus(c[5]);
        if (status == .unparsed) {
            try reg.unparsed.append(gpa, try std.fmt.allocPrint(
                gpa,
                "{d}: unrecognised status for `{s}` — \"{s}\"",
                .{ lineno, id, trim(c[5]) },
            ));
        }

        var deps: std.ArrayList(Edge) = .empty;
        var spans: std.ArrayList([]const u8) = .empty;
        defer spans.deinit(gpa);
        try backtickSpans(gpa, c[7], &spans);
        for (spans.items) |sp| {
            if (std.mem.startsWith(u8, sp, "d:")) {
                try deps.append(gpa, .{ .kind = .derives, .target = sp[2..] });
            } else if (std.mem.startsWith(u8, sp, "e:")) {
                try deps.append(gpa, .{ .kind = .evidenced, .target = sp[2..] });
            } else if (std.mem.startsWith(u8, sp, "n:")) {
                try deps.append(gpa, .{ .kind = .negation, .target = sp[2..] });
            }
        }

        try reg.rows.append(gpa, .{
            .id = id,
            .line = lineno,
            .board = trim(c[3]),
            .status = status,
            .status_raw = trim(c[5]),
            .evidence = c[6],
            .dependents = c[8],
            .deps = deps,
            .narrowed = parseNarrowed(c[9]),
            .rate = parseRate(c[10]),
            .rate_raw = trim(c[10]),
            .tree = trim(c[11]),
        });
        const slot = reg.rows.items.len - 1;
        if (reg.by_id.get(id)) |prev| {
            try reg.unparsed.append(gpa, try std.fmt.allocPrint(
                gpa,
                "{d}: duplicate claim ID `{s}` (first at line {d})",
                .{ lineno, id, reg.rows.items[prev].line },
            ));
        } else {
            try reg.by_id.put(id, slot);
        }
    }
    if (reg.sec2_end == 0) reg.sec2_end = lineno;
    return reg;
}

// ── status cell extraction ─────────────────────────────────────────────────

/// Extract the status cell text from a raw CLAIMS.md register line at a given
/// line number within the register text. Returns the cell text between the 5th
/// and 6th pipe (0-indexed column 5), trimmed. Returns null if the line cannot
/// be found or parsed.
pub fn statusCellAt(gpa: Allocator, text: []const u8, target_line: usize) !?[]const u8 {
    var lineno: usize = 0;
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |line| : (lineno += 1) {
        if (lineno + 1 != target_line) continue;
        var cells = try splitCells(gpa, line);
        defer cells.deinit(gpa);
        if (cells.items.len < 7) return null;
        // Column 5 (0-indexed: cells.items[5]) is the status column.
        // cells.items[0] is empty (before first |), cells.items[1] is ID.
        return trim(cells.items[5]);
    }
    return null;
}
