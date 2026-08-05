# `CODE.STANDING-STATE-FRAGILE` — archived register row

**Class:** NOTE · **Moved:** 2026-08-06 by T373 (triage adoption, `docs/epistemic/register-triage-2026-08-04.md`, Orchestrator ruling 2026-08-05) · **Family:** process

**Epitaph:** Found the standing triggers' persisted priors survive only until the next kanban write — an infra defect record — the fragility is documented for the managent owners; not a claim about Z.

**Move reason (from the triage sheet):** infra defect record — persisted priors fragile; infra, not a claim about Z

**Full register row (verbatim at the time of the move):**

```
| `CODE.STANDING-STATE-FRAGILE` | — | n/a | **The standing triggers' persisted was/now priors survive only until the next kanban write (T294, absorbed 2026-08-03).** `parseStateJson` skips every `_`-prefixed key (src/managent/main.zig:581) and `writeState` re-serializes only task keys, so `persistStandingState`'s textual `_standing` insertion (main.zig:4475) is dropped by any subsequent add/claim/done. Live state 2026-08-03: tasks.json carries no `_standing` key despite the Orchestrator's fired-trigger report (re-verified during absorption: `grep -c "_standing"` → 0). Consequence: the change-based triggers (REEVIDENCE, CONSOLIDATE, CLEANUP, HOLISTIC-AUDIT) lose their prior baseline whenever the kanban is written between standing runs. STANDING-ABSORB is unaffected (absolute trigger, no prior). Not fixed by T294 — reported | PROVEN | `src/managent/main.zig:581` (metadata keys skipped in parseStateJson); `src/managent/main.zig:4475` (persistStandingState naive textual insertion); `docs/infra/managent/tasks.json` (no `_standing` key, 2026-08-03); `docs/evidence/CODE.STANDING-ABSORB/PROVENANCE.md` | — | the change-based standing triggers (REEVIDENCE, CONSOLIDATE, CLEANUP, HOLISTIC-AUDIT) | 0 | ? | RETIRED |
```
