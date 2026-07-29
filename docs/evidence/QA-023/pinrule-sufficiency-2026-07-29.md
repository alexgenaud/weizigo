Task: PINRULE-SUFFICIENCY · Role: worker · Model: Kimi-k3 (kimi-k3) · Date: 2026-07-29
Set: T · Holds: src/qa023_pinrule.zig (NEW file, sole writer)
Status: IN PROGRESS — interim state checkpoint (written at context-pressure
warning; final numbers pending the full `pinrule-eval` run). No claim status
changed; proposals only.

# PINRULE-SUFFICIENCY — interim evidence

## HEADLINE 1 (premise defect, must adjudicate before anything else): the C2
"falsification" is an artefact of an inverted update guard in the 3x2
`fixpoint_kernel` of `src/qa023_probe.zig`

At HEAD 8b610ee, `fixpoint_kernel` (src/qa023_probe.zig:880-1070):

- L sweep (seed −6, ascending): Black updates when `best > L_tab[li]`
  (correct); **White updates when `best < L_tab[li]` (never fires — seeded at
  the −6 floor)** (lines ~947-961).
- H sweep (seed +6, descending): Black updates when `best < H_tab[hi]`
  (correct); **White updates when `best > H_tab[hi]` (never fires)** (lines
  ~1006-1020).

Consequence: **every White-to-move non-terminal state keeps the seed values
L=−6, H=+6** ⇒ `median(L,TIE,H)` = 0 on all of them. Verified mechanically:
878/878 White-to-move reachable non-terminals are pinned at (−6,+6)
(`pinrule-census` output). The correct pattern sits in the same codebase
twice: `src/retro.zig` (EXP-11-verified: one side-keyed operator, seeds ±N,
monotone both ways) and `smoke_fixpoint_2x2` (unconditional monotone
Gauss-Seidel).

The seven hand-adjudicated C2 "counterexample" states (586/534/302/146/103/
674/566, all White-to-move, passes=1, no ko) are each **forced-single-
successor states** (only legal move = pass to their own terminal), so the
Bellman operator forces L==H==area_score at each (+1,+1,+1,+1,+3,−6,−6 =
exactly the hand-verified truncated values). Diagnostic:
`pinrule-diag6` — as-shipped (−6,+6)/median 0 vs corrected
(+1,+1)/median +1 etc., 7/7 with legal_succs=1.

Published-data symptom, visible without any code: pin census pin_L=142 vs
pin_H=0. Colour inversion of the (inversion-symmetric) reach set REQUIRES
L(−S)==−H(S) ⇒ pin_L==pin_H for any correct tables. My corrected kernel:
pin_L==pin_H==34, inversion violations 0.

Validations (`pinrule-census`, all reproduced in stdout):
- V0 fidelity: my bug-compatible port reproduces the published pin census
  EXACTLY (948/1532/142/0 all-states; 82/1532/142/0 non-terminal).
- V1 Bellman residual (states with table ≠ Φ(table)): as-shipped
  L-residual=58, H-residual=453; corrected 0/0.
- V2 inversion violations: as-shipped 453; corrected 0.
- V3 controls: corrected L==H==hand value on 7/7 adjudicated states.

Implication (PROPOSED, needs an independent seat per verify-then-promote):
`QA-026`/`QA-013` falsification rests on garbage (L,H) inputs, not on the
median rule. The real state of C2 is UNKNOWN until re-measured with a
correct fixpoint. The current experiment does exactly that.

## HEADLINE 2: corrected (L,H) group structure at 3x2 (the actual task input)

Corrected-table groups over the 1756 reachable non-terminal states:
24 non-empty (L,H) groups, ALL of size ≥ 2 (no singletons). Distribution
perfectly inversion-symmetric (pairs (L,H)↔(−H,−L) have equal sizes):

