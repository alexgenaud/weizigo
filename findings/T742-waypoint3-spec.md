# Waypoint-3 decomposition spec — T742 (race-I spec lane)

```
Task:   T742 · Role: worker (leaf) · Worker: deepseek-v4-pro/T742 · Date: 2026-08-23
Status: PROPOSAL — one of five independently authored lanes; the seat synthesizes and
        the operator ratifies. Written to the lane's output file only; no other lane's
        spec was read, no kanban rows were registered.
Inputs: untracked/race-i-waypoint3-brief.md (shared)
        docs/audits/2026-08-02-grand-audit/DIRECTION.md (ratified program + Amendments 1–2)
        docs/epics/E1-markovian/PHASES.md · docs/epics/E1-markovian/AXIOMS.md (requirement tree)
        docs/epistemic/CLAIMS.md (register) · docs/epistemic/register-tree-map.md
        docs/epistemic/SOLUTION-TREE.md (T415 — the construction tree + §8 outstanding proofs)
        docs/epics/E1-markovian/sprints/verify-battery/pass1/spec.md (I1–I12, A1–A6)
        docs/epics/E1-markovian/sprints/g3b-value-correctness/pass0/accept.md (G3b discharge + scope limits)
        docs/infra/GLOSSARY.md · docs/epistemic/GLOSSARY.md (reserved terms)
```

## 0. What Waypoint 3 is, and the honest deliverable it reverifies

DIRECTION §5 Phase 3, as ratified: **ladder 2×2 → 3×2 → 3×3 → 4×4; kernel vs fixtures
differentially at every rung; every register row re-derived, demoted, or retired against
the requirement tree.** It has never been decomposed into registerable work (PHASES.md:
"not decomposed"). This spec decomposes it.

The register this reverifies is **231 live rows** (claimlint C0 `rows parsed: 231`, run
2026-08-23 this session; the C0 print is authoritative and changes as absorption proceeds,
so every downstream count in this spec keys off C0 at gate-run time, never a prose constant).

Two rulings fix the *object* of reverification and must not be re-litigated in the rows below:

- **G3b is discharged** (accept.md signed 2026-08-05): `4x4.C1`, `4x4.FP1` → CLAIMED with
  four scope limits; **nothing at 4×4 is PROVEN**, CLAIMED is the ceiling pending Phase 3.
- **Track A is discharged by provenance** (T472, 2026-08-19): the 3,455,412-entry
  KO_SENSITIVE column of `data/oracle-4x4-v2.wzo2` is the ADR-0020 pure loopy-game fixpoint
  bracket, never the finisher's output. `memo_writes=false` is a `retro.zig` finisher flag;
  this artifact never ran a finisher, so "Track A regen" is a category error against it. The
  old checkpoints (`data/oracle-4x4.checkpoint.wzo` and the WZO1-era small artifacts) keep
  their writes-ON taint, and the **#2 auditor gate (T467 remainder T-c) is still owed.**

The reverification's honest target is therefore not "promote everything to PROVEN". It is:
**every live register row reaches a terminal status (PROVEN / FALSE-AS-SCOPED / FALSE /
INTRACTABLE / MEASUREMENT / SUPERSEDED / RETIRED / CLAIMED-as-honest-ceiling), no UNTESTED
survives, every instrument that produced a reading is controlled, and the finish-line gate
is mechanized.** The fresh-start-only, per-goban, no-real-game-value foreclosure (NC1–NC5,
`AGENTS.md`) is the frame; a row that asserts more than fresh-start correctness is demoted,
not re-verified into a stronger claim.

---

## 1. The finish line — a mechanized gate, written first

Per DIRECTION §5 ("every gate in this plan is mechanized from the day it is declared"),
the gate ships **before** any reverification row, so every later row has somewhere to
record its verdict and the waypoint's "complete" is a binary, not prose.

### 1.1 The ledger

