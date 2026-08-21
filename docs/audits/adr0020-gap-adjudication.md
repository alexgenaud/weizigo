# ADR-0020 gap adjudication — the 716 L≠H gaps: check or solver?

**Task: T287 · Role: Auditor · Model: deepseek-v4-pro · Date: 2026-08-03**
**Verdict: The check is wrong. The solver is fine. L≠H is semantically expected under ADR-0020.**

## 1. What was measured

The pass0 matrix (`docs/evidence/GLOBAL.DIFFERENTIAL/matrix-2x2-2026-08-01.md`)
reported:

> reachable states: 2430 total · reachable non-terminals: 1620 · L≠H gaps: 716 · first gap witnesses: idx=0 L=−4 H=4

This was interpreted as an escalation (44% bracket rate) and filed
against a standing agreement fixture that measured gap=0 on 172 states.
`accept.md:64` recorded it and the human escalated it to
`untracked/T287-auditor-716-gap.md`.

## 2. What "716 L≠H gaps" actually means

The 716 counts states where L < H **within the fixpoint itself** — not
disagreement between fixpoint and truncation. The matrix was populated from
the QA-023 state encoding (81 positions × 2 sides × 5 ko values × 3 pass
values = 2,430 allocation slots, 1,620 non-terminal), computing the least
and greatest fixpoints of the Bellman operator under the corrected basic-ko
rule.

The independent Python implementation that produced this number
(`docs/evidence/QA-023/ko-fix-2026-07-29/fix2x2.py`) was re-run during this
audit. Reproduced bit-identically: **716 L<H states, 0 Bellman violations, 0
L>H violations, convergence in 4 (L) / 5 (H) sweeps.** The fixpoint is
genuine.

## 3. The check is wrong

Under ADR-0020's loopy-game fixpoint semantics, L<H is **expected**. Axiom
E3 (`docs/epics/E1-markovian/AXIOMS.md` §2):

> E3 — Bracket semantics: Where L(s) < H(s) the state is bracket-valued:
> the value depends on information not in the state (history beyond k=1).
> The bracket [L(s), H(s)] is the range of possible values consistent with
> the state alone.

Asking for "L==H everywhere" asks the solver to contradict its own
semantics. The bracket IS the deliverable. A pass condition of "gap=0 on
all reachable non-terminals" is unsound — it demands single-valuedness
where E3 explicitly allows brackets.

**What the spec actually asked for.** The pass0 spec AC-S6 asks for
**fixpoint-vs-truncation agreement** on the 24-fixture states — not L==H
within the fixpoint:

> ADR-0020 truncation-agreement verified: the 24-state standing agreement
> fixture produces gap = 0 (all 172 reachable non-terminals at 2×2 agree
> between loopy-game fixpoint and first-revisit truncation values).

That check passes (T102/T103, re-verified in this audit: 258 reachable
states, 172 non-terminal, 24/24 fixpoint-vs-truncation agreement). The
matrix measured a different thing (L≠H within the fixpoint) and reported it
as an escalation.

## 4. The solver is fine

### 4.1 Bellman consistency — 0 violations

Every non-terminal state in the Python fixpoint satisfies the Bellman equation.
Traced one complete evaluation end-to-end for the first gap witness (state
index 0: empty board, Black, ko=0, passes=0, L=−4, H=4):

| child state | L | H |
|---|---|---|
| (empty, White, ko=none, passes=1) | −4 | 0 |
| (board 3, White, ko=none, passes=0) | −4 | 4 |
| (board 9, White, ko=none, passes=0) | −4 | 4 |
| (board 27, White, ko=none, passes=0) | −4 | 4 |

L = max(children L) = −4 ✓ · H = max(children H) = 4 ✓

Extended scan: all 1,620 non-terminal states verified L = Φ(L) and H = Φ(H)
with zero violations.

### 4.2 Zig retrograde solver — consistent

The production solver (`src/retro.zig`) uses a different state encoding
(position-indexed, 81 slots) but produces consistent results:

- Test `"2x2 retrograde: converges, L <= H, fixpoints swap under colour
  inversion"` — PASSES (`zig test src/retro.zig --test-filter "2x2 retrograde:
  converges"`)
- Test `"2x2 bracket-guided finisher completes the whole ko-sensitive region
  (ADR-0010)"` — PASSES (0 budget-skipped, 0 bracket-fail)

Zig counts for 2×2: 57 legal positions, 4 settled, 53 non-terminal. V0:
L==H at 12 positions, L<H at 41 positions per side. V1: L==H at 20
positions, L<H at 33 positions per side. ko_sensitive: 41 per side.

### 4.3 Colour inversion and dihedral symmetry — 0 violations

The Zig solver's `checkSymmetry` returns zero failures on all three axes
(LH inversion, dihedral, flag consistency), verified by the test at line
4575.

### 4.4 Convergence — stable and fast

L converges in 2 sweeps (Zig), 4 sweeps (Python). H converges in 2 sweeps
(Zig), 5 sweeps (Python). The difference is due to different state encodings
and seeding strategies, not a defect — the Zig solver's Gauss-Seidel
(stone-count descending) converges faster than the Python's Jacobi-style
sweep.

## 5. The 24-state fixture explained

The 24-fixture (T102/T103) measured **fixpoint-vs-truncation agreement**, not
L==H within the fixpoint. It tests whether the loopy-game fixpoint and the
first-revisit truncation evaluator return the same value on the same states —
a cross-semantics consistency check.

Why the fixture showed gap=0 while the full scan shows 716 L<H:

