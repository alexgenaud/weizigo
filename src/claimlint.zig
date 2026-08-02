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
// CLAIMLINT — keep docs/epistemic/CLAIMS.md true, mechanically.
//
// CLAIMS.md is a static snapshot: it was built by reading documents at one
// moment and nothing keeps it honest afterwards. This project has already
// destroyed itself that way once. Claims marked PROVEN cite evidence files that
// were deleted (docs/evidence/README.md), and the C3 falsification failed to
// propagate to its dependent F2/O1 for weeks because propagation was manual.
// "More discipline" is the answer that already failed. This is the check.
//
// EVERY CHECK MAPS TO A FAILURE THAT ACTUALLY HAPPENED. Do not add a check that
// merely enforces formatting.
//
//   C1a ORPHAN DETECTION — a PROVEN/CLAIMED claim with a transitive
//       `derives-from` (`d:`) ancestor that is FALSE-AS-SCOPED or FALSE.
//       PAST FAILURE: O1. The project wrote "bracket cuts are C3" and "C3 is
//       falsified" in two documents and did not notice for weeks that the
//       finisher behind every shipped ko-sensitive value depended on it
//       (CLAIMS.md §4.1 O1; critique-2026-07-28.md §4 M-F0).
//
//   C1b NEGATION ALARM — an `n:` (derives-from-negation) edge whose parent is
//       NOT false. This project is driven by falsifications: whole positions
//       are adopted BECAUSE a claim fell. `GLOBAL.REFRAME` exists because C2,
//       C3 and C4 are false; if any of them were rehabilitated, the reframe and
//       everything under it would need re-examining and nothing would say so.
//       Propagation is inverted, so this is a real check, not the mirror image
//       of a formatting rule.
//
//   C2  DANGLING EVIDENCE — a cited file path that does not exist on disk.
//       C2a: paths in the register's own evidence column.
//       C2b: paths named inside the documents the evidence column cites —
//       the reproduction inputs. PAST FAILURE: the T13 class. The reproduction
//       block in docs/research/c2-falsification-3x2.md:124-129 names
//       `-Mmain=untracked/c2pilot_3x2.zig`, which was deleted; the falsification
//       the whole reframe rests on can be read but not re-run
//       (docs/evidence/README.md, CLAIMS.md §7).
//
//   C3  PROVEN WITHOUT COMMITTED EVIDENCE — a PROVEN claim whose evidence does
//       not resolve under docs/evidence/. PAST FAILURE: roadmap-2026-07-28.md
//       §4 P1 — 57 scratch files were swept on 2026-07-27, taking the primary
//       evidence for T13, T02/B1, T07 and B05 with them. A claim whose evidence
//       cannot be retrieved is not proven; it is remembered.
//
//   C5  SHADOWED DEPENDENCY — a `d:` edge whose parent is a MEASUREMENT row.
//       A measurement records that something *happened*; it is not a truth-claim
//       that it was *correct*. PAST FAILURE: `3x3.C1` ("fresh-start scores
//       correct at 3×3") carried `d:3x3.F2`, and `3x3.F2` measures only that
//       the finisher COMPLETED all 622 orbit reps. Completion is not soundness.
//       The real parent is `GLOBAL.F2` (the finisher is *sound*), which is
//       orphaned via `GLOBAL.C3` — falsified at 3×3, the very goban. The
//       measurement sat in the chain and stopped the falsification propagating,
//       so C1a never saw the case CLAIMS.md §4.1-O3 calls the sharpest.
//
//   C4  DANGLING CLAIM IDs — an ID cited in docs/ that has no register row
//       (an error class waiting to happen: a status change that can never
//       propagate because the register does not know the claim exists), and
//       separately, register rows nothing references (a smell, not an error).
//
//   A   SMELL: repeated narrowing — `narrowed` >= 2. PAST FAILURE: single score
//       -> bracket -> fresh-start-only. Three locally-honest retreats and the
//       project was solving nothing (critique-2026-07-28.md §2).
//
//   B   WEAK EVIDENCE — a PROVEN claim whose `wrong-answer-pass-rate` is above
//       25% or unknown. PAST FAILURE: anchor agreement, cycle-rule
//       insensitivity and bracket containment were all recorded as confirmation
//       while a wrong answer would have passed them 40-70% of the time
//       (critique-2026-07-28.md §3).
//
// CALIBRATION IS NOT OPTIONAL (GLOBAL.CALIB-LESSON, roadmap §4 P3). A checker
// with no failing case proves nothing; this project has already shipped an
// uncalibrated auditor once. Every run ends with FIVE named calibration cases —
// three known-bad that must be caught, two known-good that must stay silent —
// and a calibration failure exits non-zero on its own. One of them runs the
// whole pipeline over a synthetic four-row register embedded below, because the
// C1b ALARM has no real-data instance and "0 alarms" must not be confusable
// with "the alarm is unreachable code".
//
// EXIT CODE: 1 if C1a/C1b/C2 found anything, 2 if calibration failed, 3 if a
// register row could not be parsed. C3, C4, A and B report but do not fail yet.
//
// usage: weizigo-claimlint [claims.md] [--quiet]
//   run from the repo root; paths are resolved relative to the working dir.
const std = @import("std");
const version = @import("version");
const util = @import("util.zig");
const Allocator = std.mem.Allocator;
const Io = std.Io;

const DEFAULT_CLAIMS = "docs/epistemic/CLAIMS.md";

/// Directories the repo never tracks (.gitignore, 2026-07-28). A path that
/// exists here is on somebody's disk, not in git, which for C3 is the same as
/// not existing — that is exactly how the T13 probe source was lost.
const IGNORED_PREFIXES = [_][]const u8{
    "untracked/", "data/", "log/", "bin/", "zig-out/", ".zig-cache/", "zig-cache/",
};

/// Bulk binary artifacts. Cited-but-missing .wzo files are reported separately
/// and do NOT fail the run: docs/evidence/README.md deliberately records their
/// hashes rather than committing 516 MB.
const BULK_EXT = ".wzo";

/// The loss inventory. `docs/evidence/README.md` §"CONFIRMED LOST" exists to
/// record, by name, files that are gone — so every path in it is missing *by
/// design*. A path named ONLY there is a recorded loss, not a dangling
/// citation, and is reported separately without failing the run. A path named
/// there AND in a live document is still a failure: that is the T13 case, and
/// `untracked/c2pilot_3x2.zig` must keep tripping C2.
const LOSS_INVENTORY = "docs/evidence/README.md";

const PATH_EXT = [_][]const u8{
    ".md", ".zig", ".txt", ".py", ".cfg", ".sh", ".json", ".sgf", ".log",
    ".csv", ".toml", ".yml", ".yaml", ".wzo", ".reg", ".bak",
};

/// Every scope prefix §1 of the register admits.
const SCOPES = [_][]const u8{
    "GLOBAL", "CODE", "2x2", "3x2", "3x3", "4x3", "4x4", "5x3", "5x4", "5x5", "6x3",
};

/// The narrative file cite-tagged against the register. C6 scans this for
/// `[ID:STATUS]` tags and verifies each against the register.
const NARRATIVE_FILE = "docs/epistemic/PROGRESS.md";

// ── calibration cases ────────────────────────────────────────────────────────
// Named here, checked at the end of every run. If the checker stops catching
// these, the checker is broken — not the register.
const CAL_ORPHAN_CHILD = "GLOBAL.F2"; // must be reported by C1 ...
const CAL_ORPHAN_ROOT = "GLOBAL.C3"; // ... with this FALSE ancestor in the chain
const CAL_DANGLING = "untracked/c2pilot_3x2.zig"; // must be reported by C2
const CAL_CLEAN = "GLOBAL.ADR0003-AREA"; // PROVEN, real evidence, must be silent
const CAL_NEG_OK = "GLOBAL.REFRAME"; // carries `n:` to a FALSE parent — must be SILENT
/// C5's known-bad lives in the synthetic register, not in the data. The first
/// version calibrated against `3x3.C1 d: 3x3.F2` — the exact edge C5 exists to
/// get fixed — and went MISSED the moment the fix landed. A calibration case
/// that disappears when the register improves is not a calibration case.
const CAL_SHADOW_CLEAN = "GLOBAL.F2"; // real-data known-good: `d:` only to real claims
/// C6 calibration — a synthetic narrative text with one wrong-status tag and
/// two correct-status tags. The wrong one must be caught, the right ones must
/// pass silently. The known-bad uses a real ID with a deliberately wrong status.
const CAL_SYNTHETIC_CITETAG =
    \\## C6 calibration narrative
    \\
    \\PSK is intractable for exact solve [GLOBAL.R1:PROVEN] and this is a
    \\structural result. The claim [GLOBAL.C2:PROVEN] is deliberately wrong —
    \\C2 is FALSE-AS-SCOPED, not PROVEN. Meanwhile [QA-023:CLAIMED] is the
    \\correct status for the state-sufficiency claim.
    \\
    \\## end
;
const CAL_CITE_BAD_ID = "GLOBAL.C2"; // tagged PROVEN, actually FALSE-AS-SCOPED
const CAL_CITE_GOOD_A = "GLOBAL.R1"; // tagged PROVEN, actually PROVEN
const CAL_CITE_GOOD_B = "QA-023";    // tagged CLAIMED, actually CLAIMED

/// C7 calibration — findings/ directory scanned for unabsorbed claims.
/// Synthetic findings JSON + extended synthetic register with one mismatch.
const FINDINGS_DIR = "findings";
const CAL_SYNTHETIC_C7_JSON =
    \\{
    \\  "task_id": "T999",
    \\  "date": "2026-08-01",
    \\  "model": "TestModel",
    \\  "claims": [
    \\    {
    \\      "id": "GLOBAL.CALPARENT-DEAD",
    \\      "proposed_status": "FALSE-AS-SCOPED",
    \\      "rationale": "Synthetic calibration — already absorbed",
    \\      "evidence_path": "none"
    \\    },
    \\    {
    \\      "id": "GLOBAL.CAL-SHOULDBE-FALSE",
    \\      "proposed_status": "FALSE-AS-SCOPED",
    \\      "rationale": "Synthetic calibration — status mismatch",
    \\      "evidence_path": "none"
    \\    }
    \\  ]
    \\}