`docs/epics/E1-markovian/waypoint3/ledger.json` — one entry per live register row. The
authoritative row set is claimlint C0 at gate-run time (no prose constant can drift). Entry:

```json
{
  "id": "4x4.C1",
  "disposition": "RE-DERIVED",
  "status_after": "CLAIMED",
  "instrument": "g3b-battery:I4,C-A1,C-A2,I5,key-agreement",
  "evidence": "docs/evidence/4x4-C1/PROVENANCE.md",
  "findings": "findings/W3XXX-table.json",
  "null_control": "docs/evidence/4x4-C1/null-control.log",
  "seeded_control": "docs/evidence/4x4-C1/seeded-control.log",
  "auditor": "deepseek-v4-flash/W3-5-AUDIT",
  "open_precondition": null
}
```

`disposition` ∈ {`RE-DERIVED`, `DEMOTED`, `RETIRED-CONFIRMED`, `HELD`, `MEASUREMENT`,
`DEFINITION`, `FALSE-HELD`}. `open_precondition` is `null` for a finished row, else the
named unmet promotion precondition (e.g. `"Track A regen"`, `"mutation M1"`).

### 1.2 The gate binary `weizigo-reverify-gate`

Reads the ledger + runs claimlint C0 + reads the kill matrix. Fails loudly, each rule with
its own count, never a silent pass:

- **R1 — coverage.** Every C0 row has exactly one ledger entry; no extras. (A dropped row
  or a stale extra fails.)
- **R2 — drift.** Every entry's `status_after` equals the register's current status for
  that row. (The ledger is a *proposal record*; the register is the ratified belief. Drift
  means absorption lag, which fails the gate.)
- **R3 — no UNTESTED.** No live row's register status is `UNTESTED`. DIRECTION's stance is
  "every row re-derived, demoted, or retired" — an UNTESTED survivor means the waypoint is
  unfinished, not that the row is unknowable.
- **R4 — no open precondition.** No entry has a non-null `open_precondition`.
- **R5 — controlled instruments.** Every entry with `disposition == RE-DERIVED` carries a
  committed `null_control` and `seeded_control` path, both resolving under `docs/evidence/`.
- **R6 — auditor.** The `#2-auditor` entry records 0 minimax-identity violations with
  denominators (3×2 exhaustive + deepest-N 4×4 sample).
- **R7 — mutation adequacy.** No PROVEN row's covering mutants are unkilled (the kill
  matrix is 10/10 for every promoted claim's functions).
- **R8 — floors.** claimlint at floor (C1a=0, C1b=0, C6=0, C9=0) with calibration PASS;
  `zig build test` green.

### 1.3 Controls for the gate itself (never-trust-a-green-test)

- **Null control:** an empty ledger must exit non-zero naming R1.
- **Seeded controls:** a ledger with one row dropped (R1), one `status_after` falsified
  (R2), one `open_precondition` left set (R4), or one RE-DERIVED entry stripped of its
  control paths (R5) must each exit non-zero naming the rule.

