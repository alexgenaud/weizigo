Task: ORCHESTRATOR-VERIFY (unregistered, Orchestrator's own absorption check)
Role: Orchestrator · Model: Opus 5 (claude-opus-5[1m]) · Date: 2026-07-29

# The QA-023 probe returned TIE on its first node, unconditionally — the published falsification is an artefact

**Headline: the 2B-4 / 2B-FIX-KO disagreement counts (390/1,080 and 454/1,133)
do not measure history-sensitivity. `truncated_value` was called with an
arrival set that contains the target state σ itself, so its first revisit
check matched σ against σ and returned `TIE` before exploring a single move.
Every one of the 1,133 evaluations did this — measured, not inferred: 1,133 of
1,133 σ-in-arrival collisions.**

This does **not** rehabilitate QA-023. With the defect corrected the probe
still shows 12 disagreements — but they run the *opposite* direction, and they
localise to a different claim. See §5.

## 1. The defect

`docs/evidence/QA-023/reference-semantics-2026-07-29.md` §1 defines the
arrival history as:

> `h` = the sequence of states from the empty-goban root to σ
> (**exclusive of σ**)

The probe builds it inclusive. At `src/qa023_probe.zig:1681-1712` the arrival
buffer is seeded with the root and then appends the state after **every** move
of the sampled history — the last append is σ. `arrival_len` counts that entry.
At `:1721` the whole buffer is handed to `truncated_value`:

```zig
const v = truncated_value(state, &target_board,
                          arrival_buf[0..arrival_len], arrival_len, ...);
```

`truncated_value` opens with the revisit test (`:1162-1173`), scanning
`arrival[0..arrival_len]` for a state equal to its own argument. `fp_eq`
compares `(board, side, ko, passes)` — a correct full-tuple test — and
`arrival[arrival_len - 1]` *is* σ. So the test fires on index `arrival_len-1`
and returns `tie_value` at `:1172`, before the terminal check (`:1187`), before
`moves()` (`:1191`), before any recursion.

**The evaluator is `return TIE;` with extra steps.**

## 2. How the run output tells you this, without reading the source

Three signatures in the published stdout, all inconsistent with an evaluator
that explores anything:

| signature | published value | what it should look like |
|---|---|---|
| value-agreements (`v != TIE, v == V`) | **0**, in every run ever recorded | non-zero — some states do have definite values |
| budget-exhausted | **0 / 1,133** | non-zero — path-DFS on a densely cyclic graph is expensive |
| disagreement rate vs history depth | **flat**, 34–43% for depth ∈ {2,…,40} | should vary with how much history is burned |

A path-enumerating DFS with a 100,000-node budget that exhausts **zero** times
on the graph 2B-2 measured at 216,176 simple cycles is not plausible. It
returned on node one, so it spent exactly 1 budget unit per evaluation.

`as-published-depth-sweep.txt` is the depth sweep — 7 depths, same seed
(`0x2B4DA7A`), 256 samples × 8 histories each:

```
[depth 2]  evaluated 7    value-agree 0  TIE 4    exhausted 0/7     disagree 3
[depth 4]  evaluated 64   value-agree 0  TIE 104  exhausted 0/159   disagree 55
[depth 6]  evaluated 186  value-agree 0  TIE 556  exhausted 0/958   disagree 402
[depth 8]  evaluated 172  value-agree 0  TIE 570  exhausted 0/1043  disagree 473
[depth 12] evaluated 128  value-agree 0  TIE 509  exhausted 0/837   disagree 328
[depth 16] evaluated 171  value-agree 0  TIE 679  exhausted 0/1133  disagree 454
[depth 24] evaluated 156  value-agree 0  TIE 588  exhausted 0/1032  disagree 444
[depth 40] evaluated 131  value-agree 0  TIE 505  exhausted 0/869   disagree 364
```

Depth 16 reproduces the 2B-FIX-KO headline exactly (679 / 454 / 1,133), so this
is the same build and the same measurement, not a different configuration.

**A disagreement appears at history-depth 2, with a 3-state arrival.** Whatever
the published number measures, it is not an effect of long arrival histories.

## 3. What the published counts actually counted

With the evaluator pinned to `TIE`, the reported three-way split degenerates to
a partition of the sampled states by their *fixpoint* value alone:

- `TIE-valued` (679) = sampled evaluations where `median(L, TIE, H) == 0`
- `disagreements` (454) = sampled evaluations where `median(L, TIE, H) != 0`

So "36.1%" and "40.1%" are estimates of *how often the median fixpoint pins a
non-zero value on a sampled state*. That is a fact about the fixpoint's pin
census — not a comparison of anything against anything.

This also explains, with one cause, three anomalies previously reported as
separate findings:

1. **2B-FIX-KO §6.1** — the in-probe perturbation branch is unreachable. It sits
   behind `v != TIE`, and `v` is always TIE. Same root cause.
2. **2B-FIX-KO's** observation that the count *rose* after the ko fix
   (390 → 454). The ko fix changed the reachable set and the pin census; the
   "disagreement" count tracks the pin census, so of course it moved. It is not
   evidence about ko or about history.
3. **`budget-exhausted: 0`** was read as a clean bill of health in both
   deliverables. It was the symptom.

## 4. A worked counterexample (why this is a defect, not a semantics dispute)

From the depth-4 run, disagreement #1:

```
state=(108,0,6,1)  V_fixpoint=6  truncated=TIE  arrival_len=5
arrival: B4 pass B3 pass
```

`ko=6` is the "no ko" sentinel (`= n`, 3×2 has 6 cells); `passes=1`; Black to
move. Replaying the arrival: Black 4, White pass, Black 3, White pass. The
goban holds two Black stones and no White stone, so under Tromp–Taylor area
scoring every empty cell reaches only Black: `area_score = +6`.

Black is to move at `passes == 1`. **Black passes; `passes` becomes 2; the game
is over at +6.** That successor is generated first by `moves()` (`:668`, the
pass edge precedes placements), and it cannot be a revisit — a `passes == 2`
state is terminal, so no arrival path can have travelled through it and come
back. A correct evaluator returns +6 here. The probe returns TIE.

The fixpoint's +6 is right and the truncation's TIE is wrong. There is no
reading of §1 under which TIE is defensible at this state.

## 5. What the corrected probe reports — and why QA-023 is still not cleared

`qa023_probe-corrected.zig` (in this directory) changes two things and nothing
else. Both are in the harness, not in the rules:

1. **`:1721` passes `arrival_len - 1`** — σ excluded, per §1. An assertion counts
   the collision before excluding it, which is where the 1,133/1,133 comes from.
2. **`:1593` scratch sized 4096** instead of `history_depth + 4`. The scratch
   stack holds the *continuation* path; its depth is bounded by the reachable
   state count (§1's termination argument), not by the arrival depth. At
   `history_depth = 4` the continuation could go 8 plies before overflowing to
   `null` — silently counted in the budget-exhausted line. Defect 1 masked this
   completely: nothing ever recursed, so the scratch was never touched.

Same seed, same parameters, depth 16 (`corrected-depth16.stdout`):

| metric | as published | corrected |
|---|---|---|
| samples evaluated | 171 | 171 |
| total evaluations | 1,133 | 1,133 |
| **value-agreements** | **0** | **45** |
| TIE-valued | 679 | 20 |
| **budget-exhausted** | **0** | **1,056** |
| **disagreements** | **454** | **12** |
| σ-in-arrival collisions | — | **1,133 / 1,133** |

The instrument now discriminates: 45 evaluations return a real value that
matches the fixpoint. It also now costs what it should — 1,056 of 1,133
evaluations exhaust the 100,000-node budget, i.e. **93% of the measurement is
missing**, which is the honest cost of trilemma horn 1 (2B-0 §2). Verified as
genuine budget exhaustion, not scratch overflow: the scratch fix alone changes
none of these numbers at depth 16.

**The residual 12 disagreements are real signal and must not be waved away.**
They invert the published direction:

```
DISAGREE #1: state=(586,1,6,1) V_fixpoint=0 truncated=1 arrival_len=16
DISAGREE #2: state=(586,1,6,1) V_fixpoint=0 truncated=1 arrival_len=16
DISAGREE #3: state=(586,1,6,1) V_fixpoint=0 truncated=1 arrival_len=16
DISAGREE #4: state=(586,1,6,1) V_fixpoint=0 truncated=1 arrival_len=16
DISAGREE #5: state=(586,1,6,1) V_fixpoint=0 truncated=1 arrival_len=16
```

Now the *truncation* says +1 and the *fixpoint* pins TIE = 0 — the median rule
**over-pins**. And note what the five rows share: one state, five different
arrival histories, one value. Across every corrected observation the truncated
value is invariant in the arrival history.

## 6. Which conjunct of QA-023 this bears on

§1 states QA-023 as a conjunction, and the pre-registered falsifier does not
distinguish them:

> for every reachable σ and every two arrival histories h₁, h₂:
> `V(σ|set(h₁)) = V(σ|set(h₂))` **(C1)** — and this common value equals
> `median(L(σ), TIE, H(σ))` **(C2)**

- **C1 — Markovian state-sufficiency.** This is what the `QA-023` row in
  `CLAIMS.md` actually asserts, and it is what the roadmap needs. **Not one
  observation contradicts it** — but see the qualification below, which is
  load-bearing. Every corrected disagreement is invariant across the histories
  sampled for that state; the as-published run is invariant too, vacuously.

  **QUALIFIED 2026-07-29 by `2B-3-AUDIT`** (`docs/audits/2b-3-history-pairs-audit-2026-07-29.md`,
  DSPro, independent Python re-implementation): the history generator has a
  systematic bias — on 30 sampled states it **misses the shortest arrival path
  entirely in 28 (93%)** and includes any shortest path in **0**, collecting
  paths averaging 14.8 moves where the shortest average 5.1, with **62% pairwise
  shared prefix**. Short paths are the most visit-set-diverse. So "no
  observation contradicts C1" means *no observation among highly correlated
  near-max-depth histories* — the short-vs-long contrast that would actually
  test C1 was never sampled. **C1 is better described as UNTESTED than as
  unrefuted**, and testing it needs a two-phase generator (BFS shortest paths +
  DFS detours, paired short-vs-long), not merely the probe fix. Folded into the
  `2B-PROBE-FIX` brief as a mid-flight addendum.
- **C2 — the median formula.** This is `QA-026` / proof-v2 Thm 5.1. The 12
  residual disagreements are all C2 failures, all in the over-pinning direction
  (fixpoint TIE where truncation has a value), on a graph where the median rule
  pins TIE at **1,532 of 1,756** non-terminal states (87%).

The distinction is the whole roadmap. C1 failing would mean no tractable
Markovian representation exists — the outcome `AUDIT-DSPro` §7 says the project
may not survive. C2 failing means a **formula** is wrong and can be replaced,
with the L/H machinery and the census intact. **The corrected evidence points at
C2 and away from C1** — the opposite of what CURRENT.md's banner currently says.

## 7. Status of every affected number

| number | status |
|---|---|
| 2B-4: 390/1,080 (36.1%) | **INVALID** — artefact |
| 2B-FIX-KO: 454/1,133 (40.1%), 12 seed × depth runs | **INVALID** — same artefact |
| 2B-FIX-KO: "falsification is not a wrong-rule artefact" | **unsupported** — both sides of that comparison were pinned to TIE |
| the ko fix itself (`apply_place` lone-stone conjunct) | **STANDS** — independently verified against Python, unaffected by this |
| 2B-2 census (V, E, SCC, cycle counts) | **STANDS** — different code path, independently reproduced |
| 2B-5 NEG/POS calibration | **STANDS**, and see below |
| corrected: 12 disagreements / 77 within-budget | **CANDIDATE C2 counterexamples** — needs adjudication, 93% of the sample is missing |

**2B-5's POS calibration deserves a note.** It passed — the PSK arm found 68 and
48 disagreements where T13 predicts ≥12 — and that pass is *why* this defect was
findable rather than fatal: it established the machinery can discriminate, which
made "0 value-agreements, ever" the anomaly it is. But the PSK arm is a separate
code path (`psk_exact_value`, `psk_collect_histories`) that does **not** share
the defective call site. So POS passing did **not** cover the basic-ko arm, and
should not be read as having done so. That is the one gap in an otherwise
correct calibration design: the positive control exercised a parallel
implementation rather than the instrument under test.

## 8. Reproduction

```sh
tools/runner -- zig build-exe src/qa023_probe.zig -femit-bin=$SCRATCH/probe
tools/runner -- $SCRATCH/probe probe-3x2 --seed 0x2B4DA7A \
    --n-samples 256 --k-histories 8 --history-depth 16     # 679/454/0/0

# corrected: symlink src/*.zig into a scratch dir, replace qa023_probe.zig
# with qa023_probe-corrected.zig from this directory, rebuild, same command.
                                                            # 20/12/45/1056
```

`--history-depth` accepts any value; there is no budget flag (it is hardcoded at
`:3287`), which is worth adding when this is fixed for real.

## 9. Files

- `as-published-depth16.stdout` — the 679/454 run, reproduced at HEAD
- `as-published-depth-sweep.txt` — 8 depths, value-agreements 0 and exhausted 0 at every one
- `corrected-depth16.stdout` — the 45/20/12/1,056 run
- `qa023_probe-corrected.zig` — the two-line harness correction, for the fixer to review (**not** applied to `src/`; `2B-6` holds that file)

## 10. What this does not claim

I am one model that found this by reading one call site and running one build.
`src/qa023_probe.zig` is **not** edited — the corrected copy lives here for
review. No claim status is changed by this document. The adjudication of the 12
residual disagreements, and the decision on C1 vs C2, belong to a task with a
different model in the seat (`2B-PROBE-FIX`, `2B-6`).
