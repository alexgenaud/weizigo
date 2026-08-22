# Race G — batch 2: the sealed target set (adversarial arm)

**Sealed before dispatch.** This enumeration IS the ruling-35 denominator: thoroughness on this
race is coverage of *these* claims, and a lane that rules on 20 of 25 is at 20/25 however good
the 20 are. Do not add claims to the batch mid-race; a claim discovered to be missing is a
finding for batch 3.

**This batch is the adversarial arm of the claim-doubt comparison.** Everything is identical to
batch 1 — the same deterministic selection rule, the same five lanes, the same file shape, the
same all-grade-all grading round — **except the stance**, which is stated below and must be the
only thing that differs from batch 1. Do not read batch 1's target set, its lane findings, or
its grades; the comparison dies if either arm learns from the other.

## Selection rule — identical to batch 1, stated so the batch is checkable

From the 231 parsed rows of `docs/epistemic/CLAIMS.md` (`bin/weizigo-claimlint` prints "rows
parsed: 231 / rows UNPARSED: 0"), deterministically:

- **Tier A — cascade risk:** the 10 claims with the most dependents. A wrong status here
  propagates furthest.
- **Tier B — load-bearing proofs:** the next 8 `PROVEN*` claims carrying at least one dependent.
- **Tier C — falsifications:** the next 7 `FALSE*` claims carrying at least one dependent.

"Most dependents" is counted mechanically as **comma- or semicolon-separated items in the
hand-written `dependents` column** (parenthesised sub-clauses do not split; an em-dash or empty
column counts 0). Ties broken by claim ID, ascending. Batch 1's 25 claims are excluded before
the rule runs. This rule reproduces batch 1's Tier A exactly (the counting method is the one the
batch-1 selector used, re-derived by the batch-1 winner's audit — H1-MARKOV 12, ADR0006-EYE 6,
F1 6, T13 5, D3 5, ADR0015-BURDEN 5, AUDITOR 5, BRUTE-ALIASING 5, C3 5, QA-023 5) and reproduces
batch 1's 25 with two boundary substitutions at the count-3 tie line (documented in the findings
file; they do not affect this batch because batch 1's 25 are excluded either way).

**Known caveat recorded, not acted on:** the winning batch-1 lane's audit found the hand-written
`dependents` column disagrees with the computed reverse in-degree of the `depends-on` edges
(computed top: GLOBAL.S2 14, GLOBAL.INVSYM 11, GLOBAL.FP1 9, GLOBAL.S4 7 — none in batch 1). The
batch-2 arm keeps the *same* column-based rule so the two arms stay comparable; switching the
ranking method now would confound the stance comparison. This is a finding for a later batch, not
a defect in this one.

## Blind positives are seeded — a lane reporting "all verified" is wrong by construction

Per the operator's ratified ruling (`untracked/fable-absorption-gaps-2026-08-22.md` §6.2), this
batch contains **rows that are genuinely defective at HEAD**, sourced from the absorption-gap
dossier's §3 gaps and verified still-defective immediately before sealing. They are **blind**:
you are not told which rows they are. Their number and identity are sealed for the grader in
`findings/T653-batch2-design.json`. The consequence is load-bearing: **if you report every row
"verified" you are wrong, and the grading will know you are wrong.** Take the adversarial stance
below seriously — it is the only way to find them.

## Tier A cascade-risk (top dependent count)

### G26 — `4x4.C1`  ·  status **CLAIMED**

- **goban:** 4×4
- **claim as registered:** Fresh-start scores correct at 4×4 — CLAIMED by the G3b discharge
  (2026-08-05): closure + Bellman on the WZO2 4×4 table — I4 Bellman residual 0 / 95,677,624
  KO_SENSITIVE-clear entries; C-A1 0 / 616,030,190; C-A2 0 / 99,133,034; key agreement 0 /
  99,133,036; I5 0 / 3,455,412; I11 move-set 0 / 48,636,330 SMD1 slice records and 0 /
  99,133,036 stored entries (exhaustive, T473). C-A1/C-A2 denominators corrected (T383);
  scope limits (2) 4×3 I4 excludes 170,276 KO_SENSITIVE slots, (4) fresh-start under R only.
  CLAIMED is the ceiling pending Phase 3.
- **evidence cited:** `docs/epics/E1-markovian/sprints/g3b-value-correctness/pass0/accept.md`;
  `4x4/EPISTEMIC.md:141-147`; `PROGRESS.md:210-211`
