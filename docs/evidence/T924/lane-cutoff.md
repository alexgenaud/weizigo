# T924 — the ox-alpha lane was served, then cut off

Extracted by the T935 seat, 2026-08-25, from the lane's own session file
(`untracked/tokens/sessions/T924.1787629767763894000.37456.0.jsonl`, 146 records, 1,374,643 bytes)
and its run record (`lane-run-record.json`, copied here verbatim). The session file is volatile
storage; this document is the committed evidence.

## The run

| field | value |
|---|---|
| model | `ox-alpha` (serving tag `stealth/ox-alpha`, provider openrouter) |
| start / end | 2026-08-25T03:49:27Z - 04:57:58Z |
| wall | 4,110.6 s |
| CPU | 2,560.4 s (**62% utilisation** - it was computing, not idling) |
| tokens in / out | **4,886,579 / 44,877** |
| RSS | 1,440 MB |
| exit | **0** |
| 429s in the lane's stderr log | **0** |

66 assistant turns completed successfully. This lane was **served**.

## The cutoff

Last successful turn: **04:57:08.122Z**. Then, in fifty seconds:

- `2026-08-25T04:57:22.250Z` - Provider returned error
- `2026-08-25T04:57:29.831Z` - 429: {"message":"Provider returned error","code":429,"metadata":{"raw":"stealth/ox-alpha is temporarily rate-limited upstream. Please retry shortly.","provider_name":"Stealth","is_byok":false,"limit_source":"upstream_provider_shared_pool","remedy_hint":"Retry shortly, add your own provider key (https://openrouter.ai/settings/integrations), or route to another provider with provider routing: https:...
- `2026-08-25T04:57:40.274Z` - 429: {"message":"Provider returned error","code":429,"metadata":{"raw":"stealth/ox-alpha is temporarily rate-limited upstream. Please retry shortly.","provider_name":"Stealth","is_byok":false,"limit_source":"upstream_provider_shared_pool","remedy_hint":"Retry shortly, add your own provider key (https://openrouter.ai/settings/integrations), or route to another provider with provider routing: https:...
- `2026-08-25T04:57:57.785Z` - 429: {"message":"Provider returned error","code":429,"metadata":{"raw":"stealth/ox-alpha is temporarily rate-limited upstream. Please retry shortly.","provider_name":"Stealth","is_byok":false,"limit_source":"upstream_provider_shared_pool","remedy_hint":"Retry shortly, add your own provider key (https://openrouter.ai/settings/integrations), or route to another provider with provider routing: https:...

Run over at 04:57:58Z, `exit 0`.

`limit_source: upstream_provider_shared_pool` - the pool is shared with other openrouter users.
Our own dispatch rate at the time was 18 claims in nine hours, so the pressure was not ours.

## What it was doing when it was cut off

The last served turn is the lane reasoning about its own sampling weights - the beginning of the
correction that T929 later had to make independently (the unweighted mean was 7.585x high):

```
[{"type": "thinking", "thinking": "The


 4\u00d74 sample

 (properly labeled
, under
 admission
):


-
 writes-off: 
1287 sampled roots,
 1162 solved
,
 125 skipped at
 20M budget;
 mean
 
2.14M nodes/nontrivial-root; projected total finisher work [
2.77e12, 2.22e13] nodes = [203 h, 1620 h].

- writes-on calibration on the SAME roots: all 1287 solved, mean 14.5k nodes/root \u2014 projected [1.9e10, 1.5e11]
 nodes = [
1.9 h,
 15.
5 h].
 Hmm
 \u2014 historical writes-on full run was 367 s finisher wall with 1.08B nodes. My writes-on projection of 1.9\u201315h overestimates because the sample weights hard layers more? No wait \u2014 historical was 649,517 reps \u00d7 ~1660 nodes avg = 1.08B nodes \u2248 367 s. My slot-mean 14.5k/rep \u2192 10.37M slots... but slots \u2260 reps! Reps = orbits \u2248 slots/symmetry-factor. Historical rep count 649,517 vs my pop 10,367,922 slots \u2192 factor 16. So my projection bracket [/16, \u00d71] is exactly right: writes-on lower bound 18.7e9/16... 

wait no, I already divided by num_syms in proj_lo: proj_lo_nodes = pop/16 \u00d7 mean = 2.77e12 for off-arm. For on-arm: 1.87e10 (= 10.37M/16 \u00d7 14.45k \u2248 9.4e9... hmm printed 1.873e10). Whatever \u2014 the bracket is [pop/16\u00d7mean, pop\u00d7mean]. Historical actual: 1.08e9 nodes total. My on-arm lower estimate is 1.87e10 \u2014 still 17\u00d7 higher than historical. Why?

Because sampling uniform over SLOTS overweights large orbits? No \u2014 orbit size \u2264 16 always (num_syms=16), so slots/reps \u2208 [1,16]; mean nodes per SLOT \u2265 mean per REP /16. My lower bracket uses /16. Historical mean/rep 1663 \u2192 mean/slot \u2248 1663\u00d7(reps/slots) \u2248 1663/16 \u2248 104. But measured on-arm mean/slot = 14,454 \u2014 139\u00d7 the hist
```

It was interrupted while correcting itself, not after neglecting to write.

## Why this matters

`tools/runner` recorded `exit 0` for a run the provider refused to finish. Three distinct outcomes
are currently one value: ran and finished, ran and was killed, and **never served / cut off**.
That is **T934**. The standing B4 diagnosis - "ox-alpha does not reliably echo the nonce, protocol
compliance unreliable" - was built on this reading and was wrong for weeks.
