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
//   C1a ORPHANED (orphan detection) — a PROVEN/CLAIMED claim with a transitive
//       `derives-from` (`d:`) ancestor that is FALSE-AS-SCOPED or FALSE.
//       PAST FAILURE: O1. The project wrote "bracket cuts are C3" and "C3 is
//       falsified" in two documents and did not notice for weeks that the
//       finisher behind every shipped ko-sensitive value depended on it
//       (CLAIMS.md §4.1 O1; critique-2026-07-28.md §4 M-F0).
//
//   C1b STALE-NEGATION (negation alarm) — an `n:` (derives-from-negation) edge
//       whose parent is NOT false. This project is driven by falsifications: whole positions
//       are adopted BECAUSE a claim fell. `GLOBAL.REFRAME` exists because C2,
//       C3 and C4 are false; if any of them were rehabilitated, the reframe and
//       everything under it would need re-examining and nothing would say so.
//       Propagation is inverted, so this is a real check, not the mirror image
//       of a formatting rule.
//
//   C2  DEAD-LINKS (dangling evidence) — a cited file path that does not exist
//       on disk.
//       C2a: paths in the register's own evidence column.
//       C2b: paths named inside the documents the evidence column cites —
//       the reproduction inputs. PAST FAILURE: the T13 class. The reproduction
//       block in docs/research/c2-falsification-3x2.md:124-129 names
//       `-Mmain=untracked/c2pilot_3x2.zig`, which was deleted; the falsification
//       the whole reframe rests on can be read but not re-run
//       (docs/evidence/README.md, CLAIMS.md §7).
//
//   C3  UNBACKED (proven without committed evidence) — a PROVEN claim whose
//       evidence does not resolve under docs/evidence/. PAST FAILURE: roadmap-2026-07-28.md
//       §4 P1 — 57 scratch files were swept on 2026-07-27, taking the primary
//       evidence for T13, T02/B1, T07 and B05 with them. A claim whose evidence
//       cannot be retrieved is not proven; it is remembered.
//
//   C5  SHADOWED (shadowed dependency) — a `d:` edge whose parent is a
//       MEASUREMENT row.
//       A measurement records that something *happened*; it is not a truth-claim
//       that it was *correct*. PAST FAILURE: `3x3.C1` ("fresh-start scores
//       correct at 3×3") carried `d:3x3.F2`, and `3x3.F2` measures only that
//       the finisher COMPLETED all 622 orbit reps. Completion is not soundness.
//       The real parent is `GLOBAL.F2` (the finisher is *sound*), which is
//       orphaned via `GLOBAL.C3` — falsified at 3×3, the very goban. The
//       measurement sat in the chain and stopped the falsification propagating,
//       so C1a never saw the case CLAIMS.md §4.1-O3 calls the sharpest.
//
//   C4  GHOST-IDS (dangling claim IDs) — an ID cited in docs/ that has no
//       register row
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

/// T373: the archive index that resolves IDs moved out of the live register.
/// C4 treats an ID listed here as archived (not dangling); the reader's entry
/// point is archives/register/INDEX.md.
const ARCHIVE_INDEX_PATH = "archives/register/INDEX.md";

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

/// The canonical name↔number mapping — the ONE source of truth (T356).
/// The ID is the stable reference: it is the key in the floor file, the token
/// in existing documents and commit messages, and what anything
/// machine-readable matches on. The name is for human comprehension — `C3`
/// alone tells a reader nothing; `C3 UNBACKED` does. Every output line carries
/// both, ID first. Do not duplicate these name strings anywhere else: a second
/// copy is the divergence this project keeps paying for. Add a name here and
/// it flows to every section header, failure line and summary row via
/// `checkName`.
const Check = struct { id: []const u8, name: []const u8 };
const CHECKS = [_]Check{
    .{ .id = "C1a", .name = "ORPHANED" },
    .{ .id = "C1b", .name = "STALE-NEGATION" },
    .{ .id = "C2", .name = "DEAD-LINKS" },
    .{ .id = "C3", .name = "UNBACKED" },
    .{ .id = "C4", .name = "GHOST-IDS" },
    .{ .id = "C5", .name = "SHADOWED" },
    .{ .id = "C6", .name = "MISCITED" },
    .{ .id = "C7", .name = "UNABSORBED" },
    .{ .id = "C8", .name = "UNKILLED" },
    .{ .id = "C9", .name = "UNMAPPED" },
    .{ .id = "C10", .name = "VOLATILE" },
};

/// The canonical name for a check ID, e.g. `checkName("C3")` → `UNBACKED`.
/// Used in every output line so the name can never drift from the mapping.
fn checkName(id: []const u8) []const u8 {
    for (CHECKS) |c| if (std.mem.eql(u8, c.id, id)) return c.name;
    return "?";
}

/// The narrative files cite-tagged against the register. C6 scans each for
/// `[ID:STATUS]` tags and verifies them against the register. The set is
/// deliberately a slice — the next gating document will have the same problem
/// (GRAND-AUDIT §1c, T272).
const NARRATIVE_FILES = [_][]const u8{
    "docs/epistemic/PROGRESS.md",
    "docs/epic-01-markovian/AXIOMS.md",
};

// ── calibration cases ────────────────────────────────────────────────────────
// Named here, checked at the end of every run. If the checker stops catching
// these, the checker is broken — not the register.
// The C1a known-bad used to be a real-data case (`GLOBAL.F2` reported with
// `GLOBAL.C3` in its chain) but the register triage (T373, 2026-08-06) moved
// every real orphan — including `GLOBAL.F2` — out of the live register, so C1a
// went 10 → 0 on real data. A real-register case that disappears when the
// register is cleaned is not a calibration case (same lesson as C5's); the
// known-bad now lives in the synthetic register, exactly like C1b's and C5's,
// grafting an orphan child onto the synthetic FALSE parent so the check still
// exercises a FALSE ancestor. `GLOBAL.C3` stays live in the real register, so
// the FALSE-ancestor concept the fixture exercises is still real.
const CAL_DANGLING = "untracked/c2pilot_3x2.zig"; // must be reported by C2
const CAL_CLEAN = "GLOBAL.ADR0003-AREA"; // PROVEN, real evidence, must be silent
const CAL_NEG_OK = "GLOBAL.REFRAME"; // carries `n:` to a FALSE parent — must be SILENT
/// C5's known-bad lives in the synthetic register, not in the data. The first
/// version calibrated against `3x3.C1 d: 3x3.F2` — the exact edge C5 exists to
/// get fixed — and went MISSED the moment the fix landed. A calibration case
/// that disappears when the register improves is not a calibration case.
/// Re-based 2026-08-06 (T373): `GLOBAL.F2` (the old known-good) left the live
/// register in the triage; `GLOBAL.ADR0020-LH-CORRECT` stays and carries three
/// `d:` edges to real claims (AXIOM-BELLMAN, AXIOM-LH, AXIOM-BRACKET) — same shape.
const CAL_SHADOW_CLEAN = "GLOBAL.ADR0020-LH-CORRECT"; // real-data known-good: `d:` only to real claims
/// C1a's known-bad — synthetic (see the comment above): a CLAIMED row whose
/// only `d:` edge reaches the synthetic FALSE parent must be reported; a
/// CLAIMED row whose `d:` edge reaches a PROVEN parent must stay silent.
const CAL_SYNTHETIC_C1A_EXTRA =
    \\| `GLOBAL.CALCHILD-ORPHAN` | — | all | synthetic: orphan of a FALSE parent — must be caught | CLAIMED | `AGENTS.md:1` | `d:GLOBAL.CALPARENT-DEAD` | — | 0 | ? | Z-NONCLAIMS |
    \\| `GLOBAL.CALCHILD-ORPHAN-CLEAN` | — | all | synthetic: child of a PROVEN parent — must stay silent | CLAIMED | `AGENTS.md:1` | `d:GLOBAL.CALPARENT-LIVE` | — | 0 | ? | Z-NONCLAIMS |
;
/// C6 calibration — a synthetic narrative text with one wrong-status tag and
/// two correct-status tags. The wrong one must be caught, the right ones must
/// pass silently. The known-bad uses a real ID with a deliberately wrong status.
/// Re-based 2026-08-06 (T373): `GLOBAL.R1` (the old known-good) left the live
/// register; `GLOBAL.INVSYM` stays PROVEN with the same shape.
const CAL_SYNTHETIC_CITETAG =
    \\## C6 calibration narrative
    \\
    \\Colour inversion is exact for bounds [GLOBAL.INVSYM:PROVEN] and this is a
    \\structural result. The claim [GLOBAL.C2:PROVEN] is deliberately wrong —
    \\C2 is FALSE-AS-SCOPED, not PROVEN. Meanwhile [QA-023:CLAIMED] is the
    \\correct status for the state-sufficiency claim.
    \\
    \\## end
;
const CAL_CITE_BAD_ID = "GLOBAL.C2"; // tagged PROVEN, actually FALSE-AS-SCOPED
const CAL_CITE_GOOD_A = "GLOBAL.INVSYM"; // tagged PROVEN, actually PROVEN
const CAL_CITE_GOOD_B = "QA-023";    // tagged CLAIMED, actually CLAIMED

/// C6 multi-file calibration — a second synthetic narrative with a known-bad
/// tag that a single-file scanner would miss. Used to verify that C6 scans
/// all NARRATIVE_FILES, not just the first.
const CAL_SYNTHETIC_CITETAG_2 =
    \\## C6 calibration narrative — second file
    \\
    \\This second narrative has a deliberately wrong tag [GLOBAL.C4:FALSE] —
    \\the register says FALSE-AS-SCOPED, not FALSE. A single-file scanner that
    \\only reads the first narrative would never see this. [CODE.BATTERY-STUBBED:PROVEN]
    \\is actually PROVEN now, so that one is correct.
    \\
    \\## end
;
const CAL_CITE_BAD_ID2 = "GLOBAL.C4"; // tagged FALSE, actually FALSE-AS-SCOPED
const CAL_CITE_GOOD_C = "CODE.BATTERY-STUBBED"; // tagged PROVEN, actually PROVEN

/// C7 rejection registry — findings that were considered and correctly
/// dispositioned, with the reason. Read at each invocation; a finding in this
/// file does NOT count as unabsorbed (T272, extended T269). Three dispositions:
///   rejected-by-register       — the register refutes the finding; `refuting_row`
///                                names the row/evidence that rejects it (T272).
///   not-a-register-claim       — the finding's ID is not a register claim at all
///                                (e.g. an infra statement about tooling); the
///                                reason is carried in `rationale`, which is
///                                MANDATORY — an entry without it is invalid and
///                                does not silence (T269 part 1).
///   absorbed-under-register-id — the finding used a task ID / alias instead of
///                                the register ID; `refuting_row` names the actual
///                                register row the content was absorbed under
///                                (T269 part 1).
const REJECTIONS_FILE = "findings/rejections.json";

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
    \\| `GLOBAL.CAL-SHOULDBE-FALSE` | — | all | synthetic: deliberately PROVEN in register, finding says FALSE-AS-SCOPED | PROVEN | `AGENTS.md:1` | — | — | 0 | ? | Z-AUDIT |
;

/// C7 multi-row calibration — the T266 defect (T269): C7 read only the FIRST
/// `new_rows` entry per findings file and mis-parsed its status, so rows 2..N
/// silently vanished from the absorption queue. Two new_rows: row 1 matches the
/// register (PROVEN — must stay silent), row 2 is a status mismatch (findings
/// CLAIMED, register PROVEN — must be caught). The pre-fix parser surfaced
/// exactly one row with status ": " and reported 0 mismatches, so this case
/// fails on the old code and passes on the fix.
const CAL_SYNTHETIC_C7_MULTIROW =
    \\{
    \\  "task_id": "T269CAL",
    \\  "date": "2026-08-03",
    \\  "model": "TestModel",
    \\  "claims": [],
    \\  "new_rows": [
    \\    {
    \\      "id": "GLOBAL.CAL-NEWROW-1",
    \\      "legacy": "—",
    \\      "goban": "all",
    \\      "claim": "synthetic new row 1 — must be absorbed (register says PROVEN)",
    \\      "status": "PROVEN",
    \\      "evidence": "AGENTS.md:1",
    \\      "depends_on": "—",
    \\      "narrowed": 0,
    \\      "wrong_answer_pass_rate": "?"
    \\    },
    \\    {
    \\      "id": "GLOBAL.CAL-NEWROW-2",
    \\      "legacy": "—",
    \\      "goban": "all",
    \\      "claim": "synthetic new row 2 — status mismatch (register says PROVEN)",
    \\      "status": "CLAIMED",
    \\      "evidence": "AGENTS.md:1",
    \\      "depends_on": "—",
    \\      "narrowed": 0,
    \\      "wrong_answer_pass_rate": "?"
    \\    }
    \\  ]
    \\}
;
/// The two register rows the multi-row calibration compares against.
const CAL_SYNTHETIC_C7_MULTIROW_EXTRA =
    \\| `GLOBAL.CAL-NEWROW-1` | — | all | synthetic: absorbed row | PROVEN | `AGENTS.md:1` | — | — | 0 | ? | Z-AUDIT |
    \\| `GLOBAL.CAL-NEWROW-2` | — | all | synthetic: deliberately PROVEN in register, findings says CLAIMED | PROVEN | `AGENTS.md:1` | — | — | 0 | ? | Z-AUDIT |
;

