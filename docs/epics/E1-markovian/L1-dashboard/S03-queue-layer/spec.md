# S03 — spec: the queue layer (aging, conditions, appetite, overnight, mint safety)

**Artifact type: SPEC** (`docs/infra/sprint.md` — a spec says what we want, testably, for one
pass). **Owner:** `claude-opus-5`/S03-design · **Date:** 2026-08-21 · **Status:** PROPOSED —
audited before anything is built. Not a worker brief, not a plan, no code.

**Sits on:** `S01-process-ownership/pass2/spec.md` (the held supervisor — `managent supervise`).
The queue layer is the *policy* that decides **which row to hand the supervisor next**; the
supervisor is the *mechanism* that holds the child. Inert without it.

**Inputs.**
`docs/status/orchestration-layer-spec.md` §3 and §7 (the sketch + the operator's resolved
rulings, 2026-08-21) · `S01/pass2/spec.md` §2.1 (the fleet-fill loop the policy runs inside),
§3 (one dispatch interface), §2.5 (shutdown) · `tools/fleet-keeper.sh` (the recovered
implementation) · `docs/infra/fleet-keeper-design.md` (T500, the authoritative pressure
algorithm) · `docs/infra/managent/directives.jsonl` D022 (2026-08-19T23:07:31Z) and D023
(2026-08-19T23:17:11Z) (the operator's own words) ·
`S02-model-delegation/measurement-methodology.md` §1 (the appetite table) ·
`src/managent/main.zig` (the store schema and the engine's own needs rule).

**One line.** A row is queued once; it climbs while it waits; it is dispatched only when every
condition holds; nothing it does can silently mint more work; and no held process is ever
invisible.

---

## 0. How to read this document

Every normative statement carries an id (`Q-ORD-3`, `Q-COND-2c`, `Q-MINT-4`). §9 is the control
table: **every id has at least one seeded arm that flips it and one null arm that must stay
green.** An id with no control is not a requirement, it is a wish (`feedback-never-trust-a-green-test`:
an instrument earns its first reading only after a null control and a seeded-defect control).

Statements that **change** behaviour recovered from `tools/fleet-keeper.sh` are marked
**[CHANGE]** and are listed together in §10 for ruling. Pass 2 §8.2 says the fleet-fill policy
is carried "behaviour-preserving"; seven things in here are not, and they are named in §10 rather
than smuggled.

---

## 1. Recovery — the old shell implementation, exactly as it is

The operator recalls aging-priority logic that "lived in the old dispatch scripts and worked".
It was found. It is `tools/fleet-keeper.sh` (794 lines, bash wrapper around one embedded
`python3` heredoc), specified by `docs/infra/fleet-keeper-design.md`, and it is **live today**
as the `DFLEET` duty. Line citations below are against `tools/fleet-keeper.sh` at commit
`1b8e627`.

### 1.1 What is actually implemented

| # | behaviour | where | exact rule |
|---|---|---|---|
| R1 | **priority number** | `:229-245` (`priority_of`) | read `priority=N` from the bundle's `<!--managent …-->` header (first 2048 bytes); `0 ≤ N ≤ 99`, 99 highest; **default 50** when absent, unparseable, or out of range. No bundle ⇒ 50. |
| R2 | **the bump** | `:247-258` (`waiting_of`) | `waiting=1` in the same header is a **boolean** that outranks every priority number. |
| R3 | **FIFO tie-break** | `:211-223` (`added_of`), `:677` | third key is `added` **ascending** (oldest first), read from `managent show <id>`'s `added:` line — the public CLI, deliberately not the store schema. |
| R4 | **the sort** | `:677` | `elig.sort(key=lambda e: (-e["waiting"], -e["priority"], e["added"]))` — three keys, no fourth. |
| R5 | **cap drop (the "aging" the operator remembers)** | `:679-701`, design §6–§7 | if the **top** eligible row is conflict-blocked it becomes the `anchor`; each later iteration in which *the same* anchor is still the blocked top, `drops += \|completed\|` where `completed = prev_running − running`; `c_eff = max(1, CAP − drops)` (`:701`). Exit is immediate and total on the first iteration with no blocked top (`anchor=null, drops=0`). |
| R6 | **cap floor 1** | `:701`, design §7 | `max(1, …)`. Design §7 proves sufficiency: `drops` counts only completions *while still blocked*, at most `C−1` of them, so the arithmetic bottoms at 1 by itself; the explicit `max` guards a manual over-cap dispatch. |
| R7 | **the one-writer invariant** | `:770-777` | two tests: `holds ∩ inprog_holds = ∅` **always**, and `holds ∩ anchor_holds = ∅` **while pressured**. The second is not subsumed by the first (design §8 step 4: the anchor may hold `{a,b}` with only `a` currently held). |
| R8 | **eligibility filters** | `:628-668` | status `dispatchable` (`:629`) · not a duty (`:631`) · id matches `T\d+` (`:633`) · not inside the heal cooldown (`:636-641`) · needs met (`:642`) · exactly one bundle (`:644`) · not inside the per-row dispatch cooldown/backoff/live-pid park (`:648-663`) · resolved model passes the allow/deny/bench gate (`:666`). |
| R9 | **model window** | `:118-123`, `:260-272` | `FLEET_MODEL_ALLOW` / `FLEET_MODEL_DENY` comma lists of canonical labels; DENY wins; **durable default DENY = `glm-5.2,minimax-m3,kimi-k2.7`** (D036) unless the env var is explicitly set, even to empty. |
| R10 | **exploration-first default model** | `:274-294` | a row with no stored model gets the **least-measured** allowed model (fewest ledger rows, ties by a hardcoded canonical order), not a favourite. |
| R11 | **backoff + circuit breaker** | `:420-424`, `:426-503` | a fired row whose recorded pid is gone while the row never left `dispatchable` is one *pre-claim death*: `300 → 600 → 1200 → 3600 s` per-row backoff; `MODEL_FAILURE_TRIP=3` distinct rows dying on one model benches that lane for `LANE_RETRY=1800 s`. A real claim resets the model streak. |
| R12 | **logjam telemetry** | `:721-747` | after `FLEET_LOGJAM_FLAG=60` minutes with the same anchor, write `untracked/fleet-keeper.logjam.flag` naming the anchor, its held files, the per-file holder, and the wait in minutes; log a `LOGJAM:` line every iteration. Telemetry only — never an override. Reconciled (deleted) the first iteration the condition is false (`:748-762`). |
| R13 | **cooldown + dead-man's switch** | `:173-182`, `:544-561` | the file `untracked/fleet-keeper.cooldown` is the graceful stop; an **unreadable containing directory also counts as cooldown** — "a dead fleet is the safe failure, not a free-for-all". Under cooldown the `running` snapshot still advances so `completed` stays an honest diff. |

### 1.2 What is **not** implemented — the honest finding

**There is no aging anywhere in the recovered code.** Priority is a static number read from a
file; nothing ever increments it; there is no per-row wait counter, no pop counter, no
"lowest-minus-one" insert rule. Confirmed three ways:

1. The sort key at `:677` has exactly three terms and none is a function of elapsed time or of
   dispatch count.
2. `priority_of` (`:229-245`) is a pure function of the bundle file; it has no write path.
3. `docs/infra/fleet-keeper-design.md` §9 **argues against** any clock in the ordering, and
   wins the argument on testability: *"The only clock in the whole mechanism is telemetry
   (`waiting_since`, for the §10 flag). It never feeds a dispatch decision."*

The operator's memory is accurate about the *effect*, not the mechanism. What exists and works
is the **cap-drop pressure machine** (R5): a starved row's *share of the fleet* climbs
monotonically — 5 slots, then 4, 3, 2, 1 — until it runs near-solo. That is aging measured in
parallelism rather than in priority points, and it is his own arithmetic verbatim: D023
(2026-08-19T23:17:11Z) — *"the parallel cap drops by one for each completing task while a 'next'
task remains blocked, until the waiting task's holds are all free and it can run (solo if
needed); once it dispatches, the cap resets to normal (5)"*. The priority number itself comes
from D022 item 2 — *"tasks carry a priority 0-99 (99 highest, 0 lowest; default 50 when
unset)… tie-break by added-time"* — which is where "50/99" comes from: **50 is the default, 99
is the ceiling**, not two thresholds.

So the brief's "recover the old implementation" resolves as: R1–R13 are recovered and re-spec'd
below unchanged, **and the numeric aging is new work**, specified in §2 from the operator's
2026-08-21 words rather than recovered from disk. Saying otherwise would be inventing a
provenance (`feedback-status-is-an-assertion`: absence of an assertion is UNKNOWN, and here the
absence is now *known* — three independent reads).

