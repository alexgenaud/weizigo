Task: EXP-12 · Role: worker · Model: Kimi K3 · Date: 2026-07-28
(resumed and closed out 2026-07-29 — see the Resumption section at the end)

# PROVENANCE — GLOBAL.DENOMINATORS sweep

**Claim ID:** `GLOBAL.DENOMINATORS` (topic directory, per dispatch
`docs/infra/dispatch/EXP-12-denominator-sweep.md`).
**Artifact:** `sweep-2026-07-28.md` (the audit; sibling of this file).

## Acceptance criterion (from the brief), and how it was met

One sweep file containing: a summary table
`| file:line | % as written | denominator written | denominator correct |
verdict | fix |` for **every** percentage in `docs/research/*.md`; counts
(total, PASS, FAIL by kind, stale); FAILs grouped by kind with fixes; a
"no false negatives" line; ≥3 known-good and ≥3 known-bad calibration rows;
a common-thread paragraph; an honest-negatives paragraph. `docs/research/`
was **not** edited (verify: `git status -- docs/research/` is clean; the audit
directory is the only addition).

## Read state

- Repository HEAD moved during the task (`4fca047` → `f1f5c25`, the
  standing-tier audit-wave commit landed by other agents). All audited files
  were read from the working tree; `git diff -- docs/research/
  docs/epistemic/PROGRESS.md` is empty, so the audited content is identical
  at both commits.
- **Resumption addendum (2026-07-29):** at close-out, HEAD is `c63b678`
  (touches neither `docs/research/` nor this evidence directory — verified
  `git diff --name-only f1f5c25..HEAD`); the only `docs/research/` change
  since the first pass is the *addition* of the untracked
  `h5a-player-mitigation-2026-07-28.md` (mtime 03:13 local, GLM's EXP-9/H5a
  cost note), swept on resumption.
- Brief: `docs/infra/dispatch/EXP-12-denominator-sweep.md`. Role doc:
  `docs/infra/delegation/DELEGATEE.md`. Rule sources: `AGENTS.md`,
  `docs/research/ko-sensitive-chainability.md` (the canonical
  denominator-discipline example), `docs/evidence/README.md`.

## Files read (all of them, in full)

All 37 `docs/research/*` entries (36 `.md` + `oracle-5x5-pv.sgf`; the 37th,
`h5a-player-mitigation-2026-07-28.md`, landed after the first pass and was
swept on the 2026-07-29 resumption) — the 18
zero-`%` files are named in the sweep's "No false negatives" section —
plus `docs/epistemic/PROGRESS.md` (annex), `docs/evidence/README.md`, and
`docs/evidence/arena-4x4-undef/3x3-prefix.txt` (to check the
`arena-audit.md:148` 3×3 range — it is a different, smaller run and verifies
nothing there).

## Runs (verification instruments)

Tool runs (this machine, working tree as above; binaries from
`zig build -Doptimize=ReleaseFast` predating this task, unmodified):

```
bin/weizigo-chainability artifacts/oracle-2x2.wzo --examples 0   # 82/106 = 77.36% ko; 16/82 = 19.51% within; 0 outside
bin/weizigo-chainability artifacts/oracle-3x2.wzo --examples 0   # 378/918 = 41.18%; 72/378 = 19.05%; 0 outside
bin/weizigo-chainability artifacts/oracle-3x3.wzo --examples 0   # 8,698/24,826 = 35.04%; 688/8,698 = 7.91%; 0 outside
bin/weizigo-chainability artifacts/oracle-4x3.wzo --examples 0   # 170,276/640,110 = 26.60%; 6,092/170,276 = 3.58%; 0 outside
bin/weizigo-reachcensus artifacts/oracle-3x3.wzo --games 2000    # oracle 6,000/14,000 = 42.86%; oracle-rt 41.38/42.00; random 52.14/51.59; mixed 48.45/47.58; engine 4,433/11,437 = 38.76%; opp 6,193/10,496 = 59.00%
bin/weizigo-reachcensus artifacts/oracle-4x3.wzo --games 2000    # random 38.11/39.56; mixed 11,749/29,362 = 40.01 node + 40.01 game (coincidence confirmed genuine); engine 4,780/15,178 = 31.49%
bin/weizigo-reachcensus data/oracle-4x4.checkpoint.wzo --games 2000  # oracle 28,000/28,000 = 100.00%; random 24,622/85,200 = 28.90/31.84; mixed 15,314/44,504 = 34.41/34.75; engine 4,941/22,750 = 21.72%
```

All seven reproduced the documents' printed figures **exactly** (those rows
are the sweep's ★G calibration). Artifact identity:

```
shasum -a 256 -c artifacts/SHA256SUMS          # 4× OK
data/oracle-4x4.checkpoint.wzo            sha256 a2174fedd6a0591dc66b…  (first-16 matches the reachcensus/psk-binding notes)
data/oracle-4x4-parallel.checkpoint.wzo   sha256 28afa11bf095554ed313…  (matches docs/evidence/README.md BULK table)
```

