# S11 STATUS — the only progress surface

**A phase is complete when its single final document exists in `docs/` and carries a grade here.**
`—` not started · `ACTIVE` a worker is executing it right now · `ARMS` arms landed, ungraded · `GRADED` audited ·
`ACCEPTED` reconciled, final document written. Anything short of ACCEPTED is incomplete.

## stream1-design — ideal design, blind to the repository

| item | owner | model | state |
|---|---|---|---|
| arm A (untracked) | T857 | ox-alpha | **ARMS** — landed; blindness verified objectively (names no file that exists here) |
| arm B (untracked) | T859 | deepseek-v4-pro | **ARMS** — landed |
| grade (untracked) | **awaiting dispatch** — both arms are in | — | — |
| **`stream1-design/design.md`** | — | — | **—** |

## stream2-whatis — what exists, blind to stream1

| item | owner | model | state |
|---|---|---|---|
| arm A (untracked) | T858 | deepseek-v4-pro | **ARMS** — landed, all citations resolve |
| arm B (untracked) | T860 | ox-alpha | **ARMS** — landed (27,743 B); closed on evidence by the seat, worker skipped nonce and close |
| grade (untracked) | **awaiting dispatch** — both arms are in | — | — |
| **`stream2-whatis/whatis.md`** | — | — | **—** |

## stream3-compare — converges 1 and 2

| item | state |
|---|---|
| **`stream3-compare/comparison.md`** — should-be vs what-is, both directions | — |
| **`stream3-compare/decisions.md`** — keep / adopt / simplify / delete, each with a reason | — |

## stream4-fix — phases of the sprint pass

| phase | final document | state |
|---|---|---|
| phase1-spec | `stream4-fix/phase1-spec/spec.md` | — |
| phase2-research | `stream4-fix/phase2-research/research.md` | — |
| phase3-scope | `stream4-fix/phase3-scope/scope.md` | — |
| phase4-design | `stream4-fix/phase4-design/design.md` | — |
| phase5-pass-plan | `stream4-fix/phase5-pass-plan/plan.md` | — |
| phase6-build | `stream4-fix/phase6-build/build.md` | — |
| phase7-accept | `stream4-fix/phase7-accept/acceptance.md` | — |
| phase8-verify | `stream4-fix/phase8-verify/verify.md` | — |

Phases are used as appropriate; one that turns out to be unnecessary is struck with a reason rather
than left blank forever.

## Gates the seat enforces

- **No stream3 work until stream1 and stream2 are both ACCEPTED.** They must not meet before then.
- **No arm is graded by its own author.**
- **No acceptance test counts until it has been shown red** before the change that makes it green.
- **A pass that breaks a previously-green check is reverted, not argued.**
- **A phase whose final document exists but is ungraded is not progress** — it is a draft in the
  wrong directory.

## Baseline — first measurement, from stream2 arm A (T858, deepseek-v4-pro)

Every figure carries a `file:line` citation in the arm, and the author verified each resolves.
**Provisional until arm B corroborates it.**

| # | count | value |
|---|---|---|
| 1 | reporting surfaces inventoried | **30** |
| 2 | surfaces emitting a value where the honest answer is "cannot determine" | **6** |
| 3 | checks that cannot fail under any input | **4** |
| 4 | places that reinterpret unrecognised input as valid | **3** |
| 5 | jobs with more than one implementation | **7** |
| 6 | stated blind spots in the method | **6** |

Two entries stand out and are recorded here so they are not lost in a long document:

- **A standing trigger that can never fire.** Its condition needs a prior value greater than zero, but
  the state parser drops the key that would hold it, so the prior always reads zero after any other
  store write. It is **self-documented in the source** as unable to fire.
- **`managent done --verdict` silently defaults to `pass`.** An unrecognised flag is dropped, so a close
  that meant to record a qualified verdict records an unqualified one. This is the defect the outgoing
  seat hit on its own close, now located at a line.

## Superseded baseline note

Measured 2026-08-24 by a full sweep of every regression script: **23 of 86 fail**. Three carry the
store-census fixture signature; two prior enumerations of that class were both incomplete. Stream2's
final document must turn this into three counts: surfaces that emit a value where the honest answer is
"cannot determine", checks that cannot fail under any input, and places that reinterpret unrecognised
input as something valid.

## Absorption note — work that predates this plan

`T857` and `T858` were dispatched before this hierarchy existed and declare their outputs under
`docs/status/`. Those outputs are **arms, not final documents.** On close, the seat relocates them to
the untracked arm directory and grades them against the acceptance conditions above rather than the
looser briefs they ran under. Their content is informative; their placement is not the plan.

## Honesty note on this file, 2026-08-24

This surface twice misreported its own state within a single session: it carried the label `RUN`, which
can be read as already-run, running, or to-be-run; and it showed two arms as in-flight after both had
closed. Recorded here rather than quietly corrected, because a progress surface that lies is the exact
defect S11 exists to remove, and the sprint's own status file was an instance of it. **The rule now:
every label states a fact about the present, and the file is corrected at the moment a row closes —
not at the next convenient edit.**
