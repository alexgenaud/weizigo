# Shared harness p95 table — fuse thresholds

**Rule:** operator ruling **§7c.34** — the population rule every fuse reads,
verbatim:

> **Completed real work only.** Exclude killed attempts (a kill measures when
> we stopped a lane, not how long its work takes). Exclude bakeoff gate
> sub-runs (harness scaffolding, not work). One shared table, published, with
> the rule stated on it; every fuse reads from it. No fuse derives its own
> denominator privately again.

**Computed at commit:** `980d77c1a4ff3626a7238e32e9298a21c455c487` (the full SHA of the working
tree this snapshot was derived from). **Regenerated, not recomputed at read** —
see §Argument. The run-record input is the host-local `untracked/runs/` store,
which is NOT in git; the per-family `n` and the exclusion counts below are its
fingerprint, so a reader can tell whether the store has drifted since.

## Per-family table

| family | n | p50 (s) | p95 (s) | p99 (s) | max (s) | fuse threshold (3 × p95, ceil) | fuse |
|---|---|---|---|---|---|---|---|
| pi (deepseek) | 75 | 987.30 | 2415.08 | 2570.20 | 2638.80 | 7246 | agent progress (T643/T659) |
| claude | 36 | 548.35 | 1505.15 | 2374.92 | 2691.50 | 4516 | liveness (T634/T659) |
| ollama | 9 | 303.50 | 2255.02 | 2323.72 | 2340.90 | 6766 | agent progress (T643/T659) |

`other` (non-agent harness fixtures — regression stubs, `zig build`-shaped
runs) is not a worker-lane population and carries no fuse.  Records under
subdirectories (e.g. `archive-2026-08-20/`, 30 pre-T515 pid-named degraded
records) are out of scope: the recompute reads only top-level `*.json`, and
those 30 are all non-agent `other` fixtures anyway.

## Exclusions applied (what was thrown away, and why)

| exclusion | count |
|---|---|
| killed attempts (agent lanes) | 6 |
| killed attempts (non-agent fixtures) | 12 |
| killed attempts, no surviving record | 2 |
| bakeoff gate sub-runs | 56 |
| incomplete (launch-only / in-progress) | 14 |
| non-agent fixtures (family `other`) | 19 |
| unparseable records | 1 |

**Killed agent lanes** (walls censored, not samples — each is excluded):

- T527 (claude) 869.8 s
- T531 (claude) 1754.6 s
- T616 (claude) 600.8 s
- T573 (pi) 2701.0 s
- T638 (pi) 1901.3 s
- T643 (pi) 1706.8 s

**Killed attempts with no surviving record** (overwritten pre-T650 a4eac54;
kills proven by `untracked/log/`, absent from the store):

- T526 (pi) 1129.6 s
- T635 (pi) 1732.6 s

**Incomplete records** (launch-only or in-progress, no `exit`/`end`):

- T591
- T601
- T603
- T604
- T606
- T626
- T627
- T628
- T636
- T659
- T662
- T663
- T665
- T666

**Unparseable records** (skipped, never guessed):

- T555.json (Extra data: line 2 column 1 (char 5109))

**Seeded control:** all five known watchdog/liveness kills are absent from the
p95 population — T526 (pi, 1129.6 s), T635 (pi, 1732.6 s), T638 (pi, 1901.3 s),
T616 (claude, 600.8 s), T643 (pi, 1706.8 s).

## Argument: regenerated on a schedule, not recomputed at each fuse read

The table is **recomputed-and-committed** by `tools/runner --recompute-harness-p95`
and the runner **reads the committed table** at each fuse read.  Not recomputed
at read, because:

1. **Reproducibility across hosts.** `untracked/runs/` is host-local and
   gitignored — it does not survive a fresh clone.  A recompute-at-read fuse
   would have no population on a fresh clone and a different threshold on
   every host; a fuse threshold must be identical wherever the runner runs, or
   a pass/fail is not reproducible.  Only the committed table gives that.
2. **The cost buys nothing.** Reading hundreds of JSON records and sorting on
   every dispatch is pure overhead; one new run moves a family p95 by seconds,
   far below the fuse's minutes-long threshold.
3. **Staleness is detectable, not silent.** The recompute is a single
   deterministic command (wired as a byte-identical regression), and a
   staleness check — "records landed since the table's commit" — is a cheap
   gate on the regeneration cadence.
4. **The published table must be the real one.** A recompute-at-read design
   would leave the committed markdown describing thresholds that no longer
   exist; the ruling demands the published table BE the source.

<!-- BEGIN harness-p95 -->
```json
{
  "computed_at_commit": "980d77c1a4ff3626a7238e32e9298a21c455c487",
  "families": {
    "claude": {
      "max": 2691.5,
      "n": 36,
      "p50": 548.35,
      "p95": 1505.15,
      "p99": 2374.92,
      "threshold_s": 4516
    },
    "ollama": {
      "max": 2340.9,
      "n": 9,
      "p50": 303.5,
      "p95": 2255.02,
      "p99": 2323.72,
      "threshold_s": 6766
    },
    "pi": {
      "max": 2638.8,
      "n": 75,
      "p50": 987.3,
      "p95": 2415.08,
      "p99": 2570.2,
      "threshold_s": 7246
    }
  },
  "population_rule": "completed real work only (operator ruling §7c.34): exclude killed attempts; exclude bakeoff gate sub-runs",
  "schema": "harness-p95"
}
```
<!-- END harness-p95 -->
