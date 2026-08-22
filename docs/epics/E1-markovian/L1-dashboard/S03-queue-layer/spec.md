# S03 — spec: the queue layer (aging, conditions, appetite, overnight, mint safety)

**Artifact type: SPEC** (`docs/infra/sprint.md` — a spec says what we want, testably, for one
pass). **Owner:** `claude-opus-5`/S03-design · **Date:** 2026-08-21, **rev 2** 2026-08-22 (T576) ·
**Status:** PROPOSED — audited before anything is built. Not a worker brief, not a plan, no code.

## Changelog — rev 1 → rev 2 (T576, author-fix against `findings/T575-s03-queue-layer-audit.json`)

Rev 2 closes T575's N1–N14 and folds one operator requirement. Nothing in §1's recovery (R1–R13)
changed — the audit verified it faithful to the code.

| finding | severity | what changed | where |
|---|---|---|---|
| N1 | **must** | The two one-writer holds tests were listed inside the §3 condition conjunction, which removed conflict-blocked rows from `eligible` and thereby made the anchor unreachable, `drops` unaccruable, and the whole recovered cap-drop pressure machine **inert**. They are now the §8 step-9 candidate filter, where the recovered code puts them (`tools/fleet-keeper.sh:770-781`); only `Q-COND-1(c)` (held children) stays a condition. New `Q-COND-0a` states why, and mutation arm `H5` keeps the placement honest | §3 `Q-COND-0`, `Q-COND-0a`, `Q-COND-1`; §2.2 `Q-CAP-3`; §8 steps 5/9; `Q-ITER-2` |
| N2 | **must** | §4 specified the five static appetite **levels**, which pass 2 rev 2 §4 replaced with the operator-ratified 0–99 **dial** — two Must-level documents that could not both ship. §4 is rewritten against the dial: the queue *reads* `appetite_effective`, never writes it; `0` is the hard forbid; `lanes`/`spacing` are pass 2's arithmetic with the queue-layer consequences stated (a skipped row stays eligible and accrues; spacing never stalls the iteration); `RESERVED` and `PROBE` are separated out as hard predicates, per pass 2 §4.5's own finding | §4 in full (`Q-APP-1..11`, arms `A1`–`A11`); `Q-COND-3`, `Q-COND-4c`, `Q-CAP-3`, `Q-MINT-8`, §11, §14 |
| — | operator | **Terminal-aware dashboard requirement** (2026-08-22): the `bin/managent` view must be height/width-aware, four-section (`PROGRESS`/`CONCERNS`/`DONE`/`OPEN`), human-legible, and every row re-derivable from disk by a named command | new §12.1 (`Q-VIEW-1..6`) |
| N3 | should | `Q-ORD-7`'s rationale named a churn mechanism that cannot occur (lockstep rows tie forever and never swap). The two real drivers — differential accrual, and a higher-priority/bumped entrant — are named, and arms `P4`/`P5` are re-keyed to them | §2.1 `Q-ORD-7`; §9 |
| N4 | should | `Q-ORD-6`'s crossover was asserted unconditionally; on the spec's own keys an earlier-added pinned 99 ties at saturation and FIFO holds it. The precondition (differential accrual) is now stated, arm `O3` seeds it, new arm `O3b` covers the lockstep case, and OQ 2 is restated | §2.1 `Q-ORD-6`; §9; §13 OQ 2 |
| N5 | should | Every legacy step-less worker was classified `BEATING-STALLED` forever. New class `UNDECLARED-STEP`, one-way transition to `ADVANCING`, arm `NG4` re-keyed with a mutation | §6 `Q-NIGHT-5`; §9 |
| N6 | should | §7 and pass 2 §5 were two independent re-specs of one ruling. A division-of-labour table now assigns write-time enforcement and the delta breaker to pass 2 and quarantine/ratification/ordering to §7; duplicate fields withdrawn in pass 2's favour (`minted_by` as an identity record, `justification`, `D_max`); pass 2 rev 3 has since defined `justification-key` itself, so `mint_key` stands as a **second, complementary** key with the cases each one catches and misses tabulated; new `Q-MINT-11` states the queue's duties under the breaker | §7 preamble, `Q-MINT-1/4/5/10/11`; arms `M12`, `M13` |
| N7 | should | `Q-DP-4` used the *exclusive* grep form pass 2 F5 rejected; it now uses the inclusive sentinel `awk` form with a loud empty-selection failure. `stdout_envelope ∈ {raw, json_result}` renamed to pass 2's `output_format ∈ {text, json-envelope}` | §5.1 V6, §5.2 `Q-DP-2/3/4`, §11 |
| N8 | should | `reserved_for` matched against `task_type`, whose domain (the 8 measured types) can never contain `deep-holistic-review` — the predicate was unsatisfiable and Fable was undispatchable, not reserved. Three vocabularies pinned (`task_type`, `task_shape`, `scope`), with the mapping written out; `scope` is new and is OQ 8 | §4 `Q-APP-9`; §11; §13 OQ 8 |
| N9 | could | The per-tick cost figure appeared as both 24/12 and 36/18; the derivable one (24 reads + 12 spawns at 12 eligible rows) is now used everywhere | §10 change 3, §14 |
| N10 | could | `src/managent/main.zig` citations had no pin and were ~40 lines stale at HEAD. A citation-pin table is added and every `main.zig` number re-derived at `5b55e0e` | header; §2.1 `Q-ORD-8`, §3.1, §5.2 |
| N11 | could | The clock-free-arm pattern cited arm `h`'s line range, not arm `g`'s | §9 |
| N12 | could | Two pass-2 section refs were rev-1 numbers: "§8.2" → §10.1 item 2, and V7's "pass 2 §4" → §6 | §0; §5.1 V7 |
| N13 | could | `D036` is duplicated in `directives.jsonl`; the citation is now timestamped | §1.1 R9 |
| N14 | note | `Q-COND-5`'s sizing is a dated snapshot that has already moved; it now carries a **RE-MEASURE AT BUILD** marker with the `5b55e0e` numbers | §3.1 `Q-COND-5` |

