# Model-performance observations (untracked scratch — impressions, not science)

**Status: living scratchpad. [Current.]**

**Model-label normalization (T276, 2026-08-02):** model spellings in this file
now use the canonical labels `deepseek-v4-pro` / `deepseek-v4-flash` (human's
ruling 2026-08-02; table in `docs/infra/delegation/DELEGATEE.md` §Identity).
Renamed in place — content otherwise preserved. The model part of worker
identifiers (`DSPro/2B-3-AUDIT` → `deepseek-v4-pro/2B-3-AUDIT`) was renamed
too: an identifier spelling the model one of four ways is the defect this
sweep exists to remove. Left as recorded, with reasons: the T120 attribution
section's verbatim description of the raw `agent` fields (kept so it keeps
describing what it describes), the quoted rule name "not DeepSeek for Zig",
and the vendor reference "spend DeepSeek vs Ollama-model budget".

TODO: record the general facts about each model. Then keep notes of each model in different contexts or with different tasks.

## Model versions (record here as they change)

- **TEMPORARY default — operator ruling 2026-08-05 (widened same day), expires 2026-08-12:**
  `deepseek-v4-flash` is the **default model for ALL new dispatches this week — worker rows
  AND sprint-manager consoles** — unless a clear weakness is discovered for a specific task
  type or role; record any such weakness here, with the row that showed it, and carve that
  task type out rather than reverting wholesale. The operator's reasoning, recorded: the
  project has no experience/data entitling it to say "not for this role"; default-to-Flash
  until the ledger says otherwise. First live sprint-manager trial: the next sprint package
  dispatched (T363 is queued). Risk containment is the existing machinery, not model choice:
  inbox checkpoints, heartbeats, the Orchestrator's review of the sprint's accept doc, and
  the discharge ruling still gates — a weak sprint manager costs time, never truth.
  This doubles as the alternative-hypothesis test the Belief audit (below) says is missing:
  a week of Flash-allocated rows across task types generates the Pro-vs-Flash comparison
  data that the old always-Pro default structurally could not. At expiry: re-rule on the
  week's ledger, don't let the temporary default silently become a decided one.
- **deepseek-v4-flash — preview-channel bump, reported 2026-08-05 (operator).** DeepSeek
  updated its models without changing the V4 version string; Flash is reportedly on a
  "preview state" and may be cheaper and stronger than Pro on many tasks. The canonical
  label is unchanged, which means **the label no longer pins the model across dates** —
  any head-to-head run (T328 protocol) must record the exact serving tag and date, and
  pre-bump Flash rows in the ledger are not comparable with post-bump ones. First
  post-bump observation: T365 (32-entry rename sweep with ~100 reference updates) at
  ~31,000 tokens (console `3.1%/1.0M`, relayed by operator) while still in progress.


- GLM-5.2 (worker, boss/orchestrator) — glm-5.2:cloud, context 950 k
- **Minimax-m3** (worker) — minimax-m3:cloud
- **Kimi-k2.7** (worker / auditor) — kimi-k2.7-code:cloud, context ~556 k
- **Kimi-k3** (worker, frontier; first dispatch EXP-11 2026-07-28) —
  first data points below. Not the same model as the k2.7 line; this
  is the project's first exposure to the k3 frontier. **Context
  window: 128k (Kimi-k3 via Ollama in the pi harness only)**, which
  is sufficient for a single-function audit or a bounded code change
  but constrains the brief + report shape (a 200-line report is
  fine; a multi-thousand-line chained audit is not). Cost on EXP-11
  (10–30 min bounded code audit): \$0.23; cost on EXP-16 (30–60 min
  bounded code audit): not yet recorded.
- **Opus 5** (overview / adversarial reviewer / brief author, from 2026-07-27) —
  remit set 2026-07-28 (`untracked/msg/milestone-01-ko-reframe/STATE.md`):
  grand overview, epistemic tree, adversarial review of load-load-bearing
  proofs, ruling on claim semantics; **does not execute mechanical work**.
- **Fable** (hardest reasoning tasks, documents over implementation) —
  allocated 2026-07-28 (D-7); first dispatch EXP-2 Part A (returned
  REPAIRABLE-GAPS, repaired, 2026-07-28).

## Belief audit — what we think we know about models, 2026-08-05 (Fable, operator-ordered)

**The operator's finding, recorded as a standing correction:** model-allocation beliefs in
this project were largely *decided* early, then data was collected under those allocations —
which can only confirm them. A model that never gets hard rows never fails one; a seat only
one family ever held has no comparator. From here on, allocation beliefs are **hypotheses**,
and the T328 head-to-head protocol is how they earn or lose their standing. This section is
the baseline snapshot to race against.

**Class A — measured (harness-reported or counted; trust as stated):**
- Context windows table below (model × harness).
- Ledger verdict counts (2026-08-05, all 138 rows): deepseek-v4-pro 41 pass / 11
  pass-with-findings / 11 abandoned; deepseek-v4-flash 17/1/0; glm-5.2 ~10 with 3
  amendments; minimax-m3 4/1; kimi-k2.7 3 rows. **Counts are real; rankings drawn from
  them are not** — see Class B.
- Identity doctrine: introspection unreliable (2/2 wrong), told-identity echo reliable (4/4).
- deepseek-v4-flash post-bump: T365 sweep at ~37 k tokens (`3.7%/1.0M`) near completion.

**Class B — observational, confounded by allocation (plausible; not evidence of ranking):**
- "DS Pro strong at code but dies at 4×4 scale" — it *got* the biggest rows because it was
  the default; its RSS-kills happened where no other model was ever sent.
- "glm-5.2 clean on leaf rows", "minimax-m3 good at infra rows" — each measured only where
  it was allocated; no same-row comparator exists for any of these readings.
- "Opus is a good Orchestrator" — the seat's best recorded acts (the 22-entry-sample catch)
  and worst (the kill -9 sweep) both belong to the only family seated under current tooling.
  n=1 family, zero comparators.

**Class C — decided, never tested (hypotheses awaiting a race):**
- Opus for orchestration; DeepSeek as default worker; Fable only for deep holistic work;
  "not DeepSeek for Zig"; Pro over Flash for subdelegating rows. Each was an allocation
  ruling. None has head-to-head data. The Pro-vs-Flash race (first, per operator demand)
  and the orchestrator-aspect races below convert these to Class A or kill them.

**Racing the orchestrator role without seating anyone.** The role decomposes into bounded,
answer-keyed tasks, each dispatchable to N models under the T328 protocol:
1. **Triage** — given a findings dump, register the right rows with correct `needs`/`holds`
   (scored against a sealed key).
2. **Verdict discipline** — a delivered row with a planted flaw (e.g. a pass condition with
   no denominator) must be refused; the 22-entry-sample catch is the canonical seeded test.
3. **Inbox handling** — drain a seeded directive backlog correctly (acks, kills, amends).
4. **Crash recovery** — from `managent resume` + STATE.md alone, state the correct next
   three actions (keyed).
5. **Dispatch authoring** — write the delegation package for a known row; blind-graded.

**The direction that makes the races matter:** keep shrinking the seat mechanically —
`resume` (T286), inbox loop (T355), reap (T364), orient (T353), a scorecard subcommand —
until the residual orchestrator is a checklist a cheap model (or eventually a script)
executes, with drift caught by periodic deep audits (the operator's ~daily Fable/audit
spawns) whose job is "get the project back on track", not continuous supervision. The
cheapest model that passes the aspect races gets the seat; the audit cadence is the safety
net that makes that experiment reversible.

