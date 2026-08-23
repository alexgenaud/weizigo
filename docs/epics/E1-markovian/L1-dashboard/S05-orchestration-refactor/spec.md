# S05 — spec: orchestration refactor (one policy file, one dashboard, one arbiter)

**Artifact type: SPEC** (`docs/infra/sprint.md` — a spec says what we want, testably, for one
pass). **Owner:** deepseek-v4-pro/T748 · **Date:** 2026-08-23 · **Status:** PROPOSED (rev 1, for
operator ratification) — audited before anything is built. Not a worker brief, not a plan, no
code.

**Sits on:** the ratified seed (`docs/status/orchestration-refactor-seed-2026-08-23.md` — its
eight rulings are DECIDED, this spec does not reopen them), the existing tools it migrates
(`tools/fleet-keeper.sh`, `tools/window_policy.py`, `tools/directive_policy.py`, `bin/dispatch`,
`bin/subagent`, `untracked/watch-fleet.sh`), `docs/status/orchestration-layer-spec.md` §7c
(rulings in force), `docs/infra/sprint.md` (pass protocol + audit loop),
`docs/infra/model-registry.md` (the one short-name table), `S04-orchestrator-retirement/spec.md`
(its reconciler scope is absorbed here per the seed's feedstock list),
`S05-startup-surfaces/spec.md` (the `orient` sprint, whose startup-prose diet ruling 7 builds on).

**Inputs.** seed §1–§8 + Acceptance + Feedstock + Out-of-scope · `orchestration-layer-spec.md`
§7c.11–34 · `model-registry.md` (short-name table, T732 ox-alpha baseline) · T712/T713/T709/T578
bundles (feedstock rows) · T747 (landmark gate) · T738/T739 (dashboard trim precedent).

**One line.** One policy file every reader reads, one dashboard every human reads, one arbiter
every runner defers to: the fleet's spread-out policy, display, and pressure logic collapses into
`managent` (Zig, the single reader of store + policy), and a new model arrives by editing one
registry entry instead of four files.

**Citation pins.** Every `file:line` in this document is against `HEAD` at authoring time, commit
`a1415fe` (2026-08-23). References to other spec documents are by **§ref**; each §ref is tagged
with its document's rev/pin where load-bearing. A citation that no longer resolves at `a1415fe`
is a spec defect, not a reader's problem.

**Naming note (flag, not a ruling — operator owns the number).** The deliverable path uses the
sprint number `S05`, which already names the `S05-startup-surfaces` sprint (T583, `orient
--role`). The two are distinct sprints with a one-way relationship (this sprint's ruling 7 builds
on `orient`; it does not re-spec it). Recommendation: renumber this sprint `S06` (or fold
`startup-surfaces` under it as a lane) at ratification; the path is left as specified so the
`managent done` deliverable check holds. This is a naming decision, recorded here rather than
made silently.

---

## 0. How to read this document

Every normative statement carries an id (`ORC-*`). §9 is the control table: the seed's named
controls are the **mandatory core**; the test phase writes one seeded arm (flip) and one null arm
(green) for **every** normative id before the first live reading. An id with no control is not a
requirement, it is a wish (the standing rule: *an instrument earns its first reading only after
a null control and a seeded-defect control*).

Where a ruling underdetermines a design choice, this spec states the **options** and a
**recommendation**, and marks it `[design-open]` — the design phase may choose *only among the
listed options* without re-ratification; choosing anything else is a plan amendment. Decided
rulings are never reopened here.

The migration surface (§8) is **counted, not asserted**: 5 named tools + **75** `tools/
regression-*.sh` scripts at `HEAD`. (The brief names "74"; the delta is
`regression-window-resilience.sh`, added by T736 at `11b69b8`. The count below sums to 75 — a
script left uncounted is a silent truncation and a spec defect.)

---

## 1. Goal and scope

**ORC-GOAL-1 (the goal).** The fleet's orchestration state lives in **one policy file** (ruling
1), its human surface is **one dashboard** in `bin/managent` (ruling 3), its pressure response is
**one arbiter** (ruling 4), its rows register through **one file-first contract** (ruling 5), its
pauses **expire loudly** (ruling 2), its gates are **data, not prose** (ruling 6), its startup
prose is **`orient` only** (ruling 7), and its models are **registry entries** (ruling 8).
End state: the operator sees one pane, dispatches one command, and onboards a model by editing
one file.

**ORC-GOAL-2 (the scope number — what this sprint replaces).** The refactor collapses, at
`HEAD`:

| today | lines | role | goes to |
|---|---|---|---|
| `tools/fleet-keeper.sh` | 1169 | dispatch loop + cooldown flags + one-writer invariant + appetite/cap enforcement | `managent` arbiter + policy reader |
| `tools/window_policy.py` | 737 | reset watcher + token meter + fan-out cap | policy file + `managent` arbiter |
| `tools/directive_policy.py` | 176 | directive staleness + discharge | policy file (expiring pauses) + `managent` |
| `bin/dispatch` | 536 | dispatch gate + canonicalization | policy reader; gate logic moves to `managent` |
| `bin/subagent` | 557 | launch chokepoint + provider selection | provider seam (registry entries) |
| `untracked/watch-fleet.sh` | 304 | dashboard | thin refresh wrapper; rendering moves to `managent` |

Six files, **3479 lines**, reduced to one policy file + one registry + `managent` surface. The
number is stated so the "did we actually shrink it" question is answerable at accept.

**ORC-GOAL-3 (what is out, named — seed "Explicitly out of scope").** claimlint and the science
suite (separate ledger tooling); the history squash (T535, its own spec-first console); race
machinery beyond what the policy file touches. Also out: `tools/runner` itself is **not
rewritten** — it survives as the launch/guard layer; its interaction with the arbiter changes
(§8, REWIRE disposition), its internals do not.

