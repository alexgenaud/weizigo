# Waypoint-3 decomposition spec — A–Z reverification as registerable rows

```
Task:   T744 · Role: worker · Model: ox-alpha · Date: 2026-08-23 · At HEAD 3ce328e
Status: PROPOSAL — one of five independent Race-I lanes; the seat synthesizes, the operator ratifies.
Inputs: DIRECTION.md §5 + Amendments 1–2 (ratified) · PHASES.md · CLAIMS.md (231 live rows,
        claimlint C0 at HEAD, run 2026-08-23) · register-tree-map.md · AXIOMS.md §3 (tree) ·
        pass1/{spec,mutants,baselines}.md · LANDMARKS.md §L2
Output: this file only. Proposes no register status changes — no findings JSON accompanies it
        (nothing here is a claim about the engine; it is a work decomposition).
```

**Waypoint 3** (called "Phase 3" in DIRECTION.md until the ratified rename sweeps) is:
*every row of the claims register re-verified against the extracted kernel-as-oracle plus
the battery; re-derived, demoted, or retired against the requirement tree; kernel vs
fixtures differentially at every rung* (DIRECTION §5 Phase 3). It has never been
decomposed. This spec decomposes it into 13 poppable rows.

**What "re-verified" means mechanistically** (used identically in every row below):
a register row is re-verified when a *machine check that can fail* — battery invariant,
differential, closure check, key-agreement invariant, or a census with a full denominator —
is run at HEAD against the kernel-as-oracle (the Phase-2 `rules.zig`
`koAfterCapture`/`stateKey` as production; every legacy copy a frozen fixture), and the row
carries a disposition citing that run: **re-affirm** (status stands, evidence re-pointed at
the new run), **demote** (status drops; the disagreement is the evidence), or **retire**
(proposed-retired with reason; human rules per the tree-map convention). A prose
re-reading is not a re-verification. "Every row" includes falsifications and MEASUREMENT
rows — the negative half of Z is as load-bearing as the positive half (AXIOMS §3.7
Z-NONCLAIMS).

---

## 1. The ordered row set

Estimates: XS ≤ half a session · S one session · M 1–2 · L multi-session, runner-guarded.
`holds` are engine-file/one-writer holds; the register itself is written only via the
standing absorption pass, so no worker holds `CLAIMS.md`. No row below needs a human
mid-flight: the two rows that feed operator rulings (W3-08, W3-11) **complete when the
evidence bundle is delivered and committed**; the ruling is queued behind the bundle, not
blocking the row.

### W3-01 · slug `w3-killmatrix-recon` — "Reconcile the mutation kill matrix" (S)

- **Why first.** Amendment 2 edge 5 makes the kill rate the *promotion currency*: no claim
  moves past CLAIMED until the mutants covering its function are killed. Every promotion
  below cites this row's verdict. The current state is a three-way contradiction:
  `kill-matrix.json` (the claimlint C8 single source) records **3/10, dated 2026-08-03**;
  `mutants.md`'s changelog records T475's corrected **6/10** (2026-08-19) and T530's
  claimed **10/10** (2026-08-20, "the Amendment-2 mutation gate is now satisfied as
  written"). A promotion argued from either number today cites an unreconciled instrument.
- **Deliverables.** (a) Independent re-run at HEAD of the four T530 kill-verification
  fixtures (M1 colex-vs-rank, M2 passes bit, M3 ko-too-broad, M4 ACCEPT-KOKEY — all four
  claimed killed by the T267 key-agreement invariant); red-then-green observed live, per
  fixture, with the run command recorded. (b) `kill-matrix.json` regenerated to match
  `mutants.md` — one file's verdict per mutant, C8 and the changelog agreeing. (c) Findings
  JSON recording the reproduced (or refuted) kill rate and the resulting count of closed
  promotion gates.
- **Holds.** `docs/epics/E1-markovian/sprints/verify-battery/pass1/kill-matrix.json`,
  `.../mutants.md`.
- **Needs.** None.
- **Acceptance.** Either verdict is a pass; silence is not. (i) `bin/weizigo-claimlint` C8
  reads the regenerated matrix with zero disagreements against `mutants.md`; (ii) each of
  the 10 catalogue mutants carries a per-mutant red-then-green fixture in
  `zig build test` **or** an explicit SURVIVES-with-gap record (a survivor is a recorded
  closed gate, not a failure of this row); (iii) the findings JSON states the kill rate as
  `killed/10` with the fixture run as evidence.
- **Worked example.** If M3's fixture at HEAD shows keys *agreeing* under the mutant (the
  kill has rotted), the row records `9/10` and one closed promotion gate
  (GLOBAL.AXIOM-BASICKO stays unpromotable) — that is a **pass with findings**, and the
  three exhaustive-acceptance rows (`4x4.WZO2-A2/A5/A8-EXHAUSTIVE`, held CLAIMED per edge
  5) stay put. If all four T530 fixtures reproduce red-then-green, the rate is 10/10 and
  those three rows become promotion-eligible in their size batches (W3-07).

