<!--managent set=A-->
# V-4 — verify-battery M1 harness design

**Gated on:** G1 (human ratification of verify-battery spec pass 1)
**Deliverable:** `docs/epics/E1-markovian/sprints/verify-battery/archive/design-M1.md`

## What to produce

Design the harness: CLI contract, result schema, and artifact loading. This is the interface that all invariant modules (V-6 through V-9) consume.

Must contain:
1. **CLI contract:** invocation, flags, exit codes (three classes per spec R6: pass, fail, reference-bad)
2. **Result schema:** JSON or line protocol, one result per (invariant, goban, artifact) cell. Include denominators, §6a cell coordinates, and proposed-row format for CLAIMS.md absorption
3. **Artifact loading:** per spec R8 (battery imports nothing from `src/`). Load WZO1 and WZO2 artifacts by path + SHA-256 verification

## Read first

- `docs/epics/E1-markovian/sprints/verify-battery/pass0/spec.md` (the ratified spec) — especially §6a (12×5 matrix) and R6/R8
- `docs/epics/E1-markovian/sprints/verify-battery/pass0/plan.md` §P1
- `docs/epics/E1-markovian/sprints/verify-battery/archive/spec-audit.md`
- `docs/epics/E1-markovian/sprints/verify-battery/archive/i5-feasibility.md` (M4 design seed — M4 does NOT wait here)

## Rules

- ANALYSIS — write exactly one new file
- The schema binds V-6 through V-9 — be precise about field names, types, and error contracts
- M4 design does not wait — only M4's output fields bind to this schema

## Acceptance

1. CLI contract stated with all three exit classes
2. Result schema complete enough that V-6 through V-9 can implement against it without clarification
3. Artifact loading path + SHA-256 verification specified
