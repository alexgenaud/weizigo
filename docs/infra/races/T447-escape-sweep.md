# Race T447 — read-only sweep for live-repo escape paths in the shell harness

**Protocol:** `docs/infra/bakeoff.md` (answer-key-first, blind grading).
**Ordered by:** the operator, 2026-08-18 — "run the same safe, conflict-free tasks across all
five-to-eight models… read-only audits are the ideal class", and the standing question of where
`deepseek-v4-pro` earns its cost against `deepseek-v4-flash`.
**Race director / grader:** claude-opus-5/orcha.

## Sealed before dispatch

The key and the brief were written before any lane existed. Their SHA-256 sums are committed
here **first**; the key text itself stays in `untracked/race-keys/` so no lane can read it.

| artifact | path (gitignored) | sha256 |
|---|---|---|
| answer key + rubric (30 pts) | `untracked/race-keys/T447-key.md` | `0d2ac295eb9b2493614a52159caa823084ed551523c77e14690dc9b039da2fd4` |
| lane brief (identical bytes per lane) | `untracked/race/T447-brief.md` | `12f79202c74da8c9d81fcb3906506f7f13aa603e703426e280bb7966909978f9` |

Both were derived against HEAD `11e3916`. Publishing the sums before dispatch is what makes the
grading falsifiable: the key cannot be edited after the outputs are read without breaking the
sum recorded in this commit.

## Task given to every lane

A strictly read-only audit of `tools/*.sh`: find every path by which a test harness can act on
the **live checkout** when it meant to act on scratch state. Report format fixed by the brief —
denominator first, then a table of sites (`file:line`, code, mechanism, reachable-or-not at
HEAD, severity), then a section of constructs checked and found **safe** (scored: a false alarm
costs as much as a miss), then residual questions with the command that would settle each.

The brief carries no part of the answer, and no lane is told how many findings exist.

## Roster

| lane | family | serving tag |
|---|---|---|
| `deepseek-v4-pro` | deepseek | `deepseek-v4-pro` |
| `deepseek-v4-flash` | deepseek | `deepseek-v4-flash` |
| `glm-5.2` | ollama | `glm-5.2:cloud` |
| `minimax-m3` | ollama | `minimax-m3:cloud` |
| `kimi-k2.7` | ollama | `kimi-k2.7-code:cloud` |

Not raced, with reasons: **Claude lanes** are excluded because the grader is `claude-opus-5` and
the protocol forbids a grader sharing a family with a lane it scores (§3.6) — the Opus/Fable
comparison the operator asked for needs a non-Claude grader and is a separate run. **qwen3.6**
(the local trial model — 3.8 is not pulled on this host) is excluded because local inference
would contend with the T369 console's measured suite runs. **kimi-k3** is excluded on cost.
The `kimi-k2.7:cloud` tag does not resolve on this host; `kimi-k2.7-code:cloud` does, and both
map to the canonical label `kimi-k2.7`.

## Status

Dispatched 2026-08-18 evening. Scores, both clocks, and the unsealed lane map land here when
grading is done. n=1 per lane: this is one race, not a ranking.
