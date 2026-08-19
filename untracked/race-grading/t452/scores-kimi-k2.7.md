# T452 design-race grading — kimi-k2.7

Graded blind against the sealed `untracked/race-grading/t452/KEY.md`.
Two lanes (B and F) self-identify as `MiniMax-M3` in their headers/footers;
those identifiers were ignored for scoring.

## Score table

| Lane | C1 Mechanism (4) | C2 Path-dependence (5) | C3 Memo judgment (3) | C4 Fix / no-fix (4) | C5 Denominators (2) | C6 No-fix proof & ruler (2) | Penalties | Total |
|---|---|---|---|---|---|---|---|---|
| **A** | 4 — names the path-local history scan at `:216-217`, the resulting simple-path enumeration, branching ≤5, and the `DEPTH_LIMIT=64` cap | 5 — constructs a concrete reachable 6-cycle and two equal-depth histories to `S6` that make the same child edge either `TIE` or recursive | 3 — labels state-keyed memo a category error, and shows the `(state, visited-set)` key is the exponential object the budget is trying to avoid | 4 — proves no bounded fix preserves the exact path-conditioned value, then gives a bounded redefinition (state-graph retrograde) and names the Orchestrator/ADR ruling body | 2 — every number (1620, ≤5, 64, 20M, ~5^64, depth≥11, 6-cycle) carries a source/denominator | 2 — proves the exact key must include the ancestor set and names who must rule | 0 | **20** |
| **B** | 4 — identifies the path-DFS, the current-path-only cycle guard, branching ≤5, and the `5^64` worst case | 5 — cites the project's own proof-document witness (F1) and explains why a state-keyed memo replays a value computed under one ancestor set under another | 3 — explicitly calls the memo a category error and cites `EXP-2.md` hard constraint | 4 — recommends replacing the path DFS with the Part-A state-graph fixpoint, argues the smoke asserts that quantity, and gives a concrete diff sketch | 2 — state space, reachable set, worst-case, budget, fixpoint cost, and suite cost are all denominated | 0 — does not take the no-fix branch; instead proposes a bounded fix | 0 | **18** |
| **C** | 4 — path-local check, a machine-verified 6-cycle, captures re-emptying cells, measured node growth, and the depth-cap interaction | 5 — proves path-dependence by construction, then states and proves a theorem that the fresh-start root value equals `median(L,TIE,H)` | 3 — calls the T452 patch a category error; notes its own concession that it is "correct for the first-path computation" is not a specification | 4 — recommends a retrograde solver with the original path brute demoted to a fixture, and mechanizes the equivalence with tests | 2 — full denominators table, including measured sweeps, fix cost, and max forced-win length | 0 — argues a semantics-preserving bounded fix exists; no no-fix proof | 0 | **18** |
| **D** | 4 — states the DFS enumerates plays, the cycle guard only scans the current path, no global visited set, and the simple-path count | 5 — explicit construction: the value depends on the ancestor set, and two different paths to the same state can yield different values | 3 — calls the state-only memo a category error and notes it "assumes the conclusion" per `EXP-2.md` | 3 — recommends a state-graph solver but does not prove on its own that the state-graph value equals the path-conditioned value on 2×2; the no-fix branch is present and well argued | 2 — denominators present, including the 2430/1620 encoding discrepancy | 2 — proves no bounded fix for literal `brute_value` semantics and names the project owner / Dabir / operator | 0 | **19** |
| **E** | 4 — clear mechanism: path-local check, branching ≤5, `DEPTH_LIMIT=64`, simple-path count vs state count | 5 — formal path-dependence construction via different ancestor sets `P1` and `P2` and a descendant `d` | 3 — category error: state-keyed memo substitutes a state-value function for a path-value function | 4 — proves no bounded fix for simple-path semantics and states the only bounded option is a definitional change to the state-graph loopy game | 2 — denominators present, including the exact `(state, ancestor-set)` state-space estimate | 2 — proves infeasibility of the exact memo and names the ruleset owner / Orchestrator / human | 0 | **20** |
| **F** | 4 — detailed mechanism, including the 160-state SCC, growth table, and the four crashing tests | 5 — concrete demonstration: the same state `a` with empty vs `{a}` history yields `-4` vs `0` | 3 — "right answer, wrong reason, on this goban only"; category error in general | 4 — alpha-beta with no transposition table preserves the exact first-revisit value and fits the budget (cites audit node counts); also gives a retrograde alternative | 2 — extensive denominators and cross-validation against committed audit outputs | 0 — concludes a fix exists; no no-fix proof | 0 | **18** |
| **G** | 4 — path-local check, 160-state SCC, a 57-ply repetition-free witness, and a measured growth table | 5 — 58 witness states of path-dependence plus a root path-independence proof via memoryless threshold-attractor strategies | 3 — identifies the memo's real bug as caching path-local verdicts as global facts, linking it to ADR-0013 GHI | 4 — full-window Knuth–Moore alpha-beta with per-frame buffers; exact by theorem and supported by audit measurements | 2 — denominators throughout, including four fidelity controls for the port | 0 — concludes a fix exists; no no-fix proof | 0 | **18** |

