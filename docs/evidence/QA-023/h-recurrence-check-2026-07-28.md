# EXP-11 — H-recurrence swap check (code vs ADR-0009 vs QA-023 v1/v2)

**Date:** 2026-07-28 · **Task:** EXP-11 · **Worker model:** Kimi-k3 · **Kind:** ANALYSIS (no holds)

**VERDICT: "v1 transcription error only, code is correct."** `src/retro.zig`
implements H as the *greatest* fixpoint of the *same* Bellman operator used
for L — exactly ADR-0009's specification. The max/min swap exists only in
QA-023 proof v1 §4.2; it never propagated into the engine. No code change
proposed; nothing to ship.

## How the code is structured (why the swap *cannot* hide in it)

There is exactly **one** Bellman update in the engine, `Tables.sweep`, and
`converge` applies it to **both** tables in the same loop:

- `src/retro.zig:329` — `const c = sweep(t, &t.lo) + sweep(t, &t.hi);`

The operator is side-keyed, identical for both quads:

- `src/retro.zig:194-196` —
  `fn opt(comptime maximizing: bool, a: i8, b: i8) i8 { return if (maximizing) @max(a, b) else @min(a, b); }`
- `src/retro.zig:266` — `const maximizing = comptime (side > 0);` (Black
  maximises, White minimises, in both L and H sweeps)
- `src/retro.zig:292` — child value `if (maximizing) q.w0[ci] else q.b0[ci]`
- `src/retro.zig:302-305` — pass alternatives
  `var v0: i8 = if (maximizing) q.w1[i] else q.b1[i]; … v1 = opt(maximizing, m, v1); v0 = opt(maximizing, m, v0);`

L vs H differ **only in the seed**, not in the recurrence:

- `src/retro.zig:238` — `inline for (.{ .{ &t.lo, -N }, .{ &t.hi, N } }) |pair|`
  (non-terminals: `lo` seeded −N → monotone ascent to the least fixpoint;
  `hi` seeded +N → monotone descent to the greatest fixpoint; terminals
  seeded to `score` in both, `src/retro.zig:228-235`).

The lean core-census path is byte-equivalent and equally unswapped: the
single `coreSweep` (`src/retro.zig:1940-1998`; `maximizing = comptime (side > 0)`
at `:1965`, `@max`/`@min` at `:1975,:1980-1981`) is called on **both** the
L quad (seeded −N, `:2061-2064`) and the H quad (seeded +N, `:2065-2068`)
from `coreCensus` (`src/retro.zig:2075-2078`).

## The spec — ADR-0009

`docs/decisions/0009-retrograde-value-iteration.md`, §"The graph model":
`opt_s` = max for Black (s>0), min for White — one operator. §"Decision 2":

- "**L (pessimistic)**: all non-terminals seeded −n … swept monotonically UP
  to the least fixpoint."
- "**H (optimistic)**: seeded +n, swept DOWN to the greatest fixpoint: every
  cycle scored maximally pro-Black."

i.e. H = greatest fixpoint of the **same** operator. The code matches.

## The proof side — v1 §4.2 (swap) and v2 (swap noted)

v1 `docs/evidence/QA-023/proof.md` §4.2 (line 255 ff.), "**H iteration**":
`side(S) = Black:  H(S) = min_{m} H(succ)` / `side(S) = White: H(S) = max_{m}
H(succ)` — max/min **swapped** relative to its own L iteration and to
ADR-0009.

v2 `docs/evidence/QA-023/proof-v2-2026-07-28.md` confirms the swap is a
v1-only defect:

- §4.1 (line 246 ff.): "This is exactly ADR-0009's `converge` (L seeded −n
  swept up, H seeded +n swept down, **same operator, Black max / White min
  in both**). ⚠️ v1 §4.2 stated the H recurrence with max/min **swapped** …
  that is a transcription error against ADR-0009 and against what H must be;
  recorded in §9.3 so no implementer copies it."
- §9, item 3 (line 527 ff.): "**v1 §4.2 defect (recorded, superseded):**
  H-recurrence stated with max/min swapped relative to ADR-0009's
  greatest-fixpoint-of-the-same-operator. Any implementation copied from v1
  §4.2 would be wrong."

(Pointer note for the record: the EXP-11 brief cited "v2 §1.4 and §9.3"; v2
has no §1.4 — the note lives at §4.1 and §9 item 3. Substance unaffected.)

## Conclusion

The swap is confined to the superseded v1 proof document. The engine
computes L and H with one shared, correctly-oriented Bellman operator,
distinguished only by seed (−N / +N) and hence by fixpoint extremality
(least / greatest), matching ADR-0009 character-for-character. No fix to
propose; no engine file touched.