Worked example (the gate's own acceptance run):

```sh
bin/weizigo-reverify-gate --ledger docs/epics/E1-markovian/waypoint3/ledger.null.json   # → exit 1 "R1: 231 rows missing"
bin/weizigo-reverify-gate --ledger docs/epics/E1-markovian/waypoint3/ledger.drift.json  # → exit 1 "R2: 1 drift"
bin/weizigo-reverify-gate --ledger docs/epics/E1-markovian/waypoint3/ledger.json        # → exit 0
```

---

## 2. The ordered, registerable row set

Nine rows. Each is one bundle, one managent set (holds), no human mid-flight. Batching is
by claim family per the tree: one instrument covers many register rows. Titles ≤ 40 chars.

| # | slug | title | size | needs |
|---|---|---|---|---|
| W3-1 | `w3-gate` | Reverification gate + ledger | S | — |
| W3-2 | `w3-kernel` | Kernel joint well-definedness diff | L | W3-1 |
| W3-3 | `w3-persist` | Persist basic-ko WZO2 at 2x2/3x2/4x3 | M | W3-2 |
| W3-4 | `w3-fix` | Convergence reverify (seed+fixpoint) | M | W3-2, W3-3 |
| W3-5 | `w3-table` | Table faithfulness+completeness reverify | M | W3-4, W3-3 |
| W3-6 | `w3-auditor` | #2 auditor on the k=1 build | M | W3-2, W3-4 |
| W3-7 | `w3-mutants` | Kill M1/M2/M3/M4 (G1/G3 adequacy) | S | W3-2 |
| W3-8 | `w3-nonclaims` | Non-claims re-derivation (Z-NONCLAIMS) | L | W3-5 |
| W3-9 | `w3-retire` | Retirement dispositions confirmed | S | W3-1 |

Concurrency: W3-7 and W3-9 are parallel-safe with W3-3…W3-6 and W3-8 as long as file holds
don't collide (they don't; each holds its own file). The real serializer is file ownership,
not row number (DIRECTION Amendment 2).

### W3-1 `w3-gate` — Reverification gate + ledger

- **Deliverables.** `src/reverify_gate.zig`, `bin/weizigo-reverify-gate`,
  `docs/epics/E1-markovian/waypoint3/ledger-schema.md`, the four control ledgers
  (`ledger.null.json`, `ledger.drift.json`, `ledger.open.json`, `ledger.nocontrols.json`),
  wired into `zig build test`.
- **Holds.** `set=w3-gate`; owns `src/reverify_gate.zig` and the ledger-schema doc. Touches
  `build.zig` (serialize through the Orchestrator — single-writer file).
- **Needs.** none (the register + tree + C0 exist).
- **Acceptance.** `zig build test` green; the four control ledgers each exit non-zero
  naming their rule; a synthetic complete ledger exits 0; rules R1–R8 implemented and each
  prints its own count on failure.
- **Instruments + controls.** The gate is itself the new instrument; its controls are §1.3.
- **Size.** S.

### W3-2 `w3-kernel` — Kernel joint well-definedness diff

- **What it reverifies.** The entire Z-R family (A1–A6, B1–B3, C1–C4, D1–D3), Z-R-SIGN,
  Z-STATE-LEGAL (S1/S3a colex + legality), Z-R-SCORE (S4 area scoring), Z-STATE-KEY. Closes
  register-tree-map §5 gaps #1 (no row asserts the axioms *collectively* define a
  self-consistent ruleset — the AXIOMS §2 "seventeen-copy comparison" T273 did not deliver)
  and #2 (Z-STATE-KEY under adversarial move selection). **This row IS the unexecuted
  DIRECTION-Phase-2 execution audit** (see §5 OPEN-2).
- **Deliverables.** A differential runner comparing the production kernel move/ko/scoring/
  state-key functions against every demoted fixture (the ~17 ko copies, exp4/5/6/7, the
  brute forcers) at every size where both run — 2×2/3×2/3×3 exhaustive, 4×3/4×4 sampled with
  stated denominators; evidence under `docs/evidence/W3-KERNEL/`; a new battery invariant
  `vb_keyagree` (the G1/G3 cell — producer/consumer key parity, the T178/T193/T265 family
  that has zero battery coverage today); findings for every Z-R/Z-STATE/Z-R-SIGN row.
- **Holds.** `set=w3-kernel`; owns the new differential file and `src/vb_keyagree.zig`.
- **Needs.** W3-1.
- **Acceptance.** 0 kernel-vs-fixture mismatches at every size (denominators stated); the
  `vb_keyagree` invariant kills its seeded mutant (flip one key bit → `key_mismatches > 0`);
  the differential's null control (kernel vs an alias of itself → 0) and seeded control
  (a deliberately-broken kernel copy → mismatches) both fire red-then-green; `zig build test`
  green.
