# Glossary

**Status: living reference. [Current.]**

Terms used across this project's code and docs. Three audiences: Go players,
software engineers, and LLM agents. Organized by domain.

> **Plain-English principle (for agents).** Prefer widely-understood plain
> English over cryptic shorthand. If a short term is needed for a complex idea,
> define it here. Terms invented in this project (not standard terms of art)
> are marked **[project term]** with their plain-English expansion and an
> explicit note that they are project jargon. Terms that ARE standard in some
> field cite that field. When unsure whether a term is standard, say so rather
> than treating it as self-evident.

---

## Go rules and scoring

- **area scoring (Chinese)** — your score = your stones on the goban + empty
  points your stones surround. This project's canonical scoring. Komi applied by
  the caller. Compare *territory scoring*.
- **territory scoring (Japanese)** — your score = surrounded empty points +
  captured prisoners. Needs capture tracking; not used for solving here. Usually
  agrees with area scoring within ~1 point.
- **komi** — points added to White's score to offset Black's first-move
  advantage. This project uses komi 0; the empty-goban score IS the fair komi.
- **Black-positive** — this project's sign convention: scores are always written
  from Black's point of view. +2 = Black ends 2 ahead; −2 = White ends 2 ahead.
  Side-to-move selects which array slot (vb/vw) to read, never the sign.
- **annihilation** — optimal play in which one color ends up owning the entire
  goban (5x5 = Black +25). From 6x6 up, both colors survive.

## Repetition and ko (the central difficulty)

- **ko** — the single-move repetition ban: after a capture, you may not
  immediately recapture if doing so recreates the position one ply ago.
- **basic ko / simple ko** — ko only (the one-ply ban above), with NO broader
  superko restriction. Japan/Korea pro rules; long cycles (triple ko, eternal
  life) lead to *no result* and the game is replayed. The leading tractable
  *generation* rule candidate (see `../research/ruleset-options.md`).
- **PSK — positional superko** — no whole-goban *position* may ever repeat in a
  game. AGA/New Zealand/Tromp-Taylor/computer rule. This project's historical
  solving rule (`superko.zig`); **abandoned as the generation target** because
  exact-solve is intractable even on the empty 2x2. Kept for play-time legality.
- **SSK — situational superko** — no (position, side-to-move) pair may repeat.
  Stricter than PSK (distinguishes whose turn it is). A play-time option; never
  used for generation here. (KataGo supports {SIMPLE, POSITIONAL, SITUATIONAL}.)
  Used by real rulesets: **AGA** and **New Zealand** (situational/positional).
  Tromp–Taylor/PSK is the machine-to-machine convention; Japan and Korea use
  **no superko at all** (`../research/ruleset-options.md:9-20`).
- **superko** — generic term for "no goban state may repeat" rules (PSK/SSK).
- **triple ko / eternal life** — longer repetition cycles (3+ positions) that
  basic ko does not forbid. Under basic-ko rules these are *no result*; under
  superko they are illegal. The source of the *ko-sensitive region* difficulty.
- **no result** — (Japanese rules) a game that cannot finish due to a long
  cycle; voided and replayed. The basic-ko alternative to superko's "illegal."
- **long-cycle tie / no result (Japanese *mushōbu*)** — the two traditional ways
  to terminate a repetition longer than a basic ko. Japanese/Korean practice:
  **no result** — the game is void and replayed (entry above). MIGOS II and
  solvers generally: a **tie**, a fixed value, because "replay the game" is not
  a value a table can hold. Design consequence: a tie is not an area score —
  with komi 0 the area score on an odd-point goban is always odd, so at 3x3 a
  tie of 0 lies outside the natural value set, and the value domain becomes
  `ℤ ∪ {tie}` with the tie ordered between −1 and +1 (`roadmap-2026-07-28.md`
  §2). Contrast **score-on-cycle** (`../research/ruleset-options.md`), which
  scores the cycle by area *at the repeated goban* and is therefore
  path-dependent — foreclosed as being exactly as intractable as PSK.
