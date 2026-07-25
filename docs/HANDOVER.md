# HANDOVER — start here

Snapshot for resuming after a context compact/clear. Read this, then
`docs/ARCHITECTURE.md` (module map), `docs/TODO.md`, and the ADRs.
Updated 2026-07-22.

## LATEST (2026-07-22): ko_ref memo reuse DISPROVEN under prefixes; next = KM guard

The day a 15-kyu human beat the oracle (the "B+16 game") and everything it
taught. Read `research/arena-audit.md` + the B+16 sections of
`research/retrograde-4x4.md`. State:

- **GTP player + tools**: `src/gtp.zig` (Sabaki-compatible; Session is pub),
  `tools/play_oracle.py` (terminal play, shows diagnostics), `src/arena.zig`
  (adversarial self-play audit, 6 opponent personas, PROMISE/LEAK metric).
- **Measured**: fresh-start play leaks in 8-16% of adversarial games
  (MORE against STRONGER opponents — optimal 15.8%, novice 7.3%); max leak
  32 pts. Leaks without any single diverged move exist.
- **LOCALIZED (RETRO_CONTRA toggle matrix)**: the inconsistency (direct
  value -1 vs best child +1, same position+prefix) survives disabling
  bracket cuts AND certified seeds -> the culprit is CROSS-BRANCH MEMO
  REUSE under the ko_ref guard with a game prefix — the classic GHI hole,
  now empirically disproven (fresh-root use remains validated at 2x2/3x2).
  Assumption-free adjudication is INTRACTABLE (3 junctures > 4e9 nodes).
- **NEXT (the work item): Kishimoto-Muller dependency-guarded memo** —
  entries record the position-set their value depends on; reuse only where
  the current path cannot invalidate. Then: history-perfect genmove
  (per-move history-aware solve; measured cheap when sound), acceptance =
  ARENA ZERO LEAKS across all personas. Then recompute the tainted replay
  tables; then a 4x4 deep spot-check / KM-guarded finisher rerun (the same
  theoretical hole exists at fresh roots, undetected by all validation).
- Also recorded: worst-move review criteria (teaching-oracle-metrics.md),
  5x5 optimization plan + the honest 6x6 cliff (full tables end at 5x5;
  beyond needs CGT-style local decomposition — the query-engine direction).

## LATEST (2026-07-21 evening): the 4x4 ORACLE IS COMPLETE

`docs/research/retrograde-4x4.md` has everything. Headlines:

- **4x4 fully solved and persisted**: all 24,318,165 legal (position, side)
  per side exact; `data/oracle-4x4.wzo` (258 MB, gitignored) + checkpoint
  twin. empty(B) = **+2, dtt 13 — MATCHES the published anchor** (van der
  Werf & Winands 2009), first confirmation under positional superko. GTP
  self-play on the artifact ends 15 plies, double pass, final_score B+2.
