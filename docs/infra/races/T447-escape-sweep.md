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

## Result — graded 2026-08-18, map unsealed after every score was written

| rank | model | score /30 | wall | output | the sentence that decided it |
|---|---|---|---|---|---|
| 1 | **deepseek-v4-flash** | **38** | 416.9 s | 13.8 KB | the only lane that saw the runner's heartbeat as a *live-tree write from a test harness*, and that `pilot_gate.sh:14` regenerates **tracked** artifacts before the verification meant to gate them |
| 2 | deepseek-v4-pro | 34 | 681.8 s | 10.8 KB | cleanest reachability discipline — every `mktemp` site ruled unreachable **because `set -e`**, verified by running `cd "$(false)"` under `set -e`; and it ruled `git-commit-mine:98` fail-CLOSED, which one lane got backwards |
| 3 | glm-5.2 | 30 | **359.6 s** | 26.2 KB | the only lane to open `tools/runner` and find `os.path.isdir(".git")` — blind inside a worktree (now T449). −2 for one fabricated citation |
| 4 | minimax-m3 | 27 | 428.0 s | 25.1 KB | broadest citation count (34, all in range) but reachability reasoned from impact rather than from `set -e`, and one self-contradiction |
| 5 | kimi-k2.7 | 25 | 372.3 s | 22.6 KB | −2: reported `tools/git-commit-mine:98` as letting a foreign path slip into a commit. Verified false — with an empty scope file every non-named path is foreign, so the wrapper **refuses** |

Scores exceed the 30-point rubric because verified findings outside the key earn +3 each.

### What the race actually settled

**All five lanes found a defect the answer key missed** — `tools/regression-argus-doctor.sh:195`
appends a seed line to the **live, tracked `AGENTS.md`** and restores it with an inline `cp` that
the `:110` EXIT trap does not cover. The T445 incident record lists "AGENTS.md +1 fixture line"
among the observed damage, so this is a mechanism that has already fired once. A five-model
field beat a single Opus key on the exact question the key was written for; that is the
strongest argument for racing that this project has produced.

Three rows came out of it: **T448** (grown — the `AGENTS.md` seed is now its first item),
**T449** (`tools/runner` worktree-blind), **T450** (`pilot_gate.sh` writes before it verifies).

### On the operator's standing question

Forced to choose between the DeepSeek pair on *this* task, the answer is **Flash** — it scored
higher, in 61 % of Pro's wall time, in half the words. Pro's edge was not depth of search but
**discipline**: it and Flash were the only lanes whose reachability verdicts were all correct.
**n=1 stands.** One race is an anecdote. What it does justify is refusing to pay for Pro on
read-only audit work until a race shows it earning the difference.

### Protocol compliance and its gaps

- Key and brief SHA-256 committed at `111c141`, **before** the first lane started. ✓
- Byte-identical prompt per lane (the harness's `prompt.txt`). ✓
- Blind grading: outputs anonymized A–E by a name-hash shuffle, the map sealed to
  `untracked/race-grading/t447/lanes-map.sealed.json` and opened only after every score was
  written. ✓
- Mechanical anchors scored by script (`untracked/race-grading/t447-anchors.py`), judgment
  applied only to the residue. ✓
- Family exclusion: no Claude lane, grader is Claude. ✓
- **Gap:** lanes ran in parallel from the `--emit` block, so the harness wrote no `lanes.json`.
  The roster plus the five `tools/runner` trailers are the dispatch record.
- **Gap:** the grader saw each lane's wall time and byte size before anonymizing. Only the
  **content** was blind.
- **Gap:** no token readings — an agent cannot read its own meter and the operator was not at
  the console. Reported as absent, never estimated.
- **Irony worth recording:** the lanes ran under `tools/runner` inside a worktree, so by T449 —
  which one of them found — none of them emitted a heartbeat.

### Late sixth lane — `qwen3.8:27b-mlx`, local, unscored

Run at the operator's request after grading closed, on the byte-identical prompt (sha256
`84ec2845…`), same `tools/runner`, same worktree. It was **killed by the wall guard**:

```
[runner] KILL: wall ceiling 2400s (40:00) reached at 2400.1s elapsed (no [progress] lines seen)
[runner] exit 124 … in 2400.4 s
```

Zero bytes captured — and because `pi` buffers stdout to completion, that reads as **no
completion inside 40 minutes**, not as "produced nothing". It is **not scored**: it neither
finished nor ran blind, since its identity was known to the grader.

It is still a useful reading, just of capability rather than quality: the five cloud lanes
finished this task in 359–682 s. The cause is the task shape — a repo-wide audit is dominated by
tool-call round-trips, and every one of them pays local generation latency. What that model is
suited to instead is written up in `docs/infra/model-task-matrix.md` §3.

Full per-lane detail: `findings/T447-regression-escape-sweep.json`. Lane outputs (gitignored):
`untracked/bakeoff/t447-2026-08-18/<model>/out.md`.

---

# Race 2 — T452 design question (2026-08-19)

Same protocol, different task type: **analysis / design**, not audit. One question ("what is the
correct fix, and is a correct fix possible without changing what the search measures?"), four
lanes, read-only, one output file each — conflict-proof by construction.

| artifact | path (gitignored) | sha256 |
|---|---|---|
| key + rubric (20 pts) | `untracked/race-keys/T452-design-key.md` | `573591a023addbeae3ce3fae4d8131b44b9af54726bf47f029887f480fc114d7` |
| brief (identical per lane) | `untracked/race/T452-design-brief.md` | `d5d62104658f0ee835b06a2725205e966dfdc453fcaaa92231dac850b084b64b` |

Roster: `deepseek-v4-flash`, `glm-5.2`, `kimi-k2.7`, `minimax-m3`. **minimax-m3 is deliberately
included** — it is the model whose abandoned attempt raised the question, and excluding it would
turn one incomplete row into a verdict about a model. The key awards its highest single score to
the answer *"no bounded fix preserves the semantics — here is the proof"*, so an honest refusal
is the winning move rather than a forfeit.

Status: dispatched 2026-08-19.
