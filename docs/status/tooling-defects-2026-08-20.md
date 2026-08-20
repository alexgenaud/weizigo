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
2. **No resource-aware admission.** The fleet cap counts *workers*, not resource weight. Several workers each launched the full suite; four `zig test` binaries at ~6.5 GB drove the host below the runner's 6144 MB floor and **12 workers were culled with rc=124**, every one recorded as a model failure. Needs: weight-aware admission, and a mutex on concurrent full-suite runs.
3. **`rc=124` is unclassifiable.** `T538`'s classifier keys on provider error text; a host-pressure kill has none, so infrastructure deaths score as model failures. Extend to `rc=124` + a runner `KILL: host memory pressure` line → `verified=unreached reason=host-memory-pressure`.
4. **`bin/dispatch` writes neither `model` nor `dispatched_to`.** The store keeps whatever was last set, which is how haiku/fable/sonnet work came to be credited to flash. Folded into `T544` by directive — recorded here because that directive may have been lost.
5. **`bin/subagent:260` hardcodes `--output-format text` for Claude lanes**, so the JSON usage envelope never exists and token counts are lost at dispatch, irrecoverably (G1 is run-time, not retroactive — Fable's correction). Relayed to `T521` by directive only.
6. **Orphaned suite runs survive their console.** Two `zig build test` trees were reparented to init and still holding 4.5 GB; the DARGUS doctor chunk found six more of the same class earlier the same day. The doctor detects them — nothing prevents or reaps them automatically.
7. **A malformed findings JSON halts the entire fleet's commits.** `findings/DARGUS-chunk.json` had a literal newline inside a string; claimlint's C7-nonconforming floor is 0, so the pre-commit hook refused *every* commit repo-wide until a worker fixed it. Needs validate-on-write in the duty/findings harness.
8. **`managent tell` reports success for a directive that never landed.** Covered by `T545` item 4, listed separately because it is the reason this file exists.
9. **Directive IDs collide with historical ones.** `D041/D042/D043` each exist twice with different targets. Consequence of `T545`'s lost updates, but the *existing* duplicates need reconciling — an ID is a reference, and a duplicated one breaks the audit trail.
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