- **MIGOS / MIGOS II** — **a program, not a ruleset**; project documents and
  agent messages have used "MIGOS II" as if it named a ruleset, and that is
  wrong. MIGOS = "MIni GO Solver", Erik van der Werf's small-goban solver;
  MIGOS II is the version behind van der Werf & Winands, *Solving Go for
  Rectangular Gobans*, ICGA Journal 2009 — the source of every published anchor
  this project cites (3x3 = +9, 4x4 = +2, 5x5 = +25). Its **ruleset** is area
  (Chinese) scoring + **basic ko only** ("since superko is not used") +
  balanced long-cycle repetition scored as a **long-cycle tie**
  (`../research/retrograde-3x3.md:224-245`). Consequence the project keeps
  forgetting: weizigo plays PSK, so weizigo and the anchors are **different
  games** — they agree at 3x3 and 4x4 and provably **disagree** at 2x2 and 2x3
  (published 0 and 0 vs weizigo's ground-truthed +1 and +1).

## Go life-and-death and Japanese terms (only those used here)

- **eye** — an empty point (or small region) enclosed by one color; two genuine
  eyes make a group unconditionally alive.
- **Benson / Benson-alive / unconditional life** — Benson's algorithm (D. Benson,
  1976) proves a group can never be captured *even if its owner only ever
  passes* (needs roughly two real eyes' worth of protected space). Implemented
  in `terminal.benson_alive` / `rules.benson_alive`. The THEOREM (not just the
  port) was exhaustively falsification-tested at 3x3 here.
- **seki** — mutual life: adjacent enemy groups share liberties and neither can
  capture without dying. Shared liberties are *dame*. Not certified by Benson;
  the search resolves seki via the double-pass terminal.
- **dame** — a neutral empty point bordering both colors; worth nothing under
  area scoring.
- **sente / gote** — (Japanese) sente = a move keeping the initiative (opponent
  must respond); gote = a move that yields the initiative. Formalized by CGT.
- **tsumego** — (Japanese) a life-and-death problem; local, tractable where
  full-goban solves are not. The model for the planned *query engine*
  (goal-bounded forward solver).
- **tesuji** — (Japanese) a skillful, locally-best move/tactic.
- **joseki** — (Japanese) an established, locally-optimal opening sequence.
  Used here only as a comparison concept; not stored or generated.
- **honte** — (Japanese) the "proper"/solid move; used in the query-engine
  design as a quadrant label for moves that reinforce rather than attack.
- **tengen** — the center point of the goban (the optimal 5x5 first move, c3).

## Game-graph and search terms

- **game line / line of play** — a SEQUENCE of moves/positions from a starting
  goban. What `superko.MAX_LINE` bounds and `History` records; its length is
  measured in **plies** (one ply = one move by one side). NOT the goban's "third
  line from the edge"; NOT a serial-number "line in a listing."
- **ply** — one move (half a move-pair). Recursion depth in the forward solver
  equals game-line length in plies, which is decoupled from stone count because
  captures let a line keep changing without net stone growth.
- **PV — principal variation** — the optimal game line: best play for both sides.
- **DAG — directed acyclic graph** — a graph with no cycles. Captures + superko
  make the Go position graph *not* a clean DAG; this is why retrograde here is
  *fixpoint iteration*, not one backward sweep.
- **forward search** — solving by playing moves *forward* from a start position
  to terminals (what `solve.zig` / `oracle.zig` do).
- **retrograde analysis** — building a solution *backward* from terminal
  positions; how chess/checkers endgame tablebases are built. Here realized as
  *successor-sweep value iteration* (forward move generator only — no un-capture
  code exists), which is a fixpoint because captures are back-edges.
- **minimax** — the exact game-score rule: the player to move picks the
  continuation best for them; the score is that best outcome. The foundation;
  not a search algorithm per se.
- **alpha-beta search** — a depth-first minimax search that prunes branches
  proven irrelevant to the score. Proves the score but PRUNES (does not visit
  every subtree), so it cannot populate a complete oracle. Used here only inside
  the *finisher* and the *query engine*, not as the oracle builder.
- **DFS / BFS** — depth-first / breadth-first traversal.
- **TT — transposition table** — a cache mapping a canonical position to its
  computed score, so a position reached by different move orders is solved once
  (`solve.Table`). Unsafe under GHI without a guard (see *ko_ref*, *Kishimoto–
  Müller*).
- **GHI — Graph History Interaction** — (standard term; Kishimoto & Müller,
  and earlier) the problem that a position's score can depend on the *history*
  used to reach it (because of superko), so a plain position→score cache is
  unsafe. The central villain of this project. See `../research/ghi-and-superko.md`.
- **fixpoint iteration** — repeat a relaxation step until scores stop changing.
  Used for retrograde here because captures create back-edges (no clean
  topological order). Converges in 2/6/12/19 sweeps at 2x2/3x2/3x3/4x4.
- **Bellman update / value iteration** — (Richard Bellman; dynamic programming)
  the relaxation step "a state's score = the best one-step successor score"
  applied until convergence. The retrograde engine's core operation.
- **Markovian** — (standard term; A. Markov) the future depends only on the
  present **state**, not on the path that reached it. The nuance this project
  needs: history is not *absent*, it is **encoded in the state** — so any rule
  can be made Markovian by enlarging the state to carry exactly the history it
  depends on. The question is never *whether* a rule is Markovian but *how big
  the state must be* (`roadmap-2026-07-28.md` §1):

  | rule | history the rule needs | state size |
  |---|---|---|
  | basic ko | the one forbidden point | ~17x gobans |
  | bounded superko, window `k` | the last `k−1` gobans | explodes in `k` |
  | PSK | **every** goban ever seen | 118M ban-sets on a 2x2 |

  Corollary: a position→score table is the *smallest possible* Markovian state
  (the goban alone), and **chainable** (next entry) is the same property seen
  from the table's side — a table is chainable exactly when its state is
  Markovian for the rule it was built under.
- **chainable** **[project term]** — a table region is *chainable* when
  comparing a position's stored value with its children's stored values is a
  meaningful one-ply minimax, i.e. the history-free Bellman identity holds
  there. Choosing a move by "take the best stored child value" — what
  `Session.choose` in `src/gtp.zig` does — is only defined on a chainable
  region. Measured (`bin/weizigo-chainability`, 2026-07-27; 4x4 re-run
  **exhaustively** 2026-07-28): the single-score (L==H) region is chainable
  with **zero** violations at 2x2/3x2/3x3/4x3/4x4 — at 4x4 that is 0
  out-of-flag violations over all **48,599,962 non-settled (position, side)
  slots**, for the shipped `vb`/`vw` columns (the `lo`/`hi` bracket-table form
  of the check is still untested; WZO1 carries no bracket columns). The
  ko-sensitive region is **not** chainable, and is mispriced by up to the full
  goban swing (2n) — at 4x4, 422,990 / 10,367,922 = **4.08% of flagged
  non-settled slots**. Not a bug — each ko-sensitive slot is an independent
  fresh-start solve — but it is why the GTP player collapses in ko fights. See
  `../research/ko-sensitive-chainability.md`.
- **certified fraction** **[project term]** — the share of the positions an
  engine actually *reaches in play* where its move-selection rule is
  well-defined, i.e. the decision node is **chainable**; equivalently
  `1 − (ko-sensitive fraction over reached decision nodes)`. NOT the
  slot-uniform ko-sensitive fraction, which weights every table slot equally
  and is the wrong denominator for a player (a player walks lines from the
  empty goban). Measured 2026-07-28 with `bin/weizigo-reachcensus
  data/oracle-4x4.checkpoint.wzo --games 2000`: at 4x4 the slot-uniform figure
  is **21.33%** ko-sensitive (10,367,922 / 48,599,962 **non-settled slots**,
  exhaustive; 21.32% if the denominator is instead all 48,636,330 **legal**
  slots) but engine self-play is **100%** ko-sensitive over the **decision
  nodes reached** (28,000/28,000) — a certified fraction of **0%**. The three
  denominators are reconciled in `../research/ko-sensitive-chainability.md`
  (end of Measurement 1). See
  `../research/reachable-kosensitivity-2026-07-28.md`.
- **MPH — minimal perfect hash** — a collision-free map from a known key set
  onto a dense integer range; the index itself becomes the storage key.
  Candidate data model for the compressed oracle.
- **canonical form / equivalence class** — the 16 variants of a goban (8
  dihedral symmetries × colour inversion) all share one fate (colour swap
  negates the score), forming ONE equivalence class storing ONE score. The
  *canonical* form is the class's designated representative (here the
  lexicographically-least variant, with −1 < 0 < 1).