## Citation checks

I spot-checked the load-bearing source citations and a representative sample of
the cited documents. All matched the lane's use; no fabricated citations were
found.

- `src/qa023_brute_2x2.zig` lines `:81`, `:198`, `:202-206`, `:216-217`, `:221`, `:231`, `:239-242`, `:255-257`, `:266`, `:321`, `:408-509` — verified.
- `src/qa023_smoke_2x2.zig` `:13-20` — verified the five anchors and the PSK-by-accident note.
- `docs/infra/dispatch/EXP-2.md` `:18-19` (QA-023 claim), `:144-155` (hard constraint / thrash), `:165-179` (memo failure text) — verified.
- `docs/infra/suite-truth.md` crash family 2 and the bisect back to `7c71fe5` — verified.
- `docs/infra/assertion-ledger/assertions.jsonl` A0017 — verified.
- `docs/audits/2026-07-30-audit-2x2-mismatch-zig.stdout` `:37-38` alpha-beta node counts — verified.
- `docs/research/goban-pathology-2026-08-05.md` `:159-176` SCC census and 7-state cycle — verified.
- `findings/T457-semantics-change-detection.json` 1-ko shape returning `-4` under the patch — verified.
- `docs/decisions/0013-sound-finisher-and-dependency-guarded-memo.md` GHI text — verified.
- `docs/decisions/0010-bracket-guided-finishing.md` exactness discipline — verified.
- `git show dcc5076` confirms T382 reported "2x2 legal=57" — verifying lane G's control.

## Disagreements between lanes

1. **Path-dependence vs. fresh-start path-independence.** Lanes A, D, and E treat the value as path-dependent full stop. Lanes C, F, and G qualify this: the recursion is path-dependent (the cycle check reads history), but on 2×2 the fresh-start root value happens to equal the state-graph loopy value because the maximum forced-win length / attractor rank is small (≤3) compared with `DEPTH_LIMIT=64`. My reading of the source agrees with the qualified view: path-dependence is real for interior calls, but 2×2 is the vacuous case where it does not change the root value.

2. **Does a bounded, semantics-preserving fix exist?** A, D, and E say no for the simple-path semantics; B, C, F, and G say yes. The difference hinges on whether one accepts alpha-beta over the `(path, state)` tree as preserving the measured quantity. The 2026-07-30 audit measured exactly that: full-window alpha-beta with no transposition table disagreed with the fixpoint on 0/172 states and used ≤339,959 nodes per state. So a bounded fix preserving the path-conditioned value does exist on 2×2; the state-graph solver is a second, cheaper route that additionally relies on the 2×2-specific root path-independence fact.

3. **The 1-ko smoke expectation at `src/qa023_brute_2x2.zig:508`.** Lanes C, F, and G identify it as wrong (`0` should be `-4`) and give a forced line. Lanes A, B, D, and E do not address it. The source line asserts `try expect(v == 0)` for a `{W@0,B@1}` White-to-move position; the forced sequence `W@3` (capture), `B` pass, `W` pass yields `area_score = -4`. The expectation is therefore incorrect.

4. **The state-only memo patch.** All seven lanes agree it is unsound / a category error. The consensus is solid.

## My verdict on the underlying question

The explosion is not a rules-semantics regression; it is structural.
`brute_value` detects cycles only along the current path, so it enumerates
simple paths over a cyclic 2×2 graph. The same state is re-expanded from every
path that reaches it, giving work exponential in `DEPTH_LIMIT` rather than
linear in the state count.

A state-keyed memo is a category error: the function being cached is
`(state, ancestor-set)`, not `state`, so memoizing by state reuses a value
computed under one history for a different history.

A bounded fix that preserves *exactly* what the current code measures is
possible on 2×2: full-window alpha-beta over the `(path, state)` tree prunes
only subtrees that cannot affect the root, never reuses path-dependent values
across paths, and the 2026-07-30 audit measured it at ≤339,959 nodes per
state. Alternatively, one can exploit the measured 2×2 fact that the
fresh-start value is path-independent and replace the evaluator with a retrograde
state-graph solve; that is cheaper but changes the search paradigm.

Whichever route is taken, the existing `1-ko shape` smoke expectation
(`v == 0` at `src/qa023_brute_2x2.zig:508`) is wrong and must be corrected to
`-4`; raising `NODE_BUDGET` is forbidden; and the T452 state-only memo must not
be adopted.
