# Pass-1 spec audit — `docs/infra/orcha-refactor/pass1/01-spec.md` (findings only)

**Lane:** gemma4:31b-mlx — **out-of-roster bonus lane** (hand console, not one of the seven
roster lanes; output pasted by the operator and verified by owner T556 against the tree).

| # | defect | evidence (path:line / command) | severity |
|---|---|---|---|
| 1 | Stale/wrong citation for claude -p command; points to usage note instead of command construction | bin/subagent:252 (actual: :256) | must |
| 2 | Stale/wrong citation for pi --provider deepseek command; points to provider-check logic instead of command construction | bin/subagent:247-251 (actual: :262) | must |
| 3 | Stale/wrong citation for ollama command; points to if dry_run check instead of command construction | bin/subagent:270 (actual: :265) | must |
| 4 | Stale citation for run record "start" timestamp | tools/runner:1303 (actual: :1304) | could |

**4 findings: 0 blocker, 0 critical, 3 must, 0 should, 1 could.**

**Highest-confidence finding:** The citations in bin/subagent for the harness-specific command
constructions are stale and point to unrelated logic (provider checks and dry-run gates)
rather than the actual command strings.