;
/// Two extra rows grafted onto CAL_SYNTHETIC for C7 calibration.
/// GLOBAL.CALPARENT-DEAD is already in the synthethic register as FALSE-AS-SCOPED
/// — the finding proposes FALSE-AS-SCOPED (match, absorbed).
/// GLOBAL.CAL-SHOULDBE-FALSE is in this extended register as PROVEN — the finding
/// proposes FALSE-AS-SCOPED (mismatch, must be caught).
const CAL_SYNTHETIC_C7_EXTRA =
    \\| `GLOBAL.CAL-SHOULDBE-FALSE` | — | all | synthetic: deliberately PROVEN in register, finding says FALSE-AS-SCOPED | PROVEN | `AGENTS.md:1` | — | — | 0 | ? |
;

/// The ALARM half of the `n:` calibration cannot be exercised by real data:
/// today every `n:` edge points at a parent that really is false, which is the
/// healthy state. So the tool carries a two-row synthetic register and runs the
/// whole pipeline — parse, graph, alarm — on it at every invocation. Without
/// this, "0 alarms" would be indistinguishable from "the alarm is unreachable".
const CAL_SYNTHETIC =
    \\## 2. The register
    \\
    \\| ID | legacy | board | claim | status | evidence | depends-on | dependents | narrowed | wrong-answer-pass-rate |
    \\|---|---|---|---|---|---|---|---|---|---|
    \\| `GLOBAL.CALPARENT-DEAD` | — | all | synthetic: a parent that is FALSE | FALSE-AS-SCOPED | `AGENTS.md:1` | — | — | 0 | ? |
    \\| `GLOBAL.CALPARENT-LIVE` | — | all | synthetic: a parent still standing | PROVEN | `AGENTS.md:1` | — | — | 0 | ? |
    \\| `GLOBAL.CALCHILD-OK` | — | all | synthetic: justified by the refutation of a parent that IS refuted | CLAIMED | `AGENTS.md:1` | `n:GLOBAL.CALPARENT-DEAD` | — | 0 | ? |
    \\| `GLOBAL.CALCHILD-ALARM` | — | all | synthetic: justified by the refutation of a parent that is NOT refuted | CLAIMED | `AGENTS.md:1` | `n:GLOBAL.CALPARENT-LIVE` | — | 0 | ? |
    \\| `GLOBAL.CALPARENT-MEAS` | — | all | synthetic: a measurement, which can never be FALSE | MEASUREMENT | `AGENTS.md:1` | — | — | 0 | ? |
    \\| `GLOBAL.CALCHILD-SHADOW` | — | all | synthetic: `d:` onto a measurement — the shadowed-dependency shape | CLAIMED | `AGENTS.md:1` | `d:GLOBAL.CALPARENT-MEAS` | — | 0 | ? |
    \\| `GLOBAL.CALCHILD-PLAIN` | — | all | synthetic: `d:` onto a real claim — must stay silent in C5 | CLAIMED | `AGENTS.md:1` | `d:GLOBAL.CALPARENT-LIVE` | — | 0 | ? |
    \\
    \\## 3. end
;

// ── model ────────────────────────────────────────────────────────────────────

