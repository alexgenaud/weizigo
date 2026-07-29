Task: F1-CENSUS-GAP · Role: worker · Model: DSPro/F1-CENSUS-GAP · Date: 2026-07-30

# F1-CENSUS-GAP — the residual +3 traced; F1's "soft reconciliation" was wrong

## What was asked

Trace the residual +3 discrepancy between two independent predictions of the
corrected 3×2 true-root reachable count:

| source | V |
|---|---|
| `2B-FIX-KO`'s Python port, corrected ko rule + single true root | **2,583** |
| `F1-SEEDROOTS` (DSPro, Zig, in-tree, seeds 42 → 4) | **2,586** |

The F1-SEEDROOTS deliverable "softly reconciled" the +3 as the ko-rule fix
removing 3 additional states. The brief asks to verify that claim rather than
accept it, because "a 'softly reconciled' +3 is the same shape [as previous
defects]: an explanation that sounds plausible and was never checked."

## What I did

### 1. Built a four-configuration diff harness

Wrote `f1-census-gap-diff.py` (standalone, in `docs/evidence/QA-023/`,
read-only on `src/`) that computes the reachable 3×2 state set under four
configurations by combining two ko rules (old: no lone-stone conjunct; new:
lone-stone conjunct per `proof-v2` §1.1) with two seed sets:

| label | ko rule | seeds | description |
|---|---|---|---|
| old+4 | old | 4 (empty × 2 sides × passes={0,1}) | what F1 claimed it ran |
| old+1 | old | 1 (empty, B, KO_NONE, passes=0) | old-rule ground truth |
| new+4 | corrected | 4 | what F1 actually ran |
| new+1 | corrected | 1 | 2B-FIX-KO Python ground truth |

The harness reuses the Opus-5 audit's independent Python implementation
(`docs/evidence/QA-023/ko-fix-2026-07-29/indep_3x2.py`) and its corrected ko
rule from `corrected.py`. Every configuration applies the same legality filter
(`is_legal`) and the same reachability fixpoint.

### 2. Verified against the Zig at HEAD

The Zig binary at HEAD (`zig run -O ReleaseFast src/qa023_probe.zig --
census-3x2`) reports **V = 2,586**, matching the Python `new+4` configuration.
The Zig code at HEAD has BOTH the ko-rule fix (lone-stone conjunct in
`apply_place`) AND the 4-seed fix (`seed_roots` seeds 4 roots). F1-SEEDROOTS
edited the seed sites on top of the already-corrected ko rule.

### 3. Computed the SCC membership of the three phantom states

All three are trivial singleton SCCs (not cycle-involved, not part of any
non-trivial strongly connected component).

## Findings

### Finding 1: F1's "soft reconciliation" is wrong — the +3 is from seed count, not the ko rule

The Python analysis gives:

| configuration | V |
|---|---|
| `old+4` (old ko, 4 seeds) | 2,646 |
| `old+1` (old ko, 1 seed) | 2,643 |
| `new+4` (corrected ko, 4 seeds) | **2,586** |
| `new+1` (corrected ko, 1 seed) | **2,583** |

- **ko-rule effect** (old+4 → new+4): removes **60** states, adds 0
- **seed-count effect** at corrected ko (new+4 → new+1): removes **3** states, adds 0

The +3 gap between 2,586 and 2,583 is the **seed-count delta** (4 seeds → 1 seed),
not the ko-rule delta. The ko-rule fix removes 60 states, not 3.

F1-SEEDROOTS ran `new+4` (corrected ko + 4 seeds), not `old+4` (old ko + 4
seeds) as its deliverable implies. The 2B-FIX-KO ko-rule fix had already landed
in `src/qa023_probe.zig` before F1 edited the seed sites. F1's "before" column
(2,622) was `new+42`, and its "after" (2,586) was `new+4` — the -36 delta is the
seed fix alone, computed on the already-corrected ko rule. The subsequent
comparison to 2,583 (new+1) attributed the residual +3 to the ko-rule fix,
which is factually incorrect: it is the seed-count delta.

### Finding 2: The three states are empty-board seeds/terminals, all trivially unreachable from the true game root

The symmetric difference `new+4 \ new+1` (states in the 4-seed census but not
in the single-true-root census) is exactly three states. All have the empty
3×2 board (`......`, rank 0), ko = none:

