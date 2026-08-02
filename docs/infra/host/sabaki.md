# Sabaki — play against the 4×4 oracle (T263)

## Engine

| field | value |
|---|---|
| Name | weizigo 4×4 |
| Path | `bin/weizigo-gtp` |
| Arguments | `untracked/oracle-v2/oracle-4x4-v2.wzo2` |
| GTP version | 2 |

## Add to Sabaki

1. **File → Preferences → Engines → Add**
2. Fill the fields above.
3. **File → New →** set `boardsize 4`, komi any, attach the engine to Black
   or White.
4. Play.

## Notes

- Komi 0 is the artifact's native scoring; the engine subtracts Sabaki's komi
  from the area score on `final_score`.
- `weizigo-stats` (custom GTP command) prints lookup/miss/fallback counters.
- The artifact is ~494 MB; loading takes a few seconds on first `genmove`.
