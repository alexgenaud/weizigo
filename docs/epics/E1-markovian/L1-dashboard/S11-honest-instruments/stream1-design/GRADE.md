# GRADE — stream1-design/design.md

**Task:** T897 · **Grader:** claude-sonnet-5/T897 · **Date:** 2026-08-24
**Subject:** `stream1-design/design.md`, rev 1, RECONCILED, 435 lines. Grader is none of the three
authors (arm A T857, arm B T859, reconciler T865).

## Verdict: **ACCEPTED WITH AMENDMENTS**

The mechanism is sound, non-vacuous, and mostly decidable for code-shaped surfaces. It is not yet
fit for stream3 as written: two clause-application gaps let two reviewers reach different verdicts
on the same surface, one surface class the design's own examples target (document/status-line
surfaces) is not covered by its stated inspection procedures, and one evidentiary claim in §1
overstates what the arms actually show. Each amendment below is a sentence a follow-up row could
execute; none requires redesigning the mechanism.

**Amendments owed:**
1. State explicitly what "conforms" means for a clause whose subject matter does not exist on a
   given surface (no identity concept, no aggregate, no parseable input) — an explicit vacuous-pass
   state, not silence. Without it, C3/C5/C6/C7 are undecidable on any surface that simply doesn't do
   the thing the clause is about (evidence: §1 below).
2. State a decidable procedure (or an explicit, reasoned heuristic) for enumerating the population
   of "reporting surfaces" subject to the contract. §4's T1 ("a lint walks the reporting surfaces")
   presupposes this set is already known; nothing in the document says how a surface becomes a
   member of it (evidence: §5 below).
