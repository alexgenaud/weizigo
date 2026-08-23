# S09 — module test contracts (spec)

**Task:** T790 · **Author:** claude-sonnet-5 · **Date:** 2026-08-23
**Landmark:** advances L1 — the fleet's own software becomes maintainable software.
**Inputs:** T788 (suite re-baseline, `docs/infra/suite-truth.md`, 2026-08-23 ~16:32Z), T789
(test-gate wiring, three tiers, in flight), `findings/T679-tools-census.json` (prior tools
census, same author, 2026-08-22).

This is a spec. It does not implement. Every deliverable below is a *definition* — of a
population, a contract, a scenario, a sequence — concrete enough that a following pass can
dispatch it as a row without re-deriving the shape.

## 0. The correction this spec carries, restated so it is not softened

*"We lack unit tests and regression tests and e2e use case test suites … I have no confidence
anything works as is and certainly no confidence anything will work after consolidation … no
confidence without TEST SUITES."* — operator, 2026-08-23.

Every concrete failure named in the brief that motivated this row was a **seam** failure — two
components disagreeing about a contract neither had written down — not a unit-logic failure a
pure-function test would have caught:

| incident | seam | which use case below catches it |
|---|---|---|
| oxalpha lanes exited 0 in 38s/64s without reading their bundles | dispatch ↔ nonce verification ↔ "verified close" | UC-1 |
| local-model co-launch took the host below the memory floor; guard killed 3 cloud lanes whose combined footprint could not relieve the shortfall | host-guard ↔ shed-load selection | UC-2 |
| a register-repair row rewrote a race's sealed inputs while the race ran, erasing all 4 canaries | `managent` mutation ↔ race-in-flight lock | UC-4 |
| `managent done --verdict pass-with-findings` silently recorded `pass` | CLI flag parsing ↔ verdict field | UC-5 |
| the token meter declared 448 lanes "unattributable" that were in fact recoverable | `tools/token-capture.py` ↔ session-log discovery | §3.7 (token-capture.py contract, regression arm) |

So this spec's priority is **e2e/contract first, unit second**, and §4 (use cases) is written
before the per-module unit-arm detail in §3's worked examples, in that order, on purpose.

## 1. Scope — the 38 modules, and the boundary drawn honestly

**Boundary:** every script and binary under `bin/` and `tools/`, plus `tools/hooks/pre-commit`
(the one git hook that gates a commit) — **38 items**. This is *not* every executable artifact in
the repo; three items are deliberately **out of scope** for the pass-0 headcount, named here so
the boundary is not a silent omission:

- `untracked/watch-fleet.sh` — tracked in git as an established exception to `untracked/`'s
  scratch convention, well-integrated (23 references, `tools/regression-watch-fleet.sh` dedicated
  coverage), self-documented as "nothing reads this, read-only." A good S09 pass-2+ candidate,
  excluded from pass 0 because it lives outside the `bin/`+`tools/` boundary this sprint drew.
- `untracked/watch-rebuild.sh`, `untracked/T554-dispatch-graders.sh` — untracked, one-off scratch
  tools (a rebuild-trajectory monitor from the 2026-08-03 WZO2 era; a T554 grading dispatch
  helper), no doc names either as load-bearing infrastructure.

A census that draws a boundary and does not say so is the same false-green this sprint exists to
end — hence this paragraph.

### 1.1 Census method (S09-CENSUS-1)

Reachability is computed as the union of:

1. basename appearance in another file's source (the naive method, and the one that produced a
   false negative — see 1.2);
2. Python `import <name>` and `from <name> import …`, matched on the **module name**, not the
   file path — this is what a basename grep misses (`bin/subagent:70` does `import window_policy`
   with no `.py`, no `tools/` prefix);
3. `importlib.util.spec_from_file_location("<name>", …)` with a bare name;
4. lazy imports inside a function body (`tools/runner`'s `_load_token_capture` does this — a
   basename grep over the top of the file misses it entirely);
5. invocation through a variable holding a path (a script is invoked via `subprocess.run(binary_var,
   …)` where `binary_var` was assigned a path earlier — caught by grepping assignment sites, not
   call sites);
6. Zig `@import("…")`;
7. a grep of `docs/` and `untracked/` for a human- or schedule-described trigger (a launchd plist,
   an operator-run acceptance battery, a race-protocol step) — this is how "invoked by nothing in
   code" is distinguished from "invoked by a human who reads a doc," which static reachability
   alone cannot tell apart.

**Never propose a deletion on static reachability alone** — pair it with git history (T679's
`last_commit` field) and the doc/`untracked/` grep in (7). A module with a recent commit and no
caller anywhere is a stronger deletion candidate than one with an old commit and an undocumented
trigger; the two are not the same finding.

### 1.2 Known blind spots (S09-CENSUS-2) — stated because a method that can't name its own miss is the false-green this sprint exists to end

- **Basename-only grep produces false negatives** on bare-name imports and lazy imports (proven:
  `tools/window_policy.py` was one basename-grep away from being read as dead — `bin/subagent`
  imports it by bare module name and calls `family_of`/`family_cooldown`/`record_override` on
  every dispatch — moved out of the orphan set only by rule (2)/(4) above).
- **Doc-reference counts conflate "read by a human" with "invoked by code."** T679's
  `referenced_by` field (reused below) mixes both; this spec does not re-derive a
  code-only-caller count for every module (that would be its own multi-hour pass), and says so
  rather than presenting T679's mixed count as more precise than it is.
