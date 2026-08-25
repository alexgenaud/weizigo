# T956 — DONE audit, qwencloud arm — analysis

**Auditor:** qwen3.8-27b/T956 · **Date:** 2026-08-25 · **Slice:** 12 disjoint (T792, T679, T618,
T803, T648, T365, T799, T537, T573, T582, T506, T754) + 12 shared control (T932, T927, T894,
T924, T921, T943, T842, T841, T907, T387, T929, T421). All 24 rows reached; none unexamined.

**Method:** mechanical fields by `collector.py` (tasks.json + untracked/runs + findings/ +
git log); judgement half by hand per row — each row's bundle read, deliverables checked in git,
commit authorship/timing checked against the close, findings files read, downstream consumption
grepped. Host timezone is CEST (UTC+2); commit dates below are UTC where compared against the
store.

## Census (24 rows)

| field | count | rows |
|---|---|---|
| verdicts judged **accurate** | **22 / 24** | inaccurate: **T943** (pass over a red declared acceptance), **T907** (blocked understates 100%-complete work). T924 is counted accurate-as-status but its published number was wrong until T929 corrected it (flagged, not counted inaccurate) |
| work actually done: complete / partial / none | 19 / 2 / 3 | partial: T924 (published projection 7.585x high), T387 (Bellman-consistency reading never taken); none: T921, T842, T841 |
| **absorbed** yes / partial / no | 19 / 2 / 3 | partial: T387 (DAG readings + u6 fix reached git via T397, the Bellman-consistency reading never did), T754 (text only partially grafted into the winning lane); no: T921, T842, T841 (true negatives — honest, nothing to absorb). T679 counted yes with a flag: its findings file is untracked but its verdicts were executed downstream (T703, S09 spec) |
| **verified** / self-reported / unverifiable | **23 / 1 / 0** | self-reported: T943 (the pass rests on the runner's auto-close; the only machine gate was red at close). T387/T365/T421 have no run records (pre-run-record era) but their outcomes verify through committed artifacts — absence recorded, not inferred |
| useful: yes / mixed / no | 21 / 1 / 2 | mixed: T842 (no deliverable, exposed the per-model budget hole); no: T921, T841 (nothing produced, honestly closed) |

**No-acceptance stratum in this slice (5 rows: T679, T618, T803, T754 + T365 which declares
acceptance in the bundle but has acceptance=null in the store):** none of them was carried by a
machine gate at close time. Four of five were still verified by committed artifacts and
downstream use; T679 is the weakest link — its findings file is still untracked in git (a
write-only record that would die with the host), and its brief no longer exists (bundle="" after
the T716 backfill), so its deliverable list is unknowable from the store.

## The single most important pattern

**The close is the weak link, not the work.** Every *pass* row in this slice produced what its
brief asked for and put it in git — but three different mechanisms let the *verdict* diverge from
reality, and all three are store-side, not model-side:

1. **Automatic close outruns the gate** — T943 closed `pass` via `tools/runner` while its own
   declared acceptance was red on a clean host (the false-positive caffeinate attribution was
   only fixed ~5h later by T952).
2. **Blocked understates complete work** — T907's 233-claim adjudication was 100% done in-tree;
   the pre-commit hook tripped on a *sibling console's* dirty file, the row closed `blocked`, and
   a seat committed the work 3.5h later. A reader of the store would conclude the work failed.
3. **Store rollback silently re-closes** — T792/T803/T799 were "RECONSTRUCTED 2026-08-24 by the
   T771 seat" after the store reverted to a pre-T785 snapshot; the verdict history did not
   survive, and the close note is the only trace. T679's row was clobbered entirely until T716
   minted it back.

Disproof: if the Judge's cross-arm comparison shows other auditors flagging *work* quality
(defective code, answered-the-wrong-question) far more often than close-mechanism defects on the
same control rows, the pattern flips to "workers misdeliver and the store is honest" — I found
no such row in my 24.

## Rows I would re-open

- **T943** — the only inaccurate *pass* in the slice. Re-open as a verdict correction: the work
  was absorbed (inventory + repaired gate), so the honest fix is `pass-with-findings` with the
  red-gate close recorded, plus a runner rule that a row with a declared `acceptance=` cannot
  auto-close `pass` while that command is red.
- **T907** — re-close as `pass-with-findings`: the artifact has been in git since 594d860;
  `blocked` is a stale record of a commit failure, not of the work.
- **T679** — not a re-open of the verdict, but a *promotion*: commit the findings file (it is
  load-bearing — T703 and the S09 spec cite it) or re-run the census, because a cited record
  living untracked is the T421 failure mode this project already ruled against.

## Observations the mechanical collector surfaced (denominator: 24 rows)

- **3 rows have no run record and no attempts** (T365, T387, T421) — all pre-run-record era
  (2026-08-05/06/08). Recorded as absence, not inferred non-existence.
- **T573** is the clean example of the brief's named trap "a lane killed after flushing its
  work": wall-kill at 2700s (signal 9), but findings committed and close recorded at 08:44Z,
  kill ~08:48Z — the work survived the kill. `killed=true` in its record does not mean
  work-lost.
- **T924's 7 run records**: one 4110s run + six tiny (0.7–3.1s) seat re-closes; the headline
  attempt (longest wall) is what this slice's records report for wall/exit/tokens_out.
- **T842/T841**: both exit 1, both abandoned on evidence — the store's only failure rows in the
  slice are *honestly* failure rows. `fail-found: zero` in the store so far is not (yet)
  contradicted by this slice; the divergence I found is in *label accuracy*, not in hidden
  failures.
- **Mid-run incident to the record:** this arm's directory (with an uncommitted collector and
  records.json) was deleted once at ~17:30 CEST by something outside this task; everything was
  re-collected and committed early thereafter. A write-only audit arm loses its audit.
