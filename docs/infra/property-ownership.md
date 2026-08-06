# Property ownership — one production implementation per property

```
Task:     T395 (does every property have exactly one production implementation?)
Set:      Q
Identifier: flash/T395
Date:     2026-08-06
Landmark: L0 (the table and the instruments exist) — instrument-side twin of L5 (one rulebook)
Acceptance: test -s docs/infra/property-ownership.md
Inputs:   docs/infra/instrument-coverage.md (T388 coverage map + nine divergences),
          docs/evidence/I5-DISAGREEMENT/adjudication-2026-08-06.md (T391),
          findings/T391-context.json, src/i5_differential.zig (T391 template),
          findings/T383-*.json (F-7 key-byte), findings/T267-*.json (key agreement)
```

## The rule this document tracks

> **Every property has exactly one production implementation. Every other
> implementation is a fixture, wired into a differential that fails when the
> two disagree.**

The project's standing doctrine — "never delete redundant implementations;
they are mutual test oracles — one in production, the rest demoted to
fixtures" — was right, and its second half was never implemented until T391:
a redundant implementation is an oracle only if something **runs the
comparison**. Without it, duplication is not redundancy — it is two
independent chances to be wrong, plus a shared `pass` that conceals both.
T391's I5 adjudication proved the class: two instruments on one artifact,
every countable disagreed (E 7,364 vs 5,510; maxSCC 1,000 vs 1,676;
cycle_reachable 2,523 vs 1,678), and both reported `pass`.

Status vocabulary (per the rule): **production** = authoritative reading for
its (property, format, rung) cell; **fixture** = no longer authoritative,
still executed by a differential or a direct calibration gate; **duplicate** =
live in production alongside another implementation of the same property
(the state this row exists to shrink); **dead** = present but never executed.

