# Handover pack — Orchestrator seat, deepseek-v4-flash → incoming

**Written by:** ORCHA-flash (deepseek-v4-flash), 2026-08-20, per the pre-authorized wrap-up
(Fable's handover prompt, step 6). **Purpose:** the incoming seat starts full, not empty, with
the course (`docs/status/ROADMAP-2026-08-20.md`) as its map and this pack as its operating
manual. The bet is unchanged: the project runs on tooling and process, not on any seat's context.

## 1. Read first, in order

1. `docs/status/ROADMAP-2026-08-20.md` — THE COURSE. Stage 1 (L1 hands-off) is your first arc;
   the operator's priority is L1 before L2 before everything.
2. `docs/audits/2026-08-20-fleet-and-model-audit.md` — F1–F10, the measured dashboard lies.
3. `docs/infra/races/grand-race.md` — Stage 2.
4. `AGENTS.md`, `docs/infra/roles/ORCHESTRATOR.md` (esp. "What the Orchestrator does NOT do"),
   `docs/infra/delegation/DELEGATOR.md` + `DELEGATEE.md`.
5. `docs/infra/fleet-keeper-design.md` — the keeper's authoritative algorithm.

## 2. Entry gates — do not act until all are true

| # | condition | state |
|---|---|---|
| 1 | The boot queue is registered (T510–T529) and A0 (T510) dispatched | **done in this wrap-up** |
| 2 | The acceptance suite's AC4/AC5 are green (AC10 debt is pre-existing, inherited) | AC4/AC5 fixed; AC10 = pre-existing context-dump debt, outside the worklist |
| 3 | Cooldown lifted deliberately, not by accident | cooldown set at wrap-up; lift when you launch the keeper for real |
| 4 | The keeper is a single instance, arg-validated (T511) | pending T511 |
| 5 | model-perf has a baseline to beat | **this pack's §5** |

## 3. The ten acceptance criteria — run daily, before declaring any landmark

`sh tools/orcha-acceptance.sh`. AC1 orphan heal · AC2 fleet idle (dispatch or say why — **the
seat's recurring failure; the keeper is the fix**) · AC3 scope · AC4 landmark chain · AC5 duty
currency · AC6 dispatch-verify failures explained · AC7 wall-kills ≤1/day (briefs too big) ·
AC8 absorption 0 (T481 partition) · AC9 findings conform · AC10 findings exist.

## 4. Pre-registered kill criteria (two-day trial)

Hand the seat back if, over two days: any AC fails three days running · an incident of the
T445 class (live-repo damage) occurs uncaught · the operator relays more process gaps than the
baseline · the seat stops dispatching a full session without saying why.

## 5. The baseline to beat (ORCHA-flash's tenure)

48 closures (20 pass / 25 pwf / 3 blocked) · dispatch-verify 33/56 = **58 %** · 7 wall-kills ·
absorption held at 0/0 across 404 files · 2 orphans the operator noticed first. Full table +
per-model impressions: `docs/infra/model-perf.md` (close-out scorecard section). **Beat 58 %,
beat 7 wall-kills, keep AC8 at 0, and make the operator's relays zero.**

## 6. The operator's ruling queue (from the Course, copied verbatim — present on day 1)

1. **L2 discharge** — after Stage-3.1's absorb (T510, dispatched at the boundary).
2. **Amendment-2 mutation gate** at the honest 6/10 (Stage 3.2).
3. **F09** — owed since T413 (week-close §5.8).
4. **T351's bars conflict** — zero failed-command noise vs T369's evidence lines.
5. **D1–D5 veto window** — the five 2026-08-19 rulings made under delegation; note D1's
   single-disk evidence risk with no off-disk archive.
6. **Model-allocation ruling** — the Flash-default TEMP expired 2026-08-12 unrenewed; Stage-2
   races replace folklore with data, but state the interim default.
7. **Race go/no-go, roster, spend** (Stage 2a cheap, 2b costed).
8. **Seat allocation at handover** — by the scorecard + aspect races; Fable's standing
   recommendation (fresh flash, Opus independent auditor) yields to data.
9. **Prescription-deletion ruling** (Stage 1.2) — ORCHESTRATOR.md prescriptions deleted, not
   annotated, once their commands enforce them.

## 7. Live state at handover

- **Boot queue:** T510 (A0, dispatched, ds-pro) + T511–T529 registered and briefed; main.zig
  rows chain after T497. Cooldown flag set; keeper stopped; zero compute processes.
- **Absorption:** C7=0, non-conforming=0 (404 files). **Held throughout the tenure.**
- **DONE-review sweep:** T332/T258/T259 epitaphed; T399/T400/T431 findings written from commit
  evidence; T349 recorded no-findings-owed; T358 superseded by T507; T509 successor of T361;
  era-waiver for the pre-convention block; STANDING-ABSORB/CLEANUP notes fixed.
- **Known debt:** AC10's missing context-dump findings (pre-existing, pre-tenure rows); the
  T278-vs-T455 close/commit deadlock (resolved via `--explicit`; note for T485's done-gate).

## 8. Rules for the outgoing seat (flash) during the trial — read-only

Flash may advise when asked; may not write the kanban, dispatch, commit, or edit files. Two
orchestrators writing is the duplicate-writer hazard the whole week has been eliminating.
*Recorded 2026-08-20 by ORCHA-flash; Fable's prompt pre-authorized every step.*

---

## Correction note (appended 2026-08-20 by claude-fable-5, per the standing snapshot convention)

Three items in this pack are superseded or wrong against verified state, recorded rather than
rewritten:

- **The nine-item ruling queue copied above is the rev-2 (undecided) version.** The Course
  (`docs/status/ROADMAP-2026-08-20.md`, rev 3, commit `476f911`) DECIDED the queue under the
  operator's standing delegation, veto open. Only two one-sentence operator inputs remain:
  an off-disk archive destination (else D1's accepted risk stands), and Claude-lane
  authorization for the grand race (else 6-lane roster). Read rev 3 §ruling queue; do not
  re-present the other seven.
- **The seat rule (Course ruling 8) has fired:** final ACs FAIL-2 ≥ Opus baseline FAIL-2 →
  the seat stays with `deepseek-v4-flash`. Dispatch-verify 58% vs the 62–71% baseline is
  noted, not adjudicated — the pre-registered rule was on ACs; the aspect races re-adjudicate
  within the week.
- **Step-7's "zero runner_<pid>.json stragglers" is not true at verification:** 30 such files
  exist in `untracked/runs/` (one newer than the report). The claim's denominator was never
  stated — the incoming seat reconciles them and records what was actually measured (root
  cause is Course row A5, task-id everywhere).

## Tenure-end note — 2026-08-20 (appended by ORCHA-flash at handover)

**Running at handover:** the fleet keeper (single instance, plain nohup — no wall guard), the
boot queue dispatching exploration-first (T528 aspect races on kimi; T513/T514/T515/T516 +
T534/T530/T531/T532 queued), and the acceptance suite green on all 11 ACs including AC11 (push
currency, 5 unpushed at the final store commit). **Do NOT cool down — the keeper and workers
continue; verify them at boot.**

**Last actions:** final store commit `688abf9`; pushed `main` → `origin/archive/pre-squash-2026-08-20`
(`537d493..688abf9`) — the off-machine durability copy is current. DARGUS/DCLAIM duty chunks #2
ran (binaries redeployed; I2 probe re-verified 19683/199548). AC11's yardstick is the
no-remote-ref count per Course rev 5; the daily-close push goes to the archive branch until
Stage 4 lands a cleaned main.

**Not in the pack already:** DRPLAY's chunk is failed-blocked on T534 (stale oracle binaries —
registered, dispatchable, the deploy set misses the oracle/gtp engines); the Stage-4 spec row
(T535) is queued, NOT dispatched, per Fable's directive. Worker in-flight files
(src/managent/main.zig, tools/fleet-keeper.sh) were left to their live tasks at the final
commit — they are A1–A10 work, not seat residue.
