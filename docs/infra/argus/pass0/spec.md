# argus — SPEC

```
Status:   PROPOSED (revision 1)
Author:   Opus 5 (claude-opus-5[1m]) · 2026-07-31
Source:   untracked/msg/milestone-01-ko-reframe/067-dabir-to-orchestrator.md
          (Dabir/DeepSeek-v4-Pro) — the human's request, relayed
Process:  docs/infra/sprint.md rev 4, RATIFIED (d53c2a8). Canonical phase docs
          in docs/infra/argus/pass0/; numbered ephemera in docs/design/argus/,
          deleted at the gate commit (D-11, D-14)
Approval: human only. No external approver beyond the human is required for
          this sprint — declared here per sprint.md @ 45deb10:44-48. Rationale:
          Argus writes nothing but two git-ignored files and holds no
          authority, so a wrong Argus costs attention, not correctness
Tier:     B — read-only, cannot corrupt the register or the kanban. But Argus
          is an instrument, and "plausible-looking wrongness that survives
          because nobody checked" (docs/infra/roles/AUDITOR.md @ 45deb10:7) is
          this project's documented failure mode. An instrument built on a
          cheap model needs the same calibration discipline as an expensive one
Audit:    this document, before strategy.md is written. Instrument: document
          review, fresh seat (sprint.md @ 45deb10:147)
```

## 1. The problem

The project has two kinds of defect. The first is **wrongness in results** — an
unsound checker, a mislabeled census, a table that cannot state its own answer.
The Auditor owns that, and the machinery for it (adversarial review, independent
re-implementation) is expensive by design.

The second is **drift in process state**: a document referencing a task that no
longer exists, a checklist item that has been red for a week, an artifact nobody
has tried to load since the format changed, a task `in_progress` whose console
died. None of it is subtle. All of it is currently detected by exactly two
seats — the human and Orcha — both of whom are the most expensive readers in the
project, and neither of whom is *assigned* to sweep.

Three examples, measured on the tree at `45deb10` while writing this spec:

- `bin/weizigo-claimlint` **exits 1 today**: 10 C1a orphans, 13 C2 dangling
  evidence paths, 0 C1b, 0 C6, calibration PASS. Nobody is currently tasked
  with knowing whether that is yesterday's 10 or a new one.
- `untracked/` holds **494 MB**, of which 492 MB is two files —
  `oracle-4x4-writesoff-bracket.wzo` and `oracle-4x4-writesoff-checkpoint.wzo`,
  246 MB each. `git clean -x` is a routine operation and these are not evidence.
- `bin/managent audit` exits 0 and reports clean — which is the point: the
  cheap mechanical checks already exist and already answer, and no seat runs
  them on a cadence.

**Argus is the seat that runs them.** Named for the hundred-eyed giant who
watched Io: many eyes, never slept, never acted.

### 1.1 The counter-risk, stated first

A cheap pattern-matching model asked "what looks wrong?" across a large project
will produce plausible findings that are not findings. That is not a
hypothetical here: the `RV2-1` phantom — an audit finding that cited text which
did not exist in the current document — is why sprint.md now requires every
finding to cite file+line verified against the *current* text
(`sprint.md @ 45deb10:216-217`).

An unreliable watchdog is worse than none: it trains every reader to skip its
output, and then the one real finding is skipped too. So the load-bearing work
of this sprint is **not the sweep, it is making Argus's output cheap to trust** —
mechanized where possible, cited where not, and graded so that impressions
cannot masquerade as facts. §5's calibration criteria exist to measure that, and
§8 names the failure that ends the role.

## 2. What to build

Three things:

1. A **role definition** — one seat, read-only, advisory, with an explicit
   write allowlist.
2. A **checklist registry** — the mechanized recurring checks, their baselines,
   and a growth rule. Tracked in git.
3. Two **output files** — an append-only log and an overwritten summary, at the
   paths the human specified.

**This spec does not choose** whether the checks run as an agent executing
commands, a shell script, or a Zig tool; nor the log's exact grammar; nor who
prods Argus. Those are `design.md`.

## 3. Requirements

