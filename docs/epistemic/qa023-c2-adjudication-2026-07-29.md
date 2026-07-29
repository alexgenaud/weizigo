Author: Orchestrator (Opus 5, claude-opus-5[1m]) · Date: 2026-07-29
Status: **RECOMMENDATION to the claim owner.** The Auditor owns claim semantics
and the user owns ruleset adjudication (`ORCHESTRATOR.md` §Role boundaries).
No `CLAIMS.md` row is edited by this file. `EVIDENCE-INTEGRITY` holds that file
and should carry the wording in §5.

# What 2B-PROBE-FIX falsified, what it did not, and why the difference decides the roadmap

`2B-PROBE-FIX` (DSPro) proposes marking **`QA-023` FALSIFIED**. **Do not.** That
label would record something the evidence does not show, on the project's most
load-bearing row. What fell is the **value formula**, not the **state
representation** — and the two have opposite consequences.

## 1. The work is verified

Independently re-run by the Orchestrator from a clean build at HEAD, same seed
and parameters: **45 value-agreements · 20 TIE · 12 disagreements / 77
within-budget · 1,056 budget-exhausted · 0 scratch-overflow · 0 σ-in-arrival
collisions** (1,133/1,133 before the fix). Both defects are fixed, exhaustion and
scratch overflow are now separate counters, `--node-budget` exists, and the
`2B-FIX-KO` ko fix is intact at `:634`.

The first counterexample was also checked by hand, which is the substantive
verification. State `(586,1,6,1)` is `[B,␣,W,␣,B,W]`, White to move, `passes=1`.
On 3×2 (cells 0–2 top, 3–5 bottom) the empty cell 1 touches B(0), W(2), B(4) and
is dame; the empty cell 3 touches only B(0) and B(4) and is Black's. Black: 2
stones + 1 territory = 3. White: 2. **`area_score = +1`, exactly the truncated
value.** White passes out at +1 because Black — the maximiser — prefers +1 to a
TIE=0 repetition and can steer away from cycles. The evaluator is right; the
fixpoint's TIE pin is wrong. This is a real counterexample, not a third defect.

## 2. What is falsified

| claim | recommendation | reason |
|---|---|---|
| **`QA-026`** | **FALSIFIED at 3×2** | It asserts the L/H `converge` machinery is reusable "with loops pinned by `V = median(L, T, H)`". Four states show `median(L,TIE,H) = 0` where the history-conditioned value is +1 or +3. This is precisely the claim's content. |
| **`GLOBAL.LONGCYCLE` / `QA-013`** | **FALSE-AS-SCOPED at 3×2** | "Long cycles under simple ko can be resolved as a loopy-game fixpoint with loops pinned to the tie value." It carried the register's own annotation *"highest design risk in the roadmap"*. It now has a counterexample. **DSPro did not propose this row; it is the one most directly killed.** |
| **`3x2.QA023.B-PROBE`** | **SPLIT: C1 → UNTESTED, C2 → FALSIFIED** | As DSPro proposes. Correct. |
| **`GLOBAL.F2-REMEDY`** | **design partially invalidated** | The median build's *pin rule* is dead. Its other elements (converge on the larger tuple, no finisher, no bracket cuts, no seed inheritance) are untouched. Not FALSE — incomplete, pending a replacement value rule. |

## 3. What is NOT falsified

**`QA-023`, as its `CLAIMS.md` row states it, survives.** The row asserts:

> under basic ko + a fixed-value long-cycle verdict, `(board, side_to_move,
> ko_point, passes)` is a sufficient **Markovian** state for exact solving

C2's failure says `median(L,TIE,H)` does not compute the value. It says nothing
about whether the value is a function of the state. **Every piece of evidence
points the other way:** on all 11 eligible states, every within-budget arrival
history yields the same value — including on the four counterexample states,
where multiple distinct histories all give the same non-zero value. The value
looks like a function of the state; the *algorithm* is what is wrong.

Marking `QA-023` FALSIFIED would tell every future reader the representation is
dead. It is not. What died is a formula on top of it.

**But `QA-023` is not passing either.** Per `2B-3-AUDIT`, the generator misses
the shortest arrival in 93% of states and collects histories sharing ~62% of
their prefixes, so C1 is **UNTESTED-FOR-WANT-OF-CONTRAST** — not unrefuted, not
confirmed. The honest row is *untested*, with the reason recorded.

