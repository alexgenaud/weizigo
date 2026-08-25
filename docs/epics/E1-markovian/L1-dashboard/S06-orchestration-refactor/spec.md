# S06 — spec: orchestration refactor (one policy file, one dashboard, one arbiter)

**Artifact type: SPEC** (`docs/infra/sprint.md` — a spec says what we want, testably, for one
pass). **Owner:** deepseek-v4-pro/T748 · **Date:** 2026-08-23 · **Status:** **rev 4 — AMENDED (T822: arm-or-delete — armed count == id count,
32 of 32; five ids deleted: the four ORC-GOAL-* and ORC-GATE-2), awaiting operator ratification.** Rev 1
(PROPOSED) was audited by `claude-sonnet-5`/T778 (verdict RATIFIABLE-WITH-AMENDMENTS, 4 major /
2 medium / 2 minor); T802 discharged all eight and added four of its own, found while writing
the arms. **See §14 (amendment log) for rev 1→2's twelve, each with its arm, rev 3's five, and
rev 3→4's arm-or-delete (T822).** Rev 3 (T813) amends
the policy section only: the operator's 2026-08-23 ruling makes the 0–9 dial and the appetite
class two first-class, co-consulted configurations, retires the `conserve` level, and gives
every cooldown a reason, an end-condition and a scope. Rev 4 (T822) is not an amendment to the
requirements: it closes the gap RACE-X measured (12 of 37 honestly armed at rev 3) by arming
every remaining id and deleting the five ids that are not requirements. Not a worker brief, not a plan, no code.

