# AGENTS.md — how to work on weizigo

Agent- and harness-agnostic conventions. Read by Codex, Claude Code, Cursor,
and any LLM coding agent that honors the emerging AGENTS.md standard. If your
harness prefers a different filename (CLAUDE.md, .cursorrules), create a thin
redirect to this file rather than duplicating it.

## Read order (do this before writing any code)

1. `docs/PROGRESS.md` — the living document: where the project is, globally.
   Start here.
2. `docs/HANDOVER.md` — session-continuity snapshot: tactical state, the
   immediate next task, gotchas. Updated every session.
3. `AGENTS.md` (this file) — behavior rules and foreclosures.
4. `docs/ARCHITECTURE.md` — module map and the layer cake.
5. `docs/TODO.md` — backlog.
6. `docs/RISKS.md` — known risks, gotchas, smells, bugs. Read before engine edits.
7. The relevant `docs/decisions/000N-*.md` (ADRs) for whatever you're touching.

PROGRESS = strategic, long-term, changes when milestones shift.
HANDOVER = tactical, per-session, changes every session. They are complementary;
do not let one rot while the other updates.

## What this project is

`weizigo` — a provably-correct solver for small Go boards (Weiqi/Baduk) in
Zig 0.16. Goal: a compressed perfect oracle — the exact game-theoretic value
of every legal (position, side) — built by retrograde value iteration with
two-sided (L/H) certification. Boards done through 4x4; aiming at 5x5, then
6x6, then 7x7. See PROGRESS.md.

## Non-negotiable rules (foreclosures — do NOT relitigate)

These are settled. Reopening them wastes a session. If you believe one is
wrong, write a new ADR that supersedes the old and cite evidence; do not just
act against them.

- **Positional superko (PSK) is NOT the generation target.** PSK exact-solve
  is intractable even on the EMPTY 2x2 (118M ban-set states). See ADR-0013,
  `research/ruleset-options.md`. Play-time can still enforce PSK for legality.
- **kill-X% is dead as a residue cure.** It makes the 4x4 residue WORSE
  (21.32% -> 25.01% as the threshold drops). Remains an optional play rule only.
- **score-on-cycle is provably as hard as PSK.** Byte-identical state counts
  (118,475,182 / 116,114,272). No free lunch. See `research/ruleset-options.md`.
- **The committed residue values are NOT trustworthy.** `data/oracle-4x4.wzo`
  and the 2x2/3x2/3x3 residue columns are unverified until Track A regenerates
  them with `memo_writes=false` and passes the #2 auditor. The certified
  L==H core IS correct. Do NOT quote a residue value as truth until then.
- **Never report a single residue number as "the value of the board."** The
  honest deliverable is the rule-independent certified core + the [L,H]
  bracket for the residue. A single number is not soundly pinnable by any
  tractable method we have.
- **The #2 self-consistency auditor is a mandatory pre-commit gate** for any
  change to the finisher, memo logic, or ko/GHI handling. Zero minimax-identity
  violations on 3x2 exhaustive + the deepest-N 4x4 sample. A "sound by
  construction" claim without an auditor run is INSUFFICIENT — the last bug
  (`ko_ref >= d`, ADR-0013) looked obviously correct and was wrong.
- **Scores are ALWAYS Black-positive.** Side-to-move picks the array
  (vb/vw), never the sign. Black maximizes, White minimizes. Colour inversion:
  value(-pos,-side) == -value(pos,side); for bound tables L(-pos,-side) == -H.
- **Never call the board index a "rank."** In Go, rank = kyu/dan. Use
  "colex index" or just "index." (User decision; you will be corrected.)
- **No sub-board solving.** Restricting moves to a region of the board is
  unsound (edge stones keep phantom liberties). Search is full-board only.
- **Do not remove the eye-prune from the forward search.** Self-eye-fill
  reopens the board and explodes the DFS (ADR-0006). The retrograde engine
  uses the full move set by design; the forward cross-checks use eye-prune.

## Behavior

- **Verify, then claim.** Run the battery (auditor + bracket containment +
  symmetry + anchors + Exact-on-reachable + arena) before reporting a result.
  Report deviations honestly, including ones that invalidate your own change.
- **Prefer small, reviewed changes** to large rewrites. `retro.zig` is 3,065
  lines and the highest-risk file; edits there need an auditor run.
- **No silent writes to artifacts.** `data/oracle-*.wzo` and `artifacts/*.wzo`
  are large and precious. Never overwrite an artifact without an explicit
  instruction; write to a new path and re-hash first.
- **One writer at a time on the engine.** If sub-agents are spawned, never
  let two edit `retro.zig`/`oracle.zig`/`rules.zig` concurrently. See RISKS.md.
