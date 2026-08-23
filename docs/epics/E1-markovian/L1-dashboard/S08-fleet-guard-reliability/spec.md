# S08 — spec: the guards stop killing the fleet, and are tested against the real thing

**Artifact type: SPEC** (`docs/infra/sprint.md` — a spec says what we want, testably, for one
pass). **Owner:** claude-opus-5/T785 · **Date:** 2026-08-23 · **Status:** PROPOSED (rev 1, for
operator ratification) — audited before anything is built. Not a worker brief, not a plan, no code.

**Landmark.** Advances **L1 (dispatch tooling)** — the fleet stops losing lanes to its own guards.

**Operator ruling, 2026-08-23 (the reason this sprint exists).** *"Our tooling and monitors are
stupid, panic and suicidal… then we dispatch a sprint to fix this stupidity. And thoroughly
TEST!"* and *"cooldown and fix these buggy tools and TEST and SMOKE TEST."* Two further rulings
of the same day shape the plan and are treated as DECIDED here: *"we need to prove what works
works before proving the consolidation still works"* (pass 1 is characterization) and *"finish
this by slowly cannibalizing the 6 scripts, one by one, test one by one"* (no big-bang cut-over).

**Sits on.** `tools/runner` (the host-pressure guard), `bin/subagent` (T713's resident gate),
`tools/fleet-keeper.sh`, `bin/dispatch`, `tools/window_policy.py`, `untracked/watch-fleet.sh`;
`findings/T711-declared-tenant.json`, `findings/T713-qwen-resident-dispatch.json`,
`findings/T714-host-guard-controls.json`, `findings/T730-race-g-science-grade.json`;
`untracked/T712-host-guard-one-arbiter.md` (unbuilt — folds in as pass 2),
`untracked/T715-host-guard-incident-record.md` (the doc row this spec supplies content for);
`docs/status/orchestration-layer-spec.md` §7c (rulings in force, §7c.31 load-bearing);
`docs/epics/E1-markovian/L1-dashboard/S06-orchestration-refactor/spec.md` (ORC-ARB-1..4 — the
housing this sprint's semantics move into; §7 below is the boundary).

**One line.** A guard that cannot name a member whose death would relieve the shortfall kills
nothing, refuses instead, charges a resident model's memory to the lane that asked for it, and
labels every death it causes — and each of those four sentences has a red-before-green arm plus a
per-provider smoke lane before the pass that ships it closes.

**Citation pins.** Every `file:line` is against `HEAD` `5552d81` (2026-08-23). Log citations are
against `untracked/log/*.log` as of 2026-08-23T18:30Z; logs append across attempts, so the cited
line numbers include both the killed attempt and its retry. A citation that no longer resolves at
`5552d81` is a spec defect, not a reader's problem.

---

## 0. How to read this document

Every normative statement carries an id (`ORC-G*`, `ORC-GC/GP/GS/GB-*`). §9 is the control table.
**An id with no arm is not a requirement, it is a wish** — the S06 audit found 16 of 31 ids
armless, so this document states its arm count explicitly and the accept step recomputes it.

Where a ruling underdetermines a design choice, the spec states the **options** and a
**recommendation** and marks it `[design-open]`: the design phase may choose only among the listed
options; anything else is a plan amendment. §8 holds the open questions.

The diagnosis in §1 is **evidence already gathered**. §1.2 extends it with one new measurement
this row took (the futile-kill census) — stated with its command so any reader can recompute it.

---

## 1. The incident, and what the code actually does

### 1.1 The incident this sprint exists to make impossible (2026-08-23 15:19:09)

Four Race W judges launched together — three cloud lanes and one local `qwen3.8:27b-mlx`. **All
four were dead 88 seconds later**, each with its own runner's kill line:

| lane | log | avail | floor | shortfall | member killed | verdict |
|---|---|---|---|---|---|---|
| T780 | `untracked/log/t780.log:93` | 5761 MB | 6144 MB | 383 MB | pid 7731, RSS **251 MB** | exit 124 @ 87.8 s (`:140`) |
| T781 | `untracked/log/t781.log:10984` | 5380 MB | 6144 MB | 764 MB | pid 7741, RSS **133 MB** | exit 124 @ 87.8 s (`:11002`) |
| T782 | `untracked/log/t782.log:95` | 5687 MB | 6144 MB | 457 MB | pid 7770, RSS **129 MB** | exit 124 @ 87.7 s (`:111`) |
| T783 | `untracked/log/t783.log:102-103` | 6004 MB | 6144 MB | 140 MB | pid 8011, RSS **126 MB** | exit **1** @ 88.1 s (`:128`) |

Not one of the four killed members could have cleared its own shortfall. Their combined RSS
(639 MB) could not clear three of the four. The ~18 GB actual consumer — the resident MLX engine,
whose memory belongs to the `ollama` daemon and to no fleet member — was untouched.

Six defects are visible in that table and in the code behind it.

**D1 — the tenant detector lost a startup race.** T711's add-back fired and returned **36 MB** for
a tenant that is 18–25 GB (`untracked/log/t780.log:39`, `t783.log:48`). Because all four lanes
launched at once, the `ollama runner --mlx-engine` process was not yet resident when
`_declared_tenant_reservation_bytes()` (`tools/runner:1400`) sampled `ps`. The formula is right;
the sampling moment is wrong. **Proof it is only the moment:** the same detector, re-dispatched,
climbs 36 → 1890 → 9206 → 10153 MB within the same run (`t783.log:48-54`).

**D2 — T711's control injected the number it should have measured.** `WEIZIGO_HOST_TENANT_RESERVATION_MB`
was the test path (T714's contract, `findings/T714-host-guard-controls.json` `contract.semantics`),
so the *arithmetic* was proved and the **detector never met a real loading model**. The standing
rule — an instrument earns its first reading only after a null arm **and** a seeded-defect arm —
was followed for the wrong subject: neither arm exercised the thing that broke.

**D3 — the guard killed lanes that could not possibly relieve the pressure.** `tools/runner:3151`
picks `largest_pid = max(poll_rss, ...)` — the largest member of *this runner's own process
group* — and kills it. There is no comparison of that member's RSS against the shortfall
anywhere in the path (`tools/runner:3123-3196`). So the guard destroys the innocent and spares
the cause.

**D4 — kill was chosen where refusal was available.** T713 shipped the right principle at the
dispatch chokepoint — *idle is acceptable, killing a running lane is not* — and REFUSES a local
lane it cannot fit (`findings/T713-qwen-resident-dispatch.json`, `contract.semantics`). The
running-guard path in `tools/runner` never learned it: the guard has exactly one response verb,
and that verb is SIGKILL.

**D5 (new, this row) — the guard causes a death it does not label.** When the largest member is
*not* the direct child, the runner reaps that member (`tools/runner:3164-3183`) and sets only
`host_guard_fired`, which produces a stderr note at `tools/runner:3473`. `killed_by` is written
only on the direct-child path (`tools/runner:3382`) and on the directive path (`:3222`) — never on
the cull path. **T783 is the worked example:** culled at `t783.log:102-103`, the lane exited **1**
at 88.1 s (`:128`) with no `killed_by`. Every downstream reader that refuses rows with
`killed_by != none` (Ruling 32; `tools/fleet-keeper.sh:505,536`) therefore *accepts* that row and
scores it as a model failure. This is §7c.31 (*a guard may stop a lane, no guard may attribute*)
broken from the other end: the guard silently attributes to the model by omission.

**D6 (new, this row) — the guard fires on a single 250 ms sample, with no dwell.** `poll_ms`
defaults to 250 and the floor comparison runs every poll (`tools/runner:3135` reads, `:3150` compares). There is no
requirement that pressure persist. The corpus contains kills at a shortfall of **15 MB**
(`untracked/log/t512.log:220`) and **31 MB** (`t530.log:37`) — a lane destroyed to reclaim less
memory than a browser tab — and `t521.log:37,39,41,43` shows four kill lines in immediate
succession inside one run. An irreversible SIGKILL is triggered by a transient the next poll
would have cleared.

### 1.2 The futile-kill census — the number this sprint has to move

Assertion is not enough; the sprint needs a before-number. Recomputed at `5552d81` over
`untracked/log/*.log`, pairing each `[runner] KILL: host memory pressure` line with the member it
names (inline for the direct-child form, the following `reaping largest member` line otherwise):

> **20 host-guard kills identify a member. 16 of them (80 %) killed a member whose RSS was
> below the shortfall — a futile kill.** Sufficient: 4. Shortfalls range 103–1897 MB against
> members of 40–389 MB.

Futile kills, one per log: `duty-DCLAIM` (284/127), `t521` (362/40), `t529` (329/186), `t542`
(293/60), `t543` (276/60), `t545` (328/87), `t549` (535/255), `t630` (1599/389), `t636`
(1599/183), `t661` (1897/219), `t699` (1575/240), `t774` (103/56), `t780` (383/251), `t781`
(764/133), `t782` (457/129), `t783` (140/126).

The 2026-08-23 incident is therefore **not an anomaly**: it is the modal behaviour of this guard.
The census is reproducible by the command in Appendix A, and ORC-G10 makes it an instrument the
sprint ships rather than a number this document asserts once.

### 1.3 The seventh defect, same class of carelessness

`findings/T730-race-g-science-grade.json` F1/F2 record that a register-repair row (T731, commit
`b4f3941`, 2026-08-23T09:41:10Z) rewrote `docs/epistemic/CLAIMS.md` **while the science arm was
still running**, from the *bare* arm's own answers, erasing all four seeded canaries (G34, G26,
G43, G35) and voiding the arm's falsifiability guarantee for the two lanes that finished after
09:41:10Z. Different subsystem, identical failure mode: a tool acted on shared state without
checking whether someone was standing on it. It is in this sprint because the fix is the same
shape as the guard's — check before you act on shared state — and because leaving it in the
guard sprint is the only way it gets an arm this month.

---

## 2. Normative requirements

**ORC-G1 (refuse before kill).** Under host-memory pressure the arbiter's **first** response is to
stop admitting new lanes and wait. Killing is the **last** resort and is permitted only when
ORC-G2's naming condition is satisfied. The shed order is: (a) stop admitting, (b) queue/list-wait
the pending row (the row stays dispatchable, T713's stance), (c) only then consider a stop, newest
or least-progressed first. *"Idle is acceptable, killing a running lane is not."*

**ORC-G2 (no futile kill — an invariant).** If no single member's RSS ≥ the shortfall
(`floor − available-to-the-fleet`), the arbiter **kills nothing**. It logs, in one record: the
shortfall, every member it considered with that member's RSS, and the words that no member
qualified. Stated as an invariant: **a kill record whose named member's RSS < the shortfall at
decision time is a defect, detectable after the fact from the log alone** — which is exactly what
Appendix A's census does, so the invariant is measurable and not merely intended.

**ORC-G3 (charge memory to the lane that caused it).** A lane that asks a resident server to load
a model **owns that footprint** — for admission and for pressure accounting — even though the RSS
lands on the daemon. T711's add-back (pressure accounting) and T713's gate (admission) are two
halves of one rule; exactly one component owns both (ORC-G5). Corollary, and the reason the two
halves currently disagree: T711 adds the tenant back to `available` for the floor comparison
(`tools/runner:3145-3146`) while T713 deliberately does **not** (`findings/T713…json`
`implementation.decision_rule`). Both are right for their own question; the arbiter must state
the two questions separately — *is the host in danger?* (tenant is not an emergency: add it back)
and *can a new lane fit?* (tenant is not reclaimable: do not add it back) — and never let one
formula answer both.

**ORC-G4 (sample the tenant before admitting, not after launching).** A co-launch batch containing
a local lane resolves the tenant footprint from a **declaration or a pre-admission probe**, before
any member of the batch is admitted. A post-launch `ps` sample is never the basis of a pressure
decision for a batch that is still starting. Closes D1.

**ORC-G5 (one arbiter).** Exactly one component decides admission and pressure response. At
`5552d81` the decision is split three ways with no component aware of the others:
`tools/runner:3123-3196` owns the pressure **response** (per-runner, per-process-group, kill-only);
`bin/subagent` owns memory **admission** (local lanes only); `tools/fleet-keeper.sh` owns dispatch
**rate** (caps, cooldowns, one-writer holds — its `pressure.json` is contention pressure, not
memory pressure, `tools/fleet-keeper.sh:362,1022-1067`). Folds T712 (`untracked/T712-host-guard-one-arbiter.md`).
The arbiter never scores a model (§7c.31 / S06 ORC-ARB-2).

**ORC-G6 (sealed inputs are immutable while a race runs).** A race's sealed inputs carry a
**content hash recorded at seal time and re-checked at grade time**. A mutation while a lane is in
flight is refused (preferred) or, where refusal is impossible, **detected and stated in the grade**
so no arm is silently compared across two different input sets. Minimum viable form: the lane
brief pins the input commit SHA and the grader refuses to grade a lane whose input hash at close
differs from the sealed hash. Closes §1.3.

**ORC-G7 (a guard-caused death is labeled as such).** Every lane death the guard causes — including
the **cull** path where the reaped member is not the direct child — writes an enumerated
`killed_by` to the run record. No lane may exit with a guard-caused, unlabeled non-zero status. The
converse (§7c.31) is unchanged: the label names *which guard fired*, never *why the model failed*.
Closes D5. The T783 record is the fixture.

**ORC-G8 (pressure must be sustained before it is acted on).** A pressure response requires the
shortfall to hold across **N consecutive polls spanning ≥ a stated dwell window** (recommended
default: 3 polls / ≥ 2 s at the 250 ms poll rate) and a **minimum shortfall** below which the guard
only logs. A single sample is a reading, not an emergency. Closes D6. `[design-open]` — the two
numbers are the design phase's to choose from: (a) 3 polls / 2 s / 64 MB minimum shortfall;
(b) dwell derived as a fraction of the floor; (c) dwell only, no minimum shortfall. Recommend (a):
it is the only option whose arm can be written before the mechanism exists.

**ORC-G9 (the tenant footprint is a stable declaration for the life of a decision).** The
auto-detected reading is not stable enough to be re-read per poll: in one run it goes
36 → 1890 → 9206 → 10153 → 4873 → 2739 MB and later settles at ~7825 MB
(`untracked/log/t783.log:48-59` and its tail), against a resident engine T711 itself measured at
**15.6 GB** (`findings/T711-declared-tenant.json` `implementation.process_name_confirmation`). So
even *after* the startup race the detector under-reports by roughly 2×, and it is non-monotone.
The arbiter therefore resolves the tenant **once per decision** and holds it (recommended: a
high-water mark over the tenant's observed lifetime, never the instantaneous sample), and the
diagnostic prints the resolution **source** (`declared` | `probe` | `high-water` | `sample`) so a
reader can tell a measurement from a guess. ORC-G4 closes the race; **ORC-G9 closes the
under-reporting that survives the race**.

**ORC-G10 (the futile-kill rate is measured, not asserted).** The sprint ships a census instrument
(Appendix A, promoted to a script) that recomputes the futile-kill rate from the log/run-record
corpus. It carries its own null arm (a corpus with no kills → rate undefined, reported as such,
never as 0 %) and its own seeded arm (a synthetic corpus with one known futile and one known
sufficient kill → 50 %). **Before-number at `5552d81`: 16/20 = 80 %.** Accept requires the
instrument to report **0 futile kills** over the corpus produced after the pass that lands ORC-G2.

---

## 3. What is out of scope, named

- **Raising the floor.** Forbidden. The `total // 8` derivation (`tools/runner:2731`) exists
  because this host took a watchdog-timeout kernel panic under OOM on 2026-07-29
  (`docs/infra/host/incident-2026-07-29.md`). Raising it disables the one protection that
  precedent justifies. Every fix here is about *who* dies and *whether anyone needs to*, never
  about the threshold. (This is the content `untracked/T715-host-guard-incident-record.md` owes
  the design doc; this spec supplies it, T715 places it.)
- **Rewriting `tools/runner`.** Consistent with S06 ORC-GOAL-3: the runner survives as the
  launch/guard layer. Its *host-pressure decision* moves to the arbiter; its internals (reap,
  liveness, token capture, run records) do not.
- **The RSS cap and the other guards.** `--rss-cap-mb`, progress/wall/CPU watchdogs, liveness
  fuses: characterized in pass 1 (they are guard paths this sprint touches) but not redesigned.
- **claimlint, the science suite, race machinery beyond ORC-G6's hash check.**

---

## 4. Pass 1 is characterization, not repair

**ORC-GC-1 (pin before repair).** Before this sprint changes any guard, it pins the **current**
behaviour of every guard path it will touch, including the behaviour §1 has just proved wrong. The
minimum set, each an arm asserting today's fact: the futile kill (a shortfall larger than every
member kills the largest member anyway); the unlabeled cull (a non-direct-child cull yields a
non-zero exit with no `killed_by`); the single-sample fire (one poll below the floor fires); the
detector's real return value under a real loading model (D2's missing arm); T713's refusal; the
runner's kill-only vocabulary.

**ORC-GC-2 (a characterization arm that encodes a known defect cites its repair row).** Where
today's behaviour *is* the defect, the arm records it as the current fact **and names the ORC-G id
that will invert it**, so the later flip is a deliberate edit to a named arm and never a silent
drift. An arm that pins a defect without naming its repair id is a spec violation, not a test.

**ORC-GC-3 (the detector is under test, not only the arithmetic).** For every quantity the guard
reads from the world (tenant footprint, available memory, member RSS), at least one arm must
exercise the **real reader** against a real (or faithfully faked) world — not the injection hook.
Injection hooks stay, for the scenarios that cannot be staged; but **no quantity may have injection
as its only arm**. This is D2 stated as a rule: T711's arms were green and the detector was broken,
because the injected path was the only path any arm ever took.

---

## 5. Sequencing — one script cannibalized per pass

**ORC-GP-1 (one per pass, green before the next).** Each pass absorbs **one** script's piece of the
admission/pressure decision into the arbiter, turns that pass's arms green, and only then does the
next pass begin. No big-bang cut-over.

**ORC-GP-2 (the fleet stays dispatchable at every boundary).** At the end of every pass the fleet
can dispatch a lane on every provider. This is what the smoke gate (§6) verifies; a pass that
leaves the fleet undispatchable is reverted, not patched forward.

**ORC-GP-3 (the order, and why).** Six scripts, **4130 lines** at `5552d81` (`tools/runner` counted
by its guard path, not its 3493 total):

| pass | subject | its piece of the decision | why here |
|---|---|---|---|
| 1 | *(none — characterization)* | pins all six | the operator's "prove what works works" ruling |
| 2 | `tools/runner` (guard path, `:3123-3196`) | pressure **response** | **first**: every other defect routes through it, and ORC-G1/G2/G7/G8 all land here. The arbiter is born in this pass. |
| 3 | `bin/subagent` (819) | memory **admission** (T713) | the other half of ORC-G3; the arbiter now owns both questions and can be shown answering them differently on purpose |
| 4 | `tools/fleet-keeper.sh` (1169) | dispatch **rate** (caps, cooldowns, holds) | ORC-G1's "stop admitting" verb needs the rate limiter to be the arbiter's, not a peer's |
| 5 | `bin/dispatch` (546) | the advisory gate | after the real chokepoint is arbiter-owned, the advisory gate is a thin caller (T677/D040: a gate only in `bin/dispatch` is advisory) |
| 6 | `tools/window_policy.py` (548) | the token-window fan-out cap | the third admission dimension; last because it is independent of memory and blocks nothing |
| 7 | `untracked/watch-fleet.sh` (304) | observation | the dashboard reads the arbiter's state instead of inferring it |
| — | ORC-G6 (sealed-input hash) | *independent* | touches no guard file; may run parallel to any pass |

**ORC-GP-4 (no silent scope drop).** The line counts and the script list above are stated so
"did we actually absorb it" is answerable at accept. If a pass drops a subject, the drop is logged
with its reason — a silent truncation reads as coverage.

---

## 6. Smoke tests — named as such, separate from the unit arms

**ORC-GS-1 (one lane per provider, end to end).** A new `tools/fleet-smoke.sh` launches **one real
lane per provider** — `claude`, `deepseek`, `pi`/openrouter, `ollama` local (the four in
`bin/subagent:151`) — through the real chokepoint and asserts each reaches a **verified close**
(`[verify] verification PASSED` + a run record with `killed_by` absent or `none`). It is **not**
`tools/smoke.sh`: that is the solver's build-verification suite (`tools/smoke.sh:1-5`, wired at
`build.zig:1239`) and has nothing to do with the fleet. Two suites, two names, no overloading.

**ORC-GS-2 (smoke gates the pass boundary).** A pass does not close on unit-arm green alone; the
smoke suite must pass at the boundary. **This is the load-bearing lesson of 2026-08-23:** the
incident would have been caught by a single co-launch smoke run and was **not** caught by a full
suite of green unit arms, because every arm injected the number the detector was supposed to
measure. At least one smoke run per pass must be a **co-launch batch** (all four providers at
once), since the incident is a startup-race and a serial smoke would have missed it too.

---

## 7. Boundary with S06 — who owns what, so two sprints do not fight

S06 ORC-ARB-1 already assigns the arbiter to `managent` and names T712/T713 as things it absorbs.
This sprint must not re-litigate that.

**ORC-GB-1 (semantics here, housing there).** **S08 owns the guard's *decision content*** — the
ORC-G1..G10 invariants and every arm that holds them. **S06 owns the *housing*** — which binary the
arbiter lives in, the policy file, the dashboard, the registry. S08 states *what the arbiter must
decide and how it is proved*; S06 states *where it lives*.

**ORC-GB-2 (the arms are the contract, whichever lands first).** If S06 lands first, S08's passes
2–7 are rewires of already-migrated call sites rather than migrations. If S08 lands first, S06
moves working code with its arms attached. Either way **a rewire that drops an S08 arm is a
regression**, and the accept step re-runs the S08 battery against the post-S06 tree. The arm set,
not the file layout, is what carries.

---

## 8. Open questions

1. **Sequencing against S06.** `[design-open]` — options: (a) S08 first, S06 rewires; (b) S06
   first, S08 fills semantics in; (c) interleaved, S08 pass 2 lands inside S06's arbiter phase.
   **Recommend (a):** the fleet is losing lanes *today* at an 80 % futile rate, and S06 is a
   six-file refactor whose own pass 1 has not started. Fixing the semantics in place and letting a
   later refactor carry proven arms is strictly safer than gating a live-fire defect on a large
   consolidation. **This is the one question this spec asks the operator to rule on.**
2. **Where the arbiter's state lives during passes 2–3.** `[design-open]` — options: (a) a file in
   `untracked/` the runners poll (cheapest, matches `fleet-keeper.pressure.json` precedent);
   (b) a socket/daemon; (c) the store. Recommend (a) for passes 2–3 and let S06 choose the final
   home — a temporary file is reversible, a daemon is not.
3. **ORC-G6's enforcement point.** `[design-open]` — (a) refuse the mutation (a pre-commit check
   against a live-race lock); (b) detect at grade time via the sealed hash; (c) both. Recommend
   (c) with (b) shipping first: detection is unblockable and needs no lock protocol, and a voided
   arm that *knows* it is void is already better than 2026-08-23.

