# Bake-off protocol — head-to-head model races (T328)

**Status:** live protocol, first implementation landed 2026-08-05 (T328).
**Task:** T328 · **Role:** worker · **Model:** deepseek-v4-flash · **Date:** 2026-08-05

The human wants to race models head-to-head on a bounded task whose result is
exactly one output file, measuring speed and (blind-graded) quality, toward
quality/speed and quality/price rankings (human, 2026-08-03). This document is
the protocol; `tools/bakeoff.sh` is the harness that executes it.

## 1. What a bake-off is

One **task brief**, N **lanes** (one per model), one **output file per lane**
(`untracked/bakeoff/<run>/<model>/out.md`), one **blind grader** scoring the
outputs against an **answer key** sealed before any dispatch. The report
states quality, wall-clock, and cost per lane with denominators.

**The n=1 caveat is standing:** one run per model is an anecdote, not a
ranking. The protocol supports repeat runs (fresh `--run` name, same brief,
same roster) — a ranking is only claimed from multiple runs, and every run
states its run id, date, and roster so repeats are identifiable.

The first real race is a **separate kanban row** whose task choice gets its own
answer key. T328 built the plumbing and proved it with a trivial dry run
(§7) — the dry-run task is not a race and carries no key.

## 2. The harness

```sh
tools/bakeoff.sh <brief> <roster> [--run NAME] [--emit] [--wall N] [--claude-tools S]
```

- `<brief>` — task brief path. Its text becomes the prompt, **byte-identical
  per lane** (the harness prepends a fixed header; the brief portion is the
  same string object for every lane).
- `<roster>` — one lane per line: `#` comments allowed, blank lines skipped.
  ```
  <family> <canonical-label> [<ollama-serving-tag>]
  ```
  Families and their dispatch mechanisms:

  | family | dispatch | notes |
  |---|---|---|
  | `deepseek` | `pi --provider deepseek --model <label> --no-session -p <prompt>` | pi harness; needs `DEEPSEEK_API_KEY` in env |
  | `claude` | `claude -p <prompt> --model <label> --allowedTools <tools> --output-format text` | headless Claude Code session (below) |
  | `ollama` | `ollama launch pi --model <tag> -y -- -p <prompt>` | **serving tag required** (third field, e.g. `glm-5.2:cloud`) — the label alone does not pin what is served |

  Labels must be canonical (`src/managent/main.zig` `canonical_models`; the
  table is in `docs/infra/delegation/DELEGATEE.md` §Identity) — the harness
  rejects anything else. Duplicate labels in one roster are refused (out
  directories would collide).

- `--run NAME` — run directory under `untracked/bakeoff/` (default a
  timestamp). **A run directory is never overwritten** — a rerun needs a fresh
  name; that is how repeat runs stay comparable.
- `--emit` — print the per-lane shell commands and execute nothing. The
  emitted block is self-contained (it writes `prompt.txt` and the lane
  directories itself), so a human can paste it into one console and run every
  lane from the same start conditions (queue position, API state). Use this
  when start-condition comparability matters more than the sequential default.
- `--wall N` — `tools/runner --max-wall` guard in seconds (default 1800).
- `--claude-tools S` — the `--allowedTools` value for claude lanes (default
  `"Read,Write,Edit,Bash"`). Narrow per task, e.g.
  `--claude-tools "Read,Write,Edit,Bash(zig build test)"`.

Per-lane layout (`untracked/bakeoff/<run>/`):

| path | contents |
|---|---|
| `prompt.txt` | the exact prompt bytes (identical per lane) — the brief text record |
| `roster.txt` | copy of the roster used |
| `tokens.template.md` | operator token-readout table (§5), created per run |
| `<model>/out.md` | the lane's stdout — **the deliverable** |
| `<model>/trailer.log` | `tools/runner` stderr: argv echo, guards, exit line (wall), peak RSS/CPU per PID |
| `lanes.json` | the **dispatch record**: lane map, exact command, clocks, status — written at run close |

Every lane runs under `tools/runner`, so every lane has the RSS/wall/CPU
guards, a heartbeat record in `untracked/heartbeat.jsonl`, and a trailer with
**both clocks** (wall and CPU) and peak RSS. Lane identity for reporting is
read from `lanes.json` — never from the model (attribution doctrine: a model's
self-report is not evidence; `T320`, `T321`).

