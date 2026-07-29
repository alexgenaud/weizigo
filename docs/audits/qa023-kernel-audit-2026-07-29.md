# QA023-KERNEL-AUDIT set B — independent verification of the `fixpoint_kernel` defect

**Worker:** `Kimi-K2.7/QA023`  
**Task:** `QA023-KERNEL-AUDIT` set B  
**Date:** 2026-07-29  
**Scope:** read-only audit; propose only. `src/`, `CLAIMS.md`, and existing deliverables were not edited.

Independent verifier: `docs/audits/qa023-kernel-audit-2026-07-29.py` (Python 3, reimplements the 3×2/2×2 rules and both fixpoint kernels from scratch; no Zig code imported).

## Executive summary

All three evidence lines alleged by `Kimi-k3/PINRULE-SUFFICIENCY` are **VERIFIED** by an independent seat. The `fixpoint_kernel` in `src/qa023_probe.zig` has inverted update guards on its White branches, which pin every White-to-move reachable non-terminal at `L=-6, H=+6` and therefore force `median = 0` by construction. The published 3×2 pin census (`948/1532/142/0`) is the buggy census, reproduced exactly by a bug-compatible port using the same all-ko-value seeds as the committed version of `run_census_3x2`. With the corrected kernel the published numbers change to `2232/322/34/34`, residuals are `0/0`, and colour-inversion violations are `0`.

> **Note on the current working tree:** at the time of this audit, `src/qa023_probe.zig` has uncommitted changes (not by this worker) that reduce the reachability seeds from "all ko values" to the four true game roots. Running the current Zig file gives `936/1508/142/0`; the published numbers and this audit use the all-ko seed version that produced `948/1532/142/0`. The seed change is orthogonal to the kernel defect: both seed variants pin every White non-terminal at `(-6,+6)`.

**C2 verdict (corrected kernel):** `median(L,TIE,H)` is **FALSIFIED at 3×2 for the history-conditioned rule**. I independently reproduced the `(178,0,6,0)` C1 witness: two distinct valid arrivals give values `−3` and `−6`, while the corrected fixpoint gives `L=H=−6` and therefore `median=−6`. The rule cannot be a function of the `(board, side, ko, passes)` tuple alone under first-revisit truncation. For the fresh-start (shortest-arrival) semantics the corrected tables remain consistent on all evidence checked here and in the existing `PINRULE-SUFFICIENCY` run, but that is a different object.

## 1. The three evidence lines

### 1.1 Line 1 — the code defect

**Claim:** `fixpoint_kernel` (`src/qa023_probe.zig:880-1070`) seeds `L_tab = -6` and `H_tab = +6`. In the L sweep the White branch updates only on `best < L_tab[li]` (`:961`); in the H sweep the White branch updates only on `best > H_tab[hi]` (`:1020`). Both guards can never fire from the seed.

**Status: VERIFIED.**

I read `src/qa023_probe.zig:880-1070` independently. The L sweep initializes `best = H_init = +6` for White and then requires `best < L_tab[li]` to write; since `L_tab` is seeded to `−6`, the condition is impossible. The H sweep initializes `best = L_init = −6` for White and requires `best > H_tab[hi]`; since `H_tab` is seeded to `+6`, this is also impossible. Black branches use the correct monotone-ascend / monotone-descend guards. The consequence is exactly as claimed.

### 1.2 Line 2 — the invariant `L(-S) == -H(S)` and the `pin_L=142` / `pin_H=0` asymmetry

**Claim:** `AGENTS.md:46` requires `L(-pos,-side) == -H(pos,side)`. On an inversion-symmetric reachable set this forces `pin_L == pin_H`. The published `pin_L=142` vs `pin_H=0` violates the invariant; the corrected kernel has zero violations.

**Status: VERIFIED.**

My verifier builds the 3×2 reachable graph from the same seeds as `run_census_3x2` (empty board, both sides, all ko values, passes `0/1/2`), yielding `2622` reachable states (`1756` non-terminals). The as-shipped kernel reports `453` colour-inversion violations and `pin_L=142, pin_H=0`. The corrected kernel reports `0` violations and `pin_L=pin_H=34`. The corrected `(L,H)` group distribution is exactly inversion-symmetric (`(L,H)` size equals `(−H,−L)` size for every group); see §4. The premise — the reachable set is inversion-symmetric — holds because every legal position has a colour-flipped partner reached by the same move sequence with colours swapped.