/// C7 not-a-register-claim calibration (T269 part 1): a finding whose ID has no
/// register row, dispositioned via a rejection entry with disposition
/// `not-a-register-claim` and a mandatory reason. Must go silent ONLY when the
/// entry carries the reason; an entry missing it must NOT silence (the reason is
/// mandatory — a silent skip is how a real finding gets lost).
const CAL_SYNTHETIC_C7_INFRA =
    \\{
    \\  "task_id": "T269INFRA",
    \\  "date": "2026-08-03",
    \\  "model": "TestModel",
    \\  "claims": [
    \\    {
    \\      "id": "GLOBAL.CAL-NOID",
    \\      "proposed_status": "CLAIMED",
    \\      "rationale": "Synthetic infra statement — no register row exists",
    \\      "evidence_path": "none"
    \\    }
    \\  ],
    \\  "new_rows": []
    \\}
;

/// C8 mutation-adequacy calibration — synthetic kill matrix with two claims:
///   GLOBAL.CAL-KERNEL-UNKILLED — has a "survived" mutant (seeded, must be caught)
///   GLOBAL.CAL-KERNEL-KILLED  — has all "killed" mutants (null, must be silent)
/// A third register row GLOBAL.CAL-KERNEL-CLAIMED is CLAIMED with unkilled
/// mutants — must also be silent (only PROVEN triggers C8).
const CAL_SYNTHETIC_KILL_MATRIX =
    \\{
    \\  "claims": [
    \\    {
    \\      "claim_id": "GLOBAL.CAL-KERNEL-UNKILLED",
    \\      "function": "calUnkilled",
    \\      "source_file": "calibration",
    \\      "mutants": [
    \\        {"id": "CAL-M1", "description": "synthetic survived mutant", "verdict": "survived"}
    \\      ]
    \\    },
    \\    {
    \\      "claim_id": "GLOBAL.CAL-KERNEL-KILLED",
    \\      "function": "calKilled",
    \\      "source_file": "calibration",
    \\      "mutants": [
    \\        {"id": "CAL-M2", "description": "synthetic killed mutant", "verdict": "killed"}
    \\      ]
    \\    }
    \\  ]
    \\}
;
/// Extra register rows for C8 calibration. Three rows:
///   GLOBAL.CAL-KERNEL-UNKILLED   PROVEN   with unkilled mutant → must be caught
///   GLOBAL.CAL-KERNEL-KILLED    PROVEN   with all mutants killed → must be silent
///   GLOBAL.CAL-KERNEL-CLAIMED   CLAIMED  with unkilled mutant → must be silent
const CAL_SYNTHETIC_C8_EXTRA =
    \\| `GLOBAL.CAL-KERNEL-UNKILLED` | — | all | synthetic: PROVEN kernel claim with unkilled mutant — must be caught | PROVEN | `AGENTS.md:1` | — | — | 0 | ? | Z-AUDIT |
    \\| `GLOBAL.CAL-KERNEL-KILLED` | — | all | synthetic: PROVEN kernel claim with all mutants killed — must be silent | PROVEN | `AGENTS.md:1` | — | — | 0 | ? | Z-AUDIT |
    \\| `GLOBAL.CAL-KERNEL-CLAIMED` | — | all | synthetic: CLAIMED kernel claim with unkilled mutant — must be silent (only PROVEN triggers) | CLAIMED | `AGENTS.md:1` | — | — | 0 | ? | Z-AUDIT |
;

/// C9 calibration — the T305 tree-mapping check, exercised on synthetic
/// register rows + a synthetic mapping document.
/// known-bad: `GLOBAL.CAL-TREE-BAD` carries an invalid cell (not a node, not
/// RETIRED); `GLOBAL.CAL-TREE-NODOC` is a valid register row absent from the
/// doc; `GLOBAL.CAL-TREE-EXTRA` is a doc row the register lacks. All three must
/// be caught; the seven base rows must stay silent.
/// known-good: the base register alone against a doc covering exactly its rows
/// must be fully silent.
const CAL_SYNTHETIC_C9_EXTRA =
    \\| `GLOBAL.CAL-TREE-BAD` | — | all | synthetic: bogus tree cell — must be caught | CLAIMED | `AGENTS.md:1` | — | — | 0 | ? | BOGUS-NODE |
    \\| `GLOBAL.CAL-TREE-NODOC` | — | all | synthetic: valid cell but absent from the doc — must be caught | CLAIMED | `AGENTS.md:1` | — | — | 0 | ? | Z-AUDIT |
;
const CAL_SYNTHETIC_C9_DOC =
    \\## 1. The mapping — synthetic
    \\| ID | tree node | note |
    \\|---|---|---|
    \\| `GLOBAL.CALPARENT-DEAD` | Z-R-TIE | synthetic |
    \\| `GLOBAL.CALPARENT-LIVE` | Z-TABLE | synthetic |
    \\| `GLOBAL.CALCHILD-OK` | Z-NONCLAIMS | synthetic |
    \\| `GLOBAL.CALCHILD-ALARM` | Z-NONCLAIMS | synthetic |
    \\| `GLOBAL.CALPARENT-MEAS` | Z-AUDIT | synthetic |
    \\| `GLOBAL.CALCHILD-SHADOW` | Z-AUDIT | synthetic |
    \\| `GLOBAL.CALCHILD-PLAIN` | Z-AUDIT | synthetic |
    \\| `GLOBAL.CAL-TREE-BAD` | BOGUS-NODE | synthetic: invalid cell — mismatch must not double-report |
    \\| `GLOBAL.CAL-TREE-EXTRA` | Z-R-MOVE | synthetic: row the register does not have — must be caught |
    \\## 2. end
;
const CAL_SYNTHETIC_C9_GOOD_DOC =
    \\## 1. The mapping — synthetic good
    \\| ID | tree node | note |
    \\|---|---|---|
    \\| `GLOBAL.CALPARENT-DEAD` | Z-R-TIE | synthetic |
    \\| `GLOBAL.CALPARENT-LIVE` | Z-TABLE | synthetic |
    \\| `GLOBAL.CALCHILD-OK` | Z-NONCLAIMS | synthetic |
    \\| `GLOBAL.CALCHILD-ALARM` | Z-NONCLAIMS | synthetic |
    \\| `GLOBAL.CALPARENT-MEAS` | Z-AUDIT | synthetic |
    \\| `GLOBAL.CALCHILD-SHADOW` | Z-AUDIT | synthetic |
    \\| `GLOBAL.CALCHILD-PLAIN` | Z-AUDIT | synthetic |
    \\## 2. end
;