```
GROUP L=-6 H=-6 size=619   GROUP L=6 H=6 size=619
GROUP L=-6 H=6  size=216   (self-symmetric)
GROUP L=-6 H=-3 size=6     GROUP L=3 H=6 size=6
GROUP L=-6 H=-2 size=6     GROUP L=2 H=6 size=6
GROUP L=-6 H=-1 size=22    GROUP L=1 H=6 size=22
GROUP L=-6 H=0  size=21    GROUP L=0 H=6 size=21
GROUP L=-6 H=1  size=14    GROUP L=-1 H=6 size=14
GROUP L=-6 H=2  size=10    GROUP L=-2 H=6 size=10
GROUP L=-6 H=3  size=8     GROUP L=-3 H=6 size=8
GROUP L=-3 H=-3 size=20    GROUP L=3 H=3 size=20
GROUP L=-2 H=-2 size=8     GROUP L=2 H=2 size=8
GROUP L=-1 H=-1 size=20    GROUP L=1 H=1 size=20
GROUP L=0 H=0   size=32    (self-symmetric)
```

Per-group within-budget truncation values: PENDING (see below).

## HEADLINE 3 (instrument dispute, being adjudicated): alpha-beta (T3) vs
plain minimax (T2) diverge wildly on expensive states

At (178,0,6,0) board [B W B . W .], Black to move, (corrected L,H)=(−6,−6):
- dfs1 arrival (23 states visited): T2/T1 EXHAUST 500,000,000 nodes;
  T3 (alpha-beta) returns −3 in **22 nodes**.
- dfs2 arrival (25 states): T2/T1 exhaust 500M; T3 returns −6 in 33 nodes.

A 22-node alpha-beta "proof" of a >5·10^8-node tree violates the ~√N
best-case intuition; T3 (or T2) is defective OR something subtle. The
putative "C1 witness" (same state, two genuine arrivals, two values) rests
on T3 alone and is NOT yet trustworthy. Adjudication in flight:
`/tmp/pinrule_check.py` — an independent Python reimplementation (rules +
both evaluators) replaying the printed arrival move lists, cross-checked
against the Zig tiers. NOT YET RUN at checkpoint time.

Evaluator battery so far (pinrule-battery --sample 64 --node-budget 200000):
seven controls with BFS-short arrivals: T1==T2==T3==hand-verified values
(+1,+1,+1,+1,+3,−6,−6, ≤2 nodes each: forced successors); 64 random states:
0 tier disagreements, 63/70 partial (some tier exhausted), 7 full-agree.

## Runbook / state

- Build: `tools/runner -- zig build-exe src/qa023_pinrule.zig -femit-bin=/tmp/pinrule -Doptimize=ReleaseFast`
- Modes: `pinrule-census` (V0..V3 + groups) · `pinrule-diag6` ·
  `pinrule-battery [--sample N --node-budget N]` ·
  `pinrule-eval [--max-states N --node-budget N --k-long K --cross-every K]`
  · `pinrule-state <b> <s> <k> <p> [--node-budget N --k-long K]`
- 120-state dry run of pinrule-eval: 294 evals, 81 within budget (72%
  exhaustion at 5M budget), 0 cross-tier disagreements on cheap states,
  putative witness group (−6,−6) with values {−6,−3,0} — SUSPECT pending
  the T3/T2 adjudication above.
- Evaluator tiers in src/qa023_pinrule.zig: T1 = probe-exact port (linear
  scans), T2 = bitset plain minimax, T3 = bitset alpha-beta (primary,
  currently suspect).
- Arrival validity checker wired into eval loop (ARRIVAL-BAD counter, 0 so
  far in dry runs).

## Next steps (in order)

1. Run /tmp/pinrule_check.py on the (178,0,6,0) arrivals; find the T3/T2
   defect; fix or discard T3. Do NOT trust any T3-only value until then.
2. Re-run the full pinrule-eval with the corrected evaluator; per-group
   testable denominators; yes/no witness verdict with coverage.
3. Write final deliverable + PROVENANCE; `managent done`.

## Files

- src/qa023_pinrule.zig — the instrument (this task's sole src write).
- docs/evidence/QA-023/pinrule-sufficiency-2026-07-29.md — this document.
- /tmp/pinrule_check.py — independent Python verifier (NOT in git; promote
  into evidence dir before done).
