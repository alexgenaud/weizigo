# Citation-existence census — `docs/infra/runner.md`

**Denominator.**
`citations=27 unique=12`

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
| `untracked/runs/<task>.json` | NO (template; parent dir `untracked/runs` exists (dir)) |

**Summary.**
`missing=2`

**Ambiguous.**

| path | reason |
|---|---|
| `untracked/runs/<task>.json` | contains the placeholder `<task>`; no literal file of that name exists. Counted as `NO` above since the literal string does not resolve; the containing directory `untracked/runs/` does exist and holds per-task records. |

Ambiguous count: 1.

---

### Occurrence tally (how the denominator was reached)

| path | occurrences | lines |
|---|---|---|
| `tools/runner` | 12 | 1, 35, 36, 88, 91, 95, 102, 107, 113, 142, 237, 285 |
| `docs/infra/host/incident-2026-07-29.md` | 2 | 3, 281 |
| `docs/infra/dispatch/RUNNER-CEILING.md` | 2 | 30, 282 |
| `docs/infra/host/macos-timeout-gap.md` | 2 | 132, 283 |
| `untracked/runs/<task>.json` | 2 | 191, 231 |
| `src/oracle.zig` | 1 | 7 |
| `src/arena.zig` | 1 | 92 |
| `bin/subagent` | 1 | 141 |
| `bin/ollama-subagent` | 1 | 141 |
| `tools/bakeoff.sh` | 1 | 141 |
| `docs/infra/managent/directives.jsonl` | 1 | 159 |
| `untracked/heartbeat.jsonl` | 1 | 174 |
| **total** | **27** | |

Excluded as not matching the prefix list (recorded for transparency, not counted): `AGENTS.md` (line 80), `.zig-cache/` (line 65), `heartbeat.jsonl` bare (line 182), `/proc/<pid>/status`, `/proc/<pid>/stat` (lines 121–123), `/tmp/arena` (line 92).