- **colex index (layered colex)** — a goban's serial number in a fixed
  enumeration: a collision-free bijection between gobans and dense integers
  0..3^n−1, computed both ways (`colex_from_pos`/`pos_from_colex` in
  `src/colex.zig`). An ADDRESS, never a score — the score is what the oracle
  stores AT `values[idx]`. Layered layout: layer_offset[stones] +
  subset_idx(occupied)·2^k + colour bits; subset_idx via the combinatorial
  number system. How Syzygy chess tablebases index positions. (Combinatorics
  literature calls this "ranking/unranking"; "rank" is avoided here because in
  Go it means kyu/dan player strength.)
- **CGT — combinatorial game theory** — Conway/Berlekamp/Guy theory decomposing
  endgames into independent local games with values and *temperatures*;
  formalizes sente/gote. Substrate candidate for local evaluation and the
  **loopy**-game extension needed to pin *ko-sensitive region* scores exactly.

- **loopy games** — (CGT) games with cycles, whose values are not simple numbers
  but "loopy" combinatorial-game values (Berlekamp–Conway–Guy). The research-
  grade route to exact ko-sensitive scores; unbuilt here.

## Terms named for authors / papers

- **Tromp–Taylor rules** — (John Tromp; Bill Taylor) a formal, machine-checkable
  statement of Go rules (area scoring, positional superko, suicide illegal).
  Used here as the rules reference; position-count anchors (OEIS A094777) are
  Tromp's.
