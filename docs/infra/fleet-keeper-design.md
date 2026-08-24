# Fleet keeper — the logjam-pressure mechanism (authoritative algorithm)

**Author:** T500 (spec task) · deepseek-v4-pro · 2026-08-20
**Status:** the keeper's authoritative algorithm. T496 (the fleet keeper) incorporates this;
its `tools/fleet-keeper.sh` is amended to match. This document **supersedes** the
logjam-escape in D022 item 3 (and the code it produced).

**Landmark:** advances `L1 (the dashboard tells the truth)` — a fleet that can deadlock on file
locks cannot be trusted to keep PROGRESS populated.

---

## 1. What this supersedes (and why)

The first design — recorded in the D022 amend (2026-08-19T23:07:31Z) and implemented in
`tools/fleet-keeper.sh` — was:

> "…a task whose needs are met but whose holds are all held by OTHER tasks must still eventually
> run. Rule: if the highest-priority eligible task's holds are all held by running tasks, and it
> has waited > N minutes, the keeper may dispatch it anyway with a warning in the log …"

The operator **rejected** that design (2026-08-20 01:07 local):

> *"The first design — 'if a task's holds are all held by others and it has waited > N minutes,
> dispatch it anyway with a warning' — was rejected by the operator because it violates the
> one-writer rule. Holds are advisory at the keeper level but the files themselves are not: two
> consoles writing `src/retro.zig` corrupt silently. The keeper must never dispatch a task whose
> holds conflict with running tasks."*

The pressure mechanism replaces the escape. It **never** dispatches a conflicting task; instead
it shrinks the fleet until the blocked task can run.

D022 items 1 and 2 are **kept unchanged**: the model-cooldown window
(`FLEET_MODEL_ALLOW` / `FLEET_MODEL_DENY`) and the priority number (`priority=N` in the bundle
header, 0–99, default 50, tie-break by `added`). Only item 3 (the escape) is superseded.

## 2. The operator's design (verbatim, 2026-08-20 01:07)

> "Somehow a task which has been waiting becomes impatient and puts pressure on the delegator to
> cool down parallel delegation so that the long-waiting task can soon run independently.
> Additional tasks may then run only if compatible and conflict free (perhaps no holds)."

And the concrete variant:

> "the new parallel task cap drops from until long-waiting blocked high priority tasks are able
> to run. Then the new parallel task cap resets (to 10 or 5) until another 'next' task is blocked,
> afterwhich the new parallel task cap drops by one each for each task that completes and any
> 'next' task is blocked."

This document turns those words into exact state, arithmetic, and eligibility tests.

## 3. The one-writer invariant (the bar every rule is checked against)

> **The keeper never dispatches a task whose holds intersect the holds of any `in_progress`
> task.**

This is the operator's non-negotiable. `managent claim` already enforces it downstream
(`holdsConflict`, `src/managent/main.zig`), but the keeper must enforce it **before dispatch** —
a dispatch of a conflicting task is rejected at claim and wastes a worker. Holds are advisory at
the keeper; the files are not. Every mechanism below is checked against this invariant.

## 4. Definitions

| Term | Definition |
|---|---|
| `running` | every task whose derived status is `in_progress`. |
| `inprog_holds` | the union of `holds` over all `running` tasks. |
| `eligible` | a task whose derived status is `dispatchable`, whose id matches `T\d+` (not a duty, not a `ORCHA-*`/`STANDING-*` seat), which has exactly one bundle (`untracked/<id>-*.md`), and whose resolved model passes the model gate (§9). |
| `holds-free` | a task with an empty `holds` list (ANALYSIS in `ROLES.md` §Concurrency terms). |
| `mutation` | a task with a non-empty `holds` list. |
| `conflict-free` | a task whose `holds ∩ inprog_holds = ∅`. (Every holds-free task is trivially conflict-free.) |
| `conflict-blocked` | a task that is **not** conflict-free: `holds ≠ ∅` and `holds ∩ inprog_holds ≠ ∅`. |
| `next` | the first task in the eligible ordering (§5). |
| `blocked next` | the `next` task, when it is conflict-blocked. |

