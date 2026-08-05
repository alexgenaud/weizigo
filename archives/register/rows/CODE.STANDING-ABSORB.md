# `CODE.STANDING-ABSORB` — archived register row

**Class:** NOTE · **Moved:** 2026-08-06 by T373 (triage adoption, `docs/epistemic/register-triage-2026-08-04.md`, Orchestrator ruling 2026-08-05) · **Family:** process

**Epitaph:** Recorded the absorption-backlog standing trigger (T294) — infra mechanism, verified with controls — its home is the managent code and tests; the register row duplicated it as a claim-shaped note.

**Move reason (from the triage sheet):** infra mechanism record (T294) — the standing trigger is described and verified, but it is infra, not a claim about Z; home is docs/infra/

**Full register row (verbatim at the time of the move):**

```
| `CODE.STANDING-ABSORB` | — | n/a | **The absorption backlog is a standing trigger, not an Orchestrator habit (T294, absorbed 2026-08-03 by STANDING-ABSORB).** `managent standing` carries STANDING-ABSORB, which auto-registers a dispatchable kanban task when claimlint's C7 unabsorbed-findings count exceeds 5. The count is read from `bin/weizigo-claimlint`'s own summary (the same run the C3 trigger uses; never reimplemented — one implementation of the count, the kernel doctrine), and the per-file composition is surfaced from claimlint's own `UNABSORBED … in <file>` lines. Threshold rationale (src/managent/main.zig:4117): 0 is the permanently-red-gate failure (GRAND-AUDIT §1c); 1–4 is the in-flight noise band (a finished task's findings are legitimately unabsorbed until ratified); 5 is a session-sized job and fires with margin on the smallest fully decomposable genuine backlog observed (10, 2026-08-03: C7=21 = 10 genuine + 11 context dumps repeating their findings files) without firing on noise. Trigger is absolute (count > threshold), not change-based. Controls: null (empty findings → C7=0, no trigger, explicit at/below-threshold statement) and seeded (6 synthetic unabsorbed claims → C7=6, trigger fires, names count, registers dispatchable task) both PASS, wired into `zig build test` via tools/regression-managent-standing.sh — the standing mechanism previously had no controls at all. Re-verified live during absorption 2026-08-03: `managent standing` fired with C7=10 and the correct per-file composition | PROVEN | `docs/evidence/CODE.STANDING-ABSORB/PROVENANCE.md`; `src/managent/main.zig:4117,4151,4366`; `tools/regression-managent-standing.sh`; `docs/infra/dispatch/STANDING-ABSORB.md`; `findings/T294-standing.json` | `d:CODE.CLAIMLINT-C7-NEWROWS` (the count's correctness rests on claimlint's C7 parsing) | the absorption queue, C7 gate decision | 0 | ? | RETIRED |
```
