# S06 — spec: orchestration refactor (one policy file, one dashboard, one arbiter)

**Artifact type: SPEC** (`docs/infra/sprint.md` — a spec says what we want, testably, for one
pass). **Owner:** deepseek-v4-pro/T748 · **Date:** 2026-08-23 · **Status:** **rev 2 — AMENDED,
awaiting operator ratification.** Rev 1 (PROPOSED) was audited by `claude-sonnet-5`/T778
(verdict RATIFIABLE-WITH-AMENDMENTS, 4 major / 2 medium / 2 minor); T802 discharged all eight
and added four of its own, found while writing the arms. **See §14 (amendment log) for the
twelve, each with its arm.** Not a worker brief, not a plan, no code.

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

**Adjacent subsystem, deliberately not resolved here (T778 finding 5).** T772's ratified
direction — *"cost is REMOVED from model choice entirely"* — governs `soloPick` / task-to-model
**assignment**. This spec's policy file governs **appetite, caps, allow/deny and cooldowns**:
fan-out and back-pressure, not assignment. The two are distinct subsystems and this document
resolves nothing in T772's; a reader should not assume otherwise because both concern models.

**Citation pins.** Every `file:line` in this document is against `HEAD` at authoring time, commit
`a1415fe` (2026-08-23). References to other spec documents are by **§ref**; each §ref is tagged
with its document's rev/pin where load-bearing. A citation that no longer resolves at `a1415fe`
is a spec defect, not a reader's problem.

**Naming (RESOLVED — operator ratified 2026-08-23).** This sprint is **S06**; the directory
was renamed from `S05-orchestration-refactor` the same day (`S05-startup-surfaces` keeps S05 —
the two are distinct sprints with a one-way relationship: this sprint's ruling 7 builds on
`orient`, it does not re-spec it). Pre-rename citations of the old path in closed-row bundles
are historical records, not defects.

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

| today | lines @`a1415fe` | lines @`8c00704` | role | goes to |
|---|---|---|---|---|
| `tools/fleet-keeper.sh` | 1169 | 1169 | dispatch loop + cooldown flags + one-writer invariant + appetite/cap enforcement | `managent` arbiter + policy reader |
| `tools/window_policy.py` | 737 | **548** | reset watcher + ~~token meter~~ + fan-out cap | policy file + `managent` arbiter |
| `tools/directive_policy.py` | 176 | 176 | directive staleness + discharge | policy file (expiring pauses) + `managent` |
| `bin/dispatch` | 536 | **546** | dispatch gate + canonicalization | policy reader; gate logic moves to `managent` |
| `bin/subagent` | 557 | **858** | launch chokepoint + provider selection | provider seam (registry entries) |
| `untracked/watch-fleet.sh` | 304 | **311** | dashboard | thin refresh wrapper; rendering moves to `managent` |

Six files, **3479 lines** at the spec's own pin — **3608 at `8c00704`**, recomputed by T802
(T778 finding 6). Both columns are kept because the *delta* is the load-bearing fact: T766
removed 189 lines from `window_policy.py`, and the surface still grew by 129, because
`bin/subagent` gained 301 (T713's resident gate, T773's liveness fuse). **The surface this sprint
plans to shrink is growing faster than the sprint is shrinking it** — at +129 lines in the eight
hours between the two pins. That is the argument for ORC-PLAN-3's one-door-per-pass order over
any big-bang cut-over, and the reason the accept question ("did we actually shrink it") must be
answered against a pin taken at accept, never against 3479.

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

**Amendment (T802, T778 finding 8) — "carry over unchanged" has nothing to carry.** T778 found
ORC-DASH-4 rendering appetite as a per-FAMILY word while this id defines a per-MODEL 0–9 dial,
with no stated rollup. Counted at `8c00704`, the disagreement is deeper than a display rule:
**the 0–9 dial exists in no tracked source file.** It lives only in `orchestration-layer-spec.md`
§7c.11 prose. What exists is **two** per-family categorical tables, and they **disagree**:

