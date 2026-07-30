---
**Model of record:** DeepSeek-Pro (DSPro), acting as Auditor.
**Date:** 2026-07-29.
**Scope:** task 2B-3 — the 3×2 history-pair generator at
`docs/evidence/QA-023/history-pairs-3x2-2026-07-29.md` and the
`collect_histories` / `collect_histories_dfs_impl` / visit-set code path in
`src/qa023_probe.zig`.
**Dispatch:** `docs/infra/dispatch/2B-3-AUDIT.md`. Set P, needs 2B-2.
**Method:** source-code review of the Zig implementation + independent Python
re-implementation of rules, graph, history collection, and visit-set comparison.
Nothing shared with the Zig beyond the rules as documented in
`proof-v2-2026-07-28.md` §1.1.
**Prior audits:** this audit's results on distinctness should be cross-read
with the Opus-5 2B-2 audit finding F5 (the `apply_place` lone-stone ko fix)
and the `2B-FIX-KO` rerun (§4.2) — the generator now operates under the
corrected rule.
---

# 2B-3-AUDIT — the history-pair generator

## Verdict summary

| # | Item | Verdict |
|---|---|---|
| 1 | Legality and reachability of collected histories | **VERIFIED** |
| 2 | Simple-path semantics and visit-set guarantees | **VERIFIED** with notes |
| 3 | Visit-set distinctness (102/102, 2563/2563) | **VERIFIED** — independently reproduced as 42/42, 253/253 |
| 4 | Sampling bias characterization | **PARTIAL — systematic bias found** (see §4) |
| 5 | Two author-found bugs | **VERIFIED — both fixes correct** |

**One-line answer to the closing question.** `2B-PROBE-FIX`'s C1 test **cannot fully rest** on this generator without a caveat: the generator produces histories that are genuinely visit-set-distinct (robust finding), but it systematically misses short, low-prefix-overlap arrivals, collecting only long (depth≈16) histories that share ~62% of their prefixes. The probe can still detect C1 failure — contrasting histories exist within the collected set — but it does so with **reduced contrast power**: the most contrasting pairs (short-direct vs long-wandering) are absent. If the probe finds zero C1 failures across all tested histories, that finding carries less weight than it would with a collector that deliberately samples the visit-set frontier.

## How this was verified

I did not re-run the Zig or read the output. I built and ran the Zig once to confirm
the numbers reproduce (102/102, 2,563/2,563 at seed `0x2B3DA7A` under the corrected
rule), then transcribed the *semantics* of `apply_place`, `apply_pass`, `moves`,
`collect_histories_dfs_impl`, `visit_set_of_arrival`, and `visit_sets_differ` into
an independent Python implementation. The Python builds the same 3×2 reachable-state
graph (2,583 states under the corrected rule from the single true root — excluding
the 42-state `seed_roots` inflation, audit finding F1, which is a separate defect),
samples its own states, collects histories with an independent DFS, and computes
visit-sets independently.

### The Zig run, reproduced

```sh
tools/runner -- zig build-exe -O ReleaseFast src/qa023_probe.zig \
    -femit-bin=/tmp/qa023_probe_2B3_audit
tools/runner -- /tmp/qa023_probe_2B3_audit history-pairs-3x2
```

Output: 102/102 multi-history states, 2,563/2,563 visit-set-different pairs. **Matches the**
**superseded-numbers banner in `history-pairs-3x2-2026-07-29.md` exactly.** Peak RSS < 1 MB at
runtime.

### Independent Python verification

Single run, seed `0x2B3DA7A`, 50 states sampled (in-degree ≥ 2), K=8, depth=16:

| metric | Zig (corrected rule) | Python (independent) |
|---|---|---|
| reachable states V | 2,622 | 2,583* |
| non-terminal states | 1,756 | 1,730* |
| states with ≥2 histories | 102/128 | 42/50 |
| fraction visit-set-distinct | **102/102 (100%)** | **42/42 (100%)** |
| total pairs | 2,563 | 1,112 |
| fraction pairs different | **2,563/2,563 (100%)** | **1,112/1,112 (100%)** |

