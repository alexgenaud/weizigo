# #2 self-consistency audit — result

Env `RETRO_CONSIST` (3×2, exhaustive) and `RETRO_CONSIST4` (4×4, deepest-N
sample). Built per `next-step-consistency-auditor.md`.

## What it checks

Under one fixed root history `H = [P]`, a sound solver's own outputs must obey
the minimax identity at every node:

    V(P, side, [P])  ==  opt_side( { V(c, -side, [P,c]) : c legal },  pass )

Parent, each board child, and the pass branch (`V(P, -side, [P])` at
`passes = 1`) are each solved as an **independent root** with a freshly
re-seeded per-root memo — so the check compares final exact scores, not the
search's fail-soft internals. A maximizer whose parent score is strictly below
its best option (or a minimizer strictly above) is an **outright proof** of a
bug in that variant. This is exactly the contradiction the replay probe hit
(parent −1 with a +1 child, same position and prefix).

Necessary, not sufficient: passing does not prove correctness (a solver can be
self-consistent at a wrong fixpoint) and it never yields the true score. Use it
to **eliminate** buggy generations and as the standing acceptance test for #3.

## Result — 3×2 (exhaustive, 378 KO_SENSITIVE node/side slots)

| variant | memo_writes | checked | violations | verdict |
|---|---|---|---|---|
| `new` (committed artifact generation) | ON | 378 | **45** | **PROVABLY BUGGY** |
| `soundish` | OFF | 378 | **0** | self-consistent (necessary pass) |

The empty board is among the 45: `new` reports Black-score **−2**, yet its own
best child (solved independently under the same history) is **0** — the
published 3×2 score. White mirrors (+2 vs −1... best option is the child).

## Verdict

This is the spec's "strong evidence" case: **cross-branch bounds-memo writes
are the bug.** Turning them off makes the engine self-consistent everywhere on
3×2.

Why `soundish` is trustworthy beyond mere self-consistency: with writes off,
the only memo entries are the **certified seeds** (history-free `L==H` scores),
and reading those as cutoffs is sound. What remains is plain bracket-guided
alpha-beta over the real positional-superko history along the search path, with
the eye-prune — i.e. the Exact solver minus its ban-set-keyed memo. Its
correctness rests only on the engine's foundational invariants already checked
by the battery: (1) `[L,H]` validly brackets the score under every arrival
history, (2) the eye-prune is sound, (3) certified seeds are history-free. The
bug was never in those — it was the cross-branch **writes** violating
graph-history-interaction.

## Consequences

1. **Correctness through 4×4 is available now** by regenerating every artifact
   with `memo_writes = false`. The committed `data/oracle-4x4.wzo` ko-sensitive region and
   the committed 2×2/3×2/3×3 ko-sensitive region are NOT trustworthy until this is done.
2. **#3 (Kishimoto–Müller dependency-guarded memo)** is therefore a *scaling*
   fix, not a *correctness* fix: it restores safe cross-branch reuse so the
   finisher stays fast at 5×4/5×5, where writes-off may be too slow. Its
   acceptance test is zero violations from this auditor plus bracket
   containment, symmetry, anchors, and Exact agreement on reachable slots.

## Pending

- `RETRO_CONSIST4` (deepest 400 nodes) — confirm the same split holds on 4×4.
- Measure whether a full writes-off 4×4 finish is tractable (it loses the MTD
  bounds-memo speedup); if not, #3 is needed before 4×4 can be regenerated.
