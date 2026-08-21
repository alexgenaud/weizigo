# Per-family topology record — pass-1 `managent own` verb (§3 residual check)

**Claim-id:** `orcha-pass1-perfamily-topology` · **Owner:** deepseek-v4-pro / T556 ·
**Date:** 2026-08-21 · **Gate:** the seeded arms S1–S3 / I1 / I2 are final for a family
only after its record lands here; until then they are final only for `claude -p`
(`01-spec.md` §3).

The pass-1 verb enumerates descendants by session/group/ppid edges. The §3 residual
check asks, per console family: (a) is the tool-command root a session leader
(`pgid == sid == own pid`)? (b) is the runner's child a session leader at spawn?
(c) does anything in the chain change session? (d) how deep is the tree to the deepest
compile/tool child? Answering these determines whether the sid catch-all (OWN-2) and the
`--seed` term contribute members for that family, or whether the family needs a
different design.

| family | (a) tool root is session leader | (b) runner child is session leader | design consequence | status |
|---|---|---|---|---|
| `claude -p` | yes (measured, the reference) | yes (`tools/runner:1210`) | sid catch-all + descendant walk work as designed | **PROVEN** (reference measurement) |
| DeepSeek CLI (`pi --provider deepseek`) | **yes** — measured 2026-08-21 (below) | **yes** — measured 2026-08-21 | identical to claude — no design change | **CLAIMED** (single-seat, reproducible) |
| ollama (`ollama launch pi`) | expected yes (same `pi` binary; unmeasured) | yes | **the model runner is daemon-owned, outside the dispatched tree** — the load-bearing fact | **CLAIMED** (measured D14/D15) |

Per-family detail: `deepseek-family.md`, `ollama-family.md`.

**Promotion path:** each CLAIMED record carries the exact reproducible command; an
independent seat re-running it (or a second console's `ps`+`getsid` snapshot) promotes
it to PROVEN. The DeepSeek measurement is mechanical (a snapshot, not a judgment), so
the promotion is a formality; the ollama daemon-ownership fact was observed twice
(D14 qwen orphan, D15/gem12 peak-RSS blindness) but by one seat lineage.
