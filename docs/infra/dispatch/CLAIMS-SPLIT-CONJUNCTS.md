<!--managent set=V holds=docs/epistemic/CLAIMS.md-->
# CLAIMS-SPLIT-CONJUNCTS — three rows conjoin a live claim with a dead one; split them, don't kill them

**Opened by:** the Orchestrator, from ADR-0019's follow-up list. `EVIDENCE-INTEGRITY` did not cover this (it was added to the ADR after that brief was written). ANALYSIS + register edit.

## The pathology, which the project has now hit three times

`QA-023` nearly got marked FALSIFIED because its `CLAIMS.md` row asserts **state-sufficiency** while the reference-semantics §1 restatement conjoins state-sufficiency **with** a specific value formula. C2 (the formula) fell; C1 (sufficiency) did not; the conjunction is false; and "the conjunction is false" was about to be recorded as "the representation is dead." `2B-6` independently confirmed the distinction (`docs/epistemic/qa023-c2-adjudication-2026-07-29.md`).

**The same conjunction exists in at least three more rows, and promoting `QA-026` / `GLOBAL.LONGCYCLE` to FALSE-AS-SCOPED on 2026-07-29 orphaned all of them** (claimlint C1a: 10 → 14):

| row | the live half | the dead half |
|---|---|---|
| **`GLOBAL.H1`** — the simple-ko pivot | "under simple ko + long-cycle-ties the state `(position, side, ko_point)` is Markovian" | "…and a table over it would be chainable by construction" — depends on `d:GLOBAL.LONGCYCLE`, now FALSE-AS-SCOPED |
| **`QA-011`** | alias of `GLOBAL.H1`, same split | same |
| **`GLOBAL.ONEMISMATCH`** | "the symptoms are consistent with one mismatch: PSK non-Markovian vs a Markovian table" | that the *cure* follows — which assumed the long-cycle fixpoint works. `AUDIT-DSPro` §2.3 also notes it has never been **directly tested** (its test is EXP-4…7, gated) |

`GLOBAL.H1` is **the pivot the whole project direction rests on**. Marking it false would say "the simple-ko direction is dead." That is not what was shown. Leaving it orphaned says nothing at all.

## The task

1. **Split each row into its conjuncts**, as separate register rows with separate statuses and separate edges. Suggested shape (name them as the register's conventions dictate, not necessarily these):
   - `GLOBAL.H1-MARKOV` — the state-sufficiency half. Status **UNTESTED**, and say *why*: `2B-3-AUDIT` showed the history generator misses the shortest arrival in 93% of states with ~62% shared prefixes, so C1 has never been tested with contrasting histories. Cross-reference `QA-023`.
   - `GLOBAL.H1-COMPUTABLE` — the "computable by the existing converge machinery" half. **FALSE-AS-SCOPED (3×2)**, `d:GLOBAL.LONGCYCLE`, citing ADR-0019 and `probe-fix-2026-07-29.md`.
   - Same treatment for `QA-011` (or make it an explicit alias of the split pair) and `GLOBAL.ONEMISMATCH`.
2. **Re-point the inbound edges.** Every row that currently depends on `GLOBAL.H1` must be re-pointed at whichever half it actually needs. This is the substance of the task — a split that leaves dependents aimed at the old ID has achieved nothing.
3. **Resolve the orphans this creates or clears.** Report claimlint C1a before and after, and name every row whose orphan status changes and why.
4. **Do not mark any of the three FALSE whole, and do not upgrade anything.** If the split reveals that a half is better supported than its parent row implied, say so — do not promote it here.
5. **Add the general rule to `CLAIMS.md`'s own conventions section:** a row whose text contains "and" joining two independently-falsifiable assertions is a latent version of this bug. Note that the register cannot lint for it today (it is prose), and that the `knowledge-ladder.md` **rung + rule** columns, if the user ratifies them, would make a related class machine-checkable.

## Acceptance

- Three rows split, statuses assigned per half with citations.
- Inbound edges re-pointed; **zero** rows left depending on a retired conjoined ID.
- `bin/weizigo-claimlint` run, C1a before/after reported, every change explained.
- The convention note added.

## Deliverable

The `CLAIMS.md` edits plus a short note in `docs/status/`. **Holds `docs/epistemic/CLAIMS.md`** — nothing else may hold it concurrently.

**Read first:** `docs/epistemic/qa023-c2-adjudication-2026-07-29.md` §3 (why a conjunction must not be marked false whole), `docs/decisions/0019-*.md`, `docs/status/evidence-integrity-2026-07-29.md`, and the three rows themselves.
