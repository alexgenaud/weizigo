# argus — output format design

```
Author:   DSPro/T189 · 2026-07-31
Status:   PROPOSED (rev 1)
Inputs:   docs/epic-01-markovian/sprints/argus/pass0/spec.md (Opus 5, rev 1, PROPOSED)
Scope:    M2 — log grammar, append-only mechanism, summary layout,
          recomputability contract (A4), registry path decision
```

## 1. Overview

This document defines the two output files Argus writes, the grammar of
each, the append-only mechanism, the summary's recomputability from the log,
and where the tracked checklist registry lives.

Three artefacts:

| artefact | path | tracked? | write discipline | consumer |
|---|---|---|---|---|
| **Log** | `untracked/watchdog.md` | no (git-ignored) | append-only, one line per finding | pattern detection over weeks; the summary's source of truth |
| **Summary** | `untracked/watchdog-summary.md` | no (git-ignored) | overwritten each run, fully recomputable from the log | Orcha's cadence (A6); the human's dashboard |
| **Registry** | `docs/epic-01-markovian/sprints/argus/checklist.md` | yes (tracked in git) | revised in place by M3, then read-only for mode-2 runs; grows per R11 | Argus mode 2; the durable knowledge of what recurred |

## 2. Log grammar

### 2.1 Transport format

**JSON Lines** (NDJSON): one complete JSON object per line, `\n` terminated,
no trailing comma. Each line is self-contained and parseable independently.
Chosen over TSV/CSV because:

- The project already standardizes on JSON Lines (verify-battery's result
  schema, subagent findings schema).
- Fields are additive over time (e.g. a new evidence kind) without breaking
  line-by-line parsers.
- A JSON parser rejects malformed lines; a TSV parser silently shifts
  columns.
- DSFlash writes JSON reliably; hand-rolling a custom delimiter format
  invites off-by-one-field errors.

**One finding per line, always.** A run with zero findings still appends a
single `kind: "run-marker"` line so the summary can distinguish "clean run"
from "run not yet performed."

### 2.2 Line types

Three line kinds, distinguished by the `kind` field:

| `kind` | when emitted | frequency |
|---|---|---|
| `"run-marker"` | start of every invocation, before any findings | one per run |
| `"finding"` | one per detected issue | zero or more per run |
| *(reserved)* | future: `"baseline-change"` for when A-4 re-measures baselines | zero or more per run (pass1+) |

### 2.3 Run marker

Emitted once at the start of every Argus invocation. Carries the run's
identity, mode, and denominators.

```json
{
  "kind": "run-marker",
  "run": "2026-07-31T142200Z-checklist",
  "timestamp": "2026-07-31T14:22:00Z",
  "mode": "checklist",
  "checks_run": 5,
  "checks_skipped": 0,
  "checks_skipped_reasons": {},
  "sweep_files_visited": null,
  "sweep_files_total": null
}
```

**Field table:**

| field | type | nullable | description |
|---|---|---|---|
| `kind` | string | no | `"run-marker"` |
| `run` | string | no | Unique run identifier: `{ISO-8601-basic}Z-{mode}`. `ISO-8601-basic` = `YYYYMMDDTHHMMSS`. The `Z` is the literal character, not a timezone offset — all timestamps are UTC. Example: `20260731T142200Z-checklist`. |
| `timestamp` | string | no | ISO-8601 UTC with seconds: `YYYY-MM-DDTHH:MM:SSZ`. |
| `mode` | string | no | `"sweep"` or `"checklist"` (R5: one mode per invocation). |
| `checks_run` | u8 | yes | Number of checklist slugs executed. `null` for sweep mode. |
| `checks_skipped` | u8 | yes | Number skipped (tool missing, blocked, etc.). `null` for sweep. |
| `checks_skipped_reasons` | object | yes | Map of slug → reason string. `null` for sweep or when zero skipped. |
| `sweep_files_visited` | u64 | yes | Files visited in the sweep pass (R12). `null` for checklist mode. |
| `sweep_files_total` | u64 | yes | Total files in the sweep scope. `null` for checklist mode. |

