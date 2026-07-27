# ADR-0014: Board-snapshot scoring UI for GTP

Status: accepted
Date: 2026-07-27
Supersedes: nothing (additive GTP surface)
Relates to: ADR-0003 (Chinese area scoring), ADR-0011 (artifact format)

## Context

The GTP oracle player (`src/gtp.zig`) answers `final_score` with a single
`B+X`/`W+X`/`0` string derived from Chinese/area scoring.  That number counts
*every on-board stone as alive* and silently omits dame ("no man's land"),
which is misleading for humans mid-game.  We want a score report that is:

1. **Honest:** labels the number as definitive only when the board is settled,
   and provisional otherwise.
2. **Pure:** computed from the board snapshot only, with no dependency on the
   oracle's fresh-start / GHI caveats.
3. **Legible:** breaks the score into area, Japanese-style territory, dame,
   and a conservative dead-stone estimate.

## Decision

Add a new pure module `src/score.zig` and three new GTP commands.  No oracle
values are consulted.  Every public function carries an epistemic tag.

### `src/score.zig` — pure board-snapshot scoring

`Score(comptime w, comptime h)` returns a namespace of pure functions for a
fixed board size:

| Function | Returns | Tag |
|---|---|---|
| `chinese_area(board)` | `i8` (Black-positive) | **PROVEN** — thin wrapper over `rules.area_score` |
| `is_definitive(board)` | `bool` | **PROVEN** — thin wrapper over `rules.is_settled` |
| `dame_regions(board)` | count + point indices | **PROVEN** — empty regions touching both colours |
| `territory_japanese(board)` | `{black, white}` | **CLAIMED** — surrounded empty only; no stone/dead removal |
| `dead_stone_estimate(board)` | dead lists + contested count | **CLAIMED heuristic** — conservative domination rule |
| `make_report(board)` | composite `ScoreReport` | composition of the above tags |

The conservative dead-stone rule: a chain is `dead` iff it is **not**
Benson-alive and **every** one of its liberty regions is dominated by an
enemy Benson-alive group.  "Dominated" means the region borders at least one
enemy stone, the only friendly stones it borders are the chain itself, and
all enemy stones bordering it are Benson-alive.  Anything else is
`contested`.  This deliberately under-claims: one-eye groups, capturing
races, and shared-liberty groups are all contested.

### GTP surface

Three new commands are listed in `KNOWN_COMMANDS` so Sabaki/gogui discover
them:

- `weizigo_settled` → `yes` / `no`
- `weizigo_estimate` → one-line summary:
  `B+X / W+Y (area), territory B+tb/W+tw, dame N, dead B+db/W+dw, <definitive|provisional>`
- `weizigo_score` → multi-line human-readable report with the same data plus
  dame-point vertices, dead-stone vertices, contested-chain count, and status.

`final_score` keeps its existing Sabaki-compatible single-string reply.  When
the board is not settled it prints a stderr/log warning:
`# provisional: N dame, M non-alive chains (dead stones counted as alive)`.

## Non-promises

- The score report is **board-only**.  It does not claim the fresh-start oracle
  value and does not bound the real-game PSK score.
- `territory_japanese` is intentionally incomplete Japanese scoring: it does
  not remove dead stones and may under-count because Benson-alive is
  conservative (some alive groups are not Benson-alive).
- `dead_stone_estimate` is a heuristic, not a life/death oracle.

## Deferred items

- Stronger two-eye / life-and-death estimator.
- Dead-stone-based resign.
- Oracle-backed fresh-start "who's winning" estimate (GHI-tainted, separate
  task requiring user decision).

## Consequences

- `src/gtp.zig` imports `src/score.zig`; `src/score.zig` imports only
  `src/rules.zig` and `std`.
- `zig test src/score.zig` covers the pure geometry; `zig test src/gtp.zig`
  covers the GTP vertex mapping regression.
- No artifact or `data/` writes are introduced.
