# Per-model request accounting (T850)

**Landmark:** advances L1. **This document MEASURES. It does not cap.** No
dispatch gate, refusal, or cap belongs here or in `tools/request-accounting.py`
— that is a separate row, gated on these numbers being trusted first.

## The failure this exists to prevent

In one 5-hour window `minimax-m3` is recorded as taking **790 of ~792
requests**, running 2,902 s and producing nothing, while `glm-5.2` and
`kimi-k2.7` received one request each. `tools/fleet_caps.py` caps
**concurrency** (in-progress lane counts); `tools/window_policy.py` meters
**tokens** over a 5-hour Claude window. Neither counts requests, and a
per-family concurrency cap is structurally blind to one member consuming the
family's whole allowance from inside a single, otherwise-uncapped dispatch.

## Source of truth, per harness

The fleet runs two harnesses, and each already stamps the join key this row
needs — nothing here is invented, both are read from the per-attempt run
records `tools/runner` writes to its own git-ignored runs directory (one
JSON file per attempt, named `<task>.json`).

### `claude` (opus-5 / sonnet-5 / haiku-4-5 / fable-5) — count from `num_turns`

A claude dispatch's raw `-p --output-format json` envelope is teed, whole, to
a per-attempt file in the runner's git-ignored tokens directory (named
`<task>.<start>.claude.stdout.log` — `tools/token-capture.py write_tees()`,
called with `start_ts = run_record["start"]` — verified at
`tools/runner:3789`/`3841`). The envelope carries a `num_turns` field
independent of success or failure: verified against task T836's own teed
envelope on disk (an `is_error: true` attempt whose envelope still reads
`"num_turns": 53`).

**This is fact 2's crux, made visible.** One dispatch is one row in the
kanban and one lane in the fleet cap, but internally it is `num_turns`
provider requests — the starvation this row exists to catch happens *inside*
that count, where no per-dispatch or per-concurrency guard can see it.
`num_turns` is exactly the number that was invisible until read here.

**Join:** `<task>` + sanitized `run_record["start"]` + `.claude.stdout.log` —
a filename lookup, not a heuristic; `write_tees` and the run record are
stamped from the same `start_ts` value in the same call.

**Resolution:** per-DISPATCH, not per-request. The envelope has no per-turn
timestamp, so every request in an attempt is anchored at the attempt's own
end (or start) time for window membership. A dispatch is a request-count
delta at one instant, not a timeline — coarser than the pi harness below,
and stated as a limitation, not hidden.

### `pi` harness (deepseek, ollama's glm-5.2/minimax-m3/kimi-k2.7, local
qwen, openrouter/ox-alpha) — count from the session transcript

When the dispatcher passes `--session <path>` (T662), the runner stamps
`session_path` on the run record and the path holds the resumable session
JSONL. Verified against task T849's own real session transcript on disk
(the runner's git-ignored sessions directory, one line per event): each
completed model reply is one line `{"type": "message", "message": {"role":
"assistant", ...}, "timestamp": "..."}`; a tool-call round-trip result is a
separate `role: "toolResult"` line (not a provider request — no model call);
the initial prompt is `role: "user"`. **One `role: "assistant"` message
line = one provider request** — the same predicate
`tools/token-capture.py:read_pi_session()` already sums usage over (T662);
this row does not invent a second definition of "turn."

**Join:** `run_record["session_path"]` — the field the runner already
stamped; never a directory scan, never a cwd-slug guess (that is
`tools/token-backfill.py`'s territory, T746, deliberately not duplicated
here — see "Deliberately unmeasurable" below).

**Resolution:** per-REQUEST. Each assistant-role line carries its own
`timestamp`, so window membership is exact — a request one second outside
the window is excluded even when the surrounding dispatch straddles the
boundary.

### Fact 1, confirmed

`grep -rln "request_count\|requests_used\|n_requests\|request budget"
tools/ bin/` returns nothing (re-run 2026-08-24, still empty). Nothing in
this repository counted requests before this row.

### Fact 4, confirmed — the ollama server log cannot attribute

`~/.ollama/logs/server.log` records every HTTP request as a `[GIN]` line —
`[GIN] 2026/08/24 - 11:16:39 | 200 | 13.542µs | 127.0.0.1 | POST "/api/me"` —
with a status and a duration, but the model lives in the request body,
never the log line. The log also carries every endpoint the server serves
(`/api/status`, `/api/tags`, `/api/me`, health checks — not only chat), so
even its TOTAL is not a chat-request total. It is used below only as an
independent, non-attributing cross-check on the ollama family's known total,
reported side by side and never reconciled into one number.

The log's own timestamp carries no UTC offset — it is the host's local wall
clock. `tools/request-accounting.py` resolves it via `Europe/Oslo`, the same
zone `tools/window_policy.py`'s provider-reset parsing already trusts (one
timezone assumption, one place).

## The window

