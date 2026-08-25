# Claims–evidence audit — adjudication of the all-claims race (T907)

**Adjudicator:** claude-fable-5/T907, 2026-08-24/25. Race protocol v2.1 rule 9 (judged from primary
sources: every artifact named below was opened and its numbers checked against the register row) and
rule 11 (this seat had no lane). **Sources:** the three lanes' raw batch rows in the sealed race
area (three lane directories, 12 append-only batches each, 233 unique rows per lane), the byte-identical
lane brief, `docs/epistemic/CLAIMS.md` (read, not edited), the prior adjudication
`docs/epistemic/c3-evidence-triage.md` (used as a partial answer key, not edited), and the artifacts
themselves. **Constraint honoured:** no claim status is changed here; this document rules on what each
row's *evidence* is. Where a verdict implies a status question, it is named for the row's owner and
left alone. **Inbox:** polled at every checkpoint; no directives received.

The register's dependency columns are inconsistent with each other (the `dependents` column is
populated for only a minority of rows), so in-degree throughout is **computed from the `depends-on`
column** of every row (edges of any kind, `d:`/`e:`/`n:`).

## 1. The seat's measurement — confirmed

Recomputed from the raw rows (last object wins on the one duplicated `claim_id`, `GLOBAL.C2` in the
oxalpha lane, which is why the seat's oxalpha BACKED count reads 173 and mine 172):

| | seat | this row |
|---|---|---|
| claims all three judged | 233 | **233** (union 233 = register 233; no gaps, no extras) |
| unanimous | 96 | **97** (BACKED 67, PROSE-ONLY 30) |
| majority (2 of 3) | 96 | **95** |
| three-way split | 41 | **41** |
| dspro vs oxalpha | 42% | **43%** (100/233) |
| dspro vs glm | 66% | **66%** (153/233) |
| oxalpha vs glm | 57% | **57%** (133/233) |
| straight BACKED-vs-PROSE-ONLY | 71 | **70** |

Distributions: dspro PROSE-ONLY 125 / BACKED 92 / ADJACENT 13 / UNCHECKABLE 3; oxalpha BACKED 172 /
PROSE-ONLY 31 / ADJACENT 30; glm BACKED 102 / PROSE-ONLY 100 / ADJACENT 31. Every difference from the
seat's table is the duplicate-row handling. **Confirmed.**

## 2. The boundary — same artifact, different rule; and one lane that never opened the artifact

The brief asked whether the 70 BACKED-versus-PROSE-ONLY rows are lanes looking at *different*
artifacts or at the *same* artifact under different rules. I read all 70 lane-row triples.

**In 67 of 70 the three lanes opened the same artifact and applied different rules.** oxalpha and glm
quote the same lines, often the same line numbers (both found the `4x4/EPISTEMIC.md:17` drift; both
opened `AXIOMS.md` §2 row by row). The three exceptions, all oxalpha, are the *different-artifact*
failure: on `CODE.ADR0011-GATE` it graded `src/retro.zig:2331`, which the row does not cite; on
`GLOBAL.F1` and `GLOBAL.FP2-bounded` it credited the auditor log and the T13 probe "one edge away".
Crediting an uncited artifact is a real judgement error (it hides a repoint that the register needs),
but it is three rows, not the pattern.

**The pattern is four sub-boundaries the brief did not draw**, and each lane resolved them differently:

| sub-boundary | rows among the 70 | oxalpha | glm | dspro | my ruling |
|---|---|---|---|---|---|
| **Stipulations** — the 19 axiom rows, `GLOBAL.Z`, the `GLOBAL.C1` definition, the `REFRAME` decision, `QA-015`/`ADR0016` rule | 19 | BACKED "as defined" | PROSE-ONLY "a stipulation is stated, not established" | PROSE-ONLY (template) | **BACKED** — the text *is* the object; nothing a probe could add without changing the status |
| **Research notes that report numbers** — `retrograde-3x3.md` Findings 3/5/7/9/10, `arena-4x4-undef.md`, `retrograde-4x4.md`, the `M2` sweep counts | 20 | BACKED "prose output record" (self-flagged: "PROSE-ONLY under a strict raw-artifact rule") | PROSE-ONLY | PROSE-ONLY | **PROSE-ONLY** — a note reporting a number is testimony; only captured output (or a document that *embeds the verbatim output*, as `ko-sensitive-chainability.md` does) is output |
| **Claims whose content is a committed text or argument** — ADR arguments (`ADR0012-PAR`, `ADR0005-DBLPASS`), analyses (`4x4.A-2`, `CALIB-LESSON`), designs (`F2-REMEDY`, `BATTERY-GAPS`), literature readings (`MIGOS-RULE`, `TIE-MIGOS`) | 22 | BACKED | split (BACKED on designs/ADRs, PROSE-ONLY on analyses and readings) | PROSE-ONLY | **BACKED** when the status claims no more than the text carries (CLAIMED argument, PROVEN "as a statement about the argument", a quote-bearing reading); **PROSE-ONLY** when a PROVEN theorem rests on a sketch (`ADR0004-TERM`) |
| **Status-relative grading** — CLAIMED/UNTESTED rows citing the design or the open item | 9 | BACKED "content-at-status" (or ADJACENT "establishes openness, not the proposition") | mixed | PROSE-ONLY | the citation is a **locator**; graded PROSE-ONLY but **not a defect** — the row asserts nothing to establish |

Two findings follow, and only one of them is about the models.

**Finding 1 (the brief).** The vocabulary was closed but its key term was not defined. "Establishes" has
no meaning for a stipulation, a decision, or an UNTESTED row, and the brief did not say whether a
document that *embeds* output counts as output. Every honest lane had to invent a rule for ~50 of 233
rows; the three rules they invented account for 67 of the 70 disagreements. This is the C3 race's
missing-category defect again, in a different coat: the truth for a stipulation is "there is nothing
to establish", and the closest legal answer was BACKED for one lane and PROSE-ONLY for two. oxalpha's
ADJACENT-for-openness on 25 UNTESTED/CLAIMED rows ("establishes that the item is open, not the
proposition") was the most honest handling the schema allowed and is closer to the right answer than
either BACKED or PROSE-ONLY.

**Finding 2 (a model).** dspro's `what_i_checked` field is the identical template — *"resolved cited
paths at HEAD (all exist); read the register row and evidence cell"* — on **194 of 233 rows**
(oxalpha: 224 distinct strings, glm: 218). It did not open the artifacts; it graded by the *kind* of
citation (a `.md` is prose, a `.py`/`.log` is a probe). That is exactly the "judge by filename" failure
the brief forbade, inverted: it called `docs/evidence/GLOBAL-S2/PROVENANCE.md` PROSE-ONLY without
reading that it is a literature note with the theorem, DOI and scope argument, and called
`GLOBAL.H1-COMPUTABLE`, `QA-026`, `QA-013` PROSE-ONLY when the cited `probe-fix-2026-07-29.md` sits
beside its `.stdout`. Its 125 PROSE-ONLY is not a strict rule; it is a coarse one. Its verdicts agree
with mine on 125/233 and it raised 42 false defect flags on the 150 evidential rows.

### The rule that should have been in the brief

> **Grade the citation against the status the row records.** A verdict describes the *evidence*; a
> defect is a non-BACKED verdict on a row whose status asserts something was established (PROVEN,
> MEASUREMENT, FALSE, FALSE-AS-SCOPED, SUPERSEDED).
>
> **BACKED** requires the citation to reach the establishing artifact itself: (i) captured output of a
> committed instrument — a log, stdout, or data file, *or a document that embeds the verbatim output*;
> (ii) a committed proof or derivation, for a mathematical claim; (iii) the primary text, for a claim
> *about* a committed text (an ADR's argument, a definition, a decision, an amendment, an axiom);
> (iv) the source at a pinned commit, for a code fact; (v) a reading note that *quotes* the primary
> source, for a literature claim; (vi) an instrument-pinned result record — instrument path + hash or
> commit + invocation + results with denominators — where the raw stdout was not kept.
>
> **PROSE-ONLY** is a document that *reports* a result without any of (i)–(vi), however many
> denominators it carries. Sub-tag it **rerunnable** (the instrument is committed and named),
> **lost** (it is not), or **locator** (the row's status asserts nothing, so the citation only has to
> find the assertion — never a defect).
>
> **ADJACENT** is for an artifact that establishes a *different* proposition — including the case
> where the cited source at HEAD establishes the opposite (`CODE.M4A-HARNESS`).
>
> A citation to an **unpinned source line whose content has changed at HEAD** is not BACKED
> (`CODE.VB-STUBS`); SUPERSEDED rows must pin the commit at which they were true.

Applying that rule to all 233 gives the counts in §3. It also says why the two lanes that did the
work landed where they did: oxalpha's "content-at-status" instinct is the first sentence of the rule,
but without clause (i)'s embedded-output test it let 20 research notes through; glm applied the
brief's letter and so refused 21 committed stipulations and 21 instrument-pinned records.

## 3. Adjudication — the five counts

| verdict | rows | of which on PROVEN/MEASUREMENT/FALSE/SUPERSEDED rows |
|---|---|---|
| **BACKED** | **145** | 97 |
| **ADJACENT** | **3** | 1 |
| **PROSE-ONLY** | **85** | 52 |
| **DANGLING** | **0** | 0 — every cited path resolves at HEAD once the register's documented shorthand (`4x4/EPISTEMIC.md`, `0009`, `critique`, `roadmap`) is expanded; the only line-number drift that changed meaning is noted per row |
| **UNCHECKABLE** | **0** | 0 |
| UNKNOWN | **0** | — |

**Defects: 53 of the 150 rows whose status asserts something.** Sub-classes:
rerunnable 42, lost 8, report 2,
stale-at-HEAD 1. Of the remaining 35 non-BACKED rows, every
one is CLAIMED/UNTESTED/INTRACTABLE and its citation is a locator or a design — not a defect. Six rows
carry a volatile citation (three `*.B1` rows say so themselves; the three `4x4.WZO2-A*-EXHAUSTIVE`
rows cite the gitignored oracle-v2 4×4 artifact by path — claimlint C10 class).

**Where the prior adjudication and these lanes disagree.** `docs/epistemic/c3-evidence-triage.md`
ruled 42 rows; T901 then repointed 18 of them. All 18 are BACKED here, number-for-number (the eye-prune
stdout sections, the auditor log lines, the ten provenance notes). oxalpha and glm called all 18
BACKED; dspro called `4x3.S2` PROSE-ONLY. On the two Tier-A canaries (`GLOBAL.H1-CENSUS`,
`CODE.RESOLVER-CONTROLS`) all three lanes said BACKED. Three triage rulings are refined here:
`GLOBAL.MIGOS-RULE` (triage: UNKNOWN c|d pending a PDF read) is BACKED-by-quotation — the cited
`retrograde-3x3.md:222-241` quotes the ICGA 2009 paper and the T274 note quotes the thesis; the archived
PDF is the 2003 paper and is glyph-encoded, so it neither helps nor hurts. `CODE.M4A-HARNESS` (triage:
d + STALE) is ADJACENT — the cited `build.zig` at HEAD wires the harness. `GLOBAL.CALIB-LESSON` and
`GLOBAL.B1-AUDIT` (triage: c, a ruling to ratify) are BACKED as arguments — the committed text is the
whole content of a methodological claim. Nothing else diverges.

## 4. Most load-bearing, least backed — what the next sprint consumes

Ranked by computed in-degree among the 53 defects. The top of this list is one family:
**the E2 range-aware self-play run at 3×3** whose output was never committed. It carries `3x3.C3`
(PROVEN falsification, in-degree 3), both `3x3.E2-RUN*` measurements, `3x3.E3`, `GLOBAL.E2-SANITY`,
and through them `GLOBAL.C3` (in-degree 6) and `GLOBAL.C4` (in-degree 6). The C3 triage found an
uncommitted scratch capture of exactly this run; `src/retro.zig`'s `e2Board` is the committed probe.
One capture-and-commit repairs seven rows.

| claim | status | in-degree | sub-class | what is wrong / what cures it |
|---|---|---|---|---|
| `GLOBAL.C3` | FALSE-AS-SCOPED | 6 | rerunnable | FALSE-AS-SCOPED at 3x3 by E2, whose run output was never committed; e2Board in src/retro.zig is the committed probe. |
| `GLOBAL.C4` | FALSE-AS-SCOPED | 6 | rerunnable | Consequence claim; the ko-sensitive half is structural, the single-score half rests on C2 (T13, uncited here), the leak numbers are prose. |
| `GLOBAL.FP2-bounded` | FALSE-AS-SCOPED | 4 | rerunnable | Only the definition is cited; the falsification (T13) is committed one edge away and should be cited here. |
| `GLOBAL.S1` | PROVEN | 3 | rerunnable | Both citations are table rows asserting 'exhaustive round-trip'; no run output. The probe exists uncited: src/colex.zig main() verifies 2x2/3x3/3x2/4x4 (:196-202). |
| `GLOBAL.C2` | FALSE-AS-SCOPED | 3 | rerunnable | Prose that points to the T13 record; the falsifier (docs/evidence/T13) is committed and should be cited directly. |
| `3x3.C3` | PROVEN | 3 | rerunnable | PROVEN(falsification) with in-degree 3, cited only to prose; the E2 output is not in git (the C3 triage found an uncommitted scratch capture). Highest-value repair on the list. |
| `GLOBAL.E2-SANITY` | PROVEN | 3 | rerunnable | Asserted leak-free with trivial bounds; no output. The trivial-bounds mode exists at src/retro.zig:4056 (e2Board(2,2,…,true)). |
| `2x2.C1` | PROVEN | 2 | rerunnable | Both cite prose. No exact-solver comparison output is committed; retrograde-3x3.md Finding 3 records that the exact solver completed only 8/114 roots at 2x2, so even the underlying run was partial. |
| `3x3.E3` | PROVEN | 2 | rerunnable | '0 illegal moves in 17 plies' asserted; the leaking game record and replay output are not committed. |
| `3x3.E2-RUN1` | MEASUREMENT | 2 | rerunnable | MEASUREMENT (25/4,000) reported in three prose places; no run log. |
| `3x3.E2-RUN2` | MEASUREMENT | 2 | lost | The row itself says 'No run log is committed'; 50/8,000 survives only as a number. |
| `GLOBAL.ADR0005-CACHE` | FALSE-AS-SCOPED | 2 | rerunnable | The ADR trail records the claim, its downgrade and its falsification argument; the falsifying run (GLOBAL-AUDITOR log, 45/378) is committed and uncited here. |
| `GLOBAL.F1` | FALSE-AS-SCOPED | 2 | rerunnable | consistency-audit.md is a research note reporting 45/378; the auditor log (docs/evidence/GLOBAL-AUDITOR/consist-3x2-2026-07-30.log) establishes it and is cited only on 3x2.F1. |
| `4x4.M2` | MEASUREMENT | 2 | rerunnable | '19 sweeps' asserted in two notes; no build log committed (RETRO_4X4 rebuild ~19 min). |
| `2x2.EXACT` | MEASUREMENT | 2 | rerunnable | Prototype-era research note reporting completion numbers; no captured battery output; instrument unpinned (src/retro.zig at 2026-07-20). |
| `3x2.EXACT` | MEASUREMENT | 2 | rerunnable | '68 of 600 roots, zero mismatches' reported; no output. |
| `4x4.S1` | PROVEN | 1 | rerunnable | Same line as GLOBAL.S1; asserts the 4x4 round-trip, cites no output. src/colex.zig verify(4,4) is committed and uncited. |
| `3x3.S2-impl` | PROVEN | 1 | rerunnable | PROGRESS asserts '[3x3.S2-impl:PROVEN]' in a sentence; no falsification-run output is committed. src/rules.zig carries Benson tests (e.g. :655 theorem check ≤5 stones) but not the exhaustive 3x3 falsification the row claims. |
| `GLOBAL.LEAK` | PROVEN | 1 | rerunnable | The definition half is text; the 'player leaks' half is a reported measurement with no committed arena output (src/arena.zig is the committed probe). |
| `GLOBAL.P3` | FALSE-AS-SCOPED | 1 | rerunnable | FALSE-AS-SCOPED; the leak measurement (8-16%) is prose; arena is re-runnable. |
| `4x4.B43` | MEASUREMENT | 1 | rerunnable | Per-persona table with command line; a report, not a log. |
| `4x3.S1` | PROVEN | 0 | rerunnable | One-line inheritance assertion ('inherits the same structural proof'); the parent GLOBAL.S1 is itself prose-only and no 4x3 arm exists in colex.zig main(). |

The remaining 31 defects have in-degree 0 and are listed in §6; 30 of the 53 are
`rerunnable` with a committed instrument named in the row above (`src/colex.zig` `verify()`,
`e2Board`, `RETRO_CONSIST3`, `bin/weizigo-arena`, `RETRO_PLAIN=1`, `bin/weizigo-chainability`), so the
cure is a one-command capture, not an experiment. Eight are `lost` — E1's confounded first draft,
E2 run 2's 8,000-game log, the T314 per-run records, `GLOBAL.MEMO-XROOT`'s removed defect path,
`4x3.F4`'s missing wrapper, `QA-009`'s two runs, the `ADR0004-TERM` derivation that was never written,
and the untracked token ledger behind `CORPUS-B-METER-GAPS` — and need either a recreation or a
ruling. Four load-bearing PROVEN rows are backed by nothing but a table row asserting the result:
`GLOBAL.S1` (in-degree 3) and its two children, and `3x3.S2-impl`; each has a committed probe
uncited (`src/colex.zig`, the `rules.zig` Benson tests).

On the other side of the ledger, the most load-bearing rows in the register are well backed:
`GLOBAL.S2` (in-degree 14, literature note), `GLOBAL.INVSYM` (11, proof), `GLOBAL.FP1` (9, proof),
`GLOBAL.S4` (7, scorer + log), `GLOBAL.S3a`/`GLOBAL.FP3`/`GLOBAL.AUDITOR` (5 each, probes + logs).
The register's trunk is sound; its rot is in the 2026-07 E2/arena/prototype layer, where the
project's notes preceded its evidence discipline.

## 5. Model performance (per `docs/infra/races/capability-metrics.md`)

**Confound carried:** these lanes ran before `--thinking` was threaded; effective reasoning budgets
are unrecorded and three providers route through pi. Every ranking below is of
**models-as-served on 2026-08-24, not of models**. n = 1 task.

Substance = agreement with this adjudication (233 rows; also shown on the 150 evidential rows).
"Defect recall" = of my 53 defects, how many the lane called non-BACKED; "false flags" =
non-BACKED verdicts on evidential rows I call BACKED.

| lane | model | agree /233 | agree /150 evidential | defect recall /53 | false flags | right on the 70 | T901-repointed 18 | canaries | verdict entropy | confidence h/m/l | median `what_i_checked` | templated rows |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| T904 | ox-alpha | **169** | 119 | 27 | **2** | **49** | 18/18 | 2/2 | 0.47 | 147/86/0 | 119 | 7 |
| T905 | glm-5.2 | **166** | 116 | 46 | 25 | 42 | 18/18 | 2/2 | 0.62 | 109/124/0 | 154 | 9 |
| T903 | deepseek-v4-pro | **125** | 103 | **49** | 42 | 22 | 17/18 | 2/2 | 0.57 | 43/147/43 | 81 | **194** |

Mechanical: no lane fabricated a citation (every unresolved token in the three `cited` fields is
brace-expansion or shorthand for a path that exists; checked by hand). No interface fabrication was
possible — the brief asked for no commands.

**Judged cells (0–2, grader claude-fable-5/T907; control design not exercised by this brief — null):**

- *Category fidelity* — **oxalpha 2**: its ADJACENT-for-openness on UNTESTED rows is the correct
  reading of a category the schema lacked, and its two false flags (`B1-AUDIT`, `CALIB-LESSON`) are
  defensible readings of "argument" rows. **glm 1**: right on stipulations by the brief's letter, but
  ADJACENT on 21 instrument-pinned measurement records ("the findings record the measurement") — the
  report/output line drawn one notch too strictly — and PROSE-ONLY on `QA-021`/`4x4.FP1-C3` where the
  verbatim output is embedded in the cited note. **dspro 0**: verdicts by citation type without
  opening the artifact (194 templated rows); called committed-stdout rows PROSE-ONLY.
- *Self-reported limits* — **oxalpha 1**: flagged its own boundary on `4x3.S1`, `4x3.FP3`,
  `ADR0004-TERM`, `4x4.B43` ("PROSE-ONLY under a strict rule"); never used `low` confidence
  (147 high / 86 medium). **glm 1**: named the uncited primary-source directory on `MIGOS-RULE` and
  the uncited log on `GLOBAL.F1`; no `low` either. **dspro 1**: 43 `low`-confidence rows and three
  honest UNCHECKABLEs on the 518 MB artifact — the one place it said what it could not do — but the
  `what_i_checked` field that is graded for effort was boilerplate.

**Ranking, as served:** oxalpha 1st (highest agreement, near-zero false flags, best on the disputed
70; cost: recall of real defects only 27/53 — it is the lane most likely to wave a prose citation
through); glm 2nd (agreement within 3 rows of oxalpha, recall 46/53, but 25 false flags); dspro 3rd
(recall 49/53 is an artifact of calling 125 rows PROSE-ONLY — a coarse classifier catches most
defects and 42 non-defects). The two useful lanes are complementary: the union of oxalpha's BACKED
and glm's non-BACKED would have been a better audit than either. The C3 race's finding repeats:
oxalpha did the work and answered the operator's question over the brief's schema; the brief's
schema, not the models, produced the 2× spread.

## 6. Per-claim table (233 rows, register order)

Columns: claim; register status (qualifier trimmed); computed in-degree; verdict (kind); defect flag;
artifact opened; reason; lane verdicts as dspro/oxalpha/glm initials (B/A/P/U). Artifacts are
committed paths; volatile evidence is named by description.

| claim | status | in | verdict | defect? | artifact opened | reason | lanes |
|---|---|---|---|---|---|---|---|
| `GLOBAL.S1` | PROVEN | 3 | **PROSE-ONLY** (rerunnable) | defect | docs/epistemic/boards/4x4/EPISTEMIC.md:24 (cited :17 has drifted to a banner); 4x3/EPISTEMIC.md:24 | Both citations are table rows asserting 'exhaustive round-trip'; no run output. The probe exists uncited: src/colex.zig main() verifies 2x2/3x3/3x2/4x4 (:196-202). | P/P/P |
| `4x4.S1` | PROVEN | 1 | **PROSE-ONLY** (rerunnable) | defect | docs/epistemic/boards/4x4/EPISTEMIC.md:24 | Same line as GLOBAL.S1; asserts the 4x4 round-trip, cites no output. src/colex.zig verify(4,4) is committed and uncited. | P/P/P |
| `4x3.S1` | PROVEN | 0 | **PROSE-ONLY** (rerunnable) | defect | docs/epistemic/boards/4x3/EPISTEMIC.md:24 | One-line inheritance assertion ('inherits the same structural proof'); the parent GLOBAL.S1 is itself prose-only and no 4x3 arm exists in colex.zig main(). | P/B/P |
| `GLOBAL.S2` | PROVEN | 14 | **BACKED** (literature) | — | docs/evidence/GLOBAL-S2/PROVENANCE.md | Literature note: theorem statement, Benson 1976 citation with DOI, and a structural finite-goban scope argument. For an external theorem this is the establishing artifact. | P/B/B |
| `3x3.S2-impl` | PROVEN | 1 | **PROSE-ONLY** (rerunnable) | defect | docs/epistemic/PROGRESS.md:267 (cited :203 drifted; :203 is now ADR-0019 prose) | PROGRESS asserts '[3x3.S2-impl:PROVEN]' in a sentence; no falsification-run output is committed. src/rules.zig carries Benson tests (e.g. :655 theorem check ≤5 stones) but not the exhaustive 3x3 falsification the row claims. | P/P/P |
| `4x4.S2-impl` | UNTESTED | 0 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/epistemic/boards/4x4/EPISTEMIC.md:178-187 (cited :158-167 drifted) | UNTESTED row; the citation locates the open item. Nothing to establish. | B/A/P |
| `4x3.S2-impl` | UNTESTED | 0 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/epistemic/boards/4x3/EPISTEMIC.md:26 | UNTESTED row; the line records 'not separately regression-tested at 4x3'. | B/A/P |
| `4x3.S2` | PROVEN | 0 | **BACKED** (literature) | — | docs/evidence/GLOBAL-S2/PROVENANCE.md §3 | The theorem note states scope 'every finite goban'; 4x3 is a pure specialization (T901 repoint confirmed). | P/B/B |
| `GLOBAL.S3a` | PROVEN | 5 | **BACKED** (output) | — | docs/evidence/GLOBAL-S3a/run-kernel-2x2-2026-08-20.log (0/570 kernel violations); run-legal-count-2026-08-20.log (6/6 counts reproduced) | Independent Python probes committed with their run logs; numbers match the row. | B/B/B |
| `4x4.S3a` | PROVEN | 1 | **BACKED** (output) | — | docs/evidence/GLOBAL-S3a/run-legal-count-2026-08-20.log | Log line '4x4: legal = 24318165 register asserts 24318165 [OK]'. | B/B/B |
| `4x3.S3a` | PROVEN | 1 | **BACKED** (output) | — | docs/evidence/GLOBAL-S3a/run-legal-count-2026-08-20.log | Log line '4x3: legal = 321689 [OK]' plus the naive-vs-fast 4x3 cross-check; the OEIS caveat is definitional and stated in the row. | B/B/B |
| `GLOBAL.S4` | PROVEN | 7 | **BACKED** (output) | — | docs/evidence/GLOBAL-S4/scorer-2026-07-30.py; verify-2026-07-30.log (27/27, 120/120) | Independent scorer committed with its output; PROVENANCE records the corpus and the Zig cross-validation. | B/B/B |
| `4x4.S4` | UNTESTED | 0 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/epistemic/boards/4x4/EPISTEMIC.md:40-46 | UNTESTED(inherited) row; the citation is the inheritance note. GLOBAL-S4/PROVENANCE.md claims to discharge 4x4.S4 (size-stratified corpus incl. 4x4) but is not cited here — a repoint would change the picture. | B/A/P |
| `4x3.S4` | UNTESTED | 0 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/epistemic/boards/4x3/EPISTEMIC.md:29 | UNTESTED(inherited) row; same note as 4x4.S4. | B/A/P |
| `CODE.S4-XVAL` | MEASUREMENT | 0 | **PROSE-ONLY** (rerunnable) | defect | docs/decisions/0008-oracle-semantics-and-3x3-prototype.md:63-66 | ADR prose asserting the 500-goban/1000-move cross-validation; no output. The cross-validation test is committed in src/rules.zig (GLOBAL-S4 provenance reports it passing) but uncited. | P/P/P |
| `GLOBAL.Z-R-MOVE-B1-EQUIV` | CLAIMED | 0 | **BACKED** (source) | — | src/rules.zig Z-R-MOVE-B1-EQUIV tests (:1380-1450 region); findings/T380-ko-review.json F-3; findings/T306-b1-unification.json | Committed tests encode the corrected predicate and the falsified old wording; CLAIMED status (re-derivation owed) is honest about what the tests do not prove. | A/B/A |
| `GLOBAL.FP1` | PROVEN | 9 | **BACKED** (proof) | — | docs/evidence/GLOBAL-FP1/proof-2026-07-30.md | Full Knaster–Tarski proof with lemmas, seeds, and citations; PROVEN (as mathematics). | B/B/B |
| `2x2.B1` | CLAIMED | 2 | **PROSE-ONLY** (lost) | no defect (status asserts nothing) | docs/status/leak-crisis.md:86-101 | Row itself records the primary evidence was swept; CLAIMED. The RETRO_B1_LOFIX env hook survives (rerunnable). | P/P/P |
| `3x2.B1` | CLAIMED | 2 | **PROSE-ONLY** (lost) | no defect (status asserts nothing) | docs/status/leak-crisis.md:86-101 | Same as 2x2.B1. | P/P/P |
| `3x3.B1` | CLAIMED | 4 | **PROSE-ONLY** (lost) | no defect (status asserts nothing) | docs/status/leak-crisis.md:56-61,86-101; 4x4/EPISTEMIC.md:66-68 | Same; CLAIMED and self-declared lost. | P/P/P |
| `GLOBAL.B1-MULTIFIX` | MEASUREMENT | 0 | **PROSE-ONLY** (rerunnable) | defect | docs/status/leak-crisis.md:93-99 | MEASUREMENT reported in prose (re-converge values per goban); no run output; RETRO_B1_LOFIX hook exists. | P/P/P |
| `GLOBAL.B1-AUDIT` | PROVEN | 0 | **BACKED** (argument) | — | docs/status/leak-crisis.md:99-101; CONCEPTS.md:28-30; docs/evidence/GLOBAL-FP1/proof-2026-07-30.md (consequences) | The claim is a logical statement (a fixpoint reached from another seed is not a least-ness witness); the committed argument, and the FP1 proof note's consequences section, establish it. | P/P/P |
| `4x4.FP1` | CLAIMED | 0 | **PROSE-ONLY** (report) | no defect (status asserts nothing) | docs/epics/E1-markovian/sprints/g3b-value-correctness/pass0/accept.md | A signed ruling document reporting I4/I5 numbers; the run outputs behind them are not cited. CLAIMED — no defect, but the row leans on a report. | P/B/A |
| `4x4.FP1-C1` | UNTESTED | 0 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/epistemic/boards/4x4/EPISTEMIC.md:80-82 | UNTESTED; the citation is the experiment design. | B/A/P |
| `4x4.FP1-C2` | UNTESTED | 0 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/epistemic/boards/4x4/EPISTEMIC.md:83-84 | UNTESTED; design only. | B/A/P |
| `4x4.FP1-C3` | PROVEN | 1 | **BACKED** (output) | — | docs/research/ko-sensitive-chainability.md:74-93 (verbatim tool output, 'output above is verbatim'); src/chainability.zig | The research note embeds the verbatim exhaustive run (48,599,962 slots, 0 violations outside the flag) and names the committed tool; this subsumes the 1:37 sample the row is scoped to. | P/B/P |
| `4x3.FP1` | CLAIMED | 0 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/epistemic/boards/4x3/EPISTEMIC.md:30 | CLAIMED; the line records that the post-hoc check was not run. | P/P/P |
| `GLOBAL.FP2` | FALSE-AS-SCOPED | 4 | **BACKED** (output) | — | docs/evidence/T13/probe-reimplementation-2026-07-30.md §4,§8; findings/T706-race-g-batch2-grade.json (G30) | FALSE-AS-SCOPED at 3x2: the T13 re-implementation replays all 12 contradictions and finds 154/508; committed probe + output. | B/B/B |
| `GLOBAL.FP2-bounded` | FALSE-AS-SCOPED | 4 | **PROSE-ONLY** (rerunnable) | defect | docs/epistemic/boards/CONCEPTS.md:33-36 | Only the definition is cited; the falsification (T13) is committed one edge away and should be cited here. | P/B/P |
| `GLOBAL.FP2-general` | INTRACTABLE | 0 | **BACKED** (argument) | — | docs/epistemic/boards/CONCEPTS.md:37-42; 4x4/EPISTEMIC.md:168-177 | INTRACTABLE (possibly unprovable): the claim is an argument about information content; the committed text is that argument. No probe can exist. | B/P/P |
| `GLOBAL.FP3` | PROVEN | 5 | **BACKED** (output) | — | docs/evidence/GLOBAL-FP3/run-fp3-2026-08-22.log (0 violations / 2118 maps); probe_fp3_finite_lattice_2026_08_22.zig; GLOBAL-FP1 proof (finite height) | Proof plus an empirical re-derivation probe with committed output. | B/B/B |
| `4x4.FP3` | UNTESTED | 0 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/epistemic/boards/4x4/EPISTEMIC.md:47-52 | UNTESTED(inherited); the note explains the inheritance. | B/A/P |
| `4x3.FP3` | PROVEN | 0 | **PROSE-ONLY** (rerunnable) | defect | docs/epistemic/boards/4x3/EPISTEMIC.md:31 | PROVEN by a one-line inheritance assertion; the structural proof is committed at docs/evidence/GLOBAL-FP3 and GLOBAL-FP1 but uncited on this row (an inheritance edge or repoint cures it). | P/B/P |
| `GLOBAL.CERTCORE` | FALSE-AS-SCOPED | 0 | **PROSE-ONLY** (rerunnable) | defect | docs/decisions/0009-retrograde-value-iteration.md:65-67 | The ADR text is the source of the falsified proposition, not its falsification; T13 (committed) is the falsifier and is uncited here. | P/A/P |
| `GLOBAL.ADR0009-HONESTY` | PROVEN | 2 | **BACKED** (text) | — | docs/decisions/0009-*.md:78-89; docs/evidence/GLOBAL.ADR0009-HONESTY/PROVENANCE.md | Claim is about the ADR's own argument; the ADR text carries it verbatim. | B/B/B |
| `GLOBAL.INVSYM` | PROVEN | 11 | **BACKED** (proof) | — | docs/evidence/GLOBAL-INVSYM/proof-2026-07-30.md | Commutation proof for colour inversion and dihedral action; engine compliance is explicitly out of scope of the row. | B/B/B |
| `GLOBAL.ADR0020-LH-CORRECT` | PROVEN | 1 | **BACKED** (output) | — | docs/evidence/QA-023/ko-fix-2026-07-29/fix2x2.py; docs/audits/adr0020-gap-adjudication.md §2-4 (re-run: 716 L<H, 0 Bellman, 0 L>H); src/retro.zig tests :4575,:4594 (present at HEAD) | Independent instrument committed, its re-run recorded number-for-number, plus committed engine tests. | A/B/B |
| `GLOBAL.ADR0020-VERIFY-PASS` | CLAIMED | 1 | **BACKED** (text) | — | docs/audits/adr0020-gap-adjudication.md §3,§8; docs/evidence/QA-026/calibration-2x2-mismatch.py | The claim defines a pass condition; the adjudication text is that definition and the calibration fixture is committed. CLAIMED. | P/B/B |
| `GLOBAL.C1` | — | 0 | **BACKED** (stipulation) | — | docs/epistemic/boards/CONCEPTS.md:50-53; docs/status/leak-crisis.md:24 | Definition row; the defining text is the artifact. | B/B/P |
| `2x2.C1` | PROVEN | 2 | **PROSE-ONLY** (rerunnable) | defect | docs/status/leak-crisis.md:24; docs/epistemic/PROGRESS.md:126 | Both cite prose. No exact-solver comparison output is committed; retrograde-3x3.md Finding 3 records that the exact solver completed only 8/114 roots at 2x2, so even the underlying run was partial. | P/P/P |
| `3x2.C1` | PROVEN | 3 | **BACKED** (output) | — | docs/evidence/T13/probe-reimplementation-2026-07-30.md §3 (0/540 fresh-start re-executed); t13_probe.py; docs/research/c2-falsification-3x2.md:56-57 | Committed probe with recorded fresh-start sanity output 0/540. | A/B/A |
| `4x4.C1` | CLAIMED | 1 | **PROSE-ONLY** (report) | no defect (status asserts nothing) | docs/epics/E1-markovian/sprints/g3b-value-correctness/pass0/accept.md; docs/evidence/I11-4x4-EXHAUSTIVE/PROVENANCE.md | CLAIMED by ruling. accept.md reports six conditions with denominators but is a ruling, not output; only the I11 half has a provenance note with commands. No defect at CLAIMED. | A/B/A |
| `GLOBAL.C2` | FALSE-AS-SCOPED | 3 | **PROSE-ONLY** (rerunnable) | defect | docs/status/leak-crisis.md:25; PROGRESS.md:127; AGENTS.md:68-73 | Prose that points to the T13 record; the falsifier (docs/evidence/T13) is committed and should be cited directly. | P/P/P |
| `2x2.T12` | FALSE-AS-SCOPED | 0 | **BACKED** (output) | — | docs/evidence/QA-023/ko-fix-rerun-2026-07-29.md:390-393 + .stdout; ko-fix-2026-07-29/scc2x2.py | Tarjan over the reachable 2x2 graph: 144-vertex SCC (shipped rule), 160 (corrected); probe + record committed. | A/B/B |
| `3x2.T13` | PROVEN | 2 | **BACKED** (output) | — | docs/evidence/T13/t13_probe.py; zig_t13_replay.zig; probe-reimplementation-2026-07-30.md §4 (12/12 replay), §8 (154/508, 4,432/134,504) | The load-bearing falsification: committed probes with recorded output; the hand-verifiable idx=413 counterexample. | B/B/B |
| `3x3.C2` | UNTESTED | 0 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/epistemic/PROGRESS.md:212-213 | UNTESTED. | B/A/P |
| `4x3.C2` | UNTESTED | 0 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/epistemic/boards/4x3/EPISTEMIC.md:33 | UNTESTED; explicitly not inherited. | B/A/P |
| `4x4.C2` | UNTESTED | 0 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/epistemic/boards/4x4/EPISTEMIC.md:55,112-124 | UNTESTED (status conflict recorded). | B/A/P |
| `GLOBAL.C3` | FALSE-AS-SCOPED | 6 | **PROSE-ONLY** (rerunnable) | defect | docs/status/leak-crisis.md:26; PROGRESS.md:128; CONCEPTS.md:57-61 | FALSE-AS-SCOPED at 3x3 by E2, whose run output was never committed; e2Board in src/retro.zig is the committed probe. | P/P/P |
| `2x2.C3` | MEASUREMENT | 0 | **PROSE-ONLY** (rerunnable) | defect | docs/status/leak-crisis.md:72 | MEASUREMENT (0/4000) in a table; no run log. | P/P/P |
| `3x2.C3` | MEASUREMENT | 0 | **PROSE-ONLY** (rerunnable) | defect | docs/status/leak-crisis.md:73 | Same. | P/P/P |
| `3x3.C3` | PROVEN | 3 | **PROSE-ONLY** (rerunnable) | defect | docs/status/leak-crisis.md:36,74-79; 4x4/EPISTEMIC.md:64-75 | PROVEN(falsification) with in-degree 3, cited only to prose; the E2 output is not in git (the C3 triage found an uncommitted scratch capture). Highest-value repair on the list. | P/P/P |
| `4x3.C3` | UNTESTED | 0 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/epistemic/boards/4x3/EPISTEMIC.md:34 | UNTESTED. | B/A/P |
| `4x4.C3` | UNTESTED | 0 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/epistemic/boards/4x4/EPISTEMIC.md:64-75 | UNTESTED (status conflict recorded). | B/A/P |
| `GLOBAL.C4` | FALSE-AS-SCOPED | 6 | **PROSE-ONLY** (rerunnable) | defect | docs/status/leak-crisis.md:27; PROGRESS.md:129; 4x4/EPISTEMIC.md:35 | Consequence claim; the ko-sensitive half is structural, the single-score half rests on C2 (T13, uncited here), the leak numbers are prose. | P/P/P |
| `GLOBAL.LEAK` | PROVEN | 1 | **PROSE-ONLY** (rerunnable) | defect | docs/status/leak-crisis.md:9-14; PROGRESS.md:110-121 | The definition half is text; the 'player leaks' half is a reported measurement with no committed arena output (src/arena.zig is the committed probe). | P/P/P |
| `GLOBAL.E1` | PROVEN | 0 | **PROSE-ONLY** (lost) | defect | docs/status/leak-crisis.md:164-167 | Testimony about the confounded first-draft E1 code, which is gone; nothing committed can establish or refute it. PROVEN(methodological) is a ruling in disguise. | P/B/P |
| `GLOBAL.BRUTE-ALIASING` | FALSE | 3 | **BACKED** (output) | — | docs/audits/2026-07-30-audit-2x2-mismatch.md §1-2; 2026-07-30-audit-2x2-mismatch.py; .stdout (same dir) | Root cause read in source, independent Python re-implementation committed with its output; 24/24 mismatches explained. | A/B/B |
| `3x3.E3` | PROVEN | 2 | **PROSE-ONLY** (rerunnable) | defect | docs/status/leak-crisis.md:53-54 | '0 illegal moves in 17 plies' asserted; the leaking game record and replay output are not committed. | P/P/P |
| `GLOBAL.E2-SANITY` | PROVEN | 3 | **PROSE-ONLY** (rerunnable) | defect | docs/status/leak-crisis.md:47-51 | Asserted leak-free with trivial bounds; no output. The trivial-bounds mode exists at src/retro.zig:4056 (e2Board(2,2,…,true)). | P/P/P |
| `GLOBAL.E2-POLICY` | PROVEN | 2 | **BACKED** (source) | — | src/retro.zig e2Board (:3886; lo/hi split per side); docs/evidence/GLOBAL.E2-POLICY/PROVENANCE.md; leak-crisis.md:81-83 | The operative convention is committed code; the 'first run used lo for both' half is testimony pinned in prose — adequate for a bug-history clause. | B/B/B |
| `GLOBAL.E2-VERDICT` | CLAIMED | 0 | **BACKED** (argument) | — | docs/status/leak-crisis.md:38-42,172-174 | CLAIMED survivor hypothesis; the committed text states the structural argument. Nothing evidential is asserted. | P/P/P |
| `3x3.E2-RUN1` | MEASUREMENT | 2 | **PROSE-ONLY** (rerunnable) | defect | docs/status/leak-crisis.md:36,74; 4x4/EPISTEMIC.md:65; open-hypotheses:289 | MEASUREMENT (25/4,000) reported in three prose places; no run log. | P/P/P |
| `3x3.E2-RUN2` | MEASUREMENT | 2 | **PROSE-ONLY** (lost) | defect | docs/epistemic/PROGRESS.md:118; 3x3/EPISTEMIC.md:11 | The row itself says 'No run log is committed'; 50/8,000 survives only as a number. | P/P/P |
| `GLOBAL.ADR0005-CACHE` | FALSE-AS-SCOPED | 2 | **PROSE-ONLY** (rerunnable) | defect | docs/decisions/0005-*.md:90-93; 0008-*.md:32-38; 0013-*.md:20-44 | The ADR trail records the claim, its downgrade and its falsification argument; the falsifying run (GLOBAL-AUDITOR log, 45/378) is committed and uncited here. | P/B/P |
| `GLOBAL.ADR0008-HOLE` | PROVEN | 0 | **BACKED** (text) | — | docs/decisions/0008-*.md:32-38; docs/evidence/GLOBAL.ADR0008-HOLE/PROVENANCE.md | Claim about the ADR's own retraction; the text carries it verbatim. | B/B/B |
| `GLOBAL.F1` | FALSE-AS-SCOPED | 2 | **PROSE-ONLY** (rerunnable) | defect | docs/decisions/0013-*.md:20-44; docs/research/consistency-audit.md:25-34; CONCEPTS.md:108 | consistency-audit.md is a research note reporting 45/378; the auditor log (docs/evidence/GLOBAL-AUDITOR/consist-3x2-2026-07-30.log) establishes it and is cited only on 3x2.F1. | P/B/P |
| `3x2.F1` | PROVEN | 2 | **BACKED** (output) | — | docs/evidence/GLOBAL-AUDITOR/consist-3x2-2026-07-30.log ('RESULT new (memo_writes ON): checked=378 violations=45') | Verbatim, number-for-number. | B/B/B |
| `4x4.F1` | CLAIMED | 0 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/epistemic/boards/4x4/EPISTEMIC.md:36-37,58-61 | CLAIMED; the 4x4 auditor sample did not finish, as the text says. | P/A/P |
| `4x3.F1` | CLAIMED | 0 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/epistemic/boards/4x3/EPISTEMIC.md:35,48-50 | CLAIMED; provenance statement about the committed 4x3 artifact. | P/A/P |
| `GLOBAL.ADR0010-SOUND` | PROVEN | 0 | **BACKED** (text) | — | docs/decisions/0010-*.md:70-81; docs/evidence/GLOBAL.ADR0010-SOUND/PROVENANCE.md | Claim about the ADR's own soundness-status section; text carries it. | B/B/B |
| `2x2.F2` | MEASUREMENT | 0 | **PROSE-ONLY** (rerunnable) | defect | docs/research/retrograde-3x3.md:197-203 (Finding 10) | Research note reporting 0 diffs; the RETRO_PLAIN=1 comparison is re-runnable but no output is committed and the note is a 2026-07-20 prototype record. | P/B/P |
| `3x3.F2` | MEASUREMENT | 0 | **PROSE-ONLY** (rerunnable) | defect | docs/research/retrograde-3x3.md:181-196 (Finding 9) | Same class: completion counts and anchors reported in prose. | P/B/P |
| `4x3.F2` | UNTESTED | 0 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/epistemic/boards/4x3/EPISTEMIC.md:36 | UNTESTED. | B/A/P |
| `4x4.F2` | UNTESTED | 0 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/epistemic/boards/4x4/EPISTEMIC.md:145-152 | UNTESTED. | B/A/P |
| `3x2.F3` | PROVEN | 0 | **BACKED** (output) | — | docs/evidence/GLOBAL-AUDITOR/consist-3x2-2026-07-30.log ('soundish (writes OFF): checked=378 violations=0') | Verbatim. | B/B/B |
| `4x4.F3` | UNTESTED | 1 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/epistemic/boards/4x4/EPISTEMIC.md:125-144 | UNTESTED. | B/A/P |
| `3x2.F4` | PROVEN | 0 | **BACKED** (output) | — | docs/evidence/GLOBAL-AUDITOR/consist-3x2-2026-07-30.log ('deps (guarded reuse, Track B): checked=378 violations=0') | Verbatim. | B/B/B |
| `3x3.F4` | PROVEN | 0 | **PROSE-ONLY** (rerunnable) | defect | docs/decisions/0013-*.md:88-91 | ADR prose 'Validated (3x2/3x3/4x3)'; the committed log covers 3x2 only. RETRO_CONSIST3 hook exists. | P/P/P |
| `4x3.F4` | PROVEN | 0 | **PROSE-ONLY** (lost) | defect | docs/decisions/0013-*.md:88-91 | Same prose; the C3 triage found no 4x3 consist wrapper at HEAD, so this needs code, not just a re-run. | P/P/P |
| `4x4.F4` | UNTESTED | 0 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/epistemic/boards/4x4/EPISTEMIC.md:188-194 | UNTESTED. | B/A/P |
| `GLOBAL.AUDITOR` | PROVEN | 5 | **BACKED** (output) | — | docs/evidence/GLOBAL-AUDITOR/PROVENANCE.md + consist-3x2-2026-07-30.log; docs/research/consistency-audit.md:6-23 (the necessary-not-sufficient definition) | Instrument run committed; the 'necessary, not sufficient' clause is a definitional statement carried by the cited text. | B/B/B |
| `GLOBAL.MEMO-XROOT` | PROVEN | 0 | **PROSE-ONLY** (lost) | defect | docs/research/retrograde-3x3.md:23-37 (Finding 2); 0010:63-66 | 116 dihedral failures reported in a prototype note; the defective code path was removed, so a plain re-run cannot reproduce it (needs a seeded-defect recreation). | P/P/P |
| `GLOBAL.ADR0006-EYE` | CLAIMED | 3 | **BACKED** (argument) | — | docs/decisions/0006-*.md:27-49; docs/evidence/ADR-0006/2026-07-30-eye-prune-validation.md | CLAIMED weak-dominance argument; the ADR text is the argument and the T114 battery is its standing empirical test. | P/A/B |
| `GLOBAL.ADR0006-PRED` | PROVEN | 0 | **BACKED** (output) | — | docs/evidence/ADR-0006/2026-07-30-eye-prune-validation.stdout §A ('fixtures: 17 run, 0 failed'), §B (3,999,936 compared) | Verified in the stdout. | B/B/B |
| `GLOBAL.ADR0006-LEMMAS` | PROVEN | 0 | **BACKED** (output) | — | …eye-prune-validation.stdout §G ('4x4 909540 1362424 13.7 0 0 0 0 0 0'), §I mutant calibration | Verified. | B/B/B |
| `GLOBAL.ADR0006-TEST` | PROVEN | 0 | **BACKED** (output) | — | …eye-prune-validation.stdout §H (DISAGREEMENTS 0 at 2x2/3x2/3x3/4x3); …validation.md §6 (totals 4,212 slots, 4x3 1-in-8) | Verified; the 4,212 total is the md's sum over the four §H blocks. | B/B/B |
| `GLOBAL.ADR0006-PRUNEALL` | PROVEN | 0 | **BACKED** (output) | — | …eye-prune-validation.stdout §C ('PRUNE-ALL: 2602 (settled 2506 / NOT settled 96)'), §J ('live PRUNE-ALL pairs 96 comparable 96 … DISAGREEMENTS 0') | Verified. | B/B/B |
| `GLOBAL.ADR0009-NOEYE` | PROVEN | 1 | **BACKED** (source) | — | src/retro.zig:95-98 ('pub const apply_eye_prune = false;'); 0009:109-124; docs/evidence/GLOBAL.ADR0009-NOEYE/PROVENANCE.md | Design fact established by committed source constant plus the ADR decision text. | B/B/B |
| `GLOBAL.ADR0007-TENSION` | CLAIMED | 0 | **BACKED** (text) | — | docs/decisions/0007-*.md:37-43 | CLAIMED claim about what ADR-0007 left open; the text carries it. | B/B/B |
| `GLOBAL.ADR0004-TERM` | PROVEN | 0 | **PROSE-ONLY** (lost) | defect | docs/decisions/0004-*.md:16-19,31-34 | PROVEN theorem-chain claim whose only citation is a two-sentence ADR sketch; the derivation (Benson-terminal ⇒ exact leaf ⇒ depth-independent) was never written (C3 triage class c). | P/B/B |
| `GLOBAL.ADR0005-DBLPASS` | CLAIMED | 0 | **BACKED** (argument) | — | docs/decisions/0005-*.md:61-63 | CLAIMED (argued, not machine-checked); the ADR text is the argument. | P/B/B |
| `GLOBAL.ADR0005-PASS` | PROVEN | 0 | **BACKED** (source) | — | docs/decisions/0005-*.md:47-50; src/rules.zig:436-440 applyPass (no ko/history check); docs/evidence/GLOBAL.ADR0005-PASS/PROVENANCE.md | Definition plus committed unconditional applyPass. | B/B/B |
| `GLOBAL.ADR0003-AREA` | PROVEN | 2 | **BACKED** (source) | — | docs/decisions/0003-*.md:13-16,21-24; src/rules.zig:470 (C2 as-stands test); src/score.zig:19-36; docs/evidence/GLOBAL-S4/ | Both halves: purity by committed tests + S4 evidence; path-dependence definitional. | B/B/B |
| `GLOBAL.P1` | FALSE-AS-SCOPED | 0 | **PROSE-ONLY** (rerunnable) | defect | docs/epistemic/boards/CONCEPTS.md:122; 4x4/EPISTEMIC.md:33 (cited :24 drifted) | FALSE-AS-SCOPED by structural argument plus the B16 game; both citations are one-line prose. | P/P/P |
| `GLOBAL.P2` | PROVEN | 1 | **BACKED** (text) | — | docs/epistemic/boards/CONCEPTS.md:123; docs/evidence/GLOBAL.P2/PROVENANCE.md | 'Necessary, not sufficient' is a logical modality about the methodology text; the text carries it. | B/B/B |
| `GLOBAL.P3` | FALSE-AS-SCOPED | 1 | **PROSE-ONLY** (rerunnable) | defect | docs/epistemic/boards/CONCEPTS.md:124; 4x4/EPISTEMIC.md:34,62-63 | FALSE-AS-SCOPED; the leak measurement (8-16%) is prose; arena is re-runnable. | P/P/P |
| `4x4.P3` | MEASUREMENT | 0 | **PROSE-ONLY** (rerunnable) | defect | docs/epistemic/boards/4x4/EPISTEMIC.md:62-63 | MEASUREMENT '8-16% of games' with no committed arena output. | P/A/P |
| `GLOBAL.T06` | MEASUREMENT | 0 | **PROSE-ONLY** (rerunnable) | defect | docs/epistemic/PROGRESS.md:114-115 | MEASUREMENT '8-18%' in prose. | P/P/P |
| `4x4.B39` | FALSE-AS-SCOPED | 0 | **PROSE-ONLY** (rerunnable) | defect | docs/research/arena-4x4-undef.md:4-8,27-44 | The sentinel-poisoning diagnosis is a clear argument, but the 45.3% and its retraction are reported, not captured; bin/weizigo-arena is committed. | P/B/P |
| `4x4.B43` | MEASUREMENT | 1 | **PROSE-ONLY** (rerunnable) | defect | docs/research/arena-4x4-undef.md:57-91 | Per-persona table with command line; a report, not a log. | P/B/P |
| `4x4.B43-DIV` | MEASUREMENT | 0 | **PROSE-ONLY** (rerunnable) | defect | docs/research/arena-4x4-undef.md:87-91 | Same. | P/B/P |
| `4x4.B16-GAME` | MEASUREMENT | 0 | **PROSE-ONLY** (rerunnable) | defect | docs/research/retrograde-4x4.md:112-152 | Game narrative with a value trajectory; the game record and RETRO_REPLAY output are not committed as artifacts. | P/B/P |
| `GLOBAL.MIGOS-RULE` | PROVEN | 3 | **BACKED** (literature) | — | docs/research/retrograde-3x3.md:222-241 (quotes ICGA 2009: 'since superko is not used, balanced long-cycle repetition … is scored as a long-cycle-tie'); corroborated by docs/evidence/GLOBAL-TIE-MIGOS/tie-experiment-T274.md §3 (thesis App. A quotes) | A quote-bearing reading of the primary source, independently corroborated by a second reading note. Weakness: the quoted paper is not archived — docs/evidence/van-der-werf-sources/ssgo.pdf is the 2003 'Solving Go on Small Boards' paper (glyph-encoded, not text-extractable), so it cannot decide this. Resolves the C3 triage's UNKNOWN (c or d) as (d)-by-quotation. | P/B/P |
| `GLOBAL.REFRAME` | CLAIMED | 0 | **BACKED** (text) | — | docs/epistemic/PROGRESS.md:135-146; leak-crisis.md:150-154; AGENTS.md:59-62 | Adopted decision; the decision records are the artifact. | P/B/B |
| `GLOBAL.Z` | CLAIMED | 0 | **BACKED** (stipulation) | — | docs/epics/E1-markovian/AXIOMS.md §1 | Theorem statement, CLAIMED; the text is the object. | P/A/P |
| `GLOBAL.AXIOM-GEOM` | CLAIMED | 0 | **BACKED** (stipulation) | — | docs/epics/E1-markovian/AXIOMS.md:81 | A1 present verbatim. | P/B/P |
| `GLOBAL.AXIOM-STONE` | CLAIMED | 0 | **BACKED** (stipulation) | — | docs/epics/E1-markovian/AXIOMS.md:82 | A2 present. | P/B/P |
| `GLOBAL.AXIOM-CAPTURE` | CLAIMED | 0 | **BACKED** (stipulation) | — | docs/epics/E1-markovian/AXIOMS.md:83 | A3 present. | P/B/P |
| `GLOBAL.AXIOM-SUICIDE` | CLAIMED | 0 | **BACKED** (stipulation) | — | docs/epics/E1-markovian/AXIOMS.md:84 | A4 present. | P/B/P |
| `GLOBAL.AXIOM-PASS` | CLAIMED | 4 | **BACKED** (stipulation) | — | docs/epics/E1-markovian/AXIOMS.md:85; §7 Amendment 1 | A5 in amended wording ('clears the ko point'); amendment recorded. | P/B/P |
| `GLOBAL.AXIOM-FORCEDPASS` | CLAIMED | 0 | **BACKED** (stipulation) | — | docs/epics/E1-markovian/AXIOMS.md:86; docs/evidence/ORACLE-V2/build-T184-2026-08-01.stdout:162 ('terminal flags set: 516242') | A6 present; the one measured clause (516,242) is in the committed build stdout, verified. | B/B/A |
| `GLOBAL.AXIOM-BASICKO` | CLAIMED | 2 | **BACKED** (stipulation) | — | docs/epics/E1-markovian/AXIOMS.md:92 + the P0/P1/P2 derivation; §7 Amendment 1 | B1 present with the two-ply derivation written out. | P/B/P |
| `GLOBAL.AXIOM-KOSTATE` | CLAIMED | 1 | **BACKED** (stipulation) | — | docs/epics/E1-markovian/AXIOMS.md:93 | B2 present. | P/B/P |
| `GLOBAL.AXIOM-KOPASS` | CLAIMED | 0 | **BACKED** (stipulation) | — | docs/epics/E1-markovian/AXIOMS.md:94 | B3 present. | P/B/P |
| `GLOBAL.AXIOM-TERMINAL` | CLAIMED | 1 | **BACKED** (stipulation) | — | docs/epics/E1-markovian/AXIOMS.md:124 | C1 present. | P/B/P |
| `GLOBAL.AXIOM-AREA` | CLAIMED | 1 | **BACKED** (stipulation) | — | docs/epics/E1-markovian/AXIOMS.md:125; §7 Amendment 4; src/rules.zig:470 (C2 as-stands test) | C2 present in the Tromp-Taylor as-stands wording; the pinning test exists at HEAD. | P/B/A |
| `GLOBAL.AXIOM-TIE` | CLAIMED | 0 | **BACKED** (stipulation) | — | docs/epics/E1-markovian/AXIOMS.md:126 | C3 present. | P/B/P |
| `GLOBAL.AXIOM-SCORESIGN` | CLAIMED | 0 | **BACKED** (stipulation) | — | docs/epics/E1-markovian/AXIOMS.md:127 | C4 present. | P/B/P |
| `GLOBAL.AXIOM-STATE` | CLAIMED | 0 | **BACKED** (stipulation) | — | docs/epics/E1-markovian/AXIOMS.md:133 | D1 present. | P/B/P |
| `GLOBAL.AXIOM-FRESHSTART` | CLAIMED | 0 | **BACKED** (stipulation) | — | docs/epics/E1-markovian/AXIOMS.md:134 | D2 present. | P/B/P |
| `GLOBAL.AXIOM-PASSSTATE` | CLAIMED | 0 | **BACKED** (stipulation) | — | docs/epics/E1-markovian/AXIOMS.md:135 | D3 present (with the PASS-NOKO cross-reference). | P/B/P |
| `GLOBAL.AXIOM-BELLMAN` | CLAIMED | 1 | **BACKED** (stipulation) | — | docs/epics/E1-markovian/AXIOMS.md:141 | E1 present. | P/B/P |
| `GLOBAL.AXIOM-LH` | CLAIMED | 2 | **BACKED** (stipulation) | — | docs/epics/E1-markovian/AXIOMS.md:142 | E2 present. | P/B/P |
| `GLOBAL.AXIOM-BRACKET` | CLAIMED | 2 | **BACKED** (stipulation) | — | docs/epics/E1-markovian/AXIOMS.md:143 | E3 present. | P/B/P |
| `GLOBAL.TIE-MIGOS` | FALSE-AS-SCOPED | 2 | **BACKED** (literature) | — | docs/evidence/GLOBAL-TIE-MIGOS/tie-experiment-T274.md §3 (thesis App. A §A.4, §5.3.2, Table 5.1 quoted), §8 (small-goban TIE sweep); findings/T274-tie-experiment.json | Refuted by quoted primary sources plus a recorded sweep (L/H bit-identical across five TIE values). Sweep raw stdout not committed; the reading is the load-bearing half and is quote-bearing. | P/B/B |
| `GLOBAL.FIXPOINT-VS-SEARCH` | CLAIMED | 0 | **BACKED** (literature) | — | docs/evidence/GLOBAL-TIE-MIGOS/tie-experiment-T274.md §3.3; AXIOMS.md §4 | CLAIMED on one seat's reading; the reading is committed with quotes (Table 5.1: +1 under basic ko). | P/B/B |
| `GLOBAL.AXIOM-AMEND1` | CLAIMED | 0 | **BACKED** (text) | — | docs/epics/E1-markovian/AXIOMS.md §7 Amendment 1 | An axiom-change event; the log entry is the event. | B/B/B |
| `GLOBAL.AXIOM-AMEND2` | CLAIMED | 0 | **BACKED** (text) | — | docs/epics/E1-markovian/AXIOMS.md §7 Amendment 2 | Same. | B/B/B |
| `GLOBAL.AXIOM-AMEND4` | CLAIMED | 0 | **BACKED** (text) | — | docs/epics/E1-markovian/AXIOMS.md §7 Amendment 4; src/rules.zig:470 test 'C2 terminal scoring is Tromp-Taylor as-stands' | Same; the pinning test is present at HEAD. | B/B/B |
| `4x4.M2` | MEASUREMENT | 2 | **PROSE-ONLY** (rerunnable) | defect | docs/epistemic/boards/4x4/EPISTEMIC.md:364-365 (cited :246-247 drifted); docs/research/retrograde-4x4.md:113 | '19 sweeps' asserted in two notes; no build log committed (RETRO_4X4 rebuild ~19 min). | P/A/P |
| `4x3.M2` | MEASUREMENT | 0 | **PROSE-ONLY** (rerunnable) | defect | docs/epistemic/boards/4x3/EPISTEMIC.md:41 | '17 to convergence (measured)' — one line, no log. | P/B/P |
| `2x2.EXACT` | MEASUREMENT | 2 | **PROSE-ONLY** (rerunnable) | defect | docs/research/retrograde-3x3.md:74-82 (Finding 5) | Prototype-era research note reporting completion numbers; no captured battery output; instrument unpinned (src/retro.zig at 2026-07-20). | P/B/P |
| `3x2.EXACT` | MEASUREMENT | 2 | **PROSE-ONLY** (rerunnable) | defect | docs/research/retrograde-3x3.md:50-52,141 (Finding 3) | '68 of 600 roots, zero mismatches' reported; no output. | P/B/P |
| `3x3.FWD-SPOT` | MEASUREMENT | 0 | **PROSE-ONLY** (rerunnable) | defect | docs/research/retrograde-3x3.md:128-135 (Finding 7) | '105/105 matched, 295 budget-skipped' reported; no output. | P/B/P |
| `2x2.BASICKO-TIE` | MEASUREMENT | 0 | **BACKED** (output) | — | docs/evidence/QA-026/exp4-solve-2026-07-29.stdout (sweeps 4, root L=-4 H=+4 V=0, 258 reachable, inversion 0/2430); PROVENANCE.md; docs/audits/2026-07-30-audit-2x2-mismatch.md | Numbers verified in the committed stdout; the withdrawn brute-force section is flagged in the row and PROVENANCE. | B/B/B |
| `3x2.BASICKO-TIE` | MEASUREMENT | 0 | **BACKED** (output) | — | docs/evidence/QA-026/exp4-solve-2026-07-29.stdout (2586 reachable, 10 sweeps, root 0, inversion 0/2586) | Verified. | B/B/B |
| `3x3.BASICKO-TIE` | MEASUREMENT | 0 | **BACKED** (output) | — | docs/evidence/QA-026/3x3/exp5-solve-2026-07-29.stdout (73758 reachable, 0 UNDEF, 16 sweeps, root +9, inversion 0/73758) | Verified. | B/B/B |
| `4x4.BASICKO-TIE` | MEASUREMENT | 0 | **BACKED** (output) | — | docs/evidence/QA-026/4x4/exp6-solve-2026-07-29.stdout (99,133,036 compact states; root_B L=1 H=16 from sweep 13; 31 fixpoint sweeps per the T310 rebuild log) | The fixpoint numbers are in the stdout; the row's 'T104 verified H=+16 genuine — 0/99,133,036' clause is not cited to T104's output (uncited half). | B/B/B |
| `GLOBAL.PASS-NOKO` | PROVEN | 3 | **BACKED** (source) | — | src/exp6_solve.zig:927 ('encodeState4(board_idx, 1 - side, KO_NONE4, passes + 1)'); docs/evidence/GLOBAL.PASS-NOKO/PROVENANCE.md | Structural invariant established by the committed encoding plus the one-line argument. | B/B/B |
| `GLOBAL.H1-MARKOV` | UNTESTED | 1 | **ADJACENT** (probe) | no defect (status asserts nothing) | docs/evidence/QA-023/c1-contrast-2026-08-05.md + eleven .stdout files (0/404 contrast pairs disagree at 3x2; 3x3 not found within budget); docs/audits/2026-07-29-2b-3-history-pairs-audit.md; qa023-c2-adjudication §3 | Committed probe outputs bear on the claim but a sampled no-counterexample result cannot establish Markovian sufficiency; they establish 'no [F] under contrast at 3x2 in 404 pairs' and the reason the row is UNTESTED. Consistent with UNTESTED; a status question for the owner (c1-contrast §7 says the triage's 'untested' is stale). | B/A/A |
| `GLOBAL.H1-COMPUTABLE` | FALSE-AS-SCOPED | 1 | **BACKED** (output) | — | docs/evidence/QA-023/probe-fix-2026-07-29.md + .stdout; pinrule-sufficiency-2026-07-29.md + .stdout + verifier.py; docs/audits/2026-07-29-qa023-kernel-audit.md + .py + .stdout | Falsification chain with committed probes, outputs, and an independent Python verifier; the (178,0,6,0) C1 witness is hand-verified in two documents. | P/B/B |
| `GLOBAL.H1-CENSUS` | PROVEN | 2 | **BACKED** (output) | — | docs/evidence/GLOBAL.H1-CENSUS/4x4-standard.txt ('reachable triples = 51419046', 'distinct (b,ko) addresses = 29497329', 29 sweeps); 4x4-ko-disabled.txt; 4x4-broken-every_capture.txt (72,097,243 — the known-bad) | Numbers verified; known-good and known-bad controls committed. | B/B/B |
| `3x3.H1-CENSUS` | PROVEN | 0 | **BACKED** (output) | — | docs/evidence/GLOBAL.H1-CENSUS/3x3-standard.txt (22736 / 13997 / 16 sweeps) + two broken-detector controls | Verified. | B/B/B |
| `4x3.H1-CENSUS` | PROVEN | 0 | **BACKED** (output) | — | docs/evidence/GLOBAL.H1-CENSUS/4x3-standard.txt (638266; 25 sweeps) | Verified. | B/B/B |
| `4x4.G-CENSUS` | MEASUREMENT | 0 | **BACKED** (output) | — | docs/evidence/GLOBAL.H1-CENSUS/4x4-standard.txt; 4x4-ko-disabled.txt (45,734,854 no-ko reachable); design-M1.md §F2 | G is derived from the committed census outputs; the row is MEASUREMENT and reads its brackets off them. | B/B/B |
| `GLOBAL.LONGCYCLE` | FALSE-AS-SCOPED | 3 | **BACKED** (output) | — | docs/evidence/QA-023/probe-fix-2026-07-29.md + .stdout; docs/audits/2026-07-29-2b-6-full-review.md (counterexamples hand-verified); qa023-c2-adjudication | Committed probe output plus an independent auditor's hand verification of the over-pinning counterexamples. | P/B/B |
| `GLOBAL.H4` | CLAIMED | 0 | **PROSE-ONLY** (report) | no defect (status asserts nothing) | docs/epics/E1-markovian/sprints/g3b-value-correctness/pass0/accept.md; open-hypotheses:217-261; PROGRESS.md:77-81,221-223 | CLAIMED by ruling; accept.md reports the I4 numbers; no run output cited. No defect at CLAIMED. | P/B/A |
| `GLOBAL.H4a` | UNTESTED | 0 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/research/open-hypotheses-2026-07-27.md:224-235 | UNTESTED experiment design. | B/A/P |
| `GLOBAL.H4b` | UNTESTED | 0 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/research/open-hypotheses-2026-07-27.md:229-239 | UNTESTED design. Note: QA-021's exhaustive vb/vw sweep has since run the (b) experiment; the row may be stale (owner's call). | B/A/P |
| `GLOBAL.ONEMISMATCH-CURE` | FALSE-AS-SCOPED | 0 | **BACKED** (output) | — | docs/evidence/QA-023/probe-fix-2026-07-29.md + probe-fix-2026-07-29.stdout (same directory) | Falls with H1-COMPUTABLE; the cited probe record and its stdout are committed. | P/B/B |
| `4x4.A-2` | FALSE-AS-SCOPED | 1 | **BACKED** (argument) | — | docs/research/corrections-2026-07-27.md:69-96 (grounded in the chainability census: every violation KO_SENSITIVE-flagged; C2 scoped to L==H) | Category-error argument whose premises are committed measurements (ko-sensitive-chainability.md verbatim run). | P/B/P |
| `GLOBAL.CALIB-LESSON` | PROVEN | 0 | **BACKED** (argument) | — | docs/research/corrections-2026-07-27.md:197-205 (C-1 worked example: 19.51%/19.05% on the PROVEN 2x2/3x2 artifacts) | A methodological statement established by the committed argument and its worked example; PROVEN(methodological) is a ruling-class status. | P/P/P |
| `CODE.ADR0011-FMT` | vw\ | 0 | **BACKED** (source) | — | src/artifact.zig:23-53 (six-column schema, 32-byte header contract) and the reader-refusal test at :311; 0011:21-37 | Format is a code fact carried by the committed source; refusal behaviour has a committed test (uncited but adjacent to the cited lines). | B/B/B |
| `CODE.ADR0011-GATE` | PROVEN | 0 | **PROSE-ONLY** (rerunnable) | defect | docs/decisions/0011-*.md:39-46 | Behaviour claim (refuse-unless-battery-passed, reload-and-byte-verify) cited only to the ADR; src/retro.zig:2331 saveArtifact is committed but uncited and no control run exists. | P/B/P |
| `GLOBAL.ADR0012-PAR` | CLAIMED | 0 | **BACKED** (argument) | — | docs/decisions/0012-*.md:160-166; docs/evidence/GLOBAL-FP1/proof-2026-07-30.md (Bertsekas chaotic-iteration hand-off) | CLAIMED argument; committed text, and the FP1 proof note explicitly licenses it. | P/B/B |
| `4x4.I5-FEAS` | CLAIMED | 2 | **BACKED** (design) | — | docs/epics/E1-markovian/sprints/verify-battery/archive/i5-feasibility.md; docs/evidence/QA-023/census-reconciliation.md | CLAIMED projection; the memo is the projection. | P/B/A |
| `3x2.I5-CAL` | MEASUREMENT | 0 | **PROSE-ONLY** (report) | defect | docs/epics/E1-markovian/sprints/verify-battery/archive/T171-final.md (table V=255/2583, E=566/7364); T171-audit.md; src/vb_graph.zig:988-1015 | MEASUREMENT reported in a status memo; no run output committed. | A/B/B |
| `CODE.WZO2-PASSBIT` | PROVEN | 2 | **BACKED** (output) | — | docs/evidence/ORACLE-V2/m4a-accept-T193-2026-08-01.stdout ('A3 colour-inversion: checked=99133036 violations=16314978'); .md; src/oracle_v2_build.zig:387 at 5deec6b | Failure output committed; root cause pinned. | B/B/B |
| `SPRINT-M4a-ACCEPT` | PROVEN | 1 | **BACKED** (output) | — | docs/evidence/ORACLE-V2/m4a-accept-T212-2026-08-01.md + .stdout (A3 0/99,133,036; A5 0/1,021,991; A6 3/3; A9 0) | Verified. | B/B/A |
| `WZO2-4X4-VALID` | FALSE-AS-SCOPED | 0 | **BACKED** (output) | — | docs/evidence/ORACLE-V2/incompleteness-T266.md; incompleteness-verify-T277.md; t266_scan.py + t266-scan-2026-08-02.stdout (same dir); findings/T261-m4b-triage.json | FALSE-AS-SCOPED by a committed refutation chain with independent re-derivation. | P/B/B |
| `CODE.WZO2-INCOMPLETE` | FALSE-AS-SCOPED | 0 | **BACKED** (output) | — | docs/evidence/ORACLE-V2/incompleteness-T266.md §1.3 (exhaustive scan) + t266_scan.py + t266-scan-2026-08-02.stdout; incompleteness-verify-T277.md (t277_scan4.py, 0 exceptions / 24,318,165 groups) | Refutation with two independent scans. | P/B/B |
| `WZO2.I2-CLEAN` | MEASUREMENT | 0 | **BACKED** (output) | — | docs/evidence/BATTERY/i2-wzo2-T270/check_i2_wzo2.py; 4x4-raw.json (checked 99133036, violations 0); 3x3-raw.json | Instrument and raw outputs committed. | B/B/B |
| `CODE.WZO2-PASS1-LAW` | PROVEN | 1 | **BACKED** (output) | — | docs/evidence/ORACLE-V2/incompleteness-T266.md §1.1 (derivation) + t266_scan.py + stdout; T277 independent scan | Derivation from source plus exhaustive scan output. | B/B/B |
| `CODE.ACCEPT-KOKEY` | SUPERSEDED | 1 | **BACKED** (source) | — | docs/evidence/ORACLE-V2/incompleteness-T266.md §4.2 (source read at pinned c344f02); T277 verification; src/oracle_v2_accept.zig:159-162 at HEAD delegates to rules.koAfterCapture (the SUPERSEDED clause) | Pinned source finding plus independent verification; HEAD confirms the supersession. | B/B/B |
| `CODE.CLAIMLINT-C7-NEWROWS` | SUPERSEDED | 0 | **BACKED** (source) | — | docs/evidence/ORACLE-V2/incompleteness-T266.md §6a (A/B experiment on the findings file, source read at c344f02); findings/T266-incompleteness.json | Pinned source read plus a recorded A/B experiment. | B/B/B |
| `CODE.GTP-KOKEY` | PROVEN | 2 | **BACKED** (source) | — | docs/evidence/ORACLE-V2/ko-key-mismatch-T265.md (both rules quoted with file:line); human-game-1.gtp, human-game-2.gtp (inputs); src/gtp.zig at 626ec55 | Source-level mismatch pinned to commits with the game inputs committed; replay counts are reported (the T267 differential tests reproduce the disagreement, uncited). | B/B/B |
| `4x4.V1-INVSYM-BROKEN` | PROVEN | 0 | **PROSE-ONLY** (rerunnable) | defect | docs/evidence/BATTERY/triage-T260.md; findings/T260-fleet-triage.json; docs/evidence/BATTERY/i2-wzo2-T270.md | The 11,658,047 count appears only in reports; no run output committed (vb_table checkI2 is the committed instrument; the v1 artifact is gitignored). | P/B/A |
| `CODE.BATTERY-STUBBED` | PROVEN | 0 | **PROSE-ONLY** (rerunnable) | defect | docs/evidence/BATTERY/fleet.md; findings/T258-context.json | A context dump's testimony about stubCheck(); the pinned pre-2026-08-02 source is not cited (verifiable via git history). | B/B/B |
| `CODE.M4A-HARNESS` | PROVEN | 0 | **ADJACENT** (source) | defect | build.zig:177-185 and :1667-1686 at HEAD (oracle_v2_accept wired into test_step and as a battery-sweep executable); src/oracle_v2_accept.zig:19-20 | The cited artifact at HEAD establishes the opposite of clause (a): the harness IS in the build graph. PROVEN(by inspection) is stale at HEAD (C3 triage row 42); the original finding is recoverable only at the minting commit. | B/A/B |
| `CODE.VB-STUBS` | SUPERSEDED | 0 | **PROSE-ONLY** (report) | defect | src/verify_battery.zig:26-30 at HEAD (imports vb_table etc.; no stubCheck anywhere); T168-notes.md ('Stub invariants') | SUPERSEDED row whose source citations are unpinned and no longer show the stub at HEAD; only the notes memo asserts the original state. Needs a commit pin. | B/B/B |
| `CODE.VB-BLINDGAPS` | PROVEN | 0 | **BACKED** (text) | — | docs/evidence/CODE.VB-BLINDGAPS/T172-blind-analysis.md (GAP-5 at :1212) | The claim is that the analysis found five gaps; the analysis is the artifact. | B/B/B |
| `GLOBAL.ADR0014-PURE` | PROVEN | 0 | **BACKED** (source) | — | src/score.zig:19-36 (header; imports only std and rules); 0014:16-25,65-71; docs/evidence/GLOBAL.ADR0014-PURE/PROVENANCE.md | Inspection claim verified at HEAD. | B/B/B |
| `GLOBAL.ADR0016-INHERIT` | CLAIMED | 1 | **BACKED** (text) | — | docs/decisions/0016-per-board-independence-empirical-vs-structural.md | Adopted rule; the ADR is the ruling. | B/B/B |
| `GLOBAL.ADR0015-BURDEN` | CLAIMED | 0 | **BACKED** (text) | — | docs/decisions/0015, 0017, 0018 (heads read); 0010:16-18,70-93 | Ruling plus its failed refutation and unanimous confirmation, all committed. | B/B/B |
| `GLOBAL.F2-REMEDY` | CLAIMED | 0 | **BACKED** (design) | — | docs/research/f2-remedy-design-2026-07-29.md; docs/evidence/QA-023/proof-v2-2026-07-28.md; 0018 | CLAIMED design; the design doc is the object. | P/B/B |
| `4x4.D3` | UNTESTED | 4 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/epistemic/boards/4x4/EPISTEMIC.md:195-203 | UNTESTED measurement target. | B/A/P |
| `GLOBAL.BATTERY-GAPS` | CLAIMED | 2 | **BACKED** (text) | — | docs/epics/E1-markovian/sprints/verify-battery/pass1/spec.md §2; docs/evidence/ORACLE-V2/ko-key-mismatch-T265.md; incompleteness-T266.md | Coverage-gap analysis; the spec section is the analysis and the defect-family evidence it rests on is committed. | P/B/B |
| `GLOBAL.BATTERY-PASS1-ACCEPTANCE` | CLAIMED | 0 | **BACKED** (text) | — | docs/epics/E1-markovian/sprints/verify-battery/pass1/spec.md §4,§6,§7 | Acceptance-criteria re-basing is a spec decision; the spec carries it. | P/B/B |
| `CODE.KEY-AGREEMENT` | CLAIMED | 1 | **BACKED** (source) | — | src/differential.zig T267 tests (:598-692, null + seeded-defect + human games + self-play); build.zig:1389-1399 (wired into test_step); docs/evidence/GLOBAL.DIFFERENTIAL/T267-key-agreement/PROVENANCE.md | Committed tests with controls, verified wired at HEAD. | A/B/B |
| `4x4.WZO2-A2-EXHAUSTIVE` | CLAIMED | 1 | **PROSE-ONLY** (report) | no defect (status asserts nothing) | findings/T309-exhaustive-acceptance.json; the gitignored oracle-v2 4×4 artifact (VOLATILE path) | CLAIMED. The findings file reports the numbers and the command; no output captured; the second citation is an untracked path (claimlint C10 class). Instrument src/oracle_v2_accept.zig is committed and the artifact is rebuildable (T310). | U/B/A |
| `4x4.WZO2-A5-EXHAUSTIVE` | CLAIMED | 0 | **PROSE-ONLY** (report) | no defect (status asserts nothing) | findings/T309-exhaustive-acceptance.json; the gitignored oracle-v2 4×4 artifact (VOLATILE) | Same as A2. | U/B/A |
| `4x4.WZO2-A8-EXHAUSTIVE` | CLAIMED | 0 | **PROSE-ONLY** (report) | no defect (status asserts nothing) | findings/T309-exhaustive-acceptance.json; the gitignored oracle-v2 4×4 artifact (VOLATILE) | Same as A2. | U/B/A |
| `CODE.WZO2-BUILD-REPRO` | CLAIMED | 6 | **BACKED** (output) | — | docs/evidence/ORACLE-V2/rebuild-T310-2026-08-03.log (runner log ending in the file write, 31 sweeps, exit 0); rebuild-2026-08-03.md (two SHA-256 = 0c3366f0…) | Runner log committed; hash comparison recorded. | B/B/B |
| `CODE.T312-PARALLEL-FIXPOINT` | CLAIMED | 1 | **BACKED** (source) | — | src/t312_race_control.zig; src/exp6_solve.zig (runJacobiSweep, num_threads); findings/T312-parallel-fixpoint.json | CLAIMED capability; committed source and race-control tests. | B/B/B |
| `CODE.WZO2-RELEASESAFE-INV` | CLAIMED | 0 | **BACKED** (output) | — | docs/evidence/ORACLE-V2/releasesafe-rebuild-2026-08-03.md; releasesafe-rebuild-full-T313-2026-08-03.log (same dir) | Full-run log committed alongside the record. | P/B/A |
| `CODE.PARALLEL-FIXPOINT-MEASURED` | MEASUREMENT | 0 | **PROSE-ONLY** (lost) | defect | docs/research/parallel-fixpoint-measurement-2026-08-03.md (speedup table; the snapshot binary lived in a temporary directory the doc itself marks EVIDENCE LOST); findings/T314-parallel-measurement.json | MEASUREMENT whose per-run records were destroyed; only the summary table survives. | P/B/A |
| `GLOBAL.I5-SCC-CONTAIN` | CLAIMED | 1 | **PROSE-ONLY** (rerunnable) | no defect (status asserts nothing) | src/vb_scc_4x4.zig; findings/T344-i5-4x4.json (numbers in notes only) | CLAIMED; instrument committed, output not captured. | A/B/B |
| `4x4.NEW-ENGINE-MIRROR` | MEASUREMENT | 0 | **BACKED** (output) | — | findings/T375-symmetric-arbiter.json (265 KB per-game records); docs/evidence/ENGINE-VS-ENGINE/symmetric-2026-08-05.md; src/t366_evse.zig | Raw per-game records committed. | A/B/A |
| `4x4.THIRD-PARTY-ZERO` | MEASUREMENT | 0 | **BACKED** (output) | — | docs/evidence/THIRD-PARTY/raw-t381-gnugo-final.json; docs/evidence/4x4-THIRD-PARTY/runs-2026-08-08/{fuego,pachi}-strong.json; findings/T381-third-party.json (935 KB); T420 | Raw run JSON committed for all three engines. | B/B/B |
| `4x4.BRACKET-NOT-KO` | MEASUREMENT | 0 | **BACKED** (record) | — | findings/T380-ko-review.json F-5 (1,782,629/1,924,973; 3,455,412/99,133,036); docs/evidence/KO-REVIEW/retrograde-ko-2026-08-05.md §5; src/t380_census.zig (SHA in findings/T380-context.json) | Instrument-pinned result record with denominators; raw stdout not committed. | P/B/A |
| `4x4.KO-CLUSTER-MAX-2` | MEASUREMENT | 0 | **BACKED** (record) | — | findings/T380-ko-review.json F-4/F-9; KO-REVIEW md §4 (census table over 24,318,165); src/t380_census.zig | Same class. | P/B/A |
| `GLOBAL.PATHOLOGY-GRADIENT` | MEASUREMENT | 0 | **BACKED** (record) | — | findings/T382-pathology.json ('census' block); docs/research/goban-pathology-2026-08-05.md §3.1 table; src/t382_census.zig | Instrument-pinned record. | P/B/A |
| `CODE.I5-INSTRUMENT-ADJUDICATION` | MEASUREMENT | 1 | **BACKED** (output) | — | docs/evidence/I5-DISAGREEMENT/third-route-3x2-4x3.py + third-route-3x2.stdout; adjudication-2026-08-06.md | Third-route probe and its stdout committed in the cited directory. | P/B/B |
| `CODE.INSTRUMENT-COVERAGE` | MEASUREMENT | 0 | **BACKED** (text) | — | docs/infra/instrument-coverage.md; findings/T388-parametric.json ('demonstration' block) | The claim is the coverage map; the map is the artifact, with one demonstrated differential recorded. | P/B/B |
| `3x3.BRACKET-NOT-KO` | MEASUREMENT | 0 | **BACKED** (record) | — | findings/T385-corr3x3.json (graph 49,428/184,938/827 SCCs, max 48,602; correlation block); T385-gallery.json; docs/evidence/BRACKET-GALLERY/gallery-2026-08-06.md; src/t385_gallery.zig | Instrument-pinned record with the row's numbers. | A/B/A |
| `4x4.SELF-PLAY-BRACKET-CONSISTENT` | MEASUREMENT | 0 | **BACKED** (output) | — | findings/T389-trajectory-consistency.json (642 KB trajectories); src/t389_traj.zig | Raw trajectory records committed. | P/B/A |
| `GLOBAL.PSK-GRAFT-COHERENT` | MEASUREMENT | 0 | **BACKED** (record) | — | findings/T386-cycle-resolution.json (F-1 … with denominators 24,330 / 635,190); docs/decisions/0021-*.md; src/t386_coherence.zig etc. | Instrument-pinned record. | P/B/A |
| `GLOBAL.LIFE-CERTIFIES` | MEASUREMENT | 0 | **BACKED** (record) | — | findings/T393-two-life-census.json (instrument sha, calibration cross-checks, census data); docs/research/two-life-census-2026-08-06.md; src/t393_census.zig | Instrument-pinned record with controls. | P/B/A |
| `GLOBAL.TWO-LIFE-ONSET` | MEASUREMENT | 0 | **BACKED** (record) | — | findings/T393-two-life-census.json; two-life-census md; goban-pathology-2026-08-05.md:74-83 | Same. | P/B/A |
| `3x3.LIFE-NO-CENTRE` | MEASUREMENT | 0 | **BACKED** (record) | — | findings/T393-two-life-census.json; two-life-census md | Same. | P/B/A |
| `GLOBAL.CAPTURE-BUDGET-DAG` | MEASUREMENT | 0 | **BACKED** (record) | — | findings/T387-capture-budget-dag.json ('readings' block, status SALVAGED); src/t387_budget.zig | Instrument committed; readings recorded with the salvage provenance stated. | A/B/A |
| `GLOBAL.ROOT-SINGLE-IFF-FORCIBLE-LIFE` | MEASUREMENT | 0 | **BACKED** (record) | — | findings/T394-force-life.json (per-size roots, timestamped prediction); docs/research/force-life-classifier-2026-08-06.md; src/t394_force_life.zig | Instrument-pinned record; 5/5 sizes tabulated. | P/B/A |
| `GLOBAL.DRAWLOOP-CONFINED` | MEASUREMENT | 0 | **BACKED** (record) | — | findings/T394-force-life.json (exception witnesses); force-life md | Same. | P/B/A |
| `GLOBAL.NEITHER-FORCE-MOSTLY-DECISIVE` | MEASUREMENT | 0 | **BACKED** (record) | — | findings/T394-force-life.json; force-life md §T3 | Same. | P/B/A |
| `CODE.PROPERTY-OWNERSHIP` | MEASUREMENT | 0 | **BACKED** (source) | — | docs/infra/property-ownership.md; src/i4_differential.zig, src/i5_differential.zig (wired at build.zig:1466-1483); findings/T395-consolidation.json | Ownership table plus committed, wired differentials. | P/B/B |
| `QA-001` | FALSE | 0 | **BACKED** (output) | — | docs/research/ko-sensitive-chainability.md:74-93 (verbatim run: 422,990 violations, all KO_SENSITIVE, 0 outside); critique:359 | Refutation by the committed tool's verbatim output (the row's 11,402 was the 1:37 sample; exhaustive supersedes). | P/B/P |
| `QA-003` | FALSE | 0 | **BACKED** (argument) | — | docs/research/corrections-2026-07-27.md:69-96; critique:361 | Alias of 4x4.A-2; same grounded argument. | P/B/P |
| `QA-004` | FALSE | 0 | **PROSE-ONLY** (rerunnable) | defect | docs/epistemic/critique-2026-07-28.md:362; 4x4/EPISTEMIC.md:249 (M5: bracket [-6,+16]) | Refuted by a bracket value reported in prose; readable from the artifact bytes but not captured. | P/B/P |
| `QA-009` | FALSE | 0 | **PROSE-ONLY** (lost) | defect | docs/epistemic/critique-2026-07-28.md:367; CLAIMS.md §6-D1 (ruling) | 'Two real runs' is a ruling on testimony; neither run's log is committed. | P/B/B |
| `QA-011` | CLAIMED | 0 | **PROSE-ONLY** (locator) | no defect (status asserts nothing) | docs/epistemic/critique-2026-07-28.md:369; open-hypotheses:30-118 | CLAIMED alias; locator. | P/A/P |
| `QA-012` | UNTESTED | 0 | **ADJACENT** (probe) | no defect (status asserts nothing) | docs/evidence/QA-012/ (run-*-20260729.txt, calibrate-*.txt, SHA256SUMS); docs/research/psk-divergence-2026-07-29.md §Blocker | Harness calibration outputs on PSK tables are committed; the claim's own test (adjacent new-rule rungs) never ran — the artifacts establish the harness, not the claim. Consistent with UNTESTED. | P/A/A |
| `QA-013` | FALSE-AS-SCOPED | 0 | **BACKED** (output) | — | docs/evidence/QA-023/probe-fix-2026-07-29.md + .stdout; 2b-6 review; qa023-c2-adjudication | Alias of GLOBAL.LONGCYCLE; same committed falsification. | P/B/B |
| `QA-015` | CLAIMED | 1 | **BACKED** (text) | — | docs/decisions/0016-*.md; critique:373 | Decided rule; the ADR is the record. | B/B/B |
| `QA-019` | FALSE | 1 | **BACKED** (source) | — | src/retro.zig:2407 (Finisher.init(&t, gpa, finisher_budget, true, …) — 4th parameter is `bracketed: bool` at :961); critique:377 | Verified at HEAD: saveArtifact hardcodes bracketed=true independent of memo_writes. | B/B/B |
| `QA-021` | PROVEN | 1 | **BACKED** (output) | — | docs/research/ko-sensitive-chainability.md:74-93 (verbatim exhaustive run, 48,599,962 slots, 87 s); src/chainability.zig; critique:379 | Embedded verbatim output of the committed tool. | P/B/P |
| `QA-022` | FALSE | 0 | **BACKED** (text) | — | docs/evidence/README.md (lost-evidence register incl. T13/B1/T07/B05); critique:380 | Claim of irretrievability established by the committed record of the loss. | P/B/B |
| `QA-023` | CLAIMED | 4 | **BACKED** (argument) | — | docs/evidence/QA-023/proof.md (Part A, superseded in part) + proof-v2-2026-07-28.md; roadmap:302 | CLAIMED theorem-claim whose argument is committed; status honestly says unproven. Minor: the inline 'EXP-2-AUDIT-PREREG.md' reference does not resolve to a file in the directory (audit-opus-2026-07-28.md is the audit). | P/B/B |
| `QA-025` | PROVEN | 0 | **BACKED** (literature) | — | docs/research/retrograde-3x3.md:222-241 (as GLOBAL.MIGOS-RULE); roadmap:304 | Alias; same quote-bearing reading, same weakness. | P/B/P |
| `QA-026` | FALSE-AS-SCOPED | 1 | **BACKED** (output) | — | docs/evidence/QA-023/probe-fix-2026-07-29.md + .stdout; proof-v2 §5.3 (gadget); f2-remedy design | Falsified at 3x2 by committed probe output; the v1 rule's counterexample is in proof-v2. | P/B/B |
| `QA-027` | FALSE-AS-SCOPED | 0 | **BACKED** (output) | — | docs/evidence/QA-027/4x4/stdout-2026-07-31.txt (10.71%); calibration-known-good-3x3.txt (100%); calibration-known-bad-perturbed.txt; docs/research/newrule-certified-fraction-4x4-2026-07-31.md | Run output plus both calibration arms committed. | P/B/B |
| `3x3.OPTIMAL-CYCLE` | MEASUREMENT | 0 | **BACKED** (output) | — | docs/evidence/T416-OPTIMAL-CYCLE/3x3-allties.json (verdict CONTAINS-CYCLES, 54 cyclic SCCs, 4,550 states); audit-allties-3x3.json (independent re-run); src/t416_cycle.zig | Instrument output plus byte-identical audit re-run. | B/B/B |
| `4x4.OPTIMAL-CYCLE` | MEASUREMENT | 0 | **BACKED** (output) | — | docs/evidence/T416-OPTIMAL-CYCLE/4x4-allties.json (150,001 nodes / 208,908 edges, 6 cyclic SCCs); audit-4x4-150000.json | Same. | B/B/B |
| `CODE.RESOLVER-INTERFACE` | PROVEN | 2 | **BACKED** (source) | — | src/resolver.zig (:70-95 contract); docs/evidence/CODE.RESOLVER/PROVENANCE.md; ADR-0022 | Definitional code claim read off committed source. | B/B/B |
| `CODE.RESOLVER-BUDGET-QUARANTINE` | CLAIMED | 0 | **BACKED** (source) | — | src/resolver.zig:216-243 (capture_budget metadata); findings/T387-capture-budget.json; docs/research/capture-budget-2026-08-06.md | CLAIMED; the quarantine is a code fact, the non-convergence datum is single-instrument as the row says. | A/B/B |
| `CODE.RESOLVER-CONTROLS` | PROVEN | 0 | **BACKED** (source) | — | src/resolver_harness.zig (:208-219 null and seeded controls); docs/evidence/CODE.RESOLVER/PROVENANCE.md (re-run 0/23,420 and 20,216/20,216 recorded) | Harness committed; both controls' firing recorded at absorption re-run. (C3 canary — Tier A already.) | B/B/B |
| `3x3.LOOPY-TAXONOMY` | MEASUREMENT | 0 | **BACKED** (output) | — | docs/evidence/T419-TAXONOMY/3x3-real.json (forced 5,080; one_of_one 4,420; all_loopy 660; no_loop 41,928); src/t419_taxonomy.zig | Instrument output. | B/B/B |
| `4x4.LOOPY-TAXONOMY` | MEASUREMENT | 0 | **BACKED** (output) | — | docs/evidence/T419-TAXONOMY/4x4-real.json | Same. | B/B/B |
| `GLOBAL.REACH-P4-CENSUS` | MEASUREMENT | 0 | **BACKED** (output) | — | docs/evidence/GLOBAL.REACH-P4-CENSUS/census-{2x2,3x2,3x3,4x3}.stdout; crosscheck.py + crosscheck.stdout; src/t358_census_*.zig | Instrument stdouts plus an independent Python cross-check. | B/B/B |
| `4x4.LEAK-TIEBREAK` | MEASUREMENT | 0 | **BACKED** (output) | — | docs/evidence/T571-SINGLE-POSITION-LEAK/leak-probe-4x4-wzo2-seed42.json, -seed997.json; PROVENANCE.md; src/t571_leak_probe.zig | Probe outputs and commands committed. | B/B/B |
| `4x4.WRITESOFF-DUP` | MEASUREMENT | 0 | **BACKED** (output) | — | docs/evidence/T571-SINGLE-POSITION-LEAK/PROVENANCE.md §4-5 and docs/evidence/README.md:166 (identical shasum 28afa11b…, 258,280,358 bytes, CRC 0xd37646c1) | The recorded shasum output is the measurement; both files are gitignored, so re-verification needs the host. | B/B/B |
| `GLOBAL.CORPUS-B` | MEASUREMENT | 0 | **BACKED** (output) | — | docs/infra/task-corpus-b/ (manifest.json, chunk-*-m6.jsonl, derive.py, notes.md); findings/T818-corpus-b.json; findings/T835-corpus-claims-audit.json | Deterministic instrument and its full output committed and independently audited. | B/B/B |
| `GLOBAL.CORPUS-B-METER-GAPS` | FALSE-AS-SCOPED | 0 | **PROSE-ONLY** (lost) | defect | docs/infra/task-corpus-b/notes.md (Anomalies 2-3); findings/T818, T835 | The 771/1387 null-token count is a reading of an untracked ledger (the untracked token ledger); only the report is committed. T835 audited the report, not the ledger. | B/B/B |
