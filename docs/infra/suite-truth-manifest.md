# suite-truth — the surfaces manifest (CONSOLE + EVIDENCE)

**Task:** T561 · **Author:** deepseek-v4-flash · **Date:** 2026-08-21

This is the second half of the suite-truth gate, added by T531 (two-surfaces
split). It is read by `tools/suite-truth.sh` (`--surfaces`, default
`docs/infra/suite-truth-manifest.md`) alongside the reds manifest
`docs/infra/suite-truth.md`. The two files gate two different things:

| file | gates | surface |
|---|---|---|
| `docs/infra/suite-truth.md` | which steps fail (RED/COUNT) | the suite's failing set |
| **this file** | how the suite speaks (CONSOLE noise + EVIDENCE readings) | the two output surfaces |

Ruling 4 (`docs/status/ROADMAP-2026-08-20.md` rev 3) settled T351: the suite
has two output surfaces, not one. The CONSOLE carries the pass/fail summary
and owes zero failed-command noise; the ARTIFACT
(`untracked/log/suite-evidence.log`, written by `src/evidence.zig` when
`WEIZIGO_EVIDENCE` is set — `tools/suite-truth.sh` always sets it to an
absolute path) carries the `[EXPECTED]`/I4–I9 instrument readings. Both are
gated here, because a surface nobody reads is a surface nobody notices going
quiet.

The lines below are the machine section, parsed by `tools/suite-truth.sh`
(exactly like the RED/COUNT lines in `docs/infra/suite-truth.md`). Do not edit
them without re-running the gate (ratchet only):

- `CONSOLE cosmetic-failed-command <n>` — the allowed number of cosmetic
  `failed command:` lines (test binaries that wrote to stderr but passed).
  Relational in the gate, hardcoded here: `cosmetic = test-binary
  failed-command lines − crashed test steps`. Ratchet down only; 0 is the
  floor.
- `EVIDENCE <prefix>` — a reading the run's evidence artifact must carry,
  matched at the start of a line (`awk 'index($0, n) == 1'`). A declared
  reading that the artifact stops emitting fails the gate BY NAME — that is
  the point: an instrument that went silent no longer hides in a quiet
  console.

## The measured baseline

- **Run:** `sh tools/suite-truth.sh --evidence <dedicated artifact>`,
  2026-08-21, guarded (`tools/runner`, ReleaseSafe), seed `0xb04f6ae`, wall
  886.3 s. Two concurrent unguarded suites (T558's plain `nohup zig build
  test`, started 21:06) were running during the window; the evidence artifact
  was dedicated (outside the tree, under the runner's scratch) so no cross-run
  lines could leak in. The gate's own default artifact is
  `untracked/log/suite-evidence.log` (see `tools/suite-truth.sh`
  `EVIDENCE_DEFAULT`), matching the sibling reds manifest's log convention.
- **Suite verdict:** `Build Summary: 85/96 steps succeeded (6 failed); 777/778
  tests passed (1 skipped)` — **0 crashed tests** (the qa023/t419/vb_bellman
  crashes of the 2026-08-18 baseline are fixed at HEAD).
- **Console surface:** 2 test-binary `failed command:` lines, 0 crashed test
  steps → cosmetic = 2. Both are the `oracle_v2_accept` seeded-defect
  controls (`A1 REFUSAL` / `A2 L-VIOLATION`), which print through
  `util.warn` (stderr) rather than `evidence.print` — the same class T531
  converted everywhere else. Ratchet target 0 once that conversion lands.
- **Evidence surface:** every reading declared below was present in the
  baseline artifact and is emitted by a module that compiles at HEAD (the
  five compile-failing modules — keybyte_differential, smd1_engine,
  vb_closure, vb_i11, vb_mutants — emit none of these lines, so a declared
  reading cannot silently vanish with a compile failure).
- **Reds drift (reported, not owned here):** the 2026-08-18 reds manifest is
  stale — qa023_brute_2x2 / t419_taxonomy / vb_bellman_4x4 no longer crash,
  regression-absorption-machinery is green, regression-watch-fleet is a new
  red, and five modules fail to *compile* (a class the gate's RED-module
  regex does not extract). Ratcheting `docs/infra/suite-truth.md` to the
  current failing set is a separate task.

## Machine section — parsed by `tools/suite-truth.sh`

Do not edit the lines below without re-running the gate (ratchet only).

CONSOLE cosmetic-failed-command 2
EVIDENCE [EXPECTED] evidence-sink control: artifact write ok
EVIDENCE [EXPECTED] M9 green: status=pass
EVIDENCE [EXPECTED] M9 red: status=fail
EVIDENCE [EXPECTED] M9 double-red: status=fail
EVIDENCE I4 2x2: violations=
EVIDENCE I4 4x3: violations=
EVIDENCE I4 3x3: status=
EVIDENCE I4 3x3 CALIBRATION L-only:
EVIDENCE I4 3x3 CALIBRATION verdict-bucket:
EVIDENCE I4 2x2 synthetic: status=
EVIDENCE I4 2x2 synthetic CALIBRATION equal:
EVIDENCE I4 4x4 sample: groups=
EVIDENCE I7 3x2: terminals_bad=
EVIDENCE I9 2x2: expected=
EVIDENCE [I5] BFS:
EVIDENCE [I5] Tarjan:
EVIDENCE [I5-diff 3x2] general:
EVIDENCE [I5-diff 3x2] specific:
EVIDENCE T345 KEY-4x4 RESULT:
EVIDENCE T345 KEY-4x3 RESULT:
EVIDENCE T345 calibration:
EVIDENCE S2-4x4 (k<=5):
EVIDENCE S2-4x4 (k<=8):
EVIDENCE 2x2: bijection over all 81 boards VERIFIED
EVIDENCE 3x2: bijection over all 729 boards VERIFIED
EVIDENCE 3x3: bijection over all 19683 boards VERIFIED