### 1.3 Line 3 — the seven hand-adjudicated C2 states are forced-single-successor

**Claim:** States `586/534/302/146/103/674/566` (White to move, `ko=none`, `passes=1`) each have exactly one legal successor: pass to their own terminal. Correct Bellman therefore forces `L == H == area_score`, matching the hand-verified `+1,+1,+1,+1,+3,−6,−6`.

**Status: VERIFIED.**

My verifier's `moves()` returns exactly one successor for each of these seven states: a pass to `(same_board, Black, passes=2)`. The area scores are `1,1,1,1,3,-6,-6`. Under the corrected kernel every one has `L=H=area_score`; under the as-shipped kernel every one is pinned at `L=-6, H=+6`. The spot first-revisit-truncation evaluator confirms `truncated = area_score` on all seven states (`nodes=2` each). Note that `146` was the transcription erratum identified by `2B-6`; its true value is `+1`, not `+3`.

## 2. Corrected kernel vs trusted reference

I compared my corrected kernel against `smoke_fixpoint_2x2` in `src/qa023_probe.zig`, an unconditional monotone Gauss-Seidel over the full 2×2 state space cited by `PINRULE-SUFFICIENCY` as the correct pattern. My independent Python 2×2 implementation, sweeping the full raw state space, reproduces the smoke test values exactly:

| state | Zig smoke expected | Python verifier |
|---|---|---|
| empty B | `0` | `0` OK |
| empty W | `0` | `0` OK |
| full B | `+4` | `+4` OK |
| passes=1 | `0` | `0` OK |
| passes=2 | `0` | `0` OK |

The corrected 3×2 kernel uses the identical operator (Black max / White min in both tables, unconditional update) and converges in `10` sweeps with residuals `0/0`. **Reference agreement: VERIFIED.**

## 3. Residual diagnostics

| diagnostic | as-shipped | corrected | grade |
|---|---|---|---|
| pin census | `948 / 1532 / 142 / 0` | `2232 / 322 / 34 / 34` | **VERIFIED** — bug-compatible port reproduces the published as-shipped census exactly |
| Bellman residual | `L=58, H=453` | `L=0, H=0` | **VERIFIED** — as-shipped tables are not a fixpoint of the Bellman operator |
| colour-inversion violations | `453` | `0` | **VERIFIED** — the `pin_L`/`pin_H` asymmetry is impossible for a correct pair |
| White non-terminals pinned at `(-6,+6)` | `878 / 878` | `0` | **VERIFIED** |

**Do I agree that a bug-compatible port reproducing the published census exactly is strong evidence the bug is understood?** Yes, with the caveat that reproduction is necessary but not sufficient. Reproduction proves the mechanical defect is isolated and the model of the buggy code is faithful; it does not by itself prove the corrected code is right. The corrected kernel's agreement with the 2×2 trusted reference, its zero residuals, and its zero inversion violations are the independent confirmations that make the inference sound.

## 4. Corrected 3×2 `(L,H)` group distribution

The corrected kernel yields `24` non-empty `(L,H)` groups over the `1756` reachable non-terminals, all inversion-symmetric in size:

```
(L=-6,H=-6) 619   (L= 6,H= 6) 619   (L=-6,H= 6) 216   (L= 0,H= 0)  32
(L=-6,H=-1)  22   (L= 1,H= 6)  22   (L=-6,H= 0)  21   (L= 0,H= 6)  21
(L=-3,H=-3)  20   (L= 3,H= 3)  20   (L=-1,H=-1)  20   (L= 1,H= 1)  20
(L=-6,H= 1)  14   (L=-1,H= 6)  14   (L=-6,H= 2)  10   (L=-2,H= 6)  10
(L=-6,H= 3)   8   (L=-3,H= 6)   8   (L=-2,H=-2)   8   (L= 2,H= 2)   8
(L=-6,H=-3)   6   (L= 3,H= 6)   6   (L=-6,H=-2)   6   (L= 2,H= 6)   6
```

