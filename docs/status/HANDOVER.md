# Boss handover — 2026-07-27 (DeepSeek-Pro → GLM)

**Context:** 50-task sprint completed. 4×4 parallel artifact at 99.8%.
Repo clean. Ready for next Boss.

---

## Read order

1. `docs/epistemic/PROGRESS.md` — strategic overview (updated)
2. `docs/status/CURRENT.md` — live state
3. `docs/epistemic/innovations.md` — I1-I15 catalog
4. `docs/infra/delegation.md` — prompt Kanban
5. `untracked/heap.md` — discussion topics + ideas

## Critical state

- C1 PROVEN at 2×2/3×2. C2 false at 3×2. C3 false at 3×3.
- 4×4 parallel artifact: `data/oracle-4x4-parallel.checkpoint.wzo` — 99.8%
  complete, 83K unfilled (2-ko+ deep tangles). Usable for GTP play with UNDEF
  fallback.
- Board epistemic trees exist for 2×2, 3×2, 3×3, 4×4.

## One dispatchable

```
odeeppi -p "follow untracked/B39-arena4x4.md"
```
Arena-audit the new 4×4 artifact for leaks. Read-only.

## Key tools

| Binary | Source | Purpose |
|---|---|---|
| `bin/managent` | `src/managent/main.zig` | Task manager |
| `bin/weizigo-oracle` | `src/gtp.zig` | GTP player (auto-artifact from boardsize) |
| `bin/weizigo-arena` | `src/arena.zig` | Persona/regression/leak audit |
| `bin/weizigo-engine-vs-engine` | `src/engine-vs-engine.zig` | Self-play regression |

## Multi-model evaluation

GLM recommended as next Boss. Consistent across B34-B38 task types.
MiniMax for thorough audits. DS Pro for epistemic verification.
DS Flash for speed. Kimi for follow-through on existing findings.

## What's cooking

- Heap items: prove I1, implement I3 (2-ko), 5×5 prep, history-aware genmove
- GTP improvements (B24): auto-artifact, resign complete
- Single-ko solver (B32): integrated, limited by certified-neighbor constraint
