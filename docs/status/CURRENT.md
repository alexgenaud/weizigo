# CURRENT — in-flight task status (ephemeral; updated often)

**Purpose:** the single file a fresh session reads to resume *without loss*
after a context clear / compact / handover. Not durable — milestones live in git +
`../epistemic/PROGRESS.md` + `../decisions/` + `../research/`. If this file is stale, read
`../epistemic/PROGRESS.md` → `leak-crisis.md` and rebuild it.

Last refreshed **2026-07-27 ~23:55**.

---

## EXP-3 (Minimax-m3) — DONE 2026-07-28

- Wrote `src/kostate_census.zig` (new file, no engine file touched). Standalone
  except std; `pos_from_move` and `is_legal` reimplemented to avoid pulling
  rules.zig in (per dispatch intent).
- HEADLINE NUMBERS (standard basic-ko detector, no sampling, no stride):
  - **3×3:** 22,736 reachable (b,side,ko) triples; 13,997 distinct (b,ko) addresses; 7.11% of naive dense; 16 sweeps; <1 s.
  - **4×3:** 638,266 triples; 375,281 addresses; 5.43% of dense; 25 sweeps; 2.2 s.
  - **4×4:** **51,419,046 triples; 29,497,329 addresses; 4.03% of dense; 29 sweeps; 4 min.**
- Implied artifact size at 6 B/address: **177 MB at 4×4** (0.69× current PSK 4×4
  artifact of 258 MB; 25× smaller than naive dense 4.39 GB). With `passes ∈
  {0,1}` folded (a′, b′), 354 MB. **GO on dense addressing at 4×4** under the
  D3 placeholder (≤ 32 GB).
- Calibration: legal position counts match OEIS A094777 (3×3=12,675;
  4×4=24,318,165; 4×3=321,689 ground truth). Broken detectors
  (`every_capture`, `every_move`) move the count in the predicted direction
  and magnitude.
- **Calibration-2 caveat noted in the research doc:** the dispatch's expected
  "no-ko collapses to (pos, side) slot count" is overstated — the slot count
  is the total addressable space, not the B-to-move reachable space. The
  honest figure is the B-to-move reachable (20,888 at 3×3, 45,734,854 at
  4×4) — a separate independent depth-parity BFS confirms this.
- Deliverables (all committed, ready to cite):
  - `src/kostate_census.zig`
  - `docs/evidence/GLOBAL.H1-CENSUS/PROVENANCE.md` + 8 raw stdout files
  - `docs/research/kostate-census-2026-07-28.md` (the four numbers per
    board, the addressing GO/NO-GO, every claim tagged, calibration
    caveat stated up front)
- **Status update for CLAIMS.md (owner folds):** `GLOBAL.H1-CENSUS` (4×4)
  was UNTESTED → **PROVEN** with this census + calibration runs. Proposed
  per-board IDs `3x3.H1-CENSUS` and `4x3.H1-CENSUS` → owner assigns. (I
  did not edit CLAIMS.md per dispatch.)

## EXP-2 (Minimax-m3) — claiming work

- Reading `docs/infra/dispatch/EXP-2.md` now. EXP-2 is THE GATE for the
  roadmap; does **not** touch any engine file. Plan: write
  `docs/evidence/QA-023/proof.md` (Part A) and a 2×2 implementation
  (`src/qa023_basic_ko_2x2.zig`) plus a brute-force reference
  (`src/qa023_brute_2x2.zig`), then both calibration and acceptance runs.
  Binaries: `weizigo-exp2-<id>` under `/tmp`, caches under
  `/tmp/weizigo-zigcache-exp2`.
- Files I will own for EXP-2: `docs/evidence/QA-023/**`, `src/qa023_*.zig`,
  `docs/research/qa023-basicko-markovian-2026-07-28.md`. None of the four
  engine files. ETA: one session.

## Where the project stands right now (2026-07-27)

The 2026-07-27 evening session produced one finding that reorders the queue:
**the GTP player steers by numbers that are not comparable to each other.**

- **PROVEN (2026-07-27, `bin/weizigo-chainability`):** outside the KO_SENSITIVE
  flag there are **zero** history-free-Bellman-identity violations at
  2×2/3×2/3×3/4×3 (exhaustive) and 4×4 (`--sample 37`). The single-score (L==H)
  region *is* chainable. Violations are exactly co-extensive with the flag
  (16/16, 72/72, 688/688, 6,092/6,092, 11,402/11,402).
- **PROVEN (same run):** the empty 4×4 board is itself KO_SENSITIVE (bracket
  [−6, +16]), and 16 of 19 plies of both saved regression games are flagged. On
  4×4 the player never has table guidance it is entitled to chain.
- **PROVEN (two saved 4×4 games):** positional-superko bans changed the best
  available value at **0 of 19 plies**. The ko *rule* costs the engine nothing.
- **Not a bug.** Each ko-sensitive slot is an independent fresh-start PSK solve
  and owes its parent no agreement — the violations are C2 restated per-slot.

Full record and the fix fork: `../research/ko-sensitive-chainability.md`.
Strategic framing (do not duplicate it here): `../epistemic/PROGRESS.md`.

**The headline gap this exposes (CLAIMED, an interpretation):** PSK is
non-Markovian while the stored table is Markovian. PROGRESS has recorded since
2026-07-24 that PSK is abandoned as the *generation* rule with basic/simple ko
as the tractable candidate — but the 4×4 artifact and the GTP player are both
**still PSK**. That unexecuted pivot is now the top item. Nothing asserts simple
ko will work: its state-space census has not been run and the long-cycle
resolution rule is undecided.

