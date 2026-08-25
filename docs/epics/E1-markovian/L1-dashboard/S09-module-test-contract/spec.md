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

---

# T861 — module map, contract declarations, and the known-red baseline

**Task:** T861 · **Worker:** deepseek-v4-pro/T861 · **Date:** 2026-08-24
**Landmark:** advances `L1 (the dashboard tells the truth)` — this is the row that makes the
operator's module-test ruling enforceable: the map (declare) + the `test … covers …` lines the
pre-commit hook parses (select) + the dated, per-script, owned, expiring known-red baseline.

The T790 spec above fixes the *shape*; this section fills it with the real population. The three
machine sections below are the ones `tools/hooks/pre-commit` parses — nothing else in this file is
machine-read.

## 9. Module map (T861 — declare)

A **module** is a subset of the project with its own test suite. Two kinds, per the operator ruling:
software (tooling, engines, experiments, tables) and prose (the epistemic tree). For each module:
its tracked files (path prefix), its suite, and its gate tier.

**Tier rule (T861, measured 2026-08-24):** a script is *pre-commit* only if it runs standalone via
`sh <script>` with no build-wired argument AND completes in ≤ 20 s wall. Anything slower, or that
needs a `zig build test` argument, or that is state-dependent by design, is *full/scheduled* tier
(ran by `zig build test` / `tools/suite-truth.sh`). This is the tiered half of the budget
resolution (§9.1); the parallel half is in the hook.

| module | tracked path prefix(es) | suite | tier |
|---|---|---|---|
| kanban (bin/managent) | `src/managent/` | ~40 `regression-managent-*`, `regression-directive-*`, `regression-orient`, `regression-store-census`, `regression-status-doc-truth`, `regression-T227`, `regression-task-*`, `regression-inbox-loop`, `regression-claim-lifecycle` | pre-commit (≤20s) + full (slow arms) |
| claimlint (bin/weizigo-claimlint) | `src/claimlint.zig` `src/absorb.zig` `src/claims_register.zig` | `regression-claimlint-*` | pre-commit |
| epistemic tree (prose) | `docs/epistemic/CLAIMS.md` `docs/epistemic/PROGRESS.md` `docs/evidence/` `findings/` | `bin/weizigo-claimlint` + `regression-claimlint-*` + `regression-absorption-machinery` | pre-commit (claimlint) + full |
| gtp / oracle (bin/weizigo-gtp, bin/weizigo-oracle) | `src/gtp.zig` | `regression-gtp-boardsize` | pre-commit |
| runner | `tools/runner` | `regression-runner-*` (15 scripts), `regression-arbiter`, `regression-orphan-reaper` | pre-commit (≤20s) + full (slow) |
| pre-commit hook | `tools/hooks/pre-commit` | `regression-git-commit-mine-hook`, `regression-precommit` (full) | pre-commit + full |
| commit wrapper | `tools/git-commit-mine` `tools/git-commit-mine-lib.sh` | `regression-git-commit-mine`, `regression-git-commit-mine-hook`, `regression-commit-concurrency` | pre-commit |
| dispatcher (bin/dispatch) | `bin/dispatch` `tools/directive_policy.py` `tools/fleet_caps.py` | `regression-dispatch`, `regression-dispatch-caps`, `regression-duplicate-dispatch`, `regression-directive-*`, `regression-one-dispatch-path` (full) | pre-commit + full |
| subagent (bin/subagent, bin/ollama-subagent) | `bin/subagent` `bin/ollama-subagent` | `regression-subagent-*`, `regression-depth-enforcement`, `regression-inbox-loop`, `regression-ollama-dispatcher`, `regression-session-capture` | pre-commit |
| dispatch-verify | `tools/dispatch_verify.py` | `regression-dispatch-verification`, `regression-one-dispatch-path` (full), `regression-runner-brief-telemetry` | pre-commit + full |
| argus | `bin/argus` | `regression-argus-doctor` (state-dependent) | full |
| keeper | `tools/fleet-keeper.sh` `tools/fleet-cooldown.sh` `tools/window_policy.py` | `regression-fleet-keeper` (full), `regression-window-resilience` | pre-commit + full |
| token ledger | `tools/token-capture.py` | `regression-token-capture`, `regression-session-capture` | pre-commit |
| model labels | `tools/model_tags.py` `tools/model-profiles.py` `tools/attribution-backfill.py` | `regression-canonicalizer-parity`, `regression-model-profiles`, `regression-attribution-backfill`, `regression-managent-models`, `regression-managent-attribution` | pre-commit |
| bakeoff / race | `tools/bakeoff.sh` `tools/race-p0-verify.sh` `tools/race-collect.py` | `regression-bakeoff-gates`, `regression-race-p0`, `regression-race-collect` | pre-commit |
| suite gates | `tools/suite-truth.sh` `tools/smoke.sh` `docs/infra/suite-truth.md` `docs/infra/suite-truth-manifest.md` | `regression-suite-surfaces`, `regression-precommit` (full) | pre-commit + full |
| deploy | `tools/deploy.sh` | deploy-check arms inside several `regression-managent-*` scripts + `tools/smoke.sh` | pre-commit |
| acceptance | `tools/orcha-acceptance.sh` | `regression-orcha-acceptance` | pre-commit |
| pilot gate | `tools/pilot_gate.sh` | `regression-pilot-gate` (slow) | full |
| complementarity | `tools/complementarity.py` | `regression-complementarity` | pre-commit |
| battery compare | `tools/battery-baseline-compare.py` | `regression-battery-baselines`, `regression-battery-sweep` (need a build-wired binary arg — NOT standalone) | full (build-wired) |
| request accounting | `tools/request-accounting.py` | `regression-request-accounting` | pre-commit |
| status docs | `docs/status/` | `regression-status-doc-truth` | pre-commit |
| arbiter (T821) | `tools/runner` (admission half) | `regression-arbiter` | pre-commit |
| **core engine** | `src/retro.zig` `src/oracle.zig` `src/rules.zig` `src/solve.zig` `src/state.zig` `src/superko.zig` `src/colex.zig` `src/zobrist.zig` `src/terminal.zig` `src/score.zig` `src/enumerate.zig` | `zig build test` module unit tests (inline `test` blocks) — no `regression-*.sh` | full |
| **experiments / tables** | `src/exp*.zig` `src/t*.zig` `src/vb_*.zig` `src/*_census.zig` `src/*_differential.zig` `src/qa023_*.zig` | `zig build test` module targets | full |

