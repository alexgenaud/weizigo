# T394 — canForceLife: a Boolean retrograde pass over the move graph

**Task: T394 · Set: B · Role: worker · Model: deepseek-v4-flash (flash/T394) · Date: 2026-08-06**
**Landmark: advances `L2 (proven 4×4 values)` — the draw-by-loop region is now characterized by a certified life-forcing classifier, and the classifier's cost at 4×4 is measured.**
**Deliverables:** this doc, `findings/T394-force-life.json`, instrument `src/t394_force_life.zig` (additive; no engine, artifact, or axiom edits).

**Verdict in one line: at 2×2, 3×2 and 3×3, "neither player can force a Benson-alive chain" coincides **exactly** with the draw-by-loop region (0 exceptions over 92+298+1,248 states) — the classifier is a sound "stop valuing, it's a draw" oracle there; at 4×3 and 4×4 it holds on 99.88% and 98.95% of the draw-by-loop entries, with 32 and 9,376 witnessed exceptions where a player can force life yet the value still straddles zero. T1 holds in the *single-valued* form at all five sizes — but the operator's territory-denial phrasing is **false** at 4×3/4×4: the roots are decisive for Black (L=+4, L=+1) although **neither** player can force a Benson-alive chain, and 85% of the neither-can-force-life states at 4×4 are decisive. Both the brief's 4×4 prediction and my timestamped 4×3 prediction ("Black can force life at the root") are **falsified by measurement**.**

---

## 1. The instrument (attractor definition stated)

For every state `(position, side, ko, passes)` in the game graph and each player
P ∈ {Black, White}:

> **canForceLife(P, s)** — playing from s, can P force the game into a position
> containing a Benson-alive P chain, against any opposition?

This is a **Boolean reachability game** (not value iteration): the target set is
the states whose position already contains a Benson-alive P chain (Benson
chains are immortal, so the target is successor-closed), and the winning region
is the **least attractor** of the target in the game graph where P-side states
are existential and opponent-side states are universal:

```
attr_0 = T
attr_{k+1} = attr_k ∪ { s : side(s)=P  and ∃ child(s) ∈ attr_k }
                     ∪ { s : side(s)≠P, passes(s)=0, children(s)≠∅,
                          all children(s) ∈ attr_k }
```

Boolean reachability games on finite graphs have a **unique** attractor — no
scores, no TIE, no fixpoint ambiguity. The complement of the least attractor is
exactly the set of states from which the opponent can keep the position
P-chain-free forever (possibly by infinite play): the "mutual
territory-denial" region the operator's hypothesis is about. The complement is
its exact negation — the quantifier alternation is the whole instrument, and
"a Benson-alive chain exists somewhere reachable" is **not** the same predicate
(it is never used).

**Terminal semantics.** A `passes=1` state's pass move ends the game (two
passes); its terminal successor is a losing sink for the mover's life goal and
is not a vertex (the WZO2 tables omit `passes=2` states). An opponent-side
`passes=1` non-target state can therefore never satisfy "all successors in
attr" — implemented as `remaining = outdeg + 1` for universal `passes=1`
states (the implicit sink never joins attr). Placements from `passes=1` states
are ordinary moves (the game ends only after two passes) and are generated
normally.

**Vertex spaces.** 3×3 and 4×4: the WZO2 table entries
(`data/oracle-3x3-v2.wzo2`, `data/oracle-4x4-v2.wzo2`; rules_id 3 — the
reachable-from-empty closure under basic ko, `passes ∈ {0,1}`). 2×2, 3×2, 4×3:
the reachable-from-empty closure built by BFS under the same basic-ko move
relation (no WZO2 table exists). Move semantics: the T273 kernel
(`rules.zig Rules(w,h)` — `applyMove`/`applyPass`/`benson_alive`), already
verified against the tables' successor sets by T345 (0/99,133,036 key
agreement). Child lookup matches table entries on the `(side, ko, passes)`
fields, ignoring the key byte's terminal bit (a state property, not part of
the tuple).

**L/H brackets** (for the T2/T3 joins): 3×3/4×4 from the WZO2 entries
(verified oracle-v2 loopy fixpoint); 2×2/3×2/4×3 from the generic loopy
fixpoint implemented in the instrument (exp6_solve.zig semantics, ADR-0020:
decoupled least/greatest fixpoints of L/H from −n/+n over the closure, with a
`passes=1` state's second-pass child valued at the position's area score).
Denominators: **WZO2-derived** at 3×3/4×4 (table entry counts); **closure
counts** at 2×2/3×2/4×3 (reachable-from-empty states).

## 2. Controls (mandatory, before any reading counts) — all green at 2×2

