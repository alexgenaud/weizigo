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
const version = @import("version");

const alloc = std.heap.page_allocator;

// ── Writers: stdout for data, stderr for diagnostics ────────────────────────

const Writers = struct {
    io: std.Io,

    /// Write data to stdout — anything a caller might parse, filter, or redirect.
    /// Uses `writeStreamingAll` (direct streaming write) instead of creating a
    /// `File.Writer` with a local 4096 B buffer; the writer goes through a
    /// positional→streaming fallback on every call when stdout is a pipe,
    /// and under certain conditions the positional retry path produces
    /// truncated and reordered output (T122).
    fn data(self: Writers, comptime fmt: []const u8, args: anytype) void {
        const buf = std.fmt.allocPrint(alloc, fmt, args) catch return;
        defer alloc.free(buf);
        std.Io.File.stdout().writeStreamingAll(self.io, buf) catch {};
    }

    /// Write diagnostics to stderr — warnings, errors, progress chatter.
    fn diag(_: Writers, comptime fmt: []const u8, args: anytype) void {
        std.debug.print(fmt, args);
    }
};

// ── UTF-8-safe truncation (T569) ─────────────────────────────────────────────

/// Truncate `s` to at most `max` bytes without splitting a multi-byte UTF-8
/// sequence. Backs the cut off past continuation bytes (0b10xxxxxx) so the
/// slice never ends mid-character: a continuation byte at the cut means the
/// character's lead byte is inside the slice and its remaining continuation
/// bytes are at/after the cut.
fn utf8Truncate(s: []const u8, max: usize) []const u8 {
    if (s.len <= max) return s;
    var end = max;
    while (end > 0 and (s[end] & 0xC0) == 0x80) end -= 1;
    return s[0..end];
}

test "utf8Truncate never splits a multi-byte UTF-8 sequence" {
    const cases = [_][]const u8{
        "",
        "plain ascii command",
        "é accent",
        "arrow → inside",
        "emoji 😀 inside",
        "mixed é→😀 and ascii",
    };
    for (cases) |s| {
        var max: usize = 0;
        while (max <= s.len) : (max += 1) {
            const t = utf8Truncate(s, max);
            if (!std.unicode.utf8ValidateSlice(t)) {
                std.debug.print("utf8Truncate({s}, {d}) => invalid UTF-8\n", .{ s, max });
                return error.InvalidUtf8;
            }
        }
    }
    const expect = std.testing.expect;
    try expect(std.mem.eql(u8, utf8Truncate("aé", 2), "a")); // drops the 2-byte é
    try expect(std.mem.eql(u8, utf8Truncate("ab→", 4), "ab")); // drops the 3-byte →
    try expect(std.mem.eql(u8, utf8Truncate("plain", 3), "pla"));
    try expect(std.mem.eql(u8, utf8Truncate("plain", 99), "plain"));
}

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
    model: ?[]const u8 = null,
    // T544: attribution provenance.  model_source is null for first-hand
    // attribution (recorded at claim/done/dispatch by the worker or seat) and
    // set to the recovering source for backfilled values ("perf-ledger" /
    // "run-record" / "agent-field") or the conflict marker when a wrong
    // stored model was corrected ("conflict:<old>-><new>").  A model value
    // of "unattributed" / "unattributed-pre-T544" is a first-class state —
    // the data is gone — not a null, so aggregations exclude it by name.
    model_source: ?[]const u8 = null,
    model_unknown_reason: ?[]const u8 = null,
    // T635: mechanized assignment record (ruling 33).  `candidates` is the
    // qualified list the draw was made from; `method` is random | forced |
    // preferred; `assign_reasons` is one "<model>: <why>" line per excluded
    // candidate (and any preferred-outside-qualified note).  Null/empty on a
    // row that predates this field — historical rows stay honestly blank,
    // never back-filled with a guess.
    candidates: [][]const u8 = &.{},
    method: ?[]const u8 = null,
    assign_reasons: [][]const u8 = &.{},
    // T636: row shape (ruling 34) — "solo" | "panel" | null.  null = legacy:
    // an existing row with no shape behaves exactly as before T636 (T635's
    // random/preferred/forced draw) and is never retroactively labelled.
    // New rows registered without an explicit shape get the honest default
    // (solo) at registration — see cmdAdd.
    shape: ?[]const u8 = null,
    // T636: shape-selection notes — one "<model>: <why>" line per selection
    // decision (cost comparison for solo, marginal-complementarity step for
    // panel).  Empty when the assignment came from the legacy draw.
    shape_reasons: [][]const u8 = &.{},
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
    verdict: ?[]const u8 = null,
    verdict_note: ?[]const u8 = null,
    // T522: impression-or-waiver gate.  Every close must carry exactly one
    // non-empty field: `impression` (how the model performed on this task
    // type) or `impression_waiver` (the explicit reason no impression is
    // owed).  Recorded on the row so close_completeness is computable
    // (measurement-methodology §6) and model-perf cannot lapse silently —
    // the failure the operator caught twice (fleet-and-model-audit §3).
    impression: ?[]const u8 = null,
    impression_waiver: ?[]const u8 = null,
    acceptance: ?[]const u8 = null,
    skip_acceptance_reason: ?[]const u8 = null,
    claim_count: u32 = 0,
    // T478: duty fields.  A duty is beneficial work that never completes
    // (docs/infra/duties.md): recognised via the bundle meta header's `duty`
    // key or the --duty flag on `add`; stored so status/next/landmark need not
    // re-read every bundle.  Due-count is closes-based, not clock-based:
    // last_chunk_closes is the _sys.closes value at the last chunk (or at
    // registration); the duty is due once _sys.closes has advanced due_after
    // past it.
    duty: bool = false,
    due_after: u32 = 5,
    last_chunk_closes: u64 = 0,
    last_chunk_ts: ?[]const u8 = null,
    last_chunk_verdict: ?[]const u8 = null,
    last_chunk_findings: ?[]const u8 = null,
    // T317: append-only correction record.  managent done is terminal;
    // amend appends corrections without erasing the original verdict.
    amendments: [][]const u8 = &.{},
    // T464: one-line epitaph left when a row is retired from the live kanban
    // (archive, never delete — the full record moves, this one line stays).
    epitaph: ?[]const u8 = null,
    // T627: dispatch scope fields (ruling 35 denominator).  Written by the
    // tool at dispatch/claim time, never requested of workers.  null means
    // ABSENT = UNKNOWN (an old row predates the field), which is distinct
    // from 0 or "none" and must never render downstream as zero coverage or
    // full marks.  brief_bytes is the bundle file size; files_in_scope is the
    // count of unique deliverables= + holds= paths; expected_wall_s is the
    // dispatcher's wall estimate (--expected-wall), null when none was made —
    // never 0, which would masquerade as "instant".
    brief_bytes: ?u64 = null,
    files_in_scope: ?u32 = null,
    expected_wall_s: ?u32 = null,
    // ruling 35: the scope field must carry an enumerated target set (the
    // thoroughness denominator), or say explicitly that the set cannot be
    // enumerated in advance.  scope_enumerable == null → no scope statement
    // recorded (UNKNOWN); true → scope_targets is the enumeration; false →
    // the target set genuinely cannot be enumerated (scope_note says why).
    scope_targets: [][]const u8 = &.{},
    scope_enumerable: ?bool = null,
    scope_note: ?[]const u8 = null,
};

const valid_verdicts = [_][]const u8{ "pass", "pass-with-findings", "fail-found", "blocked", "abandoned" };

// ── T317: canonical model labels — single source of truth ────────────────
// Every model the project recognizes.  agents / claim / done / ollama-subagent
// must emit only these spellings.  Add new models here; a second copy is the
// divergence this project keeps paying for (AGENTS.md §model-perf ledger).
// Shape notes: Anthropic labels carry the vendor prefix; Haiku carries a dated
// snapshot suffix.  Validate against this list, never a regex.
const canonical_models = [_][]const u8{
    "claude-opus-5",
    "claude-sonnet-5",
    "claude-fable-5",
    "claude-haiku-4-5-20251001",
    "deepseek-v4-pro",
    "deepseek-v4-flash",
    "glm-5.2",
    "minimax-m3",
    "kimi-k2.7",
    "qwen3.8:27b-mlx",
    "ox-alpha",
};

fn isCanonicalModel(s: []const u8) bool {
    for (canonical_models) |m| {
        if (std.mem.eql(u8, m, s)) return true;
    }
    return false;
}

/// Print the canonical set to stderr — used in rejection messages so the
/// caller can see what is accepted without reading source.
fn printCanonicalModels(w: Writers) void {
    w.diag("  canonical models:", .{});
    for (canonical_models, 0..) |m, i| {
        if (i > 0) w.diag(",", .{});
        w.diag(" {s}", .{m});
    }
    w.diag("\n", .{});
}

/// Serving tag → canonical label map — the ONLY place the non-`:cloud`
/// serving-tag divergences live (T801: one canonicalizer, not four).  A
/// serving tag on the left never reaches a record; the stored value is
/// always the canonical label on the right.  `managent models --tags`
/// exports this table + the `:cloud` strip so the Python readers
/// (token-capture, model-profiles, runner) RESOLVE the transform from this
/// one source instead of reimplementing it and drifting.
const serving_tag_map = [_]struct { serving: []const u8, canonical: []const u8 }{
    .{ .serving = "kimi-k2.7-code", .canonical = "kimi-k2.7" },
    .{ .serving = "stealth/ox-alpha", .canonical = "ox-alpha" },
};

/// The generic serving-tag suffix stripped before the map is applied.
const serving_tag_strip_suffix = ":cloud";

/// Strip Ollama's :cloud tag suffix and any serving-tag divergence before
/// comparing against the canonical set.  The raw dispatch tag (e.g.
/// kimi-k2.7-code:cloud) is accepted as input convenience; the stored value
/// is always canonical.  This is the single transform; the rejection of an
/// unrecognized tag lives at the boundary (`managent canonicalize` / the
/// Python readers), never as a silent pass-through in a reader.
fn canonicalizeModelTag(raw: []const u8) []const u8 {
    // Strip the :cloud suffix first
    var s = raw;
    if (std.mem.endsWith(u8, s, serving_tag_strip_suffix)) {
        s = s[0 .. s.len - serving_tag_strip_suffix.len];
    }
    for (serving_tag_map) |m| {
        if (std.mem.eql(u8, s, m.serving)) return m.canonical;
    }
    return s;
}

test "canonicalizeModelTag: serving tags and :cloud strip map to canonical" {
    const cases = [_][2][]const u8{
        .{ "glm-5.2:cloud", "glm-5.2" },
        .{ "minimax-m3:cloud", "minimax-m3" },
        .{ "kimi-k2.7-code", "kimi-k2.7" },
        .{ "kimi-k2.7-code:cloud", "kimi-k2.7" },
        .{ "stealth/ox-alpha", "ox-alpha" },
    };
    for (cases) |c| {
        try std.testing.expectEqualStrings(c[1], canonicalizeModelTag(c[0]));
    }
    // null control: every canonical label maps to itself
    for (canonical_models) |m| {
        try std.testing.expectEqualStrings(m, canonicalizeModelTag(m));
    }
    // an unrecognized tag is NOT canonical — the boundary rejects it
    try std.testing.expect(!isCanonicalModel(canonicalizeModelTag("kimi-k2-thinking:cloud")));
}

// ── T635: mechanized model assignment (ruling 33) ──────────────────────────
// Randomization is mechanized, never improvised.  When several qualified
// models would do for a row, the assignment is drawn from the qualified list
// by THIS code, and the row records `candidates`, `method` (random | forced |
// preferred), and the draw.  Only `method=random` rows are unconfounded;
// everything else is observational (ruling 33).
//
// Family membership mirrors canonical_models[]; appetite mirrors
// measurement-methodology.md §1 (that table is the authority — this mirror
// must move in step with it).  A canonical model without a family/appetite
// row is refused (see the completeness test below) rather than silently
// drawn — the F7 divergence this single source exists to prevent.

const Appetite = enum {
    off,
    probe,
    conserve,
    spend,
    reserved,
};

const ModelFamily = struct {
    model: []const u8,
    family: []const u8,
};

const FamilyAppetite = struct {
    family: []const u8,
    appetite: Appetite,
};

// model → family (every canonical model appears exactly once — completeness
// test below).  Family names are the §1 table rows.
const model_families = [_]ModelFamily{
    .{ .model = "claude-opus-5", .family = "claude" },
    .{ .model = "claude-sonnet-5", .family = "claude" },
    .{ .model = "claude-haiku-4-5-20251001", .family = "claude" },
    .{ .model = "claude-fable-5", .family = "claude-fable" },
    .{ .model = "deepseek-v4-pro", .family = "deepseek" },
    .{ .model = "deepseek-v4-flash", .family = "deepseek" },
    .{ .model = "glm-5.2", .family = "ollama-cloud" },
    .{ .model = "minimax-m3", .family = "ollama-cloud" },
    .{ .model = "kimi-k2.7", .family = "ollama-cloud" },
    .{ .model = "qwen3.8:27b-mlx", .family = "local" },
    // T732: ox-alpha — stealth model, family UNKNOWN (identity sealed pending
    // reveal).  Its own family keeps it out of the auto-draw roster; re-keyed
    // to the real family on reveal.
    .{ .model = "ox-alpha", .family = "ox-alpha" },
};

// family → appetite, mirroring measurement-methodology.md §1 (2026-08-22).
// T834 (operator ruling 2026-08-24): ollama-cloud returns OFF → SPEND
// (glm / minimax / kimi back on the roster).  The five-level enum has no
// 0–9 dial, so the operator's equal-opportunity dial 5 is expressed here
// only as the class SPEND — permitted-equally, not drawn-equally (the dial
// is the S06 spec ORC-POL-3 mechanism; see docs/infra/model-registry.md).
// claude-fable is RESERVED (never one-off/general); local is PROBE
// (probe-flagged rows only).
const family_appetite = [_]FamilyAppetite{
    .{ .family = "ollama-cloud", .appetite = .spend },
    .{ .family = "claude", .appetite = .spend },
    .{ .family = "claude-fable", .appetite = .reserved },
    .{ .family = "deepseek", .appetite = .spend },
    .{ .family = "local", .appetite = .probe },
    // Operator ruling 2026-08-23 (supersedes T732's RESERVED): ox-alpha is
    // free while the blind test runs — draw and compare it at every
    // reasonable opportunity; never penalize it on speed (throttling observed).
    .{ .family = "ox-alpha", .appetite = .spend },
};

fn familyOf(model: []const u8) ?[]const u8 {
    for (model_families) |mf| {
        if (std.mem.eql(u8, mf.model, model)) return mf.family;
    }
    return null;
}

fn appetiteOf(family: []const u8) ?Appetite {
    for (family_appetite) |fa| {
        if (std.mem.eql(u8, fa.family, family)) return fa.appetite;
    }
    return null;
}

fn appetiteName(a: Appetite) []const u8 {
    return switch (a) {
        .off => "OFF",
        .probe => "PROBE",
        .conserve => "CONSERVE",
        .spend => "SPEND",
        .reserved => "RESERVED",
    };
}

fn isFamilyName(s: []const u8) bool {
    for (family_appetite) |fa| {
        if (std.mem.eql(u8, fa.family, s)) return true;
    }
    return false;
}

/// The outcome of a mechanized assignment.  Every slice is owned by the page
/// allocator; free with freeAssignResult.
const AssignResult = struct {
    candidates: [][]const u8 = &.{},
    reasons: [][]const u8 = &.{},
    method: []const u8 = "", // "random" | "forced" | "preferred" | "solo-least-data" | "panel-greedy" | "panel-prior"
    model: []const u8 = "", // the outcome (canonical label)
    // T636: shape-selection notes — one "<model>: <why>" line per selection
    // decision (cost comparison for solo, marginal-complementarity step for
    // panel).  Empty when the assignment came from the legacy T635 draw.
    shape_reasons: [][]const u8 = &.{},
};

fn freeAssignResult(r: *AssignResult) void {
    for (r.candidates) |c| alloc.free(c);
    alloc.free(r.candidates);
    for (r.reasons) |x| alloc.free(x);
    alloc.free(r.reasons);
    alloc.free(r.method);
    alloc.free(r.model);
    for (r.shape_reasons) |x| alloc.free(x);
    alloc.free(r.shape_reasons);
    r.* = .{};
}

/// Uniform draw over `candidates` (caller guarantees non-empty).  Returns an
/// owned copy of the chosen label.
fn drawCandidate(rng: std.Random, candidates: []const []const u8) ![]const u8 {
    return alloc.dupe(u8, candidates[rng.uintLessThan(usize, candidates.len)]);
}

/// OS-entropy `std.Random`: every fill reads fresh kernel entropy via
/// `std.Io.randomSecure` (getrandom/arc4random — always a syscall, no stored
/// state, no caller-chosen seed).  EntropyUnavailable is a panic, never a
/// silent fallback to a seeded PRNG (ruling 33).
const OsEntropy = struct {
    io: std.Io,
    fn fill(self: *OsEntropy, buf: []u8) void {
        self.io.randomSecure(buf) catch @panic("OS entropy unavailable (Io.randomSecure failed); refusing to draw from a fallback source");
    }
};

/// T635 filter: canonical_models through the constraints that apply (family
/// appetite, row-declared exclusions).  Returns two owned ArrayLists so
/// callers can append further reasons (e.g. the preferred-outside-qualified
/// note) before the lists are frozen into an AssignResult.  Free with
/// deinitQualified.
const QualifiedLists = struct {
    candidates: std.ArrayList([]const u8),
    reasons: std.ArrayList([]const u8),
};

fn deinitQualified(q: *QualifiedLists) void {
    for (q.candidates.items) |c| alloc.free(c);
    q.candidates.deinit(alloc);
    for (q.reasons.items) |x| alloc.free(x);
    q.reasons.deinit(alloc);
    q.* = undefined;
}

fn filterQualified(exclusions: []const []const u8) !QualifiedLists {
    var candidates = std.ArrayList([]const u8).empty;
    var reasons = std.ArrayList([]const u8).empty;
    errdefer {
        for (candidates.items) |c| alloc.free(c);
        candidates.deinit(alloc);
        for (reasons.items) |x| alloc.free(x);
        reasons.deinit(alloc);
    }

    for (canonical_models) |m| {
        const fam = familyOf(m) orelse {
            try reasons.append(alloc, try std.fmt.allocPrint(alloc, "{s}: no family mapping (add it to model_families)", .{m}));
            continue;
        };
        const app = appetiteOf(fam) orelse {
            try reasons.append(alloc, try std.fmt.allocPrint(alloc, "{s}: no appetite for family {s} (add it to family_appetite)", .{ m, fam }));
            continue;
        };
        if (app == .off) {
            try reasons.append(alloc, try std.fmt.allocPrint(alloc, "{s}: appetite OFF for family {s}", .{ m, fam }));
            continue;
        }
        if (app == .reserved) {
            try reasons.append(alloc, try std.fmt.allocPrint(alloc, "{s}: family {s} appetite RESERVED (reserved task types only)", .{ m, fam }));
            continue;
        }
        if (app == .probe) {
            try reasons.append(alloc, try std.fmt.allocPrint(alloc, "{s}: family {s} appetite PROBE (probe-flagged rows only)", .{ m, fam }));
            continue;
        }
        var excluded = false;
        for (exclusions) |tok| {
            if (std.mem.eql(u8, tok, fam)) {
                try reasons.append(alloc, try std.fmt.allocPrint(alloc, "{s}: excluded by row (family {s})", .{ m, fam }));
                excluded = true;
                break;
            }
            if (std.mem.eql(u8, tok, m)) {
                try reasons.append(alloc, try std.fmt.allocPrint(alloc, "{s}: excluded by row (model {s})", .{ m, m }));
                excluded = true;
                break;
            }
        }
        if (excluded) continue;
        try candidates.append(alloc, try alloc.dupe(u8, m));
    }

    return .{ .candidates = candidates, .reasons = reasons };
}

/// The mechanized assignment (ruling 33): filter canonical_models through the
/// constraints that apply, then pick the outcome.  `requested` (non-null)
/// forces `preferred`; a one-element qualified list forces `forced`;
/// otherwise the draw is `random` via `rng` (production passes OS entropy;
/// tests may pass a seeded PRNG — the production draw is never a seeded PRNG).
/// `exclusions` is a list of tokens, each a family name or a canonical model.
fn assignModel(requested: ?[]const u8, exclusions: []const []const u8, rng: std.Random) !AssignResult {
    var lists = try filterQualified(exclusions);
    errdefer deinitQualified(&lists);

    var method: []const u8 = undefined;
    var model: []const u8 = undefined;
    if (requested) |req| {
        method = try alloc.dupe(u8, "preferred");
        model = try alloc.dupe(u8, req);
        var in_list = false;
        for (lists.candidates.items) |c| {
            if (std.mem.eql(u8, c, req)) {
                in_list = true;
                break;
            }
        }
        if (!in_list) {
            try lists.reasons.append(alloc, try std.fmt.allocPrint(alloc, "{s}: preferred by row (outside qualified list)", .{req}));
        }
    } else if (lists.candidates.items.len == 0) {
        return error.NoQualifiedCandidate;
    } else if (lists.candidates.items.len == 1) {
        method = try alloc.dupe(u8, "forced");
        model = try alloc.dupe(u8, lists.candidates.items[0]);
    } else {
        method = try alloc.dupe(u8, "random");
        model = try drawCandidate(rng, lists.candidates.items);
    }

    return .{
        .candidates = try lists.candidates.toOwnedSlice(alloc),
        .reasons = try lists.reasons.toOwnedSlice(alloc),
        .method = method,
        .model = model,
    };
}

// ── T636: row shape — solo ladder, panel compose (ruling 34) ──────────────
// Every row has a shape.  Solo (single-lane: implementation, bookkeeping,
// infra) picks the cheapest qualified model by measured cost.  Panel
// (union-valued: audits, races, adjudication) anchors then adds the model
// expected to contribute the most unique catches per token given the seats
// already filled.  shape == null is LEGACY: an existing row that predates
// this field behaves exactly as before (T635's random/preferred/forced
// draw) and is never retroactively labelled.

const RowShape = enum {
    solo,
    panel,
};

fn parseShape(s: []const u8) ?RowShape {
    if (std.mem.eql(u8, s, "solo")) return .solo;
    if (std.mem.eql(u8, s, "panel")) return .panel;
    return null;
}

fn shapeName(s: RowShape) []const u8 {
    return switch (s) {
        .solo => "solo",
        .panel => "panel",
    };
}

/// The outcome of a shape-aware pick (model + method) before the surrounding
/// filter result is merged into an AssignResult.  Slices owned by the caller.
const ShapePick = struct {
    model: []const u8 = "",
    method: []const u8 = "", // "solo-least-data" | "panel-greedy" | "panel-prior" | "random"
};

// ── T772: §5 qualification gate + D027 least-data tie-break ───────────────
// Operator ruling 2026-08-23: cost is REMOVED from model choice entirely.
// The pick is qualification first (measurement-methodology.md §5), then ties
// among qualified models break on D027's exploration-first least-data rule.
// Cost becomes a REPORTING surface only — shape_reasons may state it, never
// decide on it.

/// §5 qualification state of one candidate (measurement-methodology.md §5).
const Qualification = enum {
    /// passes the §5 gate: score ≥ θ(task_type) AND fabricated_citations == 0
    /// AND verification_rate ≥ φ(task_type).
    qualified,
    /// fails the §5 gate — dropped regardless of cost or panel praise.
    underqualified,
    /// no §5 data for the task type.  D027: eligible to try, never excluded,
    /// never preferred over a qualified model.
    unmeasured,
};

/// One measured token cost plus its trust grade (T746 ruling 3: token/cpu/rss
/// figures are collected but not trusted; a retro reading must be labelled).
const CostReading = struct {
    cost: u64,
    trusted: bool, // false = source pi-session-jsonl-retro; true = dispatch-time
};

/// The reported cost for one candidate, with the trust grade carried through:
/// `median` is null when there is no reading; `has_retro` is true when at
/// least one reading folded into the median was `trusted: false`, so a
/// consumer labels the number instead of mistaking a retro reading for a
/// dispatch-time one.
const CostReport = struct {
    median: ?u64,
    has_retro: bool,
};

/// Median reported cost over measured readings, trust grade carried through.
/// It is a central reading, not a guarantee — and a candidate with no reading
/// stays unknown rather than being assumed cheap or expensive.
fn costReport(readings: []const CostReading) CostReport {
    if (readings.len == 0) return .{ .median = null, .has_retro = false };
    const sorted = alloc.alloc(u64, readings.len) catch return .{ .median = null, .has_retro = false };
    defer alloc.free(sorted);
    var has_retro = false;
    for (readings, 0..) |r, i| {
        sorted[i] = r.cost;
        if (!r.trusted) has_retro = true;
    }
    std.mem.sort(u64, sorted, {}, struct {
        fn lt(_: void, a: u64, b: u64) bool {
            return a < b;
        }
    }.lt);
    return .{ .median = sorted[sorted.len / 2], .has_retro = has_retro };
}

/// Solo pick: qualification first (methodology §5), then least-data (D027).
///
/// "Qualified" here means the §5 gate — `score ≥ θ(task_type)` AND
/// `fabricated_citations == 0` AND `verification_rate ≥ φ(task_type)` — NOT
/// the appetite/exclusion filter, which is filterQualified's job and has
/// already run before this function sees the list.  Cost is removed from
/// choice entirely (operator, 2026-08-23): `costs[i]` is written into
/// `sreasons` as a report and never decides the pick.
///
/// `quals[i]` is the §5 state of `candidates[i]`; `data_counts[i]` is the
/// candidate's ledger task count (D027 least-data: fewest rows wins);
/// `costs[i]` is the reported cost (median + trust grade).  The pick:
///  1. drop underqualified (fails §5, excluded regardless of cost);
///  2. among survivors prefer qualified over unmeasured (D027: unmeasured is
///     eligible to try, never preferred over a qualified model);
///  3. break ties on the fewest data rows, drawing uniformly among the
///     least-data set.
fn soloPick(
    candidates: []const []const u8,
    quals: []const Qualification,
    data_counts: []const u32,
    costs: []const CostReport,
    rng: std.Random,
    sreasons: *std.ArrayList([]const u8),
) !ShapePick {
    // 1. Drop underqualified; record the reason; collect eligible indices.
    var eligible = std.ArrayList(usize).empty;
    defer eligible.deinit(alloc);
    for (candidates, 0..) |c, i| {
        const q = if (i < quals.len) quals[i] else .unmeasured;
        if (q == .underqualified) {
            try sreasons.append(alloc, try std.fmt.allocPrint(alloc, "{s}: underqualified — fails the §5 gate (score/fabricated_citations/verification_rate), excluded regardless of cost", .{c}));
            continue;
        }
        try eligible.append(alloc, i);
    }
    if (eligible.items.len == 0) return error.NoQualifiedCandidate;

    // 2. Prefer qualified over unmeasured.
    var saw_qualified = false;
    for (eligible.items) |i| {
        const q = if (i < quals.len) quals[i] else .unmeasured;
        if (q == .qualified) saw_qualified = true;
    }
    var preferred = std.ArrayList(usize).empty;
    defer preferred.deinit(alloc);
    for (eligible.items) |i| {
        const q = if (i < quals.len) quals[i] else .unmeasured;
        if (!saw_qualified or q == .qualified) try preferred.append(alloc, i);
    }

    // 3. Least-data among the preferred set; ties draw uniformly.
    var min_count: u32 = std.math.maxInt(u32);
    for (preferred.items) |i| {
        const dc = if (i < data_counts.len) data_counts[i] else 0;
        if (dc < min_count) min_count = dc;
    }
    var tied = std.ArrayList(usize).empty;
    defer tied.deinit(alloc);
    for (preferred.items) |i| {
        const dc = if (i < data_counts.len) data_counts[i] else 0;
        if (dc == min_count) try tied.append(alloc, i);
    }

    const chosen_idx = if (tied.items.len == 1)
        tied.items[0]
    else
        tied.items[rng.uintLessThan(usize, tied.items.len)];

    const chosen_dc = if (chosen_idx < data_counts.len) data_counts[chosen_idx] else 0;
    const chosen_q = if (chosen_idx < quals.len) quals[chosen_idx] else .unmeasured;
    const chosen_rep = if (chosen_idx < costs.len) costs[chosen_idx] else CostReport{ .median = null, .has_retro = false };

    for (candidates, 0..) |c, i| {
        const q = if (i < quals.len) quals[i] else .unmeasured;
        if (q == .underqualified or i == chosen_idx) continue;
        const dc = if (i < data_counts.len) data_counts[i] else 0;
        const rep = if (i < costs.len) costs[i] else CostReport{ .median = null, .has_retro = false };

        var costbuf: [96]u8 = undefined;
        const cost_text: []const u8 = blk: {
            if (rep.median) |m| {
                if (rep.has_retro) break :blk std.fmt.bufPrint(&costbuf, "{d} tokens (trusted:false retro — reporting only)", .{m}) catch "unknown";
                break :blk std.fmt.bufPrint(&costbuf, "{d} tokens", .{m}) catch "unknown";
            }
            break :blk "unknown";
        };
        if (q == .qualified) {
            try sreasons.append(alloc, try std.fmt.allocPrint(alloc, "{s}: passed over — qualified, {d} ledger task(s) vs {d} (least-data) | measured cost {s}", .{ c, dc, chosen_dc, cost_text }));
        } else if (saw_qualified) {
            try sreasons.append(alloc, try std.fmt.allocPrint(alloc, "{s}: passed over — unmeasured (§5 no data), a qualified model exists | measured cost {s}", .{ c, cost_text }));
        } else {
            try sreasons.append(alloc, try std.fmt.allocPrint(alloc, "{s}: passed over — unmeasured, {d} ledger task(s) vs {d} (least-data) | measured cost {s}", .{ c, dc, chosen_dc, cost_text }));
        }
    }

    var ccostbuf: [96]u8 = undefined;
    const chosen_cost_text: []const u8 = blk: {
        if (chosen_rep.median) |m| {
            if (chosen_rep.has_retro) break :blk std.fmt.bufPrint(&ccostbuf, "{d} tokens (trusted:false retro — reporting only)", .{m}) catch "unknown";
            break :blk std.fmt.bufPrint(&ccostbuf, "{d} tokens", .{m}) catch "unknown";
        }
        break :blk "unknown";
    };
    const chosen_kind: []const u8 = if (chosen_q == .qualified) "qualified" else "unmeasured";
    try sreasons.append(alloc, try std.fmt.allocPrint(alloc, "{s}: chosen — least measured data ({d} ledger task(s)) among {s} | measured cost {s}", .{ candidates[chosen_idx], chosen_dc, chosen_kind, chosen_cost_text }));

    return .{
        .model = try alloc.dupe(u8, candidates[chosen_idx]),
        .method = try alloc.dupe(u8, "solo-least-data"),
    };
}

fn indexOfModel(names: []const []const u8, model: []const u8) ?usize {
    for (names, 0..) |n, i| {
        if (std.mem.eql(u8, n, model)) return i;
    }
    return null;
}

/// One greedy-marginal-complementarity step: given the already-seated models,
/// pick the model whose caught set adds the most items no seated model
/// caught.  This is the "expected unique catches" ranking.  Cost is removed
/// from choice (operator, 2026-08-23): ties among equal marginals break on
/// D027's least-data rule (fewer ledger task rows wins), never on cost.
/// Returns the index into `model_names`, or null when no candidate adds a
/// unique catch (diminishing returns).
fn greedyPanelStep(
    model_names: []const []const u8,
    caught_sets: []const []const []const u8,
    data_counts: []const u32,
    seats: []const []const u8,
    sreasons: *std.ArrayList([]const u8),
) !?usize {
    var covered = std.StringHashMapUnmanaged(void){};
    defer covered.deinit(alloc);
    for (seats) |seat| {
        const si = indexOfModel(model_names, seat) orelse continue;
        for (caught_sets[si]) |item| {
            try covered.put(alloc, item, {});
        }
    }

    var best: ?usize = null;
    var best_marginal: usize = 0;
    for (model_names, 0..) |m, i| {
        var is_seated = false;
        for (seats) |s| {
            if (std.mem.eql(u8, s, m)) {
                is_seated = true;
                break;
            }
        }
        if (is_seated) continue;

        var marginal: usize = 0;
        for (caught_sets[i]) |item| {
            if (!covered.contains(item)) marginal += 1;
        }

        if (best == null or marginal > best_marginal) {
            best = i;
            best_marginal = marginal;
        } else if (marginal == best_marginal) {
            const dc_new = if (i < data_counts.len) data_counts[i] else 0;
            const dc_best = if (best.? < data_counts.len) data_counts[best.?] else 0;
            if (dc_new < dc_best) best = i;
        }
    }

    const chosen = best orelse return null;
    if (best_marginal == 0) {
        try sreasons.append(alloc, try std.fmt.allocPrint(alloc, "diminishing returns: no qualified candidate adds a unique catch given the seats already filled", .{}));
        return null;
    }
    try sreasons.append(alloc, try std.fmt.allocPrint(alloc, "{s}: adds {d} unique catch(es) given seats so far", .{ model_names[chosen], best_marginal }));
    return chosen;
}

/// Read every measured per-lane token cost for `model` from the standing
/// complementarity record (T637's `tools/complementarity-record.json`),
/// carrying the trust grade (T746 ruling 3: token/cpu/rss figures are
/// collected but not trusted; a retro reading must be labelled, never
/// flattened into a dispatch-time one).  A per-lane `trusted: false` reading
/// (source pi-session-jsonl-retro) is carried through; an absent `trusted`
/// field defaults to true, because the record's costs are the reducer's
/// "clean ledger reading" selection.  Empty when the record is absent or has
/// no reading — a missing cost is "unknown", never guessed cheap or expensive.
fn readMeasuredCosts(io: std.Io, repo_root: []const u8, model: []const u8) ![]CostReading {
    const path = std.fs.path.join(alloc, &.{ repo_root, "tools", "complementarity-record.json" }) catch return &.{};
    defer alloc.free(path);
    const content = std.Io.Dir.cwd().readFileAlloc(io, path, alloc, .unlimited) catch |err| {
        if (err == error.FileNotFound) return &.{};
        return err;
    };
    defer alloc.free(content);

    var parsed = std.json.parseFromSlice(std.json.Value, alloc, content, .{ .allocate = .alloc_always }) catch return &.{};
    defer parsed.deinit();

    var readings = std.ArrayList(CostReading).empty;
    if (parsed.value != .object) return &.{};
    const groups = parsed.value.object.get("groups") orelse return &.{};
    if (groups != .object) return &.{};
    var git = groups.object.iterator();
    while (git.next()) |g| {
        const group = g.value_ptr.*;
        if (group != .object) continue;
        const per_lane = group.object.get("per_lane") orelse continue;
        if (per_lane != .object) continue;
        var lit = per_lane.object.iterator();
        while (lit.next()) |lane_entry| {
            const lane = lane_entry.value_ptr.*;
            if (lane != .object) continue;
            const m = lane.object.get("model") orelse continue;
            if (m != .string or !std.mem.eql(u8, m.string, model)) continue;
            if (lane.object.get("cost")) |cv| {
                if (cv == .integer) {
                    var trusted = true;
                    if (lane.object.get("trusted")) |tv| {
                        if (tv == .bool) trusted = tv.bool;
                    }
                    try readings.append(alloc, .{ .cost = @intCast(cv.integer), .trusted = trusted });
                }
            }
        }
    }
    return readings.toOwnedSlice(alloc);
}

/// model → caught-item set, aggregated across every group of the standing
/// complementarity record.  Not task-type-scoped: the row carries no
/// task_type yet, so this is the honest whole-record prior and is labelled
/// one in the selection reasons.
const CaughtSets = std.StringHashMapUnmanaged(std.StringHashMapUnmanaged(void));

fn freeCaughtSets(map: *CaughtSets) void {
    var mit = map.iterator();
    while (mit.next()) |e| {
        alloc.free(e.key_ptr.*);
        var inner = e.value_ptr.*;
        var iit = inner.iterator();
        while (iit.next()) |ie| alloc.free(ie.key_ptr.*);
        inner.deinit(alloc);
    }
    map.deinit(alloc);
}

fn buildCaughtSets(io: std.Io, repo_root: []const u8) !CaughtSets {
    var map = CaughtSets{};
    errdefer freeCaughtSets(&map);

    const path = std.fs.path.join(alloc, &.{ repo_root, "tools", "complementarity-record.json" }) catch return map;
    defer alloc.free(path);
    const content = std.Io.Dir.cwd().readFileAlloc(io, path, alloc, .unlimited) catch |err| {
        if (err == error.FileNotFound) return map;
        return err;
    };
    defer alloc.free(content);
    var parsed = std.json.parseFromSlice(std.json.Value, alloc, content, .{ .allocate = .alloc_always }) catch return map;
    defer parsed.deinit();

    if (parsed.value != .object) return map;
    const groups = parsed.value.object.get("groups") orelse return map;
    if (groups != .object) return map;

    var git = groups.object.iterator();
    while (git.next()) |g| {
        const group = g.value_ptr.*;
        if (group != .object) continue;
        const per_lane = group.object.get("per_lane") orelse continue;
        const caught_matrix = group.object.get("caught_matrix") orelse continue;
        if (per_lane != .object or caught_matrix != .object) continue;

        // lane id → model name (owned copies, freed at end of this group).
        var lane_model = std.StringHashMapUnmanaged([]const u8){};
        defer {
            var lit2 = lane_model.iterator();
            while (lit2.next()) |le| alloc.free(le.value_ptr.*);
            lane_model.deinit(alloc);
        }
        {
            var lit = per_lane.object.iterator();
            while (lit.next()) |lane_entry| {
                const lane = lane_entry.value_ptr.*;
                if (lane != .object) continue;
                const m = lane.object.get("model") orelse continue;
                if (m != .string) continue;
                try lane_model.put(alloc, lane_entry.key_ptr.*, try alloc.dupe(u8, m.string));
            }
        }

        var mit = caught_matrix.object.iterator();
        while (mit.next()) |item_entry| {
            const item = item_entry.key_ptr.*;
            const lanes = item_entry.value_ptr.*;
            if (lanes != .array) continue;
            for (lanes.array.items) |lv| {
                if (lv != .string) continue;
                const model = lane_model.get(lv.string) orelse continue;
                const entry = try map.getOrPut(alloc, model);
                if (!entry.found_existing) {
                    entry.key_ptr.* = try alloc.dupe(u8, model);
                    entry.value_ptr.* = .{};
                }
                try entry.value_ptr.put(alloc, try alloc.dupe(u8, item), {});
            }
        }
    }
    return map;
}

/// Panel pick: anchor + greedy marginal complementarity over the standing
/// complementarity record (a `CaughtSets` map, possibly empty).  Empty map =
/// prior-driven (uniform draw, labelled loudly).  `data_counts` is the
/// parallel per-candidate ledger task count, used only as the D027 least-data
/// tie-break among equal marginals (cost is removed from choice).  Pure over
/// its inputs — testable with seeded fixtures.
fn panelPick(
    candidates: []const []const u8,
    caught: *const CaughtSets,
    data_counts: []const u32,
    seats: []const []const u8,
    rng: std.Random,
    sreasons: *std.ArrayList([]const u8),
) !ShapePick {
    var measured = std.ArrayList([]const u8).empty;
    defer measured.deinit(alloc);
    var measured_caught = std.ArrayList([]const []const u8).empty;
    defer {
        for (measured_caught.items) |s| alloc.free(s);
        measured_caught.deinit(alloc);
    }
    var measured_counts = std.ArrayList(u32).empty;
    defer measured_counts.deinit(alloc);

    for (candidates, 0..) |c, i| {
        const entry = caught.get(c);
        if (entry == null) {
            try sreasons.append(alloc, try std.fmt.allocPrint(alloc, "{s}: no measured expectation in the complementarity record (prior, not ranked)", .{c}));
            continue;
        }
        var items = std.ArrayList([]const u8).empty;
        var it2 = entry.?.iterator();
        while (it2.next()) |e| try items.append(alloc, e.key_ptr.*);
        try measured.append(alloc, c);
        try measured_caught.append(alloc, try items.toOwnedSlice(alloc));
        try measured_counts.append(alloc, if (i < data_counts.len) data_counts[i] else 0);
    }

    if (measured.items.len == 0) {
        const picked = try drawCandidate(rng, candidates);
        try sreasons.append(alloc, try std.fmt.allocPrint(alloc, "prior-driven: complementarity record has no measured expectation for any qualified candidate — guessing (uniform draw)", .{}));
        return .{ .model = picked, .method = try alloc.dupe(u8, "panel-prior") };
    }

    const next = try greedyPanelStep(measured.items, measured_caught.items, measured_counts.items, seats, sreasons);
    const idx = next orelse return error.PanelFull;
    return .{
        .model = try alloc.dupe(u8, measured.items[idx]),
        .method = try alloc.dupe(u8, "panel-greedy"),
    };
}

/// D027 least-data census: count kanban rows per canonical model.  A row whose
/// `model` is not a canonical label (null / "unattributed") is not counted
/// against any model.  Note this is the whole-store count — the kanban carries
/// no killed_by field, so it cannot apply the guard-kill censoring the
/// fleet-keeper's least-data picker reads from the perf ledger (T629/Ruling
/// 32).  Both pickers agree on the rule (fewest rows wins), not on the
/// censored denominator.
const DataCounts = std.StringHashMapUnmanaged(u32);

fn taskCountsByModel(state: *const StateMap) !DataCounts {
    var map = DataCounts{};
    errdefer freeDataCounts(&map);
    var it = state.iterator();
    while (it.next()) |e| {
        const m = e.value_ptr.model orelse continue;
        if (!isCanonicalModel(m)) continue;
        const entry = try map.getOrPut(alloc, m);
        if (!entry.found_existing) {
            entry.key_ptr.* = try alloc.dupe(u8, m);
            entry.value_ptr.* = 0;
        }
        entry.value_ptr.* += 1;
    }
    return map;
}

fn freeDataCounts(map: *DataCounts) void {
    var it = map.iterator();
    while (it.next()) |e| alloc.free(e.key_ptr.*);
    map.deinit(alloc);
}

/// Shape-aware assignment (ruling 34).  `shape == null` is the legacy T635
/// draw (an existing row with no shape behaves exactly as before).  For a
/// solo row the multi-candidate pick is qualification-first + least-data
/// (T772: cost is removed from choice and reported only); for a panel row it
/// is anchor + greedy marginal complementarity over the standing record.
/// `requested` (--model) and a one-element qualified list behave as in T635
/// regardless of shape.  `seats` names already-seated models (panel only).
/// `counts` is the D027 least-data census.  The T635 filter
/// (candidates/reasons) is shared, so the candidates/method record is written
/// identically whichever shape applied.
fn selectForShape(
    shape: ?RowShape,
    requested: ?[]const u8,
    exclusions: []const []const u8,
    seats: []const []const u8,
    counts: *const DataCounts,
    rng: std.Random,
    io: std.Io,
    repo_root: []const u8,
) !AssignResult {
    if (shape == null) return assignModel(requested, exclusions, rng);

    var lists = try filterQualified(exclusions);
    errdefer deinitQualified(&lists);
    var sreasons = std.ArrayList([]const u8).empty;
    errdefer {
        for (sreasons.items) |x| alloc.free(x);
        sreasons.deinit(alloc);
    }

    var method: []const u8 = undefined;
    var model: []const u8 = undefined;
    if (requested) |req| {
        method = try alloc.dupe(u8, "preferred");
        model = try alloc.dupe(u8, req);
        var in_list = false;
        for (lists.candidates.items) |c| {
            if (std.mem.eql(u8, c, req)) in_list = true;
        }
        if (!in_list) {
            try lists.reasons.append(alloc, try std.fmt.allocPrint(alloc, "{s}: preferred by row (outside qualified list)", .{req}));
        }
    } else if (lists.candidates.items.len == 0) {
        return error.NoQualifiedCandidate;
    } else if (lists.candidates.items.len == 1) {
        method = try alloc.dupe(u8, "forced");
        model = try alloc.dupe(u8, lists.candidates.items[0]);
    } else {
        const cands = lists.candidates.items;
        switch (shape.?) {
            .solo => {
                var costs = std.ArrayList(CostReport).empty;
                defer costs.deinit(alloc);
                var quals = std.ArrayList(Qualification).empty;
                defer quals.deinit(alloc);
                var data_counts = std.ArrayList(u32).empty;
                defer data_counts.deinit(alloc);
                for (cands) |c| {
                    const readings = try readMeasuredCosts(io, repo_root, c);
                    defer alloc.free(readings);
                    try costs.append(alloc, costReport(readings));
                    // No machine-readable §5 record exists yet: θ/φ are
                    // unrecorded and fabricated_citations/verification_rate
                    // live only in findings files.  Every candidate is
                    // `unmeasured` — D027 admits unmeasured as eligible to
                    // try, so the live pick reduces to least-data.
                    try quals.append(alloc, Qualification.unmeasured);
                    try data_counts.append(alloc, counts.get(c) orelse 0);
                }
                const pick = try soloPick(cands, quals.items, data_counts.items, costs.items, rng, &sreasons);
                model = pick.model;
                method = pick.method;
            },
            .panel => {
                var caught = try buildCaughtSets(io, repo_root);
                defer freeCaughtSets(&caught);
                var data_counts = std.ArrayList(u32).empty;
                defer data_counts.deinit(alloc);
                for (cands) |c| {
                    try data_counts.append(alloc, counts.get(c) orelse 0);
                }
                const pick = try panelPick(cands, &caught, data_counts.items, seats, rng, &sreasons);
                model = pick.model;
                method = pick.method;
            },
        }
    }

    return .{
        .candidates = try lists.candidates.toOwnedSlice(alloc),
        .reasons = try lists.reasons.toOwnedSlice(alloc),
        .method = method,
        .model = model,
        .shape_reasons = try sreasons.toOwnedSlice(alloc),
    };
}

fn isValidVerdict(s: []const u8) bool {
    for (valid_verdicts) |v| {
        if (std.mem.eql(u8, v, s)) return true;
    }
    return false;
}

// ── message-bus types ───────────────────────────────────────────────────────

const RoleSync = struct {
    last_read_msg: u32 = 0,
    last_posted_msg: u32 = 0,
    last_event_gen: u64 = 0,
};

// ── directive types (WORKER-CHANNEL) ────────────────────────────────────────

const Directive = struct {
    id: []const u8,
    target: []const u8,
    directive: []const u8,
    note: ?[]const u8 = null,
    from: []const u8,
    ts: []const u8,
    read: bool = false,
    // T625: machine-checkable discharge condition for a `pause` — enforced
    // only while <row> is not `done` in the kanban (re-evaluated at every
    // apply by tools/runner and bin/dispatch via tools/directive_policy.py).
    // D047's condition lived in prose inside --note and killed fresh
    // dispatches for two days after it was satisfied; this field makes the
    // condition evaluable.  Valid for `pause` only; see cmdTell.
    until_done: ?[]const u8 = null,
};

const valid_directives = [_][]const u8{ "pause", "resume", "kill", "amend", "question" };

fn isValidDirective(s: []const u8) bool {
    for (valid_directives) |d| {
        if (std.mem.eql(u8, d, s)) return true;
    }
    return false;
}

/// T625: a kanban row id of the `T<digits>` shape — what `tell --until-done`
/// accepts (and what a directive's `until_done` field must name).
fn isTaskId(s: []const u8) bool {
    if (s.len < 2 or s[0] != 'T') return false;
    for (s[1..]) |c| {
        if (c < '0' or c > '9') return false;
    }
    return true;
}

const StateMap = std.StringHashMapUnmanaged(TaskState);

// ── T427: test-harness write guards ────────────────────────────────────────
// T425's regression wrote 16 T425-DOCTOR-* rows into the LIVE kanban because
// its arms called add/claim/done without MANAGENT_STORE. Two guards, both
// failing loudly at the moment of the write:
//   (a) fixture-pattern ids are refused on the live store — no cooperation
//       required from the caller (the id itself trips the guard);
//   (b) with MANAGENT_TEST=1, ANY mutating verb on the live store is refused
//       — a harness that declares itself a test cannot write production even
//       with a non-fixture-shaped id.
// Scratch stores (MANAGENT_STORE pointing anywhere else) are exempt: tests
// own their substrate (A3).

/// Marker tokens that regression harnesses embed in fixture row ids
/// (T425-DOCTOR-2-<rand>, TLC-ARM1, T294SEED, ...). Matched as
/// boundary-delimited words so a legit id like T-LATEST-... never trips it.
const fixture_markers = [_][]const u8{ "DOCTOR", "FIXTURE", "SEED", "PROBE", "ARM", "TEST" };

/// Verbs that write the kanban state (or live runtime state: ping's
/// heartbeat). Read-only verbs (status/show/whoami/why/resume/standing/
/// audit/liveness) are never refused.
const mutating_verbs = [_][]const u8{
    "add",     "claim",  "done",    "reopen", "purge", "set",
    "needs",   "agent",  "verdict", "archive", "amend", "sync",
    "tell",    "inbox",  "dispatch", "suggest", "next", "ping",
    "standing", "assert", "retire", "duty", "reap", "assign", "shape",
    "lanes",
};

fn refuseLiveWrite(w: Writers, cmd: []const u8, why: []const u8) noreturn {
    w.diag("\n  REFUSED: '{s}' would write the LIVE kanban — {s}\n", .{ cmd, why });
    w.diag("  Test harnesses and fixtures must run against a scratch store:\n", .{});
    w.diag("    MANAGENT_STORE=/tmp/weizigo/<scratch>/tasks.json {s} ...\n", .{ cmd });
    w.diag("  (T427: T425's regression wrote 16 fixture rows into the live store.)\n", .{});
    std.process.exit(1);
}

fn isMutatingVerb(cmd: []const u8) bool {
    for (mutating_verbs) |v| {
        if (std.mem.eql(u8, cmd, v)) return true;
    }
    return false;
}

/// Absolute, symlink-resolved form of a path. Uses libc realpath when the
/// path exists (so /tmp/... and /private/tmp/... compare equal on macOS);
/// falls back to pure string normalization when it does not exist yet.
fn resolveAbsPath(p: []const u8) ![]u8 {
    if (!std.fs.path.isAbsolute(p)) {
        var buf: [std.fs.max_path_bytes]u8 = undefined;
        const cwd_ptr = std.c.getcwd(&buf, buf.len) orelse return error.CwdUnavailable;
        const cwd = std.mem.sliceTo(cwd_ptr, 0);
        const joined = try std.fs.path.join(alloc, &.{ cwd, p });
        defer alloc.free(joined);
        return resolveAbsPath(joined);
    }
    const z = try alloc.allocSentinel(u8, p.len, 0);
    defer alloc.free(z);
    @memcpy(z, p);
    var out_buf: [std.fs.max_path_bytes]u8 = undefined;
    if (std.c.realpath(z.ptr, &out_buf)) |resolved| {
        return alloc.dupe(u8, std.mem.sliceTo(resolved, 0));
    }
    return std.fs.path.resolve(alloc, &.{p});
}

/// True when the store this invocation would use IS the live kanban: it
/// resolves to the default store path of the repo discovered from cwd AND
/// that path is tracked in git. The tracking check is what separates the
/// real kanban from a scratch repo's default store — T424's
/// claim-lifecycle regression runs managent from a scratch repo with
/// MANAGENT_STORE unset and must keep working; its store is untracked.
fn isLiveStore(io: std.Io, state_path: []const u8, repo_root: []const u8) bool {
    const default_path = std.fs.path.join(alloc, &.{ repo_root, "docs", "infra", "managent", "tasks.json" }) catch return false;
    defer alloc.free(default_path);
    const def_resolved = resolveAbsPath(default_path) catch return false;
    defer alloc.free(def_resolved);
    const eff_resolved = resolveAbsPath(state_path) catch return false;
    defer alloc.free(eff_resolved);
    if (!std.mem.eql(u8, eff_resolved, def_resolved)) return false;
    const out = runGit(alloc, io, repo_root, &.{ "ls-files", "--", "docs/infra/managent/tasks.json" });
    defer if (out.stdout.len > 0) alloc.free(out.stdout);
    return out.ok and std.mem.indexOf(u8, out.stdout, "docs/infra/managent/tasks.json") != null;
}

/// Does the id look like a harness-generated fixture id? Uppercased, then
/// each marker token must be delimited by '-', '_', a digit, or the edges.
fn idLooksLikeFixture(id: []const u8) bool {
    var upper_buf: [160]u8 = undefined;
    if (id.len == 0 or id.len > upper_buf.len) return false;
    for (id, 0..) |c, i| {
        upper_buf[i] = if (c >= 'a' and c <= 'z') c - 32 else c;
    }
    const upper = upper_buf[0..id.len];
    for (fixture_markers) |m| {
        var idx: usize = 0;
        while (std.mem.indexOfPos(u8, upper, idx, m)) |pos| {
            const before_ok = pos == 0 or upper[pos - 1] == '-' or upper[pos - 1] == '_';
            const after_idx = pos + m.len;
            const after_ok = after_idx >= upper.len or
                upper[after_idx] == '-' or upper[after_idx] == '_' or
                (upper[after_idx] >= '0' and upper[after_idx] <= '9');
            if (before_ok and after_ok) return true;
            idx = pos + 1;
        }
    }
    return false;
}

// ─────────────────────────────────────────────────────────────────── entry

pub fn main(init: std.process.Init.Minimal) !void {
    std.debug.print("{s}\n", .{version.banner("managent")});
    const args_raw = init.args.vector;
    var args_slice = std.ArrayList([]const u8).empty;
    defer args_slice.deinit(alloc);
    for (args_raw) |arg| {
        try args_slice.append(alloc, std.mem.span(arg));
    }
    const args = args_slice.items;

    // T295: pass the parent environment so child processes (acceptance
    // runner, git commands, claimlint) inherit PATH and other variables.
    // Default InitOptions.environ is .empty, which causes spawns to start
    // with no environment at all — /bin/sh: zig: command not found.
    var threaded = std.Io.Threaded.init(alloc, .{ .environ = init.environ });
    defer threaded.deinit();
    const io = threaded.io();

    const w = Writers{ .io = io };

    // T517: `models` is a pure static lookup over canonical_models[] — the
    // single source the keeper / dispatch / subagent / watch-fleet shell out
    // to (F7: model canonicalization was ×4 with four definitions, and the
    // keeper's least-data picker listed only the non-Claude five, so a
    // model-less row could never draw a Claude label).  It needs NEITHER a
    // repo root NOR a kanban store, so it short-circuits BEFORE findRepoRoot
    // — callable from any directory.  Safe with no store at all.
    if (args.len >= 2 and std.mem.eql(u8, args[1], "models")) {
        try cmdModels(w, args);
        return;
    }

    // T801: `canonicalize` is the strict boundary form of the same pure
    // static transform `models` exposes — resolve a raw dispatch tag to its
    // canonical label, rejecting (exit 1) an unrecognized tag instead of
    // passing it through.  Pure static like `models`: no repo root, no store.
    if (args.len >= 2 and std.mem.eql(u8, args[1], "canonicalize")) {
        try cmdCanonicalize(w, args);
        return;
    }

    const repo_root = try findRepoRoot(w, io);
    defer alloc.free(repo_root);

    // MANAGENT_STORE env var overrides the default state path (A3: substrate isolation)
    const store_env_ptr = std.c.getenv("MANAGENT_STORE");
    const store_env: ?[]const u8 = if (store_env_ptr) |p| std.mem.span(p) else null;
    const state_path = if (store_env) |se|
        try alloc.dupe(u8, se)
    else
        try std.fs.path.join(alloc, &.{ repo_root, "docs", "infra", "managent", "tasks.json" });
    defer alloc.free(state_path);

    // Ensure the managent directory exists (only for default store)
    if (store_env == null) {
        const dir_path = "docs/infra/managent";
        std.Io.Dir.cwd().createDirPath(io, dir_path) catch {};
    }

    // T427: live-store detection + test-harness marker (see guards above).
    const is_live = isLiveStore(io, state_path, repo_root);
    const test_harness = std.c.getenv("MANAGENT_TEST") != null;

    // Determine command (first non-flag arg, or "status")
    const cmd: []const u8 = if (args.len >= 2 and !std.mem.startsWith(u8, args[1], "-")) args[1] else "status";

    // S10 store-loss detector: record the verb for the census's written_by, and
    // parse the reasoned escape once, centrally (honored only by the write path,
    // so a read-only verb passing it is a harmless no-op).
    current_cmd = cmd;
    reconcile_reason = getFlagValue(args, "--reconcile-store-loss");

    // Help flags — short-circuit BEFORE any side effect (T210 D3)
    // Match: managent help, managent standing --help, managent --help, etc.
    if (std.mem.eql(u8, cmd, "help")) {
        printHelp(w);
        return;
    }
    for (args[1..]) |arg| {
        if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
            printHelp(w);
            return;
        }
    }

    // T556 pass 1: `treekill` short-circuits AFTER findRepoRoot (it needs the repo
    // root for G6's untracked/runs/ protected set) and BEFORE the
    // lock-migrate-write block below — it never takes the kanban flock and
    // never migrates the store (it runs on every runner exit path).
    if (std.mem.eql(u8, cmd, "treekill")) {
        cmdTreekill(w, io, repo_root, args) catch |err| {
            w.diag("[treekill] internal error: {s}\n", .{@errorName(err)});
            std.process.exit(3);
        };
        return;
    }

    // S10-STORE-3: read-time census check on the read-only surfaces.  Alarms on
    // stderr (naming the gap, the missing ids, the census) and marks read_shrunk
    // so the process exits non-zero AFTER the surface has rendered — the next
    // `orient` says so instead of the next lucky error.
    var read_shrunk = false;
    if (std.mem.eql(u8, cmd, "orient") or std.mem.eql(u8, cmd, "status") or
        std.mem.eql(u8, cmd, "resume") or std.mem.eql(u8, cmd, "audit"))
    {
        read_shrunk = checkCensusRead(io, state_path) catch false;
    }

    // Migration: on every invocation, re-derive dispatchable/blocked statuses.
    // T545: the whole read→migrate→write runs under the flock.  The previous
    // code read the store UNLOCKED and wrote via writeState (lock only around
    // the write), so ANY invocation that triggered a migration — including
    // ordinary reads — reverted every concurrent claim/close/attribution that
    // landed between read and write.  Observed 2026-08-20 while the fleet was
    // hot: `[migrate] T535: stored dispatchable → blocked (needs-derived)`.
    // The lock is taken on every invocation (read-only verbs included) because
    // the decision to write depends on the read; a pre-read outside the lock
    // would reopen the window.
    {
        try lockStore(io, state_path);
        defer unlockStore();
        var st = try readState(io, state_path);
        const migrated = migrateState(w, &st);
        // T478: one-time duty-flag migration — recognize duties registered
        // before the duty flag existed (DCLAIM/DRPLAY/DARGUS) by re-reading
        // their bundle meta headers.  Guarded by _sys.duty_migrated so the
        // bundle scan runs exactly once per store.
        const duty_migrated_now = !sys_duty_migrated;
        if (duty_migrated_now) {
            migrateDutyFlags(io, repo_root, &st);
        }
        if (migrated or duty_migrated_now) {
            // T427: even a read-only verb would rewrite the store here — a
            // test harness must not migrate the live store either.
            if (test_harness and is_live) {
                refuseLiveWrite(w, cmd, "MANAGENT_TEST=1 — a read-only verb would migrate the live store; point MANAGENT_STORE at a scratch path");
            }
            try writeStateLocked(io, state_path, &st);
        }
        freeState(&st);
    }

    // T427: a test harness (MANAGENT_TEST=1) must not write the live store.
    if (test_harness and is_live and isMutatingVerb(cmd)) {
        refuseLiveWrite(w, cmd, "MANAGENT_TEST=1 — test harnesses must not write the live kanban");
    }

    if (std.mem.eql(u8, cmd, "add")) {
        // T427: fixture-pattern ids are refused on the live store, no
        // cooperation required from the caller — the id itself trips it.
        if (is_live and args.len >= 3 and !std.mem.startsWith(u8, args[2], "-") and idLooksLikeFixture(args[2])) {
            refuseLiveWrite(w, cmd, "row id matches a test-fixture pattern (DOCTOR/FIXTURE/SEED/PROBE/ARM/TEST)");
        }
        try cmdAdd(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "claim")) {
        try cmdClaim(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "done")) {
        try cmdDone(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "status")) {
        try cmdStatus(w, io, state_path, repo_root, args);
    } else if (std.mem.eql(u8, cmd, "resume")) {
        try cmdResume(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "next")) {
        try cmdNext(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "show")) {
        try cmdShow(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "whoami")) {
        try cmdWhoami(w, io, state_path, args);
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
    } else if (std.mem.eql(u8, cmd, "verdict")) {
        try cmdVerdict(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "archive")) {
        try cmdArchive(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "retire")) {
        try cmdRetire(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "amend")) {
        try cmdAmend(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "sync")) {
        try cmdSync(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "holds")) {
        try cmdHolds(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "tell")) {
        try cmdTell(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "assert")) {
        try cmdAssert(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "inbox")) {
        try cmdInbox(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "ping")) {
        try cmdPing(w, io, repo_root, args);
    } else if (std.mem.eql(u8, cmd, "liveness")) {
        try cmdLiveness(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "reap")) {
        try cmdReap(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "audit")) {
        try cmdAudit(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "standing")) {
        try cmdStanding(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "why")) {
        try cmdWhy(w, io, state_path, args);
    } else if (std.mem.eql(u8, cmd, "suggest")) {
        try cmdSuggest(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "assign")) {
        try cmdAssign(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "shape")) {
        try cmdShape(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "duty")) {
        try cmdDuty(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "landmark")) {
        try cmdLandmark(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "orient")) {
        try cmdOrient(w, io, repo_root, state_path, args);
    } else if (std.mem.eql(u8, cmd, "lanes")) {
        try cmdLanes(w, io, repo_root, state_path, args);
    } else {
        w.diag("unknown command: {s}\n", .{cmd});
        std.process.exit(1);
    }

    if (read_shrunk) std.process.exit(1);
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
    acceptance: ?[]const u8 = null,
    // T478: `duty` key marks the row a duty; `due_after` overrides the
    // default closes-until-due (5).
    duty: bool = false,
    due_after: u32 = 5,
    // T636: row shape (ruling 34).  null = not declared; registration then
    // applies the honest default (solo).  A declared value must be solo or
    // panel — anything else is refused at parse.
    shape: ?[]const u8 = null,
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

    // T880: list-valued keys (holds=/needs=/caps=) accept space-separated
    // values as fully as comma-separated ones.  The header is tokenized on
    // spaces, so `holds=a.zig b.zig` arrives as tokens `holds=a.zig` and
    // `b.zig` — a bare token following a list key is a continuation of that
    // list.  Two exceptions: once `acceptance=` appears (its value runs to
    // the end of the line — T217), bare tokens belong to the acceptance
    // command; and any other `key=...` token ends the current list.  The
    // old code silently dropped every continuation token, so
    // `holds=a.zig b.zig c.zig` registered only a.zig (T872: four declared,
    // zero stored; T877: three declared, one stored).
    const ListKey = enum { none, holds, needs, caps };
    var last_list: ListKey = .none;
    var acceptance_seen = false;

    var header_holds = std.ArrayList([]const u8).empty;
    var header_needs = std.ArrayList([]const u8).empty;
    var header_caps = std.ArrayList([]const u8).empty;

    var tokens = std.mem.splitScalar(u8, inner_trimmed, ' ');
    while (tokens.next()) |token| {
        if (token.len == 0) continue;

        // T880: a bare token (no `=`) continues the most recent list value
        // — the space-separated form of holds=/needs=/caps=.
        if (std.mem.indexOfScalar(u8, token, '=') == null) {
            if (!acceptance_seen) {
                const trimmed = std.mem.trim(u8, token, " \t");
                if (trimmed.len > 0) {
                    switch (last_list) {
                        .holds => try header_holds.append(alloc, try alloc.dupe(u8, trimmed)),
                        .needs => try header_needs.append(alloc, try alloc.dupe(u8, trimmed)),
                        .caps => try header_caps.append(alloc, try alloc.dupe(u8, trimmed)),
                        .none => {},
                    }
                }
            }
            continue;
        }

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
            // T539: holds= is a list, not a single path — the old code stored
            // the whole value as ONE element, so a two-file hold became
            // ["a.zig,b.zig"] and the one-writer check compared against a string
            // no real file name could equal — vacuous by construction.
            // T880: split on commas AND whitespace; a space-separated list's
            // first element lands here, the rest as bare tokens above.
            last_list = .holds;
            if (value.len > 0) try splitListValue(value, &header_holds);
        } else if (std.mem.eql(u8, key, "needs")) {
            last_list = .needs;
            if (value.len > 0) try splitListValue(value, &header_needs);
        } else if (std.mem.eql(u8, key, "caps")) {
            last_list = .caps;
            if (value.len > 0) try splitListValue(value, &header_caps);
        } else if (std.mem.eql(u8, key, "duty")) {
            // T478: presence of the key marks the duty (value ignored —
            // `duty`, `duty=1`, `duty=true` all mean the same thing).
            result.duty = true;
        } else if (std.mem.eql(u8, key, "due_after")) {
            // T478: per-duty closes-until-due (default 5).  An unparseable
            // value falls back to 5 rather than failing registration.
            result.due_after = std.fmt.parseInt(u32, value, 10) catch 5;
        } else if (std.mem.eql(u8, key, "shape")) {
            // T636: row shape (ruling 34).  Only solo|panel are accepted; a
            // bogus value is refused rather than silently defaulted.
            if (parseShape(value) == null) {
                w.diag("error: invalid shape '{s}' in metadata (must be solo or panel)\n", .{value});
                std.process.exit(1);
            }
            result.shape = try alloc.dupe(u8, value);
        } else if (std.mem.eql(u8, key, "context")) {
            w.diag("error: 'context=…' key is rejected (retired 2026-07-28); remove it from {s}\n", .{bundle_path});
            std.process.exit(1);
        } else if (std.mem.eql(u8, key, "acceptance")) {
            // T880: everything after acceptance= is the command (T217); bare
            // tokens must not continue a list from before it.
            acceptance_seen = true;
        } else {
            // Any other key= token ends a space-continuation run.
            last_list = .none;
        }
    }

    result.holds = try header_holds.toOwnedSlice(alloc);
    result.needs = try header_needs.toOwnedSlice(alloc);
    result.caps = try header_caps.toOwnedSlice(alloc);

    // T217: acceptance= takes the rest of the meta line (allows spaces in the command).
    // It must be the LAST key in the header.
    if (std.mem.indexOf(u8, inner_trimmed, "acceptance=")) |acc_start| {
        const val_start = acc_start + "acceptance=".len;
        const val_end = inner_trimmed.len;
        if (val_end > val_start) {
            const acc_value = std.mem.trim(u8, inner_trimmed[val_start..val_end], " \t");
            if (acc_value.len > 0) {
                result.acceptance = try alloc.dupe(u8, acc_value);
            }
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
        // T760: --needs a,b,c was stored as the SINGLE element "a,b,c" — a
        // task ID that can never exist, silently blocking the row forever.
        // Split on commas exactly like holds (parseHoldsList) and dedupe
        // against the bundle's own needs= so a repeated ID is not listed twice.
        const flag_needs = try parseHoldsList(n);
        var needs_list = std.ArrayList([]const u8).empty;
        for (result.needs) |existing| {
            try needs_list.append(alloc, existing);
        }
        for (flag_needs) |fn_id| {
            var dup = false;
            for (needs_list.items) |existing| {
                if (std.mem.eql(u8, existing, fn_id)) {
                    dup = true;
                    break;
                }
            }
            if (!dup) try needs_list.append(alloc, fn_id);
        }
        result.needs = try needs_list.toOwnedSlice(alloc);
    }

    return result;
}

/// T760: refuse a need that names no task already in the store — a need on an
/// unregistered ID can never be met, so the row is blocked forever and the
/// defect is silent (the row just sits).  `--allow-unregistered-needs <reason>`
/// is the explicit escape for a need on a task registered later in the same
/// batch; the escape is recorded as an amendment (same pattern as --force on
/// done, T424) so `managent show` says which rows carry an unregistered edge.
/// Returns the amendment record to store (null when nothing was missing and no
/// record is owed).
fn validateNeedsExist(w: Writers, state: *const StateMap, needs: []const []const u8, allow_reason: ?[]const u8) !?[]const u8 {
    var missing = std.ArrayList([]const u8).empty;
    defer missing.deinit(alloc);
    for (needs) |n| {
        if (!state.contains(n)) try missing.append(alloc, n);
    }
    if (missing.items.len == 0) return null;

    if (allow_reason) |reason| {
        if (reason.len == 0) {
            w.diag("error: --allow-unregistered-needs requires a non-empty reason (why the need is not registered yet)\n", .{});
            std.process.exit(1);
        }
        const now = try nowTimestamp();
        var rec = std.ArrayList(u8).empty;
        try rec.appendSlice(alloc, now);
        try rec.appendSlice(alloc, ": ALLOWED unregistered need(s)");
        for (missing.items) |m| {
            try rec.appendSlice(alloc, " ");
            try rec.appendSlice(alloc, m);
        }
        try rec.appendSlice(alloc, " at add — ");
        try rec.appendSlice(alloc, reason);
        return try rec.toOwnedSlice(alloc);
    }

    w.diag("\n  REJECTED: need(s) not registered:", .{});
    for (missing.items) |m| w.diag(" {s}", .{m});
    w.diag("\n  A need on an unregistered task can never be met — the row would be blocked forever.\n", .{});
    w.diag("  Register the missing task(s) first, or (only for a task registered later in the same batch)\n", .{});
    w.diag("  re-run with --allow-unregistered-needs '<reason>'.\n", .{});
    std.process.exit(1);
}

/// T880: the bundle meta header's keys.  A rest-of-line list parser
/// (readBundleHolds / parseDeliverablesFromBundle) must stop at a KNOWN
/// following key (`holds=a.zig acceptance=cmd`), never at any token
/// containing '=' — a path like `docs/foo=bar.md` is a list item, not a key.
fn isKnownMetaKey(key: []const u8) bool {
    const keys = [_][]const u8{ "set", "holds", "needs", "caps", "deliverables", "acceptance", "accepts", "duty", "due_after", "shape", "context", "exclude", "priority", "waiting" };
    for (keys) |k| {
        if (std.mem.eql(u8, k, key)) return true;
    }
    return false;
}

/// T880: split a bundle-header list value on commas AND whitespace, dropping
/// empties (`holds=a,b c`, `needs=T1 T2`, `deliverables=a b` all share this
/// shape).  Items are dupe'd strings owned by the page allocator.
fn splitListValue(value: []const u8, out: *std.ArrayList([]const u8)) !void {
    var token_start: usize = 0;
    var i: usize = 0;
    while (i <= value.len) : (i += 1) {
        const c: u8 = if (i < value.len) value[i] else ' ';
        if (c == ',' or c == ' ' or c == '\t' or c == '\r' or c == '\n') {
            if (i > token_start) {
                const tok = std.mem.trim(u8, value[token_start..i], " \t\r\n");
                if (tok.len > 0) try out.append(alloc, try alloc.dupe(u8, tok));
            }
            token_start = i + 1;
        }
    }
}

/// T880: the registration confirmation label.  `set: A` with no holds;
/// `set: A, holds 3 (a.zig, b.zig, c.zig)` — EVERY hold that landed, and the
/// count.  The old label printed only holds[0], so a space-separated header
/// that landed three holds read identically to one that landed one — the
/// only feedback a human gets could not tell the difference.
fn holdsSetLabel(set: u8, holds: []const []const u8) ![]const u8 {
    if (holds.len == 0) return std.fmt.allocPrint(alloc, "set: {c}", .{set});
    var buf = std.ArrayList(u8).empty;
    const head = try std.fmt.allocPrint(alloc, "set: {c}, holds {d} (", .{ set, holds.len });
    defer alloc.free(head);
    try buf.appendSlice(alloc, head);
    for (holds, 0..) |h, hi| {
        if (hi > 0) try buf.appendSlice(alloc, ", ");
        try buf.appendSlice(alloc, h);
    }
    try buf.appendSlice(alloc, ")");
    return buf.toOwnedSlice(alloc);
}

/// T539: parse a comma-separated list (the `--holds a,b` flag, the `--needs
/// a,b,c` flag, and the `holds=`/`needs=` bundle keys share this).  Empty
/// items are dropped; the result is a list of dupe'd strings owned by the
/// page allocator.
fn parseHoldsList(list: []const u8) ![][]const u8 {
    var out = std.ArrayList([]const u8).empty;
    var split = std.mem.splitScalar(u8, list, ',');
    while (split.next()) |h| {
        const trimmed = std.mem.trim(u8, h, " \t");
        if (trimmed.len > 0) {
            try out.append(alloc, try alloc.dupe(u8, trimmed));
        }
    }
    return out.toOwnedSlice(alloc);
}

/// T635: read the `exclude=` list out of a bundle header WITHOUT the exit(1)
/// behavior of parseBundleMeta.  Returns null when the file is unreadable or
/// declares no `exclude=` key.  Each element is a family name (e.g. `claude`)
/// or a canonical model label (e.g. `deepseek-v4-pro`).
fn readBundleExclusions(io: std.Io, bundle_abs: []const u8) ?[][]const u8 {
    const content = std.Io.Dir.cwd().readFileAlloc(io, bundle_abs, alloc, .unlimited) catch return null;
    defer alloc.free(content);

    const marker = "<!--managent ";
    var lines = std.mem.splitScalar(u8, content, '\n');
    var line_count: usize = 0;
    var meta_line: ?[]const u8 = null;
    while (lines.next()) |line| : (line_count += 1) {
        if (line_count >= 50) break;
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (std.mem.startsWith(u8, trimmed, marker)) {
            meta_line = trimmed;
            break;
        }
    }
    const ml = meta_line orelse return null;

    const key = "exclude=";
    const idx = std.mem.indexOf(u8, ml, key) orelse return null;
    const val_start = idx + key.len;
    var val_end = val_start;
    while (val_end < ml.len and ml[val_end] != ' ' and ml[val_end] != '\t' and ml[val_end] != '\r') : (val_end += 1) {}
    if (val_end == val_start) return null;
    var value = std.mem.trim(u8, ml[val_start..val_end], " \t\r");
    if (std.mem.endsWith(u8, value, "-->")) {
        value = value[0 .. value.len - 3];
    }
    value = std.mem.trim(u8, value, " \t\r");
    if (value.len == 0) return null;
    return parseHoldsList(value) catch null;
}

fn mergeHoldsFlag(meta: *BundleMeta, holds_flag: ?[]const u8) !void {
    const hf = holds_flag orelse return;
    const flag_holds = try parseHoldsList(hf);
    var merged = std.ArrayList([]const u8).empty;
    for (meta.holds) |h| try merged.append(alloc, h);
    for (flag_holds) |h| {
        var dup = false;
        for (meta.holds) |oh| {
            if (std.mem.eql(u8, oh, h)) {
                dup = true;
                break;
            }
        }
        if (!dup) try merged.append(alloc, try alloc.dupe(u8, h));
    }
    meta.holds = try merged.toOwnedSlice(alloc);
}

/// T539: read the `holds=` list out of a bundle header WITHOUT the exit(1)
/// behavior of parseBundleMeta (used by `holds --sync` and the claim/next
/// vacuous-case guard, which must survive a malformed or missing bundle).
/// Returns null when the file is unreadable or declares no `holds=` key.
fn readBundleHolds(io: std.Io, bundle_abs: []const u8) ?[][]const u8 {
    const content = std.Io.Dir.cwd().readFileAlloc(io, bundle_abs, alloc, .unlimited) catch return null;
    defer alloc.free(content);

    const marker = "<!--managent ";
    var lines = std.mem.splitScalar(u8, content, '\n');
    var line_count: usize = 0;
    var meta_line: ?[]const u8 = null;
    while (lines.next()) |line| : (line_count += 1) {
        if (line_count >= 50) break;
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (std.mem.startsWith(u8, trimmed, marker)) {
            meta_line = trimmed;
            break;
        }
    }
    const ml = meta_line orelse return null;

    const key = "holds=";
    const idx = std.mem.indexOf(u8, ml, key) orelse return null;
    const val_start = idx + key.len;
    // T880: the value is a space/comma-separated list running until the next
    // `key=` token, the `-->` terminator, or end of line.  The old code cut
    // at the first whitespace, so `holds=a.zig b.zig c.zig` declared three
    // files but read as one — the sync and the vacuous-case guard saw the
    // same truncation as add.
    var rest = ml[val_start..];
    if (std.mem.indexOf(u8, rest, "-->")) |t| rest = rest[0..t];
    var out = std.ArrayList([]const u8).empty;
    var toks = std.mem.tokenizeAny(u8, rest, " \t\r");
    while (toks.next()) |tok| {
        // A following key (e.g. `acceptance=`) ends the holds list.
        if (std.mem.indexOfScalar(u8, tok, '=')) |eq| {
            if (isKnownMetaKey(tok[0..eq])) break;
        }
        splitListValue(tok, &out) catch return null;
    }
    if (out.items.len == 0) return null;
    return out.toOwnedSlice(alloc) catch null;
}

// ── T682: require a **Landmark:** declaration at registration ──────────
// LANDMARKS.md requires every brief to declare a landmark so work is
// reported in milestone terms — *whose* loss, and which way it cuts.  T592
// showed what happens when the rule lives only in prose: one brief
// registered without the line, five `sed`-cloned siblings inherited the
// omission, and nobody noticed until the operator did (D054's doctrine —
// prose is not a remedy for a mechanism failure).
//
// The single source of landmark IDs is docs/audits/2026-08-05-handover/
// LANDMARKS.md (L0..L7, prose table) — AS ADOPTED by D4
// (docs/status/orcha-decisions-2026-08-19.md), which ratified L8 and L9.
// LANDMARKS.md has NOT yet been updated for D4 (stale — a dashboard-truth
// debt); the union below is therefore the gate's copy of the ratified set.
// The comment is the coupling: adding a landmark means editing exactly this
// list AND LANDMARKS.md.  IDs are NOT re-derived at runtime: parsing the
// prose table would be its own fragile instrument, and it would miss the
// D4-adopted ids entirely (L10 is proposed, not ratified, and stays out).
const valid_landmark_ids = [_][]const u8{ "L0", "L1", "L2", "L3", "L4", "L5", "L6", "L7", "L8", "L9" };

const LandmarkVerdict = enum { declared, absent, invalid };

/// T682: verdict on one bundle body.  `absent` — no **Landmark:** line at
/// all (the T592 defect).  `invalid` — a line exists but declares no valid
/// id (L99, prose-only, empty).  `declared` — a valid id, or the sanctioned
/// no-landmark form (`none directly; unblocks <row>`, AGENTS.md §Landmarks).
fn checkBundleLandmark(content: []const u8) LandmarkVerdict {
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |raw| {
        var line = std.mem.trim(u8, raw, " \t\r");
        // The convention appears quoted in blockquotes and inside bullets
        // (AGENTS.md shows `> **Landmark:** ...`); strip one level of each.
        if (line.len > 1 and line[0] == '>') {
            line = std.mem.trim(u8, line[1..], " \t");
        }
        if (checkLandmarkLine(line)) |v| return v;
        if (line.len > 1 and (line[0] == '-' or line[0] == '*')) {
            const unbulleted = std.mem.trim(u8, line[1..], " \t");
            if (checkLandmarkLine(unbulleted)) |v| return v;
        }
    }
    return .absent;
}

/// T682: null when the line is not a **Landmark:** declaration; otherwise
/// the verdict for the declaration it carries.
fn checkLandmarkLine(line: []const u8) ?LandmarkVerdict {
    if (!std.mem.startsWith(u8, line, "**Landmark:**")) return null;
    const rest = std.mem.trim(u8, line["**Landmark:**".len..], " \t");
    if (rest.len == 0) return .invalid;
    // Sanctioned no-landmark form (AGENTS.md §Landmarks): an explicit
    // declaration that NO landmark applies.  "nonsense" is not this form.
    if (rest.len >= 4 and asciiEqFold(rest[0..4], "none")) {
        if (rest.len == 4 or !isAlnumAscii(rest[4])) return .declared;
    }
    if (containsValidLandmarkId(rest)) return .declared;
    return .invalid;
}

/// T682: true when `text` contains at least one valid landmark ID (L0..L9)
/// as a standalone token — "L" + digits not glued to surrounding word
/// characters ("CL1" and "L2cache" are not landmark references; "L99" is
/// a reference to a landmark that does not exist).
fn containsValidLandmarkId(text: []const u8) bool {
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        if (text[i] != 'L') continue;
        if (i > 0) {
            const prev = text[i - 1];
            if (isAlnumAscii(prev) or prev == '_') continue;
        }
        var j = i + 1;
        while (j < text.len and text[j] >= '0' and text[j] <= '9') : (j += 1) {}
        const digit_len = j - (i + 1);
        if (digit_len == 0 or digit_len > 2) continue;
        if (j < text.len and (isAlnumAscii(text[j]) or text[j] == '_')) continue;
        for (valid_landmark_ids) |v| {
            if (std.mem.eql(u8, text[i..j], v)) return true;
        }
    }
    return false;
}

fn isAlnumAscii(c: u8) bool {
    return (c >= '0' and c <= '9') or (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
}

fn asciiEqFold(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| {
        if (asciiLower(x) != asciiLower(y)) return false;
    }
    return true;
}

fn asciiLower(c: u8) u8 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

/// T682: registration-time gate — refuse a bundle whose brief declares no
/// landmark (or one that is not a real landmark), naming the file and the
/// expected form.  Exits non-zero; the row is never registered.
fn enforceBundleLandmark(w: Writers, io: std.Io, bundle_path: []const u8) void {
    const content = std.Io.Dir.cwd().readFileAlloc(io, bundle_path, alloc, .unlimited) catch |err| {
        w.diag("error: cannot read bundle {s} for landmark check: {}\n", .{ bundle_path, err });
        std.process.exit(1);
    };
    defer alloc.free(content);

    switch (checkBundleLandmark(content)) {
        .declared => {},
        .absent => {
            w.diag("error: {s} declares no **Landmark:** line.\n", .{bundle_path});
            w.diag("  Every brief declares a landmark (AGENTS.md §Landmarks / LANDMARKS.md):\n", .{});
            w.diag("    **Landmark:** advances `L<n> (<short name>)` — <which way it cuts>\n", .{});
            w.diag("    (a row that advances no landmark says: **Landmark:** none directly; unblocks <row>)\n", .{});
            w.diag("  Valid ids: ", .{});
            for (valid_landmark_ids) |v| w.diag("{s} ", .{v});
            w.diag("\n", .{});
            std.process.exit(1);
        },
        .invalid => {
            w.diag("error: {s} declares an unknown landmark id.\n", .{bundle_path});
            w.diag("  Valid ids (source: LANDMARKS.md + D4): ", .{});
            for (valid_landmark_ids) |v| w.diag("{s} ", .{v});
            w.diag("\n  Expected form: **Landmark:** advances `L<n> (<short name>)` — <which way it cuts>\n", .{});
            std.process.exit(1);
        },
    }
}

/// T539: like findBundle, but returns null instead of exiting — `holds --sync`
/// and the vacuous-case guard must not die on a row whose bundle is gone.
fn findBundleOrNull(io: std.Io, repo_root: []const u8, id: []const u8) ?[]const u8 {
    const untracked_path = std.fs.path.join(alloc, &.{ repo_root, "untracked" }) catch return null;
    defer alloc.free(untracked_path);

    var dir = std.Io.Dir.cwd().openDir(io, untracked_path, .{}) catch return null;
    defer dir.close(io);

    const prefix = std.fmt.allocPrint(alloc, "{s}-", .{id}) catch return null;
    defer alloc.free(prefix);

    var candidates = std.ArrayList([]const u8).empty;
    defer {
        for (candidates.items) |c| alloc.free(c);
        candidates.deinit(alloc);
    }

    var iter = dir.iterate();
    while (iter.next(io) catch return null) |entry| {
        if (entry.kind != .file) continue;
        if (std.mem.startsWith(u8, entry.name, prefix) and std.mem.endsWith(u8, entry.name, ".md")) {
            candidates.append(alloc, alloc.dupe(u8, entry.name) catch return null) catch return null;
        }
    }
    if (candidates.items.len == 0) return null;

    std.mem.sort([]const u8, candidates.items, {}, struct {
        fn lt(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lt);

    return std.fs.path.join(alloc, &.{ repo_root, "untracked", candidates.items[0] }) catch null;
}

/// T539: resolve a row's bundle to an absolute path, preferring the live glob
/// (untracked/<id>-*.md, the same glob registration uses) over the stored
/// `bundle` field (which can be absolute or stale).
fn bundleAbsFor(io: std.Io, repo_root: []const u8, id: []const u8, bundle: []const u8) ?[]const u8 {
    if (findBundleOrNull(io, repo_root, id)) |found| return found;
    if (bundle.len == 0) return null;
    if (std.fs.path.isAbsolute(bundle)) return bundle;
    return std.fs.path.join(alloc, &.{ repo_root, bundle }) catch null;
}

/// T539: the holds the one-writer check should actually use for a row about to
/// be claimed.  When the store's holds is non-empty it is authoritative.  When
/// it is EMPTY but the bundle header declares holds, the registration path
/// dropped them — the invariant's input is missing, so we must say so rather
/// than silently return "no conflict".  Warn on stderr naming the row and the
/// files, and use the bundle's declaration for the check so the mechanism is
/// not blind.  (The permanent fix is `managent holds --sync`.)
fn effectiveHolds(w: Writers, io: std.Io, repo_root: []const u8, id: []const u8, ts: TaskState) [][]const u8 {
    if (ts.holds.len > 0) return ts.holds;
    const abs = bundleAbsFor(io, repo_root, id, ts.bundle) orelse return ts.holds;
    const declared = readBundleHolds(io, abs) orelse return ts.holds;
    if (declared.len == 0) return ts.holds;
    w.diag("  warning: {s} declares holds in its bundle but the store row has none", .{id});
    w.diag(" (registration gap — one-writer check is using the bundle's holds)", .{});
    for (declared) |h| w.diag(" {s}", .{h});
    w.diag("\n  run 'managent holds --sync' to reconcile the store\n", .{});
    return declared;
}

/// T627: mechanical scope facts, computed at dispatch/claim time from the
/// bundle — never asked of a worker.  brief_bytes is the bundle file size;
/// files_in_scope is the count of UNIQUE paths across the bundle's
/// deliverables= and holds= (the files the task promises to touch or produce).
/// Returns nulls (UNKNOWN) when the bundle cannot be read — an unmeasurable
/// scope is a fact, distinct from an empty one.
const ScopeFacts = struct {
    brief_bytes: ?u64,
    files_in_scope: ?u32,
};

fn computeScopeFacts(w: Writers, io: std.Io, repo_root: []const u8, id: []const u8, ts: TaskState) !ScopeFacts {
    const abs = bundleAbsFor(io, repo_root, id, ts.bundle) orelse
        return .{ .brief_bytes = null, .files_in_scope = null };
    const content = std.Io.Dir.cwd().readFileAlloc(io, abs, alloc, .unlimited) catch
        return .{ .brief_bytes = null, .files_in_scope = null };
    defer alloc.free(content);

    // holds: the stored list is authoritative when present; otherwise read the
    // bundle header's holds= so a registration-gap row still gets a real count.
    const holds: []const []const u8 = if (ts.holds.len > 0) ts.holds else (readBundleHolds(io, abs) orelse &.{});

    const dels = try parseDeliverablesFromBundle(w, io, abs, holds);
    defer {
        for (dels) |d| alloc.free(d);
        alloc.free(dels);
    }

    var set = std.StringHashMapUnmanaged(void).empty;
    defer set.deinit(alloc);
    for (holds) |h| set.put(alloc, h, {}) catch {};
    for (dels) |d| set.put(alloc, d, {}) catch {};

    return .{
        .brief_bytes = content.len,
        .files_in_scope = @intCast(set.count()),
    };
}

/// T627: write the scope enumeration onto a row.  `targets` (when non-null) is
/// an owned, already-parsed target list (from --scope-targets);
/// `unenumerable_reason` (when non-null) records that the set genuinely cannot
/// be enumerated in advance.  Both null clears the statement to UNKNOWN — a
/// re-dispatch without a scope flag is a fresh UNKNOWN, not a stale carry-over.
/// Old scope_targets/scope_note are freed first.
fn setScopeEnumeration(ts: *TaskState, targets: ?[][]const u8, unenumerable_reason: ?[]const u8) !void {
    for (ts.scope_targets) |t| alloc.free(t);
    alloc.free(ts.scope_targets);
    if (ts.scope_note) |sn| alloc.free(sn);
    ts.scope_targets = &.{};
    ts.scope_note = null;
    if (targets) |t| {
        ts.scope_targets = t;
        ts.scope_enumerable = true;
    } else if (unenumerable_reason) |r| {
        ts.scope_note = try alloc.dupe(u8, r);
        ts.scope_enumerable = false;
    } else {
        ts.scope_enumerable = null;
    }
}

// ── state file ──────────────────────────────────────────────────────────────

/// Exclusive flock on the store, released by unlockStore or process exit (any
/// exit path — crash, SIGKILL, std.process.exit).  Uses flock(2): the kernel
/// releases the lock atomically when the holder's fd is closed, which happens
/// on ANY process termination.  This replaces the mkdir mutex that leaked on
/// every std.process.exit(1) after lock acquisition (T337 S0, 2026-08-04).
///
/// Bounded wait: ~10 attempts over ~3s.  On exhaustion, fails loudly with the
/// holder's PID and timestamp rather than hanging forever.
fn lockStore(io: std.Io, state_path: []const u8) !void {
    const lock_path = try std.fmt.allocPrint(alloc, "{s}.lockfile", .{state_path});
    defer alloc.free(lock_path);

    // Ensure the parent directory exists
    if (std.fs.path.dirname(lock_path)) |dp| {
        std.Io.Dir.cwd().createDirPath(io, dp) catch {};
    }

    const now = try nowTimestamp();

    // Open or create the lock file with O_RDWR | O_CREAT | O_CLOEXEC.
    // Use std.posix.O struct for platform-correct flag encoding.
    const open_flags = std.posix.O{
        .ACCMODE = .RDWR,
        .CREAT = true,
        .CLOEXEC = true,
    };

    // Try bounded non-blocking flock with backoff.
    const max_attempts: u8 = 10;
    var attempt: u8 = 0;
    while (attempt < max_attempts) : (attempt += 1) {
        const fd = std.c.open(@ptrCast(lock_path), open_flags, @as(c_int, 0o644));
        if (fd == -1) {
            // File might not be creatable — backoff and retry
            const backoff_ms: u64 = @as(u64, 10) << @intCast(@min(attempt, 6));
            const req: std.c.timespec = .{
                .sec = @intCast(backoff_ms / 1000),
                .nsec = @intCast((backoff_ms % 1000) * std.time.ns_per_ms),
            };
            _ = std.c.nanosleep(&req, null);
            continue;
        }

        const lock_rc = std.c.flock(fd, std.posix.LOCK.EX | std.posix.LOCK.NB);
        if (lock_rc == 0) {
            // Lock acquired.  Write PID + timestamp for diagnostics.
            const pid = std.c.getpid();
            const diag = try std.fmt.allocPrint(alloc, "pid={d} since={s}", .{ pid, now });
            defer alloc.free(diag);
            _ = std.c.pwrite(fd, diag.ptr, diag.len, 0);
            _ = std.c.ftruncate(fd, @intCast(diag.len));
            LOCK_FD = fd;
            return;
        }

        const err = std.c.errno(lock_rc);
        _ = std.c.close(fd);
        if (err != .AGAIN) {
            return error.LockFailed;
        }

        const backoff_ms: u64 = @as(u64, 10) << @intCast(@min(attempt, 6));
        const req: std.c.timespec = .{
            .sec = @intCast(backoff_ms / 1000),
            .nsec = @intCast((backoff_ms % 1000) * std.time.ns_per_ms),
        };
        _ = std.c.nanosleep(&req, null);
    }

    // Bound exhausted — fail loudly (~3.2s total).
    const content = std.Io.Dir.cwd().readFileAlloc(io, lock_path, alloc, .limited(256)) catch "(unreadable)";
    defer if (!std.mem.eql(u8, content, "(unreadable)")) alloc.free(content);
    std.debug.print("FATAL: store locked for >3s ({s}).  If the holder is dead, remove {s}\n", .{ content, lock_path });
    return error.StoreLocked;
}

/// Release the flock acquired by lockStore.
fn unlockStore() void {
    if (LOCK_FD == -1) return;
    _ = std.c.flock(LOCK_FD, std.posix.LOCK.UN);
    _ = std.c.close(LOCK_FD);
    LOCK_FD = -1;
}

var LOCK_FD: std.c.fd_t = -1;

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

/// T317/T337: write the store without acquiring the lock — caller already holds
/// the exclusive flock (lockStore).  The lock→read→modify→write→unlock
/// pattern closes the lost-update window (2026-08-03 incident: T326's
/// registration erased by a stale read-modify-write from another console).
fn writeStateLocked(io: std.Io, state_path: []const u8, state: *StateMap) !void {
    try ensureStateDir(io, state_path);

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(alloc);
    try serializeState(state, &buf);

    // T399: refuse to write an unreadable store.  Escaping makes the output
    // valid by construction; this re-parse is the write-site guard that turns
    // the 2026-08-06 failure mode (amend reported success while writing
    // unparseable tasks.json → every reader crashed) into a loud error.
    {
        var check = std.json.parseFromSlice(std.json.Value, alloc, buf.items, .{ .allocate = .alloc_always }) catch {
            return error.StateWriteNotRoundTrip;
        };
        check.deinit();
    }

    // S10 store-loss detector (T848): the census rides the live kanban store
    // (basename tasks.json) only — archive.json and any other sibling written
    // through this same call (e.g. cmdArchive's second write) carry no census.
    const live_store = std.mem.eql(u8, std.fs.path.basename(state_path), "tasks.json");

    // S10-STORE-2: write-time check — refuse an unexplained shrink BEFORE this
    // write (fail-closed: committing on top of a reverted store makes the loss
    // harder to reconstruct).  A shrink explained by this write's own
    // retirement bookkeeping (purge/archive/retire) or by the reasoned escape
    // (--reconcile-store-loss) proceeds.
    if (live_store) try checkCensusBeforeWrite(io, state_path);

    // S10-STORE-1: write the census BEFORE the store, in the same lock hold
    // and the same code path (one writer, one place).  Census-first means a
    // crash between the two renames leaves the census AHEAD of the store —
    // the next write sees live >= census (no shrink) and heals silently.  The
    // store-first order would leave the census BEHIND and a legitimate purge's
    // next write would read as a false shrink.
    if (live_store) try writeCensus(io, state_path, state, buf.items);

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
        // T108: sync before close — the rename below is a synchronous syscall
        // that can beat the IO thread's write/flush, causing the ~40% silent
        // write-loss race. fsync ensures data is on disk before the rename.
        try tmp_file.sync(io);
    }

    const state_dir = try std.Io.Dir.cwd().openDir(io, dirname, .{});
    defer state_dir.close(io);
    try state_dir.rename(tmp_name, state_dir, basename, io);
}

/// Locking wrapper — acquires the exclusive flock, calls writeStateLocked,
/// releases.  Use writeStateLocked directly in mutating commands that already
/// hold the lock (T317 lost-update pattern: lock → re-read → modify →
/// writeStateLocked → unlock).
fn writeState(io: std.Io, state_path: []const u8, state: *StateMap) !void {
    try ensureStateDir(io, state_path);
    try lockStore(io, state_path);
    defer unlockStore();
    try writeStateLocked(io, state_path, state);
}

// ── S10 store-loss detector (T848) ──────────────────────────────────────────
// A committed census (docs/infra/managent/store-census.json beside the live
// store, or a sibling of a scratch MANAGENT_STORE) records the live row count,
// a digest of the store bytes, the ids, and the command that wrote it — updated
// on every write of the live store (tasks.json), in the same lock hold and the
// same code path, so a checkout of one wave gets a consistent pair.
//
// Known limitation, stated honestly (spec S10 §2.4): a wholesale `git checkout`
// of an old commit reverts store AND census together — the pair stays internally
// consistent and this detector cannot see it.  It catches the measured failure:
// a silent single-file revert of tasks.json alone, where the census would still
// reflect the larger store.

fn censusPathFor(state_path: []const u8) ![]u8 {
    const dirname = std.fs.path.dirname(state_path) orelse ".";
    return std.fs.path.join(alloc, &.{ dirname, "store-census.json" });
}

fn storeDigestHex(content: []const u8) [64]u8 {
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(content, &digest, .{});
    const hex_chars = "0123456789abcdef";
    var out: [64]u8 = undefined;
    for (0..32) |i| {
        out[i * 2] = hex_chars[digest[i] >> 4];
        out[i * 2 + 1] = hex_chars[digest[i] & 0xF];
    }
    return out;
}

const Census = struct {
    present: bool = false,
    row_count: u64 = 0,
    ids: []const []const u8 = &.{},
};

fn readCensusAt(io: std.Io, census_path: []const u8) !Census {
    const content = std.Io.Dir.cwd().readFileAlloc(io, census_path, alloc, .unlimited) catch |err| {
        if (err == error.FileNotFound) return Census{};
        return err;
    };
    defer alloc.free(content);

    var parsed = std.json.parseFromSlice(std.json.Value, alloc, content, .{ .allocate = .alloc_always }) catch {
        std.debug.print("WARNING: store census unparseable ({s}) — treated as absent; the next write rewrites it\n", .{census_path});
        return Census{};
    };
    defer parsed.deinit();

    if (parsed.value != .object) return Census{};
    var c = Census{ .present = true };
    if (parsed.value.object.get("row_count")) |v| {
        if (v == .integer) c.row_count = @intCast(v.integer);
    }
    if (parsed.value.object.get("ids")) |v| {
        if (v == .array) {
            var list = std.ArrayList([]const u8).empty;
            for (v.array.items) |item| {
                if (item == .string) list.append(alloc, try alloc.dupe(u8, item.string)) catch {};
            }
            c.ids = try list.toOwnedSlice(alloc);
        }
    }
    return c;
}

/// Side-effect-free count of the task rows in raw store bytes (keys not
/// prefixed with `_`).  Unlike readState/parseStateJson this does NOT touch the
/// sys_* globals, so it is safe to call from the write path after the caller has
/// already loaded and modified the in-memory state.
fn countTaskIds(content: []const u8) ![]const []const u8 {
    const trimmed = std.mem.trim(u8, content, " \t\n\r");
    if (trimmed.len == 0 or std.mem.eql(u8, trimmed, "{}")) return &.{};
    var parsed = try std.json.parseFromSlice(std.json.Value, alloc, content, .{ .allocate = .alloc_always });
    defer parsed.deinit();
    if (parsed.value != .object) return &.{};
    var list = std.ArrayList([]const u8).empty;
    var it = parsed.value.object.iterator();
    while (it.next()) |entry| {
        const key = entry.key_ptr.*;
        if (std.mem.startsWith(u8, key, "_")) continue;
        list.append(alloc, try alloc.dupe(u8, key)) catch {};
    }
    return list.toOwnedSlice(alloc);
}

fn subsetOf(a: []const []const u8, b: []const []const u8) bool {
    for (a) |x| {
        var found = false;
        for (b) |y| {
            if (std.mem.eql(u8, x, y)) {
                found = true;
                break;
            }
        }
        if (!found) return false;
    }
    return true;
}

fn printMissingIds(missing: []const []const u8) void {
    for (missing, 0..) |m, i| {
        if (i > 0) std.debug.print(" ", .{});
        std.debug.print("{s}", .{m});
    }
}

fn refuseStoreShrink(live_count: usize, census_count: u64, missing: []const []const u8, census_path: []const u8) noreturn {
    std.debug.print("\n  REFUSED: store-loss detector — the live store is smaller than the committed census.\n", .{});
    std.debug.print("  live rows: {d}  census rows: {d}  (shrink of {d})\n", .{ live_count, census_count, census_count - @as(u64, @intCast(live_count)) });
    std.debug.print("  missing ids: ", .{});
    printMissingIds(missing);
    std.debug.print("\n  census: {s}\n", .{census_path});
    std.debug.print("  Committing on top of a reverted store makes the loss harder to reconstruct.\n", .{});
    std.debug.print("  Accept by fiat: re-run with --reconcile-store-loss \"<reason>\".\n", .{});
    std.debug.print("  Or restore: git checkout the last good tasks.json (store AND census) first.\n", .{});
    std.process.exit(1);
}

fn alarmReadShrink(live_count: usize, census_count: u64, missing: []const []const u8, census_path: []const u8) void {
    std.debug.print("\n  ALARM: store-loss detector — live store ({d} rows) is smaller than the committed census ({d} rows).\n", .{ live_count, census_count });
    std.debug.print("  missing ids: ", .{});
    printMissingIds(missing);
    std.debug.print("\n  census: {s}\n", .{census_path});
    std.debug.print("  This is exactly how the 2026-08-24 59-task loss looked; verify before mutating.\n", .{});
}

fn checkCensusBeforeWrite(io: std.Io, state_path: []const u8) !void {
    const census_path = try censusPathFor(state_path);
    defer alloc.free(census_path);
    const census = try readCensusAt(io, census_path);
    if (!census.present) return; // no census yet — this write creates it

    const live_ids = blk: {
        const content = std.Io.Dir.cwd().readFileAlloc(io, state_path, alloc, .unlimited) catch |err| {
            if (err == error.FileNotFound) break :blk &.{};
            return err;
        };
        defer alloc.free(content);
        break :blk try countTaskIds(content);
    };

    if (live_ids.len >= census.row_count) return; // no shrink

    var missing = std.ArrayList([]const u8).empty;
    defer missing.deinit(alloc);
    for (census.ids) |cid| {
        var found = false;
        for (live_ids) |lid| {
            if (std.mem.eql(u8, cid, lid)) {
                found = true;
                break;
            }
        }
        if (!found) missing.append(alloc, cid) catch {};
    }

    const explained = reconcile_reason != null or (retiring_ids.len > 0 and subsetOf(missing.items, retiring_ids));
    if (explained) {
        std.debug.print("\n  store-loss detector: shrink of {d} explained by {s}\n", .{
            census.row_count - @as(u64, @intCast(live_ids.len)),
            if (reconcile_reason) |r| r else "this command's retirement bookkeeping",
        });
        return;
    }

    refuseStoreShrink(live_ids.len, census.row_count, missing.items, census_path);
}

fn checkCensusRead(io: std.Io, state_path: []const u8) !bool {
    const census_path = try censusPathFor(state_path);
    defer alloc.free(census_path);
    const census = try readCensusAt(io, census_path);
    if (!census.present) return false;

    const live_ids = blk: {
        const content = std.Io.Dir.cwd().readFileAlloc(io, state_path, alloc, .unlimited) catch |err| {
            if (err == error.FileNotFound) break :blk &.{};
            return err;
        };
        defer alloc.free(content);
        break :blk try countTaskIds(content);
    };

    if (live_ids.len >= census.row_count) return false;

    var missing = std.ArrayList([]const u8).empty;
    defer missing.deinit(alloc);
    for (census.ids) |cid| {
        var found = false;
        for (live_ids) |lid| {
            if (std.mem.eql(u8, cid, lid)) {
                found = true;
                break;
            }
        }
        if (!found) missing.append(alloc, cid) catch {};
    }

    alarmReadShrink(live_ids.len, census.row_count, missing.items, census_path);
    return true;
}

fn writeCensus(io: std.Io, state_path: []const u8, state: *StateMap, store_bytes: []const u8) !void {
    const census_path = try censusPathFor(state_path);
    defer alloc.free(census_path);
    try ensureStateDir(io, census_path);

    const digest = storeDigestHex(store_bytes);
    const now = try nowTimestamp();
    defer alloc.free(now);

    // Sorted id list — deterministic output, and the set the write-time check
    // diffs against to name the missing ids.
    var id_list = std.ArrayList([]const u8).empty;
    defer id_list.deinit(alloc);
    {
        var it = state.iterator();
        while (it.next()) |entry| try id_list.append(alloc, entry.key_ptr.*);
    }
    const sortFn = struct {
        fn lt(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lt;
    std.mem.sort([]const u8, id_list.items, {}, sortFn);

    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(alloc);
    try buf.appendSlice(alloc, "{\n  \"row_count\": ");
    try buf.appendSlice(alloc, try std.fmt.allocPrint(alloc, "{d}", .{state.count()}));
    try buf.appendSlice(alloc, ",\n  \"digest\": \"");
    try buf.appendSlice(alloc, &digest);
    try buf.appendSlice(alloc, "\",\n  \"written_by\": ");

    // written_by carries the verb plus any retirement/reconcile note, so a
    // legitimate shrink is recorded where the census itself lives.
    var wb: std.ArrayList(u8) = .empty;
    defer wb.deinit(alloc);
    try wb.appendSlice(alloc, current_cmd);
    if (retiring_ids.len > 0) {
        try wb.appendSlice(alloc, " (retired:");
        for (retiring_ids) |rid| try wb.appendSlice(alloc, try std.fmt.allocPrint(alloc, " {s}", .{rid}));
        try wb.appendSlice(alloc, ")");
    }
    if (reconcile_reason) |r| {
        try wb.appendSlice(alloc, " [reconcile-store-loss: ");
        try wb.appendSlice(alloc, r);
        try wb.appendSlice(alloc, "]");
    }
    try writeJsonString(&buf, wb.items);

    try buf.appendSlice(alloc, ",\n  \"updated\": ");
    try writeJsonString(&buf, now);
    try buf.appendSlice(alloc, ",\n  \"ids\": [");
    for (id_list.items, 0..) |id, i| {
        if (i > 0) try buf.appendSlice(alloc, ", ");
        try writeJsonString(&buf, id);
    }
    try buf.appendSlice(alloc, "]\n}\n");

    // Atomic write — the same tmp+fsync+rename pattern as the store itself.
    const dirname = std.fs.path.dirname(census_path) orelse ".";
    const basename = std.fs.path.basename(census_path);
    var tmp_name_buf: [256]u8 = undefined;
    const tmp_name = try std.fmt.bufPrint(&tmp_name_buf, "{s}.tmp.{d}", .{ basename, nowMs() });
    const tmp_path = try std.fs.path.join(alloc, &.{ dirname, tmp_name });
    defer alloc.free(tmp_path);
    {
        const tmp_file = try std.Io.Dir.cwd().createFile(io, tmp_path, .{});
        defer tmp_file.close(io);
        try tmp_file.writeStreamingAll(io, buf.items);
        try tmp_file.sync(io);
    }
    const dir = try std.Io.Dir.cwd().openDir(io, dirname, .{});
    defer dir.close(io);
    try dir.rename(tmp_name, dir, basename, io);
}

var sys_next_id: u32 = 100; // monotonic task-ID counter, loaded from _sys
var sys_directive_next: u32 = 1; // monotonic directive-ID counter, loaded from _sys
var sys_assertion_next: u32 = 1; // monotonic assertion-ID counter, loaded from _sys
var sys_closes: u64 = 0; // T478: total task closes, loaded from _sys (duty due-count)
var sys_duty_migrated: bool = false; // T478: one-time duty-flag migration marker

// S10 store-loss detector globals (T848).  current_cmd is the verb this
// invocation runs (set in main); retiring_ids names the rows THIS write
// retires (set by purge/archive/retire) so an explained shrink is not a false
// alarm; reconcile_reason is the --reconcile-store-loss <reason> escape.
var current_cmd: []const u8 = "";
var retiring_ids: []const []const u8 = &.{};
var reconcile_reason: ?[]const u8 = null;

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

    // Load _sys metadata (counter, aliases, directive counter)
    // T204: track max parsed T<N> ID to catch next_id ≤ existing task
    var max_parsed_id: u32 = 0;

    if (parsed.value.object.get("_sys")) |sys_val| {
        if (sys_val == .object) {
            if (sys_val.object.get("next_id")) |nv| {
                if (nv == .integer) sys_next_id = @intCast(nv.integer);
            }
            if (sys_val.object.get("directive_next")) |dv| {
                if (dv == .integer) sys_directive_next = @intCast(dv.integer);
            }
            if (sys_val.object.get("assertion_next")) |av| {
                if (av == .integer) sys_assertion_next = @intCast(av.integer);
            }
            if (sys_val.object.get("closes")) |cv| {
                if (cv == .integer) sys_closes = @intCast(cv.integer);
            }
            if (sys_val.object.get("duty_migrated")) |dv| {
                if (dv == .bool) sys_duty_migrated = dv.bool;
            }
        }
    }

    var it = parsed.value.object.iterator();
    while (it.next()) |entry| {
        const key = entry.key_ptr.*;
        // Skip metadata keys (prefixed with _)
        if (std.mem.startsWith(u8, key, "_")) continue;

        // T204: track max parsed T<N> ID
        if (std.mem.startsWith(u8, key, "T")) {
            const num_part = key[1..];
            const parsed_num = std.fmt.parseInt(u32, num_part, 10) catch 0;
            if (parsed_num > max_parsed_id) max_parsed_id = parsed_num;
        }

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
        if (obj.object.get("model")) |mv| {
            if (mv == .string) ts.model = try alloc.dupe(u8, mv.string);
        }
        if (obj.object.get("model_source")) |msv| {
            if (msv == .string) ts.model_source = try alloc.dupe(u8, msv.string);
        }
        if (obj.object.get("model_unknown_reason")) |mur| {
            if (mur == .string) ts.model_unknown_reason = try alloc.dupe(u8, mur.string);
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
        // T635: mechanized assignment record.
        if (obj.object.get("candidates")) |cv| {
            if (cv == .array) {
                var list = std.ArrayList([]const u8).empty;
                for (cv.array.items) |item| {
                    if (item == .string) {
                        try list.append(alloc, try alloc.dupe(u8, item.string));
                    }
                }
                ts.candidates = try list.toOwnedSlice(alloc);
            }
        }
        if (obj.object.get("method")) |mv| {
            if (mv == .string) ts.method = try alloc.dupe(u8, mv.string);
        }
        if (obj.object.get("assign_reasons")) |rv| {
            if (rv == .array) {
                var list = std.ArrayList([]const u8).empty;
                for (rv.array.items) |item| {
                    if (item == .string) {
                        try list.append(alloc, try alloc.dupe(u8, item.string));
                    }
                }
                ts.assign_reasons = try list.toOwnedSlice(alloc);
            }
        }
        // T636: row shape + shape-selection notes.
        if (obj.object.get("shape")) |sv3| {
            if (sv3 == .string) ts.shape = try alloc.dupe(u8, sv3.string);
        }
        if (obj.object.get("shape_reasons")) |srv| {
            if (srv == .array) {
                var list = std.ArrayList([]const u8).empty;
                for (srv.array.items) |item| {
                    if (item == .string) {
                        try list.append(alloc, try alloc.dupe(u8, item.string));
                    }
                }
                ts.shape_reasons = try list.toOwnedSlice(alloc);
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
        if (obj.object.get("verdict")) |vd| {
            if (vd == .string) ts.verdict = try alloc.dupe(u8, vd.string);
        }
        if (obj.object.get("verdict_note")) |vn| {
            if (vn == .string) ts.verdict_note = try alloc.dupe(u8, vn.string);
        }
        if (obj.object.get("impression")) |im| {
            if (im == .string) ts.impression = try alloc.dupe(u8, im.string);
        }
        if (obj.object.get("impression_waiver")) |iw| {
            if (iw == .string) ts.impression_waiver = try alloc.dupe(u8, iw.string);
        }
        if (obj.object.get("acceptance")) |ac| {
            if (ac == .string) ts.acceptance = try alloc.dupe(u8, ac.string);
        }
        if (obj.object.get("skip_acceptance_reason")) |sr| {
            if (sr == .string) ts.skip_acceptance_reason = try alloc.dupe(u8, sr.string);
        }
        if (obj.object.get("claim_count")) |cc| {
            if (cc == .integer) ts.claim_count = @intCast(cc.integer);
        }
        if (obj.object.get("duty")) |dv| {
            if (dv == .bool) ts.duty = dv.bool;
        }
        if (obj.object.get("due_after")) |dv| {
            if (dv == .integer) ts.due_after = @intCast(dv.integer);
        }
        if (obj.object.get("last_chunk_closes")) |dv| {
            if (dv == .integer) ts.last_chunk_closes = @intCast(dv.integer);
        }
        if (obj.object.get("last_chunk_ts")) |dv| {
            if (dv == .string) ts.last_chunk_ts = try alloc.dupe(u8, dv.string);
        }
        if (obj.object.get("last_chunk_verdict")) |dv| {
            if (dv == .string) ts.last_chunk_verdict = try alloc.dupe(u8, dv.string);
        }
        if (obj.object.get("last_chunk_findings")) |dv| {
            if (dv == .string) ts.last_chunk_findings = try alloc.dupe(u8, dv.string);
        }
        if (obj.object.get("amendments")) |am| {
            if (am == .array) {
                var list = std.ArrayList([]const u8).empty;
                for (am.array.items) |item| {
                    if (item == .string) {
                        try list.append(alloc, try alloc.dupe(u8, item.string));
                    }
                }
                ts.amendments = try list.toOwnedSlice(alloc);
            }
        }
        if (obj.object.get("epitaph")) |ep| {
            if (ep == .string) ts.epitaph = try alloc.dupe(u8, ep.string);
        }
        // T627: dispatch scope fields (null = UNKNOWN, distinct from 0/none).
        if (obj.object.get("brief_bytes")) |b| {
            if (b == .integer) ts.brief_bytes = @intCast(b.integer);
        }
        if (obj.object.get("files_in_scope")) |f| {
            if (f == .integer) ts.files_in_scope = @intCast(f.integer);
        }
        if (obj.object.get("expected_wall_s")) |e| {
            if (e == .integer) ts.expected_wall_s = @intCast(e.integer);
        }
        if (obj.object.get("scope_enumerable")) |se| {
            if (se == .bool) ts.scope_enumerable = se.bool;
        }
        if (obj.object.get("scope_targets")) |st| {
            if (st == .array) {
                var list = std.ArrayList([]const u8).empty;
                for (st.array.items) |item| {
                    if (item == .string) {
                        try list.append(alloc, try alloc.dupe(u8, item.string));
                    }
                }
                ts.scope_targets = try list.toOwnedSlice(alloc);
            }
        }
        if (obj.object.get("scope_note")) |sn| {
            if (sn == .string) ts.scope_note = try alloc.dupe(u8, sn.string);
        }

        try state.put(alloc, task_id, ts);
    }

    // T204: ensure next_id strictly exceeds all existing T<N> IDs
    if (max_parsed_id > 0 and sys_next_id <= max_parsed_id) {
        sys_next_id = max_parsed_id + 1;
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

        try buf.appendSlice(alloc, "\n  ");
        try writeJsonString(buf, entry.key_ptr.*);
        try buf.appendSlice(alloc, ": {");

        const ts = entry.value_ptr.*;
        try buf.appendSlice(alloc, "\n    \"status\": ");
        try writeJsonString(buf, statusToString(ts.status));

        if (ts.agent) |a| {
            try buf.appendSlice(alloc, ",\n    \"agent\": ");
            try writeJsonString(buf, a);
        } else {
            try buf.appendSlice(alloc, ",\n    \"agent\": null");
        }

        if (ts.model) |m| {
            try buf.appendSlice(alloc, ",\n    \"model\": ");
            try writeJsonString(buf, m);
        } else {
            try buf.appendSlice(alloc, ",\n    \"model\": null");
        }

        if (ts.model_source) |ms| {
            try buf.appendSlice(alloc, ",\n    \"model_source\": ");
            try writeJsonString(buf, ms);
        } else {
            try buf.appendSlice(alloc, ",\n    \"model_source\": null");
        }

        if (ts.model_unknown_reason) |mur| {
            try buf.appendSlice(alloc, ",\n    \"model_unknown_reason\": ");
            try writeJsonString(buf, mur);
        } else {
            try buf.appendSlice(alloc, ",\n    \"model_unknown_reason\": null");
        }

        try buf.appendSlice(alloc, ",\n    \"bundle\": ");
        try writeJsonString(buf, ts.bundle);

        try buf.appendSlice(alloc, ",\n    \"set\": ");
        try writeJsonString(buf, &.{ts.set});

        try buf.appendSlice(alloc, ",\n    \"holds\": [");
        for (ts.holds, 0..) |h, hi| {
            if (hi > 0) try buf.appendSlice(alloc, ", ");
            try writeJsonString(buf, h);
        }
        try buf.appendSlice(alloc, "]");

        try buf.appendSlice(alloc, ",\n    \"needs\": [");
        for (ts.needs, 0..) |n, ni| {
            if (ni > 0) try buf.appendSlice(alloc, ", ");
            try writeJsonString(buf, n);
        }
        try buf.appendSlice(alloc, "]");

        try buf.appendSlice(alloc, ",\n    \"caps\": [");
        for (ts.caps, 0..) |c, ci| {
            if (ci > 0) try buf.appendSlice(alloc, ", ");
            try writeJsonString(buf, c);
        }
        try buf.appendSlice(alloc, "]");

        // T635: mechanized assignment record (candidates / method / reasons).
        try buf.appendSlice(alloc, ",\n    \"candidates\": [");
        for (ts.candidates, 0..) |c, ci| {
            if (ci > 0) try buf.appendSlice(alloc, ", ");
            try writeJsonString(buf, c);
        }
        try buf.appendSlice(alloc, "]");

        if (ts.method) |m| {
            try buf.appendSlice(alloc, ",\n    \"method\": ");
            try writeJsonString(buf, m);
        } else {
            try buf.appendSlice(alloc, ",\n    \"method\": null");
        }

        try buf.appendSlice(alloc, ",\n    \"assign_reasons\": [");
        for (ts.assign_reasons, 0..) |r, ri| {
            if (ri > 0) try buf.appendSlice(alloc, ", ");
            try writeJsonString(buf, r);
        }
        try buf.appendSlice(alloc, "]");

        // T636: row shape + shape-selection notes.
        if (ts.shape) |sh| {
            try buf.appendSlice(alloc, ",\n    \"shape\": ");
            try writeJsonString(buf, sh);
        } else {
            try buf.appendSlice(alloc, ",\n    \"shape\": null");
        }
        try buf.appendSlice(alloc, ",\n    \"shape_reasons\": [");
        for (ts.shape_reasons, 0..) |r, ri| {
            if (ri > 0) try buf.appendSlice(alloc, ", ");
            try writeJsonString(buf, r);
        }
        try buf.appendSlice(alloc, "]");

        try buf.appendSlice(alloc, ",\n    \"added\": ");
        try writeJsonString(buf, ts.added);

        if (ts.claimed) |c| {
            try buf.appendSlice(alloc, ",\n    \"claimed\": ");
            try writeJsonString(buf, c);
        } else {
            try buf.appendSlice(alloc, ",\n    \"claimed\": null");
        }

        if (ts.done) |d| {
            try buf.appendSlice(alloc, ",\n    \"done\": ");
            try writeJsonString(buf, d);
        } else {
            try buf.appendSlice(alloc, ",\n    \"done\": null");
        }

        if (ts.dispatched) |dp| {
            try buf.appendSlice(alloc, ",\n    \"dispatched\": ");
            try writeJsonString(buf, dp);
        } else {
            try buf.appendSlice(alloc, ",\n    \"dispatched\": null");
        }

        if (ts.dispatched_to) |dt| {
            try buf.appendSlice(alloc, ",\n    \"dispatched_to\": ");
            try writeJsonString(buf, dt);
        } else {
            try buf.appendSlice(alloc, ",\n    \"dispatched_to\": null");
        }

        if (ts.note) |nt| {
            try buf.appendSlice(alloc, ",\n    \"note\": ");
            try writeJsonString(buf, nt);
        } else {
            try buf.appendSlice(alloc, ",\n    \"note\": null");
        }

        if (ts.verdict) |vd| {
            try buf.appendSlice(alloc, ",\n    \"verdict\": ");
            try writeJsonString(buf, vd);
        } else {
            try buf.appendSlice(alloc, ",\n    \"verdict\": null");
        }

        if (ts.verdict_note) |vn| {
            try buf.appendSlice(alloc, ",\n    \"verdict_note\": ");
            try writeJsonString(buf, vn);
        } else {
            try buf.appendSlice(alloc, ",\n    \"verdict_note\": null");
        }

        if (ts.impression) |im| {
            try buf.appendSlice(alloc, ",\n    \"impression\": ");
            try writeJsonString(buf, im);
        } else {
            try buf.appendSlice(alloc, ",\n    \"impression\": null");
        }

        if (ts.impression_waiver) |iw| {
            try buf.appendSlice(alloc, ",\n    \"impression_waiver\": ");
            try writeJsonString(buf, iw);
        } else {
            try buf.appendSlice(alloc, ",\n    \"impression_waiver\": null");
        }

        try buf.appendSlice(alloc, ",\n    \"claim_count\": ");
        try buf.appendSlice(alloc, try std.fmt.allocPrint(alloc, "{d}", .{ts.claim_count}));

        // T478: duty fields
        try buf.appendSlice(alloc, ",\n    \"duty\": ");
        try buf.appendSlice(alloc, if (ts.duty) "true" else "false");
        try buf.appendSlice(alloc, ",\n    \"due_after\": ");
        try buf.appendSlice(alloc, try std.fmt.allocPrint(alloc, "{d}", .{ts.due_after}));
        try buf.appendSlice(alloc, ",\n    \"last_chunk_closes\": ");
        try buf.appendSlice(alloc, try std.fmt.allocPrint(alloc, "{d}", .{ts.last_chunk_closes}));
        if (ts.last_chunk_ts) |v| {
            try buf.appendSlice(alloc, ",\n    \"last_chunk_ts\": ");
            try writeJsonString(buf, v);
        } else {
            try buf.appendSlice(alloc, ",\n    \"last_chunk_ts\": null");
        }
        if (ts.last_chunk_verdict) |v| {
            try buf.appendSlice(alloc, ",\n    \"last_chunk_verdict\": ");
            try writeJsonString(buf, v);
        } else {
            try buf.appendSlice(alloc, ",\n    \"last_chunk_verdict\": null");
        }
        if (ts.last_chunk_findings) |v| {
            try buf.appendSlice(alloc, ",\n    \"last_chunk_findings\": ");
            try writeJsonString(buf, v);
        } else {
            try buf.appendSlice(alloc, ",\n    \"last_chunk_findings\": null");
        }

        if (ts.acceptance) |ac| {
            try buf.appendSlice(alloc, ",\n    \"acceptance\": ");
            try writeJsonString(buf, ac);
        } else {
            try buf.appendSlice(alloc, ",\n    \"acceptance\": null");
        }

        if (ts.skip_acceptance_reason) |sr| {
            try buf.appendSlice(alloc, ",\n    \"skip_acceptance_reason\": ");
            try writeJsonString(buf, sr);
        } else {
            try buf.appendSlice(alloc, ",\n    \"skip_acceptance_reason\": null");
        }

        // T317: append-only amendment records
        try buf.appendSlice(alloc, ",\n    \"amendments\": [");
        for (ts.amendments, 0..) |am, ai| {
            if (ai > 0) try buf.appendSlice(alloc, ", ");
            try writeJsonString(buf, am);
        }
        try buf.appendSlice(alloc, "]");

        // T464: retirement epitaph (null while the row is live)
        if (ts.epitaph) |ep| {
            try buf.appendSlice(alloc, ",\n    \"epitaph\": ");
            try writeJsonString(buf, ep);
        } else {
            try buf.appendSlice(alloc, ",\n    \"epitaph\": null");
        }

        // T627: dispatch scope fields (null = UNKNOWN, never 0/none).
        if (ts.brief_bytes) |b| {
            try buf.appendSlice(alloc, ",\n    \"brief_bytes\": ");
            try buf.appendSlice(alloc, try std.fmt.allocPrint(alloc, "{d}", .{b}));
        } else {
            try buf.appendSlice(alloc, ",\n    \"brief_bytes\": null");
        }
        if (ts.files_in_scope) |f| {
            try buf.appendSlice(alloc, ",\n    \"files_in_scope\": ");
            try buf.appendSlice(alloc, try std.fmt.allocPrint(alloc, "{d}", .{f}));
        } else {
            try buf.appendSlice(alloc, ",\n    \"files_in_scope\": null");
        }
        if (ts.expected_wall_s) |e| {
            try buf.appendSlice(alloc, ",\n    \"expected_wall_s\": ");
            try buf.appendSlice(alloc, try std.fmt.allocPrint(alloc, "{d}", .{e}));
        } else {
            try buf.appendSlice(alloc, ",\n    \"expected_wall_s\": null");
        }
        if (ts.scope_enumerable) |se| {
            try buf.appendSlice(alloc, ",\n    \"scope_enumerable\": ");
            try buf.appendSlice(alloc, if (se) "true" else "false");
        } else {
            try buf.appendSlice(alloc, ",\n    \"scope_enumerable\": null");
        }
        try buf.appendSlice(alloc, ",\n    \"scope_targets\": [");
        for (ts.scope_targets, 0..) |t, ti| {
            if (ti > 0) try buf.appendSlice(alloc, ", ");
            try writeJsonString(buf, t);
        }
        try buf.appendSlice(alloc, "]");
        if (ts.scope_note) |sn| {
            try buf.appendSlice(alloc, ",\n    \"scope_note\": ");
            try writeJsonString(buf, sn);
        } else {
            try buf.appendSlice(alloc, ",\n    \"scope_note\": null");
        }

        try buf.appendSlice(alloc, "\n  }");
    }

    // _sys metadata — the leading comma must be omitted when the task map is
    // empty: `{` followed directly by `,` is invalid JSON (latent bug the
    // T399 round-trip guard caught on a bare purge leaving zero tasks).
    try buf.appendSlice(alloc, if (first) "\n  " else ",\n  ");
    try buf.appendSlice(alloc, "\"_sys\": {\n    \"next_id\": ");
    try buf.appendSlice(alloc, try std.fmt.allocPrint(alloc, "{d}", .{sys_next_id}));
    try buf.appendSlice(alloc, ",\n    \"directive_next\": ");
    try buf.appendSlice(alloc, try std.fmt.allocPrint(alloc, "{d}", .{sys_directive_next}));
    try buf.appendSlice(alloc, ",\n    \"assertion_next\": ");
    try buf.appendSlice(alloc, try std.fmt.allocPrint(alloc, "{d}", .{sys_assertion_next}));
    try buf.appendSlice(alloc, ",\n    \"closes\": ");
    try buf.appendSlice(alloc, try std.fmt.allocPrint(alloc, "{d}", .{sys_closes}));
    try buf.appendSlice(alloc, ",\n    \"duty_migrated\": ");
    try buf.appendSlice(alloc, if (sys_duty_migrated) "true" else "false");
    try buf.appendSlice(alloc, "\n  }");
    try buf.appendSlice(alloc, "\n}\n");
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

/// Unix seconds from CLOCK.REALTIME — the same clock nowTimestamp() renders.
/// The seconds-resolution gap between two rendered timestamps is this value
/// minus the parse of the earlier one (ageSecFromTs's now_unix argument).
fn nowUnix() i64 {
    var ts: std.c.timespec = undefined;
    _ = std.c.clock_gettime(std.c.CLOCK.REALTIME, &ts);
    return @intCast(ts.sec);
}

fn isLeapYear(y: u64) bool {
    if (y % 400 == 0) return true;
    if (y % 100 == 0) return false;
    return y % 4 == 0;
}

/// Seconds between an ISO timestamp (YYYY-MM-DDTHH:MM:SSZ, as written by
/// the runner's heartbeat emitter and managent's own writers) and now.
/// null when unparseable.  Shared by `resume` directive staleness and
/// `liveness` beat-age classification (T370, 2026-08-06).
fn ageSecFromTs(ts_str: []const u8, now_unix: i64) ?i64 {
    if (ts_str.len < 19) return null;
    const year = std.fmt.parseInt(i64, ts_str[0..4], 10) catch return null;
    const month = std.fmt.parseInt(i64, ts_str[5..7], 10) catch return null;
    const day = std.fmt.parseInt(i64, ts_str[8..10], 10) catch return null;
    const hour = std.fmt.parseInt(i64, ts_str[11..13], 10) catch return null;
    const minute = std.fmt.parseInt(i64, ts_str[14..16], 10) catch return null;
    const second = std.fmt.parseInt(i64, ts_str[17..19], 10) catch return null;
    var leap_count: i64 = 0;
    var y: i64 = 1970;
    while (y < year) : (y += 1) {
        const leap = (@rem(y, 4) == 0 and @rem(y, 100) != 0) or (@rem(y, 400) == 0);
        if (leap) leap_count += 1;
    }
    const month_days_lut = [_]i64{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    var day_of_year: i64 = day - 1;
    var m: usize = 0;
    while (m < @as(usize, @intCast(month - 1))) : (m += 1) {
        day_of_year += month_days_lut[m];
    }
    if (month > 2 and ((@rem(year, 4) == 0 and @rem(year, 100) != 0) or (@rem(year, 400) == 0))) {
        day_of_year += 1;
    }
    const days_since_epoch: i64 = (year - 1970) * 365 + leap_count + day_of_year;
    const ts_unix: i64 = days_since_epoch * 86400 + hour * 3600 + minute * 60 + second;
    return now_unix - ts_unix;
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
        if (ts.status == .dispatchable or ts.status == .blocked) {
            const derived = deriveStatus(state, ts.*);
            if (ts.status != derived) {
                const before = statusToString(ts.status);
                const after = statusToString(derived);
                w.diag("[migrate] {s}: stored {s} → {s} (needs-derived)\n", .{ id, before, after });
                ts.status = derived;
                changed = true;
            }
        }
        // Backfill claim_count: if task has an agent and was claimed, set to 1
        if (ts.claim_count == 0 and ts.agent != null and ts.claimed != null) {
            ts.claim_count = 1;
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

/// Derive the agent identifier: <agent>/<task-id> or <agent>/<task-id>.<attempt>
/// When agent is unset, returns "unknown/<task-id>".
/// The .<attempt> suffix is appended when claim_count > 1.
fn agentIdentifier(ts: TaskState, task_id: []const u8) ![]const u8 {
    const model = ts.agent orelse ts.model orelse "unknown";
    if (ts.claim_count <= 1) {
        return try std.fmt.allocPrint(alloc, "{s}/{s}", .{ model, task_id });
    }
    return try std.fmt.allocPrint(alloc, "{s}/{s}.{d}", .{ model, task_id, ts.claim_count });
}

/// T544: record first-hand attribution when a caller names the model.
/// Both `agent` and `model` are written (a claimed/closed row must never
/// show a null model while its agent is known — the hole the attribution
/// census measured), and any stale backfill provenance is cleared:
/// first-hand observation beats a recovered value.
fn setFirstHandAttribution(ts: *TaskState, model: []const u8) !void {
    if (ts.agent) |old| alloc.free(old);
    ts.agent = try alloc.dupe(u8, model);
    if (ts.model) |old| alloc.free(old);
    ts.model = try alloc.dupe(u8, model);
    if (ts.model_source) |old| alloc.free(old);
    ts.model_source = null;
    if (ts.model_unknown_reason) |old| alloc.free(old);
    ts.model_unknown_reason = null;
}

/// Resolve the identity of whoever is running the current process, for
/// attribution on ack reads and assertions.  Uses MANAGENT_TASK_ID (the
/// worker's own task) or PI_MODEL; falls back to "unknown".
fn resolveAckIdentity() []const u8 {
    if (std.c.getenv("MANAGENT_TASK_ID")) |ptr| {
        const tid = std.mem.sliceTo(ptr, 0);
        if (tid.len > 0) return tid;
    }
    if (std.c.getenv("PI_MODEL")) |ptr| {
        const model = std.mem.sliceTo(ptr, 0);
        if (model.len > 0) {
            // We can't allocate; return a static-ish fallback.  The
            // common case is MANAGENT_TASK_ID which is already set.
            return model; // caller must dupe if needed
        }
    }
    return "unknown";
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

// ── JSON escaping (T399) ────────────────────────────────────────────────────
// The write paths interpolate free text (--note, --skip-acceptance reasons,
// directive payloads) into JSON artifacts.  Every JSON writer must go through
// writeJsonString: an unescaped `"` or newline terminates the record early
// and corrupts the store on write — the 2026-08-06 incidents (lost directive
// in directives.jsonl; tasks.json unparseable → fleet outage).  Quotes are
// the proven-in-the-wild case, not just newlines.  Control bytes are emitted
// as \uXXXX so no byte in the artifact can break a reader's JSON parse.

fn writeJsonString(buf: *std.ArrayList(u8), s: []const u8) !void {
    try buf.append(alloc, '"');
    for (s) |c| {
        switch (c) {
            '"' => try buf.appendSlice(alloc, "\\\""),
            '\\' => try buf.appendSlice(alloc, "\\\\"),
            '\n' => try buf.appendSlice(alloc, "\\n"),
            '\r' => try buf.appendSlice(alloc, "\\r"),
            '\t' => try buf.appendSlice(alloc, "\\t"),
            else => {
                if (c < 0x20) {
                    // Control byte → \u00XX (RFC 8259 requires escaping < 0x20)
                    try buf.appendSlice(alloc, "\\u00");
                    try buf.append(alloc, hexDigit((c >> 4) & 0xF));
                    try buf.append(alloc, hexDigit(c & 0xF));
                } else {
                    try buf.append(alloc, c);
                }
            },
        }
    }
    try buf.append(alloc, '"');
}

fn hexDigit(v: u8) u8 {
    return if (v < 10) '0' + v else 'a' + v - 10;
}

/// Allocating variant of writeJsonString: returns `"escaped"` including the
/// quotes, suitable for fmt-style writers (printStatusJson, audit --json).
/// Caller frees the result.
fn jsonString(s: []const u8) ![]const u8 {
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(alloc);
    try writeJsonString(&buf, s);
    return try buf.toOwnedSlice(alloc);
}

// ── commands ────────────────────────────────────────────────────────────────

fn cmdAdd(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    const use_auto = hasFlag(args, "--auto");

    if (!use_auto and args.len < 3) {
        w.diag("usage: managent add <id> [--auto] [--bundle <path>] [--set <A-Z>] [--needs <id,...>] [--holds a,b] [--model <name>] [--note <text>] [--allow-unregistered-needs <reason>]\n", .{});
        w.diag("       managent add --auto --bundle <path>  (mint opaque T<N> ID)\n", .{});
        std.process.exit(1);
    }
    if (use_auto and args.len >= 3 and args[2].len > 0 and !std.mem.startsWith(u8, args[2], "-")) {
        // --auto with an ID: use it as the bundle slug, generate T<N>
    }

    const bundle_override = getFlagValue(args, "--bundle");
    const set_override = getFlagValue(args, "--set");
    const needs_extra = getFlagValue(args, "--needs");
    const model_flag = getFlagValue(args, "--model");
    // T539: --holds a,b is the explicit writer for rows whose bundle header
    // does not carry holds= (or has none yet).  Merged with the bundle's own
    // declaration, deduplicated — the bundle stays the author's source of
    // truth, the flag is the fallback.
    const holds_flag = getFlagValue(args, "--holds");
    // T478: --duty marks the row a duty at registration (meta `duty` key is
    // the bundle-carried alternative; either one sets the stored flag).
    const duty_flag = hasFlag(args, "--duty");
    // T760: explicit escape for a need on a task registered later in the same
    // batch — recorded as an amendment.  Without it, a need on an unregistered
    // ID is refused loudly (a silent forever-block is the T760 defect).
    const allow_unreg_reason = getFlagValue(args, "--allow-unregistered-needs");

    // T424: add --note was documented in help but ignored by the implementation
    // (note stored null) — a documented flag that silently does nothing is the
    // week's signature defect in miniature (T409 found it).  Mirror dispatch's
    // ≤4 KiB limit so add and dispatch cannot disagree on what a note is.
    const note_flag = getFlagValue(args, "--note");
    var note_for_task: ?[]const u8 = null;
    if (note_flag) |nt| {
        if (nt.len > 4096) {
            w.diag("error: --note is 4 KiB max (got {d} bytes)\n", .{nt.len});
            std.process.exit(1);
        }
        note_for_task = try alloc.dupe(u8, nt);
    }

    // T317: canonicalize and validate model label at registration time.
    // Storing a non-canonical label creates attribution debt that multiplies
    // when workers claim without --agent (the claim inherits the stored model).
    var model_for_task: ?[]const u8 = null;
    if (model_flag) |m| {
        const canonical = canonicalizeModelTag(m);
        if (!isCanonicalModel(canonical)) {
            w.diag("error: '{s}' is not a canonical model label.\n", .{m});
            printCanonicalModels(w);
            std.process.exit(1);
        }
        model_for_task = try alloc.dupe(u8, canonical);
    }

    // T317: lock → re-read → modify → writeLocked → unlock lost-update pattern.
    // The flock must be acquired before reading the store so no other console
    // can register a row between our read and write.
    try lockStore(io, state_path);
    defer unlockStore();
    var state = try readState(io, state_path);

    var id: []const u8 = undefined;
    var id_owned = false;

    if (use_auto) {
        // T770: mint from max(next_id, live-max+1, archive-max+1).  next_id
        // alone is not authoritative — a retired (archived) row keeps its id
        // forever, and re-minting it silently rebinds every citation of the
        // retired row (T765 re-minted over the archived T765, 2026-08-23).
        // sys_next_id is already ≥ live-max+1 (T204 raises it in
        // parseStateJson), so only the archive side is missing here.
        const archive_path = try archivePath(repo_root);
        defer alloc.free(archive_path);
        const mint_base = @max(sys_next_id, maxArchivedTaskId(io, archive_path) + 1);
        id = try std.fmt.allocPrint(alloc, "T{d:0>3}", .{mint_base});
        id_owned = true;

        const bundle_path = if (bundle_override) |bp|
            try alloc.dupe(u8, bp)
        else if (args.len >= 3 and !std.mem.startsWith(u8, args[2], "-"))
            try findBundle(w, io, repo_root, args[2])
        else {
            w.diag("error: --auto needs --bundle <path> or a slug as positional arg\n", .{});
            std.process.exit(1);
        };
        defer alloc.free(bundle_path);

        var meta = try parseBundleMeta(w, io, bundle_path, set_override, needs_extra);
        try mergeHoldsFlag(&meta, holds_flag);
        // T682: refuse a bundle whose brief declares no (or an unknown)
        // landmark — the T592 defect multiplied five ways by brief-cloning.
        enforceBundleLandmark(w, io, bundle_path);

        // T760: refuse a need on an unregistered ID (silent forever-block);
        // the escape records an amendment on the row.
        var amendments: [][]const u8 = &.{};
        if (try validateNeedsExist(w, &state, meta.needs, allow_unreg_reason)) |am| {
            amendments = try alloc.alloc([]const u8, 1);
            amendments[0] = am;
        }

        const tmp_for_needs = TaskState{ .needs = meta.needs };
        const initial_status: TaskStatus = if (needsMet(&state, tmp_for_needs)) .dispatchable else .blocked;

        const now = try nowTimestamp();
        // T636: honest default — a new row with no declared shape is solo.
        const shape = meta.shape orelse try alloc.dupe(u8, "solo");

        const ts = TaskState{
            .status = initial_status,
            .agent = null,
            .model = model_for_task,
            .bundle = bundle_path,
            .set = meta.set,
            .holds = meta.holds,
            .needs = meta.needs,
            .caps = meta.caps,
            .acceptance = meta.acceptance,
            .shape = shape,
            .duty = meta.duty or duty_flag,
            .due_after = meta.due_after,
            .last_chunk_closes = if (meta.duty or duty_flag) sys_closes else 0,
            .added = now,
            .claimed = null,
            .done = null,
            .note = note_for_task,
            .amendments = amendments,
        };

        try state.put(alloc, try alloc.dupe(u8, id), ts);
        sys_next_id = mint_base + 1;

        // T108 + T317: retry-on-verify (same race as non-auto path).
        // T317: lock before write to prevent lost-update races.
        const max_retries = 3;
        var attempt: u8 = 0;
        var written_ok = false;
        while (attempt < max_retries) : (attempt += 1) {
            try writeStateLocked(io, state_path, &state);
            var verify_state = try readState(io, state_path);
            defer freeState(&verify_state);
            if (verify_state.contains(id)) {
                written_ok = true;
                break;
            }
            if (attempt + 1 < max_retries) {
                const backoff_ms: u64 = @as(u64, 1) << @intCast(attempt * 3);
                const req: std.c.timespec = .{
                    .sec = @intCast(backoff_ms / 1000),
                    .nsec = @intCast((backoff_ms % 1000) * std.time.ns_per_ms),
                };
                _ = std.c.nanosleep(&req, null);
                w.diag("[T108] add {s} not found after write (attempt {d}); retrying\n", .{ id, attempt + 1 });
                try state.put(alloc, try alloc.dupe(u8, id), ts);
            }
        }
        if (!written_ok) {
            w.diag("\n  FATAL: {s} registered to memory but failed to persist to tasks.json after {d} retries\n", .{ id, max_retries });
            w.diag("  tasks.json may be corrupted or the filesystem is not accepting writes.\n", .{});
            w.diag("  Do NOT dispatch this task — it will vanish on the next read.\n", .{});
            std.process.exit(1);
        }

        const set_label = try holdsSetLabel(meta.set, meta.holds);
        defer alloc.free(set_label);

        w.diag("\n  registered {s}  [{s}]  [dispatchable]\n", .{ id, set_label });
        w.diag("  bundle: {s}\n", .{bundle_path});
        defer if (id_owned) alloc.free(id);
        return;
    }

    id = args[2];

    if (state.contains(id)) {
        w.diag("error: task '{s}' already exists\n", .{id});
        std.process.exit(1);
    }

    // T770: also refuse an id already retired to the archive — a retired id
    // is a reference forever; re-registering it silently rebinds every
    // citation of the retired row.  (add previously checked live only, so a
    // freed-by-retirement id could be registered over an archived row.)
    {
        const archive_path = try archivePath(repo_root);
        defer alloc.free(archive_path);
        if (archiveContains(io, archive_path, id)) {
            w.diag("error: task '{s}' already exists in the archive (docs/infra/managent/archive.json) — a retired id is never reused\n", .{id});
            std.process.exit(1);
        }
    }

    const bundle_path = if (bundle_override) |bp|
        try alloc.dupe(u8, bp)
    else
        try findBundle(w, io, repo_root, id);
    const owned_bundle = bundle_override == null;
    defer if (owned_bundle) alloc.free(bundle_path);

    var meta = try parseBundleMeta(w, io, bundle_path, set_override, needs_extra);
    try mergeHoldsFlag(&meta, holds_flag);
    // T682: refuse a bundle whose brief declares no (or an unknown)
    // landmark — the T592 defect multiplied five ways by brief-cloning.
    enforceBundleLandmark(w, io, bundle_path);

    // T760: refuse a need on an unregistered ID (silent forever-block);
    // the escape records an amendment on the row.
    var amendments: [][]const u8 = &.{};
    if (try validateNeedsExist(w, &state, meta.needs, allow_unreg_reason)) |am| {
        amendments = try alloc.alloc([]const u8, 1);
        amendments[0] = am;
    }

    const tmp_for_needs = TaskState{ .needs = meta.needs };
    const initial_status: TaskStatus = if (needsMet(&state, tmp_for_needs)) .dispatchable else .blocked;

    const now = try nowTimestamp();
    // T636: honest default — a new row with no declared shape is solo.
    const shape = meta.shape orelse try alloc.dupe(u8, "solo");

    const ts = TaskState{
        .status = initial_status,
        .agent = null,
        .model = model_for_task,
        .bundle = bundle_path,
        .set = meta.set,
        .holds = meta.holds,
        .needs = meta.needs,
        .caps = meta.caps,
        .acceptance = meta.acceptance,
        .shape = shape,
        .duty = meta.duty or duty_flag,
        .due_after = meta.due_after,
        .last_chunk_closes = if (meta.duty or duty_flag) sys_closes else 0,
        .added = now,
        .claimed = null,
        .done = null,
        .note = note_for_task,
        .amendments = amendments,
    };

    try state.put(alloc, try alloc.dupe(u8, id), ts);

    // T108 + T317: retry-on-verify — writeState's atomic rename can lose the
    // write under heavy IO-thread contention. Verify the task actually persisted;
    // retry with backoff up to 3 times before failing loudly.
    // T317: lock before write to prevent lost-update races.
    const max_retries = 3;
    var attempt: u8 = 0;
    var written_ok = false;
    while (attempt < max_retries) : (attempt += 1) {
        try writeStateLocked(io, state_path, &state);
        // Re-read and verify the task exists
        var verify_state = try readState(io, state_path);
        defer freeState(&verify_state);
        if (verify_state.contains(id)) {
            written_ok = true;
            break;
        }
        if (attempt + 1 < max_retries) {
            const backoff_ms: u64 = @as(u64, 1) << @intCast(attempt * 3); // 1, 8, 64 ms
            const req: std.c.timespec = .{
                .sec = @intCast(backoff_ms / 1000),
                .nsec = @intCast((backoff_ms % 1000) * std.time.ns_per_ms),
            };
            _ = std.c.nanosleep(&req, null);
            w.diag("[T108] add {s} not found after write (attempt {d}); retrying\n", .{ id, attempt + 1 });
            // Re-insert into state in case the prior put was lost (belt-and-suspenders)
            try state.put(alloc, try alloc.dupe(u8, id), ts);
        }
    }
    if (!written_ok) {
        w.diag("\n  FATAL: {s} registered to memory but failed to persist to tasks.json after {d} retries\n", .{ id, max_retries });
        w.diag("  tasks.json may be corrupted or the filesystem is not accepting writes.\n", .{});
        w.diag("  Do NOT dispatch this task — it will vanish on the next read.\n", .{});
        std.process.exit(1);
    }

    const set_label = try holdsSetLabel(meta.set, meta.holds);
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
        w.diag("       --agent defaults to model stored at suggest/dispatch time\n", .{});
        std.process.exit(1);
    }
    const id = args[2];

    const agent_name_raw = getFlagValue(args, "--agent");
    const exec_prefix = getFlagValue(args, "--exec");

    // T317: validate canonical model label at point of writing.
    var agent_name: ?[]const u8 = null;
    if (agent_name_raw) |a| {
        const canonical = canonicalizeModelTag(a);
        if (!isCanonicalModel(canonical)) {
            w.diag("error: '{s}' is not a canonical model label.\n", .{a});
            printCanonicalModels(w);
            std.process.exit(1);
        }
        agent_name = canonical;
    }

    // T317: lock → re-read → modify → writeLocked → unlock lost-update pattern.
    try lockStore(io, state_path);
    defer unlockStore();
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

            if (holdsConflict(state, effectiveHolds(w, io, repo_root, id, ts_ptr.*), id)) |holder| {
                w.diag("\n  REJECTED: holds conflict on file — {s} is in progress\n", .{holder});
                std.process.exit(1);
            }

            const now = try nowTimestamp();
            ts_ptr.status = .in_progress;
            // T209 + T544: fall back to model stored at suggest/dispatch
            // time; when --agent is named, record BOTH agent and model
            // (first-hand) so a claimed row never shows a null model.
            if (agent_name) |a| {
                try setFirstHandAttribution(ts_ptr, a);
            } else {
                ts_ptr.agent = if (ts_ptr.model) |m| try alloc.dupe(u8, m) else null;
            }
            ts_ptr.claimed = now;

            // T390: bump claim_count only on a claim that will persist —
            // refusal paths must leave the store's count alone, so a refused
            // claim never prints a phantom .<attempt> suffix (agentIdentifier
            // reads the count when naming the holder).
            ts_ptr.claim_count += 1;

            // T627: fill mechanical scope facts on claim — a row claimed
            // without a prior dispatch still carries brief_bytes/files_in_scope.
            const claim_scope = try computeScopeFacts(w, io, repo_root, id, ts_ptr.*);
            ts_ptr.brief_bytes = claim_scope.brief_bytes;
            ts_ptr.files_in_scope = claim_scope.files_in_scope;

            try writeStateLocked(io, state_path, &state);
            const ident = try agentIdentifier(ts_ptr.*, id);
            w.diag("\n  claimed {s}  [set: {c}]  [{s}]\n", .{ id, ts_ptr.set, ident });
            w.diag("  follow {s}\n", .{ts_ptr.bundle});

            // WORKER-CHANNEL: print pending directives after claim
            printPendingDirectives(w, io, repo_root, state_path, id);

            // T370: liveness + directives need the worker's tools/runner
            // invocations to carry identity.  The env var is inherited by
            // children, so nested runner calls are covered without every
            // call site remembering a flag; --task-id stays the explicit
            // per-run override.
            w.diag("  export MANAGENT_TASK_ID={s}  (so tools/runner heartbeats land under this task)\n", .{id});

            if (exec_prefix) |prefix| {
                const rel = bundleRel(ts_ptr.bundle, repo_root);
                try execHarness(prefix, rel);
            }
        },
        .in_progress => {
            // T390: name the holder as the store has it — claim_count was NOT
            // bumped for a refused claim, so no phantom .<attempt> suffix.
            w.diag("\n  ALREADY CLAIMED: {s} is already in progress", .{id});
            const ident = try agentIdentifier(ts_ptr.*, id);
            w.diag(" by {s}", .{ident});
            if (ts_ptr.claimed) |c| w.diag(" since {s}", .{c});
            w.diag("\n  A second console on one row is how T376/T389/T350 duplicated.\n", .{});
            w.diag("  If the first console is genuinely dead: managent reopen {s}, or re-dispatch with --force.\n", .{id});
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

            if (holdsConflict(state, effectiveHolds(w, io, repo_root, id, ts_ptr.*), id)) |holder| {
                w.diag("\n  REJECTED: holds conflict on file — {s} is in progress\n", .{holder});
                std.process.exit(1);
            }

            const now = try nowTimestamp();
            ts_ptr.status = .in_progress;
            // T209 + T544: fall back to model stored at suggest/dispatch
            // time; when --agent is named, record BOTH agent and model
            // (first-hand) so a claimed row never shows a null model.
            if (agent_name) |a| {
                try setFirstHandAttribution(ts_ptr, a);
            } else {
                ts_ptr.agent = if (ts_ptr.model) |m| try alloc.dupe(u8, m) else null;
            }
            ts_ptr.claimed = now;

            // T390: bump claim_count only on a claim that will persist (see
            // the .blocked branch — refusal paths never touch the count).
            ts_ptr.claim_count += 1;

            // T627: fill mechanical scope facts on claim — a row claimed
            // without a prior dispatch still carries brief_bytes/files_in_scope.
            const claim_scope = try computeScopeFacts(w, io, repo_root, id, ts_ptr.*);
            ts_ptr.brief_bytes = claim_scope.brief_bytes;
            ts_ptr.files_in_scope = claim_scope.files_in_scope;

            try writeStateLocked(io, state_path, &state);

            const ident = try agentIdentifier(ts_ptr.*, id);
            w.diag("\n  claimed {s}  [set: {c}]  [{s}]\n", .{ id, ts_ptr.set, ident });
            w.diag("  follow {s}\n", .{ts_ptr.bundle});

            // WORKER-CHANNEL: print pending directives after claim
            printPendingDirectives(w, io, repo_root, state_path, id);

            // T370: liveness + directives need the worker's tools/runner
            // invocations to carry identity.  The env var is inherited by
            // children, so nested runner calls are covered without every
            // call site remembering a flag; --task-id stays the explicit
            // per-run override.
            w.diag("  export MANAGENT_TASK_ID={s}  (so tools/runner heartbeats land under this task)\n", .{id});

            if (exec_prefix) |prefix| {
                const rel = bundleRel(ts_ptr.bundle, repo_root);
                try execHarness(prefix, rel);
            }
        },
    }
}

fn cmdDispatch(w: Writers, io: std.Io, state_path: []const u8, args: [][]const u8) !void {
    if (args.len < 3) {
        w.diag("usage: managent dispatch <id> --to <agent> [--note <text>] [--force] [--expected-wall <secs>] [--scope-targets <a,b,c> | --scope-unenumerable <reason>]\n", .{});
        std.process.exit(1);
    }
    const id = args[2];

    const to_agent = getFlagValue(args, "--to");
    const note_text = getFlagValue(args, "--note");

    if (to_agent == null) {
        w.diag("error: --to <agent> is required\n", .{});
        std.process.exit(1);
    }
    // T317 + T544: canonicalize and validate the dispatch target at point of
    // writing — a made-up label here is attribution debt; the stored value
    // must be a canonical model label (and becomes the row's `model`).
    const to_raw = to_agent.?;
    const to_canonical = canonicalizeModelTag(to_raw);
    if (!isCanonicalModel(to_canonical)) {
        w.diag("error: '{s}' is not a canonical model label.\n", .{to_raw});
        printCanonicalModels(w);
        std.process.exit(1);
    }
    if (note_text) |nt| {
        if (nt.len > 4096) {
            w.diag("error: --note is 4 KiB max (got {d} bytes)\n", .{nt.len});
            std.process.exit(1);
        }
    }

    // T627: scope fields.  expected_wall_s is the dispatcher's estimate; absent
    // is UNKNOWN (null), never 0 — 0 would masquerade as "instant".  The scope
    // enumeration is --scope-targets (enumerated) XOR --scope-unenumerable
    // (explicitly cannot be enumerated); neither → UNKNOWN.
    const expected_wall_raw = getFlagValue(args, "--expected-wall");
    var expected_wall_s: ?u32 = null;
    if (expected_wall_raw) |ew| {
        const parsed = std.fmt.parseInt(u32, ew, 10) catch {
            w.diag("error: --expected-wall must be a positive integer of seconds (got '{s}')\n", .{ew});
            std.process.exit(1);
        };
        if (parsed == 0) {
            w.diag("error: --expected-wall must be positive; absent is UNKNOWN (omit the flag), never 0\n", .{});
            std.process.exit(1);
        }
        expected_wall_s = parsed;
    }

    const scope_targets_raw = getFlagValue(args, "--scope-targets");
    const scope_unenum_raw = getFlagValue(args, "--scope-unenumerable");
    if (scope_targets_raw != null and scope_unenum_raw != null) {
        w.diag("error: --scope-targets and --scope-unenumerable are mutually exclusive\n", .{});
        std.process.exit(1);
    }
    if (scope_unenum_raw) |r| {
        if (r.len == 0) {
            w.diag("error: --scope-unenumerable needs a non-empty reason (why the target set cannot be enumerated)\n", .{});
            std.process.exit(1);
        }
    }
    var scope_targets_owned: ?[][]const u8 = null;
    if (scope_targets_raw) |t| {
        const parsed = try parseHoldsList(t);
        if (parsed.len == 0) {
            w.diag("error: --scope-targets needs at least one target; use --scope-unenumerable <reason> to say the set cannot be enumerated\n", .{});
            std.process.exit(1);
        }
        scope_targets_owned = parsed;
    }

    // T317: lock → re-read → modify → writeLocked → unlock
    try lockStore(io, state_path);
    defer unlockStore();
    var state = try readState(io, state_path);

    const ts_ptr = state.getPtr(id) orelse {
        w.diag("error: task '{s}' not found\n", .{id});
        std.process.exit(1);
    };

    // T539: a dispatch whose bundle declares holds= but whose store row is
    // empty is the vacuous-case blind spot — the one-writer invariant would
    // compare empty sets and always pass.  effectiveHolds warns loudly on
    // stderr naming the row and files; enforcement happens at claim/next.
    const repo_root = try findRepoRoot(w, io);
    _ = effectiveHolds(w, io, repo_root, id, ts_ptr.*);

    if (ts_ptr.status == .done) {
        w.diag("warning: {s} is already done; recording the dispatch anyway\n", .{id});
    }
    if (ts_ptr.status == .in_progress) {
        w.diag("warning: {s} is already in progress (by {s}); recording the dispatch anyway\n", .{ id, ts_ptr.agent orelse "unknown" });
    }

    // ── T390: refuse a second dispatch on the same row ──
    // The kanban proves duplicates are real: T376, T389, T350 each got a
    // second console on one row, and in every case the OPERATOR noticed, not
    // an instrument.  A second dispatch overwrites dispatched_to and hides
    // the first holder.  Name holder + timestamp; --force re-dispatches a
    // genuinely dead console (the T379 shape) loudly.
    const force_dispatch = hasFlag(args, "--force");
    if (ts_ptr.dispatched != null and !force_dispatch) {
        w.diag("\n  REJECTED: {s} was already dispatched", .{id});
        if (ts_ptr.dispatched_to) |to| w.diag(" to {s}", .{to});
        if (ts_ptr.dispatched) |d| w.diag(" at {s}", .{d});
        w.diag("\n  A second console on one row is how T376/T389/T350 duplicated.\n", .{});
        w.diag("  If the first console is genuinely dead: managent dispatch {s} --to {s} --force\n", .{ id, to_agent.? });
        std.process.exit(1);
    }
    if (ts_ptr.dispatched != null and force_dispatch) {
        w.diag("\n  FORCED: {s} was already dispatched", .{id});
        if (ts_ptr.dispatched_to) |to| w.diag(" to {s}", .{to});
        if (ts_ptr.dispatched) |d| w.diag(" at {s}", .{d});
        w.diag(" — re-dispatching anyway (previous console presumed dead)\n", .{});
    }

    const now = try nowTimestamp();

    if (ts_ptr.dispatched) |d| alloc.free(d);
    if (ts_ptr.dispatched_to) |d| alloc.free(d);
    if (ts_ptr.note) |n| alloc.free(n);
    ts_ptr.dispatched = try alloc.dupe(u8, now);
    ts_ptr.dispatched_to = try alloc.dupe(u8, to_canonical);
    // T544: dispatch names the model — record it first-hand so the write
    // path no longer leaves `model` null (and corrects a bulk re-lane's
    // wrong value).  `agent` (who actually claims) is untouched here.
    if (ts_ptr.model) |old| alloc.free(old);
    ts_ptr.model = try alloc.dupe(u8, to_canonical);
    if (ts_ptr.model_source) |old| alloc.free(old);
    ts_ptr.model_source = null;
    if (ts_ptr.model_unknown_reason) |old| alloc.free(old);
    ts_ptr.model_unknown_reason = null;
    if (note_text) |nt| {
        ts_ptr.note = try alloc.dupe(u8, nt);
    } else {
        ts_ptr.note = null;
    }

    // T627: write the scope fields at dispatch time (the tool's job, never the
    // worker's).  brief_bytes/files_in_scope are mechanical; expected_wall_s and
    // the scope enumeration come from this dispatch's flags.
    const scope_facts = try computeScopeFacts(w, io, repo_root, id, ts_ptr.*);
    ts_ptr.brief_bytes = scope_facts.brief_bytes;
    ts_ptr.files_in_scope = scope_facts.files_in_scope;
    ts_ptr.expected_wall_s = expected_wall_s;
    try setScopeEnumeration(ts_ptr, scope_targets_owned, scope_unenum_raw);

    try writeStateLocked(io, state_path, &state);

    w.diag("\n  dispatched {s}  to {s}  [set: {c}]\n", .{ id, to_canonical, ts_ptr.set });
    if (ts_ptr.status == .dispatchable) {
        w.diag("  awaiting claim by {s} (or another agent): managent claim {s}\n", .{ to_canonical, id });
    }
    if (note_text != null) {
        w.diag("  note recorded ({d} bytes)\n", .{note_text.?.len});
    }
}

// ── suggest — mint a T-ID, create bundle, output prompt (ORCHA-TOOLS R1) ───

fn cmdSuggest(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    if (args.len < 3) {
        w.diag("usage: managent suggest <slug> [--model <name>] [--set <A-Z>]\n", .{});
        w.diag("       prints a one-line dispatch: 'Follow untracked/T<ID>-<slug>.md'\n", .{});
        w.diag("       --model is stored on the task; claim picks it up automatically\n", .{});
        std.process.exit(1);
    }
    const slug = args[2];

    // Model: --model flag, or PI_MODEL env var, or "unknown"
    const model_flag = getFlagValue(args, "--model");
    var model_owned = false;
    const model: []const u8 = if (model_flag) |m| blk: {
        model_owned = true;
        break :blk try alloc.dupe(u8, m);
    } else if (std.c.getenv("PI_MODEL")) |ptr|
        std.mem.sliceTo(ptr, 0)
    else blk2: {
        model_owned = true;
        break :blk2 try alloc.dupe(u8, "unknown");
    };
    defer if (model_owned) alloc.free(model);

    const set_override = getFlagValue(args, "--set");

    // Read current state to get sys_next_id — T337: lock → re-read → modify → writeStateLocked → unlock
    try lockStore(io, state_path);
    defer unlockStore();
    var state = try readState(io, state_path);

    // Mint the ID — T770: consult the archive too (sys_next_id is already
    // ≥ live-max+1 via T204 in parseStateJson; the archive side is missing).
    // A retired id is a reference forever; re-minting it silently rebinds
    // every citation of the retired row.
    const archive_path = try archivePath(repo_root);
    defer alloc.free(archive_path);
    const mint_base = @max(sys_next_id, maxArchivedTaskId(io, archive_path) + 1);
    const id = try std.fmt.allocPrint(alloc, "T{d:0>3}", .{mint_base});
    defer alloc.free(id);

    // Create the bundle file
    const bundle_name = try std.fmt.allocPrint(alloc, "{s}-{s}.md", .{ id, slug });
    defer alloc.free(bundle_name);
    const bundle_path = try std.fs.path.join(alloc, &.{ repo_root, "untracked", bundle_name });
    defer alloc.free(bundle_path);

    // Ensure untracked/ exists
    const untracked_dir = try std.fs.path.join(alloc, &.{ repo_root, "untracked" });
    defer alloc.free(untracked_dir);
    std.Io.Dir.cwd().createDirPath(io, untracked_dir) catch {};

    // Determine set: --set flag, else default A
    const set: u8 = if (set_override) |s| blk2: {
        if (s.len != 1 or s[0] < 'A' or s[0] > 'Z') {
            w.diag("error: invalid --set '{s}' (must be A–Z)\n", .{s});
            std.process.exit(1);
        }
        break :blk2 s[0];
    } else 'A';

    // Write the bundle template
    {
        const file = try std.Io.Dir.cwd().createFile(io, bundle_path, .{});
        defer file.close(io);
        const meta = try std.fmt.allocPrint(alloc, "<!--managent set={c} deliverables= holds=-->\n", .{set});
        defer alloc.free(meta);
        try file.writeStreamingAll(io, meta);
        const heading = try std.fmt.allocPrint(alloc, "# {s} — {s}\n", .{ id, slug });
        defer alloc.free(heading);
        try file.writeStreamingAll(io, heading);
        // T682: the skeleton declares the sanctioned no-landmark form so the
        // registration gate below passes; the seat fills in the real
        // landmark when writing the brief.  A suggest-created bundle must
        // be add-able — the gate would otherwise refuse its own creation.
        try file.writeStreamingAll(io, "\n**Landmark:** none directly; unblocks <row>\n");
    }

    // T682: the same gate that guards `add` guards the bundle suggest just
    // wrote — if the template ever regresses, suggest refuses loudly
    // instead of registering a row `add` would refuse.
    enforceBundleLandmark(w, io, bundle_path);

    // Register the task in state
    const now = try nowTimestamp();
    const rel_bundle = try std.fmt.allocPrint(alloc, "untracked/{s}", .{bundle_name});
    defer alloc.free(rel_bundle);

    // Store model on task: the model is bound at dispatch/suggest time, not claim time.
    const model_for_task: ?[]const u8 = if (model_flag) |m| try alloc.dupe(u8, m) else if (std.c.getenv("PI_MODEL")) |ptr| try alloc.dupe(u8, std.mem.sliceTo(ptr, 0)) else null;

    const ts = TaskState{
        .status = .dispatchable,
        .agent = null,
        .model = model_for_task,
        .bundle = rel_bundle,
        .set = set,
        .holds = &.{},
        .needs = &.{},
        .caps = &.{},
        .shape = try alloc.dupe(u8, "solo"),
        .added = now,
        .claimed = null,
        .done = null,
    };
    try state.put(alloc, try alloc.dupe(u8, id), ts);
    sys_next_id = mint_base + 1;
    try writeStateLocked(io, state_path, &state);

    w.diag("\n  suggested {s}  [set: {c}]  [dispatchable]\n", .{ id, set });
    w.diag("  bundle: untracked/{s}\n", .{bundle_name});

    // ── stdout: the prompt one-liner (AGENTS.md copy/paste boundaries) ──
    // T209: dispatch line is just the bundle path — the bundle carries everything.
    w.data("Follow untracked/{s}\n", .{bundle_name});
}

// ── parseDeliverablesFromBundle — extract deliverable paths from bundle body ─

fn parseDeliverablesFromBundle(w: Writers, io: std.Io, bundle_abs: []const u8, holds: []const []const u8) ![]const []const u8 {
    _ = w;
    var result = std.ArrayList([]const u8).empty;
    errdefer {
        for (result.items) |d| alloc.free(d);
        result.deinit(alloc);
    }

    const content = std.Io.Dir.cwd().readFileAlloc(io, bundle_abs, alloc, .unlimited) catch {
        // Can't read bundle — fall back to holds
        for (holds) |h| {
            try result.append(alloc, try alloc.dupe(u8, h));
        }
        return try result.toOwnedSlice(alloc);
    };
    defer alloc.free(content);

    // T209: first, try the machine-readable meta header
    // <!--managent set=X deliverables=path1,path2-->
    const meta_start = "<!--managent ";
    const dl_key = "deliverables=";
    if (std.mem.startsWith(u8, content, meta_start)) {
        // Find end of the comment line
        const newline_idx = std.mem.indexOfScalar(u8, content, '\n') orelse content.len;
        const meta_line = content[0..newline_idx];
        if (std.mem.indexOf(u8, meta_line, dl_key)) |dl_start| {
            const val_start = dl_start + dl_key.len;
            // T880: the value is a space/comma-separated list running until
            // the next `key=` token, the `-->` terminator, or end of line.
            // The old code stopped at the first whitespace only when a
            // following token contained '=', so `deliverables=a.zig b.zig`
            // became ONE element "a.zig b.zig" — a path that can never exist
            // — and a stray placeholder (`deliverables= holds=`) leaked as a
            // deliverable path.
            var rest = meta_line[val_start..];
            if (std.mem.indexOf(u8, rest, "-->")) |t| rest = rest[0..t];
            var got_any = false;
            var toks = std.mem.tokenizeAny(u8, rest, " \t\r");
            while (toks.next()) |tok| {
                // A following key (e.g. `acceptance=`) ends the list.
                if (std.mem.indexOfScalar(u8, tok, '=')) |eq| {
                    if (isKnownMetaKey(tok[0..eq])) break;
                }
                var parts = std.mem.splitScalar(u8, tok, ',');
                while (parts.next()) |part| {
                    const trimmed = std.mem.trim(u8, part, " \t\r\n");
                    if (trimmed.len > 0) {
                        try result.append(alloc, try alloc.dupe(u8, trimmed));
                        got_any = true;
                    }
                }
            }
            if (got_any) {
                return try result.toOwnedSlice(alloc);
            }
        }
    }

    // Fall back: parse "Deliverables:" paragraph
    const marker = "Deliverables:";
    const marker_idx = std.mem.indexOf(u8, content, marker);

    if (marker_idx == null) {
        // No explicit deliverables section — use holds
        for (holds) |h| {
            try result.append(alloc, try alloc.dupe(u8, h));
        }
        return try result.toOwnedSlice(alloc);
    }

    // Extract text from after "Deliverables:" to end of paragraph (blank line)
    const after = std.mem.trimStart(u8, content[marker_idx.? + marker.len ..], " \t\r\n");
    var para_end: usize = after.len;
    {
        var lines = std.mem.splitScalar(u8, after, '\n');
        var consumed: usize = 0;
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            consumed += line.len + 1; // +1 for the newline
            if (trimmed.len == 0) {
                para_end = consumed - 1; // exclude the blank line
                break;
            }
        }
        if (para_end > after.len) para_end = after.len;
    }
    const para = after[0..para_end];

    // Split on commas to get individual path entries
    var parts = std.mem.splitScalar(u8, para, ',');
    while (parts.next()) |part| {
        var trimmed = std.mem.trim(u8, part, " \t\r\n");
        if (trimmed.len == 0) continue;

        // Take the first whitespace-delimited token as the path
        // (strips parenthetical annotations like "(revised in place)")
        const first_token = if (std.mem.indexOfScalar(u8, trimmed, ' ')) |space_idx|
            trimmed[0..space_idx]
        else
            trimmed;

        // Remove trailing period
        var token = first_token;
        if (token.len > 1 and token[token.len - 1] == '.') {
            token = token[0 .. token.len - 1];
        }
        token = std.mem.trim(u8, token, " \t");

        if (token.len > 0) {
            try result.append(alloc, try alloc.dupe(u8, token));
        }
    }

    // If no paths found from body, fall back to holds
    if (result.items.len == 0) {
        for (holds) |h| {
            try result.append(alloc, try alloc.dupe(u8, h));
        }
    }

    return try result.toOwnedSlice(alloc);
}

// ── T278: the deliverable check asks git, not the filesystem ────────────────
// T272 closed pass with its deliverables untracked or uncommitted; the statFile
// check saw the files and passed. A deliverable that is not in git is not a
// deliverable (AGENTS.md). These helpers implement the git-side verdict.

/// Run git; true iff it exited 0. Spawn failure also returns false — every
/// caller treats false as "not in git", which refuses rather than silently
/// passing (the safe direction under a shared index).
fn gitOk(io: std.Io, argv: []const []const u8) bool {
    const result = std.process.run(alloc, io, .{ .argv = argv }) catch return false;
    alloc.free(result.stdout);
    alloc.free(result.stderr);
    return switch (result.term) {
        .exited => |code| code == 0,
        else => false,
    };
}

/// Was `d` deleted by some commit in history? The deliverable "the removal of
/// d" is then in git even though the path is absent from HEAD.
fn gitHistoryDeletion(io: std.Io, repo_root: []const u8, d: []const u8) bool {
    const out = runCommand(alloc, io, &.{ "git", "-C", repo_root, "log", "--diff-filter=D", "-1", "--format=%h", "--", d }) catch return false;
    defer alloc.free(out);
    return std.mem.trim(u8, out, " \t\r\n").len > 0;
}

/// ARGUS T211 retention rule: a deliberately-untracked solver artifact under
/// untracked/ whose SHA-256 is pinned in artifacts/SHA256SUMS is a legitimate
/// deliverable that will never be in git.
fn isPinnedRetentionArtifact(io: std.Io, repo_root: []const u8, d: []const u8) bool {
    if (!std.mem.startsWith(u8, d, "untracked/")) return false;
    const sums_path = std.fs.path.join(alloc, &.{ repo_root, "artifacts", "SHA256SUMS" }) catch return false;
    defer alloc.free(sums_path);
    const content = std.Io.Dir.cwd().readFileAlloc(io, sums_path, alloc, .unlimited) catch return false;
    defer alloc.free(content);
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;
        // "<64 hex>  <path>": the path is the last field, space- or *-separated.
        if (trimmed.len > d.len and std.mem.endsWith(u8, trimmed, d)) {
            const sep = trimmed[trimmed.len - d.len - 1];
            if (sep == ' ' or sep == '*') return true;
        }
    }
    return false;
}

const DeliverableVerdict = struct {
    ok: bool,
    reason: []const u8,
};

/// Is deliverable `d` cleanly in git at close time? Pass: (a) tracked and free
/// of uncommitted modifications; (b) a SHA256SUMS-pinned retention artifact
/// under untracked/; (c) deleted in git history — the deliverable is the
/// removal, and it is committed. Refuse with a reason for everything else.
fn deliverableVerdict(io: std.Io, repo_root: []const u8, d: []const u8) DeliverableVerdict {
    const in_index = gitOk(io, &.{ "git", "-C", repo_root, "ls-files", "--error-unmatch", "--", d });
    const staged_deletion = !gitOk(io, &.{ "git", "-C", repo_root, "diff", "--cached", "--quiet", "--diff-filter=D", "--", d });

    const d_abs = if (std.fs.path.isAbsolute(d))
        (alloc.dupe(u8, d) catch return .{ .ok = false, .reason = "missing" })
    else
        (std.fs.path.join(alloc, &.{ repo_root, d }) catch return .{ .ok = false, .reason = "missing" });
    defer alloc.free(d_abs);
    const exists = blk: {
        if (std.Io.Dir.cwd().statFile(io, d_abs, .{})) |_| break :blk true else |_| break :blk false;
    };

    if (exists) {
        if (in_index) {
            const clean_worktree = gitOk(io, &.{ "git", "-C", repo_root, "diff", "--quiet", "--", d });
            const clean_index = gitOk(io, &.{ "git", "-C", repo_root, "diff", "--cached", "--quiet", "--", d });
            if (clean_worktree and clean_index) {
                return .{ .ok = true, .reason = "tracked and clean" };
            }
            return .{ .ok = false, .reason = "has uncommitted modifications — commit the changes" };
        }
        if (isPinnedRetentionArtifact(io, repo_root, d)) {
            return .{ .ok = true, .reason = "SHA256SUMS-pinned retention artifact under untracked/ (ARGUS T211)" };
        }
        return .{ .ok = false, .reason = "untracked — commit it" };
    }

    // The path is not on disk: a deletion or a never-created file.
    if (staged_deletion) {
        return .{ .ok = false, .reason = "deletion staged but not committed — commit the deletion" };
    }
    if (in_index) {
        return .{ .ok = false, .reason = "missing — deleted on disk but the deletion is not committed" };
    }
    if (gitHistoryDeletion(io, repo_root, d)) {
        return .{ .ok = true, .reason = "deleted in git history — the deliverable is the removal" };
    }
    return .{ .ok = false, .reason = "missing" };
}

/// T485: the absorption done-gate (absorption-spec §4, §13 task 3). Runs
/// claimlint `c7 --json` (the machine-readable C7 report, one object per
/// findings file) and takes the C7 verdict scoped to the closing task's
/// files — the close is refused while any of ITS files is non-conforming or
/// carries an unabsorbed proposal. The count is claimlint's own: this
/// function consumes the JSON, it does not reimplement the comparison
/// (the T294 rule made mechanical). Exit 3 (register unreadable) refuses
/// the close as an infrastructure fault, the same posture as the pre-commit
/// hook's hard requirement on a runnable claimlint.
fn refuseIfUnabsorbed(w: Writers, io: std.Io, repo_root: []const u8, id: []const u8) void {
    const result = std.process.run(alloc, io, .{
        .argv = &.{ "bin/weizigo-claimlint", "c7", "--json" },
        .cwd = .{ .path = repo_root },
    }) catch {
        w.diag("\n  REJECTED: {s} — cannot run bin/weizigo-claimlint (build it: zig build); the absorption gate is blind without it.\n", .{id});
        std.process.exit(1);
    };
    defer alloc.free(result.stdout);
    defer alloc.free(result.stderr);

    const code: u8 = switch (result.term) {
        .exited => |c| c,
        else => 255,
    };
    if (code == 3) {
        w.diag("\n  REJECTED: {s} — claimlint cannot read the register (exit 3); infrastructure fault.\n", .{id});
        if (result.stderr.len > 0) w.diag("  claimlint: {s}\n", .{std.mem.trim(u8, result.stderr, " \t\r\n")});
        std.process.exit(1);
    }
    if (code != 0 and code != 1) {
        w.diag("\n  REJECTED: {s} — claimlint exited unexpectedly (code {d}); infrastructure fault.\n", .{ id, code });
        if (result.stderr.len > 0) w.diag("  claimlint: {s}\n", .{std.mem.trim(u8, result.stderr, " \t\r\n")});
        std.process.exit(1);
    }
    // Exit 0: nothing non-conforming and nothing unabsorbed ANYWHERE, so the
    // closing task's files are conforming and absorbed by construction.
    if (code == 0) return;

    // Exit 1: claimlint found a non-conforming or unabsorbed file somewhere.
    // Scope to THIS task: only files whose task_id matches the closing id
    // refuse this close. Other tasks' drift is their own close's problem
    // (spec §9: the gate is scoped, never global).
    var parsed = std.json.parseFromSlice(std.json.Value, alloc, result.stdout, .{ .allocate = .alloc_always }) catch {
        w.diag("\n  REJECTED: {s} — claimlint c7 --json emitted unparseable output (infrastructure fault).\n", .{id});
        std.process.exit(1);
    };
    defer parsed.deinit();
    if (parsed.value != .array) {
        w.diag("\n  REJECTED: {s} — claimlint c7 --json did not emit an array (infrastructure fault).\n", .{id});
        std.process.exit(1);
    }

    var nonconforming = false;
    var unabsorbed = false;

    // Non-conforming first — a file that cannot speak must fail louder than
    // a file that says something wrong (spec §6.1, the T454 illusion).
    for (parsed.value.array.items) |pf| {
        if (pf != .object) continue;
        const tid = runRecOptStr(pf.object, "task_id") orelse continue;
        if (!std.mem.eql(u8, tid, id)) continue;
        const conforming = if (pf.object.get("conforming")) |v| v == .bool and v.bool else false;
        if (conforming) continue;
        nonconforming = true;
        const path = runRecStr(pf.object, "path");
        const reason = runRecStr(pf.object, "conforming_reason");
        w.diag("  NON-CONFORMING  {s} — {s}\n", .{ path, if (reason.len > 0) reason else "(no reason reported)" });
    }

    // Then unabsorbed proposals — each named: claim id, proposed, actual.
    for (parsed.value.array.items) |pf| {
        if (pf != .object) continue;
        const tid = runRecOptStr(pf.object, "task_id") orelse continue;
        if (!std.mem.eql(u8, tid, id)) continue;
        if (pf.object.get("unabsorbed")) |ua| {
            if (ua != .array) continue;
            for (ua.array.items) |u| {
                if (u != .object) continue;
                unabsorbed = true;
                const cid = runRecStr(u.object, "id");
                const proposed = runRecStr(u.object, "proposed");
                const actual = runRecStr(u.object, "actual");
                w.diag("  C7 UNABSORBED  `{s}` — findings says `{s}`, register says `{s}`\n", .{ cid, proposed, actual });
            }
        }
    }

    if (nonconforming or unabsorbed) {
        w.diag("\n  REJECTED: {s} — findings are non-conforming or unabsorbed (absorption gate, T485).\n", .{id});
        w.diag("  Repair path: run `bin/weizigo-claimlint absorb <file>`, apply or disposition, commit, `done` again.\n", .{});
        std.process.exit(1);
    }
}

fn cmdDone(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    // ── T390: claim-at-close gate ──
    // The kanban's claim timestamps prove consoles do the work FIRST and
    // record claim and done together at the end (T388 01:22:10/01:22:10,
    // T380 21:34:36/21:34:36, T376 13:28:50/13:28:51 — and 9 of 54 closed
    // rows land within this window).  A claim recorded within this many
    // seconds of close means the row ran with NO claim held while the work
    // happened — holdsConflict, holds= and the parallel sets were all
    // blind.  cmdDone refuses; --force closes with a loud acknowledgement.
    const CLAIM_TO_DONE_REFUSE_SECS: i64 = 10;
    if (args.len < 3) {
        w.diag("usage: managent done <id> [--status pass|pass-with-findings|fail-found|blocked|abandoned] [--note <text>] [--agent <name> | --model <name> | --model-unknown <reason>] [--impression <text> | --impression-waiver <reason>] [--skip-acceptance <reason>] [--force]\n", .{});
        w.diag("       --fail (backward compat, sets verdict=blocked)\n", .{});
        w.diag("       --status defaults to 'pass'; --note required for non-pass verdicts\n", .{});
        w.diag("       --skip-acceptance bypasses the acceptance= command (reason mandatory)\n", .{});
        std.process.exit(1);
    }
    const id = args[2];
    const is_fail = hasFlag(args, "--fail");
    const status_override = getFlagValue(args, "--status");
    const note_override = getFlagValue(args, "--note");
    const agent_override_raw = getFlagValue(args, "--agent");
    const model_override_raw = getFlagValue(args, "--model");
    const model_unknown_reason = getFlagValue(args, "--model-unknown");
    const skip_acceptance_reason = getFlagValue(args, "--skip-acceptance");
    const impression_override = getFlagValue(args, "--impression");
    const impression_waiver_override = getFlagValue(args, "--impression-waiver");

    // T317: validate canonical model label at point of writing.
    var agent_override: ?[]const u8 = null;
    if (agent_override_raw) |a| {
        const canonical = canonicalizeModelTag(a);
        if (!isCanonicalModel(canonical)) {
            w.diag("error: '{s}' is not a canonical model label.\n", .{a});
            printCanonicalModels(w);
            std.process.exit(1);
        }
        agent_override = canonical;
    }
    // T544: --model is the same attribution by another name; canonical and
    // validated the same way (one worker, one model label).
    var model_override: ?[]const u8 = null;
    if (model_override_raw) |m| {
        const canonical = canonicalizeModelTag(m);
        if (!isCanonicalModel(canonical)) {
            w.diag("error: '{s}' is not a canonical model label.\n", .{m});
            printCanonicalModels(w);
            std.process.exit(1);
        }
        model_override = canonical;
    }

    // T213: resolve verdict — --status flag, or --fail backward compat, or default "pass"
    const verdict_str: []const u8 = if (status_override) |s|
        s
    else if (is_fail)
        "blocked"
    else
        "pass";

    // Validate verdict
    if (!isValidVerdict(verdict_str)) {
        w.diag("error: invalid verdict '{s}'. Valid: ", .{verdict_str});
        for (valid_verdicts, 0..) |v, vi| {
            if (vi > 0) w.diag(", ", .{});
            w.diag("{s}", .{v});
        }
        w.diag("\n", .{});
        std.process.exit(1);
    }

    // Non-pass verdicts require a note; --fail auto-generates one for backward compat
    var verdict_note_str: ?[]const u8 = if (note_override) |n| n else null;
    if (is_fail and verdict_note_str == null) {
        verdict_note_str = "--fail (no note provided)";
    }
    if (!std.mem.eql(u8, verdict_str, "pass") and verdict_note_str == null) {
        w.diag("\n  REJECTED: verdict '{s}' requires --note <text>\n", .{verdict_str});
        w.diag("  A verdict with no reason is the same information vacuum as bare 'done'.\n", .{});
        std.process.exit(1);
    }

    // ── T522: impression-or-waiver gate ──
    // Every close must record a model impression or an explicit waiver.
    // model-perf lapsed under three orchestrators because nothing at close
    // demanded it (fleet-and-model-audit §3); the waiver is the recorded
    // N/A case, never a silent omission.  Exactly one non-empty field closes
    // the row; both-empty and both-present are refused.  There is no --force
    // bypass — an escape valve here is the lapse reborn (the absorption
    // gate's lesson).  The gate is flag-only, so it runs before the lock.
    const has_impression = impression_override != null and impression_override.?.len > 0;
    const has_waiver = impression_waiver_override != null and impression_waiver_override.?.len > 0;
    if (has_impression and has_waiver) {
        w.diag("\n  REJECTED: {s} — give an impression OR a waiver, not both.\n", .{id});
        w.diag("  --impression <text>        how the model performed on this task type (model-perf datum)\n", .{});
        w.diag("  --impression-waiver <r>    the explicit reason no impression is owed (the recorded N/A)\n", .{});
        std.process.exit(1);
    }
    if (!has_impression and !has_waiver) {
        w.diag("\n  REJECTED: {s} — a close needs a model impression or an explicit waiver.\n", .{id});
        w.diag("  model-perf lapses whenever close does not ask; the row cannot close silent.\n", .{});
        w.diag("  --impression <text>        e.g. --impression \"clean spec pass, every citation verified\"\n", .{});
        w.diag("  --impression-waiver <r>    e.g. --impression-waiver \"no model ran — operator close\"\n", .{});
        std.process.exit(1);
    }

    // T350: two-phase lock.  Phase 1 (below) holds the exclusive flock for the
    // whole read→validate→modify→write sequence, closing the lost-update window
    // that previously spanned the acceptance run (T337 S6 deferred cmdDone for
    // exactly that reason).  Phase 2 runs the acceptance command with NO lock —
    // holding the flock for its runtime (up to 60s) would block every other
    // store operation — and on failure re-acquires the flock to revert the
    // done write.  There is deliberately no `defer unlockStore` here: phase 2
    // must run unlocked, so the lock is released explicitly after the phase-1
    // write.  Exit paths inside phase 1 call unlockStore() before exit, and
    // rely on flock(2)'s kernel release at process exit as the backstop (the
    // T337 S0 contract, exercised by regression-managent-lock.sh).
    try lockStore(io, state_path);
    var state = try readState(io, state_path);

    const ts_ptr = state.getPtr(id) orelse {
        unlockStore();
        w.diag("error: task '{s}' not found\n", .{id});
        std.process.exit(1);
    };

    if (ts_ptr.status != .in_progress) {
        unlockStore();
        w.diag("error: task '{s}' is not in progress (status: {s})\n", .{ id, statusToString(ts_ptr.status) });
        std.process.exit(1);
    }

    // ── T390: claim-at-close gate (before any store mutation) ──
    // A claim recorded within CLAIM_TO_DONE_REFUSE_SECS of this done is the
    // claim-at-close pattern — proof the row ran unprotected.  Refuse and
    // point at the correct flow; --force asserts the close is genuine.
    // T424: a forced close must leave a record — the T390 gate's escape was
    // silent (3 of 34 rows closed inside the window after the gate landed;
    // the store could not say which used --force).  The FORCED amendment is
    // appended at the phase-1 write, so it persists only when the close does.
    const force_done = hasFlag(args, "--force");
    var forced_close_gap: ?i64 = null;
    if (ts_ptr.claimed) |claimed_ts| {
        const gap = ageSecFromTs(claimed_ts, nowUnix());
        if (gap) |g| {
            if (g <= CLAIM_TO_DONE_REFUSE_SECS and !force_done) {
                unlockStore();
                w.diag("\n  REJECTED: {s} was claimed {d}s before this done (claimed {s})\n", .{ id, g, claimed_ts });
                w.diag("  A claim and done this close means the work ran with no claim held — no concurrency safeguard could see the row.\n", .{});
                w.diag("  Claim at the START of the work (managent claim {s}), not at close.\n", .{id});
                w.diag("  If this close is genuine, re-run with --force.\n", .{});
                std.process.exit(1);
            }
            if (g <= CLAIM_TO_DONE_REFUSE_SECS and force_done) {
                forced_close_gap = g;
                w.diag("\n  FORCED: {s} was claimed only {d}s before done (claimed {s}) — closing anyway, claim-at-close acknowledged\n", .{ id, g, claimed_ts });
            }
        }
    }

    // ── attribution enforcement (ORCHA-AUTOMATION item 3 + T544) ──
    // T544: `model` is the ledger's attribution field.  A close names it via
    // --agent/--model (first-hand, canonical) or declares it unknown via
    // --model-unknown <reason>.  A silent null is refused — the 79%-null
    // census must not grow.  --agent and --model are one attribution: given
    // both, they must agree; given one, both fields are written so the
    // agent/model split can never reopen.
    if (agent_override != null and model_override != null and !std.mem.eql(u8, agent_override.?, model_override.?)) {
        unlockStore();
        w.diag("\n  REJECTED: {s} — --agent and --model name different models ({s} vs {s}).\n", .{ id, agent_override.?, model_override.? });
        w.diag("  One worker, one attribution. Drop one of the flags.\n", .{});
        std.process.exit(1);
    }
    if (model_unknown_reason != null and (agent_override != null or model_override != null)) {
        unlockStore();
        w.diag("\n  REJECTED: {s} — --model-unknown cannot be combined with --agent/--model.\n", .{id});
        std.process.exit(1);
    }
    if (model_unknown_reason) |reason| {
        if (reason.len == 0) {
            unlockStore();
            w.diag("\n  REJECTED: {s} — --model-unknown requires a non-empty reason.\n", .{id});
            std.process.exit(1);
        }
        // Explicitly unattributed, never a silent null: the marker is
        // first-class so aggregations exclude it by name.
        if (ts_ptr.model) |old| alloc.free(old);
        ts_ptr.model = try alloc.dupe(u8, "unattributed");
        if (ts_ptr.model_source) |old| alloc.free(old);
        ts_ptr.model_source = null;
        if (ts_ptr.model_unknown_reason) |old| alloc.free(old);
        ts_ptr.model_unknown_reason = try alloc.dupe(u8, reason);
    } else if (agent_override != null or model_override != null) {
        try setFirstHandAttribution(ts_ptr, (agent_override orelse model_override).?);
    } else if (ts_ptr.model == null and ts_ptr.agent != null) {
        // An in-flight row claimed before T544 has an agent but no model:
        // promote the known agent to model so the close is attributed.
        ts_ptr.model = try alloc.dupe(u8, ts_ptr.agent.?);
    }

    if (ts_ptr.model == null) {
        unlockStore();
        w.diag("\n  REJECTED: {s} has no agent or model set.\n", .{id});
        w.diag("  Every completed task must carry a model for the attribution ledger.\n", .{});
        w.diag("  Use: managent done {s} --agent <model>   (or --model <model>)\n", .{id});
        w.diag("  Or, if the model is genuinely unknown: --model-unknown <reason>\n", .{});
        w.diag("  Or set it first: managent agent {s} <model>\n", .{id});
        std.process.exit(1);
    }

    // ── deliverable verification (ORCHA-TOOLS R2) ──
    // T213: deliverable check for all non-blocked/abandoned verdicts
    if (!std.mem.eql(u8, verdict_str, "blocked") and !std.mem.eql(u8, verdict_str, "abandoned")) {
        const bundle_abs = if (std.fs.path.isAbsolute(ts_ptr.bundle))
            try alloc.dupe(u8, ts_ptr.bundle)
        else
            try std.fs.path.join(alloc, &.{ repo_root, ts_ptr.bundle });
        defer alloc.free(bundle_abs);
        const deliverables = try parseDeliverablesFromBundle(w, io, bundle_abs, ts_ptr.holds);
        defer {
            for (deliverables) |d| alloc.free(d);
            alloc.free(deliverables);
        }
        // T278: the deliverable check asks git, not the filesystem. T272 closed
        // pass with its deliverables untracked or uncommitted; statFile saw the
        // files and passed. A deliverable that is not committed is not a
        // deliverable. The two ruled exceptions: deliberately-untracked
        // retention artifacts (untracked/ + SHA256SUMS-pinned, ARGUS T211) and
        // deletion deliverables (the removal committed to history).
        if (!gitOk(io, &.{ "git", "-C", repo_root, "rev-parse", "--git-dir" })) {
            unlockStore();
            w.diag("\n  REJECTED: {s} — cannot ask git (not a git repo, or git unavailable)\n", .{id});
            std.process.exit(1);
        }
        var violated = std.ArrayList([]const u8).empty;
        defer {
            for (violated.items) |v| alloc.free(v);
            violated.deinit(alloc);
        }
        for (deliverables) |d| {
            const v = deliverableVerdict(io, repo_root, d);
            if (!v.ok) {
                try violated.append(alloc, try std.fmt.allocPrint(alloc, "{s}  ({s})", .{ d, v.reason }));
            }
        }
        if (violated.items.len > 0) {
            unlockStore();
            w.diag("\n  REJECTED: {s} has {d} deliverable(s) not cleanly in git:\n", .{ id, violated.items.len });
            for (violated.items) |v| {
                w.diag("    - {s}\n", .{v});
            }
            w.diag("  Commit each path (git add <path> && git commit), then done again.\n", .{});
            w.diag("  A deliverable that is not committed is not a deliverable.\n", .{});
            std.process.exit(1);
        }
    }

    // ── T485: absorption done-gate (absorption-spec §4) ──
    // For pass / pass-with-findings / fail-found, run claimlint `c7 --json`
    // and take the C7 verdict scoped to THIS task's findings files. Refuse
    // the close while any of them is non-conforming (named first, with the
    // parse error) or carries an unabsorbed proposal (each named: claim id,
    // proposed, register-actual). Refusal precedes the phase-1 write; there
    // is no --skip-absorption flag and no --force bypass — an escape valve
    // here is the threshold reborn. blocked/abandoned are exempt, exactly
    // like the deliverable check above (spec §9).
    if (!std.mem.eql(u8, verdict_str, "blocked") and !std.mem.eql(u8, verdict_str, "abandoned")) {
        refuseIfUnabsorbed(w, io, repo_root, id);
    }

    // ── T350 phase-1 pre-checks (under lock, before the done write) ──
    // T227 defect-3 fix: an empty --skip-acceptance reason is rejected here,
    // BEFORE the write — a malformed skip must never leave the store mutated.
    if (skip_acceptance_reason) |reason| {
        const acceptance_applies = ts_ptr.acceptance != null and
            (std.mem.eql(u8, verdict_str, "pass") or std.mem.eql(u8, verdict_str, "pass-with-findings"));
        if (reason.len == 0 and acceptance_applies) {
            unlockStore();
            w.diag("\n  REJECTED: {s} --skip-acceptance requires a non-empty reason\n", .{id});
            std.process.exit(1);
        }
    }

    // ── phase-1 write (T350): status done + verdict, under the flock ──
    // The acceptance gate runs after the write (phase 2) so the flock is held
    // for the store mutation only, never for the acceptance command's runtime
    // (up to 60s — holding it that long would block every other store op).
    // The pre-mutation terminal fields are captured for the phase-2 revert.
    const now = try nowTimestamp();
    const prev_done = ts_ptr.done;
    const prev_verdict = ts_ptr.verdict;
    const prev_verdict_note = ts_ptr.verdict_note;
    const prev_impression = ts_ptr.impression;
    const prev_impression_waiver = ts_ptr.impression_waiver;

    // T213: all terminal tasks use status=.done; verdict carries the flavour
    ts_ptr.status = .done;
    ts_ptr.done = now;
    ts_ptr.verdict = try alloc.dupe(u8, verdict_str);
    if (verdict_note_str) |vn| {
        ts_ptr.verdict_note = try alloc.dupe(u8, vn);
    }
    // T522: record the impression (or waiver) the gate demanded.  The gate
    // guarantees at most one is non-empty; a fresh in_progress row has both
    // null, so this is the only path (no old allocation to free here).
    if (has_impression) {
        ts_ptr.impression = try alloc.dupe(u8, impression_override.?);
    }
    if (has_waiver) {
        ts_ptr.impression_waiver = try alloc.dupe(u8, impression_waiver_override.?);
    }
    // T217: record --skip-acceptance reason on the task
    if (skip_acceptance_reason) |reason| {
        if (ts_ptr.skip_acceptance_reason) |old| alloc.free(old);
        ts_ptr.skip_acceptance_reason = try alloc.dupe(u8, reason);
    }

    // T424: a forced claim-at-close close must leave a record — the escape
    // was silent, and the kanban stopped agreeing with reality.  The record
    // is an amendment, so show/audit surface it exactly like a manual amend.
    if (forced_close_gap) |gap| {
        const rec = try std.fmt.allocPrint(alloc, "{s}: FORCED close (claimed {d}s before done) — claim-at-close acknowledged via --force", .{ now, gap });
        var new_ams = std.ArrayList([]const u8).empty;
        for (ts_ptr.amendments) |am| try new_ams.append(alloc, am);
        try new_ams.append(alloc, rec);
        alloc.free(ts_ptr.amendments);
        ts_ptr.amendments = try new_ams.toOwnedSlice(alloc);
    }

    var unblocked = std.ArrayList([]const u8).empty;
    defer unblocked.deinit(alloc);

    var it2 = state.iterator();
    while (it2.next()) |entry| {
        const dep_ts = entry.value_ptr.*;
        if (dep_ts.status != .blocked) continue;

        if (deriveStatus(&state, dep_ts) == .dispatchable) {
            const dep_ptr = state.getPtr(entry.key_ptr.*).?;
            dep_ptr.status = .dispatchable;
            try unblocked.append(alloc, entry.key_ptr.*);
        }
    }

    // T478: count the close.  Incremented atomically with the phase-1 done
    // write (under the flock) and never decremented — a later acceptance
    // failure reopens the row but the close *event* still counts toward duty
    // due-counts.  Monotonic; no separate lock round-trip.
    sys_closes += 1;

    try writeStateLocked(io, state_path, &state);
    // Release the flock before phase 2 — the acceptance command runs unlocked.
    unlockStore();

    // ── phase 2 (no lock): the acceptance gate (T217) ──
    // Only for pass / pass-with-findings verdicts; blocked/abandoned/fail-found skip.
    if (std.mem.eql(u8, verdict_str, "pass") or std.mem.eql(u8, verdict_str, "pass-with-findings")) {
        if (ts_ptr.acceptance) |acc_cmd| {
            if (skip_acceptance_reason) |reason| {
                w.diag("\n  ACCEPTANCE SKIPPED: {s}\n    reason: {s}\n", .{ id, reason });
            } else {
                // Run the acceptance command via /bin/sh -c
                const acc_result = std.process.run(alloc, io, .{
                    .argv = &.{ "/bin/sh", "-c", acc_cmd },
                    .cwd = .{ .path = repo_root },
                }) catch |err| {
                    // T295: spawn failure is an infrastructure fault — the
                    // shell itself could not be started. Distinguish from
                    // a task-failure exit.
                    w.diag("\n  CANNOT RUN: {s} acceptance could not start: {}\n", .{ id, err });
                    w.diag("  command: {s}\n", .{acc_cmd});
                    w.diag("  This is an infrastructure fault, not a task failure.\n", .{});
                    // T350: phase 1 already wrote done — roll it back.
                    const reverted = revertAcceptanceFailure(w, io, state_path, id, now, prev_done, prev_verdict, prev_verdict_note, prev_impression, prev_impression_waiver) catch false;
                    if (!reverted) w.diag("  WARNING: could not revert {s} — verify its status manually.\n", .{id});
                    w.diag("  Task stays in_progress. Fix the environment or use --skip-acceptance <reason>.\n", .{});
                    std.process.exit(1);
                };
                defer alloc.free(acc_result.stdout);
                defer alloc.free(acc_result.stderr);
                // T227 (defect 1 fix): .exited reads 0 on signalled children.
                // T295: distinguish acceptance-failure verdicts:
                //   exit 127 = shell "command not found" (cannot run)
                //   exit 126 = shell "not executable" (cannot run)
                //   other non-zero = task's work genuinely failing
                //   signal/stopped/unknown = infrastructure fault
                var passed = false;
                switch (acc_result.term) {
                    .exited => |code| {
                        if (code == 0) {
                            passed = true;
                        } else if (code == 127) {
                            w.diag("\n  CANNOT RUN: {s} acceptance command not found in PATH\n", .{id});
                            w.diag("  command: {s}\n", .{acc_cmd});
                            w.diag("  This is an infrastructure fault, not a task failure.\n", .{});
                        } else if (code == 126) {
                            w.diag("\n  CANNOT RUN: {s} acceptance command found but not executable\n", .{id});
                            w.diag("  command: {s}\n", .{acc_cmd});
                            w.diag("  This is an infrastructure fault, not a task failure.\n", .{});
                        } else {
                            const last_output = if (acc_result.stderr.len > 0) acc_result.stderr else acc_result.stdout;
                            w.diag("\n  ACCEPTANCE FAILED: {s} exited with code {d}\n", .{ id, code });
                            w.diag("  command: {s}\n", .{acc_cmd});
                            if (last_output.len > 0) {
                                w.diag("  last output: {s}\n", .{last_output});
                            }
                        }
                    },
                    .signal => |sig| {
                        w.diag("\n  CANNOT RUN: {s} acceptance command killed by signal {d}\n", .{ id, sig });
                    },
                    .stopped => {
                        w.diag("\n  CANNOT RUN: {s} acceptance command stopped\n", .{id});
                    },
                    .unknown => {
                        w.diag("\n  CANNOT RUN: {s} acceptance command terminated with unknown status\n", .{id});
                    },
                }
                if (!passed) {
                    // T350: phase 1 already wrote done — the store must not
                    // keep advertising a completion the gate never confirmed.
                    const reverted = revertAcceptanceFailure(w, io, state_path, id, now, prev_done, prev_verdict, prev_verdict_note, prev_impression, prev_impression_waiver) catch false;
                    if (!reverted) w.diag("  WARNING: could not revert {s} — verify its status manually.\n", .{id});
                    w.diag("  Task stays in_progress. Fix the issue or use --skip-acceptance <reason>.\n", .{});
                    std.process.exit(1);
                }
                w.diag("\n  acceptance: {s} OK\n", .{acc_cmd});
            }
        }
    }

    w.diag("\n  {s} done  [set: {c}]  [verdict: {s}]", .{ id, ts_ptr.set, verdict_str });
    if (unblocked.items.len > 0) {
        w.diag("  [unblocks:", .{});
        for (unblocked.items) |ub| {
            w.diag(" {s}", .{ub});
        }
        w.diag("]", .{});
    }
    w.diag("\n", .{});
}

/// T350: phase-2 acceptance-failure rollback.  Re-acquires the flock, re-reads
/// the store, and restores <id> from the done state phase 1 wrote back to
/// in_progress.  Guarded: the revert is skipped when the task no longer carries
/// the exact phase-1 done timestamp — a concurrent reopen/redo/purge touched
/// it, and clobbering that is worse than leaving a stale done.  Returns true
/// when the revert was applied, false when skipped (task changed or vanished).
/// Tasks left dispatchable only by the (now reverted) completion are re-blocked
/// — the symmetric inverse of phase 1's unblock sweep, so the kanban never
/// advertises dependents as runnable on a completion that did not stick.
fn revertAcceptanceFailure(
    w: Writers,
    io: std.Io,
    state_path: []const u8,
    id: []const u8,
    phase1_done: []const u8,
    prev_done: ?[]const u8,
    prev_verdict: ?[]const u8,
    prev_verdict_note: ?[]const u8,
    prev_impression: ?[]const u8,
    prev_impression_waiver: ?[]const u8,
) !bool {
    try lockStore(io, state_path);
    defer unlockStore();
    var state = try readState(io, state_path);

    const ts = state.getPtr(id) orelse {
        w.diag("  (task {s} no longer exists — nothing to revert)\n", .{id});
        return false;
    };

    if (ts.status != .done) {
        w.diag("  (task {s} is {s} — not the done write from this command; leaving it alone)\n", .{ id, statusToString(ts.status) });
        return false;
    }
    if (ts.done == null or !std.mem.eql(u8, ts.done.?, phase1_done)) {
        w.diag("  (task {s} was re-completed since — leaving the newer done write alone)\n", .{id});
        return false;
    }

    ts.status = .in_progress;
    if (ts.done) |d| alloc.free(d);
    ts.done = if (prev_done) |d| try alloc.dupe(u8, d) else null;
    if (ts.verdict) |v| alloc.free(v);
    ts.verdict = if (prev_verdict) |v| try alloc.dupe(u8, v) else null;
    if (ts.verdict_note) |vn| alloc.free(vn);
    ts.verdict_note = if (prev_verdict_note) |vn| try alloc.dupe(u8, vn) else null;
    if (ts.impression) |im| alloc.free(im);
    ts.impression = if (prev_impression) |im| try alloc.dupe(u8, im) else null;
    if (ts.impression_waiver) |iw| alloc.free(iw);
    ts.impression_waiver = if (prev_impression_waiver) |iw| try alloc.dupe(u8, iw) else null;

    var reblocked = std.ArrayList([]const u8).empty;
    defer reblocked.deinit(alloc);
    var it = state.iterator();
    while (it.next()) |entry| {
        const dep = entry.value_ptr.*;
        if (dep.status != .dispatchable) continue;
        if (deriveStatus(&state, dep) == .blocked) {
            state.getPtr(entry.key_ptr.*).?.status = .blocked;
            try reblocked.append(alloc, entry.key_ptr.*);
        }
    }

    try writeStateLocked(io, state_path, &state);

    w.diag("  reverted {s} to in_progress (acceptance failed)\n", .{id});
    if (reblocked.items.len > 0) {
        w.diag("  re-blocked:", .{});
        for (reblocked.items) |rb| {
            w.diag(" {s}", .{rb});
        }
        w.diag("\n", .{});
    }
    return true;
}

fn cmdReopen(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    _ = repo_root;
    if (args.len < 3) {
        w.diag("usage: managent reopen <id>\n", .{});
        std.process.exit(1);
    }
    const id = args[2];

    // T337: lock → re-read → modify → writeStateLocked → unlock
    try lockStore(io, state_path);
    defer unlockStore();
    var state = try readState(io, state_path);

    const ts_ptr = state.getPtr(id) orelse {
        w.diag("error: task '{s}' not found\n", .{id});
        std.process.exit(1);
    };

    const prev = ts_ptr.status;
    // T213: also allow done tasks with blocked/abandoned verdict to be reopened
    const is_blocked_done = prev == .done and ts_ptr.verdict != null and
        (std.mem.eql(u8, ts_ptr.verdict.?, "blocked") or std.mem.eql(u8, ts_ptr.verdict.?, "abandoned"));
    if (prev != .in_progress and prev != .failed and !is_blocked_done) {
        if (prev == .done) {
            // T424: a real completion is not re-queueable (mint a new row for
            // fresh work), but a post-close correction must still be
            // recordable against the row — amend does that (T422's D064 shape:
            // the fix landed in follow-up commit 4330ef2 outside the row).
            w.diag("error: task '{s}' is done (reopen is for in_progress/failed tasks killed mid-attempt)\n", .{id});
            w.diag("  A done row is a real completion, not a killed attempt — it is not re-queueable.\n", .{});
            w.diag("  To record a post-close correction (a follow-up commit, a late directive):\n", .{});
            w.diag("    managent amend {s} --post-close \"<what landed and where>\"\n", .{id});
            w.diag("  or to correct the verdict itself: managent amend {s} --verdict <v> --note <text>\n", .{id});
            w.diag("  For fresh work, mint a new row.\n", .{});
            std.process.exit(1);
        }
        w.diag("error: task '{s}' is {s} (reopen is for in_progress/failed/blocked tasks killed mid-attempt)\n", .{ id, statusToString(prev) });
        std.process.exit(1);
    }

    ts_ptr.status = if (needsMet(&state, ts_ptr.*)) .dispatchable else .blocked;
    ts_ptr.agent = null;
    ts_ptr.claimed = null;
    ts_ptr.done = null;
    if (ts_ptr.verdict) |v| {
        alloc.free(v);
        ts_ptr.verdict = null;
    }
    if (ts_ptr.verdict_note) |vn| {
        alloc.free(vn);
        ts_ptr.verdict_note = null;
    }
    // T522: a reopened row must clear the prior close's impression/waiver —
    // the gate demands a fresh one on the next close, never a stale carry-over.
    if (ts_ptr.impression) |im| {
        alloc.free(im);
        ts_ptr.impression = null;
    }
    if (ts_ptr.impression_waiver) |iw| {
        alloc.free(iw);
        ts_ptr.impression_waiver = null;
    }

    try writeStateLocked(io, state_path, &state);

    const prev_str: []const u8 = if (prev == .in_progress) "in_progress" else if (prev == .failed) "failed" else "done";
    const status_str: []const u8 = statusToString(ts_ptr.status);
    w.diag("\n  reopened {s}  [set: {c}]  (was {s}, now {s})\n", .{ id, ts_ptr.set, prev_str, status_str });
    w.diag("  follow {s}\n", .{ts_ptr.bundle});
}

fn cmdPurge(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    _ = args;
    // T337: lock → re-read → modify → writeStateLocked → unlock
    try lockStore(io, state_path);
    defer unlockStore();
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

    // S10-STORE-4: record the ids this write retires so the write-time check
    // can tell a legitimate shrink from a reverted store.
    retiring_ids = purged.items;
    try writeStateLocked(io, state_path, &state);
    retiring_ids = &.{};

    w.diag("\n  purged {d} task(s):", .{purged.items.len});
    for (purged.items) |p| w.diag(" {s}", .{p});
    w.diag("\n", .{});
    if (cleaned.items.len > 0) {
        w.diag("  cleaned needs of:", .{});
        for (cleaned.items) |c| w.diag(" {s}", .{c});
        w.diag("\n", .{});
    }
}

// ── T319: archive closed rows to an archive store ──────────────────────────
// Closed rows are load-bearing (why, audit, model-perf) and must not be
// deleted.  archive moves them to docs/infra/managent/archive.json, tracked
// in git, and cleans their IDs from remaining needs edges (same as purge).
// Eligibility: status done or failed, all holds committed, no live dependents.

fn cmdArchive(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    const dry_run = hasFlag(args, "--dry-run");
    const force = hasFlag(args, "--force");
    _ = force; // reserved for future: skip absorption check

    // Lock the store for the entire archive operation.
    try lockStore(io, state_path);
    defer unlockStore();
    var state = try readState(io, state_path);

    // Archive path lives beside the live store.
    const archive_path = try std.fs.path.join(alloc, &.{ repo_root, "docs", "infra", "managent", "archive.json" });
    defer alloc.free(archive_path);

    // Read existing archive (or start empty).
    var archive_state = try readState(io, archive_path);
    defer freeState(&archive_state);

    // Collect archivable rows: done or failed, no live dependents,
    // holds paths committed (checked via git ls-files).
    const git_files_str = try runCommand(alloc, io, &.{ "git", "-C", repo_root, "ls-files" });
    defer alloc.free(git_files_str);

    var to_archive = std.ArrayList([]const u8).empty;
    defer to_archive.deinit(alloc);
    var refused_not_done = std.ArrayList([]const u8).empty;
    defer refused_not_done.deinit(alloc);
    var refused_dependents = std.ArrayList([]const u8).empty;
    defer refused_dependents.deinit(alloc);
    var refused_holds = std.ArrayList([]const u8).empty;
    defer refused_holds.deinit(alloc);
    var refused_absorbed = std.ArrayList([]const u8).empty;
    defer refused_absorbed.deinit(alloc);
    var refused_nonconforming = std.ArrayList([]const u8).empty;
    defer refused_nonconforming.deinit(alloc);

    // First pass: find live dependents (tasks that need an archivable row)
    var live_needed = std.StringHashMapUnmanaged(void).empty;
    defer live_needed.deinit(alloc);
    {
        var it = state.iterator();
        while (it.next()) |entry| {
            const ts = entry.value_ptr.*;
            if (ts.status == .in_progress or ts.status == .dispatchable or ts.status == .blocked) {
                for (ts.needs) |n| {
                    live_needed.put(alloc, try alloc.dupe(u8, n), {}) catch {};
                }
            }
        }
    }

    // C7 absorption check (T487): consume claimlint's machine-readable
    // `c7 --json` report — one object per findings file — instead of
    // re-parsing the human-readable C7 block. The old parser matched only
    // "  C7 UNABSORBED  `" item lines and missed NON-CONFORMING lines
    // (claimlint emits "  C7 ... NON-CONFORMING  <file> — <reason>"), so a
    // done task carrying a non-conforming findings file archived cleanly —
    // the same "parser matches a format that doesn't exist / misses a format
    // that does" class as T368 and CODE.STANDING-C3-DEAD. One count, one
    // implementation (absorption-spec §7): claimlint computes the per-file
    // verdict (conforming + unabsorbed[]); archive maps each drifting file
    // to its owning task id (declared task_id, else the <TASKID>-<slug>.json
    // filename convention) and refuses that task.
    var unabsorbed = std.StringHashMapUnmanaged(void).empty;
    defer unabsorbed.deinit(alloc);
    var nonconforming = std.StringHashMapUnmanaged(void).empty;
    defer nonconforming.deinit(alloc);
    {
        const cl_result = blk: {
            const r = std.process.run(alloc, io, .{
                .argv = &.{ "bin/weizigo-claimlint", "c7", "--json" },
                .cwd = .{ .path = repo_root },
            }) catch break :blk null;
            break :blk r;
        };
        if (cl_result) |*cr| {
            defer alloc.free(cr.stdout);
            defer alloc.free(cr.stderr);
            const code: u8 = switch (cr.term) {
                .exited => |c| c,
                else => 255,
            };
            // Exit 0: nothing non-conforming and nothing unabsorbed anywhere,
            // so no task is refused by construction (the same shortcut as the
            // done-gate and the standing partition join).
            if (code == 0) {
                // clean — nothing to refuse
            } else if (code == 1) {
                var parsed = std.json.parseFromSlice(std.json.Value, alloc, cr.stdout, .{ .allocate = .alloc_always }) catch null;
                if (parsed) |*pv| {
                    defer pv.deinit();
                    if (pv.value != .array) {
                        w.diag("  WARNING: claimlint c7 --json did not emit an array — the archive absorption check is blind\n", .{});
                    } else {
                        for (pv.value.array.items) |pf| {
                            if (pf != .object) continue;
                            const obj = pf.object;
                            const conforming = if (obj.get("conforming")) |v| v == .bool and v.bool else false;
                            var has_unabsorbed = false;
                            if (obj.get("unabsorbed")) |ua| {
                                if (ua == .array and ua.array.items.len > 0) has_unabsorbed = true;
                            }
                            if (conforming and !has_unabsorbed) continue;
                            // Owning task id: the declared task_id, else the
                            // filename-derived id (mirrors the partition join).
                            const declared = runRecOptStr(obj, "task_id") orelse "";
                            const path = runRecStr(obj, "path");
                            const tid = if (declared.len > 0) declared else (taskIdFromFindingsPath(path) orelse "");
                            if (tid.len == 0) continue;
                            if (!conforming) {
                                nonconforming.put(alloc, try alloc.dupe(u8, tid), {}) catch {};
                            }
                            if (has_unabsorbed) {
                                unabsorbed.put(alloc, try alloc.dupe(u8, tid), {}) catch {};
                            }
                        }
                    }
                } else {
                    w.diag("  WARNING: claimlint c7 --json emitted unparseable output — the archive absorption check is blind\n", .{});
                }
            } else {
                w.diag("  WARNING: claimlint c7 --json failed (exit {d}) — the archive absorption check is blind\n", .{ code });
            }
        } else {
            w.diag("  WARNING: bin/weizigo-claimlint missing or failed to run — the archive absorption check is blind\n", .{});
        }
    }

    // Second pass: determine eligibility
    {
        var it = state.iterator();
        while (it.next()) |entry| {
            const id = entry.key_ptr.*;
            const ts = entry.value_ptr.*;

            if (ts.status != .done and ts.status != .failed) {
                try refused_not_done.append(alloc, id);
                continue;
            }
            if (live_needed.contains(id)) {
                try refused_dependents.append(alloc, id);
                continue;
            }
            // Check holds are committed
            var all_holds_committed = true;
            for (ts.holds) |h| {
                if (std.mem.indexOf(u8, git_files_str, h) == null) {
                    all_holds_committed = false;
                    break;
                }
            }
            if (!all_holds_committed) {
                try refused_holds.append(alloc, id);
                continue;
            }
            // Check absorption: refuse a task whose findings are unabsorbed
            // (C7) or whose findings file is non-conforming (T487).
            if (unabsorbed.contains(id)) {
                try refused_absorbed.append(alloc, id);
                continue;
            }
            if (nonconforming.contains(id)) {
                try refused_nonconforming.append(alloc, id);
                continue;
            }

            try to_archive.append(alloc, id);
        }
    }

    if (dry_run) {
        w.diag("\n  DRY RUN — nothing will be written\n", .{});
    }

    w.diag("\n  archivable: {d} row(s)", .{to_archive.items.len});
    if (to_archive.items.len > 0) {
        for (to_archive.items) |a| w.diag(" {s}", .{a});
    }
    w.diag("\n  refused: {d} not done/failed, {d} live dependents, {d} uncommitted holds, {d} unabsorbed findings, {d} non-conforming findings\n", .{
        refused_not_done.items.len,
        refused_dependents.items.len,
        refused_holds.items.len,
        refused_absorbed.items.len,
        refused_nonconforming.items.len,
    });

    if (dry_run) {
        w.diag("  Run without --dry-run to execute.\n", .{});
        return;
    }

    if (to_archive.items.len == 0) {
        w.diag("  nothing to archive\n", .{});
        return;
    }

    // Move rows to archive.
    var archived_count: usize = 0;
    for (to_archive.items) |id| {
        if (state.get(id)) |ts| {
            const ts_copy = ts;
            try archive_state.put(alloc, try alloc.dupe(u8, id), ts_copy);
            _ = state.remove(id);
            archived_count += 1;
        }
    }

    // Clean needs edges in remaining tasks (same as purge).
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
                var is_archived = false;
                for (to_archive.items) |a| {
                    if (std.mem.eql(u8, n, a)) {
                        is_archived = true;
                        break;
                    }
                }
                if (!is_archived) {
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

    // Write both stores atomically.
    // S10-STORE-4: name the ids this write retires (legitimate shrink, no alarm).
    retiring_ids = to_archive.items;
    try writeStateLocked(io, state_path, &state);
    retiring_ids = &.{};
    try writeStateLocked(io, archive_path, &archive_state);

    w.diag("\n  archived {d} row(s):", .{archived_count});
    for (to_archive.items) |a| {
        if (archive_state.contains(a)) w.diag(" {s}", .{a});
    }
    w.diag("\n", .{});
    if (cleaned.items.len > 0) {
        w.diag("  cleaned needs of:", .{});
        for (cleaned.items) |c| w.diag(" {s}", .{c});
        w.diag("\n", .{});
    }
    w.diag("  archive store: docs/infra/managent/archive.json\n", .{});
    w.diag("  Both stores must be committed together (the archive store is new).\n", .{});
}

// ── T464: retire a row from the live kanban (archive, never delete) ─────────
// `purge` and `archive` accept only done/failed rows, so a dispatchable row
// that should leave (T462's close-with-evidence triage) had no verb.  retire
// accepts ANY status and moves the full record to archive.json with a one-line
// epitaph (--note) that stays on the archived record.
fn cmdRetire(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    if (args.len < 3) {
        w.diag("usage: managent retire <id> --note <epitaph>\n", .{});
        std.process.exit(1);
    }
    const id = args[2];
    const note_text = getFlagValue(args, "--note");
    if (note_text == null or note_text.?.len == 0) {
        w.diag("error: retire requires --note <epitaph> — a one-line epitaph stays on the archived record\n", .{});
        std.process.exit(1);
    }

    // T337: lock → re-read → modify → writeStateLocked → unlock
    try lockStore(io, state_path);
    defer unlockStore();
    var state = try readState(io, state_path);

    const ts = state.get(id) orelse {
        w.diag("error: task '{s}' not found\n", .{id});
        std.process.exit(1);
    };

    // Archive path lives beside the live store (same as cmdArchive).
    const archive_path = try std.fs.path.join(alloc, &.{ repo_root, "docs", "infra", "managent", "archive.json" });
    defer alloc.free(archive_path);

    var archive_state = try readState(io, archive_path);
    defer freeState(&archive_state);

    // The full record moves; the one-line epitaph stays on it.
    var moved = ts;
    moved.epitaph = try alloc.dupe(u8, note_text.?);
    try archive_state.put(alloc, try alloc.dupe(u8, id), moved);
    _ = state.remove(id);

    // Clean the retired id from remaining tasks' needs edges (same as purge/archive).
    var cleaned = std.ArrayList([]const u8).empty;
    defer cleaned.deinit(alloc);
    {
        var it = state.iterator();
        while (it.next()) |entry| {
            const tp = entry.value_ptr;
            if (tp.needs.len == 0) continue;
            var kept = std.ArrayList([]const u8).empty;
            var removed_any = false;
            for (tp.needs) |n| {
                if (std.mem.eql(u8, n, id)) {
                    removed_any = true;
                } else {
                    try kept.append(alloc, n);
                }
            }
            if (removed_any) {
                tp.needs = try kept.toOwnedSlice(alloc);
                try cleaned.append(alloc, entry.key_ptr.*);
            } else {
                kept.deinit(alloc);
            }
        }
    }

    // Write both stores atomically.
    // S10-STORE-4: name the id this write retires (legitimate shrink, no alarm).
    const retire_ids = [_][]const u8{id};
    retiring_ids = &retire_ids;
    try writeStateLocked(io, state_path, &state);
    retiring_ids = &.{};
    try writeStateLocked(io, archive_path, &archive_state);

    w.diag("\n  retired {s}  [set: {c}]  (archived with epitaph)\n", .{ id, ts.set });
    w.diag("  epitaph: {s}\n", .{note_text.?});
    w.diag("  archive store: docs/infra/managent/archive.json\n", .{});
    if (cleaned.items.len > 0) {
        w.diag("  cleaned needs of:", .{});
        for (cleaned.items) |c| w.diag(" {s}", .{c});
        w.diag("\n", .{});
    }
}

fn cmdSet(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    _ = repo_root;
    if (args.len < 4 or args[3].len == 0) {
        w.diag("usage: managent set <id> <A–Z>\n", .{});
        std.process.exit(1);
    }
    const id = args[2];
    const new_set = args[3][0];
    if (new_set < 'A' or new_set > 'Z') {
        w.diag("error: set must be an uppercase letter A–Z, got '{c}'\n", .{new_set});
        std.process.exit(1);
    }
    // T337: lock → re-read → modify → writeStateLocked → unlock
    try lockStore(io, state_path);
    defer unlockStore();
    var state = try readState(io, state_path);
    const ts_ptr = state.getPtr(id) orelse {
        w.diag("error: task '{s}' not found\n", .{id});
        std.process.exit(1);
    };
    const old_set = ts_ptr.set;
    ts_ptr.set = new_set;
    try writeStateLocked(io, state_path, &state);
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
    // T337: lock → re-read → modify → writeStateLocked → unlock
    try lockStore(io, state_path);
    defer unlockStore();
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

    try writeStateLocked(io, state_path, &state);

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
    const raw_name = args[3];

    // T317: validate canonical model label at point of writing.
    const name = canonicalizeModelTag(raw_name);
    if (!isCanonicalModel(name)) {
        w.diag("error: '{s}' is not a canonical model label.\n", .{raw_name});
        printCanonicalModels(w);
        std.process.exit(1);
    }

    // T317: lock → re-read → modify → write → unlock lost-update pattern.
    try lockStore(io, state_path);
    defer unlockStore();
    var state = try readState(io, state_path);
    const ts_ptr = state.getPtr(id) orelse {
        w.diag("error: task '{s}' not found\n", .{id});
        std.process.exit(1);
    };
    const old = ts_ptr.agent;
    // T544: correcting the agent also corrects the model — the two fields
    // describe the same attribution and must not be allowed to diverge.
    try setFirstHandAttribution(ts_ptr, name);
    try writeStateLocked(io, state_path, &state);
    w.diag("\n  {s}  agent {s} -> {s}\n", .{ id, old orelse "(none)", name });
}

// ── verdict — set verdict on a done task (backfill / correction) ─────────────

fn cmdVerdict(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    _ = repo_root;
    if (args.len < 4) {
        w.diag("usage: managent verdict <id> <verdict> [--note <text>]\n", .{});
        w.diag("       valid verdicts: pass pass-with-findings fail-found blocked abandoned\n", .{});
        std.process.exit(1);
    }
    const id = args[2];
    const verdict_str = args[3];
    const note_override = getFlagValue(args, "--note");

    if (!isValidVerdict(verdict_str)) {
        w.diag("error: invalid verdict '{s}'. Valid: ", .{verdict_str});
        for (valid_verdicts, 0..) |v, vi| {
            if (vi > 0) w.diag(", ", .{});
            w.diag("{s}", .{v});
        }
        w.diag("\n", .{});
        std.process.exit(1);
    }

    if (!std.mem.eql(u8, verdict_str, "pass") and note_override == null) {
        w.diag("\n  REJECTED: verdict '{s}' requires --note <text>\n", .{verdict_str});
        std.process.exit(1);
    }

    // T337: lock → re-read → modify → writeStateLocked → unlock
    try lockStore(io, state_path);
    defer unlockStore();
    var state = try readState(io, state_path);
    const ts_ptr = state.getPtr(id) orelse {
        w.diag("error: task '{s}' not found\n", .{id});
        std.process.exit(1);
    };

    if (ts_ptr.status != .done and ts_ptr.status != .failed) {
        w.diag("error: task '{s}' is {s} — verdict can only be set on done/failed tasks\n", .{ id, statusToString(ts_ptr.status) });
        std.process.exit(1);
    }

    if (ts_ptr.verdict) |old| alloc.free(old);
    ts_ptr.verdict = try alloc.dupe(u8, verdict_str);
    if (note_override) |n| {
        if (ts_ptr.verdict_note) |old| alloc.free(old);
        ts_ptr.verdict_note = try alloc.dupe(u8, n);
    }

    try writeStateLocked(io, state_path, &state);
    w.diag("\n  {s}  verdict -> {s}", .{ id, verdict_str });
    if (ts_ptr.verdict_note) |vn| w.diag("  (note: {s})", .{vn});
    w.diag("\n", .{});
}

// ── T317: append-only correction path ──────────────────────────────────────
// managent done is terminal; a row closed with a wrong verdict cannot be
// reopened (it was delivered, not killed mid-attempt).  amend appends a
// correction record — the original verdict is preserved and surfaced by
// show/status/audit alongside the correction, flagged for the reader.
//
// T424: two flavors.  `amend <id> --verdict <v> --note <t>` corrects the
// verdict (T317).  `amend <id> --post-close <t>` records a follow-up — a
// directive that landed after the close, or a fix that had to land in a
// follow-up commit outside the row (the T422 shape: D064 arrived after the
// work) — WITHOUT touching the verdict, because the verdict did not change.
// reopen still refuses done rows: a real completion is not re-queueable, and
// its refusal now names amend instead of dead-ending.

fn cmdAmend(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    _ = repo_root;
    if (args.len < 3) {
        w.diag("usage: managent amend <id> --verdict <verdict> --note <text>\n", .{});
        w.diag("       managent amend <id> --post-close <text>  (record a follow-up against a done row; verdict untouched)\n", .{});
        std.process.exit(1);
    }
    const id = args[2];
    const verdict_str = getFlagValue(args, "--verdict");
    const note_text = getFlagValue(args, "--note");
    const post_close_text = getFlagValue(args, "--post-close");

    if (post_close_text != null and (verdict_str != null or note_text != null)) {
        w.diag("error: use either --post-close (verdict untouched) or --verdict/--note (verdict correction), not both\n", .{});
        std.process.exit(1);
    }
    if (post_close_text == null) {
        if (verdict_str == null) {
            w.diag("error: --verdict is required\n", .{});
            std.process.exit(1);
        }
        if (note_text == null) {
            w.diag("error: --note is required (explain the correction)\n", .{});
            std.process.exit(1);
        }
        if (!isValidVerdict(verdict_str.?)) {
            w.diag("error: invalid verdict '{s}'. Valid: ", .{verdict_str.?});
            for (valid_verdicts, 0..) |v, vi| {
                if (vi > 0) w.diag(", ", .{});
                w.diag("{s}", .{v});
            }
            w.diag("\n", .{});
            std.process.exit(1);
        }
    } else {
        // T424: a post-close record is the follow-up itself; an empty one is
        // the same information vacuum as a bare 'done' (T227 defect-3 rule).
        if (post_close_text.?.len == 0) {
            w.diag("error: --post-close requires a non-empty note\n", .{});
            std.process.exit(1);
        }
        if (post_close_text.?.len > 4096) {
            w.diag("error: --post-close is 4 KiB max (got {d} bytes)\n", .{post_close_text.?.len});
            std.process.exit(1);
        }
    }

    // T317: lock → re-read → modify → write → unlock
    try lockStore(io, state_path);
    defer unlockStore();
    var state = try readState(io, state_path);
    const ts_ptr = state.getPtr(id) orelse {
        w.diag("error: task '{s}' not found\n", .{id});
        std.process.exit(1);
    };

    if (ts_ptr.status != .done and ts_ptr.status != .failed) {
        w.diag("error: task '{s}' is {s} — amend is for done/failed tasks only\n", .{ id, statusToString(ts_ptr.status) });
        std.process.exit(1);
    }

    const now = try nowTimestamp();
    const correction = if (post_close_text) |pct|
        try std.fmt.allocPrint(alloc, "{s}: post-close: {s}", .{ now, pct })
    else
        try std.fmt.allocPrint(alloc, "{s}: verdict={s} note={s}", .{ now, verdict_str.?, note_text.? });

    // Append to amendments array (alloc owned by the array)
    var new_amendments = std.ArrayList([]const u8).empty;
    for (ts_ptr.amendments) |am| {
        try new_amendments.append(alloc, am);
    }
    try new_amendments.append(alloc, correction);
    // Free old array but not the strings (they're now in new_amendments)
    alloc.free(ts_ptr.amendments);
    ts_ptr.amendments = try new_amendments.toOwnedSlice(alloc);

    try writeStateLocked(io, state_path, &state);

    if (post_close_text) |pct| {
        w.diag("\n  {s}  post-close correction recorded  [{s}]\n", .{ id, now });
        w.diag("  note: {s}\n", .{pct});
        w.diag("  The original verdict is preserved in the store.  audit flags amended rows.\n", .{});
    } else {
        const original = if (ts_ptr.verdict) |v| v else "(none)";
        w.diag("\n  {s}  amended  [{s}] → verdict={s}  (original: {s})\n", .{ id, now, verdict_str.?, original });
        w.diag("  note: {s}\n", .{note_text.?});
        w.diag("  The original verdict is preserved in the store.  audit flags amended rows.\n", .{});
    }
}

fn cmdStatus(w: Writers, io: std.Io, state_path: []const u8, repo_root: []const u8, args: [][]const u8) !void {
    const use_json = hasFlag(args, "--json");

    var state = try readState(io, state_path);
    defer freeState(&state);

    // T446: the board consults the assertion ledger — a `closed` assertion
    // supersedes tasks.json's status for rendering.
    var ledger = readLedgerStatuses(io, state_path);
    defer freeLedgerStatuses(&ledger);

    if (use_json) {
        try printStatusJson(w, &state, &ledger, repo_root);
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
    var duties = std.ArrayList([]const u8).empty;
    defer duties.deinit(alloc);

    var it_sort = state.iterator();
    while (it_sort.next()) |entry| {
        const tid = entry.key_ptr.*;
        // T478: a duty never renders in OPEN alongside tasks — its own section.
        if (entry.value_ptr.*.duty) {
            try duties.append(alloc, tid);
            continue;
        }
        // T464: ONE status resolver — the assertion ledger's latest assertion
        // is authoritative over tasks.json in BOTH directions.
        switch (resolveStatus(&state, entry.value_ptr.*, &ledger, tid).status) {
            .dispatchable => try dispatchable.append(alloc, tid),
            .in_progress => try in_progress.append(alloc, tid),
            .blocked => try blocked.append(alloc, tid),
            .done => try done.append(alloc, tid),
            .failed => try failed.append(alloc, tid),
        }
    }

    const sortFn = struct {
        fn lt(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lt;
    std.mem.sort([]const u8, dispatchable.items, {}, sortFn);
    std.mem.sort([]const u8, in_progress.items, {}, sortFn);
    std.mem.sort([]const u8, blocked.items, {}, sortFn);
    std.mem.sort([]const u8, done.items, {}, sortFn);
    std.mem.sort([]const u8, failed.items, {}, sortFn);
    std.mem.sort([]const u8, duties.items, {}, sortFn);

    // ── stdout: the data ──
    printSection(w, "dispatchable", dispatchable.items, &state, &ledger, repo_root);
    printSection(w, "in progress", in_progress.items, &state, &ledger, repo_root);

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

    printSection(w, "blocked", blocked.items, &state, &ledger, repo_root);
    printSection(w, "done", done.items, &state, &ledger, repo_root);
    printSection(w, "failed", failed.items, &state, &ledger, repo_root);
    printDutySection(w, duties.items, &state);
    w.data("\n", .{});
}

fn printDutySection(w: Writers, ids: []const []const u8, state: *StateMap) void {
    w.data("\n  duties ({d})\n", .{ids.len});
    if (ids.len == 0) {
        w.data("    -- none --\n", .{});
        return;
    }
    for (ids) |uid| {
        const ts = state.get(uid).?;
        const since = closesSinceChunk(ts);
        if (dutyIsDue(ts)) {
            w.data("    {s}  due ({d} closes since chunk, due after {d})", .{ uid, since, ts.due_after });
        } else {
            w.data("    {s}  not due ({d}/{d} closes since chunk)", .{ uid, since, ts.due_after });
        }
        if (ts.last_chunk_verdict) |v| {
            w.data(", last chunk: {s}", .{v});
            if (ts.last_chunk_ts) |t| w.data(" {s}", .{t});
        } else {
            w.data(", no chunk yet", .{});
        }
        w.data("\n", .{});
    }
}

fn printSection(w: Writers, label: []const u8, ids: []const []const u8, state: *StateMap, ledger: *const LedgerStatuses, repo_root: []const u8) void {
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
        // T497: the agent/identifier and dispatch line reflect the KANBAN
        // store (the row is live per tasks.json); the assertion ledger only
        // appends a history annotation, never replacing a live claim.
        if (ts.agent) |_| {
            const ident = agentIdentifier(ts, tid) catch tid;
            w.data(", {s}", .{ident});
        }
        if (ts.dispatched_to) |dt| {
            w.data(", dispatched {s}", .{dt});
        }
        if (writeAssertionAnnotation(w, ledger, tid, 40)) {
            // annotation rendered above
        }
        if (ts.verdict) |v| {
            w.data(", verdict={s}", .{v});
        }
        w.data(": follow {s}\n", .{rel});
    }
}

fn printStatusJson(w: Writers, state: *StateMap, ledger: *const LedgerStatuses, repo_root: []const u8) !void {
    // T399: this is a JSON writer (stdout data consumed by dashboards); free
    // text goes through writeJsonString like every other JSON writer.
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(alloc);
    try buf.appendSlice(alloc, "[");
    var it = state.iterator();
    var first = true;
    while (it.next()) |entry| {
        if (!first) try buf.appendSlice(alloc, ",");
        first = false;
        const ts = entry.value_ptr.*;
        const rel = bundleRel(ts.bundle, repo_root);
        // T478: a duty is its own kind — never "dispatchable" (so dashboards
        // and argus's dispatchable scans cannot mistake it for an open task).
        if (ts.duty) {
            const since = closesSinceChunk(ts);
            try buf.appendSlice(alloc, "\n  {\"id\":");
            try writeJsonString(&buf, entry.key_ptr.*);
            try buf.appendSlice(alloc, ",\"status\":\"duty\",\"duty\":true");
            try buf.appendSlice(alloc, ",\"due\":");
            try buf.appendSlice(alloc, if (dutyIsDue(ts)) "true" else "false");
            try buf.appendSlice(alloc, ",\"closes_since_chunk\":");
            try buf.appendSlice(alloc, try std.fmt.allocPrint(alloc, "{d}", .{since}));
            try buf.appendSlice(alloc, ",\"due_after\":");
            try buf.appendSlice(alloc, try std.fmt.allocPrint(alloc, "{d}", .{ts.due_after}));
            try buf.appendSlice(alloc, ",\"set\":");
            try writeJsonString(&buf, &.{ts.set});
            try buf.appendSlice(alloc, ",\"bundle\":");
            try writeJsonString(&buf, rel);
            if (ts.last_chunk_verdict) |v| {
                try buf.appendSlice(alloc, ",\"last_chunk_verdict\":");
                try writeJsonString(&buf, v);
            }
            if (ts.last_chunk_findings) |v| {
                try buf.appendSlice(alloc, ",\"last_chunk_findings\":");
                try writeJsonString(&buf, v);
            }
            if (ts.last_chunk_ts) |v| {
                try buf.appendSlice(alloc, ",\"last_chunk_ts\":");
                try writeJsonString(&buf, v);
            }
            // T516: duties carry the same `added`/`claim_count` store fields
            // as task rows; emit them for a uniform schema across the array.
            try buf.appendSlice(alloc, ",\"added\":");
            try writeJsonString(&buf, ts.added);
            try buf.appendSlice(alloc, ",\"claim_count\":");
            try buf.appendSlice(alloc, try std.fmt.allocPrint(alloc, "{d}", .{ts.claim_count}));
            try buf.appendSlice(alloc, "}");
            continue;
        }
        // T497: status comes ONLY from the kanban store (deriveStatus).
        // `asserted` is an informational annotation field (the latest
        // assertion id), never authority; the live claim fields render
        // regardless of whether an assertion is present.
        const resolved = resolveStatus(state, ts, ledger, entry.key_ptr.*);
        const asserted = resolved.asserted;
        try buf.appendSlice(alloc, "\n  {\"id\":");
        try writeJsonString(&buf, entry.key_ptr.*);
        try buf.appendSlice(alloc, ",\"status\":");
        try writeJsonString(&buf, statusToString(resolved.status));
        try buf.appendSlice(alloc, ",\"set\":");
        try writeJsonString(&buf, &.{ts.set});
        try buf.appendSlice(alloc, ",\"bundle\":");
        try writeJsonString(&buf, rel);
        if (asserted) |a| {
            try buf.appendSlice(alloc, ",\"asserted\":");
            try writeJsonString(&buf, a);
        }
        if (ts.model) |m| {
            try buf.appendSlice(alloc, ",\"model\":");
            try writeJsonString(&buf, m);
        }
        if (ts.model_source) |ms| {
            try buf.appendSlice(alloc, ",\"model_source\":");
            try writeJsonString(&buf, ms);
        }
        if (ts.model_unknown_reason) |mur| {
            try buf.appendSlice(alloc, ",\"model_unknown_reason\":");
            try writeJsonString(&buf, mur);
        }
        // T635: assignment record — `method` is the ruling-33 partition
        // (random | forced | preferred); downstream readers split on it.
        if (ts.method) |m| {
            try buf.appendSlice(alloc, ",\"method\":");
            try writeJsonString(&buf, m);
        }
        if (ts.candidates.len > 0) {
            try buf.appendSlice(alloc, ",\"candidates\":[");
            for (ts.candidates, 0..) |c, ci| {
                if (ci > 0) try buf.appendSlice(alloc, ",");
                try writeJsonString(&buf, c);
            }
            try buf.appendSlice(alloc, "]");
        }
        if (ts.assign_reasons.len > 0) {
            try buf.appendSlice(alloc, ",\"assign_reasons\":[");
            for (ts.assign_reasons, 0..) |r, ri| {
                if (ri > 0) try buf.appendSlice(alloc, ",");
                try writeJsonString(&buf, r);
            }
            try buf.appendSlice(alloc, "]");
        }
        if (ts.shape) |sh| {
            try buf.appendSlice(alloc, ",\"shape\":");
            try writeJsonString(&buf, sh);
        }
        if (ts.shape_reasons.len > 0) {
            try buf.appendSlice(alloc, ",\"shape_reasons\":[");
            for (ts.shape_reasons, 0..) |r, ri| {
                if (ri > 0) try buf.appendSlice(alloc, ",");
                try writeJsonString(&buf, r);
            }
            try buf.appendSlice(alloc, "]");
        }
        if (ts.agent) |_| {
            const ident = agentIdentifier(ts, entry.key_ptr.*) catch entry.key_ptr.*;
            try buf.appendSlice(alloc, ",\"identifier\":");
            try writeJsonString(&buf, ident);
        }
        if (ts.needs.len > 0) {
            try buf.appendSlice(alloc, ",\"needs\":[");
            for (ts.needs, 0..) |n, ni| {
                if (ni > 0) try buf.appendSlice(alloc, ",");
                try writeJsonString(&buf, n);
            }
            try buf.appendSlice(alloc, "]");
        }
        if (ts.holds.len > 0) {
            try buf.appendSlice(alloc, ",\"holds\":[");
            for (ts.holds, 0..) |h, hi| {
                if (hi > 0) try buf.appendSlice(alloc, ",");
                try writeJsonString(&buf, h);
            }
            try buf.appendSlice(alloc, "]");
        }
        if (ts.dispatched_to) |dt| {
            try buf.appendSlice(alloc, ",\"dispatched_to\":");
            try writeJsonString(&buf, dt);
        }
        if (ts.verdict) |v| {
            try buf.appendSlice(alloc, ",\"verdict\":");
            try writeJsonString(&buf, v);
        }
        if (ts.impression) |im| {
            try buf.appendSlice(alloc, ",\"impression\":");
            try writeJsonString(&buf, im);
        }
        if (ts.impression_waiver) |iw| {
            try buf.appendSlice(alloc, ",\"impression_waiver\":");
            try writeJsonString(&buf, iw);
        }
        // T516: expose `added` (registration timestamp) and `claim_count`
        // (per-row claim tally) inline so the keeper never shells out to
        // `show` for two fields the dashboard wants. Both are always-present
        // store fields (`added` defaults to "", `claim_count` defaults to 0),
        // so they emit unconditionally for a stable JSON schema.
        try buf.appendSlice(alloc, ",\"added\":");
        try writeJsonString(&buf, ts.added);
        try buf.appendSlice(alloc, ",\"claim_count\":");
        try buf.appendSlice(alloc, try std.fmt.allocPrint(alloc, "{d}", .{ts.claim_count}));
        try buf.appendSlice(alloc, "}");
    }
    if (!first) try buf.appendSlice(alloc, "\n");
    try buf.appendSlice(alloc, "]\n");
    w.data("{s}", .{buf.items});
}

// ═══════════════════════════════════════════════════════════════════════════════
// RESUME SURFACE (T286) — compose at read time, never store
// ═══════════════════════════════════════════════════════════════════════════════
// `managent resume` composes the resume surface on demand from sources that
// cannot be stale: tasks.json (the kanban), git log/config/status, the claimlint
// summary against the recorded floor, and the channel STATE.md narrative (by
// reference). Nothing is cached and nothing is written; a stale surface is
// structurally impossible because the surface IS the sources, read at the
// instant of invocation. Design: docs/infra/resume-surface.md (T286).

const ResumeFloor = struct {
    c1a: i64 = 0,
    c1b: i64 = 0,
    c2: i64 = 0,
    c6: i64 = 0,
};

fn readResumeFloor(io: std.Io, repo_root: []const u8) ?ResumeFloor {
    const floor_path = std.fs.path.join(alloc, &.{ repo_root, "tools", "hooks", "claimlint-floor.json" }) catch return null;
    defer alloc.free(floor_path);
    const content = std.Io.Dir.cwd().readFileAlloc(io, floor_path, alloc, .unlimited) catch return null;
    defer alloc.free(content);
    var parsed = std.json.parseFromSlice(std.json.Value, alloc, content, .{ .allocate = .alloc_always }) catch return null;
    defer parsed.deinit();
    if (parsed.value != .object) return null;
    const floor = parsed.value.object.get("floor") orelse return null;
    if (floor != .object) return null;
    var out = ResumeFloor{};
    if (floor.object.get("C1a")) |v| {
        if (v == .integer) out.c1a = v.integer;
    }
    if (floor.object.get("C1b")) |v| {
        if (v == .integer) out.c1b = v.integer;
    }
    if (floor.object.get("C2")) |v| {
        if (v == .integer) out.c2 = v.integer;
    }
    if (floor.object.get("C6")) |v| {
        if (v == .integer) out.c6 = v.integer;
    }
    return out;
}

const ClaimlintSummary = struct {
    ran: bool = false,
    c1a: ?u64 = null,
    c1b: ?u64 = null,
    c2: ?u64 = null,
    c6: ?u64 = null,
    calibration_pass: bool = false,
};

/// Run the project's claimlint (from the repo root) and parse the summary
/// counts. Degrades to `ran=false` when the binary is absent or spawn fails
/// (fresh clone without a build) — the surface says "unavailable" instead of
/// inventing numbers.
fn runClaimlintSummary(allocator: std.mem.Allocator, io: std.Io, repo_root: []const u8) ClaimlintSummary {
    var out = ClaimlintSummary{};
    const result = std.process.run(allocator, io, .{
        .argv = &.{"bin/weizigo-claimlint"},
        .cwd = .{ .path = repo_root },
    }) catch return out;
    defer allocator.free(result.stdout);
    out.ran = true;
    var lines = std.mem.splitScalar(u8, result.stdout, '\n');
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, "C1a orphans") != null) {
            var tok = std.mem.tokenizeAny(u8, line, " \t");
            var idx: usize = 0;
            while (tok.next()) |t| : (idx += 1) {
                if (idx == 5) out.c1a = std.fmt.parseInt(u64, t, 10) catch null;
                if (idx == 7) out.c1b = std.fmt.parseInt(u64, t, 10) catch null;
            }
        } else if (std.mem.indexOf(u8, line, "C2 dangling") != null) {
            var tok = std.mem.tokenizeAny(u8, line, " \t");
            var idx: usize = 0;
            while (tok.next()) |t| : (idx += 1) {
                if (idx == 4) out.c2 = std.fmt.parseInt(u64, t, 10) catch null;
            }
        } else if (std.mem.indexOf(u8, line, "C6 cite-tag") != null) {
            var tok = std.mem.tokenizeAny(u8, line, " \t");
            var idx: usize = 0;
            while (tok.next()) |t| : (idx += 1) {
                if (idx == 3) out.c6 = std.fmt.parseInt(u64, t, 10) catch null;
            }
        } else if (std.mem.indexOf(u8, line, "calibration") != null) {
            out.calibration_pass = std.mem.indexOf(u8, line, "PASS") != null;
        }
    }
    return out;
}

fn printResumeSection(w: Writers, label: []const u8, ids: []const []const u8, state: *const StateMap, repo_root: []const u8) void {
    if (ids.len == 0) return;
    w.data("    {s} ({d})\n", .{ label, ids.len });
    for (ids) |tid| {
        const ts = state.get(tid).?;
        const rel = bundleRel(ts.bundle, repo_root);
        w.data("      {s} [set {c}]", .{ tid, ts.set });
        if (ts.holds.len > 0) {
            w.data(" holds", .{});
            for (ts.holds) |h| w.data(" {s}", .{h});
        }
        if (ts.needs.len > 0) {
            w.data(" needs", .{});
            for (ts.needs) |n| w.data(" {s}", .{n});
        }
        if (ts.agent != null) {
            const ident = agentIdentifier(ts, tid) catch tid;
            w.data(" ({s})", .{ident});
        }
        w.data(" — {s}\n", .{rel});
    }
}

/// Print the narrative headline of every channel STATE.md under untracked/msg/
/// — by reference. The prose is never copied into the surface; the resume
/// reader opens the file. Degrades to an explicit "none" when the channel
/// does not exist (fresh clone).
fn scanChannelState(w: Writers, io: std.Io, repo_root: []const u8) void {
    const msg_dir = std.fs.path.join(alloc, &.{ repo_root, "untracked", "msg" }) catch {
        w.data("    none (untracked/msg/ unreadable — fresh clone has no channel)\n", .{});
        return;
    };
    defer alloc.free(msg_dir);

    var root = std.Io.Dir.cwd().openDir(io, msg_dir, .{}) catch {
        w.data("    none (untracked/msg/ unreadable — fresh clone has no channel)\n", .{});
        return;
    };
    defer root.close(io);

    var subs = std.ArrayList([]const u8).empty;
    defer {
        for (subs.items) |s| alloc.free(s);
        subs.deinit(alloc);
    }
    var iter = root.iterate();
    while (iter.next(io) catch null) |entry| {
        if (entry.kind != .directory) continue;
        subs.append(alloc, alloc.dupe(u8, entry.name) catch continue) catch continue;
    }
    std.mem.sort([]const u8, subs.items, {}, struct {
        fn lt(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lt);

    if (subs.items.len == 0) {
        w.data("    none (no channel directories under untracked/msg/)\n", .{});
        return;
    }

    var found: usize = 0;
    for (subs.items) |sub| {
        const state_rel = std.fmt.allocPrint(alloc, "untracked/msg/{s}/STATE.md", .{sub}) catch continue;
        defer alloc.free(state_rel);
        const state_abs = std.fs.path.join(alloc, &.{ repo_root, state_rel }) catch continue;
        defer alloc.free(state_abs);
        const content = std.Io.Dir.cwd().readFileAlloc(io, state_abs, alloc, .unlimited) catch continue;
        defer alloc.free(content);

        found += 1;
        var title: ?[]const u8 = null;
        var last_updated: ?[]const u8 = null;
        var headline: ?[]const u8 = null;
        var clines = std.mem.splitScalar(u8, content, '\n');
        while (clines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t\r");
            if (title == null and trimmed.len > 0) title = trimmed;
            if (last_updated == null and std.mem.indexOf(u8, line, "Last updated") != null) {
                last_updated = std.mem.trim(u8, line, " \t\r");
            }
            if (headline == null and std.mem.startsWith(u8, trimmed, "## ")) headline = trimmed;
            if (title != null and last_updated != null and headline != null) break;
        }
        w.data("    {s}\n", .{state_rel});
        if (title) |t| w.data("      title: {s}\n", .{t});
        if (last_updated) |lu| w.data("      last updated: {s}\n", .{lu});
        if (headline) |h| w.data("      headline: {s}\n", .{h});
        w.data("      (full narrative lives in that file — resume reads it there)\n", .{});
    }
    if (found == 0) w.data("    none (no STATE.md under untracked/msg/)\n", .{});
}

fn cmdResume(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    _ = args;

    var state = try readState(io, state_path);
    defer freeState(&state);

    const now = try nowTimestamp();
    defer alloc.free(now);

    var in_progress = std.ArrayList([]const u8).empty;
    defer in_progress.deinit(alloc);
    var dispatchable = std.ArrayList([]const u8).empty;
    defer dispatchable.deinit(alloc);
    var blocked = std.ArrayList([]const u8).empty;
    defer blocked.deinit(alloc);

    var it = state.iterator();
    while (it.next()) |entry| {
        const tid = entry.key_ptr.*;
        const ts = entry.value_ptr.*;
        switch (deriveStatus(&state, ts)) {
            .in_progress => try in_progress.append(alloc, tid),
            .dispatchable => try dispatchable.append(alloc, tid),
            .blocked => try blocked.append(alloc, tid),
            else => {},
        }
    }
    const sortFn = struct {
        fn lt(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lt;
    std.mem.sort([]const u8, in_progress.items, {}, sortFn);
    std.mem.sort([]const u8, dispatchable.items, {}, sortFn);
    std.mem.sort([]const u8, blocked.items, {}, sortFn);

    const live = in_progress.items.len + dispatchable.items.len + blocked.items.len;

    // ── header ──
    w.data("\n  === resume surface — composed at read time; nothing stored ===\n", .{});
    w.data("  composed {s} from tasks.json · git log/config/status · claimlint · STATE.md\n", .{now});

    // ── self-defense: the surface must know its own provenance ──
    // T289: the resume surface is the read-first surface; a surface that
    // cannot tell you it is out of date is the same failure in a new place
    // (T286 — the old surface was deleted while its replacement lived only
    // in zig-out/, and no cold reader could tell). Report this binary's
    // build stamp beside the source's current state, with an explicit
    // verdict (CURRENT / STALE / cannot verify), using the same staleness
    // rule as tools/smoke.sh: current iff no committed change since this
    // binary's build touched managent source (src/managent/,
    // tools/gen-version.sh, build.zig). Uncommitted edits do not trip it —
    // the verdict is about what a cold reader would be misled by, not
    // about in-progress work.
    const ts_tree = treeDirty(io, repo_root);
    const head_sha_raw = runCommand(alloc, io, &.{ "git", "-C", repo_root, "rev-parse", "--short", "HEAD" }) catch "";
    defer if (@intFromPtr(head_sha_raw.ptr) != @intFromPtr("".ptr)) alloc.free(head_sha_raw);
    const head_sha = std.mem.trim(u8, head_sha_raw, " \t\n\r");

    w.data("  self: built from {s}{s} {s} (zig {s})\n", .{
        version.commit,
        if (version.dirty) "-dirty" else "",
        version.build_date,
        version.zig_version,
    });
    if (head_sha.len == 0) {
        w.data("  source: HEAD unresolvable (git failed)\n", .{});
        w.data("  self-check: cannot verify — rebuild and deploy: zig build && zig build deploy-managent\n", .{});
    } else {
        w.data("  source: HEAD {s}, tree {s}\n", .{ head_sha, if (ts_tree.nonkanban == 0) "clean" else "dirty" });
        if (std.mem.eql(u8, version.commit, head_sha)) {
            w.data("  self-check: CURRENT — this binary was built from HEAD ({s})\n", .{head_sha});
        } else {
            const range = std.fmt.allocPrint(alloc, "{s}..HEAD", .{version.commit}) catch "";
            if (range.len == 0) {
                w.data("  self-check: cannot verify (alloc failure) — rebuild and deploy: zig build && zig build deploy-managent\n", .{});
            } else {
                defer alloc.free(range);
                const log_res = runGit(alloc, io, repo_root, &.{ "log", "--oneline", range, "--", "src/managent/", "tools/gen-version.sh", "build.zig" });
                defer if (@intFromPtr(log_res.stdout.ptr) != @intFromPtr("".ptr)) alloc.free(log_res.stdout);
                const log_trimmed = std.mem.trim(u8, log_res.stdout, " \t\n\r");
                if (!log_res.ok) {
                    w.data("  self-check: cannot verify — git cannot reconcile built commit {s} with HEAD {s} (rebuild and deploy: zig build && zig build deploy-managent)\n", .{ version.commit, head_sha });
                } else if (log_trimmed.len == 0) {
                    w.data("  self-check: CURRENT — no committed change to managent source since this binary was built\n", .{});
                } else {
                    w.data("  self-check: STALE — committed change(s) to managent source since this binary was built ({s} → {s}):\n", .{ version.commit, head_sha });
                    var clog = std.mem.splitScalar(u8, log_trimmed, '\n');
                    while (clog.next()) |cl| {
                        if (cl.len > 0) w.data("      {s}\n", .{cl});
                    }
                    w.data("    rebuild and deploy: zig build && zig build deploy-managent\n", .{});
                }
            }
        }
    }

    // ── kanban (live tasks + held files) ──
    if (live == 0) {
        w.data("\n  kanban: NOTHING IN FLIGHT — no in_progress / dispatchable / blocked tasks\n", .{});
    } else {
        w.data("\n  kanban (live):\n", .{});
        printResumeSection(w, "in_progress", in_progress.items, &state, repo_root);
        printResumeSection(w, "dispatchable", dispatchable.items, &state, repo_root);
        printResumeSection(w, "blocked", blocked.items, &state, repo_root);

        w.data("  held files:\n", .{});
        var held_any = false;
        const buckets = [_][]const []const u8{ in_progress.items, dispatchable.items, blocked.items };
        for (buckets) |ids| {
            for (ids) |tid| {
                const ts = state.get(tid).?;
                for (ts.holds) |h| {
                    held_any = true;
                    w.data("    {s}  (held by {s})\n", .{ h, tid });
                }
            }
        }
        if (!held_any) w.data("    -- none --\n", .{});
    }

    // ── fleet stalls (T364): in_progress rows with no live backing process ─
    // An in_progress row whose runner is gone (or was never seen) is a fleet
    // stall — it belongs where the operator already looks.  The same
    // classification as `managent reap`, read-only.  A row backed by a live
    // runner pid or a fresh heartbeat is NOT a stall; a row with no process
    // evidence is.  Degrades to "-- none --" on a fresh clone (no
    // untracked/runs/, no heartbeat file).
    {
        var ledger_res = readLedgerStatuses(io, state_path);
        defer freeLedgerStatuses(&ledger_res);
        var heartbeats_res = readHeartbeats(w, io, repo_root) catch std.ArrayList(Heartbeat).empty;
        defer {
            for (heartbeats_res.items) |h| {
                alloc.free(h.identifier);
                alloc.free(h.task);
                alloc.free(h.ts);
                alloc.free(h.command);
            }
            heartbeats_res.deinit(alloc);
        }
        const STALL_ORPHAN_MIN: i64 = blk: {
            const override_ptr = std.c.getenv("RESUME_STALL_MIN");
            if (override_ptr) |op| {
                const sp = std.mem.span(op);
                if (std.fmt.parseInt(i64, sp, 10)) |v| break :blk v else |_| {}
            }
            break :blk 5;
        };
        var rows_res = classifyReapRows(w, io, repo_root, &state, &ledger_res, STALL_ORPHAN_MIN * 60, heartbeats_res.items) catch null;
        defer if (rows_res) |*rr| freeReapRows(rr);

        w.data("\n  fleet stalls (in_progress rows with no live process):\n", .{});
        var n_stall: u32 = 0;
        if (rows_res) |rr| {
            for (rr.items) |r| {
                if (!isOrphanReap(r.cls)) continue;
                n_stall += 1;
                w.data("    ! {s}  ORPHAN — {s}\n", .{ r.tid, r.evidence });
            }
        }
        if (n_stall == 0) {
            w.data("    -- none --\n", .{});
        } else {
            w.data("    run `managent reap` to report, `managent reap --close` to close as abandoned.\n", .{});
        }
    }

    // ── pending directives (T352) — a fleet stall is an unread directive ──
    // The resume surface must say so where the operator already looks, with
    // age in minutes so a stale directive reads as stale.  Older than the
    // STALL_THRESHOLD_MIN threshold → flagged as STALL with a louder marker.
    // The threshold is five minutes by default; override with
    // RESUME_STALL_MIN.  This is the operator's signal that `managent tell`
    // is in use and the worker has not yet polled.
    {
        var directives = readDirectives(w, io, repo_root, state_path, null) catch null;
        defer if (directives) |*d| {
            for (d.items) |di| {
                alloc.free(di.id);
                alloc.free(di.target);
                alloc.free(di.directive);
                if (di.note) |n| alloc.free(n);
                alloc.free(di.from);
                alloc.free(di.ts);
                if (di.until_done) |ud| alloc.free(ud);
            }
            d.deinit(alloc);
        };

        var unread: u32 = 0;
        var stale: u32 = 0;
        var ts: std.c.timespec = undefined;
        _ = std.c.clock_gettime(std.c.CLOCK.REALTIME, &ts);
        const now_unix: i64 = ts.sec;
        const STALL_THRESHOLD_MIN: i64 = blk: {
            const override_ptr = std.c.getenv("RESUME_STALL_MIN");
            if (override_ptr) |op| {
                const sp = std.mem.span(op);
                if (std.fmt.parseInt(i64, sp, 10)) |v| break :blk v else |_| {}
            }
            break :blk 5;
        };

        if (directives) |dirs| {
            for (dirs.items) |d| {
                if (d.read) continue;
                unread += 1;
            }
        }

        w.data("\n  pending directives", .{});
        if (unread == 0) {
            w.data(": none\n", .{});
        } else {
            w.data(" ({d} unread", .{unread});
            if (directives) |dirs| {
                for (dirs.items) |d| {
                    if (d.read) continue;
                    if (ageSecFromTs(d.ts, now_unix)) |age_sec| {
                        if (age_sec > STALL_THRESHOLD_MIN * 60) {
                            stale += 1;
                        }
                    }
                }
            }
            if (stale > 0) {
                w.data(", {d} STALL (> {d} min old)", .{ stale, STALL_THRESHOLD_MIN });
            }
            w.data("):\n", .{});
            if (directives) |dirs| {
                for (dirs.items) |d| {
                    if (d.read) continue;
                    const age_str = blk: {
                        if (d.ts.len < 19) break :blk "?";
                        const year = std.fmt.parseInt(i64, d.ts[0..4], 10) catch break :blk "?";
                        const month = std.fmt.parseInt(i64, d.ts[5..7], 10) catch break :blk "?";
                        const day = std.fmt.parseInt(i64, d.ts[8..10], 10) catch break :blk "?";
                        const hour = std.fmt.parseInt(i64, d.ts[11..13], 10) catch break :blk "?";
                        const minute = std.fmt.parseInt(i64, d.ts[14..16], 10) catch break :blk "?";
                        const second = std.fmt.parseInt(i64, d.ts[17..19], 10) catch break :blk "?";
                        // Days-since-epoch (UTC).  Count leap years between
                        // 1970 and the year-1 boundary: a year is a leap
                        // iff divisible by 4, except centuries not by 400.
                        // 1970 itself is not a leap year, and ts represents
                        // 2026-08-01 well past all of them.  Off by ±1
                        // around a leap day — the resume surface treats
                        // these as minutes, not a contract.
                        var leap_count: i64 = 0;
                        var y: i64 = 1970;
                        while (y < year) : (y += 1) {
                            const leap = (@rem(y, 4) == 0 and @rem(y, 100) != 0) or (@rem(y, 400) == 0);
                            if (leap) leap_count += 1;
                        }
                        const month_days_lut = [_]i64{ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
                        var day_of_year: i64 = day - 1;
                        var m: usize = 0;
                        while (m < @as(usize, @intCast(month - 1))) : (m += 1) {
                            day_of_year += month_days_lut[m];
                        }
                        // Add 1 if this is a leap year and we're past Feb.
                        if (month > 2 and ((@rem(year, 4) == 0 and @rem(year, 100) != 0) or (@rem(year, 400) == 0))) {
                            day_of_year += 1;
                        }
                        const days_since_epoch: i64 = (year - 1970) * 365 + leap_count + day_of_year;
                        const ts_unix = days_since_epoch * 86400 + hour * 3600 + minute * 60 + second;
                        const age_sec = now_unix - ts_unix;
                        if (age_sec < 0) break :blk "0m";
                        const age_min: i64 = @divTrunc(age_sec, 60);
                        if (age_min < 60) break :blk std.fmt.allocPrint(alloc, "{d}m", .{age_min}) catch "?";
                        break :blk std.fmt.allocPrint(alloc, "{d}h{d}m", .{ @divTrunc(age_min, 60), @rem(age_min, 60) }) catch "?";
                    };
                    const is_stale = if (ageSecFromTs(d.ts, now_unix)) |age_sec|
                        age_sec > STALL_THRESHOLD_MIN * 60
                    else
                        false;
                    const marker: u8 = if (is_stale) '!' else ' ';
                    w.data("    {c} {s}  {s}  {s}  from {s}  ({s})\n", .{ marker, d.id, d.target, d.directive, d.from, age_str });
                }
            }
        }
    }

    // ── what landed: recent commits ──
    const log_result = runCommand(alloc, io, &.{ "git", "-C", repo_root, "log", "--oneline", "-10" }) catch "";
    defer if (@intFromPtr(log_result.ptr) != @intFromPtr("".ptr)) alloc.free(log_result);
    w.data("\n  recent commits (git log --oneline -10):\n", .{});
    if (std.mem.trim(u8, log_result, " \t\n\r").len == 0) {
        w.data("    -- no commits yet --\n", .{});
    } else {
        var llines = std.mem.splitScalar(u8, log_result, '\n');
        while (llines.next()) |l| {
            if (l.len > 0) w.data("    {s}\n", .{l});
        }
    }

    // ── gate: hook installed? claimlint at floor? ──
    const hooks_result = runCommand(alloc, io, &.{ "git", "-C", repo_root, "config", "core.hooksPath" }) catch "";
    defer if (@intFromPtr(hooks_result.ptr) != @intFromPtr("".ptr)) alloc.free(hooks_result);
    const hooks_trimmed = std.mem.trim(u8, hooks_result, " \t\n\r");
    const gate_installed = std.mem.eql(u8, hooks_trimmed, "tools/hooks");

    const cl = runClaimlintSummary(alloc, io, repo_root);
    const floor = readResumeFloor(io, repo_root);

    w.data("\n  gate:\n", .{});
    if (gate_installed) {
        w.data("    pre-commit hook: INSTALLED (core.hooksPath = tools/hooks)\n", .{});
    } else if (hooks_trimmed.len > 0) {
        w.data("    pre-commit hook: set to '{s}' (not tools/hooks — install: git config core.hooksPath tools/hooks)\n", .{hooks_trimmed});
    } else {
        w.data("    pre-commit hook: NOT INSTALLED (core.hooksPath unset — install: git config core.hooksPath tools/hooks)\n", .{});
    }

    if (!cl.ran) {
        w.data("    claimlint: unavailable (bin/weizigo-claimlint not built or failed to run — build: zig build)\n", .{});
    } else {
        w.data("    claimlint: ", .{});
        if (cl.c1a) |v| w.data("C1a={d} ", .{v}) else w.data("C1a=? ", .{});
        if (cl.c1b) |v| w.data("C1b={d} ", .{v}) else w.data("C1b=? ", .{});
        if (cl.c2) |v| w.data("C2={d} ", .{v}) else w.data("C2=? ", .{});
        if (cl.c6) |v| w.data("C6={d} ", .{v}) else w.data("C6=? ", .{});
        w.data("calibration={s}\n", .{if (cl.calibration_pass) "PASS" else "FAIL/unparsed"});
        if (floor) |f| {
            if (cl.c1a != null and cl.c1b != null and cl.c2 != null and cl.c6 != null) {
                const at_floor = cl.c1a.? <= @as(u64, @intCast(f.c1a)) and
                    cl.c1b.? <= @as(u64, @intCast(f.c1b)) and
                    cl.c2.? <= @as(u64, @intCast(f.c2)) and
                    cl.c6.? <= @as(u64, @intCast(f.c6));
                w.data("    floor: C1a={d} C1b={d} C2={d} C6={d} — {s}\n", .{
                    f.c1a, f.c1b, f.c2, f.c6,
                    if (at_floor) "at or below floor" else "ABOVE FLOOR — register regressed",
                });
            } else {
                w.data("    floor: unparseable from claimlint summary\n", .{});
            }
        } else {
            w.data("    floor: tools/hooks/claimlint-floor.json unreadable\n", .{});
        }
    }
    // zig build status is deliberately NOT run: the full suite (incl. the
    // stratified sweeps and the pre-commit regression) is minutes, not
    // milliseconds — a resume surface that costs a suite-run to compose is not
    // a resume surface. The reader is told to run it themselves. (resume-surface.md)
    w.data("    zig build test: NOT RUN here (minutes of sweeps; run `zig build test` yourself)\n", .{});

    // ── narrative headline, by reference ──
    w.data("\n  narrative (by reference — the prose is not copied here):\n", .{});
    scanChannelState(w, io, repo_root);

    // ── working tree (dirty counts computed in the self block above) ──
    w.data("\n  tree: ", .{});
    if (ts_tree.nonkanban == 0) {
        w.data("clean", .{});
        if (ts_tree.total > 0) w.data(" (only kanban-store writes: {d} file(s))", .{ts_tree.total});
        w.data("\n", .{});
    } else {
        w.data("{d} file(s) changed outside the kanban store ({d} total dirty)\n", .{ ts_tree.nonkanban, ts_tree.total });
    }

    // ── verdict (null control: an empty surface says so explicitly) ──
    w.data("\n  verdict: ", .{});
    if (live == 0 and ts_tree.nonkanban == 0) {
        w.data("NOTHING IN FLIGHT and the working tree is clean — nothing to resume.\n", .{});
        w.data("  durable overview: docs/epistemic/PROGRESS.md (hub) · docs/epistemic/CLAIMS.md (register)\n", .{});
    } else {
        w.data("{d} live task(s)", .{live});
        if (ts_tree.nonkanban > 0) w.data(", {d} uncommitted file(s) outside the kanban store", .{ts_tree.nonkanban});
        w.data(" — resume where you left off.\n", .{});
        w.data("  durable: docs/epistemic/PROGRESS.md (hub) · docs/epistemic/CLAIMS.md (register)\n", .{});
    }
    w.data("\n", .{});
}

// `managent orient` (T353) composes the worker preamble at read time — a
// generated, ≤150-line surface that replaces the ~1,524-line reading list a
// worker otherwise wades through before its own brief (AGENTS.md + DELEGATEE.md
// + sprint.md + DIRECTION.md + WAYPOINTS.md + STATE.md). It follows the `resume`
// pattern: nothing is stored, nothing can rot — the surface IS the sources,
// read at the instant of invocation.
//
// Order (per the brief): principles → current gates → kanban (dispatchable /
// in-progress with liveness / blocked with what blocks them) → fresh activity
// (git log) → handover head (by reference, not copied) → what it does NOT
// replace. The line count is stated at the end so the cap is visible; a
// surface over 150 lines fails its own test and warns on stderr.
//
// Principles are EXTRACTED from the existing documents, not invented: each is
// a one-line imperative restatement of a rule that already lives in AGENTS.md,
// DELEGATEE.md, sprint.md or DIRECTION.md. Adding policy here would be the
// exact hand-maintained diary STATE.md became.
fn cmdOrient(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    _ = args;

    var state = try readState(io, state_path);
    defer freeState(&state);
    var ledger = readLedgerStatuses(io, state_path);
    defer freeLedgerStatuses(&ledger);
    // T716: the lanes census needs the archive too (an archived row is not an
    // orphan); a corrupt archive degrades to empty here so orient never dies
    // on a store the census cannot read.
    const archive_path_o = try std.fs.path.join(alloc, &.{ repo_root, "docs", "infra", "managent", "archive.json" });
    defer alloc.free(archive_path_o);
    var archive_o = readState(io, archive_path_o) catch StateMap{};
    defer freeState(&archive_o);

    const now = try nowTimestamp();
    defer alloc.free(now);

    var in_progress = std.ArrayList([]const u8).empty;
    defer in_progress.deinit(alloc);
    var dispatchable = std.ArrayList([]const u8).empty;
    defer dispatchable.deinit(alloc);
    var blocked = std.ArrayList([]const u8).empty;
    defer blocked.deinit(alloc);
    {
        var it = state.iterator();
        while (it.next()) |entry| {
            const tid = entry.key_ptr.*;
            const ts = entry.value_ptr.*;
            switch (resolveStatus(&state, ts, &ledger, tid).status) {
                .in_progress => try in_progress.append(alloc, tid),
                .dispatchable => try dispatchable.append(alloc, tid),
                .blocked => try blocked.append(alloc, tid),
                else => {},
            }
        }
    }
    const sortFn = struct {
        fn lt(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lt;
    std.mem.sort([]const u8, in_progress.items, {}, sortFn);
    std.mem.sort([]const u8, dispatchable.items, {}, sortFn);
    std.mem.sort([]const u8, blocked.items, {}, sortFn);

    // Heartbeats power the in-progress liveness label (beating / stalled /
    // UNKNOWN). Degrades to an empty list when untracked/heartbeat.jsonl is
    // absent (fresh clone) — every in_progress row then reads UNKNOWN.
    var heartbeats = readHeartbeats(w, io, repo_root) catch std.ArrayList(Heartbeat).empty;
    defer {
        for (heartbeats.items) |h| {
            alloc.free(h.identifier);
            alloc.free(h.task);
            alloc.free(h.ts);
            alloc.free(h.command);
        }
        heartbeats.deinit(alloc);
    }

    var now_tp: std.c.timespec = undefined;
    _ = std.c.clock_gettime(std.c.CLOCK.REALTIME, &now_tp);
    const now_unix: i64 = now_tp.sec;
    const stale_secs: i64 = 5 * 60;

    // Build the surface into a buffer so the line count can be stated and the
    // 150-line cap checked before anything reaches stdout.
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(alloc);
    const Surface = struct {
        b: *std.ArrayList(u8),
        fn p(self: @This(), comptime fmt: []const u8, a: anytype) void {
            const s = std.fmt.allocPrint(alloc, fmt, a) catch return;
            defer alloc.free(s);
            self.b.appendSlice(alloc, s) catch {};
        }
    };
    const o = Surface{ .b = &buf };

    o.p("=== managent orient — generated worker preamble (≤150 lines) ===\n", .{});
    o.p("composed {s} from tasks.json · git · claimlint · floor\n", .{now});
    o.p("self: built from {s}{s} (zig {s})\n", .{ version.commit, if (version.dirty) "-dirty" else "", version.zig_version });

    // ── principles (extracted, one line each) ──
    o.p("\n## principles (extracted from AGENTS.md / DELEGATEE.md / sprint.md / DIRECTION.md)\n", .{});
    o.p("1. Commit → deploy → smoke for every mutating commit, before anything else touches the store.\n", .{});
    o.p("2. One writer per engine file; declare via kanban holds= and clear when done.\n", .{});
    o.p("3. The claimlint floor never rises; a regression moves it down or is reverted.\n", .{});
    o.p("4. Instruments over documents — a checker ships a known-good it passes and a known-bad it catches.\n", .{});
    o.p("5. Both findings deliverables: findings/<id>-<slug>.json (schema) + findings/<id>-context.json (dump).\n", .{});
    o.p("6. Canonical model labels only — one spelling per model (src/managent/main.zig canonical_models).\n", .{});
    o.p("7. Never ask a model to introspect its own kind; workers are task IDs, seats are roles.\n", .{});
    o.p("8. Mutation is serial per held file; analysis is parallel and unlimited.\n", .{});

    // ── current gates (floor + live claimlint) ──
    o.p("\n## gates (live)\n", .{});
    const hooks_result = runCommand(alloc, io, &.{ "git", "-C", repo_root, "config", "core.hooksPath" }) catch "";
    defer if (@intFromPtr(hooks_result.ptr) != @intFromPtr("".ptr)) alloc.free(hooks_result);
    const hooks_trimmed = std.mem.trim(u8, hooks_result, " \t\n\r");
    if (std.mem.eql(u8, hooks_trimmed, "tools/hooks")) {
        o.p("pre-commit hook: INSTALLED (core.hooksPath = tools/hooks)\n", .{});
    } else if (hooks_trimmed.len > 0) {
        o.p("pre-commit hook: '{s}' (not tools/hooks — install: git config core.hooksPath tools/hooks)\n", .{hooks_trimmed});
    } else {
        o.p("pre-commit hook: NOT INSTALLED (install: git config core.hooksPath tools/hooks)\n", .{});
    }
    const cl = runClaimlintSummary(alloc, io, repo_root);
    const floor = readResumeFloor(io, repo_root);
    if (!cl.ran) {
        o.p("claimlint: unavailable (bin/weizigo-claimlint not built — build: zig build)\n", .{});
    } else {
        o.p("claimlint: ", .{});
        if (cl.c1a) |v| o.p("C1a={d} ", .{v}) else o.p("C1a=? ", .{});
        if (cl.c1b) |v| o.p("C1b={d} ", .{v}) else o.p("C1b=? ", .{});
        if (cl.c2) |v| o.p("C2={d} ", .{v}) else o.p("C2=? ", .{});
        if (cl.c6) |v| o.p("C6={d} ", .{v}) else o.p("C6=? ", .{});
        o.p("calibration={s}\n", .{if (cl.calibration_pass) "PASS" else "FAIL/unparsed"});
    }
    if (floor) |f| {
        o.p("floor: C1a={d} C1b={d} C2={d} C6={d}\n", .{ f.c1a, f.c1b, f.c2, f.c6 });
    } else {
        o.p("floor: tools/hooks/claimlint-floor.json unreadable\n", .{});
    }
    // T716: an unregistered finding is an ID that exists without a row (the
    // class that killed T674–T695); surface the count here so a worker sees
    // the drift in the preamble it reads at dispatch.
    var lanes_opt = scanLanes(w, io, repo_root, &state, &archive_o) catch null;
    if (lanes_opt) |*lc| {
        defer lc.deinit();
        o.p("lanes: {d} unregistered finding(s), {d} missing-finding row(s)\n", .{ lc.unregistered.items.len, lc.missing.items.len });
    }

    // ── kanban (dispatchable / in-progress with liveness / blocked) ──
    o.p("\n## kanban (live)\n", .{});
    o.p("in progress ({d}):\n", .{in_progress.items.len});
    if (in_progress.items.len == 0) {
        o.p("  -- none --\n", .{});
    }
    for (in_progress.items) |tid| {
        const ts = state.get(tid).?;
        const rel = bundleRel(ts.bundle, repo_root);
        const ident = agentIdentifier(ts, tid) catch tid;
        var latest: ?Heartbeat = null;
        for (heartbeats.items) |h| {
            if (std.mem.eql(u8, h.task, tid)) {
                if (latest == null or std.mem.lessThan(u8, (latest.?).ts, h.ts)) latest = h;
            }
        }
        const live_label = blk: {
            if (latest) |hb| {
                if (ageSecFromTs(hb.ts, now_unix)) |age| {
                    if (age <= stale_secs) break :blk "beating";
                    break :blk "stalled";
                }
                break :blk "?";
            }
            break :blk "UNKNOWN";
        };
        o.p("  {s}  ({s}) [{s}] — {s}\n", .{ tid, ident, live_label, rel });
    }
    o.p("dispatchable ({d}):\n", .{dispatchable.items.len});
    if (dispatchable.items.len == 0) {
        o.p("  -- none --\n", .{});
    }
    for (dispatchable.items) |tid| {
        const ts = state.get(tid).?;
        const rel = bundleRel(ts.bundle, repo_root);
        o.p("  {s} [set {c}] — {s}\n", .{ tid, ts.set, rel });
    }
    o.p("blocked ({d}):\n", .{blocked.items.len});
    if (blocked.items.len == 0) {
        o.p("  -- none --\n", .{});
    }
    for (blocked.items) |tid| {
        const ts = state.get(tid).?;
        const rel = bundleRel(ts.bundle, repo_root);
        o.p("  {s} [set {c}] needs", .{ tid, ts.set });
        for (ts.needs) |n| o.p(" {s}", .{n});
        o.p(" — {s}\n", .{rel});
    }

    // ── fresh activity (last commits, with task IDs from the subjects) ──
    o.p("\n## fresh activity (git log --oneline -10)\n", .{});
    const log_result = runCommand(alloc, io, &.{ "git", "-C", repo_root, "log", "--oneline", "-10" }) catch "";
    defer if (@intFromPtr(log_result.ptr) != @intFromPtr("".ptr)) alloc.free(log_result);
    if (std.mem.trim(u8, log_result, " \t\n\r").len == 0) {
        o.p("  -- no commits yet --\n", .{});
    } else {
        var ll = std.mem.splitScalar(u8, log_result, '\n');
        while (ll.next()) |l| {
            if (l.len > 0) o.p("  {s}\n", .{l});
        }
    }

    // ── handover head (by reference — the prose is not copied here) ──
    o.p("\n## handover head (by reference — not copied here)\n", .{});
    o.p("  run `bin/managent resume` for the one-page status.\n", .{});
    o.p("  durable: docs/epistemic/PROGRESS.md (hub) · docs/epistemic/CLAIMS.md (register)\n", .{});

    // ── what this does NOT replace ──
    o.p("\n## what this does NOT replace\n", .{});
    o.p("  - your row's own brief (the bundle file your dispatch named)\n", .{});
    o.p("  - the sprint's ratified spec/plan (docs/infra/sprint.md + its plan)\n", .{});

    // Line count: count newlines in the pre-footer buffer, then the footer is
    // one line, so the reported total equals the actual newline count of the
    // emitted buffer (a `wc -l` on the output agrees with the stated number).
    var pre_lines: usize = 0;
    for (buf.items) |c| if (c == '\n') {
        pre_lines += 1;
    };
    // The footer is "\n{N} lines\n" — a blank separator line plus the
    // count line — so it adds two newlines. The reported total therefore
    // equals the actual newline count of the emitted buffer (a `wc -l` on
    // the output agrees with the stated number).
    const total = pre_lines + 2;
    o.p("\n{d} lines\n", .{total});

    std.Io.File.stdout().writeStreamingAll(io, buf.items) catch {};
    if (total > 150) {
        w.diag("orient: WARNING — surface is {d} lines, exceeds the 150-line cap (T353)\n", .{total});
    }
}

fn cmdNext(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    const exec_prefix = getFlagValue(args, "--exec");

    // T337: lock → re-read → modify → writeStateLocked → unlock
    try lockStore(io, state_path);
    defer unlockStore();
    var state = try readState(io, state_path);

    // T446: `next` consults the assertion ledger — a row whose latest
    // assertion is `closed` is finished and must never be handed out, even
    // though tasks.json still stores it as dispatchable.
    var ledger = readLedgerStatuses(io, state_path);
    defer freeLedgerStatuses(&ledger);

    var candidate_id: ?[]const u8 = null;

    var it = state.iterator();
    while (it.next()) |entry| {
        const ts = entry.value_ptr.*;
        // T478: a duty must never be handed out by next in place of a task.
        if (ts.duty) continue;
        // T464: ONE status resolver — a closed assertion is not dispatchable,
        // and a dispatchable assertion re-queues a stored-in_progress row.
        if (resolveStatus(&state, ts, &ledger, entry.key_ptr.*).status != .dispatchable) continue;
        if (phaseGate(state, ts.set)) continue;
        if (holdsConflict(state, effectiveHolds(w, io, repo_root, entry.key_ptr.*, ts), entry.key_ptr.*) != null) continue;
        candidate_id = entry.key_ptr.*;
        break;
    }

    if (candidate_id == null) return;

    const id = candidate_id.?;
    const ts_ptr = state.getPtr(id).?;

    const now = try nowTimestamp();
    ts_ptr.status = .in_progress;
    // T209: use model stored at suggest/dispatch time as agent
    ts_ptr.agent = if (ts_ptr.model) |m| try alloc.dupe(u8, m) else null;
    ts_ptr.claimed = now;
    ts_ptr.claim_count += 1;

    try writeStateLocked(io, state_path, &state);

    const ident = try agentIdentifier(ts_ptr.*, id);
    w.diag("\n  claimed {s}  [set: {c}]  [{s}]\n", .{ id, ts_ptr.set, ident });
    w.diag("  follow {s}\n", .{ts_ptr.bundle});

    if (exec_prefix) |prefix| {
        const rel = bundleRel(ts_ptr.bundle, repo_root);
        try execHarness(prefix, rel);
    }
}

fn cmdShow(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    _ = repo_root; // T518: the assertion ledger is now derived from state_path.
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

    // T497: the assertion ledger is an annotation (history) only — it never
    // overrides the kanban-store status shown on the first line below.
    var ledger = readLedgerStatuses(io, state_path);
    defer freeLedgerStatuses(&ledger);

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
    if (ts.model) |m| {
        w.data("    model:    {s}\n", .{m});
    }
    if (ts.model_source) |ms| {
        w.data("    model_source: {s}\n", .{ms});
    }
    if (ts.model_unknown_reason) |mur| {
        w.data("    model_unknown_reason: {s}\n", .{mur});
    }
    if (ts.method) |m| {
        w.data("    method:   {s}\n", .{m});
    }
    if (ts.candidates.len > 0) {
        w.data("    candidates:", .{});
        for (ts.candidates) |c| w.data(" {s}", .{c});
        w.data("\n", .{});
    }
    if (ts.assign_reasons.len > 0) {
        w.data("    assign_reasons ({d}):\n", .{ts.assign_reasons.len});
        for (ts.assign_reasons) |r| {
            w.data("      {s}\n", .{r});
        }
    }
    if (ts.shape) |sh| {
        w.data("    shape:    {s}\n", .{sh});
    }
    if (ts.shape_reasons.len > 0) {
        w.data("    shape_reasons ({d}):\n", .{ts.shape_reasons.len});
        for (ts.shape_reasons) |r| {
            w.data("      {s}\n", .{r});
        }
    }
    if (ts.agent) |_| {
        const ident = try agentIdentifier(ts, id);
        w.data("    identifier: {s}\n", .{ident});
    } else {
        w.data("    identifier: unknown/{s}\n", .{id});
    }
    if (ts.note) |nt| {
        w.data("    note:     {s}\n", .{nt});
    }
    if (ts.verdict) |v| {
        w.data("    verdict:  {s}\n", .{v});
    }
    if (ts.verdict_note) |vn| {
        w.data("    verdict_note: {s}\n", .{vn});
    }
    if (ts.impression) |im| {
        w.data("    impression: {s}\n", .{im});
    }
    if (ts.impression_waiver) |iw| {
        w.data("    impression_waiver: {s}\n", .{iw});
    }
    // T497: the latest assertion (if any) renders as a history annotation —
    // it never overrides the kanban-store status on the first line.
    if (ledger.get(id)) |ls| {
        w.data("    assertion: {s} — {s}", .{ ls.assertion_id, ls.status_value });
        if (ls.ts.len > 0) w.data(", {s}", .{ls.ts});
        if (ls.note.len > 0) {
            const shown = utf8Truncate(ls.note, 80);
            w.data(" — {s}", .{shown});
            if (ls.note.len > 80) w.data("…", .{});
        }
        w.data("\n", .{});
    }
    if (ts.acceptance) |ac| {
        w.data("    acceptance: {s}\n", .{ac});
    }
    if (ts.skip_acceptance_reason) |sr| {
        w.data("    skip_acceptance_reason: {s}\n", .{sr});
    }
    // T627: dispatch scope fields — null renders UNKNOWN, never 0/"none".
    if (ts.brief_bytes) |b| {
        w.data("    brief_bytes: {d}\n", .{b});
    } else {
        w.data("    brief_bytes: UNKNOWN\n", .{});
    }
    if (ts.files_in_scope) |f| {
        w.data("    files_in_scope: {d}\n", .{f});
    } else {
        w.data("    files_in_scope: UNKNOWN\n", .{});
    }
    if (ts.expected_wall_s) |e| {
        w.data("    expected_wall_s: {d}\n", .{e});
    } else {
        w.data("    expected_wall_s: UNKNOWN\n", .{});
    }
    if (ts.scope_enumerable) |se| {
        if (se) {
            w.data("    scope: enumerated ({d} targets)", .{ts.scope_targets.len});
            for (ts.scope_targets) |t| w.data(" {s}", .{t});
            w.data("\n", .{});
        } else {
            w.data("    scope: unenumerable", .{});
            if (ts.scope_note) |sn| w.data(" — {s}", .{sn});
            w.data("\n", .{});
        }
    } else {
        w.data("    scope: UNKNOWN\n", .{});
    }
    if (ts.amendments.len > 0) {
        w.data("    amendments ({d}):\n", .{ts.amendments.len});
        for (ts.amendments) |am| {
            w.data("      {s}\n", .{am});
        }
    }
    if (ts.duty) {
        const since = closesSinceChunk(ts);
        w.data("    duty:     yes (due after {d} closes; {d} since chunk)\n", .{ ts.due_after, since });
        if (ts.last_chunk_ts) |t| {
            w.data("    last_chunk: {s}", .{t});
            if (ts.last_chunk_verdict) |v| w.data(" verdict={s}", .{v});
            if (ts.last_chunk_findings) |f| w.data(" findings={s}", .{f});
            w.data("\n", .{});
        }
    }
    w.data("\n", .{});
}

fn cmdWhoami(w: Writers, io: std.Io, state_path: []const u8, args: [][]const u8) !void {
    if (args.len < 3) {
        w.diag("usage: managent whoami <id>\n", .{});
        std.process.exit(1);
    }
    const id = args[2];

    var state = try readState(io, state_path);
    defer freeState(&state);

    const ts = state.get(id) orelse {
        w.diag("error: task '{s}' not found\n", .{id});
        std.process.exit(1);
    };

    if (ts.agent == null) {
        w.diag("  unknown/{s}  (agent unset — claim with --agent <model> to set one)\n", .{id});
        return;
    }

    const ident = try agentIdentifier(ts, id);
    w.data("{s}\n", .{ident});
}

// ── T517: canonical model list — the single source of truth ───────────────
// Exposes canonical_models[] as a queryable verb so the keeper (and dispatch,
// subagent, watch-fleet) can `managent models` / `managent models --json`
// instead of maintaining a second copy that drifts (F7 measured four
// definitions).  Pure static: no kanban store read, no migration — main()
// short-circuits this verb before the migration block, so it is safe to call
// with no store at all (MANAGENT_STORE may point at a nonexistent path).
fn cmdModels(w: Writers, args: [][]const u8) !void {
    const use_json = hasFlag(args, "--json");
    const use_tags = hasFlag(args, "--tags");
    if (use_tags) {
        // T801: `models --tags` is the full canonicalizer export — canonical
        // list + the :cloud strip suffix + the serving-tag map — as one JSON
        // object.  This is the surface the Python readers cache so the
        // transform is RESOLVED from this single source, never reimplemented.
        if (!use_json) {
            w.diag("usage: managent models --tags --json\n", .{});
            std.process.exit(2);
        }
        try cmdModelsTagsJson(w);
    } else if (use_json) {
        // One JSON array, canonical order, machine-readable.  Labels carry
        // only [a-z0-9.:-] but go through writeJsonString for the project's
        // own discipline (every JSON string is escaped, no raw quotes).
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(alloc);
        try buf.append(alloc, '[');
        for (canonical_models, 0..) |m, i| {
            if (i > 0) try buf.append(alloc, ',');
            try writeJsonString(&buf, m);
        }
        try buf.append(alloc, ']');
        try buf.append(alloc, '\n');
        w.data("{s}", .{buf.items});
    } else {
        // One label per line — the shape `while read m` consumes.
        for (canonical_models) |m| {
            w.data("{s}\n", .{m});
        }
    }
}

/// `managent models --tags --json`: one JSON object carrying everything a
/// reader needs to apply the canonicalizer exactly as this binary does.
fn cmdModelsTagsJson(w: Writers) !void {
    var buf: std.ArrayList(u8) = .empty;
    defer buf.deinit(alloc);
    try buf.append(alloc, '{');
    try writeJsonString(&buf, "canonical_models");
    try buf.append(alloc, ':');
    try buf.append(alloc, '[');
    for (canonical_models, 0..) |m, i| {
        if (i > 0) try buf.append(alloc, ',');
        try writeJsonString(&buf, m);
    }
    try buf.append(alloc, ']');
    try buf.append(alloc, ',');
    try writeJsonString(&buf, "strip_suffix");
    try buf.append(alloc, ':');
    try writeJsonString(&buf, serving_tag_strip_suffix);
    try buf.append(alloc, ',');
    try writeJsonString(&buf, "serving_tags");
    try buf.append(alloc, ':');
    try buf.append(alloc, '{');
    for (serving_tag_map, 0..) |m, i| {
        if (i > 0) try buf.append(alloc, ',');
        try writeJsonString(&buf, m.serving);
        try buf.append(alloc, ':');
        try writeJsonString(&buf, m.canonical);
    }
    try buf.append(alloc, '}');
    try buf.append(alloc, '}');
    try buf.append(alloc, '\n');
    w.data("{s}", .{buf.items});
}

/// `managent canonicalize <tag>`: the strict boundary — resolve a raw
/// dispatch tag to its canonical label, or reject it (exit 1) so "unknown
/// label" and "canonical label" are never the same value (T801).
fn cmdCanonicalize(w: Writers, args: [][]const u8) !void {
    if (args.len < 3) {
        w.diag("usage: managent canonicalize <tag>\n", .{});
        std.process.exit(2);
    }
    const raw = args[2];
    const canon = canonicalizeModelTag(raw);
    if (!isCanonicalModel(canon)) {
        w.diag("error: '{s}' is not a recognized model tag (canonicalized to '{s}')\n", .{ raw, canon });
        printCanonicalModels(w);
        std.process.exit(1);
    }
    w.data("{s}\n", .{canon});
}

// ── T635: mechanized model assignment verb ─────────────────────────────────
// `managent assign <id>` filters the canonical models by the constraints that
// apply (family appetite, row-declared exclusions) and draws the row's model
// from the qualified list with OS entropy, recording `candidates`, `method`,
// and the draw on the row.  `--model <name>` forces `preferred`; `--exclude
// <tokens>` adds exclusions; `--dry-run` computes without writing; `--json`
// emits the result as one JSON object on stdout.
fn cmdAssign(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    if (args.len < 3) {
        w.diag("usage: managent assign <id> [--model <name>] [--exclude <tokens>] [--seats <models>] [--dry-run] [--json]\n", .{});
        std.process.exit(1);
    }
    const id = args[2];
    const dry_run = hasFlag(args, "--dry-run");
    const use_json = hasFlag(args, "--json");

    // --model names the outcome; it must be a canonical label (preferred).
    var requested: ?[]const u8 = null;
    if (getFlagValue(args, "--model")) |m| {
        const canon = canonicalizeModelTag(m);
        if (!isCanonicalModel(canon)) {
            w.diag("error: '{s}' is not a canonical model label.\n", .{m});
            printCanonicalModels(w);
            std.process.exit(1);
        }
        requested = canon;
    }

    // T337: lock → re-read → modify → writeStateLocked → unlock.
    try lockStore(io, state_path);
    defer unlockStore();
    var state = try readState(io, state_path);

    // T772: D027 least-data census over the live kanban (task count per
    // canonical model) — the tie-break among §5-qualified models.
    var counts = try taskCountsByModel(&state);
    defer freeDataCounts(&counts);

    const ts_ptr = state.getPtr(id) orelse {
        w.diag("error: task '{s}' not found\n", .{id});
        std.process.exit(1);
    };

    // T636: the row's shape decides the pick (null = legacy T635 draw).
    const shape: ?RowShape = if (ts_ptr.shape) |sh| parseShape(sh) else null;

    // T636: --seats names already-seated models for a panel row (greedy
    // marginal complementarity given the seats already filled).
    var seats = std.ArrayList([]const u8).empty;
    defer {
        for (seats.items) |s| alloc.free(s);
        seats.deinit(alloc);
    }
    if (getFlagValue(args, "--seats")) |sv| {
        const parsed = try parseHoldsList(sv);
        defer {
            for (parsed) |s| alloc.free(s);
            alloc.free(parsed);
        }
        for (parsed) |s| {
            const canon = canonicalizeModelTag(s);
            if (!isCanonicalModel(canon)) {
                w.diag("error: '{s}' is not a canonical model label (--seats).\n", .{s});
                printCanonicalModels(w);
                std.process.exit(1);
            }
            try seats.append(alloc, try alloc.dupe(u8, canon));
        }
    }

    // Exclusions: the row's bundle `exclude=` (soft) plus any --exclude flag.
    var exclusions = std.ArrayList([]const u8).empty;
    defer {
        for (exclusions.items) |e| alloc.free(e);
        exclusions.deinit(alloc);
    }
    if (bundleAbsFor(io, repo_root, id, ts_ptr.bundle)) |bundle_abs| {
        if (readBundleExclusions(io, bundle_abs)) |decl| {
            defer {
                for (decl) |d| alloc.free(d);
                alloc.free(decl);
            }
            // Copy out of `decl` — its elements are freed by the defer above.
            for (decl) |d| try exclusions.append(alloc, try alloc.dupe(u8, d));
        }
    }
    if (getFlagValue(args, "--exclude")) |ex| {
        var split = std.mem.splitScalar(u8, ex, ',');
        while (split.next()) |t| {
            const trimmed = std.mem.trim(u8, t, " \t");
            if (trimmed.len > 0) try exclusions.append(alloc, try alloc.dupe(u8, trimmed));
        }
    }

    // Draw with OS entropy (ruling 33: never a seeded PRNG, never clock/task).
    var os = OsEntropy{ .io = io };
    const rng = std.Random.init(&os, OsEntropy.fill);
    var result = selectForShape(shape, requested, exclusions.items, seats.items, &counts, rng, io, repo_root) catch |err| {
        if (err == error.NoQualifiedCandidate) {
            if (use_json) {
                w.data("{{\"id\":\"{s}\",\"error\":\"no-qualified-candidate\",\"candidates\":[],\"reasons\":[]}}\n", .{id});
            } else {
                w.data("method=none\nmodel=\ncandidates=\nreasons=no qualified candidate (all canonical models excluded)\n", .{});
            }
            w.diag("  error: no qualified candidate for {s} (all canonical models excluded)\n", .{id});
            std.process.exit(1);
        }
        if (err == error.PanelFull) {
            if (use_json) {
                w.data("{{\"id\":\"{s}\",\"error\":\"panel-full\",\"candidates\":[],\"reasons\":[]}}\n", .{id});
            } else {
                w.data("method=none\nmodel=\ncandidates=\nreasons=panel full: no qualified candidate adds a unique catch given the seats already filled\n", .{});
            }
            w.diag("  error: panel full for {s} — no qualified candidate adds a unique catch (diminishing returns)\n", .{id});
            std.process.exit(1);
        }
        return err;
    };
    defer freeAssignResult(&result);

    // Record on the row (unless dry-run).
    if (!dry_run) {
        try setAssignmentOnTask(ts_ptr, &result);
        try writeStateLocked(io, state_path, &state);
    }

    // stdout = data (parseable result / JSON); stderr = diagnostics.
    if (use_json) {
        var buf: std.ArrayList(u8) = .empty;
        defer buf.deinit(alloc);
        try buf.appendSlice(alloc, "{\"id\":");
        try writeJsonString(&buf, id);
        try buf.appendSlice(alloc, ",\"method\":");
        try writeJsonString(&buf, result.method);
        try buf.appendSlice(alloc, ",\"model\":");
        try writeJsonString(&buf, result.model);
        try buf.appendSlice(alloc, ",\"candidates\":[");
        for (result.candidates, 0..) |c, ci| {
            if (ci > 0) try buf.appendSlice(alloc, ",");
            try writeJsonString(&buf, c);
        }
        try buf.appendSlice(alloc, "],\"reasons\":[");
        for (result.reasons, 0..) |r, ri| {
            if (ri > 0) try buf.appendSlice(alloc, ",");
            try writeJsonString(&buf, r);
        }
        try buf.appendSlice(alloc, "]");
        try buf.appendSlice(alloc, ",\"shape_reasons\":[");
        for (result.shape_reasons, 0..) |r, ri| {
            if (ri > 0) try buf.appendSlice(alloc, ",");
            try writeJsonString(&buf, r);
        }
        try buf.appendSlice(alloc, "]");
        if (shape) |sh| {
            try buf.appendSlice(alloc, ",\"shape\":");
            try writeJsonString(&buf, shapeName(sh));
        }
        if (dry_run) try buf.appendSlice(alloc, ",\"dry_run\":true");
        try buf.appendSlice(alloc, "}\n");
        w.data("{s}", .{buf.items});
    } else {
        w.data("method={s}\n", .{result.method});
        w.data("model={s}\n", .{result.model});
        w.data("candidates=", .{});
        for (result.candidates, 0..) |c, ci| {
            if (ci > 0) w.data(",", .{});
            w.data("{s}", .{c});
        }
        w.data("\nreasons=", .{});
        for (result.reasons, 0..) |r, ri| {
            if (ri > 0) w.data("|", .{});
            w.data("{s}", .{r});
        }
        w.data("\n", .{});
        if (shape) |sh| {
            w.data("shape={s}\n", .{shapeName(sh)});
        }
        w.data("shape_reasons=", .{});
        for (result.shape_reasons, 0..) |r, ri| {
            if (ri > 0) w.data("|", .{});
            w.data("{s}", .{r});
        }
        w.data("\n", .{});
    }

    if (dry_run) {
        w.diag("  assign {s} -> {s} [method={s}] (dry run — not recorded)\n", .{ id, result.model, result.method });
    } else {
        w.diag("  assigned {s} -> {s} [method={s}]\n", .{ id, result.model, result.method });
    }
}

// ── T636: row shape — set/amend the shape field (ruling 34) ───────────────
// Registration defaults a new row to solo; this verb amends it.  `shape` is
// what `assign` reads to decide between the solo ladder and panel
// composition.  `shape <id>` (no value) shows the current shape read-only.
fn cmdShape(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    _ = repo_root;
    if (args.len < 3) {
        w.diag("usage: managent shape <id> [solo|panel]\n", .{});
        std.process.exit(1);
    }
    const id = args[2];

    if (args.len < 4) {
        var state = try readState(io, state_path);
        defer freeState(&state);
        const ts = state.get(id) orelse {
            w.diag("error: task '{s}' not found\n", .{id});
            std.process.exit(1);
        };
        if (ts.shape) |sh| {
            w.data("shape: {s}\n", .{sh});
        } else {
            w.data("shape: (none — legacy draw)\n", .{});
        }
        return;
    }

    const value = args[3];
    if (parseShape(value) == null) {
        w.diag("error: invalid shape '{s}' (must be solo or panel)\n", .{value});
        std.process.exit(1);
    }

    // T337: lock → re-read → modify → writeStateLocked → unlock.
    try lockStore(io, state_path);
    defer unlockStore();
    var state = try readState(io, state_path);
    const ts_ptr = state.getPtr(id) orelse {
        w.diag("error: task '{s}' not found\n", .{id});
        std.process.exit(1);
    };
    const old_owned = if (ts_ptr.shape) |s| try alloc.dupe(u8, s) else null;
    defer if (old_owned) |o| alloc.free(o);
    if (ts_ptr.shape) |oldsh| alloc.free(oldsh);
    ts_ptr.shape = try alloc.dupe(u8, value);
    try writeStateLocked(io, state_path, &state);
    w.diag("\n  {s}  shape {s} -> {s}\n", .{ id, old_owned orelse "(none)", value });
}

/// T635: copy a computed assignment onto the row (owning copies so the store
/// survives the result's lifetime).  The outcome is written to `model`, with
/// `model_source` = "assign:<method>" so the provenance of the CHOICE is not
/// mistaken for first-hand attribution (T544) nor for a backfill.
fn setAssignmentOnTask(ts: *TaskState, r: *const AssignResult) !void {
    var cands = std.ArrayList([]const u8).empty;
    for (r.candidates) |c| try cands.append(alloc, try alloc.dupe(u8, c));
    for (ts.candidates) |c| alloc.free(c);
    alloc.free(ts.candidates);
    ts.candidates = try cands.toOwnedSlice(alloc);

    var reas = std.ArrayList([]const u8).empty;
    for (r.reasons) |x| try reas.append(alloc, try alloc.dupe(u8, x));
    for (ts.assign_reasons) |x| alloc.free(x);
    alloc.free(ts.assign_reasons);
    ts.assign_reasons = try reas.toOwnedSlice(alloc);

    // T636: shape-selection notes (empty for the legacy draw).
    var sreas = std.ArrayList([]const u8).empty;
    for (r.shape_reasons) |x| try sreas.append(alloc, try alloc.dupe(u8, x));
    for (ts.shape_reasons) |x| alloc.free(x);
    alloc.free(ts.shape_reasons);
    ts.shape_reasons = try sreas.toOwnedSlice(alloc);

    if (ts.method) |old| alloc.free(old);
    ts.method = try alloc.dupe(u8, r.method);

    if (ts.model) |old| alloc.free(old);
    ts.model = try alloc.dupe(u8, r.model);
    if (ts.model_source) |old| alloc.free(old);
    ts.model_source = try std.fmt.allocPrint(alloc, "assign:{s}", .{r.method});
    if (ts.model_unknown_reason) |old| alloc.free(old);
    ts.model_unknown_reason = null;
}

fn cmdWhy(w: Writers, io: std.Io, state_path: []const u8, args: [][]const u8) !void {
    if (args.len < 3) {
        w.diag("usage: managent why <claim-id>\n", .{});
        std.process.exit(1);
    }
    const claim_id = args[2];

    var state = try readState(io, state_path);
    defer freeState(&state);

    // T319: also search the archive store.
    const state_dir = std.fs.path.dirname(state_path) orelse ".";
    const archive_path = try std.fs.path.join(alloc, &.{ state_dir, "archive.json" });
    defer alloc.free(archive_path);
    var archive_state = readState(io, archive_path) catch StateMap{};
    defer freeState(&archive_state);

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
        // T319: search the archive store
        var ait = archive_state.iterator();
        while (ait.next()) |aentry| {
            const ts = aentry.value_ptr.*;
            const tid = aentry.key_ptr.*;
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
                w.data("    {s}  [{s}] (archived)", .{ tid, statusToString(ts.status) });
                if (ts.agent) |a| w.data("  agent: {s}", .{a});
                w.data("\n      bundle: {s}\n", .{rel});
                if (ts.done) |d| w.data("      done: {s}\n", .{d});
                if (ts.epitaph) |ep| w.data("      epitaph: {s}\n", .{ep});
            }
        }
    }

    if (!found) {
        w.data("    -- no tasks reference this claim --\n", .{});
    }
    w.data("\n", .{});
}

// ── T478: duty helpers ──────────────────────────────────────────────────────

/// Does the bundle's managent meta header carry a `duty` key?  Scans only the
/// first 50 lines for the `<!--managent ... -->` line (the same window
/// parseBundleMeta uses) and looks for a `duty` token in it.  A missing or
/// unreadable bundle returns false — recognition must fail soft, never crash a
/// read-only command.
fn bundleHasDutyKey(io: std.Io, repo_root: []const u8, bundle: []const u8) bool {
    const abs = if (std.fs.path.isAbsolute(bundle))
        alloc.dupe(u8, bundle) catch return false
    else
        std.fs.path.join(alloc, &.{ repo_root, bundle }) catch return false;
    defer alloc.free(abs);

    const content = std.Io.Dir.cwd().readFileAlloc(io, abs, alloc, .unlimited) catch return false;
    defer alloc.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    var line_count: usize = 0;
    while (lines.next()) |line| : (line_count += 1) {
        if (line_count >= 50) break;
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (!std.mem.startsWith(u8, trimmed, "<!--managent ")) continue;

        var inner = trimmed["<!--managent ".len..];
        if (std.mem.endsWith(u8, inner, "-->")) {
            inner = inner[0 .. inner.len - 3];
        }
        var tokens = std.mem.splitScalar(u8, inner, ' ');
        while (tokens.next()) |token| {
            if (token.len == 0) continue;
            var parts = std.mem.splitScalar(u8, token, '=');
            const key = parts.next() orelse continue;
            if (std.mem.eql(u8, key, "duty")) return true;
        }
        return false;
    }
    return false;
}

/// T478 one-time migration: mark pre-existing duty rows by re-reading their
/// bundle meta headers.  Runs once per store (guarded by _sys.duty_migrated in
/// main); sets the marker regardless of what it found so the scan does not
/// repeat on every load.
fn migrateDutyFlags(io: std.Io, repo_root: []const u8, state: *StateMap) void {
    var it = state.iterator();
    while (it.next()) |entry| {
        const ts = entry.value_ptr;
        if (ts.duty) continue;
        if (bundleHasDutyKey(io, repo_root, ts.bundle)) {
            ts.duty = true;
        }
    }
    sys_duty_migrated = true;
}

/// Closes elapsed since a duty's last chunk (saturating at zero).
fn closesSinceChunk(ts: TaskState) u64 {
    if (sys_closes >= ts.last_chunk_closes) return sys_closes - ts.last_chunk_closes;
    return 0;
}

/// A duty is due once _sys.closes has advanced due_after past its last chunk.
fn dutyIsDue(ts: TaskState) bool {
    return closesSinceChunk(ts) >= ts.due_after;
}

/// A duty whose most recent chunk failed blocks a landmark declaration.
fn dutyLastFailed(ts: TaskState) bool {
    if (ts.last_chunk_verdict) |v| {
        return std.mem.eql(u8, v, "fail");
    }
    return false;
}

// ── T478: duty — record a chunk for a duty (duties never close) ────────────

fn cmdDuty(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    _ = repo_root;
    // managent duty <UID> done --verdict pass|fail --findings <path>
    if (args.len < 4 or !std.mem.eql(u8, args[3], "done")) {
        w.diag("usage: managent duty <UID> done --verdict pass|fail --findings <path>\n", .{});
        w.diag("       records one chunk (date, verdict, findings); a duty never closes.\n", .{});
        std.process.exit(1);
    }
    const uid = args[2];
    const verdict = getFlagValue(args, "--verdict");
    const findings = getFlagValue(args, "--findings");

    if (verdict == null or (!std.mem.eql(u8, verdict.?, "pass") and !std.mem.eql(u8, verdict.?, "fail"))) {
        w.diag("error: --verdict pass|fail is required (the chunk's pass is the landmark gate's input)\n", .{});
        std.process.exit(1);
    }
    if (findings == null or findings.?.len == 0) {
        w.diag("error: --findings <path> is required (evidence must be recorded)\n", .{});
        std.process.exit(1);
    }

    // T337: lock → re-read → modify → writeStateLocked → unlock
    try lockStore(io, state_path);
    defer unlockStore();
    var state = try readState(io, state_path);

    const ts = state.getPtr(uid) orelse {
        w.diag("error: task '{s}' not found\n", .{uid});
        std.process.exit(1);
    };

    if (!ts.duty) {
        w.diag("error: '{s}' is not a duty (no duty flag) — chunks apply only to duties\n", .{uid});
        std.process.exit(1);
    }

    const now = try nowTimestamp();

    if (ts.last_chunk_ts) |v| alloc.free(v);
    if (ts.last_chunk_verdict) |v| alloc.free(v);
    if (ts.last_chunk_findings) |v| alloc.free(v);

    ts.last_chunk_closes = sys_closes;
    ts.last_chunk_ts = try alloc.dupe(u8, now);
    ts.last_chunk_verdict = try alloc.dupe(u8, verdict.?);
    ts.last_chunk_findings = try alloc.dupe(u8, findings.?);

    try writeStateLocked(io, state_path, &state);

    w.diag("\n  chunk recorded for {s}  [verdict: {s}]  [findings: {s}]\n", .{ uid, verdict.?, findings.? });
    w.diag("  due in {d} closes (closes-since-chunk reset to 0)\n", .{ts.due_after});
}

// ── T478: landmark — gate a landmark declaration on duty currency ──────────

fn cmdLandmark(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    _ = repo_root;
    // managent landmark <Ln> --declare
    if (args.len < 4 or !std.mem.eql(u8, args[3], "--declare")) {
        w.diag("usage: managent landmark <Ln> --declare\n", .{});
        w.diag("       refuses while any duty is overdue or its last chunk failed.\n", .{});
        std.process.exit(1);
    }
    const landmark = args[2];

    var state = try readState(io, state_path);
    defer freeState(&state);

    var blocking = std.ArrayList([]const u8).empty;
    defer blocking.deinit(alloc);
    var it = state.iterator();
    while (it.next()) |entry| {
        const ts = entry.value_ptr.*;
        if (!ts.duty) continue;
        if (dutyIsDue(ts) or dutyLastFailed(ts)) {
            try blocking.append(alloc, entry.key_ptr.*);
        }
    }

    std.mem.sort([]const u8, blocking.items, {}, struct {
        fn lt(_: void, a: []const u8, b: []const u8) bool {
            return std.mem.lessThan(u8, a, b);
        }
    }.lt);

    if (blocking.items.len > 0) {
        w.diag("\n  REFUSED: landmark {s} — duties not current:\n", .{landmark});
        for (blocking.items) |bid| {
            const ts = state.get(bid).?;
            if (dutyLastFailed(ts)) {
                w.diag("    {s}: last chunk failed", .{bid});
                if (ts.last_chunk_findings) |f| w.diag(" (findings: {s})", .{f});
                w.diag("\n", .{});
            } else {
                w.diag("    {s}: overdue ({d} closes since chunk, due after {d})\n", .{ bid, closesSinceChunk(ts), ts.due_after });
            }
        }
        std.process.exit(1);
    }

    w.diag("\n  landmark {s} declared (duties current)\n", .{landmark});
}

fn printHelp(w: Writers) void {
    w.diag(
        \\managent — agent-manager CLI
        \\
        \\Usage:
        \\  managent                  show current state (default)
        \\  managent status [--json]  show current state (--json for machine output)
        \\  managent resume           compose the resume surface at read time (replaces CURRENT.md)
        \\  managent add <id>         register a task (with --auto to mint T<N> ID)
        \\  managent suggest <slug>   mint T-ID, create bundle, print dispatch prompt
        \\  managent dispatch <id>    record a human→agent dispatch (task stays dispatchable)
        \\  managent claim <id>       claim a task for execution
        \\  managent done <id>        mark a task complete
        \\  managent done <id> --fail mark a task failed
        \\  managent next             claim the next available task
        \\  managent show <id>        show details for one task
        \\  managent why <claim-id>   show tasks that produced evidence for a claim
        \\  managent sync <role> [--peek]  print unread messages; exit non-zero when write owed; --peek skips _sync write
        \\  managent audit [--json]   cross-check kanban against reality
        \\  managent agent <id> <name> set the agent model for a task
        \\  managent amend <id>        append a correction record (verdict + note) to a done/failed task
        \\  managent amend <id> --post-close <text>  record a follow-up against a done row (verdict untouched)
        \\  managent retire <id> --note <epitaph>  archive a row (any status) with a one-line epitaph (archive, never delete)
        \\  managent models [--json]   print the canonical model list (T317 single source; --json for machine output)
        \\  managent assign <id>       mechanized model assignment (ruling 33; --model/--exclude/--dry-run/--json)
        \\  managent whoami <id>       resolve agent identifier for a task
        \\  managent tell <target>    send a directive to a worker (pause/resume/kill/amend/question)
        \\  managent assert <row> <status> [--note]  assert a row's status to the assertion ledger (T441)
        \\  managent inbox [<target>] [--ack]  show pending directives; --ack marks them as read (T352)
        \\  managent ping [--note]    emit a heartbeat (prove liveness between builds)
        \\  managent liveness [--stale-min <min>]  show per-task liveness: UNKNOWN / beating / beats stopped (default threshold 5 min)
        \\  managent reap [--close]  reconcile in_progress rows vs the process table; --close closes orphans as abandoned (T364)
        \\  managent treekill --anchor <pid> [--kill] [--seed <pids>] [--since <epoch>]  enumerate/kill a process tree (pass 1)
        \\  managent duty <UID> done  record a duty chunk (--verdict pass|fail --findings <path>); duties never close
        \\  managent landmark <Ln> --declare  gate a landmark declaration on duty currency (overdue or last-failed blocks)
        \\  managent standing         register triggered standing-tier tasks
        \\  managent resume           derive the resume surface from tasks.json + git + claimlint + STATE.md
        \\  managent orient           generate the ≤150-line worker preamble (principles + gates + kanban + activity)
        \\  managent lanes            census T-ID ↔ findings drift (unregistered findings / missing-findings rows); --backfill mints+closes the orphans
        \\  managent help             show this help
        \\
        \\Options:
        \\  --agent <name>           label who claimed — sets the model in the identifier (with claim / done)
        \\  --to <agent>             agent the task is dispatched to (with dispatch)
        \\  --note <text>            free-form context, ≤4 KiB (with dispatch / add / retire)
        \\  --impression <text>      model impression required at close (with done); or --impression-waiver <reason>
        \\  --auto                   auto-generate opaque T<N> task ID (with add)
        \\  --bundle <path>          override bundle path (with add)
        \\  --set <A–Z>              override parallel set (with add / suggest)
        \\  --needs <id,...>         add extra dependency, comma-separated (with add)
        \\  --allow-unregistered-needs <reason>  allow a need on a not-yet-registered task (with add; recorded)
        \\  --duty                   register the row as a duty (with add)
        \\  --model <name>           set model for prompt line (with suggest)
        \\  --exec <prefix>          claim and exec into harness (with claim / next)
        \\  --json                   machine-readable output (with status / audit)
        \\  -h, --help               show this help
        \\
        \\Examples:
        \\  managent status --json | jq '.[] | select(.status=="blocked")'
        \\  managent audit 2>/dev/null  # see only discrepancies
        \\  managent whoami 2B-5         # resolve what identifier a task would have
        \\  managent next --exec "pi --provider deepseek --model deepseek-v4-pro"
        \\  managent claim B17 --exec "pi --provider ollama --model glm-5.2:cloud"
        \\\nTest isolation (T427 — T425 leaked 16 fixture rows into the live store):
        \\  MANAGENT_STORE=<path>  run against a scratch store instead of the live kanban
        \\  MANAGENT_TEST=1        refuse every mutating verb on the live store (for harnesses)
        \\  fixture-pattern ids (DOCTOR/FIXTURE/SEED/PROBE/ARM/TEST) are refused on the live store
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
        if (ts.model) |m| alloc.free(m);
        if (ts.model_source) |ms| alloc.free(ms);
        if (ts.model_unknown_reason) |mur| alloc.free(mur);
        for (ts.holds) |h| alloc.free(h);
        alloc.free(ts.holds);
        for (ts.needs) |n| alloc.free(n);
        alloc.free(ts.needs);
        for (ts.caps) |c| alloc.free(c);
        alloc.free(ts.caps);
        for (ts.candidates) |c| alloc.free(c);
        alloc.free(ts.candidates);
        if (ts.method) |m| alloc.free(m);
        for (ts.assign_reasons) |r| alloc.free(r);
        alloc.free(ts.assign_reasons);
        if (ts.shape) |sh| alloc.free(sh);
        for (ts.shape_reasons) |r| alloc.free(r);
        alloc.free(ts.shape_reasons);
        alloc.free(ts.added);
        if (ts.claimed) |c| alloc.free(c);
        if (ts.done) |d| alloc.free(d);
        if (ts.dispatched) |dp| alloc.free(dp);
        if (ts.dispatched_to) |dt| alloc.free(dt);
        if (ts.note) |nt| alloc.free(nt);
        if (ts.verdict) |v| alloc.free(v);
        if (ts.verdict_note) |vn| alloc.free(vn);
        if (ts.impression) |im| alloc.free(im);
        if (ts.impression_waiver) |iw| alloc.free(iw);
        if (ts.acceptance) |ac| alloc.free(ac);
        if (ts.skip_acceptance_reason) |sr| alloc.free(sr);
        for (ts.amendments) |am| alloc.free(am);
        alloc.free(ts.amendments);
        if (ts.epitaph) |ep| alloc.free(ep);
        // T627: scope fields
        for (ts.scope_targets) |t| alloc.free(t);
        alloc.free(ts.scope_targets);
        if (ts.scope_note) |sn| alloc.free(sn);
    }
    state.deinit(alloc);
}

// ═══════════════════════════════════════════════════════════════════════════════
// ORCHA-AUTOMATION new commands
// ═══════════════════════════════════════════════════════════════════════════════

// ── directive store (WORKER-CHANNEL) ─────────────────────────────────────────

const DIRECTIVES_FILE = "docs/infra/managent/directives.jsonl";

// ── assertion ledger (T426/T441) ────────────────────────────────────────────

// T518/F9: the assertion ledger's DEFAULT location, relative to repo_root,
// is `docs/infra/assertion-ledger/assertions.jsonl` — a sibling of the
// default store (`docs/infra/managent/tasks.json`).  The actual path is now
// derived from the store (assertionLedgerPath) so a MANAGENT_STORE scratch
// override relocates the ledger too; this constant documents the default
// layout and is kept for readers that still reason about the on-disk tree.
const ASSERTIONS_FILE = "docs/infra/assertion-ledger/assertions.jsonl";

const Assertion = struct {
    id: []const u8,
    ts: []const u8,
    actor: []const u8,
    verb: []const u8,
    object: []const u8,
    basis: []const u8,
    supersedes: ?[]const u8 = null,
    note: ?[]const u8 = null,
    status_value: ?[]const u8 = null,
};

fn readDirectives(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, bad_out: ?*u32) !std.ArrayList(Directive) {
    _ = state_path;
    var result = std.ArrayList(Directive).empty;
    errdefer result.deinit(alloc);

    const dir_path = try std.fs.path.join(alloc, &.{ repo_root, DIRECTIVES_FILE });
    defer alloc.free(dir_path);

    const content = std.Io.Dir.cwd().readFileAlloc(io, dir_path, alloc, .unlimited) catch |err| {
        if (err == error.FileNotFound) return result;
        return err;
    };
    defer alloc.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    var bad: u32 = 0; // T399: unparseable lines are skipped (resilience) but
    // reported — a silent skip is what let the 2026-08-06 corruption sit.
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \r\n");
        if (trimmed.len == 0) continue;

        var parsed = std.json.parseFromSlice(std.json.Value, alloc, trimmed, .{ .allocate = .alloc_always }) catch {
            bad += 1;
            continue;
        };
        defer parsed.deinit();

        if (parsed.value != .object) {
            bad += 1;
            continue;
        }
        const obj = parsed.value.object;

        const d_id = if (obj.get("id")) |v| if (v == .string) v.string else "" else "";
        const d_target = if (obj.get("target")) |v| if (v == .string) v.string else "" else "";
        const d_dir = if (obj.get("directive")) |v| if (v == .string) v.string else "" else "";
        const d_note = if (obj.get("note")) |v| if (v == .string) v.string else "" else null;
        const d_from = if (obj.get("from")) |v| if (v == .string) v.string else "" else "";
        const d_ts = if (obj.get("ts")) |v| if (v == .string) v.string else "" else "";
        const d_read = if (obj.get("read")) |v| if (v == .bool) v.bool else false else false;
        const d_until_done = if (obj.get("until_done")) |v| if (v == .string) v.string else "" else "";

        if (d_id.len == 0 or d_target.len == 0) {
            bad += 1;
            continue;
        }

        try result.append(alloc, Directive{
            .id = try alloc.dupe(u8, d_id),
            .target = try alloc.dupe(u8, d_target),
            .directive = try alloc.dupe(u8, d_dir),
            .note = if (d_note) |n| try alloc.dupe(u8, n) else null,
            .from = try alloc.dupe(u8, d_from),
            .ts = try alloc.dupe(u8, d_ts),
            .read = d_read,
            .until_done = if (d_until_done.len > 0) try alloc.dupe(u8, d_until_done) else null,
        });
    }

    if (bad > 0) {
        w.diag("warn: {d} unparseable or malformed directive record(s) in {s} — the ledger has been corrupted\n", .{ bad, DIRECTIVES_FILE });
    }
    if (bad_out) |bo| bo.* = bad;

    return result;
}

/// T758: numeric suffix of a directive id ("D041" → 41).  null when the id
/// does not have the D<digits> shape (such a record contributes nothing to
/// the mint base).
fn directiveIdNumber(id: []const u8) ?u32 {
    if (id.len < 2 or id[0] != 'D') return null;
    return std.fmt.parseInt(u32, id[1..], 10) catch null;
}

/// T758: largest directive-id suffix already in the ledger (0 when empty or
/// unreadable).  The mint base is this + 1 — NOT _sys.directive_next alone.
/// The counter lives in tasks.json, a different file from the ledger, and a
/// direct store write / restore has rolled it back repeatedly (55→21, 34→21)
/// while the ledger kept its max id (D079): minting from the stale counter is
/// what re-minted D041 a third time on 2026-08-23.
fn maxDirectiveId(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8) u32 {
    var bad: u32 = 0;
    var list = readDirectives(w, io, repo_root, state_path, &bad) catch return 0;
    defer {
        for (list.items) |d| {
            alloc.free(d.id);
            alloc.free(d.target);
            alloc.free(d.directive);
            if (d.note) |n| alloc.free(n);
            alloc.free(d.from);
            alloc.free(d.ts);
            if (d.until_done) |ud| alloc.free(ud);
        }
        list.deinit(alloc);
    }
    var max: u32 = 0;
    for (list.items) |d| {
        if (directiveIdNumber(d.id)) |n| {
            if (n > max) max = n;
        }
    }
    return max;
}

/// T770: archive store path (same layout cmdArchive/cmdRetire use — always
/// under repo_root, NOT derived from MANAGENT_STORE, so a scratch store's
/// archive lands in the scratch repo's docs tree).
fn archivePath(repo_root: []const u8) ![]const u8 {
    return std.fs.path.join(alloc, &.{ repo_root, "docs", "infra", "managent", "archive.json" });
}

/// T770: largest task-ID suffix already retired to archive.json (0 when the
/// archive is empty, missing, or unreadable).  Reads the RAW file directly —
/// NOT readState — because parseStateJson has the side effect of reloading
/// the `_sys.*` globals (sys_next_id etc.) from whatever file it parses; an
/// archive read via readState would clobber the live counter with the
/// archive's stale one.  The auto mint base must consult this: a retired id
/// is a reference forever, and re-minting it silently rebinds every citation
/// of the retired row (T765 re-minted over the archived T765, 2026-08-23).
fn maxArchivedTaskId(io: std.Io, archive_path: []const u8) u32 {
    const content = std.Io.Dir.cwd().readFileAlloc(io, archive_path, alloc, .unlimited) catch return 0;
    defer alloc.free(content);
    var parsed = std.json.parseFromSlice(std.json.Value, alloc, content, .{ .allocate = .alloc_always }) catch return 0;
    defer parsed.deinit();
    if (parsed.value != .object) return 0;
    var max: u32 = 0;
    var it = parsed.value.object.iterator();
    while (it.next()) |entry| {
        const key = entry.key_ptr.*;
        if (!std.mem.startsWith(u8, key, "T")) continue;
        const n = std.fmt.parseInt(u32, key[1..], 10) catch continue;
        if (n > max) max = n;
    }
    return max;
}

/// T770: true when `id` is already retired to archive.json.  Same raw-read
/// discipline as maxArchivedTaskId (no parseStateJson side effect).
fn archiveContains(io: std.Io, archive_path: []const u8, id: []const u8) bool {
    const content = std.Io.Dir.cwd().readFileAlloc(io, archive_path, alloc, .unlimited) catch return false;
    defer alloc.free(content);
    var parsed = std.json.parseFromSlice(std.json.Value, alloc, content, .{ .allocate = .alloc_always }) catch return false;
    defer parsed.deinit();
    if (parsed.value != .object) return false;
    return parsed.value.object.get(id) != null;
}

fn appendDirective(w: Writers, io: std.Io, repo_root: []const u8, d: Directive) !void {
    const dir_path = try std.fs.path.join(alloc, &.{ repo_root, DIRECTIVES_FILE });
    defer alloc.free(dir_path);

    const dirname = std.fs.path.dirname(dir_path) orelse ".";
    std.Io.Dir.cwd().createDirPath(io, dirname) catch {};

    // Build JSON line — T399: every string goes through writeJsonString.
    // A raw `"` or newline in a note terminates the record early and the
    // reader skips it silently (Incident 1, 2026-08-06).
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(alloc);

    try buf.appendSlice(alloc, "{\"id\":");
    try writeJsonString(&buf, d.id);
    try buf.appendSlice(alloc, ",\"target\":");
    try writeJsonString(&buf, d.target);
    try buf.appendSlice(alloc, ",\"directive\":");
    try writeJsonString(&buf, d.directive);
    if (d.note) |n| {
        try buf.appendSlice(alloc, ",\"note\":");
        try writeJsonString(&buf, n);
    }
    try buf.appendSlice(alloc, ",\"from\":");
    try writeJsonString(&buf, d.from);
    try buf.appendSlice(alloc, ",\"ts\":");
    try writeJsonString(&buf, d.ts);
    try buf.appendSlice(alloc, ",\"read\":");
    if (d.read) {
        try buf.appendSlice(alloc, "true");
    } else {
        try buf.appendSlice(alloc, "false");
    }
    if (d.until_done) |ud| {
        try buf.appendSlice(alloc, ",\"until_done\":");
        try writeJsonString(&buf, ud);
    }
    try buf.appendSlice(alloc, "}\n");

    // T399: refuse to write an unreadable record.  The line we just built
    // must round-trip through the same parser the readers use; if it does
    // not, the file is left untouched and the command fails loudly — `tell`
    // must never print `told <target>` for a record a reader cannot see.
    {
        const check = std.mem.trim(u8, buf.items, " \r\n");
        var roundtrip = std.json.parseFromSlice(std.json.Value, alloc, check, .{ .allocate = .alloc_always }) catch {
            w.diag("FATAL: directive record {s} failed to re-parse after escaping — refusing to write (would corrupt the ledger)\n", .{d.id});
            return error.DirectiveWriteNotRoundTrip;
        };
        roundtrip.deinit();
    }

    // Read existing content + append new line
    const existing_str = std.Io.Dir.cwd().readFileAlloc(io, dir_path, alloc, .unlimited) catch "";
    defer if (@intFromPtr(existing_str.ptr) != @intFromPtr("".ptr)) alloc.free(existing_str);

    // T758: uniqueness backstop — before appending, confirm the id is not
    // already present in the ledger.  Parses each existing line (the same
    // shape readDirectives uses) rather than a substring search, so a note
    // containing the id text cannot false-trip it.  This is the single
    // append chokepoint: whatever the minting logic did, a colliding id must
    // be a loud error, never a silent duplicate that breaks the audit trail.
    {
        var lines = std.mem.splitScalar(u8, existing_str, '\n');
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \r\n");
            if (trimmed.len == 0) continue;
            var parsed = std.json.parseFromSlice(std.json.Value, alloc, trimmed, .{ .allocate = .alloc_always }) catch continue;
            defer parsed.deinit();
            if (parsed.value != .object) continue;
            if (parsed.value.object.get("id")) |v| {
                if (v == .string and std.mem.eql(u8, v.string, d.id)) {
                    w.diag("FATAL: directive id {s} already exists in the ledger — refusing to write a duplicate (would break the audit trail)\n", .{d.id});
                    return error.DirectiveIdCollision;
                }
            }
        }
    }

    var out = std.ArrayList(u8).empty;
    defer out.deinit(alloc);
    if (existing_str.len > 0) try out.appendSlice(alloc, existing_str);
    try out.appendSlice(alloc, buf.items);

    const file = try std.Io.Dir.cwd().createFile(io, dir_path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, out.items);
}

// ── assertion ledger (T426/T441) ────────────────────────────────────────────

/// T518/F9: derive the assertion-ledger path from the store (state_path),
/// not from repo_root.  The default store lives at
/// `<repo_root>/docs/infra/managent/tasks.json` and the default ledger at the
/// sibling `<repo_root>/docs/infra/assertion-ledger/assertions.jsonl`; deriving
/// the ledger as `dirname(state_path)/../assertion-ledger/assertions.jsonl`
/// preserves that default layout AND relocates the ledger alongside the store
/// when MANAGENT_STORE points at a scratch path.  Before this, `assert` wrote
/// to `repo_root/...` unconditionally — a scratch store's assertion leaked into
/// the live repo's ledger.  The reader (readLedgerStatuses) uses the same
/// derivation so a scratch assertion is read back from the scratch ledger.
fn assertionLedgerPath(state_path: []const u8) ![]const u8 {
    const dir = std.fs.path.dirname(state_path) orelse ".";
    return try std.fs.path.join(alloc, &.{ dir, "..", "assertion-ledger", "assertions.jsonl" });
}

fn appendAssertion(w: Writers, io: std.Io, state_path: []const u8, a: Assertion) !void {
    const path = try assertionLedgerPath(state_path);
    defer alloc.free(path);

    const dirname = std.fs.path.dirname(path) orelse ".";
    std.Io.Dir.cwd().createDirPath(io, dirname) catch {};

    // Build JSON line — T399: every string goes through writeJsonString.
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(alloc);

    try buf.appendSlice(alloc, "{\"id\":");
    try writeJsonString(&buf, a.id);
    try buf.appendSlice(alloc, ",\"ts\":");
    try writeJsonString(&buf, a.ts);
    try buf.appendSlice(alloc, ",\"actor\":");
    try writeJsonString(&buf, a.actor);
    try buf.appendSlice(alloc, ",\"verb\":");
    try writeJsonString(&buf, a.verb);
    try buf.appendSlice(alloc, ",\"object\":");
    try writeJsonString(&buf, a.object);
    try buf.appendSlice(alloc, ",\"basis\":");
    try writeJsonString(&buf, a.basis);
    if (a.supersedes) |s| {
        try buf.appendSlice(alloc, ",\"supersedes\":");
        try writeJsonString(&buf, s);
    }
    // Build meta object if either note or status_value is set
    if (a.note != null or a.status_value != null) {
        try buf.appendSlice(alloc, ",\"meta\":{");
        var first_meta = true;
        if (a.status_value) |sv| {
            try buf.appendSlice(alloc, "\"status\":");
            try writeJsonString(&buf, sv);
            first_meta = false;
        }
        if (a.note) |n| {
            if (!first_meta) try buf.appendSlice(alloc, ",");
            try buf.appendSlice(alloc, "\"note\":");
            try writeJsonString(&buf, n);
        }
        try buf.appendSlice(alloc, "}");
    }
    try buf.appendSlice(alloc, "}\n");

    // T399 round-trip guard
    {
        const check = std.mem.trim(u8, buf.items, " \r\n");
        var roundtrip = std.json.parseFromSlice(std.json.Value, alloc, check, .{ .allocate = .alloc_always }) catch {
            w.diag("FATAL: assertion record {s} failed to re-parse after escaping — refusing to write\n", .{a.id});
            return error.AssertionWriteNotRoundTrip;
        };
        roundtrip.deinit();
    }

    const existing_str = std.Io.Dir.cwd().readFileAlloc(io, path, alloc, .unlimited) catch "";
    defer if (@intFromPtr(existing_str.ptr) != @intFromPtr("".ptr)) alloc.free(existing_str);

    var out = std.ArrayList(u8).empty;
    defer out.deinit(alloc);
    if (existing_str.len > 0) try out.appendSlice(alloc, existing_str);
    try out.appendSlice(alloc, buf.items);

    const file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, out.items);
}

// ── ledger/board seam (T446 → T464 → T497) ──────────────────────────────────
// `status` / `next` render the kanban from tasks.json only; the assertion
// ledger is the audit trail of console-lifecycle FACTS (console died at T,
// absorbed at T, recommended-close).  T446 first let a `closed` assertion
// override tasks.json; T464 generalised that to BOTH directions — the latest
// assertion was authoritative over the stored status for every status the
// ledger can assert.  T497 reverses T464's generalisation: the failure mode
// was live in the record.  Assertion A0017 said T452 was `dispatchable`
// (written when a previous worker was killed); the kanban store said
// `in_progress` (a new worker was live); the resolver rendered the assertion,
// so watch-fleet showed T452 in both PROGRESS and OPEN.  A stale event log
// overrode a live kanban truth.
//
// Status has exactly ONE source: the kanban store (`tasks.json`), written
// only by managent verbs (claim/done/reopen/retire/verdict).  The assertion
// ledger remains an append-only event log, but it must NEVER override status
// — its latest entry on a row renders as an ANNOTATION (history) in
// `status`/`show` output, never as the effective status.  Every view —
// status, the board rendering, next, liveness, audit — resolves a task's
// status through resolveStatus() and nowhere else, and resolveStatus() now
// returns deriveStatus() unconditionally.

const LedgerStatus = struct {
    status_value: []const u8,
    assertion_id: []const u8,
    note: []const u8 = "",
    ts: []const u8 = "",
};

const LedgerStatuses = std.StringHashMapUnmanaged(LedgerStatus);

/// Read the assertion ledger and keep, per object, only the LATEST assertion
/// (append-only: a later line supersedes an earlier one).  Returns an empty
/// map when the ledger file is missing (null arm — behaviour unchanged).
fn readLedgerStatuses(io: std.Io, state_path: []const u8) LedgerStatuses {
    var map: LedgerStatuses = .{};
    const path = assertionLedgerPath(state_path) catch return map;
    defer alloc.free(path);

    const content = std.Io.Dir.cwd().readFileAlloc(io, path, alloc, .unlimited) catch |err| {
        if (err == error.FileNotFound) return map;
        return map;
    };
    defer alloc.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \r\n");
        if (trimmed.len == 0) continue;

        var parsed = std.json.parseFromSlice(std.json.Value, alloc, trimmed, .{ .allocate = .alloc_always }) catch continue;
        defer parsed.deinit();

        if (parsed.value != .object) continue;
        const obj = parsed.value.object;

        const object = obj.get("object") orelse continue;
        const a_id = obj.get("id") orelse continue;
        if (object != .string or a_id != .string) continue;

        var status_value: []const u8 = "";
        var note_value: []const u8 = "";
        if (obj.get("meta")) |m| {
            if (m == .object) {
                if (m.object.get("status")) |sv| {
                    if (sv == .string) status_value = sv.string;
                }
                if (m.object.get("note")) |nv| {
                    if (nv == .string) note_value = nv.string;
                }
            }
        }
        if (status_value.len == 0) continue;
        var ts_value: []const u8 = "";
        if (obj.get("ts")) |tv| {
            if (tv == .string) ts_value = tv.string;
        }

        const key_dupe = alloc.dupe(u8, object.string) catch continue;
        const sv_dupe = alloc.dupe(u8, status_value) catch {
            alloc.free(key_dupe);
            continue;
        };
        const aid_dupe = alloc.dupe(u8, a_id.string) catch {
            alloc.free(key_dupe);
            alloc.free(sv_dupe);
            continue;
        };
        const note_dupe = alloc.dupe(u8, note_value) catch {
            alloc.free(key_dupe);
            alloc.free(sv_dupe);
            alloc.free(aid_dupe);
            continue;
        };
        const ts_dupe = alloc.dupe(u8, ts_value) catch {
            alloc.free(key_dupe);
            alloc.free(sv_dupe);
            alloc.free(aid_dupe);
            alloc.free(note_dupe);
            continue;
        };
        const gop = map.getOrPut(alloc, key_dupe) catch {
            alloc.free(key_dupe);
            alloc.free(sv_dupe);
            alloc.free(aid_dupe);
            alloc.free(note_dupe);
            alloc.free(ts_dupe);
            continue;
        };
        if (gop.found_existing) {
            alloc.free(key_dupe);
            alloc.free(gop.value_ptr.status_value);
            alloc.free(gop.value_ptr.assertion_id);
            alloc.free(gop.value_ptr.note);
            alloc.free(gop.value_ptr.ts);
        } else {
            gop.key_ptr.* = key_dupe;
        }
        gop.value_ptr.status_value = sv_dupe;
        gop.value_ptr.assertion_id = aid_dupe;
        gop.value_ptr.note = note_dupe;
        gop.value_ptr.ts = ts_dupe;
    }
    return map;
}

fn freeLedgerStatuses(map: *LedgerStatuses) void {
    var it = map.iterator();
    while (it.next()) |entry| {
        alloc.free(entry.key_ptr.*);
        alloc.free(entry.value_ptr.status_value);
        alloc.free(entry.value_ptr.assertion_id);
        alloc.free(entry.value_ptr.note);
        alloc.free(entry.value_ptr.ts);
    }
    map.deinit(alloc);
}

/// The single, unmissable status resolver (T446 → T464 → T497).  Every view
/// — status, the board rendering, next, liveness, audit — calls this to
/// learn a task's effective status.  T497: status comes ONLY from the kanban
/// store via deriveStatus (stored status, needs-derived dispatchable ↔
/// blocked); the assertion ledger never overrides it.  `asserted` carries
/// the latest assertion's id whenever the ledger has spoken on a row, so the
/// view can render it as an annotation (history); it is null when no ledger
/// file exists (null arm) or no entry covers the row.  `asserted` is an
/// ANNOTATION, never authority.
const ResolvedStatus = struct {
    status: TaskStatus,
    asserted: ?[]const u8,
};

fn resolveStatus(state: *const StateMap, ts: TaskState, ledger: *const LedgerStatuses, tid: []const u8) ResolvedStatus {
    const asserted: ?[]const u8 = if (ledger.get(tid)) |ls| ls.assertion_id else null;
    return .{ .status = deriveStatus(state, ts), .asserted = asserted };
}

/// Render a row's latest assertion as an annotation (history, not authority).
/// Writes nothing and returns false when the ledger has no entry for `tid`.
/// `max_note` caps the note (the live A0004 note is hundreds of chars); 0
/// means omit the note entirely.  Shape: `(asserted: A0017 — dispatchable,
/// 2026-08-19 04:30Z; <note>)`.
fn writeAssertionAnnotation(w: Writers, ledger: *const LedgerStatuses, tid: []const u8, max_note: usize) bool {
    const ls = ledger.get(tid) orelse return false;
    w.data("(asserted: {s} — {s}", .{ ls.assertion_id, ls.status_value });
    if (ls.ts.len > 0) w.data(", {s}", .{ls.ts});
    if (max_note > 0 and ls.note.len > 0) {
        const shown = utf8Truncate(ls.note, max_note);
        w.data("; {s}", .{shown});
        if (ls.note.len > max_note) w.data("…", .{});
    }
    w.data(")", .{});
    return true;
}

// ── heartbeat reading (WORKER-CHANNEL) ──────────────────────────────────────

const Heartbeat = struct {
    identifier: []const u8,
    task: []const u8,
    ts: []const u8,
    command: []const u8 = "",
    wall: f64 = 0.0,
    cpu: f64 = 0.0,
    rss_mb: f64 = 0.0,
};

fn readHeartbeats(w: Writers, io: std.Io, repo_root: []const u8) !std.ArrayList(Heartbeat) {
    var result = std.ArrayList(Heartbeat).empty;
    errdefer result.deinit(alloc);

    const hb_path = try std.fs.path.join(alloc, &.{ repo_root, "untracked", "heartbeat.jsonl" });
    defer alloc.free(hb_path);

    const content = std.Io.Dir.cwd().readFileAlloc(io, hb_path, alloc, .unlimited) catch |err| {
        if (err == error.FileNotFound) return result;
        return err;
    };
    defer alloc.free(content);

    var lines = std.mem.splitScalar(u8, content, '\n');
    var bad: u32 = 0; // T399: same silent-skip hazard as readDirectives had —
    // a corrupt heartbeat record must be reported, not swallowed.
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \r\n");
        if (trimmed.len == 0) continue;

        var parsed = std.json.parseFromSlice(std.json.Value, alloc, trimmed, .{ .allocate = .alloc_always }) catch {
            bad += 1;
            continue;
        };
        defer parsed.deinit();

        if (parsed.value != .object) {
            bad += 1;
            continue;
        }
        const obj = parsed.value.object;

        const hb_ident = if (obj.get("identifier")) |v| if (v == .string) v.string else "" else "";
        const hb_task = if (obj.get("task")) |v| if (v == .string) v.string else "" else "";
        const hb_ts = if (obj.get("ts")) |v| if (v == .string) v.string else "" else "";
        const hb_cmd = if (obj.get("command")) |v| if (v == .string) v.string else "" else "";
        const hb_wall = if (obj.get("wall")) |v| if (v == .float) @as(f64, v.float) else if (v == .integer) @as(f64, @floatFromInt(v.integer)) else 0.0 else 0.0;
        const hb_cpu = if (obj.get("cpu")) |v| if (v == .float) @as(f64, v.float) else if (v == .integer) @as(f64, @floatFromInt(v.integer)) else 0.0 else 0.0;
        const hb_rss = if (obj.get("rss_mb")) |v| if (v == .float) @as(f64, v.float) else if (v == .integer) @as(f64, @floatFromInt(v.integer)) else 0.0 else 0.0;

        if (hb_ident.len == 0 or hb_task.len == 0) {
            bad += 1;
            continue;
        }

        try result.append(alloc, Heartbeat{
            .identifier = try alloc.dupe(u8, hb_ident),
            .task = try alloc.dupe(u8, hb_task),
            .ts = try alloc.dupe(u8, hb_ts),
            .command = try alloc.dupe(u8, hb_cmd),
            .wall = hb_wall,
            .cpu = hb_cpu,
            .rss_mb = hb_rss,
        });
    }

    if (bad > 0) {
        w.diag("warn: {d} unparseable or malformed heartbeat record(s) in untracked/heartbeat.jsonl\n", .{bad});
    }

    return result;
}

// ── run records + orphan reaping (T364, 2026-08-20) ────────────────────────
//
// T364 closes the two structural gaps behind the 2026-08-04 fleet incident
// (T355/T356 rows ended with NO exit heartbeat — the runner was SIGKILLed in
// a load-16 sweep — and the rows sat in_progress for hours with nothing
// alive behind them):
//
//   1. tools/runner writes a PARENT-side exit record at launch
//      (untracked/runs/<task>.json: pid, pgid, start, command) and rewrites
//      it at exit with the child's fate (exit code or signal, wall, peak
//      RSS, kill reason).  A `kill -9` of the child leaves a COMPLETED
//      record — the parent wrote it.  A `kill -9` of the runner leaves the
//      launch record with no exit fields — "killed mid-flight", readable by
//      the next reap/resume.
//   2. `managent reap` reconciles the kanban against the process table: for
//      each in_progress row, a live runner pid (from the run record) or a
//      fresh heartbeat means the row is BACKED and is never reaped (stalled
//      is the progress watchdog's job, not the reaper's); a dead runner
//      with a completed record, a dead runner with no exit fields, or no
//      process evidence at all means ORPHAN.  `--close` closes each orphan
//      as `abandoned` with a note naming the evidence — never a verdict
//      guess (an orphaned row is abandoned, not pass).

const RunRecord = struct {
    task: []const u8 = "",
    pid: i64 = 0,
    pgid: i64 = 0,
    launcher_pid: i64 = 0,
    start: []const u8 = "",
    end: ?[]const u8 = null,
    exit: ?i64 = null,
    signal: ?i64 = null,
    command: []const u8 = "",
    wall: f64 = 0.0,
    cpu: f64 = 0.0,
    rss_mb: f64 = 0.0,
    killed: ?[]const u8 = null,
};

fn runRecI64(o: std.json.ObjectMap, key: []const u8) i64 {
    return if (o.get(key)) |v| switch (v) {
        .integer => v.integer,
        else => 0,
    } else 0;
}

fn runRecOptI64(o: std.json.ObjectMap, key: []const u8) ?i64 {
    return if (o.get(key)) |v| switch (v) {
        .integer => v.integer,
        else => null,
    } else null;
}

fn runRecStr(o: std.json.ObjectMap, key: []const u8) []const u8 {
    return if (o.get(key)) |v| if (v == .string) v.string else "" else "";
}

fn runRecOptStr(o: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    return if (o.get(key)) |v| if (v == .string) v.string else null else null;
}

fn runRecF64(o: std.json.ObjectMap, key: []const u8) f64 {
    return if (o.get(key)) |v| switch (v) {
        .float => @floatCast(v.float),
        .integer => @floatFromInt(v.integer),
        else => 0.0,
    } else 0.0;
}

fn readRunRecords(w: Writers, io: std.Io, repo_root: []const u8) !std.ArrayList(RunRecord) {
    var result = std.ArrayList(RunRecord).empty;
    errdefer result.deinit(alloc);

    const runs_dir = try std.fs.path.join(alloc, &.{ repo_root, "untracked", "runs" });
    defer alloc.free(runs_dir);

    var dir = std.Io.Dir.cwd().openDir(io, runs_dir, .{}) catch |err| {
        if (err == error.FileNotFound) return result; // fresh clone / no runs yet
        return err;
    };
    defer dir.close(io);

    var bad: u32 = 0; // same silent-skip hazard as readHeartbeats: a corrupt
    // run record must be reported, not swallowed (T399).
    var it = dir.iterate();
    while (it.next(io) catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;

        const abs = std.fs.path.join(alloc, &.{ runs_dir, entry.name }) catch continue;
        defer alloc.free(abs);
        const content = std.Io.Dir.cwd().readFileAlloc(io, abs, alloc, .unlimited) catch |err| {
            if (err == error.FileNotFound) continue;
            bad += 1;
            continue;
        };
        defer alloc.free(content);

        const trimmed = std.mem.trim(u8, content, " \r\n");
        if (trimmed.len == 0) {
            bad += 1;
            continue;
        }

        var parsed = std.json.parseFromSlice(std.json.Value, alloc, trimmed, .{ .allocate = .alloc_always }) catch {
            bad += 1;
            continue;
        };
        defer parsed.deinit();
        if (parsed.value != .object) {
            bad += 1;
            continue;
        }
        const obj = parsed.value.object;

        const task = runRecStr(obj, "task");
        if (task.len == 0) {
            bad += 1;
            continue;
        }

        const end = runRecOptStr(obj, "end");
        const killed = runRecOptStr(obj, "killed");
        try result.append(alloc, RunRecord{
            .task = try alloc.dupe(u8, task),
            .pid = runRecI64(obj, "pid"),
            .pgid = runRecI64(obj, "pgid"),
            .launcher_pid = runRecI64(obj, "launcher_pid"),
            .start = try alloc.dupe(u8, runRecStr(obj, "start")),
            .end = if (end) |s| try alloc.dupe(u8, s) else null,
            .exit = runRecOptI64(obj, "exit"),
            .signal = runRecOptI64(obj, "signal"),
            .command = try alloc.dupe(u8, runRecStr(obj, "command")),
            .wall = runRecF64(obj, "wall"),
            .cpu = runRecF64(obj, "cpu"),
            .rss_mb = runRecF64(obj, "rss_mb"),
            .killed = if (killed) |s| try alloc.dupe(u8, s) else null,
        });
    }
    if (bad > 0) {
        w.diag("warn: {d} unparseable or malformed run record(s) in untracked/runs/\n", .{bad});
    }
    return result;
}

/// True when a process with this pid exists (POSIX kill(pid, 0) probe).
/// Conservative on doubt: PermissionDenied means the process exists but we
/// may not signal it; any unexpected error is treated as alive — the reaper
/// never closes a row it cannot prove dead.
fn processAlive(pid: i64) bool {
    if (pid <= 0) return false;
    std.posix.kill(@intCast(pid), @enumFromInt(0)) catch |err| {
        return switch (err) {
            error.ProcessNotFound => false,
            else => true,
        };
    };
    return true;
}

const ReapClass = enum {
    backed_process, // run-record pid alive — never reap
    backed_heartbeat, // no run record but a fresh heartbeat — never reap
    orphan_ended, // runner dead, completed record — run ended, row never closed
    orphan_midflight, // runner dead, launch record only — killed mid-flight
    orphan_no_evidence, // no run record, no fresh heartbeat — nothing backs the row
};

const ReapRow = struct {
    tid: []const u8,
    cls: ReapClass,
    evidence: []const u8,
};

fn latestRunRecordFor(runs: []const RunRecord, tid: []const u8) ?RunRecord {
    var latest: ?RunRecord = null;
    for (runs) |r| {
        if (!std.mem.eql(u8, r.task, tid)) continue;
        if (latest == null or std.mem.lessThan(u8, (latest.?).start, r.start)) latest = r;
    }
    return latest;
}

fn latestHeartbeatFor(heartbeats: []const Heartbeat, tid: []const u8) ?Heartbeat {
    var latest: ?Heartbeat = null;
    for (heartbeats) |h| {
        if (!std.mem.eql(u8, h.task, tid)) continue;
        if (latest == null or std.mem.lessThan(u8, (latest.?).ts, h.ts)) latest = h;
    }
    return latest;
}

/// Classify every in_progress row as backed or orphan, with the evidence
/// string that becomes the abandoned note.  Shared by `reap` and `resume`.
/// Caller frees the rows (tid/evidence are allocated).
fn classifyReapRows(
    w: Writers,
    io: std.Io,
    repo_root: []const u8,
    state: *const StateMap,
    ledger: *const LedgerStatuses,
    stale_secs: i64,
    heartbeats: []const Heartbeat,
) !std.ArrayList(ReapRow) {
    var rows = std.ArrayList(ReapRow).empty;
    errdefer rows.deinit(alloc);

    var runs = try readRunRecords(w, io, repo_root);
    defer {
        for (runs.items) |r| {
            alloc.free(r.task);
            alloc.free(r.start);
            if (r.end) |s| alloc.free(s);
            alloc.free(r.command);
            if (r.killed) |s| alloc.free(s);
        }
        runs.deinit(alloc);
    }

    var now_tp: std.c.timespec = undefined;
    _ = std.c.clock_gettime(std.c.CLOCK.REALTIME, &now_tp);
    const now_unix: i64 = now_tp.sec;

    var it = state.iterator();
    while (it.next()) |entry| {
        const tid = entry.key_ptr.*;
        const ts = entry.value_ptr.*;
        if (resolveStatus(state, ts, ledger, tid).status != .in_progress) continue;

        var cls: ReapClass = undefined;
        var evidence: []const u8 = "";

        if (latestRunRecordFor(runs.items, tid)) |rec| {
            if (processAlive(rec.pid)) {
                cls = .backed_process;
                evidence = try std.fmt.allocPrint(alloc,
                    "runner pid {d} alive (start {s}, command {s}) — row is backed", .{
                    rec.pid, rec.start, rec.command,
                });
            } else if (rec.exit != null or rec.signal != null) {
                // The run COMPLETED (child exited or was killed) but the row
                // was never closed — the runner is gone.
                cls = .orphan_ended;
                if (rec.signal) |sig| {
                    evidence = try std.fmt.allocPrint(alloc,
                        "no live process — run ended signal={d} wall={d:.1}s at {s}; runner pid {d} dead; row never closed", .{
                        sig, rec.wall, rec.end orelse "?", rec.pid,
                    });
                } else {
                    evidence = try std.fmt.allocPrint(alloc,
                        "no live process — run ended exit={d} wall={d:.1}s at {s}; runner pid {d} dead; row never closed", .{
                        rec.exit orelse -1, rec.wall, rec.end orelse "?", rec.pid,
                    });
                }
            } else {
                // Launch record with no exit fields: the runner itself was
                // killed mid-flight (the 2026-08-04 incident shape).
                cls = .orphan_midflight;
                evidence = try std.fmt.allocPrint(alloc,
                    "no live process — launch record {s} (command {s}) has no exit fields; runner pid {d} dead — killed mid-flight", .{
                    rec.start, rec.command, rec.pid,
                });
            }
        } else if (latestHeartbeatFor(heartbeats, tid)) |hb| {
            if (ageSecFromTs(hb.ts, now_unix)) |age| {
                if (age <= stale_secs) {
                    cls = .backed_heartbeat;
                    evidence = try std.fmt.allocPrint(alloc,
                        "no run record but last beat {d}s ago — beating, never reap a healthy worker", .{age});
                } else {
                    cls = .orphan_no_evidence;
                    evidence = try std.fmt.allocPrint(alloc,
                        "no live process — no run record; last heartbeat {s} ({d}s ago); nothing backs the row", .{
                        hb.ts, age,
                    });
                }
            } else {
                cls = .orphan_no_evidence;
                evidence = try std.fmt.allocPrint(alloc,
                    "no live process — no run record; last heartbeat {s} (unparseable ts); nothing backs the row", .{hb.ts});
            }
        } else if (ts.claimed) |claimed| {
            cls = .orphan_no_evidence;
            evidence = try std.fmt.allocPrint(alloc,
                "no live process — no run record and never beat since claim {s}", .{claimed});
        } else {
            cls = .orphan_no_evidence;
            evidence = try alloc.dupe(u8, "no live process — no run record and no heartbeat");
        }

        try rows.append(alloc, .{ .tid = tid, .cls = cls, .evidence = evidence });
    }
    return rows;
}

fn freeReapRows(rows: *std.ArrayList(ReapRow)) void {
    for (rows.items) |r| {
        alloc.free(r.evidence);
        // r.tid is NOT freed: it aliases the state map's key memory (the
        // classifier copies the key pointer).  The caller owns the map and
        // frees it via freeState; freeing here would double-free.
    }
    rows.deinit(alloc);
}

fn isOrphanReap(cls: ReapClass) bool {
    return switch (cls) {
        .backed_process, .backed_heartbeat => false,
        else => true,
    };
}


// ── 1. sync <role> — message-bus sync ───────────────────────────────────────

fn cmdSync(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    if (args.len < 3) {
        w.diag("usage: managent sync <role> [--peek]\n", .{});
        std.process.exit(1);
    }
    const peek_only = hasFlag(args, "--peek");
    // Find the role: first positional arg after "sync" that is not a flag
    var role: []const u8 = "";
    for (args[2..]) |a| {
        if (!std.mem.startsWith(u8, a, "-")) {
            role = a;
            break;
        }
    }
    if (role.len == 0) {
        w.diag("usage: managent sync <role> [--peek]\n", .{});
        std.process.exit(1);
    }

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

    // Update read state (skip with --peek: read-only, does not write _sync cursor)
    // T545: writeSyncData rewrites the WHOLE store file; it must be under the
    // flock like every other whole-file writer.  The previous code wrote it
    // UNLOCKED — a concurrent claim/close/done landing between writeSyncData's
    // raw read and its rename was silently reverted.
    if (!peek_only) {
        try lockStore(io, state_path);
        defer unlockStore();
        var st = try readState(io, state_path);
        const new_rs = RoleSync{
            .last_read_msg = max_num,
            .last_posted_msg = last_role_post,
            .last_event_gen = getEventGen(&st),
        };
        try writeSyncData(io, state_path, &st, role_lower, new_rs);
        freeState(&st);
    } else {
        w.diag("  (--peek: read-only, _sync cursor not updated)\n", .{});
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
    // Build the _sync block — T399: the role is a CLI arg and must go
    // through writeJsonString like every other free text.
    var sync_buf = std.ArrayList(u8).empty;
    defer sync_buf.deinit(alloc);
    try sync_buf.appendSlice(alloc, "\"_sync\": {");
    try writeJsonString(&sync_buf, role);
    try sync_buf.appendSlice(alloc, ": {\"last_read_msg\":");
    try sync_buf.appendSlice(alloc, try std.fmt.allocPrint(alloc, "{d}", .{rs.last_read_msg}));
    try sync_buf.appendSlice(alloc, ",\"last_posted_msg\":");
    try sync_buf.appendSlice(alloc, try std.fmt.allocPrint(alloc, "{d}", .{rs.last_posted_msg}));
    try sync_buf.appendSlice(alloc, ",\"last_event_gen\":");
    try sync_buf.appendSlice(alloc, try std.fmt.allocPrint(alloc, "{d}", .{rs.last_event_gen}));
    try sync_buf.appendSlice(alloc, "}}");

    // Simple approach: insert _sync before the closing brace
    if (trimmed.len > 2 and trimmed[trimmed.len - 1] == '}') {
        // Strip trailing whitespace before the closing }
        var end = trimmed.len - 1;
        while (end > 0 and (trimmed[end - 1] == ' ' or trimmed[end - 1] == '\n' or trimmed[end - 1] == '\r' or trimmed[end - 1] == '\t')) {
            end -= 1;
        }
        try buf.appendSlice(alloc, trimmed[0..end]);
        try buf.appendSlice(alloc, ",\n  ");
        try buf.appendSlice(alloc, sync_buf.items);
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

// ── holds --sync — reconcile the store's holds= field with bundle headers ──

/// T539: order-insensitive equality for two holds lists (the one-writer check
/// compares memberships, not ordering).
fn holdsListsEqual(a: [][]const u8, b: [][]const u8) bool {
    if (a.len != b.len) return false;
    for (a) |x| {
        var found = false;
        for (b) |y| {
            if (std.mem.eql(u8, x, y)) {
                found = true;
                break;
            }
        }
        if (!found) return false;
    }
    return true;
}

fn cmdHolds(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    if (args.len < 3 or !std.mem.eql(u8, args[2], "--sync")) {
        w.diag("usage: managent holds --sync\n", .{});
        w.diag("       reads every row's bundle header holds= and fills the store,\n", .{});
        w.diag("       printing each change; idempotent; covers done/failed rows.\n", .{});
        std.process.exit(1);
    }

    // T539: bundle headers are the author's source of truth; the store's
    // holds= field is the cache.  This command rebuilds the cache.  Lock →
    // read → modify → writeLocked → unlock (same lost-update pattern as add).
    try lockStore(io, state_path);
    defer unlockStore();
    var state = try readState(io, state_path);

    var updated: u32 = 0;
    var unchanged: u32 = 0;
    var no_bundle: u32 = 0;
    var no_declared: u32 = 0;

    var it = state.iterator();
    while (it.next()) |entry| {
        if (std.mem.eql(u8, entry.key_ptr.*, "_sys")) continue;
        const id = entry.key_ptr.*;
        const ts = entry.value_ptr.*;

        const abs = bundleAbsFor(io, repo_root, id, ts.bundle) orelse {
            no_bundle += 1;
            continue;
        };
        const declared = readBundleHolds(io, abs) orelse {
            // No holds= key (or unreadable header).  Leave the store row as-is:
            // the author simply declared no holds, and a --holds flag may have
            // been the writer instead.  Never silently clear.
            no_declared += 1;
            continue;
        };

        if (holdsListsEqual(ts.holds, declared)) {
            unchanged += 1;
            continue;
        }

        // Print the diff, then write.  The bundle wins — it is the source of
        // truth; the store field is what was missing.
        w.data("holds: {s} ", .{id});
        if (ts.holds.len == 0) {
            w.data("[]", .{});
        } else {
            w.data("[", .{});
            for (ts.holds, 0..) |h, hi| {
                if (hi > 0) w.data(",", .{});
                w.data("{s}", .{h});
            }
            w.data("]", .{});
        }
        w.data(" -> [", .{});
        for (declared, 0..) |h, hi| {
            if (hi > 0) w.data(",", .{});
            w.data("{s}", .{h});
        }
        w.data("]\n", .{});

        entry.value_ptr.holds = declared;
        updated += 1;
    }

    if (updated > 0) {
        try writeStateLocked(io, state_path, &state);
    }
    w.data("holds --sync: {d} updated, {d} unchanged, {d} no-bundle, {d} no-declared-holds\n", .{ updated, unchanged, no_bundle, no_declared });
}

// ── 2. audit — cross-check kanban against reality ───────────────────────────

fn cmdAudit(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    const use_json = hasFlag(args, "--json");

    var state = try readState(io, state_path);
    defer freeState(&state);

    // T464: audit classifies every row through the same resolver as the board
    // — a closed assertion is done, a dispatchable assertion is dispatchable.
    var ledger = readLedgerStatuses(io, state_path);
    defer freeLedgerStatuses(&ledger);

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

    // ── ORCHA-TOOLS R3: read CLAIMS.md and PROGRESS.md for citation checks ──
    var claims_content: []const u8 = "";
    var progress_content: []const u8 = "";
    var claims_owned = false;
    var progress_owned = false;
    {
        const claims_path = try std.fs.path.join(alloc, &.{ repo_root, "docs", "epistemic", "CLAIMS.md" });
        defer alloc.free(claims_path);
        claims_content = std.Io.Dir.cwd().readFileAlloc(io, claims_path, alloc, .unlimited) catch "";
        if (claims_content.len > 0) claims_owned = true;
    }
    {
        const progress_path = try std.fs.path.join(alloc, &.{ repo_root, "docs", "epistemic", "PROGRESS.md" });
        defer alloc.free(progress_path);
        progress_content = std.Io.Dir.cwd().readFileAlloc(io, progress_path, alloc, .unlimited) catch "";
        if (progress_content.len > 0) progress_owned = true;
    }
    // ── T210 D1: widen citable surfaces to DECISIONS.md, docs/status/, docs/audits/ ──
    var decisions_content: []const u8 = "";
    var status_content: []const u8 = "";
    var audits_content: []const u8 = "";
    var decisions_owned = false;
    var status_owned = false;
    var audits_owned = false;
    {
        // Read all DECISIONS.md files from untracked/msg/*/ directories
        var decisions_buf = std.ArrayList(u8).empty;
        const msg_base = try std.fs.path.join(alloc, &.{ repo_root, "untracked", "msg" });
        defer alloc.free(msg_base);
        var msg_root = std.Io.Dir.cwd().openDir(io, msg_base, .{}) catch null;
        if (msg_root) |*dir| {
            defer dir.close(io);
            var iter = dir.iterate();
            while (try iter.next(io)) |entry| {
                if (entry.kind == .directory) {
                    const dec_path = try std.fs.path.join(alloc, &.{ msg_base, entry.name, "DECISIONS.md" });
                    defer alloc.free(dec_path);
                    const dec_content = std.Io.Dir.cwd().readFileAlloc(io, dec_path, alloc, .unlimited) catch "";
                    if (dec_content.len > 0) {
                        try decisions_buf.appendSlice(alloc, dec_content);
                        alloc.free(dec_content);
                    }
                }
            }
        }
        if (decisions_buf.items.len > 0) {
            decisions_content = try decisions_buf.toOwnedSlice(alloc);
            decisions_owned = true;
        }
    }
    {
        // Read all *.md files from docs/status/
        var status_buf = std.ArrayList(u8).empty;
        const status_base = try std.fs.path.join(alloc, &.{ repo_root, "docs", "status" });
        defer alloc.free(status_base);
        var status_root = std.Io.Dir.cwd().openDir(io, status_base, .{}) catch null;
        if (status_root) |*dir| {
            defer dir.close(io);
            var iter = dir.iterate();
            while (try iter.next(io)) |entry| {
                if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".md")) {
                    const sp = try std.fs.path.join(alloc, &.{ status_base, entry.name });
                    defer alloc.free(sp);
                    const sc = std.Io.Dir.cwd().readFileAlloc(io, sp, alloc, .unlimited) catch "";
                    if (sc.len > 0) {
                        try status_buf.appendSlice(alloc, sc);
                        alloc.free(sc);
                    }
                }
            }
        }
        if (status_buf.items.len > 0) {
            status_content = try status_buf.toOwnedSlice(alloc);
            status_owned = true;
        }
    }
    {
        // Read all *.md files from docs/audits/
        var audits_buf = std.ArrayList(u8).empty;
        const audits_base = try std.fs.path.join(alloc, &.{ repo_root, "docs", "audits" });
        defer alloc.free(audits_base);
        var audits_root = std.Io.Dir.cwd().openDir(io, audits_base, .{}) catch null;
        if (audits_root) |*dir| {
            defer dir.close(io);
            var iter = dir.iterate();
            while (try iter.next(io)) |entry| {
                if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".md")) {
                    const ap = try std.fs.path.join(alloc, &.{ audits_base, entry.name });
                    defer alloc.free(ap);
                    const ac = std.Io.Dir.cwd().readFileAlloc(io, ap, alloc, .unlimited) catch "";
                    if (ac.len > 0) {
                        try audits_buf.appendSlice(alloc, ac);
                        alloc.free(ac);
                    }
                }
            }
        }
        if (audits_buf.items.len > 0) {
            audits_content = try audits_buf.toOwnedSlice(alloc);
            audits_owned = true;
        }
    }
    defer {
        if (claims_owned) alloc.free(claims_content);
        if (progress_owned) alloc.free(progress_content);
        if (decisions_owned) alloc.free(decisions_content);
        if (status_owned) alloc.free(status_content);
        if (audits_owned) alloc.free(audits_content);
    }

    const Finding = struct {
        level: []const u8,
        id: []const u8,
        msg: []const u8,
    };

    var findings = std.ArrayList(Finding).empty;
    defer {
        for (findings.items) |f| {
            alloc.free(f.msg);
        }
        findings.deinit(alloc);
    }

    // T204: check next_id ≤ max(T-ID) — a collision waiting to happen
    {
        var max_tid: u32 = 0;
        var it0 = state.iterator();
        while (it0.next()) |entry0| {
            const k = entry0.key_ptr.*;
            if (std.mem.startsWith(u8, k, "T")) {
                const num = std.fmt.parseInt(u32, k[1..], 10) catch 0;
                if (num > max_tid) max_tid = num;
            }
        }
        if (max_tid > 0 and sys_next_id <= max_tid) {
            const msg = try std.fmt.allocPrint(alloc, "_sys.next_id ({d}) ≤ max T-ID (T{d}) — next suggest/add will clobber", .{ sys_next_id, max_tid });
            try findings.append(alloc, .{ .level = "FIX", .id = "_sys", .msg = msg });
        }
    }

    // ── T399: the directive ledger must round-trip ─────────────────────────
    // A corrupted control channel (unparseable lines) means directives were
    // written but never delivered — the Incident-1 failure mode (2026-08-06):
    // `tell` printed success while the reader skipped the record silently.
    // The reader warns per invocation; audit surfaces it on the dashboard.
    {
        var bad_directives: u32 = 0;
        var directives_for_check = readDirectives(w, io, repo_root, state_path, &bad_directives) catch null;
        if (directives_for_check) |*dl| {
            for (dl.items) |di| {
                alloc.free(di.id);
                alloc.free(di.target);
                alloc.free(di.directive);
                if (di.note) |n| alloc.free(n);
                alloc.free(di.from);
                alloc.free(di.ts);
                if (di.until_done) |ud| alloc.free(ud);
            }
            dl.deinit(alloc);
        }
        if (bad_directives > 0) {
            const msg = try std.fmt.allocPrint(alloc, "{d} unparseable or malformed directive record(s) in directives.jsonl — the ledger has been corrupted; directives may have been written but never delivered", .{bad_directives});
            try findings.append(alloc, .{ .level = "FIX", .id = "directives.jsonl", .msg = msg });
        }
    }

    var it = state.iterator();
    while (it.next()) |entry| {
        const tid = entry.key_ptr.*;
        const ts = entry.value_ptr.*;
        const eff = resolveStatus(&state, ts, &ledger, tid).status;

        // T478: a duty is not a task — the task-lifecycle audit checks
        // (unmet needs, attribution, deliverables, staleness) do not apply.
        if (ts.duty) continue;

        // ── cross-status checks (apply regardless of status) ──

        // A. in_progress or done but needs not met → claimed over an unmet gate
        if (eff == .in_progress or eff == .done) {
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
                const msg = try std.fmt.allocPrint(alloc, "{s} but needs not met: {s} — gate it (claimed over unmet dependency)", .{ statusToString(eff), unmet_list.items });
                try findings.append(alloc, .{ .level = "FIX", .id = tid, .msg = msg });
            }
            // Also check retroactively: claimed before dependency completed
            if (ts.claimed != null and needsMet(&state, ts)) {
                for (ts.needs) |n| {
                    const nts = state.get(n);
                    if (nts) |need_ts| {
                        if (need_ts.done != null and ts.claimed != null) {
                            if (std.mem.lessThan(u8, ts.claimed.?, need_ts.done.?)) {
                                const msg = try std.fmt.allocPrint(alloc, "{s}: claimed ({s}) before dependency {s} was done ({s}) — gated claim", .{ statusToString(eff), ts.claimed.?, n, need_ts.done.? });
                                try findings.append(alloc, .{ .level = "WARN", .id = tid, .msg = msg });
                                break;
                            }
                        }
                    }
                }
            }
        }

        // B. done task with claimed == null → completed without ever being claimed
        if (eff == .done and ts.claimed == null) {
            const msg = try std.fmt.allocPrint(alloc, "done but never claimed — audit trail broken", .{});
            try findings.append(alloc, .{ .level = "FIX", .id = tid, .msg = msg });
        }

        // T424: amended rows — a post-close correction was recorded against the
        // row (amend --verdict / amend --post-close / a forced close).  The
        // kanban must surface it, not bury it in the store: a correction that
        // lands after the close is exactly the kanban-disagrees-with-reality
        // class (T422's D064 shape).  WARN, not FIX — a correction is a fact
        // of record, not a defect to gate on.
        if (ts.amendments.len > 0) {
            const msg = try std.fmt.allocPrint(alloc, "amended post-close ({d} correction record(s)) — see managent show {s}", .{ ts.amendments.len, tid });
            try findings.append(alloc, .{ .level = "WARN", .id = tid, .msg = msg });
        }

        // C. in_progress task with note containing GATED → was blocked by hand
        if (eff == .in_progress and ts.note != null) {
            if (std.mem.indexOf(u8, ts.note.?, "GATED") != null) {
                const msg = try std.fmt.allocPrint(alloc, "in_progress but note says GATED — verify premise is still valid", .{});
                try findings.append(alloc, .{ .level = "WARN", .id = tid, .msg = msg });
            }
        }

        // WORKER-CHANNEL: heartbeat-based staleness check for in_progress
        if (eff == .in_progress) {
            var hbs = readHeartbeats(w, io, repo_root) catch null;
            if (hbs) |*heartbeats| {
                defer {
                    for (heartbeats.items) |h| {
                        alloc.free(h.identifier);
                        alloc.free(h.task);
                        alloc.free(h.ts);
                        alloc.free(h.command);
                    }
                    heartbeats.deinit(alloc);
                }
                var latest: ?Heartbeat = null;
                for (heartbeats.items) |hb| {
                    if (std.mem.eql(u8, hb.task, tid)) {
                        if (latest == null or std.mem.lessThan(u8, (latest.?).ts, hb.ts)) {
                            latest = hb;
                        }
                    }
                }
                if (latest == null) {
                    const msg = try std.fmt.allocPrint(alloc, "in_progress but no heartbeat ever recorded", .{});
                    try findings.append(alloc, .{ .level = "WARN", .id = tid, .msg = msg });
                }
            }
        }

        switch (eff) {
            .done => {
                // 1. done task with agent == null → attribute it
                if (ts.agent == null) {
                    const msg = try std.fmt.allocPrint(alloc, "done but agent is unset — attribute it: managent agent {s} <worker>", .{tid});
                    try findings.append(alloc, .{ .level = "FIX", .id = tid, .msg = msg });
                }

                // 2. done task whose path is not cited in CLAIMS.md or PROGRESS.md (ORCHA-TOOLS R3)
                {
                    const bundle_abs2 = if (std.fs.path.isAbsolute(ts.bundle))
                        try alloc.dupe(u8, ts.bundle)
                    else
                        try std.fs.path.join(alloc, &.{ repo_root, ts.bundle });
                    defer alloc.free(bundle_abs2);
                    const bundle_deliverables = try parseDeliverablesFromBundle(w, io, bundle_abs2, ts.holds);
                    defer {
                        for (bundle_deliverables) |d| alloc.free(d);
                        alloc.free(bundle_deliverables);
                    }
                    var any_cited = false;
                    // Check if task ID or any deliverable path appears in citable surfaces
                    // (CLAIMS.md, PROGRESS.md, DECISIONS.md, docs/status/*.md, docs/audits/*.md — T210 D1)
                    if (std.mem.indexOf(u8, claims_content, tid) != null or
                        std.mem.indexOf(u8, progress_content, tid) != null or
                        std.mem.indexOf(u8, decisions_content, tid) != null or
                        std.mem.indexOf(u8, status_content, tid) != null or
                        std.mem.indexOf(u8, audits_content, tid) != null)
                    {
                        any_cited = true;
                    }
                    if (!any_cited) {
                        for (bundle_deliverables) |d| {
                            if (std.mem.indexOf(u8, claims_content, d) != null or
                                std.mem.indexOf(u8, progress_content, d) != null or
                                std.mem.indexOf(u8, decisions_content, d) != null or
                                std.mem.indexOf(u8, status_content, d) != null or
                                std.mem.indexOf(u8, audits_content, d) != null)
                            {
                                any_cited = true;
                                break;
                            }
                        }
                    }
                    if (!any_cited) {
                        const msg = try std.fmt.allocPrint(alloc, "done but deliverables not cited in CLAIMS.md, PROGRESS.md, DECISIONS.md, docs/status/ or docs/audits/ — promote or cite", .{});
                        try findings.append(alloc, .{ .level = "WARN", .id = tid, .msg = msg });
                    }
                }

                // 3. done task whose holds paths are not in git ls-files → commit these
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

                // T217: done task with no acceptance= declared — WARN
                if (ts.acceptance == null and ts.skip_acceptance_reason == null) {
                    const msg = try std.fmt.allocPrint(alloc, "done but no acceptance= declared — task had no runnable green condition", .{});
                    try findings.append(alloc, .{ .level = "WARN", .id = tid, .msg = msg });
                }
                // T295: surface --skip-acceptance uses so they stay visible
                if (ts.skip_acceptance_reason) |reason| {
                    const msg = try std.fmt.allocPrint(alloc, "closed with --skip-acceptance — acceptance check was bypassed: {s}", .{reason});
                    try findings.append(alloc, .{ .level = "WARN", .id = tid, .msg = msg });
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

        // ── T390: dirty deliverables on a row nobody holds ──
        // A done or dispatchable row whose bundle deliverables= paths are
        // dirty in the working tree is evidence of unclaimed work: the T389
        // shape (second console editing a committed deliverable of an
        // already-closed row) or the T367 shape (working without ever
        // claiming).  dispatchable rows get an exists-on-disk filter — their
        // deliverables legitimately do not exist yet (the row has not
        // started); only an existing-and-dirty file is evidence of work.
        // blocked/abandoned done rows never carried deliverables (the done
        // gate exempts them by design) — checking their never-created paths
        // would be noise, not hazard (T361, T379, T349).
        const t390_exempt_verdict = eff == .done and ts.verdict != null and
            (std.mem.eql(u8, ts.verdict.?, "blocked") or std.mem.eql(u8, ts.verdict.?, "abandoned"));
        if (!t390_exempt_verdict and (eff == .done or eff == .dispatchable)) {
            const bundle_abs3 = if (std.fs.path.isAbsolute(ts.bundle))
                try alloc.dupe(u8, ts.bundle)
            else
                try std.fs.path.join(alloc, &.{ repo_root, ts.bundle });
            defer alloc.free(bundle_abs3);
            const dlvs = try parseDeliverablesFromBundle(w, io, bundle_abs3, ts.holds);
            defer {
                for (dlvs) |d| alloc.free(d);
                alloc.free(dlvs);
            }
            for (dlvs) |d| {
                // T390: skip the kanban's own store files — managent writes
                // tasks.json / directives.jsonl / heartbeat.jsonl on every
                // claim/dispatch/close, so their dirtiness is the live
                // kanban's normal state, not unclaimed work (the same
                // exclusion treeDirty applies to its dirty counts).
                if (std.mem.indexOf(u8, d, "tasks.json") != null or
                    std.mem.indexOf(u8, d, "directives.jsonl") != null or
                    std.mem.indexOf(u8, d, "heartbeat.jsonl") != null) continue;
                const v = deliverableVerdict(io, repo_root, d);
                if (v.ok) continue;
                if (eff == .dispatchable) {
                    const d_abs = if (std.fs.path.isAbsolute(d))
                        (alloc.dupe(u8, d) catch continue)
                    else
                        (std.fs.path.join(alloc, &.{ repo_root, d }) catch continue);
                    defer alloc.free(d_abs);
                    const exists = std.Io.Dir.cwd().statFile(io, d_abs, .{}) catch null;
                    if (exists == null) continue; // not created yet — normal for an unstarted row
                }
                const msg = try std.fmt.allocPrint(alloc, "{s} but deliverable '{s}' is dirty — {s} (unclaimed work on this row)", .{ statusToString(eff), d, v.reason });
                try findings.append(alloc, .{ .level = "FIX", .id = tid, .msg = msg });
            }
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

        // ── T213: verdict audit — pass-with-findings or fail-found must name a follow-up task ──
        if (ts.verdict) |v| {
            if (std.mem.eql(u8, v, "pass-with-findings") or std.mem.eql(u8, v, "fail-found")) {
                const note_text = ts.verdict_note orelse "";
                // Check for a T-reference (T followed by digits)
                var has_followup = false;
                var ci: usize = 0;
                while (ci < note_text.len) {
                    if (note_text[ci] == 'T' and ci + 1 < note_text.len and note_text[ci + 1] >= '0' and note_text[ci + 1] <= '9') {
                        has_followup = true;
                        break;
                    }
                    ci += 1;
                }
                if (!has_followup) {
                    const msg = try std.fmt.allocPrint(alloc, "verdict '{s}' but verdict_note names no follow-up task (no T-reference) — finding may be lost", .{v});
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

    // ── T486: absorption partition (absorption-spec §8) ──────────────────
    // Join claimlint's `c7 --json` against the live kanban + archive. A closed
    // task carrying unabsorbed/non-conforming findings is a crisis — with the
    // done gate (T485) live it can only mean someone went around the mechanism
    // — so each closed-partition file is a FIX finding naming the file. The
    // open partition is healthy in-flight work: informational, never a gate.
    {
        const archive_path = try std.fs.path.join(alloc, &.{ repo_root, "docs", "infra", "managent", "archive.json" });
        defer alloc.free(archive_path);
        var archive_state = try readState(io, archive_path);
        defer freeState(&archive_state);

        var part = computeAbsorptionPartition(io, repo_root, &state, &archive_state) catch |e| blk: {
            const msg = try std.fmt.allocPrint(alloc, "absorption partition unavailable — claimlint c7 --json failed ({s}); the closed-partition alarm is blind", .{@errorName(e)});
            try findings.append(alloc, .{ .level = "FIX", .id = "absorption-partition", .msg = msg });
            break :blk AbsorptionPartition{ .closed = std.ArrayList(PartitionEntry).empty, .open_files = 0, .open_unabsorbed = 0 };
        };
        defer freeAbsorptionPartition(&part);

        for (part.closed.items) |e| {
            const msg = if (e.nonconforming)
                try std.fmt.allocPrint(alloc, "closed-partition drift: '{s}' is non-conforming on closed task {s} — mechanism bypass (absorption-spec §8)", .{ e.path, e.task_id })
            else
                try std.fmt.allocPrint(alloc, "closed-partition drift: '{s}' carries {d} unabsorbed proposal(s) on closed task {s} — mechanism bypass (absorption-spec §8)", .{ e.path, e.unabsorbed, e.task_id });
            // id is a stable literal, NOT e.task_id: the partition strings are
            // freed at the end of this block (defer below), while the findings'
            // .id/.msg are emitted later — a slice into part.closed would be a
            // use-after-free at the output emission.
            try findings.append(alloc, .{ .level = "FIX", .id = "absorption-partition", .msg = msg });
        }

        // Open partition is informational — surfaced on the data channel in
        // human mode (never a finding); --json consumers get findings only.
        if (!use_json) {
            w.data("  absorption partition: closed {d}, open {d} file(s) / {d} unabsorbed proposal(s)\n", .{ part.closed.items.len, part.open_files, part.open_unabsorbed });
        }
    }

    if (use_json) {
        w.data("[\n", .{});
        for (findings.items, 0..) |f, fi| {
            if (fi > 0) w.data(",\n", .{});
            // T399: findings can embed free text (deliverable paths, hold
            // names, skip-acceptance reasons) — escape before emitting JSON.
            const lvl = try jsonString(f.level);
            defer alloc.free(lvl);
            const fid = try jsonString(f.id);
            defer alloc.free(fid);
            const fmsg = try jsonString(f.msg);
            defer alloc.free(fmsg);
            w.data("  {{\"level\":{s},\"id\":{s},\"msg\":{s}}}", .{ lvl, fid, fmsg });
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

// T486 (absorption-spec §8): ABSORB_C7_THRESHOLD is retired. The threshold
// conflated the open partition (healthy in-flight work) with the closed
// partition (a crisis). STANDING-ABSORB's trigger is now closed-partition > 0
// — see computeAbsorptionPartition below.

const standing_templates = [_]Standing{
    .{ .id = "STANDING-HOLISTIC-AUDIT", .set = 'H', .needs = &.{}, .brief_path = "docs/infra/dispatch/STANDING-HOLISTIC-AUDIT.md" },
    .{ .id = "STANDING-CLEANUP", .set = 'H', .needs = &.{}, .brief_path = "docs/infra/dispatch/STANDING-CLEANUP.md" },
    .{ .id = "STANDING-REEVIDENCE", .set = 'H', .needs = &.{}, .brief_path = "docs/infra/dispatch/STANDING-REEVIDENCE.md" },
    .{ .id = "STANDING-CONSOLIDATE", .set = 'H', .needs = &.{}, .brief_path = "docs/infra/dispatch/STANDING-CONSOLIDATE.md" },
    .{ .id = "STANDING-ABSORB", .set = 'H', .needs = &.{}, .brief_path = "docs/infra/dispatch/STANDING-ABSORB.md" },
};

/// Parse the first digit-run after `label` from claimlint's `== SUMMARY ==`
/// block (the canonical machine-consumable section — the same block the
/// pre-commit hook's awk and the resume surface read). Scoping to the
/// SUMMARY block keeps a drift in claimlint's detail sections from being
/// mistaken for a summary reading. Returns null when the label is absent
/// (marker drifted) or the value is not numeric — callers MUST treat null
/// as a loud failure, never as zero (T368).
fn parseSummaryCount(output: []const u8, label: []const u8) ?u64 {
    var lines = std.mem.splitScalar(u8, output, '\n');
    var in_summary = false;
    while (lines.next()) |line| {
        if (std.mem.indexOf(u8, line, "== SUMMARY ==") != null) {
            in_summary = true;
            continue;
        }
        if (!in_summary) continue;
        if (std.mem.indexOf(u8, line, label)) |idx| {
            const after = std.mem.trim(u8, line[idx + label.len ..], " \t\r");
            var digits: usize = 0;
            while (digits < after.len and after[digits] >= '0' and after[digits] <= '9') digits += 1;
            if (digits == 0) return null;
            return std.fmt.parseInt(u64, after[0..digits], 10) catch null;
        }
    }
    return null;
}

/// Extract a task ID from a findings filename per findings/README.md's
/// `<TASKID>-<slug>.json` convention: "T129-qa027.json" → "T129".
fn taskIdFromFindingsPath(path: []const u8) ?[]const u8 {
    const base = std.fs.path.basename(path);
    if (base.len < 2 or base[0] != 'T') return null;
    var i: usize = 1;
    while (i < base.len) : (i += 1) {
        const c = base[i];
        if (!((c >= '0' and c <= '9') or (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z') or c == '_')) break;
    }
    if (i <= 1) return null;
    return base[0..i];
}

// ── T486: the absorption partition (absorption-spec §8) ────────────────────
// The retired threshold conflated two classes of unabsorbed findings —
// in-flight work of open tasks (healthy) and drift of closed tasks (a
// crisis). The partition splits them. claimlint stays kanban-free: its
// `c7 --json` report names every findings file with its owning task id,
// conforming flag and unabsorbed proposals; managent supplies the row-status
// knowledge by joining against the live kanban + archive. A file is in the
// CLOSED partition when it is non-conforming or carries unabsorbed proposals
// AND its owning task is done/failed/archived. Everything else with drift is
// the OPEN partition — healthy in-flight work, surfaced informationally only.

const PartitionEntry = struct {
    path: []const u8,
    task_id: []const u8,
    nonconforming: bool,
    unabsorbed: u64,
};

const AbsorptionPartition = struct {
    closed: std.ArrayList(PartitionEntry),
    open_files: u64,
    open_unabsorbed: u64,
};

fn freeAbsorptionPartition(p: *AbsorptionPartition) void {
    for (p.closed.items) |e| {
        alloc.free(e.path);
        alloc.free(e.task_id);
    }
    p.closed.deinit(alloc);
}

/// A task id is "closed" when its row is done/failed in the live kanban, or
/// lives in the archive (archive only ever admits done/failed rows).
fn taskIsClosed(live: *const StateMap, archive: *const StateMap, tid: []const u8) bool {
    if (tid.len == 0) return false;
    if (archive.get(tid) != null) return true;
    if (live.get(tid)) |ts| return ts.status == .done or ts.status == .failed;
    return false;
}

/// Join claimlint's `c7 --json` report against the live kanban + archive and
/// return the absorption partition. Callers MUST treat an error as a blind
/// alarm (loud failure), never as an empty partition (a silent 0 is how a
/// trigger dies — T368).
fn computeAbsorptionPartition(
    io: std.Io,
    repo_root: []const u8,
    live: *const StateMap,
    archive: *const StateMap,
) !AbsorptionPartition {
    const result = std.process.run(alloc, io, .{
        .argv = &.{ "bin/weizigo-claimlint", "c7", "--json" },
        .cwd = .{ .path = repo_root },
    }) catch return error.ClaimlintSpawnFailed;
    defer alloc.free(result.stdout);
    defer alloc.free(result.stderr);

    const code: u8 = switch (result.term) {
        .exited => |c| c,
        else => 255,
    };
    if (code == 3) return error.ClaimlintRegisterUnreadable;
    if (code != 0 and code != 1) return error.ClaimlintUnexpectedExit;

    var part = AbsorptionPartition{ .closed = std.ArrayList(PartitionEntry).empty, .open_files = 0, .open_unabsorbed = 0 };
    errdefer freeAbsorptionPartition(&part);

    // Exit 0: nothing non-conforming and nothing unabsorbed ANYWHERE — the
    // partition is empty by construction (closed and open alike).
    if (code == 0) return part;

    var parsed = std.json.parseFromSlice(std.json.Value, alloc, result.stdout, .{ .allocate = .alloc_always }) catch return error.ClaimlintJsonUnparseable;
    defer parsed.deinit();
    if (parsed.value != .array) return error.ClaimlintJsonNotArray;

    for (parsed.value.array.items) |pf| {
        if (pf != .object) continue;
        const obj = pf.object;
        const path = runRecStr(obj, "path");
        const declared = runRecOptStr(obj, "task_id") orelse "";
        const conforming = if (obj.get("conforming")) |v| v == .bool and v.bool else true;
        var unabsorbed: u64 = 0;
        if (obj.get("unabsorbed")) |ua| {
            if (ua == .array) unabsorbed = ua.array.items.len;
        }
        if (conforming and unabsorbed == 0) continue;

        // Owning task: the declared task_id, else the filename-derived id
        // (absorption-spec §12: a misnamed orphan whose filename names a
        // closed task still surfaces in the closed partition).
        const file_tid = taskIdFromFindingsPath(path);
        const closed = taskIsClosed(live, archive, declared) or
            (if (file_tid) |ft| taskIsClosed(live, archive, ft) else false);

        if (closed) {
            try part.closed.append(alloc, PartitionEntry{
                .path = try alloc.dupe(u8, path),
                .task_id = try alloc.dupe(u8, if (declared.len > 0) declared else (file_tid orelse "")),
                .nonconforming = !conforming,
                .unabsorbed = unabsorbed,
            });
        } else {
            part.open_files += 1;
            part.open_unabsorbed += unabsorbed;
        }
    }
    return part;
}

fn cmdStanding(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    _ = args;

    // T545: the whole read→trigger→register→persist sequence runs under the
    // store flock.  The previous code read the store UNLOCKED and wrote via
    // writeState (registerStanding, lock only around each write) plus raw
    // file surgery (persistStandingState, no lock at all), so a concurrent
    // claim/close/done could be reverted by `standing`'s whole-file writes.
    // The flock is released by process exit on the early-exit paths below.
    try lockStore(io, state_path);
    defer unlockStore();

    var state = try readState(io, state_path);

    // ── detect triggers ──

    // Trigger 1: claimlint C3 debt (for STANDING-REEVIDENCE).
    // T368: the marker must match claimlint's CURRENT summary line
    // ("  C3 PROVEN w/o committed evid. {d} ..."). The old "C3: " marker
    // never matched any claimlint output (CODE.STANDING-C3-DEAD), so the
    // reading was a silent 0 from birth. Parse the == SUMMARY == block (the
    // machine-consumable section the pre-commit hook's awk also reads) and
    // fail LOUDLY when the marker is absent — a silent 0 is how a standing
    // trigger dies without anyone noticing.
    var c3_debt: u64 = 0;
    var c3_prior: u64 = 0;
    const c3_marker = "C3 PROVEN w/o committed evid.";
    const claimlint_result = runCommand(alloc, io, &.{"bin/weizigo-claimlint"}) catch |e| {
        w.diag("  standing: cannot run bin/weizigo-claimlint for the C3 trigger / absorption partition ({s})\n", .{@errorName(e)});
        w.diag("  Build it (zig build) — the standing C3/partition readings are unavailable.\n", .{});
        std.process.exit(1);
    };
    defer alloc.free(claimlint_result);
    var c3_marker_missing = false;
    if (parseSummaryCount(claimlint_result, c3_marker)) |v| {
        c3_debt = v;
    } else {
        c3_marker_missing = true;
        w.diag("  WARNING: claimlint marker '{s}' not found in its == SUMMARY == block — STANDING-REEVIDENCE reading UNRELIABLE\n", .{c3_marker});
    }

    // Trigger 1b: the absorption partition (for STANDING-ABSORB).
    // T486 (absorption-spec §8): the C7 threshold is retired — the trigger is
    // now CLOSED-partition > 0, a crisis signal for mechanism bypass, not a
    // chore threshold. The partition is computed from claimlint's own
    // `c7 --json` (one count, one implementation — the T294 rule) joined
    // against the live kanban + archive, which only managent knows. A blind
    // partition (claimlint unavailable/unparseable) is a loud failure below,
    // never a silent 0.
    var partition_blind: bool = false;
    var partition_blind_reason: []const u8 = "";
    var partition: AbsorptionPartition = undefined;
    {
        const archive_path = try std.fs.path.join(alloc, &.{ repo_root, "docs", "infra", "managent", "archive.json" });
        defer alloc.free(archive_path);
        var archive_state = try readState(io, archive_path);
        defer freeState(&archive_state);

        partition = computeAbsorptionPartition(io, repo_root, &state, &archive_state) catch |e| blk: {
            partition_blind = true;
            partition_blind_reason = @errorName(e);
            w.diag("  WARNING: absorption partition unavailable ({s}) — STANDING-ABSORB reading UNRELIABLE\n", .{@errorName(e)});
            break :blk AbsorptionPartition{ .closed = std.ArrayList(PartitionEntry).empty, .open_files = 0, .open_unabsorbed = 0 };
        };
    }
    defer freeAbsorptionPartition(&partition);

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

    // Trigger 4: tree dirty — git diff --stat line count (T210 D2: exclude tasks.json)
    var dirty_files: u64 = 0;
    var dirty_prior: u64 = 0;
    {
        const diff_result = try runCommand(alloc, io, &.{ "git", "-C", repo_root, "diff", "--stat" });
        defer alloc.free(diff_result);
        var dlines = std.mem.splitScalar(u8, diff_result, '\n');
        while (dlines.next()) |line| {
            if (line.len == 0) continue;
            // Summary line has no "|" (e.g. " 3 files changed, 12 insertions(+)")
            if (std.mem.indexOf(u8, line, "|") == null) continue;
            // Exclude managent's own writes to tasks.json (sync, standing)
            if (std.mem.indexOf(u8, line, "tasks.json") != null) continue;
            dirty_files += 1;
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
    if (c3_marker_missing) {
        w.data("    STANDING-REEVIDENCE      C3 debt: UNRELIABLE (marker '{s}' not found in claimlint summary)", .{c3_marker});
        w.data("\n", .{});
    } else {
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

    // STANDING-ABSORB: trigger when the CLOSED partition is non-empty
    // (absorption-spec §8). A non-zero closed partition is a crisis — with the
    // done gate (T485) live, a closed task carrying unabsorbed or
    // non-conforming findings can only mean someone went around the mechanism.
    // The open partition is healthy in-flight work and never triggers.
    if (partition_blind) {
        w.data("    STANDING-ABSORB          closed partition: UNRELIABLE (claimlint c7 --json: {s})", .{partition_blind_reason});
        w.data("\n", .{});
    } else {
        const closed_count = partition.closed.items.len;
        w.data("    STANDING-ABSORB          closed partition: {d} (open: {d} file(s), {d} unabsorbed)", .{ closed_count, partition.open_files, partition.open_unabsorbed });
        if (closed_count > 0) {
            w.data(" [TRIGGERED — closed partition above zero]", .{});
            // Per-file composition so triage happens before work starts.
            w.data("\n        closed files:", .{});
            for (partition.closed.items) |e| {
                if (e.nonconforming) {
                    w.data("  {s} (non-conforming, task {s})", .{ e.path, e.task_id });
                } else {
                    w.data("  {s} ({d} unabsorbed, task {s})", .{ e.path, e.unabsorbed, e.task_id });
                }
            }
            try registerStanding(w, io, repo_root, state_path, &state, "STANDING-ABSORB", "closed partition: {d} file(s) on closed task(s) with unabsorbed/non-conforming findings", .{closed_count});
        } else {
            w.data(" — closed partition is empty, no trigger", .{});
        }
        w.data("\n", .{});
    }

    // ── marker guard (T368): a missing claimlint signal is a broken ──
    // mechanism, not a zero reading. The T356 rename killed C7's marker and
    // C7 read 0 for a day while STANDING-ABSORB silently could not fire;
    // C3's marker was dead since birth (CODE.STANDING-C3-DEAD). The partition
    // (T486) is read from `c7 --json`; a claimlint that cannot produce it is
    // the same class of blind alarm — exit loudly so the next rename breaks a
    // run, not a mechanism.
    if (c3_marker_missing or partition_blind) {
        w.diag("\n  standing: FATAL — claimlint output does not carry every signal this build parses.\n", .{});
        w.diag("  The affected C3/partition readings above are UNRELIABLE; no trigger was evaluated from them.\n", .{});
        w.diag("  Re-point the markers/JSON consumption in src/managent/main.zig against a fresh `bin/weizigo-claimlint`\n", .{});
        w.diag("  run (the standing regression tests guard the exact contract), then rebuild + redeploy.\n", .{});
        std.process.exit(1);
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
    const note = try std.fmt.allocPrint(alloc, note_fmt, note_args);

    // T406: a triggered standing task whose row is `done` (or `failed`) must
    // be RE-REGISTERED as a dispatchable instance — the standing tier is
    // recurring, and `done` was absorbing every future trigger ("already
    // registered, skipping" while the absorption backlog sat at 8 and was
    // cleared only by hand). We reopen the one canonical row rather than
    // minting a fresh ID: the standing IDs are wired into standing_templates,
    // docs/infra/dispatch/STANDING-*.md, and the CODE.STANDING-* register
    // classes, so a fresh ID per recurrence would multiply those surfaces
    // without bound and orphan the historical row.
    //
    // A LIVE instance (dispatchable / in_progress / blocked) is NOT reopened:
    // a second instance would be a duplicate dispatch (T390) and two writers
    // on one standing task. That refusal must read as the inaction it is —
    // never a bare "(already registered, skipping)" sitting under a TRIGGERED
    // line, which reads as status and hides a dead trigger.
    if (state.getPtr(id)) |existing| {
        if (existing.status == .done or existing.status == .failed) {
            const prev = existing.status;
            existing.status = .dispatchable;
            existing.agent = null;
            existing.claimed = null;
            existing.done = null;
            existing.dispatched = null;
            existing.dispatched_to = null;
            if (existing.verdict) |v| {
                alloc.free(v);
                existing.verdict = null;
            }
            if (existing.verdict_note) |vn| {
                alloc.free(vn);
                existing.verdict_note = null;
            }
            if (existing.note) |old| alloc.free(old);
            existing.note = try alloc.dupe(u8, note);
            // T545: writeStateLocked — the caller (cmdStanding) already holds
            // the flock; writeState would re-flock a second fd and deadlock
            // against itself.  The read→write span is under the caller's lock.
            try writeStateLocked(io, state_path, state);
            w.data("\n      re-registered {s} [set: H] [dispatchable] (was {s} — standing triggers re-open the row)\n", .{ id, statusToString(prev) });
            return;
        }
        w.diag("      {s} is {s} — NOT re-registered (a live {s} instance already exists; the standing tier keeps one row per task, and a second would be a duplicate dispatch)\n", .{ id, statusToString(existing.status), id });
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
    const ts = TaskState{
        .status = .dispatchable,
        .agent = null,
        .bundle = brief_md,
        .set = 'H',
        .holds = &.{},
        .needs = &.{},
        .caps = &.{},
        .shape = try alloc.dupe(u8, "solo"),
        .added = now,
        .claimed = null,
        .done = null,
        .dispatched = null,
        .dispatched_to = null,
        .note = note,
    };
    try state.put(alloc, try alloc.dupe(u8, id), ts);
    // T545: writeStateLocked — same reasoning as the re-register path above:
    // cmdStanding holds the flock across the whole read→register→persist span.
    try writeStateLocked(io, state_path, state);
    w.data("\n      registered {s} [set: H] [dispatchable]", .{id});
}

fn persistStandingState(io: std.Io, state_path: []const u8, c3: u64, msg: u64, false_cnt: u64, dirty: u64) !void {
    // T545: this raw read→surgery→rename rewrites the WHOLE store file.  It
    // is safe only because the sole caller (cmdStanding) holds the store
    // flock across the entire sequence — do NOT call it from an unlocked
    // path.  (Known sibling defect, out of scope for T545: serializeState
    // drops the `_standing`/`_sync` keys, so any later writeStateLocked from
    // another command erases them until the next standing/sync run rewrites
    // them; the standing trigger priors therefore read 0 after any other
    // store write.  A first-class `_standing` in StateMap is the real fix.)
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

// ═══════════════════════════════════════════════════════════════════════════════
// WORKER-CHANNEL commands (2026-07-29)
// ═══════════════════════════════════════════════════════════════════════════════

// ── tell <target> <directive> — post a directive to a worker ─────────────────

fn cmdTell(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    if (args.len < 4) {
        w.diag("usage: managent tell <target> <pause|resume|kill|amend|question> [--note <text>] [--from <who>] [--until-done <T-id>]\n", .{});
        w.diag("  --until-done <T-id>  (pause only, T625): enforce until <T-id> is done in the kanban\n", .{});
        std.process.exit(1);
    }
    const target = args[2];
    const directive = args[3];

    if (!isValidDirective(directive)) {
        w.diag("error: invalid directive '{s}'\n", .{directive});
        std.process.exit(1);
    }

    const note_text = getFlagValue(args, "--note");
    const from_who = getFlagValue(args, "--from") orelse "unknown";

    // T625: `--until-done <row>` — a machine-checkable discharge condition
    // for a `pause`.  Valid for pause only (a kill is an unconditional
    // halt; amend/question are not enforced), the row must be a T-id, and
    // it must not name the pause's own target (a self-blocking pause can
    // never discharge).
    const until_done_raw = getFlagValue(args, "--until-done");
    var until_done: ?[]const u8 = null;
    if (until_done_raw) |ud| {
        if (!std.mem.eql(u8, directive, "pause")) {
            w.diag("error: --until-done is valid only for a pause directive (got '{s}')\n", .{directive});
            std.process.exit(1);
        }
        if (!isTaskId(ud)) {
            w.diag("error: --until-done must name a T<id> row, got '{s}'\n", .{ud});
            std.process.exit(1);
        }
        if (std.mem.eql(u8, ud, target)) {
            w.diag("error: --until-done cannot name the pause's own target ({s}) — it would never discharge\n", .{target});
            std.process.exit(1);
        }
        until_done = ud;
    }

    // T545: the whole read→mint→append→counter-persist→verify sequence runs
    // under the store flock.  cmdTell previously read the store BEFORE the
    // lock and wrote the stale snapshot back via writeState (lock only around
    // the write), so any overlapping claim/close/attribution was silently
    // reverted.  Observed 2026-08-20: 4 tells in ~3 minutes with 14 live
    // workers — zero directives reached their inboxes, D042/D043 were minted
    // twice, and _sys.directive_next moved BACKWARDS 44 → 43 (a counter that
    // decrements is a lost-update race, not a display bug).
    try lockStore(io, state_path);
    defer unlockStore();

    // Re-read under the lock: loads the CURRENT directive counter.
    var state_for_counter = try readState(io, state_path);
    defer freeState(&state_for_counter);

    // T758: mint from max(counter, ledger_max + 1).  The counter alone is not
    // authoritative — _sys.directive_next lives in tasks.json, a different
    // file from the ledger, and a direct store write / restore rolls it back
    // below ids the ledger already holds (observed 55→21, 34→21; ledger max
    // D079 vs counter 21).  Minting from the stale counter is what re-minted
    // D041 a third time on 2026-08-23T01:57:43Z.
    const base = @max(sys_directive_next, maxDirectiveId(w, io, repo_root, state_path) + 1);
    const d_id = try std.fmt.allocPrint(alloc, "D{d:0>3}", .{base});
    sys_directive_next = base + 1;

    const now = try nowTimestamp();

    const d = Directive{
        .id = try alloc.dupe(u8, d_id),
        .target = try alloc.dupe(u8, target),
        .directive = try alloc.dupe(u8, directive),
        .note = if (note_text) |nt| try alloc.dupe(u8, nt) else null,
        .from = try alloc.dupe(u8, from_who),
        .ts = try alloc.dupe(u8, now),
        .read = false,
        .until_done = if (until_done) |ud| try alloc.dupe(u8, ud) else null,
    };

    appendDirective(w, io, repo_root, d) catch |err| {
        w.diag("  FAILED: directive not written ({s}) — nothing was appended to the ledger\n", .{@errorName(err)});
        std.process.exit(1);
    };

    // Persist the updated directive counter — writeStateLocked, because the
    // flock above is already held.  The snapshot is fresh (read under the
    // lock), so no concurrent change can be reverted.
    try writeStateLocked(io, state_path, &state_for_counter);

    // T545: a directive must never be silently lost.  Verify it is readable
    // back from the ledger and fail loudly if not — `tell` printing success
    // for a directive that never landed is what hid the 2026-08-20 incident.
    if (!directiveIsReadable(w, io, repo_root, state_path, d_id)) {
        w.diag("FATAL: directive {s} is NOT readable back from the ledger after write — it was LOST.  The counter has already advanced; do not blindly retell (check the ledger first).\n", .{d_id});
        std.process.exit(1);
    }

    w.diag("\n  told {s} -> {s}\n", .{ target, directive });
    w.diag("  directive {s}\n", .{d_id});
    if (note_text) |nt| w.diag("  note: {s}\n", .{nt});
    if (until_done) |ud| {
        w.diag("  until-done: enforced until {s} is done (re-evaluated at every apply)\n", .{ud});
    } else if (std.mem.eql(u8, directive, "pause")) {
        w.diag("  until-done: none — this pause has no discharge condition; it is enforced until acked,\n", .{});
        w.diag("    or reported stale after the staleness horizon (tools/directive_policy.py).\n", .{});
        w.diag("    Prefer `--until-done <row>` so the pause discharges itself.\n", .{});
    }
}

/// T545: a directive must never be silently lost.  Returns true iff a record
/// with the given id is readable back from the directives ledger (the same
/// reader cmdInbox uses — T399 parse-resilient).  Called under the store lock
/// right after the append + store write, so the ledger is stable.
fn directiveIsReadable(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, d_id: []const u8) bool {
    var bad: u32 = 0;
    var list = readDirectives(w, io, repo_root, state_path, &bad) catch return false;
    defer {
        for (list.items) |d| {
            alloc.free(d.id);
            alloc.free(d.target);
            alloc.free(d.directive);
            if (d.note) |n| alloc.free(n);
            alloc.free(d.from);
            alloc.free(d.ts);
            if (d.until_done) |ud| alloc.free(ud);
        }
        list.deinit(alloc);
    }
    for (list.items) |d| {
        if (std.mem.eql(u8, d.id, d_id)) return true;
    }
    return false;
}

// ── assert <row> <status> [--note <text>] — assert a row's status ────────────
//
// T441: the observation layer must say only what it can support.  This
// command writes an assertion record to docs/infra/assertion-ledger/assertions.jsonl
// recording who asserted a row's status, what status, when, and why.
// The assertion log is append-only: later assertions supersede earlier ones;
// absence of an assertion is UNKNOWN, never "none".

fn cmdAssert(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    _ = repo_root; // T518: the assertion ledger is now derived from state_path.
    if (args.len < 4) {
        w.diag("usage: managent assert <row> <status> [--note <text>]\n", .{});
        w.diag("  status: dispatchable | in_progress | done | absorbed | recommended-close | closed\n", .{});
        std.process.exit(1);
    }
    const target = args[2];
    const status_val = args[3];

    const valid_statuses = [_][]const u8{ "dispatchable", "in_progress", "done", "absorbed", "recommended-close", "closed" };
    var status_ok = false;
    for (valid_statuses) |vs| {
        if (std.mem.eql(u8, vs, status_val)) { status_ok = true; break; }
    }
    if (!status_ok) {
        w.diag("error: invalid status '{s}' — must be one of: dispatchable, in_progress, done, absorbed, recommended-close, closed\n", .{status_val});
        std.process.exit(1);
    }

    const note_text = getFlagValue(args, "--note");

    // Resolve identity — same as claim/done: MANAGENT_TASK_ID or PI_MODEL
    const actor = if (std.c.getenv("MANAGENT_TASK_ID")) |ptr|
        std.mem.sliceTo(ptr, 0)
    else if (std.c.getenv("PI_MODEL")) |ptr|
        std.mem.sliceTo(ptr, 0)
    else
        "unknown";

    // T545: the assertion-counter read must sit under the same lock as the
    // write.  The previous code read the store BEFORE lockStore and then
    // wrote the STALE snapshot via writeStateLocked — the same lost-update
    // shape as cmdTell (reverts any concurrent claim/close that lands between
    // the read and the lock).  T544 should test this same mechanism for the
    // `model: null` backfill loss.
    try lockStore(io, state_path);
    defer unlockStore();
    var state_for_counter = try readState(io, state_path);
    defer freeState(&state_for_counter);

    const a_id = try std.fmt.allocPrint(alloc, "A{d:0>4}", .{sys_assertion_next});
    sys_assertion_next += 1;

    const now = try nowTimestamp();

    const a = Assertion{
        .id = try alloc.dupe(u8, a_id),
        .ts = try alloc.dupe(u8, now),
        .actor = try alloc.dupe(u8, actor),
        .verb = try alloc.dupe(u8, "asserted"),
        .object = try alloc.dupe(u8, target),
        .basis = try alloc.dupe(u8, "performed"),
        .status_value = try alloc.dupe(u8, status_val),
        .note = if (note_text) |nt| try alloc.dupe(u8, nt) else null,
    };

    // Write assertion under the same lock as the kanban
    appendAssertion(w, io, state_path, a) catch |err| {
        w.diag("  FAILED: assertion not written ({s}) — nothing was appended to the ledger\n", .{@errorName(err)});
        std.process.exit(1);
    };

    // Persist the updated assertion counter
    try writeStateLocked(io, state_path, &state_for_counter);

    w.diag("\n  asserted {s} -> {s}\n", .{ target, status_val });
    w.diag("  assertion {s}\n", .{a_id});
    w.diag("  (annotation only — status comes from the kanban store; this assertion does not override it)\n", .{});
    if (note_text) |nt| w.diag("  note: {s}\n", .{nt});
}

// ── inbox [<target>] [--ack] — show pending directives, optionally ack ──────
//
// T352: a worker that just read the inbox (--ack) signals to the resume
// surface that this directive is no longer fleet-stalling; without --ack the
// directive stays unread and keeps showing in `managent resume` so the
// operator can see stalls from a live console.  --ack is scoped: it acks
// only the directives matching the optional <target> and the current
// read=false state, so two workers polling their own inboxes do not
// collide.  Acks are recorded in-place in docs/infra/managent/directives.jsonl
// under the same flock as the kanban (lockStore/writeStateLocked — A3).
fn cmdInbox(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    var target: []const u8 = "";
    var ack = false;
    var all_flag = false;
    var i: usize = 2;
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (std.mem.eql(u8, a, "--ack")) {
            ack = true;
        } else if (std.mem.eql(u8, a, "--all")) {
            all_flag = true;
        } else if (!std.mem.startsWith(u8, a, "-")) {
            target = a;
        }
    }

    // T441: targetless ack is a footgun — it marks every row's directives
    // read.  Require an explicit --all to ack across all targets.
    if (ack and target.len == 0 and !all_flag) {
        w.diag("error: 'inbox --ack' without a target would mark every row's directives read.\n", .{});
        w.diag("  Use 'inbox <target> --ack' to ack one row, or 'inbox --all --ack' to ack all.\n", .{});
        w.diag("  Display-only (no --ack) is allowed without a target.\n", .{});
        std.process.exit(1);
    }

    var directives = try readDirectives(w, io, repo_root, state_path, null);
    defer {
        for (directives.items) |d| {
            alloc.free(d.id);
            alloc.free(d.target);
            alloc.free(d.directive);
            if (d.note) |n| alloc.free(n);
            alloc.free(d.from);
            alloc.free(d.ts);
            if (d.until_done) |ud| alloc.free(ud);
        }
        directives.deinit(alloc);
    }

    var found: u32 = 0;
    // Show unread directives
    for (directives.items) |d| {
        if (target.len > 0 and !std.mem.eql(u8, d.target, target)) continue;
        if (d.read) continue;
        if (found == 0) {
            w.data("\n  Directives", .{});
            if (target.len > 0) w.data(" for '{s}'", .{target});
            w.data(":\n", .{});
        }
        found += 1;
        w.data("    {s}  {s}  from {s}  at {s}\n", .{ d.id, d.directive, d.from, d.ts });
        if (d.note) |n| w.data("      note: {s}\n", .{n});
        if (d.until_done) |ud| w.data("      until_done: {s} (enforced until done)\n", .{ud});
    }
    if (found == 0) {
        w.data("  -- no pending directives --\n", .{});
    }
    w.data("\n", .{});

    if (ack) {
        // Mark the matching directives as read in-place.  Re-read the file
        // (the read above freed nothing; the .jsonl lines are still on disk
        // unchanged), then write a new content stream with read=true on
        // the matching IDs.
        try lockStore(io, state_path);
        defer unlockStore();
        const dir_path = try std.fs.path.join(alloc, &.{ repo_root, DIRECTIVES_FILE });
        defer alloc.free(dir_path);
        const content = std.Io.Dir.cwd().readFileAlloc(io, dir_path, alloc, .unlimited) catch "";
        defer if (@intFromPtr(content.ptr) != @intFromPtr("".ptr)) alloc.free(content);

        // Build the set of IDs to ack (in display order; we already
        // enumerated them above).  We re-read from the file rather than
        // re-using `directives` because parse-free mutation is safer than
        // a second pass that could miss a corner-case.
        var lines = std.mem.splitScalar(u8, content, '\n');
        var out = std.ArrayList(u8).empty;
        defer out.deinit(alloc);
        var acked: u32 = 0;
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \r\n");
            if (trimmed.len == 0) {
                if (out.items.len > 0) try out.append(alloc, '\n');
                continue;
            }
            // Cheap parse: extract id, target, and current read flag.
            var parsed = std.json.parseFromSlice(std.json.Value, alloc, trimmed, .{ .allocate = .alloc_always }) catch {
                try out.appendSlice(alloc, line);
                try out.append(alloc, '\n');
                continue;
            };
            defer parsed.deinit();
            if (parsed.value != .object) {
                try out.appendSlice(alloc, line);
                try out.append(alloc, '\n');
                continue;
            }
            const obj = parsed.value.object;
            const d_id = if (obj.get("id")) |v| if (v == .string) v.string else "" else "";
            const d_target = if (obj.get("target")) |v| if (v == .string) v.string else "" else "";
            const d_read = if (obj.get("read")) |v| if (v == .bool) v.bool else false else false;

            const match = !d_read and
                d_id.len > 0 and
                (all_flag or target.len == 0 or std.mem.eql(u8, d_target, target));
            if (match) {
                // Re-serialise with read:true + read_by + read_at.
                // T399: parsed values must go back through writeJsonString —
                // a directive written with an escaped `\"` in its note parses
                // to a raw `"` here, and re-emitting it raw would corrupt the
                // ledger on the ack path.
                // T441: bare read:true is retained for backward compat
                // when reading old records; new writes carry read_by + read_at.
                const now_ts = try nowTimestamp();
                const who = resolveAckIdentity();

                var line_buf = std.ArrayList(u8).empty;
                defer line_buf.deinit(alloc);
                try line_buf.appendSlice(alloc, "{\"id\":");
                try writeJsonString(&line_buf, d_id);
                try line_buf.appendSlice(alloc, ",\"target\":");
                try writeJsonString(&line_buf, d_target);
                try line_buf.appendSlice(alloc, ",\"directive\":");
                try writeJsonString(&line_buf, if (obj.get("directive")) |v| if (v == .string) v.string else "" else "");
                if (obj.get("note")) |v| if (v == .string) {
                    try line_buf.appendSlice(alloc, ",\"note\":");
                    try writeJsonString(&line_buf, v.string);
                };
                if (obj.get("from")) |v| if (v == .string) {
                    try line_buf.appendSlice(alloc, ",\"from\":");
                    try writeJsonString(&line_buf, v.string);
                };
                if (obj.get("ts")) |v| if (v == .string) {
                    try line_buf.appendSlice(alloc, ",\"ts\":");
                    try writeJsonString(&line_buf, v.string);
                };
                if (obj.get("until_done")) |v| if (v == .string) {
                    // T625: acking a directive must preserve its discharge
                    // condition — the ack path is a re-serializer, not a
                    // field drop (T399's re-escape discipline).
                    try line_buf.appendSlice(alloc, ",\"until_done\":");
                    try writeJsonString(&line_buf, v.string);
                };
                try line_buf.appendSlice(alloc, ",\"read\":true");
                try line_buf.appendSlice(alloc, ",\"read_by\":");
                try writeJsonString(&line_buf, who);
                try line_buf.appendSlice(alloc, ",\"read_at\":");
                try writeJsonString(&line_buf, now_ts);
                try line_buf.appendSlice(alloc, "}\n");
                try out.appendSlice(alloc, line_buf.items);
                acked += 1;
            } else {
                try out.appendSlice(alloc, line);
                try out.append(alloc, '\n');
            }
        }

        const file = try std.Io.Dir.cwd().createFile(io, dir_path, .{});
        defer file.close(io);
        try file.writeStreamingAll(io, out.items);
        // Always print the count, even when zero, so a polling worker can
        // confirm the ack succeeded (and a tester can assert on it).
        w.data("  acked {d} directive(s)\n\n", .{acked});
    }
}

// ── ping [--note <text>] — emit a heartbeat ──────────────────────────────────

fn cmdPing(w: Writers, io: std.Io, repo_root: []const u8, args: [][]const u8) !void {
    const note_text = getFlagValue(args, "--note");

    const ts = try nowTimestamp();
    const ident = "unknown/ping";

    // Build heartbeat JSON line — T399: escape free text like the other
    // writers; an unescaped newline in a --note would split the record.
    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(alloc);

    try buf.appendSlice(alloc, "{\"identifier\":");
    try writeJsonString(&buf, ident);
    try buf.appendSlice(alloc, ",\"task\":");
    try writeJsonString(&buf, "ping");
    try buf.appendSlice(alloc, ",\"ts\":");
    try writeJsonString(&buf, ts);
    if (note_text) |nt| {
        try buf.appendSlice(alloc, ",\"note\":");
        try writeJsonString(&buf, nt);
    }
    try buf.appendSlice(alloc, "}\n");

    // T399: refuse to write an unreadable heartbeat.
    {
        const check = std.mem.trim(u8, buf.items, " \r\n");
        var roundtrip = std.json.parseFromSlice(std.json.Value, alloc, check, .{ .allocate = .alloc_always }) catch {
            w.diag("FATAL: heartbeat failed to re-parse after escaping — refusing to write\n", .{});
            return error.HeartbeatWriteNotRoundTrip;
        };
        roundtrip.deinit();
    }

    const hb_dir = try std.fs.path.join(alloc, &.{ repo_root, "untracked" });
    defer alloc.free(hb_dir);
    std.Io.Dir.cwd().createDirPath(io, hb_dir) catch {};

    const hb_path = try std.fs.path.join(alloc, &.{ repo_root, "untracked", "heartbeat.jsonl" });
    defer alloc.free(hb_path);

    // Read existing + append new heartbeat
    const existing_str = std.Io.Dir.cwd().readFileAlloc(io, hb_path, alloc, .unlimited) catch "";
    defer if (@intFromPtr(existing_str.ptr) != @intFromPtr("".ptr)) alloc.free(existing_str);

    var out = std.ArrayList(u8).empty;
    defer out.deinit(alloc);
    if (existing_str.len > 0) try out.appendSlice(alloc, existing_str);
    try out.appendSlice(alloc, buf.items);

    const file = try std.Io.Dir.cwd().createFile(io, hb_path, .{});
    defer file.close(io);
    try file.writeStreamingAll(io, out.items);

    w.diag("\n  ping: heartbeat recorded\n", .{});
    if (note_text) |nt| w.diag("  note: {s}\n", .{nt});
}

// ── lanes — bidirectional T-ID ↔ findings census (T716) ──────────────────
// The T716 defect: findings/T674, T679, T683, T685, T687, T690–T693 exist on
// disk and were graded (commits 8877a1d Race G batch 2, 9e9cd28 Race H), yet
// no row for any of them exists in any committed or working-tree tasks.json —
// the IDs were allocated (bundles written, next_id advanced) but the rows
// were clobbered by concurrent re-serialization before any commit captured
// them.  `lanes` is the instrument that makes that class visible and, with
// --backfill, reparable.
//
//   FORWARD  — every findings/<T<id>>-*.json whose <id> has no row in the
//              live store or the archive is an UNREGISTERED lane.  This is a
//              gate: exit 1 when any exist (the suite fails on it).
//   REVERSE  — every live done/failed row whose bundle declares a
//              `deliverables=findings/...` path that never landed on disk is
//              a MISSING-FINDINGS row.  Flag-only, never deleted (deleting a
//              row is how evidence dies).
//   --backfill — mint+close the forward orphans in ONE locked write: each
//              orphan gets a `done` row (verdict pass-with-findings) so the
//              finding can never again outlive its row.
const LaneFinding = struct {
    id: []const u8,
    path: []const u8,
};

const LanesCensus = struct {
    unregistered: std.ArrayList(LaneFinding),
    missing: std.ArrayList(LaneFinding),

    fn deinit(self: *LanesCensus) void {
        for (self.unregistered.items) |e| {
            alloc.free(e.id);
            alloc.free(e.path);
        }
        self.unregistered.deinit(alloc);
        for (self.missing.items) |e| {
            alloc.free(e.id);
            alloc.free(e.path);
        }
        self.missing.deinit(alloc);
    }
};

fn scanLanes(w: Writers, io: std.Io, repo_root: []const u8, live: *const StateMap, archive: *const StateMap) !LanesCensus {
    var c = LanesCensus{
        .unregistered = std.ArrayList(LaneFinding).empty,
        .missing = std.ArrayList(LaneFinding).empty,
    };
    errdefer c.deinit();

    const asc = struct {
        fn lt(_: void, a: LaneFinding, b: LaneFinding) bool {
            if (std.mem.lessThan(u8, a.id, b.id)) return true;
            if (std.mem.lessThan(u8, b.id, a.id)) return false;
            return std.mem.lessThan(u8, a.path, b.path);
        }
    }.lt;

    // ── FORWARD: findings files whose T-id has no row (live or archived) ──
    const findings_path = try std.fs.path.join(alloc, &.{ repo_root, "findings" });
    defer alloc.free(findings_path);

    var findings_dir: ?std.Io.Dir = null;
    if (std.Io.Dir.cwd().openDir(io, findings_path, .{})) |d| {
        findings_dir = d;
    } else |err| {
        if (err != error.FileNotFound) return err;
    }
    if (findings_dir) |*d| {
        defer d.close(io);
        var iter = d.iterate();
        while (try iter.next(io)) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.name, ".json")) continue;
            const tid = taskIdFromFindingsPath(entry.name) orelse continue;
            if (live.get(tid) != null or archive.get(tid) != null) continue;
            try c.unregistered.append(alloc, LaneFinding{
                .id = try alloc.dupe(u8, tid),
                .path = try std.fmt.allocPrint(alloc, "findings/{s}", .{entry.name}),
            });
        }
    }
    std.mem.sort(LaneFinding, c.unregistered.items, {}, asc);

    // ── REVERSE: done/failed rows whose findings deliverable never landed ──
    {
        var it = live.iterator();
        while (it.next()) |entry| {
            const tid = entry.key_ptr.*;
            const ts = entry.value_ptr.*;
            if (ts.status != .done and ts.status != .failed) continue;
            if (ts.bundle.len == 0) continue;
            const bundle_abs = if (std.fs.path.isAbsolute(ts.bundle))
                try alloc.dupe(u8, ts.bundle)
            else
                try std.fs.path.join(alloc, &.{ repo_root, ts.bundle });
            defer alloc.free(bundle_abs);
            const dlvs = parseDeliverablesFromBundle(w, io, bundle_abs, ts.holds) catch continue;
            defer {
                for (dlvs) |d| alloc.free(d);
                alloc.free(dlvs);
            }
            for (dlvs) |d| {
                if (!std.mem.startsWith(u8, d, "findings/")) continue;
                const d_abs = try std.fs.path.join(alloc, &.{ repo_root, d });
                defer alloc.free(d_abs);
                if (std.Io.Dir.cwd().statFile(io, d_abs, .{}) catch null) |_| continue;
                try c.missing.append(alloc, LaneFinding{
                    .id = try alloc.dupe(u8, tid),
                    .path = try alloc.dupe(u8, d),
                });
                break;
            }
        }
    }
    std.mem.sort(LaneFinding, c.missing.items, {}, asc);

    return c;
}

fn cmdLanes(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    const backfill = hasFlag(args, "--backfill");

    // Optional positional T-ids restrict --backfill to a subset (the T716
    // use: mint exactly the nine scoped orphans, not the whole historical
    // debt the census also surfaces).
    var only = std.ArrayList([]const u8).empty;
    defer only.deinit(alloc);
    for (args[2..]) |a| {
        if (std.mem.startsWith(u8, a, "-")) continue;
        try only.append(alloc, a);
    }

    var live = try readState(io, state_path);
    defer freeState(&live);

    const archive_path = try std.fs.path.join(alloc, &.{ repo_root, "docs", "infra", "managent", "archive.json" });
    defer alloc.free(archive_path);
    var archive = try readState(io, archive_path);
    defer freeState(&archive);

    var c = try scanLanes(w, io, repo_root, &live, &archive);
    defer c.deinit();

    // stdout = data, stderr = diagnostics (AGENTS.md).
    w.data("lanes: {d} unregistered finding(s), {d} missing-finding row(s)\n", .{ c.unregistered.items.len, c.missing.items.len });
    for (c.unregistered.items) |e| {
        w.data("  UNREGISTERED  {s}  ({s})\n", .{ e.id, e.path });
    }
    for (c.missing.items) |e| {
        w.data("  MISSING-FINDINGS  {s}  ({s})\n", .{ e.id, e.path });
    }

    if (c.unregistered.items.len == 0) std.process.exit(0);
    if (!backfill) {
        w.diag("lanes: {d} unregistered finding(s) — `managent lanes --backfill` mints+closes them\n", .{c.unregistered.items.len});
        std.process.exit(1);
    }

    // ── --backfill: mint+close the orphans in ONE locked write ──────────
    try lockStore(io, state_path);
    defer unlockStore();
    var state = try readState(io, state_path);
    // The freshly-minted rows carry default empty slices; this process exits
    // immediately after the write (the cmdAdd/cmdSuggest shape), so the state
    // map is intentionally not freed here.

    const now = try nowTimestamp();
    defer alloc.free(now);

    var minted: u32 = 0;
    for (c.unregistered.items) |e| {
        if (state.get(e.id) != null or archive.get(e.id) != null) continue;
        if (only.items.len > 0) {
            var in_list = false;
            for (only.items) |o| {
                if (std.mem.eql(u8, o, e.id)) {
                    in_list = true;
                    break;
                }
            }
            if (!in_list) continue;
        }
        const note = try std.fmt.allocPrint(alloc, "T716 backfill: minted+closed an orphaned lane — findings existed, the row was clobbered before any committed store captured it (findings/T716-unregistered-lanes.json)", .{});
        const ts = TaskState{
            .status = .done,
            .model = null,
            .bundle = try alloc.dupe(u8, ""),
            .set = 'A',
            .shape = try alloc.dupe(u8, "solo"),
            .added = try alloc.dupe(u8, now),
            .done = try alloc.dupe(u8, now),
            .note = note,
            .verdict = try alloc.dupe(u8, "pass-with-findings"),
            .verdict_note = try alloc.dupe(u8, "work delivered and graded before the row was minted (T716 backfill)"),
            .impression_waiver = try alloc.dupe(u8, "T716 backfill: pre-mint work, graded before the row existed — no impression owed"),
        };
        try state.put(alloc, try alloc.dupe(u8, e.id), ts);
        minted += 1;
    }
    try writeStateLocked(io, state_path, &state);

    w.data("lanes: minted+closed {d} row(s)\n", .{minted});
    std.process.exit(0);
}

// ── liveness — show last heartbeat per in_progress task ──────────────────────

fn cmdLiveness(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    var state = try readState(io, state_path);
    defer freeState(&state);

    // T464: liveness consults the assertion ledger through the same resolver
    // as every other view — a closed-asserted row is not a live claim.
    var ledger = readLedgerStatuses(io, state_path);
    defer freeLedgerStatuses(&ledger);

    // T370 (2026-08-06): staleness threshold in minutes.  Default 5;
    // override with --stale-min <float> (or LIVENESS_STALE_MIN).  The
    // threshold is what separates "beating" from "beats stopped" — a
    // row killed mid-run reads dead within one interval of its last beat.
    const stale_min = blk: {
        const override_ptr = std.c.getenv("LIVENESS_STALE_MIN");
        if (override_ptr) |op| {
            const sp = std.mem.span(op);
            if (std.fmt.parseFloat(f64, sp)) |f| break :blk f else |_| {}
        }
        if (getFlagValue(args, "--stale-min")) |v| {
            if (std.fmt.parseFloat(f64, v)) |f| break :blk f else |_| {}
        }
        break :blk 5.0;
    };
    const stale_secs: i64 = @intFromFloat(@max(stale_min, 0.0) * 60.0);

    var heartbeats = try readHeartbeats(w, io, repo_root);
    defer {
        for (heartbeats.items) |h| {
            alloc.free(h.identifier);
            alloc.free(h.task);
            alloc.free(h.ts);
            alloc.free(h.command);
        }
        heartbeats.deinit(alloc);
    }

    var now_tp: std.c.timespec = undefined;
    _ = std.c.clock_gettime(std.c.CLOCK.REALTIME, &now_tp);
    const now_unix: i64 = now_tp.sec;

    // For each in_progress task, find latest heartbeat and count the
    // runner-emitted beats (one per [progress] line / exit).  Three
    // distinct states, because "stale" collapsing them made the reading
    // useless: never beat / beats stopped Nm ago / beating.
    w.data("\n  Liveness (in_progress tasks):\n", .{});
    w.data("  (threshold: {d:.1} min)\n", .{stale_min});

    var it = state.iterator();
    var found: u32 = 0;
    while (it.next()) |entry| {
        const tid = entry.key_ptr.*;
        const ts = entry.value_ptr.*;
        // T464: resolve through the one resolver — an `in_progress` assertion
        // shows as a live claim; a `closed` assertion drops the row.
        if (resolveStatus(&state, ts, &ledger, tid).status != .in_progress) continue;

        found += 1;

        var latest: ?Heartbeat = null;
        var beats: u32 = 0;
        for (heartbeats.items) |h| {
            if (std.mem.eql(u8, h.task, tid)) {
                beats += 1;
                if (latest == null or std.mem.lessThan(u8, (latest.?).ts, h.ts)) {
                    latest = h;
                }
            }
        }

        if (latest) |hb| {
            if (ageSecFromTs(hb.ts, now_unix)) |age| {
                if (age <= stale_secs) {
                    w.data("    {s}  [beating]  last beat {d}s ago  ({d} beats)\n", .{ tid, age, beats });
                } else {
                    const age_min: i64 = @divTrunc(age, 60);
                    if (age < 60) {
                        w.data("    {s}  [beats stopped {d}s ago]  last beat {s}  ({d} beats)\n", .{ tid, age, hb.ts, beats });
                    } else {
                        w.data("    {s}  [beats stopped {d}m ago]  last beat {s}  ({d} beats)\n", .{ tid, age_min, hb.ts, beats });
                    }
                }
            } else {
                w.data("    {s}  [last beat {s} (unparseable ts)]  ({d} beats)\n", .{ tid, hb.ts, beats });
            }
            const cmd_display = utf8Truncate(hb.command, 40);
            if (cmd_display.len > 0) {
                w.data("      command: {s}\n", .{cmd_display});
            }
            if (hb.wall > 0) {
                w.data("      wall: {d:.1}s  cpu: {d:.1}s  rss: {d:.0} MB\n", .{ hb.wall, hb.cpu, hb.rss_mb });
            }
        } else if (ts.claimed) |claimed| {
            // T441: absence of a heartbeat is UNKNOWN, never "none" —
            // a console whose worker hasn't set MANAGENT_TASK_ID is still
            // alive and working; we just can't see it.
            w.data("    {s}  UNKNOWN — no assertion (claimed {s}, no heartbeat)\n", .{ tid, claimed });
        } else {
            w.data("    {s}  UNKNOWN — no assertion (in_progress, no heartbeat)\n", .{tid});
        }
    }

    if (found == 0) {
        w.data("    -- no in_progress tasks --\n", .{});
    }
    w.data("\n", .{});
}

// ── reap — reconcile the kanban against the process table (T364) ────────────
//
// For each in_progress row: a live runner pid (from the run record in
// untracked/runs/) or a fresh heartbeat means the row is BACKED and is
// never reaped — a row whose worker is alive but idle is reported as alive,
// stalled being the progress watchdog's job, not the reaper's.  Everything
// else is an ORPHAN: a dead runner with a completed record (the run ended
// but the row was never closed), a dead runner with a launch record only
// (killed mid-flight — the 2026-08-04 incident shape), or no process
// evidence at all (no run record, no fresh heartbeat).
//
// Report-only by default (stdout = data; exit 0 whether or not orphans
// exist).  `--close` closes each orphan as `abandoned` with the evidence as
// the note — never a verdict guess.  The close runs under the store flock
// with a FRESH re-classification, so a row that became backed between the
// report and the close is not closed.
fn cmdReap(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, args: [][]const u8) !void {
    const do_close = hasFlag(args, "--close");

    // Same staleness threshold as liveness (T370): the line between
    // "beating" and "beats stopped".  Default 5 min; override with
    // --stale-min or LIVENESS_STALE_MIN.
    const stale_min = blk: {
        const override_ptr = std.c.getenv("LIVENESS_STALE_MIN");
        if (override_ptr) |op| {
            const sp = std.mem.span(op);
            if (std.fmt.parseFloat(f64, sp)) |f| break :blk f else |_| {}
        }
        if (getFlagValue(args, "--stale-min")) |v| {
            if (std.fmt.parseFloat(f64, v)) |f| break :blk f else |_| {}
        }
        break :blk 5.0;
    };
    const stale_secs: i64 = @intFromFloat(@max(stale_min, 0.0) * 60.0);

    var state = try readState(io, state_path);
    defer freeState(&state);
    var ledger = readLedgerStatuses(io, state_path);
    defer freeLedgerStatuses(&ledger);
    var heartbeats = try readHeartbeats(w, io, repo_root);
    defer {
        for (heartbeats.items) |h| {
            alloc.free(h.identifier);
            alloc.free(h.task);
            alloc.free(h.ts);
            alloc.free(h.command);
        }
        heartbeats.deinit(alloc);
    }

    var rows = try classifyReapRows(w, io, repo_root, &state, &ledger, stale_secs, heartbeats.items);
    defer freeReapRows(&rows);

    w.data("\n  Reap — in_progress rows vs the process table:\n", .{});
    var n_backed: u32 = 0;
    var n_orphan: u32 = 0;
    for (rows.items) |r| {
        if (isOrphanReap(r.cls)) {
            n_orphan += 1;
            w.data("    {s}  [ORPHAN]   {s}\n", .{ r.tid, r.evidence });
        } else {
            n_backed += 1;
            w.data("    {s}  [BACKED]   {s}\n", .{ r.tid, r.evidence });
        }
    }
    if (rows.items.len == 0) {
        w.data("    -- no in_progress rows --\n", .{});
    }
    w.data("\n  backed: {d}   orphans: {d}   (stale threshold {d:.1} min)\n", .{ n_backed, n_orphan, stale_min });
    if (n_orphan == 0) {
        w.data("  nothing to reap.\n\n", .{});
        return;
    }
    if (!do_close) {
        w.data("  run `managent reap --close` to close each orphan as `abandoned`\n", .{});
        w.data("  with the evidence above as its note (never a verdict guess).\n\n", .{});
        return;
    }

    // ── --close: under the flock, fresh re-read + re-classification ────
    try lockStore(io, state_path);
    defer unlockStore();
    var state2 = try readState(io, state_path);
    defer freeState(&state2);
    var rows2 = try classifyReapRows(w, io, repo_root, &state2, &ledger, stale_secs, heartbeats.items);
    defer freeReapRows(&rows2);

    var closed = std.ArrayList([]const u8).empty;
    defer closed.deinit(alloc);
    const now = try nowTimestamp();
    defer alloc.free(now);
    for (rows2.items) |r| {
        if (!isOrphanReap(r.cls)) continue;
        const ts_ptr = state2.getPtr(r.tid) orelse continue;
        if (ts_ptr.status != .in_progress) continue;
        const note = try std.fmt.allocPrint(alloc, "reaped: {s}", .{r.evidence});
        ts_ptr.status = .done;
        // dupe per task: freeState frees each task's own done string; a
        // shared pointer would be freed once per task (double free).
        ts_ptr.done = try alloc.dupe(u8, now);
        ts_ptr.verdict = try alloc.dupe(u8, "abandoned");
        if (ts_ptr.verdict_note) |old| alloc.free(old);
        ts_ptr.verdict_note = note;
        // T522: reap --close is a close too — record the N/A as a waiver,
        // never a silent omission.  An orphan died mid-attempt, so no
        // impression exists; the waiver is the honest record.
        if (ts_ptr.impression_waiver) |old| alloc.free(old);
        ts_ptr.impression_waiver = try std.fmt.allocPrint(alloc, "reaped orphan: {s} (no impression — console died before close)", .{r.evidence});
        sys_closes += 1; // T478: a close is a close — duty due-counts advance
        try closed.append(alloc, r.tid);
    }

    if (closed.items.len == 0) {
        w.diag("  nothing to close — rows are backed again since the report (state changed)\n", .{});
        return;
    }

    // Unblock dependents whose needs are now met (same semantics as cmdDone:
    // a .done row satisfies needs, whatever its verdict).
    var unblocked = std.ArrayList([]const u8).empty;
    defer unblocked.deinit(alloc);
    var it2 = state2.iterator();
    while (it2.next()) |entry| {
        const dep_ts = entry.value_ptr.*;
        if (dep_ts.status != .blocked) continue;
        if (deriveStatus(&state2, dep_ts) == .dispatchable) {
            const dep_ptr = state2.getPtr(entry.key_ptr.*).?;
            dep_ptr.status = .dispatchable;
            try unblocked.append(alloc, entry.key_ptr.*);
        }
    }

    try writeStateLocked(io, state_path, &state2);

    w.data("  closed {d} orphan(s) as `abandoned`:", .{closed.items.len});
    for (closed.items) |c| w.data(" {s}", .{c});
    w.data("\n", .{});
    for (rows2.items) |r| {
        if (!isOrphanReap(r.cls)) continue;
        var was_closed = false;
        for (closed.items) |c| {
            if (std.mem.eql(u8, c, r.tid)) was_closed = true;
        }
        if (was_closed) {
            w.data("    {s}: note = reaped: {s}\n", .{ r.tid, r.evidence });
        }
    }
    if (unblocked.items.len > 0) {
        w.data("  unblocked:", .{});
        for (unblocked.items) |u| w.data(" {s}", .{u});
        w.data("\n", .{});
    }
    w.data("\n", .{});
}

// ── print pending directives for a claiming task ─────────────────────────────

fn printPendingDirectives(w: Writers, io: std.Io, repo_root: []const u8, state_path: []const u8, task_id: []const u8) void {
    var directives = readDirectives(w, io, repo_root, state_path, null) catch return;
    defer {
        for (directives.items) |d| {
            alloc.free(d.id);
            alloc.free(d.target);
            alloc.free(d.directive);
            if (d.note) |n| alloc.free(n);
            alloc.free(d.from);
            alloc.free(d.ts);
            if (d.until_done) |ud| alloc.free(ud);
        }
        directives.deinit(alloc);
    }

    var found: u32 = 0;
    for (directives.items) |d| {
        if (!std.mem.eql(u8, d.target, task_id)) continue;
        if (d.read) continue;
        if (found == 0) {
            w.diag("\n  === pending directives ===\n", .{});
        }
        found += 1;
        w.diag("    {s}  {s}  from {s}\n", .{ d.id, d.directive, d.from });
        if (d.note) |n| w.diag("      {s}\n", .{n});
        if (d.until_done) |ud| w.diag("      until_done: {s} (enforced until done)\n", .{ud});
    }
    if (found > 0) {
        w.diag("\n", .{});
    }
}
// ── treekill: process-tree ownership (pass 1) ────────────────────────────────
//
// `managent treekill` — enumerate and, with --kill, terminate every reachable
// descendant of an anchor pid (live or dead).  Contract: the corrected
// docs/epics/E1-markovian/L1-dashboard/S01-process-ownership/pass1/spec.md §2-§4.  One short-lived CLI, no
// store writes, no flock, no migration; family-independent (no provider token
// appears in this region — D-2).

extern "c" fn getsid(pid: std.c.pid_t) std.c.pid_t;

const OwnOpts = struct {
    anchor: i64 = -1,
    kill: bool = false,
    seeds: []i64 = &.{},
    since: ?i64 = null,
    protect: []i64 = &.{},
    rounds: u32 = 5,
    settle_ms: u32 = 250,
    ps_fixture: ?[]const u8 = null,
};

const ProcRow = struct {
    pid: i64,
    ppid: i64,
    pgid: i64,
    sid: i64,
    uid: i64,
    start_epoch: i64,
    rss_kb: i64,
    comm: []u8,
};

const OwnAction = enum { report, killed, vanished, refused, survived, protected };

fn ownActionName(a: OwnAction) []const u8 {
    return switch (a) {
        .report => "report",
        .killed => "killed",
        .vanished => "vanished",
        .refused => "refused",
        .survived => "survived",
        .protected => "protected",
    };
}

const OwnState = struct {
    claimed: std.AutoHashMap(i64, void),
    refused: std.AutoHashMap(i64, void),
    frozen: std.AutoHashMap(i64, void),
    member_rows: std.AutoHashMap(i64, ProcRow),
    actions: std.AutoHashMap(i64, OwnAction),

    fn init(allocator: std.mem.Allocator) OwnState {
        return .{
            .claimed = std.AutoHashMap(i64, void).init(allocator),
            .refused = std.AutoHashMap(i64, void).init(allocator),
            .frozen = std.AutoHashMap(i64, void).init(allocator),
            .member_rows = std.AutoHashMap(i64, ProcRow).init(allocator),
            .actions = std.AutoHashMap(i64, OwnAction).init(allocator),
        };
    }

    fn deinit(self: *OwnState) void {
        var it = self.member_rows.valueIterator();
        while (it.next()) |r| alloc.free(r.comm);
        self.member_rows.deinit();
        self.claimed.deinit();
        self.refused.deinit();
        self.frozen.deinit();
        self.actions.deinit();
    }
};

fn ownUsage(w: Writers) noreturn {
    w.diag("[treekill] usage: managent treekill --anchor <pid> [--kill] [--seed <pid,...>] [--since <epoch>] [--protect <pid>]... [--rounds <n>] [--settle-ms <n>] [--ps-fixture <path>]\n", .{});
    std.process.exit(2);
}

fn parseOwnArgs(w: Writers, args: [][]const u8) !OwnOpts {
    var o = OwnOpts{};
    var seeds = std.ArrayList(i64).empty;
    defer seeds.deinit(alloc);
    var protect = std.ArrayList(i64).empty;
    defer protect.deinit(alloc);

    var i: usize = 2; // args[0] == program name, args[1] == "treekill"
    while (i < args.len) : (i += 1) {
        const a = args[i];
        if (std.mem.eql(u8, a, "--kill")) {
            o.kill = true;
        } else if (std.mem.eql(u8, a, "--anchor")) {
            i += 1;
            if (i >= args.len) ownUsage(w);
            o.anchor = std.fmt.parseInt(i64, args[i], 10) catch ownUsage(w);
        } else if (std.mem.eql(u8, a, "--seed")) {
            i += 1;
            if (i >= args.len) ownUsage(w);
            var it = std.mem.splitScalar(u8, args[i], ',');
            while (it.next()) |tok| {
                const t = std.mem.trim(u8, tok, " \t");
                if (t.len == 0) continue;
                try seeds.append(alloc, std.fmt.parseInt(i64, t, 10) catch ownUsage(w));
            }
        } else if (std.mem.eql(u8, a, "--since")) {
            i += 1;
            if (i >= args.len) ownUsage(w);
            o.since = std.fmt.parseInt(i64, args[i], 10) catch ownUsage(w);
        } else if (std.mem.eql(u8, a, "--protect")) {
            i += 1;
            if (i >= args.len) ownUsage(w);
            try protect.append(alloc, std.fmt.parseInt(i64, args[i], 10) catch ownUsage(w));
        } else if (std.mem.eql(u8, a, "--rounds")) {
            i += 1;
            if (i >= args.len) ownUsage(w);
            o.rounds = std.fmt.parseInt(u32, args[i], 10) catch ownUsage(w);
        } else if (std.mem.eql(u8, a, "--settle-ms")) {
            i += 1;
            if (i >= args.len) ownUsage(w);
            o.settle_ms = std.fmt.parseInt(u32, args[i], 10) catch ownUsage(w);
        } else if (std.mem.eql(u8, a, "--ps-fixture")) {
            i += 1;
            if (i >= args.len) ownUsage(w);
            o.ps_fixture = try alloc.dupe(u8, args[i]);
        } else {
            ownUsage(w);
        }
    }
    if (o.anchor < 0) ownUsage(w); // missing --anchor
    if (o.kill and o.ps_fixture != null) ownUsage(w); // G9
    o.seeds = try seeds.toOwnedSlice(alloc);
    o.protect = try protect.toOwnedSlice(alloc);
    return o;
}

fn findRow(rows: []const ProcRow, pid: i64) ?*const ProcRow {
    for (rows) |*r| {
        if (r.pid == pid) return r;
    }
    return null;
}

fn findRowIdx(rows: []const ProcRow, pid: i64) ?usize {
    for (rows, 0..) |r, idx| {
        if (r.pid == pid) return idx;
    }
    return null;
}

fn dupeProcRow(r: ProcRow) !ProcRow {
    return .{
        .pid = r.pid,
        .ppid = r.ppid,
        .pgid = r.pgid,
        .sid = r.sid,
        .uid = r.uid,
        .start_epoch = r.start_epoch,
        .rss_kb = r.rss_kb,
        .comm = try alloc.dupe(u8, r.comm),
    };
}

fn freeRows(rows: *std.ArrayList(ProcRow)) void {
    for (rows.items) |r| alloc.free(r.comm);
    rows.deinit(alloc);
}

fn seedContains(seeds: []const i64, pid: i64) bool {
    for (seeds) |s| {
        if (s == pid) return true;
    }
    return false;
}

fn parsePsLine(line: []const u8, pid: *i64, ppid: *i64, pgid: *i64, uid: *i64, etime: *[]const u8, rss_kb: *i64, state_c: *u8, comm: *[]const u8) bool {
    var toks: [7][]const u8 = undefined;
    var idx: usize = 0;
    var i: usize = 0;
    const n = line.len;
    while (i < n and idx < 7) {
        while (i < n and (line[i] == ' ' or line[i] == '\t')) i += 1;
        if (i >= n) return false;
        const start = i;
        while (i < n and line[i] != ' ' and line[i] != '\t') i += 1;
        toks[idx] = line[start..i];
        idx += 1;
    }
    if (idx < 7) return false;
    while (i < n and (line[i] == ' ' or line[i] == '\t')) i += 1;
    pid.* = std.fmt.parseInt(i64, toks[0], 10) catch return false;
    ppid.* = std.fmt.parseInt(i64, toks[1], 10) catch return false;
    pgid.* = std.fmt.parseInt(i64, toks[2], 10) catch return false;
    uid.* = std.fmt.parseInt(i64, toks[3], 10) catch return false;
    etime.* = toks[4];
    rss_kb.* = std.fmt.parseInt(i64, toks[5], 10) catch return false;
    state_c.* = if (toks[6].len > 0) toks[6][0] else '?';
    comm.* = line[i..];
    return true;
}

fn parseEtime(s: []const u8) i64 {
    var days: i64 = 0;
    var rest = s;
    if (std.mem.indexOfScalar(u8, s, '-')) |dash| {
        days = std.fmt.parseInt(i64, s[0..dash], 10) catch return 0;
        rest = s[dash + 1 ..];
    }
    var total: i64 = 0;
    var parts = std.mem.splitScalar(u8, rest, ':');
    while (parts.next()) |p| {
        total = total * 60 + (std.fmt.parseInt(i64, p, 10) catch return 0);
    }
    return days * 86400 + total;
}

fn readProcTable(io: std.Io) !std.ArrayList(ProcRow) {
    var rows = std.ArrayList(ProcRow).empty;
    const result = std.process.run(alloc, io, .{ .argv = &.{ "ps", "-axo", "pid=,ppid=,pgid=,uid=,etime=,rss=,state=,comm=" } }) catch return error.OwnPsFailed;
    defer alloc.free(result.stderr);
    defer alloc.free(result.stdout);
    if (result.term != .exited or result.term.exited != 0) return error.OwnPsFailed;
    const now = nowUnix();
    var lines = std.mem.splitScalar(u8, result.stdout, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var pid: i64 = 0;
        var ppid: i64 = 0;
        var pgid: i64 = 0;
        var uid: i64 = 0;
        var etime_s: []const u8 = "";
        var rss_kb: i64 = 0;
        var state_c: u8 = '?';
        var comm: []const u8 = "";
        if (!parsePsLine(line, &pid, &ppid, &pgid, &uid, &etime_s, &rss_kb, &state_c, &comm)) continue;
        if (state_c == 'Z') continue; // zombies are already dead — never claimed
        const s = getsid(@intCast(pid));
        if (s == -1) {
            if (std.c.errno(s) == .SRCH) continue; // vanished between ps and getsid
            return error.OwnGetsidFailed;
        }
        try rows.append(alloc, .{
            .pid = pid,
            .ppid = ppid,
            .pgid = pgid,
            .sid = s,
            .uid = uid,
            .start_epoch = now - parseEtime(etime_s),
            .rss_kb = rss_kb,
            .comm = try alloc.dupe(u8, comm),
        });
    }
    return rows;
}

fn readPsFixture(io: std.Io, path: []const u8) !std.ArrayList(ProcRow) {
    var rows = std.ArrayList(ProcRow).empty;
    const content = std.Io.Dir.cwd().readFileAlloc(io, path, alloc, .unlimited) catch return error.OwnFixtureUnreadable;
    defer alloc.free(content);
    var lines = std.mem.splitScalar(u8, content, '\n');
    while (lines.next()) |line| {
        const t = std.mem.trim(u8, line, " \r\t");
        if (t.len == 0) continue;
        var toks: [6][]const u8 = undefined;
        var idx: usize = 0;
        var i: usize = 0;
        const n = t.len;
        while (i < n and idx < 6) {
            while (i < n and (t[i] == ' ' or t[i] == '\t')) i += 1;
            if (i >= n) break;
            const start = i;
            while (i < n and t[i] != ' ' and t[i] != '\t') i += 1;
            toks[idx] = t[start..i];
            idx += 1;
        }
        if (idx < 6) continue;
        while (i < n and (t[i] == ' ' or t[i] == '\t')) i += 1;
        const pid = std.fmt.parseInt(i64, toks[0], 10) catch continue;
        const ppid = std.fmt.parseInt(i64, toks[1], 10) catch continue;
        const pgid = std.fmt.parseInt(i64, toks[2], 10) catch continue;
        const sid = std.fmt.parseInt(i64, toks[3], 10) catch continue;
        const start_epoch = std.fmt.parseInt(i64, toks[4], 10) catch continue;
        const rss_kb = std.fmt.parseInt(i64, toks[5], 10) catch continue;
        try rows.append(alloc, .{
            .pid = pid,
            .ppid = ppid,
            .pgid = pgid,
            .sid = sid,
            .uid = -1, // fixture rows are treated as same-uid
            .start_epoch = start_epoch,
            .rss_kb = rss_kb,
            .comm = try alloc.dupe(u8, t[i..]),
        });
    }
    return rows;
}

const SignalResult = enum { ok, gone, denied };

fn trySignal(pid: i64, sig: std.c.SIG) SignalResult {
    const rc = std.c.kill(@intCast(pid), sig);
    if (rc == 0) return .ok;
    return switch (std.c.errno(rc)) {
        .SRCH => .gone,
        else => .denied,
    };
}

fn sleepMs(ms: u32) void {
    const req: std.c.timespec = .{
        .sec = @intCast(ms / 1000),
        .nsec = @intCast((ms % 1000) * std.time.ns_per_ms),
    };
    _ = std.c.nanosleep(&req, null);
}

fn pidState(io: std.Io, pid: i64) !?u8 {
    const pid_buf = try std.fmt.allocPrint(alloc, "{d}", .{pid});
    defer alloc.free(pid_buf);
    const result = std.process.run(alloc, io, .{ .argv = &.{ "ps", "-o", "state=", "-p", pid_buf } }) catch return error.OwnPsFailed;
    defer alloc.free(result.stderr);
    defer alloc.free(result.stdout);
    if (result.term == .exited and result.term.exited == 0) {
        const t = std.mem.trim(u8, result.stdout, " \n\r\t");
        if (t.len == 0) return null;
        return t[0];
    }
    if (result.term == .exited and result.term.exited == 1) return null; // gone
    return error.OwnPsFailed;
}

fn freezeFrontier(w: Writers, io: std.Io, st: *OwnState, settle_ms: u32, mutation: ?[]const u8) !void {
    _ = w;
    if (mutation != null and std.mem.eql(u8, mutation.?, "freeze-off")) return;
    var new_frozen = std.ArrayList(i64).empty;
    defer new_frozen.deinit(alloc);
    var it = st.claimed.keyIterator();
    while (it.next()) |pid_ptr| {
        const pid = pid_ptr.*;
        if (st.frozen.contains(pid)) continue;
        _ = trySignal(pid, std.c.SIG.STOP);
        try st.frozen.put(pid, {});
        try new_frozen.append(alloc, pid);
    }
    // Completion oracle (D-30): SIGSTOP returns before the target stops.
    var waited_ms: u32 = 0;
    while (true) {
        var all_stopped = true;
        for (new_frozen.items) |pid| {
            const state = try pidState(io, pid);
            if (state == null) continue; // vanished
            if (state.? != 'T') {
                all_stopped = false;
                break;
            }
        }
        if (all_stopped) break;
        if (waited_ms >= settle_ms) return error.FreezeTimeout;
        sleepMs(5);
        waited_ms += 5;
    }
}

fn resumeFrozen(frozen: *std.AutoHashMap(i64, void), mutation: ?[]const u8) void {
    if (mutation != null and std.mem.eql(u8, mutation.?, "rollback-off")) return;
    var it = frozen.keyIterator();
    while (it.next()) |pid_ptr| {
        _ = trySignal(pid_ptr.*, std.c.SIG.CONT);
    }
}

var OWN_LOCK_FD: std.c.fd_t = -1;

/// Serialize concurrent `treekill --kill` invocations on one tree (N4).  flock(2)
/// is released by the kernel when the holder's fd closes — on explicit
/// unlock OR on any process exit, so a crashed holder can never deadlock a
/// successor.  Blocking (no NONBLOCK backoff): a live holder keeps the lock
/// only for one kill+settle round, far under the runner's 30 s subprocess
/// timeout.
fn lockOwn(anchor: i64) !void {
    const lock_path = try std.fmt.allocPrint(alloc, "/tmp/weizigo-treekill-{d}.lock", .{anchor});
    defer alloc.free(lock_path);
    const open_flags = std.posix.O{ .ACCMODE = .RDWR, .CREAT = true, .CLOEXEC = true };
    const fd = std.c.open(@ptrCast(lock_path), open_flags, @as(c_int, 0o644));
    if (fd == -1) return error.LockFailed;
    const rc = std.c.flock(fd, std.posix.LOCK.EX);
    if (rc != 0) {
        _ = std.c.close(fd);
        return error.LockFailed;
    }
    OWN_LOCK_FD = fd;
}

fn unlockOwn() void {
    if (OWN_LOCK_FD == -1) return;
    _ = std.c.flock(OWN_LOCK_FD, std.posix.LOCK.UN);
    _ = std.c.close(OWN_LOCK_FD);
    OWN_LOCK_FD = -1;
}

fn isAncestorOf(rows: []const ProcRow, self_pid: i64, pid: i64) bool {
    var cur = self_pid;
    var guard: usize = 0;
    while (cur > 1 and guard < 256) : (guard += 1) {
        const r = findRow(rows, cur) orelse return false;
        if (r.ppid == pid) return true;
        cur = r.ppid;
    }
    return false;
}

fn ppidChainReaches(rows: []const ProcRow, claimed: *std.AutoHashMap(i64, void), start: i64, anchor: i64) bool {
    var cur = start;
    var seen = std.AutoHashMap(i64, void).init(alloc);
    defer seen.deinit();
    var guard: usize = 0;
    while (cur > 1 and guard < 256) : (guard += 1) {
        if (cur == anchor) return true;
        if (claimed.contains(cur)) return true;
        if (seen.contains(cur)) return false;
        seen.put(cur, {}) catch {};
        const r = findRow(rows, cur) orelse return false;
        cur = r.ppid;
    }
    return false;
}

fn closeOwnership(rows: []const ProcRow, st: *OwnState, anchor: i64, seeds: []const i64, since: i64, euid: i64) !bool {
    var pgids = std.AutoHashMap(i64, void).init(alloc);
    defer pgids.deinit();
    var sid_leaders = std.AutoHashMap(i64, void).init(alloc);
    defer sid_leaders.deinit();
    var it0 = st.claimed.keyIterator();
    while (it0.next()) |pid_ptr| {
        if (findRow(rows, pid_ptr.*)) |r| {
            try pgids.put(r.pgid, {});
            if (r.sid == r.pid) try sid_leaders.put(r.pid, {});
        }
    }
    var grew = false;
    for (rows) |row| {
        if (row.start_epoch < since) continue; // G4
        if (st.claimed.contains(row.pid) or st.refused.contains(row.pid)) continue;
        const ppid_edge = st.claimed.contains(row.ppid) or row.ppid == anchor;
        const seed_edge = seedContains(seeds, row.pid);
        const sid_edge = row.sid == anchor or sid_leaders.contains(row.sid);
        const pgid_edge = pgids.contains(row.pgid) and ppidChainReaches(rows, &st.claimed, row.pid, anchor); // D-19 downward
        if (ppid_edge or seed_edge or sid_edge or pgid_edge) {
            if (row.uid != euid and row.uid >= 0) {
                try st.refused.put(row.pid, {});
                try st.member_rows.put(row.pid, try dupeProcRow(row));
                try st.actions.put(row.pid, .refused);
            } else {
                try st.claimed.put(row.pid, {});
                try st.member_rows.put(row.pid, try dupeProcRow(row));
                try st.actions.put(row.pid, .report);
            }
            grew = true;
        }
    }
    return grew;
}

fn killMembers(st: *OwnState, rows: []const ProcRow, mutation: ?[]const u8) u32 {
    const parity_kill = mutation != null and std.mem.eql(u8, mutation.?, "kill-parity");
    var killed: u32 = 0;
    var it = st.claimed.keyIterator();
    while (it.next()) |pid_ptr| {
        const pid = pid_ptr.*;
        // Mutation "kill-parity" (the B-3 acceptance instrument): odd pids
        // survive the SIGKILL (no signal is sent) while even pids really die —
        // forcing the retry path so the arm can assert rounds-spent, honest
        // killed= across rounds (N4), and exit 5 with real survivors.
        if (parity_kill and (pid & 1) == 1) {
            st.actions.put(pid, .killed) catch {};
            killed += 1;
            continue;
        }
        // A pid absent from the fresh snapshot is already dead (gone or a
        // zombie reaped/skipped by readProcTable) — report it vanished, never
        // killed, so a concurrent invocation cannot produce a double-kill
        // report for the same pid (N4). A pid we killed in an earlier round
        // stays `killed`: a retry round must not downgrade it to `vanished`.
        if (findRow(rows, pid) == null) {
            if (st.actions.get(pid) != .killed) {
                st.actions.put(pid, .vanished) catch {};
            }
            continue;
        }
        switch (trySignal(pid, std.c.SIG.KILL)) {
            .ok => {
                st.actions.put(pid, .killed) catch {};
                killed += 1;
            },
            .gone => {
                if (st.actions.get(pid) != .killed) {
                    st.actions.put(pid, .vanished) catch {};
                }
            },
            .denied => {
                st.actions.put(pid, .refused) catch {};
            },
        }
    }
    return killed;
}

fn countSurvivors(rows: []const ProcRow, st: *OwnState) u32 {
    var n: u32 = 0;
    var it = st.claimed.keyIterator();
    while (it.next()) |pid_ptr| {
        if (findRow(rows, pid_ptr.*) != null) {
            n += 1;
            st.actions.put(pid_ptr.*, .survived) catch {};
        }
    }
    return n;
}

const ProtectedEntry = struct { pid: i64, task: []u8 };

fn readProtectedSet(io: std.Io, repo_root: []const u8, anchor: i64, rows: []const ProcRow) !std.ArrayList(ProtectedEntry) {
    var result = std.ArrayList(ProtectedEntry).empty;
    const runs_dir = std.fs.path.join(alloc, &.{ repo_root, "untracked", "runs" }) catch return result;
    defer alloc.free(runs_dir);
    var dir = std.Io.Dir.cwd().openDir(io, runs_dir, .{}) catch |err| {
        if (err == error.FileNotFound) return result;
        return err;
    };
    defer dir.close(io);
    var it = dir.iterate();
    while (it.next(io) catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;
        const abs = std.fs.path.join(alloc, &.{ runs_dir, entry.name }) catch continue;
        defer alloc.free(abs);
        const content = std.Io.Dir.cwd().readFileAlloc(io, abs, alloc, .unlimited) catch continue;
        defer alloc.free(content);
        const trimmed = std.mem.trim(u8, content, " \r\n");
        if (trimmed.len == 0) continue;
        var parsed = std.json.parseFromSlice(std.json.Value, alloc, trimmed, .{ .allocate = .alloc_always }) catch continue;
        defer parsed.deinit();
        if (parsed.value != .object) continue;
        const obj = parsed.value.object;
        const task = runRecStr(obj, "task");
        if (task.len == 0) continue;
        const pgid = runRecI64(obj, "pgid");
        if (pgid <= 0) continue;
        if (pgid == anchor) continue; // the caller's own record
        if (obj.get("exit") != null or obj.get("signal") != null or obj.get("wall") != null) continue; // finalized
        const pid = runRecI64(obj, "pid");
        if (pid <= 0) continue;
        if (!processAlive(pid)) continue; // expired: runner dead
        const start_epoch = runRecI64(obj, "start_epoch");
        if (start_epoch > 0) {
            if (findRow(rows, pid)) |r| {
                if (r.start_epoch > start_epoch + 5) continue; // pid recycled after the record
            }
        }
        try result.append(alloc, .{ .pid = pgid, .task = try alloc.dupe(u8, task) });
    }
    return result;
}

fn validateOwnership(w: Writers, io: std.Io, repo_root: []const u8, rows: []const ProcRow, st: *OwnState, opts: OwnOpts, self_pid: i64, own_sid: i64, euid: i64, mutation: ?[]const u8) bool {
    _ = euid;
    var it = st.claimed.keyIterator();
    while (it.next()) |pid_ptr| {
        const pid = pid_ptr.*;
        if (pid <= 1) {
            w.diag("[treekill] REFUSED: pid {d} is pid 0/1\n", .{pid});
            return false;
        }
        if (pid == self_pid) {
            w.diag("[treekill] REFUSED: pid {d} is this process\n", .{pid});
            return false;
        }
        if (isAncestorOf(rows, self_pid, pid)) {
            w.diag("[treekill] REFUSED: pid {d} is an ancestor of this process\n", .{pid});
            return false;
        }
        if (pid == own_sid) {
            w.diag("[treekill] REFUSED: pid {d} is this process's session leader\n", .{pid});
            return false;
        }
        for (opts.protect) |p| {
            if (p == pid) {
                w.diag("[treekill] REFUSED: pid {d} is protected (--protect)\n", .{pid});
                return false;
            }
        }
    }
    if (mutation != null and std.mem.eql(u8, mutation.?, "protect-off")) return true;
    var prot = readProtectedSet(io, repo_root, opts.anchor, rows) catch {
        w.diag("[treekill] internal error: cannot read the protected-set run records\n", .{});
        return false;
    };
    defer {
        for (prot.items) |pe| alloc.free(pe.task);
        prot.deinit(alloc);
    }
    var it2 = st.claimed.keyIterator();
    while (it2.next()) |pid_ptr| {
        for (prot.items) |pe| {
            if (pe.pid == pid_ptr.*) {
                w.diag("[treekill] REFUSED: pid {d} is the anchor of in-progress task {s}\n", .{ pid_ptr.*, pe.task });
                return false;
            }
        }
    }
    return true;
}

fn printOwnRecord(w: Writers, pid: i64, r: ProcRow, action: OwnAction) void {
    w.data("{d}\t{d}\t{d}\t{d}\t{d}\t{d}\t{s}\t{s}\n", .{ pid, r.ppid, r.pgid, r.sid, r.start_epoch, r.rss_kb, ownActionName(action), r.comm });
}

fn printOwnReport(w: Writers, st: *OwnState) void {
    var pids = std.ArrayList(i64).empty;
    defer pids.deinit(alloc);
    var it = st.member_rows.keyIterator();
    while (it.next()) |p| pids.append(alloc, p.*) catch {};
    std.mem.sort(i64, pids.items, {}, struct {
        fn lt(_: void, a: i64, b: i64) bool {
            return a < b;
        }
    }.lt);
    for (pids.items) |pid| {
        const r = st.member_rows.get(pid) orelse continue;
        const action = st.actions.get(pid) orelse .report;
        printOwnRecord(w, pid, r, action);
    }
}

fn printOwnSummary(w: Writers, opts: OwnOpts, anchor_live: bool, st: *OwnState, rounds_used: u32) void {
    var killed: u32 = 0;
    var survivors: u32 = 0;
    var it = st.actions.valueIterator();
    while (it.next()) |a| {
        switch (a.*) {
            .killed => killed += 1,
            .survived => survivors += 1,
            else => {},
        }
    }
    w.data("treekill anchor={d} root={s} claimed={d} killed={d} refused={d} survivors={d} rounds={d}\n", .{
        opts.anchor,
        if (anchor_live) "live" else "dead",
        st.claimed.count(),
        killed,
        st.refused.count(),
        survivors,
        rounds_used,
    });
}

fn cmdTreekill(w: Writers, io: std.Io, repo_root: []const u8, args: [][]const u8) !void {
    const opts = try parseOwnArgs(w, args);
    defer {
        alloc.free(opts.seeds);
        alloc.free(opts.protect);
        if (opts.ps_fixture) |p| alloc.free(p);
    }

    const mutation: ?[]const u8 = if (std.c.getenv("MANAGENT_OWN_MUTATE")) |p| std.mem.span(p) else null;
    if (mutation) |m| w.diag("[treekill] MUTATION ACTIVE: {s}\n", .{m});

    const euid: i64 = @intCast(std.c.geteuid());
    const self_pid: i64 = std.c.getpid();

    var rows = blk: {
        if (opts.ps_fixture) |p| {
            break :blk readPsFixture(io, p) catch {
                w.diag("[treekill] internal error: cannot read ps fixture {s}\n", .{p});
                std.process.exit(3);
            };
        } else {
            break :blk readProcTable(io) catch {
                w.diag("[treekill] internal error: ps read failed\n", .{});
                std.process.exit(3);
            };
        }
    };
    defer freeRows(&rows);

    const anchor_row = findRow(rows.items, opts.anchor);
    const anchor_live = anchor_row != null;
    const anchor_start: i64 = if (anchor_row) |r| r.start_epoch else 0;
    var since: i64 = opts.since orelse (if (anchor_live) anchor_start else 0);
    if (mutation != null and std.mem.eql(u8, mutation.?, "since-off")) since = 0;

    // ── early guards (G0/G1/G3), read-only or kill alike ──
    if (opts.anchor <= 1) {
        w.diag("[treekill] REFUSED: anchor pid {d} (pid 0/1 is never claimable)\n", .{opts.anchor});
        std.process.exit(4);
    }
    if (anchor_live and anchor_row.?.uid != euid) {
        w.diag("[treekill] REFUSED: anchor pid {d} is not owned by euid {d}\n", .{ opts.anchor, euid });
        std.process.exit(4);
    }
    if (opts.anchor == self_pid) {
        w.diag("[treekill] REFUSED: anchor pid {d} is this process\n", .{opts.anchor});
        std.process.exit(4);
    }
    if (isAncestorOf(rows.items, self_pid, opts.anchor)) {
        w.diag("[treekill] REFUSED: anchor pid {d} is an ancestor of this process\n", .{opts.anchor});
        std.process.exit(4);
    }
    const own_sid: i64 = getsid(@intCast(self_pid));
    if (own_sid == -1) {
        w.diag("[treekill] internal error: getsid(self) failed\n", .{});
        std.process.exit(3);
    }
    if (own_sid == opts.anchor) {
        w.diag("[treekill] REFUSED: anchor pid {d} is this process's session leader\n", .{opts.anchor});
        std.process.exit(4);
    }

    var st = OwnState.init(alloc);
    defer st.deinit();

    if (anchor_live) {
        try st.claimed.put(opts.anchor, {});
        try st.member_rows.put(opts.anchor, try dupeProcRow(anchor_row.?.*));
        try st.actions.put(opts.anchor, .report);
    }
    for (opts.seeds) |s| {
        if (findRow(rows.items, s)) |row_ptr| {
            const row = row_ptr.*;
            if (row.start_epoch < since) continue;
            if (row.uid != euid and row.uid >= 0) {
                try st.refused.put(s, {});
                try st.member_rows.put(s, try dupeProcRow(row));
                try st.actions.put(s, .refused);
            } else {
                try st.claimed.put(s, {});
                try st.member_rows.put(s, try dupeProcRow(row));
                try st.actions.put(s, .report);
            }
        }
    }

    var rounds_used: u32 = 0;
    var survivors: u32 = 0;
    var converged = false;
    while (rounds_used < opts.rounds) {
        rounds_used += 1;
        if (opts.kill) {
            freezeFrontier(w, io, &st, opts.settle_ms, mutation) catch {
                resumeFrozen(&st.frozen, mutation);
                w.diag("[treekill] internal error: freeze did not complete within the bound\n", .{});
                std.process.exit(3);
            };
        }
        if (opts.ps_fixture == null) {
            freeRows(&rows);
            rows = readProcTable(io) catch {
                resumeFrozen(&st.frozen, mutation);
                w.diag("[treekill] internal error: process table read failed\n", .{});
                std.process.exit(3);
            };
        }
        const grew = closeOwnership(rows.items, &st, opts.anchor, opts.seeds, since, euid) catch |err| {
            resumeFrozen(&st.frozen, mutation);
            w.diag("[treekill] internal error: {s}\n", .{@errorName(err)});
            std.process.exit(3);
        };
        if (grew) continue;

        converged = true;

        if (opts.kill and !validateOwnership(w, io, repo_root, rows.items, &st, opts, self_pid, own_sid, euid, mutation)) {
            resumeFrozen(&st.frozen, mutation);
            printOwnSummary(w, opts, anchor_live, &st, rounds_used);
            std.process.exit(4);
        }

        if (!opts.kill) break;

        lockOwn(opts.anchor) catch {
            w.diag("[treekill] internal error: cannot acquire the kill lock\n", .{});
            resumeFrozen(&st.frozen, mutation);
            std.process.exit(3);
        };
        // Fresh snapshot immediately before the kill (under the lock): a pid
        // already killed by a concurrent invocation (now a zombie, skipped by
        // readProcTable) is reported vanished, never killed — the N4
        // no-double-kill contract.
        if (opts.ps_fixture == null) {
            freeRows(&rows);
            rows = readProcTable(io) catch {
                resumeFrozen(&st.frozen, mutation);
                w.diag("[treekill] internal error: process table read failed\n", .{});
                std.process.exit(3);
            };
        }
        _ = killMembers(&st, rows.items, mutation);
        sleepMs(opts.settle_ms);
        if (opts.ps_fixture == null) {
            freeRows(&rows);
            rows = readProcTable(io) catch {
                resumeFrozen(&st.frozen, mutation);
                w.diag("[treekill] internal error: process table read failed\n", .{});
                std.process.exit(3);
            };
        }
        survivors = countSurvivors(rows.items, &st);
        unlockOwn();
        if (survivors == 0) break;
    }

    resumeFrozen(&st.frozen, mutation);

    if (!converged) {
        w.diag("[treekill] closure did not converge within {d} rounds\n", .{opts.rounds});
        printOwnReport(w, &st);
        printOwnSummary(w, opts, anchor_live, &st, rounds_used);
        std.process.exit(5);
    }

    if (survivors > 0) {
        // Opus's exit-5 diagnostic (B-3 race, consolidated in D34): name the
        // survived-SIGKILL cause distinctly from the did-not-converge cause, so
        // the ledger never reads the two exit-5 paths as one.
        w.diag("[treekill] {d} claimed member(s) survived SIGKILL within {d} rounds\n", .{ survivors, opts.rounds });
        printOwnReport(w, &st);
        printOwnSummary(w, opts, anchor_live, &st, rounds_used);
        std.process.exit(5);
    }

    printOwnReport(w, &st);
    printOwnSummary(w, opts, anchor_live, &st, rounds_used);
    std.process.exit(0);
}

// ── end treekill ─────────────────────────────────────────────────────────────

// ── run a command and capture stdout ────────────────────────────────────────

fn runCommand(allocator: std.mem.Allocator, io: std.Io, argv: []const []const u8) ![]const u8 {
    const result = try std.process.run(allocator, io, .{
        .argv = argv,
    });
    return result.stdout;
}


const RunGitOut = struct {
    stdout: []const u8,
    ok: bool,
};

/// Run git -C <repo_root> <argv...>; return stdout plus whether the exit
/// was 0. On spawn failure stdout is "" and ok is false. Caller owns
/// stdout when it is non-empty.
fn runGit(allocator: std.mem.Allocator, io: std.Io, repo_root: []const u8, argv: []const []const u8) RunGitOut {
    var full = std.ArrayList([]const u8).empty;
    defer full.deinit(allocator);
    full.appendSlice(allocator, &.{ "git", "-C", repo_root }) catch return .{ .stdout = "", .ok = false };
    full.appendSlice(allocator, argv) catch return .{ .stdout = "", .ok = false };
    const result = std.process.run(allocator, io, .{ .argv = full.items }) catch return .{ .stdout = "", .ok = false };
    const ok = result.term == .exited and result.term.exited == 0;
    return .{ .stdout = result.stdout, .ok = ok };
}

const TreeDirty = struct {
    total: usize = 0,
    nonkanban: usize = 0,
};

/// git status --porcelain dirty counts, with the kanban store's own writes
/// (tasks.json / directives.jsonl / heartbeat.jsonl) separated out — the
/// store is written by managent itself, so its dirty lines are not "the
/// working tree diverging". Empty struct on git failure.
fn treeDirty(io: std.Io, repo_root: []const u8) TreeDirty {
    const porcelain = runCommand(alloc, io, &.{ "git", "-C", repo_root, "status", "--porcelain" }) catch return .{};
    defer if (@intFromPtr(porcelain.ptr) != @intFromPtr("".ptr)) alloc.free(porcelain);
    var out = TreeDirty{};
    var plines = std.mem.splitScalar(u8, porcelain, '\n');
    while (plines.next()) |l| {
        if (l.len == 0) continue;
        out.total += 1;
        const is_kanban_store = std.mem.indexOf(u8, l, "tasks.json") != null or
            std.mem.indexOf(u8, l, "directives.jsonl") != null or
            std.mem.indexOf(u8, l, "heartbeat.jsonl") != null;
        if (!is_kanban_store) out.nonkanban += 1;
    }
    return out;
}

// ═══════════════════════════════════════════════════════════════════════════════
// T635 tests — mechanized model assignment (ruling 33 controls)
// ═══════════════════════════════════════════════════════════════════════════════

test "assign: every canonical model has a family and appetite mapping" {
    for (canonical_models) |m| {
        const fam = familyOf(m) orelse {
            std.debug.print("canonical model '{s}' missing from model_families\n", .{m});
            return error.TestFailed;
        };
        if (appetiteOf(fam) == null) {
            std.debug.print("family '{s}' (model '{s}') missing from family_appetite\n", .{ fam, m });
            return error.TestFailed;
        }
    }
}

test "assign: nine-model spend roster; fable RESERVED and qwen PROBE excluded" {
    var prng = std.Random.DefaultPrng.init(0);
    var res = try assignModel(null, &.{}, prng.random());
    defer freeAssignResult(&res);

    // T834 (operator ruling 2026-08-24): ollama-cloud is SPEND again
    // (glm/minimax/kimi back), fable RESERVED, qwen PROBE → the qualified
    // list is the operator's eight equal-opportunity models PLUS ox-alpha
    // (dial 9, "test whenever you get the opportunity").
    try std.testing.expectEqual(@as(usize, 9), res.candidates.len);
    var saw_glm = false;
    var saw_minimax = false;
    var saw_kimi = false;
    var saw_ox = false;
    for (res.candidates) |c| {
        if (std.mem.eql(u8, c, "glm-5.2")) saw_glm = true;
        if (std.mem.eql(u8, c, "minimax-m3")) saw_minimax = true;
        if (std.mem.eql(u8, c, "kimi-k2.7")) saw_kimi = true;
        if (std.mem.eql(u8, c, "ox-alpha")) saw_ox = true;
        try std.testing.expect(!std.mem.eql(u8, c, "qwen3.8:27b-mlx"));
        try std.testing.expect(!std.mem.eql(u8, c, "claude-fable-5"));
    }
    try std.testing.expect(saw_glm);
    try std.testing.expect(saw_minimax);
    try std.testing.expect(saw_kimi);
    try std.testing.expect(saw_ox);
    var saw_reserved = false;
    var saw_probe = false;
    for (res.reasons) |r| {
        if (std.mem.indexOf(u8, r, "appetite RESERVED") != null) saw_reserved = true;
        if (std.mem.indexOf(u8, r, "appetite PROBE") != null) saw_probe = true;
    }
    try std.testing.expect(saw_reserved);
    try std.testing.expect(saw_probe);
}

test "assign: single qualified candidate forces method=forced" {
    var prng = std.Random.DefaultPrng.init(0);
    // Exclude claude, flash, ollama-cloud and ox-alpha → only
    // deepseek-v4-pro remains (ollama-cloud is SPEND again per T834).
    const excl = [_][]const u8{ "claude", "deepseek-v4-flash", "ollama-cloud", "ox-alpha" };
    var res = try assignModel(null, &excl, prng.random());
    defer freeAssignResult(&res);
    try std.testing.expectEqualStrings("forced", res.method);
    try std.testing.expectEqualStrings("deepseek-v4-pro", res.model);
    try std.testing.expectEqual(@as(usize, 1), res.candidates.len);
    try std.testing.expectEqualStrings("deepseek-v4-pro", res.candidates[0]);
}

test "assign: named model is preferred, qualified list still recorded" {
    var prng = std.Random.DefaultPrng.init(0);
    var res = try assignModel("claude-fable-5", &.{}, prng.random());
    defer freeAssignResult(&res);
    try std.testing.expectEqualStrings("preferred", res.method);
    try std.testing.expectEqualStrings("claude-fable-5", res.model);
    // fable is RESERVED, so it is not in the qualified list — but the list is
    // still recorded so a later reader sees what was passed over.
    try std.testing.expectEqual(@as(usize, 9), res.candidates.len);
    var saw_note = false;
    for (res.reasons) |r| {
        if (std.mem.indexOf(u8, r, "preferred by row (outside qualified list)") != null) saw_note = true;
    }
    try std.testing.expect(saw_note);
}

test "assign: OS-entropy draw over 3 candidates is uniform within ±15%" {
    var threaded = std.Io.Threaded.init(alloc, .{});
    defer threaded.deinit();
    const io = threaded.io();

    const pool = [_][]const u8{ "claude-opus-5", "claude-sonnet-5", "deepseek-v4-pro" };
    var counts = [3]usize{ 0, 0, 0 };
    const n: usize = 3000;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        var os = OsEntropy{ .io = io };
        const rng = std.Random.init(&os, OsEntropy.fill);
        const picked = try drawCandidate(rng, &pool);
        defer alloc.free(picked);
        if (std.mem.eql(u8, picked, pool[0])) {
            counts[0] += 1;
        } else if (std.mem.eql(u8, picked, pool[1])) {
            counts[1] += 1;
        } else {
            counts[2] += 1;
        }
    }
    const expected: usize = n / 3; // 1000
    const tol: usize = expected * 15 / 100; // ±15% → [850, 1150]
    for (counts, 0..) |c, j| {
        std.debug.print("  candidate {d}: {d}/{d} draws\n", .{ j, c, n });
        try std.testing.expect(c >= expected - tol and c <= expected + tol);
    }
}

test "assign: row with no assignment record parses unchanged (null method)" {
    const content =
        \\{
        \\  "TX": {"status":"dispatchable","agent":null,"model":null,"bundle":"untracked/TX-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-22T00:00:00Z","claim_count":0}
        \\}
    ;
    var state = try parseStateJson(content);
    defer freeState(&state);
    const ts = state.get("TX").?;
    try std.testing.expect(ts.method == null);
    try std.testing.expectEqual(@as(usize, 0), ts.candidates.len);
    try std.testing.expectEqual(@as(usize, 0), ts.assign_reasons.len);
}

test "assign: candidates/method/reasons round-trip serialize → parse" {
    var state = StateMap{};
    defer freeState(&state);

    var ts = TaskState{
        .status = .dispatchable,
        .bundle = "untracked/TX-bundle.md",
        .set = 'A',
        .added = "2026-08-22T00:00:00Z",
    };
    // freeState frees bundle/added too — give the test owned copies.
    ts.bundle = try alloc.dupe(u8, "untracked/TX-bundle.md");
    ts.added = try alloc.dupe(u8, "2026-08-22T00:00:00Z");
    var cands = std.ArrayList([]const u8).empty;
    try cands.append(alloc, try alloc.dupe(u8, "claude-opus-5"));
    try cands.append(alloc, try alloc.dupe(u8, "deepseek-v4-pro"));
    ts.candidates = try cands.toOwnedSlice(alloc);
    ts.method = try alloc.dupe(u8, "random");
    var reas = std.ArrayList([]const u8).empty;
    try reas.append(alloc, try alloc.dupe(u8, "claude-fable-5: family claude-fable appetite RESERVED (reserved task types only)"));
    ts.assign_reasons = try reas.toOwnedSlice(alloc);

    try state.put(alloc, try alloc.dupe(u8, "TX"), ts);

    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(alloc);
    try serializeState(&state, &buf);

    var parsed = try parseStateJson(buf.items);
    defer freeState(&parsed);
    const p = parsed.get("TX").?;
    try std.testing.expectEqualStrings("random", p.method.?);
    try std.testing.expectEqual(@as(usize, 2), p.candidates.len);
    try std.testing.expectEqualStrings("claude-opus-5", p.candidates[0]);
    try std.testing.expectEqualStrings("deepseek-v4-pro", p.candidates[1]);
    try std.testing.expectEqual(@as(usize, 1), p.assign_reasons.len);
    try std.testing.expectEqualStrings("claude-fable-5: family claude-fable appetite RESERVED (reserved task types only)", p.assign_reasons[0]);
}

// ═══════════════════════════════════════════════════════════════════════════════
// T627 tests — dispatch scope fields (ruling 35 denominator)
// ═══════════════════════════════════════════════════════════════════════════════
// Test isolation per T427: these never touch the live store — they round-trip a
// fixture row through serializeState/parseStateJson in memory only.

test "scope: enumerated fields round-trip serialize → parse" {
    var state = StateMap{};
    defer freeState(&state);

    var ts = TaskState{
        .status = .dispatchable,
        .bundle = "untracked/TX-bundle.md",
        .set = 'A',
        .added = "2026-08-22T00:00:00Z",
        .brief_bytes = 4096,
        .files_in_scope = 3,
        .expected_wall_s = 1800,
        .scope_enumerable = true,
    };
    ts.bundle = try alloc.dupe(u8, "untracked/TX-bundle.md");
    ts.added = try alloc.dupe(u8, "2026-08-22T00:00:00Z");
    var targets = std.ArrayList([]const u8).empty;
    try targets.append(alloc, try alloc.dupe(u8, "src/managent/main.zig"));
    try targets.append(alloc, try alloc.dupe(u8, "findings/TX-scope.json"));
    try targets.append(alloc, try alloc.dupe(u8, "docs/infra/managent/spec.md"));
    ts.scope_targets = try targets.toOwnedSlice(alloc);

    try state.put(alloc, try alloc.dupe(u8, "TX"), ts);

    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(alloc);
    try serializeState(&state, &buf);

    var parsed = try parseStateJson(buf.items);
    defer freeState(&parsed);
    const p = parsed.get("TX").?;
    try std.testing.expectEqual(@as(?u64, 4096), p.brief_bytes);
    try std.testing.expectEqual(@as(?u32, 3), p.files_in_scope);
    try std.testing.expectEqual(@as(?u32, 1800), p.expected_wall_s);
    try std.testing.expectEqual(@as(?bool, true), p.scope_enumerable);
    try std.testing.expectEqual(@as(usize, 3), p.scope_targets.len);
    try std.testing.expectEqualStrings("src/managent/main.zig", p.scope_targets[0]);
    try std.testing.expect(p.scope_note == null);
}

test "scope: unenumerable statement round-trips (note, not a guessed list)" {
    var state = StateMap{};
    defer freeState(&state);

    var ts = TaskState{
        .status = .dispatchable,
        .bundle = "untracked/TX-bundle.md",
        .set = 'A',
        .added = "2026-08-22T00:00:00Z",
        .brief_bytes = 1234,
        .files_in_scope = 1,
        .expected_wall_s = null, // absent estimate → UNKNOWN, never 0
        .scope_enumerable = false,
    };
    ts.bundle = try alloc.dupe(u8, "untracked/TX-bundle.md");
    ts.added = try alloc.dupe(u8, "2026-08-22T00:00:00Z");
    ts.scope_note = try alloc.dupe(u8, "open-ended sweep: target set grows during the pass");

    try state.put(alloc, try alloc.dupe(u8, "TX"), ts);

    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(alloc);
    try serializeState(&state, &buf);

    var parsed = try parseStateJson(buf.items);
    defer freeState(&parsed);
    const p = parsed.get("TX").?;
    try std.testing.expectEqual(@as(?bool, false), p.scope_enumerable);
    try std.testing.expectEqual(@as(usize, 0), p.scope_targets.len);
    try std.testing.expectEqualStrings("open-ended sweep: target set grows during the pass", p.scope_note.?);
    // expected_wall_s absent is UNKNOWN — it must never render as zero.
    try std.testing.expectEqual(@as(?u32, null), p.expected_wall_s);
}

test "scope: old row without scope fields parses to UNKNOWN (null, not zero)" {
    const content =
        \\{
        \\  "TX": {"status":"dispatchable","agent":null,"model":null,"bundle":"untracked/TX-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-22T00:00:00Z","claim_count":0}
        \\}
    ;
    var state = try parseStateJson(content);
    defer freeState(&state);
    const ts = state.get("TX").?;
    // Absence of an assertion is UNKNOWN, never "none" — old rows predate the
    // field, and must not be read as brief_bytes=0 / files_in_scope=0.
    try std.testing.expectEqual(@as(?u64, null), ts.brief_bytes);
    try std.testing.expectEqual(@as(?u32, null), ts.files_in_scope);
    try std.testing.expectEqual(@as(?u32, null), ts.expected_wall_s);
    try std.testing.expectEqual(@as(?bool, null), ts.scope_enumerable);
    try std.testing.expectEqual(@as(usize, 0), ts.scope_targets.len);
    try std.testing.expect(ts.scope_note == null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// T636 tests — row shape: solo ladder, panel compose (ruling 34 controls)
// ═══════════════════════════════════════════════════════════════════════════════

test "shape: legacy row with no shape field parses to null (no retroactive label)" {
    const content =
        \\{
        \\  "TX": {"status":"dispatchable","agent":null,"model":null,"bundle":"untracked/TX-bundle.md","set":"A","holds":[],"needs":[],"caps":[],"added":"2026-08-22T00:00:00Z","claim_count":0}
        \\}
    ;
    var state = try parseStateJson(content);
    defer freeState(&state);
    const ts = state.get("TX").?;
    try std.testing.expect(ts.shape == null);
    try std.testing.expectEqual(@as(usize, 0), ts.shape_reasons.len);
}

test "shape: shape + shape_reasons round-trip serialize → parse" {
    var state = StateMap{};
    defer freeState(&state);

    var ts = TaskState{
        .status = .dispatchable,
        .bundle = "untracked/TX-bundle.md",
        .set = 'A',
        .added = "2026-08-22T00:00:00Z",
    };
    ts.bundle = try alloc.dupe(u8, "untracked/TX-bundle.md");
    ts.added = try alloc.dupe(u8, "2026-08-22T00:00:00Z");
    ts.shape = try alloc.dupe(u8, "panel");
    var sreas = std.ArrayList([]const u8).empty;
    try sreas.append(alloc, try alloc.dupe(u8, "claude-opus-5: adds 3 unique catch(es) given seats so far"));
    ts.shape_reasons = try sreas.toOwnedSlice(alloc);

    try state.put(alloc, try alloc.dupe(u8, "TX"), ts);

    var buf = std.ArrayList(u8).empty;
    defer buf.deinit(alloc);
    try serializeState(&state, &buf);

    var parsed = try parseStateJson(buf.items);
    defer freeState(&parsed);
    const p = parsed.get("TX").?;
    try std.testing.expectEqualStrings("panel", p.shape.?);
    try std.testing.expectEqual(@as(usize, 1), p.shape_reasons.len);
    try std.testing.expectEqualStrings("claude-opus-5: adds 3 unique catch(es) given seats so far", p.shape_reasons[0]);
}

test "solo: §5-failing lane is not picked even when cheapest (T772)" {
    var prng = std.Random.DefaultPrng.init(0);
    // haiku is the cheapest by far but fails the §5 gate; opus and flash are
    // qualified.  The pick must never reach haiku — the defect this row fixes.
    const cands = [_][]const u8{ "claude-haiku-4-5-20251001", "claude-opus-5", "deepseek-v4-flash" };
    const quals = [_]Qualification{ .underqualified, .qualified, .qualified };
    const data_counts = [_]u32{ 5, 20, 30 };
    const costs = [_]CostReport{
        .{ .median = 1000, .has_retro = false },
        .{ .median = 2000, .has_retro = false },
        .{ .median = 3000, .has_retro = false },
    };
    var sreasons = std.ArrayList([]const u8).empty;
    defer {
        for (sreasons.items) |x| alloc.free(x);
        sreasons.deinit(alloc);
    }

    const pick = try soloPick(&cands, &quals, &data_counts, &costs, prng.random(), &sreasons);
    defer alloc.free(pick.model);
    defer alloc.free(pick.method);
    // opus: qualified, and fewer ledger rows (20) than flash (30).
    try std.testing.expectEqualStrings("claude-opus-5", pick.model);
    try std.testing.expectEqualStrings("solo-least-data", pick.method);
    var saw_underqualified = false;
    for (sreasons.items) |r| {
        if (std.mem.indexOf(u8, r, "claude-haiku-4-5-20251001: underqualified") != null) saw_underqualified = true;
    }
    try std.testing.expect(saw_underqualified);
}

test "solo: least-data qualified chosen, the two passed over recorded" {
    var prng = std.Random.DefaultPrng.init(0);
    const cands = [_][]const u8{ "claude-opus-5", "claude-sonnet-5", "deepseek-v4-flash" };
    const quals = [_]Qualification{ .qualified, .qualified, .qualified };
    const data_counts = [_]u32{ 50, 20, 30 };
    const costs = [_]CostReport{
        .{ .median = 5000, .has_retro = false },
        .{ .median = 2000, .has_retro = false },
        .{ .median = 3000, .has_retro = false },
    };
    var sreasons = std.ArrayList([]const u8).empty;
    defer {
        for (sreasons.items) |x| alloc.free(x);
        sreasons.deinit(alloc);
    }

    const pick = try soloPick(&cands, &quals, &data_counts, &costs, prng.random(), &sreasons);
    defer alloc.free(pick.model);
    defer alloc.free(pick.method);
    // sonnet is cheapest but that no longer decides: it has the FEWEST rows.
    try std.testing.expectEqualStrings("claude-sonnet-5", pick.model);
    try std.testing.expectEqualStrings("solo-least-data", pick.method);
    try std.testing.expectEqual(@as(usize, 3), sreasons.items.len);
    var saw_opus = false;
    var saw_flash = false;
    for (sreasons.items) |r| {
        if (std.mem.indexOf(u8, r, "claude-opus-5: passed over") != null) saw_opus = true;
        if (std.mem.indexOf(u8, r, "deepseek-v4-flash: passed over") != null) saw_flash = true;
    }
    try std.testing.expect(saw_opus);
    try std.testing.expect(saw_flash);
}

test "solo: unmeasured is eligible but never preferred over qualified" {
    var prng = std.Random.DefaultPrng.init(0);
    // pro is unmeasured with 0 ledger rows (least-data) but a qualified model
    // exists, so the qualified one wins — D027: unmeasured is eligible, never
    // preferred over qualified.
    const cands = [_][]const u8{ "claude-opus-5", "deepseek-v4-pro" };
    const quals = [_]Qualification{ .qualified, .unmeasured };
    const data_counts = [_]u32{ 100, 0 };
    const costs = [_]CostReport{
        .{ .median = null, .has_retro = false },
        .{ .median = null, .has_retro = false },
    };
    var sreasons = std.ArrayList([]const u8).empty;
    defer {
        for (sreasons.items) |x| alloc.free(x);
        sreasons.deinit(alloc);
    }
    const pick = try soloPick(&cands, &quals, &data_counts, &costs, prng.random(), &sreasons);
    defer alloc.free(pick.model);
    defer alloc.free(pick.method);
    try std.testing.expectEqualStrings("claude-opus-5", pick.model);
    try std.testing.expectEqualStrings("solo-least-data", pick.method);
}

test "solo: all unmeasured → least-data (D027 try), not a cost draw" {
    var prng = std.Random.DefaultPrng.init(0);
    const cands = [_][]const u8{ "claude-opus-5", "deepseek-v4-pro", "deepseek-v4-flash" };
    const quals = [_]Qualification{ .unmeasured, .unmeasured, .unmeasured };
    const data_counts = [_]u32{ 30, 5, 10 };
    const costs = [_]CostReport{
        .{ .median = null, .has_retro = false },
        .{ .median = null, .has_retro = false },
        .{ .median = null, .has_retro = false },
    };
    var sreasons = std.ArrayList([]const u8).empty;
    defer {
        for (sreasons.items) |x| alloc.free(x);
        sreasons.deinit(alloc);
    }
    const pick = try soloPick(&cands, &quals, &data_counts, &costs, prng.random(), &sreasons);
    defer alloc.free(pick.model);
    defer alloc.free(pick.method);
    // pro has the fewest ledger rows (5) → the exploration pick.
    try std.testing.expectEqualStrings("deepseek-v4-pro", pick.model);
    try std.testing.expectEqualStrings("solo-least-data", pick.method);
}

test "solo: trusted:false retro cost is labelled in shape_reasons, never silent" {
    var prng = std.Random.DefaultPrng.init(0);
    const cands = [_][]const u8{ "claude-opus-5", "deepseek-v4-pro" };
    const quals = [_]Qualification{ .qualified, .qualified };
    const data_counts = [_]u32{ 10, 20 };
    const costs = [_]CostReport{
        .{ .median = 5000, .has_retro = true },
        .{ .median = null, .has_retro = false },
    };
    var sreasons = std.ArrayList([]const u8).empty;
    defer {
        for (sreasons.items) |x| alloc.free(x);
        sreasons.deinit(alloc);
    }
    const pick = try soloPick(&cands, &quals, &data_counts, &costs, prng.random(), &sreasons);
    defer alloc.free(pick.model);
    defer alloc.free(pick.method);
    try std.testing.expectEqualStrings("claude-opus-5", pick.model);
    var saw_retro = false;
    for (sreasons.items) |r| {
        if (std.mem.indexOf(u8, r, "trusted:false retro") != null) saw_retro = true;
    }
    try std.testing.expect(saw_retro);
}

test "solo: all underqualified → NoQualifiedCandidate" {
    var prng = std.Random.DefaultPrng.init(0);
    const cands = [_][]const u8{ "A", "B" };
    const quals = [_]Qualification{ .underqualified, .underqualified };
    const data_counts = [_]u32{ 0, 0 };
    const costs = [_]CostReport{
        .{ .median = null, .has_retro = false },
        .{ .median = null, .has_retro = false },
    };
    var sreasons = std.ArrayList([]const u8).empty;
    defer {
        for (sreasons.items) |x| alloc.free(x);
        sreasons.deinit(alloc);
    }
    try std.testing.expectError(error.NoQualifiedCandidate, soloPick(&cands, &quals, &data_counts, &costs, prng.random(), &sreasons));
}

test "panel: B strict subset of A → disjoint C is the second seat, not B" {
    const names = [_][]const u8{ "A", "B", "C" };
    const caught = [_][]const []const u8{
        &.{ "x", "y", "z" },
        &.{ "x", "y" },
        &.{ "w" },
    };
    const data_counts = [_]u32{ 0, 0, 0 };
    const seats = [_][]const u8{"A"};
    var sreasons = std.ArrayList([]const u8).empty;
    defer {
        for (sreasons.items) |x| alloc.free(x);
        sreasons.deinit(alloc);
    }
    const next = try greedyPanelStep(&names, &caught, &data_counts, &seats, &sreasons);
    const idx = next orelse return error.TestFailed;
    try std.testing.expectEqualStrings("C", names[idx]);
    try std.testing.expectEqual(@as(usize, 1), sreasons.items.len);
    try std.testing.expect(std.mem.indexOf(u8, sreasons.items[0], "C: adds 1 unique catch(es)") != null);
}

test "panel: empty seats → anchor is the highest-coverage model" {
    const names = [_][]const u8{ "A", "B", "C" };
    const caught = [_][]const []const u8{
        &.{ "x", "y", "z" },
        &.{ "x", "y" },
        &.{ "w" },
    };
    const data_counts = [_]u32{ 0, 0, 0 };
    const seats = [_][]const u8{};
    var sreasons = std.ArrayList([]const u8).empty;
    defer {
        for (sreasons.items) |x| alloc.free(x);
        sreasons.deinit(alloc);
    }
    const next = try greedyPanelStep(&names, &caught, &data_counts, &seats, &sreasons);
    const idx = next orelse return error.TestFailed;
    try std.testing.expectEqualStrings("A", names[idx]);
}

test "panel: equal marginals break on D027 least-data, not cost" {
    const names = [_][]const u8{ "A", "B" };
    const caught = [_][]const []const u8{ &.{"x"}, &.{"y"} };
    const data_counts = [_]u32{ 50, 5 };
    const seats = [_][]const u8{};
    var sreasons = std.ArrayList([]const u8).empty;
    defer {
        for (sreasons.items) |x| alloc.free(x);
        sreasons.deinit(alloc);
    }
    const next = try greedyPanelStep(&names, &caught, &data_counts, &seats, &sreasons);
    const idx = next orelse return error.TestFailed;
    // Both add one unique catch given empty seats; B has the fewest rows.
    try std.testing.expectEqualStrings("B", names[idx]);
}

test "panel: empty complementarity record → prior-driven, labelled loudly" {
    var prng = std.Random.DefaultPrng.init(0);
    const candidates = [_][]const u8{ "claude-opus-5", "deepseek-v4-pro" };
    var caught = CaughtSets{};
    defer freeCaughtSets(&caught);
    const data_counts = [_]u32{ 0, 0 };
    const seats = [_][]const u8{};
    var sreasons = std.ArrayList([]const u8).empty;
    defer {
        for (sreasons.items) |x| alloc.free(x);
        sreasons.deinit(alloc);
    }

    const pick = try panelPick(&candidates, &caught, &data_counts, &seats, prng.random(), &sreasons);
    defer alloc.free(pick.model);
    defer alloc.free(pick.method);
    try std.testing.expectEqualStrings("panel-prior", pick.method);
    var is_candidate = false;
    for (candidates) |c| {
        if (std.mem.eql(u8, c, pick.model)) is_candidate = true;
    }
    try std.testing.expect(is_candidate);
    var saw_prior = false;
    for (sreasons.items) |r| {
        if (std.mem.indexOf(u8, r, "prior-driven") != null) saw_prior = true;
    }
    try std.testing.expect(saw_prior);
}

test "panel: greedy marginal over a seeded caught map picks the disjoint seat" {
    var prng = std.Random.DefaultPrng.init(0);
    // A catches x,y,z; B catches x,y (strict subset); C catches w (disjoint).
    const candidates = [_][]const u8{ "A", "B", "C" };
    var caught = CaughtSets{};
    defer freeCaughtSets(&caught);
    {
        const eA = try caught.getOrPut(alloc, "A");
        eA.key_ptr.* = try alloc.dupe(u8, "A");
        eA.value_ptr.* = .{};
        try eA.value_ptr.put(alloc, try alloc.dupe(u8, "x"), {});
        try eA.value_ptr.put(alloc, try alloc.dupe(u8, "y"), {});
        try eA.value_ptr.put(alloc, try alloc.dupe(u8, "z"), {});
        const eB = try caught.getOrPut(alloc, "B");
        eB.key_ptr.* = try alloc.dupe(u8, "B");
        eB.value_ptr.* = .{};
        try eB.value_ptr.put(alloc, try alloc.dupe(u8, "x"), {});
        try eB.value_ptr.put(alloc, try alloc.dupe(u8, "y"), {});
        const eC = try caught.getOrPut(alloc, "C");
        eC.key_ptr.* = try alloc.dupe(u8, "C");
        eC.value_ptr.* = .{};
        try eC.value_ptr.put(alloc, try alloc.dupe(u8, "w"), {});
    }
    const data_counts = [_]u32{ 0, 0, 0 };
    const seats = [_][]const u8{"A"};
    var sreasons = std.ArrayList([]const u8).empty;
    defer {
        for (sreasons.items) |x| alloc.free(x);
        sreasons.deinit(alloc);
    }
    const pick = try panelPick(&candidates, &caught, &data_counts, &seats, prng.random(), &sreasons);
    defer alloc.free(pick.model);
    defer alloc.free(pick.method);
    try std.testing.expectEqualStrings("panel-greedy", pick.method);
    try std.testing.expectEqualStrings("C", pick.model);
}

// ═══════════════════════════════════════════════════════════════════════════════
// T682 tests — registration-time landmark gate
// ═══════════════════════════════════════════════════════════════════════════════

test "landmark: absent line → absent (the T592 defect)" {
    const body =
        \\<!--managent set=A deliverables=docs/x.md-->
        \\# T592 — tools census
        \\
        \\Work that declares no landmark at all.
    ;
    try std.testing.expectEqual(LandmarkVerdict.absent, checkBundleLandmark(body));
}

test "landmark: wrong marker spelling → absent" {
    const body =
        \\<!--managent set=A-->
        \\# T682 — marker typo
        \\
        \\*Landmark:* L1 (the dashboard tells the truth)
    ;
    try std.testing.expectEqual(LandmarkVerdict.absent, checkBundleLandmark(body));
}

test "landmark: bare id (T682's own form) → declared" {
    const body =
        \\<!--managent set=A-->
        \\# T682 — require a landmark at registration
        \\
        \\**Landmark:** L1 (measurement integrity) — and the row is its own worked example.
    ;
    try std.testing.expectEqual(LandmarkVerdict.declared, checkBundleLandmark(body));
}

test "landmark: advances + backticked id + short name (common form) → declared" {
    const body =
        \\<!--managent set=A-->
        \\# T351 — two surfaces
        \\
        \\**Landmark:** advances `L1 (the dashboard tells the truth)` — the noise makes the suite read red on a glance.
    ;
    try std.testing.expectEqual(LandmarkVerdict.declared, checkBundleLandmark(body));
}

test "landmark: bare backticked id, no short name → declared" {
    const body =
        \\<!--managent set=A-->
        \\# T403 — gtp boardsize desync
        \\
        \\**Landmark:** advances `L0` usability — the first thing a human hits.
    ;
    try std.testing.expectEqual(LandmarkVerdict.declared, checkBundleLandmark(body));
}

test "landmark: two ids in one line → declared" {
    const body =
        \\<!--managent set=A-->
        \\# T379 — trajectory consistency
        \\
        \\**Landmark:** advances `L2 (proven 4×4 values)` and `L3 (the new engine outplays the old one)` by ...
    ;
    try std.testing.expectEqual(LandmarkVerdict.declared, checkBundleLandmark(body));
}

test "landmark: protects / unblocks verbs → declared" {
    const protect =
        \\**Landmark:** protects `L2 (proven 4×4 values)` from contamination.
    ;
    try std.testing.expectEqual(LandmarkVerdict.declared, checkBundleLandmark(protect));
    const unblock =
        \\**Landmark:** unblocks the open question on `L2 (proven 4×4 values)` — whether the capture budget ...
    ;
    try std.testing.expectEqual(LandmarkVerdict.declared, checkBundleLandmark(unblock));
}

test "landmark: sanctioned no-landmark form → declared" {
    const body =
        \\**Landmark:** none directly; unblocks T352
    ;
    try std.testing.expectEqual(LandmarkVerdict.declared, checkBundleLandmark(body));
    const body2 =
        \\**Landmark:** None directly.
    ;
    try std.testing.expectEqual(LandmarkVerdict.declared, checkBundleLandmark(body2));
}

test "landmark: blockquote and bullet wrappers → declared" {
    const quoted =
        \\> **Landmark:** advances `L2 (proven 4×4 values)` — what is now visible.
    ;
    try std.testing.expectEqual(LandmarkVerdict.declared, checkBundleLandmark(quoted));
    const bullet =
        \\- **Landmark:** advances `L1 (the dashboard tells the truth)` — the gauge now reads true.
    ;
    try std.testing.expectEqual(LandmarkVerdict.declared, checkBundleLandmark(bullet));
}

test "landmark: id mid-line with trailing prose → declared" {
    const body =
        \\**Landmark:** advances `L4` and the fleet's capacity. Operator, 2026-08-07.
    ;
    try std.testing.expectEqual(LandmarkVerdict.declared, checkBundleLandmark(body));
}

test "landmark: unknown id L99 → invalid" {
    const body =
        \\**Landmark:** advances `L99 (bogus)` — this is not a landmark.
    ;
    try std.testing.expectEqual(LandmarkVerdict.invalid, checkBundleLandmark(body));
}

test "landmark: prose-only declaration (no id) → invalid" {
    const body =
        \\**Landmark:** this row advances dashboard-truth work.
    ;
    try std.testing.expectEqual(LandmarkVerdict.invalid, checkBundleLandmark(body));
}

test "landmark: empty declaration → invalid" {
    try std.testing.expectEqual(LandmarkVerdict.invalid, checkBundleLandmark("**Landmark:**"));
    try std.testing.expectEqual(LandmarkVerdict.invalid, checkBundleLandmark("**Landmark:**   \n"));
}

test "landmark: nonsense is not the none-form → invalid" {
    try std.testing.expectEqual(LandmarkVerdict.invalid, checkBundleLandmark("**Landmark:** nonsense about the goban"));
    try std.testing.expectEqual(LandmarkVerdict.invalid, checkBundleLandmark("**Landmark:** nonedirectly"));
}

test "landmark: out-of-range and glued ids → invalid" {
    try std.testing.expectEqual(LandmarkVerdict.invalid, checkBundleLandmark("**Landmark:** advances `L12 (too big)`"));
    try std.testing.expectEqual(LandmarkVerdict.invalid, checkBundleLandmark("**Landmark:** advances `CL1` — not a landmark"));
    try std.testing.expectEqual(LandmarkVerdict.invalid, checkBundleLandmark("**Landmark:** advances `L2cache`"));
}

test "landmark: id at string start, no leading verb → declared" {
    try std.testing.expectEqual(LandmarkVerdict.declared, checkBundleLandmark("**Landmark:** L3 (the new engine outplays the old one) — measured"));
}

test "landmark: the landmark line is found anywhere in the body, not only line 1" {
    const body =
        \\<!--managent set=A-->
        \\# T682 — mid-file landmark
        \\
        \\The failure, and why prose did not prevent it.  A long paragraph.
        \\Another paragraph, still no marker.  Then:
        \\
        \\**Landmark:** advances `L1 (measurement integrity)` — the census tells us whether this is five rows or a hundred.
    ;
    try std.testing.expectEqual(LandmarkVerdict.declared, checkBundleLandmark(body));
}

test "landmark: D4-adopted ids L8/L9 declare; proposed L10 does not" {
    try std.testing.expectEqual(LandmarkVerdict.declared, checkBundleLandmark("**Landmark:** L9 (the fleet can race its own workers on demand). Ruling 7: aspect races GO now."));
    try std.testing.expectEqual(LandmarkVerdict.declared, checkBundleLandmark("**Landmark:** advances `L4 (the ledger is clean)` and `L8 (the language the project speaks is unambiguous)`."));
    try std.testing.expectEqual(LandmarkVerdict.invalid, checkBundleLandmark("**Landmark:** candidate `L10 (the repository tells its story cleanly)` — proposed."));
}

// ═══════════════════════════════════════════════════════════════════════════════
// T760 tests — --needs comma split + add-time existence validation
// ═══════════════════════════════════════════════════════════════════════════════

test "add: --needs a,b,c splits into three needs (T760)" {
    var threaded = std.Io.Threaded.init(alloc, .{});
    defer threaded.deinit();
    const io = threaded.io();
    const w = Writers{ .io = io };

    // Disposable scratch under /tmp/weizigo — never the repo tree.
    std.Io.Dir.cwd().createDirPath(io, "/tmp/weizigo") catch {};
    const path = "/tmp/weizigo/T760-needs-split-test-bundle.md";
    {
        const file = std.Io.Dir.createFileAbsolute(io, path, .{}) catch |err| {
            std.debug.print("T760 test: cannot create {s}: {}\n", .{ path, err });
            return error.TestFailed;
        };
        defer file.close(io);
        try file.writeStreamingAll(io, "<!--managent set=A -->\n# T760 test bundle\n");
    }
    defer std.Io.Dir.deleteFileAbsolute(io, path) catch {};

    const meta = try parseBundleMeta(w, io, path, null, "T754,T755,T756");
    try std.testing.expectEqual(@as(usize, 3), meta.needs.len);
    try std.testing.expectEqualStrings("T754", meta.needs[0]);
    try std.testing.expectEqualStrings("T755", meta.needs[1]);
    try std.testing.expectEqualStrings("T756", meta.needs[2]);
}

test "add: validateNeedsExist returns null when every need is registered (T760)" {
    var state = StateMap{};
    defer freeState(&state);
    var ts = TaskState{ .status = .dispatchable, .set = 'A' };
    ts.bundle = try alloc.dupe(u8, "untracked/TX.md");
    ts.added = try alloc.dupe(u8, "2026-08-23T00:00:00Z");
    try state.put(alloc, try alloc.dupe(u8, "T700"), ts);

    var threaded = std.Io.Threaded.init(alloc, .{});
    defer threaded.deinit();
    const io = threaded.io();
    const w = Writers{ .io = io };

    const needs = [_][]const u8{"T700"};
    const rec = try validateNeedsExist(w, &state, &needs, null);
    try std.testing.expectEqual(@as(?[]const u8, null), rec);
}

test "add: validateNeedsExist records the escape for a missing need (T760)" {
    var state = StateMap{};
    defer freeState(&state);

    var threaded = std.Io.Threaded.init(alloc, .{});
    defer threaded.deinit();
    const io = threaded.io();
    const w = Writers{ .io = io };

    const needs = [_][]const u8{ "T754", "T755" };
    const rec = (try validateNeedsExist(w, &state, &needs, "same-batch forward edge")).?;
    try std.testing.expect(std.mem.indexOf(u8, rec, "T754") != null);
    try std.testing.expect(std.mem.indexOf(u8, rec, "T755") != null);
    try std.testing.expect(std.mem.indexOf(u8, rec, "same-batch forward edge") != null);
}

// ═══════════════════════════════════════════════════════════════════════════════
// T880 tests — space-separated list values in bundle headers
// ═══════════════════════════════════════════════════════════════════════════════
// The bundle header is tokenized on spaces, so `holds=a.zig b.zig c.zig` used
// to register only a.zig — two files silently dropped, no warning (T872: four
// declared, zero stored; T877: three declared, one stored).  These probe the
// two sibling list-valued fields (needs=, deliverables=) as well: needs= shares
// the token-loop defect; deliverables= has its own parse in
// parseDeliverablesFromBundle, which used to fold `deliverables=a.zig b.zig`
// into ONE element "a.zig b.zig" — a path that can never exist.

// scratch bundle path helper for the T880 parse probes
fn t880Bundle(io: std.Io, header: []const u8) []const u8 {
    std.Io.Dir.cwd().createDirPath(io, "/tmp/weizigo") catch {};
    const path = "/tmp/weizigo/T880-probe-bundle.md";
    const file = std.Io.Dir.createFileAbsolute(io, path, .{}) catch |err| {
        std.debug.print("T880 test: cannot create {s}: {}\n", .{ path, err });
        return "";
    };
    defer file.close(io);
    file.writeStreamingAll(io, header) catch {};
    file.writeStreamingAll(io, "\n# T880 probe bundle\n") catch {};
    return path;
}

test "T880: holds= header accepts space-separated and mixed lists" {
    var threaded = std.Io.Threaded.init(alloc, .{});
    defer threaded.deinit();
    const io = threaded.io();
    const w = Writers{ .io = io };

    // Space-separated: all three must land.
    const path1 = t880Bundle(io, "<!--managent set=A holds=a.zig b.zig c.zig-->");
    defer std.Io.Dir.deleteFileAbsolute(io, path1) catch {};
    const meta1 = try parseBundleMeta(w, io, path1, null, null);
    try std.testing.expectEqual(@as(usize, 3), meta1.holds.len);
    try std.testing.expectEqualStrings("a.zig", meta1.holds[0]);
    try std.testing.expectEqualStrings("b.zig", meta1.holds[1]);
    try std.testing.expectEqualStrings("c.zig", meta1.holds[2]);

    // Mixed comma + space: all three must land.
    const path2 = t880Bundle(io, "<!--managent set=A holds=a.zig,b.zig c.zig-->");
    defer std.Io.Dir.deleteFileAbsolute(io, path2) catch {};
    const meta2 = try parseBundleMeta(w, io, path2, null, null);
    try std.testing.expectEqual(@as(usize, 3), meta2.holds.len);
    try std.testing.expectEqualStrings("a.zig", meta2.holds[0]);
    try std.testing.expectEqualStrings("b.zig", meta2.holds[1]);
    try std.testing.expectEqualStrings("c.zig", meta2.holds[2]);

    // Comma list still works (regression guard).
    const path3 = t880Bundle(io, "<!--managent set=A holds=a.zig,b.zig,c.zig-->");
    defer std.Io.Dir.deleteFileAbsolute(io, path3) catch {};
    const meta3 = try parseBundleMeta(w, io, path3, null, null);
    try std.testing.expectEqual(@as(usize, 3), meta3.holds.len);

    // A following key= token ends the list; its bare tokens are not holds
    // (acceptance= owns the rest of the line — T217).
    const path4 = t880Bundle(io, "<!--managent set=A holds=docs/one.md acceptance=sh tools/run.sh-->");
    defer std.Io.Dir.deleteFileAbsolute(io, path4) catch {};
    const meta4 = try parseBundleMeta(w, io, path4, null, null);
    try std.testing.expectEqual(@as(usize, 1), meta4.holds.len);
    try std.testing.expectEqualStrings("docs/one.md", meta4.holds[0]);

    // T880 (live damage): `priority=N`/`waiting=1` are header KEYS (D022,
    // fleet-keeper reads them), never held files — a following key must not
    // be absorbed as a hold.  The first sync run polluted 26 rows with
    // "priority=99" holds before this was pinned.
    const path5 = t880Bundle(io, "<!--managent set=A holds=docs/one.md priority=99-->");
    defer std.Io.Dir.deleteFileAbsolute(io, path5) catch {};
    const meta5 = try parseBundleMeta(w, io, path5, null, null);
    try std.testing.expectEqual(@as(usize, 1), meta5.holds.len);
    try std.testing.expectEqualStrings("docs/one.md", meta5.holds[0]);

    const path6 = t880Bundle(io, "<!--managent set=A holds=docs/one.md waiting=1-->");
    defer std.Io.Dir.deleteFileAbsolute(io, path6) catch {};
    const meta6 = try parseBundleMeta(w, io, path6, null, null);
    try std.testing.expectEqual(@as(usize, 1), meta6.holds.len);
    try std.testing.expectEqualStrings("docs/one.md", meta6.holds[0]);

    // The sync path (readBundleHolds) must agree — it is what reconciled the
    // live store.
    const path7 = t880Bundle(io, "<!--managent set=A holds=docs/one.md priority=99-->");
    defer std.Io.Dir.deleteFileAbsolute(io, path7) catch {};
    const rb7 = readBundleHolds(io, path7).?;
    defer alloc.free(rb7);
    try std.testing.expectEqual(@as(usize, 1), rb7.len);
    try std.testing.expectEqualStrings("docs/one.md", rb7[0]);
}

test "T880: needs= header accepts space-separated lists (same token loop)" {
    var threaded = std.Io.Threaded.init(alloc, .{});
    defer threaded.deinit();
    const io = threaded.io();
    const w = Writers{ .io = io };

    const path = t880Bundle(io, "<!--managent set=A needs=T880A1 T880A2-->");
    defer std.Io.Dir.deleteFileAbsolute(io, path) catch {};
    const meta = try parseBundleMeta(w, io, path, null, null);
    try std.testing.expectEqual(@as(usize, 2), meta.needs.len);
    try std.testing.expectEqualStrings("T880A1", meta.needs[0]);
    try std.testing.expectEqualStrings("T880A2", meta.needs[1]);
}

test "T880: deliverables= header accepts space-separated lists" {
    var threaded = std.Io.Threaded.init(alloc, .{});
    defer threaded.deinit();
    const io = threaded.io();
    const w = Writers{ .io = io };

    const path = t880Bundle(io, "<!--managent set=A deliverables=a.zig b.zig-->");
    defer std.Io.Dir.deleteFileAbsolute(io, path) catch {};
    const dels = try parseDeliverablesFromBundle(w, io, path, &.{});
    defer {
        for (dels) |d| alloc.free(d);
        alloc.free(dels);
    }
    try std.testing.expectEqual(@as(usize, 2), dels.len);
    try std.testing.expectEqualStrings("a.zig", dels[0]);
    try std.testing.expectEqualStrings("b.zig", dels[1]);

    // Comma list still works, and a stray `holds=` placeholder after
    // deliverables= must NOT leak as a deliverable path.
    const path2 = t880Bundle(io, "<!--managent set=A deliverables=a.zig,b.zig holds=-->");
    defer std.Io.Dir.deleteFileAbsolute(io, path2) catch {};
    const dels2 = try parseDeliverablesFromBundle(w, io, path2, &.{});
    defer {
        for (dels2) |d| alloc.free(d);
        alloc.free(dels2);
    }
    try std.testing.expectEqual(@as(usize, 2), dels2.len);
    try std.testing.expectEqualStrings("a.zig", dels2[0]);
    try std.testing.expectEqualStrings("b.zig", dels2[1]);
}