| | `tools/fleet-keeper.sh:325` | `src/managent/main.zig:313` |
|---|---|---|
| ollama models | family `ollama`, **SPEND** (quota handled by a separate model-level `DENY`) | family `ollama-cloud`, **OFF** |
| Fable | family `fable`, RESERVED | family `claude-fable`, RESERVED |
| ox-alpha | **absent** → `other` → SPEND by default fallthrough | family `ox-alpha`, SPEND by ruling |

So the same model resolves to a different family *name* and, for the three ollama models, a
different *appetite*, depending on which reader is asked. Armed as
`TestAppetiteDial.test_the_two_appetite_tables_disagree_today` (characterization, GREEN) and
`test_one_appetite_table_not_two` (ORC-POL-1, RED, owner step 1).

Three consequences for the plan, none in rev 1: (a) ORC-DASH-4's family word is not a *rollup* of
per-model dials — it is the real mechanism, and the dial is the wish, so the rollup function
T778 asks for is the wrong question; the right one is **which of the two does step 1 build**;
(b) **recommendation:** build the 0–9 per-model dial and derive the family word from it by
stated floor thresholds, because the categorical form cannot express §7c.11's monotone
back-pressure at all (there is no "slightly less") — this is a `[design-open]` choice between
the dial and the categorical form, and it must be made explicitly rather than by whichever
table step 1 happens to port; (c) this is an **11th multi-way job**, absent from the roadmap
§6 table of ten, found by T802's census: *two appetite tables, disagreeing*.

**ORC-POL-4 (the cooldown mechanisms merge — ruling 6).** heal (T504), dispatch (T536), window
(T628/T677) **and the global keeper flag** cooldowns become **one visible state machine** in the
policy file, with one namespace and one dashboard row each. The merge is a *schema* fact, not a
behaviour change: each cooldown's arithmetic survives as a named state of the machine. (§6
specifies the states.)

**Amendment (T802) — the merge was three of four, and the omitted one is the one with the
incident.** Rev 1 (and ORC-GATE-2) named three mechanisms. There is a fourth:
`untracked/fleet-keeper.cooldown`, tested by `fleet-keeper.sh`'s `cooldown_set()` as
`os.listdir(dir)` + basename membership. Because it is a *file's existence*, it carries **no
owner, no reason and no expiry** — all three of which ORC-POL-2 requires of every policy entry.
It is **global**: no family scope, no model scope, no row scope. And its unreadable-directory
branch returns `True`, so a permissions fault idles the entire fleet as a dead-man's switch.
Nothing expires it. Armed as
`TestCooldownMachine.test_a_fourth_global_cooldown_exists_as_a_bare_flag_file`
(characterization, GREEN) and `test_merge_list_names_every_cooldown_mechanism_that_exists`
(RED, owner step 1).