- **depends on:** `e:4x4.WZO2-A2-EXHAUSTIVE`, `e:GLOBAL.I5-SCC-CONTAIN`,
  `e:CODE.KEY-AGREEMENT`, `e:GLOBAL.INVSYM`, `e:4x4.S3a`

### G27 — `4x4.F3`  ·  status **UNTESTED**

- **goban:** 4×4
- **claim as registered:** Writes-off finisher self-consistent at 4×4 (stratified sample)
- **evidence cited:** `4x4/EPISTEMIC.md:111-126`
- **depends on:** `d:4x4.D3` (re-pointed 2026-08-06 T373: `d:GLOBAL.F3` and `e:4x4.M6` left the
  register with the triage)

### G28 — `4x4.FP1`  ·  status **CLAIMED (Bellman residual = 0 verifies fixpoint property)**

- **goban:** 4×4
- **claim as registered:** L/H at 4×4 are the least/greatest fixpoints — CLAIMED by the G3b
  discharge: Bellman residual 0 / 95,677,624 KO_SENSITIVE-clear entries (I4); I5 KO_SENSITIVE ⊆
  cycle-reachable 0 / 3,455,412. Scope limits: KO_SENSITIVE column distrusted pending Track A;
  I11 is a 50,000-state sample (0.05%); fresh-start under R only.
- **evidence cited:** `docs/epics/E1-markovian/sprints/g3b-value-correctness/pass0/accept.md`;
  `4x4/EPISTEMIC.md:69-97`
- **depends on:** `d:GLOBAL.FP1`, `e:4x4.M2` (re-pointed 2026-08-06 T373)

### G29 — `CODE.I5-INSTRUMENT-ADJUDICATION`  ·  status **MEASUREMENT**

- **goban:** n/a
- **claim as registered:** I5 instrument adjudication (T391). The general I5 instrument `vb_graph`
  was wrong on every graph metric while both instruments' verdicts passed; the size-specific
  `vb_scc_4x4` was correct. Three defects, each independently verified by a third-route Python:
  (A) `vb_graph` gives passes==2 states placement successors (E 7,364 vs 5,510); (B) it projects
  SCC sizes from quadruples to triples (maxSCC 1,000 vs 1,676); (C) `vb_scc_4x4` CR propagation
  processed component ids descending, fabricating the "24 natural violations" at 4×3 all-legal
  (true reading 0). Blast radius NONE — the 4×4 and 4×3 readings re-verified unchanged. Fixes
  landed; cross-size differential gate `src/i5_differential.zig` wired into `build.zig`.
- **evidence cited:** `docs/evidence/I5-DISAGREEMENT/adjudication-2026-08-06.md`;
  `findings/T391-i5-disagreement.json`; `findings/T391-context.json`
- **depends on:** — (prose records the connection to `3x2.I5-CAL`)

### G30 — `GLOBAL.FP2`  ·  status **CLAIMED**

- **goban:** all
- **claim as registered:** Where L==H the score is history-independent — ADR-0009 honesty clause,
  explicitly NOT a theorem
- **evidence cited:** `CONCEPTS.md:31-32`; `0009:65-67,78-89`
- **depends on:** `d:GLOBAL.FP1`

### G31 — `3x3.BRACKET-NOT-KO`  ·  status **MEASUREMENT**

- **goban:** 3×3
- **claim as registered:** Brackets are NOT ko-derived at 3×3 (T385, exhaustive over the 3×3 WZO2
  graph — 49,428 entries): 93.8% (5,072/5,408) of bracketed (L<H) entries are ko-free anywhere;
  neither SCC membership nor ko-reachability predicts the bracket (100% of L<H entries lie in the
  giant SCC, but 98.1% of L==H entries do too). L<H is a value-structure property, not a ko
  property. Control: the corr3x3 adjacency CSR-offset bug was caught only by the independent
  Python re-implementation.
- **evidence cited:** `findings/T385-corr3x3.json`; `findings/T385-gallery.json`;
  `findings/T385-context.json`; `docs/evidence/BRACKET-GALLERY/gallery-2026-08-06.md`
- **depends on:** —

### G32 — `3x3.E2-RUN1`  ·  status **MEASUREMENT**

- **goban:** 3×3
- **claim as registered:** E2 run 1 (original). Range-aware self-play at 3×3 leaked 25 of 4,000
  games = 0.625%; worst leak 12 pts (promise +3 → final −9). Added promoting ruling D-1.
