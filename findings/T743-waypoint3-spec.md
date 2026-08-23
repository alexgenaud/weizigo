# T743 — Waypoint 3 (A–Z reverification): decomposition spec

```
Task:   T743 · Role: leaf lane, Race I (waypoint-3 spec lane) · Model: deepseek-v4-flash
Date:   2026-08-23 · Bundle: untracked/T743-race-i-waypoint3-dsflash.md
Brief:  untracked/race-i-waypoint3-brief.md (shared, five lanes)
Inputs: docs/audits/2026-08-02-grand-audit/DIRECTION.md (ratified program, Waypoints 0–4,
        Amendments 1–2) · docs/epics/E1-markovian/PHASES.md · docs/epistemic/CLAIMS.md ·
        docs/epics/E1-markovian/register-tree-map.md · docs/infra/GLOSSARY.md ·
        docs/infra/instrument-coverage.md (T388) · docs/epics/E1-markovian/sprints/verify-battery/
        pass1/{spec,mutants,baselines}.md · docs/epics/E1-markovian/AXIOMS.md ·
        docs/audits/2026-08-19-g3b-second-audit/VERDICT.md · docs/status/ROADMAP-2026-08-20.md ·
        docs/infra/tool-consolidation/02-scope-audit.md (T433) · bin/weizigo-claimlint (HEAD 3ce328e)
Deliverable: this file only. No kanban rows registered (a proposal; the seat synthesizes, the
        operator ratifies). No other lane's findings/T74*-waypoint3-spec.md was read.
```

**Landmark:** advances `L2 (proven 4×4 values)` — Waypoint 3 is the L2 critical path: it turns
the CLAIMED 4×4 value-correctness stack into PROVEN-by-re-derivation, or honestly demotes it.
What is now visible: a registerable, poppable, conflict-free row set that a seat can dispatch
tomorrow. What remains: the operator's ratification, then execution.

---

## 0. What Waypoint 3 is, and the shape of this decomposition

**Waypoint 3** (DIRECTION §5 Phase 3; the ratified rename from "Phase" to "Waypoint" is in
flight) is the A-to-Z reverification program: *every register row re-derived, demoted, or
retired against the requirement tree, with the extracted kernel as the oracle and the battery
as the instrument, laddered 2×2 → 3×2 → 3×3 → 4×4, kernel vs fixtures differentially at every
rung* (DIRECTION §5; Amendment 2 dependency edges). It has never been decomposed.

**Three facts bound the design:**

1. **The register is 231 rows** (`weizigo-claimlint` C0 at HEAD `3ce328e`, 2026-08-23:
   `rows parsed: 231`, 240 edges — 107 `d:` / 118 `e:` / 15 `n:`). The tree-map §1 table also
   holds 231 rows (225 mapped to a node + 3 `RETIRED`); only its §3 prose says 228 — stale
   prose, C9 passes (row-set equality), and the prose fix is a one-line cleanup in the finish
   gate. Row distribution by node (counted from the tree-map §1 table): Z-NONCLAIMS 43,
   Z-TABLE-FAITHFUL 33, Z-AUDIT 24, Z-R-SCORE 17, Z-CONVERGE-FIX 15, Z-TABLE 15, Z-R-MOVE 14,
   Z-R-TIE 12, Z-TABLE-CONSISTENCY 10, Z-CONVERGE-FINITE 7, Z-STATE-REACH 6, Z-STATE-LEGAL 6,
   Z-COMPLETE-ENUM 5, Z-STATE-KEY 4, Z-R-STATE 4, Z-CONVERGE-MONO 3, Z 3, Z-CONVERGE 2,
   Z-CONVERGE-SEED 1, Z-TABLE-ROUNDTRIP 1, Z-COMPLETE-PASSES 1, Z-R-SIGN 1, Z-SYM 1, RETIRED 3.
2. **The instruments already exist.** Waypoint 1 (battery I1–I12 + golden-master baselines +
   the ten-mutant catalogue) and Waypoint 2 (kernel `rules.zig` `koAfterCapture`/`stateKey` +
   the differentials) are delivered. Waypoint 3 is mostly *reuse + adjudicate*, not build:
   re-run the battery and the differentials against the kernel at each rung, then rule on every
   row mapped to each node. New instrument work is confined to the six tree gaps
   (register-tree-map §5): Z-R joint well-definedness, adversarial key agreement, seeding
   provenance ≤3×3, the Z-R-TIE Markovian-sufficiency contrast, 4×4 closure (partially closed
   by T383/T363 — re-verify), and the #2 auditor on a k=1 4×4 build.
3. **Promotion is gated on mutation adequacy, not on re-derivation alone** (Amendment 2 edge 5:
   no claim passes CLAIMED until the mutants covering its function are killed). The honest
   6/10 kill-verified rate (T475, ratified by the 2026-08-19 G3b second audit) closes **seven
   promotion gates** — every CLAIMED row held back by edge 5. The mutation gate therefore sits
   **first** in this row set: it is the currency the whole program spends.

