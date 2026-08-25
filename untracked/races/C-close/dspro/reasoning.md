# T989 — Race C close record (dspro) — reasoning

**Identifier:** deepseek-v4-pro/T989 · **Landmark:** `L1 (the dashboard tells the truth)` ·
**Date:** 2026-08-25

Three lanes, one verdict each: all three are `pass-with-findings`, and in all three a plain
`pass` would be inaccurate. The easy reading of each (exit 0 + deliverables in git → pass) is
wrong for a different reason per row.

---

## T894 — the lane died at exit 0 without closing (work real, record absent)

**What I checked:**

- Run record `untracked/runs/T894.json`: start 09:00:13Z, end 09:16:44Z, `exit 0`, wall 991.1 s,
  `killed_by: none`, 70,532 output tokens. Nothing here says "closed".
- The row's own findings file `findings/T894-queue-head-and-eta.json` says, in its own words:
  *"This file was written post-hoc by the absorbing seat (claude-opus-5/T935), not by the worker."*
- File mtimes: `tools/regression-queue-ordering.sh` at 09:11Z (during the run) vs
  `findings/T894-queue-head-and-eta.json` at 09:28Z (12 min after the lane ended).
- Commit `b27c7f0` at 09:30:10Z — 13.5 min after the lane ended — carries the src fix, the
  regression, and the post-hoc findings file together.
- Archive row `T894`: `done` at 09:31:16Z, verdict `pass-with-findings`, verdict_note
  *"lane died at exit 0 without closing, absorbed by T935"*.
- Re-ran `tools/regression-queue-ordering.sh`: **9/9 controls PASS** (exit 0) on today's tree.

**What decided it:** the code work is complete and correct — the fix is live, the regression is
green — but the worker never wrote its findings file and never ran `managent done`. Exit 0 was a
lane dying, not a lane closing; the row is honest only because T935 stepped in. That is exactly
`pass-with-findings`, and a plain `pass` would be inaccurate.

---

## T924 — a real measurement whose headline number was 7.585× wrong

**What I checked:**

- Run record `untracked/runs/T924.1.json`: start 03:49:27Z, end 04:57:58Z, `exit 0`, wall 4110.6 s,
  CPU 2560.4 s (62% utilisation — genuinely computing), 4,886,579 tokens in.
- `docs/evidence/T924/lane-cutoff.md`: the lane was **served then cut off** — last successful turn
  04:57:08Z, then three 429 `stealth/ox-alpha is temporarily rate-limited upstream` errors, run
  over at 04:57:58Z. It was interrupted *while reasoning about its own sampling weights*, before
  writing deliverables.
- The findings file `findings/T924-4x4-d3-tractability.json` carries `recovered_by:
  claude-opus-5/T914 from the lane transcript` and states the lane *"exited 0 without writing its
  deliverables"*.
- The headline `202.5–1,620 h` in `docs/research/4x4-d3-tractability.md` is an **unweighted** mean
  over a capped stratified sample. `docs/research/4x4-d3-weighted-projection.md` (T929) shows the
  population-weighted mean is **282,104.8 nodes/root, 7.585× lower** → **26.8–214.7 h**. T924's
  own doc now carries the correction and points at T929.
- The verdict stands (not tractable under writes-off), so the measurement is not garbage — but the
  number the row published was inflated by a factor of 7.6 and stayed quoted until a second row
  fixed it.

**What decided it:** the work is real (a genuine 68-minute ladder with real per-root data), but the
row's headline number was wrong until T929 corrected it — the exact "a pass-with-findings can carry
a wrong figure and look clean" trap the brief warns about. `pass-with-findings`, `no` on a plain
pass.

---

## T943 — closed pass while its own acceptance was red

**What I checked:**

- Run record `untracked/runs/T943.json`: start 11:08:20Z, end 11:18:33Z, `exit 0`, wall 612.2 s.
- Archive row `T943`: verdict `pass`, verdict_note *"tools/runner auto-close: worker exited 0
  without closing … this close is automatic, on process evidence (exit 0 + deliverables present),
  not a worker-reported verdict"*, and an amendment recording the defect:
  *"Its own regression is RED on the live host and it is wired into zig build test. Arm A (null
  control) flags 'caffeinate -i -t 300' … whose parent is the Claude Code harness binary itself …
  Closed pass with a failing acceptance. Fix registered as T952."*
- `tools/regression-moving-parts.sh` was committed (1d40645) and later fixed twice (be06fdb, 35a7c40)
  under T952, confirming the gate was broken at close.
- The inventory `docs/infra/moving-parts.md` is real (18 rows, explicit "RECOMMEND DELETE" rows for
  fleet-keeper and the plists — the honest review the operator asked for), and the scratch-leak root
  cause (2ea6f80's `mkdtemp` with no cleanup) is correctly identified and fixed in `bin/subagent`.

**What decided it:** the deliverables exist and are useful, but the row was closed `pass` by the
runner's auto-close while its *declared acceptance test* was actively failing on a clean host. That
is the "flawed automated close" case, so `pass-with-findings` and `no` on a plain pass.

---

## Cross-row note on the three exit-0 cases

The brief names three distinct outcomes that all record `exit 0` today, and the three rows are one
of each: **T894** a lane that finished its work but died without closing; **T924** a lane refused
service by the provider mid-correction; **T943** a lane that finished cleanly but shipped a red
gate that the auto-close papered over. Reading any of them as a clean pass is the trap.