Nothing below deletes or demotes anything — demotion is the Orchestrator's
ruling, proposed in §4. This row wires the differentials; the bar was
**do not touch** `src/retro.zig`, `oracle.zig`, `rules.zig`, `solve.zig`
(the kernel is L5's territory). All instruments and this document's
differentials are the instruments side of L0.

---

## 1. The ownership table

Cells are (check, format, rung). "Production" names the single authoritative
implementation of that property at that cell; every other implementation is
classified fixture / duplicate / dead. Line numbers are at commit
113968c + T395; they drift — the file:line is a pointer, the function name is
the fact.

### 1.1 I1–I12 through the general battery (WZO1)

| check | production implementation | other implementations | status | differential |
|---|---|---|---|---|
| **I1** pin census | `vb_table.checkI1` `src/vb_table.zig:396` | — | — | none needed (one impl) |
| **I2** colour inversion | `vb_table.checkI2` `src/vb_table.zig:434` | — | — | none needed |
| **I3** L ≤ H | n/a on WZO1 (`vb_table.checkI3` `:511` is a not-applicable stub — WZO1 stores single values). WZO2: the invariant is enforced by A2's L/H residual (`oracle_v2_accept.checkA2` `:729`) and measured by the A4 pin census (`checkA4` `:659`) | — | — | A2's L_violations/H_violations are the production gate |
| **I4** Bellman residual | WZO1 ≤4×3: `vb_fixpoint.checkI4` `src/vb_fixpoint.zig:265` (`checkI4At` `:170`, BasicKo engine). WZO2 4×4: **two** WZO2 engines, adjudication pending — see §4 | `vb_bellman_4x4.i4Bellman` `src/vb_bellman_4x4.zig:675` (R8 movegen); `oracle_v2_accept.checkA2` `:729` (kernel `rules.Rules`) | **duplicate** (three Φ operators, disjoint formats — T388 D1) | **NEW `src/i4_differential.zig`** — R8 vs kernel on `data/oracle-3x3-v2.wzo2` (49,428 entries, both exhaustive): identical denominator, zero violations both sides, identical missing-child counts, zero R8-internal move divergences. Wired into `zig build test` |
| **I5** SCC containment | general battery: `vb_graph.checkI5` `src/vb_graph.zig:464` (≤4×3, WZO1). Size-specific: `vb_scc_4x4.checkI5Small` `:400` (3×2/4×3 WZO1), `checkI5Wzo1Bitset` `:1380` (4×3), `checkI5Wzo2` `:812` (4×4 WZO2) | — | **duplicate** (general vs size-specific — T388 D2/D3) | **`src/i5_differential.zig`** (T391): 3×2 permanent in `zig build test`; 4×3 env-gated `WEIZIGO_I5_DIFF_4X3=1` (linking both instruments in one binary exceeds the runner RSS cap). T395 added the Defect-A/B/A+B seeded controls to it |
| **I6** UNDEF census | `vb_table.checkI6` `src/vb_table.zig:531` | — | — | none needed |
| **I7** DTT sanity | WZO1: `vb_fixpoint.checkI7` `src/vb_fixpoint.zig:359` (`checkI7At` `:294` — terminals DTT=0, non-terminals ≠255). WZO2: `oracle_v2_accept.checkA8` `:926` (`checkA8Inner` `:955` — DTT non-constant + recurrence DTT > min(children)) | two live, one per format | **duplicate across formats** (T388 D4) | **infeasible same-artifact** — the 3×3 WZO1 and WZO2 artifacts are different builds with different ko conventions; no cell has both formats of the same build. Compensation: each format's check runs at every rung that format exists (I7 on 2×2/3×2/3×3/4×3 WZO1 — known-fail today, DTT column; A8 on 3×3/4×4 WZO2 — pass), and T388 §3's adoption of A8's recurrence as the single definition is proposed to the Orchestrator |
| **I8** truncation-gap | external fixture `docs/evidence/QA-026/calibration-2x2-mismatch.py` (runs outside the battery, 2×2 only) | `vb_fixpoint.checkI8` `:390` | **dead** (stub returning not-applicable/placeholder; never executes) | none — the real check is the Python fixture; the stub is a corpse to be removed or wired |
| **I9** anchors | `vb_fixpoint.checkI9` `src/vb_fixpoint.zig:415` (parametric, per-size anchors) | — | — | none needed (already size-parametric, T388 D9) |
| **I10** TIE median | n/a on WZO1 (`vb_table.checkI10` `:591` stub). WZO2: A1 self-play tie refusals (`oracle_v2_accept.checkA1` `:520`) + A4 pin census categories | — | — | — |
| **I11** move-set consistency | `vb_i11.compareDirect` `src/vb_i11.zig:275` (≤4×3 exhaustive), `compareSmd1` `:174` (4×4, 50k stratified via SMD1 dumps) | `vb_fixpoint.checkI11` `:473` | **dead** (stub returning not-applicable; the battery's declared mode matrix never executes — T388 D5) | `vb_i11`'s own null + seeded-defect controls (kernel vs SMD1, `zig build test` since T363's engine_mod wiring) |
| **I12** score range | `vb_table.checkI12` `src/vb_table.zig:606` | — | — | none needed |

### 1.2 The size-specific / cross-cutting instruments

| property | production implementation | other implementations | status | differential |
|---|---|---|---|---|
| **closure** (C-A1 forward / C-A2 backward) | `vb_closure.ca1ForwardClosure` `src/vb_closure.zig:450`, `ca2BackwardClosure` `:714` (parametric w,h; 3×3 exhaustive in-suite, 4×4 full gated `WEIZIGO_CLOSURE_4X4_FULL=1`) | `t380_ko_slot.zig:850` correct-ko closure counter (4×4 WZO2, supplementary) | **duplicate** (T388 D7: same verdict at 4×4, different instruments, different child relations) | **infeasible cheap** — the overlapping cell is 4×4 (600M children, ~1.1 GB, env-gated by scale). Compensation: both instruments agree on the 4×4 verdict (0 children-not-in-table); the 3×3 exhaustive runs are in-suite; the counter is supplementary, not authoritative |
| **key agreement** (producer kernel vs consumer R8 state keys) | `differential.zig` T267 game-based form (`:401`, all sizes, sampled) + T345 table-exhaustive form (`test "T345: KEY-4x4"` `:1360`; `KEY-4x3` `:1468` WZO1; T363 added the 4×3 retroactive rung) | — | two forms of one instrument, exhaustive only at 4×4/4×3 | T345's exhaustive form has no small-rung WZO2 overlap (no WZO2 artifact below 3×3 exists; T388 D6). T267's game-based form covers all sizes as the secondary check. Proposal in §4: run the exhaustive form at 3×3 WZO2 as a third rung |
| **mutation assertions** | `vb_mutants.zig` M3/M5/M6/M7/M8/M9/M10 (WZO1 2×2 in-memory fixtures; M8 also closure at 3×3) + `oracle_v2_accept.checkA6` `:1225` (WZO2 4×4: perturbed value→SHA, dropped ko state→file-size, zeroed DTT→A8) | two fixture sets, **no shared fixture** (T388 D8) | **duplicate** (parallel mutant corpora calibrating parallel paths) | **infeasible cheap** — porting the WZO1 fixtures to WZO2 3×3 is moderate work (construct in memory) and A6's three fixtures already calibrate the WZO2 path at 4×4. Recorded open: `mutants.md` kill matrix vs `vb_mutants.zig`/T363 status sources disagree (D8) — that reconciliation is a prerequisite to a shared fixture |
| **key-byte ko decode** (WZO2 key byte, ko field at bits 2..(1+ko_bits)) | contract authority `artifact2.decodeKeyByte` `src/artifact2.zig:70`; closure production path `vb_closure.keyByteKo` `src/vb_closure.zig:157` (routed through `keyByteKoShift`, shift=2) | sibling decoders: `differential.zig:1278`, `oracle_v2_accept.zig:122`, `vb_bellman_4x4.zig:164`, `vb_scc_4x4.zig:205`, `t380_census.zig:187`, `t382_census.zig:820`, `t385_gallery.zig`, `t386_engine.zig`, `t380_ko_slot.zig`, `t380_psk_diff.zig` — all `>> 2` today | duplicated sites, all correct today (T383 F-7 fixed the two wrong ones) | **NEW `src/keybyte_differential.zig`** — `vb_closure.keyByteKo` vs `artifact2.decodeKeyByte` over all 256 key bytes × ko_bits {3,4,5}, plus the F-7 seeded control. Wired into `zig build test` |

---

## 2. The four seeded-defect controls (defects become test cases)

The operator's point, now formalised: *defects become test cases.* Every
defect this row names must be shown to make its differential fire, then be
fixed — **a differential never shown to fail is not evidence.** Each control
re-introduces the historical defect through a mutation knob (default off;
production readings byte-identical with the knob off — verified by the
pre-existing calibration gates), asserts the seeded reading reproduces the
historical defect exactly, asserts the differential fires on it, then asserts
the fixed path is green.

| defect | seeded mechanism | differential that fires | seeded (RED) reading | fixed (GREEN) reading |
|---|---|---|---|---|
| **A — `vb_graph` passes==2 placement successors** (`src/vb_graph.zig`, T391) | `I5Opts.mutate_passes2_placement=true` re-adds placement moves from passes==2 states (pass edges stay guarded, exactly as pre-fix) | I5 differential 3×2 (general vs size-specific) | E=7,364, maxSCC=2,520, cycle_reachable=2,523 — the exact third-route `--buggy` readings; pair NOT identical | E=5,510, maxSCC=1,676, cycle_reachable=1,678 — identical pair |
| **B — `vb_graph` quadruple→triple SCC projection** | `I5Opts.mutate_triple_projection=true` restores the pre-fix unique-(board,side,ko) triple projection incl. triple-seeded cycle-reachable | I5 differential 3×2 | maxSCC=988 on the corrected graph (the historical 1,000 was triple projection **on top of** Defect A — see row below); pair NOT identical | maxSCC=1,676 — identical pair |
| **A+B together** | both knobs | I5 differential 3×2 | reproduces the exact pre-fix binary readings, T388 Run B: V=2,583, E=7,364, SCCs total=64, maxSCC=1,000, cycle_involved=1,000, cycle_reachable=2,523 | identical pair |
| **C — `vb_scc_4x4` descending CR propagation** (`src/vb_scc_4x4.zig`, T391) | `checkI5Wzo1Bitset(…, mutate_descending_cr=true)` processes SCC ids ncomp-1→0 instead of 0→ncomp-1 | the 4×3 all-legal cell of the I5 property (runs inside `vb_scc_4x4.zig`'s suite; the cross-instrument 4×3 cell is env-gated for RSS) | ko_not_cr=24, CR=1,300,006 — the historical "24 natural violations" (T344/T363), exactly as T391's third-route simulation of the bug | ko_not_cr=0, CR=1,300,030 — the true reading |
| **D — `kb >> 1` key-byte ko decode** (`src/vb_closure.zig`, T383 F-7) | `keyByteKoShift(…, shift=1)` restores the pre-fix `kb >> 1` (side bit leaked into the ko field); production is shift=2 | key-byte differential (closure vs artifact2 contract, all 256 bytes × ko_bits {3,4,5}) | F-7 witnesses: kb=12 (ko_bits=5) → ko=6 instead of 3; kb=66 → ko=1 instead of 16; whole-space sweep diverges first at kb=2 (side bit leaking) | every byte agrees with the contract; witnesses decode 3 and 16 |

Runs: §5. Where a defect's firing cell is scale-gated (C at 4×3
cross-instrument), the control runs in the owning instrument's own suite at
the same cell, and the compensation is recorded rather than the cell forced.

---

## 3. Differential inventory (wired, as of this row)

| differential | file | cell(s) | gate status |
|---|---|---|---|
| I5 cross-size (general vs size-specific) | `src/i5_differential.zig` (T391 + T395 controls) | 3×2 permanent; 4×3 env-gated | in `zig build test` |
| I4 cross-engine (R8 vs kernel) | `src/i4_differential.zig` (NEW) | 3×3 WZO2, both exhaustive | in `zig build test` |
| key-byte decode (closure vs artifact2) | `src/keybyte_differential.zig` (NEW) | all 256 bytes × ko_bits {3,4,5} | in `zig build test` |
| closure (C-A1/C-A2) | (scale-gated) 4×4 full sweep | env-gated `WEIZIGO_CLOSURE_4X4_FULL=1` | 3×3 exhaustive runs in-suite; 4×4 on demand |
| I5 4×4 | (scale-gated) bitset/Tarjan 2.8 GB RSS | in vb_scc_4x4's suite (4×4 WZO2 exhaustive) | in `zig build test` |

---

## 4. Demotion proposals (Orchestrator rules; nothing here demotes)

For each duplicated property, the proposed production/fixture split and the
demotion's cost.

1. **I4** — propose **A2 (kernel engine) production** for WZO2 4×4 (the
   kernel is the ruleset authority; A2's verdict shape L_violations/
   H_violations/missing_child is the clearest), **`vb_bellman_4x4` demoted
   to fixture** driven by `i4_differential.zig` (its independent R8 engine is
   the oracle — that is its whole value; its T343 4×4 reading would then be
   a fixture reading, not an independent certification), **`vb_fixpoint.
   checkI4` stays production for WZO1** (only WZO1 I4). Cost: none today —
   the differential already runs both; the demotion is a status change on
   the 4×4 WZO2 cell, and baselines.json's T343 row would be re-framed from
   "certification" to "fixture agreement".
2. **I5** — already effectively one production surface: `vb_scc_4x4` is the
   size-specific authority at 4×3/4×4 (T391 adjudicated it right), and
   `vb_graph.checkI5` remains production at ≤3×3 where the battery runs it.
   Propose demoting `vb_graph.checkI5` at 3×2/4×3 to fixture behind
   `i5_differential.zig` (the differential is already the gate). Cost: the
   general battery's I5 row at 3×2/4×3 becomes a fixture reading; the
   differential keeps it honest. `vb_scc_4x4`'s three entry points
   (checkI5Small / checkI5Wzo1Bitset / checkI5Wzo2) are rung-segmented
   backends of one instrument, not duplicates — keep.
3. **I7** — propose adopting A8's recurrence as the single definition (T388
   §3) and porting I7's terminal checks into the WZO2 path; then
   `vb_fixpoint.checkI7` becomes the WZO1 fixture. Cost: moderate (a WZO1
   column reader or a ported terminal check) — and it is blocked by the
   artifact-format split, which only a shared-reader refactor removes.
4. **I11** — no demotion needed: `vb_i11` is already the only production
   implementation; `vb_fixpoint.checkI11` is **dead** (never executes) and
   should be removed or wired as the battery's I11 runner (T388 §3 proposal
   (b), low cost). Propose wiring it (low) or deleting the stub (the
   project rule allows deletion only of dead code, and this stub is dead by
   its own doc comment).
5. **key agreement** — no demotion; propose adding the T345 exhaustive form
   at 3×3 WZO2 (49,428 entries, cheap) so the exhaustive form has a
   small-rung differential rung instead of existing only at 4×4/4×3.
6. **closure** — propose declaring closure WZO2-only explicitly and keeping
   `t380_ko_slot.zig`'s counter as the supplementary 4×4 oracle (not
   production). Cost: none; both verdicts already agree at 4×4.
