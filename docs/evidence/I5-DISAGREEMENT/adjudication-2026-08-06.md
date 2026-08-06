# T391 — which I5 instrument is telling the truth? (adjudication)

```
Task:     T391 · Set: J · 2026-08-06 · Worker: deepseek-v4-flash/T391
Landmark: advances L2 (proven 4×4 values) — I5 is one of the six conditions
          of the G3b discharge; its instrument was found to hide a defect
          behind agreeing verdicts, and the defect is now fixed with a
          permanent cross-size differential gate.
Brief:    untracked/T391-i5-instrument-disagreement.md
```

**Verdict up front:** the two instruments were measuring the **same** property
(cycle-reachability in the basic-ko legal-move game graph) on the **same**
artifact, and the **general instrument `vb_graph` was wrong** — two defects,
one a genuine bug, one a non-register counting convention. The size-specific
instrument `vb_scc_4x4` is correct at 3×2, 4×3 and 4×4, **but its 4×3
all-legal CR computation has a second, independent bug** (a propagation-order
error) that fabricated the "24 natural violations" recorded at T344/T363.
All four instruments' readings were verified by a third, independent route
(written for this task, not derived from either instrument).

Every table value in this document was recomputed by the third route and
cross-checked; every definition is quoted with `file:line`.

---

## 1. What each instrument implements (the definitions, quoted)

The property, from the g3b pass0 spec (§2.1, I5): **"Every KO_SENSITIVE slot
is cycle-reachable: `ko_not_cr == 0`."** Both instruments compute the SCC
decomposition of the basic-ko legal-move graph over `(board, side, ko_point,
passes)` states and report graph metrics plus the containment verdict.

### 1.1 `vb_graph` (general, verify-battery I5) — `src/vb_graph.zig`

- Move graph: `src/vb_graph.zig:74-79` — "Pass edges are treated as terminal
  cut-edges (Option A from i5-feasibility.md)". The header's calibration
  targets (`:30-35`): "2×2 all-seed: maxSCC=160 … 3×2 true-root: maxSCC=1,676
  (ko-fix-rerun-2026-07-29.stdout:107)".
- SCC metric level: `:820-823` (pre-fix) — "The reference (2B-2) counts SCC
  at the triple level; passes are terminal cut-edges, not vertices. We
  project quadruples to triples."
- KO_SENSITIVE scope: `:847-869` (pre-fix) — artifact-wide census over every
  stored `(colex, side)` slot; the containment check maps each flagged slot
  to its `(colex, side, ko=NONE, passes=0)` node.
- Observed at 3×2 reachable: V=2,583, E=**7,364**, SCCs=**64**, maxSCC=**1,000**,
  cycle-reachable=**2,523**, ko_sensitive=**378**, ko_not_cr=0, pass.

### 1.2 `vb_scc_4x4` (size-specific) — `src/vb_scc_4x4.zig`

