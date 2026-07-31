# CURRENT — in-flight task status (ephemeral; updated often)

**Purpose:** the single file a fresh session reads to resume *without loss*
after a context clear / compact / handover. Not durable — milestones live in git +
`../epistemic/PROGRESS.md` + `../decisions/` + `../research/`. If this file is stale, read
`../epistemic/PROGRESS.md` → `leak-crisis.md` and rebuild it.

Last refreshed **2026-07-31 (late)** (Fable/Consul — sprint state + absorption
catch-up, after the 39-task absorption audit).

# STATE AS OF 2026-07-31 (late) — Fable/Consul

## Two Tier-A sprints in flight — both M1 designs at G2 (human ratification pending)

**Doc convention** (`docs/infra/sprint.md` rev 4, **RATIFIED** `d53c2a8`):
canonical unsuffixed docs live in `docs/infra/<sprint>/pass0/`; audit/revision
ephemera in `docs/design/<sprint>/archive/`; ephemera deleted or archived at
gate commits. Older documents may cite pre-reorg paths — the moves were all
`git mv` (`e6c6bf9`, `45deb10`).

- **oracle-v2** (ko-aware rebuild, WZO2 bracket-carrying format):
  `docs/infra/oracle-v2/pass0/{spec,strategy,design-M1}.md`. design-M1 at
  **rev 3** after three audit rounds (T142/T146/T150); G2 = diff review, no
  fourth round. Spec A6 amended in place, amendment rides the same G2.
  **M2a is done**: `src/exp6_solve.zig` now exposes a public fixpoint
  interface (T140, 79 `pub` decorations; verified byte-identical by fresh
  seat T155 — gate chain 2×2=0, 3×2=0, 3×3=+9 reproduced, 4×4 census
  identical). M2b dispatchable the moment G2 clears.
- **verify-battery** (fleet re-verification instrument):
  `docs/infra/verify-battery/pass0/{spec,strategy,design-M1,i5-feasibility}.md`.
  design-M1 at **rev 2 + rev-3 patch** (T156 schema-field closures), audit
  T151 **PASS**; the JSON-Lines result schema freezes at G2. Acceptance
  criteria AC-S1 / AC-S3 / AC-S4 are still open and tracked only in the
  archived audit — carry them into the G2 review.

## Decisions the human owes

1. **G2 ratification ×2** — both design-M1 docs above.
2. **WZO1 cannot answer bracket invariants**: every committed artifact stores
   the TIE-resolved pin (single V), not `[L,H]` — so `L ≤ H`, median-pin and
   L/H-residual checks are uncomputable from committed evidence and 10 of the
   60 fleet-matrix cells are unreachable until WZO2 exists. Options on the
   table (verify-battery `pass0/design-M1.md` §agenda): wait-for-WZO2 vs a
   ~250–350-line solver-side L/H dump.
3. **ADR-0020 amendment (G1)**: the "24 mismatch states as permanent
   calibration fixture" clause was withdrawn by `GLOBAL.BRUTE-ALIASING`
   (T102: all 24 were checker artifacts; true gap **0/172** — the fixture
   should be an *agreement* fixture). Flagged independently by T133, T136,
   T137. Amendment text is **drafted, uncommitted** in the working tree
   (Orcha) — needs your ruling before it lands.

## PROPOSED specs awaiting their spec gate

- **orcha-tools** — `docs/infra/orcha-tools/pass0/spec.md`. **Implemented**
  (T159, absorbed `082433e`): `managent suggest`, done-deliverable check,
  audit cross-citation flag; reviewed T160. Its A3 acceptance fixture was the
  QA-027-not-absorbed defect, which is now fixed (`622275f`) — the tools
  exist to catch the next one.
- **argus** — `docs/infra/argus/pass0/spec.md` (read-only watchdog, 14
  requirements, cheap-tier). Spec audited T161.
- **project-restructure** — `docs/infra/project-restructure/pass0/spec.md`
  (3 items, "do nothing" explicitly acceptable). Spec audited T162 (PASS).
  Item 2 touches ~890 references to the epistemic tree — see spec §risks
  before any ratification.

## Absorption catch-up (per the 2026-07-31 Fable audit of all 39 DONE tasks)

The audit found everything after T129 was commit-only (deliverables committed,
findings never pushed into CLAIMS/PROGRESS/CURRENT). Recovery in flight:

- **Done (Fable, `622275f`)**: `QA-027` → **FALSE-AS-SCOPED (at 4×4)** —
  T129 measured certified fraction 10.71%, the median-pinned V is not
  Bellman-chainable at bracket-valued states; `QA-020` gained the new-rule
  re-test datum; PROGRESS.md §6/§7.4 updated and cite-tagged.
