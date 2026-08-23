# Citation-existence census — `docs/infra/runner.md`

citations=27 unique=12

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
| `untracked/runs/<task>.json` | AMBIGUOUS (parent `untracked/runs/` exists (dir)) |

missing=1

## Ambiguous

- `untracked/runs/<task>.json` (2 occurrences, lines 191 and 231) — contains the placeholder `<task>`; no single concrete file to test. The containing directory `untracked/runs/` exists (dir).

## Occurrence tally

`tools/runner` ×12 (lines 1, 35, 36, 88, 91, 95, 102, 107, 113, 142, 237, 285); `docs/infra/host/incident-2026-07-29.md` ×2 (3, 281); `docs/infra/dispatch/RUNNER-CEILING.md` ×2 (30, 282); `docs/infra/host/macos-timeout-gap.md` ×2 (132, 283); `untracked/runs/<task>.json` ×2 (191, 231); `src/oracle.zig` ×1 (7); `src/arena.zig` ×1 (92); `bin/subagent` ×1 (141); `bin/ollama-subagent` ×1 (141); `tools/bakeoff.sh` ×1 (141); `docs/infra/managent/directives.jsonl` ×1 (159); `untracked/heartbeat.jsonl` ×1 (174).

Excluded as not matching a listed prefix: `.zig-cache/` (65), `AGENTS.md` (81), bare `heartbeat.jsonl` (181), `/proc/<pid>/status`, `/proc/<pid>/stat` (121–124), `/tmp/arena` (92).
