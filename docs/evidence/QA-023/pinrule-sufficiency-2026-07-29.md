Task: PINRULE-SUFFICIENCY · Role: worker · Model: Kimi-k3 (kimi-k3) · Date: 2026-07-29
Set: T · Holds: src/qa023_pinrule.zig (NEW file, sole writer; src/qa023_probe.zig untouched)
Status: COMPLETE. No claim status changed; proposals only (§7).

# PINRULE-SUFFICIENCY — can ANY pointwise function of (L, TIE, H) be correct?

**Answer: NO for history-conditioned semantics — the obstruction exists and is
hand-verified. Three (L,H) groups contain multiple within-budget truncation
values; seven states are C1 witnesses (same state, two genuine arrivals, two
values).** And a second, independent headline: **the premise of the task was
broken** — the C2 "falsification" it cites is an artefact of an inverted
update guard in the probe's 3x2 `fixpoint_kernel`, which pins L=−6, H=+6 on
EVERY White-to-move non-terminal state. With a corrected fixpoint, the
median rule agrees with every within-budget *shortest-arrival* value
(396/396): the fixpoint+median is the fresh-start value function on all
within-budget evidence, and the obstruction lives entirely in genuine
(long) arrival histories.

## 1. Premise defect: the probe's 3x2 fixpoint never updates White nodes

At HEAD 8b610ee, `fixpoint_kernel` (src/qa023_probe.zig:880-1070), L sweep
(seeded −6, ascending): Black updates when `best > L_tab[li]` (correct);
**White updates when `best < L_tab[li]` — impossible from the −6 floor.**
H sweep (seeded +6, descending): Black `best < H_tab[hi]` (correct);
**White `best > H_tab[hi]` — impossible from the +6 ceiling.** Consequence:
L=−6, H=+6 at every White-to-move non-terminal ⇒ median pins TIE=0 on all
of them. The correct pattern exists twice in the same codebase
(`src/retro.zig`, EXP-11-verified; `smoke_fixpoint_2x2`, monotone
Gauss-Seidel assignment). The 3x2 kernel has no unit test (the suite's
anchors cover the 2x2 smoke tables and rank/area helpers only).

Mechanical confirmations (`pinrule-census`):

- **V0 fidelity**: my bug-compatible port reproduces the published pin
  census EXACTLY (948/1532/142/0 all-states; 82/1532/142/0 non-terminal) —
  the port is faithful, the published numbers are the buggy ones.
- White-to-move non-terminals pinned at seed: **878/878**.
- **V1 Bellman residual** (states with table ≠ Φ(table)): as-shipped
  L-residual=58, H-residual=453; corrected 0/0. The as-shipped tables are
  not even a fixpoint of the Bellman operator.
- **V2 colour inversion** (L(−S)==−H(S) required by symmetry):
  as-shipped 453 violations; corrected 0. The published pin_L=142 vs
  pin_H=0 asymmetry was already impossible for a correct pair.
- **V3 controls**: the seven hand-adjudicated C2 "counterexample" states
  (586/534/302/146/103/674/566) are each **forced-single-successor** states
  (only legal move = pass to their own terminal, `pinrule-diag6`), so the
  Bellman operator forces L==H==area_score at each. Corrected kernel:
  L==H==hand-verified value on 7/7 (+1,+1,+1,+1,+3,−6,−6).

**Proposed consequence** (needs an independent seat per verify-then-promote):
the QA-026/QA-013 falsification and the `2B-6`-confirmed adjudication rest
on garbage (L,H) inputs, not on the median rule. C2's real status is
decided by §4 below, not by the old evidence.

## 2. Corrected (L,H) group structure (the task's step 2)

Corrected kernel (monotone Gauss-Seidel, seeds ∓6, Black max / White min in
both, converged in 10 sweeps, residuals 0, inversion-symmetric). Over the
1756 reachable non-terminal states: **24 non-empty (L,H) groups, ALL of
size ≥ 2** (no singletons). Distribution exactly inversion-symmetric
((L,H)↔(−H,−L) equal sizes — an extra consistency check on the kernel):

```
(L=-6,H=-6) 619   (L=6,H=6) 619   (L=-6,H=6) 216   (L=0,H=0) 32
(L=-6,H=-1) 22    (L=1,H=6) 22    (L=-6,H=0) 21    (L=0,H=6) 21
(L=-3,H=-3) 20    (L=3,H=3) 20    (L=-1,H=-1) 20   (L=1,H=1) 20
(L=-6,H=1) 14     (L=-1,H=6) 14   (L=-6,H=2) 10    (L=-2,H=6) 10
(L=-6,H=3) 8      (L=-3,H=6) 8    (L=-2,H=-2) 8    (L=2,H=2) 8
(L=-6,H=-3) 6     (L=3,H=6) 6     (L=-6,H=-2) 6    (L=2,H=6) 6
```

