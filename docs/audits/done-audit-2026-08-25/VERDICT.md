# DONE-audit judge verdict — 2026-08-25

**Task:** T951 (judge the DONE audit)
**Author:** gpt-5.6-luna-pro/T951
**Landmark:** advances `L1 (the dashboard tells the truth)` — this is a census of whether recorded closes describe work, absorption, and verification.

## Status and method

**Verdict: pass-with-findings.** All nine auditor arms produced records for their assigned 24 rows, so the 108 disjoint rows plus the 12 shared controls cover all 120 corpus rows. I scored the shared control slice before opening the answer key, using only the ground truths printed in `corpus.md`; I then verified the key hash and opened it; only after that did I use the disjoint-slice records for the 108-row census.

The answer-key hash stated by `corpus.md` is:

`440451bc1fd60711bc676374bd3b727e22f7f39d8d30f740d0726eea792e993e`

The SHA-256 computed for the sealed answer-key artifact is:

`440451bc1fd60711bc676374bd3b727e22f7f39d8d30f740d0726eea792e993e`

The hashes match. The key, rather than an auditor's control prose, is the canonical control result below. No task work was re-run and no finding was remediated.

## Census across all 120 rows

The 12 controls use the sealed key's canonical fields; each disjoint row uses its assigned arm's record. Thus each corpus row is counted once, not nine times.

| Measure | Result | Denominator |
|---|---:|---:|
| Verdict accurate | 113 yes; 6 no; 1 unverifiable/invalid (`T701` was recorded `mixed`) | 120 |
| Work actually done | 99 complete; 15 partial; 6 none | 120 |
| Absorbed durably | 92 yes; 18 partial; 10 no | 120 |
| Verified rather than self-reported | 110 verified; 9 self-reported; 1 unverifiable | 120 |
| Useful | 99 yes; 14 mixed; 6 no; 1 partial (`T387`) | 120 |
| Complete but not useful | 0 | 120 |

The absorption count deliberately separates full absorption from partial absorption. Ten rows stopped at `absorbed: no`; three of those are explicit write-only findings cases (`T730`, `T683`, and `T361`), while the others are no-output or failed/abandoned outcomes. A findings file existing on disk is not itself absorption.

The `no-acceptance` stratum is reported separately as required. Its 20 rows are exactly the list in `corpus.md`: `T674`, `T679`, `T683`, `T685`, `T491`, `T533`, `T916`, `T462`, `T804`, `T677`, `T848`, `T464`, `T627`, `T908`, `T470`, `T640`, `T792`, `T751`, `T900`, and `T459`.

| No-acceptance measure | Result | Denominator |
|---|---:|---:|
| Verdict accurate | 20 yes; 0 no; 0 unverifiable | 20 |
| Work actually done | 18 complete; 2 partial; 0 none | 20 |
| Absorbed durably | 14 yes; 5 partial; 1 no | 20 |
| Verified rather than self-reported | 17 verified; 3 self-reported; 0 unverifiable | 20 |
| Useful | 17 yes; 3 mixed; 0 no | 20 |
| Complete but not useful | 0 | 20 |

This stratum is not evidence that missing acceptance is harmless: it has five partial absorptions and three self-reported outcomes, and its 20/20 verdict-accuracy result is a judged sample result, not a fleet-wide guarantee.

## Control-slice inter-auditor agreement

The controls agree strongly on the easy rows but expose systematic blind spots on the hard close-mechanism rows. The answer key's canonical verdict-accuracy values are `yes` for T932, T927, T921, T842, T841, T387, T929, and T421, and `no` for T894, T924, T943, and T907.

### Verdict accuracy against the key

| Auditor | Matches | Seeded rows caught | Seeded rows missed |
|---|---:|---|---|
| dspro/T946 | 9/12 | T943 | T894, T924, T907 |
| dsflash/T947 | 9/12 | T943 | T894, T924, T907 |
| kimi/T948 | 9/12 | T943 | T894, T924, T907 |
| haiku/T949 | 10/12 | T943, T907 | T894, T924 (recorded `mixed`) |
| gemini/T950 | 9/12 | T943 | T894, T924, T907 |
| gptluna/T955 | 8/12 | none | T894, T924, T943, T907 (recorded `blocked`) |
| qwencloud/T956 | 10/12 | T943, T907 | T894, T924 |
| nemotron/T957 | 9/12 | T943 | T894, T924, T907 |
| solarpro/T958 | 10/12 | T943, T907 | T894, T924 |

No auditor flagged either null control T932 or T927, and all nine recognized the true-negative control T921. T943 was caught by eight of nine. The hard T894 and T924 controls were missed by every arm as an exact `no` (haiku called T924 `mixed`); T907 was caught by haiku, qwencloud, and solarpro. The most important calibration result is therefore not the nominal 9/12–10/12 scores: the race reliably detected the red-gate control but had poor sensitivity to post-hoc rescue and a corrected-but-originally-wrong headline number.

