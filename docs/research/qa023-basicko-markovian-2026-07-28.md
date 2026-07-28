# QA-023 — basic ko + constant tie is Markovian: Part A repaired, reviewed, re-costed

```
Task: EXP-2 Part A (board ID EXP-2; dispatched to this console as "EXP-2A")
Role: worker · Model: Fable 5 (claude-fable-5) · Date: 2026-07-28
```

**Scope.** This document covers **Part A only** (the proof obligation), as
repaired after the Opus audit (`docs/evidence/QA-023/audit-opus-2026-07-28.md`,
verdict UNRESOLVED). Part B (the 3×2 history-sensitivity probe) is **EXP-2B,
pending, owned by another console** — nothing here anticipates its result.
Every claim below is tagged. The proof of record is
`docs/evidence/QA-023/proof-v2-2026-07-28.md` (self-contained; supersedes §4,
§7, §8 of `proof.md` v1).

---

## 1. Findings

### 1.1 The trichotomy is resolved — and the answer is a median, not a pin
**[PROVEN — proof-v2 §3–§5, adversarially reviewed]**

Under basic ko (formalization (i)) + a constant value `T` for infinite play,
with `−n ≤ T ≤ +n`:

```
V(S) = max( L(S), min(T, H(S)) )  =  median( L(S), T, H(S) )
```