7. **mutation assertions** — propose reconciling the kill matrix (D8) then
   porting the WZO1 2×2 fixtures to WZO2 3×3 in-memory so the two mutant
   corpora share a fixture. Cost: moderate; deferred to a later row.

---

## 5. Runs (cited)

All under `tools/runner` (RSS guard 4 GB; `docs/infra/runner.md`), 2026-08-06,
repo root, `-O ReleaseFast` (runner default). Full logs in
`findings/T395-context.json`.

| control | command | result |
|---|---|---|
| I5 Defect A | `zig test src/i5_differential.zig --test-filter "Defect-A"` | FIRES (E 7,364 vs 5,510) → GREEN; All tests passed |
| I5 Defect B | `… --test-filter "Defect-B"` | FIRES (maxSCC 988 vs 1,676) → GREEN |
| I5 Defect A+B | `… --test-filter "A+B"` | FIRES (E 7,364 maxSCC 1,000 cycleReach 2,523 sccs 64 — pre-fix binary readings reproduced exactly) → GREEN |
| I5 cross-size 3×2 | `zig test src/i5_differential.zig --test-filter "3×2"` | identical readings (V=2,583 E=5,510 maxSCC=1,676 cycleReach=1,678) |
| I5 Defect C | `zig test src/vb_scc_4x4.zig --test-filter "Defect-C"` | RED ko_not_cr=24 CR=1,300,006 → GREEN 0 / 1,300,030 |
| vb_scc_4x4 full suite | `zig test src/vb_scc_4x4.zig` | 26/26 (T395 control added; 4×4 exhaustive unchanged: ko_not_cr=0) |
| key-byte differential | `zig test src/keybyte_differential.zig --test-filter "key-byte"` | GREEN 256 bytes × 3 rungs; F-7 RED (kb=2 → ko=1 vs 0) → GREEN |
| I4 differential | `zig test src/i4_differential.zig --test-filter "I4 Bellman differential"` | bellman(R8) entries=49,428 viol=0 missing=0 move_div=0; A2(kernel) checked=49,428 L/H_violations=0 missing=0 — GREEN |

