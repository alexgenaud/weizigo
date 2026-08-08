# Evidence re-point: `/tmp` citations in committed docs — T421 (2026-08-08)

**Task:** T421 · **Role:** worker · **Model:** deepseek-v4-flash · **Date:** 2026-08-08
**Landmark:** advances `L4 (the ledger is clean)` — the failure `AGENTS.md` names by
precedent ("Evidence in git, or the claim is not proven… never `untracked/`") has been
happening quietly for weeks: 344 distinct `/tmp` paths cited in committed docs, 43 already
dead when the 2026-08-08 rescue ran. This row re-points what could be re-pointed, marks
what is dead, closes the claimlint hole that let the defect pass while the file still
existed, and states the rule in `AGENTS.md`.

Companion: `findings/T421-evidence-repoint.json` (conforming, `claims: []` — no status
changes, per bar). The rescue of record is `docs/evidence/RESCUED-tmp-2026-08-08/`
(committed `07d8c54`); nothing in it was modified.

---

## 1. Readings — snapshot and final, with the delta

**Snapshot (2026-08-08, Orchestrator sweep, pre-rescue; also in `MANIFEST.json`):**
344 distinct `/tmp` paths cited in committed docs · 72 citing documents · 43 already
destroyed · 278 surviving files rescued (4.6 MB).

**Final (this run, after rescue + T420 + this row):** the sweep
`git grep -o '/tmp/weizigo[^ )]*' -- docs/` now reads:

| class | occurrences | meaning |
|---|---|---|
| RESCUED | 278 | all inside `MANIFEST.json` itself (the rescue record's `src` fields) — **zero re-pointable citations remain outside the rescue dir** |
| LOST | 123 | 39 distinct manifest-lost paths cited in non-rescue docs (the other 4 lost paths appear only as sweep-truncated fragments, now annotated via their full brace/glob forms) |
| NEITHER | 101 | cache parameters, `zigcache` mentions, T420's unrescued paths, globs, operational prose |
| **total** | **502** | down from 785 (post-rescue) — the 283 re-points |

Distinct paths cited: **359**. Non-rescue files still containing a `/tmp` citation: **72**
(denominator = the snapshot's 72). **The delta from the snapshot is a finding:** T420,
running concurrently, added **14** new `/tmp` citations across 4 new committed files
(`4x4-THIRD-PARTY/max-strength-2026-08-08.md` ×4, `analyze-t420.py` ×4, two raw run logs
×3 each) — all pointing at `/tmp/weizigo/t420/…`, which the rescue did not cover. The
`t420/t381-evse` binary those docs cite **still exists in `/tmp` today** and will die with
the next sweep: a live instance of the exact defect this row closes. D063's instruction to
T420 ("cite committed paths") did not reach its deliverable doc. **How fast it recurs:
14 citations in the hours between rescue and re-point.**

**C10 VOLATILE (the new claimlint check, report-only) at close:** 1059 total (212 `/tmp` ·
3 `/private/tmp` · 24 absolute-outside-tree · 820 `untracked/`), measured on the tree at
close — which includes this row's own doc (it describes `/tmp` citations) and Fable's
in-flight untracked week-close audit. The count is a live census, not a stable artifact:
it moves as docs are written, which is the check working. Every pre-existing claimlint
counter is byte-identical to the pre-row baseline
(`/tmp/weizigo/T421-baseline-claimlint.txt`): C1a 0 · C1b 0 · C2 11 · C3 48 · C4 45/2 ·
C5 0 · C6 0 · C7 2 · C8 0 · C9 0 · calibration PASS. The one non-C10 change is C7's
`files scanned` denominator (293 → 294): this row's own `findings/T421-…json` joined the
scan — a count of files, not a violation.

## 2. What was done

### 2.1 Re-pointed — 283 citations, 11 files, every target verified `git ls-files`
Every citation whose normalized path has a counterpart in `MANIFEST.json` was replaced by
its `docs/evidence/RESCUED-tmp-2026-08-08/…` destination, mechanically, longest-first, with
a **refusal if any destination was not tracked** (none was). Files: the two raw run JSONs
(132 sgf paths each), `old-vs-new`, `self-play-consistency`, `symmetric`, `gnugo-4x4`,
`c1-contrast`, `divergence-matrix`, `instrument-coverage`, `subagent-reach`,
`pro-vs-flash` (the `race1_grader.py` grader). The JSONs remain valid JSON.

### 2.2 Annotated — 28 `EVIDENCE LOST` markers, 17 docs, 39 distinct dead paths
Every dead citation in a prose `.md` document now carries
`EVIDENCE LOST (path was /tmp, destroyed before rescue on 2026-08-08)` — in prose inline
after the path, inside command blocks as a `#` comment line. Citations were **not deleted
and not replaced** with invented paths. The dead paths are: the PSK-divergence probe binary
(7 sites), the eye-prune falsification probe, the T212 build logs, the oracle-v2 binaries
(`weizigo-oracle-v2`, `accept`, `orcha-accept`, `T270-calib`), the T266/T277 calibration
mutants (`t266-mutants`, `t277-mutants`, `shift-mutant.wzo2`), the T313 ReleaseSafe build
prefix/binary, the T314 snapshot binary, the T274 tie artifacts (`T274-tie-0.wzo` and the
brace-expanded stdout globs), the lane worktrees (`lane-wt-r371`, `lane-wt-t376`),
`invsym-4x4.log`, the `t325-run-*.log`/`t314-threads-*.log`/`*-baseline.jsonl` globs, the
census probe cache files. The four manifest entries that the sweep truncated
(`T274-tie-{0`, `t408/runs/{kimi`, `t416/audit-{allties-3x3`, `t416/out/{3x3-allties`)
were annotated via their full brace forms in the citing docs.

### 2.3 Left deliberately untouched — and why (each is a judgment to overturn, not an oversight)
- **Data artifacts** (`releasesafe-*.log` ×3, `t314-threads-*.log` ×5, `QA-012/run-*.txt`
  ×6, `T392-suite-….stdout`, `baselines.json`, `check_i2_wzo2.py`): verbatim run records;
  their `/tmp` mentions are recorded *data*, not citations. Annotating would corrupt JSON
  validity or the record's verbatim-ness (the rescue itself copied them verbatim). The
  losses are recorded here and in the manifest.
- **Kanban stores** (`tasks.json`, `directives.jsonl`, `archive.json`): binary-owned; the
  project rule forbids hand-editing them. Their `/tmp` mentions are historical notes.
- **T420's 4 files**: unrescued targets — there is nothing to re-point to. Reported as the
  delta finding (§1).
- **Build-cache parameters** (`ZIG_LOCAL_CACHE_DIR=`, `ZIG_GLOBAL_CACHE_DIR=`,
  `--cache-dir`, `--global-cache-dir`, "caches under …"): caches were never evidence;
  an `EVIDENCE LOST` marker would misrepresent what was lost. 5 lost-list paths appear
  only in this context (`muhtasib-audit-chunk3.md`, `GLOBAL.H1-CENSUS/PROVENANCE.md`,
  `kostate-census-2026-07-28.md`).
- **Already-honest docs**: `optimal-cycle-test-2026-08-08.md` names the committed durable
  copies at `docs/evidence/T416-OPTIMAL-CYCLE/` ("`/tmp` is not evidence (AGENTS.md)") —
  the scratch copies died but the evidence survives; `reconciliation/PROVENANCE.md` is
  itself the loss record ("the source is permanently lost"); `PACKET.md` says "deleted
  after the run"; `fleet-hardening-round-2.md` says "were rescued into …";
  `subagent-reach-2026-08-07.md` says "(disposable; evidence quoted here)";
  `parallel-fixpoint-measurement-2026-08-03.md` says "(disposable) and are not evidence
  in the git sense"; `goban-pathology-2026-08-05.md` says "(disposable)". Each reader is
  already told the truth.

## 3. Which claims the 43 dead paths supported — the load-bearing output

Every probe **source** is committed (`src/kostate_census.zig`, `src/psk_divergence.zig`,
`src/eyeprune_falsify.zig`, `src/oracle_v2_accept.zig`, the `t266_scan.py` /
`t277_shift_mutant.py` / `t266_calibrate.py` instruments, etc.), and every measured
**output** that a register row cites is committed (the census `.txt` files, the scan
outputs, the run `.log`s, the `.buildlog`, the `T416-OPTIMAL-CYCLE/` JSONs). **No
PROVEN or CLAIMED row loses its primary evidence.** What died is the compiled-binary /
calibration-fixture layer. Rows whose *reproducibility* is degraded, and how:

| register row(s) | status | dead artifact | impact |
|---|---|---|---|
| `GLOBAL.H1-CENSUS`, `3x3.H1-CENSUS`, `4x3.H1-CENSUS` | PROVEN | census probe binary `test_census_pure` + its cache manifest | measured numbers survive in committed `.txt`; source survives (`src/kostate_census.zig`) → rebuildable. The recorded binary identity (hash) is gone; **re-run gives a new binary, not the recorded one** |
| `CODE.WZO2-PASS1-LAW`, `CODE.ACCEPT-KOKEY`, `CODE.WZO2-INCOMPLETE` (FALSE-AS-SCOPED), `WZO2-4X4-VALID` | PROVEN / FALSE-AS-SCOPED | T266/T277 calibration mutants (`t266-mutants`, `t277-mutants`, `shift-mutant.wzo2`) and the `accept` binary | the "instrument calibrated with a seeded shift mutant caught by three separate checks" claim can no longer be re-run against the *recorded* mutants. The mutant *generator* (`t277_shift_mutant.py`) is committed → the calibration is regenerable, but the recorded fixtures are gone. The scan outputs in the docs survive |
| `SPRINT-M4a-ACCEPT` | PROVEN | T212 build logs (`T212-build.log`, `T212-build-run2.log`) | the committed `.buildlog` + `.stdout` carry the acceptance; the ceiling-breach run-1 log variant is gone |
| `CODE.WZO2-RELEASESAFE-INV` | CLAIMED | ReleaseSafe build prefix + binary (`safe-build-full`, `safe-build-full/bin/weizigo-oracle-v2-build`, `safe-build/bin/`) | the run records are committed as `.log`s; the built artifact is gone — the byte-identity claim cannot be re-verified against the artifact itself |
| `CODE.PARALLEL-FIXPOINT-MEASURED` | MEASUREMENT | `t314-snapshot/weizigo-oracle-v2-build` | the 5 `t314-threads-*.log` run records are committed; the measured binary is gone |
| `GLOBAL.FIXPOINT-VS-SEARCH` | CLAIMED | T274 run artifacts (`T274-tie-0.wzo`, `.small.stdout` globs) | the row's support is the primary-source reading (MIGOS thesis) which survives in the committed `tie-experiment-T274.md`; the empirical sweep outputs are gone |
| `QA-012` | UNTESTED | PSK-divergence probe binary | run outputs survive in `QA-012/`; source survives → rebuildable; the row is UNTESTED regardless |
| `3x3.OPTIMAL-CYCLE`, `4x4.OPTIMAL-CYCLE` | MEASUREMENT | t416 scratch outputs | **support intact** — durable copies committed at `docs/evidence/T416-OPTIMAL-CYCLE/`; only the scratch copies died |

Bottom line for the Orchestrator: **no row needs a status change** (hence `claims: []`),
but if the register's C3 discipline is read strictly as "a re-runnable probe with its
recorded artifacts", the `GLOBAL.H1-CENSUS` family and `CODE.WZO2-PASS1-LAW` are the rows
closest to losing that property — both remain rebuildable from committed sources, neither
can reproduce the *recorded* binary/fixture identity. The T13 lesson ("the number survives
in git, the probe that produced it does not") applies to these at the artifact layer.

## 4. The claimlint hole — closed, test-first

C2 DEAD-LINKS flags only *missing* paths, so a `/tmp` citation whose file still exists
passed every check until the sweep destroyed the file — exactly too late. New check
**C10 VOLATILE** in `src/claimlint.zig`:

- flags any evidence path outside the repo in prose documents (`.md` under `docs/` +
  `AGENTS.md`, mirroring C4's scan scope): `/tmp/…`, `/private/tmp/…`, an absolute path
  outside the working tree (root-anchored words like `/genmove` and notation like `/L/H`
  are excluded; `/dev/null` is a device), and `untracked/…` — **whether or not the file
  exists today**.
- **report-only**: does not fail the run, does not move any floor, exit code unchanged.
- **test-first, per `AGENTS.md`**: `tools/regression-claimlint-volatile.sh` was written
  and shown **red** first — the pre-fix claimlint reported nothing for a fixture doc
  citing an *existing* `/tmp/weizigo/…` path (the seeded target is created on disk, so
  the file genuinely exists — which is the whole defect) — then went **green** after the
  fix: seeded-defect caught, report-only exit unchanged, null-control output byte-
  identical on the same tree. Wired into `zig build test` (`build.zig`).
- Calibration numbers: the check distinguishes by class and reports
  `total (tmp · private-tmp · absolute · untracked)`, so the flood of `untracked/`
  mentions (813 — largely deliberate project structure: task briefs, hash records,
  channel messages) does not drown the `/tmp` signal (204 at close).

**Proposed floor (separate, for the Orchestrator to ratify — not set by this row):**
the check is a standing debt census; the meaningful ratchet is the `/tmp` class, whose
defect component (re-pointable citations) is now **zero** in committed `.md` docs. The
residual `/tmp` count (204) is: annotated-dead citations (~40), build-cache parameters
(~33), operational prose/scratch guidance (~60), T420's unrescued paths (4 in `.md`),
globs/dirs and Fable's in-flight audit. A floor of **0** on the `/tmp` class is *not*
reachable today without first resolving the T420 residual and the deliberate residuals;
propose the floor as a **per-class** number after the Orchestrator decides which residuals
are acceptable. The `untracked/` class should likely never gate (it is project structure).

## 5. Enforcement

The rule is now in `AGENTS.md` ("Scratch is for working files; a citation is a
commitment"): anything a document cites must be committed under `docs/evidence/<claim-id>/`
before the row closes. Enforcement points, in order of leverage:

1. **pre-commit hook** (`tools/hooks/pre-commit`): once the C10 floor is adopted, add
   `CURRENT_C10=$(echo "$OUTPUT" | grep '^  C10 volatile evidence paths' | awk '{print $5}')`
   and a `regression "C10" …` call — 3 lines, same pattern as C2/C3/C6/C9.
2. **`tools/git-commit-mine`**: the wrapper already limits staged paths; a citation check
   belongs in the hook (above), not the wrapper, so the two cannot drift.
3. **`managent done`**: the git-aware deliverable check already refuses untracked/dirty
   deliverables; a `/tmp`-citation scan of declared deliverable docs is a natural
   extension but needs a design (the binary would have to run claimlint or reimplement
   the scan).

## 6. Counts with denominators

| metric | value | denominator |
|---|---|---|
| docs re-pointed | 11 | 72 |
| citations re-pointed | 283 | 561 rescued-occurrence sites (278 remain, all in `MANIFEST.json`) |
| docs annotated | 17 | 72 |
| `EVIDENCE LOST` markers | 28 | 123 lost-path occurrences in docs (the rest are in verbatim data artifacts) |
| distinct dead paths annotated | 43 | 43 (39 exact + 4 sweep-truncated brace/glob forms) |
| dead paths left in verbatim artifacts | 39 distinct | 43 |
| T420 delta | 14 new `/tmp` citations in 4 files | 0 expected (D063) |
| C10 counter | 1059 (212 /tmp · 3 /private/tmp · 24 absolute · 820 untracked/) | measured at close on the working tree (incl. this row's own doc + Fable's in-flight untracked audit) |
| pre-existing claimlint counters | byte-identical (C7 `files scanned` 293→294 = this row's own findings file) | baseline `/tmp/weizigo/T421-baseline-claimlint.txt` |

## 7. What I could not establish

- Whether `/tmp/weizigo/t420/…` files still in `/tmp` today will be swept before the
  Orchestrator reads this — the binary exists *now* (`ls /tmp/weizigo/t420/t381-evse`),
  which is precisely the "exists today, gone tomorrow" state C10 exists to flag.
- Whether the Orchestrator wants the T420 residual rescued (extending the rescue dir) or
  accepted as a documented residual. This row does not extend the rescue of record.
- The `untracked/` census (813) includes C2c-handled evidence-column citations; the
  overlap is reported, not reconciled.