3. Extend the seven clauses' inspection procedures to cover document/prose reporting surfaces
   (status files, dashboards written by hand or by a model) or explicitly scope them out with a
   reason. Right now the inspection language ("its type," "the writing site," "trace its
   computation") presupposes a programmatic declaration, and the paradigm failure case this whole
   sprint exists to fix — a status file that misreports its own state — falls into the gap
   (evidence: §1, surface C).
4. Correct §1's claim that both arms "independently reject" a two-valued Option/Maybe, an
   out-of-band status field, and a nullable record. Only arm B raises and rejects those three
   alternatives; arm A never mentions them. Silence is not independent rejection, and citing it as
   such overstates the convergence evidence (evidence: §4 below).

---

## 1. Decidability — seven clauses against three real surfaces

Three surfaces chosen from this repository, none hypothetical:

- **Surface A** — `bin/managent orient`'s line `lanes: {d} unregistered finding(s), {d}
  missing-finding row(s)` (`src/managent/main.zig:7075-7079`, mirrored at `:11514`). A live count,
  printed every invocation.
- **Surface B** — `managent done`'s verdict resolution and flag parsing (`src/managent/main.zig:
  4706-4746` for the verdict, `:3553-3568` for `hasFlag`/`getFlagValue`). Takes `--status` and
  writes a `verdict` string onto the task record.
- **Surface C** — the S11 sprint's own status table
  (`docs/epics/E1-markovian/L1-dashboard/S11-honest-instruments/STATUS.md`), specifically the
  per-row state labels (`ARMS`, `ACCEPTED`, `QUEUED`, `ACTIVE`, `—`). Chosen because the design's
  own §0 names "a status line" as the paradigm reporting surface, and this file's own "Honesty
  note, 2026-08-24" section admits it misreported its state three times in one session — a
  documented instance of exactly the defect S11 exists to remove.

| clause | Surface A (orient's lane count) | Surface B (`done`'s verdict) | Surface C (STATUS.md labels) |
|---|---|---|---|
| **C1** trivalence | **FAIL, decidable.** `lc.unregistered.items.len` is a bare `usize` printed with `{d}`; no tag, no type distinguishing Measured/Unknown/Refused. If `scanLanes` fails, `lanes_opt` is `null` and the line is omitted entirely — silence, not an explicit `Unknown`. | **FAIL, decidable.** `verdict_str` is a bare `[]const u8` (`"pass"`, `"blocked"`, …); nothing distinguishes an explicit `--status pass` from the unconditional default `"pass"` (`main.zig:4740-4746`). | **NEEDS INTERPRETATION.** Labels are hand-typed prose, not derived from a type or code path C1's inspection language names. Is `—` ("not started") an acceptable proxy for `Unknown`, or does the absence of an actual tag fail the clause regardless of what the label means? The clause gives no answer for a surface with no declaration to enumerate. |
| **C2** provenance | **FAIL, decidable.** No operation/inputs/subject/time is carried by the printed integer; nothing to recompute from. | **FAIL, decidable.** No record of which flag path produced the verdict. | **NEEDS INTERPRETATION.** Some rows cite a commit/line count in prose next to the label (e.g. "committed, 435 lines, reconciled from both arms"); others don't. Does an adjacent prose citation count as "carrying" the provenance fields, or must they be structured on the value itself? Two reviewers could disagree; the clause doesn't say. |
| **C3** refusal of unrecognised | **N/A** — the surface takes no input. Passes vacuously, or the clause doesn't apply — see amendment 1. | **FAIL, decidable, and demonstrated live** — see §2 below. `--verdict fail-found` (the wrong flag name) is silently ignored; the close still defaults to `verdict="pass"`. No `Refused` is ever emitted. | **N/A** — no input dispatch. Same ambiguity as Surface A. |
| **C4** derived aggregates | **PASS, decidable.** `lc.unregistered.items.len` and `lc.missing.items.len` are `.len` of the actual enumerated lists `scanLanes` builds; the count is a fold over the same object it summarizes, computed at report time. | **N/A** — no aggregate. | **N/A** — no aggregate present in the rows examined. |
| **C5** birth-time identity | **N/A** — no identity/attribution field. | **PASS, decidable, and unusually well-built for this defect class.** `cmdDone` (`main.zig:4847-4895`) refuses to close with no model set, refuses `--agent`/`--model` disagreement, and writes an explicit `"unattributed"` marker (never a silent null) when `--model-unknown <reason>` is given. This is the same file's own best-conforming surface — worth citing as evidence the clause is achievable here, not just in the abstract. | **FAIL, decidable.** The owner/model column is typed by whoever edits the file; nothing binds it to acting context (no process id, hash, or timestamp of observation), so by C5's own inspection ("if the writing site can execute with a default, placeholder… identity, the clause fails") this fails outright — the writing site is a text editor with zero enforcement. |
| **C6** expiring claims | **N/A** — computed fresh on every call; nothing stored to go stale. | **N/A** — not a liveness claim. | **FAIL, decidable, and self-confirmed by the artifact.** No row carries an evidence timestamp + horizon; the file's own "Honesty note" admits it "showed two arms as in-flight after both had closed" — a stale claim that never expired, the exact failure C6 exists to prevent, recorded by the surface about itself. |
| **C7** falsifiable checks | **N/A** — not a pass/fail check. | **N/A** — not a pass/fail check. | **N/A** — state labels aren't checks with known-bad fixtures. |

**Clauses needing interpretation:** C1 and C2 on Surface C (prose-vs-structured-field ambiguity),
and every "N/A" cell across all three surfaces — the contract never states whether "this clause's
subject matter doesn't exist here" is a pass, a skip, or undecidable. That gap is amendment 1.
**Clean, no-interpretation fails:** C1/C2 on Surfaces A and B, C3 on Surface B, C5/C6 on Surface C.
**Clean, no-interpretation pass:** C4 on Surface A, C5 on Surface B — proof the clauses are
achievable, not merely aspirational, when a surface is code-shaped.

---

## 2. Non-vacuity — a constructed failing surface

Surface B, concretely, against clause C3: run `managent done T900 --verdict fail-found --note "x"
--impression "y"`. `getFlagValue` (`main.zig:3560`) matches only the literal string `"--status"`;
`--verdict` matches nothing, `status_override` stays `null`, and `verdict_str` resolves to the
unconditional default `"pass"` (`main.zig:4740-4746`) with no diagnostic and no `Refused` emitted.
The row closes as a clean pass. This is not a hypothetical: the T857/T859 briefs that produced the
arms being graded here state the exact same defect as a live gate condition — `"managent done`
takes `--status`, not `--verdict`, ignores unknown flags silently"` — so the defect is both
independently confirmed by reading the code and already known to this sprint's own workers. Design
clause C3's inspection procedure ("walk every parse/dispatch branch; if any fall-through reaches a
valid handler rather than a refusal that quotes the raw input, the clause fails") correctly and
unambiguously classifies this surface as non-conformant. The design is not vacuous: it names a real
defect this repository actually has.

A second, independent example: `readResumeFloor` (`main.zig:6380-6404`) parses
`tools/hooks/claimlint-floor.json` into a `ResumeFloor` struct whose fields default to `0`. If a
future edit to that file drops a key (e.g. `"C1b"` omitted), the reader silently reports `C1b=0` —
indistinguishable from a genuine floor of zero. At present (`tools/hooks/claimlint-floor.json`,
checked 2026-08-24) all four keys are present, so the defect is latent rather than triggered today;
it is nonetheless a real code path that fails C1's own inspection procedure without needing
execution to see it. Contrast: the sibling type `ClaimlintSummary` in the same file (`main.zig:
6406-6412`) uses `?u64` (optional) fields precisely so "field absent" and "field is zero" stay
distinguishable — a working example of the clause's own remedy, five lines away from the surface
that lacks it.

---

## 3. Cost honesty — §6/§7 against both arms

§6 and §7 carry forward every omission and cost named in either arm (checked against the two arm
documents in the untracked working tree, not cited here by path for the same reason `design.md`
itself gives) — I traced each of the design's twelve §6 bullets and eight §7 bullets back to a
specific arm sentence and found none invented or dropped.

**One cost neither arm names, and the design doesn't either:** the migration cost for *external*
consumers of a surface's current wire format — shell scripts and other tooling that `grep`/parse
today's bare-value stdout or JSON (e.g. something piping `bin/managent orient` and grepping the
`lanes: N unregistered` line, or a script reading a bare count out of a JSON field). §7's "every
caller branches three ways, forever" and "strict refusal breaks users and scripts" both describe
costs to *callers that invoke the type in-process* or *interactive users*; neither describes the
cost of changing a surface's serialized output shape out from under a text-parsing consumer that
isn't a "caller" in the type-system sense at all. This repository already has scripts of exactly
that shape (`bin/managent orient`'s printed lines are plain text, consumed by workers reading the
preamble and potentially by other tooling grepping it). Not a defect that invalidates the design —
just a cost §7 doesn't currently carry, worth naming for stream3's honesty-of-comparison purposes.

