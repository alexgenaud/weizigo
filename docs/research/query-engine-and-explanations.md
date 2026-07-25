# The query engine: definitive local questions & non-fiction explanations
(2026-07-18; user requirements session)

The oracle answers ONE question: exact value of (position, side). The user
requires a family of LOCAL, HUMAN-MEANINGFUL questions with DEFINITIVE answers
— or an honest "no definitive answer beyond: it leads to the optimal outcome."
No LLM narratives (out of scope); only deterministic mathematics, possibly
ranked for a later narrative layer.

## Key architectural insight: a GOAL-BOUNDED solver answers local questions

Almost every question below is a sub-game with a MODIFIED OBJECTIVE, solved by
the forward engine with a different terminal test:

    solve(position, side, objective)
      objective in { capture(S), save(S), make_pass_alive(S), value >= v }
      terminal: objective decided (not game over!)

This is classic tsumego (life & death) solving. CRUCIALLY it is tractable
where full-game solving is not: "are these stones capturable" usually decides
within a few plies — no need to play to the end of the game. Forward search,
which we measured intractable for FULL-GAME oracle filling, is exactly the
right tool for goal-bounded local questions. Forward and retrograde stay
complementary: retrograde builds the global table; forward answers live local
queries. (Rules kernel: `rules.zig`; superko machinery reusable.)

## The query taxonomy (all definitive, all non-narrative)