- **evidence cited:** `leak-crisis.md:36,74`; `4x4/EPISTEMIC.md:58`; `open-hypotheses:289`
- **depends on:** `e:GLOBAL.E2-POLICY`, `e:GLOBAL.E2-SANITY`

### G33 — `3x3.E2-RUN2`  ·  status **MEASUREMENT**

- **goban:** 3×3
- **claim as registered:** E2 run 2 (B06 re-run). Range-aware self-play at 3×3 leaked 50 of 8,000
  games = 0.625%; worst leak 12 pts. An independent replication of run 1, not a double-count
  (D-1). Kept separate to preserve the replication. **No run log is committed** — the 8,000-game
  output exists nowhere in git.
- **evidence cited:** `PROGRESS.md:128`; the D-1 ruling (§6-D1)
- **depends on:** `e:GLOBAL.E2-POLICY`, `e:GLOBAL.E2-SANITY`

### G34 — `2x2.T12`  ·  status **MEASUREMENT**

- **goban:** 2×2
- **claim as registered:** C2-pilot at 2×2 is tautological — 2×2 admits no reachable non-root
  cycles
- **evidence cited:** `4x4/EPISTEMIC.md:255-257,287-288`
- **depends on:** `e:2x2.EXACT`

### G35 — `WZO2.I2-CLEAN`  ·  status **MEASUREMENT**

- **goban:** 3×3, 4×4
- **claim as registered:** I2 colour-inversion holds exhaustively on both WZO2 artifacts
  (independent re-implementation, T270). 4×4: 0 violations / 0 not_found / 99,133,036 checked;
  3×3: 0 / 0 / 49,428. Confirms T212's A3 with a fully independent instrument per rule R8.
  Calibration reading: I2 is blind to the passes=1 asymmetry; must never be cited as covering the
  completeness defect class.
- **evidence cited:** `docs/evidence/BATTERY/i2-wzo2-T270.md`;
  `docs/evidence/BATTERY/i2-wzo2-T270/3x3-raw.json`;
  `docs/evidence/BATTERY/i2-wzo2-T270/4x4-raw.json`; `findings/T270-i2-wzo2.json`
- **depends on:** `e:SPRINT-M4a-ACCEPT` (re-derived independently), `d:GLOBAL.INVSYM`

## Tier B load-bearing proofs (PROVEN, >=1 dependent)

### G36 — `CODE.ACCEPT-KOKEY`  ·  status **PROVEN (source comparison + checker's own refusal output + one end-to-end trace, confirmed by T277)**

- **goban:** n/a
- **claim as registered:** `src/oracle_v2_accept.zig:150-165` carries a second, unfixed copy of
  the pre-T265 ko rule (T266), and that — not artifact coverage — is what fails A1/A2/A8. Its
  `koAfterCapture` sets a ko point on any single-stone capture; the solver and post-T265
  `gtp.zig` set one only when the capturing stone is in atari with no friendly neighbour. All ten
  sampled A1 refusals are at passes=0 with a non-none ko. Fourth member of the producer/consumer
  key-disagreement family after T178, T193, T265. Fix scope T273.
- **evidence cited:** `docs/evidence/ORACLE-V2/incompleteness-T266.md`;
  `docs/evidence/ORACLE-V2/incompleteness-verify-T277.md`; `findings/T266-incompleteness.json`
- **depends on:** — (root claim: source-level finding verified by direct comparison)

### G37 — `CODE.ADR0011-FMT`  ·  status **PROVEN**

- **goban:** all
- **claim as registered:** WZO1 = 32-byte header + six frozen columns `vb|vw|fb|fw|db|dw`; the
  reader REFUSES on any header mismatch; no `lo`/`hi` bracket columns exist
- **evidence cited:** `0011:21-37`; `corrections:153-158`; `src/artifact.zig:23-53`
- **depends on:** `d:GLOBAL.S1`

### G38 — `CODE.CLAIMLINT-C7-NEWROWS`  ·  status **PROVEN (A/B experiment on four-row findings file + source read)**

- **goban:** n/a
- **claim as registered:** Claimlint's C7 reads only the FIRST `new_rows` entry per findings file
  and mis-parses its status (T266). (1) Truncation: the brace scanner breaks out of `new_rows`
  after the first row object closes (`src/claimlint.zig:1676`). Proved by A/B. (2) Status
  mis-parse: after matching `status`, the skip set omits `'"'`, so every proposed status reads as
  `: `. C7's count is a floor, not a census. Fix scope T269.