| id | requirement | rationale |
|---|---|---|
| **R1** | **Exactly one Argus seat**, like Orcha. Succession is not overlap. | two watchdogs disagreeing about the same tree is a third finding nobody asked for |
| **R2** | **Authority: none.** Argus may **advise** an agent to stop; the advice is never blocking. It cannot repair, ratify, kill, or register. | a watchdog that can act is a second Orchestrator with less context |
| **R3** | **Write allowlist is exactly two paths**: `untracked/watchdog.md` and `untracked/watchdog-summary.md`. Everything else is read-only, explicitly including `src/`, `docs/` (all of it, including this spec), `data/`, `artifacts/`, `docs/epistemic/CLAIMS.md`, `docs/infra/managent/tasks.json`, and the milestone channel. Every mutating `managent` subcommand is forbidden — `add`, `claim`, `done`, `dispatch`, `tell`, `reopen`, `purge`, `standing`, `agent`, `ping`. Read-only `managent` verbs (`status`, `show`, `audit`, `liveness`, `why`, `inbox`) are permitted. | `managent tell` is directive authority and `standing` mints tasks; both contradict R2. The allowlist is stated as paths and verbs because "read-only" as an adjective has never stopped anyone |
| **R4** | **Model class: the cheap fast tier**, pattern-matching rather than deep reasoning. The human's designated instance at time of writing is DeepSeek-v4-Flash (DSFlash). Assignment is the human's at dispatch; dispatch mechanics live in `docs/infra/agents/subdelegation.md` and only there (D-15). | the role is *defined* by being cheap enough to run every 10 minutes — that is a requirement, not an implementation detail. Naming the instance is a note, not a binding |
| **R5** | **One invocation runs one mode** (§4), and says which. | a run that blends a mechanical checklist with impressions produces one output stream of mixed trustworthiness |
| **R6** | **Every finding carries its evidence**: either a command with its exit code and the relevant output line, or `file:line` verified against the current text. A finding that has neither is graded **`unverified`**, is logged, and is **excluded from the summary's violation counts**. | §1.1, the RV2-1 phantom rule. Unverified impressions are still worth logging — they are not worth counting |
| **R7** | **The log is append-only in fact, not by promise.** One finding per line, fixed field order, machine-parseable. No run may alter or remove an existing line. | the pattern-detection premise — "one finding is noise, 14 in a week is a process defect" — is a claim about the history. A history that can be rewritten supports no claim |
| **R8** | **The summary is overwritten each run** and is fully **recomputable from the log alone**: critical items, per-slug violation counts over 24 h and 7 d, last violation date per slug, plus the run's own denominators (checks run, checks skipped and why, sweep coverage). | a summary that cannot be recomputed from its source is decoration; the denominators are what make silence interpretable (standing rules 3 and 6) |
| **R9** | **Checklist checks are baseline-relative, not boolean.** Each mechanized check records a **value**; the registry records the **baseline**; a violation is a **regression against baseline**, not a nonzero exit. Baselines are dated and cite the run that set them. | `claimlint` exits 1 today (§1). A boolean `claimlint-green` check would be red forever from day one and would be filtered out by every reader within a week |
| **R10** | **The registry is tracked in git; the log is not.** Registry entry fields: slug, check (command or procedure), baseline + date, grade, first-seen, and the two citations that justified adding it (R11). | the checklist is durable process knowledge and must survive `git clean -x`; the log is working memory. See §7.1 for the tension this leaves |
| **R11** | **Registry growth rule: a slug is added only after the issue has recurred, with both instances cited.** One occurrence is a task for Orcha, not a checklist item. | a checklist that grows on speculation becomes a wish list, and every run then reports on hypotheticals |
| **R12** | **A sweep is one bounded pass and declares its coverage denominator** — what it visited and what it did not. Argus does not recurse until satisfied. | "I walked the project and found nothing" is uninterpretable; "I read 41 of 312 files under `docs/` and found nothing" is a measurement |
| **R13** | **Pacing is prod-driven.** Target cadence, advisory: every ~10 min during active development, hourly when passive, daily otherwise. When findings exist, work one sweep or one checklist item at a time; when clean, idle and available for other work. Argus does not self-schedule. | there is no cron mechanism in this project yet; the human or Orcha prods (067 §Pacing) |
| **R14** | **Findings reach the queue only through Orcha.** Argus may write a *proposed* brief into the log, marked as proposed; it never registers one. | R2. A finding merely mentioned is a finding lost (`ORCHESTRATOR.md @ 45deb10:17`) — the routing is Orcha's cadence step 5, and this is why A6 exists |