---

## 9. Controls — every id armed, and the count stated

Every arm is **red before green** (the standing rule) and scripted against a scratch store /
scratch repo, never the live fleet — the T714 isolation precedent (`MANAGENT_TASK_ID` via env, no
fixture heartbeat in the live `untracked/heartbeat.jsonl`, T512/F3).

| # | arm | seeded condition | expected | flips |
|---|---|---|---|---|
| A1 | real tenant, co-launch | a **real** local-model load concurrent with cloud lanes (no injected number) | no cloud lane dies; the tenant resolves to ≥ 90 % of its steady-state footprint before admission | ORC-G4, ORC-G9 |
| A2 | futile shortfall | injected shortfall with **all** members smaller than it | **nothing is killed**; one record names the shortfall + every member considered | ORC-G2 |
| A3 | sufficient shortfall | injected shortfall with **exactly one** member larger | exactly that member dies | ORC-G2 |
| A4 | refuse before kill | pressure with a pending dispatch and a running lane | the pending dispatch is refused/list-waited; the running lane survives | ORC-G1 |
| A5 | shed order | pressure persists after refusal, two lanes running | the newest/least-progressed is stopped first, never the oldest | ORC-G1 |
| A6 | admission vs danger | tenant resident; ask both questions | *host in danger?* adds the tenant back; *can a lane fit?* does not — two answers, one arbiter | ORC-G3 |
| A7 | one arbiter | two runners under one pressure event | exactly one kill decision exists in the corpus; no per-runner fratricide | ORC-G5 |
| A8 | cull labeling | a non-direct-child cull kills the lane indirectly (the T783 fixture) | run record carries an enumerated `killed_by`; no unlabeled guard-caused death | ORC-G7 |
| A9 | no attribution | the same cull | `killed_by` names the guard only; no model-failure cause is written (§7c.31) | ORC-G7, ORC-G5 |
| A10 | dwell | one poll below the floor, recovered by the next | log only, **no kill** | ORC-G8 |
| A11 | sustained | N consecutive polls below the floor | response fires at the Nth, not the 1st | ORC-G8 |
| A12 | minimum shortfall | a 15 MB shortfall (the `t512.log:220` fixture) | log only, no kill | ORC-G8 |
| A13 | tenant stability | detector returns 36 → 10153 → 2739 MB across polls (the `t783.log:48-59` trace, replayed) | the decision uses one held value; the diagnostic names its source | ORC-G9 |
| A14 | census null | a corpus with zero kills | rate reported **undefined**, never "0 %" | ORC-G10 |
| A15 | census seeded | synthetic corpus, 1 futile + 1 sufficient | reports exactly 50 % | ORC-G10 |
| A16 | census before-number | the corpus at `5552d81` | reports 16/20 = 80 % | ORC-G10, ORC-G2 |
| A17 | sealed-input mutation | a sealed race input mutated mid-run | refused, or graded with an explicit contamination verdict | ORC-G6 |
| A18 | sealed-input clean | inputs untouched | grades normally, hash match stated | ORC-G6 |
| A19 | characterization completeness | run the pass-1 battery against `5552d81` | every listed guard path has ≥ 1 pinning arm; the futile kill, the unlabeled cull and the single-sample fire are each pinned as today's fact | ORC-GC-1 |
| A20 | defect-arm citation | a characterization arm pinning a known defect with no ORC-G id in it | the battery **refuses** the arm | ORC-GC-2 |
| A21 | no injection-only quantity | a guard-read quantity whose only arm uses an injection hook | the battery refuses (the D2 catcher) | ORC-GC-3 |
| A22 | pass isolation | a pass touching two subjects | refused at the pass gate | ORC-GP-1 |
| A23 | scope accounting | a pass that drops a subject | the drop is logged with its reason; a silent drop fails accept | ORC-GP-4 |
| A24 | smoke, per provider | one lane per provider, serial | each reaches a verified close | ORC-GS-1, ORC-GP-2 |
| A25 | smoke, co-launch | all four providers launched at once (the incident's shape) | all four reach a verified close | ORC-GS-1, ORC-GS-2 |
| A26 | smoke gates the boundary | unit arms green, smoke red | the pass **does not close** | ORC-GS-2 |
| A27 | boundary re-run | the S08 battery against a post-S06 tree | fully green; a dropped arm is a regression | ORC-GB-1, ORC-GB-2 |
| A28 | pass order | a pass attempted out of the §5 order (e.g. `bin/subagent` before the arbiter exists) | refused at the pass gate, naming the prerequisite pass | ORC-GP-3 |

**The count, stated (the S06 audit's rule).** Normative ids: **21** — ORC-G1..G10 (10), ORC-GC-1..3
(3), ORC-GP-1..4 (4), ORC-GS-1..2 (2), ORC-GB-1..2 (2). Arms: **28**. **Armless ids: 0.** Ids with
more than one arm: ORC-G2 (A2, A3, A16), ORC-G8 (A10, A11, A12), ORC-G10 (A14, A15, A16), ORC-G7
(A8, A9), ORC-G6 (A17, A18), ORC-G1 (A4, A5), ORC-G9 (A1, A13), ORC-G5 (A7, A9), ORC-GS-1 (A24, A25),
ORC-GS-2 (A25, A26), ORC-GB-1/2 (A27). The accept step recomputes this
table's coverage mechanically; a hand-maintained count is a wish about a count.

---

## 10. Acceptance

1. Every ORC-G* id has ≥ 1 arm, the arm was **shown red before green**, and the count in §9 is
   recomputed mechanically at accept (not read from this document).
2. The census instrument (ORC-G10) reports **0 futile kills** over the corpus generated after the
   pass that lands ORC-G2 — against the before-number **80 % (16/20)** at `5552d81`.
3. Every pass boundary has a green smoke run, and at least one of them is a **co-launch** batch.
4. No lane in the post-fix corpus exits non-zero from a guard-caused death without an enumerated
   `killed_by` (ORC-G7), verified by scanning run records, not by assertion.
5. The floor is unchanged from `total // 8` (`tools/runner:2731`); a diff that touches it fails
   accept.
6. The fleet is dispatchable on all four providers at every boundary (ORC-GP-2).
7. `untracked/T715-host-guard-incident-record.md` can be closed from §1 + §3 of this document
   without further investigation.

---

## 11. Milestone

**L1 (dispatch tooling).** This is a **loss recorded and instrumented, not a win**: the fleet's own
guard killed 16 of the 20 lanes it named for no memory benefit at all — 80 % futile, four of them
in one 88-second window on 2026-08-23 — and the arms that were supposed to prevent this were green
throughout, because they injected the number the detector was supposed to measure. It cuts against
the tooling and against the control design, not against any model. What this spec adds beyond the
brief is the before-number (§1.2), two defects the incident report did not name (the unlabeled cull
D5, the no-dwell single-sample fire D6, plus the post-race under-reporting behind ORC-G9), and the
S06 boundary (§7) that stops two sprints from editing the same six files. It buys nothing until a
pass lands; the first pass buys only characterization, which is the point.

---

## Appendix A — the census command (ORC-G10's seed)

Reproduces §1.2 at any HEAD. Promote to `tools/guard-kill-census.py` in pass 1 with the A14/A15
arms attached; do not ship it as an unarmed one-liner.

```python
import re, glob
kill = re.compile(r'^\[runner\] KILL: host memory pressure — avail (\d+) MB < floor (\d+) MB'
                  r'(?: \(largest member pid \d+ RSS (\d+) MB\))?')
reap = re.compile(r'^\[runner\]   reaping largest member: pid \d+ RSS (\d+) MB')
tot = suff = fut = 0
for path in sorted(glob.glob('untracked/log/*.log')):
    pend = None
    for ln in open(path, errors='replace').read().splitlines():
        mk = kill.match(ln)
        if mk:
            short = int(mk.group(2)) - int(mk.group(1))
            if mk.group(3) is not None:
                tot += 1; suff += int(mk.group(3)) >= short; fut += int(mk.group(3)) < short
                pend = None
            else:
                pend = short          # two-line cull form: member is on the next line
            continue
        mr = reap.match(ln)
        if mr and pend is not None:
            tot += 1; suff += int(mr.group(1)) >= pend; fut += int(mr.group(1)) < pend
            pend = None
print(f"kills_with_identified_member={tot} sufficient={suff} futile={fut}")
```

Note for the implementer: the regex must anchor on `^\[runner\] ` — an unanchored match also
catches log lines that merely *quote* the runner's source or a brief, which inflates the count
(observed: 34 → 20 once anchored). The anchor is the difference between a census and a grep.