Arithmetic batch (one `python3` heredoc, ~35 fraction recomputations): every
explicit `a/b` percentage in the tree — reconciliation trio (21.3172 / 21.3332 /
21.2696), kill census (21.32/21.24/21.63/25.01), L==H fractions (65.69/73.53/
78.68), ko-census row, B43 arena row, persona rows, psk-binding rates and
`d==2` shares, M4 survivorship bound (2.51%), the 4×4 engine totals
(130,171 plies / 1,015,076 candidates — both match the note's prose). The
batch also produced every FAIL's counter-evidence:

- decile histogram `13+14+13+12+11+10+8+7+5+2 = 95`, first-half sum `63`;
- `321,689/531,441 = 60.53` (truncated to "60" at `scaling-census.md:15`);
- `4,941/21,754 = 22.713` vs `4,941/21,750 = 22.717`
  (`reachable-…:280` 22.72% input pair);
- psk stability spreads: 3×3 silent `10.1%`, 4×4 silent `16.7–17.0%`
  relative, vs the printed "≲8%";
- kostate 4×3: `638,266/321,689 = 1.984` (+98% over *legal positions*);
  pattern-consistent denominator (≈1.8× legal per the doc's own calibration 2)
  gives ≈ +10–16%.

No `data/`, `artifacts/`, or engine file was written; nothing outside
`docs/evidence/GLOBAL.DENOMINATORS/` was created or modified by this task.

## Calibration of the sweep itself (per README P3)

- **Known-good it must pass:** the three reconciliation rows
  (`ko-sensitive-chainability.md:142–144`) with full `n/d`; the small-board
  chainability table (`:63–67`); the reachcensus headline rows
  (`reachable-…:147–150, :182–185`); the B43 3.4% = 123/3,600. The sweep
  passes all of them, and for six of the seven instrument runs the pass is
  backed by an identical re-run, not just arithmetic.
- **Known-bad it must catch:** the three denominator-free "21.3%" sites
  (`retrograde-4x4.md:22,:31,:94` — the surviving residue of the
  21.27/21.32/21.33 confusion the chainability doc's Reconciliation section
  describes) and `PROGRESS.md:102` (the 21.27-vs-21.32 pairing). The sweep
  verdicts all four FAIL. If the sweep had found zero FAILs, the brief says
  that itself is a finding — it found 14 + 2 annex instead.

## Resumption (2026-07-29)

The first pass of this audit (sweep + this file) was written to the working
tree 2026-07-29 ~02:23 local; the host kernel-panicked minutes later (Jetsam
event 02:33:23, per `untracked/msg/milestone-01-ko-reframe/019` and
`docs/infra/host/incident-2026-07-29.md`) before the worker reported
completion, so the board showed EXP-12 "dispatchable" and the model-perf
ledger recorded a PARTIAL — both superseded by the deliverables on disk.

**Done on resumption (Kimi K3, fresh context):**

- Read the brief, `STATE.md`, messages 019/020, and the model-perf PARTIAL
  note; confirmed the deliverables meet every acceptance criterion in the
  brief (table, counts, FAILs grouped by kind, no-false-negatives section,
  ≥3 ★G + ≥3 ★B calibration, honest negatives).
- Swept the one file added after the first pass
  (`h5a-player-mitigation-2026-07-28.md`: two `%` tokens, one row, PASS —
  the +6.8 % per-genmove overhead reconciles exactly from the doc's printed
  inputs, load exclusion included; wall-clock comparison not re-runnable as
  an audit instrument, noted as such in the sweep).
- Re-verified on resume: `shasum -a 256 -c artifacts/SHA256SUMS` 4× OK;
  `bin/weizigo-chainability artifacts/oracle-2x2.wzo --examples 0` →
  77.36% ko / 19.51% within / 0 outside — identical to the pre-crash pass.
  The remaining six instrument runs stand: binaries and artifacts are
  byte-identical since then, and the runs' full output was already checked
  in the first pass.
- Updated the sweep's counts (37 files, 391 `%` tokens, 132 rows, 93 PASS)
  and marked EXP-12 `done` in `docs/infra/managent/tasks.json`.

**Not re-derived on resumption:** the six remaining instrument re-runs and
the ~35-fraction python batch — both stand from the pre-crash pass against
unchanged inputs.

## What was NOT done (scope honesty)

- No `docs/research/*.md` edit — fixes are proposals for file owners.
- The "denominator correct" column for rows marked PASS\* by unique-fit
  inference was not re-derived from raw run output where that output is
  uncommitted (e.g. 2×2/3×2/3×3 arena persona counts) — those are precisely
  the FAIL-numerator rows.
- `docs/epistemic/PROGRESS.md` has no sections literally named "Evidence" or
  "Research"; the annex covers all of its percentage-bearing sections
  (Central partition, Leak crisis, GTP player, Status). Any other
  `docs/epistemic/*.md` is outside the brief.
- The 4×3 no-ko reachable count needed to give `kostate-…:224`'s true value
  was not produced (that is the fix-proposal's rerun, a separate detector
  walk on the EXP-3 instrument, not this audit's job); the FAIL verdict rests
  on the denominator being wrong and unnamed-as-used, which is established.