const Status = enum {
    proven,
    claimed,
    false_as_scoped,
    false_flat,
    untested,
    intractable,
    measurement,
    definition,
    unparsed,

    fn isLive(s: Status) bool {
        return s == .proven or s == .claimed;
    }
    fn isFalse(s: Status) bool {
        return s == .false_as_scoped or s == .false_flat;
    }
    fn name(s: Status) []const u8 {
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
};

const EdgeKind = enum {
    /// `d:` the claim is a logical consequence of the parent. Parent falls -> child falls.
    derives,
    /// `e:` the claim is supported by a measurement. Parent falls -> child becomes UNTESTED.
    evidenced,
    /// `n:` the claim is justified by the parent being FALSE. Propagation is
    /// INVERTED: a FALSE parent is healthy; a parent that is no longer false
    /// means the child's justification has evaporated.
    negation,
};

const Edge = struct { kind: EdgeKind, target: []const u8 };

const Row = struct {
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
    in_degree: u32 = 0,
    refs_outside: u32 = 0,
};

// ── small string helpers ─────────────────────────────────────────────────────

fn trim(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t\r\n");
}

fn endsWith(s: []const u8, suffix: []const u8) bool {
    return std.mem.endsWith(u8, s, suffix);
}

fn baseName(p: []const u8) []const u8 {
    if (std.mem.lastIndexOfScalar(u8, p, '/')) |i| return p[i + 1 ..];
    return p;
}

fn hasPathExt(s: []const u8) bool {
    for (PATH_EXT) |e| if (endsWith(s, e)) return true;
    return false;
}

fn isIgnoredPath(p: []const u8) bool {
    for (IGNORED_PREFIXES) |pre| if (std.mem.startsWith(u8, p, pre)) return true;
    return false;
}

/// Split a markdown table row on `|` that is not backslash-escaped. The
/// register escapes literal pipes (`vb\|vw\|...` in CODE.ADR0011-FMT), so a
/// naive split silently mangles that row — and a linter that silently mangles
/// rows is worse than none.
fn splitCells(gpa: Allocator, line: []const u8) !std.ArrayList([]const u8) {
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

/// Strip a trailing `:12`, `:12-34`, `:12,34-56` line citation.
fn stripLineSpec(tok: []const u8) []const u8 {
    const colon = std.mem.lastIndexOfScalar(u8, tok, ':') orelse return tok;
    if (colon + 1 >= tok.len) return tok[0..colon];
    for (tok[colon + 1 ..]) |c| {
        if (!std.ascii.isDigit(c) and c != ',' and c != '-') {
            // en-dash is multi-byte; treat any non-ASCII as "not a line spec"
            return tok;
        }
    }
    return tok[0..colon];
}

fn stripPunct(tok: []const u8) []const u8 {
    var s = tok;
    while (s.len > 0 and (s[s.len - 1] == '.' or s[s.len - 1] == ',' or s[s.len - 1] == ';' or
        s[s.len - 1] == ')' or s[s.len - 1] == ']')) s = s[0 .. s.len - 1];
    while (s.len > 0 and (s[0] == '(' or s[0] == '[' or s[0] == '=')) s = s[1..];
    return s;
}

// ── repo file index ──────────────────────────────────────────────────────────

const Index = struct {
    gpa: Allocator,
    paths: std.ArrayList([]const u8),
    exact: std.StringHashMap(void),
    /// memoised resolutions, including negative ones
    cache: std.StringHashMap(?[]const u8),

    fn build(gpa: Allocator, io: Io) !Index {
        var idx: Index = .{
            .gpa = gpa,
            .paths = .empty,
            .exact = std.StringHashMap(void).init(gpa),
            .cache = std.StringHashMap(?[]const u8).init(gpa),
        };
        var root = try Io.Dir.cwd().openDir(io, ".", .{ .iterate = true });
        defer root.close(io);
        var w = try root.walkSelectively(gpa);
        defer w.deinit();
        while (try w.next(io)) |e| {
            if (e.kind == .directory) {
                const b = e.basename;
                if (std.mem.eql(u8, b, ".git")) continue;
                if (std.mem.eql(u8, b, ".zig-cache")) continue;
                if (std.mem.eql(u8, b, "zig-cache")) continue;
                if (std.mem.eql(u8, b, "zig-out")) continue;
                if (std.mem.eql(u8, b, "node_modules")) continue;
                w.enter(io, e) catch {};
                continue;
            }
            if (e.kind != .file) continue;
            const p = try gpa.dupe(u8, e.path);
            try idx.paths.append(gpa, p);
            try idx.exact.put(p, {});
        }
        return idx;
    }

    /// The evidence column does not write repo paths. It writes
    /// `4x4/EPISTEMIC.md:17`, `0009:65-67`, `open-hypotheses:63-88`,
    /// `leak-crisis.md:24`. Resolution is therefore a search, deliberately
    /// tolerant — an unresolvable *path-shaped* token is a finding, an
    /// unresolvable prose token is not.
    fn resolve(self: *Index, raw: []const u8) !?[]const u8 {
        var tok = stripLineSpec(stripPunct(trim(raw)));
        // Documents link each other relatively (`../status/leak-crisis.md`).
        // Drop the leading traversal and let the suffix match do the work —
        // deliberately tolerant: this check hunts deleted files, not wrong
        // relative depths.
        while (std.mem.startsWith(u8, tok, "../")) tok = tok[3..];
        while (std.mem.startsWith(u8, tok, "./")) tok = tok[2..];
        while (std.mem.startsWith(u8, tok, "/")) tok = tok[1..];
        if (tok.len == 0) return null;
        if (self.cache.get(tok)) |hit| return hit;
        const found = self.resolveUncached(tok);
        try self.cache.put(tok, found);
        return found;
    }

    fn resolveUncached(self: *Index, tok: []const u8) ?[]const u8 {
        if (self.exact.contains(tok)) {
            for (self.paths.items) |p| if (std.mem.eql(u8, p, tok)) return p;
        }
        if (std.mem.indexOfScalar(u8, tok, '/') != null) {
            // path fragment: match on a full trailing path component run
            for (self.paths.items) |p| {
                if (std.mem.eql(u8, p, tok)) return p;
                if (endsWith(p, tok) and p.len > tok.len and p[p.len - tok.len - 1] == '/') return p;
            }
            return null;
        }
        // bare `0009` -> docs/decisions/0009-*.md
        if (tok.len == 4 and std.ascii.isDigit(tok[0]) and std.ascii.isDigit(tok[3])) {
            for (self.paths.items) |p| {
                if (!std.mem.startsWith(u8, p, "docs/decisions/")) continue;
                const b = baseName(p);
                if (std.mem.startsWith(u8, b, tok) and b.len > tok.len and b[tok.len] == '-') return p;
            }
        }
        for (self.paths.items) |p| if (std.mem.eql(u8, baseName(p), tok)) return p;
        // `open-hypotheses` -> open-hypotheses-2026-07-27.md ; `corrections` ->
        // corrections-2026-07-27.md. Prefix match, unique-or-first.
        for (self.paths.items) |p| {
            const b = baseName(p);
            if (b.len <= tok.len) continue;
            if (!std.mem.startsWith(u8, b, tok)) continue;
            if (b[tok.len] == '-' or b[tok.len] == '.') return p;
        }
        return null;
    }
};

// ── register parsing ─────────────────────────────────────────────────────────

const Register = struct {
    rows: std.ArrayList(Row),
    by_id: std.StringHashMap(usize),
    unparsed: std.ArrayList([]const u8),
    /// [start,end) line numbers (1-based) of the §2 region, so C4 can tell a
    /// register row's own columns from a genuine outside reference.
    sec2_start: usize = 0,
    sec2_end: usize = 0,
};

fn parseStatus(raw: []const u8) Status {
    const s = trim(raw);
    if (s.len == 0) return .unparsed;
    if (std.mem.startsWith(u8, s, "FALSE-AS-SCOPED")) return .false_as_scoped;
    if (std.mem.startsWith(u8, s, "FALSE")) return .false_flat;
    if (std.mem.startsWith(u8, s, "PROVEN")) return .proven;
    if (std.mem.startsWith(u8, s, "CLAIMED")) return .claimed;
    if (std.mem.startsWith(u8, s, "UNTESTED")) return .untested;
    if (std.mem.startsWith(u8, s, "INTRACTABLE")) return .intractable;
    if (std.mem.startsWith(u8, s, "MEASUREMENT")) return .measurement;
    if (std.mem.startsWith(u8, s, "—")) return .definition; // "— (definition)"
    return .unparsed;
}

fn parseNarrowed(raw: []const u8) ?u32 {
    const s = trim(raw);
    if (s.len == 0 or s[0] == '?') return null;
    return std.fmt.parseInt(u32, s, 10) catch null;
}

fn parseRate(raw: []const u8) ?f64 {
    var s = trim(raw);
    if (s.len == 0 or s[0] == '?') return null;
    while (s.len > 0 and (s[0] == '~' or s[0] == '<' or s[0] == '>')) s = s[1..];
    if (endsWith(s, "%")) s = s[0 .. s.len - 1];
    return std.fmt.parseFloat(f64, s) catch null;
}

/// Every backtick-delimited span in `cell`, appended to `out`.
fn backtickSpans(gpa: Allocator, cell: []const u8, out: *std.ArrayList([]const u8)) !void {
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

fn parseRegister(gpa: Allocator, text: []const u8) !Register {
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
        if (std.mem.eql(u8, first, "ID")) continue; // header
        var only_dashes = first.len > 0;
        for (first) |ch| {
            if (ch != '-' and ch != ':') only_dashes = false;
        }
        if (only_dashes) continue; // separator

        // A data row. It MUST have the full column set; loud on anything else.
        if (c.len != 12) {
            try reg.unparsed.append(gpa, try std.fmt.allocPrint(
                gpa,
                "{d}: expected 10 columns, found {d} — `{s}`",
                .{ lineno, c.len - 2, first },
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

// ── claim-ID recognition (C4) ────────────────────────────────────────────────

fn isClaimIdToken(tok: []const u8) bool {
    // `QA-nnn` — the Q&A register minted by critique-2026-07-28 §7 and
    // roadmap-2026-07-28 §5. Scope-free by construction (§1), so it has no dot.
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
    if (hasPathExt(tok)) return false; // `4x4.checkpoint.wzo` is a file, not a claim
    return true;
}

fn claimIdOf(span: []const u8) ?[]const u8 {
    var s = trim(span);
    if (std.mem.startsWith(u8, s, "d:") or std.mem.startsWith(u8, s, "e:") or
        std.mem.startsWith(u8, s, "n:")) s = s[2..];
    if (!isClaimIdToken(s)) return null;
    return s;
}

/// `QA-nnn` — the second claim-ID namespace, minted by critique-2026-07-28 §7
/// and roadmap-2026-07-28 §5 and imported into §2.11 on 2026-07-28. Tracked
/// separately so the tool can report how much of it the register models: an ID
/// the graph cannot see is an ID a falsification can never propagate to.
fn isQaId(tok: []const u8) bool {
    if (tok.len < 6 or !std.mem.startsWith(u8, tok, "QA-")) return false;
    for (tok[3..]) |ch| if (!std.ascii.isDigit(ch)) return false;
    return true;
}

// ── path-token extraction (C2) ───────────────────────────────────────────────

fn isPathChar(c: u8) bool {
    return std.ascii.isAlphanumeric(c) or c == '.' or c == '/' or c == '-' or c == '_' or c == ':';
}

/// Every token in `text` that *looks like a repo path*: it must carry a known
/// file extension. Requiring the extension is what keeps ratios ("45/378",
/// "12/508"), shorthand ("V0/V1", "F2/F3"), directory mentions ("untracked/")
/// and git hashes out of the report — a dangling-evidence check that cries
/// wolf on prose gets switched off, and then it is worth nothing.
fn pathTokens(gpa: Allocator, text: []const u8, out: *std.ArrayList([]const u8)) !void {
    var i: usize = 0;
    while (i < text.len) {
        if (!isPathChar(text[i])) {
            i += 1;
            continue;
        }
        const start = i;
        while (i < text.len and isPathChar(text[i])) : (i += 1) {}
        const tok = stripLineSpec(stripPunct(text[start..i]));
        if (tok.len < 5) continue;
        if (!hasPathExt(tok)) continue;
        if (std.mem.startsWith(u8, tok, "http")) continue;
        try out.append(gpa, tok);
    }
}

// ── cite-tag extraction (C6) ────────────────────────────────────────────────

/// A cite-tag found in a narrative document: `[ID:STATUS]`.
const CiteTag = struct {
    id: []const u8,
    status: []const u8,
    line: usize,
};

/// A cite-tag mismatch between the narrative and the register.
const CiteMismatch = struct {
    id: []const u8,
    tagged_status: []const u8,
    register_status: []const u8,
    line: usize,
};

/// Extract every `[ID:STATUS]` tag from `text`. A cite-tag is a claim ID
/// followed by `:` and a status string, wrapped in `[]`. The ID must match the
/// claim-ID token pattern (scope-prefixed or QA-nnn), and the status must be
/// one of the recognised status words.
fn citeTags(gpa: Allocator, text: []const u8) !std.ArrayList(CiteTag) {
    var out: std.ArrayList(CiteTag) = .empty;
    var lineno: usize = 1;
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        if (text[i] == '\n') {
            lineno += 1;
            continue;
        }
        if (text[i] != '[') continue;
        const start = i + 1;
        const colon = std.mem.indexOfScalarPos(u8, text, start, ':') orelse {
            i = start;
            continue;
        };
        const close = std.mem.indexOfScalarPos(u8, text, colon + 1, ']') orelse {
            i = start;
            continue;
        };
        // Reject if the span is too long (heuristic: max 80 chars for ID + status)
        if (close - start > 80) {
            i = close;
            continue;
        }
        const id_part = trim(text[start..colon]);
        if (!isClaimIdToken(id_part)) {
            i = close;
            continue;
        }
        const status_part = trim(text[colon + 1 .. close]);
        // Validate that status_part is a recognised status word
        if (parseStatus(status_part) == .unparsed) {
            i = close;
            continue;
        }
        try out.append(gpa, .{
            .id = id_part,
            .status = status_part,
            .line = lineno,
        });
        i = close;
    }
    return out;
}

/// Run C6: scan a narrative file for cite-tags and verify each against the
/// register. Returns mismatches — tags whose stated status disagrees with the
/// register. A tag whose ID is not in the register is also a mismatch (reported
/// with register_status = "NO SUCH ID").
fn citeTagCheck(
    gpa: Allocator,
    io: Io,
    reg: *Register,
    path: []const u8,
) !std.ArrayList(CiteMismatch) {
    var out: std.ArrayList(CiteMismatch) = .empty;
    const text = Io.Dir.cwd().readFileAlloc(io, path, gpa, .unlimited) catch |e| {
        util.note("  C6: cannot read narrative file {s}: {s} — skipping\n", .{ path, @errorName(e) });
        return out;
    };
    const tags = try citeTags(gpa, text);
    for (tags.items) |tag| {
        const slot = reg.by_id.get(tag.id) orelse {
            try out.append(gpa, .{
                .id = tag.id,
                .tagged_status = tag.status,
                .register_status = "NO SUCH ID",
                .line = tag.line,
            });
            continue;
        };
        const reg_row = reg.rows.items[slot];
        const tagged = parseStatus(tag.status);
        if (tagged != reg_row.status) {
            try out.append(gpa, .{
                .id = tag.id,
                .tagged_status = tag.status,
                .register_status = reg_row.status.name(),
                .line = tag.line,
            });
        }
    }
    return out;
}

// ── report state ─────────────────────────────────────────────────────────────


const Missing = struct {
    path: []const u8,
    claims: std.ArrayList([]const u8),
    vias: std.ArrayList([]const u8),
    bulk: bool,
    from_column: bool = false,

    /// named only by the loss inventory — a recorded loss, not a live citation
    fn inventoriedOnly(m: Missing) bool {
        if (m.vias.items.len != 1) return false;
        return std.mem.eql(u8, m.vias.items[0], LOSS_INVENTORY);
    }
};

pub fn main(init: std.process.Init) !void {
    std.debug.print("{s}\n", .{version.banner("weizigo-claimlint")});
    const gpa = std.heap.page_allocator;
    const io = init.io;
    var args = std.process.Args.Iterator.init(init.minimal.args);
    _ = args.next();
    var claims_path: []const u8 = DEFAULT_CLAIMS;
    while (args.next()) |a| {
        if (std.mem.startsWith(u8, a, "--")) continue;
        claims_path = a;
    }

    const text = Io.Dir.cwd().readFileAlloc(io, claims_path, gpa, .unlimited) catch |e| {
        util.note("claimlint: cannot read {s}: {s}\n", .{ claims_path, @errorName(e) });
        std.process.exit(3);
    };

    var idx = try Index.build(gpa, io);
    var reg = try parseRegister(gpa, text);

    util.out("weizigo-claimlint — {s}\n", .{claims_path});
    util.out("repo index: {d} files · register §2 lines {d}–{d}\n", .{
        idx.paths.items.len, reg.sec2_start, reg.sec2_end,
    });

    // ── C0 parse ────────────────────────────────────────────────────────────
    util.out("\n== C0  PARSE ==\n", .{});
    util.out("rows parsed:   {d}\n", .{reg.rows.items.len});
    util.out("rows UNPARSED: {d}   <-- must be 0; a linter that skips rows is worse than none\n", .{reg.unparsed.items.len});
    for (reg.unparsed.items) |u| util.out("  ! {s}\n", .{u});

    // formal in-degree, for ranking; and the edge census §3 needs
    var n_d: usize = 0;
    var n_e: usize = 0;
    var n_n: usize = 0;
    for (reg.rows.items) |r| {
        for (r.deps.items) |d| {
            switch (d.kind) {
                .derives => n_d += 1,
                .evidenced => n_e += 1,
                .negation => n_n += 1,
            }
            if (reg.by_id.get(d.target)) |k| reg.rows.items[k].in_degree += 1;
        }
    }
    util.out("edges: {d} total — {d} `d:` derives-from, {d} `e:` evidenced-by, {d} `n:` derives-from-negation\n", .{ n_d + n_e + n_n, n_d, n_e, n_n });

    // ── C1 orphan detection ─────────────────────────────────────────────────
    util.out("\n== C1  ORPHAN DETECTION (fails the run) ==\n", .{});
    util.out("C1a: PROVEN/CLAIMED claims with a transitive `d:` ancestor that is FALSE.\n", .{});
    util.out("`n:` edges are NOT traversed — a claim justified by a refutation does not\n", .{});
    util.out("inherit the refuted parent's ancestry. C1b below checks them the other way.\n\n", .{});
    var c1_count: usize = 0;
    var cal_orphan_hit = false;
    for (reg.rows.items, 0..) |r, i| {
        if (!r.status.isLive()) continue;
        const chain = try shortestFalseChain(gpa, &reg, i) orelse continue;
        c1_count += 1;
        util.out("  ORPHAN  `{s}` ({s})\n", .{ r.id, r.status_raw });
        for (chain.items, 1..) |step, depth| {
            const sr = reg.rows.items[step];
            util.out("     {s}⟵d `{s}`  [{s}]\n", .{
                spaces(depth),
                sr.id,
                sr.status.name(),
            });
        }
        if (std.mem.eql(u8, r.id, CAL_ORPHAN_CHILD)) {
            for (chain.items) |step| {
                if (std.mem.eql(u8, reg.rows.items[step].id, CAL_ORPHAN_ROOT)) cal_orphan_hit = true;
            }
        }
    }
    if (c1_count == 0) util.out("  (none)\n", .{});
    util.out("\n  C1a orphans: {d}\n", .{c1_count});

    // C1b — the inverse. A claim carrying `n:P` is justified BY P being false.
    // If P is ever rehabilitated the justification evaporates and the child
    // needs re-examining. Nothing else in this repo detects that.
    util.out("\n  C1b — NEGATION ALARM: `n:` edges whose parent is no longer FALSE.\n", .{});
    const alarms = try negationAlarms(gpa, &reg);
    for (alarms.items) |a| {
        const child = reg.rows.items[a.child];
        const parent = reg.rows.items[a.parent];
        util.out("  ALARM   `{s}` ({s})\n", .{ child.id, child.status_raw });
        util.out("            ⟵n `{s}`  [{s}]  — justified by this parent being FALSE;\n", .{ parent.id, parent.status.name() });
        util.out("               it is not. The justification has evaporated.\n", .{});
    }
    if (alarms.items.len == 0)
        util.out("  (none — every `n:` edge points at a parent that is still FALSE)\n", .{});
    util.out("\n  C1b alarms: {d}\n", .{alarms.items.len});
    util.out("\n  C1 total: {d}\n", .{c1_count + alarms.items.len});

    // ── C2 dangling evidence ────────────────────────────────────────────────
    util.out("\n== C2  DANGLING EVIDENCE (fails the run) ==\n", .{});
    var missing: std.ArrayList(Missing) = .empty;
    var seen_missing = std.StringHashMap(usize).init(gpa);

    // C2c — an evidence document that exists but is git-ignored. It is one
    // cleanup sweep from gone; that sweep already happened once (QA-022).
    var notgit: std.ArrayList(Missing) = .empty;
    var seen_notgit = std.StringHashMap(usize).init(gpa);

    var scanned = std.StringHashMap(void).init(gpa);
    for (reg.rows.items) |r| {
        var spans: std.ArrayList([]const u8) = .empty;
        defer spans.deinit(gpa);
        try backtickSpans(gpa, r.evidence, &spans);
        for (spans.items) |sp| {
            var toks: std.ArrayList([]const u8) = .empty;
            defer toks.deinit(gpa);
            try pathTokens(gpa, sp, &toks);
            // C2a — the register's own evidence column.
            for (toks.items) |t| {
                if (try idx.resolve(t) != null) continue;
                try noteMissing(gpa, &missing, &seen_missing, t, r.id, "the evidence column itself", true);
            }
            // bare-name citations resolve too (`0009`, `open-hypotheses`)
            const bare = stripLineSpec(stripPunct(trim(sp)));
            if (bare.len > 0 and std.mem.indexOfScalar(u8, bare, ' ') == null)
                try toks.append(gpa, bare);

            // C2b — the reproduction inputs named inside the documents the
            // evidence cites. This is the T13 class: the number survives in
            // git, the probe that produced it does not.
            for (toks.items) |t| {
                const doc = (try idx.resolve(t)) orelse continue;
                if (!endsWith(doc, ".md")) continue;
                if (isIgnoredPath(doc)) {
                    try noteMissing(gpa, &notgit, &seen_notgit, doc, r.id, "the evidence column itself", true);
                    continue; // do not descend into an uncommitted document
                }
                const key = try std.fmt.allocPrint(gpa, "{s}\x00{s}", .{ r.id, doc });
                if (scanned.contains(key)) continue;
                try scanned.put(key, {});
                const body = Io.Dir.cwd().readFileAlloc(io, doc, gpa, .unlimited) catch continue;
                var inner: std.ArrayList([]const u8) = .empty;
                defer inner.deinit(gpa);
                try pathTokens(gpa, body, &inner);
                for (inner.items) |p| {
                    if (std.mem.indexOfScalar(u8, p, '/') == null) continue; // prose basenames: too noisy
                    if (try idx.resolve(p) != null) continue;
                    try noteMissing(gpa, &missing, &seen_missing, p, r.id, doc, false);
                }
            }
        }
    }

    var c2_fail: usize = 0;
    var c2_bulk: usize = 0;
    var c2a: usize = 0;
    var c2b: usize = 0;
    var c2_inventoried: usize = 0;
    for (missing.items) |m| {
        if (m.bulk) continue;
        if (m.inventoriedOnly()) {
            c2_inventoried += 1;
            continue;
        }
        if (m.from_column) c2a += 1 else c2b += 1;
    }
    util.out("\n  missing paths, with the claims that reach them:\n", .{});
    std.mem.sort(Missing, missing.items, {}, missingLess);
    for (missing.items) |m| {
        if (m.bulk) {
            c2_bulk += 1;
            continue;
        }
        if (m.inventoriedOnly()) continue;
        c2_fail += 1;
        util.out("  MISSING  {s}\n", .{m.path});
        util.out("           named in:", .{});
        for (m.vias.items, 0..) |v, k| {
            if (k == 4) {
                util.out(" …(+{d})", .{m.vias.items.len - k});
                break;
            }
            util.out(" {s}", .{v});
        }
        util.out("\n           reachable from {d} register row(s), e.g.", .{m.claims.items.len});
        for (m.claims.items, 0..) |cid, k| {
            if (k == 4) break;
            util.out(" `{s}`", .{cid});
        }
        util.out("\n", .{});
    }
    if (c2_fail == 0) util.out("  (none)\n", .{});
    if (c2_bulk > 0) {
        util.out("\n  bulk .wzo artifacts cited but absent (informational — git-ignored by\n", .{});
        util.out("  design, hashes recorded in docs/evidence/README.md; does NOT fail):\n", .{});
        for (missing.items) |m| {
            if (!m.bulk) continue;
            util.out("    {s}  (named in {s})\n", .{ m.path, m.vias.items[0] });
        }
    }
    if (c2_inventoried > 0) {
        util.out("\n  already inventoried as CONFIRMED LOST in {s} and named nowhere\n", .{LOSS_INVENTORY});
        util.out("  else — a recorded loss, not a dangling citation; does NOT fail:\n", .{});
        for (missing.items) |m| {
            if (m.bulk or !m.inventoriedOnly()) continue;
            util.out("    {s}\n", .{m.path});
        }
    }

    util.out("\n  evidence documents that EXIST but are git-ignored — readable today,\n", .{});
    util.out("  unrecoverable after the next sweep (roadmap §4 P1; QA-022):\n", .{});
    for (notgit.items) |m| {
        util.out("    NOT IN GIT  {s}   cited by", .{m.path});
        for (m.claims.items, 0..) |cid, k| {
            if (k == 4) {
                util.out(" …(+{d})", .{m.claims.items.len - k});
                break;
            }
            util.out(" `{s}`", .{cid});
        }
        util.out("\n", .{});
    }
    if (notgit.items.len == 0) util.out("    (none)\n", .{});

    const c2_total = c2_fail + notgit.items.len;
    util.out("\n  C2 total: {d}  ({d} unique missing paths — {d} cited by the evidence column\n", .{ c2_total, c2_fail, c2a });
    util.out("            directly, {d} named inside cited documents — plus {d} git-ignored\n", .{ c2b, notgit.items.len });
    util.out("            evidence documents; {d} bulk .wzo and {d} already-inventoried\n", .{ c2_bulk, c2_inventoried });
    util.out("            losses, not counted)\n", .{});

    // ── C3 proven without committed evidence ────────────────────────────────
    util.out("\n== C3  PROVEN WITHOUT COMMITTED EVIDENCE (debt list — does NOT fail, yet) ==\n", .{});
    util.out("roadmap-2026-07-28 §4 P1: a claim is PROVEN only if its probe source and\n", .{});
    util.out("output are committed under docs/evidence/. Tier C = no committed evidence\n", .{});
    util.out("at all. Tier B = a committed prose document records the result, but no\n", .{});
    util.out("re-runnable probe. Tier A = compliant.\n\n", .{});
    var tierA: std.ArrayList(usize) = .empty;
    var tierB: std.ArrayList(usize) = .empty;
    var tierC: std.ArrayList(usize) = .empty;
    for (reg.rows.items, 0..) |r, i| {
        if (r.status != .proven) continue;
        var has_evidence_dir = false;
        var has_committed = false;
        var spans: std.ArrayList([]const u8) = .empty;
        defer spans.deinit(gpa);
        try backtickSpans(gpa, r.evidence, &spans);
        for (spans.items) |sp| {
            var toks: std.ArrayList([]const u8) = .empty;
            defer toks.deinit(gpa);
            try pathTokens(gpa, sp, &toks);
            const bare = stripLineSpec(stripPunct(trim(sp)));
            if (bare.len > 0 and std.mem.indexOfScalar(u8, bare, ' ') == null)
                try toks.append(gpa, bare);
            for (toks.items) |t| {
                const p = (try idx.resolve(t)) orelse continue;
                if (std.mem.startsWith(u8, p, "docs/evidence/")) has_evidence_dir = true;
                if (!isIgnoredPath(p)) has_committed = true;
            }
        }
        if (has_evidence_dir) {
            try tierA.append(gpa, i);
        } else if (has_committed) {
            try tierB.append(gpa, i);
        } else {
            try tierC.append(gpa, i);
        }
    }
    const byDeg = struct {
        fn less(rows: []const Row, a: usize, b: usize) bool {
            return rows[a].in_degree > rows[b].in_degree;
        }
    };
    std.mem.sort(usize, tierC.items, @as([]const Row, reg.rows.items), byDeg.less);
    std.mem.sort(usize, tierB.items, @as([]const Row, reg.rows.items), byDeg.less);
    util.out("  TIER C — PROVEN, no committed evidence resolves at all ({d}):\n", .{tierC.items.len});
    for (tierC.items) |i| {
        const r = reg.rows.items[i];
        util.out("    [in-deg {d:>2}] `{s}` — {s}\n", .{ r.in_degree, r.id, trim(r.evidence) });
    }
    if (tierC.items.len == 0) util.out("    (none)\n", .{});
    util.out("\n  TIER B — PROVEN, committed prose only, no probe under docs/evidence/ ({d}):\n", .{tierB.items.len});
    for (tierB.items) |i| {
        const r = reg.rows.items[i];
        util.out("    [in-deg {d:>2}] `{s}`\n", .{ r.in_degree, r.id });
    }
    util.out("\n  TIER A — compliant (evidence under docs/evidence/): {d}\n", .{tierA.items.len});
    for (tierA.items) |i| util.out("    `{s}`\n", .{reg.rows.items[i].id});
    util.out("\n  C3 total PROVEN-without-committed-evidence: {d} of {d} PROVEN rows\n", .{
        tierB.items.len + tierC.items.len,
        tierA.items.len + tierB.items.len + tierC.items.len,
    });

    // ── C4 dangling claim IDs ───────────────────────────────────────────────
    util.out("\n== C4  DANGLING CLAIM IDs (report only — does NOT fail, yet) ==\n", .{});
    var dangling = std.StringHashMap(std.ArrayList([]const u8)).init(gpa);
    var qa = std.StringHashMap(std.ArrayList([]const u8)).init(gpa);
    var qa_modelled = std.StringHashMap(void).init(gpa);
    for (idx.paths.items) |p| {
        if (!std.mem.startsWith(u8, p, "docs/") and !std.mem.eql(u8, p, "AGENTS.md")) continue;
        if (!endsWith(p, ".md")) continue;
        const body = Io.Dir.cwd().readFileAlloc(io, p, gpa, .unlimited) catch continue;
        const is_claims = std.mem.eql(u8, p, claims_path);
        var lineno: usize = 0;
        var lit = std.mem.splitScalar(u8, body, '\n');
        while (lit.next()) |line| {
            lineno += 1;
            const inside_sec2 = is_claims and lineno > reg.sec2_start and lineno < reg.sec2_end;
            var spans: std.ArrayList([]const u8) = .empty;
            defer spans.deinit(gpa);
            try backtickSpans(gpa, line, &spans);
            for (spans.items) |sp| {
                const cid = claimIdOf(sp) orelse continue;
                if (isQaId(cid)) {
                    const g = try qa.getOrPut(cid);
                    if (!g.found_existing) g.value_ptr.* = .empty;
                    if (g.value_ptr.items.len < 3)
                        try g.value_ptr.append(gpa, try std.fmt.allocPrint(gpa, "{s}:{d}", .{ p, lineno }));
                }
                if (isQaId(cid) and reg.by_id.contains(cid)) {
                    const g2 = try qa_modelled.getOrPut(cid);
                    if (!g2.found_existing) g2.value_ptr.* = {};
                }
                if (reg.by_id.get(cid)) |k| {
                    if (!inside_sec2) reg.rows.items[k].refs_outside += 1;
                    continue;
                }
                const gop = try dangling.getOrPut(cid);
                if (!gop.found_existing) gop.value_ptr.* = .empty;
                const where = try std.fmt.allocPrint(gpa, "{s}:{d}", .{ p, lineno });
                if (gop.value_ptr.items.len < 4) try gop.value_ptr.append(gpa, where);
            }
        }
    }
    util.out("  claim IDs cited in docs/ with NO register row ({d}):\n", .{dangling.count()});
    var dit = dangling.iterator();
    while (dit.next()) |e| {
        util.out("    `{s}`  cited at", .{e.key_ptr.*});
        for (e.value_ptr.items) |w| util.out(" {s}", .{w});
        util.out("\n", .{});
    }
    if (dangling.count() == 0) util.out("    (none)\n", .{});

    const qa_gap = qa.count() - qa_modelled.count();
    util.out("\n  `QA-nnn` namespace coverage: {d} distinct IDs cited in docs/, {d} with a\n", .{ qa.count(), qa_modelled.count() });
    util.out("  register row, {d} without. A falsification cannot propagate to an ID the\n", .{qa_gap});
    util.out("  graph cannot see:\n", .{});
    var qit = qa.iterator();
    while (qit.next()) |e| {
        if (reg.by_id.contains(e.key_ptr.*)) continue;
        util.out("    UNMODELLED `{s}`  cited at", .{e.key_ptr.*});
        for (e.value_ptr.items) |w| util.out(" {s}", .{w});
        util.out("\n", .{});
    }
    if (qa_gap == 0) util.out("    (none unmodelled)\n", .{});

    var unref: usize = 0;
    util.out("\n  register rows nothing references — no citation outside §2 AND no\n", .{});
    util.out("  incoming edge inside it (a smell, not an error):\n", .{});
    for (reg.rows.items) |r| {
        if (r.refs_outside > 0 or r.in_degree > 0) continue;
        unref += 1;
        util.out("    `{s}` [{s}]\n", .{ r.id, r.status.name() });
    }
    if (unref == 0) util.out("    (none)\n", .{});
    util.out("\n  C4 total: {d} dangling IDs, {d} unmodelled QA-nnn IDs, {d} unreferenced rows\n", .{ dangling.count(), qa.count() - qa_modelled.count(), unref });

    // ── C5 shadowed dependencies ────────────────────────────────────────────
    util.out("\n== C5  SHADOWED DEPENDENCY (report only — does NOT fail, yet) ==\n", .{});
    util.out("`d:` edges terminating on a MEASUREMENT or a definition. A measurement says\n", .{});
    util.out("something happened; a definition cannot be wrong. Neither can ever be FALSE,\n", .{});
    util.out("so the edge is a dead end: if the claim really needs the SOUNDNESS behind the\n", .{});
    util.out("measurement, that parent is missing and a falsification cannot reach this row.\n\n", .{});
    const shadows = try shadowedEdges(gpa, &reg);
    for (shadows.items) |sh| {
        const child = reg.rows.items[sh.child];
        const parent = reg.rows.items[sh.parent];
        util.out("  SHADOWED: `{s}` [{s}]\n", .{ child.id, child.status.name() });
        util.out("            d: `{s}` [{s}] — a parent that can never be FALSE;\n", .{ parent.id, parent.status.name() });
        util.out("            completion is not soundness. Is the real parent a soundness claim?\n", .{});
    }
    if (shadows.items.len == 0) util.out("  (none)\n", .{});
    const c5 = shadows.items.len;
    util.out("\n  C5 total: {d}\n", .{c5});

    // ── C6 cite-tag verification ───────────────────────────────────────────
    util.out("\n== C6  CITE-TAG VERIFICATION (fails the run) ==\n", .{});
    util.out("Scans the narrative file ({s}) for `[ID:STATUS]` tags\n", .{NARRATIVE_FILE});
    util.out("and verifies each against the register. A narrative whose\n", .{});
    util.out("cite-tags do not match the register is hallucination-prone.\n\n", .{});
    const cite_mismatches = try citeTagCheck(gpa, io, &reg, NARRATIVE_FILE);
    if (cite_mismatches.items.len == 0) {
        util.out("  (all cite-tags match the register)\n", .{});
    } else {
        for (cite_mismatches.items) |m| {
            util.out("  MISMATCH  line {d}: [`{s}:{s}`] — register has [{s}]\n", .{
                m.line, m.id, m.tagged_status, m.register_status,
            });
        }
    }
    const c6 = cite_mismatches.items.len;
    util.out("\n  C6 cite-tag mismatches: {d}\n", .{c6});

    // ── C7 unabsorbed findings ────────────────────────────────────────────
    util.out("\n== C7  UNABSORBED FINDINGS (fails the run) ==\n", .{});
    util.out("Scans {s}/*.json for claim status changes not reflected in the register.\n", .{FINDINGS_DIR});
    util.out("A finding is unabsorbed when its proposed status differs from CLAIMS.md.\n\n", .{});
    const c7_results = try checkFindings(gpa, io, &reg, FINDINGS_DIR);
    const c7: usize = c7_results.unabsorbed;
    util.out("  files scanned: {d}\n", .{c7_results.files});
    util.out("  claims touched: {d}\n", .{c7_results.claims_total});
    util.out("  new-rows touched: {d}\n", .{c7_results.new_rows_total});
    if (c7_results.unabsorbed == 0) {
        util.out("  unabsorbed: 0 (all findings reflected in the register)\n", .{});
    } else {
        util.out("  unabsorbed: {d}\n", .{c7_results.unabsorbed});
        for (c7_results.items.items) |item| {
            util.out("  UNABSORBED  `{s}` — findings says `{s}`, register says `{s}`\n", .{
                item.id, item.proposed, item.actual,
            });
            if (item.file) |f| util.out("              in {s}\n", .{f});
        }
    }
    util.out("\n  C7 unabsorbed findings: {d}\n", .{c7});

    // ── A  repeated narrowing ───────────────────────────────────────────────
    util.out("\n== A  SMELL: repeated narrowing (report only) ==\n", .{});
    var smell: usize = 0;
    var smell_dead: usize = 0;
    var unknown_narrow: usize = 0;
    for (reg.rows.items) |r| {
        if (r.narrowed) |n| {
            if (n < 2) continue;
            smell += 1;
            if (r.status.isFalse()) smell_dead += 1;
            util.out("  SMELL: repeated narrowing — the representation may be wrong, not the claim.\n", .{});
            util.out("         `{s}` narrowed {d}× · now {s}\n", .{ r.id, n, r.status_raw });
        } else unknown_narrow += 1;
    }
    if (smell == 0) util.out("  (none)\n", .{});
    if (smell > 0) {
        util.out("\n  {d} of {d} repeatedly-narrowed claims are now FALSE. Repeated narrowing has\n", .{ smell_dead, smell });
        util.out("  so far predicted death in this register; the survivors are the ones to read.\n", .{});
    }
    util.out("\n  A total: {d} flagged, {d} rows with `narrowed` unknown\n", .{ smell, unknown_narrow });

    // ── B  weak evidence ────────────────────────────────────────────────────
    util.out("\n== B  WEAK EVIDENCE (report only) ==\n", .{});
    util.out("PROVEN rows whose wrong-answer-pass-rate is unknown or above 25%.\n", .{});
    var weak_unknown: usize = 0;
    var weak_high: std.ArrayList(usize) = .empty;
    var strong: std.ArrayList(usize) = .empty;
    for (reg.rows.items, 0..) |r, i| {
        if (r.status != .proven) continue;
        if (r.rate) |v| {
            if (v > 25.0) try weak_high.append(gpa, i) else try strong.append(gpa, i);
        } else weak_unknown += 1;
    }
    util.out("\n  WEAK EVIDENCE — stated rate above 25% ({d}):\n", .{weak_high.items.len});
    for (weak_high.items) |i| util.out("    `{s}`  rate {s}\n", .{ reg.rows.items[i].id, reg.rows.items[i].rate_raw });
    if (weak_high.items.len == 0) util.out("    (none)\n", .{});
    util.out("\n  WEAK EVIDENCE — rate not computed (`?`): {d} PROVEN rows\n", .{weak_unknown});
    util.out("  discriminating (rate stated and <= 25%): {d}\n", .{strong.items.len});
    for (strong.items) |i| util.out("    `{s}`  rate {s}\n", .{ reg.rows.items[i].id, reg.rows.items[i].rate_raw });

    // ── calibration ─────────────────────────────────────────────────────────
    util.out("\n== CALIBRATION (GLOBAL.CALIB-LESSON; roadmap §4 P3) ==\n", .{});
    util.out("A checker with no failing case proves nothing.\n\n", .{});
    var cal_ok = true;

    util.out("  known-bad 1 (C1): `{s}` must be reported with `{s}` in its chain … {s}\n", .{
        CAL_ORPHAN_CHILD, CAL_ORPHAN_ROOT, if (cal_orphan_hit) "CAUGHT" else "MISSED",
    });
    if (!cal_orphan_hit) cal_ok = false;

    var cal_dangling_hit = false;
    for (missing.items) |m| {
        if (std.mem.eql(u8, m.path, CAL_DANGLING)) cal_dangling_hit = true;
    }
    util.out("  known-bad 2 (C2): `{s}` must be reported … {s}\n", .{
        CAL_DANGLING, if (cal_dangling_hit) "CAUGHT" else "MISSED",
    });
    if (!cal_dangling_hit) cal_ok = false;

    var clean_ok = false;
    if (reg.by_id.get(CAL_CLEAN)) |k| {
        const r = reg.rows.items[k];
        var quiet = r.status == .proven;
        if (try shortestFalseChain(gpa, &reg, k) != null) quiet = false;
        for (missing.items) |m| {
            for (m.claims.items) |cid| if (std.mem.eql(u8, cid, CAL_CLEAN)) {
                quiet = false;
            };
        }
        clean_ok = quiet;
    }
    util.out("  known-good (C1+C2): PROVEN `{s}` with a real evidence path must be silent … {s}\n", .{
        CAL_CLEAN, if (clean_ok) "SILENT (correct)" else "FLAGGED (checker suspect)",
    });
    if (!clean_ok) cal_ok = false;

    // known-good/known-bad pair for the `n:` edge kind.
    var neg_ok_silent = false;
    if (reg.by_id.get(CAL_NEG_OK)) |k| {
        var has_n = false;
        for (reg.rows.items[k].deps.items) |d| if (d.kind == .negation) {
            has_n = true;
        };
        var alarmed = false;
        for (alarms.items) |a| if (a.child == k) {
            alarmed = true;
        };
        const orphaned = (try shortestFalseChain(gpa, &reg, k)) != null;
        neg_ok_silent = has_n and !alarmed and !orphaned;
    }
    util.out("  known-good (C1, `n:`): `{s}` — `n:` to a FALSE parent must be silent … {s}\n", .{
        CAL_NEG_OK, if (neg_ok_silent) "SILENT (correct)" else "FLAGGED or has no `n:` edge (checker suspect)",
    });
    if (!neg_ok_silent) cal_ok = false;

    var synth_ok = false;
    var synth_c5_ok = false;
    {
        var sreg = try parseRegister(gpa, CAL_SYNTHETIC);
        const salarms = try negationAlarms(gpa, &sreg);
        var saw_alarm = false;
        var saw_silent = true;
        for (salarms.items) |a| {
            const cid = sreg.rows.items[a.child].id;
            if (std.mem.eql(u8, cid, "GLOBAL.CALCHILD-ALARM")) saw_alarm = true;
            if (std.mem.eql(u8, cid, "GLOBAL.CALCHILD-OK")) saw_silent = false;
        }
        synth_ok = sreg.unparsed.items.len == 0 and sreg.rows.items.len == 7 and
            saw_alarm and saw_silent and salarms.items.len == 1;

        const sshadow = try shadowedEdges(gpa, &sreg);
        var saw_shadow = false;
        var saw_plain_silent = true;
        for (sshadow.items) |sh| {
            const cid = sreg.rows.items[sh.child].id;
            if (std.mem.eql(u8, cid, "GLOBAL.CALCHILD-SHADOW")) saw_shadow = true;
            if (std.mem.eql(u8, cid, "GLOBAL.CALCHILD-PLAIN")) saw_plain_silent = false;
        }
        synth_c5_ok = sreg.unparsed.items.len == 0 and saw_shadow and
            saw_plain_silent and sshadow.items.len == 1;
    }
    util.out("  known-bad 3 (C1b, synthetic): `n:` to a PROVEN parent must ALARM, `n:` to a\n", .{});
    util.out("                FALSE parent must not … {s}\n", .{if (synth_ok) "CAUGHT (1 alarm, 1 silent)" else "BROKEN"});
    if (!synth_ok) cal_ok = false;

    util.out("  known-bad 4 (C5, synthetic): `d:` onto a MEASUREMENT must be reported, `d:`\n", .{});
    util.out("                onto a real claim must not … {s}\n", .{if (synth_c5_ok) "CAUGHT (1 shadow, 1 silent)" else "BROKEN"});
    if (!synth_c5_ok) cal_ok = false;

    var shadow_clean = false;
    if (reg.by_id.get(CAL_SHADOW_CLEAN)) |k| {
        var any_meas = false;
        var any_d = false;
        for (reg.rows.items[k].deps.items) |d| {
            if (d.kind != .derives) continue;
            any_d = true;
            const t = reg.by_id.get(d.target) orelse continue;
            if (reg.rows.items[t].status == .measurement) any_meas = true;
        }
        shadow_clean = any_d and !any_meas;
    }
    util.out("  known-good (C5): `{s}` — every `d:` parent is a real claim, must be silent … {s}\n", .{
        CAL_SHADOW_CLEAN, if (shadow_clean) "SILENT (correct)" else "FLAGGED (checker suspect)",
    });
    if (!shadow_clean) cal_ok = false;

    // C6 calibration — process the synthetic narrative through citeTagCheck.
    // It must catch the wrong-status tag and pass the correct-status ones.
    var synth_c6_ok = false;
    {
        const syn_tags = try citeTags(gpa, CAL_SYNTHETIC_CITETAG);
        var saw_bad = false;
        var saw_good_a = false;
        var saw_good_b = false;
        var extra = false;
        for (syn_tags.items) |tag| {
            const slot = reg.by_id.get(tag.id) orelse {
                extra = true;
                continue;
            };
            const expected = reg.rows.items[slot].status;
            const tagged = parseStatus(tag.status);
            if (tagged != expected) {
                if (std.mem.eql(u8, tag.id, CAL_CITE_BAD_ID)) saw_bad = true;
            } else {
                if (std.mem.eql(u8, tag.id, CAL_CITE_GOOD_A)) saw_good_a = true;
                if (std.mem.eql(u8, tag.id, CAL_CITE_GOOD_B)) saw_good_b = true;
            }
        }
        synth_c6_ok = saw_bad and saw_good_a and saw_good_b and !extra and syn_tags.items.len == 3;
    }
    util.out("  known-bad 5 (C6, synthetic): `[{s}:PROVEN]` (register says FALSE-AS-SCOPED) must\n", .{CAL_CITE_BAD_ID});
    util.out("                be caught, while correct-status tags pass silently … {s}\n", .{if (synth_c6_ok) "CAUGHT (1 mismatch, 2 silent)" else "BROKEN"});
    if (!synth_c6_ok) cal_ok = false;

    // C7 calibration — synthetic findings JSON parsed in-memory against the
    // synthetic register extended with one deliberately-mismatched row.
    var synth_c7_ok = false;
    {
        const synth_ext = try std.fmt.allocPrint(gpa, "{s}{s}{s}", .{ CAL_SYNTHETIC, CAL_SYNTHETIC_C7_EXTRA, "\\n## 3. end\\n" });
        var sreg = try parseRegister(gpa, synth_ext);
        // Parse the synthetic findings JSON directly in-memory — no temp files.
        // parseFindingsFile takes the JSON byte slice and the register.
        const c7cal = try parseFindingsFile(gpa, CAL_SYNTHETIC_C7_JSON, "calibration/T999-cal.json", &sreg);
        var saw_mismatch = false;
        var saw_silent = false;
        for (c7cal.items.items) |item| {
            if (std.mem.eql(u8, item.id, "GLOBAL.CAL-SHOULDBE-FALSE")) saw_mismatch = true;
            if (std.mem.eql(u8, item.id, "GLOBAL.CALPARENT-DEAD")) saw_silent = true;
        }
        synth_c7_ok = c7cal.unabsorbed == 1 and saw_mismatch and !saw_silent and
            c7cal.files == 1 and c7cal.claims_total == 2;
    }
    util.out("  known-bad 6 (C7, synthetic): findings JSON with 2 claims — 1 absorbed\n", .{});
    util.out("                (GLOBAL.CALPARENT-DEAD matches), 1 unabsorbed status\n", .{});
    util.out("                mismatch (GLOBAL.CAL-SHOULDBE-FALSE: findings says\n", .{});
    util.out("                FALSE-AS-SCOPED, register says PROVEN) … {s}\n", .{if (synth_c7_ok) "CAUGHT (1 unabsorbed, 1 silent)" else "BROKEN"});
    if (!synth_c7_ok) cal_ok = false;

    util.out("\n  calibration: {s}\n", .{if (cal_ok) "PASS" else "FAIL — fix the checker before trusting the run"});

    // ── summary ─────────────────────────────────────────────────────────────
    util.out("\n== SUMMARY ==\n", .{});
    util.out("  rows parsed / unparsed        {d} / {d}\n", .{ reg.rows.items.len, reg.unparsed.items.len });
    util.out("  C1a orphans / C1b alarms      {d} / {d}   (FAILS)\n", .{ c1_count, alarms.items.len });
    util.out("  C2 dangling evidence paths    {d}   (FAILS)\n", .{c2_total});
    util.out("  C3 PROVEN w/o committed evid. {d}   (debt only, does not fail yet)\n", .{tierB.items.len + tierC.items.len});
    util.out("  C4 dangling IDs / unreferenced {d} / {d}   (report only, does not fail yet)\n", .{ dangling.count(), unref });
    util.out("  C5 shadowed dependencies      {d}   (report only, does not fail yet)\n", .{c5});
    util.out("  A  repeated-narrowing smells  {d}   (report only)\n", .{smell});
    util.out("  C6 cite-tag mismatches         {d}   (FAILS)\n", .{c6});
    util.out("  C7 unabsorbed findings         {d}   (FAILS)\n", .{c7});
    util.out("  calibration                   {s}\n", .{if (cal_ok) "PASS" else "FAIL"});

    if (reg.unparsed.items.len > 0) std.process.exit(3);
    if (!cal_ok) std.process.exit(2);
    if (c1_count > 0 or alarms.items.len > 0 or c2_total > 0 or c6 > 0 or c7 > 0) std.process.exit(1);
    std.process.exit(0);
}

fn spaces(n: usize) []const u8 {
    const pad = "                                        ";
    const k = @min(n * 2, pad.len);
    return pad[0..k];
}

fn missingLess(_: void, a: Missing, b: Missing) bool {
    if (a.bulk != b.bulk) return !a.bulk;
    if (a.claims.items.len != b.claims.items.len) return a.claims.items.len > b.claims.items.len;
    return std.mem.lessThan(u8, a.path, b.path);
}

fn noteMissing(
    gpa: Allocator,
    list: *std.ArrayList(Missing),
    seen: *std.StringHashMap(usize),
    path: []const u8,
    claim: []const u8,
    via: []const u8,
    from_column: bool,
) !void {
    if (seen.get(path)) |k| {
        const m = &list.items[k];
        var have_via = false;
        for (m.vias.items) |v| if (std.mem.eql(u8, v, via)) {
            have_via = true;
        };
        if (!have_via) try m.vias.append(gpa, via);
        for (m.claims.items) |c| if (std.mem.eql(u8, c, claim)) return;
        try m.claims.append(gpa, claim);
        return;
    }
    var claims: std.ArrayList([]const u8) = .empty;
    try claims.append(gpa, claim);
    var vias: std.ArrayList([]const u8) = .empty;
    try vias.append(gpa, via);
    const owned = try gpa.dupe(u8, path);
    try list.append(gpa, .{
        .path = owned,
        .claims = claims,
        .vias = vias,
        .bulk = endsWith(path, BULK_EXT),
        .from_column = from_column,
    });
    try seen.put(owned, list.items.len - 1);
}

// ── C7 findings checking ───────────────────────────────────────────────────

const C7Unabsorbed = struct { id: []const u8, proposed: []const u8, actual: []const u8, file: ?[]const u8 };

const C7Result = struct {
    files: usize,
    claims_total: usize,
    new_rows_total: usize,
    unabsorbed: usize,
    items: std.ArrayList(C7Unabsorbed),
};

/// JSON tokenizer for the flat findings format. Extracts a single string value
/// for a given key from a JSON object. Returns null if the key is not found or
/// the value is not a string. Handles escaped quotes and backslashes minimally
/// (enough for the findings schema, which has no embedded JSON strings).
fn jsonStringValue(gpa: Allocator, json: []const u8, key: []const u8, out: *std.ArrayList(u8)) !bool {
    out.clearRetainingCapacity();
    var i: usize = 0;
    while (i < json.len) {
        if (json[i] != '"') { i += 1; continue; }
        const key_start = i + 1;
        const key_end = std.mem.indexOfScalarPos(u8, json, key_start, '"') orelse return false;
        const found_key = json[key_start..key_end];
        i = key_end + 1;
        // skip whitespace and colon
        while (i < json.len and (json[i] == ' ' or json[i] == '\t' or json[i] == '\n' or json[i] == '\r')) : (i += 1) {}
        if (i >= json.len or json[i] != ':') continue;
        i += 1;
        while (i < json.len and (json[i] == ' ' or json[i] == '\t' or json[i] == '\n' or json[i] == '\r')) : (i += 1) {}
        if (i >= json.len) return false;
        if (!std.mem.eql(u8, found_key, key)) continue;
        if (json[i] != '"') return false; // non-string value for a string field
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

/// Parse a single findings JSON file. Returns a C7Result with the claims and
/// new_rows extracted. The caller must compare these against the register.
fn parseFindingsFile(gpa: Allocator, json: []const u8, file_path: []const u8, reg: *Register) !C7Result {
    var result: C7Result = .{
        .files = 1,
        .claims_total = 0,
        .new_rows_total = 0,
        .unabsorbed = 0,
        .items = .empty,
    };

    // file_path may be a temporary (e.g. from a Dir.Walker); dupe it once
    const owned_file = try gpa.dupe(u8, file_path);

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(gpa);

    // Extract task_id (for reporting)
    _ = try jsonStringValue(gpa, json, "task_id", &buf);

    // Count claims[] entries and check each against the register.
    // We look for "id" fields inside objects within the "claims" array.
    var in_claims = false;
    var i: usize = 0;
    while (i < json.len) : (i += 1) {
        if (json[i] != '"') continue;
        const ks = i + 1;
        const ke = std.mem.indexOfScalarPos(u8, json, ks, '"') orelse break;
        const k = json[ks..ke];
        i = ke + 1;
        if (std.mem.eql(u8, k, "claims")) {
            // skip to opening [
            while (i < json.len and json[i] != '[') : (i += 1) {}
            if (i >= json.len) break;
            in_claims = true;
            continue;
        }
        if (in_claims and std.mem.eql(u8, k, "id")) {
            // skip whitespace, colon, whitespace
            while (i < json.len and (json[i] == ' ' or json[i] == '\t' or json[i] == '\n' or json[i] == '\r' or json[i] == ':')) : (i += 1) {}
            if (i < json.len and json[i] == '"') {
                buf.clearRetainingCapacity();
                i += 1;
                while (i < json.len) {
                    if (json[i] == '\\' and i + 1 < json.len) {
                        try buf.append(gpa, json[i + 1]);
                        i += 2;
                        continue;
                    }
                    if (json[i] == '"') break;
                    try buf.append(gpa, json[i]);
                    i += 1;
                }
                const claim_id = try gpa.dupe(u8, buf.items);

                // Now find the proposed_status for this claim
                var proposed: []const u8 = "?";
                var j = i + 1;
                while (j < json.len) {
                    if (json[j] != '"') { j += 1; continue; }
                    const pks = j + 1;
                    const pke = std.mem.indexOfScalarPos(u8, json, pks, '"') orelse break;
                    const pk = json[pks..pke];
                    j = pke + 1;
                    if (std.mem.eql(u8, pk, "proposed_status")) {
                        while (j < json.len and (json[j] == ' ' or json[j] == '\t' or json[j] == '\n' or json[j] == '\r' or json[j] == ':')) : (j += 1) {}
                        if (j < json.len and json[j] == '"') {
                            j += 1;
                            var pbuf: std.ArrayList(u8) = .empty;
                            defer pbuf.deinit(gpa);
                            while (j < json.len) {
                                if (json[j] == '\\' and j + 1 < json.len) {
                                    try pbuf.append(gpa, json[j + 1]);
                                    j += 2;
                                    continue;
                                }
                                if (json[j] == '"') break;
                                try pbuf.append(gpa, json[j]);
                                j += 1;
                            }
                            proposed = try gpa.dupe(u8, pbuf.items);
                        }
                        break;
                    }
                    // skip past nested objects/arrays
                    if (json[j] == '{') {
                        var depth: usize = 1;
                        j += 1;
                        while (j < json.len and depth > 0) : (j += 1) {
                            if (json[j] == '{') depth += 1;
                            if (json[j] == '}') depth -= 1;
                        }
                        continue;
                    }
                }

                result.claims_total += 1;

                // Check against register
                if (reg.by_id.get(claim_id)) |slot| {
                    const r = reg.rows.items[slot];
                    const ps = parseStatus(proposed);
                    if (ps != .unparsed and ps != r.status) {
                        result.unabsorbed += 1;
                        try result.items.append(gpa, .{
                            .id = claim_id,
                            .proposed = proposed,
                            .actual = r.status.name(),
                            .file = owned_file,
                        });
                    }
                } else {
                    // Claim ID not in register — report as unabsorbed
                    result.unabsorbed += 1;
                    try result.items.append(gpa, .{
                        .id = claim_id,
                        .proposed = proposed,
                        .actual = "NO SUCH ID",
                        .file = owned_file,
                    });
                }
            }
        }
        if (in_claims and std.mem.eql(u8, k, "new_rows")) {
            // Count new-rows entries. For each new-row, check if the ID exists
            // in the register with the proposed status.
            var nr_depth: usize = 0;
            var nr_count: usize = 0;
            var nr_i = i + 1;
            while (nr_i < json.len) : (nr_i += 1) {
                if (json[nr_i] == '{') nr_depth += 1;
                if (json[nr_i] == '}') {
                    if (nr_depth > 0) nr_depth -= 1;
                    if (nr_depth == 0 and nr_count > 0) break;
                }
                if (nr_depth == 1 and json[nr_i] == '"') {
                    const nks = nr_i + 1;
                    const nke = std.mem.indexOfScalarPos(u8, json, nks, '"') orelse break;
                    const nk = json[nks..nke];
                    nr_i = nke;
                    if (std.mem.eql(u8, nk, "id")) {
                        nr_count += 1;
                        result.new_rows_total += 1;
                        // Extract the new-row id and status
                        while (nr_i < json.len and (json[nr_i] == ' ' or json[nr_i] == '\t' or json[nr_i] == '\n' or json[nr_i] == '\r' or json[nr_i] == ':' or json[nr_i] == '"')) : (nr_i += 1) {}
                        var nid_buf: std.ArrayList(u8) = .empty;
                        defer nid_buf.deinit(gpa);
                        while (nr_i < json.len) {
                            if (json[nr_i] == '\\' and nr_i + 1 < json.len) {
                                try nid_buf.append(gpa, json[nr_i + 1]);
                                nr_i += 2;
                                continue;
                            }
                            if (json[nr_i] == '"') break;
                            try nid_buf.append(gpa, json[nr_i]);
                            nr_i += 1;
                        }
                        const nr_id = try gpa.dupe(u8, nid_buf.items);

                        // Find "status" field within this new-row object
                        var nr_proposed: []const u8 = "?";
                        var ns = nr_i + 1;
                        var ns_depth: usize = 1;
                        while (ns < json.len) : (ns += 1) {
                            if (json[ns] == '{') ns_depth += 1;
                            if (json[ns] == '}') {
                                ns_depth -= 1;
                                if (ns_depth == 0) break;
                            }
                            if (json[ns] != '"') continue;
                            const sks = ns + 1;
                            const ske = std.mem.indexOfScalarPos(u8, json, sks, '"') orelse break;
                            const sk = json[sks..ske];
                            ns = ske;
                            if (std.mem.eql(u8, sk, "status")) {
                                while (ns < json.len and (json[ns] == ' ' or json[ns] == '\t' or json[ns] == '\n' or json[ns] == '\r' or json[ns] == ':')) : (ns += 1) {}
                                if (ns < json.len and json[ns] == '"') {
                                    ns += 1;
                                    var sbuf: std.ArrayList(u8) = .empty;
                                    defer sbuf.deinit(gpa);
                                    while (ns < json.len) {
                                        if (json[ns] == '\\' and ns + 1 < json.len) {
                                            try sbuf.append(gpa, json[ns + 1]);
                                            ns += 2;
                                            continue;
                                        }
                                        if (json[ns] == '"') break;
                                        try sbuf.append(gpa, json[ns]);
                                        ns += 1;
                                    }
                                    nr_proposed = try gpa.dupe(u8, sbuf.items);
                                }
                                break;
                            }
                        }

                        // Check if the new-row ID is in the register
                        if (reg.by_id.get(nr_id)) |slot| {
                            const r = reg.rows.items[slot];
                            const nps = parseStatus(nr_proposed);
                            if (nps != .unparsed and nps != r.status) {
                                result.unabsorbed += 1;
                                try result.items.append(gpa, .{
                                    .id = nr_id,
                                    .proposed = nr_proposed,
                                    .actual = r.status.name(),
                                    .file = owned_file,
                                });
                            }
                        } else {
                            // New row never added — unabsorbed
                            result.unabsorbed += 1;
                            try result.items.append(gpa, .{
                                .id = nr_id,
                                .proposed = nr_proposed,
                                .actual = "MISSING (row never added)",
                                .file = owned_file,
                            });
                        }
                    }
                }
            }
            in_claims = false; // past claims[] now
        }
    }

    return result;
}

/// Scan findings/*.json and check every claim against the register.
/// Returns a C7Result with counts and unabsorbed items.
fn checkFindings(gpa: Allocator, io: Io, reg: *Register, dir_path: []const u8) !C7Result {
    var result: C7Result = .{
        .files = 0,
        .claims_total = 0,
        .new_rows_total = 0,
        .unabsorbed = 0,
        .items = .empty,
    };

    var dir = Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true }) catch |e| {
        if (e == error.FileNotFound) return result;
        return e;
    };
    defer dir.close(io);

    var w = try dir.walkSelectively(gpa);
    defer w.deinit();
    while (try w.next(io)) |e| {
        if (e.kind != .file) continue;
        if (!std.mem.endsWith(u8, e.basename, ".json")) continue;
        // e.path is relative to the walked dir; read via dir, not cwd
        const body = dir.readFileAlloc(io, e.path, gpa, .unlimited) catch continue;
        const fr = try parseFindingsFile(gpa, body, e.path, reg);
        result.files += 1;
        result.claims_total += fr.claims_total;
        result.new_rows_total += fr.new_rows_total;
        result.unabsorbed += fr.unabsorbed;
        try result.items.appendSlice(gpa, fr.items.items);
    }

    return result;
}

const Alarm = struct { child: usize, parent: usize };

/// `d:` edges whose parent can never be FALSE (a MEASUREMENT or a definition).
/// Such an edge is a dead end: no falsification can ever travel it, so if the
/// child's real dependency is the *soundness* behind the measurement, that
/// parent is missing and C1a will never see the child.
fn shadowedEdges(gpa: Allocator, reg: *Register) !std.ArrayList(Alarm) {
    var out: std.ArrayList(Alarm) = .empty;
    for (reg.rows.items, 0..) |r, i| {
        for (r.deps.items) |d| {
            if (d.kind != .derives) continue;
            const k = reg.by_id.get(d.target) orelse continue;
            const ps = reg.rows.items[k].status;
            if (ps != .measurement and ps != .definition) continue;
            try out.append(gpa, .{ .child = i, .parent = k });
        }
    }
    return out;
}

/// `n:` edges pointing at a parent that is NOT false. The inverse of C1a: the
/// child was adopted *because* the parent was refuted, so a parent that is no
/// longer refuted removes the child's reason to exist.
fn negationAlarms(gpa: Allocator, reg: *Register) !std.ArrayList(Alarm) {
    var out: std.ArrayList(Alarm) = .empty;
    for (reg.rows.items, 0..) |r, i| {
        for (r.deps.items) |d| {
            if (d.kind != .negation) continue;
            const k = reg.by_id.get(d.target) orelse continue;
            if (reg.rows.items[k].status.isFalse()) continue;
            try out.append(gpa, .{ .child = i, .parent = k });
        }
    }
    return out;
}

/// Breadth-first over `derives-from` edges; returns the shortest chain from
/// row `start` to a FALSE ancestor, or null. Cycles are real in this graph
/// (GLOBAL.C4 ⟵d GLOBAL.P3 ⟵d GLOBAL.C4), so the visited set is load-bearing.
fn shortestFalseChain(gpa: Allocator, reg: *Register, start: usize) !?std.ArrayList(usize) {
    var parent = std.AutoHashMap(usize, usize).init(gpa);
    defer parent.deinit();
    var queue: std.ArrayList(usize) = .empty;
    defer queue.deinit(gpa);
    try queue.append(gpa, start);
    try parent.put(start, start);
    var head: usize = 0;
    while (head < queue.items.len) : (head += 1) {
        const cur = queue.items[head];
        for (reg.rows.items[cur].deps.items) |d| {
            if (d.kind != .derives) continue;
            const k = reg.by_id.get(d.target) orelse continue;
            if (parent.contains(k)) continue;
            try parent.put(k, cur);
            if (reg.rows.items[k].status.isFalse()) {
                var rev: std.ArrayList(usize) = .empty;
                var node = k;
                while (node != start) {
                    try rev.append(gpa, node);
                    node = parent.get(node).?;
                }
                var chain: std.ArrayList(usize) = .empty;
                var i = rev.items.len;
                while (i > 0) {
                    i -= 1;
                    try chain.append(gpa, rev.items[i]);
                }
                rev.deinit(gpa);
                return chain;
            }
            try queue.append(gpa, k);
        }
    }
    return null;
}
