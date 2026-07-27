# Arena: adversarial self-play audit of the oracle player (2026-07-22)

Instrument: `src/arena.zig` (user-designed methodology). One AUDITED player
plays fresh-start-optimally but picks RANDOMLY among score-optimal moves
(alternative winning lines, not just the fastest); the opponent plays a
seeded mix — 60% optimal / 25% winning-but-suboptimal / 15% anything-legal
(human-realistic errors). Colours, seeds, and handicaps (0/1/2 pre-placed
Black stones) all vary.

THE AUDIT: at every position where the audited player is to move, the
stored fresh-start score is a PROMISE. A game where the final score falls
short of the strongest promise anywhere in its history is a LEAK. Every
leaked game is emitted as a replayable move list for the history-exact
probes (`RETRO_REPLAY` / `RETRO_VERIFY` in retro.zig).

## First run: 4x4, 50 seeds x 2 colours x 3 handicaps = 300 games

    games=300  capped=0  audited-won=215  held-exact=232
    LEAKS=25 (8.3%), max 32 pts
    DIVERGED: 112 games (37%), 167 events

- **8.3% of adversarial games leak score** — the fresh-start player's
  exploitability is not a corner case. Max observed leak: 32 points
  (promise W+16, final B+16 — the same full-board swing class as the
  human-discovered "B+16 game", research/retrograde-4x4.md).
- **37% of games contain a DIVERGED event** (the best achievable child
  score differs from the audited player's own stored position score —
  the moment the table's promise becomes unkeepable under this game's
  superko bans). Most diverged games do NOT leak (the tangle often
  resolves favourably anyway).
- **Leaks WITHOUT any diverged event exist** (e.g. seed 42): score
  evaporated through a chain of moves each of which looked
  score-preserving by stored numbers. Fresh-start scores along a real
  history are mutually inconsistent — a deeper GHI signature than the
  single-blunder case, and the strongest argument yet for the
  history-perfect player.

## Doctrine: optimizations and assumptions must be CONDITIONAL

(user requirement, 2026-07-22) Every optimization/assumption needs a
switch, so the fast path can be compared against the tried-and-true slow
alternative — which decides where each is honoured, rejected, or scoped.
Current switchboard:

| assumption / optimization | toggle | slow alternative |
|---|---|---|
| eye-prune (ADR-0006) | `retro.apply_eye_prune` (comptime) | full move set (retrograde graph already uses it) |
| bracket cuts + certified seeds (ADR-0010) | `finish(bracketed:)`, plain path kept | `O.value_from_root` plain minimax |
| exact memo | `O.Ctx.memo` | memo-free search |
| bounds memo | `O.Ctx.lbb..` nullable | exact-memo-only |
| whole fast stack | `RETRO_PLAIN`, `RETRO_VERIFY` | assumption-free `O.solve(memo=false)` |

CAVEAT measured 2026-07-22: the assumption-free alternative is often
INTRACTABLE (juncture 11 of the B+16 game exceeded 4e9 nodes) — Finding 3/7
all over. So conditional comparison works on the tractable subset, and the
arena covers the rest statistically. OPEN: the replay probe exposed an
internal inconsistency (ply-10 score -1 vs ply-11 best-child +1 on the same
position+history) — certified-seed/bracket validity under NONEMPTY prefixes
is now a live question, distinct from the oracle's fresh-start soundness
(fresh roots: exhaustively ground-truthed at 2x2/3x2). Adjudication pending
where tractable.

## Persona sweep (2026-07-22, 100 seeds x 2 colours x 3 handicaps x 6 personas = 3,600 games)

Opponent personas (user-specified): strictly optimal; winning-any (random
among win-keeping moves); winning-slop (win-keeping but NEVER the optimal
move — the pure margin-leaker); dan 90/8/2; kyu 60/25/15; novice 30/40/30
(percent optimal/winning/any).

| opponent persona | leaks/600 | max leak | diverged games/events | audited won |
|---|---|---|---|---|
| optimal      | 95 (15.8%) | 32 | 143/205 | 299 |
| winning-any  | 109 (18.2%) | 32 | 214/360 | 362 |
| winning-slop | 100 (16.7%) | 25 | 226/467 | 405 |
| dan          | 77 (12.8%) | 32 | 152/216 | 327 |
| kyu          | 61 (10.2%) | 32 | 211/288 | 433 |
| novice       | 44 (7.3%)  | 32 | 201/293 | 520 |

**The stronger the opponent, the more the fresh-start player leaks** —
strong opponents steer into the precise ko tangles where fresh-start scores
poison; weak opponents stumble back out of them. Against a strictly optimal
opponent the belief system fails its promise in ~16% of games. This inverts
the intuition that a perfect-table player is most at risk against tricky
weak play: it is most at risk against STRENGTH.