- **Worked example** (null vs seeded): run the diff with the fixture slot replaced by a
  passthrough alias of the kernel — must report 0 (proves independence sensitivity); then
  with one ko-copy's `liberties==1 && friendly==0` check deleted — must report > 0.
- **Size.** L (17 fixtures × 5 sizes is the bulk).

### W3-3 `w3-persist` — Persist basic-ko WZO2 at 2x2/3x2/4x3

- **What it reverifies.** Z-COMPLETE / Z-TABLE-FAITHFUL at the sizes that today have **no
  current-rule artifact** — SOLUTION-TREE §8b.3: the basic-ko + TIE=0 tables at 2×2/3×2/4×3
  exist only in evidence, so those sizes cannot be reverified against a persisted object.
  This row produces the objects (no silent writes: new files, tagged `(size, ruleset)`,
  hashed; never overwrite).
- **Deliverables.** `artifacts/oracle-2x2-v2.wzo2`, `artifacts/oracle-3x2-v2.wzo2`,
  `artifacts/oracle-4x3-v2.wzo2`; SHA256SUMS entries appended (new files); build provenance
  evidence under `docs/evidence/W3-PERSIST/`.
- **Holds.** `set=w3-persist`; no `src/` ownership (runs `oracle_v2_build.zig`); the
  SHA256SUMS append serializes through the Orchestrator.
