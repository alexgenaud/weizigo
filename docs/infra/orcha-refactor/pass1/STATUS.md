# Pass 1 - live status (human-readable; the owner updates this at every step)

**Owner:** T557 (fresh DSPro, successor to T556) - **T556 is read-only advisory now.**
**Last update:** 2026-08-21 - D33: D27 B-3 accusation RETRACTED (Opus review, both lanes DEFEND); S9 kill-parity arm added (B-3 retry path now exercised); phase 9 commit still the operator's decision.

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
- history: `docs/infra/orcha-refactor/pass1/OWNER-LOG.md` (D1-D33)
- build audit: `docs/infra/orcha-refactor/pass1/07-build-audit-disposition.md`
- spec audit: `docs/infra/orcha-refactor/pass1/01-spec-audit-disposition.md`

## Blocked / open
- **Commit is the last phase-9 step, and it is the operator's bookend decision.** Everything else is done and verified. The commit spans four consoles' files (T554/T555/T556/T557): CODE (`src/managent/main.zig` +834 treekill-only, `tools/runner` +223, `tools/regression-runner-guard.sh`, new `tools/regression-process-ownership.sh`) and DOCS/FINDINGS (`docs/infra/orcha-refactor/**`, `docs/infra/races/{goldilocks,metric-vocabulary}.md`, `docs/evidence/orcha-pass1-perfamily-topology/`, `findings/T55{0..7}-*.json`, `AGENTS.md` goldilocks pointer). **Do NOT sweep** the live store files (`docs/infra/managent/tasks.json` etc.) which carry fleet-wide churn, nor the unrelated engine work (`src/colex.zig`, `src/vb_*.zig`, …). Exact scoped file list is in OWNER-LOG D32/D31.
- T554/T555/ORCHA-FLASH are orphaned in_progress rows; close after the commit (done gate requires committed deliverables).