AUDIT SEMANTICS (clarified after review): this is a BELIEF audit, not a
policy audit. The audited player picks randomly among believed-optimal
moves; if the stored scores were true in-game scores, ANY such move
preserves the promise, so randomization cannot cause a leak — every leak
proves that a move the table called optimal was history-poisoned. The
randomization only widens coverage of that claim. (A deterministic
deployed-policy audit — min-DTT tie-break — is a separate, weaker mode.)

## Next

1. HISTORY-PERFECT player (live history-aware solve per move) — measured
   cheap at 4x4; would eliminate the leak class by construction. Its arena
   leak count must be ZERO; that is the acceptance test.
2. Adjudicate the prefix-soundness question on tractable junctures; if the
   leak is real, certified-seed reuse under prefixes needs a Kishimoto-
   Muller-style dependency guard (the documented fallback).
3. Scale the arena run (1000+ seeds), add 3x3/2x2 sweeps (cheap, and their
   scores are exhaustively ground-truthed — any leak there is maximally
   diagnostic).

## Contradiction localized (2026-07-22, RETRO_CONTRA complete)

The toggle matrix on the P10 inconsistency (direct score vs max-over-children,
same position, same 10-move prefix):

    brackets=ON  seeds=ON : A=-1  child-max=+1 (D2)   INCONSISTENT
    brackets=ON  seeds=OFF: A=-1  child-max=+1 (D2)   INCONSISTENT
    brackets=OFF seeds=ON : A=-1  child-max=+1 (D2)   INCONSISTENT
    brackets=OFF seeds=OFF: A=budget(>3e9)  child-max=+1 (C1, 6e9 nodes)

VERDICT by elimination + compositionality: a maximizer's score cannot be
below its best child, so the DIRECT evaluations (A=-1) are the corrupted
ones, in every configuration that completed. Brackets and certified seeds
are exonerated as sole causes; the mechanism present in all affected runs is
CROSS-BRANCH MEMO REUSE under the ko_ref guard — entries cached in one
child's subtree poison a sibling's subtree when a game prefix is loaded.
This is the classic graph-history-interaction (GHI) unsoundness; the ko_ref
discipline is a heuristic guard, valid empirically at fresh roots
(exhaustive 2x2/3x2 ground truth), now DISPROVEN under prefixes.

Consequences:
1. The history-perfect genmove requires a DEPENDENCY-GUARDED memo
   (Kishimoto-Muller): each entry records the positions its score depends
   on; reuse only where the current path cannot invalidate it. Brackets and
   certified seeds may be re-admitted on top only after passing this same
   toggle-matrix test.
2. All prefix-based probe numbers (the replay tables) are TAINTED at
   ko-tangled junctures and must be recomputed after the fix. The coarse
   three-error story of the B+16 game (C4, D4, C1) is corroborated by
   multiple configurations but not yet certified.
3. Fresh-root oracle scores are NOT implicated (empirically validated at
   2x2/3x2 exhaustively; 4x4 anchor matches published) — but the same
   theoretical hole exists there, so a 4x4 deep spot-check pass and/or a
   KM-guarded finisher rerun is now a prioritized validation item.

## Cross-board sweeps (2026-07-22): leaks everywhere, and the decisive control

3,600 games per board (100 seeds x 2 colours x 3 handicaps x 6 personas),
leak rate range across personas:

    2x2: 14-17% of games leak (max 2 pts)   <- table PROVEN correct
    3x2: 39-46% of games leak (max 12 pts)  <- table PROVEN correct
    3x3:  6-14% of games leak (max 18 pts)
    4x4:  7-18% of games leak (max 32 pts)

THE CONTROL: the 2x2 and 3x2 tables are exhaustively verified against the
assumption-free ban-set-keyed Exact solver (0 mismatches on every slot) —
their fresh-start scores are CORRECT beyond doubt. Yet the fresh-start
PLAYER leaks there most of all (3x2: nearly half of adversarial games).
Conclusion: the leak class is entirely the player's history-blindness, not
table error. Tiny boards are ko machines (ko-sensitive region 72%/39%), so fresh-start
play is most wrong exactly where history matters most.

Timeline honesty: none of this needed a human to be DISCOVERABLE — the
arena finds it in seconds at every board size. It needed a human to think
of PLAYING ADVERSARIALLY at all: before the B+16 game, validation was
static (symmetry, brackets, anchors, ground truth) plus one deterministic
self-play line, which cannot diverge because both sides follow the same
book down its own principal variation. The permanent lesson, now
infrastructure: every claim about a PLAYER (not a table) must be tested by
adversarial play, and "self-play smoke test" is not adversarial.