- **Needs.** W3-2 (trust the builder's kernel before trusting its output).
- **Acceptance.** Each artifact loads with 0 misses / 0 fallbacks; root values match the
  committed anchors (2×2 +1, 3×2 +1, 4×3 bracket, per `GLOBAL.MIGOS-RULE`); byte-reproducible
  across two independent builds; hashes recorded. **OPEN:** whether the 4×3 WZO2 build fits
  the runner's 4 GB RSS / budget — if not, 4×3 reverification stays on the WZO1 oracle with
  its documented format boundary, and that fallback is recorded, not silent.
- **Controls.** Null: a build with a flipped flag must produce a different hash (the
  reproducibility check fires). Seeded: an intentionally-corrupted artifact must fail load
  or root-anchor.
- **Size.** M (the 4×3 build is the cost; needs a persistent session).

### W3-4 `w3-fix` — Convergence reverify (seed+fixpoint)

- **What it reverifies.** Z-CONVERGE-SEED (closes 4x4.FP1-C1/C2 — seed provenance from
  −N/+N and final zero-change sweeps, readable from build provenance, never registered),
  Z-CONVERGE-FIX (I3 L≤H, I4 Bellman residual, I5 SCC containment at every rung),
  Z-CONVERGE-MONO/FINITE (re-derive the FP1/FP3 mathematical proofs; re-verify finite-sweep
  counts). Disposes the G3b §3.1 vacuity finding (the 3×2/4×3 I5 seeded-defect premise is
  false in the full-graph model; first genuine red-then-green rung is 4×4).
- **Deliverables.** Seed-provenance evidence per size (build log citing the −N/+N seed
  vectors and the zero-change final sweep); I3/I4/I5 readings per artifact, **ladder-ordered**
  (no 4×4 reading counts until 2×2/3×2/3×3/4×3 pass); the FP1/FP3 proof re-derivations
  committed under `docs/evidence/`; findings for every Z-CONVERGE row.
- **Holds.** `set=w3-fix`; read-only on `src/` (runs the existing battery + differentials);
  owns a seed-provenance runner script if one is written.
- **Needs.** W3-2, W3-3.
- **Acceptance.** Seed provenance recorded per size; I4 0 Bellman violations (denominators,
  ladder order enforced); I5 0 `ko_not_cr` at 4×3 and 4×4; FP1/FP3 re-derived; the vacuity
  finding dispositioned as a corrected spec premise (not waived).
- **Controls.** Reused as-is: battery A1 mutants for I3/I4/I5, plus the demonstrated 4×4 I5
  red-then-green. Seed check's seeded control: a build seeded from (+N,−N) must be detected
  as a seeding violation. Monotonicity is mathematical (FP1 PROVEN) — no battery probe;
  stated as the accepted gap.
- **Size.** M (the 4×4 rebuild is 258 MB / 19 sweeps; persistent session, `tools/runner`).

### W3-5 `w3-table` — Table faithfulness+completeness reverify

- **What it reverifies.** Z-TABLE-ROUNDTRIP (A5), Z-TABLE-FAITHFUL, Z-TABLE-CONSISTENCY
  (I2/I7/I8/I9/I10/I12), Z-COMPLETE-ENUM (C-A1/C-A2 closure), Z-COMPLETE-PASSES. Decides
  the I7 format split (SOLUTION-TREE §8b.4 / T395 §4 proposal 3): adopt A8's DTT recurrence
  as the single definition, or document `CODE.WZO1-DTT-UNSET` as the per-artifact WZO1
  baseline — decided, not left ambiguous.
- **Deliverables.** Roundtrip/consistency/closure readings per artifact (denominators; the
  4×4 closure full run env-gated `WEIZIGO_CLOSURE_4X4_FULL=1`); the I7 decision; findings
  for every Z-TABLE-*/Z-COMPLETE-* row.
- **Holds.** `set=w3-table`; read-only on `src/` except the I7 decision may touch
  `vb_fixpoint.zig` (single-writer via the set).
- **Needs.** W3-4, W3-3.
- **Acceptance.** A5 roundtrip 0; C-A1 0 children-not-in-table and C-A2 0 reachable-not-in-table
  at every size (denominators); I2/I10/I12 0 violations; I9 anchors match committed references
  ruleset-aware; the I7 split decided; **no UNTESTED survives in these node families.**
- **Controls.** Reused as-is: battery A1 mutants; the g3b calibration rule (seed one deleted
  entry → C-A1/C-A2 fire); the 4×4 closure's demonstrated red-then-green.
- **Size.** M.

### W3-6 `w3-auditor` — #2 auditor on the k=1 build

- **What it reverifies.** Z-AUDIT — the mandatory self-consistency gate (AGENTS.md) applied
  to the reconstructed k=1 chain: 3×2 exhaustive + deepest-N 4×4 sample, 0 minimax-identity
  violations. `GLOBAL.AUDITOR`, and the `4x4.F2`/`F3`/`F4`/`4x4.D3` finisher rows now that
  T472 ruled the WZO2 column is fixpoint-provenance (the auditor applies to the fixpoint
  build; the retired finisher regen is not re-opened).
- **Deliverables.** The auditor run + audit-trail evidence with denominators; findings.
- **Holds.** `set=w3-auditor`; read-only on `src/` (runs the existing RETRO_CONSIST auditor).
- **Needs.** W3-2, W3-4.
- **Acceptance.** 0 minimax-identity violations on 3×2 exhaustive + the deepest-N 4×4 sample
  (N and the depth distribution stated); seeded-defect control fires (the `ko_ref >= d` bug
  shape — ADR-0013 — must produce violations); known-good control passes. This is zero
  violations, not "sound by construction."
- **Controls.** Null (known-good → 0) + seeded (known-defective → violations), per standing
  auditor doctrine.
- **Size.** M.

### W3-7 `w3-mutants` — Kill M1/M2/M3/M4 (G1/G3 adequacy)

- **What it reverifies.** The mutation-adequacy promotion gate (DIRECTION Amendment 2 edge 5).
  Waypoint-2 debt: mutation adequacy 6/10, seven promotion gates known-closed (accept.md
  §7 — M1/M2/M4 unasserted, M3 survives). This row builds per-mutant kill fixtures for the
  four, red-then-green, and reconciles the kill matrix to 10/10.
- **Deliverables.** Per-mutant fixtures in `vb_mutants.zig` (or a new mutant file) for
  M1/M2/M3/M4; the reconciled kill matrix (mutants.md == vb_mutants.zig == ledger); findings.
- **Holds.** `set=w3-mutants`; owns the mutant file (serialize with W3-5 only if it touches
  the same file).
- **Needs.** W3-2.
- **Acceptance.** 10/10 mutants killed, each with a named killer and a red-then-green
  demonstration; the three surfaces (mutants.md, vb_mutants.zig, ledger) agree.
- **Controls.** The mutants are themselves the seeded-defect controls (mutation testing);
  null control = the un-mutated fixture passes.
- **Size.** S.

### W3-8 `w3-nonclaims` — Non-claims re-derivation (Z-NONCLAIMS)

- **What it reverifies.** NC1–NC5 — the negative half of Z is as load-bearing as the
  positive. Re-derive, **independently re-implemented against the kernel-as-oracle** (the
  Amendment-1 lesson: re-running the same instrument tests determinism, not correctness):
  T13 at 3×2 (154/508, 4,432 falsifying pairs — a fresh probe, not a replay); the C3/E2
  falsification at 3×3 (12-pt leak); and the currently-UNTESTED per-goban probes — 3×3.C2,
  4×3.C2/C3, 4×4.C2/C3 (4×4 as characterization, not a decision — it is analogy-expected
  falsified, NOT an open hypothesis). Re-confirm NC4 (leak) and NC3 (policy).
- **Deliverables.** Independent probe re-implementations + runs with denominators, evidence
  under `docs/evidence/`; findings for every Z-NONCLAIMS row.
- **Holds.** `set=w3-nonclaims`; owns any new probe file; reuses t13/t389/t412/t416/t419
  instruments as-is.
- **Needs.** W3-5 (the probes read the reverified table), W3-1.
- **Acceptance.** No Z-NONCLAIMS row leaves UNTESTED — each is re-derived to FALSE-AS-SCOPED/
  FALSE with a committed run + denominator, or held with an explicit reason; NC1/NC2
  falsifications reproduce; the 4×4 C2/C3 characterization reports a sample with its
  denominator and is recorded as characterization, not verdict.
- **Controls.** Null: trivial-bounds leak-free (the E2-SANITY pattern — with `lo=−N,hi=+N`
  the policy is leak-free, proving the harness is wired). Seeded: a probe that cannot flag a
  planted divergence is blind and must be reported, not passed.
- **Size.** L (the per-goban probes are the cost).

### W3-9 `w3-retire` — Retirement dispositions confirmed

- **What it reverifies.** The 132 archived + 10 BOGUS rows (register-tree-map §2; adopted
  by T373, "archive, never delete"). Confirms each epitaph resolves against the tree; any
  archived row found load-bearing is an escalation, never a silent re-activation.
- **Deliverables.** A disposition-confirmation note + findings if any escalation fires.
- **Holds.** `set=w3-retire`; read-only on `archives/register/`.
- **Needs.** W3-1.
- **Acceptance.** Every archived row's epitaph resolves against the tree; 0 contradictions;
  claimlint C4 continues to resolve archived IDs as archived (no dangling).
- **Controls.** Reused as-is: claimlint C4/C9 as the mechanical cross-check.
- **Size.** S.

---

## 3. Sequencing rationale

**The dependency DAG** (mechanized as `needs`, never as convention — DIRECTION Amendment 2):

```
W3-1 gate ────────────────────────────┐
   │                                   │
W3-2 kernel ──┬── W3-3 persist ──┬── W3-4 fix ── W3-5 table ── W3-8 nonclaims
   │          │                  │        │
   │          │                  └── W3-6 auditor
   │          └── W3-7 mutants
   └── (W3-9 retire runs parallel, needs only the gate)
```

**Why this order.**

1. **Gate first** (W3-1) is DIRECTION §5 verbatim: a rule that stays prose is a rule we
   have chosen to re-learn. The ledger is the only surface that makes "every row re-derived,
   demoted, or retired" checkable rather than claimable.
2. **Kernel before everything** (W3-2): every downstream re-derivation reads the kernel's
   move/ko/scoring/state-key functions as its oracle. A kernel re-derivation that fails
   demotes the whole Z-R family and stops the ladder at rung 1 — the cheapest place to learn
   it. This is also the ladder's *spine*: DIRECTION orders "kernel vs fixtures differentially
   at every rung" as the first clause of Phase 3.
3. **Persist before fix/table at small sizes** (W3-3 → W3-4/W3-5): 2×2/3×2/4×3 have no
   current-rule artifact; a fixpoint or faithfulness re-derivation at those sizes needs an
   object to check. Persisting them is a precondition, not a nicety (SOLUTION-TREE §8b.3).
4. **Fix before table** (W3-4 → W3-5): table faithfulness presupposes the values are the
   right fixpoint. Verifying a faithful-but-wrong table is wasted work.
5. **Auditor and mutants hang off the kernel** (W3-6, W3-7): the auditor checks the solver
   that produced the fixpoint; the M1/M2/M3/M4 mutants attack the key-agreement function the
   kernel row owns. Both are promotion gates, not reverification in the narrow sense, so
   they are placed to close in parallel with the table/nonclaims sweep.
6. **Nonclaims last** (W3-8): the falsification probes read table values, so they must run
   after the table is reverified; and NC status is the *last* thing to touch, because a
   falsification probe that disagrees with a fresh reverification is a finding about the
   reverification, not a verdict on the non-claim.

**Where Waypoint-2's remaining debt sits.**

- **Mutation adequacy 6/10** → W3-7. It is not a blocker on the reverification sweep (the
  four surviving mutants are the G1/G3 key-agreement cell, which W3-2 now builds the battery
  invariant for); it is a **finish-line precondition** (gate rule R7) on promotion past
  CLAIMED. The seven closed promotion gates are the *consequence* of those four unkilled
  mutants — W3-7 plus R7 opens them, and the promotion itself is applied at absorption after
  the gate passes, not by any worker mid-flight.
- **T430's unexecuted phase-2 audit** → folded into W3-2 (see §5 OPEN-2 for the label
  mismatch). It sits *before* the ladder because auditing the kernel extraction is what
  licenses trusting the oracle every later rung reads.