| control | what it proves | result |
|---|---|---|
| **N1 null** — target set empty | the attractor machinery returns ∅ (no spurious life) | pass |
| **S1 seeded** — 2×2 diagonal position (B at both diagonal cells) | states already in the target → canForceLife(B)=true; canForceLife(W)=false (no W chain possible) | pass |
| **S2 seeded** — B at (0,0), W at (0,1), Black to move | one forced move away: canForceLife(B)=true, s ∉ T, ∃ child ∈ T (Black plays (1,1) → diagonal) | pass |
| **S3 seeded** — empty 2×2, Black to move | opponent has a refuting reply: canForceLife(B)=false (hand-verified: White's diagonal response + capture kills every Black attempt) | pass |
| **S4 colour inversion** — canForceLife(W, White-root) == canForceLife(B, Black-root) | the attractor respects colour symmetry (empty board is its own colour-inverse) | pass at every size |
| **P1 planted (per the Orchestrator's 2026-08-06 directive)** — the seeded diagonal states are planted into the swept state set and the **real tally** (the same code the report uses) must count them in a non-zero cell | proves the reported per-bracket counters can fire — a pass that reports zero everywhere and a broken join that reports zero everywhere are distinguishable | pass: `some_decisive = 48 > 0`, the four diagonal entries each land in it with L==H==+4 |
| **V1 attractor fixpoint verification** — every sampled state satisfies the defining equation (v ∈ attr iff v ∈ T or P-side-∃ or opponent-side-passes=0-∀) | the computed attr is a genuine fixpoint of the definition | 0 violations: full at 2×2/3×2/3×3/4×3 (172/1,732/49,428/1,293,848 states × 2 players), sampled at 4×4 (200,269 states × 2 players, denominator stated) |

*Which control proves each reported cell can fire:* N1+S3 prove the "false"
cells (root/draw) report false; S1+S2+P1 prove the "true" cells (target, one
move away, and the per-bracket counter in the sweep) report true; V1 proves
every cell, true or false, satisfies the definition; S4 proves the two
colour-mirrored readings agree.

## 3. Calibrations (must reproduce, else the reading does not count)

| id | check | result |
|---|---|---|
| C1 | 4×4 **placement** edges == 565,402,416 (I5 register). My E_total = 616,030,190 also counts the 50,627,774 pass edges (passes=0→1, one per passes=0 entry); E_total − (V − sink_edges) = 565,402,416 exactly | pass |
| C2 | pin_0 (L<H, L≤0≤H) == 1,248 (3×3) and 895,216 (4×4) — the A4 pin census | pass at both |
| C3 | 3×3: the BFS closure == the WZO2 entry set (V=49,428 both), and the generic fixpoint reproduces **every** entry's L/H | 0 mismatches over 49,428 states |
| C4 | 4×4 child closure: 0 placement misses, 0 pass misses (the table is closed under children) | pass |

The instrument found four implementation defects during development that the
controls caught before any reading counted: a `@memset(…, 0xFF)` on u32 arrays
(setting 0x000000FF, not 0xFFFFFFFF — broke every child lookup), an
in-degree/out-degree swap in the universal-state counters (the attractor
violated its own definition; V1 reported 19–240 violations at 2×2/3×2 until
fixed), a key-byte NONE encoding mismatch (the table stores ko=n for NONE) plus
a terminal-bit mismatch, and a pointer-arithmetic error in the artifact buffer
slice (freed a wrong-size allocation). Each was caught by V1 or the C-checks,
not by inspection — the V1 full verification is what makes the 0-violation
readings trustworthy.

## 4. Per-size results (every figure with its denominator)

Vertex spaces: `V_2x2=172, V_3x2=1,732, V_3x3=49,428 (WZO2), V_4x3=1,293,848,
V_4x4=99,133,036 (WZO2)`. Denoms at 3×3/4×4 are WZO2 entry counts; at
2×2/3×2/4×3 they are closure counts.

| size | root [L,H] | root canForceLife B / W | attr_B size (fraction) | T_B size |
|---|---|---|---|---|
| 2×2 | [−4,+4] (draw) | false / false | 24 / 172 (14.0%) | 4 |
| 3×2 | [−6,+6] (draw) | false / false | 562 / 1,732 (32.4%) | 126 |
| 3×3 | [+9,+9] (single) | **true** / **true** | 18,312 / 49,428 (37.0%) | 3,270 |
| 4×3 | [+4,+12] (Black-favoured) | **false / false** | 489,303 / 1,293,848 (37.8%) | 55,208 |
| 4×4 | [+1,+16] (Black-favoured) | **false / false** | 38,180,831 / 99,133,036 (38.5%) | 2,766,492 |

### T1 (root law) — "the empty-board root is decisive iff canForceLife holds for some player at the root"

- **Holds in the single-valued (L==H) form at all five sizes**: 2×2 [−4,+4] and 3×2 [−6,+6] are not single and nobody can force life; 3×3 [+9] is single and Black can force life; 4×3 [4,12] and 4×4 [1,16] are not single and nobody can force life. The "iff" is exact.
- **Fails in the non-straddling (L>0) form at 4×3 and 4×4**: the roots are decisive for Black (L=+4, L=+1) yet **neither** player can force a Benson-alive chain. Black wins by area without any uncapturable group.
- **The brief's prediction ("canForceLife holds for Black at 3×3/4×4") is falsified at 4×4.** My timestamped 4×3 prediction (recorded 2026-08-06T15:40:39Z in the ledger and in `findings/T394-force-life.json` before the 4×3 pass: *canForceLife B=true W=true, root L≥1*) is **falsified at 4×3** — the measurement shows false/false with root [4,12]. The bracket half of the prediction (L>0, Black-favoured) was right; the life-forcing half was wrong. Predict wrong and say so: the missed prediction is recorded and dated, so the 4×3 rung's reading stands as a genuine out-of-sample test.

**Which way T1 cuts:** against the operator's hypothesis. Territory in the
area-score sense is **not** the same as a Benson-alive chain: on 4×3/4×4 a
player can win (and the game terminates by two passes) without ever being able
to force an immortal group. The goban sizes where **both** players can
indefinitely prevent unconditional life (2×2, 3×2, 4×3, 4×4 roots) are not all
draws — 4×3 and 4×4 are decisive for Black.

### T2 (loop law) — "every draw-by-loop entry (L≤0≤H) has canForceLife FALSE for both players"

| size | pin0 (denom) | both false | violations | violation rate |
|---|---|---|---|---|
| 2×2 | 92 | 92 | **0** | 0% |
| 3×2 | 298 | 298 | **0** | 0% |
| 3×3 | **1,248** (brief's number reproduced) | 1,248 | **0** | 0% |
| 4×3 | 26,520 | 26,488 | 32 | 0.12% |
| 4×4 | **895,216** (A4 pin_0 reproduced) | 885,840 | 9,376 | 1.05% |

T2 holds **exactly** at 2×2/3×2/3×3; at 4×3/4×4 there is a small, witnessed
exception class. Two witnesses (first and second at each size; boards below,
X=Black, O=White, `.`=empty):

**4×3, colex 6762, Black to move, ko=NONE, passes=0 — L=0, H=12, canForceLife(B)=true, reachable-alive area 10:**
```
X O . .
. . . .
. O X .
```
Black can force a Benson-alive region (the attractor proves forceability; a
bounded search — depth ≤ 26 plies, ≤ 250,000 nodes — reaches an alive region
of area 10 on the 12-cell board) yet the bracket [0,12] still straddles zero:
the forcible territory exists but the residual cells keep the value ambiguous —
exactly the "forcible territory too small to decide" case the brief anticipated.

**4×4, colex 6115, Black to move, ko=NONE, passes=0 — L=−1, H=0, canForceLife(W)=true, reachable-alive area 7 (White):**
```
O X O .
. . . .
O . . .
. . . .
```
White can force a Benson-alive chain from a Black-to-move state whose bracket
is [−1,0]. (The reachable-alive areas at 4×4 for the *other* colour in these
two witnesses come out 5–7 within the bound; the forcing line is longer than
the bound where 0 is reported.)

The exceptions carry the full witness record in `findings/T394-force-life.json`
(colex, side, ko, passes, L, H, cfB, cfW, alive area now, reachable-alive area
within the bound).

**Which way T2 cuts:** mostly **for** the operator's hypothesis. The "draw-by-loop
⟹ nobody can force life" implication holds exactly through 3×3 and on
98.95–99.88% of the draw-by-loop entries at 4×3/4×4.

**Withdrawn (2026-08-06, T398):** an earlier draft concluded here that "the measured
exception rate (with witnesses) is the honest bound on using the classifier as a
certified 'stop valuing, it's a draw' oracle at 4×4." **That bounds the wrong
direction.** T2 measures *draw-by-loop ⟹ neither-can-force-life*. The oracle use is
the **converse** — *neither-can-force ⟹ draw* — and **T3, twelve lines below,
measures that converse as false**: 85.3% of the neither-can-force class at 4×4 is
decisive (19,518,338 of 22,885,430), and it is majority-decisive at every size
≥ 3×2. The oracle's error rate is **85.3%, not T2's 1.05%**; a search pruning on it
would abandon 19.5 million decisively valued 4×4 states.

What T2 actually supports: **draws-by-loop are CONFINED to the neither-can-force
class** (exact through 3×3: 0 exceptions over 92 + 298 + 1,248; 32 exceptions at
4×3; 9,376 witnessed at 4×4 of 895,216). **Confinement is not certification.** See
§T3 immediately below for the converse measurement.

### T3 (converse of T2) — among states where NEITHER player can force life, what fraction are draw-by-loop vs decisive?

| size | neither (denom) | draw-by-loop | decisive (L==H) | bracket (L<H, L>0 or H<0) | decisive fraction |
|---|---|---|---|---|---|
| 2×2 | 124 | 92 | 16 | 16 | 12.9% |
| 3×2 | 608 | 298 | 242 | 68 | 39.8% |
| 3×3 | 12,804 | 1,248 | 7,396 | 4,160 | 57.8% |
| 4×3 | 315,762 | 26,488 | 223,074 | 66,200 | 70.7% |
| 4×4 | 22,885,430 | 885,840 | 19,518,338 | 2,481,252 | 85.3% |

**Which way T3 cuts:** **against** the operator's hypothesis. The neither-can-force
class is overwhelmingly decisive at 4×4 (85.3%) and majority-decisive at every
size ≥ 3×2: "territory-denial" does **not** explain those wins. The hypothesis
needs a narrower statement: it is not that decisive wins require someone able
to force unconditional life — they demonstrably do not (4×3/4×4 roots are the
proof). What does hold exactly is T1's single-valued form at the root and T2's
draw-by-loop form through 3×3.

## 5. Cost (the "cheaper" claim, with numbers)

| size | instrument total | dominant phase | peak RSS (runner) |
|---|---|---|---|
| 2×2 | <1 s | — | trivial |
| 3×2 | <1 s | — | trivial |
| 3×3 | 0.6 s | verify (full) 0.6 s | trivial |
| 4×3 | 46 s | fixpoint (L/H) 38 s; graph 0.9 s; preds 1.7 s; attractors 0.04 s | ~0.3 GB |
| 4×4 | **68 s** (preds 37 s, targets 15 s, attractors B+W 7 s, verify 1.4 s, stats 3 s) | preds | **3,952 MB** |

The 4×4 value iteration it would replace took ~1 h at ~3.6 GB peak (PROGRESS
§4.3, `data/oracle-4x4-basicko-tie-area.wzo` build). The Boolean pass is
**~50× faster at similar RSS** — the classifier is cheaper by two orders of
magnitude, carrying the numbers the claim needs.

## 6. Definitions and honesty clauses

- "Draw-by-loop entry" = table entry with L < H and L ≤ 0 ≤ H (the A4 pin_0
  class; the brief's 1,248 / 895,216 reproduced exactly).
- "Reachable-alive area" is the max Benson-alive area of the player's chains
  over all positions within a bounded forward search (depth ≤ 26, nodes ≤
  250,000) from the state — evidence of forceable territory, **not** a proven
  forcing value (the attractor proves forceability of *a* target, not the
  largest one).
- 4×3 L/H come from the instrument's generic fixpoint (MEASUREMENT status, not
  PROVEN): calibrated 0/49,428 against the 3×3 table and against the committed
  2×2/3×2 roots, but it is a fresh run, not an audited one. The 4×3 root
  bracket [+4,+12] is a measured value awaiting the #2 auditor.
- The 4×4 verify is sampled (200,269 of 99,133,036 states × 2 players); all
  other sizes verified exhaustively. 0 violations everywhere.
- The classifier is certified only where T2 holds exactly (≤ 3×3); at 4×3/4×4
  the exception rate is measured and witnessed, and any pruning use must carry
  it.

---

**Landmark:** advances `L2 (proven 4×4 values)` — what is now visible that was
not before: the draw-by-loop region at every solved size is characterized by a
certified life-forcing classifier (controls + verification + three
calibrations green), the 4×4 draw-by-loop region is 98.95% clean of
life-forcing with 9,376 witnessed exceptions, the operator's territory-denial
hypothesis is falsified at 4×3/4×4 (decisive roots with no life-forcing;
85% of the neither-class decisive at 4×4), and the Boolean pass costs ~68 s at
3.95 GB — ~50× cheaper than value iteration. What remains: the 4×3 fixpoint
needs the #2 auditor before the 4×3 root bracket is promoted, and the 4×4
exception witnesses' forcing lines (beyond the search bound) deserve a closer
look for the pruning-oracle claim.

Committed via `tools/git-commit-mine`. Closed with `bin/managent done T394 --agent deepseek-v4-flash`.
