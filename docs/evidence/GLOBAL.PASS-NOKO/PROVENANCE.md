# PROVENANCE — `GLOBAL.PASS-NOKO` · pass ⇒ no ko point

**Author:** deepseek-v4-pro/T901 (repoint wave)
**Date:** 2026-08-24
**Claim closed:** `GLOBAL.PASS-NOKO` — structural invariant of the basic-ko state graph:
`passes ≥ 1 ⇒ ko_point = none`; the solver encodes every pass child with `KO_NONE` directly.
**Status:** PROVEN (code + independent re-derivation) — **unchanged by this repoint.**
**Acceptance criterion:** a committed note pinning the committed encoding and the one-line
argument (a pass captures nothing), per `docs/epistemic/c3-evidence-triage.md` §3 row 5.

---

## 1. The committed encoding

`src/exp6_solve.zig` (HEAD, around lines 925–927) encodes the pass child as:

```zig
// Pass
const pass_enc = encodeState4(board_idx, 1 - side, KO_NONE4, passes + 1);
```

The `KO_NONE4` argument is the literal none-sentinel for the ko slot: a pass child is
written with ko = none, unconditionally. The register's pinned location
`src/exp6_solve.zig:964` at commit `082433e` is reachable — `git show 082433e` yields the
identical `// Pass` / `encodeState4(..., KO_NONE4, ...)` block (the `KO_NONE4` pass-child
encoding is unchanged since that pin).

## 2. Why the invariant is structural, not empirical

A pass changes nothing on the goban and captures nothing. The ko point of a state is
defined as the single point where the opponent could recapture the stone that was *just*
captured on the previous move. After a pass there is no just-captured stone, so there is
no ko point to record; the only consistent encoding is `ko = none`. The state graph's
`passes ≥ 1` slot set therefore carries no ko column (the bounded ≤ 36-entries-per-group
bound in the WZO2 segregated index follows from exactly this), and pass edges are strictly
monotone in `passes`, so a pass edge cannot close a cycle.

## 3. Scope limits

This note establishes the *invariant and its encoding*, not any downstream use of it
(the WZO2 group-index sizing, verify-battery I5's node count) — those have their own rows.
The register row's second clause ("independently re-derived in the oracle-v2 M1 design
re-audit, T146") is carried by the canonical design document cited in that row, not by
this note.