- **evidence cited:** `docs/evidence/ORACLE-V2/incompleteness-T266.md`;
  `findings/T266-incompleteness.json`
- **depends on:** —

### G39 — `CODE.VB-STUBS`  ·  status **PROVEN (by inspection)**

- **goban:** n/a
- **claim as registered:** The verify-battery harness is not wired to any invariant module and
  has produced zero real verification runs. Every invariant routes through `stubCheck()`
  returning skipped/not-applicable; I11 and I8 are permanent `not_applicable` stubs; the
  JSON-Lines writer is hand-rolled without string escaping; none of the 36 declared tests run
  under `zig build test`; the 4×4 must-fail test reads git-ignored `data/` and silently no-ops on
  a clean clone.
- **evidence cited:** `src/verify_battery.zig:26-27,357-373`; `src/vb_fixpoint.zig:502-547`;
  `docs/epics/E1-markovian/sprints/verify-battery/archive/T168-notes.md`
- **depends on:** —

### G40 — `GLOBAL.ADR0003-AREA`  ·  status **PROVEN**

- **goban:** all
- **claim as registered:** Area score is a pure function of the terminal snapshot;
  Japanese/territory score is path-dependent and NOT recoverable from a snapshot
- **evidence cited:** `0003:13-16,21-24`
- **depends on:** —

### G41 — `GLOBAL.ADR0009-HONESTY`  ·  status **PROVEN (as a statement about the argument)**

- **goban:** all
- **claim as registered:** The certification argument has one unproven step (the memoryless-
  strategy leak); `L ≤ fresh-start ≤ H` and `L==H ⇒ exact` are strong structural evidence, not a
  theorem
- **evidence cited:** `0009:78-89`
- **depends on:** —

### G42 — `GLOBAL.FP1`  ·  status **PROVEN (as mathematics)**

- **goban:** all
- **claim as registered:** L is the least and H the greatest fixpoint of the Bellman map
  (Knaster–Tarski, monotone map, seeded from −N/+N)
- **evidence cited:** `CONCEPTS.md:25-30`; `0009:53-61`; `docs/evidence/GLOBAL-FP1/proof-2026-07-30.md`
- **depends on:** `d:GLOBAL.FP3`

### G43 — `GLOBAL.FP3`  ·  status **PROVEN**

- **goban:** all
- **claim as registered:** Bellman iteration terminates in finitely many sweeps (monotone map on
  a finite lattice)
- **evidence cited:** `CONCEPTS.md:43-46`; `4x3/EPISTEMIC.md:31`
- **depends on:** —

## Tier C falsifications (FALSE*, >=1 dependent)

### G44 — `GLOBAL.H1-COMPUTABLE`  ·  status **FALSE-AS-SCOPED**

- **goban:** all
- **claim as registered:** The computational half of the former conjoined `GLOBAL.H1`: a table
  over `(position, side, ko_point)` under simple ko + long-cycle-ties would be chainable by
  construction. FALSE-AS-SCOPED (3×2): the existing converge machinery with a pointwise tie-pin
  does NOT compute the history-conditioned value; C1 falsified under ADR-0019 truncation
  semantics. Whether ANY pointwise function of (L,TIE,H) can compute the value is open.
- **evidence cited:** `docs/evidence/QA-023/probe-fix-2026-07-29.md`;
  `docs/audits/2026-07-29-2b-6-full-review.md`;
  `docs/epistemic/qa023-c2-adjudication-2026-07-29.md`;
  `docs/audits/2026-07-29-qa023-kernel-audit.md`;
  `docs/evidence/QA-023/pinrule-sufficiency-2026-07-29.md`
- **depends on:** `d:GLOBAL.LONGCYCLE`

### G45 — `QA-026`  ·  status **FALSE-AS-SCOPED**

- **goban:** all
- **claim as registered:** The existing L/H `converge` machinery is directly reusable under a
  fixed-value cycle rule, with loops pinned by `V = median(L, T, H)`. FALSIFIED at 3x2
  (2B-PROBE-FIX, confirmed by 2B-6): six states — all White-to-move, passes=1, no ko — where
  median(L,TIE,H) pins TIE=0 while the history-conditioned value is the pass-out area_score.
  proof-v2 Thm 5.1 is FALSE as stated. (Row also carries the corrected-kernel census narrative and
  the C1 witness (178,0,6,0).)
