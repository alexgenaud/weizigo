# Task - design the model-delegation economics (appetite + measurement matrix)

You are designing (not implementing) how this project formalizes which models get which
tasks, under variable token budgets. Design only; edit nothing.

## Inputs (operator's stated requirements, 2026-08-21 - treat as the source of truth)

### Task-type history (what to measure models against, for now)
| task type | share |
|---|---|
| audit/verification | 27% |
| infra/tooling | 22% |
| battery-heavy (mutation/verify-battery) | 18% |
| implementation-bounded | 11% |
| orchestration-seat | 8% |
| integration/reframe | 6% |
| research/census | 4% |
| spec/design | 3% |

(Operator note: hopes to shift MORE energy to spec/design, so less energy is spent later
debugging/refactoring.)

### Appetite + token constraints (variable over time)
Appetite here means: how eager we are to spend a given model family's tokens on (a) racing
and testing models vs (b) real task execution, given the current budget state.

- **Ollama cloud (GLM/Minimax/Kimi)**: zero tokens for the next 48h +/- 24h; many next week.
- **Claude weekly**: ~70% used now; conserve.
- **Claude 5-hour rolling limit**: never eagerly exhaust it (a mid-task block is annoying or
  catastrophic).
- **Fable**: reserve for his special skills; keep available same-day; never one-off/general.
- **DSPro/Flash**: safest reliable workhorses; do not abuse the generous budget.
- **Local models (qwen/gemma)**: low appetite (slow, low benefit); only a sense of what they
  can and cannot do, no clear production use yet.

### model-perf.md
Legacy data is flaky impressions, some stale (models silently updated). The operator wants it
more tabular, quantifiable, and insight-discoverable, and to archive most of the legacy file
in favor of structured model-task-metric performance data.

## Deliverables (design only; concise; "less is best")
1. **Appetite config** - a formalization of the variable tolerances above (per model family:
   token budget state, appetite level, reservations) that a dispatch/race decision can
   consult. Human-readable and revisable; a machine-readable form is optional but welcome.
2. **Model-task-metric matrix schema** - structured, quantifiable records keyed by
   (task type x model), with the fields that make goldilocks tiers (just-right / over / under)
   computable. Reference `docs/infra/races/goldilocks.md` for the tier definitions.
3. **model-perf.md restructure plan** - what to archive, what the new structure is, and how
   to migrate.

## Rules
- Design, do not implement. Do not edit model-perf.md or any other file.
- Cite the operator's inputs above as the source of truth for constraints.
- Keep every section short; no prose padding.
