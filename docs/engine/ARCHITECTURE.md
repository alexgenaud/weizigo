# weizigo architecture

Updated 2026-07-20. ~6,200 lines of Zig across 16 modules, in TWO GENERATIONS
plus tools, presentation, and a documentation system. Goal (ADR-0007): a
compressed perfect oracle — the exact score of every legal (position, side) —
for 5x5, then 6x6, aiming at 7x7.

> **⚠ ERRATUM — the goal above predates the 2026-07 crisis and is not the
> current target.** Added 2026-07-29 by the Orchestrator (Opus 5); the
> `EVIDENCE-INTEGRITY` pass reported this banner as placed but it had not been.
>
> "A compressed perfect oracle … for 5x5, then 6x6, aiming at 7x7" assumes the
> **PSK fresh-start representation**, which is now known **not** to produce
> real-game scores: `GLOBAL.C2` is falsified at 3×2 (T13) and `GLOBAL.C3` at 3×3
> (E2), so the table is a *fresh-start* score table and neither equals nor
> bounds the real-game PSK score. The bracket premise is orphaned
> (`GLOBAL.F2` / `QA-018`, ADR-0015/0017/0018). PSK exact-solve is intractable
> anyway (ADR-0013).
>
> **No 5x5 work begins until a working representation is demonstrated at 4x4.**
> The live target is ADR-0019: exact solving under **basic ko + a fixed-value
> long-cycle verdict**, with a *measured* divergence from PSK — and as of
> 2026-07-29 the value rule that was to compute it (`V = median(L, TIE, H)`) is
> **FALSE-AS-SCOPED at 3×2**, so a replacement is required before any build.
> Current position: `docs/status/CURRENT.md`, `docs/epistemic/PROGRESS.md`,
> `docs/epistemic/knowledge-ladder.md` (which rung each claim actually sits on).
>
> The 5x5 density folds and projections in §§ below are historical arithmetic,
> not a plan. `ADR-0012` carries its own erratum.

> **Canonical names.** The table is the **position-to-score table** (artifact
> format `.wzo`); the table entries are **scores** (game-theoretic area scores, Black-
> positive, komi 0). Where L==H: **fresh-start single-score region**; where L<H:
> **ko-sensitive region** (bracketed [L,H]). Deprecated synonyms: "certified
> core" and "ko-sensitive region". See `../epistemic/names.md` for the canonical-name register.

## The two generations

### Generation 1 — the 5x5-hardcoded stack (validated reference)

Fixed `[25]i8` boards; sign = colour, magnitude = army flag. This stack is the
project's PROVEN core: it found and fixed the terminal-territory bug, carries
the ko/GHI machinery, and now serves as the ground-truth reference the generic
stack is cross-validated against.

| module | lines | concern |
|---|---|---|
| `state.zig` | 1290 | board representation & move application (army flags), symmetries (`lowest_blind_from_pos` = canonical form), encodings: `blind` (25-bit occupancy), `seq` (colour bits), `view` (u40 base-3) |
| `terminal.zig` | 458 | scoring & life: `area_score` (Chinese), `benson_alive` (Benson), `is_settled` (decided-terminal incl. eye-space rule) |
| `superko.zig` | 255 | positional-superko `History` (game-line stack, `repeatsIndex` for GHI, `max_len` diagnostic, always-live MAX_LINE panic) |
| `solve.zig` | 438 | THE validated forward search: to-terminal minimax + superko + Benson/double-pass terminals + `ko_ref` GHI caching rule + ADR-0006 eye-prune + `(blind,seq)` transposition table |
| `persist.zig` | 420 | disk checkpoint codec (delta+varint record stream) for the TT / future score tables; ported off the retired old path onto `solve.Table` |
| `zobrist.zig` | 216 | standalone hashing tables (kept for future data-model work; imported only by the test aggregate — huge tables, the dyld gotcha) |
| `util.zig` | 8 | `UNDEF` sentinel, `println` |

Retired (ADR-0007, commit b1b6cea): `minimax.zig` (old depth-limited search),
`measure.zig` (its instrumentation).

### Generation 2 — the board-size-generic oracle stack (comptime w x h)

Everything parameterized `(comptime w, comptime h)`; pure sign domain (no army
flags); each module standalone/dependency-light (per-module `zig test` always
works). This is where the oracle is being built.

| module | lines | concern |
|---|---|---|
| `rules.zig` | 547 | THE RULES KERNEL: move/capture/suicide, area score, Benson, settled, eye-prune predicate. Cross-validated vs Gen-1 (500 random boards vs terminal.zig, 1000 random moves vs state.zig — exact match). Also hosts the Benson THEOREM check (exhaustive adversarial falsification at 3x3) |
| `enumerate.zig` | 317 | STRUCTURE census: legality + canonical-representative tests, exhaustive per-layer counts. Validated against Tromp/OEIS published counts (1x1..4x4 all PASS) |
| `colex.zig` | 264 | THE ADDRESS SYSTEM: `colex_from_pos` / `pos_from_colex`, a collision-free bijection boards <-> 0..3^n-1, layered by stone count. Exhaustively verified bijective through 4x4. The layout is the future on-disk FORMAT CONTRACT |
| `oracle.zig` | 392 | forward oracle builder (fresh-start score; measured INTRACTABLE to build cold) + validation battery. Now the RETROGRADE ENGINE'S FINISHER and cross-check: `retro.zig` reuses its `Oracle().solve` for the certified-seeded ko ko-sensitive region and forward spot checks |
| `retro.zig` | ~1000 | **THE RETROGRADE ENGINE (ADR-0009)**: successor-sweep value iteration (forward move generator only — no un-capture) with two-sided (L/H) fixpoint certification for ko/GHI, the certified-seeded FINISHER for the ko-sensitive region, DTT, and the full battery. Hosts `Retro(w,h)` (the engine) and `Exact(w,h)` (ban-set-keyed history-exact gold-standard forward solver). Converges 2/6/12 sweeps at 2x2/3x2/3x3 |
| `artifact.zig` | ~300 | **THE ORACLE ARTIFACT (ADR-0011, WZO1)**: dense colex-addressed on-disk oracle — header versions the format AND `colex.layout_version` (the format contract), payload = the six frozen schema columns (vb/vw/fb/fw/db/dw), CRC-checked. Distinct from `persist.zig` (the TT *checkpoint*); this file IS the product. First real artifacts: `artifacts/oracle-{2x2,3x2,3x3}.wzo` |
| `sgf.zig` | 124 | PRESENTATION BRIDGE: writes SGF; all visualization delegated to external tools (Sabaki etc.). No GUI code in this repo, ever |