- **evidence cited:** `docs/evidence/QA-023/probe-fix-2026-07-29.md`;
  `docs/audits/2026-07-29-2b-6-full-review.md`;
  `docs/epistemic/qa023-c2-adjudication-2026-07-29.md`; `roadmap-2026-07-28.md:305`;
  `docs/research/f2-remedy-design-2026-07-29.md`; `docs/evidence/QA-023/proof-v2-2026-07-28.md`
- **depends on:** `d:QA-023`, `d:GLOBAL.LONGCYCLE`, `e:docs/evidence/QA-023/proof-v2-2026-07-28.md`

### G46 — `QA-027`  ·  status **FALSE-AS-SCOPED (at 4×4; 3×3 measured 100.00%)**

- **goban:** all
- **claim as registered:** Under a Markovian rule the certified fraction is 100% by construction.
  FALSIFIED at 4×4 (EXP-7 re-run): certified fraction = 10.71% (3,000/28,000); the pinned
  V = median(L,TIE,H) does not distribute over best_child at bracket-valued states; the empty-
  goban root [L=+1, H=+16] violates directly (stored V=+1 vs best_child=+16). At 3×3 the root is
  single-valued and the measured fraction is 100.00%. This falsifies the V-derivation, NOT QA-023
  state-sufficiency.
- **evidence cited:** `roadmap-2026-07-28.md:306`;
  `docs/research/newrule-certified-fraction-4x4-2026-07-31.md`;
  `docs/evidence/QA-027/4x4/PROVENANCE.md`
- **depends on:** `d:QA-023`

### G47 — `GLOBAL.ADR0005-CACHE`  ·  status **FALSE-AS-SCOPED**

- **goban:** all
- **claim as registered:** Cacheability "theorem": a node at ply `d` is cacheable iff `ko_ref ≥ d`
- **evidence cited:** `0005:90-93`; downgraded `0008:32-38`; falsified `0013:20-44`
- **depends on:** —

### G48 — `GLOBAL.FP2-bounded`  ·  status **FALSE-AS-SCOPED (at 3×2)**

- **goban:** all
- **claim as registered:** History-independence under a finite, well-specified set of ban sets
- **evidence cited:** `CONCEPTS.md:33-37`
- **depends on:** `d:GLOBAL.FP2`

### G49 — `GLOBAL.LONGCYCLE`  ·  status **FALSE-AS-SCOPED**

- **goban:** all
- **claim as registered:** "Long cycle = tie" is a loopy-game fixpoint computable by the existing
  converge machinery — UNVERIFIED and must not be asserted. FALSIFIED at 3x2 (2B-PROBE-FIX +
  2B-6): the existing converge machinery with a pointwise tie-pin does NOT compute the
  history-conditioned value. Whether ANY pointwise function of (L,TIE,H) can is open. (Row also
  carries the corrected-kernel census narrative and the C1 witness (178,0,6,0).)
- **evidence cited:** `docs/evidence/QA-023/probe-fix-2026-07-29.md`;
  `docs/audits/2026-07-29-2b-6-full-review.md`;
  `docs/epistemic/qa023-c2-adjudication-2026-07-29.md`; `open-hypotheses:92-103`
- **depends on:** — (re-pointed 2026-08-06 T373: `d:GLOBAL.R2` left the register with the triage)

### G50 — `GLOBAL.P3`  ·  status **FALSE-AS-SCOPED**

- **goban:** all
- **claim as registered:** The fresh-start player plays the real-game score
- **evidence cited:** `CONCEPTS.md:125`; `4x4/EPISTEMIC.md:25`
- **depends on:** `d:GLOBAL.C4`, `e:GLOBAL.LEAK`

---

# The adversarial brief — what the lanes are told

*(This section is the lane brief, identical for all five lanes except the lane's own findings
path. It is the ONLY thing that differs from batch 1.)*

**Race G lane — the claim-doubt campaign, batch 2 (adversarial arm).** This is real epistemic
work: your verdicts feed epic-01. The measurement rides as exhaust, and you should ignore it —
write the best verdicts you can and the race takes care of itself.

## The premise — assume nothing has been checked since it was written

The Direction presumes this register is in worse shape than it looks. Rows were written by
people with a stake in the answer, and many have not been re-read since the day they were
written. **Approach every row assuming it has NOT been checked at HEAD**, and treat "the row
says so" or "the document it cites says so" as no evidence at all — the register is a record of
what somebody once believed, not what holds now. A `PROVEN` row is a claim that somebody once
had evidence for; whether that evidence still exists, still runs, and still says what the row
says is the open question.

