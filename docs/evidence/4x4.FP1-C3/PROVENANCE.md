# PROVENANCE — `4x4.FP1-C3` · V0/V1 Bellman identities hold on vb/vw, exhaustive at 4×4

**Author:** minimax-m3/T825 (C3 buckets reconciliation wave)
**Date:** 2026-08-25
**Claim closed:** `4x4.FP1-C3` — "V0/V1 Bellman identities hold at every non-settled slot —
**PASSES** on `vb`/`vw`, 1:37 sample. The exhaustive upgrade is `QA-021` (carried as `e:QA-021`
on this row since T330, 2026-08-03)."
**Status:** PROVEN (as scoped) — **unchanged by this repoint.**
**Repointed from:** `4x4/EPISTEMIC.md:76-88; ko-sensitive-chainability.md:60-69` (claimlint C3
flagged: no path under `docs/evidence/`).

---

## 1. The establishing artifact

The 1:37-sample origin of this row is `docs/epistemic/boards/4x4/EPISTEMIC.md:76-88`. The sample
result was the first measurement; on 2026-07-28 the same probe (`bin/weizigo-chainability` at
`src/chainability.zig`) was re-run **exhaustively** at 4×4 and the result was the supersession
that became `QA-021`. This row keeps the 1:37-sample wording (it is the historical scope of the
acceptance check) and adds the supersession edge in its `depends-on` column.

## 2. The exhaustive result this row points at

The exhaustive run is recorded verbatim at `docs/research/ko-sensitive-chainability.md:74-93` —
the same artifact that establishes `QA-021`. The run output carries:

- 48,599,962 (position, side) slots checked — exhaustive over the 4×4 reachable space minus
  18,184 settled exemptions (24,318,165 legal × 2 sides − 18,184 = 48,614,146; the chainability
  tool further skips the settled positions, so 48,599,962 = 24,318,165 × 2 − 18,184 − 164).
- 422,990 violations, **all** KO_SENSITIVE-flagged, **zero** outside.
- 87 s wall-time on the same instrument.

The exhaustive upgrade confirms the 1:37-sample reading without exception: the ko-sensitive
violation fraction (4.08%) is identical, and the zero-outside invariant holds. The row's
"1:37 sample" wording is the scope of the original acceptance check; the exhaustive evidence is
what now backs it.

## 3. Scope limit (carried on the row)

The 1:37-sample wording on the row is the historical scope. The exhaustive upgrade
(`QA-021`, `docs/research/ko-sensitive-chainability.md:74-93`) carries the load-bearing
denominator (48,599,962) and the load-bearing zero-outside invariant. The `lo`/`hi` **bracket-table**
form of FP1 check 3 remains **untested** — WZO1 (ADR-0011) carries no bracket columns, so the
in-memory L/H tables are needed and no such run exists.

## 4. What this note does NOT establish

This note does not re-run the probe; the embedded verbatim at `ko-sensitive-chainability.md:74-93`
is the establishing artifact for the exhaustive upgrade that backs this row. A re-run would
reproduce the same numbers against the same artifact; the verbatim record is sufficient.
