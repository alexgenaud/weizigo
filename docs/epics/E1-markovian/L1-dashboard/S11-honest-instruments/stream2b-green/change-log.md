# stream2b-green — change-log (T872 delete wave)

**Task:** T872 · **Worker:** deepseek-v4-pro/T872.2 · **Date:** 2026-08-24
**Landmark:** advances `L1 (the dashboard tells the truth)` — the first execution wave of the
green-up: the 11 DELETE verdicts of `classification.md`, executed as deletions only.

This log is the interpretation key for what-is round 2. One entry per deleted check. Each entry
states what was deleted, what disappears from reports, and what is left untested — copying the
classification's own words, then **confirming or correcting them at the moment of deletion**.

---

## 0. The eleven deletions, at a glance

| # | verdict | artefact | whole script or arm | net lines (delete) |
|---|---|---|---|---|
| 1 | R24 | `tools/regression-managent-assert-store.sh` | arm (deploy-freshness preflight) | 20 |
| 2 | R25 | `tools/regression-managent-holds.sh` | arm | 20 |
| 3 | R26 | `tools/regression-managent-impression-gate.sh` | arm | 19 |
| 4 | R27 | `tools/regression-managent-integrity.sh` | arm | 20 |
| 5 | §4.1 red | `tools/regression-runner-guard.sh` | whole script | 79 |
| 6 | V5 | `tools/regression-runner-host-guard.sh` | whole script | 14 |
| 7 | V6 | `tools/regression-subagent-resident-gate.sh` | whole script | 31 |
| 8 | V1 | `src/vb_fixpoint.zig` `checkI8` (+`I8Result`) | stub | 42 |
| 9 | V2 | `src/vb_fixpoint.zig` `checkI11` (+`I11Result`) | stub | 41 |
| 10 | V7 | `tools/orcha-acceptance.sh` AC3 | arm | 3 |
| 11 | V8 | `bin/argus` `claimlint-green` slug | slug + method | 65 |

*(Line counts are `git diff --stat` values for each file as committed; the three §4.1 scripts are
whole-file deletions. The build.zig unwiring of the three scripts is logged under entries 5–7.)*

---

## 1. R24 — deploy-freshness arm in `regression-managent-assert-store.sh`

**What was deleted:** the `stamp_of` / `BUILT_STAMP` / `DEPLOYED_STAMP` preflight block (20 lines)
that compared `bin/managent`'s embedded build stamp against `zig-out/bin/managent` and failed the
whole script when they differed. Replaced with a comment pointing at `tools/smoke.sh`.

**What disappears from reports:** nothing measured about `assert-store` — the script's remaining
arms (store-write refusal, census integrity) are untouched.