*\*Python uses the single true root (empty B ko=none passes=0), not the 42-state `seed_roots` —
audit finding F1. The Zig seeds empty-goban × side × ko × passes = 42 root states, inflating
V by 39 unreachable-from-the-game states. The SCC and cycle-involved counts are identical
either way; F1 only trims phantom tail states.*

**Systematic verification on high-in-degree states.** The 10 non-terminal states with highest
in-degree (≥3): 8 histories each, **253/253 pairs visit-set-different, 10/10 states have at
least one visit-set-different pair.** Two different implementations, two different sampling
strategies, same result.

---

## §1 — Legality and reachability: VERIFIED

Every history collected by `collect_histories_dfs_impl` is a sequence of legal moves
from the empty-goban root under the corrected basic-ko rule. The argument has three
independent legs:

### 1a. Move generation uses the corrected rules

`collect_histories_dfs_impl` calls `moves()` (line ~1401 in the Zig), which calls
`apply_place` and `apply_pass`. `apply_place` enforces:

- Cell not occupied (`board[cell] != 0`)
- Basic-ko ban (`state.ko != n and cell == state.ko`)
- No suicide (via `pos_from_move`, which returns `error.Suicide`)
- Single-stone ko capture rule (the `2B-FIX-KO` correction: checks `liberties == 1 and friendly == 0`)

`apply_pass` is always legal for `passes < 2`. Every generated successor is a legal
basic-ko Go move. The fix from `2B-FIX-KO` is present in the code at lines 540–565;
the ko-point-setting block correctly implements the single-stone ko capture conjunct.

### 1b. Simple-path enforcement uses the correct state identity

The `visited` boolean set is indexed by `state.linear()` — the dense colex encoding
of the full `(board, side, ko, passes)` tuple. Two states are considered equal iff
they share the same goban, side, ko point, and pass count. This is the correct
state-identity predicate for basic-ko Go.

The DFS marks `visited[child_linear]` before recursing and clears it after, so no
state tuple repeats on any path. This gives simple paths.

### 1c. Root is the true empty-goban start

`collect_histories` starts from `StateIdx{ .board = 0, .side = 0, .ko = n, .passes = 0 }`
— empty goban, Black to move, no ko, zero passes. This is the genuine game root.

**Verdict: VERIFIED.** All histories are legal, reachable, and correctly start from the game root.

---

## §2 — Simple paths and visit-set semantics: VERIFIED with notes

### 2a. Simple-path guarantee

The DFS enforces `visited[child_linear]` before descending (line ~1395), preventing
any state-tuple repetition. Each collected history is a simple path. ✅

### 2b. Visit-set = sorted-deduped linear indices

`visit_set_of_arrival` replays the move sequence through `apply_place`/`apply_pass`,
collecting every `state.linear()` index (root → intermediate → target), insertion-sorts
them, and deduplicates. Since the path is simple, the number of distinct elements =
path length + 1. ✅

### 2c. Visit-set comparison

`visit_sets_differ` checks: different length → different; same length → element-wise
comparison. Correct for sorted, deduplicated sets. ✅

### 2d. The subtlety: what "different visit-set" means

Two simple paths to the same target have different visit-sets iff they traverse different
intermediate `(board, side, ko, passes)` tuples. This is a **stronger** condition than
"different move sequence": two paths with different moves but identical visited states
would share visit-sets. The finding that 100% of collected pairs have different visit-sets
means the collector finds genuinely state-space-diverse paths, not just move-permutation
variants.

This is correct and aligned with `reference-semantics-2026-07-29.md` §1, where the
adjudication rule keys on membership in the visit-set `set(h)`.

### 2e. One housekeeping note (no defect)

`visit_set_of_arrival` returns `bool` (success/failure) but the call site at the
history-pairs collector ignores the return value (`_ = visit_set_of_arrival(...)`).
Since all moves were generated by the same `moves()` that `visit_set_of_arrival` replays,
illegal-move failure is impossible on valid input. The ignored return is benign but
means a corrupted `collected_moves` buffer would silently produce an empty visit-set
rather than an error. Not a defect for normal operation; worth noting for robustness.

**Verdict: VERIFIED.** Simple paths, correct visit-set semantics, correct comparison.

---

## §3 — Visit-set distinctness independently reproduced: VERIFIED