Lanes run **sequentially** by default: deterministic, and no two lanes share
the credential at once (see `docs/infra/agents/subdelegation.md` for the
current parallelism limits — ANALYSIS unlimited, MUTATION serial). Parallelism,
when the human wants it, is the `--emit` block backgrounded in one console.

### Worktree execution and the isolation boundary (T376)

`tools/bakeoff.sh` resolves the repository root with
`git rev-parse --show-toplevel`, which accepts both forms of `.git`: a
directory (normal checkout) and a **file** carrying a `gitdir:` pointer (git
worktree). `execute()` therefore runs correctly from inside a worktree — the
harness's own dispatch path, not the `--emit` block, is the supported way to
run a race (T371 had to fall back to `--emit` because the old `find_root`
required `isdir(.git)`; T376 fixed it and proved one lane end-to-end).

Races whose answer keys must stay out of lane reach run from a **git
worktree**: a worktree contains only committed content, so gitignored state
like `untracked/race-keys/` and `untracked/race-grading/` does not exist in
the lane's view at all. The harness records the isolation context in
`lanes.json` — `isolation.root`, `isolation.root_is_worktree`,
`isolation.lane_cwd` — so every run document can state exactly what a lane
could reach.

**The true strength of that boundary:** it is a *relative-path* boundary, not
a sandbox. A lane granted tools (pi lanes have tools by default; claude lanes
get `--allowedTools`) can read the main checkout's gitignored files via
**absolute paths** from inside a worktree — or by relative paths when the
harness runs from the main checkout itself. The boundary is "a boundary plus
a convention": the harness header instructs the lane to run no shell
commands unless the brief requires it, and race briefs are self-contained by
design. That convention is real but unenforced. **Do not describe worktree
isolation as a guarantee.** A run that needs true isolation (a hostile lane)
needs OS-level sandboxing or per-family tool restriction (e.g. `--no-tools`
on pi lanes); see the sized finding in `findings/T376-bakeoff-worktree.json`
— not built this row.

### Headless Claude lanes — exact flags

Claude Code supports headless dispatch: `claude -p "<prompt>" --model <model>`
executes one prompt non-interactively and exits. Running a Claude model in its
own harness this way is ruled acceptable from any dispatcher (2026-08-03,
`docs/infra/agents/subdelegation.md` §Depth-enforcement ruling, Clarified) —
the model still runs inside its own permission system.

Flags the harness emits for a claude lane:

```sh
tools/runner --max-wall <N> -- claude -p "<prompt>" --model <model> \
    --allowedTools "Read,Write,Edit,Bash" --output-format text
```

- `-p, --print` — non-interactive: print response and exit. The workspace
  trust dialog is **skipped** in this mode (no interactive prompt can appear).
- `--model <canonical-label>` — the serving model (Claude Code resolves the
  tag; the canonical label is what the ledger records).
- `--allowedTools` — **explicit tool permissions are required**: without them,
  headless mode cannot grant a permission interactively and any tool use that
  needs approval fails. The default `Read,Write,Edit,Bash` covers the project's
  usual task shapes; narrow per task (e.g. `Bash(zig build test)` instead of
  bare `Bash`). `--dangerously-skip-permissions` is deliberately NOT used —
  it bypasses all permission checks and is not needed for bounded tasks.
- `--output-format text` — the plain final response goes to stdout, which the
  harness redirects to `out.md`. (`json` / `stream-json` exist for structured
  capture; text is the lane default.)

**Execution gate:** claude lanes execute only when `WEIZIGO_BAKEOFF_ALLOW_CLAUDE=1`
is exported; without it the lane is refused (status `refused` in `lanes.json`)
and the run exits 1 naming the lane. `--emit` always shows the claude command.
This makes the T328 bar ("no `claude -p` execution from this row — emit only")
structural, and makes accidental claude spend a deliberate act. T328 never
exports the variable.

### Credentials

No API keys in argv, ever: `tools/runner` echoes argv to the trailer and the
heartbeat writer records it, so an `--api-key` flag leaks the key into
evidence on every dispatch (observed and redacted 2026-08-02). DeepSeek lanes
read `DEEPSEEK_API_KEY` from the environment; the harness refuses a deepseek
lane when the variable is unset.

## 3. Protocol — answer-key-first (T316-hardened)