| # | state | linear | kind | reachability verdict |
|---|---|---|---|---|
| 1 | (empty, **W**, none, passes=**0**) | 9,477 | seed | **Unreachable from true root.** W cannot be to move on an empty board with passes=0: any path from the true root (empty, B, none, 0) that reaches empty-board-W-to-move must pass through a prior pass, which increments passes to at least 1. Stone placement never returns to an empty board. |
| 2 | (empty, **B**, none, passes=**1**) | 14,580 | seed | **Unreachable from true root.** B-to-move with passes=1 requires W to have passed from (empty, B, none, 0), but W is not to move there. From the true root the only pass is B's: B pass → (empty, W, none, 1), and no sequence reaches (empty, B, none, 1). |
| 3 | (empty, **W**, none, passes=**2**) | 29,889 | cascaded from seed #2 | **Unreachable from true root.** This is the terminal reached by B passing from state #2: (empty, B, none, 1) → B pass → (empty, W, none, 2). The true root's reachable terminal is (empty, B, none, 2) via B-pass, W-pass. |

**Reachability from first principles, for each state:**

**State 1 — (empty, W, none, 0).** The true game root is (empty, B, none, 0).
Every move flips `side`. Every place resets `passes` to 0. Every pass
increments `passes`. Starting from (empty, B, none, 0):
- B places a stone → `passes=0`, `side=W`, board not empty. Cannot return to
  empty via placement (captures leave capturing stones).
- B passes → (empty, W, none, 1). `passes=1`. Cannot reach `passes=0` except
  via placement, which leaves the board non-empty.
Therefore (empty, W, none, 0) is unreachable from the true game root.
**Verdict: UNREACHABLE — phantom seed.**

**State 2 — (empty, B, none, 1).** From (empty, B, none, 0), B passes →
(empty, W, none, 1). To reach B-to-move-with-passes=1, W must pass from a
B-to-move state, but the only B-to-move state reachable from the root without
placing stones is the root itself (passes=0). W is not to move there.
Any placement leaves the board non-empty. Therefore (empty, B, none, 1) is
unreachable from the true game root.
**Verdict: UNREACHABLE — phantom seed.**

**State 3 — (empty, W, none, 2).** Terminal. Reachable only via two
consecutive passes from an empty-board B-to-move state with passes=0.
The true root → B pass → (empty, W, none, 1) → W pass → (empty, B, none, 2).
The W-to-move terminal requires B-to-move with passes≥1, which is state #2
(phantom). Therefore unreachable.
**Verdict: UNREACHABLE — cascaded from phantom seed.**

### Finding 3: The three phantom states are all trivial singleton SCCs

All three have SCC size 1, no self-loops, and are not cycle-involved. They sit
entirely in the tail (drainage into the SCC), not in the SCC itself. Their
presence or absence does not affect:

- The non-trivial SCC (size unchanged)
- The cycle count (no cycles pass through them)
- The cycle-reachable count (they are not reachable from the SCC, nor does the
  SCC reach them)
- The pin_L / pin_H counts (they are all pin_T, and have trivial values)
- B-VACUITY (cycles > 0 either way)

The pin_T count shifts by 3. No headline figure depends on pin_T at the level
of precision that ±3 matters.

## Ruling: which count is authoritative

**2,583 is the authoritative count of genuinely reachable 3×2 states under the
corrected basic-ko rule.** It counts only states reachable from the single true
game root (empty board, Black to move, no ko point, zero passes), which is the
only state that can occur at the start of a real game.

2,586 overcounts by 3: it includes two phantom seeds and one cascaded terminal
that are not reachable from any legal game start. The overcount is harmless —
the phantom states are trivial singletons that affect no load-bearing claim —
but "reachable" in the census should mean "reachable from the game root," not
"reachable from a set of seeds that includes unreachable states."

**Recommendation:** `seed_roots` should seed exactly one root: (empty, B,
KO_NONE, 0). The three extra seeds F1 left in — (empty, W, none, 0), (empty,
B, none, 1), (empty, W, none, 1) — are F1's own defect, parallel to but
smaller than the 42→4 defect it fixed. The passes=1 seed on the W side
(empty, W, none, 1) is reachable from the true root (B pass), so it adds no
phantom states; the other two are not.

## Downstream impact on published numbers

| published number | affected? | how |
|---|---|---|
| V (reachable states) | **yes** | 2,586 → 2,583 (−3) |
| E (directed edges) | **yes** | 5,524 → 5,510 (−14; the 3 phantom states each have out-edges: state 1 has 7, state 2 has 7) |
| terminals (passes=2) | **yes** | 854 → 853 (−1; the W-to-move terminal is phantom) |
| cycle-involved (SCC) | **no** | 1,666 unchanged; phantom states are trivial SCCs |
| cycle-reachable | **no** | 1,680 unchanged |
| distinct legal boards | **no** | 489 unchanged |
| B-VACUITY | **no** | cycles > 0 regardless |
| pin_T / pin_L / pin_H | **minimal** | pin_T shifts by at most 3 |
| ko=cells (real-ko states) | **no** | 24 unchanged; all three phantoms have ko=none |
| B / W counts | **minimal** | B: 1,293→1,292 (−1); W: 1,293→1,291 (−2) |