- **Different measurement.** The fixture compares fixpoint V (median(L,TIE,H))
  vs truncation V, not L vs H within the fixpoint. When L=−4, H=+4, TIE=0,
  the median is 0 — and the truncation evaluator also returns TIE=0 on
  densely cyclic states. L<H within the fixpoint does not imply
  fixpoint-vs-truncation disagreement.
- **Fixture scope.** The 24 states are the ones that were **mismatched in
  EXP-4** due to a buffer-aliasing bug in `brute_value_2x2`
  (`src/exp4_solve.zig:555-594`, T102). They are not a stratified sample of
  the state space; they are the 24 that happened to hit the aliasing defect.
  The 172 number is all reachable non-terminals from both roots through the
  EXP-4 state encoding — a superset that happens to contain the 24.
- **The fixture cannot show the phenomenon.** The 24 states are
  fixpoint-vs-truncation agreement states, not L<H probes. A fixture that
  tests the wrong property is not evidence the property is absent.

## 6. The 716 decomposed

| category | count |
|---|---|
| Total Cartesian slots (81×2×5×3) | 2,430 |
| Terminals (passes=2) | 810 |
| Non-terminals in Cartesian product | 1,620 |
| Non-terminals with L<H | 716 (44.2%) |
| D3-violating states (passes≥1, ko≠none) | 1,296 |
| D3-violating states with L<H | 232 |
| Valid (L<H − D3-violating L<H) | 484 |

Only 255 states are reachable from the fresh-start root. 170 are
non-terminal. 106 have L<H — a 62.4% bracket rate on the genuinely
reachable set. All 106 bracket-valued reachable states have ko=none; the
bracket propagates backward from ko-configurations to ancestors.

## 7. The root

The fresh-start root (empty goban, Black, ko=none, passes=0) has **L=−4,
H=+4** — the full score range. Under TIE=0, V = median(−4, 0, +4) = 0, which
matches every known published value for the empty 2×2 under basic ko (MIGOS
II: 0). The bracket says: the state alone cannot determine the value beyond
the range [−4, +4], because ko configurations downstream create
history-dependent subgames. This is the correct semantic output of the
loopy-game fixpoint — not a defect.

## 8. Adjudication

### On the check

**The pass condition "L==H on all reachable non-terminals" is unsound.** It
contradicts ADR-0020 E3, which explicitly allows bracket-valued states. The
pass0 spec's actual AC-S6 asks for a different measurement
(fixpoint-vs-truncation agreement on a fixture), which passes. The matrix
measurement over-interpreted L≠H as a defect.

**Proposed pass condition:** The correct "ADR-0020 verification" is:

1. **Fixpoint consistency (C1):** L = Φ(L) and H = Φ(H) with zero Bellman
   violations over the reachable non-terminal state space. (0 violations
   confirmed at 2×2.)
2. **Truncation-agreement fixture (C2):** The 24-state standing fixture
   produces gap=0 between fixpoint and first-revisit truncation — i.e.,
   median(L,TIE,H) equals the truncation value for all 24 (172) states.
   (Confirmed: T102/T103, re-verified this audit.)
3. **No claim of single-valuedness.** L≠H is not a defect; the bracket IS
   the deliverable. The pass condition does not require L==H.

### On the solver

**No defect found.** The fixpoint iteration converges to genuine fixpoints
(0 Bellman violations, 0 L>H violations, 0 colour-inversion violations).
The solver, both Python and Zig, is correct under ADR-0020.

### On the escalation

The escalation (`accept.md:64`, `STATE.md:229`) was filed on a measurement
that tested the wrong property. It should be closed with the finding that
the check is wrong, not the solver. The 716 number is a true statement about
the fixpoint (verified independently) but it does not indicate a defect —
it is the expected output of the semantics.

## 9. Evidence produced

- Re-ran `fix2x2.py`: 716 L<H, 0 Bellman violations on all 1,620
  non-terminals. Reproduced bit-identically.
- Re-ran `calibration-2x2-mismatch.py`: 24/24 pass, 0 mismatches.
  Reproduced bit-identically.
- Ran `zig test src/retro.zig` for the two 2×2 tests: both pass.
- Traced state idx=0 (empty, Black, ko=0, passes=0) through the Bellman
  operator, end to end: L=−4, H=+4, consistent.
- Compared Zig (position-indexed, 81 slots) and Python (Cartesian product,
  2,430 slots) state spaces: different encoding, identical semantics, both
  correct.

## 10. What could not be established

- Whether the 62.4% bracket rate (106/170 reachable non-terminals) is the
  "right" number — no independent oracle exists for comparison beyond the
  Bellman consistency check. The fixpoint is a genuine fixpoint; the bracket
  rate is what it is.
- Whether any state with L<H could be made single-valued by a richer state
  representation (e.g. bounded history). This is what C2 and C3 test at
  larger gobans — outside this audit's scope.

## 11. What to check next

- Run the #2 self-consistency auditor on the 2×2 retrograde table to
  independently verify the Zig solver's fixpoint (the Python and Zig use
  different state encodings; agreement would be strong evidence).
- Sample the bracket rate at 3×2 and 3×3 for comparison — if 62% is
  anomalous, there may be a 2×2-specific effect worth understanding.
- Amend ADR-0020:47-49, which still refers to the 24 states as "mismatch"
  states (polarity inverted — the strategy audit flagged this at
  `docs/epics/E1-markovian/sprints/verify-battery/archive/strategy-audit.md:53`).
