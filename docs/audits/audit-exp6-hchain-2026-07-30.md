# AUDIT-EXP6-HCHAIN — 4×4 H-propagation chain audit (DSPro/EXP-6)

**Task: AUDIT-EXP6-HCHAIN · Role: auditor · Model: Kimi-k3 · Date: 2026-07-30**
**Subject:** `src/exp6_solve.zig` (DSPro/EXP-6, 2026-07-29) — 4×4 under basic ko + TIE=0,
loopy-game fixpoint (ADR-0020). Fixpoint converged (31 sweeps); root B = L+1 / H+16 → V=+1
(median pin), expected anchor +2.
**Question:** is H=+16 at the empty-goban root *genuine* (White cannot force the
greatest-fixpoint bound below +16 under optimal Black play) or a propagation bug?

---

# VERDICT — H=+16 IS GENUINE. Not a propagation bug.

Every load-bearing check passed with its denominator stated, on the exact
production fixpoint (all 31 sweep lines byte-identical to the production
evidence, §5):

| check | denominator | result |
|---|---|---|
| L = Φ(L) re-derived, exhaustive | 99,133,036 compact states | **0 violations** |
| H = Φ(H) re-derived, exhaustive | 99,133,036 compact states | **0 violations** |
| child-map integrity (`map_misses`), exhaustive | all edges of 99,133,036 states | **0 misses** |
| null-child states (`L_null`/`H_null`) | 99,133,036 | **0** |
| terminal legality skips | all terminal edges | **0** |
| colour inversion L(−s)=−H(s), H(−s)=−L(s), exhaustive | 99,133,036 | **0 violations, 0 inverse-misses** |
| first-move 4-fold symmetry | 16 (1B@k, W, 0) states | constant per class ✓ |
| Trace A (terminal→root chain, §3) | 16 children at the critical minimizer | **0 children with H<16**; terminal +16 reached |
| Trace B (White-always-passes witness) ×3 starts | 3 lines × ~30 plies | all end at terminal area_score=**16**, witness COMPLETE |
| independent Python kernel, 2×2 full space | 2,430 states | **0 mismatches** |
| independent Python kernel, 3×2 | 2,586 states, reachable-set exact | **0 mismatches** |
| independent Python kernel, 3×3 | 73,758 states, reachable-set exact | **0 mismatches** |

The run log: `docs/audits/audit-exp6-hchain-2026-07-30.stdout` (79,103 lines;
exit 0; 3,137 MB peak RSS; 3,322.8 s wall under `tools/runner` ceilings
8192 MB / 14400 s — the same ceilings as production).

Root reproduced exactly: B `L=+1 H=+16 V=+1`, W `L=−16 H=−1 V=−1`, 31 sweeps,
converged, root filled (V≠−128).

## The structural finding — *where* H=+16 comes from (firstmove table)

The audit instrument's first-move dump is the decisive new datum:

| Black's first move (1B@k, White to move) | L | H | reading |
|---|---|---|---|
| **centre 2×2: k ∈ {5,6,9,10}** | **+1** | **+16** | bracket [+1,+16] — only non-losing opening |
| corners: k ∈ {0,3,12,15} | −16 | −16 | **single-score −16: White force-wins the whole goban** |
| edges: k ∈ {1,2,4,7,8,11,13,14} | −16 | −16 | same |

The root value is `max` over those children: L(root)=+1 and H(root)=+16 are
inherited **entirely from the four centre openings**. Under both fixpoints
(L==H, single-score), any corner or edge first move loses the entire 16-point
goban with White to move. This is exactly the qualitative structure 4×4 theory
requires — the acceptance criterion's own parenthetical "*central first move*"
(`docs/infra/dispatch/EXP-6.md`) is corroborated by construction: the centre
2×2 is the unique opening class that does not immediately lose. A propagation
bug would have no reason to produce this Go-correct class pattern, with perfect
4-fold symmetry inside each class and perfect colour inversion everywhere.

## Why the bracket-shaped root is the expected answer of this ruleset