**`run` ID uniqueness:** the timestamp is collected at invocation start.
Two invocations in the same second append `-2`, `-3`, etc. In practice
Argus runs are human-prodded and will never collide; the suffix is a
safety measure, not a scheduling contract.

### 2.4 Finding

One per detected issue. Common fields, then mode-specific fields.

```json
{
  "kind": "finding",
  "run": "2026-07-31T142200Z-checklist",
  "timestamp": "2026-07-31T14:22:01Z",
  "mode": "checklist",
  "slug": "claimlint-green",
  "grade": "must",
  "finding": "C1a orphans regressed from baseline: 10 → 12",
  "evidence_kind": "command",
  "evidence_command": "bin/weizigo-claimlint",
  "evidence_exit": 1,
  "evidence_output": "C1a orphans: 12",
  "source_file": null,
  "source_line": null,
  "value": "C1a=12",
  "baseline": "C1a=10",
  "proposed_task": false
}
```

**Common fields (all findings):**

| field | type | nullable | description |
|---|---|---|---|
| `kind` | string | no | `"finding"` |
| `run` | string | no | The run ID this finding belongs to (matches the run-marker). |
| `timestamp` | string | no | ISO-8601 UTC with seconds. |
| `mode` | string | no | `"sweep"` or `"checklist"`. |
| `slug` | string | yes | Checklist slug from the registry. `null` for sweep findings. |
| `grade` | string | no | `critical`, `must`, `should`, `could`, `unverified`. See §2.5. |
| `finding` | string | no | Human-readable one-liner describing the issue. |
| `evidence_kind` | string | no | `"command"` or `"file-line"`. See §2.6. |
| `evidence_command` | string | yes | The command that produced the evidence. Present when `evidence_kind` is `"command"`. |
| `evidence_exit` | i32 | yes | Exit code. Present when `evidence_kind` is `"command"`. |
| `evidence_output` | string | yes | The relevant output line(s), trimmed to the evidence. Present when `evidence_kind` is `"command"`. |
| `source_file` | string | yes | `file:line` verified against current text. Present when `evidence_kind` is `"file-line"`. |
| `source_line` | u64 | yes | Line number within `source_file`. Present when `evidence_kind` is `"file-line"`. |
| `value` | string | yes | The measured value (checklist mode only). `null` for sweep. |
| `baseline` | string | yes | The registry baseline (checklist mode only). `null` for sweep. |
| `proposed_task` | bool | no | `true` if this finding includes a proposed brief for Orcha (R14). The proposed brief text is in a separate `proposed_brief` field when true. |
| `proposed_brief` | string | yes | Proposed task brief text for Orcha to register. Present only when `proposed_task` is `true`. |

**Evidence rule (R6):** a finding MUST carry either `evidence_kind: "command"`
with `evidence_command`, `evidence_exit`, and `evidence_output` populated, or
`evidence_kind: "file-line"` with `source_file` and `source_line` verified
against the current text. A finding that has neither is graded `unverified`
and is excluded from the summary's violation counts (though it is still
logged — §1.1: impressions are worth logging, not worth counting).

### 2.5 Grades

| grade | meaning | included in summary violation counts? |
|---|---|---|
| `critical` | A known invariant is violated; a tool exits nonzero that should exit zero; a process defect that will silently corrupt state. | yes |
| `must` | Violates a spec requirement, project rule, or documented invariant. | yes |
| `should` | Best-practice violation, hygiene gap, untracked file creep below threshold. | yes |
| `could` | Observation, suggestion, or minor inconsistency. | no (logged, not counted) |
| `unverified` | R6 evidence rule not met — the finding is an impression without a command or file:line citation. | no (logged, not counted; §1.1) |

Grades are Argus's judgment. The summary carries counts by grade; a reader
who only reads the summary can ignore `could` and `unverified` and lose
nothing actionable.