- **van der Werf & Winands** — (van der Werf, Winands et al.) authors of
  published small-goban Go results used as anchors: 3x3 = +9, 4x4 = +2 (under
  basic-ko/PSK-compatible rules). 2009.
- **Kishimoto–Müller (dependency-guarded memo)** — (A. Kishimoto; M. Müller) the
  sound solution to GHI in transposition tables: a memo entry records the
  position-set its score depends on, and is reused only when the current search
  path cannot invalidate it. Realized here as *deps mode* / *fingerprint* reuse
  (Track B, ADR-0013). The unsound `ko_ref >= d` guard it replaces was the bug.
- **Berlekamp–Conway–Guy** — authors of *Winning Ways* / *On Numbers and Games*;
  the CGT framework including loopy games (see *loopy games*).
- **Benson** — (D. Benson) see *Benson / Benson-alive*.
- **Syzygy** — (R. Liśkiewicz? no — Ronald de Man) a family of chess endgame
  tablebases; their colex-style addressing inspired the weizigo address system.
- **Spight** — (T. Spight) a ruleset family for bounded ko with "repeat-twice-
  since-last-pass → no result"; the SIMPLE-ko model KataGo uses.
- **OEIS A094777** — the On-Line Encyclopedia of Integer Sequences entry for
  legal Go position counts by goban size; the external anchor `enumerate.zig`
  is validated against (1x1..4x4 all pass).

## Correctness / verification terms (and a note on "sound")

- **sound** *(standard term in formal methods / logic)* — a method is **sound**
  if it NEVER returns an incorrect answer (it may return "I don't know"). The
  dual, **complete**, means it always returns an answer. "Soundness" is a
  genuine term of art, NOT invented here. **However**, in this codebase "sound"
  has also been used as loose shorthand for "correct / not GHI-tainted / safe to
  trust / produced by the certified path." That loose usage can be cryptic;
  agents should prefer the plain-English ("never returns a wrong score here") and
  reserve "sound" for the formal-methods sense, naming the specific invariant.
  - *unsound* — may return a wrong score (the `ko_ref >= d` guard was unsound).
  - **[project term]** *soundish* — shorthand for the `memo_writes=false`
    finisher config: self-consistent and resting only on already-checked
    invariants, but not independently proven. Prefer "writes-off finisher."
