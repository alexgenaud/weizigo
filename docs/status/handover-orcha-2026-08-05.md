# Orchestrator handover — Fable 5 → Opus 5, 2026-08-05

Author: Fable 5, Orchestrator seat (operator-corrected attribution; the session opened
addressed to Opus). Audience: the incoming Opus/Orcha. STATE.md is the crash anchor; the
governing plan remains `docs/audits/2026-08-05-handover/ROADMAP.md` (+ MILESTONES.md,
EPISTEMIC-RACES.md beside it) — this file is only the delta this session added, so read
those first and this second. Everything here is committed; the artifacts are the whole
handoff.

## What this session did (all verified by instrument, commits named)

- **Tier 0 is complete — milestone M1 holds.** All eight `bin/` tools CURRENT, tree clean,
  bus empty, smoke genuinely green. The 24 stalled directives (D007–D036) were acked; kanban
  state committed (`b045bff`).
- **Two instrument defects found and fixed in `tools/smoke.sh`** (`21f4cb1`): the
  rules-dispatchers step had passed a `\|` alternation as one `--test-filter` string —
  substring semantics, zero tests matched, **vacuous green since the line was written**; the
  differential step ran unfiltered `zig test` and aborted on qa023's budget (red for the
  wrong reason). Both steps now assert the exact expected test count; the seeded control was
  shown to fire before the clean PASS was read.
- **STATE rule 7 prescribed a command that does not run** (`zig build test --test-filter` —
  this build.zig wires no filter). Corrected in STATE.md (`9b4c74e`) and the T363 brief to
  the real form: `zig test src/<f>.zig --test-filter <tag>`, one flag per test, count
  asserted.
- **STANDING-ABSORB is done** (`56404d0`, `044d9b2`): C7 4→0, non-conforming 3→0, INVALID
  rejections 8→0. Its root-cause finding: T356's rename of claimlint's output lines killed
  `managent standing`'s T294 trigger markers — the C7 trigger silently reads 0 forever.
  **T368 registered** to re-couple the markers, make missing-marker parses loud, and add the
  regression (set C, hold until the fleet drains).
- **Registered:** T366 (re-registration of dead T361 — old-vs-new engine kifu, milestone M3),
  T367 (race packet authoring + key sealing, EPISTEMIC-RACES item 2), T368 (above).

## In flight at handover (all deepseek-v4-flash, per the temp ruling)

`bin/managent resume` and `git log` before dispatching anything — consoles commit on their
own and the store can lag. As of this writing: **T363** (G3b whole-sprint console — also the
first sprint-manager trial on Flash), **T328** (bake-off dry-run), **T366** (kifu) in
progress; **T367** and **T354** dispatched, awaiting claim.

## Owed by the seat you now hold

1. **The G3b discharge ruling** when T363's four gaps close — each property as
   `0 violations / <full count>`, denominators mandatory (STATE rule 2). **T348 must not be
   claimed before that ruling.** Promotions are listed in g3b spec §1.1 and are yours alone.
2. **Race first-runs** (EPISTEMIC-RACES §Registration order item 3): Pro-vs-Flash on races 1
   and 2 once T328 + T367 land; then the wider roster; item 4 (Orchestrator-aspect races)
   reuses the packet infrastructure.
3. **Tier 2 registration work** (ROADMAP Tier 2): the T305 ratification row (116
   proposed-retired → `archives/` with epitaphs; operator pre-ruled archive-never-delete) and
   rows for T305's six new-work gaps. Sequence after T354 closes — both touch the register.
4. **Queue when the fleet drains:** T357 first (its brief demands a quiet fleet), then T368
   and the other set-C managent rows, then T362/T364 (they hold `tools/runner`, which every
   live console's smoke and heartbeat path executes — that is why they waited).
5. **2026-08-12: the Flash-for-everything ruling expires.** Re-rule on the week's ledger
   (`model-perf.md` §Model versions); T363's console is the sprint-manager data point.

## Addendum — same day, at handover execution

- **T328 is done** (`89baf9a`, verdict pass-with-findings, deepseek-v4-flash/T328.2): bake-off
  harness (`tools/bakeoff.sh`), T316-hardened protocol (`docs/infra/bakeoff.md`), dry run
  proven end-to-end (Flash lane exit 0, Claude lane refused by the
  `WEIZIGO_BAKEOFF_ALLOW_CLAUDE` gate as designed). Races item 3 (Pro-vs-Flash on races 1–2)
  now waits only on T367's packets.
- **T328 disclosed, and this seat verified at the cited lines: `zig build test` is RED at
  HEAD, pre-existing** — `src/vb_i11.zig:58` imports the `engine` module while `build.zig:407`
  clears that test target's import table (broken since T346's partial `9d2fd76`). Directive
  **D037** sent to T363: the fix is in its sprint territory and its acceptance gate; red→green
  goes in accept.md. If T363 stalls on it, that directive is the thread to pull.
- T328 also reproduced the dead standing-trigger regressions (controls 3–5 fail in a scratch
  repo) — same defect T368 carries; no new row needed.
- C7 reads 0 unabsorbed / 1 non-conforming — the non-conforming file is T366's *live*,
  still-in-progress findings JSON (missing `claims` key); the row will conform at close, no
  action unless it closes malformed.

## Allocation notes

Temporary default: deepseek-v4-flash for ALL new dispatches until 2026-08-12. Concurrency
(operator, 2026-08-05): the five-agent ceiling is the Ollama pool only; no DeepSeek limit is
known — six DeepSeek + five Ollama + several Claude simultaneously is fine. The binding
constraints are kanban sets (one in-progress row per set), `holds=`, and host RAM (48 GB,
OOM-panicked once at 12.5 GB; 8192 MB authorised for T363's I5 runs).
