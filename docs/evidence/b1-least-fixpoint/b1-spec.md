<!-- RESCUED EVIDENCE -->
> **Provenance header** (added 2026-07-28 by the `docs/evidence/` rescue sweep;
> the body below this rule is verbatim and unedited).
>
> - **Original path:** `untracked/b1-spec.md`
> - **Original mtime:** 2026-07-26T00:14:12
> - **Rescued:** 2026-07-28
> - **sha256 (original, at rescue):** `c4856b74d330a08cc22b20fdf0f73af6f12540be07fa3ea7fb419e5a3b9759f3`
> - **Supports:** `2x2.B1`, `3x2.B1`, `3x3.B1`, `GLOBAL.B1-MULTIFIX`, `GLOBAL.B1-AUDIT` — **method only, not results**
> - **Cited by:** no committed document cites this file by name; it is the surviving *specification* of the `RETRO_B1_LOFIX` probe whose **results** (`untracked/T02-minimax.md`) and **audit** (`untracked/T02-audit-kimi.md`) are CONFIRMED LOST (`docs/status/leak-crisis.md:103-104,180`)
>
> The original in `untracked/` is git-ignored and may be deleted at any time.
> This copy is the durable one. Do not edit the body; append corrections to
> `docs/evidence/README.md` instead.

---

# B1 — Least-fixpoint spec (do NOT implement yet)

**Author:** Minimax, 2026-07-25, per Boss's marching orders
(`untracked/task-minimax.md`).
**Status:** SPEC — T02.1 correction applied 2026-07-25 (Boss caught V1
using oppV1[child] instead of oppV0[child]; the sweep's `m` is shared).
Boss approved implementation per `untracked/T02-minimax.md` (5 §7 answers).
Ready to implement as T02.2.

## 0. Question this answers (the (a) vs (b) survivor)

The E2 finding (3×3: range-aware player leaks, reaching −9 from a root whose
table `lo=2`) leaves two survivors in `status/leak-crisis.md`:

- **(a) C3 is genuinely FALSE** — the `L` fixpoint is a valid fresh-start
  fixpoint but does not bound real-game values. Predicted by the
  cycle-pessimism-vs-PSK-move-removal semantic gap.
- **(b) `converge` is buggy** — `lo=2` is mis-computed; the true least
  fixpoint is ≤ −9 (or wherever the leak's critical ply's `true` actually
  sits).

B1's purpose is to *rule out* (b) on tractable gobans — i.e. confirm that the
canonical `converge` does land at the true least fixpoint of the L map it
applies. It does NOT prove (a) false; even a perfect least-fixpoint
computation would not refute a semantics gap. It is the cheap, decisive half
of the disambiguation.

## 1. The L map (what `sweep(t, &t.lo)` actually computes)

For each (position `P`, side `s`, layer `k`), with `a0 = side=B → lo.b0, side=W → lo.w0`
and `a1 = side=B → lo.b1, side=W → lo.w1`, and `q` = the quad being swept
(here `q = &t.lo`):

```
∀ p ∈ empty(P):
    child = R.pos_from_move(P, s, p)
    cv    = if s==B then q.w0[colex(child)] else q.b0[colex(child)]
    (no kill branch — kill_pct=0 by default)
m       = opt(side)(cv_1, cv_2, ...)              // best child value, side-aware
v1      = opt(side)(m, t.score[i])                // V1 = best move or terminal pass
v0      = opt(side)(m, q.oppV1[i])                // V0 = best move or pass-to-opp-V1
         where q.oppV1[i] = if s==B then q.w1[i] else q.b1[i]
a1[i]   = v1 ;  a0[i] = v0
```

(I verified the source at `src/retro.zig:254–323`, in particular:
`q.w0[ci]`/`q.b0[ci]` on line 292, `v0 = if (maximizing) q.w1[i] else q.b1[i]`
on line 302, `t.score[i]` on line 300. Settled positions are skipped
at the top of the inner loop, line 263.)

**Two equations per (P, s), sharing the same `m`:** Boss correction
(2026-07-25, `untracked/T02-minimax.md`): the sweep computes ONE
`m = max_{p ∈ moves(P,s)} q.oppV0[colex(child)]` and uses it for BOTH
`v0` and `v1` (src/retro.zig:286–311). Verify against source: `cv` is
`q.w0[ci]` / `q.b0[ci]` (line 292) — always the *opponent's V0*. So:

- **V0 (move-or-pass-to-opp-V1):**
  `a0[i] = opt(side)( max_{p ∈ moves(P,s)} q.oppV0[colex(child)] ,
                       q.oppV1[i] )`
  with `q.oppV0` = the *opponent's* V0 column (`q.w0` for B, `q.b0` for W),
  and `q.oppV1[i]` = the *opponent's* V1 at this position (`q.w1[i]` for B,
  `q.b1[i]` for W).

