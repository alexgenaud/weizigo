# CURRENT — in-flight task status (ephemeral; updated often)

**Purpose:** the single file a fresh session reads to resume *without loss*
after a context clear / compact / handover. Not durable — milestones live in git +
`../epistemic/PROGRESS.md` + `decisions/` + `research/`. If this file is stale, read
`../epistemic/PROGRESS.md` → `leak-crisis.md` and rebuild it.

---

## B44 cleanup DONE (2026-07-27, Pi)

**B44 DONE:** Piper removed tracked temp-comm (`docs/status/ADVISOR.md` git-rm'd), promoted model-perf ledger to `docs/infra/model-perf.md`, and deleted 57 stale untracked scratch files. 20 files remain in `untracked/` (protected + in-flight + living). See `untracked/B44-cleanup.md` for the full classification table.

**Out of scope noted:** tracked stray binaries at repo root (`weizigo-arena`, `weizigo-oracle`) left for future gitignore-hygiene task.

## Last update: 2026-07-27 (Pi, B43 arena UNDEF guard — DONE)

**B43 DONE:** Pi finished `src/arena.zig` UNDEF guard. Clean leak rate
on the 4×4 parallel artifact dropped from 45.3% / 144-pt (B39, mostly
a measurement artifact) to 3.4% / 32-pt (within T06 band). 32.5% of
games touch a UNDEF slot; only 1 of 1170 tainted games leaked (3 pts).
E1/C2 falsification unchanged. Details in `untracked/B43-arena-undef.md`
+ appended section in `untracked/B39-arena4x4.md`. Releasing the hold
on `src/arena.zig`.

## Last update: 2026-07-27 (Pi, B43 arena UNDEF guard — starting)

**B43 starting:** Pi (the one in the harness) beginning S1 on
`src/arena.zig` (UNDEF guard for move-enumeration, promise tracking, and
divergence tally). B40 already exposed `gtp.UNDEF`. Per B43, hold on
`src/arena.zig` only; safe to run in parallel with B42 (which is already
DONE per the last update). Details in `untracked/B43-arena-undef.md`.

**Hold declared:** Pi editing `src/arena.zig` for B43, ~10 min.

---

## Last update: 2026-07-27 (Kimi, B42 score report — DONE)

**B42 DONE:** Kimi finished `src/score.zig` + `src/gtp.zig` scoring surface.
Tests pass; both GTP smokes pass; ADR-0014 written. Releasing the holds on
`src/score.zig` and `src/gtp.zig`. Details in `untracked/B42-score-report.md`.

**Sprint B15-B39 complete (50 done, 1 dispatchable).** Multi-model evaluation
complete (GLM recommended as next Boss). 4×4 parallel artifact produced:
99.8% complete, 83K unfilled (2-ko+). Board epistemic trees created for
2×2/3×2/3×3. Innovations catalog (I1-I15). Terminology sweeps complete.

**Next Boss (GLM recommended):** read HANDOVER.md for tactical state.

**B23 DONE:** Ko census on 3x3 and 4x4. Tool: `src/ko_census.zig`.
2-ko+ is ~2.0% of ko-sensitive positions on 4x4 — above irrelevance,
below priority threshold. Results: `untracked/B23-kocensus.md`.

**B15 DONE:** Track A regen of 2×2/3×2 with writes-off finisher. Byte-identical
match with committed baselines. #2 auditor PASS, bracket containment recorded.
Results: `untracked/B15-regen.md`.

**B09, B12, B13, B14 completed.** B09 auditor sensitivity test: 3 synthetic
bugs injected, 2 caught, 1 blind spot identified (L/H construction bugs).
See `untracked/B09-kimi.md`. B12 cleanup. B13 terminology sweep. B14
experiment design.

**CRITICAL: T13 falsified C2 at 3×2.** Docs reframe applied. **Per-board
epistemic independence is now explicit:** knowledge at 2×2/3×2/3×3 is not
evidence for any other size. See `../epistemic/boards/CONCEPTS.md` §"Each board size
is its own epistemic universe."

**User-decision flags pending:** UD-1, UD-2, UD-3. B05 recommends YES to all.

**Concise registry:** `untracked/SUBAGENTS.md`.

### Current state

- **B02 — GLM-5.2** (`untracked/B02-glm.md`): **In progress.** T14.3 auditor +
  C2-lattice-scope.
- **B04 — Minimax-m3** (`untracked/B04-minimax.md`): **In progress.** Scratch-
  file triage.

### Completed this session (since last update)

- **B23 — Boss** (`untracked/B23-kocensus.md`): DONE. Ko census on 3x3, 4x4.
  2-ko+ is ~2.0% of ko-sensitive on 4x4. Tool: `src/ko_census.zig`.
- **B05 — GLM-5.2** (`untracked/B05-glm.md`): DONE. Reframe plan; 8-edit plan
  applied by Boss.
- **B06 — Kimi-k2.7** (`untracked/B06-kimi.md`): DONE. E2 re-run: C3 supported
  on explored 2×2/3×2 samples (0 leaks), **falsified at 3×3** (50/8000 leaks,
  max 12 pts). General C3 claim false-as-scoped.
- **B08 — GLM-5.2** (`untracked/B08-glm.md`): DONE. Onboarding test
  **PARTIAL PASS**. Found `CURRENT.md` internal inconsistency on B06/B07 status
  (now fixed in this update) and other minor friction.
- **B11 — Boss** (`untracked/B11-boss-apply.md`): DONE. Applied B05 doc edits.

### Dispatchable now

**Set A — independent read-only / standalone:**
```text
B07: follow untracked/B07-minimax.md
B10: follow untracked/B10-minimax.md
```

**Set C — sole `src/retro.zig` owner (do not run with B07 or any engine editor):**
```text
B09: follow untracked/B09-kimi.md
```

**Set B — onboarding (re-run only if needed):**
```text
B08: follow untracked/B08-glm.md
```

### Remaining work

1. B02 reports (T14.3 + C2-lattice-scope).
2. B04 reports (scratch-file triage).
3. B07 confirms fresh-start engine sanity.
4. B09 tests auditor sensitivity (after B07, or instead of B07).
5. B10 reports 3×2 divergence statistics.
6. User signs off on UD-1/UD-2/UD-3.
7. Write ADR on C2 falsification / reframe.
8. Optionally run Track A 2×2/3×2 regen if UD-1 is YES.

### Doc edits applied this session

See `untracked/SUBAGENTS.md` §"Completed" and `untracked/B11-boss-apply.md`.
Key: AGENTS.md foreclosures; leak-crisis.md claim table + honest deliverable;
PROGRESS.md central partition + reframe; EPISTEMIC.md deliverable decision;
CONCEPTS.md C2 bullets + dependency structure + per-board independence;
names.md canonical names; GLOSSARY.md certified core / bracket / ko-sensitive
region + fresh-start score entry.

### B13 terminology sweep applied (DeepSeek-Pro, 2026-07-26)

Option A applied to 5 files:
- `docs/research/fresh-start-vs-real-game.md` — 5 corrections (duplicate
  section removed, C3 hedging fixed, generation rule clarified, per-board
  independence added, honest deliverable framing added)
- `docs/research/methods-and-findings.md` — "certified core" → "fresh-start
  single-score region" (4×), epistemic update note appended
- `docs/research/ruleset-options.md` — "certified core" → "fresh-start
  single-score region" (8×), RETRO_BRACKET section reframed, epistemic
  caveat added
- `docs/research/c2-falsification-3x2.md` — 1 replacement
- `docs/research/arena-audit.md` — 2 replacements
- `../epistemic/boards/CONCEPTS.md` — diagram label updated

### B14 engine-vs-engine + KataGo design (DeepSeek-Pro, 2026-07-26)

Three experiments scoped, prioritized, with implementation plans:
1. Fresh-start vs history-aware exact on 2×2/3×2 (~2h implementation)
2. Arena with copycat persona across all sizes (~30min code + runtime)
3. weizigo vs KataGo GTP match (~1h setup + runtime)
Full design: `untracked/B14-deepseek.md`. All deferred until UD-1/2/3 sign-off.

### Per-board epistemic independence (added this session)

Each board size has its own independent epistemic status. A falsification at
3×2 does not prove anything about 3×3 or 4×4; a pass at 2×2 does not prove
anything about 3×2. The project documents each size separately:
- `../epistemic/boards/CONCEPTS.md` — cross-size definitions and independence rule.
- `../epistemic/boards/4x4/EPISTEMIC.md` — 4×4 tree.
- Smaller boards are covered in `leak-crisis.md` and the task
  outputs (`untracked/T12-minimax.md`, `untracked/T13-minimax.md`,
  `untracked/B06-kimi.md`).

### Backlog / deferred / moot

- T14.2, T15-impl, T17-impl: deferred until user decisions.
- T16-content-review: on hold in B01.
- Cleanup: deferred until B04 and reframe settle.

### Engine edits in progress / recent

- B06 added `RETRO_E2_SEEDS` env-var knob to `src/retro.zig` (no core logic
  change).
- T14.1 `bracket_only` param still in `src/retro.zig`.
- No writes to `data/oracle-*.wzo` or `artifacts/*.wzo`.

## B07-NOTE (2026-07-26, Minimax-m3)

Conventions drift: corrected the B<NN>-<slug>.md convention (user 2026-07-26).
Recorded in `../infra/agents/boss-role.md` "Bundle filename convention" section. Existing
B01..B11 filenames NOT renamed (per migration policy: history). Going forward
all new task/bundle files use `ID-slug.md` where slug is a task hint, not a
model name. The current B07 work (B07-minimax.md) is the last file with a
model-name slug; future B-bundles and T-tasks adopt the corrected convention.

## B07-S1 complete (2026-07-26, Minimax-m3)

`#2` auditor results recorded in `untracked/B07-minimax.md`:
- 2x2: ALL three variants PASS (82 chk, 0 viol).
- 3x2: writes-on BUGGY (45 viol), soundish PASS, deps PASS.
- 3x3 (sample=400): ALL three variants PASS.

B07-S2 (bracket containment on T14.1 artifact) and B07-S3 (fresh-start
repro) still open.

B07 Minimax-m3 editing src/retro.zig to add RETRO_SAVE_2X2_OUT/3X2_OUT/3X3_OUT/4X3_OUT env knobs. No core logic change. ~3 min.

## B07-S2 complete (2026-07-26, Minimax-m3)

Bracket containment on `untracked/oracle-4x4-writesoff-bracket.wzo` (T14.1
output) — **PASS**: 0 containment failures, 0 flag mismatches, 0 illegal
fills, 5,183,961 ko-sensitive UNDEF per side (expected for a bracket-only
artifact). Certified core exact (19,134,204 B + 19,134,204 W = 38,268,408,
78.68%).

## B07-S3 complete (2026-07-26, Minimax-m3)

Per-slot comparison of `untracked/oracle-{2x2,3x2}-repro.wzo` (current
writes-off regen) against `artifacts/oracle-{2x2,3x2}.wzo` (committed
baselines) — **MATCH (byte-identical)** on both boards. SHA256 hashes
match `artifacts/SHA256SUMS`. Engine is deterministic and stable.

**Engine edit for S3** (additive, src/retro.zig only): 4 env-var knobs
`RETRO_SAVE_{2X2,3X2,3X3,4X3}_OUT` to redirect `RETRO_SAVE` away from
`artifacts/oracle-*.wzo` so repros can land in `untracked/` without
clobbering. Default paths unchanged.

## B07 STATUS — DONE (2026-07-26, Minimax-m3)

All three subtasks complete. **Releasing the `src/retro.zig` write lock.**
B09 may now begin.

## B09 — Kimi COMPLETE: synthetic-bug injection / auditor-sensitivity test (2026-07-26)

All three bugs injected, tested, reverted. `src/retro.zig` write lock released.
Results in `untracked/B09-kimi.md`.


## Conceptual clarifications added (2026-07-26)

User asked about terminology and real-game play. Boss wrote
`docs/research/fresh-start-vs-real-game.md` summarizing:
- The table holds fresh-start scores, not real-game scores.
- Even L==H positions can be history-dependent under PSK; "ko-sensitive" in
  the project sense means L < H.
- The engine is exact only for fresh-start (no history) under basic ko.
- There is one table per board size, not multiple ruleset tables.
- Fresh-start scores are still useful for opening/analysis/teaching.
- Real-game optimal play would need history-aware tables, goal-bounded forward
  search, or CGT/local decomposition.

Pending bundles for these topics: B13 (terminology sweep + real-game-play
scope), B14 (engine-vs-engine + KataGo design). Both are optional and await
human approval.