**UNKNOWN suites (recorded honestly, not invented):** the engine and experiment modules have no
per-module `regression-*.sh` script; their suite is the `zig build test` module step, which the
pre-commit selection does not run (it runs scripts, not `zig test` targets). Wiring engine unit
tests into a per-module fast check is a follow-on row, not this one.

### 9.1 The budget argument (tension a), resolved

Serial wall of the largest declared pre-commit suite (`src/managent`, ~25 scripts) is ~90 s — over
the 45 s fast-tier budget. Two halves close the gap, neither alone is enough:

1. **Tiered placement** (§9 rule): scripts > 20 s standalone (`regression-dispatch` 26 s,
   `regression-one-dispatch-path` 49 s, `regression-store-pollution` 33 s, `regression-claim-lifecycle`
   25 s, `regression-argus-doctor` 46 s, `regression-pilot-gate` 48 s, `regression-precommit` 41 s,
   `regression-runner-reap` 49 s, the four sleep/poll scripts at >60 s, and the two battery scripts
   that need a build argument) are NOT selected at commit time — they run in `zig build test`.
2. **Bounded parallelism** (`TEST_GATE_WORKERS=6` in the hook): the selected scripts run concurrently;
   wall is dominated by the single slowest selected script (~15 s `regression-managent-landmark`), so
   the `src/managent` selection lands ~25–35 s wall, under budget. **One carve-out, found by running
   the gate inside a real commit:** the `regression-claimlint-*` scripts run SERIALLY (one at a time,
   before the parallel batch) because they create and remove transient fixtures in `findings/` and
   `docs/evidence/`; under parallel execution the fixture races the byte-identity and count controls
   (two claimlint scripts failed only when run concurrently, 2026-08-24). Serializing those five ~1–2 s
   scripts costs ~7 s and removes the race; everything else parallelizes.

