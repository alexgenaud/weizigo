# Teaching oracle: explaining optimality without fiction (2026-07-18)

User goal: solved 5x5 as a TEACHING GUIDE / total holistic joseki database.
The engine should say things like: "this move is optimal, complex, guaranteed
+8 if played perfectly; that one is simpler, resolves in capture in 3 moves,
still likely wins by 1 — but loses to reply X; yet X is sharp and punishes any
single opponent error."

Guiding constraint (user's own warning): avoid FICTIONS — retroactive
narrative justifications not grounded in truth. Everything below is pure
arithmetic over exact oracle values; no narrative generation.

## Metrics derivable from a complete value table (no extra solving)

For any position P (side s to move), with all successors' values known:

- **move score**: exact value of each legal move (and pass). The base
  primitive; sorting gives the complete move ordering. "Optimal move" = any
  move whose value equals the position value; there may be several.
- **sharpness / forgiveness**: how many moves preserve the optimal value
  (1 = "only move"; many = forgiving position).
- **punishment spread**: value gap between best and second-best move; mean
  value loss of a uniformly random move (how dangerous the position is).
- **error-capitalization** (the "complex move" signal): after our move, the
  distribution of opponent-reply values — a move is *sharp/complex* if most
  opponent replies lose big (opponent must find rare exact answers), *simple*
  if all replies lead to similar values.
- **sente, operationally defined**: a move retains sente if every
  value-preserving opponent reply is confined to a small forced set (all other
  replies lose >= threshold). No shape-narrative needed.

## Metrics that need ONE extra byte per (position, side): DEPTH

- **DTT — depth to terminal** (chess tablebases store the analogous DTM/DTZ):
  plies until the game resolves under optimal play. Directly expresses the
  user's "resolves in 3 moves" vs "purpose reveals itself a dozen moves later".
- **Depth-of-consequence of a move** = DTT(successor) + 1 vs alternatives.
- The RETROGRADE engine computes DTT essentially FOR FREE: it is the
  propagation round at which a value resolves.

## => SCHEMA DECISION, needed BEFORE the format contract freezes

Plan the oracle record per (position, side) as:
    value: i8  (exact score, Black-positive)
    dtt:   u8  (plies to terminal under optimal play, saturating; 255 = far)
    flags: (later, from the retrograde ADR: ko/history-sensitivity bit, etc.)
Doubling 26 GB -> 52 GB for 5x5 canonical is still "disk is not the
constraint" (strategy doc), and DTT is unrecoverable later without re-solving.
Record in the #6' ADR.

## Delivery vehicle

Annotated SGF (sgf.zig): trees whose every node carries value, #optimal moves,
DTT, sharpness — readable in Sabaki etc. The "total joseki database" is the
oracle restricted to optimal-play-reachable positions, exported as such trees.

## Honest limits

- WHY-narratives (shape, influence, direction of play) are not derivable from
  values alone; generating them risks exactly the fictions the user warns of.
  The rigorous subset: CGT (Berlekamp-Wolfe) local game values + temperature
  for decomposed endgames = provable sente/gote/biggest-move statements.
- KataGo-style "mysterious" moves: an exact oracle can at least bound the
  mystery — exact margin, only-move-ness, and DTT tell you *that* and *when* a
  move pays off, if not the human-legible *why*.

## Worst-move criteria for game review (user requirements, 2026-07-22)

Which move in a played game is "the most critically worst — the one most
important to focus on, understand, correct, and learn from"? Four distinct,
COMPUTABLE criteria, deliberately not collapsed into one number:

1. **Outcome flip** (the game-losing move): the move whose value trajectory
   crosses the win/loss boundary (v vs komi). NOT the biggest swing — in the
   B+16 game, Black's C4 lost only 3 points but crossed +2 -> -1 (won game
   -> lost game); D4 lost 17 points but the game was already theoretically
   lost. A review leads with the flip, not the magnitude.
2. **Magnitude** (points thrown): the raw value swing. Secondary, but the
   right frame for loss-minimization lessons ("you were losing by 1; D4
   made it 16").
3. **Learnability** (is there a lesson inside?): a blunder every reply
   punishes teaches little; a PRINCIPLED error teaches much. Computable
   proxies: refutation NARROWNESS (how many opponent replies actually
   punish it — one precise refutation = subtle, systematic error),
   refutation DEPTH (plies until the consequence is visible — deep =
   conceptual, shallow = reading lapse; the DTT column + trap metric), and
   correct-move UNNATURALNESS (distance from recent play per the gravity
   model — errors whose correction violates the student's habits are the
   systematic ones; cf. the 1/d^2.5 next-move law).
4. **Student fit** (the verification-depth skill model): the most important
   lesson is the largest error whose refutation the student can verify
   end-to-end at their level. A 15-kyu should not lead with a superko
   nuance; a 5-dan should not lead with a 3-point endgame slip.

What teaching masters actually do (and the engine analogue):
- Review 3-5 SCENES, never every move -> emit top-k "review cards": the
  position, played vs best move, the punishing line (principal variation),
  and the fact-diff explanation (status ladder: which group's life/death/
  territory status changed).
- Ask "what were you thinking?" — diagnose the PLAN, not the coordinate.
  Engine analogue: principle mining across the player's games; a repeated
  error shape outranks a one-off.
- Phase distinction is real and computable: OPENING errors are
  direction-of-play (value drifts while all statuses stay open), MIDDLE
  game errors are status changes (the ko-sensitive/fight region — flags
  dense, statuses volatile), ENDGAME errors are counting (inside the
  certified core, finite DTT). Different faculties, different lessons;
  segment the review by where the certified/ko-sensitive boundary sits.
- Convert the scene into a PRACTICE PROBLEM: the position as a
  goal-bounded local puzzle ("Black to play and keep the win") — the
  query-engine's tsumego generator, fed by the player's own games.
