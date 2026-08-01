# engine-unification — draft spec (Orcha, input to the sprint)

```
Status: DRAFT — the builder writes the real pass0/spec.md (D-18)
Owner:  Orcha (commissioned internally; Orcha accepts, D-19)
Origin: human directive 2026-08-01 — "modularize, extract, share, test, reuse"
```

## Goal

One tested rule engine, used by everything that claims a result. Every
duplicate implementation kept as a test fixture. Agreement measured **before**
anything is promoted, moved, or deleted.

## Why — measured, not asserted

| | lines | test blocks |
|---|---|---|
| `exp4_solve` + `exp5_solve` + `exp6_solve` | 4,410 | 0 |
| `oracle_v2_build` + `oracle_v2_consumer_load` | 1,068 | 0 |
| core `state`/`rules`/`terminal`/`score`/`superko` | 3,469 | 58 |

Every published number came from the untested rows. The solvers import none of
the tested core; `exp6_solve` reimplements neighbours, capture, legality, area
scoring and pass application under `generic*` names, with separate hand-written
paths per board size. The two artifact writers share exactly two function
names: `lt` and `main`. A pass-encoding error therefore reached a 518 MB 4×4
artifact while 3×3 passed every check — because 3×3 runs different code.

## Method — measure, adjudicate, unify, verify

**Nothing is deleted.** N implementations of one function are N oracles for
each other. One is promoted to production; the rest are demoted to fixtures.
Uncorrelated errors across languages, sizes and authors are the only evidence
we have about our own reliability, and they are unbuyable.

1. **Measure.** Differential harness; agreement matrix per operation per size,
   at every size we can enumerate exhaustively. Disagreements are reported with
   witness inputs, not fixed. Start with double-pass — the most size-invariant
   rule in Go, implemented in at least four places here.
2. **Adjudicate.** Each disagreement gets a ruling and a reason. Some will be
   research questions; escalate those rather than guessing.
3. **Unify.** Promote one implementation per operation. Pure, idempotent
   functions. Callers migrated. TDD for anything new.
4. **Verify.** The same acceptance run at every board size. A test that runs
   only at 4×4 does not exist.

## Scope boundary

In: the rule/scoring/encoding surface and its callers. Out: claims, evidence
and the epistemic tree — the human has sequenced those *after* the code. Out:
new features of any kind.

## Inbox — existing briefs this sprint owns

`untracked/T221` (acceptance check fails open on signal-killed commands —
**do this first; until it lands every verdict in this sprint is worthless**),
`untracked/T222` (evidence stdout may be truncated), `untracked/T223` (the two
encoders; qualifying T193's A5/A3 strength), `untracked/T225` (the differential
harness — the core of pass0). Use them as input; supersede them freely.

## How this sprint runs

**Subdelegate everything.** The human observes at pass boundaries, not phases,
audits or tasks. You own your own audit loops. Concurrency discipline is yours:
two concurrent subagents maximum, disjoint file sets, and no subagent touches
`src/oracle_v2_build.zig` while T212 runs.

**Encode, do not document.** Where a principle can become a check, make it a
check. Prefer deleting prose to adding it. A convention the tooling cannot
enforce is a convention that will rot.

## What reaches the human

A blocker you cannot resolve; a ruling only he can make; evidence that we are
spinning. Not progress reports.