- **T163 (Orcha, holds `docs/epistemic/CLAIMS.md`)**: mechanical register
  batch — T138 census annotations (36-phantom identity on the four
  `2232/322/34/34` rows; new rows for 1,678 cycle-reachable / 1,676 max-SCC),
  `GLOBAL.H1-CENSUS` ×2-arithmetic caveat, `4x3.S3a` A094777-is-square-only
  caveat, T134 I5-feasibility row (~1.2–1.5 GB peak vs 4 GB cap), the
  `passes ≥ 1 ⇒ ko_point = none` invariant row, G-at-4×4 bracket row
  (23,802,969–24,318,165), T128 triage application, checkpoint SHA-256s.
  **Caution:** `untracked/c2pilot_3x2.zig` is claimlint's known-bad C2
  calibration fixture — applying T128's re-point recommendation to it would
  break the calibration suite.
- **T164 (Orcha, holds `docs/infra/model-perf.md`)**: backfill T142–T158,
  including T152's model-allocation findings.
- **Claimlint gate**: run `bin/weizigo-claimlint` after every CLAIMS.md edit.
  Current state: C6 = 0 (clean); pre-existing FAILS are 10 C1a orphans +
  13 C2 dangling paths — that is exactly the T128 debt T163 clears.

## Concurrency — live file owners

- `docs/epistemic/CLAIMS.md` — **T163** (uncommitted edits in the tree now).
- `docs/infra/model-perf.md` — **T164**.
- `docs/status/CURRENT.md` — this rewrite (Fable/Consul).
- `src/managent/main.zig` — T159 hold cleared at `082433e`.
- Kanban caution: T140/T141/T144/T145/T146 in the *current* queue are
  orcha-tools **test fixtures** with reused IDs, not the historical tasks of
  the same numbers.

---

## T129 (DSPro/T129) — EXP-7 4×4 re-run — DONE 2026-07-31

Result: certified fraction = 10.71% (3,000/28,000 fresh-start nodes) under oracle.
QA-027 is FALSE at 4×4 `[QA-027:FALSE-AS-SCOPED]` — absorbed into the register
at `622275f`. V-domain Bellman identity fails at bracket-valued states.
Deliverables: docs/evidence/QA-027/4x4/, docs/research/newrule-certified-fraction-4x4-2026-07-31.md.
Ownership of src/t129_exp7_4x4.zig cleared.

---

