# Concept-inventory — the cross-size claim-types

Definitions only. No status — status lives in each goban's `EPISTEMIC.md`.
These are the fact-topics every goban-size tree must address. Mined from the
project's failures (each was assumed-true at one size and broke at another).

## Structural (S) — the engine is correct

- **S1** colex bijection collision-free. Prove: exhaustive round-trip at size.
- **S2** Benson-alive **theorem** holds (goban-structure; inherits to
  every size) — distinct from **S2-impl**, the `rules.zig` *implementation*
  regression check, which must be re-falsified at each size.
- **S3** rules kernel correct. **Split into sub-claims `[T07-1]`:**
  - **S3a** move/capture/suicide kernel — what OEIS A094777 attests (legal
    position count). Prove: cross-validation + OEIS.
  - **S3b** ko-legality under history — the load-bearing sub-claim that
    separates "legal position count" from "legal (position, history) pair
    count"; the structural reason R1 holds. Prove per size; not attested by
    OEIS.
- **S4** area scoring correct. Prove: cross-validation + manual replay at
    size. (Currently `⬜ᴵᴺᴴ` at 4×4 — see `boards/4x4/EPISTEMIC.md`.)

## Fixpoint (FP) — the table is a genuine fixpoint

- **FP1** L is least, H is greatest fixpoint of the Bellman map (Knaster-Tarski).
  Prove: V0 AND V1 Bellman equations hold (zero violations) AND iteration
  was seeded from the lattice bottom (`-N`) for L / top (`+N`) for H AND
  final sweep hit zero change. **The re-converge-from-`+N`/`-N+1` check is
  NOT a least-ness witness** — it is a multi-fixpointedness observation and
  does not belong in FP1 acceptance `[T07-4]`.**
- **FP2** where L==H, the score is history-independent. **ADR-0009 honesty
  clause — explicitly NOT a theorem.** Split `[T07-7, T07-10]`:
  - **FP2-bounded / C2-bounded** — history-independence under a *finite,
    well-specified* set of ban sets per sampled position. Testable by the
    C2-probe (exact solver, varied ban sets). **FALSIFIED at 3×2 (T13,
    2026-07-26).** The 4×4 deliverable no longer rests on C2-bounded.
  - **FP2-general / C2-general** — history-independence under *any* past or
    future repetition, including arbitrarily long capture histories the
    table has no representation of. Possibly **unprovable by finite
    methods**; now **moot for the deliverable** since C2-bounded is false;
    remains a research question about whether any finite-history
    representation could restore a history-independence claim.
- **FP3** iteration converges in finite sweeps **(the theorem)** — the
  lattice argument that the Bellman iteration terminates. Prove: monotone
  map on a finite lattice (structural; the sweep *count* is a measurement,
  M2, not the theorem) `[T07-3]`.

## Value-correctness (C) — the crisis claims

- **C1** fresh-start scores correct as fresh-start scores. Prove: exhaustive
  comparison vs independent exact solver. (At 4×4, fold into the C2-probe
  harness: empty-history exact score vs `lo[i,side]` for L==H positions.)
- **C2** single-score (L==H) positions are history-independent. (= FP2.)
  **Falsified at 3×2 by T13 (2026-07-26); untested at 4×4.** Use
  C2-bounded vs C2-general above; the prior single-label "C2" conflated
  them `[T07-7]`.
- **C3** bracket [L,H] bounds real-game score for any history. Prove: range-
  aware player zero leaks. Falsify: one valid game outside [L,H]. At 4×4 this
  is **falsified at 3×3 by analogy-expected falsified at 4×4** — NOT an open
  hypothesis; the deliverable decision does not wait on a 4×4 C3 run
  `[T07-5]`.
- **C4** fresh-start == real-game. (FALSE for ko-sensitive by construction;
  TRUE for single-score only if C2-bounded holds.)

## Per-goban epistemic independence

**Each goban size is its own epistemic universe.** A claim that is PROVEN,
CLAIMED, or FALSE-AS-SCOPED at one size is **not** evidence for the same
status at any other size. There is no monotonicity theorem that lets a 2×2
result imply anything about 3×2, or a 3×2 result imply anything about 3×3 or
4×4.

