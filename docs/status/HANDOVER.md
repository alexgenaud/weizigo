# Boss handover — 2026-07-27 evening (chainability session)

Tactical, per-session snapshot. Strategy lives in `../epistemic/PROGRESS.md`;
in-flight task state lives in `CURRENT.md`. This file answers: what just
happened, what will bite you, what to do next.

## Read order

1. `../epistemic/PROGRESS.md` — strategic overview (refreshed 2026-07-27).
2. `CURRENT.md` — live state, uncommitted-work table, next actions by cost.
3. `../research/ko-sensitive-chainability.md` — **the finding of this session.**
4. `../../AGENTS.md` — behavior rules and foreclosures.
5. `../research/corrections-2026-07-27.md` — errata: statements already in the
   repo that are wrong. Read before quoting commit `753584f` or
   `regressions/README.md`.
6. `../research/open-hypotheses-2026-07-27.md` — the open-work queue (H1–H5).
   Written by a concurrent agent on 2026-07-27; if it is absent, the same queue
   is summarised in `CURRENT.md`.

## What this session did

- Built `bin/weizigo-chainability` (`src/chainability.zig`, new `build.zig`
  target): reads an artifact alone — no history, no search, no reference solver
  — and checks the history-free Bellman identity slot by slot.
- Measured 2×2 / 3×2 / 3×3 / 4×3 exhaustively and 4×4 at `--sample 37`
  (`bin/weizigo-chainability data/oracle-4x4.checkpoint.wzo --sample 37`;
  657,566 positions, 1,313,248 slots). Headline: **zero** violations outside the
  KO_SENSITIVE flag at every size (the L==H region *is* chainable — FP1
  acceptance check 3, previously untested); violations exactly co-extensive with
  the flag; the empty 4×4 board is itself KO_SENSITIVE (bracket [−6, +16]).
  Sampling cross-check: ko-sensitive fraction 21.27% vs M1's exhaustive 21.32%.
- Established that the ko *rule* is innocent: positional-superko bans changed
  the best available value at **0 of 19 plies** in both saved 4×4 games.
- Recorded it in `../research/ko-sensitive-chainability.md`, plus **chainable**
  in `../epistemic/GLOSSARY.md`, facts M4/M5 in
  `../epistemic/boards/4x4/EPISTEMIC.md`, and a diagnosis section in
  `../../regressions/README.md`.
- Landed `753584f` earlier the same day: the 4×4 regression fixture and an
  artifact-independent `zig` test in `src/gtp.zig` (final area 16 → B+15.5 at
  komi 0.5). Its commit message is partly wrong — see the errata doc.

Not done, deliberately: **no engine change.** The fix is a deliverable choice
(sound-but-mute vs tractable-but-unsound vs bounded-history state) and it is the
user's call; any change to the ko/finisher path is gated on the #2 auditor.

## Gotchas — read before you run anything

- **`zig build test` fails on this machine** (the documented dyld mega-binary
  quirk), not because anything is broken. Per AGENTS.md use per-module
  `zig test src/<file>.zig`. All 93 tests pass when the test binary is run
  directly, as of 2026-07-27.
- **Ko-sensitive Bellman violations are EXPECTED, not failures.** A ko-sensitive
  slot is an independent fresh-start PSK solve; it owes its parent no agreement
  across a history-free edge. `weizigo-chainability`'s verdict line therefore
  judges **only the region outside the KO_SENSITIVE flag** — that is the
  falsifiable part. Do not "fix" an in-flag violation.
- **One writer per file.** Four agents shared this tree on 2026-07-27 evening.
  `git status` before editing; `git add` by path, never `-A`; post an intent
  line in `CURRENT.md` before touching `src/retro.zig` / `oracle.zig` /
  `rules.zig` / `solve.zig`.
- **`Session.choose` in `src/gtp.zig` never searches** — it is table lookups
  only. ADR-0013's closing line claiming the GTP player inherits the finisher's
  fix is false; do not rely on it.
- **Per-board epistemic independence.** Nothing measured at 4×3 or 4×4 is
  evidence for 5×5. The 2n-misprice regularity is CLAIMED across four sizes with
  no proof.
- **Scope of the chainability PROVEN claim:** shipped `vb`/`vw` columns only
  (WZO1 carries no bracket columns) and 4×4 was a 1:37 stride sample.
- Correctness runs use `-Doptimize=ReleaseSafe`; asserts are no-ops in
  ReleaseFast.

## Critical state

- **C1** PROVEN at 2×2/3×2. **C2** FALSE-AS-SCOPED at 3×2 (T13). **C3**
  FALSE-AS-SCOPED at 3×3 (E2). **C4** false. Chainability of the L==H region
  PROVEN 2026-07-27 (scope above) — the region's first *positive* property.
- Artifacts: `artifacts/oracle-{2x2,3x2,3x3,4x3}.wzo`;
  `data/oracle-4x4-parallel.checkpoint.wzo` at 99.8% (83K unfilled, 2-ko+
  tangles), usable for GTP play with UNDEF fallback;
  `data/oracle-4x4.checkpoint.wzo` is what the chainability run measured.
- Committed ko-sensitive single-number scores remain untrusted (AGENTS.md).
- Working tree is **dirty** — see the uncommitted table in `CURRENT.md`. Build
  is clean at `zig build -Doptimize=ReleaseFast`.
- The 4×4 artifact **and** the GTP player are still positional superko, although
  PSK has been abandoned as the generation rule since 2026-07-24. That gap is
  the headline item.

## Immediate next task

**Run the H1 first experiment: a reachable-`(position, ko_point, side)`-triple
census at 4×4 under basic/simple ko.** It is a counting job, not a solve; it is
the cheapest thing on the queue and it decides whether the simple-ko pivot is
tractable. Do not start a simple-ko generation run, and do not assert that
simple ko works, before that number exists — the long-cycle resolution rule is
also still undecided.

Then, in cost order: commit the chainability work; H2 greedy-vs-random arena
persona; H4 exhaustive 4×4 + `lo`/`hi` chainability residue; H5 player
hardening (user's call); H3 mid-game tractability crossover. Detail in
`CURRENT.md` and `../research/open-hypotheses-2026-07-27.md`.

## Key tools

| Binary | Source | Purpose |
|---|---|---|
| `bin/weizigo-oracle` | `src/gtp.zig` | GTP player (auto-artifact from boardsize) |
| `bin/weizigo-chainability` | `src/chainability.zig` | Bellman-identity audit of an artifact (new, uncommitted) |
| `bin/weizigo-arena` | `src/arena.zig` | Persona / regression / leak audit |
| `bin/weizigo-engine-vs-engine` | `src/engine-vs-engine.zig` | Self-play regression |
| `bin/managent` | `src/managent/main.zig` | Task manager |
