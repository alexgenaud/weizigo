<!--managent set=M-->
# T114 — ADR-0006 (eye-prune) falsification/validation battery

**Task:** T114 · **Role:** auditor · **Model:** Opus 5 · **Date:** 2026-07-30
**Target:** `GLOBAL.ADR0006-EYE` — "forbidding a player from filling its own
Benson-alive true eye does not change the game score"
**Opened by:** `docs/audits/epistemic-tree-shake-fable-2026-07-30.md` **W1**
**Source:** `src/eyeprune_battery.zig` (new; no engine file modified)
**Stdout:** `docs/audits/eye-prune-validation-2026-07-30.stdout`

---

## 0. Verdict

**ADR-0006 is not falsified. It is validated considerably further than it was,
and the earlier evidence is corrected in three specific ways.**

| | |
|---|---|
| **Falsified?** | No. For the shipped predicate: zero disagreements and zero lemma violations in every section. |
| **New coverage** | Six structural premises of the ADR's soundness argument now hold **exhaustively at 4×4** (1,362,424 eyes over 909,540 eye-positions) — the first ADR-0006 evidence at the frontier board. |
| **Correction 1** | The 2026-07-29 denominator of 1050 is inflated: **226 of those 1050 positions are `is_settled`**, where both arms return before move generation. The non-vacuous denominator at 3×3 is **824**. |
| **Correction 2** | The 2026-07-29 **control arm is not the unpruned game value.** Its memo caches every `(pos, side, passes)` node under positional superko, which is unsound; the sound version does not terminate (32/32 roots unresolved at **3×2**, 6 cells). |
| **Correction 3** | The known-bad class this task asked for — "self-eye-fill is the only legal move" — **exists but is entirely absorbed by `is_settled`** at every board tested (4/4, 20/20, 106/106). The prune has never yet produced an empty move list in a live node. |
| **Residual risk** | The *strong* test (fresh-start value with vs without the prune, computed soundly) is **not computable by forward search at any board size**, including 2×2. What replaces it is §6: the unpruned retrograde table as the control. |

The blast radius W1 describes is real, and this battery narrows it without
closing it. What is now well-supported is the **predicate** and the **local
premises**. What remains supported only indirectly is the **global dominance
claim** on ko-sensitive slots.

---

## 1. What was actually validated before

ADR-0006's own results section cites one position (`dead_white`, Black +25,
`0006:59-61`). `docs/evidence/ADR-0006/eye-prune-falsification-2026-07-29.md`
added a 3×3 sweep: 1050 eye-positions, 0 disagreements, one random-cell
calibration with a 22.5 % wrong-answer pass rate.

Three gaps in that evidence, each addressed below:

1. **No known-good/known-bad fixtures.** Nothing distinguished "the predicate
   fires on genuine eyes" from "the predicate fires". A predicate that returned
   `false` everywhere would have scored 0 disagreements too.
2. **A calibration that does not model a plausible defect.** Pruning a random
   non-eye cell is not how this code fails; dropping the Benson requirement is.
3. **An unexamined denominator and an unexamined control.** Both are wrong, in
   opposite directions (§3, §5).

---

## 2. Battery design

Eight sections, all in `src/eyeprune_battery.zig`, run through `tools/runner`:

| § | Section | Question | Board coverage |
|---|---|---|---|
| A | Predicate fixtures | Does the predicate fire on genuine eyes and *not* fire on false eyes, one-eye groups, big-eye space, opponent eyes? | hand-built 3×3 + 5×5 |
| B | Cross-implementation | Do the project's **two** copies of the predicate agree? | 5×5, 4.0 M empty cells |
| C | Class scan | How many legal moves does the prune remove, and is there any position where it removes *all* of them? | exhaustive 2×2/3×2/3×3 |
| D | Score equivalence | With vs without the prune, sound memo | exhaustive 3×2; 3×3 |
| E | Memo soundness | Did the 2026-07-29 caching rule change any answer? | exhaustive 3×2/3×3 |
| F | Mutant score calibration | Would the score comparison catch four *plausible* wrong predicates? | exhaustive 2×2/3×2 |
| G | Structural lemmas | Do the ADR's stated premises hold, position by position? | exhaustive to **4×4**, sampled 5×5 |
| H | Sound control | Does the eye-pruned forward search agree with the **unpruned retrograde table**? | 2×2/3×2 exhaustive; 3×3/4×3 scoped |
| I | **Lemma calibration** | Do §G's lemmas actually *fire* when the predicate is wrong? | exhaustive 3×3/4×3 |

