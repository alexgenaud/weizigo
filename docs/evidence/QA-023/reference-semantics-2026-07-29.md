# QA-023 Part B — reference semantics for history-conditioned evaluation

**Task 2B-0** (Fable 5, 2026-07-29, user-dispatched; see msg 033). Status:
**definitions + code adjudication** — no measurement. Purpose: pin, once, the
semantics every EXP-2B evaluator must implement, and close the design hole
that has produced four thrash incidents on one defect (10h22m `zig test
src/qa023_brute_2x2.zig`, then 75 / 87+11 / 33 min CPU on `smoke-2x2`,
all killed, zero output).

## 1. Definitions

**State.** `σ = (board, side, ko_point, passes)`, per proof-v2 §1
(`docs/evidence/QA-023/proof-v2-2026-07-28.md`). Basic-ko legality is
state-local: a place move is illegal iff the cell is occupied, suicide, or
equals `ko_point` (formalization (i)); pass is always legal, clears
`ko_point`, increments `passes`; `passes == 2` is terminal with Tromp-Taylor
area score. This is exactly `qa023_brute_2x2.zig` `State.apply_place` /
`apply_pass` (2×2) and `qa023_probe.zig` `moves()` (3×2).

**Arrival history.** `h` = the sequence of states from the empty-board root
to σ (exclusive of σ). Only the **visit-set** `set(h)` matters: the
adjudication rule below consults membership only, never order —
order-irrelevance is immediate from the recursion (every reference to `h` is
an `∈` test).

**Adjudication rule (pins QA-023.M2 as a formalization choice).** The
long-cycle verdict under test: the first time the game line revisits any
state already in the whole game line, the game ends immediately with value
`TIE = 0` ("first-revisit truncation", proof-v2 Theorem 6.1).

**History-conditioned value.** For σ with arrival visit-set `A`:

```
V(σ | A) = TIE                                if σ ∈ A          (revisit)
         = area_score(board)                  if passes == 2    (terminal)
         = max over legal children σ' of V(σ' | A ∪ {σ})   if side = Black
         = min over legal children σ' of V(σ' | A ∪ {σ})   if side = White
```

Well-defined and finite: each recursion step strictly grows `A ∩ reachable`,
so depth ≤ |reachable states|.

**QA-023 (Part B restated).** For every reachable σ and every two arrival
histories `h₁, h₂`: `V(σ | set(h₁)) = V(σ | set(h₂))` — and this common value
equals the Part-A fixpoint `median(L(σ), TIE, H(σ))` (proof-v2 Theorem 5.1).
A single within-budget counterexample falsifies QA-023 at that board size.

## 2. The evaluator trilemma, and the honest evaluator

There is **no cheap unconditional reference** for `V(σ | A)`:

1. **Path enumeration** (no memo): sound, but enumerates *paths, not states*
   — finite depth does not give tractable breadth. This is the 10h22m and
   4× smoke failure mode. NONCONFORMING as a pipeline component.
2. **State-keyed memo** `V[σ]`: assumes the value is history-free — assumes
   QA-023. Circular; forbidden (EXP-2A standing instruction in
   `docs/status/CURRENT.md`: truncation keys on the full tuple).
3. **(σ, A)-keyed memo**: sound but the key space is the PSK blowup the
   project abandoned.

**Resolution — two evaluators, two purposes:**

- **The probe evaluator (falsifier):** path-DFS computing `V(σ | A)` with an
  explicit **node budget**; three outcomes per evaluation — `value` / `TIE` /
  `BUDGET-EXHAUSTED` — reported as three separate counts. Budget exhaustion
  is NEVER agreement. A disagreement between two within-budget evaluations at
  the same σ is a genuine counterexample regardless of the budget. Sound as
  a falsifier; supports (never proves) as a sampler.
- **The smoke evaluator (implementation check):** the Part-A fixpoint itself
  (`median(L, TIE, H)` over the full state graph). At 2×2 this is 2,430
  states (81·2·5·3; note `qa023_brute_2x2.zig:236`'s comment says "= 1620",
  a wrong-arithmetic comment, value unused), milliseconds — measured: 7
  sweeps, converged, all five anchors OK (2026-07-29). NOT circular *for the smoke's purpose*: 2×2 admits no
  reachable non-root cycles (`2x2.T12`), and the anchor values are external —
  MIGOS II publishes **0** for 2×2 basic-ko+TIE at komi 0, where PSK ground
  truth is **+1**. The smoke tests the implementation and the ruleset
  discriminator, not QA-023 (per EXP-2B.md: "2×2 is not evidence").

**Smoke expectation table** (2×2, komi 0, TIE = 0):

| state | expected | discriminates |
|---|---|---|
| empty, B to move | **0** | +1 ⇒ PSK implemented by accident |
| empty, W to move | 0 | colour symmetry |
| all-black board, B to move | +4 | area scoring path |
| empty, W to move, passes=1 | 0 | pass bookkeeping |
| empty, passes=2 | 0 | terminal scoring |

## 3. Adjudication of the code in the tree (2026-07-29)

- **`qa023_probe.zig` `truncated_value` (:986) — CONFORMS** to §1's recursion
  and §2's probe evaluator: revisit checked against arrival ∪ continuation
  by full-tuple equality (`fp_eq`), terminal → area, budget decremented per
  node, exhaustion → `null`. Two notes its runner must honour: scratch-stack
  overflow also returns `null` (counted as exhaustion — acceptable, must be
  reported in the exhaustion line, not silently retried); heartbeat is the
  caller's job.
- **`qa023_brute_2x2.zig` `brute_value`/`value` — NONCONFORMING as a pipeline
  component** (trilemma horn 1). Additionally `DEPTH_LIMIT` exhaustion
  silently returns TIE — a truncation-as-value the EXP-2B hard constraint
  bans. The file stays in-tree as EXP-2A's artifact; nothing in EXP-2B may
  call `Brute2x2.value` / `brute_value` (done-check:
  `grep -n "Brute2x2\.value\|brute_value" src/qa023_probe.zig` → 0 hits).
- **`qa023_probe.zig` `fixpoint_kernel` (:718) — is the Part-A object** (the
  thing under test at 3×2); as the 2×2 smoke reference it is legitimate per
  §2. Task 2B-1 rewires B1 (and the three 2×2 zig tests in the same file,
  which also called `Brute2x2.value`) onto a 2×2 instance of it.

## 4. Proposed claim rows (CLAIMS owner folds; not edited here)

- `3x2.QA023.B-VACUITY` — reachable directed cycles exist at 3×2 under basic
  ko (non-zero cycle census). If zero: the board cannot test QA-023;
  escalate, do not pass. UNTESTED.
- `3x2.QA023.B-PROBE` — zero within-budget disagreements across sampled
  (state, history-pair) evaluations; reported with the three-way
  value/TIE/exhausted split and the differing-visit-set pair count. UNTESTED.
- `3x2.QA023.B-CAL-NEG` — the v1 broken rule (`L<H ⇒ T`) fails the §5.3
  synthetic gadget the probe carries (`run_calibrate`). Already demonstrated
  in-code; needs a recorded run.
- `3x2.QA023.B-CAL-POS` — the identical probe machinery run under **PSK
  semantics** reproduces known history-sensitivity at 3×2 (T13: 12 pointwise
  mismatches, `docs/research/c2-falsification-3x2.md`). A probe that cannot
  detect PSK's proven sensitivity cannot clear basic ko. UNTESTED — this row
  is the strongest addition over the prior design.

Per-board independence applies: every row is 3×2-scoped.