(The as-shipped tables instead produce a degenerate giant group: 878 White
states at (−6,+6) plus 878 more — a grouping that would make any pin-rule
question vacuous. Reported for comparison only.)

## 3. The experiment (step 3): arrivals, evaluators, calibration

- Arrivals per state: **h0 = BFS-shortest** from the empty-board root (the
  class the probe's DFS generator systematically misses — 2B-3-AUDIT) +
  **h1,h2 = randomized DFS simple paths, depth 24** (probe-equivalent
  generator). Every arrival validated: root-anchored, consecutive states
  one legal move apart, simple path, ends at σ (**ARRIVAL-BAD = 0**).
- Evaluators (post-fix semantics: arrival exclusive of σ; TIE on revisit of
  arrival-or-path; area_score at passes==2; budget-null; scratch separate):
  T1 probe-exact port (linear scans) · T2 bitset plain minimax ·
  T3 bitset alpha-beta (primary). Calibration: seven controls
  T1==T2==T3==hand values; 64-state battery, 0 tier disagreements;
  79 T3-vs-T2 cross-checks in the main run, **0 disagreements**.
- The T3/T2 divergence at expensive states was adjudicated before any
  witness was believed: an independent Python reimplementation
  (`pinrule-sufficiency-verifier.py`) reproduces T3 exactly, and the
  flagship 22-node tree was dumped and **hand-verified leaf by leaf**
  (§5). T2's exhaustion is the honest exponential cost; T3's cutoffs are
  legitimate.

Run: `pinrule-eval --node-budget 5000000 --k-long 2 --cross-every 5`
(10m16s, 13.17 G nodes). Full stdout:
`pinrule-sufficiency-2026-07-29.stdout` (5,266 EVAL lines).

## 4. Findings (step 4): YES, obstruction — and a fresh-start surprise

**3,486 evaluations; 855 within budget (75.5% exhaustion — the honest
exponential cost, cf. the probe's 93% at 100k); 470/1756 states with ≥1
value; 10/24 groups testable (≥2 valued states).**

### 4a. The obstruction (history-conditioned semantics)

- **7 C1 witnesses** (same state, two genuine arrivals, two values):
  (178,0,6,0): −3 vs −6 · (511,1,6,1): −6 vs −3 · (146,0,6,0): 6 vs 3 ·
  (93,1,6,0): 6 vs 3 · (146,1,6,0): 6 vs 1 · (146,0,6,1): 6 vs 3 ·
  (380,0,6,1): 6 vs 3.
- **3 witness groups** (distinct within-budget values inside one (L,H)
  group): **(−6,−6): {−6,−3,0}** · **(+3,+3): {0,+3}** ·
  **(+6,+6): {0,+1,+2,+3,+6}**. The L==H groups are hit too — this is
  stronger than a pin-rule failure: on these states the *whole fixpoint
  value* fails to equal the history-conditioned value.
- **Witness in full** (brief's "smallest witness pair"): §5, the
  (178,0,6,0) same-state pair, hand-traced.

### 4b. The fresh-start surprise (BFS-shortest arrivals only)

Restricting to shortest-arrival values: **396/396 within-budget values
equal median(L,TIE,H) with the corrected tables — zero disagreements.**
Every one of the 9 groups with ≥2 shortest-arrival values is single-valued
and equal to the pin (−6,−3,−2,−1,0,+1,+2,+3,+6 groups). Every C1
witness's *shortest* arrival agrees with the fixpoint; the deviation
appears only on long histories (longer arrival ⇒ larger banned visit set
⇒ more TIE truncation ⇒ different game). Mechanism, visible in the §5
trace: the arrival's visit set turns losing lines into TIE=0 escapes.

**Interpretation (proposed):** the corrected fixpoint+median is the
fresh-start value function (consistent with Theorem 6.1 for the root's own
game), while the history-conditioned rule (ADR-0019's Option A:
first-revisit truncation against the actual arrival) is genuinely
history-dependent at 3×2 — the T13 pattern reappearing under basic ko. The
(board, side, ko, passes) tuple is NOT a sufficient Markovian state for the
history-conditioned rule; the value is not a function of the tuple at all,
so no pointwise function of (L,TIE,H) — itself a function of the tuple —
can compute it.

## 5. The witness, hand-verified end-to-end

State (178,0,6,0) = `[B W B . W .]`, Black to move, no ko, passes=0;
corrected (L,H)=(−6,−6); root has ONE legal move (pass; B@3 and B@5 are
suicide on the 3×2 ladder — cell 3 does not connect stones 0 and 2).

- Arrival A (dfs1, 23 states): `B2 W3 B1 W4 B5 pass B0 pass B3 W4 pass W5
  B0 W3 pass W1 pass W2 B0 W1 B2 W4` → **value −3** (22 nodes).
- Arrival B (dfs2, 25 states): `B3 W1 pass W5 pass W4 pass W0 pass W3 B2
  W3 B5 pass B0 W4 B1 pass B3 W4 B0 pass B2 W1` → **value −6** (33 nodes).

The full 22-node tree was dumped from the independent Python verifier and
checked leaf by leaf. Pivotal node #10 `[W W . W W W]`-Black: the capture
B@2 leads to `[. . B . . .]`-White-passes-0 — **which is arrival A's own
first state (move 1: B2)** — truncated to TIE=0, making node #10 worth 0
and the root −3. Arrival B does not contain that state; the same node is
worth −6 and the root −6 (matching the fixpoint). Every other leaf checks
out (terminal area scores recomputed by hand; TIE leaves cross-checked
against the validated arrival; the two cutoffs are legal alpha-beta
cutoffs: pass=+6 ≥ −3 at a max node, and value ≤ α at min nodes).
Two independent implementations (Zig T3, Python alphabeta) agree on value
and node count; window probes ((−4,127)→−3 exact, (−2,127)→−3 as
fail-soft bound) are consistent.

## 6. Wrong-answer pass rate of this check (acceptance item)

- **A still-broken evaluator** (σ-in-arrival defect: returns TIE=0 on every
  evaluation) would report distinct={0} in every testable group → "no
  witness", 100% pass-through, WRONG. Caught here by (i) the seven-control
  positive control (must return +1,+1,+1,+1,+3,−6,−6), and (ii) the
  BFS-vs-median table (broken evaluator: 396/396 DISagree instead of
  agree).
- **A vacuous sample** (everything exhausted) prints VERDICT: INCONCLUSIVE
  with testable=0 — cannot masquerade as NO; denominators are in §4.
- **The as-shipped fixpoint** would have produced the degenerate grouping
  and an artifact "witness" (the (−6,+6) pool trivially contains every
  value); V0..V3 catches and quantifies it instead.
- **A shortest-arrival-only reading** would answer "no obstruction" — true
  ONLY for fresh-start semantics; §4a/§4b report both cuts so the two
  answers cannot be conflated.
- Shared-author risk on the evaluators: mitigated by the third, differently
  shaped implementation (Python) and the hand-traced tree; residual risk
  on states believed without T2/Python overlap is recorded as the 79/0
  cross-check coverage.

## 7. Proposed claim-status inputs (owner: CLAIMS.md seat; I propose only)

- `3x2.QA023.B-PROBE-C1`: **FALSIFIED at 3×2** for genuine (non-shortest)
  histories — 7 witnesses, one hand-traced (§5). Previously
  UNTESTED-FOR-WANT-OF-CONTRAST; the contrast (BFS-short vs DFS-long) is
  exactly where it fails, as 2B-3-AUDIT predicted.
- `QA-023` (representation sufficiency): the tuple is not sufficient for
  the history-conditioned rule (Option A). **FALSIFIED at 3×2** proposed.
- `QA-026` / `QA-013` (`median(L,T,H)`): the old falsification is
  invalidated (premise defect, §1); with the corrected fixpoint the rule
  matches 396/396 shortest-arrival values → **fresh-start-consistent at
  3×2** (CLAIMED, not proven; coverage 396/1756 states, 9/24 groups).
- `GLOBAL.F2-REMEDY`: the pin rule is repairable ONLY for fresh-start
  semantics; for the history-conditioned rule no pointwise repair exists —
  the design needs bounded-history state or a ruleset decision (the
  ADR-0019 fork, now with numbers).
- The `fixpoint_kernel` defect itself: file as a finding against
  `src/qa023_probe.zig` (owner: F1-SEEDROOTS currently holds the file).

## 8. What could not be established

- 75.5% of evaluations exhausted: the witness census is a LOWER bound on
  the obstruction's extent. 14/24 groups had <2 valued states.
- Whether shortest-arrival values coincide with the fixpoint on the
  remaining 1,360 states (only 396 within budget).
- Whether even SHORTER/"canonical" histories (or empty-arrival root games)
  deviate anywhere — no deviation found, but 396/1756 coverage.
- 4x4: per-board epistemic independence — nothing here transfers.

## 9. Files

- `src/qa023_pinrule.zig` — instrument (new; sole writer).
- `docs/evidence/QA-023/pinrule-sufficiency-2026-07-29.md` — this file.
- `docs/evidence/QA-023/pinrule-sufficiency-2026-07-29.stdout` — full run.
- `docs/evidence/QA-023/pinrule-sufficiency-verifier.py` — independent
  Python verifier (rules + minimax + alpha-beta + trace dump).
- `docs/evidence/QA-023/PROVENANCE-pinrule-sufficiency-2026-07-29.md`.
