# Model × task-type matrix — what has actually been measured, and where the holes are

**Operator ruling, 2026-08-18:** there is **no permanent default model**. Repeatedly choosing the
same model for a task type because that is what we chose last time is an unsound habit and ends
here. A model is selected for a task type when evidence says it is the most appropriate for
*that* type; every model is to be tried across task types, head-to-head where the work allows.

**This file is the dispatch policy, not a report.** An empty cell is a reason to dispatch — the
next row of that type goes to a model whose cell is blank, provided the row is safe to give away.

## Cost stance while it holds (operator, 2026-08-18)

1. **Ollama credits are plentiful** — prefer `glm-5.2`, `minimax-m3`, `kimi-k2.7`. Spend them.
2. Otherwise **`deepseek-v4-flash` over `deepseek-v4-pro`**: cheaper, and on the one measured
   race also faster and better.
3. **`deepseek-v4-pro` is worth trying on heavy, long-horizon, Opus/Fable-like work** — the one
   shape no race has measured. That is where its premium might be earned, if anywhere.
4. `claude-fable-5` sparingly, under 90 % of 200 k. `kimi-k3` excluded on cost.
5. **Local `qwen3.8:27b-mlx`** costs no credits at all but costs the machine — see §3.

## 0. Short names — operator ruling, 2026-08-19

**Short names are presentation only.** They are a convenience for prose and conversation, valid
*now*, and they carry no version meaning. `flash` is whatever DeepSeek-Flash we are running
today; if it silently becomes v5, `flash` still means "the flash we use". `kimi` is always "the
kimi we use" — K2.7 today, K3 if we ever switch, without a new short name.

**Every record — kanban, ledgers, findings, model-perf — writes the canonical label AND the
date.** That pair is what stays interpretable years later; a short name in a record is a defect.
Distinct short names are needed only when two models with confusable names run at the same time.

Preferred length 3–5 characters.

| short | canonical label today (2026-08-19) | serving tag where it differs |
|---|---|---|
| `opus` | `claude-opus-5` | — |
| `fable` | `claude-fable-5` | — |
| `sonnet` | `claude-sonnet-5` | — |
| `dspro` | `deepseek-v4-pro` | — |
| `flash` | `deepseek-v4-flash` | — |
| `glm` | `glm-5.2` | `glm-5.2:cloud` |
| `minimax` | `minimax-m3` | `minimax-m3:cloud` |
| `kimi` | `kimi-k2.7` | `kimi-k2.7-code:cloud` |
| `qwen` | `qwen3.8:27b-mlx` | local (MLX) |

## 1. The task types this project actually dispatches

| # | task type | what it demands | shape |
|---|---|---|---|
| T-A | **read-only audit / sweep** | breadth of search, discipline about reachability, resisting false alarms | one output file, no writes |
| T-B | **mechanism fix, test-first** | build a control before the fix, keep a red arm red | writes source + a regression arm |
| T-C | **diagnosis / bisect** | attach a commit to a symptom; cheap per-target runs, not brute force | reads + runs, writes findings |
| T-D | **ledger / absorption bookkeeping** | exactness over judgment; envelope conformance | writes JSON + register |
| T-E | **spec / design authoring** | long-form coherence, holding a whole argument | writes a doc |
| T-F | **adjudication of another model's work** | independence, willingness to overturn | writes a verdict |
| T-G | **brief refresh / staleness triage** | re-deriving citations at HEAD, noticing drift | writes briefs |
| T-H | **long-horizon sprint console** | keeps a plan across hours, dispatches its own leaves | manages |

## 2. Measured cells (new epoch only — the 2026-08-18 DeepSeek boundary is not crossed)

| | claude-opus-5 | claude-fable-5 | deepseek-v4-pro | deepseek-v4-flash | glm-5.2 | minimax-m3 | kimi-k2.7 | qwen3.8:27b-mlx |
|---|---|---|---|---|---|---|---|---|
| **T-A** audit | — | — | **34** (T447) | **38** (T447) | **30** (T447) | **27** (T447) | **25** (T447) | **no completion in 2400 s** (T447 late lane) |
| **T-B** fix | — | — | — | — | — | — | — | — |
| **T-C** diagnosis | — | — | **pass-w-findings** (T369) | — | — | — | — | — |
| **T-D** bookkeeping | — | — | — | **pass** (T443) | — | — | — | — |
| **T-E** spec | — | prior epoch only | — | — | — | — | — | — |
| **T-F** adjudication | — | — | — | — | — | — | — | — |
| **T-G** triage | — | — | **pass-w-findings** (T444) | — | — | — | — | — |
| **T-H** console | in flight | prior epoch only | — | prior epoch only (T363) | — | — | — | — |

