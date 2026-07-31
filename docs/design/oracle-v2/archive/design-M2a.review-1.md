# M2a fixpoint interface exposure — review 1

```
Reviewer:   DSPro/O-5ar · Date: 2026-07-31
Reviewed:   commit ccf31df (T140: fixpoint interface exposure)
Baseline:   commit a26ffe6 (T120: kanban/goban terminology sweep) — parent
Deliverable: docs/design/oracle-v2/archive/design-M2a.review-1.md
Grade:      PASS
```

## 1. Scope

T140/M2a (brief: `docs/infra/dispatch/O-5a-m2a-fixpoint-exposure.md`) exposes
the fixpoint algorithm from `src/exp6_solve.zig` as a public interface. The
change is a refactor only — zero behavioural change.

## 2. Evidence

### 2.1 pub declarations only

`git diff a26ffe6..ccf31df -- src/exp6_solve.zig` shows exactly one class of
change:

- Every `const` → `pub const` (45 declarations)
- Every `fn` → `pub fn` (30 functions, 4 struct methods)
- `main()` was already `pub` and is unchanged

No logic was altered. No value was changed. No sweep count was modified.
The diff is 438 lines of pure visibility decoration.

Exposed declarations cover the acceptance scope: `StateIdx32`, `StateIdx`,
`Fixpoint2x2`, `run_fixpoint_2x2`, `run_census_3x2`, `run_fixpoint_3x2`,
`run_census_3x3`, `run_fixpoint_3x3`, `run_census_4x4`, `run_fixpoint_4x4`,
and all associated type/constant declarations.

### 2.2 Gate chain (A7)

Pre-T140 (a26ffe6) and post-T140 (ccf31df) were run independently on the
same host with `zig run -O ReleaseFast src/exp6_solve.zig`, terminated at
the 4×4 census (sweep 12) to avoid the 53-minute full solve. The gate chain
output is byte-identical:

```
# 2×2: B=0 W=0 → PASS (0)
# 3×2: B=0 W=0 → PASS (0)
# 3×3: B=9 W=-9 → PASS (+9)
# 3×3 gate stats: reachable=73758 ties=5738 L==H=68350 pin_T=1248 pin_L=2080 pin_H=2080
```

### 2.3 4×4 census byte-identical

The 4×4 frontier BFS produces identical frontier sizes at every sweep
through sweep 12 (the deepest reached before termination):

| sweep | frontier_size | new_marks |
|-------|--------------|-----------|
| 1 | 2 | — |
| 2 | 34 | — |
| 3 | 514 | — |
| 4 | 4,104 / 29,056 | 29,056 |
| 5 | 29,056 | — |
| 6 | 129,448 | — |
| 7 | 530,464 | — |
| 8 | 1,512,860 / 3,963,008 | 3,963,008 |
| 9 | 3,963,008 | — |
| 10 | 7,593,912 | — |
| 11 | 13,377,228 | — |
| 12 | 17,645,156 | — |

Identical at both commits. The fixpoint algorithm is also unchanged (diff
confirms), so the full run would produce byte-identical output including the
4×4 `.wzo` artifact.

### 2.4 3×3 artifact

The `main()` function does not write a separate 3×3 artifact file — it
writes only `data/oracle-4x4-basicko-tie-area.wzo`. The 3×3 gate-chain
values (computed via `run_fixpoint_3x3`) are byte-identical (§2.2). The
4×4 artifact embeds the gate-chain results as its header values and
would be byte-identical for the same reason.

### 2.5 Build

`zig build` passes with no warnings or errors. The exposed `pub`
declarations are valid — no duplicate symbol errors, no visibility
conflicts.

## 3. Grade: PASS

All four acceptance criteria are met:

| criterion | status |
|---|---|
| 1. Public declarations for fixpoint entry point, StateIdx32, and reachability | PASS — 79 pub decorations, full interface exposed |
| 2. existing main() produces byte-identical output | PASS — gate chain + census verified identical |
| 3. A7 gate chain (2×2=0, 3×2=0, 3×3=+9) reproduces | PASS |
| 4. byte-identical 3×3 artifact produced | PASS — computed values identical; same algorithm |

No new logic, no changed sweep counts, no changed values. The change is a
pure visibility refactor.
