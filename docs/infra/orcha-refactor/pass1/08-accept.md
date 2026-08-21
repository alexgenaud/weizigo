# Pass 1 — accept (`08-accept.md`)

**Owner:** deepseek-v4-pro / T557 · **Date:** 2026-08-21 · **Verdict: ACCEPT**
(previously PASS-WITH-FINDINGS at phase 7; the four remaining musts are now closed).

## 1. What pass 1 delivered

One Zig verb `managent treekill` in `src/managent/main.zig` (read-only default, `--kill`,
`--seed`, `--since`, `--protect`, `--rounds`, `--settle-ms`, `--ps-fixture`, five exit codes,
tab-separated stdout). `tools/runner` now calls it on three of its four exit paths — ceiling
C1, normal C2, exception C3 — and the host guard C4 reaps the culled member's subtree instead
of `os.kill`-ing one pid. The old `killpg` path is deleted. Run records carry the reap verdict
(`reap_claimed` / `reap_survivors` / `reap_ok` / `reap_unknown_partial`) and, when the host
guard culls mid-run, a `cull_reaps` list (C6). The build row's kanban acceptance gate is the
mechanized deletion grep (B-6).

## 2. Acceptance gates (phase 8 evidence, D31)

| gate | result |
|---|---|
| `zig build` | exit 0 |
| `tools/regression-process-ownership.sh` | **ALL CONTROLS PASSED — 40 PASS / 1 SKIP (sudo) / 0 FAIL** (arms N1-N5, S1-S9, M1-M4, I1-I3) |
| `tools/regression-runner-guard.sh` | all controls passed |
| claimlint | at the recorded floor — **no regression from pass 1** (11 pre-existing C2 dead links, 1 pre-existing C7 non-conforming file, both predate this pass) |
| full `zig build test` | pass-1's regressions green inside it; remaining reds are pre-existing (`rules.zig` root+engine mega-binary quirk, watch-fleet T492) or the pending `bin/managent` deploy (phase 9) |

## 3. Findings disposition (07-build-audit-disposition.md)

11 findings, all ACCEPT. **B-1..B-6 CLOSED** (the two audit criticals at D24, the four musts
B-3..B-6 at D27/D28/D29/D30). **B-7..B-11 (should/could) remain open** — bounded, none touch the
closure itself; recorded here as deferred, not silently dropped.

**Correction (D33):** the D27 B-3 scorecard charged the sonnet/opus lanes with fabricated
verification; a fresh Opus review (`findings/T557-b3-verification-review.json`) retracted it
(both DEFEND). The B-3 winner (DSPro) stands on cost/appetite + the extra N4 guard, and arm
**S9** was added so the suite exercises the retry path B-3 added.

## 4. Stated unknowns — never phrase as "no orphans"

- **r4 (post-snapshot escapees) is unmeasured** (OQ2): the verb reports `reap_unknown_partial`
  honestly when the seed is empty, but a member forked after the last snapshot is a residue
  this pass does not bound. No claim of completeness is made.
- **Post-spawn pid reuse is residue** (D-1/R4), not closed.
- **ollama model residency is NOT closed by the verb** (R3): the model runs under `ollama serve`,
  a daemon-owned sibling the verb cannot reach by pid. `ollama stop <model>` is a **Could**,
  deliberately not built. **A green suite must not be read as the ollama leak closed** — it
  closes the compile-family `killpg`-crash class (C1/C4) only.

## 5. Open rulings (unchanged, queued for the operator)

1. G3 family-exclusion counting rule. 2. spec-C detach exemption (`01-spec.md` open question 1).
3. Bookend commit of the round-1 artifacts (this commit).

## 6. Successor state

Pass-1 artifacts are UNCOMMITTED; the bookend commit closes T554/T555/ORCHA-FLASH. Remaining
queue: t11 (appetite-design audit + model-perf restructure) and the ladder races, both under the
standing race-field constraint (Claude + DeepSeek API only, no local/Ollama).
