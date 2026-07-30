<!--managent set=A-->
# T120 — kanban/goban terminology sweep: zero exclusions

**Opened by:** the human, 2026-07-30, via Dabir. ANALYSIS + MUTATION (code refactor). No holds — runs alone because it touches everything.

## The rule

Two replacements, everywhere, no exceptions:

| find | replace |
|---|---|
| `board` (task system, kanban context) | `kanban` |
| `board` (game surface, game context) | `goban` |

**No exclusions.** Code, docs, channel, history, CLAIMS.md, model-perf.md, ADRs, evidence files, channel messages, comments, variable names, type names, commit messages that can be amended. Every file in the repository and `untracked/msg/`.

## Disambiguation

The agent must determine which replacement applies at each occurrence. Default rules:

- `docs/infra/`, `docs/status/`, `AGENTS.md`, channel, `tasks.json` → kanban context
- `docs/research/`, `docs/epistemic/`, `docs/engine/`, `docs/decisions/`, `src/` → goban context
- `board` in compound terms: `task board` → `kanban`, `go board` → `goban`, `board size` → `goban size`, `board state` → `goban state`
- Idioms ("across the board", "board of directors") → leave
- Code: `Board` type → `Goban`, `board` variable → `goban`, `boards/` directory → `gobans/`

## Acceptance

- `grep -ri "board" --include="*.md" --include="*.zig" --include="*.json" --include="*.py" .` returns zero hits outside idiomatic usage
- `zig build test` passes
- `bin/weizigo-claimlint` passes
- `bin/managent status` works
- No file renamed without updating all references to it

## Deliverable

The edited files. **Do not edit `tasks.json` directly** — use `bin/managent` commands for any metadata changes. Commit with a message recording the sweep.

**Read first:** the project root, then grep for `board` to understand scope before starting.
