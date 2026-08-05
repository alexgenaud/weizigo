# `GLOBAL.ADR0012-LAYER` — archived register row

**Class:** ARCHAEOLOGY · **Moved:** 2026-08-06 by T373 (triage adoption, `docs/epistemic/register-triage-2026-08-04.md`, Orchestrator ruling 2026-08-05) · **Family:** design

**Epitaph:** Computed single 5×5 layer sizes exceed RAM raw (peak ≈142 GB) — layered streaming alone does not save 5×5 — the arithmetic feeds L7's 5×5 decision; out of Z's goban scope.

**Move reason (from the triage sheet):** [design] 5×5 layer RAM arithmetic — out of Z's goban scope

**Full register row (verbatim at the time of the move):**

```
| `GLOBAL.ADR0012-LAYER` | — | 5×5 | Single 5×5 layers exceed RAM raw (peak layer k=17 ≈ 1.42e11 slots = 142 GB at 1 B/slot) → layered streaming alone does not save 5×5 | PROVEN (arithmetic) | `0012:91-95` | — | `GLOBAL.ADR0012-5X5` | 0 | ? | RETIRED |
```
