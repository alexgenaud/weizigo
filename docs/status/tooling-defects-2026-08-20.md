# Tooling and process defects found 2026-08-20 — the durable inventory

**Author:** Orchestrator seat (opus). **Why this file exists:** the operator asked whether the
day's many findings were being recorded. Auditing that honestly surfaced a problem with *how*:
a significant number of them existed only inside `managent tell` directives and git commit
messages. Directives are the channel this same day proved **loses messages** (`T545`), and a
commit message is not a work queue. So findings were being filed into a lossy channel and a
non-searchable one. This file is the durable inventory; it supersedes nothing and drops nothing.

**Status key:** ROW = has a registered kanban row · SPRINT = an item in
`docs/status/sprint-2026-08-20.md` (`T540`) · **UNOWNED** = found, recorded here, no owner yet.

## A. Registered rows (closed today)

| id | defect | verdict |
|---|---|---|
| `T536` | keeper re-fires a row whose worker died pre-claim — 80 dispatches into a 429 wall in 3.5 min | pass-with-findings |
| `T537` | `ACCEPTANCE PASS` counted only FAIL verdicts, so AC2/AC6/AC7 warnings passed silently; AC7 was a cumulative-ever counter labelled "today" | pass |
| `T538` | provider 429 refusals recorded as model failures (~80 poisoned ledger records) | pass-with-findings |
| `T539` | `holds=` in a bundle header is parsed by **nothing**; the one-writer invariant was inert across 34 rows | pass |
| `T540` | the cleanup/bug-hunt sprint itself (9 swept items) | pass-with-findings |

## B. Registered rows still open (all reverted to dispatchable by the rc=124 cohort — re-dispatch)