This is why every goban size needs its own epistemic record:
- `docs/boards/<size>/EPISTEMIC.md` for the active sizes (currently 4×4).
- `docs/status/leak-crisis.md` for the cross-size crisis claims and their
  per-goban status.
- Task outputs in `untracked/` for the exact evidence at each size.

When a subagent reports a result, it must state the goban size explicitly
and avoid phrases like "this suggests X at larger gobans" unless a
monotonicity theorem is supplied. The Boss will reject any such inference.

## The user's unbounded-history worry (recorded verbatim, not resolved) `[T07-7, T07-10]`

> I am not convinced there is a distinction between single-score range and a
> bracketed ko-sensitive range. If we do not forbid nor declare winner on
> huge army death or if we allow numerous passes or we allow arbitrary
> handicap count and stone-placement, then any goban could have repeated in
> the past or future. Thus I assume (unproven yet unfalsified) every single
> goban state (position) could have been seen before — which is the same as
> saying "could be seen again in the future". Otherwise, can we prove that
> single-score range could never have repeated before or after? Or that
> repetition has no impact on the score? And I should be careful: whether
> THIS position can repeat is not even the issue, but rather whether any
> PREVIOUS or FUTURE position BEFORE or AFTER THIS position could repeat. On
> a sufficiently large goban any repetition could have happened without trace
> (the eyes could have been filled and the blob army destroyed and
> repopulated).

This is **C2-general**, not C2-bounded. T13 (2026-07-26) falsified
C2-bounded at 3×2, so the worry is no longer hypothetical for the
deliverable: the table's single-score region is *not* history-independent
under reachable PSK histories. The fresh-start reframe (B05,
`untracked/B05-glm.md`) accepts this as a permanent property of the table,
not a bug to fix. C2-general remains a separate research question.

## Finisher/engine (F)

- **F1** writes-on finisher (ko_ref guard) sound. (Falsified at 3×2; ADR-0013.)
- **F2** bracket-guided finisher (ADR-0010) sound. Prove: auditor +
  containment **on a writes-off regenerated artifact** (not the committed
  one, which uses the unsound `ko_ref >= d` guard) `[T07-6]`.
- **F3** writes-off (soundish) sound. Prove: #2 auditor zero violations **on
  a writes-off regenerated artifact** (same pre-condition as F2; auditor on
  the committed artifact is a falsification test for the committed
  artifact, not a validation of writes-off) `[T07-6]`.
- **F4** KM dependency-guarded memo sound. Prove: auditor + byte-identical
  to F3's writes-off regen. The KM regen and the writes-off regen cannot
  run in parallel (same disk; AGENTS.md no-silent-write) `[T07-8]`.

## Play (P)

- **P1** anchor match implies real-game correctness. (FALSE for ko-sensitive.)
- **P2** symmetry PASS implies correctness. (Necessary, not sufficient.)
- **P3** fresh-start player plays real-game score. (FALSE — the leak.)

## Ruleset (R) — settled foreclosures, instantiated per size

- **R1** PSK exact-solve intractable. **R2** score-on-cycle = PSK intractability.
- **R3** kill-X% does not collapse ko-sensitive region.

## Measured (M) — data, not knowledge

- **M1** ko-sensitive fraction. **M2** sweep count (the measurement; FP3 is
  the theorem). **M3** finisher node cost.

## Dependency structure

```
fresh-start-single-score ──► C2-bounded ──► FP2-bounded  [FALSIFIED at 3×2 (T13) — single point of failure, now broken]
C2-general            ─► [possibly unprovable by finite methods; research, not deliverable]
bracket-sound ────────► C3 ──► FP1, FP2-bounded   [C3 falsified at 3×3; analogy-expected at 4×4]
finisher-sound ───────► F2 ──► F3, FP2-bounded    [F2/F3 need writes-off regen, not the committed artifact]
fresh-start-correct ──► C1 ──► [needs independent exact solver; fold into C2-probe at 4×4]
```