## Uncommitted / unverified right now

Working tree is **dirty**; last commit is `753584f` (2026-07-27 23:28, the 4×4
regression fixture + `zig` test). Uncommitted:

| path | what it is | verified? |
|---|---|---|
| `src/chainability.zig`, `build.zig` | new `weizigo-chainability` tool + build target | builds clean `-Doptimize=ReleaseFast`; no test coverage of its own |
| `docs/research/ko-sensitive-chainability.md` | the finding (new) | numbers reproducible via the commands in the doc |
| `docs/research/corrections-2026-07-27.md` | errata ledger (new, another agent) | in flight |
| `docs/research/open-hypotheses-2026-07-27.md` | open-work queue H1–H5 (new, another agent) | in flight, may not exist yet |
| `docs/epistemic/GLOSSARY.md` | new term **chainable** | — |
| `docs/epistemic/boards/4x4/EPISTEMIC.md` | new measured facts M4, M5; FP1 check 3 → done-with-caveat | — |
| `docs/epistemic/PROGRESS.md`, `docs/status/CURRENT.md` | B45 doc hygiene + this refresh | — |
| `docs/epistemic/boards/4x3/` | 4×3 epistemic tree (B45) | — |
| `regressions/README.md` | diagnosis section (another agent) | in flight |

**Known-unsound statements already in the repo** (being logged in
`../research/corrections-2026-07-27.md`, do not re-derive): commit `753584f`
and `regressions/README.md` blamed the blunder on PSK history (zero bans were
active at that node) and called it "the C2 falsification in action" (C2 is
scoped to L==H; every blundering node is KO_SENSITIVE, outside C2's scope); and
ADR-0013's closing line says the GTP player shares the finisher machinery and
inherits its fix — it does not, `Session.choose` in `src/gtp.zig` does table
lookups only and never searches.

**Scope caveats to carry:** the chainability check validated the shipped
`vb`/`vw` columns only (WZO1 stores no bracket columns, so the `lo`/`hi` form is
untested), and 4×4 was a 1:37 stride sample, not exhaustive.

## Next actions — ordered by cost (cheapest first)

1. **H1 first experiment — simple-ko reachable-state census at 4×4.** Count
   reachable `(position, ko_point, side)` triples. This is a counting job, not a
   solve, and it is the one number that says whether the simple-ko pivot is
   tractable at all. Highest value per hour on the board. Do **not** start a
   simple-ko generation run before this number exists.
2. **Commit the chainability work.** `src/chainability.zig`, `build.zig`,
   `docs/research/ko-sensitive-chainability.md`, `GLOSSARY.md`,
   `boards/4x4/EPISTEMIC.md`, the corrections + open-hypotheses docs, and the
   status refresh. One commit per topic; the tree has four concurrent authors,
   so `git add` by path, never `-A`.
3. **H2 — greedy-vs-random arena persona.** Runs on existing machinery
   (`bin/weizigo-arena`). Falsifies or confirms the CLAIMED reading that B43's
   3.4% clean leak rate is a *lower bound* for the greedy GTP player. If greedy
   does not leak more, the "flattering false premise" mechanism is wrong.
4. **H4 — close the FP1 check-3 residue.** Exhaustive 4×4 chainability pass
   (drop `--sample`) plus an in-memory `lo`/`hi` bracket-table variant of the
   same identity. Cheap to state, long to run.
5. **H5 — player hardening.** Only after (1): the fork in
   `../research/ko-sensitive-chainability.md` is sound-but-mute (steer only
   where chainable) vs tractable-but-unsound (bracket cuts = C3, falsified at
   3×3) vs bounded-history state (new ADR). **This is the user's call, not an
   agent's** — no engine change was made on this finding.
6. **H3 — mid-game tractability crossover** for history-exact search (where does
   a real-history search become affordable?). Open-ended; lowest priority.

Detail and falsification tests for H1–H5: `../research/open-hypotheses-2026-07-27.md`.

## Concurrency — who owns what (2026-07-27 evening)

Four agents were writing this tree in parallel. One writer per file; if you pick
up a file listed above, check `git status` first and post a one-line intent here
before editing `src/retro.zig` / `oracle.zig` / `rules.zig` / `solve.zig`.
No engine file is currently claimed.

## Completed 2026-07-27

- **Chainability finding** — `bin/weizigo-chainability` built; five artifacts
  measured; PROGRESS, GLOSSARY, 4×4 EPISTEMIC, regressions README updated.
- **`753584f`** — 4×4 regression fixture (`regressions/4x4-history-blunder.{gtp,sgf}`,
  `4x4-black-win-after-ko.txt`, README) + artifact-independent `zig` test
  `4x4 regression: user-win B+15.5 …` in `src/gtp.zig` (final area 16 → B+15.5
  at komi 0.5).
- **GTP play-policy sequence** (`c03d40b`…`e94b107`) — pass/resign policy,
  early-game min-stones gate, capture-priority tie-break.
- **B45 doc hygiene (Kimi)** — PROGRESS + CURRENT refresh, new
  `docs/epistemic/boards/4x3/EPISTEMIC.md`; UD-1/2/3 resolved; docs-only.
- **B43/B44** — arena UNDEF guard (clean 4×4 leak rate **3.4%**, max 32 pts;
  `../research/arena-4x4-undef.md`) and repo cleanup.