### 2.6 Evidence kinds

**`command`:** a shell command was run, its exit code and output were
captured, and the relevant output line is quoted. The command is recorded
exactly as invoked so the reader can reproduce it.

```json
{
  "evidence_kind": "command",
  "evidence_command": "bin/weizigo-claimlint",
  "evidence_exit": 1,
  "evidence_output": "C1a orphans: 12\nC2 dangling evidence: 13"
}
```

**`file-line`:** a specific line in a tracked file was read and verified
against the current text. The finding cites the file path and line number.
The text at that line is included in `evidence_output` for traceability
without a file read.

```json
{
  "evidence_kind": "file-line",
  "source_file": "docs/epistemic/CLAIMS.md",
  "source_line": 557,
  "evidence_output": "| C1a | 3×2 | …"
}
```

### 2.7 Worked example — a full checklist run

```
{"kind":"run-marker","run":"20260731T142200Z-checklist","timestamp":"2026-07-31T14:22:00Z","mode":"checklist","checks_run":5,"checks_skipped":0,"checks_skipped_reasons":{},"sweep_files_visited":null,"sweep_files_total":null}
{"kind":"finding","run":"20260731T142200Z-checklist","timestamp":"2026-07-31T14:22:01Z","mode":"checklist","slug":"claimlint-green","grade":"must","finding":"C1a orphans regressed from baseline: 10 → 12","evidence_kind":"command","evidence_command":"bin/weizigo-claimlint","evidence_exit":1,"evidence_output":"C1a orphans: 12","source_file":null,"source_line":null,"value":"C1a=12","baseline":"C1a=10","proposed_task":false}
{"kind":"finding","run":"20260731T142200Z-checklist","timestamp":"2026-07-31T14:22:01Z","mode":"checklist","slug":"stale-in-progress","grade":"must","finding":"Task T999 in_progress for 27h with no heartbeat","evidence_kind":"command","evidence_command":"bin/managent show T999","evidence_exit":0,"evidence_output":"claimed: 2026-07-30T11:00:00Z","source_file":null,"source_line":null,"value":"27h","baseline":"0 tasks >24h","proposed_task":true,"proposed_brief":"T999 has been in_progress for 27h. Verify the console is alive; if dead, managent reopen T999."}
```

## 3. Append-only mechanism

### 3.1 Contract

**The log is append-only in fact, not by promise (R7).** No run may alter
or remove an existing line. Argus enforces this mechanically:

1. Open `untracked/watchdog.md` for append (`O_APPEND | O_WRONLY | O_CREAT`).
2. Seek to end (redundant with `O_APPEND` on POSIX; explicit for portability).
3. Write the run-marker line, then each finding line, each followed by `\n`.
4. Close.

Argus never opens the log for reading during a run. It reads the log only
for summary recomputation (A4), which happens in a separate read pass after
the run completes.

### 3.2 Verification (A3)

Run twice. After run 2, the log must contain the log after run 1 as an
**exact byte prefix**. Verification command:

```sh
# After run 1, snapshot:
cp untracked/watchdog.md /tmp/watchdog-run1.md

# After run 2:
head -c $(wc -c < /tmp/watchdog-run1.md) untracked/watchdog.md | diff /tmp/watchdog-run1.md -
# Exit 0 = identical prefix → A3 PASS
```

### 3.3 Corruption resistance

The append-only design assumes a cooperative filesystem. Three failure modes
and their mitigations:

| failure | mitigation |
|---|---|
| Partial write (crash mid-line) | The truncated last line fails JSON parse; the summary builder skips it with a warning. The run that crashed will not have a corresponding run-marker in the clean-run set — it's treated as incomplete. |
| Filesystem full | `write()` returns `ENOSPC`; Argus reports `battery-bad` (its own error convention) and does not write a partial line. The summary reflects the run as incomplete. |
| Concurrent Argus instances | R1: exactly one Argus seat. If violated by operator error, `O_APPEND` guarantees atomic writes for lines under PIPE_BUF (guaranteed on all lines here). |

