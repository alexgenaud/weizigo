# T774 — cost repeatability control: protocol and results

**Task:** `T774` (cost repeatability race) · **Landmark:** L1 (measurement integrity)
**Worker:** deepseek-v4-flash/T774 · **Date:** 2026-08-23
**Consumes:** T772's ratified direction — cost re-enters model selection only when this
gate shows the number is repeatable enough to rank on.

## 1. Question

When the same model runs the same sealed brief repeatedly in fresh contexts, how much do
**total tokens**, **cpu-seconds**, and **peak rss** move? What coefficient of variation
would make cost rankable, and is it met?

## 2. Design (T626's score-spread race applied to cost)

| axis | choice | rationale |
|---|---|---|
| models | `deepseek-v4-flash` (DeepSeek lane), `claude-opus-5` (Claude lane) | the cheap DeepSeek family the ladder could never meter + the highest-spend Claude model. `deepseek-v4-pro` remains unmeasured (follow-up) |
| brief shapes | M: short mechanical census (`docs/infra/runner.md` citation-existence); A: long read-only audit (the token/cpu/rss measurement surface) | the two ends of the ladder's row mix; a short deterministic row and a long analysis row |
| repeats | N=5 per cell, 4 cells, 20 runs | brief: N ≥ 5 |
| independence | fresh context per repeat (pi `--session` new file / claude `-p` new process), byte-identical sealed prompt, frozen worktree at `2ec4f93` reset+cleaned before every repeat | T626's method |
| order | interleaved r1..r5 × (ds-m, op-m, ds-a, op-a) | no cell's repeats cluster in one load/time-of-day band |
| launch | tools/runner (the ordinary-lane wrapper: wall/CPU/RSS guards, token capture, run records). **Not** via `bin/dispatch`: T774 is a leaf at the delegation cap (WEIZIGO_AGENT_DEPTH=3, bin/dispatch refuses `depth >= MAX_DEPTH`), so the repeats are driven T626-style; the measurement surface is identical to ordinary lanes (run records + heartbeats + session/envelope meters) | leaf constraint; recorded deviation |
| meters | tokens from `read_pi_session` (pi lanes, `--session <file>`) / `parse_claude_envelope` (claude lanes, `--output-format json`); cpu-seconds + peak rss from the runner's own meters; wall recorded as a fact (load-affected, not rankable — T626 §3) | the instrument the cost ladder actually uses |

### Seals (sha256 of the exact prompt bytes passed to every repeat)

Verified byte-identical to the briefs in this directory (`seals.txt`):

```
fd42042f0aac843fe0b69914821e5887be97764d42b7f61d6671cd83bffbf8e0  brief-m.txt
eb68252b7a817bc9db7262fb1bf85c1a38fce76089992eb777ab063004b7e208  brief-a.txt
```

### Thresholds proposed (the recommendation T772 consumes)

Let CV = sd/mean of a meter across a cell's N repeats.

- **CV ≤ 0.05:** the meter is rankable on this (model, shape) cell with confidence; cost may be
  compared between models on this shape.
- **0.05 < CV ≤ 0.15:** rankable only for gaps ≥ 2× the cell's sd; a consumer must carry the
  band (mean ± 2 sd) and require band-disjointness before ranking two models.
- **CV > 0.15:** not rankable on this shape — the reading is one draw from a wide
  distribution (T626's lesson: the single-shot reading that crowned a rank-1 was one draw
  from a spread as wide as the field it beat).

Primary meter: **total tokens** (tokens_in + tokens_out) — the ladder's own unit. The
fresh/cache split is reported separately because cache ratio changes price by >10×.
cpu-seconds and peak rss are secondary (battery-shape meters) and get the same CVs.

Caveat built into the recommendation: N=5 makes the CV estimate itself noisy; the raw numbers
are published so the consumer sees the distribution, not just the summary.

## 3. Controls (run before any live reading)

`controls.py`, three arms + runner smoke (output in `controls-out.txt`):

- **Null arm** — the same real pi session file parsed twice by `read_pi_session` yields
  byte-identical dicts; the same claude envelope parsed twice yields identical usage.
- **Seeded arm** — a fixture pi session with hand-written known usage (2 turns + 1 summary:
  input 147, output 73, cache_read 200, cache_write 5, reasoning 16, turns 2) reproduces
  exactly; a fixture claude envelope (input 10, output 20, cache_read 30, cache_write 40,
  reasoning 5, total 100) reproduces exactly.
- **Negative arm** — no session header, missing file, empty claude output, is_error
  envelope all return UNKNOWN (never 0).
- **Runner smoke** — `sleep 2` under tools/runner: exit 0, wall 2.5s, cpu 0.0s, rss 1 MB,
  run record finalized with the meter fields.

**Result:** all checks pass **except one instrument defect** (exit 2 by design):

> **T774-control-1** — `read_pi_session` (tools/token-capture.py) counts ANY assistant
> message as a "usage-bearing turn", so a session whose assistant turn carries no `usage`
> object returns `ok=True` with all-zero totals. The documented failure reason
> "no usage-bearing turns" is unreachable for this case; a truncated or usage-less session
> reads as a **free completed run** — the exact silent-zero class the docstring claims to
> prevent ("A caller must treat ok=False as UNKNOWN — never 0"). `tools/token-capture.py`
> `read_pi_session` (~line 380: `turns += 1` fires before the usage check).
> **Not fixed here** (T774 makes no mechanism changes; T772's successor owns it).
> **Guard applied to this battery's live readings:** any repeat whose run record carries
> `tokens_source` null/missing or zero tokens is treated as UNKNOWN/DNF, never as 0.

## 4. Results

**20/20 repeats complete** (N=5 per cell × 4 cells). T774.1 drove 13 before its
runner wall killed the drive mid-flight; T774.2 (deepseek-v4-pro, this row's
completer) drove the remaining 7 via `resume.sh` in `untracked/bakeoff/`
(interleaved, same `cell_run` as `drive.sh`), re-running `op-a r2` after a
host-memory-guard kill and `ds-a r4` after a torn (never-finalized) record.

See `results.csv` (per-repeat meters) and `analysis-out.json` (per-cell spreads,
from `analysis.py`). Committed per-repeat evidence is under `records/` (all 20
run records + the 10 claude lane text reports as `.out.md`). DeepSeek session files stay in
`untracked/bakeoff/t774-cost-repeatability/<cell>/r<N>/` (gitignored; sha256 in
`results.csv`). Final numbers and the recommendation are in
`findings/T774-cost-repeatability.json`.

## 5. Provenance

- Briefs: `brief-m.txt`, `brief-a.txt` (this directory, sha256 sealed).
- Drive: `drive.sh` (this directory) — reproduces the battery.
- Resume (T774.2): `resume.sh` (this directory) — drove the 7 completing repeats after T774.1's wall kill.
- Controls: `controls.py` + `controls-out.txt`.
- Frozen tree: `/tmp/weizigo/t774-frozen` @ `2ec4f93` (disposable; results carry hashes).
- Identity per repeat: `MANAGENT_TASK_ID=T774-<cell>-r<N>` (env var, so no kanban row is
  auto-claimed/done); run records copied into the main repo at
  `untracked/bakeoff/t774-cost-repeatability/<cell>/r<N>/run-record.json`.