### Tools (standalone measurement programs, `zig run` / `zig build-exe`)

| module | concern |
|---|---|
| `ko_probe.zig` | measures ko vs superko frequency; dumps replayable example games (fed `../research/ko-examples.md`) |
| `settled_census.zig` | census of settled (decided) positions per stone count |
| `main.zig` | solve driver (ReleaseSafe, big-stack thread, `FULL` flag) + the `zig build test` aggregate importing every module's tests |

## Separation of concerns (the layer cake)

    docs/               WHY: ADRs (decisions/), findings (research/), GLOSSARY,
                        status/HANDOVER (session continuity)
    ------------------------------------------------------------------
    sgf.zig             PRESENTATION: export only; render externally
    ------------------------------------------------------------------
    (planned) QUERIES:  goal-bounded local solver (capture/life/immortal/
                        sente predicates), fact-diff WHY explanations,
                        principle mining, GTP server -- see
                        research/query-engine-and-explanations.md
    ------------------------------------------------------------------
    retro.zig           ENGINES: score computation. retrograde (retro.zig,
    oracle.zig          ADR-0009) is the oracle builder; forward (oracle.zig,
    solve.zig           solve.zig) is its finisher + cross-check. Own
    superko.zig         search-only concepts: history, GHI/ko_ref + L/H
                        certification, eye-prune application, memo
    ------------------------------------------------------------------
    colex.zig           ADDRESSING/DATA: position <-> dense index (the
    artifact.zig        format contract, versioned as colex.layout_version);
    persist.zig         oracle artifact (WZO1) + TT checkpoint (WZG1) codecs
    enumerate.zig       structure census (legality/canonical counts)
    ------------------------------------------------------------------
    rules.zig (gen 2)   RULES KERNEL: what Go IS — moves, captures, scoring,
    state.zig,          life (Benson), terminal. No search concepts here
    terminal.zig (gen 1)
    ------------------------------------------------------------------
    util.zig            sentinels

Dependency direction is strictly downward. The rules kernel knows nothing of
search; engines know nothing of presentation; the address system is pure
arithmetic. Gen-1 and Gen-2 touch only in cross-validation TESTS.

## Validation doctrine (three distinct levels)

1. **Implementation vs spec**: cross-validation between generations (random
   boards/moves must agree exactly); exhaustive bijection checks (colex).
2. **Spec vs the game (THEORY tests)**: falsify the theorem itself against the
   bare rules (Benson attack-exhaustion at 3x3); published external anchors
   (Tromp position counts; 3x3 = B+9 centre / +3 side / -9 corner; 5x5 = B+25).
3. **Engine vs engine**: forward and retrograde must agree — two algorithms,
   different failure modes, mutual proof (the plan for the oracle table).

CAVEAT (recorded): 3x3-exhaustive results validate implementations and theory
*at that scale*; game scores and tractability do NOT generalize upward — each
board size is its own wall, measured separately.

## Where the frontier is

The retrograde engine EXISTS (ADR-0009, `retro.zig`): value iteration fills
the colex space in a handful of sweeps where forward filling was intractable,
with ko handled structurally by L/H certification and a bounded finisher for
the ko-sensitive region. Coverage is total (no eye-prune in the graph). Validated at
2x2/3x2/3x3 (`../research/retrograde-3x3.md`).

The frontier moved to SCALE and COMPLETION:
1. ~~Full 3x3 finisher~~ DONE (ADR-0010 bracket-guided alpha-beta: all 622
   ko-sensitive orbit reps in ~156k nodes; anchors PIN). ~~Persist the first
   artifact~~ DONE (ADR-0011, `artifact.zig`, WZO1 header versioning
   `colex.layout_version`; `artifacts/oracle-{2x2,3x2,3x3}.wzo`).
2. 4x4 (43M slots in RAM) — measure sweep-count + ko-sensitive region-fraction growth +
   bracketed-finisher nodes/root (the 5x5 projection numbers).
3. 5x5: density folds (legality ~2x, canonical ~16x → ~26 GB; a LAYOUT change
   -> bump `colex.layout_version`) + disk-streamed sweeps over the contiguous
   colex layer blocks; then 6x6.

The residual THEORETICAL risk is the `L==H ⇒ exact` certification claim
(strong structural evidence, not a theorem — ADR-0009's honesty clause);
`retro.Exact` (ban-set-keyed, sound by construction) is the empirical check,
exhaustive where it is reachable.
