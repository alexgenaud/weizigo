# RESUME — orchestration seat, 2026-08-25 night

Outgoing: `claude-opus-5`/T935, 2026-08-25 ~09:00–22:30Z. Supersedes
`docs/status/RESUME-orcha-2026-08-25-midday.md` for seat state; that file's traps still bind.

## 0. Standing operator orders

- **Reserve Fable.** Standing.
- **Roster:** no `qwenlocal`, no `qwencloud` — both retired tonight (see §5). Ollama's weekly
  limit is **exhausted until Sunday**; that is a provider fact, not a policy.
- **Four provider sets** — CC, Ollama, DS, OpenRouter — with at least four *models* delegating
  when the fleet is full. DS and OpenRouter carry more, Ollama a bit less.
- **Never kill a running task unless it is thrashing.** A policy change governs the *next*
  dispatch, not work already in flight. *"I did not mean for you to kill an ongoing task, unless
  it was thrashing."* I broke this once and it cost credit twice over.
- **Cost is the operator's concern only.** Races must not weigh or record it. He needs a reliable
  capability ladder *before* cost/benefit is meaningful.
- **Nicknames only in casual prose** — `oxalpha`, `gflash`, `gptluna`, `solarpro`, `nemotron`,
  `dspro`, `dsflash`, `opus`, `sonnet`, `haiku`. The one table is
  `docs/infra/model-registry.md` §Short names. Canonical labels in records; never a nickname.
- **Decide, tell him, act.** He reserves veto. Asking permission for a decision you have already
  reasoned through is the thing he corrects.
- **Spec-audit loop for every task spec:** single author, N *fresh* auditors per round, **the
  author resolves**. Capped at three rounds (`docs/infra/sprint.md:105-107`); a third red round
  escalates to him. He ratified this pattern outright — do not re-test it.
- **He declares task / race / sprint.** Push back if the weight looks wrong.

## 1. The dispatcher — how it is configured and why

`tools/pop-next.sh --loop`, nohup'd, supervisor re-execs a fresh child per tick so an edit takes
effect within a minute. The brake is the stop-file named in the script's own header — creating it halts the loop, and it is absent while the loop runs, which is why it must not be cited as a path here (it is a dangling citation to the commit gate; that cost four gate runs this morning).

| knob | value | reason |
|---|---|---|
| `MAX_LANES` | 8 | eight against the caps below forces a spread |
| `FLEET_FAMILY_CAP` | claude=4, deepseek=3, other=4, ollama=2, fable=1 | no two families can fill eight lanes |
| `EXCLUDE_FAMILIES` | `local,ollama-cloud` | qwenlocal wants 18 GB; ollama is out of credit |
| per-model | live models fed to `--exclude` | one lane per MODEL, not just per family |
| retry cap | 5 fast failures → skip and name | T873 was re-dispatched **30 times in 30 minutes** |
| auto-force | dispatch recorded + no run record + no live process | T925/T973 each ate a tick forever |

**claude=4 not 3 because the cap counts STORE ROWS, not processes**, and the seat row (T935) is an
`in_progress` row with no lane. It was refusing real arms. The underlying defect is unfixed.

## 2. The three races — the main thing in flight

30 sealed arms + 3 judges, **T969–T1001**. Ten models each: dspro, dsflash, opus, sonnet, haiku,
gflash, gptluna, nemotron, solarpro, oxalpha.

- **Race A (T969–T978, judge T999)** — write the spec for T936, run 4×4.D3 to completion. Graded
  on decisions *decided* not deferred, on cited numbers surviving a check against the repo, and on
  whether the arm noticed that a censored root's cost is **unknown above the cap, not equal to it**
  — the error that made T924's headline 7.585× high. **First three arms closed `pass`** in
  438–787 s (sonnet, opus, dspro).
- **Race B (T979–T988, judge T1000)** — resolve the five blockers T964 raised against the
  close-contract spec. Three are factual errors in numbers that spec cited. An arm that proves the
  **auditor** wrong, with proof, scores highest on that blocker.
- **Race C (T989–T998, judge T1001)** — write the close record for T894, T924, T943. **A sealed
  answer key already exists** (the DONE-audit key), nine auditors were scored on it today, and
  **most got T894 and T924 wrong**. The test is known to discriminate and the easy reading is known
  to be wrong.

Every judge: score before opening any key, check every cited number, report the sealed-boundary
check for **every** entrant including the well-behaved, classify absent arms
served-and-failed / served-and-cut-off / never-served with quoted evidence, attribute from the
**store row** and never a directory name, record no cost figure.

## 3. Defects registered today, highest value first

