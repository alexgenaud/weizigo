# CURRENT — in-flight task status (ephemeral; updated often)

**Purpose:** the single file a fresh session reads to resume *without loss*
after a context clear / compact / handover. Always reflects what is happening
right now and the next concrete step. Not durable — milestones live in git +
`PROGRESS.md` + `decisions/` + `research/`. If this file is stale, read
`PROGRESS.md` → `status/leak-crisis.md` and rebuild it.

Read order on resume: `PROGRESS.md` → `status/leak-crisis.md` → this file →
`docs/agent-workflow.md`.

---

## Last update: 2026-07-25 (GLM-Boss review)

## Active thread: the leak crisis (E-series)

The project's focus is the **leak crisis** (`status/leak-crisis.md`). Status of
the experiments:

- **E1 (diagnostic, DONE):** region-tagged arena diverged events. 2×2:
  single-score diverged=0; 3×2/3×3: non-zero minority. Diagnostic only — does
  NOT prove C2 (arena `best` is the fresh-start player's belief, not the true
  value). Code: `src/arena.zig` E1 counters; rebuild/run command in the doc.
- **E2 (range-aware self-play, DONE + sanity-checked):**
  - `RETRO_E2=1 ./retro-e2`: 2×2/3×2 zero leaks; **3×3 25 leaks** (promise 3 →
    final −9). Code: `src/retro.zig` `e2Board`/`runE2` (Black uses `lo`, White
    uses `hi` — a sign bug was fixed during the run).
  - `RETRO_E2SANITY=1 ./retro-e2`: trivially-valid bounds (`lo=−N`/`hi=+N`) →
    zero leaks on all boards. **Ruled out an E2 policy/wiring bug.** (Caveat:
    trivial bounds cannot detect a PSK/mechanics bug — that needed E3.)
- **E3 (exact-solver cross-check + PSK-legality, DONE — INCONCLUSIVE direct,
  narrowing):**
  - PROVEN: the leaking 3×3 game is a **VALID PSK game** (0 illegal moves) →
    ruled out the self-play/PSK mechanics bug.
  - PROVEN (structure): a valid PSK line from empty 3×3 reaches −9 while the
    table root `lo=2` (bracket [2,9]); `lo` collapses 3→−9 along the line.
  - INCONCLUSIVE: direct `true < lo` at the critical plies — **intractable**
    (the 3×3-exact wall; 2M-node budget exceeded at every early ply). Catch-22:
    leaks happen on 3×3 (intractable); the tractable boards (2×2/3×2) don't
    leak.
  - SURVIVING AMBIGUITY: **(a) C3 genuinely false** (the least-fixpoint `lo`
    does not bound real PSK values — predicted by the cycle-pessimism-vs-PSK-
    move-removal gap) vs **(b) a `lo`-converge bug**. (a) favored: `lo=2` is a
    genuine least fixpoint; the semantics gap predicts it; 2×2/3×2 don't leak.
  - NOT PROVEN: no direct `true < lo` at any position.

## State (2026-07-25, GLM-Boss review)

Minimax marching orders: `untracked/task-minimax.md` (E3-1 reverted; re-spec B1
before re-implementing; idle tasks available). Concurrency protocol adopted in
`AGENTS.md`.

