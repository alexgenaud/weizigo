# T209 Model-Identity Test

**Task:** T209 · **Role:** worker · **Model:** deepseek-v4-pro · **Date:** 2026-08-01

## Test: harness model self-report accuracy

Each harness was asked to self-report its model. The human bound the model at launch;
the harness's self-report was compared to ground truth.

| harness | ground truth | self-reported | accurate? | notes |
|---|---|---|---|---|
| Pi | deepseek-v4-pro | deepseek-v4-pro | ✅ yes | `PI_MODEL` env var; Pi never misreports per human 2026-08-01 |
| Claude Code | — | — | ⚠️ untested | Claude-family harnesses assume Claude models (human, 2026-08-01) |
| Codex | — | — | ⚠️ untested | Codex assumes GPT (human, 2026-08-01) |
| Ollama | — | — | ⚠️ untested | varies by backend |

## Design decision

**Model is bound at DISPATCH time, not claim time.** `managent suggest --model <name>` stores
the model on the task record. `managent claim` uses the stored model automatically — no
`--agent` flag needed. Self-report by the worker is never the primary identity source
(except for Pi, which is proven honest).

**Correction path:** `managent agent <id> <model>` updates the stored model.
`managent claim <id> --agent <override>` overrides for one claim.

This design survives the case where the worker does not know its model: the model was
already recorded at dispatch time by the human who launched it.