| id | defect |
|---|---|
| `T541` | the 2026-08-20 suite-truth run is contaminated (ran against a live fleet); needs a quiet re-run before the manifest is ratcheted |
| `T542` | bakeoff race gates: G1 tokens, G2 isolation-refusal, G3 family exclusion, G4 blinding all unimplemented (only G5 was) |
| `T543` | race official for the seven sealed aspect packets (not a defect — the work) |
| `T544` | model attribution: 152/193 closed rows null, 96 unrecoverable, and rows **actively mis-attributed** (haiku/fable/sonnet work credited to flash) |
| `T545` | three store writers take no flock (`cmdTell`, `main`'s migration write, `registerStanding`) — a whole-file write reverts concurrent claims/closes |

## C. Sprint items (owned by `T540`, carried here so they survive that row's close)

1. Mutating verbs silently ignore unknown flags — `managent next --peek` **claimed a row**.
2. The keeper keeps its own hardcoded model list with no Claude labels (`fleet-keeper.sh:247`) — the other half of audit F7, now also a race-data bias.
3. Misleading pre-commit diagnostic: "kanban unreadable or empty" when the kanban was readable and `holds` was merely empty.
4. `managent suggest` mints a row whose header nothing validates.
5. Walls are set by the dispatcher's guess; the `wall-low` advisory arrives *after* dispatch.
6. `untracked/runs/` straggler reconciliation (closed: 43 files = 40 task-id-named + 2 fixtures + 1 pid-named; the asserted "30" did not reproduce).
7. `directives.jsonl` accumulates blank lines.
8. Running-script rewrite hazard — `bash` reads a script incrementally, so rewriting `fleet-keeper.sh` while it runs can execute a partial file.
9. A naive single-instance guard false-positives: `pgrep -f fleet-keeper` returned 2 while zero keepers ran (it matched worker briefs).

## D. UNOWNED — found today, no row yet. **This section is the sprint's input.**

1. **`pause` is `kill`.** `tools/runner:316` — `stops = [d for d in pending if d.get("directive") in ("pause","kill")]`. There is no graceful suspend: a `pause` directive SIGKILLs the worker and discards its context. The seat sent `pause` to `T544` believing it was graceful and destroyed the run (`[runner] KILL: directive D047 PAUSE`). Either implement real suspend/resume, or rename the directive so it cannot be mistaken for one. **The operator asked for exactly this capability today and it does not exist.**
2. **No resource-aware admission.** *Measured cost of one suite-running row, 2026-08-20 16:56: `T524` alone held three live test binaries totalling ~7.0 GB (2918 + 2915 + 1156 MB).* So a single row can consume more than the runner's entire 6144 MB host-floor headroom, and two such rows exceed any plausible margin on a 48 GB desktop shared with ordinary applications. That is the number the fix needs: admission must know that a suite row is worth ~7 GB and a text edit ~60 MB — the observed victims of the day's culls had RSS of 56–87 MB. The fleet cap counts *workers*, not resource weight. Several workers each launched the full suite; four `zig test` binaries at ~6.5 GB drove the host below the runner's 6144 MB floor and **12 workers were culled with rc=124**, every one recorded as a model failure. Needs: weight-aware admission, and a mutex on concurrent full-suite runs.
3. **`rc=124` is unclassifiable.** `T538`'s classifier keys on provider error text; a host-pressure kill has none, so infrastructure deaths score as model failures. Extend to `rc=124` + a runner `KILL: host memory pressure` line → `verified=unreached reason=host-memory-pressure`.
4. **`bin/dispatch` writes neither `model` nor `dispatched_to`.** The store keeps whatever was last set, which is how haiku/fable/sonnet work came to be credited to flash. Folded into `T544` by directive — recorded here because that directive may have been lost.
5. **`bin/subagent:260` hardcodes `--output-format text` for Claude lanes**, so the JSON usage envelope never exists and token counts are lost at dispatch, irrecoverably (G1 is run-time, not retroactive — Fable's correction). Relayed to `T521` by directive only.
6. **Orphaned suite runs survive their console.** Two `zig build test` trees were reparented to init and still holding 4.5 GB; the DARGUS doctor chunk found six more of the same class earlier the same day. The doctor detects them — nothing prevents or reaps them automatically.
7. **A malformed findings JSON halts the entire fleet's commits.** `findings/DARGUS-chunk.json` had a literal newline inside a string; claimlint's C7-nonconforming floor is 0, so the pre-commit hook refused *every* commit repo-wide until a worker fixed it. Needs validate-on-write in the duty/findings harness.
8. **`managent tell` reports success for a directive that never landed.** Covered by `T545` item 4, listed separately because it is the reason this file exists.
9. **Directive IDs collide with historical ones.** `D041/D042/D043` each exist twice with different targets. Consequence of `T545`'s lost updates, but the *existing* duplicates need reconciling — an ID is a reference, and a duplicated one breaks the audit trail.
16. **Killed workers orphan their `zig build test` children, which keep multi-GB test binaries alive — and that makes the next cull more likely.** Observed **three times** on 2026-08-20: the DARGUS doctor chunk found and killed six such orphans in the morning; the seat reaped two trees (~4.5 GB) at 15:40; and four more (2630+2566+1951+1920 MB = **9.1 GB**) had accumulated by 16:51, with free memory down to **0.06 GB** and swap at 2.9 GB of 4 GB. Every one traced to an ancestry ending at init — no live worker owned them. **The suspected feedback loop, worth confirming rather than assuming:** the runner SIGKILLs a worker's process group under host pressure, but the worker's suite children survive (reparented to init) still holding their memory, so the pressure that caused the cull does not abate — which produces another cull, which orphans more children. If that is right, a memory-pressure event is self-sustaining rather than self-correcting, which matches the day's observed pattern of culls arriving in bursts. **HYPOTHESIS REFINED 17:08 — orphans are NOT only a consequence of culls.** A single 2828 MB orphan was detected and reaped while free memory was a healthy **27.1 GB** and no cull had occurred. So the cull→orphan feedback loop described above is at most *part* of the mechanism: workers also leave suite children behind when they exit normally or die for unrelated reasons. The leak is therefore **continuous, not crisis-only** — it accumulates invisibly while memory looks fine, and only surfaces as an emergency once enough has piled up. That makes a periodic sweeper the primary fix rather than the secondary one, and it means "free memory is healthy" is not evidence that the leak is absent. Wanted: the runner must reap descendants (process-group or session kill that actually catches `zig build`'s children), plus a periodic sweeper for orphans that already exist — the DARGUS doctor *detects* them but nothing prevents or automatically reaps them. Interacts with item 2 (no resource-aware admission): admission control alone will not help if dead workers keep their memory.

15. **Concurrent workers share one git index — the one-writer invariant protects files, not commits.** Registered as `T547`. Self-reported by `T521`: its commit `784235a` absorbed T531/T545's `build.zig` hunks and T512's `regression-dispatch.sh` arms under the T521 message, because `git add <path>` stages that path's entire current working-tree content and a concurrent console (T523) committed on top mid-surgery. All work preserved (`784235a` → `081b673`, gates green) but **authorship is mixed**. This is the `d7e4bdb` precedent recurring: `T455` scoped *paths* and never serialised *commits*. Two rows can legally hold disjoint files and still corrupt each other, because `.git/index` is a single shared mutable file with no lock held across stage→commit. It matters beyond hygiene: with `T544` already showing the kanban mis-attributing models, commit history was the last trustworthy authorship source, and a commit naming one row while carrying three makes it unrecoverable too. Wanted: a commit mutex, plus a refusal to stage a path held by a different in_progress row — a check only possible since `T539` populated `holds` today.

14. **The keeper has no notion of preconditions, so a row that requires a fleet state cannot be left in the auto-dispatch pool.** `T541` (the quiet suite-truth re-run) states in its own brief that it requires `in_progress(0)` and no live workers — because a suite run against a live fleet is precisely the contamination that invalidated the first attempt. The keeper dispatched it into a full fleet (cap 3/3) at 16:19, because eligibility is status + needs + bundle + model + holds, and "the fleet must be empty" is expressible in none of those. The seat's stopgap is a fake `needs` edge on an unrelated row, which is a lie in the dependency graph — it encodes "not yet" as "depends on". Wanted: a real precondition field the keeper evaluates (`requires_drained_fleet`, or a general predicate), so a sequencing constraint stops being smuggled in as a dependency. Note the interaction with item 13: gating by `needs` also makes the row invisible to the pressure machinery, so the workaround has side effects beyond dishonesty.

13. **The keeper's logjam-pressure mechanism shrinks the cap even when shrinking cannot help.** Measured 2026-08-20 16:07: anchor `T544` was blocked on `src/managent/main.zig`, held by the *in-progress* `T545`. The keeper correctly identified the anchor and then dropped its effective cap from 3 to 1 (`drops: 2`) to let the anchor "run solo". But the anchor was blocked by a **file hold**, not by cap contention — `T545` must finish before `T544` can start *regardless* of the cap. So the cap drop bought the anchor nothing and starved conflict-free work: `T521` sat dispatchable, holding an unrelated file, while the fleet ran a single worker. The pressure state machine (T500 §6–§8) is right when the anchor is waiting for a *slot* and counterproductive when it is waiting for a *holder*. It should distinguish the two: shrink only when the anchor's holds are free and it is merely queued; when a live holder owns the file, keep admitting conflict-free candidates at the full cap, because the anchor's wait is bounded by the holder's completion and nothing else. (The seat hand-dispatched `T521` on this reasoning; recorded as a deliberate override, not a bypass.)

11. **The keeper silently inherits `WEIZIGO_AGENT_DEPTH` and can become unable to dispatch anything.** Found 2026-08-20 15:39 while restarting it: the previous long-running keeper (pid 47334) was refusing every dispatch with *"REFUSED — you are at the delegation cap (depth 3 of 3)"*, because it had been started from a shell already at depth 3. A keeper in that state looks perfectly healthy — one instance, logging every iteration — while dispatching **nothing**. Restarting it from a clean shell fixed it immediately. Two defects: the depth guard should not apply to the keeper (it is a scheduler, not a delegating worker), and a keeper that cannot dispatch must say so loudly rather than logging refusals that read like ordinary queue chatter. This may have masked idle time earlier in the day.
12. **No memory-weighted admission is the same gap as D2, but note the specific trap:** the fleet cap was 5 and a full-suite row costs ~2 GB, so the *documented* cap was safe while the *effective* one was not. The cap has been lowered to 3 for unattended operation as a stopgap, which is a workaround, not a fix.

10. **Seat error, mechanism gap behind it:** three dispatches today went out before checking the live holder, and one (`T545`) was dispatched with no `holds=` declared, so it claimed a file another row held. `bin/dispatch` could refuse, or warn, when a bundle declares `holds` the store does not carry — the check exists nowhere.

## E. The proposed calm sprint (the operator's suggestion, 2026-08-20)

His words: *"when things cool down a bit in the short term, we can take a calm and diligent sprint
to clean the tooling and processes up a bit before continuing."* **Endorsed, and the conditions
are now right:** the fleet is drained (0 workers), memory is clean (7.2 GB free), the keeper is
single-instance and healthy, and `T537`'s fix means the acceptance suite finally fails honestly.

Shape it as `T540`'s successor with section D as the intake, and keep `T540`'s bar: reproduce
before fix, red-then-green regression, findings with denominators. Two sequencing notes:
`T545` (store locking) should land first because several other defects may be downstream of it,
and `T541` (quiet suite re-run) can only run on a drained fleet — which is **now**.

The pattern worth naming, because it recurs in nearly every item above: **the measurement
apparatus quietly producing the answer it assumed.** A verdict that counted only FAIL. A counter
that only rose. Refusals scored as failures. Culls scored as failures. An invariant comparing
empty sets. An allocation default that starved the alternative it was meant to be tested against.
None of these were wrong *code* so much as instruments that could not report their own failure.