- **A module wired only into `build.zig` (compiled, not run) is not a runtime caller.** Six of the
  eleven `bin/` binaries are `build.zig` targets; that wiring alone does not make them
  "production-invoked" in the sense this census cares about (whether *breaking the module's
  behavior* would be noticed) — `bin/weizigo-arena` compiles cleanly and is still dead, because
  nothing calls it at runtime.
- **This pass did not re-execute every module.** Facts below are inherited from
  `findings/T679-tools-census.json` (same author, 2026-08-22, itself produced by dispatching
  three parallel fact-gathering sub-agents and composing/verifying their output) plus this
  session's targeted checks on the two modules T679 predates (`tools/race-collect.py`,
  `tools/token-backfill.py`) and one reclassification (§1.3). Anything T679 did not run live is
  marked as such in that file and inherited as such here — this spec does not upgrade an
  unexecuted check into a verified one.

### 1.3 One correction to the brief's own lists, disclosed rather than made silently

The brief's own count of 38 and its named lists (6 hot core, 9 declared entry points, 4 actually
dead) are cited verbatim below, per instruction. This census adds one disputed candidate the
brief's list of 4 omits: **`tools/t265_diagnostic.zig`** — T679 found it imports two files that do
not exist (`exp6_solve.zig`, `colex.zig`), carries zero `build.zig` wiring, and cannot compile
standalone; its only two references are historical audit docs. That is the same evidentiary bar
the brief's four dead modules meet. It is recorded here as a **disputed 5th** rather than moved
into the dead population outright — per the brief's own rule, "deletions land as their own rows
with the reason recorded — never silently, never bundled with a test." §2's table marks it
`DEAD (disputed)` and it is *not* counted toward either population's total below, keeping the
brief's 6+9+4=19 named count intact and auditable; whoever takes the deletion-triage row decides
whether it joins the 4 or is rescued.

## 2. Pass-0 census — all 38 modules, four answers each

Columns: **what it is for** · **who invokes it** · **last activity** · **would anyone notice if it
vanished**. Evidence source is `findings/T679-tools-census.json` unless marked otherwise.

### 2.1 HOT CORE (6) — huge fan-in, most of the churn, no dedicated gate. Cited verbatim from the brief; contracts here first (§3.2–§3.7 give worked examples for all six).

