# `CODE.WZO2-CHAINSHORT` — archived register row

**Class:** ARCHAEOLOGY · **Moved:** 2026-08-06 by T373 (triage adoption, `docs/epistemic/register-triage-2026-08-04.md`, Orchestrator ruling 2026-08-05) · **Family:** old-artifact

**Epitaph:** Found the WZO2 GTP path short-circuiting the chainability instrument — SUPERSEDED when the code was fixed — the 'holds by construction' failure class is the lesson; the code is fixed, the row is history.

**Move reason (from the triage sheet):** [old-artifact] SUPERSEDED — true when written (T269); code fixed since

**Full register row (verbatim at the time of the move):**

```
| `CODE.WZO2-CHAINSHORT` | — | n/a | **The WZO2 GTP path disables the chainability instrument.** `src/gtp.zig:286-288` (pinned `200b974`): `chainable_at_pos` returns `true` unconditionally when an Artifact2 is loaded ("Bellman identity holds by solver construction"); additionally a lookup miss silently falls back to an area-score terminal row (L=H=area, DTT=0) with no counter and no log. Consequence: **the UNCHAINABLE/refusal rate under WZO2 reads 0 by fiat, not by measurement** — spec A1 (v1 baseline: 10/10 plies refused) cannot be satisfied or falsified by this code path, converting the sprint's headline falsifiable prediction ("the full Markov key eliminates refusals") into an unfalsifiable assertion. The v1 branch retains the real check. T129/QA-027 is the precedent that "holds by construction" claims fail exactly where asserted | SUPERSEDED (2026-08-03, T269: true when written — the WZO2 chainability check WAS short-circuited; T261 later confirmed the code was fixed, `chainable_at_pos` now runs the real chain check for WZO2 in `src/gtp.zig`, so the row no longer describes the code. The register had no status for "true when written, overtaken by events" — this is its first use) | `src/gtp.zig:286-288` | — | spec A1, M4b acceptance, any WZO2 self-play measurement, `QA-020` successors | 0 | ? | RETIRED |
```
