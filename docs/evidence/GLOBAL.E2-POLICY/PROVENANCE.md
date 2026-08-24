# PROVENANCE — `GLOBAL.E2-POLICY` · the range-aware policy convention

**Author:** deepseek-v4-pro/T901 (repoint wave)
**Date:** 2026-08-24
**Claim closed:** `GLOBAL.E2-POLICY` — correct range-aware policy: Black maximizes `lo[child]`,
White minimizes `hi[child]`; the first run used `lo` for both and was wrong.
**Status:** PROVEN (bug + fix) — **unchanged by this repoint.**
**Acceptance criterion:** a committed note pinning both halves — the operative convention in
committed code and the historical lo/lo half in committed prose — per
`docs/epistemic/c3-evidence-triage.md` §3 row 10.

---

## 1. The operative convention (committed code)

`src/retro.zig`, the E2 range-aware self-play path (`e2Board`):

- move children (line ~3968): `vals[cnt] = if (side > 0) t.lo.w0[ci] else t.hi.b0[ci];`
  — Black (`side > 0`) reads the **lo** table, White reads the **hi** table.
- pass child (line ~3953): `if (side > 0) t.lo.w1[idx] else t.hi.b1[idx]` — same split.
- selection (lines ~3971–3973): `const maximizing = side > 0; … if (if (maximizing) v > best
  else v < best) best = v;` — Black maximizes, White minimizes.

Together: Black maximizes `lo[child]`, White minimizes `hi[child]`. (The stale doc comment at
`src/retro.zig:3758-3759` still says "White minimizes lo[child]" — that comment describes the
*old, wrong* policy and is the bug the claim is about; the *code* is the fixed convention.)

## 2. The historical lo/lo half (committed prose)

`docs/status/leak-crisis.md:81-83` records the fix history verbatim:

> E2 policy correctness (recorded): Black maximizes `lo[child]`; White minimizes `hi[child]`.
> The first run used `lo` for both colours — wrong for White (minimizer secures its ceiling
> `hi`, not its floor `lo`). Fixed.

## 3. Scope limits

This row establishes the *policy convention and its fix*, not the leak result itself
(`3x3.C3` / `3x3.E2-RUN1/RUN2`, which are separate rows) and not the soundness of the
range-aware policy (which `3x3.C3` falsified). This note pins the convention; it says nothing
about whether a range-aware player is leak-free.
