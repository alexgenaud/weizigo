# ADR-0022 — Bracket resolvers are pluggable and none is authoritative

**Status:** ACCEPTED · **Date:** 2026-08-07 · **By:** deepseek-v4-pro/T402
**Relates to:** ADR-0009 (fixpoint + certification), ADR-0010 (bracket-guided finisher),
ADR-0020 (loopy-game fixpoint semantics), ADR-0021 (PSK-graft as bracket-resolver candidate),
T387/T397 (capture-budget measurement), T401 (bracket tournament)
**Evidence:** `findings/T402-capture-budget-pluggable.json`, `src/resolver.zig` (this row)

## Context

The loopy-game fixpoint table produces exact values where L == H (the fresh-start
single-score region, C1) and honest `[L, H]` brackets where the fixpoint is ambiguous
(the bracket region). Every attempt to convert a bracket into a single score — the
capture budget (T387/T397), first-revisit truncation (ADR-0019, SUPERSEDED), median-pin
(ADR-0019 falsification), the bracket-guided finisher (ADR-0010), the PSK graft
(ADR-0021) — has been measured and found wanting in at least one dimension. No
technique has produced both correct and tractable single scores at 4×4.

The capture budget is the latest and most instructive case, because it passed two
checks that historically sufficed for promotion and still produced the wrong answer:

| check | result |
|---|---|
| termination | 0 back-edges at 3×3 B=8 (423,922 states), 4×3 B=8 (10,636,928) — **VERIFIED as a DAG** |
| Bellman consistency | 0 minimax-identity mismatches across up to 793,619 states — **internally consistent** |
| agreement with true value | 4×3 root oscillates forever in `{0,1,2,7,9,12}`, never equals PSK truth `+4` |

**The lesson, stated once so it does not need to be re-learned per resolver:**

> **Internal consistency is not external agreement.** A self-consistent answer to the
> wrong question is still the wrong answer.

The capture budget defines a different game — finite, well-formed, internally
consistent, and provably wrong as an approximation of ours. The MIGOS `+2` epitaph
is the same class of precedent at a different scale: MIGOS II's 4×4 root is `+2`
under basic-ko rules, while this project's fresh-start fixpoint is `+1` under
positional superko (PSK). The values differ because the rulesets differ — declaring
a basic-ko value as a PSK value is "a different game, declared as one"
(T274, T290). The capture budget repeats the pattern: finite, internally consistent,
and a different game from the one whose bracket it claims to resolve. The worker's
own formulation (T387) is the one to carry forward: **"the budget relocates the
bracket's ambiguity into a budget-exhaustion race instead of resolving it."**

## Decision

### 1. Bracket resolvers are pluggable

A **bracket resolver** is any function that, given a state and its stored `[L, H]`
bracket, returns either a proposed single value or "no opinion." Resolvers are
registered, named, and carry metadata describing their provenance and known limitations.

The interface lives in `src/resolver.zig`. A resolver:

- **may propose** a single value for a bracketed entry;
- **may never overwrite `L` or `H`** — the bracket is the table's ground truth;
- **is never authoritative** — its output is not promoted without independent agreement;
- **must carry registration metadata** describing what is known about its correctness.

### 2. No resolver is authoritative

The honest deliverable remains the fresh-start single-score region (`L == H`) plus
the `[L, H]` bracket. Every resolver is a proposal. Promoting a resolver's output
to the canonical table requires the T401-style independent check — a cross-validation
against a different construction, with a measured denominator and a public witness.

A resolver that disagrees with a certified `L == H` entry is **refuted on the spot**,
and the harness reports that in those words.

### 3. Registered resolvers

The following resolvers are registered in `src/resolver.zig`:

| resolver | behaviour | role |
|---|---|---|
| `none` | always "no opinion" | null control |
| `bracket_low` | propose `L` | baseline: must beat this to be useful |
| `bracket_high` | propose `H` | baseline: symmetric |
| `bracket_mid` | propose `⌊(L+H)/2⌋` | baseline: trivial midpoint |
| `deliberately_wrong` | propose `L - 1` | seeded control: must be caught by L==H agreement |
| `capture_budget(B)` | returns `no_opinion` | the measured resolver; non-convergence recorded in metadata |

**The `capture_budget(B)` resolver** is registered **as a cautionary tale**, not as a
candidate. Its metadata records:

- The 4×3 root oscillates forever in `{0,1,2,7,9,12}` and never equals the PSK truth `+4`.
- At 3×3, `L == H` region preserved only for B ≥ 24; 20,780 of 21,126 L==H entries move at B=0.
- `L < H` values are B-dependent and non-convergent (1,252–1,648 slots drift between B=24/32/48).
- Termination and Bellman consistency were both verified — neither implies correctness.
- **"Internal consistency is not external agreement."**

This registration ensures the budget resolver cannot be adopted by someone who did not
read T387/T397. If a future row wants to implement a budget resolver that actually computes
values, it must first address the measured falsifications.

### 4. Comparison harness with denominator

`src/resolver.zig` includes a comparison harness (`test "resolver comparison harness"`)
that, for a declared position set, reports per resolver:

- **proposed** — count of non-abstentions
- **abstained** — count of "no opinion" returns
- **agrees with L==H** — count of matches where the table is certain (the column that matters)
- **disagrees with L==H** — count of mismatches → **REFUTED** if > 0
- **bracket containment** — proposed value lies within `[L, H]` (for L<H entries)

Every figure carries its denominator.

### 5. Controls

- **Null control:** the `none` resolver proposes nothing and moves no counter.
- **Seeded control:** the `deliberately_wrong` resolver (propose `L - 1`) must be caught by
  the L==H agreement column. The harness shows it firing before any real reading.

## Consequences

- The capture budget is **demoted** from a ruleset candidate to a named, pluggable resolver
  with its non-convergence on the label. It may never supply a value to the canonical table,
  and no promotion may cite it as evidence about `L`, `H`, or a single score.
- Any future bracket-resolving technique must be registered through the same interface and
  pass the same controls before consideration.
- The comparison harness provides the first honest baseline: "always say L" / "always say H"
  / "always say the midpoint." Any resolver that cannot beat these is worth nothing, and
  without the baselines there is no way to see that.
- The invariant is stated once: **a resolver may propose a single score for a bracketed
  entry; it may never overwrite `L`/`H`, and its output is never promoted without
  independent agreement.**
- This row **demotes** a construction rather than advancing one — the operator's call,
  already made, cutting toward keeping the table honest at the cost of the shortcut
  everyone hoped for.

**Landmark:** protects `L2 (proven 4×4 values)` from contamination. The capture budget
is now quarantined behind a named interface with its falsification measurements on the
label. No future table build can accidentally adopt it, and every future resolver proposal
must clear the same bars.
