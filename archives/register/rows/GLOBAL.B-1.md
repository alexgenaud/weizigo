# `GLOBAL.B-1` — archived register row

**Class:** ARCHAEOLOGY · **Moved:** 2026-08-06 by T373 (triage adoption, `docs/epistemic/register-triage-2026-08-04.md`, Orchestrator ruling 2026-08-05) · **Family:** player

**Epitaph:** Quoted ADR-0013's consequence that the history-perfect genmove inherits the finisher fix — FALSE-AS-SCOPED as of the code — the inheritance assumption was the bug; never assume a player fix follows from an engine fix.

**Move reason (from the triage sheet):** [player] history-perfect genmove inheritance claim — FALSE as of the code at 2026-07-27

**Full register row (verbatim at the time of the move):**

```
| `GLOBAL.B-1` | B-1 | all | ADR-0013's Consequences: "The history-perfect genmove (GTP player) shares this machinery; it inherits the fix automatically" | FALSE-AS-SCOPED (as of the code at 2026-07-27) | `corrections:136-171`; `0013:129-130`; `src/gtp.zig:154-196,90-93,121-132`; `src/artifact.zig:23-53,140,181` | — | any plan assuming a finisher fix improves play | 0 | ? | RETIRED |
```