**Out of scope**, explicitly: any autonomous pulse or cron mechanism; blocking
authority; repairing anything Argus finds; adjudicating claim semantics or claim
status (that is the Auditor's, `AUDITOR.md @ 45deb10:1-31`); reimplementing what
`claimlint` and `managent audit` already check (Argus **invokes** them —
`AUDITOR.md @ 45deb10:27`: cite those, don't re-derive); a graphical or web
surface.

## 4. The two modes

### Mode 1 — unspecified sweep

Walk the project end to end and ask what looks wrong. Version mismatches,
missing files, artifacts that will not load, channel messages referencing dead
tasks, agents silent for days. **One pass** (R12), record findings, state
coverage.

Mode 1 is judgment work on a cheap model, which is exactly the risky
combination. Two mitigations are requirements, not advice: R6's evidence rule,
and A2's measured phantom rate — with a decision rule attached that can descope
this mode entirely.

### Mode 2 — checklist

The five seed slugs from 067, each mechanized against a tool that exists, with
the baseline **measured on `45deb10` while writing this spec**. These baselines
are proposed, not ratified; the first Argus run re-measures and the registry
records that run as the baseline-setter.

| slug | mechanization | baseline @ 45deb10 |
|---|---|---|
| `claimlint-green` | `bin/weizigo-claimlint`; record C1a orphans, C1b alarms, C2 dangling, C6 cite-tag mismatches, and the calibration verdict — **not just the exit code** | exit 1 · C1a **10**, C1b 0, C2 **13**, C6 0, calibration PASS. (C3 = 73 and C4/C5/A counts are report-only in the tool and are logged, not gated) |
| `stale-in-progress` | `managent liveness` for heartbeats, plus `managent show <id>` per `in_progress` task for its `claimed:` timestamp; violation = >24 h with no heartbeat | **0** `in_progress` tasks; liveness reports none. See §7.2 — `managent status --json` omits timestamps, so this check costs one `show` per in-flight task |
| `artifact-loadable` | `bin/weizigo-oracle <absolute-path>` exits non-zero on load failure. Set: the four hashed `artifacts/*.wzo` (2×2, 3×2, 3×3, 4×3) and `data/oracle-4x4-basicko-tie-area.wzo` | **not measured** — the load set is a design decision (which artifacts are "active") and the first run sets it. The 4×4 loads are 258 MB each; the run budget is a design question |
| `orphan-gate` | `bin/managent audit` (exit non-zero = FIX-level findings) plus a `status --json` cross-check for a `dispatchable` task whose `needs` are unmet | `managent audit`: **clean, exit 0** |
| `ephemera-creep` | `du -sh untracked/` and files >10 MB under `untracked/` not referenced from `docs/evidence/` | **494 MB** total; two >10 MB files, both 246 MB: `untracked/oracle-4x4-writesoff-bracket.wzo`, `untracked/oracle-4x4-writesoff-checkpoint.wzo` |

The checklist grows per R11.

## 5. Acceptance criteria

Each states what a **wrong** Argus scores.

| id | criterion | what a wrong answer scores |
|---|---|---|
| **A1** | **Known-bad calibration.** Three seeded defects in a scratch copy — a `claimlint` row broken to add one C1a orphan, a registry check pointed at a deleted file, and a 20 MB file planted in `untracked/` — produce **exactly three** checklist violations, each naming its slug, and **no other slug flips**. | a watchdog that never barks and one that always barks are indistinguishable from their output. This is the sharpest criterion |
| **A2** | **Mode-1 phantom rate, measured with a denominator.** One sweep on the unseeded tree; every finding graded `must` or `critical` is adjudicated real-or-phantom by a **different seat** that did not run the sweep. The rate is recorded. **Decision rule: if more than half of the `must`/`critical` findings are phantom, mode 1 does not ship in pass0** — the registry and mode 2 ship, and mode 1 is descoped to pass1 with a different instrument. | §1.1. A pass0 that ships an unmeasured mode 1 is a bet that a cheap model does judgment work, placed without looking |
| **A3** | **Append-only, proved mechanically.** Run twice; the log after run 2 contains the log after run 1 as an **exact byte prefix**. | R7. "Append-only" as a documented intention has no test |
| **A4** | **Summary reconciles to the log.** A recount performed from the log alone, by a seat or script that did not produce the summary, reproduces every count, every last-violation date, and every denominator. | a summary that drifts from its log is a second source of truth, and the cheaper one wins by default |
| **A5** | **Read-only, proved mechanically.** After a full run of both modes, `git status --porcelain` shows **no** change to any tracked file and **no** new untracked path other than the two allowlisted files. | R3. This is the criterion that makes "read-only" checkable rather than promised |
| **A6** | **Consumer-load test.** Orcha reads `untracked/watchdog-summary.md` **without reading the log** and either registers at least one briefed task from it or states explicitly that nothing needs registering. | `sprint.md @ 45deb10:236-239` — the consumer-load test is non-negotiable, and the consumer here is Orcha's cadence, not a human eye. Output nobody can act on is not output |
| **A7** | **Cost reported.** Wall clock and turn/token cost recorded for one full checklist run and one sweep, with the artifact-load time broken out separately (the 4×4 loads dominate). | R13's ~10-minute cadence is only credible if a run is cheap. No threshold is invented here; the numbers are the deliverable, and they are what a pass1 cadence decision needs |

## 6. Modules — the delegable units

```
   M1 ROLE            M2 FORMAT  (blocks M3, M4)
   (needs only          /     \
    ratified spec)    M3 REGISTRY   M4 CALIBRATION + FIRST RUN
```

| id | module | owns | depends on |
|---|---|---|---|
| **M1** | **Role definition.** `ARGUS.md` in the same voice as its siblings: what the seat is for, the R3 write allowlist and forbidden verbs verbatim, the advisory boundary, the Auditor/Orcha/Argus boundary, and the on-resume read order. | `docs/infra/roles/ARGUS.md` (new) | ratified spec only — concurrent with M2 |
| **M2** | **Output format.** Log line grammar (fields, order, timestamp format, grades), the append-only mechanism, the summary layout, and the recomputability contract A4 tests. | `docs/infra/argus/pass0/design.md` | ratified spec |
| **M3** | **Checklist registry.** The five seed slugs mechanized as exact commands, baselines re-measured and dated, the R11 growth rule, and the R9 regression semantics per slug. | a tracked registry file under `docs/infra/argus/` (path is M2/M3's choice) | M2 format ratified |
| **M4** | **Calibration fixtures and the first live run.** A1's three seeded defects, A2's adjudicated sweep, A3/A4/A5 mechanical checks, A6 with Orcha, A7's numbers. | `docs/evidence/ARGUS/` | M3 |

**M2 blocks M3 and M4 and must not be parallelised with them.** Two agents
improvising a log grammar concurrently is the EXP-4→EXP-7 shape: independent
implementations that agree with each other and with nothing else.

## 7. Dependencies and known tensions

### 7.1 The log lives where evidence goes to die

`untracked/` is git-ignored. `git clean -x` deletes it
(`ORCHESTRATOR.md @ 45deb10:28`), canonical documents are banned from it
(`sprint.md @ 45deb10:85`), and the milestone's deletion gate says plainly that
nothing there survives a fresh clone. Argus's central premise — "one finding is
noise, 14 in a week is a process defect" — is a claim about accumulated history
in exactly that directory.

The human specified those paths, and this spec keeps them. The resolution is a
division rather than a relocation:

- The **log is deliberately ephemeral** working memory. Losing it costs pattern
  resolution, not knowledge.
- The **registry is tracked** (R10), carrying each slug's `first-seen` and
  baseline. So the checklist itself, and the fact that a class of issue recurs,
  survive a clean.
- When a slug's count establishes a **process defect**, Orcha promotes the
  finding into `docs/` — a registered task, a process doc, or an ADR. **That
  promotion is the durable artifact**, and R14 already routes findings through
  Orcha for exactly this reason.

**Flagged for the G1 human gate.** The alternative — a tracked log under
`docs/` — buys durability and costs a commit per run plus a growing tracked
file that no reader ever reads twice. This spec judges the untracked path plus
the promotion rule to be right, and says so explicitly rather than leaving the
QA-022 lesson to be rediscovered.

### 7.2 Tooling gaps, informational not blocking

- `managent status --json` carries `id`, `status`, `set`, `bundle`,
  `identifier`, `needs`, `holds` — **no timestamps**. `managent show <id>` does
  (`added:`, `claimed:`, `done:`). So `stale-in-progress` costs one `show` per
  in-flight task. With typically ≤ 3 in flight this is negligible; a
  `--json` timestamp field would be a small unrelated improvement and is not a
  dependency of this sprint.
- There is **no cron mechanism**. R13 is prod-driven for that reason, and the
  autonomous pulse is explicitly out of scope (§3).

### 7.3 Overlap declared

`bin/weizigo-claimlint` and `bin/managent audit` already mechanize two of the
five seed slugs, and Orcha's cadence already runs both every turn
(`ORCHESTRATOR.md @ 45deb10:14,16`). Argus adds **cadence independent of
Orcha's turn**, and **history** — neither tool records what it said yesterday.
Argus wraps them and must not reimplement them. If that added value fails to
materialize, §8's last bullet is the exit.

## 8. What would falsify success

- **A1 fails** — seeded defects are not caught, or unrelated slugs flip. The
  instrument is not sensitive and nothing it reports can be believed.
- **A2's phantom rate exceeds half** — the cheap-model premise is refuted for
  judgment work. Mode 2 still ships; mode 1 does not, and pass1 needs a
  different instrument (routing sweep output as *questions to Orcha* rather than
  as findings is the obvious candidate, and is not designed here).
- **A5 fails** — a run mutated something. "Read-only" was aspirational, and the
  role's entire safety argument (Tier B, human-only approval) was wrong.
- **A6 fails in practice** — the summary is read by nobody and the log
  accumulates. This is the **most likely quiet failure**: the output exists, the
  cost is real, the benefit never lands. It presents as a clean watchdog with no
  consumers, not as an error.
- **Every finding Argus produces was already produced by `claimlint` or
  `managent audit`** — then Argus is a seat and a cadence with no information
  content. The correct response is to fold the checklist into `managent audit`,
  add the 24 h/7 d history there, and retire the role. This is a legitimate
  outcome of pass0 and must be reported, not worked around.

## 9. For the spec auditor

Per `DELEGATOR.md` rule 5 you should know less than the author. Grade findings
**blocker / critical / must / should / could**; return **PASS /
PASS-WITH-EDITS / NEEDS-FIX / REDO**. Write to
`docs/design/argus/spec-audit-1.md`. Hygiene: cite file+line against the
*current* text, and cite acceptance criteria by slug (`A2`), never bare number.

Questions worth asking, offered without answers:

1. **§7.1** — is the untracked log plus the promotion rule sufficient, or is
   this the QA-022 lesson repeating with a rationale attached? What is lost the
   first time `git clean -x` runs mid-milestone?
2. **A2** — is "measure the phantom rate and descope mode 1 above half" the
   right gate, or is a threshold on a single sweep too small a sample to decide
   a mode on? Would routing sweep output as questions rather than findings be
   the better *default*, not the fallback?
3. **R9** — does baseline-relative checking create a ratchet that normalizes
   red? `claimlint`'s 10 orphans become "baseline" and stop being reported.
   Is that the correct trade, and if so what forces the baseline back down?
4. **§4** — do these five slugs cover the recurring issues this project
   actually has, or the ones easiest to mechanize? Working from
   `docs/epistemic/CLAIMS.md` and `docs/infra/model-perf.md` rather than this
   spec: what recurrence is visible there that no slug catches?
5. **R2/R12** — is "advisory only" stable under pressure? What is supposed to
   happen the first time Argus is right and the agent proceeds anyway; does the
   spec need to say, or is silence correct?
6. **R12** — can a mode-1 "walk the project" pass state a coverage denominator
   honestly, or does the requirement invite an unfalsifiable coverage claim?
7. **Tier B** — is the tier right? The argument is that read-only bounds the
   damage to wasted attention. Is wasted attention actually cheap in a project
   where the human is the dispatch mechanism?