The gfp H is the **safety-game bound**: {s : H(s)=16} is the greatest set closed
under [Black-to-move: ∃ child in set or terminal scoring 16; White-to-move: ∀
children in set or scoring 16]. A Go terminal requires two consecutive passes;
the second pass is Black's choice. Every non-empty all-Black goban scores
exactly +16 under TT area scoring (any empty region then touches only Black;
b + (16−b) = 16). Black under H-optimal play simply never passes except from
such gobans; basic ko (1-ply recapture ban) permits infinite recapture cycles,
so Black can keep play alive forever. White can *never* force the game to end —
hence never force a terminal below +16 against correct Black play. The gfp at
root is therefore +16 as a **ruleset fact**, not an artefact.

The same phenomenon appears at the smaller gobans where ground truth is
independently known and my independent kernel reproduces it exactly (§4):
3×2 root = bracket [−6,+6] pinned to V=0 (EXP-4's history-exact brute force
confirms 0); 3×3 root = L==H==+9 (MIGOS anchor). **H residing at the lattice
top is the operator's normal behaviour under loopy semantics; 4×4 is not
anomalous.** EXP-6 report §2's hypothesis 1 ("genuine ko ambiguity") is the
correct one; hypotheses 2 (child-processing bug) and 3 (hash-map misses) are
refuted by the exhaustive verify sweep: 0/99,133,036 violations, 0 map misses
over every child edge.

The V=+1 (not +2) comes from the **lfp** L(root)=+1 — well-founded forcing
only; cyclic refuges keep L=−16 for states that need them. Under basic ko,
Black's finite-forced optimum is +1; the +2 anchor lives in a different
cycle-resolution regime (MIGOS / PSK-class). The +1-vs-+2 gap is a **ruleset
difference surfaced**, exactly the deliverable class EXP-6 was meant to
produce. Median pin: max(+1, min(0,+16)) = +1 ✓ (root W: max(−16, min(0,−1))
= −1 ✓).

---

## 1. What the code does (verified by reading; line refs: `src/exp6_solve.zig`)

EXP-6 computes the **least fixpoint (L, seeded −16, ascend)** and **greatest
fixpoint (H, seeded +16, descend)** of the Bellman operator
T(values)(s) = opt over legal children of values(child), terminals pinned to
`genericAreaScore` (line 213), on `(board 3^16, side, ko∈0..16, passes∈{0,1,2})`
(`linearIndex4` line 896 — arithmetic checked: max index 4,390,765,541 =
TOTAL4−1 exactly; ReachWords4 = 68,605,712 ✓ matches log). V =
`@max(L, @min(TIE, H))` (`fn median`).