/// Build a synthetic register = CAL_SYNTHETIC's rows with `extra_rows` grafted
/// in BEFORE the "## 3. end" footer, so the extra rows are inside §2. (Appending
/// after the footer leaves them outside §2 where parseRegister never sees them —
/// a latent calibration weakness that made the old C7 known-bad pass for the
/// wrong reason.)
fn synthRegister(gpa: Allocator, extra_rows: []const u8) ![]u8 {
    const footer = "## 3. end";
    const idx = std.mem.lastIndexOf(u8, CAL_SYNTHETIC, footer) orelse return error.NoFooter;
    return std.fmt.allocPrint(gpa, "{s}{s}\n{s}\n", .{ CAL_SYNTHETIC[0..idx], extra_rows, footer });
}

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
    \\| `GLOBAL.CALPARENT-DEAD` | — | all | synthetic: a parent that is FALSE | FALSE-AS-SCOPED | `AGENTS.md:1` | — | — | 0 | ? | Z-R-TIE |
    \\| `GLOBAL.CALPARENT-LIVE` | — | all | synthetic: a parent still standing | PROVEN | `AGENTS.md:1` | — | — | 0 | ? | Z-TABLE |
    \\| `GLOBAL.CALCHILD-OK` | — | all | synthetic: justified by the refutation of a parent that IS refuted | CLAIMED | `AGENTS.md:1` | `n:GLOBAL.CALPARENT-DEAD` | — | 0 | ? | Z-NONCLAIMS |
    \\| `GLOBAL.CALCHILD-ALARM` | — | all | synthetic: justified by the refutation of a parent that is NOT refuted | CLAIMED | `AGENTS.md:1` | `n:GLOBAL.CALPARENT-LIVE` | — | 0 | ? | Z-NONCLAIMS |
    \\| `GLOBAL.CALPARENT-MEAS` | — | all | synthetic: a measurement, which can never be FALSE | MEASUREMENT | `AGENTS.md:1` | — | — | 0 | ? | Z-AUDIT |
    \\| `GLOBAL.CALCHILD-SHADOW` | — | all | synthetic: `d:` onto a measurement — the shadowed-dependency shape | CLAIMED | `AGENTS.md:1` | `d:GLOBAL.CALPARENT-MEAS` | — | 0 | ? | Z-AUDIT |
    \\| `GLOBAL.CALCHILD-PLAIN` | — | all | synthetic: `d:` onto a real claim — must stay silent in C5 | CLAIMED | `AGENTS.md:1` | `d:GLOBAL.CALPARENT-LIVE` | — | 0 | ? | Z-AUDIT |
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
    /// "true when written, overtaken by events" (T269): the claim was correct
    /// when made, but the world moved on. Not FALSE (the statement was never
    /// wrong) and not live (it no longer describes reality). Superseded rows
    /// are invisible to C1a/C3/B — they can never be FALSE, so no falsification
    /// travels through them, and they owe no committed evidence for a claim
    /// they no longer make. Existing instances: `CODE.WZO2-UNRUN`,
    /// `CODE.WZO2-CHAINSHORT`.
    superseded,
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
            .superseded => "SUPERSEDED",
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
    /// T305: the requirement-tree node (AXIOMS.md §3) this row serves, or
    /// `RETIRED` (proposed retirement — the row serves no tree node; the
    /// reason lives in register-tree-map.md §2 and the human rules). Checked
    /// by C9.
    tree: []const u8,
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
    if (std.mem.startsWith(u8, s, "SUPERSEDED")) return .superseded;
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
        if (c.len != 13) {
            try reg.unparsed.append(gpa, try std.fmt.allocPrint(
                gpa,
                "{d}: expected 11 columns, found {d} — `{s}`",
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

// ── C10 volatile-evidence detection (T421) ────────────────────────────────
//
// C2 DEAD-LINKS flags only paths that are MISSING. A /tmp citation whose file
// still exists is not missing, so it passes — and the defect only becomes
// visible after the evidence is destroyed, which is exactly too late. The
// 2026-08-08 rescue found 344 distinct /tmp paths cited in committed docs; 43
// had already crossed that line. C10 flags the citation CLASS: any evidence
// path outside the repo — /tmp, /private/tmp, an absolute path that does not
// resolve inside the working tree, or untracked/ — whether or not the file
// currently exists. Volatile storage is never evidence.
//
// Scan scope mirrors C4's: prose documents (.md under docs/ + AGENTS.md). A
// data artifact (.json/.log/.stdout run record) whose content happens to name
// a /tmp path is the evidence itself, not a citation, and is out of scope.
// Report-only (T421): it must not move any existing floor; the C10 floor is
// proposed separately.

const VolatileClass = enum { tmp, private_tmp, absolute, untracked };

fn volatileClassOf(idx: *Index, tok: []const u8) !?VolatileClass {
    if (std.mem.startsWith(u8, tok, "/tmp/")) return .tmp;
    if (std.mem.startsWith(u8, tok, "/private/tmp/")) return .private_tmp;
    if (std.mem.startsWith(u8, tok, "untracked/")) return .untracked;
    if (tok.len > 0 and tok[0] == '/') {
        // A device, not a citation — `2>/dev/null` is a shell idiom.
        if (std.mem.eql(u8, tok, "/dev/null")) return null;
        // Absolute-looking but inside the tree (`/optimal-cycle-test-2026-08-08.md`
        // is a root-relative doc link) is not a violation; resolve like C2 does.
        var t = tok;
        while (std.mem.startsWith(u8, t, "/")) t = t[1..];
        if (t.len == 0) return null;
        // A root-anchored word with no further depth (a `/genmove` fragment in a
        // GTP trace, a `-femit-bin=/weizigo-exp` tail) is not a path citation.
        const first_slash = std.mem.indexOfScalar(u8, t, '/') orelse return null;
        // Notation like `/L/H`, `/2x2/3x3/4x4`, `/C2/C3` is not a path either:
        // the first component must be a root directory this kind of host has.
        const first = t[0..first_slash];
        const ROOTS = [_][]const u8{
            "Users", "opt", "Library", "private", "System", "Applications", "Volumes",
            "home", "etc", "usr", "var", "proc", "dev", "sbin", "bin", "boot", "mnt", "media", "root", "tmp",
        };
        var is_root = false;
        for (ROOTS) |r| if (std.mem.eql(u8, first, r)) {
            is_root = true;
            break;
        };
        if (!is_root) return null;
        if ((try idx.resolve(t)) != null) return null;
        return .absolute;
    }
    return null;
}

const VolatileHit = struct {
    token: []const u8,
    file: []const u8,
    line: usize,
    class: VolatileClass,
};

fn volatileScan(gpa: Allocator, io: Io, idx: *Index, hits: *std.ArrayList(VolatileHit)) !void {
    for (idx.paths.items) |p| {
        if (!std.mem.startsWith(u8, p, "docs/") and !std.mem.eql(u8, p, "AGENTS.md")) continue;
        if (!endsWith(p, ".md")) continue;
        const body = Io.Dir.cwd().readFileAlloc(io, p, gpa, .unlimited) catch continue;
        var lineno: usize = 0;
        var lit = std.mem.splitScalar(u8, body, '\n');
        while (lit.next()) |line| {
            lineno += 1;
            var i: usize = 0;
            while (i < line.len) {
                if (!isPathChar(line[i])) {
                    i += 1;
                    continue;
                }
                const start = i;
                while (i < line.len and isPathChar(line[i])) : (i += 1) {}
                const tok = stripLineSpec(stripPunct(line[start..i]));
                if (tok.len < 5) continue;
                const cls = (try volatileClassOf(idx, tok)) orelse continue;
                try hits.append(gpa, .{ .token = tok, .file = p, .line = lineno, .class = cls });
            }
        }
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
    file: []const u8,
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
/// with register_status = "NO SUCH ID"). Each mismatch records the file path.
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
        const tagged = parseStatus(tag.status);
        // T373: the row may have moved to archives/register/ in the triage.
        // A tag whose ID is archived verifies against the archive row's
        // preserved status — silent on match, mismatch otherwise (the same
        // resolution C4 got; without it the 36 correct tags on archived
        // rows would fail the run).
        const reg_status = if (reg.by_id.get(tag.id)) |s| blk: {
            break :blk reg.rows.items[s].status;
        } else blk: {
            const arow_path = try std.fmt.allocPrint(gpa, "archives/register/rows/{s}.md", .{tag.id});
            const arow = Io.Dir.cwd().readFileAlloc(io, arow_path, gpa, .unlimited) catch break :blk null;
            break :blk try archivedRowStatus(gpa, arow);
        };
        if (reg_status) |rs| {
            if (tagged != rs) {
                try out.append(gpa, .{
                    .id = tag.id,
                    .tagged_status = tag.status,
                    .register_status = rs.name(),
                    .line = tag.line,
                    .file = path,
                });
            }
        } else {
            try out.append(gpa, .{
                .id = tag.id,
                .tagged_status = tag.status,
                .register_status = "NO SUCH ID",
                .line = tag.line,
                .file = path,
            });
        }
    }
    return out;
}

/// Parse the status out of an archived row file (archives/register/rows/<ID>.md):
/// the verbatim register line's 6th cell, or null if the file is unreadable or
/// the line cannot be parsed. Used by C6 so a tag on an archived row is verified
/// against the archived status rather than reported as "NO SUCH ID".
fn archivedRowStatus(gpa: Allocator, body: []const u8) !?Status {
    var it = std.mem.splitScalar(u8, body, '\n');
    while (it.next()) |line| {
        if (!std.mem.startsWith(u8, line, "| `")) continue;
        var cells = try splitCells(gpa, line);
        defer cells.deinit(gpa);
        if (cells.items.len < 6) continue;
        const st = parseStatus(cells.items[5]);
        if (st == .unparsed) return null;
        return st;
    }
    return null;
}

/// Read archives/register/rows/<ID>.md and return its preserved status, or null
/// if the row is not archived / unreadable / unparsed. Used by C6 and C7 so a
/// citation or finding on an archived row is verified against the archived
/// status rather than reported as NO SUCH ID.
fn archivedStatusFor(gpa: Allocator, io: Io, id: []const u8) !?Status {
    const arow_path = try std.fmt.allocPrint(gpa, "archives/register/rows/{s}.md", .{id});
    const arow = Io.Dir.cwd().readFileAlloc(io, arow_path, gpa, .unlimited) catch return null;
    return archivedRowStatus(gpa, arow);
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
    util.out("\n== C1  ORPHAN DETECTION — C1a {s} · C1b {s} (fails the run) ==\n", .{ checkName("C1a"), checkName("C1b") });
    util.out("C1a {s}: PROVEN/CLAIMED claims with a transitive `d:` ancestor that is FALSE.\n", .{checkName("C1a")});
    util.out("`n:` edges are NOT traversed — a claim justified by a refutation does not\n", .{});
    util.out("inherit the refuted parent's ancestry. C1b {s} below checks them the other way.\n\n", .{checkName("C1b")});
    var c1_count: usize = 0;
    for (reg.rows.items, 0..) |r, i| {
        if (!r.status.isLive()) continue;
        const chain = try shortestFalseChain(gpa, &reg, i) orelse continue;
        c1_count += 1;
        util.out("  C1a {s}  `{s}` ({s})\n", .{ checkName("C1a"), r.id, r.status_raw });
        for (chain.items, 1..) |step, depth| {
            const sr = reg.rows.items[step];
            util.out("     {s}⟵d `{s}`  [{s}]\n", .{
                spaces(depth),
                sr.id,
                sr.status.name(),
            });
        }
    }
    if (c1_count == 0) util.out("  (none)\n", .{});
    util.out("\n  C1a {s} orphans: {d}\n", .{ checkName("C1a"), c1_count });

    // C1b — the inverse. A claim carrying `n:P` is justified BY P being false.
    // If P is ever rehabilitated the justification evaporates and the child
    // needs re-examining. Nothing else in this repo detects that.
    util.out("\n  C1b {s} — NEGATION ALARM: `n:` edges whose parent is no longer FALSE.\n", .{checkName("C1b")});
    const alarms = try negationAlarms(gpa, &reg);
    for (alarms.items) |a| {
        const child = reg.rows.items[a.child];
        const parent = reg.rows.items[a.parent];
        util.out("  C1b {s}  `{s}` ({s})\n", .{ checkName("C1b"), child.id, child.status_raw });
        util.out("            ⟵n `{s}`  [{s}]  — justified by this parent being FALSE;\n", .{ parent.id, parent.status.name() });
        util.out("               it is not. The justification has evaporated.\n", .{});
    }
    if (alarms.items.len == 0)
        util.out("  (none — every `n:` edge points at a parent that is still FALSE)\n", .{});
    util.out("\n  C1b {s} alarms: {d}\n", .{ checkName("C1b"), alarms.items.len });
    util.out("\n  C1 total (C1a {s} + C1b {s}): {d}\n", .{ checkName("C1a"), checkName("C1b"), c1_count + alarms.items.len });

    // ── C2 dangling evidence ────────────────────────────────────────────────
    util.out("\n== C2 {s}  DANGLING EVIDENCE (fails the run) ==\n", .{checkName("C2")});
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
        util.out("  C2 {s}  {s}\n", .{ checkName("C2"), m.path });
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
        util.out("    C2 {s} (git-ignored)  {s}   cited by", .{ checkName("C2"), m.path });
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
    util.out("\n  C2 {s} total: {d}  ({d} unique missing paths — {d} cited by the evidence column\n", .{ checkName("C2"), c2_total, c2_fail, c2a });
    util.out("            directly, {d} named inside cited documents — plus {d} git-ignored\n", .{ c2b, notgit.items.len });
    util.out("            evidence documents; {d} bulk .wzo and {d} already-inventoried\n", .{ c2_bulk, c2_inventoried });
    util.out("            losses, not counted)\n", .{});

    // ── C3 proven without committed evidence ────────────────────────────────
    util.out("\n== C3 {s}  PROVEN WITHOUT COMMITTED EVIDENCE (debt list — does NOT fail, yet) ==\n", .{checkName("C3")});
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
    util.out("\n  C3 {s} total PROVEN-without-committed-evidence: {d} of {d} PROVEN rows\n", .{
        checkName("C3"),
        tierB.items.len + tierC.items.len,
        tierA.items.len + tierB.items.len + tierC.items.len,
    });

    // ── C4 dangling claim IDs ───────────────────────────────────────────────
    util.out("\n== C4 {s}  DANGLING CLAIM IDs (report only — does NOT fail, yet) ==\n", .{checkName("C4")});
    var dangling = std.StringHashMap(std.ArrayList([]const u8)).init(gpa);
    var qa = std.StringHashMap(std.ArrayList([]const u8)).init(gpa);
    var qa_modelled = std.StringHashMap(void).init(gpa);
    // T373: rows moved out of the live register by the triage adoption are
    // archived under archives/register/INDEX.md. An ID cited in docs/ that is
    // NOT in the register but IS in the archive index reads as archived, not
    // dangling — without this the 132 moved IDs would become 132 new ghosts.
    var archived = std.StringHashMap(void).init(gpa);
    if (Io.Dir.cwd().readFileAlloc(io, ARCHIVE_INDEX_PATH, gpa, .unlimited)) |abody| {
        var alit = std.mem.splitScalar(u8, abody, '\n');
        while (alit.next()) |line| {
            var spans: std.ArrayList([]const u8) = .empty;
            defer spans.deinit(gpa);
            try backtickSpans(gpa, line, &spans);
            for (spans.items) |sp| {
                const cid = claimIdOf(sp) orelse continue;
                if (!reg.by_id.contains(cid) and !archived.contains(cid)) try archived.put(cid, {});
            }
        }
    } else |_| {}
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
                // T373: an archived row still models its QA ID — a falsification
                // reaches it via the archive index, so it is not "unmodelled".
                if (isQaId(cid) and archived.contains(cid)) {
                    const g2 = try qa_modelled.getOrPut(cid);
                    if (!g2.found_existing) g2.value_ptr.* = {};
                }
                if (reg.by_id.get(cid)) |k| {
                    if (!inside_sec2) reg.rows.items[k].refs_outside += 1;
                    continue;
                }
                if (archived.contains(cid)) continue; // archived row — reads as archived, not dangling
                const gop = try dangling.getOrPut(cid);
                if (!gop.found_existing) gop.value_ptr.* = .empty;
                const where = try std.fmt.allocPrint(gpa, "{s}:{d}", .{ p, lineno });
                if (gop.value_ptr.items.len < 4) try gop.value_ptr.append(gpa, where);
            }
        }
    }
    util.out("  C4 {s} — claim IDs cited in docs/ with NO register row ({d}):\n", .{ checkName("C4"), dangling.count() });
    var dit = dangling.iterator();
    while (dit.next()) |e| {
        util.out("    C4 {s}  `{s}`  cited at", .{ checkName("C4"), e.key_ptr.* });
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
        util.out("    C4 {s}  UNMODELLED `{s}`  cited at", .{ checkName("C4"), e.key_ptr.* });
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
    util.out("\n  C4 {s} total: {d} dangling IDs, {d} unmodelled QA-nnn IDs, {d} unreferenced rows\n", .{ checkName("C4"), dangling.count(), qa.count() - qa_modelled.count(), unref });

    // ── C5 shadowed dependencies ────────────────────────────────────────────
    util.out("\n== C5 {s}  SHADOWED DEPENDENCY (report only — does NOT fail, yet) ==\n", .{checkName("C5")});
    util.out("`d:` edges terminating on a MEASUREMENT or a definition. A measurement says\n", .{});
    util.out("something happened; a definition cannot be wrong. Neither can ever be FALSE,\n", .{});
    util.out("so the edge is a dead end: if the claim really needs the SOUNDNESS behind the\n", .{});
    util.out("measurement, that parent is missing and a falsification cannot reach this row.\n\n", .{});
    const shadows = try shadowedEdges(gpa, &reg);
    for (shadows.items) |sh| {
        const child = reg.rows.items[sh.child];
        const parent = reg.rows.items[sh.parent];
        util.out("  C5 {s}  `{s}` [{s}]\n", .{ checkName("C5"), child.id, child.status.name() });
        util.out("            d: `{s}` [{s}] — a parent that can never be FALSE;\n", .{ parent.id, parent.status.name() });
        util.out("            completion is not soundness. Is the real parent a soundness claim?\n", .{});
    }
    if (shadows.items.len == 0) util.out("  (none)\n", .{});
    const c5 = shadows.items.len;
    util.out("\n  C5 {s} total: {d}\n", .{ checkName("C5"), c5 });

    // ── C6 cite-tag verification ───────────────────────────────────────────
    util.out("\n== C6 {s}  CITE-TAG VERIFICATION (fails the run) ==\n", .{checkName("C6")});
    util.out("Scans {d} narrative files for `[ID:STATUS]` tags and verifies\n", .{NARRATIVE_FILES.len});
    util.out("each against the register. A narrative whose cite-tags do not\n", .{});
    util.out("match the register is hallucination-prone.\n", .{});
    for (NARRATIVE_FILES) |nf| util.out("  scanning: {s}\n", .{nf});
    util.out("\n", .{});
    var cite_mismatches: std.ArrayList(CiteMismatch) = .empty;
    for (NARRATIVE_FILES) |nf| {
        var fms = try citeTagCheck(gpa, io, &reg, nf);
        defer fms.deinit(gpa);
        try cite_mismatches.appendSlice(gpa, fms.items);
    }
    if (cite_mismatches.items.len == 0) {
        util.out("  (all cite-tags match the register)\n", .{});
    } else {
        for (cite_mismatches.items) |m| {
            util.out("  C6 {s}  MISMATCH  {s}:{d}: [`{s}:{s}`] — register has [{s}]\n", .{
                checkName("C6"),
                m.file, m.line, m.id, m.tagged_status, m.register_status,
            });
        }
    }
    const c6 = cite_mismatches.items.len;
    util.out("\n  C6 {s} cite-tag mismatches: {d}\n", .{ checkName("C6"), c6 });

    // ── C7 unabsorbed findings ────────────────────────────────────────────
    util.out("\n== C7 {s}  UNABSORBED FINDINGS (fails the run) ==\n", .{checkName("C7")});
    util.out("Scans {s}/*.json for claim status changes not reflected in the register.\n", .{FINDINGS_DIR});
    util.out("A finding is unabsorbed when its proposed status differs from CLAIMS.md\n", .{});
    util.out("AND it is not dispositioned in the rejection registry ({s}).\n\n", .{REJECTIONS_FILE});
    // Load the rejection registry once, so C7 can filter.
    const rejection_idx = try loadRejections(gpa, io, REJECTIONS_FILE);
    const c7_results = try checkFindings(gpa, io, &reg, FINDINGS_DIR, &rejection_idx);
    const c7: usize = c7_results.unabsorbed;
    util.out("  files scanned: {d}\n", .{c7_results.files});
    if (c7_results.nonconforming > 0) {
        util.out("  non-conforming (REPORTED, not silently skipped — GRAND-AUDIT §2): {d}\n", .{c7_results.nonconforming});
        for (c7_results.conform_issues.items) |ci| {
            util.out("  C7 {s}  NON-CONFORMING  {s} — {s}\n", .{ checkName("C7"), ci.file, ci.reason });
        }
    } else {
        util.out("  non-conforming: 0 (all files conform to the findings schema)\n", .{});
    }
    if (rejection_idx.invalid.items.len > 0) {
        util.out("  INVALID rejection entries (NOT honoured — a disposition must carry its reason):\n", .{});
        for (rejection_idx.invalid.items) |why| util.out("    ! {s}\n", .{why});
    }
    util.out("  claims touched: {d}\n", .{c7_results.claims_total});
    util.out("  new-rows touched: {d}\n", .{c7_results.new_rows_total});
    if (c7_results.rejected > 0) {
        util.out("  dispositioned (reason-carrying): {d}\n", .{c7_results.rejected});
        for (c7_results.rejected_items.items) |item| {
            switch (item.disposition) {
                .rejected_by_register => {
                    util.out("  REJECTED  `{s}` — findings proposed `{s}`, register says `{s}`\n", .{
                        item.id, item.proposed, item.actual,
                    });
                    util.out("            refuted by register row: {s}\n", .{item.refuting_row});
                },
                .not_a_register_claim => {
                    util.out("  OUT OF REGISTER SCOPE  `{s}` — not a register claim; reason: {s}\n", .{
                        item.id, item.rationale,
                    });
                },
                .absorbed_under_register_id => {
                    util.out("  ABSORBED UNDER REGISTER ID  `{s}` → `{s}`; reason: {s}\n", .{
                        item.id, item.refuting_row, item.rationale,
                    });
                },
                .unparsed => {},
            }
            if (item.file) |f| util.out("            in {s}\n", .{f});
        }
    } else {
        util.out("  dispositioned: 0\n", .{});
    }
    if (c7_results.unabsorbed == 0) {
        util.out("  unabsorbed: 0 (all findings reflected in the register)\n", .{});
    } else {
        util.out("  unabsorbed: {d}\n", .{c7_results.unabsorbed});
        for (c7_results.items.items) |item| {
            util.out("  C7 {s}  `{s}` — findings says `{s}`, register says `{s}`\n", .{
                checkName("C7"),
                item.id, item.proposed, item.actual,
            });
            if (item.file) |f| util.out("              in {s}\n", .{f});
        }
    }
    util.out("\n  C7 {s} unabsorbed findings: {d}\n", .{ checkName("C7"), c7 });

    // ── C8 mutation-adequacy promotion gate ──────────────────────────────
    util.out("\n== C8 {s}  MUTATION-ADEQUACY PROMOTION GATE (report only — does NOT fail, yet) ==\n", .{checkName("C8")});
    util.out("DIRECTION Amendment 2 edge 5: a claim about a kernel function may not be\n", .{});
    util.out("promoted past CLAIMED until the battery kills the mutants covering it.\n", .{});
    util.out("Source: docs/epic-01-markovian/sprints/verify-battery/pass1/kill-matrix.json\n\n", .{});
    var c8_violations: usize = 0;
    var c8_kernel_claims: usize = 0;
    var c8_unkilled_claims: usize = 0;
    const KILL_MATRIX_PATH = "docs/epic-01-markovian/sprints/verify-battery/pass1/kill-matrix.json";
    const km_json = Io.Dir.cwd().readFileAlloc(io, KILL_MATRIX_PATH, gpa, .unlimited) catch |e| blk: {
        util.note("C8: cannot read {s}: {s} — check is blind\n", .{ KILL_MATRIX_PATH, @errorName(e) });
        break :blk @as([]const u8, &[_]u8{});
    };
    var km = try parseKillMatrix(gpa, km_json);
    defer km.deinit(gpa);
    c8_kernel_claims = km.claims.items.len;
    for (km.claims.items) |kc| {
        if (kc.all_killed) continue;
        c8_unkilled_claims += 1;
        const slot = reg.by_id.get(kc.claim_id) orelse continue;
        const rr = reg.rows.items[slot];
        if (rr.status != .proven) continue;
        c8_violations += 1;
        util.out("  C8 {s}  `{s}` — PROVEN but mutants unkilled:", .{ checkName("C8"), kc.claim_id });
        var first = true;
        for (kc.mutants.items) |m| {
            if (KillMatrix.isKilled(m.verdict)) continue;
            if (!first) util.out(",", .{});
            util.out(" {s} ({s})", .{ m.id, m.verdict });
            first = false;
        }
        util.out("\n             function: {s} in {s}\n", .{ kc.function, kc.source_file });
    }
    if (c8_violations == 0) util.out("  (none)\n", .{});
    util.out("\n  kernel-function claims in kill matrix: {d}\n", .{c8_kernel_claims});
    util.out("  with at least one unkilled mutant:    {d}\n", .{c8_unkilled_claims});
    util.out("  at PROVEN (violation):                {d}\n", .{c8_violations});
    if (c8_violations > 0) {
        util.out("\n  To become gating: all kernel-function claims at PROVEN must have every\n", .{});
        util.out("  covering mutant killed. With the current {d}/10 kill rate this is not\n", .{3});
        util.out("  achievable — the gate can ship only after Phase 2 key-agreement (G1/G3)\n", .{});
        util.out("  and closure checks (G2) close the 7 surviving gaps.\n", .{});
    } else {
        util.out("\n  The count is 0 — no PROVEN kernel-function claims with unkilled mutants.\n", .{});
        util.out("  T273's two kernel claims (GLOBAL.AXIOM-BASICKO, GLOBAL.AXIOM-STATE) are\n", .{});
        util.out("  correctly held at CLAIMED, not PROVEN. When they are ready for promotion\n", .{});
        util.out("  the G1/G3 gap must close first (key-agreement, Phase 2).\n", .{});
    }
    // The per-section total is left in its exact `C8 mutation-adequacy violations: N`
    // form (no name inserted here): tools/regression-claimlint-promotion.sh greps
    // this line by exact prefix and extracts the count with `sed 's/.*: //'`. The
    // name UNKILLED is carried by the section header above and the SUMMARY row.
    util.out("\n  C8 mutation-adequacy violations: {d}\n", .{c8_violations});

    // ── C9 tree mapping (T305) ────────────────────────────────────────────
    util.out("\n== C9 {s}  TREE MAPPING (fails the run) ==\n", .{checkName("C9")});
    util.out("Every register row carries the requirement-tree node it serves (AXIOMS.md §3)\n", .{});
    util.out("in the `tree` column (T305 — the dropped Phase 0 deliverable, phase0-execution-\n", .{});
    util.out("audit F2). C9a validates the vocabulary (a node, or RETIRED = proposed retirement);\n", .{});
    util.out("C9b cross-checks docs/epic-01-markovian/register-tree-map.md against the register:\n", .{});
    util.out("same row set, same node per row — a mapping that silently covers a subset is the\n", .{});
    util.out("denominator defect this check exists to name.\n\n", .{});
    var c9: C9Result = .{};
    var c9_doc_missing = false;
    const MAP_DOC_PATH = "docs/epic-01-markovian/register-tree-map.md";
    const map_doc = Io.Dir.cwd().readFileAlloc(io, MAP_DOC_PATH, gpa, .unlimited) catch |e| blk: {
        util.note("C9: cannot read {s}: {s} — mapping document missing, treating as violation\n", .{ MAP_DOC_PATH, @errorName(e) });
        c9_doc_missing = true;
        break :blk @as([]const u8, &[_]u8{});
    };
    try checkTreeMapping(gpa, &reg, map_doc, &c9);
    if (c9_doc_missing) {
        c9.doc_missing = true;
        try c9.failures.append(gpa, "  C9 UNMAPPED  DOC MISSING — docs/epic-01-markovian/register-tree-map.md cannot be read (C9b is blind)");
    }
    for (c9.failures.items) |f| util.out("{s}\n", .{f});
    if (c9.failures.items.len == 0) util.out("  (none)\n", .{});
    util.out("\n  register rows: {d} · mapping doc rows: {d}\n", .{ c9.reg_rows, c9.doc_rows });
    util.out("  mapped to a node: {d} · proposed-retired (RETIRED): {d} · invalid cells: {d}\n", .{ c9.reg_rows - c9.retired_rows, c9.retired_rows, c9.invalid_cells });
    util.out("  doc missing rows: {d} · doc extra rows: {d} · node mismatches: {d}\n", .{ c9.doc_missing_ids, c9.doc_extra_ids, c9.node_mismatches });
    const c9_fail = c9.invalid_cells + c9.doc_missing_ids + c9.doc_extra_ids + c9.node_mismatches + (if (c9_doc_missing) @as(usize, 1) else 0);
    util.out("\n  C9 {s} tree-mapping violations: {d}\n", .{ checkName("C9"), c9_fail });

    // ── C10 volatile evidence paths (T421) ──────────────────────────────
    util.out("\n== C10 {s}  EVIDENCE OUTSIDE THE REPO (report only — does NOT fail, yet) ==\n", .{checkName("C10")});
    util.out("A /tmp or /private/tmp path, an absolute path outside the working tree,\n", .{});
    util.out("or an untracked/ path is volatile storage — never evidence — whether\n", .{});
    util.out("or not the file exists today. C2 only catches paths that are MISSING;\n", .{});
    util.out("the 2026-08-08 rescue found 344 distinct /tmp paths cited in committed\n", .{});
    util.out("docs, of which 43 were already destroyed. The floor for this counter is\n", .{});
    util.out("proposed separately (T421); it does not gate the run yet.\n\n", .{});
    var c10_hits: std.ArrayList(VolatileHit) = .empty;
    defer c10_hits.deinit(gpa);
    try volatileScan(gpa, io, &idx, &c10_hits);
    var c10_tmp: usize = 0;
    var c10_priv: usize = 0;
    var c10_abs: usize = 0;
    var c10_untracked: usize = 0;
    for (c10_hits.items) |h| switch (h.class) {
        .tmp => c10_tmp += 1,
        .private_tmp => c10_priv += 1,
        .absolute => c10_abs += 1,
        .untracked => c10_untracked += 1,
    };
    // Group by token for the report; show up to MAX_LOC per token. The defect
    // classes (/tmp, /private/tmp, absolute-outside-tree) print IN FULL — a
    // seeded control must always be visible — and only untracked/ is capped
    // (it is a large structural census, not the defect). Sorted deterministically
    // so the output is reproducible.
    const C10_MAX_LOC = 3;
    const C10_MAX_UNTRACKED = 20;
    var c10_by_token = std.StringHashMap(std.ArrayList([]const u8)).init(gpa);
    defer {
        var it = c10_by_token.iterator();
        while (it.next()) |e| e.value_ptr.deinit(gpa);
        c10_by_token.deinit();
    }
    for (c10_hits.items) |h| {
        const gop = try c10_by_token.getOrPut(h.token);
        if (!gop.found_existing) gop.value_ptr.* = .empty;
        if (gop.value_ptr.items.len < C10_MAX_LOC)
            try gop.value_ptr.append(gpa, try std.fmt.allocPrint(gpa, "{s}:{d}", .{ h.file, h.line }));
    }
    var c10_tokens: std.ArrayList([]const u8) = .empty;
    defer c10_tokens.deinit(gpa);
    {
        var it = c10_by_token.iterator();
        while (it.next()) |e| try c10_tokens.append(gpa, e.key_ptr.*);
    }
    const C10TokenLess = struct {
        fn less(_: void, a: []const u8, b: []const u8) bool {
            // defect classes first, untracked/ last; lexicographic within each
            const au = std.mem.startsWith(u8, a, "untracked/");
            const bu = std.mem.startsWith(u8, b, "untracked/");
            if (au != bu) return !au;
            return std.mem.lessThan(u8, a, b);
        }
    };
    std.mem.sort([]const u8, c10_tokens.items, {}, C10TokenLess.less);
    var c10_shown: usize = 0;
    var c10_untracked_shown: usize = 0;
    for (c10_tokens.items) |tok| {
        const is_untracked = std.mem.startsWith(u8, tok, "untracked/");
        if (is_untracked) {
            if (c10_untracked_shown >= C10_MAX_UNTRACKED) continue;
            c10_untracked_shown += 1;
        } else {
            c10_shown += 1;
        }
        util.out("  C10 {s}  {s}\n", .{ checkName("C10"), tok });
        for (c10_by_token.get(tok).?.items) |loc| util.out("             at {s}\n", .{loc});
    }
    if (c10_untracked_shown < c10_by_token.count() - c10_shown)
        util.out("  …(+{d} more distinct untracked/ paths)\n", .{c10_by_token.count() - c10_shown - c10_untracked_shown});
    if (c10_hits.items.len == 0) util.out("  (none)\n", .{});
    util.out("\n  C10 {s} total: {d}  ({d} /tmp · {d} /private/tmp · {d} absolute-outside-tree · {d} untracked/)\n", .{
        checkName("C10"), c10_hits.items.len, c10_tmp, c10_priv, c10_abs, c10_untracked,
    });

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

    // known-bad/known-good pair for C1a — synthetic (the real register now has
    // zero orphans after the T373 triage, so a real-data case would be a
    // calibration case that disappears when the register improves).
    var synth_c1a_ok = false;
    {
        const synth_ext_c1a = try synthRegister(gpa, CAL_SYNTHETIC_C1A_EXTRA);
        var sreg_c1a = try parseRegister(gpa, synth_ext_c1a);
        var saw_orphan = false;
        var saw_clean = true;
        for (sreg_c1a.rows.items, 0..) |_, i| {
            const chain = try shortestFalseChain(gpa, &sreg_c1a, i) orelse continue;
            const cid = sreg_c1a.rows.items[i].id;
            if (std.mem.eql(u8, cid, "GLOBAL.CALCHILD-ORPHAN")) saw_orphan = true;
            if (std.mem.eql(u8, cid, "GLOBAL.CALCHILD-ORPHAN-CLEAN")) saw_clean = false;
            _ = chain;
        }
        synth_c1a_ok = sreg_c1a.unparsed.items.len == 0 and saw_orphan and saw_clean;
    }
    util.out("  known-bad 1 (C1a {s}, synthetic): a CLAIMED row with a `d:` chain to a\n", .{checkName("C1a")});
    util.out("                FALSE-AS-SCOPED ancestor must be reported, while a CLAIMED\n", .{});
    util.out("                row whose parents are PROVEN must stay silent … {s}\n", .{if (synth_c1a_ok) "CAUGHT (1 orphan, 1 silent)" else "BROKEN"});
    if (!synth_c1a_ok) cal_ok = false;

    var cal_dangling_hit = false;
    for (missing.items) |m| {
        if (std.mem.eql(u8, m.path, CAL_DANGLING)) cal_dangling_hit = true;
    }
    util.out("  known-bad 2 (C2 {s}): `{s}` must be reported … {s}\n", .{
        checkName("C2"), CAL_DANGLING, if (cal_dangling_hit) "CAUGHT" else "MISSED",
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
    util.out("  known-good (C1a {s} + C2 {s}): PROVEN `{s}` with a real evidence path must be silent … {s}\n", .{
        checkName("C1a"), checkName("C2"), CAL_CLEAN, if (clean_ok) "SILENT (correct)" else "FLAGGED (checker suspect)",
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
    util.out("  known-good (C1b {s}, `n:`): `{s}` — `n:` to a FALSE parent must be silent … {s}\n", .{
        checkName("C1b"), CAL_NEG_OK, if (neg_ok_silent) "SILENT (correct)" else "FLAGGED or has no `n:` edge (checker suspect)",
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
    util.out("  known-bad 3 (C1b {s}, synthetic): `n:` to a PROVEN parent must ALARM, `n:` to a\n", .{checkName("C1b")});
    util.out("                FALSE parent must not … {s}\n", .{if (synth_ok) "CAUGHT (1 alarm, 1 silent)" else "BROKEN"});
    if (!synth_ok) cal_ok = false;

    util.out("  known-bad 4 (C5 {s}, synthetic): `d:` onto a MEASUREMENT must be reported, `d:`\n", .{checkName("C5")});
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
    util.out("  known-good (C5 {s}): `{s}` — every `d:` parent is a real claim, must be silent … {s}\n", .{
        checkName("C5"), CAL_SHADOW_CLEAN, if (shadow_clean) "SILENT (correct)" else "FLAGGED (checker suspect)",
    });
    if (!shadow_clean) cal_ok = false;

    // C6 calibration — process both synthetic narratives through citeTagCheck.
    // The first has one wrong-status tag + two correct tags.
    // The second has one wrong-status tag + one correct tag.
    // Both must be caught; a single-file-only scanner would miss the second.
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
        const first_ok = saw_bad and saw_good_a and saw_good_b and !extra and syn_tags.items.len == 3;

        // Second synthetic narrative — calibrates multi-file scanning.
        const syn_tags2 = try citeTags(gpa, CAL_SYNTHETIC_CITETAG_2);
        var saw_bad2 = false;
        var saw_good_c = false;
        var extra2 = false;
        for (syn_tags2.items) |tag| {
            const slot = reg.by_id.get(tag.id) orelse {
                extra2 = true;
                continue;
            };
            const expected = reg.rows.items[slot].status;
            const tagged = parseStatus(tag.status);
            if (tagged != expected) {
                if (std.mem.eql(u8, tag.id, CAL_CITE_BAD_ID2)) saw_bad2 = true;
            } else {
                if (std.mem.eql(u8, tag.id, CAL_CITE_GOOD_C)) saw_good_c = true;
            }
        }
        const second_ok = saw_bad2 and saw_good_c and !extra2 and syn_tags2.items.len == 2;

        synth_c6_ok = first_ok and second_ok;
    }
    util.out("  known-bad 5 (C6 {s}, synthetic): `[{s}:PROVEN]` (register says FALSE-AS-SCOPED) must\n", .{ checkName("C6"), CAL_CITE_BAD_ID });
    util.out("                be caught, while correct-status tags pass silently … {s}\n", .{if (synth_c6_ok) "CAUGHT (2 mismatches across 2 files, 3 silent)" else "BROKEN"});
    util.out("  known-bad 5b (C6 {s}, synthetic file 2): `[{s}:FALSE]` (register says\n", .{ checkName("C6"), CAL_CITE_BAD_ID2 });
    util.out("                FALSE-AS-SCOPED) must also be caught — guards against\n", .{});
    util.out("                single-file-only scanning … {s}\n", .{if (synth_c6_ok) "CAUGHT" else "BROKEN"});
    if (!synth_c6_ok) cal_ok = false;

    // C7 calibration — synthetic findings JSON parsed in-memory against the
    // synthetic register extended with one deliberately-mismatched row.
    // Also calibrates the rejection mechanism with a known-good (genuinely
    // refuted finding goes silent) and known-bad (finding with no refuting
    // row must still be reported).
    var synth_c7_ok = false;
    {
        const synth_ext = try synthRegister(gpa, CAL_SYNTHETIC_C7_EXTRA);
        var sreg = try parseRegister(gpa, synth_ext);
        var empty_rej: RejectionIndex = .{ .entries = std.StringHashMap(RejectionEntry).init(gpa), .invalid = .empty };
        defer empty_rej.entries.deinit();
        // Known-bad 6a: parse without rejections — CAL-SHOULDBE-FALSE must
        // be unabsorbed (status mismatch), CALPARENT-DEAD must be silent (matched).
        const c7cal = try parseFindingsFile(gpa, io, CAL_SYNTHETIC_C7_JSON, "calibration/T999-cal.json", &sreg, &empty_rej);
        var saw_mismatch = false;
        var saw_silent = false;
        for (c7cal.items.items) |item| {
            if (std.mem.eql(u8, item.id, "GLOBAL.CAL-SHOULDBE-FALSE")) saw_mismatch = true;
            if (std.mem.eql(u8, item.id, "GLOBAL.CALPARENT-DEAD")) saw_silent = true;
        }
        const base_ok = c7cal.unabsorbed == 1 and saw_mismatch and !saw_silent and
            c7cal.files == 1 and c7cal.conforming == 1 and c7cal.nonconforming == 0 and
            c7cal.claims_total == 2 and c7cal.rejected == 0;
        if (!base_ok) synth_c7_ok = false;

        // Known-good C7: add a rejection entry for CAL-SHOULDBE-FALSE with a
        // refuting row. Now it must go silent (absorbed-with-rejection).
        var rej_with: RejectionIndex = .{ .entries = std.StringHashMap(RejectionEntry).init(gpa), .invalid = .empty };
        defer rej_with.entries.deinit();
        try rej_with.entries.put("GLOBAL.CAL-SHOULDBE-FALSE\x00T999-cal.json", .{
            .disposition = .rejected_by_register,
            .refuting_row = "GLOBAL.CALREFUTE",
            .rationale = "synthetic refutation",
            .valid = true,
            .invalid_reason = "",
        });
        const c7cal_rej = try parseFindingsFile(gpa, io, CAL_SYNTHETIC_C7_JSON, "calibration/T999-cal.json", &sreg, &rej_with);
        var rej_saw_rejected = false;
        var rej_saw_unabsorbed = false;
        for (c7cal_rej.rejected_items.items) |item| {
            if (std.mem.eql(u8, item.id, "GLOBAL.CAL-SHOULDBE-FALSE")) rej_saw_rejected = true;
        }
        for (c7cal_rej.items.items) |_| rej_saw_unabsorbed = true;
        const rej_ok = c7cal_rej.rejected == 1 and rej_saw_rejected and
            c7cal_rej.unabsorbed == 0 and !rej_saw_unabsorbed;

        synth_c7_ok = base_ok and rej_ok;
    }
    util.out("  known-bad 6 (C7 {s}, synthetic): findings JSON with 2 claims — 1 absorbed\n", .{checkName("C7")});
    util.out("                (GLOBAL.CALPARENT-DEAD matches), 1 unabsorbed status\n", .{});
    util.out("                mismatch (GLOBAL.CAL-SHOULDBE-FALSE: findings says\n", .{});
    util.out("                FALSE-AS-SCOPED, register says PROVEN) … {s}\n", .{if (synth_c7_ok) "CAUGHT (1 unabsorbed, 1 silent)" else "BROKEN"});
    util.out("  known-good 7 (C7 {s}, synthetic): same finding with a rejection entry\n", .{checkName("C7")});
    util.out("                naming a refuting row — must go silent … {s}\n", .{if (synth_c7_ok) "SILENT (absorbed-with-rejection)" else "BROKEN"});
    if (!synth_c7_ok) cal_ok = false;

    // C7 multi-row calibration (T269 part 3) — the T266 defect: the old parser
    // read only the FIRST new_rows entry per file and mis-parsed its status (it
    // read ": " for every value), so rows 2..N never reached the absorption
    // queue and "C7 clean" was a floor, not a census. Two new_rows: row 1
    // matches the register (PROVEN — must stay silent), row 2 mismatches
    // (CLAIMED vs PROVEN — must be caught). Both must be COUNTED: the old
    // parser counted 1 and reported 0 mismatches, so this case fails there.
    var synth_c7_multirow_ok = false;
    {
        const synth_ext2 = try synthRegister(gpa, CAL_SYNTHETIC_C7_MULTIROW_EXTRA);
        var sreg2 = try parseRegister(gpa, synth_ext2);
        var empty_rej2: RejectionIndex = .{ .entries = std.StringHashMap(RejectionEntry).init(gpa), .invalid = .empty };
        defer empty_rej2.entries.deinit();
        const c7cal2 = try parseFindingsFile(gpa, io, CAL_SYNTHETIC_C7_MULTIROW, "calibration/T269cal-multirow.json", &sreg2, &empty_rej2);
        var saw_row1_unabsorbed = false;
        var saw_row2_mismatch = false;
        for (c7cal2.items.items) |item| {
            if (std.mem.eql(u8, item.id, "GLOBAL.CAL-NEWROW-1")) saw_row1_unabsorbed = true;
            if (std.mem.eql(u8, item.id, "GLOBAL.CAL-NEWROW-2")) saw_row2_mismatch = true;
        }
        synth_c7_multirow_ok = c7cal2.new_rows_total == 2 and c7cal2.claims_total == 0 and
            c7cal2.unabsorbed == 1 and saw_row2_mismatch and !saw_row1_unabsorbed and
            c7cal2.rejected == 0 and c7cal2.files == 1;
    }
    util.out("  known-bad 8 (C7 {s}, synthetic): multi-row findings file — the T266 defect.\n", .{checkName("C7")});
    util.out("                Row 1 (PROVEN, matches register) must stay silent, row 2\n", .{});
    util.out("                (CLAIMED vs PROVEN) must be caught, and BOTH counted\n", .{});
    util.out("                (new-rows touched = 2 — the old parser saw 1) … {s}\n", .{if (synth_c7_multirow_ok) "CAUGHT (2 rows counted, 1 mismatch, 1 silent)" else "BROKEN"});
    if (!synth_c7_multirow_ok) cal_ok = false;

    // C7 non-conforming-file calibration (T269 part 4, GRAND-AUDIT §2): a file
    // that is not a findings file (missing required keys, not an object) must
    // be REPORTED, not silently skipped — the exact sin C0's banner denounces.
    var synth_c7_nonconf_ok = false;
    {
        var empty_rej3: RejectionIndex = .{ .entries = std.StringHashMap(RejectionEntry).init(gpa), .invalid = .empty };
        defer empty_rej3.entries.deinit();
        const bad = try parseFindingsFile(gpa, io, "{\"foo\": 1}", "calibration/T269cal-bad.json", &reg, &empty_rej3);
        const good = try parseFindingsFile(gpa, io, CAL_SYNTHETIC_C7_JSON, "calibration/T269cal-good.json", &reg, &empty_rej3);
        synth_c7_nonconf_ok = bad.nonconforming == 1 and bad.conform_issues.items.len == 1 and
            bad.conforming == 0 and bad.claims_total == 0 and bad.unabsorbed == 0 and
            good.nonconforming == 0 and good.conforming == 1;
    }
    util.out("  known-bad 9 (C7 {s}, synthetic): a non-findings JSON must be REPORTED, not\n", .{checkName("C7")});
    util.out("                silently skipped (GRAND-AUDIT §2) … {s}\n", .{if (synth_c7_nonconf_ok) "CAUGHT (reported non-conforming)" else "BROKEN"});
    if (!synth_c7_nonconf_ok) cal_ok = false;

    // C7 disposition calibration (T269 part 1): a rejection entry with
    // disposition not-a-register-claim + its mandatory reason silences a
    // finding whose ID has no register row; the same entry WITHOUT the reason
    // is invalid and must NOT silence — the reason is mandatory, a silent skip
    // is how a real finding gets lost.
    var synth_c7_disposition_ok = false;
    {
        var rej_infra: RejectionIndex = .{ .entries = std.StringHashMap(RejectionEntry).init(gpa), .invalid = .empty };
        defer rej_infra.entries.deinit();
        try rej_infra.entries.put("GLOBAL.CAL-NOID\x00T269cal-infra.json", .{
            .disposition = .not_a_register_claim,
            .refuting_row = "—",
            .rationale = "synthetic infra statement about tooling, not an epistemic claim about Go",
            .valid = true,
            .invalid_reason = "",
        });
        // An entry that violates the reason-mandatory contract must not silence.
        var rej_bad: RejectionIndex = .{ .entries = std.StringHashMap(RejectionEntry).init(gpa), .invalid = .empty };
        defer rej_bad.entries.deinit();
        try rej_bad.entries.put("GLOBAL.CAL-NOID\x00T269cal-infra.json", .{
            .disposition = .not_a_register_claim,
            .refuting_row = "—",
            .rationale = "",
            .valid = false,
            .invalid_reason = "not-a-register-claim entry must carry the reason in rationale",
        });
        const ok = try parseFindingsFile(gpa, io, CAL_SYNTHETIC_C7_INFRA, "calibration/T269cal-infra.json", &reg, &rej_infra);
        const bad = try parseFindingsFile(gpa, io, CAL_SYNTHETIC_C7_INFRA, "calibration/T269cal-infra.json", &reg, &rej_bad);
        var disp_saw_rejected = false;
        var disp_saw_reason = false;
        for (ok.rejected_items.items) |item| {
            if (std.mem.eql(u8, item.id, "GLOBAL.CAL-NOID")) {
                disp_saw_rejected = true;
                if (item.rationale.len > 0 and item.disposition == .not_a_register_claim) disp_saw_reason = true;
            }
        }
        var noid_still_unabsorbed = false;
        for (bad.items.items) |item| {
            if (std.mem.eql(u8, item.id, "GLOBAL.CAL-NOID")) noid_still_unabsorbed = true;
        }
        synth_c7_disposition_ok = ok.rejected == 1 and disp_saw_rejected and disp_saw_reason and
            ok.unabsorbed == 0 and bad.unabsorbed == 1 and noid_still_unabsorbed;
    }
    util.out("  known-good 8 (C7 {s}, synthetic): a not-a-register-claim rejection entry with\n", .{checkName("C7")});
    util.out("                its mandatory reason silences a NO-SUCH-ID finding … {s}\n", .{if (synth_c7_disposition_ok) "SILENT (reason carried)" else "BROKEN"});
    util.out("  known-bad 10 (C7 {s}, synthetic): the same entry WITHOUT the reason must NOT\n", .{checkName("C7")});
    util.out("                silence — a silent skip is how a real finding gets lost … {s}\n", .{if (synth_c7_disposition_ok) "CAUGHT (still reported)" else "BROKEN"});
    if (!synth_c7_disposition_ok) cal_ok = false;

    // C8 calibration — synthetic kill matrix + synthetic register rows.
    // Seeded known-bad: GLOBAL.CAL-KERNEL-UNKILLED at PROVEN with unkilled mutant → must be caught.
    // Null known-good:   GLOBAL.CAL-KERNEL-KILLED  at PROVEN with all mutants killed → must be silent.
    // CLAIMED silence:   GLOBAL.CAL-KERNEL-CLAIMED at CLAIMED with unkilled mutant → must be silent.
    var synth_c8_ok = false;
    {
        const synth_ext_c8 = try synthRegister(gpa, CAL_SYNTHETIC_C8_EXTRA);
        var sreg_c8 = try parseRegister(gpa, synth_ext_c8);
        var skm = try parseKillMatrix(gpa, CAL_SYNTHETIC_KILL_MATRIX);
        defer skm.deinit(gpa);
        var saw_unkilled = false;
        var saw_killed_silent = true;
        var saw_claimed_silent = true;
        for (skm.claims.items) |kc| {
            if (kc.all_killed) continue;
            const slot = sreg_c8.by_id.get(kc.claim_id) orelse continue;
            const rr = sreg_c8.rows.items[slot];
            if (std.mem.eql(u8, kc.claim_id, "GLOBAL.CAL-KERNEL-UNKILLED")) {
                if (rr.status == .proven) saw_unkilled = true;
            }
            if (std.mem.eql(u8, kc.claim_id, "GLOBAL.CAL-KERNEL-KILLED")) {
                if (rr.status == .proven) saw_killed_silent = false;
            }
            if (std.mem.eql(u8, kc.claim_id, "GLOBAL.CAL-KERNEL-CLAIMED")) {
                if (rr.status == .claimed) saw_claimed_silent = false;
            }
        }
        synth_c8_ok = saw_unkilled and saw_killed_silent and saw_claimed_silent;
    }
    util.out("  known-bad 11 (C8 {s}, synthetic): PROVEN kernel claim `GLOBAL.CAL-KERNEL-UNKILLED`\n", .{checkName("C8")});
    util.out("                with a survived mutant must be caught … {s}\n", .{if (synth_c8_ok) "CAUGHT" else "BROKEN"});
    util.out("  known-good 9 (C8 {s}, synthetic): PROVEN kernel claim `GLOBAL.CAL-KERNEL-KILLED`\n", .{checkName("C8")});
    util.out("                with all mutants killed must be silent … {s}\n", .{if (synth_c8_ok) "SILENT (correct)" else "BROKEN"});
    util.out("  known-good 9b (C8 {s}, synthetic): CLAIMED kernel claim `GLOBAL.CAL-KERNEL-CLAIMED`\n", .{checkName("C8")});
    util.out("                with unkilled mutant must be silent (only PROVEN triggers) … {s}\n", .{if (synth_c8_ok) "SILENT (correct)" else "BROKEN"});
    if (!synth_c8_ok) cal_ok = false;

    // C9 calibration — synthetic register rows + synthetic mapping document.
    // known-bad: a bogus tree cell, a register row missing from the doc, and a
    // doc row the register lacks must all be caught (CAL-TREE-BAD appears in
    // the doc with the same invalid cell, so it must not double-report as a
    // node mismatch).
    // known-good: the base register against a doc covering exactly its rows.
    var synth_c9_ok = false;
    {
        const synth_ext_c9 = try synthRegister(gpa, CAL_SYNTHETIC_C9_EXTRA);
        var sreg9 = try parseRegister(gpa, synth_ext_c9);
        var c9res: C9Result = .{};
        try checkTreeMapping(gpa, &sreg9, CAL_SYNTHETIC_C9_DOC, &c9res);
        const c9_bad_caught = c9res.invalid_cells == 1 and c9res.doc_missing_ids == 1 and
            c9res.doc_extra_ids == 1 and c9res.node_mismatches == 0;
        var sreg9g = try parseRegister(gpa, CAL_SYNTHETIC);
        var c9res_g: C9Result = .{};
        try checkTreeMapping(gpa, &sreg9g, CAL_SYNTHETIC_C9_GOOD_DOC, &c9res_g);
        const c9_good_silent = c9res_g.invalid_cells == 0 and c9res_g.doc_missing_ids == 0 and
            c9res_g.doc_extra_ids == 0 and c9res_g.node_mismatches == 0;
        synth_c9_ok = c9_bad_caught and c9_good_silent;
    }
    util.out("  known-bad 12 (C9 {s}, synthetic): a bogus tree cell, a register row missing\n", .{checkName("C9")});
    util.out("                from the mapping doc, and a doc row the register lacks\n", .{});
    util.out("                must all be reported … {s}\n", .{if (synth_c9_ok) "CAUGHT (1 invalid + 1 doc-missing + 1 doc-extra)" else "BROKEN"});
    util.out("  known-good 10 (C9 {s}, synthetic): a consistent register+doc pair must be\n", .{checkName("C9")});
    util.out("                silent … {s}\n", .{if (synth_c9_ok) "SILENT" else "BROKEN"});
    if (!synth_c9_ok) cal_ok = false;

    util.out("\n  calibration: {s}\n", .{if (cal_ok) "PASS" else "FAIL — fix the checker before trusting the run"});

    // ── summary ─────────────────────────────────────────────────────────────
    util.out("\n== SUMMARY ==\n", .{});
    util.out("  rows parsed / unparsed        {d} / {d}\n", .{ reg.rows.items.len, reg.unparsed.items.len });
    util.out("  C1a orphans / C1b alarms      {d} / {d}   (FAILS)   [C1a {s} / C1b {s}]\n", .{ c1_count, alarms.items.len, checkName("C1a"), checkName("C1b") });
    util.out("  C2 dangling evidence paths    {d}   (FAILS)   [{s}]\n", .{ c2_total, checkName("C2") });
    util.out("  C3 PROVEN w/o committed evid. {d}   (debt list — hook-gated at the floor in claimlint-floor.json)   [{s}]\n", .{ tierB.items.len + tierC.items.len, checkName("C3") });
    util.out("  C4 dangling IDs / unreferenced {d} / {d}   (report only, does not fail yet)   [{s}]\n", .{ dangling.count(), unref, checkName("C4") });
    util.out("  C5 shadowed dependencies      {d}   (report only, does not fail yet)   [{s}]\n", .{ c5, checkName("C5") });
    util.out("  A  repeated-narrowing smells  {d}   (report only)\n", .{smell});
    util.out("  C6 cite-tag mismatches         {d}   (FAILS)   [{s}]\n", .{ c6, checkName("C6") });
    util.out("  C7 unabsorbed findings         {d}   (FAILS)   [{s}]\n", .{ c7, checkName("C7") });
    util.out("  C7 non-conforming files        {d}   (reported)   [{s}]\n", .{ c7_results.nonconforming, checkName("C7") });
    util.out("  C8 mutation-adequacy violations {d}   (report only, does not fail yet)   [{s}]\n", .{ c8_violations, checkName("C8") });
    util.out("  C9 tree-mapping violations      {d}   (FAILS)   [{s}]\n", .{ c9_fail, checkName("C9") });
    util.out("  C10 volatile evidence paths     {d}   (report only — does not fail, yet)   [{s}]\n", .{ c10_hits.items.len, checkName("C10") });
    util.out("  calibration                   {s}\n", .{if (cal_ok) "PASS" else "FAIL"});

    if (reg.unparsed.items.len > 0) std.process.exit(3);
    if (!cal_ok) std.process.exit(2);
    if (c1_count > 0 or alarms.items.len > 0 or c2_total > 0 or c6 > 0 or c7 > 0 or c9_fail > 0) std.process.exit(1);
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

const C7Unabsorbed = struct {
    id: []const u8,
    proposed: []const u8,
    actual: []const u8,
    file: ?[]const u8,
    /// disposition metadata, populated only for rejected (dispositioned) items
    disposition: Disposition = .unparsed,
    refuting_row: []const u8 = "",
    rationale: []const u8 = "",
};

/// The three reason-carrying dispositions a rejection entry can carry (T272,
/// extended by T269). Every dispositioned finding must be able to answer the
/// question "why is this not in the register?" — a bare ignore list is the
/// whole risk this mechanism exists to close.
const Disposition = enum {
    /// T272: the register row named in `refuting_row` rejects the finding.
    rejected_by_register,
    /// T269 part 1: the finding's ID is not a register claim at all (an infra
    /// statement about tooling, a task-ID alias, ...). The reason lives in
    /// `rationale`, which is MANDATORY — the loader refuses reason-less
    /// entries of this kind, and the refusal is reported.
    not_a_register_claim,
    /// T269 part 1: the finding named its content under the wrong ID;
    /// `refuting_row` names the register row the content was actually absorbed
    /// under (e.g. a findings file that used a task ID as the claim ID).
    absorbed_under_register_id,
    unparsed,
};

const ConformIssue = struct { file: []const u8, reason: []const u8 };

const C7Result = struct {
    files: usize,
    conforming: usize,
    nonconforming: usize,
    conform_issues: std.ArrayList(ConformIssue),
    claims_total: usize,
    new_rows_total: usize,
    unabsorbed: usize,
    rejected: usize,
    items: std.ArrayList(C7Unabsorbed),
    rejected_items: std.ArrayList(C7Unabsorbed),
};

const RejectionEntry = struct {
    disposition: Disposition,
    refuting_row: []const u8,
    rationale: []const u8,
    /// false → the entry fails its own contract (missing mandatory reason /
    /// refuting row / unknown disposition); it must NOT silence and is
    /// reported instead ("a silent skip is how a real finding gets lost").
    valid: bool,
    invalid_reason: []const u8,
};

/// RejectionIndex — a set of (claim_id, finding_file) pairs loaded from
/// findings/rejections.json. A finding whose claim_id and file match a VALID
/// entry here does NOT count as unabsorbed; it is dispositioned, reason-carrying
/// (T272, extended by T269). Entries that fail their own contract are collected
/// in `invalid` and reported — they do NOT silence.
const RejectionIndex = struct {
    /// key = "claim_id\x00finding_file" (delimited so the two can't merge)
    entries: std.StringHashMap(RejectionEntry),
    invalid: std.ArrayList([]const u8),

    /// Only valid entries can disposition a finding.
    fn get(self: *const RejectionIndex, gpa: Allocator, claim_id: []const u8, file: []const u8) ?RejectionEntry {
        const key = std.mem.concat(gpa, u8, &.{ claim_id, "\x00", file }) catch return null;
        defer gpa.free(key);
        const e = self.entries.get(key) orelse return null;
        if (!e.valid) return null;
        return e;
    }
};

fn loadRejections(gpa: Allocator, io: Io, path: []const u8) !RejectionIndex {
    var idx: RejectionIndex = .{
        .entries = std.StringHashMap(RejectionEntry).init(gpa),
        .invalid = .empty,
    };
    const json = Io.Dir.cwd().readFileAlloc(io, path, gpa, .unlimited) catch |e| {
        if (e == error.FileNotFound) return idx;
        return e;
    };
    var parsed = std.json.parseFromSlice(std.json.Value, gpa, json, .{ .allocate = .alloc_always }) catch |e| {
        try idx.invalid.append(gpa, try std.fmt.allocPrint(gpa, "{s}: not valid JSON ({s})", .{ path, @errorName(e) }));
        return idx;
    };
    defer parsed.deinit();
    if (parsed.value != .object) {
        try idx.invalid.append(gpa, try std.fmt.allocPrint(gpa, "{s}: top-level is not an object", .{path}));
        return idx;
    }
    const rej_val = parsed.value.object.get("rejections") orelse return idx;
    if (rej_val != .array) {
        try idx.invalid.append(gpa, try std.fmt.allocPrint(gpa, "{s}: `rejections` is not an array", .{path}));
        return idx;
    }
    for (rej_val.array.items) |entry_val| {
        if (entry_val != .object) {
            try idx.invalid.append(gpa, try gpa.dupe(u8, "rejections[]: entry is not an object"));
            continue;
        }
        const obj = entry_val.object;
        const claim_id = strField(obj, "claim_id");
        const finding_file = strField(obj, "finding_file");
        if (claim_id == null or finding_file == null) {
            try idx.invalid.append(gpa, try std.fmt.allocPrint(gpa, "rejections[]: entry missing claim_id/finding_file ({s})", .{
                if (claim_id) |c| c else "(no claim_id)",
            }));
            continue;
        }
        const disp_str = strField(obj, "disposition") orelse "rejected-by-register";
        var disposition: Disposition = .unparsed;
        if (std.mem.eql(u8, disp_str, "rejected-by-register")) {
            disposition = .rejected_by_register;
        } else if (std.mem.eql(u8, disp_str, "not-a-register-claim")) {
            disposition = .not_a_register_claim;
        } else if (std.mem.eql(u8, disp_str, "absorbed-under-register-id")) {
            disposition = .absorbed_under_register_id;
        }
        const refuting_row = strField(obj, "refuting_row") orelse "";
        const rationale = strField(obj, "rationale") orelse "";
        var valid = true;
        var why: []const u8 = "";
        switch (disposition) {
            .rejected_by_register => if (refuting_row.len == 0) {
                valid = false;
                why = "rejected-by-register entry must name a refuting_row";
            },
            .not_a_register_claim => if (rationale.len == 0) {
                valid = false;
                why = "not-a-register-claim entry must carry the reason in rationale (a silent skip is how a real finding gets lost)";
            },
            .absorbed_under_register_id => if (refuting_row.len == 0) {
                valid = false;
                why = "absorbed-under-register-id entry must name the absorbing register row in refuting_row";
            },
            .unparsed => {
                valid = false;
                why = "unknown disposition";
            },
        }
        const key = try std.mem.concat(gpa, u8, &.{ claim_id.?, "\x00", finding_file.? });
        if (!valid) {
            try idx.invalid.append(gpa, try std.fmt.allocPrint(gpa, "{s} in {s}: {s}", .{ claim_id.?, finding_file.?, why }));
            continue;
        }
        try idx.entries.put(key, .{
            .disposition = disposition,
            .refuting_row = try gpa.dupe(u8, refuting_row),
            .rationale = try gpa.dupe(u8, rationale),
            .valid = true,
            .invalid_reason = "",
        });
    }
    return idx;
}

/// A string field of a JSON object, or null when absent / not a string.
/// The returned slice is only valid until the parse arena is freed — callers
/// that keep it must dupe.
fn strField(obj: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    const v = obj.get(key) orelse return null;
    if (v != .string) return null;
    return v.string;
}

/// Parse a single findings JSON file. Returns a C7Result with the claims and
/// new_rows extracted. The caller must compare these against the register.
/// The rejection index is used to filter findings that have been dispositioned.
///
/// Parsing is structural (std.json), not a character scan — the old scan read
/// only the FIRST `new_rows` entry per file and mis-parsed its status (T266,
/// T269 part 3). A file that does not conform to the findings schema
/// (findings/README.md: required task_id/date/model/claims) is REPORTED as
/// non-conforming rather than silently skipped (GRAND-AUDIT §2, T269 part 4).
fn parseFindingsFile(gpa: Allocator, io: Io, json: []const u8, file_path: []const u8, reg: *Register, rej: *const RejectionIndex) !C7Result {
    var result: C7Result = .{
        .files = 1,
        .conforming = 0,
        .nonconforming = 0,
        .conform_issues = .empty,
        .claims_total = 0,
        .new_rows_total = 0,
        .unabsorbed = 0,
        .rejected = 0,
        .items = .empty,
        .rejected_items = .empty,
    };

    // file_path may be a temporary (e.g. from a Dir.Walker); dupe it once
    const owned_file = try gpa.dupe(u8, file_path);

    // basename for rejection matching (rejections.json keys on the findings filename)
    const base = baseName(file_path);

    var parsed = std.json.parseFromSlice(std.json.Value, gpa, json, .{ .allocate = .alloc_always }) catch |e| {
        result.nonconforming = 1;
        try result.conform_issues.append(gpa, .{
            .file = owned_file,
            .reason = try std.fmt.allocPrint(gpa, "not valid JSON ({s})", .{@errorName(e)}),
        });
        return result;
    };
    defer parsed.deinit();

    if (parsed.value != .object) {
        result.nonconforming = 1;
        try result.conform_issues.append(gpa, .{
            .file = owned_file,
            .reason = try gpa.dupe(u8, "top-level is not a JSON object"),
        });
        return result;
    }

    // Schema conformance (findings/README.md): task_id, date, model, claims
    // are all required. A file missing any of them cannot contribute to the
    // absorption queue — it must be REPORTED, not silently skipped.
    const root = parsed.value.object;
    var missing_keys: std.ArrayList([]const u8) = .empty;
    defer missing_keys.deinit(gpa);
    const required = [_][]const u8{ "task_id", "date", "model", "claims" };
    for (required) |k| if (!root.contains(k)) try missing_keys.append(gpa, k);
    if (root.get("claims")) |cv| {
        if (cv != .array) try missing_keys.append(gpa, "claims-not-an-array");
    }
    if (missing_keys.items.len > 0) {
        result.nonconforming = 1;
        const joined = try std.mem.join(gpa, ", ", missing_keys.items);
        try result.conform_issues.append(gpa, .{
            .file = owned_file,
            .reason = try std.fmt.allocPrint(gpa, "missing/wrong required key(s): {s}", .{joined}),
        });
        return result;
    }
    result.conforming = 1;

    // claims[] — a claim is either an object (id + optional proposed_status)
    // or a bare string (context-dump form: "IDs you touched"). An object with
    // a proposed_status is a status proposal (compare against the register);
    // an object without one, or a string, is presence-only (the row exists
    // in the register or the finding leaks).
    if (root.get("claims")) |claims_val| {
        for (claims_val.array.items) |item| {
            result.claims_total += 1;
            if (item == .object) {
                const id_val = item.object.get("id") orelse null;
                if (id_val != null and id_val.? == .string) {
                    const claim_id = id_val.?.string;
                    const ps_val = item.object.get("proposed_status") orelse null;
                    var proposed: []const u8 = "";
                    if (ps_val != null and ps_val.? == .string) proposed = ps_val.?.string;
                    if (proposed.len == 0) {
                        try checkPresence(gpa, io, &result, reg, rej, claim_id, base, owned_file);
                    } else {
                        try checkStatusClaim(gpa, io, &result, reg, rej, claim_id, proposed, base, owned_file);
                    }
                } else {
                    result.unabsorbed += 1;
                    try result.items.append(gpa, .{
                        .id = try gpa.dupe(u8, "(claim without string id)"),
                        .proposed = "",
                        .actual = "MALFORMED",
                        .file = owned_file,
                    });
                }
            } else if (item == .string) {
                try checkPresence(gpa, io, &result, reg, rej, item.string, base, owned_file);
            } else {
                result.unabsorbed += 1;
                try result.items.append(gpa, .{
                    .id = try gpa.dupe(u8, "(non-string claim item)"),
                    .proposed = "",
                    .actual = "MALFORMED",
                    .file = owned_file,
                });
            }
        }
    }

    // new_rows[] — every entry, not just the first (the T266 defect). Same
    // item shapes as claims[], except the status field is named `status`.
    if (root.get("new_rows")) |nr_val| {
        if (nr_val == .array) {
            for (nr_val.array.items) |item| {
                result.new_rows_total += 1;
                if (item == .object) {
                    const id_val = item.object.get("id") orelse null;
                    if (id_val != null and id_val.? == .string) {
                        const nr_id = id_val.?.string;
                        const st_val = item.object.get("status") orelse null;
                        var nr_status: []const u8 = "";
                        if (st_val != null and st_val.? == .string) nr_status = st_val.?.string;
                        if (nr_status.len == 0) {
                            try checkPresence(gpa, io, &result, reg, rej, nr_id, base, owned_file);
                        } else {
                            try checkStatusClaim(gpa, io, &result, reg, rej, nr_id, nr_status, base, owned_file);
                        }
                    } else {
                        result.unabsorbed += 1;
                        try result.items.append(gpa, .{
                            .id = try gpa.dupe(u8, "(new-row without string id)"),
                            .proposed = "",
                            .actual = "MALFORMED",
                            .file = owned_file,
                        });
                    }
                } else if (item == .string) {
                    try checkPresence(gpa, io, &result, reg, rej, item.string, base, owned_file);
                } else {
                    result.unabsorbed += 1;
                    try result.items.append(gpa, .{
                        .id = try gpa.dupe(u8, "(non-string new-row item)"),
                        .proposed = "",
                        .actual = "MALFORMED",
                        .file = owned_file,
                    });
                }
            }
        }
    }

    return result;
}

/// A claim/new-row that carries a proposed status: compare it against the
/// register row of the same ID. A status mismatch (or a missing row) is
/// unabsorbed unless a valid rejection entry dispositions it.
fn checkStatusClaim(gpa: Allocator, io: Io, result: *C7Result, reg: *Register, rej: *const RejectionIndex, claim_id: []const u8, proposed: []const u8, base: []const u8, owned_file: []const u8) !void {
    if (reg.by_id.get(claim_id)) |slot| {
        const r = reg.rows.items[slot];
        const ps = parseStatus(proposed);
        if (ps != .unparsed and ps != r.status) {
            if (rej.get(gpa, claim_id, base)) |entry| {
                result.rejected += 1;
                try result.rejected_items.append(gpa, .{
                    .id = try gpa.dupe(u8, claim_id),
                    .proposed = try gpa.dupe(u8, proposed),
                    .actual = r.status.name(),
                    .file = owned_file,
                    .disposition = entry.disposition,
                    .refuting_row = entry.refuting_row,
                    .rationale = entry.rationale,
                });
            } else {
                result.unabsorbed += 1;
                try result.items.append(gpa, .{
                    .id = try gpa.dupe(u8, claim_id),
                    .proposed = try gpa.dupe(u8, proposed),
                    .actual = r.status.name(),
                    .file = owned_file,
                });
            }
        }
    } else if (try archivedStatusFor(gpa, io, claim_id)) |astat| {
        // T373: the row lives in archives/register/ now — the archive status
        // is the row's authority, exactly as the register's was before.
        const ps = parseStatus(proposed);
        if (ps != .unparsed and ps != astat) {
            if (rej.get(gpa, claim_id, base)) |entry| {
                result.rejected += 1;
                try result.rejected_items.append(gpa, .{
                    .id = try gpa.dupe(u8, claim_id),
                    .proposed = try gpa.dupe(u8, proposed),
                    .actual = astat.name(),
                    .file = owned_file,
                    .disposition = entry.disposition,
                    .refuting_row = entry.refuting_row,
                    .rationale = entry.rationale,
                });
            } else {
                result.unabsorbed += 1;
                try result.items.append(gpa, .{
                    .id = try gpa.dupe(u8, claim_id),
                    .proposed = try gpa.dupe(u8, proposed),
                    .actual = astat.name(),
                    .file = owned_file,
                });
            }
        }
    } else if (rej.get(gpa, claim_id, base)) |entry| {
        result.rejected += 1;
        try result.rejected_items.append(gpa, .{
            .id = try gpa.dupe(u8, claim_id),
            .proposed = try gpa.dupe(u8, proposed),
            .actual = "NO SUCH ID",
            .file = owned_file,
            .disposition = entry.disposition,
            .refuting_row = entry.refuting_row,
            .rationale = entry.rationale,
        });
    } else {
        result.unabsorbed += 1;
        try result.items.append(gpa, .{
            .id = try gpa.dupe(u8, claim_id),
            .proposed = try gpa.dupe(u8, proposed),
            .actual = "NO SUCH ID",
            .file = owned_file,
        });
    }
}

/// A claim/new-row with no proposed status (a context-dump string, an
/// absorption record): the only check possible is presence in the register.
/// Present → absorbed (the row exists); absent → the finding names an ID the
/// register does not know, which is a leak — unless dispositioned.
fn checkPresence(gpa: Allocator, io: Io, result: *C7Result, reg: *Register, rej: *const RejectionIndex, id: []const u8, base: []const u8, owned_file: []const u8) !void {
    if (reg.by_id.get(id)) |_| return;
    // T373: an archived row still satisfies presence — the row exists, in the archive.
    if (try archivedStatusFor(gpa, io, id)) |_| return;
    if (rej.get(gpa, id, base)) |entry| {
        result.rejected += 1;
        try result.rejected_items.append(gpa, .{
            .id = try gpa.dupe(u8, id),
            .proposed = "",
            .actual = "NO SUCH ID",
            .file = owned_file,
            .disposition = entry.disposition,
            .refuting_row = entry.refuting_row,
            .rationale = entry.rationale,
        });
    } else {
        result.unabsorbed += 1;
        try result.items.append(gpa, .{
            .id = try gpa.dupe(u8, id),
            .proposed = "",
            .actual = "NO SUCH ID",
            .file = owned_file,
        });
    }
}

/// Scan findings/*.json and check every claim against the register.
/// Findings matching a valid rejection entry are counted as dispositioned and
/// do NOT contribute to unabsorbed. Schema-non-conforming files are REPORTED,
/// not silently skipped (GRAND-AUDIT §2).
fn checkFindings(gpa: Allocator, io: Io, reg: *Register, dir_path: []const u8, rej: *const RejectionIndex) !C7Result {
    var result: C7Result = .{
        .files = 0,
        .conforming = 0,
        .nonconforming = 0,
        .conform_issues = .empty,
        .claims_total = 0,
        .new_rows_total = 0,
        .unabsorbed = 0,
        .rejected = 0,
        .items = .empty,
        .rejected_items = .empty,
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
        if (std.mem.eql(u8, e.basename, "rejections.json")) continue; // not a findings file
        // e.path is relative to the walked dir; read via dir, not cwd
        const body = dir.readFileAlloc(io, e.path, gpa, .unlimited) catch |err| {
            // an unreadable file is a non-conforming file — reported, not skipped
            result.files += 1;
            result.nonconforming += 1;
            try result.conform_issues.append(gpa, .{
                .file = try gpa.dupe(u8, e.path),
                .reason = try std.fmt.allocPrint(gpa, "unreadable ({s})", .{@errorName(err)}),
            });
            continue;
        };
        const fr = try parseFindingsFile(gpa, io, body, e.path, reg, rej);
        result.files += 1;
        result.conforming += fr.conforming;
        result.nonconforming += fr.nonconforming;
        result.claims_total += fr.claims_total;
        result.new_rows_total += fr.new_rows_total;
        result.unabsorbed += fr.unabsorbed;
        result.rejected += fr.rejected;
        try result.items.appendSlice(gpa, fr.items.items);
        try result.rejected_items.appendSlice(gpa, fr.rejected_items.items);
        try result.conform_issues.appendSlice(gpa, fr.conform_issues.items);
    }

    return result;
}

const Alarm = struct { child: usize, parent: usize };

/// `d:` edges whose parent can never be FALSE (a MEASUREMENT, a definition, or
/// a SUPERSEDED claim — none of them can be refuted). Such an edge is a dead
/// end: no falsification can ever travel it, so if the child's real dependency
/// is the *soundness* behind the measurement, that parent is missing and C1a
/// will never see the child. (SUPERSEDED rows joined the set 2026-08-03, T269:
/// a superseded claim is retired, not refutable.)
fn shadowedEdges(gpa: Allocator, reg: *Register) !std.ArrayList(Alarm) {
    var out: std.ArrayList(Alarm) = .empty;
    for (reg.rows.items, 0..) |r, i| {
        for (r.deps.items) |d| {
            if (d.kind != .derives) continue;
            const k = reg.by_id.get(d.target) orelse continue;
            const ps = reg.rows.items[k].status;
            if (ps != .measurement and ps != .definition and ps != .superseded) continue;
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
// ── C9 tree mapping (T305) ──────────────────────────────────────────────

/// Requirement-tree nodes from AXIOMS.md §3 (T271, amended T275). The
/// vocabulary is hardcoded (the SCOPES precedent): when the tree changes,
/// update this list — C9a then flags every row carrying a stale node instead
/// of a reader noticing. A row whose cell is not in this list and is not
/// `RETIRED` fails the run.
const TREE_NODES = [_][]const u8{
    "Z",
    "Z-R",
    "Z-R-MOVE",
    "Z-R-SCORE",
    "Z-R-TIE",
    "Z-R-STATE",
    "Z-R-SIGN",
    "Z-STATE",
    "Z-STATE-LEGAL",
    "Z-STATE-REACH",
    "Z-STATE-KEY",
    "Z-CONVERGE",
    "Z-CONVERGE-MONO",
    "Z-CONVERGE-FINITE",
    "Z-CONVERGE-SEED",
    "Z-CONVERGE-FIX",
    "Z-TABLE",
    "Z-TABLE-ROUNDTRIP",
    "Z-TABLE-FAITHFUL",
    "Z-TABLE-CONSISTENCY",
    "Z-COMPLETE",
    "Z-COMPLETE-ENUM",
    "Z-COMPLETE-PASSES",
    "Z-SYM",
    "Z-AUDIT",
    "Z-NONCLAIMS",
};

fn isTreeNode(v: []const u8) bool {
    for (TREE_NODES) |n| if (std.mem.eql(u8, v, n)) return true;
    return false;
}

/// A `tree` cell is valid when it names a tree node or the proposed-retirement
/// marker. `NEW:` is reserved for proposed new nodes (none are in use today).
fn isValidTreeCell(v: []const u8) bool {
    if (std.mem.eql(u8, v, "RETIRED")) return true;
    if (std.mem.startsWith(u8, v, "NEW:")) return v.len > 4;
    return isTreeNode(v);
}

const C9Result = struct {
    invalid_cells: usize = 0,
    doc_missing: bool = false,
    doc_rows: usize = 0,
    reg_rows: usize = 0,
    doc_missing_ids: usize = 0,
    doc_extra_ids: usize = 0,
    node_mismatches: usize = 0,
    retired_rows: usize = 0,
    failures: std.ArrayList([]const u8) = .empty,
};

/// Parse the mapping document's §1 row table (id -> node). Only the table
/// under `## 1. The mapping` is read; the retirement-family tables in §2 are
/// not row mappings and must not pollute the map.
fn parseMappingDoc(gpa: Allocator, text: []const u8) !std.StringHashMap([]const u8) {
    var map = std.StringHashMap([]const u8).init(gpa);
    var in_map = false;
    var it = std.mem.splitScalar(u8, text, '\n');
    while (it.next()) |line| {
        if (std.mem.startsWith(u8, line, "## 1. The mapping")) {
            in_map = true;
            continue;
        }
        if (std.mem.startsWith(u8, line, "## 2.")) break;
        if (!in_map) continue;
        if (line.len == 0 or line[0] != '|') continue;
        var cells = try splitCells(gpa, line);
        defer cells.deinit(gpa);
        const c = cells.items;
        if (c.len < 3) continue;
        const first = trim(c[1]);
        if (std.mem.eql(u8, first, "ID")) continue;
        var only_dashes = first.len > 0;
        for (first) |ch| {
            if (ch != '-' and ch != ':') only_dashes = false;
        }
        if (only_dashes) continue;
        if (first.len >= 2 and first[0] == '`' and first[first.len - 1] == '`')
            try map.put(first[1 .. first.len - 1], trim(c[2]));
    }
    return map;
}

/// C9 core: validate the register's `tree` column (C9a) and cross-check the
/// mapping document against it (C9b) — row set equality and per-row node
/// equality, so the mapping cannot silently cover a subset and cannot drift
/// from the rows it describes.
fn checkTreeMapping(gpa: Allocator, reg: *Register, doc_text: []const u8, out: *C9Result) !void {
    for (reg.rows.items) |r| {
        const v = trim(r.tree);
        if (isValidTreeCell(v)) {
            if (std.mem.eql(u8, v, "RETIRED")) out.retired_rows += 1;
            continue;
        }
        out.invalid_cells += 1;
        try out.failures.append(gpa, try std.fmt.allocPrint(
            gpa,
            "  C9 UNMAPPED  BAD CELL  `{s}` — tree column \"{s}\" is not a tree node or RETIRED (line {d})",
            .{ r.id, v, r.line },
        ));
    }

    var doc = try parseMappingDoc(gpa, doc_text);
    defer doc.deinit();
    for (reg.rows.items) |r| {
        const dnode = doc.get(r.id) orelse {
            out.doc_missing_ids += 1;
            try out.failures.append(gpa, try std.fmt.allocPrint(
                gpa,
                "  C9 UNMAPPED  DOC MISSING `{s}` — register row absent from register-tree-map.md §1",
                .{r.id},
            ));
            continue;
        };
        if (!std.mem.eql(u8, trim(dnode), trim(r.tree))) {
            out.node_mismatches += 1;
            try out.failures.append(gpa, try std.fmt.allocPrint(
                gpa,
                "  C9 UNMAPPED  NODE MISMATCH `{s}` — register says \"{s}\", doc says \"{s}\"",
                .{ r.id, trim(r.tree), trim(dnode) },
            ));
        }
    }
    var it = doc.iterator();
    while (it.next()) |e| {
        if (reg.by_id.get(e.key_ptr.*) == null) {
            out.doc_extra_ids += 1;
            try out.failures.append(gpa, try std.fmt.allocPrint(
                gpa,
                "  C9 UNMAPPED  DOC EXTRA `{s}` — mapping doc §1 names a row the register does not have",
                .{e.key_ptr.*},
            ));
        }
    }
    out.doc_rows = doc.count();
    out.reg_rows = reg.rows.items.len;
}

// ── C8 mutation-adequacy types ──────────────────────────────────────────

/// A kill-matrix entry: one kernel-function claim and its mutants.
const KillEntry = struct {
    claim_id: []const u8,
    function: []const u8,
    source_file: []const u8,
    mutants: std.ArrayList(KillMutant),
    all_killed: bool,
};

const KillMutant = struct {
    id: []const u8,
    verdict: []const u8,
};

const KillMatrix = struct {
    claims: std.ArrayList(KillEntry),
    by_id: std.StringHashMap(usize),

    fn deinit(self: *KillMatrix, gpa: Allocator) void {
        for (self.claims.items) |*c| c.mutants.deinit(gpa);
        self.claims.deinit(gpa);
        self.by_id.deinit();
    }

    fn isKilled(verdict: []const u8) bool {
        return std.mem.eql(u8, verdict, "killed");
    }
};

/// Parse the kill-matrix JSON. The kill matrix maps claim IDs to the
/// mutants covering that claim's kernel function. A claim with all mutants
/// killed has all_killed=true.
fn parseKillMatrix(gpa: Allocator, json: []const u8) !KillMatrix {
    var km: KillMatrix = .{
        .claims = .empty,
        .by_id = std.StringHashMap(usize).init(gpa),
    };
    var parsed = std.json.parseFromSlice(std.json.Value, gpa, json, .{ .allocate = .alloc_always }) catch |e| {
        util.note("C8: kill matrix is not valid JSON ({s}) — check is blind\n", .{@errorName(e)});
        return km;
    };
    defer parsed.deinit();
    if (parsed.value != .object) return km;
    const claims_arr = parsed.value.object.get("claims") orelse return km;
    if (claims_arr != .array) return km;
    for (claims_arr.array.items) |cv| {
        if (cv != .object) continue;
        const obj = cv.object;
        const cid_val = obj.get("claim_id") orelse continue;
        if (cid_val != .string) continue;
        const cid = try gpa.dupe(u8, cid_val.string);
        const fn_val = obj.get("function") orelse null;
        const func = if (fn_val != null and fn_val.? == .string) try gpa.dupe(u8, fn_val.?.string) else try gpa.dupe(u8, "-");
        const sf_val = obj.get("source_file") orelse null;
        const sf = if (sf_val != null and sf_val.? == .string) try gpa.dupe(u8, sf_val.?.string) else try gpa.dupe(u8, "-");

        var all_killed = true;
        var mutants: std.ArrayList(KillMutant) = .empty;
        if (obj.get("mutants")) |mv| {
            if (mv == .array) {
                for (mv.array.items) |m| {
                    if (m != .object) continue;
                    const mo = m.object;
                    const mid_val = mo.get("id") orelse continue;
                    if (mid_val != .string) continue;
                    const mid = try gpa.dupe(u8, mid_val.string);
                    const verd_val = mo.get("verdict") orelse continue;
                    if (verd_val != .string) continue;
                    const verd = try gpa.dupe(u8, verd_val.string);
                    if (!KillMatrix.isKilled(verd)) all_killed = false;
                    try mutants.append(gpa, .{ .id = mid, .verdict = verd });
                }
            }
        }
        try km.claims.append(gpa, .{
            .claim_id = cid,
            .function = func,
            .source_file = sf,
            .mutants = mutants,
            .all_killed = all_killed,
        });
        try km.by_id.put(cid, km.claims.items.len - 1);
    }
    return km;
}

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
