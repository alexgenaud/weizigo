# 4x4 scale run: the oracle COMPLETES (2026-07-21)

The first 4x4 run of the retrograde engine (ADR-0009/0010/0011), and the run
that forced + validated two engine upgrades (checkpointed deepest-first
finishing; MTD null-window probing with a per-root bounds memo). End state:
**the complete, validated 4x4 oracle** — every legal (position, side) exact —
persisted as `data/oracle-4x4.wzo` (258,280,358 bytes, gitignored; checkpoint
twin alongside). Reproduce: `RETRO_4X4=1 zig run -O ReleaseFast src/retro.zig`
(~19 min wall total on the dev machine; the build is deterministic, so the
regenerated file should hash identically):

    sha256(data/oracle-4x4.wzo) =
    b42c3371db9c800c6a76fc29b842e8be6f8b0af35731f5a88e2ba24b5551655f

## The scaling numbers (the 5x5 projection data)

| quantity | 2x2 | 3x2 | 3x3 | 4x4 |
|---|---|---|---|---|
| slots (3^n) | 81 | 729 | 19,683 | 43,046,721 |
| legal/side | 57 | 489 | 12,675 | 24,318,165 |
| sweeps to fixpoint | 2 | 6 | 12 | 19 |
| residue fraction | 72% | 39% | 34% | **21.3%** |
| residue orbit reps (B+W) | 9 | 57 | 622 | 649,517 |
| finisher nodes total | 6,033 | 29,482 | 78,595 | 1,080,118,252 |
| finisher wall | 1 ms | 2 ms | 12 ms | 367 s |
| build wall | <1 ms | 1 ms | ~130 ms | ~495 s |

- legal/side = 24,318,165 matches Tromp's published L(4x4) EXACTLY (free
  external validation of the generic rules kernel at this size).
- Sweep growth 2 -> 6 -> 12 -> 19 is strongly sub-linear in slot count; the
  residue fraction keeps FALLING (72 -> 39 -> 34 -> 21.3%). Both trends are
  favourable for 5x5.
- Finisher average: 1,663 nodes/rep at 4x4; max/root 349,349 (1.7% of the
  20M budget). dtt+symmetry pass: 136 s.

## The driver saga: how the finisher was made to survive 4x4

Three root-driver generations, measured on the SAME workload:

| driver | 3x3 nodes (max/root) | 4x4 layer-15 (238 reps) | 4x4 empty root |
|---|---|---|---|
| aspiration (L-1, H+1) | 156,178 (6,378) | 123 solved / 115 SKIPPED | >500M nodes, abandoned (146 s) |
| bare MTD null-window | 315,526 (28,581) | 114 / 124 SKIPPED | — |
| MTD + per-root bounds memo | 78,595 (1,266) | **238 / 0** | **<=349k nodes** |

1. **Aspiration dies where brackets are wide** (the deep-residue ko tangles):
   with a wide window the ADR-0010 bracket cutoffs cannot fire and the search
   degrades to raw minimax. Also, the original shallowest-first root order
   put the most hopeless roots FIRST: two runs burned 4+ hours on ~105
   opening roots before being killed.
2. **Bare MTD is WORSE** (measured, layer 15: 124 vs 115 skips): fail-soft
   probe results may not be stored in the exact memo (exactness discipline),
   so successive probes re-search each other's work — the textbook reason
   MTD(f) requires a transposition table that stores BOUNDS.
3. **MTD + bounds memo wins everywhere**: per-root lb/ub columns per
   (idx, side), ko_ref-clean like the exact memo, reads cut or NARROW the
   window, writes classify against the narrowed entry window (a fail against
   a narrowed window is never stored exact), journal-reverted per root.
   Result: 2x fewer nodes than aspiration at 3x3, and at 4x4 the ENTIRE
   residue — all 649,517 reps including the empty board — solves with ZERO
   budget skips in 6.1 minutes. The empty root went from >5e8 nodes
   (abandoned) to <=3.5e5: over 1,400x on the hardest case.

Operational lessons, also landed in code:
- **Deepest-first layer order** (cheap near-terminal residue first, opening
  tail last) — with per-layer CHECKPOINTS (`saveArtifact(checkpoint_path)`):
  resume skips finished roots (FLAG_FROM_FORWARD) and known budget-skips
  (FLAG_TRIED_SKIP, bit2). Interruption now costs at most one layer.
- **Heartbeat** (`finishProgress`): progress every N reps + every skip logged
  with its layer. The first 4x4 attempt ran 4 hours as a black box; never again.
- The per-root **undo journal** (replacing an O(total) memcpy per root) is
  what made 43M-slot finishing feasible at all.

## Anchors: published 4x4 value MATCHES under positional superko

