# PROVENANCE — `QA-021` · FP1 check 3 PASSES exhaustively at 4×4 on the shipped `vb`/`vw` columns

**Author:** minimax-m3/T825 (C3 buckets reconciliation wave)
**Date:** 2026-08-25
**Claim closed:** `QA-021` — "FP1 acceptance check 3 passes **exhaustively** at 4×4 on the shipped
`vb`/`vw` columns: 48,599,962 slots, 422,990 violations, **all** KO_SENSITIVE, **zero** outside,
87 s. Upgrades `4x4.FP1-C3`'s 1:37 sample. Does **not** cover `lo`/`hi` — WZO1 has no bracket
columns."
**Status:** PROVEN — **unchanged by this repoint.**
**Repointed from:** `critique-2026-07-28.md:379; ko-sensitive-chainability.md:109,116` (claimlint
C3 flagged: no path under `docs/evidence/`).

---

## 1. The establishing artifact — verbatim tool output embedded in a committed note

`docs/research/ko-sensitive-chainability.md:74-93` carries the **verbatim** output of the
exhaustive 4×4 chainability run (2026-07-28, 87 seconds), re-run-and-byte-compared the same day
before the section was written. The output is verbatim — the file states "the output above is
verbatim" in the closing line — and reads:

```
bin/weizigo-chainability data/oracle-4x4.checkpoint.wzo --examples 0     # 87 s
  legal, non-settled:   24318165
  settled (exempt):     18184
(position, side) slots checked: 48599962
  violations, full move set:     422990
  violations, eyeprune move set: 422990
  violations under BOTH:         422990   <-- unambiguous
    of which KO_SENSITIVE-flagged: 422990
  max |stored - bellman|:        32 points
  BOTH-violation rate:           0.8704% of all checked slots
KO_SENSITIVE-flagged slots:     10367922 (21.33% of checked)
  violations WITHIN ko-sensitive: 4.08%
  violations OUTSIDE ko-sensitive: 0
verdict: PASS
```

The four numbers that establish the claim:

| line | number | what it proves |
|---|---|---|
| `(position, side) slots checked` | **48,599,962** | the run is exhaustive over the 4×4 reachable (board, side) space (24,318,165 legal positions × 2 sides minus 18,184 settled) |
| `violations under BOTH` | **422,990** | violation count, identical under both the full-move and eye-prune move sets (the disambiguation) |
| `of which KO_SENSITIVE-flagged` | **422,990** | **every** violation is inside the ko-sensitive region |
| `violations OUTSIDE ko-sensitive` | **0** | the load-bearing half of the verdict: zero violations outside the flag |

The third and fourth together establish the proposition — chainability is sound outside the
ko-sensitive region, and the misprice inside it is structural (a fresh-start slot storing an
independent solve is under no obligation to agree with its parent across a history-free edge).

The instrument that produced the run lives at `src/chainability.zig` (HEAD). The exhaustivity
claim — "all 48,599,962 4×4 slots, not a sample" — is stated at
`docs/research/ko-sensitive-chainability.md:109-116` ("**0 out-of-flag violations across all
48,599,962 checked 4×4 slots** (2026-07-28), no longer a sample result").

## 2. The supersession of `4x4.FP1-C3`'s 1:37 sample

The 4×4 chainability result was first measured on a 1:37 sample
(`4x4/EPISTEMIC.md:76-88`); the exhaustive run on 2026-07-28 then confirmed it without exception
(ko-sensitive violations 4.08%, exactly the same fraction as the sample). The exhaustive result
is the load-bearing evidence and is the one this row records. The QA-021 row is the canonical
"exhaustive" reading; the `4x4.FP1-C3` row keeps its 1:37 wording and adds the supersession
edge `e:QA-021` (already on the row since T330, 2026-08-03).

## 3. Scope limit (carried on the row, repeated here)

The run checks the shipped `vb`/`vw` single-value columns. The `lo`/`hi` **bracket-table** form of
FP1 check 3 remains **untested** — WZO1 (ADR-0011) carries no bracket columns. To test the
bracket form, the in-memory L/H tables are needed; no such run exists. The exhaustive run on
`vb`/`vw` does not transfer to `lo`/`hi` mechanically.

## 4. What this note does NOT establish

This note does not re-run the probe; the embedded verbatim is the establishing artifact (the file
itself says so). A re-run would reproduce the same numbers byte-for-byte against the same
artifact; the verbatim record is sufficient.