**Your job is to find what does not hold at HEAD** — the stale justification, the citation that
no longer resolves, the number that no longer reproduces, the proof that was never re-derived,
the clause that a later experiment quietly overtook. A verdict of "holds" is earned only by
*failing to break the row after trying*; it is not the default. Where a row does hold, say so
plainly — a row that survives genuine attack is the strongest thing this register has.

This batch contains blind positives: rows that are genuinely defective at HEAD. **If you report
every row "holds", you are wrong, and the grading will know.** The only way to be right is to
attack each row and let the ones that break, break.

## Your target set — fixed, and it is your denominator

This file enumerates exactly **25 claims, G26–G50**, sealed before dispatch. Rule on **every
one**. Coverage is measured against this list: ruling on 20 of 25 is 20/25 no matter how good
the 20 are. Do not add claims; if you find one that should have been in the batch, that is a
finding for batch 3, recorded and not acted on.

## What a verdict costs — two fields per row, both mandatory

For each of G26–G50, return **two** verdicts, not one. Batch 1 ran one field and five lanes read
the same row four different ways; this closes that.

1. **`status_correct`** — is the row's **headline status** (PROVEN / CLAIMED / FALSE-AS-SCOPED /
   FALSE / UNTESTED / MEASUREMENT / INTRACTABLE) the right one for the claim as scoped? `yes` /
   `no` / `unknown`.
2. **`rationale_fresh`** — is the row's **rationale fresh at HEAD** — does every load-bearing
   clause it asserts still hold, does every citation it leans on still resolve, and does its
   evidence column actually carry the evidence its own prose describes? `yes` / `no` / `unknown`.

Both fields are mandatory per row. A row can be `status_correct: yes, rationale_fresh: no` — the
status is right while the reason is obsolete — and that is exactly the answer batch 1 could not
express. **`unknown` means you could not settle that field at HEAD, not that you did not try.**
When a field is `unknown`, say *which* — missing evidence, an instrument that no longer runs, or
out of scope for this lane — and still give the other field if you can. A lane that can tell the
rationale cites a file that no longer exists has a real `rationale_fresh: no` even when it cannot
settle `status_correct`.

Where a field is `no` or `unknown`, also record **`status_should_be`** (what the register row
ought to read) and whether your finding **cascades**: the row lists its dependents, and a broken
claim with five dependents is a much larger event than one with none. You are not editing
`CLAIMS.md`; that promotion is the operator's call on the graded result.

**Keying — every verdict entry MUST carry BOTH the `G26`…`G50` label AND the claim ID** (the
backtick-quoted ID, e.g. `4x4.C1`), as separate fields. Batch 1 lost data when lanes split
between two keying schemes and a join turned real agreement into phantom absence. **Again: every
entry carries the G-label AND the claim ID. Do not use one as a substitute for the other.**

## Bars

- **Work the batch in the order given.** If the wall stops you, a prefix of well-evidenced
  verdicts is worth far more than 25 shallow ones, and the ordering is by cascade risk so the
  prefix is the valuable half. **Write your findings file incrementally** — flush after each
  claim, do not hold everything to the end. A lane killed at claim 19 should leave 18 verdicts on
  disk, not zero.
- **Do not trust a green.** Where a claim asserts a count, a closure, or a coverage figure,
  re-derive it rather than reading the number off the document that claims it. Where you run an
  instrument, say whether it has a null control and whether you ran it. **Citing the same
  document the claim already cites proves nothing** — the register says what the documents say;
  you are checking whether the *world* agrees.
- **Do not repair anything.** Finding a defect does not license fixing the code, the register, or
  the document. Report; another row repairs. Read-only outside your findings file.
- **No builds or suites while the fleet is hot** unless the claim genuinely requires one; prefer
  a targeted `zig test` on a single file to `zig build test`. Say what you ran.
- Independent work only. Do not read other lanes' findings; this race is scored on what your seat
  catches that others miss, so consulting them destroys the measurement and your own value. Do
  not read batch 1's target set, lane findings, or grades.

Write `findings/<YOUR-TASKID>-race-g.json`: the standard envelope plus a `"verdicts"` array of
25 entries keyed `G26`…`G50`, each with `claim_id` (the backtick-quoted register ID), `G_label`,
`status_correct`, `rationale_fresh`, `status_should_be`, `cascades` (the dependents affected),
`citation` or `reproduction` (a file:line, or a command and its actual output pasted in — a
verdict whose citation a reader cannot check without you does not count), and one line of `why`.
Flush the file after every claim.