- **the #2 auditor** **[project term]** — the self-consistency auditor
  (`RETRO_CONSIST`/`RETRO_CONSIST4`): under a fixed history a solver's own
  outputs must satisfy minimax (a parent's score never below its best child); a
  violation PROVES a bug. Necessary-not-sufficient. The mandatory pre-commit
  gate for finisher/memo/ko changes.
- **battery** **[project term]** — the standard validation suite run after an
  engine change: anchors, exhaustive symmetry (inversion + dihedral + L/H-swap),
  bracket containment, Exact-on-reachable, spot checks, arena. See ARCHITECTURE.

## weizigo engine concepts (project jargon — defined, not standard)

- **fresh-start score** **[project term]** — the score of a position assuming
  the game history is empty (no prior gobans to forbid). The ADR-0008 oracle
  semantics. Equals the history-free score where the fresh-start single-score region holds.
- **L / H (two-sided certification)** **[project term]** — two fixpoints of the
  retrograde value iteration: **L** seeded −n (cycles scored maximally anti-
  Black → least fixpoint), **H** seeded +n (pro-Black → greatest fixpoint).
  Where L==H the score is *claimed* history- and rule-independent (the **fresh-start single-score region**; C2, falsified at 3×2 by T13 — see `status/leak-crisis.md`); where L<H the node is *KO_SENSITIVE* (the **ko-sensitive
  region**), bracketed [L,H]. See `names.md` for canonical names.
- **certified core** **[project term; DEPRECATED]** — historical synonym
  for the **fresh-start single-score region** (positions where L==H). The
  term implied real-game history-independence; that implication is **false**
  (C2 falsified at 3×2 by T13, 2026-07-26; see `status/leak-crisis.md`).
  Use "fresh-start single-score region" or "single-score scores" instead.

## fresh-start score

[project term] The score of a (position, side) reached from the empty goban
with no prior history, played out under the generation rule (basic ko +
bracket-guided finisher, `memo_writes=false`). The table holds fresh-start
scores (C1). A fresh-start score is **not** a real-game score under PSK
(C2 falsified at 3×2; C3 falsified at 3×3).
- **ko-sensitive region** **[project term]** — the complement of the
  single-score region: positions where L<H, i.e. the fresh-start score is not
  unique across cycle conventions. Fraction FALLS with size — **72/39/34/21% at
  2x2/3x2/3x3/4x4, denominator = all legal (position, side) slots** (the
  converge census; at 4x4, 10,367,922 / 48,636,330 = 21.32%) — but never
  vanishes. **Mind the denominator:** `bin/weizigo-chainability` reports a
  *different* series (77.36 / 41.18 / 35.04 / 26.60 / 21.33% at
  2x2/3x2/3x3/4x3/4x4) because it exempts settled positions and divides by
  **non-settled** slots only. The two series are reconciled **at 4x4 only** (the
  36,368-slot settled exemption; `../research/ko-sensitive-chainability.md`, end
  of Measurement 1); the smaller-goban rows are `CLAIMS.md` discrepancy D7 and
  remain unreconciled. The bracket `[L,H]` is the **spread of
  fresh-start fixpoints under different cycle-resolution conventions**; it is a
  CLAIMED fresh-start property, **not** a real-game bound (C3 falsified at
  3×3; see `../status/leak-crisis.md`). See `names.md`.
- **bracket / [L,H] bracket** **[project term]** — the bracket for a
  ko-sensitive slot: a `[L,H]` range from the L/H fixpoint iteration. It is the
  **spread of fresh-start fixpoints under different cycle-resolution
  conventions**, not a real-game bound (C3 falsified at 3×3; see
  `status/leak-crisis.md`). The lower bound L is the least fresh-start
  fixpoint; the upper bound H is the greatest. The range-aware player is NOT
  leak-free. See `names.md`.
- **KO_SENSITIVE** **[project term]** — the flag (FLAG_KO_SENSITIVE) marking a
  ko-sensitive slot (L<H). Its score depends on the cycle rule / history.
- **DTT — depth-to-terminal** **[project term]** — the fastest optimal
  resolution length (in plies) for a slot, saturating at DTT_FAR. Computed free
  by the retrograde sweeps; unrecoverable later, so stored in the schema.
- **finisher** **[project term]** — the forward solve that resolves ko-sensitive region
  slots, seeded with certified scores so it terminates upon leaving the ko-
  tangled region. Implemented as bracket-guided alpha-beta (ADR-0010) + MTD
  null-window probes + per-root bounds memo. Its committed outputs are
  UNTRUSTWORTHY until Track A regeneration (ADR-0013).
- **converge / finalize** **[project term]** — the two retrograde phases:
  *converge* runs L/H fixpoint sweeps; *finalize* reads out the fresh-start single-score region
  and (optionally) runs the finisher on the ko-sensitive region. Polynomial in table size;
  the finisher is the expensive part.
- **kill-X%** **[project term]** — an optional rule: a move capturing > X% of
  the goban's points ends the game immediately. Tested as a ko-sensitive-region cure and
  ABANDONED (it worsens the ko-sensitive region). Retained as an optional play rule.
- **fingerprint (dependency)** **[project term]** — a Bloom-style bit-word
  summarizing the position-set a memo entry's score depends on (Track B / deps
  mode). Reuse is allowed only when the entry's fingerprint is bit-disjoint from
  the ancestors' OR — proving no ancestor can introduce a new superko ban.
  False positives only forgo reuse, never corrupt.