Measured 2026-08-24 (upper bounds, standalone, `tools/runner --max-wall 60`): largest single
pre-commit-tier script is `regression-runner-pi-session-liveness` at 20 s; `regression-managent-landmark`
15 s; the rest ≤ 18 s. The hook prints its own elapsed wall on every commit (`fast tier elapsed Ns`).

## 10. Contract declarations (T861 — select)

Format (parsed by `tools/hooks/pre-commit`, unchanged): `test <script> covers <prefix…>` where each
prefix is a module path prefix (exact file, or a directory that also matches `prefix/*`). Scripts
listed here but absent from the fast pool are now **selected** when a staged change touches their
coverage; a pool script with no `covers` line still always runs.

<!-- machine: test-coverage (do not reorder; parsed at line start) -->
<!-- tools/smoke.sh is deliberately NOT declared: it is the one always-run fast-pool script
     (in-pool + no coverage = always), which keeps SELECTED non-empty and preserves the
     "unknown coverage is not empty coverage" invariant. -->
test tools/regression-claimlint-output.sh covers src/claimlint.zig src/absorb.zig src/claims_register.zig docs/epistemic/CLAIMS.md docs/epistemic/PROGRESS.md docs/evidence findings
test tools/regression-claimlint-c7-json.sh covers src/claimlint.zig src/absorb.zig src/claims_register.zig findings
test tools/regression-claimlint-c7-scope.sh covers src/claimlint.zig src/absorb.zig src/claims_register.zig docs/epistemic/CLAIMS.md findings
test tools/regression-claimlint-promotion.sh covers src/claimlint.zig src/absorb.zig src/claims_register.zig docs/epistemic/CLAIMS.md
test tools/regression-claimlint-volatile.sh covers src/claimlint.zig src/absorb.zig src/claims_register.zig
test tools/regression-orient.sh covers src/managent
test tools/regression-directive-id-uniqueness.sh covers bin/dispatch tools/directive_policy.py src/managent
test tools/regression-directive-integrity.sh covers bin/dispatch tools/directive_policy.py src/managent docs/epistemic/CLAIMS.md
test tools/regression-managent-models.sh covers src/managent tools/model_tags.py tools/model-profiles.py
test tools/regression-managent-landmark.sh covers src/managent
test tools/regression-suite-surfaces.sh covers tools/suite-truth.sh docs/infra/suite-truth.md docs/infra/suite-truth-manifest.md src/evidence.zig src/evidence_control.zig
test tools/regression-canonicalizer-parity.sh covers tools/model_tags.py tools/model-profiles.py tools/attribution-backfill.py src/managent
test tools/regression-absorption-machinery.sh covers src/absorb.zig src/claims_register.zig docs/epistemic/CLAIMS.md
test tools/regression-arbiter.sh covers tools/runner
test tools/regression-attribution-backfill.sh covers tools/attribution-backfill.py tools/model_tags.py
test tools/regression-bakeoff-gates.sh covers tools/bakeoff.sh
test tools/regression-complementarity.sh covers tools/complementarity.py
test tools/regression-depth-enforcement.sh covers bin/subagent
test tools/regression-duplicate-dispatch.sh covers bin/dispatch
test tools/regression-git-commit-mine-hook.sh covers tools/hooks/pre-commit tools/git-commit-mine tools/git-commit-mine-lib.sh
test tools/regression-gtp-boardsize.sh covers src/gtp.zig
test tools/regression-inbox-loop.sh covers bin/subagent tools/directive_policy.py src/managent
test tools/regression-managent-attribution.sh covers src/managent
test tools/regression-managent-build-mode.sh covers src/managent tools/deploy.sh
test tools/regression-managent-concurrency.sh covers src/managent docs/epistemic/CLAIMS.md
test tools/regression-managent-done-git.sh covers src/managent docs/epistemic/CLAIMS.md
test tools/regression-managent-done-two-phase.sh covers src/managent
test tools/regression-managent-duty.sh covers src/managent
test tools/regression-managent-lanes.sh covers src/managent
test tools/regression-managent-ledger-board-seam.sh covers src/managent
test tools/regression-managent-resume.sh covers src/managent
test tools/regression-managent-standing.sh covers src/managent docs/epistemic/CLAIMS.md
test tools/regression-managent-store-write-utf8.sh covers src/managent tools/deploy.sh
test tools/regression-model-profiles.sh covers tools/model-profiles.py
test tools/regression-ollama-dispatcher.sh covers bin/ollama-subagent bin/subagent
test tools/regression-orcha-acceptance.sh covers tools/orcha-acceptance.sh
test tools/regression-orphan-reaper.sh covers tools/runner
test tools/regression-race-collect.sh covers tools/race-collect.py
test tools/regression-race-p0.sh covers tools/race-p0-verify.sh
test tools/regression-request-accounting.sh covers tools/request-accounting.py
test tools/regression-runner-agent-progress.sh covers tools/runner
test tools/regression-runner-brief-telemetry.sh covers tools/runner tools/dispatch_verify.py
test tools/regression-runner-claude-liveness.sh covers tools/runner
test tools/regression-runner-harness-p95.sh covers tools/runner
test tools/regression-runner-pi-session-liveness.sh covers tools/runner
test tools/regression-runner-reporting.sh covers tools/runner
test tools/regression-runner-run-records.sh covers tools/runner tools/attribution-backfill.py
test tools/regression-runner-startup-liveness.sh covers tools/runner
test tools/regression-runner-taskid.sh covers tools/runner
test tools/regression-runner-worktree.sh covers tools/runner tools/bakeoff.sh
test tools/regression-scratch-repo.sh covers tools/runner tools/hooks/pre-commit
test tools/regression-session-capture.sh covers tools/token-capture.py bin/subagent
test tools/regression-status-doc-truth.sh covers src/managent docs/status
test tools/regression-store-census.sh covers src/managent
test tools/regression-T227.sh covers src/managent
test tools/regression-token-capture.sh covers tools/token-capture.py
test tools/regression-commit-concurrency.sh covers tools/git-commit-mine tools/git-commit-mine-lib.sh
test tools/regression-directive-kill.sh covers bin/dispatch tools/directive_policy.py src/managent
test tools/regression-dispatch-caps.sh covers bin/dispatch tools/fleet_caps.py src/managent
test tools/regression-dispatch-verification.sh covers tools/dispatch_verify.py
test tools/regression-git-commit-mine.sh covers tools/git-commit-mine tools/git-commit-mine-lib.sh
test tools/regression-managent-assert-store.sh covers src/managent
test tools/regression-managent-holds.sh covers src/managent
test tools/regression-managent-impression-gate.sh covers src/managent
test tools/regression-managent-integrity.sh covers src/managent
test tools/regression-managent-lock.sh covers src/managent
test tools/regression-managent-status-json.sh covers src/managent
test tools/regression-subagent-prompt.sh covers bin/subagent
test tools/regression-task-id-archive.sh covers src/managent
test tools/regression-task-identity.sh covers src/managent
test tools/regression-window-resilience.sh covers tools/window_policy.py tools/fleet-keeper.sh