- **Minimax's E3-1 probe was REVERTED** from `src/retro.zig` (it was
  uncommitted, env-gated, and self-flagged-ambiguous — Minimax didn't verify
  the V1 fixpoint equation or confirm re-converge reached zero-change). The
  process slip (implementing before spec'ing) is what `agent-workflow.md`
  warns against. `src/retro.zig` is now GLM's clean E2/E3 only.
- **Clean baseline verified:** `zig build-exe` clean; `zig test` **59/59**.
- Binaries (`retro-e2`/`retro-e3`) and stray empty `HUMAN.md` removed;
  `/retro-e*` gitignored.
- GLM's diff committed on a local branch (no push); main untouched.

## Next concrete steps (pick up here)

- [ ] **`TODO` B1 (re-spec E3-1):** before re-implementing, *specify* the
      least-fixpoint check (which Bellman equations — V0 AND V1; confirm
      re-converge hits zero-change; falsifiable acceptance test) and agree it
      with Boss. Then Minimax may implement. (Don't repeat implement-first.)
- [ ] **`TODO` B2 (E3-2):** find a leaking 3×3 game whose critical ply is
      exactly solvable (the `−2` leaks may transition deeper/tractable) for a
      direct `true < lo`.
- [ ] If C3 false: re-frame the deliverable (core-only artifact + range-aware
      player; bracket unsound as a real-game bound).

## State on disk

- `src/arena.zig` — E1 counters (uncommitted).
- `src/retro.zig` — `e2Board` / `runE2` / `runE2sanity` / `e3Analyze` +
  `RETRO_E2` / `RETRO_E2SANITY` env probes (uncommitted). Rebuild:
  `ZIG_GLOBAL_CACHE_DIR=/tmp/weizigo-zigcache ZIG_LOCAL_CACHE_DIR=/tmp/weizigo-zigcache zig build-exe -O ReleaseFast src/retro.zig -femit-bin=retro-e2`
  (the binary is removed each session to keep the tree clean; rebuild command
  above).
- Docs: `status/leak-crisis.md` (full E1/E2/E3 record), `names.md`,
  `PROGRESS.md`, `about-this-document.md`, `agent-workflow.md` (new),
  `AGENTS.md`, `GLOSSARY.md` updated. All uncommitted.
- Nothing pushed to git; user handles commits.

## Not in flight / parked

- Track A (regenerate 2×2..4×4 with `memo_writes=false` + #2 auditor) — paused
  until the crisis resolves; the crisis calls the whole bracket into question
  first.
- 5×5 build — explicitly on hold (don't build on an unverified bracket).
- Canonical-name propagation (`names.md` checklist) — pending the
  single-value rename to "proven" if E3 confirms C2 holds there.

## Gotchas

- Zig builds need `ZIG_GLOBAL_CACHE_DIR`/`ZIG_LOCAL_CACHE_DIR` set to a
  writable dir (sandbox blocks the default global cache). Use `/tmp/weizigo-
  zigcache`.
- `sed` in-place on macOS: `&` in the replacement means "the whole match" —
  use Python for edits containing `&`. (This corrupted an E3 line once.)
- E2/E3 probes are env-gated (`RETRO_E2` / `RETRO_E2SANITY`); the default
  `zig run retro.zig` runs the full battery (slow) — always set the env.

## 2026-07-25 (Minimax, start) — B1 least-fixpoint spec

Picking the B1 spec task from `untracked/task-minimax.md`. Writing to
`untracked/b1-spec.md`. No engine edits. Concurrency: posting here.

## 2026-07-25 (Minimax, B1 spec written)

- **Task:** B1 least-fixpoint spec (per `untracked/task-minimax.md`).
- **Output:** `untracked/b1-spec.md` (270 lines). Two Bellman equations
  (V0 + V1) for the L map, three checks (fixpoint-equation,
  re-converge-from-lower, re-converge-from-upper) with the zero-change
  precondition. Falsifiable acceptance: zero violations on 2×2/3×2/3×3
  → (b) converge-bug ruled out. 5 open questions for Boss in §7.
- **Engine edits:** none. Awaiting Boss sign-off.
- **Concurrency:** holding all engine files.

## 2026-07-25 (Minimax, T02.2 starting)

- **Task:** T02.2 — implement `RETRO_B1_LOFIX` per `untracked/T02-minimax.md`
  (Boss-approved; spec at `untracked/b1-spec.md`, V1-equation correction
  applied in T02.1).
- **Editing:** `src/retro.zig` only. Adding `e3LofixCheck` + `runE3B1`
  + `RETRO_B1_LOFIX` env gate (~180–220 lines, est. 15 min wall).
- **Not touching:** docs/, AGENTS.md, other engine files, branches,
  git refs. Branch: `glm-boss/e2-e3-docs-baseline`. Uncommitted.
- **Concurrency:** holding `src/retro.zig` exclusively.

## 2026-07-25 (Minimax, B1 done) — verdict INCONCLUSIVE on (b)

- **T02 done.** Results in `untracked/T02-minimax.md`.
- **Surprise:** the L map has **multiple fixpoints** on 2×2/3×2/3×3
  (re-converge from `-N+1` and `+N` lands at different fixpoints,
  all satisfying V0/V1 Bellman equations). The canonical `converge`
  IS a real fixpoint of the L map, but the L map is not the standard
  monotone-from-above map the spec assumed. **The map's
  `cv = q.w0[ci]` reads the OPPONENT's V0, which is updated in the
  same sweep (Gauss-Seidel); multi-fixpointedness is a real
  possibility, not a bug.**
- **For the leak crisis:** (b) "converge is mis-computed" is
  NOT supported (the canonical IS a fixpoint). (a) "C3 false
  because the bracket doesn't bound real games" is the more
- **2026-07-25 B1+audit RESOLUTION:** (b) converge-bug RULED OUT on
  2×2/3×2/3×3 (canonical `lo` is the true least fixpoint; V0+V1 hold; Knaster-
  Tarski). (a′) unsound, discarded (Kimi audit, untracked/T02-audit-kimi.md).
  → the survivor is **(a): C3 false** — the L fixpoint does NOT bound real
  PSK-game values; the bracket is unsound as a real-game bound. The range-aware
  player is NOT leak-free (E2). The only candidate sound deliverable is the
  certified core (`lo==hi`), **contingent on C2** (single-score history-
  independence, still CLAIMED not proven) — now the load-bearing claim.
- **Next (decide w/ user):** C2-probe (prove the certified core on 2×2/3×2) >
  E3-2 (catch-22'd) > re-frame deliverable (core-only; bracket/residue unsound).
- **Doc-hygiene backlog:** untracked/doc-hygiene.md (AGENTS.md overclaim, broken
  RISKS.md link, README numbering, GLOSSARY typo, stale HANDOVER, code minors).