**Decomposition principle.** Rows are **family-major** (one row per claim family/tree-node
group, per the brief's batching encouragement — one instrument covers many rows), with the
ladder sequenced *inside* each family row (rungs 1→5 = 2×2, 3×2, 3×3, 4×3, 4×4; the g3b
ladder, `g3b-value-correctness/pass0/spec.md` §7 — 4×3 is included because artifacts and
mapped rows exist for it, even though Z's goban set is {2×2, 3×2, 3×3, 4×4}). Per-goban
epistemic independence (AGENTS.md; ADR-0016) is enforced per rung: each rung's readings and
verdicts are recorded separately and no rung's verdict licenses another's.

**Conventions every row inherits (stated once here):**

- **Register edits go through findings files, never direct.** Each row proposes status changes
  in `findings/<taskid>-<slug>.json` per `findings/README.md` (claims[] + new_rows[] schema);
  STANDING-ABSORB applies them. No row holds `docs/epistemic/CLAIMS.md`; the absorption pass
  is the single writer. Tier-A status changes (→ PROVEN / → FALSE-AS-SCOPED / new or retired
  rows) require the C11 auditor attestation field (`audited_by`) per the 2026-08-19 D2 ruling.
- **Evidence under `docs/evidence/WAYPOINT3/<family>/`, committed before the row closes.**
  No `/tmp` citations (claimlint C10; the T13/T02/T07 lesson).
- **Every instrument run carries its null control and seeded-defect control**, recorded in the
  row's readings JSONL with red-then-green evidence paths. §3 is the consolidated control map.
- **The ladder deliverable is a verdict ledger**, one entry per register row mapped to the
  family's nodes, in `docs/evidence/WAYPOINT3/verdict-ledger.json` — machine-checked by the
  finish gate (W3-16). Worked example of a ledger entry:

  ```json
  {"row": "2x2.BASICKO-TIE", "node": "Z-TABLE", "verdict": "re-derived",
   "status_before": "MEASUREMENT", "status_after": "MEASUREMENT",
   "rungs": ["1"], "instruments": ["I4@2x2", "I2@2x2", "kernel-exact-solver"],
   "reading": "root 0, bracket [-4,+4], 4 sweeps, Bellman 0/28, inversion 0/2430",
   "controls": {"null": "T102 Python re-run", "seeded": "QA-026 calibration-2x2-mismatch.py"},
   "evidence": ["docs/evidence/WAYPOINT3/w3-09/rung1/readings.jsonl"], "date": "2026-08-23"}
  ```

  Verdicts: `re-derived` (status confirmed or upgraded, with the run), `demoted` (status
  lowered, reason named), `retired` (row serves no tree node; requires the human's retirement
  ruling, recorded — the 3 `RETIRED` rows and the 132 archived rows are the standing examples,
  T373).

- **Title discipline:** each proposed title is ≤ 40 chars. Proposed IDs are W3-NN; the seat
  assigns real T-IDs at registration. Holds follow one-writer-per-file; conflict-free means
  two rows never hold the same file.

---

## 1. The row set (16 rows, in dispatch order)

### P-rows — Waypoint-2 debt closure (first; they are the currency)

#### W3-01 — "Mutation gate: fixture M1/M2/M4, kill M3"

- **Why it is first:** Amendment 2 edge 5 makes mutation adequacy the promotion currency. At
  the honest 6/10 (T475; VERDICT.md N3 — M5/M6/M7/M8/M9/M10 killed; **M3 survives** — I5 is
  vacuous at 2×2; **M1/M2/M4 have no per-mutant fixtures**), the following rows sit at CLAIMED
  on exactly this gate: `4x4.C1`, `4x4.FP1`, `GLOBAL.H4`, `GLOBAL.I5-SCC-CONTAIN`,
  `4x4.WZO2-A2/A5/A8-EXHAUSTIVE`, `CODE.WZO2-BUILD-REPRO`, `CODE.KEY-AGREEMENT`, the T273
  kernel claims (`GLOBAL.AXIOM-BASICKO`, `GLOBAL.AXIOM-KOSTATE`, `GLOBAL.AXIOM-STATE`),
  `GLOBAL.Z-R-MOVE-B1-EQUIV`. Every ladder row below wants to promote some of these; none can
  until this row lands.
- **Deliverables:** (a) `kill-matrix.json` reconciled to 10/10 — total_mutants=10,
  mutants_killed=10 — with each mutant's named killer (the test that fails red on the mutant
  and passes green on the fix); (b) `vb_mutants.zig` extended with the missing fixtures: M1
  (colex-vs-rank, one side at wrong indices — attacks `stateKey`), M2 (passes bit dropped —
  attacks `stateKey`), M4 (second ko copy in the acceptance harness — attacks
  `koAfterCapture`); (c) M3 killed by routing its check to a non-vacuous rung (I5 at 3×2,
  where KO_SENSITIVE is non-empty: 378 ko-sensitive slots) or by a direct `koAfterCapture`
  differential, per the mutation-testing doctrine (DeMillo–Lipton–Sayward 1978) — never by
  deleting the mutant.
- **Holds:** `src/vb_mutants.zig`, `docs/epics/E1-markovian/sprints/verify-battery/pass1/kill-matrix.json`.
- **Needs:** none (inputs: T475 reconciliation, VERDICT.md N3, mutants.md). **Needed by:** every
  row that promotes past CLAIMED (W3-03, W3-06…W3-13, W3-16).
- **Acceptance:** kill-matrix.json at 10/10, each kill red-then-green evidenced in
  `findings/<tid>-mutation-gate.json`; `zig build test` green; claimlint floor not regressed
  (C1a=0, C1b=0, C2≤13, C6=0). If the operator instead re-rules the gate threshold
  (ROADMAP §3.2), the row still delivers the fixtures so the re-ruling has the evidence in
  view — the re-ruling itself is a ratification, not this row's work.
- **Size:** 2–4 worker-days (all small gobans; no 4×4 compute).

#### W3-02 — "Close phantom T430 phase-2 bundle row"

- **Why here:** the `--bundle [set S]` row is *dispatchable* and its bundle
  `untracked/T430-phase2-audit.md` **does not exist on disk** (verified 2026-08-19 in
  `docs/status/backlog-2026-08-19.md:55`; re-verified today: only
  `T430-doctor-console-permanently-green.md` and `T433-phase2-audit.md` exist). A dispatchable
  row whose brief is absent is a trap — a worker dispatched to it reads a non-file and fails
  or, worse, improvises. The phase-2 audit content was delivered under T433
  (`docs/infra/tool-consolidation/02-scope-audit.md`, verdict pass-with-findings, F-a..F-f;
  F3–F5 line citations still wrong). Close the phantom row with evidence; carry the residue.
- **Deliverables:** (a) the `--bundle [set S]` row closed (done with evidence, or purged) so
  it no longer appears dispatchable in `bin/managent status`; (b) T433's residual findings
  (F3–F5 line-citation errors, the unproduced accept.md) recorded in the tool-consolidation
  backlog or a new closure note; (c) the register-count prose drift fixed: `register-tree-map.md`
  §3's "228" rows → the claimlint-printed 231 (C9 row-set equality already passes; prose only).
- **Holds:** none (kanban row + backlog note; no source files).
- **Needs:** none. **Needed by:** the finish gate's queue-hygiene check.
- **Acceptance:** `bin/managent status` shows no dispatchable row whose bundle is absent;
  T433 residue is on disk under the consolidation docs; the tree-map §3 prose and claimlint C0
  agree on 231.
- **Size:** 0.5–1 worker-day.

### I-rows — new instruments (the six tree gaps' build work; land before their consumers)

#### W3-03 — "Adversarial key agreement (4-component)"

- **Closes tree gap #2.** `CODE.KEY-AGREEMENT`'s own caveat: self-play with a first-legal-move
  policy under-covers cycle-intensive ko positions; full four-component key parity (colex,
  side, ko, passes, terminal bit) under *adversarial* move selection is unverified. The
  T178/T193/T265 family is the project's most expensive defect class and its check is still
  game-sampled.
- **Deliverables:** a key-agreement harness (`src/w3_keyadv.zig`) that drives the
  producer/consumer key pair through cycle-intensive regions — ko fights, pass fights,
  approach-move loops, the 3×2 T13 witness family — at every rung, and asserts full key
  parity against the kernel `rules.zig` `stateKey`. Verdict ledger for the Z-STATE-KEY-mapped
  rows (`CODE.KEY-AGREEMENT`, `CODE.ACCEPT-KOKEY`, `CODE.GTP-KOKEY`, `CODE.WZO2-PASSBIT`, the
  keybyte rows).
- **Controls:** null = reproduce the T267/T345 pass (0 mismatches on the existing
  game-sampled sequences, including T345's table-exhaustive 4×4 run); seeded = re-introduce
  each of the three historical key defects through a default-off mutation knob (ko too broad;
  passes bit dropped; colex-vs-rank) and observe ≥1 disagreement with the defect's historical
  fingerprint, then green without it.
- **Holds:** `src/w3_keyadv.zig` (new file; if instead it extends `src/differential.zig`,
  declare the hold and clear it on close — T531 already holds the differential file family).
- **Needs:** none hard (kernel exists); promotion of `CODE.KEY-AGREEMENT` past CLAIMED needs
  W3-01. **Needed by:** W3-06 (Z-STATE rungs).
- **Acceptance:** 0 mismatches under adversarial selection at all rungs; all three seeded
  defects each fire ≥1 disagreement; controls red-then-green evidenced; key rows re-adjudicated.
- **Size:** 3–5 worker-days.

#### W3-04 — "Ruleset well-definedness check (Z-R)"

- **Closes tree gap #1.** No row asserts the axioms *collectively* define a self-consistent,
  computable ruleset. Its [F] — a position where two interpretations of the axioms disagree on
  legality — is mechanized nowhere; the seventeen-copy comparison AXIOMS §2 promises is not
  what T273 delivered (phase0-execution-audit F4).
- **Deliverables:** an instrument (`src/w3_rjoint.zig`) comparing two independent readings of
  the AXIOMS text — the kernel `rules.zig` and a from-the-text re-implementation (R8 style,
  no `src/` imports) — over the full legal-move predicate: legality, capture, suicide,
  ko-after-capture, pass/forced-pass, at every rung (exhaustive ≤3×2, sampled with stated
  denominators at 3×3+). Also runs the frozen legacy copies (the ~14 divergent ko rules,
  demoted fixtures per DIRECTION §4) through the same comparison — every disagreement between
  kernel and fixture is a finding to adjudicate (kernel bug vs fixture bug). Verdict ledger for
  the Z-R-mapped rows it touches (the A/B-axiom rows).
- **Controls:** null = the two clean readings agree at every position at 2×2/3×2 (exhaustive)
  and on the sampled 3×3+ positions; seeded = plant a divergence in one reading (suicide-before-
  vs-after-capture; ko-ply count one vs two) and the check must fire; legacy-copy runs are the
  known-bad family (each must produce a disagreement or a written adjudication of why not).
- **Holds:** `src/w3_rjoint.zig` (new file).
- **Needs:** none. **Needed by:** W3-12 (Z-R rungs).
- **Acceptance:** 0 disagreements on the clean runs at all rungs; every seeded and legacy-copy
  run fires or carries a written adjudication; the [F]-search denominators stated.
- **Size:** 4–6 worker-days.

#### W3-05 — "Independent terminal scorer (Z-R-SCORE)"

- **Closes the battery's thinnest node.** The pass1 spec (§2) is explicit: I12 bounds values
  in [−area, +area] but does not verify terminal scores are correct per C2; the suggested check
  — compute area_score independently at every terminal and compare with the table's terminal
  values — was never built.
- **Deliverables:** an independent scorer (`src/w3_scorer.zig`) implementing C2's Tromp-Taylor
  as-stands statement (AXIOMS §2, Amendment 4) from the text — no `src/` imports — computing
  the terminal score at every terminal state at every rung and comparing against (a) the
  table's terminal values and (b) `rules.zig`'s scorer. Verdict ledger for the Z-R-SCORE-mapped
  rows (S2/S2-impl, S4, `GLOBAL.ADR0003-AREA`, `GLOBAL.ADR0004-TERM`,
  `GLOBAL.ADR0005-DBLPASS`, `GLOBAL.AXIOM-AREA/TERMINAL/SCORESIGN`, `GLOBAL.S4`, `CODE.S4-XVAL`).
- **Controls:** null = agreement on exhaustive small-rung terminals and random 3×3+ positions;
  seeded = plant a scoring defect (off-by-one territory count; a colour-asymmetric count;
  removal-at-terminal instead of as-stands) and observe red.
- **Holds:** `src/w3_scorer.zig` (new file).
- **Needs:** none. **Needed by:** W3-12 (Z-R rungs).
- **Acceptance:** 0 disagreements on the clean runs at all rungs; each seeded defect fires;
  the S2/S4 rows re-adjudicated (e.g. `4x4.S2-impl` and `4x4.S4` — currently UNTESTED — get a
  verdict or an honest stay).
- **Size:** 3–5 worker-days.

### L-rows — the reverification proper (family-major, ladder-sequenced inside)

#### W3-06 — "Z-STATE rungs: legality, reach, key"

- **Covers:** Z-STATE-LEGAL (6 rows), Z-STATE-REACH (6), Z-STATE-KEY (4), Z-COMPLETE-ENUM
  (5: `GLOBAL.ADR0009-NOEYE`, `GLOBAL.ADR0007-TENSION`, `CODE.WZO2-INCOMPLETE`,
  `WZO2-4X4-VALID`, `4x4.G-CENSUS`), Z-COMPLETE-PASSES (1: `CODE.WZO2-PASS1-LAW`) — the
  state-space and completeness family: `GLOBAL.S1`, `4x4.S1`, `4x3.S1`, `GLOBAL.S3a`,
  `4x4.S3a`, `4x3.S3a`, `GLOBAL.H1-CENSUS`,
  `3x3.H1-CENSUS`, `4x3.H1-CENSUS`, `4x4.G-CENSUS`, `4x4.I5-FEAS`, `GLOBAL.I5-SCC-CONTAIN`,
  `GLOBAL.PASS-NOKO`, `GLOBAL.REACH-P4-CENSUS`, `CODE.KEY-AGREEMENT`, `CODE.ACCEPT-KOKEY`,
  `CODE.GTP-KOKEY`, `CODE.WZO2-PASSBIT`, and the closure rows.
- **Deliverables, per rung 1→5:** (a) I6 legal-position census vs OEIS/ground truth
  (57 / 489 / 12,675 / 321,689 / 24,318,165); (b) reachable-triple counts re-derived via the
  kernel (258 / 2,586 / 73,758 / 1,929,038 / 147,638,298, `GLOBAL.REACH-P4-CENSUS` T507 as
  reference); (c) C-A1/C-A2 closure (`vb_closure.zig`) at every rung — at 4×4 the full run with
  the **corrected** ko-decode (T383: C-A1 0/616,030,190, C-A2 0/99,133,034; the stale
  kb>>1 figures are superseded and must not be re-published); (d) key agreement via W3-03's
  harness. Verdict ledger for every row above, per rung (per-goban independence).
- **Controls:** I6's OEIS anchors are the known-good; a seeded census off-by-one is the
  known-bad; I5's calibrating pair (T391 third-route Python vs `vb_scc_4x4`; the historical
  fabricated-24 is the known-bad) reused as-is; closure's controls per `vb_closure.zig` tests.
- **Holds:** the family readings files + findings; no engine files (read-only consumers of the
  battery and the artifacts).
- **Needs:** W3-03 (adversarial key agreement); W3-01 for the promotion of
  `GLOBAL.I5-SCC-CONTAIN` / `CODE.KEY-AGREEMENT` past CLAIMED. **Needed by:** W3-16.
- **Acceptance:** every Z-STATE-mapped row has a verdict; the closure re-verification at 4×4
  restates the corrected-decode denominators; tree gap #5's "closure untested" language in
  `WZO2-4X4-VALID` is updated; controls fire per instrument; promotions meet edge 5.
- **Size:** 5–8 worker-days (4×4 compute is minutes, not hours: closure C-A1+C-A2 245.8 s wall at 1,124 MB RSS per T383; I5 149 s wall at 2,768 MB RSS per T344; the I5/closure/REACH re-runs are re-runnable under the runner).

#### W3-07 — "Z-CONVERGE-FIX: Bellman identity rungs"

- **Covers:** Z-CONVERGE-FIX (15 rows) + the fixpoint-falsification QA family: `GLOBAL.FP1`,
  `2x2.B1`, `3x2.B1`, `3x3.B1`, `4x4.FP1`, `4x4.FP1-C1/C2/C3`, `4x3.FP1`, `GLOBAL.B1-MULTIFIX`,
  `GLOBAL.B1-AUDIT`, `GLOBAL.H4`, `GLOBAL.H4a`, `GLOBAL.H4b`, `GLOBAL.ADR0020-LH-CORRECT`,
  `GLOBAL.ADR0020-VERIFY-PASS`, `QA-001`, `QA-021`, `QA-026`, `QA-027`, `4x4.WZO2-A2-EXHAUSTIVE`.
- **Deliverables, per rung:** I3 (L≤H), I4 (Bellman residual) via the size-appropriate
  instrument (general battery ≤4×3; `vb_bellman_4x4` / accept `checkA2` at 4×4 — the same
  kernel move engine per the coverage map), I5 SCC containment; the QA rows re-derived: QA-001
  (the refuted one-ply Bellman identity — 11,402/11,402 violations all KO_SENSITIVE), QA-021
  (exhaustive FP1-check-3), QA-026 (median falsification at 3×2), QA-027 (V-derivation
  falsified at 4×4, 3×3 measured 100.00%). Verdict ledger for the rows above; the
  fixpoint-vs-truncation I8 fixture re-confirmed at 2×2.
- **Controls:** I4's known-good = the ADR-0020 independent Python re-run at 2×2; known-bad =
  the v1 basic-ko artifact's I2 failure (T260, 48%) and the T309/T363 exhaustive runs as
  golden-master baselines (unchanged, never "fails"); the battery's seeded mutants M5/M6/M8
  (I2/I7/closure) reused as-is.
- **Holds:** family readings + findings; no engine files.
- **Needs:** W3-01 (promotion of `4x4.FP1`, `GLOBAL.H4`, `4x4.WZO2-A2-EXHAUSTIVE` past
  CLAIMED). **Needed by:** W3-16.
- **Acceptance:** Bellman residual 0 at every rung with stated denominators; the QA rows
  re-adjudicated; every Z-CONVERGE-FIX row has a verdict; promotions meet edge 5.
- **Size:** 4–6 worker-days.

#### W3-08 — "Z-CONVERGE: seed, finite, monotone"

- **Covers:** Z-CONVERGE-SEED (1 row — `4x4.FP1-C1`), Z-CONVERGE-FINITE (7 —
  `GLOBAL.FP3`, `4x4.FP3`, `4x3.FP3`, `4x4.FP1-C2`, `4x4.M2`, `4x3.M2`,
  `GLOBAL.CAPTURE-BUDGET-DAG`), Z-CONVERGE-MONO (3 — `GLOBAL.FP1` proof, `GLOBAL.B1-AUDIT`,
  `GLOBAL.B1-MULTIFIX`), Z-CONVERGE (2 — `GLOBAL.AXIOM-BELLMAN` (E1 defines Φ),
  `GLOBAL.AXIOM-LH` (E2 fixpoint seeds)).
- **Deliverables:** **(a) seeding provenance at every rung — the cheapest gap in the tree**
  (gap #3): post-hoc reads of the build logs and provenance files showing the L-sweep seeded
  from −N and the H-sweep from +N, at 2×2/3×2/3×3 (only `4x4.FP1-C1` exists and it is
  UNTESTED; `GLOBAL.BATTERY-GAPS` G5 accepted it as a gap — now close it); **(b) finite-sweep
  records**: sweep counts (4 / 10 / 16 / 17 / 31) re-derived from build logs + the final
  zero-change sweeps (FP1-C2's two claims); **(c) monotonicity**: mathematical — accept via the
  committed FP1/FP3 proof (`docs/evidence/GLOBAL-FP3/…`), no new compute; state the acceptance
  as a reading with the proof path cited.
- **Controls:** seeding is a provenance read — the control is a seeded wrong-provenance
  mutant (a dry-run log claiming the build seeded from 0 instead of −N must be flagged);
  sweep counts: two independent readers of the same stdout (a grep and a human pass) recorded
  in the readings file.
- **Holds:** readings + findings.
- **Needs:** none. **Needed by:** W3-16.
- **Acceptance:** every size has a seeding-provenance record with its log cited; every size
  has a zero-change final-sweep record; MONO acceptance cites the proof; `4x4.FP1-C1`/`C2`
  re-adjudicated and promoted per edge 5.
- **Size:** 2–3 worker-days.

#### W3-09 — "Z-TABLE-FAITHFUL: C1/BASICKO/EXACT"

- **Covers:** the 33 Z-TABLE-FAITHFUL rows minus the 4×4-writes-off slice (owned by W3-10):
  `2x2.C1`, `3x2.C1`, `3x3.C1`, `4x4.C1` (rungs 1–4 slices; rung-5 gated on W3-10),
  `2x2.BASICKO-TIE`, `3x2.BASICKO-TIE`, `3x3.BASICKO-TIE`, `4x4.BASICKO-TIE`, `2x2.EXACT`,
  `3x2.EXACT`, `3x3.FWD-SPOT`, `2x2.F2`, `3x3.F2`, `3x2.F1`, `3x2.F3`, `3x2.F4`, `3x3.F4`,
  `4x3.F2`, `4x3.F4`, `4x4.F1`, `4x3.F1`,
  `4x4.F2/F3/F4` (read-only until W3-10), `GLOBAL.ADR0005-CACHE`, `GLOBAL.ADR0008-HOLE`,
  `GLOBAL.MEMO-XROOT`, `GLOBAL.F1`, `GLOBAL.F2-REMEDY`, `GLOBAL.MIGOS-RULE`,
  `GLOBAL.TIE-MIGOS`, `GLOBAL.FIXPOINT-VS-SEARCH`, `GLOBAL.ADR0010-SOUND`,
  `GLOBAL.ADR0015-BURDEN`, `4x4.WRITESOFF-DUP`, `QA-019`, `QA-025`, `GLOBAL.P1`, `4x4.D3`
  (read-only until W3-10).
- **Deliverables, per rung:** fresh-start correctness re-derived against the kernel-as-oracle
  plus the exact-solver fixtures (2×2/3×2 EXACT rows; the 3×3 forward spot-check); the
  BASICKO-TIE anchor values re-verified (2×2 root 0 bracket [−4,+4]; 3×2 root 0 [−6,+6];
  3×3 root +9 L==H; 4×4 root +1 bracket [+1,+16]) with the MIGOS external attestation
  re-stated per T274/T279 (MIGOS basic-ko 4×4 = +1 = ours; the +2 is a different game —
  pass-difference cycle resolution); the finisher family re-run: `3x2.F1` (writes-on, 45/378
  minimax-identity violations) and `3x2.F3` (writes-off, 0/378) — the auditor's
  known-bad/known-good pair — and the legacy artifacts still fail their finisher checks
  (regression, not new failure). Worked verdict example: `2x2.BASICKO-TIE` re-derived
  MEASUREMENT (I4 0/28, I2 0/2430, 4 sweeps, root 0 [−4,+4]); `4x4.C1` verdict "re-derived at
  rungs 1–4, rung-5 pending W3-10" (it stays CLAIMED until the writes-off regen + #2 auditor).
- **Controls:** the exact-solver fixtures are the independent re-implementations (null);
  `3x2.F1` vs `3x2.F3` is the auditor's calibrating pair; MIGOS anchors are external
  attestation only (never a `d:` parent — `GLOBAL.P1` is FALSE-AS-SCOPED).
- **Holds:** family readings + findings; no engine files.
- **Needs:** W3-10 for the rung-5 (4×4) slice — sequence rungs 1–4 first, then consume the
  regen; W3-01 for promotions. **Needed by:** W3-16.
- **Acceptance:** C1 rows re-derived with 0 mismatches and denominators; BASICKO-TIE anchors
  confirmed; the finisher pair re-measured (45/378 vs 0/378); every one of the 33 rows has a
  verdict; promotions meet edge 5.
- **Size:** 5–8 worker-days (excluding W3-10's compute).

#### W3-10 — "Writes-off 4×4 regen + #2 auditor"

- **Covers:** `4x4.D3` (writes-off tractability — UNTESTED, a measurement not a truth claim),
  `4x4.F2`, `4x4.F3`, `4x4.F4`, the Track A regen (`memo_writes=false`) that the AGENTS.md
  ko-sensitive foreclosure demands, and the #2 auditor on the completed regen. This is the
  largest single piece and the L2 critical path's last gate: the committed ko-sensitive
  values are unverified until Track A regenerates them and passes the #2 auditor, and
  `4x4.WRITESOFF-DUP` already cautions that the old "writes-off" checkpoint was byte-identical
  to the parallel checkpoint — the confound must not be repeated (the regen must vary only the
  writes flag, serial, and the provenance must say so).
- **Deliverables:** (a) the regen run under `tools/runner` (RSS ≤ 4 GB; a persistent session
  with heartbeat — the existing build took 3,789 s / 31 sweeps at 3.9 GB; never restart);
  (b) the D3 measurement: wall, RSS, sweep count, or an honest infeasibility record (D3 is a
  measurement — either outcome is a reading); (c) the #2 auditor (`RETRO_CONSIST` or the
  standing gate) on the regenerated artifact, 0 violations with denominators; (d) the WZO2
  acceptance A1–A9 on the new artifact; (e) the provenance note: which artifact is the ADR-0020
  pure loopy fixpoint (`data/oracle-4x4-v2.wzo2`), which checkpoint values stay untrusted
  (`data/oracle-4x4.checkpoint.wzo`), and the AGENTS.md foreclosure's discharge record.
- **Controls:** the auditor's known-bad = `3x2.F1`'s 45/378 on a writes-on build; known-good =
  `3x2.F3`'s 0/378; the regen's reproducibility = a byte-identical rebuild witness in the
  `CODE.WZO2-BUILD-REPRO` style; A6 calibration fixtures on the new artifact.
- **Holds:** the builder file (one writer — declare the hold on `src/oracle_v2_build.zig` or
  the Track A builder before starting, clear on close), the artifact path, findings.
- **Needs:** W3-01 (the auditor readings are gate readings; promoting `4x4.C1`/`4x4.F3` past
  CLAIMED needs the mutants). **Needed by:** W3-09 (rung-5 slice), W3-16.
- **Acceptance:** D3 measured with the runner's bounds; the writes-off artifact regenerated
  (or infeasibility documented with the measurement); #2 auditor 0 violations with
  denominators; A1–A9 pass; the ko-sensitive foreclosure's discharge note committed under
  `docs/evidence/WAYPOINT3/w3-10/`.
- **Size:** 5–10 worker-days, compute-bound. The row's brief must carry the runner and
  heartbeat discipline verbatim (docs/infra/runner.md).

#### W3-11 — "Z-TABLE consistency & round-trip rungs"

- **Covers:** Z-TABLE-CONSISTENCY (10: `CODE.ADR0011-GATE`, `GLOBAL.ADR0012-PAR`,
  `SPRINT-M4a-ACCEPT`, `WZO2.I2-CLEAN`, `4x4.V1-INVSYM-BROKEN`, `4x4.WZO2-A8-EXHAUSTIVE`,
  `CODE.WZO2-BUILD-REPRO`, `CODE.T312-PARALLEL-FIXPOINT`, `CODE.WZO2-RELEASESAFE-INV`,
  `CODE.PARALLEL-FIXPOINT-MEASURED`), Z-TABLE-ROUNDTRIP (1: `4x4.WZO2-A5-EXHAUSTIVE`), Z-SYM
  (1: `GLOBAL.INVSYM`), Z-TABLE (15: the bracket-semantics rows — `GLOBAL.AXIOM-BRACKET`,
  `GLOBAL.ADR0020-LH-CORRECT`, `QA-004`, `GLOBAL.PSK-GRAFT-COHERENT`, `GLOBAL.LIFE-CERTIFIES`,
  `GLOBAL.ROOT-SINGLE-IFF-FORCIBLE-LIFE`, `GLOBAL.DRAWLOOP-CONFINED`,
  `GLOBAL.NEITHER-FORCE-MOSTLY-DECISIVE`, `4x4.BRACKET-NOT-KO`, `3x3.BRACKET-NOT-KO`,
  `4x4.KO-CLUSTER-MAX-2`, `CODE.ADR0011-FMT`, `GLOBAL.ADR0005-DBLPASS`).
- **Deliverables, per rung:** A5 round-trip (exhaustive at 4×4, closing the stride-97 gap),
  A8 DTT consistency, A9 reproducibility, I2 colour inversion (Z-SYM — exhaustive, both WZO2
  artifacts), the INVSYM proof re-read, build-repro byte-identity, parallel-fixpoint
  byte-identity, the keybyte differential re-run, the ADR-0011 format/gate re-read. Verdict
  ledger for the rows above.
- **Controls:** A6 calibration fixtures (3 seeded corruptions — value→SHA, dropped ko state,
  zeroed DTT) are the seeded controls; the T292 golden-master baselines are the regression
  inputs (unchanged, never "fails"); the T260 independent Python inversion re-implementation
  is the I2 null; the T395 four seeded-defect knobs (red-then-green) reused as-is.
- **Holds:** family readings + findings; no engine files.
- **Needs:** W3-01 (promotion of `4x4.WZO2-A5/A8-EXHAUSTIVE`, `CODE.WZO2-BUILD-REPRO` past
  CLAIMED). **Needed by:** W3-16.
- **Acceptance:** every consistency/round-trip/symmetry row re-verified with its controls;
  the A5/A8 exhaustive denominators restated; promotions meet edge 5.
- **Size:** 3–5 worker-days.

#### W3-12 — "Z-R rungs: move, score, state, sign"

- **Covers:** Z-R-MOVE (14), Z-R-SCORE (17), Z-R-STATE (4), Z-R-SIGN (1) — the ruleset
  family: the A/B-axiom rows (`GLOBAL.AXIOM-GEOM/STONE/CAPTURE/SUICIDE/PASS/FORCEDPASS`,
  `GLOBAL.AXIOM-BASICKO/KOSTATE/KOPASS`, `GLOBAL.AXIOM-AMEND1/2`), `GLOBAL.S2`, the S2-impl
  rows (`3x3.S2-impl`, `4x3.S2-impl`, `4x4.S2-impl`), `4x3.S2`, `GLOBAL.S4`, `4x4.S4`, `4x3.S4`,
  `3x3.LIFE-NO-CENTRE`, `GLOBAL.TWO-LIFE-ONSET`,
  `CODE.S4-XVAL`, `GLOBAL.ADR0003-AREA`, `GLOBAL.ADR0004-TERM`, `GLOBAL.ADR0005-PASS`,
  `GLOBAL.ADR0005-DBLPASS`, `GLOBAL.AXIOM-AREA`, `GLOBAL.AXIOM-TERMINAL`,
  `GLOBAL.AXIOM-AMEND4`, `GLOBAL.AXIOM-SCORESIGN`, `GLOBAL.AXIOM-FRESHSTART`,
  `GLOBAL.AXIOM-PASSSTATE`, `GLOBAL.AXIOM-STATE`,
  `GLOBAL.ADR0006-*` (the eye-prune family is Z-AUDIT-mapped —
  re-adjudicated in W3-15), `GLOBAL.Z-R-MOVE-B1-EQUIV`, `4x4.KO-CLUSTER-MAX-2`.
- **Deliverables:** (a) **I11 move-set consistency at every rung** (`vb_i11.zig`: R8
  independent move generator vs kernel/SMD1 — 2×2/3×2/3×3/4×3 exhaustive, 4×4 full SMD1 slice
  48,636,330 + full table 99,133,036, T473); (b) **the B1-equivalence re-mechanization at
  3×3+** — the "separate row, not done here" from `GLOBAL.Z-R-MOVE-B1-EQUIV`: the
  `src/rules.zig:1385,1446` tests still mechanize the old (falsified) predicate; re-mechanize
  them to the corrected predicate (T380 F-3: old 152/784 at 3×3, 36,446/344,996 at 4×4;
  corrected 0/784, 0/344,996) and kill the old predicate; (c) **Z-R-SCORE via W3-05's
  independent scorer**; (d) **Z-R-STATE encoding checks** (the battery G1 gap — state-key
  correctness, closed by W3-03 + the encoding checks); (e) Z-R-SIGN via I2. Verdict ledger
  for the 36 mapped rows.
- **Controls:** I11's null = the R8 independent move generator; its seeded control = the T265
  ko mutant (M3) at a non-vacuous rung; the B1 re-mechanization's calibrating pair = T380
  F-3's old-predicate failures (known-bad) vs corrected-predicate 0/784 (known-good) — the
  old predicate IS the mutant, and the new test must fail on it; the scorer's controls from
  W3-05.
- **Holds:** `src/rules.zig` for the B1 re-mechanization (declare the hold, one writer, clear
  on close; the kernel is otherwise frozen as oracle — the re-mechanization changes only the
  *tests*, never `koAfterCapture`/`stateKey` behavior), the family readings + findings.
  **Conflict note:** T531 (dispatchable) already declares a hold on `src/rules.zig`; the seat
  must not dispatch W3-12 while T531's hold is live, or must re-point the re-mechanization to
  a new test file (preferred — see OPEN 9).
- **Needs:** W3-04 (Z-R joint), W3-05 (terminal scorer), W3-01 (promotions). **Needed by:**
  W3-16.
- **Acceptance:** I11 0 mismatches at all rungs with denominators; the B1 tests re-mechanized
  and the old predicate killed (red on old, green on corrected); every Z-R-mapped row has a
  verdict; `GLOBAL.Z-R-MOVE-B1-EQUIV` promoted or demoted with evidence.
- **Size:** 6–9 worker-days (the B1 re-mechanization and instrument wiring dominate).

#### W3-13 — "Z-R-TIE: cycle resolution rungs"

- **Covers:** Z-R-TIE (12 rows): `GLOBAL.AXIOM-TIE`, `GLOBAL.H1-MARKOV`, `GLOBAL.H1-COMPUTABLE`,
  `GLOBAL.LONGCYCLE`, `GLOBAL.ONEMISMATCH-CURE`, `QA-011`, `QA-013`, `QA-023`,
  `3x3.OPTIMAL-CYCLE`, `4x4.OPTIMAL-CYCLE`, `3x3.LOOPY-TAXONOMY`, `4x4.LOOPY-TAXONOMY`,
  `GLOBAL.PSK-GRAFT-COHERENT` (Z-TABLE-mapped; its cycle-resolution content is adjudicated
  here).
- **Deliverables:** (a) I10 (TIE ∈ [L,H]) at every rung; (b) **the QA-023 state-sufficiency
  contrast (tree gap #4)** — re-run the C1 test with the contrast generator fixed; the
  historical 93% miss rate (2B-3-AUDIT) is the known-bad; the 2026-08-05 T372 run (0 C1
  failures in 404 within-budget pairs at 3×2) is the baseline whose budget-exhaustion caveat
  must be addressed (state the within-budget denominator); (c) the optimal-cycle and
  loopy-taxonomy measurements re-verified (T416: 3×3 exhaustive 54 cyclic SCCs/12 forced,
  4×4 declared 150,001-node sample; T419: 3×3 exhaustive, 4×4 200,000-sample — per-goban
  independence: the 4×4 samples stay samples); (d) the cycle-resolution semantics rows
  re-adjudicated (`GLOBAL.LONGCYCLE` FALSE-AS-SCOPED at 3×2, `GLOBAL.H1-COMPUTABLE`
  FALSE-AS-SCOPED, `GLOBAL.H1-MARKOV` UNTESTED, `QA-023`'s split verdict).
- **Controls:** I10's known-good/bad from the battery baselines; QA-023's seeded control =
  the 2B-4 σ-in-arrival defect re-introduced (must change the reading, red, then green);
  T416's controls reused as-is (null ACYCLIC 0 edges; seeded force_all_optimal RED; the
  tie-handling control that undercounts cycles 54→48 must still fire).
- **Holds:** family readings + findings; the t416/t419 instruments are read-only consumers.
- **Needs:** W3-01 (promotions). **Needed by:** W3-16.
- **Acceptance:** I10 0 violations at all rungs; the QA-023 contrast re-run with a fixed
  generator and a stated denominator; the cycle/taxonomy rows re-verified or re-run; verdict
  ledger complete for the 12 rows.
- **Size:** 5–8 worker-days.

#### W3-14 — "Z-NONCLAIMS: NC1–NC5 re-verified"

- **Covers:** Z-NONCLAIMS (43 rows) — the negative half of Z, as load-bearing as the positive:
  `GLOBAL.C2`, `GLOBAL.C3`, `GLOBAL.C4`, `GLOBAL.FP2`, `GLOBAL.FP2-bounded`,
  `GLOBAL.FP2-general`, `GLOBAL.CERTCORE`, `GLOBAL.ADR0009-HONESTY`, `3x2.T13`, `2x2.T12`,
  `3x3.C2`, `4x3.C2`, `4x4.C2`, `3x3.C3`, `4x3.C3`, `4x4.C3`, `3x3.E2-RUN1`, `3x3.E2-RUN2`,
  `3x3.E3`, `GLOBAL.E1`, `GLOBAL.E2-SANITY`, `GLOBAL.E2-POLICY`, `GLOBAL.E2-VERDICT`,
  `GLOBAL.LEAK`, `GLOBAL.P3`, `4x4.P3`, `GLOBAL.T06`, `4x4.B39`, `4x4.B43`, `4x4.B43-DIV`,
  `4x4.B16-GAME`, `2x2.C3`, `3x2.C3`, `GLOBAL.ADR0014-PURE`, `GLOBAL.ADR0016-INHERIT`,
  `4x4.A-2`, `QA-003`,
  `QA-009`, `QA-012`, `QA-015`, `QA-022`, `GLOBAL.PATHOLOGY-GRADIENT`, `4x4.LEAK-TIEBREAK`,
  `GLOBAL.REFRAME` (Z-mapped; adjudicated here).
- **Deliverables:** each non-claim's falsification re-derived against the kernel-as-oracle:
  (a) **NC1** — `3x2.T13` re-run via the committed probe re-implementation
  (`docs/evidence/T13/`): the 154/508 reachable L==H slots with a differing PSK history,
  re-confirmed with the kernel's key; `2x2.T12`'s SCC witness re-derived; (b) **NC2** —
  `3x3.C3`'s E2 leak re-run (the E2 harness exists); `3x3.E2-RUN2`'s run log is **uncommitted
  debt** (D-1) — the row either re-runs the 8,000-game replication or records the demotion to
  UNTESTED-with-debt; (c) **NC4** — the leak family re-derived at the rungs where the arena
  runs exist; (d) the scope rows (`4x4.C2/C3` UNTESTED status conflicts D2/D3) adjudicated
  under per-goban independence; (e) the 3 `RETIRED` rows' retirement ruling recorded (they
  serve L3, not the theorem — T384/T396 already argued it; the human's ruling is the
  deliverable, with the argument restated). Worked example: `3x2.T13` re-derived PROVEN
  (falsification stands — probe re-implementation re-run against the kernel, 154/508
  re-confirmed, calibration control green); `3x3.E2-RUN2` re-run or demoted with the debt
  named.
- **Controls:** each falsification's own controls (T13's probe calibration; the E2 sanity
  harness — trivial-bounds leak-free everywhere; the T375/T381 arena null+seed controls).
- **Holds:** family readings + findings; no engine files.
- **Needs:** none hard (kernel and artifacts exist); W3-01 for any promotion. **Needed by:**
  W3-16.
- **Acceptance:** every one of the 43 rows has a verdict; the AXIOMS §1.2 NC1–NC5 block is
  re-verified clause by clause; the uncommitted-evidence rows are re-run or their debt
  recorded; the retirement rulings for the 3 `RETIRED` rows are requested with evidence.
- **Size:** 5–8 worker-days (arena re-runs are minutes each; the T13 re-run dominates).

#### W3-15 — "Z-AUDIT: instruments re-verified"

- **Covers:** Z-AUDIT (24 rows) — the claims about the instruments themselves:
  `GLOBAL.AUDITOR`, `GLOBAL.P2`, `GLOBAL.CALIB-LESSON`, `GLOBAL.BRUTE-ALIASING`,
  `GLOBAL.BATTERY-GAPS`, `GLOBAL.BATTERY-PASS1-ACCEPTANCE`,
  `CODE.BATTERY-STUBBED`, `CODE.VB-STUBS`, `CODE.M4A-HARNESS`, `CODE.CLAIMLINT-C7-NEWROWS`,
  `CODE.I5-INSTRUMENT-ADJUDICATION`, `CODE.INSTRUMENT-COVERAGE`, `CODE.PROPERTY-OWNERSHIP`,
  `CODE.RESOLVER-INTERFACE`, `CODE.RESOLVER-BUDGET-QUARANTINE`, `CODE.RESOLVER-CONTROLS`,
  `GLOBAL.ADR0006-EYE`, `GLOBAL.ADR0006-PRED`, `GLOBAL.ADR0006-LEMMAS`,
  `GLOBAL.ADR0006-PRUNEALL`, `GLOBAL.ADR0006-TEST`, `3x2.I5-CAL`,
  `CODE.VB-BLINDGAPS`, `QA-022`.
- **Deliverables:** (a) for each instrument-validity row: re-verify the instrument's
  calibration pair still fires at HEAD (the fixes T258/T269/T273/T391 are in the tree — the
  rows' SUPERSEDED statuses re-confirmed, or the fixes re-broken); (b) the per-rung #2 auditor
  runs (`RETRO_CONSIST`) on the in-scope artifacts, feeding W3-09/W3-10; (c) the
  instrument-coverage divergences D1/D3–D9 (`CODE.INSTRUMENT-COVERAGE`) re-stated or closed —
  the "same test at every size" doctrine (operator 2026-08-06); (d) the kernel-vs-fixture
  differential discipline re-confirmed at every rung (DIRECTION §4: kernel vs the frozen 17
  ko copies and exp4–7 — every disagreement adjudicated, kernel bug or fixture bug); (e) the
  eye-prune family re-adjudicated (the ADR-0006 direct-falsification hole from CLAIMS §4.2
  honourable mention — the weakest joint of the forward-search ground truth).
- **Controls:** each instrument's calibration pair; claimlint's own calibration cases (C1–C11
  known-good/known-bad); the T395 four seeded-defect knobs.
- **Holds:** family readings + findings; no engine files (read-only consumers).
- **Needs:** W3-01; the ladder rows' readings as inputs (run after them per family, or
  per-rung as readings land). **Needed by:** W3-16.
- **Acceptance:** every Z-AUDIT-mapped row re-verified with its controls; `GLOBAL.AUDITOR`
  re-confirmed as the standing pre-commit gate (necessary, not sufficient); the
  instrument-coverage divergences re-stated or closed; the eye-prune rows have verdicts.
- **Size:** 4–6 worker-days.

### F-row — the finish line

#### W3-16 — "Waypoint 3 completion gate"

- **Covers:** the mechanized acceptance for "Waypoint 3 complete" (DIRECTION §5: "every gate
  mechanized from the day it is declared" — a gate, not prose), plus the Z-root assertion
  (`GLOBAL.Z`, `GLOBAL.C1`, `GLOBAL.REFRAME`, `QA-025`).
- **Deliverables:** `tools/waypoint3-accept.sh` (wired into `zig build test` fast path as a
  meta-gate, or `zig build w3-accept`; failing loudly on any check — never a vacuous pass),
  which verifies:
  1. **Ledger completeness:** `docs/evidence/WAYPOINT3/verdict-ledger.json` row set == the
     claimlint C0 row set (231), every row with exactly one verdict and its evidence paths
     existing on disk (C2-clean);
  2. **Floor:** claimlint at or below the recorded floor (C1a=0, C1b=0, C2≤13, C6=0; C9=0) —
     not "green", per the pre-commit doctrine;
  3. **Controls manifest:** every instrument used in the program has its null + seeded
     controls recorded in `docs/evidence/WAYPOINT3/controls-manifest.json`, each with a
     red-then-green evidence path that exists; the gate fails on any missing path;
  4. **Tree gaps closed:** Z-R joint (W3-04), adversarial key agreement (W3-03),
     Z-CONVERGE-SEED at all sizes (W3-08), QA-023 contrast (W3-13), 4×4 closure re-verified
     (W3-06), #2 auditor on the writes-off 4×4 (W3-10);
  5. **Z falsifiability, every rung:** Z1 state omission (I6 + closure), Z2 Bellman
     violation (I4), Z3 seeding violation (W3-08 provenance), Z4 colour-inversion (I2),
     Z5 monotonicity (proof read) — each with a named instrument and denominator;
  6. **NC1–NC5 re-verified** (W3-14);
  7. **Promotion criteria:** every row promoted past CLAIMED names its killed mutants (W3-01)
     and carries the C11 `audited_by` attestation for tier-A changes.
- **Holds:** `tools/waypoint3-accept.sh`, the ledger, the controls manifest.
- **Needs:** ALL of W3-01…W3-15 (it is the conjunction). **Needed by:** L2 declaration and
  the Phase-4 swap (kernel becomes production; `src/` gains the engine/experiment boundary).
- **Acceptance (the gate's own controls):** the gate passes green on a full clean run; it
  fails (non-zero) on each of a seeded set of omissions — a missing verdict, a missing
  control path, a regressed floor, an unpromoted row without its mutant evidence.
- **Size:** 2–3 worker-days + the synthesis pass.

---

## 2. Sequencing rationale

**What unblocks what:**

```
W3-01 mutation gate ──► (promotion currency: every past-CLAIMED promotion)
W3-02 phantom close ──► (queue hygiene; unblocks the set-S dispatchable)
W3-03 adv key agreement ─► W3-06 Z-STATE
W3-04 Z-R joint ─┐
W3-05 terminal scorer ─┴► W3-12 Z-R rungs
W3-10 writes-off regen ─► W3-09 Z-TABLE-FAITHFUL (rung-5 slice)
W3-01..W3-15 ─────────────────────────────► W3-16 completion gate
```

1. **The mutation gate (W3-01) is first because it is the currency, not a step.** Amendment 2
   edge 5 means no re-derived row may pass CLAIMED until the mutants covering its function are
   killed. The honest 6/10 (M3 survives; M1/M2/M4 unfixtured) closes **seven promotion gates**
   — the CLAIMED stack that Waypoint 3 exists to promote: `4x4.C1`, `4x4.FP1`, `GLOBAL.H4`,
   `GLOBAL.I5-SCC-CONTAIN`, `4x4.WZO2-A2/A5/A8-EXHAUSTIVE`, `CODE.WZO2-BUILD-REPRO`,
   `CODE.KEY-AGREEMENT`, plus the T273 kernel claims. Every ladder row's acceptance references
   it. If the operator re-rules the threshold instead (ROADMAP §3.2), the fixtures still land
   first so the ruling has evidence in view.
2. **The phantom phase-2 audit row (W3-02) closes early because it is a dispatch trap.**
   `T430's unexecuted phase-2 audit` is precisely this: the audit's *content* was delivered
   under T433 (pass-with-findings; the residual F3–F5 citation errors), but the kanban's
   `--bundle [set S]` row still names the absent bundle `untracked/T430-phase2-audit.md` and
   is dispatchable. Close it before anyone is dispatched to a non-file.
3. **The new instruments (W3-03/04/05) land before their consumers** (W3-06, W3-12) so the
   ladder rows run one pass, not two. They are the six tree gaps' build half; the ladder rows
   are the adjudication half.
4. **The writes-off regen (W3-10) precedes the 4×4 slice of the faithfulness row (W3-09)**
   and is the critical path: it is the AGENTS.md ko-sensitive foreclosure's discharge, the
   #2 auditor's target, and `4x4.C1`'s last promotion condition. W3-09 sequences its rungs
   1–4 first so its earlier work is not blocked.
5. **The ladder rows are concurrent within holds.** They touch different instruments, different
   artifacts, and different findings files; the real serializer is file ownership, not the
   phase number (Amendment 2). The only hard serializers are the needs edges above and the
   one-writer holds declared per row. A seat may split any family row into per-rung rows if a
   worker budget demands it — the family row is the proposed granularity, not the only one.
6. **Where Waypoint-2's remaining debt sits in the order:** mutation adequacy 6/10 → W3-01
   (first); the seven closed promotion gates → discharged by W3-01 then spent by W3-03,
   W3-06…W3-13 (each row's acceptance names which of the seven it promotes); T430's
   unexecuted phase-2 audit → W3-02 (second). Nothing else of Waypoint 2 is outstanding:
   the kernel claims stay CLAIMED (their promotion is W3-04/W3-12's job), and the g3b
   discharge's residual scope limits were rescinded by T472/T473 (I11 exhaustive at 4×4).
7. **Rung order inside each family row is 2×2 → 3×2 → 3×3 → 4×3 → 4×4** (dependency, not
   calendar): each rung's instruments calibrate on the previous rung's artifacts, and per-goban
   independence means a rung's verdict never licenses the next — but the 4×4 runs are the
   expensive ones, so a rung-5 failure is isolated to rung 5's verdict, not the row's earlier
   work.

---

## 3. Controls — never trust a green test

Per the never-trust-a-green-test doctrine (DIRECTION Amendment 1; QA-023 chain; AGENTS.md
verification rules), every instrument this program names carries a null control and a
seeded-defect control. Reused instruments carry their existing controls; new instruments
(W3-03/04/05) carry the controls specified in their rows. Consolidated map:

| instrument | sizes / rungs | null control (known-good) | seeded-defect control (known-bad) | reused as-is? |
|---|---|---|---|---|
| Battery I1–I12 (`verify-battery`, `vb_*.zig`) | 1–4 general; 5 via size-specifics | golden-master baselines (T292; "unchanged from baseline", never "fails") | the ten mutants M1–M10 (T291/T475; `vb_mutants.zig`) | yes — controls already wired; M1/M2/M4 fixtures and the M3 kill are W3-01 |
| I4 Bellman (`vb_fixpoint` / `vb_bellman_4x4` / accept A2) | all | ADR-0020 independent Python re-run (2×2); T309/T363 exhaustive baselines | v1 basic-ko artifact's I2 failure (T260, ~48%) as the regression-input pair | yes |
| I5 SCC (`vb_graph` / `vb_scc_4x4` / `i5_differential`) | all | third-route Python (T391); register-calibrated `vb_graph` post-fix | the historical fabricated-24 (defect C, CR descending) — must still read 0 true / 24 buggy | yes |
| I11 move-set (`vb_i11.zig`) | all | R8 independent move generator vs kernel/SMD1 | T265 ko mutant (M3) at a non-vacuous rung | yes |
| A1–A9 WZO2 acceptance (`oracle_v2_accept.zig`) | 3×3, 4×4 WZO2 | T212/T260 independent re-implementations | A6 calibration fixtures (3 seeded corruptions: value→SHA, dropped ko state, zeroed DTT) | yes |
| Differentials (T267, i4, i5, keybyte) | all | the differentials' clean agreement | the T395 four seeded-defect knobs, red-then-green; keybyte's 256-byte × ko_bits pin | yes |
| claimlint C0–C11 | meta | calibration cases (C1–C11 known-good) | each check's known-bad fixture (the check-to-incident map) | yes |
| #2 auditor `RETRO_CONSIST` | per rung | `3x2.F3` 0/378 (writes-off) | `3x2.F1` 45/378 (writes-on) | yes |
| Frozen fixtures (17 ko copies, exp4–7, brute forcers) | all | — (they are the differential corpus) | every kernel-vs-fixture disagreement is a finding to adjudicate (DIRECTION §4) | yes |
| W3-03 adversarial key agreement | all | T267/T345 pass reproduction | the three historical key defects (ko too broad / passes-bit / colex-vs-rank) via mutation knobs | new — controls in W3-03 |
| W3-04 Z-R joint | all | clean readings agree exhaustively ≤3×2, sampled 3×3+ | planted axiom divergence; legacy 14-copy family must fire | new — controls in W3-04 |
| W3-05 terminal scorer | all | agree with rules.zig + tables at terminals | planted scoring defects (off-by-one territory; as-stands violation) | new — controls in W3-05 |

**Standing discipline:** a control that cannot run must fail loudly, not pass vacuously
(DIRECTION §7); a reading without its controls recorded is not a reading; "0 violations" always
carries its denominator and its run command.

---

## 4. The finish line — a gate, not prose

"Waypoint 3 complete" is **W3-16's `tools/waypoint3-accept.sh` passing green**, where green
means all seven checks (ledger completeness, floor, controls manifest, tree gaps closed, Z
falsifiability Z1–Z5 at every rung, NC1–NC5 re-verified, promotion criteria) hold, and the
gate's own seeded-omission controls fail it correctly. Nothing prose may declare Waypoint 3
complete; the LANDMARKS L2 (proven 4×4 values) declaration cites the gate's run, and the
Phase-4 swap (kernel becomes production) is gated on it (Amendment 2 edge 4: Phase 4 swap ←
Phase 3 differential verification).

---

## 5. OPEN items — assumptions not verifiable at HEAD

1. **The mutation-gate threshold's final disposition.** The row set assumes W3-01 can reach
   10/10 by fixturing M1/M2/M4 and killing M3. Whether the operator instead re-rules the
   threshold (ROADMAP §3.2) is not decidable here; either way W3-01's deliverables stand.
2. **The writes-off 4×4 regen's feasibility is a measurement, not a given.** `4x4.D3` is
   UNTESTED; the existing writes-on build ran 3,789 s / 31 sweeps at 3.9 GB RSS. The regen may
   blow the 4 GB runner cap or exceed the 8 h wall target; W3-10 must report either outcome.
   The row's structure (and this spec's dependency of W3-09 on it) assumes a completed regen;
   if D3 comes back infeasible, W3-09's rung-5 slice and `4x4.C1`'s promotion take the
   documented demotion path instead — a seat ruling, not a spec change.
3. **The 4×4 ladder re-runs' wall-clock budget.** The 4×4 readings are minutes, not hours
   (closure C-A1+C-A2 245.8 s at 1,124 MB RSS — T383; I5 149 s at 2,768 MB RSS — T344; I11
   69.5 s — T473; A2 50.6 s — T309), each under the runner's 4 GB RSS cap and the
   one-invocation rule; the total 4×4 re-run compute across W3-06/07/09/10/11 is on the order
   of a few hours of serial runner time, dominated by W3-10's regen (3,789 s / 31 sweeps at
   3.9 GB for the existing writes-on build). I could not verify current host load or the
   compressor-incident status; the rows must run under `tools/runner` per `docs/infra/runner.md`
   (the Orchestrator's refusal duty covers unguarded builds).
4. **`3x3.E2-RUN2`'s 8,000-game run cannot be re-derived from committed evidence** — no run
   log is committed (D-1 debt). W3-14 either re-runs it or demotes it; I could not verify
   whether the original run is recoverable anywhere.
5. **The exact inventory of "the seven promotion gates" is not stated verbatim in one place.**
   I named the CLAIMED rows blocked by edge 5 from the register's own "CLAIMED … pending
   Phase 3" / "held at CLAIMED per edge 5" language; the count may differ by a row or two at
   HEAD. W3-01's ledger should list the definitive set and reconcile any drift.
6. **The register-count prose (228 vs claimlint's 231)** is stale prose only (C9 row-set
   equality passes; both tables hold 231). Folded into W3-02 as a one-line cleanup; I verified
   the tables, not the git history of the prose.
7. **Whether any in-flight task already owns part of this scope.** The kanban at claim time
   (2026-08-23) shows no Track A / writes-off / reverification task in progress; T531 holds
   the battery-file family, so new instrument files (w3_*) were chosen to avoid that hold set.
   If a row appears mid-program, the seat reconciles.
8. **The operator's retirement rulings for the 3 `RETIRED` rows and any demotion proposed by
   the ladder rows** are ratification events, not mid-flight blockers — rows must request
   them with evidence and continue (Decide-now doctrine: only genuine operator calls —
   spend, scope, overturning a recorded ruling — escalate).
9. **T531's declared holds overlap the battery file family** (`src/rules.zig`, `src/differential.zig`,
   the `vb_*` files, `build.zig` — dispatchable as of 2026-08-23). The new-instrument rows
   (W3-03/04/05) were given new `src/w3_*.zig` files specifically to avoid that hold set, and
   W3-12's B1 re-mechanization should prefer a new test file over editing `src/rules.zig`
   (the kernel stays frozen as oracle; the tests are what change). If T531 is in flight when
   any W3 row dispatches, the seat reconciles the holds before claim.

---

## 6. Milestone line

**Landmark:** advances `L2 (proven 4×4 values)` — Waypoint 3, decomposed into 16 poppable,
conflict-free rows (2 debt-closure, 3 new-instrument, 10 family-ladder, 1 mechanized finish
gate) with the mutation gate first (the promotion currency), the phantom phase-2-audit row
closed second, and every register row's verdict ledgered and gate-checked. What remains: the
seat's synthesis, the operator's ratification, then execution under `tools/runner`.
