# Impact report — second Claude window expiry, 2026-08-22 17:34Z

**Scope:** the second five-hour Claude session-limit expiry of the day, and what it cost.
Compare `docs/epics/E1-markovian/L1-dashboard/S02-model-delegation/race-g-claim-doubt/wall-canary-preregistration.md`,
written at ~14:55Z *before* any of these lanes launched. This is the first live test of the
outage path against expectations recorded in advance rather than reconstructed afterwards.

## What happened

    You've hit your session limit · resets 8pm (Europe/Oslo)

One lane was live and was lost: **T654** (`claude-opus-5`, Race C grader), killed at
**17:34:15Z**, wall 835.3 s, rc=1. Every other lane of the round — T649 (Fable arbiter), T655,
T656, T657, T658, T650, T651, T652 — had already landed and passed verification.

## Cost, stated against the 12:47Z outage

| | 12:47Z (first) | 17:34Z (second) |
|---|---|---|
| lanes killed | 5 | **1** |
| false model-failure rows written | **5** | **0** |
| Claude wall discarded | ~39 min | **0 min — the artifact survived** |
| classified by machine | no — hand-annotated DO NOT SCORE | **yes** |
| zombie rows left | 1 (T616) | 0 *from the outage* (but see §Two new defects) |
| discovered by | the operator asking | the ledger, mechanically |

**The deliverable survived.** `findings/T654-race-c-grade.json` is 46 KB and carries
`control_check`, `my_rulings_on_the_twelve_inputs`, `per_scorer_grade` and `ranking` — the lane
had done the work and flushed it. Only the closing `verdict` field is unset. This is the third
time today the incremental-flush mandate turned a kill into a prefix instead of a loss
(T638, T641, now T654), and it is the evidence behind the §7c.33 amendment.

## The pre-registered expectations, scored

| # | expectation | outcome |
|---|---|---|
| 1 | dies with the provider's own text, rc=1 | **met** |
| 2 | classifier reads provider-limit from the terminal record | **met** — `verified=unreached reason=provider-429` |
| 3 | `killed_by = provider` if T629 landed | **met** — `killed_by=provider-limit`; T629 had landed at 15:02Z |
| 4 | **row reopens unscored; no `fail=row`, no model-performance failure** | **met — and this is the one that failed last time** |
| 5 | family cooldown written *if T628 landed* | **did not happen, exactly as predicted** — T628 is undispatched. Gap confirmed, not discovered |
| 6 | single probe lane at reset before any fan-out | **not exercised** — nothing was dispatched after the wall |
| 7 | wall-killed artifact salvage-adjudicated before re-running | **met** — checked before anything was re-dispatched |

Four testable expectations met, one confirmed-absent as predicted, two unexercised. **Nothing
in the fix behaved differently from how it was written down in advance.** That is the result
worth keeping: the classifier had only ever been tested against replayed fixtures, and it held
against a real wall.

## Two new defects, neither caused by the outage

**A. `T643` is a zombie, from a directive-kill false positive.** T643 (`deepseek-v4-pro`) — the
row sent to fix the progress watchdog — was killed **by the progress watchdog** at 1706.8 s. Its
run record is correct: `killed: progress timeout 600s`, `signal 9`, `killed_by: watchdog`. But
`dispatch_verify` recorded:

    [verify] worker stopped by directive unknown/pause/kill — verification FAILED (directive kill…)
    [verify] not healed: worker killed by directive unknown/pause/kill (kill) — row left in_progress

Two failures compounding. The classification contradicts the runner's own record — the authority
ruling 31 named. And because a directive kill legitimately suppresses the heal (a deliberate stop
should not be auto-reopened), the misclassification **converted itself into a stuck row**. T643's
findings file is on disk and complete; only the row is wrong.

This is the **third instance of one class**: a classifier matching text the worker was working
*on*. The refusal classifier matched a quoted 429 (T526) and the word "quota" (T601); the
directive classifier has now matched a row whose entire subject is the kill machinery. T652's
harness-symmetry audit predicts these structurally; this one arrived before the audit reported.

**B. Worker closing assessments die in the console.** The operator's catch. A worker's final
reply — its surprises, caveats and "possible follow-up" — reaches the console and
`untracked/log/t<id>.log` and **nowhere else**. The findings file holds the result; the closing
reply holds the judgement *about* the result. Recovered verbatim today to
`docs/status/recovered/console-assessments-2026-08-22.md`. What was nearly lost:

- **T651 (autopilot keeper):** *"the keeper inherits `WEIZIGO_AGENT_DEPTH`, so it must run from
  launchd/operator at depth 1 — a keeper started from a worker console would refuse every
  firing."* A deployment landmine that would have presented as a silently dead autopilot.
- **T651:** the bundle's `deliverables=` omitted the wired test file and the launchd plist; both
  shipped under a recorded `--explicit` commit.
- **T657 (Race C grade):** the S1 premise is **doubly** false, so that trigger measured
  premise-checking rather than proactivity — a fixture confound that must reach T583 before any
  re-run.
- **T635:** "harness-fits-scope" has no mechanized check; it rides the row's `exclude=` channel
  because it depends on runtime state the function cannot see.

## A discrepancy to resolve, not to average

T634 and T643 both computed DeepSeek p95 wall and disagree: **2340.9 s (n=113)** versus
**2445.05 s (n=66)**. T643 excluded the T542 bakeoff gate sub-runs and counted only finalized
non-killed runs. Different denominators, and the smaller, more carefully filtered one is
probably the better number — but the two fuses now in `tools/runner` were derived from different
figures. Someone should reconcile them and state which population a liveness threshold ought to
be drawn from; a killed attempt's wall is not a sample of how long the work takes.

## Standing

No re-dispatch of any killed row until **T650** (run records never overwritten) is absorbed —
a retry currently destroys the killed attempt, which is ruling 32's censored row. T650 passed
verification; absorption is owed before the next retry.
