# Muhtasib audit — Chunk 4: dirty-tree commit-hazard inspection

**Auditor:** Kimi-k2.7 Auditor (Muhtasib role).  
**Date:** 2026-07-28  
**Scope:** inspect the uncommitted working tree for claims, stale state, artifact hazards, and concurrent-author conflicts before anything is committed.

## Method

- `git status` + `git diff --stat` to map the dirty tree.
- `git diff` on the highest-claim files: `docs/status/CURRENT.md`, `src/qa023_brute_2x2.zig`, `docs/infra/dispatch/EXP-2.md`.
- Source- and claim-register checks to see whether items listed in `docs/research/corrections-2026-07-27.md` have actually been corrected in their owning files.
- Verify no `data/` or `artifacts/` files are modified.
- Check `.gitignore` coverage for any untracked build artifacts created during the audit.

## Dirty-tree inventory

```
On branch main
Your branch is ahead of 'origin/main' by 15 commits.

Changes not staged for commit:
  AGENTS.md
  docs/AGENTS.md
  docs/README.md
  docs/about-this-document.md
  docs/infra/agents/boss-role.md
  docs/infra/agents/worker-role.md
  docs/infra/agents/workflow.md
  docs/infra/delegation.md
  docs/infra/dispatch/EXP-2.md
  docs/infra/dispatch/EXP-3.md
  docs/infra/dispatch/EXP-4.md
  docs/infra/dispatch/EXP-5.md
  docs/infra/dispatch/EXP-6.md
  docs/infra/dispatch/EXP-7.md
  docs/infra/dispatch/EXP-8.md
  docs/infra/dispatch/EXP-9.md
  docs/infra/dispatch/EXP-10.md
  docs/infra/managent/spec.md
  docs/infra/model-perf.md
  docs/infra/sprint.md
  docs/infra/subagent.md
  docs/status/CURRENT.md
  src/qa023_brute_2x2.zig

Untracked files:
  docs/INTENT.md
  docs/evidence/GLOBAL.H1-CENSUS/reconciliation/
  docs/infra/delegation/
  docs/infra/dispatch/EXP-2B.md
  docs/infra/dispatch/QA-018-RULING.md
  docs/infra/roles/
  src/qa023_smoke_2x2.zig
  weizigo-exp3-minimax
```

### Safe-to-ignore items

- No engine file (`src/retro.zig`, `oracle.zig`, `rules.zig`, `solve.zig`) is modified.
- No `data/` or `artifacts/` file is modified or untracked (verified with `git status --short data/ artifacts/`).
- The bulk of the diff is an infrastructure retirement/reorganization (`boss-role.md`, `worker-role.md`, `workflow.md`, `delegation.md`, `sprint.md`, `subagent.md`) moving content to `docs/infra/delegation/` and `docs/infra/roles/`. These are administrative, not epistemic claims.

## Findings

### 1. `docs/status/CURRENT.md` contains two stale subsections that contradict its own updated entries

**Status: NEEDS REPAIR.**

The file was refreshed 2026-07-28 and correctly records:
- EXP-2A as **DONE**.
- EXP-3 as **DONE 2026-07-28** with headline numbers and committed deliverables.

But the lower sections are stale relative to those entries:

- **"Where the project stands right now (2026-07-27)"** says: *"Nothing asserts simple ko will work: its state-space census has not been run"*. This is false after the EXP-3 entry above it; the census was committed in `286d679` and reproduced independently in Chunk 3.
- **"Uncommitted / unverified right now"** lists as uncommitted:
  - `src/chainability.zig`, `build.zig`
  - `docs/research/ko-sensitive-chainability.md`
  - `docs/research/corrections-2026-07-27.md`
  - `docs/research/open-hypotheses-2026-07-27.md`
  - `docs/epistemic/GLOSSARY.md`
  - `docs/epistemic/boards/4x4/EPISTEMIC.md`
  - `docs/epistemic/PROGRESS.md`
  - `docs/epistemic/boards/4x3/`
  - `regressions/README.md`

  All of these are already committed (`git ls-files` confirms each). The table is therefore misleading and should be pruned or retitled.

**Why it matters:** a fresh session reading `CURRENT.md` after a context clear is explicitly the project's recovery mechanism. If the file tells that reader that the census has not run and the chainability work is uncommitted, the reader will duplicate work or make wrong dispatch decisions.

**Repair:** delete or update the two stale subsections to reflect the current committed state. The EXP-2A/EXP-3 entries already carry the needed status.

### 2. `docs/decisions/0013-sound-finisher-and-dependency-guarded-memo.md` still carries the false GTP-player claim

**Status: NEEDS REPAIR (carried from Chunk 2).**

Lines 129–130 of ADR-0013 state:

> "The history-perfect genmove (GTP player) shares this machinery; it inherits the fix automatically once the finisher config is corrected."

This is false. Source inspection (`src/gtp.zig:90-93`, `154-196`) shows the player performs table lookups only; it has no finisher search machinery and no bracket columns to read. The correction is recorded in `docs/research/corrections-2026-07-27.md` §B-1 and in `docs/research/ko-sensitive-chainability.md` §"What a fix costs".

ADR-0015 (`docs/decisions/0015-bracket-cut-soundness-search-vs-real-history.md`) supersedes the **Consequences** section of ADR-0010, but it does **not** supersede ADR-0013. Therefore the false sentence remains in a committed ADR with no superseding ADR.

