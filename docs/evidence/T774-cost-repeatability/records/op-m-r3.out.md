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
| `untracked/runs/<task>.json` | see Ambiguous (parent `untracked/runs` exists (dir)) |

**Summary.** `missing=1`

**Ambiguous.**
- `untracked/runs/<task>.json` (lines 191, 231) — contains the placeholder `<task>`; no literal file of that name can be checked. The parent directory `untracked/runs` exists (dir) and is populated. Not counted in `missing`.

Occurrence tally (for audit): `tools/runner` ×12 (lines 1, 35, 36, 88, 91, 95, 102, 107, 113, 142, 237, 285); `docs/infra/host/incident-2026-07-29.md` ×2 (3, 281); `docs/infra/dispatch/RUNNER-CEILING.md` ×2 (30, 282); `docs/infra/host/macos-timeout-gap.md` ×2 (132, 283); `untracked/runs/<task>.json` ×2 (191, 231); all others ×1 (`src/oracle.zig` 7, `src/arena.zig` 92, `bin/subagent` 141, `bin/ollama-subagent` 141, `tools/bakeoff.sh` 141, `docs/infra/managent/directives.jsonl` 159, `untracked/heartbeat.jsonl` 174).

Excluded as not matching the prefix rule: `.zig-cache/` (line 65), `AGENTS.md` (line 81), bare `heartbeat.jsonl` (line 181), `/proc/<pid>/…` (lines 121–125).
