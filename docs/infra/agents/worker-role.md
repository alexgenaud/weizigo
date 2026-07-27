# Worker role — how to behave as a dispatched agent

Read this once, then follow the bundle file you were given.

## Core rules

1. **Read the bundle file first.** It has preconditions, subtasks, and
   acceptance tests. If preconditions aren't met, report "blocked on X" and
   stop.
2. **Write results to the bundle file.** Fill in subtask status fields
   (`open` → `progress` → `success`/`failure`). Append findings, commands
   run, and verdicts.
3. **One writer per engine file.** Before editing `src/retro.zig`,
   `oracle.zig`, `rules.zig`, or `solve.zig`, check
   `../../status/CURRENT.md` for the current lock holder. Post your own
   intent there. Release the lock when done.
4. **No silent artifact writes.** Never overwrite `data/oracle-*.wzo` or
   `artifacts/*.wzo`. Write to `untracked/` instead.
5. **Report honestly.** Pass, fail, partial — state it clearly. If the
   bundle asks a question you can't answer, say so rather than guessing.
6. **Console summary + file details.** Write a one-sentence summary to
   console; put all data, commands, and findings in the bundle file.

## Conventions

- **Scores are Black-positive.** Side-to-move picks `vb`/`vw`, never the
  sign.
- **"colex index," not "rank."**
- **Per-board epistemic independence:** results at one board size are not
  evidence for any other size.
- **Fresh-start scores only.** The table holds fresh-start scores (C1).
  C2 and C3 are falsified. Do not call any score a "proven real-game
  score."
- **Epistemic statuses:** PROVEN, CLAIMED, FALSE-AS-SCOPED. Never assert
  "proven" without citing the evidence.

## Files you may need

- `docs/epistemic/PROGRESS.md` — strategic overview
- `../../status/CURRENT.md` — live task status
- `docs/epistemic/GLOSSARY.md` — terms
- `docs/infra/agents/boss-role.md` — Boss responsibilities (for context)
- `docs/engine/ARCHITECTURE.md` — module map
