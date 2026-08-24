# S11 STATUS — the only progress surface

**A phase is complete when its single final document exists in `docs/` and carries a grade here.**
`—` not started · `RUN` arms in flight · `ARMS` arms landed, ungraded · `GRADED` audited ·
`ACCEPTED` reconciled, final document written. Anything short of ACCEPTED is incomplete.

## stream1-design — ideal design, blind to the repository

| item | owner | model | state |
|---|---|---|---|
| arm A (untracked) | T857 | ox-alpha | RUN |
| arm B (untracked) | T859 | deepseek-v4-pro | RUN |
| grade (untracked) | — | — | — |
| **`stream1-design/design.md`** | — | — | **—** |

## stream2-whatis — what exists, blind to stream1

| item | owner | model | state |
|---|---|---|---|
| arm A (untracked) | T858 | deepseek-v4-pro | RUN |
| arm B (untracked) | T860 | ox-alpha | RUN |
| grade (untracked) | — | — | — |
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

## Baseline this sprint must move

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
