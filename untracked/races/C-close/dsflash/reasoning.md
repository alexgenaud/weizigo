# T990 — Race C close record (dsflash) — reasoning

**Worker:** deepseek-v4-flash/T990. **Date:** 2026-08-25. **Landmark:** L1 (the dashboard tells
the truth) — the close is where a fleet's honesty is decided.

Sources examined, in order: the three run records (`untracked/runs/T894.json`,
`T924.1.json`, `T943.json`), the three briefs, the archived kanban rows
(`docs/infra/managent/archive.json` for T894/T924/T943), the findings files, the git history of
every deliverable and of the task store, `docs/evidence/T924/` (lane-cutoff.md, lane-run-record.json,
per-root.csv, summary.csv), the committed DONE-audit corpus and judge verdict
(`docs/audits/done-audit-2026-08-25/corpus.md`, `VERDICT.md`), `docs/research/4x4-d3-tractability.md`
and its correction chain, and two live runs of the delivered regression scripts at HEAD.

Method per row: what the run record claims, what the artifacts on disk say, who committed the
deliverables and when relative to the lane's end, and — where the row's headline is a number —
whether anything independent checked it.

---

## T894 — queue head orders by dispatch-readiness (claude-sonnet-5)

**Timeline.** Claimed 09:00:31Z; ran 09:00:13Z -> 09:16:44Z; **exit 0**; wall 991.1 s of a 7200 s
budget; 70,532 output tokens. The row was closed 09:31:16Z — 15 minutes after the lane ended —
with verdict **pass-with-findings** by the absorbing seat (claude-opus-5/T935), who also wrote the
findings file post-hoc (the file itself says so) and committed the work at b27c7f0 (09:30Z).

**What I checked.**
1. Did the lane do the work? The regression script's mtime (09:11Z) is inside the lane's run
   window; the findings say the lane built managent at 09:13:13Z mid-run; the corpus ground truth
   ("worker delivered code in src/managent/main.zig and regression test") agrees. The lane wrote
   the code and the script.
2. Did the lane finish the row? No. No findings file was written by the worker and no `managent
   done` was ever called; `managent reap` read the row as an orphan. `exit 0` here is the process
   exiting, not the row completing — exactly the T934 class the brief warns about.
