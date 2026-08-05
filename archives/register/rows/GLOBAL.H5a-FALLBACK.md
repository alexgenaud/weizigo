# `GLOBAL.H5a-FALLBACK` — archived register row

**Class:** ARCHAEOLOGY · **Moved:** 2026-08-06 by T373 (triage adoption, `docs/epistemic/register-triage-2026-08-04.md`, Orchestrator ruling 2026-08-05) · **Family:** player

**Epitaph:** Ruled 'refuse' must not mean pass — the player falls back to a history-free settled-area quantity — shipped in the player; the ruling is recorded here, the code carries it.

**Move reason (from the triage sheet):** [player] "refuse" must not mean pass (D-3, EXP-9) — player-side

**Full register row (verbatim at the time of the move):**

```
| `GLOBAL.H5a-FALLBACK` | H5(a) correction 2 | all | **"Refuse" must NOT mean pass.** When the identity check fails, the player falls back to a **history-free quantity** — settled area / Benson-alive territory — which is sound by theorem rather than by table lookup. Ruled 2026-07-28 (D-3, Opus) as the second condition of H5(a) shipping. Passing is a *move* with a value; refusing to price a position is not. **Implementation shipped (EXP-9, Opus 5, 2026-07-29):** the fallback is the settled-area / Benson-alive quantity in `src/gtp.zig`. **CLAIMED, not verified-optimal** (same EXP-9 run as `GLOBAL.H5a-CHILD`; same PARTIAL caveat). | CLAIMED | ruling D-3, 2026-07-28; EXP-9 2026-07-29 (`docs/research/h5a-player-mitigation-2026-07-28.md`); `open-hypotheses:281-284` (the H5(b) history-free-by-theorem argument this reuses); `0004:16-19,31-34` | `d:GLOBAL.S2`, `d:GLOBAL.ADR0004-TERM`, `e:GLOBAL.H5b` | H5(a) implementation, `GLOBAL.H5` player fork, `src/gtp.zig` genmove | 0 | ? | RETIRED |
```
