# S11 STATUS — the only progress surface

**Legend:** `—` not started · `RUN` in flight · `DRAFT` exists, ungraded · `GRADED` audited ·
`ACCEPTED` reconciled and closed. An artifact is complete only at ACCEPTED.

## Phase 1 — design from scratch (blind, parallel)

| artifact | owner | model | state |
|---|---|---|---|
| `phase-1-design/arms/arm-a-design.md` | T857 | ox-alpha | RUN |
| `phase-1-design/arms/arm-b-design.md` | (queued) | deepseek-v4-pro | — |
| `phase-1-design/grade.md` | (queued) | — | — |
| `phase-1-design/reconcile.md` | (queued) | — | — |

## Phase 2 — document what exists (blind, parallel)

| artifact | owner | model | state |
|---|---|---|---|
| `phase-2-whatis/arms/arm-a-whatis.md` | T858 | deepseek-v4-pro | RUN |
| `phase-2-whatis/arms/arm-b-whatis.md` | (queued) | ox-alpha | — |
| `phase-2-whatis/grade.md` | (queued) | — | — |
| `phase-2-whatis/reconcile.md` | (queued) | — | — |

## Phase 3 — compare (converges; first meeting of the two streams)

| artifact | state |
|---|---|
| `phase-3-compare/comparison.md` — should-be vs what-is, both directions | — |
| `phase-3-compare/decisions.md` — keep / adopt / simplify / delete, each with a reason | — |

## Phase 4 — informed spec

| artifact | state |
|---|---|
| `phase-4-spec/spec.md` | — |
| `phase-4-spec/acceptance.md` — test cases written first, expected RED, each with its red evidence | — |
| `phase-4-spec/plan.md` — passes, ordering, landing rules | — |
| `phase-4-spec/audit.md` — independent audit of the three above | — |

## Phase 5 — execute (one subdirectory per pass)

| artifact | state |
|---|---|
| `phase-5-execute/pass-1/{build.md,test-evidence.md,audit.md}` | — |
| further passes minted from `phase-4-spec/plan.md` | — |

## Gate conditions the seat enforces

- No phase-3 work begins until **all four** phase-1 and phase-2 artifacts are ACCEPTED.
- No arm is graded by its own author.
- No acceptance test counts until it has been **shown red** before the change that makes it green.
- A pass that breaks a previously-green check is reverted, not argued.
