# RAM policy — declared need, admission-time refusal, and no death for a stranger's memory

**Owner:** T806 (claude-opus-5). **Date:** 2026-08-23. **Status:** policy, ratified-pending —
supersedes the RAM parts of `S08-fleet-guard-reliability/spec.md` per the table in §7.
**Authority:** operator ruling 2026-08-23 (quoted in §0) + directive **D081** (relayed mid-row, 2026-08-23T20:25:48Z; discharged in §2.1, §4.1 and §6.1). **Scope:** policy and disposition only;
`tools/runner`, `bin/subagent`, `tools/fleet-keeper.sh` and `src/managent/main.zig` are untouched
by this row — a build row follows.

## 0. The ruling this document executes

> *"No. panic history does not stand! RAM floor is stupid. Review absolutely everything about RAM
> floor, RAM requirements, RAM panic, and redesign from scratch. Set a modest to generous default
> and then require dispatch to set RAM requirements if tasks require more. Tasks must not panic and
> die just because some other unrelated non-conflicting ps harmlessly exists."*

`S08/spec.md` §3 (*"Raising the floor. Forbidden"*) and §10.5 (a diff touching `total // 8` fails
accept) are lifted. The concern behind them — the 2026-07-29 kernel panic — was raised with the
operator and the instruction reaffirmed. §5 assigns that risk explicitly rather than leaving it
with the mechanism being removed.

---

## 1. The incident re-read: the floor is not what fixed it, and never could have been

`docs/infra/host/incident-2026-07-29.md` is the load-bearing artifact. Its evidence:

| fact | value | source |
|---|---|---|
| the hog | `zig` pid 92604, **12.5 GB RSS / 21.8 GB peak** | incident §"Causal chain", Jetsam `.ips` |
| next largest | `SmartGo` 2.4 GB — **5× smaller** | same table |
| system free at Jetsam snapshot | **~46 MB of 48 GB** | same table |
| normal peak at clean HEAD | **≤ 555 MB** — the hog was **40×** normal | incident §"Honest caveat" |
| the panic | `watchdogd` starved 91 s → `panic()` on core 0 | panic string |

The two fixes the record itself names (`docs/infra/runner.md:6-16`, incident actionable **B-2**) are:

1. **default `-O ReleaseFast`** — *"the LLVM path in Debug is the memory hog"*: the root cause;
2. **a per-process RSS cap** — *"the guard at 4 GB would have caught it with 5 s of slack"*
   (now `--rss-cap-mb` default **12288**, `tools/runner:2576`).

**Neither is a host-wide floor.** The floor is T362 (`tools/runner:2807`, `host_total // 8`),
committed **`1a3a6c1`, 2026-08-20 04:47** — **22 days after the panic**. Three findings follow, and
all three are checkable:

- **The floor has never prevented a recurrence, because no recurrence was available to prevent.**
  The 22-day window between the panic and the floor's existence contains no second host incident
  (the repo holds exactly one host-incident record). Whatever kept the host alive for those 22 days
  was the build-mode default and the RSS cap, because nothing else existed. *(Stated as an
  assertion about the record, not about the machine: absence of a second `.panic` artifact is not
  proof of no event, but absence of a second incident record over 22 days of heavy fleet use is
  the only evidence either way, and it does not favour the floor.)*
- **The floor's trigger point is nowhere near the danger point.** It fires at `48 GB // 8` =
  **6144 MB free**. The panic happened at **46 MB free**. The floor fires **133× further from the
  cliff than the cliff**. The lowest *real* available reading anywhere in the log corpus is
  **4247 MB** — still 92× the panic condition, and no host instability accompanied it.
- **The floor cannot see or touch the thing that caused the panic class it names.** It kills
  members of *its own runner's process group* (`tools/runner:3198-3275`, `poll_rss`). On
  2026-08-23 the 18 GB consumer was the `ollama` daemon — structurally outside every group the
  guard can reach. A 12.5 GB `zig` spawned by an agent lane *is* in-group, but that case is the
  RSS cap's, and the cap is both earlier and surgical.

**Verdict: the floor's justification is refuted.** The 2026-07-29 record justifies exactly two
mechanisms, both per-process, both retained by this policy (§5). It justifies no host-wide,
task-blind, kill-capable threshold.

---

## 2. The floor's firing history — the headline number