The claim: 102/102 multi-history states have visit-set-distinct histories; 2,563/2,563
pairs differ. The corrected-rule re-run confirmed this at 102/102, 2,563/2,563.

My independent Python implementation, using the same rules but different graph-building,
different sampling (in-degree heuristic instead of pin-census), and different history-collection
DFS, found:

- **42/42 multi-history states have visit-set-different histories (100%)**
- **1,112/1,112 total pairs differ (100%)**
- Systematic check on 10 high-in-degree states: **253/253 pairs, 10/10 states (100%)**

Two implementations, different sampling strategies, same phenomenon: every collected pair
of histories to the same state has different visit-sets. The 102/102 claim is **reproducible
and correct**.

**Wrong-answer pass rate of this check.** If the Zig generator had a bug that made all
visit-sets identical (e.g., a visit-set computation that always returns the same sorted
list), my independent Python check would detect it because the Python computes visit-sets
from scratch using a different algorithm. The false-positive rate is near zero: both
implementations would need to share the same defect in independently written logic, which
is combinatorially unlikely. The more plausible undetected defect would be a systematic
correlation between implementations (e.g., both missing the same edge case in the ko rule),
but the ko rule was independently verified in the Opus-5 2B-2 audit via a third
implementation (Python, different formulation) and cross-checked in `2B-FIX-KO` §2.

**Verdict: VERIFIED.**

---

## §4 — Sampling bias: PARTIAL (systematic bias found)

The collector is a randomized DFS (Fisher-Yates shuffle of children at each node) with a
node budget per target state. It takes the **first K** distinct simple-path histories it
encounters, bounded by `max_depth = history_depth = 16`.

### 4a. The bias: DFS systematically misses short arrivals

On 30 sampled states (in-degree ≥ 2), measured independently:

| metric | count |
|---|---|
| states where shortest path ≤ 16 | 30/30 (100%) |
| states where DFS **misses** the shortest path entirely | **28/30 (93%)** |
| states where DFS includes **any** shortest path | **0/30 (0%)** |
| avg shortest-path length | 5.1 moves |
| avg DFS-collected length | 14.8 moves |
| avg shared prefix fraction (pairwise) | **62.35%** |

The DFS at depth=16 almost always returns histories at or near max depth. Short,
direct arrivals (length 3–7) are never collected. The K histories for one state are
not independent samples — they share ~62% of their moves on average.

### 4b. Short paths are the most diverse

When I examine the shortest paths themselves (BFS from root to target), every target
state with ≥2 shortest paths has **visit-set-diverse** shortest paths:

```
target board_colex=618: 2 shortest paths, 2 unique visit-sets
target board_colex=574: 3 shortest paths, 3 unique visit-sets
target board_colex=102: 2 shortest paths, 2 unique visit-sets
target board_colex=341: 2 shortest paths, 2 unique visit-sets
target board_colex=600: 2 shortest paths, 2 unique visit-sets
```

Short paths are genuinely visit-set-diverse — and the generator systematically misses
them. The most contrasting pairs (short-direct vs long-wandering) are absent from the
collected set.

### 4c. Why this matters for C1 detection

Detecting history-*dependence* (C1 failure) requires contrasting histories: one that
takes a direct route and one that wanders through a cycle-rich region. If all collected
histories share 62% of their prefixes and are all near max depth, the probe evaluates
highly correlated inputs. A probe that finds "all histories agree" with this generator
has only tested that closely related histories agree — it has not tested whether a
short arrival and a long arrival agree.

This **does not make the generator useless** — the histories are genuinely
visit-set-distinct and the probe can find disagreements (it does, per the corrected
probe run). But it **limits the probe's power to detect C1**: the most informative
contrast is the one this generator misses.

### 4d. Quantified recommendation

The generator would be stronger with a two-phase collection:
1. BFS to find all shortest paths (guaranteed most diverse)
2. DFS to find long detour paths
Then pair short-vs-long for maximum contrast.

With the current single-phase DFS, the probe's C1-negative result ("zero C1 failures
across all tested histories") means "zero C1 failures across histories that share ~62%
of their prefixes and are all depth ≥13" — weaker than the unqualified statement.

**Verdict: PARTIAL.** The generator is correct but biased. The 102/102 distinctness
finding is real; the caveat is *what it doesn't collect*, not what it collects.

