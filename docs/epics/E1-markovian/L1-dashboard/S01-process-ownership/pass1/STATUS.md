# Pass 1 - live status (human-readable; the owner updates this at every step)

**Owner:** T557 (fresh DSPro, successor to T556) - **T556 is read-only advisory now.**
**Last update:** 2026-08-21 - committed as `bec8be2` (pass-1 code+docs+findings); goldilocks cost/overqualification corrected; T556-stats made conforming. Next: close T554/T555/ORCHA-FLASH, then t11/t12 fold + ladder races.

## Ladder
| phase | state |
|---|---|
| 0-6 | DONE |
| 7 build + audit | DONE (PASS-WITH-FINDINGS; B-1..B-6 closed) |
| 8 verify + smoke | DONE (pass-1 green; full suite red only on pre-existing quirk + pending deploy) |
| 9 accept | DONE (08-accept.md + findings + deploy + commit `bec8be2`; T554/T555/ORCHA-FLASH closed) |

## Running now
- t11 - DSPro designing the appetite config + matrix schema + model-perf restructure (in flight, audit next)

## Queued (in order)
1. t11 - audit with a fresh model, then implement (model-perf restructure + adopt config)
2. ladder races - per `docs/infra/races/goldilocks.md` (R4/R5) and the appetite

## Standing race-field constraint (operator + T556, 2026-08-21)
Race **only Claude + DeepSeek API models** — Fable, Opus, Sonnet, Haiku, DSPro, Flash.
**No Ollama cloud** (zero tokens now) and **no local models** (low appetite). API-only lanes
run in parallel safely (no host-memory risk). One byte-identical brief, one unique output
file per lane, each wrapped in `tools/runner` (crib `untracked/bakeoff/pass1-audit-round1/drive.sh`);
Claude via `--output-format json`, DS via `pi --provider deepseek`. Field = target + adjacent
rungs. Claude weekly ~70% used → full field only to establish a rung, not routine tasks.

## Key artifacts
- rules: `docs/infra/races/goldilocks.md` (R1-R5 provisional)
- history: `docs/epics/E1-markovian/L1-dashboard/S01-process-ownership/pass1/OWNER-LOG.md` (D1-D35)
- build audit: `docs/epics/E1-markovian/L1-dashboard/S01-process-ownership/pass1/audit-build-disposition.md`
- spec audit: `docs/epics/E1-markovian/L1-dashboard/S01-process-ownership/pass1/audit-disposition.md`

## Blocked / open
- **Pass-1 committed** (`bec8be2`…`6f8a432`) and T554/T555/ORCHA-FLASH closed. Remaining: t11/t12 fold and the ladder races.