- **Update docs as you go.** When a milestone shifts, update PROGRESS.md. At
  the end of every session, update HANDOVER.md. New decisions get a new ADR
  (append-only; supersede, don't rewrite).
- **Dates are absolute** (e.g. 2026-07-24), never "today."
- **Numbers cite their run** (command, board size, flags).

## Build / test / run

- Build: `zig build`
- Full suite: `zig build test`
- Per-module (reliable, avoids the dyld mega-binary quirk): `zig test src/<file>.zig`
- Retrograde build + battery: `RETRO_SAVE=1 zig run -O ReleaseFast src/retro.zig`
- Correctness runs use `-Doptimize=ReleaseSafe` (asserts are no-ops in
  ReleaseFast — a known footgun; see RISKS.md).
- Playable oracle: `weizigo-oracle <artifact.wzo>` (GTP; Sabaki-compatible).
- Arena audit: `weizigo-arena <artifact.wzo> <seeds>`

## Sandbox awareness

This harness runs in a restricted sandbox by default. Writes are limited to
the workspace and tmp; reads to the workspace tree. Commands needing broader
access trigger an approval prompt. Long retrograde runs (258 MB artifacts,
19 sweeps) may need a persistent PTY session — start it, watch the heartbeat,
feed input without restarting.

## Workflow & readiness

The full intention is in `docs/agent-workflow.md` (read it). Summary, in
spirit not ceremony — the agent chooses how much applies per task:

- **Document before / while / after.** Intent + a falsifiable acceptance test
  as a `TODO` first; keep the doc honest during; record success *or* failure
  and prune after.
- **Fail-fast subtasks.** Prefer a probe that returns a number in seconds over
  one that grinds as a black box.
- **Always ready to clear context.** Write unchecked task status to
  `docs/status/CURRENT.md` continuously. Aim to implement → test → stabilize →
  verify → commit in small cycles, so the committed state is coherent and only
  the current `CURRENT.md` line is at risk. Milestones go to git; the in-flight
  task goes to `CURRENT.md`; decisions/findings to ADRs/`research/`.
- **Auditability.** Each phase (spec, design, test, integrate) should be
  independently auditable by a fresh agent that reads only the relevant doc.
- **Parallelization.** Uniquely ID chunk outputs; each task declares its
  parallelization tolerance; default to ONE writer per engine file
  (`retro.zig`/`oracle.zig`/`rules.zig`) — concurrent edits silently corrupt.
- **Epistemic discipline.** Every claim carries a status: PROVEN / CLAIMED /
  FALSE-AS-SCOPED. Never assert "proven/sound" without the evidence. Record
  ambiguity explicitly rather than forcing a clean story.

If encoding these as rules produces deadweight instead of results, the rules
are wrong — prune them.

## Concurrency protocol (Boss-adopted, 2026-07-25)

Multiple agents (GLM-Boss orchestrator; Minimax, Kimi workers) share this tree
and `/tmp`. Light rules; the point is no silent collisions:

- **One writer per engine file.** Before editing `src/retro.zig`, `oracle.zig`,
  `rules.zig`, or `solve.zig`, post a one-line intent in `docs/status/
  CURRENT.md` ("<agent> editing src/X for <task>, ~N min"); note when done.
  Others wait or pick a different file.
- **One scratch file per in-flight task** (`untracked/<topic>.md` or
  `docs/status/<topic>.md`), owned by the agent that opened it; others append
  findings, the owner folds them in. Avoids two agents racing `CURRENT.md`.
- **Binaries** named `retro-<env>` (e.g. `retro-e2`, `retro-e3-1`); gitignored
  (`/retro-e*`); remove when done. Use `ZIG_GLOBAL_CACHE_DIR`/`ZIG_LOCAL_CACHE_DIR`
  under `/tmp/weizigo-zigcache`.
- **No silent writes** to `artifacts/` or `artifacts/SHA256SUMS`.
- **High-contention docs** (`PROGRESS.md`, `HANDOVER.md`, `status/CURRENT.md`,
  `status/leak-crisis.md`): one editor per session; others append to a topic
  scratch file for the owner to fold.
- **Boss is orchestrator.** Workers pick tasks from `CURRENT.md` / the
  discussion tree (`untracked/discussion.md`) / Boss assignments, and report
  back to disk. When idle, pick a low-risk task from `untracked/idea-heap.md`.

## Pointers

- `docs/decisions/0001..0013` — ADRs (0007 = goal; 0009 = retrograde engine;
  0010 = bracket finisher; 0011 = artifact format; 0012 = RAM-lean roadmap;
  0013 = sound finisher + dependency-guarded memo).
- `docs/research/` — durable findings. `ruleset-options.md` (the ruleset
  pivot), `methods-and-findings.md` (plain-English narrative),
  `retrograde-3x3.md` / `retrograde-4x4.md` (measurements),
  `consistency-audit.md` (the #2 auditor that convicted the write path).
- `docs/GLOSSARY.md` — terms.

## Epistemic discipline

- **Never assert as fact what you cannot verify.** This applies to model
  identity, version numbers, library behavior, and — especially here —
  soundness/correctness claims. "This is sound by construction" without a
  passing auditor run is the failure mode that produced the `ko_ref >= d` bug.
- **Project-invented shorthand is fine, but mark it.** Terms coined in this
  project (not standard terms of art) live in `docs/GLOSSARY.md` marked
  **[project term]** with a plain-English expansion. Prefer plain English in
  prose; reserve the shorthand for tight contexts and always define on first use.
- **"sound" is a real formal-methods term** (a method that never returns a wrong
  answer) but has been used loosely here as shorthand for "correct / not GHI-
  tainted." Use the precise sense; name the specific invariant. See GLOSSARY.md.