- **Bloom filter** — (Burton Bloom, 1970) a space-efficient probabilistic set
  membership structure using multiple hash-selected bits; the basis of the
  *fingerprint*.
- **MTD(f) / MTD null-window** — (Plaat 1996) a best-first search built from
  repeated zero-window alpha-beta probes; used by the finisher. Bare MTD was
  measured WORSE than aspiration-with-bounds-memo here.
- **aspiration window** — a narrow alpha-beta window around an expected score
  to speed pruning; re-searched wider on failure.
- **Track A / Track B** **[project term]** — ADR-0013's two routes: **Track A**
  = correctness now (regenerate 2x2..4x4 with memo writes OFF, pass the
  auditor); **Track B** = sound cross-branch reuse via dependency fingerprints
  (the Kishimoto–Müller realization, for 5xN scale).
- **deps mode** **[project term]** — the Track B finisher configuration using
  dependency-guarded memo (fingerprints). Sound and byte-identical to writes-off
  on 3x2/3x3/4x3 (validated), faster than writes-off but slower than the unsound
  path.
- **ban set / ban-set key** **[project term]** — the set of prior goban
  positions forbidden by superko; the `Exact` solver keys memo on it (sound but
  memory-prohibitive >3x3: ~5 MB/state at 4x4).
- **rule-independent** **[project term]** — a score identical under any cycle
  convention whose cycle-score lies in [−N,N]; the *claimed* property of the single-score region (C2; falsified at 3×2 by T13 — see `status/leak-crisis.md`).

## weizigo code-specific terms

- **position (`pos`)** — a `[n]i8` goban; sign = colour (>0 black, <0 white,
  0 empty). Magnitudes are *army-flag* ids, ignored when comparing colours.
- **army flag** — the positive/negative magnitude labelling which connected
  group (chain) a stone belongs to; assigned by `state.update_armies` (Gen-1).
- **blind** — the n-bit occupancy bitmap (which cells hold a stone, ignoring
  colour). `state.blind_from_pos`.
- **seq** — the colour bits of the occupied cells in index order (≤16 stones
  hashable). `state.seq_from_pos`.
- **view** — a 40-bit packed encoding of a position (Gen-1).
- **lowest / canonical form** — the representative of a position under the 8
  dihedral symmetries × black/white inversion; the TT key.
  `state.lowest_blind_from_pos`.
