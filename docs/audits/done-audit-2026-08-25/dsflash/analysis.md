# DONE-audit arm analysis — dsflash (T947)

**Auditor:** deepseek-v4-flash/T947 · **Date:** 2026-08-25 · **Landmark:** L1 (the dashboard tells the truth)
**Rows audited:** 24 (12 disjoint `dsflash` slice + 12 shared control). All 24 reached — none left unexamined.
**Collector:** `collector.py` (in this directory) gathers the mechanical fields from `tasks.json`,
`untracked/runs/`, bundle headers, `findings/`, and git; `collector-output.json` is its raw output.
The thinking half (judgement fields) was done by hand per row against the bundle briefs, run records,
commit timelines, and downstream citations.

## Census

| Judgement | tally |
|---|---|
| `verdict_accurate` | **yes 23 / no 1** — the single `no` is T943 (auto-closed `pass` while its own declared acceptance was RED on a clean host). |
| `work_actually_done` | complete 18 / partial 3 (T730, T924, T387) / none 3 (T921, T842, T841) |
| `absorbed` | **yes 17 / no 4 / partial 3** — the four `no`s are T730, T921, T842, T841; three of the four are rows that produced nothing (true negatives, correctly closed). T730 is the absorption failure that matters: real work, zero git. |
| `self_reported_or_verified` | **verified 21 / self-reported 1 / unverifiable 2** — 21/24 rows have an artifact other than the worker's own assertion establishing the outcome (committed deliverable, downstream citation, or my own independent run of their regression). |
| `useful` | yes 18 / mixed 4 (T730, T777, T842, T387) / no 2 (T921, T841) |

Independent verification performed by this auditor (regressions I actually ran, all green):
`tools/regression-sleep-guard.sh` (T927), `tools/regression-store-loss.sh` (T944), `tools/regression-queue-ordering.sh` (T894),
`tools/regression-finishparallel-partition.sh` (T932), and T916's delivered runner-guard regression (its race-lane
copy under `untracked/` — 25/25 green, 5/5 red caught).

## The rows I would re-open / amend