## 4. Summary layout

### 4.1 Contract

**The summary is overwritten each run (R8)** and is **fully recomputable
from the log alone.** Every number in the summary cites the log field it
derives from. The summary is Markdown — Orcha reads it directly (A6).

### 4.2 Sections

The summary has four sections, always in this order:

1. **Run info** — what just ran, when, denominators.
2. **Violations (24h / 7d)** — per-slug regression table.
3. **Sweep coverage** — most recent sweep's denominator (if mode 1 is active).
4. **Proposed tasks** — findings marked `proposed_task: true` in the last 24h.

### 4.3 Template

```markdown
# Argus watchdog — summary

**Last run:** 2026-07-31T14:22:00Z (checklist) · **Run ID:** `20260731T142200Z-checklist`
**Checks run:** 5 · **Skipped:** 0 · **Findings this run:** 2 (1 must, 0 could, 1 unverified)

---

## Violations — past 24h

| slug | grade | current | baseline | last seen | 24h | 7d |
|---|---|---|---|---|---|---|
| claimlint-green | must | C1a=12 | C1a=10 | 2026-07-31T14:22Z | 1 | 1 |
| stale-in-progress | must | T999 27h | 0 >24h | 2026-07-31T14:22Z | 1 | — |

*No violations in past 7d beyond what 24h captures. `—` = slug added <7d ago, partial window.*

---

## Sweep — most recent

**Run:** `20260731T140000Z-sweep` · **Files visited:** 41 of 312 under `docs/` (13.1%)
**Findings:** 1 must, 3 could, 2 unverified · **Phantom rate (must/critical):** 0/1 (0%)

---

## Proposed tasks

- [ ] **T999 stale** — `managent show T999`: in_progress for 27h, no heartbeat. Verify console; reopen if dead.
- *(none other)*

---

*Summary recomputable from `untracked/watchdog.md` (287 lines, 19 runs). Recompute command: `bin/argus-summarize` (pass1).*
```

### 4.4 Recomputability (A4)

Every number in the summary is derivable from the log by a pure function:

| summary field | log source |
|---|---|
| "Last run" timestamp + mode | Most recent `run-marker` line's `timestamp` and `mode` |
| "Checks run" / "Skipped" | Most recent `run-marker`'s `checks_run` / `checks_skipped` |
| "Findings this run" | Count of `finding` lines with `run` matching the last run-marker's `run`, grouped by `grade` |
| Violations table: `current` | Most recent `finding` for that slug's `value` field |
| Violations table: `baseline` | Most recent `finding` for that slug's `baseline` field |
| Violations table: `last seen` | Most recent `finding` for that slug's `timestamp` |
| Violations table: `24h` | Count of `finding` lines for that slug in the 24h window before the last run-marker's `timestamp` |
| Violations table: `7d` | Count of `finding` lines for that slug in the 7d window before the last run-marker's `timestamp` |
| Sweep: files visited | Most recent sweep `run-marker`'s `sweep_files_visited` / `sweep_files_total` |
| Sweep: findings / phantom rate | Count of sweep `finding` lines from the most recent sweep run, grouped by grade; phantom rate = adjudicated-phantom count / (must + critical count) |
| Proposed tasks | `finding` lines with `proposed_task: true` in the last 24h, rendered as Markdown checklist items |

A4 verification: a different seat or script reads the log, recomputes every
summary field, and confirms identity. No field in the summary carries
information not present in the log.

### 4.5 Phantom rate tracking (A2)

The sweep section carries the most recent adjudication result. The phantom
rate is computed as:

```
phantom_rate = adjudicated_phantoms / (must_count + critical_count)
```

where `adjudicated_phantoms` is the count of `must`/`critical` findings from
the most recent sweep that a different seat adjudicated as phantom. The
denominator is the total `must` + `critical` findings from that sweep.
`could` and `unverified` findings are excluded from both numerator and
denominator.