3. Is the work real and still live? I ran `sh tools/regression-queue-ordering.sh` at HEAD:
   **9/9 PASS**, including the seeded-defect arm (leading-dash id refused by name, store carries
   no `--bundle` key) and the null arm (ready-only queue: 5 in, 5 found). Live `managent orient`
   output shows the fix: duties and STANDING- triggers are in their own section, never in the
   dispatchable list; ready rows lead, blocked rows sort by unmet-need count. build.zig:1410 wires
   the regression into the suite (via T932's cb5a307, per the 09:32:51Z amendment — the commit
   message's claim that the wiring was absent was wrong, a shared-writer slip, not a work defect).
4. Does the recorded verdict describe what happened? No. It reads as a normal close; the truth is
   a lane that exited without finalizing and a record reconstructed by a different seat. That is
   why `verdict_accurate_if_closed_pass` is **no** even though the work itself was complete and
   verified (the verdict-accuracy judgement is about the record, not the code).

**Decisions.** work_actually_done: **complete** (delivered, committed, verified green at HEAD by
two independent runs). verdict_accurate_if_closed_pass: **no**. absorbed: **yes** (fix live at
HEAD, regression wired, observable in today's orient output). self_reported_or_verified:
**verified** (the worker never self-reported; the outcome rests on T935's re-run and my own).
useful: **yes** (the queue head no longer lies; the estimate column prints UNKNOWN rather than a
fabricated number, and the remaining gap — nothing populates expected_wall_s — is recorded as a
finding, not hidden).

---

## T924 — 4x4.D3 writes-off tractability (ox-alpha)

**Timeline.** Claimed 03:49:35Z; ran 03:49:27Z -> 04:57:58Z; **exit 0**; wall 4110.6 s; 4.89 M
tokens in, 44.9 k out. The lane did **not** write either declared deliverable; the runner's
auto-close declined and the row stayed open until T914 recovered the numbers from the lane
transcript (commit 62b27bd, 07:05Z: "every number is a line the probe printed"), committed the
evidence CSVs (4fd16e0, 07:41Z), and closed the row pass-with-findings (09:32:04Z).

**What I checked.**
1. What is `exit 0` hiding here? The lane was **cut off by the provider**, not finished:
   `docs/evidence/T924/lane-cutoff.md` shows 429s ("stealth/ox-alpha is temporarily rate-limited
   upstream") at 04:57:22-57.8Z, ~70 s after the last served turn. 66 turns completed, then three
   429s, then exit 0. The last served turn was the lane *correcting its own sampling weights* —
   the correction that T929 later had to finish independently.
2. Did the lane deliver anything? No deliverables; the recovery was done by T914 (doc + findings +
   probe source 4a80255 + evidence CSVs). The lane's own contribution is the probe output.
3. Was the headline number checked? Yes — and it was **wrong**: the doc's floor argument ("the
   125 capped roots are excluded from the mean") is false — `sum_nodes` includes them at the
   20,000,001-node cap (2614391). T929 re-derived the projection layer-population-weighted:
   **26.8-214.7 h, 7.585x lower than the row's 202.5-1620 h** (8d5d163). The not-tractable verdict
   stands, on a ~7.6x smaller margin, and the shape is different (a pathological tail: 125 capped
   roots = 9.71% of samples but 92.6% of measured nodes). The findings file at HEAD **still**
   carries the stale "excluded from the mean" claim.
4. Was the register updated? The brief required updating `4x4.D3` in CLAIMS.md from UNTESTED.
   `docs/epistemic/CLAIMS.md:510` **still reads UNTESTED at HEAD** — that part of the row's brief
   was never actually done (the claim lives only inside the findings file).

**Decisions.** work_actually_done: **partial** — the measurement itself ran and is real, but the
lane was cut off mid-analysis, wrote nothing, its headline was wrong until a second row corrected
it, and the register update never happened. verdict_accurate_if_closed_pass: **no** — the
recorded verdict reads as a sound measurement; it was not sound as recorded. absorbed: **yes**
(doc, findings, evidence, probe source all committed; T929/T930 built on them; caveat: the 4x4.D3
register row is still UNTESTED). self_reported_or_verified: **verified** (recovered verbatim from
the transcript and independently re-derived/corrected by T929 — the verification is external to
any worker assertion, of which there were none). useful: **mixed** — the measurement outcome
redirects Track A -> Track B (ADR-0013's branch) and is load-bearing for L2, but the row's own
published figure was 7.6x overstated and the findings file at HEAD still asserts the wrong floor
argument; the value came from the recovery + correction chain.

---

## T943 — one documented inventory of moving parts (gemini-3.7-flash)

**Timeline.** Claimed 11:08:26Z; ran 11:08:20Z -> 11:18:33Z; **exit 0**; wall 612.2 s. The worker
committed the deliverables during the run (1d40645, 11:17:22Z), exited 0 **without calling
`managent done`**, and the runner **auto-closed the row as `pass`** at 11:17:50Z on process
evidence (verdict_note: "automatic, on process evidence (exit 0 + deliverables present), not a
worker-reported verdict"). A verdict amendment followed at 11:18:14Z, then T935's post-close
amendment at 11:26:23Z: **the row's own acceptance was RED on the live host**.

**What I checked.**
1. Was the work delivered? Yes — the inventory (docs/infra/moving-parts.md, 18 parts with
   dispositions), the gate (tools/regression-moving-parts.sh), the scratch root cause (commit
   2ea6f80's `tempfile.mkdtemp(prefix='t631-pinned-')` with no cleanup — 3,917 leaked dirs) and
   the atexit fixes (bin/subagent and others) are all in git at 1d40645. The acceptance command
   `sh tools/regression-moving-parts.sh` is declared in the row.
2. Was the acceptance true at close time? **No.** Arm A (null control) false-positived on
   `caffeinate -i -t 300` whose parent is the Claude Code harness binary — so the suite was red
   whenever a Claude console was open. T935 found this within minutes of the close ("T943 closed
   pass with its own acceptance failing", 35fd322) and explicitly named it S10-CLOSE-2: a
   condition that exits non-zero must refuse the close; nothing ran the acceptance at close time.
   The T958/T951 DONE audit lists T943's verdict among the inaccurate ones.
3. Was the gate fixed? Yes — T952 attributed caffeinate by ancestry rather than command shape
   (be06fdb, 35a7c40). My run at HEAD: arms B-F pass; arm A is red only on genuinely live-host
   findings (a stale T961 runner 6.4 h past its 7200 s max-wall and three orphaned
   watch-fleet-live scratch trees) — i.e. the gate now catches real problems, which is its job.
4. The worker's findings claim ("ALL CONTROLS PASSED") was therefore a self-report that was false
   on a clean host; verification arrived only after the close.

**Decisions.** work_actually_done: **complete** (all four brief items delivered and committed; the
defect is in a delivered item, captured in verdict accuracy, not in work done). 
verdict_accurate_if_closed_pass: **no** — closed pass with its own declared acceptance red
(S10-CLOSE-2). absorbed: **yes** (inventory + gate wired into build.zig:750; subagent cleanup
committed; T952 built on the gate). self_reported_or_verified: **self-reported** (the worker's
"ALL CONTROLS PASSED" was wrong at close time and unverified — nothing ran the acceptance; the
truth came from T935/T952 after the close). useful: **mixed** — the inventory and the scratch
leak fix are genuinely valuable, but the shipped gate broke `zig build test` on this host until
T952's fix; the mechanism was defective as delivered.

---

## Cross-row notes

- All three rows share one shape the brief warned about: **exit 0 is not evidence of completion.**
  T894: exited without finalizing (record reconstructed by a seat). T924: exited because the
  provider cut the lane off (record reconstructed by a seat + corrected by T929). T943: exited
  without finalizing (auto-close ran on process evidence alone and never ran the acceptance).
- Only T894's work was both real *and* correctly described by its surviving artifacts at close
  time. T924's headline was wrong until a second row fixed it; T943's own gate was red at close.
- The committed DONE-audit corpus/verdict (docs/audits/done-audit-2026-08-25/) — which used these
  three rows as sealed controls — reaches the same three "verdict inaccurate" conclusions
  independently; my analysis above was done from the run records, artifacts, and git history
  before being cross-checked against it.
