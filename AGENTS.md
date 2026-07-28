# AGENTS.md — the router

**Only what EVERY agent needs** — read this, then the one file your role points you at, nothing else. Agents
read only what they need, when they need it. Harness prefers `CLAUDE.md`/`.cursorrules`? Redirect, don't copy.

## What this project is
`weizigo` — a provably-correct solver for small Go boards (Weiqi/Baduk) in Zig 0.16. Goal: a compressed
fresh-start oracle: the exact game-theoretic fresh-start score of every legal (position, side), by
retrograde value iteration with two-sided (L/H) certification. Boards done through 4x4; ruleset in reframe.

## Non-negotiable rules (foreclosures — do NOT relitigate)
Settled — reopening one wastes a session. To overturn one, write an ADR superseding it with evidence; never act against one silently.

- **Positional superko (PSK) is NOT the generation target.** PSK exact-solve is intractable even on the EMPTY
  2x2 (118M ban-set states). See ADR-0013, `research/ruleset-options.md`. Play-time can still enforce PSK for legality.
- **kill-X% is dead as a ko-sensitive-region cure.** It makes the 4x4 ko-sensitive region WORSE (21.32%
  -> 25.01% as the threshold drops). Remains an optional play rule only.
- **score-on-cycle is provably as hard as PSK.** Byte-identical state counts (118,475,182 / 116,114,272).
  No free lunch. See `research/ruleset-options.md`.
- **The committed ko-sensitive values are NOT trustworthy.** `data/oracle-4x4.checkpoint.wzo` (referent
  corrected 2026-07-28: `data/oracle-4x4.wzo` is named in older docs but **does not exist on disk** — two
  instruments confirm, `bin/weizigo-claimlint` and a direct `ls`. The checkpoint is the artifact this
  foreclosure is about: it is the writes-**ON** build, it is the only 4x4 artifact whose root is filled, and
  every headline 4x4 number to date came from it.) and the 2x2/3x2/3x3
  ko-sensitive columns are unverified until Track A regenerates them with `memo_writes=false` and passes
  the #2 auditor. The L==H core is **fresh-start correct (C1)**, NOT real-game correct. C2 (single-score
  history-independence) is **falsified at 3×2** (T13, 2026-07-26; 12 mismatches on 508 non-trivial PSK
  histories). Do NOT quote a ko-sensitive score as truth until then, and do not call the L==H region a
  "proven core" or "certified core" in any real-game sense; it is the *fresh-start single-score region*.
- **Never report any table value as *the* real-game value of the board.** The table holds **fresh-start
  scores only** (C1); C2 (single-score history-independence) is falsified at 3×2 (T13); C3 (bracket bounds
  real-game score) is falsified at 3×3 (E2). The honest deliverable is the fresh-start score table + the
  CLAIMED [L,H] fresh-start bracket, with the explicit non-promise that neither equals nor bounds the
  real-game PSK score.
- **The #2 self-consistency auditor is a mandatory pre-commit gate** for any change to the finisher, memo
  logic, or ko/GHI handling. Zero minimax-identity violations on 3x2 exhaustive + the deepest-N 4x4
  sample. A "sound by construction" claim without an auditor run is INSUFFICIENT — the last bug
  (`ko_ref >= d`, ADR-0013) looked obviously correct and was wrong.
- **The single-score (L==H) region is NOT history-independent.** T13 falsified C2 at 3×2 (2026-07-26). The
  L==H values are fresh-start exact (C1), not real-game exact. Do not relitigate "is the L==H region
  history-independent?" — it is settled false at the smallest testable board. A new ADR with a different
  representation (e.g. bounded-history state) is the route to a real-game claim, not a re-run of the
  C2-probe.
- **Scores are ALWAYS Black-positive.** Side-to-move picks the array (vb/vw), never the sign. Black
  maximizes, White minimizes. Colour inversion: value(-pos,-side) == -value(pos,side); for bound tables
  L(-pos,-side) == -H.
- **Never call the board index a "rank."** In Go, rank = kyu/dan. Use "colex index" or just "index." (User
  decision; you will be corrected.)
- **No sub-board solving.** Restricting moves to a region of the board is unsound (edge stones keep
  phantom liberties). Search is full-board only.
