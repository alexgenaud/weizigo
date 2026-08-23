# Citation-existence census — `docs/infra/runner.md`

**Denominator.** `citations=27 unique=12`

| path | exists? |
|---|---|
| `tools/runner` | YES |
| `docs/infra/host/incident-2026-07-29.md` | YES |
| `src/oracle.zig` | YES |
| `docs/infra/dispatch/RUNNER-CEILING.md` | YES |
| `src/arena.zig` | YES |
| `docs/infra/host/macos-timeout-gap.md` | YES |
| `bin/subagent` | YES |
| `bin/ollama-subagent` | NO |
| `tools/bakeoff.sh` | YES |
| `docs/infra/managent/directives.jsonl` | YES |
| `untracked/heartbeat.jsonl` | YES |
| `untracked/runs/<task>.json` | AMBIGUOUS |

**Summary.** `missing=1`

**Ambiguous.**

- `untracked/runs/<task>.json` (lines 191, 231) — contains the placeholder `<task>`; no concrete filename to test. The parent directory `untracked/runs` does exist (dir).

Occurrence breakdown: `tools/runner` ×12 (L1, 35, 36, 88, 91, 95, 102, 107, 113, 142, 237, 285); `docs/infra/host/incident-2026-07-29.md` ×2 (L3, 281); `docs/infra/dispatch/RUNNER-CEILING.md` ×2 (L30, 282); `docs/infra/host/macos-timeout-gap.md` ×2 (L132, 283); `untracked/runs/<task>.json` ×2 (L191, 231); all others ×1. Not counted (no qualifying prefix): `.zig-cache/`, `/proc/<pid>/status`, `/proc/<pid>/stat`, `runner/<pid>`, bare `heartbeat.jsonl`, `AGENTS.md`.