**This mechanism is the ORC-PAUSE-1 incident, and it is live, not historical.** Measured at
`8c00704` (2026-08-23T19:40Z): the keeper process is **alive** (pid 99956, ppid 1, elapsed
3d04h), its last dispatch was **2026-08-20T18:25:26Z** (T554 → claude-fable-5), and it has
logged **8,747 consecutive** `cooldown flag set — no new dispatches` ticks since — **~73 hours**
— while **21 rows sit dispatchable**. §3 describes this as "the 2.5-day silent global cooldown of
2026-08-20→23"; it is now 3 days and still counting, because the flag has no expiry to lapse and
no dashboard row to make it visible. A merge that left this mechanism out would have preserved
the third place to look *and* the incident. It is in the merge as of this amendment, and it is
the state machine's **only** state whose entry condition is a bare file.

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
    {"model": "oxalpha", "dial": 6, "owner": "operator", "reason": "free while the blind test runs; draw and compare at every reasonable opportunity, never penalize on speed (ruling 2026-08-23, 2ec4f93 — supersedes T732 RESERVED)", "expiry": "blind-test-reveal"}
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
  "pause_default": {"max_seconds": 18000, "owner": "operator", "reason": "ruling 2: 5-hour default maximum unless explicitly longer", "expiry": null}
}
```

**Amendment 2026-08-23 (T766).** The `window_budgets` block (shown above at lines 180–183 in the
seed) is **retired**. Operator ruling: the predictive token-budget meter is removed; regulation
collapses to APPETITE (steering) + COOLDOWN (reactive). The T736 calibration (35M, 5h) is
superseded — marked with an epoch-boundary note in docs/infra/model-perf.md (project convention),
never deleted.

**ORC-POL-6 (RESERVED is a category with no current member — amended T802, T778 finding 4).**
RESERVED is a §7c.12 "should" fact (never auto-drawn), not a "can" dial. The parser accepts
exactly `0–9` plus a reserved sentinel; anything else is a parse error.

Rev 1 built this id's rationale on `oxalpha` as RESERVED's sole real-world subject. **That is no
longer true**: the operator flipped ox-alpha to free/SPEND on 2026-08-23 (`2ec4f93`, recorded in
`landmark-waypoints-seed-2026-08-23.md` §5), three hours after this spec's pin. RESERVED's only
remaining member is `claude-fable-5` **as a family appetite**, not as a per-model dial — so the
category still exists but has **no per-model subject at all**, and the §12 `[design-open]`
choice between a `-1` sentinel and an explicit `"RESERVED"` string has **no live consumer**.
Design should not spend a cycle on it; the sentinel-vs-string choice is deferred until something
is actually RESERVED per-model, and the recommendation (explicit string) stands as the answer
for that day.

There is a second, live problem this id must own. `tools/fleet-keeper.sh` has **no ox-alpha row
at any granularity**: `family_of("ox-alpha")` → `"other"` → `APPETITE.get("other", "SPEND")` →
SPEND. The keeper therefore never honoured RESERVED for ox-alpha — before the 2026-08-23 ruling
it would have auto-dispatched an identity-sealed model, and it is *accidentally* correct now.
Armed as `TestAppetiteDial.test_keeper_has_no_row_for_ox_alpha_so_it_falls_through_to_spend`
(T802). ORC-PLAN-3 step 1 must fix the fallthrough, not inherit it: **an unknown model resolves
to a refusal, never to a default appetite.** A default that silently permits is the D036 class
this sprint exists to kill.

**ORC-POL-7 (env vars are overrides, and overrides are recorded).** The existing knobs
(`FLEET_MODEL_ALLOW/DENY`, `FLEET_APPETITE`, `FLEET_FAMILY_CAP`, `WEIZIGO_DIRECTIVE_STALE_HOURS`)
keep working **as overrides of a file entry**, and an override is appended to
`untracked/fleet-window-overrides.jsonl` with the reason it was needed (the T677 override-recording
precedent, generalized). A knob with no corresponding file entry is refused with "add it to the
policy file or it is not a knob" — the D036 silent-default class dies here. (T766: `WEIZIGO_WINDOW_BUDGET_*` knobs retired.)

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
● appetite
   family         appetite   cap
   claude         SPEND      3    (claude-fable RESERVED — runs alone)
   deepseek       SPEND      6
   ollama-cloud   OFF        5    (deny: glm, minimax, kimi — quota)
   local          PROBE      1
   ox-alpha       SPEND      —    (free while the blind test runs, 2026-08-23)
● benched       (none benched at HEAD — deepseek-v4-flash last benched 2026-08-20, T544 failures=6, now clear)
● queue         in_progress 3 (T724 T733 T739) · dispatchable 21 · blocked 0
                claimlint C1a=0 C1b=0 C2=13 C6=0 · lanes: 41 unregistered finding(s)
```