- **V1 (move-or-second-pass):**
  `a1[i] = opt(side)( max_{p ∈ moves(P,s)} q.oppV0[colex(child)] ,
                       t.score[i] )`
  with `q.oppV0` as above (NOT the opponent's V1 — both v0 and v1 share the
  same `m`). `t.score[i] = R.area_score(P)` is the terminal area score
  (a constant; also the value the second consecutive pass forces).

**A genuine least fixpoint of the L map must satisfy both equations at every
(P, s) with `t.legal[i] && !t.settled[i]`.** My prior E3-1 probe checked only
the V0 equation, and only with the V0-vs-V0 max — the V1 equation is the
other half. A fixpoint of the V0 equation alone is not necessarily a
fixpoint of the L map. **Both equations are needed.**

## 2. The fixpoint-equation check (revised E3-1-A)

For every legal, non-settled `(i, s)`:

- **V0:** `t.lo.<s>v0[i]` must equal `opt(s)( max_{p} t.lo.<opp>v0[colex(child)],
  t.lo.<opp>v1[i] )`.
- **V1:** `t.lo.<s>v1[i]` must equal `opt(s)( max_{p} t.lo.<opp>v0[colex(child)],
  t.score[i] )`. (Boss correction 2026-07-25: V1 also reads
  `<opp>v0[child]`, NOT `<opp>v1[child]`. The sweep's `m` is shared.)

(Subscript `<s>` = the column for the side to move: `b` for B, `w` for W.
`<opp>` = opponent's column.)

A failure of either equation proves the stored `lo` is NOT a fixpoint of the
L map. With no other failure mode known, that is positive evidence for (b).

A pass of both equations is consistent with `lo` being a fixpoint of the L
map. It does NOT prove least-ness — that's a separate question (see §3).

## 3. The least-fixpoint check (E3-1-B/C, refined)

The L map is monotone in `q` (every read of `q` is an opt over a finite set
of reads of `q`'s cells; the opt is monotone; everything else is a
constant). Chaotic Gauss-Seidel iteration from a lower bound reaches the
LEAST fixpoint. From an upper bound it reaches the GREATEST fixpoint of the
same map **only if the map is monotone from above** — and the L map *is*:
every read is monotone, and a non-`score` constant `-N` would be monotone
but `score` is a constant too (terminal value), so going downward from `+N`
must drain toward the least fixpoint because the upward-leak paths are
finite (no positive feedback loop in a monotone decreasing iteration).

Concrete check: re-converge from a higher seed and verify the result is
**elementwise ≤** the canonical at every legal position. If any element is
strictly above, the canonical is not a least fixpoint — and either the
canonical is mis-computed (b) or the map is non-monotone (worse).

**Critical: the re-converge must reach `c == 0` (zero-change sweep) before
reading its `lo`**. Otherwise "didn't converge yet" is indistinguishable from
"different fixpoint." In the prior probe I did not confirm this; it's a
real gap. The check is `sweep(t, &t.lo) == 0` immediately after `converge`
returns, OR: read `t.sweeps` and confirm the canonical `sweeps` was reached
plus an additional full-sweep run produced zero changes.

**B-side lower bound is also a check (and was correct in the prior probe).**
Re-converge from `lo=-N+1` (one above the canonical seed `-N`). Same
monotonicity argument: must reach the same least fixpoint. Disagreement
implies the canonical seed is NOT a lower bound on the least fixpoint —
i.e. the canonical is *above* the least fixpoint, which is the smoking gun
for (b).

## 4. Falsifiable acceptance test

This is the contract. Without it, the probe is decoration.

**Setup:** build the canonical converged table with the *current* engine
(`RT.seed` + `RT.converge`; do NOT call `RT.finalize`; the V0/V1 columns
must be read directly from `t.lo`).

**B-side acceptance (least-fixpoint check, decides (b) vs not-(b)):**

- Run the §2 fixpoint-equation check on every legal non-settled position.
  **Acceptance:** zero V0 violations AND zero V1 violations.
- Run the §3 re-converge-from-`-N+1` (lower-bound check) AND from `+N`
  (upper-bound check). **Acceptance:** both re-converges land elementwise at
  the canonical `t.lo` after reaching `c == 0` (zero-change sweep).

**What this decides:**

- **All four acceptances hold → (b) is RULED OUT on this goban.** The
  canonical `converge` lands at the true least fixpoint of the L map.
  Whatever the E2 leak means, it is NOT a `converge` bug. C3's failure
  must be (a) — semantics gap — or some other cause.
- **Any V0 or V1 violation OR any re-converge element above canonical →
  (b) is PLAUSIBLE on this goban.** Record the count, the magnitude, the
  positions. Decide whether to dig into the engine or treat the leak as
  dual-caused.
- **Re-converge fails to reach `c == 0` in `MAX_SWEEPS`** → report and treat
  as inconclusive. The probe must not silently cap.

**Gobans to run:** 2×2 (ground truth), 3×2 (ground truth), 3×3 (the crisis
goban). Do NOT run 4×4 — the 4×4 state space is large and the re-converge
cost will dominate. The 3×3 result is what matters for the crisis; 2×2/3×2
are sanity checks (the canonical fixpoint must be correct on gobans that
have no ko-sensitive region, since the L=H=score on every position).

**A second-decision rule on (a) vs not-(a):** B1 does NOT distinguish (a)
from "some other cause of the E2 leak that isn't a `converge` bug." That's
E3-2's job (direct `true < lo` at a tractable critical ply). B1's role is
narrow: rule out (b) on 2×2/3×2/3×3. If it does, the E2 leak on 3×3 cannot
be cured by fixing `converge`.

## 5. What the probe will look like (shape only — no code yet)

- A new env-gated entry in `pub fn main`, e.g. `RETRO_E3_LOFIX` (name
  TBD with Boss; the prior name collided with the E3-1 that's been
  reverted).
- A function `e3LofixCheck(comptime w, h, gpa)` that:
  1. Builds canonical `t`, runs `seed` + `converge` (NO `finalize`).
  2. §2 check: iterates `0..total`, skips illegal/settled, computes both
     V0 and V1 expected values, compares to stored. Counts violations;
     records up to N exemplars with `(idx, side, stored_v0, expected_v0,
     stored_v1, expected_v1)`.
  3. §3-B check: copies `t.lo`, re-seeds lower columns to `-N+1`, runs
     `converge`, asserts `sweep(t, &t.lo) == 0` after `converge` returns,
     compares elementwise to canonical.
  4. §3-C check: copies `t.lo`, re-seeds upper columns to `+N`, runs
     `converge`, asserts `sweep(t, &t.lo) == 0` after, compares.
  5. Prints a one-line verdict per goban and a per-goban table of violation
     counts.
- Build: `ZIG_GLOBAL_CACHE_DIR=/tmp/weizigo-zigcache
  ZIG_LOCAL_CACHE_DIR=/tmp/weizigo-zigcache zig build-exe -O ReleaseFast
  src/retro.zig -femit-bin=retro-e3-lofix`. (Binary name per Boss's
  namespacing rule `retro-<env>`.)
- Output goes to stdout; no writes to disk beyond the binary.

**Total expected new lines in `src/retro.zig`:** ~180–220 (the prior
E3-1 was ~165; adding the V1 equation and the zero-change assertion
roughly doubles the check density).

**No edits to `docs/`, `AGENTS.md`, or other engine files.** All
write-targets are inside `src/retro.zig` and the build binary.

## 6. Risks and gotchas (so I don't repeat them)

- **Settled positions must be skipped, not just `t.legal[i]`.** Settled
  positions have `a0[i] = a1[i] = t.score[i]` by construction (seed
  branch), but their move-set is empty in the game graph; the Bellman
  equations on them are vacuous. A violation on a settled position is
  meaningless. (Prior probe skipped both, correctly.)
- **The terminal second-pass uses `t.score[i]` (the area score at
  position i, not the area score at the child).** This is the value
  the second consecutive pass forces when the position itself is passed
  to. Easy to misread as "area of child." (I had it right in the prior
  probe via the `score[i]` reference; will re-confirm in the
  implementation.)
- **`t.score[i]` may be 0 (empty goban, no stones) and the area score
  at V1 of empty is 0.** That is correct. The V1 of empty is the
  area score if both players pass from empty — 0. Not a bug.
- **Re-converge from `+N` may be slow on 3×3** if the chaotic iteration
  takes many sweeps. `MAX_SWEEPS = 10_000` is set; the probe must
  detect a cap and report rather than silently running on.
- **Settled positions have `a0 == a1 == t.score[i]` from the seed
  branch.** The Bellman re-apply on a settled position (which `sweep`
  skips) would not change that. No spurious "violation" risk.
- **E2 sanity's `lo=-N`/`hi=+N` is different from the B1-C re-seed
  from `+N`.** The E2 sanity uses a *single* `-N` or `+N` and just runs
  the player; B1-C uses a *full* re-seed of the table to `+N` then
  re-converges the L map. Different beasts.
- **`RT.converge` sweeps BOTH `lo` and `hi` in alternation.** The
  re-converge-from-`-N+1` test must re-seed `lo` to `-N+1` AND leave
  `hi` at its canonical value (don't double-perturb). Same for the
  `+N` re-seed.

## 7. Open questions for Boss (please answer before I implement)

1. **Env-gate name:** keep `RETRO_E3_LOFIX` (matches the prior name) or
   pick a new one (e.g. `RETRO_B1_LOFIX`)? My preference: `RETRO_B1_LOFIX`
   to mark the new task name and avoid confusion with the reverted
   probe. (Both names are gone from the tree; this is a fresh choice.)
2. **Output verbosity:** print all violations (could be ~12,000 on 3×3
   if it goes bad) or cap to ~10 with a "see summary for full count"?
   I lean toward the cap; the spec says "accept zero" so a small
   exemplar is enough to diagnose.
3. **Should the probe ALSO run the same checks against `hi`?** Symmetry
   suggests yes; if `lo` is least then `hi` is greatest by the colour-
   inversion identity, and a violation in `hi` is another (b) signal.
   I lean yes, marginal cost, more evidence.
4. **Should the §3 lower-bound check use `-N+1` or some other "narrowly
   above" seed?** The point is to seed with a *strict* lower bound that
   is NOT the canonical seed. `-N+1` is the obvious choice. Alternative:
   seed with `-N+3` (further from canonical) to stress-test
   convergence. I'll use `-N+1`; `-N+3` adds little.
5. **Pre-acceptance: do you want me to write the probe against the
   *current* `src/retro.zig` or against a specific branch (e.g.
   `glm-boss/e2-e3-docs-baseline`)?** Current main is what I'll work
   from unless you say otherwise. I will NOT touch `retro.zig` until
   you say go on this spec.

## 8. What I will NOT do

- I will not edit `src/retro.zig` until Boss signs off on this spec.
- I will not run `zig build` or `zig test` on a modified tree.
- I will not commit, push, or touch git refs.
- I will not touch `docs/`, `AGENTS.md`, or other engine files.
- I will not delete the existing `retro-e2`/`retro-e3` binaries (per
  `.gitignore` rule, they're gitignored anyway; they were removed by
  GLM-Boss per `uncommitted-review.md`).
- I will not respond to other agents' `CURRENT.md` updates without
  re-reading them; if Kimi posts an edit-intent while I'm working, I
  yield.

## 9. Status line for CURRENT.md (on sign-off)

When Boss says "go," I will:
1. Append to `docs/status/CURRENT.md`: "Minimax: B1 spec approved; editing
   `src/retro.zig` for `RETRO_B1_LOFIX` env gate + `e3LofixCheck`/`runE3B1`
   (est. ~200 lines, est. 15 min wall). Holding per concurrency."
2. Implement, build, run, report to `untracked/b1-results.md`.
3. Append "Minimax: B1 done; results in `untracked/b1-results.md`" to
   `CURRENT.md`.



## 10. Changelog

- **2026-07-25 — T02.1 (Minimax):** Boss correction. §1 V1 equation and
  §2 V1 check now use `oppV0[child]` (not `oppV1[child]`); the sweep's
  `m` is shared between V0 and V1. Without this, the probe would
  manufacture spurious V1 violations (sinking the same way as E3-1).
  Status: corrected; ready for T02.2.