4×4 path is sparse: frontier-BFS census into a 549 MB dense bitset
(`run_census_4x4`; legality filter on passes==0 children only — correct: pass
edges preserve the parent's legal goban, and `genericPosFromMove` cannot
produce an illegal goban from a legal one), compact list of reachable
passes∈{0,1} states (line 1096), AutoHashMap dense→compact (line 1114),
Gauss-Seidel L sweep (line 1154) and H sweep (line 1201); terminal children
scored on the fly (lines 1225-1230), non-terminal children via `map.get`
(silent skip on miss, line 1231 — a *checked hazard*, closed by the verify
sweep's `map_misses=0` over all edges). No finisher; no bracket cut: the
fixpoint itself is the deliverable (ADR-0020).

## 2. Game-theoretic reading (semantics proof sketch)

 gfp/lfp exist and are computed correctly by monotone Gauss-Seidel from ⊥/⊤ on
 the finite lattice [−16,16]^n (Knaster-Tarski / chaotic-iteration theorem) —
 convergence in 31 sweeps with identical counters on two independent runs
 corroborates determinism. H(root)=16 ⟺ Black has a strategy to never allow a
 terminal <16 (infinite survival satisfies the bound). The game argument in
 the verdict above shows this holds: ending requires Black's own pass; Black
 passes only to +16 terminals; White's alternative — placing stones to force a
 sub-16 end — is exactly what the exhaustive H=Φ(H) check falsifies nowhere:
 at every White-to-move state, the computed min equals the stored H.

One falsifiable structural corollary, verified with denominator:
**white-to-move states with a White stone on goban and passes==1 must never
have H==16** (their pass child is a terminal scoring <16, and White minimises).
Population over 99,133,036: white-to-move H==16 = 8,223,118; with a White
stone = 8,158,215; of those passes==1 = **0** ✓. Mirror check (Black, L==−16):
8,223,118 / 8,158,215 — exact symmetry. Also `tot_H16 = tot_L-16 =
38,715,951`, the population-level inversion identity.

## 3. Traced H-update path, terminal → root (the required end-to-end trace)

Witness chain, B first move to centre cell 5 (goban rank 3^5 = 243), executed
by the instrument (Trace A) against the converged tables:

1. **Leaf** T = (243, W, ko=NONE, passes=2): not compact (terminals excluded),
   value on the fly: `genericAreaScore` = 1 stone + 15 empties touched only by
   Black = **+16** (lines 1225-1230).
2. **S1 = (243, B, ko=NONE, passes=1)** — maximizing (line 1216): children =
   [pass→T (+16), 15 placements]; `best_h = 16`; stored (lines 1242-1247).
   Trace A: `L=+16 H=+16` — this is precisely the propagation step EXP-6's
   report §2 asked about: the pass chain carries +16 from a terminal into a
   non-terminal.
3. **S0 = (243, W, ko=NONE, passes=0)** — **minimizing**: H(S0)=16 requires
   ALL children at 16. Trace A enumerated all 16: pass child (S1) at (+16,+16);
   14 of 15 placement children (1B1W gobans, B to move) are single-score
   (+16,+16) — Black finitely force-captures the lone invader; the 15th
   (White replies at centre cell 10) holds bracket (+1,+16). **0 children with
   H<16 → min = 16 = stored ✓.**
4. **Root = (0, B, NONE, 0)** — maximizing over 17 children: pass child
   (0,W,NONE,1) = (−16,−1) (DEBUG line), 15 non-centre place children =
   (−16,−16), 4 centre place children = (+1,+16) → `max ⇒ H(root)=16`,
   `L(root)=1`.

Trace B (White always passes — her purest attempt to drag the game to a
sub-16 terminal) from all three first-move classes: all three lines end at
`TERMINAL: bstones=15 wstones=0 area_score=16` — Black fills the goban and
passes out for +16. From corner/edge starts the stored value is −16, so those
lines demonstrate the recovery under a White blunder (they do not witness
H=16 there); from the centre start the premise H=16 holds at every node on the
line (all printed nodes H=+16) and the witness is complete.

**Instrument defect disclosure (mine, not the engine's):** Trace B's hardcoded
diagnostic printed `WHITE-NODE VIOLATION: 6/3 of 16 children have H<16 — stored
H=16 contradicts min` at the corner/edge starts. The stored H there is **−16**;
min over children (6 resp. 3 at −16, rest at +16, pass at +16) is exactly −16 —
fully consistent, no engine violation. The diagnostic assumed H=16 at every
traced node and misfires when the premise fails. Flagged for any reader of the
raw log; the centre-start line, where the premise holds, is violation-free.

## 4. Independent Python kernel check (true re-implementation)

`docs/audits/exp6-hchain-kernel-check-2026-07-30.py` (rules core from the QA023
kernel audit — the instrument class that found F5; satisfies "independent
re-implementation is what finds defects") vs the harness's dumped tables.
Output committed at `docs/audits/exp6-hchain-kernel-check-2026-07-30.stdout`:

| goban | denominator | reach-set equality | value mismatches | inversion | white p=1 mixed H==top |
|---|---|---|---|---|---|
| 2×2 (full raw space) | 2,430 | n/a (bijection, no dup keys) | **0** | n/a | n/a |
| 3×2 (reachable) | 2,586 | **exact** (0 either direction) | **0** | **0** | **0** |
| 3×3 (reachable) | 73,758 | **exact** | **0** | **0** | **0** |

Python fixpoints: 2×2 4 sweeps; 3×2 10 sweeps (root (−6,+6) → V=0 ✓ EXP-4);
3×3 17 sweeps (root (+9,+9)/(−9,−9) ✓ MIGOS). Validates — independently of all
Zig code — move generation (place/capture/suicide/basic-ko formalization (i)),
area scoring, census closure, the L/H operator, and the median pin at every
gate size, and reproduces the H-at-top *phenomenon itself* where the pinned
ground truth is known.

## 5. Deterministic reproduction of production

`diff` of the 31 `# 4x4 fixpoint sweep N: L_changed=…` lines between
`docs/evidence/QA-026/4x4/exp6-solve-2026-07-29.stdout` and the audit log:
**byte-identical, all 31** (plus census 147,638,298/32 sweeps; compact
99,133,036; root trajectory −16→+1 at sweep 13). The operator is deterministic
⇒ the audit observed the production fixpoint itself, not a neighbour of it.

## 6. FINDING (process, not values) — provenance drift in exp6_solve.zig

Committed `src/exp6_solve.zig` (sole commit b9caa4f) contains **5** DEBUG
prints after the fixpoint; the committed run evidence contains only **2** —
the three blocks for `(1B,W,0)`, `(1B1W,B,0)`, `(1B1W,W,1)` each print in
either branch, so their absence proves the evidence binary lacked them (runner
footer present: no truncation). Three read-only diagnostic blocks were **added
to the source after the evidence-producing run** (file mtime 2026-07-30 06:42).
Values unaffected (no state writes; §5's byte-identical reproduction of the
*evidence's* sweep stream confirms). Recommend a one-line correction note in
`docs/evidence/QA-026/4x4/PROVENANCE.md`. (Incidentally, the missing three
values, now measured by this audit's run: (1B@0,W,0) = (−16,−16);
(1B@0+1W@1,B,0) = (+1,+16); (1B@0+1W@1,W,1) = (−16,−16).)

## 7. Residual risks this audit does not close

1. The 4×4-specific transcription `apply_place4` (line 922; ko-detect logic
   textually equal to `apply_place32`, which *is* independently validated at
   3×2 by §4) is validated at 4×4 only consistency-level: exhaustive fixpoint
   equations, inversion, symmetry, plus the §4 kernels at ≤3×3 sharing the
   same generic core (lines 165-241). No second end-to-end 4×4 solver exists.
2. EXP-3 cross-check (`kostate-census-2026-07-28.md`: 51,419,046 reachable
   (b,side,ko) triples) reconciles only at scale: EXP-6's passes=0 triples =
   99,133,036 − (147,638,298 − 99,133,036) = 50,627,774 (~1.5% gap),
   unresolved — EXP-3 folds passes analytically (×2), not as graph states. NOT
   cited as validation.
3. L=+1's game-theoretic meaning (what Black finitely forces; why not +2) is
   not independently game-tree-verified at 4×4 (EXP-6 §13's brute root check
   was out of scope). The centre-class finding mitigates but does not close
   this.
4. Whether loopy-game fixpoint is the right *target* is ADR-0020's settled
   decision; not relitigated here.

## 8. Evidence & files

- `docs/audits/audit-exp6-hchain-2026-07-30.stdout` — full run log (79,103
  lines; runner exit 0; 3,137 MB peak; 3,322.8 s)
- `docs/audits/exp6-hchain-kernel-check-2026-07-30.py` + `.stdout` —
  independent kernel check, exit 0, all PASS
- `src/exp6_hchain_audit.zig` — faithful-copy instrument (post-convergence,
  read-only audits only: verify / inversion / firstmove / trace A / trace B;
  contains the §3- Trace-B diagnostic defect disclosed in §3)
- Production evidence: `docs/evidence/QA-026/4x4/exp6-solve-2026-07-29.stdout`
- Sources read completely: `src/exp6_solve.zig`,
  `docs/research/newrule-4x4-2026-07-28.md`, `docs/infra/dispatch/EXP-6.md`,
  `docs/decisions/ADR-0020-loopy-game-fixpoint-semantics.md`,
  `docs/research/kostate-census-2026-07-28.md` §method.

## 9. Recommended claim-status inputs (owner `CLAIMS.md`)

- `4x4.BASICKO-TIE` — V=+1 faithful to the loopy-fixpoint operator (lfp L=+1,
  gfp H=+16, median pin); the +2-anchor failure is a **ruleset** difference
  (basic ko vs PSK-class cycle handling), not a propagation defect. Structural
  finding attached: centre 2×2 openings are the unique non-losing class;
  corner/edge openings are single-score −16. **CLAIMED** at 4×4 (per-goban
  independence; residuals §7).
- `QA-026` (4×4 scope) — L/H converge machinery + H-propagation: **CLAIMED**;
  this audit supplies the deferred H-propagation audit (EXP-6 report §13, item
  1) with exhaustive denominator-stated counters.
- Process input: EXP-6's committed solver source drifted from its evidence
  binary by three read-only DEBUG blocks (§6); PROVENANCE note recommended.