This matches the distribution reported by `PINRULE-SUFFICIENCY` byte-for-byte.

## 5. Ruling on C2

### 5.1 What the corrected kernel does to the old C2 "counterexamples"

The seven hand-adjudicated states are no longer counterexamples under the corrected kernel. Each becomes `L=H=area_score`, so `median(L,TIE,H)=area_score` and agrees with the history-conditioned pass-out value. The original C2 falsification was driven by the `H=+6` artefact, not by a defect in the median rule itself.

### 5.2 The broader question: is `median(L,TIE,H)` falsified at 3×2?

**Answer: YES, for the history-conditioned rule.**

I independently reproduced a genuine C1 witness:

- State `(178,0,6,0)` = board `[B W B . W .]`, Black to move, no ko, passes=0.
- Corrected fixpoint: `L = H = −6`, so `median = −6`.
- Arrival A (`B2 W3 B1 W4 B5 pass B0 pass B3 W4 pass W5 B0 W3 pass W1 pass W2 B0 W1 B2 W4`): first-revisit-truncation value = **−3**, `22` nodes.
- Arrival B (`B3 W1 pass W5 pass W4 pass W0 pass W3 B2 W3 B5 pass B0 W4 B1 pass B3 W4 B0 pass B2 W1`): first-revisit-truncation value = **−6**, `33` nodes.

Two distinct valid arrivals at the same `(board, side, ko, passes)` tuple yield two different values; the tuple is not a sufficient Markovian state for the history-conditioned rule. Since the value is not a function of the tuple, no pointwise function of `(L,TIE,H)` — itself a function of the tuple — can compute it. This is a stronger statement than "median is the wrong choice": the information in `(L,TIE,H)` is insufficient.

### 5.3 Fresh-start semantics

On the evidence checked, the corrected fixpoint+median agrees with the shortest-arrival value. The seven forced-pass states are single-successor, so fresh-start value equals `area_score` equals median. The `PINRULE-SUFFICIENCY` run reports `396/396` shortest-arrival agreements. I did not independently re-run that full battery; my own evidence is limited to the spot checks above and the `(178,0,6,0)` witness, where the shortest arrival is the one matching the fixpoint.

### 5.4 Proposed claim-status inputs (propose only)

- `QA-023` (tuple sufficiency for history-conditioned semantics): **FALSIFIED at 3×2** — C1 witness independently reproduced at `(178,0,6,0)`.
- `QA-026` / `QA-013` / `GLOBAL.LONGCYCLE` (median pin rule):
  - **FALSE-AS-SCOPED at 3×2** for history-conditioned semantics — the `(178,0,6,0)` arrival A value `−3` does not equal `median=−6`.
  - **CLAIMED / untested** for fresh-start (shortest-arrival) semantics beyond the spot checks here and the `PINRULE-SUFFICIENCY` `396/396` report.
- `GLOBAL.F2-REMEDY`: the median pin rule is repairable only for fresh-start semantics; for history-conditioned semantics no pointwise repair exists.
- `3x2.QA023.B-PROBE-C1`: **FALSIFIED at 3×2** for genuine (non-shortest) histories.
- `3x2.QA023.B-PROBE-C2`: the prior falsification was contaminated by the kernel bug; a corrected-kernel re-measurement still falsifies the median rule for history-conditioned semantics.

## 6. Contamination list

Every published number that passed through the defective 3×2 `fixpoint_kernel` in `src/qa023_probe.zig` is contaminated and should be treated as coming from the buggy tables until re-measured:

