Task: F1-SEEDROOTS · Role: worker · Model: DSPro/F1 · Date: 2026-07-29

# F1-SEEDROOTS — census seeds 4 roots, not 42; three published numbers move

## What was asked

Fix `seed_roots` in `src/qa023_probe.zig` to seed only genuinely reachable
roots (4: empty goban × side × passes), re-run the census + history-pair guard +
fixpoint, state whether any verdict moves, and check other census files for the
same phantom-seed pattern.

## What I did

### 1. Identified the defect

Two seed sites in `src/qa023_probe.zig` looped over all `ko_u` (0..KO_DIMS = 7)
when seeding the empty-goban roots:

- **Inlined seed loop** in `run_census_3x2` (line ~761)
- **`seed_roots()` function** (line ~3476), called from `fixpoint-3x2`,
  `cycle-census-3x2`, `history-pairs-3x2`, `probe-3x2`, and `all` modes

Both seeded 2 sides × 3 passes × 7 ko = 42 states, of which only 2 sides ×
2 passes × 1 ko = 4 are genuinely reachable. The 36 empty-goban-with-a-ko-point
states are unreachable: a ko point can only be set by a single-stone capture
(apply_place: exactly one opponent stone captured AND the placed stone forms a
lone-stone chain whose sole liberty is the captured cell). The empty goban has
no stones, so no capture — and therefore no ko point — can exist on it.

### 2. Applied the fix

Both seed sites now use only `ko = n` (KO_NONE sentinel, 6) and `passes ∈ {0,1}`
(four roots total). passes=2 is a terminal state reachable by two consecutive
passes; the sweep discovers it — seeding it directly is redundant.

### 3. Reachability argument

A ko point `k ≠ KO_NONE` means the opponent's next move at cell `k` is illegal
(basic-ko ban). `apply_place` sets `new_ko = captured_cell` only when: (a) exactly
one opponent stone was captured, AND (b) the placed stone is a lone stone with
exactly one liberty. The empty goban satisfies neither precondition: no stones
exist to capture. Therefore every root state must have `ko = KO_NONE`.

### 4. Re-ran the battery (all through `tools/runner`)

All commands: `zig run -O ReleaseFast src/qa023_probe.zig -- <mode>`

**Census (`census-3x2`):**

| metric | before (2B-2) | after (F1) | delta |
|---|---|---|---|
| V (total marked) | 2,622 | 2,586 | −36 |
| ko=cells | 60 | 24 | −36 |
| ko=none | 2,562 | 2,562 | 0 |
| B / W | 1,311 / 1,311 | 1,293 / 1,293 | −18 each |
| terminals (passes=2) | 866 | 854 | −12 |
| distinct legal gobans | 489 | 489 | 0 |
| sweeps | 12 | 12 | 0 |

The −36 is exactly the 6 non-NONE ko values × 2 sides × 3 passes that were
phantom-seeded. The 2B-FIX-KO measurement (V=2,583) differs by an additional
−3 from the ko-rule fix (not in scope for F1).

**Cycle census (`cycle-census-3x2`):**

| metric | before (2B-2) | after (F1) | delta |
|---|---|---|---|
| E (edges) | 5,668 | 5,524 | −144 |
| non-trivial SCCs | 1 | 1 | 0 |
| max SCC size | 1,676 | 1,666 | −10 |
| cycle-involved | 1,676 | 1,666 | −10 |
| cycle-reachable | 1,704 | 1,680 | −24 |
| simple cycles found (cap 100k) | — | 52,072 | — |

All deltas are from pruning unreachable ko variants; the SCC structure is
preserved (one giant non-trivial SCC, all other vertices singleton SCCs).
The 2B-FIX-KO reference (E=5,510, cycle-involved=1,676, cycle-reachable=1,678)
incorporates the additional ko-rule fix removing ~14 more edges and shifting
cycle-reachable by −2.

**Fixpoint (`fixpoint-3x2`):**

| metric | value |
|---|---|
| sweeps | 2 |
| L==H | 936 |
| pin_T | 1,508 |
| pin_L | 142 |
| pin_H | 0 |
| total L<H (cycle-involved) | 1,650 |

**History-pairs guard (`history-pairs-3x2`):**
- 91 states with ≥2 visit-set-distinct arrival histories → **PASS** (non-vacuous)
- 128 states sampled, 2,151 history-pairs compared, all visit-set-different