Recomputed at HEAD `346b5b2` over `untracked/log/*.log`, anchored on `^\[runner\] `
(`S08/spec.md` Appendix A's method; the anchor is what makes it a census and not a grep):

```
kill lines total (any form)   : 34
kills with identified member  : 20
  futile (victim RSS < shortfall) : 16  (80 %)
  sufficient (victim RSS >= short):  4
kills with NO member named    : 14
shortfall range 15–1897 MB; victim RSS range 40–389 MB
sum of all victim RSS = 3090 MB; sum of shortfalls = 11287 MB
```

**Could-it-have-helped ratio: 4/20 = 20 %. 16 of 20 kills (80 %) destroyed a worker whose entire
resident footprint was smaller than the shortfall it was killed to relieve.** Across the corpus the
guard reclaimed at most 3090 MB against 11287 MB of shortfall — it could not have succeeded even if
every kill had been free.

And the four "sufficient" kills do not rescue the mechanism. Their shortfalls were **15, 31, 141
and 176 MB** — the largest is **2.9 % below the floor**, on a 48 GB host, ~35× further from danger
than the panic. The 14 unattributed kill lines are worse: they include a kill at
**`avail 6138 MB < floor 6144 MB` — a 6 MB shortfall, 0.0125 % of host RAM.**

> **So: of 20 identified kills, zero were both necessary and effective.** 16 were arithmetically
> futile; 4 relieved a transient a dwell requirement would have suppressed. In 3.2 days of
> existence the floor produced ~10 kills/day and prevented nothing. This is not an anomaly to
> repair — it is the mechanism working as designed.

Full per-kill table: `findings/T806-ram-redesign.json` `evidence.kill_census`.

### 2.1 Where `total // 8` came from — asked, and answered (directive D081)

D081 required this be established rather than assumed. Every artifact in the floor's provenance was
read: the bundle `untracked/T362-fleet-aware-memory-guard.md`, the commit message of `1a3a6c1`,
`findings/T362-fleet-guard.json` and `findings/T362-context.json`.

| artifact | what it says about the value |
|---|---|
| T362 bundle, §Scope 1 | *"Derive the floor from `hw.memsize` rather than hardcoding it, and state the panic precedent in the comment so nobody raises it casually."* — **mandates the form, names no value and no divisor** |
| commit `1a3a6c1` | *"below a danger floor derived from hw.memsize (total // 8, …)"* — restates the formula |
| `findings/T362-fleet-guard.json` | *"The floor is derived from hw.memsize (total // 8 ≈ 6 GB on 48 GB)"* — restates the formula |
| `findings/T362-context.json` | *"default 0 = derive total//8 ≈ 6 GB on 48 GB"* — restates the formula |

Four artifacts, four restatements of the arithmetic, **and not one sentence anywhere saying why
eight.** No calculation, no measurement, no reference to the panic's own numbers (the 46 MB free
that actually preceded the panic appears in the precedent citation but never in the derivation),
and no stated relation to any quantity the fleet or the host produces.

> **So, in the words D081 asked for: no derivation exists beyond "an eighth of RAM felt safe."**

Two further observations, because the provenance is instructive rather than merely absent:

- **The brief's own instruction is the origin of the defect.** *"Derive the floor from `hw.memsize`
  rather than hardcoding it"* treats a fraction of hardware as more principled than a constant. It
  is the reverse. A constant would have had to be justified to be written down; a fraction *looks*
  derived while being exactly as arbitrary, and it inherited a false air of rigour that survived
  three subsequent rows (T711, T713, T803) without once being questioned. **A fraction of installed
  hardware cannot know what the fleet is doing** — it moves when you buy RAM and stands still when
  you launch five lanes.
- **T362 diagnosed the right problem and then specified the wrong mechanism.** Its one quantitative
  argument is: *"On 2026-08-04 the operator raised two rows to 8192 MB … and five such rows would
  commit 40 GB."* That is an argument about **total committed demand** — precisely what §4.1's
  admission arithmetic bounds. It is not an argument for a free-memory threshold with a kill verb.
  The floor was a *reaction* to over-commitment where a *bound* on over-commitment was called for.


---

## 3. The measured distribution, and what actually predicts a task's memory need

Corpus: `untracked/runs/*.json`, 517 records, **481 carry `rss_mb`**, **365 nonzero**.