The only published number the brief explicitly flags as load-bearing is
B-VACUITY, which is unaffected. The cycle census, pin census, and
PINRULE-SUFFICIENCY group structure are unaffected.

## Wrong-answer pass rate of this check

This check uses the Opus-5 audit's Python implementation (`indep_3x2.py`) as
its base. The Python implementation was verified against the Zig on the
42-seed census at V=2,682 (exact match, every headline number). Its corrected
variant (`corrected.py`) was verified against the Zig 2B-FIX-KO run at V=2,622
(exact match). My `new+4` configuration matches the Zig at HEAD (V=2,586).

However, this check is NOT an independent re-implementation — it shares the
Python rules engine with the audit whose correctness it depends on. A defect
in the audit's transcription of the Zig rules (e.g., the `neighbors` order,
the `chain` flood-fill, or the `pos_from_move` suicide check) would propagate
to this analysis. The only independent verification is the Zig-at-HEAD match
at V=2,586, which constrains the combined system (Python rules × Python
reachability) but does not independently verify the diff computation.

**Wrong-answer pass rate: unknown but low-probability for the specific claim.**
The three states are all empty-board states that differ only in `side` and
`passes`, and the reachability argument from first principles (Finding 2) does
not depend on the Python implementation at all — it is a direct graph-distance
argument over the move rules. The claim that these three states are unreachable
from the single true root follows from: (a) every move flips side, (b) every
place leaves a non-empty board, (c) every pass increments passes. These are
true under any correct transcription of the basic-ko rules.

## Could a "softly reconciled" discrepancy of this size hide a systematic error?

**No, the +3 does not hide a systematic error.** It is exactly three isolated
states, all empty-board variants, all trivial in the graph structure. A
systematic error would manifest as a pattern across many states (like the 60
ko-rule states, which form a regular pattern of spurious ko bans across 30
Black and 30 White states in symmetrical board positions).

That said, the "soft reconciliation" narrative in F1-SEEDROOTS *was* a
systematic error of a different kind: it attributed the wrong cause to the
gap, and doing so masked the fact that F1 didn't know which ko rule its own
code was running. Had the +3 been larger or had it included a cycle-involved
state, the misattribution would have led to the wrong fix being applied. The
standing rule "Verify-then-promote" would have caught this — an independent
seat checking F1's claim that "the ko-rule fix removes 3 states" would have
found it removes 60.

## What the corrected census lineage looks like

| step | what | ko rule | seeds | V |
|---|---|---|---|---|
| 2B-2 (published) | original census | old (buggy) | 42 (including 36 phantom ko seeds) | 2,682 |
| 2B-FIX-KO | ko-rule fix only | corrected | 42 | 2,622 |
| F1-SEEDROOTS | seed fix (on top of ko fix) | corrected | 4 | 2,586 |
| → correct | seed fix to single true root | corrected | **1** | **2,583** |

The 2,582→2,583 delta that F1 described as "(F1 fixes only seeds; the combined
fix produces 2,583)" was correct about the number but wrong about the
attribution: the combined fix actually produces 2,586 (corrected ko + 4 seeds),
and the further →2,583 step is reducing the seed count from 4 to 1.

## Files

- `docs/evidence/QA-023/f1-census-gap-diff.py` — the four-configuration diff harness
- `docs/evidence/QA-023/ko-fix-2026-07-29/indep_3x2.py` — the audit Python implementation (base rules)
- `docs/evidence/QA-023/ko-fix-2026-07-29/corrected.py` — the corrected ko rule
- `src/qa023_probe.zig` — the Zig census (read-only; verified V=2,586 at HEAD)

## PROVENANCE

- Harness: `docs/evidence/QA-023/f1-census-gap-diff.py` (Python 3, stdlib +
  `indep_3x2.py` + `corrected.py`)
- Zig verification: `tools/runner -- zig run -O ReleaseFast src/qa023_probe.zig -- census-3x2`
  at commit `HEAD`, 2026-07-30, V=2,586, 0.3 s, peak RSS ~0 MB
- Agent: DSPro/F1-CENSUS-GAP, 2026-07-30