**Sits on:** the ratified seed (`docs/status/orchestration-refactor-seed-2026-08-23.md` — its
eight rulings are DECIDED, this spec does not reopen them), the existing tools it migrates
(`tools/fleet-keeper.sh`, `tools/window_policy.py`, `tools/directive_policy.py`, `bin/dispatch`,
`bin/subagent`, `untracked/watch-fleet.sh`), `docs/status/orchestration-layer-spec.md` §7c
(rulings in force), `docs/infra/sprint.md` (pass protocol + audit loop),
`docs/infra/model-registry.md` (the one short-name table), `S04-orchestrator-retirement/spec.md`
(its reconciler scope is absorbed here per the seed's feedstock list),
`S05-startup-surfaces/spec.md` (the `orient` sprint, whose startup-prose diet ruling 7 builds on).

**Inputs.** seed §1–§8 + Acceptance + Feedstock + Out-of-scope · `orchestration-layer-spec.md`
§7c.11–34 · `model-registry.md` (short-name table, T732 oxalpha baseline) · T712/T713/T709/T578
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

The migration surface (§8) is **counted, not asserted**: six named tools (§1's scope table —
rev 1 said "5" and undercounted its own document by one, T811 R9) + **82** `tools/
regression-*.sh` scripts live (rev 1 said "75 at HEAD", which was correct at its own pin — the
live count is the ORC-PLAN-4 mechanism's number, and `TestDispositionCount` fails the moment the
declared count and the live count diverge; prose is not a remedy for a mechanism failure). A
script left off ORC-PLAN-4's disposition table is a spec defect, not a reader's problem.

---

## 1. Goal and scope

**The goal (unnumbered — a goal is the §10 acceptance bars, not an id; §0's rule: a
requirement with no control is a wish, and a goal with no mechanism is the same. Rev 1–3
carried this as ORC-GOAL-1; T822 deleted the goal ids because each was a summary of the ids
below and §11 still maps every ruling to its ids).** The fleet's orchestration state lives in
**one policy file** (ruling 1 → ORC-POL-1/2/5/7), its human surface is **one dashboard** in
`bin/managent` (ruling 3 → ORC-DASH-1–5), its pressure response is **one arbiter** (ruling 4 →
ORC-ARB-1–4), its rows register through **one file-first contract** (ruling 5 → ORC-REG-1–4),
its pauses **expire loudly** (ruling 2 → ORC-PAUSE-1–3), its gates are **data, not prose**
(ruling 6 → ORC-GATE-1, ORC-POL-4), its startup prose is **`orient` only** (ruling 7 →
ORC-ORIENT-1), and its models are **registry entries** (ruling 8 → ORC-PROV-1). End state: the
operator sees one pane, dispatches one command, and onboards a model by editing one file — the
three bars ORC-ACC-1 measures.

**The scope number — what this sprint replaces (unnumbered context; the census content is
carried by ORC-PLAN-4's disposition table and `TestAbsorptionTargetsAreLive`. Was
ORC-GOAL-2; deleted by T822).** The refactor collapses, at `HEAD`:

| today | lines @`a1415fe` | lines @`8c00704` | role | goes to |
|---|---|---|---|---|
| `tools/fleet-keeper.sh` | 1169 | 1169 | dispatch loop + cooldown flags + one-writer invariant + appetite/cap enforcement | `managent` arbiter + policy reader |
| `tools/window_policy.py` | 737 | **548** | reset watcher + ~~token meter~~ + fan-out cap | policy file + `managent` arbiter |
| `tools/directive_policy.py` | 176 | 176 | directive staleness + discharge | policy file (expiring pauses) + `managent` |
| `bin/dispatch` | 536 | **546** | dispatch gate + canonicalization | policy reader; gate logic moves to `managent` |
| `bin/subagent` | 557 | **858** | launch chokepoint + provider selection | provider seam (registry entries) |
| `untracked/watch-fleet.sh` | 286 | **311** | dashboard | thin refresh wrapper; rendering moves to `managent` |

Six files, **3461 lines** at the spec's own pin — **3608 at `8c00704`**, recomputed by T802
(T778 finding 6) and corrected by T811 (RACE-X: watch-fleet was **286** at `a1415fe`, not 304 —
304 is the count at `402922f`, six minutes later). Both columns are kept because the *delta* is
the load-bearing fact: T766 removed 189 lines from `window_policy.py`, and the surface still
grew by 147, because `bin/subagent` gained 301 (T713's resident gate, T773's liveness fuse).
**The surface this sprint plans to shrink is growing faster than the sprint is shrinking it** —
at +147 lines in the eight hours between the two pins. That is the argument for ORC-PLAN-3's
one-door-per-pass order over any big-bang cut-over, and the reason the accept question ("did we
actually shrink it") must be answered against a pin taken at accept, never against 3461.

**What is out, named (unnumbered — a scope boundary is prose guidance for builders, not a
testable requirement. Was ORC-GOAL-3; deleted by T822).** claimlint and the science suite
(separate ledger tooling); the history squash (T535, its own spec-first console); race
machinery beyond what the policy file touches. Also out: `tools/runner` itself is **not
rewritten** — it survives as the launch/guard layer; its interaction with the arbiter changes
(§8, REWIRE disposition), its internals do not.

**The reconciler absorption (unnumbered — the pre-pass statement is ORC-ARB-3's and the
fold-point is §12 open question 1; the goal-level restatement was ORC-GOAL-4, deleted by
T822).** The seed's
feedstock list names T578 ("this sprint absorbs its reconciler scope, operator-ratified
direction"). Consequence: the **arbiter is the deterministic pre-pass** (ORC-ARB-3) that S04's
`REC-LIFE-2` was going to build — it applies every (a)/(b) mechanism before any model token is
spent, and a quiet store is a zero-token wake. What is **not** absorbed here is the model-spawn
residue (S04 `REC-LIFE-1`, the verdict/triage reconciler that wakes on a non-empty residue).
That boundary is `[design-open]` (§12 open question 1) because the seed's two statements — "one
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
| oxalpha | **absent** → `other` → SPEND by default fallthrough | family `oxalpha`, SPEND by ruling |

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

**Amendment (T813, 2026-08-23) — the dial and the class are two first-class configurations,
both consulted.** The operator ruled: *"I think BOTH the 0-9 dial and enums convey different
information and BOTH are required. Make BOTH equal first-class configurations, honoured and
consulted during model selection."* They carry different information and must both be consulted:
**the class (enum) is a policy CLASS** — what *kind* of permission the family has and what
condition attaches to drawing it; **the dial (0–9) is a RATE / eagerness** — how strongly to
prefer the model when it is permitted at all. The operator's own note records why both stay:
*"admittedly the number 1 is less informative than RESERVE and PROBE."* `1` says *rarely*;
`RESERVED` and `PROBE` say *why* and *under what condition*. A single scalar cannot carry both,
and neither can a single word. The §7c.11 mechanics carry over unchanged (0 = unliftable hard
forbid, monotone back-pressure between, max = no back-pressure, operator-only raise, auto may
only reduce); the §7c.11 **initial values** are superseded by the operator's 2026-08-23 table
below, which is now the file's seed. The mechanism is ORC-POL-8/9/10; the file rows are in
ORC-POL-5's worked example.

| family | class | dial | the operator's words (2026-08-23), verbatim as rationale |
|---|---|---|---|
| ollama-cloud | `OFF` | **0** | *"DO NOT USE"* |
| claude-fable | `RESERVED` | **1** | *"ONLY when it's the only, necessary and best option"* |
| local (qwen) | `PROBE` | **1** | *"ONLY when we believe/hope to get some good test results"* |
| claude (opus / sonnet / haiku) | `SPEND` | **4** | *"available but dice roll leans deepseek, all else equal"* |
| deepseek (dspro / dsflash) | `SPEND` | **5** | *"reliably available"* |
| oxalpha | `SPEND` | **9** | *"test whenever you get the opportunity"* |

The dial is per **model** (the family numbers above are the family *default dials* — §7c.11's
"bulk convenience"); the class is per **family**. A model with no dial row inherits its family's
default (ORC-POL-10, materialized — never a hidden fallback).

**ORC-POL-4 (the cooldown mechanisms merge — ruling 6; absorbs ORC-GATE-2, which T822
deleted as a duplicate of this id — one machine, one T802 amendment, the same arms).**
heal (T504), dispatch (T536), window
(T628/T677) **and the global keeper flag** cooldowns become **one visible state machine** in the
policy file, with one namespace, one dashboard row each, and one visible transition set. The
merge is a *schema* fact, not a behaviour change: each cooldown's arithmetic survives as a
named state of the machine — T504 heal, T536 dispatch, T628/T677 window, the flag file's
boolean (rev 1's "(§6 specifies the states.)" cross-reference was wrong — §6 is the
registration flow; §7's ORC-GATE-2 named the states, and its content folds here).

**Amendment (T802) — the merge was three of four, and the omitted one is the one with the
incident.** Rev 1's two homes for the merge — this id and its §7 twin (then ORC-GATE-2, folded
here by T822) — named three mechanisms. There is a fourth:
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

**Amendment (T813, 2026-08-23) — the merge separates two mechanisms the name conflates.** A
cooldown is **prohibition** (do not draw until the end-condition), and every cooldown carries
**scope**, **reason** and **end** (ORC-POL-11/12); a **rate reduction** is the **dial**, not a
cooldown. The current auto-cooldown (provider limit → `FALLBACK_COOLDOWN_SECONDS`) is one row of
this machine — scope `family`, reason `provider-limit`, end `duration` — not the whole concept.

**ORC-POL-5 (schema — worked example, the full file).** The file is JSON (the project's
store convention), at `docs/infra/orchestration-policy.json` (committed, diff-reviewed — it is
the gate-as-data artifact, so it lives in git, not `untracked/`). Runtime *state* (who is cooled
down *right now*) stays in the store/run-records, never in the policy file — the file is the
**parameters**, the store is the **fact**.

```json
{
  "schema_version": 2,
  "note": "Every entry carries owner, reason, expiry. Env vars override only; nothing here is a hidden default. A family row carries BOTH a class (the permission kind) and a dial (the eagerness — the family DEFAULT, which member models inherit unless a model_dials row overrides it). Cooldowns are prohibitions, each with scope + reason + end; rate reduction is a dial, never a cooldown.",
  "appetite": [
    {"family": "ollama-cloud", "class": "OFF",      "dial": 0, "owner": "operator", "reason": "DO NOT USE (operator 2026-08-23)", "expiry": "next-ollama-quota-refresh"},
    {"family": "claude-fable", "class": "RESERVED", "dial": 1, "owner": "operator", "reason": "ONLY when it's the only, necessary and best option (operator 2026-08-23)", "expiry": null},
    {"family": "local",        "class": "PROBE",    "dial": 1, "owner": "operator", "reason": "ONLY when we believe/hope to get some good test results (operator 2026-08-23)", "expiry": null},
    {"family": "claude",       "class": "SPEND",    "dial": 4, "owner": "operator", "reason": "available but dice roll leans deepseek, all else equal (operator 2026-08-23)", "expiry": null},
    {"family": "deepseek",     "class": "SPEND",    "dial": 5, "owner": "operator", "reason": "reliably available (operator 2026-08-23)", "expiry": null},
    {"family": "oxalpha",     "class": "SPEND",    "dial": 9, "owner": "operator", "reason": "test whenever you get the opportunity (operator 2026-08-23; supersedes T732 RESERVED and the rev-2 dial 6)", "expiry": "blind-test-reveal"}
  ],
  "model_dials": [],
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
longer true**: the operator flipped oxalpha to free/SPEND on 2026-08-23 (`2ec4f93`, recorded in
`landmark-waypoints-seed-2026-08-23.md` §5), three hours after this spec's pin. RESERVED's only
remaining member is `claude-fable-5` **as a family appetite**, not as a per-model dial — so the
category still exists but has **no per-model subject at all**, and the §12 `[design-open]`
choice between a `-1` sentinel and an explicit `"RESERVED"` string has **no live consumer**.
Design should not spend a cycle on it; the sentinel-vs-string choice is deferred until something
is actually RESERVED per-model, and the recommendation (explicit string) stands as the answer
for that day.

There is a second, live problem this id must own. `tools/fleet-keeper.sh` has **no oxalpha row
at any granularity**: `family_of("oxalpha")` → `"other"` → `APPETITE.get("other", "SPEND")` →
SPEND. The keeper therefore never honoured RESERVED for oxalpha — before the 2026-08-23 ruling
it would have auto-dispatched an identity-sealed model, and it is *accidentally* correct now.
Armed as `TestAppetiteDial.test_keeper_has_no_row_for_ox_alpha_so_it_falls_through_to_spend`
(T802). ORC-PLAN-3 step 1 must fix the fallthrough, not inherit it: **an unknown model resolves
to a refusal, never to a default appetite.** A default that silently permits is the D036 class
this sprint exists to kill.

**Amendment (T813, 2026-08-23) — RESERVED and PROBE are class values with row-flag conditions,
not dial sentinels.** ORC-POL-8/9 re-spec the level: `RESERVED` and `PROBE` are per-**family**
classes that gate on a row flag (`reserved` / `probe`), not sentinels on a per-model dial. Their
live subjects are `claude-fable` (RESERVED) and `local` (PROBE), so the "no per-model subject"
framing above is superseded — the subject is per-family, and the condition that did not exist now
does (ORC-POL-9). The §12.2 sentinel-vs-string question is moot for a new reason: there is no
sentinel to encode, because the class is not a value on the dial axis.

**ORC-POL-7 (env vars are overrides, and overrides are recorded).** The existing knobs
(`FLEET_MODEL_ALLOW/DENY`, `FLEET_APPETITE`, `FLEET_FAMILY_CAP`, `WEIZIGO_DIRECTIVE_STALE_HOURS`)
keep working **as overrides of a file entry**, and an override is appended to
`untracked/fleet-window-overrides.jsonl` with the reason it was needed (the T677 override-recording
precedent, generalized). A knob with no corresponding file entry is refused with "add it to the
policy file or it is not a knob" — the D036 silent-default class dies here. (T766: `WEIZIGO_WINDOW_BUDGET_*` knobs retired.)

**ORC-POL-8 (the dial is a draw weight — 0 excludes, 1–9 weights; `conserve` is retired).** For
a model `m`, `dial(m) ∈ {0,…,9}`. `dial(m) = 0` excludes the model from every draw (hard forbid,
"DO NOT USE" — §7c.11's unliftable forbid). `dial(m) ≥ 1` admits the model to a **weighted draw**
with weight `dial(m)`: draw probability ∝ weight. The dial's only effect on a `≥1` candidate is
its weight — **lowering a dial lowers a model's draw share, it never removes it** (rate reduction
is not prohibition; the class gate and dial 0 are the only removals). `dial = 9` means "draw it at
every reasonable opportunity": the model is the modal outcome whenever it is qualified (its weight
is the scheme's maximum). A dial of 5 versus 4 is a defined, checkable effect: two candidates at 5
and 4 draw in proportion 5:4 (5/9 vs 4/9).

**Dead-level disposition (decided per level — a level with no observable behaviour is not a level):**

| level | disposition | reason |
|---|---|---|
| `off` | **keep** as a class | the family-level hard forbid ("DO NOT USE"); it is what dial 0 means at family scope, and it is the only level with an observable branch today |
| `probe` | **keep, and specify** | names "probe-flagged rows only" — the flag does not exist today, so ORC-POL-9 defines it (row flag `probe`); the operator values it: "1 is less informative than PROBE" |
| `conserve` | **RETIRE** | no branch today — `filterQualified` treats it exactly as `spend` (falls through to the candidate list). Its meaning, "use less, keep using", is precisely the dial's 1–3 range: a *rate*, not a *permission kind* |
| `spend` | **keep** as a class | the general permission ("available"); the dial carries *how eagerly* within it |
| `reserved` | **keep, and specify** | names "reserved task types only" — the task-type test does not exist today, so ORC-POL-9 defines it (row flag `reserved`); the operator values it: "1 is less informative than RESERVED" |

**ORC-POL-9 (selection consults class first, then the dial among the qualified — the order, with
"all else equal" defined).** Selection applies, in order: **(1) class gate** — `OFF` out always;
`RESERVED` in only when the row carries `reserved`; `PROBE` in only when the row carries `probe`;
`SPEND` in always; **(2) dial-0 forbid** — a model at dial 0 is out (a model-level "DO NOT USE"
inside a class-admitted family); **(3) qualification** — methodology §5's gate (score ≥ threshold,
no fabricated citations, verification ≥ floor): a model that fails it is out *even at dial 9*; an
**unmeasured** model is eligible (D027 exploration-first: unmeasured is a reason to *try*, never to
exclude and never to prefer — T772); **(4) the dial weights the draw** among the survivors,
probability ∝ dial; **(5) cost is reported, never consulted** — `shape_reasons` may state measured
costs, they never decide a pick (T772 ratified: cost is removed from model choice entirely). **"All
else equal"** is defined by (1)–(3): candidates that survive the class gate, the dial-0 forbid and
the qualification gate, with the dial the sole remaining discriminator — which is exactly the
operator's "dice roll leans deepseek, all else equal": deepseek's 5 outdraws claude's 4, and only
there.

The two row flags — `reserved` (the §1 reserved task types: deep holistic review, gate-holder
verification, spec/design adjudication; never one-off/general) and `probe` (exploration-only rows;
never during a measured suite run) — are row-declared in the bundle header and read by the one
parser (ORC-REG-2); their position in the registration contract is design's (ORC-REG-3's field
list grows by two), their **semantics** are normative here. An `oxalpha` at dial 9 is drawn at
every reasonable opportunity *because* it passes (1)–(3) on the rows where it is qualified and
then carries the maximum weight — not because it bypasses any of them.

**ORC-POL-10 (dial inheritance is materialized, never a hidden fallback).** The policy file
declares a dial per **model short name** and a **default dial per family** (the operator's
2026-08-23 table is the initial family defaults). A model with no explicit dial row **inherits its
family's default dial, and the inheritance is materialized** — the reader resolves every model to
a concrete dial at parse time and the dashboard renders the resolved dial, so the inheritance is
never a fallback nobody can see. A model whose family has no default dial is a **parse error**
(refused, like an entry with no owner/reason — ORC-POL-2), never silently drawn at an invented
default. The per-model override is how §7c.11's "family setting is bulk convenience" is honoured:
a family default is the bulk write; a `model_dials` row is the unit of record for a model that
differs.

**ORC-POL-11 (rate reduction is the dial; cooldown is prohibition — and every cooldown carries
scope, reason, end).** The two mechanisms ORC-POL-4's machine conflates are distinct: **rate
reduction = the dial** (use less, keep using — dial 1–8, never a prohibition); **cooldown =
prohibition** (do not draw *at all* until the end-condition, however long that is). Every cooldown
record carries three required fields — `scope` (one model / one family / the whole fleet), `reason`
(the ORC-POL-12 enumeration), `end` (one of the three ORC-POL-12 forms) — plus owner and creation
time. A cooldown missing any of the three is refused at parse (ORC-POL-2). The current auto-cooldown
(a terminal run record showing a provider limit, `FALLBACK_COOLDOWN_SECONDS` 30 min or a parsed
reset) is **one row** of this machine — scope `family`, reason `provider-limit`, end `duration` —
not the whole concept, and it no longer gets to use the general name alone.

**ORC-POL-12 (the cooldown reason enumeration, the three end-condition forms, the scope axis).**

Reasons (the enumeration to start from — extended by adding a name, never by omitting one):

| reason | what it is |
|---|---|
| `provider-limit` | today's automatic case — a terminal run record showed a provider limit |
| `graceful-shutdown` | the fleet is shutting down deliberately |
| `reserve-queue-for-refactor` | hold the queue for a large refactor; do not resume until it is done |
| `preserve-tokens-before-reset` | save tokens ahead of a family reset |
| `operator-manual` | the operator flipped it by hand |

End-conditions (exactly three forms):

| form | example | note |
|---|---|---|
| `duration` | "cooldown Claude for the next 3 h 34 min" | an ISO instant or a seconds count; expires itself |
| `until` | "do not resume until the refactor task `<T-id>` is done" | a named condition re-evaluated at every read — the `managent tell … pause --until-done <T-id>` mechanism, generalized to a family or the fleet |
| `indefinite` | "graceful shutdown" | pending a human flip; **visible and never silently expiring** — it does not lapse, it waits |

Scope axis: `model` (one short name) · `family` (one family) · `fleet` (all). The current machine
is `family`-only; `model` and `fleet` are new, and `fleet` is what the 2026-08-20→23 keeper flag
effectively was — but as a scoped, owned, expiring record, not a bare file.

**ORC-POL-13 (a cooldown is legible or it does not exist).** Every cooldown renders on the
dashboard as one row — **what** is cooled (scope), **why** (reason), **when/on-what it ends**
(end-condition) — beside the pauses section (ORC-PAUSE-3, ORC-DASH-4). A prohibition nobody can
see is how the keeper stayed paused from 2026-08-20 without anyone noticing (the ORC-PAUSE-1
incident); the `indefinite` form is the one that most needs the row, because it is the one that
will not lapse on its own.

**Worked example — one real task type, dial ordered, one dial moves by 1 (ORC-POL-9).** Take
**audit** (27 % of task-type share, §1). A plain audit row (no `reserved`/`probe` flag):

- **class admits**: `claude` (opus, sonnet, haiku), `deepseek` (dspro, dsflash), `oxalpha`.
  `ollama-cloud` is OFF (glm, minimax, kimi out); `claude-fable` is RESERVED and audit is not a
  reserved task type (fable out); `local` is PROBE and audit is not probe-flagged (qwen out).
- **dial orders** (all at family defaults; no `model_dials` override): weights opus 4 · sonnet 4 ·
  haiku 4 · dspro 5 · dsflash 5 · oxalpha 9, sum 31. Draw shares: oxalpha 9/31 ≈ 29 %; dspro
  and dsflash 5/31 ≈ 16 % each; opus, sonnet, haiku 4/31 ≈ 13 % each. (Assuming each admitted
  candidate passes §5 or is unmeasured — D027 admits unmeasured; a §5 failure drops out regardless
  of dial.)
- **one dial moves by 1**: raise haiku 4 → 5. Sum becomes 32; haiku rises 4/31 ≈ 12.9 % → 5/32 ≈
  15.6 %, oxalpha falls 9/31 ≈ 29.0 % → 9/32 ≈ 28.1 %, the other four fall by the same
  renormalization. The effect is exactly the dial's: a +1 raises one model's draw share and
  lowers every other survivor's — it never removes anyone, and it never reaches a candidate the
  class or qualification gate already dropped.

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

**ORC-DASH-4 (the one pane — worked example, illustrative data).** The pane has exactly five sections —
keeper liveness, pauses, appetite + cap, benched models, and the queue head — all from
the store + policy file at read time. Rendered against the live store at `a1415fe` (live values
marked ●; every row whose store state could not be verified at the pin is marked ◇ and is
illustrative, never a claim — T810 R5 found the queue row of rev 3 was invented, listing rows
that did not exist at the pin; the corrected store numbers below are T810's own census):

```
● keeper       alive · lease pid 29107 · last tick 2s ago (interval 10s)
◇ pauses       dsflash: cooldown-test — "you've hit your session limit" · age 0h12 · expires in 0h48
               (illustrative ◇ — directives.jsonl is append-only and non-empty; no live
               enforcing pause at the pin, which is the point: the pause row renders)
● appetite
   family         appetite   cap
   claude         SPEND      3    (claude-fable RESERVED — runs alone)
   deepseek       SPEND      6
   ollama-cloud   OFF        5    (deny: glm, minimax, kimi — quota; see §14 rev 3→4 for the
                                  operator's 2026-08-24 return-to-SPEND ruling)
   local          PROBE      1
   oxalpha       SPEND      —    (free while the blind test runs, 2026-08-23)
● benched       (none benched at HEAD — deepseek-v4-flash last benched 2026-08-20, T544 failures=6, now clear)
◇ queue         in_progress 3 (T527 T700 T723) · dispatchable 26 · blocked 1
               (illustrative ◇ — real store census at the pin, per T810 R5; the rev-3
               T724/T733/T739 numbers were invented: T733/T739 did not exist at `a1415fe`)
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

**ORC-ARB-1 (one decision point — amended rev 4, T822: the shed order restates the ratified
T821/ram-policy build, which landed ahead of this sprint's P4.2; the rev-1 phrase "inside
`managent`" is amended because the decision is enforced where the lane is launched).**
Host-pressure and shed-load decisions live in
**one arbiter** — built by T821 in `tools/runner`, the launch chokepoint every lane passes
through (`bin/subagent` is its only caller). Under real pressure it responds in the order
`docs/infra/host/ram-policy.md` ratifies: **(1) refuse new admissions** — a lane whose declared
need does not fit what is already admitted is refused before anything is spawned, the row stays
dispatchable, zero tokens spent (rev 1's "pause/queue new dispatches first"); **(2) stop a lane
only for its OWN overrun** — `--rss-cap-mb`, sized to the declaration, is the only remaining
stop, always that lane's own (INV-1; rev 1's "stop the newest or least-progressed lane next"
was superseded by ram-policy's futile-kill finding: 16 of 20 recorded kills were futile, 0 of
20 necessary and effective); **(3) alarm, never kill, when a host-wide consumer is identified**
— the L3 alarm names the real top consumer (T712's "target a specific consumer only when one
is actually identified", minus the kill). The arbiter **absorbs** T712 (one arbiter, no
per-runner kills) and T713 (resident-tenant dispatch check — the resident model declares its
registry RAM figure at admission; list-wait is acceptable, mid-run fratricide is not). T711's
declared-tenant fix already landed and is a prerequisite, not a co-deliverable. Its control
battery is `tools/regression-arbiter.sh` (T821, SURVIVE — the P4.2 bar itself, not a thing
under test); the REWIRE of the twelve still-live `regression-runner-*.sh` entries to the
arbiter remains owed to the pass that formally closes P4.2 (see the ORC-PLAN-4 amendment).

**ORC-ARB-2 (a guard may stop a lane, no guard may attribute — §7c.31, mechanical).** The
arbiter stops lanes; it never scores models. `killed_by` stays an enumerated value written from
the runner's own terminal record, and any row with `killed_by != none` is refused by every
scorer with the skip count stated. The arbiter's stop is a harness decision; attribution is a
measurement decision; the two never share a code path.

**ORC-ARB-3 (the arbiter is the reconciler pre-pass — §1 prose, was ORC-GOAL-4).** The arbiter's deterministic
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
to produce (the inventory is §12's deferred-to-design list); the *principle* is normative: a gate that exists
to enforce a taste, not a safety invariant, is a warning.

**Deleted in rev 4 — the former `ORC-GATE-2` (a duplicate of ORC-POL-4).** Rev 1–3 carried the merged
cooldown machine twice — here under the gate diet (ruling 6) and in §2 as ORC-POL-4 — with the
same T802 amendment, the same arms, and the same single machine. One id for one machine: the
merge contract (one namespace, one dashboard row each, one visible transition set) and the
flag-file behaviour change (its boolean becomes a scoped, owned, expiring state — the only
behaviour change the merge makes, because a state with no expiry cannot belong to a machine
whose defining property is that pauses lapse loudly) are all ORC-POL-4's now. Ruling 6's
traceability row (§11) maps to ORC-GATE-1 + ORC-POL-4.

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

**ORC-PLAN-4 (regression scripts — counted disposition).** 83 `tools/regression-*.sh` at `HEAD`.
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

**Amendment (T821, 2026-08-24).** `docs/infra/host/ram-policy.md` (T806, ratified 2026-08-23)
built the ORC-ARB-1 arbiter directly — ahead of, not inside, this sprint's P4.2 phase order
("taken first… passes are sequenced by dependency, not by number," T821's own brief) — because
every guard defect in `tools/runner`'s host-pressure path routed through it and the pressure was
live (2026-08-23 15:19:09, four lanes dead in 88s). Three landings, live count 81 → **82**:

| script | change | disposition |
|---|---|---|
| `regression-arbiter.sh` (new, T821) | the arbiter's own controls: real co-launch, futile-kill, effective overrun-stop, refusal, null | **SURVIVE** — the new standing control, the P4.2 bar itself (`orcha-acceptance.sh`'s pattern: the gate is not a thing under test) |
| `regression-subagent-resident-gate.sh` | the T713 gate it tested is deleted (ram-policy.md §6 items 8-9); retired to an exit-0 banner naming the reason | **ABSORB, done early** — this row's own §708-715 P4.2 listing already named it; T821 discharges it ahead of the formal phase close |
| `regression-runner-host-guard.sh` | the T362/T711 floor it tested is deleted (ram-policy.md §6 items 1-2, 5); retired to an exit-0 banner naming the reason | **REWIRE, done early** — this row's own §728 P4.2 listing already named it; T821 discharges it ahead of the formal phase close |

The ABSORB-19/REWIRE-16/SURVIVE-45 bucket sums two paragraphs below are **not** rebalanced by this
amendment — both retired scripts were already named inside those buckets (they are being
*discharged* early, not reclassified), and the one new script is a fresh SURVIVE addition of
exactly the same shape T801 recorded for `regression-canonicalizer-parity.sh`. A full phase-P4.2
reconciliation (rewiring the twelve still-live `regression-runner-*.sh` REWIRE entries at §728 to
the arbiter this row built) remains owed to whichever pass formally closes P4.2.

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

**SURVIVE — 46** (out of scope; untouched): the 19 remaining `regression-managent-*` scripts
(assert-store, attribution, build-mode, concurrency, done-git, done-two-phase, duty, holds,
impression-gate, integrity, lanes, ledger-board-seam, lock, memory-safety, resume, standing,
status-json, store-pollution, store-write-utf8) — they already test the `managent` binary that
grows, and are extended in place, not absorbed; plus the out-of-scope domains: claimlint ×6
(c7-json, c7-scope, output, promotion, volatile, claim-lifecycle), absorption-machinery,
argus-doctor, orphan-reaper, bakeoff-gates, battery-baselines, battery-sweep, complementarity,
model-profiles, race-p0, race-collect, gtp-boardsize, T227, suite-surfaces, commit-concurrency, git-commit-mine,
git-commit-mine-hook, process-ownership, pilot-gate, orcha-acceptance, precommit,
regression-dispatch-caps.sh (new, T845 — the fleet-cap gate's own controls: cap-2 fixture,
per-family, recorded override, null, shared-counter, one-writer). `orcha-
acceptance.sh` survives as the bar itself (it is the P5 gate, not a thing under test).

**ORC-PLAN-5 (silent truncation is a defect — now mechanized).** The disposition table's counts
sum to **80**, the `ls tools/regression-*.sh | wc -l` at `8c00704`; the T801 addition brought the
live count to **81**, the T821 amendment (one new SURVIVE script, two early discharges of
already-listed entries) brought it to **82**, and the T845 amendment (one new SURVIVE script,
`regression-dispatch-caps.sh`) brings it to **83** (see the ORC-PLAN-4 amendments). If a later phase retires a
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
requirement, it is a wish"*). RACE-X (T810/T811/T812) re-measured rev 3 and found the honest
count was **12 of 37** — the flips column is a plan, not an inventory (R1), four of the seven
T802 arms could not observe their subject (R2), and no id met §0's own null+seeded predicate
(R7). T822 (rev 4) is the convergent close: **armed count == id count == 32 of 32**, with the
predicate stated — an id is armed iff at least one arm exists **on disk** whose subject is the
id (the §0 null+seeded pair is the P3 battery's bar, ORC-CTRL-2, not the census predicate; a
RED arm with a named owning step is a recorded defect, and turning it green is the step's own
acceptance).

The 15 flips-column ids are all armed on disk now: fourteen carry a **RED spec-conformance
arm** (T822) in `tests/unit/test_s06_conformance.py` naming the ORC-PLAN-3 step that owes the
mechanism — ARB-2, ARB-3, DASH-2, DASH-3, DASH-5, PAUSE-1, PAUSE-2, POL-2, POL-7, PROV-1,
REG-1, REG-2, REG-3, REG-4 — and ARB-1 is armed GREEN because T821 built its mechanism ahead
of P4.2 (admission arbiter; battery `regression-arbiter.sh`). On top of the arms T802 wrote
(POL-1, POL-3, POL-4, DASH-1, DASH-4, ARB-4) and T813 wrote (POL-8…13), plus T822's arms for the ids that had
none (POL-5, POL-6's conformance half, POL-13, PAUSE-3, GATE-1, ORIENT-1). The adjacent arms
RACE-X flagged were replaced, not kept: POL-4's prose-regex arm (whose green condition was a
spec edit) is now a code-signature arm over the policy reader, and DASH-1/DASH-4's substring
greps are strengthened with the watch-fleet-thin half. Cross-tier arms are credited, not
duplicated: ORC-ORIENT-1's ≤150-line cap is behaviorally held by `regression-orient.sh` (T353);
ORC-REG-4's dropped-edge control by `regression-managent-holds.sh` (T539); ORC-ARB-1's battery
is `regression-arbiter.sh` (T821, SURVIVE — the P4.2 bar itself). The T802/T813 arms are **RED
by construction and correct to be red** (ORC-CTRL-2: red first): each is
`@unittest.expectedFailure` naming the ORC-PLAN-3 step that owes the mechanism, paired with a
GREEN *characterization* arm pinning what the subject does **today** — so a migration step
cannot change today's behaviour silently, and cannot mark the id armed without turning its red
arm green. T822's arms follow the same pattern (35 GREEN characterization / 28 RED conformance,
63 arms total, 0.1 s).

**Deleted by T822 — five ids, so the count is 32, and armed == id holds.** `ORC-GOAL-1..4` (the
four goal statements) carried no mechanism to observe — each was a summary of the ids under it
and of §10's acceptance bars, and this spec's own rev-2 census said a goal that cannot be armed
"should be a measurable acceptance bar in §10 or should not carry an id". Their prose stays in
§1, unnumbered. `ORC-GATE-2` was a duplicate of `ORC-POL-4` — one machine, one T802 amendment,
the same arms; the merge contract and the flag-file behaviour change fold into POL-4. Zero new
ids were added (T822 found no missing requirement; candidates, if any, are noted in its
findings file only).

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
| C9 | arbiter shed order | pressure: a lane whose declared need cannot be admitted, or a mid-run lane over its own cap | refused before spawn (row stays dispatchable); the only stop is the lane's own overrun; never kills to admit | ORC-ARB-1 |
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
| 4 one arbiter | ORC-ARB-1–4 |
| 5 registration flow | ORC-REG-1–4 |
| 6 gate diet | ORC-GATE-1, ORC-POL-4 (ORC-GATE-2 folded in, T822) |
| 7 startup-prose diet | ORC-ORIENT-1 |
| 8 provider seam | ORC-PROV-1 |
| Acceptance (3 days + onboarding + one pane) | ORC-ACC-1 |
| Feedstock T712/T713 | ORC-ARB-1 |
| Feedstock T578 (reconciler scope) | ORC-ARB-3 + §1 prose (was ORC-GOAL-4, deleted T822) |
| Feedstock T709 | ORC-REG-1 (mechanical store-write refusal subsumes the rc=0 reconcile) |
| T747 landmark gate | ORC-REG-3 (field 3) |
| T738/T739 dashboard trim | ORC-DASH-2/3 |
| §7c.11/12 appetite | ORC-POL-3/8/9/10 |
| Operator ruling 2026-08-23 (dial + class both required) | ORC-POL-3, ORC-POL-8/9/10 |
| Operator ruling 2026-08-23 (cooldown = prohibition, reason/end/scope) | ORC-POL-11/12/13 |
| T772 ratified (cost removed; qualification first) | ORC-POL-9 |
| §7c.31 guard vs attribution | ORC-ARB-2 |
| §7c.18 kernel-attested identity | ORC-ARB-4, ORC-REG-1 |
| §7c.21 two-tier closure + audit cap | ORC-REG-3 (field 5), ORC-ACC-3 |
| T778 audit (8 findings) | §14 amendment log, rows 1–8 |
| T802 census + arms (4 findings) | §14 amendment log, rows 9–12; `tests/unit/test_s06_conformance.py` |
| Goal statements (were ORC-GOAL-1..4) | §1 prose (unnumbered) + §10 acceptance; deleted T822 |
| RACE-X census closure (12 of 37 honest) | §9, §14 rev 3→4; `tests/unit/test_s06_conformance.py` |

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

1. **The reconciler fold-point** (was ORC-GOAL-4, deleted by T822 — the pre-pass statement is
   ORC-ARB-3's and the goal prose is §1's): (a) absorb the model-spawn into this sprint's
   build, or (b) ship the arbiter pre-pass first, model-spawn as a successor row. **Recommend
   (b)** — an unshipped pre-pass cannot audit a model-spawn.
2. **RESERVED encoding** (ORC-POL-6): `-1` sentinel vs explicit `"appetite": "RESERVED"` string.
   **Recommend the explicit string** — but **DEFERRED, no live consumer** (amended T802, T778
   finding 4): oxalpha was RESERVED's only per-model subject and is now free/SPEND, so design
   would be choosing an encoding for an empty category. **Amended T813:** moot for a new reason —
   RESERVED/PROBE are class values with row-flag conditions (ORC-POL-9), not values on the dial
   axis, so there is no sentinel to encode; the class is a distinct field (`"class": "RESERVED"`),
   and its live subjects are `claude-fable` (RESERVED) and `local` (PROBE).
3. **The appetite mechanism itself** (ORC-POL-3) — **RESOLVED by the operator, 2026-08-23**
   (T813): the per-model 0–9 dial and the per-family categorical word are **both** first-class,
   because they carry different information — the class is the *permission kind* (what condition
   attaches), the dial is the *eagerness* (how strongly to prefer when permitted). "Recommend
   the dial" (rev 2) is superseded: both stay, and ORC-POL-8/9/10 specify the division of labour.
   The one genuinely open composition point is §12.5 (dial eagerness vs D027 least-data).
4. **The dashboard's section set** (ORC-DASH-4, added T802): replace today's five task-view
   sections with the five fleet-view sections, or render both under the omission rule.
   **Recommend both** — the specified set shares nothing with the existing set, so "replace" is
   a deletion of a surface the operator uses daily.
5. **Dial eagerness vs D027 least-data** (ORC-POL-9, added T813): among candidates at *equal*
   dial, does the draw stay uniform, or does T772's exploration-first least-data rule prefer the
   less-measured model? The operator's dial is a standing eagerness signal; least-data is a
   per-selection exploration signal; their composition inside a weighted draw is `[design-open]`.
   **Recommend uniform among equal dials** (a weighted draw's natural "all else equal"), with
   least-data available to a row's own shape picker (T772's `soloPick`/`panelPick`) as a
   secondary signal — and neither rule silently dropped.

**Deferred to design (the spec states the principle, design states the mechanism):**

- the merged cooldown machine's exact state set and transitions (ORC-POL-4 — ORC-GATE-2 was
  folded into it by T822);
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
`tests/unit/test_s06_conformance.py` (hermetic, stdlib-only, **63 arms — 35 GREEN
characterization, 28 RED spec-conformance covering 32 ids**, 0.1 s) unless stated. A
**documentary row** — a change with no mechanism to observe — says so and is exempt; every
other row names its arm. (RACE-X finding R11 flagged rows 3/5/6/7 below as unarmed; rev 3→4
arms or resolves each: row 3 → `TestRetiredMeter` (the meter's absence from the code), rows 5
and 6 are documentary-exempt and now say so, row 7 → ORC-REG-1's conformance arm.)

### Discharging T778 (`findings/T778-s06-spec-audit.json`)

| # | sev | id(s) | what changed | arm |
|---|---|---|---|---|
| 1 | major | ORC-CTRL-1 | universal-coverage claim withdrawn; armed count **stated as 22 of 31**, the 9 unarmed **enumerated by id**; the 4 load-bearing ones T778 named are armed here | the 5 new RED arms below, each `expectedFailure` with its owning step |
| 2 | major | ORC-PLAN-4/5 | re-pinned 75 → **80** at `8c00704`, 5 uncounted scripts placed (19/16/45/0); reframed as pin drift, not an authoring error (75 was correct at `a1415fe`) | `TestDispositionCount` — null + seeded control + live check |
| 3 | major | ORC-DASH-4, ORC-DASH-5, ORC-ACC-1 | the T766-retired `window_budgets` meter removed from the pane, its data source, and **the acceptance bar** | `TestRetiredMeter` (T822: the meter's knobs are gone from every tracked source — a documentary row held by the deletion's absence) |
| 4 | major | ORC-POL-5, ORC-POL-6, §12.2 | oxalpha RESERVED → free/SPEND per `2ec4f93`; RESERVED restated as a category with **no per-model member**; the sentinel-vs-string design-open **deferred as moot** | `test_keeper_has_no_row_for_ox_alpha_so_it_falls_through_to_spend` |
| 5 | medium | header | one sentence stating T772 (`soloPick`/assignment) and this spec (appetite/caps/cooldowns) are distinct subsystems — no amendment was owed | documentary (no mechanism to observe) |
| 6 | medium | ORC-GOAL-2 | line counts recomputed: 3479 @`a1415fe` → **3608** @`8c00704`; both columns kept because the delta is the finding; T811 later corrected the pin figure to 3461 | documentary (no mechanism to observe; the census content is held by `TestAbsorptionTargetsAreLive` and ORC-PLAN-4) |
| 7 | minor | ORC-REG-1 | "collide gracefully" resolved: **refuse**, naming the alternative filename | ORC-REG-1's conformance arm (T822): `test_direct_tasks_json_edits_fail_mechanically` |
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

### Rev 2 → rev 3 (T813, 2026-08-23) — appetite dial + class, cooldown reasons

Amends the policy section only. Every row names the id it changed and the arm that holds it;
arms live in `tests/unit/test_s06_conformance.py` (7 new arms — 3 GREEN characterization, 4 RED
spec-conformance), text analysis of `src/managent/main.zig` and `tools/window_policy.py`.

| # | id(s) | what changed | arm |
|---|---|---|---|
| 1 | ORC-POL-3, ORC-POL-8 | the operator's ruling makes the 0–9 dial and the class two first-class configurations; the dial reference table (0/1/1/4/5/9) is the new initial config, superseding §7c.11's 2026-08-22 numbers; `conserve` retired | `test_conserve_has_no_branch_today` (GREEN) · `test_dial_is_a_weight_and_zero_excludes` (RED, step 1) |
| 2 | ORC-POL-9, ORC-POL-6 | selection order class→dial-0→qualification→weighted-draw→cost-reported; `reserved`/`probe` conditions now exist as row flags | `test_reserved_and_probe_name_conditions_that_do_not_exist_today` (GREEN) · `test_selection_consults_class_then_qualification_then_dial` (RED, step 1) |
| 3 | ORC-POL-10 | dial inheritance is materialized (family default + per-model override), never a hidden fallback | `test_dial_inheritance_is_materialized_not_hidden` (RED, step 1) |
| 4 | ORC-POL-4, ORC-POL-11/12/13 | rate reduction = dial vs cooldown = prohibition; every cooldown carries scope + reason + end; the reason enumeration, three end-forms, and scope axis are specified | `test_todays_auto_cooldown_is_one_narrow_case` (GREEN) · `test_cooldown_carries_reason_end_and_scope` (RED, step 1) |
| 5 | ORC-POL-5 | the worked example's `appetite` array becomes family class + default dial (operator's table) plus an explicit `model_dials` override list; `schema_version` 1→2 | (documentary — held by row 1's dial arm) |

The 6 new ids (POL-8…13) each carry an arm; none of the 9 pre-existing unarmed ids is newly
armed by this amendment, and no id is added unarmed.

### Rev 3 → rev 4 (T822, 2026-08-24) — arm or delete, no third option

RACE-X (T810/T811/T812) measured the honest on-disk arm count of rev 3 as **12 of 37** (the
spec claimed 28). This revision is the convergent close, not a fourth amendment round: per
unarmed id, exactly ARM or DELETE. Outcome — **armed count == id count == 32 of 32**; the five
non-requirements are gone (see §9 for the full accounting and the armed-predicate statement).
Every arm below is on disk in `tests/unit/test_s06_conformance.py` (63 arms: 35 GREEN / 28 RED)
unless a cross-tier script is named. Zero new ids were added.

| # | id(s) | decision | arm / deletion reason |
|---|---|---|---|
| 1 | ORC-GOAL-1 | **DELETE** | a goal is the §10 acceptance bars, not an id — its content is the union of the ids under it and ORC-ACC-1's three bars; §0 forbids numbering a wish. Prose stays in §1, unnumbered | (no arm — deleted) |
| 2 | ORC-GOAL-2 | **DELETE** | the scope census, not a requirement — the six-file surface is held by `TestAbsorptionTargetsAreLive` and ORC-PLAN-4's disposition table. Prose + corrected table stay in §1 (T811's 286/3461 figures adopted) | (no arm — deleted) |
| 3 | ORC-GOAL-3 | **DELETE** | a scope boundary is prose guidance for builders, not a testable requirement | (no arm — deleted) |
| 4 | ORC-GOAL-4 | **DELETE** | the pre-pass statement is ORC-ARB-3's (C1 flips it) and the fold-point is §12 open question 1 | (no arm — deleted) |
| 5 | ORC-GATE-2 | **DELETE — DUPLICATE-OF ORC-POL-4** | one machine, one T802 amendment, the same arms; the merge contract and the flag-file behaviour change fold into POL-4 | (no arm — deleted) |
| 6 | ORC-POL-2 | **ARM** | entry contract (owner/reason/expiry + parse refusal) | `test_every_policy_entry_carries_owner_reason_and_expiry` (RED, step 1) |
| 7 | ORC-POL-5 | **ARM** | the schema's worked example — the file + blocks + schema_version 2 | `test_policy_file_exists_with_schema_version_two` (RED, step 1) |
| 8 | ORC-POL-6 | **ARM** | unknown model → refusal, never a silent default (the live half after T813) | `test_unknown_model_resolves_to_a_refusal` (RED, step 1) + existing GREEN `test_keeper_has_no_row_for_ox_alpha...` |
| 9 | ORC-POL-7 | **ARM** | env overrides recorded (T677 precedent, GREEN) + unbacked knob refused (RED) | `test_override_recording_precedent_exists` (GREEN) · `test_knob_with_no_file_entry_is_refused` (RED, step 1) |
| 10 | ORC-POL-13 | **ARM** | cooldown legibility — one dashboard row with scope/reason/end (T811 finding 2: the T813 arms asserted POL-11/12's subject, not this id's) | `test_each_cooldown_renders_as_one_row_with_scope_reason_end` (RED, step 3) |
| 11 | ORC-PAUSE-1 | **ARM** | 5-hour default maximum + loud EXPIRED render | `test_pause_default_max_and_loud_expiry_in_the_policy_file` (RED, step 1/3) |
| 12 | ORC-PAUSE-2 | **ARM** | T625 mechanism exists in Python (GREEN) + moves to the policy file (RED) | `test_directive_policy_has_discharge_and_staleness_today` (GREEN) · `test_staleness_horizon_lives_in_the_policy_file` (RED, step 1) |
| 13 | ORC-PAUSE-3 | **ARM** | one row per pause, owner/reason/age/expiry, no second ledger | `test_each_pause_renders_as_one_row_with_owner_reason_age_expiry` (RED, step 3) |
| 14 | ORC-DASH-2 | **ARM** | short names through the one table — wrapper does it today (GREEN), managent must keep it (RED) | `test_watch_fleet_resolves_short_names_through_the_one_table` (GREEN) · `test_managent_pane_resolves_short_names_through_the_one_table` (RED, step 3) |
| 15 | ORC-DASH-3 | **ARM** | T738 omission + T739 fill — wrapper omits empty sections today (GREEN), managent must keep the rules (RED) | `test_watch_fleet_omits_empty_sections_today` (GREEN) · `test_managent_pane_omits_empty_sections` (RED, step 3) |
| 16 | ORC-DASH-5 | **ARM** | the five data sources wired; nothing invented (C6 is the P3 seeded control) | `test_dashboard_reads_only_the_five_stated_sources` (RED, step 3) |
| 17 | ORC-ARB-1 | **ARM** | the T821 build exists (GREEN — admission, own-overrun stop, alarm-never-kill; battery is `regression-arbiter.sh`); shed-order prose amended to the ratified ram-policy | `test_arbiter_exists_as_one_admission_component` (GREEN) · `test_arbiter_refusal_precedes_any_model_token` (GREEN) |
| 18 | ORC-ARB-2 | **ARM** | T629 killed_by enum exists (GREEN); the scorer-side refusal with stated skip count is the RED half | `test_killed_by_is_an_enumerated_runner_stamped_value` (GREEN) · `test_every_scorer_refuses_killed_rows_with_skip_count` (RED, step 2) |
| 19 | ORC-ARB-3 | **ARM** | pre-launch admission = zero tokens on refusal (GREEN); the policy-driven pre-pass in managent is the RED half | `test_arbiter_refusal_precedes_any_model_token` (GREEN) · `test_policy_driven_prepass_exists_in_managent` (RED, step 1/2) |
| 20 | ORC-REG-1 | **ARM** | direct tasks.json edits fail mechanically — nothing refuses today | `test_direct_tasks_json_edits_fail_mechanically` (RED, step 4) |
| 21 | ORC-REG-2 | **ARM** | one parser, three call sites — bin/dispatch still parses the header itself (T505's title_re) | `test_one_parser_shared_by_add_suggest_and_dispatch` (RED, step 4) |
| 22 | ORC-REG-3 | **ARM** | landmark gate exists at add (GREEN, T682); title≤40 and gate-declaration refused at add are the RED half | `test_landmark_gate_is_enforced_at_registration` (GREEN) · `test_registration_refuses_title_and_gate_at_add` (RED, step 4) |
| 23 | ORC-REG-4 | **ARM** | the T735/T539 repair is the parser and it is held cross-tier | `test_holds_edges_are_read_by_the_one_parser_at_add` (GREEN) + `regression-managent-holds.sh` (T539, credited) |
| 24 | ORC-GATE-1 | **ARM** | taste-gate demotion — the T505 title refusal exists today (GREEN), must become a warning (RED) | `test_title_gate_is_a_refusal_at_dispatch_today` (GREEN) · `test_taste_gates_are_warnings_not_refusals` (RED, step 5) |
| 25 | ORC-ORIENT-1 | **ARM** | the ≤150-line cap is enforced (GREEN, T353 — `regression-orient.sh` credited); injection at dispatch is the RED half | `test_orient_preamble_cap_is_enforced` (GREEN) · `test_orient_is_injected_at_dispatch` (RED, step 5) |
| 26 | ORC-PROV-1 | **ARM** | the registry is data today (GREEN); dispatch reading the one registry is the RED half (step 6 = the acceptance demo) | `test_model_registry_is_read_today` (GREEN) · `test_dispatch_reads_the_one_registry` (RED, step 6) |
| 27 | ORC-POL-4 (adjacent arm) | **ARM, replaced** | the rev-2 RED arm's green condition was a spec edit (prose regex over ORC-POL-4's paragraph — RACE-X R2). Replaced by a code-signature arm over the reader | `test_one_cooldown_machine_names_all_four_mechanisms` (RED, step 1) |
| 28 | ORC-DASH-1/4 (adjacent arms) | **ARM, strengthened** | the rev-2 substring greps could pass on a comment; the watch-fleet-thin half makes the green condition the actual rendering move | `test_managent_renders_the_five_specified_sections` (RED, step 3, strengthened) |
| 29 | ORC-POL-3/8/9/10/11/12, ORC-ARB-4, ORC-POL-1, ORC-DASH-1/4 | **KEEP, already armed** | no change; the GATE-2 coverage these arms carried moves to POL-4 | existing arms |

**Also in this revision (factual corrections the race earned, each with its own arm where a
mechanism exists):** the ORC-DASH-4 pane's queue row was invented (T810 R5 — T724/T733/T739 did
not exist at the pin) and is now ◇-illustrative with T810's corrected census; the normative
section-name list's "window budget + appetite" is "appetite + cap" (T810 R6 — the retired
meter's name leaked into the contract); watch-fleet's pin line count is 286, not 304 (T811 R10 —
the six-file total is 3461 at `a1415fe`, delta +147); ORC-ARB-1's shed order restates the
ratified T821/ram-policy build; the "directives.jsonl empty at HEAD" note is gone (T811 R11 —
the file is append-only and non-empty). Each is named in this log with its evidence; the pane
corrections are part of the DASH-4 arms' subject, and the meter retirement is now held by
`TestRetiredMeter`.

**Cross-task observation (recorded, not resolved here):** T834 (`T834-appetite-ollama-back`)
landed its operator-ruled change mid-revision (commit `91e4478`, 2026-08-24): `ollama-cloud`
returns OFF → SPEND in `src/managent/main.zig` — a step-1 slice landed ahead of the sprint, the
same shape as T821's arbiter. Its appetite change also turned the rev-2 characterization arm
`test_the_two_appetite_tables_disagree_today`'s appetite half stale (the family-NAME sets still
differ); T822 re-pinned that arm to the structural truth (names differ; keeper ollama=SPEND) so
it holds at both the pre- and post-T834 trees. The §2 seed table and the pane's appetite block
still show the 2026-08-23 OFF — T834's own amendment owes that update.

**Process defect recorded (evidence for ORC-G6's scope, S08 — not this document's to fix):**
the subject document moved mid-race. T813 (dispatched by the oversight seat) amended the spec
to rev 3 at 23:11 while RACE-X was auditing rev 2 (T807/T809 at `d79726c`); the race brief
pinned its subject by revision NAME, not by commit. `S08/spec.md` ORC-G6 requires a race's
sealed inputs to be immutable while a race runs; this instance shows the rule must cover **any**
document under audit, not only a race's sealed key. Credit where due: the dsflash entrant
(T808, `findings/T808-race-x-s06-audit.json`) **detected the move and audited rev 3 while
declaring the drift** rather than auditing a stale target — the grader ranked that first, and an
entrant catching a measurement failure the fleet caused is worth more than any single finding.