1. **T943 — amend the verdict.** The row is closed `pass` by the tools/runner auto-close on process evidence
   (exit 0 + deliverables present) while its own declared acceptance test was RED on a clean host (harness-caffeinate
   false positive). T935 already recorded the defect in a commit (`35fd322` "T943 closed pass with its own acceptance
   failing") and T952 is the stalled follow-up, but the store verdict itself still says `pass`. It should be
   `pass-with-findings` (the work is real; the close gate malfunctioned). This is the one row where the record says
   something materially false about what happened.
2. **T730 — commit the orphaned findings.** The row is correctly closed `blocked` (the load-bearing input, slots
   A–K, never existed), but both `findings/T730-race-g-science-grade.json` and `findings/T730-ruling.json` sit
   **untracked on disk** (`git status` shows `??`). A substantive key-blind ruling plus a race-compromise finding
   (T731 repaired the register mid-race, erasing seeded canaries) exists only on this host. Commit the two files,
   or a follow-up row; until then the work is write-only. (This is the corpus trap "a row whose deliverables are in
   git may not have written them" inverted: the row **did** write them and **no one** committed them.)
3. **T387 — no re-open; note the gate hole.** The store's `verdict_note` for T387 is literally `--fail (no note
   provided)` — the reasonless-close hole that T490 later named and fixed. The row itself is honest `blocked`
   (the u6 wrap hang was real); the DAG readings were salvaged via T397 and the Bellman consistency reading was
   never taken. Nothing to change in the store; the gate hole is already being retired.

## The no-acceptance stratum in my slice (T459, T470, T916)

All three rows in this stratum were graded blind / produced an artifact with **no** machine `acceptance=` command.
All three nevertheless check out as verified and absorbed: T459's scores were consumed by the T452 race record
(`docs/infra/races/race-corpus.md` row 29), T470's policy is cited by `docs/audits/2026-08-20-fleet-and-model-audit.md`,
and T916's regression passes when I run it. Absence of a machine gate did **not** correlate with fabrication in my
slice — the downstream consumers did the verifying. (The sample is 3 rows; that is a weak claim, stated as such.)

## Who committed, and when — the attribution check

Commit author name is **not** a reliable attribution signal in this repo: worker commits before ~2026-08-24 carry
the `T278` identity; after that, nearly all commits (worker and orchestrator alike) carry the human's name. The
reliable signal is **timing relative to the run window**:

- Committed inside the lane window (worker wrote + committed, or seat committed at close): T459, T470, T619, T624,
  T793, T777, T853, T884, T932, T927, T943, T944, T916, T929, T555 (via OWNER-LOG).
- Committed **after** the worker's process exited, by another seat: **T894** (worker exited 0 at 09:16:44Z without
  committing or closing; T935 committed at 09:30:10Z and closed 09:31:16Z), **T924** (deliverables recovered from
  the transcript by the T914 seat; the doc header says so explicitly), **T907** (work complete but commit refused by
  the pre-commit hook; committed by the human at 594d860 ~3.4h after close), **T387** (salvaged by T397),
  **T555** (findings file written retroactively by T557).
- Never committed at all: **T730** (both findings untracked on disk).

T924 is the named trap in the corpus — "deliverables in git may not have been written [by the worker]" — and it is
real: the lane exited 0 without writing, and everything was recovered from the transcript. The row's close is honest
(pwf, with the correction acknowledged), which is exactly what the trap says: deliverable-presence checking alone
would have missed the defect.

## The single most important pattern

**The done gate closes on process evidence — exit 0 plus deliverable *presence in the working tree* — and that is
not the same as the acceptance passing, and not the same as the deliverable being in git.** Three of the four
defects in my slice are this one gap, at three different stages:

- **T943** — auto-close on exit 0 + presence, never ran the acceptance; the acceptance was RED.
- **T894** — exit 0, deliverables in the tree, but uncommitted; the row could only be closed by a second seat
  recovering the tree (which it did, honestly, within an hour).
- **T730** — closed `blocked` with deliverables in the tree that no one ever committed; two findings files are
  still `??` in `git status`.
- **T924** — exit 0, deliverables *nowhere* on disk; recovered from the transcript.

The rows that go right in this slice (T932, T927, T944, T916) are the ones with a machine-checked acceptance or a
deliverable the auditor can run — the gate works when there is a command behind it. The rows that go wrong are the
ones where the gate's evidence was "the process exited" and "the file is there."

**What would disprove it:** a closed-`pass` row whose recorded acceptance result was captured at close time and
matched the verdict — i.e., the store carried the acceptance's exit code / output, and the verdict tracked it.
T943 is the control arm of this test and it fails: the store says `pass`, the acceptance was red, and the failure
is only recoverable from a later seat's commit message. A second confirming instance (another `pass` whose
acceptance was red at close) would strengthen it; the T935/35fd322 record suggests the fleet already knows.

## Caveats

- `wall` is null for T459/T470/T555/T387/T421/T921 — those runs predate or escaped the `untracked/runs/` capture;
  the schema's wall field is then honestly null.
- T619's findings file header declares `"verdict": "pass-with-findings"` while the store says `pass` — a small
  label drift, noted in the record, not load-bearing.
- T555's bundle declared deliverable path `docs/infra/orcha-refactor/pass1/OWNER-LOG.md` **does not exist in HEAD**
  and never did; the work is recorded at `docs/epics/E1-markovian/L1-dashboard/S01-process-ownership/pass1/OWNER-LOG.md`.
  A declared-path defect in the bundle, not in the work.
- The control-slice ground truths in the sealed key and this arm's independent findings agree on all 12 control
  rows, including the two hard ones (T924's wrong headline number, T943's flawed auto-close) — this arm would flag
  the same rows the key expects flagged.