**One window definition, one place** (T850 constraint): `tools/
request-accounting.py` takes its rolling-window length from
`tools/window_policy.WINDOW_SECONDS` (currently 5 hours, the Claude
session-window constant) rather than defining a second rolling-window
length. A `--window-seconds` override exists for testing and for a
deliberately different report width; the *default* is one import, not a
second literal.

A window is `[now - WINDOW_SECONDS, now)` — half-open, so a request exactly
at the boundary is unambiguously inside or outside (pinned by the
regression's window-boundary arm).

## Report shape

Per model: attributed request count in the window, its share of its
`tools/fleet_caps.py` family total, its share of the fleet total, and the
count of attempts in-window whose request count could **not** be
attributed (with the distinct reasons, never folded into 0 or into the
total). A model whose share of its OWN family's known total is **≥ 80%**
is flagged `STARVATION` — derived, not guessed: at `tools/fleet_caps.py`'s
`ollama` cap of 5 lanes, an even split is 20% each, so 80% is 4× an even
share, with headroom below the 99.7%-of-family incident this row exists to
catch and above any plausible healthy skew from one member simply running
longer.

The **null control**: zero run records fall in the window at all →
the report says so explicitly (`"status": "empty-window"`, `models: {}`,
`fleet_total_requests: null`) and prints nothing that reads like a
measurement — a `0` here would be indistinguishable from "measured zero
traffic," which is false; there is no measurement to report.

## Deliberately unmeasurable, and why

- **A `pi`/`ollama`/`openrouter` lane with no `--session` at dispatch**
  (`session_path` is `None` on the run record — the ox-alpha/openrouter
  lanes today, per fact 6). The default-location session file
  (`~/.pi/agent/sessions/<cwd-slug>/`) is shared by every concurrent lane in
  that directory and cannot be attributed to one task without a
  time-correlation heuristic — that heuristic already exists
  (`tools/token-backfill.py`, T746) and is a *retroactive recovery* tool
  with its own tolerance/corroboration machinery. Reimplementing a second,
  narrower version of it here would be exactly the "two implementations of
  one idea" defect this project has been bitten by repeatedly (four cooldown
  mechanisms, two short-name tables). This row reports these lanes as
  **UNKNOWN**, with the run record's own reason string, and stops there.
- **A claude attempt whose tee is missing, unreadable, or carries no
  `num_turns`** (an older claude CLI version, or a lane that died before
  any stdout was captured). UNKNOWN, with the specific reason.
- **A lane dispatched through neither `claude` nor `pi`** (argv[0] is
  something else). UNKNOWN — the harness itself is unrecognized, so no
  join is attempted.

None of these is folded into 0 or into a family/fleet total. The honesty
rule (this project's standing ruling, already enforced for tokens): an
unattributable request is UNKNOWN, never 0 and never the total. A counter
that reports 0 where it means "I could not tell" would authorize the exact
starvation this row exists to detect.

## Fact 5, corrected — the ollama "100% consumed" note

`docs/status/RESUME-orcha.md` states "**100% of the 5-hour window
consumed**" for ollama on 2026-08-24. The `[GIN]` log for that UTC date
(measured 2026-08-24 09:19Z, via `grep '^\[GIN\] 2026/08/24'
~/.ollama/logs/server.log`) shows:

| date (UTC) | total `[GIN]` lines | status 200 | status 429 |
|---|---|---|---|
| 2026-08-24 (partial day, through 09:19Z) | 936 | 923 | 12 |
| 2026-08-20 (full day) | 4,734 | — | 331 |
| 2026-08-20, hour 13:00 alone | 1,848 | — | — |

12 refusals out of 936 requests (1.3%) is a **brief** ceiling, not a
window-long exhaustion — the 429s cluster tightly (per the brief's original
measurement, around 09:44Z) and the great majority of the day's traffic
returned 200. 2026-08-20 is the genuinely saturated day by comparison: 331
refusals and one single hour carrying more requests (1,848) than the
2026-08-24 figures being corrected here span in almost a full day. These
counts grow as the log is live-appended; a re-run of the `grep` above after
this document is committed will read higher totals for the same date and
should — that is the log doing its job, not a discrepancy in this table.

**Correction:** "100% of the window consumed" should read "ollama hit a
brief request ceiling around 09:44Z on 2026-08-24 (12 refusals against 936
requests, 1.3%), not a window-long exhaustion." This document does not edit
`docs/status/RESUME-orcha.md` itself (out of this row's declared
deliverables); the correction is recorded here per the brief's instruction
and should be carried forward by whoever next touches that status doc.

## Out of scope, deliberately

No dispatch gate, no refusal, no cap, no change to `bin/dispatch`,
`tools/fleet_caps.py`, `tools/window_policy.py`, or `tools/runner`.
Report-only, per the brief. `tools/token-backfill.py`'s retroactive
cwd-slug scan is not duplicated here (see "Deliberately unmeasurable").

## Regression

`tools/regression-request-accounting.sh` — arms and their controls are
listed at the top of that script; run it directly for the current arm
count and pass/fail detail.