**Not declared** (deliberately — they run in `zig build test`, not pre-commit selection):
`regression-argus-doctor` (state-dependent), `regression-battery-baselines`/`regression-battery-sweep`
(need a build-wired binary arg), `regression-claim-lifecycle` (25 s), `regression-dispatch` (26 s),
`regression-fleet-keeper` (sleeps, >60 s), `regression-managent-memory-safety` (>60 s),
`regression-managent-store-pollution` (33 s), `regression-one-dispatch-path` (49 s),
`regression-pilot-gate` (48 s), `regression-precommit` (41 s), `regression-process-ownership` (>60 s),
`regression-runner-reap` (49 s), `regression-watch-fleet` (>60 s). The two vacuous exit-0 stubs
(`regression-runner-host-guard`, `regression-subagent-resident-gate`) are also not declared — they
are delete candidates, not coverage.

## 11. Known-red baseline (T861 — dated, per-script, owned, expiring)

**Why this exists:** 24 of 88 `regression-*.sh` fail standalone today (measured 2026-08-24, each run
via `tools/runner --max-wall 60 -- sh <script>`, the same invocation the hook uses). If the gate
selected real suites and blocked on every red, any change touching a red module would freeze. This
baseline is the **temporary** resolution: the gate treats a baseline hit as *known red, non-blocking*,
and still **refuses any failure not in the baseline** (a NEW red). It is per-script, never a blanket
"ignore failures" switch.