1. **Answer key first.** The task choice, its rubric, and the answer key are
   written and **committed BEFORE any dispatch**, and the commit hash is
   recorded in the findings. (T316's lesson: the key must predate the first
   lane, or the race is unfalsifiable.)
2. **Identical brief text per lane.** The harness passes the same prompt
   string to every lane; `prompt.txt` is the record. No lane sees a
   differently-worded brief.
3. **The brief must not contain its own answer.** A brief whose "expected
   output" is visible to the lane is a echo test, not a measurement.
4. **Blind grading.** The grader receives **anonymized outputs** — lane
   identity stripped, labels replaced by A/B/C — and the **lane map is sealed
   in the findings** (the `lanes.json` dispatch record) until grading is
   done. The grader scores against the key; only after scoring is the map
   unsealed and the report written.
5. **Mechanical anchors first.** Every rubric criterion that can be a command
   (file exists, output matches a regex, `zig build test` passes, denominator
   present) is scored by **running the command**, not by the grader's
   judgment. The grader judges only the residual prose/design quality.
6. **Grader validity — the grader is an instrument, so instrument rules
   apply:**
   - **Null control:** before scores count, the grader must score two
     near-identical outputs within one rubric step of each other. A grader
     that separates twins is noise.
   - **Seeded-defect control:** the grader must rank a deliberately
     defect-seeded copy of an output below its clean twin. A grader that
     cannot is blind, and its readings are void.
   - **Family exclusion:** an LLM grader must not share a model family with
     any lane it grades (self-preference bias — Zheng et al. 2023, "Judging
     LLM-as-a-Judge"). When that leaves no eligible grader, use two graders
     from different families, neither sharing a family with the lane they
     favour, and report inter-grader agreement alongside the scores.
   - **Label hygiene at ingest:** lane identity comes from the dispatch
     record (`lanes.json`) only. A run whose lane map cannot name the exact
     serving tag (e.g. a preview-channel model bump — the 2026-08-05
     DeepSeek bump kept the V4 label) is not comparable across dates and must
     record the tag it measured.
7. **Report with denominators.** Quality is a fraction of what was checked,
   not a count of what passed. A rate without its denominator is not a
   measurement (QA-023 standing rule).

## 4. What is measured per lane

- **Both clocks, always.** Wall time AND CPU time (system runtime) from the
  `tools/runner` trailer (`[runner] exit N in S s` for wall; the peak-total-CPU
  lines for CPU). Wall measures latency the operator feels; CPU measures
  compute. A lane that waits on a queue looks slow on one clock and cheap on
  the other — the report must let the reader tell which.
- **Peak RSS** from the trailer (guards and memory behaviour; a lane that was
  RSS-killed is reported as such, never as a normal completion).
- **Tokens — human-collected, by protocol.** Agents cannot read their own
  meter; the harness console can. The operator step, at each lane's close:
  record the console readout **verbatim** — percent, window denominator,
  harness — into the run's `tokens.template.md`, then convert to absolute
  tokens (3.1% of 1.0 M ≈ 31,000). **A lane without a token reading is
  reported as such, never estimated.** The operator also records the exact
  serving tag the console shows (label hygiene, §3.6).
- **Tokens now, prices later.** Findings record the measured quantity
  (tokens, both clocks) — **never a dollar figure**: token prices vary by
  model, by date, even by hour of day. Prices live in a separate dated price
  table in `docs/infra/model-perf.md`, and quality/price is computed at query
  time: "which model is cheapest for task type X at today's prices" must be
  answerable years later from the recorded tokens alone.

## 5. Reporting

Each run's findings file reports, per lane: quality score (blind), wall, CPU,
tokens (or "no reading"), and the run's date + serving tag. Derived metrics:

- **quality/speed** — score ÷ wall (state the denominator: per lane, same
  task, n=1).
- **quality/price** — score ÷ cost, where cost is computed **at query time**
  from the recorded tokens × today's price-table row; the findings file holds
  only tokens.

The n=1 caveat accompanies every such ratio. A repeat run is a new `--run`
with the same brief and roster; multiple runs are required before a ranking
claim is worth making.

### Retried lanes (T376)

A lane may stall (observed: a deepseek-v4-flash attempt-1 API stall,
2026-08-05 — 600 s wall with near-zero CPU, 0 output; waiting, not compute).
When a lane is retried:

- **The completing attempt's clocks and output are the scored ones.** The
  stalled attempt's near-zero CPU is not a capability signal; its wall time
  measures the API's behaviour that day, and both are still recorded.
- **The retry is disclosed in the run document**: attempt count, why each
  non-completing attempt stopped (trailer exit line / kill reason), and which
  attempt's clocks were scored.
- **Attempt artifacts are preserved verbatim, never overwritten**
  (`out.md.attempt1`, `trailer.log.attempt1`, …). A retried lane is a
  validity question for timing comparisons, not a no-op — a run with a
  retried lane reports it as such.

## 6. Dry-run demonstration (T328, 2026-08-05)

Fixtures: `tools/bakeoff-dryrun-task.md` (trivial, not graded — explicitly
not an answer-keyed task) and `tools/bakeoff-dryrun.roster` (one deepseek
lane + one claude lane).

1. **Emit** — `tools/bakeoff.sh tools/bakeoff-dryrun-task.md
   tools/bakeoff-dryrun.roster --run dryrun --emit` printed both lane
   commands, including the exact headless Claude invocation
   (`claude -p ... --model claude-opus-5 --allowedTools Read,Write,Edit,Bash
   --output-format text`), and executed nothing.
2. **Execute** — `tools/bakeoff.sh ... --run dryrun-2026-08-05b` ran the
   deepseek lane end-to-end through `tools/runner` and refused the claude lane
   (gate unset, as this row requires):

   ```
   RESULT deepseek-v4-flash family=deepseek serving_tag=deepseek-v4-flash status=ok exit=0 wall_s=1.7 cpu_s=0.48 rss_mb=194 out_bytes=18
   RESULT claude-opus-5 family=claude serving_tag=claude-opus-5 status=refused exit=None ... note='WEIZIGO_BAKEOFF_ALLOW_CLAUDE unset — emit only (T328 bar)'
   ```

   - `out.md` landed, containing exactly `BAKEOFF-DRYRUN-OK\n` (18 bytes).
   - `trailer.log` captured the runner trailer: `[runner] exit 0 in 1.7 s`,
     peak RSS 194 MB, peak total CPU 0.48 s.
   - `lanes.json` (the dispatch record) written with the lane map, exact
     commands, clocks, and statuses.
   - Run exited 1 (the refused claude lane), as designed.

Evidence: `untracked/bakeoff/dryrun-2026-08-05b/` (gitignored; SHA-256 of
`out.md`, `trailer.log`, `lanes.json` recorded in `findings/T328-bakeoff.json`).

### Worktree proof (T376, 2026-08-05)

`execute()` from a git worktree, end-to-end: a fresh worktree at
`/tmp/weizigo/lane-wt-t376` — EVIDENCE LOST (path was /tmp, destroyed before rescue on 2026-08-08) — (committed content only), one deepseek lane
(roster `deepseek deepseek-v4-flash`, brief `tools/bakeoff-dryrun-task.md`),
run `tools/bakeoff.sh ... --run t376-worktree-proof-20260805` from inside the
worktree. Result: `root=<worktree> worktree=True` in the summary;
`out.md` = `BAKEOFF-DRYRUN-OK`; trailer captured both clocks + peak RSS;
`lanes.json` records `isolation.root_is_worktree: true`; `untracked/race-keys/`
and `untracked/race-grading/` absent from the lane's view. Durable run dir
copied to the main checkout's `untracked/bakeoff/t376-worktree-proof-20260805/`
(gitignored); SHA-256 of `out.md`, `trailer.log`, `lanes.json` recorded in
`findings/T376-bakeoff-worktree.json`.

## 7. Security and hygiene notes

- Credentials by environment only (§2); runner guards on every lane.
- `untracked/bakeoff/` is the one state area; nothing is written to `docs/`,
  `src/`, `data/`, or `artifacts/` by the harness.
- Run directories are immutable after close: never overwrite, and never edit a
  `lanes.json` in place — a corrected run is a new `--run`.
- The claude gate (§2) is the deliberate-spend control: a bake-off that
  executes claude lanes is an explicit, env-var-backed act.
- **Worktree isolation is a relative-path boundary, not a sandbox** (§2,
  "Worktree execution and the isolation boundary"). The harness records
  `isolation.root` / `root_is_worktree` / `lane_cwd` in `lanes.json` so the
  run document can state what a lane could reach; it does not (and cannot,
  cheaply) prevent a tool-using lane from reading the main checkout by
  absolute path.