The reference-semantics §1 restatement — `V(σ|h₁) = V(σ|h₂)` **and** `= median(L,
TIE, H)` — is a **conjunction**, and it is false because its second half is
false. That is a fact about the restatement, not about the state tuple. Any row
citing §1 should be split into its conjuncts rather than marked false whole.

## 4. The consequence is worse than "a formula was wrong"

**F2-REMEDY was attractive precisely because the pin rule was cheap.** EXP-3
settled tractability (reachable `(board, side, ko)` at 4×4 = 177 MB) on the
assumption that two `converge` sweeps plus a pointwise `median` finished the job
— "tens of minutes at 4×4". Remove the pin rule and the tractability estimate
loses its basis. A proper loopy-game solution needs dependency-set machinery
(Kishimoto–Müller, which the project already cites for Track B), and
dependency-set costs are what made PSK intractable in the first place. **C2's
failure therefore re-opens the tractability question EXP-3 was thought to have
closed.** It should not be reported as a contained setback.

**And there is a sharper danger that is cheap to test.** On the counterexample
states, `L < 0 < H` and the truth is +1 or +3 — outside what the median selects
but inside the bracket. If two distinct states share the same `(L, TIE, H)`
triple while having different history-conditioned values, then **no pointwise
function of `(L, TIE, H)` can be correct** — and the failure is not "median is
the wrong choice among candidate pin rules" but "L and H do not carry enough
information to determine the value at all." Every candidate repair dies at once.

That is a decisive, cheap experiment and nobody has run it. Registered as
**`PINRULE-SUFFICIENCY`**.

## 5. Proposed wording for `EVIDENCE-INTEGRITY` (which holds `CLAIMS.md`)

- `QA-026` → **FALSE-AS-SCOPED (3×2)**, cite `docs/evidence/QA-023/probe-fix-2026-07-29.md`
  §4 and this file. Add the four counterexample states.
- `QA-013` / `GLOBAL.LONGCYCLE` → **FALSE-AS-SCOPED (3×2)**, same evidence.
- `QA-023` → **remains CLAIMED**, with the row's evidence column recording that
  the computational half is **split**: C1 UNTESTED-FOR-WANT-OF-CONTRAST (generator
  bias, `2B-3-AUDIT`), C2 FALSIFIED (which is `QA-026`'s content, not this row's).
  **Add an explicit note that C2's falsification is not evidence against this
  row**, so a future reader does not re-derive the wrong conclusion.
- `3x2.QA023.B-PROBE` → **SPLIT** into `…B-PROBE-C1` (UNTESTED) and
  `…B-PROBE-C2` (FALSE-AS-SCOPED at 3×2).
- `GLOBAL.F2-REMEDY` → keep **CLAIMED**, annotate: the `median(L,T,H)` pin rule is
  falsified at 3×2; the design needs a replacement value rule, and its
  tractability estimate is no longer supported (§4).
- `QA-027` (certified fraction 100% "by construction") → unchanged in status, but
  note it inherits `QA-023`, which is now explicitly untested rather than
  presumed.
- Run `bin/weizigo-claimlint` after every edit.

## 6. The fork for the user (ruleset adjudication)

The disagreement is between two *different objects*, and which one is "the rule"
is the user's call, not a bug to fix:

- **First-revisit truncation** (reference-semantics §1) — the game ends the moment
  any state repeats, valued TIE. Closer to how real Go handles repetition. This is
  what the probe measures.
- **The loopy-game L/H fixpoint with a pin rule** — a position-indexed value with
  no notion of "when" a repeat happened. This is what the median build computes.

**Option A — keep truncation as the rule.** Then the median formula is simply
wrong and needs replacing, with the tractability risk in §4. Honest, and it keeps
the ruleset close to real Go.

**Option B — declare the loopy-game value to be the rule.** Then the fixpoint is
correct by definition and the probe was testing against the wrong reference. This
is cheaper but it means the project solves a rule defined by its own algorithm —
exactly the trap that produced the fresh-start-oracle retreat (item 3 in the
`knowledge-ladder.md` relaxation inventory, one of the three nobody decided).

**Recommendation: Option A.** B is how a project ends up perfect at a game
nobody plays. But it is a ruleset decision and belongs to the user, and it should
be recorded in an ADR either way — the milestone's completion condition requires
exactly that.
