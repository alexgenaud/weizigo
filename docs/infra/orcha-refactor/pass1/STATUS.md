# Pass 1 - live status (human-readable; the owner updates this at every step)

**Owner:** T557 (fresh DSPro, successor to T556) - **T556 is read-only advisory now.**
**Last update:** 2026-08-21 - committed as `bec8be2` (pass-1 code+docs+findings); goldilocks cost/overqualification corrected; T556-stats made conforming. Next: close T554/T555/ORCHA-FLASH, then t11/t12 fold + ladder races.

## Ladder
| phase | state |
|---|---|
| 0-6 | DONE |
| 7 build + audit | DONE (PASS-WITH-FINDINGS; B-1..B-6 closed) |
| 8 verify + smoke | DONE (pass-1 green; full suite red only on pre-existing quirk + pending deploy) |
| 9 accept | IN PROGRESS (08-accept.md + findings + deploy DONE; commit = the operator's bookend decision) |

## Running now
- phase 9 commit — prepared, awaiting the operator's bookend-commit decision (file list in OWNER-LOG D32)
- t11 - DSPro designing the appetite config + matrix schema + model-perf restructure (in flight, audit next)

## Queued (in order)
1. phase 9 commit — bookend (then close T554/T555/ORCHA-FLASH)
2. t11 - audit with a fresh model, then implement (model-perf restructure + adopt config)
3. ladder races - per `docs/infra/races/goldilocks.md` (R4/R5) and the appetite

## Standing race-field constraint (operator + T556, 2026-08-21)
Race **only Claude + DeepSeek API models** — Fable, Opus, Sonnet, Haiku, DSPro, Flash.
**No Ollama cloud** (zero tokens now) and **no local models** (low appetite). API-only lanes
run in parallel safely (no host-memory risk). One byte-identical brief, one unique output
file per lane, each wrapped in `tools/runner` (crib `untracked/bakeoff/pass1-audit-round1/drive.sh`);
Claude via `--output-format json`, DS via `pi --provider deepseek`. Field = target + adjacent
rungs. Claude weekly ~70% used → full field only to establish a rung, not routine tasks.

## Key artifacts
- rules: `docs/infra/races/goldilocks.md` (R1-R5 provisional)
- history: `docs/infra/orcha-refactor/pass1/OWNER-LOG.md` (D1-D35)
- build audit: `docs/infra/orcha-refactor/pass1/07-build-audit-disposition.md`
- spec audit: `docs/infra/orcha-refactor/pass1/01-spec-audit-disposition.md`

## Blocked / open
- **Committed** as `bec8be2` (D35). Remaining: close T554/T555/ORCHA-FLASH (done gate now satisfiable), then t11/t12 fold and the ladder races.
- T554/T555/ORCHA-FLASH are orphaned in_progress rows; close now that the deliverable is committed.