Rules throughout: area (Chinese) scoring, Black-positive, positional superko
(pass exempt), terminal on double pass or `is_settled` — i.e. `oracle.zig`
semantics.

---

## 3. §A/§B — the predicate itself

**Known-good** (the prune MUST fire — the eye is genuine and filling it is
dominated) and **known-bad** (the prune MUST NOT fire — removing the move could
remove a needed one). 17 hand-labelled assertions, **17 pass, 0 fail**:

| class | fixture | expected | got |
|---|---|---|---|
| GOOD | 3×3 `X.X/XXX/...` — alive group, single-point eye | prune | prune |
| GOOD | 3×3 `X.X/XXX/X.X` — both eyes of an alive group | prune | prune |
| GOOD | 5×5 two-eye alive group, both eyes | prune | prune |
| GOOD | 5×5 `dead_white` (the ADR's own anchor), cells 6 and 18 | prune | prune |
| BAD | 3×3 **false eye** (three unconnected stones) | no prune | no prune |
| BAD | 5×5 **false eye** (cuttable, no Benson chain) | no prune | no prune |
| BAD | 5×5 **one-eye group** (not Benson-alive) | no prune | no prune |
| BAD | 3×3 **2-point eye space**, both points | no prune | no prune |
| BAD | open-territory points adjacent to an alive group | no prune | no prune |
| BAD | the **opponent's** view of a genuine eye | no prune | no prune |
| BAD | 5×5 `dead_white` cell 3 — the capturing move | no prune | no prune |

The three false-eye / one-eye fixtures are the discriminating ones: on all
three, the naive "all neighbours are my stones" predicate **would** prune, and
the shipped predicate does not. That is the Benson certificate doing its job,
and it is now pinned by tests rather than by argument.

**§B — the second implementation.** `solve.zig:168` carries a private copy of
the predicate hard-coded to a 5-wide grid; `rules.zig:348` has the generic one.
They are never compared in the test suite. Transcribing `solve.zig`'s verbatim
and differentially testing it against `rules.zig` over 200,000 random dense 5×5
boards — **3,999,936 empty cells compared, 21,828 eyes found, 0 mismatches.**
(Limitation: this compares a transcript, because the original is not `pub`. It
detects indexing divergence between the engines, not a defect shared by both.)

---

## 4. §C — the class scan, and the known-bad class T114 asked for

For every legal position × side, how many legal board moves the prune removes:

| board | legal positions | pairs | removes nothing | removes some | **PRUNE-ALL** | of which `is_settled` | **live PRUNE-ALL** |
|---|---|---|---|---|---|---|---|
| 2×2 | 57 | 114 | 110 | 0 | 4 | 4 | **0** |
| 3×2 | 489 | 978 | 918 | 40 | 20 | 20 | **0** |
| 3×3 | 12,675 | 25,350 | 24,300 | 944 | 106 | 106 | **0** |

**The known-bad class is non-empty but unreachable by move generation.** Every
position at which self-eye-fill is the mover's *only* legal board move is
already an `is_settled` terminal, so the solver returns `area_score` before it
ever builds a move list. The prune therefore never yields an empty move list at
a live node on any board tested — the failure mode "prune removes every move,
search has nothing to do" does not occur.

Why this is structural rather than lucky: for the prune to remove *every* legal
move, every empty point must be either the mover's own true eye or illegal for
the mover. Illegal-for-the-mover means suicide, which means enclosure by living
opponent stones. A board partitioned into two such regions with no dame and no
non-alive stone satisfies all three `is_settled` conditions. Breaking
`is_settled` requires a dead stone or a dame, and either one hands the mover a
legal non-eye move. **The exhaustive scan confirms this holds at 2×2, 3×2 and
3×3; it is not proved for larger boards.**

**Vacuity correction.** The same scan gives the denominator the 2026-07-29 run
should have quoted:

| board | positions with ≥1 eye | of which `is_settled` | non-vacuous pairs |
|---|---|---|---|
| 2×2 | 4 | 4 | **0** |
| 3×2 | 60 | 28 | 32 |
| 3×3 | **1,050** | **226** | **824** |

The 1050 figure reproduces exactly, which cross-validates both enumerations.
But 226 of those positions are settled, so the with/without comparison there is
`area_score == area_score` — it cannot fail. **The 2026-07-29 result is
0 disagreements over 824 live pairs, not 1050**, and at 2×2 the same test would
be entirely vacuous.

---

## 5. §D/§E — the control arm does not exist

Section D re-runs the with/without comparison using a memo that is exact under
superko: the key includes an order-independent hash of the **full set** of
positions in the game line, so a cached value is only ever reused under an
identical superko constraint set.

| board | pairs checked | disagreements | **unresolved** | nodes (control / pruned) |
|---|---|---|---|---|
| 2×2 | 0 (no live pairs) | 0 | 0 | — |
| 3×2 | 32 | 0 | **32 (all)** | 64,000,032 / **128** |
| 3×3 | 824 | 0 | **824 (all)** | 1,648,000,824 / 384,004,560 |

Section D returns **no positive information at any board size**: the sound
control resolved zero of the 856 pairs. Its value is the negative result.

At 3×2 — **six cells** — the unpruned control exhausts a 2,000,000-node budget
on *every one* of the 32 roots, while the pruned arm answers all 32 in 128 nodes
total. `solve.zig`'s production `ko_ref` rule fares no better: in §6 it leaves 24 of
32 2×2 slots unresolved even *with* the prune, because on sparse boards the
prune barely fires and the pruned search is the unpruned search.
This is not a budget that wants raising: under positional superko the value of a
node depends on the set of positions already played, and without the prune that
set space does not collapse. It is the same fact ADR-0020 (loopy-game fixpoint)
and ADR-0009 (value iteration instead of DFS) are built around.

**Consequence for the prior evidence.** `eyeprune_falsify.zig` caches every
`(pos, side, passes)` node unconditionally. That is what made its control arm
finish in 106 s — and it means the "score without the eye-prune" it printed is
**not the unpruned game value**; it is the value under a memo that ignores
history. The 0/1050 result therefore compares the pruned search against an
approximation, not against ground truth. Both arms shared the defect, so the
comparison is not meaningless — but it cannot certify what it was read as
certifying.

Section E measures whether the three caching rules disagree **on the pruned
arm**, where all three are tractable:

| board | comparison | pairs | differences |
|---|---|---|---|
| 3×2 | `solve.zig` ko_ref vs 2026-07-29 always-cache | 32 | **0** |
| 3×2 | exact history-set vs `solve.zig` ko_ref | 32 | **0** |
| 3×2 | exact history-set vs 2026-07-29 always-cache | 32 | **0** |
| 3×3 | `solve.zig` ko_ref vs 2026-07-29 always-cache | 824 (192 unresolved) | **0** |
| 3×3 | exact history-set vs `solve.zig` ko_ref | 824 (192 unresolved) | **0** |
| 3×3 | exact history-set vs 2026-07-29 always-cache | 824 (192 unresolved) | **0** |

So on the pruned arm the unsound memo happened to give the right answers here.
That is a useful reassurance about `solve.zig`'s TT rule, and it is *not*
transferable to the unpruned arm, which is where the memo does the heavy lifting
and where no sound value exists to compare against.

---

## 6. §H — the sound control that does exist

The project already owns an unpruned solver that does not blow up: the
retrograde value iteration (`retro.zig` `sweep`, `apply_eye_prune = false`,
ADR-0009 Decision 3). On slots flagged neither `KO_SENSITIVE` (bracket, not a
single value) nor `FROM_FORWARD` (written by the eye-pruned finisher — using it
would be circular), the stored number is an exact fresh-start score computed
over the **full legal move set**.

Comparing the eye-pruned forward search against those slots is the sound version
of the ADR-0006 test — and it is precisely the standing test ADR-0009:118-123
promised and `GLOBAL.ADR0006-TEST` records as "PROVEN (as method)". The register
carries the method with **no run and no denominator attached**, and the
tree-shake audit records that it has never fired. **Here it is executed with
explicit denominators.**

(Assumption: the committed `artifacts/oracle-*.wzo` are the output of that
value-iteration pipeline. `retro.zig:98` sets `apply_eye_prune = false` for the
sweep, and the `FROM_FORWARD` flag — zero on all three small-board artifacts —
is what marks anything the eye-pruned finisher wrote.)

| artifact | slots | KO_SENSITIVE | FROM_FORWARD | checked | resolved | **disagreements** |
|---|---|---|---|---|---|---|
| `oracle-2x2.wzo` | 114 | 82 | 0 | 32 (all non-KO) | 8 | **0** |
| `oracle-3x2.wzo` | 978 | 378 | 0 | 600 (all non-KO) | 168 | **0** |
| `oracle-3x3.wzo` | 25,350 | 8,698 | 0 | 1,050 (prune-touched) | **858** | **0** |

The unresolved remainder is the forward search timing out, not a disagreement.
Note the shape of what resolves: the eye-pruned forward search terminates on
*dense* positions and not on sparse ones — exactly the regime ADR-0006 claims
for itself ("eye-pruning tames endgames … it does not make the empty-board full
solve cheap"). The prune's own scope statement predicts this coverage pattern.

**Caveat on inheritance.** This test inherits each artifact's provenance. For
2×2–4×3 those are value-iteration outputs; §5 of the tree-shake audit (W5, D16)
raises separate questions about the 4×4 checkpoint that this battery does not
address.

---

## 7. §F/§I — calibration that models real defects

Pruning a random non-eye cell (the 2026-07-29 calibration, 22.5 % pass rate) is
not how this code fails. Four **plausible** wrong predicates were substituted
for `is_own_eye` instead:

- **M1 naive-eye** — all neighbours are own stones, Benson requirement dropped.
  The canonical wrong implementation, and the one the false-eye fixtures target.
- **M2 two-liberty "alive"** — Benson replaced by the cheap heuristic
  "every neighbouring chain has ≥2 liberties".
- **M3 any-alive-neighbour** — `all` weakened to `any`; a gross over-prune,
  present as an "is the harness awake" case.
- **M4 interior-only** — prunes only points with four real neighbours, so it
  strictly **under**-prunes relative to ADR-0006. This is the deliberate
  **null control**: an under-prune cannot break a claim of the form "removing
  these moves is safe", so if the battery is well-calibrated M4 must come back
  clean. A battery that flags M4 is over-sensitive and its zeroes mean nothing.

### §I — the lemma battery is calibrated

§8's zeroes are only evidence if the same lemmas fire on a wrong predicate.
Each mutant was substituted and the whole scan re-run. **Violation counts:**

| board | predicate | eye-positions | eyes | L1 | L2 | L3 | L4 | L7 | L8 |
|---|---|---|---|---|---|---|---|---|---|
| 3×3 | **ADR-0006 (shipped)** | 1,050 | 1,414 | **0** | **0** | **0** | **0** | **0** | **0** |
| 3×3 | M1 naive-eye | 4,120 | 5,032 | 274 | 0 | **1,032** | 0 | 144 | 72 |
| 3×3 | M2 two-liberty | 3,134 | 3,726 | 0 | 0 | 0 | 0 | **56** | 40 |
| 3×3 | M3 any-alive-neighbour | 1,050 | 2,846 | 0 | **1,160** | 848 | 744 | 0 | 0 |
| 3×3 | M4 interior-only (null control) | 30 | 30 | **0** | **0** | **0** | **0** | **0** | **0** |
| 4×3 | **ADR-0006 (shipped)** | 16,132 | 24,164 | **0** | **0** | **0** | **0** | **0** | **0** |
| 4×3 | M1 naive-eye | 119,348 | 148,532 | 7,432 | 0 | **30,744** | 0 | 5,148 | 3,864 |
| 4×3 | M2 two-liberty | 91,386 | 110,356 | 0 | 0 | 0 | 0 | **2,696** | 2,444 |
| 4×3 | M3 any-alive-neighbour | 16,132 | 55,124 | 0 | **24,496** | 20,424 | 13,548 | 1,284 | 0 |
| 4×3 | M4 interior-only (null control) | 1,644 | 1,644 | **0** | **0** | **0** | **0** | **0** | **0** |

This is the calibration result the battery needed:

- **All three over-prune mutants are caught, and caught by the right lemma.**
  M1's dominant failure is **L3** — in a false eye the opponent genuinely *can*
  play, 1,032 times at 3×3 alone. That is the exact defect the Benson
  certificate exists to prevent, and the exact one a naive implementation
  introduces.
- **M2 is the interesting one.** A two-liberty heuristic looks reasonable and
  passes L1–L4 completely; it is caught **only by L7/L8** — it prunes eyes of
  groups that are not unconditionally alive, so filling can change who ends up
  with unconditional life. Without L7 this battery would have missed M2.
- **M4, the null control, is clean at both sizes** — so the battery is not
  merely flagging any deviation. Its zeroes for the shipped predicate mean
  something.

### §F — the same mutants through the score comparison

The score-based arm can only be run where a tractable baseline exists, so it
uses the **shipped** arm as baseline (the no-prune control is not computable,
§5) and is limited to 2×2/3×2.

| board | mutant | checked | resolved | **detected** |
|---|---|---|---|---|
| 2×2 | all four | 0 | 0 | — (no live pairs at 2×2, §4) |
| 3×2 | M1 naive-eye | 88 | 32 | **0** |
| 3×2 | M2 two-liberty | 64 | 32 | **0** |
| 3×2 | M3 any-alive-neighbour | 48 | 48 | **48 (100 %)** |
| 3×2 | M4 interior-only (null control) | 32 | 0 | 0 |

**The score comparison is the weak instrument, and this is the measurement that
says so.** At 3×2 it catches only the gross mutant. M1 — the canonical wrong
implementation, which §I flags 1,032 times at 3×3 — produces *no score
disagreement at all* on the 32 pairs where both arms resolve. Pruning a move
that is off the optimal line changes nothing about the value, so a value
comparison is blind to it.

This is the same weakness the 2026-07-29 calibration reported as a 22.5 % pass
rate, now attributed to a cause rather than a number: **score equivalence is a
low-power test for this claim, and it is the only test the prior evidence
had.** The lemma battery is what carries the load.

## 8. §G — the ADR's premises, exhaustively, including 4×4

The strong test is uncomputable (§5) and the sound control is coverage-limited
(§6). What *is* exactly checkable per position, with no search at all, is the
set of premises ADR-0006's soundness argument actually rests on. Each is
evaluated for every own true eye of every legal position:

| id | premise | ADR text |
|---|---|---|
| **L1** | the eye fill is a legal move for the mover | (implicit — otherwise the prune removes nothing) |
| **L2** | the area score is invariant under the fill | "does not gain a point … it is yours either way" |
| **L3** | the opponent's play at the eye is **suicide** | "the opponent already cannot play in those eyes" |
| **L4** | the fill captures nothing | (implicit in the dominance argument) |
| **L7** | the fill never **creates** unconditional life for the mover | "only ever *risking* its life" |
| **L8** | the fill never creates unconditional life for the opponent | (not claimed; measured because it would be a real way the move changes the game) |

**Violations, exhaustive enumeration of every legal position:**

| board | eye-positions | eyes checked | L1 | L2 | L3 | L4 | L7 | L8 |
|---|---|---|---|---|---|---|---|---|
| 2×2 | 4 | 8 | 0 | 0 | 0 | 0 | 0 | 0 |
| 3×2 | 60 | 84 | 0 | 0 | 0 | 0 | 0 | 0 |
| 3×3 | 1,050 | 1,414 | 0 | 0 | 0 | 0 | 0 | 0 |
| 4×3 | 16,132 | 24,164 | 0 | 0 | 0 | 0 | 0 | 0 |
| **4×4** | **909,540** | **1,362,424** | **0** | **0** | **0** | **0** | **0** | **0** |
| 5×5 (sampled) | 745,782 | 1,321,127 | 0 | 0 | 0 | 0 | 0 | 0 |

4×4 runs in 9.3 s; the 5×5 row is 20 M random dense draws, 20.0 s.

This is the first evidence for ADR-0006 at 4×4 and 5×5 of any kind. It is
**not** the game-score claim — L1–L8 are the premises, and premises holding does
not make the conclusion true. What it does rule out is every failure mode in
which the prune removes a move that *changes the board's account*: nothing is
captured, no point of area changes hands, the opponent genuinely cannot enter,
and — the load-bearing one — **filling an eye never manufactures unconditional
life**, so the move can never be the mover's uniquely best resource on those
grounds. Combined with the fact that passing is always legal, this is the ADR's
argument made checkable, and it checks out on 1.36 M 4×4 eyes.

Per `AGENTS.md` per-board epistemic independence, each row stands for its own
board size. The 4×4 row is new; it does not inherit from 3×3 and 3×3 does not
inherit from it.

---

## 9. What would still falsify ADR-0006

Ranked by what the battery could not reach:

1. **A ko-sensitive slot where the pruned forward value differs from an
   unpruned bracket.** §6 deliberately excludes `KO_SENSITIVE` slots because
   they hold a bracket, not a value — but that is exactly the region where the
   finisher (which prunes) produces the shipped numbers, and exactly where a
   superko-interaction counterexample would live. The eye fill changes the
   position and therefore the superko history in a way a pass does not; the
   dominance argument in `0006:34-49` is a *scoring* argument and does not
   address that. **This is the open hole.** A targeted experiment: for
   ko-sensitive slots, run the finisher twice, with and without the prune, and
   compare brackets.
2. **A live PRUNE-ALL position on a board larger than 3×3.** §4's argument for
   why the class is absorbed by `is_settled` is a sketch, not a proof. Cheap to
   extend: the class scan at 4×3 and 4×4 costs a single pass.
3. **A 4×4 or 5×5 lemma violation** — the L-battery already covers 4×4
   exhaustively and 5×5 by sampling; exhaustive 5×5 is out of reach (3²⁵).
4. **A divergence between the two predicate implementations on a board shape
   the random sampler misses.** §B is random, not exhaustive.

---

## 10. Recommended register changes

**Do not edit `CLAIMS.md`** (owner's file). Proposed rows for the owner:

```
| `GLOBAL.ADR0006-EYE` | — | all | Forbidding a player from filling its own Benson-alive true eye does not change the game score (weak dominance under area scoring) | CLAIMED | `0006:27-49`; `docs/audits/eye-prune-validation-2026-07-30.md` | `d:GLOBAL.S2`, `d:GLOBAL.S4` | (unchanged) | ? | ? |
| `GLOBAL.ADR0006-PRED` | — | all | The shipped eye-prune predicate fires on genuine eyes of Benson-alive groups and never on false eyes, one-eye groups, big-eye space or opponent eyes; both implementations agree | PROVEN | `eye-prune-validation-2026-07-30.md` §3 (17/17 fixtures; 0/3,999,936 cross-impl mismatches) | `e:GLOBAL.S2` | `GLOBAL.ADR0006-EYE` | 0 | see §7 |
| `GLOBAL.ADR0006-LEMMAS` | — | 2×2/3×2/3×3/4×3/4×4 | The six premises of ADR-0006's soundness argument (fill legal, area invariant, opponent-suicide, no capture, no new life either side) hold for every own true eye | PROVEN (per board listed) | `eye-prune-validation-2026-07-30.md` §8 (0 violations; 1,362,424 eyes at 4×4) | `e:GLOBAL.S2`, `e:GLOBAL.S4` | `GLOBAL.ADR0006-EYE` | 0 | n/a (exact) |
| `GLOBAL.ADR0006-TEST` | — | 2×2/3×2 | The eye-pruned forward search agrees with the unpruned retrograde table on every non-KO_SENSITIVE, non-FROM_FORWARD slot it can resolve | PROVEN (executed 2026-07-30, scoped) | `eye-prune-validation-2026-07-30.md` §6 | `d:GLOBAL.ADR0009-NOEYE` | `GLOBAL.ADR0006-EYE` | 0 | see §7 |
```

`GLOBAL.ADR0006-EYE` should **stay CLAIMED**. Nothing here promotes it: the
score-equivalence claim itself is still unverified on the ko-sensitive region,
which is where its dependents (`GLOBAL.F2`, `GLOBAL.F3`, the shipped
ko-sensitive values) actually consume it.

Two further register notes:

- `docs/evidence/ADR-0006/eye-prune-falsification-2026-07-29.md` should carry an
  **erratum** for the two corrections in §4 and §5: the denominator is 824 live
  pairs, not 1050, and the control arm is not the unpruned game value.
- `GLOBAL.ADR0006-TEST`'s status "PROVEN (as method)" was accurate but had never
  been run. §6 runs it; the row should record the denominator, not just the
  method.

---

## 11. Build / run

```sh
zig build-exe -O ReleaseFast src/eyeprune_battery.zig -femit-bin=./weizigo-eyeprune-battery
tools/runner -- ./weizigo-eyeprune-battery          # everything
tools/runner -- ./weizigo-eyeprune-battery G        # a single section (C D E F G H)
```

Sections A, B, C and G are seconds-to-minutes. D, E, F and H are budget-bounded
and report `unresolved` counts rather than silently truncating.
