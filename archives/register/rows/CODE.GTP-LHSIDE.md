# `CODE.GTP-LHSIDE` — archived register row

**Class:** ARCHAEOLOGY · **Moved:** 2026-08-06 by T373 (triage adoption, `docs/epistemic/register-triage-2026-08-04.md`, Orchestrator ruling 2026-08-05) · **Family:** player

**Epitaph:** Found the GTP display printing the bracket for the wrong side to move — a display-path defect, fixed T283 — display-only, but the wrong-side-query class is why producer/consumer key tests exist.

**Move reason (from the triage sheet):** [player] wrong-side bracket display — display-path defect (fix T283)

**Full register row (verbatim at the time of the move):**

```
| `CODE.GTP-LHSIDE` | — | n/a | **`src/gtp.zig:1222-1225` displays the bracket for the wrong side to move on every genmove (T266, absorbed T279).** The `lh_suffix` block calls `bounds2(&s.pos, …, side)` after `applyMove`, querying the post-move position with the mover still named as side to move. On the opening move that state is single-colour and legitimately absent (the reproducible `colex=12 side=1 ko=16 passes=0` miss). Everywhere else the wrong-side query silently succeeds and prints a wrong bracket. Display/telemetry only: the move choice from `choose_with_check` is unaffected. Reproduced at HEAD `63e245f`; four plies cross-checked against direct artifact lookups. Fix scope for T283. **(Term "monochrome" superseded by "single-colour goban" per glossary, T285, 2026-08-03.)** | PROVEN (reproduced at HEAD, four plies cross-checked; independently confirmed by T277) | `docs/evidence/ORACLE-V2/incompleteness-T266.md`; `docs/evidence/ORACLE-V2/incompleteness-verify-T277.md`; `findings/T266-incompleteness.json` | `d:CODE.WZO2-PASS1-LAW` (the single-colour-side law explains why the wrong-side query's miss is real but irrelevant) | T283 (fix), GTP display path, self-play diagnostics | 0 | ? | RETIRED |
```