**What is left untested** (classification: *"nothing — the same job is done by `tools/smoke.sh`, by
`bin/argus --mode doctor`'s staleness reading, and by `managent audit`'s closing line"*):
**CONFIRMED.** `tools/smoke.sh` is wired into `test_step` (`build.zig:1289`), so the deploy-freshness
job has a surviving, already-wired preflight. Deleting the four re-implementations removes four
redundant reds, not one scrap of coverage.

---

## 2. R25 — deploy-freshness arm in `regression-managent-holds.sh`

**What was deleted:** the identical `stamp_of` preflight block (20 lines).

**What disappears from reports:** nothing — the holds arms (parse, conflict, list) are untouched.

**What is left untested:** as R24. **CORRECTED on the "only red arm" claim.** The post-deletion
sweep shows `regression-managent-holds.sh` **still red (rc=1)**, for a *second* cause the
classification missed: its T539 arm (`holds= gets a writer, --sync reconciles`) fails because the
deployed `bin/managent` does not yet implement the holds writer (`add T539W1/W2/W3 exited
non-zero`). The deploy-freshness arm WAS redundant and is gone; the script is now red for the T539
cause alone — which is T880's in-flight fix, not this wave's subject. Nothing left untested by
*this* deletion: the deploy job still has `tools/smoke.sh`.

---

## 3. R26 — deploy-freshness arm in `regression-managent-impression-gate.sh`

**What was deleted:** the same preflight (19 lines), including the `stamp_of` helper and the
`BUILT_STAMP != DEPLOYED_STAMP` comparison.

**What disappears from reports:** the `T268: deployed … == built …` line only.

**What is left untested:** as R24. **CONFIRMED** — with the arm gone the script's remaining arms
(done-path absorption gate) are what actually run.

---

## 4. R27 — deploy-freshness arm in `regression-managent-integrity.sh`

**What was deleted:** the same preflight (20 lines), the longest of the four variants.

**What disappears from reports:** the `T268: deployed stamp check` line only.

**What is left untested:** as R24. **CORRECTED on the "passes outright with a fresh binary" claim.**
The post-deletion sweep shows `regression-managent-integrity.sh` **still red (rc=1)** — it now dies
at arm 3 (`parseStateJson` → `managent suggest`) under `set -e`, a failure the deploy arm had
previously masked. The deploy arm WAS redundant and is gone; the revealed arm-3 failure is a
pre-existing FIX-THE-TEST/CODE concern for a later wave, not a gap this deletion opened (the arm
always existed; it just never ran before). Nothing left untested by *this* deletion: the deploy job
still has `tools/smoke.sh`.

---

## 5. §4.1 red — `tools/regression-runner-guard.sh` (whole script)

**What was deleted:** the whole script (79 lines) and its `build.zig` wiring (the `runner_guard_regression`
step, one `addSystemCommand` block).

**What disappears from reports:** a red that asserted *the T362 `host_total // 8` memory-pressure
guard fires* — a guard T821 deleted. The seeded arm could never fire again; the script was testing a
corpse.

**What is left untested:** host-pressure admission. **CONFIRMED with one note:** the classification's
own §4.1 says this is *"covered by `regression-arbiter.sh` once §4.1 wires it"* — and `arbiter.sh` is
**not yet wired** (it is unwired-green, U1, and T873's fix-test wave wires it). Until then, host-pressure
admission has no live gate. That gap is real but not created by this deletion: the deleted script was
red-on-a-dead-guard, and the two siblings below were `exit 0` stubs. Deleting three checks that did not
measure leaves the same zero measurement, now honestly visible.

---

## 6. V5 — `tools/regression-runner-host-guard.sh` (whole script)

**What was deleted:** the whole script (14 lines: three `echo` lines + `exit 0`) and its `build.zig`
wiring (`build.zig:333`).

**What disappears from reports:** one guaranteed pass in the suite's passing count. Its own header
said *"This script cannot be repaired into passing"* — the T362 floor and tenant add-back it tested
were deleted by T821.

**What is left untested:** host-pressure admission, as §5. **CONFIRMED.**

---

## 7. V6 — `tools/regression-subagent-resident-gate.sh` (whole script)

**What was deleted:** the whole script (31 lines: same `exit 0` stub shape) and its `build.zig` wiring
(`build.zig:352`).

**What disappears from reports:** one more guaranteed pass. The T713 resident-aware memory gate it
tested was deleted by T821.

**What is left untested:** host-pressure / resident-budget admission, as §5. **CONFIRMED.**

---

## 8. V1 — battery I8 `checkI8` (stub) in `src/vb_fixpoint.zig`

**What was deleted:** `I8Result` (the struct), `checkI8()` (which returned `.not_applicable`
unconditionally), and the two `test "I8 not_applicable stubs"` assertions (42 net lines, counting the
header rewrite). The battery harness's I8 slot now reports `external`, and `vb_health.runI8` returns
`.external` directly.

**What disappears from reports:** the `I8: not-applicable` line in every battery report — today's run
prints exactly that line, and it was a claim of coverage for a check that never ran.

**What is left untested:** *"the loopy-fixpoint vs first-revisit comparison at 2×2 — which the stub
never tested either; the real coverage is the committed Python fixture the code's own comment names"*.
**CONFIRMED** — `docs/evidence/QA-026/calibration-2x2-mismatch.py` exists on disk, and the battery now
reports I8 as `external`, naming that fixture as its coverage. No gap is created; a misleading
`not-applicable` line is replaced by an honest `external` pointer.

---

## 9. V2 — battery I11 `checkI11` (stub) in `src/vb_fixpoint.zig`

**What was deleted:** `I11Result` (the struct), `checkI11()` (which returned `.not_applicable` with a
GAP-5 note), and the `test "I11 not_applicable stubs"` assertion (41 net lines). `vb_health.runI11`
now returns `.external`; the harness slot reports `external`.

**What disappears from reports:** the `I11: not-applicable` line.

**What is left untested** (classification V2: *"battery-vs-solver legal-move-set agreement —
genuinely uncovered, by anything"*): **CORRECTED — this statement is wrong at the moment of deletion,
and the code comments written to enshrine it were corrected in the same wave.** Battery-vs-solver
legal-move-set agreement **is** covered: the standalone `src/vb_i11.zig` module (T346/T473) compares
the battery's independent move generator (R8, `vb_movegen.zig`) against the kernel's
(`src/rules.zig`), with a null control, a seeded-defect control, exhaustive 2×2/3×2/3×3/4×3 runs, a
50k stratified 4×4 sample, and a gated full-table 4×4 arm — and it is wired into `zig build test`
(`build.zig:1437`, `test_step.dependOn(&run_vb_i11_tests.step)`).

So deleting `checkI11` reveals no gap. It removes a redundant `not-applicable` stub whose real job is
already done, and better, by a module the classifier did not read (classification §2.3 names exactly
this blind spot: *"I read every failing script's relevant arm … I did not read all 88 in full"*).
The battery harness's I11 slot now reports `external`, delegating to `vb_i11.zig`. **There is no
"genuinely uncovered" gap to carry to the claims register** — the follow-up row anticipated by the
brief is not needed for I11. (The stale GAP-5 premise — "dump format unspecified" — was itself
resolved by T438, which made `vb_i11.zig` regenerate its fixtures in-memory.)

---

## 10. V7 — `tools/orcha-acceptance.sh` AC3

**What was deleted:** the unconditional `say AC3 PASS "enforced by tools/hooks/pre-commit (T455)…"`
line (3 lines), replaced with a comment explaining the removal.

**What disappears from reports:** one of eleven acceptance lines, and a PASS the seat had been
reading as evidence.

**What is left untested** (classification: *"nothing — the T455 holder-collision refusal is really
covered by `regression-precommit.sh` and `regression-git-commit-mine-hook.sh`"*): **CONFIRMED.**

**Execution note on "renumber AC3 out":** the classification says *"renumber AC3 out"*. This wave
removed AC3 **without renumbering AC4..AC11 down**, because `tools/regression-orcha-acceptance.sh`
(the T537 regression) filters `AC6` and `AC7` **by exact id** (`c["ac"]=="AC7"` etc.). Renumbering
would silently re-target those arms at different checks and turn a green regression red. Removing AC3
and leaving the remaining ids stable is the only execution of "AC3 out" that does not break T537, and
the removal comment states this rationale inline.

---

## 11. V8 — `bin/argus` `claimlint-green` checklist slug

**What was deleted:** the `claimlint-green` branch in `_run_slug` and the entire `_check_claimlint`
method (65 lines), whose regexes (`C1a orphans:`, `C2 total:`, `C6 cite-tag mismatches:`) never
matched the real claimlint labels (`C1a ORPHANED orphans: 0`, `C2 DEAD-LINKS total: 0`, …), so every
parsed value stayed `None` and the check emitted *"at or below floor"* unconditionally.

**What disappears from reports:** the `checklist` mode, which has no production consumer (`DARGUS`
runs `--mode doctor` only). **And, deliberately NOT deleted:** the `CLAIMLINT_FLOOR = {"C1a": 10,
"C2": 12, "C6": 0}` attribute, which `doctor` check 9 (lockstep) and sweep's claimlint reading still
consume. The classification V8 said to delete the slug *"and with it … the second, looser
`CLAIMLINT_FLOOR`"* — but that attribute is shared live state, not part of the dead slug; deleting it
here would change `doctor`'s behavior, which is a FIX-THE-CODE concern (the floor's stale 10/12 vs
the real 0/0) owned by a later wave, not a deletion. The deletion leaves the attribute in place with a
comment naming that hand-off. **CORRECTED** against the classification's literal text, with the
reason stated.

**What is left untested** (classification: *"nothing — `tools/hooks/pre-commit` is the real floor
gate and it is green and wired"*): **CONFIRMED.**

---

## 12. Sweep comparison (acceptance condition 2)

Baseline: `untracked/greenup/sweep-pre/` — **65 pass · 23 non-zero · 1 timeout · 89 total** (T872
first dispatch, 2026-08-24T17:08–17:26Z, before any deletion).

Post-deletion: `untracked/greenup/sweep-post/` — **64 pass · 22 non-zero · 1 timeout · 87 total**
(this wave, 2026-08-24T18:17–18:43Z, after all eleven deletions).

The 87 vs 89 delta is 3 deletions minus 1 addition: `regression-runner-guard.sh` (was red),
`regression-runner-host-guard.sh` (was green), `regression-subagent-resident-gate.sh` (was green)
were deleted; `regression-bundle-header-parse.sh` (green, T880's in-flight test) appeared in the glob.

**Superset verdict: PASS, with two documented green→red flips, neither caused by this wave.**

| script | baseline → post | disposition |
|---|---|---|
| `regression-ollama-dispatcher.sh` | 0 → 1 | **excluded** by `SWEEP-CONTRACT.md` §4 (verdict is a function of host free memory; the flip was already observed between classification and baseline) |
| `regression-inbox-loop.sh` | 0 → 1 | **concurrent-edit artifact**, not a break: the sweep caught `bin/subagent` mid-edit by T890 (its `_resolve_model` was halfway through changing from a 2-tuple to a 3-tuple return — the script hit `ValueError: too many values to unpack`). Re-run standalone after T890's edit settled → **rc 0, arm 5 PASS**. Two readings disagree, ambient input named (`bin/subagent` in-flight). |

Every other script obeys the superset rule: the four `regression-managent-*` deploy arms moved
`assert-store` and `impression-gate` red→green, left `holds` and `integrity` red (for the T539 and
arm-3 causes documented in §2/§4), and no other previously-green script regressed. The three
deleted scripts are gone from the glob; `regression-watch-fleet.sh` is `TIMEOUT` on both sides.

---

## 13. Net-negative lines (acceptance condition 4)

`git diff --stat` across the five code commits of this wave: **+78 insertions · −566 deletions =
net −488 lines.** Per commit: `12e7055` (−309) · `21f1659` (−69) · `a3f3dc1` (−51) · `6766112`
(+3) · `2073672` (−62). The one per-file positive (`orcha-acceptance.sh`, +3) is a three-line
removal-comment replacing a one-line unconditional PASS; the wave as a whole is net-negative.

The two documentation deliverables (`change-log.md`, `findings/T872-greenup-delete-wave.json`) are
additive by design — a deletion log is the point of the row — and are not counted in the −488.

---

## 15. `zig build test` (acceptance condition 3)

- `zig build` compiles clean (rc 0) — the build graph is intact after the `build.zig` unwiring:
  no step references a deleted script (grep of the three memory-guard paths over `build.zig` = 0).
- `zig test src/vb_fixpoint.zig` → **All 14 tests passed** (I4/I7/I9 anchors; the two deleted I8/I11
  stub tests are gone, nothing dangles).
- Full `zig build test` was run to the end of the wired step list: it progressed through compile,
  the zig module tests, and the wired regression scripts, failing only on the pre-existing known-reds
  (`regression-task-id-archive.sh` R6, `regression-window-resilience.sh` R19,
  `regression-dispatch-verification.sh` R17 — all in the classification's red set). It then blocked
  **indefinitely on `regression-watch-fleet.sh`** (R7): that script launches a live-TUI dashboard that
  waits for input, and as a wired `addSystemCommand` step it has no watchdog. The same hang is
  reproduced by several concurrent lanes' builds simultaneously (three other `regression-watch-fleet.sh`
  processes stuck at the time of the run), so it is pre-existing and unrelated to this wave. The build
  test was terminated at that point and the block is on record as R7, not a new failure.

## 16. What this wave deliberately did NOT touch

- **R1–R23 (FIX-THE-TEST / FIX-THE-CODE reds)** — untouched. They are T873's and T874's subjects.
- **V3 (STANDING-REEVIDENCE trigger), V4 (`suite-truth.sh` summary comparisons), V9 (dead FAIL
  branches), V10 (SKIP-as-PASS)** — untouched; all are FIX verdicts.
- **U1–U5 (unwired-but-green)** — untouched, including `regression-arbiter.sh` (T873 wires it).
- **`docs/epistemic/CLAIMS.md`** — untouched (single owner). The brief anticipated a follow-up row to
  carry "I11's gap" to the register; §9 above shows there is no such gap, so no register row is owed.
- **`bin/argus`'s `CLAIMLINT_FLOOR` value** — left in place (see §11); its stale 10/12 is a
  FIX-THE-CODE item for a later wave, not a deletion.