where `L`/`H` are ADR-0009's least/greatest Bellman fixpoints computed **on
the new state graph** `(board, side, ko_point, passes)`. The three orderings
the audit demanded (F1) are all argued, on the mechanism *who can trap whom*,
and the audit's "who can force the cycle" question dissolves: no player ever
needs to force a cycle — each needs cycle-*or*-acceptable-terminal, which a
trap (the complement of the opponent's attractor) provides unconditionally.
The attractor computation the audit expected to be additionally required
**is** `L` and `H` themselves: the proof identifies `L` = Black's
forced-termination value and `H` = White's, exactly (proof-v2 Theorem 4.1) —
which also fixes audit F2 by *proving* `true game value = median(f, T, g)`
from first principles (determinacy included, no load-bearing citation) rather
than citing a characterization.

### 1.2 v1's rule "`L < H ⇒ V = T`" is FALSE
**[PROVEN — counterexample, proof-v2 §5.3]**

A four-state graph with `L = 1`, `H = 3`, `T = 0` has true value `1`; v1's
rule returns `0`. v1's rule is correct exactly when `T ∈ [L, H]`. How often
`T ∉ [L, H] ∧ L < H` occurs on real boards is an open empirical number — the
**pin census** (below) that EXP-4/5/6 must now report per board.

### 1.3 The adversarial review (audit F3 closed)
**[Run 2026-07-28; verdict verbatim in proof-v2 §10.1]**

Owner: this console dispatched it (the F3 process defect — passive voice, no
owner — does not recur). Independence condition honored: the reviewer got
only the proof §§1–6, the two foreclosure records, and *"find the flaw;
assume one exists"*; no brief, roadmap, critique, audit, or repo access; zero
tool uses. Caveat recorded: the reviewer is a fresh context of the same model
family as the author, not a different mind.

**Verdict: REPAIRABLE-GAPS — "every theorem as literally stated withstood
attack."** Six findings (2 GAP, 1 MINOR, 3 NIT), all accepted, all repaired
in place, none changing a theorem statement. The two GAPs are genuinely
valuable and are now load-bearing guidance:

- **F1:** first-revisit-truncated *subtree* values are path-dependent — a
  state-keyed memo on the forward evaluator is unsound (the GHI trap, third
  appearance in this project), refuted by the reviewer with the proof's own
  gadget. Generation is unaffected (the fixpoint sweeps need no such cache);
  the EXP-2B probe and any spot-checker must run memo-free.
- **F2:** the rule has **no in-game repetition trigger** — `T` is the value
  of *infinite plays*; the proven-sound evaluator truncates on full
  `(board, side, ko_point, passes)` revisits only. Board-keyed triggers are
  a *different game*, equivalence unproven → new sub-claims QA-023.M1/M2
  (§3 below).

### 1.4 Two v1 defects found outside the audit's list
**[PROVEN — proof-v2 §9.3–§9.4]**

- v1 §4.2 states the H-recurrence with max/min **swapped** relative to
  ADR-0009 (H is the greatest fixpoint of the *same* operator, Black max /
  White min). Any implementation copied from v1 §4.2 would be wrong.
- v1 §5's parity premise ("area score on an odd-point board is always odd")
  is false: area scoring admits neutral regions (`src/rules.zig:125`);
  witness: 3×3 terminal B a1 / W c3 / rest empty (reachable via
  B a1, W c3, pass, pass) scores 0. Consequence: with `T = 0`,
  `V ∈ ℤ ∩ [−n, n]` on **every** board and no sentinel encoding is needed in
  the value column; the A5 ADR should be drafted on the corrected premise.

## 2. Re-cost of the reframe (the audit's direct demand)

The audit warned: if the trichotomy needs a who-can-force-a-cycle
computation, the "one-line post-processing, no engine retraining" story dies,
and the reframe's cost estimate rests on the broken branch. Answer:

| item | verdict |
|---|---|
| One-line post-processing | **Survives, with a different line**: `V = max(L, min(T, H))`, still O(1)/state after the same two sweeps. v1's line was wrong, not expensive. |
| Extra fixpoint / threshold iteration / attractor pass | **None needed** — `L`/`H` *are* the attractor values (Theorem 4.1). |
| Engine reuse | As the roadmap already planned: `converge` re-runs on the **new** state graph. No shipped PSK artifact's L/H columns can be reinterpreted into new-rule values by any post-processing. |
| State space | One real, bounded increase: `passes ∈ {0,1}` joins the solved state. A pass never sets a ko point, so the extra slice is `(board, side, none, passes=1)` — bounded by reachable `(board, side)` pairs. Total < 2× EXP-3's census (< 354 MB at 4×4 vs the 258 MB PSK artifact). EXP-3's dense-addressing GO stands. |
| Forbidden optimization | Forward evaluators under this rule must not memoize truncated values by state (reviewer F1). Costs probe speed only. |
| Docs that must change | `roadmap-2026-07-28.md` §2 ("pinning to that value") and `QA-026`'s wording — both state v1's false rule. Owners: roadmap/CLAIMS owners, not this console. |

**Net: the reframe's cost story survives the repair; what changed is
semantics, not budget.** Per the pre-registration's standing instruction,
this convenient outcome got the extra scrutiny: the review attacked the exact
theorems it rests on and returned "withstood attack" — and the two GAPs it
did find are recorded above rather than smoothed over.

## 3. New/updated sub-claims for the register (one-line statuses for the CLAIMS.md owner — this console edited nothing there)

- `QA-023` — **CLAIMED, Part A repaired+reviewed (was: Part A UNRESOLVED per
  audit).** Proof of record `docs/evidence/QA-023/proof-v2-2026-07-28.md`;
  review verdict REPAIRABLE-GAPS→repaired, verbatim in §10.1. Gate still
  requires EXP-2B (3×2 probe, non-zero cycle census) before any PROVEN mark.
- `QA-026` — **wording FALSE as it stands** (asserts v1's pin rule); corrected
  statement: L/H reusable with `V = max(L, min(T, H))` post-processing.
- `QA-023.M1` (new, UNTESTED) — the rule proven here matches the ruleset of
  the published MIGOS II anchors, including *what their long-cycle verdict
  triggered on*. Must be verified before EXP-5/6 treat anchors as truth.
- `QA-023.M2` (new, UNTESTED) — play-time tie adjudication triggers
  (board-keyed repetition etc.) are value-equal to the infinite-play-valued
  game. Proven only for full-tuple first-revisit truncation (Theorem 6.1).
- v1 §4.2 H-recurrence and v1 §5 parity premise — two recorded v1 defects
  (§1.4) for the errata trail.

## 4. What EXP-4 implements (spec essentials — do not commission separately, per msg 008)

1. State `(board, side, ko_point, passes∈{0,1})`; `passes=2` terminal on the
   fly; `passes=1 ⇒ ko_point=none`.
2. ADR-0009 `converge`: L up from −n, H down from +n, same operator (max/min
   NOT as v1 §4.2 has it), then `V = max(L, min(0, H))` (T = 0 pending the
   user's A3-sub ADR).
3. Report the **pin census**: `|{L<H}|` split by `T<L` / `T∈[L,H]` / `H<T`.
4. Calibration (synthetic): the proof-v2 §5.3 four-state gadget — median rule
   returns 1 (known-good); v1's rule wired in returns 0 and must be caught
   (known-bad). Plus reviewer F1's gadget for any memoized evaluator.
5. Cross-check: 2×2 = 0, not PSK's +1 (necessary, not sufficient).

## 5. What this console could not establish (candour)

- QA-023 overall — needs EXP-2B (empirical (A1) check; the probe design
  notes it must not truncate against the arrival prefix, proof-v2 §6.2).
- QA-023.M1/M2 — need the MIGOS paper and an adjudication ADR respectively.
- A2 (formalization (i) vs (ii)), A3-sub (value of `T`, komi), A5 encoding
  (on the corrected parity premise) — the user's ADRs, flagged not decided.
- Whether the pin census is non-zero anywhere ≤ 4×4 — empirical, EXP-4/5/6.