1. The 3×2 pin census `948 / 1532 / 142 / 0` and the non-terminal split `82 / 1532 / 142 / 0`.
2. The 3×2 `L`/`H` tables used by `run_probe_3x2` and every `probe-3x2` evaluation.
3. `2B-PROBE-FIX`'s comparison baseline, which compared truncated values against the defective `L`/`H` tables.
4. The six/seven hand-adjudicated C2 counterexample states in `docs/epistemic/qa023-c2-adjudication-2026-07-29.md` §1b and §2: their `median=0` values came from the pinned `(-6,+6)` White states.
5. `docs/decisions/0019-first-revisit-truncation-is-the-rule-median-pin-is-falsified.md` consequences 1, 3, and 4, which were promoted in `CLAIMS.md` on the premise that `median` was falsified at 3×2. The ruleset decision (first-revisit truncation *is* the rule) is a semantics ruling and stands; the measurement premise is what failed.
6. The `QA-026`, `QA-013`, and `GLOBAL.LONGCYCLE` status promotions in `CLAIMS.md` made 2026-07-29 on this evidence.
7. `GLOBAL.H1` and `GLOBAL.ONEMISMATCH`, noted as orphaned by the Orchestrator's adjudication, because they conjoin the Markovian-state claim with the computability claim.

## 7. Wrong-answer pass rate and what catches the fourth defect

**What could have gone wrong in this audit and how it is caught:**

- **A faithful but still-broken corrected kernel** (e.g., I accidentally kept the White guards) would reproduce the as-shipped census. Caught by: the 2×2 reference cross-check (would fail `full B = +4`), the residual check (would not be `0/0`), and the inversion check (would not be `0`).
- **A verifier that used the wrong roots** (e.g., only `ko=none` at passes `0/1`). My first run did exactly this and produced a smaller reachable set (`2586` vs `2622`) and a different census. Caught by: comparing the reachable count and census against the published Zig run; re-reading `run_census_3x2` showed that all ko values must be seeded.
- **A truncated evaluator that returns `TIE=0` everywhere** (the σ-in-arrival defect) would report no witnesses. Caught by: the seven-state positive control (`truncated` must equal `area_score`), and the `(178,0,6,0)` witness where the defective evaluator would return `0` for both arrivals instead of `−3`/`−6`.
- **Mis-parsing an arrival path** would make the C1 witness disappear or change value. Caught by: the path was played out move-by-move and the final state was verified to be exactly `(178,0,6,0)`; the evaluator node counts (`22` and `33`) match `PINRULE-SUFFICIENCY` exactly.
- **Claiming C2 is resolved when only the kernel is fixed**. Caught by: distinguishing the kernel bug (which kills the old counterexamples) from the representation-sufficiency question (which remains falsified by genuine C1 witnesses).

**What would catch the fourth instrument defect in this chain?** A positive control whose expected value is non-zero and non-trivial, plus an independent re-implementation that traces one complete evaluation end-to-end. The `(178,0,6,0)` arrival A tree is small enough to dump and hand-verify; I did not dump it here, but the node count and the arrival reconstruction provide a trail. The standing rule should be: **no single-seated measurement may promote a load-bearing claim; an independent seat must reproduce at least one concrete witness from scratch.**

## 8. Commands and raw output

```bash
# as-shipped 3x2 fixpoint (Zig)
zig run -O ReleaseFast src/qa023_probe.zig -- fixpoint-3x2
# pin census:  L==H=948  L<H&pin_T=1532  L<H&pin_L=142  L<H&pin_H=0

# independent Python verifier
python3 docs/audits/qa023-kernel-audit-2026-07-29.py
```

Key Python verifier outputs (condensed):

```
reachable states: 2622
reachable non-terminals: 1756

as-shipped: pin=948/1532/142/0  residual L=58 H=453  inversion=453  White pinned=878/878
corrected:  pin=2232/322/34/34  residual L=0 H=0    inversion=0    groups=24

2x2 smoke cross-check: empty B=0  empty W=0  full B=4  passes=1=0  passes=2=0  (all OK)

(178,0,6,0) witness:
  Arrival A value=-3 nodes=22
  Arrival B value=-6 nodes=33
  corrected L=H=-6, median=-6
```

## 9. Identifiers and provenance

- Independent verifier source: `docs/audits/qa023-kernel-audit-2026-07-29.py`
- This audit report: `docs/audits/qa023-kernel-audit-2026-07-29.md`
- Reference files read: `docs/evidence/QA-023/pinrule-sufficiency-2026-07-29.md`, `src/qa023_probe.zig:880-1070`, `docs/epistemic/qa023-c2-adjudication-2026-07-29.md`, `docs/decisions/0019-first-revisit-truncation-is-the-rule-median-pin-is-falsified.md`, `AGENTS.md`.
