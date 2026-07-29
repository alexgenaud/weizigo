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
- **Know your identifier and write it into every file you produce.** Court seats use the role name
  (`Orchestrator`, `Dabir`); workers use their task ID (`2B-5`, `EXP-4`). A model name alone names a
  *kind* of worker, not a worker, and five instances of one model ran five tasks on 2026-07-29. In full
  at first use, abbreviated after. `unknown/<task-id>` if you were not told your model, **never a guess**;
  otherwise the model-performance ledger can attribute nothing. The model is recorded at dispatch time
  in `managent`'s `agent` field and in `model-perf.md`; it does not belong in the identifier. Scheme and
  edge cases: `docs/infra/agent-identity-and-worker-channel.md`.
- **Workers are identified by task ID** (`EXP-4`, `B99`), never by model name; thinking managers are
  addressed by ROLE — Orchestrator / Dabir / Auditor. Who is who, what may be specified in a brief, and how
  many agents may run at once: `docs/infra/delegation/ROLES.md`.

## Build / test / run
- Build `zig build` · suite `zig build test` · per-module `zig test src/<file>.zig` (avoids the dyld mega-
  binary quirk). Correctness runs use `-Doptimize=ReleaseSafe` — asserts are no-ops in ReleaseFast.
- **Ad-hoc builds run under `tools/runner`**, which auto-adds `-O ReleaseFast` (or
  `-Doptimize=ReleaseFast` for `zig build`) and SIGKILLs the process group on a
  4 GB RSS breach. The 2026-07-29 02:37 host kernel panic
  (`docs/infra/host/incident-2026-07-29.md`) is the precedent; the runner is
  `docs/infra/runner.md`; the source is `tools/runner` (Python, stdlib only).
  **Builds without the guard on a host with a recent compressor incident are
  the Orchestrator's responsibility to refuse, not the agent's to remember.**
- Retrograde build + battery: `RETRO_SAVE=1 zig run -O ReleaseFast src/retro.zig`. Long runs (258 MB, 19 sweeps)
  need a persistent session: start it, watch the heartbeat, never restart. Caches under `/tmp/weizigo-zigcache`.
- `weizigo-oracle <a.wzo>` (GTP; Sabaki-compatible) · `weizigo-arena <a.wzo> <seeds>` · `bin/weizigo-claimlint`.
- `bin/managent` is the queue: `add` / `dispatch` / `claim` / `done` / `reopen`
  / `purge` / `set` / `next` / `status` / `show`. The human dispatches; the
  agent claims; the Orchestrator owns the kanban end-to-end (D-8) and may
  dispatch/claim/done on a worker's behalf, attributing with `--agent <worker>`.
  Schema in `docs/infra/managent/spec.md`; role protocol in
  `docs/infra/roles/ORCHESTRATOR.md`.
- **stdout = data, stderr = diagnostics.** Use `util.out(...)` for parseable/filterable
  output and `util.note(...)` / `util.warn(...)` for diagnostics. Reference:
  `src/gtp.zig:691,1056`, helper in `src/util.zig`. Regression check:
  `<tool> 2>/dev/null` must emit data, `<tool> 1>/dev/null` must be silent.

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
| resuming cold (durable in git) | `docs/status/CURRENT.md`, then `docs/status/HANDOVER.md` |
| resuming from the channel (durable + untracked) | `untracked/msg/<milestone>/STATE.md` (read first), then `docs/status/CURRENT.md` |
| running an ad-hoc build | `docs/infra/runner.md`, then `tools/runner -- <command>` |
| editing engine code | `docs/engine/ARCHITECTURE.md` + the relevant `docs/decisions/000N-*.md` |

## The queue is a *kanban*, not a *board*

`bin/managent` is the **kanban**. Never call it "the board" — in this project **board** means the Go board
(2×2, 3×2, 4×4), and the overload has already produced sentences that read two ways. Say *kanban*, *task*,
*column*, *claim*. (User's terminology ruling, 2026-07-29.)

## Verification rules earned on 2026-07-29 (the QA-023 chain) — standing

The QA-023 probe returned `TIE` on its first node in **1,133 of 1,133** evaluations and produced two
published falsification numbers before an absorption check caught it. **Five audit links; four passed the
artefact through.** These are the rules that would have caught it, and they are now standing:

- **Verify-then-promote.** A load-bearing claim moves to FALSE (or PROVEN) **only after an independent
  seat agrees** — not on one model's report, however well argued. The Orchestrator is not exempt: the
  Orchestrator's own adjudication went to `2B-6` before promotion. State the gate in the commit.
- **An auditor must trace one complete evaluation end-to-end.** `2B-3-AUDIT` stopped one function call
  short of the defect and verified everything around it. Reviewing inputs, outputs and structure is not
  the same as following one datum from entry to verdict.
- **A positive control must exercise the instrument under test, not a parallel one.** `2B-5`'s POS arm ran
  PSK through a *separate* code path, passed, and gave **zero** coverage of the defective call site — while
  reading as proof the instrument was sensitive.
- **Impossibly clean counters are red flags.** `budget-exhausted: 0` on a harness whose honest cost is
  exponential, or `value-agreements: 0` in every run ever recorded, are symptoms. Both were reported as
  reassurance.
- **Independent re-implementation is what finds defects.** In this project it is the *only* thing that ever
  has: the audit that found the ko bug (F5) rewrote the algorithm in Python; document review found nothing.
- **State every denominator, including the within-budget one.** 93% of the corrected probe's sample is
  missing; a rate quoted without that is not a measurement.

## Agent-to-human output — copy/paste boundaries (user requirement, 2026-07-29)

The human relays text between consoles by hand. **Anything he is meant to copy must be unambiguously
bounded, so he never has to guess which paragraphs are the payload.** Two forms, and only two:

**1. A prompt one-liner is exactly one line.** No wrapping, no internal newlines, no leading bullet or
quote marker — it must survive a single select-and-paste. If it does not fit on one line, it is not a
one-liner; use form 2.

**2. Multi-line copy/paste text is fenced by a `---` horizontal rule above and below, each `---` on its
own line with a blank line on either side.** So: prose, blank line, `---`, blank line, **the payload**,
blank line, `---`, blank line, prose. Nothing but payload goes inside the boundaries — no commentary, no
"note that…", no explanation the receiving console should not read. Put that in the prose outside.

Why: without the rule the human has to infer the subset, and inferring it wrongly means a console gets a
truncated or contaminated brief. This applies to relay messages, dispatch prompts, commit-message drafts,
and anything else handed over for pasting — every role, not just the Orchestrator.

## Agent-to-agent communication
Cross-agent traffic lives in `untracked/msg/<milestone>/` (max two live): `STATE.md` is the crash-recovery anchor
(read first; always current, overwritten in place), `NNN-<from>-to-<to>.md` are append-only numbered messages
(never edit an old one), `DECISIONS.md` records every ruling with its promotion target in `docs/`. **Delete the
directory only once every decision is promoted** — `untracked/` is git-ignored, so it dies on a fresh clone; that
is how T13's evidence was destroyed. Promotion is the gate, not tidiness.