Scores in **T-A** are the blind-graded T447 rubric (30 points; verified findings outside the key
earn +3, which is why the top scores exceed 30). Everything else is a single row's verdict, which
is weaker evidence than a race — a verdict says "the work was acceptable", not "better than the
alternative". **n = 1 everywhere.** No cell in this table justifies a ranking on its own.

## 3. What the local model is for — `qwen3.8:27b-mlx`

Measured 2026-08-18, and the reading is exact rather than impressionistic — given the T447 audit
brief (3,027-byte prompt, whole-repo reading) it was killed by the guard:
`[runner] exit 124 (wall ceiling 2400s (40:00) reached at 2400.1s elapsed (no [progress] lines
seen)) in 2400.4 s`, zero bytes captured. Because `pi` buffers stdout to completion that means
**no completion inside 40 minutes**, not "produced nothing". Five cloud lanes finished the same
task in 359–682 s. The reason is structural, not a defect: a repo-wide audit is dominated by
tool-call round-trips, and every one of them pays local generation latency.

**So it is the wrong tool for T-A, T-C and T-H, and the right tool for work with a small input,
a bounded output, and no deadline.** Its credits cost nothing; its cost is the machine.

Suited (small in, small out, judgment but no search):
- one-row **short-name generation** — `AGENTS.md` requires every row to be phrased as the
  question it answers, and much of the register predates that rule;
- **findings-envelope conformance** — the `task_id`/`model`/`claims` fix, one file at a time;
- **epitaph writing** for archived register rows (one line: what was tried, what it cost);
- **abbreviation-expansion sweeps** — the standing rule that every acronym is expanded at first
  use, one document at a time;
- **repeat-runs of an already-graded race brief**, overnight, purely to measure **within-model
  variance** — the thing every `n = 1` caveat in this project is waiting for, and the one job
  where slowness is free.

Not suited: anything on the critical path, anything that must grep the repo, anything whose
value decays if it lands eight hours late.

**Hard scheduling constraint:** no local inference during a measured suite run. An 18 GB model
takes the machine to load ~9.5, and load contamination is exactly what produced the bogus 35–52
minute suite readings on 2026-08-08. Any midnight job must check for a running suite first.

## 3b. Closed — the first T-B (mechanism fix) readings, 2026-08-18 21:53

Three crash-repair rows dispatched in parallel to three different models, same bars, same
acceptance shape:

| row | red being fixed | model |
|---|---|---|
| T451 | `t419_taxonomy` `@intCast` underflow | `glm-5.2` |
| T452 | `qa023_brute_2x2` node-budget explosion | `minimax-m3` |
| T453 | `vb_bellman_4x4` `board[0..16]` OOB | `kimi-k2.7` |

**What this design can say, and what it cannot.** Each row is a *different bug*, so this is
"same task type, different instance" — it fills three T-B cells with real verdicts, and it does
**not** rank the three models the way T447 ranked five on one identical task. A true T-B race
would hand the same defect to every lane, which would mean either three worktrees (the operator
has ruled the project does not use them) or duplicated write work on one file. So the honest
label on these cells is *demonstrated competence at this task type*, never *better than*.

Two conditions were set by the Orchestrator before dispatch, both of which the briefs lacked:

1. **`deliverables=` was empty** in all three, which silently disables the strongest arm of
   dispatch verification (T411 checks the nonce, the declared deliverables, and the row status —
   with no deliverables declared, only the nonce is left). Each row now declares its source file
   and its findings file, plus a per-file `zig test` as acceptance rather than the full suite,
   which is untrustworthy per T454.
2. **All three originally declared `docs/infra/suite-truth.md`** — three concurrent writers on
   one manifest. The manifest was removed from every scope; each console reports the ratchet it
   earned under a `manifest_ratchet` key in its findings, and the Orchestrator applies all three
   in one commit with one writer.

## 4. The holes, in the order worth filling

1. **T-B (mechanism fix, test-first)** — no cell filled at all, and it is the most common row
   shape in the queue. T446, T448, T449, T450 and T451–T453 are all T-B and all currently free:
   dispatch them to *different* models and compare on the same bars.
2. **T-F (adjudication)** — never measured, and it is the seat where independence matters most.
3. **T-E (spec authoring)** at Ollama scale — only Fable has ever done it, in the prior epoch.
4. **T-H (long-horizon console)** — the operator's own hypothesis is that `deepseek-v4-pro` may
   earn its premium here. Untested in the new epoch.
5. **Opus and Fable in T-A** — excluded from T447 because the grader was Claude. Needs a
   non-Claude grader to be legitimate.
