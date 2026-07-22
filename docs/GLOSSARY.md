# Glossary

Abbreviations and terms used across this project's code and docs. Three groups:
Go terms, algorithm / computer-science terms, and weizigo code-specific terms.

## Go terms

- **area scoring (Chinese)** — your score = your stones on the board + empty
  points your stones surround. This project's canonical ruleset. Komi applied by
  the caller. Compare *territory scoring*.
- **territory scoring (Japanese)** — your score = surrounded empty points +
  captured prisoners. Needs capture tracking; not used for solving here. Usually
  agrees with area scoring within ~1 point.
- **komi** — points added to White's score to offset Black's first-move
  advantage.
- **Benson / pass-alive / unconditional life** — Benson's algorithm proves a
  group can never be captured *even if its owner only ever passes* (needs
  roughly two real eyes' worth of protected space). Implemented in
  `terminal.pass_alive`.
- **eye** — an empty point (or small region) enclosed by one color; two genuine
  eyes make a group unconditionally alive.
- **seki** — mutual life: adjacent enemy groups share liberties and neither can
  capture without dying. Shared liberties are *dame*. Not certified by Benson;
  the search resolves seki via the double-pass terminal.
- **dame** — a neutral empty point bordering both colors; worth nothing under
  area scoring.
- **sente / gote** — sente = a move keeping the initiative (opponent must
  respond); gote = a move that yields the initiative.
- **tengen** — the center point of the board (the optimal 5x5 first move, c3).
- **ko / superko** — *ko*: the single-move repetition ban. *superko*: no
  whole-board position may ever repeat. See PSK.
- **PSK — positional superko** — the exact whole-board *position* may never
  repeat in a game (this project's ko rule; `superko.zig`). Compare *situational*
  superko (position + side-to-move).
- **game line / line of play** — a SEQUENCE of moves/positions from a starting
  board (chess/Go analysis jargon). What `superko.MAX_LINE` bounds and what
  `History` records; its length is measured in plies. NOT the board's "third
  line from the edge", and NOT a serial-number "line in a listing" (that
  metaphor is retired — see *colex index*).
- **PV — principal variation** — the optimal game line: best play for both
  sides.
- **annihilation** — optimal play in which one color ends up owning the entire
  board (5x5 = Black +25). From 6x6 up, both colors survive.

## Algorithm / computer-science terms

- **TT — transposition table** — a cache mapping a canonical position to its
  computed value, so a position reached by different move orders is solved once
  (`solve.Table`).
- **GHI — Graph History Interaction** — the problem that a position's value can
  depend on the *history* used to reach it (because of superko), so a plain
  position→value cache is unsafe without care. Handled here by the `ko_ref`
  cacheability rule.
- **DFS / BFS** — depth-first / breadth-first search (traversal orders).
- **DAG — directed acyclic graph** — a graph with no cycles. Captures + superko
  make the Go position graph *not* a clean DAG.
- **forward search** — solving by playing moves *forward* from a start position
  to terminals (what `solve.zig` does).
- **retrograde analysis** — building a solution *backward* from terminal
  positions by "un-playing" moves; how chess/checkers endgame tablebases are
  built. The intended efficient oracle engine (ADR-0007).
- **fixpoint iteration** — repeat a relaxation step until values stop changing;
  needed for retrograde in Go because captures create back-edges (no clean
  topological order).
- **alpha-beta / PN (proof-number) search** — value-proving searches that prune
  suboptimal subtrees. Out of scope here: they prove the value (goal a) but
  cannot populate an oracle (goal b). See ADR-0007.
- **MPH — minimal perfect hash** — a collision-free map from a known key set
  onto a dense integer range; the index itself becomes the storage key.
  Candidate data model for the compressed oracle.
- **canonical form / equivalence class** — the 16 variants of a board (8
  dihedral symmetries x colour inversion) all have the same fate (colour swap
  negates the value), so they form one *equivalence class* storing ONE value.
  The *canonical* form is the class's designated representative (here: the
  lexicographically-least variant, with -1 < 0 < 1). Lookup = canonicalize the
  query, fetch, negate if the transform swapped colours.
- **colex index (layered colex)** — a board's serial number in a fixed enumeration
  order: a collision-free bijection between boards and the dense integers
  0..3^n-1, computed arithmetically both ways (`colex_from_pos`, `pos_from_colex`
  in `src/colex.zig`). An ADDRESS, never a score — the score is what the
  oracle stores AT `values[idx]`. Layered layout: layer_offset[stones] +
  subset_idx(occupied cells)*2^k + colour bits, with subset_idx from the
  combinatorial number system (C(c1,1)+...+C(ck,k)). How chess endgame
  tablebases (Syzygy) index positions. (The combinatorics literature calls
  this "ranking/unranking" — the word "rank" is avoided in this project
  because in Go it means kyu/dan player strength.)
- **CGT — combinatorial game theory** — Conway/Berlekamp theory decomposing
  endgames into independent local games with values/*temperatures*; formalizes
  sente/gote. Candidate substrate for local evaluation / explainability.
- **ADR — Architecture Decision Record** — a short dated doc capturing one
  design decision, its context, and consequences. Kept in `docs/decisions/`.

## weizigo code-specific terms

- **position (`pos`)** — a `[25]i8` board; sign = colour (>0 black, <0 white,
  0 empty). Magnitudes are army-flag ids, ignored when comparing colours.
- **army flag** — the positive/negative magnitude labelling which connected
  group (chain) a stone belongs to; assigned by `state.update_armies`.
- **blind** — the 25-bit occupancy bitmap of a position (which cells hold a
  stone, ignoring colour). `state.blind_from_pos`.
- **seq** — the colour bits of the occupied cells in index order (≤16 stones
  hashable). `state.seq_from_pos`.
- **view** — a 40-bit packed encoding of a position.
- **lowest / canonical form** — the representative of a position under the 8
  dihedral symmetries × black/white inversion; the TT key.
  `state.lowest_blind_from_pos`.
- **is_settled** — fast-path terminal test: whole board decided (all stones
  Benson-alive, every empty region one colour's eye-space, no open interior).
  `terminal.is_settled`.
- **double-pass terminal** — the general game-end condition (two passes in a
  row); the always-correct terminal the search falls back to.
- **eye-prune (`is_own_eye`)** — move-generation rule forbidding a player from
  filling its own Benson-alive eye; required for a tractable forward search
  (ADR-0006). A forward-search device only.
- **ko_ref** — the shallowest game-line ply any superko ban in a subtree
  referenced; a node's value is cacheable iff `ko_ref >= d` (its own depth).
- **KO_CLEAN** — sentinel `ko_ref` meaning "no superko ban referenced any prior
  ply" → the subtree value is history-independent.
- **MAX_LINE** — the bound on one game line's length = the recursion depth cap in
  `solve` (a game line is measured in *plies*, decoupled from stone count by
  captures).
- **SeqScore / block_size** — a TT slot `{seq, score}`; `block_size(n) =
  2^(n-1)` slots reserved per blind of `n` stones (after colour-inversion
  canonicalization).

## Board-size facts (see also `docs/research/strategy-open-questions.md`)

- 5x5: **solved**, Black +25 — total annihilation (whole board Black).
- 6x6: expected Black +4 (both colours survive, ~20/16); **not** rigorously
  solved from the empty board.
- 7x7: fair komi ≈ 9; near-balanced at fair komi, both colours keep large
  territory; not rigorously solved.
- 8x8+: unsolved.
- Transition: **5x5 is the largest board on which optimal play annihilates one
  side; from 6x6 up both players live.**