The pane's contract is the five section names and their data sources (store + policy file); the
exact column layout is design. **ORC-DASH-5 (data sources, stated).** keeper liveness ←
`untracked/heartbeat.jsonl`/lease file; pauses ← `directives.jsonl` evaluated by the §3 rules;
appetite ← policy file `appetite` + `caps` + the §6 machine's runtime state; benched ← the
arbiter's benched set (the `fleet-keeper.attempts.json` shape, moved into the store); queue ←
`managent status --json`. No section may render a number the store/policy file does not already
hold — a dashboard that invents a figure is the QA-023 defect wearing a pane.

**Amendment (T802, T778 finding 3) — the retired meter is out of §4 and §10 too.** Rev 1's §2
amendment retired `window_budgets` (T766: the predictive token-budget meter is removed;
regulation is APPETITE + COOLDOWN), and then three later sections still required it: this pane's
`budget/5h` column with its superseded 35.0M figure, this id's `window_budgets` data source, and
ORC-ACC-1's third acceptance bar. All three are corrected above and below. A builder reading
rev 1 §4 literally would have re-introduced the meter the sprint had just killed, and the
acceptance bar would have ratified it.

**Amendment (T802) — the section names are a NEW pane, not a moved one.** ORC-PLAN-3 step 3
reads as a move (*"rendering moves to `managent`"*). Measured: this id's five section names and
the five `untracked/watch-fleet.sh` actually renders (`PROGRESS`, `CONCERNS`, `RECENT`, `DONE`,
`OPEN`) have an **empty intersection** — armed as
`TestOnePane.test_specified_sections_share_nothing_with_todays_sections`. So step 3 is a build
plus a deletion, and the sizing must say so. Two consequences, neither in rev 1: (a) T738's
omission rule, T739's fill-the-screen rule and T799's footer work attach to sections this id
does not keep — they must be re-expressed against the new sections or they are lost, not
carried; (b) the operator's current pane answers *"what is happening to my tasks"* while this
id's pane answers *"what is happening to my fleet"*. Both are wanted. **Recommendation
(`[design-open]`):** the `managent` dashboard verb renders **both** groups as one pane of up to
ten sections under the omission rule, rather than replacing the task view with a fleet view —
deleting a surface the operator uses daily is not a consolidation the census asked for.

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
`untracked/T-<slug>.md` first, then **one** `bin/managent` call registers/claims. **Collision
resolution (amended T802, T778 finding 7):** rev 1 said filenames "collide gracefully" and left
two readings — auto-suffix, or refuse. It **refuses**, and names the alternative filename in the
refusal, per ORC-REG-3's show-the-line convention. A silent auto-rename means the author's next
command reads a file they did not write, which is the ungated-convenience-path failure mode the
§6 census names; a refusal costs one keystroke and cannot lose a bundle. `managent` is the sole store writer and the recoverable conflict point. Direct
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
window · **global-keeper-flag** cooldowns become states of one machine with one namespace, one
dashboard row each, and one visible transition set. The arithmetic of each state survives (T504
heal, T536 dispatch, T628/T677 window, the flag file's boolean); what dies is the third *and
fourth* place to look for "is this thing cooled down". (Amended T802 — see ORC-POL-4: the flag
file was omitted from rev 1's merge, and it is the mechanism that has idled the fleet for ~73
hours at the time of this amendment. Its arithmetic does not survive intact: a state with no
expiry cannot be a state of a machine whose defining property is that pauses lapse loudly, so
the flag's boolean becomes a scoped, owned, expiring entry — a behaviour change, deliberately,
and the only one this merge makes.)

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

**ORC-PLAN-4 (regression scripts — counted disposition).** 81 `tools/regression-*.sh` at `HEAD`.
Dispositions: **ABSORB** (coverage re-expressed as `managent` Zig tests, shell script retired at
phase close), **REWIRE** (script updated to the new mechanism; subject survives), **SURVIVE**
(out of scope, untouched), **RETIRE** (mechanism deleted, no replacement owed — count is **0**,
stated so nothing is silently dropped). The table is complete: 19 + 16 + 45 + 0 = **80**.

**Amendment (T801).** `regression-canonicalizer-parity.sh` landed after the `8c00704` pin (T801,
one canonicalizer): **SURVIVE** — it is the new standing parity control over the model
canonicalizer, out of the S06 orchestration scope. Live count 80 → **81**; the table above is
unchanged (the 80 it enumerates are all still accounted).

**Amendment (T802, T778 finding 2) — re-pinned to `8c00704`, and the count is now an
instrument.** Rev 1's 75 was **correct at its own pin**: `git ls-tree a1415fe` returns exactly
75. T778 measured 76 at `2ec4f93` and read the delta as a spec defect; it is better described as
**pin drift**, and the distinction matters because it changes the fix. Measured now: 75 at
`a1415fe` (13:04) → 76 at `2ec4f93` (16:45) → **80 at `8c00704`** (21:31). Five scripts landed in
the eight and a half hours after the spec's pin:

| script | added | disposition |
|---|---|---|
| `regression-directive-id-uniqueness.sh` | `be87b34` T758 | **ABSORB** P4.1 — directive-ID minting, beside its two `regression-directive-*` siblings |
| `regression-subagent-resident-gate.sh` | `e842dbf` T713 | **ABSORB** P4.2 — T713 is named by ORC-ARB-1 as absorbed by the arbiter, so its control moves with it |
| `regression-runner-pi-session-liveness.sh` | `1b8baa0` T773 | **REWIRE** P4.2 — a `regression-runner-*` arm; `tools/runner` survives, its arbiter interaction is re-pointed |
| `regression-task-id-archive.sh` | `e946739` T770 | **REWIRE** P4.4 — task-ID mint consults the archive; the two-task-stores census row is registration's |
| `regression-race-collect.sh` | `b436c63` T779 | **SURVIVE** — race machinery, explicitly out of scope per ORC-GOAL-3 |

ORC-PLAN-5 says in prose that an uncounted script is a spec defect. **Prose does not count
scripts**: this table drifted by five in a third of a day, and would drift again before the
sprint's first pass lands. The fix is therefore the mechanism, not this edit —
`TestDispositionCount.test_the_spec_declares_the_live_count` (T802) reads the number out of this
paragraph and compares it to `glob("tools/regression-*.sh")`, with a null control (a correct
synthetic declaration passes) and a seeded control (a wrong one is caught) so the instrument
earns its reading. The number above is maintained by that arm going red, never by a reader
noticing.

**ABSORB — 19** (phase P4; their controls move into `zig build test`):

| script | phase |
|---|---|
| regression-dispatch.sh, regression-dispatch-verification.sh, regression-duplicate-dispatch.sh, regression-depth-enforcement.sh, regression-ollama-dispatcher.sh, regression-subagent-prompt.sh, regression-session-capture.sh, regression-token-capture.sh, regression-task-identity.sh | P4.5 dispatch/subagent rewire |
| regression-inbox-loop.sh | P4.4 registration (the T352 inbox loop) |
| regression-directive-integrity.sh, regression-directive-kill.sh, regression-directive-id-uniqueness.sh | P4.1 policy reader (expiring pauses) |
| regression-subagent-resident-gate.sh | P4.2 arbiter (T713, absorbed by ORC-ARB-1) |
| regression-fleet-keeper.sh, regression-window-resilience.sh | P4.1/P4.2 policy + arbiter |
| regression-watch-fleet.sh | P4.3 dashboard |
| regression-attribution-backfill.sh | P4.4 registration (store writer) |
| regression-orient.sh | P4.x startup-prose diet (carried into `orient` battery) |

**REWIRE — 16**:

| script | phase | change |
|---|---|---|
| regression-managent-landmark.sh | P4.4 | extends into the registration-contract battery (title/deliverables/landmark/edges/gate) |
| regression-managent-models.sh | P4.6 | extends into the one-registry test (short names + canonical + serving tags) |
| regression-task-id-archive.sh | P4.4 | task-ID mint consults the archive; re-pointed at the one registration parser (the two-task-stores census row) |
| regression-runner-host-guard.sh, regression-runner-guard.sh, regression-runner-reap.sh, regression-runner-reporting.sh, regression-runner-run-records.sh, regression-runner-brief-telemetry.sh, regression-runner-taskid.sh, regression-runner-worktree.sh, regression-runner-agent-progress.sh, regression-runner-claude-liveness.sh, regression-runner-harness-p95.sh, regression-runner-startup-liveness.sh, regression-runner-pi-session-liveness.sh | P4.2 | `tools/runner` survives; its arbiter interaction (who sheds load, who writes `killed_by`) is re-pointed at the arbiter |

**SURVIVE — 45** (out of scope; untouched): the 19 remaining `regression-managent-*` scripts
(assert-store, attribution, build-mode, concurrency, done-git, done-two-phase, duty, holds,
impression-gate, integrity, lanes, ledger-board-seam, lock, memory-safety, resume, standing,
status-json, store-pollution, store-write-utf8) — they already test the `managent` binary that
grows, and are extended in place, not absorbed; plus the out-of-scope domains: claimlint ×6
(c7-json, c7-scope, output, promotion, volatile, claim-lifecycle), absorption-machinery,
argus-doctor, orphan-reaper, bakeoff-gates, battery-baselines, battery-sweep, complementarity,
model-profiles, race-p0, race-collect, gtp-boardsize, T227, suite-surfaces, commit-concurrency, git-commit-mine,
git-commit-mine-hook, process-ownership, pilot-gate, orcha-acceptance, precommit. `orcha-
acceptance.sh` survives as the bar itself (it is the P5 gate, not a thing under test).

**ORC-PLAN-5 (silent truncation is a defect — now mechanized).** The disposition table's counts
sum to **80**, the `ls tools/regression-*.sh | wc -l` at `8c00704`; the T801 addition brings the
live count to **81** (see the ORC-PLAN-4 amendment). If a later phase retires a
script not listed here, the plan is amended; a script left off the table is a spec defect, not a
reader's problem. **Amended T802:** that sentence is now enforced by
`tests/unit/test_s06_conformance.py::TestDispositionCount`, which fails the moment the declared
count and the live count diverge. The rule was true in rev 1 and drifted by five anyway, which is
the standing lesson: prose is not a remedy for a mechanism failure.

---

## 9. Controls — never trust a green arbiter

**ORC-CTRL-1 (the battery, scripted against a scratch store — coverage stated, not claimed).**
Each control is scripted against a scratch store (`MANAGENT_STORE`), regression-suite style.
**C1–C14 below are the mandatory core; they are not full coverage of §1–§7.** Rev 1 claimed
"every id in §1–§7 has at least one arm"; T778 finding 1 counted the flips column and found 15
of **31** normative ids armed, i.e. 16 wishes wearing requirements — the same overclaim the S04
spec audit found, and the exact failure §0's own rule names (*"an id with no control is not a
requirement, it is a wish"*). The remainder is therefore **enumerated by id**, because an
unenumerated remainder is how coverage debt goes silent.

**Armed count at `8c00704`: 22 of 31.** The 15 in the flips column below (ARB-1, ARB-2, ARB-3,
DASH-2, DASH-3, DASH-5, PAUSE-1, PAUSE-2, POL-2, POL-7, PROV-1, REG-1, REG-2, REG-3, REG-4)
plus **7 armed by T802** in `tests/unit/test_s06_conformance.py` — POL-1, POL-3, POL-4, DASH-1,
DASH-4, ARB-4, GATE-2 — the four load-bearing ones T778's disposition named, plus the three its
arms necessarily also assert. Those seven arms are **RED by construction and correct to be red**
(ORC-CTRL-2: red first): each is `@unittest.expectedFailure` naming the ORC-PLAN-3 step that
owes the mechanism, and each is paired with a GREEN *characterization* arm pinning what the
subject does **today** — so a migration step cannot change today's behaviour silently, and
cannot mark the id armed without turning its red arm green.

**Still unarmed — 9, owed in P3:** `ORC-GOAL-1`, `ORC-GOAL-2`, `ORC-GOAL-3`, `ORC-GOAL-4`
(the four goal statements — arguably unarmable as stated, which is itself a finding: a goal that
cannot be armed should be a measurable acceptance bar in §10 or should not carry an id),
`ORC-POL-5` (the schema's worked example), `ORC-POL-6` (the RESERVED encoding — see the
amendment below; it has no live subject), `ORC-PAUSE-3` (one row per pause), `ORC-GATE-1` (the
gate diet, whose inventory is design's), `ORC-ORIENT-1` (the prose diet, armed in `S05`'s own
`regression-orient.sh` rather than here — a cross-tier arm that this table should credit or
disclaim, not omit).

The mandatory core:

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
   expiry, **per-family appetite and cap** (amended T802, T778 finding 3 — "window budget" is
   the mechanism T766 retired; requiring it here would have made the acceptance bar ratify a
   deleted meter), benched models (§4's five sections).

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
| T778 audit (8 findings) | §14 amendment log, rows 1–8 |
| T802 census + arms (4 findings) | §14 amendment log, rows 9–12; `tests/unit/test_s06_conformance.py` |

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
   **Recommend the explicit string** — but **DEFERRED, no live consumer** (amended T802, T778
   finding 4): ox-alpha was RESERVED's only per-model subject and is now free/SPEND, so design
   would be choosing an encoding for an empty category. Revisit when something is RESERVED
   per-model again.
3. **The appetite mechanism itself** (ORC-POL-3, added T802): the per-model 0–9 dial vs the
   per-family categorical word that both live tables actually implement. **Recommend the dial**
   (the categorical form cannot express §7c.11 monotone back-pressure), with the family word
   derived from it by stated floor thresholds. This is `[design-open]` and must be chosen
   explicitly — rev 1 assumed the dial existed and could be "carried over unchanged".
4. **The dashboard's section set** (ORC-DASH-4, added T802): replace today's five task-view
   sections with the five fleet-view sections, or render both under the omission rule.
   **Recommend both** — the specified set shares nothing with the existing set, so "replace" is
   a deletion of a surface the operator uses daily.

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

---

## 14. Amendment log — rev 1 → rev 2 (T802, 2026-08-23)

Every row names the id it changed and the arm that holds it. A row with no arm is a wish; that is
§0's rule and it applies to amendments as much as to requirements. Arms live in
`tests/unit/test_s06_conformance.py` (hermetic, stdlib-only, **24 arms — 19 GREEN
characterization, 5 RED spec-conformance covering 7 ids**, 0.04 s) unless stated.

### Discharging T778 (`findings/T778-s06-spec-audit.json`)

| # | sev | id(s) | what changed | arm |
|---|---|---|---|---|
| 1 | major | ORC-CTRL-1 | universal-coverage claim withdrawn; armed count **stated as 22 of 31**, the 9 unarmed **enumerated by id**; the 4 load-bearing ones T778 named are armed here | the 5 new RED arms below, each `expectedFailure` with its owning step |
| 2 | major | ORC-PLAN-4/5 | re-pinned 75 → **80** at `8c00704`, 5 uncounted scripts placed (19/16/45/0); reframed as pin drift, not an authoring error (75 was correct at `a1415fe`) | `TestDispositionCount` — null + seeded control + live check |
| 3 | major | ORC-DASH-4, ORC-DASH-5, ORC-ACC-1 | the T766-retired `window_budgets` meter removed from the pane, its data source, and **the acceptance bar** | (documentary; no mechanism left to arm) |
| 4 | major | ORC-POL-5, ORC-POL-6, §12.2 | ox-alpha RESERVED → free/SPEND per `2ec4f93`; RESERVED restated as a category with **no per-model member**; the sentinel-vs-string design-open **deferred as moot** | `test_keeper_has_no_row_for_ox_alpha_so_it_falls_through_to_spend` |
| 5 | medium | header | one sentence stating T772 (`soloPick`/assignment) and this spec (appetite/caps/cooldowns) are distinct subsystems — no amendment was owed | — |
| 6 | medium | ORC-GOAL-2 | line counts recomputed: 3479 @`a1415fe` → **3608** @`8c00704`; both columns kept because the delta is the finding | — |
| 7 | minor | ORC-REG-1 | "collide gracefully" resolved: **refuse**, naming the alternative filename | (owed: registration battery, P4.4) |
| 8 | minor | ORC-POL-3, ORC-DASH-4 | the family-word/per-model-dial mismatch answered — see row 11, which supersedes the question T778 asked | `test_appetite_is_family_categorical_today_not_a_per_model_dial` |

### Found by T802 while arming (four, all from the census)

| # | sev | id(s) | finding | arm |
|---|---|---|---|---|
| 9 | **major** | ORC-POL-4, ORC-GATE-2 | **the merge was three of four.** `untracked/fleet-keeper.cooldown` is a fourth cooldown — a bare flag file, global, no owner/reason/expiry, dead-man's-switch on an unreadable directory — and it is **the mechanism behind the incident ORC-PAUSE-1 exists to end**. Measured: keeper alive (pid 99956, 3d04h), last dispatch `2026-08-20T18:25:26Z`, **8,747 consecutive idle ticks (~73 h)** with **21 rows dispatchable**. The incident is live, not historical. Both ids amended to include it, and its boolean is the one state whose arithmetic deliberately does **not** survive | `test_a_fourth_global_cooldown_exists_as_a_bare_flag_file` (GREEN) · `test_merge_list_names_every_cooldown_mechanism_that_exists` (RED, step 1) |
| 10 | **major** | ORC-DASH-4, ORC-PLAN-3 step 3 | **step 3 is not a move.** The five sections ORC-DASH-4 specifies and the five `watch-fleet.sh` renders (`PROGRESS`/`CONCERNS`/`RECENT`/`DONE`/`OPEN`) have an **empty intersection**. So T738's omission rule, T739's fill-the-screen rule and T799's footer work attach to sections the spec does not keep, and "replace" deletes a surface the operator uses daily. Recommendation recorded: render both groups under the omission rule | `test_specified_sections_share_nothing_with_todays_sections` (GREEN) · `test_managent_renders_the_five_specified_sections` (RED, step 3) |
| 11 | **major** | ORC-POL-3, ORC-POL-1 | **the 0–9 dial exists in no tracked source file** — only in §7c.11 prose, so "carries over unchanged" has nothing to carry. What exists is **two** per-family categorical tables that **disagree** (`fleet-keeper.sh:325` ollama=SPEND / `main.zig:313` ollama-cloud=OFF, plus different family names). This is an **11th multi-way job**, absent from roadmap §6's ten | `test_the_two_appetite_tables_disagree_today` (GREEN) · `test_one_appetite_table_not_two` (RED, step 1) |
| 12 | medium | ORC-ARB-4 | store-write identity is `std.c.getenv("MANAGENT_TASK_ID")` — the spoofable source ORC-ARB-4 forbids — while `managent` **already** parses `ps -axo pid=,ppid=,…` for the guard path. So step 2 extends an existing process-table reader rather than building one; recorded so it is not re-implemented | `test_identity_is_read_from_the_environment_today` + `test_ppid_machinery_exists_but_serves_the_host_guard_not_attestation` (GREEN) · `test_store_write_authority_is_not_env_derived` (RED, step 2) |

### What rev 2 does not do

It does not touch the eight ratified seed rulings, does not build anything, and does not resolve
the four `[design-open]` items (two inherited, two added by rows 10 and 11) — those are design's,
and §12 now lists all four. **Rev 2 is a spec amendment awaiting ratification, and no absorption
pass may begin before it is ratified**: rows 9–11 each change what a pass must build.