### 1.3 The one thing that was tried and rejected

D022 item 3 proposed the escape "if the top row's holds are all held and it has waited > N
minutes, dispatch it anyway with a warning". The operator **rejected** it on 2026-08-20 01:07
(design §1, quoted verbatim there): holds are advisory at the keeper but the files are not; two
consoles writing `src/retro.zig` corrupt silently. `FLEET_LOGJAM_WAIT` and `logjam.json` were
deleted. **Nothing in this spec may reintroduce a dispatch-anyway path**; that is the standing
foreclosure the aging design is checked against (`Q-ORD-9`).

---

## 2. Ordering — aging priority

### 2.1 The key

**Q-ORD-1 (the fields).** Each row carries two integers in the store: `priority` (the authored
number, `0..99`, default 50 — R1's semantics, moved from the bundle header into the store row,
see `Q-ORD-8`) and `age` (accrued pass-overs, `0..AGE_CAP`, default 0, initialised at
registration). `waiting` stays a boolean (R2).

**Q-ORD-2 (effective priority).** `effective = min(99, priority + age)`.

**Q-ORD-3 (the total order).** Eligible rows are ordered by, in descending preference:

```
1. waiting        desc   (the operator's manual bump — R2, unchanged)
2. effective      desc   (Q-ORD-2)
3. age            desc   (longest-starved first, decides ties at saturation)
4. added          asc    (FIFO — R3, unchanged)
5. id             asc    (total-order closure; no two rows share an id)
```

Key 5 makes the order **total**: no two distinct rows ever compare equal. This is load-bearing,
not tidiness — see `Q-ORD-7`.

**Q-ORD-4 (accrual — the only write).** On each iteration in which the queue **fires** a row,
`age += 1` for every row that was in the **eligible** set (§3) that iteration and was not the
row fired — including rows that were eligible but conflict-blocked. A row excluded from
eligible for *any* reason (needs, appetite, backoff, heal cooldown, missing bundle, missing
acceptance, host-quiet, pending ratification) accrues **nothing** that iteration. An iteration
that fires nothing (cap, cooldown, no conflict-free candidate) accrues nothing.

**Q-ORD-5 (saturation).** `age` is clamped at `AGE_CAP = 49` (default). With the default
`priority = 50` this makes `effective` reach exactly 99 — the top of the operator's own scale —
and no further. A row authored at 99 starts saturated.