**RATCHET DISCIPLINE (operator correction D084, 2026-08-24) — this is a temporary device:**

- **Target: ZERO red.** This baseline is not a permanent "no new failures" floor; it is the worklist
  for `stream2b-green`, which fixes or deletes every entry below and then deletes this section.
- **Deletion requires ALL of:** (1) `stream2b-green` resolves every entry — repair, re-point the
  fixture, or delete the script/arm, with the disposition column below obeyed; (2) a fresh full sweep
  of `tools/regression-*.sh` (standalone, same invocation) shows zero non-baseline failures AND zero
  baseline entries still failing; (3) `tools/hooks/pre-commit` drops the `known-red` read (the
  `KNOWN_RED_FILE` block) — the gate must refuse any failing script once the baseline is gone.
  **The file must not be emptied and left behind; it must be DELETED, or the per-script rule has
  silently become a blanket one.**
- **Expiry condition:** this section is void the moment `stream2b-green` closes with all entries
  green or deleted; if that has not happened by 2026-09-07 (two-week review), the Orchestrator must
  re-ratify it — a ratchet that outlives its review is the exact failure D084 forbids.

**Delete vs repair (D084):** of the 24, **one is a delete-or-repoint** — `regression-runner-guard.sh`
tests the host-guard memory-pressure kill that T821 deleted; its seeded arm can never fire again, so
the script must be re-pointed at the T821 arbiter behavior or deleted. Everything else is a repair
(fix code or re-point a drifted fixture), except the slow/needs-arg entries marked `not-precommit`
(they stay in `zig build test`; nothing is wrong with them for pre-commit purposes). Two further
**delete candidates are NOT red** — the vacuous exit-0 stubs `regression-runner-host-guard.sh` and
`regression-subagent-resident-gate.sh` pass but assert nothing (whatis C5/C6); `stream2b-green` must
delete them as part of zero-red, not fix them.

Owner = the owning row that must resolve it (or `stream2b-green` when triage is that sprint's job).
Disposition vocabulary: `repair` (fix code/fixture) · `repoint` (re-aim the assertion) · `delete` ·
`deploy` (self-heals via `zig build deploy-*`) · `not-precommit` (slow/stateful; full-suite tier).

<!-- machine: known-red (format: known-red <script> <owner> <disposition>; parsed at line start) -->
known-red tools/regression-argus-doctor.sh T442 repair
known-red tools/regression-battery-baselines.sh stream2b-green not-precommit
known-red tools/regression-battery-sweep.sh stream2b-green not-precommit
known-red tools/regression-claim-lifecycle.sh stream2b-green repair
known-red tools/regression-commit-concurrency.sh stream2b-green repair
known-red tools/regression-directive-kill.sh T682 repair
known-red tools/regression-dispatch-caps.sh stream2b-green repair
known-red tools/regression-dispatch-verification.sh D021 repair
known-red tools/regression-fleet-keeper.sh stream2b-green not-precommit
known-red tools/regression-git-commit-mine.sh T454 deploy
known-red tools/regression-managent-lock.sh T337 repair
known-red tools/regression-managent-memory-safety.sh stream2b-green not-precommit
known-red tools/regression-managent-status-json.sh stream2b-green repair
known-red tools/regression-process-ownership.sh stream2b-green not-precommit
known-red tools/regression-subagent-prompt.sh stream2b-green repair
known-red tools/regression-task-id-archive.sh stream2b-green repair
known-red tools/regression-task-identity.sh stream2b-green repair
known-red tools/regression-watch-fleet.sh T466 repair
known-red tools/regression-window-resilience.sh stream2b-green repair
