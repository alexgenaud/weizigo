# INDEX — claim-to-task cross-reference (generated)

Task: INDEX-RETRIEVAL · Role: worker · Model: DSPro · Date: 2026-07-29

**Generated from `docs/infra/dispatch/*.md` briefs and `docs/epistemic/CLAIMS.md`.**
Reproduce by running `./bin/managent status` and scanning dispatch briefs.

Each entry maps a claim ID to the task(s) that close it, bear on it, or
produced its evidence. Status is from the kanban (`./bin/managent status`).

---

## Claim → task mapping

| claim ID | task(s) | task status | relationship |
|---|---|---|---|
| `QA-023` | EXP-2, 2B-0…2B-6, 2B-FIX-KO, 2B-PROBE-FIX, PINRULE-SUFFICIENCY, QA023-C1-WITNESS, QA023-KERNEL-AUDIT | mixed (most done; QA023-C1-WITNESS in-progress) | closes / bears on |
| `QA-026` | EXP-4 (2×2/3×2), EXP-5 (3×3), EXP-6 (4×4) | blocked | closes (scoped to each board) |
| `QA-027` | EXP-7 | blocked | closes |
| `QA-012` | EXP-8 | blocked | closes |
| `QA-024` | EXP-1 (legality), EXP-8 (value) | done / blocked | supplies halves |
| `QA-002` | EXP-9 | done | bears on (stop-gap) |
| `QA-018` / `QA-019` | EXP-10, QA-018-REVIEW-A/B/C, QA-018-RULING | done / done / dispatchable | closes |
| `QA-025` | (none directly; EXP-5 corroborates) | blocked | corroborates |
| `GLOBAL.H1-CENSUS` | EXP-3 | done | closes |
| `GLOBAL.ADR0006-EYE` | ADR0006-FALSIFY | done | bears on |
| `GLOBAL.F2` | F2-REMEDY, EXP-10, QA-018-REVIEW-A/B/C | done / done / done | bears on (F2-REMEDY designs; EXP-10 tried to un-orphan) |
| `GLOBAL.ONEMISMATCH` | (none directly) | — | diagnostic only |
| `GLOBAL.H5a` | EXP-9 | done | implements the mitigation |
| `GLOBAL.H4b` | QA-021 | done (via claimlint sweep) | discharges |
| `3x2.QA023.B-VACUITY` | 2B-2, 2B-6 | done / done | closes |
| `3x2.QA023.B-PROBE` | 2B-4, 2B-PROBE-FIX | done / done | closes |
| `3x2.QA023.B-CAL-NEG` | 2B-5 | done | closes |
| `3x2.QA023.B-CAL-POS` | 2B-5 | done | closes |
| `4x4.COMPLETE-2026-07-21` | (none — retracted) | — | retracted |
| `GLOBAL.REFRAME` | AUDIT-DSPro, EVIDENCE-INTEGRITY | done / done | audits the reframe premises |
| `3x2.T13` | (none — historical) | — | evidence lost (`untracked/`); durable summary in git |
| `2x2.B1` / `3x2.B1` / `3x3.B1` | (none — historical) | — | evidence lost (`untracked/`); summary in `leak-crisis.md` |
| `GLOBAL.H1-MARKOV` / `GLOBAL.H1-COMPUTABLE` | CLAIMS-SPLIT-CONJUNCTS, EXP-2B, 2B-PROBE-FIX, PINRULE-SUFFICIENCY | CLAIMS-SPLIT in-progress; others done | split / closes |
| `GLOBAL.ONEMISMATCH-DIAG` / `GLOBAL.ONEMISMATCH-CURE` | CLAIMS-SPLIT-CONJUNCTS | in-progress | split |
| `GLOBAL.LONGCYCLE` | PINRULE-SUFFICIENCY, QA023-KERNEL-AUDIT | done / done | falsified at 3×2 |
| `GLOBAL.CLAIMLINT` | EXP-13-claimlint-rerun | (not on kanban) | rerun |
| `GLOBAL.CORRECTIONS` | EXP-14-corrections-cross-check | (not on kanban) | cross-check |
| `GLOBAL.DENOMINATORS` | EXP-12-denominator-sweep | (not on kanban) | sweep |
| `GLOBAL.HYPOTHESES` | EXP-15-hypotheses-reality-check | (not on kanban) | reality-check |
| `GLOBAL.SESSION-CHOOSE` | EXP-16-session-choose-audit | (not on kanban) | audit |

---

## Tasks with no direct claim closure

Some tasks are infrastructure, cleanup, or routing:

| task | purpose |
|---|---|
| INDEX-RETRIEVAL | this index |
| NARRATIVE-LAYER | human-readable through-line from the claim tree |
| MANAGENT-DERIVE-STATUS | kanban status derivation |
| ORCHA-AUTOMATION | Orchestrator automation |
| AGENT-IDENTITY | agent identity scheme |
| WORKER-CHANNEL | cross-agent communication channel |
| RUNNER-CEILING | `tools/runner` memory ceiling |
| ROLE-NAMES | role naming conventions |
| STREAM-DISCIPLINE | stream discipline rules |
| REFERENCES | bibliography |

---

## Kanban summary (2026-07-29)

From `./bin/managent status`:

- **dispatchable (5):** CLAIMS-SPLIT-CONJUNCTS, NARRATIVE-LAYER, ORCHA-AUTOMATION, ROLE-NAMES, STREAM-DISCIPLINE
- **in-progress (3):** F1-CENSUS-GAP, INDEX-RETRIEVAL, QA023-C1-WITNESS
- **blocked (6):** AGENT-IDENTITY, EXP-4, EXP-5, EXP-6, EXP-7, WORKER-CHANNEL
- **done (22):** 2B-0…2B-6, 2B-FIX-KO, 2B-PROBE-FIX, ADR0006-FALSIFY, AUDIT-DSPro, AUDIT-REF-DSPro, EVIDENCE-INTEGRITY, F1-SEEDROOTS, MANAGENT-DERIVE-STATUS, PINRULE-SUFFICIENCY, QA023-KERNEL-AUDIT, REFERENCES, RUNNER-CEILING, EXP-9
- **failed (1):** EXP-2B