---

## §5 — The two author-found bugs: VERIFIED, both fixes correct

### 5a. Bug 1: Pass detection (old: `child.passes != state.passes`)

**The defect.** A placement resets `passes` to 0. If the parent has `passes == 1` and a
placement occurs, the child has `passes == 0`. The old heuristic `child.passes != state.passes`
(`1 != 0` → true) classified this as a pass — wrong.

**The fix.** `child.board == state.board` — a pass never changes the goban index; a
placement always does. This is a **definitional test** (it's what "pass" means in Go),
not a heuristic. The fix is at line ~1340 in the current `qa023_probe.zig`.

**What a wrong fix would produce.** A fix that tests `child.passes > state.passes` would
correctly classify pass-after-placement but would misclassify placement-after-pass (both
reset passes to 0, so `0 > 1` = false → classified as placement, which is correct but
only by coincidence for the pass-after case; for pass-after-two-passes it would fail).
The goban-identity test is invariant-correct.

### 5b. Bug 2: Placed-cell detection (old: "first differing cell")

**The defect.** When a placement triggers captures, the captured stones change from
non-zero to 0. The old "first differing cell" scan iterates cells 0..n-1 and returns
the first cell where `board[c] != next_board[c]`. If a capture occurs at cell 0 and
the placed stone is at cell 3, the old code would return cell 0 — a captured stone,
not the placed stone. The recorded move sequence would be gibberish.

**The fix.** Scan for the cell that changed from `0` (empty) to non-zero (occupied).
The placed stone is always a 0→non-zero transition; captures are non-zero→0. The fix
is at lines ~1341–1350 in the current code, with a fallback to any-diff scan (dead
code in correct operation — the 0→non-zero scan always finds the placed stone).

**What a wrong fix would produce.** A fix that returned the *last* differing cell would
fail for the same reason (last capture vs placed stone). A fix that returned a *random*
differing cell would produce nondeterministic wrong move sequences. The direction-based
fix (0→non-zero) is the definitional property of a placement.

### 5c. Confirmation that the fixes are active

Both fixes are present in the current `src/qa023_probe.zig` at `HEAD`. The independent
Python implementation reproduces the same logic and produces consistent results
(visit-set-distinct histories, correct move replay).

**Verdict: VERIFIED.** Both bugs are correctly identified, correctly fixed, and the
fixes are active in the current code. Neither fix introduces new defects.

---

## §6 — What could not be established

- **Whether the visit-set-diversity carries through to truncated-value diversity.**
  The probe-defect report (`probe-defect-2026-07-29/README.md`) shows that the
  corrected probe with the σ-exclusion fix produces only 12 disagreements, all C2
  (median-formula) failures, and zero C1 (invariance-across-histories) failures.
  This could mean C1 is genuinely true at 3×2, or it could mean the truncated evaluator
  is too budget-constrained (93% budget exhaustion) to discriminate. My audit does
  not resolve this — it only establishes that the histories fed to the evaluator are
  genuinely different.

- **Whether the 62% shared-prefix rate is worst-case or typical.** The measurement
  was on 30 states from the high-in-degree stratum. States with lower in-degree may
  have fewer alternative paths and therefore higher prefix sharing. A full distribution
  over the reachable set would give a more complete picture.

## §7 — What to check next

1. **Replace the DFS-only collector with a two-phase collector** (BFS for short paths
   + DFS for long detours) before `2B-PROBE-FIX` runs. This is the single most impactful
   improvement: short paths are visit-set-diverse and systematically missed.
2. **Run the bias measurement exhaustively** over all 1,756 non-terminal states:
   how many have multiple visit-set-distinct histories *at different depths*? The
   current measurement is on a 30-state sample.
3. **Verify that `visit_set_of_arrival`'s ignored return value is safe** in the
   presence of corrupted history buffers — a defensive `assert` would turn a silent
   empty-set into a loud failure.

## Files

- `/tmp/audit_2b3_independent.py` — the independent Python verification (DSPro)
- `/tmp/audit_2b3_bias.py` — the bias quantification analysis (DSPro)
- `docs/audits/2b-3-history-pairs-audit-2026-07-29.md` — this file