**Q-ORD-6 (equivalence to the operator's arithmetic).** The ruling describes FIFO as *"lowest-
priority-in-queue minus 1, all bump one on each pop"*. Q-ORD-2/4 produce the same order without
the shared minimum:

- *Same-base FIFO.* Two rows with equal `priority`, both continuously eligible: both accrue +1
  per fire, so the earlier entrant's `age` is ≥ the later one's, and strictly > if any fire
  occurred between their entries. Ties fall to key 4 (`added` asc). ⇒ FIFO. ∎
- *Crossover with a pinned row.* A default row (50) overtakes a pinned 99 after 49 fires it
  loses. Under the operator's scheme (+1 to all, insert at min−1) the same crossover lands at
  the same count, because a uniform +1 to every queued row leaves all differences invariant and
  only the *newcomer's* insert position matters. The two schemes agree up to the crossover. ∎
- *Difference, deliberate.* His scheme lets a default row climb **past** 99 unboundedly; ours
  saturates into a tie and resolves it by key 3 (`age` desc) in the starved row's favour. Same
  winner, but every number in the store stays inside the scale the operator reads (`0..99`). An
  ordering field that can print `1473` is not a priority anyone can reason about.
- *Why not literally +1-to-all-on-pop.* It rewrites every queued row's authored number, so the
  operator's `priority=99` is destroyed by the mechanism after one night, and the ordering stops
  being reproducible from the store (the L1 bar: every gauge re-derivable from disk by hand).
  Separating authored `priority` from accrued `age` keeps both facts, and `effective` is derived
  at read time — which is the S02 methodology §3 rule ("store what was observed; never freeze a
  derived number") applied to the queue.

**Q-ORD-7 (anchor stickiness).** **[CHANGE]** While `anchor != null` and the anchor row is still
eligible and still conflict-blocked, it **remains** the anchor even if another row's `effective`
overtakes it. Re-anchor only when the anchor leaves the eligible set or becomes conflict-free.

*Why this clause exists.* R5 keys the anchor to *the top of the order* (`:687`). With a static
priority the top is stable, so keying to it is safe. With aging the top churns: two starved
mutation rows accrue in lockstep and can swap places, and every swap is a re-anchor that resets
`drops = 0` (`:694-698`), so `c_eff` never falls and the pressure machine becomes **vacuous** —
the fleet stays at 5 forever while both rows starve. This is a defect that aging *introduces*
into working code, which is exactly the class of thing a design pass exists to catch. Stickiness
costs nothing: the overtaking row is still a *candidate* and still runs the moment it is
conflict-free (§8 step 4 of the recovered design), so stickiness changes who *anchors*, never
who *runs*. Control: arm `P4`.

**Q-ORD-8 (where the fields live).** **[CHANGE]** `priority`, `age`, and `waiting` move from the
bundle header into the store row (`src/managent/main.zig`'s `TaskState` (`:66-107`), beside `claim_count`
and `due_after`). Reasons: (a) `age` is written by the queue, and the queue must not edit worker
briefs; (b) the recovered `priority_of`/`waiting_of` re-open and re-parse the bundle
twice per eligible row per iteration (`:225-258`) and `added_of` forks a `managent show`
subprocess per eligible row (`:211-223`) — at 12 eligible rows and a 10-second tick that is 24
file reads and 12 process spawns every 10 seconds, the enumeration cost pass 2 Open question 5
already flags; (c) one writer (pass 2 HOLD-6) requires one location. The bundle
header keys stay **accepted** as the authoring surface — `managent add` reads `priority=` /
`waiting=` into the row once, at registration — so no brief has to be rewritten and the
operator's habit is preserved. `acceptance=` stays last in the header (T217).

**Q-ORD-9 (the foreclosure).** Aging **never** authorises a dispatch. `effective` is an input to
*ordering only*. Every condition in §3 is evaluated after the order is computed and vetoes
regardless of `effective = 99`. Mechanized: the dispatch path contains no comparison of a
priority/age value against a threshold — `grep -nE "effective|priority|age" <dispatch decision
region>` returns only the sort. This is the §1.3 rejected escape, kept dead. Control: arm `A6`.

### 2.2 The cap drop

**Q-CAP-1.** R5–R7 are carried **unchanged** in arithmetic: entry sets `anchor`, `drops = 0`,
`waiting_since = now`; each iteration with the same anchor still blocked adds `|completed|`;
exit is immediate and total; `c_eff = max(1, C_window − drops)`.

**Q-CAP-2 (the window term).** **[CHANGE]** `C_window = min(C_base, C_mode)` where `C_base = 5`
(the operator's 2026-08-19 ruling, design §12) and `C_mode` is the mode cap — `C_mode = C_base`
by day, `C_night` overnight (§6). The floor stays 1. So the night cap and the pressure drop
compose by taking the min first, then subtracting, and the floor still guarantees a slot for the
freed anchor (design §7 reason 1).

**Q-CAP-3 (only a runnable row may anchor).** A row excluded from eligible by needs, appetite,
backoff, heal cooldown, host-quiet, missing bundle, missing acceptance, or pending ratification
is **not** the anchor and does not create pressure. Only a `conflict-blocked` row anchors —
i.e. a row that would run *now* but for another task's holds.

*Why this clause exists.* It is the self-DoS hole that aging opens. An unrunnable row that keeps
accruing `age` climbs to the top of the order; if the top of the order could anchor, that one
permanently-unrunnable row would cool the entire fleet to `c_eff = 1` indefinitely — a
fleet-wide denial of service minted by a single bad row. The recovered code is partly protected
by accident (the model gate sits *inside* `eligible` at `:666`, and design §11 notes the
consequence), but appetite-OFF plus aging is a new path and the invariant must be stated, not
inherited. Q-ORD-4 (no accrual while ineligible) is the second half of the same defence.
Control: arms `A5`, `M8`.

**Q-CAP-4 (logjam telemetry).** R12 unchanged, with one addition: the flag line also records the
anchor's `effective` and `age`, so the operator can see *why* this row is the anchor without
recomputing the order by hand.

---

## 3. Conditions — non-negotiable, each with a control that flips it

The operator's ruling: *"conditions are non-negotiable — they must be satisfied before any
dispatch, regardless of priority."* Structurally: **conditions are a conjunction evaluated as a
filter on the eligible set; the order is a sort applied afterwards.** No condition is weighted,
scored, or traded against priority. A condition either holds or the row is not eligible.

**Q-COND-0 (the shape).** `eligible = { r ∈ rows : C1 ∧ C2 ∧ … ∧ C11 }`, then §2's order, then
§8's candidate filter, then fire one. A row failing any condition is **reported** with the
condition that failed (§6's no-silent rule extends to non-dispatch: an idle queue must say why),
never silently skipped.

### 3.1 The five named conditions

**Q-COND-1 — holds clear.** Three tests, all carried from R7 plus pass 2:
- (a) `r.holds ∩ inprog_holds = ∅` — the one-writer invariant, always. `inprog_holds` is the
  union of `holds` over rows the queue observes as `in_progress`.
- (b) `anchor ≠ null ⇒ r.holds ∩ anchor.holds = ∅` — compatibility with the blocked anchor.
- (c) **[CHANGE, from pass 2 §2.1]** `r.id ∉ supervisor.held_children` — the in-memory child
  set, consulted *before* the store moves. This is the fix for the 80-fires-in-3.5-minutes red;
  it belongs in the condition list, not only in the mechanism, because a queue that re-fires a
  row it is already holding has violated "holds clear" in the only sense that matters.
- Controls: `H1` null (disjoint holds ⇒ dispatch), `H2` seeded (intersecting holds ⇒ never
  dispatched, under both NORMAL and PRESSURED), `H3` seeded (anchor holds `{a,b}`, running holds
  `{a}`, candidate holds `{b}` ⇒ refused — the non-subsumption case), `H4` seeded (slow-claiming
  stub ⇒ exactly one fire).

**Q-COND-2 — needs satisfied.**
- (a) Every id in `r.needs` exists in the store and has `status == done`. Carried from R8 /
  `tools/fleet-keeper.sh:201-206`.
- (b) **[CHANGE]** …**and** its `verdict ∈ {pass, pass-with-findings}`. A dependency closed
  `blocked`, `abandoned`, or `fail-found` does **not** satisfy a need; the dependent stays
  `blocked` and is reported as *"needs T541, which closed blocked"*.
- (c) A missing dependency id is a **refusal that names the row**, not a silent block.

*Evidence this matters.* Today's rule is `status != done ⇒ unmet`, in **two** independent
implementations that agree — `tools/fleet-keeper.sh:201-206` and `src/managent/main.zig:1550-1557`
(`needsMet`). Because they agree, this is a deliberate rule, not a one-sided bug, so changing it
is a policy decision needing a ruling (§10) and it must change in **both** or the queue and the
engine will disagree about which rows are `dispatchable` — the engine derives that status at
`main.zig:1559-1563`. The live store has 9 done-but-not-passed rows (7 `blocked`, 2 `abandoned`)
and one real instance: **T535 needs T541, and T541 closed `blocked`** — today T541 counts as
satisfied. Controls: `N1` null (dep `pass` ⇒ satisfied), `N2` seeded (dep done+`blocked` ⇒ NOT
satisfied), `N3` seeded (dep absent ⇒ refusal naming the id), `N4` (mutation: revert to the
status-only rule ⇒ `N2` must go red).

**Q-COND-3 — appetite permits.** §4 in full.

**Q-COND-4 — fleet quiet.** **[CHANGE — this condition does not exist today.]**
- (a) `host_avail_mb ≥ HOST_FLOOR_MB + headroom(family)` at admission time, where `headroom` is
  a data-table attribute per family (§5) — a local MLX model needs ~18 GB, a cloud API worker
  needs ~200 MB.
- (b) `loadavg1 ≤ QUIET_LOAD × ncpu` (default `QUIET_LOAD = 1.5`).
- (c) **Measured-suite interlock:** while a measurement run is declared in progress, `PROBE`-
  appetite (local) families are not admitted at all — S02 methodology §1 reservation, *"never
  during a measured suite run (load contamination — the D6/D12/D14 cull)"*.
- (d) The reading is injectable for tests via the existing `WEIZIGO_HOST_MEM_AVAIL_MB` hook
  (`tools/runner:899-909`), so no arm has to exhaust real memory.

*Why this is new.* The recovered keeper has **no** host check — the only `mem`-shaped tokens in
`tools/fleet-keeper.sh` are `json.load` calls. The host-memory floor exists solely in
`tools/runner:853-910` as a **post-hoc killer** (pass-1 C4). So today the queue may admit a
worker onto a host with 46 MB free, and the guard's remedy is to kill something afterwards. That
is the exact shape of the 2026-07-29 kernel panic (12.5 GB Debug `zig` compile, watchdogd
starved 91 s). Admission-time quiet is the cheap half of a guard that already exists; the
killer stays as the backstop. Controls: `Q1` null (headroom available ⇒ dispatch), `Q2` seeded
(injected low memory ⇒ no dispatch, loud line naming the reading and the floor), `Q3` seeded
(measurement declared + a PROBE row at the top of the order ⇒ not admitted, and the next
non-PROBE candidate runs).

**Q-COND-5 — discharge known.** A row is not dispatchable unless *done is gate-able before the
work starts*: `r.acceptance ≠ null` **or** `r.skip_acceptance_reason ≠ null`. **[CHANGE]**
- Rationale: the sketch's own words — *"a row is done only when its acceptance command exits 0
  and its deliverables are committed and its verdict is recorded… a queue that reports success
  while doing nothing is the named recurring defect."* An acceptance command invented *at close
  time* by the worker that wants to close is not a gate, it is a self-grade.
- **Sizing, measured on the live store (2026-08-21).** 18 rows derive as `dispatchable`; **12**
  of them are the `T\d+`, non-duty rows the queue would actually consider (Q-COND-7); and
  **zero** of those 12 carry an `acceptance` command or a `skip_acceptance_reason` — T511, T522,
  T524, T525, T526, T527, T529, T530, T531, T533, T544, T548. Store-wide it is 77 of 251 rows.
  So this condition, enforced as stated, parks **the entire dispatchable queue**. That is the
  honest cost, and it turns the migration from optional into a precondition: the condition is
  enforced for every newly registered row from day one, **and** a backfill row (12 acceptance
  commands, or explicit skip reasons) must be closed before the queue goes live. Enforcing it
  retroactively with no backfill would leave the queue reporting "nothing eligible" all night —
  the same class of failure as reporting success while doing nothing.
- Controls: `D1` null (acceptance set ⇒ dispatch), `D2` seeded (both null ⇒ refused, message
  names the row and the field), `D3` seeded (`skip_acceptance_reason` set with a non-empty
  reason ⇒ dispatch, and the reason appears in the run record).

### 3.2 The six carried conditions (R8/R11 — recovered, unchanged)

| id | condition | source | control |
|---|---|---|---|
| Q-COND-6 | derived status is `dispatchable` | `:629`; engine `main.zig:1559-1563` | `C1` seeded: `in_progress`/`done`/`blocked` rows never fire |
| Q-COND-7 | not a duty row; id matches `T\d+` (no `ORCHA-*`, `STANDING-*`) | `:631-634` | `C2` seeded: a duty row and a `STANDING-*` row in the pool, neither fires |
| Q-COND-8 | exactly one bundle `untracked/<id>-*.md` | `:208-209`, `:644` | `C3` seeded: zero bundles ⇒ refuse; two bundles ⇒ refuse (name collision) |
| Q-COND-9 | outside the heal cooldown (`HEAL_COOLDOWN = 600 s`, fresh T477 heal record **or** `claim_count ≥ 2`) | `:568-607`, `:636-641` | `C4` seeded: a just-healed row is parked, then admitted after the window |
| Q-COND-10 | outside the per-row dispatch cooldown / pre-claim backoff / live-pid park (`DISPATCH_COOLDOWN = 300`, backoff `300→600→1200→3600`) | `:420-424`, `:648-663` | `C5` seeded: three pre-claim deaths ⇒ the three backoff steps observed, no re-fire inside a window |
| Q-COND-11 | the resolved model's lane is not benched (`MODEL_FAILURE_TRIP = 3` distinct rows, `LANE_RETRY = 1800 s`) | `:426-503`, `:260-272` | `C6` seeded: three rows die on one model ⇒ lane down, `lane-down.json` written, a row on another model still fires |

**Q-COND-12 (cooldown precedence).** R13's precedence is unchanged and sits **above** the
conjunction: cooldown ⇒ dispatch nothing, advance the `running` snapshot, touch nothing else.
Pass 2 §2.4 moves the flag file to a store field and retires the missing-directory dead-man's
switch while **preserving its direction**: an unreadable store ⇒ dispatch nothing, loudly.
That direction is restated here as a condition-layer rule: **every unreadable input fails
closed.** Control: `C7` seeded (store unreadable ⇒ zero dispatches, non-zero report, no crash).

---

## 4. Appetite — a spectrum, two mechanisms

Levels, from S02 methodology §1: `OFF < PROBE < CONSERVE < SPEND < RESERVED`. The ruling:
*hard* = a family is forbidden outright; *soft* = back-pressure. The distinction is made
mechanically, not by degree.

**Q-APP-1 (the axis rule — the load-bearing design decision).** Appetite acts on **model
resolution and admission**. It **never** alters task ordering. A row's position in §2's order is
a function of the row alone (`waiting`, `priority`, `age`, `added`, `id`) and of nothing about
which model it resolved to.

*Why.* A priority penalty for a CONSERVE model would make the queue order depend on model
assignment, so re-pointing one row's model would silently reorder unrelated work, and the
ordering would no longer be re-derivable from the task table by hand — the L1 bar. Keeping the
axes separate means the two mechanisms are independently testable: an ordering arm never needs
an appetite fixture, and an appetite arm never needs to reason about `age`.

**Q-APP-2 (hard — `OFF`).** The family is not in the candidate pool. Implementation: the family
row's `appetite = OFF` removes every one of its labels from `model_allowed()` (R9's mechanism,
generalised from two env lists to one table column). A row *pinned* to an OFF family is
ineligible and is **reported as parked-on-appetite** — not silently dropped, and (Q-CAP-3) never
an anchor. A row with **no** pinned model resolves to an allowed family instead (R10's
least-measured rule, restricted to allowed families as today at `:283`).
- Current mapping: `ollama-cloud` (glm-5.2, minimax-m3, kimi-k2.7) = **OFF** — 0 tokens, D036.
  Rejoin is a **human flip**, never a calendar auto-trust (methodology §1). This replaces
  R9's `DEFAULT_DENY` string with the table's own value; the env override survives as an
  operator escape hatch for a forced window.

**Q-APP-3 (hard-conditional — `RESERVED`).** Denied **unless** the row's `task_type` is in the
family's `reserved_for` list. Not a soft preference: a row outside the list cannot resolve to a
RESERVED family at all, even if every other family is at its cap.
- Current mapping: `claude-fable-5` = **RESERVED**, `reserved_for = [deep-holistic-review,
  gate-holder-verification, spec-design-adjudication]`, plus the hand-over rule (`feedback-fable-under-90-of-200k`)
  expressed as an attribute `handover_at_tokens = 180000`.
- A row that names a RESERVED family with a non-reserved `task_type` is refused **at registration
  time** as well as at admission, so the mistake is caught when it is cheap.

**Q-APP-4 (soft — `CONSERVE`).** Three mechanisms, all admission-side:
- (a) **Family sub-cap.** `concurrent_max(family)` — at most that many held children resolved to
  that family at once (default 1 for CONSERVE, unbounded for SPEND). A candidate that would
  exceed it is skipped **for this iteration only** and the next candidate is considered; the
  skipped row keeps its `age` accrual because it *was* eligible (Q-ORD-4).
- (b) **Lane substitution.** If the row's model is **unpinned** and some `SPEND` family is
  qualified for the row's `task_type` (per `docs/infra/model-task-matrix.md`), resolve to the
  SPEND family. This is methodology §1's *"only where no cheaper qualified lane exists"* turned
  into a resolution rule instead of a prose reminder. A **pinned** row is never re-pointed —
  re-pointing an operator's explicit choice would be the mechanism overruling the human.
- (c) **Window guard.** `min_window_s(family)`: never start a row whose `wall_class` estimate
  exceeds the family's remaining declared budget window. For claude, that is the 5-hour rolling
  window reservation from methodology §1 stated as arithmetic: `est_wall_s ≤ window_remaining_s`.
  The window remaining is an **operator-declared** number in the family row (`window_resets_at`),
  not a scraped one — we do not have an API for it, and a guessed number that gates dispatch is
  worse than a declared one.
- Current mapping: `claude` (opus / sonnet / haiku) = **CONSERVE**, weekly ≈70 % used.

**Q-APP-5 (soft — `PROBE`).** Admitted only for rows carrying `probe = true`, and never while a
measurement is declared (Q-COND-4c). Current mapping: `local` (qwen3.8:27b-mlx, gemma*) =
**PROBE**.

**Q-APP-6 (none — `SPEND`).** No admission gate beyond the burn-rate **report** (a gauge, not a
veto). Current mapping: `deepseek` (v4-pro, v4-flash) = **SPEND**.

**Q-APP-7 (reservations outrank appetite).** Methodology §1: *"Reservations are hard and override
appetite."* So `RESERVED` and the per-family `reservations` column are evaluated **before** the
level. A family at `SPEND` with a reservation still refuses a row the reservation excludes.

**Q-APP-8 (the appetite table is data).** One row per **family** (not per model), in the same
data file as §5's dispatch table. Columns: `family`, `models[]`, `appetite`, `concurrent_max`,
`reserved_for[]`, `probe_only`, `min_window_s`, `window_resets_at`, `budget_note`, `as_of`. The
authority remains methodology §1's prose table; this is its machine-readable mirror, and
**§9's arm `A7` asserts the two agree** — a mirror that can drift from its source silently is
the F7 four-definitions defect again.

| family | appetite | mechanism it maps to | current effect |
|---|---|---|---|
| ollama-cloud (glm / minimax / kimi) | OFF | Q-APP-2 hard | no dispatch at all; human flip to rejoin |
| claude (opus / sonnet / haiku) | CONSERVE | Q-APP-4 (a)+(b)+(c) | sub-cap 1, substitute to DeepSeek when unpinned, 5 h window guard |
| claude-fable | RESERVED | Q-APP-3 hard-conditional | three task types only; hand over at 180 k |
| deepseek (pro / flash) | SPEND | Q-APP-6 | unconstrained; burn-rate gauge only |
| local (qwen / gemma) | PROBE | Q-APP-5 + Q-COND-4c | probe rows only; never during a measured run |

**Controls.** `A1` seeded: OFF family pinned ⇒ parked, reported, not an anchor. `A2` seeded:
RESERVED family + non-reserved `task_type` ⇒ refused at registration and at admission; with a
reserved type ⇒ admitted. `A3` seeded: CONSERVE sub-cap 1 with two ready rows on that family ⇒
exactly one held child, the second still accrues `age`. `A4` seeded: unpinned row + CONSERVE
family qualified + SPEND family qualified ⇒ resolves SPEND; the same row **pinned** to the
CONSERVE family ⇒ stays on it. `A5` seeded: an OFF-pinned row at the top of the order ⇒ `c_eff`
stays at `C_window` (Q-CAP-3). `A6` seeded: a row at `effective = 99` failing one condition ⇒
not dispatched (Q-ORD-9). `A7` null: the table mirrors methodology §1 exactly (field-by-field
diff). `A8` seeded: `est_wall_s > window_remaining_s` ⇒ not started, reported.

---

## 5. One dispatch — the data/code split, settled

**The question.** Is `model → harness` fully data (a table row), or do hardcoded family branches
remain? Pass 2 DP-2 says data; the sketch §7 item 3 says *"lean data, but the design must prove
it."*

### 5.1 What varies today, measured

Every family-varying behaviour on the current dispatch path, with its site:

| # | varying thing | sites | shape |
|---|---|---|---|
| V1 | label → provider family | `bin/dispatch:76-88` (`MODELS`), `bin/subagent:52`, `:57-62`, `:69-77` | **already data** (three copies of it, which is the F7 drift) |
| V2 | input aliases (`dspro`, `:cloud`, `kimi-k2.7-code`) | `bin/dispatch:91-94` (`ALIASES`), `:97-107` (`canonicalize_model`); `bin/subagent:69-77` | **already data** + one normalising function |
| V3 | argv template | `bin/subagent:247-272` — `pi --provider deepseek --model M -p P` / `ollama launch pi --model TAG -y -- -p P` / `claude -p P --model M --allowedTools T` | **branch today**; template with named holes |
| V4 | required env | `bin/subagent:237-239` (`DEEPSEEK_API_KEY`) | **branch today**; a `require_env[]` list |
| V5 | tool allowlist | `bin/subagent:65` (`CLAUDE_ALLOWED_TOOLS`) | already data, but keyed by a family name |
| V6 | stdout envelope | claude passes `--output-format json` and the runner buffers instead of streaming (`tools/runner:990-995`, `forward=False`, *"a claude JSON lane"*) | **branch today**; a 2-value enum |
| V7 | post-exit release call | `ollama stop <model>` (pass 2 §4) — daemon-owned model outlives `treekill` | **branch today**; a command template or none |
| V8 | guard defaults | `--rss-cap-mb` documented "deepseek only" (`bin/subagent:8`); local MLX needs ~18 GB headroom | **branch today**; numeric attributes |

### 5.2 The verdict: fully data, with one naming rule

**Q-DP-1 (fully data).** All of V1–V8 are expressed as columns of one table, one row per family,
in **one** location — pass 2 DP-2's `canonical_models[]` region in `src/managent/main.zig`,
extended (today it is a flat list of ten label strings at `src/managent/main.zig:115-126`).
`bin/dispatch`'s `MODELS`/`ALIASES` and `bin/subagent`'s `OLLAMA_TAG_TO_CANONICAL`/
`CLAUDE_MODELS` are deleted, not kept as second copies.

**Q-DP-2 (zero necessary branches).** No family branch remains on the dispatch path. The
argument, per behaviour:
- V1, V2, V5, V8 are *values*. A branch that selects a value is a lookup written badly.
- V3 is a *template*: `argv_template = ["pi","--provider","{family_provider}","--model",
  "{model}","-p","{prompt}"]` with a fixed hole set `{model, tag, prompt, nonce, wall}`. One
  interpolator, family-agnostic, for all rows.
- V4 is a *list*: `require_env = ["DEEPSEEK_API_KEY"]` (empty for the others), plus an optional
  `preflight` command template. One loop over the list.
- V6 and V7 are the only *behavioural* variations. Each becomes a bounded, **capability-named**
  enum with one interpreter per value: `stdout_envelope ∈ {raw, json_result}` and
  `release ∈ {none, <command template>}`.

**Q-DP-3 (the naming rule — how a 1-family interpreter is still "data").** V6's `json_result`
today has exactly one user (claude). A single-user interpreter is a legitimate honest worry: is
it a branch wearing a costume? The rule that resolves it: **an interpreter is named for the
capability, never for the family.** `json_result` unwraps a JSON envelope and takes `.result`;
any future family emitting the same envelope selects the same value with no code change. A
`claude_envelope` branch would fail this test, and it also fails the mechanized gate below,
which is the point — the gate makes the rule enforceable rather than aspirational.

**Q-DP-4 (the mechanized gate).** Pass 2 DP-3's grep, extended to the queue layer: 
`grep -nE "claude|deepseek|ollama|qwen|glm|minimax|kimi|gemma|\bpi\b"` over the dispatch,
resolution, appetite, and condition regions — **excluding** the data-table region delimited by
pinned sentinel comments — returns nothing. Unscoped it can never pass (the table holds every
token), which is exactly pass-1 §7.1's argument. A family token outside the table is the drift
alarm.

**Q-DP-5 (the proof obligation for any future branch).** A proposed family branch is admissible
only with a written argument that its behaviour (a) cannot be named as a capability, **or**
(b) cannot be selected by a bounded enum. Recorded in this spec's successor, never in a code
comment. Current count of admissible branches: **zero**.

**Q-DP-6 (what stays code, and is not family-shaped).** The prompt builder (nonce, orient
preamble, deliverables, inbox loop) is one shared function for every family — pass 2 DP-2, and
already true in `bin/subagent` today. The verify (nonce echo, deliverables exist, row closed,
findings parse) is family-independent by construction (pass 2 DP-4).

**Controls.** `DP1` null: every canonical label resolves to a complete row (all eight columns
present) — a missing column is a FAIL, not a default. `DP2` seeded: add a **fictional** eleventh
family as a table row only, with a stub binary; a dispatch through it succeeds end-to-end with
**zero** source edits. This is the real test of "data, not code" and it is cheap. `DP3` null: the
scoped grep returns nothing; the unscoped grep returns hits (proving the gate is scoped, not
vacuous). `DP4` seeded: delete the sentinel comments ⇒ `DP3` must go red (instrument mutation).

---

## 6. Overnight — conservatism, and no silent process

**Q-NIGHT-1 (a mode, not a clock).** Overnight is an explicit launch mode
(`managent supervise --overnight`), not a wall-clock window. Reasons: the operator launches the
night run, so the mode is known at launch; and design §9's argument holds — a clock in a
dispatch decision costs clock injection in every arm and buys nothing here. A scheduled window
may be added later as a launcher concern, never as a decision input.

**Q-NIGHT-2 (reduced parallelization).** `C_night` (default **2**) feeds `C_window` per Q-CAP-2,
so the night cap and the pressure drop compose and the floor stays 1. Rationale for 2 rather
than 1: one long build plus one short row keeps the queue draining without two heavy processes
contending for the host — and 1 is still reachable, via pressure, when a blockage warrants it.
`C_night` is a number in the mode row, not a constant in code.

**Q-NIGHT-3 (walls: higher, and not the stuck-detector).** This is where the "table/engine
builds must not time out prematurely" requirement is discharged, and the recovered tooling
already made the right call: `tools/runner:70-81` (T214) — *"progress watchdog replaces wall/CPU
ceilings. Wall and CPU ceilings are bad stuck-detectors — they kill correct long-running jobs."*
Carried and made explicit:
- (a) Each row declares a `wall_class`; the table gives each class a wall. Classes:
  `harness` (2700 s — today's `bin/dispatch:70` `DEFAULT_WALL`), `build` (6 h), `table` (24 h),
  `unbounded` (no wall; requires `progress_total` to be declared, per (c)).
- (b) Overnight **multiplies** the class wall by `NIGHT_WALL_FACTOR` (default 2) and never
  reduces it. A row whose class has no wall keeps none.
- (c) The **RSS cap stays absolute** and is never relaxed by mode or by progress
  (`tools/runner:76-77`: *"No progress earns an exemption from a memory-exhaustion kill"*) — the
  2026-07-29 kernel panic is the reason and it is not negotiable.
- (d) The progress watchdog, not the wall, is the stuck-detector: `progress_timeout` (default
  600 s) kills on silence. Overnight **tightens** the reporting requirement while loosening the
  wall — the two move in opposite directions on purpose.

**Q-NIGHT-4 (the progress-line contract).** **[CHANGE — an extension, backward compatible.]**
A held worker must emit, at least every `progress_timeout / 2` seconds:

```
[progress] step=<i>/<n> <label>
```

`<i>` non-decreasing across the run; `<n>` fixed for the run; `<label>` free text. Today
`tools/runner` only tests `'[progress]' in line` (`:982`), so a legacy bare `[progress]` line
still satisfies liveness — it just yields no ETA. Declaring `<n>` is what makes "will it finish
in time?" a computation rather than an opinion.

**Q-NIGHT-5 (mechanical liveness classification).** Every poll, every held child is placed in
exactly one class, from three observables (heartbeat age, `step` index, `step` total):

| class | test | meaning |
|---|---|---|
| `ADVANCING` | heartbeat age ≤ `progress_timeout` **and** `step` strictly increased since the previous classification | productive |
| `BEATING-STALLED` | heartbeat age ≤ `progress_timeout` **and** `step` unchanged for ≥ `STALL_S` (default `progress_timeout`) | zombie-suspect — alive, reporting, not advancing |
| `SILENT` | heartbeat age > `progress_timeout` | zombie — killed by the watchdog, and recorded as such |
| `DEAD` | `waitpid` returned | terminal; the run record is finalized |

Orthogonally, an **ETA verdict** per child: `WILL-FINISH` if
`elapsed × (n − i) / i ≤ wall_remaining`; `WILL-OVERRUN` if not; `ETA-UNKNOWN` if `n` was never
declared or `i = 0`. `ETA-UNKNOWN` is a **reported state**, never a blank — absence of an
assertion is UNKNOWN, not "fine" (`feedback-status-is-an-assertion`).

**Q-NIGHT-6 (no silent process — the three-way equality).** At every poll:

```
|held_children| == |classified_children| == |rows the queue observes as in_progress and owns|
```

Any inequality is a **loud defect**, reported with the offending ids on both sides. This single
equality is the whole "no silent process" requirement, and it is checkable by hand from disk:
`managent supervise status --json` vs `managent status --json` vs `ps` for the held pids. A child
with no class, or a class with no child, or an `in_progress` row the supervisor does not hold, is
the bug — and each of the three is a distinct known failure (an unclassified child is the
zombie; a classless row is the orphan; an unowned `in_progress` row is the T364 reap case).

**Q-NIGHT-7 (mandatory progress report).** Every `REPORT_EVERY` (default 1800 s) the queue
appends one report record — per-child `(id, model, class, eta_verdict, step, elapsed, rss)`,
plus `c_eff`, `anchor`, `drops`, the eligible count, and the **reason the queue is idle** when it
is. The report is a *file the operator reads in the morning*, and it is the discharge of
"mandatory progress reports". A report interval that elapses with no record written is itself a
defect (arm `NG5`).

**Q-NIGHT-8 (the stop budget — three ceilings, cheapest first).** Evaluated in this order, short
-circuiting on the first breach; each writes a stop report and then follows Q-NIGHT-9:
1. **wall** — `now − start ≥ RUN_WALL_S`. One monotonic clock read.
2. **closes** — `_sys.closes − closes_at_start ≥ RUN_CLOSES` (the duty-counter shape; `_sys.closes`
   already exists in the store, currently 90). One field of a read the loop already performs.
3. **gauge** — any dashboard gauge crosses its declared stop threshold. The most expensive: it
   recomputes the gauge set.

The order is the operator's ruling ("all three, cheapest-first") and the costs above are why
that order is the cheap one. Gauge thresholds are declared in the mode row, so "stop if X" is a
config line.

**Q-NIGHT-9 (stopping is graceful by default).** A stop-budget breach performs pass 2's
SUP-STOP-1: no new spawns, held children run to completion, exit 0 with the report. It does
**not** kill work in flight — killing an 80 %-complete table build to honour a wall ceiling
destroys more than it protects. A **second** breach of the same ceiling while draining escalates
to SUP-STOP-2 (hard stop), so a hung drain cannot hold the night open forever.

**Controls.** `NG1` seeded: a `build`-class row overnight ⇒ wall is `class × factor`, not 2700 s;
it is not killed at 2700 s. `NG2` seeded: stub emits `[progress] step=i/n` then stops emitting ⇒
`ADVANCING` → `BEATING-STALLED` → `SILENT` → killed, all four transitions in the record. `NG3`
seeded: stub with `n` declared and a slow rate ⇒ `WILL-OVERRUN` reported *before* the wall is
reached. `NG4` seeded: stub emitting legacy bare `[progress]` ⇒ liveness satisfied,
`ETA-UNKNOWN` reported (not blank). `NG5` seeded: fake-clock the report interval ⇒ a record
exists per interval; suppress the writer ⇒ red. `NG6` seeded: each of the three ceilings tripped
in isolation ⇒ graceful stop, report names which ceiling, and *only* that one was evaluated
(the cheaper ones' evaluation counters prove the short-circuit). `NG7` seeded: kill a held child
so the equality breaks ⇒ Q-NIGHT-6 reports the inequality with ids. `NG8` seeded: RSS breach on
a row that is `ADVANCING` ⇒ still killed (progress earns no memory exemption).

---

## 7. Mint safety — recursion, replication, self-DoS

The ruling: sprints **may** queue or defer tasks, but every queued task must be well-specified,
unique, justified, and provably not recursive / replicating / self-DoS. "Provably" is taken
literally: each property gets a mechanical check that runs **before** the row can become
eligible, and a row that cannot pass them is parked, not run.

**Q-MINT-1 (the fields).** A minted row carries: `minted_by` (the parent task id), `lineage`
(the ordered chain from the root mint to this row), `mint_depth` = `len(lineage) − 1`,
`mint_justification` (mandatory, non-empty, and must name at least one deliverable path),
`mint_key` (§Q-MINT-5), and — at depth ≥ 2 — `decreases` (§Q-MINT-7). An operator- or
orchestrator-registered row has `minted_by = null`, `mint_depth = 0`, and needs none of the rest.

**Q-MINT-2 (quarantine — the default is parked).** A minted row is registered with status
`pending-ratification`. It is **not** eligible, does **not** accrue `age` (Q-ORD-4), and can
never be an anchor (Q-CAP-3) — so a mint storm cannot cool the fleet. It leaves quarantine only
by Q-MINT-3.

**Q-MINT-3 (auto-admit boundary).** `mint_depth ≤ 1` **and** all of Q-MINT-4…8 green ⇒ the row
becomes `dispatchable` automatically. `mint_depth ≥ 2` ⇒ ratification is required: an operator or
the Orchestrator seat records `ratified_by`. Rationale: depth 1 is a sprint decomposing its own
work, which is the thing the operator explicitly permitted; depth ≥ 2 is where a chain becomes a
chain, and it is exactly where a human should look. This keeps friction proportional
(`project-process-doctrine`: least friction, no ceremony) while making the recursive case
reviewed by construction.

**Q-MINT-4 (depth and fan-out caps).**
- `mint_depth ≤ MINT_DEPTH_MAX` (default **3**) — a hard refusal above it, at registration.
- A single parent mints ≤ `MINT_FANOUT_MAX` (default **5**) rows over its lifetime.
- A whole lineage tree (all descendants of one root mint) holds ≤ `MINT_TREE_MAX` (default
  **20**) rows.
- ≤ `MINT_RATE_MAX` (default **10**) rows minted per stop-budget epoch (§6), across all lineages.
- These four are **independent** of the process delegation cap (`WEIZIGO_AGENT_DEPTH`,
  `MAX_DEPTH = 3`, `bin/dispatch:68-69`). That cap bounds *live process nesting*; these bound
  *queued work*. A task can mint a row it never runs, so one cap cannot serve both. Named
  separately so nobody "reuses" one and leaves the other open.

**Q-MINT-5 (uniqueness — the anti-replication check).** `mint_key = sha256(normalize(title) ‖
sorted(deliverables) ‖ normalize(acceptance))`. A mint whose key matches **any** row in the store
— open **or** closed — is refused, naming the collision. Checked against the row's own ancestors
first (an O(depth) walk: a key equal to an ancestor's is a self-replicator, the sharpest case),
then against the whole store. The only override is `--supersedes <id>`, which names the prior row
explicitly and records the supersession — the honest way to redo work.

**Q-MINT-6 (disjoint deliverables).** A minted row's `deliverables` must be disjoint from the
union of its ancestors' `deliverables`, unless `--supersedes` names the ancestor. A task that
mints a task producing the same artifact is a replicator even when its title differs, and this
catches the case Q-MINT-5's title hash misses.

**Q-MINT-7 (well-founded measure — the non-recursion proof).** At `mint_depth ≥ 2` the row must
declare `decreases = <measure>:<n>` where `<measure>` names a finite set and `<n>` is its
cardinality for this row, and `n_child < n_parent` for the same measure. A chain of mints whose
measure strictly decreases on a well-founded order **terminates** — that is the proof, and it is
one integer comparison. A depth-≥2 mint with no measure, or with `n_child ≥ n_parent`, or with a
measure name its parent does not share, is refused. Depth ≤ 1 needs no measure (Q-MINT-3's
proportionality).

**Q-MINT-8 (runnability at mint time — the self-DoS check).** A minted row must be *capable of
running*: its resolved family's appetite must permit it **now** (§4), its `wall_class` must exist
in the table, and its `needs` must form a DAG with the existing rows — a mint that introduces a
cycle, or that names an ancestor in `needs`, is refused. A row that can only run on an `OFF`
family is refused with that reason, because an eternally-unrunnable row is the aging mechanism's
worst input (Q-CAP-3's rationale).

**Q-MINT-9 (well-specified).** A minted row must satisfy the same registration gates a hand-
registered row does — exactly one bundle, a `# T<nnn> — <title>` line under 40 chars
(`bin/dispatch:224-253`, T505), an `acceptance` command or an explicit skip reason (Q-COND-5) —
so "well-specified" is the existing bar, not a second standard.

**Q-MINT-10 (visibility).** `pending_ratification` is a dashboard gauge with the same
re-derivable-by-hand bar as every other gauge. A quarantined row is *visible*, never silent; a
mint refused by Q-MINT-4…9 writes a refusal record naming the rule and the values. A mint that
disappears with no record is the defect.

**Controls.** `M1` seeded: a depth-4 mint ⇒ refused, rule named. `M2` seeded: a parent minting 6
rows ⇒ the 6th refused. `M3` seeded: a 21st row in one lineage ⇒ refused. `M4` seeded: 11 mints
in one epoch ⇒ the 11th refused. `M5` seeded: a mint whose `(title, deliverables, acceptance)`
matches an ancestor ⇒ refused as self-replicating; matches a *closed* row ⇒ refused; with
`--supersedes` ⇒ admitted and the supersession recorded. `M6` seeded: overlapping deliverables
with a grandparent ⇒ refused. `M7` seeded: depth-2 mint with no `decreases` ⇒ refused; with
`n_child = n_parent` ⇒ refused; with `n_child < n_parent` ⇒ admitted. `M8` seeded: a mint pinned
to an `OFF` family ⇒ refused; and separately, an already-registered OFF-pinned row at the top of
the order ⇒ `c_eff` unchanged (the self-DoS path, shared with `A5`). `M9` seeded: a mint whose
`needs` closes a cycle ⇒ refused. `M10` seeded: a depth-2 mint passing every check ⇒ status
`pending-ratification`, not dispatchable, counted in the gauge; after `ratified_by` ⇒
dispatchable. `M11` (mutation) disable the quarantine default ⇒ `M10` goes red.

---

## 8. The iteration, in order

One scheduling iteration, stated as an ordered sequence so the interaction of §2–§7 is
unambiguous. Steps 0–2 and 8–10 are recovered (`tools/fleet-keeper.sh:543-783`); the marked
steps are this spec's additions.

```
 0. stop budget            wall → closes → gauge, short-circuit (Q-NIGHT-8)          [new]
 1. cooldown precedence    set ⇒ advance `running` snapshot, dispatch nothing (Q-COND-12)
 2. read + reconcile       store read; adjudicate own firings (R11); heal observation (R8)
 3. classify held children ADVANCING / BEATING-STALLED / SILENT / DEAD + ETA (Q-NIGHT-5) [new]
 4. three-way equality     |held| == |classified| == |owned in_progress| (Q-NIGHT-6)      [new]
 5. conditions             eligible = rows satisfying Q-COND-1..11 (report each failure)
 6. order                  sort by (waiting, effective, age, added, id)  (Q-ORD-3)     [new key]
 7. pressure bookkeeping   anchor with stickiness; drops += |completed|; c_eff (Q-CAP-1..3) [sticky new]
 8. cap                    |running| >= c_eff ⇒ dispatch nothing, report
 9. candidate filter       two holds tests + family sub-cap + window guard (Q-COND-1, Q-APP-4)
10. fire one               hand the first surviving candidate to `managent supervise <id> <model>`
11. accrue                 age += 1 for every eligible row not fired (Q-ORD-4)         [new]
12. report                 per-interval progress report if due (Q-NIGHT-7)             [new]
```

**Q-ITER-1.** Exactly **one** row is fired per iteration (recovered behaviour, `:781-782`). The
fleet fills over successive iterations rather than in a burst; this is what makes the cap, the
pressure state, and the in-flight child set consistent at every decision point.

**Q-ITER-2.** Steps 5 and 6 are separate and in this order. A condition is never consulted
inside the sort, and a priority is never consulted inside a condition. This is the mechanical
form of "conditions are non-negotiable" and is checkable by inspection of the two regions.

**Q-ITER-3.** `--once` runs exactly one iteration and exits (recovered test hook, `:91-92`,
`:789-793`; pass 2 keeps it as `managent supervise --once`). Every control arm in §9 is written
against `--once` on a scratch store, so no arm needs a timer.

---

## 9. Controls

**Discipline.** Scratch store (`MANAGENT_STORE`) + scratch repo root + stub workers via the
`--test-worker=<cmd>` hook (T427/T476, carried by pass 2). No arm dispatches a real model. No arm
sleeps: the clock-dependent arms seed a stale timestamp, exactly as the recovered
`regression-fleet-keeper.sh` arm `g` seeds a 61-minute-old `waiting_since`
(`tools/regression-fleet-keeper.sh:890-929` is the pattern to copy for the ordering arms).
Red-first: every seeded arm is seen failing before the code exists.

**Q-CTL-1 (a null control and a seeded control per statement).** Table below. A statement whose
seeded arm cannot be made to fail is not a statement about this system.

**Q-CTL-2 (instrument-mutation controls).** Six mutations, each of which must turn a named arm
red — this is what proves the arms are measuring what they claim (`feedback-never-trust-a-green-test`):

| mutation | must go red |
|---|---|
| remove the `age` term from `effective` | `O2`, `O3` |
| remove anchor stickiness (re-key the anchor to the order's top) | `P4` |
| revert `needs` to the status-only rule | `N2` |
| delete the data-table sentinel comments | `DP3` |
| disable the mint quarantine default | `M10` |
| disable the three-way equality check | `NG7` |

**Q-CTL-3 (the carried pressure arms).** `docs/infra/fleet-keeper-design.md` §13 arms **a–h**
are carried verbatim and must stay green under the new ordering — they are the regression net
for R5–R7. Arm `a` (drop-then-solo, cap 5→1 then solo) and arm `h` (the `waiting=1` bump) are
the two that the aging change is most likely to break, so they run first.

### Arm index

| arm | kind | statement | seed | asserts |
|---|---|---|---|---|
| `O1` | null | Q-ORD-1 | fresh row, no `priority` | `priority = 50`, `age = 0` |
| `O2` | seeded | Q-ORD-2/4 | two rows base 50, one present for 3 fires | the older sorts first; `age` is 3 vs 0 |
| `O3` | seeded | Q-ORD-6 | one row base 50, one base 99, 49 fires between | the base-50 row overtakes at exactly fire 49, not 48, not 50 |
| `O4` | seeded | Q-ORD-5 | a row at `age = AGE_CAP` after further fires | `age` clamps; `effective` stays 99 |
| `O5` | seeded | Q-ORD-4 | a row ineligible (missing bundle) during 5 fires | its `age` is unchanged |
| `O6` | null | Q-ORD-3 | two rows identical on keys 1–4 | order is stable and total (id asc), across two runs |
| `P4` | seeded | Q-ORD-7 | anchor blocked; a second row's `effective` overtakes it | anchor and `drops` persist; `c_eff` keeps falling |
| `H1`–`H4` | null+seeded | Q-COND-1 | §3.1 | as §3.1 |
| `N1`–`N4` | null+seeded+mutation | Q-COND-2 | §3.1 | as §3.1 |
| `A1`–`A8` | seeded+null | §4 | §4 | as §4 |
| `Q1`–`Q3` | null+seeded | Q-COND-4 | §3.1 | as §3.1 |
| `D1`–`D3` | null+seeded | Q-COND-5 | §3.1 | as §3.1 |
| `C1`–`C7` | seeded | Q-COND-6..12 | §3.2 | as §3.2 |
| `DP1`–`DP4` | null+seeded+mutation | §5 | §5 | as §5; `DP2` (fictional family, zero source edits) is the load-bearing one |
| `NG1`–`NG8` | seeded | §6 | §6 | as §6 |
| `M1`–`M11` | seeded+mutation | §7 | §7 | as §7 |
| `a`–`h` | carried | R5–R7 | design §13 | unchanged, must stay green |

**Q-CTL-4 (the hand-trace acceptance).** Beyond the arms: one hand-traced night. A real overnight
run, then by hand from disk — recompute the order for three arbitrary iterations from the stored
`(waiting, priority, age, added, id)`, recompute `c_eff` from `(C_window, drops)`, and reconcile
the report's per-child classes against the run records. If any of the three cannot be reproduced
by hand, the layer is not accepted. This is L1's own bar ("a gauge that cannot be re-derived is
decoration") applied to the scheduler's decisions rather than to its displays.

---

## 10. Changes from the recovered implementation — each needs a ruling

Pass 2 §8.2 carries the keeper's policy "behaviour-preserving". These seven are **not**
behaviour-preserving and are listed for explicit decision rather than adopted silently.

| # | change | statement | why | risk if adopted | risk if rejected |
|---|---|---|---|---|---|
| 1 | numeric aging added to the order | Q-ORD-2/4 | the operator's 2026-08-21 ruling; no aging exists today (§1.2) | a pinned `priority=99` loses to a starved default after 49 fires | starvation stays bounded only by the cap-drop, which needs a *conflict* to engage — a row starved by mere ordering never escalates |
| 2 | anchor stickiness | Q-ORD-7 | without it aging makes the pressure machine vacuous (§2.2) | a newly-urgent blocked row waits for the current anchor's epoch | pressure never builds under aging; both rows starve |
| 3 | `priority`/`age`/`waiting` move into the store row | Q-ORD-8 | `age` is queue-written; 36 file reads + 18 subprocesses per tick today | a store schema change (T485/486/487 hold `main.zig`) | the queue writes worker briefs, and the cost stays |
| 4 | needs require a **passing** verdict | Q-COND-2b | a dependency that closed `blocked` satisfies a need today, in both implementations; T535/T541 is a live instance | 1 open row re-blocks immediately; more as `blocked` closes accumulate | work proceeds on foundations that were never laid |
| 5 | fleet-quiet as an **admission** condition | Q-COND-4 | no host check exists in the queue today; the floor is a post-hoc killer only | a quiet host that reads low parks the fleet | the 2026-07-29 panic shape stays reachable from the queue |
| 6 | discharge (acceptance) required before dispatch | Q-COND-5 | "done is the only success" needs a gate authored before the work | **all 12** queue-eligible rows park until backfilled | a worker invents its own gate at close time |
| 7 | progress-line `step=i/n` contract | Q-NIGHT-4 | "will-finish-in-time" is otherwise an opinion | worker briefs must ask for the fraction | ETA stays unmeasurable; `ETA-UNKNOWN` everywhere |

**Recommendation on each:** adopt 1, 2, 3, 5, 7 as specified. Adopt 4 with the ruling that it
changes **both** implementations in the same commit (`fleet-keeper`'s successor and
`main.zig:1550`), because a split rule means the queue and the engine disagree about which rows
are `dispatchable`. Adopt 6 **only with** a named backfill row closed before
the queue goes live — enforcing it retroactively without the backfill parks all 12 eligible rows
on night one, which is the same class of defect it is meant to prevent.

---

## 11. State and schema

**Store row, added fields:** `priority` (int, default 50) · `age` (int, default 0) · `waiting`
(bool, default false) · `task_type` (one of the 8 measured types) · `wall_class` · `probe` (bool)
· `minted_by` · `lineage` (array) · `mint_justification` · `mint_key` · `decreases` ·
`ratified_by`. New status value: `pending-ratification`.

**Store `_sys`, added fields:** `pops` (monotone count of fires — telemetry and the audit trail
for `age`) · `minted` (count, for `MINT_RATE_MAX`) · `epoch_started_at`.

**Data table (one location, pass 2 DP-2's region, sentinel-delimited):** per **model** —
`label`, `family`, `serving_tag`, `aliases[]`. Per **family** — `provider`, `argv_template`,
`require_env[]`, `preflight`, `tool_allowlist`, `stdout_envelope ∈ {raw, json_result}`,
`release`, `rss_cap_mb`, `host_headroom_mb`, `appetite`, `concurrent_max`, `reserved_for[]`,
`probe_only`, `min_window_s`, `window_resets_at`, `as_of`.

**Mode table:** `C_base`, `C_night`, `NIGHT_WALL_FACTOR`, `progress_timeout`, `STALL_S`,
`REPORT_EVERY`, `RUN_WALL_S`, `RUN_CLOSES`, gauge stop thresholds, `AGE_CAP`, `MINT_*` caps,
`HOST_FLOOR_MB`, `QUIET_LOAD`.

**Retained runtime state** (recovered): pressure record (`anchor`, `drops`, `waiting_since`,
`running`), heal state, attempt/backoff state, lane-down census, logjam flag. Pass 2 §2.4 moves
the cooldown flag into the store; the rest may stay as the supervisor's own files since HOLD-6
makes it the only writer.

**Q-SCHEMA-1.** Every added field is a **stored fact** (an authored number, an observed count, a
declared class), never a derived one. `effective`, the liveness class, the ETA verdict, and
`c_eff` are all computed at read time and appear in no record except a report. This is S02
methodology §3's rule, and it is what keeps §9's hand-trace possible.

---

## 12. Non-goals

The queue layer does **not**: build the dashboard (gauges are named here as consumers, specified
in the L1 dashboard pass); build the supervisor (S01 pass 2); preempt, pause, or kill a holder to
free an anchor (§1.3, the standing foreclosure); dispatch duty or `STANDING-*`/`ORCHA-*` rows
(Q-COND-7); decide *which model is best for a task type* (that is S02's matrix — this layer reads
it); implement a scheduled overnight window (Q-NIGHT-1); introduce a second supervisory process;
change the acceptance-command semantics of `managent done`; or relitigate the pass-1/pass-2
foreclosures.

---

## 13. Open questions — rulings needed

1. **The seven changes in §10**, each individually. §10 carries a recommendation for each.
2. **`AGE_CAP = 49`.** It makes a default row exactly reach the pinned ceiling. Should a pinned
   `priority = 99` be *unovertakeable* instead (`AGE_CAP = 48`)? That would give the operator a
   genuinely absolute pin at the cost of reintroducing unbounded starvation for a default row
   whenever a 99 is queued. Recommendation: keep 49 (reachable ties, resolved by `age`), and note
   that `waiting = 1` already provides an absolute override that no amount of aging can pass.
3. **`C_night = 2`.** A number, not a principle. Wants one night of measurement.
4. **`MINT_DEPTH_MAX = 3` and the auto-admit boundary at depth 1.** The boundary is the
   friction/safety trade; the operator may want auto-admit at depth 0 only (every sprint-minted
   row ratified) or at depth 2.
5. **Where the data table physically lives.** Pass 2 DP-2 says the `canonical_models[]` region of
   `src/managent/main.zig` (a Zig literal, compiled). An external JSON would be editable without
   a rebuild but adds a parse-and-validate path and a file that can go missing. Recommendation:
   in-source (pass 2's choice), because a dispatch table that can be absent at runtime is a new
   failure mode on the critical path.
6. **`step=i/n` adoption path.** Do worker briefs get a standing instruction (DELEGATEE.md), or
   does the orient preamble emit it? The latter needs no brief edits and reaches every worker.
7. **Whether the queue may write `age` while a sprint console holds `main.zig`.** T485/486/487
   and T522/T544 currently hold that file; the schema change in §10 item 3 collides. Sequencing
   question, not a design question.

---

## 14. Provenance and rejected alternatives

| aspect | source |
|---|---|
| priority 0–99, default 50, tie-break by `added`; the model allow/deny window | directive **D022** (2026-08-19T23:07:31Z), `docs/infra/managent/directives.jsonl` |
| the cap-drop pressure arithmetic, verbatim | directive **D023** (2026-08-19T23:17:11Z); `docs/infra/fleet-keeper-design.md` §2, §6, §7 |
| the one-writer invariant; the rejection of dispatch-anyway; completion-driven over clock-driven; the floor at 1 and its proof; the logjam flag as telemetry-only | `docs/infra/fleet-keeper-design.md` §1, §3, §7, §9, §10 |
| `waiting=1` as the bump; the three-key sort; eligibility filters; heal cooldown; pre-claim backoff and the lane circuit breaker; the cooldown dead-man's switch | `tools/fleet-keeper.sh` (lines cited per row in §1.1) |
| the held-child set as a condition; one dispatch interface; the family-token grep gate; cooldown as a verb; shutdown semantics | `S01-process-ownership/pass2/spec.md` §2.1, §2.4, §2.5, §3 |
| the appetite levels, the family table, the reservations, the task-type shares | `S02-model-delegation/measurement-methodology.md` §1 |
| "store facts, derive numbers at report time" | `S02-model-delegation/measurement-methodology.md` §3 |
| "wall and CPU ceilings are bad stuck-detectors"; the progress watchdog; the RSS cap as absolute; the injectable host reading | `tools/runner:70-81`, `:853-910` |
| aging-priority, the appetite spectrum, conservative overnight, mandatory heartbeats, cheapest-first stop budget, mint safety | operator rulings 2026-08-21, `docs/status/orchestration-layer-spec.md` §7 |

Rejected alternatives, one line each:

| rejected | reason |
|---|---|
| literal "+1 to every queued row on each pop" | destroys the operator's authored `priority` after one night and makes the order irreproducible from the store; Q-ORD-6 shows the derived form gives the same order |
| aging by wall-clock elapsed instead of by pass-overs | design §9's argument: a clock in a dispatch decision costs clock injection in every arm; pass-overs are discrete, deterministic, and hand-checkable |
| deriving `age` from a global pop counter (`pops − pop_epoch`) | cheaper to store but wrong: it accrues while a row is parked by backoff, heal cooldown, or appetite, so a repeatedly-failing row would climb to the top — the opposite of what backoff is for |
| appetite as a priority penalty | makes the order depend on model assignment, so re-pointing one row silently reorders unrelated work (Q-APP-1) |
| appetite as a single boolean gate | cannot express CONSERVE at all; the operator's ruling is explicitly a spectrum |
| keeping `priority`/`waiting` in the bundle header | the queue would have to write worker briefs to age a row, and the per-tick read cost (36 files + 18 subprocesses) is already on pass 2's open-question list |
| keying the anchor to the top of the order (recovered behaviour, unchanged) | correct under static priority, vacuous under aging (§2.2) |
| a wall ceiling as the overnight stuck-detector | `tools/runner:70-81` — it kills correct long-running jobs, which is exactly the "table/engine must not time out prematurely" failure |
| relaxing the RSS cap for an `ADVANCING` child | `tools/runner:76-77` — no progress earns an exemption from a memory-exhaustion kill; the 2026-07-29 kernel panic is the precedent |
| allowing a mint to become dispatchable immediately at any depth | removes the only place a human can see a chain forming; quarantine costs one status value |
| a family branch for the claude JSON envelope | expressible as a capability-named enum (`stdout_envelope = json_result`), so Q-DP-5's proof obligation is not met |
| a dispatch-anyway escape after N minutes | rejected by the operator 2026-08-20; violates the one-writer rule (§1.3) |
