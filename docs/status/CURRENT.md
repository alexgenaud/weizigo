# CURRENT — in-flight task status (ephemeral; updated often)

**Purpose:** the single file a fresh session reads to resume *without loss*
after a context clear / compact / handover. Not durable — milestones live in git +
`../epistemic/PROGRESS.md` + `../decisions/` + `../research/`. If this file is stale, read
`../epistemic/PROGRESS.md` → `leak-crisis.md` and rebuild it.

Last refreshed **2026-07-31** (DSPro/T127 — T100–T126 wave absorption; DSPro/T129 — EXP-7 4×4 re-run DONE).

## T129 (DSPro/T129) — EXP-7 4×4 re-run — DONE 2026-07-31

Result: certified fraction = 10.71% (3,000/28,000 fresh-start nodes) under oracle.
QA-027 is FALSE at 4×4. V-domain Bellman identity fails at bracket-valued states.
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
> ## Open items (post-T126)
>
> - **T128** — claimlint dangling-retire sweep (CLAIMS.md rows with no
>   document citation)
> - **T129** — EXP-7 4×4 re-run (certified-fraction measurement) using the
>   .wzo artifact
> - **4×4 writes-off regen** (D3): untested `[4x4.D3:UNTESTED]`
> - **FP1 acceptance checks 1–2**: can read post-hoc from T104 output
> - **PSK-divergence measurement** (EXP-8): harness built, blocked on
>   new-rule tables — which now exist
> - **4×4 S2-impl / S3b**: untested
> - **ADR-0006 residual**: ko-sensitive region and 5×5
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
> ## Concurrency — no active file owners
>
> No engine file is currently claimed. Check `bin/managent status` for
> in-progress tasks before touching `src/retro.zig` / `oracle.zig` /
> `rules.zig` / `solve.zig`.
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