- Move graph: `checkI5Small` (`:398`, 3×2/4×3 WZO1), `checkI5Wzo1Bitset`
  (`:1378`, 4×3), `checkI5Wzo2` (`:810`, 4×4 WZO2). Passes=2 states are
  terminal in all three (`checkI5Small:445` "Terminal: passes=2 has no
  outgoing edges"; `checkI5Wzo2:1110` "Terminal: out-degree 0").
- SCC metric level: quadruples (no projection).
- KO_SENSITIVE scope: flags on graph vertices at `(ko=NONE, passes=0)`
  (`checkI5Small:741-757`); at 4×4 the census is artifact-wide L≠H
  (`checkI5Wzo2:861-870`).
- Observed at 3×2 reachable: V=2,583, E=**5,510**, maxSCC=**1,676**,
  cycle-reachable=**1,678**, ko_sensitive=**347**, ko_not_cr=0, pass.

### 1.3 The committed register (verify-battery pass0 spec §5, I5 calibration)

- 3×2 max SCC: **1,676** under both seed conventions
  (`docs/evidence/QA-023/ko-fix-rerun-2026-07-29.stdout:107`).
- 3×2 cycle-reachable spread 1,724 / 1,704 / **1,678**; "Convention for I5:
  the true game root, phantoms excluded → 1,678"
  (`docs/epic-01-markovian/sprints/verify-battery/pass0/spec.md` §5).
- 2×2 true root: V=255, E=434, max SCC=160 (`scc2x2.py`).

---

## 2. Adjudication

### 2.1 They measure the same property; `vb_graph` is wrong

Same artifact, same goban, same reachable-from-empty convention, identical
vertex set (V=2,583 both). The disagreements are therefore differences in the
**edge set** and in the **SCC metric level** — not different properties.

**Defect A — passes==2 states are not terminal in `vb_graph`.** Its BFS
(`:606-633` pre-fix) generated placement successors for *every* node and only
gated the pass successor on `passes < 2`. The size-specific instrument and
the committed reference treat `passes == 2` as terminal (two passes end the
game; "pass edges are terminal cut-edges", `vb_graph.zig:15-16` itself).
The consequence at 3×2: E=7,364 vs 5,510 (the out-degree sum of the 853
passes=2 nodes, which should be sinks), SCCs merged 64 vs 908, cycle-reachable
inflated 2,523 vs 1,678. The third route reproduces **every** one of these
numbers with the passes=2 placements re-enabled (`third-route-3x2-4x3.py`
`--buggy`: E=7,364, SCCs=64, CR=2,523) and the register values with them
disabled (E=5,510, SCCs=908, CR=1,678).

**Defect B — `vb_graph` projects SCC sizes to triples.** `vb_graph.zig:820`
(pre-fix) projected each SCC from quadruples to unique `(board, side, ko)`
triples, reporting maxSCC=1,000 at 3×2. The register is quadruple-level
(1,676); `vb_graph`'s *own header* cites 1,676 as its target (`:34`) and does
not reproduce it. Its result also mixes levels (cycle_involved triple-
projected 1,000, cycle_reachable counted on quadruple vertices 2,523).
The size-specific instrument and the committed Python reference
(`docs/evidence/QA-023/i5-reference-3x2.py`) report the register values
exactly.

**The ko_sensitive 378 vs 347 is a census-scope difference, not a numeric
error.** 378 = artifact-wide flag census over all stored `(colex, side)`
slots (verified by direct byte scan of `artifacts/oracle-3x2.wzo`: bit 0 of
the fb/fw columns, 378 set). 347 = the subset of those flags whose
fresh-start state is a vertex of the reachable graph at `(ko=NONE,
passes=0)` (31 flagged slots are legal but not reachable from the empty
board). Both instruments' *violation checks* cover only the 347; neither
counts the 31 as violations. T388's framing ("the general instrument is
right, the size-specific one undercounts by 31") conflates the census with
the checked domain. The fix reports both quantities, explicitly named.

### 2.2 The size-specific instrument is correct at 3×2/4×3/4×4 — with one new bug found

At every size where they overlap, `vb_scc_4x4`'s readings equal the register
**and** the third route:

| quantity | register | vb_scc_4x4 | third route |
|---|---|---|---|
| 3×2 V / E / maxSCC / CR | 2,583 / 5,510 / 1,676 / 1,678 | 2,583 / 5,510 / 1,676 / 1,678 | 2,583 / 5,510 / 1,676 / 1,678 |
| 3×2 ko_sensitive (graph) | — | 347 | 347 |
| 2×2 V / E / maxSCC | 255 / 434 / 160 | — | 255 / 434 / 160 |
| 4×3 reachable V / E / maxSCC / CR | — | 1,929,035 / 6,858,926 / 1,284,078 / 1,284,080 | same |
| 4×3 reachable ko_sensitive | — | 170,181 | 170,181 |
| 4×4 V / E / maxSCC / CR | — | 99,133,036 / 565,402,416 / 47,429,504 / 97,689,592 | — (scale) |

**New defect C — `runTarjanSccDag`'s CR propagation order** (4×3 all-legal
path, `src/vb_scc_4x4.zig:1700-1714` pre-fix). The single-pass propagation
processed component ids **descending** (ncomp-1 → 0), but CR is a backward
property (an SCC is CR if a *successor* SCC is CR), which requires processing
successors before predecessors — Tarjan pops successors first (lower ids),
so ids must be processed **ascending**. With descending order, a trivial SCC
whose path to a cycle runs through ≥2 trivial SCCs is never marked CR. At
4×3 all-legal this fabricated **24 spurious violations** (the "24 natural
violations" recorded at T344/T363, and the T363 vacuity claim "4×3's non-CR
slots are all already KO_SENSITIVE" — both now falsified). The third route
simulates both orders on the identical graph: descending gives the
instrument's exact output (CR=1,300,006, ko_not_cr=24); ascending matches
the exact reverse-BFS (CR=1,300,030, ko_not_cr=0). The bug only
**over**-reports non-CR, so the 4×3 *reachable* reading (0 violations) and
the 4×4 reading (snapshot-sweep, order-independent) were unaffected.

### 2.3 The committed Python reference was not independent

`docs/evidence/QA-023/i5-reference-3x2.py` (T186) reproduced `vb_graph`'s
pre-fix numbers to the digit — because it had inherited both defects (passes=2
placement expansion and the triple projection). Two instruments sharing a bug
produce agreement without evidence; that is the T363 lesson applied again.
The reference is corrected in place (header note + fixes) and the genuinely
independent route now lives under `docs/evidence/I5-DISAGREEMENT/`.

---

## 3. The third route (independent hand-verification)

`docs/evidence/I5-DISAGREEMENT/third-route-3x2-4x3.py` — a self-contained
Python re-implementation written for this task: own WZO1 reader, own layered
colex (ADR-0007), own basic-ko engine stated from the F5 rule ("exactly one
opponent stone captured AND the placed stone's chain has size 1 and exactly 1
liberty"), own BFS/Tarjan/reverse-BFS. The only things taken from the
codebase are the two things a file format fixes and cannot be chosen
independently: the WZO1 byte layout and the colex bijection. Run outputs:
`docs/evidence/I5-DISAGREEMENT/third-route-3x2.stdout`.

The route reproduces, to the digit, both the register values (correct model)
and the general instrument's inflated values (with the passes=2 defect
re-enabled), and it breaks the 4×3 all-legal tie (24-vs-0) in favour of 0.
Full numbers in `findings/T391-i5-disagreement.json`.

---

## 4. Blast radius for the G3b discharge

**The discharge's I5 lines are unchanged — no second amendment needed.**

- **4×4 `0 / 3,455,412`** — produced by `checkI5Wzo2` (snapshot-sweep CR,
  order-independent, artifact-wide census and check). Adjudicated correct;
  the T391 changes do not touch that path, and the suite re-ran it
  unchanged (V=99,133,036, E=565,402,416, maxSCC=47,429,504, CR=97,689,592,
  ko_not_cr=0 — identical to T363).
- **4×3 `0 / 170,181`** (reachable, true-root convention — the register's
  stated convention) — produced by `checkI5Wzo1Bitset`. Correct: the true
  value is 0 under both the reachable and the all-legal convention. The
  recorded "24 natural violations" (T344/T363) were a false positive of
  Defect C, now fixed; the true all-legal reading is also 0.
- **3×2 `0/378` (battery, all-legal) and 0/347 (reachable)** — correct under
  both conventions (vacuity: every 3×2 passes=0 fresh-start state is
  cycle-reachable).
- The general instrument's battery rows (2×2 0/82, 3×2 0/378, 3×3 0/8,698,
  4×3 0/170,276) keep their denominators (the census is preserved) and
  verdicts; only the graph metrics (E, maxSCC, CR, SCC count) change to the
  register values. The T292 golden-master baseline comparison passes
  unchanged.
