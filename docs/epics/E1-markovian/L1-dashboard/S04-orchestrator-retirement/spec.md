# S04 — spec: the ephemeral reconciler (verdict + triage only)

**Artifact type: SPEC** (`docs/infra/sprint.md` — a spec says what we want, testably, for one
pass). **Owner:** deepseek-v4-pro/T582 · **Date:** 2026-08-22 · **Status:** PROPOSED — audited
before anything is built. Not a worker brief, not a plan, no code.

**Sits on:** the seed (`seed.md`, this directory), the Phase 0 counted table
(`decision-log.md`, this directory), `docs/status/orchestration-layer-spec.md` §3/§7 (the queue
sketch + the operator's resolved rulings), `docs/infra/sprint.md` (the pass protocol),
`S01-process-ownership/pass2/spec.md` (§2 the held supervisor, §4 appetite, §5 runaway/mint
safety), `S03-queue-layer/spec.md` (§3 conditions, §4 appetite, §7 mint).

**Inputs.** `seed.md` §4–§11 · `decision-log.md` §2 (the counted table: 129 distinct decisions,
61/12/56 = (a)/(b)/(c)) and §3 (F1–F8) · `orchestration-layer-spec.md` §7c rulings 11–26 ·
`sprint.md` (spec phase, audit loop) · `S01-process-ownership/pass2/spec.md` §5 (RUN-1..RUN-5).

**One line.** The queue and `managent` decide everything decidable by rule; a short-lived
**reconciler** — spawned by tooling, retired within minutes, bounded to the verb whitelist —
decides only the verdict-and-triage residue; only irreversible or scope-changing decisions reach
the operator.

**Citation pins.** Every `file:line` in this document is against `HEAD` at authoring time,
commit `14d8d6b` (2026-08-22). References to other spec documents are by **§ref** (their section
numbers are stable where cited), never by line number; each §ref is tagged with its document's
rev/pin where that is load-bearing. A citation that no longer resolves at `14d8d6b` is a spec
defect, not a reader's problem.

---

## 0. How to read this document

Every normative statement carries an id (`REC-GOAL-2`, `REC-VERB-3`). §5 is the control table:
the seed's named controls (§5 C1–C10) are the **mandatory core**; the test phase writes one
seeded arm (flip) and one null arm (green) for **every** normative id before the first live
wake. An id with no control is not a requirement, it is a wish (the project's standing rule:
*an instrument earns its first reading only after a null control and a seeded-defect control*).

The reconciler's scope is **derived from data, not intuition**: the Phase 0 study counted every
decision the orchestrator seat has ever made. Section 1 states that derivation; the spec's verb
set (§3) is the residue it leaves, and nothing more.

---

## 1. Goal and scope — derived from the counted table, not designed

**REC-GOAL-1 (the goal).** Retire the long-lived orchestrator seat: everything decidable by
rule is decided by rule (`managent` + the queue); the residue that is *not* rule-decidable is
decided by a short-lived reconciler inside a bounded verb set; only irreversible or
scope-changing decisions reach the operator. End state: no standing orchestrator agent — one
that "arises periodically, spawned by the dispatcher tooling, and retires within minutes"
(`seed.md` §1, §2).

**REC-GOAL-2 (the scope number, traceable to evidence).** The reconciler covers **verdict
evaluation and triage only** — 25 of the seat's 129 recorded distinct decisions, **19.4 %**
(`decision-log.md` §2: (c) judgment is 56/129; the (c) sub-split is verdict 15 + triage 10 =
25; the remaining 31 (c) rows are relay 15, doctrine 10, scope 6). The 25-row residue is the
reconciler's universe; the 31-row remainder is the operator-and-strong-agent conversation and is
explicitly **out** (`seed.md` §9). The spec states the 19.4 % so the boundary is auditable
against the table, not asserted.

**REC-GOAL-3 (what is out, named).** The reconciler replaces **steady-state** orchestration
only — routing, health, closure, escalation. Sprint decomposition, spec authorship, grand
audits, and direction remain a conversation between the operator and a strong agent
(`seed.md` §9). Non-goals (`seed.md` §10): no new dashboard (S03 owns it), no supervisor
changes (pass 2 owns it), no model-perf restructure (T558/S4), no change to the sprint pass
protocol.

**REC-GOAL-4 (column (b) is data entry, not design).** The 12 (b) decisions (`decision-log.md`
§2) are discharged by data tables that **already exist**: the appetite dial
(`orchestration-layer-spec.md` §7c.11), the provider-quota/cooldown facts
(`decision-log.md` §3 F3), and the ordering table (`orchestration-layer-spec.md` §7.1,
`decision-log.md` §2). This spec **rows** those tables (§2.6) and does **not** re-design their
mechanism — the mechanism lives in `S03-queue-layer/spec.md` §3/§4/§7 and
`S01-process-ownership/pass2/spec.md` §4/§5. A reconciler that re-judges a (b) decision is
wrong by construction; it reads the table.

---

## 2. The reconciler

### 2.1 Trigger and wake policy (open question 1, resolved here)

**REC-LIFE-1 (wake policy).** The reconciler is spawned by tooling, in three circumstances:
(a) **queue-cycle-attached** — as the tail step of a queue cycle (`S03-queue-layer/spec.md`
§3) that has produced state the pre-pass cannot resolve; (b) **event-triggered** — a lane death
observed by the supervisor, a duty coming due, or an `managent audit` discrepancy; (c) a
**scheduled tick** where a duty is due. It is **not** a free-running cron that wakes on a quiet
store: a wake whose residue is empty is a **zero-token wake** (REC-LIFE-2), and spawning a model
for one is the failure this spec's attrition metric (§6.1) measures.

**REC-LIFE-2 (the deterministic pre-pass — where the zero-token wake lives).** Before any model
token is spent, tooling runs a deterministic pre-pass that (i) applies every (a) mechanism —
`managent` refusals, the done gate, reap, liveness, the acceptance command — and (ii) resolves
every (b) lookup from the §2.6 tables. What remains is the **(c) residue**: the genuine
verdict/triage decisions. If the residue is empty, the wake is a **zero-token wake**: the script
itself acts (which, on an empty residue, is "do nothing, retire cleanly") and no model is
spawned. If the residue is non-empty, the model is spawned with exactly that residue as its
input. This is what makes the attrition metric (§6.1) a real measurement: a wake the script
alone could decide is a wake where no orchestrator existed.

**REC-LIFE-3 (inputs — the read-only battery).** The reconciler reads state from the store at
spawn: `managent status --json`, `managent audit`, `managent liveness`, `managent sync --peek`,
`argus --mode doctor`. It derives nothing from an unreadable source; a reading it cannot obtain
is a gap reported, never papered over. All state is read at spawn — the reconciler is a single
snapshot reader, not a live observer.

**REC-LIFE-4 (lifetime).** Hard wall measured in minutes (`seed.md` §5). The reconciler retires
by default at the wall or on residue exhaustion; it **never waits idle**. Never-idle
(`orchestration-layer-spec.md` §7c.22) is a property of the **fleet**, discharged by the
idle-work ladder (standing rows), not by keeping a reconciler model alive after its residue is
spent.

**REC-LIFE-5 (statelessness).** Every decision is written to the store **before** retirement;
no handover document is owed — the store IS the handover (`seed.md` §5). The run record is
written by the tooling (the supervisor, per pass 2 §2), not reconstructed by the reconciler.

**REC-LIFE-6 (model).** Cheapest passing per the race protocol; "reconciler" enters the
task-type ladder as its own row (`seed.md` §5). The model must pass the **dispatcher predicate**
(`orchestration-layer-spec.md` §7c.17 — the reconciler *is* a dispatcher/manager) and be
permitted by the **appetite dial** (`§7c.11/§7c.12` — the dial records *can use*; *should use*
is the ladder + circumstantial appropriateness, never the reconciler's invention). Selection is
a §2.6 table read, not a judgment.

### 2.2 Overnight interaction

**REC-LIFE-7 (overnight).** The reconciler inherits the queue's overnight budget semantics
(`orchestration-layer-spec.md` §3 "overnight", §7.4): wall ceiling, stop-after-N-closes,
stop-if-a-gauge-crosses, reduced parallelization, mandatory progress reports + heartbeats — no
silent processes. The reconciler's own wake carries its minutes-long wall on top of those; a
wake that outlives its wall is killed and reported, not extended.

### 2.3 Prerequisite — F4, the highest-yield fix, folded as a gate

**REC-LIFE-8 (holds= mandatory at mint — F4).** The largest single (a) family — 15 recorded
one-writer conflicts plus 2 registration rows (`decision-log.md` §3 F4) — fired for the entire
period because `holds=` was never registered at mint. Before the reconciler's first live wake,
`managent add` must **require `--holds` (and `--bundle`) at mint**; a row minted without a
holds declaration is refused at write time. This is cheaper than anything in the reconciler and
is a **prerequisite**, owned by `managent`, stated here because the reconciler's triage must be
able to assume the invariant it enforces. (`T568`'s closing lesson reaches the same conclusion
independently: register bundle-first, or `suggest` mints before the header exists and `holds=`
never records.)

### 2.4 The data tables (column (b)) — rows, not mechanism

**REC-LIFE-9 (the three tables, and where the mechanism lives).** The reconciler reads these;
it never re-derives them, and it never substitutes judgment for a table hit.

| table | rows (data) | mechanism (not re-spec'd here) |
|---|---|---|
| **appetite dial** — 0–9 **per model short name**, not per family; family setting is bulk convenience only | ollama-cloud **0** · fable **2** · opus **4** · qwen **4** · sonnet **6** · haiku **6** · dspro **6** · flash **6** (`§7c.11`, initial values operator-set) | `S01/pass2` §4 arithmetic (0 = unliftable hard forbid, monotone back-pressure, max = no back-pressure, operator-only raise, auto may only reduce) |
| **provider quota / cooldown** | Ollama cooldown windows · weekly exhaustion · the Claude 15:30 reset clock · a wind-down's steps = the kill protocol (`decision-log.md` §3 F3, §2 (b) rows) | `S03-queue-layer` §3 conditions + `managent` `FLEET_MODEL_DENY`/allow |
| **ordering** | aging-priority: default 50/99, blocked tasks climb, FIFO ≈ "lowest-priority-in-queue minus 1" (`§7.1`); successor queue orders (`decision-log.md` §2 `T568-4`, `T557-1`) | `S03-queue-layer` §2.1 `Q-ORD-*` |

---

## 3. Verb set — bounded to verdict + triage, enforced mechanically

**REC-VERB-1 (the whitelist).** The reconciler may issue exactly these verbs, and nothing else:

1. **dispatch** the next ready row via the supervisor (`managent supervise`), including a due
   duty row and a standing row when the priority pool is empty/gated (never-idle, §7c.22).
2. **tell** — nudge or question a lane (`managent tell`).
3. **reap --close** — for a **confirmed** orphan only (no surviving process, records accounted).
4. **done** — **only** where the row's acceptance command exits 0, its deliverables are
   committed, and its verdict is recorded (`REC-VERB-5` for the two-tier rule).
5. **escalate** — assert to the ledger and surface to the operator, per the §4 contract.

**REC-VERB-2 (the never-list).** The reconciler may **never** `retire`, `amend`, force-close,
edit a spec/plan, answer the ruling queue, or **mint rows** — with the single ruled exception
of REC-VERB-3. The default on discovering work is "escalate the need", not "mint the row"
(`untracked/T578-orchestrator-retirement.md` constraints).

**REC-VERB-3 (the one ruled mint exception).** On an **irreversible blocker** only
(`orchestration-layer-spec.md` §7c.19), the reconciler mints **exactly one** bounded read-only
investigation lane per blocker: lineage-tracked (`lineage_depth` = 3, per §7c.18/§7c.15),
justification = the blocker itself (so pass 2 RUN-4's `(holds, justification-key)` dedupes a
repeat investigation, and `lineage_depth` bounds the chain), and read-only — it may not mutate
the store beyond its own close. The operator briefing on a blocker is **"blocker + evidence +
options forward with costs"**, never a bare halt.

**REC-VERB-4 (enforcement is mechanism, never prose).** The verb boundary lives in `managent`
itself, exactly as `MANAGENT_TEST=1` refuses mutating verbs today (`seed.md` §5). Two hard
properties (from §7c.18): (a) **kernel-attested caller identity** — the reconciler's role is
resolved from the supervisor's held-child table (parent-PID chain), **never** from an env-var
self-declaration (`MANAGENT_TASK_ID` is spoofable by unsetting); (b) **worker output is an
injection surface into any reading agent** — the boundary stays mechanical precisely because
persuasion must not matter. A brief that *instructs* the reconciler to `amend`/`retire` is
mechanically refused and the refusal recorded. (Open question 2's resolution: the role is
**neither** a self-declared env var **nor** a bare per-invocation flag — it is attested by the
supervisor; the concrete plumbing of that attestation is a design decision, not a spec one.)

**REC-VERB-5 (the `done` verb is two-tier — §7c.21).** Mechanical closure: a row with
`gate: <command>` closes on exit 0 + committed deliverables + recorded verdict, valid only if
the gate was seen red first (red-first IS the gate's independent check). Audit-act closure: a
row with `gate: audit` closes only on an independent non-same-family audit verdict. Every row
declares its gate at mint; neither declared = not dispatchable. The reconciler **never invents
a verdict** — it runs the declared gate or routes the audit and records the verdict; the
"lying `done`" (acceptance command fails) is mechanically not closed and is re-dispatched or
escalated.

**REC-VERB-6 (no cheating — §7c.23, mechanical).** The reconciler cannot edit any row's gate,
brief, or acceptance — its own or another's. A gate edit requires an out-of-lane author. This is
already subsumed by REC-VERB-2's never-list; it is stated separately because §7c.23 makes it a
*mechanical* requirement, and the reconciler is the one agent whose whole job is to sit next to
gates it must not touch.

**REC-VERB-7 (self-correction is a verb — F6).** One wake may **retract a previous wake's
action through the store**: the escalation contract's retraction path is a first-class store
operation (assert the retraction against the prior directive/assertion id), not an escalation
to the operator. `decision-log.md` §3 F6 records 6 such corrections; a stateless per-wake
reconciler that cannot retract through the store turns every correction into an escalation, so
the verb exists. It is bounded: retraction retracts a **specific prior wake's action**; it is
not a general amend.

**REC-VERB-8 (directive emission is templated, not shell-built — F8).** Three recorded
decisions were spent repairing the seat's own mangled message text (`decision-log.md` §3 F8).
The reconciler emits directives through a template with typed fields, never by shell-string
interpolation. A templated directive that fails to render fails loudly; it does not emit
garbage.

---

## 4. Escalation contract

**REC-ESC-1 (outbound — the three categories, §7c.14 ratified).** The reconciler escalates to
the operator **only**:
1. a decision that is **irreversible** — explicitly including **more than eight hours of
   wasted work**: work put at risk beyond that bar by proceeding on an unratified default is
   escalated *before* it runs, not vetoed after it burned;
2. a decision that **changes scope**;
3. a **premise violated** — a long-running assumed hypothesis falsified, or something believed
   possible proven impossible or astronomically difficult.

**REC-ESC-2 (everything else is reconciled, not escalated).** Anything outside those three the
reconciler resolves from the store and the docs, or delegates to a stronger agent. An
out-of-contract question answered locally produces **zero operator surfaces** (control §5).

**REC-ESC-3 (posture — blocker is a research opportunity, §7c.19).** Fixable red flags are
fixed and work continues. A serious irreversible blocker blocks — and dispatches the one
bounded read-only investigation lane (REC-VERB-3) so the briefing is "blocker + evidence +
options forward with costs", never a bare halt. **Panic-halt is reserved for thrash** — when
investigation itself adds thrash and things spin out of control. If unsure: investigate and
research.

**REC-ESC-4 (the concern channel is first-class and always open, §7c.20).** Every agent —
especially headless subagents — may record a concern or finding via `managent assert` + a
findings file. A concern is **input to the reconciler, never a discharge**: it closes nothing,
excuses nothing, and reaches the operator only after dedupe + contract check. An agent that
asserts a concern still meets or fails its own acceptance gate.

**REC-ESC-5 (inbound has one shape, and it is a RULE not a judgment — F7).** Four escalations
were ever received; the two genuine blocks were identical in shape — *a gate fired correctly and
the unblock needed a cross-lane routing decision* (`decision-log.md` §3 F7). The rule: **route
the blocking file to its owning row** — the owning row is derived from `holds=`/the store, never
from the reconciler's guess. And "report" is **forbidden** as an escalation category outright:
`managent done` already records it; a "report" escalation is a duplicate of the store.

**REC-ESC-6 (recurrence corollary — fix the tool, delete the prose).** An escalation category
that recurs twice yields a rule or a tool that absorbs it (`seed.md` §6 corollary). The
recurrence check rides an **existing duty chunk**; it does not spawn a new ceremony.

**REC-ESC-7 (audit-loop residue escalates, §7c.21).** When a sprint phase fails its third
audit — the cap — the phase and the sprint block and escalate (`sprint.md` audit loop). That
blocker is scope/irreversible: the reconciler routes it per REC-ESC-1, it does not re-audit.

---

## 5. Controls — never trust a green reconciler

**REC-CTRL-1 (the battery, scripted against a scratch store).** Each control is scripted
against a scratch store (`MANAGENT_STORE`), regression-suite style (`seed.md` §7). Every id in
§1–§4 has at least one arm here; the seed's named controls are the mandatory core:

| # | control | seeded defect | expected | flips |
|---|---|---|---|---|
| C1 | null | quiet store | zero actions, zero escalations, clean retirement, **zero model tokens** | REC-LIFE-1/2 |
| C2 | stuck row | a live row with beats stopped | `tell`, then escalate on no response | REC-VERB-1 (tell), REC-ESC-1 |
| C3 | duplicate-dispatch attempt | a second dispatch of a claimed row | mechanically refused and recorded | REC-VERB-4 |
| C4 | lying `done` | acceptance command exits non-zero | NOT closed; re-dispatch or escalate | REC-VERB-1/5 |
| C5 | orphan | confirmed-dead process, no records gap | reaped with records accounted | REC-VERB-1 (reap) |
| C6 | verb-boundary probe | brief *instructs* `amend`/`retire` | mechanically refused by managent, recorded | REC-VERB-4/6 |
| C7 | escalation-contract probe | in-contract concern | exactly **one** operator surface | REC-ESC-1 |
| C8 | escalation-contract probe | out-of-contract question | resolved locally, **zero** operator surfaces | REC-ESC-2 |
| C9 | retraction | a wake retracts a prior wake's `tell` | store records the retraction against the prior id; no operator surface | REC-VERB-7 |
| C10 | report-as-escalation | a "report" escalation | refused as a category; `managent done` is the record | REC-ESC-5 |

**REC-CTRL-2 (red first).** The first live reading counts only after C1 (null) **and** the
seeded-defect controls pass — red first, then green (`seed.md` §7). The controls are written
**before** implementation (`sprint.md` TDD; the 2B-5 positive-control failure is the local
scar).

**REC-CTRL-3 (T572 regression is a prerequisite, not a co-deliverable).** The store-pollution
guard (T572) is the same defect class as C6's refusal; its regression must be green before the
reconciler's first live wake (`seed.md` §7, T578 constraints).

**REC-CTRL-4 (token-window exhaustion is a first-class, testable failure mode, §7c.25).** The
handler for the reconciler's own five-hour window is **agent-free tooling** and/or **family
rotation** — an agent handler dies of the same cause it is handling. The control: a reconciler
lane whose family hits its window is re-scheduled by tooling to another permitted family or a
scheduled resume; it is never asked to handle its own exhaustion. (Tested only by actually
hitting limits — never by burning tokens purely to test.)

---

## 6. Retirement gate and attrition metric

**REC-GATE-1 (the attrition metric).** The metric is the fraction of reconciler wakes that
required **zero model tokens** — a wake the script alone could decide is a wake where no
orchestrator existed (`seed.md` §8). Tracked in the run records, denominator stated (wakes, not
decisions). The instrument-probe channel is kept **separate** from the decision channel
(`decision-log.md` §3 F5): the run record has a `probe` flag, and probes are excluded from the
metric's numerator and denominator.

**REC-GATE-2 (intermediate gate — AUTOPILOT-5H, §7c.24, this sprint's verification
centerpiece).** **N consecutive unattended five-hour runs** with zero orphans / runaways /
breaker-trips / panics / thrash, every lane accounted, and **real work produced each run**
(never-idle, §7c.22). **ACTIVE autopilot (§7c.26):** idle autopilot is no proof — each of the
five hours must contain real delegation, issue resolution, and closes. **Proposed default
N = 3** (flagged for operator ratification — a number the operator owns, per §7b's "still owed
operator numbers" convention; the spec default holds meanwhile). Passing AUTOPILOT-5H unlocks
L2 (return to science); it comes **before** the retirement gate and is the thing this sprint
verifies.

**REC-GATE-3 (the gate — the seat ends).** Three consecutive clean days under reconciler-only
steady-state operation — zero operator process-relays, duties current by the gate, every
escalation in-contract, every gauge reproducible — then the orchestrator row line (T568's
successors) ends with no successor minted (`seed.md` §8). This is the L1 declaration bar
measured on the new mechanism: **L1 and this gate are one bar, not two.** Independently
audited before believed (`orchestration-layer-spec.md` §7b.9).

**REC-GATE-4 (never-idle is measured, §7c.22).** "Real work produced each run" is an
acceptance term, not a slogan: each AUTOPILOT-5H run must show at least one delegation, one
issue resolution, and one close. A run that merely stayed alive fails the gate. The idle-work
ladder (STANDING-CLEANUP / STANDING-ABSORB / STANDING-CLAIMVERIFY) is the queue's fallback when
the priority pool is empty or gated; the reconciler's triage dispatches it, it does not *do* it.

---

## 7. Open questions — resolved at spec vs deferred to design

**Resolved at spec (the seed's §11 list, closed here):**

1. **Wake policy** → REC-LIFE-1/2: queue-cycle-attached + event + due-duty tick, with a
   deterministic pre-pass so a quiet store is a zero-token wake. Not a free-running cron.
2. **Verb-boundary mechanism** → REC-VERB-4: neither env self-declaration nor a bare flag; the
   role is kernel-attested via the supervisor's held-child table. The concrete plumbing (how
   the supervisor conveys "this child is the reconciler row" into managent's store-write check)
   is **design**.
3. **Does the reconciler run due duty chunks?** → No. It **detects and dispatches** them
   (REC-VERB-1 verb 1). Running a duty is execution, not verdict/triage, and would exceed both
   the verb set and the wall. The queue/supervisor runs duties.

**Deferred to design (the seed did not ask, the spec does not invent):**

- the pre-pass's concrete implementation (its inputs are REC-LIFE-3; its output is the residue);
- the exact attestation plumbing for REC-VERB-4;
- the run-record schema (must carry: wake id, residue, verdict per action, probe flag, token
  count, wall, and the §6.1 metric fields).

**Pending operator numbers (spec defaults hold meanwhile, per §7b):**

- `N` for AUTOPILOT-5H (proposed 3, REC-GATE-2);
- the appetite dial constants were set by §7c.11; the `runaway_streak` = 5 / `lineage_depth`
  = 3 values are ratified (§7c.18) and are consumed, not re-set, here.

**Build gating (seed §11.4).** Design may run ahead (the `orchestration-layer-spec.md` §6
pattern); **build** is gated on the pass-2 supervisor holding its first child and the queue
layer's audited spec. The reconciler's build depends on REC-LIFE-8 (holds= at mint) landing
first — it is a prerequisite, not a co-deliverable.

---

## 8. Rulings traceability — no ruling silently dropped

Each §7c ruling and study finding the brief names, mapped to the spec statement that satisfies
it. (A fuller per-ruling audit trail is in `findings/T582-s04-reconciler-spec.json`.)

| ruling / finding | spec home |
|---|---|
| §7c.11 appetite 0–9 per model | REC-LIFE-9 (appetite table) |
| §7c.12 can vs should axes | REC-LIFE-6, REC-LIFE-9 |
| §7c.13 short-name resolution | REC-LIFE-9 (table note) |
| §7c.14 escalation contract + premise + >8 h | REC-ESC-1 |
| §7c.18 runaway constants renamed, kernel-attested identity, mechanical boundary | REC-VERB-3 (`lineage_depth`), REC-VERB-4 |
| §7c.19 blocker = research opportunity, one investigation lane | REC-VERB-3, REC-ESC-3 |
| §7c.20 concern channel first-class | REC-ESC-4 |
| §7c.21 two-tier closure, audit-loop cap 3 | REC-VERB-5, REC-ESC-7 |
| §7c.22 never-idle + idle-work ladder | REC-LIFE-4, REC-GATE-4 |
| §7c.23 no-cheating mechanical | REC-VERB-6 |
| §7c.24/26 AUTOPILOT-5H, ACTIVE | REC-GATE-2 |
| §7c.25 token-window exhaustion | REC-LIFE-6 (selection), REC-CTRL-4 |
| F4 holds= at mint (prerequisite) | REC-LIFE-8 |
| F6 self-correction through the store | REC-VERB-7 |
| F7 inbound one shape; forbid "report" | REC-ESC-5 |
| F8 templated directives | REC-VERB-8 |
| scope = verdict + triage (25/129) | REC-GOAL-2 |
| (b) lookup = data entry | REC-GOAL-4, REC-LIFE-9 |
