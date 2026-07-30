<!--managent set=C-->
# T128 — claimlint fails on evidence debt that is partly discharged

**Type:** ANALYSIS · **Holds:** none (report first; edits are a follow-up)

## The state

`bin/weizigo-claimlint` currently FAILS:

```
C1a orphans / C1b alarms      10 / 0   (FAILS)
C2 dangling evidence paths    11       (FAILS)
C6 cite-tag mismatches         0       (FAILS threshold, currently clean)
calibration                   PASS
```

The C2 set is Fable's W2, the "untracked evidence graveyard" — eight unique
missing paths, reachable from up to 81 register rows each:

```
untracked/B05-glm.md               reachable from 81 rows
untracked/T07-audit-hypotheses.md  reachable from 51 rows
untracked/T02-audit-kimi.md        reachable from 24 rows
untracked/T02-minimax.md           reachable from 24 rows
untracked/T13-minimax.md           + 4 more
```

## Why this is now partly stale

T119's recoverability audit found **3 of 7 "lost" items recoverable from
committed code**, with a clean asymmetry: *code-derived results are
recoverable, human reasoning is not*. And T110 actually recovered the T13 one —
`untracked/T13-minimax.md` was the raw output of a probe whose method survived
in `docs/research/c2-falsification-3x2.md` and whose solver
(`retro.ab_solve`) was committed the whole time. The reproduction now lives at
`docs/evidence/T13/`.

Nobody updated the lint set. So the run fails on at least one path whose
content has since been reconstructed, and the failure count no longer measures
what it claims to measure.

## Task

For each of the eight missing paths, classify against T119's asymmetry:

- **RECOVERED** — content now exists elsewhere in committed form. Give the new
  path; the citing rows should be re-pointed.
- **RECOVERABLE** — code-derived, re-runnable, not yet done. Estimate the cost.
- **LOST** — human reasoning with no committed derivation. Say so plainly; the
  citing rows need their status re-examined, not their citation patched.

Then do the same for the 10 C1a orphans. `CLAIMS-SPLIT-CONJUNCTS` took these
from 14 to 10 by splitting rows that conjoined a live half with a dead one —
check whether the remaining 10 are the same shape or genuinely parentless.

## Do not

Edit `CLAIMS.md` in this task, and do not make the lint pass by deleting
citations. A dangling citation to real lost evidence is information; silencing
it is not a fix. Report, then a follow-up task applies with the register held.

## Deliverable

`docs/evidence/GLOBAL.CLAIMLINT/dangling-triage-<date>.md` — the eight paths
and ten orphans, each classified, each with the rows that reach it and the
recommended disposition.