Two items the audit raised that are **not** fixed here, because the file is not this row's to
write (one writer): pass 2's changelog claims S03 cites only its §2.1/§2.5/§3, which is incomplete
(N12's other half), and `directives.jsonl`'s duplicate ids `D021`–`D054` are a store data defect
(N13's other half). Both are recorded in `findings/T576-s03-must-fix.json`.

---

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

**Citation pins (rev 2, T576 — pass 2 F11's discipline, applied to every file, not one).** Every
`file:line` in this document is pinned to a commit, and a citation that no longer resolves at its
pin is a spec defect to be re-derived, not silently trusted:

| file | pin | note |
|---|---|---|
| `tools/fleet-keeper.sh` | `1b8e627` | unchanged `1b8e627..5b55e0e`; every citation resolves at both |
| `tools/regression-fleet-keeper.sh` | `1b8e627` | unchanged; arm letters as cited in §9 |
| `docs/infra/fleet-keeper-design.md` | `1b8e627` | unchanged |
| `bin/dispatch`, `bin/subagent`, `tools/runner` | `5b55e0e` | unchanged since `56b9cf1` in the cited regions |
| `src/managent/main.zig` | `5b55e0e` | **re-derived at rev 2.** Rev 1's numbers were authored against `56b9cf1` and T569's `d9d0331` shifted the file by ~40 lines; every `main.zig` citation below is the `5b55e0e` number |
| `S01-process-ownership/pass2/spec.md` | **rev 3**, `4f47990` (T577, 2026-08-22) | cited by §ref only, never by line. Rev 3 folded its own re-audit N1–N8 while this revision was in flight; §§2.1, 2.4, 2.5, 3, 3.1, 4.1–4.5, 5, 6, 10.1, 10.2 all keep their numbers, and the two seams rev 3 moved (N2's appetite-family column, N3's `justification-key` definition) are reconciled at Q-APP-11 and Q-MINT-5 |
| `docs/infra/managent/directives.jsonl` | cited **by timestamp**, not by id | the file has duplicate ids (every id `D021`–`D054` appears twice); the timestamp is the key |

---

## 0. How to read this document

Every normative statement carries an id (`Q-ORD-3`, `Q-COND-2c`, `Q-MINT-4`). §9 is the control
table: **every id has at least one seeded arm that flips it and one null arm that must stay
green.** An id with no control is not a requirement, it is a wish (`feedback-never-trust-a-green-test`:
an instrument earns its first reading only after a null control and a seeded-defect control).

Statements that **change** behaviour recovered from `tools/fleet-keeper.sh` are marked
**[CHANGE]** and are listed together in §10 for ruling. Pass 2 §10.1 item 2 says the fleet-fill
policy is carried "behaviour-preserving" (rev 1 of this document cited "pass 2 §8.2", a rev-1
number that rev 2's insertion of §4/§5 shifted — the statement's homes are §10.1 item 2 and the
§2.1 opening "carried from `tools/fleet-keeper.sh` with no behaviour invention"); seven things in
here are not behaviour-preserving, and they are named in §10 rather than smuggled.

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
| R9 | **model window** | `:118-123`, `:260-272` | `FLEET_MODEL_ALLOW` / `FLEET_MODEL_DENY` comma lists of canonical labels; DENY wins; **durable default DENY = `glm-5.2,minimax-m3,kimi-k2.7`** (D036, 2026-08-20T12:18:47Z — the store holds a second, unrelated `D036` at 2026-08-04T23:46:36Z, so the timestamp is the citation) unless the env var is explicitly set, even to empty. |
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
- *Crossover with a pinned row — and its precondition.* A default row (50) reaches `effective =
  99` after 49 fires it loses, so it **ties** a pinned 99 rather than passing it; key 3 (`age`
  desc) then decides, and it decides for the starved row **only if the starved row accrued
  strictly more than the pinned one**. Under lockstep accrual (both rows continuously eligible)
  the two ages are equal at every fire, key 3 ties too, and key 4 (`added` asc) gives it to the
  earlier entrant — so a later-entering default **never** overtakes an earlier-added pinned 99.
  The overtake is real but its precondition is **differential accrual**: the pinned row must
  have been out of the eligible set for at least one fire (model denied, backoff, heal cooldown,
  appetite, host-quiet) while the default row accrued. Under the operator's scheme (+1 to all,
  insert at min−1) the same crossover lands at the same count and under the same precondition,
  because a uniform +1 to every queued row leaves all differences invariant and only the
  *newcomer's* insert position matters. The two schemes agree up to the crossover. ∎ (Rev 1
  asserted the crossover unconditionally; that was wrong on the spec's own keys — T575 N4.)
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
priority the top is stable, so keying to it is safe. With aging the top churns, and every change
of top is a re-anchor that resets `drops = 0` (`:694-698`), so `c_eff` never falls and the
pressure machine becomes **vacuous** — the fleet stays at 5 forever while both rows starve. The
two churn drivers, named (rev 1 named a third that is mechanically impossible — two rows
accruing *in lockstep* have equal `age` forever, so key 3 ties and key 4 orders them permanently;
lockstep produces zero swaps, T575 N3):

- **(i) differential accrual.** A row that missed accrual during an ineligibility window
  (backoff, heal cooldown, appetite, host-quiet, model denied) re-joins the eligible set below a
  competitor that kept accruing, then climbs past it as the competitor saturates. Its `effective`
  crosses the anchor's from below while both are blocked.
- **(ii) a higher-priority entrant.** A row authored at a higher `priority` — or an operator
  `waiting = 1` bump — enters or re-enters the eligible set while the anchor is blocked, and
  takes the top on key 1 or key 2 immediately.

Both are re-anchors under R5's rule, both reset `drops`, and both are reachable on any night with
a backoff or an operator bump in it. This is a defect that aging *introduces*
into working code, which is exactly the class of thing a design pass exists to catch. Stickiness
costs nothing: the overtaking row is still a *candidate* and still runs the moment it is
conflict-free (§8 step 4 of the recovered design), so stickiness changes who *anchors*, never
who *runs*. Control: arm `P4`.

**Q-ORD-8 (where the fields live).** **[CHANGE]** `priority`, `age`, and `waiting` move from the
bundle header into the store row (`src/managent/main.zig`'s `TaskState` (`:106-145`), beside `claim_count`
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
i.e. a row that would run *now* but for another task's holds. **Holds-conflict is deliberately
absent from that exclusion list**: a conflict-blocked row is exactly the row that anchors, which
is why the two holds tests are a step-9 candidate filter and not conditions (Q-COND-0a).

*Why this clause exists.* It is the self-DoS hole that aging opens. An unrunnable row that keeps
accruing `age` climbs to the top of the order; if the top of the order could anchor, that one
permanently-unrunnable row would cool the entire fleet to `c_eff = 1` indefinitely — a
fleet-wide denial of service minted by a single bad row. The recovered code is partly protected
by accident (the model gate sits *inside* `eligible` at `:666`, and design §11 notes the
consequence), but a **0 dial** (or a failed reservation/probe predicate) plus aging is a new path
and the invariant must be stated, not inherited. Q-ORD-4 (no accrual while ineligible) is the second half of the same defence.
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

**Q-COND-0 (the shape — and where each test is evaluated).**

```
eligible  = { r ∈ rows : C1(c) ∧ C2 ∧ C3 ∧ … ∧ C11 }        (§3, step 5)
order     = sort(eligible) by (waiting, effective, age, added, id)   (§2, step 6)
anchor    = pressure bookkeeping over the ordered eligible set        (§2.2, step 7)
candidate = first row of the order surviving the step-9 filter:
              C1(a)  r.holds ∩ inprog_holds  = ∅
              C1(b)  anchor ≠ null ⇒ r.holds ∩ anchor.holds = ∅
              plus the appetite lane/spacing gates (§4)               (§8, step 9)
fire       one candidate                                             (§8, step 10)
```

A row failing any condition is **reported** with the condition that failed (§6's no-silent rule
extends to non-dispatch: an idle queue must say why), never silently skipped. A candidate skipped
at step 9 is reported with reason `holds-conflict` and **stays eligible** (so it accrues `age`,
Q-ORD-4, and can anchor, Q-CAP-3).

**Q-COND-0a (why the two holds tests are a step-9 filter and not conditions — the load-bearing
placement).** **A conflict-blocked row must remain in the eligible set.** Everything in §2.2
depends on it: the anchor *is* "the top eligible row that is conflict-blocked" (Q-CAP-1, R5), so
if a holds conflict excluded a row from `eligible`, then `eligible ∧ conflict-blocked = ∅`, no row
could ever anchor, `drops` would never accrue, `c_eff` would never fall, and the entire cap-drop
pressure machine — the one thing in §1.1 that *is* recovered, working, and the operator's own
arithmetic (D023) — would be **inert**. Q-ORD-7's "still eligible and still conflict-blocked",
Q-ORD-4's "including rows that were eligible but conflict-blocked", and Q-CAP-3's exclusion list
(which deliberately does **not** name holds-conflict) all read as vacuous under the other
placement. The recovered code puts both tests exactly here — `tools/fleet-keeper.sh:770-781`:
`candidates = []` at `:770`, `if e["holds"] & inprog_holds: continue` at `:772`, the anchor test
at `:774`, `pick = candidates[0]` at `:781` — *after* `elig` (`:628-668`) and *after* the sort
(`:677`) and the pressure bookkeeping (`:679-701`). Rev 1 of this document listed (a) and (b)
inside the §3 conjunction, which silently killed the pressure machine (T575 N1); this is the
correction. C1(c) is a genuine condition and stays one: a row the supervisor is already holding is
not "blocked by someone else", it is *already running*, and it must not accrue `age` or anchor.

### 3.1 The five named conditions

**Q-COND-1 — holds clear.** Three tests, all carried from R7 plus pass 2. **They are not all
evaluated at the same point** (Q-COND-0a), and the split is normative:

| test | rule | evaluated at | if it fails |
|---|---|---|---|
| (a) | `r.holds ∩ inprog_holds = ∅` — the one-writer invariant, always. `inprog_holds` is the union of `holds` over rows the queue observes as `in_progress` | **§8 step 9**, the candidate filter (`tools/fleet-keeper.sh:772`) | not a candidate *this iteration*; **still eligible** — accrues `age`, may anchor, reported `holds-conflict` |
| (b) | `anchor ≠ null ⇒ r.holds ∩ anchor.holds = ∅` — compatibility with the blocked anchor. Not subsumed by (a): the anchor may hold `{a,b}` with only `a` currently held (design §8 step 4) | **§8 step 9** (`:774`) | as (a), reported `anchor-conflict` |
| (c) | **[CHANGE, from pass 2 §2.1]** `r.id ∉ supervisor.held_children` — the in-memory child set, consulted *before* the store moves | **§3 step 5**, a true condition | **not eligible**: no `age` accrual, never an anchor |

(c) is the fix for the 80-fires-in-3.5-minutes red (pass 2 §2.1's named Red), and it is a
*condition* rather than a filter for a reason the other two do not share: a row the supervisor is
already holding is not blocked *by another task*, it is already running, so treating it as
eligible-but-blocked would let it anchor against itself and cool the fleet on its own work.
- Controls: `H1` null (disjoint holds ⇒ dispatch), `H2` seeded (intersecting holds ⇒ never
  dispatched, under both NORMAL and PRESSURED, **and the row is still counted eligible and still
  accrues `age`** — this is the arm that fails under the rev-1 placement), `H3` seeded (anchor
  holds `{a,b}`, running holds `{a}`, candidate holds `{b}` ⇒ refused — the non-subsumption
  case), `H4` seeded (slow-claiming stub ⇒ exactly one fire, and the row is **not** eligible
  while held — the (c) arm), `H5` (mutation) move (a)/(b) into the step-5 conjunction ⇒ arm `a`
  (drop-then-solo) and `P4` must go red, because no row can anchor.

**Q-COND-2 — needs satisfied.**
- (a) Every id in `r.needs` exists in the store and has `status == done`. Carried from R8 /
  `tools/fleet-keeper.sh:201-206`.
- (b) **[CHANGE]** …**and** its `verdict ∈ {pass, pass-with-findings}`. A dependency closed
  `blocked`, `abandoned`, or `fail-found` does **not** satisfy a need; the dependent stays
  `blocked` and is reported as *"needs T541, which closed blocked"*.
- (c) A missing dependency id is a **refusal that names the row**, not a silent block.

*Evidence this matters.* Today's rule is `status != done ⇒ unmet`, in **two** independent
implementations that agree — `tools/fleet-keeper.sh:201-206` and `src/managent/main.zig:1590-1597`
(`needsMet`). Because they agree, this is a deliberate rule, not a one-sided bug, so changing it
is a policy decision needing a ruling (§10) and it must change in **both** or the queue and the
engine will disagree about which rows are `dispatchable` — the engine derives that status at
`main.zig:1599-1604`. The live store has 9 done-but-not-passed rows (7 `blocked`, 2 `abandoned`)
and one real instance: **T535 needs T541, and T541 closed `blocked`** — today T541 counts as
satisfied. Controls: `N1` null (dep `pass` ⇒ satisfied), `N2` seeded (dep done+`blocked` ⇒ NOT
satisfied), `N3` seeded (dep absent ⇒ refusal naming the id), `N4` (mutation: revert to the
status-only rule ⇒ `N2` must go red).

**Q-COND-3 — appetite permits.** §4 in full — the 0-dial hard forbid (Q-APP-3), the reservation
predicate (Q-APP-8), and `probe_only` (Q-APP-10) are **conditions** and exclude a row from
`eligible`; the lane sub-cap (Q-APP-4) and spacing (Q-APP-5) are **step-9 filters** and leave the
row eligible and accruing (Q-COND-0a). The split matters: a row a *dial* forbids is not runnable
and must not anchor (Q-CAP-3), while a row merely waiting its family's turn is.

**Q-COND-4 — fleet quiet.** **[CHANGE — this condition does not exist today.]**
- (a) `host_avail_mb ≥ HOST_FLOOR_MB + headroom(family)` at admission time, where `headroom` is
  a data-table attribute per family (§5) — a local MLX model needs ~18 GB, a cloud API worker
  needs ~200 MB.
- (b) `loadavg1 ≤ QUIET_LOAD × ncpu` (default `QUIET_LOAD = 1.5`).
- (c) **Measured-suite interlock:** while a measurement run is declared in progress, families
  flagged `probe_only` (today `local`) are not admitted at all — S02 methodology §1 reservation,
  *"never during a measured suite run (load contamination — the D6/D12/D14 cull)"*; see Q-APP-10.
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
(measurement declared + a `probe` row on a `probe_only` family at the top of the order ⇒ not
admitted, and the next candidate on a non-`probe_only` family runs).

**Q-COND-5 — discharge known.** A row is not dispatchable unless *done is gate-able before the
work starts*: `r.acceptance ≠ null` **or** `r.skip_acceptance_reason ≠ null`. **[CHANGE]**
- Rationale: the sketch's own words — *"a row is done only when its acceptance command exits 0
  and its deliverables are committed and its verdict is recorded… a queue that reports success
  while doing nothing is the named recurring defect."* An acceptance command invented *at close
  time* by the worker that wants to close is not a gate, it is a self-grade.
- **Sizing — MEASURED 2026-08-21, RE-MEASURE AT BUILD.** The numbers below are a dated
  snapshot and they have already moved (at `5b55e0e`: 254 rows, 21 dispatchable, 15 `T\d+`
  non-duty, **14** without acceptance — T573 has since gained an acceptance command, T571/T572
  are new acceptance-less rows; `_sys.closes` is 94, not 90). The *direction* is what the
  argument rests on, and it is unchanged; the *count* is the input to §10 change 6's backfill
  precondition and must be re-derived from the store at build time, never read off this table.
  18 rows derive as `dispatchable`; **12**
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
| Q-COND-6 | derived status is `dispatchable` | `:629`; engine `main.zig:1599-1604` | `C1` seeded: `in_progress`/`done`/`blocked` rows never fire |
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

## 4. Appetite — the 0–99 dial (pass 2 §4), plus two hard predicates

**Authority.** Pass 2 §4 (introduced at rev 2, unchanged in force at **rev 3**, `4f47990`)
**replaced** the static levels `OFF < PROBE < CONSERVE < SPEND < RESERVED`
(`S02-model-delegation/measurement-methodology.md:23`) with a continuous integer dial per family,
as operator refinement (a); it is a **Must** and it is on pass 2's never-cut list (§10.2). The 2026-08-22 rulings (`docs/status/orchestration-layer-spec.md` §7b, closing line) put
the dial's *direction* beyond question and leave only its *constants* owed — *"Still owed operator
numbers (not direction; spec defaults hold meanwhile): appetite constants (pass-2 spec §4.5)"*.

**Rev 1 of this document specified the five levels** (it was authored against pass 2 rev 1) and
would have had the queue evaluate `Q-COND-3` against a mechanism the supervisor does not
implement — two Must-level documents that could not both ship (T575 N2). **This section is
rewritten against the dial.** It does **not** re-specify the dial: pass 2 §4.1–§4.4 own the dial's
definition, its arithmetic, its window observation, and its write hierarchy. §4 here owns only
what the *queue* does with it, plus the two predicates that were never on the appetite axis at all.

**Q-APP-1 (the axis rule — unchanged, and now agreed on both sides).** Appetite acts on **model
resolution and admission**. It **never** alters task ordering. A row's position in §2's order is a
function of the row alone (`waiting`, `priority`, `age`, `added`, `id`) and of nothing about which
model it resolved to. Pass 2 §4.2 states the same rule from the other end — *"The dial must not
perturb the eligibility ordering — ordering is S03's concern… The dial changes how many and how
often, never which"* — and forbids randomised admission for the same reason.

*Why.* A priority penalty for a throttled family would make the queue order depend on model
assignment, so re-pointing one row's model would silently reorder unrelated work, and the ordering
would no longer be re-derivable from the task table by hand — the L1 bar. Keeping the axes
separate means the two mechanisms are independently testable: an ordering arm never needs an
appetite fixture, and an appetite arm never needs to reason about `age`.

**Q-APP-2 (what the queue reads, never writes).** The queue reads
`appetite_effective(f) = min(appetite_operator(f), appetite_auto(f))` (pass 2 §4.4) and the
family's `lane_cap(f)` / `spacing_max(f)` constants. **The queue writes none of them.** The
operator sets `appetite_operator`; the supervisor computes `appetite_auto` from the observed
window record (pass 2 §4.3) and may only *reduce*; no worker may write either (pass 2 §4.4,
mechanized there). A queue that could raise a dial to clear its own backlog is the runaway vector
pass 2 §5 exists to stop, so the queue's relationship to the dial is read-only by construction.

**Q-APP-3 (hard forbid — the `0` floor).** `appetite_effective(f) = 0` ⇒ no row resolving to `f`
is admitted. Checked **first**, before any arithmetic, refusal reason `appetite-forbid` (pass 2
§4.1). A row *pinned* to a 0-dial family is **ineligible** and is reported as parked on
`appetite-forbid` — not silently dropped, and (Q-CAP-3) **never an anchor**. A row with **no**
pinned model resolves to a permitted family instead (R10's least-measured rule, restricted to
families with `appetite_effective ≥ 1`, as today at `:283`).
- Current effect: `ollama-cloud` (glm-5.2, minimax-m3, kimi-k2.7) is at **0** by D036
  (2026-08-20T12:18:47Z) — 0 tokens. Rejoin is a **human flip** of `appetite_operator`, never a
  calendar auto-trust (methodology §1; pass 2 §4.3's `ASSUMED_RESET` row says the same thing
  mechanically: *"the machine does not speed up on a prediction"*). Pass 2 §4.5's migration table
  gives `ollama-cloud` a default of **90** as "the speed-up side of the operator's ask"; that is
  the number the operator flips *to*, and it does not describe today. The queue's live value is
  whatever the store's dial record says, and the record's author and timestamp are the evidence.
  R9's `FLEET_MODEL_ALLOW` / `FLEET_MODEL_DENY` env pair survives only as an operator escape
  hatch for a forced window, and it can only *narrow*: it is intersected with the dial, never
  unioned. **The env vars can never lift a 0.**

**Q-APP-4 (lanes — the family sub-cap).** `lanes(f) = max(1, round(appetite_effective(f) ×
lane_cap(f) / 99))` for a nonzero dial, `0` at zero (pass 2 §4.2 verbatim; the queue does not
re-derive it). It is a **second cap below `c_eff`** — the lower of the two binds:

```
admissible_now(f) = min(c_eff − |running|, lanes(f) − |held children resolved to f|)
```

A candidate that would exceed `lanes(f)` is skipped **for this iteration only**, the next
candidate in the order is considered, and the skipped row **stays eligible** — so it keeps its
`age` accrual (Q-ORD-4) and can still anchor (Q-CAP-3). Refusal reason
`appetite-lanes-exhausted`. Evaluated at §8 step 9, alongside the two holds tests, for exactly
the Q-COND-0a reason.

**Q-APP-5 (spacing — the queue-layer consequence of a rate limit).**
`spacing(f) = round(spacing_max(f) × (99 − appetite_effective(f)) / 98)` seconds for a nonzero
dial (pass 2 §4.2): the minimum wall time between two consecutive dispatches to `f`. Refusal
reason `appetite-spacing`.

This is the one place the dial touches something the levels never had, and it needs a queue rule
the supervisor's spec does not state: **spacing is a per-family clock, not a per-row one, and it
never stalls the iteration.** If the top candidate's family is inside its spacing window, the
iteration continues down the order and fires the first candidate whose family is not — it does
**not** fire nothing and it does **not** wait. Otherwise one throttled family at
`appetite_effective = 1` would hold the whole fleet at its own `spacing_max`, converting
back-pressure on one family into a fleet-wide stall — the "silently off" failure pass 2 §4.2's
`max(1, …)` exists to prevent, reintroduced one layer up. A row skipped on spacing stays
eligible and accrues.

*This is a clock in a dispatch decision*, which §1.2/design §9 argue against, and it is admitted
here **narrowly and on purpose**: it is a *rate limit on a family*, never an input to ordering or
to eligibility, so it cannot decide *which* row runs — only whether this family's turn has come
round. The arms inject it the same way every other clock-dependent arm does (§9: seed a stale
`last_dispatch_at` per family; no arm sleeps).

**Q-APP-6 (lane substitution — the queue's own resolution rule).** If the row's model is
**unpinned** and more than one family is qualified for the row's declared shape (Q-APP-8), resolve
to the **qualified family with the highest `appetite_effective`**, ties broken by R10's
least-measured rule. This is methodology §1's *"only where no cheaper qualified lane exists"*
turned into arithmetic that is monotone in the dial rather than a prose reminder: as `claude`'s
dial falls, unpinned qualified work migrates to `deepseek` without anyone editing a policy doc,
which is the operator's stated intent (*"slow down with Claude and speed up with Ollama as
token/credit windows approach and reset"*, pass 2 §4). A **pinned** row is never re-pointed —
re-pointing an operator's explicit choice would be the mechanism overruling the human.

**Q-APP-7 (the window guard).** Never start a row whose `est_wall_s` (from its `wall_class`,
§6 Q-NIGHT-3) exceeds the family's remaining declared window: `est_wall_s ≤ window_remaining_s`.
Refusal reason `appetite-window`. The window record is **observed, not inferred** — the queue
reads pass 2 §4.3's `{kind, resets_at, remaining_frac, observed_at, author, source}` record and
takes its state at face value:

| record state | what the queue does |
|---|---|
| `OBSERVED` | gate on `est_wall_s ≤ window_remaining_s` as computed from `remaining_frac` |
| `ASSUMED_RESET` | gate on the **pre-reset** remaining value; crossing `resets_at` grants nothing |
| `UNKNOWN` | the dial is already clamped to `appetite_floor(f)` (pass 2 §4.3); the queue applies the guard against the last observed remaining, and if there has never been one, admits only rows whose `wall_class` is the shortest — never treats absence as "the window is full" (`feedback-status-is-an-assertion`) |

**Q-APP-8 (the reservation predicate — a hard gate, not a dial value).** Pass 2 §4.5's finding,
adopted: `RESERVED` was **never a point on the appetite axis** — it is a *task-shape predicate*
(*"deep holistic review · gate-holder verification · spec/design adjudication; never
one-off/general"*, `measurement-methodology.md:30`). A family may therefore be simultaneously
mid-dial (it may spend when it is the right lane) and hard-reserved (it is the right lane rarely).
The predicate is evaluated **with** the appetite check and **before** the dial arithmetic (pass 2
§4.5's *"separate hard gate"*; methodology §1's *"Reservations are hard and override appetite"*).
Refusal reason `reservation-mismatch`. A row outside a reserved family's predicate cannot resolve
to it **at all**, even if every other family is at its lane cap; and the mismatch is refused **at
registration time** as well as at admission, so the mistake is caught when it is cheap.

**Q-APP-9 (the vocabulary the predicate matches on — three taxonomies, pinned).** Rev 1 wrote
`reserved_for = [deep-holistic-review, gate-holder-verification, spec-design-adjudication]` and
matched it against the row's `task_type`, whose domain (§11) is the **8 measured types**
(`audit`, `infra`, `battery`, `implement`, `orchestration`, `integration`, `research`, `spec` —
methodology §1's shares). No row can ever carry `task_type = deep-holistic-review`, so the
predicate was unsatisfiable and `claude-fable-5` was unreservedly undispatchable (T575 N8). Three
vocabularies were floating without a mapping; they are pinned here:

| field | domain | authored by | used for |
|---|---|---|---|
| `task_type` | the **8 measured types** | the row's author | the ledger and the measurement epoch (methodology §1/§3) — **not** the reservation predicate |
| `task_shape` | `T-A … T-H` (`docs/infra/model-task-matrix.md` §1) | the row's author | model qualification (Q-APP-6) and the reservation predicate |
| `scope` | `row` \| `subsystem` \| `holistic` | the row's author | qualifies `task_shape` where breadth is the distinguishing demand |

All three are **declared facts** on the row, never derived (Q-SCHEMA-1); a row missing
`task_shape` is not dispatchable, refused at registration with the field named. The three
reservation phrases map onto `(task_shape, scope)` pairs:

| methodology §1 phrase | `(task_shape, scope)` |
|---|---|
| deep holistic review | `(T-A, holistic)` — a read-only audit/sweep at whole-repo breadth. Plain `(T-A, row)` audit rows, which are 27 % of all work, **do not** match |
| gate-holder verification | `(T-F, *)` — adjudication of another model's work |
| spec/design adjudication | `(T-E, *)` and `(T-F, *)` — spec/design authoring, and adjudication of it |

So `reserved_for(claude-fable) = [(T-A, holistic), (T-E, *), (T-F, *)]`, and methodology §1's
*"never one-off/general"* is exactly the exclusion of `(T-A, row)` and of every other shape. The
`scope` vocabulary is **new in this document** and is listed for ratification (§13 OQ 8) rather
than assumed; the *mapping* is this spec's claim, the *vocabulary* is the operator's to confirm.
Fable's hand-over rule (`feedback-fable-under-90-of-200k`) is a separate family attribute,
`handover_at_tokens = 180000`, and is not part of the predicate.

**Q-APP-10 (the probe predicate — the second hard gate).** `local` was `PROBE`, which like
`RESERVED` bundled a dial value with a predicate. Separated the same way: the dial carries the
back-pressure (pass 2 §4.5's default **15** — *"costs the machine, not credits"*), and a family
flagged `probe_only` admits **only** rows carrying `probe = true`. Refusal reason
`probe-only`. Independently, no `probe_only` family is admitted at all while a measurement run is
declared in progress (Q-COND-4c — methodology §1's *"never during a measured suite run (load
contamination — the D6/D12/D14 cull)"*). The interlock is a condition, not a dial value, because a
dial the machine drops to 0 for the duration would be indistinguishable from an operator forbid.

**Q-APP-11 (the family table is data, and the mirror is gated).** One row per **family** (not per
model), in the same sentinel-fenced data region as §5's dispatch table. **"Family" here means the
*appetite* family, not the *launch* family** — pass 2 rev 3's N2 separated the two words: the launch
family selects the argv (three rows: `deepseek`, `claude`, `ollama`), while the dial family is the
credit pool (five: `deepseek`, `claude`, `claude-fable`, `ollama-cloud`, `local`), and the two sets
do not coincide — one claude launch row spans `claude` and `claude-fable` across the 200 k boundary,
and one ollama launch row spans `ollama-cloud` and `local` (`qwen3.8:27b-mlx` is local). Every gate
in this section keys on the **`appetite family`** column of pass 2 §3.1's table; nothing in §4 keys
on the launch `family` column. A new launch-family row must declare its appetite family (pass 2's
arm D6), or the dial has a family it cannot price. Appetite columns:
`family`, `models[]`, `appetite_operator`, `appetite_auto`, `appetite_floor`, `lane_cap`,
`spacing_max`, `window` (the pass 2 §4.3 record), `reserved_for[]`, `probe_only`,
`handover_at_tokens`, `budget_note`, `as_of`. `appetite_effective`, `lanes(f)` and `spacing(f)` are
**derived at read time** and stored nowhere (Q-SCHEMA-1). Every dial write is a record with an
author and a timestamp, superseding rather than overwriting (pass 2 §4.4). The prose authority is
pass 2 §4.5's migration table (whose numbers the operator still owes) and methodology §1's
reservations; **arm `A7` asserts the table and its sources agree field-by-field** — a mirror that
can drift from its source silently is the F7 four-definitions defect again.

| family | pass 2 §4.5 default dial | hard predicate | what binds in practice |
|---|---|---|---|
| `deepseek` (pro / flash) | 90 | none | lanes ≈ `lane_cap`; spacing ≈ 0 — the workhorse |
| `claude` (opus / sonnet / haiku) | 45 | none | ~half the lanes, mid spacing, window guard (Q-APP-7); unpinned qualified work substitutes to `deepseek` (Q-APP-6) |
| `claude-fable` | 60 | `reserved_for = [(T-A, holistic), (T-E, *), (T-F, *)]` | the predicate, almost always — a mid dial on a lane that is rarely the right one |
| `ollama-cloud` (glm / minimax / kimi) | 90 *(the flip target)* | none | **live value 0** (D036) ⇒ `appetite-forbid`; no dispatch at all until a human flips it |
| `local` (qwen / gemma) | 15 | `probe_only = true`, plus Q-COND-4c | one lane, maximally spaced, probe rows only, never during a measured run |

**Controls.**
- `A1` seeded: a family at `appetite_effective = 0` with a row pinned to it ⇒ parked on
  `appetite-forbid`, reported, **not** an anchor, and the row's `age` does **not** accrue.
- `A2` seeded: the reservation predicate — a `claude-fable` row with `(task_shape, scope) =
  (T-A, row)` ⇒ refused `reservation-mismatch` at registration **and** at admission; the same row
  at `(T-A, holistic)` ⇒ admitted. Plus the N8 regression: a row whose `task_type` is one of the 8
  measured types is **not** thereby excluded — the predicate reads `task_shape`, not `task_type`.
- `A3` seeded: `lane_cap = 4`, dial `25` ⇒ `lanes = 1`; two ready rows on that family ⇒ exactly
  one held child, and the second **still accrues `age`** and is reported
  `appetite-lanes-exhausted`.
- `A4` seeded: unpinned row qualified on two families, dials `45` and `90` ⇒ resolves to the `90`;
  the same row **pinned** to the `45` family ⇒ stays on it. Then drop the `90` to `0` ⇒ the
  unpinned row resolves to the `45`, never to the forbidden family.
- `A5` seeded: a 0-dial-pinned row whose `effective` is the highest in the store ⇒ it is **not in
  the eligible set at all**, so it is not the top of the order, not the anchor, accrues no `age`,
  and `c_eff` stays at `C_window` (Q-CAP-3) — the self-DoS arm, shared with `M8`.
- `A6` seeded: a row at `effective = 99` failing one condition ⇒ not dispatched (Q-ORD-9).
- `A7` null: the family table agrees field-by-field with pass 2 §4.5 and methodology §1
  (mechanical diff, including the `(task_shape, scope)` mapping of Q-APP-9).
- `A8` seeded: `est_wall_s > window_remaining_s` ⇒ not started, reported `appetite-window`; and
  the window record at `ASSUMED_RESET` past `resets_at` ⇒ **still** gated on the pre-reset value
  (crossing the clock grants nothing).
- `A9` seeded: spacing — dial `1`, `spacing_max = 600`, a fresh `last_dispatch_at` for that
  family, and the top candidate on it ⇒ that candidate is skipped `appetite-spacing`, **the next
  candidate on another family fires in the same iteration**, and the skipped row accrues. Mutation:
  make spacing stall the iteration ⇒ this arm goes red.
- `A10` seeded: `probe_only` — a non-`probe` row on `local` ⇒ refused `probe-only`; a `probe` row
  ⇒ admitted; with a measurement declared, the `probe` row ⇒ refused (Q-COND-4c) and the next
  non-`probe` candidate on another family fires.
- `A11` (mutation) let the queue write `appetite_operator` ⇒ pass 2 §4.4's worker-write refusal
  arm goes red, proving the queue's read-only relationship is enforced and not merely stated.

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
| V6 | stdout envelope (`output_format`) | claude passes `--output-format json` and the runner buffers instead of streaming (`tools/runner:990-995`, `forward=False`, *"a claude JSON lane"*) | **branch today**; a 2-value enum — pass 2 DP-5's `output_format ∈ {text, json-envelope}` |
| V7 | post-exit release call | `ollama stop <launched tag>` (pass 2 **§6**; rev 1 cited "pass 2 §4", the appetite dial — T575 N12) — daemon-owned model outlives `treekill`, and the release must carry the **launched** tag (`glm-5.2:cloud`), not the canonical label (pass 2 F9) | **branch today**; a command template or none |
| V8 | guard defaults | `--rss-cap-mb` documented "deepseek only" (`bin/subagent:8`); local MLX needs ~18 GB headroom | **branch today**; numeric attributes |

### 5.2 The verdict: fully data, with one naming rule

**Q-DP-1 (fully data).** All of V1–V8 are expressed as columns of one table, one row per family,
in **one** location — pass 2 DP-2's `canonical_models[]` region in `src/managent/main.zig`,
extended (today it is a flat list of ten label strings at `src/managent/main.zig:155-166`,
exposed by `managent models` — the verb dispatch at `:374-377`, the implementation at `:5207-5229`).
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
  enum with one interpreter per value: **`output_format ∈ {text, json-envelope}`** and
  `release ∈ {none, <command template>}`. The `output_format` name and domain are pass 2 §3.1/DP-5's
  — rev 1 of this document coined a second vocabulary (`stdout_envelope ∈ {raw, json_result}`) for
  the same capability, and pass 2's arms D2/D3/D4 are keyed to *its* names, so the coinage is
  withdrawn (T575 N7). One capability, one spelling.

**Q-DP-3 (the naming rule — how a 1-family interpreter is still "data").** V6's `json-envelope`
today has exactly one user (claude). A single-user interpreter is a legitimate honest worry: is
it a branch wearing a costume? The rule that resolves it: **an interpreter is named for the
capability, never for the family.** `json-envelope` unwraps a JSON envelope and takes `.result`;
any future family emitting the same envelope selects the same value with no code change. A
`claude_envelope` branch would fail this test, and it also fails the mechanized gate below,
which is the point — the gate makes the rule enforceable rather than aspirational.

**Q-DP-4 (the mechanized gate — pass 2 DP-3's *inclusive* sentinel form).** Rev 1 of this
document specified the gate in the **exclusive** shape (grep the file, minus the data tables) —
the shape pass 2 rev 2 F5 explicitly rejected, because it inverts the form that shipped and works
(T556 acceptance, `pass1/plan.md:173-174`). Withdrawn; pass 2 DP-3's inclusive form is adopted
verbatim and extended to the queue layer's own regions. Each region is delimited by **emitted
sentinel comments** and `awk`-selected *in*; the grep runs on that selection only:

```sh
for region in "supervise: dispatch/input" "queue: resolution" "queue: appetite" "queue: conditions"; do
  sel=$(awk "/^\/\/ ── ${region} region/,/^\/\/ ── end ${region}/" src/managent/main.zig)
  # a gate that greps nothing is green forever: an empty selection FAILS
  [ -n "$sel" ] || { echo "EMPTY SELECTION: $region" >&2; exit 2; }
  printf '%s\n' "$sel" | grep -v '^[[:space:]]*//' |
    grep -qiE 'claude|deepseek|ollama|qwen|glm|minimax|kimi|gemma|(^|[^a-z])pi([^a-z]|$)' \
    && { echo "FAMILY TOKEN INSIDE: $region" >&2; exit 1; }
done
exit 0
```

Three properties the exclusive form lacked, all pass 2 F5's: (i) the region is *selected in*, so a
token outside it is irrelevant by construction and the gate cannot be defeated by moving code;
(ii) `grep -v '^[[:space:]]*//'` strips comment lines, so `pi` in prose cannot trip the gate while
`pi` as an argv literal still does; (iii) the data tables sit *outside* every selection and need no
exclusion clause. **An empty selection is a loud failure, not a pass** — a gate that greps nothing
is green forever (pass 2's D1-empty carries the same rule). A family token inside a selected region
is the drift alarm.

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
| `BEATING-STALLED` | heartbeat age ≤ `progress_timeout` **and** a `step` **has been declared at least once** **and** it is unchanged for ≥ `STALL_S` (default `progress_timeout`) | zombie-suspect — alive, reporting, not advancing |
| `UNDECLARED-STEP` | heartbeat age ≤ `progress_timeout` **and** `step` has **never** been declared | alive and reporting, ETA unknowable — a legacy worker, **not** a zombie-suspect |
| `SILENT` | heartbeat age > `progress_timeout` | zombie — killed by the watchdog, and recorded as such |
| `DEAD` | `waitpid` returned | terminal; the run record is finalized |

**Why `UNDECLARED-STEP` exists (and is not tidiness).** Q-NIGHT-4 promises backward compatibility
— *"a legacy bare `[progress]` line still satisfies liveness"* — and every worker on the tree today
is legacy. Under rev 1's four classes a child with no `step` at all satisfies neither "strictly
increased" (null) nor fails "unchanged for ≥ `STALL_S`" (null never changes), so **every** legacy
child would be classified `BEATING-STALLED` — reported as a zombie-suspect, every poll, forever
(T575 N5). That is the false-alarm-that-trains-readers-to-ignore-it shape this spec itself cites
in the logjam-flag lifecycle (T514, `tools/fleet-keeper.sh:748-762`) and in pass 2's F5. ETA already
had its no-declaration branch (`ETA-UNKNOWN`); the class needed the same one. **The transition is
one-way and immediate:** the first poll at which a `step` is declared moves the child to
`ADVANCING`, and it can never return to `UNDECLARED-STEP` for the rest of the run — so upgrading a
brief to the `step=i/n` contract mid-flight is observable rather than silent.

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
reached. `NG4` seeded: stub emitting legacy bare `[progress]` for longer than `STALL_S` ⇒ liveness
satisfied, class `UNDECLARED-STEP` (**never** `BEATING-STALLED`), `ETA-UNKNOWN` reported (not
blank); then the same stub emits `step=1/4` ⇒ the class moves to `ADVANCING` on that poll and
never returns. Mutation: fold `UNDECLARED-STEP` back into `BEATING-STALLED` ⇒ this arm goes red.
`NG5` seeded: fake-clock the report interval ⇒ a record exists per interval; suppress the writer ⇒ red. `NG6` seeded: each of the three ceilings tripped
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

**Division of labour with pass 2 §5 (RUN-1..5) — one regime, two owners.** Rev 1 of this document
re-spec'd the same operator ruling (`docs/status/orchestration-layer-spec.md` §7.5) independently
of pass 2 §5, and the two disagreed on field shapes, on the uniqueness key, and on the depth cap's
name — both at Must level, so a build following both would have had to choose silently (T575 N6).
That is exactly how the F7 four-definitions drift starts. The split, normative from here:

| concern | owner | why there |
|---|---|---|
| **write-time enforcement** — every check below runs at the store write (`managent add`), not in the dispatch loop | **pass 2 §5** | a worker can write the store directly; a check that lives only in the queue is bypassed by the first worker that mints a row itself (pass 2 §5's opening) |
| the mint-delta **circuit breaker** (RUN-1) | **pass 2 §5** | it is a property of the close path, which the supervisor owns |
| one author per mint, lineage, justification (RUN-2/3) | **pass 2 §5** | the field definitions below are pass 2's, not this document's |
| **quarantine, ratification, and the ordering consequences** — `pending-ratification` as a status, no accrual, never an anchor, the depth/fan-out/tree/rate caps, `--supersedes`, the visibility gauge | **this section** | they are all statements about *the queue*: what a quarantined row does to `eligible`, to `age`, and to `c_eff` |
| the **second** uniqueness key | **this section** | pass 2 rev 3 defines RUN-4's `justification-key` as the normalized justification text over open rows; `mint_key` (Q-MINT-5) keys on title/deliverables/acceptance over **all** rows, open or closed. Disjoint fields, disjoint cases, both refuse `duplicate-mint` and the record names which fired |

Where the two documents named the same thing twice, **pass 2's field set wins** and this
document's duplicate is withdrawn (Q-MINT-1). Where this document adds a check pass 2 does not
have (Q-MINT-6 disjoint deliverables, Q-MINT-7 the well-founded measure, Q-MINT-8 runnability),
the check is new and runs at pass 2's write-time hook, not at a second one.

**Q-MINT-1 (the fields — pass 2's set, one spelling each).** A minted row carries:

| field | shape | owner |
|---|---|---|
| `minted_by` | the identity record `{task_id, model, supervisor_pid}` — exactly one, rejected at write time if absent or if a second author is appended | pass 2 RUN-2 (rev 1 here said "the parent task id"; withdrawn — one author is a *record*, so the lineage walk has exactly one parent) |
| `lineage` | the ordered chain of task ids from the root **human-authored** row to this row; an operator-added row has `lineage = [self]` | pass 2 RUN-3 |
| `mint_depth` | `len(lineage) − 1`; derived, never stored (Q-SCHEMA-1) | this section |
| `justification` | mandatory, non-empty free text naming the finding, gate, or condition the row discharges — **and** at least one deliverable path | pass 2 RUN-3, with this document's deliverable-path requirement added. Rev 1 called it `mint_justification`; withdrawn, one spelling |
| `mint_key` | Q-MINT-5's hash — the definition RUN-4's `justification-key` is missing | this section |
| `decreases` | at `mint_depth ≥ 2` only (Q-MINT-7) | this section |
| `ratified_by` | set by an operator or the Orchestrator seat (Q-MINT-3) | this section |

An operator- or orchestrator-registered row has `minted_by = null`, `lineage = [self]`,
`mint_depth = 0`, and needs none of the rest.

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
- `mint_depth ≤ D_max` (pass 2 RUN-3's name and its operator-set value; spec default **3** while
  the number is owed — §7b's closing line). A hard refusal above it, at registration, refusal
  reason `lineage-depth`. Rev 1 called this `MINT_DEPTH_MAX`; withdrawn, one spelling. Acyclicity
  (a row whose own id appears in its lineage) is pass 2 RUN-3's `lineage-cycle`, unchanged.
- A single parent mints ≤ `MINT_FANOUT_MAX` (default **5**) rows over its lifetime.
- A whole lineage tree (all descendants of one root mint) holds ≤ `MINT_TREE_MAX` (default
  **20**) rows.
- ≤ `MINT_RATE_MAX` (default **10**) rows minted per stop-budget epoch (§6), across all lineages.
- These four are **independent** of the process delegation cap (`WEIZIGO_AGENT_DEPTH`,
  `MAX_DEPTH = 3`, `bin/dispatch:68-69`). That cap bounds *live process nesting*; these bound
  *queued work*. A task can mint a row it never runs, so one cap cannot serve both. Named
  separately so nobody "reuses" one and leaves the other open.

**Q-MINT-5 (uniqueness — two complementary keys, neither redundant).**
`mint_key = sha256(normalize(title) ‖ sorted(deliverables) ‖ normalize(acceptance))`. A mint whose
`mint_key` matches **any** row in the store — open **or** closed — is refused, naming the collision.

**Reconciliation with pass 2 RUN-4 (rev 3, `4f47990`).** Rev 1 of this document was written when
RUN-4's `justification-key` was undefined (T574 N3) and offered `mint_key` as that definition. Pass
2 rev 3 has since defined it *differently and deliberately*: the normalized RUN-3 `justification`
text itself (whitespace trimmed and collapsed, case preserved), explicitly *"not a separate field
… never an author-supplied key field"*, keyed on `(holds, justification-key)` over **open** rows.
That offer is therefore withdrawn — but the two keys are **not** the same check and neither
subsumes the other, so both stand:

| key | catches | misses |
|---|---|---|
| RUN-4's `(holds, justification-key)` — pass 2, open rows | the byte-identical self-copy: a worker whose close reproduces its own justification verbatim. The cheapest possible refusal, and it fires before anything else | a replicator that re-words its justification; a re-mint of *closed* work; two rows with disjoint `holds` producing the same artifact |
| `mint_key` — this section, any row open or closed | a differently-worded row that produces the same title, deliverables and acceptance; and the re-mint of work that already **closed**, which an open-rows-only check cannot see | a genuinely new title/deliverable pair whose justification is copied (RUN-4's case) |

Two independent uniqueness checks for one property is pass 2 §5's own stated pattern — *"three
independent mechanisms, because a single one is a single point of failure for a defect whose cost
is the whole fleet plus the credit pool"* — not duplication of the N6 kind, because they key on
disjoint fields and refuse disjoint cases. Both refuse with `duplicate-mint`, and **the refusal
record names which key fired** (Q-MINT-10), so the two are never confused in the log.

`mint_key` is checked against the row's own ancestors first (an O(depth) walk: a key equal to an
ancestor's is a self-replicator, the sharpest case), then against the whole store. The only
override is `--supersedes <id>`, which names the prior row explicitly and records the
supersession — the honest way to redo work.

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
running*: its resolved family must permit it **now** (§4 — a nonzero dial, and the reservation and
`probe_only` predicates satisfied), its `wall_class` and `task_shape` must exist in the tables, and
its `needs` must form a DAG with the existing rows — a mint that introduces a cycle, or that names
an ancestor in `needs`, is refused. A row that can only run on a family at
`appetite_effective = 0` is refused with that reason, because an eternally-unrunnable row is the
aging mechanism's worst input (Q-CAP-3's rationale). A *lane* or *spacing* limit is **not** grounds
for refusal — those are transient and leave the row runnable.

**Q-MINT-9 (well-specified).** A minted row must satisfy the same registration gates a hand-
registered row does — exactly one bundle, a `# T<nnn> — <title>` line under 40 chars
(`bin/dispatch:224-253`, T505), an `acceptance` command or an explicit skip reason (Q-COND-5) —
so "well-specified" is the existing bar, not a second standard.

**Q-MINT-10 (visibility).** `pending_ratification` is a dashboard gauge with the same
re-derivable-by-hand bar as every other gauge (§12.1). A quarantined row is *visible*, never
silent; a mint refused by Q-MINT-4…9 writes a refusal record naming the rule and the values —
which is pass 2 RUN-5's *"a parked row is reported, never dropped"* applied to every refusal in
this section, not just RUN-3's and RUN-4's. A mint that disappears with no record is the defect.

**Q-MINT-11 (the queue's duty under the mint-delta breaker).** Pass 2 RUN-1's breaker is the
supervisor's instrument — `Δ = open(after) − open(before)` per close, tripping on `K` consecutive
positive deltas (`K` operator-set, default 5) or on a per-window budget. The queue-layer
consequence, which pass 2 states only as *"dispatch nothing new"*, made precise here:

- While `mint-breaker` is tripped the queue fires **nothing**, and the idle report names
  `mint-breaker` as the reason (Q-NIGHT-7's "reason the queue is idle" field).
- **Held children run to completion** — the breaker is not a kill (§6 Q-NIGHT-9's shape).
- **`age` accrues nothing** while the breaker is tripped: it is an iteration that fires nothing,
  and Q-ORD-4 already says such an iteration accrues nothing. So a tripped breaker cannot
  silently reorder the queue by starving whoever happened to be ineligible during it.
- The pressure machine **holds its state**: `anchor`, `drops` and `c_eff` are untouched, because
  `completed` is still an honest diff (R13's rule under cooldown, same reason).
- Only an operator clears it. The queue has no self-clear path — a queue that could clear a
  runaway detector to resume dispatching is the detector's own failure mode.
- Control: arm `M12` seeded — trip the breaker with `K` positive deltas ⇒ zero fires, the reason
  reported, held children finish, `age` and `c_eff` unchanged across the tripped iterations; clear
  it ⇒ dispatch resumes on the next iteration.

**Controls.** `M1` seeded: a depth-4 mint ⇒ refused, rule named. `M2` seeded: a parent minting 6
rows ⇒ the 6th refused. `M3` seeded: a 21st row in one lineage ⇒ refused. `M4` seeded: 11 mints
in one epoch ⇒ the 11th refused. `M5` seeded: a mint whose `(title, deliverables, acceptance)`
matches an ancestor ⇒ refused as self-replicating; matches a *closed* row ⇒ refused; with
`--supersedes` ⇒ admitted and the supersession recorded. `M6` seeded: overlapping deliverables
with a grandparent ⇒ refused. `M7` seeded: depth-2 mint with no `decreases` ⇒ refused; with
`n_child = n_parent` ⇒ refused; with `n_child < n_parent` ⇒ admitted. `M8` seeded: a mint pinned
to a family at `appetite_effective = 0` ⇒ refused; and separately, an already-registered
0-dial-pinned row with the store's highest `effective` ⇒ not eligible, not the anchor, `c_eff`
unchanged (the self-DoS path, shared with `A5`). Plus: the same row pinned to a family merely at
its `lanes` limit ⇒ **admitted** (a transient limit is not grounds for refusal, Q-MINT-8). `M9` seeded: a mint whose
`needs` closes a cycle ⇒ refused. `M10` seeded: a depth-2 mint passing every check ⇒ status
`pending-ratification`, not dispatchable, counted in the gauge; after `ratified_by` ⇒
dispatchable. `M11` (mutation) disable the quarantine default ⇒ `M10` goes red. `M12` seeded: the mint-delta
breaker (Q-MINT-11), as specified there. `M13` seeded: a mint written with **two** `minted_by`
authors, and one with **zero** ⇒ both refused at write time (pass 2 RUN-2), proving the queue never
sees an anonymous or multiply-parented row to walk.

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
 5. conditions             eligible = rows satisfying Q-COND-1(c), Q-COND-2..11 (report each)
 6. order                  sort by (waiting, effective, age, added, id)  (Q-ORD-3)     [new key]
 7. pressure bookkeeping   anchor with stickiness; drops += |completed|; c_eff (Q-CAP-1..3) [sticky new]
 8. cap                    |running| >= c_eff ⇒ dispatch nothing, report
 9. candidate filter       two holds tests (Q-COND-1a/b) + appetite lanes/spacing (§4) —
                           a row skipped here stays eligible and accrues (Q-COND-0a)
10. fire one               hand the first surviving candidate to `managent supervise <id> <model>`
11. accrue                 age += 1 for every eligible row not fired (Q-ORD-4)         [new]
12. report                 per-interval progress report if due (Q-NIGHT-7)             [new]
```

**Q-ITER-1.** Exactly **one** row is fired per iteration (recovered behaviour, `:781-782`). The
fleet fills over successive iterations rather than in a burst; this is what makes the cap, the
pressure state, and the in-flight child set consistent at every decision point.

**Q-ITER-2.** Steps 5 and 6 are separate and in this order. A condition is never consulted
inside the sort, and a priority is never consulted inside a condition. This is the mechanical
form of "conditions are non-negotiable" and is checkable by inspection of the two regions. Step 9
is a **third** region, distinct from both: it decides *which of the ordered eligible rows runs
now*, and a row it skips is still eligible (Q-COND-0a). Three regions, three inspections —
`grep` for a holds test inside the step-5 region, or for an `effective` comparison inside step 5
or step 9, must return nothing.

**Q-ITER-3.** `--once` runs exactly one iteration and exits (recovered test hook, `:91-92`,
`:789-793`; pass 2 keeps it as `managent supervise --once`). Every control arm in §9 is written
against `--once` on a scratch store, so no arm needs a timer.

---

## 9. Controls

**Discipline.** Scratch store (`MANAGENT_STORE`) + scratch repo root + stub workers via the
`--test-worker=<cmd>` hook (T427/T476, carried by pass 2). No arm dispatches a real model. No arm
sleeps: the clock-dependent arms seed a stale timestamp, exactly as the recovered
`regression-fleet-keeper.sh` arm `g` seeds a 61-minute-old `waiting_since`
(`tools/regression-fleet-keeper.sh:761-830`, the seed itself at `:774`; rev 1 cited `:890-929`,
which is arm `h`, the `waiting=1` bump — a copying reader landed in the wrong arm, T575 N11).
Red-first: every seeded arm is seen failing before the code exists.

**Q-CTL-1 (a null control and a seeded control per statement).** Table below. A statement whose
seeded arm cannot be made to fail is not a statement about this system.

**Q-CTL-2 (instrument-mutation controls).** Six mutations, each of which must turn a named arm
red — this is what proves the arms are measuring what they claim (`feedback-never-trust-a-green-test`):

| mutation | must go red |
|---|---|
| remove the `age` term from `effective` | `O2`, `O3` |
| remove anchor stickiness (re-key the anchor to the order's top) | `P4`, `P5` |
| **move Q-COND-1(a)/(b) into the step-5 conjunction** (rev 1's placement) | `a`, `P4`, `H2` |
| revert `needs` to the status-only rule | `N2` |
| delete the data-table sentinel comments | `DP3` |
| **make the sentinel selection empty** (rename a sentinel) | `DP3` — an empty selection must FAIL loudly, not pass |
| **let spacing stall the iteration** instead of falling through the order | `A9` |
| **fold `UNDECLARED-STEP` back into `BEATING-STALLED`** | `NG4` |
| **let the queue write `appetite_operator`** | `A11` |
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
| `O3` | seeded | Q-ORD-6 | one row base 50 (the **earlier** entrant), one base 99 that is **ineligible for ≥ 1 of the 49 fires** (seed a backoff window), 49 fires between | the base-50 row takes the top at exactly fire 49, not 48, not 50. The precondition is part of the seed: without differential accrual the two tie on `effective` **and** on `age`, and key 4 (`added` asc) decides — see Q-ORD-6 |
| `O3b` | seeded | Q-ORD-6 | the **lockstep** case: base 50 and base 99 both continuously eligible, the 99 added first, 60 fires | the 99 **never** loses the top; at saturation both are `effective = 99` with equal `age` and FIFO holds it. This is the arm that would have caught rev 1's unconditional crossover claim |
| `O4` | seeded | Q-ORD-5 | a row at `age = AGE_CAP` after further fires | `age` clamps; `effective` stays 99 |
| `O5` | seeded | Q-ORD-4 | a row ineligible (missing bundle) during 5 fires | its `age` is unchanged |
| `O6` | null | Q-ORD-3 | two rows identical on keys 1–4 | order is stable and total (id asc), across two runs |
| `P4` | seeded | Q-ORD-7 (driver i) | anchor blocked at `priority 50, age 45` (`effective 95`); a second row at `priority 60` that was ineligible for 5 fires re-joins at `age 40` (`effective 99`) and overtakes on key 2 | anchor and `drops` persist; `c_eff` keeps falling; the overtaking row still runs the moment it is conflict-free |
| `P5` | seeded | Q-ORD-7 (driver ii) | anchor blocked; an operator sets `waiting = 1` on a different eligible row, which takes the top on key 1 | anchor and `drops` persist — a bump changes who *runs*, never who *anchors* |
| `H1`–`H5` | null+seeded+mutation | Q-COND-1 | §3.1 | as §3.1; `H5` is the placement mutation — move the two holds tests into the step-5 conjunction and arm `a` plus `P4` must go red |
| `N1`–`N4` | null+seeded+mutation | Q-COND-2 | §3.1 | as §3.1 |
| `A1`–`A11` | seeded+null+mutation | §4 (the dial) | §4 | as §4; `A2` (the `task_shape` reservation predicate) and `A9` (spacing never stalls the iteration) are the two the rev-1 level model had no arm for |
| `Q1`–`Q3` | null+seeded | Q-COND-4 | §3.1 | as §3.1 |
| `D1`–`D3` | null+seeded | Q-COND-5 | §3.1 | as §3.1 |
| `C1`–`C7` | seeded | Q-COND-6..12 | §3.2 | as §3.2 |
| `DP1`–`DP4` | null+seeded+mutation | §5 | §5 | as §5; `DP2` (fictional family, zero source edits) is the load-bearing one |
| `NG1`–`NG8` | seeded+mutation | §6 | §6 | as §6; `NG4` carries the `UNDECLARED-STEP` mutation |
| `M1`–`M13` | seeded+mutation | §7 | §7 | as §7; `M12` (mint-delta breaker) and `M13` (zero/two authors) are the pass 2 §5 seams |
| `a`–`h` | carried | R5–R7 | design §13 | unchanged, must stay green |

**Q-CTL-4 (the hand-trace acceptance).** Beyond the arms: one hand-traced night. A real overnight
run, then by hand from disk — recompute the order for three arbitrary iterations from the stored
`(waiting, priority, age, added, id)`, recompute `c_eff` from `(C_window, drops)`, and reconcile
the report's per-child classes against the run records. If any of the three cannot be reproduced
by hand, the layer is not accepted. This is L1's own bar ("a gauge that cannot be re-derived is
decoration") applied to the scheduler's decisions rather than to its displays.

---

## 10. Changes from the recovered implementation — each needs a ruling

Pass 2 §10.1 item 2 carries the keeper's policy "behaviour-preserving". These seven are **not**
behaviour-preserving and are listed for explicit decision rather than adopted silently.

| # | change | statement | why | risk if adopted | risk if rejected |
|---|---|---|---|---|---|
| 1 | numeric aging added to the order | Q-ORD-2/4 | the operator's 2026-08-21 ruling; no aging exists today (§1.2) | a pinned `priority=99` loses to a starved default after 49 fires | starvation stays bounded only by the cap-drop, which needs a *conflict* to engage — a row starved by mere ordering never escalates |
| 2 | anchor stickiness | Q-ORD-7 | without it aging makes the pressure machine vacuous (§2.2) | a newly-urgent blocked row waits for the current anchor's epoch | pressure never builds under aging; both rows starve |
| 3 | `priority`/`age`/`waiting` move into the store row | Q-ORD-8 | `age` is queue-written; 24 file reads + 12 subprocesses per tick at 12 eligible rows today (§2.1; rev 1 said 36/18 here, a figure derivable from nothing — T575 N9) | a store schema change (T485/486/487 hold `main.zig`) | the queue writes worker briefs, and the cost stays |
| 4 | needs require a **passing** verdict | Q-COND-2b | a dependency that closed `blocked` satisfies a need today, in both implementations; T535/T541 is a live instance | 1 open row re-blocks immediately; more as `blocked` closes accumulate | work proceeds on foundations that were never laid |
| 5 | fleet-quiet as an **admission** condition | Q-COND-4 | no host check exists in the queue today; the floor is a post-hoc killer only | a quiet host that reads low parks the fleet | the 2026-07-29 panic shape stays reachable from the queue |
| 6 | discharge (acceptance) required before dispatch | Q-COND-5 | "done is the only success" needs a gate authored before the work | **all 12** queue-eligible rows park until backfilled | a worker invents its own gate at close time |
| 7 | progress-line `step=i/n` contract | Q-NIGHT-4 | "will-finish-in-time" is otherwise an opinion | worker briefs must ask for the fraction | ETA stays unmeasurable; `ETA-UNKNOWN` everywhere |

**Not in this table (and why).** The appetite **dial** (§4) is not a change *this* spec proposes:
it is pass 2 rev 2's operator-refinement (a), already a Must there and on its never-cut list, so it
needs no ruling here — only its constants are owed (§7b closing line). Likewise the mint regime's
write-time enforcement is pass 2 §5's. What §4 and §7 add here are the *queue-layer consequences*
(Q-APP-5's spacing fall-through, Q-APP-9's `task_shape`/`scope` vocabulary, Q-MINT-11's breaker
duties), and the one genuinely new vocabulary among them — `scope` — is §13 OQ 8.

**Recommendation on each:** adopt 1, 2, 3, 5, 7 as specified. Adopt 4 with the ruling that it
changes **both** implementations in the same commit (`fleet-keeper`'s successor and
`main.zig:1590`), because a split rule means the queue and the engine disagree about which rows
are `dispatchable`. Adopt 6 **only with** a named backfill row closed before
the queue goes live — enforcing it retroactively without the backfill parks all 12 eligible rows
on night one, which is the same class of defect it is meant to prevent.

---

## 11. State and schema

**Store row, added fields:** `priority` (int, default 50) · `age` (int, default 0) · `waiting`
(bool, default false) · `task_type` (one of the **8 measured types** — the ledger vocabulary,
methodology §1) · `task_shape` (one of `T-A … T-H`, `docs/infra/model-task-matrix.md` §1 — the
qualification and reservation vocabulary, Q-APP-9) · `scope` (`row` \| `subsystem` \| `holistic`,
Q-APP-9) · `wall_class` · `probe` (bool) · `minted_by` (the `{task_id, model, supervisor_pid}`
record, pass 2 RUN-2) · `lineage` (array) · `justification` · `mint_key` · `decreases` ·
`ratified_by`. New status value: `pending-ratification`. The three taxonomy fields are distinct and
none substitutes for another (Q-APP-9); `mint_depth` is **derived** from `lineage` and is stored
nowhere.

**Store `_sys`, added fields:** `pops` (monotone count of fires — telemetry and the audit trail
for `age`) · `minted` (count, for `MINT_RATE_MAX`) · `epoch_started_at`.

**Data table (one location, pass 2 DP-2's region, sentinel-delimited):** per **model** —
`label`, `family`, `serving_tag`, `aliases[]`. Per **family** — `provider`, `argv_template`,
`require_env[]`, `preflight`, `tool_allowlist`, **`output_format ∈ {text, json-envelope}`** (pass 2
§3.1/DP-5's name and domain — rev 1's `stdout_envelope ∈ {raw, json_result}` is withdrawn),
`release`, `rss_cap_mb`, `host_headroom_mb`, and the appetite columns of Q-APP-11:
`appetite_operator`, `appetite_auto`, `appetite_floor`, `lane_cap`, `spacing_max`, `window` (the
pass 2 §4.3 record), `reserved_for[]`, `probe_only`, `handover_at_tokens`, `budget_note`, `as_of`.
`appetite_effective`, `lanes(f)` and `spacing(f)` are derived at read time and stored nowhere.

**Mode table:** `C_base`, `C_night`, `NIGHT_WALL_FACTOR`, `progress_timeout`, `STALL_S`,
`REPORT_EVERY`, `RUN_WALL_S`, `RUN_CLOSES`, gauge stop thresholds, `AGE_CAP`, `D_max` (pass 2
RUN-3), `MINT_FANOUT_MAX` / `MINT_TREE_MAX` / `MINT_RATE_MAX`, `K` (the pass 2 RUN-1 breaker's
consecutive-delta threshold), `HOST_FLOOR_MB`, `QUIET_LOAD`, and the §12.1 view's
`MIN_ROWS`.

**Retained runtime state** (recovered): pressure record (`anchor`, `drops`, `waiting_since`,
`running`), heal state, attempt/backoff state, lane-down census, logjam flag. **Added:**
`last_dispatch_at` per family (Q-APP-5's spacing clock — one timestamp per family, the only new
clock in the layer, and it feeds a rate limit, never an ordering key). Pass 2 §2.4 moves
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

### 12.1 What the deferred dashboard must be — operator requirement, 2026-08-22

The dashboard is **not built here** (above), but the queue layer is its principal producer, so the
requirement is stated here rather than left to be rediscovered by whoever builds it. The operator's
words, 2026-08-22 (`docs/status/orchestration-layer-spec.md` §7b item 10): *"I expect bin/managent
to produce a dashboard with full task transparency. Written in Zig, fully tested, and reliable."*
`untracked/watch-fleet.sh` remains a spot-check viewer only — no further investment.

**Q-VIEW-1 (home and language).** The view is a `bin/managent` verb, in Zig, in the same binary
that owns the store. Not a shell wrapper, not a second reader of the store.

**Q-VIEW-2 (terminal height- and width-aware — a requirement, not a nicety).** The view **fits the
terminal it is printed into**: it reads the terminal's rows and columns and lays out inside them.

- **Height.** The four sections are budgeted, not truncated blindly:
  `PROGRESS` and `CONCERNS` **always show every row** — they are the two that must never be
  elided, because an unseen in-flight worker and an unseen concern are exactly the "silent process"
  this layer exists to forbid (§6 Q-NIGHT-6). `DONE` and `OPEN` show **at least `MIN_ROWS` each**
  and expand into whatever height is left. This is `untracked/watch-fleet.sh`'s own budget
  (`:4`, `:186-189`), and it is carried because it is the shape the operator already reads.
- **Width.** Every line fits the column count with no wrapping and no horizontal scroll. Columns
  are elided from the least load-bearing end; an **elision is marked** (`…`), never silent, so a
  truncated title cannot be mistaken for a short one.
- **Overflow is stated, never hidden.** When a budget forces rows out of `DONE` or `OPEN`, the
  section header says how many were withheld (`OPEN (14, showing 6)`). A section that silently
  shows a subset is a display that lies.
- **The size is injectable.** `FLEET_LINES` / `FLEET_COLS` (watch-fleet's existing hook, `:58`)
  override the detected size, so every layout arm runs at a pinned geometry and no arm needs a
  pty. Arms: an 80×24 and a 200×60 geometry over the same store ⇒ both fit, both show every
  `PROGRESS` and `CONCERNS` row, both mark their elisions; a geometry too small for even
  `MIN_ROWS` ⇒ a named, non-crashing degradation, not a panic and not a wrapped mess.

**Q-VIEW-3 (the four sections).** `PROGRESS` / `CONCERNS` / `DONE` / `OPEN`, in that order — the
watch-fleet shape. The queue layer supplies each: `PROGRESS` is the held children with their
Q-NIGHT-5 class and ETA verdict; `CONCERNS` is the union of the loud states this spec defines
(`BEATING-STALLED`, `SILENT`, `WILL-OVERRUN`, a broken three-way equality, the logjam flag,
`mint-breaker`, a tripped lane, and **the reason the queue is idle when it is idle**); `DONE` is
recent closes with their verdicts; `OPEN` is the ordered eligible set with `effective`, `age`, and
the failed condition for the rows that have one.

**Q-VIEW-4 (every row re-derivable from disk by a named command).** This is the L1 bar and it is
not negotiable: **each line of the view carries, or the view's legend names, the command that
reproduces it** — `managent status --json`, `managent supervise status --json`, `managent show
<id>`, `ps` for a held pid. A number that no printed command reproduces is decoration and must be
deleted rather than explained. This is the same rule §9's Q-CTL-4 hand-trace applies to the
scheduler's decisions, applied to its displays.

**Q-VIEW-5 (human-friendly means legible, not decorated).** No colour or glyph carries information
that is not also in the text (the view must read correctly piped to a file, which is also how the
arms read it); no animation; no spinner; no progress bar standing in for a number. Full task
transparency means the operator can answer "what is running, what is stuck, what closed, what is
next, and why is nothing running" from one screen without a second command.

**Q-VIEW-6 (fully tested — what that means here).** The view gets the same instrument discipline as
everything else in this document: a null arm (a known store ⇒ a byte-exact expected screen at a
pinned geometry) and a seeded arm per claim above (elision marked, withheld count stated, every
`PROGRESS` row present at the smallest geometry, `CONCERNS` non-empty when a seeded child is
`SILENT`), plus a mutation arm (drop a `PROGRESS` row under height pressure ⇒ red). A dashboard is
an instrument; it earns its first reading the same way (`feedback-never-trust-a-green-test`).

---

## 13. Open questions — rulings needed

1. **The seven changes in §10**, each individually. §10 carries a recommendation for each.
2. **`AGE_CAP = 49`, and how little it decides.** It makes a default row exactly *reach* the
   pinned ceiling — not pass it. Under lockstep accrual a pinned 99 and a starved 50 tie on
   `effective` **and** on `age` at fire 49, and key 4 (`added` asc) gives the top to the earlier
   entrant, so **an earlier-added pinned 99 is already effectively absolute at either cap value**
   (T575 N4). The only path by which the starved row takes the top is differential accrual — the
   pinned row missing at least one fire's accrual — and `AGE_CAP = 48` would close *that* path
   too. So the real question is narrower than rev 1 stated it: *should a pinned 99 that was itself
   parked (backoff, appetite, host-quiet) be overtakeable by a row that kept accruing?*
   Recommendation: keep 49 — yes, it should be, because a pinned row that has been unrunnable is
   not the same thing as a pinned row that is waiting — and note that `waiting = 1` already
   provides an absolute override that no amount of aging can pass.
3. **`C_night = 2`.** A number, not a principle. Wants one night of measurement.
4. **`D_max = 3` (pass 2 RUN-3's cap, whose number the operator still owes) and the auto-admit
   boundary at depth 1.** The boundary is the
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
8. **The `scope` vocabulary (`row` \| `subsystem` \| `holistic`).** Q-APP-9 introduces it to make
   the Fable reservation predicate satisfiable — without it, "deep holistic review" cannot be
   distinguished from an ordinary `T-A` audit row, and `T-A` is 27 % of all work, so a
   `task_shape`-only predicate would either make Fable unreservedly undispatchable (rev 1's defect)
   or admit a quarter of the queue to it. The *mapping* in Q-APP-9 is this spec's claim; the
   *vocabulary* is new and the operator's to ratify, narrow, or replace. It is a declared field, so
   whatever the vocabulary, it stays hand-checkable.
9. **Q-APP-5's spacing clock.** It is the only clock this layer admits into a dispatch path, and
   design §9 argues against clocks there. The narrowing (a per-family rate limit that never decides
   *which* row runs, only whether this family's turn has come) is stated in Q-APP-5, and the
   fall-through rule keeps one throttled family from stalling the fleet — but the operator may
   prefer the dial to act on `lanes` alone and drop `spacing` entirely, which would remove the
   clock. `spacing` is pass 2 §4.2's, so dropping it is a pass-2 amendment, not a local choice.
10. **The `MIN_ROWS` budget and the four-section shape for §12.1.** Carried from
    `untracked/watch-fleet.sh` because it is the shape the operator already reads; the numbers
    (`MIN_ROWS`, and whether `CONCERNS` outranks `PROGRESS` when even the unelidable sections do
    not fit) want one look at a real screen.

---

## 14. Provenance and rejected alternatives

| aspect | source |
|---|---|
| priority 0–99, default 50, tie-break by `added`; the model allow/deny window | directive **D022** (2026-08-19T23:07:31Z), `docs/infra/managent/directives.jsonl` |
| the cap-drop pressure arithmetic, verbatim | directive **D023** (2026-08-19T23:17:11Z); `docs/infra/fleet-keeper-design.md` §2, §6, §7 |
| the one-writer invariant; the rejection of dispatch-anyway; completion-driven over clock-driven; the floor at 1 and its proof; the logjam flag as telemetry-only | `docs/infra/fleet-keeper-design.md` §1, §3, §7, §9, §10 |
| `waiting=1` as the bump; the three-key sort; eligibility filters; heal cooldown; pre-claim backoff and the lane circuit breaker; the cooldown dead-man's switch | `tools/fleet-keeper.sh` (lines cited per row in §1.1) |
| the held-child set as a condition; one dispatch interface; the family-token grep gate; cooldown as a verb; shutdown semantics | `S01-process-ownership/pass2/spec.md` §2.1, §2.4, §2.5, §3 |
| the appetite **dial** (0–99), `lanes`/`spacing`, the window record's three states, the write hierarchy, and the finding that `RESERVED` was never on the appetite axis | `S01-process-ownership/pass2/spec.md` §4.1–§4.5 (operator refinement (a), a Must; constants still owed per `docs/status/orchestration-layer-spec.md` §7b closing line) |
| the family table's prose source, the hard reservations, the probe interlock, the task-type shares | `S02-model-delegation/measurement-methodology.md` §1 (levels superseded by pass 2 §4; the reservations and the interlock are not) |
| the `T-A … T-H` task shapes the reservation predicate matches on | `docs/infra/model-task-matrix.md` §1 |
| mint write-time enforcement, one author per mint, lineage + justification, `D_max`, the mint-delta circuit breaker | `S01-process-ownership/pass2/spec.md` §5 (RUN-1..5) |
| the dashboard's home, language, and "full task transparency" | operator, 2026-08-22 (`docs/status/orchestration-layer-spec.md` §7b item 10); the four-section height budget and the `FLEET_LINES`/`FLEET_COLS` hook from `untracked/watch-fleet.sh:4`, `:58`, `:186-189` |
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
| appetite as a single boolean gate | cannot express back-pressure at all; the operator's ruling is explicitly a spectrum |
| appetite as the five static levels `OFF/PROBE/CONSERVE/SPEND/RESERVED` (rev 1 of this document) | a five-valued enum cannot express "a bit less than yesterday", so every real adjustment became a doc edit, and `RESERVED` was never on the same axis at all — pass 2 rev 2 §4/§4.5 replaced it with the dial, and two Must-level documents cannot both ship (T575 N2) |
| matching the reservation predicate on `task_type` | its domain is the 8 measured types, so no row can carry `deep-holistic-review` and the predicate is unsatisfiable — it made Fable undispatchable rather than reserved (T575 N8) |
| spacing that stalls the iteration when the top candidate's family is inside its window | converts back-pressure on one family into a fleet-wide stall at that family's `spacing_max` — the "silently off" failure pass 2 §4.2's `max(1, …)` exists to prevent, one layer up (Q-APP-5) |
| the two holds tests as §3 conditions (rev 1 of this document) | a conflict-blocked row would leave `eligible`, so nothing could ever anchor and the recovered cap-drop pressure machine — the operator's own arithmetic — would be inert (Q-COND-0a, T575 N1) |
| a fourth liveness class only (no `UNDECLARED-STEP`) | classifies every legacy step-less worker `BEATING-STALLED` forever, which is the false alarm that trains the reader to ignore the report (Q-NIGHT-5, T575 N5) |
| an *exclusive* family-token grep (grep the file, minus the data tables) | inverts the inclusive sentinel form that shipped and works, and can be defeated by moving code out of the excluded region — pass 2 rev 2 F5 (Q-DP-4, T575 N7) |
| re-spec'ing the mint regime independently of pass 2 §5 | two Must-level field sets for one operator ruling; a build following both must choose silently, which is how the F7 four-definitions drift starts (§7 division of labour, T575 N6) |
| a dashboard that truncates `PROGRESS` under height pressure | an unseen in-flight worker is the silent process §6 exists to forbid; `DONE`/`OPEN` are the elidable sections (Q-VIEW-2) |
| keeping `priority`/`waiting` in the bundle header | the queue would have to write worker briefs to age a row, and the per-tick read cost (24 files + 12 subprocesses at 12 eligible rows, §2.1) is already on pass 2's open-question list |
| keying the anchor to the top of the order (recovered behaviour, unchanged) | correct under static priority, vacuous under aging (§2.2) |
| a wall ceiling as the overnight stuck-detector | `tools/runner:70-81` — it kills correct long-running jobs, which is exactly the "table/engine must not time out prematurely" failure |
| relaxing the RSS cap for an `ADVANCING` child | `tools/runner:76-77` — no progress earns an exemption from a memory-exhaustion kill; the 2026-07-29 kernel panic is the precedent |
| allowing a mint to become dispatchable immediately at any depth | removes the only place a human can see a chain forming; quarantine costs one status value |
| a family branch for the claude JSON envelope | expressible as a capability-named enum (`output_format = json-envelope`, pass 2 §3.1/DP-5), so Q-DP-5's proof obligation is not met |
| a dispatch-anyway escape after N minutes | rejected by the operator 2026-08-20; violates the one-writer rule (§1.3) |
