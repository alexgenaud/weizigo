# `CODE.STANDING-C3-DEAD` — archived register row

**Class:** NOTE · **Moved:** 2026-08-06 by T373 (triage adoption, `docs/epistemic/register-triage-2026-08-04.md`, Orchestrator ruling 2026-08-05) · **Family:** process

**Epitaph:** Found the STANDING-REEVIDENCE trigger cannot fire — the marker it greps for never appears in claimlint output — a dead-trigger defect record; the fix decision belongs to the Orchestrator, not the register.

**Move reason (from the triage sheet):** infra defect record — dead trigger, reported for the Orchestrator; infra, not a claim about Z

**Full register row (verbatim at the time of the move):**

```
| `CODE.STANDING-C3-DEAD` | — | n/a | **The pre-existing STANDING-REEVIDENCE trigger cannot fire (T294, absorbed 2026-08-03).** `cmdStanding` searches claimlint output for the marker "C3: " (src/managent/main.zig:4140,4176), but claimlint's summary prints "C3 PROVEN w/o committed evid. N" — no line containing "C3: " exists in its output (verified by grep over a full claimlint run, 2026-08-03; re-verified during absorption). `c3_debt` therefore parses as 0 every run and the change-based condition (`c3_debt > c3_prior and c3_prior > 0`) can never hold. The trigger is dead code as written. Not fixed by T294 — reported so the Orchestrator can decide (neighbouring triggers are the Orchestrator's call per the T294 brief's note) | PROVEN | `src/managent/main.zig:4140,4176`; `bin/weizigo-claimlint` summary line format (grep for "C3: " over full output returns nothing, 2026-08-03); `docs/evidence/CODE.STANDING-ABSORB/PROVENANCE.md` (observation recorded) | — | STANDING-REEVIDENCE effectiveness, C3 debt trigger decision | 0 | ? | RETIRED |
```