**Only a mutation task can be a `blocked next`.** A holds-free task is never conflict-blocked, so
pressure is always anchored by a mutation; ANALYSIS tasks are always conflict-free and never
trigger pressure.

## 5. Ordering — priority and the bump

Each eligible task has an **effective ordering key**, in descending preference:

1. `waiting` — the bundle-header boolean `waiting=1` first, everyone else after. This is the
   operator's "bump": marking a task `waiting=1` makes it *next* regardless of its priority
   number. (Satisfies the brief's "so that we can bump tasks to be next".)
2. `priority` — the bundle-header number `priority=N`, 0–99, 99 highest, **default 50** when
   absent or unparseable (D022 item 2). Read from the bundle header like T496's `priority_of`;
   clamp out-of-range to 50.
3. `added` — ascending (oldest first); resolved via `managent show <id>` (the public CLI, not the
   store schema — T496's `added_of`).

Both flags live in the bundle `<!--managent …-->` header as extra keys (`managent add` ignores
keys it does not know, so `priority=` and `waiting=` are safe there; keep `acceptance=` **last**
per T217). No store change, no engine change.

## 6. The state machine

Two states, one persistent record.

**Persistent state** — `untracked/fleet-keeper.pressure.json`:

```json
{
  "anchor": null,         // id of the current blocked-next, or null (NORMAL)
  "drops": 0,             // completions counted while `anchor` stayed blocked
  "waiting_since": null,  // ISO timestamp the current anchor FIRST became blocked (telemetry)
  "running": []           // the in_progress id set as of the previous iteration
}
```

- **NORMAL** = `anchor == null`; effective cap `C_eff = C` (`C` = `FLEET_CAP`, default **5**).
- **PRESSURED** = `anchor != null`; effective cap `C_eff = max(1, C − drops)`.

**Entry.** First iteration where a `blocked next` exists. `anchor = blocked_next.id`,
`drops = 0`, `waiting_since = now`. The entry iteration's own completions are **not** counted —
`drops` starts at 0 (deterministic "drops start at entry" rule; avoids counting the completion
that just *enabled* the blocked task).

**The drop rule.** Each subsequent iteration while the **same** anchor remains the blocked next:
`drops += |completed|`, where `completed` is the set of ids that left `in_progress` since the
previous iteration (`prev.running − running`). This is the operator's "drops by one each for each
task that completes and any 'next' task is blocked."

**Exit / reset.** The first iteration where there is no `blocked next` (the anchor's holds have
all freed, or it left the eligible set): `anchor = null`, `drops = 0`, `waiting_since = null`,
`C_eff` back to `C`. **Immediate** — no ramp, no hysteresis. The cap jumps back to `C` and the
fleet refills; if the refill immediately creates a new blocked next, pressure re-enters from
`drops = 0`. That self-correction is intended, not a bug.

**Anchor change without exit** (rare: the anchor leaves the eligible set — purged, bundle gone,
or model denied — while a *different* task is the new blocked next): re-anchor — `anchor = new id`,
`drops = 0`, `waiting_since = now`. A fresh blockage gets a fresh pressure epoch; the previous
anchor's cooling credit is not carried over.

**Persisting `running`.** `running` is written to the record **every** iteration (including
cooldown), so `completed` is the honest diff of who left `in_progress`. Under cooldown (§8) the
keeper updates nothing else and dispatches nothing, but the snapshot still advances.

## 7. The drop rule, precisely — arithmetic and the floor

```
C_eff = C                                  if anchor == null
C_eff = max(1, C − drops)                  if anchor != null
drops = 0 on entry; drops += |completed|   each iteration the same anchor is still blocked
```

**Floor at 1.** Not at "the number of holds the blocked task needs." Reasons:

1. **Necessity.** A cap of 0 deadlocks the keeper: `|running| >= C_eff` is always true, so even
   the freed anchor could never be dispatched. The cap must leave at least one slot for the
   blocked task to run into once its holds free.
2. **Sufficiency (the arithmetic bottoms at 1 by itself).** The anchor is freed exactly when its
   last remaining holder leaves `in_progress`; that freeing completion makes the anchor the
   non-blocked `next`, so the *next* iteration is an exit (`drops = 0`), not a drop. Therefore
   `drops` counts only completions that occur while the anchor is **still** blocked — at most
   `(running at entry − 1) ≤ C − 1` of them. Hence `C − drops ≥ 1` under the keeper's own cap
   invariant (`|running| ≤ C`). The explicit `max(1, ·)` is the safety net against the rare case
   where a *manual* dispatch pushes `|running|` above `C`.
3. **Why not "number of holds"?** The cap is measured in **running-task slots**, not files. A
   task holding three files via a *single* running holder is freed when that one holder
   completes; a floor of 3 would keep the fleet at 3 for no reason. Holds are files; the cap is
   tasks; a file-count floor mixes the units.

**Why the drop is not what frees the anchor.** The anchor is freed by its *holders* completing,
never by the cap. The drop is a **rate limiter on new admissions**: it stops the freed slots from
being refilled with fresh parallel work, so the fleet cools toward the anchor's holders and the
anchor eventually runs near-solo. This distinction matters for §10.

## 8. Dispatch under pressure

Precedence, each iteration:

1. **Cooldown** (`untracked/fleet-keeper.cooldown` present, or its directory unreadable — the
   dead-man's switch): dispatch nothing; update the `running` snapshot; do nothing else.
2. Compute `eligible`, `next`, `blocked next`, then the pressure bookkeeping of §6.
3. **Cap.** If `|running| >= C_eff`, dispatch nothing.
4. **Candidate eligibility test** — a candidate must satisfy **both**:
   - `candidate.holds ∩ inprog_holds = ∅` — the one-writer invariant (§3), always;
   - `candidate.holds ∩ anchor.holds = ∅` — compatibility with the blocked task, **only when
     `anchor != null`**. (This second test is not fully subsumed by the first: the anchor may
     hold `{a, b}` while only `{a}` is held by a running task; a candidate holding `{b}` would
     pass the running-holds test yet plant itself as the anchor's *next* blocker.)
   In NORMAL state only the first test applies.
5. **Order candidates** by the §5 key and dispatch the first. If none, dispatch nothing
   (logjam — §10).

Consequences, stated plainly:

- The anchor itself is never a candidate while blocked (its holds intersect `inprog_holds` by
  definition); it becomes a candidate the moment its holds free, and being `next`, it is
  dispatched first.
- A holds-free (ANALYSIS) task passes both tests trivially, so **"additional tasks may run only
  if compatible and conflict-free (perhaps no holds)"** is satisfied as a *consequence*: under
  pressure the freed slots refill with analysis, never with a mutation that touches the anchor's
  files. No separate "prefer holds-free" rule is needed.

## 9. Impatience model — completion-driven (recommended), argued

**Recommendation: completion-driven only.** "Becomes impatient" is realised as *pressure* (the
fleet cools), not as a timeout. The only event that moves the state is a task leaving
`in_progress`.

- **It is the operator's exact arithmetic** — "drops by one each for each task that completes."
  A clock would be a second mechanism he did not ask for in the drop rule.
- **The one case completion-driven cannot handle** — a single long-running holder that will not
  complete for hours — is the logjam of §10, which has its **own** escape (an operator-facing
  flag, human in the loop). Folding a time component into the cap-drop would be a *redundant*
  second mechanism for the same case, and it would cost a clock in the tests.
- **Deterministic tests.** The TDD bar (red-first) is cheap when the only input event is "a task
  left `in_progress`" (seed the store, delete a running row, iterate). A time-driven drop needs
  clock injection or real sleeps.

The only clock in the whole mechanism is **telemetry** (`waiting_since`, for the §10 flag). It
never feeds a dispatch decision.

## 10. Logjam = nothing conflict-free (the long-holder case)

If the anchor's holds are held by a long-running task that will not complete for hours, the cap
drops to 1 and stays there; the fleet runs that one holder and nothing else. Cap-drop alone
never frees the anchor — this is the honest, documented worst case.

**Recommendation: option (c) — a holder-timeout that *flags* the holder for operator review,
plus option (b) — the human decides. Option (a) is the baseline until the human acts. No silent
preemption.**

- **Flag threshold** `FLEET_LOGJAM_FLAG` (minutes, **default 60**). While `anchor != null`, if
  `now − waiting_since >= FLEET_LOGJAM_FLAG × 60`, the keeper writes
  `untracked/fleet-keeper.logjam.flag` (one line per anchor: id, held files, per-file holder ids,
  waited minutes) and logs a `LOGJAM:` line every iteration thereafter. It **still dispatches
  nothing conflicting** — the flag is telemetry, not an override.
- **The human acts.** The flag directs the operator to the holder; he uses the existing manual
  verbs (`bin/managent reopen`/kill, or pausing the holder) to unblock — option (b). The keeper
  never kills, pauses, or reopens anything itself (no silent preemption).
- **Documented worst case** (option a) — if the operator does nothing, the anchor waits
  **unboundedly** (until the holder completes). The fleet, meanwhile, is deliberately cooled to
  that single holder: this is the operator's chosen "cool down so the long-waiting task can soon
  run independently", not an accident.

**Operator-visible signals that a task is waiting** (so he can intervene):

1. `untracked/fleet-keeper.pressure.json` — machine-readable: `anchor`, `drops`, `waiting_since`.
2. `untracked/log/fleet-keeper.log` — every pressured iteration logs
   `pressure: T100 blocked on {a,b} — drops=3 cap=2 (a←T50, b←T51)`.
3. `untracked/fleet-keeper.logjam.flag` — appears once a task has waited `FLEET_LOGJAM_FLAG`
   minutes; the loud, greppable artifact.
4. `bin/managent status` — the blocked task is visible as `dispatchable` with its `holds`, and
   the status "held files" map shows which running task holds each path.

## 11. Interaction with the model cooldown (FLEET_MODEL_ALLOW / FLEET_MODEL_DENY)

The model gate is applied **inside `eligible`** (D022 item 1), so it binds the pressure path too:

- A candidate whose resolved model is denied/not-allowed is never in the candidate pool — a
  pressured dispatch never fires a denied model.
- If the **anchor's own** model enters the deny window, the anchor leaves the `eligible` set, so
  there is no `blocked next` and pressure exits (the cap resets). The cooldown window is the
  operator's explicit override and outranks the pressure mechanism. When the window opens, the
  anchor re-enters `eligible`; if still conflict-blocked, pressure re-enters from `drops = 0`.

## 12. Environment and state (complete list)

| Name | Default | Meaning |
|---|---|---|
| `FLEET_CAP` | 4 | base cap `C` (5 was the committed value, operator's 2026-08-19 ruling; **T845 proposes 4** — the 2026-08-24 ruling asks for more serial execution, and bin/dispatch now enforces the same number from the shared tools/fleet_caps.py; derivation in that file's docstring, pending operator ratification). |
| `FLEET_FAMILY_CAP` | `claude=3,fable=1,ollama=5` | per-family concurrent-lane cap `"family=N"` (T651 §7c.33; ollama added T845 — the provider's recorded five-worker ceiling; unlisted = uncapped). |
| `FLEET_INTERVAL` | 10 | seconds between iterations. |
| `FLEET_DEFAULT_MODEL` | glm-5.2 | model for rows with no stored model. |
| `FLEET_MODEL_ALLOW` | unset | comma list of canonical models allowed (unset = all). |
| `FLEET_MODEL_DENY` | unset | comma list denied; wins over ALLOW. |
| `FLEET_LOGJAM_FLAG` | 60 | minutes after which the waiting anchor is flagged (telemetry only). |
| `FLEET_ROOT` | repo | working dir for `untracked/` (scratch dir in tests). |
| `FLEET_TEST_WORKER`, `MANAGENT_STORE` | — | test-only (scratch store + `--test-root` isolation, T427/T476). |
| *(removed)* `FLEET_LOGJAM_WAIT` | — | superseded by the pressure mechanism; the escape it fed is gone. |

State file: `untracked/fleet-keeper.pressure.json` (§6). Superseded file
`untracked/fleet-keeper.logjam.json` is removed.

## 13. Controls (red-first, scratch store + scratch repo, wired into `zig build test`)

All arms run on a scratch store + scratch repo (`MANAGENT_STORE` + `FLEET_ROOT` +
`bin/dispatch --test-root`, per T427/T476) — never the live queue. Seeded arms must be seen red
before the implementation exists; the flag arm seeds a stale `waiting_since` (no sleeping).

| # | Arm | Seed | Expect |
|---|---|---|---|
| a | **drop-then-solo** (seeded) | cap 5, five running (`R1{a},R2{b},R3,R4,R5`), `T100` priority 99 holds `{a,b}` → blocked next. Complete R3,R4,R5,R1 one at a time. | Each completion while `T100` still blocked: `drops` +1, `C_eff` falls 5→4→3→2→1, nothing dispatched. When R2 completes, `T100` frees and is dispatched **solo** (cap resets to 5). |
| b | **conflict-free still runs** (seeded) | cap 5, one running `R1{a}`, `T100` holds `{a}` (blocked next), plus `T200` (holds-free, priority 50). | While pressured, `T200` is dispatched up to the reduced cap (holds-free passes both tests). |
| c | **conflict never dispatches** (seeded) | cap 5, running `R1{a}`, `T100` holds `{a}` blocked, `T300` holds `{a}` (also blocked). | `T300` never dispatches under pressure — its holds intersect `inprog_holds` (and `anchor.holds`). |
| d | **no blocked next → cap stays C** (null) | cap 5, no conflict-blocked eligible task. | `C_eff = 5`, normal refill. |
| e | **holds free → immediate, no pressure** (null) | `T100` holds `{a}`, nothing running holds `{a}`. | `T100` dispatches immediately; `pressure.json` stays NORMAL. |
| f | **model cooldown binds pressure** (null/seeded) | `FLEET_MODEL_DENY` includes `T200`'s model; arm b's fixture. | `T200` not dispatched; if the anchor's model is denied, pressure exits. |
| g | **logjam flag** (seeded) | seed `waiting_since` 61 min old, `FLEET_LOGJAM_FLAG=60`. | `fleet-keeper.logjam.flag` written; nothing conflicting dispatched. |
| h | **bump** (seeded) | `T400` priority 20 `waiting=1`, `T500` priority 99. | `T400` is `next` (waiting outranks priority); if `T400` is conflict-blocked it anchors pressure. |

## 14. What the implementing worker does (T496's amendment)

1. Replace the D022 item-3 escape block in `tools/fleet-keeper.sh` with the §6–§8 state machine:
   persist `pressure.json`, compute `completed` from the `running` diff, apply `drops`/`C_eff`,
   and use the two-test candidate filter (§8). Remove the `LOGJAM_WAIT`/`logjam.json` machinery.
2. Add `waiting=1` parsing beside `priority=N`.
3. Add the `FLEET_LOGJAM_FLAG` telemetry (log line + flag file); no dispatch changes.
4. Extend `tools/regression-fleet-keeper.sh` with arms a–h (§13), red-first, on the scratch
   store/repo, and keep it wired into `zig build test`.
5. Update `docs/infra/duties.md`'s `DFLEET` row to cite this document as the dispatch algorithm.
6. `sh -n` clean; the keeper still survives a worker completing; still never dispatches a duty or
   a non-`T` seat; the cooldown dead-man's switch is unchanged.

## 15. Honest worst case

- **A blocked mutation waits until its last holder leaves `in_progress`** — unbounded in wall
  time (the holder may run for hours). The fleet cools to that holder (`C_eff` falls to 1) and
  adds no new conflicting work.
- The wait is **not silent**: §10 lists four operator-visible signals, and after
  `FLEET_LOGJAM_FLAG` minutes the flag file names the holder for manual review.
- The one-writer invariant (§3) is never violated at any point: the keeper dispatches only
  tasks whose holds are disjoint from every running task's holds, in both NORMAL and PRESSURED
  states.