- **is_settled** — fast-path terminal test: whole goban decided (all stones
  Benson-alive, every empty region one color's eye-space, no open interior).
  `terminal.is_settled` / `rules.is_settled`.
- **double-pass terminal** — the general game-end condition (two passes in a
  row); the always-correct terminal the search falls back to.
- **eye-prune (`is_own_eye`)** — move-generation rule forbidding a player from
  filling its own Benson-alive eye; required for a tractable forward search
  (ADR-0006). A forward-search device ONLY; the retrograde engine uses the full
  move set by design.
- **ko_ref** **[project term]** — the shallowest game-line ply any superko ban
  in a subtree referenced. The OLD cacheability guard was `ko_ref >= d`
  (cacheable if every ban was self-contained within the node's own subtree) —
  PROVEN UNSOUND (ADR-0013) because a different arrival can introduce a new ban.
  Replaced by dependency-guarded reuse.
- **KO_CLEAN** **[project term]** — sentinel `ko_ref` meaning "no superko ban
  referenced any prior ply."
- **MAX_LINE** — the bound on one game line's length = the recursion depth cap
  in `solve`. Headroom, not a proof.
- **schema (frozen, ADR-0009)** — per (position, side): value:i8 + dtt:u8 +
  flags:u8. Columnar; six frozen columns vb/vw/fb/fw/db/dw in the artifact.

## File / format / protocol terms

- **GTP — Go Text Protocol** — the standard protocol for Go engine↔GUI
  communication (Sabaki, gogui, etc.). `src/gtp.zig` implements it; the oracle
  plays via GTP. Supports `rectangular_boardsize W H` for non-square gobans.
- **SGF — Smart Game Format** — the standard text format for recording Go
  games/problems. `src/sgf.zig` writes it; rendering is delegated to external
  tools (Sabaki, SmartGo One). No GUI code in this repo, ever.
- **WZO / WZO1 — weizigo oracle artifact** **[project term]** — the on-disk
  oracle format (`src/artifact.zig`): dense colex-addressed columns, a 32-byte
  header versioning the format AND `colex.layout_version`, CRC-32-checked; the
  reader refuses any mismatch. `artifacts/oracle-{2x2,3x2,3x3}.wzo` are the
  committed small artifacts. Distinct from the TT checkpoint codec (`persist.zig`).
- **ADR — Architecture Decision Record** — a short dated doc capturing one
  design decision, its context, and consequences. Kept in `docs/decisions/`,
  append-only (supersede, don't rewrite). 0001..0013 so far.

## Goban-size facts (see `research/strategy-open-questions.md`)

- 2x2: empty(B) = +1 (fresh-start). 3x2: +1. 4x3: +4 (perfect).
- 3x3: +9 (PSK, matches van der Werf & Winands). 4x4: +2 (PSK, matches anchor).
- 5x5: known **Black +25** — total annihilation — but under a SIMPLER repetition
  rule than this project's; not yet reached here.
- 6x6: expected Black +4 (both colors survive, ~20/16); not rigorously solved.
- 7x7: fair komi ≈ 9; near-balanced; not rigorously solved. 8x8+: unsolved.
- **5x5 is the largest goban on which optimal play annihilates one side; from
  6x6 up both players live.**

## single-colour goban `[project term]`

A position with **at least one stone, all stones the same colour, and any number of
empty points.** The goban after Black's opening stone is a single-colour goban; so is
one with fifteen black stones and one empty point.

Ruling by the Orchestrator, 2026-08-03, replacing **"monochrome"**, which T266 used for
this concept in `docs/evidence/ORACLE-V2/incompleteness-T266.md` and
`findings/T266-incompleteness.json`. "Monochrome" reads as "no empty points" — the
opposite of what is meant — and the whole T266 result rests on the reader getting this
right: a `(position, side, ko=none, passes=1)` state is unreachable exactly when the
position is single-colour **in the side's opposing colour**, because the only way into
`passes=1` is a pass from `passes=0`, and `passes=0` is only entered by a placement,
which always leaves a stone of the mover's colour. 131,068 such states at 4×4, all
correctly absent.

The findings file keeps the old word: findings are immutable once absorbed (T279
absorbed it on 2026-08-03), so the correction propagates forward into the register row
and the evidence document rather than backward into the record. Superseding a term is
not licence to rewrite what was written.