| row | what |
|---|---|
| **T1002** | **two live rows hold `src/managent/main.zig`** — the one-writer rule leaked on the *claim* path (dispatch refuses correctly). Also: T874's stored holds is one **colon-joined string**, so exact-match isolation can never see a path inside it. Also asks whether **anything reads the worker message channel** — a worker reported this defect into it and waited four hours. T1002 names the file. |
| **T968** | **`--max-wall` is declared and not enforced.** Two lanes ran 4h57m against a 7,200 s budget. Nothing compares elapsed to budget on any surface. |
| **T953** | a failure must name its cause. Its D2 needs `src/managent/main.zig`; blocked behind T961. Arm D2 is baselined red in the S09 contract. |
| **T963/T964** | close-contract spec written (49 KB, 11 sections) and audited → **5 blockers**. Race B resolves them. |
| **T931** | `acceptance=` swallows the next key — 19 briefs were corrupted. Headers reordered as mitigation; stored values still wrong; needs the general `--sync`. |
| **T965 T967 T942 T943→T952 T966** | store archive · per-task-type draw · the DONE rate joins two runs · moving-parts gate red on a clean host · a stale citation |

## 4. Errors I made — recorded so they are not repeated

- **Killed a live minimax lane** over a policy about the *next* dispatch. Spent the credit twice.
- **`| tail -1`** in my own popper discarded every refusal's cause; T798 was refused 22 times in
  22 minutes with no task id in the log. **Then I specified T953 around the wrong diagnosis**, and
  the round-1 audit proved the gate was fine and the reader was mine.
- **Truncated the rate column to `%-8.8s`** while fixing a nickname overflow, which broke T942's
  measurement fix an hour later.
- **Committed a 232-line regression's deletion** (`tools/regression-store-census.sh`, the store-loss
  controls) by staging a file list without checking which entries were deletions.
- **Said we had lost evidence** when the claim was backed by committed source; the missing file was
  a stale citation.
- **Called T953 thrashing.** It was waiting correctly for a held file and had reported the reason.
- **Pinned T873 to glm** and had no retry cap — 30 failed re-dispatches helped exhaust Ollama.

## 5. Model evidence — what is actually known

`sh tools/model-matrix.sh` is the census. `sh tools/flow.sh [--blocks N]` is the queue trend.

**Retired tonight:** `qwencloud` — bottom of the output ladder (14.8 out/s) while consuming
**109.6 M fresh input tokens** on one row; slow *and* expensive. `qwenlocal` — 3 rows ever, wants
18 GB, and its presence makes `tools/regression-ollama-dispatcher.sh` control 4 fleet-dependent.

Output rate today (out/s): gptluna 96.8 · haiku 74.2 · nemotron 67.0 · sonnet 52.7 · solarpro 46.0
· opus 40.5 · dsflash 34.6 · gflash 34.3 · dspro 29.1 · qwencloud 14.8 · oxalpha 8.7.

**Rate is not quality.** The one calibrated test (nine auditors, twelve control rows, sealed key):
haiku / qwencloud / solarpro **10/12**; dspro, dsflash, kimi, gflash, nemotron **9/12**;
**gptluna 8/12 and caught none of the seeded rows** — the model I had called the best of the new
five on speed alone. **All nine missed T894 and T924.**

The DONE-audit census across 120 rows: **113/120 verdicts accurate, 99 complete, 110 verified
rather than self-reported, 92 absorbed durably.** Absorption is the weak column.

## 6. Where the four streams stand

- **Failure transparency** — the most advanced. Store-loss detector green (T848 + T944's SMOKE-4),
  one-door dispatch landed, retry cap landed, spec written and audited. Race B finishes it.
- **Honest instruments** — self-sustaining; it keeps finding its own defects.
- **Autonomy** — real. The dispatcher ran unattended for hours and closed rows without help.
- **4×4** — barely moved. **T936 is `dispatchable` and only `unspec`**; T928 closed at 19:50Z. It
  is Race A's subject, so its spec arrives from the race.

## 7. First five minutes for the next seat

1. `bin/managent reap` — orphans accumulate; the popper logs them every tick but closes none.
2. **Compare the store row count against HEAD before trusting the queue.** A negative delta is the
   alarm. The detector exists now (`tools/regression-store-census.sh`, `tools/regression-store-loss.sh`).
3. tail the popper's log (the path is in `tools/pop-next.sh`'s header) — a stalled dispatcher looks identical to a quiet one.
4. **Verify closes by hand.** Two rows closed `pass` today with their own acceptance failing.
   `finished` in the CONCERNS pane means *exit 0*, not *work done*.
5. `sh tools/flow.sh --blocks 2` and `sh tools/model-matrix.sh`.