If mode 1 is descoped (phantom rate > 50%), the Sweep section reads:

```
## Sweep — DESCOPED

Mode 1 descoped: phantom rate 3/4 (75%) > 50% threshold (A2).
Checklist mode (mode 2) remains active. Mode 1 re-evaluation deferred to pass1.
```

## 5. Checklist registry

### 5.1 Path

```
docs/epic-01-markovian/sprints/argus/checklist.md
```

Tracked in git (R10). M3 writes it; M4 reads it. Path chosen to colocate
with the sprint's other durable artefacts (`spec.md`, `plan.md`, `design.md`).

### 5.2 Schema

A Markdown file with a YAML-like metadata block (for machine parsing) and a
human-readable table.

```markdown
# Argus checklist registry

```
registry_version: "1.0.0"
updated: "2026-07-31T15:00:00Z"
updated_by: "20260731T150000Z-checklist"
```

## Growth rule (R11)

A slug is added only after the issue has recurred, with both instances cited.
One occurrence is a task for Orcha, not a checklist item.

## Slugs

| slug | check | baseline | baseline_date | baseline_run | grade | first_seen | citations |
|---|---|---|---|---|---|---|---|
| claimlint-green | `bin/weizigo-claimlint` — record C1a, C1b, C2, C6, calibration | C1a=10, C1b=0, C2=13, C6=0, cal=PASS | 2026-07-31 | `20260731T120000Z-checklist` | must | 2026-07-31 | spec §4; 067-dabir-to-orchestrator.md |
| stale-in-progress | `bin/managent liveness` + `bin/managent show <id>` per in_progress task | 0 tasks >24h | 2026-07-31 | `20260731T120000Z-checklist` | must | 2026-07-31 | spec §4; 067-dabir-to-orchestrator.md |
| artifact-loadable | `bin/weizigo-oracle <path>` exit≠0 = load failure | all pass | 2026-07-31 | `20260731T120000Z-checklist` | critical | 2026-07-31 | spec §4 |
| orphan-gate | `bin/managent audit` exit≠0 = FIX findings | clean, exit 0 | 2026-07-31 | `20260731T120000Z-checklist` | must | 2026-07-31 | spec §4 |
| ephemera-creep | `du -sh untracked/` + files >10 MB not in evidence | 494 MB, 2 >10 MB | 2026-07-31 | `20260731T120000Z-checklist` | should | 2026-07-31 | spec §4 |
```

**Field definitions:**

| field | description |
|---|---|
| `slug` | Unique short name, kebab-case. Used in log `slug` field and summary table. |
| `check` | Exact command or procedure to mechanize. Shell-incantable where possible; procedural steps where not. |
| `baseline` | The value measured on `baseline_date`. A regression is a change away from this value that the grade deems a violation. |
| `baseline_date` | ISO-8601 date the baseline was set. |
| `baseline_run` | The run ID that set this baseline. |
| `grade` | Default grade for findings from this slug. May be overridden per-finding if the severity changes. |
| `first_seen` | Date the issue was first observed (before the slug was added — cited in `citations`). |
| `citations` | Two references (R11): the two instances that justified adding this slug. For seed slugs: the spec and the Dabir message that proposed them. |

### 5.3 Baseline semantics (R9)

A baseline is a **value**, not a boolean. The check records a value each
run; the violation is a **regression against baseline**. Examples:

| slug | records | baseline | violation |
|---|---|---|---|
| `claimlint-green` | C1a count, C2 count, calibration verdict | C1a=10, C2=13, cal=PASS | C1a > 10, or C2 > 13, or cal=FAIL |
| `stale-in-progress` | count of tasks >24h stale | 0 | >0 |
| `artifact-loadable` | per-artifact load result | all pass | any fail |
| `orphan-gate` | `managent audit` exit code + findings | exit 0, clean | exit ≠0 |
| `ephemera-creep` | `du -sh untracked/`, count >10 MB not in evidence | 494 MB, 2 >10 MB | size increase >10% or new >10 MB file not in evidence |