- **The ladder discipline is per-row, not per-phase.** W3-4 and W3-5 enforce "no 4×4 reading
  counts until 2×2/3×2/3×3/4×3 pass" inside their own acceptance criteria. The phase number
  is not a dependency; file ownership is the serializer (DIRECTION Amendment 2).

---

## 4. Controls — every instrument named, null + seeded, reused-as-is or new

Per never-trust-a-green-test, each instrument in the rows above carries a null control and a
seeded-defect control before its first reading counts. This table is the single source.

| instrument | reused as-is? | null control | seeded-defect control |
|---|---|---|---|
| `weizigo-reverify-gate` (new, W3-1) | new | empty ledger → fail R1 | dropped row / drifted status / open precondition / stripped controls → fail R1/R2/R4/R5 |
| kernel-vs-fixture differential (W3-2) | extends `differential.zig` | kernel vs alias-of-itself → 0 | one ko-copy's `liberties==1 && friendly==0` deleted → > 0 |
| `vb_keyagree` (new, W3-2) | new | producer key == its own alias → 0 | one key bit flipped → `key_mismatches > 0` (T178/T193/T265 shape) |
| builder reproducibility (W3-3) | reuses `oracle_v2_build.zig` + hashes | two identical builds → same hash | flipped flag → different hash; corrupted artifact → load/root-anchor fail |
| verify-battery I1–I12 (W3-4/W3-5) | **reused as-is** (pass1/spec.md A1) | — | A1 synthetic mutant per invariant (one slot corrupted) must be caught |
| closure C-A1/C-A2 (W3-5) | **reused as-is** (`vb_closure.zig`) | — | one entry deleted → `children_not_in_table > 0` and `reachable_not_in_table > 0` |
| seed provenance check (W3-4) | new | build seeded (−N,+N) passes | build seeded (+N,−N) → seeding violation detected |
| #2 auditor (W3-6) | **reused as-is** (RETRO_CONSIST) | known-good build → 0 | `ko_ref >= d` defect shape → violations (ADR-0013) |
| mutation corpus (W3-7) | **reused as-is** + four new fixtures | un-mutated fixture passes | M1/M2/M3/M4 killed, red-then-green |
| falsification probes (W3-8) | **reused as-is** (t13/t389/t412/t416/t419) | trivial bounds leak-free (E2-SANITY) | planted divergence must be flagged |
| claimlint C0/C4/C9 (W3-9, gate R8) | **reused as-is** | — | floor + calibration PASS is its control (C9 row-set equality) |

