<!--managent set=A holds=docs/epistemic/CLAIMS.md-->
# T123 — absorb T114's five ADR-0006 rows into the register

**Type:** ANALYSIS + register edit · **Holds:** `docs/epistemic/CLAIMS.md`

## Background

T114 (the eye-prune validation battery, Fable's W1) produced five `CLAIMS.md`
rows **already formatted for insertion** at
`docs/audits/eye-prune-validation-2026-07-30.md:441-445`. None were pasted in.
The T120 absorption audit found this is the largest block of verified,
ready-to-absorb evidence sitting outside the register.

| row | what it records |
|---|---|
| `GLOBAL.ADR0006-EYE` | evidence-column update only |
| `GLOBAL.ADR0006-PRED` | PROVEN — 17/17 fixtures, 0/3,999,936 cross-impl mismatches |
| `GLOBAL.ADR0006-LEMMAS` | PROVEN — six premises, 1,362,424 eyes at 4×4, 0 violations |
| `GLOBAL.ADR0006-TEST` | **status change** — the ADR-0009 standing test was executed for the first time with denominators (4,212 slots, 0 disagreements) |
| `GLOBAL.ADR0006-PRUNEALL` | new self-eye-fill hazard class — 96 live 4×4 pairs, all clean |

`CLAIMS.md:318` still shows `GLOBAL.ADR0006-EYE` with evidence `0006:27-49`;
`AGENTS.md:83-84` only. `:319` still calls `GLOBAL.ADR0006-TEST` "PROVEN (as
method)" with no record that the method was ever run.

## Task

1. Insert the five rows. Verify each against the battery document before
   pasting — you are the second pair of eyes, not a transcription service. If a
   row's numbers do not match its cited section, **stop and report**.
2. T114 also recorded **three corrections to the 2026-07-29 ADR-0006 evidence**:
   the denominator was inflated (226/1050 vacuous), the control arm was unsound
   (memo caches under superko), and the calibration measured the wrong thing.
   Annotate `docs/evidence/ADR-0006/eye-prune-falsification-2026-07-29.md` and
   its `PROVENANCE-` sibling so a reader landing there does not take the
   superseded numbers as current. Do not delete the old numbers — mark them.
3. Run `bin/weizigo-claimlint`. New rows must not add C1a orphans or C2
   dangling paths.

## Do not

Change ADR-0006's status. The battery's verdict is **NOT falsified**, which is
not the same as proven, and `GLOBAL.ADR0006-EYE` stays CLAIMED. Read §7 of the
battery for what remains open.

## Deliverable

Edited `CLAIMS.md`, annotated 2026-07-29 evidence, claimlint output showing no
new failures.