**The baseline ratchet question (spec auditor question 3):** does
baseline-relative checking normalize red? Yes, by design — the purpose is to
detect *regressions*, not to flag every pre-existing issue every run. The
remedy for a stale baseline is a **manual baseline reset** by the human or
Orcha: when an issue is fixed (e.g. C1a orphans go from 10 to 0), the human
updates the registry's baseline to the new value and dates it. The registry
is a tracked file; the update is a normal commit. Argus does not reset
baselines automatically — that would hide regressions.

### 5.4 Registry revision

The registry is revised in place by M3 (initial population) and
subsequently only by the human or Orcha (adding slugs per R11, resetting
baselines after fixes). Argus reads the registry; it never writes it.

## 6. Paths summary

| path | writer | tracked | purpose |
|---|---|---|---|
| `untracked/watchdog.md` | Argus (append-only) | no | Accumulated finding history |
| `untracked/watchdog-summary.md` | Argus (overwrite) | no | Human/machine-readable dashboard |
| `docs/epic-01-markovian/sprints/argus/checklist.md` | M3 (initial), human/Orcha (ongoing) | yes | Durable checklist registry |

## 7. Tension resolution: §7.1 (untracked log)

The spec flags the tension between a git-ignored log and the premise that
accumulated history reveals process defects. This design accepts the
division:

- **The log is deliberately ephemeral.** Losing it costs pattern resolution,
  not knowledge. The summary carries 24h/7d windows; a `git clean -x` after
  a week of clean runs loses nothing actionable because the summary had
  nothing to report.
- **The registry is tracked.** Slugs, baselines, and `first_seen` dates
  survive a clean. The knowledge that `claimlint-green` has been red since
  2026-07-31 is in git.
- **Promotion is the durable artefact.** When a finding crosses the
  threshold from "recurring noise" to "process defect," Orcha promotes it
  into `docs/` — a task, a process doc, or an ADR. The log is working
  memory; the promotion is the permanent record.

No alternative (tracking the log under `docs/`) is designed here — the spec
owners chose the untracked path, and this design implements it faithfully.

## 8. For the design auditor

Per sprint.md, the design audit is **adversarial review** — attempt
refutation, state a verdict. Grade **blocker / critical / must / should /
could**; verdict **PASS / PASS-WITH-EDITS / NEEDS-FIX / REDO**. Write to
`docs/epic-01-markovian/sprints/argus/archive/design.audit-1.md`.

Questions worth attempting to refute:

1. **Log as JSON Lines** — does a DSFlash session writing hand-rolled JSON
   risk syntax errors that break the summary recomputation? Should the log
   format be a simpler line grammar (e.g. `field1|field2|...`) that DSFlash
   can emit without a JSON serializer?
2. **Summary as Markdown** — Orcha reads this in cadence step 5. Is the
   proposed task section parseable enough that Orcha can `managent add`
   without re-interpreting? Should proposed tasks carry a structured brief
   snippet (title, body, needs, holds) rather than free text?
3. **Baseline reset mechanism** — the design says "human or Orcha resets
   baselines." Is there a risk that baselines are never reset and the
   summary permanently reports zero violations on slugs that are permanently
   red? Does the summary need a "days since baseline reset" column?
4. **Run ID collision** — the `-2` suffix assumes ≤2 invocations per second.
   Is this safe for a prod-driven model where the human might run Argus back
   to back?
5. **`proposed_task` field** — the finding carries a `proposed_brief` string
   but no structured task fields (needs, holds, set). Can Orcha register a
   task from a free-text brief without re-analyzing the finding?
6. **No log rotation** — the log grows without bound. At one run every 10
   minutes with 2 findings each, that's ~288 lines/day, ~2,000/week. Is
   unbounded growth acceptable for an untracked file, or should the design
   specify a retention window (e.g. keep 30d, archive older)?