| module | for | invoked by | last activity | noticed if gone |
|---|---|---|---|---|
| `tools/runner` | guarded dispatch/sandboxing/telemetry core — spawns every lane, host-guard, token capture, reap | `bin/dispatch`, `bin/subagent`, `build.zig` (15+ sites), `fleet-keeper.sh`; 56 production files, 30 commits/**29 distinct rows** (brief table) | `0e74e37` 2026-08-22 | yes, instantly — every dispatch breaks |
| `bin/dispatch` | CLI that launches one lane and drives its verification | `fleet-keeper.sh`, `window_policy.py`, `dispatch_verify.py`, `attribution-backfill.py`, human paste lines; 47 production files, 9 commits/12 rows | `4aee950` 2026-08-22 | yes, instantly |
| `bin/managent` | the kanban store — claim/done/inbox/status/orient; the tool this brief itself is written in terms of | 143 referencing files, every workflow in this sprint | source `c7e4034` 2026-08-22 | yes, instantly and catastrophically |
| `bin/weizigo-claimlint` | honest-debt floor / citation lint (C1–C9), ratchet-down only | `main.zig`, `orcha-acceptance.sh`, `model-profiles.py`, ~15 regression scripts; 30 files, 8 production callers (brief table) | source `533d908` 2026-08-22 | yes, pre-commit-adjacent breakage |
| `bin/subagent` | the CLI a manager calls to launch its own leaves, depth-capped | 70 files (`DELEGATEE.md`/`DELEGATOR.md`, `dispatch_verify.py`, `token-capture.py`); 29 commits/**26 distinct rows**, 7 production callers (brief table) | `0e74e37` 2026-08-22 | yes, instantly — all delegation halts |
| `tools/fleet-keeper.sh` | the unattended daemon loop: cooldowns + dispatch loop, launchd-driven | `weizigo.fleet-keeper.plist`, 51+ files, 5 production callers (brief table) | `757138e` 2026-08-22 (uncommitted diff at T679 census time) | yes within one keeper cycle, but *silently* — nothing alerts on the plist's own logs |

### 2.2 DECLARED ENTRY POINTS (9) — invoked by a human or a schedule, misread as dead by static reachability alone. Cited verbatim from the brief.

| module | for | invoked by | last activity | noticed if gone |
|---|---|---|---|---|
| `tools/deploy.sh` | remove-copy-sign deploy step, one per `weizigo-*` binary + `managent` | `build.zig` (8 call sites) as a build step a human runs (`zig build deploy-X`); `regression-managent-store-write-utf8.sh` | `ae29552` 2026-08-02 | yes — next deploy silently copies a stale binary (the `weizigo-oracle` BadMagic/T534 precedent) |
| `tools/orcha-acceptance.sh` | Orchestrator-seat acceptance battery, AC1–AC11 | a human/seat running it periodically; `build.zig:473`, `tools/runner` | `2e36495` 2026-08-22 | yes — it is *already* reporting 5 real fails (AC1,4,5,7,8) that nobody has acted on because nobody runs it on a schedule |
| `tools/pilot_gate.sh` | ADR-0012 fast promotion gate (2x2/3x2/3x3/4x3 hash check) | a human before promoting an artifact; `regression-pilot-gate.sh` | `51dbf23` 2026-08-19 | yes, at the next promotion attempt |
| `tools/gen-indices` | regenerate `docs/INDEX-claim-{task,evidence,deps}.md` | a human/cron regenerating docs (no doc names the trigger); `regression-absorption-machinery.sh` | `b1c443f` 2026-08-07 | yes, but slowly (stale indices go unnoticed until someone cross-checks); **hazard, restated:** it has no argument parsing at all — any invocation, including an attempted `--help` probe, unconditionally rewrites the three INDEX files in place (T679 confirmed this by tripping it) |
| `tools/window_policy.py` | per-family dispatch-window/cooldown policy (`family_of`, `family_cooldown`, `record_override`) | **dual role, the census's own worked example (§1.2):** imported by bare name inside `bin/subagent` on every dispatch, *and* run as a standalone entry point by `tools/fleet-keeper.sh`'s watch loop | untracked — in-flight T628/T677 work | yes, on the very next dispatch — a basename-only census would have called this dead |
| `tools/complementarity.py` | reduce/check/schema for the complementarity record | `main.zig`, `docs/infra/complementarity.md`; wired into `zig build test` per `build.zig` comment | `13ff364` 2026-08-22 | yes, `zig build test` red |
| `tools/battery-baseline-compare.py` | compares a battery run against its recorded baseline | `docs/epics/…/verify-battery/pass1/baselines.md`; `regression-battery-baselines.sh`, `regression-battery-sweep.sh` | `f25e615` 2026-08-03 | only if someone re-runs the battery — otherwise silent |
| `tools/attribution-backfill.py` | backfill/repair task-attribution fields | `bin/dispatch`, `main.zig`; `regression-attribution-backfill.sh` | `8076156` 2026-08-22 | yes, next attribution repair |
| `tools/race-collect.py` | mechanical race-protocol-v2 collection + blinding (content-hash the judge's blind set, refuse a set that leaks attribution) | invoked by a human/orchestrator running a race collection step; `docs/epics/…/race-protocol-v2.md`, S06 spec; own `regression-race-collect.sh` (survives S06 per ORC-PLAN-4 amendment) | `b436c63` 2026-08-23 (T779) | yes, at the next race's judging step — and the failure mode (a leaked attribution) is exactly the thing race-protocol-v2 exists to prevent |

### 2.3 ACTUALLY DEAD (4, +1 disputed) — invoked by nothing, referenced by nothing, not even a test. Cited verbatim from the brief; the 5th is this census's own addition (§1.3).

| module | for (historical) | invoked by | last activity | noticed if gone |
|---|---|---|---|---|
| `bin/weizigo-arena` | self-play arena binary | 11 doc files only (`AGENTS.md`, `HANDOVER.md`); default invocation errors on a hardcoded path to a deleted artifact | source `879b0fe` 2026-07-27 | no |
| `tools/play_oracle.py` | interactive oracle play harness | `DELEGATEE.md`, two research docs; missing exec bit despite a shebang | `1abb0c2` 2026-07-25 | no |
| `tools/race-c-prepare.py` | Race C input builder | none anywhere besides its own git history | `9f73667` 2026-08-22 | no |
| `tools/token-backfill.py` | one-shot recovery of 448 unmetered lane token readings | added by T746 this session, invoked by nothing since — disclosed by its own author (T790's brief) as belonging on this list | `105e8f8` 2026-08-23 | no, unless it earns a home in T789's gate or gets deleted once its backfill is absorbed |
| `tools/t265_diagnostic.zig` **(disputed, §1.3)** | a one-time 2026-08-02 diagnostic | 2 historical audit docs only; imports two files that don't exist; zero `build.zig` wiring | `78057e4` 2026-08-02 | no — pending ratification as a deletion, not silently added to the count above |

### 2.4 Ordinary reachable (19) — production-invoked, not called out for priority, still owed a contract in pass 2+

| module | for | invoked by | last activity | noticed if gone |
|---|---|---|---|---|
| `bin/argus` | fleet doctor / duty-check runner, itself spawns `weizigo-oracle` as one of its checks | 49 files; confirmed runtime caller of `weizigo-oracle` (`bin/argus:488`) | source `6e0c02d` 2026-08-20 | yes — `regression-argus-doctor.sh` already reports it state-dependent-red (T442) |
| `bin/weizigo-chainability` | chain-length/complementarity oracle query | `build.zig`, `tools/smoke.sh`, research + `GLOBAL.DENOMINATORS` evidence docs | source `4a598b1` 2026-08-02 | only via smoke's build-freshness check — no behavioral regression |
| `bin/weizigo-engine-vs-engine` | engine-vs-engine self-play harness | `build.zig`, `tools/smoke.sh`; sparsest reference footprint of any binary (6 files) | source `4a598b1` 2026-08-02 | only via smoke |
| `bin/weizigo-gtp` | GTP protocol server (Sabaki-compatible) | `build.zig`, `regression-gtp-boardsize.sh`, `docs/infra/host/sabaki.md` | source `b35ea50` 2026-08-07 | yes for boardsize behavior; a GTP-session regression beyond that is unverified |
| `bin/weizigo-oracle` | deploy-alias of `weizigo-gtp`'s output (its GTP `name` command replies `weizigo-oracle`) | `bin/argus` (confirmed runtime `subprocess` call), oracle-v2 specs, `CLAIMS.md` | tracks `src/gtp.zig`, `b35ea50` 2026-08-07 | **weakest-verified reachable module censused** — zero regression AND zero smoke coverage despite a documented prior silent-staleness incident (BadMagic, T534) |
| `bin/weizigo-reachcensus` | reachability census oracle query | `build.zig`, `tools/smoke.sh`, `GLOSSARY.md`, `GLOBAL.DENOMINATORS` evidence | source `4a598b1` 2026-08-02 | only via smoke |
| `tools/bakeoff.sh` | grand-race bakeoff dispatch + grading | 56 files (`tools/runner`, `token-capture.py`, `race-p0-verify.sh`) | `5899c2f` 2026-08-22 | yes, next race dispatch — its own most recent commit self-reports the `grade` subcommand "orphaned, UNVERIFIED — rescued from a watchdog kill" |
| `tools/directive_policy.py` | pause/amend/kill directive parse+validate library for the inbox loop | `bin/dispatch` (import), `main.zig` | `4aee950` 2026-08-22 | yes, but only as a downstream `regression-directive-*` failure — no CLI/`--help` of its own |
| `tools/dispatch_verify.py` | classify a dispatch outcome verified/unverified/unreached | 55 files (`bin/subagent`, `tools/runner`, `fleet-keeper.sh`) | `2e36495` 2026-08-22 | yes — T788 found a live classification defect here (D021: a harness-kill refusal misclassified `fail` instead of `unreached`) |
| `tools/fleet-cooldown.sh` | set/clear/report one of the three (soon-to-merge, ORC-POL-4) cooldown mechanisms | `tools/fleet-keeper.sh`, `docs/infra/duties.md` | `7d0efea` 2026-08-20 | yes within one keeper cycle, silently |
| `tools/gen-version.sh` | emit the version string `build.zig` stamps into every binary | `build.zig:25`, every build | `ae29552` 2026-08-02 | yes, every build, silently (wrong/stale version string) |
| `tools/model-profiles.py` | per-model profile / serving-tag lookup for token accounting and dispatch | `tasks.json` tooling, `token-capture.py`, `dispatch_verify.py` | `2e36495` 2026-08-22 | yes — feeds the cost ladder T772 depends on |
| `tools/race-p0-verify.sh` | grand-race P0 go/no-go SEALS/ROSTER gate | `tools/runner`, `suite-truth.sh` (`regression-race-p0.sh`) | `6fb5801` 2026-08-21, re-pointed by T788 2026-08-23 | yes, at the next race start |
| `tools/smd1.zig` | native SMD1/i11 engine, a `zig build test` target (14 tests) | `src/smd1_engine.zig`, `src/vb_i11.zig` imports | `5dccc3f` 2026-08-04 | yes, `zig build test` red |
| `tools/smoke.sh` | deployed-binary build-stamp freshness check | `build.zig:1108` test step; `bin/argus` | `99a919b` 2026-08-21 | yes — the one thing standing between a stale binary and silent staleness, for the binaries its own `deploy_check` list covers (it does **not** cover `weizigo-arena` or `weizigo-oracle`) |
| `tools/suite-truth.sh` | observed-vs-manifest ratchet gate over the whole suite — T789's mechanism | `src/evidence.zig`, `regression-suite-surfaces.sh` | `39ee966` 2026-08-22, re-baselined by T788 2026-08-23 | yes — it is the gate this whole sprint is designing tiers around |
| `tools/token-capture.py` | capture per-lane token usage into `model-task-metrics.jsonl` | `tools/runner`, `bakeoff.sh`, `race-p0-verify.sh` | `0e74e37` 2026-08-22 | yes — T746 found 448 lanes this module's pipeline had marked "unattributable" that were in fact recoverable; its contract's regression arm belongs exactly here |
| `tools/weizigo-claimlint` companion — *(none; already listed under HOT CORE)* | — | — | — | — |
| `tools/hooks/pre-commit` | the commit-time gate — today, citation debt only, **invokes no test** | `git core.hooksPath`, every commit | `31dce73` 2026-08-20 | yes, every commit — and yet the thing it does *not* do (run any test) stayed invisible for the whole week this sprint audits |

(18 data rows above + `bin/argus` = 19; the placeholder line marks that `bin/weizigo-claimlint`
is not double-counted — it is HOT CORE, §2.1.)

**Total: 6 + 9 + 4 + 19 = 38.** (`tools/t265_diagnostic.zig` tracked separately as disputed,
§1.3/§2.3, not added to this total pending its own deletion-triage row.)

## 3. The module contract

### 3.1 Schema (S09-CONTRACT-1)

For each module pass 0 keeps, a contract states, testably:

```
owner:            <sprint/landmark this module serves>, one line
purpose:          what it is for, one line
public_surface:   flags | env vars | exit codes | files read | files written
unit_arms:        [ {id, what pure logic it isolates} ]
regression_arms:  [ {id, seeded-defect fixture, null-control fixture, must-be-shown-red-first} ]
e2e_arm:          {id, the realistic invocation it exercises}
gate_tier:        pre-commit | pre-consolidation | scheduled   (T789's three tiers)
would_have_caught: <a named, real, past incident — or the arm is a deletion candidate>
```

Arm count is stated per module, and the running total is stated at the end of §3 (S09-ARM-LEDGER)
— the S06 spec audit (T807/T809) found 16 of 31 normative ids armless; this spec does not repeat
that by leaving the count implicit.

### 3.2 `tools/runner` (worked contract)

- **owner:** L1 dashboard / S06 (absorption target for the host-guard interaction).
- **purpose:** the guarded process that actually spawns a lane, applies the host-guard/shed-load
  decision, captures tokens, and reaps the child.
- **public surface:** flags — `--brief`, `--task-id`, `--provider`; env — `MANAGENT_TASK_ID`; exit
  codes — 0 success, non-zero on guard-kill or child crash (currently under-distinguished, see
  regression arm below); files written — `untracked/log/<task>.log`, session capture under
  `untracked/tokens/sessions/`.
- **unit arms (2):**
  - `S09-RUNNER-U1` — shed-load candidate selection given a set of running PIDs and their measured
    footprints picks a subset whose combined footprint actually relieves the shortfall (pure
    function over a footprint table, no process spawn needed).
  - `S09-RUNNER-U2` — `_load_token_capture`'s lazy import resolves even when invoked from a
    different working directory (regression against the census's own blind spot, §1.2).
- **regression arms (2):**
  - `S09-RUNNER-R1` — seeded defect: shed-load selection picks 3 lanes whose combined footprint is
    less than the shortfall (the exact 2026-08-23 15:19 defect) → asserted red; corrected
    selection → green. **Would have caught:** the local-model co-launch incident, UC-2.
  - `S09-RUNNER-R2` — null control: no host pressure, no local model resident → no lane killed.
- **e2e arm:** `S09-RUNNER-E1` = UC-1 (dispatch one lane per provider, assert verified close).
- **gate tier:** R2/U1/U2 → pre-commit (host-independent, seconds-scale); R1 → pre-consolidation
  (needs a simulated host-pressure fixture, not host-insensitive); E1 → scheduled (spawns a real
  provider lane).
- **would-have-caught:** R1 → the 15:19 host-guard incident; E1 → the oxalpha exit-0 incident.

### 3.3 `bin/dispatch` (worked contract)

- **owner:** L1 dashboard / S06 (dispatch/subagent rewire, phase 5).
- **purpose:** the CLI a human or a manager calls to launch one lane against a bundle.
- **public surface:** flags — `--provider {claude,deepseek,pi,ollama}`, positional `<task-id>
  <bundle-path>`; exit codes — 0 dispatched, refusal codes for landmark-gate / delegation-cap /
  unrecognized flag; files read — the bundle (must contain a `**Landmark:**` line, T682 gate).
- **unit arms (1):** `S09-DISPATCH-U1` — the landmark-gate parser accepts a bundle with a
  `**Landmark:**` line and refuses one without, independent of any process spawn.
- **regression arms (2):**
  - `S09-DISPATCH-R1` — seeded defect: an unrecognized flag (e.g. a retired `--dsflash`) is
    silently ignored → asserted red today (this is the live shape of the
    `--verdict`-vs-`--status` bug, reproduced here at the dispatch layer); fixed → refused loudly,
    green.
  - `S09-DISPATCH-R2` — null control: a well-formed bundle + a recognized provider flag dispatches
    clean.
- **e2e arm:** `S09-DISPATCH-E1` = UC-1.
- **gate tier:** U1/R2 → pre-commit; R1 → pre-commit once the flag-refusal fix (T775) lands, else
  it is the very red this sprint should show first; E1 → scheduled.
- **would-have-caught:** R1 → the class of bug T775/T768 exist to fix; E1 → the oxalpha incident.

### 3.4 `bin/managent` (worked contract)

- **owner:** L1 dashboard, the orchestration layer itself.
- **purpose:** the task store — claim, done, inbox, status, orient; the source of truth for what
  is in progress, dispatchable, or blocked.
- **public surface:** subcommands (`claim`, `done`, `inbox`, `status`, `orient`, `show`, `add`,
  `agent`, …), each with its own flags; exit codes; the store file on disk (single-writer lock).
- **unit arms (1):** `S09-MANAGENT-U1` — `done`'s flag parser rejects an unrecognized flag (e.g.
  `--verdict`) rather than silently dropping it and defaulting `--status`.
- **regression arms (3):**
  - `S09-MANAGENT-R1` — seeded defect: `done --verdict pass-with-findings` (no `--status`) is
    called → today records `--status` as unset/default `pass`, silently → asserted red; fixed →
    refused with a named-flag error, green. **Would have caught:** the exact incident named in the
    brief's motivating list.
  - `S09-MANAGENT-R2` — SIGKILL the lock holder mid-mutation, then attempt a mutating command →
    today RC134/SIGABRT (T788's live finding, T337) → asserted red until T337 lands; green after.
  - `S09-MANAGENT-R3` — a race's sealed-inputs directory is mutated by a second, concurrent
    `managent`-driven repair row while the first row still holds the race lock → must be refused,
    not silently applied. **Would have caught:** the Race G contamination (T731 mid-race rewrite,
    2026-08-23, four canaries erased).
- **e2e arm:** `S09-MANAGENT-E1` = UC-3 (delegation is automatic — a dispatchable row with a free
  hold is claimed, run, and closed with no human action).
- **gate tier:** U1/R1 → pre-commit (fast, deterministic); R2/R3 → pre-consolidation (need a
  second process / a held lock, not host-insensitive-fast); E1 → scheduled.
- **would-have-caught:** R1 → the verdict-silently-recorded-as-pass incident; R3 → Race G; E1 →
  "delegation is not automatic" (currently a wondered-about property, per the operator's own
  words, not a tested one).

### 3.5 `bin/weizigo-claimlint` (worked contract)

- **owner:** L1 dashboard, honest-debt floor.
- **purpose:** citation-debt lint (C1–C9), the floor that never rises.
- **public surface:** default (no-arg) invocation runs a read-only `verify` against the live
  `CLAIMS.md`; exit 0/non-zero on floor breach.
- **unit arms (1):** `S09-CLAIMLINT-U1` — a C2/C7 count computed from a fixture register matches a
  hand-counted expectation (already covered by `regression-claimlint-output.sh`'s three controls;
  this contract names it rather than re-specifying it).
- **regression arms (1):** `S09-CLAIMLINT-R1` — a seeded floor regression (one more unabsorbed C7
  row than the floor allows) is refused by the pre-commit hook, not merely reported.
- **e2e arm:** `S09-CLAIMLINT-E1` — a real commit touching `CLAIMS.md` with a genuine new
  unabsorbed finding is refused at `git commit` time (exercises the hook, not just the binary).
- **gate tier:** U1/R1 → pre-commit (already there, informally — this contract makes it formal);
  E1 → pre-commit.
- **would-have-caught:** E1 is the existing hook's own job; naming it here is what stops a future
  "citation debt only, no test" repeat of the T789 finding from recurring in the claimlint gate
  itself.

### 3.6 `bin/subagent` (worked contract)

- **owner:** L1 dashboard / S06 (dispatch/subagent rewire, phase 5).
- **purpose:** the CLI a manager calls to launch its own leaf, depth-capped.
- **public surface:** `--provider {claude,deepseek,ollama,pi}` (current CLI, post T713 — the
  regression suite's own fixtures still assert the retired `--dsflash`/`--dspro`/positional
  flags, T788's live finding); depth-cap refusal exit code.
- **unit arms (1):** `S09-SUBAGENT-U1` — depth-cap refusal fires at depth 3 of 3, not depth 4 (an
  off-by-one is the realistic seeded defect for a cap check).
- **regression arms (2):**
  - `S09-SUBAGENT-R1` — the `--provider` flag surface matches the CLI at HEAD, not a stale fixture
    (this is literally T788's live red — the fixture predates the CLI move). **Would have
    caught:** the `regression-subagent-prompt.sh`/`regression-fleet-keeper.sh` breakage T788 found
    this session.
  - `S09-SUBAGENT-R2` — null control: a depth-1 dispatch with a valid provider flag succeeds.
- **e2e arm:** `S09-SUBAGENT-E1` = UC-1, run through `bin/subagent` rather than `bin/dispatch`
  directly (the two callers of `tools/runner` must both be exercised, not just one).
- **gate tier:** U1/R2 → pre-commit; R1 → pre-commit (it is exactly the kind of "surface bug" the
  brief calls out — a flag rename with no fixture update — that a fast, always-run check should
  catch same-day, not a week later in a suite re-baseline); E1 → scheduled.
- **would-have-caught:** R1 → this session's own live finding, restated as the reason the fixture
  should have failed loudly the day the CLI moved, not eight days into drift.

### 3.7 `tools/fleet-keeper.sh` (worked contract)

- **owner:** L1 dashboard / S06 (absorption target — cooldown half → policy file, dispatch-loop
  half → arbiter).
- **purpose:** the unattended loop: cooldowns + dispatch, launchd-driven, no human in the loop.
- **public surface:** no flags (a loop, not a one-shot CLI); reads the policy/cooldown files
  `window_policy.py` and `fleet-cooldown.sh` maintain; writes dispatch calls to `bin/dispatch`.
- **unit arms (0 — none isolable):** the loop's logic is almost entirely orchestration, not pure
  function; this is itself a finding — a module with zero isolable unit logic is a signal that
  its *e2e* and *regression* arms carry the whole contract, consistent with §0's priority
  inversion.
- **regression arms (1):** `S09-FLEETKEEPER-R1` — the `subagent-prompt` sub-arm (its call into
  `bin/subagent`) matches the CLI at HEAD — same root cause and same fixture-drift class as
  `S09-SUBAGENT-R1`, kept as a separate arm here because `fleet-keeper.sh` is a distinct caller
  that must independently not break.
- **e2e arm:** `S09-FLEETKEEPER-E1` = UC-3 (delegation is automatic, run through the keeper's own
  loop rather than a single `managent` claim/done pair — this is the arm that actually answers
  "should be tested periodically," since the keeper is the thing meant to run periodically).
- **gate tier:** R1 → pre-commit; E1 → scheduled (one full keeper iteration against a scratch
  store, not fast enough for pre-commit, not full-suite-scale either — this is exactly the kind of
  check T789's change-based-selection dimension should route to whoever touches `fleet-keeper.sh`,
  `bin/subagent`, or `window_policy.py`, per T789's "each test declares which modules it covers").
- **would-have-caught:** R1 → same finding as `S09-SUBAGENT-R1`; E1 → "I should not wonder why
  delegation is not automatic" (operator, T789 brief).

### 3.8 Contracts for the remaining 32 modules

Not worked in full here — that is pass 2+'s job (§5.2), one module per pass, each producing its
own contract with the same seven fields as §3.1. This spec fixes the *shape*; writing the other 32
contracts before their arms exist would be exactly the "vibe-coded" test suite the operator's
ruling warns against. The triage order is: the 9 declared entry points and the 4(+1 disputed) dead
modules first (§5.3 — a module nobody can answer the four census questions for is a
deletion/disposition candidate, and that disposition is cheaper to land than a full contract), then
the 19 ordinary-reachable modules by whichever sprint next touches them.

## 4. The use-case suite

The layer that does not exist today (T789's own finding). Each is a scenario against a fixture
repo or scratch store — **never the live one** — because every scenario below either kills
processes, mutates a store, or seeds a defect, and the live fleet is not a fixture.

### UC-1 — dispatch one lane per provider, end to end

**Fixture:** a scratch `managent` store with one dispatchable row per provider (claude, deepseek,
pi/openrouter, ollama-local), each bundle containing a nonce line and a one-file deliverable.
**Scenario:** dispatch each row through its normal path (`bin/dispatch` and, separately, through
`bin/subagent` — both callers, per §3.6). **Assert:** each lane reaches a *verified* close — nonce
echoed in the transcript, the declared deliverable file exists, and the row is left `in_progress`
until `managent done` is called (never silently marked done by the dispatch step itself).
**Would have caught:** the two oxalpha lanes that exited 0 in 38s/64s without reading their
bundles — nonce verification caught it that day only because a human was watching; this arm makes
watching unnecessary.

### UC-2 — co-launch a local model with cloud lanes; no cloud lane dies

**Fixture:** a simulated host-guard input — a footprint table of N "running" PIDs (some real
sleeper processes so the guard's process-existence check is genuine, sized to represent a local
MLX-engine load) plus a memory-floor breach. **Scenario:** trigger the shed-load decision.
**Assert:** the guard's kill selection, applied to the fixture's footprint table, actually relieves
the shortfall — no run where the selected kill set's combined footprint is less than the deficit
(this is a property check over the selection function, `S09-RUNNER-U1`/`R1`, run here as the e2e
frame around it). **Would have caught:** the 2026-08-23 15:19 incident — three cloud lanes killed,
none of whose combined footprint could have relieved the shortfall.

### UC-3 — delegation is automatic

**Fixture:** a scratch `tasks.json` with one dispatchable row, a free hold, no blocking `needs`.
**Scenario:** run one iteration of `tools/fleet-keeper.sh` (today) / the S06 arbiter (after
absorption) with no human action after seeding the fixture. **Assert:** the row transitions
dispatchable → in_progress → done without any manual `managent claim`/`done` call in the scenario
script. **Would have caught:** nothing yet, because this property has never been tested — it is
the operator's named "I should not wonder why delegation is not automatic" property, currently
UNKNOWN rather than PASS or FAIL, and this arm converts it to a fact.

### UC-4 — a race's sealed inputs survive a concurrent repair row

**Fixture:** a scratch race root with 4 seeded canaries and a held race-lock (simulating "race in
flight"). **Scenario:** while the lock is held, run a register-repair row (the same class of
mutation T731 ran) against the race's sealed-inputs path. **Assert:** the mutation is refused
(preferred) or, if the design permits concurrent non-conflicting writes, the 4 canaries are
provably unchanged after — never silently overwritten. **Would have caught:** Race G's
contamination (T731, 2026-08-23 09:41:10Z, four seeded canaries erased mid-race, voiding the arm —
`[[project-race-g-contaminated-2026-08-23]]`-class incident).

### UC-5 — verdict and flag integrity

**Fixture:** a scratch store with one row ready to close. **Scenario:** call `managent done` with
one recognized flag misspelled as an unrecognized one (`--verdict` where the CLI wants `--status`)
in one sub-scenario, and with the correct flag in a second. **Assert:** the misspelled-flag call is
**refused**, not silently accepted with a default; the correct-flag call records the *exact*
verdict requested, byte for byte. **Would have caught:** the incident this spec's §0 table already
names first — `managent done --verdict pass-with-findings` silently recording `pass`.

## 5. Sequencing

### 5.1 Pass 1 — characterization (S09-SEQ-1)

*"we need to prove what works works before proving the consolidation still works"* — operator
ruling, applied here to the S06 target set specifically: **the six scripts S06 will consolidate**
(`docs/status/roadmap-2026-08-23.md`: "S06 (six fleet scripts → one policy file, one dashboard, one
arbiter)") — `tools/window_policy.py`, `tools/directive_policy.py`, `tools/fleet-keeper.sh`,
`untracked/watch-fleet.sh`, `bin/dispatch`, `bin/subagent`.

Concrete enough to dispatch, one row per script:

1. Write a fixture that exercises the script's **current** externally-observable behavior — its
   flags, its exit codes, the files it reads/writes — including behavior believed wrong (e.g. the
   three redundant cooldown mechanisms `window_policy.py`/`fleet-cooldown.sh`/`fleet-keeper.sh`
   each partially implement, per ORC-POL-4; the `bin/subagent` CLI mid-flight rename this
   session's own live finding caught).
2. Capture the fixture's output as a golden snapshot.
3. Seed a real mutation of the script (not a no-op) and show the characterization arm goes red;
   restore and show green. This is the same red-then-green rule every regression arm in this spec
   follows — a characterization arm that has never been shown red is unverified, same as any other.
4. Where the pinned behavior is a **known defect** (the triple cooldown mechanism, the stale CLI
   fixtures), the arm asserts what the code does today and records the defect as its own row
   (§5.3's disposition table) — the characterization arm is not the place to fix it.

This produces the "shared test harness" the roadmap notes the six scripts lack today — a
precondition the roadmap already names for lifting the S06 hold.

### 5.2 Pass 2+ — one module per pass (S09-SEQ-2)

Contract written (§3.1's seven fields), arms shown red then green, gate tier assigned (cross-ref
T789's three tiers), before the next module starts. No big-bang. Order: the 6 HOT CORE modules
first (§3.2–§3.7 already worked as the starting contracts), then the 9 declared entry points +
5 dead/disputed (triaged per §5.3, not contracted until disposed), then the 19 ordinary-reachable
modules, in whatever order the sprint that next touches one dictates.

### 5.3 Triage-first rule for the 13 (+1 disputed) uncovered modules (S09-SEQ-3)

Before any of the 9 declared entry points or 4(+1) dead modules gets a full contract, it gets a
one-line disposition:

| module | disposition |
|---|---|
| `tools/deploy.sh`, `tools/orcha-acceptance.sh`, `tools/pilot_gate.sh`, `tools/gen-indices`, `tools/window_policy.py`, `tools/complementarity.py`, `tools/battery-baseline-compare.py`, `tools/attribution-backfill.py`, `tools/race-collect.py` | **needs a contract** — declare the role explicitly (who runs it, when, on what trigger) per §2.2's "invoked by" column; `tools/gen-indices` additionally needs its argument-parsing hazard fixed (any invocation mutates tracked files) before it is safe to write a regression arm for at all |
| `bin/weizigo-arena`, `tools/play_oracle.py`, `tools/race-c-prepare.py`, `tools/token-backfill.py` | **should be deleted or homed** — the brief's own disposition; lands as its own row with the reason, never bundled with a test |
| `tools/t265_diagnostic.zig` | **disputed deletion candidate** (§1.3) — its own triage row decides, not this spec |

An unused script with no test is a liability; `tools/` has accumulated some (per the brief), and
this table is where that gets fixed, not inside a module contract.

## 6. Gate tiers — cross-reference to T789

Every arm above is tagged with one of T789's three tiers (pre-commit / pre-consolidation /
scheduled). Two rules from T789 apply directly to every contract in §3:

- an arm with no declared module-coverage always runs (T789's rule (a): unknown coverage is not
  empty coverage) — every arm in §3 declares its module in its ID prefix (`RUNNER-`, `DISPATCH-`,
  …), satisfying this by construction;
- the change-based selection T789 specifies (run the arms of the changed module + its dependents)
  reads its coverage declaration from exactly this document — `S09-RUNNER-*` arms run on a commit
  touching `tools/runner`, `S09-SUBAGENT-*` + `S09-FLEETKEEPER-*` both run on a commit touching
  `bin/subagent` (both declare it as a dependency, §3.6/§3.7), and so on.

## 7. Arm ledger (S09-ARM-LEDGER)

| id prefix | module | unit | regression | e2e | total |
|---|---|---|---|---|---|
| `S09-RUNNER-` | `tools/runner` | 2 | 2 | 1 | 5 |
| `S09-DISPATCH-` | `bin/dispatch` | 1 | 2 | 1 | 4 |
| `S09-MANAGENT-` | `bin/managent` | 1 | 3 | 1 | 5 |
| `S09-CLAIMLINT-` | `bin/weizigo-claimlint` | 1 | 1 | 1 | 3 |
| `S09-SUBAGENT-` | `bin/subagent` | 1 | 2 | 1 | 4 |
| `S09-FLEETKEEPER-` | `tools/fleet-keeper.sh` | 0 | 1 | 1 | 2 |
| `S09-UC-` (UC-1..5, cross-cutting) | — | 0 | 0 | 5 | 5 |
| **total normative arms this spec defines** | | 6 | 11 | 11 | **28** |

Every id above carries at least one arm and names an incident it would have caught (§3.2–§3.7,
§4) or states explicitly why it has none (`S09-FLEETKEEPER-` unit arms: zero, because the module
has no isolable pure logic — a stated absence, not a silent gap). The 32 not-yet-worked modules
(§3.8) are explicitly *not* counted in this ledger — they are pass 2+'s obligation, and counting
them here would misstate what this spec actually specifies versus what it defers.

## 8. Acceptance

- Spec at `docs/epics/E1-markovian/L1-dashboard/S09-module-test-contract/spec.md` (this file) —
  every normative id carries ≥1 arm, count stated in §7 (28 arms across 6 module contracts + the
  5-case use-case suite).
- Pass-0 census: all 38 modules classified (§2.1–§2.4), each with its four answers; deletion
  candidates named with reasons (§2.3, §5.3), including one disputed correction to the brief's own
  list, disclosed rather than silently applied (§1.3).
- Five use cases specified as runnable scenarios, each naming its fixture (§4).
- Characterization-pass definition, concrete enough to dispatch, naming the six S06-target scripts
  by path (§5.1).
- Findings: `findings/T790-module-contract-spec.json`.