- **Do not remove the eye-prune from the forward search.** Self-eye-fill reopens the board and explodes the
  DFS (ADR-0006). The retrograde engine uses the full move set by design; the forward cross-checks use eye-prune.

## Behaviour — every agent, every task
- **Per-board epistemic independence.** Each board size is its own epistemic universe: PROVEN / CLAIMED /
  FALSE-AS-SCOPED at one size is **not** evidence at any other size, absent a monotonicity theorem.
- **Evidence in git, or the claim is not proven** — under `docs/evidence/<claim-id>/`, never `untracked/`:
  that is how T13's probe source, the falsification the strategy rests on, was destroyed. **Every claim
  carries a status** — PROVEN / CLAIMED / FALSE-AS-SCOPED — and never assert "proven" or "sound" without
  the run that makes it so.
- **No silent writes to `data/` or `artifacts/`.** New rule → new file, tagged `(size, ruleset)`; never
  overwrite a `.wzo` or `artifacts/SHA256SUMS`.
- **One writer per engine file** (`src/retro.zig`, `oracle.zig`, `rules.zig`, `solve.zig`). Declare
  ownership in `docs/status/CURRENT.md`, clear it when done; concurrent edits corrupt silently.
- **Dates are absolute** (2026-07-28), never "today." **Numbers cite their run** (command, flags, board
  size) and state their **denominator**.
- **Know your role, your task ID and your model, and write the model into every file you produce** —
  `Model: not stated at dispatch` if you were not told, **never a guess**; otherwise the model-performance
  ledger can attribute nothing.
- **Workers are identified by task ID** (`EXP-4`, `B99`), never by model name; thinking managers are
  addressed by ROLE — OVERSEER / ADVISOR / THEORIST. Who is who, what may be specified in a brief, and how
  many agents may run at once: `docs/infra/delegation/ROLES.md`.

## Build / test / run
- Build `zig build` · suite `zig build test` · per-module `zig test src/<file>.zig` (avoids the dyld mega-
  binary quirk). Correctness runs use `-Doptimize=ReleaseSafe` — asserts are no-ops in ReleaseFast.
- Retrograde build + battery: `RETRO_SAVE=1 zig run -O ReleaseFast src/retro.zig`. Long runs (258 MB, 19 sweeps)
  need a persistent session: start it, watch the heartbeat, never restart. Caches under `/tmp/weizigo-zigcache`.
- `weizigo-oracle <a.wzo>` (GTP; Sabaki-compatible) · `weizigo-arena <a.wzo> <seeds>` · `bin/weizigo-claimlint`.

## Where to go next — read ONE of these
| if you are… | read |
|---|---|
| dispatching, or unsure what you are | `docs/infra/delegation/ROLES.md` |
| writing a task for another agent | `docs/infra/delegation/DELEGATOR.md` |
| executing a task you were handed | `docs/infra/delegation/DELEGATEE.md`, then your brief |
| running an experiment from a console | `docs/infra/dispatch/README.md` + your experiment's brief there |
| auditing or setting claim status | `docs/epistemic/CLAIMS.md` (one owner — do not race it) |
| unsure of a term | `docs/epistemic/GLOSSARY.md` (coinages marked `[project term]`) |
| after the living overview | `docs/epistemic/PROGRESS.md` — the durable hub. The two dated docs below are depth it is meant to absorb; if they disagree with it, PROGRESS is stale and that is a bug to file |
| after which ruleset we solve, and how | `docs/epistemic/roadmap-2026-07-28.md` |
| after what is known-wrong | `docs/epistemic/critique-2026-07-28.md` (§4 especially) |
| resuming cold | `docs/status/CURRENT.md`, then `docs/status/HANDOVER.md` |
| editing engine code | `docs/engine/ARCHITECTURE.md` + the relevant `docs/decisions/000N-*.md` |

## Agent-to-agent communication
Cross-agent traffic lives in `untracked/msg/<milestone>/` (max two live): `STATE.md` is the crash-recovery anchor
(read first; always current, overwritten in place), `NNN-<from>-to-<to>.md` are append-only numbered messages
(never edit an old one), `DECISIONS.md` records every ruling with its promotion target in `docs/`. **Delete the
directory only once every decision is promoted** — `untracked/` is git-ignored, so it dies on a fresh clone; that
is how T13's evidence was destroyed. Promotion is the gate, not tidiness.
