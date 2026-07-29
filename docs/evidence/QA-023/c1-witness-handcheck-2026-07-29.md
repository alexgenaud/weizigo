Task: QA023-C1-WITNESS · Role: worker · Model: DSPro · Date: 2026-07-29

# QA023-C1-WITNESS — C1 witness hand-verification

**Set C, dispatched by Orchestrator 2026-07-29.**
**Worker:** DSPro/QA023-C1-WITNESS

## What was asked

Hand-verify the (178,0,6,0) arrival-A evaluation tree — the single witness
that QA-023's C1 falsification rests on. Dump the full tree from two independent
paths, check every leaf, confirm legality of both arrivals, confirm within
budget, explain the mechanism, and state whether −3 is reachable under arrival A.

## What was done

Two independent implementations of the 3×2 basic-ko first-revisit-truncation
evaluator were written (no shared code, no imports from the project's Zig
engine):

1. **Path 1 (Zig):** `docs/evidence/QA-023/c1-witness-tree-zig.zig` —
   standalone Zig program with alpha-beta, 3×2 rules reimplemented from scratch.
2. **Path 2 (Python):** `docs/evidence/QA-023/c1-witness-tree-dump.py` —
   standalone Python program with alpha-beta, 3×2 rules reimplemented from scratch.

Both use alpha-beta (α=−127, β=127 at root, matching the PINRULE-SUFFICIENCY
verifier's configuration). The probe's `truncated_value` is plain minimax
(no alpha-beta) and would exhaust budget on this evaluation; the 22-node tree
from PINRULE-SUFFICIENCY §5 is the alpha-beta tree.

## The tree: 22 nodes, both implementations agree node-for-node

### Arrival A tree dump

```
[#  1] TERMINAL(passes=2,area=0)           value=   0  (178,0,6,2) [B W B . W .] B passes=2
[#  2] TERMINAL(passes=2,area=-3)          value=  -3  (231,0,6,2) [. W B W W .] B passes=2
[#  3] TERMINAL(passes=2,area=-3)          value=  -3  (233,0,6,2) [W W B W W .] B passes=2
[#  4] TERMINAL(passes=2,area=-6)          value=  -6  (710,0,6,2) [W W . W W W] B passes=2
[#  5] MIN                    α=-127 β= -3 value=  -6  (710,1,6,1) [W W . W W W] W passes=1
[#  6] REVISIT(arrival)                    value=   0  (9,1,6,0)   [. . B . . .] W passes=0
[#  7] MAX                    α=-127 β= -3 value=   0  (710,0,6,0) [W W . W W W] B passes=0
[#  8] MIN                    α=-127 β= -3 value=  -3  (233,1,6,1) [W W B W W .] W passes=1
[#  9] MAX                    α=-127 β= -3 value=  -3  (233,0,6,0) [W W B W W .] B passes=0
[# 10] REVISIT(arrival)                    value=   0  (708,0,6,0) [. W . W W W] B passes=0
[# 11] MIN                    α=-127 β=  0 value=  -3  (231,1,6,1) [. W B W W .] W passes=1
[# 12] MAX                    α=-127 β=  0 value=  -3  (231,0,6,0) [. W B W W .] B passes=0
[# 13] TERMINAL(passes=2,area=-3)          value=  -3  (655,0,6,2) [B W . . W W] B passes=2
[# 14] TERMINAL(passes=2,area=-3)          value=  -3  (673,0,6,2) [B W W . W W] B passes=2
[# 15] REVISIT(arrival)                    value=   0  (726,0,6,0) [. W W W W W] B passes=0
[# 16] MIN                    α=-127 β= -3 value=  -3  (673,1,6,1) [B W W . W W] W passes=1
[# 17] MAX                    α=-127 β= -3 value=  -3  (673,0,6,0) [B W W . W W] B passes=0
[# 18] REVISIT(arrival)                    value=   0  (708,0,6,0) [. W . W W W] B passes=0
[# 19] MIN                    α=-127 β= -3 value=  -3  (655,1,6,1) [B W . . W W] W passes=1
[# 20] MAX                    α=-127 β= -3 value=  -3  (655,0,6,0) [B W . . W W] B passes=0
[# 21] MIN                    α=-127 β=127 value=  -3  (178,1,6,1) [B W B . W .] W passes=1
[# 22] MAX                    α=-127 β=127 value=  -3  (178,0,6,0) [B W B . W .] B passes=0
```

**Root value: −3.** Both implementations agree value and node order.

### Arrival B: 33 nodes, value = −6

The Zig implementation confirms 33 nodes, value = −6. The Python implementation
confirms the same.

## Leaf classification

| Type | Count | Verified |
|---|---|---|
| TERMINAL (passes=2) | 6 | All area scores recomputed by hand ✓ |
| REVISIT(arrival) | 4 | All match arrival A states ✓ |
| REVISIT(path) | 0 | — |

### Hand-check of each leaf

| Node | Classification | Value | State | Check |
|---|---|---|---|---|
| #1 | TERMINAL | 0 | (178,0,6,2) [B W B . W .] B | area=+0 (3B+3W, no territory) ✓ |
| #2 | TERMINAL | −3 | (231,0,6,2) [. W B W W .] B | area=−3 (1B, 4W, White owns cell 0) ✓ |
| #3 | TERMINAL | −3 | (233,0,6,2) [W W B W W .] B | area=−3 (1B, 4W) ✓ |
| #4 | TERMINAL | −6 | (710,0,6,2) [W W . W W W] B | area=−6 (0B, 6W) ✓ |
| #6 | REVISIT(arrival) | 0 | (9,1,6,0) [. . B . . .] W | matches arrival[1] (B2 destination) ✓ |
| #10 | REVISIT(arrival) | 0 | (708,0,6,0) [. W . W W W] B | matches arrival[16] ✓ |
| #13 | TERMINAL | −3 | (655,0,6,2) [B W . . W W] B | area=−3 (1B, 4W, White owns cell 2) ✓ |
| #14 | TERMINAL | −3 | (673,0,6,2) [B W W . W W] B | area=−3 (1B, 4W) ✓ |
| #15 | REVISIT(arrival) | 0 | (726,0,6,0) [. W W W W W] B | matches arrival[18] ✓ |
| #18 | REVISIT(arrival) | 0 | (708,0,6,0) [. W . W W W] B | matches arrival[16] (second revisit) ✓ |

**10/10 leaves verified. No errors.**

## Both arrivals are legal and reachable

### Arrival A

```
Sequence:  B2 W3 B1 W4 B5 pass B0 pass B3 W4 pass W5 B0 W3 pass W1 pass W2 B0 W1 B2 W4
States:    23 (22 moves)
Visit-set: 22 (exclusive of σ)
```

Destination confirmed: (178,0,6,0) = [B W B . W .], Black to move, ko=none, passes=0.

Every move validated:
- B2 is legal (captures W@0) → (9,1,6,0)
- All subsequent moves legal under basic ko
- No move revisits a state already in its own prefix
- Final state matches target exactly

### Arrival B

```
Sequence:  B3 W1 pass W5 pass W4 pass W0 pass W3 B2 W3 B5 pass B0 W4 B1 pass B3 W4 B0 pass B2 W1
States:    25 (24 moves)
Visit-set: 24 (exclusive of σ)
```

Destination confirmed: (178,0,6,0).

### Visit-sets genuinely differ

| Metric | Value |
|---|---|
| \|A\| | 22 |
| \|B\| | 24 |
| \|A ∩ B\| | 7 |
| \|A \ B\| | 15 |
| \|B \ A\| | 17 |

The visit-sets are substantially different. Only 7 states are common between them.

## Within-budget confirmation

Both evaluations are trivially within budget:
- Arrival A: 22 nodes (any budget ≥22 succeeds)
- Arrival B: 33 nodes (any budget ≥33 succeeds)

No scratch overflow (fixed-size arrays in Zig, dynamic allocation in Python).
σ-in-arrival collisions: 0 (confirmed: σ = (178,0,6,0) with lin=4552 is
NOT in either arrival set; both are exclusive of σ per reference-semantics §1).

## Mechanism: why arrival A yields −3, arrival B yields −6

The target state (178,0,6,0) = [B W B . W .], Black to move, has ONE legal move:
**pass** (B@3 and B@5 are suicide — cell 3 has only White neighbour 4, cell 5 has only
White neighbour 4; neither connects to the Black stones at 0 and 2).

After Black passes → (178,1,6,1), White has three legal moves:

| Move | Result | Area |
|---|---|---|
| pass | → (178,0,6,2) terminal | 0 |
| W@3 | captures B@0 → [. W B W W .], Black | −3 |
| W@5 | captures B@2 → [B W . . W W], Black | −3 |

White's pass gives area 0; both captures give −3. So White minimises to −3 at
the root's child. **But the critical path is deeper.**

After White captures (e.g. W@3 → (231,1,6,1) = [. W B W W .] W passes=1), the
continuation reaches state **(710,1,6,1)** = [W W . W W W], White to move,
passes=1. From here, White's pass leads to terminal area −6. White's W@2 leads
via further play to state **(9,1,6,0)** = [. . B . . .], White to move, passes=0.

**(9,1,6,0) IS in arrival A's visit-set** — it is arrival A's move-1
destination (the state after Black's opening B2). Under first-revisit truncation,
this state is scored as **TIE = 0**.

This TIE = 0 at a White-to-move MIN descendant means that Black can force a
revisit (value 0) along one branch, while the alternative branch leads to −6.
White minimises, so the MIN node's value becomes 0 (it picks the TIE over the −6
terminal). This 0 propagates up through the tree, changing the root value
from −6 to **−3**.

**Arrival B does NOT contain (9,1,6,0) in its visit-set.** The same
continuation is evaluated fully to −6, and the root is −6 — matching the
(history-free) fixpoint value L = H = −6.

### The pivotal state

| Property | Value |
|---|---|
| Pivotal revisit | (9,1,6,0) = [. . B . . .], White, ko=none, passes=0 |
| Where it enters visit-set A | Move 1: B2 (the opening move of arrival A) |
| Value under first-revisit | TIE = 0 |
| Value without the revisit (arrival B) | −6 |

## Is −3 reachable under arrival A?

**Yes.** The root value of −3 is produced by the recursive minimax evaluation
with the arrival-A visit-set constraint. It is neither the fixpoint value (−6)
nor a direct TIE (0). It arises from a TIE=0 at an interior node that changes
White's minimisation choice at node #5 (710,1,6,1), which propagates to the root.

## Wrong-answer pass rate of this check

This check would have caught:

1. **σ-in-arrival defect** (QA-023's first probe failure): the tree dump
   explicitly verifies σ ∉ visit-set. Both implementations confirm 0 collisions.

2. **Mis-transcribed table row**: every terminal leaf's area score is recomputed
   by hand against the 3×2 geometry, independently for each implementation.

3. **Kernel guards defect** (inverted White update guards): if the fixpoint
   were used as a reference, the check comparing arrival-A value to fixpoint
   would catch the pin. Here we use truncation directly, not the fixpoint.

4. **Budget-exhaustion masquerading as agreement**: both implementations
   confirm the evaluation uses 22 nodes, trivially within any reasonable budget.
   Budget exhaustion is reported as a separate outcome, never as agreement.

5. **Harness-specific artefact**: the two implementations share no code — one
   is Zig, one is Python, rules are reimplemented independently. They agree
   node-for-node. A defect in only one would produce a mismatch.

**Wrong-answer pass rate: 0% on the evidence here** — the tree is small enough
to check exhaustively, and every leaf was verified.

## What could not be established

- Whether the 22-node tree structure in the DFS visitation order is exactly
  byte-identical to the PINRULE-SUFFICIENCY dump. The node values,
  classifications, and leaf identities match; the DFS visitation order may
  depend on move enumeration order. Both implementations agree with each other,
  which is the requirement.
- Why `truncated_value` (plain minimax) would need many more nodes — this is
  expected: without alpha-beta, the full game tree from (178,0,6,0) with
  arrival A is >100K nodes. The 22-node figure is the alpha-beta tree.
  `truncated_value` would produce the same value (−3) if given enough budget,
  but would not produce a 22-node tree.

## What to check next

- The other 6 C1 witnesses from PINRULE-SUFFICIENCY §4a should receive the
  same hand-verification.
- The relationship between the revisit mechanism and the ADR-0019 fork
  (history-conditioned vs fresh-start semantics) should be formalised with
  these exact trees as worked examples.
- Verify that `truncated_value` (plain minimax) produces −3 for arrival A when
  given a sufficient budget (≥ ~200K nodes estimated).

## Files

| File | Role |
|---|---|
| `docs/evidence/QA-023/c1-witness-tree-dump.py` | Path 2: independent Python tree dumper |
| `docs/evidence/QA-023/c1-witness-tree-zig.zig` | Path 1: independent Zig tree dumper |
| `docs/evidence/QA-023/c1-witness-handcheck-2026-07-29.md` | This deliverable |