- **Worth saying explicitly:** under the all-legal convention the 4×3
  reading was never the discharge's number; under the true-root convention
  it is 0. The G3b I5 discharge lines therefore stand as recorded.

The corrections to the record are narrative, not numbers: T344/T363's "24
natural violations at 4×3" and "4×3's non-CR slots are all already
KO_SENSITIVE" are falsified (spurious), and T388's claim that the general
instrument's KO_SENSITIVE count "is right" while the size-specific "undercounts
by 31" is a scope confusion. All three rows now have their honest reading:
0.

---

## 5. Fixes shipped with this adjudication

1. **`src/vb_graph.zig`** — passes==2 states are terminal in the BFS, Tarjan
   children and reverse-adjacency phases (`:606, :737, :810`); SCC metrics
   are quadruple-level (projection removed, `:819`); a graph-restricted
   KO_SENSITIVE count is reported alongside the census (`:857`);
   calibration gates updated to the register values (2×2 V/E/maxSCC/CR,
   3×2 V/E/maxSCC/CR/SCCs) — the module now reproduces the numbers its own
   header always cited.
2. **`src/vb_scc_4x4.zig`** — `runTarjanSccDag` CR propagation processes
   component ids ascending (successors before predecessors, `:1700`); the
   4×3 exact gates and the seeded-defect test now record the true vacuity
   (ko_not_cr=0; the "24" note is corrected); `checkI5Small` is `pub` for
   the differential.
3. **`docs/evidence/QA-023/i5-reference-3x2.py`** — corrected in place
   (passes=2 terminal, quadruple-level metrics, exact register gates),
   with a header note explaining the T391 correction.
4. **`src/i5_differential.zig`** (new, wired into `build.zig`) — the T388 §4
   cross-size differential as a permanent gate: both instruments on
   `artifacts/oracle-3x2.wzo` (reachable) must return identical V, E,
   maxSCC, cycle_involved, cycle_reachable, ko_sensitive, ko_not_cr and
   verdict. The 4×3 cell is env-gated (`WEIZIGO_I5_DIFF_4X3=1`) because
   linking both instruments in one binary makes the ReleaseFast codegen
   exceed the tools/runner RSS cap (tooling constraint, measured: the
   instrument itself runs at ~110 MB after BFS); its values are pinned by
   the per-instrument exact gates and the third route instead.
5. **`build.zig`** — the differential test step.

Verification: `zig test src/vb_graph.zig` 8/8; `zig test src/vb_scc_4x4.zig`
25/25 (incl. 4×4, ko_not_cr=0 unchanged); `zig test src/i5_differential.zig`
3×2 differential passes; `zig build test` 50/52 steps succeeded, 727/732
tests passed (1 skipped = the gated 4×3 differential; 4 crashed = the
documented pre-existing qa023_brute_2x2 explosive smoke tests, T360) — the
identical failure set as the HEAD baseline. Battery golden-master baseline
comparison passes unchanged.

---

## 6. What a human can now see

The I5 pair can no longer silently diverge: the general instrument reports
the register's numbers, the size-specific instrument's 4×3 all-legal reading
is honest (0, not 24), and the differential gate fails loudly on any future
drift at the overlapping size. What still stands in the way of `L2 (proven
4×4 values)`: the Track A regeneration of the ko-sensitive columns
(`memo_writes=false` + the #2 auditor) — the T391 adjudication does not
touch the artifact's values, only the instruments that read them.
