<!--managent set=A-->
# T121 — remove the dead memo from the T13 probe-v2 solver

**Type:** MUTATION (bounded, one function) · **Holds:** `docs/evidence/T13/probe-v2-2026-07-30.py`

## Background

`ab_solve` in `docs/evidence/T13/probe-v2-2026-07-30.py` carries a memo added
after T118 stopped. The T120 absorption audit measured it: **400,001 lookups,
0 hits (0.00000000%)**. The defect is documented in the function's docstring;
read that first.

Two independent reasons it cannot work:

1. The key contains `tuple(history)` — the *ordered* path — which uniquely
   identifies a node of the DFS tree. A node is expanded once. Both call sites
   (`:607`, `:630`) pass `memo=None`, so the dict is per-query as well.
2. It is net cost: an O(depth) tuple construction, a hash and a dict store at
   every node, with the dict growing unbounded for the life of the query. This
   makes the 62-minute non-completion recorded in
   `probe-reimplementation-2026-07-30.md` worse.

And a latent hazard: `best` is **fail-soft**. On the `a >= b` cutoff it is a
bound, not the exact value, and it is stored with no bound flag and no window
in the key. Sharing one memo across queries — the obvious way to get hits —
would return wrong values.

## Task

Remove the memo: the `memo` parameter, the `MEMOSTATS`-free lookup/store, and
the docstring's defect block. Restore the function to plain fail-soft
alpha-beta, which is what the two call sites already execute.

**Do not** attempt to make the memo work. If you believe a sound transposition
table is worth having here, that is a separate proposal with a separate brief:
it needs `(lower, upper)` bound pairs, a key without the ordered history, and
a calibration run against the no-memo values before it may be trusted.

## Acceptance

- `probe-v2-2026-07-30.py` runs and produces values identical to the current
  `memo=None` path on a bounded sample (fresh-start sanity slots are enough —
  do not run the full both-sides enumeration, it exceeds an hour).
- The numbers in `probe-reimplementation-2026-07-30.md` are unchanged. If any
  differ, **stop and report** — that would mean the memo was firing after all
  and the audit's measurement is wrong.

## Deliverable

The edited file, plus a one-paragraph note appended to
`docs/evidence/T13/probe-reimplementation-2026-07-30.md` recording the removal.