**Two measurement caveats, stated before the numbers.** (a) `rss_mb` is
`max(peak_rss.values())` — the **largest single member's peak**, not the tree's total
(`tools/runner:3449,3507`). A task's real footprint is therefore **understated** by this field;
every default below inherits that bias, and closing it is a build-row item. (b) The 116 zero
values are **censored, not zero**: 116 of 116 are runs under 60 s (54 % of that band), too short to
be sampled. They are excluded, never counted as 0 MB.

### 3.1 What does *not* predict it

Two plausible keys were tested and both fail:

| candidate key | result |
|---|---|
| **provider** (`S08` §2a / ORC-GD-2's table) | all providers converge: deepseek p95 **3207**, claude p95 **3380**, ollama-cloud p95 **3184**, pi/openrouter p95 **784**. The top of the distribution is a repeated ~3.2 GB value (3163–3224 MB) appearing on `deepseek-v4-pro`, `deepseek-v4-flash` and unattributed lanes alike. A number that is the same for everyone is not a per-provider default. |
| **does the task compile** | agent lanes with heavy zig activity: p95 **3198**. Agent lanes with none: p95 **3208**. Bare `zig build test`: p95 **3216**. Indistinguishable. |

ORC-GD-2's per-provider table is therefore **confounded**: it reads provider identity off a
distribution whose shape is set by something else.

### 3.2 What does predict it — time on task

Run duration separates the distribution monotonically in **every** quantile:

| expected wall | n | p50 | p90 | p95 | p99 | max | default `ram_mb` | p95 covered |
|---|---|---|---|---|---|---|---|---|
| `< 60 s` | 97 | 14 | 523 | 570 | 856 | 989 | **768** | 93/97 |
| `60–600 s` | 104 | 522 | 830 | 1626 | 1627 | 1627 | **1792** | 104/104 |
| `600–1800 s` | 119 | 524 | 1427 | 2992 | 3779 | 12296 | **3072** | 113/119 |
| `≥ 1800 s` | 45 | 856 | 3224 | 4574 | 10617 | 13661 | **4608** | 42/45 |

**Rounding rule:** `default = ceil(p95 / 256 MB) × 256 MB` — headroom to the next quarter-GB, no
invented spare constant (ORC-GD-2's rule, retained). Coverage: **352 / 365 = 96.4 %** of measured
runs fit their band's default. **Causal reading, not just a correlation:** an agent lane's resident
set is dominated by accumulated conversation context plus the peak of whatever it spawned, and both
grow with time on task. A model does not have a memory footprint; *a duration of agentic work* does.

### 3.3 The defaults, keyed on task type

Task type is the field a brief actually sets (`T786`); duration is the measured mechanism behind
the number. The mapping uses each type's shape from `docs/infra/model-task-matrix.md` §1:

| type | what it is | expected band | default `ram_mb` | basis |
|---|---|---|---|---|
| **T-A** read-only audit / sweep | one output file, no writes | 600–1800 s | **3072** | §3.2 band 3 |
| **T-B** mechanism fix, test-first | writes source + a regression arm | 600–1800 s | **3072** | §3.2 band 3 |
| **T-C** diagnosis / bisect | reads + runs, writes findings | 600–1800 s | **3072** | §3.2 band 3 |
| **T-D** ledger / absorption bookkeeping | writes JSON + register | 60–600 s | **1792** | §3.2 band 2 |
| **T-E** spec / design authoring | writes a doc | 600–1800 s | **3072** | §3.2 band 3 |
| **T-F** adjudication of another model's work | writes a verdict | 60–600 s | **1792** | §3.2 band 2 |
| **T-G** brief refresh / staleness triage | writes briefs | 60–600 s | **1792** | §3.2 band 2 |
| **T-H** long-horizon sprint console | manages, dispatches its own leaves | ≥ 1800 s | **10752** | §3.2 band 4 **p99**, not p95 — see below |
| *(smoke / duty / harness)* | sub-minute mechanical | < 60 s | **768** | §3.2 band 1 |
| **resident-model modifier** | any task that asks a local server to load a model | any | **+18432** | `docs/infra/model-registry.md:62` — *"local, 18 GB MLX"* |

**Why T-H alone gets p99.** Consoles are the only class whose tail is real: both records above 8 GB
(13661 MB / T724, 12296 MB / T721) are long-horizon lanes, because a console's peak member is
whatever *its leaves* spawned. Consoles are also few, long, and expensive to lose. Leaf lanes get
p95 because they are many, short, and cheap to re-queue — the asymmetry in the cost of being wrong
is the reason for the asymmetry in the quantile, stated rather than assumed.

**Why the resident-model figure is a declaration, not a measurement of the task.** `qwen3.8:27b-mlx`
shows **521 MB** on its own pid (n=2) because the 18 GB lives in the `ollama` daemon. Declaring
521 MB would be `S08` D1 again, moved from sampling code into a registration field. The declaration
is the registry's recorded 18 GB, which also sits above the one measured resident instance
(15.6 GB, `findings/T711-declared-tenant.json`) and inside the operator's stated 18–25 GB range.
Never the live `ps` sample: that sample is non-monotone (36 → 1890 → 9206 → 10153 → 4873 → 2739 →
~7825 MB within one run, `untracked/log/t783.log:48-59`) and under-reports by ~2× even after it
settles.

**Sanity check on concurrency (48 GB host):** 5 leaf lanes at 3072 MB = 15.0 GB; + a resident qwen
= 33.0 GB of 48. Two consoles at 10752 + three leaves at 3072 = 30.7 GB of 48. The defaults are
generous enough to be honest and modest enough to fit the fleet the project actually runs.

**Overrides.** A brief may declare any value with a stated reason; the reason is logged
(ORC-GD-2's override rule, retained). A declaration is a claim, and §4's INV-4 is how it is held to.

---

## 4. The policy — four layers, and the invariants

### 4.0 Shape

| layer | question | mechanism | can it stop a running task? |
|---|---|---|---|
| **L0 root-cause defaults** | *is any single process allowed to run away?* | `-O ReleaseFast` for agent builds; `--rss-cap-mb` per process | yes — **only** the process that overran |
| **L1 declaration** | *what will this task need?* | `ram_mb` at registration (§3.3 defaults) | no |
| **L2 admission** | *does it fit what is free, given what is already admitted?* | the arithmetic below; refuse → row stays dispatchable | no |
| **L3 danger alarm** | *is the host actually in danger, and who is causing it?* | kernel pressure signal, dwell-gated, names the consumer, stops admitting | **no — never** |

The floor's safety role is split between **L0** (which is what actually answered 2026-07-29) and
**L2** (which bounds the fleet's total commitment *before* anything runs). L3 is observation and
back-pressure, not force. **Nothing in this policy kills a worker for a host-level condition.**

### 4.1 Admission arithmetic

```
committed = Σ(declared ram_mb of admitted, not-yet-exited tasks)
          + Σ(declared resident-model charges currently held)

admit  iff  host_avail_mb − committed − declared_ram_mb(candidate) >= RESERVE_MB
refuse otherwise — the row stays dispatchable and is re-tried when a lane exits
```

`RESERVE_MB = 4608`, and per **D081** it derives from a measured quantity, not from installed
hardware. **Derivation: the observed p95 of actual RSS in the heaviest duration band** (§3.2,
`≥ 1800 s`: p95 = 4574 MB → 4608 at the 256 MB rounding). The reserve's job is to absorb the worst
single **under-declaration** the corpus has ever produced, so that one task peaking past its
declaration never obliges the host to shed anything. Sizing it at one heaviest-task's measured p95
is that requirement stated as a number.

Three properties, each checkable:

- **It does not scale with `hw.memsize`.** A bigger host does not need a bigger untouchable slice;
  it needs more admitted lanes. Buying RAM must change how much work fits, not how much is
  reserved. (INV-5.)
- **It moves when the corpus moves.** `declared_vs_actual` records (ORC-GD-5) recompute the p95, so
  the reserve is a measurement with a refresh path rather than a constant with a birthday. Contrast
  §2.1: `total // 8` had no derivation to refresh.
- **Corroboration, not derivation:** the lowest real available reading anywhere in the corpus is
  **4247 MB**, observed with no host instability, and the panic condition was **46 MB** — so 4608
  also sits just above everything ever observed and ~100× above the cliff. Stated as a cross-check
  because it is an observation of a symptom, not of a need; the p95 is the derivation.

**The structural difference from the floor is not the number: it is that crossing the reserve causes
a refusal, and nobody dies for it.**

### 4.2 The four invariants, each with the arm that catches its violation

**INV-1 — no task dies for a process it does not conflict with.** *(the operator's core
requirement; hard invariant)* A running task may be stopped only for **its own** overrun of **its
own** declaration. A host-level condition caused by anything else — the `ollama` daemon, a browser,
a foreign compile, another tenant — is **never** grounds to signal an in-budget worker.
> **Arm (seeded):** inject a host reading at a danger level with a *foreign* consumer holding the
> memory and every fleet member inside its declared budget. Assert: **zero** signals sent to any
> worker, **one** alarm record naming the consumer and its RSS, admission closed.
> **Arm (null):** same fleet, no pressure → no alarm, no kill, admission open.
> *Post-hoc detector:* any run record with a guard-caused death whose peak RSS ≤ its declared
> `ram_mb` is an INV-1 violation, detectable from the record alone.

**INV-2 — no futile stop.** Every stop must be able to relieve what it targets. Under INV-1 the
only stop left is an overrun stop, which relieves its own overrun by construction — so INV-2 is
satisfied structurally rather than by a size comparison.
> **Arm:** the §2 census instrument, run over the post-change corpus, reports
> `kills_for_host_condition = 0` **and** `futile = 0`. `ORC-G10`'s null arm (no kills → rate
> *undefined*, never reported as 0 %) and seeded arm (one known futile + one known sufficient →
> 50 %) carry over unchanged. The existing red arm in `tests/unit/test_runner.py` (T785) becomes a
> deletion check: the selector it tests should not exist.

**INV-3 — memory is decided at admission, not during execution.** Before launch: does the declared
need fit? If yes, run and never re-litigate it on memory grounds. If no, **refuse and leave the row
dispatchable**. *Idle is acceptable; killing a running task is not* — T713's stance, generalised
from local lanes to every lane.
> **Arm (seeded):** declared needs that sum past `avail − RESERVE_MB`. Assert the last candidate is
> **REFUSED**, its row status is unchanged and dispatchable, **no process was spawned**, and **zero**
> signals reached any running task.
> **Arm (null):** needs that fit → all admitted, no refusals.

**INV-4 — a guard-caused death is labeled, and pressure is sustained before it is acted on.** The
only guard-caused death is an overrun stop; it writes an enumerated `killed_by` to the run record,
never silently. No response — stop or alarm — fires on a single sample: the shortfall or overrun
must hold across **3 consecutive polls spanning ≥ 2 s** (`ORC-G8` recommendation (a), retained; the
current guard fires on one 250 ms sample).
> **Arm (seeded, dwell):** a single-sample overrun spike that the next poll clears → **no stop**.
> A sustained overrun past the dwell window → stop, with `killed_by` present.
> **Fixture:** the T783 record (culled at `untracked/log/t783.log:102-103`, exited **1** at 88.1 s
> with no `killed_by`) is the known-bad this arm must catch.
> *Threshold:* a stop requires **> 125 %** of declared (`ORC-GD-5`'s recommendation, adopted);
> between 100 % and 125 % it is logged as `declared_vs_actual` and nothing else.

**INV-5 — no threshold is a fraction of hardware.** Every memory number in the fleet is either a
measurement with its corpus cited or a declaration with its reason logged.
> **Arm:** `S08` §10.5 **inverted** — accept fails a diff that *introduces* a
> `hw.memsize`/`total // N`-derived memory threshold.

### 4.3 When the real consumer is not ours to stop

L3 alarms; it never forces. Two cases, and they are different:

- **A resident model we asked for.** It is ours in the sense that matters: a task requested the
  load and is charged for it (§3.3's modifier). The release path is the model server's own unload,
  invoked by the admission layer when the last charging task exits — a **tenant release**, not a
  SIGKILL of a daemon. Identifying that call is a build-row item; the policy requires that the
  charge be released the same way it was taken.
- **A genuinely foreign consumer** (browser, Xcode, Spotlight, the operator's own work). We never
  signal it. The response is: **stop admitting, alarm loudly naming the consumer and its RSS, and
  surface it to the operator** — and then wait. This is a safe response precisely because L2 has
  already bounded the fleet's own contribution: the fleet cannot be the cause of a condition its
  own admitted commitments fit inside, so the correct action is always to hold, never to shed.

### 4.4 The danger signal — ask the kernel, not a fraction

The floor's `available < total // 8` is a homemade proxy for a verdict the kernel already computes
and publishes free:

| signal | reading now | meaning |
|---|---|---|
| `sysctl -n kern.memorystatus_vm_pressure_level` | **1** | 1 = normal, 2 = warn, 4 = critical — Jetsam's own verdict |
| `sysctl -n kern.memorystatus_level` | **90** | kernel's percent-free figure |
| `vm_stat` swapouts / compressor segments | — | the 2026-07-29 panic's actual signature was *"100 % of segments limit (BAD)"*, **not** a free-page count |

Live control, this host, right now: the runner's own `_host_avail_bytes()` returns **32515 MB**
while `Pages free` alone is **1651 MB** — a 20× spread between two defensible readings of the same
machine. That spread is the argument: a hand-rolled aggregate is a guess where the kernel ships a
verdict. **L3 reads `kern.memorystatus_vm_pressure_level ≥ 2`, sustained per INV-4, and reports the
compressor/swap figures alongside it.** The 2026-07-29 signature is what it watches for, because
that is the signature the one real incident actually had.

---

## 5. Where the kernel-panic risk goes

It does not vanish with the floor, and it is not left unassigned:

| the risk | who holds it now | sufficient? |
|---|---|---|
| one process balloons 40× normal (**the actual 2026-07-29 cause**) | **L0**: `-O ReleaseFast` default + `--rss-cap-mb` (12288, `tools/runner:2576`) | **Yes** — this is the mechanism the incident record itself names (B-2), it caught the case in the reference run at 4 GB with 5 s of slack, and it is per-process, so it is surgical by construction. |
| the fleet in aggregate over-commits the host | **L2 admission** (§4.1) | **Yes, and newly so.** Nothing held this before: the floor was a *reaction* to over-commitment, never a bound on it. L2 makes over-commitment unreachable rather than survivable. |
| a foreign consumer puts the host in danger | **L3 alarm** (§4.3, §4.4) | **Partly, by design.** We cannot fix someone else's memory use and must not try. What we can guarantee is that we stop adding to it and that we name it. |
| a task exceeds what it declared | **L0 cap + INV-4 overrun stop** (>125 %) | **Yes** — and the overrun is recorded as `declared_vs_actual`, feeding the corpus §3's defaults came from, so a bad default gets fixed instead of re-guessed. |

**The last-resort backstop that survives** is L3, and it is constrained by all three of the brief's
conditions: (a) it **names the true consumer**, (b) it **never** kills a worker inside its declared
budget (INV-1), and (c) it **requires dwell** (INV-4). It has one verb — *stop admitting and
alarm* — and no kill verb at all.

---

## 6. What to delete

A redesign that only adds is not a redesign. These go:

| # | thing | file / anchor | disposition |
|---|---|---|---|
| 1 | **the `host_total // 8` derivation** — named explicitly per **D081** | `tools/runner:2807` | **delete outright; do not re-tune the divisor and do not preserve the form.** Refuted in §1 (fires 133× from the cliff, 22 days after the panic it cites) and unprovenanced in §2.1 (*"an eighth of RAM felt safe"* is the whole of it). Every replacement threshold in this policy derives from a measured quantity — the p95 of actual RSS (§4.1), the sum of declared needs in flight (§4.1), or the compressor-segment limit that actually failed in 2026-07-29 (§4.4) — never a fraction of installed hardware (INV-5). |
| 2 | the whole host-floor comparison path | `tools/runner:3198-3275` | **delete** — the only code path that kills a worker for a foreign process (INV-1) |
| 3 | `--host-mem-floor-mb` / `--no-host-guard` flags | `tools/runner:2582,2591` | **delete** — no floor to set or disable |
| 4 | largest-member kill selection | `_select_host_guard_victim`, `tools/runner` | **delete** — with no host-condition kill there is no victim to select. **T785's pending fix is moot**: do not repair the selector, remove it. Its red arm in `tests/unit/test_runner.py` becomes a deletion check. |
| 5 | T711's tenant **add-back** to the available reading | `tools/runner:3224-3225` | **delete** — it existed only to stop the floor mis-firing; with the floor gone the add-back has no consumer. The tenant **charge at admission** (§3.3 modifier) survives; the two halves of ORC-G3 collapse to one. |
| 6 | the tenant auto-detect `ps` scan as a **decision input** | `_sum_mlx_tenant_bytes`, `_declared_tenant_reservation_bytes` | **demote** — retained as a labeled `sample` diagnostic only. It is non-monotone and under-reports ~2×; the charge comes from the registry declaration. D1's startup race becomes structurally impossible, not merely better-timed. |
| 7 | `WEIZIGO_HOST_TENANT_RESERVATION_MB` as the path that stood in for the measurement | `tools/runner`, `bin/subagent` | **retire the role, keep the hook** — T714's D2 defect was a control injecting what it should have measured. The declaration is now the production path, so the injection is a test hook and nothing more. |
| 8 | `MEMORY_GATE_MARGIN_MB = 2048`, `LOCAL_LANE_COST_DEFAULT_MB = 16384` | `bin/subagent:232-233` | **delete** — replaced by the declared `ram_mb` (18432 from the registry) and the one named `RESERVE_MB`. Two unexplained constants become one derived one. |
| 9 | `_lane_is_memory_heavy` provider-shaped special case | `bin/subagent` | **delete** — every lane declares; there is no heavy-lane class. This is what generalises T713 from local models to the whole fleet. |
| 10 | `--override-memory-gate=<reason>` | `bin/subagent:21-27` | **keep, rename** — it becomes the declaration override of §3.3, and its reason is logged rather than merely accepted. |

Kept, unchanged, and load-bearing: `-O ReleaseFast` default, `--rss-cap-mb`, the wall/CPU/progress
watchdogs, the reap paths. **Amendment to the cap:** where a declaration exists, `--rss-cap-mb`
defaults to `ceil(declared ram_mb × 1.25)` (INV-4's threshold), falling back to 12288 when there is
none — the per-process cap becomes the enforcement arm of the declaration instead of a second,
unrelated global constant.

---

## 7. Disposition of `S08` normative ids

One source, so the build sprint does not have to adjudicate two specs.

| id | `S08` says | this policy | why |
|---|---|---|---|
| **ORC-G1** refuse before kill | refuse first, kill is last resort | **RETAINED, strengthened** | refusal becomes the *only* response to a host condition; the last-resort kill verb is removed (§4.2 INV-1) |
| **ORC-G2** no futile kill | compare victim RSS to shortfall | **RETAINED as invariant, mechanism retired** | with no host-condition kill there is no comparison to make; §2's census survives as the historical instrument |
| **ORC-G3** charge memory to the causing lane | two halves: T711 accounting + T713 admission | **AMENDED** | admission half retained (§3.3, §4.1); pressure-accounting half deleted with the floor. The "two questions, never one formula" corollary collapses — only *can it fit?* remains |
| **ORC-G4** sample the tenant before admitting | pre-admission probe or declaration | **SUPERSEDED in mechanism** | no sampling at any time; the charge is a registry declaration, so D1's race cannot occur rather than being merely re-timed |
| **ORC-G5** one arbiter | one component owns admission + pressure response | **RETAINED, scope narrowed** | the arbiter owns admission; there is no pressure-response decision left to unify. *Correction to §2's premise:* `tools/fleet-keeper.sh` has **no memory logic at all** (verified at HEAD) — its `pressure.json` is contention only, so the split was two ways, not three |
| **ORC-G6** sealed inputs immutable | content hash at seal/grade | **UNAFFECTED** | not a RAM id |
| **ORC-G7** guard-caused death is labeled | every guard death writes `killed_by` | **RETAINED, narrowed** | the only guard death left is an overrun stop and it must be labeled; deleting the cull path (§6.2) removes the unlabeled path structurally, not by adding a write |
| **ORC-G8** dwell before acting | 3 polls / ≥2 s / min shortfall | **RETAINED, re-pointed** | dwell now governs the overrun stop and the L3 alarm; recommendation (a) adopted. Minimum-shortfall is dropped — there is no shortfall term left |
| **ORC-G9** tenant is a stable declaration | high-water mark, print the source | **RETAINED in principle, mechanism replaced** | high-water-over-lifetime retired for the registry declaration; the `source` label survives and gains `registry` |
| **ORC-G10** futile-kill rate measured | census instrument, accept at 0 futile | **RETAINED, target strengthened** | accept becomes `kills_for_host_condition = 0` **and** `futile = 0`; null/seeded arms unchanged |
| **ORC-GD-1** declared-need block | `ram_mb` required at registration | **RETAINED unchanged** | this policy is built on it |
| **ORC-GD-2** default from task type + provider | per-provider table | **AMENDED** | provider keying **refuted by measurement** (§3.1: all providers converge, p95 ≈ 3.2 GB). Replaced by the duration-band derivation keyed to task type (§3.2–3.3). The resident-model rule and the `ceil(p90/256)` rounding **survive** (rounding re-pointed to p95, p99 for T-H) |
| **ORC-GD-3** admission arithmetic | formula with `floor_bytes (total // 8)` | **AMENDED** | formula retained; `floor_bytes` → `RESERVE_MB` (§4.1: derived from the measured p95 of actual RSS, not a hardware fraction); the tenant term becomes a declaration |
| **ORC-GD-4** the backstop is unchanged | floor survives as machine backstop | **RETIRED** | the backstop is *not* unchanged: the floor is removed and replaced by a kernel-signalled, kill-free alarm (§4.4). This is the one id the operator's ruling directly overturns |
| **ORC-GD-5** overrun is a declaration defect | log it; 25 % stop threshold `[design-open]` | **RETAINED and promoted** | it is now the **only** path to stopping a running task; the 25 % recommendation is **adopted** and wired to `--rss-cap-mb` (§6) |
| **§3** *"Raising the floor. Forbidden"* | out of scope, forbidden | **RETIRED** | operator ruling 2026-08-23 (§0). The floor is not raised — it is removed |
| **§10.5** accept fails a diff touching `total // 8` | accept gate | **INVERTED** | accept now fails a diff that *introduces* a hardware-fraction memory threshold (INV-5) |
| **§2a** *"the floor's value does not move"* | resolution of T803 | **SUPERSEDED** | T803 changed the floor's role and preserved its value; this policy removes it. T803's admission design is otherwise adopted wholesale — it did the work this row builds on |
| **ORC-GP-3** pass order | pass 2 = runner guard repair | **AMENDED** | pass 2 becomes a **deletion** pass (§6 items 1–6); pass 3 (`bin/subagent` admission) becomes the primary build. Deleting before building is cheaper and removes INV-1's violation path first |
| **T785** selector fix | repair `RSS >= shortfall` | **MOOT** | §6.4 — remove the selector rather than repair it |
| **T712** one arbiter | folded into ORC-G5 | **NARROWED** | admission-only arbiter |
| **T715** incident record | owed the design doc's content | **DISCHARGEABLE from §1** | §1 is the re-read T715 was to place; it now also records that the mechanism it documented is retired |

---

## 8. What this policy would have done, on both dates

**On 2026-08-23 15:19:09** — four lanes launched together: three cloud Race W judges and one
`qwen3.8:27b-mlx`. Each judge declares **4608 MB** (T-A/T-F at the ≥1800 s band) and the qwen lane
declares **18432 MB** (§3.3's resident modifier, read from the registry at registration, before any
process exists and depending on no `ps` sample). Available before the qwen loaded reconstructs to
**≈24193 MB** (the observed 5761 MB at kill time plus the ~18 GB the engine then held). Running
§4.1's test — `avail − committed − candidate >= RESERVE_MB` with `RESERVE_MB = 4608`: the qwen lane
is **admitted** (`24193 − 0 − 18432 = 5761 >= 4608`), and the first judge is already **refused**
(`24193 − 18432 − 4608 = 1153 < 4608`), as are the second and third. **One lane admitted, three
left dispatchable, zero kills.** All four 88-second deaths — the three at 251, 133 and 129 MB and
T783's unlabeled cull — do not happen: three of those lanes were never running, and the qwen lane
was inside its declared budget and therefore untouchable (INV-1). The 18 GB consumer is not "untouched because the guard cannot see
it" — it is *charged to the task that asked for it* and is the reason the batch did not fit.

**On 2026-07-29 02:37** — a `zig build-exe -O Debug` balloons to 12.5 GB RSS / 21.8 GB peak inside
an agent lane. L0 acts first and alone: the build would have run `-O ReleaseFast` by default (the
root cause, `docs/infra/runner.md:14-15`), and had it ballooned anyway, `--rss-cap-mb` bounds
**that process** — the incident record's own arithmetic puts the catch 5 s before the cliff at a
4 GB cap, and today's cap is 12288 MB. L2 would additionally have refused to admit further lanes
alongside a task declaring a heavy build. L3 would have read
`kern.memorystatus_vm_pressure_level = 4` and the compressor at *"100 % of segments limit"* — the
panic's actual signature — closed admission, and named `zig pid 92604` at 12.5 GB in the alarm.
**The floor, at 6144 MB free, would have fired somewhere in the descent from 48 GB to 46 MB and
killed the largest member of some runner's process group; on the corpus's evidence it would have
been a 40–389 MB agent lane, not the 12.5 GB compiler — futile, and the panic would have happened
anyway.**