The reuse-as-is set (battery A1 mutants, closure, auditor, mutation corpus, claimlint) is
the already-calibrated instrument estate from G3b/pass1 — no row re-builds a control that
already fires. The *new* instruments are the gate, the joint kernel diff, the key-agreement
battery cell, and the seed-provenance check; each ships its own null + seeded pair.

---

## 5. Assumptions and OPEN questions

Stated, not silently resolved (the brief's bar):

- **OPEN-1 — row count.** "231-row register" keys off claimlint C0 at this session's run
  (`rows parsed: 231`). The register is live; the gate re-reads C0 at run time so the ledger
  cannot drift from a prose constant. No action needed, stated for the record.
- **OPEN-2 — "T430's unexecuted phase-2 audit".** At HEAD, `T430` is the doctor-console task
  (done, pass-with-findings) and `T433` (bundle `untracked/T430-phase2-audit.md`) is a
  tool-consolidation audit (done) — neither is a DIRECTION-Phase-2 (kernel extraction) audit.
  I read the brief's debt as "the DIRECTION Phase 2 kernel extraction has no execution audit
  (unlike Phase 0's phase0-execution-audit)" and fold it into W3-2. **OPEN if the seat meant
  something else.**
- **OPEN-3 — 4×3 WZO2 buildability.** W3-3 assumes the 4×3 basic-ko fixpoint build fits the
  runner's 4 GB RSS and the session budget. If not, 4×3 reverification stays on the WZO1
  oracle with its documented format boundary (G3b scope limit 2), recorded, not silent.
- **OPEN-4 — I11 exhaustiveness at 4×4.** CLAIMS.md records T473 made I11 exhaustive
  (0/48,636,330 slice records, 0/99,133,036 entries), so W3-5 does not re-specify it; the
  gate R7 (mutation adequacy) is what gates the promotion, not a re-run. **OPEN** only if the
  seat wants an independent re-derivation of I11 rather than a citation of T473.
- **OPEN-5 — promotion is absorbed, not performed by a worker.** Rows propose statuses via
  findings; the register changes by absorption after the gate passes. No worker edits
  `CLAIMS.md`; no human mid-flight. The operator ratifies the waypoint once, at the end.
- **OPEN-6 — new retirements.** W3-8/W3-9 may surface a *new* retirement proposal (a row
  whose reverification shows no tree node). Per register-tree-map, the human rules on
  retirements; to keep the rows human-mid-flight-free, new retirement proposals are collected
  in the ledger's `open_precondition` field and ruled once at the finish line, not per-row.

---

## Landmark

**Landmark:** advances `L2 (proven 4×4 values)` — decomposes DIRECTION Phase 3 (A–Z
reverification) into nine poppable rows with a mechanized finish-line gate, so the operator
can see the path from "231 rows, some PROVEN, some UNTESTED, nothing at 4×4 PROVEN" to
"every row at a terminal status, no UNTESTED survivor, the #2 auditor at 0, mutation
adequacy 10/10" — what still stands between here and L2 is the execution of W3-1…W3-9, and
the gate that says when they are done.