> # STATE AS OF 2026-07-31 — DSPro/T127 refresh
>
> **All previously-superseded blocks below the 2026-07-29 "Opus/Orcha" top block
> have been deleted.** The T100–T126 wave is now fully absorbed into
> `PROGRESS.md` and `CLAIMS.md`; the superseded dated sections (2026-07-29
> Orchestrator succession, EXP-10, EXP-8, host-panic-recovery, EXP-2A, EXP-3,
> EXP-2 dispatch records, and the 2026-07-27 evening session) described states
> that either concluded or were superseded by later findings. Historical
> context lives in `model-perf.md:2163–2470` (per-task ledger of all 60 purged
> tasks). The kanban was purged by T120; new tasks registered T121–T129.
>
> ## The keystone: ADR-0020 (loopy-game fixpoint semantics)
>
> ADR-0019 (first-revisit truncation) is superseded. Under ADR-0020, cycles
> do not terminate the game; the value is the limit of the iterative Bellman
> operator on `(board, side, ko_point, passes)`. This representation **is**
> Markovian, convergent by Knaster–Tarski, and tractable through 4×4.
>
> ## T100–T126 wave summary
>
> **32 tasks across 7 models** (2026-07-30), plus the T120 absorption audit
> that registered T121–T129. Key findings now in `PROGRESS.md`:
>
> | finding | source |
> |---|---|
> | 4×4 root V=+1 (bracket [+1,+16]), H=+16 verified genuine | EXP-6, T104 |
> | T13 reproduced; 154/508 (30.3%) history-sensitive, not 12 | T110 |
> | ADR-0006 not falsified; 3 corrections; new PRUNE-ALL hazard class | T114 |
> | 4×4 ko-sensitive region 99.997% single-ko | T117 |
> | brute-force corroboration withdrawn across EXP-4→EXP-7 | T102 |
> | all five T101A evidence-free PROVEN rows closed | T105/106/107/111/112 |
> | `.wzo` artifact written, 258 MB, SHA-256 verified | T113 |
> | ADR-0020 loopy-fixpoint semantics accepted | DSPro/Orcha |
>
> ## The EXP-4→7 gate chain — complete
>
> | goban | root | status |
> |---|---|---|
> | 2×2 | 0 (TIE) | `2x2.BASICKO-TIE` MEASUREMENT |
> | 3×2 | 0 (TIE) | `3x2.BASICKO-TIE` MEASUREMENT |
> | 3×3 | +9 (matches MIGOS II) | `3x3.BASICKO-TIE` MEASUREMENT |
> | 4×4 | +1 (NOT +2 — ruleset difference) | `4x4.BASICKO-TIE` MEASUREMENT |
>
> **⚠ Brute-force cross-check withdrawn across the entire chain.** See
> `GLOBAL.BRUTE-ALIASING` in `CLAIMS.md`. Fixpoint results are independently
> verified and stand.
>
> ## Artifact
>
> `data/oracle-4x4-basicko-tie-area.wzo` — 258,280,358 bytes, SHA-256
> `edd9f68ef243f67de21152432f9e8f521536317527d425208e6901f90b11c0cc`.
> Rules ID 2 (basic-ko + TIE=0). 48.5M fresh-start states, 31 sweeps.
> PROVENANCE: `docs/evidence/QA-026/4x4/ARTIFACT-PROVENANCE.md`.
>
> ## Open items (post-T126) — **superseded 2026-07-31 (late)**
>
> T128 and T129 are DONE (see above). The surviving open items, restated:
> **4×4 writes-off regen** (D3) `[4x4.D3:UNTESTED]` · **FP1 acceptance
> checks 1–2** (post-hoc from T104 output) · **PSK-divergence measurement**
> (EXP-8: harness built, new-rule tables now exist) · **4×4 S2-impl / S3b**
> untested · **ADR-0006 residual** (ko-sensitive region and 5×5 — note the
> WZO2 u32-colex format caps at 20 cells, so 5×5 needs a format change) ·
> plus the sprint/gate items in the top block.
>
> ## Read next
>
> `docs/epistemic/PROGRESS.md` (just refreshed) ·
> `docs/decisions/ADR-0020-loopy-game-fixpoint-semantics.md` ·
> `docs/audits/eye-prune-validation-2026-07-30.md` ·
> `docs/evidence/T13/probe-reimplementation-2026-07-30.md` ·
> `docs/research/ko-composition-census-2026-07-30.md` ·
> `docs/audits/audit-2x2-mismatch-2026-07-30.md` ·
> `docs/infra/model-perf.md` (T100–T126 per-task ledger)
>
> ## Concurrency — **superseded 2026-07-31 (late)**
>
> See "Concurrency — live file owners" in the top block. Check
> `bin/managent status` before touching any held file.
>
> ## Claimlint
>
> Run `bin/weizigo-claimlint` after any CLAIMS.md edit. C6 must be clean
> (every cite-tagged sentence in this file cross-referenced against the
> register). New rows must not add C1a orphans or C2 dangling paths.
>
> ## The queue is a *kanban*; the playing surface is a *goban*
>
> `bin/managent` is the **kanban** — tasks, sets, holds, needs, claims.
> The Go playing surface is the **goban** (2×2, 3×2, 4×4, etc).

---

## Historical — 2026-07-29 and earlier (superseded)

All dated sections that were below the 2026-07-29 top block have been
deleted by T127. They described states that were either completed
(T100–T126, purged by T120), superseded (ADR-0019 → ADR-0020, the
Orchestrator succession handover), or absorbed into PROGRESS.md. The
per-task ledger survives in `docs/infra/model-perf.md:2163–2470`.
The handover file `docs/status/handover-minimax-m3-2026-07-29.md`
remains on disk for procedural context.

### Completed 2026-07-28

- EXP-2A (Fable 5) — Part A proof, REPAIRABLE-GAPS→repaired
- EXP-3 (Minimax-m3) — kostate census, GO on dense addressing at 4×4

### Completed 2026-07-29 (host-panic-recovery)

- EXP-9 (Opus 5) — H5a Session.choose mitigation
- EXP-12 (Kimi-k3) — denominator sweep
- B-2 RSS runner (`tools/runner`)
- managent schema + dispatch command
- Host incident record

### Completed 2026-07-30 (T100–T126 wave)

All 32 tasks. Per-task details in `docs/infra/model-perf.md` and `PROGRESS.md`.
Key deliverables: T13 reproducible (T110), ADR-0006 validated (T114),
ko-composition census (T117), EXP-4→7 gate chain complete, .wzo artifact
written (T113), T101A punchlist closed, brute-force aliasing withdrawn
(T102), ADR-0020 accepted.