**ORC-GOAL-4 (the reconciler absorption — stated, with the one fold-point flagged).** The seed's
feedstock list names T578 ("this sprint absorbs its reconciler scope, operator-ratified
direction"). Consequence: the **arbiter is the deterministic pre-pass** that S04's
`REC-LIFE-2` was going to build — it applies every (a)/(b) mechanism before any model token is
spent, and a quiet store is a zero-token wake. What is **not** absorbed here is the model-spawn
residue (S04 `REC-LIFE-1`, the verdict/triage reconciler that wakes on a non-empty residue).
That boundary is `[design-open]` (§7 open question 1) because the seed's two statements — "one
arbiter" (ruling 4) and "absorbs its reconciler scope" (feedstock) — do not by themselves say
whether the model-spawn folds into this sprint's build or becomes a successor row. The spec
**recommends**: ship the arbiter pre-pass first (its zero-token wake is the measurable win and
the L1 bar's engine), then the model-spawn as a successor row gated on the arbiter holding its
first live day — because a model-spawn built on an unshipped pre-pass is the exact
"sound-by-construction without an auditor run" trap the foreclosures name.

---

## 2. The one policy file (ruling 1)

**ORC-POL-1 (one file, all readers).** A single policy file holds: per-family appetite, caps,
allow/deny lists, cooldowns, and window budgets. `bin/dispatch`, `bin/subagent`, and the keeper
(→ arbiter) read it; **env vars become overrides only** (they never invent a default the file
does not state). The kill: the D036 deny default and the 5M invented window budget (T736
recalibrated) die because there is no unstated default left to hide in.

**ORC-POL-2 (every entry carries owner, reason, expiry).** Every entry in the file is a record
`{value, owner, reason, expiry}`. An entry with no owner/reason is refused at parse time (it is
an invisible default wearing a config costume). `expiry` is `null` (standing), an ISO instant
(one-shot), or a named condition (e.g. `"next-ollama-quota-refresh"` — resolved by the arbiter,
re-evaluated at every read, the `directive_policy.py` discharge-by-condition lesson).

**ORC-POL-3 (appetite is per-model, 0–9 — §7c.11, not re-spec'd).** The dial is per model short
name; family setting is bulk convenience. The §7c.11 initial values are the file's seed rows; the
§7c.11 mechanics (0 = unliftable hard forbid, monotone back-pressure, max = no back-pressure,
operator-only raise, auto may only reduce) carry over unchanged. The §7c.12 "can vs should"
separation is preserved: appetite records *can use* only.

**ORC-POL-4 (the three cooldown mechanisms merge — ruling 6).** heal (T504), dispatch (T536),
and window (T628/T677) cooldowns become **one visible state machine** in the policy file, with
one namespace and one dashboard row each. The merge is a *schema* fact, not a behaviour change:
each cooldown's arithmetic survives as a named state of the machine. (§6 specifies the states.)

**ORC-POL-5 (schema — worked example, the full file).** The file is JSON (the project's
store convention), at `docs/infra/orchestration-policy.json` (committed, diff-reviewed — it is
the gate-as-data artifact, so it lives in git, not `untracked/`). Runtime *state* (who is cooled
down *right now*) stays in the store/run-records, never in the policy file — the file is the
**parameters**, the store is the **fact**.

```json
{
  "schema_version": 1,
  "note": "Every entry carries owner, reason, expiry. Env vars override only; nothing here is a hidden default.",
  "appetite": [
    {"model": "dspro",   "dial": 6, "owner": "operator", "reason": "initial, 2026-08-22 (§7c.11)", "expiry": null},
    {"model": "dsflash", "dial": 6, "owner": "operator", "reason": "initial, 2026-08-22 (§7c.11)", "expiry": null},
    {"model": "sonnet",  "dial": 6, "owner": "operator", "reason": "initial, 2026-08-22 (§7c.11)", "expiry": null},
    {"model": "haiku",   "dial": 6, "owner": "operator", "reason": "initial, 2026-08-22 (§7c.11)", "expiry": null},
    {"model": "opus",    "dial": 4, "owner": "operator", "reason": "initial, 2026-08-22 (§7c.11)", "expiry": null},
    {"model": "qwen",    "dial": 4, "owner": "operator", "reason": "initial, 2026-08-22 (§7c.11)", "expiry": null},
    {"model": "fable",   "dial": 2, "owner": "operator", "reason": "reserve for when Fable is most appropriate AND needed", "expiry": null},
    {"model": "glm",     "dial": 0, "owner": "operator", "reason": "ollama weekly quota exhausted (D036)", "expiry": "next-ollama-quota-refresh"},
    {"model": "minimax", "dial": 0, "owner": "operator", "reason": "ollama weekly quota exhausted (D036)", "expiry": "next-ollama-quota-refresh"},
    {"model": "kimi",    "dial": 0, "owner": "operator", "reason": "ollama weekly quota exhausted (D036)", "expiry": "next-ollama-quota-refresh"},
    {"model": "oxalpha", "dial": -1, "owner": "T732", "reason": "RESERVED — identity sealed, never auto-drawn", "expiry": null}
  ],
  "caps": [
    {"family": "claude", "fan_out": 3, "owner": "operator", "reason": "§7c.33 one race's lanes, never two races", "expiry": null},
    {"family": "fable",  "fan_out": 1, "owner": "operator", "reason": "RESERVED lane runs alone or not at all (§7c.33)", "expiry": null},
    {"family": "deepseek", "fan_out": 6, "owner": "operator", "reason": "§7c.15 provisional lane_cap", "expiry": null},
    {"family": "ollama-cloud", "fan_out": 5, "owner": "operator", "reason": "§7c.15 provisional lane_cap", "expiry": null},
    {"family": "local", "fan_out": 1, "owner": "operator", "reason": "§7c.15 provisional lane_cap", "expiry": null}
  ],
  "allow_deny": {
    "deny": [
      {"model": "glm-5.2",     "owner": "operator", "reason": "D036 ollama weekly quota (model-level)", "expiry": "next-ollama-quota-refresh"},
      {"model": "minimax-m3",  "owner": "operator", "reason": "D036 ollama weekly quota (model-level)", "expiry": "next-ollama-quota-refresh"},
      {"model": "kimi-k2.7",   "owner": "operator", "reason": "D036 ollama weekly quota (model-level)", "expiry": "next-ollama-quota-refresh"}
    ],
    "allow": []
  },
  "cooldowns": {
    "heal":     {"seconds": 600,  "owner": "T504", "reason": "recently-healed rows need investigation, not re-fire", "expiry": null},
    "dispatch": {"seconds": 300,  "owner": "T536", "reason": "pre-claim-death rate limiter", "expiry": null},
    "window_fallback": {"seconds": 1800, "owner": "T677", "reason": "unparseable provider reset — short, death-anchored horizon", "expiry": null},
    "probe_window": {"seconds": 1800, "owner": "T677", "reason": "post-reset one-lane probe", "expiry": null},
    "bench_retry": {"seconds": 1800, "owner": "T536", "reason": "benched model re-probe interval", "expiry": null},
    "failure_trip": {"count": 3, "owner": "T536", "reason": "consecutive pre-claim deaths bench a model", "expiry": null},
    "stale_directive_hours": {"hours": 24, "owner": "T625", "reason": "unacked unconditional pause older than this is reported stale", "expiry": null}
  },
  "window_budgets": [
    {"family": "claude", "tokens": 35000000, "window_s": 18000, "owner": "T736", "reason": "measured ~38M/5h, 35M keeps margin", "expiry": null},
    {"family": "deepseek", "tokens": null, "window_s": null, "owner": "operator", "reason": "no five-hour limit (§7c.25); meter still counts for the record", "expiry": null}
  ],
  "pause_default": {"max_seconds": 18000, "owner": "operator", "reason": "ruling 2: 5-hour default maximum unless explicitly longer", "expiry": null}
}
```

**ORC-POL-6 (dial -1 = RESERVED, not an appetite value).** `oxalpha` carries `-1` because
RESERVED is a §7c.12 "should" fact (identity sealed, operator-only stealth-test), not a "can"
dial. The parser accepts exactly `0–9` plus the reserved sentinel; anything else is a parse
error. (The `-1` encoding is `[design-open]` — options: `-1` sentinel vs an explicit
`"appetite": "RESERVED"` string field; recommendation: the explicit string, since a negative
dial reads as an off-by-one bug. The worked example uses `-1` to match the current
`FLEET_APPETITE` surface; design may switch to the string form without re-ratification.)

**ORC-POL-7 (env vars are overrides, and overrides are recorded).** The existing knobs
(`FLEET_MODEL_ALLOW/DENY`, `FLEET_APPETITE`, `FLEET_FAMILY_CAP`, `WEIZIGO_WINDOW_BUDGET_*`,
`WEIZIGO_DIRECTIVE_STALE_HOURS`) keep working **as overrides of a file entry**, and an override
is appended to `untracked/fleet-window-overrides.jsonl` with the reason it was needed (the T677
override-recording precedent, generalized). A knob with no corresponding file entry is refused
with "add it to the policy file or it is not a knob" — the D036/T736 silent-default class dies
here.

---

## 3. Expiring pauses (ruling 2)

**ORC-PAUSE-1 (scoped, expiring, re-asserted).** A pause is scoped per family (never a silent
global), has a **5-hour default maximum** unless an explicit longer expiry is stated, and
**lapses loudly** — the dashboard shows the pause as EXPIRED and the arbiter reports it, rather
than silently re-enforcing it. The 2.5-day silent global cooldown of 2026-08-20→23 is the
incident this ends: a pause without an expiry would have been reported stale after 24 h and dead
after 5 h.

**ORC-PAUSE-2 (carry the T625 discharge rules into the file).** `directive_policy.py`'s two
machine-checkable remedies become policy-file semantics, not Python: (a)
discharge-by-condition — `pause --until-done <row>` is enforced only while `<row>` is not
`done`, re-evaluated at every apply; (b) staleness horizon — an unacked unconditional pause
older than `cooldowns.stale_directive_hours` is reported stale, not enforced. `kill` is never
stale and never conditional (explicit halt).

**ORC-PAUSE-3 (one state machine, one row each).** Each pause is one row in the dashboard with
owner / reason / age / expiry (seed Acceptance), and one state in the §6 merged cooldown
machine. There is no second ledger the operator must consult to know what is paused.

---

## 4. One dashboard (ruling 3)

**ORC-DASH-1 (rendering moves into `bin/managent`).** The dashboard is `managent`'s
presentation layer — Zig, the one reader of store + policy file. `watch-fleet.sh` becomes a
thin refresh wrapper (a `while` loop that calls the managent verb and clears the screen); it
holds no rendering logic, no second short-name mapping, no data logic.

**ORC-DASH-2 (short names only; one table).** Human surfaces show SHORT names (`opus`, `dspro`,
`oxalpha`, …) resolved through `model-registry.md`'s one short-name table — no second mapping
(T738/T739 already established this in the interim wrapper; the refactor carries it into Zig).
Canonical labels live in stats and records, never on the human pane.

**ORC-DASH-3 (empty sections are omitted; recovered height shows rows).** T738's omission rule
and T739's fill-the-screen rule are normative: a section with zero rows prints nothing; recovered
vertical space becomes visible rows, not blank lines.

**ORC-DASH-4 (the one pane — worked example, real data).** The pane has exactly five sections —
keeper liveness, pauses, window budget + appetite, benched models, and the queue head — all from
the store + policy file at read time. Rendered against the live store at `a1415fe` (live values
marked ●; the single illustrative pause row is marked ◇ because `directives.jsonl` is empty at
`HEAD`):

```
● keeper       alive · lease pid 29107 · last tick 2s ago (interval 10s)
● pauses       ◇ dsflash: cooldown-test — "you've hit your session limit" · age 0h12 · expires in 0h48
               (no live pauses — directives.jsonl empty)
● window+appetite
   family         budget/5h    used       appetite   cap
   claude         35.0M        ◇ 0        SPEND      3    (fable RESERVED — runs alone)
   deepseek       — (no limit) ◇ 0        SPEND      6
   ollama-cloud   —            —         OFF        5    (deny: glm, minimax, kimi — quota)
   local          —            —         PROBE      1
   ox-alpha       —            —         RESERVED   —    (identity sealed)
● benched       (none benched at HEAD — deepseek-v4-flash last benched 2026-08-20, T544 failures=6, now clear)
● queue         in_progress 3 (T724 T733 T739) · dispatchable 21 · blocked 0
                claimlint C1a=0 C1b=0 C2=13 C6=0 · lanes: 41 unregistered finding(s)
```

The pane's contract is the five section names and their data sources (store + policy file); the
exact column layout is design. **ORC-DASH-5 (data sources, stated).** keeper liveness ←
`untracked/heartbeat.jsonl`/lease file; pauses ← `directives.jsonl` evaluated by the §3 rules;
window+appetite ← policy file `window_budgets` + `appetite` + the §6 machine's runtime state;
benched ← the arbiter's benched set (the `fleet-keeper.attempts.json` shape, moved into the
store); queue ← `managent status --json`. No section may render a number the store/policy file
does not already hold — a dashboard that invents a figure is the QA-023 defect wearing a pane.

---

## 5. One arbiter (ruling 4)

**ORC-ARB-1 (one decision point).** Host-pressure and shed-load decisions move out of N runners
into a single arbiter inside `managent`. Under real pressure it sheds in order: pause/queue new
dispatches first, stop the newest or least-progressed lane next, target a specific consumer only
when one is actually identified (T712). The arbiter **absorbs** T712 (one arbiter, no per-runner
kills) and T713 (resident-tenant dispatch check — the dispatcher knows the reduced memory budget
when the model server is resident; list-wait is acceptable, mid-run fratricide is not). T711's
declared-tenant fix already landed and is a prerequisite, not a co-deliverable.

**ORC-ARB-2 (a guard may stop a lane, no guard may attribute — §7c.31, mechanical).** The
arbiter stops lanes; it never scores models. `killed_by` stays an enumerated value written from
the runner's own terminal record, and any row with `killed_by != none` is refused by every
scorer with the skip count stated. The arbiter's stop is a harness decision; attribution is a
measurement decision; the two never share a code path.

**ORC-ARB-3 (the arbiter is the reconciler pre-pass — ORC-GOAL-4).** The arbiter's deterministic
pre-pass applies every (a)/(b) mechanism before any model token is spent; a quiet store is a
zero-token wake. The model-spawn residue is the §7 open question 1 fold-point.

**ORC-ARB-4 (kernel-attested identity, never env — §7c.18 carried).** The arbiter's store-write
authority is attested from the supervisor's held-child table (parent-PID chain), never from
`MANAGENT_TASK_ID` (spoofable by unsetting). This is the same Security Must the registration
contract (§6) enforces for every other writer.

---

## 6. Registration flow (ruling 5) — file-first, one writer, required fields

**ORC-REG-1 (agents never write tasks.json).** An agent authors
`untracked/T-<slug>.md` first (filenames collide gracefully), then **one** `bin/managent` call
registers/claims. `managent` is the sole store writer and the recoverable conflict point. Direct
`tasks.json` edits fail **mechanically** (hook/permission), never by prose — the standing
"tooling gets the same pipeline" rule: a silent wrong answer outranks a loud crash, so the
refusal is a hard failure, not a warning.

**ORC-REG-2 (one parser, three call sites).** `add`, `suggest`, and `dispatch` share one bundle
header parser. The needs/holds edges are read from the bundle header **at add time** — the T735
dropped-edge incident is the negative precedent; the fix is affirmative: one parser, used by all
three, so an edge can never be read by one surface and dropped by another.

**ORC-REG-3 (required fields, mechanical).** A registration is refused at the `managent` call
unless **all** hold:
1. **title** ≤ 40 chars, one line, phrased as the question the task answers (AGENTS.md);
2. **deliverables** — a comma list, the authoritative source for `managent done`;
3. **landmark tag** — a `**Landmark:**` line (T747): a row cannot enter the queue without saying
   which landmark it serves;
4. **needs/holds edges** — from the bundle header, read by the one parser;
5. **gate declaration** — `gate: <command>` or `gate: audit`, carried from §7c.21 (every row
   declares its gate at mint; neither declared = not dispatchable).

A refusal names the missing field with a worked example of the line to add (T747's "show the
line, don't lecture" convention), never a lecture. The T747 regression (`regression-managent-
landmark.sh`) is the seed of the registration-contract battery.

**ORC-REG-4 (the T735 repair is the parser, not a sweep).** The registration gate re-derives the
T735 dropped-edge incident as a control: a bundle whose header carries `holds=` that `add`
silently drops must make the parser red. The parser is the artifact; a one-off sweep of the
queue is not the fix and is not promised here.

---

## 7. Gate diet, startup-prose diet, provider seam (rulings 6–8)

**ORC-GATE-1 (every dispatch gate re-justified — ruling 6).** Each of today's dispatch gates is
re-justified against process doctrine or demoted. Display preferences (the 40-char title
refusal) demote to **warnings** — they do not block a dispatch. The gate *inventory* is design's
to produce (§7 open question 3 names the shape); the *principle* is normative: a gate that exists
to enforce a taste, not a safety invariant, is a warning.

**ORC-GATE-2 (the merged cooldown machine — one visible state machine).** heal · dispatch ·
window cooldowns become states of one machine with one namespace, one dashboard row each, and
one visible transition set. The arithmetic of each state survives (T504 heal, T536 dispatch,
T628/T677 window); what dies is the third place to look for "is this thing cooled down".

**ORC-ORIENT-1 (startup-prose diet — ruling 7).** `managent orient`'s ≤150-line preamble is the
only boilerplate, injected at dispatch; briefs carry task-specific content only. This builds on
`S05-startup-surfaces` and does not re-spec it: `orient --role` already owns role-sizing; this
sprint's ruling 7 is the *scope* statement (the preamble is the only boilerplate) that
`orient`'s role budgets enforce.

**ORC-PROV-1 (providers as data — ruling 8).** A model is a registry entry: the policy file's
`appetite` row + `model-registry.md`'s short-name/canonical/serving-tag table + the dispatch
MODELS map, unified into one registry read by `bin/dispatch` and `bin/subagent`. **Acceptance
is the T732 baseline inverted:** onboarding a new model costs **one registry entry** (one edit
in one file), measured against T732's "4 tracked files, 65 insertions / 5 deletions, one rebuild
+ deploy". A provider change is a data edit; it is never a code change in three scripts.

---

## 8. Phase plan, sizing, and migration order

**ORC-PLAN-1 (phases — the pass protocol, with audit loops).** Five phases, each with the
`sprint.md` audit loop (cap 3, §7c.21). Build is gated on the policy-file schema and the
arbiter design passing audit; design may run ahead of build (the `orchestration-layer-spec.md`
§6 pattern).

| phase | artifact | content | audit instrument |
|---|---|---|---|
| P1 spec | this `spec.md` (rev 1) | goal, schema, layouts, contracts, migration | document review (fresh session) |
| P2 design | `design*.md` | policy schema final form, dashboard column layout, arbiter state machine, registration parser grammar, provider registry shape | adversarial review |
| P3 test | `test.md` + RED batteries | §9 controls written red before build | review tests **without reading the implementation** |
| P4 build | `build.md` + `managent` changes | policy reader, arbiter, dashboard, registration gate, dispatch/subagent rewire | independent re-implementation of the core check |
| P5 accept | `accept.md` | §10 acceptance: 3 clean days + one-edit onboarding + one-pane proof | numbers audit (denominators, calibration) |

**ORC-PLAN-2 (sizing — backlogs of bounded rows, one writer per file).** Sizing is in
worker-rows, each declaring `holds=`. The binding serialization is `src/managent/main.zig`
(one writer at a time); analysis rows run parallel, mutation rows serial.

| phase | rows | parallel? | note |
|---|---|---|---|
| P1 spec | 1 (this T748) + 1 auditor | — | done by this task |
| P2 design | 4–6 (policy schema, dashboard, arbiter, registration, provider) | yes (analysis) | each ends in a design doc |
| P3 test | 4–6 (one battery per §9 control group) | yes | RED before build |
| P4 build | 6–10 | **serial on `src/managent/main.zig`** | the long pole |
| P5 accept | 2–4 + 3 wall-clock days | — | `orcha-acceptance.sh` × 3 days |

**ORC-PLAN-3 (migration order — tools first, then scripts).** The tools migrate in this order,
each step committing before the next touches the store (commit → deploy → smoke):

1. **Policy file + `managent` policy reader** (absorbs `window_policy.py`, `directive_policy.py`,
   the cooldown half of `fleet-keeper.sh`) — first, because every later step reads it.
2. **Arbiter** (absorbs the dispatch-loop half of `fleet-keeper.sh` + the runner host-guard
   interaction) — second, because it is the pre-pass everything else sits on.
3. **Dashboard** (`watch-fleet.sh` → thin wrapper; rendering in `managent`) — third, because it
   renders steps 1–2.
4. **Registration flow** (the T747 gate + one parser + mechanical store-write refusal) —
   fourth, because `dispatch`/`subagent` step 5 must assume it.
5. **Dispatch/subagent rewire** (read the policy file + registry; gate logic moves to
   `managent`) — fifth, the consumers.
6. **Provider seam** (the one-registry-entry onboarding, measured against T732) — last, the
   acceptance demo.

**ORC-PLAN-4 (regression scripts — counted disposition).** 75 `tools/regression-*.sh` at `HEAD`.
Dispositions: **ABSORB** (coverage re-expressed as `managent` Zig tests, shell script retired at
phase close), **REWIRE** (script updated to the new mechanism; subject survives), **SURVIVE**
(out of scope, untouched), **RETIRE** (mechanism deleted, no replacement owed — count is **0**,
stated so nothing is silently dropped). The table is complete: 17 + 14 + 44 + 0 = **75**.

**ABSORB — 17** (phase P4; their controls move into `zig build test`):

| script | phase |
|---|---|
| regression-dispatch.sh, regression-dispatch-verification.sh, regression-duplicate-dispatch.sh, regression-depth-enforcement.sh, regression-ollama-dispatcher.sh, regression-subagent-prompt.sh, regression-session-capture.sh, regression-token-capture.sh, regression-task-identity.sh | P4.5 dispatch/subagent rewire |
| regression-inbox-loop.sh | P4.4 registration (the T352 inbox loop) |
| regression-directive-integrity.sh, regression-directive-kill.sh | P4.1 policy reader (expiring pauses) |
| regression-fleet-keeper.sh, regression-window-resilience.sh | P4.1/P4.2 policy + arbiter |
| regression-watch-fleet.sh | P4.3 dashboard |
| regression-attribution-backfill.sh | P4.4 registration (store writer) |
| regression-orient.sh | P4.x startup-prose diet (carried into `orient` battery) |

**REWIRE — 14**:

| script | phase | change |
|---|---|---|
| regression-managent-landmark.sh | P4.4 | extends into the registration-contract battery (title/deliverables/landmark/edges/gate) |
| regression-managent-models.sh | P4.6 | extends into the one-registry test (short names + canonical + serving tags) |
| regression-runner-host-guard.sh, regression-runner-guard.sh, regression-runner-reap.sh, regression-runner-reporting.sh, regression-runner-run-records.sh, regression-runner-brief-telemetry.sh, regression-runner-taskid.sh, regression-runner-worktree.sh, regression-runner-agent-progress.sh, regression-runner-claude-liveness.sh, regression-runner-harness-p95.sh, regression-runner-startup-liveness.sh | P4.2 | `tools/runner` survives; its arbiter interaction (who sheds load, who writes `killed_by`) is re-pointed at the arbiter |

**SURVIVE — 44** (out of scope; untouched): the 19 remaining `regression-managent-*` scripts
(assert-store, attribution, build-mode, concurrency, done-git, done-two-phase, duty, holds,
impression-gate, integrity, lanes, ledger-board-seam, lock, memory-safety, resume, standing,
status-json, store-pollution, store-write-utf8) — they already test the `managent` binary that
grows, and are extended in place, not absorbed; plus the out-of-scope domains: claimlint ×6
(c7-json, c7-scope, output, promotion, volatile, claim-lifecycle), absorption-machinery,
argus-doctor, orphan-reaper, bakeoff-gates, battery-baselines, battery-sweep, complementarity,
model-profiles, race-p0, gtp-boardsize, T227, suite-surfaces, commit-concurrency, git-commit-mine,
git-commit-mine-hook, process-ownership, pilot-gate, orcha-acceptance, precommit. `orcha-
acceptance.sh` survives as the bar itself (it is the P5 gate, not a thing under test).

**ORC-PLAN-5 (silent truncation is a defect).** The disposition table's counts sum to 75, the
`ls tools/regression-*.sh | wc -l` at `HEAD`. If a later phase retires a script not listed
here, the plan is amended; a script left off the table is a spec defect, not a reader's problem.

---

## 9. Controls — never trust a green arbiter

**ORC-CTRL-1 (the battery, scripted against a scratch store).** Each control is scripted
against a scratch store (`MANAGENT_STORE`), regression-suite style. Every id in §1–§7 has at
least one arm; the seed's named controls are the mandatory core:

| # | control | seeded defect | expected | flips |
|---|---|---|---|---|
| C1 | null | quiet store + clean policy file | zero actions, zero escalations, zero model tokens | ORC-ARB-3 |
| C2 | policy parse | an entry with no owner/reason | refused at parse, names the entry | ORC-POL-2 |
| C3 | hidden default | env knob with no file entry | refused: "add it to the policy file or it is not a knob" | ORC-POL-7 |
| C4 | expiring pause | a 6-hour-old unconditional pause | reported stale/expired, not enforced | ORC-PAUSE-1/2 |
| C5 | discharge-by-condition | `pause --until-done T<x>` with T<x> done | pause not enforced | ORC-PAUSE-2 |
| C6 | dashboard truth | a section rendering a number not in store/policy | refused (the pane may not invent a figure) | ORC-DASH-5 |
| C7 | empty section | a section with zero rows | omitted, no heading | ORC-DASH-3 |
| C8 | short names | a canonical label on the human pane | refused (short names only) | ORC-DASH-2 |
| C9 | arbiter shed order | pressure: shed queue-first, then newest lane | never kills a mid-run lane to admit a new one | ORC-ARB-1 |
| C10 | guard vs attribution | a stopped lane | `killed_by` enumerated, scorers refuse + state skips | ORC-ARB-2 |
| C11 | registration fields | bundle missing a landmark line / >40-char title / no gate | refused at the `managent` call, names the field + example | ORC-REG-3 |
| C12 | direct store edit | a task writes `tasks.json` directly | fails mechanically (hook/permission) | ORC-REG-1 |
| C13 | dropped edge | a bundle header `holds=` that `add` silently drops | parser red | ORC-REG-2/4 |
| C14 | one-edit onboarding | a new model registered via one file edit | dispatches; T732 baseline (4 files) not touched | ORC-PROV-1 |

**ORC-CTRL-2 (red first).** The first live reading counts only after C1 (null) **and** the
seeded-defect controls pass — red first, then green (`sprint.md` TDD; the 2B-5 positive-control
failure is the local scar). Controls are written **before** implementation (P3 precedes P4).

**ORC-CTRL-3 (the seeded defects are synthetic fixtures, not live docs).** C2/C3/C11/C13's
defects are synthetic fixtures under the scratch store — live faults get fixed, and a check
against live data then silently tests nothing (calibration rule).

**ORC-CTRL-4 (the one-edit onboarding is measured, not asserted).** C14 records the edit count
against the T732 baseline's "4 tracked files, 65 insertions / 5 deletions, one rebuild +
deploy". A pass is **one registry entry**; anything touching a second code path fails.

---

## 10. Acceptance (seed "Acceptance for the sprint")

**ORC-ACC-1 (the three bars, all three required).**

1. `tools/orcha-acceptance.sh` green **three consecutive days** with **zero operator
   process-relays** (the existing L1 bar), **AND**
2. a demonstrated **one-edit model onboarding**, measured against the T732 baseline (C14), **AND**
3. the dashboard shows, in **one pane**: keeper liveness, every pause with owner/reason/age/
   expiry, per-family window budget and appetite, benched models (§4's five sections).

**ORC-ACC-2 (the L1 declaration is measured on the new mechanism, not the old).** The three
clean days run on the refactored surface — policy file read by `dispatch`/`subagent`/arbiter,
dashboard in `managent`, registration through the file-first contract. A clean day on the old
shell keeper does not count; the point of the sprint is that the new mechanism holds the bar.

**ORC-ACC-3 (audit-loop cap 3, carried).** Each phase's audit loop caps at three (sprint.md +
§7c.21): a third red audit blocks the phase and the sprint escalates; the sprint cannot close
itself past that.

---

## 11. Rulings traceability — no ruling silently dropped

| seed ruling | spec home |
|---|---|
| 1 one policy file | ORC-POL-1/2/5/7 |
| 2 expiring pauses | ORC-PAUSE-1/2/3 |
| 3 one dashboard | ORC-DASH-1–5 |
| 4 one arbiter | ORC-ARB-1–4, ORC-GOAL-4 |
| 5 registration flow | ORC-REG-1–4 |
| 6 gate diet | ORC-GATE-1/2 |
| 7 startup-prose diet | ORC-ORIENT-1 |
| 8 provider seam | ORC-PROV-1 |
| Acceptance (3 days + onboarding + one pane) | ORC-ACC-1 |
| Feedstock T712/T713 | ORC-ARB-1 |
| Feedstock T578 (reconciler scope) | ORC-GOAL-4, ORC-ARB-3 |
| Feedstock T709 | ORC-REG-1 (mechanical store-write refusal subsumes the rc=0 reconcile) |
| T747 landmark gate | ORC-REG-3 (field 3) |
| T738/T739 dashboard trim | ORC-DASH-2/3 |
| §7c.11/12 appetite | ORC-POL-3 |
| §7c.31 guard vs attribution | ORC-ARB-2 |
| §7c.18 kernel-attested identity | ORC-ARB-4, ORC-REG-1 |
| §7c.21 two-tier closure + audit cap | ORC-REG-3 (field 5), ORC-ACC-3 |

---

## 12. Open questions — resolved at spec vs options-with-recommendation vs deferred

**Resolved at spec:**

1. **Do env vars die?** No — they become overrides of a file entry, and overrides are recorded
   (ORC-POL-7).
2. **Is the policy file committed or untracked?** Committed, `docs/infra/orchestration-policy.json`
   — it is the gate-as-data artifact and must be diff-reviewed (ORC-POL-5).
3. **Is the dashboard's pane layout normative or illustrative?** The five section names + data
   sources are normative; the column layout is design (ORC-DASH-4/5).

**Options with a recommendation (`[design-open]` — design may choose among these only):**

1. **The reconciler fold-point** (ORC-GOAL-4): (a) absorb the model-spawn into this sprint's
   build, or (b) ship the arbiter pre-pass first, model-spawn as a successor row. **Recommend
   (b)** — an unshipped pre-pass cannot audit a model-spawn.
2. **RESERVED encoding** (ORC-POL-6): `-1` sentinel vs explicit `"appetite": "RESERVED"` string.
   **Recommend the explicit string.**

**Deferred to design (the spec states the principle, design states the mechanism):**

- the merged cooldown machine's exact state set and transitions (ORC-GATE-2);
- the dashboard's column layout (ORC-DASH-4);
- the registration parser's grammar and the mechanical store-write refusal's enforcement point
  (hook vs `managent` permission check) — both must be kernel-attested per §7c.18, the concrete
  plumbing is design;
- the dispatch-gate inventory (which gates demote to warnings) — the *principle* (a taste-gate
  is a warning, a safety-gate is a refusal) is normative, the *list* is design's.

**Pending operator numbers (spec defaults hold meanwhile, per §7b):**

- the sprint number itself (§header naming note — `S05` collision, recommend `S06`);
- none of the §7c constants are re-set here (they are consumed from the seed).

---

## 13. Milestone

**Landmark:** advances **L1 (hands-off orchestration)** — the ratified rulings become a spec
the operator can ratify or amend; on ratification the fleet's six-file policy/display/pressure
surface collapses into one policy file, one dashboard, and one arbiter, and onboarding a model
costs one registry entry. What remains for L1: ratification, then the five-phase build whose
acceptance is three consecutive clean days on the new mechanism.