### Agreement on the other control fields

- **Work:** unanimous `complete` on T932, T927, T894, T907, T929, and T421; unanimous `none` on T842 and T841; unanimous `partial` on T387. Disagreement was concentrated in T924 (5 complete / 4 partial), T921 (8 none / 1 partial), and T943 (6 complete / 3 partial).
- **Absorption:** unanimous on most controls. T894 was 8 yes / 1 partial; T943 7 yes / 2 partial; T907 6 yes / 3 partial; T387 8 partial / 1 yes.
- **Verification:** T932, T927, T907, T929, and T421 were unanimous verified. T894 was 7 verified / 2 self-reported; T924 7 / 2; T921 6 verified / 2 self-reported / 1 unverifiable; T943 6 self-reported / 3 verified; T842 7 verified / 2 self-reported; T841 6 verified / 2 self-reported / 1 unverifiable. T387 had 7 verified, 1 self-reported, and 1 invalid `partial` value.
- **Usefulness:** disagreement was expected and informative: T924 was 6 yes / 3 mixed, T943 5 mixed / 4 yes, T842 7 no / 2 mixed, T841 8 no / 1 mixed, and T387 7 mixed / 2 yes. Other controls were unanimous.
- **Deliverables-present-in-git:** this was not stable across collectors, and that is a defect, not substantive auditor disagreement. For example, T932 was reported as full by 7 auditors, source-only by 1, and empty by 1; T943 was full by 6, empty by 2, and missing its regression path by 1; T907 was full by 6, empty by 2, and document-only by 1. T927 also differed in path order and partial subsets. The key provides the canonical full/empty control values; future collection must normalize and freeze the HEAD used for comparison.

## Rows recommended for re-opening or record repair

These are recommendations only; this judge did not re-open them.

- **T894:** amend the close record. The code and regression were real, but the worker exited without findings or a close and the seat reconstructed both; the sealed key treats the clean `pass-with-findings` accuracy judgment as `no`.
- **T924:** amend the record to preserve the original 7.585x-overstated projection and point to T929's correction. The underlying ladder data was useful, but the original headline was wrong.
- **T943:** re-open the `pass` close. Its declared acceptance was red on a clean host despite exit 0 and deliverable presence.
- **T907:** amend `blocked` to describe the complete work plus the unrelated-dirty-file hook failure, or re-close with the later commit evidence; the key treats the original verdict as inaccurate.
- **T598:** re-open the disjoint finding that the required S3 action was not performed, leaving only a flawed write-up.
- **T638:** re-open or amend the record because G15 remained pending after the watchdog kill despite the `pass` close.
- **T701** and **T755:** inspect the incomplete/missing deliverables identified by the haiku arm; T701's `mixed` verdict field is also outside the declared schema.
- **T730**, **T683**, **T533**, and **T679:** establish downstream citations or disposition the findings as write-only/untracked. These are absorption and evidence-durability repairs, not claims that the workers necessarily did no work.

## Late-arm service, store state, and model attribution

The brief required T955–T958 to be closed or classified before judging. They were served: each has a run record and a 24-row records artifact. They are not `never-served`.

- **T955:** historical registration at commit `4edb831` had `status: blocked` and `model: null`; its run record shows `nemotron-3.5-lightning`, exit 0, and 255.9 seconds, with tracked records and findings. The live row is now absent. Classification: **served-and-failed to finalize / store row later lost**, not never-served. The `gptluna/` directory label is not the served model.
- **T956:** the live row has `model: qwen3.8-27b` and remains `in_progress`, while its run record shows exit 0 and 5509.4 seconds and its records/finding are present. Classification: **served but unfinalized**, not never-served. The qwencloud directory and store model agree.
- **T957:** historical registration had `status: blocked` and `model: null`; its run record shows `gpt-5.6-luna-pro`, exit 0, and 213.2 seconds, with tracked records and findings. The live row is absent. Classification: **served-and-failed to finalize / store row later lost**, not never-served. The `nemotron/` directory and findings label do not name the model that ran.
- **T958:** historical registration had `status: blocked` and `model: null`; its run record shows `solar-pro4`, exit 0, and 1567.1 seconds, with tracked records and findings. The live row is absent. Classification: **served-and-failed to finalize / store row later lost**, not never-served. The solarpro label agrees with the run, but no live store model field survives.

Accordingly, model cells were written for every served arm without inventing a model for an absent store row: T946–T950 use their live store `model` fields, T956 uses `qwen3.8-27b`, and T955/T957/T958 use `model: null` with an explicit missing-store note. The directory labels were not used as attribution. T955 and T957 are the two directory/model mismatches; T956 and T958 match their surviving/intended labels.

## Findings and inbox

No claim-status changes or new claim rows are proposed. The machine-readable task finding is `findings/T951-done-audit-judge.json`. Inbox polls at claim, after the key/census step, and before close found no pending directives; therefore no directive ID is recorded.
