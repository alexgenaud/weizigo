<!--managent set=A-->
# O-3 — oracle-v2 M1 format design

**Gated on:** G1 (human ratification of oracle-v2 spec pass 1)
**Deliverable:** `docs/epics/E1-markovian/sprints/oracle-v2/archive/design-M1.md`
**Time box:** ≤ 30 min

## What to produce

Design the WZO2 artifact format. The format is the interface between solver (M2b) and engine (M3) — two agents building concurrently need the same contract.

Must contain:
1. **Key encoding:** `(goban, side, ko)` triples. Passes NOT folded — use EXP-3's count of 51,419,046 `(goban, side, ko)` triples.
2. **Column schema:** L, H, DTT, flags. Store L and H separately (not pinned V) per spec R2.
3. **Header layout:** magic, rules_id, goban size, column count, row count, SHA-256 slot.
4. **F2 byte budget:** derive concrete byte count from key encoding + column schema. > 600 MB → document and flag for re-scope; do NOT proceed to M2b.
5. **Artifact naming convention:** `data/oracle-{goban}-v2.wzo2`
6. **R8 baseline:** inventory of verifier checks the format must support (from verify-battery spec §6a)

## Read first

- `docs/epics/E1-markovian/sprints/oracle-v2/spec.md` (the ratified spec)
- `docs/epics/E1-markovian/sprints/oracle-v2/plan.md` §P1
- `docs/epics/E1-markovian/sprints/oracle-v2/archive/spec-audit.md`
- `docs/epics/E1-markovian/sprints/oracle-v2/archive/spec.md` (frozen pass-0 for context)

## Rules

- ANALYSIS — write exactly one new file, modify nothing else
- Do not start M2b or M3 design — M1 is the format contract, not the solver or engine
- The spec-audit's Q3 answer stands: M1 is NOT parallelised with M2b/M3

## Acceptance

1. Byte budget derived and stated
2. All six items above present and internally consistent
3. The design can be handed to two independent agents (M2b builder, M3 engine) with no further format questions
