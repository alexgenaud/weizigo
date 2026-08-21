# Model-performance — pointer (the full log is archived)

**Status: thin pointer.** On 2026-08-21 (T565) the ~4,150-line prose impression log that
lived here was restructured per `measurement-methodology.md` §8:

- **The full historical log** (belief-audit Class A/B/C, dated anecdotes, Boss-era notes,
  tenure scorecards, the 2026-08-21 impressions section) → **`docs/infra/archive/model-perf-2026-08-21.md`**,
  stamped *"impressions, not measurements; not evidence of ranking"*. Historical line-number
  citations into the old file resolve there with **+9 lines**.
- **Canonical facts** (context windows, label normalization, serving-tag/epoch rules, short-name
  table, model versions) → **`docs/infra/model-registry.md`**.
- **Structured measured cells** (T447 blind scores, T371, T451–T453, T369, T443, T444, re-keyed
  onto the 8 operator types) → **`docs/infra/model-task-metrics.jsonl`**.
- **Dispatch policy + task types** (the 8 operator types, measured-cells matrix, qwen scope,
  the local-model rule) → **`docs/infra/model-task-matrix.md`** (unchanged by this restructure
  except the retired 2026-08-18 cost stance).
- **Appetite / budget authority** → `measurement-methodology.md` §1 (the appetite table).

The old path is kept live so existing citations do not dangle (claimlint C2). New observations
go to the JSONL (measured) or the archive append (impressions), not here.