**Repair:** add a superseding ADR or an explicit correction note appended to ADR-0013's Consequences. Until then, the ADR should not be cited without the corrections file.

### 3. `regressions/README.md` and `src/gtp.zig` corrections appear folded

**Status: VERIFIED.**

- `regressions/README.md` no longer blames the blunder on "the game's PSK history" or calls it "the C2 falsification in action" or "fresh-start perfect". The corrected version now says the cause is unchainability in the ko-sensitive region and explicitly invokes C4, not C2.
- `src/gtp.zig` no longer contains the phrase "fresh-start perfect" or "history perfect" in its header comment (verified with `git grep`).

The corrections file has been folded into these two files.

### 4. `src/qa023_brute_2x2.zig` diff is harmless type widening

**Status: VERIFIED safe.**

The diff changes `u32` indexes and counters to `u64` to avoid overflow at larger state spaces. No semantic change, no claim change.

### 5. `src/qa023_smoke_2x2.zig` is a new smoke-test file with no engine imports

**Status: VERIFIED safe.**

It imports only `std` and `qa023_brute_2x2.zig`. It does not touch engine files. It makes no epistemic claims.

### 6. `docs/infra/dispatch/EXP-2.md` correction is sound

**Status: VERIFIED.**

The diff replaces the instruction "brute-force the same game by explicit game-tree evaluation carrying full history and compare every state" with a history-sensitivity probe modeled on T13. The old instruction was intractable and had already burned a console. The new instruction is methodologically correct and explicitly names the non-zero cycle-census acceptance criterion.

### 7. `weizigo-exp3-minimax` binary is untracked and NOT in `.gitignore`

**Status: COMMIT HAZARD.**

`.gitignore` lists `/retro-e*`, `/gtp`, `/weizigo`, `/weizigo-arena`, `/weizigo-oracle`, `/weizigo-engine-vs-engine`, `/managent`, but not `/weizigo-exp3-minimax`. A careless `git add -A` would commit a 100+ KB binary.

**Repair:** delete the binary or add it to `.gitignore` (e.g. `/weizigo-exp3-minimax` and any future `/weizigo-exp*`).

### 8. Concurrent-author / file-ownership hazards

**Status: NO ENGINE-FILE CONFLICT; one soft conflict noted.**

- No engine file is modified in the dirty tree.
- `src/qa023_brute_2x2.zig` is modified; `src/qa023_smoke_2x2.zig` is new. Both are QA-023/EXP-2 tooling. `docs/infra/dispatch/EXP-2B.md` assigns `src/qa023_probe.zig` (not yet present) to Minimax for Part B. There is no overlap between the modified `brute_2x2` and the assigned `probe.zig`.
- `AGENTS.md` is being heavily rewritten. Because it is a read-first doc, concurrent edits are undesirable, but there is no evidence of two authors editing it in this tree.

### 9. `AGENTS.md` reorganization does not weaken foreclosures

**Status: VERIFIED.**

The new `AGENTS.md` keeps all non-negotiable foreclosures (PSK not generation target, kill-X% dead, score-on-cycle hardness, ko-sensitive values untrusted, C2/C3 falsified, Black-positive scores, "colex index" not "rank", one writer per engine file, no silent artifact writes). It also corrects the stale reference to `data/oracle-4x4.wzo` (not on disk) to `data/oracle-4x4.checkpoint.wzo`.

## Verdict summary

| item | status | note |
|---|---|---|
| No `data/` or `artifacts/` overwrites | VERIFIED | nothing modified in those dirs |
| No engine-file edits | VERIFIED | dirty tree is docs + one QA-023 tool |
| `CURRENT.md` EXP-2A/EXP-3 status honest | VERIFIED | still labels QA-023 as CLAIMED, EXP-3 as DONE |
| `CURRENT.md` stale lower sections | **NEEDS REPAIR** | contradict committed state |
| ADR-0013 GTP-player false claim | **NEEDS REPAIR** | no superseding ADR yet |
| `regressions/README.md` / `src/gtp.zig` corrections | VERIFIED | folded |
| `src/qa023_brute_2x2.zig` diff | VERIFIED safe | type widening only |
| `src/qa023_smoke_2x2.zig` | VERIFIED safe | smoke test, no engine imports |
| `EXP-2.md` probe correction | VERIFIED | methodologically sound |
| `weizigo-exp3-minimax` untracked binary | **COMMIT HAZARD** | not in `.gitignore` |
| `AGENTS.md` foreclosure preservation | VERIFIED | all foreclosures retained |

## Recommended actions before commit

1. **Prune `docs/status/CURRENT.md`** — update or delete the 2026-07-27 "Where the project stands" and "Uncommitted / unverified" sections so they do not contradict the EXP-3/EXP-2A entries above them.
2. **Clean up the untracked binary** — `rm weizigo-exp3-minimax` and add `/weizigo-exp*` to `.gitignore` if such probes will be rebuilt.
3. **ADR-0013 supersession** — file an ADR-0017 or append a correction note to ADR-0013's Consequences; do not leave the false GTP-player sentence unaccompanied.
4. **Stage carefully** — the dirty tree has four or five conceptual topics (infra retirement, CURRENT.md refresh, QA-023 type widening, new delegation files). Commit by topic, never `git add -A`, until the binary hazard is gone.