Full suite: `tools/runner -- zig build test` — red exactly where the
documented pre-existing baseline is red (T391's note: identical failing
binary hashes for bellman/closure/oracle_v2_accept/battery steps — the Zig
0.16 `--listen=-` "internal test runner failure: EndOfStream" exit quirk;
plus the 4 documented qa023_brute_2x2 budget-crash ABRTs). The three new
differential steps are green; no new red was introduced. (T369 owns the
manifest; it was dispatchable, not live, when this row ran.)

## Landmark

**Landmark:** advances `L0 (the table and the instruments exist)` — the
operator can now see, for every property, the single production
implementation, every other implementation, and whether each is a fixture, a
duplicate, or dead; the two WZO2 Φ operators (I4) and the closure key-byte
decode are now pinned to each other by permanent differentials in `zig build
test`; and all four 2026-08-06 defects (vb_graph passes==2 successors, its
triple SCC projection, vb_scc_4x4's descending CR propagation, the kb>>1
key-byte ko decode) are seeded controls that demonstrably fire their
differential before the fixed path turns green. What remains for L0's
instrument side: the WZO1/WZO2 format split on I7 and the 4×4 scale cells
(closure, I5 cross-instrument) still have no same-artifact differential —
each is recorded with its compensation — and the demotions in §4 await the
Orchestrator's ruling.