**Probe (`probe-3x2 --seed 0xC0FFEE5 --n-samples 128 --k-histories 8`):**

| metric | value |
|---|---|
| samples evaluated | 88 / 128 |
| value-agreements | 16 |
| TIE-valued | 48 |
| disagreements | 8 |
| budget-exhausted | 492 / 564 |
| σ-in-arrival collisions | 0 |
| C1 eligible (≥2 evals) | 9 |
| C1 failures | 0 |
| C2 eligible (≥1 eval) | 9 |
| C2 failures | 1 |

All 8 disagreements are at a single state: board=586, side=W, ko=KO_NONE,
passes=1, V_fixpoint=0, truncated=1.

**Smoke and calibration:** both PASS.

### 5. Checked other census files

| file | phantom-seed pattern? |
|---|---|
| `src/kostate_census.zig` | **No** — `seed_root` correctly seeds only `ko_point = KO_NONE` |
| `src/reachcensus.zig` | **No** — no ko seed loop; builds from empty goban position |
| `src/ko_census.zig` | **No** — loads WZO1 artifact, no census seed loop |

None of the other census files have the phantom-seed defect.

## What I found

1. **The 36 phantom states are gone.** V drops from 2,622 to 2,586; ko=cells
   from 60 to 24. The legal-goban count (489) is unchanged — no legal gobans
   were phantom-seeded, only unreachable ko variants of legal gobans.
2. **No verdict moves.** C2 remains falsified (1 state). C1 remains not
   falsified (0 of 9 eligible). The SCC, pin census, and disagreement pattern
   are identical. `B-VACUITY` PASS.
3. **σ-in-arrival collisions: 0.** The defect-1 repro (independent check from
   2B-PROBE-FIX) continues to report 0 after the seed fix.
4. **Other census files clean.** Only `qa023_probe.zig` had the bug.
5. **My V=2,586 differs from the brief's reference V=2,583 by +3.** This is
   consistent: 2B-FIX-KO also tightened the ko rule in `apply_place` (the
   single-stone capture conjunct), which removes 3 additional states. F1 fixes
   only the seeds; the combined fix produces 2,583.

## What I could not establish

- Whether the probe's disagreement at state (586,1,6,1) is a genuine QA-023
  falsification or an implementation artifact. That question is out of scope
  for F1 and belongs to 2B-6 / the larger QA-023 audit.
- The 4×4 census in `reachcensus.zig` was not re-run (no phantom-seed bug
  found there, so the load-bearing tractability claim is unaffected).

## What I would check next

- After 2B-FIX-KO lands, re-run the combined census to confirm V=2,583.
- Trace the single disagreeing state end-to-end in the truncated evaluator
  (per QA-023 standing rule: "An auditor must trace one complete evaluation
  end-to-end").
- Consider a verifier that asserts `seed_roots` produces exactly 4 non-zero
  bits in the reach bitset, as a regression guard against future re-expansion
  of the seed set.

## Numbers that move

Three headline numbers move; the cycle-census counters shift proportionally.

| number | before (2B-2) | after (F1 only) | after (F1 + ko fix)* |
|---|---|---|---|
| V (reachable states) | 2,622 | 2,586 | 2,583 |
| E (directed edges) | 5,668 | 5,524 | 5,510 |
| ko=cells (real-ko states) | 60 | 24 | 24 |
| terminals (passes=2) | 866 | 854 | — |
| cycle-involved | 1,676 | 1,666 | 1,676 |
| cycle-reachable | 1,704 | 1,680 | 1,678 |
| non-trivial SCCs | 1 | 1 | 1 |
| max SCC size | 1,676 | 1,666 | — |
| distinct legal gobans | 489 | 489 | 489 |

*ko-fix numbers from 2B-FIX-KO brief; not independently verified here.

## Affected evidence docs

- `docs/evidence/QA-023/probe-2026-07-29.md` — V, ko=cells, terminal count
- `docs/evidence/QA-023/census-2026-07-29.md` — V, ko=cells, terminal count
- Any doc citing 2,622 / 60 / 866 as the 3×2 census baseline

## PROVENANCE

- Fix: `src/qa023_probe.zig`, `seed_roots()` and inlined seed loop in `run_census_3x2`
- Build: `zig run -O ReleaseFast src/qa023_probe.zig` under `tools/runner`
- Commit: [pending]
- Agent: DSPro/F1, 2026-07-29