### W3-02 · slug `w3-phantom-audit-close` — "Close the phantom phase-2 audit row" (XS)

- **What the brief calls "T430's unexecuted phase-2 audit" is already delivered.** The
  kanban's `--bundle` row points at `untracked/T430-phase2-audit.md`, which does not exist
  on disk (verified 2026-08-23); the phase-2 audit content was delivered under **T433**
  (`docs/infra/tool-consolidation/02-scope-audit.md:240-246` — "the real brief is
  `untracked/T433-phase2-audit.md`"; `docs/status/landmark-assignment-2026-08-19.md:51` —
  "the phase-2 content has been delivered under T433"). The row is a phantom of the
  bundle-renaming episode; T444/T446 already recommended close-with-evidence.
- **Deliverables.** A one-paragraph close-with-evidence memo (where T433's audit lives,
  what it covered) appended to the synthesis package; the `--bundle` row proposed for
  `done --status abandoned` at ratification. No re-execution.
- **Holds.** None (memo only).
- **Needs.** None. Parallel with W3-01.
- **Acceptance.** The memo cites T433's deliverable by path and the landmark-assignment
  line; the phantom row's proposed disposition is recorded. Done.

### W3-03 · slug `w3-oracle-diff-harness` — "Kernel-vs-fixture differential harness" (M)

- **What it is.** One runner, all four theorem sizes, one command: per size g ∈
  {2×2, 3×2, 3×3, 4×4} (4×3 behind a flag, see W3-08), run the kernel-as-oracle battery —
  colour inversion (I2), L ≤ H (I3), Bellman residual (I4), TIE∈[L,H] (I10), score range
  (I12), closure C-A1/C-A2, key agreement (T267 invariant), I11 at its current sampled
  denominator — and emit a per-size machine-readable verdict JSON where **every line
  carries its full denominator** (`0 / N` or the violation count), per the L2 rule that a
  line without a denominator is not a reading.
- **Reused as-is (do not rewrite).** `src/vb_table.zig`, `vb_fixpoint.zig`, `vb_graph.zig`,
  `vb_closure.zig`, `vb_i11.zig`, `vb_movegen.zig`, `keybyte_differential.zig`,
  `differential.zig`, the T267 key-agreement invariant, and the golden-master baselines
  (`docs/evidence/BATTERY/baselines.json`). The row composes existing checks behind one
  entry point; it does not invent a fifth ko rule.
