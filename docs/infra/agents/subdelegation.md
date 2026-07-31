# Subdelegation — dispatching work to DeepSeek Pro/Flash subagents

**Commands:**
- `pi --provider deepseek --model deepseek-v4-pro -p "prompt"` — DeepSeek-v4-Pro subagent
- `pi --provider deepseek --model deepseek-v4-flash -p "prompt"` — DeepSeek-v4-Flash subagent

API key is already exported in the parent shell. Subagents run in the same Pi harness as the parent. Output returns to stdout. Subagents share the project directory and can read/write files.

## When to use

| scenario | subagent |
|---|---|
| Parallel independent audit (different instance, same model) | `pi --provider deepseek --model deepseek-v4-pro` |
| Cheap mechanical sweep, terminology, formatting | `pi --provider deepseek --model deepseek-v4-flash` |
| Run two measurements at different goban sizes simultaneously | either |
| Adversarial review — must be a different instance, ideally different model | Pro reviews Pro, or Flash reviews Pro |

## Rules

1. **Give the subagent a bounded task.** One file to read, one question to answer, one deliverable. A subagent with an open-ended brief is a lost session.
2. **State the deliverable path.** The subagent must write its output to a specific file. The parent reads it after the subagent exits.
3. **Subagents never edit shared state.** No `CLAIMS.md`, no `CURRENT.md`, no `tasks.json`, no channel messages. Output goes to `untracked/` or a dedicated evidence path.
4. **Independent re-implementation is the highest-value use.** The only instrument that has found every real defect in this project is an independent seat. Subagents make this cheap.
5. **Max two subagents at once.** They share the same filesystem and API key. Three concurrent subagents risk race conditions and rate limiting.

## Pattern: independent audit

```sh
# Parent dispatches an audit subagent
pi --provider deepseek --model deepseek-v4-pro -p "You are DSPro/T999-audit. Read docs/design/foo/pass0/spec.md. Audit it against the acceptance criteria in the same file. Write your verdict and findings to untracked/T999-audit.md. Do not edit the spec."
```

## Pattern: parallel measurements

```sh
# Run SCC census at two goban sizes in parallel
pi --provider deepseek --model deepseek-v4-pro -p "You are DSPro/SCC-3x3. Read docs/infra/dispatch/SCC-3x3.md. Run the census. Write results to docs/evidence/SCC/3x3.md." &
pi --provider deepseek --model deepseek-v4-flash -p "You are DSFlash/SCC-4x3. Read docs/infra/dispatch/SCC-4x3.md. Run the census. Write results to docs/evidence/SCC/4x3.md." &
wait
```

## Recording

Subagent work is recorded in `model-perf.md` under the parent task, with a note that it was subdelegated. The subagent's model is stated.