`empty(B) 4x4 = +2` (dtt 13) — exactly van der Werf & Winands (ICGA 2009,
B+2, central first move; MIGOS II plays basic-ko + long-cycle-ties, weizigo
plays PSK — the 4x4 empty-board value is evidently cycle-rule-insensitive,
unlike 2x2/3x2 where the rulesets diverge by a point; see the ko-rule-variant
section in `retrograde-3x3.md`).

End-to-end smoke test (gtp.zig on the persisted artifact): a perfect
self-play game — 15 plies, double pass, **final_score = B+2** — the play
loop, the artifact, and the published truth agree.

Validation summary (all green): 0 bracket-fails, 0 orbit-clashes, exhaustive
symmetry PASS (inversion + dihedral + L/H-swap + flags over all 43M slots),
0 unfilled legal slots, reload columns byte-identical.

## Open questions carried to 5x5

1. Density folds (legal ~2x, canonical ~8x) + disk-streamed sweeps = the 5x5
   engineering wall (raw 3^25 = 847G slots). Layout change -> bump
   `colex.layout_version` (ADR-0011). The 4x4 trends (19 sweeps, 21.3%
   residue, 1.7k nodes/rep) say the COMPUTE is plausible; the I/O
   architecture is the work.
2. The journal entry encoding requires idx < 2^30 — revisit with the folds.
3. Whether an intermediate 4x5 shakedown run is wanted before 5x5 (it has a
   published anchor, +20, and forces the folds at 1/250th of 5x5 scale).
4. 4x4 value histogram / DTT distribution: derivable offline from the
   artifact (`data/oracle-4x4.wzo`) — no re-solve needed.

## First in-the-wild GHI divergence: the B+16 game (2026-07-22)

A human (Black) beat the fresh-start-perfect oracle White by 16 points on
4x4 — 14 points beyond the game-theoretic +2 — in the first serious live
game. Replaying the game with diagnostics gives the full value trajectory
(Black-positive, stored value read with White to move):

    after B C3, B3, A2:   +2, +2, +2      (Black perfect so far)
    after B C4:           -1              (Black error, -3; White's A3
                                           "self-atari" is the optimal
                                           sacrifice holding -1)
    after B D4:           -16             (Black error, -15: fresh-start
                                           theory says White now wins by 16)
    after B D2:           stored -16, but EVERY legal move yields +16
                          -> engine flag: HISTORY-DIVERGED

The 32-point cliff: White's winning continuation required recreating a
whole-board position this game had already visited — banned by positional
superko (PSK). The stored value is the ADR-0008 FRESH-START value; on
KO_SENSITIVE positions (every early position in this game carried the flag)
the in-game value under the actual ban set can differ arbitrarily. This is
the ADR-0009 honesty clause observed live, at maximum amplitude, in a real
game: the oracle is fresh-start-perfect, not history-perfect.

### The verdict (HISTORY-EXACT replay, `RETRO_REPLAY=1`)

`value_from_line` (MTD probes under the game's ACTUAL history; certified
seeds + bracket cuts + ko_ref, memo reset per juncture) recomputed every
juncture of the game. Fresh-start and history-exact values AGREE at every
ply through 13 — and then:

    ply 13 (after B D2, White to move):  fresh -16, history-exact -16
    ply 14 (after W C1, Black to move):  fresh +16, history-exact +16

**White was never doomed. Given all of Black's actual play, a history-aware
White still wins by 16 as late as ply 13. White's C1 was the game-losing
blunder — a 32-point swing under the real rules.** And the mechanism is the
INVERSE of the naive reading: the winning move was NOT superko-banned; it
merely LOOKED equal-lost, because every legal child's fresh-start value was
+16 — including the truly-winning child, whose fresh value assumes Black may
later use recaptures that this game's history forbids. Fresh-start values
mislead in BOTH directions mid-ko-fight; the engine's HISTORY-DIVERGED flag
fired at exactly this moment but the player had no better number to act on.

Cost of knowing better (measured): the history-exact solves took 65k nodes
at ply 1 and monotonically fewer later (sub-1k from ply 7; 0 nodes where the
bracket is already tight). A HISTORY-PERFECT genmove — live history-exact
solve per move — is therefore trivially affordable at 4x4. Black's C4 and
D4 remain genuine errors under BOTH accountings (+2 -> -1 -> -16).

Consequences:
1. `tools/play_oracle.py` now shows the engine's per-move diagnostics
   (stored vs achievable value, KO_SENSITIVE, HISTORY-DIVERGED) so a human
   opponent sees the gap the moment it opens.
2. The road to a HISTORY-PERFECT player is already paved: at each
   KO_SENSITIVE genmove, run a live certified-seeded forward solve under
   the game's ACTUAL history (the finisher machinery — now cheap with the
   MTD + bounds-memo driver; certified values are history-free memo seeds
   by construction). Candidate follow-up; would also quantify how often
   real games diverge.
3. For engine-vs-engine matches (KataGo audit), fresh-start play is a known
   handicap in long ko fights — record which flavour is playing.