- Scale numbers for 5x5: sweeps 2/6/12/**19**; residue fraction
  72/39/34/**21.3%**; 649,517 orbit reps ALL solved (0 skips), avg 1,663
  nodes/rep, finisher 6.1 min, whole run ~19 min wall.
- **The finisher was rebuilt twice to get here** (all measured, all
  committed): (1) deepest-first layers + per-layer CHECKPOINTS + resume
  (FLAG_TRIED_SKIP bit2) + heartbeat — the first attempt ran 4h as a black
  box grinding hopeless OPENING roots shallowest-first; (2) the root driver
  is now MTD null-window probing over the [L,H] bracket with a per-root
  BOUNDS memo (lb/ub per (idx,side), ko_ref-clean, journal-reverted; a
  fail vs the NARROWED entry window is never stored exact). Bare MTD
  without the bounds memo is measurably WORSE than aspiration; with it the
  empty 4x4 root fell from >5e8 nodes (abandoned) to <=3.5e5.
- GTP oracle player (`src/gtp.zig`, ADR-agnostic): plays any complete .wzo
  artifact via Sabaki/gogui; smoke-tested 3x3 (B+9) and 4x4 (B+2).
- Ko-rule-variant caveat recorded: published 2x2=0/2x3=0 (MIGOS: basic ko,
  long-cycle-ties, NO superko) vs weizigo PSK +1/+1 — a rules delta, not a
  bug; 3x3=+9 and 4x4=+2 match across rulesets.

NEXT: **5x5** — the engineering wall is density folds (legal ~2x, canonical
~8x; layout change -> bump `colex.layout_version`) + disk-streamed layer
sweeps (raw 3^25 = 847G slots). Compute trends say plausible; I/O is the
work. Optional 4x5 shakedown first (published anchor +20, 1/250th scale).
Also: journal encoding needs idx < 2^30 — revisit with folds.

## Older (2026-07-21): OPENING RESIDUE SOLVED — 3x3 oracle COMPLETE (ADR-0010)

The Finding-6 frontier is CLOSED. `docs/decisions/0010-bracket-guided-
finishing.md` + `retro.ab_solve`: the finisher's forward solve is now
fail-soft alpha-beta with the [L,H] brackets as cutoffs at EVERY node.
Brackets hold under any arrival history (the Finding-3 empirical claim), so
they fire deep inside the ko-tangled opening where certified-memo cuts could
not — plus bracket-ordered moves and an aspiration window one past the root's
own bracket. Neither iterated finishing nor Kishimoto–Müller buckets were
needed (KM stays the documented fallback for larger boards).

MEASURED (research/retrograde-3x3.md Findings 8–10):
- empty(B) 3x3 pins at +9 in **1,854 nodes, <1 ms** (plain finisher: >2.0e9
  nodes, abandoned) — ~10^6x. ALL 622 residue orbit reps solve in 156,178
  nodes total (~20 ms). 2x2: 6,033 vs 1.72e9 nodes.
- **3x3 oracle COMPLETE** — every legal (position, side) exact; all 5 anchors
  PIN (empty +9/−9, centre +9, side +3, corner −9); 0 bracket-fails, 0
  orbit-clashes; exhaustive symmetry PASS; ground truth 0 mismatches
  (2x2/3x2); plain-vs-bracketed tables IDENTICAL at 2x2 (engine-vs-engine).
- DTT extends through finished values free of charge: empty(B) = 3 plies
  (centre, pass, pass), max finite 16.
- Memo discipline unchanged: per-root, ko_ref-clean AND exact-only writes
  (a fail-soft bound is never stored). Finding 2 still stands — never share
  clean memo across roots. Brackets are shareable BY CONSTRUCTION.

ALSO 2026-07-21: **first real oracle artifacts persisted (ADR-0011)**.
`src/artifact.zig` (WZO1): dense colex-addressed columns (vb/vw/fb/fw/db/dw),
32-byte header versioning the format AND `colex.layout_version` (new constant
in colex.zig — bump it on ANY layout change, incl. the 5x5 density folds),
CRC-32, reader refuses any mismatch. `retro.saveArtifact` refuses to write an
incomplete/unvalidated table, and after writing RELOADS the file and verifies
every column byte-identical. `artifacts/oracle-{2x2,3x2,3x3}.wzo` committed
(518 B / 4.4 KB / 118 KB; reproduce: `RETRO_SAVE=1 zig run -O ReleaseFast
src/retro.zig`). New data: empty(B) fresh-start = +1 at both 2x2 and 3x2.

NEXT: (1) 4x4 scale run (43M slots in RAM): sweep count, residue fraction,
bracketed-finisher nodes/root — the 5x5 projection numbers (artifact would be
258 MB, same writer); (2) then 5x5 density folds (= colex_layout v2).

## Older (2026-07-19/20): the RETROGRADE ENGINE landed (ADR-0009, retro.zig)

The critical path is BUILT. `docs/decisions/0009-retrograde-value-iteration.md`
+ `src/retro.zig` (wired into `zig build test`; 86 tests green). Measurements
in `docs/research/retrograde-3x3.md`. What it is:

- **Successor-sweep value iteration** over the colex space — Bellman updates
  read FORWARD successors only (the cross-validated move generator; NO
  un-capture / predecessor code ever written). Captures are back-edges so it
  is a fixpoint; converges in 2/6/12 sweeps at 2x2/3x2/3x3 (forward filling
  was intractable — the whole point).
- **Ko/GHI handled structurally by TWO-SIDED (L/H) certification**, not history
  buckets: L seeded −n (least fixpoint), H seeded +n (greatest). Where L==H the
  value is history-free = the ADR-0008 fresh-start value (the CERTIFIED core).
  Where L<H the node is KO_SENSITIVE, bracketed [L,H], resolved by the
  **finisher** (certified-seeded forward solve).
- **NO eye-prune in the retrograde graph** → coverage is TOTAL (resolves the
  ADR-0007 eye-prune-vs-coverage tension). Forward cross-checks still use it.
- **Schema frozen** (ADR-0009 decision 4): value:i8 + dtt:u8 + flags:u8.
- **Battery**: `retro.Exact` (ban-set-keyed history-exact gold standard),
  L/H brackets, exhaustive symmetry (inversion + dihedral + L/H-swap + flags),
  3x3 anchors, spot checks.

KEY MEASURED FACTS (see research/retrograde-3x3.md):
- Cross-root sharing of ko_ref-clean memo is UNSOUND and MEASURABLY so (2x2
  gave an asymmetric table). Finisher solves ONE orbit rep per symmetry class,
  fresh certified baseline per root. NEVER share clean memo across roots.
- History-exact forward solving is the intractable thing ITSELF: the empty 2x2
  root exceeds 4e9 nodes / 3e7 exact states — the GHI cost IS the whole cost.
- Residue fraction FALLS with size: 72% (2x2) → 39% (3x2) → 34% (3x3). 3x3
  finisher = 375+247 orbit reps.

THE OPEN FRONTIER — **RESOLVED 2026-07-21 by ADR-0010 (see Latest above)**:
the deep-opening ko residue needed history-aware finishing; bracket-guided
alpha-beta turned out to suffice (the [L,H] tables themselves are the
history-free cut). The acceptance test (3x3 anchors PIN, not bracket) passes.

---

## Latest (2026-07-17/18): generic stack, colex, oracle attempt, design docs

Everything committed on `inverse-player` (unpushed; user pushes). Sessions
landed, in order:

1. **Goal fixed (ADR-0007)**: compressed perfect oracle — value of every legal
   (position, side). Board-size ambition: 5x5 -> 6x6 -> 7x7 (user: 7x7 is the
   minimal "interesting" game). Alpha-beta scrapped (can't populate an oracle).
2. **#1 safety + #2 old-path retirement done**; `persist.zig` ported onto
   `solve.Table`; forward FULL 5x5 solve measured non-converging (TT caches
   nothing — GHI-tainted opening): `research/forward-solve-scaling.md`.
3. **Generation-2 board-size-generic stack built** (see ARCHITECTURE.md):
   `enumerate.zig` (census, validated vs Tromp/OEIS through 4x4 — canonical
   counts are NEW data), `colex.zig` (the address system: `colex_from_pos` /
   `pos_from_colex`, bijection exhaustively verified through 4x4; naming went
   rank -> posidx -> **colex**, user decision — never say "rank"),
   `rules.zig` (generic rules kernel, cross-validated vs Gen-1 exactly),
   `oracle.zig` (builder + validation battery), `sgf.zig` (presentation
   delegated to external viewers; `research/oracle-5x5-pv.sgf` opens in
   SmartGo One / Sabaki).
4. **ADR-0008**: oracle semantics = FRESH-START value; sign conventions
   canonized (Black-positive always; side picks the slot, never the sign).
5. **MEASURED: forward fresh-start filling intractable even at 3x3**
   (8-stone roots >10M nodes, 2,100+-ply lines; `research/oracle-3x3.md`) —
   so the **RETROGRADE ENGINE (#6' ADR) IS THE CRITICAL PATH**. oracle.zig's
   validation battery (anchors, exhaustive inversion+dihedral,
   order-independence) waits ready to verify it.
6. **Benson's THEOREM (not just the port) exhaustively confirmed at 3x3**
   (1,766 cases, every attack sequence; `zig run -O ReleaseFast src/rules.zig`).
7. **Design docs from user requirements sessions** (read before any oracle/
   query work): `research/query-engine-and-explanations.md` — goal-bounded
   local solver (tsumego-style, forward search's redeemed role), LOCAL x
   GLOBAL move quadrants (honte/poison/sacrifice), tenuki/urgency test,
   fact-diff WHY explanations (no LLM fictions), group status ladder (incl.
   exact ko-threat sizing), verification-depth skill metric, personas (lazy /
   destroyer / Emperor's-courtesy margin steering / explainer), KataGo audit
   (score-perfection vs win-perfection; audit beats match), principle mining.
   `research/teaching-oracle-metrics.md` — SCHEMA: store value:i8 + DTT:u8 +
   flags per (position, side), columnar side-files for future data.

## NEXT (recommended): the #6' retrograde design ADR + 3x3 retrograde engine

The two load-bearing design problems: (a) predecessor generation / un-capture
(or successor-counting value iteration); (b) the ko/GHI representation —
history-sensitive buckets and cycle resolution under positional superko. The
3x3 measurements above are the design constraints. Include the schema decision
(value+DTT+flags) and the sign-conventions section (user has been bitten;
port the colour-symmetry tests). Validate with oracle.zig's battery + forward
spot checks + published anchors (3x3: B+9 centre / +3 side / -9 corner).

## Older context (2026-07-16): improvement review; safety hardening landed (#1)

A full engine-core read produced a prioritized cleanup/optimization backlog —
see the new **"Improvement review (2026-07-16)"** section at the top of
`docs/TODO.md` (#1–#6). #1 is DONE and committed:

- **Policy: the one-time perfect solve runs in `-Doptimize=ReleaseSafe`** —
  correctness beats speed.
- The two silent-corruption `assert`s are now **always-live `@panic`s**
  (`superko.push` MAX_LINE; `solve.Table.set` seq-full / inconsistency /
  overrun) so ReleaseFast can't corrupt the oracle undetected.
- `superko.History.max_len` measures the deepest game line per run.
- `main.zig` is now a solve driver: spawns a 256 MB-stack thread and reports
  value + max ply. `zig build run -Doptimize=ReleaseSafe` -> dead-stone demo
  = Black+25, max ply 2. Flip `main.FULL` for the empty board.
- **Depth clarified**: recursion depth == game-line length in PLIES, decoupled
  from the ~20-stone board ceiling (captures). `MAX_LINE=4096` is headroom, not
  a proof; realistic lines are almost certainly short (tens) — a real `FULL`
  run will now MEASURE it (needs the TT wired+sized first — #1-followup).
- Next recommended: #2 (retire old path — note `persist.zig` is worth keeping
  and couples `minimax`), then #3/#4/#5, then #6 (alpha-beta, own ADR first).

## What this project is

`weizigo` — a brute-force / perfect 5×5 Go solver in **Zig 0.16**, branch
**`inverse-player`**. Goal: compute the game-theoretic value under **Chinese /
area scoring + positional superko** (5×5 is known: **Black wins by 25** — the
oracle).

## Recently fixed (2026-07-15): `is_settled` terminal bug

`terminal.is_settled` used to over-fire — reporting *scoring-settled* positions
as *decided*. FIXED (commit b18e49d): it now also requires every empty point to
have a stone neighbour (eye-space, not colonizable interior). Corrected census:
minimal decided terminal = 10 stones. Full write-up:
`docs/research/terminal-territory-bug.md`. Leaf values are now trustworthy in
principle; still validate at scale before persisting them. (Persisting DAG
*structure* — positions + legal moves — was always safe.)

## Strategy fork — DECIDED 2026-07-16: goal (b), compressed perfect oracle (ADR-0007)

The goal is now fixed: **build a compressed perfect oracle** — the value of every
reachable (position, side) — not just prove the number. Consequences (ADR-0007):
- **Alpha-beta/PN is out of scope** (goal-(a) only; returns bounds + prunes
  subtrees, cannot populate an oracle). Former TODO #6 is scrapped.
- **Engine = retrograde / layered fixpoint** (captures = back-edges → fixpoint,
  not one sweep). Current exhaustive forward minimax + exact-value TT in
  `solve.zig` is the slow reference / cross-check until retrograde exists.
- **`persist.zig` to be PORTED** to `solve.Table` (oracle needs checkpointing) —
  resolves the #2 sub-decision.
- **Eye-prune (ADR-0006) vs full coverage is an OPEN tension** — resolve before
  persisting values.
- Data model: combinatorial ranking / minimal-perfect-hash. Oracle is over
  POSITIONS, not paths.

Next engine work needs its own design ADR (#6' in TODO) before coding.

## After that: reach the full-board oracle (scaling)

Once the terminal test is sound, the remaining wall is scale: the empty-board
full solve (= Black+25) does not yet complete. See `docs/decisions/0006` and
`docs/TODO.md`. Concretely:
1. **Line length / recursion depth.** Positional-superko lines can be long and
   recursion depth == line length. `MAX_LINE` was raised 2048→4096 as headroom;
   a first empty-board run ran minutes at ~320 MB RSS without finishing and was
   stopped. Find a real 5×5 line bound and make the depth stack-safe. (`solve`
   is kept free of diagnostics — add measurement deliberately when needed, the
   way `src/ko_probe.zig` and `src/measure.zig` are standalone.)
2. **seq-table sizing** for a full run — needs measured `collision_size` for
   9–16 stones (the long-standing ADR-0005 open question).
3. Raw tree size / time.

These are scaling problems, not correctness gaps.

## What's done (committed on `inverse-player`)

- Zig 0.16 port; branch cleanup; `seq` widened u8→u16 (8→16 stone ceiling).
- `src/persist.zig` — disk checkpoint (delta+varint codec).
- `src/measure.zig` — plan-A instrumentation (`zig run -O ReleaseFast
  src/measure.zig`), clean to depth 6 (old minimax path).
- `src/terminal.zig` — Benson `pass_alive` + `area_score` + `is_settled` (pure).
- `src/superko.zig` — positional superko `History`; `repeatsIndex` returns the
  matched ply (for GHI); `max_len` diagnostic; `MAX_LINE = 4096`.
- `src/solve.zig` — **the correct search** (ADR-0005 + 0006):
  - search-to-terminal, area scoring, value = Black-perspective − komi;
  - positional superko; Benson/double-pass terminal;
  - **transposition table** `Table` — `(blind,seq)`+side key via
    `state.lowest_blind_from_pos`, `num_stones ≤ 16` cutoff, `passes == 0`-only
    caching, `block_size(n) = 2^(n-1)`, seq index 0 reserved;
  - **GHI**: `solve` returns `{value, ko_ref}`; caches iff `ko_ref ≥ d`;
  - **eye-prune** (`is_own_eye`): a mover may not fill its own Benson-alive
    eyes — REQUIRED for tractability (ADR-0006).
  - Validated: TT machinery unit tests; `dead_white` → Black+25 both sides,
    colour symmetry, TT == no-TT. Full suite green.

`minimax.zig` + `measure.zig` (old depth-limited path) were RETIRED 2026-07-16
(#2, commit b1b6cea). `persist.zig` was ported onto `solve.Table` and kept (the
oracle needs checkpointing). `zobrist.zig` remains standalone for future hashing
/ data-model work.

## Build / test / run

- Build: `zig build`   ·   Full suite: `zig build test`
- Per module (reliable): `zig test src/<file>.zig`
- Measurement: `zig run -O ReleaseFast src/measure.zig`
- `main.zig`'s test block imports every module so `zig build test` covers all.

## Gotchas (learned the hard way)

- **dyld/env quirk**: large *test* binaries (multiple 2^25 tables) sometimes
  abort at launch (`dyld … shared region … macOS 26.5.2 newer than running OS`).
  `zig run` and per-module `zig test` on small binaries work fine. Keep new test
  modules dependency-light (don't import `zobrist.zig`'s huge tables).
  STATUS 2026-07-17: INTERMITTENT — `zig build test` sometimes fails at harness
  launch (`--listen=-`) and passes on rerun; the same binary run DIRECTLY always
  passes (73/73). Do not chase "failed command …/test" as a test failure:
  re-run, or run the binary directly, or use per-module `zig test` (always
  reliable). Real fix = TODO #5 per-module build test steps.
- **The "black white symmetry" bug (commit 39dbe4a) is really repetition +
  horizon**, not symmetry. See `docs/research/transposition-bug-root-cause.md`.
- **No sub-board solving**: restricting moves to a region of the 25-array is
  unsound (edge stones keep phantom liberties). `solve` is full-board only.
- **Self-eye-fill reopens the board** (the Phase-2 tractability lesson): the DFS
  will fill a live group's own eyes → group captured → near-empty board →
  intractable. Fixed by `solve.is_own_eye` pruning (ADR-0006). Do not remove it.
- **`std.debug.assert` is a no-op in `-O ReleaseFast`**: `MAX_LINE` / TT-bounds
  overflow silently corrupts there. Run correctness checks in Debug.
- **index-0 sentinel bug** (open, Housekeeping): `seq_next_empty_index` starts
  at 0 which also means "unset" → first-stored block orphaned. Reserve index 0.
- `collision_size(9..16)` are 2^(n-1) worst-case placeholders; measure before
  deep runs.

## Git state (2026-07-15)

- Branch `inverse-player`; base was `39dbe4a`.
- **origin is at `42d1ebf`; several commits are UNPUSHED** through
  `405806a "Phase 2: transposition table + GHI + eye-prune in solve.zig"`
  (terminal, superko, ADR-0005, solve Phase 1, HANDOVER, Phase 2). User handles
  pushing.
- Remotes: `inverse-player` + `main` only (other branches pruned).

## Glossary

`docs/GLOSSARY.md` — abbreviations + Go / algorithm / weizigo-code terms
(TT, GHI, PSK, CGT, ADR, blind/seq/view/lowest, is_settled, eye-prune, ko_ref,
…) and the small-board result table.

## Doc map

- `docs/TODO.md` — task backlog with status marks.
- `docs/decisions/0001..0009` — ADRs (0005 = the forward search design; 0007 =
  goal is a compressed oracle; 0008 = fresh-start semantics; **0009 = the
  retrograde engine: L/H value iteration, the current engine**).
- `docs/research/retrograde-3x3.md` — the retrograde measurements (7 findings:
  fast convergence, cross-root memo hazard, exact-solving intractable, residue
  shrinks with size, 2x2 fully solved, opening-residue frontier, certified-yet-
  forward-intractable).
- `docs/research/` — Go rules & ko/scoring, GHI + superko, the transposition-bug
  root cause, **the `is_settled` terminal-territory bug (terminal-territory-bug.md,
  current top priority)**, **strategy-open-questions.md (the strategy fork)**,
  data-model + measurements, and `ko-examples.md` (engine-verified replayable
  superko/simple-ko games; superko is empirically abundant on 5x5).
- `src/settled_census.zig` — tool: per-stone-count census of settled positions
  (currently counts the buggy `is_settled`; re-run after the fix).
- `src/ko_probe.zig` — self-contained tool (its own legal-play walker; no solver
  coupling) that measures ko vs superko frequency and dumps replayable examples
  (`zig build-exe -O ReleaseFast src/ko_probe.zig` then run, stderr →
  `docs/research/ko-examples.md`).