- **Controls (never-trust-a-green-test).** *Null:* the runner against the canonical
  artifacts must reproduce the recorded baselines exactly (golden master — "unchanged from
  baseline", never "fails"). *Seeded-defect:* at each size, the runner must go red on (a)
  the pass1 mutant fixtures that size can express — minimally one value corruption with the
  checksum repaired (the LANDMARKS §L2 strong-corruption pattern: a blind byte flip only
  proves the checksum works) and (b) one key-encode flip (the M1/M2 class). A runner that
  cannot turn red on the seeded artifact is blind and does not ship.
- **Holds.** One new file (e.g. `src/w3_reverify.zig`) + its build-graph wiring. No engine
  files.
- **Needs.** None hard — Amendment 2 gates *promotion*, not dispatch. But nothing cites its
  readings until W3-01 records the kill rate.
- **Acceptance.** (i) All four sizes emit verdict JSON with denominators from one command
  under `tools/runner`; (ii) both controls fire (red observed on seeded inputs, green
  unchanged on canonical); (iii) wired into `zig build` (a fast path in `zig build test`,
  full sweeps behind a named step) — nothing green that doesn't run.
- **Estimate note.** 4×4 full sweeps reuse the recorded exhaustive runtimes (A2 50.6s, A8
  55.9s, closure ~minutes) — the composition is the work, not the compute.

### W3-04 · slug `w3-reverify-2x2` — "Reverify 2×2 register rows" (S)

### W3-05 · slug `w3-reverify-3x2` — "Reverify 3×2 register rows" (S)

### W3-06 · slug `w3-reverify-3x3` — "Reverify 3×3 rows, honest anchor" (M)

### W3-07 · slug `w3-reverify-4x4-core` — "Reverify 4×4 core rows" (L)

One row per size; identical shape, so specified once here (§1a) with per-size deltas after.
The ladder order 2×2 → 3×2 → 3×3 → 4×4 is **shake-out order, not epistemic dependency**:
the kernel is size-generic, so a harness defect surfaced at the cheapest size invalidates
the larger runs — but per-goban epistemic independence means a verdict at one size is never
evidence at another, and the batches may run concurrently once W3-03 is green at that size.
3×3 carries one delta: the anchor (+9) is *reconciled honestly* — the MIGOS basic-ko
agreement (`GLOBAL.TIE-MIGOS`, `GLOBAL.FIXPOINT-VS-SEARCH`) is re-attested as external
attestation of the k=1 fresh-start value, with the refuted tie-explanation
(`GLOBAL.ADR0020-LH-CORRECT` family) not silently reused as proof. 4×4 carries the size's
own burden: 54 scoped rows plus the `all`-scoped rows' 4×4 leg, and its batch absorbs the
promotion decisions (A2/A5/A8 exhaustive, `CODE.WZO2-BUILD-REPRO`) that W3-01 licenses.

#### §1a — the per-size batch shape (applies to W3-04…W3-07)

- **Deliverables.** (a) The W3-03 verdict JSON at that size, run at HEAD, committed under
  `docs/evidence/W3/<size>/`. (b) A disposition table covering **every** live register row
  in that size's scope — scoped rows plus the size's leg of `all`/multi-size rows — with
  one of re-affirm / demote / retire per row, each citing the run (command, flags,
  denominator). (c) Findings JSON (schema per `findings/README.md`) proposing the status
  changes; absorbed via STANDING-ABSORB. (d) For rows whose evidence is prose-only or lost
  (e.g. `2x2.B1`/`3x2.B1` — "no durable evidence file, downgraded PROVEN→CLAIMED
  2026-07-29"): the re-verification run *becomes* the durable evidence, committed under
  `docs/evidence/<claim-id>/`.
- **Holds.** The batch's own evidence directory + findings file. Register writes go through
  absorption only.
- **Needs.** W3-03 green at that size (hard). W3-01 recorded (hard for any *promotion*
  past CLAIMED; demotions and re-affirmations at or below current status need only W3-03).
- **Acceptance.** (i) Zero silent rows: every in-scope row appears in the disposition table
  (claimlint C7 = 0 after absorption; C9 row-set equality still holds); (ii) every
  disposition cites a run with a denominator; (iii) no promotion past CLAIMED without
  W3-01's recorded gate being satisfied for the row's function (edge 5); (iv) the size's
  falsification rows (e.g. `3x2.T13`, `3x3.C3`) are re-affirmed *from their own evidence*
  — a falsification whose witness no longer reproduces is a finding, not a quiet re-affirm.
- **Worked example (3×2).** `3x2.F3` ("writes-off self-consistent at 3×2", PROVEN) — the
  runner's 3×2 Bellman residual reads `0 / N` on the k=1 build; the row re-affirms with the
  new run as evidence, its `wrong-answer-pass-rate` re-stated against the battery's kill
  matrix. `3x2.T13` (C2 falsified, 154/508) — re-affirmed by re-running the T13 probe
  fixture if wired, else by citing the committed `docs/evidence/T13/` re-implementation;
  if the probe is unwired, the batch wires it (a falsification nobody can re-run is one
  repair away from an orphan).

### W3-08 · slug `w3-reverify-4x3-sizebrief` — "Reverify 4×3 rows + size-set brief" (S)

- **The wrinkle.** Z's size set is {2×2, 3×2, 3×3, 4×4} (AXIOMS §1) — **4×3 is not in the
  theorem** — yet the register holds 14 4×3-scoped rows and substantial 4×3 evidence
  (closure 0/643,378, cycle containment 0/170,181, `4x3.H1-CENSUS`). The rows are real
  knowledge feeding `all`-scoped claims; the theorem is silent about them.
- **Deliverables.** (a) The W3-03 batch shape run at 4×3 (flag from W3-03). (b) A one-page
  ruling brief for the operator: amend Z's size set to include 4×3 (evidence exists; cost
  of inclusion ≈ what is already delivered) **or** mark the 14 rows out-of-theorem
  supporting evidence (tree-map disposition, not RETIRED). The brief decides nothing; the
  operator rules at synthesis. (c) Disposition table per §1a with the size-set question
  attached to each 4×3 row as a rider.
- **Needs.** W3-03 (4×3 flag); W3-01 for promotions.
- **Acceptance.** §1a (i)–(iv) at 4×3, plus the brief delivered. The row **completes with
  the bundle**; the ruling is queued, not blocking (poppable rule).

### W3-09 · slug `w3-nonclaims-reverify` — "Reverify non-claims NC1–NC5" (M)

- **Why a separate row.** The NCs are cross-size by nature (NC1 at 2×2/3×2/…, NC2 at
  3×3/4×4, NC3 policy, NC4 player-leak family, NC5 auditor doctrine) and are the half of Z
  a per-size batch sees only piecemeal. Batching them buys one consistent standard: each
  NC is re-affirmed **as a falsification** — the witness re-run or the committed
  re-implementation cited — never absorbed as background.
- **Deliverables.** Per-NC disposition (re-affirm / demote / retire) covering the NC1–NC5
  mapped rows (Z-NONCLAIMS in the tree column, ~30 rows), with the leak-family
  measurements (`GLOBAL.LEAK`, `4x4.P3`, `GLOBAL.T06`, …) re-census-or-cited; findings JSON;
  absorb via standing pass.
- **Needs.** W3-03 (the harness supplies per-size verdicts the NC rows sit on top of);
  W3-04…W3-07 *not* required — this row reads the same runs, so it may land with or after
  the size batches, whichever the seat schedules; no file conflict (distinct findings file).
- **Acceptance.** Every Z-NONCLAIMS-mapped row dispositioned with a denominator; any NC
  whose falsification witness cannot be re-run gets the witness wired or the row demoted
  with that stated. An NC silently re-affirmed from prose fails this row.
- **Worked example.** NC1 at 2×2 (`2x2.T12`: "C2-pilot tautological — no cycles") is
  re-affirmed by the trivial census `0 cyclic states at 2×2` from the runner's SCC output —
  a one-line denominator, which is all the claim ever needed.

### W3-10 · slug `w3-i11-exhaustive-4x4` — "Exhaustive I11 at 4×4" (L)

- **What it closes.** The one non-exhaustive L2/G3b condition: I11 (kernel-vs-independent
  move-set) is a 0.05% sample at 4×4 (0/50,000 of 99,133,036); LANDMARKS §L2: "never a
  sample". ~600M children makes it scale-expensive — hence a sizing gate inside the row.
- **Deliverables.** (a) Sizing pass: measured child-generation rate at 4×4 → projected wall
  time and peak RSS, recorded **before** the run commits. (b) The exhaustive run under
  `tools/runner` (SIGKILL guard, heartbeat, persistent session discipline). (c) Verdict
  `0 / <children>` or the violation list; findings JSON; evidence committed.
- **Holds.** `src/vb_i11.zig` (if the exhaustive mode needs code) + its evidence dir.
- **Needs.** W3-03 (the harness entry point); W3-01 (its reading is promotion-grade
  currency); W3-07 (the 4×4 core batch should have shaken out first — an I11 violation
  lands as that batch's demotion, not a surprise).
- **Acceptance.** Full denominator or the sizing pass's honest "does not fit" with the
  measured numbers (a deferral with denominators beats a sample without one — but it does
  not discharge L2; the finish gate tracks it as open).

### W3-11 · slug `w3-kosensitive-tracka-brief` — "KO_SENSITIVE Track A evidence bundle" (S)

- **What it is.** The KO_SENSITIVE column is distrusted fleet-wide (AGENTS.md foreclosure);
  T380 F-8 is evidence it may be dischargeable **by ruling** rather than by a writes-off
  regen. This row assembles that ruling's evidence bundle: what F-8 measured, what a
  Track-A regen would cost (the `GLOBAL.REACH-P4-CENSUS` totals give the state counts),
  and the two candidate rulings with their consequences for the register's KO-mapped rows.
- **Deliverables.** The bundle, committed; the ruling queued for the operator. Row
  completes with the bundle (poppable rule).
- **Needs.** W3-07 (the 4×4 batch's KO-mapped dispositions say exactly which rows ride on
  the ruling).
- **Acceptance.** Both candidate rulings are stated with their row-level consequences; no
  KO-sensitive value is quoted as truth anywhere in the bundle (the foreclosure stands
  until the operator rules).

### W3-12 · slug `w3-auditor2-gate-4x4` — "#2 auditor gate at 4×4" (M)

- **What it is.** The mandatory pre-commit-gate discipline (AGENTS.md: the #2
  self-consistency auditor) run on the completed k=1 4×4 table — the gate T274's residue
  ("our own +1 still awaits the #2 auditor") and register-tree-map §5.6 both name as owed.
  The auditor traces complete evaluations end-to-end (the QA-023 rule: reviewing inputs and
  outputs is not tracing a datum).
- **Deliverables.** Auditor brief + run + verdict on the k=1 4×4 table; findings JSON;
  `GLOBAL.AUDITOR`'s 4×4 leg re-pointed at it.
- **Needs.** W3-03; W3-07 (audits the batch's surviving table reading); W3-01 (a red
  auditor finding may trigger demotions that need the gate currency).
- **Acceptance.** One complete evaluation traced entry-to-verdict, zero minimax-identity
  violations on the sampled depth (denominator stated), or the violations become the 4×4
  batch's amendment findings.

### W3-13 · slug `w3-finish-gate` — "Mechanized Waypoint-3 finish gate" (M)

- **What it is.** The finish line as a gate, not prose: a new checker
  (e.g. `bin/weizigo-w3gate`, claimlint-style, own file) that exits 0 **iff**:
  1. every live register row carries a W3 disposition (re-affirmed / demoted / retired /
     SUPERSEDED) whose evidence cites a post-W3-03 run — mechanically: a `w3:` evidence tag
     or dated disposition column the checker validates; C7 = 0, C9 = 0, C1a = 0;
  2. the reconciled kill matrix (W3-01) is the one C8 reads, and its SURVIVES entries each
     name their closed promotion gate;
  3. the battery fast path is green at all four sizes and the slow-sweep baselines read
     PASS (unchanged-from-baseline);
  4. each L2-remainder item — I11-exhaustive, KO_SENSITIVE ruling, #2 auditor — carries
     either a discharge record (denominator included) or a **ratified** open-disposition;
     an unratified open item fails the gate;
  5. claimlint at floor, calibration PASS.
- **Controls.** *Known-bad:* a fixture register with one row's status flipped without a
  W3 disposition must fail the gate (red-then-green, wired into `zig build test`).
  *Null:* HEAD passes or prints its honest red census — a gate that cannot name what is
  red is a stub (`CODE.BATTERY-STUBBED` is the family scar).
- **Holds.** The new checker file + its fixture.
- **Needs.** All of W3-01…W3-12 (it is the last row).
- **Acceptance.** The gate command exists, its two controls fire, and its verdict on
  post-W3 HEAD is recorded in the synthesis package. "Waypoint 3 complete" is then a
  sentence with an exit code.

---

## 2. Sequencing rationale — what unblocks what, and where the Waypoint-2 debt sits

```
W3-01 (kill matrix)  ── promotion currency for every promotion below
W3-02 (phantom row)  ── independent, XS, anytime before synthesis
W3-03 (harness)      ── the instrument; needs nothing, cited by everything
  ├─ W3-04 (2×2) ─┐
  ├─ W3-05 (3×2) ─┤  shake-out order cheapest-first; concurrent once green per size
  ├─ W3-06 (3×3) ─┤
  ├─ W3-07 (4×4) ─┘
  ├─ W3-08 (4×3 + size brief)   ── needs W3-03's flag; ruling queued, not blocking
  ├─ W3-09 (NC1–NC5)            ── same runs, distinct file; with or after the batches
  ├─ W3-10 (I11 exhaustive)     ── needs W3-01 + W3-03 + W3-07; sizing gate inside
  ├─ W3-11 (Track A bundle)     ── needs W3-07; ruling queued
  └─ W3-12 (#2 auditor)         ── needs W3-01 + W3-03 + W3-07
W3-13 (finish gate)  ── needs all
```

- **Mutation adequacy (brief says 6/10).** It is W3-01, and it goes first because edge 5
  makes it the only currency every later promotion is paid in. The 6/10 figure is T475's
  correction (2026-08-19); T530 then claimed 10/10 (2026-08-20) and the C8 single source
  still says 3/10. **The number is contradictory at HEAD; W3-01 exists to make it one
  number again.** Nothing should promote on any of the three figures until it does.
- **The seven closed promotion gates.** Not a separate task — a *function of W3-01's
  verdict*: T291's 3/10 closed seven gates; 6/10 closes four; a reproduced 10/10 closes
  none and re-opens the A2/A5/A8-exhaustive and BUILD-REPRO promotions inside W3-07. The
  spec's only commitment is that the count is computed from a reconciled matrix, never
  quoted from memory.
- **T430's unexecuted phase-2 audit.** Discharged by evidence, not execution: delivered
  under T433; the pointing row is a phantom (W3-02). Placing it early is pure hygiene — it
  costs XS and removes a dead row from the synthesis surface.
- **Why the ladder order is not an epistemic gate.** Per-goban independence (AGENTS.md)
  forbids inheriting 2×2's verdicts at 4×4; the ordering is engineering risk-ordering —
  harness defects surface at the size where a rerun costs seconds. The one real
  within-ladder dependency is mechanical: W3-03's per-size green is each batch's hard
  `needs`.
- **Concurrency.** File ownership serializes, not phase numbers (Amendment 2): the size
  batches touch disjoint evidence dirs and findings files; the register is written only by
  the standing absorption pass. W3-10/W3-12 both read the 4×4 table but write disjoint
  files; they may overlap after W3-07.

## 3. Controls — per never-trust-a-green-test

| instrument | reused as-is? | null control | seeded-defect control |
|---|---|---|---|
| Battery I1–I12 + pass1 mutants + golden-master baselines | **yes, as-is** (fast path in `zig build test`, sweep behind `battery-sweep`) | baseline comparison PASS = unchanged | the 10 catalogue mutants; T530's four fixtures re-verified live by W3-01 |
| claimlint C0–C14 | **yes, as-is** | calibration PASS at HEAD (verified 2026-08-23) | its own known-bad/known-good calibration suites (C14 arms, T669) |
| Closure C-A1/C-A2 (`vb_closure.zig`) | **yes, as-is** | 0/0 on canonical artifacts, denominators recorded | M8 deleted-entry fixture (kills it — recorded 2026-08-05) |
| Key agreement (T267 invariant, `keybyte_differential.zig`) | **yes, as-is** | producer==consumer over all keys at 4×4/4×3 | M1/M2/M3/M4 kill fixtures (W3-01 re-runs them) |
| I11 (`vb_i11.zig`) | **yes, as-is** (exhaustive mode is W3-10's addition) | 0/N sampled, denominator in every line | allows-suicide mutant → 1/114 (T346, recorded) |
| W3-03 composed runner | **new** | reproduces golden-master baselines exactly | strong value-corruption w/ repaired checksum + one key-encode flip, per size — must go red |
| W3-13 finish gate | **new** | HEAD passes / honest red census | seeded stale row (status flip, no disposition) must fail the gate |
| #2 auditor (W3-12) | **existing discipline, fresh run** | zero violations on the sampled depth, denominator stated | the QA-023 scar is its calibration story: an impossibly clean counter (1133/1133 TIE) is treated as a red flag, not reassurance |

Standing rule inherited by every row: a control that cannot run must **fail loudly**, never
pass vacuously; and any counter that is impossibly clean (0 budget-exhausted on an
exponential harness) is itself a finding.

## 4. The finish line — mechanized

"Waypoint 3 complete" **is** `bin/weizigo-w3gate` exiting 0 (W3-13's five conditions). Not
a paragraph. The gate is registered and mechanized the day it is declared (DIRECTION §5
standing policy), with its known-bad fixture wired before its first reading counts. Its
verdict — pass or honest red census — is the single artifact the synthesis package quotes.

## 5. OPEN — assumptions I could not verify

1. **The live kill rate.** Three figures coexist at HEAD (3/10 in `kill-matrix.json`,
   6/10 per T475, 10/10 claimed by T530). I did not re-run the fixtures — that is W3-01's
   entire deliverable, and every promotion in this plan waits on it.
2. **Z's size set vs 4×3.** AXIOMS §1 names four sizes; the register carries 14 4×3-scoped
   rows plus heavy 4×3 evidence. Operator ruling requested (W3-08); this spec does not
   presume the answer and schedules the rows either way.
3. **"Waypoint" vs "Phase".** No ratified rename text exists in `docs/` (grep for
   "Waypoint" at HEAD returns only the race briefs); DIRECTION.md still says Phase. Treated
   as synonymous per this brief; the rename sweep is L5 (one rulebook) work, not ours.
4. **Row count.** 231 live rows (claimlint C0 at HEAD, 2026-08-23) — the brief's "231" is
   current; the tree-map's "228" (§3) is a stale snapshot, as its own prose anticipates.
5. **Artifact of record.** I assumed the k=1 reverification target at 4×4 is
   `untracked/oracle-v2/oracle-4x4-v2.wzo2` (0c3366f0, byte-reproducible per
   `CODE.WZO2-BUILD-REPRO`). If the seat names a different artifact, every per-size batch's
   evidence paths change; nothing else does.
6. **W3-10's cost.** Unestimated until its sizing pass runs (~600M children). The row is
   written to survive an honest "does not fit" — but a deferral does not discharge L2, and
   the finish gate will say so.

## 6. What this spec deliberately does not do

- Does not register any kanban row (Race-I rule: the seat synthesizes, the operator
  ratifies).
- Does not change any register status, edge, or tree mapping; proposes no findings JSON
  (no claim about the engine is made here).
- Does not re-audit any row by prose — every disposition in the plan traces to a run that
  can fail, which is the whole content of Waypoint 3.