| question (user's words) | formal query | answer type |
|---|---|---|
| max guaranteed score, either side | oracle value(P, s); negative = White ahead | exact i8 |
| value of every next move, both colors | successor lookups in both side-tables | exact per move |
| worth of having the move here | TEMPO(P) = value(P, Black) − value(P, White) | exact swing |
| "can Black capture these white stones?" | goal-solve: objective = capture(S) vs save(S) | yes/no + line + plies |
| "can these stones become immortal vs a diligent killer?" | goal-solve: defender aims pass_alive(S) certificate, attacker prevents | yes/no + plies |
| "must we choose which group lives?" (miai death) | compare goal-solves: save(A), save(B), save(A and B) | which combinations are achievable |
| "is this move sente?" | after the move, do all value-preserving opponent replies lie in a small forced set (others lose >= t)? | yes/no at threshold t |
| how soon does it resolve? | DTT (global, stored) or plies-to-objective (local, computed) | exact ply count |
| sharp or forgiving? | # value-preserving moves; punishment spread; opponent-error capitalization | exact counts/margins |

## "WHY is move A better than B" — the FACT-DIFF mechanism (no fiction)

Compute the definitive predicate set in the positions after A and after B
(group-by-group capture/life/immortality status, tempo, sente state, exact
values, DTT), and DIFF them:

    after A: white group at {..} becomes capturable (proof: capture query
             flips no->yes), Black keeps sente, value +9, resolves in 5.
    after B: same group stays uncapturable; Black loses tempo (opponent
             gains a free move worth 4); value +1.

The diff of PROVABLE FACTS is the explanation. Every clause is a theorem about
a sub-game, not a story. When no predicate differs, the engine says exactly
what the user allowed: "no simpler reason found: A leads to the optimal
outcome and B does not" — the honest residue.

A later narrative layer (LLM or template) may ORDER these ranked deterministic
reasons into prose — explicitly OUT OF SCOPE now. In scope: computing and
ranking the reasons.

## Store vs compute doctrine (answers "what to collect and why")

STORE at build time (global, unrecoverable later without re-solving):
  - value: i8 per (position, side) — the oracle.
  - DTT: u8 — depth to FULL-BOARD terminal under optimal play.
  - flags: ko/history-sensitivity bit (from the retrograde ADR).

COMPUTE at query time (local, cheap, no storage):
  - Benson status of every group: instant (rules.pass_alive).
  - capture / life / immortalization queries: goal-bounded forward solves
    (small; cacheable in a session-local memo if needed).
  - move tables, tempo, sharpness, sente predicates, fact-diffs: arithmetic
    over stored values + the above.

Nothing else needs precomputation. The user's concern is exactly right: do
NOT try to pre-answer all local Q&A across the whole tree; store the two bytes
+ flags that cannot be recomputed cheaply, and make everything else a fast
live query.

## LOCAL x GLOBAL quadrants (user requirement, 2026-07-18)

Every candidate move gets TWO independent verdicts, and the cross-product is
the teaching signal:

  LOCAL  verdict: does the move achieve/preserve the local objective?
                  (goal-bounded solver: kill/save/live/connect)
  GLOBAL verdict: does the move preserve the exact game value? (oracle)

  quadrant        | meaning                        | classical name
  ----------------|--------------------------------|------------------------
  good : good     | correct battle, correct war    | honte
  good : bad      | wins the fight, LOSES the game | poison move / overplay
  bad  : good     | locally losing but optimal     | sacrifice / tesuji
  bad  : bad      | plain error                    | --

Plus a third GLOBAL category beyond good/bad: **indifferent** — achieving vs
abandoning the local objective leads to the SAME game value (the local object
does not decide the game). That answers "locally optimal but will not
determine the final win".

**Urgency / tenuki test** (exact, from the oracle): compare
value(best local move) vs value(best move ELSEWHERE). If tenuki preserves the
value, the local situation is not urgent (classical "urgent before big",
computed, not judged). The user's example sentence — "Black CAN kill these
stones and CAN save those, but should play the corner now" — is precisely:
kill = LOCAL:good GLOBAL:bad; corner = LOCAL:none GLOBAL:good; with the WHY
possibly beyond simple explanation (the honest residue), but the QUADRANT
labels always statable.

Storage impact: NONE (composes from oracle values + live goal solves).

## Principle mining (the publishable 5x5 "joseki laws")

With the solved DAG, candidate principles become EXACTLY quantifiable over
optimal-play-reachable positions:

    "centre is the only winning first move"        -> check: value of all 6
                                                       distinct openings
    "never play the corner before move K"          -> for each K: does any
                                                       optimal line contain an
                                                       earlier corner move?
    "avoid the side before move K"                 -> same schema

Output form: "true in 100% of optimal positions" or "98.7% — counterexamples:
[SGF list]". Tic-tac-toe analogy (user's): "always expect a tie; centre
maximizes opponent-error winning chances" — the 5x5 versions will be
conditional but exactly stated, with machine-checked quantifiers and
counterexample files. This is a post-solve analysis pass; no schema impact.

## Auditing external engines (KataGo) — audit beats match

With a VERIFIED oracle, whether KataGo (or any engine) plays perfect 5x5 is
answered by AUDIT, not by match play: for any position, compare the engine's
chosen move against the table — "suboptimal at P" becomes a checkable theorem.
- Falsification is cheap: ONE audited value-losing move suffices.
- Total perfection is a coverage claim: provable along the optimal-play DAG
  (bounded), infeasible over all legal positions (each query costs the
  engine a search; and "KataGo" is only a defined strategy once config,
  visits, and seed are pinned).
- Match logic (user's, with the komi caveat): our loss from a theoretically
  >= drawn position falsifies US; our win falsifies the OPPONENT's perfection
  ONLY if it held a theoretically >= drawn position (at fair komi 25, yes);
  and a win never proves OUR perfection — only the validation battery +
  engine-vs-engine agreement do that.
- Novelty: plausibly the first published exhaustive small-board audit of a
  neural engine against a proven oracle — needs a literature check before
  claiming (adjacent: Expected Work Search 5x5 2024; 7x7 killall studies).
- TWO perfection criteria (2026-07-18, after reviewing KataGo's objectives):
  KataGo maximizes a hybrid utility — win probability (dominant) + a
  saturating expected-score term (its signature innovation; keeps gradient in
  lost positions -> minimizes losing margins, avoids winrate-flatline
  nonsense; no explicit opponent-error model by default, though
  playoutDoublingAdvantage approximates "opponent is weaker", and v1.15+
  ships a rank-conditioned human-imitation net — statistical imitation,
  vs our principled local/global skill construction). Therefore audit BOTH:
    score-perfection: move preserves the exact oracle value (KataGo does not
      even aim at this; will "fail" by design in won positions -- slack is
      intended, not error);
    win-perfection: no move converts a theoretical win/draw at komi K into a
      loss (KataGo's actual objective; the fair test).
  At fair komi 25 the two nearly coincide (no slack margin exists). The
  oracle audits both: value = score-perfection; sign vs komi = win-perfection.

## Skill-graded opponents from LOCAL x GLOBAL (user idea, 2026-07-18)

The quadrant data enables PRINCIPLED skill levels (instead of the usual
"fewer playouts -> alien blunders"): choose moves by a blended score
alpha*global + beta*local + noise. ~30 kyu = near-random / local-only, no
global anticipation; ~15 kyu = favours local objectives over global value;
dan = mostly global with sharp local reading. Errors become HUMAN-SHAPED
(local greed, missed tenuki) because they are generated from the same
local-vs-global tension human players actually experience. Post-oracle
application; no schema impact.

## Personas & pedagogy from exact data (user vision, 2026-07-18)

A PERSONA is a utility function over exact quantities — every human style the
user named is computable, because the oracle makes margin, risk, and
explanation all measurable:

- **lazy winner** ("I'll win anyway, don't make me think"): among
  win-preserving moves, maximize FORGIVENESS (most future moves stay winning;
  min sharpness) rather than score. Exactly the human conserve-energy habit.
- **angry destroyer**: maximize exact margin + opponent punishment (prefer
  lines where the opponent's average reply loses most).
- **the Emperor's courtesy**: steer the FINAL MARGIN itself — among
  win-preserving moves, choose those that provably reduce one's own winning
  margin toward the minimum (+0.5-style). Deliberate margin control with a
  guarantee is an ORACLE-ONLY capability; statistical engines cannot promise
  it. (5x5 area scores are odd integers; margin steering is in +-2 steps and
  interacts with komi.)
- **the explainer**: among value-preserving moves prefer minimal EXPLANATION
  COST = size/depth of the smallest fact-diff that justifies the move (count
  of goal-solve clauses, their ply depths). The honest inverse is now a
  statement, not a failure: "the provably optimal move exists but exceeds the
  explanation budget" — the user's 'cannot be concisely explained by pithy
  principles'.

**Rank-labelling moves ("this is a 15k move; any dan plays this")** — the one
ingredient exact data CANNOT supply: kyu/dan labels are empirical facts about
human populations. Bridge: an external human-move model (KataGo v1.15+ ships a
rank-conditioned human-imitation network; or game corpora) supplies
P(rank r plays m); our oracle supplies the truth about m (quadrant, value
cost). Label = the rank band where m becomes a typical choice, ANNOTATED with
its exact consequence ("typical 15k move: wins the local fight, loses 6").
Without the human model we can still say the deeper thing: WHAT the move
costs and WHY-by-fact-diff.

**Joseki-by-principle (conditional principle mining)**: upgrade principle
mining from unconditional laws to CONDITIONAL rules — decision rules over
computable predicates (ladder-works?, influence/ownership toward a side,
group statuses, sente state): "IF <condition> THEN X is optimal (accuracy
100%/N%, counterexamples attached)". The mining is mechanical over exact
labels; the human work is choosing GOOD predicate vocabulary — which is
exactly where teaching insight enters. This is how an expert explains joseki:
alternatives-by-condition, not a catalog.

### Refinements (user, 2026-07-18 second pass)

- **Lazy winner, corrected**: humans have no oracle; "don't make me think" =
  among win-preserving moves prefer IMMEDIATE LOCAL RESOLUTION (low local
  plies-to-objective: the kill lands, the two eyes form, the corner settles in
  a few stones) — minimize FUTURE READING, not maximize forgiveness.
- **Trap metric (handicap play / anti-weak-opponent persona)**: the exact
  version of "prefer complications the opponent cannot read out":
  REFUTATION DEPTH = the length of the forced only-move chain the opponent
  must navigate to hold the value (computable from the oracle: consecutive
  positions where all-but-one replies lose). Trap value = punishment x
  P(opponent misses), the P from an opponent model. KataGo's analog is
  playoutDoublingAdvantage — it models the opponent as a WEAKER VERSION OF
  ITSELF (fewer playouts), not a depth-limited human; without it, its
  self-consistent search plays hopeless Go in big handicaps.
- **Emperor's courtesy, refined**: also "make it look challenging" =
  VALUE-TRAJECTORY SHAPING — keep the exact running value near the polite
  target for the WHOLE game, not just at the end (the margin trajectory is
  fully observable to us at every ply). And robustness: steer such that the
  target stays reachable across the PLAUSIBLE (not optimal) reply set — which
  requires an opponent model; the Emperor may surprise in both directions,
  assumed never deeply optimal. Honest: courtesy is opponent-model-dependent;
  pure margin steering (endpoint only) is oracle-only and guaranteed.
- **Skill without human data — VERIFICATION DEPTH**: a move is a "15k move"
  if a BETTER move exists that only deeper reading reveals. Computable
  ordering: D(m, m*) = minimal reading depth at which m*'s superiority over m
  becomes definite (how many stones until the groups' fates diverge
  provably — we can count exactly). Skill config = fractions of
  {random, local-objective, global-optimal} + a ply-depth budget per
  component (30k: near-random+local, no endgame; dan: never random,
  local+global). Mapping D-bands to kyu labels stays empirical (ranges, with
  move-rank ambiguity: 30k and 9d may both tenuki), but the DIFFICULTY
  ORDERING is exact and needs no human data.
- **GROUP STATUS LADDER** (per group, all computable, sorted advice):
    1. cannot kill (immortal or defensible)
    2. cannot kill BUT worthy ko threat (attack forces answers; the threat's
       exact value = the swing if ignored — exact ko-threat sizing)
    3. can kill, but killing is OFF the optimal path (tenuki test fails it)
    4. can kill, compatible with the optimal win
    5. can and MUST kill to win (all winning lines kill it)
  Similar ladders for territory (immortal / invadable / contested) and
  influence. "Can I kill these stones?" and "is killing on the optimal path?"
  are tiers of this ladder. Fluffy vocabulary ("good shape") explicitly
  far-out-of-scope; LLM narrative out-of-scope; the ladder + fact-diffs are
  the truthful evidence base a narrative layer would consume later.

Sequencing note: all personas/pedagogy sit ABOVE the oracle + query engine;
nothing here changes the store (value/DTT/flags + columnar extensions).

## Schema extensibility (user agnosticism about future stored aids)

Keep the store minimal (value, DTT, flags) but COLUMN-ORIENTED: any future
per-position datum (e.g. move-ordering hints for goal solvers, decomposition
flags) becomes a SEPARATE parallel file keyed by the same colex index —
addable later without touching or re-deriving existing columns. Only store
what is expensive to recompute; Benson/settled status recomputes instantly
and is never stored.

## Viewer strategy (Mac; user has SmartGo One, PVGo, Go Zen)

- Encode annotations in PLAIN SGF so every viewer renders them: C[] comments,
  LB[] point labels (e.g. per-move values on the board), TB[]/TW[] territory
  marks, TR/SQ/MA shape marks. Verified: oracle-5x5-pv.sgf opens in SmartGo
  One; same file works in Sabaki (open source, variation trees).
- Standardize on ONE primary tool: Sabaki — it also HOSTS GTP engines, so the
  future live query engine (weizigo speaking GTP) works inside the same tool;
  GoGui is only needed if we later want its `gogui-analyze` graphical overlay
  extensions (heatmaps). Extending/forking Sabaki (Electron/JS, MIT) to render
  richer overlays is plausible but deferred until the query engine exists.
- Future interface: a small GTP server exposing oracle lookups + goal queries
  ("genmove" = an optimal move; custom commands: value, movetable, capture?,
  immortal?, tempo). That is the "interactive sniff-test" milestone.
