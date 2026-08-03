# Fleet hardening sprint — 2026-08-04

Sprint console: **deepseek-v4-pro/T336** · Date: 2026-08-03

## Rows delivered

### T317 — managent attribution + store safety + model validation + amend (pass)

Six scope items, all delivered:

1. **`managent add --model <name>`** — parsed, canonicalized, validated, stored. Both `--auto` and non-auto branches.
2. **Canonical model label validation** — `canonical_models[]` single source of truth in `src/managent/main.zig` (9 models). Rejected at `agent`, `claim`, `done`. Ollama `:cloud` and `-code` variants canonicalized before validation. `bin/ollama-subagent` maps raw tags to canonical labels. `DELEGATEE.md` updated with full canonical table.
3. **`tools/regression-subagent-prompt.sh` wired into `zig build test`** — closes T315's wiring debt.
4. **Store write lost-update safety** — `writeState` → `writeStateLocked` refactor. Five commands use full lock→re-read→modify→writeLocked→unlock: `add`, `claim`, `agent`, `dispatch`, `amend`. Seven remaining commands use `writeState` wrapper (locks internally). Tool identified but not fully hardened.
5. **`bin/ollama-subagent` deliverables fix** — parses `deliverables=` from bundle header; closing prompt names declared paths, not filename-derived path.
6. **`managent amend`** — append-only correction record on done/failed tasks. Original verdict preserved in `amendments[]` array. Wired into dispatch, help text, spec.

**Controls:** Non-canonical label rejected (exit 1, prints canonical set). Raw tag canonicalized (`kimi-k2.7-code:cloud` → `kimi-k2.7`). Amend preserves original verdict. All seeded controls shown red-then-green.

**Evidence:** `zig build test` exit 0 (41s), smoke PASS, claimlint at floor (C1a=10 C1b=0 C2=14 C6=0 C9=0).

---

### T319 — kanban archive (pass)

`managent archive` command with `--dry-run`. Moves done/failed rows to `docs/infra/managent/archive.json`. Eligibility: done/failed, no live dependents, holds committed, C7 absorption clean. `cmdWhy` searches both live and archive stores (archived rows marked `(archived)`). Idempotent.

**Result:** 96 rows archived, 10 live remaining. Needs edges cleaned (T317's `needs T315` cleaned). Both stores committed atomically.

**Evidence:** `zig build test` exit 0, dry-run showed 96 archivable, real run archived 96, second run idempotent (0 archivable).

---

### T325 — flaky-suite diagnosis (pass)

10 consecutive `zig build test` runs: **all passed** (exit 0), mean wall time 39.9s (range 39.6–40.3s). Zero build-step failures, zero test failures. Serial run (`-j1`) also clean (45.1s).

The previously observed flakiness (T314: 390/393 → 393/393 at `b3d0209`) did not reproduce. Likely resolved: dirty-tree binary and `.zig-cache` contention from concurrent builds no longer present at HEAD.

Proposed fix if it recurs: serialize regression scripts that share `/tmp` fixtures.

**Evidence:** 10 log files at `/tmp/weizigo/t325-run-*.log`. Analysis only — no source changes.

---

### T322 — wire orphaned regression controls (pass-with-findings)

**Wired 2** of 7 orphaned scripts into `zig build test`:
- `regression-managent-done-git.sh` — git deliverable guard controls
- `regression-managent-memory-safety.sh` — T122 stdout/stderr splitting

Both pass, use temp stores, add <1s to suite wall time (41.0s total).

**5 deferred** with stated reasons in `findings/T323-orphaned-controls.json`:

| script | issue |
|---|---|
| `depth-enforcement` | FAILURES on ruling text match |
| `git-commit-mine` | writes live `docs/infra/managent/tasks.json` (hygiene violation, line 190) |
| `git-commit-mine-hook` | FAILURES on pre-commit regression |
| `managent-integrity` | checks deployed `bin/` vs `zig-out/` staleness — pre-condition `zig build test` does not satisfy (16 checks, the costliest gap) |
| `T227` | TIMEOUT >120s |

---

## Remaining sprint rows (not yet executed)

| row | status | files | notes |
|---|---|---|---|
| **T326** GTP handicap | dispatchable (unblocked by T322) | `src/gtp.zig` | `set_free_handicap`, `place_free_handicap`, `fixed_handicap`, regression test, Sabaki verification |
| **T327** score-annotated board | blocked (needs T326) | `src/gtp.zig` | `weizigo_showscores` command, two-digit ASCII cells, L<H compact format |
| **T328** model bake-off harness | dispatchable (set A, human-ruled after T317) | `tools/bakeoff.sh`, `docs/infra/bakeoff.md` | headless Claude + Ollama dispatch, answer-key-first protocol |
| **T330** retirement edge re-points | dispatchable (set B, holds `CLAIMS.md`) | `docs/epistemic/CLAIMS.md` | nine `e:`/`d:` edges, deferred-8 completion, claimlint verify |

T326 is now unblocked (T322 done). T327 follows T326. T328 and T330 can run in parallel with the S2-store chain.

---

## Gaps and debt

1. **Five regression scripts still orphaned** — each needs a fix row (or one combined fix-them-all row). The `managent-integrity` staleness check is the highest-value gap (16 checks), followed by `depth-enforcement` (7 depth-cap controls).

2. **Lost-update hardening incomplete** — 7 of 12 mutating commands still use `writeState` (internal lock) rather than lock→re-read→writeLocked pattern. The five most raced commands are hardened.

3. **`cmdShow` does not display amendments** — amendment records are in JSON but not surfaced in `show` output.

4. **`ollama-subagent` tag mapping** — `OLLAMA_TAG_TO_CANONICAL` dict must stay in sync with `canonical_models[]` in `main.zig`. No mechanized cross-check.

5. **C7 unabsorbed findings at 9** (up from 5) — T317, T319, T325, T322 findings files unabsorbed. The absorber (T294/STANDING-ABSORB) should run next.

---

## What to check next

1. Dispatch T326 → T327 (GTP handicap + score-annotated board) — S2-store chain, now unblocked
2. Dispatch T330 (retirement edges) — holds `CLAIMS.md`, single-owner
3. Dispatch T328 (bake-off) — human-ruled after T317, ready
4. Run `managent standing` — C7 at 9 should fire STANDING-ABSORB
5. Fix the `git-commit-mine.sh` live-store write (line 190) before wiring — it would corrupt the kanban silently
6. Deploy and verify smoke after each commit (standing rule, enforced for T317/T319/T322)

---

## Build evidence

All rows deployed with `zig build deploy` + `sh tools/smoke.sh` PASS, zero STALE lines. Claimlint at floor throughout: C1a=10, C1b=0, C2=14, C6=0, C9=0, calibration=PASS.