---

## 4. Reconciliation integrity — spot-checking §5 against both arms

Read both arms in full — the working-tree documents that produced `stream1-design/design.md`'s
consolidation, deliberately not cited by path here for the same reason `design.md` itself gives
(they sit outside the tracked tree) — and checked five of §5's choices against them:

- **§5.1 (staleness, witness vs. expiry).** Accurate. Arm A's C6 states the expiry-to-`Unknown`
  requirement; arm B's R6 states the witness requirement and has no expiry-after-horizon rule
  anywhere in its contract. The design's chosen text is a faithful merge, and nothing from either
  side is dropped — the witness becomes content of design's C5, expiry becomes design's C6.
- **§5.2 (vacuous check).** Accurate. Arm A's C7 states the `Unknown("no falsifier exists")`
  emission requirement verbatim; arm B's T-B states the harness-refuses-conformance branch. Design's
  C7 keeps both sentences, matching §5.2's "both kept" claim exactly.
- **§5.3 (provenance).** Accurate, and more precise than it needs to be: design's C2 text
  ("the operation that produced it, the set of contributing inputs (or the contributor count and
  denominator), the identity of the subject measured, and the time") is close to verbatim arm B's
  R2 ("the operation … the set of contributing inputs (or the contributor count plus denominator),
  and the identity of the thing measured") with "and the time" appended from arm A's C2 ("when").
  Arm A's "population (denominator)" language is subsumed rather than dropped.
- **§5.4 (identity).** Accurate. "A process id, a worker id, an artifact hash, a timestamp of
  observation" in design's C5 is lifted essentially verbatim from arm B's R6; the birth-time/never-
  defaulted/never-backfilled language is arm A's C5. Both survive; §5.4's "chosen: both" is correct.
- **§5.5 (caller rule) and §5.6 (known-broken register).** Both accurate — arm B states the caller
  rule and the register/self-`Reading` suite output; arm A states neither. §5's characterization of
  these as one-arm contributions "kept in full" matches.

**One inaccuracy found, outside §5 but inside the same integrity question §5 exists to answer.**
§1 (Convergence) states: "both independently reject a two-valued Option/Maybe … out-of-band error
codes or a status field beside the value … a nullable record … and confidence-valued readings."
Checked against both arms: **arm B explicitly raises and rejects all three of the first alternatives**
(§2, numbered list: "1. A two-valued Option/Maybe… Rejected…", "2. Error codes / exceptions / a
separate status field… [rejected]", "3. A Measurement record with a nullable value… [rejected]").
**Arm A never mentions Option/Maybe, out-of-band error codes/status fields, or nullable records
anywhere in its document.** Arm A's §4 ("what is deliberately left out") names six omissions, and
none of them is any of these three. Only the fourth item — confidence-valued readings — is
independently stated by both arms (arm A's §4 first bullet, arm B's §5 first bullet). Silence is
not rejection: design.md's §1 uses "independent convergence… on the same set of rejected
alternatives" as evidence that "every symptom in the brief is a place with two possible answers,"
but three-quarters of that evidence is one arm's reasoning presented as if both arms had reached it
separately. This is the exact failure mode §5 itself is careful to avoid ("a consolidation that
quietly drops a cost is worse than either arm") — inverted: here a consolidation quietly *adds*
weight to a convergence claim that only one side actually supports. See amendment 4.

---

## 5. Fitness for stream3

**Not writable as-is**, for one concrete reason beyond the four amendments above: §4's T1
("a lint walks the reporting surfaces and fails any whose declaration returns a bare value") and
the whole conformance-testing section presuppose that "the reporting surfaces" is an already-known,
enumerable set. Nothing in the document says how that set is identified or bounded. §0's definition
("anything that emits a value meant to be believed") is a judgment call a human or model must make
per candidate — itself not decidable by inspection in the sense the rest of the document insists on.
For `comparison.md` to score this repository against the standard, someone first has to decide,
surface by surface, whether a given `o.p(...)` call, log line, or markdown table cell counts as "a
reporting surface" at all — and the design gives no criterion for that prior step. Combined with the
N/A-clause ambiguity (§1 above) and the prose-surface gap (Surface C, §1 above), a `comparison.md`
written today would have three different reviewers drawing the surface boundary differently and
scoring the same repository differently — which is exactly the defect this grade exists to catch.

None of this requires redesigning the mechanism; each is a sentence-scale addition (amendments 1-4
above). The document is close: one dispatch of amendments, not a redo of either arm or the
reconciliation.