## THREE-WAY finisher disagreement (2026-07-23) — correctness crisis, honestly logged

Regenerating small artifacts (pilot gate) exposed that the current finisher
disagrees with the committed artifacts. Adjudication made it WORSE, not
better: three methods give three different scores for the empty 3x2 board
(idx 0, fresh-start):

    old      (aspiration exact-memo finisher)     : +1
    new      (MTD + bounds memo finisher)         : -2
    writes-off (bracket-guided, cross-branch      :  0
                memo writes disabled)

62 of 378 ko-sensitive region (slot,side) pairs differ between writes-off and old.
CONCLUSION we can and cannot draw:
- We CAN conclude the finisher-produced KO-SENSITIVE is unreliable across
  generations — at least two of the three methods are wrong on these slots,
  and possibly all three.
- We CANNOT yet name the true score. The "writes-off" judge removes the
  convicted cross-branch memo reuse but still ASSUMES the L/H brackets and
  the certified seeds are sound and that its own search logic is correct —
  none of those is proven; it is the least-assumption-laden of the three,
  not an oracle.
- The ONLY assumption-free judge is Exact(w,h) (ban-set-keyed, sound by
  construction). It is intractable on the empty board (Finding 3) but IS
  tractable on near-terminal disputed slots (high stone count). Those are
  the footholds: adjudicate every Exact-reachable disputed slot, see which
  method (if any) it matches.

Scope of the doubt (unchanged): the fresh-start single-score region (L==H)
is not in dispute here — every disputed slot is KO_SENSITIVE ko-sensitive
region. But the ko-sensitive region is 21-49% of every board and includes
the opening, so "the oracle is correct on its fresh-start single-score
region" is true and "the published 3x2/3x3/4x4 artifacts are
fully correct" is NOT currently established.

This is the honest state: the two-sided L/H CERTIFICATION is trustworthy;
the FINISHER (every generation of it) is under a cloud; the fix is the
dependency-guarded memo (Kishimoto-Muller), and the acceptance test is
agreement with Exact on every Exact-reachable slot at 2x2/3x2 plus the
pilot-gate byte-identity thereafter.

## Foothold adjudication is STRUCTURALLY DEFEATED (2026-07-23)

Attempted #1 (assumption-minimal external adjudication of the disputed
ko-sensitive region) on both boards. Both failed to produce a SINGLE foothold:
- 3x2: Exact (ban-set-keyed), most-filled disputed slots, 2e9 then 3e8
  node budget — 0 reached (~2 h).
- 4x4: Exact is memory-dead (5.38 MB per ban-set key = 3^16 bits); judge =
  O.solve memo=OFF (minimax + real superko history + eye-prune, no
  cross-branch cache, memory-safe). Most-filled ko-sensitive region, 1.5e9 budget,
  ~6.5 h — 0 footholds reached.

WHY (structural, not tuning): the disputed slots ARE the ko-sensitive
ko-sensitive region, and those are exactly the positions where a capture REOPENS the
board mid-search (Finding 7), exploding any un-memoized or ban-set-memoized
solve. Exact memoization is the only thing that could tame it, and its key
(the full superko ban-set) is what makes it intractable — the graph-history-
interaction cost IS the whole cost (Finding 3, restated). This is
board-size-independent: it defeated 3x2 (a ko machine) AND 4x4 (a square
target) identically.

CONCLUSION — reframes the correctness strategy:
- We CANNOT prove the ko-tangled ko-sensitive region correct by EXTERNAL CHECK against a
  brute oracle; that is intractable by the same mechanism the whole project
  exists to circumvent. No current check (Exact-reachable slots, brackets,
  symmetry, bracket-containment) DISCRIMINATES old vs new — they agree on
  the fresh-start single-score region and are silent on the ko-sensitive region.
- Therefore ko-sensitive region correctness must come BY CONSTRUCTION: a provably-sound
  finisher (Kishimoto-Muller dependency-guarded memo — a published,
  proven-correct GHI method), whose trust rests on the ALGORITHM, validated
  by determinism (pilot gate), bracket containment, exhaustive symmetry, and
  agreement with Exact on the reachable (non-ko-sensitive region) slots — NOT on
  adjudicating individual disputed slots.
- Honest status: which of old/new is right on the disputed ko-sensitive region is
  currently UNDECIDABLE by any tractable external means. Only a from-scratch
  provably-sound recompute settles it. #1 is exhausted.