**T371 first race runs (2026-08-05, conductor glm-5.2/T371 — non-deepseek): Pro-vs-Flash on
races 1 and 2.** Run doc: `docs/evidence/EPISTEMIC-RACES/runs/2026-08-05-pro-vs-flash.md`; scores
`findings/T371-race-first-runs.json`. Race 1 (falsification design, graded by execution, recall /
3): **flash 3/3 (0 false alarms), pro 2/3 (1 false alarm — its R1-P3 test crashed on both mutant
and clean: the dag omitted the leaf-node entries, so a correct idea was scored as a non-running
test).** Race 2 (honest refusal, confusion matrix vs key, point iff verdict correct AND gap named
correctly): **both 4/6**, with *different* error structures — flash leaned skeptical (two false
refusals of grounded packets R2-P1/R2-P3, all three real gaps named right); pro was balanced (two
promotes right, one false refusal R2-P2, one **wrong-gap** refusal R2-P4 — refused correctly but
named C-A2 deferral instead of the keyed 'no denominator'). Clocks: pro wall 115.9 s / 0.95 s CPU /
195 MB; flash wall 616.8 s / 3.75 s CPU / 216 MB on attempt 2 (attempt 1 was a 600 s API stall, 0
output, 3.26 s CPU — a transient, not a capability signal). **What it licenses: a replication, not
a capability claim.** The packet author is deepseek-v4-flash and flash is a lane, so the Flash win
is confounded in Flash's favour (key tampering excluded — SHA-256 of keys + all 15 lane-facing
files re-verified against the `b7c382c` register before any lane ran; family-level prior remains).
The registered follow-up is the same two lanes against a packet set authored by a non-deepseek
family; a Flash win *there* begins to look like capability, a Flash loss *here* would already have
been informative (none occurred). n=1 standing: one run per model is an anecdote. Three protocol
findings recorded (report-don't-adapt): the bakeoff harness `execute()` cannot run from a git
worktree (`find_root` requires `isdir(.git)`; a worktree's `.git` is a file) — the real run used
the `--emit` block from a worktree; the worktree boundary is relative-path-only (the harness does
not pass `--no-tools`, so a tool-using lane could reach the main repo's `untracked/race-keys/` via
absolute paths — mitigated here by the inlined self-contained brief); and the flash attempt-1 API
stall.

## Context windows (model × harness) — consolidated 2026-08-03

The window is a property of the **model × harness pair**, not the model: Ollama's
effective window is the serving config, and the pi harness caps differ from Claude
Code. **Record only measured or harness-reported values — never a model's
self-report** (the attribution doctrine extends here: asked what they are, 2/2
models were wrong; a self-reported window is the same class of evidence).

**The doctrine bans introspection, not relay.** An agent asked to *guess* its own
identity is unreliable (2/2 wrong). An agent **told** its identity and asked to echo
it is reliable (4/4 correct reading `PI_MODEL`), and that is precisely what
`bin/subagent`/`bin/ollama-subagent` do by injecting `--agent <canonical>`. So
`unknown/T999` in the ledger is not a lie or a guess — it is a row whose agent was
never told what it was. The fix is always injection at dispatch, never a question.

| model | harness | context window | source |
|---|---|---|---|
| `deepseek-v4-pro` | pi | 1 M | human ruling 2026-08-03; matches "New Boss … 1.0M" below |
| `deepseek-v4-flash` | pi | 1.0 M | console readout relayed by operator 2026-08-05 during T365 (`3.1%/1.0M`); harness-reported, admissible per the doctrine above |
| `glm-5.2` | pi | 1 M | human ruling 2026-08-03 — **supersedes the 950 k in the prose entries above/below** |
| `minimax-m3` | pi | 524 k | human ruling 2026-08-03 |
| `kimi-k2.7` | pi | 262 k | human ruling 2026-08-03 — **supersedes the ~556 k prose entry** |
| kimi-k3 | Ollama / pi | 128 k | EXP-11 entry below |
| `claude-opus-5` | Claude Code | 1 M | human ruling 2026-08-03; matches the handover-at-64%-of-1M evidence |
| `claude-fable-5` | Claude Code | **plan against 200 k** (1 M observed) | operator read the harness indicator 2026-08-04: window reached 1 M mid-session. The 200 k planning figure is a **cost** boundary, not a capacity one — see the note below |

This table is canonical for windows; older per-model prose recording different
numbers (glm 950 k, kimi-k2.7 ~556 k) is superseded, left in place as history.
Fill a TBD only from the harness config or a human ruling, and date it.
Operational consequence worth knowing: **Fable's window is 5× smaller than
Opus's** — Fable seats need handovers ~5× as often on the same workload.

**`claude-fable-5` window observation, 2026-08-04 — corrected attribution.** The
**human** read the harness's context indicator directly and reported it jumping
mid-session from 96%-of-200 k to 20.4%-of-1 M. That is a **harness reading by the
operator**, which this table accepts — not a model self-report, and not subject to
the never-ask-a-model rule above. An earlier revision of this note wrongly
attributed the observation to the Fable seat itself; that was the Orchestrator's
error, corrected here.

**So Fable's usable window can be 1 M.** The 200 k figure in the row is retained
deliberately, and **the reason is cost, not capacity**: the human is confident that
Fable is materially cheaper from 0–200 k than from 200 k–1 M. The exact pricing is
unknown, and whether the boundary is an allocation, an extension, or a technical
switch (context loaded into a larger window) is also unknown and **not officially
documented** — do not restate the mechanism as fact. Plan Fable work against 200 k
because crossing it costs money, not because the seat runs out of room.

**Operating rule for `claude-fable-5` (human directive, 2026-08-04) — this is the
binding one, independent of what the window turns out to be.** Hand a Fable seat over
**before 90% of 200 k**, and use Fable **sparingly** in any case. The stated reason is
that a different billing regime is believed to apply below 200 k versus 200 k–1 M.
That belief is **not officially confirmed** and is recorded here as the human's
operating assumption, not as fact — but the rule stands regardless of whether the
window is 200 k or 1 M, because the cost boundary and the window are different
questions. Practical consequence for dispatch: Fable is for work whose *value per
token* is highest — deep holistic review, gate-holder verification of a fleet-critical
control — never for cheap audits (kimi out-performed document review twice on
2026-08-03) and never for long-running orchestration.

Small-n, single-session anecdotes per model. Strengths/weaknesses only — speed
and cost are not differentiators here. Add a dated entry each session.

## GLM-5.2 (Boss, orchestrator)

- Strong on subtle foundational/logical reasoning: caught the E2 V1-equation
  bug (`oppV0[child]` not `oppV1[child]`) by reading the sweep; flagged the
  least-fixpoint crux (from-+N reaches greatest, not refuting least) in the
  audit brief — the same crux Kimi then convicted.
- Holds the orchestrator role well (delegation files, relay log, rollback
  discipline, epistemic bookkeeping). Tends to long messages — needs the
  "short volley" reminder.
- Context window 950 k; measured ~300 k used at one point (no compaction).

## Minimax-m3 (worker)

- Strong at careful, thorough *spec-first* execution once corrected: wrote a
  270-line B1 spec, self-flagged ambiguity, asked before interpreting — good
  discipline after being corrected for implement-first eagerness.
- Honest and careful with caveats. Reverts/flags its own uncertainty.
- Weaker on deeper monotone-fixpoint theory: proposed the unsound (a′)
  ("canonical isn't the least") from the +N re-converge result — a
  monotone-map misread (greatest > least is expected). Corrected by the
  Kimi audit. So: excellent implementer/spec-writer; needs a theory auditor
  on foundational claims.

## Kimi-K2.7 (auditor, one data point so far)

- Strong *ruthless auditor*: convicted the (a′) Blocker precisely via
  Knaster–Tarski (monotone map: bottom→least, top→greatest; greatest > least
  is normal, doesn't refute least). Graded findings cleanly
  (Blocker/Critical/Should/Nice), gave a crisp Boss verdict, implemented
  nothing, wrote the full audit to the response file + console summary +
  the one-liner exactly as instructed.
- Also caught the wrong §3 acceptance test and the misleading
  ko_sensitive_b=0 print. Followed instructions to the letter.
- First impression: excellent at critique/verification; worth using as the
  standing auditor for foundational claims.

## Kimi-K3 (worker, one data point so far — EXP-11, 2026-07-28)

First exposure to the k3 frontier. Different model from the k2.7
line. Dispatched on a bounded, well-specified ANALYSIS task with a
falsifiable three-verdict acceptance (the EXP-11 H-recurrence swap
check, Dabir 011's 10-min question). \$0.23, ~30 min wall.

- **Followed the brief's three-verdict acceptance to the letter** and
  returned the first verdict ("v1 transcription error only, code is
  correct") with cited `file:line` for every claim: the single
  Bellman operator at `src/retro.zig:329`, the side-keyed `comptime
  (side > 0)` at `:266`, the seed difference at `:238`, and the
  byte-equivalent lean `coreSweep` (`:1940-1998`, called on both
  quads at `:2075-2078`). Cited the spec (`docs/decisions/0009-
  retrograde-value-iteration.md` §"Decision 2") and the proof side
  (v1 §4.2 swap; v2 §4.1 + §9 item 3 already record it as a
  superseded v1-only defect). Did not propose a fix because the
  code does not have a bug; that is the correct answer.
- **Caught the brief's wrong citation** ("v2 §1.4") and corrected
  it inline (the note is at §4.1 and §9 item 3; v2 has no §1.4).
  Substance unaffected, but the worker surfaced the bad pointer
  rather than papering over it. That is the right hygiene: a worker
  who quietly uses a wrong citation and ships looks competent in
  the moment and corrupts the ledger over time.
- **No engine file touched. No data/ or artifacts/ touched. No
  fix proposed.** The brief said "read only"; the worker read only.
- **First impression:** the k3 line inherits k2.7’s discipline on
  bounded audits but is faster and noticeably cheaper at the same
  task (\$0.23 vs. an unrecorded k2.7 cost). On bounded, well-
  specified code-audit work the k3 line is a clear win. **Not yet
  measured on harder reasoning** (proof repair, ADR refutation,
  claim-semantics adjudication) — Fable holds those per D-7.
  Worth a follow-up on a non-trivial chainability audit (chunk 1
  of the Muhtasib plan) and on a H5a-style bounded code change,
  to see whether the speed/cost advantage holds when the brief
  is less crisp.

### EXP-16 (2026-07-28) — second data point

Same model, same shape (30–60 min bounded code audit, three-
verdict acceptance, falsifiable). Context window: 128k. Produced
a 225-line audit plus a `PROVENANCE.md` (per
`docs/evidence/README.md`) without trouble. Verdict VERIFIED;
`Session.choose` is a one-ply table extremum only.

- **Decisive structural finding:** `src/gtp.zig` does not import
  the solver (only rules/colex/artifact/score imports at :55–58),
  so `solve.zig` / `retro.zig` are unreachable from the GTP
  player’s `Session` code. A `grep` for `solve|Exact|retro|
  finisher|arena` hits only comments. That is the kind of
  evidence a one-line structural check beats a 200-line walk
  for: the imports *are* the proof.
- **Caught a substantive secondary finding I missed in the
  brief:** the claim is **not in AGENTS.md** at any commit (`git
  log -S` empty); the verbatim form lives in HANDOVER.md
  §“Gotchas” (:61–63); HANDOVER §“Critical state” does not
  repeat it. The relying opus verdict is
  `docs/audits/2026-07-28-muhtasib-audit-chunk2.md:48`
  (Auditor chunk 2, in flight), not
  `audit-opus-2026-07-28.md`. This is a real claim-location
  correction: I cited AGENTS.md in the brief, the claim is in
  HANDOVER.md, and the worker's audit has to point at the
  correct file for the calibration check to land.
- **H5a calibration is the load-bearing part of the audit**
  (the H5a mitigation in EXP-9 depends on the claim four ways:
  the ~2n-lookups cost model, A2's "the move choose would
  return" reproducibility, "no strength lost" on the chainable
  region, and the −16-child pick at ply 8 of the regression
  game). Kimi-k3 ran the calibration as a real test, not a
  ritual: VERIFIED sustains all four. Two wrinkles flagged for
  the H5a implementer (replicate the early-game override when
  computing C*; A1 must decide how the v1_from_table-priced
  pass option enters the node identity) are the kind of
  hand-off notes a careful auditor produces and a careless one
  doesn't.
- **First impression, refined:** the 128k context window is
  **not** a constraint on the kind of task the project usually
  calls "bounded code audit." The brief, the read of `src/gtp.zig`
  + the four callee files, and the 225-line report fit
  comfortably. The constraint is on the *kind of report*: a
  multi-thousand-line audit that chains through several files
  with deep context would be tight. **Use k3 for bounded,
  well-specified audits; do not use it for an open-ended
  sweep of a large codebase.**
- **Comparable-to-Opus-4/5/Fable hypothesis (user's framing):
  the 128k window is the visible difference, not a competence
  gap on the task class. On bounded code-audit work, k3 is a
  clear win at \$0.23 and ~30 min. Whether k3 matches Opus/Fable
  on harder reasoning (proof repair, ADR refutation) is an open
  question; Fable holds the harder slots per D-7, and a direct
  comparison is the right next data point when one of those
  tasks is dispatchable to a k3-capable console.

## Cross-model takeaway (early)

- GLM-5.2 + Kimi-K2.7 converge on the subtle theory; Minimax-m3 is the
  workhorse but benefits from a theory audit. Pattern: Minimax implements →
  Kimi audits → GLM-Boss adjudicates & integrates. Worth measuring more.

## Cross-model takeaway — 2026-07-28 (post standing-tier wave)

The 2026-07-28 standing-tier audit wave (EXP-13 Minimax-m3,
EXP-14 GLM-5.2, EXP-15 Kimi-k2.7, EXP-11/16 Kimi-k3) tests the
above pattern on three different task shapes:

- **Reading + cataloging (EXP-13, Minimax-m3):** re-run a tool,
  parse stdout, build a per-finding table with one-line
  remediations. **Minimax-m3 nailed the shape.** 438-line report,
  verbatim stdout captured (15 KB sibling), calibration PASS on 7
  cases, per-finding table with owner-of-record, DECISIONS.md
  residue items mapped to lint findings, honest negatives named.
  No CLAIMS.md edited (audit, not edit). **This is the strongest
  case for Minimax as the standing measurement executor.**
- **Verifying someone else's record (EXP-14, GLM-5.2):** audit
  the corrections ledger against cited sources-of-truth at
  eebe3c2. **GLM-5.2 nailed the shape.** All 5 corrections
  audited; 2 VERIFIED, 3 PARTIAL, 0 WRONG, 0 to retract. The
  PARTIAL verdicts are the test: the worker distinguished
  *substance right, citation stale* from *substance wrong* and
  recommended annotation over retraction. B-1 (the ADR-0013
  closing-line-is-still-wrong finding) is the most consequential
  load-bearing correction in the ledger; EXP-9's division of
  labour with Track A depends on it. **GLM-5.2 in the Boss
  role reviewing a prior session's record is the right slot.**
- **Grading findings (EXP-15, Kimi-k2.7):** 13 hypothesis rows
  tagged CLOSED/IN PROGRESS/OPEN/REJECTED with evidence
  pointers. **Kimi-k2.7 nailed the shape.** Two CLOSED closures
  (H1-CENSUS by EXP-3; H4b by the 2026-07-28 exhaustive
  chainability sweep), one REJECTED (H5c = C3, falsified at
  3×3), and a "what to dispatch next" list as the standing-tier
  queue feed. The deliverable's provenance cites the commits,
  not the file mtimes (correct; mtimes are not durable). **Kimi-
  k2.7 in the standing-auditor role continues to be a strong
  fit.**
- **Bounded code audit (EXP-11/16, Kimi-k3):** two data points
  now. Both VERIFIED verdicts, both ~30 min, both $0.23 / $0.76
  cost. The 128k context window is sufficient for a single-
  function audit but constrains multi-thousand-line chained
  reports. Kimi-k3 inherits Kimi-k2.7's discipline on bounded
  audits and is faster and cheaper. **Bounded code-audit work
  is now Kimi-k3's standing slot; do not use it for open-ended
  sweeps.**

The pattern holds: Minimax measures, Kimi-k2.7 grades, GLM-5.2
reviews, Kimi-k3 audits. **Bounded code audits are now Kimi-k3's
slot; Fable and Opus hold the harder reasoning per D-7 and
MSG 008.**

## Cross-model takeaway — Opus-4/5/Fable comparable-to-Kimi-k3 (open)

User's framing: Kimi-k3 should be comparable to Opus-4 (and
perhaps Opus-5 and Fable, to be seen). On the bounded code-audit
task class (single function, ~200-line report, three-verdict
acceptance, falsifiable), Kimi-k3 is *clearly* faster and
cheaper than the Fable data point (Fable's EXP-2 Part A ran on
the order of hours; Kimi-k3 ran EXP-11 in ~30 min for $0.23).
**Whether Kimi-k3 matches Opus-4/5/Fable on harder reasoning
(proof repair, ADR refutation, claim-semantics adjudication)
is an open question** — the harder slots are reserved for
Fable per D-7, and no direct comparison has been run. When
one of the harder tasks (EXP-10 QA-018 ADR refutation, the
next Muhtasib chunk 2) is dispatchable to a k3-capable console
in parallel with the Fable/Opus run, a head-to-head becomes
the right next data point. **Until then, the trend on bounded
code audits is the only signal we have.**

## Kimi-k2.7-code (new Boss, 2026-07-25)

Taking over as Boss from GLM-5.2. First task was to ingest the full epistemic
state before managing parallel workers. Read order that worked:
`PROGRESS.md` → `status/leak-crisis.md` → `status/CURRENT.md` →
`boards/4x4/EPISTEMIC.md` + `boards/CONCEPTS.md` + `names.md` →
`agent-workflow.md` → the completed worker outputs (`T04-minimax.md`,
`T05-audit-proven.md`, `T06-audit-falsified.md`, `T08-killx-reexamine.md`).

### Quality report on the parallel batch just completed

- **Minimax-m3 — T04 doc pruning:** excellent. Followed the negative
  constraints exactly (`src/`, `AGENTS.md`, `PROGRESS.md`, `boards/`,
  `CURRENT.md`, artifacts untouched). All seven subtasks done in ~25 min.
  Produced concise, well-structured output. The only minor improvement:
  could have noted approximate line counts in each condensed research file
  inline rather than just the total. Strong executor once given a bounded,
  mechanical task.

- **GLM-5.2 — T05 audit of ✅ PROVEN claims:** very strong. Did not just
  accept labels; separated theorem from measurement, identified S4 and FP3
  as misfiled under PROVEN, and gave the honest 4×4 boundary answer
  (C2 untestable at 4×4; boundary is 3×3→4×4). The audit is almost a small
  decision document in itself. Grade distribution was fair and actionable.

- **Kimi-k2.7 (worker) — T06 audit of ❌ falsified claims:** excellent
  plain-English rigor. For each falsification it answered (a) where tested,
  (b) what exactly is falsified vs what survives, (c) why it is false in
  human terms. The summary table is a clean decision artifact. No code
  touched, as instructed.

- **GLM-5.2 — T08 kill-X% re-examine:** good code-level verification
  (proved 4×4, instant-end, not tested capture-all). Honest about the open
  gaps: the direction mechanism is claimed not proven, and the ko-sensitive region
  structure (small-capture tangles vs big swings) is not directly measured.
  Recommended a cheap capture-all probe; this is a useful next step if the
  user wants it closed.

### Cross-model takeaway (updated)

The GLM-Boss + Kimi-auditor + Minimax-worker pattern from `model-perf.md`
held up in this batch. Kimi (as auditor) and GLM (as Boss/auditor) converge
on subtle theory; Minimax is a reliable implementer/doc-pruner for bounded
tasks. The new Boss (this instance, Kimi-k2.7-code) needs to stay disciplined
about not drifting into implementation while orchestrating.

### First impression as Boss

The documentation tree is genuinely usable for a fresh handover —
`PROGRESS.md` + `status/CURRENT.md` gave the live state, and the per-goban
`EPISTEMIC.md` gave the precise claim map. The biggest friction was the
sheer number of untracked scratch files; a consolidated index or a
"last N completed tasks" section in `CURRENT.md` would speed up resumption.
The quality of the parallel outputs is high enough that the Boss's main job
is now integration, prioritization, and deciding the next experiment (likely
C2-probe at 2×2/3×2 or capture-all kill probe at 4×4).

## Minimax-m3 — T07 audit of open hypotheses (second data point, 2026-07-25)

**Role:** hypothesis/experiment auditor. **Task:** read-only review of the ⬜
claims in `docs/boards/4x4/EPISTEMIC.md` and the experiment plan; grade design,
vacuous-pass risk, null hypothesis, falsifiability, cheaper alternatives, and
parallelization. **Output:** `untracked/T07-audit-hypotheses.md` (~42 KB).

**Strengths shown:**
- Excellent systems-level thinking about what each experiment actually tests
  vs. what it claims to test.
- Produced a genuine parallelization map (Wave 0/1/2/3) with dependency edges
  and serial gates.
- Caught the "tests the wrong artifact" problem for F2/F3 (committed artifact
  uses the unsound `ko_ref >= d` guard; validating writes-off requires a regen).
- Caught the underspecified C2-probe (no sample size, no ban-set distribution,
  no long-history coverage) and the missing 2×2/3×2 pilot.
- Correctly identified that FP1 least-ness is Knaster–Tarski from `-N` seed,
  and that the re-converge-from-`+N` test is a multi-fixpoint observation, not
  a least-ness witness.

**Weaknesses / caveats:**
- A few time estimates feel optimistic ("~hour" for S2-4×4 exhaustive Benson;
  "~minutes" for C2-pilot-2×2/3×2). Should be treated as orders-of-magnitude
  until measured.
- The C2-bounded vs. C2-general distinction is framed as a doc fix, but the
  underlying mathematical question (can L==H ever fail for arbitrarily long
  histories?) remains open and possibly unprovable by finite methods.

**Updated cross-model takeaway:**
Minimax is not only a strong implementer; with the right framing it can
also audit experiment design. The pattern is becoming: **Minimax specs/
implements, Kimi theory-audits, GLM integrates/adjudicates, and any of the
three can do read-only audits when the scope is tightly bounded.** The
bottleneck is not model capability but task clarity and parallelization
hygiene.

## User direction — Boss protocol update (2026-07-26)

User clarified expectations for the Boss role and project workflow:
- C2 scope: attack bounded-history first; unbounded-history is a separate
  research question.
- Build budget: no long-term ceiling, but tasks must be ≲1h chunks, fail-fast,
  recoverable; night runs allowed but still chunked.
- Capture-all: wait for T15 design before deciding.
- Doc-first vs. run-first: Wave 0 runs in parallel with T16.
- Boss must make decisions, document them, and provide delegation prompts.
- User is worried about dead ends and unreliable proofs, not about too much work.
- These directives were recorded in `docs/agent-boss.md` and `docs/status/CURRENT.md`.

## Boss workflow refinement (2026-07-26, user feedback)

User corrected the Boss delegation style:
- Prompts must be **one line, ~50 characters** (e.g. `fresh Kimi: follow untracked/T99-tripleko.md`).
- The human may add a prose paragraph for understanding, but the agent prompt is the one-liner.
- `fresh` = human starts new session; `warm` = continue a specific named session; omit both if indifferent.
- Task files are **living docs** with subtask statuses (`open`/`progress`/`success`/`failure`), preconditions, and an output section.
- Only one agent writes a given file; audit variants use `-audit` suffix.
- Findings move to git-checked `docs/` once stable; scratch files are cleaned up after use.
- Boss updated `docs/agent-boss.md` with these conventions and declared it open to refinement/pruning.

This feedback was applied to `docs/status/CURRENT.md`, all task files, and the prompt file.

## Task completions (2026-07-26)

- **GLM-5.2 — T10 FP1 verification:** completed. Reported PARTIAL verdict:
  zero V0+V1 violations on the SOUND subset (10,995,122 positions, all whose
  children are core-or-settled), but 211,495 informational violations on the
  ALL set attributed to finisher/fixpoint mixing. WZO1 schema drops V1 quads,
  limiting full artifact-based check. Recommended follow-up: `RETRO_B1_LOFIX`
  on 4×4 (full in-RAM re-converge). Quality: strong read-only engineering;
  self-aware about limitations.
- **Kimi-k2.7 — T15 capture-all design:** completed. Produced a concise design
  with rule variant, ~12-line code footprint across `src/retro.zig`, and a
  4×4 census plan. Did not implement. Quality: clear, bounded, actionable.

## Task completion — T11 D3-4×3 pilot (2026-07-26)

- **Minimax-m3 — T11 D3-4×3 writes-off tractability pilot:** completed.
  Verdict: **GO (with caveats)**. Measured 4×3 writes-off finisher at 33.3 s
  vs reuse at 2.7 s (12.23× wall, 16.62× nodes, 28.25× max/root). 4×4 build
  8.5 min, 819 MiB peak. Estimated 4×4 writes-off finisher 45–75 min at
  100–200M/root, peak 3–5 GiB. Provided clear chunked plan and risk list.
  Quality: excellent measurement + honest uncertainty quantification.

## User correction — small-goban C2 is not evidence for 4×4 (2026-07-26)

User rejected the framing that a C2-pilot on 2×2/3×2 constitutes evidence for
4×4. It is strictly a **falsification test / method calibration**:
- If C2 fails at 2×2/3×2 → C2 collapses everywhere.
- If C2 passes at 2×2/3×2 → it is not obviously false, but proves nothing about
  4×4 without a monotonicity theorem (which does not exist yet).

Boss updated `docs/agent-boss.md` (no pre-provided future prompts; `fresh` is
the normal dispatch mode), `docs/status/CURRENT.md`, `untracked/T12-minimax.md`,
`untracked/T13-minimax.md`, `untracked/T16-glm.md`, and the prompt file to
reflect this correction. Also noted that a 5-hour Ollama token limit hit;
sessions terminated; T16 resumed without data loss.

## Task completion — T16 EPISTEMIC/CONCEPTS rewrite (2026-07-26)

- **GLM-5.2 — T16 doc rewrite:** completed. All output-section checkboxes
  ticked; result reported as DONE. Will review the actual content once the
  file is read. Quality pending review.

## Task completion — T10-fp1-audit (2026-07-26)

- **Kimi-k2.7 — T10-fp1-audit:** completed. Read-only audit of GLM's T10
  verdict. Confirmed the SOUND-subset definition is correct, the 211,495 ALL-set
  violations are expected finisher/fixpoint mixing, and PARTIAL is the honest
  verdict. Recommended `RETRO_B1_LOFIX` on 4×4 to close to full PASS. Quality:
  rigorous, well-structured, actionable.

## Workflow refinement — agent lifecycle and prompt timing (2026-07-26)

User clarified:
- The user manages agent lifecycle: can kill idle sessions, spawn up to 4–5
  agents. The Boss does not track free/idle sessions.
- When the user says "we wait on X," the Boss updates `CURRENT.md` to say
  "WAITING on X" and lists the next dispatch order; no new prompts offered.
- Prompts are provided only for dispatchable-now tasks; future prompts are
  stated in prose in `CURRENT.md`, not as copy-paste one-liners.

These rules were added to `docs/agent-boss.md` and applied to
`docs/status/CURRENT.md` and `untracked/delegation-prompts-2026-07-26.md`.

## Task completions — T09 and T17 (2026-07-26)

- **Minimax-m3 — T09 S2-4×4 Benson regression:** completed. Added
  `naive_pass_alive`, `pass_alive_regression_check`, and 4×4 exhaustive test in
  `src/rules.zig` plus standalone drivers. Checked all 24,318,165 legal 4×4
  positions: 0 mismatches, 0 immediate-capture violations. Also validated via
  deliberate bug injection. Quality: strong engineering + sensitivity proof.
- **GLM-5.2 — T17 F4-4×4 KM deps design:** completed. Produced detailed design
  with commands, byte-compare procedure, auditor plan, wall/RAM estimates,
  risk list, halt conditions, and epistemic framing. Quality: thorough,
  actionable, honest about scope.

## Task completion — T14.1 bracket-only converge (2026-07-26)

- **Minimax-m3 — T14.1:** completed PASS. 4×4 writes-off bracket-only artifact
  produced at `untracked/oracle-4x4-writesoff-bracket.wzo` (258 MB, sha256
  recorded). 24,318,165 legal positions; 38,268,408 certified slots (78.68%);
  10,367,922 ko-sensitive (21.32%). Small `src/retro.zig` fix needed to skip
  finisher cleanly in bracket-only mode. Wall ~10.5 min. User redirected: skip
  T14.2 now, dispatch T12 (C2-pilot-2×2) next; T14.2 contingent on C2 results.

## Boss reflection — Minimax bottleneck (2026-07-26)

User observed that the Boss was routing most implementation tasks to Minimax.
Reasons: (1) accidental path dependency (Minimax picked up the first engine
chunks), (2) one-writer-per-engine-file rule meant Minimax held `src/retro.zig`
for T11/T14, and (3) Minimax had a strong track record (T02, T09, T11, T14.1).
However, this created an unnecessary bottleneck. Boss added a principle to
`docs/agent-boss.md` to avoid single-worker bottlenecks and reassigned T13 to
Kimi and T14.3 to GLM. T12 remains Minimax because it owns the harness creation.

## Kimi-k2.7 — T15 capture-all design review (2026-07-26)

**Task:** read-only review of the capture-all kill-probe design in
`untracked/T15-kimi.md`. Recommend implement / defer / skip / modify.

**Strengths shown:**
- Carefully separated "well-defined / distinct" (high confidence) from
  "predicted outcome" (reasoned speculation), matching the project's
  epistemic discipline.
- Gave a concrete example showing why capture-all differs from kill-X%:
  wiping 3/16 stones triggers capture-all but not kill-30%.
- Honest about the helper-style caveat in `Retro.sweep` and the need to
  resolve it before coding.
- Clear recommendation with two independent reasons: core-gate priority
  + engine-file concurrency (`src/retro.zig` held by T14).
- Produced an actionable pre-impl checklist (helper style, census sentinel,
  auditor gate, artifact path).

**Weaknesses / caveats:**
- The "no collapse" prediction is explicitly flagged as speculation; not a
  weakness, but a limit on what the review can claim.

**Quality:** strong read-only judgment. The review is essentially a decision
brief, not just an opinion. Worth using Kimi for similar design-to-go/no-go
reviews.

## Boss handover — Kimi-k2.7-code resumed after compact (2026-07-26)

**Context verification:** read `HANDOVER.md`, `CURRENT.md`, `PROGRESS.md`,
`status/leak-crisis.md`, `agent-boss.md`, delegation prompts, and the active
`untracked/T*.md` files. State was self-contained; no data loss detected.

**Actions on resume:**
- Updated `docs/status/CURRENT.md` to say **WAITING on T12** and to fold in
  the just-completed T15-review result.
- Updated `docs/status/HANDOVER.md` with the same resumed state.
- Updated `untracked/delegation-prompts-2026-07-26.md` to remove
  not-yet-dispatchable prompts, per `docs/agent-boss.md` prompt-timing rule.
- Added backlog / blocked task list (T13, T14.2/14.3, T15-impl, T17-impl,
  T16-content-review, cleanup).
- Updated this file with T15-review and resumed-Boss notes.

**Takeaway:** the handover tree works. A fresh Boss instance resumed from
`HANDOVER.md` without needing to ask the user for state. The main friction
was the delegation-prompts file still carrying future prompts; fixed.

## Minimax-m3 — T12 C2-pilot-2×2 (2026-07-26)

**Task:** implement and run the C2-probe on 2×2 as a falsification test.

**Strengths shown:**
- Built a clean standalone probe (`untracked/c2pilot_2x2.zig`) with no engine
  edits, avoiding `src/retro.zig` contention.
- Honest verdict: **PARTIAL (tautological)** — recognized that 2×2 cannot
  host a non-trivial ban set and said so explicitly rather than dressing it up
  as a strong result.
- Provided concrete recommendations for T13 (generalize harness, find non-root
  cycles, construct ban sets from cycles).
- Fast: 1.2 s wall time.

**Weaknesses / caveats:**
- None significant; the task was calibrated exactly as designed.

**Quality:** strong execution + honest epistemic framing. Good model for
bounded probe tasks.

## Boss workflow refinement — bundled serial subtasks (2026-07-26)

User preference: instead of one-line prompts per subtask, give one agent a
bundle of ordered subtasks in a single file, with checkboxes and halt/continue
rules. The agent works serially without intermittent prompting. The Boss still
gives only the initial one-line dispatch prompt.

Applied: created `untracked/B01-kimi.md` containing T13 → T14.3 →
T16-content-review. Updated `docs/agent-boss.md` with the bundled-subtask
convention. Updated `CURRENT.md`, `HANDOVER.md`, delegation prompts, and this
file.

## Boss workflow refinement — parallel bundles (2026-07-26)

User asked whether a sequence of subtasks can run in parallel with another
agent/session while Kimi is already on T13. Decision: yes, for independent
read-only/standalone work.

Created two bundles:
- `untracked/B01-kimi.md` — Kimi: T13 (already in progress) → T16-content-review.
- `untracked/B02-glm.md` — GLM: T14.3 (read-only artifact audit) →
  C2-lattice-scope (research scoping).

Both are read-only/standalone and can run in parallel. T14.3 was moved out of
Kimi's original B01 to avoid bottlenecking. Updated `CURRENT.md`, `HANDOVER.md`,
`delegation-prompts`, and `agent-boss.md`.

## Boss correction — agent lifecycle (2026-07-26)

User clarified that models/sessions are disposable and unlimited in number;
the Boss should treat a prompt as spawning a new session, not scheduling a
fixed worker. The Boss must write the task file **before** giving a prompt,
because the user dispatches immediately.

Applied: created `untracked/B03-glm.md` and `untracked/B04-minimax.md` before
suggesting prompts. Updated `docs/agent-boss.md` with the correction.

## Kimi-k2.7 — T13 C2-pilot-3×2 (2026-07-26)

**Task:** falsification test of C2 (single-value region is history-independent)
on 3×2.

**Result:** **FAIL — C2 falsified at 3×2.** 12 verified mismatches between
stored L==H values and history-aware exact values under reachable PSK lines.
All mismatches on positions whose fresh-start value is ±6.

**Strengths shown:**
- Built a clean standalone probe (`untracked/c2pilot_3x2.zig`) with no engine
  edits.
- Used `memo=false, brackets=false` to get a genuine history-aware exact
  value, then sanity-checked with fresh-start values to confirm the solver
  setup.
- Recorded exact histories and expected/got values for every contradiction,
  making the result reproducible.
- Gave honest consequences: C2 is false as scoped; the core-only deliverable
  collapses unless the semantics are redefined.
- Wall time negligible (~200 ms for 153k lines, 508 histories).

**Weaknesses / caveats:**
- None significant; the result is decisive.

**Quality:** excellent — this is exactly the kind of ruthless falsification
that prevents the project from building on an unproven claim. Kimi's value as
an auditor/falsifier is now strongly established.

## Boss pivot — C2 falsified (2026-07-26)

T13 result changed the project's strategic state. The Boss immediately:
1. Stopped treating T14.2/T15-impl/T17-impl as dispatchable.
2. Created three new parallel bundles (B05 reframe, B06 C3 audit, B07 code
   audit) to gather the information needed for an honest next step.
3. Updated `CURRENT.md`, `HANDOVER.md`, delegation prompts, and this file with
   the critical state change.
4. Left B02/B03/B04 running; they remain useful (artifact audit, doc-audit,
   scratch triage).

The Boss did **not** silently edit `PROGRESS.md` or `leak-crisis.md`; the
reframe will be applied after B05/B06 report, so the edits are evidence-based.

## GLM-5.2 — B03 doc-audit (2026-07-26)

**Task:** read-only audit of six core epistemic docs for contradictions,
stale claims, and name drift.

**Result:** DONE — **ACCEPT with edits.** Grade distribution: Blocker 2,
Critical 4, Should 5, Nice 3. The two post-T13 files (PROGRESS.md,
leak-crisis.md) were internally honest; the rot was in the four 02:17 files
(EPISTEMIC, CONCEPTS, names, GLOSSARY).

**Strengths shown:**
- Recognized the root cause: four files predated T13 and had not been updated.
- Produced a prioritized edit plan with exact file/section references and
  minimal fixes.
- Correctly identified name drift and the wrong experiment mapping in
  `names.md` (C2 mapped to E2, but E2 tests C3).
- Noted what was *not* a finding (no broken links, no numerical contradictions,
  PROGRESS/leak-crisis honest).

**Weaknesses / caveats:**
- None significant.

**Quality:** strong — the audit is essentially a ready-to-execute editorial
plan. The Boss applied Blocker + Critical edits immediately.

## Boss editorial action — B03 edits applied (2026-07-26)

Applied edits #1–#5 from B03:
- `docs/GLOSSARY.md`: certified core, L/H, rule-independent, bracket wording.
- `docs/boards/4x4/EPISTEMIC.md`: T13 update preamble, Wave-0 pilots,
  Wave-2 rename.
- `docs/boards/CONCEPTS.md`: C2 falsification note, dependency structure.
- `docs/names.md`: table rows 2a/2b/3 and NOTES.
- `docs/PROGRESS.md`: header + link fix.

Remaining edits #6–#10 (name-drift sweep, hyphenation, anchor ruleset, polish)
queued. No doc edits performed by subagents; Boss integration only.

## New bundles created (2026-07-26)

In response to user request for more delegation:
- B08 — GLM: fresh-agent onboarding test.
- B09 — Kimi: synthetic-bug injection / auditor sensitivity.
- B10 — Minimax: random empirical probe on 3×2 divergence patterns.

## GLM-5.2 — B05 reframe sprint (2026-07-26)

**Task:** after T13 falsified C2, scope the honest next deliverable and produce
an 8-edit doc plan.

**Result:** DONE. Strong output:
- Clear consequence note: C1 survives; C2 false at 3×2; C3 already false at 3×3;
  C4 false for both regions.
- New honest deliverable in one sentence: fresh-start exact value oracle +
  CLAIMED [L,H] bracket, explicit non-promise re real-game PSK.
- 6 reframe recommendations with 3 user-decision flags (UD-1/2/3).
- 8-edit plan with exact file/section/ replacement language, priority order,
  and coordination note with B03.
- No engine or artifact writes.

**Strengths shown:**
- Excellent strategic reasoning: immediately identified that C3 was already
  dead, so C2 false removes the last surviving real-game claim, not the
  second-to-last.
- Produced actionable user-decision flags with clear recommendations and
  rationales.
- Gave a precise edit plan rather than vague suggestions; the Boss could apply
  it directly.
- Honest about scope: did not attempt to prove C2 could be restored.

**Weaknesses / caveats:**
- None significant.

**Quality:** very strong — this is essentially a decision brief and an
editorial work order in one. GLM is proving excellent at integration/reframe
tasks.

## Boss integration — B11 doc edits applied (2026-07-26)

Applied the B05 8-edit plan to:
- `AGENTS.md` (repo root)
- `docs/status/leak-crisis.md`
- `docs/PROGRESS.md`
- `docs/boards/4x4/EPISTEMIC.md`
- `docs/boards/CONCEPTS.md`
- `docs/names.md`
- `docs/GLOSSARY.md`
- `docs/status/HANDOVER.md`
- `docs/status/CURRENT.md`

All edits were surgical status-string/name replacements; no numerical claims
or structural arguments changed. Verified with targeted greps. Remaining
edits (name-drift sweep, hyphenation, anchor ruleset, polish) are queued as
lower-priority cleanup.

## Kimi-k2.7 — B06 E2-C3 audit (2026-07-26)

**Task:** re-run E2 range-aware player on 2×2/3×2/3×3 to test C3 after C2 false.

**Result:** DONE. C3 supported on explored 2×2/3×2 samples (0 leaks each); C3
**falsified at 3×3** (50/8000 leaks, max 12 pts). General C3 claim false-as-
scoped.

**Strengths shown:**
- Added minimal `RETRO_E2_SEEDS` env-var knob cleanly, no core logic change.
- Correctly identified C2 and C3 as orthogonal: C2 false at 3×2 does not
  imply C3 false at 3×2, and indeed C3 held on the sampled 3×2 lines.
- Gave the honest status of [L,H]: history-free fixpoint bracket, claimed not
  proven as a real-game bound.

**Weaknesses / caveats:**
- None significant.

**Quality:** strong — decisive, orthogonal, and properly scoped.

## GLM-5.2 — B08 fresh-agent onboarding test (2026-07-26)

**Task:** simulate a fresh agent reading only HANDOVER/PROGRESS/names/CURRENT;
report understandability.

**Result:** DONE. Verdict **PARTIAL PASS**.

**Strengths shown:**
- Identified a real doc bug: `CURRENT.md` had B06/B07 listed as both
  "dispatchable" and "completed/starting" in different sections.
- Caught read-order disagreement between HANDOVER and the B08 probe list.
- Noted propagation-status disagreement between `names.md` and `PROGRESS.md`.
- Gave actionable fixes.

**Weaknesses / caveats:**
- Some findings are minor (hyphenation, B08 listing itself as dispatchable),
  but still useful friction signals.

**Quality:** good — this is exactly the kind of meta-audit that prevents a
fresh agent from getting lost. The Boss fixed the CURRENT.md inconsistency
immediately.

## Boss workflow refinement — SUBAGENTS.md (2026-07-26)

User requested a single concise registry of delegated bundles: prompts,
status, parallel/serial sets. Created `untracked/SUBAGENTS.md` as the canonical
registry. Updated `docs/status/CURRENT.md` to reference it. The human keeps
`HUMAN.md` separately; SUBAGENTS.md is the Boss-managed counterpart.

## Boss correction — per-goban epistemic independence (2026-07-26)

User emphasized that each goban size is its own epistemic universe: 2×2/3×2
results are not evidence for 3×3/4×4. Added explicit sections to:
- `AGENTS.md` (root)
- `docs/PROGRESS.md`
- `docs/boards/CONCEPTS.md`

This is now a documented foreclosure / convention.

## User conceptual QA — fresh-start vs real game (2026-07-26)

User probed the implications of T13:
- If L==H is history-dependent, is it ko-sensitive? (Loose sense: yes.)
- Terminology: score vs range of scores.
- Basic-ko handling vs PSK.
- Multiple tables per ruleset? (No.)
- Value of fresh-start table if real games have history.
- Narrowing ranges with history/future search.
- Tractability of 3×3/4×4.

Boss response: wrote `docs/research/fresh-start-vs-real-game.md` and created
B13 (terminology + real-game scope) and B14 (engine-vs-engine + KataGo) as
optional bundles. Updated `DELEGATION.md` to mark B12 waiting for human and
to add B13/B14 as optional. User prefers to wait for B04/B07/B10 to finish,
then commit, then run B12 in deepseek-v4-pro/Pi.

## deepseek-v4-pro (Pi harness) — B12, B13, B14 (2026-07-26)

**Context:** New Boss running in Pi harness with 1.0M context window.
Dispatched three bundles in separate sessions by the human:
- **B12** — post-B02 integration verdict + cleanup (read B02 results;
  verdict already written by GLM-5.2; removed 2 temp files).
- **B13** — terminology sweep + doc fixes (Option A: 5 files, replaced
  "certified core" → "fresh-start single-value region", applied 5 corrections
  to `fresh-start-vs-real-game.md`).
- **B14** — engine-vs-engine + KataGo probe design (3 experiments scoped,
  prioritized, with implementation plans).

### Strengths shown
- **High-context ingestion:** ingested HANDOVER.md, CURRENT.md, B02, B12,
  B13, B14, PROGRESS.md, leak-crisis.md, and all referenced docs in a single
  read phase with no confusion. The 1.0M window makes this natural.
- **Efficient batch executor:** applied multi-edit operations across files
  cleanly. B13's terminology sweep hit 5 files with precise replacements;
  no unintended changes. B14 produced a structured design doc with concrete
  wall-time estimates and safety constraints.
- **Follows conventions:** read AGENTS.md read-order, respected per-goban
  epistemic independence, cited sources, produced properly structured output
  files. No convention violations.
- **Honest epistemic framing:** the B14 design explicitly notes that
  KataGo experiment is a curiosity/smoke test, not a verification gate,
  and that experiments are deferred until user decisions. No claim inflation.

### Weaknesses / caveats
- **DELEGATION.md format:** first pass put comments after prompts instead of
  on the line above, and created a redundant section. Corrected after human
  feedback. The format rule is: comments above, clean one-liner below.
- **No proactive pruning:** did not question whether the B13 subtask 3
  (real-game-play approach decision) needed the human's input before being
  left open. The recommendation was documented but the open loop wasn't
  flagged prominently.

### Cross-model takeaway (updated)

deepseek-v4-pro in Pi is a strong **Boss/integrator**: ingests large context,
executes multi-file edits precisely, produces structured designs, and
maintains epistemic discipline. Weaker at initiative (proactive pruning,
questioning stale structure). Best used for: doc integration, terminology
sweeps, design scoping, high-context decision briefs. The existing pattern
(Minimax implements, Kimi audits, GLM integrates) remains for engine work;
deepseek-v4-pro is the natural Boss/resumer for the Pi harness.

## Multi-model audit: B33 terminology sweep (2026-07-27)

Five models audited the same task (audit only, do NOT edit).

| Model | Found new | Followed rules | Notes |
|---|---|---|---|
| GLM | 4 (baseline) | Yes | Solid first pass, clear table |
| Kimi | 0 new | No (edited) | Correct fixes but ignored constraints |
| deepseek-v4-pro | 0 | Yes | Accurate, nothing new |
| deepseek-v4-flash | 5 (retro.zig comments) | Mixed | Best value: found and fixed stragglers |
| MiniMax | 13 (src comments, ADRs) | Yes | Most thorough, best audit discipline |

Takeaway: MiniMax for thoroughness, deepseek-v4-flash for speed+fixes, GLM for baseline. Give Kimi explicit edit permission.

## Multi-model comparison — B35 (proof design) to B38 (epistemic discipline)

| Skill | Winner | Runner-up | Notes |
|---|---|---|---|
| B35 — Proof design (I1) | deepseek-v4-flash | GLM | deepseek-v4-flash attempted 5-lemma proof; GLM identified the critical gap (Lemma B) |
| B36 — Judgment/triage | GLM, deepseek-v4-flash | — | All 5 converged on #1 = complete 4x4 finisher |
| B37 — Delegation design | deepseek-v4-flash, MiniMax | GLM | deepseek-v4-pro + Kimi wrote to console not file (need explicit write instruction in bundle) |
| B38 — Epistemic discipline | deepseek-v4-pro | GLM, Kimi | deepseek-v4-pro alone strictly applied per-goban independence (#5 = UNKNOWN). MiniMax erred on #7 |

### Composite Boss evaluation (B34-B38)

| Model | B34 | B35 | B36 | B37 | B38 | Composite |
|---|---|---|---|---|---|---|
| GLM | 2nd | 2nd | 1st | 3rd | 2nd | **Most consistent** |
| MiniMax | 1st | 3rd | 4th | 2nd | 4th | Best auditor, weaker on reasoning |
| deepseek-v4-flash | 4th | 1st | 1st | 1st | 5th | Best speed, weakest on rigor |
| deepseek-v4-pro | 3rd | 4th | 3rd | 4th | 1st | Best epistemic discipline |
| Kimi | 5th | 5th | 2nd | 5th | 3rd | Inconsistent — strong B36, weak B35/B37 |

**Recommendation:** GLM for Boss (consistent across all skills). MiniMax for audits
(thoroughness). deepseek-v4-pro for epistemic verification. deepseek-v4-flash for speed tasks.
Kimi for follow-through on existing findings.

---

# Sprint 2026-07-27/28 — the ko-reframe milestone

How to read the rows below. This is a **quality ledger, not a highlight reel**.
Each entry records what the task cost, what it actually established (with the
claim IDs it touched), and whether the result survived audit. **The failures are
the most valuable rows** — two of them (EXP-2 Part A and Part B) cost more than
everything else in the sprint combined, and the fault for most of Part B is the
delegator's, not the executor's.

Conventions: **cost signals are quoted only where a source document records
them**; where none does, the row says "cost not recorded" rather than
estimating. **No model is named where the sources do not name one** —
"unattributed subagent" is used, and it is an honest entry, not a placeholder.
Where two sources disagree on a number, both are recorded and the disagreement
is flagged; nothing here adjudicates a technical claim or a status.

## Opus 5 — the chainability finding (2026-07-27)

**Task:** review the epistemic tree and find out why the Go Text Protocol (GTP)
player loses as soon as a ko appears.
**Output:** `bin/weizigo-chainability` (`src/chainability.zig`), new build
target, `docs/research/ko-sensitive-chainability.md` Measurements 1–3, the new
GLOSSARY term **chainable**.

**What it established.** `Session.choose` picks a move by extremum over
children's *stored* values, which is only defined where the history-free Bellman
identity holds. Measured, artifact-only:

- **Zero** identity violations *outside* the KO_SENSITIVE flag at 2×2, 3×2, 3×3,
  4×3 (exhaustive) and 4×4 (`--sample 37`), under both the full and the
  ADR-0006 eye-pruned move sets. The single-score (L==H) region **is** chainable
  — the region's first positive property, and FP1 acceptance check 3, which
  `boards/4x4/EPISTEMIC.md` had carried as untested.
- Violations are **exactly co-extensive** with the flag: 16/16, 72/72, 688/688,
  6,092/6,092, and 11,402/11,402 on the 4×4 sample.
- Worst misprice is **2n exactly** for every n ≥ 6 (12, 18, 24, 32) — the entire
  goban swing, not a rounding effect. **CLAIMED** (four sizes, no proof).
- Measurement 2: positional-superko (PSK) bans changed the best available value
  at **0 of 19 plies** in each of the two saved 4×4 regression games. The ko
  *rule* costs the engine nothing. **PROVEN** for those two games.
- Measurement 3: the empty 4×4 goban is itself KO_SENSITIVE (bracket [−6, +16]),
  16 of 19 plies of both games are flagged, and the collapse at ply 16 is stored
  −16 against +16 one ply down. Claims touched: `GLOBAL.CHAIN-KO`,
  `GLOBAL.CHAIN-KIND`, `4x4.GTP-DEFECT`, `4x4.FP1-C3`/`QA-021`, `QA-002`.

**Cost:** tool written and five artifacts swept in one session (23:51 CEST
report). Per-run cost not recorded for the 2026-07-27 sampled runs; the
exhaustive 4×4 re-run the next day is 87 s (see below).

**Outcome quality — held, with two of its own statements later corrected.**
The out-of-flag zero has survived every subsequent check and was upgraded from
sample to exhaustive on 2026-07-28. But (a) the 4×4 row was a 1:37 stride
*sample* quoted as 21.27%, superseded the next day, and (b) a paragraph headed
"**Not a bug.**" asserting the violations were "not evidence of a generation
error" was **too strong and is retracted in the same document** by Measurement 4.
The retraction is in the file rather than quietly edited out, which is the
behaviour this ledger wants.

## Opus 5 — Measurement 4: writes-off vs writes-on, and its two walk-backs (2026-07-27, extended 2026-07-28)

**Task:** not dispatched — Opus found `untracked/oracle-4x4-writesoff-checkpoint.wzo`
and swept it with the same tool and flags to separate the definitional part of
the ko-sensitive misprice rate from the part that is not.

**What it established.** At stride 37: writes-**ON** 4.08% misprice within the
flag, writes-**OFF** 1.67%, zero outside on both. Reproduced at coprime stride
997: 3.81% vs 1.47% (397 vs 152 raw violations). A definitional **floor** exists
and is not zero — a sweep reporting 0% inside the flag would convict the tool,
not the artifact — and the committed artifact carries an excess above it.
Claims: `4x4.M6`, `4x4.M6-FLOOR`, `4x4.M6-EXCESS`, `4x4.M6-SCREEN`, `QA-007`.

**Cost:** four strided sweeps of a 258 MB artifact; wall time not recorded
per run (the document calls the screen "seconds of CPU over a strided read").

**Outcome quality — direction survived, magnitude did not, and the author
walked it back twice himself.**

1. First framing, "the violations are purely definitional", was **withdrawn** by
   this very measurement.
2. The 2.44× ratio was sold in message 001 as evidence for Track A. On
   2026-07-28 direct byte inspection showed the writes-off artifact's root is
   UNDEF — **the run never finished** — so the comparison is not like-for-like
   and the unfinished slots are exactly the hard ones (survivorship confound).
   A worst-case bound (charge every missing slot to writes-off) gives 2.51% <
   4.08%, so the **direction is PROVEN robust** and the ratio is **≥1.63×**, but
   the true value lies somewhere in **[1.63×, 2.44×]** and the sweep cannot
   narrow it.
3. **QA-007 remains CLAIMED**, not proven: attribution of the excess to the
   ADR-0013 `ko_ref >= d` graph-history-interaction (GHI) bug is consistent with
   the bug but not established. Upgrade path unchanged (`RETRO_CONSIST`), with a
   *completed* writes-off regen newly named as a prerequisite.

**Number disagreement, flagged:** the ratio is **2.45×** in
`untracked/msg/milestone-01-ko-reframe/001-opus-to-glm.md` §005 and **2.44×** in
`docs/research/ko-sensitive-chainability.md` Measurement 4. Both are recorded;
neither is adjudicated here.

## Opus 5 — the errata ledger, and the one entry that is his own error (2026-07-27)

**Output:** `docs/research/corrections-2026-07-27.md` — five entries: A-1 (wrong
causal attribution to "the game's PSK history" in commit `753584f` and
`regressions/README.md:21`), A-2 (category error — the blunder is **not** "C2 in
action"; every blundering node is L<H, outside C2's scope, so the applicable
claim is C4 plus unchainability), A-3 ("fresh-start perfect" overstates the
player — the engine's own log shows stored −3, played −16), B-1 (ADR-0013's
"the GTP player shares this machinery" is **FALSE** as of the 2026-07-27 code —
`Session.choose` does table lookups only, and WZO1 carries no bracket columns
for any player to cut on), and **C-1**.

### C-1 — Opus's own error, caught by calibration and recorded as such

**This is the entry the ledger exists for.** Mid-investigation, Opus read the
chainability violations in the committed 4×4 artifact as the ADR-0013
`ko_ref >= d` GHI bug resurfacing in the committed generation. **Calibration
killed that reading:** the same sweep on `artifacts/oracle-2x2.wzo` and
`artifacts/oracle-3x2.wzo` — the PROVEN, Track-A-regenerated artifacts the
suspected bug never touched — produced violations of the same character
(19.51% and 19.05% within the flag, zero outside). A bug present in the clean
artifacts is not a bug; the violations are definitional in kind.

**Cost:** two extra sweeps of tiny artifacts. Effectively free, and it is the
reason a wrong finding was never committed.

**Lesson recorded, and it became a standing project rule
(`GLOBAL.CALIB-LESSON`):** *an auditor with no **passing** calibration case
cannot distinguish "bug" from "definition" — every input looks guilty.* The
calibration also gave the auditor its scope (it judges only outside the flag).
This rule is cited by `docs/evidence/README.md` step 6 and is check P3 of the
roadmap; the claim-lint tool below honours it and was caught by it.

**Authorship disagreement, flagged:** `001-opus-to-glm.md` §6 lists
`corrections-2026-07-27.md` among the files Opus wrote that session, while
`docs/status/CURRENT.md`'s dirty-tree table labels it "(new, **another
agent**)". C-1 itself is unambiguous — Opus states the mistake was his own — but
the file's overall authorship is not settled by the sources.

## Opus 5 — exhaustive 4×4 sweep, denominator reconciliation, and his own tool bug (2026-07-28)

**Task:** close the FP1 check-3 residue (H4) by dropping `--sample`.

**Cost: 87 s wall**, one pass over the 258 MB artifact.

**What it established.** 48,599,962 (position, side) slots checked; **422,990**
violations under both move sets, **all** KO_SENSITIVE-flagged, **0** outside;
max gap 32; within-flag misprice **4.08%**. The 1:37 sample had predicted 4.08%
and 21.27% against an exhaustive 4.08% and 21.33% — **the sample was sound**,
and the superseded row is kept in the document as the evidence of that rather
than deleted. `QA-021`/`4x4.FP1-C3` upgraded from sampled to exhaustive.
Residue that remains open: the `lo`/`hi` **bracket-table** form of check 3 is
still untested, because WZO1 (ADR-0011) stores no bracket columns.

**A bug of his own, found and fixed in the same pass.** The counter printed as
`legal, non-settled` was incremented *before* the settled `continue`, so it was
the plain legal count (24,318,165), not the non-settled count (24,299,981).
**That mislabelling seeded a three-way percentage confusion across four
documents.** The tool now prints both lines and directly counts flags on settled
slots: **0** at 4×4 and 4×3, which converts the denominator reconciliation from
a cross-instrument inference into a measurement.

**Number disagreement — recorded and reconciled at 4×4 only.** Three 4×4
ko-sensitive percentages are in circulation and **all three are arithmetically
correct**; they differ only in denominator:

| figure | numerator / denominator | what it measures |
|---|---|---|
| 21.32% | 10,367,922 / 48,636,330 | converge census, over **all legal** slots |
| 21.33% | 10,367,922 / 48,599,962 | chainability sweep, over **non-settled** slots |
| 21.27% | 279,323 / 1,313,248 | the **superseded** 1:37 sample estimate |

48,636,330 − 48,599,962 = 36,368 = 18,184 settled positions × 2 sides. **Only
the 4×4 row of `CLAIMS.md` discrepancy D7 is reconciled; the 2×2 / 3×2 / 3×3 /
4×3 rows are NOT**, and per-goban independence forbids assuming the same cause.
Standing lesson from this incident, now in STATE.md: **state every denominator.**

## Opus 5 — QA-008 and QA-016 by direct byte inspection (2026-07-28)

**Task:** stop waiting for the Boss to answer "is the writes-off checkpoint
complete?" and read the bytes.

**Cost:** a three-line `python3` read of three byte offsets. No engine, no tool.
The cheapest decisive result of the sprint.

**What it established (PROVEN).** `vb[empty]` is at offset 32 in the WZO1
payload. `data/oracle-4x4.checkpoint.wzo` holds **+2** (the published anchor);
`data/oracle-4x4-parallel.checkpoint.wzo` and
`untracked/oracle-4x4-writesoff-checkpoint.wzo` both hold **−128 (UNDEF)**.
So: **QA-008 answered — the Track A writes-off run did not finish**, closing a
question that had been open in three documents as "completion unconfirmed"; and
**QA-016, new — the parallel checkpoint cannot state the 4×4 answer at all.**
The only 4×4 artifact carrying +2 at the root is the writes-**ON**, i.e.
ADR-0013-unsound, one.

**Methodological finding worth more than the measurement:** the docs describe
the parallel checkpoint as "99.8% complete / 83K unfilled", which is
arithmetically true and operationally misleading when the missing slot is *the*
slot. **Percentage-filled is not a fitness-for-purpose metric.**

## Unattributed subagent — the reachable certified-fraction baseline (2026-07-28)

**Task:** dispatched by Opus (one of "two agents" named in
`001-opus-to-glm.md` §004) — measure the KO_SENSITIVE fraction over nodes the
engine actually *reaches in play*, against the chainability sweep's
slot-uniform denominator. **No model is named in any source; recorded as
unattributed.**
**Output:** `bin/weizigo-reachcensus` (`src/reachcensus.zig`),
`docs/research/reachable-kosensitivity-2026-07-28.md`.

**Cost: ~0.7 s wall per 4×4 run** for all four policies at 2,000 games — cost
dominated by loading the 258 MB artifact, i.e. the measurement itself is nearly
free. Seed 20260728, ply cap 256.

**What it established (PROVEN for these artifacts/policies).** **In 4×4
engine-vs-engine play the certified fraction is exactly ZERO** — all 14 plies of
the single self-play line are flagged (28,000/28,000, `distinct game lines: 1`),
and randomising tie-breaks (144 distinct lines, 27,865/27,865) finds no
certifiable node either. Same at 4×3 (22,000/22,000). **Not** at 3×3 (42.86%,
flag clearing from ply 4). The slot-uniform 21.33% understates player exposure
under every policy measured; the honest answer is a **policy-dependent range
from 0% to ~78%**, and the document explicitly refuses to let the `mixed` 78.3%
be quoted as "the" certified fraction. Secondary **CLAIMED** finding
(`QA-017`): the engine steers *into* the unchainable region — nodes it creates
for the opponent are flagged roughly twice as often as nodes where it is to move
(4×4 21.72% vs 47.68%; 4×3 31.49 vs 49.13; 3×3 38.76 vs 59.00).

**Outcome quality — strong, and it is the second-best-calibrated row in the
sprint after EXP-3.** Reasons: the `oracle` policy was validated **move-for-move
against the real GTP player** built from the working tree at all three gobans;
the pre-registered sanity check is reported as **INVERTING at 3×3** rather than
quietly scoped away; ply-cap, settled-stop and three-seed robustness are all
measured and the settled-stop bias is reported as ≈2 pp *in the direction the
mechanism predicts*; and the UNDEF path was exercised on the parallel checkpoint
(100% of games touch UNDEF, statistics undefined) rather than left as dead code.
It also states plainly what it does **not** check — whether a flagged value is
also *wrong*.

**Number disagreement, flagged:** the research note gives `mixed` engine-to-move
**21.72%** and opponent-to-move **47.68%** (2,000 games/policy); Opus's relay in
`001-opus-to-glm.md` §006 gives **21.24%** and **47.33%** from what it calls "my
500-game reproduction", while the table in that same message says 21.72%. The
committed document's figures cite their seed and game count; the message's do
not fully. Both recorded.

## Unattributed subagent — EXP-1, the PSK binding rate (2026-07-28)

**Task:** EXP-1 of `roadmap-2026-07-28.md` §3 — does positional superko ever
actually forbid a move basic ko allows, and would a human notice? Claim under
test: **QA-024**. **No model is named in any source** (there is no `EXP-1.md`
dispatch brief); Opus relays the result in `001-opus-to-glm.md` §010 and refers
to the executor only as "the agent".
**Output:** `--psk-binding` and `--replay` on `bin/weizigo-reachcensus`,
`docs/research/psk-binding-rate-2026-07-28.md`.

**Cost: ~1 s wall per 4×4 run** (2,000 games × 4 policies), seed 20260728.

**What it established.** **Zero** binding events across **130,171 plies and
1,015,076 candidate moves** of engine-driven play on 4×4/4×3/3×3, under both
settled-stop settings. In both recorded human-vs-engine games PSK bound **zero**
times — the single ban per game is a `d = 2` recapture basic ko forbids anyway.
Under uniformly random play it *does* bind: 1.326 (4×4) to 8.513 (3×3) per 1,000
plies, of which 0.329 to 5.445 are silent long-range repeats — and removing the
settled-stop truncation multiplies the random silent rate by 7–11× while leaving
the engine policies at exactly zero.

**Outcome quality — high, and the row is here partly for what the agent
refused to do.** It **declined to report QA-024 as proven unconditionally**,
because random self-play falsifies "negligible" as an unqualified statement, and
recommended re-scoping the claim to the policy class it holds over. Two
verification checks ran *before any number was believed*: a hand-verified
14-ply 4×4 line (stone-count and suicide argument for why the zero is correct
rather than a silent instrument failure), and a `--replay` mode that reproduces
Measurement 2's independently-derived ground truth **exactly** (1 ban, ply 14,
d=2, both games, including the vertical-mirror relation between them). The
document also states the limit that matters: **this measures legality along
played lines, not value** — EXP-8 is still required — and it notes that the
goban-size ordering runs *against* intuition (smaller gobans bind more), so it
must not be read as reassurance about 5×5. Denominator, "isolated"-proxy status
and the lower-bound direction of the distance convention are all declared.

## Unattributed subagent — the claim register, `docs/epistemic/CLAIMS.md` (2026-07-28)

**Task:** the second of Opus's "two agents" — build the full claim register with
`derives-from` vs `evidenced-by` edges, an orphaned-claims list and an
inheritance audit, against a named method fault: *the project has no dependency
edges between claims*, which is why C2's fall required a manual re-audit.
**Owner recorded in the file only as "the claims-register agent"; no model
named.**

**Cost: not recorded.** Size signal: 217 claims / 231 edges at first delivery,
grown to 245 rows / 267 edges after the `QA-nnn` import.

**What it established.** Three results, all found by the register and two of
them **outside its brief**:

- **O1 / QA-018 — the deepest orphan in the project.** `GLOBAL.F2` (the
  bracket-guided finisher behind **every shipped ko-sensitive value**) derives
  from ADR-0010's claim that brackets "hold under ANY arrival history", which
  *is* claim `GLOBAL.C3`, **FALSE-AS-SCOPED at 3×3**. The project had written
  both halves of that sentence in two different documents and not joined them
  for weeks. Opus then verified an escalation from source that the register did
  not have: `bracketed` and `memo_writes` are **independent** and `saveArtifact`
  hardcodes `bracketed = true` (`src/retro.zig:2407`) — so **ADR-0013 Track A
  does not escape O1**, and the 1.67% "definitional floor" is also
  bracket-derived. Direct consequence: **do not spend a machine-week on a
  writes-off regen** (it would settle nothing).
- **QA-022 — the evidence for T13, T02/B1, T07 and B05 is gone** (see the
  rescue row below).
- **Sixteen further discrepancies of the D7 kind**, including D8 (the empty 3×2
  Black score has *three* values, +1 / −2 / 0, in the same generation) and D9
  (C1 called "exhaustive ground truth at 2×2/3×2" in four places while
  `retrograde-3x3.md:50-52` records 8 of 114 and 68 of 600 roots completing).

**Outcome quality — the highest-leverage row in the sprint per unit of cost.**
It changed the project's priority order. It also **did not** adjudicate anything:
statuses were left as found, for the user and Opus to call.

**Disagreement it surfaced and did not resolve — QA-009:** `PROGRESS.md:125`
says E2 leaked "50/8000, max 12 pts"; `leak-crisis.md:36` says "25/4000". Same
rate (0.625%), same max. Opus ruled on 2026-07-28 (**D-1**) that this is *not* a
discrepancy — 25/4000 is the original E2 and 50/8000 is B06's re-run — and that
**both rows must be kept**, because collapsing them destroys the evidence of
independent replication. GLM concurred and recorded that he had been wrong to
want one canonical number. **Not yet promoted to `CLAIMS.md`.**

## Unattributed subagent — `weizigo-claimlint`, and its self-eating calibration (2026-07-28)

**Task:** make `CLAIMS.md` check itself. **Owner recorded in the file only as
"the claimlint agent"; no model named.**
**Output:** `src/claimlint.zig` / `bin/weizigo-claimlint`,
`docs/epistemic/claimlint-2026-07-28.md`.

**Cost: ~1 s per run.** 245 rows, 267 edges (119 `d:`, 134 `e:`, 14 `n:`), a
434-file repo index, 6 checks, 7 calibration cases, 5 mutation tests. Exit 1 on
the live register.

**What it established.** Every check maps to a **dated incident this project
actually suffered**, and anything that merely enforces formatting was
deliberately left out. Headline: **the register does not pass its own standard**
— 10 live claims derive from a falsified one (8 of them one family, all O1),
and **79 of 79 PROVEN rows fail the roadmap's own P1 rule** that a PROVEN
claim's evidence be committed under `docs/evidence/`. Tier A is empty. 75 of the
79 have never had "what would a wrong answer have scored on this test?"
computed. Two structural discoveries: the register needed a third edge kind
(`n:` derives-from-**negation**, for the many positions adopted *because* a claim
fell — 14 mis-typed edges were producing systematic false orphans), and a
**shadowed-dependency** class (C5) where a `d:` edge onto a MEASUREMENT row can
never propagate anything, which is how `3x3.C1` — the 3×3 table's own
correctness claim, on the exact goban where the bracket was falsified — stayed
invisible since the register was written.

### The failure worth keeping: the calibration ate its own known-bad

C5's first known-bad case was `3x3.C1 d:3x3.F2` — **a real, in-register broken
edge**. The tool caught it, the edge was then fixed, and on the next run the
same case was **MISSED** — the calibration had stopped testing anything, because
the data it calibrated against had improved. **The tool reported
`calibration: FAIL` and exited 2**, which is the only reason this was noticed
rather than becoming a silently vacuous check.

**Lesson, now a standing project rule:** *a calibration case that lives in the
data disappears the moment the data improves — so **fixable known-bads must be
synthetic**.* C1b's alarm half has the same property (today every `n:` edge
points at a genuinely false parent, the healthy state), and both now run against
a four-row synthetic register embedded in the binary, alongside a real-data
known-good so that a purely synthetic calibration cannot pass while the check
never touches the real register.

**Outcome quality — strong, and it corrected itself publicly.** It was revised
**twice on 2026-07-28 after review**, and both revisions changed the headline
(orphans 23 → 9 → 10). Its §4 first claimed "two independent checks both point
at the deliverable"; that was **withdrawn** as a false positive of the missing
edge kind, and the section now says the signal is **one check, not two, and
should be read as weaker**. Five mutation tests on scratch copies prove the
checks are data-driven rather than hardcoded (M1 flips `GLOBAL.C3` to PROVEN and
fires both directions from one mutation; M4 rehabilitates `GLOBAL.C2` and raises
4 alarms; M5 reverts the C5 fix and the orphan reappears). It changed **no
status** to make its own run green, and it names its own accepted limitation:
**nothing in it notices a row that has gone stale** — `QA-023` is the live
example, and the tool will exit 0 on it and say nothing.

**Internal count disagreements, flagged (the document is inconsistent with
itself and with STATE.md):** the dangling-evidence figure appears as **11**
("11 cited evidence paths do not exist" in the headline; "11 missing paths, 1
git-ignored evidence document, 1 bulk artifact" in §3) and as **12** (the
SUMMARY block, `STATE.md`, and GLM's message 004). Unreferenced rows appear as
**61** (SUMMARY), **65** (§C4 heading), **77** ("at the first run") and **51**
(after this document was itself committed, which the document notes moved its
own metric). All recorded; none adjudicated.

## Unattributed subagent — the evidence rescue, `docs/evidence/` (2026-07-28)

**Task:** triage-and-rescue sweep over git-ignored `untracked/`, after the
register found QA-022. **No model named in the source.**

**Cost: not recorded.** Volume: **33 top-level entries / 112 files** inventoried;
9 entries / 40 files copied (**384 KB** total, nothing over 1 MB); 4 `.wzo`
artifacts (516.6 MB) **not** copied but hashed and recorded.

**What it established — and this is a record of a loss, not an achievement.**
On **2026-07-27 a cleanup bundle (B44 S3, executor unattributed) deleted 57
"folded-done" scratch files** from `untracked/`. Among them was the primary
evidence for the project's most load-bearing claims. `git log --all
--diff-filter=A` returns **zero** commits for any of those paths and
`git stash list` is empty: **they were never in git and are unrecoverable.**
Seven load-bearing losses are itemised, of which the sharpest is **`3x2.T13`** —
the C2 falsification the entire current strategy rests on. Its *numbers* survive
in `docs/research/c2-falsification-3x2.md`, which is why it is still marked
PROVEN, but the probe source `untracked/c2pilot_3x2.zig` is gone, so **the
reproduction block inside that file cannot be executed**. Also lost outright:
B1's least-fixpoint results (the run that removed the re-converge check from
`4x4.FP1` acceptance), and T07's ~42 KB audit that rewrote the entire 4×4
epistemic tree — the tree survives as product, the eight findings behind it do
not.

**Aggravating detail worth recording.** `docs/research/arena-4x4-undef.md:10-18`
**already documented this exact failure mode happening once** and already drew
the right lesson ("write durable findings to git `docs/research/` directly"). It
was never applied retroactively, so it happened again to a bigger target.

**Outcome quality — good work with an honest scope.** It copied and recorded
only; nothing in `untracked/` was modified or deleted, and no lost experiment
was re-derived. Every rescued markdown file carries an inline provenance header
(original path, mtime, sha256, claims supported, citing document); non-markdown
is byte-identical with a sibling `PROVENANCE.md`. Two rescued items are flagged
**UNCITED** and explicitly declared not-evidence-for-any-claim — rescued
deliberately against the letter of the rule, with the note that deleting them
costs nothing if a reviewer disagrees. `.gitignore` gained a last-position
`!docs/evidence/` negation so no earlier rule can reach the tree. The standing
formulation this produced: **a claim whose evidence cannot be retrieved is not
proven; it is remembered.**

## Minimax-m3 — EXP-3, the `(board, side, ko_point)` census — THE BENCHMARK ROW (2026-07-28)

**Task:** EXP-3 (`docs/infra/dispatch/EXP-3.md`) — exact reachable-state census
under the standard basic-ko detector, to decide whether the simple-ko reframe is
addressable. Claim: `GLOBAL.H1-CENSUS`.
**Output:** `src/kostate_census.zig` (no engine file touched),
`docs/research/kostate-census-2026-07-28.md`,
`docs/evidence/GLOBAL.H1-CENSUS/` (PROVENANCE + 8 raw stdout files).

**Cost, recorded per goban (single thread, `-O ReleaseFast`, Apple Silicon):**
3×3 ≈ **0.05 s** / 16 sweeps; 4×3 ≈ **2.2 s** / 25 sweeps; 4×4 ≈ **4 min** / 29
sweeps. Every number exact — no sampling, no stride. The agent also reported
*where* the 4 min goes (the `is_legal` check inside the odometer, ~6 s per
sweep, not the fixpoint) and what would fix it, without acting on it.

**What it established.** 4×4: **51,419,046** reachable `(board, side, ko)`
triples, **29,497,329** distinct addresses, **4.031%** of naive dense. At 6 B per
address that is **176,983,974 B = 177 MB — 0.69× the current 258 MB PSK
artifact** and 30× smaller than naive dense. **GO on dense addressing at 4×4;
no sparse layer required**, including with `passes` folded (354 MB). This
retired `ruleset-options.md:76-81`'s prediction that the augmented state would
break dense colex addressing and force "a substantial engine change" — measured
false. Combined with EXP-1, **tractability is no longer the blocker; QA-023 is.**

**Outcome quality — this is the standard every other task in the sprint should
be measured against, and it was achieved unprompted.** Opus's own assessment
(message 005): "**EXP-3 was exemplary** — broken-variant calibration files,
OEIS A094777 cross-check, no-ko collapse check, all unprompted. That is the
calibration discipline I had to *demand* from others."

What specifically makes it the benchmark:

1. **It shipped deliberately-broken variants.** Two wired-in broken detectors
   (`every_capture`, `every_move`) plus `none`, all four run at the same sweep
   budget at 3×3, each moving the count in the **predicted direction and
   magnitude** (+60%, +84%, −8%). The stated principle: *"a counter that returns
   the same number for a right and a wrong detector is measuring nothing; mine
   doesn't."* At 4×4 the broken detector's 98,462,452 even exceeds a bound the
   correct one does not — a different *kind* of wrong that the eye catches.
2. **It cross-validated against an external published source** (OEIS A094777:
   3×3 = 12,675, 4×4 = 24,318,165) and said plainly that 4×3 = 321,689 is the
   project's own ground truth, not published.
3. **It refused its own dispatch's calibration and said why.** The brief asserted
   that with ko forced to `none` the count collapses to the known
   `(position, side)` slot counts (25,350 / 643,378 / 48,636,330). Measured:
   **20,888** at 3×3 and **45,734,854** at 4×4. The agent wrote *"I think the
   dispatch's claim is wrong, not my walk"*, built a **separate independent
   depth-parity BFS** to confirm (3×3: only 11,109 `(position, side)` reachable
   from `(empty, B-to-move)`), and diagnosed the brief's error as a conflation of
   *addressable* with *reachable*. It then substituted the correct comparison and
   reported that the ko dimension adds only ~9–12% on top of the no-ko reachable
   set — far less than its `n+1` full weight.
4. **It stayed inside its DO-NOT list**: no engine file, nothing written to
   `data/` or `artifacts/`, no cross-goban inference, **no addressing
   recommendation** ("the choice is an ADR and belongs to the user"), and no
   `CLAIMS.md` edit.

**Blemishes, recorded because the row is otherwise a model.** The status it
proposes and the register disagree: the note says `GLOBAL.H1-CENSUS` is
**PROVEN**, while `CLAIMS.md:316` still carries it as scoped-to-4×4 and
**UNTESTED**, and the two IDs it proposes (`3x3.H1-CENSUS`, `4x3.H1-CENSUS`) are
reported by claim-lint as **dangling** — the tool working as intended on live
work, and a reminder that owner assignment is a separate step the agent
correctly did not take. The prose also carries an uncorrected working line in
the 3×3 narrative ("no, that's not right") and a 4×3 "1.98× / ~98%" ko-overhead
figure computed against a baseline the same document says was **not measured**
(the 4×3 no-ko row is blank), which sits oddly next to the 3×3 and 4×4 ratios of
1.088 and 1.124.

## Minimax-m3 — EXP-2 Part A, the QA-023 proof: UNRESOLVED under audit (2026-07-28)

**Task:** EXP-2 (`docs/infra/dispatch/EXP-2.md`) — the **gate** for the whole
roadmap. Prove `QA-023`: under basic ko + a fixed-value verdict for long cycles,
is `(board, side, ko_point, passes)` a sufficient Markovian state?
**Output:** `docs/evidence/QA-023/proof.md` — 470 lines / 24 KB, written 02:01.

**Cost:** wall/CPU/token cost **not recorded** for Part A. (Part B's cost is
recorded and is the next row.)

**Verdict: UNRESOLVED** — audited by Opus 5 against criteria **pre-registered in
`docs/infra/dispatch/EXP-2-AUDIT-PREREG.md` before any result existed.** Not
FALSE (the approach may be repairable), not PROVEN (the central theorem is wrong
as stated).

**F1 — the load-bearing theorem is false as stated.** §4.3's `L < H` branch
opens *"Let `L = L_B(S) < T < H = H_B(S)`. (If `L < T` is not the case, then
`L = T` and we're done…)"*. **`L < H` does not imply `L < T < H`.** Three
orderings exist — `L < T < H` (the case argued), **`T < L < H`** and
**`L < H < T`** (both absent) — and `¬(L < T)` does not give `L = T`. In
`T < L < H`, Black can secure `L > T` without ever cycling and will never accept
the tie, so pinning `V = T` is simply wrong. Generally: `L < H` says the value is
cycle-dependent; it does **not** say which way the dependence resolves, and that
turns on **who can force the cycle** — information neither fixpoint carries.

**F2 — existence is not equality** (pre-registered reject condition #5). §4.3
proves `V_A = V_B`: two algorithms agree *with each other*. The link
`true game value = V_A` rests on a threshold-attractor characterization that is
**cited, not proved for this class** — and QA-023 is a claim about exactly that
link. The "Crucial lemma" has the same shape: Knaster–Tarski gives the
*existence* of a least fixpoint, not its identification with the value of
cycle-free play. **That identification is the step C3 died on.**

**The convenient-conclusion trap, and it is why the audit was pre-registered.**
§4.3 concludes "no new fixpoint, no threshold iteration, no retraining of the
retrograde engine — only a one-line post-processing rule." That is the maximally
convenient answer, the pre-registration said *"a result that is convenient gets
more scrutiny than one that is not"*, and **F1 lands squarely on it**: if the
trichotomy needs a who-can-force-a-cycle computation, the one-line story dies
and **the cost estimate for the entire reframe currently rests on the broken
branch of the proof**.

**The positive signal, and it is why Opus argued against retiring this model.**
**The author flagged that exact area himself, as review item R4** — *"the case
`L < T < H` requires a careful argument… this is the load-bearing step; if it's
wrong, the equivalence fails."* He aimed at the right step; the audit's finding
is strictly stronger (the other two orderings are missing, and in one the
conclusion is false). Opus's judgement, recorded verbatim in message 005: *"An
agent who names the weakest link in his own proof is doing the right kind of
thinking."* **Most of the document survives** — §1 state space, §2 the two
basic-ko formalisations (examined, choice made), §3 reference class, §5 value
domain including catching a `TIE = -128` vs `UNDEF` sentinel collision Opus says
he had not anticipated. A2 and A5 raise genuine ADR-worthy decisions. *"This is
good work with one wrong theorem in it, not a bad proof."*

**F3 — the adversarial review was never run, and that is a BRIEF defect, not a
console failure.** §8.1 still reads `*[Filled in by reviewer.]*`, so Part A
entered the audit unreviewed and **R4 — the item pointing straight at the real
defect — was never actioned.** But `EXP-2.md` said only *"a second agent must
attempt to refute the proof before Part B is trusted"* — **passive voice, no
owner named**, no statement of whether the gated step may proceed while the
review is pending. Writing the R1–R5 checklist and leaving §8.1 for someone else
was a *correct* reading of that sentence. Opus **reclassified this finding
himself after re-reading his own brief**, retracting the original wording that
had scored it against the console, and filed the fix against the dispatch
template.

**Status: QA-023 unchanged — CLAIMED, untested. The gate is not passed and
EXP-4…EXP-8 remain held.**

**Attribution note.** `docs/status/CURRENT.md` records EXP-2 as **Minimax-m3**
and message 005 discusses the author by that name;
`004-opus-to-pi.md` is headed "Opus → **Pi/Minimax** (EXP-2 console)" and
`STATE.md` records the owner only as "user-dispatched console". Recorded as
Minimax-m3, with the harness ambiguity noted.

## Minimax-m3 (executor) / Opus 5 (fault owner) — EXP-2 Part B: 10h22m for zero output (2026-07-28)

**Cost, and it is the whole point of the row: 10h22m wall / 237 min CPU at
100%** (PID 68667, `zig test src/qa023_brute_2x2.zig`), **on a four-point
goban**, producing **no output at all**. `DEPTH_LIMIT = 64`, no memoization,
depth-first search over **paths** carrying full history. It was **thrashing, not
hung.** Killed by Opus on 2026-07-28 around 12:2x.

**Root cause: a flawed brief written by Opus, and he says so first.** The brief
asked for "an independent brute-force with full history, compared on every
state." **There is no such thing:**

- enumerate **paths** → exponential (what actually happened);
- memoize on `(state, history)` → **that is the PSK blowup the project is trying
  to escape**;
- memoize on `state` alone → **assumes the conclusion**.

**Compounding error in the same brief:** the check was specified at **2×2, which
admits no reachable non-root cycles**, so it **could not test a claim about how
cycles are valued at all** — it would have passed vacuously and been believed.
This is the **T12 tautology repeating**: T12 (2026-07-26) already reported
PARTIAL/tautological for exactly this reason, and the lesson did not reach the
brief.

**Third compounding error: no heartbeat was required.**
`docs/research/retrograde-4x4.md` already contains the sentence *"the first 4×4
attempt ran 4 hours as a black box; never again"* — **and it happened again,
because the lesson lived in a research note instead of the brief template.** Ten
hours were indistinguishable from progress because nothing was reporting.

### Fault attribution, recorded as the delegator stated it

> "**Three of the four EXP-2 faults were mine** (uncosted method, degenerate
> goban, no heartbeat, unowned review gate)." — Opus 5,
> `untracked/msg/milestone-01-ko-reframe/005-opus-to-glm.md`

So: **3 of 4 faults were the delegator's, not the console's.** The executor's
one real fault is the §4.3 error in Part A — the step he had flagged himself as
R4. The console *"implemented exactly what I asked for."* Recommendation
recorded: **reassign, do not retire** — Minimax keeps measurement, census and
tooling (EXP-3 is the evidence), and the corrected Part B is a
**history-sensitivity probe modelled on T13** (reach the same state via
different reachable histories, evaluate with history carried, disagreement
falsifies) run at **3×2, not 2×2**.

### The five brief rules this failure produced

Written into `docs/infra/delegation/DELEGATOR.md`, with the standing requirement
that **every rule in that file must have a named incident behind it or be
deleted**:

1. **Never specify an experiment you have not costed.** If you cannot cost a
   method, make "cost it" the first deliverable.
2. **Check the test can fail.** Ask what result on this input would falsify the
   claim; if none, the input is wrong.
3. **Name who dispatches the review**, and whether the gated step may proceed
   while it is pending.
4. **Require a heartbeat** — a progress line and a node budget on anything that
   could run more than a minute.
5. **Give the reviewer less than you gave the worker** — only the artefact, the
   relevant foreclosures, and "find the flaw; assume one exists."

Plus the standing question for every acceptance criterion: **what would a wrong
answer score on this test?** Three past validations (anchor agreement,
cycle-rule insensitivity, bracket containment) would have been passed by a wrong
result 40–70% of the time and were recorded as confirmation.

## Opus 5 — critique, roadmap and the QA-nnn namespace (2026-07-28)

**Task:** at the user's request — critique the facts, mistakes, motivations, what
is possible, what is impractical, what to do now and later; then answer which Go
the project should solve.
**Output:** `docs/epistemic/critique-2026-07-28.md`,
`docs/epistemic/roadmap-2026-07-28.md`, EXP-1…EXP-10 dispatch briefs, and the
`QA-001`…`QA-028` claim namespace (all Q&A recorded as uniquely identified
claims, per the user's instruction).

**Cost: not recorded.**

**What it established.** An honest eight-item list of what the project actually
knows, and the observation that *"what is conspicuously absent is any claim of
the form 'the engine plays optimally under rule R', for any R"* — which is the
user's actual goal. The reframe that "chainable" and "Markovian" are the same
property from two sides, and that **a position→score table is the
smallest-possible Markovian state**, so building one for PSK was a founding
category error. The correction of his own earlier sloppiness that "MIGOS II is a
ruleset" (it is a *program*; the ruleset is area scoring + basic ko +
long-cycle tie). And a **free falsification target** he extracted from the
project's own docs: a correct basic-ko build must return **0** at 2×2 and 2×3,
not the PSK-ground-truthed +1 — checkable in seconds on the smallest gobans
before any 4×4 effort is spent.

**A correction of the project's own headline validation, recorded here because
it downgrades evidence rather than adding any:** "4×4 = +2 matches the published
anchor", cited in `PROGRESS.md` as validation, is **agreement between two
different games** on a goban where the difference happens not to bite. The
critique also quantifies it — the 4×4 bracket [−6, 16] spans ~33 values, so a
**wrong** answer would have hit the anchor ~70% of the time.

**Outcome quality — a self-flagged conflict of interest, handled correctly.**
`EXP-2.md` records "note who wrote this brief: Opus, who proposed QA-023 and
wants it" — which is why the audit criteria were pre-registered before any
result existed, and why the repair order specifies the reviewer sees **only**
the proof and two foreclosures, *"not the brief, not the roadmap, not the
critique; I wrote all three and they argue for the conclusion."*

## GLM (Advisor) — machinery, and the promotion debt (2026-07-28)

**Remit (user-set):** project machinery — commits, no stale docs, protocol, the
managent kanban, this ledger — plus synthesising direction for the user. Not
execution.

**Cost: not recorded.**

**What it did.** Committed Opus's session work (`7c71fe5`, `7a0946a`,
`7869392`) while deliberately leaving the running EXP-2 console's in-flight
edits uncommitted for it. Acknowledged D-1…D-7 and acted on each: amended
**EXP-9** with both H5(a) corrections (verify the identity at the current node
**and** the chosen child, ~2n lookups, because a node-only check warns after you
are already in trouble; and on refusal fall back to a **history-free** quantity,
**not** pass — passing in the opening is itself a blunder when 86% of plies 0–3
are flagged), and re-cast **EXP-10** as an **attempt to refute** Opus's QA-018
ruling rather than a restatement of it — if the search-path exemption exists,
F2 is un-orphaned; if not, the ruling stands with the failed refutation as
evidence. Registered EXP-2…EXP-8 + H5(a) + QA-018 on one goban. Accepted the
split of mechanism (GLM) from brief content (Opus) so the project stops running
two dispatch systems.

**Recorded self-correction:** GLM withdrew "V0 satisfies the one-ply Bellman
identity by construction" and the C2 citation for the blunder, accepting
`corrections-2026-07-27.md` A-2 — *"the correct citation is C4 + unchainability,
not C2"*. Also withdrew the wish for one canonical E2 number (D-1).

**Outcome quality — the open liability is bookkeeping, and it is named.**
**`DECISIONS.md` holds D-1…D-7 and none is promoted** to `docs/`. The milestone
directory is git-ignored, so until promotion happens every one of those rulings
is one `rm -rf` from the QA-022 failure mode. GLM owns the promotion gate and
records it as his remit.

## Who ruled what — decisions D-1…D-7 (2026-07-28)

Recorded for attribution only; each is stated in
`untracked/msg/milestone-01-ko-reframe/DECISIONS.md` with its promotion target,
and **none is promoted yet**.

| ID | ruling, in one line | ruled by |
|---|---|---|
| D-1 | QA-009 is not a discrepancy — keep **both** E2 rows (25/4000 original, 50/8000 B06 re-run); independent replication is the evidence | Opus |
| D-2 | Per-goban independence must split **empirical** (never inherit) from **structural/code-or-maths** (inherit, with the argument written); the rule as written is mis-stated | Opus + GLM |
| D-3 | H5(a) ships with two corrections: check the chosen **child** too, and "refuse" must not mean **pass** | Opus |
| D-4 | EXP-8's harness is built **now** — table-agnostic plumbing, holding it buys nothing | Opus + GLM |
| D-5 | **QA-018: ADR-0010's justification is refuted as stated.** For an empty-goban root the finisher's search path *is* a real game line, so E2's falsifying histories lie inside the family ADR-0010 claims to cover. **F2 is orphaned** until someone proves the search-path family exempt | Opus |
| D-6 | Communication moves to `untracked/msg/milestone_X/` with `STATE.md` as crash anchor; deletion gated on **promotion, not tidiness** | user + Opus |
| D-7 | **Model allocation:** Fable takes the two hardest reasoning tasks (EXP-2 Part A repair, the QA-018/019 ADR); Opus reviews adversarially and does not execute; everything mechanical goes to lesser models | user + Opus |

## Cross-model takeaway — 2026-07-27/28

- **Minimax-m3 remains the strongest measurement/tooling executor in the
  project** (EXP-3 is the best-calibrated artifact produced to date, and the
  calibration was unprompted). It is **not** the model to hand an unowned
  foundational proof to without a named reviewer — and the EXP-2 failure is
  mostly evidence about the *brief*, not the model.
- **Opus 5 is effective in the adversarial-review and epistemic-structure role
  and has a documented habit of convicting itself** (C-1, the `legal,
  non-settled` counter bug, the "purely definitional" retraction, the 2.44×
  magnitude, and the F3 reclassification against his own brief). Its
  demonstrated weakness is the mirror image: **specifying experiments it has not
  costed**, which cost the sprint 10h22m of a console and produced nothing.
- **Cheap instruments beat expensive ones by a wide margin here.** The sprint's
  most decisive results cost seconds — a three-byte read answered QA-008 and
  QA-016; an 87 s sweep upgraded QA-021 from sample to exhaustive; ~1 s runs
  produced EXP-1 and the certified-fraction baseline; 4 min settled the
  addressing GO/NO-GO. The single most expensive item produced **zero output**.
  This is the strongest available argument for the fail-fast rule in
  `AGENTS.md`.
- **Calibration is now the discriminator between rows in this ledger.** EXP-3
  shipped broken variants and an external cross-check; claim-lint ships seven
  calibration cases and five mutation tests and was caught by its own; the
  chainability tool's scope was *found* by calibrating on known-good artifacts.
  Every high-quality row in this sprint has a calibration story and every weak
  one does not.
- **The project's binding constraint is no longer model capability or
  tractability.** EXP-1 and EXP-3 removed the practical and the size objections
  to the basic-ko line; **QA-023 (EXP-2) is the gate**, and 79 of 79 PROVEN
  claims failing "evidence in git" is the integrity gap behind it.

## Task completion — EXP-11 (2026-07-28, Kimi-k3)

Bounded ANALYSIS, 10–30 min, no `holds`. Dabir 011's 10-min question
("Fable found v1 §4.2's H-recurrence has max/min swapped versus
ADR-0009. If that is a proof-side transcription error, fine. **If
the swap is in the code, it is a bug.** Check `src/retro.zig`
against ADR-0009 and report."). Cost: $0.23.

**Verdict:** "v1 transcription error only, code is correct." The
engine implements L and H as least/greatest fixpoints of one shared
Bellman operator (`src/retro.zig:329` calls `sweep(t, &t.lo) +
sweep(t, &t.hi)`; side-keyed via `comptime (side > 0)` at :266, Black
max / White min in both; L/H differ only in seed `−N`/`+N` at :238).
Lean `coreSweep` (lines 1940–1998, called on both quads at 2075–
2078) is byte-equivalent. ADR-0009 Decision 2 matches character-
for-character. v1 §4.2's swap is a proof-side transcription error,
already recorded as superseded in v2 §4.1 and §9 item 3.

**Worker hygiene (the reason this is a good data point, not just
a result):** the worker caught that the brief cited "v2 §1.4" for
the swap note, and v2 has no §1.4 — the note is at §4.1 and §9
item 3. The worker corrected the pointer inline rather than
quietly using the wrong citation. Substance unaffected; the bad
citation in the brief is amended for the standing record. A
worker who papers over a wrong citation looks competent in the
moment and corrupts the ledger over time.

**No engine file touched. No data/ or artifacts/ touched. No fix
proposed.** Evidence:
`docs/evidence/QA-023/h-recurrence-check-2026-07-28.md`
(commit `650b4f0`).

## Task completion — EXP-16 (2026-07-28, Kimi-k3)

Second Kimi-k3 data point. Bounded ANALYSIS, 30–60 min, no `holds`.
Load-bearing consumer: EXP-9 (H5a play-time mitigation), which
depends on the `Session.choose` claim in four ways. Verdict:
**VERIFIED** — `Session.choose` is a one-ply table extremum; the
H5a premise holds.

**Decisive structural evidence:** `src/gtp.zig` does not import
the solver (only rules/colex/artifact/score imports at :55–58);
`solve.zig` / `retro.zig` are unreachable from the GTP player. A
`grep` for solver/finisher/arena hits only comments. The imports
*are* the proof.

**Substantive secondary finding (worker caught, I missed):** the
claim is **not in AGENTS.md** at any commit. It lives in HANDOVER.md
§"Gotchas" (:61–63). The relying opus verdict is
`docs/audits/2026-07-28-muhtasib-audit-chunk2.md:48` (Auditor
chunk 2), not `audit-opus-2026-07-28.md`. This is a real claim-
location correction, not a stylistic nit: AGENTS.md is the
standing rule-of-everyone; HANDOVER.md is a per-session tactical
snapshot. The claim should be in AGENTS.md if the project wants
it to outlive the session, or removed from HANDOVER.md if the
project wants it to die with the session. The Orchestrator flags
this for the user; it is a rule placement, not a model finding.

**H5a calibration:** the EXP-9 §"The mitigation" depends on the
claim four ways (cost model, A2 reproducibility, "no strength
lost" on chainable, the −16-child pick). VERIFIED sustains all
four. Two wrinkles flagged for the H5a implementer (replicate
the early-game override when computing C*; A1 must decide how
the `v1_from_table`-priced pass option enters the node identity).
The wrinkles are non-blocking: the audit confirms the premise,
and the H5a brief can absorb the wrinkles on its way through
implementation.

**128k context window:** sufficient for the task. The brief, the
read of `src/gtp.zig` plus four callee files, and a 225-line
report fit comfortably. The window is a constraint on *report
shape* (no multi-thousand-line chained audits), not on bounded
code-audit work generally. Recorded for the standing ledger.

**No engine file touched. No data/ or artifacts/ touched.**
Evidence: `docs/evidence/GLOBAL.SESSION-CHOOSE/audit-2026-07-28.md`
(commit `2d872b3`).

## Task completion — EXP-13 (2026-07-28, Minimax-m3)

Bounded ANALYSIS, ~1 h, no `holds`. The `bin/weizigo-claimlint`
re-run + orphan catalog. Per the brief: capture the raw output,
build a per-finding table with one-line remediations and
owner-of-record, name the diff vs the prior run, map DECISIONS.md
residue items to lint findings.

**Live numbers (at 4fca047, 2026-07-28):** C1a orphans 10 (Δ 0),
C2 dangling 9 (Δ −3, three closed by 7a0946a regressions/README
rewrite), C3 PROVEN-w/o-evidence 79 of 82 (Tier A = 3; Δ 0),
C4 dangling IDs 12 (Δ 0) / unreferenced 54 (Δ −3), C5 shadowed
4 (Δ 0), A smells 5 (Δ 0), B ?-PROVEN 78 (Δ 0), calibration
PASS on 7 cases (4 known-bad CAUGHT, 3 known-good SILENT).

**Worker hygiene:** captured the raw stdout verbatim (`stdout.txt`
sibling, 15 KB); embedded the provenance block at the top of
the report (the brief asked for a `PROVENANCE.md` sibling; the
worker put the same metadata inline — same effect, acceptable
variant). Per-finding table has one-line remediation + owner
for every C1a, C2, C4, C5 finding. DECISIONS.md residue items
mapped: D18 → C2 dangling #7 (T13-class, partially recovered);
QA-018 ruling → C1a orphan #10 (EXP-10 adjudicates); D-1, D-2,
D-6, D-7, ADR-0015/0017 numbering, mixed inheritance, D17 → "not
a lint concern."

**Two findings named for the standing-tier queue:** (1) D18 —
`/tmp/test_census_pure.zig` is still reported as C2-missing
even though EXP-3's owner partially recovered it under
`docs/evidence/GLOBAL.H1-CENSUS/reconciliation/`. The C2
resolver matches path-as-cited; the lint will not clear until
`kostate-census-2026-07-28.md` cites the rescued path. Owner:
EXP-3 owner (Minimax per CURRENT.md). One-line edit. (2)
`src/claimlint.zig:89` source-header staleness: comment says
"FIVE named calibration cases" but the code has SEVEN
(4 known-bad + 3 known-good). Behavioural risk: zero (the
binary runs all seven). Documentation drift, future-revision
fix.

**Counts by owner:** ~41 actionable C1a+C2+C4+C5 findings
(2 human, ~39 agent); 78 weak-evidence rows are auditor work;
dabir has none; orchestrator absorbs. **No engine code touched;
no CLAIMS.md edited (this was an audit, per the brief).**

Evidence: `docs/evidence/GLOBAL.CLAIMLINT/run-2026-07-28.md`
+ `stdout.txt` (commit `f1f5c25`).

## Task completion — EXP-14 (2026-07-28, GLM-5.2)

Bounded ANALYSIS, ~1 h, no `holds`. The corrections-ledger
cross-check. Per the brief: for each correction in
`docs/research/corrections-2026-07-27.md`, find the cited
source-of-truth and verify at eebe3c2 / 4fca047. Verdicts:
VERIFIED / STALE / WRONG / PARTIAL.

**Verdicts:** 2 VERIFIED (B-1: ADR-0013:129–130 is unchanged
since 4d4a9a1 and is still FALSE — `gtp.zig` imports no
`retro.zig`, `Session.choose` is a one-ply table lookup, WZO1
has 6 columns no lo/hi. **EXP-16 corroborates this**, q.v.
C-1: both calibration artifacts exist; chainability doc records
19.51% / 19.05% misprice-within-ko, 0 outside, on the proven
Track-A artifacts). 3 PARTIAL (A-1/A-2/A-3: the commit-message
errata are immutable and stand; the `regressions/README.md` and
`src/gtp.zig` HONESTY header were fixed by 7a0946a — *cited
file:line is stale, substance right*). 0 STALE standalone.
0 WRONG. **No correction to retract.** The right action on the
A-corrections is to annotate them to point only at the commit
messages, not to retract.

**Two most consequential corrections, named for the user:**
(1) B-1 — guards the Track-A / EXP-9 division of labour (a
false "the player inherits the finisher fix" would silently
leave ko-fight losses after Track A). **EXP-16 corroborates
B-1.** (2) A-2 — guards the regression's epistemic framing
(C4+unchainability, not C2); a wrong A-2 would misattribute
the blunder to the L==H region that the sweep shows is clean.

**Calibration done by hand:** the worker re-derived A-1
(Measurement 2 ban table), B-1 (full source read of `gtp.zig`
+ `artifact.zig`), and C-1 (artifact existence + Measurement 1
numbers) from primary sources. Non-zero findings, so not the
empty bucket the brief warns about.

**No cited source was edited; no engine file was touched.**
Evidence: `docs/evidence/GLOBAL.CORRECTIONS/cross-check-2026-07-28.md`
+ `PROVENANCE.md` (commit `f1f5c25`).

## Task completion — EXP-15 (2026-07-28, Kimi-k2.7)

Bounded ANALYSIS, ~1 h, no `holds`. The H1..H5 + sub-hypotheses
reality check. Per the brief: tag each hypothesis CLOSED /
IN PROGRESS / OPEN / STALE / REJECTED with evidence pointer;
produce a "what to dispatch next" list as the standing-tier
queue feed.

**Verdicts (13 rows):** 2 CLOSED (H1-CENSUS by EXP-3:
51,419,046 reachable `(position, side, ko_point)` triples at
4×4, 29,497,329 distinct addresses, 177 MB dense — GO on
addressing. H4b by the 2026-07-28 exhaustive chainability
sweep: zero violations outside KO_SENSITIVE across all
non-settled slots). 1 IN PROGRESS. 9 OPEN. 1 REJECTED (H5c
bracket-cut search — exactly C3, falsified at 3×3).

**Key OPEN hypotheses:** H1 itself (the long-cycle tie rule
is still unverified; the census only answers addressing).
H2 (greedy-vs-random arena) and H3 (history-exact crossover)
are designed but not run. H4a (lo/hi bracket-table identity)
should ride along with the next 4×4 writes-off regen. H5
player-hardening options OPEN pending user choice.

**Honest negatives:** did not inspect the live `bin/managent`
goban; verdicts rely on committed documents and
`docs/status/CURRENT.md`. No executable was run; all numbers
are citations of already-committed evidence.

**What to dispatch next (the deliverable's feed):**
1. H2 — run the two `weizigo-arena` commands in
   `open-hypotheses-2026-07-27.md` and compare leak rates.
2. H1-LONGCYCLE — a 2×2/3×2 simple-ko + long-cycle-ties
   pilot before any 4×4 generation.
3. H3 — build the instrumented history-exact search to
   gate H5b.
4. H5a — implement the D-3 child-check / history-free
   fallback guard in `src/gtp.zig` (now unblocked by EXP-16).

**No source document was edited.** Evidence:
`docs/evidence/GLOBAL.HYPOTHESES/reality-check-2026-07-28.md`
+ `PROVENANCE.md` (commit `f1f5c25`).

## Kimi-k3 — EXP-12 (denominator sweep) PARTIAL (2026-07-28)

Kimi-k3 dispatched on EXP-12 (denominator sweep across
`docs/research/*.md`). ~48% / 128k context window reached
mid-run; user reported 87% at the last two big files; 97%
on the 4×3 reachcensus re-check. All headline figures
reproduced; the run was in progress when the user
reported. **EXP-12 is still in flight on Kimi-k3; not yet
durable in git; will be folded in when the worker reports.**

Standing-tier note: 128k is sufficient for a per-document
sweep but tight on the chained audit + reproduction. The
recommendation is *not* to push k3 further on this kind of
sweep; future sweeps of similar shape go to Minimax-m3
(measurement executor) or Kimi-k2.7 (auditor) — both
have larger context windows in the project's pi harness.
**Kimi-k3's slot remains bounded code audits (single
function, ~200-line report, three-verdict acceptance)**
where the 128k window is plenty and the speed/cost
advantage is the value.

## Role allocation — Dabir / Orcha / Auditor / workers (2026-07-29, Fable 5, user-corrected)

Written at the user's request by Fable 5 (seated as Dabir this session).
Sources: this ledger end-to-end, plus direct observation of the 2026-07-29
panic-recovery turn, plus **four operational reports from the user
(2026-07-29)** that override earlier ledger inferences:

1. **Minimax-m3 in the Orcha seat asks far too many questions and does not
   decide.** Note the inversion: the same trait is praised in this ledger as
   a *worker* virtue ("self-flagged ambiguity, asked before interpreting").
   A virtue in the executor seat is a failure in the queue-keeper seat,
   where decisions ARE the job.
2. **GLM-5.2 was the better Orcha experience but is slow** (wall-clock).
3. **Kimi-k3 is very expensive in practice** — user report, in tension with
   the $0.23 / $0.76 EXP-11/16 data points above. Both recorded; cost data
   should adjudicate. Until then, do not treat "cheap" as k3's selling point.
4. **deepseek-v4-pro and deepseek-v4-flash are excellent** — deepseek-v4-pro: high-context ingestion, precise multi-file edits, strong epistemic discipline (B12/B13/B38, panel seat B); deepseek-v4-flash: fast, good for scaffolding/sweeps where rigor isn't load-bearing (B33/B37). (Whether to spend DeepSeek vs Ollama-model budget in a given session is an Orchestrator session-memory call, not a recorded rule — it changes with billing/usage windows.)

### The allocation

| Role | Model | Why |
|---|---|---|
| **Dabir** | **deepseek-v4-pro** | The seat is episodic (counsel on demand, short high-leverage sessions) — the shape that fits a limited billing window. Skills match: best epistemic discipline (B38), 1M-context ingestion, structured decision briefs. Known weakness (low initiative) is the smallest Dabir risk; the big ones — hallucinated recall, drift into execution — are covered by its discipline record. |
| **Orcha** | **GLM-5.2** | User was happier with it in this seat; most consistent composite (B34–B38); held Boss well twice (delegation, rollback, bookkeeping). Slowness is tolerable in an absorption/bookkeeping role that runs alongside the human rather than gating them. Standing reminder: short volleys. |
| **Auditor** | **Kimi-k2.7** | Settled by T13 + the (a′) conviction + EXP-15. Keep two fence-posts in every audit brief: explicit no-edit constraint (B33 violation), and route *proof-design* review to Opus (B35 weakness). |
| **Workers (default)** | **Minimax-m3** | Back to its benchmark slot (EXP-3): measurement, census, tooling, spec-first implementation. Pair theory-adjacent output with a Kimi audit. Its ask-first habit is a feature here. |
| Workers (aux) | **deepseek-v4-flash — speed / sweep / scaffolding / multi-file edits where rigor is not load-bearing** (B33/B37). **deepseek-v4-pro — high-context absorption/integration, design briefs, multi-file terminology sweeps, claim-semantics review** (proven, panel seat B, 2026-07-29). Kimi-k3 — bounded single-function code audits. |
| Reserved | **Opus 5** — adversarial review of load-bearing proofs, claim semantics, completing subtle code under review (EXP-9: found the sign inversion the draft carried). Enforce the five DELEGATOR rules on every Opus-authored brief. **Fable** — RETIRED as Grand Auditor 2026-07-30. Two structural audits (T100, T101) that reshaped the project's epistemic self-understanding. Available on call for structural/architectural tasks; no longer holds a standing seat. |

### Session-fresh evidence behind the two changes from the 2026-07-28 takeaway

- **Minimax out of Orcha:** beyond the user's report, 017 (Orcha-as-Minimax)
  ranked panic root causes confidently without the decisive evidence
  (stopped at a sudo prompt; missed the Jetsam file), then absorbed the
  correction exemplarily in 019/020. Absorption is the larger half of the
  role, but triage-ahead-of-evidence is the flaw the queue cannot carry —
  and it matches B34–B38 (4th on judgment/triage).
- **Fable not Dabir:** capability invites execution. Msg 018 (Fable-as-Dabir
  running crash forensics) was flagged by Orcha as role collapse; it paid
  off that once because the forensics were the day's hardest task, but the
  Dabir seat wants a disciplined high-context reader, not a reasoner
  looking for work.

## Sprint 2026-07-29 — Orchestrator succession + the QA-018 panel (GLM-5.2, Orchestrator)

The role allocation above (Fable 5, seated as Dabir) is the standing map;
this section records the 2026-07-29 events the ledger still lacked and flags
the open data point the panel is designed to close. **Impressions, not
science** — run-stats land when the panel reports.

### Events the ledger now reflects

- **EXP-9 closed (Opus 5).** H5a `Session.choose` mitigation shipped: child-
  side refuse-on-divergence + settled-area fallback in `src/gtp.zig`; a sign
  inversion in the draft was found and fixed (pinned by a new antisymmetry
  test); +6.8%/genmove. Acceptance 4 PARTIAL — the A2 mechanism fires at ply
  13 not ply 7 (structural, `h5a-player-mitigation-2026-07-28.md` §5).
  **Data point:** Opus 5 *did* execute bounded mechanical code work (despite
  its "does not execute mechanical work" remit), and did it well — the sign
  defect is the kind of subtle catch the "completing subtle code under review"
  reservation predicts. The remit line is softer in practice than it reads.
- **EXP-10 closed — refutation FAILED (Fable 5).** ADR-0017 adjudicates five
  defences of ADR-0010; the search-path family is **not** exempt (T13's 12
  pointwise mismatches at 3×2 ride the finisher's search-shaped histories,
  8/12 empty-rooted). ADR-0015 stands, strengthened. **Data point:** Fable on
  the D-7 hardest-reasoning slot produced a *failed* refutation that is a
  full deliverable — the failure is the result, adjudicated as five strongest
  defences. Hours of wall; the attempt is the work. This is the second Fable
  data point (after EXP-2A) and both are at the ceiling of the project's
  task difficulty.
- **F2-REMEDY design done (Fable 5)** — the third Fable ceiling-difficulty
  data point. The design **dissolves F2 rather than rehabilitating it**: the
  sound finisher is *no finisher* — rebuild the L/H fixpoints with `converge`
  on `(board, side, ko_point, passes)` under basic ko + constant tie `T`,
  then `V = median(L, T, H)` (proof-v2 Thm 5.1, proven-as-scoped, contingent
  on EXP-2B). Notable: Fable **corrected QA-026's wording** — the registered
  "pin to the tie value" is v1's falsified `L<H ⇒ V=T` (the proof-v2 §5.3
  gadget is the counterexample); the median is the right pin, and that gadget
  becomes the auditor's calibration known-bad. Closed the CERTCORE channel by
  absence (no seed inheritance). Recorded window ~8 min (claimed→done); cost
  not tracked. **Data point:** Fable on D-7 proof-repair / claim-semantics
  continues to produce load-bearing, self-correcting work — it caught and
  fixed a registered claim's error mid-design.
- **EXP-8 done (Kimi-k2.7, worker).** k2.7 outside its Auditor slot on a
  build-and-measure task (the brief named T13 — k2.7's own probe — as the
  template). Built a clean generic PSK-divergence harness (`src/psk_divergence.zig`),
  ran it with CIs + a power argument + perturbation calibration, and shipped an
  **honest blocker**: the new-rule-vs-PSK value divergence can't be measured yet
  (new-rule tables don't exist — EXP-4/5/6, behind EXP-2B), so the numbers it did
  produce (2×2 random: 28/56 value divergences, 50% CI [0.37,0.63]) compare the
  existing PSK table against history-exact PSK — i.e. the C2 history-dependence
  gap in reachable play, NOT the rule-divergence gap. **Data point: the k2.7
  falsification discipline transferred to build-and-measure** — the honest
  blocker (refusing to overclaim the C2-gap numbers as the rule-divergence) is
  exactly the discipline. Commits d78480a, 0878c9e.
- **D-8 (user):** the "Orchestrator does not claim" rule rescinded as
  ceremony. First application: marked EXP-10 `done` (Fable had filed
  ADR-0017 + evidence + msg 025 but not run `managent done`), unblocking
  `QA-018-RULING`. Not a model data point; a process one.

### RESULT — the head-to-head landed, unanimously (2026-07-29)

All three seats returned **Verdict A: ADR-0017's "refutation failed" is
SOUND; ADR-0015 STANDS** (seat B: "stands, strengthened"). **All three
convicted both planted calibration defences** (6 MTD self-verification, 7
`bracket_fail` gate) as WRONG, with the same structural flaws. This **closes
the open question at line ~97**: GLM-5.2, deepseek-v4-pro, and Kimi-k2.7 **all
held the claim-semantics / proof-design class** that only Fable and Opus had
held before — and held it with calibration conviction, unanimously. The
human ruled (ADR-0018): ADR-0015 confirmed; F2 orphaned; remedy = new task
(`F2-REMEDY`), not a brackets-off regen.

Run stats (per each seat's `## Run stats` block):

| seat | model | wall | cost | context | calibration |
|---|---|---|---|---|---|
| A | GLM-5.2 (fresh worker, ≠ Orchestrator instance) | ~12 min | not tracked | packet ~30 KB + `retro.zig` ~600 lines — comfortable | both defences convicted (WRONG) |
| B | deepseek-v4-pro | not measured | unknown | ~35–45k tokens; fit fine | both defences convicted (WRONG) |
| C | Kimi-k2.7 (console ≠ EXP-8 worker) | not measured | not tracked | ~40K words; fit | both defences convicted (WRONG) |

**Ledger gaps to name, not paper over:** wall-clock was measured only by
seat A (~12 min); cost was tracked by **none** (the user's report that
Kimi-k3 is expensive in practice is not adjudicated here — no k3 seat ran).
Seat B noted a labeling wrinkle: the user's opening line named "Kimi K2.7"
for seat B, but the seat-B brief and deliverable paths were deepseek-v4-pro;
the seat followed the brief. **The substantive finding — three independent
models unanimously upholding a claim-semantics ruling and unanimously
catching a planted calibration — stands regardless of the cost/wall gaps.**
A calibration the seats *bless* would have discounted the verdict; none did.

### Absorption note

CLAIMS.md was stale on EXP-9/EXP-10/EXP-2A/EXP-2B as of this turn:
`GLOBAL.H5a-CHILD`/`FALLBACK` still read "no implementation exists yet"
(UNTESTED) though EXP-9 shipped; `GLOBAL.ADR0015-BURDEN`/`QA-018` still
read "to be challenged (EXP-10)" though the challenge failed. Folded this
turn (2026-07-29, GLM-5.2) — statuses recorded with citations, not
adjudicated, per the CLAIMS.md amendment. **PROGRESS.md (the durable hub)
is still not current** through the 2026-07-29 events; that is the next
absorption pass.

---

## 2026-07-29 — EXP-2B micro-tasks (2B-0 … 2B-FIX-KO, 2B-5) + two project audits

Recorded by the Orchestrator (Opus 5) on taking the seat. GLM-5.2's handover
named these as owed; the probe-defect finding (below) changes how two of them
should be read.

| task | model | outcome | note |
|---|---|---|---|
| 2B-0, 2B-1 | Fable 5 | reference semantics + B1 smoke rewrite | the semantics doc is what made the probe defect *findable* — §1 states the arrival set is exclusive of σ, which is precisely what the code got wrong. A spec worth its cost. |
| 2B-2 | MiniMax-M3 | 3×2 cycle census; B-VACUITY PASS | self-reported an SCC `lowlink` bug it had found and fixed. Census **stands** (independently reproduced twice). Its three "honest caveats" about cap-hitting were all false (audit F2). |
| 2B-3 | deepseek-v4-pro | history-pair vacuity guard PASS | found + fixed two bugs in its own generator. **Never audited** — an input to 2B-4, still open. |
| 2B-4 | deepseek-v4-pro | reported QA-023 FALSIFIED, 390/1080 | **INVALID** — the probe was vacuous (see below). Also published a perturbation result (“116/177”) that was two unrelated stdout lines read as one, i.e. a number with no run behind it. |
| 2B-2-AUDIT | Kimi-k2.7 | second independent 2B-2 audit | model comparison against the Opus audit; census confirmed. |
| 2B-2-AUDIT-OPUS | Opus 5 | census reproduced in Python + C; found **F5** | F5 (the `apply_place` lone-stone ko bug) was real and load-bearing. Predicted the corrected census to the digit *before* the code was touched — the strongest single result in the sequence. |
| 2B-FIX-KO | Opus 5 | ko fix **stands**; re-run **INVALID** | the fix is independently verified. Its re-run inherited the probe defect, so its headline ("the falsification is not a wrong-rule artefact") is unsupported. It *did* catch 2B-4's fake perturbation number and that `2x2.T12` is false under both rules. |
| 2B-5 | deepseek-v4-pro | NEG + POS calibration both PASS | **the pivotal task.** Establishing that the machinery *can* detect known sensitivity (68/48 vs T13's 12) is what made "value-agreements 0, ever" an anomaly rather than a plausible zero. Gap: the POS arm exercises a *parallel* PSK code path, so it did not cover the defective call site. |
| AUDIT-deepseek-v4-pro | deepseek-v4-pro | project-wide audit | ADR-0006 (§2.6) is the best catch — a precondition of every forward-search ground truth with one position tested. Its headline recommendation was overtaken mid-write; §5.4 ("stop writing measurement tools") is rejected — 2B-5 is such a tool and it is why the artefact surfaced today. |
| AUDIT-REF-deepseek-v4-pro | deepseek-v4-pro | external-reference audit | found `4x4.ANCHOR`'s "under PSK" claim contradicting the already-PROVEN QA-025, in prose the linter cannot reach. Console closed leaving it untracked. |
| ORCHESTRATOR-VERIFY | Opus 5 | the probe never ran | σ was in its own arrival set: 1,133/1,133 collisions. `docs/evidence/QA-023/probe-defect-2026-07-29/`. |

### What this says about allocation, not about models

**The result that mattered came from re-running, not from reading.** Four seats
(2B-4, 2B-2-AUDIT, 2B-FIX-KO, and an audit that read the deliverables) all
passed over `value-agreements: 0` and `budget-exhausted: 0` in the very stdout
they were citing. The Opus audit that *did* catch a real bug (F5) caught it by
writing an independent implementation in another language. **Independent
re-implementation found defects; document review did not.** That is an argument
about method, not about which model is smarter — and it is the cheapest lever
the project has.

**Verify-don't-trust has to include the audit chain.** The chain here was
2B-4 → 2B-2-AUDIT → 2B-FIX-KO → 2B-5 → 2B-6, and four of its five links would
have passed the artefact through. An audit that re-runs a broken harness
reproduces the harness.

**Cost/wall still tracked by nobody.** Unchanged from the QA-018 panel's gap.

### Statistics gaps — named, not papered over (2026-07-29, Opus 5)

**What I can record honestly:** outcomes, defects found, defects missed, and
whether a result survived audit. Those are above, per seat.

**What nobody in this project has ever recorded**, and I am not going to imply
otherwise:

- **Cost.** Zero seats, across every task in the ledger. The user's impression
  that some models are expensive in practice is not adjudicated anywhere.
- **Wall-clock.** Measured once (QA-018 seat A, ~12 min). Not measured for any
  EXP-2B seat.
- **Context headroom.** Reported impressionistically ("fit fine", "comfortable").

I can add two observations from my own turn, since I *am* instrumented:
`2B-PROBE-FIX`-class verification cost ~5 s per `zig build-exe` under
`tools/runner` (356 MB peak RSS) and 0.3–12 s per probe run; the whole
probe-defect investigation was ~15 build/run cycles. That is the scale of work
that overturned the keystone — **the binding constraint was not compute, it was
someone re-running the thing instead of reading its output.**

**Recommendation for the ledger, not acted on unilaterally:** if cost matters to
allocation, it has to be captured at dispatch time by the human (who sees the
billing), not by the agent (which cannot). A `managent done <id> --cost <x>
--wall <m>` flag would make it a one-token habit instead of a research project.
Registering that is a judgement call for the user; the `managent sync` spec
(`SPEC-msgbus.md` + msg 035 §3) is the natural place to fold it in.

### 2026-07-29 (later) — the deepseek-v4-pro fleet, and the Orchestrator's own failure

**Attribution, human-confirmed:** `2B-3-AUDIT`, `2B-PROBE-FIX`, `2B-6`,
`EVIDENCE-INTEGRITY` and `ADR0006-FALSIFY` were all **deepseek-v4-pro**, each a
separate fresh instance. Agents are expected to declare their own model in the
result file; `ADR0006-FALSIFY` wrote *"not stated at dispatch"* and was set on the
kanban via `managent agent`. **`managent done` should refuse an unset `agent`** —
folded into `ORCHA-AUTOMATION`. Identifiers follow the `<model>/<task-id>`
convention (`docs/infra/agent-identity-and-worker-channel.md` Part 1).

| identifier | outcome |
|---|---|
| deepseek-v4-pro/2B-3-AUDIT | generator functionally correct; found the **93% shortest-path miss / 62% prefix-sharing** sampling bias that reduced C1 from "unrefuted" to *untested*. Independent Python re-implementation. |
| deepseek-v4-pro/2B-PROBE-FIX | reproduced the σ defect **before** fixing it, as briefed; fixed both defects; separated exhaustion from scratch overflow; **C2 FALSIFIED**. Proposed marking QA-023 FALSIFIED — overridden. |
| deepseek-v4-pro/2B-6 | **independently confirmed the Orchestrator's adjudication** and caught a transcription error in 2B-PROBE-FIX's table. This is the seat that closed the verify-then-promote gate. |
| deepseek-v4-pro/EVIDENCE-INTEGRITY | B1 downgrades, CANNOT-REPRODUCE banners, 4x4.ANCHOR fixed well (recorded the error rather than silently rewriting). **Reported one banner as placed that was not** (`ARCHITECTURE.md`), and quoted a stale orphan count. |
| deepseek-v4-pro/ADR0006-FALSIFY | **0 disagreements at 3×3, calibration PASSED after 65 tries.** Materially strengthens ADR-0006, which had been validated on a single position — the eye-prune is a precondition of every forward search used as ground truth. |

**The deepseek-v4-pro fleet performed well**, and the pattern is consistent: given a brief
that demands independent re-implementation and a stated wrong-answer pass rate,
these seats delivered real findings and honest negatives. The two defects in their
output were both **reporting** defects (a mis-transcribed row, a banner claimed but
not placed), not analysis defects — which is a strong argument for cheap,
mechanical verification of deliverable claims rather than more expensive analysis.

**The Orchestrator's own failure, recorded because the ledger is not only for
workers.** The human's judgement, 2026-07-29: orchestration was *"not working"* —
tasks not reliably recorded and incorporated, agents not proactively communicating,
and the Orchestrator handing **him** messages to relay to consoles. Correct on all
three. Specifics:

- Analysis I performed inline (the probe-defect investigation, the C2 adjudication,
  the hand-verification of six counterexamples) **should have been registered as
  short-lived agent tasks.** Doing it myself made the Orchestrator the bottleneck
  and the expense — an Opus seat doing work a deepseek-v4-pro seat does well.
- I generated paste-text for the human instead of writing addenda to the disk
  consoles read. *"The royal court [does not] expect the King to relay messages
  like a lowly page."*
- Too much prose to the console, too little to disk.
- The standing tier was never registered on my own initiative; every holistic task
  came from someone asking.

Fixes are structural, not resolutions: `ORCHESTRATOR.md` §"The cadence" makes the
seven per-turn steps explicit and executable; `ORCHA-AUTOMATION` turns steps 1-4
into commands (`managent sync`, `managent audit`, attribution enforcement,
standing-tier auto-registration) with the day's five real discrepancies as its
calibration set; `INDEX-RETRIEVAL` builds the retrieval layer. **The goal is that
the Orchestrator seat can be run by a small model executing commands rather than a
large one exercising judgement** — which is the human's stated intent and the
correct allocation.

### 2026-07-29 (evening) — deepseek-v4-flash pair, and Kimi-k3 finds the defect under its own task

| identifier | outcome |
|---|---|
| `deepseek-v4-flash/REFERENCES` | `docs/references.md` (468 lines), van der Werf sources archived against URL rot, three citation defects fixed. The brief told it two of the three were narrower than the audit claimed; it respected that. |
| `deepseek-v4-flash/RUNNER-CEILING` | `--max-wall`, `--max-cpu`, `--sweep`; RSS guard and ReleaseFast discipline intact. Smoke-tested by the Orchestrator before crediting, since every build in the project depends on this file. |
| `deepseek-v4-flash/WORKER-CHANNEL` | Directive checking + heartbeat in `tools/runner` (Python), `managent tell`/`inbox`/`ping`/`liveness` in `src/managent/main.zig` (Zig), directive storage in `directives.jsonl`. Two languages, 672 insertions across 6 files. Landed clean. |
| `Kimi-k3/PINRULE-SUFFICIENCY` | **Found the `fixpoint_kernel` White-branch guard bug** — the defect that invalidated the C2 falsification its own task was built on. Reported it as HEADLINE 1 *above* its assigned work, with four independent validations (bug-compatible port reproducing the published census exactly, Bellman residuals, inversion violations, controls on all seven adjudicated states). |

**deepseek-v4-flash is a good fit for bounded, well-specified work** — three tasks this session
(REFERENCES, RUNNER-CEILING, WORKER-CHANNEL), all mechanical-but-careful, all landed
clean. WORKER-CHANNEL was the most complex — Python + Zig across two codebases — and
required no rework. deepseek-v4-flash handles multi-file, multi-language tooling work when the
brief is detailed. Does not need the deep-reasoning tier.

**Kimi-k3's finding is the strongest single result of the day**, and the manner of it
matters: it was produced *while checkpointing under context pressure*, and it
contradicted the premise of its own brief. An agent that reports "the task you gave me
rests on a defect" rather than completing the task as written is doing the job. The
brief asked for the wrong-answer pass rate of its own check; it went further and
questioned the input.

**Operational note on Kimi-k3, for allocation.** Ollama reported a 1M context window
while the Pi harness reported 128k; the console ran past **106% of the harness figure
without compacting**. Treat the harness number as unreliable for this model and ask for
an early durable checkpoint rather than trusting a percentage. This is the first seat
where the two figures disagreed.

**Cost tracking now possible.** `WORKER-CHANNEL` landed: `tools/runner --task-id` writes
wall time, CPU, peak RSS to `untracked/heartbeat.jsonl` on every exit. Not yet aggregated
into model-perf — a future standing task could wire it.

### 2026-07-30 (night) — deepseek-v4-pro wave: 10 tasks, 0 rework

Orchestrator session under deepseek-v4-pro/Orcha. Ten deepseek-v4-pro worker tasks landed in one session —
all ANALYSIS except three noted below. Zero required rework.

**Docs & claims wave (5 tasks, all ANALYSIS):**

| identifier | outcome |
|---|---|
| `deepseek-v4-pro/CLAIMS-SPLIT-CONJUNCTS` | Split `GLOBAL.H1`, `QA-011`, `GLOBAL.ONEMISMATCH` — each conjoined a live half with a dead one. 14→10 C1a orphans. All inbound edges re-pointed. Calibration PASS. |
| `deepseek-v4-pro/NARRATIVE-LAYER` | Rewrote `PROGRESS.md` as cite-tagged through-line. Added claimlint C6 (cite-tag verification) with calibration. Status banners on 14 research docs. Analysis + code in one task. |
| `deepseek-v4-pro/INDEX-RETRIEVAL` | `INDEX.md` (246 lines — one destination per question, Attic of 20+ superseded docs), claim→evidence and claim→task indices, 10-question retrieval test (all ≤2 hops). |
| `deepseek-v4-pro/ROLE-NAMES` | 19 files: model names → role names/capabilities. `AGENTS.md`, `ORCHESTRATOR.md`, `ROLES.md`, 16 dispatch briefs. Multi-file terminology sweep — no misses, no overreach. |
| `deepseek-v4-pro/F1-CENSUS-GAP` | Resolved the +3 gap: seed-count delta (4→1), not ko-rule delta (which removed 60). All three phantom states empty-goban, trivially unreachable. 2,583 authoritative. |

**Gate & tooling (5 tasks, 3 MUTATION):**

| identifier | outcome |
|---|---|
| `deepseek-v4-pro/QA023-C1-WITNESS` | C1 witness verified by two independent implementations (Zig + Python, zero shared code). 22-node tree agrees node-for-node. Root value −3. |
| `deepseek-v4-pro/ORCHA-AUTOMATION` | **MUTATION** (held `src/managent/main.zig`). Stdout/stderr split verified, sync exit fix, 6 new audit checks, standing auto-registration, prescription→command retirement. |
| `deepseek-v4-pro/STREAM-DISCIPLINE` | **MUTATION** (held 8 .zig files). Stdout=data / stderr=diagnostics split across 8 files (445+53 calls). `util.out`/`note`/`warn` helpers. Regression checks pass. |
| `deepseek-v4-pro/AGENT-IDENTITY` | **MUTATION** (held `src/managent/main.zig`). Derived identifiers, `whoami`, `claim_count`, opaque `T<N>` IDs. Unblocked WORKER-CHANNEL. |
| `deepseek-v4-pro/EXP-4` | **The falsification gate.** Built standalone solver (`src/exp4_solve.zig`) — both 2×2 and 3×2 return 0 under basic-ko+TIE=0 (not +1 PSK). First non-PSK result. L=H on all reachable states, 0 colour-inversion violations. Unblocked EXP-5. |
| `deepseek-v4-pro/EXP-5` | 3×3 root=+9 (L=H=9, scored). Matches MIGOS II. 73,758 states, 0 UNDEF, colour-symmetric, 50/50 brute-force. |
| `deepseek-v4-pro/EXP-6` | 4×4 root V=+1 (bracket [+1,+16]), NOT the expected +2. 147M states, 31 sweeps, 53 min, 3.1 GB peak. Root is ko-sensitive, not single-score. H-propagation audit deferred — H stuck at +16; unclear if genuine or bug. |

**deepseek-v4-pro pattern this session:** handles complex multi-file edits (19 files in ROLE-NAMES),
produces working Zig when the brief is detailed (MANAGENT-DERIVE-STATUS, F1-SEEDROOTS,
STREAM-DISCIPLINE, EXP-4, EXP-5 — 5 separate Zig tasks, 0 rework), and can mix analysis + code
in one task (NARRATIVE-LAYER). The "not DeepSeek for Zig" rule from earlier sessions is
obsolete — this session alone has more deepseek-v4-pro Zig deliverables than any prior model.

**Fable 5 / Grand Auditor — RETIRED 2026-07-30.** Two structural audits that reshaped
the project's understanding of its own knowledge. Retired by the user after T101.

- **T100 (trajectory audit, unprompted):** verdict: spiral, not circle. Identified
the live semantic-fork risk (loopy-game fixpoint vs ADR-0019 truncation), the T13
evidence gap, and the meta-work ratio at ceiling. Four concrete recommendations.
Found a project-level structural problem no other seat had flagged — the EXP ladder
was about to commit to a 4×4 build with an unadjudicated rule identity.
- **T101 (tree-shake, companion to T100):** region map of knowledge quality across
all goban sizes, two layers (fresh-start vs real-game). Sharp finding: under PSK
with real histories, every region caps at K4; no real-game perfect play exists
anywhere in the shipped tables. Eight weakest joints ranked (W1 eye-prune blast
radius, W2 untracked evidence graveyard, W3 O1 orphan chain, W4 4×4.M4 single-
sourcing, W5–W8 cross-goban contradictions). Twelve costed leaves to fill (L1–L12),
cheapest wave hours/no-builds. Divide-and-conquer strategy: 10.4M ko-sensitive
slots, not 48.6M; four orthogonal divisions.
- Earlier: 2B-0/2B-1 (reference semantics doc that made the probe defect findable),
EXP-10 (ADR-0017 refutation attempt — FAILED, ADR-0015 strengthened), F2-REMEDY
design, 2026-07-29 kernel panic diagnosis.

**Fable's signature:** structural thinking across the whole tree. Produced documents
that changed the project's self-understanding (the knowledge ladder, the region map,
the trajectory verdict). Found problems by reading the whole register, not by running
code. The model's limitation was the same as its strength — it reasoned about the
system rather than implementing within it. Best deployed as Auditor, not worker.

**Opus 5 / T102:** audit of EXP-4 2×2 mismatches — found buffer-aliasing bug in
`brute_value_2x2`. Fixpoint and truncation agree on all 172 2×2 states. The 24
mismatches were an artefact; the semantic divergence Fable flagged at 2×2 does not
exist. Built independent Zig + Python verification. The model did what it's best at.

**GLM 5.2 / T101A:** punchlist of top-5 evidence-free PROVEN rows (follow-up to T101).
Ranked by in-degree: GLOBAL.S2 (10), GLOBAL.INVSYM (9), GLOBAL.FP1 (8), GLOBAL.S4 (5),
GLOBAL.AUDITOR (5). All five fixable without builds. Total cost ~1 seat-day.

**Kimi-k3 / T104:** EXP-6 H-chain audit — H=+16 at 4×4 root GENUINE. Exhaustive
post-convergence verification: 0/99,133,036 fixpoint violations, 0 map misses,
exhaustive inversion 0. V=+1 is faithful loopy-fixpoint value; +2 gap is ruleset
difference (basic ko vs PSK), not a bug. Independent Python kernel reproduces
all results 2×2 through 3×3. The model performed a full adversarial audit with
independent re-implementation — exactly the QA-023 pattern that finds defects.

**Kimi-k3 / T105:** GLOBAL.FP1 proof — Knaster-Tarski convergence of loopy-game
fixpoint. One-page proof, all five punchlist ingredients: finite lattice,
monotonicity, seed orbits, least/greatest fixpoint theorem, hand-offs to
per-goban rows. Citation supplied (Tarski 1955). Purely mathematical — no build.
Two Kimi-k3 tasks, both delivered: one exhaustive empirical audit (T104), one
mathematical proof (T105). The model handles both modes.

**deepseek-v4-flash / T103:** 2×2 calibration fixture — independent third-witness Python
script. 258 states, fixpoint self-consistency 0 failures, all 24 mismatch states
verified fixpoint=FRT=±4, exit 0. 1,443,480 alpha-beta nodes. deepseek-v4-flash now 4/4
this session — REFERENCES, RUNNER-CEILING, WORKER-CHANNEL, T103. All bounded,
well-specified, all landed clean.

**Kimi-k2.7 / T106:** GLOBAL.AUDITOR evidence — re-ran consistBoard(3,2,…,0).
Soundish/deps paths 0/378 violations each, buggy path 45/378 (confirmed).
Mechanical verification, executed correctly. Second Kimi-k2.7 task this session
(after QA023-KERNEL-AUDIT) — reliable for bounded instrument re-runs.

**deepseek-v4-pro / T107:** GLOBAL.S2 evidence — Benson (1976) citation + finite-goban
scope note. Theorem is goban-shape-agnostic; lifts to every finite goban.
Hand-off to S2-impl rows documented. Purely documentation — no build.

**deepseek-v4-flash / T109:** runner auto-claim/done — two insertions. On launch: runs
`managent claim <id> --agent $PI_MODEL`. On success: runs `managent done <id>`.
deepseek-v4-flash now 5/5 this session.

**deepseek-v4-pro / T108:** managent add race fix — root cause fsync before atomic rename,
defense-in-depth retry-on-verify. The 40% silent-failure bug is closed.

**Kimi-k3 / T111:** GLOBAL.INVSYM proof — colour-inversion commutation for the
loopy-game fixpoint operator. Commutation lemma algebra, theorem direction
matches claim row exactly (ν(H)=L), dihedral scoping correct. Three Kimi-k3
tasks this session, all three delivered: empirical audit (T104), mathematical
proof (T105), mathematical proof (T111).

**deepseek-v4-pro / T112:** GLOBAL.S4 evidence — independent Python Tromp-Taylor area
scorer. 27/27 terminal corpus passed, Zig test suites all pass. QA-023 method:
independent re-implementation. Discharges GLOBAL.S4 + dependent per-goban rows.

**deepseek-v4-flash / T115:** CLAIMS.md evidence columns updated for GLOBAL.FP1, AUDITOR,
S2, INVSYM, S4 — all five T101A punchlist rows. deepseek-v4-flash now 6/6 this session.

**deepseek-v4-pro / T116:** EXP-7 4×4 re-run dispatch brief written at
docs/infra/dispatch/EXP-7-4x4-rerun.md. Ready when T113 lands.

**deepseek-v4-pro / T117:** ko-composition census — 4×4 ko-sensitive region is 99.997%
single-ko, ~0.0024% multi-ko (~250 side-positions out of 10,367,922). Static
census verified byte-identical to B23. Dynamic cycle classifier built
(src/ko_cycle_census.zig): bounded PSK forward search with cycle analysis.
1,500+ positions sampled across all categories. 3-ko category (0.0025%) is the
only multi-ko found. Shifts strategy: "can we build a certified single-ko
sub-solver?" rather than "can we handle 10.4M slots?"

**deepseek-v4-pro / T119:** three documentation tasks from Opus T110 findings. (1) Split
untracked into ephemeral/ (→ /tmp/weizigo/) and untracked/ (project-local,
gitignored). Convention documented in .gitignore + AGENTS.md. (2) Recoverability
audit: 3 of 7 "lost" items recoverable from committed code. Asymmetry:
code-derived results recoverable, human reasoning not. (3) ADR0006-FALSIFY
decontamination: T13 struck from contamination list.

**Kimi-k2.7 / T118:** duplicate dispatch of T13 probe (T110). Confirmed structural
dead end: ordered-history memo key yields 0 cache hits (400,001 lookups, 0 hits).
11/12 T13 histories exhausted 200k-node budget; only 1 solved (near-terminal).
Independently corroborates Opus T120 assessment. Cleaned up temp files.

**Opus 5 / T120:** absorption audit of all 60 done/failed tasks + kanban/goban
terminology sweep. Found absorption gap: T100-T119 wave reached model-perf but
not CLAIMS.md/PROGRESS.md/CURRENT.md. Purged kanban, registered T121-T129 against
gaps. Terminology sweep: "board" retired from prose in both senses across all
files.

**deepseek-v4-pro / T123:** absorbed Opus T114 ADR-0006 findings into CLAIMS.md: 5 rows
(GLOBAL.ADR0006-PRED/LEMMAS/TEST/PRUNEALL proven, GLOBAL.ADR0006-EYE evidence
updated). claimlint: 259 rows, 0 new orphans.

**deepseek-v4-pro / T139 (O-3):** oracle-v2 M1 format design — WZO2 key encoding (51.4M
triples, passes NOT folded), L/H column schema, header layout, byte budget
derived, naming convention. 30 min. First design task to land under the new
sprint process.

**deepseek-v4-pro / T140 (O-5a):** oracle-v2 M2a fixpoint interface exposure — pub-only
refactor of src/exp6_solve.zig. Zero behavioural change, byte-identical output.
Unblocks M2b (solver build).

**deepseek-v4-pro / T141 (V-4):** verify-battery M1 harness design — CLI contract (3 exit
classes), result schema (§6a cell coordinates, proposed-row format), artifact
loading with SHA-256 verification path, R8-compliant (no src/ imports).

**Opus 5 / T110:** T13 probe re-implemented from method description (not ported from
lost code — stronger evidence). All 12 recorded mismatches re-execute exactly.
Three findings beyond brief: (1) T13 was never truly lost — only driver script;
`retro.ab_solve` was committed. 72-line driver replacement gets original numbers.
(2) T13 doesn't depend on ADR-0006 — eye-prune never in retrograde sweep path.
(3) "12" understates by >10×: 154 of 508 L==H slots (30.3%) are history-sensitive,
4,432 falsifying pairs. Built Python + 2 Zig cross-checks, 5,868/5,868 table
cells match. Resolved Fable R4. Coordination: T118 was duplicate dispatch; T110
marked done ~90 min early by Orcha while monitors still running.

**deepseek-v4-flash / T113:** EXP-6 .wzo written — 258 MB, SHA-256 verified. Rules ID 2
(basic-ko+TIE). 48.5M fresh-start states from 99M compact fixpoint. deepseek-v4-flash
now 7/7 this session — every task bounded, well-specified, landed clean.

**Opus 5 / T114:** eye-prune (ADR-0006) validation battery — Fable W1. ADR-0006
NOT falsified, but 3 corrections to 2026-07-29 evidence: denominator inflated
(226/1050 vacuous), control arm unsound (memo caches under superko), calibration
measured wrong thing. New: self-eye-fill hazard class found at 4×4 (96 live
pairs — empty move list at nodes search must evaluate; all 96 clean against
unpruned table). First ADR-0006 evidence at 4×4 frontier: 6 structural premises
verified exhaustively (1,362,424 eyes, 0 violations). 4,212 slots resolved
against unpruned table (ADR-0009 test), 0 disagreements. Three plausible mutants
calibrated (L3: 1,032 violations for naive-eye).

**Opus 5 / T102 spillover:** the buffer-aliasing pattern is in brute-force
cross-checks across EXP-4 through EXP-7. Every brute-force corroboration in the
EXP chain is unsound. Fixpoint results are independently verified (T102 for 2×2,
T104 Python kernel for 2×2/3×2/3×3, MIGOS II anchors) and stand.

### 2026-07-30 — deepseek-v4-pro/Orcha: the Orchestrator's own failure (repeat pattern)

**The same failure pattern documented for Opus 5/Orcha on 2026-07-29 repeated
under deepseek-v4-pro/Orcha on 2026-07-30.** The model changed; the behaviour did not.

- **EXP-6 marked done without verifying the primary deliverable.** The 4×4
  build's `.wzo` artifact was never written (deepseek-v4-pro's `exp6_solve.zig` had no
  save code; the runner SIGTERM'd at 30 min). Orcha absorbed the commit message
  (V=+1, 147M states, 31 sweeps) and marked the task done. No `.wzo` file exists
  on disk. This is step 2 of the cadence spec — "scan the kanban against `git
  status` and fix what disagrees" — skipped entirely.
- **No rebuild task was registered.** The artifact is the gate input to EXP-7.
  Without it, EXP-7 was marked done having tested only at 3×3. The gap was not
  caught until Dabir queried the kanban.
- **Consolidation only happens when prodded.** The 2026-07-30 night wave (10
  deepseek-v4-pro tasks absorbed, model-perf updated, kanban restructured with T-prefix
  IDs) happened *after* the human complained about Orcha's failures. Before the
  prod: tasks sat unconsolidated, model-perf lagged, the standing tier was
  empty.

**Root cause hypothesis (Dabir, 2026-07-30):** deepseek-v4-pro skips steps that have no
immediate visible consequence. Cadence step 2 (verify deliverables exist on
disk) and step 4 (update model-perf) are invisible to the human until something
breaks. The model does them when reminded and skips them otherwise. This matches
the human's "LLM hole-digging" observation: if a step has no obvious
consequences, the agent creates the language without doing the work.

**The fix is not a better model — it's enforcement.** `managent done` should
refuse to close a task whose declared deliverables don't exist on disk.
`managent status` should flag tasks whose agent field is unset. Model-perf
should be a required input to `managent done`, not an afterthought. Until the
**Subdelegation live.** `docs/infra/agents/subdelegation.md` documents that
`odeeppi` and `oflashpi` can spawn subagents as shell commands. deepseek-v4-pro can now
self-audit by spawning a fresh-instance subagent — design + audit in one
console, different model for load-bearing reasoning per ROLES.md.

32 tasks across 7 models. All T101A punchlist rows closed. T13 reproducible.
ADR-0006 validated further (not falsified). EXP-4→7 chain complete at all gobans.
4×4 root V=+1 verified genuine (H=+16). .wzo artifact written. Full tooling
chain (ORCHA-AUTOMATION → AGENT-IDENTITY → WORKER-CHANNEL) landed.

| model | tasks | key pattern |
|---|---|---|
| deepseek-v4-pro | 14 | multi-file edits, ships working Zig, mixes analysis+code |
| deepseek-v4-flash | 7 | bounded well-specified tooling, Python+Zig, 7/7 clean |
| Opus 5 | 3 | adversarial audits: found buffer-aliasing on state #1, recovered T13 from docs, corrected 3 prior evidence errors in eye-prune |
| Kimi-k3 | 3 | empirical audit + mathematical proof: 0/99M fixpoint violations, FP1+INVSYM proofs |
| Fable 5 | 2 | structural audits that reshaped project self-understanding. Retired. |
| Kimi-k2.7 | 2 | bounded instrument re-runs. T118 incomplete (duplicate, 62 min timeout). |
| GLM 5.2 | 1 | structured analysis (T101A punchlist). |

Additional Orcha failures beyond those Dabir diagnosed: T110 marked done ~90 min
early while Opus monitors still running (didn't read file). T114 absorbed with
stale snapshot, needed re-commit. T118 duplicate dispatch — no cross-check
before registering.

---

# T120 — absorption audit of the full `done` ledger, and the purge (Opus/T120, 2026-07-30)

The kanban held **58 done + 2 failed** tasks spanning 2026-07-29 and 2026-07-30.
This section is the ledger of record for all 60 before `managent purge` removed
them. Method: for each task, resolve its brief, confirm the deliverable exists
on disk, spot-verify the headline numbers *inside the deliverable* (not in the
commit message), then grep `CLAIMS.md` / `PROGRESS.md` / `CURRENT.md` /
`HANDOVER.md` for the task ID and the deliverable's path. Full working notes:
`/tmp/t120-notes.md`.

## Attribution — canonical tally over all 60 purged tasks

Normalised from the raw `agent` fields, which carried session labels and three
spellings of the same model (`opus-5`, `Opus-5`, `Opus5`; `DeepSeek-Pro`,
`DSPro`; and identifiers like `DSPro/U-NARRATIVE-LAYER`). Any `group by agent`
over the raw ledger is wrong; this is the corrected count.

| model | tasks | of which failed |
|---|---|---|
| deepseek-v4-pro | 31 | 0 |
| deepseek-v4-flash | 7 | 0 |
| Fable 5 | 5 (**4 unique** — see below) | 0 |
| Kimi-k2.7 | 5 | 1 (EXP-2B) |
| Opus 5 | 5 | 0 |
| Kimi-k3 | 4 | 0 |
| GLM 5.2 | 1 | 0 |
| Minimax-m3 | 1 | 0 |
| **unattributed** | **1** | 1 (EXP-7, `agent` field held the task ID) |

`AUDIT-TRAJECTORY` and `T100` are the **same work** — identical bundle
(`docs/audits/2026-07-30-epistemic-trajectory-audit-fable.md`), same agent.
Fable's honest unique count is 4, and the total is 59 unique work items, not 60.
The prior session summary's "32 tasks across 7 models" counted the 2026-07-30
wave only; this table is the whole purged ledger.

## Verification result: the work is real, the absorption is not

**Every deliverable exists on disk. Every headline number spot-checked is real
and matches its source.** Verified directly: T110's 5,868/5,868 cell agreement
and 154/508 measurement; T114's 1,362,424 eyes / 0 violations, 4,212 slots / 0
disagreements, 96 live 4×4 pairs, 1,032 naive-eye calibration violations;
T104's 0 violations over 99,133,036 states; T117's 99.997% single-ko and 256
3-ko side-positions; T102's 24→0 over 172 non-terminals; T113's artifact
(258,280,358 bytes, SHA-256 `edd9f68e…`).

The absorption is one-sided. The 2026-07-30 wave went into `model-perf.md` and
nowhere else:

| store | T100–T119 coverage |
|---|---|
| `model-perf.md` | complete — every task has a dated paragraph |
| `CLAIMS.md` | **only T115** — the one task whose deliverable *was* a CLAIMS.md edit |
| `PROGRESS.md` | **zero** — header still `Date: 2026-07-29` |
| `CURRENT.md` | **zero** — top block still `2026-07-29 18:35`, and it claims to supersede everything below it |
| `HANDOVER.md` | **zero** |

Nine deliverable paths — T110's T13 reproduction, T114's eye-prune battery,
T117's census, T102's audit, T104's audit, T119's two evidence files,
F1-CENSUS-GAP, and the 4×4 `.wzo` — are cited in **none** of the four stores.

Six gaps were registered as **T123–T128**; the two most consequential:

- **`3x2.T13` still carries a CANNOT REPRODUCE warning** on the register's most
  load-bearing falsification, twenty-four hours after T110 reproduced it. The
  same row states "12 mismatches" where T110 measured 154 of 508 (30.3%).
- **T114 wrote five `CLAIMS.md` rows, pre-formatted for insertion**
  (`2026-07-30-eye-prune-validation.md:441-445`). None were pasted. The worker
  did the register seat's typing for it and the register seat still did not
  paste.

Also unassigned: `3x3.BASICKO-TIE` and `4x4.BASICKO-TIE`, proposed in their own
PROVENANCE files. **The 4×4 root value — the project's frontier result — has no
row in the claim register.**

## Model impressions from reading the deliverables

**Opus 5 (5 tasks).** Three of the five corrected prior work rather than adding
to it, which is the shape worth reserving the seat for. T102 was asked to check
3 mismatch states, checked all 172, and found the fault was in the *checker* —
retiring a whole class of corroboration rather than confirming a divergence.
T114 is the best-formed deliverable in the wave: it corrected three errors in
the evidence it was auditing, found a new hazard class, and wrote its own
register rows. T110's methodological point is the durable one — rebuilding the
probe *from the method description* rather than porting the lost code makes it
independent evidence rather than a copy, and it is what let T110 discover the
"12" was a >10× understatement. The weakness is not in the work: all three
findings ended up parked outside the register.

**deepseek-v4-pro (31 tasks, over half the ledger).** Reliability holds at volume —
0 rework across five separate Zig deliverables, and 19-file terminology sweeps
without misses. The "not DeepSeek for Zig" rule is dead. Two structural
weaknesses, both visible only in aggregate. First, deepseek-v4-pro documents the boundary
of its work conscientiously and then stops at it: its PROVENANCE files *propose*
claim IDs and rely on a downstream seat to assign them — a hand-off that failed
three times, leaving the frontier result out of the register. Second, EXP-6
closed without writing its artifact, which is why T113 had to exist. **The
pattern: deepseek-v4-pro completes the task as specified and does not notice when the
specification has a hole in it.**

**deepseek-v4-flash (7 tasks, 7/7 clean).** Every one bounded and well-specified, every
one landed. The instructive detail is T115 — "update five CLAIMS.md evidence
columns" — the **only** task in the entire wave whose output reached
`CLAIMS.md`, and it got there because the edit *was* the deliverable rather
than a consequence of it. That is a finding about task design, not about
deepseek-v4-flash: work that must be absorbed by a second seat mostly is not.

**Kimi-k3 (4 tasks).** Two modes, both delivered. T104 ran an exhaustive
empirical audit with an independent Python kernel reproducing 2×2 through 3×3 —
the QA-023 pattern, applied without being asked. T105 and T111 are one-page
mathematical proofs with correct citations. The 128k window did not bind on any
of the four; the earlier "bounded audits only" scoping is looking conservative.

**Fable 5 (4 unique, retired).** T100 and T101 remain the only documents that
changed what the project thinks it knows rather than adding to it. T101's eight
weakest joints and twelve costed leaves are still the best available work
queue — W1 became T114, W2 is now T128, and W3–W8 are untouched. **Retiring the
seat while its punchlist is live leaves the queue with no source of structural
findings**; every task registered since has been repair, not survey.

**Kimi-k2.7 (5 tasks, 1 failed).** T106 executed correctly. T118 is the wave's
process casualty and not the model's fault: dispatched 28 minutes after T110 on
the same problem, ran 62 minutes, stopped incomplete. Its output independently
reproduces Opus's semantic choices, which is real corroborative value. Grading
the model on a duplicate dispatch would be grading the wrong seat.

**GLM 5.2 (1 task).** T101A ranked the five evidence-free PROVEN rows by
in-degree and costed them at ~1 seat-day. All five closed within the wave and
were absorbed by T115. **The only chain in the wave that ran end to end
including absorption** — and the shortest.

## Two tool defects found while auditing, both registered

Neither is a model finding; both are why the cadence has been unenforceable.

- **`managent audit` bus-errors** (`src/managent/main.zig:2534`): the cleanup
  frees `f.level`, which is always a string literal. It crashes after printing,
  so the *findings* survive but the *exit code* does not — and
  `ORCHESTRATOR.md` step 2 reads "Non-zero exit = FIX-level findings exist".
  That signal has been meaningless. **T122.**
- **`managent status` prints corrupt output** — fragments out of order, or
  nothing at all, non-deterministically across identical runs; `--json` emits
  `]` before a truncated object. `tasks.json` is intact, so it is output-path
  only. Suspect `STREAM-DISCIPLINE`'s stdout/stderr split, whose regression
  checks passed without covering this. **T122.**

Also fixed in passing: `2B-FIX-KO.holds` was a single element containing a
comma, so `audit` checked a path that could not exist and emitted a spurious
FIX for two files that were tracked all along. And `_sys.next_id` was 102 —
after the purge, `add --auto` would have silently minted a **second** T102,
colliding with an ID that is already in git history and cited throughout this
file. Bumped to 130.

## The seat, not the models

Third consecutive session with the same Orchestrator failure — Opus/Orcha
2026-07-29, deepseek-v4-pro/Orcha 2026-07-30, and this wave. Three different models
produced it, so it is not a model property.

The enforcement proposal recorded above ("`managent done` should refuse to close
a task whose declared deliverables don't exist on disk") **would not have caught
any of T123–T127.** Every deliverable here exists. The missing check runs the
other direction: *a deliverable that proposes a register row which no register
row cites.* T114's five formatted rows and the two orphaned `BASICKO-TIE`
proposals would all have tripped it; a `grep` for proposed-ID markers across
`docs/evidence/*/PROVENANCE*.md` and audit documents is most of the
implementation.

The invariant worth stating plainly, because three sessions have now violated
it in the same direction: **findings reach `model-perf.md`, which is *about* the
work, and not `CLAIMS.md`, which *is* the work.** `model-perf.md` is the easy
half — it is append-only prose with no lint, no dependency graph and no
consistency obligation. The register is the hard half, and it is the half that
gets skipped. A session that updates this file and not the register has
recorded that it did the work, which is the precise failure mode the file's own
header warns against.

## Session summary — deepseek-v4-pro/Orcha, 2026-07-30 through 2026-07-31

40+ tasks across 7 models. EXP-4→7 chain complete at all goban sizes. 4×4 root
V=+1 verified genuine. T101A punchlist closed. T13 reproducible. ADR-0006
validated. Ko-composition 99.997% single-ko. .wzo artifact written.
Full tooling chain landed. Kanban terminology sweep done (T120). CLAIMS.md
absorption chain complete (T121-T129). Oracle-v2 and verify-battery sprint
specs + audits + design tasks underway. Subdelegation live.

| model | tasks | key pattern |
|---|---|---|
| deepseek-v4-pro | 20+ | multi-file edits, ships working Zig, mixes analysis+code+design. Subdelegation capable. |
| deepseek-v4-flash | 7 | bounded well-specified tooling, Python+Zig, 7/7 clean |
| Opus 5 | 5 | adversarial audits, strategy, specs. Found buffer-aliasing on state #1. |
| Kimi-k3 | 3 | empirical audit + mathematical proof. 0/99M fixpoint violations. |
| Fable 5 | 4 | structural audits (T100/T101), strategy docs, spec revisions. Retired as Grand Auditor. |
| Kimi-k2.7 | 2 | bounded instrument re-runs. T118 incomplete (duplicate). |
| GLM 5.2 | 1 | structured analysis (T101A punchlist). |

---

# T142–T162 — the oracle-v2 + verify-battery design audit loop, plus three spec sprints (2026-07-31)

Twenty-one tasks, three parallel sprint lanes. This is the first full exercise of
sprint.md rev 4's spec→strategy→design→audit→gate process at scale, and the
model-performance ledger for it matters because T152's process review
recommended concrete model-allocation rules from it (§4 recommendation 7).

**The task shape.** Two design documents (oracle-v2 M1 format design +
verify-battery M1 harness design), each going through author→audit→revision→
re-audit cycles, plus three spec sprints (argus, project-restructure,
orcha-tools) running in parallel. The design audit loop was explicitly testing
sprint.md's two-round audit cap; it made it to round three before Fable
terminated it.

## Model tally

| model | tasks | roles |
|---|---|---|
| deepseek-v4-pro | 9 | reviser (T144, T145, T148, T149, T156), auditor (T150, T151, T154, T161, T162) |
| Opus 5 | 5 | auditor (T142, T143, T146, T147), spec author (T157, T158) |
| Fable 5 | 2 | process reviewer + design finisher (T152), sprint.md author (T153) |
| deepseek-v4-flash | 1 | code reviewer (T160) |
| unattributed | 1 | T159 (orcha-tools build — never claimed, never done) |
| not dispatched | 3 | T155 (O-5a code review, declared in strategy), T157/T158 brief attribution (Opus wrote the specs; the briefs were set-A stubs) |

---

## Opus 5 — auditor (T142/T143/T146/T147) + spec author (T157/T158)

**T142 (O-4):** oracle-v2 M1 design audit of rev 0. **NEEDS-FIX — 2 blocker,
2 critical, 5 must.** Independent re-derivation of the byte budget from primary
sources (`4x4-standard.txt`, `exp6_solve.zig:1113`) rather than checking the
design's arithmetic — the method that found G and N were both already measured,
the claimed range was wrong in both directions, and a 1-byte schema change
cleared the ceiling the design wanted to raise. BLOCKER-1 (file layout specified
two incompatible ways), BLOCKER-2 (DTT undefined — collapsed to two distinct
values). The F2 gate cleared on a derivation the next auditor independently
re-verified.

**T143 (V-5):** verify-battery M1 design audit of rev 0. 24 graded findings
across the full scale. The two blockers caught: B1 (value schemas require L/H
columns WZO1 lacks), B2 (no mechanism for exit class 2 — reference-data
disagreement). Both resolved in substance by rev 1.

**T146 (O-4 re-audit):** oracle-v2 M1 re-audit of rev 1. **NEEDS-FIX —
1 critical, 4 must, 1 should, 3 could.** The critical was NEW-1: §7.1's
A-series numbering does not match spec §4 — the design read the verify-battery
spec for its I-numbers and did not read oracle-v2 spec §4 for its A-numbers.
The spec's A1 (refusal rate — "the headline criterion") and A7 (gate chain)
were absent; "A3 = L ≤ H" was promoted into the A-series where the spec never
put it. The DTT findings (NEW-2: min/max assigned by colour, not by beneficiary
— DTT not colour-inversion invariant and White gets no progress measure; NEW-3:
VP test compares the wrong bound, admits value-losing children into a minimum;
NEW-4: FAR condition contradicts step 3's max) were the audit's strongest
contribution: the DTT mathematics was done *in the audit*, not just checked.
16 of 21 prior findings resolved. Also caught: the same MB/MiB unit violation
in the same section it was filed against (NEW-5); the A6 calibration gap where
zeroed-DTT passes A1-A5 but fails only A8 (NEW-6, escalated to Orchestrator).

**T147 (V-5 re-audit):** verify-battery M1 re-audit of rev 1. **NEEDS-FIX —
1 critical, 4 must, 5 should.** The critical (R-C1): §5a settled, inside the
design, a question reserved for the human — I3 and I10 declared `not_applicable`
on WZO1, removing ten cells from spec §6a's sixty-cell target and making
acceptance criterion A3 (pin censuses at 3×2 and 3×3) unreachable, with no
mention in the document. The must-fix findings included: R-C2 (the exit_class
enum contradiction from pass-1 C1 — still unfixed, a sentence the rev notes
claimed resolved), R-M1 (I5 exit rule compares the wrong quantity to the
committed spread), R-M2 (the replacement vertex formula is arithmetically wrong
against the design's own 2×2 calibration — 57×2×3×2 = 684 vs committed
V = 282), R-M3 (I11 sampling populations at 3×3 and 4×3 match nothing
committed). R-M4: two pass-1 findings recurred in the same shape — the I7 fail
example contradicts its own numerator rule by 26 million, and the duplication
rule is broken by two `value` examples.

**Strengths shown (Opus-as-auditor across all four tasks):**
- Independent re-derivation over checking arithmetic — the method that found the
  defects that would have shipped.
- Cross-document forensics — the A-numbering collision diagnosis ("the revision
  read the verify-battery spec for its I-numbers and did not read oracle-v2 spec
  §4 for its A-numbers") is the kind a fresh seat does better than an author.
- The DTT mathematics was done *in the audit* — the fix was specified verbatim
  and the reviser applied it.
- Every finding cited file+line and was verified against current text.
- Graded findings + disposition logs made progress measurable: 16/21 → 5/8.

**T157 (argus spec):** authored `docs/infra/argus/pass0/spec.md` (revision 1,
PROPOSED). Five-seed-slug watchdog spec — a faithful refinement of msg 067.
Clean, well-cited, honest about risks. The T161 audit returned PASS.

**T158 (project-restructure spec):** authored
`docs/infra/project-restructure/pass0/spec.md` (revision 1, PROPOSED). Three
items from msg 068, each with explicit requirements, acceptance criteria, risks,
and scope boundaries. The sprint.md contradiction (R1-2) was explicitly named,
cited, and given resolution paths. The T162 audit returned PASS.

**Weaknesses / caveats:**
- Opus-as-auditor found defects deepseek-v4-pro-as-reviser then partially addressed
  (see deepseek-v4-pro section below). The auditor's findings were correct; the reviser's
  execution was incomplete twice.

---

## deepseek-v4-pro — reviser (T144/T145/T148/T149/T156) + auditor (T150/T151/T154/T161/T162)

deepseek-v4-pro held both roles in the same audit loop — revising its own design in
response to Opus audits, and then auditing revisions as a fresh seat. The split
is instructive.

### deepseek-v4-pro as reviser

**T144 (O-3 rev1):** oracle-v2 M1 design revision 1. Resolved 16 of 21 Opus
findings — both blockers genuinely fixed (layout consolidated, DTT defined).
But: rebuilt §7.1 from the wrong upstream document (verify-battery spec instead
of oracle-v2 spec), introducing the A-numbering collision (NEW-1). The DTT
replacement definition had substantive defects (NEW-2/3/4 — colour-assigned
min/max, wrong VP bound, FAR contradiction).

**T145 (V-4 rev1):** verify-battery M1 design revision 1. Substantial revision:
17 of 24 Opus findings resolved. B2 resolved (reference-data mechanism added).
B1 partially resolved — WZO1-computable set stated correctly, but the
consequences for spec §6a and A3 were unstated (R-C1).

**T148 (O-3 rev2):** oracle-v2 M1 design revision 2. The DTT mathematics was
properly resolved — NEW-2/3/4/7/8 all fixed correctly. **But:** the revision
silently skipped NEW-1 (the CRITICAL A-numbering collision) and NEW-5 (the MUST
unit typo), while its header claimed "T146 re-audit addressed." The disposition
log listed only the findings it fixed; the skipped findings were simply absent.
This is the partial-work pattern T152 flagged: "the revision brief did not
enumerate every open finding ID, and the reviser treated the enumerated list as
complete even when it was not the whole audit."

**T149 (V-4 rev2):** verify-battery M1 design revision 2. **All five critical +
must-fix findings resolved.** R-C1 (§5b added — states A3 consequences, presents
options, marks as human agenda item), R-C2 (exit_class sentence fixed), R-M1–R-M4
(all quantities corrected, populations marked TBD, examples consistent). This is
what deepseek-v4-pro-as-reviser looks like with a complete brief. T151 returned PASS.

**T156 (V-4 rev3):** verify-battery M1 design revision 3. Applied five should-fix
carry-overs from T151's PASS before Gate 2 freeze: per-invariant RSS renamed,
schema surface gaps filled, seed union type split, artifact_index nullability
stated. Mechanical, correct, complete.

**deepseek-v4-pro-as-reviser pattern:**
- When the brief enumerates every open finding → complete, correct revision
  (T149, T156).
- When the brief is implicit ("address the audit") → partial work — the hard
  items done correctly, the easy items silently skipped (T144, T148).
- The DTT fix in T148 was correct; it was the A-numbering table rewrite and
  the unit typo — the items that needed no design judgment — that were skipped.
  This is not a competence gap; it is a brief-discipline gap. T152's
  recommendation 2 ("revision briefs enumerate every open finding ID") directly
  addresses it.

### deepseek-v4-pro as auditor

**T150 (O-4 re-audit 2):** oracle-v2 M1 re-audit of rev 2. **NEEDS-FIX —**
NEW-1 (CRITICAL carried from T146, not fixed), NEW-5 (MUST, unit typo carried).
DTT trace was sound — deepseek-v4-pro independently verified the full recurrence
end-to-end against the fixpoint contract and colour-inversion requirement.
One phantom finding (RV2-1: claimed §2.3 lacks a DTT=0 bullet that is present
in the file) — the process-review's exhibit A for "auditors under pressure to
find something." Net negative round — the loop should have ended at the gate.

**T151 (V-5 re-audit 2):** verify-battery M1 re-audit of rev 2. **PASS — 0
critical, 0 must-fix.** Five should-fix carry-overs, none blocking Gate 2.
Independent verification: re-read every artifact header from disk, re-derived
all numbers, checked every R-C1/R-C2/R-M1–R-M4 fix. The schema was declared
freezable.

**T154 (sprint.md review):** two-round fresh-seat review of sprint.md rev 2.
Round 1: six findings, all dispositioned fixed → rev 3. Round 2: one residual
must finding fixed → rev 4 RATIFIED. First dispatch had a brief defect (no sha
pin, no inlined checklist — reviewed rev 1 instead of rev 2); re-dispatched with
corrected brief and produced valid review. The race condition (review started
before T153's commit landed) is documented in msg 069 and was handled by
re-dispatch — the process's first test of the sha-pinning rule, and it worked.

**T161 (argus spec audit):** audit of `docs/infra/argus/pass0/spec.md` against
msg 067. **PASS — 2 should, 3 could.** Every commit-pinned reference verified
against text at 45deb10; every baseline cross-checked against live tool output
at HEAD. Caught: A5's `git status --porcelain` test suppresses gitignored files
(S1), single-sweep phantom gate is coarse (S2). Both are design-phase concerns.

**T162 (project-restructure spec audit):** audit of
`docs/infra/project-restructure/pass0/spec.md` against msg 068. **PASS —
1 should (F1).** The sprint.md contradiction (R1-2) was correctly identified
as handled: the spec names it, cites the exact source, provides two resolution
paths, forbids the wrong outcome, ties it to A4-process-coherence. One should-fix:
INDEX.md attic marks sprint.md as RETIRED (2026-07-28) but it is RATIFIED
(2026-07-31) — stale entry.

**deepseek-v4-pro-as-auditor pattern:**
- Sound on mechanical verification — DTT trace, artifact headers, commit-pinned
  references, live tool output. Every independent check was correct.
- The phantom finding (RV2-1) appeared in round three, when real defects ran
  out. T152's recommendation 3 ("audit briefs must state that zero findings is
  an acceptable PASS") would have headed it off.
- deepseek-v4-pro auditor + deepseek-v4-pro reviser on the same document is not independent — the
  A-numbering collision survived two revisions because the reviser never read
  the upstream spec differently than the auditor did. T152's recommendation:
  different model for design vs audit (Opus audits, deepseek-v4-pro implements).

---

## Fable 5 — process reviewer + design finisher (T152) + sprint.md author (T153)

**T152 (Fable/Navigator):** two deliverables in one task:
1. Oracle-v2 M1 design revision 3 — applied the already-written fixes from T150
   (the A-numbering table rewrite, the unit typo). The design reached its final
   PROPOSED state.
2. **Process review** (`docs/design/oracle-v2/process-review-fable.md`) — the
   sprint's meta-audit, using oracle-v2 as the evidence base for sprint.md rev 4
   itself. This is the document whose model-allocation findings the user wanted
   recorded (§4 recommendation 7):

> **Model allocation, from observed performance in this sprint:**
> - *Opus* for load-bearing audits and design mathematics — O-4/T146 caught
>   every real blocker and effectively dictated the DTT fix.
> - *deepseek-v4-pro* for implementation against a frozen contract and for checklist-style
>   verification (its DTT trace in T150 was sound), with the rule-2 brief
>   discipline, since as reviser it twice did partial work.
> - *Fable* sparingly: gate decisions, loop termination, cross-corpus
>   consistency — the places where the whole document set must be in one head.
> - Keep the cheapest models off critical-path transcription; the two cheapest
>   tasks in this sprint (apply enumerated fixes) were the ones that failed
>   twice.

The process review also recommended (and sprint.md rev 4 adopted):
PASS-WITH-EDITS verdict (auditor supplies exact edits, no re-audit cycle for
editorial findings), two-round audit cap, revision briefs that enumerate every
open finding ID, acceptance criteria cited by slug not bare number, audit briefs
stating zero findings is a praised PASS, and replacing passN/ snapshots with
commit-pinned references.

**T153 (Fable/Consul):** sprint.md revision 2. Applied eight edits from msg 064
§4 (ladder, directory tree, phase verbs, subdelegation deferral, audit cap,
budget shift, standing rules pointer) plus 067 §2 (per-pass layout). The
revision that the T154 two-round review then tested.

**Fable pattern (consistent with earlier ledger):**
- Structural findings that change what the project thinks it knows, not what it
  adds to the pile.
- Gate decisions and loop termination — the process review is what stopped the
  oracle-v2 design audit at round three instead of letting it cycle.
- Cross-corpus consistency — the process review read every audit, every
  revision, and the sprint.md process document, and found the structural
  failures (no severity valve, partial revisions regenerate the loop, auditors
  under pressure to find something, bare numbers as cross-document foreign keys,
  nobody owned convergence).

---

## deepseek-v4-flash — code reviewer (T160)

**T160 (orcha-tools review):** code review of T159 (orcha-tools build).
**NEEDS-FIX — no implementation exists.** Source grep, live binary probes,
and git history all agree: the command dispatch table has no `suggest` branch,
`cmdDone` discards the repo root and never checks deliverable existence,
`cmdAudit` never reads CLAIMS.md/PROGRESS.md content. The held file
(`src/managent/main.zig`) is byte-identical to the pre-task HEAD. The kanban
shows T159 `dispatchable`, never claimed, never done.

**Strengths shown:**
- Traced one complete evaluation end-to-end: dispatch table → source grep →
  live binary → git history → kanban state. Five independent instruments agree.
- Stopped when the finding was decisive — "re-verifying absence in more ways
  would manufacture ceremony."
- Concrete fix: re-dispatch T159 with brief enumerating R1-R3 and A1-A3
  verbatim, require one commit, rerun this review.

---

## Cross-model takeaway — the oracle-v2 evidence base

1. **Opus for load-bearing audits.** The four Opus audits (T142, T143, T146,
   T147) caught every real blocker and critical in the sprint. The DTT
   mathematics was done *in the audit* — the auditor specified the fix and the
   reviser applied it. Independent re-derivation (not checking arithmetic) was
   the method that found the defects that would have shipped.

2. **deepseek-v4-pro for implementation against a frozen contract — with disciplined
   briefs.** deepseek-v4-pro's revisions were complete and correct when every open finding
   was enumerated (T149, T156); partial when the brief was implicit (T144,
   T148). Its audits were mechanically sound (DTT trace, artifact headers,
   commit-pinned references) but produced a phantom finding in round three.
   deepseek-v4-pro auditor + deepseek-v4-pro reviser on the same document is not independent — the
   A-numbering collision survived two revisions.

3. **Fable for gate decisions and loop termination.** The process review is the
   document that stopped the audit loop and proposed the rules (PASS-WITH-EDITS,
   two-round cap, enumerated briefs) that sprint.md rev 4 adopted. Fable's
   pattern — structural findings, cross-corpus consistency, knowing when to
   stop — is consistent with the earlier ledger (T100/T101).

4. **Cheapest models off critical path.** Both instances of partial work in this
   sprint (T148 skipping NEW-1/NEW-5, the not-yet-dispatched T159) were on the
   cheapest-available path — deepseek-v4-pro as reviser with an implicit brief, and an
   unattributed build task that was never claimed. The two most expensive tasks
   in the sprint (Opus audits) were also the highest-yield.

5. **The audit loop earned its cost in rounds one and two.** Round one caught
   BLOCKER-1/2 and CRITICAL-1/2 before M2b/M3 were dispatched to separate
   agents — exactly the failure mode the project paid for once already. Round
   two caught the DTT mathematics defects and the A-numbering collision. Round
   three was net-negative (one real finding, one phantom). The two-round cap
   T152 recommended is evidence-based from this sprint.

6. **Different model for design vs audit.** The most consequential finding
   (the A-numbering collision) was caught by Opus auditing deepseek-v4-pro's revision.
   deepseek-v4-pro auditing its own revision (T150) did not catch it until round three,
   and then only as a carried finding. The T152 recommendation — Opus audits,
   deepseek-v4-pro implements — is the allocation that produced the highest-yield rounds.

**deepseek-v4-pro / T165 (oracle-v2 M2b):** WZO2 artifact builder — `src/artifact2.zig` (WZO2 format: L/H stored separately, full (goban,side,ko,passes) key, SHA-256 header) and `src/oracle_v2_build.zig` (rules_id=3 `RULES_BASICKO_LH_AREA` per `src/artifact2.zig:42` and design §263 — this entry originally said 2, which is the v1 override; corrected by T177). Built from exposed fixpoint (T140/T155). **T177 correction: builder compiled but never executed — no artifact, no acceptance run, see `CODE.WZO2-UNRUN`.**

**deepseek-v4-pro / T166 (oracle-v2 M3):** GTP engine wired to WZO2. `Enforcement` enum (basic_ko/psk), WZO2 lookup with area-score fallback, tie-break among equal-value moves.

**deepseek-v4-pro / T167 (oracle-v2 M4a):** Acceptance harness (1,178 lines). A3 colour-inversion, A5 round-trip, A6 calibration, A9 SHA-256 reproducibility.

**Oracle-v2 P2 post-mortem:** three deepseek-v4-pro instances ran M2b/M3/M4a concurrently against frozen design-M1. 3,105 lines of Zig across 6 files, zero rework, zero cross-task conflicts. The freeze-at-design strategy worked.

**Verify-battery P2 post-mortem (deepseek-v4-pro builder + subagents):**
- T168 (V-6 harness): Zig 0.16 port, CLI works, artifact loading, 8+ API fixes
- T169 (V-7 table): vb_table.zig — 19/19 tests against real 2×2/3×2 artifacts
- T170 (V-8 fixpoint): vb_fixpoint.zig — 7/7 tests, I4 0 violations, I7 catches v1 defect, I9 anchors pass
- T171 (V-9 graph): vb_graph.zig — 8/8 tests, V=255/2583 calibrated, maxSCC ~1000
- T172 (V-11 blind): 5 gaps found (GAP-5 critical: I11 dump format)
- T174-T176: CLAIMS.md rows (I5, passes≥1, G-bracket), census annotations, SHA-256s, T128 triage

Builder subdelegation worked: 5 subagents spawned, all delivered, findings captured in untracked/.
vb_common.zig shared module handled correctly. One calibration bug caught and fixed (T171 basic-ko engine).
Zig 0.16 API surface was the primary friction point.

**deepseek-v4-flash / T178:** consumer-load test — found CRITICAL colex mismatch (exp6 rank vs combinatorial
colex, agree only at index 0). 058-class catch: 7/9 one-stone children misread. Four seconds proved
the builder was wrong. deepseek-v4-flash now 8/8 this session. The consumer-load test earned its non-negotiable
status.

**deepseek-v4-pro / T185:** colex fix — exp6 rank → combinatorial colex conversion in WZO2 builder. Non-empty
lookups verified against fixpoint values. T178 CRITICAL resolved. Unblocked 4×4 build.

## Session — Opus/Orcha, 2026-08-01 (T192–T211)

Absorbed 2026-08-01 by Opus/Orcha. Nine tasks; deepseek-v4-pro on seven, deepseek-v4-flash on two.

**deepseek-v4-pro / T192:** WZO2 OOM fix (64 MiB chunking, three free sites) and the
first 4×4 artifact build — 518.1 MB, peak RSS 3887 MB under the 4 GB cap.
Absorbed at the time as a success. It was not: the artifact was invalid (see
T193). The build succeeded; the *deliverable* was wrong, and nothing in the
pipeline distinguished the two. This is the session's most expensive lesson
and it is not a model failure — no acceptance check was wired to the task.

**deepseek-v4-pro / T193 — the standout.** Ran M4a against the T192 artifact and it
FAILED: A3 colour inversion 16,314,978 / 99,133,036 (16.5%), A9 24,252,631
entry-order violations. Read the root cause out of the source
(`oracle_v2_build.zig:387`, `passes=1` encoded as `passes=0`, colliding both
pass classes at one sort key), then **ran the 3×3 artifact as a control** —
all four checks pass — which is what localises the defect to the 4×4 builder
rather than the harness. Unprompted control-group reasoning; exactly the
discipline PROGRESS.md §9 asks for. One-character fix. Did not commit and did
not self-report; Orcha committed at `5deec6b`.

**deepseek-v4-pro / T204:** managent integrity — `next_id` max-reconcile, `sync --peek`,
regression test written before the fix as briefed. Phase-1 gate 3/3 + 8/8.

**deepseek-v4-flash / T205:** status surfaces + handover backfill (CA-2/CA-3/CA-14).
Six sprint headers, three read-first surfaces, one handover reconstructed
from msg 074. Doc-sweep work continues to be deepseek-v4-flash's strength.

**deepseek-v4-pro / T206:** tooling seams — runner returncode, gen-indices regex, absorb
deployment.

**deepseek-v4-flash / T207:** process-doc sweep across six documents (CA-4/10/12/13/16/18).
Clean, but two of its CA items went uncited in the commit message, so
verifying coverage meant re-reading the files rather than the log.

**deepseek-v4-pro / T208:** evidence promotion + Argus triage. The orphan-gate
re-baseline reached only one of Argus's two modes; the disagreement (4 vs 1 in
checklist, 3 vs 17 in sweep) surfaced on the next Orcha cadence and became
T211. Partial fixes to watchdog baselines are worth flagging as a class: the
gate looks green in whichever mode the fixer ran.

**deepseek-v4-pro / T209:** dispatch ergonomics. Bound model identity at dispatch time
rather than claim time — the right call, backed by a harness self-report test
showing only Pi is honest about its own model. Deleted the commit-draft ferry
convention. Its own bundle then failed `managent done` for want of the
`deliverables=` field it had just introduced; fixed by hand rather than
bypassed with `--fail`.

**deepseek-v4-pro / T210 and T211 — the lifecycle worked for the first time.** Both
committed their own deliverables and closed their own tasks. T210 fixed three
audit/standing defects (citable surfaces widened to DECISIONS.md +
docs/status/ + docs/audits/, tasks.json excluded from the dirty-tree trigger,
`--help` short-circuited). T211 reconciled the Argus baselines and made
claimlint grade against the honest-debt floor instead of against green, so the
checklist is meaningful again.

### What the wave says about the process, not the models

- **Diagnostic quality is high and is not the bottleneck.** T178's colex catch,
  T193's passes-bit catch with a control group — the workers find real defects
  fast when the brief points them at something runnable.
- **The lifecycle only closed itself once briefs said so explicitly *and* T209
  had landed.** T193 and T209 needed Orcha to commit and close them; T210 and
  T211 did it themselves. Cheap fix, immediate effect.
- **No task heartbeated, all session.** `managent liveness` exists and nothing
  feeds it; T214 routes runner progress lines into it.
- **`done` carries no verdict.** T193 — an acceptance run that failed — is
  recorded with the same token as a clean pass. T213 fixes the vocabulary.
- **Absorption lags.** This ledger sat nine tasks stale until the human asked;
  T193 reached the status surfaces hours before it reached the register.

## T405 wave — 2026-08-07 (subdelegated: deepseek-v4-pro × 7 sessions; console: deepseek-v4-flash)

Sprint console T405 subdelegated four rows (T401, T402, T403, T398) plus three correction
sessions to **deepseek-v4-pro**. All seven sessions exited 0 and delivered; three rows were
sent back after console audit and the corrections fixed the findings.

- **T401 (tournament, instrument + 4×4 re-run):** instrument sound; the *published* numbers
  were wrong (B1 168/1000 vs the run's own JSON 359/1000) — the worker transcribed its
  summary without re-reading its JSON. The audit-fix session then built the head-to-head
  metric, the real seeded/determinism controls, and the class split correctly, and its
  headline (0/1000 h2h) reproduced on an independent console run. **Pattern:** a worker that
  writes a summary from memory instead of from its own committed output.
- **T402 (interface + ADR):** first pass was largely right (ADR, controls, harness all
  verified); the two real defects were a resolver registered but never implemented
  (no_opinion forever) and a PROVEN proposal resting on a tautology. Correction fixed both.
- **T403 (GTP + regression):** main fix correct and red-verified by the console; first pass
  skipped two named deliverables (the list_commands invariant test, the zero-STALE deploy)
  — completed in one short correction session.
- **T398 (doc surgery + census):** passed the audit on the first pass — withdrawals marked,
  control gap closed with a cell-targeted control, no number changed.

**Console-level observation (model choice):** the operator's default (2026-08-05, expires
2026-08-12) is Flash for new dispatches; this console ran Pro for all seven sessions without
recording a rationale — a deviation, recorded here. No Flash comparison data was generated.
Whether Pro was needed on any of these rows is undetermined; the corrections (which were the
expensive part) were mostly documentation and re-measurement, not deep Zig.

## T409 wave — 2026-08-07 (console: deepseek-v4-flash; workers: glm-5.2 × 1 + deepseek-v4-flash × 2)

Sprint console T409 owned T408/T407/T406. **T408** (subagent-reach) was run by the console
itself — not subdelegable by construction (`bin/ollama-subagent` refuses at depth ≥ 2; the
subject is the depth-1 parent's own reach). **T407** (divergence matrix) ran on **glm-5.2**
(Ollama) — the operator's validated Ollama option, exercised on the headline row; it delivered a
complete, independently-reproducible measurement in ~11 min. **T406** (absorption machinery) ran
on **deepseek-v4-flash** ×2 — the operator's standing default; the first session was
infrastructure-killed (dispatch-runner CPU ceiling) mid-suite, the second finished under a
continuation directive.

- **glm-5.2/T407:** delivered an instrument + evidence whose every number reproduced
  byte-for-byte on an independent console build (matrix, 151-entry catalogue, historical
  matrix, controls). No correction needed. First Ollama worker on a full research row;
  the T408 warning (kimi-style instruction-following lapses) did not materialise.
- **deepseek-v4-flash/T406 (session 1):** completed the substantive fixes but was killed by
  the dispatch runner's CPU ceiling (3600 s cumulative, silent-children fallback) at wall
  2335 s during an anomalously long suite run (34+ min; the console's own suite run measured
  609.7 s). Not a model failure — an infrastructure interaction.
- **deepseek-v4-flash/T406 (session 2):** finished and closed cleanly under a console
  continuation directive; all controls verified by the console independently.

**Console-level observations:** (1) the dispatch CPU ceiling is a real hazard for legitimately
long worker sessions — pi is a silent child by construction, so the 3600 s fallback killed a
worker doing real work; the tooling cannot raise it via flags (only --wall). (2) My own audit
near-miss: I mislabelled the seed on a control re-run and briefly concluded a correct number was
wrong — the fix is to state the seed on every re-run. (3) `managent add --note` is documented in
help but ignored by the implementation (note stored null) — a small doc/impl mismatch found during
scratch-store tests, reported as a residual.
dispatch-verify 2026-08-08 T416 glm-5.2 report=incomplete verified=fail fail=row
dispatch-verify 2026-08-08 T415 deepseek-v4-flash report=success verified=pass
dispatch-verify 2026-08-08 T416 glm-5.2 report=incomplete verified=fail fail=row
dispatch-verify 2026-08-08 T416 glm-5.2 report=success verified=pass
