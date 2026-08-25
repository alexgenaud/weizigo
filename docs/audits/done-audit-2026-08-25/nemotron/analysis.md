# T957 DONE-audit analysis — nemotron

**Landmark:** advances `L1 (the dashboard tells the truth)`. **Auditor:** nemotron-49b/T957. **Date:** 2026-08-25.

## Coverage and census

I audited all 24 assigned rows: the 12 nemotron disjoint rows (`T640`, `T848`, `T598`, `T621`, `T638`, `T652`, `T913`, `T403`, `T507`, `T742`, `T862`, `T465`) and all 12 shared controls. No assigned row was left unexamined.

The records judge **21/24 recorded verdicts accurate (87.5%)** and **3/24 inaccurate (12.5%)**: T598, T638, and T943. Actual work was complete for 16/24 (66.7%), partial for 5/24 (20.8%), and absent for 3/24 (12.5%). The partial rows are T598, T638, T862, T943, and T387; absent work is T921, T842, and T841.

## Absorption, verification, and usefulness

- **Absorbed yes:** 18/24 (75.0%); **partial:** 2/24 (8.3%); **no:** 4/24 (16.7%). The no rows are the three no-output controls T921/T842/T841 plus T598, whose missed S3 action left only a flawed write-up rather than the requested probe result.
- **Verified rather than merely self-reported:** 24/24 (100%). Every record has independent evidence such as a committed artifact, machine/run record, downstream use, or a control-ground-truth check. This does not mean every result was correct: T598, T638, and T943 demonstrate why completion evidence and verdict accuracy are separate judgements.
- **Useful yes:** 19/24 (79.2%); **mixed:** 2/24 (8.3%); **no:** 3/24 (12.5%). T638 is mixed because 24 claim rulings remain useful despite G15 being pending; T598 is mixed because it correctly rejected stale S1/S2 premises but missed S3.

## Rows to re-open or follow up

Re-open **T598**: it did not perform the shared brief's S3 action (`glm=0` assertion plus conservative substitution), while its pass-with-findings note says that scenario was absent. Re-open **T638**: its committed file still marks G15 `pending` even though the task is recorded `pass` after a watchdog SIGKILL. Re-open **T943**: the declared regression has a false-positive and makes the clean-host acceptance path RED, so its automatic clean `pass` is not reliable.

T862 needs a separate follow-up for the explicitly outstanding pi/openrouter and Claude session-handle construction, but its `pass-with-findings` close accurately discloses that gap and is not itself recommended for reopening. T924's wrong projection was caught and corrected by T929; it does not need reopening on this audit.

## No-acceptance stratum

The dedicated no-acceptance stratum rows in this slice are **T640, T848, and control T421**. T640 completed a 25-claim audit and later triggered durable register repair; T848 delivered a four-arm detector and later had fixture state repaired/restored; T421 completed a verified evidence rescue and C10 checker. Their outcomes range from a high-cadence analytical audit to infrastructure implementation to historical evidence repair, so absence of a machine acceptance tag did not by itself predict failure here. The no-output controls T842/T841 and the killed T921 are separately sampled failure controls, not part of the 20-row dedicated stratum.

## Most important pattern

**A clean status can be wrong even when every declared deliverable is present and committed.** T943 has all three declared artifacts in git and exited 0, yet its own acceptance regression has a false-positive that makes the suite RED. T924 shows the complementary analytical form: committed research and findings existed, but its headline projection was 7.585× too high until T929 independently re-derived it. Conversely, T862 shows that a partial implementation can still have an accurate `pass-with-findings` close when the remaining scope is explicitly recorded.

This pattern is not disproved by mere deliverable presence. It would be disproved by an independent acceptance run or downstream re-derivation showing that every apparently clean row with committed artifacts has both a truthful gate and a numerically/semantically correct result; specifically, T943's regression would need to pass its clean-host null control without the false-positive, and T924's projection would need to agree with an independent weighted calculation.

The practical implication for `L1 (the dashboard tells the truth)` is that close auditing must test the declared acceptance behavior and headline claims, not only `git ls-files` and exit status. The three recommended reopenings are the concrete cases where the stored verdict and observed reality diverge.
